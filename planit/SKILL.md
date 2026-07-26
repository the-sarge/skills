---
name: planit
description: Produce an implementation plan for standalone or unplanned work and drive it to merge through a controlled, agent-in-the-loop review cycle. Use when the user asks to plan a feature or change that has not already been packaged as an architecture-handoff child slice. Route marked architecture-handoff child issues and their mirrored OmniFocus tasks to implement-architecture-slice.
---

# planit

Produce an implementation plan, get the user's approval, then drive it to merge one PR at a time through a review loop where **you** do the fixing and judging and RAS is used **only** to review and verify.

Before planning, inspect any supplied issue. When given an OmniFocus task, use `omnifocus-cli` to resolve and inspect its linked issue. When the issue contains `<!-- architecture-handoff-slice:v1 -->`, invoke `$implement-architecture-slice`; its committed plan is already the approved design and its execution preflight replaces this planning stage. Read the repository's review protocol when present and compose its stronger repository-specific rules with the shared [review-loop baseline](../_shared/REVIEW-LOOP.md).

## Workflow

### 1. Plan

- Write the plan, then present it to the user for approval **before writing any code**.
- Implementation happens in a branch, divided into multiple PRs if needed, using TDD where appropriate.
- For each non-trivial design choice, state what it changes **beyond** the immediate goal — its blast radius (shared/global state, concurrency and ordering, public API and data/schema contracts, error and failure modes, performance, security surface, new dependencies, etc.) — and prefer the option with the smallest blast radius. Explicitly flag any choice whose full effects you haven't traced.
- Apply the shared [contract-closure reference](../_shared/CONTRACT-CLOSURE.md) when a PR crosses one of its risk triggers. Include the precise invariant, enforcement owner, behaviorally distinct classes, dispositions, and proving tests in the plan; the plan is not approval-ready while a triggered row is untraced.
- Write the plan inline — concrete enough to execute: the PR breakdown and, within each PR, the specific changes and tests. Do not hand the plan off to another skill.

### 2. For each PR

1. Implement the PR's work — use the `tdd` skill where appropriate — then push and open the PR.
2. Run the review phase of the composed repository and shared protocols until a fresh review surfaces no blocking findings.
3. Run every planned stress gate, push the final candidate, and then run the repository's final local exact-head certification. If it exposes `task preflight`, run it and retain its exact head/base receipt; otherwise run and record the repository's documented local equivalents against the exact SHA. Any later candidate change invalidates this receipt and returns the PR to review before a new certification, except the shared protocol's docs-only polish exemption: run its lightweight docs checks and generate a new local certification without another RAS review.
4. Request the required hosted CI for that same head, verify the run head and live PR head still match, and confirm the required result before merge. Do not blindly rerun a failed unchanged head: diagnose it first; fix repository failures and return to review, and allow a same-head rerun only for a demonstrated external infrastructure failure.
5. Merge that exact head using the repository-required strategy. If `main` advances, update the branch and repeat review, local certification, and CI. If GitHub reports `mergeable: UNKNOWN` right after a push, poll until `MERGEABLE` before merging.
6. Append a dev-journal entry with the `append-dev-journal` skill — **do NOT run `ras` for the journal**.
7. Update OmniFocus with the `omnifocus-cli` skill — complete the relevant task and add any follow-up issues created during review.

### Approach stops

Apply the shared [contract-closure reference](../_shared/CONTRACT-CLOSURE.md) before deciding whether a finding is local. When the composed review protocol reaches an approach stop, preserve the branch, record the review history and precise invariant-and-owner root, revise the plan using a complete closure proof, and present the changed approach for user approval before resuming code or RAS.
