#!/usr/bin/env python3
"""Star Office UI - Backend State Service"""

from flask import Flask, jsonify, send_from_directory, make_response, request, session
from datetime import datetime, timedelta
import json
import os
import random
import math
import re
import shutil
import subprocess
import tempfile
import threading
import time
from pathlib import Path
from urllib import request as urllib_request, error as urllib_error
from security_utils import is_production_mode, is_strong_secret, is_strong_drawer_pass
from memo_utils import get_yesterday_date_str, sanitize_content, extract_memo_from_file
from store_utils import (
    load_agents_state as _store_load_agents_state,
    save_agents_state as _store_save_agents_state,
    load_asset_positions as _store_load_asset_positions,
    save_asset_positions as _store_save_asset_positions,
    load_asset_defaults as _store_load_asset_defaults,
    save_asset_defaults as _store_save_asset_defaults,
    load_runtime_config as _store_load_runtime_config,
    save_runtime_config as _store_save_runtime_config,
    load_join_keys as _store_load_join_keys,
    save_join_keys as _store_save_join_keys,
)

try:
    from PIL import Image
except Exception:
    Image = None

# Paths (project-relative, no hardcoded absolute paths)
ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MEMORY_DIR = os.path.join(os.path.dirname(ROOT_DIR), "memory")
FRONTEND_DIR = os.path.join(ROOT_DIR, "frontend")
FRONTEND_INDEX_FILE = os.path.join(FRONTEND_DIR, "index.html")
FRONTEND_ELECTRON_STANDALONE_FILE = os.path.join(FRONTEND_DIR, "electron-standalone.html")
WORKBENCH_DIR = os.path.join(Path(ROOT_DIR).parent.parent, "web")
STATE_FILE = os.path.join(ROOT_DIR, "state.json")
AGENTS_STATE_FILE = os.path.join(ROOT_DIR, "agents-state.json")
JOIN_KEYS_FILE = os.path.join(ROOT_DIR, "join-keys.json")
FRONTEND_PATH = Path(FRONTEND_DIR)
ASSET_ALLOWED_EXTS = {".png", ".webp", ".jpg", ".jpeg", ".gif", ".svg", ".avif"}
ASSET_TEMPLATE_ZIP = os.path.join(ROOT_DIR, "assets-replace-template.zip")
WORKSPACE_DIR = os.path.dirname(ROOT_DIR)
OPENCLAW_WORKSPACE = os.environ.get("OPENCLAW_WORKSPACE") or os.path.join(os.path.expanduser("~"), ".openclaw", "workspace")
IDENTITY_FILE = os.path.join(OPENCLAW_WORKSPACE, "IDENTITY.md")
GEMINI_SCRIPT = os.path.join(WORKSPACE_DIR, "skills", "gemini-image-generate", "scripts", "gemini_image_generate.py")
GEMINI_PYTHON = os.path.join(WORKSPACE_DIR, "skills", "gemini-image-generate", ".venv", "bin", "python")
ROOM_REFERENCE_IMAGE = (
    os.path.join(ROOT_DIR, "assets", "room-reference.webp")
    if os.path.exists(os.path.join(ROOT_DIR, "assets", "room-reference.webp"))
    else os.path.join(ROOT_DIR, "assets", "room-reference.png")
)
BG_HISTORY_DIR = os.path.join(ROOT_DIR, "assets", "bg-history")
HOME_FAVORITES_DIR = os.path.join(ROOT_DIR, "assets", "home-favorites")
HOME_FAVORITES_INDEX_FILE = os.path.join(HOME_FAVORITES_DIR, "index.json")
HOME_FAVORITES_MAX = 30
ASSET_POSITIONS_FILE = os.path.join(ROOT_DIR, "asset-positions.json")

# 性能保护：默认关闭“每次打开页面随机换背景”，避免首页首屏被磁盘复制拖慢
AUTO_ROTATE_HOME_ON_PAGE_OPEN = (os.getenv("AUTO_ROTATE_HOME_ON_PAGE_OPEN", "0").strip().lower() in {"1", "true", "yes", "on"})
AUTO_ROTATE_MIN_INTERVAL_SECONDS = int(os.getenv("AUTO_ROTATE_MIN_INTERVAL_SECONDS", "60"))
_last_home_rotate_at = 0
ASSET_DEFAULTS_FILE = os.path.join(ROOT_DIR, "asset-defaults.json")
RUNTIME_CONFIG_FILE = os.path.join(ROOT_DIR, "runtime-config.json")
OPENCLAW_HOME = os.environ.get("OPENCLAW_HOME") or os.path.join(os.path.expanduser("~"), ".openclaw")
OPENCLAW_ENV_FILE = os.path.join(OPENCLAW_HOME, "env")
OPENCLAW_JSON_FILE = os.path.join(OPENCLAW_HOME, "openclaw.json")
OPENCLAW_PROFILE_DIR = os.path.join(OPENCLAW_HOME, "profile")
OPENCLAW_WEB_PROFILE_JSON = os.path.join(OPENCLAW_PROFILE_DIR, "web-config-profile.json")
OPENCLAW_WEB_LOADOUT_JSON = os.path.join(OPENCLAW_PROFILE_DIR, "web-config-loadout.json")
OPENCLAW_WEB_MANAGED_SKILLS_JSON = os.path.join(OPENCLAW_PROFILE_DIR, "web-config-managed-skills.json")
OPENCLAW_GAME_PROGRESS_JSON = os.path.join(OPENCLAW_PROFILE_DIR, "game-progress.json")
OPENCLAW_TASK_QUEUE_JSON = os.path.join(OPENCLAW_PROFILE_DIR, "web-task-queue.json")
OPENCLAW_MEDIA_QUOTA_STATE_FILE = os.environ.get("OPENCLAW_MEDIA_QUOTA_STATE_FILE") or os.path.join(OPENCLAW_HOME, "quota", "media-state.json")
OPENCLAW_MEDIA_QUOTA_SCRIPT = os.environ.get("OPENCLAW_MEDIA_QUOTA_SCRIPT") or ""
OPENCLAW_SKILLS_DIR = os.path.join(OPENCLAW_HOME, "skills")
OPENCLAW_SESSIONS_DIR = os.path.join(OPENCLAW_HOME, "agents", "main", "sessions")
OPENCLAW_LOGS_DIR = os.path.join(OPENCLAW_HOME, "logs")
PROJECTION_API_INGEST_URL = os.environ.get("PROJECTION_API_INGEST_URL", "http://127.0.0.1:19100/runtime/ingest")
RUNTIME_SUMMARY_TTL_SECONDS = int(os.getenv("OPENCLAW_RUNTIME_SUMMARY_TTL_SECONDS", "45"))
RUNTIME_SCAN_MAX_FILES = int(os.getenv("OPENCLAW_RUNTIME_SCAN_MAX_FILES", "90"))
RUNTIME_SCAN_MAX_BYTES = int(os.getenv("OPENCLAW_RUNTIME_SCAN_MAX_BYTES", "180000"))
_runtime_summary_cache = {"ts": 0.0, "data": None}

# Canonical agent states: single source of truth for validation and mapping
VALID_AGENT_STATES = frozenset({"idle", "writing", "researching", "executing", "syncing", "error"})
WORKING_STATES = frozenset({"writing", "researching", "executing"})  # subset used for auto-idle TTL
STATE_TO_AREA_MAP = {
    "idle": "breakroom",
    "writing": "writing",
    "researching": "writing",
    "executing": "writing",
    "syncing": "writing",
    "error": "error",
}


app = Flask(__name__, static_folder=FRONTEND_DIR, static_url_path="/static")
app.secret_key = os.getenv("FLASK_SECRET_KEY") or os.getenv("STAR_OFFICE_SECRET") or "star-office-dev-secret-change-me"

# Session hardening
app.config.update(
    SESSION_COOKIE_HTTPONLY=True,
    SESSION_COOKIE_SAMESITE="Lax",
    SESSION_COOKIE_SECURE=is_production_mode(),
    PERMANENT_SESSION_LIFETIME=timedelta(hours=12),
)

# Guard join-agent critical section to enforce per-key concurrency under parallel requests
join_lock = threading.Lock()

# Async background task registry for long-running operations (e.g. image generation)
# Avoids Cloudflare 524 timeout (100s limit) by letting frontend poll for completion.
_bg_tasks = {}  # task_id -> {"status": "pending"|"done"|"error", "result": ..., "error": ..., "created_at": ...}
_bg_tasks_lock = threading.Lock()

# Generate a version timestamp once at server startup for cache busting
VERSION_TIMESTAMP = datetime.now().strftime("%Y%m%d_%H%M%S")
ASSET_DRAWER_PASS_DEFAULT = os.getenv("ASSET_DRAWER_PASS", "1234")

if is_production_mode():
    hardening_errors = []
    if not is_strong_secret(str(app.secret_key)):
        hardening_errors.append("FLASK_SECRET_KEY / STAR_OFFICE_SECRET is weak (need >=24 chars, non-default)")
    if not is_strong_drawer_pass(ASSET_DRAWER_PASS_DEFAULT):
        hardening_errors.append("ASSET_DRAWER_PASS is weak (do not use default 1234; recommend >=8 chars)")
    if hardening_errors:
        raise RuntimeError("Security hardening check failed in production mode: " + "; ".join(hardening_errors))


def _is_asset_editor_authed() -> bool:
    return bool(session.get("asset_editor_authed"))


def _require_asset_editor_auth():
    if _is_asset_editor_authed():
        return None
    return jsonify({"ok": False, "code": "UNAUTHORIZED", "msg": "Asset editor auth required"}), 401


@app.after_request
def add_no_cache_headers(response):
    """Apply cache policy by path:
    - HTML/API/state: no-cache (always fresh)
    - /static assets (2xx only): long cache (filenames are versioned with ?v=VERSION_TIMESTAMP)
    - /static assets (non-2xx, e.g. 404): no-cache to prevent CDN from caching errors
    """
    path = (request.path or "")
    if path.startswith('/static/') and 200 <= response.status_code < 300:
        response.headers["Cache-Control"] = "public, max-age=31536000, immutable"
        response.headers.pop("Pragma", None)
        response.headers.pop("Expires", None)
    else:
        response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate, max-age=0"
        response.headers["Pragma"] = "no-cache"
        response.headers["Expires"] = "0"
    return response

# Default state
DEFAULT_STATE = {
    "state": "idle",
    "detail": "等待任务中...",
    "progress": 0,
    "updated_at": datetime.now().isoformat()
}


def load_state():
    """Load state from file.

    Includes a simple auto-idle mechanism:
    - If the last update is older than ttl_seconds (default 25s)
      and the state is a "working" state, we fall back to idle.

    This avoids the UI getting stuck at the desk when no new updates arrive.
    """
    state = None
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, "r", encoding="utf-8") as f:
                state = json.load(f)
        except Exception:
            state = None

    if not isinstance(state, dict):
        state = dict(DEFAULT_STATE)

    # Auto-idle
    try:
        ttl = int(state.get("ttl_seconds", 300))
        updated_at = state.get("updated_at")
        s = state.get("state", "idle")
        if updated_at and s in WORKING_STATES:
            # tolerate both with/without timezone
            dt = datetime.fromisoformat(updated_at.replace("Z", "+00:00"))
            # Use UTC for aware datetimes; local time for naive.
            if dt.tzinfo:
                from datetime import timezone
                age = (datetime.now(timezone.utc) - dt.astimezone(timezone.utc)).total_seconds()
            else:
                age = (datetime.now() - dt).total_seconds()
            if age > ttl:
                state["state"] = "idle"
                state["detail"] = "待命中（自动回到休息区）"
                state["progress"] = 0
                state["updated_at"] = datetime.now().isoformat()
                # persist the auto-idle so every client sees it consistently
                try:
                    save_state(state)
                except Exception:
                    pass
    except Exception:
        pass

    return state


def get_office_name_from_identity():
    """Read office display name from OpenClaw workspace IDENTITY.md (Name field) -> 'XXX的办公室'."""
    if not os.path.isfile(IDENTITY_FILE):
        return None
    try:
        with open(IDENTITY_FILE, "r", encoding="utf-8") as f:
            content = f.read()
        m = re.search(r"-\s*\*\*Name:\*\*\s*(.+)", content)
        if m:
            name = m.group(1).strip().replace("\r", "").split("\n")[0].strip()
            if not name:
                return None
            low = name.lower()
            suspicious = [
                "pick something you like",
                "office name",
                "placeholder",
                "default",
            ]
            if any(flag in low for flag in suspicious) or len(name) > 40:
                return None
            return f"{name}的办公室"
    except Exception:
        pass
    return None


def save_state(state: dict):
    """Save state to file"""
    with open(STATE_FILE, "w", encoding="utf-8") as f:
        json.dump(state, f, ensure_ascii=False, indent=2)


def ensure_electron_standalone_snapshot():
    """Create Electron standalone frontend snapshot once if missing.

    The snapshot is intentionally decoupled from the browser page:
    - browser uses frontend/index.html
    - Electron uses frontend/electron-standalone.html
    """
    if os.path.exists(FRONTEND_ELECTRON_STANDALONE_FILE):
        return
    try:
        shutil.copy2(FRONTEND_INDEX_FILE, FRONTEND_ELECTRON_STANDALONE_FILE)
        print(f"[standalone] created: {FRONTEND_ELECTRON_STANDALONE_FILE}")
    except Exception as e:
        print(f"[standalone] create failed: {e}")


# Initialize state
if not os.path.exists(STATE_FILE):
    save_state(DEFAULT_STATE)
ensure_electron_standalone_snapshot()


_INDEX_HTML_CACHE = None


@app.route("/", methods=["GET"])
def index():
    """Serve the pixel office UI with built-in version cache busting"""
    # 默认禁用页面打开即换背景，避免首屏慢
    # 如需启用，可配置 AUTO_ROTATE_HOME_ON_PAGE_OPEN=1
    _maybe_apply_random_home_favorite()

    global _INDEX_HTML_CACHE
    if _INDEX_HTML_CACHE is None:
        with open(FRONTEND_INDEX_FILE, "r", encoding="utf-8") as f:
            raw_html = f.read()
        _INDEX_HTML_CACHE = raw_html.replace("{{VERSION_TIMESTAMP}}", VERSION_TIMESTAMP)

    resp = make_response(_INDEX_HTML_CACHE)
    resp.headers["Content-Type"] = "text/html; charset=utf-8"
    return resp


@app.route("/electron-standalone", methods=["GET"])
def electron_standalone_page():
    """Serve Electron-only standalone frontend page."""
    ensure_electron_standalone_snapshot()
    target = FRONTEND_ELECTRON_STANDALONE_FILE
    if not os.path.exists(target):
        target = FRONTEND_INDEX_FILE
    with open(target, "r", encoding="utf-8") as f:
        html = f.read()
    html = html.replace("{{VERSION_TIMESTAMP}}", VERSION_TIMESTAMP)
    resp = make_response(html)
    resp.headers["Content-Type"] = "text/html; charset=utf-8"
    return resp

    resp.headers["Content-Type"] = "text/html; charset=utf-8"
    return resp


@app.route("/join", methods=["GET"])
def join_page():
    """Serve the agent join page"""
    with open(os.path.join(FRONTEND_DIR, "join.html"), "r", encoding="utf-8") as f:
        html = f.read()
    resp = make_response(html)
    resp.headers["Content-Type"] = "text/html; charset=utf-8"
    return resp


@app.route("/invite", methods=["GET"])
def invite_page():
    """Serve human-facing invite instruction page"""
    with open(os.path.join(FRONTEND_DIR, "invite.html"), "r", encoding="utf-8") as f:
        html = f.read()
    resp = make_response(html)
    resp.headers["Content-Type"] = "text/html; charset=utf-8"
    return resp


@app.route("/workbench", methods=["GET"])
@app.route("/workbench/", methods=["GET"])
@app.route("/workbench/<path:filename>", methods=["GET"])
def workbench_page(filename: str = "index.html"):
    """Serve Lobster workbench pages from the room backend under the same origin."""
    target = (filename or "index.html").strip("/")
    if not target:
        target = "index.html"
    return send_from_directory(WORKBENCH_DIR, target)


DEFAULT_AGENTS = [
    {
        "agentId": "star",
        "name": "Star",
        "isMain": True,
        "state": "idle",
        "detail": "待命中，随时准备为你服务",
        "updated_at": datetime.now().isoformat(),
        "area": "breakroom",
        "source": "local",
        "joinKey": None,
        "authStatus": "approved",
        "authExpiresAt": None,
        "lastPushAt": None
    }
]


def load_agents_state():
    return _store_load_agents_state(AGENTS_STATE_FILE, DEFAULT_AGENTS)


def save_agents_state(agents):
    _store_save_agents_state(AGENTS_STATE_FILE, agents)


def load_asset_positions():
    return _store_load_asset_positions(ASSET_POSITIONS_FILE)


def save_asset_positions(data):
    _store_save_asset_positions(ASSET_POSITIONS_FILE, data)


def load_asset_defaults():
    return _store_load_asset_defaults(ASSET_DEFAULTS_FILE)


def save_asset_defaults(data):
    _store_save_asset_defaults(ASSET_DEFAULTS_FILE, data)


def load_runtime_config():
    return _store_load_runtime_config(RUNTIME_CONFIG_FILE)


def save_runtime_config(data):
    _store_save_runtime_config(RUNTIME_CONFIG_FILE, data)


def _ensure_home_favorites_index():
    os.makedirs(HOME_FAVORITES_DIR, exist_ok=True)
    if not os.path.exists(HOME_FAVORITES_INDEX_FILE):
        with open(HOME_FAVORITES_INDEX_FILE, "w", encoding="utf-8") as f:
            json.dump({"items": []}, f, ensure_ascii=False, indent=2)


