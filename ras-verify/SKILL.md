---
name: ras-verify
description: >-
  Use when Codex needs to run or guide a one-shot `ras verify` of a prior RAS review or consideration run, optionally pinned to a PR head SHA or model profile. Use for requests such as "run ras verify", "verify this review run", "check whether the fixes resolved that RAS review", or "verify this consideration run". Do not use for a complete review/fix/fresh-review loop; use `ras-review-loop` for that.
---

# RAS Verify

Use `ras verify` when the user wants RAS to check whether a changed PR head or local consideration document resolves findings from one prior RAS run.

## Operating Model

`ras verify <run-id>` dispatches by the stored run type. For GitHub PR review runs, it verifies the live PR head against the prior synthesis. For consideration runs, it verifies the current local document in a matching source-aware checkout. The command stores verification artifacts and prints a verification synthesis.

## Before Running

1. Confirm the current directory is the intended git repository.
2. Inspect `git status --short --branch`; `ras verify` warns on dirty checkouts because verifier agents run in detached worktrees and may ignore dirty files that are not committed, pushed, or explicit consideration target/context files.
3. Confirm the prior run id from the user, the previous RAS output, `ras status <run-id> --json`, or `ras serve`.
4. For PR review verification, fetch the pushed PR head and use `--head <40-character-sha>` when the user or workflow needs protection against verifying the wrong commit.
5. For consideration verification, do not pass `--head`; RAS uses stored source metadata and document fingerprints.
6. Check `.ras/config.yaml`, then `~/.config/ras/config.yaml` if verifier agent, model profile, or source identity behavior matters.

## Run Pattern

Verify a prior run:

```bash
ras verify <run-id>
```

Pin PR verification to the pushed head:

```bash
head="$(gh pr view <pr> --json headRefOid --jq .headRefOid)"
ras verify <run-id> --head "$head"
```

Use a model profile when requested:

```bash
ras verify <run-id> --model-profile deep-review
```

Use offline verifier guidance when live URL probes, downloads, or package fetches are inappropriate:

```bash
ras verify <run-id> --offline
```

## Handling Output

Wait for the command to finish and read the final verification synthesis. Do not infer success from silence or from an exit code alone.

While `ras verify` is actively running, monitor that command's own output as the primary progress source. Use `ras status`, `ras show`, `ras report`, or `ras serve` for explicit diagnostics or after verification completes rather than as a polling loop, and do not run cleanup/admin mutations while verification may still own local state.

When reporting back, include the verified run id, PR or consideration target, head SHA when used, whether the verification was clean, unresolved findings, command failures, and where to inspect artifacts with `ras status <run-id> --json`, `ras show <run-id> --json`, `ras report <run-id>`, or `ras serve`.

## Safety Notes

- Do not verify against an unpushed or stale local commit; use the PR head SHA when verification gates a PR update.
- Do not assume unrelated uncommitted local files are visible to verifier agents; commit/push them, include them as consideration context refs, or treat true dirty-workspace verification as outside current `ras verify` behavior.
- Do not run a fresh `ras review` in a manual review loop until verification resolves the prior blocking findings.
- Do not treat consideration verification as applying changes to the caller checkout; it only verifies the current source-aware document state.
- Do not hide verifier failures, missing verifier agents, parse failures, or source identity mismatches.
