#!/usr/bin/env python3
from __future__ import annotations

import datetime as dt
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from urllib.parse import urlparse

REPO_ROOT = Path(__file__).resolve().parents[1]
SKILLS_DIR = REPO_ROOT / 'skills' / 'default'
REPORT_PATH = REPO_ROOT / 'docs' / 'skills-update-report.md'
UPSTREAM_DOC = REPO_ROOT / 'docs' / 'upstream-sources.md'
LOCAL_SOURCE_ROOTS = [
    Path.home() / '.openclaw' / 'skills',
    Path.home() / '.codex' / 'skills',
    Path.home() / '.agents' / 'skills',
]
AGENTMAIL_REPO = 'https://github.com/agentmail-to/agentmail-skills.git'
AGENTMAIL_SKILLS = {'agentmail', 'agentmail-cli', 'agentmail-mcp', 'agentmail-toolkit'}
IGNORE_NAMES = {'.DS_Store', 'GUIDE.md', '__pycache__'}
ENABLE_NPX_CLAWHUB = os.environ.get('OPENCLAW_ENABLE_NPX_CLAWHUB', '').lower() in {'1', 'true', 'yes', 'on'}
LOCAL_NAME_ALIASES = {
    'openai-docs': ['.system/openai-docs'],
    'plugin-creator': ['.system/plugin-creator'],
    'skill-installer': ['.system/skill-installer'],
    'tdd': ['test-driven-development'],
    'frontend-dev': ['frontend-design'],
    'fullstack-dev': ['fullstack-guardian'],
    'flutter-dev': ['flutter-expert'],
    'ios-application-dev': ['iosdev-cn'],
    'react-native-dev': ['react-native-skills'],
    'pptx-generator': ['pptx'],
    'web-design': ['web-design-guidelines'],
}
CLAWHUB_SLUG_ALIASES = {
    'agent-browser': 'openclaw-agent-browser',
}


def display_path(path: Path) -> str:
    try:
        rel = path.relative_to(REPO_ROOT)
        return rel.as_posix() or '.'
    except ValueError:
        pass
    home = Path.home()
    try:
        rel = path.relative_to(home)
        return f"~/{rel.as_posix()}" if rel.as_posix() != '.' else '~'
    except ValueError:
        return str(path)


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def snapshot_tree(root: Path) -> dict[str, str]:
    items: dict[str, str] = {}
    if not root.exists():
        return items
    for path in sorted(root.rglob('*')):
        rel = path.relative_to(root).as_posix()
        if any(part in IGNORE_NAMES for part in path.parts):
            continue
        if path.is_dir():
            items[rel + '/'] = 'dir'
        elif path.is_file():
            items[rel] = sha256_file(path)
    return items


def copy_tree(src: Path, dst: Path) -> None:
    if dst.exists():
        shutil.rmtree(dst)
    shutil.copytree(src, dst)


def hash_path(path: Path) -> str:
    if path.is_dir():
        return hashlib.sha256(repr(sorted(snapshot_tree(path).items())).encode()).hexdigest()
    if path.is_file():
        if path.suffix == '.json' and path.name.endswith('.clawhub.json'):
            return hashlib.sha256(extract_clawhub_skill_text(path).encode('utf-8')).hexdigest()
        return sha256_file(path)
    return ''


def resolve_sync_target(skill_dir: Path, source_path: Path) -> Path:
    if source_path.is_file() and source_path.suffix == '.json' and source_path.name.endswith('.clawhub.json'):
        return skill_dir / 'SKILL.md'
    if source_path.is_file():
        return skill_dir / 'references' / 'upstream-README.md'
    return skill_dir


def copy_source(source_path: Path, skill_dir: Path) -> None:
    target = resolve_sync_target(skill_dir, source_path)
    if source_path.is_dir():
        copy_tree(source_path, target)
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    if source_path.suffix == '.json' and source_path.name.endswith('.clawhub.json'):
        target.write_text(extract_clawhub_skill_text(source_path), encoding='utf-8')
        return
    shutil.copy2(source_path, target)


def sync_detail(source_path: Path, source_kind: str, changed: bool) -> str:
    if source_kind == 'clawhub':
        return '已同步 ClawHub 发布包' if changed else '与 ClawHub 发布包一致'
    if source_path.is_file() and source_path.suffix == '.json' and source_path.name.endswith('.clawhub.json'):
        return '已同步 ClawHub 最新 SKILL.md' if changed else '与 ClawHub 最新 SKILL.md 一致'
    if source_path.is_file():
        return '已同步上游参考文档' if changed else '与上游参考文档一致'
    return '已用上游目录覆盖本地默认包' if changed else '与上游目录一致'


