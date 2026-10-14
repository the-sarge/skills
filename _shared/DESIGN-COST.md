# Design Cost

Design cost is what a reviewer, and every later maintainer, must hold in mind to trust a change. Diff size is a poor proxy for it. Use this reference to compare design options inside a plan or slice, to record rejected design alternatives, and to recognize structural cost in existing code.

This reference guides judgment inside the boundary that the accepted work contract and blast-radius tracing establish. It does not expand that boundary, approve changes to a closed contract, trigger contract closure, or add review-blocking evidence. The shared review-loop and contract-closure policies govern verification scope, finding disposition, and completion.

## Terms

- A **module** is anything with an interface and an implementation: a function, type, package, or slice spanning several of them.
- A module's **interface** is everything a caller must know to use it correctly, including invariants, ordering constraints, error modes, and required configuration.
- A module is **deep** when much behavior sits behind a small interface, and **shallow** when its interface is nearly as complex as its implementation.
- A **seam** is the place where an interface lives.
- An **execution context** is anything that runs independently of its caller: a goroutine, thread, process, queue worker, event loop, timer, or deferred callback.
- An **obligation** is an ordering or consistency fact someone must verify for the design to be correct: what happens when a signal arrives late, when two copies of state disagree, when a flag is read before it is set, or when a format changes while old readers still run.
- A **mechanism** is a construct that creates obligations: a hand-off between execution contexts, lock, channel, deferred or cross-context callback, retry, mailbox, mirrored copy of state, flag, or lifecycle phase. Existing state given a new meaning is a mechanism too; see borrowed invariants below.
- The **accepted work contract** is the outcome, boundary, and non-goals the current plan or slice is approved to deliver. A slice boundary that is still being drafted is not yet part of it.
- A **closed contract** is an interface or behavior the current work has no authority to change: one owned by an upstream project or another team, a public compatibility promise, an accepted ADR, or an explicit non-goal. Anything else the work may change is open, even when changing it has a large blast radius.
- The **state owner** is the module that mutates a piece of state. A **contract owner** is whoever may change a closed contract.
- A **contained design** adds a mechanism beside a module — a side channel, adapter, or hand-off — instead of changing that module's core or a contract.

## Weigh obligations before footprint

Among options the accepted work contract allows, compare in this default order:

1. **Obligations** each option introduces, keeps, and removes. Weigh them by what verifying them takes, not by counting constructs. A hand-off between execution contexts or a mirrored copy of state usually costs more than a lock, and replacing several coupled flags with one lifecycle phase held by the state owner can remove more obligations than it adds.
2. **Contract changes**: public interfaces, persisted or wire formats, defaults, and documented behavior that change, including their migration and mixed-version consistency obligations, weighed by their effect on callers.
3. **Footprint**: files, call sites, and lines.

A smaller footprint rarely offsets an added hand-off, and a wider footprint that removes one is usually the lower-cost design. The order is a default, not arithmetic: when a contract change and an internal mechanism pull in opposite directions, say which way you weighed them and why. Costs that create no obligation, such as blocking a shared execution context, latency, or memory, are still traced in blast radius, and an option that violates an accepted requirement such as non-blocking behavior is excluded before this comparison. Options that would change a closed contract are outside it.

## Concurrency is interface

Every hand-off between execution contexts adds ordering constraints to the interface of both modules. Count them as interface cost. A synchronous path can usually be verified by reading it in order; an asynchronous one also requires reasoning about interleavings, which is harder to make convincingly complete.

- Make each decision in the module that owns the state it changes. When that state is confined to one execution context, such as an event loop, make the decision in that context. State owned by a synchronized module, such as a cache behind a lock, needs no dedicated execution context.
- A worker that must report back carries facts (what happened, and to which generation of the state), not policy (what the owner should do about it).
- When a design keeps a hand-off, note which delivery behaviors apply — late, dropped, coalesced, duplicated, stale after a state change, or arriving after shutdown — and which owner or runtime guarantee makes each safe. A guarantee such as exactly-once delivery discharges the behaviors it excludes. These notes are design analysis; the contract-closure triggers and evidence budgets decide how much testing they need.

## Contained is not deep

A contained design keeps the diff local but usually grows the owning module's interface: a parameter threaded through a constructor, a signal the owner must drain, or a copy of a value the owner must keep in sync.

Apply the deletion test to the side channel itself: would restructuring the state owner make it unnecessary? If so, and the restructure fits the accepted work contract, the restructure is usually the deeper design even when its diff is wider.

## Sketch the owner's design

When the leading option is a contained design, write one paragraph on the owner's design: what the state owner or contract owner would do if the contracts in the way were open — what would move, what would disappear, and which contracts would change. Then:

- If it fits the accepted work contract, compare both in the default order above. Either may win.
- If it would change a closed contract, record it as a rejected alternative with the obligations the contained design adds relative to it.
- If it changes no closed contract but falls outside the accepted work boundary, record it as a rejected alternative with that scope reason. Raise it only where the invoking workflow's existing decision conditions call for it; it never expands the work by itself.

Every rejected alternative records its reason and either a **revisit trigger** — the observable event that would reopen it, such as an upstream release adopting the owner's design, a contract owner accepting a change, the governing ADR being superseded, or the work boundary being widened — or `none: rejected on merit`. Split and merge alternatives follow the same rule and are usually rejected on merit. These are brief planning records, not evidence obligations.

## Borrowed invariants

Giving existing state a new meaning — a nil pointer meaning "not started yet," a zero value meaning "use the default" — saves storage but not obligations: correctness now depends on initialization, reset, and retry order owned elsewhere. Weigh those obligations like any other mechanism; recording them makes them visible, not free. Relying on an invariant the state already guarantees, without giving it a new meaning, adds nothing.

The same holds for an unguarded call that is safe only because of another module's behavior. Record each borrowed invariant next to the code that relies on it, in a comment or in a test that fails when the borrowed fact changes.

## In audits of existing code

When auditing code rather than planning a change, use this reference to recognize structural cost: decisions carried back to a state owner through side channels, state mirrored between an owner and a worker, and borrowed invariants. Report them as candidates. Internal interfaces are open to restructuring in a candidate; the weighing order and the recording rules apply once a specific change is planned.

## Example

Two fixes for the same handshake bug in an upstream networking library. The first, from an outside contributor, detected an operating-system write error on a send-queue worker and signalled the connection loop through a new channel; the maintainer closed it as too complicated. The second, from the maintainer, had the connection loop perform the first full-size writes itself until the outcome was known, and was merged.

In this reference's terms, the first added a hand-off whose late, dropped, and stale-path deliveries each needed analysis, for a small footprint. The second added no hand-off. It changed contracts that were open to the maintainer — a configuration default's meaning and documented behavior — and it added obligations of its own: a helper object created only after the first full-size write, and a borrowed invariant, because padding rules guarantee that write happens before a later unguarded call. The hand-off was the obligation that mattered; synchronous designs are not free.

A downstream fork had chosen the hand-off design for the same bug and listed the synchronous route among rejected alternatives without its own reason or revisit trigger, so the upstream merge had no recorded path back to that decision.
