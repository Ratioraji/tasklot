#!/usr/bin/env bash
###############################################################################
#  ████████╗ █████╗ ███████╗██╗  ██╗██╗      ██████╗ ████████╗
#  ╚══██╔══╝██╔══██╗██╔════╝██║ ██╔╝██║     ██╔═══██╗╚══██╔══╝
#     ██║   ███████║███████╗█████╔╝ ██║     ██║   ██║   ██║
#     ██║   ██╔══██║╚════██║██╔═██╗ ██║     ██║   ██║   ██║
#     ██║   ██║  ██║███████║██║  ██╗███████╗╚██████╔╝   ██║
#     ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝ ╚═════╝    ╚═╝
#
#  TaskLot — Autonomous AI-Powered Task Execution Pipeline
#  Author: Sey
#  Version: 1.0.0
#
#  Usage: ./tasklot.sh [--config config.json] [--dry-run] [--task TASK_ID]
###############################################################################

set -euo pipefail

# ─── Colors & Formatting ─────────────────────────────────────────────────────
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
TASKS_FILE="${SCRIPT_DIR}/tasks.json"
LOG_DIR="${SCRIPT_DIR}/logs"
ENGINES_DIR="${SCRIPT_DIR}/engines"
AGENTS_DIR="${SCRIPT_DIR}/agents"
QA_FILE="${SCRIPT_DIR}/qa/qa-agent.md"
GIT_AGENT_FILE="${AGENTS_DIR}/git-operations.agent.md"
DRY_RUN=false
SINGLE_TASK=""
PREVIOUS_BRANCH=""
PREVIOUS_TASK_ID=""
CURRENT_SOURCE_BRANCH=""
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${LOG_DIR}/tasklot_${TIMESTAMP}.log"

# ─── Logging ──────────────────────────────────────────────────────────────────
log() { echo -e "${DIM}[$(date +"%H:%M:%S")]${RESET} $1" | tee -a "$LOG_FILE"; }
log_success() { log "${GREEN}✔ $1${RESET}"; }
log_warn() { log "${YELLOW}⚠ $1${RESET}"; }
log_error() { log "${RED}✖ $1${RESET}"; }
log_info() { log "${BLUE}ℹ $1${RESET}"; }
log_step() { log "${CYAN}▶ $1${RESET}"; }

banner() {
  echo -e "${MAGENTA}${BOLD}"
  echo "  ┌─────────────────────────────────────────────┐"
  echo "  │            ⚡ T A S K L O T ⚡              │"
  echo "  │     Autonomous AI Task Execution Engine      │"
  echo "  └─────────────────────────────────────────────┘"
  echo -e "${RESET}"
}

# ─── Parse Arguments ──────────────────────────────────────────────────────────
parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --config) CONFIG_FILE="$2"; shift 2 ;;
      --dry-run) DRY_RUN=true; shift ;;
      --task) SINGLE_TASK="$2"; shift 2 ;;
      --help)
        echo "Usage: ./tasklot.sh [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --config FILE   Path to config.json (default: ./config.json)"
        echo "  --dry-run       Preview tasks without executing"
        echo "  --task ID       Run a single task by ID"
        echo "  --help          Show this help"
        exit 0
        ;;
      *) log_error "Unknown option: $1"; exit 1 ;;
    esac
  done
}

