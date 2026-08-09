---
name: omnifocus-cli
description: Use when an agent needs to read, inspect hierarchy, inspect front-window state or selection, inspect repeat rules, inspect notifications, edit guarded task or project notifications, inspect attachments or file links, inspect or edit guarded project lifecycle/review metadata, preview caller-supplied organization plans, search, create, update, move, complete, drop, bulk import, native TaskPaper-import, or native TaskPaper-export OmniFocus tasks/projects/tags/folders using the local omnifocus CLI. Includes safety rules for live OmniFocus data, ID discovery, JSON parsing, MCP awareness, sensitive current-context reads, host-file export recovery, database import recovery, and partial-update handling.
---

# OmniFocus CLI

Use the local `omnifocus` binary to inspect or modify the user's live
OmniFocus database. Prefer `~/.local/bin/omnifocus`; fall back to
`omnifocus` on `PATH` if needed.

## Safety Rules

- Use `--json` for every command whose output you parse.
- Read before writing. Discover IDs with `projects`, `tasks`, `search`,
  `tags`, `folders`, or `perspectives`; never guess IDs from names.
- Write only when the user explicitly asks to change OmniFocus.
- `drop`, `complete`, `move`, `update`, `set-tags`, `defer`, `due`, `estimate`, `set-group-type`, `set-completed-by-children`, `timezone`, `planned`, guarded `notification add/remove/clear task`, guarded `notification add/remove/clear project`, guarded project lifecycle/review writes, `project`, `tag`, `folder`, `bulk import --apply`, and `taskpaper import --apply --token TOKEN` mutate live data.
- `set-tags`, `update --tag`, and `project update --tag` replace the whole tag
  set. `project set-tags --tag` replaces the whole project tag set.
- Project metadata date updates snapshot and restore project repeat rules; task date helpers do not yet have a fixture-proven repeat-rule preservation contract.
- Do not invent or call an `omnifocus trash` command. The CLI and MCP server do
  not expose OmniFocus Trash; use `drop` for no-longer-relevant tasks and the
  OmniFocus GUI when the user explicitly wants Trash.
- `move` appends by default and is not a no-op when an item is already in the
  destination. Use `--before`, `--after`, or `--first` when order matters.
- `bulk import` previews by default. Use `--apply` only after the write is
  intended.
