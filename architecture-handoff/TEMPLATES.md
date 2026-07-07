# Templates

Exemplars from the first run (SwarmCast repo, 2026-07-05):
`docs/adr/2026-07-05-architecture-deepening-program.md`, the five
`2026-07-05-*-plan.md` docs beside it, and issues #211–#216.

## Implementation-plan doc skeleton

```markdown
# {Track Name} Implementation Plan

**Date:** {YYYY-MM-DD}
**Status:** Accepted; not yet implemented
**Track:** {n} of {N} in the {date} architecture deepening program
**Depends on:** {other track + which PR, or "nothing — safe to start first"}
**Related:** {ADRs this track must honor, if any}

## Goal

{One paragraph: the deepening in CONTEXT.md vocabulary — what module gets
deep, what interface shrinks, what leverage/locality is gained.}

## Current Shape (verified {date})

{Verified facts with file:line anchors. Include LOC where it matters.
If grilling narrowed or corrected the original review finding, say so
explicitly here — implementing agents must know the review claim that did
NOT survive.}

## Decision

{The grilled design: interface shape, what moves vs stays, load-bearing
rules from grilling. Mark reversed/rejected directions:
"**Rejected alternative (do not do this):** ..." Non-goals last.}

## Implementation Slices

{Numbered PRs. Each: scope, TDD guidance (which tests to write/pin first),
what proves behavior preservation. Note which PR unblocks dependent tracks.}

## Acceptance Criteria

{Bullet list, checkable, including negative criteria ("grep for X returns
nothing", "no bare literals remain").}

## Validation Gates

{Exact commands: focused package tests, full suite, repo task runner.}

## Operating Discipline

Follow `docs/REVIEW-LOOP.md` for every PR. {Track-specific stop conditions:
"If X proves wrong, STOP and check with the operator — that is an
approach-level finding." Vocabulary reminders.}
```

## Program-overview doc skeleton

```markdown
# Architecture Deepening Program — {date}

**Status:** Accepted; tracks not yet implemented

## What this is
{Origin: review + grilling. Point of the doc: program index; each track's
plan doc carries full context so no agent re-derives decisions.}

## Outcomes that require no implementation
{Candidates rejected/closed with their ADRs; guardrails adopted instead of
refactors; vocabulary already committed.}

## Tracks, in recommended order
| # | Track | Plan doc | Depends on | Size |
{...}
{Which tracks are parallel-safe; which is the recommended starter.}

## Rules that bind every track
{Behavior preservation gates; docs/REVIEW-LOOP.md; settled ADRs not to
re-litigate; vocabulary discipline; post-merge ritual.}
```

## Track issue body

```markdown
Implement the plan in **`docs/adr/{date}-{track}-plan.md`** — the plan doc
is the source of truth and contains the full grilled design. Do not
re-derive design decisions; if a plan assumption proves wrong in code, stop
and check with the operator.

{If the plan records a reversed decision, restate it here: the naive
reading an agent would reach, and why it was rejected.}

**Summary:** {one paragraph}

- Depends on: {issue #s + which PR, or "nothing"}
- Size: {n} PRs
- Process: follow `docs/REVIEW-LOOP.md` for every PR.
- Program index: `docs/adr/{date}-architecture-deepening-program.md`
```

## Tracking issue body

```markdown
Program index: **`docs/adr/{date}-architecture-deepening-program.md`**.

Recommended order ({which} parallel-safe; {which} blocked):

- [ ] #{n} Track 1 — {name} (starter)
- [ ] #{n} Track 2 — {name} ⚠️ blocked by #{m} (PR {k})
{...}

Already closed with no code: {rejections + their ADRs}.

Binding rules for all tracks: behavioral preservation is the hard gate;
`docs/REVIEW-LOOP.md` per PR; do not re-litigate {settled ADRs}.
```

## OmniFocus note shapes

Track task note:

```text
GitHub: {issue URL}
Plan: docs/adr/{date}-{track}-plan.md
{One-line summary}. {Dependency warning or "Independent."} {n} PRs.
```

Parent task note:

```text
Program index: docs/adr/{date}-architecture-deepening-program.md
Tracking issue: {URL}
{Parallel/blocked summary}. Per PR: review loop per docs/REVIEW-LOOP.md,
merge, append-dev-journal, complete OmniFocus task.
```