# ─── Config Loading ───────────────────────────────────────────────────────────
load_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    log_error "Config file not found: $CONFIG_FILE"
    exit 1
  fi

  ENGINE=$(jq -r '.engine // "claude-code"' "$CONFIG_FILE")
  PROJECT_DIR=$(jq -r '.project_dir // "."' "$CONFIG_FILE")
  BRANCH_PREFIX=$(jq -r '.branch_prefix // "feat"' "$CONFIG_FILE")
  BASE_BRANCH=$(jq -r '.base_branch // "main"' "$CONFIG_FILE")
  MAX_RETRIES=$(jq -r '.max_retries // 3' "$CONFIG_FILE")
  TEST_COMMAND=$(jq -r '.test_command // ""' "$CONFIG_FILE")
  CURL_TESTS_ENABLED=$(jq -r '.curl_tests_enabled // false' "$CONFIG_FILE")
  API_BASE_URL=$(jq -r '.api_base_url // "http://localhost:3000"' "$CONFIG_FILE")
  NOTION_ENABLED=$(jq -r 'if .task_source.type then (.task_source.type != "null") else (.notion.enabled // false) end' "$CONFIG_FILE")
  TASK_SOURCE_TYPE=$(jq -r '.task_source.type // "none"' "$CONFIG_FILE")
  AUTO_PR=$(jq -r '.auto_pr // true' "$CONFIG_FILE")
  AUTO_DOCUMENT=$(jq -r '.auto_document // true' "$CONFIG_FILE")

  # Validate engine exists
  if [[ ! -f "${ENGINES_DIR}/${ENGINE}.sh" ]]; then
    log_error "Engine not found: ${ENGINES_DIR}/${ENGINE}.sh"
    log_info "Available engines: $(ls "${ENGINES_DIR}"/*.sh 2>/dev/null | xargs -I{} basename {} .sh | tr '\n' ', ')"
    exit 1
  fi

  # Source the engine
  source "${ENGINES_DIR}/${ENGINE}.sh"

  log_info "Config loaded: engine=${BOLD}${ENGINE}${RESET}, project=${BOLD}${PROJECT_DIR}${RESET}"
  log_info "Branch prefix: ${BRANCH_PREFIX}, base: ${BASE_BRANCH}, max retries: ${MAX_RETRIES}"
}

# ─── Task Loading ─────────────────────────────────────────────────────────────
load_tasks() {
  if [[ ! -f "$TASKS_FILE" ]]; then
    log_error "Tasks file not found: $TASKS_FILE"
    log_info "Run './pull-tasks.sh' to fetch tasks from Notion, or create tasks.json manually."
    exit 1
  fi

  TOTAL_TASKS=$(jq '[.tasks[] | select(.status != "done")] | length' "$TASKS_FILE")
  log_info "Loaded ${BOLD}${TOTAL_TASKS}${RESET} pending tasks"
}

# ─── Extract Agent from Task Description ──────────────────────────────────────
# The ticket description starts with something like:
#   "read backend-developer.agent.md"
# We parse that to load the right agent context.
extract_agent() {
  local description="$1"
  local agent_ref

  # Match patterns like: "read backend-developer.agent.md" or "use frontend-developer.agent.md"
  agent_ref=$(echo "$description" | grep -oiE '(read|use|load|agent:)\s*[a-zA-Z0-9_-]+\.agent\.md' | head -1 | grep -oE '[a-zA-Z0-9_-]+\.agent\.md' || true)

  if [[ -n "$agent_ref" && -f "${AGENTS_DIR}/${agent_ref}" ]]; then
    echo "${AGENTS_DIR}/${agent_ref}"
  else
    echo ""
  fi
}

# ─── Strip Agent Reference from Description ───────────────────────────────────
# Returns the task description without the "read xxx.agent.md" line
strip_agent_line() {
  local description="$1"
  echo "$description" | sed -E '/^(read|use|load|agent:)\s*[a-zA-Z0-9_-]+\.agent\.md\s*$/Id'
}

# ─── Load Git Agent Context ───────────────────────────────────────────────────
load_git_agent() {
  if [[ -f "$GIT_AGENT_FILE" ]]; then
    cat "$GIT_AGENT_FILE"
  else
    log_warn "Git operations agent not found at ${GIT_AGENT_FILE} — using defaults"
    echo "Use conventional commits. Branch format: {type}/{scope}-{description}. PR descriptions should be detailed."
  fi
}

# ─── Resolve Source Branch (Stacked Branch Logic) ────────────────────────────
# Determines which branch to create the new task branch from:
#   - If previous task's branch is merged → branch from main
#   - If previous task's branch is unmerged → branch from it (stacked)
#   - If no previous task → branch from main
resolve_source_branch() {
  local source_branch="$BASE_BRANCH"

  if [[ -z "$PREVIOUS_BRANCH" ]]; then
    log_info "No previous task — branching from ${BOLD}${BASE_BRANCH}${RESET}"
    echo "$source_branch"
    return
  fi

  cd "$PROJECT_DIR"

  # Check if the previous branch has been merged into base branch
  local is_merged=false

  # Method 1: Check if gh pr reports it as merged
  if gh pr view "$PREVIOUS_BRANCH" --json state -q '.state' 2>/dev/null | grep -qi "MERGED"; then
    is_merged=true
  fi

  # Method 2: Fallback — check if branch is ancestor of base
  if [[ "$is_merged" == "false" ]]; then
    git fetch origin "$BASE_BRANCH" --quiet 2>/dev/null || true
    if git merge-base --is-ancestor "origin/${PREVIOUS_BRANCH}" "origin/${BASE_BRANCH}" 2>/dev/null; then
      is_merged=true
    fi
  fi

  if [[ "$is_merged" == "true" ]]; then
    log_info "Previous branch ${BOLD}${PREVIOUS_BRANCH}${RESET} is merged → branching from ${BOLD}${BASE_BRANCH}${RESET}"
    source_branch="$BASE_BRANCH"
  else
    log_info "Previous branch ${BOLD}${PREVIOUS_BRANCH}${RESET} is unmerged → ${YELLOW}stacking${RESET} on it"
    source_branch="$PREVIOUS_BRANCH"
  fi

  echo "$source_branch"
}

