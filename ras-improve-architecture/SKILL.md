---
name: ras-improve-architecture
description: >-
  Use when Codex needs to run or guide `ras improve-architecture` for multi-agent codebase architecture review at repository HEAD. Use for requests such as "run architecture review", "find codebase deepening opportunities", "use RAS to improve architecture", or "review this subsystem architecture"; do not use for PR review, local document consideration, verification, posting, or implementation handoff.
---

# RAS Improve Architecture

Use `ras improve-architecture` when the user wants independent agents to inspect the current repository architecture and synthesize deepening candidates rather than review a PR diff or critique one local document.

## Operating Model

`ras improve-architecture` creates an architecture review run. Reviewers inspect disposable worktrees materialized from the current `HEAD`, emit deepening candidates, RAS clusters and optionally adjudicates those candidates, and synthesis writes a prioritized Markdown deepening report.

Architecture runs are terminal in v1:

- Do not run `ras verify` on an architecture run.
- Do not run `ras post` on an architecture run.
- Do not run `ras fix` on an architecture run; `ras fix` is only for consideration runs.
- Do not run `ras implement --from-run` on an architecture run.

Choose one candidate with the user and create a separate issue, PRD, or inline `ras implement --task` work item when implementation should begin.

## Before Running

1. Confirm the current directory is the intended git repository with a valid `HEAD`.
2. Inspect `git status --short --branch` and tell the user when tracked or untracked work will be ignored by the HEAD-only source policy.
3. Check that `ras` is available with `command -v ras`.
4. Check `.ras/config.yaml`, then `~/.config/ras/config.yaml`, if agent roster, timeout, model profile, context shape, or delivery mode matter.
5. Confirm any `--context file:<path>` refs are inside the repository and are intentional operator overlays.

## Run Pattern

Run a full-repository architecture review:

```bash
ras improve-architecture
```

Scope reviewer attention to one directory while still materializing the full repository:

```bash
ras improve-architecture --path internal/runner
```

Add operator guidance and explicit context:

```bash
ras improve-architecture --prompt "Focus on the review pipeline and persistence seams."
ras improve-architecture --prompt-file ./architecture-guidance.md
ras improve-architecture --context file:docs/prd/improve-architecture-prd.md --context file:docs/adr/0008-architecture-review-run.md
```

Useful controls:

```bash
ras improve-architecture --agents codex,claude
ras improve-architecture --model-profile deep-review
ras improve-architecture --context-shape full
ras improve-architecture --delivery-mode auto
ras improve-architecture --timeout-seconds 1200
ras improve-architecture --no-adjudication
ras improve-architecture --no-auto-context
```

Architecture runs require the effective `review.context_shape=full`, whether it comes from `.ras/config.yaml`, `~/.config/ras/config.yaml`, or the CLI. If config sets `tiered`, `lean`, or `chunked`, override it with `ras improve-architecture --context-shape full`; non-full effective shapes fail before run creation. `ras improve-architecture` has no `--output` flag; canonical output is the stored Markdown synthesis and structured run JSON, and `ras report --output -` is the supported stdout inspection path.

## Inspect Results

After the command completes, read the printed synthesis and inspect structured run state:

```bash
ras show <run-id> --json
ras report <run-id> --output -
```

Ground any summary in stored facts: architecture source metadata, deepening candidates, clusters, adjudications, coverage notes, warnings, and synthesis artifact. Prefer `ras show <run-id> --json` when another agent or script needs candidate IDs and source facts.

## Optional Ephemeral Report

When visual cards help a human compare candidates, generate any temporary report from `ras show <run-id> --json`, not from free-form synthesis parsing. The report must be labeled ephemeral and non-canonical, write outside the repository by default, use deterministic escaping or an autoescaping template, avoid CDN or external assets, and must not auto-open a browser or register itself as a RAS artifact.

## Safety Notes

- Dirty tracked and untracked files in the caller checkout are warnings, not source input, unless passed as explicit `--context file:` overlays.
- `CONTEXT.md` and `docs/adr/*.md` are auto-injected from `HEAD` by default; use `--no-auto-context` only when the user intentionally wants narrower or context-free review.
- Large repositories create one disposable full worktree per active reviewer round. Tell operators to estimate disk headroom as active reviewer count times repository worktree size and to tune `--agents` or `--timeout-seconds` for large repos.
- Architecture prompts already include the deepening-candidate contract; bundled local agent skills are optional enrichment, not required for subprocess agents to produce valid output.

## Candidate Follow-Up Handoff

If the user picks a candidate for grilling, stress-testing, or deeper exploration, hand off to `ras-grill-candidate`. Do not duplicate its hydration workflow here; that skill reconstructs the selected candidate from `ras show <run-id> --json`, loads the canonical synthesis block, source candidates, adjudication dissent, evidence paths, architecture record notes, coverage notes, and warnings before asking the first grilling question.

If the user picks a candidate for planning or execution instead, help turn that single candidate into an issue, PRD, or `ras implement --task` work item. Do not automatically implement every candidate from the deepening report.

End with this exact question:

which candidate would you like to explore?
