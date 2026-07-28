---
name: implement-architecture-slice
description: Execute one audited child issue produced by architecture-handoff from contract preflight through one PR, review, exact-head validation, merge, journal, and program tracking. Use when the user provides an architecture-handoff child issue or its mirrored OmniFocus task, or asks to implement an audited architecture slice. Standalone or unplanned work belongs to planit; parent and tracking issues require an explicit architecture-handoff run.
---

# Implement Architecture Slice

Execute exactly one audited slice. Treat its committed plan as the design authority and translate that contract into one verified PR without creating another implementation plan.

## 1. Resolve the slice contract

Accept one GitHub child issue or its mirrored OmniFocus task. When given OmniFocus, use `omnifocus-cli` to resolve the child issue URL.

Require the child issue to contain all of the following:

- `<!-- architecture-handoff-slice:v1 -->`.
- `**Dispatch:** \`$implement-architecture-slice\``.
- A 40-character plan commit, plan path, and exact slice heading.
- Current state and blocker links. The child is a pointer surface; the exact plan slice owns the substantive contract.

Read the repository instructions; child and parent current state; the current default-branch slice contract; a bounded diff from its recorded plan commit when the governing contract changed; its referenced invariants and ADR/domain docs; only the unresolved review history named by the slice; the program index's frontier entry; and `docs/REVIEW-LOOP.md`. Read `docs/CONTRACT-CLOSURE.md` when present, otherwise use the shared [contract-closure reference](../_shared/CONTRACT-CLOSURE.md). Stop if the review protocol is absent. Stay inside the slice's declared context budget: do not ingest complete historical plan versions, audit chronology, or mirrored contracts.

Read the shared [review-loop baseline](../_shared/REVIEW-LOOP.md) here, not when the review loop begins. It owns finding disposition and the approach-stop policy, and both have to be in hand before the first finding arrives. A repository protocol that omits a baseline rule has not overridden it; only an explicit, reasoned override composes. Where the two disagree without such an override, the baseline governs and the divergence is worth reporting.

Verify every blocker is closed, the issue is on the current implementation frontier, and the current slice still agrees materially with the recorded contract. If the plan changed after the recorded commit, inspect the bounded governing diff for that slice and its referenced invariants; continue only when the slice contract is unchanged or the child pointer was explicitly synchronized with the accepted revision.

If the slice was created under legacy proof-oriented rules and contains recursive, proof-only, duplicated, or disproportionate evidence obligations, freeze dispatch and route to `$architecture-handoff` for the shared legacy-program rebaseline. Preserve completed shipped behavior and required safety enforcement; do not silently execute, strengthen, or delete legacy obligations.

Inspect any open PR or implementation branch named by the issue or plan. Continue it only under the recorded retain/rework disposition. Treat unmentioned existing work as evidence to evaluate, never as an implicit baseline.

This step is complete when one marked child, one accepted slice contract, one intended PR, and a closed blocker set agree.

## 2. Emit the execution preflight

Inspect the current code to confirm the plan's factual assumptions. Emit a short preflight containing:

- The accepted outcome, non-goals, and one-PR boundary.
- The likely files and real seams involved.
- Each material artifact's classification, including the payoff, supported domain, owner, and retirement policy for any verification aid approved as a blocking maintained deliverable.
- The supported input domain, representation owner, universal/canonical-subset/example-level guarantee, and finite terminating evidence.
- The tests to make red first, plus the preservation, restart, failure, concurrency, platform, and stress gates admitted by the evidence budget.
- The enforcement owner, authority-completeness obligations, transitional-seam budget, traced blast radius, and explicitly untraced effects.
- For closure explicitly triggered by material consequence plus multiple independently reachable paths or states, the invariant, enforcement owner, semantic matrix location, evidence budget, and uncovered cells. State “not triggered” for routine low-risk ordering or multiple-caller work.
- The declared dispatch-context and review-round budgets.
- The branch/worktree choice, existing-work precautions, and stop conditions.

