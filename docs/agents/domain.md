# Domain docs

This is a single-context repository. Engineering skills should consume its domain documentation using the following rules.

## Before exploring, read these

- `CONTEXT.md` at the repository root.
- Relevant architectural decisions under `docs/adr/`.

If these paths do not exist, proceed silently. The domain-modeling workflow creates them lazily when terminology or architectural decisions are established.

## Use the glossary’s vocabulary

When output names a domain concept, use the term defined in `CONTEXT.md`. Do not drift to synonyms the glossary explicitly avoids.

If a needed concept is absent, reconsider whether the project uses that concept or note the gap for domain modeling.

## Flag ADR conflicts

If proposed work contradicts an existing ADR, surface the conflict explicitly instead of silently overriding the decision.
