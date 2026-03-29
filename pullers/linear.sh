#!/usr/bin/env bash
###############################################################################
#  TaskLot Puller: Linear
#  Fetches tasks from a Linear team/project via Claude Code MCP
#
#  Required config fields:
#    task_source.config.team_key       — Linear team key (e.g. "ENG")
#    task_source.config.project_name   — Optional: filter by project name
#    task_source.config.status_filter  — Optional: statuses to include (default: backlog, todo, in_progress)
###############################################################################

PULLER_NAME="linear"
PULLER_VERSION="1.0.0"

check_puller() {
  if ! command -v claude &>/dev/null; then
    echo "Error: Claude Code CLI required for Linear MCP. Install: npm i -g @anthropic-ai/claude-code"
    exit 1
  fi
}

pull_tasks() {
  local config_file="$1"
  local output_file="$2"

  check_puller

  local team_key
  team_key=$(jq -r '.task_source.config.team_key // empty' "$config_file")

  if [[ -z "$team_key" ]]; then
    echo "Error: task_source.config.team_key not set in config"
    return 1
  fi

  local project_name
  project_name=$(jq -r '.task_source.config.project_name // empty' "$config_file")

  local status_filter
  status_filter=$(jq -r '.task_source.config.status_filter // "backlog,todo,in_progress"' "$config_file")

  local project_clause=""
  if [[ -n "$project_name" ]]; then
    project_clause="Filter by project name: ${project_name}"
  fi

  local pull_prompt="You have access to Linear via MCP. Query Linear with the following:

Team: ${team_key}
${project_clause}
Include statuses: ${status_filter}

Fetch ALL matching issues. For each issue, extract:
- id: use the Linear issue identifier (e.g. ENG-123)
- title: the issue title
- description: the full issue description/body (this includes the agent reference like 'read backend-developer.agent.md')
- status: map to 'pending' if status is 'Backlog', 'Todo', 'In Progress', or 'Unstarted'. Map to 'done' if 'Done' or 'Completed'. Map to 'failed' if 'Cancelled'.
- priority: map Linear priority to high/medium/low (Urgent/High → high, Medium → medium, Low/No priority → low)
- source_id: the Linear issue ID (UUID, for posting comments back later)

Output ONLY valid JSON in this exact format, no markdown fences, no explanation:

{
  \"pulled_at\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",
  \"source\": \"linear\",
  \"source_config\": {
    \"team_key\": \"${team_key}\"$(if [[ -n "$project_name" ]]; then echo ", \"project_name\": \"${project_name}\""; fi)
  },
  \"tasks\": [
    {
      \"id\": \"ENG-001\",
      \"title\": \"Task title here\",
      \"description\": \"Full description including agent reference...\",
      \"status\": \"pending\",
      \"priority\": \"medium\",
      \"source_id\": \"linear-issue-uuid-here\",
      \"completed_at\": null,
      \"failure_reason\": null
    }
  ]
}"

  echo "$pull_prompt" | claude -p --output-format text 2>&1
}
