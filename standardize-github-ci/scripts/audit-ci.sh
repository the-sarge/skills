#!/usr/bin/env bash
# Read-only conformance audit of one repository against the portfolio CI standard
# (standardize-github-ci/references/ci-policy.md).
#
# Usage: audit-ci.sh [repository-path]
# Env:   CI_AUDIT_RULESET_JSON=<file>  audit default-branch rules from this JSON (array from
#                                      GET /repos/{o}/{r}/rules/branches/{branch}) instead of GitHub
#        CI_AUDIT_RULESET=live         query GitHub with gh for the default-branch rules
# Exit:  0 conformant, 3 deviations found, 2 usage or tool error.
#
# shellcheck disable=SC2016
# SC2016: single quotes are intentional throughout; they hold jq programs and
#         literal GitHub Actions expression syntax, not shell expansions.
set -euo pipefail

repo_input="${1:-.}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'error: required command not found: %s\n' "$1" >&2
    exit 2
  fi
}
require_command git
require_command jq
require_command yq

repo_root="$(git -C "$repo_input" rev-parse --show-toplevel 2>/dev/null)" || {
  printf 'error: not a git repository: %s\n' "$repo_input" >&2
  exit 2
}

deviations=""
deviate() { # code, message
  if test -z "$deviations"; then
    deviations="- \`$1\` $2"
  else
    deviations="$deviations
- \`$1\` $2"
  fi
}

# --- header
printf '# CI conformance audit: %s\n\n' "$(basename "$repo_root")"
printf -- '- Repository: `%s`\n' "$repo_root"
printf -- '- Branch: `%s`\n' "$(git -C "$repo_root" branch --show-current 2>/dev/null || true)"
printf -- '- HEAD: `%s`\n' "$(git -C "$repo_root" rev-parse --short HEAD)"
printf -- '- Origin: `%s`\n\n' "$(git -C "$repo_root" remote get-url origin 2>/dev/null || printf 'none')"

# --- required workflow
# Every check below tolerates a malformed workflow: `.jobs`, each job body, and
# each step list are normalized to the expected type before they are inspected,
# and jq stderr is discarded. An odd document therefore yields deviations and a
# complete report rather than a jq error, a truncated report, and an exit status
# outside the 0/2/3 contract.
workflow_dir="$repo_root/.github/workflows"
ci_yml="$workflow_dir/ci.yml"
required_jobs=""
needs_edges=""
printf '## Required workflow `.github/workflows/ci.yml`\n\n'
if ! test -f "$ci_yml"; then
  printf -- '- Missing\n\n'
  deviate CI-MISSING 'ci.yml: required workflow not found'
elif ! wf="$(yq -o=json -I=0 '.' "$ci_yml" 2>/dev/null)"; then
  printf -- '- Present but not parseable as YAML\n\n'
  deviate CI-MISSING 'ci.yml: not parseable as YAML'
else
  j() { printf '%s' "$wf" | jq -e "$1" >/dev/null 2>&1; }

  j '(.on|type=="object") and (.on|keys)==["pull_request"] and (.on.pull_request|type=="object") and (.on.pull_request|keys)==["types"] and ((.on.pull_request.types|sort)==["opened","ready_for_review","reopened","synchronize"])' \
    || deviate CI-TRIGGER 'ci.yml: trigger must be exactly pull_request with types [opened, synchronize, reopened, ready_for_review] and no paths or branches filters'
  j '(.concurrency.group|type=="string") and (.concurrency.group|contains("github.event.pull_request.number")) and .concurrency["cancel-in-progress"]==true' \
    || deviate CI-CONCURRENCY 'ci.yml: concurrency must group by github.event.pull_request.number with cancel-in-progress: true'
  j '.permissions == {"contents":"read"}' \
    || deviate CI-PERMISSIONS 'ci.yml: workflow permissions must be exactly contents: read'
  j '(.jobs|type=="object") and (.jobs|has("ci-required"))' \
    || deviate CI-JOBS 'ci.yml: job ci-required is required'

  job_names="$(printf '%s' "$wf" | jq -r '(.jobs? // {} | if type=="object" then . else {} end) | keys_unsorted[]' 2>/dev/null || true)"
  while IFS= read -r job; do
    test -n "$job" || continue
    case "$job" in
      ci-required) target='task ci' ;;
      ci-*) target="task $job" ;;
      *) deviate CI-JOB-NAME "ci.yml: job $job is not part of the standard; delete it, or fold its check into task check (ci-required) or into a new task ci-<lane> with its own ci-<lane> job if it must block merging; non-blocking work moves to a non-required workflow"; continue ;;
    esac
    required_jobs="${required_jobs:+$required_jobs, }\`$job\`"
    jobjson="$(printf '%s' "$wf" | jq -c --arg job "$job" '.jobs[$job] | if type=="object" then . else {} end' 2>/dev/null)" || jobjson=''
    test -n "$jobjson" || jobjson='{}'
    stepsjson="$(printf '%s' "$jobjson" | jq -c '(.steps? // []) | if type=="array" then . else [] end' 2>/dev/null)" || stepsjson=''
    test -n "$stepsjson" || stepsjson='[]'
    jj() { printf '%s' "$jobjson" | jq -e "$1" >/dev/null 2>&1; }
    js() { printf '%s' "$stepsjson" | jq -e "$1" >/dev/null 2>&1; }
    jj '(.if|type=="string") and (.if|contains("!github.event.pull_request.draft")) and (.if|contains("github.event.pull_request.head.repo.full_name == github.repository"))' \
      || deviate CI-GUARD "ci.yml: job $job must guard with !github.event.pull_request.draft && head.repo.full_name == github.repository"
    jj '.["timeout-minutes"]|type=="number"' \
      || deviate CI-TIMEOUT "ci.yml: job $job must set timeout-minutes"
    # needs: is permitted only for a cross-runner artifact exchange: the job is a destination ci-<lane> (never
    # ci-required), every target is a different ci-* job in this workflow (hence itself a required check), and the
    # job must keep GitHub's implicit success gate: no status function at all (always/failure/cancelled would run after
    # an upstream failure; !success() or success() == false would skip after a green upstream, and a skipped required
    # check counts as passing). GitHub expression functions are case-insensitive and allow spaces.
    if jj 'has("needs")'; then
      needs_list="$(printf '%s' "$jobjson" | jq -r '.needs | if type=="array" then .[] elif type=="string" then . else empty end' 2>/dev/null || true)"
      needs_ok=true
      test -n "$needs_list" || needs_ok=false
      test "$job" != ci-required || needs_ok=false
      while IFS= read -r dep; do
        test -n "$dep" || continue
        case "$dep" in
          ci-*) { test "$dep" != "$job" && printf '%s\n' "$job_names" | grep -qxF -- "$dep"; } || needs_ok=false ;;
          *) needs_ok=false ;;
        esac
      done <<< "$needs_list"
      if jj '(.if // "" | tostring) | test("(always|failure|cancelled|success)[[:space:]]*\\("; "i")'; then needs_ok=false; fi
      if test "$needs_ok" = true; then
        needs_edges="${needs_edges:+$needs_edges; }\`$job\` needs $(printf '%s\n' "$needs_list" | sed 's/.*/`&`/' | paste -sd, - | sed 's/,/, /g')"
      else
        deviate CI-NEEDS "ci.yml: job $job may declare needs only as the destination ci-<lane> of a cross-runner artifact exchange: every target must be a different ci-* job in ci.yml, ci-required never depends on other jobs, and the job's if must not call any status function (always(), failure(), cancelled(), success())"
      fi
    fi
    # Aggregation: fail closed on any use of the needs context inside an expression other than an outputs access
    # (needs.<job>.outputs.<name> or bracket equivalents; a bare .outputs object is not a named output and is rejected). Expression text is every ${{ }} fragment anywhere in the
    # job (spanning lines via [\s\S]) plus the job-level and step-level `if` values, which GitHub evaluates as expressions even
    # without delimiters. This catches .result, .conclusion, wildcard, bracket, toJSON(needs), and future spellings.
    if printf '%s' "$jobjson" | jq -e '
        ([.. | strings | scan("\\$\\{\\{[\\s\\S]*?\\}\\}")]
         + [(.if // "" | tostring)]
         + [((.steps? // []) | if type=="array" then .[] else empty end | if type=="object" then (.if // "" | tostring) else "" end)])
        | map(gsub("needs[[:space:]]*(\\.[[:space:]]*[A-Za-z0-9_-]+|\\[[[:space:]]*(\"[^\"]*\"|\u0027[^\u0027]*\u0027)[[:space:]]*\\])[[:space:]]*(\\.[[:space:]]*outputs|\\[[[:space:]]*(\"outputs\"|\u0027outputs\u0027)[[:space:]]*\\])[[:space:]]*(\\.[[:space:]]*[A-Za-z0-9_-]+|\\[[[:space:]]*(\"[^\"]*\"|\u0027[^\u0027]*\u0027)[[:space:]]*\\])"; ""; "i"))
        | any(test("\\bneeds\\b"; "i"))' >/dev/null 2>&1; then
      deviate CI-AGGREGATE "ci.yml: job $job uses the needs context for something other than needs.<job>.outputs.<name> (for example .result, .conclusion, needs.*, or toJSON(needs)); jobs must not aggregate other jobs — each ci-* job is required on its own"
    fi
    jj '(has("strategy")|not) or ((.strategy|type=="object") and (.strategy.matrix == null))' \
      || deviate CI-MATRIX "ci.yml: job $job must not use a matrix; route by job, not by matrix"
    printf '%s' "$stepsjson" | jq -e --arg t "$target" '[.[] | select(type=="object" and has("run")) | .run] == [$t]' >/dev/null 2>&1 \
      || deviate CI-TARGET "ci.yml: job $job must run exactly one step: $target"
    jj '(.steps? // []) | (type=="array") and all(type=="object")' \
      || deviate CI-PIN "ci.yml: job $job has a step that is not a mapping; every step must be a run step or a SHA-pinned uses step"
    while IFS= read -r uses; do
      test -n "$uses" || continue
      # Local composite actions and docker:// images carry no ref to pin.
      case "$uses" in ./*|docker://*) continue ;; esac
      printf '%s' "$uses" | grep -Eq '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(/[A-Za-z0-9_./-]+)?@[0-9a-f]{40}$' \
        || deviate CI-PIN "ci.yml: job $job uses unpinned action $uses"
    done <<< "$(printf '%s' "$stepsjson" | jq -r '.[] | select(type=="object" and has("uses")) | .uses' 2>/dev/null || true)"
    js '[.[] | select(type=="object" and ((.uses? // "") | type=="string") and ((.uses? // "") | startswith("actions/checkout@"))) | ((.with? // {}) | if type=="object" then .["fetch-depth"] else null end)] | length > 0 and all(. == 0)' \
      || deviate CI-FETCH-DEPTH "ci.yml: job $job must check out with fetch-depth: 0"
  done <<< "$job_names"

  printf -- '- Required jobs: %s\n' "${required_jobs:-none}"
  printf -- '- Artifact-exchange edges: %s\n' "${needs_edges:-none}"
  printf -- '- Runners:\n'
  printf '%s' "$wf" | jq -r '(.jobs? // {} | if type=="object" then . else {} end) | to_entries[] | "  - `\(.key)` = `\((.value | if type=="object" then .["runs-on"] else null end) | tostring)`"' 2>/dev/null || true
  printf '\n'
fi

# --- other workflows
# Same tolerance as the required workflow: an unparseable or oddly-shaped
# document is reported and skipped rather than aborting the run.
printf '## Other workflows\n\n'
other_count=0
release_workflow_count=0
if test -d "$workflow_dir"; then
  while IFS= read -r wf_path; do
    test -n "$wf_path" || continue
    test "$wf_path" != "$ci_yml" || continue
    other_count=$((other_count + 1))
    rel="${wf_path#"$repo_root"/}"
    base_name="$(basename "$wf_path")"
    if ! owf="$(yq -o=json -I=0 '.' "$wf_path" 2>/dev/null)" || test -z "$owf"; then
      printf -- '- `%s`: not parseable as YAML\n' "$base_name"
      deviate WF-PARSE "$rel: not parseable as YAML; timeout and pin checks skipped"
      continue
    fi
    ojobs="$(printf '%s' "$owf" | jq -c '(.jobs? // {}) | if type=="object" then . else {} end' 2>/dev/null)" || ojobs=''
    test -n "$ojobs" || ojobs='{}'
    triggers="$(printf '%s' "$owf" | jq -r '.on | if type=="string" then . elif type=="array" then join(", ") elif type=="object" then (keys|join(", ")) else "none" end' 2>/dev/null)" || triggers=''
    printf -- '- `%s`: triggers `%s`\n' "$base_name" "${triggers:-none}"
    if printf '%s' "$owf" | jq -e '.on | if type=="string" then (.=="pull_request" or .=="pull_request_target") elif type=="array" then (index("pull_request")!=null or index("pull_request_target")!=null) elif type=="object" then (has("pull_request") or has("pull_request_target")) else false end' >/dev/null 2>&1; then
      deviate WF-PR-TRIGGER "$rel: only ci.yml may use pull_request or pull_request_target; move this workflow to schedule, push tags, or workflow_dispatch"
    fi
    # `task ci` / `task ci-<lane>` are the PR merge gate: they classify against a PR merge base (absent on a tag or
    # schedule) and are deliberately the fast path. A non-required workflow must call a purpose-named target instead
    # (for example `task release-gate` or `task nightly`) so it does not silently inherit the narrower gate.
    ci_calls="$(printf '%s' "$ojobs" | jq -r '[.[] | (if type=="object" then (.steps? // []) else [] end) | (if type=="array" then . else [] end) | .[] | select(type=="object" and has("run")) | (.run|tostring) | scan("(?:^|[[:space:]&|;(<>`])task[[:space:]]+(ci(?:-[A-Za-z0-9_-]+)?)(?=$|[[:space:]&|;)<>`])") | .[0]] | unique | .[]' 2>/dev/null || true)"
    if test -n "$ci_calls"; then
      deviate WF-TASK-CI "$rel: runs $(printf '%s\n' "$ci_calls" | sed 's/.*/`task &`/' | paste -sd, - | sed 's/,/, /g'); ci and ci-<lane> are the PR merge gate (fast path, classified against a PR merge base) — call a purpose-named Taskfile target such as release-gate or nightly instead"
    fi
    # A tag-push (release) workflow must run `task release-gate`, the repository-owned release gate, so the
    # validation that precedes an immutable release is named, visible, and never silently the fast PR gate.
    if printf '%s' "$owf" | jq -e '.on | type=="object" and (.push | type=="object") and (.push | has("tags"))' >/dev/null 2>&1; then
      release_workflow_count=$((release_workflow_count + 1))
      if ! printf '%s' "$ojobs" | jq -e '[.[] | (if type=="object" then (.steps? // []) else [] end) | (if type=="array" then . else [] end) | .[] | select(type=="object" and has("run")) | (.run|tostring)] | any(test("(?:^|[[:space:]&|;(<>`])task[[:space:]]+release-gate(?:$|[[:space:]&|;)<>`])"))' >/dev/null 2>&1; then
        deviate WF-RELEASE-GATE "$rel: tag-push workflow does not run task release-gate; every release workflow runs the repository's release gate before publishing"
      fi
    fi
    # A job that calls a reusable workflow (`uses:` at job level) cannot carry timeout-minutes; the called workflow owns them.
    missing_timeouts="$(printf '%s' "$ojobs" | jq -r '[to_entries[] | select(.value | (type!="object") or (((.uses|type)!="string" or .uses=="") and .["timeout-minutes"] == null)) | .key] | join(", ")' 2>/dev/null)" || missing_timeouts=''
    if test -n "$missing_timeouts"; then
      deviate WF-TIMEOUT "$rel: jobs missing timeout-minutes: $missing_timeouts"
    fi
    while IFS= read -r uses; do
      test -n "$uses" || continue
      # Local composite actions and docker:// images carry no ref to pin.
      case "$uses" in ./*|docker://*) continue ;; esac
      printf '%s' "$uses" | grep -Eq '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(/[A-Za-z0-9_./-]+)?@[0-9a-f]{40}$' \
        || deviate WF-PIN "$rel: unpinned action $uses"
    done <<< "$(printf '%s' "$ojobs" | jq -r '.[] | (if type=="object" then (.steps? // []) else [] end) | (if type=="array" then . else [] end) | .[] | select(type=="object" and has("uses")) | .uses' 2>/dev/null || true)"
  done <<< "$(find "$workflow_dir" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) -print | sort)"
fi
if test "$other_count" -eq 0; then
  printf -- '- None\n'
fi
printf '\n'

# --- Taskfile and classifier
printf '## Taskfile\n\n'
taskfile="$(find "$repo_root" -maxdepth 1 -type f \( -iname 'taskfile.yml' -o -iname 'taskfile.yaml' \) -print -quit)"
if test -z "$taskfile"; then
  printf -- '- Missing\n'
  deviate TASK-CI-MISSING 'Taskfile.yml: not found; the required workflow runs task ci -- add a Taskfile and copy task ci from the skill asset assets/Taskfile.ci.yml'
  deviate TASK-CHECK-MISSING 'Taskfile.yml: not found; task check is required'
  deviate TASK-DOCS-CHECK-MISSING 'Taskfile.yml: not found; task docs-check is required'
  if test "${release_workflow_count:-0}" -gt 0; then
    deviate TASK-RELEASE-GATE-MISSING 'Taskfile.yml: not found; task release-gate is required because a tag-push workflow exists'
  fi
else
  tasks_json="$(yq -o=json -I=0 '.tasks // {}' "$taskfile" 2>/dev/null)" || tasks_json=''
  case "$tasks_json" in '{'*) ;; *) tasks_json='{}' ;; esac
  has_task() { printf '%s' "$tasks_json" | jq -e --arg t "$1" 'has($t)' >/dev/null 2>&1; }
  for t in ci check docs-check; do
    if has_task "$t"; then printf -- '- `%s`: present\n' "$t"; else printf -- '- `%s`: missing\n' "$t"; fi
  done
  has_task ci || deviate TASK-CI-MISSING "$(basename "$taskfile"): task ci is required; copy it from the skill asset assets/Taskfile.ci.yml"
  has_task check || deviate TASK-CHECK-MISSING "$(basename "$taskfile"): task check is required"
  has_task docs-check || deviate TASK-DOCS-CHECK-MISSING "$(basename "$taskfile"): task docs-check is required"
  if test "${release_workflow_count:-0}" -gt 0; then
    if has_task release-gate; then printf -- '- `release-gate`: present\n'; else printf -- '- `release-gate`: missing\n'; deviate TASK-RELEASE-GATE-MISSING "$(basename "$taskfile"): task release-gate is required because a tag-push workflow exists; copy it from assets/Taskfile.ci.yml and fill in the repository's deep checks"; fi
  fi
  while IFS= read -r job; do
    test -n "$job" || continue
    case "$job" in
      ci-required) ;;
      ci-*) has_task "$job" || deviate TASK-LANE-MISSING "$(basename "$taskfile"): task $job is required by job $job" ;;
    esac
  done <<< "${job_names:-}"
fi
if test -x "$repo_root/scripts/ci-classify.sh"; then
  printf -- '- `scripts/ci-classify.sh`: present\n'
else
  printf -- '- `scripts/ci-classify.sh`: missing\n'
  deviate CLASSIFY-MISSING 'scripts/ci-classify.sh: missing or not executable; copy the skill asset assets/ci-classify.sh to scripts/ci-classify.sh and chmod +x it'
fi
printf '\n'

# --- default-branch rules
# Fails closed: a configured rules source that cannot be read, is empty, or is
# not a JSON array is a tool error (exit 2), never a silent pass. The same goes
# for any gh call in live mode -- an unauthenticated or rate-limited run must
# not be reported as "no rules found".
printf '## Default-branch rules\n\n'
rules_json=""
rules_configured=0
rules_source='not checked (set CI_AUDIT_RULESET=live or CI_AUDIT_RULESET_JSON=<file>)'
legacy_protection='not checked'
legacy_reason=""
gh_failed() { # what, detail
  printf 'error: cannot read %s via gh: %s\n' "$1" "$(printf '%s' "$2" | tr '\n' ' ')" >&2
  exit 2
}
if test -n "${CI_AUDIT_RULESET_JSON:-}"; then
  rules_configured=1
  rules_origin="$CI_AUDIT_RULESET_JSON"
  rules_source="\`$CI_AUDIT_RULESET_JSON\`"
  rules_json="$(cat "$CI_AUDIT_RULESET_JSON" 2>/dev/null)" || {
    printf 'error: cannot read CI_AUDIT_RULESET_JSON: %s\n' "$CI_AUDIT_RULESET_JSON" >&2
    exit 2
  }
elif test "${CI_AUDIT_RULESET:-}" = live; then
  rules_configured=1
  require_command gh
  origin_url="$(git -C "$repo_root" remote get-url origin 2>/dev/null || true)"
  slug="$(printf '%s' "$origin_url" | sed -E 's#^(https://github.com/|git@github.com:)##; s#\.git$##')"
  if test -z "$slug"; then
    printf 'error: cannot read default-branch rules: no origin remote to derive a GitHub slug from\n' >&2
    exit 2
  fi
  rules_origin="live $slug"
  default_branch="$(gh api "repos/$slug" --jq .default_branch 2>&1)" \
    || gh_failed "the default branch of $slug" "$default_branch"
  test -n "$default_branch" || gh_failed "the default branch of $slug" 'empty response'
  rules_json="$(gh api "repos/$slug/rules/branches/$default_branch" 2>&1)" \
    || gh_failed "default-branch rules for $slug" "$rules_json"
  rules_source="live \`$slug\` \`$default_branch\`"
  rules_origin="live $slug $default_branch"
  # A 404 means "not protected"; anything else (403, 401, network) is unknown,
  # and unknown must not read as absent.
  if protection_err="$(gh api --silent "repos/$slug/branches/$default_branch/protection" 2>&1)"; then
    legacy_protection=present
  elif printf '%s' "$protection_err" | grep -q 'HTTP 404'; then
    legacy_protection=absent
  else
    legacy_protection=unknown
    legacy_reason="$(printf '%s' "$protection_err" | tr '\n' ' ')"
  fi
fi
printf -- '- Source: %s\n' "$rules_source"
printf -- '- Legacy branch protection: %s\n' "$legacy_protection"
if test "$rules_configured" -eq 1; then
  printf '%s' "$rules_json" | jq -e 'type=="array"' >/dev/null 2>&1 \
    || { printf 'error: default-branch rules source is empty or not a JSON array: %s\n' "$rules_origin" >&2; exit 2; }
  r() { printf '%s' "$rules_json" | jq -e "$1" >/dev/null 2>&1; }
  r 'any(.[]; .type=="pull_request")' || deviate RULES-PR 'default branch: a pull_request rule is required (no direct pushes)'
  r 'any(.[]; .type=="pull_request" and (.parameters.allowed_merge_methods // []) == ["squash"])' || deviate RULES-SQUASH 'default branch: allowed merge methods must be exactly [squash]'
  r 'any(.[]; .type=="deletion")' || deviate RULES-DELETION 'default branch: deletion must be blocked'
  r 'any(.[]; .type=="non_fast_forward")' || deviate RULES-FF 'default branch: force pushes must be blocked'
  r 'any(.[]; .type=="required_status_checks" and .parameters.strict_required_status_checks_policy==true)' || deviate RULES-STRICT 'default branch: required status checks must be strict (branch up to date)'
  actual_contexts="$(printf '%s' "$rules_json" | jq -c '[.[] | select(.type=="required_status_checks") | .parameters.required_status_checks[]? | .context] | sort' 2>/dev/null)" || actual_contexts=''
  test -n "$actual_contexts" || actual_contexts='[]'
  if test -z "${job_names:-}"; then
    # CI-MISSING already covers this; comparing against no jobs would only add noise.
    printf -- '- Required contexts (from rulesets only): expected unknown (ci.yml missing or unparseable), actual `%s`\n' "$actual_contexts"
  else
    expected_contexts="$(printf '%s\n' "$job_names" | { grep -E '^ci-' || true; } | LC_ALL=C sort | jq -R . | jq -sc .)"
    printf -- '- Required contexts (from rulesets only): expected `%s`, actual `%s`\n' "$expected_contexts" "$actual_contexts"
    test "$expected_contexts" = "$actual_contexts" || deviate RULES-CHECKS "default branch: required status checks must be exactly the ci-* jobs $expected_contexts (actual $actual_contexts)"
  fi
  case "$legacy_protection" in
    present) deviate RULES-LEGACY 'default branch: legacy branch protection is present; the rule checks above read rulesets only, so any protection it enforces (required checks, strict, reviews) is not reflected above. Delete the legacy protection, then apply the ruleset' ;;
    unknown) deviate RULES-LEGACY "default branch: legacy branch protection state unknown (gh returned $legacy_reason); verify and remove it manually" ;;
  esac
fi
printf '\n'

# --- deviations
printf '## Deviations\n\n'
if test -z "$deviations"; then
  printf -- '- None. Repository conforms to the standard.\n'
  exit 0
fi
printf '%s\n' "$deviations"
exit 3
