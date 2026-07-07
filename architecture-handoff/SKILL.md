---
name: architecture-handoff
description: Package grilled architecture-review candidates as dispatchable work - self-contained implementation-plan docs in docs/adr/, thin GitHub issues plus a tracking issue, and a mirrored OmniFocus task tree. Use ONLY when the user explicitly invokes /architecture-handoff; do not trigger from natural-language phrases like "hand off" or from post-review context.
---

# Architecture Handoff

Package a grilled architecture review so implementing agents never re-derive
what was decided. Plan docs are the source of truth; GitHub issues are thin
dispatch pointers; OmniFocus mirrors the PR slicing. Anything that lives only
in the conversation or a temp-file report is a failure.

**Input**: an OmniFocus parent task link (`omnifocus:///task/...`). Ask if
not given. **Precondition**: candidates have been grilled. If any haven't,
self-grill first — walk each design tree, answer every question by exploring
the codebase, and make best recommendations (the user accepts them). Never
start implementation.

**Order matters**: docs → commit/push → issues → OmniFocus → report.
(Issues reference committed doc paths, so docs land first.)

**Scoped runs**: if the user names specific tracks (a revised design, or a
new track joining an existing program), run the same steps for only those
tracks — update rather than recreate the program overview, tracking issue,
and OmniFocus parent.

## Step 1 — Repo docs

One implementation-plan doc per track in `docs/adr/` (date-slug naming,
e.g. `2026-07-05-product-command-client-plan.md`), using the skeleton in
[TEMPLATES.md](TEMPLATES.md). Each doc must be self-contained:

- Grilled decisions WITH reasoning; verified facts anchored to `file:line`.
- Reversed/rejected directions explicitly marked "do not do this" — these
  are what a fresh agent gets wrong.
- Explicit non-goals and the settled ADRs/guardrails not to re-litigate.
- Dependencies on other tracks; PR slicing with TDD guidance;
  behavior-preservation gates.

Also write a program-overview doc (track table: order, dependencies, sizes;
outcomes closed with no code; binding rules) and record any CONTEXT.md terms
or ADRs the grilling crystallized that aren't captured yet (use the
domain-modeling skill).

Every doc's Operating Discipline section references `docs/REVIEW-LOOP.md`
instead of restating it. If the repo lacks that file, seed it from the
bundled [REVIEW-LOOP.md](REVIEW-LOOP.md).

Commit and push all docs before creating issues.

## Step 2 — GitHub issues

One THIN issue per track (template in [TEMPLATES.md](TEMPLATES.md)): pointer
to its plan doc as source of truth, one-paragraph summary, dependencies with
blocking issue numbers, size in PRs, "follow docs/REVIEW-LOOP.md", link to
the program index. Restate any reversed decision in the body. Then one
tracking issue: checklist of all track issues, ordering, blocked markers.

## Step 3 — OmniFocus

Under the user's parent task (use the omnifocus-cli skill):

- One task per track; per-PR subtasks under each.
- `set-group-type --sequential` on each track task so PRs unlock in order;
  tracks themselves stay parallel.
- Each track note: issue URL, plan doc path, one-line summary, dependency
  warnings. Blocked tracks get "BLOCKED by ..." in the title.
- Update the parent task's note: program index path, tracking issue URL,
  per-PR ritual (review loop → merge → append-dev-journal → complete task).

## Step 4 — Report

Deliver: the commit, all issue links, and dispatch instructions — which
tracks are parallel-safe, the recommended starter, and that each track is
dispatched to a fresh agent with the user's standard
"Make a plan to implement #N" prompt.

## Final audit

Before finishing, verify every grilled decision from the session appears in
a committed doc. If one lives only in conversation, go back and capture it.