- `taskpaper import` previews by default and is CLI-only, inbox-only, and non-idempotent. Use `--apply --token PREVIEW_TOKEN` only with a token from a preview of the same normalized input text and inbox destination. Do not invent `--project`, `--parent`, MCP native import, native preview parity, title/count cleanup, or rollback cleanup.
- `taskpaper export task TASK_ID --output FILE` writes one validated host file outside OmniFocus through `internal/pathsafety`. It defaults to no-overwrite, forces mode `0600`, rejects sensitive paths plus any dotfile or dot-directory component anywhere in the resolved canonical path, anchors `~`, `$HOME`, and home-sensitive roots to the resolved process home, rejects symlink/package/device destinations observed before replacement, enforces MCP allowed roots canonically, writes relative to the validated parent directory handle, and can return `export_recovery`; if the platform no-replace filesystem primitive is unsupported, creating a new export file fails with `runtime` even with `--overwrite`, while replacing an existing regular file through `--overwrite` remains the only replacement path. A same-user race that swaps the final component after overwrite validation is a documented residual: overwrite replaces the path node without following symlink targets. Process-observable failures after the destination has been renamed into place do not attempt automatic unlink rollback; they report irreversible `partial_update` with manual recovery guidance. Use `--overwrite` only when replacing an existing regular file is intended.
- `organize preview` is read-only and has no `--apply` flag. Use it only for caller-supplied deterministic ID-based plans with complete `current_order` and `requested_order`; do not infer, generate, recommend, auto-sort, auto-reorder, or apply organization decisions.
- `repeat get` is read-only. Do not invent `repeat set` or `repeat clear`; repeat-rule writes are not exposed by the CLI or MCP server in this slice.
- Task and project notification writes are guarded. CLI writes use only `notification add task`, `notification remove task --index N --expected-file FILE`, `notification clear task --all --expected-file FILE`, `notification add project`, `notification remove project --index N --expected-file FILE`, and `notification clear project --all --expected-file FILE`; MCP writes use `omnifocus_add_notification`, `omnifocus_remove_notification`, and `omnifocus_clear_notifications` only when the MCP server was launched with `--allow-writes`, and redact write success and `notification_recovery` timing by default unless `include_sensitive: true` is supplied. The shipped dynamic-state expansion is limited to owner-mode preflight plus rollback/restorability for task absolute, task due-relative, and project due-relative positive repeat intervals; do not invent kind-filtered clear, fingerprint-only guards, direct repeat/floating editors, project absolute repeat-interval and fixed/current time-zone restoration, repeating-owner writes, snooze/unsnooze, defer-relative writes, unknown-kind writes, direct `Project` mutation, or unguarded notification writes.
- `attachments add`, `file-links add`, and guarded `file-links remove` are available for task/project owners; `attachments remove` remains deferred and must not be invented. CLI output can reveal sensitive local filenames and file URLs, while MCP redacts those values unless `include_sensitive: true` is explicitly requested.
- Project lifecycle/review writes are guarded and project-only. CLI writes are `project status`, `project complete`, `project incomplete`, `project set-type --single-actions`, `project set-default-singleton`, `project review-interval`, and `project review-date`; MCP writes are `omnifocus_project_status`, `omnifocus_project_complete`, `omnifocus_project_incomplete`, `omnifocus_set_project_single_action`, `omnifocus_set_project_default_singleton`, `omnifocus_set_project_review_interval`, and `omnifocus_set_project_review_date` only when the MCP server was launched with `--allow-writes`. Status accepts only `active`, `on_hold`, `done`, and `dropped`, plus `on-hold` as an input alias. Use `project complete` for non-done to done transitions. Terminal lifecycle writes require `--expected-status` and `--expected-completed`; default-singleton writes require `--expected-default-project-id PROJECT_ID|null`; review-date writes require `--expected-last DATE|null` and `--expected-next DATE|null`. Do not invent review clears, mark-reviewed, repeating-project terminal writes, incomplete-child acknowledgements, bulk lifecycle/review edits, folder status writes, or selection-based lifecycle/review writes.
- `window state`, `selection get`, and `window visible-items` are read-only front-window inspections. They require an available document window, never change perspective, focus, selection, panes, windows, tabs, forecast day, or database data, and can reveal sensitive current context. Do not invent `selection set`, `window focus`, `window perspective`, `forecast select`, `window new`, `window tab`, or `window panels` commands or MCP tools.
- If a command returns `partial_update`, stop and fetch the affected task or
  project before retrying.
- If Automation permission fails, tell the user to grant access in
  System Settings -> Privacy & Security -> Automation.

## Quick Checks

```sh
~/.local/bin/omnifocus doctor --json
~/.local/bin/omnifocus version --json
```

## Common Reads

