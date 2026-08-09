---
name: architecture-handoff
description: 'Package grilled architecture-review candidates as dispatchable programs: self-contained implementation-plan docs, evidence-gated context-sized tracer-bullet slices with blocking edges, parent/child GitHub issues, and a mirrored OmniFocus task tree. Use ONLY when the user explicitly invokes /architecture-handoff; do not trigger from natural-language phrases like "hand off" or from post-review context.'
---

# Architecture Handoff

Package a grilled architecture review so implementing agents never re-derive the design or decompose a multi-PR track themselves. Plan docs are the normative source of truth; each audited slice maps one-to-one to a child issue, intended PR, and pointer-based OmniFocus task. Anything that lives only in conversation or a temporary report is a failure.

**Input**: an OmniFocus parent task link (`omnifocus:///task/...`). Ask if not given.

**Precondition**: candidates have been grilled. If any have not, self-grill first: walk each design tree, explore the codebase, answer every technical question, and make the best evidence-backed decisions. Ask the user only when product intent, authority for an irreversible action, or mutually exclusive outcomes cannot be discovered from the code and accepted design. Never start implementation.

**Order matters**: draft current design docs, terminating evidence plans, and slice graph → agent audits slice decisions → finalize docs → publish and merge docs → resolve the exact default-branch plan commit → issues → OmniFocus → report. Issues must reference docs already merged to the default branch. Do not publish or commit a dispatch plan before the slice audit passes, and do not synchronize dispatch pointers or report a slice ready while its accepted contract exists only on an unmerged branch.

**Scoped runs**: when the user names revised or additional tracks, update only those tracks plus the existing program overview, tracking issue, and OmniFocus parent. Do not recreate the program.

**Existing work is not a baseline by default**: when a track has an open PR, implementation branch, failed review, or partial merge, fetch the issue and PR bodies/comments, inspect the diff and the history relevant to unresolved roots, and evaluate that work against the same slice gates. For repeated or approach-level findings, read and apply the shared [contract-closure reference](../_shared/CONTRACT-CLOSURE.md) to the precise invariant-and-owner root; do not extend the latest checklist. Before treating findings as one repeated root, record the required side-by-side comparison of their exact invariant, concrete central enforcement seam, semantic classes, and why the earlier accepted family had to cover the later case. A shared module, table, helper, lifecycle, or broad authority topic is not enough. Never grandfather unmerged work as an "established baseline." If it violates a gate, choose and document rework, split, replacement, or closure; do not let later slices depend on it.

## Step 1 — Capture the grilled design

Draft one implementation-plan doc per track in `docs/adr/` using [TEMPLATES.md](TEMPLATES.md). Each plan must contain:

- Grilled decisions with reasoning and verified facts anchored to `file:line`.
- Reversed/rejected directions explicitly marked "do not do this."
- Non-goals and settled ADRs/guardrails not to re-litigate.
- Track dependencies, behavioral-preservation gates, approach-level stop conditions, artifact classifications, representation contracts, evidence budgets, and any contract-closure matrix required by the risk triggers below.
- The slice graph from Step 2; do not finalize or commit it before the agent audit passes.
- The disposition of existing work: retain, re-slice, replace, or close, with evidence.
- A context budget for each slice: the exact current slice contract, referenced invariants, relevant unresolved history, and bounded governing diff an implementer must receive.

Keep each plan normative and current: outcome, boundaries, invariants, acceptance evidence, blockers, and stop conditions only. Put review chronology, run IDs, historical candidate SHAs, verification receipts, and superseded findings in linked audit artifacts or PR discussion. Also draft or update the pointer-based program-overview doc and record any new domain terms or ADRs through the domain-modeling skill.

