# Templates

Use these shapes after the slice graph passes the agent's evidence audit. Keep plan docs evidence-rich; keep issues concise and link back to the plan.

## Implementation-plan doc skeleton

```markdown
# {Track Name} Implementation Plan

**Date:** {YYYY-MM-DD}
**Status:** Accepted; not yet implemented
**Track:** {n} of {N} in the {date} architecture deepening program
**Depends on:** {track/slice, or "nothing — safe to start first"}
**Related:** {settled ADRs and plans}

## Goal

{What module becomes deeper, where its interface seam lives, and what leverage/locality results.}

## Current Shape (verified {date})

{Verified facts with file:line anchors. State which original review claims did not survive grilling.}

## Decision

{Grilled interface, ownership, invariants, ordering, failure modes, and reasoning.}

**Rejected alternative (do not do this):** {Likely wrong turn and why.}

**Non-goals:** {Explicit exclusions.}

## Slice Graph

| Slice | Status/disposition | Delivers | Blocked by | Removes temporary seam |
|---|---|---|---|---|
| 1 | {new/retain/rework/replace/close} | {end-to-end behavior} | None | {seam or n/a} |

## Implementation Slices

### Slice 1 — {Title}

**What it delivers:** {Narrow, complete behavior through the real seams.}

**Existing-work disposition:** {For open PRs/branches: retain, rework, split, replace, or close, with unresolved-review and diff evidence. Otherwise "new slice."}

**Blocked by:** {Audited slice identifiers, or none.}

**Single owner after merge:** {Owner for every durable fact/transition touched.}

**Authority completeness:** {Constructors, validation, restart round trip, and destructive/security-sensitive consumers covered for newly authoritative facts.}

**Transitional-seam budget:** {Duplicate representations, generic mutations, adapters, or double opens retained; why coherent; exact removal slice. State "none" when none.}

**Blast radius:** {Shared state, concurrency/ordering, interfaces/schema, failures, performance, security, dependencies. Explicitly flag untraced effects.}

**Contract closure:** {For triggered protocol, lifecycle, multi-entrypoint, authority, environment, restoration, restart, concurrency, or security boundaries: invariant, enforcement owner, behaviorally distinct equivalence classes, dispositions, and proofs. Otherwise "not triggered" with evidence.}

**TDD and preservation proof:** {Tests written first and gates proving preserved behavior.}

**Fresh-context case:** {Why implementation, fixes, and verification fit one fresh context.}

**Slice decision audit:** {Strongest further-split and adjacent-merge alternatives; why each was rejected; evidence that every blocking edge is necessary.}

**Stop conditions:** {Code evidence that invalidates the approach and requires operator review.}

## Acceptance Criteria

- [ ] {Checkable behavioral outcome.}
- [ ] {Negative criterion proving an old seam or authority is absent where promised.}

## Validation Gates

{Exact focused tests, full suite, task runner, and platform/race gates.}

## Operating Discipline

Follow `docs/REVIEW-LOOP.md` and `docs/CONTRACT-CLOSURE.md` for every slice/PR. {Track-specific approach stop conditions and vocabulary reminders.}
```

## Program-overview doc skeleton

```markdown
# Architecture Deepening Program — {date}

**Status:** Accepted; tracks not yet implemented

## What this is

{Origin and why plan docs are the source of truth.}

## Outcomes that require no implementation

{Rejected candidates, adopted guardrails, and settled ADRs.}

## Tracks, dependencies, and frontier

| # | Track | Plan | Parent issue | Blocked by | Slices | Status |
|---|---|---|---|---|---|---|
| 1 | {name} | {plan link} | {issue or pending} | None | {count} | FRONTIER |

{Cross-track slice edges, parallel-safe work, and recommended starter.}

## Rules that bind every track

{Behavior preservation; single-owner and authority-complete invariants; transitional-seam budget; review loop; settled ADRs; vocabulary; post-merge ritual.}
```

## Parent track issue body

```markdown
Implement only through the audited child slices in **`docs/adr/{date}-{track}-plan.md`**. The plan is the source of truth and contains the grilled design. Do not dispatch this parent issue as one implementation task. If a plan assumption proves wrong, use the child skill's scoped re-audit; check with the operator only when closure changes the accepted boundary.

**Summary:** {Track outcome.}

**Rejected direction:** {Restate the likely wrong turn, when applicable.}

- Depends on: {parent/child issues or none}
- Size: {n} audited child slices/PRs
- Process: `docs/REVIEW-LOOP.md` for every child PR
- Program index: `docs/adr/{date}-architecture-deepening-program.md`

## Audited slices

- [ ] #{child} — {slice title} — blocked by {children or none}
```

## Child slice issue body

```markdown
<!-- architecture-handoff-slice:v1 -->

**Dispatch:** `$implement-architecture-slice`
**Plan commit:** `{exact 40-character docs commit SHA}`

## Parent and source of truth

- Parent: #{track issue}
- Plan: `docs/adr/{date}-{track}-plan.md` — {slice heading}

## What to build

{The narrow end-to-end behavior this slice makes work. Do not restate a layer-by-layer recipe.}

## Acceptance criteria

- [ ] {Behavioral result.}
- [ ] {Restart/failure/concurrency or negative criterion required by the slice.}
- [ ] {Preservation gate.}

## Ownership and transition budget

- Single owner after merge: {owner}
- Authority completeness: {constructors, validation, restart, and destructive/security consumers covered; or no new authoritative fact}
- Temporary seams retained: {seams, why coherent, and removal issue; or none}
- Blast radius: {traced effects and explicitly untraced effects}
- Contract closure: {matrix location and precise invariant/enforcement owner, or not triggered with evidence}
- Preservation proof: {gate for each contract intended to remain unchanged}

## Blocked by

- {Child issue links, or "None — can start immediately"}

## Stop conditions

{Evidence that invalidates the approach. Enter the scoped re-audit without widening the slice; consult the operator when closure changes topology, adjacent scope, product intent, irreversible authority, or the one-PR boundary.}
```

## Tracking issue body

```markdown
Program index: **`docs/adr/{date}-architecture-deepening-program.md`**.

## Current frontier

- [ ] #{child} — {ready slice}

## Tracks

- [ ] #{parent} — {track} ({slice count} slices; {status/blocker})

Already closed with no code: {rejections and ADRs}.

Binding rules: behavioral preservation; one mutation owner per durable fact; authority-complete slices; explicit transitional-seam removal; contract closure for triggered boundaries; `docs/REVIEW-LOOP.md` per PR.
```

## OmniFocus note shapes

Track task note:

```text
GitHub parent: {URL}
Plan: docs/adr/{date}-{track}-plan.md
{Summary}. {Dependency warning or "Independent."} {n} audited slices.
```

Slice task note:

```text
GitHub child: {URL}
Parent: {URL}
Dispatch: $implement-architecture-slice
Plan commit: {exact 40-character docs commit SHA}
Plan: docs/adr/{date}-{track}-plan.md#{slice-anchor}
Delivers: {end-to-end outcome}
Blocked by: {issues or none}
Per slice: review loop, merge, append-dev-journal, complete this task.
```

Program-parent note:

```text
Program index: docs/adr/{date}-architecture-deepening-program.md
Tracking issue: {URL}
Current frontier: {child issues}
Dispatch each frontier child to a fresh agent with $implement-architecture-slice.
```
