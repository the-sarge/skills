# Simplify the portfolio CI standard — design

Date: 2026-08-18
Status: draft for review
Supersedes: GitHub issue #7 (dispatch/label reconciliation)

## Problem

The portfolio's five Go repositories each certify pull requests differently: exact-head `workflow_dispatch` plus a commit-status bridge, a one-shot `ci:certify` / `ci-certify` label, `ready_for_review` as a certification event, multi-job aggregates with `needs:`, and two enforcement mechanisms (rulesets vs. legacy branch protection) with two required-check names (`ci-required` vs. `Verify`). `standardize-github-ci` was meant to converge them but is written to be evidence-driven per repository, so it produced divergence. The shared `_shared/REVIEW-LOOP.md` was hardened (commit `102340a`) to require the label family, which made repositories standardized by `standardize-github-ci` unmergeable through `loop-review-merge`.

All of that complexity exists to start CI from outside the PR (after out-of-band RAS review) and then fake the PR association GitHub only grants to `pull_request`-triggered runs. The operator wants one simple, reliable standard they can understand at a glance.

## Decision

Stop fighting GitHub. Use `pull_request` as the only certifying trigger, skip draft PRs, and let the review loop use draft→ready as the "CI may run now" signal. Move all "how much to check" logic into the Taskfile where it runs identically locally and in CI. Enforce merges with one identical ruleset per repository.

Constraints confirmed with the operator:

- All repositories are private and Go/Taskfile-based; runner minutes matter, hence a mix of GitHub-hosted and self-hosted GARM runners.
- There are no outside contributors; fork PRs never need CI.
- Docs-only PRs are frequent (`append-dev-journal` pushes journal entries through PRs) and must stay cheap.
- Some repositories route heavy race testing to an xlarge self-hosted runner while ordinary checks run on a small runner; that routing must remain possible.
- Squash-only merges are acceptable portfolio-wide.
- Scope of this design: the skills repository only. Migrating individual repositories is follow-up work performed by running the rewritten skill.

## The standard

### Required workflow

Every repository has `.github/workflows/ci.yml`. The skeleton is identical across repositories; only `runs-on` (and, where a repository has extra `ci-<lane>` jobs, those jobs) vary.

```yaml
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
    if: >-
      !github.event.pull_request.draft &&
      github.event.pull_request.head.repo.full_name == github.repository
    runs-on: ubuntu-latest # per-repo: hosted label or self-hosted GARM label
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@<pinned-sha>
        with:
          fetch-depth: 0
      - uses: actions/setup-go@<pinned-sha>
        with:
          go-version-file: go.mod
      - uses: arduino/setup-task@<pinned-sha>
      - run: task ci
```

Rules:

- Trigger is exactly `pull_request` with `types: [opened, synchronize, reopened, ready_for_review]`. No `push`, no `workflow_dispatch`, no `pull_request_target`, no `paths` filters.
- The job-level `if` skips draft PRs and PRs whose head repository is not the base repository. A skipped job on a draft PR is harmless because GitHub refuses to merge drafts; the required check therefore only ever exists as a real run on a non-draft head.
- Concurrency cancels superseded runs per PR.
- `permissions` is `contents: read` at workflow level; jobs add nothing unless a Taskfile target demonstrably needs it.
- Every job has `timeout-minutes`.
- Third-party actions are pinned to full commit SHAs.
- `fetch-depth: 0` so the Taskfile classifier can compute a merge base.

### Required jobs

The workflow contains one or more independent required jobs. Each:

- is named `ci-required` (the default job) or `ci-<lane>` (an additional merge-blocking lane, e.g. `ci-race`);
- carries the same `if` guard, timeout, and pinned setup steps;
- has its own `runs-on`, which is how per-lane runner routing works;
- runs exactly one Taskfile target (`task ci` for `ci-required`, `task ci-<lane>` for others);
- declares no `needs:` and is not aggregated by any other job.

The choice rule: a lane that is merge-blocking today becomes a standalone `ci-<lane>` job; a lane that is not merge-blocking moves to a non-required workflow. Because no job depends on another, each required check either ran and passed or is absent; absence blocks the merge. This is fail-closed without any aggregation script.

### Taskfile contract

Each repository's `Taskfile.yml` exposes:

- `ci`: runs `scripts/ci-classify.sh`; if the diff against the merge base with the default branch is docs-only, runs `docs-check`; otherwise (including empty or indeterminate diffs and unknown file types) runs `check`.
- `docs-check`: the repository's documentation checks.
- `check`: the repository's ordinary merge gate (format, vet, lint, unit tests, build smoke — repository-owned).
- `ci-<lane>` for each additional required job: applies the same classifier and exits early on docs-only diffs, otherwise runs that lane.

`scripts/ci-classify.sh` is shipped by the skill and copied into repositories unchanged. It answers only "docs-only: yes/no", fails closed, and reads a docs allowlist (default: `*.md`, `docs/**`, `DEV-JOURNAL.md`, `LICENSE*`) that a repository may extend via a Taskfile variable. It works identically on a laptop (`task ci` on a branch) and in CI.

### Ruleset

One ruleset on the default branch, identical across repositories, replacing legacy branch protection where present:

- require a pull request before merging;
- required status checks: every `ci-*` job name in `ci.yml`, sourced from the GitHub Actions integration;
- strict required status checks (branch must be up to date with the default branch) enabled — GitHub, not the agent, then blocks merging when `main` has advanced since CI ran;
- block force pushes and deletion;
- allowed merge methods: squash only.

Ruleset changes are external mutations and require explicit operator authorization in the skill's `apply` mode.

### Non-required workflows

