#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_help() {
  cat <<'EOF'
OpenClaw 独立安装入口

用法:
  ./install-openclaw.sh [install.sh 兼容参数]
  curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/release/hermes-website-minimax-hardening-20260503/install-openclaw.sh | bash

说明:
  - 当前最新分支: release/hermes-website-minimax-hardening-20260503
  - 此入口固定安装 OpenClaw
  - 如需安装 Hermes，请使用 install-hermes.sh
  - 如需双引擎，请使用 install.sh --engine both

常用示例:
  ./install-openclaw.sh --auto-confirm-all
  ./install-openclaw.sh --install-method git --rule-profile medium
  ./install-openclaw.sh --extra-model "id=gpt-5-5,name=GPT-5.5,base_url=https://example.com/v1,api_key=$GPT55_API_KEY,model=gpt-5.5,api_type=openai-completions,image_tool=responses-image-generation"
  openclaw-setup install openclaw
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
      echo "[ERROR] install-openclaw.sh 已固定为 OpenClaw 入口，请不要再传 --engine" >&2
      exit 2
      ;;
    --engine=*)
      echo "[ERROR] install-openclaw.sh 已固定为 OpenClaw 入口，请不要再传 ${arg}" >&2
      exit 2
      ;;
  esac
done

exec bash "$script_dir/install.sh" --engine openclaw "$@"
