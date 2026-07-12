#!/usr/bin/env bash
set -euo pipefail

require_result() {
  label="$1"
  expected="$2"
  actual="$3"
  if test "$actual" != "$expected"; then
    printf 'error: %s result was %s, expected %s\n' "$label" "${actual:-unset}" "$expected" >&2
    exit 1
  fi
}

require_result classify success "${CLASSIFY_RESULT:-}"

case "${DOCS_ONLY:-}" in
  true)
    require_result docs success "${DOCS_RESULT:-}"
    require_result code skipped "${CODE_RESULT:-}"
    ;;
  false)
    require_result docs skipped "${DOCS_RESULT:-}"
    require_result code success "${CODE_RESULT:-}"
    ;;
  *)
    printf 'error: DOCS_ONLY must be true or false\n' >&2
    exit 1
    ;;
esac

printf 'required CI lane completed successfully\n'
