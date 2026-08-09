---
name: omnioutliner-cli
description: Use when an agent needs to inspect, search, export, mutate, import, or use MCP with OmniOutliner outlines through the local omnioutliner CLI. Includes safety rules for live OmniOutliner data, JSON parsing, document and row ID discovery, explicit writes, local-file inputs, MCP --allow-writes, partial-update handling, and deferred unsupported operations.
---

# OmniOutliner CLI

Use the local `omnioutliner` binary to inspect or modify open OmniOutliner
documents. Prefer `~/.local/bin/omnioutliner`; fall back to `omnioutliner` on
`PATH` if needed.

## Safety Rules

- Use `--json` for every structured command whose output you parse.
- OmniOutliner must be installed and allowed through macOS Automation. Run
  `doctor --json` before diagnosing app, permission, or scripting issues.
- Read before writing. Discover open documents with `documents --json` and row
  IDs with `outline`, `rows`, `get`, or `search`; never guess row IDs from
  names.
- Omitted `--document` targets the frontmost document. Prefer explicit
  `--document` for writes or when multiple outlines may be open.
- Write only when the user explicitly asks to change OmniOutliner.
- `add`, `update`, `move`, `indent`, `import`, `duplicate`, `transform
  group|ungroup|organize`, and `delete` mutate live open documents. `delete` and
  `organize --prune-empty` remove rows and are destructive (see Transforms And
  Delete).
- `export` writes raw Markdown, OPML, or native-format bytes and rejects
  `--json`. `export native --format FORMAT_ID` uses IDs from `formats --json`.
- Markdown export is lossy. Use OPML for native interchange; Markdown import and
  native import by `FORMAT_ID` are not implemented (`import` is OPML-only).
- Local file inputs include CLI `--note` and CLI `import --from`; MCP `note_path`, OPML import `path`, lifecycle `file` selectors, document-open paths, and save-as destinations require `--allow-file-root` and must stay under configured roots. Local note and OPML reads are capped at 512 KiB and read with the CLI or MCP server process filesystem access.
- `update --note` can use an empty file to clear a row note.
- If a command returns `partial_update`, stop and inspect affected rows before
  retrying. A failed `group` title/move names the created group row; an
  `organize` that fails partway names the created groups, confirmed-moved rows,
  pruned rows, and the destination; a `delete` whose verification finds rows
  still present names confirmed-deleted and observed-remaining IDs.
- Start MCP read-only by default. Use `mcp --allow-writes` only for trusted local clients because write tools can modify open outlines; add repeatable `--allow-file-root DIR` only for the narrow host-file directories the client needs. Allowed roots reject `~/Library`, including iCloud Drive's `~/Library/Mobile Documents/...`; use a non-Library working directory for MCP file access.
- `document open|save|save-as|close` and `windows` are live document-lifecycle
  operations. `save`/`close --save` refuse untitled documents (use `save-as`),
  `close` needs exactly one of `--save`/`--discard`, and `save-as --to` writes a
  native `.ooutline`/`.oo3` file and rejects an existing destination (best-effort
  preflight, not an atomic overwrite guard).
- Single-row subtree `delete` and `duplicate`/`transform group|ungroup|organize`
  are supported (see Transforms And Delete). Do not invent multi-row delete,
  reparent-on-delete, archive, or trash; multi-column `organize` (organize keys
  off one `--by-column` column, resolved by stable ID or unique title);
  blank/template document
  creation, template listing; Markdown import, native import by `FORMAT_ID`;
  rich-text replacement, named-style application, or attachment add/import
  (`rich-text`, `styles list`, and `attachments list` reads are supported, but
  their write counterparts are deferred); style editing; column schema mutation
  (add/update/reorder/delete columns); or document-note commands. Typed cell
  writes to existing
  number/date/duration/enumeration columns are supported (see Writes); changing
  the schema itself is not.
- If Automation permission fails, tell the user to grant access in System
  Settings -> Privacy & Security -> Automation.

