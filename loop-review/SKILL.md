---
name: loop-review
description: Get a PR ready for merge in a controlled, agent-in-the-loop review cycle. Runs each PR through a manual `ras review`/`ras verify` loop (the agent does the fixing — never the auto-fixer) before merge.
---

# loop-review

Get a PR ready for merge through a review loop where **you** do the fixing and judging and RAS is used **only** to review and verify.

## Workflow

Read the repository's review protocol when present and compose its stronger repository-specific rules with the shared [review-loop baseline](../_shared/REVIEW-LOOP.md). Require the accepted contract to satisfy the shared [review briefing](../_shared/REVIEW-LOOP.md#review-briefing), then execute the [bounded review algorithm](../_shared/REVIEW-LOOP.md#bounded-review-algorithm).

When the protocol produces `stop-for-decision`, preserve the branch, record all dispositions and the review and verification history plus the precise invariant-and-owner root, and report the required design decision to the user. A `defer` or `reject` finding does not enter this branch. This review-only skill does not silently widen or redesign the PR.

Apply shared [contract closure](../_shared/CONTRACT-CLOSURE.md) only after the baseline assigns `fix-now`; apply the shared [approach stops](../_shared/REVIEW-LOOP.md#approach-stops) throughout.

The skill is complete when the shared bounded review completion criterion is met. Leave certification, merge, journal, and tracking to the invoking workflow.
