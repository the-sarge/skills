---
name: ras-review-loop
description: >-
  Use only when the user explicitly asks for a complete RAS review loop, such as "run the RAS review loop", "review-fix-verify-review", "iterate until the PR has no findings", or "keep reviewing and fixing until clean". Run the loop manually so the current agent independently dispositions and fixes findings. Do not use for single-step requests to only run `ras review`, fix known findings, run `ras verify`, or run a fresh review.
---

# RAS Review Loop

Drive an existing PR through the review phase of the shared [review-loop baseline](../_shared/REVIEW-LOOP.md), composed with any stronger repository review protocol. The current agent owns judgment and edits; RAS supplies review and verification evidence.

This skill stops at review cleanliness. It does not merge the PR, run final certification or hosted CI, update trackers, append the development journal, or perform release cleanup.

## Before running

1. Confirm the current directory is the intended repository and inspect `git status --short --branch`.
2. Prefer a dedicated worktree and account for user-owned changes.
3. Confirm the PR URL, branch, and live head with `gh pr view`.
4. Read the accepted work contract and repository review protocol. Require the contract to satisfy the shared [review briefing](../_shared/REVIEW-LOOP.md#review-briefing).
5. Read prior review and verification history so later rounds do not relitigate settled evidence.
6. Follow the baseline's automated-fixer safety policy; do not hand review output to an autonomous fixer.

## Loop

1. Follow `ras-review` to run each review requested by the shared [bounded review algorithm](../_shared/REVIEW-LOOP.md#bounded-review-algorithm), passing the accepted work contract through `--prompt-file` as its guidance requires.
2. Inspect the cited code and apply the baseline's finding-disposition policy to every substantive item.
3. If any item is `stop-for-decision`, preserve the branch, report the evidence and required choice, and stop before editing.
4. If there are no `fix-now` items, report `defer` and `reject` items, apply the baseline's low/nit policy, and finish against the declared evidence plan.
5. For each `fix-now` item, follow the baseline's semantic finding-family and contract-closure policies, implement the smallest complete in-bound fix, and run the accepted evidence plan.
6. Run `git diff --check`, commit and push the fixes, and confirm `git rev-parse HEAD` equals the live PR head.
7. Follow `ras-verify` with the prior review run ID and exact 40-character pushed head, then disposition its output through the shared algorithm.
8. Continue, replace the review, or stop exactly as the shared algorithm and approach-stop policy require; do not create local loop rules.

A timed-out, terminated, failed, or no-synthesis review or verification is not clean. Report it and stop rather than advancing on partial output.

Use the baseline's default evidence and review budgets unless the accepted contract records an explicit override.

## Reporting

Report the final status, PR URL and head, review and verification run IDs, all recorded dispositions with concise rationale, verification commands that passed, and any retained worktree or blocker. Do not hide deferred, rejected, failed, or unresolved findings.

## Safety

- Treat uncommitted changes as user-owned unless you made them in this loop.
- Do not force-push unless the user explicitly asks.
- Do not merge the PR or update external trackers as part of this skill.
