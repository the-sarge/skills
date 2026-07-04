---
name: ras-review
description: >-
  Use when Codex needs to run or guide a one-shot `ras review` of a GitHub pull request, optionally with posting, model profile, reviewer selection, context shape, delivery mode, timeout, or operator guidance. Use for requests such as "run ras review on PR 42", "review this PR with RAS", "post a RAS review", or "run a fresh RAS review". Prefer it as the read-only approach gate before fixes or loops when a finding could invalidate the implementation strategy. Do not use when the user asks for a complete review/fix/verify loop; use `ras-review-loop` for that.
---

# RAS Review

Use `ras review` when the user wants a multi-agent review synthesis for a GitHub PR, not an implementation loop.

## Operating Model

`ras review <pr-url-or-number>` prepares disposable review worktrees, runs the configured reviewer agents, adjudicates findings unless disabled, synthesizes a coding-agent-ready fix queue, stores artifacts in the RAS data directory, and prints the synthesis.

It does not post to GitHub unless `--post` is passed or the user later runs `ras post <run-id>`.

## Approach Gate

Use one-shot review as the default first move when a PR touches an approach-defining area and a likely finding could invalidate the implementation strategy. Examples include shell job control or process groups, concurrency/lifecycle orchestration, security/auth boundaries, migrations or data loss, parser or protocol changes, major dependency choices, and broad architecture/API shape changes.

When the synthesis contains a critical or high finding that attacks the foundation, do not automatically route it into `ras review-fix` or ask a builder to preserve the design. Summarize the approach decision for the user: abandon or redesign, patch in place, or split follow-up work. Only start a mutating loop after the operator has chosen that direction.

## Before Running

1. Confirm the current directory is the intended git repository.
2. Inspect `git status --short --branch`; local dirty changes are user-owned and should not be edited for a review-only request.
3. Confirm the PR target when needed:

   ```bash
   gh pr view <number-or-url> --json number,url,headRefName,baseRefName,state,isDraft,headRefOid
   ```

4. Check that `ras` is available:

   ```bash
   command -v ras
   ```

5. Check `.ras/config.yaml`, then `~/.config/ras/config.yaml` if agents, prompts, context shape, delivery mode, or model profile matter.

## Run Pattern

Basic review:

```bash
ras review <pr-url-or-number>
```

Fresh review after fixes:

```bash
ras review <pr-url-or-number>
```

Post during the run only when the user asks:

```bash
ras review <pr-url-or-number> --post
```

Add operator guidance:

```bash
ras review <pr> --prompt "Review correctness, security, migrations, and tests."
ras review <pr> --prompt-file ./review-prompt.md
```

Useful controls:

```bash
ras review <pr> --agents codex,claude
ras review <pr> --model-profile deep-review
ras review <pr> --context-shape tiered --delivery-mode auto
ras review <pr> --timeout-seconds 900
ras review <pr> --no-adjudication
```

Use `--no-adjudication` only when the user explicitly wants faster, less processed output or adjudicator agents are unavailable.

## Handling Output

Wait for the command to finish and read the final synthesis. Do not treat a quiet run or an exit code alone as a clean review.

Separate agents may run other plain `ras review` commands against different PRs in the same repository while this review is running. RAS gives each review its own run id, run directory, and disposable worktrees, though very large parallel batches can still contend on shared SQLite and Git worktree locks.

For this run, prefer the command's own output as the live progress source. Use `ras status`, `ras show`, `ras report`, or `ras serve` for explicit diagnostics or after the run completes rather than as a noisy polling loop. When an agent needs structured diagnostics, prefer `ras status <run-id> --json` or `ras show <run-id> --json` over scraping human-readable text.

When reporting back, include:

- run id
- PR URL or number
- whether the run posted to GitHub
- synthesis judgment and `Fix First` count
- any command failures, missing quorum, or no-synthesis condition
- where to inspect the run, such as `ras status <run-id> --json`, `ras show <run-id> --json`, `ras report <run-id>`, or `ras serve`

Low/nit handling is a loop-control policy, not just a prioritization hint. When a synthesis contains only low-severity or nit findings, report it as having no blocking findings and do not route the PR into another RAS loop solely to validate polish.

If low/nit findings appear alongside blocking findings, cheap and local low/nit fixes may ride along only when a mutating fix/verify cycle is already required for blockers. If the only remaining findings are low/nit and any are not docs-only, do not fix them now, even if they look cheap; create or recommend follow-up issues and report them separately from blockers. If the only remaining findings are low/nit docs-only findings, they may be fixed only when the edit is cheap and correctness is very high confidence; after that docs-only polish fix, do not run another `ras review`, `ras verify`, or full RAS loop solely for the docs change. Run only lightweight local docs checks and state that the RAS re-run was intentionally skipped by policy.

If the synthesis contains foundational critical/high findings, summarize the operator choice first: abandon or redesign, patch in place, or split follow-up work. Only fix findings or route to `ras-review-loop` after the operator has chosen a direction.

If the user asks to fix findings after a review, do not silently start a complete loop. Either fix the known patch-level synthesis as requested, respecting the low/nit policy above, or use `ras-review-loop` only when they ask for review/fix/verify iteration and the Approach Gate says the foundation is sound enough for mutation.

## Safety Notes

- Do not edit code for a review-only request.
- Do not post unless the user asks for posting.
- Do not hide failed reviewer, adjudication, or synthesis output.
- Do not claim the PR is merge-ready just because `ras review` completed; the synthesis content determines that.
- Treat low-severity and nit findings separately from true blockers when summarizing, and do not spend another RAS run on low/nit-only polish.
- Do not run cleanup/admin mutations such as `ras cleanup stale-runs --apply` while active reviews may still own the listed state.
