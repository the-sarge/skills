---
name: ras-review-loop
description: >-
  Use only when the user explicitly asks for a complete RAS review loop, such as "run the RAS review loop", "review-fix-verify-review", "iterate until the PR has no findings", or "keep reviewing and fixing until clean". Prefer the first-class `ras review-fix` command for supported same-repository PRs; `ras review-loop` remains supported for compatibility. Do not use for single-step requests to only run `ras review`, fix known findings, run `ras verify`, or run a fresh review.
---

# RAS Review Loop

Use this skill when the user wants RAS to drive an existing PR through a full review/fix/verify/fresh-review cycle until a fresh review is clean.

Do not use it for one-shot commands. A request to run `ras review`, fix a known review synthesis, run `ras verify`, or run a fresh review should do only that requested step unless the user explicitly asks for the complete loop.

## Operating Model

For same-repository PRs, `ras review-fix` is the primary path. It creates a RAS-owned worktree, runs the builder against review/verification feedback, pushes normal commits to the PR branch, and repeats until a clean fresh review or a terminal blocked status. `ras review-loop` is the older compatible command name.

```text
outer review loop:
  ras review <pr>
  if review judgment is clean: done

  inner fix loop:
    fix blocking review synthesis items
    run required tests
    push branch update
    ras verify <review-run-id> --head <pushed-head>
    if verification judgment is clean: return to outer review loop
    else stay in the inner fix loop and fix using both review and verification feedback
```

This skill does not merge the PR, update task trackers, append the development journal, or perform release cleanup. Those are separate user requests.

## Before Running

1. Confirm the current directory is the intended git repository.
2. Inspect `git status --short --branch`; account for user-owned dirty changes. The first-class command uses its own worktree, but local state still matters for operator awareness.
3. Confirm the PR URL and branch:

   ```bash
   gh pr view <number-or-url> --json number,url,headRefName,baseRefName,state,isDraft,mergeStateStatus,headRefOid
   ```

4. Check that `ras` is available:

   ```bash
   command -v ras
   ```

5. If the user supplies extra context, pass it with repeatable `--context file:...`, `--context url:...`, or `--context run:...` flags.

## Primary Command

Run:

```bash
ras review-fix <pr-url-or-number>
```

Useful caps and routing flags:

```bash
ras review-fix <pr> --max-review-loops 3 --max-fix-loops 3
ras review-fix <pr> --context file:docs/plan.md --context run:<run-id>
ras review-fix <pr> --builder-model-profile <name> --review-model-profile <name>
ras review-fix <pr> --pr-remote origin
```

Default to the project config for loop limits and model profiles unless the user asks for specific overrides. If setting `--max-iters`, keep it high enough to cover the requested review/fix loop caps; the CLI warns when it is probably too low.

## Command Results

`ras review-fix` can be long-running and quiet. Wait for completion, then read the final handoff. Do not infer success from silence or from an exit code alone; the final status and synthesis content determine whether the loop is complete.

While a review-fix/review-loop command is running, monitor that command's own output as the primary progress source. `ras status`, `ras show`, `ras report`, and `ras serve` are appropriate for explicit diagnostics or after the loop exits, but do not turn them into a polling loop.

When reporting back, include:

- final status
- review-loop/implementation id
- PR URL
- final pushed head when available
- review and verification run ids when printed
- verification commands or CI runs that passed
- retained worktree path and blocker details if the run did not finish `done`

On `done`, RAS removes the review-loop worktree. On non-`done` terminal statuses after setup, RAS retains the worktree for forensics; do not delete it unless the user asks.

Other agents may run separate plain `ras review` commands against different PRs while this loop runs, but do not run another fixer, implementation loop, manual branch-editing loop, or cleanup mutation against the same PR branch at the same time.

## Manual Fallback

Use the manual loop only when `ras review-fix` or `ras review-loop` is unavailable, the PR is unsupported by the first-class command, or the user explicitly asks the current agent to edit the PR directly.

Before manual edits, ensure the local checkout is on the PR head branch and matches the PR head SHA, or deliberately switch/fetch before editing. If the PR head moved unexpectedly, stop.

