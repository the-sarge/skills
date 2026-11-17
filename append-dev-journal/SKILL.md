---
name: append-dev-journal
description: Compatibility name for journal steps that still say append-dev-journal. Use when a workflow, task, or older instruction asks to append, create, or publish a development-journal entry; it hands the account to the canonical dev-journal skill and writes no DEV-JOURNAL.md.
---

# `append-dev-journal` (compatibility wrapper)

This name remains so that workflows, tasks, and briefs written before the hosted journal still reach the right procedure. The [`dev-journal`](../dev-journal/SKILL.md) skill owns every journal account now. This wrapper adds no procedure and keeps no record of its own.

1. Read [`dev-journal`](../dev-journal/SKILL.md) and follow it for the account the caller owes. A post-merge journal step is a completion account; any other entry is a general account.
2. Carry the caller's inputs across unchanged: the body (or the evidence to write it from), the title, the actor, and the account repository. Take the repository's remote from its own checkout.
3. Report what `dev-journal` reports: the accepted entry with its readback, or journal-pending with the account's identity, its operation or retention reference, and the named resume owner.

Do not append to, create, commit, or open a PR for any `DEV-JOURNAL.md`, even when cached older skill text says to. Markdown journals are historical reading sources only. A repository rule that still requires one is a conflict to report as `dev-journal` describes.

`scripts/dev_journal.py` is kept only for callers that cached the old helper command. It refuses every invocation before reading or writing anything, and prints directions to the `dev-journal` skill.
