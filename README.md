# ⚡ TaskLot

**Autonomous AI-Powered Task Execution Pipeline**

TaskLot reads your tickets, writes the code, validates it against your architecture, runs all tests, creates PRs, and documents everything — then picks up the next ticket and does it again. Fully autonomous. Stack-agnostic. Engine-pluggable.

You define the architecture. You write the tickets. TaskLot builds it.

---

## Table of Contents

- [How It Works](#how-it-works)
- [Architecture Overview](#architecture-overview)
- [Folder Structure](#folder-structure)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Agents](#agents)
- [Engines](#engines)
- [Task Format](#task-format)
- [The Execution Loop](#the-execution-loop)
- [The QA Pipeline](#the-qa-pipeline)
- [Stacked Branches](#stacked-branches)
- [Notion Integration](#notion-integration)
- [CLI Reference](#cli-reference)
- [Logging](#logging)
- [Requirements](#requirements)
- [Tips & Best Practices](#tips--best-practices)
- [FAQ](#faq)
- [License](#license)

---

## How It Works

```
 ┌──────────────────────────────────────────────────────────────────────┐
 │                        PHASE 1: PREPARATION                        │
 └──────────────────────────────────────────────────────────────────────┘

 ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
 │   Notion      │────▶│ pull-tasks.sh│────▶│  tasks.json  │
 │   Board       │     │              │     │              │
 └──────────────┘     └──────────────┘     └──────────────┘
                                                  │
           You review, reorder, approve           │
                                                  ▼
 ┌──────────────────────────────────────────────────────────────────────┐
 │                     PHASE 2: EXECUTION LOOP                         │
 └──────────────────────────────────────────────────────────────────────┘

                                           ┌──────────────┐
                                           │   tasklot.sh  │
                                           │               │◀── config.json
                                           │  Pick Task #1 │◀── engines/{engine}.sh
                                           └──────┬───────┘
                                                  │
                    ┌─────────────────────────────┼──────────────────────┐
                    ▼                             ▼                      ▼
             ┌──────────────┐            ┌──────────────┐       ┌──────────────┐
             │ Read Agent    │            │ Resolve Source│       │   Execute    │
             │ Context       │            │ Branch        │       │   Task via   │
             │ (.agent.md)   │            │ (main or      │       │   AI Engine  │
             └──────────────┘            │  stacked)     │       └──────┬───────┘
                                          └──────────────┘              │
                                                                        ▼
              ┌─────────────────────────────────────────────────────────────┐
              │                  PHASE 3: VALIDATION GATES                 │
              │                                                             │
              │  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐│
              │  │ Gate 1: QA     │  │ Gate 2: Test   │  │ Gate 3: Curl   ││
              │  │ Architecture   │─▶│ Suite          │─▶│ API Tests      ││
              │  │ Conformance    │  │                │  │                ││
              │  └────────────────┘  └────────────────┘  └────────────────┘│
              └────────────────────────────┬────────────────────────────────┘
                                           │
                                    Pass? ─┤
                                    │      │
                                 No ▼    Yes ▼
                             ┌──────────┐  ┌─────────────────────────────────┐
                             │ Fix &    │  │  Git Agent: Commit → Push → PR  │
                             │ Retry    │  │  Document solution to Notion     │
                             │ (max 3)  │  │  Mark task done                  │
                             └──────────┘  │  → Pick next task, repeat        │
                                           └─────────────────────────────────┘

 ┌──────────────────────────────────────────────────────────────────────┐
 │                       PHASE 4: SUMMARY REPORT                       │
 │                                                                      │
 │   Completed: 8  │  Failed: 1  │  Duration: 47m 12s  │  Log: ✔      │
 └──────────────────────────────────────────────────────────────────────┘
```

---

## Architecture Overview

TaskLot is built around three core design principles:

### 1. Stack-Agnostic

The orchestrator (`tasklot.sh`) knows nothing about your tech stack. It doesn't care if you're building a NestJS API, a Django backend, a React frontend, or a Rust CLI tool. All stack-specific knowledge lives in **agent files** that you create per project.

### 2. Engine-Pluggable

The AI tool that writes the code is swappable. Claude Code today, Aider tomorrow, Codex next week — change one config value and the pipeline works the same. Each engine is a tiny shell script (~20 lines) that wraps the AI tool's CLI.

### 3. Agent-Driven

Every operation is guided by agent context files:

- **Task agents** (e.g. `backend-developer.agent.md`) tell the AI engine *how* to build — architecture, patterns, conventions, stack details.
- **Git operations agent** (`git-operations.agent.md`) controls branching, commit messages, and PR descriptions.
- **QA agent** (`qa/qa-agent.md`) defines the quality standards everything is validated against.

The result: TaskLot is a **framework**, not a tool tied to one stack or one AI provider. You bring the context, TaskLot runs the loop.

---

## Folder Structure

```
tasklot/
│
├── tasklot.sh                    # Main orchestrator — the execution loop
│                                 # Reads tasks, delegates to engines, runs QA,
│                                 # handles git via agent, retries on failure,
│                                 # produces summary report.
│                                 # This is the only file you run.
│
├── pull-tasks.sh                 # Notion → tasks.json converter
│                                 # Connects to Notion via Claude Code MCP,
│                                 # fetches all tickets from your board,
│                                 # generates a local tasks.json snapshot.
│                                 # Run this before tasklot.sh.
│
├── config.json                   # Project-level configuration
│                                 # Engine selection, repo path, branch settings,
│                                 # test commands, API URLs, Notion DB ID.
│                                 # One config per project.
│
├── tasks.json                    # Generated task queue (auto-created)
│                                 # Created by pull-tasks.sh or manually.
│                                 # TaskLot reads from this, marks tasks done/failed
│                                 # as it progresses. Do not edit while running.
│
├── tasks.example.json            # Example tasks file
│                                 # Shows the expected JSON schema with sample
│                                 # tickets referencing different agents.
│
├── engines/                      # Pluggable AI coding engines
│   │                             # Each file wraps one AI tool's CLI.
│   │                             # tasklot.sh sources the active engine and calls
│   │                             # execute_task() — that's the only contract.
│   │
│   ├── claude-code.sh            # Engine: Claude Code CLI
│   │                             # Wraps `claude -p` for non-interactive execution.
│   │                             # Best for autonomous workflows with MCP support.
│   │
│   ├── aider.sh                  # Engine: Aider
│   │                             # Wraps `aider --message` with --yes-always.
│   │                             # Good for git-aware coding with auto-commits off.
│   │
│   ├── codex.sh                  # Engine: OpenAI Codex CLI
│   │                             # Wraps `codex --approval-mode full-auto`.
│   │                             # Full autonomy mode for OpenAI's agent.
│   │
│   └── custom.sh                 # Engine: Template for your own
│                                 # Copy this, implement execute_task(), done.
│                                 # Any CLI tool that accepts a prompt works.
│
├── agents/                       # Agent context files (bring your own)
│   │                             # Each file defines a role's full context:
│   │                             # tech stack, architecture, patterns, naming
│   │                             # conventions, file structure, testing approach.
│   │                             # TaskLot ships with the git agent only —
│   │                             # you create the rest based on your project.
│   │
│   ├── git-operations.agent.md   # DEFAULT: Git operations agent
│   │                             # Used internally by TaskLot for ALL git work:
│   │                             # branch naming, conventional commits, PR
│   │                             # descriptions, stacked branch handling.
│   │                             # Customise this to match your team's workflow.
│   │
│   └── README.md                 # Guide to creating your own agent files
│                                 # Explains what to include, naming convention,
│                                 # and how agents connect to tickets.
│
├── qa/                           # Quality assurance
│   └── qa-agent.md               # Universal QA rules
│                                 # Runs after every task implementation.
│                                 # Checks code quality, security, error handling,
│                                 # naming, structure, and test coverage.
│                                 # Can also reference the task's agent file for
│                                 # stack-specific validation.
│
├── logs/                         # Execution logs (auto-created)
│                                 # One log file per run, timestamped.
│                                 # Contains full engine output, QA results,
│                                 # test output, and error details.
│                                 # Format: tasklot_YYYYMMDD_HHMMSS.log
│
├── .gitignore                    # Ignores logs/, tasks.json, *.log
│
└── README.md                     # This file
```

### Example with user-created agents:

When working on a full-stack project, your agents folder might look like:

```
agents/
├── git-operations.agent.md           # Ships with TaskLot (customise per team)
├── backend-developer.agent.md        # Your NestJS/Express/Django standards
├── frontend-developer.agent.md       # Your React/Vue/Svelte conventions
├── ai-ml-developer.agent.md          # Your ML pipeline patterns
├── devops-engineer.agent.md          # Your infra and CI/CD standards
├── mobile-developer.agent.md         # Your React Native/Flutter setup
└── README.md                         # Guide (ships with TaskLot)
```

---

## Quick Start

### 1. Clone & Configure

```bash
git clone https://github.com/your-username/tasklot.git
cd tasklot
chmod +x tasklot.sh pull-tasks.sh engines/*.sh
```

Edit `config.json` with your project details:

```json
{
  "project_name": "my-saas-app",
  "project_dir": "/home/dev/my-saas-app",
  "engine": "claude-code",
  "base_branch": "main",
  "branch_prefix": "feat",
  "auto_pr": true,
  "max_retries": 3,
  "test_command": "npm test",
  "curl_tests_enabled": true,
  "api_base_url": "http://localhost:3000",
  "auto_document": true,
  "notion": {
    "enabled": true,
    "database_id": "YOUR_NOTION_DATABASE_ID",
    "status_field": "Status",
    "agent_field_in_description": true
  }
}
```

### 2. Create Your Agent Files

This is the most important step. Your agent files capture everything the AI needs to know about your project's architecture, conventions, and standards.

```bash
vi agents/backend-developer.agent.md
```

A good agent file covers:

- **Identity** — what this agent is responsible for
- **Tech stack** — language, framework, runtime, database, ORM, key libraries
- **Architecture** — folder structure, design patterns, module organisation
- **Coding standards** — naming conventions, error handling, logging, imports
- **API conventions** — route patterns, request/response format, status codes (for backend)
- **Component standards** — structure, state management, styling (for frontend)
- **Testing** — framework, what to test, naming, coverage expectations

See `agents/README.md` for a detailed guide.

### 3. Set Up Your Notion Tickets

Each ticket's description starts with an agent reference, telling TaskLot which agent context to load:

```
read backend-developer.agent.md

Build the user authentication system:
- POST /auth/register — register new user (email, password, name)
- POST /auth/login — login with email/password, return JWT
- POST /auth/refresh — refresh expired token
- GET /auth/me — get current user profile (protected)
- Password hashing with bcrypt
- JWT token generation and validation
- Input validation on all endpoints
```

The first line (`read backend-developer.agent.md`) is the agent reference. Everything after is the task specification.

### 4. Pull Tasks from Notion

```bash
./pull-tasks.sh
```

This connects to Notion via Claude Code MCP, fetches all tickets, and generates `tasks.json`. You'll see a preview:

```
  ⚡ TaskLot — Notion Pull ⚡

  [○] TASK-001 — Setup project boilerplate (high)
  [○] TASK-002 — Implement user authentication (high)
  [○] TASK-003 — Build dashboard UI components (medium)

  Ready to run: ./tasklot.sh
```

Review the order. Reorder in `tasks.json` if needed.

### 5. Run TaskLot

```bash
# Execute all pending tasks
./tasklot.sh

# Dry run — preview what would happen without executing
./tasklot.sh --dry-run

# Run a single specific task
./tasklot.sh --task TASK-002

# Use a different config file
./tasklot.sh --config projects/my-other-project.json
```

### 6. Watch It Work

TaskLot will:

1. Pick the first pending task
2. Load the referenced agent context
3. Create a git branch (stacked if previous task's PR is unmerged)
4. Implement the task using your chosen AI engine
5. Run the three QA validation gates
6. Fix and retry if anything fails (up to 3 attempts)
7. Commit with conventional commits, push, create PR
8. Document the solution back on the Notion ticket
9. Move to the next task and repeat

When complete, you get a summary:

```
  ⚡ TaskLot Execution Summary
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Completed: 8
  Failed:    1
  Duration:  47m 12s
  Log:       logs/tasklot_20260329_141500.log
```

---

## Configuration

`config.json` controls all project-level settings. Here's every field:

```json
{
  "project_name": "my-project",
  "project_dir": "/absolute/path/to/your/repo",
  "engine": "claude-code",
  "base_branch": "main",
  "branch_prefix": "feat",
  "auto_pr": true,
  "max_retries": 3,
  "test_command": "npm test",
  "curl_tests_enabled": true,
  "api_base_url": "http://localhost:3000",
  "auto_document": true,
  "notion": {
    "enabled": true,
    "database_id": "YOUR_NOTION_DATABASE_ID",
    "status_field": "Status",
    "agent_field_in_description": true
  }
}
```

### Field Reference


| Field                               | Type    | Default                   | Description                                                                                                                                                      |
| ------------------------------------- | --------- | --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `project_name`                      | string  | —                        | Human-readable project name (used in logs)                                                                                                                       |
| `project_dir`                       | string  | `"."`                     | Absolute path to your project's git repo. All git operations and code execution happen here.                                                                     |
| `engine`                            | string  | `"claude-code"`           | Which AI engine to use. Must match a filename in`engines/` (without `.sh`). Options: `claude-code`, `aider`, `codex`, `custom`, or any custom engine you create. |
| `base_branch`                       | string  | `"main"`                  | The default branch PRs target. Also the branch TaskLot pulls from before creating feature branches (unless stacking).                                            |
| `branch_prefix`                     | string  | `"feat"`                  | Fallback prefix for branch names if the git agent doesn't generate one. The git agent typically overrides this with proper conventional prefixes.                |
| `auto_pr`                           | boolean | `true`                    | Whether to automatically create GitHub PRs after successful validation. Set to`false` if you prefer to review locally first.                                     |
| `max_retries`                       | number  | `3`                       | How many times TaskLot will attempt to fix and re-validate a task before marking it as failed and moving on.                                                     |
| `test_command`                      | string  | `""`                      | The shell command to run your test suite. Examples:`"npm test"`, `"bun test"`, `"pytest"`, `"go test ./..."`, `"cargo test"`. Leave empty to skip the test gate. |
| `curl_tests_enabled`                | boolean | `false`                   | Enable Gate 3 — dynamic curl-based API endpoint testing. Only relevant for backend/API tasks.                                                                   |
| `api_base_url`                      | string  | `"http://localhost:3000"` | Base URL for curl tests. Your server must be running at this URL during execution.                                                                               |
| `auto_document`                     | boolean | `true`                    | Whether to post implementation documentation back to the Notion ticket after task completion.                                                                    |
| `notion.enabled`                    | boolean | `true`                    | Enable Notion integration for pulling tasks and posting documentation.                                                                                           |
| `notion.database_id`                | string  | —                        | Your Notion database ID. Find it in the Notion URL:`notion.so/{workspace}/{database_id}`.                                                                        |
| `notion.status_field`               | string  | `"Status"`                | The name of the status property in your Notion database. Used to map ticket statuses to TaskLot statuses.                                                        |
| `notion.agent_field_in_description` | boolean | `true`                    | Whether agent references are embedded in ticket descriptions (the`read xxx.agent.md` pattern).                                                                   |

### Multiple Projects

Maintain separate configs for different projects:

```bash
./tasklot.sh --config configs/saas-backend.json
./tasklot.sh --config configs/mobile-app.json
./tasklot.sh --config configs/ml-pipeline.json
```

## Configuration

`config.json` — all settings for your project:


| Key                  | Description                                                  | Default                 |
| ---------------------- | -------------------------------------------------------------- | ------------------------- |
| `project_name`       | Your project name                                            | —                      |
| `project_dir`        | Absolute path to your project repo                           | —                      |
| `engine`             | AI engine to use (`claude-code`, `aider`, `codex`, `custom`) | `claude-code`           |
| `base_branch`        | Branch to create PRs against                                 | `main`                  |
| `branch_prefix`      | Prefix for feature branches                                  | `feat`                  |
| `auto_pr`            | Automatically create GitHub PRs                              | `true`                  |
| `max_retries`        | Max validation retry attempts per task                       | `3`                     |
| `test_command`       | Command to run your test suite                               | `""`                    |
| `curl_tests_enabled` | Enable deep API curl testing                                 | `false`                 |
| `api_base_url`       | Base URL for curl tests                                      | `http://localhost:3000` |
| `auto_document`      | Post implementation docs to Notion                           | `true`                  |
| `notion.enabled`     | Enable Notion integration                                    | `true`                  |
| `notion.database_id` | Your Notion database ID                                      | —                      |

## Agents

Agents are markdown files that give the AI engine full context about how to work. They are the most important part of TaskLot — the quality of your agent files directly determines the quality of the output.

### Types of Agents


| Agent Type                               | Purpose                                                      | Used By                                   |
| ------------------------------------------ | -------------------------------------------------------------- | ------------------------------------------- |
| **Task agents** (you create)             | Define tech stack, architecture, coding standards for a role | The AI engine during task implementation  |
| **Git operations agent** (ships default) | Define branching, commit, and PR conventions                 | TaskLot internally for all git operations |
| **QA agent** (ships default)             | Define quality standards and validation rules                | TaskLot after each task for validation    |

### How Task Agents Connect to Tickets

The first line of each Notion ticket's description references the agent:

```
read backend-developer.agent.md

Build the payment processing module:
- POST /payments/charge
- POST /payments/refund
- Stripe integration via provider interface
...
```

TaskLot parses this line, loads `agents/backend-developer.agent.md`, and feeds its contents to the AI engine alongside the task description. Supported reference patterns:

```
read backend-developer.agent.md
use frontend-developer.agent.md
load ai-ml-developer.agent.md
agent: devops-engineer.agent.md
```

### Naming Convention

```
{role}.agent.md
```

The `.agent.md` suffix is required — TaskLot uses it to identify agent files.

### What to Include in a Task Agent

Recommended structure:

```markdown
# Agent: {Role Name}

## Identity
What this agent is responsible for and what it does NOT handle.

## Tech Stack
- Language & runtime (e.g. TypeScript 5.x, Node 20, Bun)
- Framework (e.g. NestJS 10, Express, Django 5)
- Database (e.g. PostgreSQL 16 via TypeORM)
- Key libraries with versions

## Architecture
- Folder structure (draw the actual tree)
- Design patterns (repository pattern, service layer, etc.)
- Module/feature organisation
- Dependency injection approach

## Coding Standards
- File naming: kebab-case, PascalCase, etc.
- Variable/function naming conventions
- Import ordering rules
- Error handling patterns
- Logging standards

## API Conventions (backend agents)
- Route naming: /resource/:id/sub-resource
- Request/response envelope format
- Status codes and when to use each
- Pagination, filtering, sorting patterns
- Authentication/authorization approach

## Component Standards (frontend agents)
- Component file structure
- State management (Redux, Zustand, etc.)
- Styling approach (Tailwind, CSS Modules, etc.)
- Accessibility requirements

## Testing
- Test framework (Jest, Vitest, Pytest, etc.)
- What to test vs what not to test
- Test file naming and location
- Minimum coverage expectations
```

### Customising the Git Operations Agent

The default `git-operations.agent.md` ships with sensible conventions (conventional commits, proper branch naming, structured PR descriptions, stacked branch handling). Customise it for your team:

```bash
vi agents/git-operations.agent.md
```

Things you might change:

- Branch naming scopes (to match your monorepo or module structure)
- Commit scope names (to match your codebase areas)
- PR description template (to match your team's review process)
- Stacked PR conventions

### Customising the QA Agent

The QA agent in `qa/qa-agent.md` defines universal quality rules. Customise it to add project-specific checks:

```bash
vi qa/qa-agent.md
```

The QA agent automatically loads the same task agent that was used during implementation, so it can validate stack-specific conventions without you duplicating rules.

---

## Engines

TaskLot delegates all code generation to a pluggable AI engine. The engine is a shell script that implements one function: `execute_task()`.

### Available Engines


| Engine      | Config Value    | AI Tool          | Install Command                      |
| ------------- | ----------------- | ------------------ | -------------------------------------- |
| Claude Code | `"claude-code"` | Claude Code CLI  | `npm i -g @anthropic-ai/claude-code` |
| Aider       | `"aider"`       | Aider            | `pip install aider-chat`             |
| Codex       | `"codex"`       | OpenAI Codex CLI | `npm i -g @openai/codex`             |
| Custom      | `"custom"`      | Your tool        | Copy`engines/custom.sh`              |

### Switching Engines

Change one value in `config.json`:

```json
{ "engine": "aider" }
```

That's it. The entire pipeline works the same — only the AI tool changes.

### Creating a Custom Engine

```bash
cp engines/custom.sh engines/my-tool.sh
```

Implement two functions:

```bash
check_engine() {
  # Verify the tool is installed
  if ! command -v my-tool &>/dev/null; then
    echo "Error: my-tool not found"
    exit 1
  fi
}

execute_task() {
  local prompt="$1"      # The full prompt (agent context + task)
  local work_dir="$2"    # The project directory

  check_engine
  cd "$work_dir"

  # Call your AI tool and output the result to stdout
  my-tool --prompt "$prompt" 2>&1
}
```

Set it in config:

```json
{ "engine": "my-tool" }
```

### Engine Contract

Every engine must:

1. Accept a prompt string as `$1` and a working directory as `$2`
2. Execute the prompt using the AI tool in the given directory
3. Output the result to stdout
4. Return exit code 0 on success

The engine does NOT handle git, testing, QA, or PR creation — only code generation.

---

## Task Format

Tasks live in `tasks.json` — either generated by `pull-tasks.sh` from Notion or created manually.

### Schema

```json
{
  "pulled_at": "2026-03-29T12:00:00Z",
  "source": "notion",
  "database_id": "your-notion-db-id",
  "tasks": [
    {
      "id": "TASK-001",
      "title": "Short descriptive title",
      "description": "read backend-developer.agent.md\n\nFull task specification...",
      "status": "pending",
      "priority": "high",
      "notion_page_id": "notion-page-uuid",
      "completed_at": null,
      "failure_reason": null
    }
  ]
}
```

### Field Reference


| Field            | Type        | Description                                                                                                                         |
| ------------------ | ------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `id`             | string      | Unique task identifier (e.g.`TASK-001`). Used in branch names and commit messages.                                                  |
| `title`          | string      | Short task title. Used in PR titles and commit messages.                                                                            |
| `description`    | string      | Full task specification. First line should be the agent reference (`read xxx.agent.md`), followed by the detailed task description. |
| `status`         | string      | One of:`pending`, `done`, `failed`. TaskLot updates this as it progresses.                                                          |
| `priority`       | string      | `high`, `medium`, or `low`. Informational — TaskLot executes in array order.                                                       |
| `notion_page_id` | string      | The Notion page UUID. Used for posting documentation back to the ticket.                                                            |
| `completed_at`   | string/null | ISO timestamp set when the task completes successfully.                                                                             |
| `failure_reason` | string/null | Error description set when the task fails after max retries.                                                                        |

### Task Execution Order

Tasks execute in the order they appear in the `tasks[]` array. To change execution order, reorder the array in `tasks.json` before running TaskLot.

Tasks with `status: "done"` or `status: "failed"` are skipped.

### Manual Task Creation

You don't need Notion. Create `tasks.json` manually:

```json
{
  "pulled_at": "2026-03-29T12:00:00Z",
  "source": "manual",
  "tasks": [
    {
      "id": "TASK-001",
      "title": "Setup Express server with TypeScript",
      "description": "read backend-developer.agent.md\n\nInitialise the project with:\n- Express + TypeScript boilerplate\n- ESLint + Prettier\n- Health check endpoint at GET /health\n- Error handling middleware",
      "status": "pending",
      "priority": "high",
      "notion_page_id": "",
      "completed_at": null,
      "failure_reason": null
    }
  ]
}
```

---

## The Execution Loop

Here's exactly what happens for each task, in order:

### Step 1: Load Task

TaskLot reads the next pending task from `tasks.json`.

### Step 2: Extract Agent

The task description is parsed for an agent reference (e.g. `read backend-developer.agent.md`). If found, the agent file is loaded from `agents/`. The agent reference line is stripped from the description before passing to the engine.

### Step 3: Resolve Source Branch

TaskLot determines which branch to create the feature branch from:

- If there's no previous task → branch from `main`
- If the previous task's branch PR is merged → branch from `main`
- If the previous task's branch PR is unmerged → **stack** on the previous branch

See [Stacked Branches](#stacked-branches) for details.

### Step 4: Create Branch

The git operations agent creates a properly named branch following conventional naming patterns from `agents/git-operations.agent.md`.

### Step 5: Implement

The AI engine receives the full agent context + task description and implements the feature in the project directory.

### Step 6: QA Validation (3 Gates)

The implementation goes through three validation gates. See [The QA Pipeline](#the-qa-pipeline).

### Step 7: Fix & Retry

If any gate fails, TaskLot's fix agent analyses the failure and modifies the code, then re-runs all gates. This repeats up to `max_retries` times (default: 3).

### Step 8: Commit & Push

The git operations agent stages, commits (with granular conventional commits), and pushes. Migrations are committed separately from feature code, which is committed separately from tests.

### Step 9: Create PR

The git operations agent creates a GitHub PR with a structured description using the PR template from the agent file. If the branch is stacked, the PR targets the parent branch (not main).

### Step 10: Document

If Notion integration is enabled, TaskLot posts an implementation summary as a comment on the Notion ticket.

### Step 11: Next Task

The task is marked as `done` in `tasks.json` and TaskLot moves to the next pending task.

### On Failure

If a task fails after `max_retries` attempts:

- The task is marked as `failed` with a reason in `tasks.json`
- The stacking chain resets (next task branches from `main`)
- TaskLot continues to the next task without stopping

---

## The QA Pipeline

Every task passes through three validation gates before it can be committed.

### Gate 1: Architecture & Quality (QA Agent)

The QA agent (`qa/qa-agent.md`) reviews all code changes and checks:

- **Code quality** — no hardcoded secrets, no debug statements, no dead code, no unused imports, function length limits
- **Error handling** — all external calls wrapped, no silent catches, descriptive user-facing errors
- **Security** — input validation, injection prevention, CORS configuration, auth checks, no sensitive data in logs
- **File structure** — files in correct directories, proper naming conventions
- **Testing** — new functionality has tests, tests are meaningful, edge cases covered
- **Git hygiene** — changes scoped to task, no unrelated modifications

The QA agent also loads the task's agent file (if one was used) for stack-specific validation — e.g., checking NestJS module structure or React component patterns.

**Response protocol:** The QA agent responds with `QA_PASSED`, `QA_FIXED` (found and fixed issues), or `QA_FAILED` (issues it cannot fix).

### Gate 2: Test Suite

Runs the command specified in `config.json → test_command`:

```json
{ "test_command": "npm test" }
```

All tests must pass. If this field is empty, the gate is skipped.

### Gate 3: API Curl Tests

When `curl_tests_enabled` is `true`, TaskLot dynamically generates and runs curl tests for all created/modified API endpoints:

- **Happy path** — valid requests with expected responses
- **Invalid input** — missing fields, wrong types, malformed data
- **Edge cases** — empty strings, very long inputs, special characters
- **Auth** — requests with/without tokens, expired tokens
- **Status codes** — validates correct HTTP status codes and response bodies

The API server must be running at `api_base_url` during execution.

### Retry Behaviour

```
Attempt 1: QA → Tests → Curl
  ↓ (any failure)
Fix attempt → Attempt 2: QA → Tests → Curl
  ↓ (any failure)
Fix attempt → Attempt 3: QA → Tests → Curl
  ↓ (failure)
Task marked as FAILED, move to next
```

Each gate runs sequentially. If Gate 1 fails, Gates 2 and 3 are skipped for that attempt. The fix agent analyses the failure and modifies the code before the next attempt.

---

## Stacked Branches

When TaskLot executes multiple tasks sequentially, each task often depends on the code from the previous task. Since PRs aren't merged instantly, TaskLot uses **stacked branches** to keep the pipeline moving.

### How It Works

```
main ─────────────────────────────────────────────────
  │
  └── feat/api-auth-endpoints          (TASK-001)
       │   PR #1 → targets main
       │
       └── feat/api-user-profile        (TASK-002)
            │   PR #2 → targets feat/api-auth-endpoints
            │
            └── feat/api-notifications  (TASK-003)
                    PR #3 → targets feat/api-user-profile
```

### Decision Logic

Before creating each branch, TaskLot runs `resolve_source_branch()`:

```
Is there a previous task branch?
  ├── No  → Branch from main
  └── Yes → Is the previous PR merged?
              ├── Yes → Branch from main
              └── No  → Branch from previous task's branch (STACK)
```

### Merge Detection

TaskLot checks if the previous PR is merged using two methods:

1. **`gh pr view`** — checks the PR state via GitHub CLI
2. **`git merge-base --is-ancestor`** — fallback check if the branch is an ancestor of main

### Stacked PR Labels

Stacked PRs are clearly marked in their description:

```markdown
## ⚠️ STACKED PR
This PR targets: feat/api-auth-endpoints (not main)
This is a stacked PR — it should be reviewed after its parent PR is merged.
Once the parent PR merges, retarget this PR to main.
```

### Chain Reset on Failure

If a task fails after max retries, the stacking chain resets. The next task branches from `main` to avoid building on top of potentially broken code.

### After Merging Parent PRs

When a parent PR merges into main, retarget the child PR:

```bash
# Via GitHub UI: Edit PR → Change base → main
# Via CLI:
gh pr edit 42 --base main
```

---

## Notion Integration

TaskLot integrates with Notion in two ways:

### 1. Pulling Tasks (`pull-tasks.sh`)

Connects to your Notion database via Claude Code MCP, fetches all tickets, and generates `tasks.json`.

**Requirements:**

- Claude Code CLI installed
- Notion MCP configured in Claude Code
- `notion.database_id` set in `config.json`

**Notion Database Setup:**

Your Notion database should have at minimum:

- **Title** — the task name
- **Status** — a select/status property (e.g. "To Do", "In Progress", "Done")
- **Page content** — the full task description with agent reference

Optional but useful:

- **Priority** — high / medium / low
- **Tags/Labels** — for categorisation

### 2. Documenting Solutions

After a task completes, TaskLot posts an implementation summary as a comment on the Notion ticket. This includes what was implemented, key technical decisions, files created or modified, patterns used, and testing coverage.

Set `auto_document: true` in config to enable this.

### Without Notion

TaskLot works perfectly without Notion. Create `tasks.json` manually and set:

```json
{
  "notion": { "enabled": false }
}
```

---

## CLI Reference

### `tasklot.sh`

The main orchestrator.

```
Usage: ./tasklot.sh [OPTIONS]

Options:
  --config FILE   Path to config.json (default: ./config.json)
  --dry-run       Preview tasks without executing anything
  --task ID       Run only a single task by its ID
  --help          Show help
```

**Examples:**

```bash
# Run all pending tasks
./tasklot.sh

# Preview without executing
./tasklot.sh --dry-run

# Run just TASK-005
./tasklot.sh --task TASK-005

# Use a project-specific config
./tasklot.sh --config configs/backend-api.json
```

### `pull-tasks.sh`

Fetches tasks from Notion.

```
Usage: ./pull-tasks.sh [--config config.json]
```

**Output:** Creates `tasks.json` in the TaskLot directory with a preview of all pulled tasks.

---

## Logging

Every TaskLot run produces a timestamped log file in `logs/`:

```
logs/
├── tasklot_20260329_141500.log
├── tasklot_20260329_163022.log
└── tasklot_20260330_091200.log
```

Logs contain:

- Full AI engine output for each task
- QA agent review details
- Test suite output
- Curl test results and responses
- Error details for failed tasks
- Git operation output
- Timestamps for every action

Logs are excluded from git via `.gitignore`.

---

## Requirements


| Tool             | Purpose                  | Install                                |
| ------------------ | -------------------------- | ---------------------------------------- |
| **Bash 4+**      | Orchestrator runtime     | Pre-installed on macOS/Linux           |
| **jq**           | JSON processing          | `brew install jq` / `apt install jq`   |
| **git**          | Version control          | Pre-installed or`brew install git`     |
| **gh**           | GitHub CLI (PR creation) | `brew install gh` then `gh auth login` |
| **An AI engine** | Code generation          | See[Engines](#engines)                 |

**Optional:**


| Tool                | Purpose                | When Needed                    |
| --------------------- | ------------------------ | -------------------------------- |
| **Claude Code CLI** | Notion MCP integration | When using Notion for tasks    |
| **curl**            | API endpoint testing   | When`curl_tests_enabled: true` |

---

## Tips & Best Practices

### Agent Files

- **Be exhaustive** — the more detail in your agent files, the better the output. Include actual folder tree structures, actual code examples, actual naming patterns.
- **Include anti-patterns** — tell the agent what NOT to do. "Never use `any` type" is as useful as "always use strict typing."
- **Iterate** — review the first few PRs TaskLot creates and refine your agent files based on what it gets wrong.

### Tickets

- **One feature per ticket** — don't create epic-sized tickets. "Build the full auth system with OAuth, SAML, MFA, and social login" is too much. Break it down.
- **Be specific** — "Build auth endpoints" is vague. "POST /auth/register with email+password, POST /auth/login returning JWT, GET /auth/me with bearer token validation" is specific.
- **Order matters** — tasks execute sequentially. Put foundation work first (database, boilerplate), then features, then polish.

### Execution

- **Always start with `--dry-run`** to preview what TaskLot will do.
- **Run `--task TASK-001` first** to test a single task before running the full queue.
- **Review the first 2-3 PRs** manually to calibrate your agent files and QA rules.
- **Keep your server running** if using curl tests — TaskLot needs to hit actual endpoints.

### Git

- **Customise the git agent** to match your team's conventions before the first run.
- **Review stacked PRs in order** — start with the oldest (bottom of the stack).
- **Retarget PRs** after merging parents: `gh pr edit {number} --base main`.

### Debugging

- **Check logs** in `logs/` — every engine call, QA result, and test output is captured.
- **Failed tasks stay in `tasks.json`** with a `failure_reason`. Fix the issue, set status back to `"pending"`, and re-run.
- **Increase `max_retries`** for complex tasks that might need more fix cycles (default: 3).

---

## FAQ

**Can I use TaskLot without Notion?**
Yes. Create `tasks.json` manually and set `notion.enabled: false` in config.

**Can I use TaskLot with Linear / Jira / Asana?**
Not natively yet, but you can write a custom `pull-tasks.sh` that queries any project management tool and outputs the same `tasks.json` format. The orchestrator doesn't care where tasks come from.

**What happens if the AI engine produces bad code?**
The three QA gates catch most issues. If a task still fails after `max_retries`, it's marked as failed and TaskLot moves on. You can fix it manually, set the status back to `"pending"`, and re-run.

**Can I run TaskLot on multiple projects simultaneously?**
Yes. Use separate `config.json` files:

```bash
./tasklot.sh --config configs/project-a.json &
./tasklot.sh --config configs/project-b.json &
```

**Does TaskLot support monorepos?**
Yes. Your agent files define the folder structure and module boundaries. A monorepo might have multiple task agents (backend, frontend, shared packages) and tickets that reference different agents for different parts of the codebase.

**How do I resume after a failure?**
Failed tasks are marked in `tasks.json`. Fix the underlying issue, set the task's status back to `"pending"`, and run TaskLot again. It skips completed tasks and resumes from the first pending one.

**Can I add tasks while TaskLot is running?**
No. TaskLot reads `tasks.json` at startup. Add new tasks after the current run completes, or stop the run, update the file, and restart.

**How much does it cost?**
TaskLot itself is free and open source. You pay for the AI engine usage — Claude Code, Aider (with your API key), or Codex (with your OpenAI subscription). Cost depends on task complexity and the number of QA retry cycles.

**What if a task has no agent reference?**
TaskLot will still execute it — the AI engine just won't have agent context. The task description alone will be used. This works for simple, self-contained tasks but produces better results with an agent file.

**Can I use the same agent file for all tasks?**
Yes. If your entire project uses one stack, one agent file is fine. Every ticket just references the same file: `read backend-developer.agent.md`.

---

## License

MIT

---

## Author

Built by **Sey** — Autonomous AI workflows for modern engineering.

[GitHub](https://github.com/ratioraji) · [Twitter](https://x.com/seyi_life)
