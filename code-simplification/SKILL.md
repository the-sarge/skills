---
name: code-simplification
description: Simplify working Go, Python, TypeScript, and Rust code for clarity and maintainability without changing observable behavior. Use after implementing or reviewing code when the current solution is unnecessarily nested, repetitive, indirect, over-abstracted, or difficult to understand; keep changes scoped and prove behavior preservation with the repository's tests and checks.
---

# Code Simplification

Make code easier to read, reason about, modify, and debug while preserving its observable behavior. Optimize for comprehension, not line count.

> Adapted from Addy Osmani's [code-simplification skill](https://github.com/addyosmani/agent-skills/tree/main/skills/code-simplification), used under the MIT License.

## Non-negotiable constraints

- Preserve inputs, outputs, side effects, mutation, ordering, timing guarantees, errors, resource lifetimes, and supported edge cases.
- Keep public APIs, serialized forms, and compatibility guarantees unchanged unless the user explicitly expands the task.
- Follow the repository's conventions instead of imposing personal or language-community preferences.
- Keep the diff within the requested or recently changed surface. Do not mix drive-by refactors into the pass.
- Prefer explicit, conventional code over dense or clever code.
- Stop when a proposed simplification cannot be shown to preserve behavior.

## Resolve project rules

Before editing, read every applicable `AGENTS.md`, starting at the repository root and continuing through the directories that contain the files in scope. Apply the most specific instructions where rules differ.

Also inspect the repository's formatter, linter, compiler, test, and task-runner configuration. Study neighboring code for established naming, control-flow, error-handling, module, type, and testing patterns.

## Workflow

### 1. Establish the boundary

Identify the exact files and behavior in scope from the user's request, current diff, branch history, issue, or review finding. Treat unrelated uncommitted changes as user-owned.

Confirm that the code works before simplifying it. Run the narrowest relevant tests or checks to establish a baseline. If the behavior is untested and the proposed change is not mechanically obvious, preserve the code or add characterization coverage when the task permits it.

### 2. Build a behavior map

Answer these questions before changing the code:

- What responsibility does this code own?
- Who calls it, and what does it call?
- What values, errors, side effects, and state transitions are observable?
- Which ordering, timing, identity, allocation, or cleanup properties could matter?
- Which tests, types, schemas, or public contracts define its behavior?
- Why might the current structure exist: compatibility, performance, concurrency, platform limits, or prior incidents?

Use history or blame when the reason for a surprising construct is unclear. Do not remove a fence before understanding why it exists.

### 3. Load the language guidance

Read the reference for every language in the changed surface before proposing edits:

- [Go](references/go.md)
- [Python](references/python.md)
- [TypeScript](references/typescript.md)
- [Rust](references/rust.md)

For a cross-language boundary, inspect both sides of the contract and read every applicable reference.

### 4. Find concrete opportunities

Look for evidence of avoidable complexity:

| Signal | Prefer |
| --- | --- |
| Deeply nested happy paths | Guard clauses or named helpers that make exceptional paths explicit |
| A function with several responsibilities | Focused functions split at domain boundaries |
| Dense expressions or nested conditionals | Named intermediate values, clear branches, or exhaustive matching |
| Repeated logic | One well-named implementation when the behavior is genuinely identical |
| Generic or misleading names | Names that express domain meaning and side effects |
| Comments narrating syntax | Self-explanatory code; retain comments that explain constraints or intent |
| Pass-through wrappers | Direct calls when the wrapper owns no policy, seam, compatibility, or instrumentation |
| Speculative abstractions | The simplest design required by current callers |
| Dead code | Removal after references, generated use, feature gates, reflection, and dynamic loading are ruled out |

Treat thresholds such as nesting depth or function length as prompts to investigate, not automatic rewrite rules.

### 5. Reject false simplifications

Do not make a change merely because it:

- uses fewer lines;
- adopts a fashionable idiom;
- replaces explicit control flow with a dense chain;
- removes a helper that gives a domain concept a useful name;
- merges code that changes for different reasons;
- hides failure or cleanup behavior;
- introduces a new dependency or abstraction;
- shifts work, allocation, or blocking into a less visible location;
- makes the type checker happier while making runtime intent less clear.

Flag, rather than silently perform, architectural changes such as replacing a dependency-injection seam, changing a concurrency model, introducing shared state, or replacing composition with global context.

### 6. Apply one coherent change at a time

For each candidate:

1. State the behavior that must remain invariant.
2. Make the smallest coherent edit.
3. Format the changed files with the repository's configured tool.
4. Run the narrowest relevant test or check.
5. Inspect the diff for semantic drift and unrelated churn.
6. Keep the edit only when it is clearly easier to understand.

Do not modify expectations merely to make a refactor pass. A changed test expectation is evidence that behavior changed; investigate it separately.

For a broad mechanical refactor, use an AST-aware transformation or other deterministic automation and review representative and edge-case diffs. Do not hand-edit hundreds of repetitive sites.

### 7. Verify the complete pass

Run the repository's documented checks, then apply the language-specific verification from the relevant references. Prefer project-defined task commands over invented command combinations.

When only an isolated snippet is available, compile or type-check it where possible and compare the original and candidate with a focused, throwaway characterization harness. Exercise normal, boundary, error, and side-effect paths; report exactly what ran, distinguish it from checks merely recommended, and do not claim repository-level verification.

Inspect the final diff and confirm:

- Existing tests pass without changed expectations.
- Builds, type checks, linters, and formatters pass with no new warnings.
- Error handling, cleanup, ordering, concurrency, and side effects remain intact.
- Public interfaces and serialized representations are unchanged.
- No unused imports, unreachable branches, stale comments, or dead helpers remain.
- The diff contains no unrelated edits or formatting churn.
- The result uses patterns already understood by maintainers of this repository.
- Reverting the simplification alone would restore the previous implementation cleanly.

## Stop conditions

Stop and report the uncertainty when:

- the current behavior cannot be determined;
- baseline tests fail for reasons related to the target code;
- applicable `AGENTS.md` instructions conflict with the requested change;
- preserving behavior requires a product, API, schema, performance, or compatibility decision;
- the simplification would cross the approved scope or absorb user-owned changes;
- the only evidence of equivalence is intuition.

## Report the result

Summarize the simplifications, the behavior-preservation evidence, and the exact checks run. Call out anything intentionally left unchanged because its purpose or equivalence was uncertain.
