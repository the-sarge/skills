# Simplify CI Standard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the dispatch/label/status-bridge CI machinery in `standardize-github-ci` and the shared review loop with one draft-gated `pull_request` standard, so every repository converges to an identical, fail-closed, human-readable CI shape.

**Architecture:** The skill ships four assets (`ci.yml`, `ci-classify.sh`, `Taskfile.ci.yml`, `ruleset.json`) that *are* the standard, a conformance auditor (`audit-ci.sh`) that checks a repository against those assets, and a forward-test harness (`test-skill.sh`) that pins both. Policy and migration references describe the same standard in prose. `_shared/REVIEW-LOOP.md` and its consumers switch from "request CI through a trigger" to "mark the draft PR ready".

**Tech Stack:** bash 3.2-compatible shell (macOS default), `yq` v4, `jq`, `rg`, `actionlint`, `gh`, GitHub Actions YAML, Taskfile v3, GitHub rulesets API.

**Spec:** `docs/superpowers/specs/2026-08-18-simplify-ci-standard-design.md`

## Global Constraints

- Work only in the worktree `/Volumes/worktrees/skills/simplify-ci-standard` on branch `codex/simplify-ci-standard`. Run `git status --short --branch` before edits and before every commit; stop on unexpected changes.
- Do not hard-wrap Markdown prose; one physical line per paragraph. Do not rewrap existing paragraphs you are not otherwise changing.
- Shell scripts must run on bash 3.2: no `mapfile`, no associative arrays, no `${var,,}`, no `declare -A`. Use `set -euo pipefail`. Pass `shellcheck` with no warnings.
- Workflow assets pin third-party actions to full 40-hex commit SHAs with a trailing `# vX.Y.Z` comment: `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1`, `actions/setup-go@b7ad1dad31e06c5925ef5d2fc7ad053ef454303e # v7.0.0`, `arduino/setup-task@c0bc642852239c2689f73f4ea6459c29405f3c52 # v3.0.0`.
- Required workflow trigger is exactly `pull_request` with `types: [opened, synchronize, reopened, ready_for_review]`. Required jobs are named `ci-required` or `ci-<lane>`, carry no `needs:` and no `strategy.matrix`, and run exactly one Taskfile target (`task ci` or `task ci-<lane>`).
- GitHub carries no review-tool state: no RAS names, labels, inputs, statuses, or verdicts anywhere in assets, docs, or scripts.
- `standardize-github-ci/scripts/test-skill.sh` must pass at the end of every task that touches the skill (`bash standardize-github-ci/scripts/test-skill.sh`).
- Commit after every task with a message in the repository's imperative style (see `git log --oneline -10`).

---

## File structure

| Path | Responsibility | Action |
|---|---|---|
| `standardize-github-ci/assets/ci.yml` | The required workflow skeleton every repository copies | create |
| `standardize-github-ci/assets/ci-classify.sh` | Docs-only yes/no classifier used by `task ci`; fail-closed | create |
| `standardize-github-ci/assets/Taskfile.ci.yml` | Taskfile snippet defining `ci`, `ci-<lane>`, `docs-check`, `check` | create |
| `standardize-github-ci/assets/ruleset.json` | Default-branch ruleset body for `gh api` | create |
| `standardize-github-ci/assets/ci.yml.template`, `classify-ci-changes.sh`, `require-ci-results.sh` | superseded | delete |
| `standardize-github-ci/scripts/audit-ci.sh` | Read-only conformance audit against the standard | rewrite |
| `standardize-github-ci/scripts/test-skill.sh` | Forward tests for assets, classifier, and audit | rewrite |
| `standardize-github-ci/references/ci-policy.md` | The standard in prose | rewrite |
| `standardize-github-ci/references/migration.md` | Per-repository migration checklist | rewrite |
| `standardize-github-ci/SKILL.md` | Skill entry: modes, load order, audit/plan/apply/validate/deliver | rewrite |
| `standardize-github-ci/agents/openai.yaml` | Agent-facing description | edit |
| `_shared/REVIEW-LOOP.md` | Draft→ready convention replaces trigger language | edit |
| `loop-review-merge/SKILL.md`, `implement-architecture-slice/SKILL.md`, `planit/SKILL.md` | Consumers reference the convention | edit |

---

### Task 1: Required workflow asset and new test harness

**Files:**
- Create: `standardize-github-ci/assets/ci.yml`
- Rewrite: `standardize-github-ci/scripts/test-skill.sh`
- Delete: `standardize-github-ci/assets/ci.yml.template`, `standardize-github-ci/assets/classify-ci-changes.sh`, `standardize-github-ci/assets/require-ci-results.sh`

**Interfaces:**
- Produces: `assets/ci.yml` — the canonical skeleton. Later tasks (audit fixtures) copy this file verbatim as the "conformant" fixture.
- Produces: `test-skill.sh` skeleton with a `tmp` fixture dir, `fail()` helper, and section markers `# --- assets`, `# --- classifier`, `# --- audit`, `# --- docs` that later tasks append to.

- [ ] **Step 1: Delete the superseded assets and write the failing test harness**

```bash
cd /Volumes/worktrees/skills/simplify-ci-standard
git status --short --branch
git rm -q standardize-github-ci/assets/ci.yml.template standardize-github-ci/assets/classify-ci-changes.sh standardize-github-ci/assets/require-ci-results.sh
```

Write `standardize-github-ci/scripts/test-skill.sh`:

```bash
#!/usr/bin/env bash
# Forward tests for the standardize-github-ci skill: assets, classifier, audit, docs.
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
```

- [ ] **Step 2: Run the harness to verify it fails**

Run: `bash standardize-github-ci/scripts/test-skill.sh`
Expected: `error: missing .../assets/ci.yml`

- [ ] **Step 3: Write `standardize-github-ci/assets/ci.yml`**

```yaml
# Portfolio required CI workflow. Copy verbatim; change only `runs-on`
# and, when a repository has additional merge-blocking lanes, add sibling
# `ci-<lane>` jobs with the same guard, timeout, setup steps, and one
# `task ci-<lane>` step. Never add `needs`, `strategy.matrix`, other
# triggers, or path filters. See references/ci-policy.md.
name: ci
on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]
concurrency:
  group: ci-${{ github.event.pull_request.number }}
  cancel-in-progress: true
permissions:
  contents: read
jobs:
  ci-required:
    if: ${{ !github.event.pull_request.draft && github.event.pull_request.head.repo.full_name == github.repository }}
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          fetch-depth: 0
      - uses: actions/setup-go@b7ad1dad31e06c5925ef5d2fc7ad053ef454303e # v7.0.0
        with:
          go-version-file: go.mod
      - uses: arduino/setup-task@c0bc642852239c2689f73f4ea6459c29405f3c52 # v3.0.0
        with:
          version: 3.x
          repo-token: ${{ secrets.GITHUB_TOKEN }}
      - run: task ci
```

- [ ] **Step 4: Run the harness to verify it passes**

Run: `bash standardize-github-ci/scripts/test-skill.sh && actionlint standardize-github-ci/assets/ci.yml && shellcheck standardize-github-ci/scripts/test-skill.sh`
Expected: `skill fixtures passed`, no actionlint or shellcheck output.

- [ ] **Step 5: Commit**

```bash
git status --short --branch
git add standardize-github-ci/assets standardize-github-ci/scripts/test-skill.sh
git commit -m "standardize-github-ci: ship the draft-gated pull_request workflow asset"
```

---

### Task 2: Docs-only classifier asset

**Files:**
- Create: `standardize-github-ci/assets/ci-classify.sh`
- Modify: `standardize-github-ci/scripts/test-skill.sh` (append under `# --- classifier`)

**Interfaces:**
- Produces: `assets/ci-classify.sh` — prints exactly one line `docs_only=true` or `docs_only=false` to stdout, always exits 0, fails closed. Env: `CI_BASE_SHA` (explicit base), `CI_HEAD_SHA` (default `HEAD`), `CI_DEFAULT_BRANCH` (default: `origin/HEAD` target, else `main`), `CI_REMOTE` (default `origin`), `CI_DOCS_GLOBS` (space-separated shell globs; default `*.md docs/* DEV-JOURNAL.md LICENSE LICENSE.*`). Appends the same line to `$GITHUB_OUTPUT` when set.

- [ ] **Step 1: Append failing classifier tests**

