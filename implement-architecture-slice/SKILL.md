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

Read the repository instructions; child and parent current state; the current default-branch slice contract; a bounded diff from its recorded plan commit when the governing contract changed; its referenced invariants and ADR/domain docs; only the unresolved review history named by the slice; and the program index's frontier entry. Stay inside the slice's declared context budget: do not ingest complete historical plan versions, audit chronology, or mirrored contracts.

Read the shared [review-loop baseline](../_shared/REVIEW-LOOP.md) and [contract-closure baseline](../_shared/CONTRACT-CLOSURE.md) here, not when implementation or review begins. Stop if either shared baseline is unavailable.

Read `docs/REVIEW-LOOP.md` and `docs/CONTRACT-CLOSURE.md` only when present as repository-specific overlays. Stop if the repository instructions or accepted slice contract explicitly require an overlay that is unavailable; do not stop merely because no overlay exists. The shared review-loop baseline owns finding disposition and the approach-stop policy, and both have to be in hand before the first finding arrives. A repository overlay that omits a baseline rule has not overridden it; only an explicit, reasoned override composes. Where the two disagree without such an override, the baseline governs and the divergence is worth reporting.

Verify every blocker is closed, the issue is on the current implementation frontier, and the current slice still agrees materially with the recorded contract. If the plan changed after the recorded commit, inspect the bounded governing diff for that slice and its referenced invariants; continue only when the slice contract is unchanged or the child pointer was explicitly synchronized with the accepted revision.

If the slice qualifies for the shared [legacy-program rebaseline](../_shared/CONTRACT-CLOSURE.md#keep-contracts-and-tracking-bounded), freeze dispatch and route to `$architecture-handoff`; do not reinterpret the legacy contract inside this execution workflow.

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
- For closure triggered by the shared policy, the invariant, enforcement owner, semantic matrix location, evidence budget, and uncovered cells; otherwise the plan's recorded not-triggered disposition.
- The declared dispatch-context and review-round budgets.
- The branch/worktree choice, existing-work precautions, and stop conditions.

This preflight reports how the accepted slice will be executed; it does not reopen its design. Continue after reporting it. Wait for approval only when the user explicitly requested an approval gate.

Enter the scoped re-audit branch below when current code invalidates an accepted assumption, the issue and plan disagree, ownership or authority must change within the accepted outcome, an untraced effect becomes material, or review produces a `stop-for-decision` finding that can still retain the accepted child and one-PR boundary without a new product or representation choice. A `defer` or `reject` finding does not enter re-audit. Any stop from the shared representation gate requires an operator decision and cannot enter this branch. An adjacent-slice crossing, product decision, representation choice, irreversible external action, or inability to retain one independently green PR is not a scoped repair; preserve useful branch state and ask the user to invoke `$architecture-handoff`.

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

The branch is complete when the declared terminating evidence plan is satisfied and pointer-based tracking surfaces agree on current state. An [approach stop](../_shared/REVIEW-LOOP.md#approach-stops) ends the current fix/verify/review cycle but does not by itself select `$architecture-handoff`. Route it through the decision rules above: use this scoped re-audit when the accepted child, outcome, representation contract, and one-PR boundary remain intact; require `$architecture-handoff` only when closure requires another child, adjacent scope, a different PR boundary, changed product intent or representation, irreversible external action, or an unresolved authority decision. Do not resume code edits or RAS cycles until that routing decision is recorded.

## 3. Implement one PR

Create a fresh branch/worktree from current default-branch HEAD unless the accepted disposition names existing work to retain or rework. Keep unrelated work untouched.

Use `tdd` at the seams named by the slice. Make the specified characterization or failing tests red, implement the narrowest contract-satisfying change, and run focused checks regularly within the accepted evidence budget. Independently disposition each substantive failure or review finding before designing a fix. Apply the shared semantic-family, contract-closure, artifact, and non-recursion policies only to `fix-now` findings. Preserve the named single owner, authority boundary, artifact classes, intermediate contract, and non-goals. Report worthwhile deferred improvements instead of absorbing them, and do not create follow-up busywork for rejected or marginal findings.

Run the slice's focused and stress gates plus the repository's ordinary local suite. Commit only scoped files, push, and open one PR that links the parent and plan, records the plan commit and slice heading, and closes the child issue.

This step is complete when the intended PR implements every acceptance criterion and no neighboring slice contract.

## 4. Review, certify, and merge

Follow the shared [review-loop baseline](../_shared/REVIEW-LOOP.md) and compose any existing repository-specific `docs/REVIEW-LOOP.md` overlay. The shared baseline owns disposition, family, stop, and budget rules. A repository overlay may add stronger boundary, certification, CI, merge, journal, tracking, and routing rules or explicit, reasoned overrides. Judge and fix findings yourself; use RAS only as the composed protocol permits. Route a `stop-for-decision` finding to the scoped re-audit branch only when no new user decision is required, and record dispositions and causal roots in linked audit history rather than appending them to the normative plan.

Always run reviews through `ras-review` and verifications through `ras-verify`. This is mandatory: never invoke `ras review`, `ras verify`, or equivalent direct CLI paths during this workflow, even when their syntax is known. Those skills carry run handling, severity-independent finding disposition, and the routing that presents only `stop-for-decision` findings to the operator before any fix; a direct CLI call silently drops all of it. If either required skill is unavailable, stop and report the missing dependency instead of falling back to the CLI.

Build every prompt from the exact normative plan slice and the shared [review briefing](../_shared/REVIEW-LOOP.md#review-briefing), following `ras-review`'s mechanical quoting guidance. Link round history without copying chronology into the plan.

Before each inner fix loop, record the dispositions required by the shared baseline against the exact slice contract. Only `fix-now` findings enter implementation; route `stop-for-decision` appropriately, keep `defer` and `reject` findings out of both paths, and apply the shared approach-stop history check to review and verification evidence. Before declaring two findings the same root, record the shared contract-closure comparison: exact invariant, concrete central enforcement seam, both semantic classes, and why the earlier accepted family had to cover the later case. Do not equate roots merely because they share a package, table, transaction helper, lifecycle, or broad authority concern.

Execute the shared [bounded review algorithm](../_shared/REVIEW-LOOP.md#bounded-review-algorithm). After it and the terminating evidence plan are complete with no unresolved stop, push the final candidate, run every accepted stress gate, and run the repository's exact-head local certification. Dispatch hosted CI only for that certified head, verify the live PR head and required result still match, and merge that exact head. Diagnose failed CI before deciding whether any rerun is legitimate. If the base advances, repeat every gate required by the repository protocol.

This step is complete only when the exact reviewed, locally certified, and hosted-verified head is merged.

## 5. Close the program loop

Run `append-dev-journal` without RAS. Ensure the child issue is closed, create review follow-up issues, and use `omnifocus-cli` to complete the exact slice task and add those follow-ups.

Recompute only the affected successors. When all of a successor's blockers are closed, apply the repository's agent-ready label, remove its OmniFocus blocked prefix, and refresh the tracking issue and program-parent current frontier without inventing ordering. Keep those updates to current state, blockers, and pointers; do not copy contracts, audit history, or exact plan-SHA narratives into mirrors.

Report the PR and merge commit, validation receipt and hosted run, journal commit, issue/OmniFocus updates, newly ready slices, follow-ups, and any remaining untraced effects.

The skill is complete when the merged slice, child issue, journal, OmniFocus tree, successor readiness, and program frontier agree.
