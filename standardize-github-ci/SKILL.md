---
name: standardize-github-ci
description: Audit, plan, implement, and verify efficient GitHub Actions CI for one repository at a time, with Taskfile validation lanes, change-aware job routing, stable required checks, concurrency, timeouts, runner-cost controls, and approval-gated GitHub settings changes. Use when the user asks to inspect CI waste, standardize workflows, prevent docs-only changes from running full suites, reduce Actions minutes, refactor Taskfile/Actions configuration, or apply the portfolio CI policy to a repository.
---

# Standardize GitHub CI

Standardize one repository without assuming that every repository needs identical jobs. Treat GitHub workflow YAML as orchestration, Taskfile tasks as portable validation commands, and GitHub rulesets as enforcement.

## Choose the mode

Infer the narrowest authorized mode. Default to `audit` when the request is ambiguous.

- `audit`: inspect local and current default-branch configuration, recent runs, and available billing evidence; report only.
- `plan`: produce a repo-specific migration plan and expected savings; do not edit.
- `apply`: implement an approved plan on a feature branch or worktree and validate it.
- `verify`: check an existing migration against the policy and actual workflow behavior; do not expand into unrelated fixes.

Never treat an audit or plan request as authorization to edit files, change GitHub settings, open a PR, push, or rerun workflows.

## Load policy and instructions

1. Read repository `AGENTS.md` files that govern the target paths.
2. Read [references/ci-policy.md](references/ci-policy.md) completely.
3. Run `scripts/audit-ci.sh <repository-path>` for deterministic local evidence when the repository is checked out.
4. Treat the current GitHub default branch as authoritative when the checkout may be stale. Use read-only `gh` queries rather than fetching into or modifying a user worktree.
5. Inspect Taskfile tasks invoked by CI, not just workflow YAML.

## Audit

Collect evidence before recommending changes:

1. Inventory workflow triggers, runner labels, matrices, job dependencies, conditions, concurrency, timeouts, permissions, caches, artifacts, schedules, and Taskfile entry points.
2. Distinguish GitHub-hosted, self-hosted, and public-repository usage. Do not present self-hosted work as billed runner minutes.
3. Inspect recent workflow titles, events, conclusions, and changed files. Verify docs-only examples from PR file lists rather than relying only on titles.
4. Inspect organization billing usage when readable. State any scope or permission limitation.
5. Find duplicated work across jobs and Taskfile lanes, including normal plus race tests, repeated vulnerability scans, repeated checkout/toolchain/private-module setup, and PR plus merged-push reruns.
6. Identify correctness constraints such as private dependencies, generated docs, cgo, platform-specific files, release signing, secret scanning, and direct pushes to the default branch.

Report findings by impact and cite exact workflow paths, Taskfile tasks, runs, or billing records. Include repositories or workflows requiring no change.

## Plan

Produce a migration that includes:

- change categories and fail-closed classification rules;
- proposed `docs-check`, `check`, `deep-check`, and `release-check` Taskfile lanes, adapted to existing names when appropriate;
- a job graph that runs a cheap core gate before expensive jobs;
- PR, default-branch, schedule, manual, and tag behavior;
- hosted versus self-hosted runner choices;
- the stable required check and GitHub ruleset transition;
- validation, observation, and rollback steps;
- exceptions to the default policy with repository evidence;
- an estimate or qualitative ranking of savings.

Do not make a workflow-level `paths` filter the sole mechanism for a required check. GitHub can leave an entirely skipped required workflow pending. Prefer an always-triggered workflow with conditional internal jobs and a stable final gate.

## Apply

Proceed only when the user explicitly asks to implement or has approved the plan.

1. Inspect git status and preserve user-owned changes.
2. Follow repository branch/worktree instructions. Use an isolated worktree for non-trivial or overlapping work.
3. Adapt assets rather than copying them blindly:
   - [assets/classify-ci-changes.sh](assets/classify-ci-changes.sh) provides fail-closed change categories.
   - [assets/ci.yml.template](assets/ci.yml.template) demonstrates the efficient single-required-job default.
   - [assets/require-ci-results.sh](assets/require-ci-results.sh) provides final-gate result validation only when a repository genuinely needs multiple independently required jobs.
4. Keep repository-specific commands in the Taskfile or existing scripts. Keep event, runner, dependency, and cancellation policy in workflow YAML.
5. Preserve or deliberately transition required check names. Do not change rulesets, branch protection, Actions budgets, secrets, variables, runner groups, or repository settings without explicit authorization for those external mutations.
6. Pin third-party actions according to repository policy. Do not copy stale versions from the assets.
7. Keep the diff scoped to CI standardization.

## Validate

Validate in proportion to the change:

1. Run the repository's workflow contract tests and `actionlint` when available.
2. Parse every edited YAML file.
3. Run changed shell-script tests or at minimum syntax checks plus representative fixtures.
4. Run Taskfile lanes affected by the refactor when the required toolchain and credentials are available.
5. Re-run `scripts/audit-ci.sh` and resolve new policy warnings or document justified exceptions.
6. Model at least these paths: docs-only PR, source PR, dependency change, workflow change, superseding PR commit, protected merge to the default branch, schedule, manual dispatch, and release tag when applicable.
7. If authorized to open a test PR, observe actual check names and skipped-job behavior before changing required checks.

Do not claim that a workflow saves minutes merely because YAML parses. Explain which jobs no longer start and under which events.

## Deliver

Lead with the outcome. State:

- mode completed;
- files or settings changed, if any;
- validation performed and unavailable validation;
- expected runner-minute effect;
- required human or GitHub-settings follow-up;
- remaining policy exceptions.
