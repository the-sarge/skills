---
name: devonthink-cli
description: Use when an agent needs to read, search, capture, mutate, organize, classify, compare, or manage DEVONthink records/groups/smart groups using the local devonthink CLI. Includes safety rules for live DEVONthink data, UUID discovery, JSON parsing, MCP write gates, confirmation fields, indexed-file handling, and partial-update recovery.
---

# DEVONthink CLI

Use the local `devonthink` binary to inspect or modify the user's live
DEVONthink databases. Prefer `~/.local/bin/devonthink`; fall back to
`devonthink` on `PATH` if needed.

## Safety Rules

- Use `--json` for every command whose output you parse.
- DEVONthink must be running on macOS. If it is unavailable, report that to the
  user instead of trying to launch or repair it yourself.
- Read before writing. Discover UUIDs with `databases`, `groups`,
  `smart-groups`, `search`, `get`, `classify`, `compare`, or `see-also`; never
  guess UUIDs from names.
- Write only when the user explicitly asks to change DEVONthink.
- Capture and mutation commands modify live data: `create-*`, `import-file`,
  `index-file`, `annotations summarize`, `annotations set`, `annotations clear`,
  `reminders add`, `reminders update`, `reminders remove`, `rename`, `move`, `tags add`,
  `tags remove`, `trash`, `groups create|rename|move|trash`, and
  `smart-groups create|rename|move|trash|update`.
- Trash is soft delete only and still requires `--confirm UUID`. Hard delete
  and empty-trash are not CLI or MCP surfaces.
- `index-file` leaves the file on disk and requires `--confirm-indexed` to
  match the cleaned absolute path.
- There is no content overwrite command and no blind full-tag replacement
  command. Use `tags add` and `tags remove` only after reading current tags.
- If a command returns `partial_update`, stop and inspect the returned
  `details`; fetch/search the affected record, group, or smart group before
  retrying.
- If Automation permission fails, tell the user to grant access in
  System Settings -> Privacy & Security -> Automation.

## Quick Checks

```sh
~/.local/bin/devonthink doctor --json
~/.local/bin/devonthink version --json
```

## Common Reads

```sh
~/.local/bin/devonthink databases --json
~/.local/bin/devonthink groups --database "Work" --json
~/.local/bin/devonthink groups --parent GROUP_UUID --json
~/.local/bin/devonthink smart-groups --database "Work" --json
~/.local/bin/devonthink smart-groups get SMART_GROUP_UUID --json
~/.local/bin/devonthink smart-groups results SMART_GROUP_UUID --limit 10 --json
~/.local/bin/devonthink search "query text" --limit 10 --json
~/.local/bin/devonthink search "query text" --group GROUP_UUID --limit 10 --json
~/.local/bin/devonthink get RECORD_UUID --json
~/.local/bin/devonthink read RECORD_UUID --json
~/.local/bin/devonthink tags RECORD_UUID --json
~/.local/bin/devonthink annotations count RECORD_UUID --json
~/.local/bin/devonthink annotations get RECORD_UUID --json
~/.local/bin/devonthink reminders get RECORD_UUID --json
~/.local/bin/devonthink custom-metadata list RECORD_UUID --json
~/.local/bin/devonthink custom-metadata get RECORD_UUID --key review_state --json
```

Use `--database NAME_OR_UUID` or `--group GROUP_UUID` to keep searches focused.
`groups` lists ordinary groups; use `smart-groups` for smart group discovery
and lifecycle commands.

Custom metadata can contain workflow state, identifiers, URLs, dates, people, organizations, or business context, so treat `custom-metadata list` as a bounded sensitive read. Prefer `custom-metadata get` when the user already knows the key, and use `--default` only for local missing-key fallback; present values are never coerced to the default. If `list` returns `unsafe_integer_precision_loss`, treat that field's value as unavailable even when `found:true`; `get` intentionally fails closed for that same key with `invalid_argument` and `unsafe_integer_precision_loss`.

Annotation text can contain user-authored private notes or document-derived highlights, so treat `annotations get` as a sensitive read. Prefer `annotations count` when the caller only needs the annotation count. If DEVONthink's annotation accessor fails, `annotations get` reports an error instead of treating the annotation as missing.

Reminder reads can expose local script paths, script text, spoken text, email addresses, or other GUI-created alarm data in `alarm_string`, so treat `reminders get` as a sensitive read. Reminder writes support only future minute-aligned one-time default-notification add/update with empty `alarm_string` and no recurrence fields; update requires the current `reminder_sha256`, and remove requires `--confirm RECORD_UUID`. Reminder error details can include full reminder objects under `existing_reminder`, `current_reminder`, `previous_reminder`, or `observed_reminder`; treat all of those as sensitive in CLI JSON and MCP tool errors.

## Annotation Writes

