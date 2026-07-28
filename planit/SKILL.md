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
- Classify every material artifact as shipped behavior, required safety enforcement, verification aid, or process/traceability metadata before assigning evidence. Keep a verification aid off the product critical path unless the user-approved outcome explicitly makes it a maintained deliverable and states its operational payoff, supported domain, owner, and retirement policy.
- For each non-trivial design choice, state what it changes **beyond** the immediate goal — its blast radius (shared/global state, concurrency and ordering, public API and data/schema contracts, error and failure modes, performance, security surface, new dependencies, etc.) — and prefer the option with the smallest blast radius. Explicitly flag any choice whose full effects you haven't traced.
- For each acceptance criterion containing “all,” “every,” “never,” “exactly,” or another universal claim, state the supported input domain, representation owner, universal/canonical-subset/example-level guarantee, and finite terminating evidence. If the proposed implementation cannot own that domain through an authoritative parser or validator or an enforced canonical subset, narrow the criterion or return `stop-for-decision` before approval.
- Apply the shared [contract-closure reference](../_shared/CONTRACT-CLOSURE.md) only when an accepted obligation has both a material failure consequence and multiple independently reachable paths or states that ordinary focused tests cannot reasonably cover. Routine ordering or multiple-caller work defaults to focused tests. For triggered closure, pass the representation gate and include the precise invariant, enforcement owner, behaviorally distinct semantic classes, dispositions, artifact classes, and proportionate evidence budget in the plan; the plan is not approval-ready while a required row is untraced.
- Keep the plan normative and current: update the accepted outcome, boundaries, invariants, evidence, blockers, and stop conditions in place. Link review chronology, run IDs, superseded findings, and historical receipts instead of appending them. Give each PR a bounded implementation context containing the current contract, referenced invariants, relevant unresolved history, and a governing diff when the contract changed.
- Write the plan inline — concrete enough to execute: the PR breakdown and, within each PR, the specific changes and tests. Do not hand the plan off to another skill.

### 2. For each PR

1. Implement the PR's work — use the `tdd` skill where appropriate — then push and open the PR.
2. Run the bounded review phase of the composed repository and shared protocols: one fully briefed fresh review, verification of independently accepted `fix-now` findings, and at most one fully briefed replacement review. Complete against the declared evidence plan rather than reviewer exhaustion; later non-critical roots are normally `defer` or `stop-for-decision`.
3. Run every planned stress gate, push the final candidate, and then run the repository's final local exact-head certification. If it exposes `task preflight`, run it and retain its exact head/base receipt; otherwise run and record the repository's documented local equivalents against the exact SHA. Any later candidate change invalidates this receipt and returns the PR to review before a new certification, except the shared protocol's docs-only polish exemption: run its lightweight docs checks and generate a new local certification without another RAS review.
4. Request the required hosted CI for that same head, verify the run head and live PR head still match, and confirm the required result before merge. Do not blindly rerun a failed unchanged head: diagnose it first; fix repository failures and return to review, and allow a same-head rerun only for a demonstrated external infrastructure failure.
5. Merge that exact head using the repository-required strategy. If `main` advances, update the branch and repeat review, local certification, and CI. If GitHub reports `mergeable: UNKNOWN` right after a push, poll until `MERGEABLE` before merging.
6. Append a dev-journal entry with the `append-dev-journal` skill — **do NOT run `ras` for the journal**.
7. Update OmniFocus with the `omnifocus-cli` skill — complete the relevant task and add any follow-up issues created during review.

### Approach stops

Apply the shared review loop's finding-disposition policy before doing sibling-family or contract-closure work. A `defer` or `reject` finding does not revise the plan. When a finding is `stop-for-decision`, preserve the branch, record the disposition evidence and review history, revise the plan only as far as the accepted decision requires, and present the changed approach for user approval before resuming code or RAS.
