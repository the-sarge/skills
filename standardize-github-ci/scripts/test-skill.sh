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
# Fail closed on an early exit. bash 3.2 runs the EXIT trap with `$?` already
# reset to 0 after a `set -u` abort, so the status alone cannot be trusted;
# `completed` is set only on the last line of the file.
completed=0
cleanup() {
  cleanup_rc=$?
  rm -rf "$tmp"
  if test "$cleanup_rc" -eq 0 && test "$completed" -ne 1; then
    printf 'error: test harness exited before the end\n' >&2
    cleanup_rc=1
  fi
  exit "$cleanup_rc"
}
trap cleanup EXIT

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
for t in ci ci-race ci-platform docs-check check release-gate; do
  test "$(yq -r ".tasks | has(\"$t\")" "$taskfile_asset")" = true || fail "Taskfile.ci.yml: missing task $t"
done
rg -Fq 'scripts/ci-classify.sh' "$taskfile_asset" || fail 'Taskfile.ci.yml: ci must call scripts/ci-classify.sh'
rg -Fq 'docs_only=true' "$taskfile_asset" || fail 'Taskfile.ci.yml: ci must branch on docs_only=true'
rg -Fq 'CI_MATCH_GLOBS' "$taskfile_asset" || fail 'Taskfile.ci.yml: must show a path-gated ci-<lane> using CI_MATCH_GLOBS'

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

# default-branch fallback order: CI_DEFAULT_BRANCH, then GITHUB_BASE_REF, then the
# origin/HEAD probe, then main. This fixture has no remote, so the probe is empty.
test "$(classify_in GITHUB_BASE_REF=main)" = 'docs_only=true' || fail 'classifier: GITHUB_BASE_REF must supply the default branch'
test "$(classify_in GITHUB_BASE_REF=does-not-exist)" = 'docs_only=false' || fail 'classifier: GITHUB_BASE_REF must be consulted before the origin/HEAD probe and the main fallback'
test "$(classify_in CI_DEFAULT_BRANCH=does-not-exist GITHUB_BASE_REF=main)" = 'docs_only=false' || fail 'classifier: CI_DEFAULT_BRANCH must win over GITHUB_BASE_REF'

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

# non-ASCII and newline-bearing pathnames: git quotes them unless core.quotePath=false and -z are used
git -C "$cls_repo" checkout -q main
git -C "$cls_repo" checkout -qb odd-names
mkdir -p "$cls_repo/platform" && printf 'x\n' > "$cls_repo/platform/café.go" && printf 'y\n' > "$cls_repo/platform/new
line.go"
git -C "$cls_repo" add . && git -C "$cls_repo" commit -qm oddnames
test "$(classify_in CI_DEFAULT_BRANCH=main CI_MATCH_GLOBS='platform/*')" = 'matches=true' || fail 'classifier: non-ASCII / newline pathnames must still match in match mode'
git -C "$cls_repo" checkout -q main
git -C "$cls_repo" checkout -qb odd-docs
printf 'doc\n' > "$cls_repo/naïve.md"
git -C "$cls_repo" add . && git -C "$cls_repo" commit -qm odddocs
test "$(classify_in CI_DEFAULT_BRANCH=main)" = 'docs_only=true' || fail 'classifier: non-ASCII markdown must still be docs-only'
git -C "$cls_repo" checkout -q src-branch

# CI_MATCH_GLOBS mode: does any changed file match these globs? (path-gated ci-<lane> targets use it)
# src-branch is checked out here: its diff against main is only pkg/pkg.go
test "$(classify_in CI_DEFAULT_BRANCH=main CI_MATCH_GLOBS='pkg/*')" = 'matches=true' || fail 'classifier: CI_MATCH_GLOBS must report a matching change'
test "$(classify_in CI_DEFAULT_BRANCH=main CI_MATCH_GLOBS='docs/* *.md')" = 'matches=false' || fail 'classifier: CI_MATCH_GLOBS must report no match when only other paths changed'
test "$(classify_in CI_DEFAULT_BRANCH=does-not-exist CI_MATCH_GLOBS='docs/*')" = 'matches=true' || fail 'classifier: CI_MATCH_GLOBS must fail closed to matches=true without a base'
git -C "$cls_repo" checkout -q main
test "$(classify_in CI_DEFAULT_BRANCH=main CI_MATCH_GLOBS='docs/*')" = 'matches=true' || fail 'classifier: CI_MATCH_GLOBS must fail closed to matches=true on an empty diff'
git -C "$cls_repo" checkout -q src-branch
: > "$gh_out"
(cd "$cls_repo" && GITHUB_OUTPUT="$gh_out" CI_DEFAULT_BRANCH=main CI_MATCH_GLOBS='pkg/*' "$classify" >/dev/null 2>&1)
test "$(cat "$gh_out")" = 'matches=true' || fail 'classifier: CI_MATCH_GLOBS must mirror matches= to GITHUB_OUTPUT'
test "$(classify_in CI_DEFAULT_BRANCH=main CI_MATCH_GLOBS='pkg/*' | wc -l | tr -d ' ')" = 1 || fail 'classifier: CI_MATCH_GLOBS mode must print exactly one line'
# mktemp failure must still produce the mode-appropriate one-line fail-closed answer and exit 0
fakebin="$tmp/fakebin"; mkdir -p "$fakebin"; printf '#!/bin/sh\nexit 1\n' > "$fakebin/mktemp"; chmod +x "$fakebin/mktemp"
test "$(classify_in PATH="$fakebin:$PATH" CI_DEFAULT_BRANCH=main)" = 'docs_only=false' || fail 'classifier: mktemp failure must fail closed to docs_only=false'
test "$(classify_in PATH="$fakebin:$PATH" CI_DEFAULT_BRANCH=main CI_MATCH_GLOBS='pkg/*')" = 'matches=true' || fail 'classifier: mktemp failure must fail closed to matches=true'
(cd "$cls_repo" && PATH="$fakebin:$PATH" CI_DEFAULT_BRANCH=main "$classify" >/dev/null 2>&1) || fail 'classifier: must exit 0 when mktemp fails'
# set-but-empty CI_MATCH_GLOBS is match mode with no globs: fail closed to matches=true (an undefined Taskfile var)
test "$(classify_in CI_DEFAULT_BRANCH=main CI_MATCH_GLOBS='')" = 'matches=true' || fail 'classifier: empty CI_MATCH_GLOBS must fail closed to matches=true'
: > "$gh_out"
(cd "$cls_repo" && GITHUB_OUTPUT="$gh_out" CI_DEFAULT_BRANCH=main CI_MATCH_GLOBS='' "$classify" >/dev/null 2>&1)
test "$(cat "$gh_out")" = 'matches=true' || fail 'classifier: empty CI_MATCH_GLOBS must mirror matches=true to GITHUB_OUTPUT'

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

