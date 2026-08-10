---
name: code-smell-audit
description: Parallel code-smell and style-consistency audit of the current repo — collated report archived to DEVONthink, conventions captured for the cross-repo survey, batched tickets with blocking edges, mirrored to OmniFocus.
disable-model-invocation: true
---

# Code Smell Audit

Audit the current repository for code smells and style drift using parallel read-only **auditors**, archive the collated report, capture the repo's conventions for the cross-repo survey, then publish batched tickets and mirror them to OmniFocus.

Arguments: a DEVONthink group link (`x-devonthink-item://UUID`) and an OmniFocus parent-task link (`omnifocus:///task/ID`), in either order. If either is missing, ask for it before doing anything else.

The audit itself never modifies the repository. The only writes are to DEVONthink, the issue tracker, and OmniFocus.

## 1. Preflight

- Invoke the `devonthink-cli` and `omnifocus-cli` skills. `get` both IDs: the DEVONthink item must be a group, the OmniFocus item a task. Stop and report if either fails.
- Read the repo's agent docs (AGENTS.md / CLAUDE.md / CONTEXT.md and anything they mark authoritative) and its linter/formatter configs. Auditors judge against documented standards and must not re-report what the linters already enforce.
- Locate tracker conventions: `docs/agents/issue-tracker.md` and `docs/agents/triage-labels.md` if present, else default to GitHub via `gh` with a `ready-for-agent` label if the repo has one.
- **Delta check**: search the DEVONthink group for earlier audit records. If one exists, this run is a **delta**: extract the prior report's findings and carry them into every auditor prompt so each finding comes back as fixed, persisting, or new.

Done when: both links resolve to the right kinds, tracker conventions are known, and prior-audit state (fresh vs delta) is decided.

## 2. Dispatch auditors

- Map the repo: file counts by language and directory, line counts, generated/vendored files to exclude.
- Partition into domains and build one prompt per auditor from [AUDITORS.md](AUDITORS.md). Always include the cross-cutting consistency auditor — multi-author drift is only visible to one reader spanning the whole tree.
- Dispatch all auditors in a single message so they run in parallel, each read-only, each returning `file:line — severity — description` findings.

Done when: every hand-written source file falls inside exactly one domain auditor's scope, the cross-cutting auditor spans them all, and all auditors have been dispatched.

## 3. Collate and archive

- When all auditors report back, collate into one report: verdict, hazard callouts (real risks get separated from style findings), ranked top cleanups, per-area findings with severity and `file:line`, the **fault lines** (which files read like different authors), and a "genuinely good — don't fix" section. On a delta run, lead with fixed / persisting / new counts.
- Load the `artifact-design` skill, build the report as a single self-contained HTML page, publish it as an artifact.
- Wrap the page as a standalone HTML document (doctype, head, body — artifacts omit these) and import it into the DEVONthink group, titled `<Repo> Code Smell & Style Audit (<date>)`.

Done when: the artifact URL is live and the DEVONthink record exists in the target group with that title.

## 4. Capture conventions

- Create a Markdown record in the same DEVONthink group titled `Conventions observed — <repo> (<date>)`, tagged `conventions-survey`, recording per dimension (error-message grammar, panic/error boundary, naming and constructor patterns, test idioms and helper prefixes, script prologue, comment density): the dominant convention, whether it is documented or only observed, and the drift pockets that diverge from it.
- This record is the raw material for the cross-repo conventions synthesis — write it so it can be compared side-by-side with the same record from other repos.

Done when: the tagged record exists and covers every dimension the cross-cutting auditor reported on.

## 5. Tickets

- Read `~/.claude/skills/to-tickets/SKILL.md` and follow its process with these overrides: batch findings into roughly 5–10 tickets grouped by surface (one coherent PR each); any hazard fix is its own unblocked ticket; a doc-only convention-codification ticket gates the code-sweep tickets; every ticket carries a Source section linking the artifact and the DEVONthink record; bodies cite symbols, never line numbers.
- Present the breakdown and get the user's approval before publishing — this gate is never skipped.

Done when: all approved tickets are live on the tracker with native blocking edges and the agent-ready label.

## 6. OmniFocus mirror

- Mirror the tickets under the given parent task so availability matches the tracker **frontier** exactly: unblocked tickets as direct children, chains as sequential groups, a gate-then-parallel shape (sequential group whose first child precedes a parallel subgroup) where one ticket unblocks several. Set the parent parallel. Each task's note carries its issue URL, a one-line delivery statement, and its blockers.
- Verify with a tree read: every frontier ticket shows available, everything else blocked.

Done when: OmniFocus available/blocked states match the tracker frontier one-for-one.

## 7. Report

Final message: the verdict in one sentence, hazards first, the frontier and highest-leverage first pick, and every link produced — artifact, DEVONthink records, issues, OmniFocus parent.
