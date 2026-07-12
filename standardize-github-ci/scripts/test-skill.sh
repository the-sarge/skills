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

printf '# initial\n' > "$repo/docs/README.md"
printf 'package pkg\n' > "$repo/pkg/pkg.go"
git -C "$repo" add .
git -C "$repo" commit -qm initial
initial="$(git -C "$repo" rev-parse HEAD)"

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
test "$(printf '%s\n' "$audit_output" | rg -c 'Push paths: `unfiltered`')" = 1

CLASSIFY_RESULT=success DOCS_ONLY=true DOCS_RESULT=success CODE_RESULT=skipped "$require_results" >/dev/null
CLASSIFY_RESULT=success DOCS_ONLY=false DOCS_RESULT=skipped CODE_RESULT=success "$require_results" >/dev/null
if CLASSIFY_RESULT=success DOCS_ONLY=false DOCS_RESULT=skipped CODE_RESULT=failure "$require_results" >/dev/null 2>&1; then
  printf 'error: failed code result unexpectedly passed\n' >&2
  exit 1
fi

printf 'skill fixtures passed\n'