## Quick Checks

```sh
~/.local/bin/omnioutliner version --json
~/.local/bin/omnioutliner doctor --json
```

## Common Reads

```sh
~/.local/bin/omnioutliner documents --json
~/.local/bin/omnioutliner columns --document "Project Plan" --json
~/.local/bin/omnioutliner outline --document "Project Plan" --json
~/.local/bin/omnioutliner rows --document "Project Plan" --depth 0 --json
~/.local/bin/omnioutliner rows --document "Project Plan" --parent PARENT_ROW_ID --json
~/.local/bin/omnioutliner get ROW_ID --document "Project Plan" --json
~/.local/bin/omnioutliner search "milestone" --document "Project Plan" --json
~/.local/bin/omnioutliner search "blocked" --document "Project Plan" --status unchecked --json
~/.local/bin/omnioutliner rows --document "Project Plan" --column Owner=Josh --json
~/.local/bin/omnioutliner columns --document "Project Plan" --verbose --json
~/.local/bin/omnioutliner column get COLUMN_ID --document "Project Plan" --json
~/.local/bin/omnioutliner column values COLUMN_ID --document "Project Plan" --json
```

`columns --verbose` exposes each column's stable `id`. `column get COLUMN_ID`
returns the verbose column plus its enumeration members and
`supported_write_types`; `column values COLUMN_ID` returns populated per-row
`{row_id, column_id, type, raw_value, display_value}` cells in outline order.

Depth is absolute and 0-indexed. `--parent` returns a subtree. To get direct
children only, read the parent's depth first, then combine `--parent PARENT_ID`
with `--depth PARENT_DEPTH_PLUS_1`.

Status filters are `checked`, `unchecked`, `mixed`, and `none`. Column filters
match existing non-built-in column titles exactly and case-sensitively. Use
`--status` for the built-in checkbox status column.

## Exports

```sh
~/.local/bin/omnioutliner export markdown --document "Project Plan" -o review.md
~/.local/bin/omnioutliner export opml --document "Project Plan" -o native.opml
```

Use Markdown for review, search, or prose handoff. It does not preserve styles,
column schemas, folding state, attachments, or exact layout. Use OPML for
native interchange. Output files created with `-o` use owner-only `0600`
permissions.

For any other native format (CSV, OpenXML, ...), list the inventory and export
by stable `FORMAT_ID`:

```sh
~/.local/bin/omnioutliner formats --json
# CSV is textual and flat — it streams to stdout:
~/.local/bin/omnioutliner export native --document "Project Plan" --format FORMAT_ID > outline.csv
# Binary OpenXML writers (docx/xlsx/pptx) are flat but require -o:
~/.local/bin/omnioutliner export native --document "Project Plan" --format FORMAT_ID -o outline.docx
```

`export native` augments the Markdown/OPML shortcuts. Use the inventory `id`
(not the display `name`); add `--kind` when an `id` is shared across kinds. It
rejects unknown, non-writable, export-unsupported (writable plug-in/automation
bundles that cannot export an outline), and package/directory formats (including
the built-in HTML exporters) before writing,
and routes off `content_class`/`output_kind`, not file extensions: textual
formats stream to stdout, binary (and other non-textual) outputs need `-o FILE`.
Transforms run with default parameters. Native import by `FORMAT_ID` is not
enabled; `import` accepts only `--format opml`.

Review recipe:

```sh
mkdir -p .omnioutliner-exports

~/.local/bin/omnioutliner outline --document "Project Plan" --json \
  > .omnioutliner-exports/project-plan.json

~/.local/bin/omnioutliner export markdown --document "Project Plan" \
  -o .omnioutliner-exports/project-plan.md

~/.local/bin/omnioutliner export opml --document "Project Plan" \
  -o .omnioutliner-exports/project-plan.opml
```

## Rich Text, Styles, and Attachments (read-only)

