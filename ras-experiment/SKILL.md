---
name: ras-experiment
description: >-
  Use when Codex needs to run or guide `ras experiment` for comparing RAS context shapes, delivery modes, agents, prompts, or evaluator settings against a GitHub pull request. Use for requests such as "run a context strategy experiment", "compare full vs tiered context", or "benchmark RAS review context modes". Do not use for manifest-driven benchmark suites; use `ras-benchmark` for those. Do not use for ordinary PR review or merge gating; use `ras-review` or `ras-review-loop` for those.
---

# RAS Experiment

Use `ras experiment` when the user wants evidence about context strategy behavior across shapes, delivery modes, agents, prompts, or evaluator choices for a GitHub PR.

## Operating Model

`ras experiment <pr-url-or-number>` runs multiple review cells over one PR, evaluates or synthesizes the results, records experiment data in local RAS state, and can write an experiment report. It is exploratory and comparative; it is not a merge gate by itself.

## Before Running

1. Confirm the current directory is the intended git repository.
2. Inspect `git status --short --branch`; do not edit code for an experiment-only request.
3. Confirm the PR target:

   ```bash
   gh pr view <number-or-url> --json number,url,headRefName,baseRefName,state,isDraft,headRefOid
   ```

4. Check `.ras/config.yaml`, then `~/.config/ras/config.yaml` for available agents, evaluator defaults, context shapes, and delivery modes.
5. Clarify output location, shapes, delivery modes, and agent set when the request is not specific; experiments can be slower and more expensive than a normal review.

## Run Pattern

Run the configured default experiment:

```bash
ras experiment <pr-url-or-number>
```

Compare selected shapes and delivery modes:

```bash
ras experiment <pr> --shapes full,tiered,lean --delivery-modes inline,auto --output reports/ras-experiment.md
```

Use `session` only when the selected agents advertise session delivery support; bundled subprocess and SSH agents such as Codex, Claude, and agy use inline delivery.

Set agents, evaluator, or guidance:

```bash
ras experiment <pr> --agents codex,claude --evaluator claude
ras experiment <pr> --prompt "Compare context sufficiency and finding quality."
ras experiment <pr> --prompt-file ./experiment-prompt.md
```

## Handling Output

Wait for the experiment to finish and read the report or printed summary. Report the PR, experiment dimensions, output path, evaluator used, standout results, failed cells, and any caveats about cost, runtime, or reviewer availability.

While the experiment is running, monitor that command's own output as the primary progress source. Use inspection commands for explicit diagnostics or after the experiment completes rather than as a polling loop; expect extra resource, model, and Git/state contention if other agents run reviews at the same time.

## Safety Notes

- Do not treat experiment results as a clean PR review, verification, or merge approval.
- Do not post experiment output to GitHub unless the user explicitly asks.
- Keep experiment dimensions bounded; large shape x delivery x agent matrices can consume substantial time and model budget.
- Preserve failed-cell details instead of summarizing only the winning configuration.
