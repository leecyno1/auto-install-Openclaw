#!/usr/bin/env bash
set -euo pipefail

INSTALLER_BRANCH="${OPENCLAW_INSTALLER_BRANCH:-main}"
INSTALLER_GITEE_URL="${OPENCLAW_INSTALLER_GITEE_URL:-https://gitee.com/leecyno1/auto-install-openclaw/raw/${INSTALLER_BRANCH}/install.sh}"
INSTALLER_GITHUB_URL="${OPENCLAW_INSTALLER_GITHUB_URL:-https://raw.githubusercontent.com/leecyno1/auto-install-Openclaw/${INSTALLER_BRANCH}/install.sh}"

print_help() {
  cat <<'EOF'
Hermes 独立安装入口

用法:
  ./install-hermes.sh [install.sh 兼容参数]
  curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/main/install-hermes.sh | bash

说明:
  - 当前最新分支: main
  - 此入口固定安装 Hermes
  - 如需安装 OpenClaw，请使用 install-openclaw.sh
  - 如需双引擎，请使用 install.sh --engine both

常用示例:
  ./install-hermes.sh --auto-confirm-all
  ./install-hermes.sh --install-method git
  openclaw-setup install hermes
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

if [ "${BASH_SOURCE[0]:-}" != "" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [ -f "$script_dir/install.sh" ]; then
    exec bash "$script_dir/install.sh" --engine hermes "$@"
  fi
fi

tmp_root="${TMPDIR:-/tmp}"
tmp_installer="$(mktemp "${tmp_root%/}/openclaw-install.XXXXXX")"
cleanup() {
  rm -f "$tmp_installer" 2>/dev/null || true
}
trap cleanup EXIT

if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$INSTALLER_GITEE_URL" -o "$tmp_installer" \
    || curl -fsSL "$INSTALLER_GITHUB_URL" -o "$tmp_installer"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "$tmp_installer" "$INSTALLER_GITEE_URL" \
    || wget -qO "$tmp_installer" "$INSTALLER_GITHUB_URL"
else
  echo "[ERROR] 需要 curl 或 wget 下载 install.sh" >&2
  exit 1
fi

exec bash "$tmp_installer" --engine hermes "$@"