```sh
~/.local/bin/omnifocus inbox --limit 20 --json
~/.local/bin/omnifocus projects --limit 50 --json
~/.local/bin/omnifocus tasks --project PROJECT_ID --json
~/.local/bin/omnifocus tasks --parent PROJECT_ID --json
~/.local/bin/omnifocus tasks --parent TASK_ID --json
~/.local/bin/omnifocus tree --project PROJECT_ID --json
~/.local/bin/omnifocus tree --task TASK_ID --json
~/.local/bin/omnifocus tasks --status overdue --json
~/.local/bin/omnifocus tasks --estimate-le 20 --has-repeat --json
~/.local/bin/omnifocus tasks --planned tomorrow --json
~/.local/bin/omnifocus search "query text" --limit 10 --json
~/.local/bin/omnifocus get TASK_ID --json
~/.local/bin/omnifocus metadata TASK_ID --json
~/.local/bin/omnifocus repeat get task TASK_ID --json
~/.local/bin/omnifocus repeat get project PROJECT_ID --json
~/.local/bin/omnifocus notification list task TASK_ID --json
~/.local/bin/omnifocus notification list project PROJECT_ID --json
~/.local/bin/omnifocus attachments list task TASK_ID --json
~/.local/bin/omnifocus attachments list project PROJECT_ID --json
~/.local/bin/omnifocus file-links list task TASK_ID --json
~/.local/bin/omnifocus file-links list project PROJECT_ID --json
~/.local/bin/omnifocus project lifecycle PROJECT_ID --json
~/.local/bin/omnifocus project review PROJECT_ID --json
~/.local/bin/omnifocus tags --limit 50 --json
~/.local/bin/omnifocus folders --json
~/.local/bin/omnifocus perspectives --json
~/.local/bin/omnifocus perspective items builtin:inbox --limit 20 --json
~/.local/bin/omnifocus window state --json
~/.local/bin/omnifocus selection get --json
~/.local/bin/omnifocus window visible-items --limit 20 --json
~/.local/bin/omnifocus organize preview --plan-file PLAN.json --json
~/.local/bin/omnifocus taskpaper export task TASK_ID --json
~/.local/bin/omnifocus taskpaper export task TASK_ID --output ~/Exports/acme.taskpaper --json
~/.local/bin/omnifocus taskpaper import --json < plan.taskpaper
```

`forecast` is upcoming-only and excludes overdue tasks:

```sh
~/.local/bin/omnifocus forecast --days 7 --limit 20 --json
~/.local/bin/omnifocus tasks --status overdue --json
```

Use `tasks --parent` for direct children only: project IDs return top-level project tasks, and task/action-group IDs return direct child tasks. Use `tree` when recursive nesting matters; `tree --task` returns the selected task as the root descriptor. `tree` returns the full stored subtree, including completed and dropped tasks, and is intentionally unbounded. MCP `omnifocus_tasks` accepts `parent_id` for direct children, but recursive tree output is available only from the CLI in this release.

Use `metadata TASK_ID` when you need expanded task metadata without changing the default `get TASK_ID` shape. If OmniFocus does not expose planned dates, metadata reads return `planned_dates_available: false` with null planned fields and still never treat defer dates as planned dates. `tasks` metadata filters include `--estimate-le`, `--estimate-gt`, `--planned`, `--has-repeat`, `--has-notifications`, and `--has-attachments`. Planned-date filters require OmniFocus planned-date support and must not be treated as defer-date reads.

Use `repeat get task TASK_ID --json` or `repeat get project PROJECT_ID --json` for full repeat-rule inspection. The JSON shape is `owner_kind`, `owner_id`, `extended_rule_fields_available`, and `rule`; `rule` is null when the owner does not repeat.

Use `notification list task TASK_ID --json` or `notification list project PROJECT_ID --json` for notification inspection. CLI JSON returns full local timing fields and a `sha256:` fingerprint; MCP `omnifocus_notifications` redacts exact timing fields by default and requires `include_sensitive: true` for full timing. MCP notification write tools are `omnifocus_add_notification`, `omnifocus_remove_notification`, and `omnifocus_clear_notifications`, and they are registered only when MCP writes are enabled with `--allow-writes`.

Use task or project notification writes only when the user explicitly asks to change reminders:

```sh
~/.local/bin/omnifocus notification add task TASK_ID --absolute 2026-06-10T09:00:00-04:00 --json
~/.local/bin/omnifocus notification add task TASK_ID --due-offset=-30m --json
~/.local/bin/omnifocus notification remove task TASK_ID --index 0 --expected-file notification.json --json
~/.local/bin/omnifocus notification clear task TASK_ID --all --expected-file notifications.json --json
~/.local/bin/omnifocus notification add project PROJECT_ID --absolute 2026-06-10T09:00:00-04:00 --json
~/.local/bin/omnifocus notification add project PROJECT_ID --due-offset=-30m --json
~/.local/bin/omnifocus notification remove project PROJECT_ID --index 0 --expected-file notification.json --json
~/.local/bin/omnifocus notification clear project PROJECT_ID --all --expected-file notifications.json --json
```

