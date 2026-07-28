---
name: loop-review-merge
description: Drive a PR to merge through a controlled, agent-in-the-loop review cycle. Use when the user asks to review a PR until merged. Runs each PR through a manual `ras review`/`ras verify` loop (the agent does the fixing — never the auto-fixer) before merge.
---

# loop-review-merge

Drive a PR to merge through a review loop where **you** do the fixing and judging and RAS is used **only** to review and verify.

## Workflow

1. Read the repository's review protocol when present and compose its stronger repository-specific rules with the shared [review-loop baseline](../_shared/REVIEW-LOOP.md).
2. Run the composed review phase until independent disposition of a fresh review leaves no `fix-now` or `stop-for-decision` findings.
3. Run the composed exact-head local-certification and hosted-CI phase.
4. Merge that exact head using the repository-required strategy. If GitHub reports `mergeable: UNKNOWN` right after a push, poll until `MERGEABLE` before merging.

When the protocol produces `stop-for-decision`, preserve the branch, record all dispositions and the review and verification history plus the precise invariant-and-owner root, and report the required design decision to the user. A `defer` or `reject` finding does not enter this branch. This merge skill does not silently widen or redesign the PR.

Apply the shared [contract-closure reference](../_shared/CONTRACT-CLOSURE.md) only after a `fix-now` finding triggers it.

The skill is complete when the reviewed, locally certified, and hosted-verified head is merged.