Every plan's Operating Discipline section states that the shared [review-loop](../_shared/REVIEW-LOOP.md) and [contract-closure](../_shared/CONTRACT-CLOSURE.md) baselines govern, then references any repository-specific overlays. Use the shared baselines directly when no overlay exists; do not seed or synchronize repository copies. Create or update `docs/REVIEW-LOOP.md` or `docs/CONTRACT-CLOSURE.md` only for explicit additions or stronger repository-specific boundary, certification, CI, merge, journal, tracking, or routing rules, and keep those overlays limited to the differences. Verify the composed policy covers representation and artifact gates, finite evidence and review budgets, semantic-family closure, review-and-verification-aware approach stops, exact-head local certification, same-head hosted CI, merge, journal, pointer-based tracking, and diagnosis before reruns.

## Step 2 — Design and audit tracer-bullet slices

Decompose each track before publishing it. A slice is one intended PR and one fresh implementation-agent context. Prefer prefactoring that makes the vertical change easy, then the vertical change.

Audit any existing or in-progress slice first. Include unresolved review findings and behavioral regressions in the audit. A green historical test run or a large amount of completed code does not exempt the slice from the gates below.

Every slice must satisfy all of these rules:

- **Vertical and complete**: deliver one narrow behavior through the real module interface, persistence/adapter seams, callers, and tests that the behavior actually crosses. Do not create a horizontal "complete schema/model now, operations later" slice.
- **Independently green**: merge without relying on an unmerged successor. State exactly how the slice is demonstrated or verified.
- **Context-sized**: declare a bounded dispatch context and fit implementation, local review fixes, and verification inside it. Split again if that claim is doubtful; never require two complete historical plan versions when the current slice plus a governing diff is sufficient.
- **Explicitly ordered**: name only genuine blocking slices. A slice with no blockers belongs on the implementation frontier.
- **TDD-shaped**: name the failing or characterization tests written first, including restart, failure, or concurrency tests where the behavior crosses those seams, and keep their count inside the declared evidence budget.
- **Smallest blast radius**: trace effects beyond the immediate goal across shared/global state, concurrency and ordering, public interfaces and schemas, failure modes, performance, security, and dependencies. Flag every effect not fully traced.

Apply these architecture-specific gates:

- **Single-owner invariant**: after the slice, each durable fact and lifecycle transition has one mutation owner. A compatibility adapter may translate, but it must not become a second state machine.
- **Authority-complete invariant**: do not make a persisted fact authoritative unless the same slice covers its constructors, validation, restart round trip, and every destructive or security-sensitive consumer that relies on it.
- **Transitional-seam budget**: list every duplicate representation, generic mutation path, temporary adapter, or double-open lifetime left after the slice. Explain why the intermediate state is coherent and identify the exact blocking slice that removes it. A slice may not widen a transitional seam.
- **Artifact classification**: apply the shared classification and blocking policy, then record each artifact and any approved maintained-aid exception in the plan.
- **Behavior-preservation evidence**: distinguish unchanged behavior from intended architectural change and name the gate that detects each relevant regression. Keep mutations and harness obligations within the shared evidence and non-recursion budgets.

Apply the shared [contract-closure policy](../_shared/CONTRACT-CLOSURE.md) without restating or strengthening its triggers, representation gate, semantic-family rules, or evidence budgets. Record its required contract fields and any triggered semantic matrix using the plan template.

Apply the shared representation gate to every universal acceptance criterion. A plan routed to `stop-for-decision` is not dispatchable.

Record any approved exception to the shared mutation or operational evidence budgets with its contract basis.

Treat a genuinely wide mechanical refactor as expand–migrate–contract instead of forcing it into a tracer bullet. The expand step must be behaviorally inert and must not grant authority to the new form. Migrate in independently green batches sized by blast radius. Block contract/deletion on every migration batch. Use an integration branch only when no batch can remain green alone, and make the final integrate-and-verify slice explicit.

If a slice cannot satisfy these rules without moving a non-goal, leaving two mutation owners, or depending on untraced future behavior, stop and return to grilling. That is an approach-level failure, not permission to make the slice larger.