For CLI remove, the expected file must be exactly one stable guard object with `kind`, `absolute_fire_date`, `initial_fire_date`, `relative_fire_offset_seconds`, `repeat_interval_seconds`, and `uses_floating_time_zone`. For CLI clear-all, the expected file must contain `expected_count` and the complete `notifications` list of those guard objects. For MCP remove/clear, pass either that stable guard shape or a full unredacted notification item from `omnifocus_notifications` with `include_sensitive: true`; embedded fingerprints are ignored and embedded indexes must match. Do not use redacted MCP output, fingerprints, or index-only writes as guards. Due-relative guards include `initial_fire_date`, so regenerate guards from a fresh read after any task or project due-date change. Absolute notification remove/clear also preflights the owner time-zone mode; a zero-repeat absolute notification can intentionally reject after the owner mode changed because the write path fails closed before mutation. MCP write success and `notification_recovery` are redacted by default; pass `include_sensitive: true` only when the user explicitly wants exact local reminder timing in the write result. If JSON errors include `notification_recovery`, inspect `rollback_succeeded`; `partial_update` means read the affected owner notifications before retrying.

For `kind:"absolute"`, `absolute_fire_date` and `initial_fire_date` must both be non-empty strings and `relative_fire_offset_seconds` must be null. For `kind:"due_relative"`, `initial_fire_date` must be a non-empty string, `relative_fire_offset_seconds` must be an integer, and `absolute_fire_date` must be null. Every stable guard requires a nonnegative integer `repeat_interval_seconds` and a boolean `uses_floating_time_zone`. A full unredacted MCP notification item is a write guard only when those stable fields are populated; redacted output, null `repeat_interval_seconds`, and null `uses_floating_time_zone` are intentionally insufficient.

Use `attachments list task TASK_ID --json`, `attachments list project PROJECT_ID --json`, `file-links list task TASK_ID --json`, or `file-links list project PROJECT_ID --json` for attachment metadata and linked-file URL inspection. CLI JSON returns local attachment names and file URLs, which can expose sensitive filenames and absolute paths that may have synced through OmniFocus; MCP `omnifocus_attachments` and `omnifocus_file_links` redact those values by default and require `include_sensitive: true` for full local output.

Use `attachments add task|project OWNER_ID --path ABSOLUTE_FILE --acknowledge-sync-disclosure --json` to embed a source file. The command rejects relative paths, home shorthand, symlinks, directories, packages, devices, sensitive paths, missing files, and files over 25 MiB before mutation, then copies the validated bytes through a private app-readable handoff because OmniFocus cannot read arbitrary host paths directly.

If attachment add crashes after creating its handoff, stale `ai-cli-attachment-handoff-*` directories can remain in OmniFocus's documents directory and may contain copied source bytes. Treat them as sensitive crash residue and remove only stale directories with that exact prefix after confirming no attachment add is running.

Use `file-links add task|project OWNER_ID --path ABSOLUTE_FILE --acknowledge-sync-disclosure --json` to add a linked file URL. Use `file-links remove task|project OWNER_ID --url CANONICAL_FILE_URL --expected-file file-links.json --json` only after generating `file-links.json` from a fresh unredacted CLI read, for example `omnifocus file-links list task TASK_ID --json | jq '{expected_count: (.linked_file_urls | length), linked_file_urls: .linked_file_urls}' > file-links.json`. Do not use redacted MCP output as a remove guard.

Use `project lifecycle PROJECT_ID --json` for observed project status, completion/drop dates, effective terminal dates, single-action/default-singleton observations, and next task. Use `project review PROJECT_ID --json` for last/next review dates and review interval. Both commands reject normal task IDs and project root task IDs.

Use guarded project lifecycle/review writes only when the user explicitly asks to change the project:

