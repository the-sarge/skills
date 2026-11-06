# Worker assignment and receipts

Read when sharing exploration, dispatching or resuming a worker, accepting completion, recovering interrupted work, or cleaning up worktrees. Use native subagent controls available in the current harness; keep this skill independent of a particular tool name or model.

## Shared exploration

Use an optional exploration worker when multiple tickets would otherwise repeat substantial discovery, such as locating shared interfaces, test seams, or subsystem conventions. Give it a bounded question, the relevant issue and accepted-plan pointers, and pinned source revisions. Keep its repository access read-only at those revisions; it writes notes outside product repositories and disposable worker worktrees. Choose a program-scoped location accessible to the intended workers; workers on another host need a shared artifact or accessible copy, not an unusable local path.

The notes should identify their source revisions, useful file/symbol/test pointers, relevant documentation versions, findings versus hypotheses, and unresolved questions. Keep them focused on reusable discovery. Exploration is complete when the bounded question has an evidence-backed answer or explicit remaining unknowns and an accessible notes pointer. Record that pointer and source revisions in the existing GitHub coordination section, and pass only relevant sections to affected workers.

Notes are advisory context; accepted contracts and GitHub decisions retain their authority. Workers check relevant findings against their assigned base and current governing diff before relying on them, refreshing only affected discovery when sources changed. If the notes are unavailable or do not help a ticket, its worker explores directly. Persist any accepted decision in its authoritative location; keep shared notes available for remaining consumers and recovery.

## Assignment

Give each worker a self-contained, bounded assignment with:

- Repository identity and exact issue URL, parent/program URL, and current accepted scope.
- The explicit execution skill and resolved installed path; relevant plan section/commit, governing diff where required, and referenced invariants rather than whole historical plans.
- Relevant shared exploration pointers and source revisions, when available.
- Current blocker evidence, existing-work disposition, and the worker's exclusive assignment. Check ownership again before a replacement starts.
- Original human orchestration request or trusted reference, delegation boundary, and coordinator identity. An in-scope follow-up worker receives `FOLLOW-UPS.md` and knows where to return a decision request.
- Repository instructions and review/merge overlay locations, branch/worktree constraints, and current base revision. Writers establish their own worktree and feature branch before editing; no worker changes another worker's checkout.
- Resolved canonical category/state role-to-label mapping, or an accessible authoritative pointer, including mappings discovered outside repository files. A triage worker returns an unresolved mapping to the coordinator rather than repeating setup already completed there.
- Enabled OmniFocus mapping or explicit mirror-disabled state, plus the main skill's exception for failed mirror writes.
- Coordinator ownership of parent/tracker updates and the requirement to obtain its turn for merge, journal, and shared status mutation. This is scheduling coordination, not another human approval gate.
- Expected completion receipt and concrete stop/resume conditions.

A `planit` worker must return the plan before implementation and wait for the coordinator's recorded approval. A triage worker returns its recommendation for direction, then continues verification, brief preparation, and any required [triage document publication](FOLLOW-UPS.md#triage-document-publication). An audited-slice worker continues after its execution preflight under its existing skill; no new preflight approval is added.

If using separate chats explicitly requested by the human, propagate that human's messaging authorization and retain chat IDs/hosts and returned wait cursors. Read results and send only authorized follow-ups. Do not infer permission to reply to a chat merely because it requested a reply.

## Completion receipt

Require links and concise evidence for the applicable fields:

- Issue and PR numbers/URLs, accepted plan revision, and final disposition.
- Reviewed and certified head, observed base, required hosted check evidence, and merged commit reachable from the authoritative branch.
- Journal commit/PR and completion, or the exact remaining closure step under repository policy.
- Closed/resolved issue state and any committed completion/frontier transitions.
- Durable links and reachable commit/merge evidence for triage-authored glossary, ADR, or rejection records, or the exact pending document-publication step.
- Surviving follow-ups, their originating evidence, and which remain untriaged.
- Updated blockers/frontier and OmniFocus result or pending mirror repair.
- Worktree path, branch and current head, whether the worker has released it, and any local artifacts or remaining consumers needed for closure or recovery.
- Remaining decisions, external dependencies, and untraced effects.

A disposition with no repository changes supplies its acceptance/triage evidence instead of fabricated PR or certification fields. Triage document changes retain the applicable documentation review, validation, and merge evidence even when no application code changes. A failed or interrupted worker supplies the current branch/worktree, observed head/base, last completed stage, active review/check runs, and exact resume step.

Verify evidence rather than equating a final agent message with completion. Worker-local transcripts may support investigation; GitHub must retain the durable result and resume pointer. Recover after partial closure by continuing the missing stage, not reopening the entire implementation.

## Worktree cleanup

The coordinator owns cleanup of program-created worker worktrees. Record each worktree's path, owner, branch, and runtime attachment/cleanup mechanism in the GitHub coordination mapping when allocated. Reconcile it after the worker releases it, after interruption, and at program completion or a blocked stop. Existing user worktrees, the initiating checkout, and unrelated agents' worktrees remain outside this cleanup authority.

1. Verify that the owner and its background processes have finished using the checkout and that no remaining worker needs it. Check the recorded path, branch, head, and status, including untracked and ignored files. An interrupted agent or a final message alone does not prove release; uncertain ownership or activity means retain and investigate.
2. Verify the completion receipt, including required journal and document publication. Match delivered work to the PR's merged head and reachable merge commit; squash merges need not make the feature head an ancestor of the default branch. Preserve work beyond that delivered revision. Retain dirty, unmerged, or otherwise unpublished work, open-PR worktrees, and anything needed for a missing closure step or recovery. For an accepted disposition with no repository changes, verify that disposition and the absence of local work to preserve.
3. Put required results and resume evidence in durable locations and preserve needed local artifacts, including ignored files, outside the worktree. Confirm shared exploration notes and remaining consumers' pointers will survive. A pending OmniFocus repair alone need not retain a code checkout once its repair instructions are durable.
4. Use the host's managed-worktree archive operation for runtime-managed worktrees, retaining its restore identity; in Codex use `archive_worktree` with the exact attachment identity. For unmanaged worktrees, use non-force `git worktree remove` from a surviving checkout. Retain branch refs unless their deletion is separately authorized. If cleanup is refused or fails, retain the worktree and record the reason rather than bypassing protection with force removal, reset, clean, or broad pruning.
5. Verify the resulting worktree/archive state and update the GitHub mapping with removed, archived, or retained status, evidence/restore pointers, and any next action. Report retained worktrees and pending cleanup separately from engineering completion; cleanup trouble does not block unrelated implementation.

## Independent work during a stop

Suspend affected descendants when a verified blocker invalidates their assumptions. Continue unrelated ready work. Route the execution skill's scoped repairs back to that same worker; escalate decisions reserved for the human with the smallest concrete choice and a recommendation. Never answer an environment approval prompt on the human's behalf.