# a repository with no language toolchain deletes the setup-go step; still conformant
notool="$tmp/no-toolchain"
make_conformant_repo "$notool"
yq -i 'del(.jobs["ci-required"].steps[] | select(.uses | (. // "") | test("^actions/setup-go@")))' "$notool/.github/workflows/ci.yml"
rm -f "$notool/go.mod"
run_audit "$notool"; out="$audit_out"
test "$audit_rc" -eq 0 || fail "audit: deleting the toolchain setup step must stay conformant; got $audit_rc:
$out"
printf '%s\n' "$out" | rg -Fq -- '- None. Repository conforms to the standard.' || fail "audit: no-toolchain repo must report no deviations:
$out"

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
# needs: is allowed only for a cross-runner artifact exchange between ci-* jobs; everything else deviates
mutate CI-NEEDS '.jobs.build = .jobs["ci-required"] | .jobs.build.steps[-1].run = "task build" | .jobs["ci-required"].needs = ["build"]'
mutate CI-NEEDS '.jobs["ci-required"].needs = ["ci-missing"]'
mutate CI-NEEDS '.jobs["ci-race"] = .jobs["ci-required"] | .jobs["ci-race"].steps[-1].run = "task ci-race" | .jobs["ci-race"].needs = ["ci-required"] | .jobs["ci-race"].if = "${{ always() && !github.event.pull_request.draft && github.event.pull_request.head.repo.full_name == github.repository }}"'
mutate CI-NEEDS '.jobs["ci-race"] = .jobs["ci-required"] | .jobs["ci-race"].steps[-1].run = "task ci-race" | .jobs["ci-race"].needs = "ci-required" | .jobs["ci-race"].if = "${{ failure() || (!github.event.pull_request.draft && github.event.pull_request.head.repo.full_name == github.repository) }}"'
mutate CI-NEEDS '.jobs["ci-race"] = .jobs["ci-required"] | .jobs["ci-race"].steps[-1].run = "task ci-race" | .jobs["ci-race"].needs = ["ci-required"] | .jobs["ci-race"].if = "${{ ALWAYS ( ) && !github.event.pull_request.draft && github.event.pull_request.head.repo.full_name == github.repository }}"'
mutate CI-NEEDS '.jobs["ci-race"] = .jobs["ci-required"] | .jobs["ci-race"].steps[-1].run = "task ci-race" | .jobs["ci-race"].needs = ["ci-required"] | .jobs["ci-race"].if = "${{ !success() && !github.event.pull_request.draft && github.event.pull_request.head.repo.full_name == github.repository }}"'
mutate CI-NEEDS '.jobs["ci-race"] = .jobs["ci-required"] | .jobs["ci-race"].steps[-1].run = "task ci-race" | .jobs["ci-race"].needs = ["ci-required"] | .jobs["ci-race"].if = "success() == false && !github.event.pull_request.draft && github.event.pull_request.head.repo.full_name == github.repository"'
mutate CI-NEEDS '.jobs["ci-race"] = .jobs["ci-required"] | .jobs["ci-race"].steps[-1].run = "task ci-race" | .jobs["ci-race"].needs = ["ci-race"]'
mutate CI-NEEDS '.jobs["ci-origin"] = .jobs["ci-required"] | .jobs["ci-origin"].steps[-1].run = "task ci-origin" | .jobs["ci-required"].needs = ["ci-origin"]'
mutate CI-NEEDS '.jobs["ci-race"] = .jobs["ci-required"] | .jobs["ci-race"].steps[-1].run = "task ci-race" | .jobs["ci-race"].needs = ["ci-r.quired"]'
# aggregation: any expression that reads dependency results, in any GitHub expression form
exchange_lane='.jobs["ci-race"] = .jobs["ci-required"] | .jobs["ci-race"].steps[-1].run = "task ci-race" | .jobs["ci-race"].needs = ["ci-required"]'
mutate CI-AGGREGATE "$exchange_lane"' | .jobs["ci-race"].env.UPSTREAM = "${{ needs.ci-required.result }}"'
mutate CI-AGGREGATE "$exchange_lane"' | .jobs["ci-race"].env.UPSTREAM = "${{ Needs[ '"'"'ci-required'"'"' ].Result }}"'
mutate CI-AGGREGATE "$exchange_lane"' | .jobs["ci-race"].if = "${{ !github.event.pull_request.draft && github.event.pull_request.head.repo.full_name == github.repository && needs.*.result != '"'"'failure'"'"' }}"'
mutate CI-AGGREGATE "$exchange_lane"' | .jobs["ci-race"].env.ALL = "${{ toJSON(needs) }}"'
# job-level and step-level if are expressions even without ${{ }} delimiters
mutate CI-AGGREGATE "$exchange_lane"' | .jobs["ci-race"].if = "!github.event.pull_request.draft && github.event.pull_request.head.repo.full_name == github.repository && needs.ci-required.result == '"'"'success'"'"'"'
mutate CI-AGGREGATE "$exchange_lane"' | .jobs["ci-race"].steps[-1].if = "needs.ci-required.result == '"'"'success'"'"'"'
mutate CI-AGGREGATE "$exchange_lane"' | .jobs["ci-race"].env.UP = "${{ needs['"'"'ci-required'"'"']['"'"'result'"'"'] }}"'
mutate CI-AGGREGATE "$exchange_lane"' | .jobs["ci-race"].env.UP = "${{\n  needs.ci-required.result\n}}"'
mutate CI-AGGREGATE "$exchange_lane"' | .jobs["ci-race"].env.UP = "${{ fromJSON(toJSON(needs)).ci-required.conclusion }}"'
mutate CI-AGGREGATE "$exchange_lane"' | .jobs["ci-race"].env.ALL_OUTPUTS = "${{ toJSON(needs.ci-required.outputs) }}"'
# inert text and dependency outputs are not aggregation
inert="$tmp/inert"
make_conformant_repo "$inert"
yq -i "$exchange_lane"' | .jobs["ci-race"].env.NOTE = "plain text mentioning needs.ci-required.result is not an expression" | .jobs["ci-race"].env.BUNDLE = "${{ needs.ci-required.outputs.bundle_name }}" | .jobs["ci-race"].env.BUNDLE2 = "${{ needs['"'"'ci-required'"'"'].outputs['"'"'bundle_name'"'"'] }}"' "$inert/.github/workflows/ci.yml"
git -C "$inert" commit -qam inert
run_audit "$inert"; out="$audit_out"
test "$audit_rc" -eq 0 || fail "audit: inert text and needs.<job>.outputs must not be aggregation:
$out"
mutate CI-MATRIX '.jobs["ci-required"].strategy.matrix.os = ["ubuntu-latest","macos-latest"]'
mutate CI-TARGET '.jobs["ci-required"].steps[-1].run = "task check"'
mutate CI-TARGET '.jobs["ci-required"].steps += [{"run":"task extra"}]'
mutate CI-TARGET '.jobs["ci-race"] = .jobs["ci-required"]'
mutate CI-PIN '.jobs["ci-required"].steps[0].uses = "actions/checkout@v7"'
mutate CI-FETCH-DEPTH 'del(.jobs["ci-required"].steps[0].with)'

