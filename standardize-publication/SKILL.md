---
name: standardize-publication
description: Apply the portfolio release/publication standard to one repository at a time through read-only audit, tier selection, approval-gated implementation, and a verified first release. Use when asked to add, fix, audit, or standardize a release or publication pipeline, adopt the portfolio publication policy, or prepare a repo's first published GitHub Release.
---

# Standardize Publication

Bring one repository onto the portfolio publication policy in [references/policy.md](references/policy.md). The policy is deliberately minimal: a short invariant list plus the smallest publisher that satisfies it. The most common failure mode in this portfolio is over-engineering, not under-engineering — wiremux's original release machinery had to be ripped out and rewritten after it collapsed under its own ceremony. Bias every decision toward less.

## The simplicity rule (binding)

Machinery beyond the baseline for the repo's tier requires the operator's explicit written justification of the concrete threat it addresses, recorded in the repo. When proposing a plan, the default answer to "should we also add X?" is no. Never propose promotion to a higher tier; the operator chooses tiers.

## Process

### 1. Audit (read-only, no approval needed)

- Identify the repo's tier candidate per the policy: library, binary-shipping, or hardened. Confirm the tier with the operator; never assume hardened.
- Record what exists: release-related workflows, `task release-check`-style gates, tags, existing GitHub Releases and their assets, release docs, CHANGELOG.
- Diff reality against the tier's invariant checklist in the policy. Output a short gap list — one line per gap, no essays.

### 2. Plan (approval-gated)

Propose the smallest change set that closes the gaps: usually one workflow file, one Taskfile target, a short runbook section, and a CHANGELOG. Copy from the tier's reference implementation named in the policy rather than inventing. State explicitly what you are *not* adding. Get operator approval before writing anything.

### 3. Implement

- Follow the repo's own contribution flow (branch, PR, its merge gates).
- Workflow hygiene is non-negotiable even at baseline: actions pinned to full commit SHAs, top-level `permissions: contents: read` with per-job escalation, `persist-credentials: false`, no private-module credentials exposed to untrusted code, timeouts on every job.
- Wire the version/commit/date ldflags so the binary can prove its source.

### 4. Verify with a real release

A publisher that has never run is not evidence (ras shipped a complete publisher that has still never executed). Verify with a real tag — a prerelease or `-rc.1` tag is fine — and confirm: the workflow ran green at the tagged commit, assets and checksums match, notes state the platform tiers, and re-pushing the same tag or re-running cannot replace the published release. Record the run URL and asset digests wherever the repo tracks release evidence.

### 5. Close out

Update the repo's release runbook to describe the steady-state flow (usually: update CHANGELOG → merge → annotated tag on the default branch → push tag → verify run). Note the adoption in the portfolio rollout list at the bottom of the policy file.

## Scope boundaries

- One repository per invocation.
- This skill standardizes publication, not CI; route CI work to standardize-github-ci.
- Version-number choices, tier choices, and first-tag timing are operator decisions. Present facts, recommend once, don't relitigate.
