---
name: ras-grill-candidate
description: Hydrate and grill one RAS architecture deepening candidate from a stored `ras improve-architecture` run. Use when the user wants to explore, stress-test, grill, interrogate, or turn a specific RAS architecture candidate such as `C-001` into a sharper design, issue, PRD, or implementation task.
---

# RAS Grill Candidate

Use this skill after `ras improve-architecture` has produced deepening candidates and the user wants to explore one candidate rigorously.

## Non-Negotiable Preflight

Do not ask the first grilling question until you have reconstructed the candidate context from stored RAS artifacts.

1. Resolve the intended repository, run id, and candidate id. Accept cluster ids like `C-001` and source ids like `codex:A-C-003`; if either run id or candidate id is missing, ask for the missing value.
2. Confirm `ras` is available with `command -v ras`.
3. Run the dossier helper from the repository root:

```bash
python3 <skill-base-dir>/scripts/build_candidate_dossier.py --run-id <run-id> --candidate-id <candidate-id>
```

4. Read the generated dossier before continuing. It must include the canonical synthesis block, candidate cluster, source candidates, evidence paths, architecture record notes, adjudication counts, dissent/corrections, source metadata, coverage notes, and warnings.
5. If the helper cannot resolve exactly one candidate, stop and ask for clarification. Do not grill from memory or from a task title alone.

## Code And Docs Grounding

Before grilling, inspect the highest-signal referenced files:

- The candidate primary file and primary module.
- Evidence paths listed in the canonical synthesis block.
- Architecture record notes, usually `CONTEXT.md` and `docs/adr/*.md`. If no `docs/adr/` exists, say that architecture records may be `CONTEXT.md`, `docs/architecture.md`, or app-specific design docs.
- Any dissent or correction that narrows scope.

Prefer `rg`, `sed`, `nl`, and focused test file reads. If a question can be answered by inspecting code or docs, inspect first and then state the answer.

## Grilling Workflow

Use the `grill-with-docs` style after hydration:

- Ask one question at a time and wait for the user's answer.
- For each question, include your recommended answer.
- Anchor every question to the dossier: cite the candidate id, canonical rank, evidence path, architecture record note, or adjudication dissent that motivated it.
- Challenge scope drift immediately. If adjudication narrowed the candidate, keep the grill inside that scope unless the user explicitly expands it.
- Resolve terminology against `CONTEXT.md`; when language conflicts with the glossary, call it out.
- Offer to update `CONTEXT.md` or create/amend an ADR only after a concrete decision crystallizes and the `grill-with-docs` ADR criteria are met.

## Output Shape

Start with a compact dossier acknowledgement:

```text
Hydrated C-001 from run <run-id>: canonical rank 1, strength Strong, primary file src/...
Key dissent/correction: ...
First question: ...
Recommended answer: ...
```

Keep the session interactive. Do not dump every possible question at once.

## Completion Handoff

When the grilling session has resolved the candidate scope, success criteria, sequencing, test strategy, and documentation or ADR decisions, summarize the resolved implementation brief:

- Candidate id, run id, canonical rank, and action title.
- Final scope boundaries and explicit non-goals.
- Decisions made during grilling, including any architecture record updates needed.
- Proposed implementation slices and tests at a high level.
- Remaining risks or open questions.

Then ask whether to use `planit` to produce the implementation plan. If the user agrees, hand off to `planit` with the hydrated dossier and resolved grilling decisions as input. Do not start `planit` automatically after an arbitrary answer; only offer it when the candidate is genuinely ready to plan.

## Safety

- This is read-only until the user explicitly asks to write docs, create issues, or start implementation.
- Do not run `ras verify`, `ras fix`, `ras post`, or `ras implement --from-run` for architecture runs.
- Do not reorder candidates based on strength, source count, or adjudication counts. Preserve canonical synthesis order.
