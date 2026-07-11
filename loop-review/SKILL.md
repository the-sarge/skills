---
name: loop-review
description: Get a PR ready for merge in a controlled, agent-in-the-loop review cycle. Runs each PR through a manual `ras review`/`ras verify` loop (the agent does the fixing — never the auto-fixer) before merge.
---

# loop-review

Get a PR ready for merge through a review loop where **you** do the fixing and judging and RAS is used **only** to review and verify.

## Workflow

Run the **review loop** below until a fresh review surfaces no blocking findings.

### The review loop

**You** do all the fixing and judging; RAS is used **only** to review and verify. Never hand fixing to an auto-fixer — do **NOT** use `ras review-fix` or `ras-review-loop`. "Clean" means **no remaining blocking findings**; low/nit findings never hold the loop open.

Low/nit handling is a loop-control policy, not just a prioritization hint. If low/nit findings appear alongside blocking findings, fix cheap and local low/nit items only while another verify/review cycle is already required for blockers. If the only remaining findings are low/nit and any are not docs-only, do not fix them now, even if they look cheap; file follow-up issues and stop the loop. If the only remaining findings are low/nit docs-only findings, fix them only when the edit is cheap and correctness is very high confidence; after that docs-only polish fix, do not run another `ras review`, `ras verify`, or full RAS loop solely for the docs change.

```
outer review loop:
  ras review <pr>
  if the review has no blocking findings:
    apply the low/nit policy above
    done

  inner fix loop:
    for each blocking synthesis item, first judge: is this a local fix, or a
      sign the APPROACH itself is wrong? If approach-wrong, STOP, reconsider
      the design, and check with the user — do not patch around it.
    fix the blocking items
    run the required tests
    push the branch update
    ras verify <review-run-id> --head <exact 40-char SHA you just pushed>
    if verification confirms the blocking items are resolved: return to the
      outer loop (a FRESH ras review, to catch any NEW blocking issues the
      fixes introduced)
    else: stay in the inner fix loop, fixing using BOTH the review and the
      verification feedback
Repeat until a fresh ras review surfaces no blocking findings.
```
