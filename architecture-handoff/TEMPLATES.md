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
**Normative scope:** Current outcome, boundaries, invariants, acceptance evidence, blockers, and stop conditions
**Audit history:** {Links to review chronology, receipts, and superseded findings, or "none"}

## Goal

{What module becomes deeper, where its interface seam lives, and what leverage/locality results.}

## Current Shape (verified {date})

{Verified current facts with file:line anchors. Link historical corrections through the Audit history field instead of appending chronology here.}

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

**Artifact classification:** {Classify each material artifact as shipped behavior, required safety enforcement, verification aid, or process/traceability metadata. For any verification aid approved as a blocking maintained deliverable, state payoff, supported domain, owner, and retirement policy.}

**Representation contract:** {Supported input domain; authoritative parser/validator or enforced canonical subset; representation owner; universal/canonical-subset/example-level guarantee.}

**Contract closure:** {If material consequence and multiple independently reachable paths/states both trigger closure: invariant, enforcement owner, behaviorally distinct semantic equivalence classes, dispositions, and terminating evidence. Otherwise "not triggered" with evidence.}

**Evidence budget:** {Representative positive and materially distinct negative cases; optional one guard mutation per owner; justified platforms, repetitions, timing, hosted runs, or security-fixture cells; explicit terminating rule; one review plus at most one replacement.}

**TDD and preservation evidence:** {Tests written first and focused gates detecting regressions in preserved behavior.}

**Dispatch context budget:** {Current slice contract, referenced invariants, relevant unresolved history, governing diff if needed, and why implementation plus review fits one fresh context.}

**Slice decision audit:** {Strongest further-split and adjacent-merge alternatives; why each was rejected; evidence that every blocking edge is necessary.}

**Stop conditions:** {Code evidence that invalidates the approach and requires operator review.}

## Acceptance Criteria

- [ ] {Checkable behavioral outcome.}
- [ ] {Negative criterion showing an old seam or authority is absent where promised.}

For every criterion containing a universal quantifier, record its supported domain, representation owner, guarantee level, and finite terminating evidence.

## Validation Gates

{Exact focused tests, full suite, task runner, and risk-justified platform/race gates within the evidence budget.}

## Operating Discipline

Follow the shared review-loop and contract-closure baselines supplied by `$implement-architecture-slice` for every slice/PR, composed with any existing repository-specific `docs/REVIEW-LOOP.md` and `docs/CONTRACT-CLOSURE.md` overlays. {Track-specific approach stop conditions and vocabulary reminders.}
```

## Program-overview doc skeleton

```markdown
# Architecture Deepening Program — {date}

**Status:** Accepted; tracks not yet implemented

## What this is

{Stable program identity and why plan docs are the normative source of truth. Audit history stays behind links.}

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
Implement only through the audited child slices in **`docs/adr/{date}-{track}-plan.md`**. The plan is the source of truth and contains the current grilled design. Do not dispatch this parent issue as one implementation task. If a plan assumption proves wrong, use the child skill's scoped re-audit only while the accepted representation, outcome, and one-PR boundary remain intact; otherwise stop for a decision or rebaseline.

**Summary:** {Track outcome.}

- Depends on: {parent/child issues or none}
- Size: {n} audited child slices/PRs
- Status: {current state}
- Process: shared review-loop baseline plus any existing repository-specific `docs/REVIEW-LOOP.md` overlay for every child PR
- Program index: `docs/adr/{date}-architecture-deepening-program.md`
- Normative plan: `docs/adr/{date}-{track}-plan.md`

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
- Status: {ready/blocked/in progress/done}

The exact plan slice is the normative contract for outcome, acceptance criteria, ownership, representation, artifact classes, evidence and context budgets, preservation obligations, and stop conditions. Do not mirror those fields here.

## Blocked by

- {Child issue links, or "None — can start immediately"}

Current blocker/frontier state is administrative metadata, not exact code-head certification.
```

## Tracking issue body

```markdown
Program index: **`docs/adr/{date}-architecture-deepening-program.md`**.

## Current frontier

- [ ] #{child} — {ready slice}

## Tracks

- [ ] #{parent} — {track} ({slice count} slices; {status/blocker})

Already closed with no code: {stable identity and plan pointers}.

Binding rules: see the normative program index and track plans. This tracker contains current state and pointers only.
```

## OmniFocus note shapes

Track task note:

```text
GitHub parent: {URL}
Plan: docs/adr/{date}-{track}-plan.md
Status: {current state}
Dependencies: {warning or "Independent."}
Slices: {n}
```

Slice task note:

```text
GitHub child: {URL}
Parent: {URL}
Dispatch: $implement-architecture-slice
Plan: docs/adr/{date}-{track}-plan.md#{slice-anchor}
Status: {ready/blocked/in progress/done}
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
