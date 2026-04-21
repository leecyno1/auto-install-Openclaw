#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

pass() { echo "[PASS] $1"; }
warn() { echo "[WARN] $1"; }
fail() { echo "[FAIL] $1"; exit 1; }
strict_shell_tools="${OPENCLAW_STRICT_SHELL_TOOLS:-${CI:-0}}"

is_truthy() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

require_tool_or_warn() {
  local tool="$1"
  local install_hint="$2"
  if command -v "$tool" >/dev/null 2>&1; then
    return 0
  fi
  if is_truthy "$strict_shell_tools"; then
    fail "$tool not installed (strict mode). $install_hint"
  fi
  warn "$tool not installed, skipped"
  return 1
}

TARGETS=(
  "install.sh"
  "config-menu.sh"
  "docker-entrypoint.sh"
  "scripts/*.sh"
  "scripts/lib/*.sh"
)

FILES=()
for pattern in "${TARGETS[@]}"; do
  for file in $pattern; do
    [[ -f "$file" ]] || continue
    FILES+=("$file")
  done
done

[[ "${#FILES[@]}" -gt 0 ]] || fail "no shell files found"

for file in "${FILES[@]}"; do
  bash -n "$file" || fail "bash syntax: $file"
done
pass "bash -n"

if require_tool_or_warn shellcheck "Install shellcheck or unset OPENCLAW_STRICT_SHELL_TOOLS for local-only runs."; then
  shellcheck -S error "${FILES[@]}" || fail "shellcheck"
  pass "shellcheck"
fi

if require_tool_or_warn shfmt "Install shfmt or unset OPENCLAW_STRICT_SHELL_TOOLS for local-only runs."; then
  shfmt -d -i 4 -ci "${FILES[@]}" || fail "shfmt"
  pass "shfmt"
fi

echo "shell lint done"
