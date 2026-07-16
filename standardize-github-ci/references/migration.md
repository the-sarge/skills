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
10. Can `workflow_dispatch` or an equivalent operator trigger produce the required GitHub-Actions check on a same-repository PR head?

## Minimal RAS-first migration

Use this pattern when RAS must settle before paid certification and the user has not requested a more elaborate integration:

1. Preserve the stable required check and its result aggregation.
2. Remove automatic open and synchronize certification from `pull_request` and `pull_request_target`; remove event-specific branches that become unreachable.
3. Preserve or add `workflow_dispatch` with a full or otherwise fail-closed certification mode. Bind dispatch to the RAS-reviewed SHA with an expected-SHA input and an early equality check when practical; otherwise verify the resulting run's head SHA before accepting it. If live proof shows that dispatch checks do not satisfy the required PR rollup, use a one-shot operator-only PR activity as the fallback and bind its event to the live same-repository head, base, and synthetic merge SHAs.
4. Keep automatic PR preflight separate and non-required if repository evidence justifies it. Do not let skipped certification jobs report success before RAS.
5. After a blocker-free RAS synthesis, invoke the proven operator trigger for the same-repository PR. A new push invalidates both the RAS decision and required check because both belong to the old SHA.
6. Keep complete default-branch validation until rulesets prohibit direct pushes; then consider reducing the post-merge run separately.

Adapt this operator handoff to the repository's workflow and inputs:

```sh
gh workflow run <certifying-workflow> --ref <same-repository-pr-branch> -f expected_sha=<ras-reviewed-head> -f base_sha=<reviewed-base>
```

After dispatch, inspect the run and check suite rather than assuming the branch reference stayed unchanged.

When dispatch cannot satisfy the required PR rollup, adapt this one-shot label handoff instead:

```sh
gh pr edit <pr-number> --repo <owner/repository> --add-label <certification-label>
```

The label workflow must subscribe only to the `labeled` PR activity, reject unrelated labels, remove the certification label before checkout, and re-read the live PR to bind its head, base, repositories, and synthetic merge SHA to the event. Prove on live source and documentation PRs that open and synchronize start no run, the label is revoked, and the stable required check appears in the PR rollup.

Task is an optional operator interface, not the gate itself. A target such as `task certify-pr PR=<n>` may capture the head, run RAS, inspect structured synthesis, recheck the live head, and dispatch CI, but must not chain CI merely because `ras review` exited zero.

Do not add labels, webhooks, repository-dispatch integrations, or custom status publishers unless the user wants operator coordination or repository evidence requires enforcement beyond the required check. A persistent label is insufficient unless automation revokes it or otherwise SHA-binds it.

## Bootstrap

The migration PR is created while the old default-branch workflow still controls `pull_request`, so opening it may start one last automatic CI run. Before pushing or opening the PR, tell the user and obtain authority either to let that bootstrap run finish or, when the current default-branch workflow already supports dispatch, to cancel it, complete RAS, and dispatch final certification manually. A newly added `workflow_dispatch` trigger generally cannot bootstrap itself before its workflow exists on the default branch. Do not silently spend or cancel Actions minutes.

Existing open PR heads may retain successful required checks produced before the migration. Treat those checks as CI evidence only; enforce the RAS-current-head policy operationally during rollout.

## Rollout and observation

1. Record the baseline workflow/job count and available usage data.
2. Implement on a feature branch with existing required checks preserved where possible.
3. For RAS repositories, verify that PR open/synchronize starts no certifying workflow, then manually certify a docs-only head and a source head after blocker-free RAS results.
4. Change required checks only with explicit authorization after observing actual check names.
5. Observe failures, queue time, and billing for at least several normal development cycles.
6. Tighten path categories only from evidence; fail closed when uncertain.
7. Record the reviewed SHA, dispatched run SHA, required check producer, and check conclusion for the first live certification.
8. Roll back by restoring the prior PR trigger if dispatch cannot reliably produce the required check; do not weaken or remove the required check merely to unblock merging.

## Exceptions

Document exceptions with the protected behavior, supporting evidence, and review condition. Examples include always scanning all files for secrets, rebuilding committed native libraries on every relevant change, or maintaining default-branch validation because direct pushes remain allowed.