def extract_clawhub_skill_text(payload_path: Path) -> str:
    data = json.loads(payload_path.read_text(encoding='utf-8'))
    for key in ('content', 'skillMd', 'skill_md'):
        value = data.get(key)
        if isinstance(value, str) and value.strip():
            text = value
            break
    else:
        raise ValueError(f'Unsupported ClawHub payload: {payload_path}')
    return text if text.endswith('\n') else text + '\n'


def parse_cli_json(stdout: str) -> dict | None:
    start = stdout.find('{')
    if start < 0:
        return None
    try:
        return json.loads(stdout[start:])
    except json.JSONDecodeError:
        return None


def clone_repo(repo_url: str, target_dir: Path, branch: str | None = None) -> Path | None:
    cmd = ['git', 'clone', '--depth', '1']
    if branch:
        cmd.extend(['--branch', branch])
    cmd.extend([repo_url, str(target_dir)])
    try:
        subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        return None
    return target_dir if target_dir.is_dir() else None


def clawhub_cli_prefix() -> list[str] | None:
    clawhub = shutil.which('clawhub')
    if clawhub:
        return [clawhub]
    npx = shutil.which('npx')
    if npx and ENABLE_NPX_CLAWHUB:
        return [npx, '--yes', 'clawhub@latest']
    return None


def run_clawhub_inspect_json(slug: str, *args: str) -> dict | None:
    prefix = clawhub_cli_prefix()
    if prefix is None:
        return None
    cmd = [*prefix, 'inspect', '--json', slug, *args]
    try:
        result = subprocess.run(
            cmd,
            check=False,
            capture_output=True,
            text=True,
            timeout=60,
        )
    except Exception:
        return None
    if result.returncode != 0:
        return None
    return parse_cli_json(result.stdout)


def fetch_clawhub_latest(slug: str, target_dir: Path) -> Path | None:
    inspect = run_clawhub_inspect_json(slug, '--files')
    if inspect is None:
        return None
    files = inspect.get('version', {}).get('files')
    if not isinstance(files, list) or not files:
        return None

    if target_dir.exists():
        shutil.rmtree(target_dir)
    target_dir.mkdir(parents=True, exist_ok=True)

    wrote_any = False
    for entry in files:
        rel = entry.get('path')
        if not isinstance(rel, str) or not rel.strip():
            return None
        rel_path = Path(rel)
        if rel_path.is_absolute() or '..' in rel_path.parts:
            return None
        file_payload = run_clawhub_inspect_json(slug, '--file', rel)
        content = (file_payload or {}).get('file', {}).get('content')
        if not isinstance(content, str):
            return None
        dst = target_dir / rel_path
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_text(content, encoding='utf-8')
        wrote_any = True

    return target_dir if wrote_any and (target_dir / 'SKILL.md').is_file() else None


def load_doc_source_hints() -> dict[str, str]:
    if not UPSTREAM_DOC.is_file():
        return {}
    hints: dict[str, str] = {}
    in_table = False
    for raw_line in UPSTREAM_DOC.read_text(encoding='utf-8').splitlines():
        line = raw_line.strip()
        if line.startswith('## 2) 默认 Skills 包上游索引'):
            in_table = True
            continue
        if in_table and line.startswith('### '):
            break
        if not in_table or not line.startswith('|'):
            continue
        if line.startswith('| Skill |') or line.startswith('|---|'):
            continue
        cells = [cell.strip() for cell in line.strip('|').split('|')]
        if len(cells) < 3:
            continue
        skill, _, source = cells[:3]
        if skill and source:
            hints[skill] = source.strip('`')
    return hints


def load_clawhub_hint(skill_dir: Path) -> str | None:
    origin = skill_dir / '.clawhub' / 'origin.json'
    if not origin.is_file():
        return None
    try:
        data = json.loads(origin.read_text(encoding='utf-8'))
    except Exception:
        return None
    slug = data.get('slug')
    registry = data.get('registry', 'https://clawhub.ai')
    if not slug:
        return None
    return f'{registry.rstrip("/")}/{slug}'


def normalize_hint_path(hint: str) -> Path | None:
    if hint.startswith('~/'):
        return Path.home() / hint[2:]
    if hint.startswith('/'):
        return Path(hint)
    return None


def is_missing_local_hint(hint: str) -> bool:
    path_hint = normalize_hint_path(hint)
    return path_hint is not None and not path_hint.is_dir()


def local_candidate_names(skill_name: str) -> list[str]:
    names = [skill_name]
    names.extend(LOCAL_NAME_ALIASES.get(skill_name, []))
    # Some installed bundles keep subskills nested under vendor packages.
    if skill_name == 'web-design-guidelines':
        names.append('vercel-agent-skills/skills/web-design-guidelines')
    return names


