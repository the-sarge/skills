# Review Loop Protocol

The standard per-PR discipline for agent-implemented work in this repo.
Implementation plan docs reference this file from their Operating Discipline
sections; do not restate it inline.

## Structure

- Do the work in a branch, divided into multiple PRs if needed, using TDD
  where appropriate.

## For each PR

1. Run the review loop below until a fresh review surfaces no blocking
   findings.
2. Merge.
3. append-dev-journal (do NOT run `ras` for the journal).
4. Update OmniFocus — complete the relevant task and add any follow-up issues
   created during review.

## The review loop

YOU (the implementing agent) do all the fixing and judging; RAS is used ONLY
to review and verify. Never hand fixing to an auto-fixer. Do NOT use
`ras review-fix` or `ras review-loop`.

"Clean" below means NO remaining BLOCKING findings. Low/nit handling is a
loop-control policy, not just a prioritization hint.

Low/nit policy:

- If low/nit findings appear ALONGSIDE blocking findings, you may fix cheap,
  local low/nit items while already editing, because another verify/review
  cycle is already required for blockers.
- If the ONLY remaining findings are low/nit and any are not docs-only, DO
  NOT FIX THEM NOW, even if they look cheap. File follow-up issues, report
  them separately, and treat the review loop as clean for merge-readiness.
- If the ONLY remaining findings are low/nit docs-only findings, you may fix
  them only when they are cheap and you have very high confidence in
  correctness. After such a docs-only polish fix, DO NOT run another
  `ras review`, `ras verify`, or full RAS loop solely for that docs change.
  Run only lightweight local docs checks, then explicitly report that the RAS
  re-run was skipped by policy.

```
outer review loop:
  ras review <pr>
  if the review has no blocking findings:
    apply the low/nit policy above
    done

  inner fix loop:
    for each blocking synthesis item, first judge: is this a local fix, or a
    sign the APPROACH itself is wrong? If approach-wrong, STOP, reconsider
    the design, and check with the operator. Do not patch around it.
    fix the blocking items
    if cheap local low/nit findings are in the same area, you may fix them
    now because blockers already require another verify/review cycle
    run the required tests
    push the branch update
    ras verify <review-run-id> --head <exact 40-char SHA you just pushed>
    if verification confirms the blocking items are resolved: return to the
    outer loop for a FRESH ras review, to catch any NEW blocking issues the
    fixes introduced
    else: stay in the inner fix loop, fixing using BOTH the review and the
    verification feedback
```

Repeat until a fresh `ras review` surfaces no blocking findings after
applying the low/nit policy.