This preflight reports how the accepted slice will be executed; it does not reopen its design. Continue after reporting it. Wait for approval only when the user explicitly requested an approval gate.

Enter the scoped re-audit branch below when current code invalidates an accepted assumption, the issue and plan disagree, ownership or authority must change within the accepted outcome, an untraced effect becomes material, or review produces a `stop-for-decision` finding that can still retain the accepted child and one-PR boundary without a new product or representation choice. A `defer` or `reject` finding does not enter re-audit. A handwritten scanner claiming broad coverage of an open external grammar is an immediate representation-mismatch stop; do not patch a syntax example or choose parser/canonical-subset/example-level scope for the user. An adjacent-slice crossing, product decision, representation choice, irreversible external action, or inability to retain one independently green PR is not a scoped repair; preserve useful branch state and ask the user to invoke `$architecture-handoff`.

## Scoped re-audit branch

The original `$implement-architecture-slice` invocation authorizes routine scoped re-audits that retain the accepted child, end-to-end outcome, and one-PR boundary. Do not ask the user to invoke another skill merely to enter this branch.

1. Preserve the implementation branch and stop code edits, RAS cycles, certification, and CI.
2. Reconstruct only the relevant code and unresolved review or verification evidence. Apply the shared [contract-closure reference](../_shared/CONTRACT-CLOSURE.md) only to accepted invariant-and-owner roots involved in the stop and only when both material-risk triggers remain true.
3. Re-run the slice gates: representation ownership, artifact classification, evidence budget, single owner, authority completeness, transitional seams, preservation, blast radius, context fit, and the strongest split/merge cases.
4. Continue only when the same child and one-PR outcome pass those gates with a central enforcement design and a finite terminating evidence plan.
   - Update the current normative plan contract in place. Put the coverage matrix and current disposition there; put trigger chronology, review/verification IDs, receipts, and superseded findings in a linked audit artifact or PR discussion.
   - Publish through the repository's authorized path and require the resulting commit to be reachable from the plan's authoritative branch before synchronizing the child issue's exact plan pointer. Do not copy the plan SHA into OmniFocus, parent, or program mirrors.
   - Refresh parent/tracking issues and track/program OmniFocus notes with current disposition, blockers/frontier, and pointers only. Keep re-audit docs out of the implementation diff unless the accepted plan explicitly co-locates them there.
5. If closure requires another child, adjacent scope, a different PR boundary, changed product intent, an irreversible external action, or an unresolved authority decision, preserve the branch and ask the user to invoke `$architecture-handoff`.
6. Post a concise re-audit receipt to linked audit history or PR discussion and update the child with the current plan-section pointer, exact docs commit, current state, and resume point. Reconcile the implementation branch with the advanced default branch and emit that receipt to the user.
   - For a preflight-triggered re-audit, return to Step 2, re-check the revised contract against current code, emit the revised execution preflight, and then enter Step 3.
   - For a review-triggered re-audit, resume the triggering review's inner loop: implement and test the central fix, push it, verify the triggering review against that exact head, and only then request a fresh review.

The branch is complete when the declared terminating evidence plan is satisfied and pointer-based tracking surfaces agree on current state. If review or verification produces a second behaviorally distinct semantic counterexample at the same precise invariant and enforcement owner, the approach failed. Do not append cases, mutate external syntax, strengthen a verification harness, or run another same-boundary re-audit; preserve the branch and require `$architecture-handoff`.

## 3. Implement one PR

Create a fresh branch/worktree from current default-branch HEAD unless the accepted disposition names existing work to retain or rework. Keep unrelated work untouched.

Use `tdd` at the seams named by the slice. Make the specified characterization or failing tests red, implement the narrowest contract-satisfying change, and run focused checks regularly within the accepted evidence budget. Independently disposition each substantive failure or review finding before designing a fix. Only for a `fix-now` finding, translate the example into its accepted invariant and in-contract semantic sibling family, then fix that family at its central enforcement owner when it fits the accepted representation and work contracts. Preserve the named single owner, authority boundary, artifact classes, intermediate contract, and non-goals. Do not recursively apply closure to tests or validation harnesses, and do not let verification aids become new blockers. Report worthwhile deferred improvements instead of absorbing them, and do not create follow-up busywork for rejected or marginal findings.