Insert after the `# --- classifier` line in `test-skill.sh`:

```bash
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
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash standardize-github-ci/scripts/test-skill.sh`
Expected: `error: missing or non-executable .../assets/ci-classify.sh`

- [ ] **Step 3: Write `standardize-github-ci/assets/ci-classify.sh`**

```bash
#!/usr/bin/env bash
# Answers exactly one question for `task ci`: is this change docs-only?
# Prints `docs_only=true` or `docs_only=false` and always exits 0.
# Fails closed: any doubt (no base, empty diff, non-doc file) => false.
#
# Env:
#   CI_BASE_SHA        explicit base commit (default: merge-base with the default branch)
#   CI_HEAD_SHA        head commit (default: HEAD)
#   CI_DEFAULT_BRANCH  default branch name (default: origin/HEAD target, else main)
#   CI_REMOTE          remote name (default: origin)
#   CI_DOCS_GLOBS      space-separated shell globs treated as documentation
#                      (default: '*.md docs/* DEV-JOURNAL.md LICENSE LICENSE.*')
set -euo pipefail
set -f # never pathname-expand the globs

remote="${CI_REMOTE:-origin}"
head="${CI_HEAD_SHA:-HEAD}"
docs_globs="${CI_DOCS_GLOBS:-*.md docs/* DEV-JOURNAL.md LICENSE LICENSE.*}"

emit() {
  printf 'docs_only=%s\n' "$1"
  if test -n "${GITHUB_OUTPUT:-}"; then
    printf 'docs_only=%s\n' "$1" >> "$GITHUB_OUTPUT"
  fi
  exit 0
}

default_branch="${CI_DEFAULT_BRANCH:-}"
if test -z "$default_branch"; then
  default_branch="$(git symbolic-ref -q --short "refs/remotes/$remote/HEAD" 2>/dev/null | sed "s#^$remote/##" || true)"
  default_branch="${default_branch:-main}"
fi

base="${CI_BASE_SHA:-}"
if test -z "$base"; then
  if git rev-parse --verify -q "$remote/$default_branch^{commit}" >/dev/null; then
    base="$(git merge-base "$remote/$default_branch" "$head" 2>/dev/null || true)"
  elif git rev-parse --verify -q "$default_branch^{commit}" >/dev/null; then
    base="$(git merge-base "$default_branch" "$head" 2>/dev/null || true)"
  fi
fi

if test -z "$base" || ! git rev-parse --verify -q "$base^{commit}" >/dev/null || ! git rev-parse --verify -q "$head^{commit}" >/dev/null; then
  printf 'ci-classify: cannot determine a trustworthy base; failing closed\n' >&2
  emit false
fi

changed="$(git diff --name-only --no-renames "$base" "$head")"
if test -z "$changed"; then
  printf 'ci-classify: empty diff; failing closed\n' >&2
  emit false
fi

while IFS= read -r path; do
  test -n "$path" || continue
  matched=false
  for glob in $docs_globs; do
    # shellcheck disable=SC2254
    case "$path" in
      $glob) matched=true; break ;;
    esac
  done
  if test "$matched" = false; then
    printf 'ci-classify: %s is not documentation\n' "$path" >&2
    emit false
  fi
done <<< "$changed"

emit true
```

Then `chmod +x standardize-github-ci/assets/ci-classify.sh`.

- [ ] **Step 4: Run to verify it passes**

Run: `bash standardize-github-ci/scripts/test-skill.sh && shellcheck standardize-github-ci/assets/ci-classify.sh`
Expected: `skill fixtures passed`, no shellcheck output.

- [ ] **Step 5: Commit**

```bash
git status --short --branch
git add standardize-github-ci/assets/ci-classify.sh standardize-github-ci/scripts/test-skill.sh
git commit -m "standardize-github-ci: add fail-closed docs-only classifier for task ci"
```

---

### Task 3: Taskfile snippet and ruleset assets

**Files:**
- Create: `standardize-github-ci/assets/Taskfile.ci.yml`
- Create: `standardize-github-ci/assets/ruleset.json`
- Modify: `standardize-github-ci/scripts/test-skill.sh` (append under `# --- assets`, before `# --- classifier`)

**Interfaces:**
- Produces: Taskfile targets `ci`, `ci-race` (example lane), `docs-check`, `check`. `ci` and `ci-<lane>` call `scripts/ci-classify.sh` and branch on its output.
- Produces: `ruleset.json` — body for `gh api --method POST repos/<owner>/<repo>/rulesets --input assets/ruleset.json`; `required_status_checks` lists `ci-required` with `integration_id` 15368 (GitHub Actions); migrations append `ci-<lane>` contexts.

- [ ] **Step 1: Append failing asset tests**

Insert before the `# --- classifier` line:

```bash
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
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash standardize-github-ci/scripts/test-skill.sh`
Expected: `error: missing .../assets/Taskfile.ci.yml`

- [ ] **Step 3: Write `standardize-github-ci/assets/Taskfile.ci.yml`**

```yaml
# Merge these tasks into the repository's Taskfile.yml. `ci` is the only
# target .github/workflows/ci.yml calls. `docs-check` and `check` are
# repository-owned; replace their bodies. Add one `ci-<lane>` task per
# additional required job (see `ci-race`); delete it if unused.
version: '3'

vars:
  # Space-separated shell globs treated as documentation by scripts/ci-classify.sh.
  CI_DOCS_GLOBS: '*.md docs/* DEV-JOURNAL.md LICENSE LICENSE.*'

tasks:
  ci:
    desc: Required merge gate; docs-only changes run docs-check, everything else runs check
    cmds:
      - |
        result="$(CI_DOCS_GLOBS='{{.CI_DOCS_GLOBS}}' scripts/ci-classify.sh)"
        case "$result" in
          docs_only=true) task docs-check ;;
          *) task check ;;
        esac

  ci-race:
    desc: Example additional required lane; skips work for docs-only changes but still reports success
    cmds:
      - |
        result="$(CI_DOCS_GLOBS='{{.CI_DOCS_GLOBS}}' scripts/ci-classify.sh)"
        case "$result" in
          docs_only=true) echo "docs-only change; race lane not applicable" ;;
          *) task race ;;
        esac

  docs-check:
    desc: Documentation checks (repository-owned)
    cmds:
      - echo "replace with the repository's documentation checks"

  check:
    desc: Ordinary merge gate (repository-owned)
    cmds:
      - echo "replace with the repository's format, vet, lint, test, and build checks"

  race:
    desc: Race lane body (repository-owned; only if ci-race is used)
    cmds:
      - echo "replace with the repository's race tests"
```

- [ ] **Step 4: Write `standardize-github-ci/assets/ruleset.json`**

```json
{
  "name": "default-branch",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["~DEFAULT_BRANCH"],
      "exclude": []
    }
  },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false,
        "allowed_merge_methods": ["squash"]
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "do_not_enforce_on_create": false,
        "required_status_checks": [
          { "context": "ci-required", "integration_id": 15368 }
        ]
      }
    }
  ]
}
```

- [ ] **Step 5: Run to verify it passes**

Run: `bash standardize-github-ci/scripts/test-skill.sh`
Expected: `skill fixtures passed`

- [ ] **Step 6: Commit**

```bash
git status --short --branch
git add standardize-github-ci/assets/Taskfile.ci.yml standardize-github-ci/assets/ruleset.json standardize-github-ci/scripts/test-skill.sh
git commit -m "standardize-github-ci: add Taskfile ci snippet and default-branch ruleset assets"
```

---

### Task 4: Conformance audit — required workflow checks

**Files:**
- Rewrite: `standardize-github-ci/scripts/audit-ci.sh`
- Modify: `standardize-github-ci/scripts/test-skill.sh` (append under `# --- audit`)

**Interfaces:**
- Produces: `scripts/audit-ci.sh [repo-path]`. Read-only. Prints a Markdown report ending in a `## Deviations` section. Exit 0 when conformant, 3 when deviations exist, 2 on usage/tool error. Deviation lines have the form `` - `CODE` path: message ``. Codes emitted by this task: `CI-MISSING`, `CI-TRIGGER`, `CI-CONCURRENCY`, `CI-PERMISSIONS`, `CI-JOBS`, `CI-JOB-NAME`, `CI-GUARD`, `CI-TIMEOUT`, `CI-NEEDS`, `CI-MATRIX`, `CI-TARGET`, `CI-PIN`, `CI-FETCH-DEPTH`. Task 5 adds `WF-*`, `TASK-*`, `CLASSIFY-*`, `RULES-*`.
- Env consumed (Task 5): `CI_AUDIT_RULESET_JSON`, `CI_AUDIT_RULESET`.

