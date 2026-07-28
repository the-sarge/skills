# Contract Closure

Use contract closure only after an obligation has been accepted as part of the current work and crosses a protocol or schema, lifecycle or ordering rule, multiple entrypoints or consumers, authority source, subprocess or inherited environment, cleanup or restoration boundary, restart behavior, concurrency boundary, or security-sensitive failure path.

Contract closure converts an accepted invariant into a bounded, checkable proof. It prevents a reported example from becoming the accidental scope of the fix without turning the current task into a proof of every conceivable strengthening.

## Bound the contract first

Before building a matrix, state the accepted outcome, the invariant actually required to achieve it, the supported actors and threat model, the declared non-goals, and the proof that terminates the work. Do not use closure to decide whether a review finding belongs to the task; use the review loop's finding-disposition policy first.

The accepted contract is both a floor and a ceiling. Existing behavior on the changed surface still has to be preserved, but pre-existing defects, unsupported inputs, speculative consumers, stronger guarantees, and adjacent families do not enter the matrix unless the accepted work or its safety requires them. If the required family does not fit the approved boundary, return `stop-for-decision`; do not expand the matrix until it appears to fit.

## Build the closure proof

1. State the accepted invariant in one sentence, name its single enforcement owner, and repeat the boundary and terminating proof.
2. Census the real, supported axes that can change the accepted behavior: in-contract entrypoints and callers; producers and consumers; actions, states, and phases; field presence and validity; authority sources; inherited environment; relevant success and failure modes; preconditions and restoration obligations.
3. Cross only axes whose combinations can change behavior. Use one row per behaviorally distinct equivalence class rather than an indiscriminate Cartesian product.
4. Give every row an expected disposition, enforcement location, proving test or gate, and status: covered, rejected as invalid, or explicit non-goal.
5. Trace only the negative space admitted by the accepted contract and threat model. Consider malformed, missing, stale, reordered, partial, and hostile siblings when they are supported, reachable, or necessary to prove the accepted safety property.
6. Prefer one representation or validator that makes the matrix visible. Parallel checks at individual callers are evidence of an unclosed contract unless the contract explicitly assigns those callers distinct authority.

Choose proof depth proportionate to the accepted risk. Every covered row needs demonstrated red/green evidence against the relevant enforcement behavior. Require a targeted mutation of the enforcement owner when the plan or slice calls for mutation proof, when an inherited test is the only evidence, or when ordinary red/green evidence cannot show that the named owner enforces the property. Do not mutation-test unrelated branches merely to satisfy a generic completeness ritual.

For a required mutation, name the change to the enforcement owner that should break the property, apply it, and observe that row's proving test fail. A test that still passes under that mutation does not cover the row, whatever its name says. Record the mutation and its observed failure next to the row.

The mutation must be behavior-changing and discriminating, or the evidence is worthless in one of two directions:

- **A mutation that changes no behavior proves nothing.** Reordering statements with no observable consequence leaves the test correctly passing, which reads as a missing test rather than a sound one. Confirm the mutation is real before concluding a row is uncovered.
- **A mutation that trips several guards proves only that some guard fired.** If corrupting a field also invalidates a checksum covering it, the checksum branch rejects the input and the named guard is never exercised — deleting that guard then leaves the suite green. Isolate the named enforcement: delete the guard itself, or repair the collateral damage so only the guard under test can reject.

Deleting each enforcement branch in turn is usually the most direct audit, because it names the guard rather than guessing at an input that reaches it.

Split a row whose disposition bundles several properties, and mutate each separately. "The barrier fails" may mean the error propagates *and* the owner is poisoned; one mutation proves only one of them.

A compact table is usually sufficient:

| Axis or equivalence class | Expected disposition         | Enforcement owner | Proof          | Mutation when required        | Status                      |
| ------------------------- | ---------------------------- | ----------------- | -------------- | ----------------------------- | --------------------------- |
| {real case}               | {accept/reject/restore/fail} | {one seam}        | {test or gate} | {mutation → observed failure} | {covered/rejected/non-goal} |

## Close an accepted review finding as a family

After a substantive finding has the `fix-now` disposition, translate it through this chain before editing:

`observed example → accepted invariant → in-contract sibling family → enforcement owner → regression proof`

Inspect the row and column containing the example inside the bounded contract. A fix is local only when the sibling family required by the accepted invariant fits the approved boundary and the central owner can enforce it without widening ownership, authority, seams, or blast radius. Fix and prove that family rather than appending a check only for the reported example. Record adjacent or stronger families as non-goals, `defer`, or `stop-for-decision` according to the review-loop policy; do not absorb them.

Classify repeated roots by the precise invariant and enforcement owner, not by a broad noun such as “schema,” “ordering,” or “authority.” For example, “the event decoder cannot represent field presence” is a root; “JSON schema” is only a topic.

## Re-audit a failed approach

Use the entire review history, including verified fixes and recorded dispositions, to produce a root-closure proof:

1. List the findings that share the precise invariant and owner.
2. Rebuild the bounded census from current code rather than extending the previous checklist.
3. Choose the central representation or enforcement seam that closes the family.
4. Re-run ownership, authority, transitional-seam, blast-radius, and context-size gates against that design.
5. Record why another in-contract sibling counterexample would require a different invariant or owner.

For a re-audit caused by a repeated review root, use a fresh audit subagent when agent dispatch is available. This instruction authorizes that bounded read-only audit delegation without another user prompt. Give it the draft contract, code anchors, complete review history, and closure criteria, but not the preferred retain/split/replace conclusion. Judge its evidence yourself. When subagents are unavailable, perform the same adversarial audit directly and record that limitation.

A re-audit that merely adds the latest reported cases is incomplete. If the accepted family cannot be closed inside the approved boundary, re-slice or escalate instead of resuming implementation. Do not re-audit a `defer` or `reject` finding.

## Completion criterion

Contract closure is complete only when every in-contract producer, consumer, and entrypoint maps to one enforcement owner; every behaviorally distinct class admitted by the accepted contract has a disposition and proportionate proof; every row requiring mutation evidence has a demonstrated failing mutation; every accepted example has had its in-contract sibling family inspected; and every remaining relevant unknown is an explicit non-goal or `stop-for-decision`. “Likely covered” and untraced in-contract cells do not pass.

A matrix asserted without demonstrated red/green evidence is an inventory of assumptions, not a closure proof. A row inherited from an existing test requires mutation evidence when that test is the only proof, because the test's name describes its intent rather than the boundary it actually pins.
