# Running TaskLot on Monorepos

A complete guide to using TaskLot with monorepo architectures — Turborepo, Nx, Lerna, pnpm workspaces, or any multi-package repository. Build features across your entire stack from a single task queue.

---

## Table of Contents

- [Why Monorepos are TaskLot's Sweet Spot](#why-monorepos-are-tasklots-sweet-spot)
- [Monorepo Challenges TaskLot Solves](#monorepo-challenges-tasklot-solves)
- [Architecture](#architecture)
- [Setup](#setup)
- [Agent Strategy for Monorepos](#agent-strategy-for-monorepos)
- [Task Design for Monorepos](#task-design-for-monorepos)
- [Cross-Package Tasks](#cross-package-tasks)
- [Git Strategy for Monorepos](#git-strategy-for-monorepos)
- [QA Strategy for Monorepos](#qa-strategy-for-monorepos)
- [Test Strategy for Monorepos](#test-strategy-for-monorepos)
- [Real-World Example: Full Walkthrough](#real-world-example-full-walkthrough)
- [Advanced Patterns](#advanced-patterns)
- [Troubleshooting](#troubleshooting)

---

## Why Monorepos are TaskLot's Sweet Spot

Monorepos are where TaskLot truly shines. Here's why:

In a monorepo, a single feature often touches multiple packages — a shared entity definition, an API endpoint, a frontend component, maybe a worker job. Traditionally, a developer has to mentally context-switch between these layers, keeping the full picture in their head while working file-by-file.

TaskLot eliminates this entirely. You write one ticket that says "build the notification system" and give it an agent that understands the entire monorepo structure — where entities live, where API modules go, where frontend components belong. The AI engine sees the full picture because the agent file draws the full picture.

With stacked branches, TaskLot builds foundation layers first (shared entities, migrations), then API endpoints on top, then frontend components on top of that — all in the correct dependency order, all committed properly, all with PRs that stack cleanly.

The result: a feature that spans 5 packages, 30 files, and 3 layers of the stack, built end-to-end in one automated run.

---

## Monorepo Challenges TaskLot Solves

| Challenge | How TaskLot Handles It |
|-----------|----------------------|
| **Cross-package consistency** | Agent files define the architecture for the entire monorepo — shared naming, import patterns, module structure |
| **Dependency ordering** | Task ordering in `tasks.json` ensures shared packages are built before consuming apps. Stacked branches preserve the dependency chain. |
| **Correct commit scoping** | The git operations agent knows to commit shared packages separately from consuming apps, migrations separately from feature code |
| **Testing across packages** | The test command can run the monorepo's full test suite (`turbo test`, `nx test`, `pnpm test --recursive`) |
| **Shared entity changes** | Agent files explicitly document how shared packages work, preventing the AI from duplicating logic or breaking contracts |
| **Build verification** | QA gate can verify that the monorepo still builds after changes (`turbo build`, `nx build`) |

---

## Architecture

TaskLot sits alongside your monorepo (or inside it). It points `project_dir` at the monorepo root and uses agents that understand the entire structure.

```
~/projects/
├── my-monorepo/                          ← Your monorepo
│   ├── package.json                      ← Root workspace config
│   ├── turbo.json / nx.json              ← Build orchestrator
│   ├── packages/
│   │   ├── shared-types/                 ← Shared TypeScript types
│   │   ├── database/                     ← Shared entities & migrations
│   │   ├── config/                       ← Shared configuration
│   │   └── ui-components/                ← Shared UI library
│   ├── apps/
│   │   ├── api/                          ← NestJS backend
│   │   ├── web/                          ← React frontend
│   │   ├── mobile/                       ← React Native app
│   │   └── worker/                       ← Background job processor
│   └── .tasklot/                         ← TaskLot lives here
│       ├── tasklot.sh
│       ├── pull-tasks.sh
│       ├── config.json
│       ├── agents/
│       │   ├── git-operations.agent.md
│       │   ├── api-developer.agent.md
│       │   ├── web-developer.agent.md
│       │   ├── shared-packages.agent.md
│       │   └── fullstack.agent.md
│       ├── qa/
│       │   └── qa-agent.md
│       ├── engines/
│       ├── pullers/
│       └── logs/
```

Key: `project_dir` in config points to `~/projects/my-monorepo` (the monorepo root), not a specific app within it.

---

## Setup

### 1. Place TaskLot

Either clone TaskLot into a `.tasklot/` directory inside your monorepo, or keep it external and point the config at the monorepo:

```bash
# Option A: Inside the monorepo
cd ~/projects/my-monorepo
git clone https://github.com/your-username/tasklot.git .tasklot
cd .tasklot

# Option B: External (recommended for keeping monorepo clean)
cd ~/projects/tasklot
# Set project_dir in config to ~/projects/my-monorepo
```

### 2. Configure for the Monorepo

```json
{
  "project_name": "my-monorepo",
  "project_dir": "/home/dev/projects/my-monorepo",
  "engine": "claude-code",
  "base_branch": "main",
  "branch_prefix": "feat",
  "auto_pr": true,
  "max_retries": 3,
  "test_command": "turbo test",
  "curl_tests_enabled": true,
  "api_base_url": "http://localhost:3000",
  "auto_document": true,
  "task_source": {
    "type": "notion",
    "config": {
      "database_id": "MONOREPO_NOTION_DB_ID"
    }
  }
}
```

Note `test_command`: use the monorepo's build orchestrator (`turbo test`, `nx test`, `pnpm -r test`). This runs tests across all affected packages, ensuring cross-package changes don't break anything.

### 3. Add `.tasklot/` to `.gitignore` (if inside the monorepo)

```gitignore
# TaskLot
.tasklot/logs/
.tasklot/tasks.json
```

---

## Agent Strategy for Monorepos

This is where monorepo TaskLot differs from single-project TaskLot. Your agents need to understand the full monorepo structure — not just one app.

### Agent Types for Monorepos

| Agent | Responsible For | Knows About |
|-------|----------------|-------------|
| `api-developer.agent.md` | `apps/api/` | API structure, but also how to import from `packages/database`, `packages/shared-types` |
| `web-developer.agent.md` | `apps/web/` | Frontend structure, but also how to import from `packages/ui-components`, `packages/shared-types` |
| `shared-packages.agent.md` | `packages/*` | Shared entity definitions, migration patterns, how packages are consumed by apps |
| `fullstack.agent.md` | Cross-cutting features | The entire monorepo structure — when a ticket spans multiple packages and apps |
| `worker-developer.agent.md` | `apps/worker/` | Job processing patterns, queue integration, shared database access |

### The Critical Monorepo Section in Agent Files

Every monorepo agent file MUST include a section that maps the full repository structure and explains import boundaries. This is what prevents the AI from putting files in the wrong place or importing from the wrong package.

```markdown
# Agent: API Developer — MyMonorepo

## Repository Structure (FULL MONOREPO)

```
my-monorepo/
├── packages/
│   ├── shared-types/           ← TypeScript interfaces & enums
│   │   └── src/
│   │       ├── entities/       ← Entity interfaces (NOT TypeORM — just types)
│   │       ├── enums/          ← Shared enums
│   │       └── dto/            ← Shared DTOs
│   ├── database/               ← TypeORM entities & migrations
│   │   └── src/
│   │       ├── entities/       ← TypeORM entity classes
│   │       ├── migrations/     ← Database migrations
│   │       └── index.ts        ← Barrel export
│   ├── config/                 ← Shared config (env vars, constants)
│   └── ui-components/          ← Shared React components (NOT your area)
├── apps/
│   ├── api/                    ← YOUR AREA
│   │   └── src/
│   │       ├── modules/        ← NestJS feature modules
│   │       ├── common/         ← Guards, interceptors, pipes
│   │       └── main.ts
│   ├── web/                    ← NOT your area
│   └── worker/                 ← NOT your area
```

## Import Rules

- Import entities from `@monorepo/database`, NEVER define entities in apps/api
- Import types/DTOs from `@monorepo/shared-types`, NEVER define shared types locally
- Import config from `@monorepo/config`
- NEVER import from other apps (apps/web, apps/worker)
- NEVER import from apps/api into packages/ (packages cannot depend on apps)

## When You Need to Add a Shared Entity

If the task requires a new database entity:
1. Add the TypeScript interface in packages/shared-types/src/entities/
2. Add the TypeORM entity in packages/database/src/entities/
3. Create a migration in packages/database/src/migrations/
4. Export from packages/database/src/index.ts
5. THEN use it in apps/api
```

This level of detail is what makes monorepo TaskLot work. Without it, the AI engine might create entities in the wrong package, import from the wrong path, or violate dependency boundaries.

### The Fullstack Agent

For cross-cutting features that touch everything, create a `fullstack.agent.md` that contains the ENTIRE monorepo context:

```markdown
# Agent: Fullstack Developer — MyMonorepo

## Identity

You work across the ENTIRE monorepo. You handle tasks that span
multiple packages and apps. You understand the dependency graph:

  packages/shared-types  ← consumed by everything
  packages/database      ← consumed by api, worker
  packages/config        ← consumed by everything
  packages/ui-components ← consumed by web, mobile
  apps/api               ← consumes packages/*
  apps/web               ← consumes packages/*
  apps/worker            ← consumes packages/*

## Build Order for Cross-Cutting Features

When implementing a feature that spans multiple areas:
1. packages/shared-types (interfaces, enums, DTOs)
2. packages/database (entities, migrations)
3. apps/api (endpoints, services)
4. apps/worker (if background jobs needed)
5. packages/ui-components (if shared components needed)
6. apps/web (pages, components)

ALWAYS follow this order. The git operations agent will commit
each layer separately.
```

---

## Task Design for Monorepos

How you write your tickets determines whether TaskLot builds things in the right order with the right agents.

### Rule 1: Split by Layer, Not by Feature

Instead of one giant ticket "Build the notification system", split it into layer-specific tickets that execute in dependency order:

```
TASK-001: [shared-types] Add notification types and enums
          read shared-packages.agent.md
          Priority: high

TASK-002: [database] Add notifications table and entity
          read shared-packages.agent.md
          Priority: high

TASK-003: [api] Implement notification module with queue and handlers
          read api-developer.agent.md
          Priority: high

TASK-004: [worker] Add notification delivery processor
          read worker-developer.agent.md
          Priority: high

TASK-005: [ui-components] Build NotificationBell and NotificationList components
          read web-developer.agent.md
          Priority: medium

TASK-006: [web] Integrate notifications into dashboard layout
          read web-developer.agent.md
          Priority: medium
```

TaskLot executes these in order. TASK-001 creates the shared types. TASK-002 builds on them to create the entity (stacked branch). TASK-003 builds on that to create the API module (another stacked branch). And so on up the dependency chain.

### Rule 2: Prefix Ticket Titles with the Package Scope

This makes it instantly clear which part of the monorepo each ticket affects, and the git operations agent uses it for branch naming and commit scoping:

```
[database] Add notifications table
[api] Build notification endpoints
[web] Build notification dropdown
[shared-types] Add NotificationType enum
```

### Rule 3: Cross-Cutting Tickets Use the Fullstack Agent

When a task genuinely needs to touch multiple packages in one go:

```
TASK-010: [full] Add subscription tier system
          read fullstack.agent.md

          This feature spans the entire stack:
          1. Add SubscriptionTier enum to packages/shared-types
          2. Add subscriptions table and entity to packages/database
          3. Add subscription module to apps/api with Stripe integration
          4. Add tier guard middleware to apps/api
          5. Add SubscriptionBadge component to packages/ui-components
          6. Add billing page to apps/web
```

The fullstack agent knows the build order and will implement each layer in sequence within a single task execution.

---

## Cross-Package Tasks

The most powerful (and trickiest) part of monorepo TaskLot is handling tasks that create or modify shared packages that are consumed by multiple apps.

### The Dependency Graph Matters

```
shared-types ──► database ──► api
                          ──► worker
shared-types ──► ui-components ──► web
                               ──► mobile
config ──► everything
```

When you modify `shared-types`, everything downstream could be affected. Your task ordering must respect this:

```
1. TASK-001: Modify shared-types (adds new interface)
2. TASK-002: Update database entity to implement new interface
3. TASK-003: Update API to use new entity fields
4. TASK-004: Update web to display new fields
```

TaskLot's stacked branches handle this naturally — TASK-002 branches from TASK-001's branch and has access to the new types.

### Breaking Change Protocol

When a shared package change breaks consuming apps, your agent file should include instructions:

```markdown
## Breaking Change Protocol

If your changes to packages/shared-types or packages/database
cause type errors in consuming apps:

1. Fix the consuming apps in the SAME task
2. Run `turbo build` to verify all apps compile
3. Run `turbo test` to verify all tests pass
4. Commit the shared package change FIRST, then consuming app fixes

NEVER leave the monorepo in a state where `turbo build` fails.
```

---

## Git Strategy for Monorepos

### Customise the Git Operations Agent

Your `git-operations.agent.md` should include monorepo-specific scopes and commit conventions:

```markdown
## Commit Scopes (Monorepo)

Scopes map to monorepo packages and apps:

```
shared-types:  interfaces, enums, DTOs in packages/shared-types
database:      entities, migrations in packages/database
config:        configuration in packages/config
ui:            components in packages/ui-components
api:           apps/api modules, services, controllers
web:           apps/web pages, components, hooks
worker:        apps/worker jobs, processors
mobile:        apps/mobile screens, components
full:          cross-cutting changes spanning multiple packages
```

Examples:
```
feat(database): add notifications table and entity
feat(api): implement notification module with BullMQ
feat(ui): add NotificationBell component
feat(full): add subscription tier system across stack
chore(shared-types): add NotificationType enum
```

## Commit Ordering for Cross-Package Changes

When a task touches multiple packages, commit in dependency order:

```
1. chore(shared-types): add new interface
2. chore(database): add migration using new interface
3. feat(api): implement feature using new entity
4. feat(web): add UI for new feature
5. test(api): add tests for new feature
```
```

### Branch Naming for Monorepo Tasks

The git agent should produce branches that indicate the scope:

```
feat/database-notifications-table
feat/api-notification-module
feat/web-notification-dropdown
feat/full-subscription-tier-system
```

---

## QA Strategy for Monorepos

### Extend the QA Agent for Monorepo Rules

Add monorepo-specific checks to `qa/qa-agent.md`:

```markdown
## Monorepo-Specific Quality Rules

### Dependency Boundaries
- Apps (apps/*) may import from packages (packages/*) only
- Apps NEVER import from other apps
- Packages NEVER import from apps
- Packages may import from other packages only if the dependency
  is declared in that package's package.json

### Build Verification
- After changes, `turbo build` (or equivalent) must succeed
- No circular dependencies between packages

### Shared Package Changes
- Any change to packages/shared-types must not break consuming apps
- Any change to packages/database must include a migration
- Any new export from a package must be added to its index.ts barrel

### Import Path Verification
- All imports from shared packages use the workspace alias
  (e.g., @monorepo/database, NOT relative paths like ../../packages/database)
- No deep imports into package internals
  (e.g., @monorepo/database is OK, @monorepo/database/src/entities/user is NOT)
```

---

## Test Strategy for Monorepos

### Test Command Configuration

Use the monorepo's build orchestrator as the test command so it runs tests for ALL affected packages:

```json
{
  "test_command": "turbo test"
}
```

Alternative test commands by monorepo tool:

| Tool | Test Command | What It Does |
|------|-------------|-------------|
| Turborepo | `turbo test` | Runs tests in all affected packages (cached) |
| Nx | `nx affected --target=test` | Runs tests only in packages affected by changes |
| pnpm | `pnpm -r test` | Runs tests recursively in all packages |
| Lerna | `lerna run test --since=main` | Runs tests in packages changed since main |
| Bun workspaces | `bun test` | Runs tests across the workspace |

### Why `turbo test` (or equivalent) is Ideal

Monorepo build tools like Turborepo and Nx understand the dependency graph. When TaskLot changes `packages/database`, `turbo test` knows to run tests in:
- `packages/database` (the changed package)
- `apps/api` (depends on database)
- `apps/worker` (depends on database)

But NOT in `apps/web` or `packages/ui-components` (which don't depend on database). This makes tests faster while still catching cross-package breakage.

### Curl Tests for Monorepo APIs

If your monorepo has an API app, configure curl tests to target it:

```json
{
  "curl_tests_enabled": true,
  "api_base_url": "http://localhost:3000"
}
```

Make sure the API app is running before TaskLot starts. You can add a startup step to your workflow:

```bash
# Start the API in the background
cd ~/projects/my-monorepo
turbo dev --filter=api &
sleep 10

# Run TaskLot
cd .tasklot
./tasklot.sh
```

---

## Real-World Example: Full Walkthrough

Let's walk through a complete monorepo TaskLot run, building a "Team Management" feature across the stack.

### The Monorepo

```
acme-platform/
├── packages/
│   ├── shared-types/       ← TypeScript interfaces
│   ├── database/           ← TypeORM entities + migrations
│   └── ui-components/      ← Shared React components
├── apps/
│   ├── api/                ← NestJS API
│   └── web/                ← Next.js frontend
```

### Step 1: Create Agent Files

**`agents/api-developer.agent.md`** — defines NestJS patterns, module structure, how to import from `@acme/database` and `@acme/shared-types`.

**`agents/web-developer.agent.md`** — defines Next.js patterns, page structure, how to import from `@acme/ui-components` and `@acme/shared-types`.

**`agents/shared-packages.agent.md`** — defines how to add entities, create migrations, export new types.

### Step 2: Create Tickets in Notion

```
TASK-001: [shared-types] Add Team and TeamMember interfaces
          read shared-packages.agent.md

          Add to packages/shared-types/src/entities/:
          - Team interface (id, name, slug, ownerId, createdAt)
          - TeamMember interface (id, teamId, userId, role, joinedAt)
          - TeamRole enum (OWNER, ADMIN, MEMBER, VIEWER)
          Export all from packages/shared-types/src/index.ts

TASK-002: [database] Add teams and team_members tables
          read shared-packages.agent.md

          Create TypeORM entities in packages/database/src/entities/:
          - Team entity implementing Team interface
          - TeamMember entity implementing TeamMember interface
          Create migration in packages/database/src/migrations/
          Add proper indexes, foreign keys, and CASCADE rules
          Export from packages/database/src/index.ts

TASK-003: [api] Implement team management module
          read api-developer.agent.md

          Create apps/api/src/modules/team/ with:
          - POST /teams — create team
          - GET /teams — list user's teams
          - GET /teams/:id — get team details
          - POST /teams/:id/members — invite member
          - DELETE /teams/:id/members/:userId — remove member
          - PATCH /teams/:id/members/:userId/role — change role
          Owner-only operations guarded by TeamOwnerGuard
          Import entities from @acme/database

TASK-004: [ui-components] Build TeamCard and TeamMemberList components
          read web-developer.agent.md

          Create in packages/ui-components/src/:
          - TeamCard — displays team name, member count, user's role
          - TeamMemberList — sortable list with role badges
          - InviteMemberModal — email input with role selector
          Use @acme/shared-types for type safety

TASK-005: [web] Build team management pages
          read web-developer.agent.md

          Create in apps/web/src/pages/:
          - /teams — list of user's teams (uses TeamCard)
          - /teams/new — create team form
          - /teams/:id — team detail with member management
          - /teams/:id/settings — team settings (owner only)
          Use components from @acme/ui-components
          Connect to API endpoints from TASK-003
```

### Step 3: Pull and Run

```bash
./pull-tasks.sh
./tasklot.sh
```

### What Happens

```
⚡ T A S K L O T ⚡

[14:00:01] ℹ Config loaded: engine=claude-code, project=~/projects/acme-platform
[14:00:01] ℹ Loaded 5 pending tasks

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[14:00:02] ℹ Task TASK-001: [shared-types] Add Team and TeamMember interfaces
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[14:00:02] ℹ Agent: shared-packages.agent.md
[14:00:02] ℹ No previous task — branching from main
[14:00:03] ▶ Git Agent: Creating branch from main...
[14:00:05] ✔ Branch: feat/shared-types-team-interfaces
[14:00:05] ▶ Implementing task...
[14:01:20] ✔ Implementation complete
[14:01:20] ℹ Validation round 1/3
[14:01:20] ▶ QA Gate: Architecture & Quality Check (attempt 1)
[14:01:45] ✔ QA check passed
[14:01:45] ▶ Test Gate: Running test suite (attempt 1)
[14:02:10] ✔ All tests passed
[14:02:10] ▶ Git Agent: Committing and pushing...
[14:02:15] ✔ Pushed to feat/shared-types-team-interfaces
[14:02:15] ▶ Git Agent: Creating pull request → base: main...
[14:02:18] ✔ PR created for feat/shared-types-team-interfaces
[14:02:20] ✔ Task TASK-001 completed successfully! ✨

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[14:02:21] ℹ Task TASK-002: [database] Add teams and team_members tables
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[14:02:21] ℹ Agent: shared-packages.agent.md
[14:02:22] ℹ Previous branch feat/shared-types-team-interfaces is unmerged → stacking on it
[14:02:22] ▶ Git Agent: Creating branch from feat/shared-types-team-interfaces...
[14:02:25] ✔ Branch: feat/database-teams-tables
...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[14:08:30] ℹ Task TASK-003: [api] Implement team management module
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[14:08:30] ℹ Agent: api-developer.agent.md
[14:08:31] ℹ Previous branch feat/database-teams-tables is unmerged → stacking on it
[14:08:31] ▶ Git Agent: Creating branch from feat/database-teams-tables...
...
```

### The Result: Stacked PRs

```
main
 └── feat/shared-types-team-interfaces       PR #1 → main
      └── feat/database-teams-tables          PR #2 → feat/shared-types-team-interfaces
           └── feat/api-team-module           PR #3 → feat/database-teams-tables
                └── feat/ui-team-components   PR #4 → feat/api-team-module
                     └── feat/web-team-pages  PR #5 → feat/ui-team-components
```

Five PRs, perfectly stacked, each building on the previous layer. Review bottom-up. Merge bottom-up. Each PR retargets to main after its parent merges.

---

## Advanced Patterns

### Pattern 1: Parallel Tracks Within a Monorepo

Some features can be built in parallel because they don't depend on each other. Structure your `tasks.json` to run independent tracks sequentially, but recognise which tasks COULD be parallelised if you split them into separate runs:

```
Track A (API features):           Track B (Web features):
  TASK-001: [api] Auth module       TASK-004: [web] Landing page
  TASK-002: [api] User endpoints    TASK-005: [web] Dashboard layout
  TASK-003: [api] Team endpoints    TASK-006: [web] Settings page
```

Run two TaskLot instances with separate task files:

```bash
# Track A: API work
./tasklot.sh --config configs/monorepo-api-track.json &

# Track B: Web work (independent, no conflicts)
./tasklot.sh --config configs/monorepo-web-track.json &

wait
```

This works because the two tracks modify different directories (`apps/api/` vs `apps/web/`) and won't have merge conflicts.

**When NOT to parallelise:** When both tracks modify shared packages. If Track A adds a database entity and Track B needs that entity, they must run sequentially.

### Pattern 2: Shared Package First, Then Fan Out

Build the shared foundation in one sequential run, then fan out into parallel app-specific runs:

```bash
# Phase 1: Shared packages (sequential, must complete first)
./tasklot.sh --config configs/monorepo-shared.json

# Phase 2: Apps (parallel, each builds on the shared layer)
./tasklot.sh --config configs/monorepo-api.json &
./tasklot.sh --config configs/monorepo-web.json &
./tasklot.sh --config configs/monorepo-worker.json &
wait
```

Phase 1 creates types, entities, and migrations. Phase 2's configs point to the same monorepo but have tasks that only touch specific apps.

### Pattern 3: Feature Flags in Monorepos

For large features that should be behind a feature flag, include the flag setup in the first ticket:

```
TASK-001: [config] Add ENABLE_TEAMS feature flag
          read shared-packages.agent.md

          Add to packages/config:
          - ENABLE_TEAMS environment variable
          - Feature flag utility function
          - Default: false in production, true in development
```

Subsequent tasks wrap their code in the feature flag check. The fullstack agent knows to gate all new endpoints and pages behind the flag.

### Pattern 4: Migration Safety

Database migrations in monorepos need special care. Add this to your shared packages agent:

```markdown
## Migration Safety Rules

1. NEVER modify an existing migration — create a new one
2. Migration filenames: {timestamp}-{description}.ts
3. Test migrations run both UP and DOWN: `turbo db:migrate && turbo db:rollback`
4. Migrations must be idempotent — safe to run multiple times
5. If adding a NOT NULL column, include a DEFAULT or backfill step
6. NEVER drop a column or table without a deprecation migration first
```

---

## Troubleshooting

**Build fails after cross-package changes**
The AI engine might forget to export new types from a package's `index.ts`. Your QA agent should check for this. Add to `qa/qa-agent.md`:
```
- Verify all new exports are added to the package's barrel file (index.ts)
- Run `turbo build` and check for import errors
```

**Import path errors**
The AI uses relative imports instead of workspace aliases. Your agent file must be explicit:
```
CORRECT: import { User } from '@acme/database'
WRONG:   import { User } from '../../../packages/database/src/entities/user'
```

**Migration conflicts between stacked branches**
If two tasks create migrations with the same timestamp, they'll conflict. Your shared packages agent should specify:
```
Use the current Unix timestamp for migration names.
Format: {timestamp}-{description}.ts
Example: 1711700000000-add-teams-table.ts
```

**Tests pass individually but fail together**
This usually means two tasks modify the same test setup or share database state. Solutions:
- Use isolated test databases per package
- Ensure tests clean up after themselves
- Run `turbo test` (not individual package tests) so cross-package issues are caught

**TypeORM entity not found after adding it**
The entity must be registered in the database module's entity list. Your agent should include:
```
After creating a new entity in packages/database:
1. Add the entity class to src/entities/index.ts
2. Add it to the entities array in the database module configuration
3. Generate and run the migration
```

**Stacked PR shows massive diff**
When reviewing PR #3 in a stack, GitHub shows the diff against PR #2's branch — which only shows the changes from TASK-003. But if you look at the "Files changed" tab, it might include changes from TASK-001 and TASK-002 if GitHub is comparing against main. Solution: review the diff against the PR's actual base branch, not main.
