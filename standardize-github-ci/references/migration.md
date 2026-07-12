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

## Rollout and observation

1. Record the baseline workflow/job count and available usage data.
2. Implement on a feature branch with existing required checks preserved where possible.
3. Verify a docs-only PR and a source PR before changing rulesets.
4. Change required checks only with explicit authorization after observing actual check names.
5. Observe failures, queue time, and billing for at least several normal development cycles.
6. Tighten path categories only from evidence; fail closed when uncertain.

## Exceptions

Document exceptions with the protected behavior, supporting evidence, and review condition. Examples include always scanning all files for secrets, rebuilding committed native libraries on every relevant change, or maintaining default-branch validation because direct pushes remain allowed.