def find_local_source(skill_name: str) -> tuple[str, Path | None]:
    # Portability guard: local matches are reported as local sources by find_source.
    # return display_path(root), candidate, 'local'
    for root in LOCAL_SOURCE_ROOTS:
        candidate_names = local_candidate_names(skill_name)
        for candidate_name in candidate_names:
            candidate = root / candidate_name
            if candidate.is_dir() and (candidate / 'SKILL.md').is_file():
                return display_path(root), candidate
        for candidate_name in candidate_names:
            try:
                recursive = next(
                    p for p in root.rglob(Path(candidate_name).name)
                    if p.is_dir() and (p / 'SKILL.md').is_file()
                )
            except StopIteration:
                continue
            return display_path(root), recursive
    return '', None


def parse_github_hint(hint: str) -> tuple[str, str | None, str | None] | None:
    if 'github.com/' not in hint:
        return None
    parsed = urlparse(hint)
    parts = [p for p in parsed.path.strip('/').split('/') if p]
    if len(parts) < 2:
        return None
    owner, repo = parts[0], parts[1]
    repo_url = f'https://github.com/{owner}/{repo}.git'
    branch = None
    subpath = None
    if len(parts) >= 5 and parts[2] == 'tree':
        branch = parts[3]
        subpath = '/'.join(parts[4:])
    return repo_url, branch, subpath


def infer_repo_candidate_paths(repo_dir: Path, skill_name: str, subpath: str | None) -> list[Path]:
    candidates: list[Path] = []
    if subpath:
        candidates.append(repo_dir / subpath)
    candidates.extend([
        repo_dir / skill_name,
        repo_dir / 'skills' / skill_name,
        repo_dir / 'tools' / skill_name,
        repo_dir / 'tools' / 'image' / skill_name,
        repo_dir / 'src' / skill_name,
        repo_dir,
    ])
    unique: list[Path] = []
    seen: set[str] = set()
    for candidate in candidates:
        key = str(candidate)
        if key in seen:
            continue
        seen.add(key)
        unique.append(candidate)
    return unique


def find_wrapper_readme_source(skill_dir: Path, repo_dir: Path) -> Path | None:
    target = skill_dir / 'references' / 'upstream-README.md'
    if not target.exists():
        return None
    for name in ('README.md', 'README.MD', 'readme.md'):
        candidate = repo_dir / name
        if candidate.is_file():
            return candidate
    return None


def resolve_hint_source(
    skill_name: str,
    skill_dir: Path,
    source_hint: str,
    tmp_root: Path,
    clone_cache: dict[tuple[str, str | None], Path | None],
) -> tuple[str, Path | None, str]:
    path_hint = normalize_hint_path(source_hint)
    if path_hint is not None:
        return source_hint, (path_hint if path_hint.is_dir() else None), 'local'

    github = parse_github_hint(source_hint)
    if github:
        repo_url, branch, subpath = github
        cache_key = (repo_url, branch)
        if cache_key not in clone_cache:
            repo_name = repo_url.rstrip('.git').split('/')[-1]
            branch_name = branch or 'head'
            cache_suffix = hashlib.sha1(f'{repo_url}@{branch_name}'.encode()).hexdigest()[:10]
            clone_cache[cache_key] = clone_repo(
                repo_url,
                tmp_root / f'{repo_name}-{cache_suffix}',
                branch,
            )
        repo_dir = clone_cache[cache_key]
        if repo_dir:
            for candidate in infer_repo_candidate_paths(repo_dir, skill_name, subpath):
                if (candidate / 'SKILL.md').is_file():
                    return source_hint, candidate, 'github'
            readme_source = find_wrapper_readme_source(skill_dir, repo_dir)
            if readme_source is not None:
                return source_hint, readme_source, 'github-readme'
        return source_hint, None, 'hint-only'

    clawhub_hint = load_clawhub_hint(skill_dir)
    if clawhub_hint and source_hint == clawhub_hint:
        slug = clawhub_hint.rstrip('/').split('/')[-1]
        slug = CLAWHUB_SLUG_ALIASES.get(slug, slug)
        clawhub_payload = fetch_clawhub_latest(slug, tmp_root / f'{skill_name}.clawhub')
        if clawhub_payload is not None:
            return source_hint, clawhub_payload, 'clawhub'
        return source_hint, None, 'hint-only'

    return source_hint, None, 'hint-only'