# a cross-runner artifact exchange between ci-* jobs is conformant: origin jobs feed destination jobs via needs
exch="$tmp/exchange"
make_conformant_repo "$exch"
# destination is declared before its origins to prove forward references resolve
yq -i '.jobs["ci-portable-linux"] = .jobs["ci-required"] | .jobs["ci-portable-linux"].steps[-1].run = "task ci-portable-linux" | .jobs["ci-portable-linux"].needs = ["ci-origin-linux","ci-origin-windows"] | .jobs["ci-portable-linux"].steps = [.jobs["ci-portable-linux"].steps[0], {"uses":"actions/download-artifact@0123456789abcdef0123456789abcdef01234567","with":{"pattern":"bundle-*"}}] + .jobs["ci-portable-linux"].steps[1:] | .jobs["ci-origin-linux"] = .jobs["ci-required"] | .jobs["ci-origin-linux"].steps[-1].run = "task ci-origin-linux" | .jobs["ci-origin-linux"].steps += [{"uses":"actions/upload-artifact@fedcba9876543210fedcba9876543210fedcba98","with":{"name":"bundle-linux","path":"dist/bundle-linux.tar"}}] | .jobs["ci-origin-windows"] = .jobs["ci-origin-linux"] | .jobs["ci-origin-windows"]["runs-on"] = "windows-latest" | .jobs["ci-origin-windows"].steps[-2].run = "task ci-origin-windows" | .jobs["ci-origin-windows"].steps[-1].with.name = "bundle-windows"' "$exch/.github/workflows/ci.yml"
yq -i '.tasks["ci-origin-linux"] = .tasks["ci-race"] | .tasks["ci-origin-windows"] = .tasks["ci-race"] | .tasks["ci-portable-linux"] = .tasks["ci-race"]' "$exch/Taskfile.yml"
git -C "$exch" commit -qam exchange
run_audit "$exch"; out="$audit_out"
test "$audit_rc" -eq 0 || fail "audit: ci-* artifact-exchange graph must be conformant:
$out"
printf '%s\n' "$out" | rg -Fq 'Required jobs: `ci-required`, `ci-portable-linux`, `ci-origin-linux`, `ci-origin-windows`' || fail 'audit: exchange jobs must be listed as required'
printf '%s\n' "$out" | rg -Fq 'ci-portable-linux` needs `ci-origin-linux`, `ci-origin-windows`' || fail 'audit: exchange edges must be reported'

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

# malformed or oddly-shaped ci.yml must still honour the exit contract and finish the report
expect_report() { # output
  printf '%s\n' "$1" | rg -Fq '## Deviations' || fail "audit: report must reach the Deviations section; got:
$1"
}

broken="$tmp/broken-yaml"
make_conformant_repo "$broken"
printf 'on: [\n' > "$broken/.github/workflows/ci.yml"
run_audit "$broken"; out="$audit_out"
test "$audit_rc" -eq 3 || fail "audit: unparseable ci.yml must exit 3; got $audit_rc:
$out"
expect_deviation "$out" CI-MISSING
expect_report "$out"

mutate CI-JOBS '.jobs = "hello"'
expect_report "$out"
mutate CI-GUARD '.jobs["ci-required"] = "foo"'
expect_report "$out"
mutate CI-PIN '.jobs["ci-required"].steps = ["task ci"]'
expect_deviation "$out" CI-TARGET
expect_report "$out"

# other workflows must not use pull_request / pull_request_target
other="$tmp/other"
make_conformant_repo "$other"
cat > "$other/.github/workflows/deep-ci.yml" <<'YAML'
name: deep-ci
on:
  schedule:
    - cron: '17 3 * * *'
  workflow_dispatch:
jobs:
  race:
    runs-on: ubuntu-latest
    timeout-minutes: 60
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
      - run: task race
  # a reusable-workflow call cannot carry timeout-minutes; the called workflow owns its timeouts
  windows_contracts:
    uses: ./.github/workflows/windows-contracts.yml
    with:
      lane: portable
YAML
git -C "$other" add . && git -C "$other" commit -qm deep
run_audit "$other"; out="$audit_out"
test "$audit_rc" -eq 0 || fail "audit: scheduled non-required workflow must be conformant:
$out"
printf '%s\n' "$out" | rg -Fq '`deep-ci.yml`' || fail 'audit: must list other workflows'

# malformed or empty job-level uses must not exempt a job from the timeout rule
cat > "$other/.github/workflows/malformed.yml" <<'YAML'
name: malformed
on:
  workflow_dispatch:
jobs:
  scalar_job: just-a-string
  null_uses:
    uses:
  empty_uses:
    uses: ""
  numeric_uses:
    uses: 42
  fine:
    uses: ./.github/workflows/x.yml
