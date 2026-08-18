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
uses_step_count="$(yq -r '[.jobs["ci-required"].steps[] | select(has("uses"))] | length' "$workflow_asset")"
pinned_with_version_count="$(rg -c 'uses: .*@[0-9a-f]{40} # v[0-9]+\.[0-9]+\.[0-9]+$' "$workflow_asset" || true)"
test "${pinned_with_version_count:-0}" = "$uses_step_count" || fail 'ci.yml: every pinned action must carry a trailing # vX.Y.Z comment'
test "$(yq -r '.jobs["ci-required"].steps[] | select(.uses | test("^actions/checkout@")) | .with["fetch-depth"]' "$workflow_asset")" = 0 || fail 'ci.yml: checkout fetch-depth 0'
if rg -qi 'ras|certify|expected_sha|statuses' "$workflow_asset"; then
  fail 'ci.yml: exposes review-tool or dispatch state'
fi
if command -v actionlint >/dev/null; then
  actionlint "$workflow_asset"
fi

# --- classifier

test -x "$classify" || fail "missing or non-executable $classify"

cls_repo="$tmp/classify-repo"
mkdir -p "$cls_repo/docs" "$cls_repo/pkg"
git -C "$cls_repo" init -q -b main
git -C "$cls_repo" config user.email ci-skill-test@example.invalid
git -C "$cls_repo" config user.name ci-skill-test
printf '# readme\n' > "$cls_repo/README.md"
printf 'package pkg\n' > "$cls_repo/pkg/pkg.go"
git -C "$cls_repo" add . && git -C "$cls_repo" commit -qm initial

classify_in() { (cd "$cls_repo" && env "$@" "$classify" 2>/dev/null); }

# empty diff on main -> fail closed
test "$(classify_in CI_DEFAULT_BRANCH=main)" = 'docs_only=false' || fail 'classifier: empty diff must be docs_only=false'

git -C "$cls_repo" checkout -qb docs-branch
printf 'more\n' >> "$cls_repo/README.md"
mkdir -p "$cls_repo/docs/deep" && printf 'note\n' > "$cls_repo/docs/deep/notes.txt"
printf 'entry\n' > "$cls_repo/DEV-JOURNAL.md"
git -C "$cls_repo" add . && git -C "$cls_repo" commit -qm docs
test "$(classify_in CI_DEFAULT_BRANCH=main)" = 'docs_only=true' || fail 'classifier: markdown, docs/**, DEV-JOURNAL.md must be docs_only=true'

# unknown extension outside docs/ -> not docs
printf 'x\n' > "$cls_repo/notes.txt"
git -C "$cls_repo" add . && git -C "$cls_repo" commit -qm txt
test "$(classify_in CI_DEFAULT_BRANCH=main)" = 'docs_only=false' || fail 'classifier: unknown extension must be docs_only=false'
# allowlist extension via CI_DOCS_GLOBS
test "$(classify_in CI_DEFAULT_BRANCH=main CI_DOCS_GLOBS='*.md docs/* DEV-JOURNAL.md *.txt')" = 'docs_only=true' || fail 'classifier: CI_DOCS_GLOBS must extend the allowlist'

# source change -> not docs
printf 'var Changed = true\n' >> "$cls_repo/pkg/pkg.go"
git -C "$cls_repo" add . && git -C "$cls_repo" commit -qm source
test "$(classify_in CI_DEFAULT_BRANCH=main)" = 'docs_only=false' || fail 'classifier: source change must be docs_only=false'

# explicit base wins
docs_head="$(git -C "$cls_repo" rev-parse HEAD~2)"
test "$(classify_in CI_DEFAULT_BRANCH=main CI_HEAD_SHA="$docs_head" CI_BASE_SHA=main)" = 'docs_only=true' || fail 'classifier: CI_BASE_SHA/CI_HEAD_SHA must be honoured'

# missing base -> fail closed, still exit 0
test "$(classify_in CI_DEFAULT_BRANCH=does-not-exist)" = 'docs_only=false' || fail 'classifier: unknown base must be docs_only=false'
(cd "$cls_repo" && CI_DEFAULT_BRANCH=does-not-exist "$classify" >/dev/null 2>&1) || fail 'classifier: must exit 0 when failing closed'

# GITHUB_OUTPUT mirror
gh_out="$tmp/github-output"
: > "$gh_out"
(cd "$cls_repo" && GITHUB_OUTPUT="$gh_out" CI_DEFAULT_BRANCH=main "$classify" >/dev/null 2>&1)
test "$(cat "$gh_out")" = 'docs_only=false' || fail 'classifier: GITHUB_OUTPUT mirror'

# no globbing against the working tree: a file literally named '*.md' must not widen the match
git -C "$cls_repo" checkout -q main
git -C "$cls_repo" checkout -qb glob-branch
printf 'x\n' > "$cls_repo/pkg/other.go"
touch "$cls_repo/*.md"
git -C "$cls_repo" add . && git -C "$cls_repo" commit -qm glob
test "$(classify_in CI_DEFAULT_BRANCH=main)" = 'docs_only=false' || fail 'classifier: must not pathname-expand globs'

# --- audit

# --- docs

printf 'skill fixtures passed\n'
