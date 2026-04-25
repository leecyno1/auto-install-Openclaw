#!/usr/bin/env python3
"""
API Replacer - 扫描并替换 Skills 中硬编码的第三方服务地址

支持的服务：nanobanana, gemini, openai, minimax, replicate
支持的文件类型：.py, .js, .sh
"""

import argparse
import json
import os
import re
import shutil
from datetime import datetime
from pathlib import Path

# 默认的服务 URL 模式
DEFAULT_SERVICE_PATTERNS = {
    "nanobanana": [
        r"https?://api\.nanobanana\.com",
        r"https?://nanobanana",
    ],
    "gemini": [
        r"https?://generativelanguage\.googleapis\.com",
        r"https?://gemini\.google\.com",
    ],
    "openai": [
        r"https?://api\.openai\.com",
        r"https?://openai\.com",
    ],
    "minimax": [
        r"https?://api\.minimax\.io",
        r"https?://minimax\.io",
    ],
    "replicate": [
        r"https?://api\.replicate\.com",
        r"https?://replicate\.com",
    ],
}


def load_overrides(overrides_file: str) -> dict:
    """加载 API 地址映射配置"""
    if not os.path.exists(overrides_file):
        return {}

    with open(overrides_file, "r", encoding="utf-8") as f:
        return json.load(f)


def save_overrides(overrides_file: str, overrides: dict):
    """保存 API 地址映射配置"""
    os.makedirs(os.path.dirname(overrides_file), exist_ok=True)
    with open(overrides_file, "w", encoding="utf-8") as f:
        json.dump(overrides, f, indent=2, ensure_ascii=False)


def get_backup_dir() -> str:
    """获取备份目录"""
    backup_dir = os.path.expanduser("~/.openclaw/backups/api-replacer")
    os.makedirs(backup_dir, exist_ok=True)
    return backup_dir


def backup_file(filepath: str) -> str:
    """备份文件到备份目录"""
    backup_dir = get_backup_dir()
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = os.path.basename(filepath)
    backup_path = os.path.join(backup_dir, f"{filename}.{timestamp}.bak")

    shutil.copy2(filepath, backup_path)
    return backup_path


def replace_in_file(filepath: str, overrides: dict, dry_run: bool = False) -> list:
    """
    在单个文件中替换 URL
    返回：被修改的服务列表
    """
    # 只处理代码文件
    if not filepath.endswith((".py", ".js", ".sh", ".ts", ".tsx", ".jsx")):
        return []

    if not os.path.isfile(filepath):
        return []

    # 跳过 node_modules 等目录
    if "node_modules" in filepath or ".venv" in filepath or "__pycache__" in filepath:
        return []

    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    original_content = content
    modified_services = []

    for service, config in overrides.items():
        if "replacement" not in config:
            continue

        replacement = config["replacement"]

        # 获取该服务的 URL 模式
        patterns = DEFAULT_SERVICE_PATTERNS.get(service, [])

        # 如果配置中有自定义的 original URL，也加入匹配
        if "original" in config:
            patterns.append(re.escape(config["original"]))

        for pattern_str in patterns:
            # 构建匹配模式
            # 1. 匹配带引号的 URL: "https://..." 或 'https://...'
            pattern1 = rf'(["\'])({pattern_str}[^"\']*)\1'
            # 2. 匹配 url= 形式的 URL: url="https://..."
            pattern2 = rf'(url\s*[=:]\s*)(["\']?)({pattern_str}[^\s,)\'"&]*)\2'
            # 3. 匹配 BASE_URL 形式的: https://...
            pattern3 = rf'(=\s*["\']?)({pattern_str}[^\s,)\'"]+)(["\']?)\s*([,)])'

            for pattern in [pattern1, pattern2, pattern3]:
                if re.search(pattern, content):
                    # 安全替换 - 确保不替换注释中的 URL
                    new_content = re.sub(pattern, lambda m: safe_replace(m, replacement), content)
                    if new_content != content:
                        content = new_content
                        if service not in modified_services:
                            modified_services.append(service)

    if content != original_content and not dry_run:
        # 备份原文件
        backup_path = backup_file(filepath)
        print(f"  Backup: {backup_path}")

        with open(filepath, "w", encoding="utf-8") as f:
            f.write(content)

        print(f"  Updated: {filepath}")

    return modified_services


def safe_replace(match, replacement: str) -> str:
    """
    安全替换 - 确保不破坏代码语法
    """
    full_match = match.group(0)

    # 如果 replacement 已经是完整的 URL，直接使用
    if replacement.startswith("http"):
        return full_match

    # 否则保持原有结构，只替换 URL 部分
    return full_match


def scan_and_replace(skills_dir: str, overrides_file: str, dry_run: bool = False) -> dict:
    """
    扫描 skills 目录并替换 URL
    返回：{filepath: [modified_services]}
    """
    overrides = load_overrides(overrides_file)
    if not overrides:
        print(f"No overrides configured in {overrides_file}")
        return {}

    results = {}
    skills_path = Path(skills_dir)

    print(f"Scanning: {skills_dir}")
    print(f"Overrides: {list(overrides.keys())}")
    print()

    for filepath in skills_path.rglob("*"):
        if filepath.is_file():
            modified = replace_in_file(str(filepath), overrides, dry_run)
            if modified:
                results[str(filepath)] = modified

    return results