YAML
git -C "$other" add . && git -C "$other" commit -qm malformed
run_audit "$other"; out="$audit_out"
test "$audit_rc" -eq 3 || fail 'audit: malformed uses jobs must exit 3'
printf '%s\n' "$out" | rg -Fq 'malformed.yml: jobs missing timeout-minutes: scalar_job, null_uses, empty_uses, numeric_uses' || fail "audit: WF-TIMEOUT must name each malformed job and spare the valid reusable caller:
$out"
git -C "$other" rm -q .github/workflows/malformed.yml && git -C "$other" commit -qm rm-malformed

cat > "$other/.github/workflows/preflight.yml" <<'YAML'
name: preflight
on: [pull_request]
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - run: task lint
YAML
git -C "$other" add . && git -C "$other" commit -qm preflight
run_audit "$other"; out="$audit_out"
test "$audit_rc" -eq 3 || fail 'audit: pull_request on a non-required workflow must exit 3'
expect_deviation "$out" WF-PR-TRIGGER
expect_deviation "$out" WF-TIMEOUT
expect_deviation "$out" WF-PIN

cat > "$other/.github/workflows/preflight.yml" <<'YAML'
name: preflight
on:
  pull_request_target:
    types: [labeled]
jobs:
  lint:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - run: 'true'
YAML
git -C "$other" add . && git -C "$other" commit -qm target
run_audit "$other"; out="$audit_out"
expect_deviation "$out" WF-PR-TRIGGER

# a non-required workflow that runs `task ci` inherits the fast PR gate (and classifies against a PR merge base that
# does not exist on a tag or schedule); it must call a purpose-named target instead
rel="$tmp/release"
make_conformant_repo "$rel"
cat > "$rel/.github/workflows/release.yml" <<'YAML'
name: release
on:
  push:
    tags: ['v*']
jobs:
  publish:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
      - name: Run complete validation
        run: task ci
      - run: |
          echo build
          task ci-race
      - run: task ci>/dev/null
      - run: 'test -n "`task ci-portable-linux`"'
      - run: task cicd && task ci_fast && task ci-
YAML
git -C "$rel" add . && git -C "$rel" commit -qm release
run_audit "$rel"; out="$audit_out"
test "$audit_rc" -eq 3 || fail "audit: non-required workflow running task ci must exit 3:
$out"
expect_deviation "$out" WF-TASK-CI
printf '%s\n' "$out" | rg -Fq 'release.yml: runs `task ci`, `task ci-portable-linux`, `task ci-race`' || fail "audit: WF-TASK-CI must name exactly the ci targets it found (not cicd/ci_fast/ci-):
$out"
yq -i '.jobs.publish.steps[1].run = "task release-gate" | .jobs.publish.steps[2].run = "task build" | .jobs.publish.steps[3].run = "task release-gate>/dev/null" | .jobs.publish.steps[4].run = "task nightly"' "$rel/.github/workflows/release.yml"
git -C "$rel" commit -qam release-gate
run_audit "$rel"; out="$audit_out"
test "$audit_rc" -eq 0 || fail "audit: non-required workflow calling a purpose-named target must be conformant:
$out"
# a tag-push workflow must run task release-gate, and the Taskfile must define it
yq -i '.jobs.publish.steps[1].run = "task build" | .jobs.publish.steps[3].run = "task package>/dev/null"' "$rel/.github/workflows/release.yml"
git -C "$rel" commit -qam no-gate
run_audit "$rel"; out="$audit_out"
test "$audit_rc" -eq 3 || fail 'audit: tag-push workflow without task release-gate must exit 3'
expect_deviation "$out" WF-RELEASE-GATE
yq -i '.jobs.publish.steps[1].run = "task release-gate"' "$rel/.github/workflows/release.yml"
yq -i 'del(.tasks["release-gate"])' "$rel/Taskfile.yml"
git -C "$rel" commit -qam no-gate-task
run_audit "$rel"; out="$audit_out"
expect_deviation "$out" TASK-RELEASE-GATE-MISSING
# no Taskfile at all, but a tag-push workflow: the release-specific diagnostic must still appear
norel_tf="$tmp/release-notaskfile"
make_conformant_repo "$norel_tf"
cp "$rel/.github/workflows/release.yml" "$norel_tf/.github/workflows/release.yml"
git -C "$norel_tf" rm -q Taskfile.yml && git -C "$norel_tf" add . && git -C "$norel_tf" commit -qm notaskfile
run_audit "$norel_tf"; out="$audit_out"
test "$audit_rc" -eq 3 || fail 'audit: tag-push workflow with no Taskfile must exit 3'
expect_deviation "$out" TASK-RELEASE-GATE-MISSING
# a repo with no tag-push workflow does not need release-gate
norel="$tmp/norelease"
make_conformant_repo "$norel"
yq -i 'del(.tasks["release-gate"])' "$norel/Taskfile.yml"
git -C "$norel" commit -qam norel
run_audit "$norel"; out="$audit_out"
test "$audit_rc" -eq 0 || fail "audit: release-gate is only required when a tag-push workflow exists:
$out"

# local composite actions and docker:// images carry no ref to pin and must not be flagged
localact="$tmp/localaction"
make_conformant_repo "$localact"
yq -i '.jobs["ci-required"].steps += [{"uses":"./.github/actions/setup"},{"uses":"docker://alpine:3.20"}]' "$localact/.github/workflows/ci.yml"
cat > "$localact/.github/workflows/nightly.yml" <<'YAML'
name: nightly
on:
  schedule:
    - cron: '23 4 * * *'
jobs:
  deep:
    runs-on: ubuntu-latest
    timeout-minutes: 45
    steps:
      - uses: ./.github/actions/setup
      - run: task deep
YAML
run_audit "$localact"; out="$audit_out"
test "$audit_rc" -eq 0 || fail "audit: local composite actions must not be reported as unpinned; got $audit_rc:
$out"

