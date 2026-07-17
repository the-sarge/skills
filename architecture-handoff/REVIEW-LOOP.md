# Review Loop Protocol

The standard per-PR discipline for agent-implemented work in this repo. Implementation plan docs reference this file from their Operating Discipline sections; do not restate it inline.

## Structure

- Do the work in a branch, divided into multiple PRs if needed, using TDD where appropriate.

## For each PR

1. Run the review loop below until a fresh review surfaces no blocking findings.
2. Push the final candidate, run slice-specific stress checks, and run the repository's local exact-head certification.
3. Request required hosted CI for that same head and verify its protected result belongs to the certified head.
4. Merge that exact head.
5. Run `append-dev-journal` without RAS.
6. Update OmniFocus: complete the relevant task and add review follow-ups.

## Review loop

The implementing agent does all fixing and judging; RAS is used only to review and verify. Never hand fixing to an auto-fixer. Do not use `ras review-fix` or `ras review-loop`.

“Clean” means no remaining blocking findings. Low/nit handling is a loop-control policy, not merely a prioritization hint.

Low/nit policy:

- If low/nit findings appear alongside blocking findings, cheap and local low/nit items may be fixed while already editing because another verify/review cycle is required for blockers.
- If the only remaining findings are low/nit and any are not docs-only, leave them out of the current PR, file follow-up issues, report them separately, and treat the review loop as clean for merge-readiness.
- If the only remaining findings are low/nit docs-only findings, fix them only when cheap and supported by very high confidence. After such a docs-only polish fix, skip another RAS review/verify cycle, run lightweight local docs checks plus a new local certification, and report that the RAS rerun was skipped by policy.

Approach-stop policy: before fixing blockers from a fresh review, compare its synthesis with every prior fresh review and verified fix for the PR. Treat any blocker that requires work beyond the approved PR/slice boundary, acceptance criteria, or declared blast radius as an immediate approach-level finding. Also stop when a later fresh blocker is rooted in the same ownership, authority, seam, ordering, schema, or failure-model assumption as a previously verified fix, or when the sequence of otherwise-local blockers collectively requires widening the approved boundary. Preserve the branch, record the review/verification run IDs and causal pattern, run no further fix/verify/review cycle, and check with the operator. Failed verification of the current fix remains inner-loop evidence and does not by itself establish a repeated fresh-review pattern.

```text
outer review loop:
  ras review <pr>
  if the review has no blocking findings:
    apply the low/nit policy above
    done

  compare the blocking synthesis with all prior fresh reviews and verified fixes
  if any blocker crosses the approved PR/slice boundary, or the review history
    shows a repeated root assumption or collective boundary expansion:
      STOP, preserve the branch, report the review history, and check with the operator

  inner fix loop:
    for each blocking synthesis item, first judge whether it is a local fix
      or evidence that the approach is wrong
    if approach-wrong: STOP, reconsider the design, and check with the operator
    fix the blocking items
    optionally fix cheap local low/nit findings in the same area
    run the required tests
    push the branch update
    ras verify <review-run-id> --head <exact 40-character SHA just pushed>
    if verification confirms the blockers are resolved:
      return to the outer loop for a fresh review
    else:
      remain in the inner loop using review and verification feedback
```

Repeat until a fresh `ras review` surfaces no blocking findings after applying the low/nit policy.

## Exact-head local certification and hosted CI

After the review loop is clean, run every slice-specific stress command, push the final candidate, and verify the worktree is clean. If the repository exposes `task preflight`, run it and retain its exact head/base receipt; otherwise run and record the repository's documented local equivalents against the exact pushed SHA. Any candidate change invalidates that receipt and returns the PR to review before recertification, except for the docs-only polish policy above.

Request hosted CI only when local certification passes, its head is still the live PR head, and its base is still the live default-branch tip. Verify the hosted run head, live PR head, and protected result before merging the exact certified head. Hosted CI remains authoritative for clean-runner, operating-system, architecture, secret, and service boundaries that local execution cannot reproduce.

Diagnose failed CI before deciding what happens next. Product tests, static analysis, races, nondeterministic repository tests, and reproducible tool failures return the PR to implementation, review, and recertification. A same-head rerun is allowed only for a demonstrated external infrastructure failure. If the default branch advances, update the branch and repeat every review, certification, and CI gate required by the repository.
