#!/usr/bin/env bash
###############################################################################
#  TaskLot Puller: Notion
#  Fetches tasks from a Notion database via Claude Code MCP
#
#  Required config fields:
#    task_source.config.database_id    — Notion database ID
#    task_source.config.status_field   — Name of status property (default: "Status")
###############################################################################

PULLER_NAME="notion"
PULLER_VERSION="1.0.0"

check_puller() {
  if ! command -v claude &>/dev/null; then
    echo "Error: Claude Code CLI required for Notion MCP. Install: npm i -g @anthropic-ai/claude-code"
    exit 1
  fi
}

pull_tasks() {
  local config_file="$1"
  local output_file="$2"

  check_puller

  local database_id
  database_id=$(jq -r '.task_source.config.database_id // empty' "$config_file")

  if [[ -z "$database_id" ]]; then
    echo "Error: task_source.config.database_id not set in config"
    return 1
  fi

  local status_field
  status_field=$(jq -r '.task_source.config.status_field // "Status"' "$config_file")

  local pull_prompt="You have access to Notion via MCP. Query the Notion database with ID: ${database_id}

Fetch ALL pages/tickets from this database. For each ticket, extract:
- id: a short identifier (use a sequential number like TASK-001, TASK-002, etc.)
- title: the page title
- description: the full page content/body (this includes the agent reference like 'read backend-developer.agent.md')
- status: the '${status_field}' property (map to 'pending' if it's 'To Do' or 'Not Started', 'done' if 'Done' or 'Complete')
- priority: priority if available (high, medium, low), default to 'medium'
- source_id: the Notion page ID (for posting comments back later)

Output ONLY valid JSON in this exact format, no markdown fences, no explanation:

{
  \"pulled_at\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",
  \"source\": \"notion\",
  \"source_config\": {
    \"database_id\": \"${database_id}\"
  },
  \"tasks\": [
    {
      \"id\": \"TASK-001\",
      \"title\": \"Task title here\",
      \"description\": \"Full description including agent reference...\",
      \"status\": \"pending\",
      \"priority\": \"medium\",
      \"source_id\": \"notion-page-id-here\",
      \"completed_at\": null,
      \"failure_reason\": null
    }
  ]
}"

  echo "$pull_prompt" | claude -p --output-format text 2>&1
}
