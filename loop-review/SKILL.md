---
name: loop-review
description: Get a PR ready for merge in a controlled, agent-in-the-loop review cycle. Runs each PR through a manual `ras review`/`ras verify` loop (the agent does the fixing — never the auto-fixer) before merge.
---

# loop-review

Get a PR ready for merge through a review loop where **you** do the fixing and judging and RAS is used **only** to review and verify.

## Workflow

Read the repository's review protocol when present and compose its stronger repository-specific rules with the review phase of the shared [review-loop baseline](../_shared/REVIEW-LOOP.md). Require the accepted contract to name its representation domain and owner, guarantee level, artifact classes, terminating evidence plan, and review-round budget. Run one fully briefed fresh review, verify independently accepted `fix-now` findings, and permit at most one replacement review; complete against accepted evidence rather than reviewer exhaustion.

When the protocol produces `stop-for-decision`, preserve the branch, record all dispositions and the review and verification history plus the precise invariant-and-owner root, and report the required design decision to the user. A `defer` or `reject` finding does not enter this branch. This review-only skill does not silently widen or redesign the PR.

Apply the shared [contract-closure reference](../_shared/CONTRACT-CLOSURE.md) only after a `fix-now` finding has both a material failure consequence and multiple independently reachable paths or states that focused tests cannot reasonably cover. A representation mismatch stops immediately, and a second behaviorally distinct counterexample at the same invariant and owner stops whether review or verification found it.

The skill is complete when the terminating evidence plan and bounded review are complete with no unresolved `stop-for-decision` finding after the low/nit policy. Leave certification, merge, journal, and tracking to the invoking workflow.
