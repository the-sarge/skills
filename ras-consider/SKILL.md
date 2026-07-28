---
name: ras-consider
description: >-
  Use when Codex needs to run or guide `ras consider` on a local PRD, design doc, implementation plan, spec, or other repository file to get a multi-agent critique without a GitHub PR. Prefer it as a read-only design gate before mutating loops when approach viability is still open. Use for requests such as "consider this PRD", "run RAS consider", "review this design doc with RAS", or "get multi-agent feedback on this plan". Do not use for GitHub PR review; use `ras-review`.
---

# RAS Consider

Use `ras consider` when the user wants a multi-agent critique of a local repository file rather than a GitHub PR review.

## Operating Model

`ras consider <file>` runs the same review/adjudication/synthesis pipeline as `ras review`, but the target is a local file inside the current git repository. It stores a normal RAS run that can be shown, reported, and browsed locally.

Consideration runs are local-only and do not post to GitHub. `ras verify <consider-run-id>` is supported for source-aware follow-up: it verifies the current local document in a matching checkout against the prior consideration synthesis, records document fingerprints, and refuses legacy runs without source metadata with `source_identity_unavailable`; `--head` remains PR-only. Missing or failing consideration verifier agents fail closed with `blocked/verify_failed` instead of silently treating the result as clean. If the verifier returns output that fails strict parsing or validation against the required JSON result, RAS runs one strict reformatting repair prompt against the same verifier agent and the same fingerprint scope. Repair is strict structured-output recovery, not semantic prose interpretation: the original raw verifier output must contain structured or JSON-like evidence before a repaired parsed result can be accepted. JSON-like raw output is grounded by item status and prior finding identity, so a raw `resolved` entry can ground only repaired `resolved`, a raw `unresolved` entry can ground only that entry's `status`, conflicting structured raw statuses for the same prior finding identity cannot ground any repaired prior status, and packet-ready out-of-scope `new_scope` and `needs_human` entries can ground only matching repaired entries. Prose-only raw output, including status sentences, Markdown headings, schema-field references, and mixed or negated status prose, fails closed with `blocked/verify_parse_failed`. On successful repair, the verification row keeps the original raw verifier output as the primary artifact, returns that same raw body to the caller, and stores the repaired parsed JSON separately for metadata. A repair pass may add one extra verifier-agent invocation with the same timeout/cost profile as verification. If repair also fails, returns empty stdout, introduces judgments without matching structured raw evidence, or if the repair prompt would exceed the verification prompt size limit, RAS persists the original raw verification artifact without parsed metadata and fails closed with `blocked/verify_parse_failed`; repair prompt and parsed-result artifact or database persistence failures are returned directly and do not write synthetic parse-failure verification rows.

## Approach Gate

Use `ras consider` as the cheap design gate before a mutating loop when the artifact describes a possible approach rather than an accepted plan. If the synthesis says the foundation is wrong, ambiguous, claims broad coverage of an open external grammar through a handwritten scanner, or depends on an unresolved product/architecture choice, keep the decision with the user and revise the document; do not patch syntax examples or immediately feed the result to `ras implement --from-run` or `ras-consider-resolve`.

## Before Running

1. Confirm the current directory is the intended git repository with a valid `HEAD`.
2. Inspect `git status --short --branch`; do not edit local files for a consider-only request unless the user asks.
3. Confirm the target and any `file:` context refs are inside the repository.
4. Check that `ras` is available:

   ```bash
   command -v ras
   ```

5. Check `.ras/config.yaml`, then `~/.config/ras/config.yaml` if agents, prompts, context shape, delivery mode, or model profile matter.

## Choose The Kind

Use `--kind` to name the artifact in prompts and stored output:

```bash
ras consider docs/prd/feature-prd.md --kind prd
ras consider docs/design.md --kind design
ras consider docs/implementation-plan.md --kind plan
```

If no specific type is clear, omit `--kind` and let it default to `doc`.

## Add Context

Attach focused local context with repeatable `file:` refs:

```bash
ras consider docs/prd/feature-prd.md --kind prd --context file:README.md --context file:SPEC.md
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

When constraints on the document live outside it — a parent plan, a program
boundary, a prior decision that closed a direction — quote them into the prompt
rather than summarizing them. Reviewers hold the document to the text supplied,
so a paraphrase that widens a bounded constraint produces findings that are
correct against the paraphrase and wrong against the constraint. See the same
guidance under `ras-review`, where the failure mode is best documented.

For an engineering contract, also identify the supported representation domain and owner, universal/canonical-subset/example-level guarantee, artifact classes, terminating evidence plan, evidence budget, and whether the run is the initial consideration or the one allowed replacement. Ask reviewers to test semantic behavior and representation ownership inside that boundary. Do not generically request syntax aliases, concrete mutants, repeated hosted runs, exhaustive platform matrices, or recursive validation of verification aids.

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
- where to inspect the run, such as `ras status <run-id> --json` or `ras show <run-id> --json` for agent-readable detail, and `ras report <run-id>` or `ras serve` for human browsing

If the user asks to resolve findings in the document itself, apply the Approach Gate first. Only use `ras-consider-resolve` when the findings are document-level edits or the operator has chosen the approach; if the synthesis says the foundation is wrong, representation ownership is missing, or direction is undecided, keep the decision with the user and revise the plan before invoking a fixer. If the user asks to turn the consideration output into code, use `ras-implement` with a precise work item or `ras implement --from-run <run-id>` only when the synthesis is suitable and the approach is chosen.

## Safety Notes

- Do not mutate the file under consideration for a consider-only request.
- Keep GitHub posting out of consideration workflows.
- Use `ras verify <consider-run-id>` when the user wants source-aware follow-up against the current local document.
- Use `ras-consider-resolve` when the user wants decision capture, isolated document edits, resume/apply/abort handoff, or `ras fix <consider-run-id> --decisions <file>`, after approach-defining decisions are made or represented as `needs_human`.
- Do not treat consideration output as an accepted plan; it is critique and synthesis for the user to decide on.
- Treat low-severity and nit feedback separately from correctness, safety, or feasibility blockers.
