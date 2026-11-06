---
name: orchestrate-architecture-program
description: Coordinates an audited architecture program through fresh implementation agents, delegated follow-up triage, and approval of in-scope follow-up plans. Use when the user wants a program or parent issue executed with minimal intervention, or wants to resume that orchestration. Single-ticket execution belongs to implement-architecture-slice or planit.
---

# Orchestrate Architecture Program

Own scheduling, delegated decisions, and reconciliation for an existing audited program. Dispatch fresh workers for individual issues and keep advancing eligible work until the authorized scope is complete or only genuine blockers remain.

## Authority and source of truth

A human request to run this workflow for an identified program delegates routine follow-up triage direction and approval of concrete, in-scope `planit` plans to the orchestrator under [FOLLOW-UPS.md](FOLLOW-UPS.md). It authorizes worker delegation and the program's established implementation, review, merge, journal, issue, and mirror workflow. Creating, reviewing, or discussing this skill does not start a program. Preserve any narrower user instruction.

GitHub issues are authoritative for program membership, dependencies, current state, decisions, follow-ups, and execution receipts. Follow their links to the accepted committed plans for substantive slice contracts; preserve those contracts in their existing authoritative location. An issue edit cannot silently replace an accepted contract or grant execution permissions. Reconcile contradictions before dispatching the affected work.

OmniFocus is an optional convenience mirror. Its availability, ordering, labels, and completion state never establish GitHub readiness or completion. Apply the mirror policy below throughout delegated skills, including when those skills ordinarily require an OmniFocus step.

## 1. Resolve the program

Accept a GitHub program/parent issue or an OmniFocus task pointing to one. Resolve an OmniFocus input through `omnifocus-cli`, then operate from the linked GitHub issue. If that initial resolution is unavailable, request the GitHub link; independent discovery may continue. Discover repository identity, default branch, instruction files, issue conventions, readiness labels, and review/merge overlays rather than assuming a host path, branch name, CI job name, or label mapping.

Read the parent/tracker, relevant children and comments, native blocking relationships or their documented fallback, accepted plan pointers, and current implementation frontier. Inspect existing PRs, branches, worker claims, and receipts before starting work. A closed blocker counts as satisfied only when its disposition fulfills the required dependency; a closed-as-rejected issue is not evidence that its code shipped.

Locate `implement-architecture-slice`, `triage`, and `planit` in the installed skill catalog or configured skill roots. `triage` may be supplied by a separate skills package. Resolve each skill's dependencies when its route is needed; a missing route blocks only work requiring it. Read the shared review and contract-closure baselines before making delegated technical approval decisions, composing repository overlays without copying their rules here.

Record a compact coordination section on the existing GitHub parent/tracker: authorized scope and human delegation source, current frontier, active issue-to-worker/worktree/PR mapping, pending decisions, follow-up dispositions, and mirror repairs. Keep contracts and review history behind links. Update this section in place; use linked receipts for history. Do not create another tracker when one already serves this purpose.

This step is complete when each candidate has one authoritative issue, a resolved contract or triage route, known blockers, and no competing active owner.

## 2. Select and dispatch work

Use these routes, checking the issue's marker before its labels:

| Work | Route |
| --- | --- |
| Frontier child with `architecture-handoff-slice:v1` | `implement-architecture-slice`; one child and one fresh worker context |
| Surviving follow-up requiring classification or a brief | `triage`, using [FOLLOW-UPS.md](FOLLOW-UPS.md) |
| Standalone follow-up ready for an agent | `planit`, with a concrete plan returned for delegated approval before implementation |
| Parent/tracker with no accepted child contracts | Prepare the missing-contract report and recommend `architecture-handoff`; do not treat the parent as one implementation ticket |
| Work requiring a reserved human decision | Record the decision needed and continue independent work |

