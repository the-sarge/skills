---
name: dev-journal
description: Write, find, read, and amend hosted development-journal entries through the dev-journal CLI's supported entry point. Use whenever a workflow owes a journal account (a post-merge completion account or a general session account), when a journal step reports pending or needs recovery, when asked what the journal says about a repository's history or intent, or when an accepted entry needs a correction, addendum, or comment. Legacy DEV-JOURNAL.md files are historical reading sources, never write targets.
---

# `dev-journal`

This skill owns the agent procedure for the hosted journal: writing accounts, finding and completely reading entries, deliberate amendments, and reporting pending work. It holds no state of its own. The `dev-journal` CLI and its submission owner own durable drafts, operation lookup, immutable requests, receipts, and recovery; hosted receipts are the acceptance authority. Callers decide when an account is owed and then follow this skill; they do not restate its rules.

A journal step is **complete** when the relevant hosted receipt and its readback establish where the authored account was recorded. Until then it is **journal-pending**.

## Entry point and profile

Route journal operations through the supported entry point and put command names before their flags.

```bash
dev-journal agent --profile PROFILE COMMAND [ARGS]
```

`PROFILE` is the absolute path of this host's installed profile, supplied by the operator or recorded by the installation. To inspect the installed role and validate its proof, run `dev-journal profile show --profile PROFILE`. The `agent` entry point revalidates it on each call. A **writer** profile can prepare and apply in its own protected local store. A **reader** profile allows reads. Use the installed binary and profile as supplied. Keep `--config` and `--state-dir` out of routed commands.