```sh
~/.local/bin/devonthink annotations set RECORD_UUID --text "review note" --confirm-missing --json
~/.local/bin/devonthink annotations set RECORD_UUID --text-file ./annotation.txt --confirm-current "old note" --json
printf 'review note\n' | ~/.local/bin/devonthink annotations set RECORD_UUID --text-stdin --confirm-current-hash SHA256 --json
~/.local/bin/devonthink annotations clear RECORD_UUID --confirm-current "review note" --json
```

Use annotation writes only when the user explicitly asks to change DEVONthink.
They currently support Markdown records only and reject indexed, replicated,
locked/system/trashed, and unsupported records. Every write requires exactly
one precondition: `--confirm-current`, `--confirm-current-hash`, or
`--confirm-missing`. `--confirm-current ""` matches explicit empty text only.
When the current annotation is present, `clear` writes explicit empty text, so
follow-up writes should confirm `""` or the SHA-256 of empty text rather than
missing. `clear --confirm-missing` is an idempotent no-op when the annotation
is still missing. Text sources must be UTF-8 and are capped at 512 KiB after
leading UTF-8 BOMs in the bounded source payload are removed. Use
`--confirm-current-hash` instead of `--confirm-current` when the current
annotation is large, because exact-current guards share the JXA argument
payload budget with the replacement text. The 512 KiB limit is the raw
annotation text cap; escape-heavy HTML/XML/JSON-like text can hit the JSON/JXA
argv budget below that size and fail as `argument_too_large` instead of
`annotation_too_large`. Guard mismatches return
`precondition_failed` with redacted details such as `mode`, `actual_sha256`,
`actual_text_length`, or `actual_missing`. `--text-file` uses the local
host-file boundary. MCP set/clear tools accept inline text only and never
accept path/file/stdin fields.

On annotation set/clear `partial_update`, inspect `details.uuid`, requested
text hash/length, precondition mode/details, `cause_kind`, and
`cause_message`. Previous and observed text hashes/lengths are included only
when known, such as script-internal timeouts or post-write verification
failures. If `details.created_uuid` is present, DEVONthink created a new
annotation content record before verification failed; inspect it and trash the
orphaned annotation record if appropriate before retrying.

## Custom Metadata Writes

```sh
~/.local/bin/devonthink custom-metadata set RECORD_UUID --key review_state --type string --value ready --create-key --confirm-key review_state --if-current-json '"draft"' --json
```

Use `custom-metadata set` only when the user explicitly asks to write DEVONthink metadata. It writes one scalar `text`, `string`, `int`, `real`, or `bool` value, always requires `--create-key --confirm-key KEY` because the write may create or update a global Settings > Data definition, rejects replicated records, verifies readback, and requires exactly one lost-update mode: `--if-current-json JSON`, `--confirm-current-missing`, or `--force`. `--if-current-json` is the canonical JSON value payload, not the full `get` envelope. Stored-null keys count as present, but `if-current-json null` is not registered in this slice, so updating a stored-null value is force-only. Hash preconditions, date/url/list-like writes, clear/delete, and replicated-record writes remain deferred; do not simulate those through another command.

## Suggestions

```sh
~/.local/bin/devonthink classify RECORD_UUID --limit 5 --json
~/.local/bin/devonthink classify RECORD_UUID --tags --limit 5 --json
~/.local/bin/devonthink compare RECORD_UUID --database "Work" --limit 5 --json
~/.local/bin/devonthink see-also RECORD_UUID --limit 5 --json
```

`classify` returns suggested groups by default. Add `--tags` for tag
suggestions. `compare` and `see-also` return similar records.

## Capture

Capture commands require an explicit writable destination group UUID and create
new records only.

```sh
printf '# Notes\n' | ~/.local/bin/devonthink create-markdown \
  --title "Meeting notes" \
  --group GROUP_UUID \
  --tag meeting \
  --json

~/.local/bin/devonthink create-url "https://example.com/article" \
  --group GROUP_UUID \
  --title "Example article" \
  --json

~/.local/bin/devonthink create-formatted-note "https://example.com/article" \
  --group GROUP_UUID \
  --readability \
  --json

~/.local/bin/devonthink create-web-document "https://example.com/article" \
  --group GROUP_UUID \
  --readability \
  --json

~/.local/bin/devonthink create-feed "https://example.com/feed.xml" \
  --group GROUP_UUID \
  --json

~/.local/bin/devonthink import-file ./reference.pdf \
  --group GROUP_UUID \
  --json

~/.local/bin/devonthink index-file ./external.pdf \
  --group GROUP_UUID \
  --confirm-indexed "$(pwd)/external.pdf" \
  --json
```

Repeat `--tag` for literal tags. Use `--tags "a,b"` for comma-split tags.
Markdown stdin is capped at 512 KiB.

If capture returns `partial_update`, the record may already exist. Details may
include `created_uuid`, `group`, `title`, `phase`, redacted `url`,
`canonical_path`, `confirm_indexed`, or `cause_kind`. Inspect those details and
search/fetch before retrying.

## Annotation Summaries

