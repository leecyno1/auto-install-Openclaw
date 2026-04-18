#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import sys
import time
import uuid
from contextlib import contextmanager
from pathlib import Path
from typing import Any

DEFAULT_WINDOW_HOURS = 5
DEFAULT_RESERVATION_TTL_SECONDS = 1800
DEFAULT_STATE_PATH = os.path.join(os.path.expanduser("~"), ".openclaw", "quota", "media-state.json")
_LOCK_TIMEOUT_SECONDS = 5.0
_LOCK_POLL_SECONDS = 0.05
VALID_CATEGORIES = {"image", "video", "text"}


def _env_get(env: dict[str, str] | None, key: str, default: str = "") -> str:
    if env is not None and key in env:
        return str(env[key])
    return str(os.environ.get(key, default))


def _to_int(value: Any, default: int = 0) -> int:
    try:
        if value is None:
            return default
        return int(float(str(value).strip()))
    except Exception:
        return default


def _profile_default_limits(profile: str) -> dict[str, int]:
    normalized = str(profile or "medium").strip().lower()
    if normalized == "low":
        return {"image": 0, "video": 0, "text": 100}
    if normalized == "high":
        return {"image": 50, "video": 2, "text": 0}
    if normalized == "none":
        return {"image": 0, "video": 0, "text": 0}
    return {"image": 20, "video": 1, "text": 300}


def _state_path(env: dict[str, str] | None = None) -> Path:
    return Path(_env_get(env, "OPENCLAW_MEDIA_QUOTA_STATE_FILE", DEFAULT_STATE_PATH)).expanduser()


def _lock_path(env: dict[str, str] | None = None) -> Path:
    state_path = _state_path(env)
    return state_path.with_suffix(state_path.suffix + ".lock")


def _reservation_ttl_seconds(env: dict[str, str] | None = None) -> int:
    return max(60, _to_int(_env_get(env, "OPENCLAW_MEDIA_QUOTA_RESERVATION_TTL_SECONDS", str(DEFAULT_RESERVATION_TTL_SECONDS)), DEFAULT_RESERVATION_TTL_SECONDS))


def _window_hours(env: dict[str, str] | None = None) -> int:
    return max(1, _to_int(_env_get(env, "OPENCLAW_RULE_WINDOW_HOURS", str(DEFAULT_WINDOW_HOURS)), DEFAULT_WINDOW_HOURS))


def _limits(env: dict[str, str] | None = None) -> dict[str, int]:
    profile = _env_get(env, "OPENCLAW_RULE_PROFILE", "medium").strip().lower()
    defaults = _profile_default_limits(profile)
    return {
        "image": max(0, _to_int(_env_get(env, "OPENCLAW_RULE_MAX_IMAGE_REQUESTS", str(defaults["image"])), defaults["image"])),
        "video": max(0, _to_int(_env_get(env, "OPENCLAW_RULE_MAX_VIDEO_REQUESTS", str(defaults["video"])), defaults["video"])),
        "text": max(0, _to_int(_env_get(env, "OPENCLAW_RULE_MAX_REQUESTS", str(defaults["text"])), defaults["text"])),
    }


@contextmanager
def _file_lock(env: dict[str, str] | None = None):
    lock_path = _lock_path(env)
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    start = time.time()
    while True:
        try:
            os.mkdir(lock_path)
            break
        except FileExistsError:
            if (time.time() - start) > _LOCK_TIMEOUT_SECONDS:
                raise TimeoutError(f"quota lock timeout: {lock_path}")
            time.sleep(_LOCK_POLL_SECONDS)
    try:
        yield
    finally:
        try:
            os.rmdir(lock_path)
        except FileNotFoundError:
            pass


def _load_state(env: dict[str, str] | None = None) -> dict[str, Any]:
    state_path = _state_path(env)
    if not state_path.exists():
        return {"version": 1, "entries": []}
    try:
        data = json.loads(state_path.read_text(encoding="utf-8"))
        if isinstance(data, dict):
            entries = data.get("entries")
            if not isinstance(entries, list):
                data["entries"] = []
            return data
    except Exception:
        pass
    return {"version": 1, "entries": []}


