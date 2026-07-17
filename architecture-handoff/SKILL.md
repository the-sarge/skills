---
name: architecture-handoff
description: 'Package grilled architecture-review candidates as dispatchable programs: self-contained implementation-plan docs, evidence-gated context-sized tracer-bullet slices with blocking edges, parent/child GitHub issues, and a mirrored OmniFocus task tree. Use ONLY when the user explicitly invokes /architecture-handoff; do not trigger from natural-language phrases like "hand off" or from post-review context.'
---

# Architecture Handoff

Package a grilled architecture review so implementing agents never re-derive the design or decompose a multi-PR track themselves. Plan docs are the source of truth; each audited slice maps one-to-one to a child issue, intended PR, and OmniFocus task. Anything that lives only in conversation or a temporary report is a failure.

**Input**: an OmniFocus parent task link (`omnifocus:///task/...`). Ask if not given.

**Precondition**: candidates have been grilled. If any have not, self-grill first: walk each design tree, explore the codebase, answer every technical question, and make the best evidence-backed decisions. Ask the user only when product intent, authority for an irreversible action, or mutually exclusive outcomes cannot be discovered from the code and accepted design. Never start implementation.

**Order matters**: draft design docs and slice graph → agent audits slice decisions → finalize docs → commit/push → issues → OmniFocus → report. Issues must reference committed docs. Do not publish or commit a dispatch plan before the slice audit passes.

**Scoped runs**: when the user names revised or additional tracks, update only those tracks plus the existing program overview, tracking issue, and OmniFocus parent. Do not recreate the program.

**Existing work is not a baseline by default**: when a track has an open PR, implementation branch, failed review, or partial merge, fetch the issue and PR bodies/comments, inspect the diff and unresolved findings, and evaluate that work against the same slice gates. Never grandfather unmerged work as an "established baseline." If it violates a gate, choose and document rework, split, replacement, or closure; do not let later slices depend on it.

## Step 1 — Capture the grilled design

Draft one implementation-plan doc per track in `docs/adr/` using [TEMPLATES.md](TEMPLATES.md). Each plan must contain:

- Grilled decisions with reasoning and verified facts anchored to `file:line`.
- Reversed/rejected directions explicitly marked "do not do this."
- Non-goals and settled ADRs/guardrails not to re-litigate.
- Track dependencies, behavioral-preservation gates, and approach-level stop conditions.
- The slice graph from Step 2; do not finalize or commit it before the agent audit passes.
- The disposition of existing work: retain, re-slice, replace, or close, with evidence.

Also draft or update the program-overview doc and record any new domain terms or ADRs through the domain-modeling skill.

Every plan's Operating Discipline section references `docs/REVIEW-LOOP.md`. If the repo lacks it, seed it from the bundled [REVIEW-LOOP.md](REVIEW-LOOP.md). If it exists, verify it covers the manual review/fix/verify loop, history-aware approach stops, exact-head local certification, same-head hosted CI, merge, journal, OmniFocus, and diagnosis before reruns; update stale protocol text with the implementation-plan docs.

## Step 2 — Design and audit tracer-bullet slices

Decompose each track before publishing it. A slice is one intended PR and one fresh implementation-agent context. Prefer prefactoring that makes the vertical change easy, then the vertical change.

Audit any existing or in-progress slice first. Include unresolved review findings and behavioral regressions in the audit. A green historical test run or a large amount of completed code does not exempt the slice from the gates below.

Every slice must satisfy all of these rules:

- **Vertical and complete**: deliver one narrow behavior through the real module interface, persistence/adapter seams, callers, and tests that the behavior actually crosses. Do not create a horizontal "complete schema/model now, operations later" slice.
- **Independently green**: merge without relying on an unmerged successor. State exactly how the slice is demonstrated or verified.
- **Context-sized**: fit implementation, local review fixes, and verification in one fresh context window. Split again if that claim is doubtful.
- **Explicitly ordered**: name only genuine blocking slices. A slice with no blockers belongs on the implementation frontier.
- **TDD-shaped**: name the failing or characterization tests written first, including restart, failure, or concurrency tests where the behavior crosses those seams.
- **Smallest blast radius**: trace effects beyond the immediate goal across shared/global state, concurrency and ordering, public interfaces and schemas, failure modes, performance, security, and dependencies. Flag every effect not fully traced.

Apply these architecture-specific gates:

- **Single-owner invariant**: after the slice, each durable fact and lifecycle transition has one mutation owner. A compatibility adapter may translate, but it must not become a second state machine.
- **Authority-complete invariant**: do not make a persisted fact authoritative unless the same slice covers its constructors, validation, restart round trip, and every destructive or security-sensitive consumer that relies on it.
- **Transitional-seam budget**: list every duplicate representation, generic mutation path, temporary adapter, or double-open lifetime left after the slice. Explain why the intermediate state is coherent and identify the exact blocking slice that removes it. A slice may not widen a transitional seam.
- **Behavior-preservation proof**: distinguish unchanged behavior from intended architectural change and name the gate that proves each preserved contract.

