#!/usr/bin/env bash
###############################################################################
#  TaskLot Engine: Claude Code
#  Uses Claude Code CLI to execute tasks
###############################################################################

ENGINE_NAME="claude-code"
ENGINE_VERSION="1.0.0"

# Check if claude is available
check_engine() {
  if ! command -v claude &>/dev/null; then
    echo "Error: Claude Code CLI not found. Install it with: npm install -g @anthropic-ai/claude-code"
    exit 1
  fi
}

# Execute a task using Claude Code
# Args: $1 = prompt, $2 = working directory
execute_task() {
  local prompt="$1"
  local work_dir="$2"

  check_engine

  cd "$work_dir"

  # Use claude with --print for non-interactive execution.
  # --dangerously-skip-permissions is required: tasklot runs claude headlessly
  # so there is no human to approve write/bash/edit prompts. Without it,
  # every file-writing or shell tool call is silently denied and the QA gate
  # fails because nothing was produced.
  # The prompt is passed via stdin to handle large prompts safely.
  echo "$prompt" | claude -p --dangerously-skip-permissions --output-format text 2>&1
}