```sh
~/.local/bin/devonthink annotations summarize \
  --record RECORD_UUID \
  --group GROUP_UUID \
  --format markdown \
  --json
```

`annotations summarize` is a write that creates a Markdown record in an
explicit destination group from explicit source record UUIDs. It can summarize
sources with annotation count support, such as annotated PDFs, even when
`annotations get` reports `annotation:null`. If summary creation returns
`partial_update`, inspect `details.created_uuid`, `validated_source_uuids`,
`group`, `format`, and `source_record_uuids` before retrying.

## Mutations

```sh
~/.local/bin/devonthink rename RECORD_UUID --title "New title" --json
~/.local/bin/devonthink move RECORD_UUID --group DEST_GROUP_UUID --json
~/.local/bin/devonthink tags add RECORD_UUID --tag reviewed --tags "client/acme,reference" --json
~/.local/bin/devonthink tags remove RECORD_UUID --tag reviewed --json
~/.local/bin/devonthink trash RECORD_UUID --confirm RECORD_UUID --json

~/.local/bin/devonthink groups create --name "Project Archive" --database "Work" --json
~/.local/bin/devonthink groups create --name "Invoices" --parent GROUP_UUID --json
~/.local/bin/devonthink groups rename GROUP_UUID --name "Invoices 2026" --json
~/.local/bin/devonthink groups move GROUP_UUID --parent DEST_GROUP_UUID --json
~/.local/bin/devonthink groups trash GROUP_UUID --confirm GROUP_UUID --cascade --json
```

`rename` rejects indexed records. `move` is same-database only and requires an
ordinary stored destination group. `groups trash` requires `--cascade` for
non-empty groups. For tag replacement requests, read current tags, propose an
add/remove diff, get explicit confirmation, re-read immediately before
removals, and abort if the current tags drifted.

## Smart Groups

```sh
~/.local/bin/devonthink smart-groups create \
  --name "Recent Markdown" \
  --parent GROUP_UUID \
  --predicate "kind:markdown" \
  --json

~/.local/bin/devonthink smart-groups rename SMART_GROUP_UUID --name "Renamed" --json
~/.local/bin/devonthink smart-groups move SMART_GROUP_UUID --parent DEST_GROUP_UUID --json
~/.local/bin/devonthink smart-groups trash SMART_GROUP_UUID --confirm SMART_GROUP_UUID --json
~/.local/bin/devonthink smart-groups update SMART_GROUP_UUID --predicate "kind:pdf" --json
```

Smart group predicates are DEVONthink search predicate text, not ordinary
`devonthink search` queries. `smart-groups trash` trashes the smart group
record only, not the records matched by the predicate. Predicate update verifies
round-trip metadata after writing; inspect `partial_update.details` before
retrying.

## MCP

```sh
~/.local/bin/devonthink mcp
~/.local/bin/devonthink mcp --allow-writes
```

Read-only MCP tools cover databases, groups, smart groups, search, get, read, tags, classify, compare, see-also, `devonthink_annotations_count`, `devonthink_annotations_get`, `devonthink_reminders_get`, `devonthink_custom_metadata_list`, and `devonthink_custom_metadata_get`. Treat the annotation, reminder, and custom metadata MCP read tools as bounded sensitive reads for the same reasons as the CLI commands. For unsafe integer custom metadata, `devonthink_custom_metadata_list` can report `found:true`, `value:null`, and `unsafe_integer_precision_loss`; do not assume `devonthink_custom_metadata_get` will succeed for that key. Write tools appear only with `--allow-writes`; `devonthink_reminders_add` accepts `due`, `devonthink_reminders_remove` requires `confirm`, and `devonthink_reminders_update` requires `if_current_reminder_sha256`; reminder successes wrap the CLI `RecordReminder` as `structuredContent.reminder`, so the nested reminder object is at `structuredContent.reminder.reminder`; `devonthink_annotations_summarize` requires explicit `record_uuids`, `group`, and `format:"markdown"`; `devonthink_annotations_set` accepts inline `text` only plus exactly one of `confirm_current`, `confirm_current_hash`, or `confirm_missing:true`; `devonthink_annotations_clear` accepts no replacement text and uses the same preconditions; trash tools still require `confirm`, `devonthink_index_file` still requires `confirm_indexed`, and `devonthink_custom_metadata_set` still requires `create_key:true`, matching `confirm_key`, one scalar value, and exactly one of `if_current_json`, `confirm_current_missing:true`, or `force:true`; stored-null updates are force-only in this slice.

## Errors

With `--json`, failures have:

```json
{"error":{"kind":"not_found","message":"..."}}
```

Important kinds: `invalid_argument`, `not_found`, `app_unavailable`,
`permission_denied`, `timeout`, `partial_update`, and `runtime`.
DEVONthink exits with code 5 for `partial_update`.

For deeper reference, see `docs/apps/devonthink/AGENTS.md`,
`docs/apps/devonthink/USER-GUIDE.md`, and
`docs/apps/devonthink/SAFETY-CONTRACT.md` when they are available.
