# Go simplification

Use Go's ordinary, explicit control flow. A shorter implementation is not simpler when it obscures `nil`, error identity, cleanup, ownership, or concurrency behavior.

## Preserve these semantics

- Distinguish a `nil` slice or map from an allocated empty value when callers, JSON, reflection, equality, or tests can observe it.
- Preserve error identity, concrete type, wrapping, text, and the behavior of `errors.Is` and `errors.As`.
- Preserve `defer` registration order, argument-evaluation time, named-result mutation, and resource lifetime.
- Preserve pointer identity, aliasing, receiver semantics, and whether a value is copied.
- Preserve interface dynamic types, including typed `nil` values stored in non-`nil` interfaces.
- Preserve goroutine creation, channel ownership, close responsibility, blocking, cancellation, and ordering.
- Preserve map-order assumptions only by making ordering explicit; map iteration itself is not stable.
- Respect the module's Go version, build tags, generated-code boundaries, and platform-specific files.

Treat allocation as a preserved behavior when nilness, identity, aliasing, performance requirements, or caller-visible results make it observable. Otherwise, still avoid incidental allocation regressions that buy no clarity.

## Prefer these moves

- Flatten nested failure paths with early returns when the returned values and cleanup timing remain identical.
- Name complex conditions when the name adds domain meaning.
- Extract helpers at responsibility boundaries, not simply to reduce function length.
- Remove pass-through wrappers only after ruling out interface conformance, instrumentation, synchronization, compatibility, and test seams.
- Use standard-library functions when they express the same behavior, including allocation and Unicode or byte semantics.
- Keep simple loops when a generic helper or callback would make control flow less obvious.

Example:

```go
// Before
func loadUser(id string) (*User, error) {
	if id != "" {
		user, err := store.Load(id)
		if err != nil {
			return nil, err
		}
		return user, nil
	}
	return nil, ErrMissingID
}

// After
func loadUser(id string) (*User, error) {
	if id == "" {
		return nil, ErrMissingID
	}

	user, err := store.Load(id)
	if err != nil {
		return nil, err
	}
	return user, nil
}
```

The early return is safe only because it does not move a `defer`, alter error wrapping, or change which calls run.

## Common semantic traps

| Rewrite | Risk to check |
| --- | --- |
| `return []T{}` instead of `return nil` | JSON output, reflection, equality, allocations, caller conventions |
| Collapse `if err != nil` into a helper | Error identity, stack context, deferred cleanup, hidden policy |
| Add or remove `%w` | `errors.Is` and `errors.As` behavior |
| Move a call into `defer` | Arguments may be evaluated at a different time |
| Replace a pointer receiver with a value receiver | Mutation, copies, method sets, interface satisfaction |
| Reuse `:=` in a nested scope | Variable shadowing and returning the wrong value or error |
| Capture range variables or addresses | Go-version-dependent loop semantics, aliasing, copied elements |
| Replace a loop with goroutines | Ordering, cancellation, races, resource limits, partial results |
| Close a channel from a receiver | Panics and ownership violations |
| Convert between `[]byte` and `string` | Allocation, aliasing assumptions, Unicode versus byte behavior |

Do not simplify generated `.go` files directly. Change the generator or source definition and regenerate them.

## Verify

Use the repository's documented task first. Otherwise, select the applicable checks:

1. Run `gofmt` on changed Go files and confirm it introduces no unrelated churn.
2. Run the narrow package tests, then `go test ./...` when repository scope and build requirements permit it.
3. Run `go vet ./...` and the repository's configured linter.
4. Run race tests for changed concurrency-sensitive code when the project supports them.
5. Exercise relevant build tags, platforms, or integration tests when the changed code is gated.

Compare exact error assertions, JSON fixtures, nil-versus-empty cases, concurrency tests, and benchmarks when those behaviors are relevant.