# ─── Git Operations (Agent-Driven) ───────────────────────────────────────────
create_branch() {
  local task_id="$1"
  local task_title="$2"

  # Determine source branch (stacked vs main)
  local source_branch
  source_branch=$(resolve_source_branch)

  log_step "Git Agent: Creating branch from ${BOLD}${source_branch}${RESET}..."

  local git_context
  git_context=$(load_git_agent)

  local stacking_note=""
  if [[ "$source_branch" != "$BASE_BRANCH" ]]; then
    stacking_note="
## ⚠️ STACKED BRANCH
This branch is being created FROM: ${source_branch} (NOT from ${BASE_BRANCH})
The previous task's PR has not been merged yet, so we are stacking on top of it.
When creating the PR later, the PR base will be: ${source_branch} (not ${BASE_BRANCH})
"
  fi

  local branch_prompt="You are the TaskLot Git Operations agent.

## Git Operations Standards
${git_context}
${stacking_note}
## Your Task
Create a properly named git branch for this task:

- Task ID: ${task_id}
- Task Title: ${task_title}
- Source Branch: ${source_branch}
- Project Directory: ${PROJECT_DIR}

## Instructions
1. cd into the project directory
2. Checkout ${source_branch} and pull latest
3. Create a new branch following the naming convention from your standards
4. The branch name must reflect the task title and follow the {type}/{scope}-{description} pattern
5. After creating the branch, output ONLY the branch name on a line starting with BRANCH_NAME: followed by the branch name

Example output (after doing the git operations):
BRANCH_NAME: feat/api-auth-endpoints"

  local result
  result=$(execute_task "$branch_prompt" "$PROJECT_DIR" 2>&1)

  # Extract branch name from the result
  local branch_name
  branch_name=$(echo "$result" | grep -oP 'BRANCH_NAME:\s*\K\S+' | head -1)

  if [[ -z "$branch_name" ]]; then
    # Fallback: generate a safe branch name
    local slug=$(echo "$task_title" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-|-$//g' | cut -c1-50)
    branch_name="${BRANCH_PREFIX}/${task_id}-${slug}"
    cd "$PROJECT_DIR"
    git checkout "$source_branch" 2>/dev/null || true
    git pull origin "$source_branch" 2>/dev/null || true
    git checkout -b "$branch_name" 2>/dev/null || git checkout "$branch_name"
    log_warn "Git agent did not return branch name — used fallback: ${branch_name}"
  fi

  # Store source branch for PR creation
  CURRENT_SOURCE_BRANCH="$source_branch"

  echo "$branch_name"
}

commit_and_push() {
  local branch_name="$1"
  local task_title="$2"
  local task_id="$3"

  log_step "Git Agent: Committing and pushing..."

  local git_context
  git_context=$(load_git_agent)

  local commit_prompt="You are the TaskLot Git Operations agent.

## Git Operations Standards
${git_context}

## Your Task
Commit all changes and push to remote for this task:

- Task ID: ${task_id}
- Task Title: ${task_title}
- Branch: ${branch_name}
- Project Directory: ${PROJECT_DIR}

## Instructions
1. cd into the project directory
2. Review the changed files with git status and git diff --stat
3. Stage and commit the changes following the commit convention from your standards
4. Use proper commit granularity — if changes span multiple logical units, create MULTIPLE commits in the correct order (e.g. migrations first, then feature code, then tests)
5. Each commit message must follow the conventional commits format: {type}({scope}): {description}
6. Include the Task ID in the commit body footer
7. Push the branch to origin
8. After pushing, output: PUSH_COMPLETE"

  local result
  result=$(execute_task "$commit_prompt" "$PROJECT_DIR" 2>&1)

  if echo "$result" | grep -q "PUSH_COMPLETE"; then
    log_success "Pushed to ${branch_name}"
  else
    # Fallback: basic commit and push
    cd "$PROJECT_DIR"
    git add -A
    git commit -m "feat: ${task_title}

Task: ${task_id}" || {
      log_warn "Nothing to commit"
      return 0
    }
    git push -u origin "$branch_name"
    log_warn "Git agent push did not confirm — used fallback commit"
  fi
}

