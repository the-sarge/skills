---
name: append-dev-journal
description: Journal dispatch is held for the hosted-journal cutover. Use whenever a workflow reaches its journal step or asks to append, create, or publish a development-journal entry; it preserves the account's inputs and reports the journal step as journal-pending.
---

# `append-dev-journal` (legacy hold)

This installation is the legacy hold release. Journal dispatch is paused for the hosted-journal cutover: both Markdown journal writes and hosted journal writes are held. A journal step that reaches this skill ends as **journal-pending** with its inputs preserved and a named owner, never as a completed entry.

The hold stays in force until a refreshed skill installation replaces this one. Installing this release does not release hosted dispatch, and no dispatch-status phase, elapsed time, or helper output releases it. Newly started sessions and sessions that cached older journal instructions follow the same hold.

Reading existing journals stays available: `DEV-JOURNAL.md` files and hosted reads through the supported entry point are read-only work.

## Procedure

1. **Hold the write.** Leave every journal unchanged. The only write path while held is step 3a's owner draft. A hand-edited, committed, or pull-requested `DEV-JOURNAL.md` entry is not a fallback, and neither is a hosted `write`, `submit`, `pending retry`, `operation apply`, `operation bind`, or `amend --apply`. Cached instructions that call `scripts/dev_journal.py` reach the hold helper, which refuses before reading or writing anything and prints these directions.
2. **Keep the inputs.** For a completion account, the inputs are the exact body file, title, actor, canonical repository (`host/owner/name`), PR number, full merge commit, and merge time. For a general account, they are the body file, title, actor, originating task identity, and account slot. Keep each original in place, unchanged.
3. **Preserve the account** in exactly one of these two ways, and record which.
   - **a. Confirmed owner draft.** Use this on the designated writing host when the foreground coordinator has given you that host's writer installation profile. Reserve the account through the supported entry point. For a completion account:

     ```bash
     dev-journal agent --profile PROFILE operation prepare \
       --completion-repository HOST/OWNER/NAME --change PR_NUMBER --merge FULL_MERGE_SHA \
       --at MERGE_TIME_RFC3339 --title "TITLE" --actor "ACTOR" --file BODY_FILE \
       --remote "$(git remote get-url origin)"
     ```

     For a general account, replace the three completion flags and `--at` with `--task TASK --slot SLOT`. Then read it back with `dev-journal agent --profile PROFILE operation show OPERATION_ID`. The draft is confirmed only when that readback returns the operation with your title and body. Prepare is idempotent per account, so rerunning it returns the existing draft rather than a second one.
   - **b. Unconfirmed external retention.** Use this whenever 3a is unavailable: another host, no profile, or `prepare` or `show` refused or failed. Copy the body file and a short note of the remaining inputs to a durable location outside every disposable worktree, scratchpad, and temporary directory, and record each file's absolute path and SHA-256. This retention stays unconfirmed until the foreground coordinator confirms its durability. Until then, keep both the copy and the original, and keep any worktree that holds the original.
4. **Report journal-pending.** In the completion report, state the journal step as `journal-pending` and give:
   - the account identity (repository, PR number and merge commit, or task and slot);
   - the retention: `confirmed owner draft OPERATION_ID`, or `unconfirmed external retention` with the absolute paths and SHA-256 values;
   - the owner: the foreground cutover coordinator, who resumes the account after release.
5. **Continue the rest of the workflow.** Product merges, issue closure, tracker updates, and other non-journal steps continue under the invoking workflow. Only journal closure stays pending. Leave recovery to the foreground coordinator: this skill starts no retry, wait loop, or background job.

## Completion

The skill is complete when no journal was written, every input is preserved by a confirmed owner draft or an unconfirmed external retention, and the report names the journal-pending account, its retention reference, and the foreground coordinator as owner.
