---
name: ras-consider
description: >-
  Use when Codex needs to run or guide `ras consider` on a local PRD, design
  doc, implementation plan, spec, or other repository file to get a multi-agent
  critique without a GitHub PR. Use for requests such as "consider this PRD",
  "run RAS consider", "review this design doc with RAS", or "get multi-agent
  feedback on this plan". Do not use for GitHub PR review; use `ras-review`.
---

# RAS Consider

Use `ras consider` when the user wants a multi-agent critique of a local repository file rather than a GitHub PR review.

## Operating Model

`ras consider <file>` runs the same review/adjudication/synthesis pipeline as `ras review`, but the target is a local file inside the current git repository. It stores a normal RAS run that can be shown, reported, and browsed locally.

Consideration runs are local-only. They do not post to GitHub, and `ras verify` is for PR review runs, not consideration runs.

## Before Running

1. Confirm the current directory is the intended git repository with a valid `HEAD`.
2. Inspect `git status --short --branch`; do not edit local files for a consider-only request unless the user asks.
3. Confirm the target and any `file:` context refs are inside the repository.
4. Check that `ras` is available:

   ```bash
   command -v ras
   ```

5. Check `.ras.yaml`, `.ras/config.yaml`, then `~/.config/ras/config.yaml` if agents, prompts, context shape, delivery mode, or model profile matter.

## Choose The Kind

Use `--kind` to name the artifact in prompts and stored output:

```bash
ras consider docs/feature-prd.md --kind prd
ras consider docs/design.md --kind design
ras consider docs/implementation-plan.md --kind plan
```

If no specific type is clear, omit `--kind` and let it default to `doc`.

## Add Context

Attach focused local context with repeatable `file:` refs:

```bash
ras consider docs/feature-prd.md --kind prd --context file:README.md --context file:SPEC.md
```

Only `file:` context refs are supported. Keep context narrow; do not paste or attach the whole repository as prose.

## Run Pattern

Basic consideration:

```bash
ras consider <file> --kind <prd|design|plan|doc>
```

Add operator guidance:

```bash
ras consider <file> --kind prd --prompt "Stress-test scope, risks, and acceptance criteria."
ras consider <file> --kind design --prompt-file ./consider-prompt.md
```

Useful controls:

```bash
ras consider <file> --agents codex,claude
ras consider <file> --model-profile deep-review
ras consider <file> --context-shape tiered --delivery-mode auto
ras consider <file> --timeout-seconds 900
ras consider <file> --no-adjudication
```

Use `--no-adjudication` only when the user explicitly wants faster, less processed output or adjudicator agents are unavailable.

## Handling Output

Wait for the command to finish and read the final synthesis. Do not infer success from silence or from an exit code alone.

When reporting back, include:

- run id
- considered file and kind
- key findings or recommendations
- whether any agent, adjudication, or synthesis stage failed
- where to inspect the run, such as `ras status <run-id>`, `ras show <run-id>`, `ras report <run-id>`, or `ras serve`

If the user asks to turn the consideration output into code, use `ras-implement` with a precise work item or `ras implement --from-run <run-id>` when the synthesis is suitable.

## Safety Notes

- Do not mutate the file under consideration for a consider-only request.
- Do not use `ras post` or `ras verify` for consideration runs.
- Do not treat consideration output as an accepted plan; it is critique and synthesis for the user to decide on.
- Treat low-severity and nit feedback separately from correctness, safety, or feasibility blockers.
