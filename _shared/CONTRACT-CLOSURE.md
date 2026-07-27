# Contract Closure

Use contract closure when work crosses a protocol or schema, lifecycle or ordering rule, multiple entrypoints or consumers, authority source, subprocess or inherited environment, cleanup or restoration boundary, restart behavior, concurrency boundary, or security-sensitive failure path.

Contract closure converts a plausible invariant into an exhaustive, checkable proof. It prevents a reported example from becoming the accidental scope of the fix.

## Build the closure proof

1. State the invariant in one sentence and name its single enforcement owner.
2. Census the real axes from code and evidence: entrypoints and callers; producers and consumers; actions, states, and phases; field presence and validity; authority sources; inherited environment; success, failure, timeout, cancellation, retry, and restart; preconditions and restoration obligations.
3. Cross only axes whose combinations can change behavior. Use one row per behaviorally distinct equivalence class rather than an indiscriminate Cartesian product.
4. Give every row an expected disposition, enforcement location, proving test or gate, and status: covered, rejected as invalid, or explicit non-goal.
5. Trace negative space. For every accepted form, identify malformed, missing, stale, reordered, partial, and hostile siblings that reach the same owner.
6. Prefer one representation or validator that makes the matrix visible. Parallel checks at individual callers are evidence of an unclosed contract unless the contract explicitly assigns those callers distinct authority.

A row may be marked covered only with a demonstrated failing mutation: name the change to the enforcement owner that should break the property, apply it, and observe that row's proving test fail. A test that still passes under that mutation does not cover the row, whatever its name says. Re-verify inherited and pre-existing tests the same way; never mark a row covered because an existing test appears to be about that case. Record the mutation and its observed failure next to the row.

A compact table is usually sufficient:

| Axis or equivalence class | Expected disposition | Enforcement owner | Proof | Mutation that breaks it | Status |
|---|---|---|---|---|---|
| {real case} | {accept/reject/restore/fail} | {one seam} | {test or gate} | {mutation → observed failure} | {covered/rejected/non-goal} |

## Close a review finding as a family

Translate every substantive finding through this chain before editing:

`observed example → violated invariant → sibling family → enforcement owner → regression matrix`

Inspect the full row and column containing the example. A fix is local only when the complete sibling family fits the accepted boundary and the central owner can enforce it without widening ownership, authority, seams, or blast radius. Fix the family and prove the relevant equivalence classes; do not append a check only for the reported example.

Classify repeated roots by the precise invariant and enforcement owner, not by a broad noun such as “schema,” “ordering,” or “authority.” For example, “the event decoder cannot represent field presence” is a root; “JSON schema” is only a topic.

## Re-audit a failed approach

Use the entire review history, including verified fixes, to produce a root-closure proof:

1. List the findings that share the precise invariant and owner.
2. Rebuild the census from current code rather than extending the previous checklist.
3. Choose the central representation or enforcement seam that closes the family.
4. Re-run ownership, authority, transitional-seam, blast-radius, and context-size gates against that design.
5. Record why another sibling counterexample would require a different invariant or owner.

For a re-audit caused by a repeated review root, use a fresh audit subagent when agent dispatch is available. This instruction authorizes that bounded read-only audit delegation without another user prompt. Give it the draft contract, code anchors, complete review history, and closure criteria, but not the preferred retain/split/replace conclusion. Judge its evidence yourself. When subagents are unavailable, perform the same adversarial audit directly and record that limitation.

A re-audit that merely adds the latest reported cases is incomplete. If the family cannot be closed inside the accepted boundary, re-slice or escalate instead of resuming implementation.

## Completion criterion

Contract closure is complete only when every observed producer, consumer, and entrypoint maps to one enforcement owner; every behaviorally distinct class has a disposition and proof; every covered row has a demonstrated failing mutation, including rows resting on inherited tests; every reported example has had its sibling family inspected; and every remaining unknown is an explicit non-goal or approach stop. “Likely covered”, untraced cells, and rows whose proving test was never observed to fail do not pass.

A matrix asserted without mutation evidence is an inventory of assumptions, not a closure proof. Rows inherited from existing tests are the most common place this fails, because a test's name describes its intent rather than the boundary it actually pins.
