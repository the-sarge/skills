#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

repo_input="${1:-.}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'error: required command not found: %s\n' "$1" >&2
    exit 2
  fi
}

require_command git
require_command rg
require_command yq

repo_root="$(git -C "$repo_input" rev-parse --show-toplevel 2>/dev/null)" || {
  printf 'error: not a git repository: %s\n' "$repo_input" >&2
  exit 2
}

relative_path() {
  case "$1" in
    "$repo_root"/*) printf '%s\n' "${1#"$repo_root"/}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

printf '# CI audit: %s\n\n' "$(basename "$repo_root")"
printf -- '- Repository: `%s`\n' "$repo_root"
printf -- '- Branch: `%s`\n' "$(git -C "$repo_root" branch --show-current 2>/dev/null || true)"
printf -- '- HEAD: `%s`\n' "$(git -C "$repo_root" rev-parse --short HEAD)"
printf -- '- Origin: `%s`\n' "$(git -C "$repo_root" remote get-url origin 2>/dev/null || printf 'none')"
status_count="$(git -C "$repo_root" status --short | wc -l | tr -d ' ')"
printf -- '- Worktree changes: `%s`\n\n' "$status_count"

printf '## Build entry points\n\n'
entry_points="$(find "$repo_root" -maxdepth 1 -type f \( -iname 'taskfile.yml' -o -iname 'taskfile.yaml' -o -name 'Makefile' -o -name 'Justfile' \) -print | sort)"
entry_count=0
while IFS= read -r entry_path; do
  test -n "$entry_path" || continue
  printf -- '- `%s`\n' "$(basename "$entry_path")"
  entry_count=$((entry_count + 1))
done <<< "$entry_points"
if test "$entry_count" -eq 0; then
  printf -- '- None found\n'
fi

taskfile="$(find "$repo_root" -maxdepth 1 -type f \( -iname 'taskfile.yml' -o -iname 'taskfile.yaml' \) -print -quit)"
if test -n "$taskfile"; then
  lane_tasks="$(yq -r '.tasks // {} | keys | .[] | select(test("(^|:)(docs(-check)?|check|verify|ci|deep(-check)?|race|vuln|security(-gate)?|release(-check)?)$"))' "$taskfile" 2>/dev/null || true)"
  if test -n "$lane_tasks"; then
    printf '\nCandidate validation tasks:\n\n'
    while IFS= read -r task_name; do
      test -n "$task_name" && printf -- '- `%s`\n' "$task_name"
    done <<< "$lane_tasks"
  fi
fi

printf '\n## Workflows\n\n'
workflow_dir="$repo_root/.github/workflows"
if ! test -d "$workflow_dir"; then
  printf 'No checked-in GitHub Actions workflows found.\n\n'
  printf '## Policy signals\n\n- No workflow findings.\n'
  exit 0
fi

workflow_list="$(find "$workflow_dir" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) -print | sort)"
if test -z "$workflow_list"; then
  printf 'No checked-in GitHub Actions workflows found.\n\n'
  printf '## Policy signals\n\n- No workflow findings.\n'
  exit 0
fi

signals=""
append_signal() {
  if test -z "$signals"; then
    signals="$1"
  else
    signals="$signals
$1"
  fi
}

trigger_state() {
  workflow_file="$1"
  trigger="$2"
  if test "$(yq -r ".on | has(\"$trigger\")" "$workflow_file")" != true; then
    printf 'absent\n'
  elif test "$(yq -r "((.on.$trigger // {}) | has(\"paths\")) or ((.on.$trigger // {}) | has(\"paths-ignore\"))" "$workflow_file")" = true; then
    printf 'filtered\n'
  else
    printf 'unfiltered\n'
  fi
}

while IFS= read -r workflow; do
  test -n "$workflow" || continue
  rel="$(relative_path "$workflow")"
  workflow_name="$(yq -r '.name // "unnamed"' "$workflow")"
  job_count="$(yq -r '.jobs // {} | length' "$workflow")"
  trigger_json="$(yq -o=json -I=0 '.on // {}' "$workflow")"
  if test "$(yq -r 'has("concurrency")' "$workflow")" = true; then
    concurrency_state=configured
  else
    concurrency_state=missing
  fi
  pr_state="$(trigger_state "$workflow" pull_request)"
  push_state="$(trigger_state "$workflow" push)"
  missing_timeouts="$(yq -r '[.jobs // {} | to_entries[] | select(.value["timeout-minutes"] == null) | .key] | join(", ")' "$workflow")"
  runners="$(yq -r '(.jobs // {}) | to_entries | .[] | "\(.key)=\(.value[\"runs-on\"] | @json)"' "$workflow")"

  printf '### `%s` — %s\n\n' "$rel" "$workflow_name"
  printf -- '- Jobs: `%s`\n' "$job_count"
  printf -- '- Triggers: `%s`\n' "$trigger_json"
  printf -- '- Pull request paths: `%s`\n' "$pr_state"
  printf -- '- Push paths: `%s`\n' "$push_state"
  printf -- '- Concurrency: `%s`\n' "$concurrency_state"
  if test -n "$missing_timeouts"; then
    printf -- '- Jobs missing timeouts: `%s`\n' "$missing_timeouts"
  else
    printf -- '- Jobs missing timeouts: none\n'
  fi
  printf -- '- Runners:\n'
  while IFS= read -r runner; do
    test -n "$runner" && printf '  - `%s`\n' "$runner"
  done <<< "$runners"
  printf '\n'

  if test "$concurrency_state" = missing && { test "$pr_state" != absent || test "$push_state" != absent; }; then
    append_signal "WARN $rel: automatic workflow has no concurrency policy"
  fi
  if test -n "$missing_timeouts"; then
    append_signal "WARN $rel: jobs missing timeout-minutes: $missing_timeouts"
  fi
  if test "$pr_state" = unfiltered; then
    append_signal "REVIEW $rel: pull_request trigger is not path-filtered; use internal classification when the check is required"
  fi
  if test "$push_state" = unfiltered; then
    append_signal "REVIEW $rel: push trigger is not path-filtered; check for full PR plus merged-push duplication"
  fi
  if printf '%s\n' "$runners" | rg -qi 'macos|windows'; then
    append_signal "COST $rel: uses macOS or Windows runners"
  fi
  if rg -q 'go test[[:space:]]+([^\n]*[[:space:]])?\./\.\.\.' "$workflow" && rg -q 'go test[[:space:]]+-race([^\n]*)?\./\.\.\.|go test([^\n]*)[[:space:]]-race([^\n]*)?\./\.\.\.' "$workflow"; then
    append_signal "DUPLICATE $rel: contains both ordinary and race runs of ./..."
  fi
done <<< "$workflow_list"

printf '## Cross-file duplication signals\n\n'
search_files=("$workflow_dir")
if test -n "$taskfile"; then
  search_files+=("$taskfile")
fi
govuln_refs="$({ rg -n --no-heading 'govulncheck' "${search_files[@]}" 2>/dev/null || true; } | wc -l | tr -d ' ')"
race_refs="$({ rg -n --no-heading 'go test[^\n]*-race' "${search_files[@]}" 2>/dev/null || true; } | wc -l | tr -d ' ')"
printf -- '- `govulncheck` references: `%s`\n' "$govuln_refs"
printf -- '- race-test command references: `%s`\n' "$race_refs"
if test "$govuln_refs" -gt 1; then
  append_signal "DUPLICATE repository: multiple govulncheck references require intent review"
fi

printf '\n## Policy signals\n\n'
if test -z "$signals"; then
  printf -- '- No mechanical warnings. Perform semantic review before declaring the CI efficient.\n'
else
  while IFS= read -r signal; do
    test -n "$signal" && printf -- '- %s\n' "$signal"
  done <<< "$signals"
fi

printf '\nThis report is read-only and mechanical. Confirm required checks, changed-file semantics, recent runs, billing, private dependencies, generated docs, and platform constraints separately.\n'
