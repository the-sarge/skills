# Contract Closure

Contract closure creates proportionate evidence for a materially risky invariant. It is not a completeness proof and must not attempt to establish exhaustiveness by enumerating examples. Reserve “proof” for a genuinely finite or formally modeled state space.

Use contract closure only after an obligation has been accepted as part of the current work and both conditions below are true:

- Failure has a material consequence, such as a security-boundary or authority leak, data loss, irreversible state, public compatibility break, concurrency corruption, or broken lifecycle, restart, cleanup, or restoration obligation.
- The invariant has multiple independently reachable paths or states that ordinary focused tests cannot reasonably cover.

Routine ordering changes, schemas, multiple callers, or multiple consumers do not trigger closure by themselves. Record “not triggered” and use ordinary focused tests unless the accepted contract explicitly establishes both conditions.

## Classify artifacts before assigning evidence

Classify every material artifact in the plan or slice:

- **Shipped behavior** — runtime behavior or user-visible capability.
- **Required safety enforcement** — code or configuration that directly enforces an accepted safety invariant.
- **Verification aid** — tests, analyzers, fixtures, mutation harnesses, CI checks, and diagnostic infrastructure.
- **Process or traceability metadata** — plans, receipts, mirrors, journal entries, and status records.

A verification aid may block shipped work only when the user-approved outcome explicitly makes it a maintained deliverable and states its operational payoff, supported domain, owner, and retirement policy. Otherwise keep it off the product critical path, review it proportionately, and do not let incompleteness in the aid recursively strengthen the shipped contract.

## Pass the representation gate

Before building a matrix, state:

- The supported input domain.
- The trusted representation owner.
- Whether the guarantee is **universal**, **canonical-subset**, or **example-level**.
- The finite evidence that terminates the task.

Do this explicitly for acceptance criteria containing universal quantifiers such as “all,” “every,” “never,” or “exactly.” Do not infer that every representation accepted by a third-party parser belongs to the changed implementation's contract.

When an invariant ranges over an external language, schema, or protocol, claim broad coverage only when an authoritative parser or validator owns the representation or a mechanically enforced canonical subset is checked before semantic validation. If neither is true, choose one of these outcomes before implementation:

- Use an authoritative parser or validator, then test semantic behavior.
- Define and mechanically enforce a canonical subset, then test semantic behavior inside it.
- Narrow the guarantee to example-level regression coverage without claiming universal enforcement.
- Return `stop-for-decision`.

A handwritten scanner that claims broad coverage of an open external grammar is a representation mismatch and immediately returns `stop-for-decision`. Do not patch the reported syntax family first or approximate parser completeness through mutation examples.

## Bound the contract

State the accepted outcome, the invariant required to achieve it, the supported actors and threat model, the artifact classes, the declared non-goals, the supported input domain, the representation owner, the guarantee level, and the terminating evidence plan. Do not use closure to decide whether a review finding belongs to the task; use the review loop's finding-disposition policy first.

The accepted contract is both a floor and a ceiling. Existing behavior on the changed surface still has to be preserved, but pre-existing defects, unsupported inputs, speculative consumers, stronger guarantees, and adjacent families do not enter the matrix unless the accepted work or its safety requires them. If the required family does not fit the approved boundary, return `stop-for-decision`; do not expand the matrix.

## Build the coverage argument

1. State the accepted invariant in one sentence, name its single enforcement owner, and repeat the boundary, representation contract, artifact class, and terminating evidence plan.
2. Census the real, supported semantic axes that can change the accepted behavior: in-contract entrypoints and callers; producers and consumers; actions, states, and phases; field presence and validity; authority sources; inherited environment; relevant success and failure modes; preconditions; and restoration obligations.
3. Cross only axes whose combinations can change behavior. Use one row per behaviorally distinct semantic equivalence class rather than an indiscriminate Cartesian product.
4. Give every row an expected disposition, enforcement location, evidence, and status: covered, rejected as invalid, or explicit non-goal.
5. Trace only the negative space admitted by the accepted contract and threat model. Consider malformed, missing, stale, reordered, partial, and hostile siblings only when they are supported, reachable, or necessary to demonstrate the accepted safety property.
6. Prefer one semantic representation or enforcement owner that makes the matrix visible. Parallel checks at individual callers are evidence of an unclosed contract unless the accepted contract explicitly assigns distinct authority.

Sibling families are behaviorally distinct semantic cases, not alternate encodings accepted by an external parser. Syntax aliases belong to the authoritative parser or mechanically enforced canonicalization boundary. Treat syntax spellings as separate rows only when the changed implementation owns that syntax.

A compact table is usually sufficient:

| Semantic axis or equivalence class | Expected disposition | Enforcement owner | Evidence | Guard mutation when required | Status |
| --- | --- | --- | --- | --- | --- |
| {real case} | {accept/reject/restore/fail} | {one seam} | {test or gate} | {mutation → observed failure, or n/a} | {covered/rejected/non-goal} |

## Budget evidence

Choose evidence depth proportionate to accepted risk. Default to:

