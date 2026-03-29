#!/usr/bin/env bash
###############################################################################
#  TaskLot Puller: GitHub Issues
#  Fetches tasks from GitHub Issues using the gh CLI
#
#  Required config fields:
#    task_source.config.repo            — GitHub repo (e.g. "owner/repo")
#    task_source.config.label           — Optional: filter by label
#    task_source.config.milestone       — Optional: filter by milestone
###############################################################################

PULLER_NAME="github"
PULLER_VERSION="1.0.0"

check_puller() {
  if ! command -v gh &>/dev/null; then
    echo "Error: GitHub CLI (gh) required. Install: brew install gh"
    exit 1
  fi
}

pull_tasks() {
  local config_file="$1"
  local output_file="$2"

  check_puller

  local repo
  repo=$(jq -r '.task_source.config.repo // empty' "$config_file")

  if [[ -z "$repo" ]]; then
    echo "Error: task_source.config.repo not set in config"
    return 1
  fi

  local label
  label=$(jq -r '.task_source.config.label // empty' "$config_file")

  local milestone
  milestone=$(jq -r '.task_source.config.milestone // empty' "$config_file")

  # Build gh command
  local gh_args="issue list --repo ${repo} --state open --json number,title,body,labels,milestone --limit 100"

  if [[ -n "$label" ]]; then
    gh_args+=" --label ${label}"
  fi

  if [[ -n "$milestone" ]]; then
    gh_args+=" --milestone ${milestone}"
  fi

  # Fetch issues via gh CLI
  local raw_issues
  raw_issues=$(gh $gh_args 2>&1)

  if [[ $? -ne 0 ]]; then
    echo "Error: Failed to fetch GitHub issues: ${raw_issues}"
    return 1
  fi

  # Transform GitHub issues JSON into TaskLot format
  echo "$raw_issues" | jq '{
    pulled_at: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
    source: "github",
    source_config: {
      repo: "'"${repo}"'"
    },
    tasks: [
      .[] | {
        id: ("TASK-" + (.number | tostring | if (. | length) < 3 then ("000" + .)[-3:] else . end)),
        title: .title,
        description: (.body // ""),
        status: "pending",
        priority: (
          if (.labels | map(.name) | any(. == "priority:high" or . == "P0" or . == "P1" or . == "urgent")) then "high"
          elif (.labels | map(.name) | any(. == "priority:low" or . == "P3" or . == "P4")) then "low"
          else "medium"
          end
        ),
        source_id: (.number | tostring),
        completed_at: null,
        failure_reason: null
      }
    ]
  }' 2>&1
}
