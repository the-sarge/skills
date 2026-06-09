---
name: omnifocus-cli
description: Use when an agent needs to read, inspect hierarchy, inspect front-window state or selection, inspect repeat rules, inspect notifications, edit guarded task or project notifications, inspect attachments or file links, inspect project lifecycle/review metadata, preview caller-supplied organization plans, search, create, update, move, complete, drop, or bulk import OmniFocus tasks/projects/tags/folders using the local omnifocus CLI. Includes safety rules for live OmniFocus data, ID discovery, JSON parsing, MCP awareness, sensitive current-context reads, and partial-update handling.
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
- `drop`, `complete`, `move`, `update`, `set-tags`, `defer`, `due`, `estimate`, `set-group-type`, `set-completed-by-children`, `timezone`, `planned`, guarded `notification add/remove/clear task`, guarded `notification add/remove/clear project`, `project`, `tag`, `folder`, and `bulk import --apply` mutate live data.
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
- `organize preview` is read-only and has no `--apply` flag. Use it only for caller-supplied deterministic ID-based plans with complete `current_order` and `requested_order`; do not infer, generate, recommend, auto-sort, auto-reorder, or apply organization decisions.
- `repeat get` is read-only. Do not invent `repeat set` or `repeat clear`; repeat-rule writes are not exposed by the CLI or MCP server in this slice.
- Task and project notification writes are guarded. CLI writes use only `notification add task`, `notification remove task --index N --expected-file FILE`, `notification clear task --all --expected-file FILE`, `notification add project`, `notification remove project --index N --expected-file FILE`, and `notification clear project --all --expected-file FILE`; MCP writes use `omnifocus_add_notification`, `omnifocus_remove_notification`, and `omnifocus_clear_notifications` only when the MCP server was launched with `--allow-writes`, and redact write success and `notification_recovery` timing by default unless `include_sensitive: true` is supplied. The shipped dynamic-state expansion is limited to owner-mode preflight plus rollback/restorability for task absolute, task due-relative, and project due-relative positive repeat intervals; do not invent kind-filtered clear, fingerprint-only guards, direct repeat/floating editors, project absolute repeat-interval and fixed/current time-zone restoration, repeating-owner writes, snooze/unsnooze, defer-relative writes, unknown-kind writes, direct `Project` mutation, or unguarded notification writes.
- `attachments list` and `file-links list` are read-only. Do not invent attachment or file-link add/remove commands or MCP tools; CLI output can reveal sensitive local filenames and file URLs, while MCP redacts those values unless `include_sensitive: true` is explicitly requested.
- `project lifecycle` and `project review` are read-only. Do not invent project status, completion/incompletion, single-action/default-singleton, review interval, or review date write commands or MCP tools; these writes are not exposed in this slice, even with MCP `--allow-writes`.
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

Use `attachments list task TASK_ID --json`, `attachments list project PROJECT_ID --json`, `file-links list task TASK_ID --json`, or `file-links list project PROJECT_ID --json` for attachment metadata and linked-file URL inspection. CLI JSON returns local attachment names and file URLs, which can expose sensitive filenames and absolute paths that may have synced through OmniFocus; MCP `omnifocus_attachments` and `omnifocus_file_links` redact those values by default and require `include_sensitive: true` for full local output.

Use `project lifecycle PROJECT_ID --json` for observed project status, completion/drop dates, effective terminal dates, single-action/default-singleton observations, and next task. Use `project review PROJECT_ID --json` for last/next review dates and review interval. Both commands reject normal task IDs and project root task IDs.

Use `window state --json`, `selection get --json`, and `window visible-items --limit 20 --json` only when the user wants the current visible OmniFocus context. These reads are sensitive because they expose what the user is looking at or has selected. MCP equivalents are `omnifocus_window_state`, `omnifocus_selection`, and `omnifocus_visible_items`; no UI-mutating MCP tools are registered.

Use `organize preview --plan-file PLAN.json --json` to validate a caller-authored organization plan without changing OmniFocus. Slice 1 supports ID-backed containers only: tasks under a project or task, tags under a parent tag, folders under a parent folder, and projects under a folder. Top-level/inbox ordering, tag behavior writes, `childrenAreMutuallyExclusive` writes, multi-object moves, duplication helpers, MCP parity, and apply/write paths are not exposed.

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

Project lifecycle/review reads have MCP equivalents `omnifocus_project_lifecycle` and `omnifocus_project_review`, each requiring `project_id`. No lifecycle/review write tool is registered by MCP, including when started with `--allow-writes`.

Attachment/file-link reads have MCP equivalents `omnifocus_attachments` and `omnifocus_file_links`, each requiring `owner_kind` and `owner_id` and accepting `include_sensitive` defaulting to false. No attachment or file-link write tool is registered by MCP, including when started with `--allow-writes`.

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
