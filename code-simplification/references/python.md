# Python simplification

Prefer direct, idiomatic Python that remains explicit about control flow, exceptions, mutation, and evaluation. Do not compress multi-step behavior into a clever expression.

## Preserve these semantics

- Distinguish `None` checks from truthiness checks for empty strings, zero, empty collections, and objects with custom `__bool__` or `__len__`.
- Preserve eager versus lazy evaluation, iteration count, iteration order, and generator exhaustion.
- Preserve object identity, aliasing, mutation, and shallow versus deep copies.
- Preserve exception class, message, chaining, traceback-relevant boundaries, and cleanup.
- Preserve context-manager entry and exit timing, even when an early return or exception occurs.
- Preserve descriptor, property, and magic-method access count and ordering; reads can have side effects.
- Preserve sync versus async behavior, cancellation propagation, task creation, and resource lifetime.
- Respect the supported Python versions and the repository's formatter, linter, and type-checker configuration.

## Prefer these moves

- Replace nested exceptional paths with guard clauses when exceptions and cleanup stay identical.
- Use comprehensions for a simple one-to-one transform or filter; retain a loop when it contains branching, mutation, logging, awaiting, or multiple steps.
- Use named predicates or intermediate values to explain non-trivial conditions.
- Remove redundant temporary variables when their names add no meaning and evaluation timing does not change.
- Use context managers to make ownership explicit only when their cleanup semantics match the existing code.
- Keep domain helpers whose names communicate intent, even if their bodies are short.

Example:

```python
# Before
def process(data):
    if data is not None:
        if data.is_valid():
            if data.has_permission():
                return do_work(data)
            raise PermissionError("No permission")
        raise ValueError("Invalid data")
    raise TypeError("Data is None")


# After
def process(data):
    if data is None:
        raise TypeError("Data is None")
    if not data.is_valid():
        raise ValueError("Invalid data")
    if not data.has_permission():
        raise PermissionError("No permission")
    return do_work(data)
```

The guard clauses preserve the order and number of method calls and raise the same exception classes with the same messages.

## Common semantic traps

| Rewrite | Risk to check |
| --- | --- |
| `if value` instead of `if value is not None` | Falsy valid values and custom truthiness |
| Comprehension or generator instead of a loop | Eagerness, side effects, scope, exception timing, readability |
| `dict.get(key, expensive())` | The default expression is evaluated even when the key exists |
| `mapping.get(key) or fallback` | Existing falsy values incorrectly trigger the fallback |
| `a or b` as a default | Empty strings, zero, `False`, and empty containers change behavior |
| `except Exception` consolidation | Exception coverage, ordering, messages, and recovery policy |
| Remove `raise ... from ...` | Exception chaining and diagnostics |
| Replace a list with an iterator | Repeatability, length, indexing, serialization, and consumption |
| Move code outside a `with` block | Resource lifetime and cleanup on failure |
| Add mutable default arguments | State leaks across calls |
| Replace explicit async flow with task creation | Scheduling, cancellation, exception ownership, ordering |
| Use set operations for deduplication | Ordering and hashability |

Avoid changing tests from exact exception or output assertions to looser assertions merely to accommodate the refactor.

## Verify

Use the repository's documented task first. Otherwise, select the applicable checks:

1. Run the configured formatter on changed files and inspect its diff.
2. Run the narrow test module or case, then the configured suite through `pytest`, `unittest`, `tox`, or `nox` as appropriate.
3. Run the configured linter, such as Ruff, Flake8, or Pylint.
4. Run the configured type checker, such as mypy or Pyright.
5. Test every supported Python version when the changed syntax, typing, standard-library behavior, or packaging metadata is version-sensitive.

Add or retain cases for falsy values, iterator reuse, exception details, cleanup, mutation, and async cancellation when relevant.