# an unpinned third-party action beside them still fires, in ci.yml and elsewhere
yq -i '.jobs["ci-required"].steps += [{"uses":"actions/setup-node@v4"}]' "$localact/.github/workflows/ci.yml"
yq -i '.jobs.deep.steps += [{"uses":"actions/setup-node@v4"}]' "$localact/.github/workflows/nightly.yml"
run_audit "$localact"; out="$audit_out"
test "$audit_rc" -eq 3 || fail "audit: unpinned third-party action must exit 3; got $audit_rc:
$out"
expect_deviation "$out" CI-PIN
expect_deviation "$out" WF-PIN

# Taskfile and classifier presence
tf="$tmp/taskfile"
make_conformant_repo "$tf"
yq -i 'del(.tasks.ci)' "$tf/Taskfile.yml"
git -C "$tf" commit -qam noci
run_audit "$tf"; out="$audit_out"
expect_deviation "$out" TASK-CI-MISSING
yq -i 'del(.tasks.check) | del(.tasks["docs-check"])' "$tf/Taskfile.yml"
git -C "$tf" commit -qam nolanes
run_audit "$tf"; out="$audit_out"
expect_deviation "$out" TASK-CHECK-MISSING
expect_deviation "$out" TASK-DOCS-CHECK-MISSING
git -C "$tf" rm -q scripts/ci-classify.sh && git -C "$tf" commit -qm noclassify
run_audit "$tf"; out="$audit_out"
expect_deviation "$out" CLASSIFY-MISSING

lanetf="$tmp/lanetf"
make_conformant_repo "$lanetf"
yq -i '.jobs["ci-fuzz"] = .jobs["ci-required"] | .jobs["ci-fuzz"].steps[-1].run = "task ci-fuzz"' "$lanetf/.github/workflows/ci.yml"
git -C "$lanetf" commit -qam lane
run_audit "$lanetf"; out="$audit_out"
expect_deviation "$out" TASK-LANE-MISSING

# --- self-hosted cache locality: no self-hosted job uses the GitHub Actions cache

# the asset ships cache: false, so a self-hosted lane built from it is conformant
swept="$tmp/cache-swept"
make_conformant_repo "$swept"
yq -i '.jobs["ci-required"]["runs-on"] = "repo-garm-linux-arm64"' "$swept/.github/workflows/ci.yml"
git -C "$swept" commit -qam swept
run_audit "$swept"; out="$audit_out"
test "$audit_rc" -eq 0 || fail "audit: self-hosted job with cache: false must be conformant; got $audit_rc:
$out"

# seeded violations: cache enabled explicitly, by omission, by a package-manager
# string, or via an actions/cache step, on a self-hosted job
mutate CI-CACHE '.jobs["ci-required"]["runs-on"] = "self-hosted-xlarge" | (.jobs["ci-required"].steps[] | select(.uses | (. // "") | test("^actions/setup-go@")) | .with.cache) = true'
mutate CI-CACHE '.jobs["ci-required"]["runs-on"] = ["self-hosted", "linux"] | del(.jobs["ci-required"].steps[] | select(.uses | (. // "") | test("^actions/setup-go@")) | .with.cache)'
mutate CI-CACHE '.jobs["ci-required"]["runs-on"] = "self-hosted-xlarge" | .jobs["ci-required"].steps += [{"uses":"actions/setup-node@0123456789abcdef0123456789abcdef01234567","with":{"cache":"npm"}}]'
mutate CI-CACHE '.jobs["ci-required"]["runs-on"] = "self-hosted-xlarge" | .jobs["ci-required"].steps += [{"uses":"actions/cache@0123456789abcdef0123456789abcdef01234567","with":{"path":"~/.cache/go-build","key":"go-build"}}]'

# hosted jobs may keep the action default: cache enabled by omission is conformant
hostedcache="$tmp/cache-hosted"
make_conformant_repo "$hostedcache"
yq -i 'del(.jobs["ci-required"].steps[] | select(.uses | (. // "") | test("^actions/setup-go@")) | .with.cache)' "$hostedcache/.github/workflows/ci.yml"
git -C "$hostedcache" commit -qam hosted
run_audit "$hostedcache"; out="$audit_out"
test "$audit_rc" -eq 0 || fail "audit: hosted job may keep the cache default; got $audit_rc:
$out"

# a runtime-resolved runner cannot be classified: canonical-subset guarantee, no deviation
dyncache="$tmp/cache-dynamic"
make_conformant_repo "$dyncache"
yq -i '.jobs["ci-required"]["runs-on"] = "${{ inputs.runner_label }}" | del(.jobs["ci-required"].steps[] | select(.uses | (. // "") | test("^actions/setup-go@")) | .with.cache)' "$dyncache/.github/workflows/ci.yml"
git -C "$dyncache" commit -qam dynamic
run_audit "$dyncache"; out="$audit_out"
if printf '%s\n' "$out" | rg -Fq '`CI-CACHE`'; then
  fail "audit: a runtime-resolved runs-on must not be classified as self-hosted:
$out"
fi

# the check covers non-required workflows too
wfcache="$tmp/cache-wf"
make_conformant_repo "$wfcache"
cat > "$wfcache/.github/workflows/deep.yml" <<'YAML'
name: deep
on:
  schedule:
    - cron: '7 2 * * *'
jobs:
  deep:
    runs-on: repo-garm-linux-arm64
    timeout-minutes: 60
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
      - uses: actions/setup-go@b7ad1dad31e06c5925ef5d2fc7ad053ef454303e
        with:
          go-version-file: go.mod
      - run: task deep
YAML
git -C "$wfcache" add . && git -C "$wfcache" commit -qm wfcache
run_audit "$wfcache"; out="$audit_out"
test "$audit_rc" -eq 3 || fail "audit: self-hosted setup-go without cache: false in a non-required workflow must exit 3; got $audit_rc:
$out"
expect_deviation "$out" WF-CACHE
yq -i '(.jobs.deep.steps[] | select(.uses | (. // "") | test("^actions/setup-go@")) | .with.cache) = false' "$wfcache/.github/workflows/deep.yml"
git -C "$wfcache" commit -qam wfcache-fixed
run_audit "$wfcache"; out="$audit_out"
test "$audit_rc" -eq 0 || fail "audit: cache: false on the self-hosted job must clear WF-CACHE; got $audit_rc:
$out"

