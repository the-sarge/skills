# Rust simplification

Prefer explicit ownership, ordinary control flow, and established crate conventions. Do not trade visible branching for hidden allocation, cloning, coercion, panic, or lifetime complexity.

## Preserve these semantics

- Preserve ownership, borrowing, aliasing, mutation, and whether values are moved, copied, or cloned.
- Preserve drop order, guard lifetime, RAII cleanup, and the point at which resources are released.
- Preserve `Result` and `Option` variants, error types, sources, messages, conversions, and panic behavior.
- Preserve iterator laziness, short-circuiting, item order, side-effect timing, and allocation.
- Preserve static versus dynamic dispatch, trait bounds, auto traits such as `Send` and `Sync`, object safety, and public inference behavior.
- Preserve synchronization, lock scope, atomic ordering, async cancellation, pinning, and task scheduling.
- Respect the crate's MSRV, edition, feature flags, target-specific modules, unsafe invariants, and lint policy.

## Prefer these moves

- Flatten nested failure paths with early returns or clear matching when error conversion and drop timing remain identical.
- Use `?` when it preserves the exact conversion and cleanup semantics and follows local style.
- Replace repeated matches with standard combinators only when the combinator chain is easier to read and has the same evaluation behavior.
- Name complex predicates, state transitions, and lifetime-sensitive scopes.
- Remove unnecessary clones only when the new borrow or move does not expand lifetimes, change APIs, or complicate the code.
- Keep explicit loops when iterator chains would hide mutation, failure, short-circuiting, or async behavior.

Example:

```rust
// Before
fn process(input: Option<&Input>) -> Result<Output, Error> {
    if let Some(input) = input {
        if input.is_valid() {
            return run(input);
        }
        return Err(Error::Invalid);
    }
    Err(Error::Missing)
}

// After
fn process(input: Option<&Input>) -> Result<Output, Error> {
    let input = match input {
        Some(input) => input,
        None => return Err(Error::Missing),
    };

    if !input.is_valid() {
        return Err(Error::Invalid);
    }
    run(input)
}
```

The rewrite preserves the match order, returned variants, method-call count, and borrowed input. Use `let ... else` only when the crate's MSRV supports it and local conventions prefer it.

## Common semantic traps

| Rewrite | Risk to check |
| --- | --- |
| Add `?` | `From` conversion, error type/source/message, and changed cleanup or drop ordering |
| Replace `match` with combinators | Laziness, capture mode, side-effect order, readability, inference |
| Add `.clone()` to satisfy borrowing | Allocation, identity, performance, and hidden ownership confusion |
| Remove a block or binding | Borrow duration, lock duration, and drop order |
| Replace iteration with `collect` | Allocation, eager evaluation, error timing, partial progress |
| Change iterator ordering or parallelize | Side-effect order, determinism, short-circuiting, resource use |
| Replace `Result` with `unwrap` or `expect` | Panic behavior and public failure contract |
| Box a trait or future | Allocation, dynamic dispatch, object safety, `Send` or lifetime bounds |
| Change pattern bindings | Moves versus borrows and partial-move behavior |
| Merge error variants | Matching exhaustiveness, diagnostics, downstream API behavior |
| Narrow an unsafe block syntactically | Safety invariant may still span setup, use, and cleanup |
| Change lock acquisition or guard scope | Deadlocks, contention, atomicity, poisoning, consistency |

Treat `unsafe` code, procedural macros, pin projections, FFI, and concurrency primitives as high-risk surfaces. Simplify them only with an explicit invariant map and targeted evidence.

## Verify

Use the repository's documented task first. Otherwise, select the applicable checks:

1. Run `cargo fmt --check` after formatting the changed Rust files.
2. Run the narrow crate or test target, then the applicable workspace tests.
3. Run the repository's configured Clippy command; use all targets or features only when the project supports that combination.
4. Build relevant feature sets and targets when conditional compilation is involved.
5. Run doctests, examples, compile-fail tests, or public API checks when the changed surface requires them.
6. Run Miri, Loom, sanitizers, or targeted stress tests when the repository uses them for unsafe or concurrent code.

Compare error chains, drop-sensitive tests, allocation or performance benchmarks, feature combinations, and downstream compile behavior when relevant.
