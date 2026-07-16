# CI Migration Guide

## Required planning questions

Answer these before implementation:

1. Which check names are currently required?
2. Are direct pushes to the default branch possible?
3. Which documentation is generated from code?
4. Does the repository contain cgo, OS-specific files, GUI code, installers, or native libraries?
5. Which private dependencies, credentials, or self-hosted runners are required?
6. Which checks detect time-varying external risk?
7. Which jobs publish, deploy, sign, attest, comment, or otherwise mutate external state?
8. What recent changes produced unnecessary runs, and what would the proposed classifier do with them?
9. Is RAS the pre-merge review gate, what constitutes a blocker-free result, and how is the reviewed head SHA recorded?
10. Can `workflow_dispatch` or an equivalent operator trigger produce a required result on a same-repository PR head that the live PR status rollup and ruleset actually credit, or is a generic commit-status bridge required?
11. Does the repository trust the agent/operator and same-repository branch writers, or does it explicitly require protection from malicious branch-controlled workflow changes?
12. Does `base_sha` mean the current default-branch tip, the PR merge base, or a merge-queue synthetic SHA, and which changes invalidate prior review/CI?
13. Is a merge queue enabled, and if so how does its synthetic SHA interact with exact-head validation and merge?

## Minimal agent-gated migration

Use this pattern when the agent runs RAS or another review process before paid CI and the user has not requested a more elaborate integration. GitHub does not need to know which review tool was used or what verdict it produced:

1. Preserve the stable required check and its result aggregation.
2. Remove automatic open and synchronize certification from `pull_request` and `pull_request_target`; remove event-specific branches that become unreachable.
3. Preserve or add `workflow_dispatch` with a full or otherwise fail-closed validation mode. Use generic `expected_sha` and `base_sha` inputs plus an early equality check when practical; regardless, the agent must inspect the resulting run's head SHA before accepting it. Do not assume a dispatched job check satisfies a PR ruleset: verify the PR status rollup, and if necessary publish a generic required commit status as pending after binding and success or failure after aggregate evaluation. Give the dispatch aggregate check a different display name from the required status context.
4. Keep automatic PR preflight separate and non-required if repository evidence justifies it. Do not let skipped certification jobs report success before the agent requests CI.
5. By default, the agent captures the exact PR head and current default-branch tip, runs and resolves RAS outside GitHub, rechecks both live SHAs, dispatches CI on the same-repository PR branch, inspects the run and required check, rechecks the PR head/base, and merges with an exact-head guard. A new PR commit or default-branch advance invalidates the prior decision and CI result unless the repository explicitly documents and tests merge-base or merge-queue semantics.
6. Keep complete default-branch validation until rulesets prohibit direct pushes; then consider reducing the post-merge run separately.

The expected-SHA guard prevents accidental branch movement; it is not proof of RAS and must not be described as one in workflow state. Under the default trusted-agent/operator model, branch-local workflow code is acceptable. If the user explicitly requires protection from malicious same-repository branch writers, stop and separately design a trusted controller or dedicated check publisher rather than silently changing the architecture.

Adapt this operator handoff to the repository's workflow and inputs:

```sh
gh workflow run <certifying-workflow> --ref <same-repository-pr-branch> -f expected_sha=<exact-pr-head> -f base_sha=<exact-default-branch-head>
```

After dispatch, inspect the run and check suite, re-read the live PR head, and merge only the exact requested head, for example with `gh pr merge --match-head-commit <exact-pr-head>`.

When dispatch cannot satisfy the required PR rollup, adapt this one-shot label handoff instead:

```sh
gh pr edit <pr-number> --repo <owner/repository> --add-label <certification-label>
```

The label and workflow must be generic CI coordination with no RAS meaning. The workflow must subscribe only to the `labeled` PR activity, reject unrelated labels, remove the certification label before checkout, and re-read the live PR to bind its head, base, repositories, and synthetic merge SHA to the event. Prove on live source and documentation PRs that open and synchronize start no run, the label is revoked, and the stable required check appears in the PR rollup.

Task is an optional agent interface, not a GitHub-side RAS gate. A target such as `task validate-pr PR=<n>` may capture the head, run RAS, inspect structured synthesis, recheck the live head, dispatch CI, inspect the run, and merge the same head, but must not request CI merely because `ras review` exited zero.

Do not add labels, webhooks, repository-dispatch integrations, or statuses to communicate the review tool or verdict. A generic required commit-status publisher is permitted when live repository evidence shows that GitHub does not credit dispatched job checks; it must report CI progress/result only, use least-privilege `statuses: write`, link to the dispatched run, use a context distinct from the dispatch aggregate check name, guard terminal publication against cancellation, and fail closed. Because cancellation can race with an already-started status request, reject every cancelled run regardless of visible status. If cancellation leaves pending, follow the workflow run with a bounded wait and request fresh exact-head CI; never convert pending to success for convenience. A persistent operator label is insufficient unless automation revokes it or otherwise SHA-binds it.

## Bootstrap

The migration PR is created while the old default-branch workflow still controls `pull_request`, so opening it may start one last automatic CI run. Before pushing or opening the PR, tell the user and obtain authority either to let that bootstrap run finish or, when the current default-branch workflow already supports dispatch, to cancel it, complete RAS, and dispatch final certification manually. A newly added `workflow_dispatch` trigger generally cannot bootstrap itself before its workflow exists on the default branch. Do not silently spend or cancel Actions minutes.

Existing open PR heads may retain successful required checks produced before the migration. Treat those checks as CI evidence only; enforce the agent-reviewed-current-head policy operationally during rollout.

## Rollout and observation

1. Record the baseline workflow/job count and available usage data.
2. Implement on a feature branch with existing required checks preserved where possible.
3. For agent-gated repositories, verify that PR open/synchronize starts no certifying workflow, then manually validate a docs-only head and a source head after the agent decides each is ready.
4. Change required checks only with explicit authorization after observing actual check names.
5. Observe failures, queue time, and billing for at least several normal development cycles.
6. Tighten path categories only from evidence; fail closed when uncertain.
7. Record the agent-reviewed SHA, dispatched run SHA, required check producer, check conclusion, live PR head before merge, and merged SHA for the first live validation.
8. If dispatch cannot reliably produce a ruleset-credited required result, stop the rollout and repair the generic status bridge or choose another explicit agent-requested trigger. Restore the prior PR trigger only if that matches the user's requested operating model; never weaken or remove the required result merely to unblock merging.

## Exceptions

Document exceptions with the protected behavior, supporting evidence, and review condition. Examples include always scanning all files for secrets, rebuilding committed native libraries on every relevant change, or maintaining default-branch validation because direct pushes remain allowed.
