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

---

## needs: narrowed to cross-runner artifact exchanges - 2026-08-19 10:57 EDT

**Main:** `fe632fd4cb33`
**Actor:** Claude

### Summary

The CI standard's blanket `needs:` ban was narrowed to the hazard it guarded against. Landed on `main` as squash commit `fe632fd` from [PR #11](https://github.com/the-sarge/skills/pull/11), a follow-up to [issue #8](https://github.com/the-sarge/skills/issues/8) prompted by the wellspring audit, whose portability test builds bundles natively on Linux, macOS, and Windows and verifies each on every other OS in the same run.

### Completed

- `standardize-github-ci/references/ci-policy.md` and the design spec now permit `needs:` only for a cross-runner artifact exchange: a destination `ci-<lane>` job (never `ci-required`) may depend on origin `ci-*` jobs in the same `ci.yml`; every node is a required check in its own right; the destination keeps the standard guard and calls no status function; artifacts move with SHA-pinned upload/download-artifact steps; no job uses the `needs` context for anything but `needs.<job>.outputs.<name>`. Matrices stay forbidden; committed fixtures are a backward-compatibility test for a non-required workflow, not a substitute.
- `scripts/audit-ci.sh`: `CI-NEEDS` enforces the exception (destination-only, literal `ci-*` targets present in the file, no self-edge, case-insensitive and whitespace-tolerant rejection of `always()`/`failure()`/`cancelled()`/`success()`), reports artifact-exchange edges, and a new `CI-AGGREGATE` fails closed on any non-outputs use of the `needs` context across `${{ }}` fragments (spanning lines) and job- and step-level `if` values.
- `scripts/test-skill.sh`: fixtures for each `CI-NEEDS` rejection, seven `CI-AGGREGATE` spellings (dotted, bracketed, wildcard, `toJSON(needs)`, unwrapped `if`, multi-line, bare `.outputs`), an inert-text/named-outputs control, and a conformant forward-referenced two-origin exchange with pinned artifact steps; policy, asset-header, SKILL.md, and spec greps.
- `assets/ci.yml` header, `SKILL.md` Apply allowlist, and `references/migration.md` §1.2/§3.1 aligned.

### Decisions

- A standard should forbid the hazard, not the syntax: fail-closed depends on every job that matters being individually required, which `RULES-CHECKS` already enforces; `needs:` between individually required `ci-*` jobs preserves it, while aggregate jobs and any dependency-result read do not. Rationale in the spec's Required jobs section (amended 2026-08-19) and PR #11.
- Rejected: parsing GitHub expression grammar to avoid a false positive on a string literal that spells a needs-result access; the audit stays a canonical-subset checker and fails closed there.

### Validation

- Round 1 RAS review (run `20260819T135451`) and three verifications at `893adb9`, `3f62de0`, `05d657e`; replacement review (run `20260819T143925`) at `c99ece6` found one distinct root (`!success()` skip-after-green), fixed in `4f5a549`; the review-round override is recorded here.
- `standardize-github-ci/scripts/test-skill.sh` printed `skill fixtures passed` under default bash and `/bin/bash` 3.2 at `4f5a549`; shellcheck and actionlint clean.
- Deferred with reason: `continue-on-error` on `ci-*` jobs is unaudited and its effect on the published check needs a hosted observation before a rule is added.

### Next

