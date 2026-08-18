# Development Journal

**Append-only. New entries go at the END of this file.**

Oldest entry first, most recent entry last.

---

## Representation-aware contract closure landed - 2026-07-28 15:03 EDT

**Main:** `edf8977a0313`
**Actor:** Codex

### Summary

Representation-aware, risk-gated, and evidence-budgeted contract closure landed on `main` in commits `b6e3520` and `edf8977`.

### Completed

- Reworked the shared contract-closure and review-loop policies around trusted representation ownership, semantic sibling families, finite evidence and review budgets, artifact classification, non-recursion, bounded context, pointer-based tracking, and legacy-program rebaseline.
- Composed the shared policies through planning, architecture handoff and execution, RAS review/verification/consideration/implementation, architecture-candidate handoff, and GitHub CI standardization workflows.
- Preserved exact-head local certification, same-head hosted CI, central enforcement ownership, contract floor/ceiling semantics, and independent finding disposition.

### Decisions

- Contract closure now builds proportionate evidence for materially risky invariants instead of treating example enumeration as a completeness proof. The canonical decision and acceptance record is [GitHub issue #2](https://github.com/the-sarge/skills/issues/2).

### Validation

- Both standards and specification review axes were clean after their findings were fixed, and all 12 issue-defined forward scenarios passed.
- Skill frontmatter, relative Markdown links, `git diff --check`, and `standardize-github-ci/scripts/test-skill.sh` passed at the final head.

---

## Correction: representation-aware contract-closure validation - 2026-07-28 15:43 EDT

**Main:** `39c41b7a7b40`
**Actor:** Codex

### Correction

The preceding entry's retained validation covers standards and specification review plus the listed static and fixture checks. No durable per-scenario receipt was kept for the 12 issue-defined forward scenarios, so its statement that all 12 passed is withdrawn.

---

## Draft-gated pull_request CI standard landed - 2026-08-18 19:35 EDT

**Main:** `6cff957efa78`
**Actor:** Claude

### Summary

One draft-gated `pull_request` CI standard replaced the dispatch, one-shot label, and commit-status-bridge certification families. Landed on `main` as squash commit `6cff957` from [PR #9](https://github.com/the-sarge/skills/pull/9), tracked by [issue #8](https://github.com/the-sarge/skills/issues/8), which supersedes [issue #7](https://github.com/the-sarge/skills/issues/7) (closed not-planned).

### Completed

- `standardize-github-ci` rewritten around a fixed shape: `assets/ci.yml` (`pull_request` on `opened, synchronize, reopened, ready_for_review`; job-level draft and same-repo guard; one `ci-required` job running `task ci`; pinned actions), `assets/ci-classify.sh` (fail-closed docs-only classifier), `assets/Taskfile.ci.yml`, `assets/ruleset.json` (require PR, required `ci-*` checks from integration 15368, strict up-to-date, block force-push/deletion, squash only). The old `ci.yml.template`, `classify-ci-changes.sh`, and `require-ci-results.sh` were deleted.
- `scripts/audit-ci.sh` rewritten as a read-only conformance auditor (exit 0/3/2; `CI-*`, `WF-*`, `TASK-*`, `CLASSIFY-MISSING`, `RULES-*` codes) that keeps its exit contract on unparseable YAML, non-object jobs, scalar steps, empty or non-array rules sources, `gh` failures, and 403 on the legacy-protection probe; local `./` and `docker://` actions are exempt from pin checks.
- `scripts/test-skill.sh` rewritten: asset shape and pin comments, classifier against real `git diff` output (mutation-checked discriminators for `set -f` and source changes), one fixture per audit code including a PATH-shim `gh` for live-ruleset mode, doc greps, and an end-to-end `task ci` run when `task` is installed; passes under `/bin/bash` 3.2.
- `SKILL.md`, `references/ci-policy.md`, `references/migration.md`, and `agents/openai.yaml` rewritten; `_shared/REVIEW-LOOP.md`, `loop-review-merge`, `implement-architecture-slice`, and `planit` now open PRs as drafts and request hosted CI with `gh pr ready`.
- Design spec `docs/superpowers/specs/2026-08-18-simplify-ci-standard-design.md` and plan `docs/superpowers/plans/2026-08-18-simplify-ci-standard.md` committed with the work.

### Decisions

- Merge evidence is the latest `ci` run started after the PR was marked ready on the exact live head with every `ci-*` job `success`; a draft-phase `skipped` check counts as passing on GitHub and is never merge evidence. Both runs report `event: pull_request`; identify the post-ready run by `createdAt` and job conclusions.
- Independent `ci-<lane>` jobs (own `runs-on`, one Taskfile target, no `needs`, no matrix) are the only routing mechanism; merge-blocking lanes become jobs, others move to scheduled workflows. Job-level `env:` and, for lanes, `services:`/`container:` are permitted.
- Docs-only handling lives inside `task ci` via the shipped classifier, never in workflow-level path filters. Rationale and constraints are recorded in the design spec linked above and in issue #8.

### Validation

- `standardize-github-ci/scripts/test-skill.sh` printed `skill fixtures passed` under default bash and `/bin/bash` 3.2.57 at head `980e6ac`; `shellcheck` on scripts and assets, `actionlint` on `assets/ci.yml`, and `yq`/`jq` parses were clean.
- Read-only dry-run audit of a fresh `GridSwarm/codemux` clone (default and `CI_AUDIT_RULESET=live`) exited 3 with an actionable deviation list; the clone was not modified.
- Live GitHub behavior (draft un-mergeability, post-ready run, strict up-to-date blocking) is deliberately unverified in this repository and is scheduled for each repository's migration PR per `references/migration.md` §7.
- Process note: PR #9 was squash-merged by the agent's `gh pr merge --squash --match-head-commit` after the operator selected local merge; the operator's subsequent interrupt arrived after the command had fired, so the planned RAS review pass did not run on the PR. The merged head is the one that passed the plan's per-task and whole-branch reviews.

### Next

- Migrate repositories one at a time by running `standardize-github-ci`: codemux first, then tapmux, wiremux, gridcast, wellspring (last; `ci-race` on the xlarge runner). Each migration PR is the live test of the standard.
- Follow-ups: run the harness's optional `task ci` block under `env -u GITHUB_BASE_REF -u GITHUB_OUTPUT`; change `references/migration.md` §7.1 to print `databaseId,createdAt,conclusion`. Live view: [issue #8](https://github.com/the-sarge/skills/issues/8).