If the installation is missing, read-only or invalid, follow [No writer profile](#no-writer-profile). If routing or the service refuses a retained write, preserve the local selector and report it [pending](#pending-accounts). Leave profile setup, migration, recovery and fence changes to the operator. Continue to honor any hold already loaded in the session and leave identified pre-upgrade random-ID obligations with their recorded owners. [Operator upgrade and rollback runbook](https://github.com/the-sarge/dev-journal/blob/main/docs/operations/writer-profile-upgrade.md)

Never use these routes, even when they would work: hand-editing, appending to, committing, or opening a PR for any `DEV-JOURNAL.md`; raw `write`; raw `amend --apply`; `pending retry` outside the operation that owns the request; or any helper script. The entry point refuses most of them, and this skill forbids all of them.

## Repository identity

Resolve the account's repository from that repository's own checkout, not from whatever directory you are in:

```bash
dev-journal agent --profile PROFILE repository resolve --remote ACCOUNT_REPOSITORY_REMOTE_URL
```

When it resolves, use the matching HTTPS locator from `Aliases` for `--completion-repository`. Select the destination with the checkout `--remote` shown below or the verified `--repo REPOSITORY_ID`.

When the repository is unregistered or lookup is unavailable, a writer can still prepare offline with the checkout `--remote`. For a completion, supply the merged repository's full, case-preserving HTTPS locator from the forge as `--completion-repository`. Keep the draft and report its selector and resume owner as journal-pending. The matching locator must be a registered alias of the chosen destination before it can bind. Ask the operator to resolve registration or selection. Historical import is a separate operator action.

## Write an account

### Gather the facts first

For a **completion account**, establish the actual merge on the default branch before drafting or reserving the account. Use the repository locator from [Repository identity](#repository-identity), PR number, full merge commit, and exact forge merge timestamp. For a **general account**, use the originating issue or session and an explicit account slot or owner-reserved handle. A standalone freeform note can use a handle by itself. Two hosts naming the same task and slot owe the same account. Reuse the known identity when resuming and reserve a fresh handle only for a distinct account.

Write the body from evidence: the merge, PR and issue state, validation output, and session notes. Keep each issue and PR reference with its number, link canonical decision records and live trackers rather than restating them, and record only facts the evidence supports. When the user supplies the body, keep it intact. `--actor` is narrative attribution and stays distinct from the authenticated identity. Write the body to a file and keep that file unchanged until the account is accepted.

Supply `--at` as RFC 3339 with seconds and an explicit offset. For a completion account, use the forge merge timestamp verbatim. For a shared general account, use the same explicit work timestamp across hosts or carry over the exact date frozen at its first prepare. Each store otherwise supplies its own date for a task account. Preserve exact spelling, including `Z` or `+00:00`. If a standalone note was prepared without a date, keep `--at` omitted when reproducing it. The service supplies that note's date on acceptance.

### Prepare, read back, apply

1. **Prepare** the draft offline. For a completion account, use the full repository HTTPS locator for the identity and the checkout remote for the destination lookup.

   ```bash
   dev-journal agent --profile PROFILE operation prepare \
     --completion-repository REPOSITORY_HTTPS_LOCATOR --change PR_NUMBER --merge FULL_MERGE_SHA \
     --at MERGE_TIME_RFC3339 --title "TITLE" --actor "ACTOR" --file BODY_FILE \
     --remote ACCOUNT_REPOSITORY_REMOTE_URL
   ```

   For a general account, use `--task TASK --slot SLOT` in place of the three completion flags and follow the date guidance above. To use a handle, replace `--slot SLOT` with the existing `--handle HANDLE` or reserve one with `--reserve-handle`. Use `--additional` with `--reserve-handle` only for a deliberately separate account for the same task. Use `--reuse-handle` with `--handle` only for a known general account from another store when there is no retained attempt to resume there. For a new standalone freeform note, omit `--task` and use `--reserve-handle`.

2. **Read back** the exact selector from prepare with `operation show OPERATION_ID` and compare the identity, destination and authored fields, including the exact body. A completion prepare with the same intent rediscovers its selector. Different completion wording can return a separate contribution selector. Use `operation list` to recover selectors when needed. If prepare reports a held proposal, see [Changed authored intent](#changed-authored-intent).
3. **Apply** the selector in the same installation and include `--json` for verification. Use `operation apply OPERATION_ID` for a general account. For a completion, follow the shown `Apply:` command under `agent --profile PROFILE`. Apply a child contribution by its own ID or select it with `operation apply ROOT_OPERATION_ID --contribution CONTRIBUTION_ID`. Use the root ID as both arguments to select the root's own contribution explicitly. Apply can settle an outstanding prerequisite original for the selected child. It leaves any other contributions for explicit selection.
4. **Verify and report** the relevant [receipt and readback](#receipt-and-readback), then [report journal success to the user](#report-to-the-user). An unverified result follows [Pending accounts](#pending-accounts).

### Receipt and readback

In the apply JSON, use `operation.association.receipt` if an association is present. Otherwise use the accepted `submission.receipt`. For an original, match that receipt to `readback.receipt` and check `readback.original` against the retained intent or the original verified for association. For an amendment, find the matching receipt in `readback.amendments` and compare that record's request to the selected authored content. Decode `body_base64` to compare body bytes. For a no-op amendment, require the matching accepted receipt with `noop` set and the CLI's verified account readback. A no-op may have no amendment record.

A matching completion can recover the receipt of the original or of an already recorded complete comment. Different content for the same merge can be accepted automatically as a complete comment, preserving its own body and authored fields beside the earlier original. A later explicit correction leaves the introducing comment's receipt intact. Different content for a shared general identity needs deliberate disposition by the account owner.

### Report to the user

After confirmed acceptance and readback, give the user a descriptive Markdown link to the actual hosted entry in the final session report. For the personal hosted journal, use `[Read the journal entry](https://app.dev-journal.com/journal/entries/ENTRY_ID)` with `ENTRY_ID` replaced by the URL-escaped entry ID from the verified receipt. Use the canonical reader origin even if the installation uses a legacy API endpoint. For another installation, use the documented browser reader origin and entry route for that service and workspace. A comment or correction links to its containing entry, and an association links to the selected existing entry. A browser sign-in may be required. [Hosted reader route](https://github.com/the-sarge/dev-journal/blob/main/docs/design/private-reader.md) · [Personal journal origin](https://github.com/the-sarge/dev-journal/blob/main/docs/operations/render.md#application-domain-and-client-configuration)

If the reader origin or route cannot be established, report the verified entry ID and say the reader link is unavailable. Keep the selected operation ID and the accepted receipt's request ID, entry ID and revision in the durable record. Read the revision from the selected receipt. The entry may have moved to a newer revision. Reserve identifiers in the chat for recovery or when the user asks for them. For pending work, use the [pending report](#pending-accounts) with its recovery reference.

### Associate an existing account

Read the entry and its history. Use `operation associate OPERATION_ID --entry ENTRY_ID` only when the hosted original itself satisfies the obligation, belongs to the same repository, and the selected operation is an eligible draft or its attempt is proved never dispatched. Apply the inspected selector with `--json` for verified readback of that association. For a matching complete comment on an earlier original, rediscover the exact completion contribution with `operation list` or prepare the same authored intent if its selector is absent. Apply that selection and verify the introducing comment's receipt. For an original captured by a bound import, the operator can use the import association route with that bundle's evidence. An uncertain attempt stays on its exact recovery path. After readback, [report journal success to the user](#report-to-the-user).

### Changed authored intent

When prepare reports `conflict` and `operation show OPERATION_ID --json` confirms a held proposal, preserve both versions. `revision` identifies the current draft, `intent` holds its authored fields, and `held_proposals` lists each proposed `intent` in order (bodies are base64 in `body_base64`). Follow the printed resolution guidance for that operation.

- To deliberately resolve your unbound account draft, run `operation revise OPERATION_ID --expected-revision N` with the inspected revision. Reproduce the selected intent's repository selection, title, decoded body file, attribution, journal date, historical flag, metadata and links. For a historical freeform note, pass both `--at` and `--historical` again. Use `operation revise-amendment` for an unbound amendment with the complete selected amendment intent. An exact reproduction of the current intent keeps it and disposes the proposals without opening a new revision.
- If an attempt is bound, use `operation resolve OPERATION_ID --expected-attempt N --proposal P --reason "REASON"` only when it is authoritatively settled as never dispatched. `N` is the current attempt sequence, and `P` is the proposal's 1-based position in `held_proposals`, or 0 to rebind the current intent.
- If you are not the account's owner, or the right content is unclear, leave both versions as they are and report the conflict, with its operation ID, to the owner as journal-pending.

### No writer profile

If the installed writer is unavailable or prepare or show fails before retention can be confirmed, copy the exact body and all other inputs to a durable location outside every disposable worktree, scratchpad and temporary directory. Keep the chosen identity, repository, title, date with its original spelling or omission, historical flag, actor, metadata and links, plus the amendment entry, kind, target, revision token, reason and patch when applicable. Record the host name, absolute paths and SHA-256 values. Preserve any known selector or request too. External retention stays **unconfirmed** until the account's owner verifies its durability. Until then keep the copy, original and any worktree holding the original. [Report journal-pending](#pending-accounts) with the named resume owner.

## Pending accounts

Every account that is not accepted with readback is journal-pending. Its owner is the foreground owner of the invoking workflow: the session or coordinator that will resume it. Name that owner explicitly. When your own session will end first, as a dispatched worker's does, the owner is the coordinator or operator that dispatched you, never yourself; a coordinator that finds a pending account whose named owner is gone records itself as the owner before resuming it. Record the pending account in the durable task record the workflow already keeps (its issue comment or completion receipt), with:

- the account identity (repository, PR number and merge commit, or originating task and slot or reserved handle, plus the entry and subject for an amendment);
- the originating installation and operation ID or contribution selector, its state, and its current request ID if bound, or the external retention with host, paths, SHA-256 values and confirmation state;
- the named resume owner and where the resume reference is recorded.

The named owner resumes the retained selection in its original installation. If only authored inputs were retained, first check for an existing selector or accepted receipt before preparing from those inputs on an available writer. When a verified account or complete comment already satisfies the obligation, follow [Associate an existing account](#associate-an-existing-account). Leave store copies with operator recovery.

- Inspect with `operation show OPERATION_ID`. For a bound request, use `pending show REQUEST_ID` to inspect the retained request's disposition.
- For a draft or interrupted selection without a bound request, resume using its inspected apply selector. For `pending` or `outcome_unknown` with a current bound request, use `operation apply OPERATION_ID --request REQUEST_ID` with the selected operation's own ID and the retained request ID. Omit `--contribution` on an exact retry. If the CLI confirms a settled completion collision or stale complete-comment attempt and instructs you to continue the same contribution, follow that inspected apply selector without `--request`. Keep an ambiguous request with its existing operation for exact retry.
- For a settled collision with different content for the same general account, keep the operation and collision evidence. Report journal-pending to the named account owner with the retained operation and competing entry IDs, even if `pending list` is empty. Leave any new slot, handle or deliberate amendment to that owner's decision.
- For an accepted selection with readback still due, apply that selection again to retrieve its verified receipt and readback. For `reconciliation_required`, a recovery-generation conflict or a conflicting payload, preserve the evidence and refer it to the operator for disposition.

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

1. Run `read ENTRY_ID`, inspect the subject and take the opaque `Revision token:` (`revision_token` with `--json`). Use `history` when you need the revision index or the introducing revision of an attached subject.
2. Reserve the amendment. For a correction to an attached subject, add `--target-revision N` with its introducing revision.

   ```bash
   dev-journal agent --profile PROFILE operation amend ENTRY_ID --kind KIND \
     --revision REVISION_TOKEN --reason "REASON" --file TEXT_FILE --task TASK --slot SLOT
   ```

   An original correction can also replace the title, date or entry metadata. For an attached subject, use text and, when needed, a links-only metadata patch. Use `--reserve-handle` instead of `--slot` to have the owner reserve one.
3. Check the retained intent and preview it with `operation preview OPERATION_ID`, then apply it with `operation apply OPERATION_ID --json`, verify its [receipt and readback](#receipt-and-readback), and [report journal success to the user](#report-to-the-user).

If the revision check fails, reread the entry. Use `operation revise-amendment` at the expected draft revision to resolve changed intent while still unbound. If the CLI confirms a dispatched correction was rejected for a stale token, retain that exact attempt. Only if the owner still wants to make the change after inspecting the new revision, reserve a distinct amendment under a new slot or handle with the fresh token. Follow exact-request recovery for an ambiguous dispatch.

## Legacy journals and completed history

- **Historical files.** A repository's `DEV-JOURNAL.md` is a historical record. Read it as history when the question is explicitly historical, for example a period or repository the hosted journal does not cover. Reading it never imports it, and an excluded history stays excluded.
- **Non-entry text is history too.** Header append directions ("New entries go at the END of this file", "scroll to the bottom and append"), preamble status or trigger notes, and templates inside a legacy journal describe the earlier method or an earlier state. They are not live instructions. Do not follow them as write directions, and do not edit them to keep them current. When such a note mirrors a live fact, such as an implementation trigger, update the authoritative source it mirrors (an ADR status, `AGENTS.md`, `README.md`) and leave the journal bytes unchanged. If no other source holds that fact, leave the journal unchanged and report the gap.
- **Current instructions** come from the installed skills and each repository's governing sources. A repository's stronger journal rule governs over this skill, but this skill cannot change it. When a repository's governing source still requires a Markdown journal write, a journal commit, or a journal PR, follow neither that rule nor a Markdown fallback: hold the account as journal-pending with its inputs kept, and report the conflict to the operator.
- **Completed legacy closure stays complete.** A journal step completed under the earlier Markdown method before the hosted release, with its journal commit or journal PR merged, remains satisfied. Do not re-journal it, write a hosted duplicate, or demand a hosted receipt for it. Hosted completion applies to accounts owed after release.

## Completion

The skill is complete when the owed account is accepted and read back, or is reported journal-pending with its identity, operation or retention reference, state, and named resume owner, with no Markdown journal changed.
