---
name: ras-implement
description: >-
  Use when Codex needs to run or guide `ras implement` to drive a work item,
  PRD, prior ras run synthesis, or inline task through RAS's isolated
  builder/review loop, including local implementation mode or PR-backed
  implementation mode. Use for requests such as "use ras implement", "run the
  implement loop", "implement this PRD with RAS", "open a RAS implementation
  PR", or "turn this RAS run into code". Do not use when acting as the
  builder/reviewer subprocess inside an already-running `ras implement`; in that
  case follow the prompt and manifest contract instead of starting another loop.
---

# RAS Implement

Use `ras implement` when the user wants RAS to orchestrate implementation through an isolated builder/review loop, rather than asking the current agent to edit the current checkout directly.

## Operating Model

`ras implement` creates a separate git worktree from the current `HEAD`, creates a branch named like `ras-impl/<slug>-<timestamp>-<id>`, runs the configured builder agent there, optionally reviews each iteration with the normal RAS review pipeline, and records implementation history in the configured RAS data directory.

Local mode leaves the final code on the implementation branch/worktree printed by the command. It is not automatically merged into the original checkout and it does not post to GitHub by default.

PR-backed mode (the default, or explicit `--open-pr`) pushes the implementation branch, opens a draft PR, then uses the same review/fix/verify/fresh-review discipline as `ras review-fix` / `ras review-loop`. It finishes only after a clean fresh review or a terminal blocked status.

## Before Running

1. Confirm the current directory is the intended git repository.
2. Inspect `git status --short`; avoid starting a loop from an unintended dirty base. If changes are present, account for them explicitly. PR-backed mode requires a clean original checkout.
3. Check that `ras` is available with `command -v ras`. If working inside the `ras` source repo and a fresh local binary is needed, build or run the local CLI intentionally.
4. Check the builder config if behavior matters: `.ras/config.yaml`, then `~/.config/ras/config.yaml`.
5. Ensure the requested work item is precise enough for an autonomous builder. If it is vague or high risk, convert it into a short PRD with goals, constraints, acceptance criteria, and verification steps before invoking the loop.

## Choose The Work Item Source

Use exactly one source:

```bash
ras implement path/to/work-item.md
ras implement --task "Fix the flaky login test"
printf '%s\n' "$WORK_ITEM" | ras implement --stdin
ras implement --from-run <run-id>
```

Prefer a markdown file when the work is non-trivial, needs reviewable acceptance criteria, or should be committed with the repo. Use `--task` for small, self-contained fixes. Use `--stdin` for generated multi-paragraph work items that should not become repo files. Use `--from-run` when implementing a synthesized RAS fix queue from a previous run.

Markdown work items may include frontmatter:

```markdown
---
title: Feature X
context:
  - file: docs/architecture.md
  - run: 20260512T010203-abcd1234
  - url: https://github.com/org/repo/issues/42
---

# Feature X

Implement the feature, including constraints, acceptance criteria, and checks.
```

Add extra context with repeatable flags:

```bash
ras implement docs/feature.md --context file:README.md --context run:<run-id>
```

Supported context refs are `file:`, `url:`, and `run:`. Keep context relevant; do not attach the whole repository as prose.

## Choose The Execution Mode

Default to PR-backed mode unless the user asks for local-only behavior or the effective config sets `implement.default_mode: local`.

Local mode:

```bash
ras implement docs/feature.md --local-only --max-iters 3
```

PR-backed mode:

```bash
ras implement docs/feature.md --max-review-loops 3 --max-fix-loops 3
```

Use `--local-only` when the user wants a local implementation worktree. Use `--pr-base` and `--pr-remote` only when the default target is wrong.

PR-backed constraints:

- `--open-pr` conflicts with `--local-only`, `--no-review`, and `--squash`.
- PR-backed builders run with a scrubbed environment by default; use `--pr-builder-inherit-env` only when the builder genuinely needs the current shell environment.
- Use `--no-pr-builder-inherit-env` to force scrubbing when project config opts into inheritance.
- PR-backed mode owns PR creation, pushes, review, verify, and final gate decisions; the builder should not push, comment, close, mark ready, or merge PRs.

## Run Pattern

Start with conservative limits until the project has proven behavior:

```bash
ras implement docs/feature.md --max-iters 3
```

Use local mode and `--no-review` only for throwaway experiments or when reviewer agents are intentionally unavailable:

```bash
ras implement --task "Rename the internal helper" --local-only --no-review --max-iters 1
```

Use `--squash` in local mode when the user wants a single final implementation commit if the loop finishes with `done`; use `--no-squash` when iteration history is useful.

Do not pass both `--squash` and `--no-squash`. `--no-post` is currently a reserved no-op because local implementations do not post by default.

## While It Runs

Watch the progress output for:

- implementation id
- branch name
- worktree path
- iteration number
- builder status
- review run id
- final status

If the loop fails with `blocked`, `stuck`, or `max_iters`, inspect the implementation record, builder raw output, and review synthesis before retrying with clearer instructions or narrower scope.

For PR-backed mode, also watch for:

- PR URL
- pushed head SHA
- outer review run id
- verification id
- final gate status

## After Running

1. Record the final status, implementation id, branch name, and worktree path.
2. Inspect the implementation branch:

   ```bash
   git -C <worktree-path> status --short
   git -C <worktree-path> log --oneline --decorate -10
   git -C <worktree-path> diff <base-ref>...HEAD --stat
   ```

3. Run the project's verification commands in the implementation worktree, not the original checkout.
4. Use `ras serve` or `ras report` when the user needs stored history, review findings, or artifacts.
5. Tell the user where the result lives and whether it needs merge, cherry-pick, push, PR review, or follow-up fixes.

For PR-backed mode, report the PR URL, final status, final head, and any retained worktree or cleanup guidance printed by RAS. Do not merge or mark the PR ready unless the user separately asks.

## Retry Guidance

Retry with a revised work item rather than repeating the same command when:

- the builder blocked because requirements were unclear
- the same review findings keep recurring
- the loop hit `stuck`
- context was missing or too broad
- verification failed for reasons not described in the work item

Good retries narrow the scope, add specific failing tests or files, attach a prior review run with `--context run:<run-id>`, and reduce `--max-iters` until the loop is behaving predictably.

Do not let low-severity or nit review findings hold up useful progress when they are not blocking correctness, safety, or merge-readiness. Fix cheap, clear nits while already in the area; otherwise record or recommend follow-up issues and report them separately from true blockers.

## Safety Notes

- Treat the original checkout's uncommitted changes as user-owned.
- Remember that `ras implement` branches from the current `HEAD`; choose the base intentionally.
- Do not recursively invoke `ras implement` from inside a builder prompt for an existing implementation run.
- Do not assume a `done` status means the result is merged or deployed.
- Do not hide failed review findings; summarize them and point to the recorded run/artifacts.
- Do not bypass PR-backed verify/fresh-review gates after review findings have been raised.
