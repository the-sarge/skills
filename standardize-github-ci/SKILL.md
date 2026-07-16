---
name: standardize-github-ci
description: Standardize GitHub Actions CI for one repository at a time through read-only audit, approval-gated planning and implementation, and verification, including agent-gated exact-head validation after out-of-band review. Use for Actions-usage audits, Taskfile or workflow refactors, review-before-CI sequencing, dispatch-gated required checks, or applying the portfolio CI policy to a repository.
---

# Standardize GitHub CI

Standardize one repository without assuming that every repository needs identical jobs. Treat GitHub workflow YAML as CI orchestration, Taskfile tasks as portable validation commands, GitHub rulesets as enforcement, and RAS as an agent-side review tool when the repository uses it.

## Trust and review boundary

Keep GitHub review-system agnostic by default. The agent opens or updates a PR without starting CI, runs RAS or other review tools outside GitHub, resolves findings, decides when the exact PR head is ready, requests CI for that head, verifies the resulting run, and merges that same head. Do not encode RAS state in workflow names, inputs, labels, statuses, comments, environments, or conditions.

Treat `expected_sha` and `base_sha` as generic race and ref-integrity guards, not proof that RAS ran or passed. Under the default trusted-agent/operator model, candidate-branch workflow code is acceptable because the agent rechecks the live PR head, dispatched run head, required result, and merge head. If repository evidence or the user explicitly places malicious same-repository branch writers inside the threat model, stop and plan a trusted controller or dedicated check publisher separately; do not silently impose that stronger architecture on the default workflow.

Define base semantics explicitly. Default `base_sha` to the current default-branch tip captured when the agent makes its final review decision; if that branch advances, update the PR as needed and repeat the agent-side review/CI decision. Repositories that intentionally validate against a merge base or merge-queue SHA must document and test that different invalidation rule.

## Choose the mode

Infer the narrowest authorized mode. Default to `audit` when the request is ambiguous.

- `audit`: inspect local and current default-branch configuration, recent runs, and available billing evidence; report only.
- `plan`: produce a repo-specific migration plan and expected savings; do not edit.
- `apply`: implement an approved plan on a feature branch or worktree and validate it.
- `verify`: check an existing migration against the policy and actual workflow behavior; do not expand into unrelated fixes.

Never treat an audit or plan request as authorization to edit files, change GitHub settings, open a PR, push, or rerun workflows.

## Load policy and instructions

1. Read repository `AGENTS.md` files that govern the target paths.
2. Read [references/ci-policy.md](references/ci-policy.md) completely for every mode.
3. Read [references/migration.md](references/migration.md) completely in `plan`, `apply`, and `verify` modes.
4. Run `scripts/audit-ci.sh <repository-path>` for deterministic local evidence when the repository is checked out.
5. Treat the current GitHub default branch as authoritative when the checkout may be stale. Use read-only `gh` queries rather than fetching into or modifying a user worktree.
6. Inspect Taskfile tasks invoked by CI, not just workflow YAML.
7. Establish whether RAS is the repository's pre-merge review gate from user direction, repository instructions, Taskfile/scripts, or RAS history. Do not infer a clean RAS verdict from process exit alone.

## Audit

Collect evidence before recommending changes:

1. Inventory workflow triggers, runner labels, matrices, job dependencies, conditions, concurrency, timeouts, permissions, caches, artifacts, schedules, and Taskfile entry points.
2. Distinguish GitHub-hosted, self-hosted, and public-repository usage. Do not present self-hosted work as billed runner minutes.
3. Inspect recent workflow titles, events, conclusions, and changed files. Verify docs-only examples from PR file lists rather than relying only on titles.
4. Inspect organization billing usage when readable. State any scope or permission limitation.
5. Find duplicated work across jobs and Taskfile lanes, including normal plus race tests, repeated vulnerability scans, repeated checkout/toolchain/private-module setup, and PR plus merged-push reruns.
6. Identify correctness constraints such as private dependencies, generated docs, cgo, platform-specific files, release signing, secret scanning, and direct pushes to the default branch.
7. For repositories that run RAS agent-side before CI, distinguish automatic pull-request activity such as open and synchronize from operator-only activity such as `types: [labeled]`, confirm whether an explicit generic dispatch or one-shot operator path can produce the required check in the PR rollup, and compare superseded agent-reviewed heads with CI runs when evidence is available.

When user direction establishes that the repository uses RAS but the audit cannot discover repository-local evidence, run it as `CI_USES_RAS=true scripts/audit-ci.sh <repository-path>`. Use `CI_USES_RAS=false` only when the repository is explicitly non-RAS and mechanical detection is a false positive.

Report findings by impact and cite exact workflow paths, Taskfile tasks, runs, or billing records. Include repositories or workflows requiring no change.

## Plan

Produce a migration that includes:

- change categories and fail-closed classification rules;
- proposed `docs-check`, `check`, `deep-check`, and `release-check` Taskfile lanes, adapted to existing names when appropriate;
- a job graph that runs a cheap core gate before expensive jobs;
- PR, default-branch, schedule, manual, and tag behavior;
- exact base-SHA semantics, base-advance invalidation, and merge-queue compatibility;
- agent-side review-before-CI ordering, the exact-head handoff, and which workflow runs after the agent decides the PR is ready;
- hosted versus self-hosted runner choices;
- the stable required check and GitHub ruleset transition;
- validation, observation, and rollback steps;
- exceptions to the default policy with repository evidence;
- an estimate or qualitative ranking of savings.

