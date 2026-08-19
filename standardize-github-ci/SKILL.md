---
name: standardize-github-ci
description: Bring one repository onto the portfolio CI standard — a draft-gated pull_request workflow with independent ci-* required jobs that each run one Taskfile target, a docs-only shortcut inside task ci, and one squash-only default-branch ruleset — through read-only audit, approval-gated planning and implementation, and verification. Use for CI audits, workflow or Taskfile refactors, ruleset standardization, or when PR merging behaves differently across repositories.
---

# Standardize GitHub CI

Converge one repository at a time onto the standard in [references/ci-policy.md](references/ci-policy.md). The standard is a fixed shape, not a menu: identical `ci.yml`, identical ruleset, repository-owned Taskfile bodies. Do not adapt the shape to repository evidence; adapt the repository to the shape and record any genuinely impossible case as a documented exception for the operator to decide.

## Trust and review boundary

GitHub carries no review-tool state. The agent opens PRs as drafts, reviews out of band, marks the PR ready (`gh pr ready`) when local certification passes, waits for a `ci` run triggered after the PR was marked ready to succeed on the live head (a draft-phase `skipped` check is never merge evidence), and merges that head with a squash. Draft status is the only signal and means "not ready for CI".

## Choose the mode

Infer the narrowest authorized mode. Default to `audit` when the request is ambiguous.

- `audit`: run the conformance audit and report deviations; no edits.
- `plan`: produce the per-repository mapping and checklist from [references/migration.md](references/migration.md); no edits.
- `apply`: implement an approved plan on a feature branch or worktree and validate it.
- `verify`: re-run the audit (including live rules) against a migrated repository and confirm the live-PR observations were recorded; do not expand into unrelated fixes.

Never treat an audit or plan request as authorization to edit files, change GitHub settings, open a PR, push, cancel or rerun workflows.

## Load policy and instructions

1. Read repository `AGENTS.md` / `CLAUDE.md` files that govern the target paths.
2. Read [references/ci-policy.md](references/ci-policy.md) completely in every mode.
3. Read [references/migration.md](references/migration.md) completely in `plan`, `apply`, and `verify` modes.
4. Read the shared [review-loop](../_shared/REVIEW-LOOP.md) baseline in `apply` and `verify` modes; the migration PR goes through it like any other PR.
5. Run `scripts/audit-ci.sh <repository-path>` (add `CI_AUDIT_RULESET=live` when `gh` can read the repository). Treat the deviation list as the work list.
6. Treat the current GitHub default branch as authoritative when the checkout may be stale; use read-only `gh` queries rather than fetching into or modifying a user worktree.

## Audit

Report the audit output plus:

- every workflow's current triggers and which lanes it runs, the proposed destination of each lane (`ci-required`, `ci-<lane>`, or a non-required workflow), and every caller of a Taskfile target the migration renames or redefines (release and scheduled workflows need purpose-named targets, never `task ci` or `task ci-<lane>`);
- self-hosted runner labels in use;
- the current required check names and whether enforcement is a ruleset or legacy protection;
- anything the standard cannot express for this repository, stated as an exception with evidence.

Do not present self-hosted work as billed minutes. Include "no change needed" findings.

## Plan

Follow §1–§2 of [references/migration.md](references/migration.md). The plan lists the file-level changes, the `runs-on` per job, the Taskfile bodies (existing commands renamed into `check` / `docs-check`, not rewritten), the ruleset diff, the bootstrap warning, and the verification observations that will be recorded on the migration PR.

## Apply

Proceed only when the user explicitly asks to implement or has approved the plan. Follow §3–§8 of [references/migration.md](references/migration.md) in order. In particular:

- work in an isolated worktree and feature branch;
- copy assets verbatim ([assets/ci.yml](assets/ci.yml), [assets/ci-classify.sh](assets/ci-classify.sh), [assets/Taskfile.ci.yml](assets/Taskfile.ci.yml), [assets/ruleset.json](assets/ruleset.json)); do not hand-edit the workflow beyond `runs-on`, `ci-<lane>` jobs, job-level `env:`/`services:` a lane needs, and, for a cross-runner artifact exchange, `needs:` on destination `ci-<lane>` jobs plus SHA-pinned `actions/upload-artifact` / `actions/download-artifact` steps (the single `task` run step stays);
- keep the diff scoped to CI standardization;
- obtain explicit authorization before every external mutation (ruleset create/update, legacy protection removal, cancelling or rerunning a workflow, opening the PR);
- open the migration PR as a draft and warn about the bootstrap run first.

## Validate

1. Run `scripts/audit-ci.sh .` and expect `- None. Repository conforms to the standard.`; then run `CI_AUDIT_RULESET=live scripts/audit-ci.sh .` and expect only `RULES-*` deviations before the ruleset is applied and none after.
2. `actionlint .github/workflows/ci.yml` passes; every edited YAML parses.
3. `task ci` runs locally on a docs-only diff and on a source diff and takes the expected path.
4. The live-PR observations in migration §7 are performed and recorded in the PR description.
5. Run the migration PR through the shared review loop before marking it ready.

Do not claim minutes are saved merely because YAML parses; state which jobs no longer start on which events.

## Deliver

State: mode completed; files or settings changed; validation performed and unavailable validation; expected runner-minute effect (no `ci-*` job runs during the draft phase — the workflow starts and every job is skipped; docs-only PRs run `docs-check` only); required operator follow-up; remaining exceptions.
