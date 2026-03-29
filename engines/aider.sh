#!/usr/bin/env bash
###############################################################################
#  TaskLot Engine: Aider
#  Uses Aider CLI to execute tasks
###############################################################################

ENGINE_NAME="aider"
ENGINE_VERSION="1.0.0"

check_engine() {
  if ! command -v aider &>/dev/null; then
    echo "Error: Aider not found. Install it with: pip install aider-chat"
    exit 1
  fi
}

execute_task() {
  local prompt="$1"
  local work_dir="$2"

  check_engine

  cd "$work_dir"

  # Aider in message mode for non-interactive execution
  aider --message "$prompt" --yes-always --no-auto-commits 2>&1
}