```sh
~/.local/bin/omnioutliner rich-text row ROW_ID --field topic --document "Project Plan" --json
~/.local/bin/omnioutliner rich-text row ROW_ID --field note --document "Project Plan" --json
~/.local/bin/omnioutliner rich-text cell ROW_ID COLUMN_ID --document "Project Plan" --json
~/.local/bin/omnioutliner styles list --document "Project Plan" --json
~/.local/bin/omnioutliner attachments list --document "Project Plan" --row ROW_ID --limit 50 --json
```

These inspect the rich text the plain reads flatten. `rich-text row`/`cell`
return `{field, plain_text, content_hash, runs, truncated, serialized_bytes,
omitted_runs, applied_style_ids}`; each run has UTF-8 byte `start`/`length`,
`text`, best-effort `font`/`size`/`color`/`bold`/`italic`/`underline`,
`style_ids`, and locally defined `attributes`. `rich-text cell` takes the stable
`COLUMN_ID` from `columns --verbose` (not a title). `styles list` returns the
document's named styles with an `id_persistence` of `proven` or `session_only`.
`attachments list` returns metadata only (`{id?, row_id, field, file_name,
embedded, path?, size_bytes?, content_hash?}`) for topic/note attachments —
file-link `path`s expose local file information and raw bytes are never
returned.

Responses are capped at 512 KiB. Route an oversized rich-text read to a file
with `--out FILE`; narrow an oversized `attachments` read with `--row`/`--limit`
(`--limit` also stops the outline scan early). `styles list` has no narrowing
flags, so an oversized `styles list --json` is rejected with a pointer to rerun
without `--json` (the table output is not capped). The matching writes
(`rich-text replace`, `style apply`, `attachment add`) are deferred — do not
invent them.

## Writes and Import

```sh
~/.local/bin/omnioutliner add --document "Project Plan" --text "Next milestone" --json

~/.local/bin/omnioutliner add \
  --document "Project Plan" \
  --parent PARENT_ROW_ID \
  --position 0 \
  --text "First child" \
  --note note.txt \
  --column Owner=Josh \
  --json

~/.local/bin/omnioutliner update ROW_ID \
  --document "Project Plan" \
  --text "Updated title" \
  --status checked \
  --column Done=true \
  --json

# Typed cell writes key off the stable COLUMN_ID, not the title:
~/.local/bin/omnioutliner update ROW_ID \
  --document "Project Plan" \
  --number-column COLUMN_ID=12.5 \
  --date-column COLUMN_ID=2026-01-02T15:04:05Z \
  --duration-column COLUMN_ID=1h30m \
  --enum-column COLUMN_ID=MEMBER_ID_OR_LABEL \
  --json

~/.local/bin/omnioutliner move ROW_ID \
  --document "Project Plan" \
  --to-parent PARENT_ROW_ID \
  --position 1 \
  --json

~/.local/bin/omnioutliner move ROW_ID --document "Project Plan" --top-level --position 0 --json
~/.local/bin/omnioutliner indent ROW_ID --document "Project Plan" --delta 1 --json
~/.local/bin/omnioutliner indent ROW_ID --document "Project Plan" --delta -1 --json

~/.local/bin/omnioutliner import \
  --document "Project Plan" \
  --from outline.opml \
  --format opml \
  --at-row PARENT_ROW_ID \
  --position 0 \
  --json
```

`--position` is zero-based. Omit it to append when adding or reparenting.
`move --top-level` explicitly reparents a row to the document root and
conflicts with `--to-parent`. Positive `indent --delta` values indent;
negative values outdent. Multi-step indent or outdent requests are preflighted
before mutation.

