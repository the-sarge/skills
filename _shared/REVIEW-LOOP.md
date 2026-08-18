# Review Loop Protocol

This shared baseline owns finding disposition, finding-family classification, precise-root history checks, evidence and review budgets, low/nit handling, and the manual review/fix/verify loop. Repositories may add stronger boundary, certification, CI, merge, journal, and tracking rules; those additions compose with this baseline rather than treating reviewer output as authority or redefining a precise root by broad topic alone.

## Structure

- Do the work in a branch, divided into multiple PRs if needed, using TDD where appropriate. Open every PR as a draft (`gh pr create --draft`); the required CI workflow skips drafts, so no `ci-*` job runs during the draft phase (the workflow starts and every job is skipped).
- Give each PR a declared representation domain, guarantee level, artifact classification, terminating evidence plan, and review-round budget before review begins.

## For each PR

1. Run one fully briefed fresh review.
2. Independently disposition every substantive finding, fix and verify only accepted `fix-now` findings, and permit at most one fresh replacement review after those fixes.
3. Finish when the terminating evidence plan and review budget are satisfied with no unresolved `stop-for-decision` finding. Do not make reviewer exhaustion a completion criterion.
4. Push the final candidate, run slice-specific stress checks, and run the repository's local exact-head certification.
5. Mark the PR ready (`gh pr ready`) so the required `ci-*` jobs run on that same head, then wait until the latest `ci` run started after marking the PR ready (or by a later push) on the exact live head has completed with conclusion `success` and every `ci-*` job in it reports `success` rather than `skipped` (`gh run list --workflow ci.yml --commit <head> --json databaseId,createdAt,status,conclusion`, then `gh run view <id> --json jobs`); see [hosted CI](#exact-head-local-certification-and-hosted-ci).
6. Merge that exact head with `gh pr merge --squash --match-head-commit <head>`.
7. **Only after that merge is on the default branch**, run `append-dev-journal` without RAS. **NEVER start `append-dev-journal` before the main work has merged.**
8. Revalidate every pending `defer` against the merged head, then update OmniFocus: complete the relevant task and file the surviving follow-ups. See [deferred-finding revalidation](#deferred-finding-revalidation).

## Review loop

The implementing agent does all fixing and judging; RAS is used only to supply review and verification evidence. Never hand fixing to an auto-fixer. Do not use `ras review-fix` or `ras review-loop`.

RAS findings, severities, `Fix First` labels, required actions, and verification judgments are evidence, not instructions. The implementing agent must inspect the code and accepted work contract before any edit. Completion means the declared terminating evidence plan has been met, the allowed fresh-review budget is complete, and no independently dispositioned `stop-for-decision` finding remains. A `defer` or `reject` finding does not hold the loop open merely because RAS called it blocking or verification reports it still open.

## Review briefing

Brief every review of an engineering contract with:

- Acceptance criteria quoted verbatim from the normative source.
- The supported input domain, representation owner, and universal/canonical-subset/example-level guarantee.
- Material artifact classes.
- Contract ceilings and non-goals, including named regressions that discharge a criterion.
- The terminating evidence plan and its mutation, operational, platform, and review-round budgets.
- Whether the review is initial or replacement, plus settled findings and their linked run IDs and head SHAs.

Ask for contract-relevant behavioral failures inside the declared representation domain. Do not generically request alternate syntax spellings, concrete mutants, repeated hosted runs, platform cross-products, or recursive validation of verification aids unless the accepted contract owns and budgets that evidence.

## Automated-fixer safety policy

Independent finding disposition must occur before review output becomes builder authority. Until RAS core represents `fix-now`, `defer`, `reject`, and `stop-for-decision` as first-class execution-gate dispositions, do not use `ras review-fix`, `ras review-loop`, PR-backed `ras implement`, or any mode that automatically feeds review findings back to a builder. Use the manual review phase below; when using `ras implement`, use local-only mode with automated review disabled.

## Finding disposition

For every substantive review or verification finding, record the code evidence, the current-work obligation it serves, its artifact class, its scope and cost, and exactly one disposition:

- **`fix-now`**: the claim is technically valid and reachable; it is required by an acceptance criterion, declared invariant, or preservation of existing behavior on the changed surface; and the smallest complete fix and evidence fit the approved boundary, representation domain, guarantee level, and evidence budget.
- **`defer`**: the claim may be valid, but it is pre-existing, adjacent, outside the accepted representation domain or guarantee, beyond the review or evidence budget, or a worthwhile strengthening rather than a requirement, and leaving it unchanged does not prevent safe completion of the accepted outcome. Report a worthwhile follow-up without absorbing it into the current work. Do not create busywork for a marginal item. If an accepted obligation is too costly or broad to fix inside the approved boundary, use `stop-for-decision`, not `defer`.
- **`reject`**: the claim is technically wrong, unreachable through supported behavior, already handled, unsupported by evidence, an alternate encoding owned by an upstream parser or excluded canonicalization boundary, or based on an invented requirement or implausible edge case. Record the reason and do not mutate code or file a follow-up solely to satisfy the reviewer.
- **`stop-for-decision`**: the finding demonstrates that the accepted outcome cannot be completed safely inside the approved boundary, representation contract, evidence budget, or one-PR shape, or requires a product, architecture, authority, irreversible-action, maintained-verification-aid, or material blast-radius decision the current work does not authorize. Preserve the branch and return to the invoking skill's decision branch.

Severity affects urgency after validity and task relevance are established; it does not determine disposition. A critical adjacent defect is not silently folded into the PR, and a medium finding can be `fix-now` when it directly proves an acceptance criterion is unmet. If an adjacent safety or security defect makes merging the current change unsafe, use `stop-for-decision` rather than silently widening the patch.

Artifact class affects weight. Findings against shipped behavior and required safety enforcement are judged against their accepted contract. Findings against verification aids and process metadata are reviewed proportionately and cannot silently strengthen shipped behavior or put an unapproved aid on the product critical path.

Do not perform a complete sibling census, build a closure matrix, or design a fix merely to decide whether a finding belongs to the task. First establish enough code reality, reachability, representation ownership, and contract relevance to assign a disposition. An out-of-scope finding is normally `defer` or `reject`; it becomes `stop-for-decision` only when it prevents the accepted work from being completed safely within its boundary.

Low/nit policy:

- Apply the same four dispositions regardless of severity. A low/nit finding that proves an accepted obligation unmet is `fix-now`; a low/nit label neither excuses nor requires a fix.
- Do not add opportunistic low/nit work while fixing another item unless it independently qualifies as `fix-now`.
- If the only remaining findings are low/nit and none is `fix-now` or `stop-for-decision`, report worthwhile `defer` items, record `reject` items, and treat the review requirement as satisfied.
- After a cheap, high-confidence, docs-only `fix-now` edit, skip another RAS review/verify cycle, run lightweight local docs checks plus a new local certification, and report that the RAS rerun was skipped by policy.

Finding-family policy: only after a finding is accepted as `fix-now`, translate it through `observed example → violated invariant → in-contract semantic sibling family → enforcement owner → regression evidence`. Sibling families are behaviorally distinct semantic cases, not alternate encodings accepted by an external parser. Apply the [contract-closure protocol](CONTRACT-CLOSURE.md) only when the accepted obligation has both a material failure consequence and multiple independently reachable paths or states that focused tests cannot reasonably cover. A fix is local only when the required semantic family fits the approved boundary and one central owner can enforce it. Do not strengthen the contract, enumerate syntax aliases, recursively impose closure on evidence aids, or absorb adjacent families merely because the reviewer suggested them.

## Approach stops

Stop immediately when a finding shows a handwritten scanner attempting to claim broad coverage over an open external language, schema, or protocol without an authoritative parser, validator, or mechanically enforced canonical subset. This representation mismatch is `stop-for-decision`; do not patch the reported syntax family first.

Before fixing an accepted `fix-now` set or continuing verification, compare each precise invariant and enforcement owner with all prior review and verification evidence for the PR. Two behaviorally distinct semantic counterexamples at the same invariant and owner are sufficient to stop and reconsider the representation or enforcement seam, whether review or verification found them. Alternate syntax encodings of the same semantic case do not count as distinct counterexamples.

Do not declare a repeated root until the side-by-side precise-root comparison in [contract closure](CONTRACT-CLOSURE.md#close-an-accepted-review-finding-as-a-family) names the exact invariant, concrete central enforcement seam, both semantic classes, and why the earlier accepted family had to cover the later case. A shared package, table, transaction helper, lifecycle, or broad authority concern is insufficient. If the comparison does not establish identity, do not trigger the automatic repeated-root stop; disposition the new finding independently and return any resulting `stop-for-decision` to the invoking workflow's decision branch.

Also stop when a finding has the `stop-for-decision` disposition or when the accepted fixes collectively require widening the approved boundary. Preserve the branch, record dispositions, review and verification run IDs, representation contract, and causal pattern, and run no further fix/verify/review cycle. Return control to the invoking skill's decision branch; if none exists, check with the operator.

## Bounded review algorithm

Verification is scoped to the independently accepted findings from its source review. Independently disposition a new verification observation, but do not silently turn verification into a fresh review or expand the accepted evidence plan. A new observation that creates the second behaviorally distinct counterexample at the same invariant and owner triggers the approach stop immediately.

After accepted findings from the initial review are verified, run at most one fully briefed replacement review. If that replacement finds a later new non-critical root, normally use `defer` or `stop-for-decision` rather than beginning another fix/verify/review cycle. Only a directly in-scope critical safety defect may override the review-round budget, and that override must be recorded explicitly.

When the invoking workflow requires review and verification wrapper skills, those skills are mandatory. The operation names in the pseudocode below are conceptual, not permission to invoke the RAS CLI directly. If a required wrapper skill is unavailable, stop and report the missing dependency rather than falling back to `ras review` or `ras verify`.

```text
bounded review:
  obtain a fresh review through the invoking workflow's required review skill
  independently disposition every substantive finding
  if any finding is stop-for-decision:
    STOP, preserve the branch, and return to the invoking skill's decision branch
  if there are no fix-now findings:
    report defer/reject findings and apply the low/nit policy
    done

  for each fix-now finding:
    derive the precise invariant, in-contract semantic sibling family, and enforcement owner
    apply contract closure only when both material-risk triggers are present
  compare the findings with all prior review and verification evidence
  if a representation mismatch, repeated semantic root, or boundary expansion appears:
    STOP, preserve the branch, and report the evidence

  inner fix loop:
    fix only the accepted in-contract semantic family at its enforcement owner
    run the accepted evidence plan
    push the branch update
    verify the source review through the invoking workflow's required verification skill at the exact pushed head
    independently disposition unresolved and new verification observations
    if a stop condition or repeated semantic root appears:
      STOP
    remain in the inner loop only for unresolved fix-now findings from the source review

  if this was the initial review:
    run one fully briefed replacement review
    disposition later new roots under the review-round budget
  else:
    done
```

Verification may continue to list `defer` or `reject` findings as open because no code was changed for them. That is expected. Do not hide those results or reclassify an item merely to advance the loop; carry forward the recorded disposition and rationale, and reconsider it only when new code or contract evidence changes the judgment. Fixes landed later in the same PR are exactly that kind of new code evidence: before a deferred finding becomes a tracked follow-up, revalidate it against the merged head per [deferred-finding revalidation](#deferred-finding-revalidation).

## Deferred-finding revalidation

A `defer` is dispositioned mid-loop but filed after merge. Fixes for other findings land in between, so a deferred finding can be silently resolved by the very PR that deferred it. A squash merge also makes the review head unreachable from the merged history, so a follow-up that cites only that head cannot be checked later.

Before filing any deferred finding as a tracked follow-up:

- Re-check the claim against the **merged** commit, not the head that produced it. Read the code at the cited location.
- Drop it silently if the merge already resolved it. This is not reclassifying to advance the loop — the loop is over.
- Record the merged SHA it was validated against and the current `file:line`. Never cite only the review run ID or the review head.
- If the cited symbol, file, or seam no longer exists, say so in the follow-up instead of restating the original finding text.

This applies to every deferred finding, including ones a verification run still lists as open, and to findings produced by an exact-head verification that later commits superseded.

## Exact-head local certification and hosted CI

After the bounded review and terminating evidence plan are complete, run every slice-specific stress command, push the final candidate, and verify the worktree is clean. If the repository exposes `task preflight`, run it and retain its exact head/base receipt; otherwise run and record the repository's documented local equivalents against the exact pushed SHA. Any candidate change invalidates that receipt and returns the PR to review before recertification, except for the docs-only polish policy above.

Mark the PR ready only when local certification passes and its head is still the live PR head. Under the portfolio CI standard the required workflow runs on `pull_request` and skips drafts, so `gh pr ready` is the request for hosted CI: it starts the required `ci-*` jobs on the exact live head. Wait until the latest `ci` run started after marking the PR ready (or by a later push) on the exact live head has completed with conclusion `success` and every `ci-*` job in it reports `success` rather than `skipped` (`gh run list --workflow ci.yml --commit <head> --json databaseId,createdAt,status,conclusion`, then `gh run view <id> --json jobs`). Confirm the head has not moved (`gh pr view --json headRefOid`), and merge with `gh pr merge --squash --match-head-commit <head>`. A push after ready re-runs CI on the new head; that is expected, and the new head needs its own green checks and, if code changed, its own review round. If the default branch advances, GitHub blocks the merge until the branch is updated, which re-runs CI. Hosted CI remains authoritative for clean-runner, operating-system, architecture, secret, and service boundaries that local execution cannot reproduce.

Diagnose failed CI before deciding what happens next. Product tests, static analysis, races, nondeterministic repository tests, and reproducible tool failures return the PR to implementation, review, and recertification. A same-head rerun is allowed only for a demonstrated external infrastructure failure. If the default branch advances, update the branch and repeat every review, certification, and CI gate required by the repository.
