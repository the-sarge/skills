---
name: omnifocus-cli
description: Use when an agent needs to read, search, create, update, move, complete, drop, or bulk import OmniFocus tasks/projects/tags/folders using the local omnifocus CLI. Includes safety rules for live OmniFocus data, ID discovery, JSON parsing, MCP awareness, and partial-update handling.
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
- `drop`, `complete`, `move`, `update`, `set-tags`, `defer`, `due`,
  `project`, `tag`, `folder`, and `bulk import --apply` mutate live data.
- `set-tags`, `update --tag`, and `project update --tag` replace the whole tag
  set. `project set-tags --tag` replaces the whole project tag set.
- Do not invent or call an `omnifocus trash` command. The CLI and MCP server do
  not expose OmniFocus Trash; use `drop` for no-longer-relevant tasks and the
  OmniFocus GUI when the user explicitly wants Trash.
- `move` appends by default and is not a no-op when an item is already in the
  destination. Use `--before`, `--after`, or `--first` when order matters.
- `bulk import` previews by default. Use `--apply` only after the write is
  intended.
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
~/.local/bin/omnifocus tasks --status overdue --json
~/.local/bin/omnifocus search "query text" --limit 10 --json
~/.local/bin/omnifocus get TASK_ID --json
~/.local/bin/omnifocus tags --limit 50 --json
~/.local/bin/omnifocus folders --json
~/.local/bin/omnifocus perspectives --json
~/.local/bin/omnifocus perspective items builtin:inbox --limit 20 --json
```

`forecast` is upcoming-only and excludes overdue tasks:

```sh
~/.local/bin/omnifocus forecast --days 7 --limit 20 --json
~/.local/bin/omnifocus tasks --status overdue --json
```

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

~/.local/bin/omnifocus move TASK_ID --project PROJECT_ID --first --json
~/.local/bin/omnifocus move TASK_ID --before SIBLING_TASK_ID --json
~/.local/bin/omnifocus complete TASK_ID --json
~/.local/bin/omnifocus drop TASK_ID --json
~/.local/bin/omnifocus drop TASK_ID --all-occurrences --json
```

Date inputs accept RFC3339, `YYYY-MM-DD`, `today`, `tomorrow`, weekday names,
`next <weekday>`, `+Nd`, `+Nw`, simple time suffixes, and `null` where a
command clears dates.

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

Project helper commands are CLI-only conveniences over `project update`; MCP
callers should use `omnifocus_update_project` instead.

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