For a repository that uses agent-side review before CI, prefer the minimal cost-first migration unless repository evidence requires more automation: stop automatic certifying CI on PR updates, retain or add explicit dispatch with a fail-closed binding to the exact requested head SHA, keep the required context stable, and let its absence on a new head block merging until the agent requests CI for that head. A branch-only dispatch is insufficient because the branch can advance between review and workflow start. GitHub may omit `workflow_dispatch` job checks from the PR required-status rollup even when the check suite names the PR; when live evidence confirms that behavior, publish the generic required CI commit status as pending after exact-head binding and success or failure after aggregation. Give the dispatch aggregate check a different display name because GitHub may require both a same-named check and status. That status reports CI only and must not encode which review tool ran or what it decided. Treat Task wrappers as optional agent interfaces; do not add labels, webhooks, statuses, or workflow inputs merely to represent the out-of-band review decision.

When live proof shows that GitHub excludes `workflow_dispatch` checks from the required PR rollup, an operator-only `pull_request` activity such as `types: [labeled]` is an admissible fallback. Require a dedicated label, revoke it before running repository code, bind the event to the live same-repository PR head, base, and synthetic merge SHAs, fail closed on unrelated labels, and prove that open and synchronize events start no run.

## Apply

Proceed only when the user explicitly asks to implement or has approved the plan.

1. Inspect git status and preserve user-owned changes.
2. Follow repository branch/worktree instructions. Use an isolated worktree for non-trivial or overlapping work.
3. Adapt assets rather than copying them blindly:
   - Use [assets/classify-ci-changes.sh](assets/classify-ci-changes.sh) for fail-closed change categories.
   - Use [assets/ci.yml.template](assets/ci.yml.template) when required validation spans conditional jobs.
   - Use [assets/require-ci-results.sh](assets/require-ci-results.sh) to validate every job contributing to a final required gate.
4. Keep repository-specific commands in the Taskfile or existing scripts. Keep event, runner, dependency, and cancellation policy in workflow YAML.
5. Preserve or deliberately transition required check names. Do not change rulesets, branch protection, Actions budgets, secrets, variables, runner groups, or repository settings without explicit authorization for those external mutations.
6. Pin third-party actions according to repository policy. Do not copy stale versions from the assets.
7. Keep the diff scoped to CI standardization.
8. For an approved agent-gated migration, remove automatic open and synchronize certification from `pull_request` and `pull_request_target`, remove newly unreachable event branches, preserve an explicit full/fail-closed operator path with generic head/base inputs, and add a workflow contract that prevents automatic PR certification from returning. Prefer exact-head dispatch; consider a one-shot generic operator event only after live evidence shows dispatch cannot satisfy the required PR rollup. If a generic commit-status bridge is needed for ruleset attribution, grant `statuses: write` only to the jobs that publish pending and final CI states, link the status to the run, give the dispatch aggregate check a distinct display name, guard terminal publication against cancellation, reject every cancelled run even if cancellation races with an already-started status request, and make failure reporting fail closed. Keep any automatic cheap preflight separate from the required certification check, and keep RAS names and verdicts out of all GitHub workflow and status state.
9. Do not open the migration PR without considering the bootstrap effect: the old default-branch workflow may start one final automatic CI run. Opening, cancelling, rerunning, or dispatching that run requires the user's authorization.

## Validate

Validate in proportion to the change:

1. Run the repository's workflow contract tests and `actionlint` when available.
2. Parse every edited YAML file.
3. Run changed shell-script tests or at minimum syntax checks plus representative fixtures.
4. Run Taskfile lanes affected by the refactor when the required toolchain and credentials are available.
5. Re-run `scripts/audit-ci.sh` and resolve new policy warnings or document justified exceptions.
6. Model at least these paths: docs-only PR, source PR, dependency change, workflow change, superseding PR commit, protected merge to the default branch, schedule, manual dispatch, and release tag when applicable.
7. If authorized to open a test PR, observe actual check names and skipped-job behavior before changing required checks.
8. For agent-gated validation, prove that PR open/synchronize events start no certifying jobs, an intermediate head consumes no certifying runner time, the operator trigger produces a required result in the PR rollup for the exact requested head/base/merge binding that the live ruleset actually credits, the dispatch check name does not collide with the required status context, a newer SHA cannot reuse that success, the agent verifies the run head and live PR head, and the required result remains absent before the operator trigger or pending while CI runs. Cancel and redispatch a same-head canary to prove the cancelled run publishes no terminal result and the fresh run recovers pending. Inspect the PR status rollup and attempt the guarded merge; a green workflow run alone is insufficient evidence.

Do not claim that a workflow saves minutes merely because YAML parses. Explain which jobs no longer start and under which events.

## Deliver

State:

- mode completed;
- files or settings changed, if any;
- validation performed and unavailable validation;
- expected runner-minute effect;
- the exact agent-side review-to-dispatch-and-merge command or handoff;
- required human or GitHub-settings follow-up;
- remaining policy exceptions.
