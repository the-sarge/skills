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

One CI shape for every repository: a `pull_request`-triggered workflow that skips draft PRs, one or more individually required jobs that each run one Taskfile target, and one identical default-branch ruleset. The shape is identical across repositories so that any workflow, ruleset, or merge problem is the same problem everywhere. Cost control comes from drafts (no CI during review) and from a docs-only shortcut inside `task ci`, not from orchestration cleverness in YAML.

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

Why drafts are safe, and what they are not: the job-level `if` skips the job on draft PRs, but GitHub still publishes a `ci-required` check run with conclusion `skipped` and counts `skipped` as passing for required checks. That is harmless while the PR is a draft, because GitHub refuses to merge drafts regardless of checks. The moment the PR is marked ready, the run started by marking it ready executes on the live head and its check run supersedes the skipped one; every later push starts another. The agent convention therefore never treats a `skipped` conclusion as evidence: it merges only after the latest `ci` workflow run started after the PR was marked ready (or by a later push) on the exact live head has completed with conclusion `success` and every `ci-*` job in that run reports `success` — see [Agent convention](#agent-convention).

## Required jobs

The workflow contains one or more required jobs, each a required check in its own right:

- `ci-required` (always present) runs `task ci`.
- `ci-<lane>` (optional, e.g. `ci-race`) runs `task ci-<lane>`. Use one when a lane must block merging *and* needs its own runner or timeout. Each `ci-<lane>` job repeats the guard, timeout, and pinned setup steps, sets its own `runs-on`, and appears in the ruleset's required checks.
- A job may add a job-level `env:` mapping repository secrets or variables the Taskfile target consumes (for example a private-module token), and a `ci-<lane>` job may declare `services:` or `container:` when the lane needs them; the Taskfile still owns what runs. Apart from the cross-runner exchange below, nothing else varies.
- No job uses `strategy.matrix`, and no job aggregates or summarizes other jobs (no step or expression reads `needs.<job>.result`). Every `ci-*` job is individually required, so the merge is blocked unless each one reports a real success: a missing check blocks, a failed origin blocks through its own red check, and a downstream job skipped after an origin failure is harmless because the origin already blocks. That is the fail-closed guarantee, and it needs no aggregation script.
- `needs:` is permitted only for a **cross-runner artifact exchange**: a destination `ci-<lane>` job (never `ci-required`) that must consume an artifact produced on a different runner in the same run (for example, bundles created natively on Linux, macOS, and Windows, each verified on every other OS). Conditions: every `needs` target is a `ci-*` job in the same `ci.yml` (so it is itself a required check and a failed upstream blocks the merge through its own check, not through a skipped downstream); the downstream job keeps the standard guard and calls no status function at all — `always()`, `failure()`, or `cancelled()` would run it after an upstream failure, and `!success()` or `success() == false` would skip it after a green upstream, where a skipped required check counts as passing; artifacts move with SHA-pinned `actions/upload-artifact` / `actions/download-artifact` steps inside the run (the job still has exactly one `task` run step); no job in the graph uses the `needs` context in any expression for anything other than an outputs access (`needs.<job>.outputs.<name>` and bracket equivalents are fine; `.result`, `.conclusion`, `needs.*`, `toJSON(needs)`, and any other use are aggregation and are rejected); and the job graph is recorded in the repository's migration notes. Write each OS job out explicitly rather than using a matrix so check names stay stable. Committing representative fixtures is a backward-compatibility test, not a substitute for the same-run exchange, and belongs in a non-required workflow.

Choice rule: a lane that is merge-blocking today becomes a `ci-<lane>` job; a lane that is not merge-blocking moves to a [non-required workflow](#non-required-workflows).

## Taskfile contract

Copy [`assets/Taskfile.ci.yml`](../assets/Taskfile.ci.yml) into the repository `Taskfile.yml` and [`assets/ci-classify.sh`](../assets/ci-classify.sh) to `scripts/ci-classify.sh` unchanged.

- `ci`: runs `scripts/ci-classify.sh`; on `docs_only=true` runs `docs-check`, otherwise runs `check`. Empty diffs, an unknown base, and unknown file types classify as not docs-only.
- `docs-check`: repository-owned documentation checks.
- `check`: repository-owned ordinary merge gate (format, vet, lint, unit tests, build smoke).
- `ci-<lane>`: runs the classifier, exits successfully with a message on docs-only changes, otherwise runs the lane.
- `release-gate` (when the repository publishes releases): the validation a tag-push release workflow runs before publishing; repository-owned, typically `check` plus the deep checks the PR gate deliberately skips.
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

Deep tests, fuzzing, security scans, cross-platform builds, and release publication keep their own workflows and names. They may use `schedule`, `push: tags`, or `workflow_dispatch`. They may not use `pull_request` or `pull_request_target`, and they are never required checks. Every job in them still sets `timeout-minutes` and pins actions (a job that only calls a reusable workflow via `uses:` cannot carry `timeout-minutes`; the called workflow's jobs own theirs). They call purpose-named Taskfile targets, never `task ci` or `task ci-<lane>`. The names are fixed where it matters: every tag-push release workflow runs `task release-gate` (repository-owned; recommended `check` + deep checks such as race, vulnerability scan, and SAST, with bounded fuzzing left to the nightly when it is slow or flaky) before publishing, and the audit reports `WF-RELEASE-GATE` / `TASK-RELEASE-GATE-MISSING` when it does not; scheduled workflows should use `nightly` (or a descriptive name when a repository has several). Never `task ci`: those are the PR merge gate — deliberately the fast path, classified against a PR merge base that does not exist on a tag or schedule — so a release workflow that calls `task ci` validates less than it appears to.

## Runners

For a private repository, prefer a self-hosted runner label when one exists; otherwise `ubuntu-latest`. Route by job (`ci-<lane>` with its own `runs-on`), never by matrix inside a required job. `actions/setup-go@v7` and `arduino/setup-task@v3` are Node 24 actions; a self-hosted runner image must be recent enough to run Node 24 or the setup steps fail before `task ci` starts.

## Review-tool agnosticism

GitHub carries no review-tool state. There are no labels, inputs, statuses, comments, environments, or conditions that mention RAS or its verdicts. Draft status is the only signal and means "not ready for CI", nothing more.

## Agent convention

The shared [review loop](../../_shared/REVIEW-LOOP.md#exact-head-local-certification-and-hosted-ci) owns the sequence: open the PR as a draft; review and certify locally; `gh pr ready`; wait for the post-ready run described below; `gh pr merge --squash --match-head-commit <head>`.

A workflow run's `event` field is the trigger name, not the activity type, so both the draft-phase run and the post-ready run report `event: pull_request`; `ready_for_review` and `synchronize` appear only in the payload. Identify the post-ready run as the latest `ci` run on the live head created after `gh pr ready` (`gh run list --workflow ci.yml --commit <head> --json databaseId,createdAt,status,conclusion`), and require that in that run every `ci-*` job reports `success` — not `skipped` — via `gh run view <id> --json jobs` (or `gh pr checks <n> --json name,state`). A `skipped` conclusion left over from the draft phase is never merge evidence.

## What the standard forbids

Dispatch inputs carrying head or base SHAs, commit statuses published to bridge a dispatched run into the ruleset, certification labels, `ready_for_review` used as a certification trigger, `needs:` edges outside a cross-runner artifact exchange, any use of the `needs` context other than `needs.<job>.outputs.<name>` even inside a valid exchange, workflow-level change classification or path filters on the required workflow, and any encoding of out-of-band review state in GitHub. Do not reintroduce them under other names.
