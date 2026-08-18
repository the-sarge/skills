#!/usr/bin/env bash
# Read-only conformance audit of one repository against the portfolio CI standard
# (standardize-github-ci/references/ci-policy.md).
#
# Usage: audit-ci.sh [repository-path]
# Env:   CI_AUDIT_RULESET_JSON=<file>  audit default-branch rules from this JSON (array from
#                                      GET /repos/{o}/{r}/rules/branches/{branch}) instead of GitHub
#        CI_AUDIT_RULESET=live         query GitHub with gh for the default-branch rules
# Exit:  0 conformant, 3 deviations found, 2 usage or tool error.
#
# shellcheck disable=SC2016
# SC2016: single quotes are intentional throughout; they hold jq programs and
#         literal GitHub Actions expression syntax, not shell expansions.
set -euo pipefail

repo_input="${1:-.}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'error: required command not found: %s\n' "$1" >&2
    exit 2
  fi
}
require_command git
require_command jq
require_command yq

repo_root="$(git -C "$repo_input" rev-parse --show-toplevel 2>/dev/null)" || {
  printf 'error: not a git repository: %s\n' "$repo_input" >&2
  exit 2
}

deviations=""
deviate() { # code, message
  if test -z "$deviations"; then
    deviations="- \`$1\` $2"
  else
    deviations="$deviations
- \`$1\` $2"
  fi
}

# --- header
printf '# CI conformance audit: %s\n\n' "$(basename "$repo_root")"
printf -- '- Repository: `%s`\n' "$repo_root"
printf -- '- Branch: `%s`\n' "$(git -C "$repo_root" branch --show-current 2>/dev/null || true)"
printf -- '- HEAD: `%s`\n' "$(git -C "$repo_root" rev-parse --short HEAD)"
printf -- '- Origin: `%s`\n\n' "$(git -C "$repo_root" remote get-url origin 2>/dev/null || printf 'none')"

# --- required workflow
workflow_dir="$repo_root/.github/workflows"
ci_yml="$workflow_dir/ci.yml"
required_jobs=""
printf '## Required workflow `.github/workflows/ci.yml`\n\n'
if ! test -f "$ci_yml"; then
  printf -- '- Missing\n\n'
  deviate CI-MISSING '.github/workflows/ci.yml: required workflow not found'
else
  wf="$(yq -o=json -I=0 '.' "$ci_yml")"
  j() { printf '%s' "$wf" | jq -e "$1" >/dev/null 2>&1; }

  j '(.on|type=="object") and (.on|keys)==["pull_request"] and (.on.pull_request|type=="object") and (.on.pull_request|keys)==["types"] and ((.on.pull_request.types|sort)==["opened","ready_for_review","reopened","synchronize"])' \
    || deviate CI-TRIGGER 'ci.yml: trigger must be exactly pull_request with types [opened, synchronize, reopened, ready_for_review] and no paths or branches filters'
  j '(.concurrency.group|type=="string") and (.concurrency.group|contains("github.event.pull_request.number")) and .concurrency["cancel-in-progress"]==true' \
    || deviate CI-CONCURRENCY 'ci.yml: concurrency must group by github.event.pull_request.number with cancel-in-progress: true'
  j '.permissions == {"contents":"read"}' \
    || deviate CI-PERMISSIONS 'ci.yml: workflow permissions must be exactly contents: read'
  j '(.jobs|type=="object") and (.jobs|has("ci-required"))' \
    || deviate CI-JOBS 'ci.yml: job ci-required is required'

  job_names="$(printf '%s' "$wf" | jq -r '.jobs // {} | keys_unsorted[]')"
  while IFS= read -r job; do
    test -n "$job" || continue
    case "$job" in
      ci-required) target='task ci' ;;
      ci-*) target="task $job" ;;
      *) deviate CI-JOB-NAME "ci.yml: job $job must be named ci-required or ci-<lane>"; continue ;;
    esac
    required_jobs="${required_jobs:+$required_jobs, }\`$job\`"
    jj() { printf '%s' "$wf" | jq -e --arg job "$job" ".jobs[\$job] | $1" >/dev/null 2>&1; }
    jj '(.if|type=="string") and (.if|contains("!github.event.pull_request.draft")) and (.if|contains("github.event.pull_request.head.repo.full_name == github.repository"))' \
      || deviate CI-GUARD "ci.yml: job $job must guard with !github.event.pull_request.draft && head.repo.full_name == github.repository"
    jj '.["timeout-minutes"]|type=="number"' \
      || deviate CI-TIMEOUT "ci.yml: job $job must set timeout-minutes"
    jj 'has("needs")|not' \
      || deviate CI-NEEDS "ci.yml: job $job must not declare needs; required jobs are independent"
    jj '(.strategy.matrix // null) == null' \
      || deviate CI-MATRIX "ci.yml: job $job must not use a matrix; route by job, not by matrix"
    printf '%s' "$wf" | jq -e --arg job "$job" --arg t "$target" '[.jobs[$job].steps[]? | select(has("run")) | .run] == [$t]' >/dev/null 2>&1 \
      || deviate CI-TARGET "ci.yml: job $job must run exactly one step: $target"
    while IFS= read -r uses; do
      test -n "$uses" || continue
      printf '%s' "$uses" | grep -Eq '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(/[A-Za-z0-9_./-]+)?@[0-9a-f]{40}$' \
        || deviate CI-PIN "ci.yml: job $job uses unpinned action $uses"
    done <<< "$(printf '%s' "$wf" | jq -r --arg job "$job" '.jobs[$job].steps[]? | select(has("uses")) | .uses')"
    printf '%s' "$wf" | jq -e --arg job "$job" '[.jobs[$job].steps[]? | select((.uses // "") | startswith("actions/checkout@")) | .with["fetch-depth"]] | length > 0 and all(. == 0)' >/dev/null 2>&1 \
      || deviate CI-FETCH-DEPTH "ci.yml: job $job must check out with fetch-depth: 0"
  done <<< "$job_names"

  printf -- '- Required jobs: %s\n' "${required_jobs:-none}"
  printf -- '- Runners:\n'
  printf '%s' "$wf" | jq -r '.jobs // {} | to_entries[] | "  - `\(.key)` = `\(.value["runs-on"] | tostring)`"'
  printf '\n'
fi

# --- deviations
printf '## Deviations\n\n'
if test -z "$deviations"; then
  printf -- '- None. Repository conforms to the standard.\n'
  exit 0
fi
printf '%s\n' "$deviations"
exit 3
