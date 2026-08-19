# CI Migration Checklist

Migrate one repository at a time to the [portfolio CI standard](ci-policy.md). Every step below is either read-only, a change on the migration branch, or an explicitly authorized external mutation.

## 1. Inventory (read-only)

1. Run `scripts/audit-ci.sh <repo>` and, when `gh` can read the repository, `CI_AUDIT_RULESET=live scripts/audit-ci.sh <repo>`. Keep the deviation list; it is the work list.
2. List every workflow and every job's Taskfile target(s). For each lane decide: merge-blocking today **and** needing its own runner or timeout → its own `ci-<lane>` job; merge-blocking on the same runner as `check` → fold into `task check`; not merge-blocking → a non-required workflow on `schedule`, `push: tags`, or `workflow_dispatch`. A lane the current workflow ran only for certain paths stays conditional by being path-gated inside its `ci-<lane>` target (`CI_MATCH_GLOBS`, see ci-policy.md Taskfile contract) — do not write that per-path selection is lost. Count GitHub-hosted runners (especially macOS and Windows) separately: a required lane on a hosted runner spins up on every non-docs PR even when path-gated, so prefer self-hosted labels for required lanes and move hosted platform matrices to the release gate or a scheduled workflow unless they are genuinely merge-blocking. A lane that must consume an artifact produced on a different runner in the same run (a cross-runner exchange) becomes origin `ci-*` jobs plus destination `ci-<lane>` jobs (never `ci-required`) that `needs:` them — under the conditions in [ci-policy.md](ci-policy.md#required-jobs); record the graph in the plan.
3. Record the current required check names and whether the default branch uses a ruleset or legacy branch protection (`gh api repos/<o>/<r>/rules/branches/<default>`, `gh api repos/<o>/<r>/branches/<default>/protection`).
4. Record which jobs run on self-hosted labels; those labels move to `runs-on` of the corresponding `ci-*` job.
5. Grep every workflow, script, Taskfile, and doc for every caller of a Taskfile target that the migration renames or redefines (`task ci` becomes the fast PR gate; `check`/`docs-check` may absorb old lanes). Decide each caller explicitly. Every tag-push release workflow calls `task release-gate` (define it from `assets/Taskfile.ci.yml`: `check` plus the deep checks the PR gate skips); scheduled workflows call `nightly` or another descriptive name; none call `task ci` or `task ci-<lane>`: those classify against a PR merge base that does not exist on a tag or schedule and are deliberately the narrow gate, so a release that keeps calling `task ci` silently validates less than before (the audit reports this as `WF-TASK-CI`).

## 2. Plan (no edits)