# ruleset from JSON
good_rules="$tmp/rules-good.json"
cat > "$good_rules" <<'JSON'
[
  {"type":"deletion","ruleset_id":1},
  {"type":"non_fast_forward","ruleset_id":1},
  {"type":"pull_request","ruleset_id":1,"parameters":{"allowed_merge_methods":["squash"],"required_approving_review_count":0}},
  {"type":"required_status_checks","ruleset_id":1,"parameters":{"strict_required_status_checks_policy":true,"required_status_checks":[{"context":"ci-required","integration_id":15368}]}}
]
JSON
run_audit "$conf" CI_AUDIT_RULESET_JSON="$good_rules"; out="$audit_out"
test "$audit_rc" -eq 0 || fail "audit: good ruleset must be conformant:
$out"
printf '%s\n' "$out" | rg -Fq 'Default-branch rules' || fail 'audit: must report rules section'

bad_rules="$tmp/rules-bad.json"
cat > "$bad_rules" <<'JSON'
[
  {"type":"pull_request","ruleset_id":1,"parameters":{"allowed_merge_methods":["merge","squash","rebase"]}},
  {"type":"required_status_checks","ruleset_id":1,"parameters":{"strict_required_status_checks_policy":false,"required_status_checks":[{"context":"Verify","integration_id":15368}]}}
]
JSON
run_audit "$conf" CI_AUDIT_RULESET_JSON="$bad_rules"; out="$audit_out"
test "$audit_rc" -eq 3 || fail 'audit: bad ruleset must exit 3'
expect_deviation "$out" RULES-CHECKS
expect_deviation "$out" RULES-STRICT
expect_deviation "$out" RULES-SQUASH
expect_deviation "$out" RULES-DELETION
expect_deviation "$out" RULES-FF

# two-lane repo: rules must require both contexts
run_audit "$lane" CI_AUDIT_RULESET_JSON="$good_rules"; out="$audit_out"
expect_deviation "$out" RULES-CHECKS

# empty rules array: no PR rule and no checks
printf '[]\n' > "$tmp/rules-empty.json"
run_audit "$conf" CI_AUDIT_RULESET_JSON="$tmp/rules-empty.json"; out="$audit_out"
expect_deviation "$out" RULES-PR
expect_deviation "$out" RULES-CHECKS

# an unparseable non-required workflow must not pass silently
badwf="$tmp/badwf"
make_conformant_repo "$badwf"
printf 'on: [\n' > "$badwf/.github/workflows/broken.yml"
git -C "$badwf" add . && git -C "$badwf" commit -qm broken
run_audit "$badwf"; out="$audit_out"
test "$audit_rc" -eq 3 || fail "audit: unparseable non-required workflow must exit 3; got $audit_rc:
$out"
expect_deviation "$out" WF-PARSE
expect_report "$out"

# a missing Taskfile is missing every required task, not just ci
notf="$tmp/notaskfile"
make_conformant_repo "$notf"
git -C "$notf" rm -q Taskfile.yml && git -C "$notf" commit -qm notaskfile
run_audit "$notf"; out="$audit_out"
test "$audit_rc" -eq 3 || fail "audit: missing Taskfile must exit 3; got $audit_rc:
$out"
expect_deviation "$out" TASK-CI-MISSING
expect_deviation "$out" TASK-CHECK-MISSING
expect_deviation "$out" TASK-DOCS-CHECK-MISSING

# an unusable rules source is a tool error, never a silent pass
: > "$tmp/rules-empty-file.json"
run_audit "$conf" CI_AUDIT_RULESET_JSON="$tmp/rules-empty-file.json"; out="$audit_out"
test "$audit_rc" -eq 2 || fail "audit: empty rules file must exit 2; got $audit_rc:
$out"
printf '{"message":"Not Found"}\n' > "$tmp/rules-notfound.json"
run_audit "$conf" CI_AUDIT_RULESET_JSON="$tmp/rules-notfound.json"; out="$audit_out"
test "$audit_rc" -eq 2 || fail "audit: non-array rules source must exit 2; got $audit_rc:
$out"
run_audit "$conf" CI_AUDIT_RULESET_JSON="$tmp/does-not-exist.json"; out="$audit_out"
test "$audit_rc" -eq 2 || fail "audit: unreadable rules file must exit 2; got $audit_rc:
$out"

# without a parseable ci.yml the required contexts are unknown, not empty
run_audit "$nowf" CI_AUDIT_RULESET_JSON="$good_rules"; out="$audit_out"
printf '%s\n' "$out" | rg -Fq 'expected unknown' || fail "audit: required contexts must read unknown without ci.yml:
$out"
if printf '%s\n' "$out" | rg -Fq '`RULES-CHECKS`'; then
  fail "audit: must not compare required contexts without ci.yml:
$out"
fi

# --- live ruleset mode, against a gh stand-in (never the network)
ghbin="$tmp/ghbin"
mkdir -p "$ghbin"
cat > "$ghbin/gh" <<'SH'
#!/usr/bin/env bash
# Minimal gh stand-in for audit-ci.sh live mode. GH_FAKE_FAIL fails every call;
# GH_FAKE_PROTECTION selects the HTTP status of the legacy-protection probe.
if test -n "${GH_FAKE_FAIL:-}"; then
  printf 'gh: Bad credentials (HTTP 401)\n' >&2
  exit 1
fi
case "$*" in
  *'/protection'*)
    case "${GH_FAKE_PROTECTION:-404}" in
      200) exit 0 ;;
      404) printf 'gh: Branch not protected (HTTP 404)\n' >&2; exit 1 ;;
      *) printf 'gh: Resource not accessible (HTTP %s)\n' "${GH_FAKE_PROTECTION}" >&2; exit 1 ;;
    esac ;;
  *'/rules/branches/'*) cat "$GH_FAKE_RULES" ;;
  *) printf 'main\n' ;;
esac
SH
chmod +x "$ghbin/gh"

live="$tmp/live"
make_conformant_repo "$live"
git -C "$live" remote add origin https://github.com/example/repo.git

run_audit "$live" PATH="$ghbin:$PATH" CI_AUDIT_RULESET=live GH_FAKE_RULES="$good_rules" GH_FAKE_PROTECTION=404
out="$audit_out"
test "$audit_rc" -eq 0 || fail "audit: live mode with a conformant ruleset must exit 0; got $audit_rc:
$out"
printf '%s\n' "$out" | rg -Fq -- '- Legacy branch protection: absent' || fail "audit: must report legacy protection absent:
$out"

