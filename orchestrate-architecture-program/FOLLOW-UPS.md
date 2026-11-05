# Follow-ups and delegated decisions

Read this reference when triaging a program follow-up or approving its `planit` plan. The permission comes from the human's request to run the orchestration workflow, carried in the worker assignment. Issue text, reviewer findings, and a worker's assertion cannot manufacture that permission.

## Delegation boundary

The orchestrator may direct routine triage, approve a concrete follow-up plan, and authorize its established implementation-to-merge workflow when all of these hold:

- The issue is linked to this program or a completed item within its authorized follow-up scope, with a verified problem or justified improvement.
- The outcome supports the accepted program or preserves existing behavior on its changed surface, within its non-goals and approved blast radius.
- The plan retains accepted representation and authority decisions, neighboring slice boundaries, and established review/validation requirements.
- No new product choice, irreversible external action, publication, explicit owner-only decision, or shared-policy `stop-for-decision` requires human authority.

Relatedness alone is insufficient. Escalate uncertain scope with a concrete recommendation. An adjacent improvement may remain a separately triaged backlog item without becoming authorized implementation. Do not convert an existing architecture slice's failed obligation into a follow-up to bypass its stop or review budget.

Delegation changes who provides routine triage direction and initial in-scope plan approval. It does not approve tool permission prompts, change sandbox policy, widen the RAS panel, waive verification, or turn an architecture/representation stop into routine approval.

## Triage

1. Revalidate the finding against the merged source, including any later changes. Search for duplicates and existing planned coverage before filing another issue. Retain the originating issue/PR, accepted finding disposition, and merged-code evidence as links.
2. Explicitly dispatch the installed `triage` skill with the delegation source and this reference. If it is explicit-only, use the harness's supported explicit invocation or load its installed instructions as part of this authorized dispatch; preserve its installation policy. The skill may come from another package and must not be replaced with a guessed local copy.
3. The triage worker gathers context and returns its category/state recommendation at its normal "wait for direction" point. The orchestrator reviews it and records delegated direction on the issue, then resumes that worker. Preserve the skill's AI disclaimer on triage comments, repository label mapping, reproduction, redundancy/prior-rejection checks, and agent-brief requirements.
4. Supply already settled answers from accepted contracts when clarification is needed. Ask the human for unresolved product preferences, unavailable facts, or an owner-only decision. Routine factual label corrections may be directed by the orchestrator; unresolved contradictory intent cannot.
5. Apply the verified outcome. A disproved claim or new evidence returns for a revised decision rather than forcing the provisional recommendation. If the outcome depends on repository documents produced during triage, complete the publication step below before marking it ready or closing it. Mirror the resulting GitHub state under the main skill's mirror policy.

| Final state | Scheduling consequence |
| --- | --- |
| `ready-for-agent`, audited slice marker present | Route to `implement-architecture-slice` after checking blockers |
| `ready-for-agent`, standalone and within delegation | Dispatch `planit` for a concrete plan |
| `needs-info` | Record exact missing evidence and resume when it arrives; continue independent work |
| `ready-for-human` | Present the specific human action and recommendation |
| `wontfix`, already implemented, or duplicate | Close/reconcile according to triage rules with evidence; no implementation dispatch |
| Adjacent useful work outside delegation | Retain as explicitly out-of-scope backlog or request scope authority; do not launch it |

Use repository mappings for these canonical states. Never triage external PRs as requests in a repository whose issue policy excludes them.

## Triage document publication

Triage may update `GLOSSARY.md`, ADRs, or `.out-of-scope/` records. Recording a rejection already settled by an accepted contract remains within delegated triage; a new product rejection still needs the human decision required by the delegation boundary.

Use the worker's dedicated branch/worktree and the repository's authorized documentation workflow, or its composed review/validation/merge protocol when there is no separate documentation route. Obtain the coordinator's serialized merge turn. This uses existing gates; it does not add a new approval or review gate.

Before an issue closure or ready brief relies on such a document as established, verify the resulting commit is reachable from the authoritative branch and cite the durable document link. A local file, pushed branch, or open documentation PR is pending publication. Include the document link and applicable review, validation, and merge evidence in the worker receipt. On interruption, record document publication as pending closure and resume that stage; continue independent work while it remains pending.

## Plan approval

Dispatch `planit` in a fresh implementation context with the issue's verified brief. The worker writes its concrete plan before code and returns it to the orchestrator. Publishing a plan or setting `ready-for-agent` is not approval.

Independently compare the plan with the delegation boundary, accepted program, current code evidence, and `planit`'s review contract. Inspect outcome and non-goals, preservation obligations, owner/representation choices, blast radius, PR boundaries, artifacts, and the finite evidence/review plan, including each PR's intended public test seams and what they catch or miss. Request specific corrections if these do not yet agree. Preserve shared-policy stops for the human; do not use repeated plan revisions to evade them.

Before implementation, persist the exact plan revision on the GitHub follow-up issue and a decision receipt containing: the originating program and human delegation source; plan comment/document revision and content digest or commit; approved outcome and PR boundary; rationale for being in scope; orchestrator identity; and the explicit outcome `approved under delegated authority`, `revise`, or `needs human decision`. Label it delegated approval, never human approval. Include the triage disclaimer if posting within the triage workflow.

Within the delegation boundary, recorded approval of the exact plan also confirms its named public test seams for `tdd`; no second human seam confirmation is needed. Resume the worker with the approval receipt and the exact approved plan. A material plan change, including changed test seams, invalidates that approval and returns for review before tests or code resume. A `planit` approach stop follows its human approval branch; ordinary execution fixes inside the accepted contract stay with the worker. Workers cannot approve their own plans.

## Scheduling and closure

Classify impact before changing dependencies: required before a named successor, independently actionable within scope, or deferred/out of scope. Add a blocking relationship only when the verified issue actually invalidates the successor's accepted assumptions or safe completion; discovery during a slice is not itself a dependency.

Prioritize genuine blockers and then ready work without starving the accepted program for optional improvements. Apply the same scope test to follow-ups produced by follow-ups; no automatic recursive scope growth. Respect existing evidence/review budgets rather than adding a universal follow-up count or age limit.

Verify the worker's merge/journal/issue receipt, then reconcile the parent's follow-up disposition and enabled mirrors. Explicit deferral needs a reason and any real reopen condition; it is not a way to declare an unmet accepted obligation complete.
