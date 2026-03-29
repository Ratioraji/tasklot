# TaskLot Agents

This folder holds your **agent context files**. Each agent file defines the role, tech stack, architecture standards, and coding conventions for a specific type of work.

## Default Agents

TaskLot ships with one built-in agent:

- **`git-operations.agent.md`** — Handles all version control: branch naming, commit messages (conventional commits), push operations, and PR creation with structured descriptions. TaskLot uses this agent internally for every git operation. Customise it to match your team's git workflow.

## How It Works

1. You brainstorm your project and define your architecture
2. You create agent files that capture those decisions
3. Your Notion tickets reference the agent: `read backend-developer.agent.md`
4. TaskLot loads the agent context before executing the task
5. The QA agent can also reference your agent file for stack-specific validation

## Naming Convention

```
{role}.agent.md
```

Examples:
- `backend-developer.agent.md`
- `frontend-developer.agent.md`
- `ai-ml-developer.agent.md`
- `devops-engineer.agent.md`
- `mobile-developer.agent.md`

## What to Include in an Agent File

A good agent file answers these questions:

### Identity & Role
- What is this agent responsible for?
- What does it NOT touch?

### Tech Stack
- Language, framework, runtime versions
- Database, ORM, cache layer
- Key libraries and their versions

### Architecture
- Folder structure (draw the tree)
- Design patterns to follow (repository pattern, service layer, etc.)
- How modules/features are organized

### Coding Standards
- Naming conventions (files, variables, functions, classes)
- Error handling approach
- Logging standards
- Import ordering

### API Conventions (for backend)
- Route naming patterns
- Request/response format
- Status codes to use
- Pagination, filtering, sorting patterns
- Authentication/authorization approach

### Component Standards (for frontend)
- Component structure
- State management approach
- Styling methodology
- Accessibility requirements

### Testing
- Test framework and runner
- What to test and what not to test
- Naming conventions for tests
- Minimum coverage expectations

---

## Example

See `tasks.example.json` in the root for how tickets reference agents:

```
read backend-developer.agent.md

Build the authentication system:
- POST /auth/register — register new user
- POST /auth/login — login with email/password, return JWT
...
```

The first line tells TaskLot which agent to load. Everything after is the task.
