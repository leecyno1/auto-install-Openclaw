#!/usr/bin/env python3
"""
Lobster Sanctum Studio - Projection API V2

Lightweight state/event service for runtime world projection.
No external dependencies required.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import threading
import time
import traceback
from datetime import datetime, timezone
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlparse


VALID_STATES = {"idle", "writing", "researching", "executing", "syncing", "error"}
VALID_PHASES = VALID_STATES
STATE_HINTS = {
    "idle": ["idle", "ready", "standby", "wait", "sleep", "空闲", "待命", "等待"],
    "writing": ["writing", "draft", "compose", "summary", "document", "写作", "整理", "总结"],
    "researching": ["research", "search", "lookup", "crawl", "fetch", "检索", "搜索", "调研", "查询"],
    "executing": ["execute", "executing", "run", "running", "tool", "coding", "build", "执行", "运行", "调用"],
    "syncing": ["sync", "deliver", "upload", "push", "commit", "同步", "推送", "交付", "提交"],
    "error": ["error", "failed", "fail", "panic", "exception", "timeout", "报错", "异常", "失败", "超时"],
}
ROOT_DIR = Path(__file__).resolve().parent
DATA_DIR = ROOT_DIR / "data"
STATE_FILE = DATA_DIR / "state.json"
EVENTS_FILE = DATA_DIR / "events.json"
AGENTS_FILE = DATA_DIR / "agents.json"
AGENT_EVENTS_FILE = DATA_DIR / "agent-events.json"
MISSIONS_FILE = DATA_DIR / "missions.json"
MAX_EVENTS = 1000
MAX_AGENT_EVENTS = 1000
MAX_EVENT_TEXT = 300
DEDUPE_TTL_SECONDS = 45
AGENT_DEDUPE_TTL_SECONDS = 20
AGENT_STALE_SECONDS = 120
VALID_MISSION_STATUS = {"pending", "running", "blocked", "done", "canceled"}


state_lock = threading.RLock()
state_cond = threading.Condition(state_lock)

runtime_state: dict[str, Any] = {}
runtime_events: list[dict[str, Any]] = []
next_event_id = 1
signature_index: dict[str, dict[str, Any]] = {}
runtime_agents: dict[str, dict[str, Any]] = {}
agent_events: list[dict[str, Any]] = []
next_agent_event_id = 1
agent_signature_index: dict[str, dict[str, Any]] = {}
runtime_missions: list[dict[str, Any]] = []


def now_iso() -> str:
    return datetime.now(timezone.utc).astimezone().isoformat()


def ensure_data_dir() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)


def default_state() -> dict[str, Any]:
    return {
        "state": "idle",
        "phase": "idle",
        "detail": "projection api ready",
        "progress": 0,
        "source": "projection-api",
        "task_id": "",
        "tool": "",
        "model": "",
        "latency_ms": None,
        "error_code": "",
        "agent_id": "",
        "last_event_id": 0,
        "event_signature": "",
        "updated_at": now_iso(),
    }


def safe_int(value: Any, fallback: int = 0) -> int:
    try:
        return int(value)
    except Exception:
        return fallback


def safe_text(value: Any, fallback: str = "") -> str:
    text = str(value).strip() if value is not None else ""
    return text or fallback


def clamp_progress(value: Any, fallback: int = 0) -> int:
    return max(0, min(100, safe_int(value, fallback)))


def parse_epoch_from_iso(value: Any) -> float:
    text = safe_text(value)
    if not text:
        return 0.0
    try:
        return datetime.fromisoformat(text.replace("Z", "+00:00")).timestamp()
    except Exception:
        return 0.0


def find_by_path(payload: dict[str, Any], path: str) -> Any:
    cur: Any = payload
    for chunk in path.split("."):
        key = chunk.strip()
        if not key:
            return None
        if not isinstance(cur, dict) or key not in cur:
            return None
        cur = cur[key]
    return cur


def first_value(payload: dict[str, Any], candidates: list[str]) -> Any:
    for key in candidates:
        if "." in key:
            val = find_by_path(payload, key)
            if val is not None and val != "":
                return val
        elif key in payload and payload[key] not in (None, ""):
            return payload[key]
    return None


def infer_state_from_text(text: Any) -> str | None:
    low = safe_text(text).lower()
    if not low:
        return None
    for state, hints in STATE_HINTS.items():
        if any(hint in low for hint in hints):
            return state
    return None


def normalize_state_phase(raw_state: Any, raw_phase: Any, detail: Any, message: Any) -> tuple[str, str]:
    state = safe_text(raw_state).lower()
    phase = safe_text(raw_phase).lower()

    if state not in VALID_STATES:
        state = ""
    if phase not in VALID_PHASES:
        phase = ""

    if not state:
        state = infer_state_from_text(raw_phase) or infer_state_from_text(raw_state)
    if not state:
        state = infer_state_from_text(detail) or infer_state_from_text(message)
    if not state:
        state = "idle"

    if not phase:
        phase = infer_state_from_text(raw_phase) or state
    if phase not in VALID_PHASES:
        phase = state
    if phase not in VALID_PHASES:
        phase = "idle"
    return state, phase


def truncate_text(text: Any, limit: int = MAX_EVENT_TEXT) -> str:
    val = safe_text(text)
    if len(val) <= limit:
        return val
    return val[: limit - 1] + "…"


def compute_signature(event: dict[str, Any]) -> str:
    canonical = {
        "type": safe_text(event.get("type"), "log").lower(),
        "source": safe_text(event.get("source"), "projection-api").lower(),
        "task_id": safe_text(event.get("task_id")).lower(),
        "agent_id": safe_text(event.get("agent_id")).lower(),
        "state": safe_text(event.get("state")).lower(),
        "phase": safe_text(event.get("phase")).lower(),
        "tool": safe_text(event.get("tool")).lower(),
        "model": safe_text(event.get("model")).lower(),
        "message": truncate_text(event.get("message"), 180),
        "detail": truncate_text(event.get("detail"), 220),
        "progress": event.get("progress"),
        "error_code": safe_text(event.get("error_code")).lower(),
        "latency_ms": event.get("latency_ms"),
    }
    payload = json.dumps(canonical, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha1(payload.encode("utf-8")).hexdigest()


def normalize_state_payload(payload: dict[str, Any], base: dict[str, Any] | None = None) -> dict[str, Any]:
    base = base or default_state()
    state, phase = normalize_state_phase(
        payload.get("state", base.get("state", "idle")),
        payload.get("phase", base.get("phase", "")),
        payload.get("detail", base.get("detail", "")),
        payload.get("message", ""),
    )
    detail = safe_text(payload.get("detail"), safe_text(payload.get("message"), f"{state} in progress"))
    if not detail:
        detail = safe_text(base.get("detail"), f"{state} in progress")
    progress = max(0, min(100, safe_int(payload.get("progress", 0), 0)))
    source = safe_text(payload.get("source"), safe_text(base.get("source"), "projection-api"))
    updated_at = safe_text(payload.get("updated_at"), now_iso())
    task_id = safe_text(payload.get("task_id"), safe_text(base.get("task_id")))
    tool = safe_text(payload.get("tool"), safe_text(base.get("tool")))
    model = safe_text(payload.get("model"), safe_text(base.get("model")))
    latency_raw = payload.get("latency_ms", base.get("latency_ms"))
    latency_ms = None
    if latency_raw not in (None, ""):
        latency_ms = max(0, safe_int(latency_raw, 0))
    error_code = safe_text(payload.get("error_code"), safe_text(base.get("error_code")))
    agent_id = safe_text(payload.get("agent_id"), safe_text(base.get("agent_id")))
    last_event_id = safe_int(payload.get("last_event_id", base.get("last_event_id", 0)), 0)
    event_signature = safe_text(payload.get("event_signature"), safe_text(base.get("event_signature")))
    return {
        "state": state,
        "phase": phase,
        "detail": detail,
        "progress": progress,
        "source": source,
        "task_id": task_id,
        "tool": tool,
        "model": model,
        "latency_ms": latency_ms,
        "error_code": error_code,
        "agent_id": agent_id,
        "last_event_id": last_event_id,
        "event_signature": event_signature,
        "updated_at": updated_at,
    }


def normalize_event_payload(payload: dict[str, Any]) -> dict[str, Any]:
    state, phase = normalize_state_phase(payload.get("state"), payload.get("phase"), payload.get("detail"), payload.get("message"))
    event_type = safe_text(payload.get("type"), "log").lower()
    message = truncate_text(payload.get("message"), 280)
    detail = truncate_text(payload.get("detail"), 360)
    source = safe_text(payload.get("source"), "projection-api")
    progress = payload.get("progress")
    norm_progress = None
    if progress is not None:
        norm_progress = clamp_progress(progress, 0)
    latency_raw = payload.get("latency_ms", payload.get("latency"))
    latency_ms = None
    if latency_raw not in (None, ""):
        latency_ms = max(0, safe_int(latency_raw, 0))
    task_id = safe_text(payload.get("task_id", payload.get("taskId", payload.get("run_id", payload.get("session_id", "")))))
    tool = safe_text(payload.get("tool", payload.get("tool_name", payload.get("skill", payload.get("mcp", "")))))
    model = safe_text(payload.get("model", payload.get("model_name", "")))
    error_code = safe_text(payload.get("error_code", payload.get("code", "")))
    agent_id = safe_text(payload.get("agent_id", payload.get("worker_id", payload.get("agent", ""))))
    event: dict[str, Any] = {
        "type": event_type,
        "message": message,
        "detail": detail,
        "state": state,
        "phase": phase,
        "progress": norm_progress,
        "task_id": task_id or None,
        "tool": tool or None,
        "model": model or None,
        "latency_ms": latency_ms,
        "error_code": error_code or None,
        "agent_id": agent_id or None,
        "source": source,
        "created_at": now_iso(),
    }
    idempotency_key = safe_text(payload.get("idempotency_key", payload.get("event_id", payload.get("trace_id", payload.get("request_id", "")))))
    event["signature"] = idempotency_key or compute_signature(event)
    return event


def map_raw_payload_to_event(payload: dict[str, Any]) -> dict[str, Any]:
    raw = payload.get("raw")
    raw_payload = raw if isinstance(raw, dict) else payload
    if not isinstance(raw_payload, dict):
        raise ValueError("raw payload must be object")

    mapped = {
        "type": first_value(raw_payload, ["type", "event", "kind", "runtime.type"]) or "runtime",
        "source": safe_text(payload.get("source"), safe_text(first_value(raw_payload, ["source"]), "openclaw-bridge")),
        "state": first_value(raw_payload, ["state", "status", "runtime.state", "runtime.status", "agent.state", "agent.status"]),
        "phase": first_value(raw_payload, ["phase", "stage", "runtime.phase", "task.phase"]),
        "message": first_value(raw_payload, ["message", "text", "summary", "log", "runtime.message", "statusText"]),
        "detail": first_value(raw_payload, ["detail", "runtime.detail", "task.detail", "description", "reason"]),
        "progress": first_value(raw_payload, ["progress", "pct", "percent", "runtime.progress", "task.progress"]),
        "task_id": first_value(raw_payload, ["task_id", "task.id", "run_id", "session_id", "trace_id"]),
        "tool": first_value(raw_payload, ["tool", "tool.name", "tool_name", "skill", "mcp"]),
        "model": first_value(raw_payload, ["model", "model_name", "llm.model"]),
        "latency_ms": first_value(raw_payload, ["latency_ms", "duration_ms", "elapsed_ms", "latency", "duration"]),
        "error_code": first_value(raw_payload, ["error_code", "error.code", "error.type", "code"]),
        "agent_id": first_value(raw_payload, ["agent_id", "agent.id", "worker_id", "runner"]),
        "idempotency_key": first_value(raw_payload, ["idempotency_key", "event_id", "trace_id", "request_id"]),
    }
    return normalize_event_payload(mapped)


def compute_agent_signature(agent: dict[str, Any]) -> str:
    canonical = {
        "agent_id": safe_text(agent.get("agent_id")).lower(),
        "name": safe_text(agent.get("name")).lower(),
        "role": safe_text(agent.get("role")).lower(),
        "state": safe_text(agent.get("state")).lower(),
        "phase": safe_text(agent.get("phase")).lower(),
        "detail": truncate_text(agent.get("detail"), 220),
        "progress": agent.get("progress"),
        "task_id": safe_text(agent.get("task_id")).lower(),
        "tool": safe_text(agent.get("tool")).lower(),
        "model": safe_text(agent.get("model")).lower(),
        "latency_ms": agent.get("latency_ms"),
        "error_code": safe_text(agent.get("error_code")).lower(),
        "source": safe_text(agent.get("source")).lower(),
    }
    payload = json.dumps(canonical, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha1(payload.encode("utf-8")).hexdigest()


def normalize_agent_payload(payload: dict[str, Any], base: dict[str, Any] | None = None) -> dict[str, Any]:
    base = base or {}
    state, phase = normalize_state_phase(
        payload.get("state", base.get("state", "idle")),
        payload.get("phase", base.get("phase", "")),
        payload.get("detail", base.get("detail", "")),
        payload.get("message", ""),
    )
    progress = clamp_progress(payload.get("progress", base.get("progress", 0)), base.get("progress", 0) or 0)
    agent_id = safe_text(
        payload.get("agent_id", payload.get("id", payload.get("worker_id", payload.get("name", base.get("agent_id", ""))))),
        "",
    )
    if not agent_id:
        agent_id = f"agent-{int(time.time() * 1000)}"
    name = safe_text(payload.get("name"), safe_text(base.get("name"), agent_id))
    role = safe_text(payload.get("role"), safe_text(base.get("role"), "worker"))
    source = safe_text(payload.get("source"), safe_text(base.get("source"), "projection-api"))
    detail = truncate_text(payload.get("detail", payload.get("message", base.get("detail", ""))), 280)
    task_id = safe_text(payload.get("task_id", payload.get("taskId", base.get("task_id", ""))))
    tool = safe_text(payload.get("tool", payload.get("tool_name", payload.get("skill", base.get("tool", "")))))
    model = safe_text(payload.get("model", payload.get("model_name", base.get("model", ""))))
    latency_raw = payload.get("latency_ms", payload.get("latency", base.get("latency_ms")))
    latency_ms = None
    if latency_raw not in (None, ""):
        latency_ms = max(0, safe_int(latency_raw, 0))
    error_code = safe_text(payload.get("error_code", payload.get("code", base.get("error_code", ""))))
    level = max(1, safe_int(payload.get("level", base.get("level", 1)), 1))
    updated_at = safe_text(payload.get("updated_at"), now_iso())
    last_seen = safe_text(payload.get("last_seen"), updated_at)
    status = safe_text(payload.get("status", base.get("status", "online")), "online").lower()
    if status not in {"online", "offline"}:
        status = "online"
    agent = {
        "agent_id": agent_id,
        "name": name,
        "role": role,
        "state": state,
        "phase": phase,
        "detail": detail,
        "progress": progress,
        "task_id": task_id,
        "tool": tool,
        "model": model,
        "latency_ms": latency_ms,
        "error_code": error_code,
        "level": level,
        "source": source,
        "status": status,
        "last_seen": last_seen,
        "updated_at": updated_at,
    }
    signature = safe_text(payload.get("signature"))
    agent["signature"] = signature or compute_agent_signature(agent)
    return agent


def normalize_agent_event_payload(payload: dict[str, Any]) -> dict[str, Any]:
    event_type = safe_text(payload.get("type"), "heartbeat").lower()
    agent_id = safe_text(payload.get("agent_id"))
    state, phase = normalize_state_phase(payload.get("state"), payload.get("phase"), payload.get("detail"), payload.get("message"))
    progress = payload.get("progress")
    norm_progress = None
    if progress is not None:
        norm_progress = clamp_progress(progress, 0)
    event = {
        "type": event_type,
        "agent_id": agent_id,
        "name": safe_text(payload.get("name")),
        "role": safe_text(payload.get("role")),
        "state": state,
        "phase": phase,
        "detail": truncate_text(payload.get("detail", payload.get("message")), 280),
        "progress": norm_progress,
        "task_id": safe_text(payload.get("task_id")),
        "tool": safe_text(payload.get("tool")),
        "model": safe_text(payload.get("model")),
        "error_code": safe_text(payload.get("error_code")),
        "source": safe_text(payload.get("source"), "projection-api"),
        "created_at": now_iso(),
    }
    idempotency_key = safe_text(payload.get("idempotency_key", payload.get("event_id", payload.get("request_id", ""))))
    event["signature"] = idempotency_key or compute_signature(event)
    return event


def normalize_mission_payload(payload: dict[str, Any], base: dict[str, Any] | None = None) -> dict[str, Any]:
    base = base or {}
    mission_id = safe_text(payload.get("mission_id", payload.get("id", base.get("mission_id", ""))))
    if not mission_id:
        mission_id = f"mission-{int(time.time() * 1000)}"
    title = truncate_text(payload.get("title", base.get("title", mission_id)), 120)
    status = safe_text(payload.get("status", base.get("status", "pending")), "pending").lower()
    if status not in VALID_MISSION_STATUS:
        status = "pending"
    progress = clamp_progress(payload.get("progress", base.get("progress", 0)), base.get("progress", 0) or 0)
    owner_agent_id = safe_text(payload.get("owner_agent_id", payload.get("owner", base.get("owner_agent_id", ""))))
    summary = truncate_text(payload.get("summary", payload.get("detail", base.get("summary", ""))), 240)
    source = safe_text(payload.get("source"), safe_text(base.get("source"), "projection-api"))
    updated_at = safe_text(payload.get("updated_at"), now_iso())
    created_at = safe_text(payload.get("created_at"), safe_text(base.get("created_at"), updated_at))
    mission = {
        "mission_id": mission_id,
        "title": title,
        "status": status,
        "progress": progress,
        "owner_agent_id": owner_agent_id,
        "summary": summary,
        "source": source,
        "created_at": created_at,
        "updated_at": updated_at,
    }
    return mission


def persist_state() -> None:
    STATE_FILE.write_text(json.dumps(runtime_state, ensure_ascii=False, indent=2), encoding="utf-8")


def persist_events() -> None:
    EVENTS_FILE.write_text(json.dumps(runtime_events, ensure_ascii=False, indent=2), encoding="utf-8")


def persist_agents() -> None:
    rows = list(runtime_agents.values())
    AGENTS_FILE.write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8")


def persist_agent_events() -> None:
    AGENT_EVENTS_FILE.write_text(json.dumps(agent_events, ensure_ascii=False, indent=2), encoding="utf-8")


def persist_missions() -> None:
    MISSIONS_FILE.write_text(json.dumps(runtime_missions, ensure_ascii=False, indent=2), encoding="utf-8")


def find_event_by_id(event_id: int) -> dict[str, Any] | None:
    for item in reversed(runtime_events):
        if safe_int(item.get("id"), -1) == event_id:
            return item
    return None


def find_agent_event_by_id(event_id: int) -> dict[str, Any] | None:
    for item in reversed(agent_events):
        if safe_int(item.get("id"), -1) == event_id:
            return item
    return None


def prune_signature_index(now_ts: float) -> None:
    expired = [key for key, ref in signature_index.items() if now_ts - float(ref.get("ts", 0.0)) > DEDUPE_TTL_SECONDS * 4]
    for key in expired:
        signature_index.pop(key, None)


def prune_agent_signature_index(now_ts: float) -> None:
    expired = [key for key, ref in agent_signature_index.items() if now_ts - float(ref.get("ts", 0.0)) > AGENT_DEDUPE_TTL_SECONDS * 8]
    for key in expired:
        agent_signature_index.pop(key, None)


def append_event(event: dict[str, Any]) -> tuple[dict[str, Any], bool]:
    global next_event_id
    now_ts = time.time()
    signature = safe_text(event.get("signature"))
    if signature:
        hit = signature_index.get(signature)
        if hit and now_ts - float(hit.get("ts", 0.0)) <= DEDUPE_TTL_SECONDS:
            exist = find_event_by_id(safe_int(hit.get("id"), -1))
            if exist is not None:
                return exist, True

    event_obj = {
        "id": next_event_id,
        "seq": next_event_id,
        **event,
    }
    next_event_id += 1
    runtime_events.append(event_obj)
    if len(runtime_events) > MAX_EVENTS:
        del runtime_events[:-MAX_EVENTS]
    if signature:
        signature_index[signature] = {"id": event_obj["id"], "ts": now_ts}
    if len(signature_index) > MAX_EVENTS * 2:
        prune_signature_index(now_ts)
    persist_events()
    state_cond.notify_all()
    return event_obj, False


def append_agent_event(event: dict[str, Any]) -> tuple[dict[str, Any], bool]:
    global next_agent_event_id
    now_ts = time.time()
    signature = safe_text(event.get("signature"))
    if signature:
        hit = agent_signature_index.get(signature)
        if hit and now_ts - float(hit.get("ts", 0.0)) <= AGENT_DEDUPE_TTL_SECONDS:
            exist = find_agent_event_by_id(safe_int(hit.get("id"), -1))
            if exist is not None:
                return exist, True

    event_obj = {
        "id": next_agent_event_id,
        "seq": next_agent_event_id,
        **event,
    }
    next_agent_event_id += 1
    agent_events.append(event_obj)
    if len(agent_events) > MAX_AGENT_EVENTS:
        del agent_events[:-MAX_AGENT_EVENTS]
    if signature:
        agent_signature_index[signature] = {"id": event_obj["id"], "ts": now_ts}
    if len(agent_signature_index) > MAX_AGENT_EVENTS * 2:
        prune_agent_signature_index(now_ts)
    persist_agent_events()
    state_cond.notify_all()
    return event_obj, False


def apply_event_to_state(event: dict[str, Any]) -> None:
    runtime_state["state"] = event.get("state") or runtime_state.get("state", "idle")
    runtime_state["phase"] = event.get("phase") or runtime_state.get("phase", runtime_state["state"])
    if event.get("detail"):
        runtime_state["detail"] = event["detail"]
    elif event.get("message"):
        runtime_state["detail"] = event["message"]
    if event.get("progress") is not None:
        runtime_state["progress"] = clamp_progress(event.get("progress"), runtime_state.get("progress", 0))
    runtime_state["source"] = event.get("source") or runtime_state.get("source", "projection-api")
    if event.get("task_id"):
        runtime_state["task_id"] = event["task_id"]
    if event.get("tool"):
        runtime_state["tool"] = event["tool"]
    if event.get("model"):
        runtime_state["model"] = event["model"]
    if event.get("latency_ms") is not None:
        runtime_state["latency_ms"] = max(0, safe_int(event["latency_ms"], 0))
    if event.get("error_code"):
        runtime_state["error_code"] = event["error_code"]
    elif runtime_state["state"] != "error":
        runtime_state["error_code"] = ""
    if event.get("agent_id"):
        runtime_state["agent_id"] = event["agent_id"]
    runtime_state["last_event_id"] = safe_int(event.get("id"), runtime_state.get("last_event_id", 0))
    runtime_state["event_signature"] = safe_text(event.get("signature"))
    runtime_state["updated_at"] = now_iso()


def apply_agent_to_runtime(agent: dict[str, Any]) -> None:
    runtime_agents[agent["agent_id"]] = agent
    persist_agents()


def upsert_mission(mission: dict[str, Any]) -> dict[str, Any]:
    for idx, item in enumerate(runtime_missions):
        if safe_text(item.get("mission_id")) == mission["mission_id"]:
            runtime_missions[idx] = mission
            persist_missions()
            return mission
    runtime_missions.append(mission)
    if len(runtime_missions) > 500:
        del runtime_missions[:-500]
    persist_missions()
    return mission


def rebuild_agent_signature_index() -> None:
    agent_signature_index.clear()
    for item in agent_events:
        signature = safe_text(item.get("signature"))
        if not signature:
            continue
        ts = parse_epoch_from_iso(item.get("created_at"))
        agent_signature_index[signature] = {"id": safe_int(item.get("id"), 0), "ts": ts or time.time()}


def mark_stale_agents() -> None:
    now_ts = time.time()
    changed = False
    for agent in runtime_agents.values():
        last_seen_ts = parse_epoch_from_iso(agent.get("last_seen"))
        if last_seen_ts <= 0:
            continue
        is_stale = now_ts - last_seen_ts > AGENT_STALE_SECONDS
        if is_stale and agent.get("status") != "offline":
            agent["status"] = "offline"
            agent["updated_at"] = now_iso()
            changed = True
    if changed:
        persist_agents()


def mission_summary() -> dict[str, int]:
    rows = runtime_missions
    return {
        "total": len(rows),
        "pending": sum(1 for item in rows if item.get("status") == "pending"),
        "running": sum(1 for item in rows if item.get("status") == "running"),
        "blocked": sum(1 for item in rows if item.get("status") == "blocked"),
        "done": sum(1 for item in rows if item.get("status") == "done"),
        "canceled": sum(1 for item in rows if item.get("status") == "canceled"),
    }


def rebuild_signature_index() -> None:
    signature_index.clear()
    for item in runtime_events:
        signature = safe_text(item.get("signature"))
        if not signature:
            continue
        ts = parse_epoch_from_iso(item.get("created_at"))
        signature_index[signature] = {
            "id": safe_int(item.get("id"), 0),
            "ts": ts or time.time(),
        }


def load_data() -> None:
    global runtime_state, runtime_events, next_event_id, runtime_agents, runtime_missions, agent_events, next_agent_event_id
    ensure_data_dir()
    with state_lock:
        if STATE_FILE.exists():
            try:
                runtime_state = normalize_state_payload(json.loads(STATE_FILE.read_text(encoding="utf-8")))
            except Exception:
                runtime_state = default_state()
        else:
            runtime_state = default_state()
            persist_state()

        if EVENTS_FILE.exists():
            try:
                data = json.loads(EVENTS_FILE.read_text(encoding="utf-8"))
                runtime_events = data if isinstance(data, list) else []
            except Exception:
                runtime_events = []
        else:
            runtime_events = []
            persist_events()

        normalized_events: list[dict[str, Any]] = []
        assigned_id = 1
        for item in runtime_events:
            if not isinstance(item, dict):
                continue
            event = dict(item)
            event_id = safe_int(event.get("id"), assigned_id)
            if event_id <= 0:
                event_id = assigned_id
            event["id"] = event_id
            event["seq"] = safe_int(event.get("seq"), event_id)
            event["created_at"] = safe_text(event.get("created_at"), now_iso())
            if not safe_text(event.get("signature")):
                event["signature"] = compute_signature(event)
            normalized_events.append(event)
            assigned_id = max(assigned_id + 1, event_id + 1)
        runtime_events = normalized_events[-MAX_EVENTS:]

        if runtime_events:
            max_id = max(int(item.get("id", 0)) for item in runtime_events)
            next_event_id = max_id + 1
        else:
            next_event_id = 1
        rebuild_signature_index()

        if AGENTS_FILE.exists():
            try:
                data = json.loads(AGENTS_FILE.read_text(encoding="utf-8"))
                rows = data if isinstance(data, list) else []
            except Exception:
                rows = []
        else:
            rows = []
            persist_agents()

        runtime_agents = {}
        for item in rows:
            if not isinstance(item, dict):
                continue
            agent = normalize_agent_payload(item, item)
            runtime_agents[agent["agent_id"]] = agent
        persist_agents()

        if AGENT_EVENTS_FILE.exists():
            try:
                data = json.loads(AGENT_EVENTS_FILE.read_text(encoding="utf-8"))
                rows = data if isinstance(data, list) else []
            except Exception:
                rows = []
        else:
            rows = []
            persist_agent_events()

        normalized_agent_events: list[dict[str, Any]] = []
        assigned_agent_event_id = 1
        for item in rows:
            if not isinstance(item, dict):
                continue
            event = dict(item)
            event_id = safe_int(event.get("id"), assigned_agent_event_id)
            if event_id <= 0:
                event_id = assigned_agent_event_id
            event["id"] = event_id
            event["seq"] = safe_int(event.get("seq"), event_id)
            event["created_at"] = safe_text(event.get("created_at"), now_iso())
            if not safe_text(event.get("signature")):
                event["signature"] = compute_signature(event)
            normalized_agent_events.append(event)
            assigned_agent_event_id = max(assigned_agent_event_id + 1, event_id + 1)
        agent_events = normalized_agent_events[-MAX_AGENT_EVENTS:]
        if agent_events:
            max_agent_id = max(int(item.get("id", 0)) for item in agent_events)
            next_agent_event_id = max_agent_id + 1
        else:
            next_agent_event_id = 1
        rebuild_agent_signature_index()
        persist_agent_events()

        if MISSIONS_FILE.exists():
            try:
                data = json.loads(MISSIONS_FILE.read_text(encoding="utf-8"))
                rows = data if isinstance(data, list) else []
            except Exception:
                rows = []
        else:
            rows = []
            persist_missions()

        runtime_missions = []
        for item in rows:
            if not isinstance(item, dict):
                continue
            runtime_missions.append(normalize_mission_payload(item, item))
        if len(runtime_missions) > 500:
            runtime_missions = runtime_missions[-500:]
        persist_missions()


class ProjectionHandler(BaseHTTPRequestHandler):
    server_version = "LobsterProjectionAPI/2.0"

    def log_message(self, format: str, *args: Any) -> None:
        return

    def _set_common_headers(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
        self.send_header("Cache-Control", "no-store")

    def _send_json(self, status: int, payload: dict[str, Any]) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self._set_common_headers()
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _read_json(self) -> dict[str, Any]:
        length = int(self.headers.get("Content-Length", "0"))
        if length <= 0:
            return {}
        raw = self.rfile.read(length)
        if not raw:
            return {}
        parsed = json.loads(raw.decode("utf-8"))
        return parsed if isinstance(parsed, dict) else {}

    def do_OPTIONS(self) -> None:
        self.send_response(HTTPStatus.NO_CONTENT)
        self._set_common_headers()
        self.end_headers()

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        path = parsed.path

        if path == "/health":
            self._send_json(HTTPStatus.OK, {"ok": True, "service": "projection-api", "time": now_iso()})
            return

        if path == "/runtime/state":
            with state_lock:
                self._send_json(
                    HTTPStatus.OK,
                    {
                        "ok": True,
                        "data": runtime_state,
                        "event_count": len(runtime_events),
                    },
                )
            return

        if path == "/runtime/events":
            query = parse_qs(parsed.query or "")
            limit = max(1, min(500, safe_int(query.get("limit", ["50"])[0], 50)))
            since_id = max(0, safe_int(query.get("since_id", ["0"])[0], 0))
            with state_lock:
                rows = runtime_events
                if since_id > 0:
                    rows = [item for item in rows if safe_int(item.get("id"), 0) > since_id]
                self._send_json(
                    HTTPStatus.OK,
                    {
                        "ok": True,
                        "data": rows[-limit:],
                        "total": len(runtime_events),
                        "since_id": since_id,
                    },
                )
            return

        if path == "/runtime/agents":
            with state_lock:
                mark_stale_agents()
                query = parse_qs(parsed.query or "")
                include_offline = safe_text(query.get("include_offline", ["1"])[0], "1") not in {"0", "false", "no"}
                rows = list(runtime_agents.values())
                if not include_offline:
                    rows = [item for item in rows if item.get("status") == "online"]
                rows.sort(
                    key=lambda item: (
                        0 if item.get("status") == "online" else 1,
                        -parse_epoch_from_iso(item.get("last_seen")),
                        item.get("agent_id", ""),
                    )
                )
                self._send_json(
                    HTTPStatus.OK,
                    {
                        "ok": True,
                        "data": rows,
                        "summary": {
                            "total": len(runtime_agents),
                            "online": sum(1 for item in runtime_agents.values() if item.get("status") == "online"),
                            "offline": sum(1 for item in runtime_agents.values() if item.get("status") == "offline"),
                        },
                    },
                )
            return

        if path == "/runtime/missions":
            with state_lock:
                rows = list(runtime_missions)
                rows.sort(key=lambda item: parse_epoch_from_iso(item.get("updated_at")), reverse=True)
                self._send_json(
                    HTTPStatus.OK,
                    {
                        "ok": True,
                        "data": rows,
                        "summary": mission_summary(),
                    },
                )
            return

        if path == "/runtime/stream":
            self._handle_stream(parsed)
            return

        if path == "/runtime/agents/stream":
            self._handle_agents_stream(parsed)
            return

        self._send_json(HTTPStatus.NOT_FOUND, {"ok": False, "error": "not found"})

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        path = parsed.path
        try:
            payload = self._read_json()
        except json.JSONDecodeError:
            self._send_json(HTTPStatus.BAD_REQUEST, {"ok": False, "error": "invalid json"})
            return

        if path == "/runtime/state":
            try:
                with state_lock:
                    norm = normalize_state_payload(payload, runtime_state)
            except ValueError as exc:
                self._send_json(HTTPStatus.BAD_REQUEST, {"ok": False, "error": str(exc)})
                return

            with state_lock:
                runtime_state.update(norm)
                state_event = normalize_event_payload(
                    {
                        "type": "state",
                        "message": f"state -> {runtime_state['state']}",
                        "detail": runtime_state["detail"],
                        "state": runtime_state["state"],
                        "phase": runtime_state.get("phase", runtime_state["state"]),
                        "progress": runtime_state["progress"],
                        "source": runtime_state["source"],
                        "task_id": runtime_state.get("task_id"),
                        "tool": runtime_state.get("tool"),
                        "model": runtime_state.get("model"),
                        "latency_ms": runtime_state.get("latency_ms"),
                        "error_code": runtime_state.get("error_code"),
                        "agent_id": runtime_state.get("agent_id"),
                        "idempotency_key": payload.get("idempotency_key"),
                    }
                )
                event, deduped = append_event(state_event)
                runtime_state["last_event_id"] = safe_int(event.get("id"), runtime_state.get("last_event_id", 0))
                runtime_state["event_signature"] = safe_text(event.get("signature"))
                runtime_state["updated_at"] = now_iso()
                persist_state()
                self._send_json(
                    HTTPStatus.OK,
                    {
                        "ok": True,
                        "data": runtime_state,
                        "event": event,
                        "deduplicated": deduped,
                    },
                )
            return

        if path == "/runtime/events":
            norm = normalize_event_payload(payload)
            with state_lock:
                event, deduped = append_event(norm)
                apply_event_to_state(event)
                persist_state()
                self._send_json(
                    HTTPStatus.OK,
                    {
                        "ok": True,
                        "event": event,
                        "state": runtime_state,
                        "deduplicated": deduped,
                    },
                )
            return

        if path == "/runtime/ingest":
            try:
                mapped = map_raw_payload_to_event(payload)
            except ValueError as exc:
                self._send_json(HTTPStatus.BAD_REQUEST, {"ok": False, "error": str(exc)})
                return

            with state_lock:
                event, deduped = append_event(mapped)
                apply_event_to_state(event)
                persist_state()
                self._send_json(
                    HTTPStatus.OK,
                    {
                        "ok": True,
                        "event": event,
                        "state": runtime_state,
                        "deduplicated": deduped,
                    },
                )
            return

        if path == "/runtime/agents":
            with state_lock:
                source = safe_text(payload.get("source"), "projection-api")
                rows = payload.get("agents")
                if isinstance(rows, list):
                    incoming_rows = [item for item in rows if isinstance(item, dict)]
                else:
                    incoming_rows = [payload]

                updated: list[dict[str, Any]] = []
                deduped_count = 0
                for item in incoming_rows:
                    merged = dict(item)
                    merged["source"] = safe_text(merged.get("source"), source)
                    explicit_action = safe_text(merged.get("action")).lower()
                    if explicit_action == "leave":
                        merged["status"] = "offline"
                    base = runtime_agents.get(safe_text(merged.get("agent_id", merged.get("id", merged.get("name", "")))), {})
                    agent = normalize_agent_payload(merged, base)
                    previous = runtime_agents.get(agent["agent_id"])
                    apply_agent_to_runtime(agent)
                    event_type = "join" if previous is None else "heartbeat"
                    if previous is not None and previous.get("status") != "offline" and agent.get("status") == "offline":
                        event_type = "leave"
                    elif previous is not None and previous.get("signature") != agent.get("signature"):
                        event_type = "update"
                    event_payload = normalize_agent_event_payload(
                        {
                            "type": event_type,
                            "agent_id": agent["agent_id"],
                            "name": agent.get("name"),
                            "role": agent.get("role"),
                            "state": agent.get("state"),
                            "phase": agent.get("phase"),
                            "detail": agent.get("detail"),
                            "progress": agent.get("progress"),
                            "task_id": agent.get("task_id"),
                            "tool": agent.get("tool"),
                            "model": agent.get("model"),
                            "error_code": agent.get("error_code"),
                            "source": agent.get("source"),
                            "idempotency_key": agent.get("signature"),
                        }
                    )
                    _, deduped = append_agent_event(event_payload)
                    if deduped:
                        deduped_count += 1
                    updated.append(agent)

                self._send_json(
                    HTTPStatus.OK,
                    {
                        "ok": True,
                        "updated": updated,
                        "updated_count": len(updated),
                        "deduplicated_count": deduped_count,
                        "summary": {
                            "total": len(runtime_agents),
                            "online": sum(1 for item in runtime_agents.values() if item.get("status") == "online"),
                            "offline": sum(1 for item in runtime_agents.values() if item.get("status") == "offline"),
                        },
                    },
                )
            return

        if path == "/runtime/missions":
            with state_lock:
                source = safe_text(payload.get("source"), "projection-api")
                rows = payload.get("missions")
                if isinstance(rows, list):
                    incoming_rows = [item for item in rows if isinstance(item, dict)]
                else:
                    incoming_rows = [payload]
                updated: list[dict[str, Any]] = []
                for item in incoming_rows:
                    merged = dict(item)
                    merged["source"] = safe_text(merged.get("source"), source)
                    mission_id = safe_text(merged.get("mission_id", merged.get("id")))
                    base = {}
                    if mission_id:
                        for current in runtime_missions:
                            if safe_text(current.get("mission_id")) == mission_id:
                                base = current
                                break
                    mission = normalize_mission_payload(merged, base)
                    updated.append(upsert_mission(mission))
                self._send_json(
                    HTTPStatus.OK,
                    {
                        "ok": True,
                        "updated": updated,
                        "updated_count": len(updated),
                        "summary": mission_summary(),
                    },
                )
            return

        self._send_json(HTTPStatus.NOT_FOUND, {"ok": False, "error": "not found"})

    def _handle_stream(self, parsed: Any) -> None:
        query = parse_qs(parsed.query or "")
        since_id = max(0, safe_int(query.get("since_id", ["0"])[0], 0))
        if since_id <= 0:
            since_id = max(0, safe_int(self.headers.get("Last-Event-ID", "0"), 0))

        self.send_response(HTTPStatus.OK)
        self._set_common_headers()
        self.send_header("Content-Type", "text/event-stream; charset=utf-8")
        self.send_header("Connection", "keep-alive")
        self.end_headers()

        try:
            # Initial handshake event
            init_payload = {"ok": True, "type": "hello", "time": now_iso()}
            self.wfile.write(f"event: hello\ndata: {json.dumps(init_payload, ensure_ascii=False)}\n\n".encode("utf-8"))
            self.wfile.flush()

            last_sent_id = since_id
            while True:
                with state_cond:
                    if runtime_events:
                        latest_id = int(runtime_events[-1].get("id", 0))
                    else:
                        latest_id = 0

                    if latest_id <= last_sent_id:
                        state_cond.wait(timeout=15.0)
                        # heartbeat
                        heartbeat = {"type": "ping", "time": now_iso()}
                        self.wfile.write(f"event: ping\ndata: {json.dumps(heartbeat, ensure_ascii=False)}\n\n".encode("utf-8"))
                        self.wfile.flush()
                        continue

                    new_events = [item for item in runtime_events if int(item.get("id", 0)) > last_sent_id]

                for event in new_events:
                    self.wfile.write(f"id: {event.get('id')}\n".encode("utf-8"))
                    self.wfile.write(f"event: runtime\ndata: {json.dumps(event, ensure_ascii=False)}\n\n".encode("utf-8"))
                    self.wfile.flush()
                    last_sent_id = int(event.get("id", last_sent_id))
        except (BrokenPipeError, ConnectionResetError):
            return
        except Exception:
            traceback.print_exc()
            return

    def _handle_agents_stream(self, parsed: Any) -> None:
        query = parse_qs(parsed.query or "")
        since_id = max(0, safe_int(query.get("since_id", ["0"])[0], 0))
        if since_id <= 0:
            since_id = max(0, safe_int(self.headers.get("Last-Event-ID", "0"), 0))

        self.send_response(HTTPStatus.OK)
        self._set_common_headers()
        self.send_header("Content-Type", "text/event-stream; charset=utf-8")
        self.send_header("Connection", "keep-alive")
        self.end_headers()

        try:
            init_payload = {"ok": True, "type": "hello", "stream": "agents", "time": now_iso()}
            self.wfile.write(f"event: hello\ndata: {json.dumps(init_payload, ensure_ascii=False)}\n\n".encode("utf-8"))
            self.wfile.flush()
            last_sent_id = since_id
            while True:
                with state_cond:
                    if agent_events:
                        latest_id = int(agent_events[-1].get("id", 0))
                    else:
                        latest_id = 0
                    if latest_id <= last_sent_id:
                        state_cond.wait(timeout=15.0)
                        heartbeat = {"type": "ping", "stream": "agents", "time": now_iso()}
                        self.wfile.write(f"event: ping\ndata: {json.dumps(heartbeat, ensure_ascii=False)}\n\n".encode("utf-8"))
                        self.wfile.flush()
                        continue
                    new_events = [item for item in agent_events if int(item.get("id", 0)) > last_sent_id]

                for event in new_events:
                    self.wfile.write(f"id: {event.get('id')}\n".encode("utf-8"))
                    self.wfile.write(f"event: agent\ndata: {json.dumps(event, ensure_ascii=False)}\n\n".encode("utf-8"))
                    self.wfile.flush()
                    last_sent_id = int(event.get("id", last_sent_id))
        except (BrokenPipeError, ConnectionResetError):
            return
        except Exception:
            traceback.print_exc()
            return


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Lobster Projection API V2")
    parser.add_argument("--host", default=os.getenv("PROJECTION_API_HOST", "127.0.0.1"))
    parser.add_argument("--port", type=int, default=int(os.getenv("PROJECTION_API_PORT", "19100")))
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    load_data()
    server = ThreadingHTTPServer((args.host, args.port), ProjectionHandler)
    print(f"[projection-api] listening on http://{args.host}:{args.port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
