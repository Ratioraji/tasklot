#!/usr/bin/env bash
###############################################################################
#  TaskLot Engine: OpenAI Codex CLI
#  Uses Codex CLI to execute tasks
###############################################################################

ENGINE_NAME="codex"
ENGINE_VERSION="1.0.0"

check_engine() {
  if ! command -v codex &>/dev/null; then
    echo "Error: Codex CLI not found. Install it with: npm install -g @openai/codex"
    exit 1
  fi
}

execute_task() {
  local prompt="$1"
  local work_dir="$2"

  check_engine

  cd "$work_dir"

  codex --approval-mode full-auto "$prompt" 2>&1
}
