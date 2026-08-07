---
name: append-dev-journal
description: Append or create a repository DEV-JOURNAL.md entry for any project, using evidence-backed markdown, default-branch metadata, append-only safety checks, commit-and-push completion, and optional helper-script automation.
---

# `append-dev-journal`

Use this skill when a project needs a new development-journal entry recording a
session, milestone, release, handoff, decision batch, or other meaningful
project boundary. The skill works in any git repository and no longer assumes a
specific organization, repo map, session prefix, or counter scheme.

## Hard precondition

**NEVER start this skill until AFTER the main work has merged.**

When invoked from planit, review-loop, architecture-slice, or any PR-driven
workflow, the product PR (or other primary deliverable) must already be merged
to the default branch. Do not draft, preview, append, open a journal PR, or
commit journal updates while the main PR is still open, waiting on CI, or only
locally certified. Journal is post-merge only.

## Default Entry Shape

New generic entries use:

```markdown
## <short title> - YYYY-MM-DD HH:MM TZ

**Main:** `<default-branch-sha>`
**Actor:** <actor>

<entry body>
```

Use a concise, factual title such as `Web UI review handoff`,
`v0.3.0 release prep`, or `Parser hardening landed`. Do not use repo-specific
prefixes or session counters unless the user explicitly asks for legacy format.

Body sections are adaptive. Use only the sections supported by the evidence:
`Summary`, `Completed`, `Decisions`, `Validation`, and `Next`.

## Evidence Rules

- Prefer drafting the body from repo/session evidence: `git log`, `git diff`,
  PR/issue state when available, validation output, and explicit user context.
- Do not invent board status, issue closures, test results, merge state, or
  future work. If a material fact is missing or ambiguous, ask before appending.
- When a canonical decision record exists (issue-tracker resolution, ADR,
  planning map), a `Decisions` line is: the decision's gist (a line or two)
  plus a link to that record. The record holds the rationale and detail; the
  journal points at it.
- `Next` is a snapshot as of the entry timestamp. When a live work-tracking
  surface exists (tracker, board, map), a `Next` line is: the snapshot gist
  plus a link naming that surface as the live view.
- Keep entries append-only historical records. Do not revise old entries as part
  of an append.
- If the user supplies final `entry_body_markdown`, append that body after
  basic validation instead of rewriting it.

## Journal Resolution

Resolve the target from the current git repo:

1. If the user supplies `journal_path`, use that path after confirming it is
   inside the repo.
2. Otherwise, if exactly one of `DEV-JOURNAL.md` or `docs/DEV-JOURNAL.md`
   exists, use it.
3. Otherwise, if neither exists, create `docs/DEV-JOURNAL.md` with the generic
   append-only banner and the new entry.
4. Otherwise, if both exist, stop and ask which journal to use.

Existing journals do not need a matching banner, template, heading style, or
metadata block. New entries still use the default generic shape unless the user
explicitly asks for a legacy/custom format.

## Helper Script

Use `scripts/dev_journal.py` for deterministic mechanics. It lives inside this
skill's base directory — the path announced when the skill loads; `<skill-base-dir>`
below stands for that path. Run it from the repo where the journal should be
updated.

Preview without writing:

```bash
python3 <skill-base-dir>/scripts/dev_journal.py \
  preview --title "Short title" --actor "<actor>" --body-file /path/to/body.md
```

Append after inspecting the preview:

```bash
python3 <skill-base-dir>/scripts/dev_journal.py \
  append --title "Short title" --actor "<actor>" --body-file /path/to/body.md
```

Useful options:

- `--repo <path>`: run against a repo other than the current directory. Put
  this before `preview` or `append`.
- `--journal-path <path>`: explicit target path, relative to the repo or
  absolute inside it.
- `--datetime-tz "YYYY-MM-DD HH:MM TZ"`: override the timestamp.
- `--main-sha <sha>`: supply a known default-branch commit when automatic
  detection is unavailable.

The script:

- detects the git root;
- resolves or creates the journal path;
- computes `Main` from the remote/default branch when possible, falling back to
  the local default branch;
- blocks if the target journal already has uncommitted changes;
- allows unrelated dirty files;
- creates a git-internal append lock with one-hour stale-lock protection;
- appends only at EOF;
- blocks duplicate headings;
- preserves newline termination.

## Procedure

0. Confirm the main work is already merged to the default branch (see Hard
   precondition). If it is not, stop and do not run this skill.
1. Gather enough evidence to write a factual entry. Use `git status --short`,
   recent `git log`, relevant diffs, PR/issue state, validation output, and user
   notes as appropriate.
2. Draft the entry body in scratch. Include only supported adaptive sections.
   Keep the body complete before writing; do not append partial metadata first.
3. Run the helper in `preview` mode. Inspect the resolved path, computed
   metadata, separator behavior, and complete entry.
4. Run the helper in `append` mode. If it stops on ambiguity or dirty target
   journal state, resolve that condition before retrying.
5. Verify the final diff. Historical content must be unchanged, exactly one new
   entry should appear, and the file must end with a newline.
6. Run the repo's normal validation gate when one is documented. At minimum,
   run `git diff --check` for markdown-only journal updates.
7. Commit and push the journal update, unless the user explicitly asked not to:
   - Stage only the resolved journal path, never unrelated dirty files:
     `git add -- <journal-path>`.
   - Commit with a concise message such as
     `docs: update development journal`.
   - Push the current branch to its upstream with `git push`. If no upstream is
     configured, set it explicitly for the current branch after confirming the
     intended remote/branch from git metadata or user context.
   - After pushing, verify `git status --short -- <journal-path>` is clean and
     capture the commit SHA for the final response.
8. Merge

## Failure Cases

Stop without appending if:

- the main product work for this journal entry has not yet merged to the
  default branch (hard precondition);
- the current directory is not inside a git repo;
- the target journal path would be outside the repo;
- both `DEV-JOURNAL.md` and `docs/DEV-JOURNAL.md` exist and the user did not
  choose one;
- the target journal already has uncommitted changes;
- the lock exists and is not provably stale;
- the title, body, timestamp, actor, or commit metadata is malformed or missing;
- the generated heading already exists;
- source evidence is insufficient for a factual body;
- the final diff contains anything other than the intended single journal
  append;
- the journal update cannot be committed or pushed safely without including
  unrelated changes.