Deep tests, fuzzing, security scans, cross-platform builds, and release publication stay in their own workflows with their existing names. They may use `schedule`, `push: tags`, or `workflow_dispatch`. They may not use `pull_request` or `pull_request_target`, and they are never required checks.

### Runner guidance

For a private repository, prefer a self-hosted runner label when one exists; otherwise `ubuntu-latest`. Route by job, never by matrix inside a required job.

### Review-tool agnosticism

GitHub carries no review-tool state. There are no labels, inputs, statuses, comments, or conditions that mention RAS or its verdicts. Draft status is the only signal, and it means "not ready for CI", nothing more.

## Agent convention (shared review loop)

1. Open every PR as a draft.
2. Run the RAS review loop and local exact-head certification as today; no hosted CI runs during this phase.
3. When local certification passes on the live head, mark the PR ready (`gh pr ready`).
4. Wait for every required `ci-*` check to succeed on the live head. A push after ready re-runs CI on the new head; that is expected. If the default branch advances, GitHub blocks the merge until the branch is updated, which re-runs CI.
5. Merge with `gh pr merge --squash --match-head-commit <head>`.
6. Journal and tracking steps are unchanged.

## Changes to this repository

### `standardize-github-ci`

- `SKILL.md`: keep the four modes and their authorization rules; rewrite the audit/plan/apply/validate/deliver bodies around the standard; update the frontmatter description (drop dispatch-gated and review-before-CI language).
- `references/ci-policy.md`: replaced by the standard above. Removed: agent-gated dispatch, status bridge, one-shot labels, event-policy table, workflow-level change classification, duplicate-work policy, threat-model paragraphs.
- `references/migration.md`: replaced by a per-repository checklist: inventory workflows and lanes → map each lane to `ci` / `ci-<lane>` / non-required workflow → write `ci.yml` from the asset → add `scripts/ci-classify.sh` and Taskfile targets → apply the ruleset with authorization and remove legacy protection → open the migration PR as a draft → verify on that PR (docs-only head, source head, main-advance block, draft un-mergeability) → mark ready → merge. Retains the bootstrap note that the old default-branch workflow may run once and that opening, cancelling, or rerunning that run needs the operator's OK.
- `assets/`: add `ci.yml`, `ci-classify.sh`, `Taskfile.ci.yml` (snippet showing `ci`, `docs-check`, `check`, `ci-<lane>`), `ruleset.json`. Delete `ci.yml.template`, `classify-ci-changes.sh`, `require-ci-results.sh`.
- `scripts/audit-ci.sh`: rewritten to report conformance to the standard: `ci.yml` trigger set, draft and same-repo guards, concurrency, permissions, timeouts, pinned actions, one Taskfile target per job, no `needs:`; non-required workflows free of `pull_request`/`pull_request_target`; Taskfile exposes `ci`; ruleset shape when `gh` access is available. Output is a short conformance table plus named deviations. All RAS/label/dispatch heuristics are deleted.
- `scripts/test-skill.sh`: forward tests for the new audit and classifier (see Testing).
- `agents/openai.yaml`: description updated to match.

### Shared protocol and consumers

- `_shared/REVIEW-LOOP.md`: Structure gains "open every PR as a draft"; step 5 and the "Exact-head local certification and hosted CI" section become the agent convention above; all `ci:certify`, `workflow_dispatch`, and rollup-crediting language is removed. Everything else is untouched.
- `loop-review-merge/SKILL.md` steps 3–4, `implement-architecture-slice/SKILL.md` line 93, `planit/SKILL.md` line 30: reworded to reference the convention instead of a "PR-associated trigger".
- `loop-review/SKILL.md`: verified unchanged.

No new standalone doc; the policy reference is the single source.

## Testing

- `scripts/test-skill.sh` is the executable suite: `audit-ci.sh` and `ci-classify.sh` run against temporary git fixtures. The conformant fixture (built from `assets/ci.yml`) produces zero deviations; each deviation the audit can emit (extra trigger, missing draft guard, missing same-repo guard, `needs:` present, unpinned action, missing timeout, `pull_request` on a non-required workflow, missing `task ci`) has a fixture that produces it. `ci-classify.sh` is exercised against real `git diff` output: docs-only, mixed, empty diff, unknown extension (last two must classify as not docs-only). Tests are written before the script behavior.
- `actionlint` and an authoritative YAML parse on `assets/ci.yml`; a fixture asserts the shipped asset itself passes the audit so template and checker cannot drift.
- Markdown: no hard-wrapping; every intra-repo link and anchor referenced from the touched skills resolves.
- One read-only dry-run audit of a real un-migrated repository to confirm the deviations read sensibly. No repository is modified.
- Not testable here and stated as such: GitHub's live behavior (draft un-mergeability, `ready_for_review` firing, strict up-to-date blocking). These are verified on each repository's migration PR via the migration checklist.

## Rollout

- Close issue #7 as superseded with a comment explaining that its acceptance criteria are satisfied trivially by the new design. Open a new issue for this work referencing #7.
- This design lands as one PR from `codex/simplify-ci-standard` (worktree `/Volumes/worktrees/skills/simplify-ci-standard`), gated by `test-skill.sh` and the repository's review loop.
- Repository migrations follow as separate `standardize-github-ci` runs, one at a time: codemux first (single job, already `pull_request`-triggered, lowest risk for proving GitHub behavior), then tapmux, wiremux, gridcast, and wellspring last (`ci-race` on the xlarge runner). A surprise on codemux fixes the standard once before the other four move.

## Out of scope

- Migrating any repository.
- Reintroducing dispatch, labels, status bridges, or workflow-level classification under any name.
- Changing what `check`, `docs-check`, or any lane actually runs inside a repository.