```sh
~/.local/bin/omnifocus project status PROJECT_ID on_hold --expected-status active --expected-completed=false --json
~/.local/bin/omnifocus project complete PROJECT_ID --expected-status active --expected-completed=false --json
~/.local/bin/omnifocus project incomplete PROJECT_ID --expected-status done --expected-completed=true --json
~/.local/bin/omnifocus project set-type PROJECT_ID --single-actions --json
~/.local/bin/omnifocus project set-default-singleton PROJECT_ID true --expected-default-project-id null --json
~/.local/bin/omnifocus project review-interval PROJECT_ID --steps 2 --unit weeks --json
~/.local/bin/omnifocus project review-date PROJECT_ID --last 2026-06-09 --expected-last null --expected-next 2026-06-16 --json
```

Repeating projects and projects with incomplete child tasks are refused before completion/drop writes. `project set-default-singleton true` requires an already-single-action project, and `false` refuses to clear the only verified holder. Review interval writes require an existing interval. Review date writes accept exactly one of `--last` or `--next`, and null clears are not supported. If JSON errors include `lifecycle_recovery` or `review_recovery`, inspect `rollback_succeeded`, `observed`, and `manual_recovery`; `partial_update` means read the affected project before retrying.

Use `window state --json`, `selection get --json`, and `window visible-items --limit 20 --json` only when the user wants the current visible OmniFocus context. These reads are sensitive because they expose what the user is looking at or has selected. MCP equivalents are `omnifocus_window_state`, `omnifocus_selection`, and `omnifocus_visible_items`; no UI-mutating MCP tools are registered.

Use `organize preview --plan-file PLAN.json --json` to validate a caller-authored organization plan without changing OmniFocus. Slice 1 supports ID-backed containers only: tasks under a project or task, tags under a parent tag, folders under a parent folder, and projects under a folder. Top-level/inbox ordering, tag behavior writes, `childrenAreMutuallyExclusive` writes, multi-object moves, duplication helpers, MCP parity, and apply/write paths are not exposed.

Use `taskpaper export task TASK_ID --json` when the caller needs native OmniFocus TaskPaper transport text for one normal task subtree. Add `--output FILE` to write one host file; relative paths, `~`, and `$HOME` are resolved to a canonical absolute `output_path` anchored to the resolved process home. The parent must exist, `.taskpaper` is recommended but not required, and the command rejects any dotfile or dot-directory component anywhere in the resolved canonical path, final symlinks observed before replacement, non-regular destinations, package ancestry such as `.app`, and sensitive roots such as `~/Library`, `/etc`, `/private/etc`, `/private/var/db`, `/dev`, `/System`, `/bin`, `/sbin`, and `/usr`. The shared `internal/pathsafety` writer opens the validated parent directory and performs temp creation, cleanup, readback, rename, permission publish, file sync, and parent sync relative to that directory handle. Default no-overwrite uses platform no-replace support; if the destination filesystem does not support no-replace, creating a new export file fails with `runtime` instead of weakening the no-clobber guarantee, even with `--overwrite`; `--overwrite` only avoids no-replace when replacing an existing regular destination. A same-user race that swaps the final component after overwrite validation is a documented residual: overwrite replaces the path node without following symlink targets. `--overwrite` is irreversible and has no backup. If JSON errors include `export_recovery`, inspect `rollback_attempted`, `irreversible`, and `manual_recovery` first; post-rename `partial_update` means no automatic unlink rollback was attempted and `rollback_succeeded` remains false. Crash residue named `omnifocus-taskpaper-export-*.tmp` may contain exported task text.

Use `taskpaper import --json < plan.taskpaper` or `taskpaper import --file plan.taskpaper --json` when the caller explicitly wants to import native OmniFocus TaskPaper transport text. Preview returns `apply_token`; apply with `taskpaper import --apply --token PREVIEW_TOKEN --json < plan.taskpaper` only after the user intends the write. The command imports to the inbox only, rejects empty/over-1 MiB input and `@tag(`, `@tags(`, `@project(`, `@folder(`, malformed case/spacing variants, and top-level `Name:` project-like syntax before mutation, and applies through a private pasteboard. Success returns `created_task_ids` and typed `tasks`; failure after mutation can return `database_recovery`. If timeout recovery says `created_task_ids_available:false` or `residual_created_count_available:false`, do not retry blindly and do not clean up by title, prefix, or count.