- One representative positive case per semantic behavior.
- One representative negative case per materially different failure mode and supported enforcement owner.
- At most one guard-deletion or guard-bypass mutation per enforcement owner.
- No syntax-variant mutations unless the changed implementation owns that syntax or its canonicalization boundary.
- No additional adversarial, fuzz, platform, timing, or repetition scope without explicit approval.

Use mutation testing only when deleting or bypassing a central enforcement guard is the clearest way to show that an existing test exercises that guard. It is especially useful when inherited coverage is the only evidence. Name the changed guard and observe the accepted test fail. Do not mutate external input syntax to approximate parser conformance, mutation-test unrelated branches for completeness, or require a mutation for every matrix row.

The mutation must be behavior-changing and discriminating. Deleting the named enforcement branch is usually more useful than corrupting an input that may trip a different guard. If collateral validation masks the owner under test, isolate the named enforcement or do not claim the mutation as evidence.

Do not apply closure recursively to tests, fixtures, mutation harnesses, analyzers, or validation infrastructure. Harness completeness becomes its own closure obligation only when the user-approved outcome explicitly makes that harness a maintained deliverable and declares its supported representation domain.

Operational and platform evidence has the same finite boundary:

- Expand platforms only where behavior can materially differ or the accepted support contract requires them.
- Require repeated-run counts to answer an explicit statistical question or respond to prior instability, an incident, an SLO, or an external certification requirement.
- Require exact timing-boundary demonstrations only for an accepted product or operational deadline contract.
- For platform or security-fixture matrices, identify which cells are semantic distinctions and which are redundant encodings or environments.

“More confidence” is not a terminating criterion. Additional repetition, platforms, hosted experiments, timing demonstrations, or fixture cross products require an explicit approved evidence scope.

## Close an accepted review finding as a family

After a substantive finding has the `fix-now` disposition, translate it through this chain before editing:

`observed example → accepted invariant → in-contract semantic sibling family → enforcement owner → regression evidence`

Inspect the row and column containing the example inside the bounded contract. A fix is local only when the semantic sibling family required by the accepted invariant fits the approved boundary and the central owner can enforce it without widening ownership, authority, seams, or blast radius. Fix and demonstrate that family rather than appending a check only for the reported example. Record representation aliases, adjacent families, and stronger guarantees as parser-owned, non-goals, `defer`, or `stop-for-decision` according to the review-loop policy; do not absorb them.

Classify repeated roots by the precise invariant and enforcement owner, not by a broad noun such as “schema,” “ordering,” or “authority.” Two behaviorally distinct semantic counterexamples at the same invariant and owner indicate an approach failure; alternate encodings of one semantic case do not create distinct roots.

## Re-audit a failed approach

Use the relevant review and verification history to rebuild the coverage argument rather than extending the latest example list:

1. List the findings that share the precise invariant and owner, regardless of whether review or verification found them.
2. Re-run the representation gate and rebuild the bounded semantic census from current code.
3. Choose the central representation or enforcement seam that covers the accepted family.
4. Re-run ownership, authority, transitional-seam, blast-radius, artifact, evidence-budget, and context-size gates against that design.
5. Record why another in-contract semantic counterexample would require a different invariant or owner.

A re-audit that merely adds reported cases is incomplete. If the accepted family cannot be covered inside the approved boundary and evidence budget, re-slice or escalate instead of resuming implementation. Do not re-audit a `defer` or `reject` finding.

## Keep contracts and tracking bounded

The normative contract contains only the current outcome, boundaries, invariants, acceptance evidence, blockers, and stop conditions. Update it in place. Keep review chronology, run IDs, historical candidate SHAs, verification receipts, and superseded findings in linked audit artifacts or PR discussion.

Give every dispatchable slice a context budget. An implementer receives the current slice contract, referenced invariants, relevant unresolved history, and a bounded governing diff when the contract changed. Do not require duplicate complete historical plan versions.

Keep parent issues, program trackers, and task-manager mirrors pointer-based: stable identity, current state, blockers or frontier, and a pointer to the normative contract. Reconcile current state in place rather than appending superseded narratives. Exact code-head certification remains separate from plan-version and administrative mirror state; do not require mirror-wide SHA agreement as a merge gate.

For a program created under older closure rules:

1. Freeze new dispatch without discarding completed product work.
2. Classify obligations by artifact type, accepted risk, and current product necessity.
3. Preserve shipped behavior and required safety enforcement.
4. Demote or remove recursive, obsolete, duplicated, proof-only, or disproportionate evidence obligations without treating removal as a product regression.
5. Move audit history behind links, collapse mirrors to current state and pointers, and recompute the real implementation frontier.
6. Publish one concise replacement contract and an explicit disposition ledger for removed obligations.

## Completion criterion

Contract closure is complete when the declared terminating evidence plan is satisfied: every in-contract producer, consumer, and entrypoint maps to one enforcement owner; every behaviorally distinct semantic class admitted by the accepted contract has a disposition and proportionate evidence; required guard mutations have demonstrated a failing test; every accepted example has had its in-contract semantic sibling family inspected; and every remaining relevant unknown is an explicit non-goal or `stop-for-decision`.

Completion does not require enumerating every representation alias, recursively validating the validation harness, exhausting reviewer creativity, or adding evidence beyond the approved budget.
