#!/usr/bin/env python3
"""Retired Markdown helper of append-dev-journal.

Development-journal accounts are written to the hosted journal through the
canonical dev-journal skill. Every invocation, whatever its arguments, refuses
before reading or writing any file, repository, or lock, and prints
self-contained directions to stderr. It never parses or opens its arguments;
it only echoes them so the caller knows which inputs to keep.
"""

from __future__ import annotations

import os
import shlex
import sys

EXIT_RETIRED = 69  # EX_UNAVAILABLE: the Markdown helper is retired; nothing was written.

# The canonical skill sits beside this skill in the skills source tree. The path
# is computed from this file's location only; nothing is opened.
CANONICAL_SKILL = os.path.normpath(
    os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "dev-journal", "SKILL.md")
)

DIRECTIONS = """\
append-dev-journal: THE MARKDOWN JOURNAL HELPER IS RETIRED. Nothing was written.

Development-journal accounts now go to the hosted journal. This helper
refused before reading or writing anything: the journal, its lock, the
repository, and every input file are untouched.
Refused invocation: {invocation}

Do this instead of any cached append steps:

1. Do not append to, create, commit, or open a PR for any DEV-JOURNAL.md.
   Markdown journals are historical reading sources only, and a manual
   append is not a fallback.
2. Keep the account identity and inputs in place, unchanged: the body file,
   title, actor, and the account repository's remote URL from its own checkout.
3. Read the canonical dev-journal skill and follow it for this account:
     {skill}
   Follow its installed-profile, selection, and receipt instructions.
4. For journal-pending, use that skill's retention and reporting procedure.
"""


def main(argv: list[str]) -> int:
    invocation = shlex.join(["dev_journal.py", *argv])
    sys.stderr.write(DIRECTIONS.format(invocation=invocation, skill=CANONICAL_SKILL))
    return EXIT_RETIRED


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
