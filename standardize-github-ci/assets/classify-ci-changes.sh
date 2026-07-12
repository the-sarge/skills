#!/usr/bin/env bash
set -euo pipefail

base="${CI_BASE_SHA:-${1:-}}"
head="${CI_HEAD_SHA:-${2:-HEAD}}"

if test -z "$base" || ! git rev-parse --verify -q "$base^{commit}" >/dev/null || ! git rev-parse --verify -q "$head^{commit}" >/dev/null; then
  printf 'warning: unable to determine a trustworthy diff; failing closed as source-affecting\n' >&2
  changed_files=""
  indeterminate=true
else
  changed_files="$(git diff --name-only --no-renames "$base" "$head")"
  indeterminate=false
fi

changed_count=0
docs_only=true
source_changed=false
dependencies_changed=false
workflows_changed=false
platform_changed=false
release_changed=false

if test "$indeterminate" = true || test -z "$changed_files"; then
  docs_only=false
  source_changed=true
else
  while IFS= read -r changed_path; do
    test -n "$changed_path" || continue
    changed_count=$((changed_count + 1))
    path_is_docs=false

    case "$changed_path" in
      *.md|docs/*|memory/*)
        path_is_docs=true
        ;;
      *)
        docs_only=false
        source_changed=true
        ;;
    esac

    case "$changed_path" in
      go.mod|go.sum|Cargo.toml|Cargo.lock|package.json|package-lock.json|pnpm-lock.yaml|yarn.lock|requirements*.txt|pyproject.toml|uv.lock)
        dependencies_changed=true
        ;;
    esac

    case "$changed_path" in
      .github/workflows/*|.github/actions/*|scripts/ci/*|Taskfile.yml|Taskfile.yaml|taskfile.yml|taskfile.yaml)
        workflows_changed=true
        ;;
    esac

    if test "$path_is_docs" = false; then
      case "$changed_path" in
        *_windows.go|*_darwin.go|*_linux.go|*_unix.go|*windows*|*darwin*|*macos*|Dockerfile|Dockerfile.*|docker/*|packaging/*)
          platform_changed=true
          ;;
      esac
    fi

    case "$changed_path" in
      .goreleaser.yml|.goreleaser.yaml|.github/workflows/release.yml|.github/workflows/release.yaml|CHANGELOG.md|release/*|packaging/*)
        release_changed=true
        ;;
    esac
  done <<< "$changed_files"
fi

emit() {
  printf '%s=%s\n' "$1" "$2"
  if test -n "${GITHUB_OUTPUT:-}"; then
    printf '%s=%s\n' "$1" "$2" >> "$GITHUB_OUTPUT"
  fi
}

emit changed_count "$changed_count"
emit docs_only "$docs_only"
emit source_changed "$source_changed"
emit dependencies_changed "$dependencies_changed"
emit workflows_changed "$workflows_changed"
emit platform_changed "$platform_changed"
emit release_changed "$release_changed"

if test -n "$changed_files"; then
  printf '%s\n' "$changed_files" | sed 's/^/changed: /'
fi
