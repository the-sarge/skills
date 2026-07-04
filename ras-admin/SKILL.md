---
name: ras-admin
description: >-
  Use when Codex needs to initialize, configure, install bundled skills, test agent adapters, clean stale RAS state, or inspect version metadata with administrative RAS commands such as `ras init`, `ras skills install`, `ras agents test`, `ras agents capabilities`, `ras cleanup stale-runs`, or `ras version`. Do not use for running reviews, verification, fixing, or implementation loops.
---

# RAS Admin

Use RAS admin commands for setup, local diagnostics, bundled skill installation, stale-state cleanup, and version checks.

## Before Running

1. Confirm the current directory is the intended git repository when using repo-scoped commands.
2. Inspect `git status --short --branch`; config, `.gitignore`, and repo-local skill changes should be treated as real repo edits.
3. Check that `ras` is available with `command -v ras`, or use `go run ./cmd/ras` intentionally from the RAS source repo.
4. Read before writing: use `--check`, dry-run output, or non-mutating diagnostics before `--force`, `--apply`, or global installs.

## Init And Config

Initialize repo-local RAS config and state:

```bash
ras init
ras init --with-agent-skills
```

Use force flags only when intended:

```bash
ras init --force
ras init --force-global
ras init --data-dir .ras/data
```

`--force` overwrites the project `.ras/config.yaml`; `--force-global` overwrites the global config. Plain `ras init` should preserve existing config.

## Bundled Skills

Check or install managed copies of bundled RAS skills:

```bash
ras skills install --repo --check
ras skills install --repo
ras skills install --global --check
ras skills install --global
ras skills install --global --force-replace
```

Use `--force` only when replacing drifted managed files is intended. If a global install finds a non-empty Claude skill directory, `--force` lists the contents and prompts before replacing it; use `--force-replace` only for non-interactive replacement.

## Agent Diagnostics

Check configured agent executables and local prerequisites:

```bash
ras agents test
ras agents capabilities
```

Use these before long review or implementation loops when agent setup is uncertain.

## Cleanup

Inspect stale interrupted review runs first:

```bash
ras cleanup stale-runs
```

Apply cleanup only after reviewing the listed stale runs and worktrees:

```bash
ras cleanup stale-runs --apply
```

Use `--older-than` when the default 24-hour threshold is too broad or too narrow.

## Version

Print human-readable or JSON version metadata:

```bash
ras version
ras version --json
ras --version
```

## Safety Notes

- Do not run `cleanup stale-runs --apply` against runs that may still be active.
- Do not use `--force`, `--force-replace`, `--force-global`, or skill install `--force` unless the user intends replacement.
- Do not mutate global skill/config state when the user only asked for repo-local setup.
- Do not hide failed agent diagnostics; they are usually the reason later review, verify, or implement commands fail.
