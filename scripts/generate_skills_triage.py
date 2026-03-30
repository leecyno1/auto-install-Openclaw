#!/usr/bin/env python3
from __future__ import annotations

import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
SKILLS_DIR = REPO_ROOT / "skills" / "default"
OUT_PATH = REPO_ROOT / "docs" / "skills-triage-2026-03-28.md"

# Must-install (kept aligned with install.sh/config-menu.sh baseline bundles)
MUST_INSTALL = {
    "agent-browser",
    "agentmail",
    "agentmail-cli",
    "agentmail-mcp",
    "agentmail-toolkit",
    "akshare-stock",
    "brainstorming",
    "chrome-devtools-mcp",
    "content-strategy",
    "data-analyst",
    "docx",
    "finance-data",
    "format-pro",
    "github",
    "lark-calendar",
    "media-downloader",
    "minimax-image-understanding",
    "minimax-web-search",
    "model-usage",
    "openclaw-cron-setup",
    "pdf",
    "nano-pdf",
    "notebooklm-skill",
    "pptx",
    "preflight-checks",
    "proactive-agent",
    "publish-guard",
    "reflection",
    "self-improving-agent-cn",
    "session-logs",
    "shell",
    "skill-creator",
    "skill-security-auditor",
    "social-content",
    "stock-monitor-skill",
    "subagent-driven-development",
    "summarize",
    "task",
    "todo",
    "using-superpowers",
    "verification-before-completion",
    "weather",
    "writing-skills",
    "xlsx",
}

# API-key-needed bucket (excluding MUST_INSTALL and forced-other prefixes).
API_REQUIRED = {
    "capability-evolver",
    "data-reconciliation-exceptions",
    "douyin-upload-skill",
    "gemini-image-service",
    "grok-imagine-1.0-video",
    "imagegen",
    "logo-creator",
    "nanobanana",
    "oracle",
    "paperless-docs",
    "paperless-ngx-tools",
    "producthunt",
    "requesthunt",
    "skill-installer",
    "tavily-search",
    "twitter",
    "video-agent",
    "wechat-multi-publisher",
    "wechat-public-cli",
    "wechat-search",
    "xiaohongshutools",
    "yoinkit",
}

CATEGORY_MAP = {
    "Agent编排与流程": {
        "agent-builder",
        "dispatching-parallel-agents",
        "planning-with-files",
        "writing-plans",
    },
    "开发工程与代码质量": {
        "database",
        "gitclassic",
        "github-actions-generator",
        "mcp-builder",
        "merge-pr",
        "mintlify",
        "plugin-creator",
        "prepare-pr",
        "prisma-database-setup",
        "receiving-code-review",
        "requesting-code-review",
        "review-pr",
        "tailwind",
        "tdd",
        "test-driven-development",
        "ui-ux-pro-max",
        "using-git-worktrees",
        "web-artifacts-builder",
        "webapp-testing",
    },
    "搜索情报与数据抓取": {
        "bilibili-youtube-watcher",
        "blogwatcher",
        "domain-hunter",
        "google-trends",
        "multi-search-engine",
        "news-radar",
        "openclaw-feeds",
        "url-to-markdown",
        "web-search",
    },
    "内容营销与社媒运营": {
        "content-brief-builder",
        "content-intake-hub",
        "larry",
        "marketing-psychology",
        "marketingskills",
        "programmatic-seo",
        "pua",
        "seo-geo",
    },
    "设计视觉与多媒体生成": {
        "ai-image-generation",
        "ai-music-generation",
        "ai-music-prompts",
        "animation",
        "canvas-design",
        "demo-video",
        "frontend-design",
        "infographic-pro",
        "planner-image-post",
        "planner-video-script",
        "remotion",
        "remotion-best-practices",
        "remotion-video",
        "remotion-video-toolkit",
        "tailwind-design-system",
        "video-download",
        "video-frames",
        "video-subtitles",
        "web-animation-design",
        "web-design",
        "web-design-guidelines",
        "weibo-manager",
    },
    "文档办公与知识管理": {
        "ai-meeting-notes",
        "doc-coauthoring",
        "editorial-reviewer",
        "internal-comms",
        "jupyter-notebook",
        "material-pack-builder",
        "openai-docs",
        "todoist-api",
    },
    "平台发布与渠道自动化": {
        "douyin-hot-trend",
        "himalaya",
        "reddit",
        "wechat-article-extractor-skill",
        "wechat-draft-writer",
        "wechat-style-profiler",
        "wechat-title-generator",
        "wechat-topic-outline-planner",
        "weibo-fresh-posts",
        "xiaohongshu-auto",
        "xiaohongshu-extract",
        "xiaohongshu-ops",
        "zhihu-post",
    },
    "系统工具与运维": {
        "gh-modify-pr",
        "high-agency",
        "systematic-debugging",
        "theme-factory",
        "tmux",
    },
}

