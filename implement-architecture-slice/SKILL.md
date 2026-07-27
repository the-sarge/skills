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
- One end-to-end outcome, acceptance criteria, ownership and authority obligations, transition budget, blockers, preservation proof, and approach-level stop conditions.

Read the repository instructions, child and parent issues, the plan at the recorded commit, the current default-branch version of that plan, the program index, referenced ADR/domain docs, and `docs/REVIEW-LOOP.md`. Read `docs/CONTRACT-CLOSURE.md` when present, otherwise use the shared [contract-closure reference](../_shared/CONTRACT-CLOSURE.md). Stop if the review protocol is absent.

Verify every blocker is closed, the issue is on the current implementation frontier, and the current plan still agrees materially with the recorded contract. If the plan changed after the recorded commit, inspect that diff; continue only when the slice contract is unchanged or the child issue was explicitly synchronized with the accepted revision.

Inspect any open PR or implementation branch named by the issue or plan. Continue it only under the recorded retain/rework disposition. Treat unmentioned existing work as evidence to evaluate, never as an implicit baseline.

This step is complete when one marked child, one accepted slice contract, one intended PR, and a closed blocker set agree.

## 2. Emit the execution preflight

Inspect the current code to confirm the plan's factual assumptions. Emit a short preflight containing:

- The accepted outcome, non-goals, and one-PR boundary.
- The likely files and real seams involved.
- The tests to make red first, plus preservation, restart, failure, concurrency, platform, and stress gates required by the slice.
- The mutation owner, authority-completeness obligations, transitional-seam budget, traced blast radius, and explicitly untraced effects.
- The contract-closure invariant, enforcement owner, matrix location, and uncovered cells for every triggered protocol, lifecycle, multi-entrypoint, authority, environment, restoration, restart, concurrency, or security-sensitive boundary.
- The branch/worktree choice, existing-work precautions, and stop conditions.

This preflight reports how the accepted slice will be executed; it does not reopen its design. Continue after reporting it. Wait for approval only when the user explicitly requested an approval gate.

Enter the scoped re-audit branch below when current code invalidates an accepted assumption, the issue and plan disagree, ownership or authority must change within the accepted outcome, an untraced effect becomes material, or review reaches an approach stop. A remaining blocker, adjacent-slice crossing, product decision, irreversible external action, or inability to retain one independently green PR is not a scoped repair; preserve useful branch state and ask the user to invoke `$architecture-handoff`.

## Scoped re-audit branch

The original `$implement-architecture-slice` invocation authorizes routine scoped re-audits that retain the accepted child, end-to-end outcome, and one-PR boundary. Do not ask the user to invoke another skill merely to enter this branch.

1. Preserve the implementation branch and stop code edits, RAS cycles, certification, and CI.
2. Reconstruct the complete code and review evidence, including verified fixes. Apply the shared [contract-closure reference](../_shared/CONTRACT-CLOSURE.md) to every precise invariant-and-owner root involved.
3. Re-run the slice gates: single owner, authority completeness, transitional seams, preservation, blast radius, context fit, and the strongest split/merge cases.
4. Continue only when the same child and one-PR outcome pass those gates with a central enforcement design and a complete closure matrix. Add a durable re-audit section to the plan containing the closure matrix, disposition, trigger evidence, and review/verification IDs when they exist; update the program overview in a clean docs worktree from the plan's authoritative branch. The plan's authoritative branch is the branch the child issue's plan commit is reachable from, which is often but not always the default branch; a program whose plan lives on a long-lived handoff branch publishes there instead. Publish those docs through the repository's authorized path and require the resulting commit to be reachable from that same authoritative branch before synchronizing its exact SHA into the existing child issue and exact OmniFocus slice task. Refresh the parent/tracking issues and track/program OmniFocus notes with the revised disposition and frontier using their existing representations; do not duplicate the commit field where their contract does not define one. Keep re-audit docs out of the implementation diff unless the accepted plan explicitly co-locates them there.
5. If closure requires another child, adjacent scope, a different PR boundary, changed product intent, an irreversible external action, or an unresolved authority decision, preserve the branch and ask the user to invoke `$architecture-handoff`.
6. Post a re-audit receipt to the child issue containing the plan-section link, exact docs commit, synchronized tracking surfaces, trigger evidence, and resume point. Reconcile the implementation branch with the advanced default branch and emit that receipt to the user.
   - For a preflight-triggered re-audit, return to Step 2, re-check the revised contract against current code, emit the revised execution preflight, and then enter Step 3.
   - For a review-triggered re-audit, resume the triggering review's inner loop: implement and test the central fix, push it, verify the triggering review against that exact head, and only then request a fresh review.

