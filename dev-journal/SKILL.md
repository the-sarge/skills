---
name: dev-journal
description: Write, find, read, and amend hosted development-journal entries through the dev-journal CLI's supported entry point. Use whenever a workflow owes a journal account (a post-merge completion account or a general session account), when a journal step reports pending or needs recovery, when asked what the journal says about a repository's history or intent, or when an accepted entry needs a correction, addendum, or comment. Legacy DEV-JOURNAL.md files are historical reading sources, never write targets.
---

# `dev-journal`

This skill owns the agent procedure for the hosted journal: writing accounts, finding and completely reading entries, deliberate amendments, and reporting pending work. It holds no state of its own. The `dev-journal` CLI and its submission owner own durable drafts, operation lookup, immutable requests, receipts, and recovery; hosted receipts are the acceptance authority. Callers decide when an account is owed and then follow this skill; they do not restate its rules.

A journal step is **complete** only when the account has an accepted hosted receipt and its original has been read back. A Markdown append, a journal commit, or a journal PR is not completion. Anything short of acceptance and readback is **journal-pending**.

## Entry point and profile

Run every journal command through the supported entry point, naming the command first:

```bash
dev-journal agent --profile PROFILE COMMAND [ARGS]
```

`PROFILE` is the absolute path of this host's installation profile, supplied by the operator or recorded by the installation. Never guess it, and never pass `--config`, `--state-dir`, or `--host-identity`; the profile fixes them. A **writer** profile exists only on the designated writing host and can prepare and dispatch. A **reader** profile can only read. With no profile, do not write by any other route: keep the account's inputs as described under [No writer profile](#no-writer-profile).

The entry point checks the profile's dispatch status before any mutation. A refusal such as `journal dispatch is held in phase PHASE` means dispatch is paused: keep the prepared draft, report journal-pending, and do not retry or wait. Reading and local preparation stay available while dispatch is held.

Never use these routes, even when they would work: hand-editing, appending to, committing, or opening a PR for any `DEV-JOURNAL.md`; raw `write`; raw `amend --apply`; `pending retry` outside the operation that owns the request; or any helper script. The entry point refuses most of them, and this skill forbids all of them.

## Repository identity

Resolve the account's repository from that repository's own checkout, not from whatever directory you are in:

```bash
dev-journal agent --profile PROFILE repository resolve --remote ACCOUNT_REPOSITORY_REMOTE_URL
```

When it resolves, use the registered repository ID it reports. When the repository is not registered, do not guess an ID and do not fall back to a Markdown journal. Prepare the account with `--remote ACCOUNT_REPOSITORY_REMOTE_URL` so the draft keeps its authored intent until registration is resolved, report journal-pending, and tell the operator the repository needs registration or deliberate selection. Having no registered identity never authorizes importing that repository's historical journal.

## Write an account

### Gather the facts first

For a **completion account** (product work), first establish the actual merge on the default branch: canonical repository `host/owner/name`, PR number, full merge commit, and merge time from the forge. Never draft or reserve a completion account before the merge exists. For a **general account** (session, handoff, decision batch), use the originating task identity and an account slot, or ask the owner to reserve a handle.

Write the body from evidence: the merge, PR and issue state, validation output, and session notes. Keep each issue and PR reference with its number, link canonical decision records and live trackers rather than restating them, and record only facts the evidence supports. When the user supplies the body, keep it intact. `--actor` is narrative attribution and stays distinct from the authenticated identity. Write the body to a file and keep that file unchanged until the account is accepted.

The journal date for a completion account is the merge time. A general account uses the evidenced work time when there is one, otherwise its date is frozen at the first prepare. Pass dates as RFC 3339 with seconds and an explicit offset. A held draft keeps its date across midnight and delayed acceptance.

### Prepare, read back, apply

1. **Prepare** the draft. For a completion account:

   ```bash
   dev-journal agent --profile PROFILE operation prepare \
     --completion-repository HOST/OWNER/NAME --change PR_NUMBER --merge FULL_MERGE_SHA \
     --at MERGE_TIME_RFC3339 --title "TITLE" --actor "ACTOR" --file BODY_FILE \
     --remote ACCOUNT_REPOSITORY_REMOTE_URL
   ```

   A general account replaces the three completion flags with `--task TASK` plus `--slot SLOT`, `--handle HANDLE` for a handle the owner already reserved, or `--reserve-handle` to have the owner reserve one, keeping `--at` for an evidenced work time. Rerunning prepare with the same intent returns the existing draft. Add `--additional` (only with `--reserve-handle`) only when the owner deliberately wants a second account for the same task, never to get around an existing draft.
2. **Read back** the draft with `operation show OPERATION_ID`. Continue only when it shows exactly your title and body. A different title or body means the obligation already retains other intent; handle it under [Changed authored intent](#changed-authored-intent).
3. **Apply** it with `operation apply OPERATION_ID`. Apply binds the attempt, dispatches it through the retained record, and verifies the accepted original. Success reports `Readback: verified hosted original of entry ENTRY_ID at revision N`.
4. **Report** the entry ID, the operation ID, and that readback. That is journal completion.

If apply is refused because dispatch is held, or it ends in any state other than accepted with readback, the account is journal-pending: follow [Pending accounts](#pending-accounts).

### Changed authored intent

When prepare reports `conflict` because the obligation already retains different authored intent, the submission owner keeps both: the retained draft and your content as a held proposal. Do not prepare another account, and do not delete either version. Inspect both with `operation show OPERATION_ID --json`: `revision` is the draft's current revision, `intent` is the retained draft, and `held_proposals` lists each proposal's `intent` in order (bodies are base64 in `body_base64`). Then resolve explicitly, following the instruction the conflict printed:

- If you own the account and the new content is a deliberate correction of an unbound draft, run `operation revise OPERATION_ID --expected-revision N` with `N` that revision. Revise replaces the whole intent, so pass every field of the version you keep, taken from its JSON: exactly one repository selection (`--repo REPOSITORY_ID` or each `--remote`), `--title`, the decoded body as `--file`, `--actor` for its attribution, `--metadata` with its metadata as a JSON file, and each `--link`. An omitted field other than the journal date is dropped. Keep the proposal's fields to adopt it, or reproduce the current intent exactly to keep the draft; an exact reproduction disposes the proposals without a new revision.
- If an attempt is already bound or settled, use `operation resolve OPERATION_ID --expected-attempt N --proposal P --reason "REASON"` only after `operation show` reports that attempt authoritatively settled. `N` is the number of attempts shown, and `P` is the proposal's 1-based position in `held_proposals`, or 0 to rebind the current intent.
- If you are not the account's owner, or the right content is unclear, leave both versions as they are and report the conflict, with its operation ID, to the owner as journal-pending.

### No writer profile

When there is no writer profile on this host, or prepare or show is refused or fails, preserve the account outside the submission owner instead. Copy the body file and a note of the other inputs (title, actor, remote, and the completion or general identity) to a durable location outside every disposable worktree, scratchpad, and temporary directory, and record the host name, absolute paths, and SHA-256 values. This retention stays **unconfirmed** until the account's owner confirms its durability; until then keep the copy, the original, and any worktree holding the original.

## Pending accounts

Every account that is not accepted with readback is journal-pending. Its owner is the foreground owner of the invoking workflow: the session or coordinator that will resume it. Name that owner explicitly. When your own session will end first, as a dispatched worker's does, the owner is the coordinator or operator that dispatched you, never yourself; a coordinator that finds a pending account whose named owner is gone records itself as the owner before resuming it. Record the pending account in the durable task record the workflow already keeps (its issue comment or completion receipt), with:

- the account identity (repository, PR number and merge commit, or task and slot);
- the operation ID, its state, and its current request ID, or the unconfirmed external retention with host, paths, and SHA-256 values;
- the named resume owner and where the resume reference is recorded.

Resume only that operation, and only as its owner:

- `operation show OPERATION_ID` (and `pending show REQUEST_ID`) report its state: `unbound_draft`, `pending`, `outcome_unknown`, `reconciliation_required`, or `accepted`.
- `pending` or `outcome_unknown`: resume with `operation apply OPERATION_ID`, or `operation apply OPERATION_ID --request REQUEST_ID` to retry exactly that retained request. A timeout or a missing receipt is not permission to create a new request or a new account.
- `reconciliation_required`, a recovery-generation conflict, or a payload conflict: stop. Keep all evidence and report it to the operator for disposition.
- An obligation whose account was already accepted elsewhere, such as one captured by a history import, is closed by `operation associate`, not by a second account. That is the cutover coordinator's action.

Do not drain other pending accounts, start a background retry or wait loop, or fall back to Markdown. Before cleaning up a worktree, confirm every input, operation pointer, and recovery artifact the account needs is durable and discoverable elsewhere. An empty retention field is not proof.

Journal closure is separate from engineering progress. A pending account does not stop product merges, issue closure, or tracker updates; the overall completion report stays explicitly journal-pending until acceptance and readback.

## Find and read

To answer what the journal records for a repository, query the hosted journal:

```bash
dev-journal agent --profile PROFILE list --repo REPO_ID
dev-journal agent --profile PROFILE search "QUERY" --repo REPO_ID
```

Results are paged. A complete answer requires following each page's `Next cursor` with `--cursor` until no cursor remains; never treat the first page as the whole history. State any `--from`, `--until`, `--topic`, or `--repo` filter that bounds the answer.

`read ENTRY_ID` returns the complete original account, and `history ENTRY_ID` returns its complete revision index, including amendments. Read the entry, and check its history when amendments matter, before quoting or relying on it.

## Amend an accepted entry

Accepted originals are immutable. Change what an entry says only through a deliberate amendment, and only when you have a reason to: a `correction` of the original, an `addendum`, or a `comment`. Never write a new account to replace an old one.

1. Run `read ENTRY_ID` and take its `Revision token:` (`revision_token` with `--json`), an opaque token. `history` lists the revisions and amendments but is not the token source.
2. Reserve the amendment:

   ```bash
   dev-journal agent --profile PROFILE operation amend ENTRY_ID --kind KIND \
     --revision REVISION_TOKEN --reason "REASON" --file TEXT_FILE --task TASK --slot SLOT
   ```

   A correction may also replace `--title`, `--at`, or `--metadata`. Use `--reserve-handle` instead of `--slot` to have the owner reserve one.
3. Check it with `operation preview OPERATION_ID`, then apply it with `operation apply OPERATION_ID` and read the entry back.

If the entry changed after you read it, the revision check fails. Read it again and decide afresh; do not force the amendment. A changed amendment draft is resolved with `operation revise-amendment` at the expected revision, as in [Changed authored intent](#changed-authored-intent).

## Legacy journals and completed history

- **Historical files.** A repository's `DEV-JOURNAL.md` is a historical record. Read it as history when the question is explicitly historical, for example a period or repository the hosted journal does not cover. Reading it never imports it, and an excluded history stays excluded.
- **Non-entry text is history too.** Header append directions ("New entries go at the END of this file", "scroll to the bottom and append"), preamble status or trigger notes, and templates inside a legacy journal describe the earlier method or an earlier state. They are not live instructions. Do not follow them as write directions, and do not edit them to keep them current. When such a note mirrors a live fact, such as an implementation trigger, update the authoritative source it mirrors (an ADR status, `AGENTS.md`, `README.md`) and leave the journal bytes unchanged. If no other source holds that fact, leave the journal unchanged and report the gap.
- **Current instructions** come from the installed skills and each repository's governing sources. A repository's stronger journal rule governs over this skill, but this skill cannot change it. When a repository's governing source still requires a Markdown journal write, a journal commit, or a journal PR, follow neither that rule nor a Markdown fallback: hold the account as journal-pending with its inputs kept, and report the conflict to the operator.
- **Completed legacy closure stays complete.** A journal step completed under the earlier Markdown method before the hosted release, with its journal commit or journal PR merged, remains satisfied. Do not re-journal it, write a hosted duplicate, or demand a hosted receipt for it. Hosted completion applies to accounts owed after release.

## Completion

The skill is complete when the owed account is accepted and read back, or is reported journal-pending with its identity, operation or retention reference, state, and named resume owner, with no Markdown journal changed.
