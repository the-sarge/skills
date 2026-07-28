---
name: ras
description: >-
  Use as the high-level RAS entry point when a user asks broadly about RAS, wants help choosing a RAS workflow, asks for project or run status, or mentions multiple RAS operations without naming a specific command. Route concrete review, implementation, consideration, architecture review, verification, benchmark, experiment, inspection, or admin work to the matching operation-specific RAS skill. Use read-only review or consideration as the approach-risk gate before mutating workflows when the foundation may be wrong.
---

# RAS

Use this skill as the router for broad RAS requests. RAS means review, adjudicate, synthesize: a local CLI for multi-agent PR review, local document consideration, architecture deepening review, verification, implementation loops, benchmarks, experiments, reports, and local run inspection.

## First Checks

1. Confirm the current directory is the intended git repository.
2. Inspect `git status --short --branch` before starting any workflow.
3. Check that `ras` is available with `command -v ras`, or intentionally use `go run ./cmd/ras` from the RAS source repo.
4. Prefer read-only inspection before mutation when the user asks for status, history, or "where are we?" Use `ras status --json`, `ras status <run-id> --json`, or `ras show <run-id> --json` when an agent needs structured run state instead of human-readable text.
5. Do not run same-target mutating RAS workflows concurrently.

## Route The Request

- Use `ras-inspect` for project status, run history, reports, artifacts, stale-run summaries, or `ras serve`.
- Use `ras-review` for a one-shot GitHub PR review, posting a stored review, or an approach gate before mutating PR workflows.
- Use `ras-review-loop` when the user explicitly asks for review, independent finding disposition, agent-performed fixes, verification, and repetition until clean.
- Use `ras-verify` for one-shot verification of a prior PR review or consideration run.
- Use `ras-consider` for critique of a local PRD, design doc, implementation plan, or other repository file, especially when the next decision is whether a proposed approach is viable.
- Use `ras-consider-resolve` for decision packets, document fixing, apply/resume/abort, or `ras fix <consider-run-id> --decisions <file>` after approach-defining decisions have been made.
- Use `ras-improve-architecture` for multi-agent codebase architecture review at repository `HEAD`, deepening candidate synthesis, and post-run grilling handoff.
- Use `ras-implement` when the user wants RAS to drive a clear, approach-ready work item in an isolated builder worktree; follow the shared automated-fixer safety policy.
- Use `ras-benchmark` for benchmark manifests, benchmark plan/run/resume/evaluate/synthesize/report workflows, or benchmark result interpretation.
- Use `ras-experiment` for context-shape, delivery-mode, agent, prompt, or evaluator comparison against a PR.
- Use `ras-admin` for `ras init`, bundled skill installation, adapter tests, capabilities, cleanup, or version checks.

## Approach Risk Gate

Before choosing a mutating workflow, decide whether the implementation strategy is sufficiently specified. If not, route to read-only `ras-review` for PRs or `ras-consider` for plans first. In every case, treat review output as evidence and apply the shared [finding-disposition policy](../_shared/REVIEW-LOOP.md) before any review-driven mutation.

Treat shell/process control, concurrency/lifecycle orchestration, auth/security boundaries, data migrations or destructive writes, parser/protocol rewrites, API or architecture changes, and unfamiliar dependency strategies as approach-risky by default. Apply the shared representation and approach stops before routing to mutation. Use `ras-review-loop`, `ras-implement`, `ras-consider-resolve`, or `ras fix` only when the foundation is still sound and the remaining findings are patches on that foundation.

If the user explicitly asks for a complete mutating loop, use the manual `ras-review-loop`, which composes the shared review budget and disposition policy. Severity alone does not establish a foundational stop.

## Broad Status Pattern

For "what is the status of this project?" or "where are we?":

1. Read the project docs that define current intent, usually `CONTEXT.md`, `README.md`, `SPEC.md`, `docs/DEV-JOURNAL.md`, and PRDs under `docs/prd/`.
2. Inspect local repository state with `git status --short --branch` and recent history with `git log --oneline --decorate -n 20`.
3. Check GitHub issue and PR state with `gh issue list` and `gh pr list` when the repository uses GitHub.
4. Check CI/release state when relevant with `gh run list`, `gh repo view`, and release metadata.
5. Run local verification only when useful for the requested confidence level.
6. Report what is done, what is open, what is missing, the roadmap, and the best next steps.

## Safety

Plain inspection commands such as `ras status`, `ras status --json`, `ras show`, `ras show --json`, `ras report --output -`, and read-only `ras serve` are safe for normal diagnostics. Mutating workflows should be serialized per target and called out clearly before running. Follow the shared [automated-fixer safety policy](../_shared/REVIEW-LOOP.md).