- [ ] **Step 1: Append failing audit tests for the required workflow**

Insert after `# --- audit`:

```bash
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

run_audit() { # dir [env...]; prints output; stores exit code in audit_rc
  dir="$1"; shift
  set +e
  audit_out="$(env "$@" "$audit" "$dir" 2>&1)"
  audit_rc=$?
  set -e
  printf '%s\n' "$audit_out"
}

expect_deviation() { # output code
  printf '%s\n' "$1" | rg -Fq "\`$2\`" || fail "audit: expected deviation $2; got:
$1"
}

conf="$tmp/conformant"
make_conformant_repo "$conf"
out="$(run_audit "$conf")"
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
  out="$(run_audit "$d")"
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
out="$(run_audit "$lane")"
test "$audit_rc" -eq 0 || fail "audit: two-lane repo must exit 0:
$out"
printf '%s\n' "$out" | rg -Fq 'Required jobs: `ci-required`, `ci-race`' || fail 'audit: must list both required jobs'

# missing workflow
nowf="$tmp/nowf"
make_conformant_repo "$nowf"
git -C "$nowf" rm -q .github/workflows/ci.yml && git -C "$nowf" commit -qm nowf
out="$(run_audit "$nowf")"
test "$audit_rc" -eq 3 || fail 'audit: missing ci.yml must exit 3'
expect_deviation "$out" CI-MISSING
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash standardize-github-ci/scripts/test-skill.sh`
Expected: failure at the conformant-repo assertion (old audit prints a different report and exits 0 with RAS-era output; the `- None. Repository conforms` grep fails).

- [ ] **Step 3: Rewrite `standardize-github-ci/scripts/audit-ci.sh` (workflow section; Task 5 adds the rest)**

```bash
#!/usr/bin/env bash
# Read-only conformance audit of one repository against the portfolio CI standard
# (standardize-github-ci/references/ci-policy.md).
#
# Usage: audit-ci.sh [repository-path]
# Env:   CI_AUDIT_RULESET_JSON=<file>  audit default-branch rules from this JSON (array from
#                                      GET /repos/{o}/{r}/rules/branches/{branch}) instead of GitHub
#        CI_AUDIT_RULESET=live         query GitHub with gh for the default-branch rules
# Exit:  0 conformant, 3 deviations found, 2 usage or tool error.
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

  job_names="$(printf '%s' "$wf" | jq -r '.jobs // {} | keys[]')"
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
```

End the file (for this task) with:

```bash
# --- deviations
printf '## Deviations\n\n'
if test -z "$deviations"; then
  printf -- '- None. Repository conforms to the standard.\n'
  exit 0
fi
printf '%s\n' "$deviations"
exit 3
```

- [ ] **Step 4: Run to verify it passes**

Run: `bash standardize-github-ci/scripts/test-skill.sh && shellcheck standardize-github-ci/scripts/audit-ci.sh`
Expected: `skill fixtures passed`; shellcheck clean (add `# shellcheck disable=SC2016` at the top if it complains about the backtick literals in single quotes).

- [ ] **Step 5: Commit**

```bash
git status --short --branch
git add standardize-github-ci/scripts/audit-ci.sh standardize-github-ci/scripts/test-skill.sh
git commit -m "standardize-github-ci: rewrite audit as conformance check for the required workflow"
```

---

### Task 5: Conformance audit — other workflows, Taskfile, classifier, ruleset

**Files:**
- Modify: `standardize-github-ci/scripts/audit-ci.sh` (insert before `# --- deviations`)
- Modify: `standardize-github-ci/scripts/test-skill.sh` (append under `# --- audit`)

**Interfaces:**
- Produces deviation codes: `WF-PR-TRIGGER`, `WF-TIMEOUT`, `WF-PIN`, `TASK-CI-MISSING`, `TASK-LANE-MISSING`, `TASK-CHECK-MISSING`, `TASK-DOCS-CHECK-MISSING`, `CLASSIFY-MISSING`, `RULES-PR`, `RULES-CHECKS`, `RULES-STRICT`, `RULES-SQUASH`, `RULES-DELETION`, `RULES-FF`, `RULES-LEGACY`.
- Consumes: `CI_AUDIT_RULESET_JSON=<file>` (array of rule objects), `CI_AUDIT_RULESET=live` (uses `gh api repos/<slug>/rules/branches/<default>` and `gh api repos/<slug>/branches/<default>/protection`).

- [ ] **Step 1: Append failing tests**

```bash
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
YAML
git -C "$other" add . && git -C "$other" commit -qm deep
out="$(run_audit "$other")"
test "$audit_rc" -eq 0 || fail "audit: scheduled non-required workflow must be conformant:
$out"
printf '%s\n' "$out" | rg -Fq '`deep-ci.yml`' || fail 'audit: must list other workflows'

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
out="$(run_audit "$other")"
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
out="$(run_audit "$other")"
expect_deviation "$out" WF-PR-TRIGGER

# Taskfile and classifier presence
tf="$tmp/taskfile"
make_conformant_repo "$tf"
yq -i 'del(.tasks.ci)' "$tf/Taskfile.yml"
git -C "$tf" commit -qam noci
out="$(run_audit "$tf")"
expect_deviation "$out" TASK-CI-MISSING
yq -i 'del(.tasks.check) | del(.tasks["docs-check"])' "$tf/Taskfile.yml"
git -C "$tf" commit -qam nolanes
out="$(run_audit "$tf")"
expect_deviation "$out" TASK-CHECK-MISSING
expect_deviation "$out" TASK-DOCS-CHECK-MISSING
git -C "$tf" rm -q scripts/ci-classify.sh && git -C "$tf" commit -qm noclassify
out="$(run_audit "$tf")"
expect_deviation "$out" CLASSIFY-MISSING

lanetf="$tmp/lanetf"
make_conformant_repo "$lanetf"
yq -i '.jobs["ci-fuzz"] = .jobs["ci-required"] | .jobs["ci-fuzz"].steps[-1].run = "task ci-fuzz"' "$lanetf/.github/workflows/ci.yml"
git -C "$lanetf" commit -qam lane
out="$(run_audit "$lanetf")"
expect_deviation "$out" TASK-LANE-MISSING

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
out="$(run_audit "$conf" CI_AUDIT_RULESET_JSON="$good_rules")"
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
out="$(run_audit "$conf" CI_AUDIT_RULESET_JSON="$bad_rules")"
test "$audit_rc" -eq 3 || fail 'audit: bad ruleset must exit 3'
expect_deviation "$out" RULES-CHECKS
expect_deviation "$out" RULES-STRICT
expect_deviation "$out" RULES-SQUASH
expect_deviation "$out" RULES-DELETION
expect_deviation "$out" RULES-FF

# two-lane repo: rules must require both contexts
out="$(run_audit "$lane" CI_AUDIT_RULESET_JSON="$good_rules")"
expect_deviation "$out" RULES-CHECKS

# empty rules array: no PR rule and no checks
printf '[]\n' > "$tmp/rules-empty.json"
out="$(run_audit "$conf" CI_AUDIT_RULESET_JSON="$tmp/rules-empty.json")"
expect_deviation "$out" RULES-PR
expect_deviation "$out" RULES-CHECKS
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash standardize-github-ci/scripts/test-skill.sh`
Expected: `error: audit: must list other workflows` (or the first missing section).

- [ ] **Step 3: Insert the remaining sections into `audit-ci.sh` before `# --- deviations`**