When several tickets need the same discovery, consider [shared exploration](WORKERS.md#shared-exploration) before or alongside dispatch. Skip it when accepted plans and existing context already suffice; independent ready work can proceed while exploration runs.

Claim only eligible, unowned work and persist the assignment before implementation. Re-read the live issue and claim immediately before dispatch; if another agent owns it, coordinate or select another item. Resume an owned worker for its current issue; use a fresh context for a different issue. Supply the bounded [worker assignment](WORKERS.md), including the original human delegation and the exact skill to read.

Use subagents by default. Separate user-owned chats require an explicit human request and messaging authorization; an orchestrator message alone does not grant a worker permission to message another chat. With no delegation capability, report that limitation and offer sequential execution rather than silently substituting it.

Parallelize only dependency-independent work with compatible write scopes. Each repository-writing agent owns its own feature branch and worktree under the applicable repository/user rules; the initiating checkout stays read-only. Read-only workers use pinned revisions. Serialize merge, journal, and shared status mutation within each repository, granting one worker that responsibility at a time. Re-read the live head and base and repeat the checks required by the execution skill after another merge advances the base.

Use existing runtime capacity and accepted slice/review budgets. Preserve the configured RAS panel. Do not create new time, token, retry, or review budgets merely to orchestrate. Distinguish normal host activity from a failed worker using progress evidence; overall CPU usage alone is insufficient.

## 3. Supervise and reconcile

Stay active while owned workers run. Use the harness's result/wait controls and resume workers with precise remaining work. When only hosted checks remain, use the applicable authorized CI watcher policy with one watcher owner per head; workers and coordinator must not duplicate watchers. Diagnose failures under the execution skill before reruns.

Workers own their complete execution workflow, including review, validation, merge, journal, and issue updates. The coordinator owns the parent/tracker and scheduling. Reconcile overlapping administrative updates serially; product PRs retain ownership of committed frontier/completion changes required by their contracts.

Verify each [completion receipt](WORKERS.md#completion-receipt) against GitHub and the relevant repository. Distinguish code merged, journal pending, tracker pending, and fully reconciled. Complete remaining closure work without repeating an already merged implementation. Only then advance successors whose actual dependencies are satisfied; optional mirror repair is handled separately below.

After verified closure, perform [worktree cleanup](WORKERS.md#worktree-cleanup) for released worker worktrees and record what was removed, archived, or retained. Preserve work needed for recovery or remaining consumers.

Revalidate deferred findings against the merged head before filing or scheduling follow-ups. Read [FOLLOW-UPS.md](FOLLOW-UPS.md) for triage, delegated approval, scheduling, and recursive follow-up handling. New findings do not automatically enlarge the program or block its successors.

After each meaningful transition, update the GitHub coordination section and enabled mirrors. Report merged outcomes, material changes to the frontier, and decisions needed. Keep routine waiting quiet and include visible issue/PR numbers in every reference.

## OmniFocus mirror policy

Enable mirroring when the user requests it, supplies an OmniFocus program task, or the program already has an established mirror. With no established destination, keep GitHub work moving and request one only if mirroring is wanted. An explicitly disabled mirror stays disabled.

Use `omnifocus-cli`, read before writing, and match tasks by their GitHub issue links and recorded IDs. Preserve unrelated user notes and task state. Mirror each issue change: current state, blocker warnings, issue/parent/plan pointers, and completion after verified closure. Contracts, approvals, and readiness remain in GitHub and its accepted plan references.

On unavailable OmniFocus or a failed/partial update, record the affected issue, task ID if known, and pending operation in the GitHub coordination section. Read actual state before retrying after recovery. A mirror failure neither undoes GitHub progress nor prevents independent dispatch or engineering completion. Report outstanding mirror repairs explicitly; never describe failed synchronization as complete. This policy is the orchestration-specific exception to downstream skills' unconditional OmniFocus closure steps.

## Resume, decisions, and completion

After interruption, reconstruct state from GitHub and verify live worker, PR, head/base, journal, and mirror state. Treat recorded worker IDs as hints until checked. Reuse completed work and accepted approvals only if their exact scope and plan revision still match; an interrupted worker does not by itself justify redispatch. Resolve ownership before replacing it.

Escalate only affected work when product intent, representation/authority, adjacent slice scope, an accepted PR boundary, release/publication authority, external evidence, or an explicit owner-only decision is unresolved. Preserve useful branches and receipts. Same-child scoped re-audits remain with `implement-architecture-slice` when that skill authorizes them; a true architecture-handoff stop stays a human decision. Routine triage and in-scope follow-up plan approval follow the delegated path.

When authorized work is exhausted, reconcile the parent with fulfilled acceptance criteria and every child's disposition. Required external qualification or a conditional outcome awaiting evidence remains pending. Authorized in-scope follow-ups must be completed or explicitly dispositioned; unrelated improvements do not make the program endless. Reconcile every recorded worker worktree under the cleanup procedure, including on a blocked stop. Report engineering completion separately from retained worktrees, pending cleanup, and remaining mirror repair.

If only blocked work remains, persist exact resume conditions and report the smallest concrete decision or external event needed, with a recommendation. Do not mark incomplete work complete, claim an active watcher after the session ends, or imply automatic restart recovery. No scheduled automation is needed to watch this program.