- Sync the changed skill into dotfiles; then migrate repositories starting with codemux, and wellspring last using the exchange exception for its portability lanes. Live view: [issue #8](https://github.com/the-sarge/skills/issues/8).

---

## Audit flags non-required workflows that run task ci - 2026-08-19 11:31 EDT

**Main:** `1b8774eb8613`
**Actor:** Claude

### Summary

`standardize-github-ci` now catches the gap ai-cli hit after its migration ([ai-cli #818](https://github.com/the-sarge/ai-cli/issues/818)): once `task ci` means "fast PR merge gate", any other caller — notably `release.yml` — silently validates less than before. Landed on `main` as squash commit `1b8774e` from [PR #13](https://github.com/the-sarge/skills/pull/13).

### Completed

- `scripts/audit-ci.sh`: new `WF-TASK-CI` deviation when a non-required workflow's run steps invoke `task ci` or `task ci-<lane>` (word-boundary scan that also covers redirects, backticks, and multi-line scripts); the message names the targets found and points at purpose-named targets such as `release-gate` or `nightly`.
- `references/migration.md`: §1.5 inventories every caller of a Taskfile target the migration renames or redefines; §2 maps each caller to its purpose-named target and body; §3.5 defines those targets and repoints the callers. `references/ci-policy.md` (non-required workflows) and `SKILL.md` (audit summary) state the same rule.
- `scripts/test-skill.sh`: release-workflow fixture (`task ci`, `task ci-race`, `task ci>/dev/null`, backticked `task ci-portable-linux`, plus `task cicd`/`task ci_fast`/`task ci-` negatives) → `WF-TASK-CI`; repointed to `release-gate`/`nightly` → conformant; section-specific prose greps for policy, SKILL.md, migration §2 and §3.

### Decisions

- `ci` and `ci-<lane>` are PR-only targets by definition (classified against a PR merge base that does not exist on a tag or schedule). Release and scheduled workflows get purpose-named targets; the recommended release composition is `check` + `deep-check` + `sast`, with bounded fuzzing left to the nightly when it would make releases slow or flaky. Recorded in PR #13 and ai-cli #818.

### Validation

- RAS review run `20260819T150901` (7 findings: 4 fix-now, 3 rejected as unsupported/duplicate); verification at `735da62` cleared all clusters with one low coverage nit fixed in `5f8a00d` without another RAS cycle (docs/test-only policy).
- `standardize-github-ci/scripts/test-skill.sh` printed `skill fixtures passed` under default bash and `/bin/bash` 3.2; shellcheck and actionlint clean.

### Next

- Sync the skill into dotfiles; apply the caller inventory when migrating codemux → tapmux → wiremux → gridcast → wellspring. Live view: [issue #8](https://github.com/the-sarge/skills/issues/8).

---

## Release gate named: task release-gate - 2026-08-19 12:24 EDT

**Main:** `7ec1da262bdc`
**Actor:** Claude

### Summary

The release gate now has a fixed name: every tag-push release workflow runs `task release-gate`. Landed on `main` as squash commit `7ec1da2` from [PR #15](https://github.com/the-sarge/skills/pull/15), completing the caller-inventory change from PR #13 so `release.yml` reads the same in every repository.

### Completed

- `references/ci-policy.md` and `references/migration.md`: tag-push release workflows run `task release-gate` (repository-owned; recommended `check` plus the deep checks the PR gate skips — race, vulnerability scan, SAST — with bounded fuzzing left to the nightly when slow or flaky); scheduled workflows use `nightly` or a descriptive name (not mandated, since several per repository is normal). `SKILL.md` audit guidance names the target.
- `assets/Taskfile.ci.yml`: `release-gate` task placeholder (`check` + deep-check placeholder).
- `scripts/audit-ci.sh`: `WF-RELEASE-GATE` when a `push: tags` workflow has no run step invoking `task release-gate`; `TASK-RELEASE-GATE-MISSING` when such a workflow exists and the Taskfile lacks the target or is absent. Repositories without a tag-push workflow are unaffected.
- `scripts/test-skill.sh`: fixtures for all three cases plus the no-release control; discriminating policy/migration/SKILL.md greps (proved not to match the base document).

### Decisions

- Tag-push detection is the canonical subset `.on.push.tags`; `tags-ignore`-only and `on: release` triggers are a separate, deliberate expansion if a repository turns out to use them (RAS review C-001/C-008, rejected as out of the declared domain, recorded here as a follow-up).

### Validation

- RAS review run `20260819T155818` (8 findings: 3 fix-now, 5 rejected as duplicate/out-of-domain); verification at `21e6d7f` cleared all clusters with no new concerns.
- `standardize-github-ci/scripts/test-skill.sh` printed `skill fixtures passed` under default bash and `/bin/bash` 3.2; shellcheck, actionlint, and `yq` clean; `task release-gate` runs from the asset.

### Next

- Sync the skill into dotfiles; migrate codemux → tapmux → wiremux → gridcast → wellspring, defining `release-gate` wherever a tag-push workflow exists. Live view: [issue #8](https://github.com/the-sarge/skills/issues/8).

---

## WF-TIMEOUT exempts reusable-workflow callers - 2026-08-19 13:15 EDT

**Main:** `40adb8ce41fa`
**Actor:** Claude

### Summary

Audit false positive fixed: `WF-TIMEOUT` no longer flags a job that only calls a reusable workflow (`jobs.<id>.uses`), which cannot carry `timeout-minutes`. Surfaced by the wellspring audit (`portable_storage` caller). Landed on `main` as squash commit `40adb8c` from [PR #17](https://github.com/the-sarge/skills/pull/17).

### Completed

- `scripts/audit-ci.sh`: the exemption applies only to a non-empty string job-level `uses`; scalar job values and `uses: null` / `""` / non-string remain flagged (fail closed).
- `references/ci-policy.md`: the timeout sentence for non-required workflows is qualified accordingly.
- `scripts/test-skill.sh`: reusable-caller job in the conformant scheduled fixture; a malformed-`uses` workflow asserting `WF-TIMEOUT` names `scalar_job, null_uses, empty_uses, numeric_uses` and spares the valid caller; policy grep.

### Validation

- RAS review run `20260819T170101` (6 findings: 3 fix-now, 3 duplicates); verification at `73ed153` cleared with no new concerns. `test-skill.sh` passed under default bash and `/bin/bash` 3.2; shellcheck clean.

### Next

- Sync to dotfiles; wellspring re-audit, then a plan that applies the two-part choice rule (own runner or timeout) and path-gated `ci-<lane>` targets instead of 20+ required jobs. Live view: [issue #8](https://github.com/the-sarge/skills/issues/8).

---

## Path-gated ci-<lane> targets and NUL-safe classifier - 2026-08-19 14:04 EDT

**Main:** `af9f4d4cea4a`
**Actor:** Claude

### Summary

Path-gated `ci-<lane>` targets are now a concrete mechanism, and the classifier handles non-ASCII and newline-bearing pathnames correctly. Landed on `main` as squash commit `af9f4d4` from [PR #19](https://github.com/the-sarge/skills/pull/19), prompted by two wellspring audits that read the standard as "fine-grained per-path lane selection is lost".

### Completed

- `assets/ci-classify.sh`: second mode — with `CI_MATCH_GLOBS` set (even empty) it prints `matches=true|false` (any changed file matches; fails closed to `true`, including on an empty value, a missing base, an empty diff, git failure, or `mktemp` failure). Pathnames are read NUL-delimited with `core.quotePath=false` in both modes, fixing a pre-existing docs-mode bug where a quoted non-ASCII path (e.g. `naïve.md`) was treated as not documentation.
- `assets/Taskfile.ci.yml`: `ci-platform` example lane gated by `CI_PLATFORM_GLOBS`, plus a `platform` placeholder body.
- `references/ci-policy.md`: Taskfile contract describes path-gated lanes; the choice rule is now three-way (own runner/timeout → `ci-<lane>`; same runner → fold into `task check`; not merge-blocking → non-required); Runners section carries the hosted-runner rule (a required job starts its runner on every non-draft same-repo PR run, docs-only included, so hosted — especially macOS/Windows — lanes belong in `release-gate` or a schedule unless genuinely merge-blocking). `references/migration.md` §1.2/§2/§3.3 and `SKILL.md` Audit carry the same rule, the glob variable per gated lane, and a hosted-runner count.
- `scripts/test-skill.sh`: match-mode fixtures (match, no match, no base, empty diff, empty value, `GITHUB_OUTPUT`, one line, `mktemp` failure), odd-pathname fixtures in both modes, asset and prose greps, and an end-to-end `task ci-platform` run (not-applicable vs. lane body) when `task` is installed.

### Decisions

- Match mode is selected by variable presence, not content, so an undefined Taskfile variable fails closed (the lane runs) rather than silently switching to docs mode.
- The classifier does not support negation or gitignore-style semantics; lanes declare positive globs only.

### Validation

- RAS review run `20260819T173834` (9 findings: 6 fix-now incl. the quoted-pathname bug, 3 duplicates); verification at `e7cc9e3` cleared with one low concern (`mktemp` guard) fixed in `7d0cabc` without another cycle. `test-skill.sh` passed under default bash and `/bin/bash` 3.2; shellcheck, actionlint, yq clean.

### Next

- Sync to dotfiles. Already-migrated repositories (codemux, tapmux, gridcast) carry the older `ci-classify.sh`; re-copy it from the asset on their next touch so non-ASCII documentation paths classify correctly. Wellspring plan guidance issued (codec matrices off the PR gate, hosted-Linux lanes collapsed, path-gated lanes, standard checkout with `sparse-checkout`). Live view: [issue #8](https://github.com/the-sarge/skills/issues/8).

---

## Correction: path-gated lanes validation SHA - 2026-08-19 14:04 EDT

**Main:** `4843796510c2`
**Actor:** Claude

### Correction

The preceding entry's Validation line says the `mktemp` guard was "fixed in `7d0cabc`". That SHA is the previous journal commit (#18), not the fix. The guard was PR #19's last branch commit `8170aa9`, which landed inside squash commit `af9f4d4`.
