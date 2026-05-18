#!/usr/bin/env python3
"""
OpenClaw Gateway Quota Enforcer
================================
A thin HTTP proxy that sits in front of the OpenClaw Gateway (port 13145) to enforce
request-count quotas (text / image / video) at the gateway layer. The official
OpenClaw Gateway remains the internal upstream; external clients should use this
proxy endpoint (default port 13147).

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

# URL patterns that represent media generation calls (image, video).
IMAGE_URL_PATTERNS = [
    re.compile(r"/v1/images?[/]?$", re.IGNORECASE),
    re.compile(r"/v1/images?/generations", re.IGNORECASE),
    re.compile(r"/v1/images?/edits", re.IGNORECASE),
    re.compile(r"/v1/images?/variations", re.IGNORECASE),
    re.compile(r"/v1/generation/images?", re.IGNORECASE),
]

VIDEO_URL_PATTERNS = [
    re.compile(r"/v1/video", re.IGNORECASE),
    re.compile(r"/v1/videos?", re.IGNORECASE),
]

# Body patterns that indicate image generation in JSON payloads
IMAGE_BODY_PATTERNS = [
    re.compile(r'"model"\s*:\s*"[^"]*image[^"]*"', re.IGNORECASE),
    re.compile(r'"model"\s*:\s*"[^"]*(seedream|flux|midjourney|dall-e|imagen|stable-diffusion|qwen-image|glm-image|z-image)[^"]*"', re.IGNORECASE),
    re.compile(r'"type"\s*:\s*"image_generation"', re.IGNORECASE),
]

VIDEO_BODY_PATTERNS = [
    re.compile(r'"model"\s*:\s*"[^"]*video[^"]*"', re.IGNORECASE),
    re.compile(r'"type"\s*:\s*"video_generation"', re.IGNORECASE),
]


def is_media_generation_request(method: str, path: str, body: Optional[bytes]) -> tuple[bool, str]:
    """
    Determine if a request is a media generation call.
    Returns (is_media, category) where category is 'image' or 'video'.
    Music/audio/search/vision requests are intentionally treated as text in v1.
    """
    if method not in ("POST", "PUT", "PATCH"):
        return False, ""

    path_lower = path.lower()

    for pat in IMAGE_URL_PATTERNS:
        if pat.search(path_lower):
            return True, "image"

    for pat in VIDEO_URL_PATTERNS:
        if pat.search(path_lower):
            return True, "video"

    if body:
        try:
            text = body.decode("utf-8", errors="ignore").lower()
            for pat in IMAGE_BODY_PATTERNS:
                if pat.search(text):
                    return True, "image"
            for pat in VIDEO_BODY_PATTERNS:
                if pat.search(text):
                    return True, "video"
        except Exception:
            pass

    return False, ""


def should_count_text_request(method: str, path: str) -> bool:
    if method not in ("POST", "PUT", "PATCH"):
        return False
    normalized = path.split("?", 1)[0].rstrip("/")
    if normalized.startswith("/quota"):
        return False
    if normalized in ("", "/health"):
        return False
    return True


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


def units_for_category(category: str, method: str, path: str, body: Optional[bytes]) -> int:
    if category == "image":
        return count_image_units(method, path, body)
    return 1


def _json_body(body: Optional[bytes]) -> dict:
    if not body:
        return {}
    try:
        data = json.loads(body.decode("utf-8", errors="ignore"))
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def infer_model_family(path: str, body: Optional[bytes]) -> str:
    data = _json_body(body)
    model = str(data.get("model") or data.get("model_id") or "")
    haystack = f"{path} {model}".lower()
    if "minimax" in haystack:
        return "minimax"
    if "deepseek" in haystack:
        return "deepseek"
    if "glm" in haystack or "zai" in haystack or "zhipu" in haystack:
        return "glm"
    if "gpt" in haystack or "openai" in haystack:
        return "gpt"
    if "image" in haystack or "dall-e" in haystack or "imagen" in haystack:
        return "image"
    if "video" in haystack or "hailuo" in haystack:
        return "video"
    return "unknown"


def infer_task_type(category: str, path: str, body: Optional[bytes]) -> str:
    if category in ("image", "video"):
        return f"{category}_generation"
    data = _json_body(body)
    text = json.dumps(data, ensure_ascii=False).lower() if data else ""
    if any(word in text for word in ("summarize", "摘要", "总结")):
        return "summary"
    if any(word in text for word in ("classify", "分类")):
        return "classification"
    if any(word in text for word in ("rewrite", "润色", "改写")):
        return "rewrite"
    if any(word in text for word in ("code review", "review code", "代码审阅", "审查代码")):
        return "coding_review"
    return "text"


def quota_tool_metadata(path: str, category: str, body: Optional[bytes]) -> str:
    return json.dumps({
        "path": path,
        "modelFamily": infer_model_family(path, body),
        "taskType": infer_task_type(category, path, body),
    }, ensure_ascii=False)

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

    def _send_quota_denied(self, category: str, units: int, reserve_result: dict) -> None:
        reason = reserve_result.get("reason", "unknown")
        message = reserve_result.get("message", "Quota exceeded")
        status_summary = reserve_result.get("status", {})
        log_warn(f"Quota denied: {category}/{units} -> {reason}: {message}")
        self._send_json(429, {
            "error": "quota_exceeded",
            "reason": reason,
            "message": message,
            "category": category,
            "requestedUnits": units,
            "remaining": status_summary.get("remaining", 0),
            "limit": status_summary.get("limit", 0),
            "resetAt": status_summary.get("resetAt", 0),
            "windowHours": status_summary.get("windowHours", 5),
        })

    def _proxy_with_quota(self, method: str, path: str, headers: dict, body: Optional[bytes], category: str, units: int) -> None:
        tool_metadata = quota_tool_metadata(path, category, body)
        log_info(f"Quota-controlled request: {path} category={category} units={units} metadata={tool_metadata}")
        reserve_result = quota_reserve(category, units, tool=tool_metadata)

        if not reserve_result.get("ok"):
            self._send_quota_denied(category, units, reserve_result)
            return

        reservation_id = reserve_result.get("reservation", {}).get("id", "")
        log_info(f"Quota reserved: {category}/{units} reservation_id={reservation_id}")

        status, resp_headers, resp_body = self._proxy_to_gateway(method, path, headers, body)

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

        resp_headers["X-Quota-Reservation-Id"] = reservation_id
        resp_headers["X-Quota-Category"] = category
        resp_headers["X-Quota-Model-Family"] = infer_model_family(path, body)
        resp_headers["X-Quota-Task-Type"] = infer_task_type(category, path, body)
        resp_headers["X-Proxy-By"] = "openclaw-quota-enforcer"
        self._forward_response(status, resp_headers, resp_body)

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

        if self.path == "/quota/status/text":
            result = quota_status()
            self._send_json(200, result.get("text", {"error": "no data"}))
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

        is_media, category = is_media_generation_request("POST", self.path, body)
        if not category and should_count_text_request("POST", self.path):
            category = "text"
        if category:
            units = units_for_category(category, "POST", self.path, body)
            headers = {k: v for k, v in self.headers.items()}
            self._proxy_with_quota("POST", self.path, headers, body, category, units)
            return

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
                print(f"  Text quota:  {data.get('text', {}).get('used', 0)}/{data.get('text', {}).get('limit', 0)} used, {data.get('text', {}).get('remaining', 0)} remaining")
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