def add_override(overrides_file: str, service: str, original: str, replacement: str):
    """添加新的覆盖配置"""
    overrides = load_overrides(overrides_file)

    overrides[service] = {
        "original": original,
        "replacement": replacement,
    }

    save_overrides(overrides_file, overrides)
    print(f"Added override: {service}")
    print(f"  Original: {original}")
    print(f"  Replacement: {replacement}")


def remove_override(overrides_file: str, service: str):
    """移除覆盖配置"""
    overrides = load_overrides(overrides_file)

    if service in overrides:
        del overrides[service]
        save_overrides(overrides_file, overrides)
        print(f"Removed override: {service}")
    else:
        print(f"No override found for: {service}")


def show_overrides(overrides_file: str):
    """显示当前覆盖配置"""
    overrides = load_overrides(overrides_file)

    if not overrides:
        print("No overrides configured.")
        return

    print("Current API Overrides:")
    print("-" * 60)
    for service, config in overrides.items():
        print(f"\n{service}:")
        if "original" in config:
            print(f"  Original: {config['original']}")
        print(f"  Replacement: {config['replacement']}")


def rollback(backup_name: str = None):
    """从备份恢复"""
    backup_dir = get_backup_dir()

    if backup_name:
        backup_path = os.path.join(backup_dir, backup_name)
        if os.path.exists(backup_path):
            # 从备份文件名提取原文件路径
            original_name = backup_name.rsplit(".", 2)[0]
            # 尝试在 skills 目录恢复
            skills_dir = os.path.expanduser("~/.openclaw/skills")
            for root, dirs, files in os.walk(skills_dir):
                if original_name in files:
                    original_path = os.path.join(root, original_name)
                    shutil.copy2(backup_path, original_path)
                    print(f"Restored: {original_path}")
                    return
            print(f"Backup file not found in skills directory: {backup_path}")
        else:
            print(f"Backup not found: {backup_path}")
    else:
        # 列出所有备份
        backups = sorted(Path(backup_dir).glob("*"))
        if backups:
            print("Available backups:")
            for backup in backups:
                print(f"  {backup.name}")
        else:
            print("No backups found.")


def main():
    parser = argparse.ArgumentParser(
        description="API Replacer - 替换 Skills 中硬编码的第三方服务地址"
    )

    subparsers = parser.add_subparsers(dest="command", help="子命令")

    # replace 子命令
    replace_parser = subparsers.add_parser("replace", help="扫描并替换 URL")
    replace_parser.add_argument("--skills-dir", default="~/.openclaw/skills", help="Skills 目录")
    replace_parser.add_argument("--overrides", default="~/.openclaw/api-overrides.json", help="覆盖配置")
    replace_parser.add_argument("--dry-run", action="store_true", help="只显示将要修改的内容")

    # add 子命令
    add_parser = subparsers.add_parser("add", help="添加新的覆盖配置")
    add_parser.add_argument("--service", required=True, help="服务名称 (nanobanana/gemini/openai/...)")
    add_parser.add_argument("--original", required=True, help="原始 URL")
    add_parser.add_argument("--replacement", required=True, help="替换后的 URL")
    add_parser.add_argument("--overrides", default="~/.openclaw/api-overrides.json", help="覆盖配置")

    # remove 子命令
    remove_parser = subparsers.add_parser("remove", help="移除覆盖配置")
    remove_parser.add_argument("--service", required=True, help="服务名称")
    remove_parser.add_argument("--overrides", default="~/.openclaw/api-overrides.json", help="覆盖配置")

    # list 子命令
    list_parser = subparsers.add_parser("list", help="显示当前覆盖配置")
    list_parser.add_argument("--overrides", default="~/.openclaw/api-overrides.json", help="覆盖配置")

    # rollback 子命令
    rollback_parser = subparsers.add_parser("rollback", help="从备份恢复")
    rollback_parser.add_argument("--name", help="备份文件名")

    args = parser.parse_args()

    if args.command == "replace":
        skills_dir = os.path.expanduser(args.skills_dir)
        overrides = os.path.expanduser(args.overrides)

        if not os.path.exists(skills_dir):
            print(f"Skills directory not found: {skills_dir}")
            return 1

        if not os.path.exists(overrides):
            print(f"Overrides file not found: {overrides}")
            return 1

        results = scan_and_replace(skills_dir, overrides, args.dry_run)

        if not results:
            print("\nNo files modified.")
        else:
            print(f"\nModified {len(results)} files:")
            for filepath, services in results.items():
                print(f"  {filepath}: {', '.join(services)}")

    elif args.command == "add":
        overrides = os.path.expanduser(args.overrides)
        add_override(overrides, args.service, args.original, args.replacement)

    elif args.command == "remove":
        overrides = os.path.expanduser(args.overrides)
        remove_override(overrides, args.service)

    elif args.command == "list":
        overrides = os.path.expanduser(args.overrides)
        show_overrides(overrides)

    elif args.command == "rollback":
        rollback(args.name)

    else:
        parser.print_help()

    return 0


if __name__ == "__main__":
    exit(main())
