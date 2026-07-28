---
name: ras-consider-resolve
description: >-
  Use when Codex needs to run or guide `ras consider-resolve`, apply explicit decisions to a consideration run with `ras fix <consider-run-id> --decisions <file>`, resume a waiting document-resolution session, apply a resolved document back to the caller checkout, or abort an active consider-resolve session. Use after approach-defining decisions are made; unresolved foundation choices should remain `needs_human`. Use for requests such as "resolve this RAS consideration", "apply these decisions to the PRD", "resume consider-resolve", or "abort this resolution". Do not use for critique-only local document review; use `ras-consider` for that.
---

# RAS Consider Resolve

Use `ras consider-resolve` when the user wants RAS to turn consideration findings into an explicit decision workflow and an isolated document edit, rather than only producing critique.

## Operating Model

`ras consider-resolve <file>` runs an initial consideration, writes a decision packet, waits for a Markdown decisions file or invokes the configured decision command, validates decisions, runs the fixer in a RAS-owned result worktree, verifies the edited document against the prior finding set, and returns to at most one replacement consideration before reporting `done` for an engineering contract.

The caller checkout is the starting snapshot, not the live edit target. After the result worktree exists, fixer passes, verification, and fresh consideration read the document copy inside `.ras/worktrees/consider-resolve/<resolve-id>/worktree`. The caller file changes only when the user runs `ras consider-resolve apply <resolve-id>` and the caller file still matches the fingerprint captured at session start.

Standalone `ras fix <consider-run-id> --decisions <file>` runs one source-aware document fix pass for an existing consideration run. It creates a fix-only resolution session, validates the decisions file against a generated packet, edits only the target document in the result worktree when `address` decisions exist, and stops at `fixed` with an apply handoff.

## Approach Decision Gate

Before invoking the fixer, separate document edits from decisions about the document's direction. If findings could invalidate the plan, product choice, architecture, migration strategy, representation owner or guarantee level, maintained status of a verification aid, or other foundation, mark them `needs_human` or ask the user; do not ask the fixer to preserve the current text by patching around an unresolved approach decision. A handwritten scanner claiming broad coverage of an open external grammar is `needs_human`; do not address it by adding syntax cases.

## Before Running

1. Confirm the current directory is the intended git repository.
2. Inspect `git status --short --branch` and treat uncommitted changes as user-owned.
3. Confirm the target document and any `file:` context refs are inside the repository.
4. Check that `ras` is available with `command -v ras`.
5. Check `.ras/config.yaml`, then `~/.config/ras/config.yaml` when decision method, fixer command, model profile, loop caps, gate categories, or environment inheritance matter.
6. For an engineering contract, recover its representation domain and owner, guarantee level, artifact classes, terminating evidence plan, and evidence and review budgets. Keep the resolution scoped to those fields and the independently accepted findings.

## Full Resolution

Start a new resolution:

```bash
ras consider-resolve docs/prd/feature-prd.md --kind prd
ras consider-resolve docs/design.md --kind design --context file:README.md
```

Manual decision mode normally stops in `waiting_for_decisions` and prints:

```text
consider_resolve: <resolve-id>
decision_packet: <path>
decisions_out: <path>
status: waiting_for_decisions
resume: ras consider-resolve --resume <resolve-id>
```

Open the packet, write exactly one fenced JSON decisions block in the printed decisions file, then resume:

```bash
ras consider-resolve --resume <resolve-id>
```

If a valid decisions file contains `needs_human`, RAS stores it but keeps the session waiting and does not invoke the fixer. Amend the same decisions file with final `address`, `reject`, or `defer` decisions before resuming again.

## Standalone Fix

Apply explicit decisions to one prior consideration run:

```bash
ras fix <consider-run-id> --decisions docs/prd/feature-prd-decisions.md
```

Use this when the user already has decisions and wants one isolated document-edit pass without the full verify/fresh-consider loop. `ras fix` refuses before mutation when the caller target has drifted from the source fingerprint of the referenced consideration run.

If a fixer believes accepted `address` decisions are already satisfied without edits, it should write `status: "done"` and `no_edit_required: true` in the fixer manifest. Fix-only sessions require that explicit flag for no-change `address` passes; full `consider-resolve` sessions send no-change `address` passes through verification and fresh consideration instead of blocking immediately.

## Apply Or Abort

Inspect the result before applying:

```bash
git -C <result-worktree> diff <initial-head> -- docs/prd/feature-prd.md
git -C <result-worktree> status --short
```

Apply a handoff-ready result to the caller checkout:

```bash
ras consider-resolve apply <resolve-id>
```

If apply reports caller drift, do not force it. Inspect both files, reconcile the caller checkout, then rerun apply or ask the user how to proceed.

After an apply-origin block such as `caller_drift`, `ras consider-resolve --resume <resolve-id>` can reprint `ras consider-resolve apply <resolve-id>` when lifecycle state still allows an apply retry.

Abort an unwanted non-terminal or fixed session:

```bash
ras consider-resolve abort <resolve-id>
```

Abort releases the active target key and keeps the result worktree available for inspection.

## Decision File Rules

Decision files are Markdown with exactly one fenced JSON block. The JSON must match the active `run_id`, `resolve_id`, and `packet_fingerprint`; every actionable packet finding needs exactly one decision; `address` requires `fixer_instruction`; `reject` and `defer` require `reason`; `needs_human` must not include either field.

Do not invent decisions. If a finding is a product or scope choice the user has not made, leave it as `needs_human` or ask the user before amending the file.

Rejected and deferred findings are durable decisions, not ignored text. They stop the same stable finding fingerprint from repeatedly blocking the one replacement consideration for the same resolution lineage. A later new non-critical root is normally `defer` or `needs_human`, not authorization for another fix/verify/consider cycle; only a directly in-scope critical safety defect may explicitly override the review budget.

## Handling Output

When reporting back, include the resolve id, status, decision packet path, decisions path, result worktree, result file, apply command, and any blocker substatus. For `done` or `fixed`, state whether the caller checkout has been applied yet.

Use `ras status <consider-run-id> --json` or `ras show <consider-run-id> --json` for agent-readable inspection of decision packet artifacts, raw and parsed decisions, verification Markdown, parsed verification JSON, fixer manifests, and raw fixer output; use `ras report <consider-run-id>` or `ras serve` for human browsing.

## Concurrent RAS Commands

While `ras consider-resolve`, `ras fix`, or `ras verify` is actively running, monitor that command's own output as the primary progress source. `ras status`, `ras show`, `ras report`, and `ras serve` are appropriate for explicit diagnostics or after the command exits, but avoid polling loops and do not run cleanup/admin mutations while guarded fixer or verification workflows may still own local state.

## Safety Notes

- Do not edit the caller document directly unless the user explicitly asks outside the RAS workflow.
- Do not attach public `ras fix` to an existing full-loop session unless RAS prints an explicit resume or apply command.
- Do not treat a clean verification as final `done`; full resolution still requires the one allowed replacement consideration and independent disposition against the terminating evidence plan. It does not require repeated consideration until reviewer creativity is exhausted.
- Do not bypass apply drift checks by copying files manually unless the user explicitly takes over reconciliation.
- Do not push, post to GitHub, or mutate external systems as part of consider-resolve.