run_audit "$live" PATH="$ghbin:$PATH" CI_AUDIT_RULESET=live GH_FAKE_RULES="$good_rules" GH_FAKE_PROTECTION=200
out="$audit_out"
test "$audit_rc" -eq 3 || fail 'audit: live legacy protection present must exit 3'
expect_deviation "$out" RULES-LEGACY
printf '%s\n' "$out" | rg -Fq -- '- Legacy branch protection: present' || fail "audit: must report legacy protection present:
$out"

# a 403 on the protection probe must not read as absent
run_audit "$live" PATH="$ghbin:$PATH" CI_AUDIT_RULESET=live GH_FAKE_RULES="$good_rules" GH_FAKE_PROTECTION=403
out="$audit_out"
test "$audit_rc" -eq 3 || fail "audit: unknown legacy protection must exit 3; got $audit_rc:
$out"
expect_deviation "$out" RULES-LEGACY
printf '%s\n' "$out" | rg -Fq -- '- Legacy branch protection: unknown' || fail "audit: must report legacy protection unknown:
$out"

# gh failure and a missing origin are tool errors, not partial reports
run_audit "$live" PATH="$ghbin:$PATH" CI_AUDIT_RULESET=live GH_FAKE_FAIL=1; out="$audit_out"
test "$audit_rc" -eq 2 || fail "audit: gh failure in live mode must exit 2; got $audit_rc:
$out"
printf '%s\n' "$out" | rg -Fq 'via gh' || fail "audit: gh failure must name the cause:
$out"

run_audit "$conf" PATH="$ghbin:$PATH" CI_AUDIT_RULESET=live GH_FAKE_RULES="$good_rules"; out="$audit_out"
test "$audit_rc" -eq 2 || fail "audit: live mode without an origin remote must exit 2; got $audit_rc:
$out"

# --- task ci end to end (only when `task` is installed)

# Proves the Taskfile branch, not just the classifier: the asset's docs-check and
# check bodies echo distinctive placeholder text, so the output names the lane taken.
if command -v task >/dev/null; then
  docs_marker="replace with the repository's documentation checks"
  check_marker="replace with the repository's format, vet, lint, test, and build checks"
  taskrun="$tmp/taskrun"
  make_conformant_repo "$taskrun"

  git -C "$taskrun" checkout -qb docs-only-change
  printf '# readme\n' > "$taskrun/README.md"
  git -C "$taskrun" add . && git -C "$taskrun" commit -qm docs
  task_out="$(cd "$taskrun" && task ci 2>&1)" || fail "task ci: failed on a docs-only diff:
$task_out"
  printf '%s\n' "$task_out" | rg -Fq "$docs_marker" || fail "task ci: docs-only diff must run docs-check; got:
$task_out"
  if printf '%s\n' "$task_out" | rg -Fq "$check_marker"; then
    fail "task ci: docs-only diff must not run check; got:
$task_out"
  fi

  git -C "$taskrun" checkout -q main
  git -C "$taskrun" checkout -qb source-change
  printf 'package pkg\n' > "$taskrun/pkg.go"
  git -C "$taskrun" add . && git -C "$taskrun" commit -qm source
  task_out="$(cd "$taskrun" && task ci 2>&1)" || fail "task ci: failed on a source diff:
$task_out"
  printf '%s\n' "$task_out" | rg -Fq "$check_marker" || fail "task ci: source diff must run check; got:
$task_out"

  # path-gated lane: a source change outside its globs reports not-applicable; a change inside runs the lane body
  platform_marker="replace with the repository's platform-specific checks"
  task_out="$(cd "$taskrun" && task ci-platform 2>&1)" || fail "task ci-platform: failed:
$task_out"
  printf '%s\n' "$task_out" | rg -Fq 'not applicable' || fail "task ci-platform: change outside its globs must report not applicable; got:
$task_out"
  mkdir -p "$taskrun/platform" && printf 'x\n' > "$taskrun/platform/windows.go"
  git -C "$taskrun" add . && git -C "$taskrun" commit -qm platform
  task_out="$(cd "$taskrun" && task ci-platform 2>&1)" || fail "task ci-platform: failed on a platform diff:
$task_out"
  printf '%s\n' "$task_out" | rg -Fq "$platform_marker" || fail "task ci-platform: platform diff must run the lane; got:
$task_out"
fi

# --- docs

