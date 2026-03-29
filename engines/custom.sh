#!/usr/bin/env bash
###############################################################################
#  TaskLot Engine: Custom
#  Template for creating your own engine
#
#  To create a custom engine:
#  1. Copy this file: cp custom.sh my-engine.sh
#  2. Implement execute_task()
#  3. Set "engine": "my-engine" in config.json
###############################################################################

ENGINE_NAME="custom"
ENGINE_VERSION="1.0.0"

check_engine() {
  # Add your tool availability check here
  # Example:
  # if ! command -v my-tool &>/dev/null; then
  #   echo "Error: my-tool not found"
  #   exit 1
  # fi
  echo "Custom engine — implement check_engine()"
}

execute_task() {
  local prompt="$1"
  local work_dir="$2"

  check_engine

  cd "$work_dir"

  # Replace this with your AI tool's CLI command
  # The function should:
  #   - Accept a prompt string
  #   - Execute it in the given working directory
  #   - Output the result to stdout
  echo "Custom engine — implement execute_task()"
  echo "Prompt: ${prompt:0:100}..."
}
