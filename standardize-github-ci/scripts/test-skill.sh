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

test -f "$taskfile_asset" || fail "missing $taskfile_asset"
yq eval '.' "$taskfile_asset" >/dev/null
for t in ci ci-race docs-check check; do
  test "$(yq -r ".tasks | has(\"$t\")" "$taskfile_asset")" = true || fail "Taskfile.ci.yml: missing task $t"
done
rg -Fq 'scripts/ci-classify.sh' "$taskfile_asset" || fail 'Taskfile.ci.yml: ci must call scripts/ci-classify.sh'
rg -Fq 'docs_only=true' "$taskfile_asset" || fail 'Taskfile.ci.yml: ci must branch on docs_only=true'

test -f "$ruleset_asset" || fail "missing $ruleset_asset"
jq -e '.target == "branch" and .enforcement == "active"' "$ruleset_asset" >/dev/null || fail 'ruleset.json: target/enforcement'
jq -e '.conditions.ref_name.include == ["~DEFAULT_BRANCH"]' "$ruleset_asset" >/dev/null || fail 'ruleset.json: must target the default branch'
jq -e '[.rules[].type] | sort == ["deletion","non_fast_forward","pull_request","required_status_checks"]' "$ruleset_asset" >/dev/null || fail 'ruleset.json: rule set'
jq -e '.rules[] | select(.type=="pull_request") | .parameters.allowed_merge_methods == ["squash"]' "$ruleset_asset" >/dev/null || fail 'ruleset.json: squash only'
jq -e '.rules[] | select(.type=="required_status_checks") | .parameters.strict_required_status_checks_policy == true' "$ruleset_asset" >/dev/null || fail 'ruleset.json: strict up-to-date'
jq -e '.rules[] | select(.type=="required_status_checks") | .parameters.required_status_checks == [{"context":"ci-required","integration_id":15368}]' "$ruleset_asset" >/dev/null || fail 'ruleset.json: required check ci-required from Actions'

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
docs_commit="$(git -C "$cls_repo" rev-parse HEAD)"
test "$(classify_in CI_DEFAULT_BRANCH=main)" = 'docs_only=true' || fail 'classifier: markdown, docs/**, DEV-JOURNAL.md must be docs_only=true'

# unknown extension outside docs/ -> not docs
printf 'x\n' > "$cls_repo/notes.txt"
git -C "$cls_repo" add . && git -C "$cls_repo" commit -qm txt
test "$(classify_in CI_DEFAULT_BRANCH=main)" = 'docs_only=false' || fail 'classifier: unknown extension must be docs_only=false'
# allowlist extension via CI_DOCS_GLOBS
test "$(classify_in CI_DEFAULT_BRANCH=main CI_DOCS_GLOBS='*.md docs/* DEV-JOURNAL.md *.txt')" = 'docs_only=true' || fail 'classifier: CI_DOCS_GLOBS must extend the allowlist'

# source change -> not docs (fresh branch off main so the diff contains only the .go change)
git -C "$cls_repo" checkout -q main
git -C "$cls_repo" checkout -qb src-branch
printf 'var Changed = true\n' >> "$cls_repo/pkg/pkg.go"
git -C "$cls_repo" add . && git -C "$cls_repo" commit -qm source
test "$(classify_in CI_DEFAULT_BRANCH=main)" = 'docs_only=false' || fail 'classifier: source change must be docs_only=false'

# explicit base wins
test "$(classify_in CI_DEFAULT_BRANCH=main CI_HEAD_SHA="$docs_commit" CI_BASE_SHA=main)" = 'docs_only=true' || fail 'classifier: CI_BASE_SHA/CI_HEAD_SHA must be honoured'

# missing base -> fail closed, still exit 0
test "$(classify_in CI_DEFAULT_BRANCH=does-not-exist)" = 'docs_only=false' || fail 'classifier: unknown base must be docs_only=false'
(cd "$cls_repo" && CI_DEFAULT_BRANCH=does-not-exist "$classify" >/dev/null 2>&1) || fail 'classifier: must exit 0 when failing closed'

# GITHUB_OUTPUT mirror
gh_out="$tmp/github-output"
: > "$gh_out"
(cd "$cls_repo" && GITHUB_OUTPUT="$gh_out" CI_DEFAULT_BRANCH=main "$classify" >/dev/null 2>&1)
test "$(cat "$gh_out")" = 'docs_only=false' || fail 'classifier: GITHUB_OUTPUT mirror'

# no globbing against the working tree: without set -f, docs/* would pathname-expand to the
# existing docs/nested directory and no longer match docs/nested/only.txt, yielding false
git -C "$cls_repo" checkout -q main
git -C "$cls_repo" checkout -qb glob-branch
mkdir -p "$cls_repo/docs/nested" && printf 'note\n' > "$cls_repo/docs/nested/only.txt"
git -C "$cls_repo" add . && git -C "$cls_repo" commit -qm glob
test "$(classify_in CI_DEFAULT_BRANCH=main)" = 'docs_only=true' || fail 'classifier: must not pathname-expand globs'

# --- audit

test -x "$audit" || fail "missing or non-executable $audit"

