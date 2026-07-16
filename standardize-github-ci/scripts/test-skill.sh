#!/usr/bin/env bash
set -euo pipefail

skill_root="$(cd "$(dirname "$0")/.." && pwd)"
audit="$skill_root/scripts/audit-ci.sh"
classify="$skill_root/assets/classify-ci-changes.sh"
require_results="$skill_root/assets/require-ci-results.sh"
workflow_template="$skill_root/assets/ci.yml.template"

command -v yq >/dev/null || {
  printf 'error: yq is required to validate the workflow template\n' >&2
  exit 1
}
yq eval '.' "$workflow_template" >/dev/null
test "$(yq -r '.on | has("pull_request") or has("pull_request_target")' "$workflow_template")" = false
test "$(yq -r '.on | has("workflow_dispatch")' "$workflow_template")" = true
test "$(yq -r '.on.workflow_dispatch.inputs.expected_sha.required' "$workflow_template")" = true
rg -q 'test "\$GITHUB_SHA" = "\$EXPECTED_SHA"' "$workflow_template"
if command -v actionlint >/dev/null; then
  actionlint "$workflow_template"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
repo="$tmp/repo"

mkdir -p "$repo/.github/workflows" "$repo/docs" "$repo/pkg"
git -C "$repo" init -q
git -C "$repo" config user.email ci-skill-test@example.invalid
git -C "$repo" config user.name ci-skill-test

cat > "$repo/.github/workflows/scalar.yml" <<'YAML'
name: Scalar
on: pull_request
jobs:
  check:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - run: 'true'
YAML

cat > "$repo/.github/workflows/list.yml" <<'YAML'
name: List
on: [push, pull_request]
jobs:
  check:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - run: 'true'
YAML

cat > "$repo/.github/workflows/map.yml" <<'YAML'
name: Map
on:
  pull_request:
    paths: ['**.go']
jobs:
  check:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - run: 'true'
YAML

cat > "$repo/.github/workflows/target.yml" <<'YAML'
name: Target
on: pull_request_target
jobs:
  check:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - run: 'true'
YAML

printf '# initial\n' > "$repo/docs/README.md"
printf 'package pkg\n' > "$repo/pkg/pkg.go"
git -C "$repo" add .
git -C "$repo" commit -qm initial

ras_without_dispatch="$(cd "$repo" && CI_USES_RAS=true "$audit")"
printf '%s\n' "$ras_without_dispatch" | rg -q 'RAS-BLOCKER repository: no operator-triggered exact-head certification path was detected'

cat > "$repo/.github/workflows/manual.yml" <<'YAML'
name: Manual certification
on:
  workflow_dispatch:
jobs:
  check:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - run: 'true'
YAML

git -C "$repo" add .github/workflows/manual.yml
git -C "$repo" commit -qm manual-unbound
ras_without_binding="$(cd "$repo" && CI_USES_RAS=true "$audit")"
printf '%s\n' "$ras_without_binding" | rg -q 'RAS-BLOCKER repository: operator-triggered certification exists but no exact-head binding evidence was detected'

cat > "$repo/.github/workflows/manual.yml" <<'YAML'
name: Manual certification
on:
  workflow_dispatch:
    inputs:
      expected_sha:
        description: Exact reviewed head
        required: true
        type: string
jobs:
  check:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - env:
          EXPECTED_SHA: ${{ inputs.expected_sha }}
        run: test "$GITHUB_SHA" = "$EXPECTED_SHA"
      - run: 'true'
YAML

git -C "$repo" add .github/workflows/manual.yml
git -C "$repo" commit -qm manual-bound
initial="$(git -C "$repo" rev-parse HEAD)"

label_repo="$tmp/label-repo"
mkdir -p "$label_repo/.github/workflows"
git -C "$label_repo" init -q
git -C "$label_repo" config user.email ci-skill-test@example.invalid
git -C "$label_repo" config user.name ci-skill-test
cat > "$label_repo/.github/workflows/certify.yml" <<'YAML'
name: Label certification
on:
  pull_request:
    types: [labeled]
permissions:
  contents: read
  pull-requests: write
jobs:
  check:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - env:
          TRIGGER_LABEL: ${{ github.event.label.name }}
          HEAD_SHA: ${{ github.event.pull_request.head.sha }}
          BASE_SHA: ${{ github.event.pull_request.base.sha }}
          MERGE_SHA: ${{ github.sha }}
          HEAD_REPOSITORY: ${{ github.event.pull_request.head.repo.full_name }}
          BASE_REPOSITORY: ${{ github.event.pull_request.base.repo.full_name }}
        run: |
          test "$TRIGGER_LABEL" = ci:certify
          gh api --method DELETE "repos/example/repo/issues/1/labels/$TRIGGER_LABEL"
          pr_json='{"merge_commit_sha":"0000000000000000000000000000000000000000"}'
          test "$(jq -r .merge_commit_sha <<< "$pr_json")" = "$MERGE_SHA"
          test -n "$HEAD_SHA$BASE_SHA$HEAD_REPOSITORY$BASE_REPOSITORY"
