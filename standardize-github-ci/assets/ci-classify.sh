#!/usr/bin/env bash
# Answers exactly one question about the change and always exits 0.
#   Default mode (for `task ci`): is this change docs-only?
#     Prints `docs_only=true` or `docs_only=false`. Fails closed: any doubt
#     (no base, empty diff, non-doc file) => false, so the full gate runs.
#   CI_MATCH_GLOBS mode (for path-gated `task ci-<lane>` targets): does any changed
#     file match these globs? Prints `matches=true` or `matches=false`. Fails closed:
#     any doubt (no base, empty diff) => true, so the lane runs.
#
# Env:
#   CI_BASE_SHA        explicit base commit (default: merge-base with the default branch)
#   CI_HEAD_SHA        head commit (default: HEAD)
#   CI_DEFAULT_BRANCH  default branch name (default: GITHUB_BASE_REF, else the origin/HEAD
#                      target, else main)
#   CI_REMOTE          remote name (default: origin)
#   CI_DOCS_GLOBS      space-separated shell globs treated as documentation
#                      (default: '*.md docs/* DEV-JOURNAL.md LICENSE LICENSE.*')
#   CI_MATCH_GLOBS     when set, switch to match mode: space-separated shell globs a
#                      lane cares about (for example 'codec/* internal/codec/*')
set -euo pipefail
set -f # never pathname-expand the globs

remote="${CI_REMOTE:-origin}"
head="${CI_HEAD_SHA:-HEAD}"
docs_globs="${CI_DOCS_GLOBS:-*.md docs/* DEV-JOURNAL.md LICENSE LICENSE.*}"
match_globs="${CI_MATCH_GLOBS:-}"

key=docs_only
test -z "$match_globs" || key=matches

emit() {
  printf '%s=%s\n' "$key" "$1"
  if test -n "${GITHUB_OUTPUT:-}"; then
    printf '%s=%s\n' "$key" "$1" >> "$GITHUB_OUTPUT"
  fi
  exit 0
}

# Fail-closed answer: docs mode => false (run everything); match mode => true (run the lane).
fail_closed() {
  if test "$key" = matches; then emit true; else emit false; fi
}

default_branch="${CI_DEFAULT_BRANCH:-${GITHUB_BASE_REF:-}}"
if test -z "$default_branch"; then
  default_branch="$(git symbolic-ref -q --short "refs/remotes/$remote/HEAD" 2>/dev/null | sed "s#^$remote/##" || true)"
  default_branch="${default_branch:-main}"
fi

base="${CI_BASE_SHA:-}"
if test -z "$base"; then
  if git rev-parse --verify -q "$remote/$default_branch^{commit}" >/dev/null; then
    base="$(git merge-base "$remote/$default_branch" "$head" 2>/dev/null || true)"
  elif git rev-parse --verify -q "$default_branch^{commit}" >/dev/null; then
    base="$(git merge-base "$default_branch" "$head" 2>/dev/null || true)"
  fi
fi

if test -z "$base" || ! git rev-parse --verify -q "$base^{commit}" >/dev/null || ! git rev-parse --verify -q "$head^{commit}" >/dev/null; then
  printf 'ci-classify: cannot determine a trustworthy base; failing closed\n' >&2
  fail_closed
fi

changed="$(git diff --name-only --no-renames "$base" "$head")"
if test -z "$changed"; then
  printf 'ci-classify: empty diff; failing closed\n' >&2
  fail_closed
fi

if test "$key" = matches; then
  while IFS= read -r path; do
    test -n "$path" || continue
    for glob in $match_globs; do
      # shellcheck disable=SC2254
      case "$path" in
        $glob) printf 'ci-classify: %s matches %s\n' "$path" "$glob" >&2; emit true ;;
      esac
    done
  done <<< "$changed"
  emit false
fi

while IFS= read -r path; do
  test -n "$path" || continue
  matched=false
  for glob in $docs_globs; do
    # shellcheck disable=SC2254
    case "$path" in
      $glob) matched=true; break ;;
    esac
  done
  if test "$matched" = false; then
    printf 'ci-classify: %s is not documentation\n' "$path" >&2
    emit false
  fi
done <<< "$changed"

emit true