policy="$skill_root/references/ci-policy.md"
rg -Fq 'types: [opened, synchronize, reopened, ready_for_review]' "$policy" || fail 'ci-policy.md: must state the trigger'
rg -Fq 'ci-<lane>' "$policy" || fail 'ci-policy.md: must define ci-<lane> jobs'
rg -Fq 'cross-runner artifact exchange' "$policy" || fail 'ci-policy.md: must define the needs: exception for cross-runner artifact exchange'
rg -Fq 'CI_MATCH_GLOBS' "$policy" || fail 'ci-policy.md: must describe path-gated ci-<lane> targets via CI_MATCH_GLOBS'
rg -Fq 'fold into `task check`' "$policy" || fail 'ci-policy.md: choice rule must include the fold-into-check branch'
rg -Fq 'hosted runner' "$policy" || fail 'ci-policy.md: Runners section must carry the hosted-runner cost rule'
rg -Fq 'toolchain setup step' "$policy" || fail 'ci-policy.md: must document the toolchain setup step as the variable slot (replace per toolchain, delete when none)'
rg -Fq 'toolchain setup step' "$skill_root/references/migration.md" || fail 'migration.md: apply must carry the toolchain setup slot allowance'
rg -Fq 'toolchain setup step' "$skill_root/SKILL.md" || fail 'SKILL.md: apply scope must carry the toolchain setup slot allowance'
head -8 "$workflow_asset" | rg -q 'toolchain setup slot' || fail 'ci.yml: header must name the toolchain setup slot among the allowed variations'
if head -8 "$workflow_asset" | rg -q 'change only `runs-on`\.'; then fail 'ci.yml: header must not claim runs-on is the only allowed change'; fi
rg -B1 -F 'actions/setup-go@' "$workflow_asset" | rg -q '^\s*#.*[Tt]oolchain' || fail 'ci.yml: the setup-go step must be marked as the toolchain slot with a comment'
rg -Fq 'cache: false' "$workflow_asset" || fail 'ci.yml: the setup-go step must set cache: false'
rg -Fq 'cache: false' "$policy" || fail 'ci-policy.md: must state the self-hosted cache: false rule'
rg -Fq 'GitHub Actions cache' "$policy" || fail 'ci-policy.md: must forbid the GitHub Actions cache on self-hosted labels'
rg -Fq 'CI-CACHE' "$policy" || fail 'ci-policy.md: must name the CI-CACHE/WF-CACHE audit codes'
rg -Fq 'cache: false' "$skill_root/SKILL.md" || fail 'SKILL.md: replacement toolchain setup must keep cache: false'
rg -Fq 'path-gated' "$skill_root/SKILL.md" || fail 'SKILL.md: audit checklist must record path-gated lanes and hosted runners'
rg -Fq 'glob variable' "$skill_root/references/migration.md" || fail 'migration.md: plan/apply must carry each gated lane glob variable'
rg -Fq 'path-gated' "$skill_root/references/migration.md" || fail 'migration.md: must tell migrators to path-gate conditional lanes inside the Taskfile'
if rg -qi 'never add `needs`' "$workflow_asset"; then fail 'ci.yml: header must not contradict the cross-runner exchange exception'; fi
rg -Fq 'upload-artifact' "$skill_root/SKILL.md" || fail 'SKILL.md: Apply must authorize the artifact steps an exchange needs'
if rg -q 'no job depends on another|`needs:` present' "$repo_root/docs/superpowers/specs/2026-08-18-simplify-ci-standard-design.md"; then fail 'spec: stale blanket needs: statements remain'; fi
rg -Fq 'strict' "$policy" || fail 'ci-policy.md: must require strict up-to-date'
rg -Fq 'squash' "$policy" || fail 'ci-policy.md: must require squash-only'
if rg -qi 'expected_sha|status bridge|ci:certify|ci-certify|workflow_dispatch.*certif|labeled' "$policy"; then
  fail 'ci-policy.md: must not describe dispatch/label certification'
fi

migration="$skill_root/references/migration.md"
rg -Fq 'gh pr ready' "$migration" || fail 'migration.md: must describe marking the PR ready'
rg -Fq 'every caller' "$migration" || fail 'migration.md: must require an inventory of every caller of a renamed or redefined Taskfile target'
rg -Fq 'for every caller found in §1.5, the purpose-named target it will call' "$migration" || fail 'migration.md §2: plan must map each caller to its purpose-named target'
rg -Fq 'Define the purpose-named targets planned in §2' "$migration" || fail 'migration.md §3: apply must define the targets and repoint callers'
rg -Fq 'never `task ci` or `task ci-<lane>`' "$policy" || fail 'ci-policy.md: non-required workflows must call purpose-named targets, never task ci or ci-<lane>'
rg -Fq 'cannot carry `timeout-minutes`' "$policy" || fail 'ci-policy.md: must qualify the timeout rule for reusable-workflow callers'
rg -Fq '`task release-gate`' "$policy" || fail 'ci-policy.md: tag-push release workflows must run task release-gate'
rg -Fq 'Every tag-push release workflow calls `task release-gate`' "$migration" || fail 'migration.md: must mandate task release-gate for tag-push workflows'
rg -Fq 'tag-push release workflows run `task release-gate`' "$skill_root/SKILL.md" || fail 'SKILL.md: audit guidance must name task release-gate'
rg -Fq 'never `task ci` or `task ci-<lane>`' "$skill_root/SKILL.md" || fail 'SKILL.md: audit summary must cover both task ci and task ci-<lane>'
rg -Fq 'gh pr merge --squash --match-head-commit' "$migration" || fail 'migration.md: must describe the exact-head squash merge'
rg -Fq 'assets/ruleset.json' "$migration" || fail 'migration.md: must apply the ruleset asset'
rg -Fq 'gh pr create --draft' "$migration" || fail 'migration.md: must open the migration PR as a draft'
if rg -qi 'expected_sha|ci:certify|ci-certify|status bridge' "$migration"; then
  fail 'migration.md: must not describe dispatch/label certification'
fi

skill_md="$skill_root/SKILL.md"
rg -Fq 'name: standardize-github-ci' "$skill_md" || fail 'SKILL.md: frontmatter name'
rg -Fq 'scripts/audit-ci.sh' "$skill_md" || fail 'SKILL.md: must run the audit'
rg -Fq 'references/ci-policy.md' "$skill_md" || fail 'SKILL.md: must load the policy'
rg -Fq 'references/migration.md' "$skill_md" || fail 'SKILL.md: must load the migration checklist'
if rg -qi 'dispatch-gated|expected_sha|ci:certify|status bridge|labeled' "$skill_md"; then
  fail 'SKILL.md: must not describe dispatch/label certification'
fi
if rg -qi 'dispatch|exact-head' "$skill_root/agents/openai.yaml"; then
  fail 'openai.yaml: stale description'
fi

rg -Fq 'skipped' "$policy" || fail 'ci-policy.md: must state the skipped-check mechanism'
rg -Fq 'post-ready' "$migration" || fail 'migration.md: must describe the post-ready run'
# A workflow run's `event` is the trigger name; the activity type lives in the
# payload, so no document may tell an agent to match on `event: ready_for_review`.
for doc in "$policy" "$migration" "$skill_md" "$repo_root/_shared/REVIEW-LOOP.md"; do
  if rg -Fq 'event: ready_for_review' "$doc"; then
    fail "$doc: a workflow run reports event: pull_request, never event: ready_for_review"
  fi
done
rg -Fq 'gh pr ready' "$skill_md" || fail 'SKILL.md: must describe marking the PR ready'
rg -Fq 'short_description: "Audit and apply the draft-gated pull_request CI standard"' "$skill_root/agents/openai.yaml" || fail 'openai.yaml: short_description must match'

# New test sections belong above this line, under their own `# ---` marker;
# nothing may follow `completed=1` but the success line.
completed=1
printf 'skill fixtures passed\n'
