---
name: ras-implement
description: >-
  Use when Codex needs to run or guide `ras implement` for an approach-ready work item, PRD, prior ras run synthesis, or inline task. Follow the shared automated-fixer safety policy: use local-only implementation without automated review, then route any requested review/fix cycle to the manual `ras-review-loop`. Do not use when acting as the builder/reviewer subprocess inside an already-running `ras implement`; in that case follow the prompt and manifest contract instead of starting another loop.
---

# RAS Implement

Use `ras implement` when the user wants RAS to orchestrate implementation in an isolated builder worktree rather than asking the current agent to edit the current checkout directly.

## Operating Model

`ras implement` creates a separate git worktree from the current `HEAD`, creates a branch named like `ras-impl/<slug>-<timestamp>-<id>`, runs the configured builder agent there, optionally reviews each iteration with the normal RAS review pipeline, and records implementation history in the configured RAS data directory.

Local mode leaves the final code on the implementation branch/worktree printed by the command. It is not automatically merged into the original checkout and it does not post to GitHub by default.

RAS also exposes a PR-backed mode that pushes the implementation branch, opens a draft PR, and feeds review-gate output back to a builder. The shared [automated-fixer safety policy](../_shared/REVIEW-LOOP.md) currently prohibits that mode.

## Approach Risk Gate

If implementation hinges on an uncertain strategy, do not hand it straight to an autonomous builder loop. First use `ras consider` on a PRD, design, or plan, or tighten the work item until it names the chosen approach, non-goals, constraints, and verification. For an existing PR whose approach may be wrong, use one-shot `ras review` and independently judge the result before authorizing mutation.

PR-backed `ras implement` can compound a bad foundation because it creates and then auto-repairs a PR through review/fix/verify gates. It remains disabled even when the work item appears sound because later review findings still need independent task-relevance and proportionality judgment.

## Execution policy

Apply the shared automated-fixer safety policy. Run local implementation with `--local-only --no-review`, inspect and validate the result, and use the manual `ras-review-loop` only when the user requested a complete review/fix/verify cycle.

## Before Running

1. Confirm the current directory is the intended git repository.
2. Inspect `git status --short`; avoid starting a loop from an unintended dirty base. If changes are present, account for them explicitly.
3. Check that `ras` is available with `command -v ras`. If working inside the `ras` source repo and a fresh local binary is needed, build or run the local CLI intentionally.
4. Check the builder config if behavior matters: `.ras/config.yaml`, then `~/.config/ras/config.yaml`.
5. Ensure the requested work item is precise enough for an autonomous builder. It must state the outcome, acceptance criteria, preserved behavior on the changed surface, non-goals, and approved blast radius, and must satisfy the applicable contract fields and gates in the shared [contract-closure policy](../_shared/CONTRACT-CLOSURE.md). If it is vague, fails a shared gate, or is otherwise high risk, tighten it or use read-only consideration before invoking the builder.

## Choose The Work Item Source

Use exactly one source:

```bash
ras implement path/to/work-item.md
ras implement --task "Fix the flaky login test"
printf '%s\n' "$WORK_ITEM" | ras implement --stdin
ras implement --from-run <run-id>
```

Prefer a markdown file when the work is non-trivial, needs reviewable acceptance criteria, or should be committed with the repo. Keep it normative and current; link audit history instead of appending run chronology or superseded findings. Use `--task` for small, self-contained fixes. Use `--stdin` for generated multi-paragraph work items that should not become repo files. Use `--from-run` only after independently dispositioning the stored synthesis and confirming that the command will not authorize deferred or rejected items. Otherwise construct the bounded work item with a file or `--stdin`.

### Route Structured Dispositions

Before turning a prior run into implementation, inspect it with `ras show <run-id> --json`. Treat synthesis dispositions as review evidence, not workflow commands, and apply the shared [finding-disposition policy](../_shared/REVIEW-LOOP.md):

- `fix_first`: include only when the current agent confirms it is `fix-now` against the accepted work contract and the user requested mutation.
- `follow_up` with `needs_more_evidence`: report it and offer investigation; exclude it from builder work.
- `follow_up` with `architecture_review`: report it and offer a separate architecture review or grill; exclude it from builder work.
- `do_not_act`: summarize it without action.
- `omitted`: keep it inspectable but outside the normal action queue.

Create no issue and start no additional workflow without the user authorization required for that mutation or workflow. When structured dispositions are available, build a precise work item containing only independently accepted `fix-now` items and pass the remaining classifications as clearly non-authorizing context when relevant. When dispositions are absent or unavailable, inspect the underlying findings and apply the same policy; do not turn synthesis Markdown directly into builder authority.

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

Add only the current contract, referenced invariants, relevant unresolved history, and a bounded governing diff with repeatable flags:

```bash
ras implement docs/prd/feature.md --context file:README.md --context run:<run-id>
```

Supported context refs are `file:`, `url:`, and `run:`. Keep context within the work item's declared budget; do not attach the whole repository, duplicate historical plans, or full audit chronology as prose.

## Choose The Execution Mode

Do not rely on the configured default mode. The shared safety policy requires both `--local-only` and `--no-review`; do not pass `--open-pr`.

## Run Pattern

Start with conservative limits:

```bash
ras implement docs/prd/feature.md --local-only --no-review --max-iters 3
```

For a small, self-contained task:

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
- final status

If the loop fails with `blocked`, `stuck`, or `max_iters`, inspect the implementation record and builder raw output before retrying with clearer instructions or narrower scope.

## After Running

1. Record the final status, implementation id, branch name, and worktree path.
2. Inspect the implementation branch:

   ```bash
   git -C <worktree-path> status --short
   git -C <worktree-path> log --oneline --decorate -10
   git -C <worktree-path> diff <base-ref>...HEAD --stat
   ```

3. Run the project's verification commands in the implementation worktree, not the original checkout, under the shared artifact, evidence-budget, and non-recursion policies.
4. Use `ras status <run-id> --json` or `ras show <run-id> --json` for structured agent-readable inspection, and use `ras serve` or `ras report` when the user needs browsable stored history, review findings, or artifacts.
5. Tell the user where the result lives and whether it needs merge, cherry-pick, push, PR review, or follow-up fixes.

If the user requested a complete review cycle, continue from the inspected local implementation using the manual `ras-review-loop`; otherwise report that review was intentionally not automated under the shared safety policy.

## Retry Guidance

Retry with a revised work item rather than repeating the same command when:

- the builder blocked because requirements were unclear
- the loop hit `stuck`
- context was missing or too broad
- local verification exposed a requirement not described in the work item

Good retries narrow the scope, add specific failing tests or files, attach a prior review run with `--context run:<run-id>`, and reduce `--max-iters` until the loop is behaving predictably.

When later review is requested, apply the shared [finding-disposition policy](../_shared/REVIEW-LOOP.md). Do not let severity, category, or a `Fix First` label substitute for technical validity, task relevance, scope, and proportionality.

## Safety Notes

- Treat the original checkout's uncommitted changes as user-owned.
- Remember that `ras implement` branches from the current `HEAD`; choose the base intentionally.
- Do not recursively invoke `ras implement` from inside a builder prompt for an existing implementation run.
- Follow the shared automated-fixer safety policy.
- Do not assume a `done` status means the result is merged or deployed.
- Do not hide failed review findings; summarize them and point to the recorded run/artifacts.
