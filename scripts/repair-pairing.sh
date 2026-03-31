#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_MENU="$ROOT_DIR/config-menu.sh"

if [[ ! -f "$CONFIG_MENU" ]]; then
  echo "[ERROR] 未找到 config-menu.sh: $CONFIG_MENU" >&2
  exit 1
fi

if [[ ! -x "$CONFIG_MENU" ]]; then
  chmod +x "$CONFIG_MENU" || true
fi

echo "[INFO] 执行 Dashboard 配对/登录修复..."
bash "$CONFIG_MENU" --repair-pairing

echo "[OK] 配对修复流程完成。"
