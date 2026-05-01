#!/usr/bin/env bash
###############################################################################
#  TaskLot — Task Puller
#  Fetches tasks from your project management tool and generates tasks.json
#
#  Supports: Notion, Jira, Linear, GitHub Issues, Custom
#  The puller is selected via config.json → task_source.type
#
#  Usage: ./pull-tasks.sh [--config config.json] [--source notion|jira|linear|github|custom]
###############################################################################

set -euo pipefail

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ─── Globals ──────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.json"
PULLERS_DIR="${SCRIPT_DIR}/pullers"
OUTPUT_FILE="${SCRIPT_DIR}/tasks.json"
SOURCE_OVERRIDE=""

# ─── Parse Args ───────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --config) CONFIG_FILE="$2"; shift 2 ;;
    --source) SOURCE_OVERRIDE="$2"; shift 2 ;;
    --output) OUTPUT_FILE="$2"; shift 2 ;;
    --list)
      echo "Available pullers:"
      for f in "${PULLERS_DIR}"/*.sh; do
        basename "$f" .sh
      done
      exit 0
      ;;
    --help)
      echo "Usage: ./pull-tasks.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --config FILE     Path to config.json (default: ./config.json)"
      echo "  --source TYPE     Override task source (notion, jira, linear, github, custom)"
      echo "  --output FILE     Output file path (default: ./tasks.json)"
      echo "  --list            List available pullers"
      echo "  --help            Show this help"
      exit 0
      ;;
    *) echo -e "${RED}Unknown option: $1${RESET}"; exit 1 ;;
  esac
done

# ─── Validate Config ─────────────────────────────────────────────────────────
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo -e "${RED}✖ Config file not found: ${CONFIG_FILE}${RESET}"
  exit 1
fi

# ─── Determine Source ─────────────────────────────────────────────────────────
# Priority: --source flag > config.json task_source.type > legacy config.json notion field
SOURCE_TYPE=""

if [[ -n "$SOURCE_OVERRIDE" ]]; then
  SOURCE_TYPE="$SOURCE_OVERRIDE"
elif jq -e '.task_source.type' "$CONFIG_FILE" > /dev/null 2>&1; then
  SOURCE_TYPE=$(jq -r '.task_source.type' "$CONFIG_FILE")
elif jq -e '.notion.enabled' "$CONFIG_FILE" > /dev/null 2>&1; then
  # Backward compatibility: legacy config with notion.* fields
  LEGACY_ENABLED=$(jq -r '.notion.enabled // false' "$CONFIG_FILE")
  if [[ "$LEGACY_ENABLED" == "true" ]]; then
    SOURCE_TYPE="notion"
    echo -e "${YELLOW}⚠ Using legacy config format (notion.*). Consider migrating to task_source.type${RESET}"
    echo ""
  fi
fi

if [[ -z "$SOURCE_TYPE" ]]; then
  echo -e "${RED}✖ No task source configured${RESET}"
  echo ""
  echo -e "Set ${BOLD}task_source.type${RESET} in config.json:"
  echo ""
  echo '  "task_source": {'
  echo '    "type": "notion",      ← notion | jira | linear | github | custom'
  echo '    "config": { ... }'
  echo '  }'
  echo ""
  echo -e "Or use ${BOLD}--source${RESET} flag: ./pull-tasks.sh --source notion"
  echo ""
  echo -e "Available pullers: $(ls "${PULLERS_DIR}"/*.sh 2>/dev/null | xargs -I{} basename {} .sh | tr '\n' ', ' | sed 's/,$//')"
  exit 1
fi

# ─── Validate Puller Exists ──────────────────────────────────────────────────
PULLER_FILE="${PULLERS_DIR}/${SOURCE_TYPE}.sh"

if [[ ! -f "$PULLER_FILE" ]]; then
  echo -e "${RED}✖ Puller not found: ${PULLER_FILE}${RESET}"
  echo ""
  echo -e "Available pullers:"
  for f in "${PULLERS_DIR}"/*.sh; do
    local_name=$(basename "$f" .sh)
    echo -e "  ${CYAN}${local_name}${RESET}"
  done
  echo ""
  echo -e "Create a custom puller: cp ${PULLERS_DIR}/custom.sh ${PULLERS_DIR}/${SOURCE_TYPE}.sh"
  exit 1
fi

# ─── Source the Puller ────────────────────────────────────────────────────────
source "$PULLER_FILE"

# ─── Banner ───────────────────────────────────────────────────────────────────
echo -e "${MAGENTA}${BOLD}"
echo "  ┌─────────────────────────────────────────────┐"
echo "  │         ⚡ TaskLot — Task Puller ⚡          │"
echo "  └─────────────────────────────────────────────┘"
echo -e "${RESET}"

echo -e "${CYAN}▶ Source:${RESET} ${BOLD}${SOURCE_TYPE}${RESET} (${PULLER_FILE})"
echo -e "${CYAN}▶ Config:${RESET} ${CONFIG_FILE}"
echo -e "${CYAN}▶ Output:${RESET} ${OUTPUT_FILE}"
echo ""

# ─── Pull Tasks ───────────────────────────────────────────────────────────────
echo -e "${BLUE}ℹ Fetching tasks from ${BOLD}${SOURCE_TYPE}${RESET}${BLUE}...${RESET}"
echo ""

RESULT=$(pull_tasks "$CONFIG_FILE" "$OUTPUT_FILE" 2>&1)

# ─── Parse & Validate JSON ───────────────────────────────────────────────────
TASKS_JSON=$(echo "$RESULT" | grep -Pzo '(?s)\{.*\}' | tr '\0' '\n' || echo "")

if [[ -z "$TASKS_JSON" ]]; then
  echo -e "${RED}✖ Failed to parse tasks from ${SOURCE_TYPE} response${RESET}"
  echo -e "${DIM}Raw response:${RESET}"
  echo "$RESULT"
  exit 1
fi

if ! echo "$TASKS_JSON" | jq . > /dev/null 2>&1; then
  echo -e "${RED}✖ Invalid JSON returned from ${SOURCE_TYPE} puller${RESET}"
  echo "$TASKS_JSON"
  exit 1
fi

# Validate required fields
if ! echo "$TASKS_JSON" | jq -e '.tasks' > /dev/null 2>&1; then
  echo -e "${RED}✖ JSON missing required 'tasks' array${RESET}"
  echo "$TASKS_JSON" | jq '.' 2>/dev/null || echo "$TASKS_JSON"
  exit 1
fi

# ─── Write tasks.json ────────────────────────────────────────────────────────
echo "$TASKS_JSON" | jq '.' > "$OUTPUT_FILE"

TASK_COUNT=$(jq '.tasks | length' "$OUTPUT_FILE")
PENDING_COUNT=$(jq '[.tasks[] | select(.status == "pending")] | length' "$OUTPUT_FILE")
DONE_COUNT=$(jq '[.tasks[] | select(.status == "done")] | length' "$OUTPUT_FILE")

echo -e "${GREEN}✔ Successfully pulled ${BOLD}${TASK_COUNT}${RESET}${GREEN} tasks (${PENDING_COUNT} pending, ${DONE_COUNT} done)${RESET}"
echo -e "${DIM}  Saved to: ${OUTPUT_FILE}${RESET}"
echo ""

# ─── Preview Tasks ────────────────────────────────────────────────────────────
echo -e "${CYAN}${BOLD}Task Preview:${RESET}"
echo ""

jq -r '.tasks[] | "  [\(.status | if . == "pending" then "○" elif . == "done" then "✔" else "✖" end)] \(.id) — \(.title) (\(.priority))"' "$OUTPUT_FILE"

echo ""

# Show agent references
AGENTS_USED=$(jq -r '.tasks[].description' "$OUTPUT_FILE" | grep -oiE '(read|use|load|agent:)\s*[a-zA-Z0-9_-]+\.agent\.md' | grep -oE '[a-zA-Z0-9_-]+\.agent\.md' | sort -u || true)

if [[ -n "$AGENTS_USED" ]]; then
  echo -e "${CYAN}${BOLD}Agents Referenced:${RESET}"
  echo "$AGENTS_USED" | while read -r agent; do
    if [[ -f "${SCRIPT_DIR}/agents/${agent}" ]]; then
      echo -e "  ${GREEN}✔${RESET} ${agent}"
    else
      echo -e "  ${RED}✖${RESET} ${agent} ${DIM}(not found in agents/)${RESET}"
    fi
  done
  echo ""
fi

echo -e "${GREEN}${BOLD}Ready to run: ./tasklot.sh${RESET}"
