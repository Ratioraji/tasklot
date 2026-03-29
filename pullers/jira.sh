#!/usr/bin/env bash
###############################################################################
#  TaskLot Puller: Jira
#  Fetches tasks from a Jira project via Claude Code MCP (Atlassian)
#
#  Required config fields:
#    task_source.config.project_key    — Jira project key (e.g. "PROJ")
#    task_source.config.jql            — Optional JQL filter (default: open issues)
#    task_source.config.base_url       — Jira instance URL
###############################################################################

PULLER_NAME="jira"
PULLER_VERSION="1.0.0"

check_puller() {
  if ! command -v claude &>/dev/null; then
    echo "Error: Claude Code CLI required for Jira MCP. Install: npm i -g @anthropic-ai/claude-code"
    exit 1
  fi
}

pull_tasks() {
  local config_file="$1"
  local output_file="$2"

  check_puller

  local project_key
  project_key=$(jq -r '.task_source.config.project_key // empty' "$config_file")

  if [[ -z "$project_key" ]]; then
    echo "Error: task_source.config.project_key not set in config"
    return 1
  fi

  local base_url
  base_url=$(jq -r '.task_source.config.base_url // empty' "$config_file")

  local jql
  jql=$(jq -r '.task_source.config.jql // "project = '"${project_key}"' AND status != Done ORDER BY priority DESC, created ASC"' "$config_file")

  local pull_prompt="You have access to Jira via the Atlassian MCP. Query Jira with the following:

Project Key: ${project_key}
$(if [[ -n "$base_url" ]]; then echo "Jira URL: ${base_url}"; fi)
JQL Filter: ${jql}

Fetch ALL matching issues. For each issue, extract:
- id: use the Jira issue key (e.g. PROJ-123)
- title: the issue summary
- description: the full issue description body (this includes the agent reference like 'read backend-developer.agent.md')
- status: map to 'pending' if status is 'To Do', 'Open', 'Backlog', or 'In Progress'. Map to 'done' if 'Done' or 'Closed'.
- priority: map Jira priority to high/medium/low (Highest/High → high, Medium → medium, Low/Lowest → low)
- source_id: the Jira issue key (e.g. PROJ-123, for posting comments back later)

Output ONLY valid JSON in this exact format, no markdown fences, no explanation:

{
  \"pulled_at\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",
  \"source\": \"jira\",
  \"source_config\": {
    \"project_key\": \"${project_key}\",
    \"jql\": \"${jql}\"
  },
  \"tasks\": [
    {
      \"id\": \"PROJ-001\",
      \"title\": \"Task title here\",
      \"description\": \"Full description including agent reference...\",
      \"status\": \"pending\",
      \"priority\": \"medium\",
      \"source_id\": \"PROJ-001\",
      \"completed_at\": null,
      \"failure_reason\": null
    }
  ]
}"

  echo "$pull_prompt" | claude -p --output-format text 2>&1
}
