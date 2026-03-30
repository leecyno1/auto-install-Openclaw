#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UI_PROJECT_DIR="$ROOT_DIR/subprojects/lobster-sanctum-ui"
SESSION_NAME="${1:-lobster_ui_studio}"

if [[ ! -d "$UI_PROJECT_DIR" ]]; then
  echo "[ERROR] UI subproject not found: $UI_PROJECT_DIR"
  exit 1
fi

if ! command -v tmux >/dev/null 2>&1; then
  echo "[INFO] tmux not found. Run these commands manually:"
  echo "  cd '$UI_PROJECT_DIR'"
  echo "  bash '$ROOT_DIR/scripts/config-ui.sh' start"
  echo "  # Open a new Codex session with cwd: $UI_PROJECT_DIR"
  exit 0
fi

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  echo "[OK] Attach existing session: $SESSION_NAME"
  exec tmux attach -t "$SESSION_NAME"
fi

tmux new-session -d -s "$SESSION_NAME" -c "$UI_PROJECT_DIR"
tmux rename-window -t "$SESSION_NAME:1" "ui-studio"
tmux send-keys -t "$SESSION_NAME:1" "bash '$ROOT_DIR/scripts/config-ui.sh' start" C-m
tmux split-window -h -t "$SESSION_NAME:1" -c "$UI_PROJECT_DIR"
tmux send-keys -t "$SESSION_NAME:1.2" "echo 'Lobster Sanctum Studio session ready.'" C-m
tmux send-keys -t "$SESSION_NAME:1.2" "echo 'UI URL: http://127.0.0.1:${STAR_BACKEND_PORT:-19000}'" C-m
tmux send-keys -t "$SESSION_NAME:1.2" "echo 'Focus: UI design, art polish, interaction.'" C-m
tmux select-pane -t "$SESSION_NAME:1.1"

exec tmux attach -t "$SESSION_NAME"
