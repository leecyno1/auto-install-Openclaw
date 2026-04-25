#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_MENU_LOCAL="$SCRIPT_DIR/config-menu.sh"
INSTALL_SCRIPT="$SCRIPT_DIR/install.sh"
CONFIG_MENU_INSTALLED="$HOME/.openclaw/config-menu.sh"
WORKBENCH="$HOME/.openclaw/lobster-world.sh"

print_help() {
  cat <<'EOH'
🔥 大圣之怒统一入口

用法: openclaw-setup {install|config|repair|workbench|status|doctor|engine|migrate|backup|help}

命令:
  install      安装引擎: openclaw | hermes | both
  config       配置中心，可带子命令: model|image|skills|rules|routing|pixel-house|website|hermes
  repair       修复历史错误配置，或 repair minimax
  workbench    启动/停止/查看像素小屋
  status       查看 OpenClaw / Hermes 状态
  doctor       执行 OpenClaw / Hermes 健康检查
  engine       打开引擎管理
  migrate      OpenClaw -> Hermes 迁移
  backup       调用备份脚本

示例:
  openclaw-setup install openclaw --auto-confirm-all
  openclaw-setup install hermes --auto-confirm-all
  openclaw-setup install both --provider minimax --model MiniMax-M2.7-highspeed --api-key sk-xxx
  openclaw-setup config model
  openclaw-setup config image
  openclaw-setup config website --sync
  openclaw-setup repair minimax

兼容: lobster-setup 会转发到 openclaw-setup。
EOH
}

run_config_menu() {
  local menu="$CONFIG_MENU_LOCAL"
  [ -f "$CONFIG_MENU_INSTALLED" ] && menu="$CONFIG_MENU_INSTALLED"
  if [ ! -f "$menu" ]; then
    echo "[ERROR] 未找到配置菜单脚本: $menu" >&2
    exit 1
  fi
  bash "$menu" "$@"
}

cmd="${1:-help}"
shift || true

case "$cmd" in
  help|-h|--help)
    print_help
    ;;
  install)
    sub="${1:-openclaw}"
    case "$sub" in
      openclaw|hermes|both)
        shift || true
        bash "$INSTALL_SCRIPT" --engine "$sub" "$@"
        ;;
      *)
        bash "$INSTALL_SCRIPT" "$sub" "$@"
        ;;
    esac
    ;;
  config|c)
    run_config_menu "$@"
    ;;
  repair|fix|r)
    sub="${1:-}"
    case "$sub" in
      minimax) shift || true; run_config_menu --repair-minimax "$@" ;;
      ""|all|full) [ -n "$sub" ] && shift || true; run_config_menu --repair-config "$@" ;;
      *) run_config_menu --repair-config "$sub" "$@" ;;
    esac
    ;;
  workbench|wb|w)
    if [ -f "$WORKBENCH" ]; then
      bash "$WORKBENCH" "${1:-status}"
    else
      run_config_menu --install-pixel-house
    fi
    ;;
  status|s)
    command -v openclaw >/dev/null 2>&1 && openclaw gateway status || true
    command -v hermes >/dev/null 2>&1 && hermes status || true
    ;;
  doctor|d)
    command -v openclaw >/dev/null 2>&1 && openclaw doctor || true
    command -v hermes >/dev/null 2>&1 && hermes doctor || true
    ;;
  engine)
    run_config_menu --engine-menu "$@"
    ;;
  migrate)
    sub="${1:-}"
    if [ "$sub" = "openclaw-to-hermes" ]; then
      shift || true
      hermes claw migrate "$@"
    else
      echo "用法: openclaw-setup migrate openclaw-to-hermes [--dry-run]" >&2
      exit 1
    fi
    ;;
  backup)
    if [ -f "$HOME/.openclaw/backup-manager.sh" ]; then
      bash "$HOME/.openclaw/backup-manager.sh" "$@"
    else
      echo "[WARN] 备份脚本未安装" >&2
      exit 1
    fi
    ;;
  *)
    echo "[ERROR] 未知命令: $cmd" >&2
    print_help
    exit 1
    ;;
esac
