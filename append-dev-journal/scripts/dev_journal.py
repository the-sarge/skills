#!/usr/bin/env python3
"""Preview or append a generic DEV-JOURNAL.md entry."""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path


TIMESTAMP_RE = re.compile(r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2} ([A-Z]{2,5}|[+-]\d{4})$")
TITLE_RE = re.compile(r"^[^\n#].*\S$")
SHA_RE = re.compile(r"^[0-9a-fA-F]{7,40}$")
STALE_LOCK_SECONDS = 60 * 60


class JournalError(RuntimeError):
    pass


@dataclass(frozen=True)
class ResolvedJournal:
    repo: Path
    journal: Path
    will_create: bool


def run_git(repo: Path, args: list[str], check: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        ["git", *args],
        cwd=repo,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if check and result.returncode != 0:
        message = result.stderr.strip() or result.stdout.strip() or "git command failed"
        raise JournalError(f"git {' '.join(args)}: {message}")
    return result


def git_root(path: Path) -> Path:
    result = run_git(path, ["rev-parse", "--show-toplevel"])
    return Path(result.stdout.strip()).resolve()


def inside_repo(repo: Path, path: Path) -> bool:
    try:
        path.resolve().relative_to(repo)
        return True
    except ValueError:
        return False


def resolve_journal(repo: Path, journal_path: str | None) -> ResolvedJournal:
    if journal_path:
        candidate = Path(journal_path)
        if not candidate.is_absolute():
            candidate = repo / candidate
        candidate = candidate.resolve()
        if not inside_repo(repo, candidate):
            raise JournalError(f"journal path is outside repo: {candidate}")
        return ResolvedJournal(repo=repo, journal=candidate, will_create=not candidate.exists())

    root_journal = repo / "DEV-JOURNAL.md"
    docs_journal = repo / "docs" / "DEV-JOURNAL.md"
    existing = [path for path in (root_journal, docs_journal) if path.exists()]

    if len(existing) == 1:
        return ResolvedJournal(repo=repo, journal=existing[0], will_create=False)
    if len(existing) == 0:
        return ResolvedJournal(repo=repo, journal=docs_journal, will_create=True)
    raise JournalError("both DEV-JOURNAL.md and docs/DEV-JOURNAL.md exist; pass --journal-path")


def default_branch_sha(repo: Path) -> str | None:
    remote_head = run_git(repo, ["symbolic-ref", "--quiet", "refs/remotes/origin/HEAD"], check=False)
    refs: list[str] = []
    if remote_head.returncode == 0:
        refs.append(remote_head.stdout.strip())

    remote_show = run_git(repo, ["remote", "show", "origin"], check=False)
    if remote_show.returncode == 0:
        for line in remote_show.stdout.splitlines():
            stripped = line.strip()
            if stripped.startswith("HEAD branch:"):
                branch = stripped.split(":", 1)[1].strip()
                if branch and branch != "(unknown)":
                    refs.append(f"refs/remotes/origin/{branch}")

    for branch in ("main", "master", "trunk"):
        refs.extend([f"refs/remotes/origin/{branch}", f"refs/heads/{branch}"])

    seen: set[str] = set()
    for ref in refs:
        if not ref or ref in seen:
            continue
        seen.add(ref)
        result = run_git(repo, ["rev-parse", "--verify", f"{ref}^{{commit}}"], check=False)
        if result.returncode == 0:
            return result.stdout.strip()
    return None


def validate_timestamp(value: str) -> None:
    if not TIMESTAMP_RE.match(value):
        raise JournalError("datetime must match YYYY-MM-DD HH:MM TZ")


def validate_inputs(title: str, actor: str, body: str, main_sha: str, timestamp: str) -> None:
    if not TITLE_RE.match(title.strip()):
        raise JournalError("title must be a non-empty single-line heading fragment")
    if "\n" in actor or not actor.strip():
        raise JournalError("actor must be non-empty and single-line")
    if not body.strip():
        raise JournalError("entry body must be non-empty")
    if re.search(r"^##\s+", body, flags=re.MULTILINE):
        raise JournalError("entry body must not contain a level-2 journal heading")
    if not SHA_RE.match(main_sha):
        raise JournalError("main sha must be a 7-40 character hex commit")
    validate_timestamp(timestamp)


def local_timestamp() -> str:
    return datetime.now().astimezone().strftime("%Y-%m-%d %H:%M %Z")


def read_body(path: str) -> str:
    return Path(path).read_text(encoding="utf-8")


def target_is_dirty(repo: Path, journal: Path) -> bool:
    if not journal.exists():
        return False
    rel = journal.relative_to(repo).as_posix()
    result = run_git(repo, ["status", "--porcelain", "--", rel])
    return bool(result.stdout.strip())


def lock_path(repo: Path) -> Path:
    result = run_git(repo, ["rev-parse", "--git-path", "dev-journal-append.lock"])
    return (repo / result.stdout.strip()).resolve()


def parse_lock_created_at(metadata: str) -> datetime | None:
    for line in metadata.splitlines():
        if line.startswith("created_at="):
            value = line.split("=", 1)[1].strip()
            try:
                return datetime.fromisoformat(value.replace("Z", "+00:00"))
            except ValueError:
                return None
    return None


def acquire_lock(repo: Path) -> Path:
    path = lock_path(repo)
    try:
        path.mkdir()
    except FileExistsError as exc:
        metadata_path = path / "metadata"
        metadata = metadata_path.read_text(encoding="utf-8") if metadata_path.exists() else ""
        created_at = parse_lock_created_at(metadata)
        now = datetime.now(timezone.utc)
        if created_at is None:
            raise JournalError(f"lock exists with missing or malformed metadata: {path}") from exc
        if (now - created_at.astimezone(timezone.utc)).total_seconds() <= STALE_LOCK_SECONDS:
            raise JournalError(f"lock exists and is not stale: {path}") from exc
        shutil.rmtree(path)
        path.mkdir()

    now = datetime.now(timezone.utc).replace(microsecond=0)
    (path / "metadata").write_text(
        f"created_at={now.isoformat().replace('+00:00', 'Z')}\npid={os.getpid()}\n",
        encoding="utf-8",
    )
    return path


def release_lock(path: Path) -> None:
    shutil.rmtree(path)


def initial_journal_text() -> str:
    return (
        "# Development Journal\n\n"
        "**Append-only. New entries go at the END of this file.**\n\n"
        "Oldest entry first, most recent entry last.\n"
    )


def compose_entry(title: str, timestamp: str, main_sha: str, actor: str, body: str) -> str:
    normalized_body = body.strip() + "\n"
    return (
        f"## {title.strip()} - {timestamp}\n\n"
        f"**Main:** `{main_sha}`\n"
        f"**Actor:** {actor.strip()}\n\n"
        f"{normalized_body}"
    )


def append_text(existing: str, entry: str) -> str:
    base = existing.rstrip()
    if not base:
        return entry.rstrip() + "\n"
    if base.endswith("---"):
        return base + "\n\n" + entry.rstrip() + "\n"
    return base + "\n\n---\n\n" + entry.rstrip() + "\n"


def preview_or_append(args: argparse.Namespace, append: bool) -> int:
    repo = git_root(Path(args.repo).resolve())
    resolved = resolve_journal(repo, args.journal_path)
    timestamp = args.datetime_tz or local_timestamp()
    main_sha = args.main_sha or default_branch_sha(repo)
    if main_sha is None:
        raise JournalError("could not determine default branch commit; pass --main-sha")
    main_sha = main_sha[:12]
    body = read_body(args.body_file)

    validate_inputs(args.title, args.actor, body, main_sha, timestamp)

    if target_is_dirty(repo, resolved.journal):
        rel = resolved.journal.relative_to(repo)
        raise JournalError(f"target journal has uncommitted changes: {rel}")

    entry = compose_entry(args.title, timestamp, main_sha, args.actor, body)
    existing = resolved.journal.read_text(encoding="utf-8") if resolved.journal.exists() else initial_journal_text()
    heading = entry.splitlines()[0]
    if heading in existing:
        raise JournalError(f"duplicate journal heading: {heading}")
    final_text = append_text(existing, entry)

    if not append:
        print(f"repo: {repo}")
        print(f"journal: {resolved.journal.relative_to(repo)}")
        print(f"will_create: {str(resolved.will_create).lower()}")
        print()
        print(entry.rstrip())
        return 0

    lock = acquire_lock(repo)
    try:
        resolved.journal.parent.mkdir(parents=True, exist_ok=True)
        before = resolved.journal.read_text(encoding="utf-8") if resolved.journal.exists() else initial_journal_text()
        if before != existing:
            raise JournalError("journal changed after preview state was read")
        resolved.journal.write_text(final_text, encoding="utf-8")
        after = resolved.journal.read_text(encoding="utf-8")
        if after != final_text or not after.endswith("\n") or after.count(heading) != 1:
            raise JournalError("post-write journal validation failed")
    except Exception:
        raise
    else:
        release_lock(lock)

    rel = resolved.journal.relative_to(repo)
    print(f"appended: {rel}")
    print(f"heading: {heading}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=".", help="git repo path, default: current directory")
    subparsers = parser.add_subparsers(dest="command", required=True)

    for command in ("preview", "append"):
        sub = subparsers.add_parser(command)
        sub.add_argument("--journal-path", help="journal path relative to repo or absolute inside repo")
        sub.add_argument("--title", required=True, help="short single-line entry title")
        sub.add_argument("--actor", default="Codex", help="single-line actor name, default: Codex")
        sub.add_argument("--body-file", required=True, help="markdown file containing the entry body")
        sub.add_argument("--datetime-tz", help="timestamp in YYYY-MM-DD HH:MM TZ format")
        sub.add_argument("--main-sha", help="default branch commit sha, if auto-detection is unavailable")

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return preview_or_append(args, append=args.command == "append")
    except JournalError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
