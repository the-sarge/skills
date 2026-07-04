#!/usr/bin/env python3
"""Build a grilling dossier for one RAS architecture candidate."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path
from typing import Any


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-id", required=True, help="RAS run id")
    parser.add_argument("--candidate-id", required=True, help="Cluster id like C-001 or source id like codex:A-C-003")
    parser.add_argument("--repo", default=".", help="Repository root to run ras from")
    parser.add_argument("--json-file", help="Read ras show JSON from this file instead of invoking ras")
    parser.add_argument("--format", choices=("markdown", "json"), default="markdown")
    return parser.parse_args()


def load_run(args: argparse.Namespace) -> dict[str, Any]:
    if args.json_file:
        return json.loads(Path(args.json_file).read_text())
    raw = subprocess.check_output(
        ["ras", "show", args.run_id, "--json"],
        cwd=args.repo,
        text=True,
        stderr=subprocess.PIPE,
    )
    return json.loads(raw)


def esc(text: Any) -> str:
    return str(text if text is not None else "").strip()


def strip_file_prefix(value: str) -> str:
    return value[5:] if value.startswith("file:") else value


def uniq(values: list[str]) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for value in values:
        if value and value not in seen:
            seen.add(value)
            out.append(value)
    return out


def canonical_items(markdown: str) -> list[dict[str, Any]]:
    section_match = re.search(
        r"## Prioritized Deepening Candidates\s*([\s\S]*?)(?:\n##\s|$)",
        markdown or "",
    )
    section = section_match.group(1) if section_match else ""
    starts = list(re.finditer(r"^(\d+)\.\s+\*\*(.+?)\*\*", section, re.M))
    items: list[dict[str, Any]] = []
    for index, match in enumerate(starts):
        block = section[match.start() : starts[index + 1].start() if index + 1 < len(starts) else len(section)]
        module_match = re.search(r"\*\*Primary module/file:\*\*\s+`([^`]+)`\s*/\s*`([^`]+)`", block)
        strength_match = re.search(r"\*\*Recommendation strength:\*\*\s+(.+?)\s{2,}", block)
        items.append(
            {
                "rank": int(match.group(1)),
                "title": match.group(2).strip(),
                "primary_module": module_match.group(1) if module_match else "",
                "primary_file": module_match.group(2) if module_match else "",
                "strength": strength_match.group(1).strip() if strength_match else "",
                "fields": canonical_fields(block),
                "block": block.strip(),
            }
        )
    return items


def canonical_fields(block: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    matches = list(re.finditer(r"^\s+\*\*([^:]+):\*\*\s+", block, re.M))
    for index, match in enumerate(matches):
        start = match.end()
        end = matches[index + 1].start() if index + 1 < len(matches) else len(block)
        fields[match.group(1).strip()] = re.sub(r"\s+", " ", block[start:end]).strip()
    return fields


def find_cluster(data: dict[str, Any], candidate_id: str) -> dict[str, Any]:
    clusters = data.get("deepening_candidate_clusters") or []
    matches = []
    for cluster in clusters:
        ids = {cluster.get("id"), *(cluster.get("candidate_ids") or [])}
        ids.update(candidate.get("id") for candidate in cluster.get("candidates") or [])
        ids.update(candidate.get("raw_candidate_id") for candidate in cluster.get("candidates") or [])
        if candidate_id in ids:
            matches.append(cluster)
    if len(matches) != 1:
        valid = sorted(str(cluster.get("id")) for cluster in clusters if cluster.get("id"))
        raise SystemExit(
            f"expected exactly one candidate for {candidate_id!r}, found {len(matches)}. "
            f"Valid cluster ids: {', '.join(valid)}"
        )
    return matches[0]


def find_canonical_item(data: dict[str, Any], cluster: dict[str, Any]) -> dict[str, Any] | None:
    for item in canonical_items(data.get("synthesis") or ""):
        if item["primary_module"] == cluster.get("primary_module"):
            return item
    return None


def evidence(cluster: dict[str, Any], canonical: dict[str, Any] | None) -> list[str]:
    values: list[str] = []
    if canonical:
        values.extend(parse_evidence_field(canonical.get("fields", {}).get("Evidence", ""), canonical.get("primary_file", "")))
    values.extend(strip_file_prefix(esc(value)) for value in cluster.get("representative_evidence") or [])
    for candidate in cluster.get("candidates") or []:
        values.extend(strip_file_prefix(esc(value)) for value in candidate.get("evidence") or [])
    return uniq(values)


def parse_evidence_field(field: str, primary_file: str) -> list[str]:
    tokens = re.split(r"[,;]", field.replace("`", ""))
    values: list[str] = []
    last_path = primary_file
    for token in tokens:
        item = token.strip()
        if not item:
            continue
        if item.startswith(":") and last_path:
            item = f"{last_path}{item}"
        else:
            path_match = re.match(r"(.+?)(?::\d+)?$", item)
            if path_match and ("/" in item or item.endswith(".py") or item.endswith(".md")):
                last_path = re.sub(r":\d+$", "", item)
        values.append(item)
    return values


def architecture_notes(cluster: dict[str, Any], canonical: dict[str, Any] | None, repo: str) -> list[dict[str, str]]:
    notes: list[dict[str, str]] = []
    seen: set[tuple[str, str]] = set()
    if canonical:
        canonical_note = esc(canonical.get("fields", {}).get("ADR conflicts", ""))
        if canonical_note:
            record = resolve_architecture_record(canonical_note, repo)
            notes.append(
                {
                    "record": record,
                    "note": canonical_note.replace("`", ""),
                    "classification": classify_record_note(record, canonical_note),
                    "source": "synthesis",
                }
            )
            seen.add((record, canonical_note.replace("`", "")))
    for candidate in cluster.get("candidates") or []:
        for entry in candidate.get("adr_conflicts") or []:
            record = esc(entry.get("adr")) or "Architecture record"
            note = esc(entry.get("note"))
            key = (record, note)
            if key in seen:
                continue
            seen.add(key)
            notes.append(
                {
                    "record": record,
                    "note": note,
                    "classification": classify_record_note(record, note),
                    "source": esc(candidate.get("agent")) or "unknown",
                }
            )
    return notes


def resolve_architecture_record(note: str, repo: str) -> str:
    path_match = re.search(r"(CONTEXT\.md|docs/adr/[^\s`;]+|docs/architecture\.md)", note)
    if path_match:
        return path_match.group(1)
    adr_match = re.search(r"\bADR-(\d{4})\b", note)
    if adr_match:
        adr_dir = Path(repo, "docs", "adr")
        if adr_dir.is_dir():
            matches = sorted(adr_dir.glob(f"{adr_match.group(1)}-*.md"))
            if matches:
                return str(matches[0].relative_to(repo))
        return f"ADR-{adr_match.group(1)}"
    return "Architecture record"


def classify_record_note(record: str, note: str) -> str:
    text = f"{record} {note}".lower()
    if re.search(r"aligns?|supports?|matches?|honou?ring|depends on|preserve|consistent with|fits", text):
        return "Doc alignment"
    if re.search(r"drift|stale|gap|not named|not mention|not a blocker|documentation/layout|additive with|lack of enforced convention|current root modules are intentional", text):
        return "Stale doc / gap"
    if re.search(r"conflict|requires? .*update|requires? .*amend|would need|need .*amend|alter|disallow|flat .*layout|prescribed boundary", text):
        return "Doc tension"
    return "Doc note"


def adjudication(data: dict[str, Any], cluster_id: str) -> dict[str, Any]:
    adjs = [adj for adj in data.get("adjudications") or [] if adj.get("cluster_id") == cluster_id]
    counts = Counter(esc(adj.get("stance")) or "unknown" for adj in adjs)
    dissent = [
        {
            "agent": esc(adj.get("agent")) or "unknown",
            "stance": esc(adj.get("stance")) or "unknown",
            "confidence": esc(adj.get("confidence")) or "unknown",
            "reason": esc(adj.get("reason")),
            "correction": esc(adj.get("correction")),
            "verification": esc(adj.get("verification")),
        }
        for adj in adjs
        if adj.get("stance") != "agree"
    ]
    return {"counts": dict(counts), "dissent": dissent, "total": len(adjs)}


def benefits(cluster: dict[str, Any]) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for candidate in cluster.get("candidates") or []:
        raw = candidate.get("benefits")
        if not isinstance(raw, dict):
            continue
        for key, value in raw.items():
            rows.append({"source": esc(candidate.get("agent")) or "unknown", "kind": esc(key), "text": esc(value)})
    return rows


def canonical_benefit(canonical: dict[str, Any] | None) -> str:
    if not canonical:
        return ""
    return (canonical.get("fields", {}).get("Benefits") or "").replace("`", "")


def action_title(canonical: dict[str, Any] | None, cluster: dict[str, Any]) -> str:
    title = esc(canonical.get("title") if canonical else "")
    known = {
        "Repair Top-Up Package Split": "Split Repair Top-Up Into a Package",
        "Lifecycle Intent Handler Package": "Extract Lifecycle Intent Handlers",
        "Local Inner Adapter Boundary": "Introduce a Local Inner Adapter Boundary",
        "Pure v3 Helper Import-Boundary Governance": "Govern Pure v3 Helper Imports",
        "Geo-Owned v3 Outer Workflow Orchestrator": "Move v3 Outer Workflow Into Geo",
        "Phase A Validation and Compilation Split": "Split Phase A Validation From Compilation",
        "Shared Scheduler Contract Helpers": "Share Scheduler Contract Helpers",
    }
    return known.get(title) or f"Explore {title or cluster.get('primary_module') or cluster.get('id')}"


def build_dossier(data: dict[str, Any], candidate_id: str, repo: str) -> dict[str, Any]:
    cluster = find_cluster(data, candidate_id)
    canonical = find_canonical_item(data, cluster)
    run = data.get("run") or {}
    source = data.get("architecture_source") or {}
    return {
        "run": {
            "id": run.get("id"),
            "status": run.get("status"),
            "head_sha": run.get("head_sha"),
            "context_shape": run.get("context_shape"),
            "delivery_mode": run.get("delivery_mode"),
            "synthesis_artifact_id": run.get("synthesis_artifact_id"),
        },
        "candidate": {
            "id": cluster.get("id"),
            "input_id": candidate_id,
            "canonical_rank": canonical.get("rank") if canonical else None,
            "synthesis_title": canonical.get("title") if canonical else None,
            "action_title": action_title(canonical, cluster),
            "primary_module": cluster.get("primary_module"),
            "primary_file": cluster.get("primary_file"),
            "recommendation_strength": cluster.get("recommendation_strength"),
            "source_agents": cluster.get("sources") or [],
            "source_candidate_ids": cluster.get("candidate_ids") or [],
            "problem": cluster.get("representative_problem"),
            "solution": cluster.get("representative_solution"),
            "canonical_synthesis_block": canonical.get("block") if canonical else "",
        },
        "evidence_paths": evidence(cluster, canonical),
        "canonical_benefits": canonical_benefit(canonical),
        "benefits": benefits(cluster),
        "architecture_record_notes": architecture_notes(cluster, canonical, repo),
        "adjudication": adjudication(data, cluster.get("id")),
        "source_candidates": cluster.get("candidates") or [],
        "coverage_notes": data.get("architecture_coverage") or [],
        "warnings": [
            f"dirty_summary: {source.get('dirty_summary')}" if source.get("dirty_summary") else "",
            *[
                f"{agent.get('round')} {agent.get('agent')}: {agent.get('status')}{' - ' + agent.get('error') if agent.get('error') else ''}"
                for agent in data.get("agent_runs") or []
                if agent.get("status") != "complete" or agent.get("error")
            ],
        ],
        "architecture_records": {
            "docs_adr_exists": Path(repo, "docs", "adr").is_dir(),
            "auto_context_refs": source.get("auto_context_refs") or [],
        },
    }


def render_markdown(dossier: dict[str, Any]) -> str:
    candidate = dossier["candidate"]
    run = dossier["run"]
    lines = [
        f"# RAS Candidate Dossier: {candidate['id']}",
        "",
        f"- Run: `{run['id']}`",
        f"- Run status: `{run['status']}`",
        f"- HEAD: `{run['head_sha']}`",
        f"- Candidate: `{candidate['id']}`",
        f"- Canonical rank: `{candidate['canonical_rank']}`",
        f"- Synthesis title: {candidate['synthesis_title']}",
        f"- Action title: {candidate['id']}: {candidate['action_title']}",
        f"- Strength: {candidate['recommendation_strength']}",
        f"- Primary module: `{candidate['primary_module']}`",
        f"- Primary file: `{candidate['primary_file']}`",
        f"- Source agents: {', '.join(candidate['source_agents']) or 'none'}",
        f"- Source candidate IDs: {', '.join(candidate['source_candidate_ids']) or 'none'}",
        "",
        "## Problem",
        esc(candidate["problem"]),
        "",
        "## Solution Direction",
        esc(candidate["solution"]),
        "",
        "## Canonical Synthesis Block",
        candidate["canonical_synthesis_block"] or "Not found.",
        "",
        "## Evidence Paths",
    ]
    lines.extend(f"- `{path}`" for path in dossier["evidence_paths"])
    lines.extend(["", "## Structured Benefits"])
    if dossier["canonical_benefits"]:
        lines.append(f"- **synthesis**: {dossier['canonical_benefits']}")
    if dossier["benefits"]:
        lines.extend(f"- **{row['kind']}** ({row['source']}): {row['text']}" for row in dossier["benefits"])
    elif not dossier["canonical_benefits"]:
        lines.append("- None recorded.")
    lines.extend(["", "## Architecture Record Notes"])
    if dossier["architecture_record_notes"]:
        for note in dossier["architecture_record_notes"]:
            lines.append(f"- **{note['classification']}** `{note['record']}` ({note['source']}): {note['note']}")
    else:
        lines.append("- None recorded.")
    if not dossier["architecture_records"]["docs_adr_exists"]:
        lines.append("- No `docs/adr/` directory detected. Architecture records may be `CONTEXT.md`, `docs/architecture.md`, or app-specific design docs.")
    lines.extend(["", "## Adjudication"])
    counts = dossier["adjudication"]["counts"]
    lines.append("- Counts: " + (", ".join(f"{key}={value}" for key, value in counts.items()) or "none"))
    lines.append(f"- Total: {dossier['adjudication']['total']}")
    lines.extend(["", "## Dissent And Corrections"])
    if dossier["adjudication"]["dissent"]:
        for item in dossier["adjudication"]["dissent"]:
            lines.append(f"- **{item['agent']}** `{item['stance']}` / `{item['confidence']}`")
            if item["reason"]:
                lines.append(f"  - Reason: {item['reason']}")
            if item["correction"]:
                lines.append(f"  - Correction: {item['correction']}")
            if item["verification"]:
                lines.append(f"  - Verification: {item['verification']}")
    else:
        lines.append("- None recorded.")
    lines.extend(["", "## Coverage Notes"])
    for coverage in dossier["coverage_notes"]:
        lines.append(f"- **{coverage.get('agent', 'unknown')}**")
        for note in coverage.get("coverage_notes") or []:
            lines.append(f"  - {note}")
    lines.extend(["", "## Warnings"])
    warnings = [warning for warning in dossier["warnings"] if warning]
    if warnings:
        lines.extend(f"- {warning}" for warning in warnings)
    else:
        lines.append("- None recorded.")
    return "\n".join(lines) + "\n"


def main() -> int:
    args = parse_args()
    data = load_run(args)
    dossier = build_dossier(data, args.candidate_id, args.repo)
    if args.format == "json":
        print(json.dumps(dossier, indent=2, sort_keys=True))
    else:
        print(render_markdown(dossier))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
