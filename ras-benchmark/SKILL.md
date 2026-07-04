---
name: ras-benchmark
description: >-
  Use when Codex needs to plan, run, resume, evaluate, synthesize, report, or
  interpret a `ras benchmark` manifest. Use for requests such as "run the RAS
  benchmark", "benchmark these reviewer setups", "resume this benchmark",
  "generate the benchmark report", or "summarize benchmark results". Do not use
  for one-PR context strategy experiments; use `ras-experiment` for those.
---

# RAS Benchmark

Use `ras benchmark` for manifest-driven benchmark suites across targets,
reviewer setups, context shapes, delivery modes, repeated runs, secondary
evaluator passes, and synthesis candidates.

## Operating Model

`ras benchmark` is a durable, multi-step benchmark workflow:

1. `plan` expands a manifest without running agents.
2. `run` executes primary benchmark experiments and persists progress.
3. `resume` continues an incomplete benchmark without rerunning completed cells.
4. `evaluate` runs secondary evaluator passes for completed experiments.
5. `synthesize` compares synthesis agents against fixed benchmark evidence.
6. `report` writes aggregate Markdown, JSON, and CSV artifacts.

Benchmark output is evidence for comparing RAS behavior. It is not a PR merge
gate by itself.

## Before Running

1. Confirm the current directory is the intended git repository.
2. Inspect `git status --short --branch`; do not edit code for a
   benchmark-only request unless the user explicitly asks for implementation.
3. Check that the current `ras` binary supports benchmarks:

   ```bash
   ras version
   ras benchmark --help
   ```

   If working inside the RAS source repo and the installed binary is stale,
   build and install a current binary before running a benchmark.

4. Inspect `.ras/config.yaml`, then `~/.config/ras/config.yaml` for available
   agents, evaluator defaults, synthesis agents, context shapes, and delivery
   modes.
5. Confirm the manifest path or benchmark id. PRD-style benchmark manifests
   should live under `docs/prd/`; generated result artifacts should usually live
   under `reports/benchmarks/<name>/`.
6. For large runs, call out expected time and model cost before starting. Prefer
   a smaller manifest or a `plan` dry run when scope is unclear.

## Run Pattern

Expand the manifest first:

```bash
ras benchmark plan <manifest>
```

Run the primary benchmark:

```bash
ras benchmark run <manifest>
```

If the run is interrupted or partial, resume instead of rerunning:

```bash
ras benchmark resume <manifest-or-id>
```

Run secondary evaluator passes after primary experiments complete:

```bash
ras benchmark evaluate <manifest-or-id> --evaluators codex,claude,agy
```

Run synthesis-agent comparisons after completed multi-agent benchmark cells
exist:

```bash
ras benchmark synthesize <manifest-or-id> --synthesis-agents codex,claude,agy
```

Generate aggregate reports:

```bash
ras benchmark report <manifest-or-id>
```

When a command prints a benchmark id, keep it in the working notes. Use the id
for later resume/report commands when manifest identity is ambiguous.

## Handling Output

Read the generated report artifacts before summarizing results. Expected
artifacts are:

- `benchmark-summary.md`
- `benchmark-summary.json`
- `benchmark-cells.csv`
- `benchmark-stage-costs.csv`
- `benchmark-evaluator-scores.csv`
- `benchmark-evaluator-comparisons.csv`
- `benchmark-synthesis-scores.csv`
- `benchmark-interactions.csv`
- `benchmark-repeatability.csv`

When reporting results, include the benchmark id, manifest path, output
directory, completion status, failed or skipped experiments, strongest
configuration signals, evaluator disagreement, synthesis quality/efficiency
signals, repeatability or ground-truth caveats, and the exact report paths.

If no report artifacts exist, say that no benchmark results have been produced
yet. Do not infer benchmark outcomes from the PRD or implementation status.

## Safety Notes

- Do not run the same benchmark concurrently from multiple shells.
- Do not delete partial benchmark state to "start clean" unless the user asks.
  Prefer `ras benchmark resume`.
- Do not post benchmark output to GitHub unless the user explicitly asks.
- Do not treat a partially failed benchmark as successful; report partial data
  and failed cells separately.
- Keep manifests and report paths stable so runs can be resumed and compared.