Produce, per repository: the mapping from old jobs to `ci-required` / `ci-<lane>` / non-required workflows; the `runs-on` per job; the `task check` and `task docs-check` bodies (existing lanes renamed, not rewritten); any `CI_DOCS_GLOBS` extension; the ruleset diff including any `ci-<lane>` contexts to add; and the bootstrap note below; and, for every caller found in §1.5, the purpose-named target it will call (`release-gate` for tag-push workflows — `check` plus the repository's deep checks; `nightly` or a descriptive name for scheduled ones) and the body of that target.

## 3. Apply (on a feature branch, after approval)

1. Copy `assets/ci.yml` to `.github/workflows/ci.yml`; set `runs-on`; add `ci-<lane>` jobs by duplicating `ci-required` and changing only the job name, `runs-on`, `timeout-minutes`, the `task ci-<lane>` step, and any job-level `env:`/`services:` the lane needs. For a cross-runner exchange, add `needs:` on the destination `ci-<lane>` jobs only, listing origin `ci-*` jobs by name, and move artifacts with SHA-pinned `actions/upload-artifact` / `actions/download-artifact` steps; never read `needs.<job>.result` or `toJSON(needs)`.
2. Copy `assets/ci-classify.sh` to `scripts/ci-classify.sh` unchanged and make it executable.
3. Merge `assets/Taskfile.ci.yml` into `Taskfile.yml`: add `ci`, `docs-check`, `check`, and one `ci-<lane>` per extra job; point `check` and `docs-check` at the repository's existing commands.
4. Remove `pull_request` and `pull_request_target` from every other workflow; delete workflows that only existed to certify PRs (dispatch/label/status-bridge workflows). Keep deep, security, fuzz, cross-platform, and release workflows on their non-PR triggers, pinned and with timeouts.
5. Define the purpose-named targets planned in §2 in `Taskfile.yml` and repoint every caller from §1.5 (`task ci` / `task ci-<lane>` in release or scheduled workflows, scripts, docs) to them; rename steps whose names no longer describe what runs.
6. Run `task ci` locally on the branch (expect the docs-only or full path as appropriate); run `scripts/audit-ci.sh .` and expect `- None. Repository conforms to the standard.`; then run `CI_AUDIT_RULESET=live scripts/audit-ci.sh .` and expect only `RULES-*` deviations before the ruleset is applied and none after.
7. Commit. Do not open the PR yet.

## 4. Bootstrap warning

Opening the migration PR may start one last automatic run of an old workflow, but only from a trigger the branch cannot switch off. For `pull_request` GitHub reads the workflow definition from the PR's merge ref, so an old `pull_request` workflow the branch deletes does not run; what can still start is a base-branch `push` or `pull_request_target` workflow, or an old `pull_request` workflow the branch keeps. Tell the operator before pushing and obtain an OK either to let it finish or to cancel it. Never silently spend or cancel Actions minutes.

## 5. Open the migration PR as a draft

```sh
git push -u origin <branch>
gh pr create --draft --title "ci: adopt portfolio CI standard" --body "<summary of the mapping>"
```

While the PR is a draft, `ci.yml` runs but every `ci-*` job is skipped by the draft guard (the check shows `skipped`; a draft cannot be merged regardless). The old default-branch workflow may still run, see §4.

## 6. Apply the ruleset (external mutation, needs explicit authorization)

1. Edit a copy of `assets/ruleset.json` to list every `ci-*` job as a required check.
2. Create it: `gh api --method POST repos/<o>/<r>/rulesets --input <copy>.json`. If a ruleset for the default branch already exists, `gh api repos/<o>/<r>/rulesets` to find its id and `--method PUT repos/<o>/<r>/rulesets/<id>` instead.
3. Remove legacy branch protection when present: `gh api --method DELETE repos/<o>/<r>/branches/<default>/protection`.
4. Re-run `CI_AUDIT_RULESET=live scripts/audit-ci.sh .` and expect no `RULES-*` deviations.

Until the migration PR merges, the *old* required check names may still be referenced by open PRs; that is expected and resolves as they update.

## 7. Verify on the migration PR (this is the live test of GitHub behavior)

1. Draft: `gh pr view --json isDraft,mergeable` shows draft; `gh run list --workflow ci.yml --branch <branch> --json event,conclusion` shows the run(s) with every `ci-*` job skipped (`gh run view <id> --json jobs`), and the PR cannot be merged.
2. `gh pr ready`. Expect a new `ci` run on the live head (both runs show `event: pull_request`; the new one has a later `createdAt`) whose head SHA equals `gh pr view --json headRefOid` and in which every `ci-*` job reports `success` in `gh run view <id> --json jobs`, not `skipped`.
3. Push a docs-only commit (for example a line in `DEV-JOURNAL.md` or `docs/`). Expect the run's `ci-required` log to show `task docs-check` ran and no `task check`.
4. Push a source commit. Expect `task check` to run.
5. If possible, land an unrelated change on the default branch and confirm `gh pr view --json mergeStateStatus` becomes `BEHIND` and the merge button is blocked until `gh pr update-branch` (or a rebase) re-runs CI.
6. Confirm the merge is blocked while any `ci-*` check is pending or failed.
7. Confirm the merge rule end to end: immediately after `gh pr ready` and before the new run completes, `gh pr checks` may still show the draft-phase `skipped` check — record that this is not accepted as merge evidence; merge only after the latest post-ready `ci` run on the live head reports `success` for every `ci-*` job.

Record head SHAs, run ids, and check names for each observation in the PR description.

## 8. Merge

`gh pr merge --squash --match-head-commit <live-head-sha>`. Then run the repository's usual post-merge steps (journal, tracking).

## Rollback

Restore the previous workflow files and required-check names from the pre-migration commit; rulesets can be updated with `--method PUT` to the previous check list. Never weaken or remove the required check merely to unblock a merge.
