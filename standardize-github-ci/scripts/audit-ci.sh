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
require_command jq
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
printf -- '- Worktree changes: `%s`\n' "$status_count"

case "${CI_USES_RAS:-}" in
  true)
    uses_ras=true
    ras_source='CI_USES_RAS=true'
    ;;
  false)
    uses_ras=false
    ras_source='CI_USES_RAS=false'
    ;;
  "")
    if test -f "$repo_root/.ras/config.yaml" || rg -qi --hidden --glob '!.git/**' 'ras[[:space:]]+(review|verify|review-fix|review-loop)|RAS[- ]first|RAS review' "$repo_root"; then
      uses_ras=true
      ras_source='repository evidence'
    else
      uses_ras=false
      ras_source='not detected'
    fi
    ;;
  *)
    printf 'error: CI_USES_RAS must be true, false, or unset\n' >&2
    exit 2
    ;;
esac
printf -- '- RAS-first review gate: `%s` (%s)\n\n' "$uses_ras" "$ras_source"

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
  on_json="$(yq -o=json -I=0 '.on // {}' "$workflow_file")"
  if ! printf '%s\n' "$on_json" | jq -e --arg trigger "$trigger" '
    if type == "string" then . == $trigger
    elif type == "array" then index($trigger) != null
    elif type == "object" then has($trigger)
    else false
    end
  ' >/dev/null; then
    printf 'absent\n'
  elif printf '%s\n' "$on_json" | jq -e --arg trigger "$trigger" '
    type == "object" and (.[$trigger] | type == "object") and ((.[$trigger] | has("paths")) or (.[$trigger] | has("paths-ignore")))
  ' >/dev/null; then
    printf 'filtered\n'
  else
    printf 'unfiltered\n'
  fi
}

dispatch_sha_binding_state() {
  workflow="$1"
  sha_inputs="$(yq -r '(.on.workflow_dispatch.inputs // {}) | keys | .[]' "$workflow" | rg -i '(^|_)(expected|reviewed|head)?_?sha($|_)' || true)"
  test -n "$sha_inputs" || {
    printf 'not detected'
    return
  }

  jobs_json="$(yq -o=json -I=0 '.jobs // {}' "$workflow")"
  while IFS= read -r sha_input; do
    test -n "$sha_input" || continue
    if printf '%s\n' "$jobs_json" | rg -Fq "inputs.$sha_input" && printf '%s\n' "$jobs_json" | rg -q 'GITHUB_SHA|github\.sha'; then
      printf 'detected; verify the comparison fails closed'
      return
    fi
  done <<< "$sha_inputs"

  printf 'not detected'
}

