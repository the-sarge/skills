# Auditors

How to partition the repo and what each auditor's prompt must contain. Auditors are read-only `general-purpose` agents dispatched in one message.

## Partitioning

Aim for 4–7 auditors. Domains, applied in order:

1. **Production code, per major package/directory** — split further only when a single domain would exceed roughly 8k lines of hand-written code.
2. **Test suite** — its own auditor whenever tests rival or exceed production volume; test smells differ from production smells.
3. **Public support surface** — test-support packages, harnesses, SDK/facade layers, codegen.
4. **Scripts and build config** — shell/Python automation, task runners, CI workflows, linter and secret-scan configs, module/dependency hygiene.
5. **Cross-cutting consistency** — always present, spans everything: finds where the codebase disagrees with itself.

Exclude generated and vendored files everywhere (check for generation headers; verify suspiciously large files before including them).

## Shared prompt skeleton

Every auditor prompt contains:

- **Read-only contract**: no edits, no file creation, no formatters or linters that modify files.
- **Context line**: the repo was written incrementally by various AI agents using different models — expect stylistic drift.
- **Scope**: the exact directories/files this auditor owns.
- **Standards first**: skim the repo's agent docs and linter configs; do not re-report what the linter already enforces.
- **Depth**: read files fully (in chunks for big files) — never audit from grep excerpts alone.
- **Output contract**: a structured markdown report — 3–5 sentence overall assessment; findings grouped by category as `path:line — severity (high/med/low) — one-sentence description`; the most impactful cleanups (max 5) with rough scale. Selectivity: real smells, not lint nitpicks. The final message IS the report.
- **On a delta run**: the prior report's findings for this scope, with instructions to mark each fixed / persisting / new before reporting anything else.

## Per-domain lenses

Add the matching lens to the skeleton.

**Production code**: long functions, deep nesting, duplicated logic; dead code, speculative generality, needless indirection; naming drift (constructor patterns, receiver names, abbreviations); error-handling drift (wrapping, sentinels vs typed, message grammar); comment smells (noise, stale, changelog-style AI artifacts); file organization; magic values; API surface (over-exported, awkward signatures, secret/redaction hygiene on anything holding credentials).

**Test suite**: copy-pasted setup and fixtures vs over-abstracted helpers; mixed dialects for the same check (table vs inline, fatal vs continue, assertion-message grammar); giant multi-purpose test functions; redundant or vacuous coverage (cases whose fixtures don't express what their names promise); timing hacks — sleeps, wall-clock deadlines, and especially negative timing assertions ("X must NOT finish within N ms"); implementation-detail coupling; magic values; helper naming and placement; process-history comments referencing documents outside the repo.

**Public support surface**: everything from the production lens, plus harness over-engineering (indirection that makes simple assertions hard to follow), parallel mechanisms for the same job (multiple API-contract guards, duplicate child-process or fault-injection infrastructure), option/config pattern consistency, and doc comments that restate function docs verbatim.

**Scripts and build config**: prologue and dialect consistency (strict mode, bracket style, `local`); silent-failure patterns whose exit codes go unchecked; style drift between sibling scripts (typing, imports, arg parsing); duplication across languages and between task runner and CI (version pins counted per location — every pin duplicated anywhere is a finding); dead config (exclusions matching nothing, unreachable refs); naming that breaks test discovery.

**Cross-cutting consistency**: compare conventions ACROSS the other auditors' scopes — error-message grammar, doc-comment voice and placement, constructor/option/naming patterns, panic-vs-error boundary and panic values, test conventions per package, file/package organization and test-file naming, comment tone and density outliers. Verify 5–8 concrete documented rules from the agent docs against the code, and check the docs against each other. Every claimed inconsistency needs at least two `file:line` citations showing the disagreement. Close with the fault lines — which files or packages read like a different author — and the highest-value harmonization moves.
