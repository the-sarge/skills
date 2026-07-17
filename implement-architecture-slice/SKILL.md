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

Read the repository instructions, child and parent issues, the plan at the recorded commit, the current default-branch version of that plan, the program index, referenced ADR/domain docs, and `docs/REVIEW-LOOP.md`. Stop if the review protocol is absent.

Verify every blocker is closed, the issue is on the current implementation frontier, and the current plan still agrees materially with the recorded contract. If the plan changed after the recorded commit, inspect that diff; continue only when the slice contract is unchanged or the child issue was explicitly synchronized with the accepted revision.

Inspect any open PR or implementation branch named by the issue or plan. Continue it only under the recorded retain/rework disposition. Treat unmentioned existing work as evidence to evaluate, never as an implicit baseline.

This step is complete when one marked child, one accepted slice contract, one intended PR, and a closed blocker set agree.

## 2. Emit the execution preflight

Inspect the current code to confirm the plan's factual assumptions. Emit a short preflight containing:

- The accepted outcome, non-goals, and one-PR boundary.
- The likely files and real seams involved.
- The tests to make red first, plus preservation, restart, failure, concurrency, platform, and stress gates required by the slice.
- The mutation owner, authority-completeness obligations, transitional-seam budget, traced blast radius, and explicitly untraced effects.
- The branch/worktree choice, existing-work precautions, and stop conditions.

This preflight reports how the accepted slice will be executed; it does not reopen its design. Continue after reporting it. Wait for approval only when the user explicitly requested an approval gate.

Stop with evidence and ask the user to invoke `$architecture-handoff` for re-audit when current code invalidates an accepted assumption, the issue and plan disagree, a blocker remains open, the work crosses an adjacent slice, ownership or authority must change, an untraced effect becomes material, or the work cannot fit one independently green PR. Preserve any useful branch state and recommend re-audit rather than expanding the slice locally.

## 3. Implement one PR

Create a fresh branch/worktree from current default-branch HEAD unless the accepted disposition names existing work to retain or rework. Keep unrelated work untouched.

Use `tdd` at the seams named by the slice. Make the specified characterization or failing tests red, implement the narrowest contract-satisfying change, and run focused checks regularly. Preserve the named single owner, authority boundary, intermediate contract, and non-goals. File adjacent improvements as follow-up issues instead of absorbing them.

Run the slice's focused and stress gates plus the repository's ordinary local suite. Commit only scoped files, push, and open one PR that links the parent and plan, records the plan commit and slice heading, and closes the child issue.

This step is complete when the intended PR implements every acceptance criterion and no neighboring slice contract.

## 4. Review, certify, and merge

Follow `docs/REVIEW-LOOP.md` exactly. Judge and fix findings yourself; use RAS only as that protocol permits. Before fixing blockers from each fresh review, compare them with all prior fresh reviews and verified fixes for this PR. Treat a blocker outside the pinned slice as an immediate approach-level finding. Also stop when a later fresh blocker is rooted in the same accepted ownership, authority, seam, ordering, schema, or failure-model assumption as a previously verified fix, or when the review sequence collectively widens the slice, blast radius, or transitional-seam budget. Preserve the branch, report the review/verification run IDs and causal pattern, run no further RAS cycle, and ask the user to invoke `$architecture-handoff` for re-audit.

After a fresh review is clean, push the final candidate, run every named stress gate, and run the repository's exact-head local certification. Dispatch hosted CI only for that certified head, verify the live PR head and required result still match, and merge that exact head. Diagnose failed CI before deciding whether any rerun is legitimate. If the base advances, repeat every gate required by the repository protocol.

This step is complete only when the exact reviewed, locally certified, and hosted-verified head is merged.

## 5. Close the program loop

Run `append-dev-journal` without RAS. Ensure the child issue is closed, create review follow-up issues, and use `omnifocus-cli` to complete the exact slice task and add those follow-ups.

Recompute only the affected successors. When all of a successor's blockers are closed, apply the repository's agent-ready label, remove its OmniFocus blocked prefix, and refresh the tracking issue and program-parent current frontier without inventing ordering.

Report the PR and merge commit, validation receipt and hosted run, journal commit, issue/OmniFocus updates, newly ready slices, follow-ups, and any remaining untraced effects.

The skill is complete when the merged slice, child issue, journal, OmniFocus tree, successor readiness, and program frontier agree.
