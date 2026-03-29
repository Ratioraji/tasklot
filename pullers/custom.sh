#!/usr/bin/env bash
###############################################################################
#  TaskLot Puller: Custom
#  Template for creating your own task puller
#
#  To create a custom puller:
#  1. Copy this file: cp custom.sh my-tool.sh
#  2. Implement pull_tasks()
#  3. Set "task_source.type": "my-tool" in config.json
#
#  Your puller must output valid JSON to stdout in the TaskLot task format.
###############################################################################

PULLER_NAME="custom"
PULLER_VERSION="1.0.0"

check_puller() {
  # Add your tool availability check here
  # Example:
  # if ! command -v my-tool &>/dev/null; then
  #   echo "Error: my-tool not found"
  #   exit 1
  # fi
  echo "Custom puller — implement check_puller()"
}

pull_tasks() {
  local config_file="$1"
  local output_file="$2"

  check_puller

  # Read your custom config values:
  # local my_value
  # my_value=$(jq -r '.task_source.config.my_field // empty' "$config_file")

  # Your puller must output valid JSON to stdout in this format:
  cat <<'EOF'
{
  "pulled_at": "2026-01-01T00:00:00Z",
  "source": "custom",
  "source_config": {},
  "tasks": [
    {
      "id": "TASK-001",
      "title": "Example task",
      "description": "read your-agent.agent.md\n\nTask description here...",
      "status": "pending",
      "priority": "medium",
      "source_id": "custom-id-here",
      "completed_at": null,
      "failure_reason": null
    }
  ]
}
EOF
}