Writes support row topic text, row notes, status `checked` or `unchecked`,
existing non-built-in text or checkbox columns (`--column TITLE=VALUE`), and
number, date, duration, and enumeration columns (the ID-keyed typed flags).
Numbers use a plain decimal grammar, dates are RFC3339, durations are Go-style
strings (`1h30m`) or integer seconds, and enumerations resolve against an exact
member id or label (ambiguous labels are rejected — use the id). The typed
flag's type must match the column's type, and built-in columns are rejected (use
`--text`/`--note`/`--status`). `--column` only writes text/checkbox columns and a
typed flag only writes its matching number/date/duration/enumeration column, so
the two forms address disjoint column types and can never target the same column;
a mismatch is rejected by those per-form type checks. Typed writes on `add` are deferred:
add the row, then run a typed `update`. Import is OPML only and uses
OmniOutliner's native import path. Imports are not atomic; inspect created row
IDs after `partial_update`.

## Transforms and Delete

```sh
# Read-only preview of any transform (group, ungroup, organize, duplicate, delete):
~/.local/bin/omnioutliner transform preview --row ROW_ID --operation delete --json

# Duplicate a full subtree (default lands the copy right after the source):
~/.local/bin/omnioutliner duplicate ROW_ID --json
~/.local/bin/omnioutliner duplicate ROW_ID --to-parent PARENT_ROW_ID --position 0 --json

# Group siblings under a new parent / ungroup a group / organize by a column:
~/.local/bin/omnioutliner transform group --row ROW_ID --row ROW_ID --title "Bucket" --json
~/.local/bin/omnioutliner transform ungroup ROW_ID --json
~/.local/bin/omnioutliner transform organize --row ROW_ID --row ROW_ID --by-column COLUMN_ID --under PARENT_ROW_ID --json
~/.local/bin/omnioutliner transform organize --row ROW_ID --by-column COLUMN_ID --prune-empty --confirm-prune --json

# Delete one row subtree (destructive, single-row):
~/.local/bin/omnioutliner delete ROW_ID --with-children --confirm ROW_ID --allow-destructive --json
```

Standard `duplicate`/`delete` are top-level verbs; OmniOutliner-specific
`group`/`ungroup`/`organize` live under `transform`. Always `transform preview`
first: it is read-only and reports the resolved scope, whether the operation is
destructive, best-effort predicted created/deleted counts, and
`write_matches_preview` (false when a write would fail, e.g. grouping
non-siblings or ungrouping a leaf). Every transform returns a `TransformResult`
(`target_row_ids`, `affected_row_ids`, `created_row_ids`, `deleted_row_ids`, and
an `updated_subtree` where available).

- `duplicate` copies the full subtree (`created_row_ids` includes copied
  descendants); the copy IDs are only known after the write.
- `group` needs sibling rows under one parent; it creates the parent and moves
  the rows in, then sets the title.
- `ungroup` promotes a group's children to its parent and keeps the former
  (now-leaf) group row; a leaf is rejected.
- `organize` needs explicit `--row` scope and one `--by-column` column (resolved
  by stable ID first, then by a unique column title), and rejects overlapping
  targets (a row plus one of its descendants). For organize, a preview's
  `write_matches_preview=false` means "cannot confirm before the write," not
  "the write will fail." `--prune-empty`
  deletes former parent rows emptied by the move (cascading up to emptied
  ancestors) and is destructive, so it requires `--confirm-prune`.
- `delete` is single-row and destructive (do not depend on OmniOutliner undo). It
  requires `--with-children` (subtree deletion is the only mode, including leaf
  rows), a `--confirm` matching `ROW_ID` exactly after trimming, and
  `--allow-destructive`.

On `partial_update`: a failed `group` title/move names the created group row;
`organize` failing partway names the created groups, confirmed-moved rows, pruned
rows, and the destination (reconcile the destination subtree, then re-run on rows
still misplaced); `delete` finding rows still present names confirmed-deleted and
observed-remaining IDs.

## View State and Selection

These adjust on-screen state (expansion, hoist focus, selection) without
changing outline content, and return the updated view state. They are still
writes; the matching MCP tools require `--allow-writes`.