```bash
# --- other workflows
printf '## Other workflows\n\n'
other_count=0
if test -d "$workflow_dir"; then
  while IFS= read -r wf_path; do
    test -n "$wf_path" || continue
    test "$wf_path" != "$ci_yml" || continue
    other_count=$((other_count + 1))
    rel="${wf_path#"$repo_root"/}"
    base_name="$(basename "$wf_path")"
    owf="$(yq -o=json -I=0 '.' "$wf_path")"
    triggers="$(printf '%s' "$owf" | jq -r '.on | if type=="string" then . elif type=="array" then join(", ") elif type=="object" then (keys|join(", ")) else "none" end')"
    printf -- '- `%s`: triggers `%s`\n' "$base_name" "$triggers"
    if printf '%s' "$owf" | jq -e '.on | if type=="string" then (.=="pull_request" or .=="pull_request_target") elif type=="array" then (index("pull_request")!=null or index("pull_request_target")!=null) elif type=="object" then (has("pull_request") or has("pull_request_target")) else false end' >/dev/null 2>&1; then
      deviate WF-PR-TRIGGER "$rel: only ci.yml may use pull_request or pull_request_target; move this workflow to schedule, push tags, or workflow_dispatch"
    fi
    missing_timeouts="$(printf '%s' "$owf" | jq -r '[.jobs // {} | to_entries[] | select(.value["timeout-minutes"] == null) | .key] | join(", ")')"
    if test -n "$missing_timeouts"; then
      deviate WF-TIMEOUT "$rel: jobs missing timeout-minutes: $missing_timeouts"
    fi
    while IFS= read -r uses; do
      test -n "$uses" || continue
      printf '%s' "$uses" | grep -Eq '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(/[A-Za-z0-9_./-]+)?@[0-9a-f]{40}$' \
        || deviate WF-PIN "$rel: unpinned action $uses"
    done <<< "$(printf '%s' "$owf" | jq -r '.jobs // {} | .[] | .steps[]? | select(has("uses")) | .uses')"
  done <<< "$(find "$workflow_dir" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) -print | sort)"
fi
if test "$other_count" -eq 0; then
  printf -- '- None\n'
fi
printf '\n'

# --- Taskfile and classifier
printf '## Taskfile\n\n'
taskfile="$(find "$repo_root" -maxdepth 1 -type f \( -iname 'taskfile.yml' -o -iname 'taskfile.yaml' \) -print -quit)"
if test -z "$taskfile"; then
  printf -- '- Missing\n'
  deviate TASK-CI-MISSING 'Taskfile.yml: not found; the required workflow runs task ci'
else
  tasks_json="$(yq -o=json -I=0 '.tasks // {}' "$taskfile")"
  has_task() { printf '%s' "$tasks_json" | jq -e --arg t "$1" 'has($t)' >/dev/null 2>&1; }
  for t in ci check docs-check; do
    if has_task "$t"; then printf -- '- `%s`: present\n' "$t"; else printf -- '- `%s`: missing\n' "$t"; fi
  done
  has_task ci || deviate TASK-CI-MISSING "$(basename "$taskfile"): task ci is required"
  has_task check || deviate TASK-CHECK-MISSING "$(basename "$taskfile"): task check is required"
  has_task docs-check || deviate TASK-DOCS-CHECK-MISSING "$(basename "$taskfile"): task docs-check is required"
  while IFS= read -r job; do
    test -n "$job" || continue
    case "$job" in
      ci-required) ;;
      ci-*) has_task "$job" || deviate TASK-LANE-MISSING "$(basename "$taskfile"): task $job is required by job $job" ;;
    esac
  done <<< "${job_names:-}"
fi
if test -x "$repo_root/scripts/ci-classify.sh"; then
  printf -- '- `scripts/ci-classify.sh`: present\n'
else
  printf -- '- `scripts/ci-classify.sh`: missing\n'
  deviate CLASSIFY-MISSING 'scripts/ci-classify.sh: missing or not executable; copy it from the skill assets'
fi
printf '\n'

# --- default-branch rules
printf '## Default-branch rules\n\n'
rules_json=""
rules_source='not checked (set CI_AUDIT_RULESET=live or CI_AUDIT_RULESET_JSON=<file>)'
legacy_protection=unknown
if test -n "${CI_AUDIT_RULESET_JSON:-}"; then
  rules_json="$(cat "$CI_AUDIT_RULESET_JSON")"
  rules_source="\`$CI_AUDIT_RULESET_JSON\`"
elif test "${CI_AUDIT_RULESET:-}" = live; then
  require_command gh
  origin_url="$(git -C "$repo_root" remote get-url origin 2>/dev/null || true)"
  slug="$(printf '%s' "$origin_url" | sed -E 's#^(https://github.com/|git@github.com:)##; s#\.git$##')"
  default_branch="$(gh api "repos/$slug" --jq .default_branch)"
  rules_json="$(gh api "repos/$slug/rules/branches/$default_branch")"
  rules_source="live \`$slug\` \`$default_branch\`"
  if gh api "repos/$slug/branches/$default_branch/protection" >/dev/null 2>&1; then
    legacy_protection=present
  else
    legacy_protection=absent
  fi
fi
printf -- '- Source: %s\n' "$rules_source"
if test -n "$rules_json"; then
  r() { printf '%s' "$rules_json" | jq -e "$1" >/dev/null 2>&1; }
  r 'any(.[]; .type=="pull_request")' || deviate RULES-PR 'default branch: a pull_request rule is required (no direct pushes)'
  r 'any(.[]; .type=="pull_request" and (.parameters.allowed_merge_methods // []) == ["squash"])' || deviate RULES-SQUASH 'default branch: allowed merge methods must be exactly [squash]'
  r 'any(.[]; .type=="deletion")' || deviate RULES-DELETION 'default branch: deletion must be blocked'
  r 'any(.[]; .type=="non_fast_forward")' || deviate RULES-FF 'default branch: force pushes must be blocked'
  r 'any(.[]; .type=="required_status_checks" and .parameters.strict_required_status_checks_policy==true)' || deviate RULES-STRICT 'default branch: required status checks must be strict (branch up to date)'
  expected_contexts="$(printf '%s\n' "${job_names:-}" | grep -E '^ci-' | sort | jq -R . | jq -sc .)"
  actual_contexts="$(printf '%s' "$rules_json" | jq -c '[.[] | select(.type=="required_status_checks") | .parameters.required_status_checks[]? | .context] | sort')"
  printf -- '- Required contexts: expected `%s`, actual `%s`\n' "$expected_contexts" "$actual_contexts"
  test "$expected_contexts" = "$actual_contexts" || deviate RULES-CHECKS "default branch: required status checks must be exactly the ci-* jobs $expected_contexts (actual $actual_contexts)"
  if test "$legacy_protection" = present; then
    deviate RULES-LEGACY 'default branch: legacy branch protection is present; replace it with the ruleset'
  fi
fi
printf '\n'
```

- [ ] **Step 4: Run to verify it passes**

Run: `bash standardize-github-ci/scripts/test-skill.sh && shellcheck standardize-github-ci/scripts/audit-ci.sh`
Expected: `skill fixtures passed`; shellcheck clean.

- [ ] **Step 5: Commit**

```bash
git status --short --branch
git add standardize-github-ci/scripts/audit-ci.sh standardize-github-ci/scripts/test-skill.sh
git commit -m "standardize-github-ci: audit other workflows, Taskfile, classifier, and default-branch rules"
```

---

### Task 6: Rewrite `references/ci-policy.md`

**Files:**
- Rewrite: `standardize-github-ci/references/ci-policy.md`
- Modify: `standardize-github-ci/scripts/test-skill.sh` (append under `# --- docs`)

- [ ] **Step 1: Append failing doc assertions**

```bash
policy="$skill_root/references/ci-policy.md"
rg -Fq 'types: [opened, synchronize, reopened, ready_for_review]' "$policy" || fail 'ci-policy.md: must state the trigger'
rg -Fq 'ci-<lane>' "$policy" || fail 'ci-policy.md: must define ci-<lane> jobs'
rg -Fq 'strict' "$policy" || fail 'ci-policy.md: must require strict up-to-date'
rg -Fq 'squash' "$policy" || fail 'ci-policy.md: must require squash-only'
if rg -qi 'expected_sha|status bridge|ci:certify|ci-certify|workflow_dispatch.*certif|labeled' "$policy"; then
  fail 'ci-policy.md: must not describe dispatch/label certification'
fi
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash standardize-github-ci/scripts/test-skill.sh`
Expected: `error: ci-policy.md: must state the trigger`

- [ ] **Step 3: Write `standardize-github-ci/references/ci-policy.md`**

````markdown
# Portfolio GitHub CI Standard

## Contents