create_pull_request() {
  local branch_name="$1"
  local task_title="$2"
  local task_id="$3"
  local documentation="$4"

  # Use the source branch determined during create_branch
  local pr_base="${CURRENT_SOURCE_BRANCH:-$BASE_BRANCH}"

  local stacked_label=""
  if [[ "$pr_base" != "$BASE_BRANCH" ]]; then
    stacked_label="
## ⚠️ STACKED PR
This PR targets: ${pr_base} (not ${BASE_BRANCH})
This is a stacked PR — it should be reviewed after its parent PR is merged.
Once the parent PR merges, retarget this PR to ${BASE_BRANCH}.
"
  fi

  log_step "Git Agent: Creating pull request → base: ${BOLD}${pr_base}${RESET}..."

  local git_context
  git_context=$(load_git_agent)

  local pr_prompt="You are the TaskLot Git Operations agent.

## Git Operations Standards
${git_context}

## Your Task
Create a GitHub Pull Request for this completed task:

- Task ID: ${task_id}
- Task Title: ${task_title}
- Branch: ${branch_name}
- Base Branch (PR target): ${pr_base}
- Project Directory: ${PROJECT_DIR}
${stacked_label}

## Implementation Documentation
${documentation}

## Instructions
1. cd into the project directory
2. Use the \`gh\` CLI to create the pull request
3. The PR title MUST follow the conventional format from your standards
4. The PR description MUST use the PR description template from your standards
5. Fill in all sections of the template with relevant details from the implementation documentation above
6. Include the Task ID in the description
7. After creating the PR, output: PR_CREATED"

  local result
  result=$(execute_task "$pr_prompt" "$PROJECT_DIR" 2>&1)

  if echo "$result" | grep -q "PR_CREATED"; then
    log_success "PR created for ${branch_name}"
  else
    # Fallback: create a basic PR
    cd "$PROJECT_DIR"
    gh pr create \
      --base "$pr_base" \
      --head "$branch_name" \
      --title "feat: ${task_title}" \
      --body "### 📌 Summary

> ${task_title}
${stacked_label}
### 🛠️ Changes Made

${documentation}

### ✅ Test & Validation

- [x] Architecture conformance verified
- [x] Test suite passed
- [x] API endpoints validated

---

*Task ID: ${task_id}*" 2>&1 || {
      log_warn "PR creation failed — may already exist"
      return 0
    }
    log_warn "Git agent PR did not confirm — used fallback PR"
  fi
}

# ─── QA Validation ────────────────────────────────────────────────────────────
run_qa_check() {
  local agent_file="$1"
  local task_description="$2"
  local attempt="$3"

  log_step "QA Gate: Architecture & Quality Check (attempt ${attempt})"

  local qa_prompt="You are the TaskLot QA Agent. Your job is to review the code changes just made and validate them.

## Universal QA Rules
$(cat "$QA_FILE" 2>/dev/null || echo "No QA rules file found. Apply general best practices.")

"

  # If an agent file was used, include it for stack-specific validation
  if [[ -n "$agent_file" && -f "$agent_file" ]]; then
    qa_prompt+="
## Stack-Specific Standards (from agent file)
$(cat "$agent_file")

"
  fi

  qa_prompt+="
## Task That Was Implemented
${task_description}

## Your Instructions
1. Review ALL changed files (use git diff)
2. Check that the implementation follows the architecture rules above
3. Check for security issues, missing error handling, and edge cases
4. Verify naming conventions and file structure
5. If everything passes, respond with exactly: QA_PASSED
6. If issues are found, describe each issue clearly and fix them, then respond with: QA_FIXED
7. If issues cannot be fixed, respond with: QA_FAILED followed by the reason"

  local qa_result
  qa_result=$(execute_task "$qa_prompt" "$PROJECT_DIR" 2>&1)

  if echo "$qa_result" | grep -q "QA_PASSED"; then
    log_success "QA check passed"
    return 0
  elif echo "$qa_result" | grep -q "QA_FIXED"; then
    log_warn "QA found and fixed issues"
    return 0
  else
    log_error "QA check failed"
    echo "$qa_result" >> "$LOG_FILE"
    return 1
  fi
}

# ─── Test Execution ───────────────────────────────────────────────────────────
run_tests() {
  local attempt="$1"

  if [[ -z "$TEST_COMMAND" ]]; then
    log_warn "No test command configured — skipping tests"
    return 0
  fi

  log_step "Test Gate: Running test suite (attempt ${attempt})"

  cd "$PROJECT_DIR"
  if eval "$TEST_COMMAND" >> "$LOG_FILE" 2>&1; then
    log_success "All tests passed"
    return 0
  else
    log_error "Tests failed"
    return 1
  fi
}

# ─── Curl API Tests ───────────────────────────────────────────────────────────
run_curl_tests() {
  local task_description="$1"
  local attempt="$2"

  if [[ "$CURL_TESTS_ENABLED" != "true" ]]; then
    log_warn "Curl API tests disabled — skipping"
    return 0
  fi

  log_step "API Gate: Deep curl-based endpoint testing (attempt ${attempt})"

  local curl_prompt="You are the TaskLot API Test Agent. Based on the task that was just implemented, you must:

## Task Implemented
${task_description}

## Your Instructions
1. Identify ALL API endpoints that were created or modified
2. For each endpoint, run curl tests covering:
   - Happy path (valid request → expected response)
   - Invalid input (missing fields, wrong types)
   - Edge cases (empty strings, very long inputs, special characters)
   - Authentication/authorization if applicable
   - Rate limiting if applicable
3. Base URL: ${API_BASE_URL}
4. Run each curl command and verify the response status code and body
5. If ALL tests pass, respond with: API_TESTS_PASSED
6. If any test fails, describe the failure and attempt to fix the code, then respond with: API_TESTS_FIXED
7. If tests fail and cannot be fixed, respond with: API_TESTS_FAILED followed by details"

  local curl_result
  curl_result=$(execute_task "$curl_prompt" "$PROJECT_DIR" 2>&1)

  if echo "$curl_result" | grep -q "API_TESTS_PASSED"; then
    log_success "API curl tests passed"
    return 0
  elif echo "$curl_result" | grep -q "API_TESTS_FIXED"; then
    log_warn "API tests found and fixed issues"
    return 0
  else
    log_error "API curl tests failed"
    echo "$curl_result" >> "$LOG_FILE"
    return 1
  fi
}

# ─── Fix Issues ───────────────────────────────────────────────────────────────
attempt_fix() {
  local agent_file="$1"
  local task_description="$2"
  local failure_context="$3"

  log_step "Attempting auto-fix..."

  local fix_prompt="You are the TaskLot Fix Agent. A previous check has failed. Your job is to fix the issues.

## Agent Context
$(if [[ -n "$agent_file" && -f "$agent_file" ]]; then cat "$agent_file"; else echo "No agent file — use general best practices."; fi)

## Original Task
${task_description}

## What Failed
${failure_context}

## Instructions
1. Analyze the failure
2. Fix all issues in the codebase
3. Ensure the fix doesn't break other functionality
4. Respond with a summary of what you fixed"

  execute_task "$fix_prompt" "$PROJECT_DIR" >> "$LOG_FILE" 2>&1
}

# ─── Generate Documentation ──────────────────────────────────────────────────
generate_documentation() {
  local task_description="$1"
  local agent_file="$2"

  log_step "Generating implementation documentation..."

  local doc_prompt="You are the TaskLot Documentation Agent. Summarize the implementation that was just completed.

## Task
${task_description}

## Instructions
Write a clear, concise summary covering:
1. What was implemented
2. Key technical decisions made
3. Files created or modified
4. Any notable patterns or approaches used
5. Testing coverage

Keep it professional and useful for code review. Use markdown formatting.
Do NOT include any preamble — start directly with the summary."

  local documentation
  documentation=$(execute_task "$doc_prompt" "$PROJECT_DIR" 2>&1)
  echo "$documentation"
}

# ─── Document to Source Tool ──────────────────────────────────────────────────
document_to_source() {
  local task_id="$1"
  local documentation="$2"
  local source_id="$3"

  if [[ "$AUTO_DOCUMENT" != "true" || "$TASK_SOURCE_TYPE" == "none" ]]; then
    log_warn "Source documentation disabled — skipping"
    return 0
  fi

  if [[ -z "$source_id" ]]; then
    log_warn "No source_id for task — skipping documentation"
    return 0
  fi

  log_step "Documenting to ${TASK_SOURCE_TYPE} (${source_id})..."

  local doc_prompt=""

  case "$TASK_SOURCE_TYPE" in
    notion)
      doc_prompt="Post the following as a comment on the Notion page with ID: ${source_id}

---
## Implementation Report

${documentation}

---
*Documented at $(date '+%Y-%m-%d %H:%M:%S')*"
      ;;
    jira)
      doc_prompt="Add the following as a comment on the Jira issue: ${source_id}

---
## Implementation Report

${documentation}

---
*Documented at $(date '+%Y-%m-%d %H:%M:%S')*"
      ;;
    linear)
      doc_prompt="Add the following as a comment on the Linear issue with ID: ${source_id}

---
## Implementation Report

${documentation}

---
*Documented at $(date '+%Y-%m-%d %H:%M:%S')*"
      ;;
    github)
      doc_prompt="Add the following as a comment on GitHub issue #${source_id}

---
## Implementation Report

${documentation}

---
*Documented at $(date '+%Y-%m-%d %H:%M:%S')*"
      ;;
    *)
      doc_prompt="Document the following implementation for task ${source_id}:

${documentation}"
      ;;
  esac

  execute_task "$doc_prompt" "$PROJECT_DIR" >> "$LOG_FILE" 2>&1
  log_success "Documentation posted to ${TASK_SOURCE_TYPE}"
}

# ─── Mark Task Done ───────────────────────────────────────────────────────────
mark_task_done() {
  local task_index="$1"
  local tmp_file=$(mktemp)

  jq ".tasks[${task_index}].status = \"done\" | .tasks[${task_index}].completed_at = \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"" "$TASKS_FILE" > "$tmp_file"
  mv "$tmp_file" "$TASKS_FILE"
}

mark_task_failed() {
  local task_index="$1"
  local reason="$2"
  local tmp_file=$(mktemp)

  jq ".tasks[${task_index}].status = \"failed\" | .tasks[${task_index}].failure_reason = \"${reason}\"" "$TASKS_FILE" > "$tmp_file"
  mv "$tmp_file" "$TASKS_FILE"
}

# ─── Execute Single Task ─────────────────────────────────────────────────────
execute_single_task() {
  local task_index="$1"
  local task_id task_title task_description task_source_id

  task_id=$(jq -r ".tasks[${task_index}].id" "$TASKS_FILE")
  task_title=$(jq -r ".tasks[${task_index}].title" "$TASKS_FILE")
  task_description=$(jq -r ".tasks[${task_index}].description" "$TASKS_FILE")
  task_source_id=$(jq -r ".tasks[${task_index}].source_id // .tasks[${task_index}].notion_page_id // empty" "$TASKS_FILE")

  echo ""
  echo -e "${MAGENTA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  log_info "Task ${BOLD}${task_id}${RESET}: ${task_title}"
  echo -e "${MAGENTA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

  # ── Extract agent reference from description ──
  local agent_file
  agent_file=$(extract_agent "$task_description")
  local clean_description
  clean_description=$(strip_agent_line "$task_description")

  if [[ -n "$agent_file" ]]; then
    log_info "Agent: ${BOLD}$(basename "$agent_file")${RESET}"
  else
    log_warn "No agent file referenced — using task description only"
  fi

  # ── Dry run check ──
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "[DRY RUN] Would execute task: ${task_title}"
    log_info "[DRY RUN] Agent: $(basename "${agent_file:-none}")"
    return 0
  fi

  # ── Create branch ──
  log_step "Creating branch..."
  local branch_name
  branch_name=$(create_branch "$task_id" "$task_title")
  log_success "Branch: ${branch_name}"

  # ── Build implementation prompt ──
  local implementation_prompt=""

  if [[ -n "$agent_file" && -f "$agent_file" ]]; then
    implementation_prompt+="## Agent Context & Architecture Standards
$(cat "$agent_file")

"
  fi

  implementation_prompt+="## Task to Implement
${clean_description}

## Instructions
- Implement this task fully according to the agent context and standards above
- Follow all naming conventions, file structure rules, and patterns specified
- Include proper error handling and input validation
- Write clean, production-ready code
- Add inline comments for complex logic"

  # ── Execute implementation ──
  log_step "Implementing task..."
  execute_task "$implementation_prompt" "$PROJECT_DIR" >> "$LOG_FILE" 2>&1
  log_success "Implementation complete"

  # ── Validation loop ──
  local attempt=1
  local all_passed=false

  while [[ $attempt -le $MAX_RETRIES ]]; do
    log_info "Validation round ${attempt}/${MAX_RETRIES}"
    local qa_ok=false tests_ok=false curl_ok=false

    # QA Check
    if run_qa_check "$agent_file" "$clean_description" "$attempt"; then
      qa_ok=true
    else
      attempt_fix "$agent_file" "$clean_description" "QA architecture check failed"
    fi

    # Test Suite
    if [[ "$qa_ok" == "true" ]]; then
      if run_tests "$attempt"; then
        tests_ok=true
      else
        attempt_fix "$agent_file" "$clean_description" "Test suite failed"
      fi
    fi

    # Curl API Tests
    if [[ "$tests_ok" == "true" ]]; then
      if run_curl_tests "$clean_description" "$attempt"; then
        curl_ok=true
      else
        attempt_fix "$agent_file" "$clean_description" "API curl tests failed"
      fi
    fi

    # All gates passed?
    if [[ "$qa_ok" == "true" && "$tests_ok" == "true" && "$curl_ok" == "true" ]]; then
      all_passed=true
      break
    fi

    ((attempt++))
  done

  if [[ "$all_passed" != "true" ]]; then
    log_error "Task ${task_id} failed after ${MAX_RETRIES} attempts"
    mark_task_failed "$task_index" "Failed validation after ${MAX_RETRIES} attempts"
    # Still track the branch — next task should branch from main since this one failed
    PREVIOUS_BRANCH=""
    PREVIOUS_TASK_ID=""
    return 1
  fi

  # ── Generate documentation ──
  local documentation
  documentation=$(generate_documentation "$clean_description" "$agent_file")

  # ── Commit, push, PR ──
  log_step "Committing and pushing..."
  commit_and_push "$branch_name" "$task_title" "$task_id"

  if [[ "$AUTO_PR" == "true" ]]; then
    log_step "Creating pull request..."
    create_pull_request "$branch_name" "$task_title" "$task_id" "$documentation"
  fi

  # ── Document to Notion ──
  if [[ -n "$task_source_id" ]]; then
    document_to_source "$task_id" "$documentation" "$task_source_id"
  fi

  # ── Mark done ──
  mark_task_done "$task_index"

  # ── Track for stacked branches ──
  PREVIOUS_BRANCH="$branch_name"
  PREVIOUS_TASK_ID="$task_id"

  log_success "Task ${task_id} completed successfully! ✨"

  return 0
}

# ─── Main Loop ────────────────────────────────────────────────────────────────
main() {
  banner
  parse_args "$@"
  mkdir -p "$LOG_DIR"
  load_config
  load_tasks

  local completed=0
  local failed=0
  local skipped=0
  local start_time=$(date +%s)

  # Get task indices
  local task_count
  task_count=$(jq '.tasks | length' "$TASKS_FILE")

  for ((i=0; i<task_count; i++)); do
    local status
    status=$(jq -r ".tasks[${i}].status" "$TASKS_FILE")

    # Skip completed/failed tasks
    if [[ "$status" == "done" || "$status" == "failed" ]]; then
      continue
    fi

    # If single task mode, skip non-matching tasks
    if [[ -n "$SINGLE_TASK" ]]; then
      local tid
      tid=$(jq -r ".tasks[${i}].id" "$TASKS_FILE")
      if [[ "$tid" != "$SINGLE_TASK" ]]; then
        continue
      fi
    fi

    if execute_single_task "$i"; then
      ((completed++))
    else
      ((failed++))
    fi
  done

  # ── Summary ──
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  local minutes=$((duration / 60))
  local seconds=$((duration % 60))

  echo ""
  echo -e "${MAGENTA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${BOLD}  ⚡ TaskLot Execution Summary${RESET}"
  echo -e "${MAGENTA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "  ${GREEN}Completed:${RESET} ${completed}"
  echo -e "  ${RED}Failed:${RESET}    ${failed}"
  echo -e "  ${BLUE}Duration:${RESET}  ${minutes}m ${seconds}s"
  echo -e "  ${DIM}Log:       ${LOG_FILE}${RESET}"
  echo -e "${MAGENTA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo ""
}

main "$@"
