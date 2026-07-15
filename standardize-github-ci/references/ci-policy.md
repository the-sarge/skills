# Portfolio GitHub CI Policy

## Contents

- [Purpose](#purpose)
- [Responsibility boundary](#responsibility-boundary)
- [Required defaults](#required-defaults)
  - [Stable required gate](#stable-required-gate)
  - [RAS-first certification](#ras-first-certification)
  - [Change classification](#change-classification)
  - [Validation lanes](#validation-lanes)
  - [Event policy](#event-policy)
  - [Concurrency](#concurrency)
  - [Timeouts](#timeouts)
  - [Job ordering](#job-ordering)
  - [Runner policy](#runner-policy)
  - [Duplicate-work policy](#duplicate-work-policy)
  - [Security policy](#security-policy)
  - [Caching and artifacts](#caching-and-artifacts)
  - [Schedules](#schedules)

## Purpose

Reduce GitHub-hosted runner consumption and feedback latency without weakening meaningful correctness, security, platform, or release coverage. Apply these defaults through repository-specific evidence rather than identical workflow files.

## Responsibility boundary

| Layer | Owns |
|---|---|
| GitHub workflow YAML | Events, change routing, runners, dependencies, matrices, concurrency, timeouts, permissions, caches, secrets, schedules, artifacts |
| Taskfile and repository scripts | Portable docs, format, lint, test, race, vulnerability, build, integration, and release commands |
| RAS and operator automation | Review the exact PR head, determine whether blockers remain, and request certification only for the reviewed head |
| GitHub settings | Required checks, rulesets, Actions budgets, runner groups, secrets, variables, permissions |

## Required defaults

### Stable required gate

Keep one required check with a stable name such as `ci-required`. Let it validate the results of conditional jobs. Avoid requiring every conditional platform or security job separately. In an automatically triggered workflow, create it for every relevant event; in a RAS-first workflow, create it only during explicit certification and deliberately let its absence on a new PR head block merging before dispatch.

Prefer one required job with conditional steps when all required validation can run on one runner. When required validation spans conditional or runner-specific jobs, put `ci-required` last, declare every contributing job in `needs`, and fail unless every required result succeeded or was intentionally skipped.

Do not rely only on workflow-level `paths` or `paths-ignore` for a required workflow. An entirely skipped required workflow may remain pending. A conditionally skipped job reports success, making job-level routing safer for required checks.

### RAS-first certification

When RAS is the repository's designated pre-merge review gate, use this cost-first sequence by default:

```text
push PR head -> RAS reviews that head -> resolve blockers -> dispatch certifying CI for the blocker-free head -> required check -> merge
```

Do not start the certifying workflow automatically on `pull_request` or `pull_request_target` merely to make the required check appear. A new head without the required check is safely unmergeable. Preserve a manual or operator-driven dispatch path, verify that the workflow run head SHA equals the RAS-reviewed SHA, and require a fresh RAS decision plus certification after any new push.

An automatic preflight may remain when its early signal justifies its cost, but it must be cheap, must not launch the expensive certification graph, and must not emit or accidentally satisfy the required certification check. Do not use a skipped required job as a pending gate.

A Task target may standardize RAS invocation and CI dispatch, but it is optional. A successful `ras review` process exit does not mean the synthesis has no blockers; any wrapper must inspect the structured run result or an explicit RAS gate verdict. Persistent labels are not exact-head approvals unless automation revokes or SHA-binds them.

### Change classification

Classify at least:

- docs-only;
- source;
- dependencies;
- workflows or CI scripts;
- platform-sensitive code;
- release configuration.

Fail closed: an unknown path is source-affecting until repository evidence admits it to a cheaper class. Treat an empty or indeterminate diff as source-affecting.

### Validation lanes

Prefer these conceptual Taskfile lanes, adapting established names rather than renaming gratuitously:

| Lane | Typical content |
|---|---|
| `docs-check` | Whitespace, Markdown links, frontmatter, generated-doc freshness, docs-specific tests |
| `check` | Formatting, vet, unit tests, ordinary lint, build smoke |
| `deep-check` | Race, integration, vulnerability, native platforms, long contracts, bounded fuzzing |
| `release-check` | Packaging, artifact/SBOM/signing metadata, release-specific validation |

Do not place every possible check in the PR lane merely because one Taskfile task can aggregate them.

### Event policy

| Event | Default behavior |
|---|---|
| Pull request without RAS | Complete merge gate selected by changed files |
| Pull request with RAS | No automatic certifying CI; optional cheap preflight only, then exact-head certification after RAS has no blockers |
| Protected default-branch push | Deployment or reduced smoke; do not repeat the identical full PR suite |
| Direct default-branch push | Complete validation only when direct pushes are possible and intentionally supported |
| Schedule | Time-sensitive security, deep race/integration, native platform, bounded fuzzing |
| Manual dispatch | Exact-head RAS-approved certification, exceptional diagnostics, proofs, or operator-selected deep work |
| Tag/release | Release validation and publication |

Verify protection and merge behavior before dropping default-branch validation. If the workflow cannot distinguish protected PR merges from direct pushes reliably, keep a defensible default-branch gate or eliminate direct pushes through rulesets.

### Concurrency

Cancel superseded automatic pull-request work within each workflow. For RAS-first repositories, avoid starting certifying work before review; also prevent duplicate dispatches for the same ref when cancellation is safe. Keep workflow names in concurrency groups so unrelated workflows do not cancel one another. Do not cancel release publication or stateful deployment work unless its recovery model explicitly permits it.

### Timeouts

Set every job timeout. Suggested starting points:

- classification, docs, and workflow lint: 5 minutes;
- ordinary build, test, and lint: 10–20 minutes;
- integration and native platform: 20–30 minutes;
- fuzzing: explicit bounded work duration plus controlled overhead.

Use repository evidence to adjust these numbers. A timeout is a containment boundary, not a performance target.

### Job ordering

After any RAS gate, run cheap, broad failure detectors before expensive matrices:

```text
classify -> Linux/core verify -> security, native platform, integration, deep contracts
```

Avoid launching macOS, Windows, CodeQL, and long contracts alongside a basic build that may fail immediately.

### Runner policy

- Use Linux as the ordinary hosted PR runner.
- Use Linux cross-compilation for pure-Go Darwin and Windows compilation when it provides the required signal.
- Run native macOS and Windows only for platform-sensitive changes, schedules, or releases unless the repository proves broader need.
- Apply routing to self-hosted jobs too; they consume machines and queue capacity even when GitHub does not bill runner minutes.
- Do not treat public-repository hosted usage as a private-minute hotspot, but still reduce noise and latency.

### Duplicate-work policy

Justify rather than assume value from:

- `go test ./...` followed by the same suite under `-race`;
- vulnerability scanning in both the main gate and a dependency workflow;
- OS-independent lint on multiple operating systems;
- repeated checkout, toolchain, private-module, or tool installation across independent jobs;
- per-binary builds followed by an all-package build;
- complete PR validation followed by complete validation of the identical merged commit;
- complete certification on every intermediate head that RAS later blocks or supersedes;
- two fuzz systems covering the same targets on the same cadence.

Keep duplicated execution only when it produces a distinct signal or materially improves feedback time at acceptable cost.

### Security policy

Separate event-sensitive and time-sensitive coverage:

- run dependency review when manifests or lockfiles change;
- run SAST and CodeQL when source or their configuration changes;
- scan changed PR content for secrets, including documentation;
- run full vulnerability, SAST, and secret-history scans on a schedule because external advisories change without repository commits.

Do not skip secret scanning merely because a change is documentation-only; documentation can contain credentials.

### Caching and artifacts

Cache immutable dependency downloads when repository policy permits it. Do not cache outputs whose clean deterministic rebuild is the assertion. Set explicit short artifact retention for disposable proof, corpus, or diagnostic artifacts.

### Schedules

Stagger schedules away from the top of the hour and across repositories. Give every scheduled workflow a concurrency policy and timeout. Disable redundant schedules in legacy or superseded repositories.