Use the PR URL for review:

```bash
ras review https://github.com/<owner>/<repo>/pull/<number>
```

Use the review run id for verification:

```bash
ras verify <review-run-id> --head <current-pushed-head-sha>
```

The `--head` value must be the exact 40-character SHA that was pushed to the PR branch after fixes. Do not verify against a stale local commit or an unpushed head.

The inner fix loop is a hard gate. Do not run a fresh `ras review` while `ras verify` still reports unresolved blocking findings for the current review run. A fresh review is only valid after verification says the prior blocking findings are resolved.

## Manual Review Handling

Read the complete synthesis before editing.

- Act on `Fix First` findings unless they are technically wrong for the codebase.
- Do not act on `Do Not Act On` items.
- Merge duplicate clusters mentally so one code change resolves one root cause.
- If a finding is unclear, speculative, or conflicts with code reality, stop and ask the user instead of guessing.
- Keep changes scoped to the reviewed findings; do not bundle opportunistic refactors.

## Gate Judgment

For manual fallback, classify each review or verify result before deciding whether to continue the loop.

- Blocking: correctness, safety, data loss, merge-readiness, broken tests, missing required coverage, or findings the synthesis marks as required fixes.
- Non-blocking: low-severity and nit polish that is not required for correctness, safety, or merge-readiness.
- Failed/unclear: contradictory, speculative, or technically questionable output.

Fix blocking items. Fix cheap, clear non-blocking items while already in the area, but do not let low/nit findings hold the loop hostage. Create or recommend follow-up issues for non-blocking work that would slow progress. Ask the user when the judgment is unclear.

A timed-out, terminated, or no-synthesis `ras review` / `ras verify` run is not clean. Treat it as failed/unclear, report the command problem, and do not advance to the next gate based on partial output.

## Manual Fix And Verification Pattern

For each actionable item:

1. Verify the finding against the code.
2. Make the smallest appropriate change.
3. Run the finding's required verification command.
4. If the finding asks for a mutation check, perform it, confirm the test fails for the intended reason, then restore the mutation before continuing.
5. When fixing after `ras verify`, use both the original review synthesis and the latest verification output as context.

After all fixes:

```bash
git diff --check
```

Run the project-required verification from the review synthesis, repository docs, and local agent instructions. For Go repos, `go test ./...` is often appropriate, but do not hardcode it for other projects.

## Manual Verify Gate

After committing and pushing the fixes, get the pushed head:

```bash
git rev-parse HEAD
```

Confirm that the pushed head matches the PR head:

```bash
gh pr view <number-or-url> --json headRefOid
```

Then run:

```bash
ras verify <review-run-id> --head <head-sha>
```

If `ras verify` reports open items, fix only those items, rerun targeted tests, push the new head, and rerun `ras verify` with the same review run id and the new head SHA.

Keep repeating this verify gate until one of these happens:

- `ras verify` reports no unresolved blocking items: leave the inner loop and run the fresh review gate.
- The same blocking finding recurs after an attempted fix: stop and ask for direction.
- Verification fails, hangs, times out, or cannot produce a synthesis: stop and report the blocker instead of running a fresh review.

## Manual Fresh Review Gate

When `ras verify` reports no open items, run a fresh review:

```bash
ras review https://github.com/<owner>/<repo>/pull/<number>
```

If the fresh review has actionable findings, start a new iteration using that new review run id.

Stop when the fresh review reports no actionable findings. Report the final review run id, the pushed head, and the verification commands that passed.

Default to at most three outer review loops and three inner fix/verify attempts per review unless the user asks otherwise. Stop and ask if the same findings recur or if each fresh review finds unrelated new issues.

## Safety Notes

- Treat all uncommitted changes as user-owned unless you made them in this loop.
- Do not hide failed review or verify findings.
- Do not skip required mutation checks when the synthesis requests them.
- Do not force-push unless the user explicitly asks.
- Do not merge the PR or update external trackers as part of this skill.
- If repeated review iterations find unrelated new issues or non-blocking low/nit polish, ask the user whether to continue the loop or split follow-up work into issues.