def find_source(
    skill_name: str,
    skill_dir: Path,
    agentmail_repo: Path | None,
    doc_hints: dict[str, str],
    tmp_root: Path,
    clone_cache: dict[tuple[str, str | None], Path | None],
) -> tuple[str, Path | None, str]:
    if skill_name in AGENTMAIL_SKILLS:
        if agentmail_repo is None:
            return 'skill.sh / GitHub: agentmail-to/agentmail-skills', None, 'hint-only'
        candidate = agentmail_repo / skill_name
        return 'skill.sh / GitHub: agentmail-to/agentmail-skills', (candidate if candidate.is_dir() else None), 'github'

    local_label, local_source = find_local_source(skill_name)
    if local_source is not None:
        return local_label, local_source, 'local'

    source_hint = doc_hints.get(skill_name)
    dead_local_hint = source_hint if source_hint and is_missing_local_hint(source_hint) else None
    if dead_local_hint:
        clawhub_hint = load_clawhub_hint(skill_dir)
        if clawhub_hint:
            source_hint = clawhub_hint
        else:
            return dead_local_hint, None, 'dead-local-hint'
    else:
        source_hint = source_hint or load_clawhub_hint(skill_dir)
    if source_hint:
        return resolve_hint_source(skill_name, skill_dir, source_hint, tmp_root, clone_cache)

    return '未找到可用上游源', None, 'missing'


def row_for_missing(skill: str, source_label: str, source_kind: str) -> dict[str, str]:
    if source_kind == 'hint-only' and source_label.startswith('https://clawhub.ai/'):
        if clawhub_cli_prefix() is None:
            detail = '已识别 ClawHub 来源提示，但当前未安装 clawhub CLI（npx 回退默认关闭），保留仓库现有版本'
        else:
            detail = '已识别 ClawHub 来源提示，但该 slug 当前无法通过官方 CLI 解析，保留仓库现有版本'
    elif source_kind == 'hint-only':
        detail = '已识别上游提示，但当前无法自动拉取目录，保留仓库现有版本'
    elif source_kind == 'dead-local-hint':
        detail = '已声明本机来源提示，但该本机 skill 当前不存在，保留仓库现有版本'
    elif source_kind == 'missing':
        detail = '仓库自维护技能，当前未声明外部上游，保留仓库现有版本'
    else:
        detail = '未找到自动同步源，保留仓库现有版本'
    return {
        'skill': skill,
        'status': '保留现状',
        'source': source_label,
        'detail': detail,
    }


def main() -> int:
    if not SKILLS_DIR.is_dir():
        print(f'Missing skills dir: {SKILLS_DIR}', file=sys.stderr)
        return 1

    doc_hints = load_doc_source_hints()
    report_rows: list[dict[str, str]] = []
    with tempfile.TemporaryDirectory(prefix='openclaw-skill-refresh-') as tmp:
        tmp_root = Path(tmp)
        clone_cache: dict[tuple[str, str | None], Path | None] = {}
        agentmail_repo = clone_repo(AGENTMAIL_REPO, tmp_root / 'agentmail-skills')

        for skill_dir in sorted(p for p in SKILLS_DIR.iterdir() if p.is_dir()):
            skill = skill_dir.name
            source_label, source_dir, source_kind = find_source(
                skill,
                skill_dir,
                agentmail_repo,
                doc_hints,
                tmp_root,
                clone_cache,
            )

            if source_dir is None:
                report_rows.append(row_for_missing(skill, source_label, source_kind))
                continue

            target_path = resolve_sync_target(skill_dir, source_dir)
            before_hash = hash_path(target_path)
            source_hash = hash_path(source_dir)
            if before_hash == source_hash:
                report_rows.append({
                    'skill': skill,
                    'status': '已最新',
                    'source': source_label,
                    'detail': sync_detail(source_dir, source_kind, changed=False),
                })
                continue

            copy_source(source_dir, skill_dir)
            report_rows.append({
                'skill': skill,
                'status': '已更新',
                'source': source_label,
                'detail': sync_detail(source_dir, source_kind, changed=True),
            })

    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        '# Skills 更新结果',
        '',
        f'- 生成时间: {dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")}',
        f'- 扫描目录: `{display_path(SKILLS_DIR)}`',
        '- 同步优先级: `~/.openclaw/skills` -> `~/.codex/skills` -> `~/.agents/skills` -> `agentmail-to/agentmail-skills` -> `docs/upstream-sources.md`',
        '',
        '| Skill | 结果 | 来源 | 说明 |',
        '|---|---|---|---|',
    ]
    for row in report_rows:
        lines.append(f"| {row['skill']} | {row['status']} | {row['source']} | {row['detail']} |")
    REPORT_PATH.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(f'Wrote {REPORT_PATH}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