```sh
~/.local/bin/omnioutliner view state --document "Project Plan" --json
~/.local/bin/omnioutliner selection get --document "Project Plan" --json
~/.local/bin/omnioutliner view expand ROW_ID --with-descendants --json
~/.local/bin/omnioutliner view collapse ROW_ID --json
~/.local/bin/omnioutliner view expand-all --document "Project Plan" --json
~/.local/bin/omnioutliner view collapse-all --document "Project Plan" --json
~/.local/bin/omnioutliner view hoist ROW_ID --document "Project Plan" --json
~/.local/bin/omnioutliner view unhoist --document "Project Plan" --json
~/.local/bin/omnioutliner view unhoist --all --json
~/.local/bin/omnioutliner selection set --row ROW_ID --row ROW_ID --json
~/.local/bin/omnioutliner selection clear --document "Project Plan" --json
```

`view state` returns the document, `hoist_path` (root to current hoisted row),
`selected_row_ids`, and `selected_column_titles`; single-row expand/collapse/
hoist writes also return `affected_row`. `selection set` replaces the selection,
deduplicates IDs, and reveals hidden rows; zero rows is `invalid_argument` (use
`selection clear`). `unhoist` clears the current focus; `--all` clears all
stacked focus levels.

## Document Lifecycle and Windows

```sh
~/.local/bin/omnioutliner windows --json
~/.local/bin/omnioutliner document open ~/Outlines/Plan.ooutline --json
~/.local/bin/omnioutliner document save --file ~/Outlines/Plan.ooutline --json
~/.local/bin/omnioutliner document save-as --document "Plan" --to ~/Outlines/Plan-copy.ooutline --json
~/.local/bin/omnioutliner document close --file ~/Outlines/Plan.ooutline --save --json
~/.local/bin/omnioutliner document close --document "Scratch" --discard --json
```

`windows` is read-only and never moves/focuses windows; its human table is a
summary, so use `--json` for `id`/`index`/`bounds`/`zoomed`. Lifecycle mutations
target one document by `--file PATH` (canonical path from `documents --verbose`,
preferred) or `--document NAME` (a unique name; an exact display name like
`Plan.ooutline` is matched first, so it disambiguates a `Plan.oo3` sibling, and
ambiguous names are rejected); omit both for the frontmost document. `save`/`close
--save` refuse untitled documents and direct you to `save-as`; no Save dialog
ever appears. `close` requires exactly one of `--save`/`--discard`; with no
selector `--save` acts on the frontmost document, while a `--discard` without a
selector is rejected unless `--frontmost` confirms discarding the frontmost
document (mutually exclusive with `--document`/`--file`). `save-as --to` writes `.ooutline`/`.oo3`
only and rejects an existing destination (a best-effort preflight, not an atomic
overwrite guard). Blank/template create and template listing are deferred.

## MCP

```sh
~/.local/bin/omnioutliner mcp
~/.local/bin/omnioutliner mcp --allow-writes
~/.local/bin/omnioutliner mcp --allow-writes --allow-file-root ~/Documents/Outlines
```

Read-only tools:

```text
omnioutliner_documents
omnioutliner_formats
omnioutliner_outline
omnioutliner_rows
omnioutliner_get
omnioutliner_search
omnioutliner_columns
omnioutliner_column_get
omnioutliner_column_values
omnioutliner_export_markdown
omnioutliner_export_opml
omnioutliner_export_native
omnioutliner_view_state
omnioutliner_selection_get
omnioutliner_windows
omnioutliner_transform_preview
omnioutliner_rich_text_row
omnioutliner_rich_text_cell
omnioutliner_styles_list
omnioutliner_attachments_list
```