def _load_home_favorites_index():
    _ensure_home_favorites_index()
    try:
        with open(HOME_FAVORITES_INDEX_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
            if isinstance(data, dict) and isinstance(data.get("items"), list):
                return data
    except Exception:
        pass
    return {"items": []}


def _save_home_favorites_index(data):
    _ensure_home_favorites_index()
    with open(HOME_FAVORITES_INDEX_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


def _maybe_apply_random_home_favorite():
    """On page open, randomly apply one saved home favorite if available."""
    global _last_home_rotate_at

    if not AUTO_ROTATE_HOME_ON_PAGE_OPEN:
        return False, "disabled"

    try:
        now_ts = datetime.now().timestamp()
        if _last_home_rotate_at and (now_ts - _last_home_rotate_at) < AUTO_ROTATE_MIN_INTERVAL_SECONDS:
            return False, "throttled"

        idx = _load_home_favorites_index()
        items = idx.get("items") or []
        candidates = []
        for it in items:
            rel = (it.get("path") or "").strip()
            if not rel:
                continue
            abs_path = os.path.join(ROOT_DIR, rel)
            if os.path.exists(abs_path):
                candidates.append((rel, abs_path))

        if not candidates:
            return False, "no-favorites"

        rel, src = random.choice(candidates)
        target = FRONTEND_PATH / "office_bg_small.webp"
        if not target.exists():
            return False, "missing-office-bg"

        shutil.copy2(src, str(target))
        _last_home_rotate_at = now_ts
        return True, rel
    except Exception as e:
        return False, str(e)


def load_join_keys():
    return _store_load_join_keys(JOIN_KEYS_FILE)


def save_join_keys(data):
    _store_save_join_keys(JOIN_KEYS_FILE, data)


def _ensure_magick_or_ffmpeg_available():
    if shutil.which("magick"):
        return "magick"
    if shutil.which("ffmpeg"):
        return "ffmpeg"
    return None


def _probe_animated_frame_size(upload_path: str):
    """Return (w,h) from first frame if possible."""
    if Image is not None:
        try:
            with Image.open(upload_path) as im:
                w, h = im.size
                return int(w), int(h)
        except Exception:
            pass
    # ffprobe fallback
    if shutil.which("ffprobe"):
        try:
            cmd = [
                "ffprobe", "-v", "error",
                "-select_streams", "v:0",
                "-show_entries", "stream=width,height",
                "-of", "csv=p=0:s=x",
                upload_path,
            ]
            out = subprocess.check_output(cmd, stderr=subprocess.STDOUT, timeout=5).decode().strip()
            if "x" in out:
                w, h = out.split("x", 1)
                return int(w), int(h)
        except Exception:
            pass
    return None, None


def _animated_to_spritesheet(
    upload_path: str,
    frame_w: int,
    frame_h: int,
    out_ext: str = ".webp",
    preserve_original: bool = True,
    pixel_art: bool = True,
    cols: int | None = None,
    rows: int | None = None,
):
    """Convert animated GIF/WEBP to spritesheet, return (out_path, columns, rows, frames, out_frame_w, out_frame_h)."""
    backend = _ensure_magick_or_ffmpeg_available()
    if not backend:
        raise RuntimeError("未检测到 ImageMagick/ffmpeg，无法自动转换动图")

    ext = (out_ext or ".webp").lower()
    if ext not in {".webp", ".png"}:
        ext = ".webp"

    out_fd, out_path = tempfile.mkstemp(suffix=ext)
    os.close(out_fd)

    with tempfile.TemporaryDirectory() as td:
        frames = 0
        out_fw, out_fh = int(frame_w), int(frame_h)
        if Image is not None:
            try:
                with Image.open(upload_path) as im:
                    n = getattr(im, "n_frames", 1)
                    # 默认保留用户原始帧尺寸（避免先压缩再放大导致像素糊）
                    if preserve_original:
                        out_fw, out_fh = im.size
                    for i in range(n):
                        im.seek(i)
                        fr = im.convert("RGBA")
                        if not preserve_original and (fr.size != (out_fw, out_fh)):
                            resample = Image.Resampling.NEAREST if pixel_art else Image.Resampling.LANCZOS
                            fr = fr.resize((out_fw, out_fh), resample)
                        fr.save(os.path.join(td, f"f_{i:04d}.png"), "PNG")
                    frames = n
            except Exception:
                frames = 0

        if frames <= 0:
            cmd1 = f"ffmpeg -y -i '{upload_path}' '{td}/f_%04d.png' >/dev/null 2>&1"
            if os.system(cmd1) != 0:
                raise RuntimeError("动图抽帧失败（Pillow/ffmpeg 都失败）")
            files = sorted([x for x in os.listdir(td) if x.startswith("f_") and x.endswith(".png")])
            frames = len(files)
            if frames <= 0:
                raise RuntimeError("动图无有效帧")

        if backend == "magick":
            # 像素风动图转精灵表默认无损，避免颜色/边缘被压缩糊掉
            quality_flag = "-define webp:lossless=true -define webp:method=6 -quality 100" if ext == ".webp" else ""
            # 允许按 cols/rows 排布；默认单行
            if cols is None or cols <= 0:
                cols_eff = frames
            else:
                cols_eff = max(1, int(cols))
            rows_eff = max(1, int(rows)) if (rows is not None and rows > 0) else max(1, math.ceil(frames / cols_eff))

            # 先规范单帧尺寸
            prep = ""
            if not preserve_original:
                magick_filter = "-filter point" if pixel_art else ""
                prep = f" {magick_filter} -resize {out_fw}x{out_fh}^ -gravity center -background none -extent {out_fw}x{out_fh}"

            cmd = (
                f"magick '{td}/f_*.png'{prep} "
                f"-tile {cols_eff}x{rows_eff} -background none -geometry +0+0 {quality_flag} '{out_path}'"
            )
            rc = os.system(cmd)
            if rc != 0:
                raise RuntimeError("ImageMagick 拼图失败")
            return out_path, cols_eff, rows_eff, frames, out_fw, out_fh

        ffmpeg_quality = "-lossless 1 -compression_level 6 -q:v 100" if ext == ".webp" else ""
        cols_eff = max(1, int(cols)) if (cols is not None and cols > 0) else frames
        rows_eff = max(1, int(rows)) if (rows is not None and rows > 0) else max(1, math.ceil(frames / cols_eff))
        if preserve_original:
            vf = f"tile={cols_eff}x{rows_eff}"
        else:
            scale_algo = "neighbor" if pixel_art else "lanczos"
            vf = (
                f"scale={out_fw}:{out_fh}:force_original_aspect_ratio=decrease:flags={scale_algo},"
                f"pad={out_fw}:{out_fh}:(ow-iw)/2:(oh-ih)/2:color=0x00000000,"
                f"tile={cols_eff}x{rows_eff}"
            )
        cmd2 = (
            f"ffmpeg -y -pattern_type glob -i '{td}/f_*.png' "
            f"-vf '{vf}' "
            f"{ffmpeg_quality} '{out_path}' >/dev/null 2>&1"
        )
        if os.system(cmd2) != 0:
            raise RuntimeError("ffmpeg 拼图失败")
        return out_path, frames, 1, frames, out_fw, out_fh


def normalize_agent_state(s):
    """Normalize agent state for compatibility.
    Maps synonyms (e.g. working/busy -> writing, run/running -> executing) into VALID_AGENT_STATES.
    Returns 'idle' for unknown values.
    """
    if not s:
        return 'idle'
    s_lower = s.lower().strip()
    if s_lower in {'working', 'busy', 'write'}:
        return 'writing'
    if s_lower in {'run', 'running', 'execute', 'exec'}:
        return 'executing'
    if s_lower in {'sync'}:
        return 'syncing'
    if s_lower in {'research', 'search'}:
        return 'researching'
    if s_lower in VALID_AGENT_STATES:
        return s_lower
    return 'idle'


# User-facing model aliases -> provider model ids
USER_MODEL_TO_PROVIDER_MODELS = {
    # 严格按用户要求：仅两种官方模型映射
    "nanobanana-pro": [
        "nano-banana-pro-preview",
    ],
    "nanobanana-2": [
        "gemini-2.5-flash-image",
    ],
}

PROVIDER_MODEL_TO_USER_MODEL = {
    provider: user
    for user, providers in USER_MODEL_TO_PROVIDER_MODELS.items()
    for provider in providers
}

ROLE_ALIASES = {
    "druid": "druid",
    "generalist": "druid",
    "wanjinyou": "druid",
    "assassin": "assassin",
    "analyst": "assassin",
    "fenxiyuan": "assassin",
    "mage": "mage",
    "researcher": "mage",
    "yanjiuzhe": "mage",
    "summoner": "summoner",
    "manager": "summoner",
    "guanlizhe": "summoner",
    "warrior": "warrior",
    "technician": "warrior",
    "jishuyuan": "warrior",
    "paladin": "paladin",
    "marketer": "paladin",
    "yingxiaozhe": "paladin",
    "designer": "designer",
    "archer": "designer",
    "yunyingzhe": "designer",
}

ROLE_SKILL_MAP = {
    "druid": [
        "proactive-agent", "openclaw-cron-setup", "reflection", "find-skills", "shell",
        "web-search", "summarize", "docx", "xlsx", "agentmail", "task", "todo",
        "ai-meeting-notes", "weather",
    ],
    "assassin": [
        "akshare-stock", "stock-monitor-skill", "multi-search-engine", "web-search",
        "tavily-search", "news-radar", "summarize", "url-to-markdown", "xlsx",
        "finance-data", "data-analyst", "google-trends",
    ],
    "mage": [
        "brainstorming", "summarize", "web-search", "tavily-search", "url-to-markdown",
        "docx", "pdf", "nano-pdf", "pptx", "xlsx", "notebooklm-skill",
        "paperless-docs", "paperless-ngx-tools",
    ],
    "summoner": [
        "proactive-agent", "openclaw-cron-setup", "docx", "xlsx", "pptx", "agentmail",
        "github", "reflection", "task", "todo", "ai-meeting-notes", "lark-calendar",
    ],
    "warrior": [
        "shell", "github", "mcp-builder", "chrome-devtools-mcp", "agent-browser",
        "model-usage", "web-search", "minimax-image-understanding", "reflection",
        "test-driven-development", "subagent-driven-development",
        "skill-security-auditor", "database", "preflight-checks",
    ],
    "paladin": [
        "web-search", "tavily-search", "news-radar", "summarize", "url-to-markdown",
        "docx", "xlsx", "agentmail", "frontend-design", "web-design",
        "content-strategy", "social-content", "google-trends",
        "baoyu-post-to-wechat", "baoyu-post-to-x",
    ],
    "designer": [
        "frontend-design", "web-design", "gemini-image-service", "grok-imagine-1.0-video",
        "pptx", "docx", "summarize", "ai-image-generation", "logo-creator",
        "baoyu-article-illustrator", "baoyu-cover-image", "baoyu-infographic",
        "baoyu-slide-deck", "video-frames",
    ],
}

TOOL_TO_SKILL_BINDINGS = {
    "chrome-devtools": ["chrome-devtools-mcp"],
    "agent-browser-rig": ["agent-browser"],
    "github-mcp": ["github"],
    "image-studio": ["ai-image-generation"],
    "gemini-vision": ["gemini-image-service"],
    "nano-banana": ["ai-image-generation"],
    "market-radar": ["news-radar"],
    "sheet-engine": ["xlsx"],
    "search-array": ["web-search"],
    "tavily-core": ["tavily-search"],
    "cron-orb": ["openclaw-cron-setup"],
}

TOOL_TO_ENV_BINDINGS = {
    "chrome-devtools": {"OPENCLAW_TOOL_CHROME_DEVTOOLS": "1"},
    "agent-browser-rig": {"OPENCLAW_TOOL_AGENT_BROWSER": "1"},
    "github-mcp": {"OPENCLAW_TOOL_GITHUB": "1"},
    "image-studio": {"OPENCLAW_TOOL_IMAGE_STUDIO": "1"},
    "gemini-vision": {"OPENCLAW_TOOL_GEMINI_VISION": "1"},
    "nano-banana": {"OPENCLAW_TOOL_NANO_BANANA": "1"},
    "search-array": {"OPENCLAW_TOOL_SEARCH_ARRAY": "1"},
    "tavily-core": {"OPENCLAW_TOOL_TAVILY": "1"},
    "market-radar": {"OPENCLAW_TOOL_MARKET_RADAR": "1"},
    "sheet-engine": {"OPENCLAW_TOOL_SHEET_ENGINE": "1"},
    "cron-orb": {"OPENCLAW_TOOL_CRON_ORB": "1"},
}

ROLE_META = {
    "druid": {"title": "万金油 · 德鲁伊", "className": "通用总管"},
    "assassin": {"title": "分析员 · 刺客", "className": "投资分析"},
    "mage": {"title": "研究者 · 大法师", "className": "研究学习"},
    "summoner": {"title": "管理者 · 召唤师", "className": "组织管理"},
    "warrior": {"title": "技术员 · 战士", "className": "工程开发"},
    "paladin": {"title": "营销者 · 圣骑士", "className": "增长运营"},
    "designer": {"title": "设计师", "className": "设计创意"},
}


def _normalize_user_model(model_name: str) -> str:
    m = (model_name or "").strip()
    if not m:
        return "nanobanana-pro"
    low = m.lower()
    if low in USER_MODEL_TO_PROVIDER_MODELS:
        return low
    if low in PROVIDER_MODEL_TO_USER_MODEL:
        return PROVIDER_MODEL_TO_USER_MODEL[low]
    return "nanobanana-pro"


def _normalize_persona_role(role_name: str) -> str:
    role = (role_name or "").strip().lower().replace("_", "-")
    return ROLE_ALIASES.get(role, "druid")


def _repo_root_path() -> str:
    root = Path(ROOT_DIR).resolve()
    for candidate in [root, *root.parents]:
        if (candidate / "skills" / "default").is_dir():
            return str(candidate)
    return str(root)


def _resolve_default_skills_bundle_dir() -> str | None:
    repo_root = _repo_root_path()
    candidates = [
        os.path.join(repo_root, "skills", "default"),
        os.path.join(OPENCLAW_HOME, ".cache", "auto-install-openclaw-repo", "skills", "default"),
        os.path.join(OPENCLAW_HOME, "workspace", "auto-install-openclaw", "skills", "default"),
        os.path.join(OPENCLAW_HOME, "workspace", "auto-install-Openclaw", "skills", "default"),
    ]
    for path in candidates:
        if os.path.isdir(path):
            return path
    return None


def _strip_wrapped_quotes(value: str) -> str:
    text = str(value or "").strip()
    if len(text) >= 2 and ((text[0] == text[-1] == "'") or (text[0] == text[-1] == '"')):
        return text[1:-1]
    return text


def _read_env_exports() -> dict[str, str]:
    data: dict[str, str] = {}
    if not os.path.exists(OPENCLAW_ENV_FILE):
        return data
    try:
        with open(OPENCLAW_ENV_FILE, "r", encoding="utf-8") as f:
            for raw in f:
                line = raw.strip()
                if not line or line.startswith("#") or not line.startswith("export "):
                    continue
                body = line[len("export ") :]
                if "=" not in body:
                    continue
                key, value = body.split("=", 1)
                key = key.strip()
                if not key:
                    continue
                data[key] = _strip_wrapped_quotes(value)
    except Exception:
        return data
    return data


def _friendly_name_from_id(name: str) -> str:
    text = str(name or "").strip().replace("_", " ").replace("-", " ")
    text = re.sub(r"\s+", " ", text).strip()
    return text.title() if text else "Unknown"


def _guess_skill_branch(skill_id: str) -> str:
    sid = str(skill_id or "").lower()
    if any(k in sid for k in ["search", "news", "radar", "crawler", "trend"]):
        return "情报网络"
    if any(k in sid for k in ["doc", "pdf", "ppt", "xlsx", "notebook", "summary", "markdown"]):
        return "知识文档"
    if any(k in sid for k in ["stock", "finance", "akshare", "quant", "fund"]):
        return "金融引擎"
    if any(k in sid for k in ["design", "image", "video", "logo", "poster", "infographic", "animation"]):
        return "创意工坊"
    if any(k in sid for k in ["content", "social", "marketing", "wechat", "xhs", "weibo"]):
        return "增长工坊"
    if any(k in sid for k in ["browser", "shell", "devtools", "github", "mcp", "code", "test", "build"]):
        return "执行系统"
    return "控制中枢"


def _guess_tool_slot(name: str, item_type: str, idx: int = 0) -> str:
    text = f"{name or ''} {item_type or ''}".lower()
    if "model" in text or "模型" in text:
        return "head"
    if any(k in text for k in ["api", "key", "token", "search", "radar"]):
        return "ring" if idx % 2 == 0 else "core"
    if "mcp" in text or "browser" in text or "devtools" in text:
        return "mainhand" if idx % 2 == 0 else "offhand"
    if any(k in text for k in ["mail", "calendar", "wechat", "app"]):
        return "shoulders"
    if any(k in text for k in ["image", "video", "design"]):
        return "offhand" if idx % 2 == 0 else "legs"
    if "shell" in text or "tool" in text:
        return "belt"
    return "boots"


def _list_skill_dirs(base_dir: str) -> list[str]:
    if not base_dir or not os.path.isdir(base_dir):
        return []
    names = []
    try:
        for name in os.listdir(base_dir):
            full = os.path.join(base_dir, name)
            if os.path.isdir(full) and re.fullmatch(r"[a-zA-Z0-9._-]+", name):
                names.append(name)
    except Exception:
        return []
    return sorted(set(names))


def _role_ids_for_ui() -> list[str]:
    return ["druid", "assassin", "mage", "summoner", "warrior", "paladin", "designer"]


def _frontmatter_description(text: str) -> str:
    if not text:
        return ""
    match = re.search(r'^\s*description:\s*"?(.*?)"?\s*$', text, re.M)
    return match.group(1).strip() if match else ""


def _first_nonempty_content_line(text: str) -> str:
    for raw in (text or "").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or line.startswith("---"):
            continue
        return line
    return ""


def _read_skill_description(skill_id: str) -> str:
    bundle_dir = _resolve_default_skills_bundle_dir()
    candidates = [
        os.path.join(OPENCLAW_SKILLS_DIR, skill_id),
        os.path.join(bundle_dir, skill_id) if bundle_dir else "",
    ]
    checked = set()
    for skill_dir in candidates:
        if not skill_dir or skill_dir in checked or not os.path.isdir(skill_dir):
            continue
        checked.add(skill_dir)
        for filename in ("SKILL.md", "GUIDE.md"):
            file_path = os.path.join(skill_dir, filename)
            if not os.path.isfile(file_path):
                continue
            try:
                with open(file_path, "r", encoding="utf-8") as f:
                    content = f.read()
            except Exception:
                continue
            desc = _frontmatter_description(content) or _first_nonempty_content_line(content)
            if desc:
                return desc
    return f"{_guess_skill_branch(skill_id)}能力，可按需加入当前构筑。"


def _collect_skill_catalog() -> dict:
    installed = _list_skill_dirs(OPENCLAW_SKILLS_DIR)
    bundle_dir = _resolve_default_skills_bundle_dir()
    bundle = _list_skill_dirs(bundle_dir) if bundle_dir else []
    all_ids = sorted(set(installed) | set(bundle))

    return {
        "installed": installed,
        "bundle": bundle,
        "all": all_ids,
        "counts": {
            "installed": len(installed),
            "bundle": len(bundle),
            "all": len(all_ids),
        },
    }


def _extract_json_payload(text: str):
    raw = (text or "").strip()
    if not raw:
        return None
    decoder = json.JSONDecoder()
    for idx, ch in enumerate(raw):
        if ch not in "{[":
            continue
        try:
            obj, _ = decoder.raw_decode(raw[idx:])
            return obj
        except Exception:
            continue
    return None


def _collect_skill_ids_from_obj(value) -> list[str]:
    rows: list[str] = []

    def _walk(node):
        if isinstance(node, str):
            text = node.strip()
            if re.fullmatch(r"[a-zA-Z0-9._-]+", text):
                rows.append(text)
            return
        if isinstance(node, list):
            for item in node:
                _walk(item)
            return
        if isinstance(node, dict):
            for key in ("id", "name", "skill", "skillId", "slug"):
                v = node.get(key)
                if isinstance(v, str):
                    text = v.strip()
                    if re.fullmatch(r"[a-zA-Z0-9._-]+", text):
                        rows.append(text)
            for v in node.values():
                _walk(v)

    _walk(value)
    return _safe_skill_id_list(rows)


def _collect_skill_catalog_with_fallback() -> dict:
    base = _collect_skill_catalog()
    installed = list(base.get("installed", []))
    bundle = list(base.get("bundle", []))
    local_all = list(base.get("all", []))

    diagnostic = {
        "status": "local-only",
        "message": "仅使用本地技能目录扫描结果",
        "cliAvailable": bool(shutil.which("openclaw")),
        "source": "local-scan",
    }

    if not shutil.which("openclaw"):
        return {
            "installed": installed,
            "bundle": bundle,
            "all": local_all,
            "counts": {"installed": len(installed), "bundle": len(bundle), "all": len(local_all)},
            "diagnostic": diagnostic,
        }

    try:
        proc = subprocess.run(
            ["openclaw", "skills", "list", "--json"],
            check=False,
            capture_output=True,
            text=True,
            timeout=15,
        )
        parsed = _extract_json_payload(proc.stdout or "")
        if parsed is None:
            diagnostic = {
                "status": "parse-failed",
                "message": "OpenClaw CLI 返回结果无法解析为 JSON，已回退本地扫描",
                "cliAvailable": True,
                "source": "local-scan",
                "exitCode": int(proc.returncode),
                "stderr": (proc.stderr or "").strip()[:240],
            }
            return {
                "installed": installed,
                "bundle": bundle,
                "all": local_all,
                "counts": {"installed": len(installed), "bundle": len(bundle), "all": len(local_all)},
                "diagnostic": diagnostic,
            }

        cli_ids = _collect_skill_ids_from_obj(parsed)
        # installed 仍以本地已安装目录为准，避免 CLI 语义差异导致误判
        merged_all = sorted(set(local_all) | set(cli_ids))
        diagnostic = {
            "status": "ok",
            "message": "已使用 OpenClaw CLI + 本地目录合并结果",
            "cliAvailable": True,
            "source": "cli-merged",
            "exitCode": int(proc.returncode),
        }
        return {
            "installed": installed,
            "bundle": bundle,
            "all": merged_all,
            "counts": {"installed": len(installed), "bundle": len(bundle), "all": len(merged_all)},
            "diagnostic": diagnostic,
        }
    except subprocess.TimeoutExpired:
        diagnostic = {
            "status": "timeout",
            "message": "OpenClaw CLI 调用超时，已回退本地扫描",
            "cliAvailable": True,
            "source": "local-scan",
            "timeoutSeconds": 15,
        }
    except Exception as e:
        diagnostic = {
            "status": "exec-failed",
            "message": f"OpenClaw CLI 调用失败，已回退本地扫描: {e}",
            "cliAvailable": True,
            "source": "local-scan",
        }

    return {
        "installed": installed,
        "bundle": bundle,
        "all": local_all,
        "counts": {"installed": len(installed), "bundle": len(bundle), "all": len(local_all)},
        "diagnostic": diagnostic,
    }


def _tail_text(path: str, max_bytes: int = RUNTIME_SCAN_MAX_BYTES) -> str:
    try:
        size = os.path.getsize(path)
        with open(path, "rb") as f:
            if size > max_bytes:
                f.seek(max(0, size - max_bytes))
            data = f.read(max_bytes)
        return data.decode("utf-8", errors="ignore")
    except Exception:
        return ""


def _collect_runtime_signal_snapshot() -> dict:
    file_meta: list[tuple[float, str]] = []
    for root in [OPENCLAW_SESSIONS_DIR, OPENCLAW_LOGS_DIR]:
        if not os.path.isdir(root):
            continue
        for dir_path, _, files in os.walk(root):
            for name in files:
                full = os.path.join(dir_path, name)
                try:
                    mt = os.path.getmtime(full)
                    file_meta.append((float(mt), full))
                except Exception:
                    continue

    if not file_meta:
        return {
            "hoursPlayed": 0.0,
            "tokensUsed": 0,
            "tasksCompleted": 0,
            "tasksSuccess": 0,
            "successRate": 0.0,
            "tokensPerSuccess": 0.0,
            "skillUsageRate": 0.0,
            "installedSkillsCount": len(_list_skill_dirs(OPENCLAW_SKILLS_DIR)),
            "usedSkillsCount": 0,
            "userDissatisfaction": 0.0,
            "signalsSource": "runtime-empty",
        }

    file_meta.sort(key=lambda x: x[0], reverse=True)
    latest = file_meta[0][0]
    earliest = file_meta[-1][0]
    recent_files = [path for _, path in file_meta[: max(10, RUNTIME_SCAN_MAX_FILES)]]

    token_re = re.compile(r'"(?:totalTokens|total_tokens|tokensUsed|tokens_used)"\s*:\s*(\d+)', re.I)
    completed_re = re.compile(r'"status"\s*:\s*"(?:completed|done|success)"', re.I)
    success_re = re.compile(r'"success"\s*:\s*true|"status"\s*:\s*"success"', re.I)
    failed_re = re.compile(r'"success"\s*:\s*false|"status"\s*:\s*"(?:failed|error|timeout|cancelled)"', re.I)
    user_re = re.compile(r'"role"\s*:\s*"user"', re.I)

    def _scan_runtime_files(paths: list[str]) -> dict:
        tokens_used_local = 0
        tasks_completed_local = 0
        tasks_success_local = 0
        tasks_failed_local = 0
        user_messages_local = 0
        blob_chunks_local: list[str] = []

        for path in paths:
            text = _tail_text(path)
            if not text:
                continue
            low = text.lower()
            if len(blob_chunks_local) < 24:
                blob_chunks_local.append(low[:18000])
            try:
                tokens_used_local += sum(int(x) for x in token_re.findall(text))
            except Exception:
                pass
            tasks_completed_local += len(completed_re.findall(text))
            tasks_success_local += len(success_re.findall(text))
            tasks_failed_local += len(failed_re.findall(text))
            user_messages_local += len(user_re.findall(text))

        return {
            "tokensUsed": tokens_used_local,
            "tasksCompleted": tasks_completed_local,
            "tasksSuccess": tasks_success_local,
            "tasksFailed": tasks_failed_local,
            "userMessages": user_messages_local,
            "blobChunks": blob_chunks_local,
        }

    primary_scan = _scan_runtime_files(recent_files)
    tokens_used = int(primary_scan["tokensUsed"])
    tasks_completed = int(primary_scan["tasksCompleted"])
    tasks_success = int(primary_scan["tasksSuccess"])
    tasks_failed = int(primary_scan["tasksFailed"])
    user_messages = int(primary_scan["userMessages"])
    blob_chunks = list(primary_scan["blobChunks"])

    # Fallback: when recent tail files have no signal (common on reset/rollover),
    # expand the scan window once to include a wider historical slice.
    if tokens_used <= 0 and tasks_completed <= 0 and user_messages <= 0 and len(file_meta) > len(recent_files):
        extended_limit = max(240, RUNTIME_SCAN_MAX_FILES * 4)
        extended_paths = [path for _, path in file_meta[: min(len(file_meta), extended_limit)]]
        secondary_scan = _scan_runtime_files(extended_paths)
        tokens_used = max(tokens_used, int(secondary_scan["tokensUsed"]))
        tasks_completed = max(tasks_completed, int(secondary_scan["tasksCompleted"]))
        tasks_success = max(tasks_success, int(secondary_scan["tasksSuccess"]))
        tasks_failed = max(tasks_failed, int(secondary_scan["tasksFailed"]))
        user_messages = max(user_messages, int(secondary_scan["userMessages"]))
        if not blob_chunks:
            blob_chunks = list(secondary_scan["blobChunks"])

    if tasks_completed <= 0 and user_messages > 0:
        tasks_completed = max(1, int(user_messages * 0.35))
    if tasks_success <= 0 and tasks_completed > 0:
        fail_hint = tasks_failed if tasks_failed > 0 else max(1, int(tasks_completed * 0.18))
        tasks_success = max(1, tasks_completed - min(tasks_completed, fail_hint))
    if tasks_success > tasks_completed:
        tasks_success = tasks_completed

    success_rate = round((tasks_success / tasks_completed), 4) if tasks_completed > 0 else 0.0
    installed_skills = _list_skill_dirs(OPENCLAW_SKILLS_DIR)
    installed_skills_count = len(installed_skills)
    used_skills_count = 0
    if blob_chunks and installed_skills_count > 0:
        blob = "\n".join(blob_chunks)
        for skill in installed_skills:
            key = skill.lower()
            variants = [key, key.replace("-", "_"), key.replace("_", "-")]
            if any(v and v in blob for v in variants):
                used_skills_count += 1
    skill_usage_rate = round((used_skills_count / installed_skills_count) * 100, 2) if installed_skills_count > 0 else 0.0
    if skill_usage_rate <= 0 and installed_skills_count > 0 and tasks_completed > 0:
        skill_usage_rate = round(min(100.0, (tasks_completed / installed_skills_count) * 100.0), 2)

    tokens_per_success = round(tokens_used / max(1, tasks_success), 2) if tasks_success > 0 else float(tokens_used)
    if tasks_completed <= 0:
        dissatisfaction = 35.0 if tokens_used > 0 else 0.0
    else:
        failure_ratio = 1.0 - success_rate
        token_pressure = min(1.0, (tokens_per_success / 200000.0) if tasks_success > 0 else 1.0)
        skill_idle = max(0.0, 1.0 - (skill_usage_rate / 100.0))
        dissatisfaction = round(min(100.0, (failure_ratio * 0.55 + token_pressure * 0.25 + skill_idle * 0.20) * 100), 1)

    hours_played = round(max(0.0, time.time() - earliest) / 3600.0, 2)
    return {
        "hoursPlayed": float(hours_played),
        "tokensUsed": int(max(0, tokens_used)),
        "tasksCompleted": int(max(0, tasks_completed)),
        "tasksSuccess": int(max(0, tasks_success)),
        "successRate": float(success_rate),
        "tokensPerSuccess": float(max(0.0, tokens_per_success)),
        "skillUsageRate": float(max(0.0, skill_usage_rate)),
        "installedSkillsCount": int(installed_skills_count),
        "usedSkillsCount": int(used_skills_count),
        "userDissatisfaction": float(max(0.0, dissatisfaction)),
        "signalsSource": "sessions+logs",
        "firstSeenEpoch": int(earliest),
        "lastSeenEpoch": int(latest),
    }


def _collect_runtime_signals_cached() -> dict:
    now = time.time()
    cache = _runtime_summary_cache.get("data")
    ts = float(_runtime_summary_cache.get("ts") or 0.0)
    if cache and (now - ts) < max(5, RUNTIME_SUMMARY_TTL_SECONDS):
        return cache
    data = _collect_runtime_signal_snapshot()
    _runtime_summary_cache["ts"] = now
    _runtime_summary_cache["data"] = data
    return data


def _default_quota_limits(profile: str) -> tuple[int, int, int]:
    normalized = str(profile or "medium").strip().lower()
    if normalized == "low":
        return (0, 0, 100)
    if normalized == "high":
        return (50, 2, 0)
    if normalized == "none":
        return (0, 0, 0)
    return (20, 1, 300)


def _resolve_media_quota_script() -> str:
    candidates = []
    if OPENCLAW_MEDIA_QUOTA_SCRIPT:
        candidates.append(OPENCLAW_MEDIA_QUOTA_SCRIPT)
    try:
        app_file = Path(__file__).resolve()
        for parent in app_file.parents:
            candidates.append(str(parent / "scripts" / "media_quota.py"))
    except Exception:
        pass
    candidates.append(os.path.join(OPENCLAW_HOME, ".cache", "auto-install-openclaw-repo", "scripts", "media_quota.py"))
    candidates.append(os.path.join(OPENCLAW_WORKSPACE, "auto-install-openclaw", "scripts", "media_quota.py"))
    for raw in candidates:
        path = str(raw or "").strip()
        if not path:
            continue
        expanded = os.path.expanduser(path)
        if os.path.isfile(expanded):
            return expanded
    return ""


def _run_media_quota_command(args: list[str]) -> tuple[bool, dict]:
    script_path = _resolve_media_quota_script()
    if not script_path:
        return False, {"ok": False, "reason": "quota_script_missing", "message": "quota script not found"}
    try:
        proc = subprocess.run(
            ["python3", script_path, *args],
            capture_output=True,
            text=True,
            timeout=8,
        )
        raw = (proc.stdout or "").strip() or (proc.stderr or "").strip()
        payload = {}
        if raw:
            try:
                payload = json.loads(raw)
            except Exception:
                payload = {"ok": False, "reason": "quota_parse_error", "message": raw}
        if proc.returncode == 0:
            return True, payload if isinstance(payload, dict) else {}
        if isinstance(payload, dict) and payload:
            return False, payload
        return False, {"ok": False, "reason": "quota_command_failed", "message": raw or f"exit={proc.returncode}"}
    except Exception as exc:
        return False, {"ok": False, "reason": "quota_command_exception", "message": str(exc)}


def _reserve_quota(category: str, units: int, tool_name: str) -> tuple[str | None, dict]:
    ok, payload = _run_media_quota_command(
        ["reserve", "--category", str(category), "--units", str(max(1, int(units))), "--tool", str(tool_name or "unknown")]
    )
    if not ok:
        return None, payload if isinstance(payload, dict) else {}
    reservation = payload.get("reservation") if isinstance(payload, dict) else {}
    reservation_id = str((reservation or {}).get("id") or "").strip()
    if not reservation_id:
        return None, {"ok": False, "reason": "reservation_missing", "message": "reservation id missing", "raw": payload}
    return reservation_id, payload


def _commit_quota(reservation_id: str | None) -> None:
    rid = str(reservation_id or "").strip()
    if not rid:
        return
    _run_media_quota_command(["commit", "--id", rid])


def _release_quota(reservation_id: str | None) -> None:
    rid = str(reservation_id or "").strip()
    if not rid:
        return
    _run_media_quota_command(["release", "--id", rid])


def _collect_media_quota_state(env_data: dict[str, str]) -> dict[str, dict]:
    def _safe_int(value, default=0) -> int:
        try:
            return int(float(value))
        except Exception:
            return int(default)

    rule_profile = str(env_data.get("OPENCLAW_RULE_PROFILE") or "medium").strip().lower()
    default_image_quota, default_video_quota, default_text_quota = _default_quota_limits(rule_profile)
    window_hours = max(1, int(_safe_int(env_data.get("OPENCLAW_RULE_WINDOW_HOURS"), 5)))
    reservation_ttl = max(60, int(_safe_int(env_data.get("OPENCLAW_MEDIA_QUOTA_RESERVATION_TTL_SECONDS"), 1800)))
    state_file = str(env_data.get("OPENCLAW_MEDIA_QUOTA_STATE_FILE") or OPENCLAW_MEDIA_QUOTA_STATE_FILE)
    now_epoch = int(time.time())
    cutoff = now_epoch - window_hours * 3600
    raw_state = _json_read(state_file, {"entries": []})
    entries = raw_state.get("entries") if isinstance(raw_state, dict) else []
    if not isinstance(entries, list):
        entries = []

    def _summarize(category: str, limit_default: int) -> dict:
        env_key = {
            "image": "OPENCLAW_RULE_MAX_IMAGE_REQUESTS",
            "video": "OPENCLAW_RULE_MAX_VIDEO_REQUESTS",
            "text": "OPENCLAW_RULE_MAX_REQUESTS",
        }.get(category, "")
        limit = max(0, int(_safe_int(env_data.get(env_key), limit_default)))
        valid_committed = []
        valid_reserved = []
        for entry in entries:
            if not isinstance(entry, dict):
                continue
            if str(entry.get("category") or "").strip().lower() != category:
                continue
            status = str(entry.get("status") or "").strip().lower()
            reserved_at = int(_safe_int(entry.get("reserved_at"), 0))
            committed_at = int(_safe_int(entry.get("committed_at"), 0))
            expires_at = int(_safe_int(entry.get("expires_at"), 0))
            if status == "committed":
                ts = committed_at or reserved_at
                if ts > 0 and ts >= cutoff:
                    valid_committed.append(entry)
            elif status == "reserved":
                expiry = expires_at or (reserved_at + reservation_ttl)
                if reserved_at > 0 and expiry >= now_epoch:
                    valid_reserved.append(entry)

        used = sum(max(0, int(_safe_int(item.get("units"), 0))) for item in valid_committed)
        pending = sum(max(0, int(_safe_int(item.get("units"), 0))) for item in valid_reserved)
        unlimited = bool(category == "text" and limit <= 0)
        remaining = -1 if unlimited else (0 if limit <= 0 else max(0, limit - used - pending))
        reset_candidates = []
        for item in valid_committed:
            ts = int(_safe_int(item.get("committed_at"), 0) or _safe_int(item.get("reserved_at"), 0))
            if ts > 0:
                reset_candidates.append(ts + window_hours * 3600)
        reset_at = min(reset_candidates) if reset_candidates else now_epoch
        return {
            "limit": int(limit),
            "used": int(used),
            "pending": int(pending),
            "remaining": int(remaining),
            "windowHours": int(window_hours),
            "resetAt": int(reset_at),
            "enabled": True if unlimited else bool(limit > 0),
            "unlimited": unlimited,
        }

    return {
        "image": _summarize("image", default_image_quota),
        "video": _summarize("video", default_video_quota),
        "text": _summarize("text", default_text_quota),
    }


def _collect_dynamic_loadout_items(env_data: dict[str, str], installed_skills: list[str]) -> list[dict]:
    role_all = _role_ids_for_ui()
    items = []
    seen = set()

    def add_item(item_id: str, name: str, item_type: str, desc: str, slot: str | None = None, rarity: str = "magic"):
        iid = str(item_id or "").strip()
        if not iid or iid in seen:
            return
        seen.add(iid)
        items.append({
            "id": iid,
            "name": name,
            "type": item_type,
            "rarity": rarity,
            "slot": slot or _guess_tool_slot(name, item_type, len(items)),
            "desc": desc,
            "roles": role_all,
            "dynamic": True,
        })

    model_candidates = [
        ("model-main", env_data.get("OPENCLAW_UNOFFICIAL_ADVANCED_MODEL") or env_data.get("OPENAI_MODEL")),
        ("model-fallback", env_data.get("OPENCLAW_UNOFFICIAL_OPENAI_MODEL") or env_data.get("SILICONFLOW_FALLBACK_MODEL")),
        ("model-image", env_data.get("OPENAI_IMAGE_MODEL") or env_data.get("QIHANG_IMAGE_MODEL") or env_data.get("MOLIFANG_IMAGE_MODEL")),
        ("model-gemini", env_data.get("OPENCLAW_GEMINI_IMAGE_MODEL") or env_data.get("GEMINI_IMAGE_MODEL")),
    ]
    for item_id, model in model_candidates:
        if model:
            add_item(item_id, str(model), "模型", "来自当前环境配置的模型", "head", rarity="mythic")

    api_keys = sorted(
        [k for k, v in env_data.items() if k.endswith("_API_KEY") and str(v).strip()],
        key=lambda x: x.lower(),
    )
    for idx, key in enumerate(api_keys[:24]):
        label = key.replace("_API_KEY", "").replace("_", " ").strip() + " API"
        add_item(f"api-{key.lower().replace('_', '-')}", label, "API", "已配置 API Key，可用于联网或外部能力调用", _guess_tool_slot(label, "API", idx), rarity="rare")

    tool_flags = sorted([k for k, v in env_data.items() if k.startswith("OPENCLAW_TOOL_") and str(v).strip() in {"1", "true", "True"}])
    for idx, key in enumerate(tool_flags):
        name = key.replace("OPENCLAW_TOOL_", "").replace("_", " ").strip()
        add_item(f"tool-{name.lower().replace(' ', '-')}", _friendly_name_from_id(name), "Tool", "来自已启用工具开关", _guess_tool_slot(name, "Tool", idx))

    for idx, skill in enumerate(installed_skills[:120]):
        sid = skill.lower()
        if "mcp" in sid:
            add_item(f"mcp-{skill}", _friendly_name_from_id(skill), "MCP", "从已安装 Skill 识别的 MCP 能力", _guess_tool_slot(skill, "MCP", idx))
        elif any(k in sid for k in ["browser", "devtools", "shell", "github"]):
            add_item(f"tool-{skill}", _friendly_name_from_id(skill), "Tool", "从已安装 Skill 识别的执行能力", _guess_tool_slot(skill, "Tool", idx))
        elif any(k in sid for k in ["image", "video", "design", "logo"]):
            add_item(f"tool-{skill}", _friendly_name_from_id(skill), "Tool", "从已安装 Skill 识别的创意能力", _guess_tool_slot(skill, "Tool", idx))
        elif any(k in sid for k in ["mail", "calendar", "wechat"]):
            add_item(f"app-{skill}", _friendly_name_from_id(skill), "App", "从已安装 Skill 识别的应用能力", _guess_tool_slot(skill, "App", idx))

    return items


def _json_read(path: str, fallback):
    if not os.path.exists(path):
        return fallback
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return fallback


def _json_write(path: str, payload):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)
        f.write("\n")


def _append_task_queue(item: dict):
    payload = _json_read(OPENCLAW_TASK_QUEUE_JSON, {"tasks": []})
    tasks = payload.get("tasks") if isinstance(payload, dict) else []
    if not isinstance(tasks, list):
        tasks = []
    tasks = [item, *tasks][:60]
    _json_write(OPENCLAW_TASK_QUEUE_JSON, {"updatedAt": datetime.now().isoformat(), "tasks": tasks})


def _push_projection_runtime(state: str, detail: str, progress: int, source: str = "lobster-world"):
    try:
        payload = json.dumps(
            {
                "state": state,
                "detail": detail,
                "progress": max(0, min(100, int(progress))),
                "source": source,
                "updated_at": datetime.now().isoformat(),
            },
            ensure_ascii=False,
        ).encode("utf-8")
        req = urllib_request.Request(
            PROJECTION_API_INGEST_URL,
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib_request.urlopen(req, timeout=2):
            return True
    except (urllib_error.URLError, TimeoutError, ValueError):
        return False
    except Exception:
        return False


def _upsert_env_export(key: str, value: str):
    os.makedirs(os.path.dirname(OPENCLAW_ENV_FILE), exist_ok=True)
    if not os.path.exists(OPENCLAW_ENV_FILE):
        with open(OPENCLAW_ENV_FILE, "w", encoding="utf-8") as f:
            f.write("")
    lines = []
    found = False
    target_prefix = f"export {key}="
    with open(OPENCLAW_ENV_FILE, "r", encoding="utf-8") as f:
        for raw in f.readlines():
            if raw.startswith(target_prefix):
                lines.append(f'export {key}={value}\n')
                found = True
            else:
                lines.append(raw)
    if not found:
        lines.append(f'export {key}={value}\n')
    with open(OPENCLAW_ENV_FILE, "w", encoding="utf-8") as f:
        f.writelines(lines)


def _remove_env_export(key: str):
    if not os.path.exists(OPENCLAW_ENV_FILE):
        return
    target_prefix = f"export {key}="
    with open(OPENCLAW_ENV_FILE, "r", encoding="utf-8") as f:
        lines = [raw for raw in f.readlines() if not raw.startswith(target_prefix)]
    with open(OPENCLAW_ENV_FILE, "w", encoding="utf-8") as f:
        f.writelines(lines)


def _env_export_value(value) -> str:
    if isinstance(value, (dict, list)):
        return "'" + json.dumps(value, ensure_ascii=False) + "'"
    return json.dumps("" if value is None else str(value), ensure_ascii=False)


MINIMAX_MULTIMODAL_DEFAULTS = {
    "output_path": "~/.openclaw/workspace/minimax-output",
    "resource_mode": "local",
    "image_model": "image-01",
    "image_endpoint": "/v1/image_generation",
    "tts_model": "speech-2.8-hd",
    "tts_endpoint": "/v1/t2a_v2",
    "video_model": "MiniMax-Hailuo-2.3",
    "video_endpoint": "/v1/video_generation",
    "video_query_endpoint": "/v1/query/video_generation",
    "video_retrieve_endpoint": "/v1/files/retrieve",
    "music_model": "music-2.6",
    "music_endpoint": "/v1/music_generation",
}


def _minimax_api_host_from_base_url(base_url: str | None, env_data: dict | None = None) -> str:
    env_data = env_data or {}
    raw = str(base_url or "").strip()
    if raw:
        return re.sub(r"/anthropic/?$", "", raw)
    saved = str(env_data.get("MINIMAX_API_HOST") or "").strip()
    if saved:
        return saved
    provider_base = str(env_data.get("OPENCLAW_MINIMAX_PROVIDER_URL") or "").strip()
    if provider_base:
        return re.sub(r"/anthropic/?$", "", provider_base)
    return "https://api.minimaxi.com"


def _minimax_bundle_config(env_data: dict | None = None, base_url: str | None = None) -> dict:
    env_data = env_data or {}
    api_host = _minimax_api_host_from_base_url(base_url, env_data)
    output_path = str(env_data.get("MINIMAX_MULTIMODAL_OUTPUT_PATH") or MINIMAX_MULTIMODAL_DEFAULTS["output_path"]).strip()
    return {
        "api_host": api_host,
        "provider_base_url": str(base_url or env_data.get("OPENCLAW_MINIMAX_PROVIDER_URL") or "").strip(),
        "output_path": output_path,
        "mcp_base_path": str(env_data.get("MINIMAX_MCP_BASE_PATH") or output_path).strip(),
        "resource_mode": str(env_data.get("MINIMAX_API_RESOURCE_MODE") or MINIMAX_MULTIMODAL_DEFAULTS["resource_mode"]).strip(),
        "image_model": str(env_data.get("MINIMAX_IMAGE_MODEL") or MINIMAX_MULTIMODAL_DEFAULTS["image_model"]).strip(),
        "image_endpoint": str(env_data.get("MINIMAX_IMAGE_ENDPOINT") or MINIMAX_MULTIMODAL_DEFAULTS["image_endpoint"]).strip(),
        "tts_model": str(env_data.get("MINIMAX_TTS_MODEL") or MINIMAX_MULTIMODAL_DEFAULTS["tts_model"]).strip(),
        "tts_endpoint": str(env_data.get("MINIMAX_TTS_ENDPOINT") or MINIMAX_MULTIMODAL_DEFAULTS["tts_endpoint"]).strip(),
        "video_model": str(env_data.get("MINIMAX_VIDEO_MODEL") or MINIMAX_MULTIMODAL_DEFAULTS["video_model"]).strip(),
        "video_endpoint": str(env_data.get("MINIMAX_VIDEO_ENDPOINT") or MINIMAX_MULTIMODAL_DEFAULTS["video_endpoint"]).strip(),
        "video_query_endpoint": str(env_data.get("MINIMAX_VIDEO_QUERY_ENDPOINT") or MINIMAX_MULTIMODAL_DEFAULTS["video_query_endpoint"]).strip(),
        "video_retrieve_endpoint": str(env_data.get("MINIMAX_FILES_RETRIEVE_ENDPOINT") or MINIMAX_MULTIMODAL_DEFAULTS["video_retrieve_endpoint"]).strip(),
        "music_model": str(env_data.get("MINIMAX_MUSIC_MODEL") or MINIMAX_MULTIMODAL_DEFAULTS["music_model"]).strip(),
        "music_endpoint": str(env_data.get("MINIMAX_MUSIC_ENDPOINT") or MINIMAX_MULTIMODAL_DEFAULTS["music_endpoint"]).strip(),
    }


def _should_autowire_minimax_image_provider(env_data: dict | None = None) -> bool:
    env_data = env_data or {}
    provider_id = str(env_data.get("OPENCLAW_IMAGE_PROVIDER_ID") or "").strip().lower()
    base_url = str(env_data.get("OPENCLAW_IMAGE_API_URL") or "").strip()
    if not provider_id and not base_url:
        return True
    if provider_id.startswith("minimax"):
        return True
    if provider_id in {"", "custom-image"} and base_url in {"", "https://api.viviai.cc/v1/chat/completions"}:
        return True
    return False


def _write_minimax_skill_config(api_key: str, bundle: dict, text_model: str = ""):
    if not api_key:
        return
    cfg_path = os.path.join(OPENCLAW_HOME, "config", "minimax.json")
    os.makedirs(os.path.dirname(cfg_path), exist_ok=True)
    payload = {
        "api_key": api_key,
        "api_host": bundle.get("api_host", ""),
        "provider_base_url": bundle.get("provider_base_url", ""),
        "text_model": text_model,
        "output_path": bundle.get("output_path", MINIMAX_MULTIMODAL_DEFAULTS["output_path"]),
        "mcp_base_path": bundle.get("mcp_base_path", bundle.get("output_path", MINIMAX_MULTIMODAL_DEFAULTS["output_path"])),
        "resource_mode": bundle.get("resource_mode", MINIMAX_MULTIMODAL_DEFAULTS["resource_mode"]),
        "image": {
            "model": bundle.get("image_model", MINIMAX_MULTIMODAL_DEFAULTS["image_model"]),
            "endpoint": bundle.get("image_endpoint", MINIMAX_MULTIMODAL_DEFAULTS["image_endpoint"]),
        },
        "tts": {
            "model": bundle.get("tts_model", MINIMAX_MULTIMODAL_DEFAULTS["tts_model"]),
            "endpoint": bundle.get("tts_endpoint", MINIMAX_MULTIMODAL_DEFAULTS["tts_endpoint"]),
        },
        "video": {
            "model": bundle.get("video_model", MINIMAX_MULTIMODAL_DEFAULTS["video_model"]),
            "endpoint": bundle.get("video_endpoint", MINIMAX_MULTIMODAL_DEFAULTS["video_endpoint"]),
            "query_endpoint": bundle.get("video_query_endpoint", MINIMAX_MULTIMODAL_DEFAULTS["video_query_endpoint"]),
            "retrieve_endpoint": bundle.get("video_retrieve_endpoint", MINIMAX_MULTIMODAL_DEFAULTS["video_retrieve_endpoint"]),
        },
        "music": {
            "model": bundle.get("music_model", MINIMAX_MULTIMODAL_DEFAULTS["music_model"]),
            "endpoint": bundle.get("music_endpoint", MINIMAX_MULTIMODAL_DEFAULTS["music_endpoint"]),
        },
        "mcp": {
            "tools": ["web_search", "understand_image"],
        },
    }
    _json_write(cfg_path, payload)
    try:
        os.chmod(cfg_path, 0o600)
    except OSError:
        pass


def _normalize_provider_config(data: dict | None, env_data: dict | None = None) -> dict:
    env_data = env_data or {}
    payload = data if isinstance(data, dict) else {}
    preset_labels = {
        "anthropic": "Anthropic",
        "openai": "OpenAI",
        "zai": "GLM",
        "minimax": "MiniMax",
        "minimax-cn": "MiniMax",
        "deepseek": "DeepSeek",
        "google": "Gemini",
        "openrouter": "OpenRouter",
        "custom": "自定义 Provider",
    }
    preset = str(payload.get("preset") or env_data.get("OPENCLAW_ACTIVE_PROVIDER_PRESET") or "").strip().lower()
    if not preset:
        if env_data.get("OPENCLAW_CUSTOM_PROVIDER_ID") or env_data.get("OPENCLAW_CUSTOM_PROVIDER_BASE_URL"):
            preset = "custom"
        elif env_data.get("OPENCLAW_MINIMAX_PROVIDER_URL") or env_data.get("MINIMAX_API_KEY"):
            preset = "minimax"
        elif env_data.get("ZAI_API_KEY"):
            preset = "zai"
        elif env_data.get("OPENAI_API_KEY"):
            preset = "openai"
        elif env_data.get("ANTHROPIC_API_KEY"):
            preset = "anthropic"
        elif env_data.get("GOOGLE_API_KEY"):
            preset = "google"
        elif env_data.get("DEEPSEEK_API_KEY"):
            preset = "deepseek"
        else:
            preset = "anthropic"
    provider_id = str(payload.get("providerId") or env_data.get("OPENCLAW_CUSTOM_PROVIDER_ID") or preset or "anthropic").strip()
    display_name = str(payload.get("displayName") or env_data.get("OPENCLAW_CUSTOM_PROVIDER_NAME") or preset_labels.get(preset) or provider_id).strip()
    base_url = str(payload.get("baseUrl") or "").strip()
    model = str(payload.get("model") or "").strip()
    api_type = str(payload.get("apiType") or env_data.get("OPENCLAW_ACTIVE_PROVIDER_API_TYPE") or "").strip()
    api_key = str(payload.get("apiKey") or "").strip()
    keep_existing_key = bool(payload.get("keepExistingKey", True))
    if not api_type:
        api_type = "anthropic-messages" if preset in {"anthropic", "minimax", "minimax-cn"} else "openai-responses"
    if not base_url:
        defaults = {
            "anthropic": str(env_data.get("ANTHROPIC_BASE_URL") or "https://api.anthropic.com"),
            "openai": str(env_data.get("OPENAI_BASE_URL") or "https://api.openai.com/v1"),
            "zai": str(env_data.get("ZAI_BASE_URL") or "https://open.bigmodel.cn/api/paas/v4"),
            "minimax": str(env_data.get("OPENCLAW_MINIMAX_PROVIDER_URL") or "https://api.minimax.io/anthropic"),
            "minimax-cn": str(env_data.get("OPENCLAW_MINIMAX_PROVIDER_URL") or "https://api.minimaxi.com/anthropic"),
            "deepseek": str(env_data.get("DEEPSEEK_BASE_URL") or "https://api.deepseek.com"),
            "openrouter": str(env_data.get("OPENROUTER_BASE_URL") or "https://openrouter.ai/api/v1"),
            "google": str(env_data.get("GOOGLE_BASE_URL") or ""),
        }
        base_url = defaults.get(preset, "")
    if not model:
        defaults = {
            "anthropic": "claude-sonnet-4-20250514",
            "openai": "gpt-5.1",
            "zai": "glm-5",
            "minimax": "MiniMax-M2.7-highspeed",
            "minimax-cn": "MiniMax-M2.7-highspeed",
            "deepseek": "deepseek-chat",
            "openrouter": "anthropic/claude-3.7-sonnet",
            "google": "gemini-2.5-pro",
            "custom": str(env_data.get("OPENCLAW_CUSTOM_PROVIDER_MODEL") or ""),
        }
        model = defaults.get(preset, "")
    if preset == "custom":
        provider_id = provider_id or "custom-provider"
        display_name = display_name or "自定义 Provider"
    else:
        provider_id = provider_id or preset
        display_name = display_name or preset_labels.get(preset) or preset
    return {
        "preset": preset,
        "providerId": provider_id,
        "displayName": display_name,
        "baseUrl": base_url,
        "model": model,
        "apiType": api_type,
        "apiKey": api_key,
        "keepExistingKey": keep_existing_key,
    }


def _normalize_image_provider_config(data: dict | None, env_data: dict | None = None) -> dict:
    env_data = env_data or {}
    payload = data if isinstance(data, dict) else {}
    provider_id = str(payload.get("providerId") or env_data.get("OPENCLAW_IMAGE_PROVIDER_ID") or "custom-image").strip()
    display_name = str(payload.get("displayName") or env_data.get("OPENCLAW_IMAGE_PROVIDER_NAME") or "生图 Provider").strip()
    base_url = str(payload.get("baseUrl") or env_data.get("OPENCLAW_IMAGE_API_URL") or "").strip()
    model = str(payload.get("model") or env_data.get("OPENCLAW_IMAGE_MODEL") or "").strip()
    if (not base_url or not model or provider_id in {"", "custom-image"}) and str(env_data.get("OPENCLAW_ACTIVE_PROVIDER_PRESET") or "").strip().lower() in {"minimax", "minimax-cn"}:
        bundle = _minimax_bundle_config(env_data, env_data.get("OPENCLAW_ACTIVE_PROVIDER_BASE_URL"))
        provider_id = provider_id or "minimax-image"
        display_name = display_name if display_name not in {"", "生图 Provider"} else "MiniMax 官方生图"
        base_url = base_url or f'{bundle["api_host"]}{bundle["image_endpoint"]}'
        model = model or bundle["image_model"]
    if not base_url:
        base_url = "https://api.viviai.cc/v1/chat/completions"
    if not model:
        model = "gemini-3.1-flash-image-preview"
    if not provider_id:
        provider_id = "custom-image"
    if not display_name:
        display_name = "生图 Provider"
    api_key = str(payload.get("apiKey") or "").strip()
    keep_existing_key = bool(payload.get("keepExistingKey", True))
    return {
        "providerId": provider_id,
        "displayName": display_name,
        "baseUrl": base_url,
        "model": model,
        "apiKey": api_key,
        "keepExistingKey": keep_existing_key,
    }


def _openclaw_model_ref_for_provider(provider_config: dict) -> str:
    preset = str(provider_config.get("preset") or "anthropic").strip().lower()
    model = str(provider_config.get("model") or "").strip()
    if not model:
        return ""
    if preset == "custom":
        provider_id = str(provider_config.get("providerId") or "custom-provider").strip()
        return f"{provider_id}-custom/{model}"
    custom_base = str(provider_config.get("baseUrl") or "").strip()
    if custom_base and preset in {"anthropic", "openai", "zai"}:
        return f"{preset}-custom/{model}"
    return f"{preset}/{model}"


def _set_openclaw_default_model(model_ref: str):
    if not model_ref:
        return
    if shutil.which("openclaw"):
        try:
            result = subprocess.run(
                ["openclaw", "models", "set", model_ref],
                check=False,
                capture_output=True,
                text=True,
                timeout=10,
            )
            if result.returncode == 0:
                return
        except Exception:
            pass
    _run_openclaw_config_set("agents.defaults.model.primary", model_ref)
    _run_openclaw_config_set("models.default", model_ref)


def _upsert_custom_provider_json(provider_id: str, base_url: str, api_key: str, model: str, api_type: str):
    provider_id = str(provider_id or "").strip()
    base_url = str(base_url or "").strip()
    api_key = str(api_key or "").strip()
    model = str(model or "").strip()
    api_type = str(api_type or "openai-responses").strip()
    if not provider_id or not base_url or not api_key or not model:
        return
    payload = _json_read(OPENCLAW_JSON_FILE, {})
    if not isinstance(payload, dict):
        payload = {}
    models_cfg = payload.setdefault("models", {})
    providers_cfg = models_cfg.setdefault("providers", {})
    for key in list(providers_cfg.keys()):
        if str(key).endswith("-custom"):
            providers_cfg.pop(key, None)
    custom_id = provider_id if provider_id.endswith("-custom") else f"{provider_id}-custom"
    providers_cfg[custom_id] = {
        "baseUrl": base_url,
        "apiKey": api_key,
        "models": [
            {
                "id": model,
                "name": model,
                "api": api_type,
                "input": ["text", "image"],
                "contextWindow": 200000,
                "maxTokens": 8192,
            }
        ],
    }
    _json_write(OPENCLAW_JSON_FILE, payload)


def _ensure_minimax_provider_json(provider: str, model: str, base_url: str):
    payload = _json_read(OPENCLAW_JSON_FILE, {})
    if not isinstance(payload, dict):
        payload = {}
    models_cfg = payload.setdefault("models", {})
    models_cfg.setdefault("mode", "merge")
    providers_cfg = models_cfg.setdefault("providers", {})
    other_provider = "minimax-cn" if provider == "minimax" else "minimax"
    providers_cfg.pop(other_provider, None)
    catalog = {
        "MiniMax-M2.7": "MiniMax M2.7",
        "MiniMax-M2.7-highspeed": "MiniMax M2.7 Highspeed",
        "MiniMax-M2.5": "MiniMax M2.5",
        "MiniMax-M2.5-highspeed": "MiniMax M2.5 Highspeed",
    }
    providers_cfg[provider] = {
        "baseUrl": base_url,
        "api": "anthropic-messages",
        "authHeader": True,
        "models": [
            {
                "id": model_id,
                "name": label,
                "reasoning": True,
                "input": ["text"],
                "cost": {"input": 0.3, "output": 1.2, "cacheRead": 0.03, "cacheWrite": 0.12},
                "contextWindow": 200000,
                "maxTokens": 8192,
            }
            for model_id, label in catalog.items()
        ],
    }
    defaults_models = payload.setdefault("agents", {}).setdefault("defaults", {}).setdefault("models", {})
    for key in list(defaults_models.keys()):
        if str(key).startswith("minimax/") or str(key).startswith("minimax-cn/"):
            defaults_models.pop(key, None)
    defaults_models[f"{provider}/{model}"] = {"alias": "Minimax"}
    _json_write(OPENCLAW_JSON_FILE, payload)


def _apply_provider_config(provider_config: dict, env_data: dict | None = None):
    env_data = env_data or _read_env_exports()
    cfg = _normalize_provider_config(provider_config, env_data)
    preset = cfg["preset"]
    base_url = cfg["baseUrl"]
    api_key = cfg["apiKey"] or ""
    if cfg.get("keepExistingKey") and not api_key:
        env_key_map = {
            "anthropic": "ANTHROPIC_API_KEY",
            "openai": "OPENAI_API_KEY",
            "zai": "ZAI_API_KEY",
            "minimax": "MINIMAX_API_KEY",
            "minimax-cn": "MINIMAX_API_KEY",
            "deepseek": "DEEPSEEK_API_KEY",
            "google": "GOOGLE_API_KEY",
            "openrouter": "OPENROUTER_API_KEY",
            "custom": "OPENCLAW_CUSTOM_PROVIDER_API_KEY",
        }
        api_key = str(env_data.get(env_key_map.get(preset, ""), "")).strip()

    _upsert_env_export("OPENCLAW_ACTIVE_PROVIDER_PRESET", _env_export_value(preset))
    _upsert_env_export("OPENCLAW_ACTIVE_PROVIDER_MODEL", _env_export_value(cfg["model"]))
    _upsert_env_export("OPENCLAW_ACTIVE_PROVIDER_API_TYPE", _env_export_value(cfg["apiType"]))
    if base_url:
        _upsert_env_export("OPENCLAW_ACTIVE_PROVIDER_BASE_URL", _env_export_value(base_url))
    else:
        _remove_env_export("OPENCLAW_ACTIVE_PROVIDER_BASE_URL")

    if preset == "anthropic":
        if api_key:
            _upsert_env_export("ANTHROPIC_API_KEY", _env_export_value(api_key))
        if base_url:
            _upsert_env_export("ANTHROPIC_BASE_URL", _env_export_value(base_url))
        else:
            _remove_env_export("ANTHROPIC_BASE_URL")
    elif preset == "openai":
        if api_key:
            _upsert_env_export("OPENAI_API_KEY", _env_export_value(api_key))
        if base_url:
            _upsert_env_export("OPENAI_BASE_URL", _env_export_value(base_url))
        else:
            _remove_env_export("OPENAI_BASE_URL")
    elif preset == "zai":
        if api_key:
            _upsert_env_export("ZAI_API_KEY", _env_export_value(api_key))
        if base_url:
            _upsert_env_export("ZAI_BASE_URL", _env_export_value(base_url))
        else:
            _remove_env_export("ZAI_BASE_URL")
    elif preset in {"minimax", "minimax-cn"}:
        bundle = _minimax_bundle_config(env_data, base_url)
        if api_key:
            _upsert_env_export("MINIMAX_API_KEY", _env_export_value(api_key))
        if base_url:
            _upsert_env_export("OPENCLAW_MINIMAX_PROVIDER_URL", _env_export_value(base_url))
        else:
            _remove_env_export("OPENCLAW_MINIMAX_PROVIDER_URL")
        _upsert_env_export("MINIMAX_API_HOST", _env_export_value(bundle["api_host"]))
        _upsert_env_export("MINIMAX_MULTIMODAL_OUTPUT_PATH", _env_export_value(bundle["output_path"]))
        _upsert_env_export("MINIMAX_MCP_BASE_PATH", _env_export_value(bundle["mcp_base_path"]))
        _upsert_env_export("MINIMAX_API_RESOURCE_MODE", _env_export_value(bundle["resource_mode"]))
        _upsert_env_export("MINIMAX_IMAGE_MODEL", _env_export_value(bundle["image_model"]))
        _upsert_env_export("MINIMAX_IMAGE_ENDPOINT", _env_export_value(bundle["image_endpoint"]))
        _upsert_env_export("MINIMAX_TTS_MODEL", _env_export_value(bundle["tts_model"]))
        _upsert_env_export("MINIMAX_TTS_ENDPOINT", _env_export_value(bundle["tts_endpoint"]))
        _upsert_env_export("MINIMAX_VIDEO_MODEL", _env_export_value(bundle["video_model"]))
        _upsert_env_export("MINIMAX_VIDEO_ENDPOINT", _env_export_value(bundle["video_endpoint"]))
        _upsert_env_export("MINIMAX_VIDEO_QUERY_ENDPOINT", _env_export_value(bundle["video_query_endpoint"]))
        _upsert_env_export("MINIMAX_FILES_RETRIEVE_ENDPOINT", _env_export_value(bundle["video_retrieve_endpoint"]))
        _upsert_env_export("MINIMAX_MUSIC_MODEL", _env_export_value(bundle["music_model"]))
        _upsert_env_export("MINIMAX_MUSIC_ENDPOINT", _env_export_value(bundle["music_endpoint"]))
        _write_minimax_skill_config(api_key, bundle, cfg["model"])
        if _should_autowire_minimax_image_provider(env_data):
            _upsert_env_export("OPENCLAW_IMAGE_PROVIDER_ID", _env_export_value("minimax-image"))
            _upsert_env_export("OPENCLAW_IMAGE_PROVIDER_NAME", _env_export_value("MiniMax 官方生图"))
            _upsert_env_export("OPENCLAW_IMAGE_API_URL", _env_export_value(f'{bundle["api_host"]}{bundle["image_endpoint"]}'))
            _upsert_env_export("OPENCLAW_IMAGE_MODEL", _env_export_value(bundle["image_model"]))
            if api_key:
                _upsert_env_export("OPENCLAW_IMAGE_API_KEY", _env_export_value(api_key))
        _run_openclaw_config_set("vendor.media.minimax.apiHost", bundle["api_host"])
        _run_openclaw_config_set("vendor.media.minimax.outputPath", bundle["output_path"])
        _run_openclaw_config_set("vendor.media.minimax.mcpBasePath", bundle["mcp_base_path"])
        _run_openclaw_config_set("vendor.media.minimax.resourceMode", bundle["resource_mode"])
        _run_openclaw_config_set("vendor.media.minimax.image.model", bundle["image_model"])
        _run_openclaw_config_set("vendor.media.minimax.image.endpoint", bundle["image_endpoint"])
        _run_openclaw_config_set("vendor.media.minimax.tts.model", bundle["tts_model"])
        _run_openclaw_config_set("vendor.media.minimax.tts.endpoint", bundle["tts_endpoint"])
        _run_openclaw_config_set("vendor.media.minimax.video.model", bundle["video_model"])
        _run_openclaw_config_set("vendor.media.minimax.video.endpoint", bundle["video_endpoint"])
        _run_openclaw_config_set("vendor.media.minimax.video.queryEndpoint", bundle["video_query_endpoint"])
        _run_openclaw_config_set("vendor.media.minimax.video.retrieveEndpoint", bundle["video_retrieve_endpoint"])
        _run_openclaw_config_set("vendor.media.minimax.music.model", bundle["music_model"])
        _run_openclaw_config_set("vendor.media.minimax.music.endpoint", bundle["music_endpoint"])
        _ensure_minimax_provider_json(preset, cfg["model"], base_url or f'{bundle["api_host"]}/anthropic')
    elif preset == "deepseek":
        if api_key:
            _upsert_env_export("DEEPSEEK_API_KEY", _env_export_value(api_key))
        _upsert_env_export("DEEPSEEK_BASE_URL", _env_export_value(base_url or "https://api.deepseek.com"))
    elif preset == "google":
        if api_key:
            _upsert_env_export("GOOGLE_API_KEY", _env_export_value(api_key))
        if base_url:
            _upsert_env_export("GOOGLE_BASE_URL", _env_export_value(base_url))
        else:
            _remove_env_export("GOOGLE_BASE_URL")
    elif preset == "openrouter":
        if api_key:
            _upsert_env_export("OPENROUTER_API_KEY", _env_export_value(api_key))
        _upsert_env_export("OPENROUTER_BASE_URL", _env_export_value(base_url or "https://openrouter.ai/api/v1"))

    if preset == "custom":
        _upsert_env_export("OPENCLAW_CUSTOM_PROVIDER_ID", _env_export_value(cfg["providerId"]))
        _upsert_env_export("OPENCLAW_CUSTOM_PROVIDER_NAME", _env_export_value(cfg["displayName"]))
        _upsert_env_export("OPENCLAW_CUSTOM_PROVIDER_BASE_URL", _env_export_value(base_url))
        _upsert_env_export("OPENCLAW_CUSTOM_PROVIDER_MODEL", _env_export_value(cfg["model"]))
        _upsert_env_export("OPENCLAW_CUSTOM_PROVIDER_API_TYPE", _env_export_value(cfg["apiType"]))
        if api_key:
            _upsert_env_export("OPENCLAW_CUSTOM_PROVIDER_API_KEY", _env_export_value(api_key))
        _upsert_custom_provider_json(cfg["providerId"], base_url, api_key, cfg["model"], cfg["apiType"])
    elif base_url and preset in {"anthropic", "openai", "zai"} and api_key:
        _upsert_custom_provider_json(preset, base_url, api_key, cfg["model"], cfg["apiType"])

    _set_openclaw_default_model(_openclaw_model_ref_for_provider(cfg))
    return {
        "preset": cfg["preset"],
        "providerId": cfg["providerId"],
        "displayName": cfg["displayName"],
        "baseUrl": cfg["baseUrl"],
        "model": cfg["model"],
        "apiType": cfg["apiType"],
        "hasApiKey": bool(api_key),
    }


def _apply_image_provider_config(image_provider_config: dict, env_data: dict | None = None):
    env_data = env_data or _read_env_exports()
    cfg = _normalize_image_provider_config(image_provider_config, env_data)
    api_key = cfg["apiKey"] or ""
    if cfg.get("keepExistingKey") and not api_key:
        api_key = str(env_data.get("OPENCLAW_IMAGE_API_KEY") or "").strip()
        if not api_key and str(cfg.get("providerId") or "").strip().lower().startswith("minimax"):
            api_key = str(env_data.get("MINIMAX_API_KEY") or "").strip()
    _upsert_env_export("OPENCLAW_IMAGE_PROVIDER_ID", _env_export_value(cfg["providerId"]))
    _upsert_env_export("OPENCLAW_IMAGE_PROVIDER_NAME", _env_export_value(cfg["displayName"]))
    _upsert_env_export("OPENCLAW_IMAGE_API_URL", _env_export_value(cfg["baseUrl"]))
    _upsert_env_export("OPENCLAW_IMAGE_MODEL", _env_export_value(cfg["model"]))
    if api_key:
        _upsert_env_export("OPENCLAW_IMAGE_API_KEY", _env_export_value(api_key))
    return {
        "providerId": cfg["providerId"],
        "displayName": cfg["displayName"],
        "baseUrl": cfg["baseUrl"],
        "model": cfg["model"],
        "hasApiKey": bool(api_key),
    }


def _provider_config_summary(env_data: dict, profile_payload: dict | None = None) -> dict:
    profile_payload = profile_payload if isinstance(profile_payload, dict) else {}
    data = profile_payload.get("providerConfig") if isinstance(profile_payload.get("providerConfig"), dict) else {}
    cfg = _normalize_provider_config(data, env_data)
    env_key_map = {
        "anthropic": "ANTHROPIC_API_KEY",
        "openai": "OPENAI_API_KEY",
        "zai": "ZAI_API_KEY",
        "minimax": "MINIMAX_API_KEY",
        "minimax-cn": "MINIMAX_API_KEY",
        "deepseek": "DEEPSEEK_API_KEY",
        "google": "GOOGLE_API_KEY",
        "openrouter": "OPENROUTER_API_KEY",
        "custom": "OPENCLAW_CUSTOM_PROVIDER_API_KEY",
    }
    has_key = bool(str(env_data.get(env_key_map.get(cfg["preset"], ""), "")).strip())
    return {
        "preset": cfg["preset"],
        "providerId": cfg["providerId"],
        "displayName": cfg["displayName"],
        "baseUrl": cfg["baseUrl"],
        "model": cfg["model"],
        "apiType": cfg["apiType"],
        "hasApiKey": has_key,
    }


def _image_provider_config_summary(env_data: dict, profile_payload: dict | None = None) -> dict:
    profile_payload = profile_payload if isinstance(profile_payload, dict) else {}
    data = profile_payload.get("imageProviderConfig") if isinstance(profile_payload.get("imageProviderConfig"), dict) else {}
    cfg = _normalize_image_provider_config(data, env_data)
    return {
        "providerId": cfg["providerId"],
        "displayName": cfg["displayName"],
        "baseUrl": cfg["baseUrl"],
        "model": cfg["model"],
        "hasApiKey": bool(str(env_data.get("OPENCLAW_IMAGE_API_KEY") or "").strip()),
    }

def _run_openclaw_config_set(key: str, value: str):
    if not shutil.which("openclaw"):
        return
    try:
        subprocess.run(
            ["openclaw", "config", "set", key, value],
            check=False,
            capture_output=True,
            text=True,
            timeout=8,
        )
    except Exception:
        pass


def _install_skill_via_openclaw(skill_id: str, timeout_sec: int = 30) -> bool:
    """Try installing a missing skill through OpenClaw CLI as a fallback."""
    if not skill_id or not shutil.which("openclaw"):
        return False
    try:
        proc = subprocess.run(
            ["openclaw", "skills", "add", skill_id],
            check=False,
            capture_output=True,
            text=True,
            timeout=timeout_sec,
        )
        if proc.returncode != 0:
            return False
        return os.path.isdir(os.path.join(OPENCLAW_SKILLS_DIR, skill_id))
    except Exception:
        return False


def _sanitize_identity_field(value, default: str, max_len: int = 240) -> str:
    text = str(value if value is not None else default).strip()
    if not text:
        text = default
    if len(text) > max_len:
        text = text[:max_len]
    return text


def _collect_identity_profile_from_env(env_data: dict, role_id: str) -> dict:
    role_meta = ROLE_META.get(role_id, ROLE_META["druid"])
    return {
        "assistantName": str(env_data.get("OPENCLAW_ASSISTANT_NAME") or "Clawd"),
        "userName": str(env_data.get("OPENCLAW_USER_NAME") or "主人"),
        "region": str(env_data.get("OPENCLAW_REGION") or "中国大陆"),
        "timezone": str(env_data.get("OPENCLAW_TIMEZONE") or "Asia/Shanghai"),
        "goal": str(env_data.get("OPENCLAW_USER_GOAL") or f"围绕{role_meta['className']}完成高质量任务"),
        "personality": str(env_data.get("OPENCLAW_ASSISTANT_PERSONALITY") or "严谨、务实、可协作"),
        "workStyle": str(env_data.get("OPENCLAW_ASSISTANT_WORK_MODE") or env_data.get("OPENCLAW_ASSISTANT_WORK_STYLE") or "先分析再执行，阶段性回报"),
    }


def _supports_openclaw_doctor_non_interactive() -> bool:
    if not shutil.which("openclaw"):
        return False
    try:
        proc = subprocess.run(
            ["openclaw", "doctor", "--help"],
            check=False,
            capture_output=True,
            text=True,
            timeout=8,
        )
        output = f"{proc.stdout or ''}\n{proc.stderr or ''}".lower()
        return "--non-interactive" in output
    except Exception:
        return False


def _run_openclaw_diag_command(cmd: str) -> dict:
    command = (cmd or "").strip().lower()
    if command not in {"doctor", "status", "health"}:
        return {"ok": False, "msg": "unsupported command", "code": 400}
    if not shutil.which("openclaw"):
        return {"ok": False, "msg": "openclaw not found", "code": 404}

    if command == "doctor":
        argv = ["openclaw", "doctor", "--non-interactive"] if _supports_openclaw_doctor_non_interactive() else ["openclaw", "doctor"]
        timeout = 60
    elif command == "status":
        argv = ["openclaw", "status"]
        timeout = 25
    else:
        argv = ["openclaw", "health"]
        timeout = 25

    try:
        proc = subprocess.run(
            argv,
            check=False,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        stdout = (proc.stdout or "").strip()
        stderr = (proc.stderr or "").strip()
        merged = "\n".join(part for part in [stdout, stderr] if part).strip()
        if len(merged) > 24000:
            merged = merged[:24000] + "\n...[truncated]"
        return {
            "ok": True,
            "code": int(proc.returncode),
            "command": command,
            "argv": argv,
            "stdout": stdout,
            "stderr": stderr,
            "output": merged,
            "ranAt": datetime.now().isoformat(),
        }
    except subprocess.TimeoutExpired:
        return {"ok": False, "msg": "command timeout", "command": command, "code": 504}
    except Exception as e:
        return {"ok": False, "msg": str(e), "command": command, "code": 500}


def _safe_skill_id_list(items) -> list[str]:
    output = []
    for item in items or []:
        name = str(item or "").strip()
        if re.fullmatch(r"[a-zA-Z0-9._-]+", name):
            output.append(name)
    return list(dict.fromkeys(output))


def _sync_skills_to_local(payload_skills: list[str], role_id: str, scope: str, equipped_tool_ids: list[str]):
    bundle_dir = _resolve_default_skills_bundle_dir()
    if not os.path.isdir(OPENCLAW_SKILLS_DIR):
        os.makedirs(OPENCLAW_SKILLS_DIR, exist_ok=True)

    role_baseline = ROLE_SKILL_MAP.get(role_id, ROLE_SKILL_MAP["druid"])
    desired = list(payload_skills or [])
    if scope in {"role", "all"}:
        desired = list(dict.fromkeys([*desired, *role_baseline]))
    for tool_id in equipped_tool_ids:
        desired.extend(TOOL_TO_SKILL_BINDINGS.get(tool_id, []))
    desired = list(dict.fromkeys(_safe_skill_id_list(desired)))

    managed_state = _json_read(OPENCLAW_WEB_MANAGED_SKILLS_JSON, {})
    prev_managed = set(_safe_skill_id_list(managed_state.get("managedSkills", [])))
    installed = []
    removed = []
    missing = []

    desired_set = set(desired)
    for stale in sorted(prev_managed - desired_set):
        stale_dir = os.path.join(OPENCLAW_SKILLS_DIR, stale)
        if os.path.isdir(stale_dir):
            try:
                shutil.rmtree(stale_dir)
                removed.append(stale)
            except Exception:
                pass

    allow_remote_install = scope in {"skills", "all"}
    for skill in desired:
        target_dir = os.path.join(OPENCLAW_SKILLS_DIR, skill)
        if os.path.isdir(target_dir):
            installed.append(skill)
            continue
        if not bundle_dir:
            if allow_remote_install and _install_skill_via_openclaw(skill):
                installed.append(skill)
            else:
                missing.append(skill)
            continue
        source_dir = os.path.join(bundle_dir, skill)
        if not os.path.isdir(source_dir):
            if allow_remote_install and _install_skill_via_openclaw(skill):
                installed.append(skill)
            else:
                missing.append(skill)
            continue
        try:
            shutil.copytree(source_dir, target_dir, dirs_exist_ok=True)
            installed.append(skill)
        except Exception:
            if allow_remote_install and _install_skill_via_openclaw(skill):
                installed.append(skill)
            else:
                missing.append(skill)

    managed_payload = {
        "updatedAt": datetime.now().isoformat(),
        "role": role_id,
        "managedSkills": sorted(desired_set),
    }
    _json_write(OPENCLAW_WEB_MANAGED_SKILLS_JSON, managed_payload)
    return {
        "bundleDir": bundle_dir or "",
        "desired": sorted(desired_set),
        "installed": sorted(set(installed)),
        "removed": sorted(set(removed)),
        "missing": sorted(set(missing)),
        "remoteInstallFallback": bool(allow_remote_install),
    }


def _apply_openclaw_side_effects_async(
    role_id: str,
    role_meta: dict,
    identity_profile: dict,
    model_route: str,
    skill_pack: str,
    security: list[str],
    hotbar: list[str],
    pinned: list[str],
    equipped: dict,
    disabled_skills: list[str],
):
    """Run slow OpenClaw sync commands in background to keep API response fast."""

    def _worker():
        try:
            _run_openclaw_config_set("identity.role.id", role_id)
            _run_openclaw_config_set("identity.role.name", role_meta.get("className", role_id))
            _run_openclaw_config_set("identity.name", identity_profile.get("assistantName", "Clawd"))
            _run_openclaw_config_set("identity.user_name", identity_profile.get("userName", "主人"))
            _run_openclaw_config_set("identity.region", identity_profile.get("region", "中国大陆"))
            _run_openclaw_config_set("identity.timezone", identity_profile.get("timezone", "Asia/Shanghai"))
            _run_openclaw_config_set("identity.goal", identity_profile.get("goal", "综合任务协作"))
            _run_openclaw_config_set("identity.personality", identity_profile.get("personality", "严谨、务实、可协作"))
            _run_openclaw_config_set("identity.work_style", identity_profile.get("workStyle", "先分析后执行，阶段性汇报"))
            _run_openclaw_config_set("vendor.control.persona.role.id", role_id)
            _run_openclaw_config_set("vendor.control.persona.role.name", role_meta.get("className", role_id))
            _run_openclaw_config_set("vendor.control.routing.mode", model_route)
            _run_openclaw_config_set("vendor.control.profile.skillPack", skill_pack)
            _run_openclaw_config_set("vendor.control.profile.security", json.dumps(security, ensure_ascii=False))
            _run_openclaw_config_set("vendor.control.profile.hotbar", json.dumps(hotbar, ensure_ascii=False))
            _run_openclaw_config_set("vendor.control.profile.pinnedSkills", json.dumps(pinned, ensure_ascii=False))
            _run_openclaw_config_set("vendor.control.profile.equipped", json.dumps(equipped, ensure_ascii=False))
            _run_openclaw_config_set("vendor.control.profile.disabledSkills", json.dumps(disabled_skills, ensure_ascii=False))
        except Exception:
            pass

        try:
            apply_script = os.path.join(_repo_root_path(), "scripts", "apply-web-profile.sh")
            if os.path.isfile(apply_script):
                subprocess.run(
                    ["bash", apply_script, OPENCLAW_WEB_PROFILE_JSON],
                    capture_output=True,
                    text=True,
                    timeout=60,
                    check=False,
                )
        except Exception:
            pass

    threading.Thread(target=_worker, name="openclaw-config-apply", daemon=True).start()


def _extract_runtime_from_state(state_obj: dict):
    src = state_obj if isinstance(state_obj, dict) else {}
    return {
        "state": str(src.get("state") or src.get("status") or "idle").lower(),
        "detail": str(src.get("detail") or src.get("message") or "等待任务"),
        "progress": max(0, min(100, int(float(src.get("progress") or 0)))),
        "updatedAt": str(src.get("updated_at") or src.get("updatedAt") or "-"),
    }


def _build_openclaw_status_summary():
    progress = _json_read(OPENCLAW_GAME_PROGRESS_JSON, {})
    profile_payload = _json_read(OPENCLAW_WEB_PROFILE_JSON, {})
    hero = progress.get("hero") or {}
    stats = progress.get("stats") or {}
    gear = progress.get("gear") or {}
    memory = gear.get("memory") or {}
    security = gear.get("security") or {}
    policy = gear.get("policy") or {}
    env_data = _read_env_exports()
    provider_summary = _provider_config_summary(env_data, profile_payload)
    image_provider_summary = _image_provider_config_summary(env_data, profile_payload)
    runtime = _collect_runtime_signals_cached()
    skill_catalog = _collect_skill_catalog()
    role_id = _normalize_persona_role(hero.get("classId") or env_data.get("OPENCLAW_PERSONA_ROLE") or "druid")

    def _to_int(value, default=0):
        try:
            return int(float(value))
        except Exception:
            return int(default)

    def _to_float(value, default=0.0):
        try:
            return float(value)
        except Exception:
            return float(default)

    hours_played = max(_to_float(stats.get("hoursPlayed"), 0.0), _to_float(runtime.get("hoursPlayed"), 0.0))
    tokens_used = max(_to_int(stats.get("tokensUsed"), 0), _to_int(runtime.get("tokensUsed"), 0))
    tasks_completed = max(_to_int(stats.get("tasksCompleted"), 0), _to_int(runtime.get("tasksCompleted"), 0))
    tasks_success = max(_to_int(stats.get("tasksSuccess"), 0), _to_int(runtime.get("tasksSuccess"), 0))
    if tasks_success > tasks_completed:
        tasks_success = tasks_completed
    success_rate = _to_float(stats.get("successRate"), 0.0)
    if tasks_completed > 0:
        success_rate = max(success_rate, round(tasks_success / max(1, tasks_completed), 4))

    installed_skills_count = max(
        _to_int(stats.get("installedSkillsCount"), 0),
        _to_int(runtime.get("installedSkillsCount"), 0),
        _to_int(skill_catalog.get("counts", {}).get("installed"), 0),
    )
    used_skills_count = max(_to_int(stats.get("usedSkillsCount"), 0), _to_int(runtime.get("usedSkillsCount"), 0))
    skill_usage_rate = _to_float(stats.get("skillUsageRate"), 0.0)
    if installed_skills_count > 0:
        skill_usage_rate = max(skill_usage_rate, round((used_skills_count / max(1, installed_skills_count)) * 100.0, 2))

    tokens_per_success = _to_float(stats.get("tokensPerSuccess"), 0.0)
    if tasks_success > 0:
        tokens_per_success = max(tokens_per_success, round(tokens_used / max(1, tasks_success), 2))
    elif tokens_used > 0:
        tokens_per_success = float(tokens_used)

    user_dissatisfaction = _to_float(stats.get("userDissatisfaction"), 0.0)
    if tasks_completed <= 0:
        user_dissatisfaction = max(user_dissatisfaction, 35.0 if tokens_used > 0 else 0.0)
    else:
        failure_ratio = 1.0 - success_rate
        token_pressure = min(1.0, (tokens_per_success / 200000.0) if tasks_success > 0 else 1.0)
        skill_idle = max(0.0, 1.0 - (skill_usage_rate / 100.0))
        calc_dissatisfaction = round(min(100.0, (failure_ratio * 0.55 + token_pressure * 0.25 + skill_idle * 0.20) * 100), 1)
        user_dissatisfaction = max(user_dissatisfaction, calc_dissatisfaction)

    xp = _to_int(hero.get("xp"), 0)
    if xp <= 0:
        xp = int(tasks_success * 120 + used_skills_count * 45 + min(tokens_used / 2000.0, 6000))
    level = max(1, _to_int(hero.get("level"), 0))
    if level <= 1 and xp > 0:
        level = max(1, min(99, int(xp // 320) + 1))
    xp_next_target = _to_int(hero.get("xpNextTarget"), 0)
    if xp_next_target <= 0:
        xp_next_target = level * 320
    xp_progress_percent = _to_int(hero.get("xpProgressPercent"), 0)
    if xp_progress_percent <= 0 and xp_next_target > 0:
        curr = xp - max(0, (level - 1) * 320)
        xp_progress_percent = max(0, min(100, int(round((curr / max(1, 320)) * 100))))

    main_model = (
        str(gear.get("mainModel") or "").strip()
        or str(provider_summary.get("model") or "").strip()
        or str(env_data.get("OPENCLAW_UNOFFICIAL_ADVANCED_MODEL") or "").strip()
        or str(env_data.get("OPENAI_MODEL") or "").strip()
        or str(env_data.get("OPENCLAW_GEMINI_IMAGE_MODEL") or "").strip()
        or "未配置"
    )
    fallback_model = (
        str(gear.get("fallbackModel") or "").strip()
        or str(env_data.get("SILICONFLOW_FALLBACK_MODEL") or "").strip()
        or str(env_data.get("OPENCLAW_UNOFFICIAL_OPENAI_MODEL") or "").strip()
        or "Qwen/Qwen3-8B"
    )

    identity = _collect_identity_profile_from_env(env_data, role_id)
    assistant_name = _sanitize_identity_field(
        hero.get("name") or identity.get("assistantName"),
        "Clawd",
        80,
    )
    rule_profile = str(policy.get("ruleProfile") or env_data.get("OPENCLAW_RULE_PROFILE") or "medium")
    default_image_quota, default_video_quota, default_text_quota = _default_quota_limits(rule_profile)
    quota_state = _collect_media_quota_state(env_data)
    media_quota = {
        "image": quota_state.get("image", {}),
        "video": quota_state.get("video", {}),
    }
    text_quota = quota_state.get("text", {})

    return {
        "assistantName": assistant_name,
        "role": role_id,
        "roleName": str(hero.get("className") or ROLE_META.get(role_id, ROLE_META["druid"])["className"]),
        "level": int(level),
        "xp": int(max(0, xp)),
        "xpNextTarget": int(max(1, xp_next_target)),
        "xpProgressPercent": int(max(0, min(100, xp_progress_percent))),
        "hoursPlayed": float(hours_played),
        "tokensUsed": int(max(0, tokens_used)),
        "tasksCompleted": int(max(0, tasks_completed)),
        "tasksSuccess": int(max(0, tasks_success)),
        "successRate": float(max(0.0, min(1.0, success_rate))),
        "tokensPerSuccess": float(max(0.0, tokens_per_success)),
        "skillUsageRate": float(max(0.0, min(100.0, skill_usage_rate))),
        "userDissatisfaction": float(max(0.0, min(100.0, user_dissatisfaction))),
        "installedSkillsCount": int(max(0, installed_skills_count)),
        "usedSkillsCount": int(max(0, used_skills_count)),
        "mainModel": main_model,
        "fallbackModel": fallback_model,
        "memory": {
            "bootMd": bool(memory.get("bootMd", True)),
            "sessionMemory": bool(memory.get("sessionMemory", True)),
        },
        "security": {
            "sandboxMode": bool(security.get("sandboxMode", False)),
        },
        "policy": {
            "ruleProfile": rule_profile,
            "windowHours": int(_to_int(policy.get("windowHours"), _to_int(env_data.get("OPENCLAW_RULE_WINDOW_HOURS"), 5))),
            "maxRequests": int(_to_int(policy.get("maxRequests"), _to_int(env_data.get("OPENCLAW_RULE_MAX_REQUESTS"), default_text_quota))),
            "maxTokens": int(_to_int(policy.get("maxTokens"), _to_int(env_data.get("OPENCLAW_RULE_MAX_TOKENS"), 2400000))),
            "maxTokensPerRequest": int(_to_int(policy.get("maxTokensPerRequest"), _to_int(env_data.get("OPENCLAW_RULE_MAX_TOKENS_PER_REQUEST"), 48000))),
            "maxImageRequests": int(_to_int(policy.get("maxImageRequests"), _to_int(env_data.get("OPENCLAW_RULE_MAX_IMAGE_REQUESTS"), default_image_quota))),
            "maxVideoRequests": int(_to_int(policy.get("maxVideoRequests"), _to_int(env_data.get("OPENCLAW_RULE_MAX_VIDEO_REQUESTS"), default_video_quota))),
            "mediaUsage": media_quota,
            "requestUsage": text_quota,
        },
        "identity": {
            "assistantName": assistant_name,
            "userName": _sanitize_identity_field(identity.get("userName"), "主人", 64),
            "region": _sanitize_identity_field(identity.get("region"), "中国大陆", 64),
            "timezone": _sanitize_identity_field(identity.get("timezone"), "Asia/Shanghai", 64),
            "goal": _sanitize_identity_field(identity.get("goal"), "综合任务协作", 300),
            "personality": _sanitize_identity_field(identity.get("personality"), "严谨、务实、可协作", 200),
            "workStyle": _sanitize_identity_field(identity.get("workStyle"), "先分析再执行，阶段性回报", 200),
        },
        "providerConfig": provider_summary,
        "imageProviderConfig": image_provider_summary,
        "signalsSource": str(runtime.get("signalsSource") or stats.get("signalsSource") or "runtime+cached"),
    }


def _apply_default_red_blue_background():
    if Image is None:
        raise RuntimeError("Pillow 不可用")
    target = FRONTEND_PATH / "office_bg_small.webp"
    if not target.exists():
        raise RuntimeError("office_bg_small.webp 不存在")
    bak = target.with_suffix(target.suffix + ".bak")
    shutil.copy2(target, bak)

    w, h = 1280, 720
    img = Image.new("RGBA", (w, h), (10, 18, 30, 255))
    px = img.load()
    tile = 8
    for y in range(h):
        for x in range(w):
            cx = x // tile
            cy = y // tile
            # red-blue checker with low contrast, fit pixel-house base.
            if (cx + cy) % 2 == 0:
                base = (26, 40, 78, 255)
            else:
                base = (72, 24, 36, 255)
            stripe = (x * 255) // max(1, w - 1)
            r = min(255, base[0] + stripe // 10)
            b = min(255, base[2] + (255 - stripe) // 10)
            px[x, y] = (r, base[1], b, 255)

    # Add center glow to keep room visibility.
    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    opx = overlay.load()
    cx, cy = w // 2, h // 2
    radius = min(w, h) * 0.46
    for y in range(h):
        for x in range(w):
            dx = x - cx
            dy = y - cy
            d = (dx * dx + dy * dy) ** 0.5
            a = max(0, min(95, int((1 - d / radius) * 95)))
            if a > 0:
                opx[x, y] = (70, 90, 140, a)
    merged = Image.alpha_composite(img, overlay).convert("RGB")
    merged.save(target, "WEBP", quality=92, method=6)
    return str(target)


def _provider_model_candidates(user_model: str):
    normalized = _normalize_user_model(user_model)
    return list(USER_MODEL_TO_PROVIDER_MODELS.get(normalized, USER_MODEL_TO_PROVIDER_MODELS["nanobanana-pro"]))


def _generate_rpg_background_to_webp(out_webp_path: str, width: int = 1280, height: int = 720, custom_prompt: str = "", speed_mode: str = "fast"):
    """Generate RPG-style room background and save as webp.

    speed_mode:
      - fast: use nanobanana-2 + 1024x576 intermediate + downscaled reference (faster)
      - quality: use configured model (fallback nanobanana-pro) + full 1280x720 path
    """
    runtime_cfg = load_runtime_config()
    api_key = (runtime_cfg.get("gemini_api_key") or "").strip()
    if not api_key:
        raise RuntimeError("MISSING_API_KEY")
    themes = [
        "8-bit dungeon guild room",
        "8-bit stardew-valley inspired cozy farm tavern",
        "8-bit nordic fantasy tavern",
        "8-bit magitech workshop",
        "8-bit elven forest inn",
        "8-bit pixel cyber tavern",
        "8-bit desert caravan inn",
        "8-bit snow mountain lodge",
    ]
    theme = random.choice(themes)

    if not (os.path.exists(GEMINI_PYTHON) and os.path.exists(GEMINI_SCRIPT)):
        raise RuntimeError("生图脚本环境缺失：gemini-image-generate 未安装")

    style_hint = (custom_prompt or "").strip()
    if not style_hint:
        style_hint = theme

    # 默认使用更稳妥的 quality 档，避免 fast 模型在部分 API 通道不可用
    mode = (speed_mode or "quality").strip().lower()
    if mode not in {"fast", "quality"}:
        mode = "quality"

    configured_user_model = _normalize_user_model(runtime_cfg.get("gemini_model") or "nanobanana-pro")
    if mode == "fast":
        preferred_user_model = "nanobanana-2"
        # fast 也提高基础清晰度：从 1024x576 提升到 1152x648（牺牲少量速度）
        gen_width, gen_height = 1152, 648
        ref_width, ref_height = 1152, 648
    else:
        preferred_user_model = configured_user_model
        gen_width, gen_height = width, height
        ref_width, ref_height = width, height

    # 同时规避可能触发 400 的特殊能力参数：
    # 仅 nanobanana-2 走 aspect-ratio，nanobanana-pro 交给模型默认比例（后续再标准化到 1280x720）
    allow_aspect_ratio = (preferred_user_model == "nanobanana-2")

    prompt = (
        "Use a top-down pixel room composition compatible with an office game scene. "
        "STRICTLY preserve the same room geometry, camera angle, wall/floor boundaries and major object placement as the provided reference image. "
        "Keep region layout stable (left work area, center lounge, right error area). "
        "Only change visual style/theme/material/lighting according to: " + style_hint + ". "
        "Do not add text or watermark. Retro 8-bit RPG style."
    )

    tmp_dir = tempfile.mkdtemp(prefix="rpg-bg-")
    cmd = [
        GEMINI_PYTHON,
        GEMINI_SCRIPT,
        "--prompt", prompt,
        "--model", configured_user_model,
        "--out-dir", tmp_dir,
        "--cleanup",
    ]
    if allow_aspect_ratio:
        cmd.extend(["--aspect-ratio", "16:9"])

    # 强约束：每次都带固定参考图，保持房间区域布局不漂移
    ref_for_call = None
    if os.path.exists(ROOM_REFERENCE_IMAGE):
        ref_for_call = ROOM_REFERENCE_IMAGE
        if mode == "fast" and Image is not None:
            try:
                ref_fast = os.path.join(tmp_dir, "room-reference-fast.webp")
                with Image.open(ROOM_REFERENCE_IMAGE) as rim:
                    rim = rim.convert("RGBA").resize((ref_width, ref_height), Image.Resampling.LANCZOS)
                    rim.save(ref_fast, "WEBP", quality=85, method=4)
                ref_for_call = ref_fast
            except Exception:
                ref_for_call = ROOM_REFERENCE_IMAGE

    if ref_for_call:
        cmd.extend(["--reference-image", ref_for_call])

    env = os.environ.copy()
    # 运行时配置优先：只保留 GEMINI_API_KEY，避免脚本因双 key 报错
    env.pop("GOOGLE_API_KEY", None)
    env["GEMINI_API_KEY"] = api_key

    def _run_cmd(cmd_args):
        return subprocess.run(cmd_args, capture_output=True, text=True, env=env, timeout=240)

    def _is_model_unavailable_error(text: str) -> bool:
        low = (text or "").strip().lower()
        return (
            ("not found" in low and "models/" in low)
            or ("model_not_available" in low)
            or ("model is not available" in low)
            or ("configured model is not available" in low)
            or ("this model is not available" in low)
            or ("not supported for generatecontent" in low)
        )

    def _with_model(cmd_args, model_name: str):
        m = cmd_args[:]
        if "--model" in m:
            idx = m.index("--model")
            if idx + 1 < len(m):
                m[idx + 1] = model_name
        else:
            m.extend(["--model", model_name])
        return m

    # 模型多级回退（仅允许两类用户模型：nanobanana-pro / nanobanana-2）
    # 每个用户模型映射到若干 provider 真实模型。
    user_model_order = [preferred_user_model, configured_user_model]
    user_model_order = [m for i, m in enumerate(user_model_order) if m and m not in user_model_order[:i]]

    model_candidates = []
    for um in user_model_order:
        model_candidates.extend(_provider_model_candidates(um))
    # 去重并清理空项
    model_candidates = [m for i, m in enumerate(model_candidates) if m and m not in model_candidates[:i]]

    proc = None
    last_err_text = ""
    model_unavailable_count = 0

    for mname in model_candidates:
        env["GEMINI_MODEL"] = mname
        try_cmd = _with_model(cmd, mname)
        proc = _run_cmd(try_cmd)
        if proc.returncode == 0:
            break

        err_text = (proc.stderr or proc.stdout or "").strip()
        last_err_text = err_text

        # key 失效/泄漏：立即终止，不继续尝试
        low = err_text.lower()
        if "your api key was reported as leaked" in low or "permission_denied" in low:
            raise RuntimeError("API_KEY_REVOKED_OR_LEAKED")

        if _is_model_unavailable_error(err_text):
            model_unavailable_count += 1
            continue

        # 非模型不可用错误，直接返回真实错误
        raise RuntimeError(f"生图失败: {err_text}")

    if proc is None or proc.returncode != 0:
        err_text = (last_err_text or "").strip()
        if model_unavailable_count >= len(model_candidates) or _is_model_unavailable_error(err_text):
            brief = (err_text or "").replace("\n", " ")[:240]
            raise RuntimeError(f"MODEL_NOT_AVAILABLE::{brief}")
        raise RuntimeError(f"生图失败: {err_text}")

    try:
        result = json.loads(proc.stdout.strip().splitlines()[-1])
    except Exception:
        raise RuntimeError("生图结果解析失败")

    files = result.get("files") or []
    if not files:
        raise RuntimeError("生图未返回文件")

    gen_path = files[0]
    if not os.path.exists(gen_path):
        raise RuntimeError("生图文件不存在")

    if Image is None:
        raise RuntimeError("Pillow 不可用，无法做尺寸标准化")

    with Image.open(gen_path) as im:
        im = im.convert("RGBA")
        # 质量模式优先保细节；快速模式优先速度
        if mode == "fast":
            im = im.resize((gen_width, gen_height), Image.Resampling.LANCZOS)
            if (gen_width, gen_height) != (width, height):
                # fast 的放大改为 LANCZOS，牺牲少量速度换更高细节
                im = im.resize((width, height), Image.Resampling.LANCZOS)
            im.save(out_webp_path, "WEBP", quality=96, method=6)
        else:
            # quality：确保输出标准尺寸，同时使用无损 webp，减少压缩损失
            if im.size != (width, height):
                im = im.resize((width, height), Image.Resampling.LANCZOS)
            im.save(out_webp_path, "WEBP", lossless=True, quality=100, method=6)


def state_to_area(state):
    """Map agent state to office area (breakroom / writing / error)."""
    return STATE_TO_AREA_MAP.get(state, "breakroom")


# Ensure files exist
if not os.path.exists(AGENTS_STATE_FILE):
    save_agents_state(DEFAULT_AGENTS)
if not os.path.exists(JOIN_KEYS_FILE):
    if os.path.exists(os.path.join(ROOT_DIR, "join-keys.sample.json")):
        try:
            with open(os.path.join(ROOT_DIR, "join-keys.sample.json"), "r", encoding="utf-8") as sf:
                sample = json.load(sf)
            save_join_keys(sample if isinstance(sample, dict) else {"keys": []})
        except Exception:
            save_join_keys({"keys": []})
    else:
        save_join_keys({"keys": []})

# Tighten runtime-config file perms if exists
if os.path.exists(RUNTIME_CONFIG_FILE):
    try:
        os.chmod(RUNTIME_CONFIG_FILE, 0o600)
    except Exception:
        pass


@app.route("/agents", methods=["GET"])
def get_agents():
    """Get full agents list (for multi-agent UI), with auto-cleanup on access"""
    agents = load_agents_state()
    now = datetime.now()

    cleaned_agents = []
    keys_data = load_join_keys()

    for a in agents:
        if a.get("isMain"):
            cleaned_agents.append(a)
            continue

        auth_expires_at_str = a.get("authExpiresAt")
        auth_status = a.get("authStatus", "pending")

        # 1) 超时未批准自动 leave
        if auth_status == "pending" and auth_expires_at_str:
            try:
                auth_expires_at = datetime.fromisoformat(auth_expires_at_str)
                if now > auth_expires_at:
                    key = a.get("joinKey")
                    if key:
                        key_item = next((k for k in keys_data.get("keys", []) if k.get("key") == key), None)
                        if key_item:
                            key_item["used"] = False
                            key_item["usedBy"] = None
                            key_item["usedByAgentId"] = None
                            key_item["usedAt"] = None
                    continue
            except Exception:
                pass

        # 2) 超时未推送自动离线（超过5分钟）
        last_push_at_str = a.get("lastPushAt")
        if auth_status == "approved" and last_push_at_str:
            try:
                last_push_at = datetime.fromisoformat(last_push_at_str)
                age = (now - last_push_at).total_seconds()
                if age > 300:  # 5分钟无推送自动离线
                    a["authStatus"] = "offline"
            except Exception:
                pass

        cleaned_agents.append(a)

    save_agents_state(cleaned_agents)
    save_join_keys(keys_data)

    return jsonify(cleaned_agents)


@app.route("/agent-approve", methods=["POST"])
def agent_approve():
    """Approve an agent (set authStatus to approved)"""
    try:
        data = request.get_json()
        agent_id = (data.get("agentId") or "").strip()
        if not agent_id:
            return jsonify({"ok": False, "msg": "缺少 agentId"}), 400

        agents = load_agents_state()
        target = next((a for a in agents if a.get("agentId") == agent_id and not a.get("isMain")), None)
        if not target:
            return jsonify({"ok": False, "msg": "未找到 agent"}), 404

        target["authStatus"] = "approved"
        target["authApprovedAt"] = datetime.now().isoformat()
        target["authExpiresAt"] = (datetime.now() + timedelta(hours=24)).isoformat()  # 默认授权24h

        save_agents_state(agents)
        return jsonify({"ok": True, "agentId": agent_id, "authStatus": "approved"})
    except Exception as e:
        return jsonify({"ok": False, "msg": str(e)}), 500


@app.route("/agent-reject", methods=["POST"])
def agent_reject():
    """Reject an agent (set authStatus to rejected and optionally revoke key)"""
    try:
        data = request.get_json()
        agent_id = (data.get("agentId") or "").strip()
        if not agent_id:
            return jsonify({"ok": False, "msg": "缺少 agentId"}), 400

        agents = load_agents_state()
        target = next((a for a in agents if a.get("agentId") == agent_id and not a.get("isMain")), None)
        if not target:
            return jsonify({"ok": False, "msg": "未找到 agent"}), 404

        target["authStatus"] = "rejected"
        target["authRejectedAt"] = datetime.now().isoformat()

        # Optionally free join key back to unused
        join_key = target.get("joinKey")
        keys_data = load_join_keys()
        if join_key:
            key_item = next((k for k in keys_data.get("keys", []) if k.get("key") == join_key), None)
            if key_item:
                key_item["used"] = False
                key_item["usedBy"] = None
                key_item["usedByAgentId"] = None
                key_item["usedAt"] = None

        # Remove from agents list
        agents = [a for a in agents if a.get("agentId") != agent_id or a.get("isMain")]

        save_agents_state(agents)
        save_join_keys(keys_data)
        return jsonify({"ok": True, "agentId": agent_id, "authStatus": "rejected"})
    except Exception as e:
        return jsonify({"ok": False, "msg": str(e)}), 500


@app.route("/join-agent", methods=["POST"])
def join_agent():
    """Add a new agent with one-time join key validation and pending auth"""
    try:
        data = request.get_json()
        if not isinstance(data, dict) or not data.get("name"):
            return jsonify({"ok": False, "msg": "请提供名字"}), 400

        name = data["name"].strip()
        state = data.get("state", "idle")
        detail = data.get("detail", "")
        join_key = data.get("joinKey", "").strip()

        # Normalize state early for compatibility
        state = normalize_agent_state(state)

        if not join_key:
            return jsonify({"ok": False, "msg": "请提供接入密钥"}), 400

        keys_data = load_join_keys()
        key_item = next((k for k in keys_data.get("keys", []) if k.get("key") == join_key), None)
        if not key_item:
            return jsonify({"ok": False, "msg": "接入密钥无效"}), 403
        # key 可复用：不再因为 used=true 拒绝

        with join_lock:
            # 在锁内重新读取，避免并发请求都基于同一旧快照通过校验
            keys_data = load_join_keys()
            key_item = next((k for k in keys_data.get("keys", []) if k.get("key") == join_key), None)
            if not key_item:
                return jsonify({"ok": False, "msg": "接入密钥无效"}), 403

            # Key-level expiration check
            key_expires_at_str = key_item.get("expiresAt")
            if key_expires_at_str:
                try:
                    key_expires_at = datetime.fromisoformat(key_expires_at_str)
                    if datetime.now() > key_expires_at:
                        return jsonify({"ok": False, "msg": "该接入密钥已过期，活动已结束 🎉"}), 403
                except Exception:
                    pass

            agents = load_agents_state()

            # 并发上限：同一个 key “同时在线”最多 3 个。
            # 在线判定：lastPushAt/updated_at 在 5 分钟内；否则视为 offline，不计入并发。
            now = datetime.now()
            existing = next((a for a in agents if a.get("name") == name and not a.get("isMain")), None)
            existing_id = existing.get("agentId") if existing else None

            def _age_seconds(dt_str):
                if not dt_str:
                    return None
                try:
                    dt = datetime.fromisoformat(dt_str)
                    return (now - dt).total_seconds()
                except Exception:
                    return None

            # opportunistic offline marking
            for a in agents:
                if a.get("isMain"):
                    continue
                if a.get("authStatus") != "approved":
                    continue
                age = _age_seconds(a.get("lastPushAt"))
                if age is None:
                    age = _age_seconds(a.get("updated_at"))
                if age is not None and age > 300:
                    a["authStatus"] = "offline"

            max_concurrent = int(key_item.get("maxConcurrent", 3))
            active_count = 0
            for a in agents:
                if a.get("isMain"):
                    continue
                if a.get("agentId") == existing_id:
                    continue
                if a.get("joinKey") != join_key:
                    continue
                if a.get("authStatus") != "approved":
                    continue
                age = _age_seconds(a.get("lastPushAt"))
                if age is None:
                    age = _age_seconds(a.get("updated_at"))
                if age is None or age <= 300:
                    active_count += 1

            if active_count >= max_concurrent:
                save_agents_state(agents)
                return jsonify({"ok": False, "msg": f"该接入密钥当前并发已达上限（{max_concurrent}），请稍后或换另一个 key"}), 429

            if existing:
                existing["state"] = state
                existing["detail"] = detail
                existing["updated_at"] = datetime.now().isoformat()
                existing["area"] = state_to_area(state)
                existing["source"] = "remote-openclaw"
                existing["joinKey"] = join_key
                existing["authStatus"] = "approved"
                existing["authApprovedAt"] = datetime.now().isoformat()
                existing["authExpiresAt"] = (datetime.now() + timedelta(hours=24)).isoformat()
                existing["lastPushAt"] = datetime.now().isoformat()  # join 视为上线，纳入并发/离线判定
                if not existing.get("avatar"):
                    import random
                    existing["avatar"] = random.choice(["guest_role_1", "guest_role_2", "guest_role_3", "guest_role_4", "guest_role_5", "guest_role_6"])
                agent_id = existing.get("agentId")
            else:
                # Use ms + random suffix to avoid collisions under concurrent joins
                import random
                import string
                agent_id = "agent_" + str(int(datetime.now().timestamp() * 1000)) + "_" + "".join(random.choices(string.ascii_lowercase + string.digits, k=4))
                agents.append({
                    "agentId": agent_id,
                    "name": name,
                    "isMain": False,
                    "state": state,
                    "detail": detail,
                    "updated_at": datetime.now().isoformat(),
                    "area": state_to_area(state),
                    "source": "remote-openclaw",
                    "joinKey": join_key,
                    "authStatus": "approved",
                    "authApprovedAt": datetime.now().isoformat(),
                    "authExpiresAt": (datetime.now() + timedelta(hours=24)).isoformat(),
                    "lastPushAt": datetime.now().isoformat(),
                    "avatar": random.choice(["guest_role_1", "guest_role_2", "guest_role_3", "guest_role_4", "guest_role_5", "guest_role_6"])
                })

            key_item["used"] = True
            key_item["usedBy"] = name
            key_item["usedByAgentId"] = agent_id
            key_item["usedAt"] = datetime.now().isoformat()
            key_item["reusable"] = True

            # 拿到有效 key 直接批准，不再等待主人手动点击
            # （状态已在上面 existing/new 分支写入）
            save_agents_state(agents)
            save_join_keys(keys_data)

        return jsonify({"ok": True, "agentId": agent_id, "authStatus": "approved", "nextStep": "已自动批准，立即开始推送状态"})
    except Exception as e:
        return jsonify({"ok": False, "msg": str(e)}), 500


@app.route("/leave-agent", methods=["POST"])
def leave_agent():
    """Remove an agent and free its one-time join key for reuse (optional)

    Prefer agentId (stable). Name is accepted for backward compatibility.
    """
    try:
        data = request.get_json()
        if not isinstance(data, dict):
            return jsonify({"ok": False, "msg": "invalid json"}), 400

        agent_id = (data.get("agentId") or "").strip()
        name = (data.get("name") or "").strip()
        if not agent_id and not name:
            return jsonify({"ok": False, "msg": "请提供 agentId 或名字"}), 400

        agents = load_agents_state()

        target = None
        if agent_id:
            target = next((a for a in agents if a.get("agentId") == agent_id and not a.get("isMain")), None)
        if (not target) and name:
            # fallback: remove by name only if agentId not provided
            target = next((a for a in agents if a.get("name") == name and not a.get("isMain")), None)

        if not target:
            return jsonify({"ok": False, "msg": "没有找到要离开的 agent"}), 404

        join_key = target.get("joinKey")
        new_agents = [a for a in agents if a.get("isMain") or a.get("agentId") != target.get("agentId")]

        # Optional: free key back to unused after leave
        keys_data = load_join_keys()
        if join_key:
            key_item = next((k for k in keys_data.get("keys", []) if k.get("key") == join_key), None)
            if key_item:
                key_item["used"] = False
                key_item["usedBy"] = None
                key_item["usedByAgentId"] = None
                key_item["usedAt"] = None

        save_agents_state(new_agents)
        save_join_keys(keys_data)
        return jsonify({"ok": True})
    except Exception as e:
        return jsonify({"ok": False, "msg": str(e)}), 500


@app.route("/status", methods=["GET"])
def get_status():
    """Get current main state (backward compatibility). Optionally include officeName from IDENTITY.md."""
    state = load_state()
    office_name = get_office_name_from_identity()
    if office_name:
        state["officeName"] = office_name
    return jsonify(state)


@app.route("/openclaw/status/summary", methods=["GET"])
def openclaw_status_summary():
    runtime = _extract_runtime_from_state(load_state())
    summary = _build_openclaw_status_summary()
    return jsonify({"ok": True, "runtime": runtime, "summary": summary})


@app.route("/openclaw/diagnose", methods=["POST"])
def openclaw_diagnose():
    data = request.get_json(silent=True) or {}
    command = str(data.get("cmd") or data.get("action") or "").strip().lower()
    result = _run_openclaw_diag_command(command)
    if result.get("ok"):
        return jsonify(result), 200
    code = int(result.get("code", 500) or 500)
    return jsonify(result), code


@app.route("/openclaw/catalog", methods=["GET"])
def openclaw_catalog():
    try:
        skills = _collect_skill_catalog_with_fallback()
        env_data = _read_env_exports()
        role_id = _normalize_persona_role(env_data.get("OPENCLAW_PERSONA_ROLE") or "druid")

        def _skill_obj(skill_id: str) -> dict:
            return {
                "id": skill_id,
                "name": _friendly_name_from_id(skill_id),
                "tier": "low",
                "branch": _guess_skill_branch(skill_id),
                "desc": _read_skill_description(skill_id),
                "deps": [],
                "roles": _role_ids_for_ui(),
                "pack": ["low", "medium", "high"],
                "dynamic": True,
            }

        all_skill_objects = [_skill_obj(sid) for sid in skills.get("all", [])]
        installed_set = set(skills.get("installed", []))
        available_set = set(skills.get("all", [])) - installed_set

        equipment = _collect_dynamic_loadout_items(env_data, skills.get("installed", []))
        return jsonify(
            {
                "ok": True,
                "role": role_id,
                "skills": {
                    "installed": sorted(installed_set),
                    "available": sorted(available_set),
                    "all": skills.get("all", []),
                    "objects": all_skill_objects,
                    "counts": skills.get("counts", {}),
                },
                "equipment": equipment,
                "diagnostic": skills.get("diagnostic", {}),
            }
        )
    except Exception as e:
        return jsonify({"ok": False, "msg": str(e)}), 500


@app.route("/openclaw/config/apply", methods=["POST"])
def openclaw_config_apply():
    try:
        data = request.get_json(silent=True) or {}
        if not isinstance(data, dict):
            return jsonify({"ok": False, "msg": "invalid json payload"}), 400

        scope = str(data.get("scope") or "all").strip().lower()
        if scope not in {"all", "role", "skills", "equipment", "status", "tasks"}:
            scope = "all"

        role_ui = str(data.get("role") or data.get("personaRole") or "druid")
        role_id = _normalize_persona_role(role_ui)
        role_meta = ROLE_META.get(role_id, ROLE_META["druid"])
        role_state = data.get("roleState") if isinstance(data.get("roleState"), dict) else {}
        draft_only = bool(data.get("draftOnly"))
        env_data = _read_env_exports()
        identity_defaults = _collect_identity_profile_from_env(env_data, role_id)
        identity_input = data.get("identity") if isinstance(data.get("identity"), dict) else {}
        provider_input = data.get("providerConfig") if isinstance(data.get("providerConfig"), dict) else {}
        image_provider_input = data.get("imageProviderConfig") if isinstance(data.get("imageProviderConfig"), dict) else {}
        identity_profile = {
            "assistantName": _sanitize_identity_field(identity_input.get("assistantName"), identity_defaults["assistantName"], 80),
            "userName": _sanitize_identity_field(identity_input.get("userName"), identity_defaults["userName"], 64),
            "region": _sanitize_identity_field(identity_input.get("region"), identity_defaults["region"], 64),
            "timezone": _sanitize_identity_field(identity_input.get("timezone"), identity_defaults["timezone"], 64),
            "goal": _sanitize_identity_field(identity_input.get("goal"), identity_defaults["goal"], 300),
            "personality": _sanitize_identity_field(identity_input.get("personality"), identity_defaults["personality"], 200),
            "workStyle": _sanitize_identity_field(identity_input.get("workStyle"), identity_defaults["workStyle"], 200),
        }

        model_route = str(role_state.get("modelRoute") or "balanced")
        token_rule = str(role_state.get("tokenRule") or "medium")
        skill_pack = str(role_state.get("skillPack") or "medium")
        security = [str(x) for x in (role_state.get("security") or []) if str(x).strip()]
        hotbar = _safe_skill_id_list(role_state.get("hotbar") or [])
        pinned = _safe_skill_id_list(role_state.get("pinnedSkills") or [])
        installed_skills = _safe_skill_id_list(role_state.get("installedSkills") or [])
        disabled_skills = _safe_skill_id_list(role_state.get("disabledSkills") or [])
        inventory = _safe_skill_id_list(role_state.get("inventory") or [])
        equipped = role_state.get("equipped") if isinstance(role_state.get("equipped"), dict) else {}
        normalized_provider_config = _normalize_provider_config(provider_input, env_data)
        normalized_image_provider_config = _normalize_image_provider_config(image_provider_input, env_data)
        stored_provider_config = {**normalized_provider_config, "apiKey": ""}
        stored_image_provider_config = {**normalized_image_provider_config, "apiKey": ""}

        equipped_tool_ids = []
        for slot_val in equipped.values():
            tool_id = str(slot_val or "").strip()
            if re.fullmatch(r"[a-zA-Z0-9._-]+", tool_id):
                equipped_tool_ids.append(tool_id)
        equipped_tool_ids = list(dict.fromkeys(equipped_tool_ids))

        profile_payload = {
            "version": 1,
            "generatedAt": datetime.now().isoformat(),
            "persona": {
                "id": role_id,
                "title": role_meta["title"],
                "className": role_meta["className"],
                "goal": ", ".join(ROLE_SKILL_MAP.get(role_id, [])),
            },
            "identity": identity_profile,
            "routing": {
                "modelRoute": model_route,
                "tokenRule": token_rule,
                "skillPack": skill_pack,
                "security": security,
            },
            "loadout": {
                "hotbar": hotbar,
                "pinnedSkills": pinned,
                "equipped": equipped,
                "inventory": inventory,
            },
            "uiState": {
                "disabledSkills": disabled_skills,
                "selectedSkillId": str(role_state.get("selectedSkillId") or ""),
                "selectedToolId": str(role_state.get("selectedToolId") or ""),
            },
            "providerConfig": stored_provider_config,
            "imageProviderConfig": stored_image_provider_config,
        }

        _json_write(OPENCLAW_WEB_PROFILE_JSON, profile_payload)
        _json_write(OPENCLAW_WEB_LOADOUT_JSON, {
            "persona": profile_payload["persona"],
            "identity": profile_payload["identity"],
            "routing": profile_payload["routing"],
            "loadout": profile_payload["loadout"],
            "uiState": profile_payload["uiState"],
        })

        _upsert_env_export("OPENCLAW_PERSONA_ROLE", role_id)
        _upsert_env_export("OPENCLAW_RULE_PROFILE", token_rule)
        _upsert_env_export("OPENCLAW_WEB_SKILL_PACK", skill_pack)
        _upsert_env_export("OPENCLAW_WEB_MODEL_ROUTE", model_route)
        _upsert_env_export("OPENCLAW_ASSISTANT_NAME", json.dumps(identity_profile["assistantName"], ensure_ascii=False))
        _upsert_env_export("OPENCLAW_USER_NAME", json.dumps(identity_profile["userName"], ensure_ascii=False))
        _upsert_env_export("OPENCLAW_REGION", json.dumps(identity_profile["region"], ensure_ascii=False))
        _upsert_env_export("OPENCLAW_TIMEZONE", json.dumps(identity_profile["timezone"], ensure_ascii=False))
        _upsert_env_export("OPENCLAW_USER_GOAL", json.dumps(identity_profile["goal"], ensure_ascii=False))
        _upsert_env_export("OPENCLAW_ASSISTANT_PERSONALITY", json.dumps(identity_profile["personality"], ensure_ascii=False))
        _upsert_env_export("OPENCLAW_ASSISTANT_WORK_MODE", json.dumps(identity_profile["workStyle"], ensure_ascii=False))
        _upsert_env_export("OPENCLAW_ASSISTANT_WORK_STYLE", json.dumps(identity_profile["workStyle"], ensure_ascii=False))
        _upsert_env_export("OPENCLAW_WEB_SECURITY", "'" + json.dumps(security, ensure_ascii=False) + "'")
        _upsert_env_export("OPENCLAW_WEB_HOTBAR", "'" + json.dumps(hotbar, ensure_ascii=False) + "'")
        _upsert_env_export("OPENCLAW_WEB_PINNED_SKILLS", "'" + json.dumps(pinned, ensure_ascii=False) + "'")
        _upsert_env_export("OPENCLAW_WEB_INVENTORY", "'" + json.dumps(inventory, ensure_ascii=False) + "'")
        _upsert_env_export("OPENCLAW_WEB_EQUIPPED", "'" + json.dumps(equipped, ensure_ascii=False) + "'")
        _upsert_env_export("OPENCLAW_WEB_DISABLED_SKILLS", "'" + json.dumps(disabled_skills, ensure_ascii=False) + "'")
        applied_provider_summary = _apply_provider_config(normalized_provider_config, env_data)
        applied_image_provider_summary = _apply_image_provider_config(normalized_image_provider_config, env_data)

        for env_key in sorted({k for m in TOOL_TO_ENV_BINDINGS.values() for k in m.keys()}):
            _upsert_env_export(env_key, "0")
        for tool_id in equipped_tool_ids:
            bindings = TOOL_TO_ENV_BINDINGS.get(tool_id) or {}
            for env_key, env_val in bindings.items():
                _upsert_env_export(env_key, env_val)

        if draft_only:
            script_result = {"used": False, "scheduled": False, "msg": "draft saved only"}
            skills_result = {
                "bundleDir": _resolve_default_skills_bundle_dir() or "",
                "desired": sorted(set(installed_skills)),
                "installed": _list_skill_dirs(OPENCLAW_SKILLS_DIR),
                "removed": [],
                "missing": [],
                "remoteInstallFallback": False,
            }
        else:
            _apply_openclaw_side_effects_async(
                role_id=role_id,
                role_meta=role_meta,
                identity_profile=identity_profile,
                model_route=model_route,
                skill_pack=skill_pack,
                security=security,
                hotbar=hotbar,
                pinned=pinned,
                equipped=equipped,
                disabled_skills=disabled_skills,
            )
            script_result = {"used": True, "scheduled": True, "msg": "background sync queued"}

            skills_result = _sync_skills_to_local(
                payload_skills=installed_skills,
                role_id=role_id,
                scope=scope,
                equipped_tool_ids=equipped_tool_ids,
            )

        summary = _build_openclaw_status_summary()
        summary["providerConfig"] = applied_provider_summary
        summary["imageProviderConfig"] = applied_image_provider_summary
        return jsonify({
            "ok": True,
            "scope": scope,
            "role": role_id,
            "draftOnly": draft_only,
            "skills": skills_result,
            "script": script_result,
            "summary": summary,
        })
    except Exception as e:
        return jsonify({"ok": False, "msg": str(e)}), 500


@app.route("/openclaw/tasks/dispatch", methods=["POST"])
def openclaw_task_dispatch():
    text_reservation_id = None
    try:
        data = request.get_json(silent=True) or {}
        prompt = str(data.get("prompt") or data.get("task") or "").strip()
        if not prompt:
            return jsonify({"ok": False, "msg": "缺少任务内容"}), 400

        text_reservation_id, quota_payload = _reserve_quota("text", 1, "openclaw-task-dispatch")
        if not text_reservation_id:
            reason = str((quota_payload or {}).get("reason") or "")
            code = 429 if reason in {"quota_exceeded", "disabled"} else 503
            message = str((quota_payload or {}).get("message") or "文本请求配额检查失败")
            return jsonify({"ok": False, "code": reason or "quota_error", "msg": message, "quota": quota_payload}), code

        role_id = _normalize_persona_role(data.get("role") or _read_env_exports().get("OPENCLAW_PERSONA_ROLE") or "druid")
        task_id = f"task_{int(time.time() * 1000)}"
        created_at = datetime.now().isoformat()
        state_payload = {
            "state": "executing",
            "detail": f"任务已派发：{prompt[:72]}",
            "progress": 12,
            "updated_at": created_at,
            "task_id": task_id,
            "role": role_id,
        }
        save_state(state_payload)
        _append_task_queue(
            {
                "id": task_id,
                "role": role_id,
                "prompt": prompt,
                "status": "queued",
                "createdAt": created_at,
            }
        )
        projection_ok = _push_projection_runtime("executing", state_payload["detail"], 12, source="openclaw-task-dispatch")
        _commit_quota(text_reservation_id)
        text_reservation_id = None
        return jsonify(
            {
                "ok": True,
                "task": {
                    "id": task_id,
                    "role": role_id,
                    "prompt": prompt,
                    "status": "queued",
                    "createdAt": created_at,
                },
                "projection": {"pushed": projection_ok},
                "runtime": _extract_runtime_from_state(state_payload),
            }
        )
    except Exception as e:
        _release_quota(text_reservation_id)
        return jsonify({"ok": False, "msg": str(e)}), 500


@app.route("/openclaw/theme/red-blue-default", methods=["POST"])
def openclaw_theme_red_blue_default():
    try:
        applied = _apply_default_red_blue_background()
        st = os.stat(applied)
        return jsonify({
            "ok": True,
            "path": os.path.relpath(applied, ROOT_DIR),
            "size": st.st_size,
            "msg": "已应用红蓝像素默认背景",
        })
    except Exception as e:
        return jsonify({"ok": False, "msg": str(e)}), 500


@app.route("/agent-push", methods=["POST"])
def agent_push():
    """Remote openclaw actively pushes status to office.

    Required fields:
    - agentId
    - joinKey
    - state
    Optional:
    - detail
    - name
    """
    try:
        data = request.get_json()
        if not isinstance(data, dict):
            return jsonify({"ok": False, "msg": "invalid json"}), 400

        agent_id = (data.get("agentId") or "").strip()
        join_key = (data.get("joinKey") or "").strip()
        state = (data.get("state") or "").strip()
        detail = (data.get("detail") or "").strip()
        name = (data.get("name") or "").strip()

        if not agent_id or not join_key or not state:
            return jsonify({"ok": False, "msg": "缺少 agentId/joinKey/state"}), 400

        state = normalize_agent_state(state)

        keys_data = load_join_keys()
        key_item = next((k for k in keys_data.get("keys", []) if k.get("key") == join_key), None)
        if not key_item:
            return jsonify({"ok": False, "msg": "joinKey 无效"}), 403

        # Key-level expiration check
        key_expires_at_str = key_item.get("expiresAt")
        if key_expires_at_str:
            try:
                key_expires_at = datetime.fromisoformat(key_expires_at_str)
                if datetime.now() > key_expires_at:
                    return jsonify({"ok": False, "msg": "该接入密钥已过期，活动已结束 🎉"}), 403
            except Exception:
                pass


        agents = load_agents_state()
        target = next((a for a in agents if a.get("agentId") == agent_id and not a.get("isMain")), None)
        if not target:
            return jsonify({"ok": False, "msg": "agent 未注册，请先 join"}), 404

        # Auth check: only approved agents can push.
        # Note: "offline" is a presence state (stale), not a revoked authorization.
        # Allow offline agents to resume pushing and auto-promote them back to approved.
        auth_status = target.get("authStatus", "pending")
        if auth_status not in {"approved", "offline"}:
            return jsonify({"ok": False, "msg": "agent 未获授权，请等待主人批准"}), 403
        if auth_status == "offline":
            target["authStatus"] = "approved"
            target["authApprovedAt"] = datetime.now().isoformat()
            target["authExpiresAt"] = (datetime.now() + timedelta(hours=24)).isoformat()

        if target.get("joinKey") != join_key:
            return jsonify({"ok": False, "msg": "joinKey 不匹配"}), 403

        target["state"] = state
        target["detail"] = detail
        if name:
            target["name"] = name
        target["updated_at"] = datetime.now().isoformat()
        target["area"] = state_to_area(state)
        target["source"] = "remote-openclaw"
        target["lastPushAt"] = datetime.now().isoformat()

        save_agents_state(agents)
        return jsonify({"ok": True, "agentId": agent_id, "area": target.get("area")})
    except Exception as e:
        return jsonify({"ok": False, "msg": str(e)}), 500


@app.route("/health", methods=["GET"])
def health():
    """Health check"""
    return jsonify({
        "status": "ok",
        "service": "star-office-ui",
        "timestamp": datetime.now().isoformat(),
    })


@app.route("/yesterday-memo", methods=["GET"])
def get_yesterday_memo():
    """获取昨日小日记"""
    try:
        # 先尝试找昨天的文件
        yesterday_str = get_yesterday_date_str()
        yesterday_file = os.path.join(MEMORY_DIR, f"{yesterday_str}.md")
        
        target_file = None
        target_date = yesterday_str
        
        if os.path.exists(yesterday_file):
            target_file = yesterday_file
        else:
            # 如果昨天没有，找最近的一天
            if os.path.exists(MEMORY_DIR):
                files = [f for f in os.listdir(MEMORY_DIR) if f.endswith(".md") and re.match(r"\d{4}-\d{2}-\d{2}\.md", f)]
                if files:
                    files.sort(reverse=True)
                    # 跳过今天的（如果存在）
                    today_str = datetime.now().strftime("%Y-%m-%d")
                    for f in files:
                        if f != f"{today_str}.md":
                            target_file = os.path.join(MEMORY_DIR, f)
                            target_date = f.replace(".md", "")
                            break
        
        if target_file and os.path.exists(target_file):
            memo_content = extract_memo_from_file(target_file)
            return jsonify({
                "success": True,
                "date": target_date,
                "memo": memo_content
            })
        else:
            return jsonify({
                "success": False,
                "msg": "没有找到昨日日记"
            })
    except Exception as e:
        return jsonify({
            "success": False,
            "msg": str(e)
        }), 500


@app.route("/set_state", methods=["POST"])
def set_state_endpoint():
    """Set state via POST (for UI control panel)"""
    try:
        data = request.get_json()
        if not isinstance(data, dict):
            return jsonify({"status": "error", "msg": "invalid json"}), 400
        state = load_state()
        if "state" in data:
            s = data["state"]
            if s in VALID_AGENT_STATES:
                state["state"] = s
        if "detail" in data:
            state["detail"] = data["detail"]
        state["updated_at"] = datetime.now().isoformat()
        save_state(state)
        return jsonify({"status": "ok"})
    except Exception as e:
        return jsonify({"status": "error", "msg": str(e)}), 500


@app.route("/assets/template.zip", methods=["GET"])
def assets_template_download():
    if not os.path.exists(ASSET_TEMPLATE_ZIP):
        return jsonify({"ok": False, "msg": "模板包不存在，请先生成"}), 404
    return send_from_directory(ROOT_DIR, "assets-replace-template.zip", as_attachment=True)


@app.route("/assets/list", methods=["GET"])
def assets_list():
    items = []
    for p in FRONTEND_PATH.rglob("*"):
        if not p.is_file():
            continue
        rel = p.relative_to(FRONTEND_PATH).as_posix()
        if rel.startswith("fonts/"):
            continue
        if p.suffix.lower() not in ASSET_ALLOWED_EXTS:
            continue
        st = p.stat()
        width = None
        height = None
        if Image is not None:
            try:
                with Image.open(p) as im:
                    width, height = im.size
            except Exception:
                pass
        items.append({
            "path": rel,
            "size": st.st_size,
            "ext": p.suffix.lower(),
            "width": width,
            "height": height,
            "mtime": datetime.fromtimestamp(st.st_mtime).isoformat(),
        })
    items.sort(key=lambda x: x["path"])
    return jsonify({"ok": True, "count": len(items), "items": items})


def _bg_generate_worker(task_id: str, custom_prompt: str, speed_mode: str, reservation_id: str | None = None):
    """Background worker for RPG background generation."""
    try:
        target = FRONTEND_PATH / "office_bg_small.webp"

        # 覆盖前保留最近一次备份
        bak = target.with_suffix(target.suffix + ".bak")
        shutil.copy2(target, bak)

        _generate_rpg_background_to_webp(
            str(target),
            width=1280,
            height=720,
            custom_prompt=custom_prompt,
            speed_mode=speed_mode,
        )

        # 每次生成都归档一份历史底图（可回溯风格演化）
        os.makedirs(BG_HISTORY_DIR, exist_ok=True)
        ts = datetime.now().strftime("%Y%m%d-%H%M%S")
        hist_file = os.path.join(BG_HISTORY_DIR, f"office_bg_small-{ts}.webp")
        shutil.copy2(target, hist_file)

        st = target.stat()
        with _bg_tasks_lock:
            _bg_tasks[task_id] = {
                "status": "done",
                "result": {
                    "ok": True,
                    "path": "office_bg_small.webp",
                    "size": st.st_size,
                    "history": os.path.relpath(hist_file, ROOT_DIR),
                    "speed_mode": speed_mode,
                    "msg": "已生成并替换 RPG 房间底图（已自动归档）",
                },
            }
        _commit_quota(reservation_id)
    except Exception as e:
        _release_quota(reservation_id)
        msg = str(e)
        error_result = {"ok": False, "msg": msg}
        if msg == "MISSING_API_KEY":
            error_result["code"] = "MISSING_API_KEY"
            error_result["msg"] = "Missing GEMINI_API_KEY or GOOGLE_API_KEY"
        elif msg == "API_KEY_REVOKED_OR_LEAKED":
            error_result["code"] = "API_KEY_REVOKED_OR_LEAKED"
            error_result["msg"] = "API key is revoked or flagged as leaked. Please rotate to a new key."
        elif msg.startswith("MODEL_NOT_AVAILABLE"):
            error_result["code"] = "MODEL_NOT_AVAILABLE"
            error_result["msg"] = "Configured model is not available for this API key/channel."
            if "::" in msg:
                error_result["detail"] = msg.split("::", 1)[1]
        with _bg_tasks_lock:
            _bg_tasks[task_id] = {"status": "error", "result": error_result}


@app.route("/assets/generate-rpg-background", methods=["POST"])
def assets_generate_rpg_background():
    """Start async RPG background generation. Returns a task_id for polling."""
    guard = _require_asset_editor_auth()
    if guard:
        return guard
    image_reservation_id = None
    try:
        req = request.get_json(silent=True) or {}
        custom_prompt = (req.get("prompt") or "").strip() if isinstance(req, dict) else ""
        speed_mode = (req.get("speed_mode") or "quality").strip().lower() if isinstance(req, dict) else "quality"
        if speed_mode not in {"fast", "quality"}:
            speed_mode = "fast"

        target = FRONTEND_PATH / "office_bg_small.webp"
        if not target.exists():
            return jsonify({"ok": False, "msg": "office_bg_small.webp 不存在"}), 404

        # Pre-flight checks that can fail fast (before spawning thread)
        runtime_cfg = load_runtime_config()
        api_key = (runtime_cfg.get("gemini_api_key") or "").strip()
        if not api_key:
            return jsonify({"ok": False, "code": "MISSING_API_KEY", "msg": "Missing GEMINI_API_KEY or GOOGLE_API_KEY"}), 400
        if not (os.path.exists(GEMINI_PYTHON) and os.path.exists(GEMINI_SCRIPT)):
            return jsonify({"ok": False, "msg": "生图脚本环境缺失：gemini-image-generate 未安装"}), 500

        # Check if another generation is already running
        with _bg_tasks_lock:
            for tid, task in _bg_tasks.items():
                if task.get("status") == "pending":
                    return jsonify({"ok": True, "async": True, "task_id": tid, "msg": "已有生图任务进行中，请等待完成"}), 200

        image_reservation_id, quota_payload = _reserve_quota("image", 1, "lobster-bg-generate")
        if not image_reservation_id:
            reason = str((quota_payload or {}).get("reason") or "")
            code = 429 if reason in {"quota_exceeded", "disabled"} else 503
            message = str((quota_payload or {}).get("message") or "图片配额检查失败")
            return jsonify({"ok": False, "code": reason or "quota_error", "msg": message, "quota": quota_payload}), code

        # Create async task
        import string as _string
        task_id = "gen_" + str(int(datetime.now().timestamp() * 1000)) + "_" + "".join(random.choices(_string.ascii_lowercase + _string.digits, k=4))
        with _bg_tasks_lock:
            _bg_tasks[task_id] = {
                "status": "pending",
                "created_at": datetime.now().isoformat(),
                "reservation_id": image_reservation_id,
            }

        t = threading.Thread(target=_bg_generate_worker, args=(task_id, custom_prompt, speed_mode, image_reservation_id), daemon=True)
        t.start()
        image_reservation_id = None

        return jsonify({"ok": True, "async": True, "task_id": task_id, "msg": "生图任务已启动，请通过 task_id 轮询结果"})
    except Exception as e:
        _release_quota(image_reservation_id)
        return jsonify({"ok": False, "msg": str(e)}), 500


@app.route("/assets/generate-rpg-background/poll", methods=["GET"])
def assets_generate_rpg_background_poll():
    """Poll async generation task status."""
    guard = _require_asset_editor_auth()
    if guard:
        return guard
    task_id = (request.args.get("task_id") or "").strip()
    if not task_id:
        return jsonify({"ok": False, "msg": "缺少 task_id"}), 400
    with _bg_tasks_lock:
        task = _bg_tasks.get(task_id)
    if not task:
        return jsonify({"ok": False, "msg": "任务不存在"}), 404
    status = task.get("status", "pending")
    if status == "pending":
        return jsonify({"ok": True, "status": "pending", "msg": "生图进行中..."})
    elif status == "done":
        # Clean up task after delivering result
        with _bg_tasks_lock:
            _bg_tasks.pop(task_id, None)
        return jsonify({"ok": True, "status": "done", **task.get("result", {})})
    else:
        with _bg_tasks_lock:
            _bg_tasks.pop(task_id, None)
        result = task.get("result", {})
        code = 400 if result.get("code") else 500
        return jsonify({"ok": False, "status": "error", **result}), code


@app.route("/assets/restore-reference-background", methods=["POST"])
def assets_restore_reference_background():
    """Restore office_bg_small.webp from fixed reference image."""
    guard = _require_asset_editor_auth()
    if guard:
        return guard
    try:
        target = FRONTEND_PATH / "office_bg_small.webp"
        if not target.exists():
            return jsonify({"ok": False, "msg": "office_bg_small.webp 不存在"}), 404
        if not os.path.exists(ROOM_REFERENCE_IMAGE):
            return jsonify({"ok": False, "msg": "参考图不存在"}), 404

        # 备份当前底图
        bak = target.with_suffix(target.suffix + ".bak")
        shutil.copy2(target, bak)

        # 快速路径：若参考图已是 1280x720 的 webp，直接拷贝（秒级）
        ref_ext = os.path.splitext(ROOM_REFERENCE_IMAGE)[1].lower()
        fast_copied = False
        if ref_ext == '.webp':
            try:
                with Image.open(ROOM_REFERENCE_IMAGE) as rim:
                    if rim.size == (1280, 720):
                        shutil.copy2(ROOM_REFERENCE_IMAGE, target)
                        fast_copied = True
            except Exception:
                fast_copied = False

        # 慢路径：仅在必要时重编码
        if not fast_copied:
            if Image is None:
                return jsonify({"ok": False, "msg": "Pillow 不可用"}), 500
            with Image.open(ROOM_REFERENCE_IMAGE) as im:
                im = im.convert("RGBA").resize((1280, 720), Image.Resampling.LANCZOS)
                im.save(target, "WEBP", quality=92, method=6)

        st = target.stat()
        return jsonify({
            "ok": True,
            "path": "office_bg_small.webp",
            "size": st.st_size,
            "msg": "已恢复初始底图",
        })
    except Exception as e:
        return jsonify({"ok": False, "msg": str(e)}), 500


@app.route("/assets/restore-last-generated-background", methods=["POST"])
def assets_restore_last_generated_background():
    """Restore office_bg_small.webp from latest bg-history snapshot."""
    guard = _require_asset_editor_auth()
    if guard:
        return guard
    try:
        target = FRONTEND_PATH / "office_bg_small.webp"
        if not target.exists():
            return jsonify({"ok": False, "msg": "office_bg_small.webp 不存在"}), 404

        if not os.path.isdir(BG_HISTORY_DIR):
            return jsonify({"ok": False, "msg": "暂无历史底图"}), 404

        files = [
            os.path.join(BG_HISTORY_DIR, x)
            for x in os.listdir(BG_HISTORY_DIR)
            if x.startswith("office_bg_small-") and x.endswith(".webp")
        ]
        if not files:
            return jsonify({"ok": False, "msg": "暂无历史底图"}), 404

        latest = max(files, key=lambda p: os.path.getmtime(p))

        bak = target.with_suffix(target.suffix + ".bak")
        shutil.copy2(target, bak)
        shutil.copy2(latest, target)

        st = target.stat()
        return jsonify({
            "ok": True,
            "path": "office_bg_small.webp",
            "size": st.st_size,
            "from": os.path.relpath(latest, ROOT_DIR),
            "msg": "已回退到最近一次生成底图",
        })
    except Exception as e:
        return jsonify({"ok": False, "msg": str(e)}), 500


@app.route("/assets/home-favorites/list", methods=["GET"])
def assets_home_favorites_list():
    guard = _require_asset_editor_auth()
    if guard:
        return guard
    try:
        data = _load_home_favorites_index()
        items = data.get("items") or []
        out = []
        for it in items:
            rel = (it.get("path") or "").strip()
            if not rel:
                continue
            abs_path = os.path.join(ROOT_DIR, rel)
            if not os.path.exists(abs_path):
                continue
            fn = os.path.basename(rel)
            out.append({
                "id": it.get("id"),
                "path": rel,
                "url": f"/assets/home-favorites/file/{fn}",
                "thumb_url": f"/assets/home-favorites/file/{fn}",
                "created_at": it.get("created_at") or "",
            })
        out.sort(key=lambda x: x.get("created_at") or "", reverse=True)
        return jsonify({"ok": True, "items": out})
    except Exception as e:
        return jsonify({"ok": False, "msg": str(e)}), 500


@app.route("/assets/home-favorites/file/<path:filename>", methods=["GET"])
def assets_home_favorites_file(filename):
    guard = _require_asset_editor_auth()
    if guard:
        return guard
    return send_from_directory(HOME_FAVORITES_DIR, filename)


@app.route("/assets/home-favorites/save-current", methods=["POST"])
def assets_home_favorites_save_current():
    guard = _require_asset_editor_auth()
    if guard:
        return guard
    try:
        src = FRONTEND_PATH / "office_bg_small.webp"
        if not src.exists():
            return jsonify({"ok": False, "msg": "office_bg_small.webp 不存在"}), 404

        _ensure_home_favorites_index()
        ts = datetime.now().strftime("%Y%m%d-%H%M%S")
        item_id = f"home-{ts}"
        fn = f"{item_id}.webp"
        dst = os.path.join(HOME_FAVORITES_DIR, fn)
        shutil.copy2(str(src), dst)

        idx = _load_home_favorites_index()
        items = idx.get("items") or []
        items.insert(0, {
            "id": item_id,
            "path": os.path.relpath(dst, ROOT_DIR),
            "created_at": datetime.now().isoformat(timespec="seconds"),
        })

        # 控制收藏数量上限，清理最旧项
        if len(items) > HOME_FAVORITES_MAX:
            extra = items[HOME_FAVORITES_MAX:]
            items = items[:HOME_FAVORITES_MAX]
            for it in extra:
                try:
                    p = os.path.join(ROOT_DIR, it.get("path") or "")
                    if os.path.exists(p):
                        os.remove(p)
                except Exception:
                    pass

        idx["items"] = items
        _save_home_favorites_index(idx)
        return jsonify({"ok": True, "id": item_id, "path": os.path.relpath(dst, ROOT_DIR), "msg": "已收藏当前地图"})
    except Exception as e:
        return jsonify({"ok": False, "msg": str(e)}), 500


@app.route("/assets/home-favorites/delete", methods=["POST"])
def assets_home_favorites_delete():
    guard = _require_asset_editor_auth()
    if guard:
        return guard
    try:
        data = request.get_json(silent=True) or {}
        item_id = (data.get("id") or "").strip()
        if not item_id:
            return jsonify({"ok": False, "msg": "缺少 id"}), 400

        idx = _load_home_favorites_index()
        items = idx.get("items") or []
        hit = next((x for x in items if (x.get("id") or "") == item_id), None)
        if not hit:
            return jsonify({"ok": False, "msg": "收藏项不存在"}), 404

        rel = hit.get("path") or ""
        abs_path = os.path.join(ROOT_DIR, rel)
        if os.path.exists(abs_path):
            try:
                os.remove(abs_path)
            except Exception:
                pass

        idx["items"] = [x for x in items if (x.get("id") or "") != item_id]
        _save_home_favorites_index(idx)
        return jsonify({"ok": True, "id": item_id, "msg": "已删除收藏"})
    except Exception as e:
        return jsonify({"ok": False, "msg": str(e)}), 500


@app.route("/assets/home-favorites/apply", methods=["POST"])
def assets_home_favorites_apply():
    guard = _require_asset_editor_auth()
    if guard:
        return guard
    try:
        data = request.get_json(silent=True) or {}
        item_id = (data.get("id") or "").strip()
        if not item_id:
            return jsonify({"ok": False, "msg": "缺少 id"}), 400

        idx = _load_home_favorites_index()
        items = idx.get("items") or []
        hit = next((x for x in items if (x.get("id") or "") == item_id), None)
        if not hit:
            return jsonify({"ok": False, "msg": "收藏项不存在"}), 404

        src = os.path.join(ROOT_DIR, hit.get("path") or "")
        if not os.path.exists(src):
            return jsonify({"ok": False, "msg": "收藏文件不存在"}), 404

        target = FRONTEND_PATH / "office_bg_small.webp"
        if not target.exists():
            return jsonify({"ok": False, "msg": "office_bg_small.webp 不存在"}), 404

        bak = target.with_suffix(target.suffix + ".bak")
        shutil.copy2(str(target), str(bak))
        shutil.copy2(src, str(target))

        st = target.stat()
        return jsonify({"ok": True, "path": "office_bg_small.webp", "size": st.st_size, "from": hit.get("path"), "msg": "已应用收藏地图"})
    except Exception as e:
        return jsonify({"ok": False, "msg": str(e)}), 500


@app.route("/assets/auth", methods=["POST"])
def assets_auth():
    try:
        data = request.get_json(silent=True) or {}
        pwd = (data.get("password") or "").strip()
        if pwd and pwd == ASSET_DRAWER_PASS_DEFAULT:
            session["asset_editor_authed"] = True
            return jsonify({"ok": True, "msg": "认证成功"})
        return jsonify({"ok": False, "msg": "验证码错误"}), 401
    except Exception as e:
        return jsonify({"ok": False, "msg": str(e)}), 500


@app.route("/assets/auth/status", methods=["GET"])
def assets_auth_status():
    return jsonify({
        "ok": True,
        "authed": _is_asset_editor_authed(),
        "drawer_default_pass": ASSET_DRAWER_PASS_DEFAULT == "1234",
    })


@app.route("/assets/positions", methods=["GET"])
def assets_positions_get():
    guard = _require_asset_editor_auth()
    if guard:
        return guard
    try:
        return jsonify({"ok": True, "items": load_asset_positions()})
    except Exception as e:
        return jsonify({"ok": False, "msg": str(e)}), 500


@app.route("/assets/positions", methods=["POST"])
def assets_positions_set():
    guard = _require_asset_editor_auth()
    if guard:
        return guard
    try:
        data = request.get_json(silent=True) or {}
        key = (data.get("key") or "").strip()
        x = data.get("x")
        y = data.get("y")
        scale = data.get("scale")
        if not key:
            return jsonify({"ok": False, "msg": "缺少 key"}), 400
        if x is None or y is None:
            return jsonify({"ok": False, "msg": "缺少 x/y"}), 400
        x = float(x)
        y = float(y)
        if scale is None:
            scale = 1.0
        scale = float(scale)

        all_pos = load_asset_positions()
        all_pos[key] = {"x": x, "y": y, "scale": scale, "updated_at": datetime.now().isoformat()}
        save_asset_positions(all_pos)
        return jsonify({"ok": True, "key": key, "x": x, "y": y, "scale": scale})
    except Exception as e:
        return jsonify({"ok": False, "msg": str(e)}), 500


@app.route("/assets/defaults", methods=["GET"])
def assets_defaults_get():
    guard = _require_asset_editor_auth()
    if guard:
        return guard
    try:
        return jsonify({"ok": True, "items": load_asset_defaults()})
    except Exception as e:
        return jsonify({"ok": False, "msg": str(e)}), 500


@app.route("/assets/defaults", methods=["POST"])
def assets_defaults_set():
    guard = _require_asset_editor_auth()
    if guard:
        return guard
    try:
        data = request.get_json(silent=True) or {}
        key = (data.get("key") or "").strip()
        x = data.get("x")
        y = data.get("y")
        scale = data.get("scale")
        if not key:
            return jsonify({"ok": False, "msg": "缺少 key"}), 400
        if x is None or y is None:
            return jsonify({"ok": False, "msg": "缺少 x/y"}), 400
        x = float(x)
        y = float(y)
        if scale is None:
            scale = 1.0
        scale = float(scale)

        all_defaults = load_asset_defaults()
        all_defaults[key] = {"x": x, "y": y, "scale": scale, "updated_at": datetime.now().isoformat()}
        save_asset_defaults(all_defaults)
        return jsonify({"ok": True, "key": key, "x": x, "y": y, "scale": scale})
    except Exception as e:
        return jsonify({"ok": False, "msg": str(e)}), 500


@app.route("/config/gemini", methods=["GET"])
def gemini_config_get():
    guard = _require_asset_editor_auth()
    if guard:
        return guard
    try:
        cfg = load_runtime_config()
        key = (cfg.get("gemini_api_key") or "").strip()
        masked = ("*" * max(0, len(key) - 4)) + key[-4:] if key else ""
        return jsonify({
            "ok": True,
            "has_api_key": bool(key),
            "api_key_masked": masked,
            "gemini_model": _normalize_user_model(cfg.get("gemini_model") or "nanobanana-pro"),
        })
    except Exception as e:
        return jsonify({"ok": False, "msg": str(e)}), 500


@app.route("/config/gemini", methods=["POST"])
def gemini_config_set():
    guard = _require_asset_editor_auth()
    if guard:
        return guard
    try:
        data = request.get_json(silent=True) or {}
        api_key = (data.get("api_key") or "").strip()
        model = _normalize_user_model((data.get("model") or "").strip() or "nanobanana-pro")
        payload = {"gemini_model": model}
        if api_key:
            payload["gemini_api_key"] = api_key
        save_runtime_config(payload)
        return jsonify({"ok": True, "msg": "Gemini 配置已保存"})
    except Exception as e:
        return jsonify({"ok": False, "msg": str(e)}), 500


@app.route("/assets/restore-default", methods=["POST"])
def assets_restore_default():
    guard = _require_asset_editor_auth()
    if guard:
        return guard
    try:
        data = request.get_json(silent=True) or {}
        rel_path = (data.get("path") or "").strip().lstrip("/")
        if not rel_path:
            return jsonify({"ok": False, "msg": "缺少 path"}), 400

        target = (FRONTEND_PATH / rel_path).resolve()
        try:
            target.relative_to(FRONTEND_PATH.resolve())
        except Exception:
            return jsonify({"ok": False, "msg": "非法 path"}), 400

        if not target.exists():
            return jsonify({"ok": False, "msg": "目标文件不存在"}), 404

        root, ext = os.path.splitext(str(target))
        default_path = root + ext + ".default"
        if not os.path.exists(default_path):
            return jsonify({"ok": False, "msg": "未找到默认资产快照"}), 404

        # 回滚前保留上一版
        bak = str(target) + ".bak"
        if os.path.exists(str(target)):
            shutil.copy2(str(target), bak)

        shutil.copy2(default_path, str(target))
        st = os.stat(str(target))
        return jsonify({"ok": True, "path": rel_path, "size": st.st_size, "msg": "已重置为默认资产"})
    except Exception as e:
        return jsonify({"ok": False, "msg": str(e)}), 500


@app.route("/assets/restore-prev", methods=["POST"])
def assets_restore_prev():
    guard = _require_asset_editor_auth()
    if guard:
        return guard
    try:
        data = request.get_json(silent=True) or {}
        rel_path = (data.get("path") or "").strip().lstrip("/")
        if not rel_path:
            return jsonify({"ok": False, "msg": "缺少 path"}), 400

        target = (FRONTEND_PATH / rel_path).resolve()
        try:
            target.relative_to(FRONTEND_PATH.resolve())
        except Exception:
            return jsonify({"ok": False, "msg": "非法 path"}), 400

        bak = str(target) + ".bak"
        if not os.path.exists(bak):
            return jsonify({"ok": False, "msg": "未找到上一版备份"}), 404

        shutil.copy2(str(target), bak + ".tmp") if os.path.exists(str(target)) else None
        shutil.copy2(bak, str(target))
        st = os.stat(str(target))
        return jsonify({"ok": True, "path": rel_path, "size": st.st_size, "msg": "已回退到上一版"})
    except Exception as e:
        return jsonify({"ok": False, "msg": str(e)}), 500


@app.route("/assets/upload", methods=["POST"])
def assets_upload():
    guard = _require_asset_editor_auth()
    if guard:
        return guard
    try:
        rel_path = (request.form.get("path") or "").strip().lstrip("/")
        backup = (request.form.get("backup") or "1").strip() != "0"
        f = request.files.get("file")

        if not rel_path or f is None:
            return jsonify({"ok": False, "msg": "缺少 path 或 file"}), 400

        target = (FRONTEND_PATH / rel_path).resolve()
        try:
            target.relative_to(FRONTEND_PATH.resolve())
        except Exception:
            return jsonify({"ok": False, "msg": "非法 path"}), 400

        if target.suffix.lower() not in ASSET_ALLOWED_EXTS:
            return jsonify({"ok": False, "msg": "仅允许上传图片/美术资源类型"}), 400

        if not target.exists():
            return jsonify({"ok": False, "msg": "目标文件不存在，请先从 /assets/list 选择 path"}), 404

        target.parent.mkdir(parents=True, exist_ok=True)

        # 首次上传前固化默认资产快照，供“重置为默认资产”使用
        default_snap = Path(str(target) + ".default")
        if not default_snap.exists():
            try:
                shutil.copy2(target, default_snap)
            except Exception:
                pass

        if backup:
            bak = target.with_suffix(target.suffix + ".bak")
            shutil.copy2(target, bak)

        auto_sheet = (request.form.get("auto_spritesheet") or "0").strip() == "1"
        ext_name = (f.filename or "").lower()

        if auto_sheet and target.suffix.lower() in {".webp", ".png"}:
            with tempfile.NamedTemporaryFile(suffix=os.path.splitext(ext_name)[1] or ".gif", delete=False) as tf:
                src_path = tf.name
                f.save(src_path)
            try:
                in_w, in_h = _probe_animated_frame_size(src_path)
                frame_w = int(request.form.get("frame_w") or (in_w or 64))
                frame_h = int(request.form.get("frame_h") or (in_h or 64))

                # 如果是静态图上传到精灵表目标，按网格切片而不是整图覆盖
                if not (ext_name.endswith(".gif") or ext_name.endswith(".webp")) and Image is not None:
                    try:
                        with Image.open(src_path) as sim:
                            sim = sim.convert("RGBA")
                            sw, sh = sim.size
                            if frame_w <= 0 or frame_h <= 0:
                                frame_w, frame_h = sw, sh
                            cols = max(1, sw // frame_w)
                            rows = max(1, sh // frame_h)
                            sheet_w = cols * frame_w
                            sheet_h = rows * frame_h
                            if sheet_w <= 0 or sheet_h <= 0:
                                raise RuntimeError("静态图尺寸与帧规格不匹配")

                            cropped = sim.crop((0, 0, sheet_w, sheet_h))
                            # 目标是 webp 仍按无损保存，避免像素损失
                            if target.suffix.lower() == ".webp":
                                cropped.save(str(target), "WEBP", lossless=True, quality=100, method=6)
                            else:
                                cropped.save(str(target), "PNG")

                            st = target.stat()
                            return jsonify({
                                "ok": True,
                                "path": rel_path,
                                "size": st.st_size,
                                "backup": backup,
                                "converted": {
                                    "from": ext_name.split(".")[-1] if "." in ext_name else "image",
                                    "to": "webp_spritesheet" if target.suffix.lower() == ".webp" else "png_spritesheet",
                                    "frame_w": frame_w,
                                    "frame_h": frame_h,
                                    "columns": cols,
                                    "rows": rows,
                                    "frames": cols * rows,
                                    "preserve_original": False,
                                    "pixel_art": True,
                                }
                            })
                    finally:
                        pass

                # 默认：优先保留输入帧尺寸；若前端传了强制值则按前端。
                preserve_original_val = request.form.get("preserve_original")
                if preserve_original_val is None:
                    preserve_original = True
                else:
                    preserve_original = preserve_original_val.strip() == "1"

                pixel_art = (request.form.get("pixel_art") or "1").strip() == "1"
                req_cols = int(request.form.get("cols") or 0)
                req_rows = int(request.form.get("rows") or 0)
                sheet_path, cols, rows, frames, out_fw, out_fh = _animated_to_spritesheet(
                    src_path,
                    frame_w,
                    frame_h,
                    out_ext=target.suffix.lower(),
                    preserve_original=preserve_original,
                    pixel_art=pixel_art,
                    cols=(req_cols if req_cols > 0 else None),
                    rows=(req_rows if req_rows > 0 else None),
                )
                shutil.move(sheet_path, str(target))
                st = target.stat()
                from_type = "gif" if ext_name.endswith(".gif") else "webp"
                to_type = "webp_spritesheet" if target.suffix.lower() == ".webp" else "png_spritesheet"
                return jsonify({
                    "ok": True,
                    "path": rel_path,
                    "size": st.st_size,
                    "backup": backup,
                    "converted": {
                        "from": from_type,
                        "to": to_type,
                        "frame_w": out_fw,
                        "frame_h": out_fh,
                        "columns": cols,
                        "rows": rows,
                        "frames": frames,
                        "preserve_original": preserve_original,
                        "pixel_art": pixel_art,
                    }
                })
            finally:
                try:
                    os.remove(src_path)
                except Exception:
                    pass

        f.save(str(target))
        st = target.stat()
        return jsonify({"ok": True, "path": rel_path, "size": st.st_size, "backup": backup})
    except Exception as e:
        return jsonify({"ok": False, "msg": str(e)}), 500


if __name__ == "__main__":
    raw_port = os.environ.get("STAR_BACKEND_PORT", "19000")
    try:
        backend_port = int(raw_port)
    except ValueError:
        backend_port = 19000
    if backend_port <= 0:
        backend_port = 19000

    print("=" * 50)
    print("Star Office UI - Backend State Service")
    print("=" * 50)
    print(f"State file: {STATE_FILE}")
    print(f"Listening on: http://0.0.0.0:{backend_port}")
    if backend_port != 19000:
        print(f"(Port override: set STAR_BACKEND_PORT to change; current: {raw_port})")
    else:
        print("(Set STAR_BACKEND_PORT to use a different port, e.g. 3009)")
    mode = "production" if is_production_mode() else "development"
    print(f"Mode: {mode}")
    if is_production_mode():
        print("Security hardening: ENABLED (strict checks)")
    else:
        weak_flags = []
        if not is_strong_secret(str(app.secret_key)):
            weak_flags.append("weak FLASK_SECRET_KEY/STAR_OFFICE_SECRET")
        if not is_strong_drawer_pass(ASSET_DRAWER_PASS_DEFAULT):
            weak_flags.append("weak ASSET_DRAWER_PASS")
        if weak_flags:
            print("Security hardening: WARNING (dev mode) -> " + ", ".join(weak_flags))
        else:
            print("Security hardening: OK")
    print("=" * 50)

    app.run(host="0.0.0.0", port=backend_port, debug=False)