- [Purpose](#purpose)
- [Responsibility boundary](#responsibility-boundary)
- [Required workflow](#required-workflow)
- [Required jobs](#required-jobs)
- [Taskfile contract](#taskfile-contract)
- [Default-branch ruleset](#default-branch-ruleset)
- [Non-required workflows](#non-required-workflows)
- [Runners](#runners)
- [Review-tool agnosticism](#review-tool-agnosticism)
- [Agent convention](#agent-convention)
- [What the standard forbids](#what-the-standard-forbids)

## Purpose

One CI shape for every repository: a `pull_request`-triggered workflow that skips draft PRs, one or more independent required jobs that each run one Taskfile target, and one identical default-branch ruleset. The shape is identical across repositories so that any workflow, ruleset, or merge problem is the same problem everywhere. Cost control comes from drafts (no CI during review) and from a docs-only shortcut inside `task ci`, not from orchestration cleverness in YAML.

## Responsibility boundary

| Layer | Owns |
|---|---|
| `.github/workflows/ci.yml` | Trigger, draft and same-repo guards, concurrency, permissions, timeouts, runner per job, pinned setup steps, one `task` call per job |
| Taskfile and `scripts/ci-classify.sh` | What CI checks: `ci` decides docs-only vs. full, `docs-check` and `check` hold the repository's real commands, `ci-<lane>` holds any additional required lane |
| Default-branch ruleset | Require PR, required `ci-*` checks, strict up-to-date, no force-push or deletion, squash-only |
| Agent and review loop | Open PRs as drafts, review out of band, mark ready when locally certified, merge the exact green head |

## Required workflow

Every repository has `.github/workflows/ci.yml` copied from [`assets/ci.yml`](../assets/ci.yml). It is byte-identical across repositories except `runs-on` and any additional `ci-<lane>` jobs.

- Trigger: exactly `pull_request` with `types: [opened, synchronize, reopened, ready_for_review]`. No `push`, `workflow_dispatch`, `pull_request_target`, `paths`, `paths-ignore`, or `branches` filters.
- Concurrency: `group: ci-${{ github.event.pull_request.number }}`, `cancel-in-progress: true`.
- Permissions: `contents: read` at workflow level and nothing else unless a Taskfile target demonstrably needs more.
- Every job: `if: ${{ !github.event.pull_request.draft && github.event.pull_request.head.repo.full_name == github.repository }}`, `timeout-minutes`, third-party actions pinned to full commit SHAs, `actions/checkout` with `fetch-depth: 0` so `scripts/ci-classify.sh` can compute a merge base.

Why the draft guard is safe: GitHub refuses to merge a draft PR regardless of checks, so a draft's skipped `ci-required` can never satisfy the ruleset. The moment the PR is marked ready, `ready_for_review` starts a real run on the live head; every later push starts another. The required check therefore only ever exists as a real run on a non-draft head.

## Required jobs

The workflow contains one or more independent required jobs:

- `ci-required` (always present) runs `task ci`.
- `ci-<lane>` (optional, e.g. `ci-race`) runs `task ci-<lane>`. Use one when a lane must block merging *and* needs its own runner or timeout. Each `ci-<lane>` job repeats the guard, timeout, and pinned setup steps, sets its own `runs-on`, and appears in the ruleset's required checks.
- No job declares `needs:`; no job uses `strategy.matrix`. Each required job either ran and passed or is absent, and absence blocks the merge. That is the fail-closed guarantee, and it needs no aggregation script.

Choice rule: a lane that is merge-blocking today becomes a `ci-<lane>` job; a lane that is not merge-blocking moves to a [non-required workflow](#non-required-workflows).

## Taskfile contract

Copy [`assets/Taskfile.ci.yml`](../assets/Taskfile.ci.yml) into the repository `Taskfile.yml` and [`assets/ci-classify.sh`](../assets/ci-classify.sh) to `scripts/ci-classify.sh` unchanged.

- `ci`: runs `scripts/ci-classify.sh`; on `docs_only=true` runs `docs-check`, otherwise runs `check`. Empty diffs, an unknown base, and unknown file types classify as not docs-only.
- `docs-check`: repository-owned documentation checks.
- `check`: repository-owned ordinary merge gate (format, vet, lint, unit tests, build smoke).
- `ci-<lane>`: runs the classifier, exits successfully with a message on docs-only changes, otherwise runs the lane.
- `CI_DOCS_GLOBS` (Taskfile var): space-separated shell globs treated as documentation. Default `*.md docs/* DEV-JOURNAL.md LICENSE LICENSE.*`. Extend it per repository rather than editing the script.

`task ci` behaves identically on a laptop and in CI, so a wrong classification is reproducible locally without pushing.

## Default-branch ruleset

Apply [`assets/ruleset.json`](../assets/ruleset.json) to every repository's default branch, replacing legacy branch protection where present. Ruleset changes are external mutations and require explicit operator authorization.

- Require a pull request before merging.
- Required status checks: every `ci-*` job in `ci.yml`, sourced from the GitHub Actions integration (`integration_id` 15368). Add `ci-<lane>` contexts to the asset's list per repository.
- Strict required status checks (branch must be up to date with the default branch): GitHub, not the agent, blocks a merge when the default branch has advanced since CI ran; updating the branch re-runs CI.
- Block force pushes and deletion.
- Allowed merge methods: squash only.

## Non-required workflows

Deep tests, fuzzing, security scans, cross-platform builds, and release publication keep their own workflows and names. They may use `schedule`, `push: tags`, or `workflow_dispatch`. They may not use `pull_request` or `pull_request_target`, and they are never required checks. Every job in them still sets `timeout-minutes` and pins actions.

## Runners

For a private repository, prefer a self-hosted runner label when one exists; otherwise `ubuntu-latest`. Route by job (`ci-<lane>` with its own `runs-on`), never by matrix inside a required job.

## Review-tool agnosticism

GitHub carries no review-tool state. There are no labels, inputs, statuses, comments, environments, or conditions that mention RAS or its verdicts. Draft status is the only signal and means "not ready for CI", nothing more.

## Agent convention

The shared [review loop](../../_shared/REVIEW-LOOP.md#exact-head-local-certification-and-hosted-ci) owns the sequence: open the PR as a draft; review and certify locally; `gh pr ready`; wait for every required `ci-*` check to succeed on the live head; `gh pr merge --squash --match-head-commit <head>`.

## What the standard forbids

Dispatch inputs such as `expected_sha`/`base_sha`, commit-status bridges, certification labels, `ready_for_review` used as a certification trigger, multi-job aggregates with `needs`, workflow-level change classification or path filters on the required workflow, and any encoding of out-of-band review state in GitHub. Do not reintroduce them under other names.
````

- [ ] **Step 4: Run to verify it passes**

Run: `bash standardize-github-ci/scripts/test-skill.sh`
Expected: `skill fixtures passed`

- [ ] **Step 5: Commit**

```bash
git status --short --branch
git add standardize-github-ci/references/ci-policy.md standardize-github-ci/scripts/test-skill.sh
git commit -m "standardize-github-ci: replace CI policy with the draft-gated pull_request standard"
```

---

### Task 7: Rewrite `references/migration.md`

**Files:**
- Rewrite: `standardize-github-ci/references/migration.md`
- Modify: `standardize-github-ci/scripts/test-skill.sh` (append under `# --- docs`)

- [ ] **Step 1: Append failing doc assertions**

```bash
migration="$skill_root/references/migration.md"
rg -Fq 'gh pr ready' "$migration" || fail 'migration.md: must describe marking the PR ready'
rg -Fq 'gh pr merge --squash --match-head-commit' "$migration" || fail 'migration.md: must describe the exact-head squash merge'
rg -Fq 'assets/ruleset.json' "$migration" || fail 'migration.md: must apply the ruleset asset'
rg -Fq 'gh pr create --draft' "$migration" || fail 'migration.md: must open the migration PR as a draft'
if rg -qi 'expected_sha|ci:certify|ci-certify|status bridge' "$migration"; then
  fail 'migration.md: must not describe dispatch/label certification'
fi
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash standardize-github-ci/scripts/test-skill.sh`
Expected: `error: migration.md: must describe marking the PR ready`

- [ ] **Step 3: Write `standardize-github-ci/references/migration.md`**

````markdown
# CI Migration Checklist

Migrate one repository at a time to the [portfolio CI standard](ci-policy.md). Every step below is either read-only, a change on the migration branch, or an explicitly authorized external mutation.

## 1. Inventory (read-only)

1. Run `scripts/audit-ci.sh <repo>` and, when `gh` can read the repository, `CI_AUDIT_RULESET=live scripts/audit-ci.sh <repo>`. Keep the deviation list; it is the work list.
2. List every workflow and every job's Taskfile target(s). For each lane decide: merge-blocking today → `ci-required` (fold into `task check`) or its own `ci-<lane>` job; not merge-blocking → a non-required workflow on `schedule`, `push: tags`, or `workflow_dispatch`.
3. Record the current required check names and whether the default branch uses a ruleset or legacy branch protection (`gh api repos/<o>/<r>/rules/branches/<default>`, `gh api repos/<o>/<r>/branches/<default>/protection`).
4. Record which jobs run on self-hosted labels; those labels move to `runs-on` of the corresponding `ci-*` job.

## 2. Plan (no edits)

Produce, per repository: the mapping from old jobs to `ci-required` / `ci-<lane>` / non-required workflows; the `runs-on` per job; the `task check` and `task docs-check` bodies (existing lanes renamed, not rewritten); any `CI_DOCS_GLOBS` extension; the ruleset diff including any `ci-<lane>` contexts to add; and the bootstrap note below.

## 3. Apply (on a feature branch, after approval)

1. Copy `assets/ci.yml` to `.github/workflows/ci.yml`; set `runs-on`; add `ci-<lane>` jobs by duplicating `ci-required` and changing only the job name, `runs-on`, `timeout-minutes`, and the `task ci-<lane>` step.
2. Copy `assets/ci-classify.sh` to `scripts/ci-classify.sh` unchanged and make it executable.
3. Merge `assets/Taskfile.ci.yml` into `Taskfile.yml`: add `ci`, `docs-check`, `check`, and one `ci-<lane>` per extra job; point `check` and `docs-check` at the repository's existing commands.
4. Remove `pull_request` and `pull_request_target` from every other workflow; delete workflows that only existed to certify PRs (dispatch/label/status-bridge workflows). Keep deep, security, fuzz, cross-platform, and release workflows on their non-PR triggers, pinned and with timeouts.
5. Run `task ci` locally on the branch (expect the docs-only or full path as appropriate) and `scripts/audit-ci.sh .` (expect `- None. Repository conforms to the standard.` apart from `RULES-*`, which is checked live).
6. Commit. Do not open the PR yet.

## 4. Bootstrap warning

Opening the migration PR while the old default-branch workflow still owns `pull_request` may start one last automatic run of the old workflow. Tell the operator before pushing and obtain an OK either to let it finish or to cancel it. Never silently spend or cancel Actions minutes.

## 5. Open the migration PR as a draft

```sh
git push -u origin <branch>
gh pr create --draft --title "ci: adopt portfolio CI standard" --body "<summary of the mapping>"
```

While the PR is a draft, no `ci.yml` job runs on it (the new workflow file is on the branch, but the guard skips drafts; the old default-branch workflow may still run, see §4).

## 6. Apply the ruleset (external mutation, needs explicit authorization)

1. Edit a copy of `assets/ruleset.json` to list every `ci-*` job as a required check.
2. Create it: `gh api --method POST repos/<o>/<r>/rulesets --input <copy>.json`. If a ruleset for the default branch already exists, `gh api repos/<o>/<r>/rulesets` to find its id and `--method PUT repos/<o>/<r>/rulesets/<id>` instead.
3. Remove legacy branch protection when present: `gh api --method DELETE repos/<o>/<r>/branches/<default>/protection`.
4. Re-run `CI_AUDIT_RULESET=live scripts/audit-ci.sh .` and expect no `RULES-*` deviations.

Until the migration PR merges, the *old* required check names may still be referenced by open PRs; that is expected and resolves as they update.

## 7. Verify on the migration PR (this is the live test of GitHub behavior)

1. Draft: `gh pr view --json mergeable,mergeStateStatus` shows the PR is not mergeable while draft, and `gh run list --workflow ci.yml --branch <branch>` shows no run from the new workflow.
2. `gh pr ready`. Expect a `ci` run whose head SHA equals `gh pr view --json headRefOid`. Expect every `ci-*` check to appear in `gh pr checks`.
3. Push a docs-only commit (for example a line in `DEV-JOURNAL.md` or `docs/`). Expect the run's `ci-required` log to show `task docs-check` ran and no `task check`.
4. Push a source commit. Expect `task check` to run.
5. If possible, land an unrelated change on the default branch and confirm `gh pr view --json mergeStateStatus` becomes `BEHIND` and the merge button is blocked until `gh pr update-branch` (or a rebase) re-runs CI.
6. Confirm the merge is blocked while any `ci-*` check is pending or failed.

Record head SHAs, run ids, and check names for each observation in the PR description.

## 8. Merge

`gh pr merge --squash --match-head-commit <live-head-sha>`. Then run the repository's usual post-merge steps (journal, tracking).

## Rollback

Restore the previous workflow files and required-check names from the pre-migration commit; rulesets can be updated with `--method PUT` to the previous check list. Never weaken or remove the required check merely to unblock a merge.
````

- [ ] **Step 4: Run to verify it passes**

Run: `bash standardize-github-ci/scripts/test-skill.sh`
Expected: `skill fixtures passed`

- [ ] **Step 5: Commit**

```bash
git status --short --branch
git add standardize-github-ci/references/migration.md standardize-github-ci/scripts/test-skill.sh
git commit -m "standardize-github-ci: replace migration guide with the per-repository checklist"
```

---

### Task 8: Rewrite `SKILL.md` and `agents/openai.yaml`

**Files:**
- Rewrite: `standardize-github-ci/SKILL.md`
- Modify: `standardize-github-ci/agents/openai.yaml`
- Modify: `standardize-github-ci/scripts/test-skill.sh` (append under `# --- docs`)

- [ ] **Step 1: Append failing doc assertions**

```bash
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
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash standardize-github-ci/scripts/test-skill.sh`
Expected: `error: SKILL.md: must not describe dispatch/label certification`

- [ ] **Step 3: Write `standardize-github-ci/SKILL.md`**

````markdown
---
name: standardize-github-ci
description: Bring one repository onto the portfolio CI standard — a draft-gated pull_request workflow with independent ci-* required jobs that each run one Taskfile target, a docs-only shortcut inside task ci, and one squash-only default-branch ruleset — through read-only audit, approval-gated planning and implementation, and verification. Use for CI audits, workflow or Taskfile refactors, ruleset standardization, or when PR merging behaves differently across repositories.
---

# Standardize GitHub CI

Converge one repository at a time onto the standard in [references/ci-policy.md](references/ci-policy.md). The standard is a fixed shape, not a menu: identical `ci.yml`, identical ruleset, repository-owned Taskfile bodies. Do not adapt the shape to repository evidence; adapt the repository to the shape and record any genuinely impossible case as a documented exception for the operator to decide.

## Trust and review boundary

GitHub carries no review-tool state. The agent opens PRs as drafts, reviews out of band, marks the PR ready when local certification passes, waits for the required `ci-*` checks on the live head, and merges that head with a squash. Draft status is the only signal and means "not ready for CI".

## Choose the mode

Infer the narrowest authorized mode. Default to `audit` when the request is ambiguous.

- `audit`: run the conformance audit and report deviations; no edits.
- `plan`: produce the per-repository mapping and checklist from [references/migration.md](references/migration.md); no edits.
- `apply`: implement an approved plan on a feature branch or worktree and validate it.
- `verify`: re-run the audit (including live rules) against a migrated repository and confirm the live-PR observations were recorded; do not expand into unrelated fixes.

Never treat an audit or plan request as authorization to edit files, change GitHub settings, open a PR, push, cancel or rerun workflows.

## Load policy and instructions

1. Read repository `AGENTS.md` / `CLAUDE.md` files that govern the target paths.
2. Read [references/ci-policy.md](references/ci-policy.md) completely in every mode.
3. Read [references/migration.md](references/migration.md) completely in `plan`, `apply`, and `verify` modes.
4. Read the shared [review-loop](../_shared/REVIEW-LOOP.md) baseline in `apply` and `verify` modes; the migration PR goes through it like any other PR.
5. Run `scripts/audit-ci.sh <repository-path>` (add `CI_AUDIT_RULESET=live` when `gh` can read the repository). Treat the deviation list as the work list.
6. Treat the current GitHub default branch as authoritative when the checkout may be stale; use read-only `gh` queries rather than fetching into or modifying a user worktree.

## Audit

Report the audit output plus:

- every workflow's current triggers and which lanes it runs, and the proposed destination of each lane (`ci-required`, `ci-<lane>`, or a non-required workflow);
- self-hosted runner labels in use;
- the current required check names and whether enforcement is a ruleset or legacy protection;
- anything the standard cannot express for this repository, stated as an exception with evidence.

Do not present self-hosted work as billed minutes. Include "no change needed" findings.

## Plan

Follow §1–§2 of [references/migration.md](references/migration.md). The plan lists the file-level changes, the `runs-on` per job, the Taskfile bodies (existing commands renamed into `check` / `docs-check`, not rewritten), the ruleset diff, the bootstrap warning, and the verification observations that will be recorded on the migration PR.

## Apply

Proceed only when the user explicitly asks to implement or has approved the plan. Follow §3–§8 of [references/migration.md](references/migration.md) in order. In particular:

- work in an isolated worktree and feature branch;
- copy assets verbatim ([assets/ci.yml](assets/ci.yml), [assets/ci-classify.sh](assets/ci-classify.sh), [assets/Taskfile.ci.yml](assets/Taskfile.ci.yml), [assets/ruleset.json](assets/ruleset.json)); do not hand-edit the workflow beyond `runs-on` and `ci-<lane>` jobs;
- keep the diff scoped to CI standardization;
- obtain explicit authorization before every external mutation (ruleset create/update, legacy protection removal, cancelling or rerunning a workflow, opening the PR);
- open the migration PR as a draft and warn about the bootstrap run first.

## Validate

1. `scripts/audit-ci.sh .` on the branch reports no deviations other than `RULES-*` before the ruleset is applied, and none after.
2. `actionlint .github/workflows/ci.yml` passes; every edited YAML parses.
3. `task ci` runs locally on a docs-only diff and on a source diff and takes the expected path.
4. The live-PR observations in migration §7 are performed and recorded in the PR description.
5. Run the migration PR through the shared review loop before marking it ready.

Do not claim minutes are saved merely because YAML parses; state which jobs no longer start on which events.

## Deliver

State: mode completed; files or settings changed; validation performed and unavailable validation; expected runner-minute effect (draft phase runs nothing; docs-only PRs run `docs-check` only); required operator follow-up; remaining exceptions.
````

- [ ] **Step 4: Update `standardize-github-ci/agents/openai.yaml`**

```yaml
interface:
  display_name: "Standardize GitHub CI"
  short_description: "Audit and apply the draft-gated pull_request CI standard"
  default_prompt: "Use $standardize-github-ci to audit this repository against the portfolio CI standard and, with approval, migrate it to the draft-gated pull_request workflow, Taskfile ci contract, and squash-only ruleset."
```

- [ ] **Step 5: Run to verify it passes**

Run: `bash standardize-github-ci/scripts/test-skill.sh`
Expected: `skill fixtures passed`

- [ ] **Step 6: Commit**

```bash
git status --short --branch
git add standardize-github-ci/SKILL.md standardize-github-ci/agents/openai.yaml standardize-github-ci/scripts/test-skill.sh
git commit -m "standardize-github-ci: rewrite skill entry around the fixed CI standard"
```

---

### Task 9: Update `_shared/REVIEW-LOOP.md` to the draft→ready convention

**Files:**
- Modify: `_shared/REVIEW-LOOP.md` (Structure list, step 5, section "Exact-head local certification and hosted CI")

- [ ] **Step 1: Write the failing check**

Run:

```bash
cd /Volumes/worktrees/skills/simplify-ci-standard
rg -n 'ci:certify|workflow_dispatch|status rollup' _shared/REVIEW-LOOP.md && echo STALE || echo CLEAN
rg -Fq 'gh pr ready' _shared/REVIEW-LOOP.md && echo HAS-READY || echo NO-READY
```

Expected: `STALE` and `NO-READY`.

- [ ] **Step 2: Edit the Structure list**

Replace:

```
- Do the work in a branch, divided into multiple PRs if needed, using TDD where appropriate.
```

with:

```
- Do the work in a branch, divided into multiple PRs if needed, using TDD where appropriate. Open every PR as a draft (`gh pr create --draft`); the required CI workflow skips drafts, so no hosted CI runs during the review loop.
```

- [ ] **Step 3: Replace step 5**

Replace:

```
5. Request required hosted CI for that same head through the portfolio's PR-associated `ci:certify` trigger, then verify the resulting `pull_request`/`labeled` run binds the certified PR head and produces the protected `ci-required` result in the live PR status rollup. Do not substitute a successful `workflow_dispatch` run for this merge gate.
6. Merge that exact head.
```

with:

```
5. Mark the PR ready (`gh pr ready`) so the required `ci-*` checks run on that same head, then wait for every required check to succeed on the live head.
6. Merge that exact head with `gh pr merge --squash --match-head-commit <head>`.
```

- [ ] **Step 4: Replace the hosted-CI paragraphs**

Replace the two paragraphs beginning `Request hosted CI only when local certification passes` and `Do not use a successful \`workflow_dispatch\` run as merge-gating evidence` with:

```
Mark the PR ready only when local certification passes and its head is still the live PR head. Under the portfolio CI standard the required workflow runs on `pull_request` and skips drafts, so `gh pr ready` is the request for hosted CI: it starts the required `ci-*` jobs on the exact live head. Wait for every required check to succeed on that head (`gh pr checks --watch`), confirm the head has not moved (`gh pr view --json headRefOid`), and merge with `gh pr merge --squash --match-head-commit <head>`. A push after ready re-runs CI on the new head; that is expected, and the new head needs its own green checks and, if code changed, its own review round. If the default branch advances, GitHub blocks the merge until the branch is updated, which re-runs CI. Hosted CI remains authoritative for clean-runner, operating-system, architecture, secret, and service boundaries that local execution cannot reproduce.
```

- [ ] **Step 5: Verify**

Run:

```bash
rg -n 'ci:certify|workflow_dispatch|status rollup|labeled' _shared/REVIEW-LOOP.md && echo STALE || echo CLEAN
rg -Fq 'gh pr ready' _shared/REVIEW-LOOP.md && echo HAS-READY
git diff --stat
```

Expected: `CLEAN`, `HAS-READY`, only `_shared/REVIEW-LOOP.md` changed, and the diff touches only the four edited spots (no rewrapping elsewhere).

- [ ] **Step 6: Commit**

```bash
git status --short --branch
git add _shared/REVIEW-LOOP.md
git commit -m "REVIEW-LOOP: request hosted CI by marking the draft PR ready"
```

---

### Task 10: Update consumers (`loop-review-merge`, `implement-architecture-slice`, `planit`) and check links

**Files:**
- Modify: `loop-review-merge/SKILL.md:14`
- Modify: `implement-architecture-slice/SKILL.md:93`
- Modify: `planit/SKILL.md:30`

- [ ] **Step 1: Failing check**

Run: `rg -n 'PR-associated trigger|Request the required hosted CI' loop-review-merge/SKILL.md implement-architecture-slice/SKILL.md planit/SKILL.md`
Expected: two matches (implement-architecture-slice:93, planit:30).

- [ ] **Step 2: Edit `loop-review-merge/SKILL.md`**

Replace:

```
3. Run the composed exact-head local-certification and hosted-CI phase.
4. Merge that exact head using the repository-required strategy. If GitHub reports `mergeable: UNKNOWN` right after a push, poll until `MERGEABLE` before merging.
```

with:

```
3. Run the composed exact-head local-certification phase, then mark the draft PR ready and wait for every required `ci-*` check on the live head, per the shared [hosted-CI convention](../_shared/REVIEW-LOOP.md#exact-head-local-certification-and-hosted-ci).
4. Merge that exact head with `gh pr merge --squash --match-head-commit <head>`. If GitHub reports `mergeable: UNKNOWN` right after a push, poll until `MERGEABLE` before merging.
```

- [ ] **Step 3: Edit `implement-architecture-slice/SKILL.md` line 93**

Replace the sentence:

```
Request hosted CI only for that certified head through the shared protocol's PR-associated trigger, verify the live PR head and required result still match, and merge that exact head.
```

with:

```
Mark the draft PR ready only for that certified head, wait for every required `ci-*` check to succeed on the live head, and squash-merge that exact head with `--match-head-commit`.
```

- [ ] **Step 4: Edit `planit/SKILL.md` line 30**

Replace the leading clause:

```
4. Request the required hosted CI for that same head, verify the run head and live PR head still match, and confirm the required result before merge.
```

with:

```
4. Mark the draft PR ready so the required `ci-*` checks run on that same head, verify the live PR head has not moved, and confirm every required check succeeded before merge.
```

Leave the rest of the sentence (diagnose failed CI, etc.) unchanged.

- [ ] **Step 5: Verify links and stale terms across the repo**

Run:

```bash
cd /Volumes/worktrees/skills/simplify-ci-standard
rg -n 'ci:certify|ci-certify|expected_sha|status bridge|PR-associated' --glob '!docs/**' --glob '!.git/**' . && echo STALE || echo CLEAN
# every relative markdown link in touched skills resolves
for f in _shared/REVIEW-LOOP.md loop-review-merge/SKILL.md implement-architecture-slice/SKILL.md planit/SKILL.md standardize-github-ci/SKILL.md standardize-github-ci/references/ci-policy.md standardize-github-ci/references/migration.md; do
  dir="$(dirname "$f")"
  rg -o '\]\((\.{1,2}/[^)#]+|[A-Za-z0-9_./-]+\.(md|yml|sh|json))(#[^)]*)?\)' "$f" | sed -E 's/^\]\(//; s/\)$//; s/#.*$//' | while read -r link; do
    test -e "$dir/$link" || echo "BROKEN $f -> $link"
  done
done
# anchors used against REVIEW-LOOP.md exist
rg -o 'REVIEW-LOOP.md#[a-z-]+' -N . --glob '!.git/**' | sort -u | sed 's/.*#//' | while read -r a; do
  rg -qi "^## .*$(echo "$a" | tr '-' ' ')" _shared/REVIEW-LOOP.md || echo "MISSING ANCHOR $a"
done
```

Expected: `CLEAN`, no `BROKEN`, no `MISSING ANCHOR`. (`docs/DEV-JOURNAL.md` and the spec/plan are excluded on purpose; historical text may keep old terms.)

- [ ] **Step 6: Commit**

```bash
git status --short --branch
git add loop-review-merge/SKILL.md implement-architecture-slice/SKILL.md planit/SKILL.md
git commit -m "Point merge-driving skills at the draft-ready hosted-CI convention"
```

---

### Task 11: Dry-run audit against a real repository and final validation

**Files:** none modified (read-only validation).

- [ ] **Step 1: Clone a real un-migrated repository into the scratchpad (read-only)**

```bash
scratch=/private/tmp/claude-501/-Users-josh-code-github-com-the-sarge-skills/3122f645-c6ed-4908-9a60-fbe1db7b93e9/scratchpad
gh repo clone GridSwarm/codemux "$scratch/codemux" -- --depth 1 -q
```

- [ ] **Step 2: Run the audit two ways**

```bash
cd /Volumes/worktrees/skills/simplify-ci-standard
bash standardize-github-ci/scripts/audit-ci.sh "$scratch/codemux"; echo "exit=$?"
CI_AUDIT_RULESET=live bash standardize-github-ci/scripts/audit-ci.sh "$scratch/codemux"; echo "exit=$?"
```

Expected: exit 3 both times; the deviation list names, at minimum, `CI-TRIGGER` (or `CI-MISSING`), `CI-GUARD`, `TASK-CI-MISSING`, `CLASSIFY-MISSING`, and with live rules `RULES-SQUASH` and `RULES-STRICT` (codemux allows all merge methods, strict is off) plus `RULES-LEGACY`. Read the report as a human would: every line should tell the migrator exactly what to change. Fix wording in `audit-ci.sh` if a message is unclear, then re-run `test-skill.sh`.

- [ ] **Step 3: Full validation**

```bash
bash standardize-github-ci/scripts/test-skill.sh
shellcheck standardize-github-ci/scripts/*.sh standardize-github-ci/assets/*.sh
actionlint standardize-github-ci/assets/ci.yml
yq eval '.' standardize-github-ci/assets/Taskfile.ci.yml >/dev/null
jq . standardize-github-ci/assets/ruleset.json >/dev/null
git status --short --branch
```

Expected: `skill fixtures passed`, no shellcheck/actionlint output, clean tree except any wording commit from Step 2.

- [ ] **Step 4: Commit any wording fixes**

```bash
git add -A standardize-github-ci && git commit -m "standardize-github-ci: clarify audit deviation messages" || echo "nothing to commit"
```

---

### Task 12: Tracking issues

**Files:** none (GitHub issues only). Approved in the design's Rollout section.

- [ ] **Step 1: Open the superseding issue**

```bash
gh issue create --repo the-sarge/skills \
  --title "Simplify standardize-github-ci to one draft-gated pull_request CI standard" \
  --label ready-for-agent \
  --body-file - <<'EOF'
Supersedes #7.

Replace the dispatch / label / commit-status-bridge certification families with one standard: a `pull_request`-triggered `ci.yml` (types opened, synchronize, reopened, ready_for_review) that skips drafts and fork heads; 1..N independent required jobs named `ci-required` / `ci-<lane>` with no `needs`; docs-only handled inside `task ci` via a shipped `scripts/ci-classify.sh`; one squash-only default-branch ruleset with strict up-to-date; non-required workflows off `pull_request`. The shared review loop requests hosted CI by marking the draft PR ready.

Design: `docs/superpowers/specs/2026-08-18-simplify-ci-standard-design.md`. Plan: `docs/superpowers/plans/2026-08-18-simplify-ci-standard.md`.

Scope: this repository only (skill, assets, audit, tests, shared review-loop docs). Repository migrations follow as separate `standardize-github-ci` runs: codemux, tapmux, wiremux, gridcast, wellspring.
EOF
```

Record the new issue number as `NEW`.

- [ ] **Step 2: Close #7 as superseded**

```bash
gh issue close 7 --repo the-sarge/skills --reason "not planned" --comment "Superseded by #NEW. Rather than reconcile the dispatch/status-bridge, one-shot label, and ready_for_review families, the portfolio moves to a single pull_request-triggered, draft-gated standard. Every acceptance criterion here is satisfied trivially by that design: there is no dispatch to credit, no label to consume, no rollup attribution to prove, and GitHub carries no review-tool state. Design and plan are linked from #NEW."
```

- [ ] **Step 3: Verify**

Run: `gh issue view 7 --repo the-sarge/skills --json state,comments --jq '{state, last: .comments[-1].body[0:80]}'`
Expected: `CLOSED` with the superseded comment.

---

## Self-review

**Spec coverage.** Required workflow → Task 1; classifier and Taskfile contract → Tasks 2–3; ruleset → Task 3 (asset) and Task 5 (audit); required-jobs rule incl. `ci-<lane>`, no `needs`, no matrix → Tasks 1, 4; non-required workflows off `pull_request` → Task 5; runner guidance and review-tool agnosticism → Task 6; agent convention → Task 9; skill rewrite (SKILL.md, policy, migration, assets, audit, tests, openai.yaml) → Tasks 1–8; consumers → Task 10; testing section (actionlint, shellcheck, fixtures, real-repo dry run, link check) → Tasks 1–5, 10, 11; rollout / issue #7 → Task 12. `loop-review/SKILL.md` needs no change (verified: it does not mention triggers).

**Placeholder scan.** `NEW` in Task 12 is a value the executor records at run time, not a placeholder; `<pinned-sha>` appears only in the spec, the plan carries real SHAs. No TBD/TODO.

**Consistency.** Deviation codes used in tests (Tasks 4–5) match those emitted by the audit; asset paths (`assets/ci.yml`, `assets/ci-classify.sh`, `assets/Taskfile.ci.yml`, `assets/ruleset.json`) are the same in SKILL.md, ci-policy.md, migration.md, and test-skill.sh; the classifier's env names (`CI_BASE_SHA`, `CI_HEAD_SHA`, `CI_DEFAULT_BRANCH`, `CI_REMOTE`, `CI_DOCS_GLOBS`) match between script, tests, and Taskfile snippet; the audit exit codes (0/3/2) match between script header and tests.
