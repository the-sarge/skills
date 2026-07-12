# Portfolio GitHub CI Policy

## Purpose

Reduce GitHub-hosted runner consumption and feedback latency without weakening meaningful correctness, security, platform, or release coverage. Apply these defaults through repository-specific evidence rather than identical workflow files.

## Responsibility boundary

| Layer | Owns |
|---|---|
| GitHub workflow YAML | Events, change routing, runners, dependencies, matrices, concurrency, timeouts, permissions, caches, secrets, schedules, artifacts |
| Taskfile and repository scripts | Portable docs, format, lint, test, race, vulnerability, build, integration, and release commands |
| GitHub settings | Required checks, rulesets, Actions budgets, runner groups, secrets, variables, permissions |

## Required defaults

### Stable required gate

Keep one always-created required check with a stable name such as `ci-required`. Let it validate the results of conditional jobs. Avoid requiring every conditional platform or security job separately.

Do not rely only on workflow-level `paths` or `paths-ignore` for a required workflow. An entirely skipped required workflow may remain pending. A conditionally skipped job reports success, making job-level routing safer for required checks.

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
| Pull request | Complete merge gate selected by changed files |
| Protected default-branch push | Deployment or reduced smoke; do not repeat the identical full PR suite |
| Direct default-branch push | Complete validation only when direct pushes are possible and intentionally supported |
| Schedule | Time-sensitive security, deep race/integration, native platform, bounded fuzzing |
| Manual dispatch | Exceptional diagnostics, proofs, or operator-selected deep work |
| Tag/release | Release validation and publication |

Verify protection and merge behavior before dropping default-branch validation. If the workflow cannot distinguish protected PR merges from direct pushes reliably, keep a defensible default-branch gate or eliminate direct pushes through rulesets.

### Concurrency

Cancel superseded pull-request work within each workflow. Keep workflow names in concurrency groups so unrelated workflows do not cancel one another. Do not cancel release publication or stateful deployment work unless its recovery model explicitly permits it.

### Timeouts

Set every job timeout. Suggested starting points:

- classification, docs, and workflow lint: 5 minutes;
- ordinary build, test, and lint: 10–20 minutes;
- integration and native platform: 20–30 minutes;
- fuzzing: explicit bounded work duration plus controlled overhead.

Use repository evidence to adjust these numbers. A timeout is a containment boundary, not a performance target.

### Job ordering

Run cheap, broad failure detectors before expensive matrices:

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