Run the slice's focused and stress gates plus the repository's ordinary local suite. Commit only scoped files, push, and open one PR that links the parent and plan, records the plan commit and slice heading, and closes the child issue.

This step is complete when the intended PR implements every acceptance criterion and no neighboring slice contract.

## 4. Review, certify, and merge

Follow the repository's `docs/REVIEW-LOOP.md` and the shared [review-loop baseline](../_shared/REVIEW-LOOP.md). The shared file owns finding disposition, semantic-family analysis, representation stops, verification-aware repeated-root classification, and the one-review-plus-one-replacement default budget; the repository protocol may add stronger boundary, certification, CI, merge, journal, tracking, and routing rules. Judge and fix findings yourself; use RAS only as those protocols permit. Route a `stop-for-decision` finding to the scoped re-audit branch only when no new user decision is required, and record dispositions and causal roots in linked audit history rather than appending them to the normative plan.

Run reviews through `ras-review` and verifications through `ras-verify` rather than invoking the CLI directly. Those skills carry run handling, severity-independent finding disposition, and the routing that presents only `stop-for-decision` findings to the operator before any fix; a direct CLI call silently drops all of it.

Brief every review. Follow `ras-review`'s operator-guidance section and build the prompt from the exact normative plan slice, quoting its acceptance criteria and non-goals verbatim and identifying its representation domain and owner, guarantee level, artifact classes, terminating evidence plan, review-round budget, and settled findings. Ask for contract-relevant behavioral failures within that representation domain; do not request syntax aliases or concrete mutants unless parser conformance or a central-guard mutation is explicitly in scope. A criterion that names the regressions discharging it is a ceiling. For the one allowed replacement review, add the round number and link what the initial review closed with its run ID and head SHA without copying chronology into the plan.

Before each inner fix loop, record the dispositions required by the shared baseline against the exact slice contract. Only `fix-now` findings enter implementation; route `stop-for-decision` appropriately, and keep `defer` and `reject` findings out of both paths. For each `fix-now` finding and every new verification observation, compare its precise invariant and enforcement owner with all prior review and verification evidence. A second behaviorally distinct semantic counterexample at the same root stops immediately.

Run one initial fresh review, verify only independently accepted `fix-now` findings, and run at most one replacement review. A new verification observation is independently dispositioned but does not silently become a fresh review; a later non-critical root after the replacement is normally `defer` or `stop-for-decision`. After the terminating evidence plan and review budget are complete with no unresolved stop, push the final candidate, run every accepted stress gate, and run the repository's exact-head local certification. Dispatch hosted CI only for that certified head, verify the live PR head and required result still match, and merge that exact head. Diagnose failed CI before deciding whether any rerun is legitimate. If the base advances, repeat every gate required by the repository protocol.

This step is complete only when the exact reviewed, locally certified, and hosted-verified head is merged.

## 5. Close the program loop

Run `append-dev-journal` without RAS. Ensure the child issue is closed, create review follow-up issues, and use `omnifocus-cli` to complete the exact slice task and add those follow-ups.

Recompute only the affected successors. When all of a successor's blockers are closed, apply the repository's agent-ready label, remove its OmniFocus blocked prefix, and refresh the tracking issue and program-parent current frontier without inventing ordering. Keep those updates to current state, blockers, and pointers; do not copy contracts, audit history, or exact plan-SHA narratives into mirrors.

Report the PR and merge commit, validation receipt and hosted run, journal commit, issue/OmniFocus updates, newly ready slices, follow-ups, and any remaining untraced effects.

The skill is complete when the merged slice, child issue, journal, OmniFocus tree, successor readiness, and program frontier agree.
