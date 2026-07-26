---
name: loop-review
description: Get a PR ready for merge in a controlled, agent-in-the-loop review cycle. Runs each PR through a manual `ras review`/`ras verify` loop (the agent does the fixing — never the auto-fixer) before merge.
---

# loop-review

Get a PR ready for merge through a review loop where **you** do the fixing and judging and RAS is used **only** to review and verify.

## Workflow

Read the repository's review protocol when present and compose its stronger repository-specific rules with the review phase of the shared [review-loop baseline](../_shared/REVIEW-LOOP.md). Continue until a fresh review surfaces no blocking findings.

When the protocol reaches an approach stop, preserve the branch, record the review and verification history plus the precise invariant-and-owner root, and report the required design decision to the user. This review-only skill does not silently widen or redesign the PR.

Apply the shared [contract-closure reference](../_shared/CONTRACT-CLOSURE.md) whenever a blocking finding triggers it.

The skill is complete when the fresh review is clean after the low/nit policy. Leave certification, merge, journal, and tracking to the invoking workflow.
