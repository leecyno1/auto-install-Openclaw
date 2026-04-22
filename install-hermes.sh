#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_help() {
  cat <<'EOF'
Hermes 独立安装入口

用法:
  ./install-hermes.sh [install.sh 兼容参数]
  curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/main/install-hermes.sh | bash

说明:
  - 此入口固定安装 Hermes
  - 如需安装 OpenClaw，请使用 install-openclaw.sh
  - 如需双引擎，请使用 install.sh --engine both

常用示例:
  ./install-hermes.sh --auto-confirm-all
  ./install-hermes.sh --install-method git
  lobster-setup install hermes
EOF
}

case "${1:-}" in
  --help|-h|help)
    print_help
    exit 0
    ;;
esac

for arg in "$@"; do
  case "$arg" in
    --engine)
      echo "[ERROR] install-hermes.sh 已固定为 Hermes 入口，请不要再传 --engine" >&2
      exit 2
      ;;
    --engine=*)
      echo "[ERROR] install-hermes.sh 已固定为 Hermes 入口，请不要再传 ${arg}" >&2
      exit 2
      ;;
  esac
done

exec bash "$script_dir/install.sh" --engine hermes "$@"
