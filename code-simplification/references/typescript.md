# TypeScript simplification

Use the type system to expose intent, but remember that runtime JavaScript behavior is the contract. Prefer straightforward control flow and domain types over dense expression chains or assertion-heavy code.

## Preserve these semantics

- Preserve runtime values, object identity, mutation, property enumeration, prototype behavior, and serialization.
- Preserve `null`, `undefined`, falsy-value, and missing-property distinctions.
- Preserve promise settlement, microtask ordering, stack and error handling, cancellation conventions, and side effects.
- Preserve getter, proxy, and function call count and ordering; property access is not always inert.
- Preserve emitted JavaScript and module behavior where type-only changes can affect imports, decorators, enums, or transpilation.
- Preserve discriminated-union exhaustiveness and the repository's strictness guarantees; do not replace proof with assertions.
- Respect the package manager, lockfile, TypeScript version, module target, runtime targets, and configured formatter and linter.

## Prefer these moves

- Replace nested branches with guard clauses or an exhaustive `switch` when control flow becomes clearer.
- Name complex boolean expressions and transformations when the names add domain meaning.
- Use discriminated unions and narrowing instead of repeated casts or non-null assertions.
- Extract repeated logic only when its runtime behavior and type relationships are truly the same.
- Remove an `async` wrapper when it owns no error handling and returning the original promise preserves the contract.
- Keep explicit loops when an array chain would create dense callbacks, intermediate allocations, or obscured short-circuiting.

Example:

```typescript
// Before
function getStatusLabel(item: Item): string {
  if (item.status === "new") {
    return "New";
  } else if (item.status === "updated") {
    return "Updated";
  } else if (item.status === "archived") {
    return "Archived";
  } else {
    return "Active";
  }
}

// After
function getStatusLabel(item: Item): string {
  switch (item.status) {
    case "new":
      return "New";
    case "updated":
      return "Updated";
    case "archived":
      return "Archived";
    default:
      return "Active";
  }
}
```

Use an exhaustive assertion instead of `default` only if the current type and runtime contract reject unknown statuses.

## Common semantic traps

| Rewrite | Risk to check |
| --- | --- |
| `value || fallback` instead of `value ?? fallback` | Empty strings, zero, `false`, and `NaN` |
| `value ?? fallback` instead of an explicit check | Missing versus present values and domain-specific sentinels |
| Optional chaining instead of `&&` | Different behavior for non-null falsy intermediates and access count |
| Remove `return await` | Local `try`/`catch` or `finally`, stack traces, and promise behavior |
| Object spread instead of mutation or assignment | Identity, setters, descriptors, symbols, prototypes, enumeration |
| `Map` instead of object or record | Key coercion, ordering, serialization, prototype, equality |
| Array methods instead of a loop | Allocation, short-circuiting, holes, callback side effects, async mistakes |
| `as`, `!`, or `any` to shorten narrowing | Runtime uncertainty hidden from the type checker |
| Merge overloads or union parameters | Inference and caller-facing API behavior |
| Convert `enum` or `const enum` | Emitted code and downstream compilation |
| Change import form | Module loading, side effects, interop, tree shaking |
| Memoize a React value or callback | Referential identity, stale closures, dependency behavior, overhead |

Do not replace type-safe, explicit code with a shorter assertion. A simplification should reduce both runtime and reasoning risk.

## Verify

Use the repository's documented task and package-manager scripts first. Otherwise, select the applicable checks:

1. Use the package manager indicated by the lockfile; do not regenerate or replace the lockfile incidentally.
2. Run the configured formatter and linter on changed files.
3. Run the narrow tests, then the relevant configured suite.
4. Run the repository's type-check command or `tsc --noEmit` with the correct project configuration.
5. Run the build when emitted modules, bundling, declarations, decorators, or framework compilation could change.
6. Exercise supported runtimes or browser targets when the rewrite depends on platform APIs or transpilation.

Retain cases for `null`, `undefined`, falsy values, missing keys, promise rejection, object identity, serialization, and exhaustive unions when relevant.

When Promise ordering matters and no test exists, record labeled events before calls, in callbacks, after `await`, in `catch` or `finally`, and in a queued microtask. Compare the complete event sequence and error identity between the original and candidate.
