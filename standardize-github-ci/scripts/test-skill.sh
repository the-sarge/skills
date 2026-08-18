#!/usr/bin/env bash
# Forward tests for the standardize-github-ci skill: assets, classifier, audit, docs.
# shellcheck disable=SC2034,SC2016
# SC2034: repo_root/classify/taskfile_asset/ruleset_asset/audit are used by
#         later sections appended under the markers below.
# SC2016: single quotes are intentional where they hold literal GitHub
#         Actions expression syntax (e.g. ${{ ... }}), not shell expansion.
set -euo pipefail

skill_root="$(cd "$(dirname "$0")/.." && pwd)"
repo_root="$(cd "$skill_root/.." && pwd)"
workflow_asset="$skill_root/assets/ci.yml"
classify="$skill_root/assets/ci-classify.sh"
taskfile_asset="$skill_root/assets/Taskfile.ci.yml"
ruleset_asset="$skill_root/assets/ruleset.json"
audit="$skill_root/scripts/audit-ci.sh"

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

for tool in yq jq rg git; do
  command -v "$tool" >/dev/null || fail "required tool not found: $tool"
done

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# --- assets

test -f "$workflow_asset" || fail "missing $workflow_asset"
yq eval '.' "$workflow_asset" >/dev/null
test "$(yq -o=json -I=0 '.on | keys' "$workflow_asset")" = '["pull_request"]' || fail 'ci.yml: trigger must be exactly pull_request'
test "$(yq -o=json -I=0 '.on.pull_request | keys' "$workflow_asset")" = '["types"]' || fail 'ci.yml: pull_request must carry only types'
test "$(yq -o=json -I=0 '.on.pull_request.types | sort' "$workflow_asset")" = '["opened","ready_for_review","reopened","synchronize"]' || fail 'ci.yml: wrong pull_request types'
test "$(yq -r '.concurrency.group' "$workflow_asset")" = 'ci-${{ github.event.pull_request.number }}' || fail 'ci.yml: concurrency group'
test "$(yq -r '.concurrency["cancel-in-progress"]' "$workflow_asset")" = true || fail 'ci.yml: cancel-in-progress'
test "$(yq -o=json -I=0 '.permissions' "$workflow_asset")" = '{"contents":"read"}' || fail 'ci.yml: permissions'
test "$(yq -o=json -I=0 '.jobs | keys' "$workflow_asset")" = '["ci-required"]' || fail 'ci.yml: exactly one job named ci-required'
job_if="$(yq -r '.jobs["ci-required"].if' "$workflow_asset")"
printf '%s' "$job_if" | rg -Fq '!github.event.pull_request.draft' || fail 'ci.yml: draft guard'
printf '%s' "$job_if" | rg -Fq 'github.event.pull_request.head.repo.full_name == github.repository' || fail 'ci.yml: same-repo guard'
test "$(yq -r '.jobs["ci-required"]["timeout-minutes"]' "$workflow_asset")" = 30 || fail 'ci.yml: timeout'
test "$(yq -r '.jobs["ci-required"] | has("needs")' "$workflow_asset")" = false || fail 'ci.yml: needs must be absent'
test "$(yq -r '.jobs["ci-required"] | has("strategy")' "$workflow_asset")" = false || fail 'ci.yml: strategy must be absent'
test "$(yq -o=json -I=0 '[.jobs["ci-required"].steps[] | select(has("run")) | .run]' "$workflow_asset")" = '["task ci"]' || fail 'ci.yml: exactly one run step, task ci'
while IFS= read -r uses; do
  printf '%s' "$uses" | rg -q '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+@[0-9a-f]{40}$' || fail "ci.yml: unpinned action: $uses"
done < <(yq -r '.jobs["ci-required"].steps[] | select(has("uses")) | .uses' "$workflow_asset")
test "$(yq -r '.jobs["ci-required"].steps[] | select(.uses | test("^actions/checkout@")) | .with["fetch-depth"]' "$workflow_asset")" = 0 || fail 'ci.yml: checkout fetch-depth 0'
if rg -qi 'ras|certify|expected_sha|statuses' "$workflow_asset"; then
  fail 'ci.yml: exposes review-tool or dispatch state'
fi
if command -v actionlint >/dev/null; then
  actionlint "$workflow_asset"
fi

# --- classifier

# --- audit

# --- docs

printf 'skill fixtures passed\n'