## Common Writes

```sh
~/.local/bin/omnifocus add "Task title" --json
~/.local/bin/omnifocus add "Task title" --project PROJECT_ID --tag TAG_ID --due tomorrow --json
~/.local/bin/omnifocus add "Child task" --parent TASK_ID --json

~/.local/bin/omnifocus update TASK_ID --title "New title" --json
~/.local/bin/omnifocus update TASK_ID --note "" --json
~/.local/bin/omnifocus update TASK_ID --due null --defer "next monday" --json
~/.local/bin/omnifocus set-tags TASK_ID --tag TAG_ID --tag OTHER_TAG_ID --json
~/.local/bin/omnifocus set-tags TASK_ID --clear --json
~/.local/bin/omnifocus defer TASK_ID tomorrow --json
~/.local/bin/omnifocus due TASK_ID null --json
~/.local/bin/omnifocus estimate TASK_ID 25 --json
~/.local/bin/omnifocus estimate TASK_ID null --json
~/.local/bin/omnifocus set-group-type TASK_ID --sequential --json
~/.local/bin/omnifocus set-group-type TASK_ID --parallel --json
~/.local/bin/omnifocus set-completed-by-children TASK_ID true --json
~/.local/bin/omnifocus timezone TASK_ID --floating --json
~/.local/bin/omnifocus timezone TASK_ID --current --json
~/.local/bin/omnifocus planned TASK_ID tomorrow --json
~/.local/bin/omnifocus planned TASK_ID null --json

~/.local/bin/omnifocus move TASK_ID --project PROJECT_ID --first --json
~/.local/bin/omnifocus move TASK_ID --before SIBLING_TASK_ID --json
~/.local/bin/omnifocus complete TASK_ID --json
~/.local/bin/omnifocus drop TASK_ID --json
~/.local/bin/omnifocus drop TASK_ID --all-occurrences --json
```

Date inputs accept RFC3339, `YYYY-MM-DD`, `today`, `tomorrow`, weekday names,
`next <weekday>`, `+Nd`, `+Nw`, simple time suffixes, and `null` where a
command clears dates. `timezone` requires a due or defer date before OmniFocus allows floating time-zone edits. `planned` requires OmniFocus planned-date support and never falls back to defer dates.

## Projects, Tags, And Folders

```sh
~/.local/bin/omnifocus project add "Project name" --folder FOLDER_ID --json
~/.local/bin/omnifocus project rename PROJECT_ID "New name" --json
~/.local/bin/omnifocus project move PROJECT_ID --top-level --json
~/.local/bin/omnifocus project set-type PROJECT_ID --parallel --json
~/.local/bin/omnifocus project set-type PROJECT_ID --single-actions --json
~/.local/bin/omnifocus project status PROJECT_ID on_hold --expected-status active --expected-completed=false --json
~/.local/bin/omnifocus project complete PROJECT_ID --expected-status active --expected-completed=false --json
~/.local/bin/omnifocus project incomplete PROJECT_ID --expected-status done --expected-completed=true --json
~/.local/bin/omnifocus project set-default-singleton PROJECT_ID true --expected-default-project-id null --json
~/.local/bin/omnifocus project review-interval PROJECT_ID --steps 2 --unit weeks --json
~/.local/bin/omnifocus project review-date PROJECT_ID --last 2026-06-09 --expected-last null --expected-next 2026-06-16 --json
~/.local/bin/omnifocus project update PROJECT_ID --defer tomorrow --due +2w --flagged --json
~/.local/bin/omnifocus project defer PROJECT_ID tomorrow --json
~/.local/bin/omnifocus project due PROJECT_ID null --json
~/.local/bin/omnifocus project set-tags PROJECT_ID --tag TAG_ID --tag OTHER_TAG_ID --json
~/.local/bin/omnifocus project set-tags PROJECT_ID --clear --json
~/.local/bin/omnifocus project flag PROJECT_ID --json
~/.local/bin/omnifocus project unflag PROJECT_ID --json
~/.local/bin/omnifocus project lifecycle PROJECT_ID --json
~/.local/bin/omnifocus project review PROJECT_ID --json

~/.local/bin/omnifocus tag add "Tag name" --json
~/.local/bin/omnifocus tag rename TAG_ID "New tag name" --json
~/.local/bin/omnifocus tag move TAG_ID --parent PARENT_TAG_ID --json
~/.local/bin/omnifocus tag drop TAG_ID --json
~/.local/bin/omnifocus tag activate TAG_ID --json

~/.local/bin/omnifocus folder add "Folder name" --json
~/.local/bin/omnifocus folder rename FOLDER_ID "New folder name" --json
~/.local/bin/omnifocus folder move FOLDER_ID --top-level --json
~/.local/bin/omnifocus folder drop FOLDER_ID --json
~/.local/bin/omnifocus folder activate FOLDER_ID --json
```

