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

Dispatch inputs carrying head or base SHAs, commit statuses published to bridge a dispatched run into the ruleset, certification labels, `ready_for_review` used as a certification trigger, multi-job aggregates with `needs`, workflow-level change classification or path filters on the required workflow, and any encoding of out-of-band review state in GitHub. Do not reintroduce them under other names.
