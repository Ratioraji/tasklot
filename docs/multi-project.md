# Running TaskLot on Multiple Projects Simultaneously

A complete guide to executing autonomous AI pipelines across multiple projects in parallel — shipping features across your entire portfolio at the speed of thought.

---

## Table of Contents

- [Why Multi-Project Execution](#why-multi-project-execution)
- [Architecture](#architecture)
- [Setup](#setup)
- [Configuration Per Project](#configuration-per-project)
- [Running in Parallel](#running-in-parallel)
- [Shared vs Isolated Agents](#shared-vs-isolated-agents)
- [Resource Management](#resource-management)
- [Monitoring Multiple Runs](#monitoring-multiple-runs)
- [Orchestrating with a Meta-Script](#orchestrating-with-a-meta-script)
- [Real-World Scenarios](#real-world-scenarios)
- [Troubleshooting](#troubleshooting)

---

## Why Multi-Project Execution

Most developers and teams work on more than one project. You might have:

- A **SaaS product** with a separate backend API, frontend app, and marketing site
- **Multiple client projects** with different stacks but similar patterns
- A **main product** and several **internal tools** that need features built in sync
- **Microservices** that each live in their own repo but need coordinated updates

Without TaskLot, you'd work on one project at a time — context switching, losing momentum, and waiting for reviews before starting the next thing.

With multi-project TaskLot, you set up your tickets and agents for each project, fire them all off, and come back to a stack of PRs across every repo. Each project runs its own independent pipeline with its own agents, QA rules, and engine.

---

## Architecture

Each TaskLot instance is fully independent. There's no shared state between projects — each one has its own config, its own tasks, its own logs, and its own agents. This means you can run as many as your machine (and API rate limits) can handle.

```
┌─────────────────────────────────────────────────────────────┐
│                     Your Machine                            │
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌────────────┐  │
│  │  TaskLot Run #1  │  │  TaskLot Run #2  │  │  Run #3    │  │
│  │                  │  │                  │  │            │  │
│  │  Config: api.json│  │  Config: web.json│  │  tools.json│  │
│  │  Engine: claude  │  │  Engine: aider   │  │  Engine:   │  │
│  │  Tasks: 12       │  │  Tasks: 8        │  │  claude    │  │
│  │  Agents: backend │  │  Agents: frontend│  │  Tasks: 5  │  │
│  │                  │  │                  │  │            │  │
│  │  ▶ Project:      │  │  ▶ Project:      │  │  ▶ Project:│  │
│  │  ~/repos/api     │  │  ~/repos/web     │  │  ~/repos/  │  │
│  │                  │  │                  │  │  tools     │  │
│  └─────────────────┘  └─────────────────┘  └────────────┘  │
│         │                     │                    │        │
│         ▼                     ▼                    ▼        │
│     logs/api_*.log        logs/web_*.log      logs/tools_*  │
└─────────────────────────────────────────────────────────────┘
```

Each run pushes to its own repo, creates PRs in its own repo, and documents back to its own tickets. They never interfere with each other.

---

## Setup

### Directory Structure

There are two approaches to organising multi-project TaskLot:

**Approach A: Single TaskLot installation, multiple configs**

One copy of TaskLot with per-project config files. Best when projects share the same agents or you want everything in one place.

```
tasklot/
├── tasklot.sh
├── pull-tasks.sh
├── configs/                          # Per-project configs
│   ├── api-backend.json
│   ├── web-frontend.json
│   ├── admin-dashboard.json
│   └── mobile-app.json
├── agents/                           # Shared agent pool
│   ├── git-operations.agent.md
│   ├── nestjs-backend.agent.md
│   ├── react-frontend.agent.md
│   ├── react-native-mobile.agent.md
│   └── admin-panel.agent.md
├── qa/
│   └── qa-agent.md
├── engines/
├── pullers/
└── logs/                             # All logs land here
```

**Approach B: TaskLot copy per project**

A separate TaskLot installation per project. Best when projects have completely different conventions, teams, or you want total isolation.

```
~/projects/
├── api-backend/
│   ├── src/                          # The actual project
│   └── .tasklot/                     # TaskLot lives inside the project
│       ├── tasklot.sh
│       ├── config.json
│       ├── agents/
│       └── ...
├── web-frontend/
│   ├── src/
│   └── .tasklot/
│       ├── tasklot.sh
│       ├── config.json
│       ├── agents/
│       └── ...
└── admin-dashboard/
    ├── src/
    └── .tasklot/
```

**Recommendation:** Start with Approach A. It's simpler, lets you share agents across projects, and one `configs/` folder gives you a birds-eye view of everything you're running.

---

## Configuration Per Project

Each project gets its own config file. The key differences between configs are typically `project_dir`, `task_source`, `test_command`, and which agents the tickets reference.

### Example: API Backend (`configs/api-backend.json`)

```json
{
  "project_name": "api-backend",
  "project_dir": "/home/dev/repos/api-backend",
  "engine": "claude-code",
  "base_branch": "main",
  "branch_prefix": "feat",
  "auto_pr": true,
  "max_retries": 3,
  "test_command": "bun test",
  "curl_tests_enabled": true,
  "api_base_url": "http://localhost:3000",
  "auto_document": true,
  "task_source": {
    "type": "notion",
    "config": {
      "database_id": "NOTION_DB_ID_FOR_API_TICKETS"
    }
  }
}
```

### Example: Web Frontend (`configs/web-frontend.json`)

```json
{
  "project_name": "web-frontend",
  "project_dir": "/home/dev/repos/web-frontend",
  "engine": "claude-code",
  "base_branch": "main",
  "branch_prefix": "feat",
  "auto_pr": true,
  "max_retries": 3,
  "test_command": "npm run test:ci",
  "curl_tests_enabled": false,
  "auto_document": true,
  "task_source": {
    "type": "linear",
    "config": {
      "team_key": "FE",
      "project_name": "Web App v3"
    }
  }
}
```

### Example: Admin Dashboard (`configs/admin-dashboard.json`)

```json
{
  "project_name": "admin-dashboard",
  "project_dir": "/home/dev/repos/admin-dashboard",
  "engine": "aider",
  "base_branch": "develop",
  "branch_prefix": "feat",
  "auto_pr": true,
  "max_retries": 2,
  "test_command": "vitest run",
  "curl_tests_enabled": false,
  "auto_document": true,
  "task_source": {
    "type": "github",
    "config": {
      "repo": "your-org/admin-dashboard",
      "label": "tasklot"
    }
  }
}
```

Notice each project can use a different engine, different task source, different test runner, and different base branch. The pipeline is the same — only the configuration changes.

---

## Running in Parallel

### Basic: Background Processes

The simplest approach — run each project in the background:

```bash
# Pull tasks for all projects
./pull-tasks.sh --config configs/api-backend.json
./pull-tasks.sh --config configs/web-frontend.json
./pull-tasks.sh --config configs/admin-dashboard.json

# Run all three in parallel
./tasklot.sh --config configs/api-backend.json &
./tasklot.sh --config configs/web-frontend.json &
./tasklot.sh --config configs/admin-dashboard.json &

# Wait for all to complete
wait

echo "All projects complete."
```

### Better: Using tmux for Visibility

tmux lets you watch all pipelines simultaneously in split panes:

```bash
# Create a new tmux session
tmux new-session -d -s tasklot

# Pane 1: API Backend
tmux send-keys './tasklot.sh --config configs/api-backend.json' C-m

# Pane 2: Web Frontend
tmux split-window -h
tmux send-keys './tasklot.sh --config configs/web-frontend.json' C-m

# Pane 3: Admin Dashboard
tmux split-window -v
tmux send-keys './tasklot.sh --config configs/admin-dashboard.json' C-m

# Attach to watch them all
tmux attach -t tasklot
```

This gives you a split-screen terminal where you can watch all three pipelines executing in real time. Perfect for demo videos.

### Advanced: GNU Parallel

For running many projects (5+), GNU Parallel handles the orchestration:

```bash
# Create a list of configs
ls configs/*.json > /tmp/project-configs.txt

# Pull all tasks first
cat /tmp/project-configs.txt | parallel './pull-tasks.sh --config {}'

# Run all projects with max 3 concurrent
cat /tmp/project-configs.txt | parallel -j 3 './tasklot.sh --config {}'
```

The `-j 3` flag limits concurrency to 3 simultaneous runs, which prevents API rate limit issues.

---

## Shared vs Isolated Agents

### Shared Agents (Approach A)

When projects share conventions, use the same agent files. Your tickets in different projects can reference the same agent:

```
# Ticket in API project
read nestjs-backend.agent.md

Build the payment webhook handler...

# Ticket in Admin project (same agent, different task)
read nestjs-backend.agent.md

Build the admin override endpoint for refunds...
```

Shared agents make sense when:
- Multiple projects use the same framework and patterns
- You want consistency across projects
- One team maintains all projects

### Isolated Agents

When projects have different conventions, create project-specific agents. You can namespace them:

```
agents/
├── git-operations.agent.md                # Shared across all
├── api--nestjs-backend.agent.md           # API project only
├── web--react-frontend.agent.md           # Web project only
├── admin--vue-dashboard.agent.md          # Admin project only
└── mobile--react-native.agent.md          # Mobile project only
```

Your tickets reference the project-specific agent:

```
# In API tickets
read api--nestjs-backend.agent.md

# In Web tickets
read web--react-frontend.agent.md
```

### Hybrid: Shared Foundation + Project Overrides

The most powerful approach. Create a base agent with shared conventions, then project-specific agents that reference it:

```markdown
# Agent: API Backend Developer

## Foundation
Follow all conventions in `shared-typescript.agent.md`.

## Project-Specific Overrides
- Framework: NestJS 10 (not Express)
- ORM: TypeORM with PostgreSQL
- Auth: JWT with RS256
...
```

The AI engine reads both files when they're referenced together in the task description:

```
read shared-typescript.agent.md
read api--nestjs-backend.agent.md

Build the notification queue processor...
```

---

## Resource Management

### API Rate Limits

Running multiple projects simultaneously means multiple AI engine calls in parallel. Be aware of rate limits:

| Engine | Typical Rate Limit | Recommendation |
|--------|-------------------|----------------|
| Claude Code | ~60 requests/min | Max 2-3 concurrent projects |
| Aider (Anthropic API) | Depends on tier | Check your API tier limits |
| Aider (OpenAI API) | Depends on tier | Check your API tier limits |
| Codex | Varies | Check OpenAI usage limits |

If you hit rate limits, reduce concurrency or stagger project starts:

```bash
# Stagger by 5 minutes
./tasklot.sh --config configs/api-backend.json &
sleep 300
./tasklot.sh --config configs/web-frontend.json &
sleep 300
./tasklot.sh --config configs/admin-dashboard.json &
```

### CPU and Memory

Each TaskLot run is lightweight (bash + jq), but the AI engine and test suites consume resources. If running test suites for multiple projects:

- Make sure each project uses a different port for its dev server (for curl tests)
- Watch memory if running heavy test suites in parallel
- Consider running `--dry-run` for all projects first to estimate total task count

### Database Conflicts

If multiple projects share a local database (e.g., a dev PostgreSQL instance), ensure each project uses a separate database name:

```
# api-backend .env
DATABASE_URL=postgresql://localhost:5432/api_dev

# admin-dashboard .env
DATABASE_URL=postgresql://localhost:5432/admin_dev
```

---

## Monitoring Multiple Runs

### Log Files

Each run produces its own timestamped log in `logs/`. With multiple projects, the project name helps identify which log belongs to which run:

```
logs/
├── tasklot_20260329_140000.log    # api-backend
├── tasklot_20260329_140001.log    # web-frontend
├── tasklot_20260329_140002.log    # admin-dashboard
```

To make this clearer, you can symlink or rename logs after the run. Or tail them live:

```bash
# Watch all logs in real time
tail -f logs/tasklot_*.log
```

### Quick Status Check

After all runs complete, check `tasks.json` for each project to see results:

```bash
# Summary across all projects
for config in configs/*.json; do
  project=$(jq -r '.project_name' "$config")
  tasks_file="tasks_${project}.json"
  if [[ -f "$tasks_file" ]]; then
    done=$(jq '[.tasks[] | select(.status == "done")] | length' "$tasks_file")
    failed=$(jq '[.tasks[] | select(.status == "failed")] | length' "$tasks_file")
    pending=$(jq '[.tasks[] | select(.status == "pending")] | length' "$tasks_file")
    echo "${project}: ✔ ${done} done, ✖ ${failed} failed, ○ ${pending} pending"
  fi
done
```

### PR Dashboard

After all runs, check PRs created across all repos:

```bash
# List all open PRs across your repos
gh pr list --repo your-org/api-backend --state open
gh pr list --repo your-org/web-frontend --state open
gh pr list --repo your-org/admin-dashboard --state open
```

---

## Orchestrating with a Meta-Script

For regular multi-project runs, create a meta-script that handles the full workflow:

### `run-all.sh`

```bash
#!/usr/bin/env bash
###############################################################################
#  TaskLot Meta-Orchestrator — Run all projects
###############################################################################

set -euo pipefail

TASKLOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGS_DIR="${TASKLOT_DIR}/configs"
MAX_PARALLEL="${1:-3}"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

echo -e "${CYAN}${BOLD}"
echo "  ┌─────────────────────────────────────────────┐"
echo "  │      ⚡ TaskLot Multi-Project Runner ⚡      │"
echo "  └─────────────────────────────────────────────┘"
echo -e "${RESET}"

# Collect all configs
CONFIGS=($(ls "${CONFIGS_DIR}"/*.json 2>/dev/null))

if [[ ${#CONFIGS[@]} -eq 0 ]]; then
  echo -e "${RED}No configs found in ${CONFIGS_DIR}/${RESET}"
  exit 1
fi

echo -e "${CYAN}Found ${#CONFIGS[@]} projects:${RESET}"
for config in "${CONFIGS[@]}"; do
  name=$(jq -r '.project_name' "$config")
  engine=$(jq -r '.engine' "$config")
  echo -e "  ${BOLD}${name}${RESET} (engine: ${engine}, config: $(basename $config))"
done
echo ""

# Phase 1: Pull all tasks
echo -e "${CYAN}${BOLD}Phase 1: Pulling tasks for all projects...${RESET}"
echo ""
for config in "${CONFIGS[@]}"; do
  name=$(jq -r '.project_name' "$config")
  echo -e "  Pulling: ${BOLD}${name}${RESET}..."
  "${TASKLOT_DIR}/pull-tasks.sh" --config "$config" > /dev/null 2>&1
  task_count=$(jq '.tasks | length' "${TASKLOT_DIR}/tasks.json" 2>/dev/null || echo "0")
  echo -e "  ${GREEN}✔ ${name}: ${task_count} tasks${RESET}"

  # Copy tasks.json per project to avoid overwriting
  cp "${TASKLOT_DIR}/tasks.json" "${TASKLOT_DIR}/tasks_${name}.json"
done
echo ""

# Phase 2: Dry run (optional)
read -p "Run dry-run first? (y/N) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
  for config in "${CONFIGS[@]}"; do
    name=$(jq -r '.project_name' "$config")
    echo -e "${CYAN}Dry run: ${name}${RESET}"
    "${TASKLOT_DIR}/tasklot.sh" --config "$config" --dry-run 2>&1 | tail -5
    echo ""
  done

  read -p "Proceed with execution? (y/N) " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
  fi
fi

# Phase 3: Execute in parallel
echo -e "${CYAN}${BOLD}Phase 2: Executing all projects (max ${MAX_PARALLEL} parallel)...${RESET}"
echo ""

PIDS=()
NAMES=()

for config in "${CONFIGS[@]}"; do
  name=$(jq -r '.project_name' "$config")

  # Wait if we've hit the concurrency limit
  while [[ ${#PIDS[@]} -ge $MAX_PARALLEL ]]; do
    for i in "${!PIDS[@]}"; do
      if ! kill -0 "${PIDS[$i]}" 2>/dev/null; then
        wait "${PIDS[$i]}" 2>/dev/null
        echo -e "  ${GREEN}✔ ${NAMES[$i]} finished${RESET}"
        unset 'PIDS[$i]'
        unset 'NAMES[$i]'
        PIDS=("${PIDS[@]}")
        NAMES=("${NAMES[@]}")
        break
      fi
    done
    sleep 5
  done

  echo -e "  ▶ Starting: ${BOLD}${name}${RESET}"
  "${TASKLOT_DIR}/tasklot.sh" --config "$config" &
  PIDS+=($!)
  NAMES+=("$name")

  # Stagger starts by 10 seconds to avoid API burst
  sleep 10
done

# Wait for remaining
for i in "${!PIDS[@]}"; do
  wait "${PIDS[$i]}" 2>/dev/null
  echo -e "  ${GREEN}✔ ${NAMES[$i]} finished${RESET}"
done

echo ""
echo -e "${GREEN}${BOLD}All projects complete.${RESET}"
```

Usage:

```bash
# Run all projects, max 3 concurrent
./run-all.sh 3

# Run all projects, max 2 concurrent
./run-all.sh 2
```

---

## Real-World Scenarios

### Scenario 1: SaaS Product with Separate Repos

You're building a SaaS with a NestJS API, React frontend, and a React Native mobile app. Each lives in its own repo.

```
configs/
├── saas-api.json          → points to ~/repos/saas-api
├── saas-web.json          → points to ~/repos/saas-web
└── saas-mobile.json       → points to ~/repos/saas-mobile

agents/
├── git-operations.agent.md
├── nestjs-api.agent.md
├── react-web.agent.md
└── react-native.agent.md
```

Notion has three separate databases — one per project. Each with tickets referencing the appropriate agent.

You fire off all three. The API gets 8 endpoints built, the web gets 5 pages built, the mobile gets 3 screens built. All in parallel. You come back to 16 PRs across three repos.

### Scenario 2: Agency with Multiple Client Projects

You're an agency or freelancer with four client projects, each with different stacks:

```
configs/
├── client-a-django.json      → Python/Django
├── client-b-rails.json       → Ruby/Rails
├── client-c-nextjs.json      → Next.js
└── client-d-laravel.json     → PHP/Laravel

agents/
├── git-operations.agent.md
├── django-developer.agent.md
├── rails-developer.agent.md
├── nextjs-developer.agent.md
└── laravel-developer.agent.md
```

Each client has their own Jira board. You pull tickets from all four, run TaskLot across all four in parallel, and deliver features to all clients simultaneously.

### Scenario 3: Feature Sync Across Services

You need to add "notifications" across your API, web app, and mobile app. The tickets are coordinated:

```
API tickets:     TASK-001: Build notification endpoints
                 TASK-002: Build notification WebSocket gateway

Web tickets:     TASK-001: Build notification dropdown component
                 TASK-002: Build notification settings page

Mobile tickets:  TASK-001: Build push notification handler
                 TASK-002: Build notification list screen
```

Run all three in parallel. Each project implements its part of the notification feature independently, guided by its own agent. The end result: a complete notification system across all surfaces, built simultaneously.

---

## Troubleshooting

**Tasks file getting overwritten between projects**
If using Approach A (single installation), each `pull-tasks.sh` call overwrites `tasks.json`. Solution: use the `--output` flag or copy the file immediately after pulling:

```bash
./pull-tasks.sh --config configs/api.json
cp tasks.json tasks_api.json

./pull-tasks.sh --config configs/web.json
cp tasks.json tasks_web.json
```

Or use the meta-script which handles this automatically.

**API rate limits hit**
Reduce `MAX_PARALLEL` in the meta-script, or increase the stagger delay between starts. Claude Code has per-minute rate limits — spreading starts across 30-60 seconds usually resolves this.

**Port conflicts for curl tests**
Each project's dev server must run on a different port. Set `api_base_url` accordingly:

```json
// api-backend.json
"api_base_url": "http://localhost:3000"

// admin-dashboard.json
"api_base_url": "http://localhost:3001"
```

**Git authentication issues**
Ensure `gh auth login` is done and your SSH keys are configured for all repos. Test with:

```bash
gh pr list --repo your-org/repo-name
```

If this works for all repos, TaskLot will too.

**Different engines failing differently**
If one project uses `claude-code` and another uses `aider`, they have different failure modes. Check the project-specific log file for the failing project. Engine issues are always logged with full output.
