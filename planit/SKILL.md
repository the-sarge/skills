---
name: planit
description: Produce an implementation plan for standalone or unplanned work and drive it to merge through a controlled, agent-in-the-loop review cycle. Use when the user asks to plan a feature or change that has not already been packaged as an architecture-handoff child slice. Route marked architecture-handoff child issues and their mirrored OmniFocus tasks to implement-architecture-slice.
---

# planit

Produce an implementation plan, get the user's approval, then drive it to merge one PR at a time through a review loop where **you** do the fixing and judging and RAS is used **only** to review and verify.

Before planning, inspect any supplied issue. When given an OmniFocus task, use `omnifocus-cli` to resolve and inspect its linked issue. When the issue contains `<!-- architecture-handoff-slice:v1 -->`, invoke `$implement-architecture-slice`; its committed plan is already the approved design and its execution preflight replaces this planning stage.

## Workflow

### 1. Plan

- Write the plan, then present it to the user for approval **before writing any code**.
- Implementation happens in a branch, divided into multiple PRs if needed, using TDD where appropriate.
- For each non-trivial design choice, state what it changes **beyond** the immediate goal — its blast radius (shared/global state, concurrency and ordering, public API and data/schema contracts, error and failure modes, performance, security surface, new dependencies, etc.) — and prefer the option with the smallest blast radius. Explicitly flag any choice whose full effects you haven't traced.
- Write the plan inline — concrete enough to execute: the PR breakdown and, within each PR, the specific changes and tests. Do not hand the plan off to another skill.

### 2. For each PR

1. Implement the PR's work — use the `tdd` skill where appropriate — then push and open the PR.
2. Run the **review loop** below until a fresh review surfaces no blocking findings.
3. Run the repository's final local certification once the review-clean candidate is pushed. If it exposes `task preflight`, run it and retain its exact head/base receipt; otherwise run and record the repository's documented local equivalents against the exact SHA. Run slice-specific stress gates separately when the plan names them. Any later candidate change invalidates this receipt and returns the PR to review before a new certification, except the explicitly exempted docs-only polish above: run its lightweight docs checks and generate a new local certification without another RAS review.
4. Request the required hosted CI for that same head, verify the run head and live PR head still match, and confirm the required result before merge. Do not blindly rerun a failed unchanged head: diagnose it first; fix repository failures and return to review, and allow a same-head rerun only for a demonstrated external infrastructure failure.
5. Merge (squash) that exact head. If `main` advances, update the branch and repeat review, local certification, and CI. If GitHub reports `mergeable: UNKNOWN` right after a push, poll until `MERGEABLE` before merging.
6. Append a dev-journal entry with the `append-dev-journal` skill — **do NOT run `ras` for the journal**.
7. Update OmniFocus with the `omnifocus-cli` skill — complete the relevant task and add any follow-up issues created during review.

### The review loop

**You** do all the fixing and judging; RAS is used **only** to review and verify. Never hand fixing to an auto-fixer — do **NOT** use `ras review-fix` or `ras-review-loop`. "Clean" means **no remaining blocking findings**; low/nit findings never hold the loop open.

Low/nit handling is a loop-control policy, not just a prioritization hint. If low/nit findings appear alongside blocking findings, fix cheap and local low/nit items only while another verify/review cycle is already required for blockers. If the only remaining findings are low/nit and any are not docs-only, do not fix them now, even if they look cheap; file follow-up issues and stop the loop. If the only remaining findings are low/nit docs-only findings, fix them only when the edit is cheap and correctness is very high confidence; after that docs-only polish fix, do not run another `ras review`, `ras verify`, or full RAS loop solely for the docs change.

Approach-stop policy: before fixing blockers from a fresh review, compare its synthesis with every prior fresh review and verified fix for the PR. Treat any blocker that requires work beyond the approved PR boundary, acceptance criteria, or declared blast radius as an immediate approach-level finding. Also stop when a later fresh blocker is rooted in the same ownership, authority, seam, ordering, schema, or failure-model assumption as a previously verified fix, or when the sequence of otherwise-local blockers collectively requires widening the approved boundary. Preserve the branch, record the review/verification run IDs and causal pattern, run no further fix/verify/review cycle, and present a revised approach for user approval. Failed verification of the current fix remains inner-loop evidence and does not by itself establish a repeated fresh-review pattern.

```
outer review loop:
  ras review <pr>
  if the review has no blocking findings:
    apply the low/nit policy above
    done

  compare the blocking synthesis with all prior fresh reviews and verified fixes
  if any blocker crosses the approved PR boundary, or the review history shows
    a repeated root assumption or collective boundary expansion:
      STOP, preserve the branch, report the review history, and check with the user

  inner fix loop:
    for each blocking synthesis item, first judge: is this a local fix, or a
      sign the APPROACH itself is wrong? If approach-wrong, STOP, reconsider
      the design, and check with the user — do not patch around it.
    fix the blocking items
    run the required tests
    push the branch update
    ras verify <review-run-id> --head <exact 40-char SHA you just pushed>
    if verification confirms the blocking items are resolved: return to the
      outer loop (a FRESH ras review, to catch any NEW blocking issues the
      fixes introduced)
    else: stay in the inner fix loop, fixing using BOTH the review and the
      verification feedback
Repeat until a fresh ras review surfaces no blocking findings.
```