`project add` is parallel by default. Pass `--sequential` only when sequential
project behavior is wanted.

Project helper commands are local CLI conveniences over `project update`; MCP
callers should use `omnifocus_update_project` instead.

Project lifecycle/review reads have MCP equivalents `omnifocus_project_lifecycle` and `omnifocus_project_review`, each requiring `project_id`. With MCP writes enabled, lifecycle/review writes have MCP equivalents `omnifocus_project_status`, `omnifocus_project_complete`, `omnifocus_project_incomplete`, `omnifocus_set_project_single_action`, `omnifocus_set_project_default_singleton`, `omnifocus_set_project_review_interval`, and `omnifocus_set_project_review_date`; they are absent in read-only MCP mode.

Attachment/file-link reads have MCP equivalents `omnifocus_attachments` and `omnifocus_file_links`, each requiring `owner_kind` and `owner_id` and accepting `include_sensitive` defaulting to false. With MCP writes enabled, `omnifocus_remove_file_link` is registered under `--allow-writes`; `omnifocus_add_attachment` and `omnifocus_add_file_link` require `--allow-writes --allow-file-root PATH`, `confirm_path`, and `acknowledge_sync_disclosure:true`. MCP write success and `attachments_recovery` redact local names and URLs by default unless `include_sensitive: true` is supplied. `omnifocus_remove_attachment` and the noun-first attachment/file-link write names are not registered.

TaskPaper file export has MCP equivalent `omnifocus_taskpaper_export_task` only when the server is launched with `--allow-writes --allow-file-root PATH`. It requires `owner_kind: "task"`, `owner_id`, `output_path`, and `confirmed_output_path` matching the resolved canonical destination, rejects paths outside configured canonical roots before export, omits raw `text` by default, and echoes text only with `include_text: true`.

Native TaskPaper import has no MCP equivalent in this slice. `omnifocus_taskpaper_import`, `omnifocus_import_taskpaper`, `omnifocus_import`, and `omnifocus_database_import` remain absent in read-only and `--allow-writes` MCP modes.

## Bulk Import

Preview first:

```sh
~/.local/bin/omnifocus bulk import --project PROJECT_ID --json < tasks.taskpaper
```

Apply when intended:

```sh
~/.local/bin/omnifocus bulk import --project PROJECT_ID --apply --json < tasks.taskpaper
```

Supported input is a strict TaskPaper-like subset:

```text
- Parent task @due(tomorrow)
  note: Optional note text.
  - Child task @tag(TAG_ID) @flagged
```

Use two spaces or one tab for hierarchy. Metadata supports `@tag(ID)`,
`@due(DATE)`, `@defer(DATE)`, and `@flagged`.

## Errors

With `--json`, failures have:

```json
{"error":{"kind":"not_found","message":"..."}}
```

Important kinds: `not_found`, `invalid_argument`, `app_unavailable`,
`permission_denied`, `partial_update`, `timeout`, and `runtime`.

For deeper reference, see `docs/apps/omnifocus/AGENTS.md` and
`docs/apps/omnifocus/USER-GUIDE.md` when they are available.
