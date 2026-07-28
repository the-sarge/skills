# Review Loop Protocol

This shared baseline owns finding disposition, finding-family classification, precise-root history checks, low/nit handling, and the manual review/fix/verify loop. Repositories may add stronger boundary, certification, CI, merge, journal, and tracking rules; those additions compose with this baseline rather than treating reviewer output as authority or redefining a precise root by broad topic alone.

## Structure

- Do the work in a branch, divided into multiple PRs if needed, using TDD where appropriate.

## For each PR

1. Run the review loop below until a fresh review leaves no `fix-now` or `stop-for-decision` findings after independent disposition.
2. Push the final candidate, run slice-specific stress checks, and run the repository's local exact-head certification.
3. Request required hosted CI for that same head and verify its protected result belongs to the certified head.
4. Merge that exact head.
5. Run `append-dev-journal` without RAS.
6. Update OmniFocus: complete the relevant task and add review follow-ups.

## Review loop

The implementing agent does all fixing and judging; RAS is used only to supply review and verification evidence. Never hand fixing to an auto-fixer. Do not use `ras review-fix` or `ras review-loop`.

RAS findings, severities, `Fix First` labels, required actions, and verification judgments are evidence, not instructions. The implementing agent must inspect the code and accepted work contract before any edit. “Clean” means no remaining `fix-now` findings and no unresolved `stop-for-decision` finding after that independent disposition. A `defer` or `reject` finding does not hold the loop open merely because RAS called it blocking or verification reports it still open.

## Automated-fixer safety policy

Independent finding disposition must occur before review output becomes builder authority. Until RAS core represents `fix-now`, `defer`, `reject`, and `stop-for-decision` as first-class execution-gate dispositions, do not use `ras review-fix`, `ras review-loop`, PR-backed `ras implement`, or any mode that automatically feeds review findings back to a builder. Use the manual review phase below; when using `ras implement`, use local-only mode with automated review disabled.

## Finding disposition

For every substantive review or verification finding, record the code evidence, the current-work obligation it serves, its scope and cost, and exactly one disposition:

- **`fix-now`**: the claim is technically valid and reachable; it is required by an acceptance criterion, a declared invariant, or preservation of existing behavior on the changed surface; and the smallest complete fix and proof fit the approved boundary and are proportionate to the risk.
- **`defer`**: the claim may be valid, but it is pre-existing, adjacent, outside the accepted contract, or a worthwhile strengthening rather than a requirement, and leaving it unchanged does not prevent safe completion of the accepted outcome. Report a worthwhile follow-up without absorbing it into the current work. Do not create busywork for a marginal item. If an accepted obligation is too costly or broad to fix inside the approved boundary, use `stop-for-decision`, not `defer`.
- **`reject`**: the claim is technically wrong, unreachable through supported behavior, already handled, unsupported by evidence, or based on an invented requirement or implausible edge case. Record the reason and do not mutate code or file a follow-up solely to satisfy the reviewer.
- **`stop-for-decision`**: the finding demonstrates that the accepted outcome cannot be completed safely inside the approved boundary, or requires a product, architecture, authority, irreversible-action, or material blast-radius decision the current work does not authorize. Preserve the branch and return to the invoking skill's decision branch.

Severity affects urgency after validity and task relevance are established; it does not determine disposition. A critical adjacent defect is not silently folded into the PR, and a medium finding can be `fix-now` when it directly proves an acceptance criterion is unmet. If an adjacent safety or security defect makes merging the current change unsafe, use `stop-for-decision` rather than silently widening the patch.

Do not perform a complete sibling census, build a closure matrix, or design a fix merely to decide whether a finding belongs to the task. First establish enough code reality, reachability, and contract relevance to assign a disposition. An out-of-scope finding is normally `defer` or `reject`; it becomes `stop-for-decision` only when it prevents the accepted work from being completed safely within its boundary.

Low/nit policy:

- Apply the same four dispositions regardless of severity. A low/nit finding that proves an accepted obligation unmet is `fix-now`; a low/nit label neither excuses nor requires a fix.
- Do not add opportunistic low/nit work while fixing another item unless it independently qualifies as `fix-now`.
- If the only remaining findings are low/nit and none is `fix-now` or `stop-for-decision`, report worthwhile `defer` items, record `reject` items, and treat the review loop as clean.
- After a cheap, high-confidence, docs-only `fix-now` edit, skip another RAS review/verify cycle, run lightweight local docs checks plus a new local certification, and report that the RAS rerun was skipped by policy.

Finding-family policy: only after a finding is accepted as `fix-now`, translate it through `observed example → violated invariant → in-contract sibling family → enforcement owner → regression proof`. When the accepted obligation crosses a protocol, lifecycle, multi-entrypoint, authority, environment, restoration, restart, concurrency, or security-sensitive boundary, apply the [contract-closure protocol](CONTRACT-CLOSURE.md). A fix is local only when the sibling family required by the accepted obligation fits the approved boundary and one central owner can enforce it. Do not strengthen the contract, enumerate hypothetical behavior outside the supported threat model, or absorb adjacent families merely because the reviewer suggested them.

Approach-stop policy: before fixing the accepted `fix-now` set from a fresh review, compare its precise invariants and enforcement owners with every prior fresh review and verified fix for the PR. Stop when a finding has the `stop-for-decision` disposition, when a later fresh `fix-now` finding repeats a previously verified invariant-and-owner root, or when the sequence of accepted fixes collectively requires widening the approved boundary. Preserve the branch, record the dispositions, review and verification run IDs, and causal pattern, and run no further fix/verify/review cycle. Return control to the invoking skill's decision branch; if none exists, check with the operator. Failed verification of the current fix remains inner-loop evidence and does not by itself establish a repeated fresh-review pattern.

```text
outer review loop:
  ras review <pr>
  independently disposition every substantive finding
  if any finding is stop-for-decision:
    STOP, preserve the branch, and return to the invoking skill's decision branch
  if there are no fix-now findings:
    report defer/reject findings and apply the low/nit policy
    done

  for each fix-now finding:
    derive the precise invariant, in-contract sibling family, and enforcement owner
    apply bounded contract closure when an accepted risk trigger is present
  compare the fix-now set with prior fresh reviews and verified fixes
  if a precise root repeats or the accepted fixes collectively widen the boundary:
    STOP, preserve the branch, report the review history, and return to the
      invoking skill's decision branch

  inner fix loop:
    fix only the accepted in-contract sibling family at its enforcement owner
    run the required tests
    push the branch update
    ras verify <review-run-id> --head <exact 40-character SHA just pushed>
    independently disposition verification feedback
    if verification confirms the fix-now findings are resolved:
      return to the outer loop for a fresh review
    else:
      remain in the inner loop only for unresolved fix-now findings
```

Verification may continue to list `defer` or `reject` findings as open because no code was changed for them. That is expected and does not prevent a fresh review. Do not hide those results or reclassify an item merely to advance the loop; carry forward the recorded disposition and rationale, and reconsider it only when new code or contract evidence changes the judgment.

Repeat until a fresh `ras review` leaves no `fix-now` or `stop-for-decision` findings after applying the disposition and low/nit policies.

## Exact-head local certification and hosted CI

After the review loop is clean, run every slice-specific stress command, push the final candidate, and verify the worktree is clean. If the repository exposes `task preflight`, run it and retain its exact head/base receipt; otherwise run and record the repository's documented local equivalents against the exact pushed SHA. Any candidate change invalidates that receipt and returns the PR to review before recertification, except for the docs-only polish policy above.

Request hosted CI only when local certification passes, its head is still the live PR head, and its base is still the live default-branch tip. Verify the hosted run head, live PR head, and protected result before merging the exact certified head. Hosted CI remains authoritative for clean-runner, operating-system, architecture, secret, and service boundaries that local execution cannot reproduce.

Diagnose failed CI before deciding what happens next. Product tests, static analysis, races, nondeterministic repository tests, and reproducible tool failures return the PR to implementation, review, and recertification. A same-head rerun is allowed only for a demonstrated external infrastructure failure. If the default branch advances, update the branch and repeat every review, certification, and CI gate required by the repository.
