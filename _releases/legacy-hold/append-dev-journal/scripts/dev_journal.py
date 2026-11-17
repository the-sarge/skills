#!/usr/bin/env python3
"""Legacy hold stub for append-dev-journal's helper.

Journal dispatch is held. Every invocation, whatever its arguments, refuses
before reading or writing any file, repository, or lock, and prints
self-contained hold directions to stderr. It never parses or opens its
arguments; it only echoes them so the caller knows which inputs to keep.
"""

from __future__ import annotations

import shlex
import sys

EXIT_HELD = 75  # EX_TEMPFAIL: journal dispatch is held; nothing was written.

DIRECTIONS = """\
append-dev-journal: JOURNAL DISPATCH IS HELD. Nothing was written.

This is the legacy hold release of append-dev-journal. Markdown journal
writes and hosted journal writes are both paused for the hosted-journal
cutover. This helper refused before reading or writing anything: the
journal, its lock, the repository, and every input file are untouched.
Refused invocation: {invocation}

Follow these directions instead of any cached append steps:

1. Hold the write. Leave every journal unchanged. The only write path while
   held is the owner draft in 3a. A hand-edited, committed, or pull-requested
   DEV-JOURNAL.md entry is not a fallback, and neither is a hosted write,
   submit, pending retry, operation apply, operation bind, or amend --apply.
2. Keep the inputs in place, unchanged: the exact body file, title, actor,
   and the account identity (canonical repository host/owner/name, PR
   number, full merge commit and merge time; or, for a general account, the
   originating task and account slot).
3. Preserve the account in exactly one way:
   a. Confirmed owner draft: on the designated writing host, with the writer
      installation profile the foreground coordinator gave you, run
        dev-journal agent --profile PROFILE operation prepare \\
          --completion-repository HOST/OWNER/NAME --change PR_NUMBER \\
          --merge FULL_MERGE_SHA --at MERGE_TIME_RFC3339 --title "TITLE" \\
          --actor "ACTOR" --file BODY_FILE --remote "$(git remote get-url origin)"
      (a general account uses --task TASK --slot SLOT instead of the
      completion flags and --at), then read it back with
        dev-journal agent --profile PROFILE operation show OPERATION_ID
      It is confirmed only when that readback returns your title and body.
   b. Unconfirmed external retention: whenever 3a is unavailable (another
      host, no profile, prepare or show refused or failed), copy the body
      file and a note of the other inputs to a durable location outside
      every disposable worktree, scratchpad, and temporary directory, and
      record absolute paths and SHA-256 values. It stays unconfirmed until
      the foreground coordinator confirms durability; keep the copy, the
      original, and any worktree holding the original until then.
4. Report the journal step as journal-pending, never as complete. Name the
   account identity, the retention (confirmed owner draft OPERATION_ID, or
   unconfirmed external retention with paths and SHA-256 values), and the
   owner: the foreground cutover coordinator, who resumes it after release.
5. Continue the rest of your workflow; only journal closure stays pending.
   Leave recovery to the foreground coordinator: do not rerun this helper,
   wait for release, or start a retry or background job. Release arrives as
   a refreshed skill installation, not as a change in this helper.
"""


def main(argv: list[str]) -> int:
    invocation = shlex.join(["dev_journal.py", *argv])
    sys.stderr.write(DIRECTIONS.format(invocation=invocation))
    return EXIT_HELD


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