# helper: build a repo with the shipped assets in place; caller mutates then audits
make_conformant_repo() {
  dir="$1"
  mkdir -p "$dir/.github/workflows" "$dir/scripts"
  git -C "$dir" init -q -b main
  git -C "$dir" config user.email ci-skill-test@example.invalid
  git -C "$dir" config user.name ci-skill-test
  cp "$workflow_asset" "$dir/.github/workflows/ci.yml"
  cp "$classify" "$dir/scripts/ci-classify.sh"
  cp "$taskfile_asset" "$dir/Taskfile.yml"
  printf 'module example.test\n\ngo 1.22\n' > "$dir/go.mod"
  git -C "$dir" add . && git -C "$dir" commit -qm conformant
}

# Sets audit_out and audit_rc in the caller. Deliberately not used inside a
# command substitution: that subshell would discard audit_rc.
run_audit() { # dir [env...]
  dir="$1"; shift
  set +e
  audit_out="$(env "$@" "$audit" "$dir" 2>&1)"
  audit_rc=$?
  set -e
}

expect_deviation() { # output code
  printf '%s\n' "$1" | rg -Fq "\`$2\`" || fail "audit: expected deviation $2; got:
$1"
}

conf="$tmp/conformant"
make_conformant_repo "$conf"
run_audit "$conf"; out="$audit_out"
test "$audit_rc" -eq 0 || fail "audit: conformant repo must exit 0; got $audit_rc:
$out"
printf '%s\n' "$out" | rg -Fq -- '- None. Repository conforms to the standard.' || fail "audit: conformant repo must report no deviations:
$out"
printf '%s\n' "$out" | rg -Fq 'Required jobs: `ci-required`' || fail 'audit: must list required jobs'

# each mutation of ci.yml produces its named deviation and exit 3
mutate() { # code, yq-expression
  d="$tmp/mut-$1"
  rm -rf "$d"; make_conformant_repo "$d"
  yq -i "$2" "$d/.github/workflows/ci.yml"
  run_audit "$d"; out="$audit_out"
  test "$audit_rc" -eq 3 || fail "audit: $1 fixture must exit 3; got $audit_rc:
$out"
  expect_deviation "$out" "$1"
}
mutate CI-TRIGGER '.on.push = {"branches":["main"]}'
mutate CI-TRIGGER '.on.pull_request.types = ["opened","synchronize"]'
mutate CI-TRIGGER '.on.pull_request.paths = ["**.go"]'
mutate CI-CONCURRENCY 'del(.concurrency)'
mutate CI-CONCURRENCY '.concurrency["cancel-in-progress"] = false'
mutate CI-PERMISSIONS '.permissions.contents = "write"'
mutate CI-JOB-NAME '.jobs.build = .jobs["ci-required"] | .jobs.build.steps[-1].run = "task build"'
mutate CI-JOBS 'del(.jobs["ci-required"])'
mutate CI-GUARD '.jobs["ci-required"].if = "${{ !github.event.pull_request.draft }}"'
mutate CI-GUARD 'del(.jobs["ci-required"].if)'
mutate CI-TIMEOUT 'del(.jobs["ci-required"]["timeout-minutes"])'
mutate CI-NEEDS '.jobs["ci-lint"] = .jobs["ci-required"] | .jobs["ci-lint"].steps[-1].run = "task ci-lint" | .jobs["ci-required"].needs = ["ci-lint"]'
mutate CI-MATRIX '.jobs["ci-required"].strategy.matrix.os = ["ubuntu-latest","macos-latest"]'
mutate CI-TARGET '.jobs["ci-required"].steps[-1].run = "task check"'
mutate CI-TARGET '.jobs["ci-required"].steps += [{"run":"task extra"}]'
mutate CI-TARGET '.jobs["ci-race"] = .jobs["ci-required"]'
mutate CI-PIN '.jobs["ci-required"].steps[0].uses = "actions/checkout@v7"'
mutate CI-FETCH-DEPTH 'del(.jobs["ci-required"].steps[0].with)'

# a second well-formed lane is conformant
lane="$tmp/lane"
make_conformant_repo "$lane"
yq -i '.jobs["ci-race"] = .jobs["ci-required"] | .jobs["ci-race"]["runs-on"] = "self-hosted-xlarge" | .jobs["ci-race"].steps[-1].run = "task ci-race"' "$lane/.github/workflows/ci.yml"
git -C "$lane" commit -qam lane
run_audit "$lane"; out="$audit_out"
test "$audit_rc" -eq 0 || fail "audit: two-lane repo must exit 0:
$out"
printf '%s\n' "$out" | rg -Fq 'Required jobs: `ci-required`, `ci-race`' || fail 'audit: must list both required jobs'

# missing workflow
nowf="$tmp/nowf"
make_conformant_repo "$nowf"
git -C "$nowf" rm -q .github/workflows/ci.yml && git -C "$nowf" commit -qm nowf
run_audit "$nowf"; out="$audit_out"
test "$audit_rc" -eq 3 || fail 'audit: missing ci.yml must exit 3'
expect_deviation "$out" CI-MISSING

# --- docs

printf 'skill fixtures passed\n'