API_KEY_OVERRIDES = {
    "capability-evolver": ["GH_TOKEN", "GITHUB_TOKEN"],
    "data-reconciliation-exceptions": ["DUPLICATE_KEY", "INVALID_KEY"],
    "douyin-upload-skill": [
        "DOUYIN_ASR_API_KEY",
        "DOUYIN_CLIENT_KEY",
        "DOUYIN_CLIENT_SECRET",
        "DOUYIN_TOKEN_ENC_KEY",
    ],
    "gemini-image-service": ["GEMINI_API_KEY"],
    "grok-imagine-1.0-video": ["GROK_IMAGINE_API_KEY"],
    "imagegen": ["OPENAI_API_KEY"],
    "logo-creator": ["GEMINI_API_KEY", "RECRAFT_API_KEY", "REMOVE_BG_API_KEY"],
    "nanobanana": ["GEMINI_API_KEY"],
    "oracle": ["OPENAI_API_KEY"],
    "paperless-docs": ["PAPERLESS_TOKEN"],
    "paperless-ngx-tools": ["PAPERLESS_TOKEN"],
    "producthunt": ["PRODUCTHUNT_ACCESS_TOKEN"],
    "requesthunt": ["REQUESTHUNT_API_KEY"],
    "skill-installer": ["GH_TOKEN", "GITHUB_TOKEN"],
    "tavily-search": ["TAVILY_API_KEY"],
    "twitter": ["TWITTERAPI_API_KEY"],
    "video-agent": ["HEYGEN_API_KEY"],
    "wechat-multi-publisher": ["WECHAT_APP_SECRET"],
    "wechat-public-cli": [
        "BJH_TOKEN",
        "WECHAT_ACCESS_TOKEN",
        "WECHAT_SECRET",
        "YOUR_APP_SECRET",
        "YOUR_BJH_TOKEN",
    ],
    "wechat-search": ["TAVILY_API_KEY"],
    "xiaohongshutools": ["XIAOHONGSHU_COOKIE（或登录态）"],
    "yoinkit": ["YOINKIT_API_TOKEN"],
}

DESCRIPTION_OVERRIDES = {
    "publish-guard": "发布核验与平台凭据管理，防止“已发布但链接404/未落地”的假成功回报。",
}

ENV_VAR_PATTERN = re.compile(r"\b[A-Z][A-Z0-9_]{2,}\b")
DESC_PATTERN = re.compile(r'^description:\s*["\']?(.*?)["\']?$', re.M)
FRONTMATTER_KEY_PATTERN = re.compile(r"^[A-Za-z0-9_-]+:\s*.*$")


def clean_desc(text: str) -> str:
    t = " ".join(text.strip().split())
    t = t.replace("|", " ")
    if len(t) > 90:
        t = t[:87].rstrip() + "..."
    return t


def parse_description(skill_dir: Path) -> str:
    skill_md = skill_dir / "SKILL.md"
    if not skill_md.exists():
        return "未提供说明。"
    text = skill_md.read_text(encoding="utf-8", errors="ignore")

    # 1) YAML frontmatter description (supports multiline | or > blocks)
    if text.startswith("---\n"):
        parts = text.split("\n---\n", 1)
        if len(parts) == 2:
            fm = parts[0].splitlines()[1:]
            i = 0
            while i < len(fm):
                line = fm[i]
                if line.startswith("description:"):
                    raw = line.split(":", 1)[1].strip()
                    if raw and raw not in {"|", ">"}:
                        return clean_desc(raw.strip("\"'"))
                    block: list[str] = []
                    j = i + 1
                    while j < len(fm):
                        cur = fm[j]
                        if cur.startswith(("  ", "\t")):
                            block.append(cur.strip())
                            j += 1
                            continue
                        if FRONTMATTER_KEY_PATTERN.match(cur):
                            break
                        if not cur.strip():
                            block.append("")
                            j += 1
                            continue
                        break
                    merged = " ".join(x for x in block if x.strip())
                    if merged.strip():
                        return clean_desc(merged)
                    break
                i += 1

    # 2) single-line description fallback
    m = DESC_PATTERN.search(text)
    if m and m.group(1).strip():
        return clean_desc(m.group(1))

    # 3) first meaningful body line fallback
    lines = text.splitlines()
    in_frontmatter = False
    for i, line in enumerate(lines):
        if i == 0 and line.strip() == "---":
            in_frontmatter = True
            continue
        if in_frontmatter:
            if line.strip() == "---":
                in_frontmatter = False
            continue
        s = line.strip()
        if (
            not s
            or s.startswith("#")
            or s.startswith("```")
            or s.startswith("<!--")
            or s.endswith("-->")
        ):
            continue
        return clean_desc(s)
    return "未提供说明。"


