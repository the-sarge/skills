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
  `index-file`, `rename`, `move`, `tags add`, `tags remove`, `trash`,
  `groups create|rename|move|trash`, and
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
```

Use `--database NAME_OR_UUID` or `--group GROUP_UUID` to keep searches focused.
`groups` lists ordinary groups; use `smart-groups` for smart group discovery
and lifecycle commands.

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

Read-only MCP tools cover databases, groups, smart groups, search, get, read,
tags, classify, compare, and see-also. Write tools appear only with
`--allow-writes`; trash tools still require `confirm`, and
`devonthink_index_file` still requires `confirm_indexed`.

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
