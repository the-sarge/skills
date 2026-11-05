# Implementation practices

## TDD handoff

When the invoking workflow calls for TDD, load the installed `tdd` skill before writing tests and apply it throughout implementation. The accepted plan supplies the pre-agreed seams and evidence budget: report what each seam catches and misses, then proceed without requesting the same approval again. In `planit`, include that agreement in plan approval by its authorized approval owner; in `implement-architecture-slice`, use the accepted slice contract. Missing agreement or a material change to the seams or evidence obligations returns to the invoking workflow's existing planning or re-audit decision path before tests are written.

Work one behavior at a time through red, then green, at those seams, with independent expectations and focused validation. Preserve the accepted evidence budget and behavior-preservation gates. Interface uncertainty may require loading `codebase-design`; it does not authorize reopening settled design or expanding the contract. Refactoring suggestions from review still require the shared finding disposition before implementation.

## PR composition

Load the installed `pr` skill when composing or materially revising the product PR body. Use its concise explanation, observed before/after evidence, reversibility, and blast-radius guidance. Repository templates and the invoking workflow's required issue references, parent and plan pointers, plan commit, slice heading, and closing keywords take precedence over its generic layout. Include issue and PR numbers in visible references.

Choose a visual when it clarifies the change; a small prose-only change need not acquire a diagram. Report only evidence actually obtained, and identify checks not run or unavailable baseline evidence without manufacturing a failing-before result. PR composition does not change acceptance criteria, approval ownership, review, certification, or merge requirements.