def detect_env_keys(skill_dir: Path) -> list[str]:
    skill_md = skill_dir / "SKILL.md"
    if not skill_md.exists():
        return []
    text = skill_md.read_text(encoding="utf-8", errors="ignore")
    keys = set()
    for token in ENV_VAR_PATTERN.findall(text):
        if (
            token.endswith(("_KEY", "_TOKEN", "_SECRET", "_PASSWORD"))
            or "API_KEY" in token
            or token in {"GH_TOKEN", "GITHUB_TOKEN", "CLIENT_KEY", "CLIENT_SECRET"}
        ):
            keys.add(token)
    return sorted(keys)


def fmt_keys(keys: list[str]) -> str:
    if not keys:
        return "见 `SKILL.md`"
    return "、".join(f"`{k}`" for k in keys)


def render_skill_line(skill: str, skill_dir: Path, include_api: bool) -> str:
    desc = DESCRIPTION_OVERRIDES.get(skill, parse_description(skill_dir))
    if not include_api:
        return f"- `{skill}`：{desc}"
    keys = API_KEY_OVERRIDES.get(skill, detect_env_keys(skill_dir))
    return f"- `{skill}`：{desc}；API Key: {fmt_keys(keys)}"


def main() -> int:
    skill_dirs = {p.name: p for p in SKILLS_DIR.iterdir() if p.is_dir() and (p / "SKILL.md").exists()}
    all_skills = set(skill_dirs.keys())

    must = sorted(MUST_INSTALL & all_skills)
    forced_other = {s for s in all_skills if s.startswith("baoyu-") or s.startswith("dasheng-")}
    api = sorted((API_REQUIRED & all_skills) - set(must) - forced_other)

    available = all_skills - set(must) - set(api) - forced_other

    cat_skills: dict[str, list[str]] = {}
    used = set()
    for cat, names in CATEGORY_MAP.items():
        selected = sorted((names & available) - used)
        cat_skills[cat] = selected
        used.update(selected)

    other = sorted((available - used) | forced_other)
    covered = set(must) | set(api) | used | set(other)
    if covered != all_skills:
        other = sorted(set(other) | (all_skills - covered))

    lines: list[str] = []
    lines.append("# 本地 Skills 三分类清单（2026-03-28）")
    lines.append("")
    lines.append(f"- 总技能数: **{len(all_skills)}**")
    lines.append(f"- 基础必装: **{len(must)}**")
    lines.append(f"- 需要 API Key（不含基础必装）: **{len(api)}**")
    lines.append(f"- 功能性分类（排除前两类）: **{len(all_skills)-len(must)-len(api)}**")
    lines.append("- 强制归类规则: `baoyu*`、`dasheng*` 全部归入“其他”")
    lines.append("")
    lines.append("## 一、基础必装（每项附用途说明）")
    for name in must:
        lines.append(render_skill_line(name, skill_dirs[name], include_api=False))
    lines.append("")
    lines.append("## 二、需要 API Key（每项附用途说明 + 所需 Key）")
    for name in api:
        lines.append(render_skill_line(name, skill_dirs[name], include_api=True))
    lines.append("")
    lines.append("## 三、功能性分类（不含前两类，且不重复）")

    order = [
        "Agent编排与流程",
        "开发工程与代码质量",
        "搜索情报与数据抓取",
        "内容营销与社媒运营",
        "设计视觉与多媒体生成",
        "文档办公与知识管理",
        "平台发布与渠道自动化",
        "系统工具与运维",
    ]
    for cat in order:
        arr = cat_skills[cat]
        lines.append(f"### {cat}（{len(arr)}）")
        if not arr:
            lines.append("- （无）")
            lines.append("")
            continue
        for name in arr:
            lines.append(render_skill_line(name, skill_dirs[name], include_api=False))
        lines.append("")

    lines.append(f"### 其他（{len(other)}）")
    for name in other:
        lines.append(render_skill_line(name, skill_dirs[name], include_api=False))
    lines.append("")

    OUT_PATH.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUT_PATH} (skills={len(all_skills)}, must={len(must)}, api={len(api)})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
