# Portfolio publication policy

Adopted 2026-08-05 (owner decision). Applies to all portfolio repos across the-sarge, GridSwarm, GridCastIO, SwarmCast, and GrainBin. Cross-org private reusable workflows are not possible on GitHub, so the sharing vehicle is this policy plus per-repo copies of the reference implementations, pinned and adapted.

Grounded in a 2026-08-05 survey of the portfolio's live release paths: cpace (hardened, mature), wiremux (dispatch-gated publisher, post-simplification), ras (baseline publisher, designed but never run), codemux/wellspring (manual tag + notes), tapmux/swarmcast/archive-simulator (validation-only `release-check`, no publisher). madmap's TEST-INFRASTRUCTURE §9 (goreleaser prescription) predates all of these, matches none of them, and is superseded by this policy; madmap is stale and must be independently vetted before anything else is built on it.

## Invariants (every tier, every release)

1. **Tags are immutable.** Never moved, never reused, never replaced in place. The publisher fails if a Release already exists for the tag. A wrong published release gets a new patch version, not a rewrite.
2. **Annotated tag, on the default branch.** The publisher verifies the tagged commit is an ancestor of the default branch before doing anything else.
3. **Version numbers are deliberate.** Recorded in CHANGELOG or a release issue before tagging — never inferred from prior tags, especially across architecture rewrites.
4. **Validation at the exact tagged commit.** The repo's merge-gate equivalent (`task check` / `task release-check`) runs green at that commit before publication.
5. **Checksums cover every asset.** A `SHA256SUMS` asset listing every other asset. No assets (library tier) → no checksums needed.
6. **Binaries prove their source.** version/commit/date injected via ldflags; `<binary> --version` (or equivalent) must identify the release commit.
7. **Notes state the boundaries.** User-visible changes, compatibility expectations, and the platform tier of every artifact: **tested** (a CI lane exercised it) vs **build-only** (cross-compiled, never run). Explicit non-claims beat implied support.
8. **Workflow hygiene.** Actions pinned to full commit SHAs; top-level `permissions: contents: read` with per-job escalation; `persist-credentials: false`; timeouts on every job; private-module credentials never exposed to untrusted code.

## Tiers

### Library (default for libraries)

Annotated tag + GitHub Release with notes satisfying invariants 1–4 and 7. No workflow required at all — codemux releases this way today and is compliant. A repo may add a small tag-triggered validation workflow if it wants CI proof at the tag, nothing more.

### Binary-shipping (default for CLIs/servers)

Everything in Library, plus a single-job, tag-push-triggered publisher:

- Trigger: push of an annotated `v*` tag (the tag push is the deliberate operator act; no dispatch ceremony). `workflow_dispatch` on an existing tag allowed as a retry path.
- Flow: verify tag format and default-branch ancestry → run the repo's release gate → cross-build the supported targets → archive as `<name>_<version>_<os>_<arch>.tar.gz` → `SHA256SUMS` → `gh release create --verify-tag`, failing if the release exists.
- Notes from CHANGELOG or a tracked notes file, stating platform tiers (invariant 7).
- **Reference implementation: `SwarmCast/tapmux` `.github/workflows/release.yml` + `docs/runbooks/release.md`** — the proven baseline (first verified release v2.0.0-rc.3). Adapt module path, binary name, target list, and gate decomposition: private-module deploy keys must be scoped to the steps that need them (gate fixtures may require their absence), and aggregate local gate tasks usually decompose into separate CI steps. `the-sarge/ras` contributed the original design and its Homebrew-tap-from-checksums flow remains the optional distribution add-on, but its publisher has never executed — verify it before treating it as reference.
- Prefer draft-create → spot-check → publish for the *first* release of a new major line; steady-state releases publish directly.

### Hardened (opt-in only, security-critical repos)

For repos whose artifacts are themselves security infrastructure (today: cpace only). Adds signed annotated tags verified in CI against checked-in allowed-signers, SBOM + artifact attestation, frozen-candidate evidence bundles. **Reference implementation: `the-sarge/cpace`.** Adoption requires the operator's explicit decision; never propose it as an upgrade.

## Anti-patterns (learned the hard way)

- Multi-job evidence pipelines, digest read-backs, terminal publication records, typed dispatch inputs, exact-asset-set enforcement: wiremux-style machinery. It was over-engineered, caused real frustration, and had to be dramatically simplified. Do not reintroduce it absent a written threat justification.
- goreleaser is acceptable if a repo prefers it, but is not the standard; the portfolio reference is the small hand-rolled publisher already in ras, which fits the Taskfile-centric house style.
- A publisher that has never run (ras today) is design, not evidence. Adoption ends with a real verified release.

## Rollout status

| Repo | Tier | Status (2026-08-05) |
|---|---|---|
| the-sarge/cpace | Hardened | Compliant (reference) |
| the-sarge/ras | Binary | Publisher designed, never run — needs first verified release |
| GridSwarm/wiremux | Binary | Publishing works; over-spec relative to policy; simplify opportunistically, don't rewrite |
| GridSwarm/codemux | Library | Compliant (manual) |
| GridSwarm/keymux | Library | No code yet; adopt at first release |
| GridCastIO/gridcast | Binary | No publisher |
| SwarmCast/tapmux | Binary | Compliant (reference for Binary tier): publisher proven with v2.0.0-rc.3 (2026-08-05); v2.0.0 final pending readiness gates in SwarmCast/tapmux#428. Adoption lessons: keys must be step-scoped or gate fixtures break; aggregate local gate tasks must be decomposed in CI |
| SwarmCast/swarmcast | Binary | Validation-only `release-check`; no publisher |
| GrainBin/wellspring | Library | Manual releases; verify invariants on next release |
| GrainBin/offload | Binary | No publisher |
| GrainBin/archive-simulator | Binary (future) | Validation-only `release-check`; adopt when it ships binaries |
