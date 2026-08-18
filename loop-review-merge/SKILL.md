---
name: loop-review-merge
description: Drive a PR to merge through a controlled, agent-in-the-loop review cycle. Use when the user asks to review a PR until merged. Runs each PR through a manual `ras review`/`ras verify` loop (the agent does the fixing — never the auto-fixer) before merge.
---

# loop-review-merge

Drive a PR to merge through a review loop where **you** do the fixing and judging and RAS is used **only** to review and verify.

## Workflow

1. Read the repository's review protocol when present and compose its stronger repository-specific rules with the shared [review-loop baseline](../_shared/REVIEW-LOOP.md).
2. Require the accepted contract to satisfy the shared [review briefing](../_shared/REVIEW-LOOP.md#review-briefing), then execute the [bounded review algorithm](../_shared/REVIEW-LOOP.md#bounded-review-algorithm).
3. Run the composed exact-head local-certification phase, then mark the draft PR ready and wait for every required `ci-*` check on the live head (a post-ready `ci` run with conclusion `success`; a draft-phase `skipped` check is not evidence), per the shared [hosted-CI convention](../_shared/REVIEW-LOOP.md#exact-head-local-certification-and-hosted-ci).
4. Merge that exact head with `gh pr merge --squash --match-head-commit <head>`. If GitHub reports `mergeable: UNKNOWN` right after a push, poll until `MERGEABLE` before merging.

When the protocol produces `stop-for-decision`, preserve the branch, record all dispositions and the review and verification history plus the precise invariant-and-owner root, and report the required design decision to the user. A `defer` or `reject` finding does not enter this branch. This merge skill does not silently widen or redesign the PR.

Apply shared [contract closure](../_shared/CONTRACT-CLOSURE.md) only after the baseline assigns `fix-now`; apply the shared [approach stops](../_shared/REVIEW-LOOP.md#approach-stops) throughout.

The skill is complete when the reviewed, locally certified, and hosted-verified head is merged.
