#!/usr/bin/env python3
"""
OpenClaw Gateway Quota Enforcer
================================
A thin HTTP proxy that sits in front of the OpenClaw Gateway (port 13145) to enforce
media generation quotas (image / video) at the gateway layer.

Usage:
    python3 gateway-quota-enforcer.py [start|stop|status|restart]

Environment variables:
    QUOTA_ENFORCER_PORT   Port to listen on (default: 13147)
    QUOTA_GATEWAY_HOST   Gateway host (default: 127.0.0.1)
    QUOTA_GATEWAY_PORT   Gateway port (default: 13145)
    QUOTA_LOG_FILE       Log file path (default: /tmp/openclaw-quota-enforcer.log)

Endpoints:
    GET  /quota/status   Current quota status (from media_quota.py)
    GET  /health         Basic health check
    *    /               All other requests proxied to gateway with quota enforcement
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import threading
import time
import urllib.request
import urllib.error
from http.server import HTTPServer, BaseHTTPRequestHandler
from typing import Optional

# ── Configuration ──────────────────────────────────────────────────────────────

QUOTA_ENFORCER_PORT = int(os.environ.get("QUOTA_ENFORCER_PORT", "13147"))
QUOTA_GATEWAY_HOST  = os.environ.get("QUOTA_GATEWAY_HOST", "127.0.0.1")
QUOTA_GATEWAY_PORT  = int(os.environ.get("QUOTA_GATEWAY_PORT", "13145"))
QUOTA_LOG_FILE      = os.environ.get("QUOTA_LOG_FILE", "/tmp/openclaw-quota-enforcer.log")
PID_FILE            = "/tmp/openclaw-quota-enforcer.pid"
SCRIPT_DIR          = os.path.dirname(os.path.abspath(__file__))

# ── Logging ────────────────────────────────────────────────────────────────────

def log(level: str, msg: str) -> None:
    ts = time.strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{ts}] [{level}] {msg}"
    print(line, flush=True)
    try:
        with open(QUOTA_LOG_FILE, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except Exception:
        pass

def log_info(msg: str) -> None: log("INFO", msg)
def log_warn(msg: str) -> None: log("WARN", msg)
def log_err(msg: str) -> None: log("ERROR", msg)

# ── media_quota.py wrapper ────────────────────────────────────────────────────

MEDIA_QUOTA_SCRIPT = os.path.join(SCRIPT_DIR, "media_quota.py")

def _run_quota_cmd(args: list[str]) -> dict:
    """Call media_quota.py as subprocess and parse JSON output."""
    try:
        result = subprocess.run(
            [sys.executable, MEDIA_QUOTA_SCRIPT] + args,
            capture_output=True, text=True, timeout=15
        )
        try:
            return json.loads(result.stdout)
        except Exception:
            return {"ok": False, "reason": "parse_error", "stdout": result.stdout, "stderr": result.stderr}
    except subprocess.TimeoutExpired:
        return {"ok": False, "reason": "timeout"}
    except FileNotFoundError:
        return {"ok": False, "reason": "media_quota_not_found"}
    except Exception as exc:
        return {"ok": False, "reason": str(exc)}


def quota_reserve(category: str, units: int = 1, tool: str = "") -> dict:
    """Reserve quota units. Returns dict with 'ok', 'reservation' (if ok), 'status'."""
    return _run_quota_cmd(["reserve", "--category", category, "--units", str(units), "--tool", tool])


def quota_commit(reservation_id: str) -> dict:
    return _run_quota_cmd(["commit", "--id", reservation_id])


def quota_release(reservation_id: str) -> dict:
    return _run_quota_cmd(["release", "--id", reservation_id])


def quota_status() -> dict:
    return _run_quota_cmd(["status"])

# ── Request classification ─────────────────────────────────────────────────────

# URL patterns that represent media generation calls (image, video, music)
MEDIA_URL_PATTERNS = [
    re.compile(r"/v1/images?[/]?$", re.IGNORECASE),
    re.compile(r"/v1/images?/generations", re.IGNORECASE),
    re.compile(r"/v1/images?/edits", re.IGNORECASE),
    re.compile(r"/v1/images?/variations", re.IGNORECASE),
    re.compile(r"/v1/video", re.IGNORECASE),
    re.compile(r"/v1/music", re.IGNORECASE),
    re.compile(r"/v1/generation/images?", re.IGNORECASE),
]

# Body patterns that indicate image generation in JSON payloads
MEDIA_BODY_PATTERNS = [
    re.compile(r'"model"\s*:\s*"[^"]*image[^"]*"', re.IGNORECASE),
    re.compile(r'"prompt"\s*:', re.IGNORECASE),
    re.compile(r'"n"\s*:\s*[1-9]', re.IGNORECASE),
]


def is_media_generation_request(method: str, path: str, body: Optional[bytes]) -> tuple[bool, str]:
    """
    Determine if a request is a media generation call.
    Returns (is_media, category) where category is 'image', 'video', or 'music'.
    """
    if method not in ("POST", "PUT", "PATCH"):
        return False, ""

    path_lower = path.lower()

    # Check URL patterns
    for pat in MEDIA_URL_PATTERNS:
        if pat.search(path_lower):
            if "image" in path_lower or "image" in str(path):
                return True, "image"
            if "video" in path_lower:
                return True, "video"
            if "music" in path_lower:
                return True, "music"
            # Default based on URL
            return True, "image"

    # Check body content
    if body:
        try:
            text = body.decode("utf-8", errors="ignore").lower()
            for pat in MEDIA_BODY_PATTERNS:
                if pat.search(text):
                    return True, "image"
        except Exception:
            pass

    return False, ""


def count_image_units(method: str, path: str, body: Optional[bytes]) -> int:
    """Count how many images this request will generate (for quota reservation)."""
    units = 1
    if body:
        try:
            text = body.decode("utf-8", errors="ignore")
            m = re.search(r'"n"\s*:\s*(\d+)', text)
            if m:
                units = max(1, min(int(m.group(1)), 10))  # cap at 10 per call
        except Exception:
            pass
    return units

# ── HTTP Proxy Handler ────────────────────────────────────────────────────────

class QuotaEnforcerHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def _send_json(self, status_code: int, data: dict) -> None:
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def _proxy_to_gateway(self, method: str, path: str, headers: dict,
                          body: Optional[bytes] = None) -> tuple[int, dict, Optional[bytes]]:
        """Forward request to gateway and return (status_code, response_headers, body_bytes)."""
        gateway_url = f"http://{QUOTA_GATEWAY_HOST}:{QUOTA_GATEWAY_PORT}{path}"
        req = urllib.request.Request(gateway_url, data=body, method=method)
        for k, v in headers.items():
            if k.lower() not in ("host", "connection", "content-length"):
                req.add_header(k, v)
        req.add_header("Host", f"{QUOTA_GATEWAY_HOST}:{QUOTA_GATEWAY_PORT}")
        req.add_header("X-Forwarded-For", "127.0.0.1")
        req.add_header("X-Forwarded-By", "openclaw-quota-enforcer")

        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                resp_body = resp.read()
                resp_headers = dict(resp.headers)
                return resp.status, resp_headers, resp_body
        except urllib.error.HTTPError as e:
            resp_body = e.read() if e.fp else b""
            resp_headers = dict(e.headers) if e.headers else {}
            return e.code, resp_headers, resp_body
        except urllib.error.URLError as e:
            return 502, {}, b'{"error": "gateway_unreachable", "message": "OpenClaw Gateway is not reachable"}'
        except Exception as e:
            return 502, {}, json.dumps({"error": "proxy_error", "message": str(e)}).encode()

    def _forward_response(self, status_code: int, headers: dict, body: Optional[bytes]) -> None:
        """Forward gateway response back to client."""
        self.send_response(status_code)
        for k, v in headers.items():
            if k.lower() not in ("transfer-encoding", "connection", "content-encoding"):
                try:
                    self.send_header(k, v)
                except Exception:
                    pass
        self.send_header("X-Proxy-By", "openclaw-quota-enforcer")
        if body:
            self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if body:
            self.wfile.write(body)

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Authorization, Content-Type")
        self.end_headers()

    def do_GET(self) -> None:
        if self.path == "/health":
            self._send_json(200, {"status": "ok", "service": "quota-enforcer"})
            return

        if self.path in ("/quota/status", "/quota/status/"):
            result = quota_status()
            result["service"] = "quota-enforcer"
            result["gateway"] = f"http://{QUOTA_GATEWAY_HOST}:{QUOTA_GATEWAY_PORT}"
            self._send_json(200, result)
            return

        if self.path == "/quota/status/image":
            result = quota_status()
            self._send_json(200, result.get("image", {"error": "no data"}))
            return

        if self.path == "/quota/status/video":
            result = quota_status()
            self._send_json(200, result.get("video", {"error": "no data"}))
            return

        if self.path in ("/quota/reset", "/quota/reset/"):
            log_warn("Quota reset requested (no-op in proxy mode, use media_quota.py directly)")
            self._send_json(400, {"error": "reset_not_supported", "message": "Use scripts/media_quota.py to reset quota state"})
            return

        # Proxy other GET requests to gateway
        headers = {k: v for k, v in self.headers.items()}
        status, resp_headers, body = self._proxy_to_gateway("GET", self.path, headers)
        self._forward_response(status, resp_headers, body)

    def do_POST(self) -> None:
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length) if content_length > 0 else None

        if self.path in ("/quota/reserve", "/quota/release", "/quota/commit"):
            self._handle_quota_api(body)
            return

        # Check if this is a media generation request
        is_media, category = is_media_generation_request("POST", self.path, body)
        if is_media and category:
            units = count_image_units("POST", self.path, body)
            log_info(f"Media request detected: {self.path} category={category} units={units}")

            reserve_result = quota_reserve(category, units, tool=self.path)

            if not reserve_result.get("ok"):
                reason = reserve_result.get("reason", "unknown")
                message = reserve_result.get("message", "Quota exceeded")
                log_warn(f"Quota denied: {category}/{units} → {reason}: {message}")
                status_summary = reserve_result.get("status", {})
                self._send_json(429, {
                    "error": "quota_exceeded",
                    "reason": reason,
                    "message": message,
                    "category": category,
                    "requestedUnits": units,
                    "remaining": status_summary.get("remaining", 0),
                    "limit": status_summary.get("limit", 0),
                    "windowHours": status_summary.get("windowHours", 5),
                })
                return

            reservation_id = reserve_result.get("reservation", {}).get("id", "")
            log_info(f"Quota reserved: {category}/{units} reservation_id={reservation_id}")

            # Forward request to gateway
            headers = {k: v for k, v in self.headers.items()}
            status, resp_headers, resp_body = self._proxy_to_gateway("POST", self.path, headers, body)

            # Commit or release based on response
            if 200 <= status < 300:
                commit_result = quota_commit(reservation_id)
                if commit_result.get("ok"):
                    log_info(f"Quota committed: {category}/{units} reservation_id={reservation_id}")
                else:
                    log_warn(f"Quota commit failed: {commit_result}")
            else:
                release_result = quota_release(reservation_id)
                if release_result.get("ok"):
                    log_info(f"Quota released (non-2xx): {category}/{units} status={status}")
                else:
                    log_warn(f"Quota release failed: {release_result}")

            # Add quota headers to response
            resp_headers["X-Quota-Reservation-Id"] = reservation_id
            resp_headers["X-Proxy-By"] = "openclaw-quota-enforcer"
            self._forward_response(status, resp_headers, resp_body)
            return

        # Non-media POST — proxy directly
        headers = {k: v for k, v in self.headers.items()}
        status, resp_headers, body = self._proxy_to_gateway("POST", self.path, headers, body)
        self._forward_response(status, resp_headers, body)

    def _handle_quota_api(self, body: Optional[bytes]) -> None:
        """Handle /quota/* admin endpoints."""
        try:
            data = json.loads(body.decode("utf-8")) if body else {}
        except Exception:
            self._send_json(400, {"error": "invalid_json"})
            return

        if self.path == "/quota/reserve":
            category = data.get("category", "image")
            units = max(1, int(data.get("units", 1)))
            tool = data.get("tool", "")
            result = quota_reserve(category, units, tool)
            self._send_json(200 if result.get("ok") else 429, result)
            return

        if self.path == "/quota/commit":
            rid = data.get("id", "")
            result = quota_commit(rid) if rid else {"ok": False, "reason": "missing_id"}
            self._send_json(200 if result.get("ok") else 400, result)
            return

        if self.path == "/quota/release":
            rid = data.get("id", "")
            result = quota_release(rid) if rid else {"ok": False, "reason": "missing_id"}
            self._send_json(200 if result.get("ok") else 400, result)
            return

    def log_message(self, format, *args) -> None:
        log_info(f"{self.client_address[0]} {format % args}")

    def log_error(self, format, *args) -> None:
        log_err(f"{self.client_address[0]} {format % args}")


# ── Server lifecycle ──────────────────────────────────────────────────────────

def _read_pid() -> Optional[int]:
    try:
        return int(open(PID_FILE).read().strip())
    except Exception:
        return None


def _write_pid(pid: int) -> None:
    open(PID_FILE, "w").write(str(pid))


def start_server(bind: str = "127.0.0.1", port: int = QUOTA_ENFORCER_PORT) -> None:
    """Start the quota enforcer server."""
    # Check if already running
    existing = _read_pid()
    if existing:
        try:
            import signal
            os.kill(existing, 0)
            log_err(f"Quota enforcer already running (PID {existing}) on port {port}")
            sys.exit(1)
        except ProcessLookupError:
            pass

    server = HTTPServer((bind, port), QuotaEnforcerHandler)
    _write_pid(os.getpid())
    log_info(f"Quota enforcer listening on http://{bind}:{port}")
    log_info(f"  Gateway: http://{QUOTA_GATEWAY_HOST}:{QUOTA_GATEWAY_PORT}")
    log_info(f"  Status:  http://{bind}:{port}/quota/status")
    log_info(f"  Health:  http://{bind}:{port}/health")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        log_info("Quota enforcer shutting down")
    finally:
        server.server_close()
        try:
            os.unlink(PID_FILE)
        except Exception:
            pass


def stop_server() -> None:
    """Stop the running quota enforcer."""
    pid = _read_pid()
    if not pid:
        print("Quota enforcer not running (no PID file)")
        return
    try:
        import signal
        os.kill(pid, signal.SIGTERM)
        print(f"Quota enforcer (PID {pid}) stopped")
    except ProcessLookupError:
        print("Quota enforcer not running")
    except PermissionError:
        print(f"Permission denied (try sudo): PID {pid}")
    try:
        os.unlink(PID_FILE)
    except Exception:
        pass


def status_server() -> None:
    """Print status of the quota enforcer."""
    import urllib.request
    import urllib.error

    pid = _read_pid()
    running = False
    if pid:
        try:
            os.kill(pid, 0)
            running = True
        except ProcessLookupError:
            running = False

    if running:
        print(f"Quota enforcer: RUNNING (PID {pid})")
        try:
            req = urllib.request.Request(f"http://127.0.0.1:{QUOTA_ENFORCER_PORT}/quota/status")
            with urllib.request.urlopen(req, timeout=5) as resp:
                data = json.loads(resp.read())
                print(f"  Image quota: {data.get('image', {}).get('used', 0)}/{data.get('image', {}).get('limit', 0)} used, {data.get('image', {}).get('remaining', 0)} remaining")
                print(f"  Video quota: {data.get('video', {}).get('used', 0)}/{data.get('video', {}).get('limit', 0)} used, {data.get('video', {}).get('remaining', 0)} remaining")
        except Exception as e:
            print(f"  Quota status error: {e}")
    else:
        print("Quota enforcer: NOT RUNNING")


# ── CLI entry point ───────────────────────────────────────────────────────────

def main(argv: list[str] | None = None) -> int:
    argv = argv or sys.argv[1:]
    cmd = argv[0] if argv else "start"

    if cmd in ("start", ""):
        start_server()
        return 0
    if cmd == "stop":
        stop_server()
        return 0
    if cmd == "status":
        status_server()
        return 0
    if cmd == "restart":
        stop_server()
        time.sleep(1)
        start_server()
        return 0
    if cmd in ("help", "--help", "-h"):
        print(__doc__)
        return 0

    print(f"Unknown command: {cmd}")
    print("Usage: gateway-quota-enforcer.py {start|stop|status|restart}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