YAML
git -C "$label_repo" add .
git -C "$label_repo" commit -qm label-bound

label_audit_output="$(cd "$label_repo" && CI_USES_RAS=true "$audit")"
printf '%s\n' "$label_audit_output" | rg -Fq 'Pull request activity: `label-only operator trigger`'
printf '%s\n' "$label_audit_output" | rg -Fq 'Label-gated certification binding: `detected; verify label revocation and head/base/merge comparisons fail closed`'
printf '%s\n' "$label_audit_output" | rg -q 'Automatic pull-request workflows: `0`'
printf '%s\n' "$label_audit_output" | rg -q 'Label-gated certification candidates: `1`'
if printf '%s\n' "$label_audit_output" | rg -q 'RAS-(COST|BLOCKER)'; then
  printf 'error: exact-bound label certification unexpectedly emitted a RAS signal\n' >&2
  exit 1
fi

cat > "$label_repo/.github/workflows/certify.yml" <<'YAML'
name: Incomplete label certification
on:
  pull_request:
    types: [labeled]
jobs:
  check:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - run: 'true'
YAML
label_incomplete_output="$(cd "$label_repo" && CI_USES_RAS=true "$audit")"
printf '%s\n' "$label_incomplete_output" | rg -q 'RAS-BLOCKER .github/workflows/certify.yml: label-only certification lacks one-shot revocation or exact head/base/merge binding evidence'
printf '%s\n' "$label_incomplete_output" | rg -q 'RAS-BLOCKER repository: no operator-triggered exact-head certification path was detected'

printf '# documentation\n' >> "$repo/docs/README.md"
git -C "$repo" add docs/README.md
git -C "$repo" commit -qm docs
docs="$(git -C "$repo" rev-parse HEAD)"

docs_output="$(cd "$repo" && "$classify" "$initial" "$docs")"
printf '%s\n' "$docs_output" | rg -q '^docs_only=true$'
printf '%s\n' "$docs_output" | rg -q '^source_changed=false$'

printf 'var Changed = true\n' >> "$repo/pkg/pkg.go"
git -C "$repo" add pkg/pkg.go
git -C "$repo" commit -qm source
source="$(git -C "$repo" rev-parse HEAD)"

source_output="$(cd "$repo" && "$classify" "$docs" "$source")"
printf '%s\n' "$source_output" | rg -q '^docs_only=false$'
printf '%s\n' "$source_output" | rg -q '^source_changed=true$'

audit_output="$($audit "$repo")"
test "$(printf '%s\n' "$audit_output" | rg -c 'Pull request paths: `unfiltered`')" = 2
test "$(printf '%s\n' "$audit_output" | rg -c 'Pull request paths: `filtered`')" = 1
test "$(printf '%s\n' "$audit_output" | rg -c 'Pull request target paths: `unfiltered`')" = 1
test "$(printf '%s\n' "$audit_output" | rg -c 'Push paths: `unfiltered`')" = 1
test "$(printf '%s\n' "$audit_output" | rg -c 'Manual dispatch: present')" = 1
test "$(printf '%s\n' "$audit_output" | rg -c 'Exact-head dispatch binding: `detected; verify the comparison fails closed`')" = 1
if printf '%s\n' "$audit_output" | rg -q 'RAS-COST'; then
  printf 'error: non-RAS audit unexpectedly emitted a RAS cost signal\n' >&2
  exit 1
fi

ras_audit_output="$(cd "$repo" && CI_USES_RAS=true "$audit")"
printf '%s\n' "$ras_audit_output" | rg -Fq 'RAS-first review gate: `true` (CI_USES_RAS=true)'
test "$(printf '%s\n' "$ras_audit_output" | rg -c 'RAS-COST')" = 4
if printf '%s\n' "$ras_audit_output" | rg -q 'RAS-BLOCKER'; then
  printf 'error: dispatch-capable RAS audit unexpectedly emitted a blocker\n' >&2
  exit 1
fi
printf '%s\n' "$ras_audit_output" | rg -q 'Automatic pull-request workflows: `4`'
printf '%s\n' "$ras_audit_output" | rg -q 'Manual-dispatch workflows: `1`'
printf '%s\n' "$ras_audit_output" | rg -q 'Exact-head dispatch candidates: `1`'

CLASSIFY_RESULT=success DOCS_ONLY=true DOCS_RESULT=success CODE_RESULT=skipped "$require_results" >/dev/null
CLASSIFY_RESULT=success DOCS_ONLY=false DOCS_RESULT=skipped CODE_RESULT=success "$require_results" >/dev/null
if CLASSIFY_RESULT=success DOCS_ONLY=false DOCS_RESULT=skipped CODE_RESULT=failure "$require_results" >/dev/null 2>&1; then
  printf 'error: failed code result unexpectedly passed\n' >&2
  exit 1
fi

printf 'skill fixtures passed\n'