`omnioutliner_export_native` takes a required `format` (and optional `kind`)
from `omnioutliner_formats`; textual formats return decoded text plus base64,
binary formats return base64 only. `omnioutliner_windows` exposes window and
associated-document metadata (including local file paths).
`omnioutliner_transform_preview` is read-only: it takes an `operation` (group,
ungroup, organize, duplicate, or delete) and a `rows` array, resolves the
targets, and reports destructive effects, predicted counts, and whether a
subsequent write would match — it never mutates. Over MCP the `operation` is
case-sensitive and must match the lowercase schema enum (e.g. `delete`, not
`DELETE`); the CLI `--operation` lowercases and so accepts either case.
`omnioutliner_rich_text_row` (`row_id` + `field`), `omnioutliner_rich_text_cell`
(`row_id` + stable `column_id`), `omnioutliner_styles_list`, and
`omnioutliner_attachments_list` (optional `row_id`, `limit`) are read-only and
return the same rich-text/named-style/attachment objects as the CLI. Their
descriptions disclose that rich text, attachment file names, and file-link paths
may expose local file information; raw attachment data is never returned. There
is no `--out` over MCP, so a rich-text response over 512 KiB is rejected with
`invalid_argument` (read it through the CLI's `rich-text --out FILE`).

Write tools appear only with `--allow-writes`:

```text
omnioutliner_add
omnioutliner_update
omnioutliner_move
omnioutliner_indent
omnioutliner_import_opml
omnioutliner_duplicate
omnioutliner_transform_group
omnioutliner_transform_ungroup
omnioutliner_transform_organize
omnioutliner_delete
omnioutliner_view_expand
omnioutliner_view_collapse
omnioutliner_view_expand_all
omnioutliner_view_collapse_all
omnioutliner_view_hoist
omnioutliner_view_unhoist
omnioutliner_selection_set
omnioutliner_selection_clear
omnioutliner_document_save
omnioutliner_document_close
```

Additional write tools when `--allow-file-root` is configured:

```text
omnioutliner_document_open
omnioutliner_document_save_as
```

`omnioutliner_delete` is registered only with `--allow-writes` and requires
`with_children: true` plus a `confirm` matching the target `row_id`;
`omnioutliner_transform_organize` requires `confirm_prune: true` when
`prune_empty: true`. Preview any transform first with the read-only
`omnioutliner_transform_preview`.

View-state write tools change only on-screen state (expand/collapse, hoist, selection) and are non-destructive, but still require `--allow-writes`. The document lifecycle tools take `document` or `file` (mutually exclusive; omit both for the frontmost document), `omnioutliner_document_close` requires `save` (true/false); with no selector `save=true` closes the frontmost document, while `save=false` with no selector is rejected unless `frontmost=true` confirms discarding the frontmost document. `file` selectors require `--allow-file-root`; document-name and frontmost selectors do not. `omnioutliner_document_open` and `omnioutliner_document_save_as` are absent unless at least one root is configured. `omnioutliner_document_templates`/`omnioutliner_document_create` are not registered.

MCP document-scoped tools accept optional `document`; omitted `document`
targets the frontmost document. Rows and search accept `depth`, `parent_id`,
`status`, and `column_filters`. `omnioutliner_column_get` and
`omnioutliner_column_values` take a stable `column_id`. `omnioutliner_update`
accepts `typed_column_values` (an array of `{column_id, type, value}` with type
`number`/`date`/`duration`/`enumeration`) alongside the title-based
`column_values`; the two address disjoint column types (text/checkbox vs the
typed columns) and so can never target the same column. Add/update note inputs accept inline `note` or allowed-root local `note_path`. OPML import accepts inline `content` or allowed-root local `path`.

## Errors

With `--json`, failures have:

```json
{"error":{"kind":"not_found","message":"..."}}
```

Important kinds include `invalid_argument`, `not_found`, `app_unavailable`,
`permission_denied`, `timeout`, `partial_update`, and `runtime`. Classify by
`error.kind`, not by human text.

For deeper reference, see `docs/apps/omnioutliner/AGENTS.md`,
`docs/apps/omnioutliner/README.md`, and
`docs/apps/omnioutliner/USER-GUIDE.md` when they are available.