Treat a genuinely wide mechanical refactor as expand–migrate–contract instead of forcing it into a tracer bullet. The expand step must be behaviorally inert and must not grant authority to the new form. Migrate in independently green batches sized by blast radius. Block contract/deletion on every migration batch. Use an integration branch only when no batch can remain green alone, and make the final integrate-and-verify slice explicit.

If a slice cannot satisfy these rules without moving a non-goal, leaving two mutation owners, or depending on untraced future behavior, stop and return to grilling. That is an approach-level failure, not permission to make the slice larger.

Before committing docs, write the proposed slice graph and audit each numbered slice with:

- Title.
- Blocked by.
- What it delivers end to end.
- Single owner after merge.
- Temporary seams introduced or retained, and their removal slice.
- Blast radius and untraced effects.
- Why it fits one fresh context.
- Existing-work disposition when applicable: retain, rework, split, replace, or close.
- The strongest case for splitting it further and the strongest case for merging it with an adjacent slice.
- The evidence that its blocking edges are necessary rather than convenient ordering.

Judge the graph yourself. Split when context fit, ownership, authority completeness, or blast-radius tracing is doubtful; bias toward the smaller independently green slice. Merge only when neither candidate can deliver a coherent behavior alone and the merged slice still fits one fresh context. Remove convenience-only blocking edges. Record rejected split/merge alternatives briefly in the plan so later agents do not repeat the debate.

Do not ask the user to judge technical granularity, ownership seams, or dependency edges. Escalate only when the audit exposes an unresolved product choice, requires authority for an irreversible external action, or proves an accepted architectural decision cannot work. Otherwise make the best decision and proceed.

## Step 3 — Finalize and commit repo docs

Finalize one plan per track plus the program overview using [TEMPLATES.md](TEMPLATES.md). The program overview records track order, slice-level blocking edges that cross tracks, parallel-safe frontiers, sizes, outcomes closed with no code, and binding rules.

Audit the docs, then commit and push them before creating issues.

## Step 4 — Publish GitHub issues

Create one thin **parent track issue** per track. It points to the plan doc as source of truth, summarizes the track, names track-level dependencies, links the program index, restates reversed decisions, and lists its audited child slices. Do not dispatch the parent issue for implementation.

Create one **child issue per audited slice** using [TEMPLATES.md](TEMPLATES.md):

- Start with the stable `<!-- architecture-handoff-slice:v1 -->` marker, name `$implement-architecture-slice` as the dispatch skill, and record the exact 40-character docs commit containing the accepted plan.
- Link the parent track issue and source plan.
- Describe the end-to-end delivery and acceptance criteria, not a layer-by-layer implementation recipe.
- Record blocking child issues using native relationships when available, otherwise explicit links.
- Restate the slice's owner, authority-completeness obligations, transitional-seam budget, blast radius, preservation proof, and stop condition.
- Apply the repo's agent-ready label only to frontier issues whose blockers are complete. Do not label blocked work ready.

Then create or update one tracking issue for the program. It tracks parent issues, recommended order, blocked markers, and the current frontier; child details remain on the parent and in the plan.

## Step 5 — Mirror OmniFocus

Use the omnifocus-cli skill under the user's parent task:

- Create one task per track and one subtask per child slice/intended PR. Include the child issue URL in each slice task.
- Use `set-group-type --sequential` only for a genuinely linear track. Preserve parallel-safe work; do not invent ordering that is absent from the slice graph.
- Prefix blocked slice titles with `BLOCKED by ...`; notes include the dispatch skill, plan commit, parent issue, child issue, plan path, delivery, and blockers.
- Track notes include the parent issue, plan path, summary, dependency warnings, and slice count.
- Update the program-parent note with the program index, tracking issue, current frontier, and per-slice ritual: review loop → merge → append-dev-journal → complete slice task.

## Step 6 — Report dispatch instructions

Deliver the docs commit, tracking issue, all parent/child issue links, OmniFocus mapping, current frontier, and parallel-safe work.

Dispatch each frontier child issue to a fresh agent with `$implement-architecture-slice`. That skill emits an execution preflight and implements the accepted contract; it stops on approach-level failures and asks the user to invoke `$architecture-handoff` for re-audit. Clear context between child issues.

## Final audit

Before finishing, verify:

- Every grilled decision appears in a committed plan.
- Every audited slice maps exactly once to a plan contract, child issue, intended PR, and OmniFocus task.
- Every child issue carries the stable marker, dispatch skill, and exact plan commit required by `$implement-architecture-slice`.
- Every unmerged existing slice was re-evaluated against the current gates; none was silently treated as an established dependency.
- Every durable fact and transition has one named mutation owner after each slice.
- Every newly authoritative persisted fact has constructor, validation, restart, and destructive-consumer coverage in the same slice.
- Every transitional seam has a coherent intermediate contract and a blocking removal slice.
- All blocking edges are genuine, all frontier labels are correct, and no blocked work is presented as ready.
- No untraced blast-radius effect is silently accepted.

If any check fails, return to the slice-design gate before publishing or dispatching work.
