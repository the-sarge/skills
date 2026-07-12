#!/usr/bin/env bash
set -euo pipefail

require_success() {
  label="$1"
  actual="$2"
  if test "$actual" != success; then
    printf 'error: %s result was %s, expected success\n' "$label" "${actual:-unset}" >&2
    exit 1
  fi
}

require_skipped() {
  label="$1"
  actual="$2"
  if test "$actual" != skipped; then
    printf 'error: %s result was %s, expected skipped\n' "$label" "${actual:-unset}" >&2
    exit 1
  fi
}

require_success classify "${CLASSIFY_RESULT:-}"

case "${DOCS_ONLY:-}" in
  true)
    require_success docs "${DOCS_RESULT:-}"
    require_skipped code "${CODE_RESULT:-}"
    ;;
  false)
    require_skipped docs "${DOCS_RESULT:-}"
    require_success code "${CODE_RESULT:-}"
    ;;
  *)
    printf 'error: DOCS_ONLY must be true or false\n' >&2
    exit 1
    ;;
esac

printf 'required CI lane completed successfully\n'