Before committing docs, write the proposed slice graph and audit each numbered slice with:

- Title.
- Blocked by.
- What it delivers end to end.
- Single owner after merge.
- Temporary seams introduced or retained, and their removal slice.
- Blast radius and untraced effects.
- Artifact classes and any explicitly approved maintained verification aid.
- Representation domain, owner, guarantee level, and terminating evidence budget.
- Why it fits its declared fresh-context budget.
- Existing-work disposition when applicable: retain, rework, split, replace, or close.
- The strongest case for splitting it further and the strongest case for merging it with an adjacent slice.
- The evidence that its blocking edges are necessary rather than convenient ordering.

Judge the graph yourself. Split when context fit, ownership, authority completeness, or blast-radius tracing is doubtful; bias toward the smaller independently green slice. Merge only when neither candidate can deliver a coherent behavior alone and the merged slice still fits one fresh context. Remove convenience-only blocking edges. Record rejected split/merge alternatives briefly in the plan so later agents do not repeat the debate.

Do not ask the user to judge technical granularity, ownership seams, or dependency edges. Escalate only when the audit exposes an unresolved product choice, requires authority for an irreversible external action, or proves an accepted architectural decision cannot work. Otherwise make the best decision and proceed.

### Legacy-program rebaseline

When a scoped run updates a program created under older proof-oriented rules, execute the [shared legacy-program rebaseline](../_shared/CONTRACT-CLOSURE.md#keep-contracts-and-tracking-bounded) before designing new slices. Applying it to that program requires the user's scoped handoff request; do not silently rebaseline unrelated tracks.

## Step 3 — Finalize, publish, and merge repo docs

Finalize one current plan per track plus the program overview using [TEMPLATES.md](TEMPLATES.md). The program overview records stable track identity, plan pointers, slice-level blocking edges that cross tracks, parallel-safe frontiers, sizes, outcomes closed with no code, and binding rules. It does not mirror substantive slice contracts or audit history.

Audit the docs, then commit and push them on a dedicated branch. Publish and merge that branch through the repository's authorized docs path before creating or updating issues and task-manager mirrors. Satisfy the repository's required review, validation, hosted-CI, and merge gates for docs; do not substitute an unmerged branch, open PR, or successful branch check for default-branch publication.

After the merge, fetch the default branch and identify the exact 40-character commit whose tree contains the accepted plan. Verify that the commit is reachable from the current remote default branch and that the plan and program-index contents there match the audited contract. For a squash merge, record the resulting default-branch squash commit rather than the unreachable source-branch commit. For a merge or rebase strategy, still verify reachability instead of assuming it. This verified default-branch commit is the plan commit used by child issues and dispatch reporting.

Use `pending` for issue-link fields that cannot exist before publication; do not create another authoritative plan commit solely to backfill those links because the issues and program tracker own the live mapping. If the docs cannot be merged or the accepted contract cannot be verified on the default branch, stop before synchronizing issue pointers, readiness labels, or OmniFocus state and report that the handoff is not dispatchable.

## Step 4 — Publish GitHub issues

Create one thin **parent track issue** per track. It points to the plan doc as source of truth and records stable identity, current state, track-level dependencies, the program index, and child pointers. Do not copy the contract or audit history into it, and do not dispatch the parent issue for implementation.

Create or update exactly one **child issue per audited slice** using [TEMPLATES.md](TEMPLATES.md). Re-auditing existing work updates its existing child unless the audited disposition explicitly replaces or splits that contract:

- Start with the stable `<!-- architecture-handoff-slice:v1 -->` marker, name `$implement-architecture-slice` as the dispatch skill, and record the exact 40-character default-branch commit from Step 3 containing the accepted plan. Never record an unmerged source-branch commit.
- Link the parent track issue and source plan.
- Record stable slice identity and current state; keep the end-to-end delivery, acceptance criteria, representation contract, artifact classification, evidence budget, and stop conditions in the exact plan slice.
- Record blocking child issues using native relationships when available, otherwise explicit links.
- Apply the repo's agent-ready label only to frontier issues whose blockers are complete. Do not label blocked work ready.

Then create or update one tracking issue for the program. It contains stable parent identities, blocked markers, the current frontier, and a program-index pointer. Child contracts and audit narratives remain in the plan and linked history.

## Step 5 — Mirror OmniFocus

Use the omnifocus-cli skill under the user's parent task:

- Create one task per track and one subtask per child slice/intended PR. Include the child issue URL in each slice task.
- Use `set-group-type --sequential` only for a genuinely linear track. Preserve parallel-safe work; do not invent ordering that is absent from the slice graph.
- Prefix blocked slice titles with `BLOCKED by ...`; notes contain stable identity, current state, blockers, child and parent issue pointers, the dispatch skill, and the normative plan pointer. Do not copy the contract, audit narrative, or exact plan SHA into task-manager mirrors.
- Track notes contain the parent issue and plan pointers, current state, dependency warnings, and slice count.
- Update the program-parent note with the program index, tracking issue, current frontier, and per-slice ritual: review loop → merge → append-dev-journal → complete slice task.

## Step 6 — Report dispatch instructions

Deliver the merged default-branch plan commit, docs PR and merge receipt, tracking issue, all parent/child issue links, OmniFocus mapping, current frontier, and parallel-safe work.

Immediately before reporting dispatch instructions, fetch the remote default branch again and verify that every frontier child's recorded plan commit remains reachable and its exact plan slice is present there. Dispatch each verified frontier child issue to a fresh agent with `$implement-architecture-slice`. That skill emits an execution preflight, implements the accepted contract, and performs same-child scoped re-audits without operator routing only while the representation contract, accepted outcome, and one-PR boundary remain intact. It stops for a decision or asks for `$architecture-handoff` when representation ownership, topology, adjacent scope, product intent, irreversible authority, or the one-PR boundary changes. Clear context between child issues. A child whose plan commit is not reachable from the current remote default branch is not dispatchable even if its branch was pushed or its docs PR is open.

## Final audit

Before finishing, verify:

- Every grilled decision appears in a plan merged to the current remote default branch.
- Every audited slice maps exactly once to a plan contract, child issue, intended PR, and OmniFocus task.
- Every child issue carries the stable marker, dispatch skill, and exact default-branch plan commit required by `$implement-architecture-slice`; that commit is reachable from the current remote default branch and contains the accepted slice contract.
- Every material artifact is classified, and no verification aid blocks shipped behavior without explicit maintained-deliverable approval, payoff, domain, owner, and retirement policy.
- Every universal criterion declares its supported domain, representation owner, guarantee level, and finite terminating evidence.
- Every triggered contract-closure matrix maps its precise invariant, representation and enforcement owners, behaviorally distinct semantic classes, dispositions, and budgeted evidence into the committed plan.
- Every repeated-root conclusion includes the shared side-by-side precise-root comparison; no conclusion relies only on a common module, table, helper, lifecycle, or broad architectural topic.
- Every unmerged existing slice was re-evaluated against the current gates; none was silently treated as an established dependency.
- Every durable fact and transition has one named mutation owner after each slice.
- Every newly authoritative persisted fact has constructor, validation, restart, and destructive-consumer coverage in the same slice.
- Every transitional seam has a coherent intermediate contract and a blocking removal slice.
- Every dispatchable slice has a bounded context budget, and audit history is linked rather than appended to its normative contract.
- All blocking edges are genuine, all frontier labels are correct, and no blocked work is presented as ready.
- Parent issues, program trackers, and OmniFocus notes contain current state and pointers rather than mirrored substantive contracts, and exact code-head certification is not conflated with administrative plan or mirror state.
- No untraced blast-radius effect is silently accepted.

If any check fails, return to the slice-design gate before publishing or dispatching work.
