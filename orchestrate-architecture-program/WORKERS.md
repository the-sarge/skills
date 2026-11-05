# Worker assignment and receipts

Read when dispatching or resuming a worker, accepting completion, or recovering interrupted work. Use native subagent controls available in the current harness; keep this skill independent of a particular tool name or model.

## Assignment

Give each worker a self-contained, bounded assignment with:

- Repository identity and exact issue URL, parent/program URL, and current accepted scope.
- The explicit execution skill and resolved installed path; relevant plan section/commit, governing diff where required, and referenced invariants rather than whole historical plans.
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
- Remaining decisions, external dependencies, and untraced effects.

A disposition with no repository changes supplies its acceptance/triage evidence instead of fabricated PR or certification fields. Triage document changes retain the applicable documentation review, validation, and merge evidence even when no application code changes. A failed or interrupted worker supplies the current branch/worktree, observed head/base, last completed stage, active review/check runs, and exact resume step.

Verify evidence rather than equating a final agent message with completion. Worker-local transcripts may support investigation; GitHub must retain the durable result and resume pointer. Recover after partial closure by continuing the missing stage, not reopening the entire implementation.

## Independent work during a stop

Suspend affected descendants when a verified blocker invalidates their assumptions. Continue unrelated ready work. Route the execution skill's scoped repairs back to that same worker; escalate decisions reserved for the human with the smallest concrete choice and a recommendation. Never answer an environment approval prompt on the human's behalf.