pull_request_activity_state() {
  workflow="$1"
  on_json="$(yq -o=json -I=0 '.on // {}' "$workflow")"
  if ! printf '%s\n' "$on_json" | jq -e '
    if type == "string" then . == "pull_request"
    elif type == "array" then index("pull_request") != null
    elif type == "object" then has("pull_request")
    else false
    end
  ' >/dev/null; then
    printf 'absent'
  elif printf '%s\n' "$on_json" | jq -e '
    type == "object" and
    (.pull_request | type == "object") and
    ((.pull_request.types // []) == ["labeled"])
  ' >/dev/null; then
    printf 'label-only operator trigger'
  else
    printf 'automatic updates'
  fi
}

label_certification_state() {
  workflow="$1"
  activity_state="$(pull_request_activity_state "$workflow")"
  test "$activity_state" = 'label-only operator trigger' || {
    printf 'not detected'
    return
  }

  jobs_json="$(yq -o=json -I=0 '.jobs // {}' "$workflow")"
  if printf '%s\n' "$jobs_json" | rg -Fq 'github.event.label.name' &&
    printf '%s\n' "$jobs_json" | rg -Fq 'github.event.pull_request.head.sha' &&
    printf '%s\n' "$jobs_json" | rg -Fq 'github.event.pull_request.base.sha' &&
    printf '%s\n' "$jobs_json" | rg -Fq 'github.sha' &&
    printf '%s\n' "$jobs_json" | rg -Fq 'merge_commit_sha' &&
    printf '%s\n' "$jobs_json" | rg -Fq 'head.repo.full_name' &&
    printf '%s\n' "$jobs_json" | rg -Fq 'base.repo.full_name' &&
    printf '%s\n' "$jobs_json" | rg -Fq -- '--method DELETE' &&
    printf '%s\n' "$jobs_json" | rg -Fq '/labels/'; then
    printf 'detected; verify label revocation and head/base/merge comparisons fail closed'
  else
    printf 'not detected; label-only trigger lacks complete binding evidence'
  fi
}

manual_workflow_count=0
automatic_pr_workflow_count=0
exact_head_dispatch_count=0
label_certification_count=0

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
  pr_activity_state="$(pull_request_activity_state "$workflow")"
  pr_target_state="$(trigger_state "$workflow" pull_request_target)"
  push_state="$(trigger_state "$workflow" push)"
  dispatch_state="$(trigger_state "$workflow" workflow_dispatch)"
  missing_timeouts="$(yq -r '[.jobs // {} | to_entries[] | select(.value["timeout-minutes"] == null) | .key] | join(", ")' "$workflow")"
  runners="$(yq -r '(.jobs // {}) | to_entries | .[] | "\(.key)=\(.value[\"runs-on\"] | @json)"' "$workflow")"

  printf '### `%s` — %s\n\n' "$rel" "$workflow_name"
  printf -- '- Jobs: `%s`\n' "$job_count"
  printf -- '- Triggers: `%s`\n' "$trigger_json"
  printf -- '- Pull request paths: `%s`\n' "$pr_state"
  printf -- '- Pull request activity: `%s`\n' "$pr_activity_state"
  printf -- '- Pull request target paths: `%s`\n' "$pr_target_state"
  printf -- '- Push paths: `%s`\n' "$push_state"
  if test "$dispatch_state" = absent; then
    printf -- '- Manual dispatch: absent\n'
  else
    printf -- '- Manual dispatch: present\n'
    manual_workflow_count=$((manual_workflow_count + 1))
    dispatch_sha_binding="$(dispatch_sha_binding_state "$workflow")"
    printf -- '- Exact-head dispatch binding: `%s`\n' "$dispatch_sha_binding"
    if test "$dispatch_sha_binding" != 'not detected'; then
      exact_head_dispatch_count=$((exact_head_dispatch_count + 1))
    fi
  fi
  label_certification="$(label_certification_state "$workflow")"
  if test "$pr_activity_state" = 'label-only operator trigger'; then
    printf -- '- Label-gated certification binding: `%s`\n' "$label_certification"
    if test "$label_certification" = 'detected; verify label revocation and head/base/merge comparisons fail closed'; then
      label_certification_count=$((label_certification_count + 1))
    fi
  fi
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

  if test "$concurrency_state" = missing && { test "$pr_state" != absent || test "$pr_target_state" != absent || test "$push_state" != absent; }; then
    append_signal "WARN $rel: automatic workflow has no concurrency policy"
  fi
  if test -n "$missing_timeouts"; then
    append_signal "WARN $rel: jobs missing timeout-minutes: $missing_timeouts"
  fi
  if test "$pr_state" = unfiltered && test "$pr_activity_state" != 'label-only operator trigger'; then
    append_signal "REVIEW $rel: pull_request trigger is not path-filtered; use internal classification when the check is required"
  fi
  if test "$pr_target_state" != absent; then
    append_signal "SECURITY $rel: pull_request_target requires explicit untrusted-code and secret-boundary review"
  fi
  if test "$pr_activity_state" = 'automatic updates' || test "$pr_target_state" != absent; then
    automatic_pr_workflow_count=$((automatic_pr_workflow_count + 1))
    if test "$uses_ras" = true; then
      append_signal "RAS-COST $rel: automatically starts on pull request updates before the RAS gate settles; separate preflight or use dispatch-gated certification"
    fi
  fi
  if test "$uses_ras" = true && test "$pr_activity_state" = 'label-only operator trigger' && test "$label_certification" != 'detected; verify label revocation and head/base/merge comparisons fail closed'; then
    append_signal "RAS-BLOCKER $rel: label-only certification lacks one-shot revocation or exact head/base/merge binding evidence"
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

if test "$uses_ras" = true && test "$exact_head_dispatch_count" -eq 0 && test "$label_certification_count" -eq 0; then
  if test "$manual_workflow_count" -eq 0; then
    append_signal "RAS-BLOCKER repository: no operator-triggered exact-head certification path was detected"
  else
    append_signal "RAS-BLOCKER repository: operator-triggered certification exists but no exact-head binding evidence was detected"
  fi
fi

printf '## RAS sequencing\n\n'
printf -- '- Automatic pull-request workflows: `%s`\n' "$automatic_pr_workflow_count"
printf -- '- Manual-dispatch workflows: `%s`\n' "$manual_workflow_count"
printf -- '- Exact-head dispatch candidates: `%s`\n' "$exact_head_dispatch_count"
printf -- '- Label-gated certification candidates: `%s`\n\n' "$label_certification_count"

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

printf '\nThis report is read-only and mechanical. Confirm required checks, changed-file semantics, recent runs, billing, private dependencies, generated docs, platform constraints, and any RAS-reviewed-to-dispatched SHA handoff separately.\n'
