#!/usr/bin/env bash
###############################################################################
#  TaskLot — Notion Task Puller
#  Fetches all tickets from a Notion database and generates tasks.json
#
#  Usage: ./pull-tasks.sh [--config config.json]
#
#  This script uses Claude Code with Notion MCP to pull tasks.
#  Ensure your Notion MCP connection is configured in Claude Code.
###############################################################################

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.json"

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --config) CONFIG_FILE="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo -e "${RED}Config file not found: ${CONFIG_FILE}${RESET}"
  exit 1
fi

NOTION_DB_ID=$(jq -r '.notion.database_id // empty' "$CONFIG_FILE")

if [[ -z "$NOTION_DB_ID" ]]; then
  echo -e "${RED}Notion database_id not set in config.json${RESET}"
  exit 1
fi

echo -e "${MAGENTA}${BOLD}"
echo "  ┌─────────────────────────────────────────────┐"
echo "  │       ⚡ TaskLot — Notion Pull ⚡           │"
echo "  └─────────────────────────────────────────────┘"
echo -e "${RESET}"

echo -e "${CYAN}▶ Pulling tasks from Notion database: ${BOLD}${NOTION_DB_ID}${RESET}"
echo ""

# Use Claude Code to query Notion via MCP and output structured JSON
PULL_PROMPT="You have access to Notion via MCP. Query the Notion database with ID: ${NOTION_DB_ID}

Fetch ALL pages/tickets from this database. For each ticket, extract:
- id: a short identifier (use the Notion page ID or a sequential number like TASK-001)
- title: the page title
- description: the full page content/body (this includes the agent reference like 'read backend-developer.agent.md')
- status: the status property (map to 'pending' if it's 'To Do' or 'Not Started', 'done' if 'Done' or 'Complete')
- priority: priority if available (high, medium, low), default to 'medium'
- notion_page_id: the Notion page ID (for posting comments back later)

Output ONLY valid JSON in this exact format, no markdown fences, no explanation:

{
  \"pulled_at\": \"ISO_TIMESTAMP\",
  \"source\": \"notion\",
  \"database_id\": \"${NOTION_DB_ID}\",
  \"tasks\": [
    {
      \"id\": \"TASK-001\",
      \"title\": \"Task title here\",
      \"description\": \"Full description including agent reference...\",
      \"status\": \"pending\",
      \"priority\": \"medium\",
      \"notion_page_id\": \"notion-page-id-here\",
      \"completed_at\": null,
      \"failure_reason\": null
    }
  ]
}"

echo -e "${BLUE}ℹ Calling Claude Code to fetch Notion data...${RESET}"
echo ""

RESULT=$(echo "$PULL_PROMPT" | claude -p --output-format text 2>&1)

# Try to extract JSON from the result
TASKS_JSON=$(echo "$RESULT" | grep -Pzo '(?s)\{.*\}' | tr '\0' '\n' || echo "")

if [[ -z "$TASKS_JSON" ]]; then
  echo -e "${RED}✖ Failed to parse tasks from Notion response${RESET}"
  echo -e "${DIM}Raw response:${RESET}"
  echo "$RESULT"
  exit 1
fi

# Validate JSON
if ! echo "$TASKS_JSON" | jq . > /dev/null 2>&1; then
  echo -e "${RED}✖ Invalid JSON returned${RESET}"
  echo "$TASKS_JSON"
  exit 1
fi

# Write tasks.json
echo "$TASKS_JSON" | jq '.' > "${SCRIPT_DIR}/tasks.json"

TASK_COUNT=$(jq '.tasks | length' "${SCRIPT_DIR}/tasks.json")

echo -e "${GREEN}✔ Successfully pulled ${BOLD}${TASK_COUNT}${RESET}${GREEN} tasks${RESET}"
echo -e "${DIM}  Saved to: ${SCRIPT_DIR}/tasks.json${RESET}"
echo ""

# Preview tasks
echo -e "${CYAN}${BOLD}Task Preview:${RESET}"
echo ""
jq -r '.tasks[] | "  [\(.status | if . == "pending" then "○" elif . == "done" then "✔" else "✖" end)] \(.id) — \(.title) (\(.priority))"' "${SCRIPT_DIR}/tasks.json"
echo ""
echo -e "${GREEN}${BOLD}Ready to run: ./tasklot.sh${RESET}"
