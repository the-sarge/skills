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
- Architecture record notes, usually `GLOSSARY.md` and `docs/adr/*.md`. If no `docs/adr/` exists, say that architecture records may be `GLOSSARY.md`, `docs/architecture.md`, or app-specific design docs.
- Any dissent or correction that narrows scope.

Prefer `rg`, `sed`, `nl`, and focused test file reads. If a question can be answered by inspecting code or docs, inspect first and then state the answer.

## Grilling Workflow

After hydration, load `grilling` for its design-tree and frontier method and `domain-modeling` for terminology and ADR criteria. Apply these local composition rules: ask one frontier question at a time rather than batching the frontier, and keep glossary/ADR changes proposed until the user authorizes writing them. Loading either skill does not authorize documentation edits or implementation:

- Ask one question at a time and wait for the user's answer.
- For each question, include your recommended answer and phrase the question so "yes" accepts it.
- Anchor every question to the dossier: cite the candidate id, canonical rank, evidence path, architecture record note, or adjudication dissent that motivated it.
- Challenge scope drift immediately. If adjudication narrowed the candidate, keep the grill inside that scope unless the user explicitly expands it.
- Resolve terminology against `GLOSSARY.md`; when language conflicts with the glossary, call it out.
- Offer to update `GLOSSARY.md` or create/amend an ADR only after a concrete decision crystallizes and the `domain-modeling` ADR criteria are met; write only after the user explicitly authorizes the documentation change.

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

Once the user confirms the resolved understanding, recommend the route that fits the work: `planit` for standalone work, or an explicit `$architecture-handoff` invocation for an architecture program requiring audited slices and program tracking. Supply the hydrated dossier and resolved decisions to the chosen route. Start `planit` only when the user agrees; `architecture-handoff` retains its explicit-invocation requirement. Existing marked child issues route to `implement-architecture-slice` under their accepted contracts. Report the recommendation without automatically starting implementation or dispatching an agent.

## Safety

- This is read-only until the user explicitly asks to write docs, create issues, or start implementation.
- Do not run `ras verify`, `ras fix`, `ras post`, or `ras implement --from-run` for architecture runs.
- Do not reorder candidates based on strength, source count, or adjudication counts. Preserve canonical synthesis order.