The branch is complete only when every triggered closure row has a disposition and proof and all synchronized tracking surfaces agree through their defined representations. If a later fresh review exposes an uncovered sibling in the same precise invariant-and-owner root, the scoped closure proof failed. Do not append cases or run another same-boundary re-audit. Classify the failure before routing:

- **Design repeat**: the reviews dispute ownership, authority, a seam, the failure model, or the production behavior itself, or closing the family needs work outside the accepted boundary. Preserve the branch and require `$architecture-handoff`.
- **Proof-depth repeat**: every review confirms the production behavior correct, and the repeats are all uncovered cells of an obligation that was satisfiable without pinning the property. This authorizes exactly one in-place proof re-specification: restate the obligation as the regression it must detect, rebuild the matrix under the mutation gate in the shared [contract-closure reference](../_shared/CONTRACT-CLOSURE.md), and mutation-verify every row including inherited tests. It stays in the implementation PR, publishes no docs, and does not re-enter the scoped re-audit branch. Record in the PR that the one in-place re-specification was used. If a fresh review then exposes another sibling in that same root, preserve the branch and require `$architecture-handoff` without further classification.

## 3. Implement one PR

Create a fresh branch/worktree from current default-branch HEAD unless the accepted disposition names existing work to retain or rework. Keep unrelated work untouched.

Use `tdd` at the seams named by the slice. Make the specified characterization or failing tests red, implement the narrowest contract-satisfying change, and run focused checks regularly. For each substantive failure or review finding, translate the example into its violated invariant and sibling family before editing; fix the family at its central enforcement owner when it fits the accepted contract. Preserve the named single owner, authority boundary, intermediate contract, and non-goals. File adjacent improvements as follow-up issues instead of absorbing them.

Run the slice's focused and stress gates plus the repository's ordinary local suite. Commit only scoped files, push, and open one PR that links the parent and plan, records the plan commit and slice heading, and closes the child issue.

This step is complete when the intended PR implements every acceptance criterion and no neighboring slice contract.

## 4. Review, certify, and merge

Follow the repository's `docs/REVIEW-LOOP.md` and the shared [review-loop baseline](../_shared/REVIEW-LOOP.md). The shared file owns finding-family and precise invariant-and-owner classification; the repository protocol may add stronger boundary, certification, CI, merge, journal, tracking, and routing rules. Judge and fix findings yourself; use RAS only as those protocols permit. Route any approach stop to the scoped re-audit branch and record the review/verification run IDs plus the precise causal pattern.

After a fresh review is clean, push the final candidate, run every named stress gate, and run the repository's exact-head local certification. Dispatch hosted CI only for that certified head, verify the live PR head and required result still match, and merge that exact head. Diagnose failed CI before deciding whether any rerun is legitimate. If the base advances, repeat every gate required by the repository protocol.

This step is complete only when the exact reviewed, locally certified, and hosted-verified head is merged.

## 5. Close the program loop

Run `append-dev-journal` without RAS. Ensure the child issue is closed, create review follow-up issues, and use `omnifocus-cli` to complete the exact slice task and add those follow-ups.

Recompute only the affected successors. When all of a successor's blockers are closed, apply the repository's agent-ready label, remove its OmniFocus blocked prefix, and refresh the tracking issue and program-parent current frontier without inventing ordering.

Report the PR and merge commit, validation receipt and hosted run, journal commit, issue/OmniFocus updates, newly ready slices, follow-ups, and any remaining untraced effects.

The skill is complete when the merged slice, child issue, journal, OmniFocus tree, successor readiness, and program frontier agree.