def _save_state(state: dict[str, Any], env: dict[str, str] | None = None) -> None:
    state_path = _state_path(env)
    state_path.parent.mkdir(parents=True, exist_ok=True)
    state_path.write_text(json.dumps(state, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def _prune_entries(state: dict[str, Any], env: dict[str, str] | None = None, now: int | None = None) -> list[dict[str, Any]]:
    current = int(now or time.time())
    window_seconds = _window_hours(env) * 3600
    reservation_ttl = _reservation_ttl_seconds(env)
    cutoff = current - window_seconds
    pruned: list[dict[str, Any]] = []
    for raw in state.get("entries", []):
        if not isinstance(raw, dict):
            continue
        category = str(raw.get("category") or "").strip().lower()
        if category not in VALID_CATEGORIES:
            continue
        status = str(raw.get("status") or "").strip().lower()
        reserved_at = _to_int(raw.get("reserved_at"), 0)
        committed_at = _to_int(raw.get("committed_at"), 0)
        expires_at = _to_int(raw.get("expires_at"), 0)
        if status == "committed":
            ts = committed_at or reserved_at
            if ts <= 0 or ts < cutoff:
                continue
        elif status == "reserved":
            expiry = expires_at or (reserved_at + reservation_ttl)
            if reserved_at <= 0 or expiry < current:
                continue
        else:
            continue
        pruned.append(raw)
    state["entries"] = pruned
    state["updated_at"] = current
    return pruned


def _category_status(state: dict[str, Any], category: str, env: dict[str, str] | None = None, now: int | None = None) -> dict[str, Any]:
    if category not in VALID_CATEGORIES:
        raise ValueError(f"invalid category: {category}")
    current = int(now or time.time())
    limits = _limits(env)
    entries = state.get("entries", [])
    committed = [e for e in entries if e.get("category") == category and str(e.get("status")) == "committed"]
    reserved = [e for e in entries if e.get("category") == category and str(e.get("status")) == "reserved"]
    used = sum(max(0, _to_int(e.get("units"), 0)) for e in committed)
    pending = sum(max(0, _to_int(e.get("units"), 0)) for e in reserved)
    limit = max(0, limits.get(category, 0))
    unlimited = category == "text" and limit <= 0
    if unlimited:
        remaining = -1
    elif limit <= 0:
        remaining = 0
    else:
        remaining = max(0, limit - used - pending)
    reset_candidates = [
        (_to_int(e.get("committed_at"), 0) or _to_int(e.get("reserved_at"), 0)) + _window_hours(env) * 3600
        for e in committed
        if (_to_int(e.get("committed_at"), 0) or _to_int(e.get("reserved_at"), 0)) > 0
    ]
    reset_at = min(reset_candidates) if reset_candidates else current
    return {
        "category": category,
        "limit": limit,
        "used": used,
        "pending": pending,
        "remaining": remaining,
        "windowHours": _window_hours(env),
        "resetAt": reset_at,
        "enabled": True if unlimited else (limit > 0),
        "unlimited": unlimited,
    }


def get_quota_status(env: dict[str, str] | None = None, now: int | None = None) -> dict[str, Any]:
    current = int(now or time.time())
    with _file_lock(env):
        state = _load_state(env)
        _prune_entries(state, env, current)
        _save_state(state, env)
    return {
        "ok": True,
        "now": current,
        "stateFile": str(_state_path(env)),
        "image": _category_status(state, "image", env, current),
        "video": _category_status(state, "video", env, current),
        "text": _category_status(state, "text", env, current),
    }


def reserve_quota(category: str, units: int, env: dict[str, str] | None = None, tool: str = "", now: int | None = None) -> dict[str, Any]:
    normalized = str(category or "").strip().lower()
    if normalized not in VALID_CATEGORIES:
        raise ValueError(f"invalid category: {category}")
    requested_units = max(1, int(units))
    current = int(now or time.time())
    reservation_ttl = _reservation_ttl_seconds(env)
    with _file_lock(env):
        state = _load_state(env)
        _prune_entries(state, env, current)
        summary = _category_status(state, normalized, env, current)
        if not summary.get("unlimited") and summary["limit"] <= 0:
            _save_state(state, env)
            return {
                "ok": False,
                "reason": "disabled",
                "message": f"{normalized} quota disabled for current profile",
                "category": normalized,
                "requestedUnits": requested_units,
                "status": summary,
            }
        if not summary.get("unlimited") and summary["used"] + summary["pending"] + requested_units > summary["limit"]:
            _save_state(state, env)
            return {
                "ok": False,
                "reason": "quota_exceeded",
                "message": f"{normalized} quota exceeded: requested {requested_units}, remaining {summary['remaining']}",
                "category": normalized,
                "requestedUnits": requested_units,
                "status": summary,
            }
        reservation = {
            "id": uuid.uuid4().hex,
            "category": normalized,
            "units": requested_units,
            "status": "reserved",
            "reserved_at": current,
            "committed_at": 0,
            "expires_at": current + reservation_ttl,
            "tool": tool or "unknown",
        }
        state.setdefault("entries", []).append(reservation)
        _save_state(state, env)
        summary = _category_status(state, normalized, env, current)
        return {
            "ok": True,
            "reservation": reservation,
            "status": summary,
        }


def commit_quota(reservation_id: str, env: dict[str, str] | None = None, now: int | None = None) -> dict[str, Any]:
    current = int(now or time.time())
    with _file_lock(env):
        state = _load_state(env)
        _prune_entries(state, env, current)
        for entry in state.get("entries", []):
            if str(entry.get("id")) != str(reservation_id):
                continue
            if str(entry.get("status")) != "reserved":
                break
            entry["status"] = "committed"
            entry["committed_at"] = current
            entry["expires_at"] = current + _window_hours(env) * 3600
            _save_state(state, env)
            return {
                "ok": True,
                "reservation": entry,
                "status": _category_status(state, str(entry.get("category")), env, current),
            }
        _save_state(state, env)
    return {"ok": False, "reason": "reservation_not_found", "message": f"reservation not found: {reservation_id}"}


def release_quota(reservation_id: str, env: dict[str, str] | None = None, now: int | None = None) -> dict[str, Any]:
    current = int(now or time.time())
    with _file_lock(env):
        state = _load_state(env)
        _prune_entries(state, env, current)
        entries = state.get("entries", [])
        kept: list[dict[str, Any]] = []
        removed: dict[str, Any] | None = None
        for entry in entries:
            if str(entry.get("id")) == str(reservation_id) and str(entry.get("status")) == "reserved" and removed is None:
                removed = entry
                continue
            kept.append(entry)
        state["entries"] = kept
        _save_state(state, env)
        if removed:
            return {
                "ok": True,
                "reservation": removed,
                "status": _category_status(state, str(removed.get("category")), env, current),
            }
    return {"ok": False, "reason": "reservation_not_found", "message": f"reservation not found: {reservation_id}"}


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="OpenClaw local media quota controller")
    sub = parser.add_subparsers(dest="command", required=True)

    reserve = sub.add_parser("reserve")
    reserve.add_argument("--category", required=True, choices=sorted(VALID_CATEGORIES))
    reserve.add_argument("--units", type=int, default=1)
    reserve.add_argument("--tool", default="")

    commit = sub.add_parser("commit")
    commit.add_argument("--id", required=True)

    release = sub.add_parser("release")
    release.add_argument("--id", required=True)

    sub.add_parser("status")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)
    try:
        if args.command == "reserve":
            result = reserve_quota(args.category, args.units, tool=args.tool)
            print(json.dumps(result, ensure_ascii=False))
            return 0 if result.get("ok") else 2
        if args.command == "commit":
            result = commit_quota(args.id)
            print(json.dumps(result, ensure_ascii=False))
            return 0 if result.get("ok") else 3
        if args.command == "release":
            result = release_quota(args.id)
            print(json.dumps(result, ensure_ascii=False))
            return 0 if result.get("ok") else 4
        if args.command == "status":
            print(json.dumps(get_quota_status(), ensure_ascii=False))
            return 0
        parser.error("unknown command")
    except Exception as exc:
        print(json.dumps({"ok": False, "reason": "exception", "message": str(exc)}, ensure_ascii=False), file=sys.stderr)
        return 1
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
