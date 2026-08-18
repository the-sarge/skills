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
- Give each PR an explicit review contract: the current outcome, acceptance criteria, existing behavior on the changed surface that must be preserved, non-goals, approved blast radius, artifact classifications, representation domain and owner, guarantee level, terminating evidence plan, and review-round budget. Treat that contract as both the minimum to deliver and the ceiling a review finding cannot silently expand.
- Classify every material artifact through the shared contract-closure policy and record any explicit approval for a verification aid to block shipped work.
- For each non-trivial design choice, state what it changes **beyond** the immediate goal — its blast radius (shared/global state, concurrency and ordering, public API and data/schema contracts, error and failure modes, performance, security surface, new dependencies, etc.) — and prefer the option with the smallest blast radius. Explicitly flag any choice whose full effects you haven't traced.
- Apply the shared [contract-closure reference](../_shared/CONTRACT-CLOSURE.md), including its universal-criterion representation gate, material-risk trigger, artifact classification, and evidence budgets. Record the resulting representation contract and any triggered semantic matrix in the plan; do not approve a plan that the shared policy routes to `stop-for-decision`.
- Keep the plan normative and current: update the accepted outcome, boundaries, invariants, evidence, blockers, and stop conditions in place. Link review chronology, run IDs, superseded findings, and historical receipts instead of appending them. Give each PR a bounded implementation context containing the current contract, referenced invariants, relevant unresolved history, and a governing diff when the contract changed.
- Write the plan inline — concrete enough to execute: the PR breakdown and, within each PR, the specific changes and tests. Do not hand the plan off to another skill.

### 2. For each PR

1. Implement the PR's work — use the `tdd` skill where appropriate — then push and open the PR.
2. Run the shared review loop's [review briefing](../_shared/REVIEW-LOOP.md#review-briefing) and [bounded review algorithm](../_shared/REVIEW-LOOP.md#bounded-review-algorithm).
3. Run every planned stress gate, push the final candidate, and then run the repository's final local exact-head certification. If it exposes `task preflight`, run it and retain its exact head/base receipt; otherwise run and record the repository's documented local equivalents against the exact SHA. Any later candidate change invalidates this receipt and returns the PR to review before a new certification, except the shared protocol's docs-only polish exemption: run its lightweight docs checks and generate a new local certification without another RAS review.
4. Mark the draft PR ready so the required `ci-*` checks run on that same head, verify the live PR head has not moved, and confirm every required check succeeded before merge (a post-ready `ci` run with conclusion `success`; a draft-phase `skipped` check is not evidence). Do not blindly rerun a failed unchanged head: diagnose it first; fix repository failures and return to review, and allow a same-head rerun only for a demonstrated external infrastructure failure.
5. Merge that exact head using the repository-required strategy. If `main` advances, update the branch and repeat review, local certification, and CI. If GitHub reports `mergeable: UNKNOWN` right after a push, poll until `MERGEABLE` before merging.
6. **Only after step 5 has completed and the main work is on the default branch**, append a dev-journal entry with the `append-dev-journal` skill — **do NOT run `ras` for the journal**. **NEVER start `append-dev-journal` before the main work has merged.** Do not open the next product PR while this PR's journal is still in flight if that would put the next PR behind a journal merge.
7. Revalidate every pending `defer` against the merged head per the shared [deferred-finding revalidation](../_shared/REVIEW-LOOP.md#deferred-finding-revalidation) rule, filing only the survivors. Then update OmniFocus with the `omnifocus-cli` skill — complete the relevant task and add those follow-ups.

### Approach stops

Apply the shared review loop's finding-disposition policy before doing sibling-family or contract-closure work. A `defer` or `reject` finding does not revise the plan. When a finding is `stop-for-decision`, preserve the branch, record the disposition evidence and review history, revise the plan only as far as the accepted decision requires, and present the changed approach for user approval before resuming code or RAS.
