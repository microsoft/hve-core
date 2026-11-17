# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Render an audit as a Markdown report or a JSON object."""

from __future__ import annotations

import json
from collections import Counter, defaultdict
from typing import Any

from ._audit import Audit, Finding
from ._discovery import Artifact, relpath
from ._markdown import capped, dash, escape_inline, md_escape, plural, redact_obj, short
from ._rules import (
    CONTROL_ORDER,
    KIND_LABEL,
    KIND_ORDER,
    KNOWN_OTHER_AREAS,
    MAX_SCAN_DEPTH,
    RULES,
    SEV_LABEL,
    SEVERITY_ORDER,
    STATE_CONTRACT_FIELDS,
)

TOOL_NAME = "rpi_tracking_audit"
# raised when a key is renamed or removed, or a value changes meaning
JSON_SCHEMA_VERSION = 1
CONVENTIONS = (
    "the RPI phase skill templates and the `rpi` skill State contract of the hve-core "
    "release that ships this skill; artifacts written by another hve-core version may "
    "differ"
)
NOT_VISIBLE = (
    "whether a person approved a plan or decided a finding, what the agent did outside "
    "the "
    "artifacts, which host or model ran each phase, whether validation commands "
    "actually ran, "
    "git history of the ignored folder"
)


def table(
    headers: list[str],
    rows: list[tuple[Any, ...]],
    max_rows: int,
    more_label: str = "rows",
) -> str:
    """A Markdown table truncated to max_rows."""
    out = [
        "| " + " | ".join(headers) + " |",
        "| " + " | ".join("---" for _ in headers) + " |",
    ]
    for r in rows[:max_rows]:
        out.append("| " + " | ".join(md_escape(c) for c in r) + " |")
    if len(rows) > max_rows:
        out.append("")
        out.append(
            f"... and {len(rows) - max_rows} more {more_label}. "
            "Use --max-rows to show more or --json for the full list."
        )
    return "\n".join(out)


def _iso(value: Any) -> str:
    return value.isoformat() if value else "-"


def render_header(
    audit: Audit, version: str, brief: bool = False, single_path: str | None = None
) -> str:
    """The Item and Value table that opens the report."""
    kinds = Counter(a.kind for a in audit.artifacts)
    kinds_txt = (
        ", ".join(f"{kinds[k]} {KIND_LABEL[k]}" for k in KIND_ORDER if kinds[k])
        or "none"
    )
    rows: list[tuple[str, str]] = []
    if single_path:
        rows.append(("File", single_path))
        rows.append(("Workspace root used for paths", str(audit.root)))
    else:
        tracking = (
            relpath(audit.tracking_root, audit.root) if audit.tracking_root else None
        )
        rows.append(("Workspace", str(audit.root)))
        rows.append(("Tracking folder", tracking or "not found at the root"))
    rows.append(
        (
            "RPI artifacts (current format)",
            f"{len(audit.artifacts)} ({kinds_txt}) in "
            f"{plural(len(audit.tasks), 'task')}",
        )
    )
    if audit.legacy or not brief:
        legacy = (
            f"{len(audit.legacy)} in {plural(len(audit.legacy_tasks), 'task')}"
            if audit.legacy
            else "none"
        )
        rows.append(("Legacy artifacts (retired Task Planner format)", legacy))
    rows.append(("Reference date (--as-of)", audit.as_of.isoformat()))
    rows.append(("HVE Core conventions", CONVENTIONS))
    by_reason: dict[str, list[str]] = {}
    for rule, reason in audit.not_evaluated.items():
        by_reason.setdefault(reason, []).append(rule)
    not_eval = "; ".join(
        "{} ({})".format(
            ", ".join(rules)
            if len(rules) <= 8
            else f"{len(rules)} rules: {capped(rules, 4)}",
            reason,
        )
        for reason, rules in by_reason.items()
    )
    if audit.unreadable:
        rows.append(("Folders that could not be listed", capped(audit.unreadable, 5)))
    if brief:
        if not_eval:
            rows.append(("Rules not evaluated", not_eval))
    else:
        if audit.other_areas:
            areas = ", ".join(
                f"{k} ({v})" for k, v in sorted(audit.other_areas.items())
            )
            rows.append(("Other tracking areas (not audited)", areas))
        states = (
            plural(len(audit.state_files), "file")
            if audit.state_files
            else "none found"
        )
        if audit.bad_states:
            states += (
                f"; {plural(len(audit.bad_states), 'file')} not readable as state "
                "(TK14)"
            )
        rows.append(("Session state files", states))
        rows.append(
            (
                "Symbolic links skipped",
                ", ".join(audit.symlinks) if audit.symlinks else "none",
            )
        )
        if audit.depth_limited:
            rows.append(
                (
                    "Scan depth",
                    f"folders deeper than {MAX_SCAN_DEPTH} levels were not searched "
                    "for nested "
                    "tracking folders",
                )
            )
        rows.append(("Rules not evaluated", not_eval or "none"))
        rows.append(("Not visible to this audit", NOT_VISIBLE))
    rows.append(("Tool", f"{TOOL_NAME} {version}"))
    lines = ["| Item | Value |", "| --- | --- |"]
    lines += [f"| {md_escape(k)} | {md_escape(v)} |" for k, v in rows]
    return "\n".join(lines)


def render_board(audit: Audit, max_rows: int, brief: bool = False) -> str:
    """The task board, the next action per task, and the legacy table."""
    out: list[str] = []
    if not audit.board and not audit.legacy_board:
        return "No RPI tasks found."
    if audit.board:
        if brief:
            rows = [
                (r["slug"], r["state"], r["plan_progress"], r["next"])
                for r in audit.board
            ]
            out.append(
                table(["Task", "State", "Plan", "Next action"], rows, max_rows, "tasks")
            )
        else:
            headers = [
                "Task",
                "State",
                "Phase reached",
                "Plan",
                "Readiness",
                "Execution",
                "Review exec / assessed outcome",
                "Final outcome",
                "Open decisions",
                "Blockers",
                "Undecided RV",
                "Last change",
            ]
            rows = [
                (
                    r["slug"],
                    r["state"],
                    r["phase_reached"],
                    r["plan_progress"],
                    r["readiness"],
                    r["execution"],
                    r["review"],
                    dash(r["final_outcome"]),
                    str(r["open_decisions"]),
                    str(r["blockers"]),
                    str(len(r["undecided"])),
                    _iso(r["last_change"]),
                )
                for r in audit.board
            ]
            out.append(table(headers, rows, max_rows, "tasks"))
            out += ["", "### Next action per task", ""]
            out += [
                f"- **{escape_inline(r['slug'])}**: {escape_inline(r['next'])}"
                for r in audit.board[:max_rows]
            ]
            if len(audit.board) > max_rows:
                out.append(f"- ... and {len(audit.board) - max_rows} more tasks")
    if audit.legacy_board:
        out += ["", "### Legacy tasks (retired Task Planner format, not audited)", ""]
        rows = [
            (
                r["slug"],
                ", ".join(r["kinds"]),
                r["progress"],
                _iso(r["last_change"]),
                r["next"],
            )
            for r in audit.legacy_board
        ]
        headers = ["Task", "Files", "Checklist", "Last change", "Next action"]
        out.append(table(headers, rows, max_rows, "legacy tasks"))
    return "\n".join(out)


def render_attention(audit: Audit, max_rows: int) -> str:
    """Artifacts carrying high or medium findings, most high findings first."""
    per: dict[tuple[str, str], list[Finding]] = {}
    for f in audit.findings:
        if f.severity in ("high", "medium"):
            per.setdefault((f.slug or "(workspace)", f.artifact), []).append(f)

    def order(
        kv: tuple[tuple[str, str], list[Finding]],
    ) -> tuple[int, int, tuple[str, str]]:
        return (-sum(1 for f in kv[1] if f.severity == "high"), -len(kv[1]), kv[0])

    rows = []
    for (slug, art), fs in sorted(per.items(), key=order):
        hi = sum(1 for f in fs if f.severity == "high")
        rows.append(
            (slug, art, str(hi), str(len(fs) - hi), " ".join(f.fid() for f in fs))
        )
    if not rows:
        return "No high or medium findings."
    return table(
        ["Task", "Artifact", "High", "Medium", "Findings"], rows, max_rows, "artifacts"
    )


def render_findings(audit: Audit, max_rows: int, brief: bool = False) -> str:
    """One table per severity; the brief report rolls low and info up per rule."""
    out: list[str] = []
    by_sev: dict[str, list[Finding]] = defaultdict(list)
    for f in audit.findings:
        by_sev[f.severity].append(f)
    for sev in ("high", "medium", "low", "info"):
        fs = by_sev.get(sev, [])
        if not fs:
            continue
        out += [f"### {SEV_LABEL[sev]} ({len(fs)})", ""]
        if brief and sev in ("low", "info"):
            for rule, c in Counter(f.rule for f in fs).most_common():
                arts = plural(
                    len({f.artifact for f in fs if f.rule == rule}), "artifact"
                )
                out.append(
                    f"- **{rule} {RULES[rule].title}**: {plural(c, 'finding')} on "
                    f"{arts}. "
                    f"Fix: {RULES[rule].fix}."
                )
        elif brief:
            rows = [
                (f.fid(), f.artifact, f"{f.rule} {f.detail}. Fix: {RULES[f.rule].fix}")
                for f in fs
            ]
            out.append(table(["#", "Artifact", "Finding"], rows, max_rows, "findings"))
        else:
            rows = [
                (
                    f.fid(),
                    f.rule,
                    f.slug or "-",
                    f.artifact,
                    f"{f.detail}. Fix: {RULES[f.rule].fix}.",
                )
                for f in fs
            ]
            out.append(
                table(
                    ["#", "Rule", "Task", "Artifact", "Finding"],
                    rows,
                    max_rows,
                    "findings",
                )
            )
        out.append("")
    return "\n".join(out).rstrip() or "No findings."


def render_remediation(audit: Audit, brief: bool = False) -> str:
    """Findings grouped by control, then by rule, with why, verify, and fix."""
    by_control: dict[str, dict[str, list[Finding]]] = {c: {} for c in CONTROL_ORDER}
    for f in audit.findings:
        by_control.setdefault(RULES[f.rule].control, {}).setdefault(f.rule, []).append(
            f
        )
    out: list[str] = []
    for control, rules in by_control.items():
        if not rules:
            continue
        out += [f"### {control}", ""]
        ordered = sorted(
            rules.items(), key=lambda kv: min(SEVERITY_ORDER[f.severity] for f in kv[1])
        )
        for rule_id, fs in ordered:
            rule = RULES[rule_id]
            sev_counts = Counter(f.severity for f in fs)
            sev_txt = ", ".join(
                f"{sev_counts[s]} {SEV_LABEL[s].lower()}"
                for s in ("high", "medium", "low", "info")
                if sev_counts[s]
            )
            arts = plural(len({f.artifact for f in fs}), "artifact")
            if brief:
                # the brief findings section lists only high and medium IDs
                shown = [f.fid() for f in fs if f.severity in ("high", "medium")]
                refs = f" Refs: {capped(shown)}." if shown else ""
                fix = rule.fix[0].upper() + rule.fix[1:]
                out.append(
                    f"- **{rule_id} {rule.title}**, {sev_txt} on {arts}. {fix}.{refs}"
                )
            else:
                refs = capped([f.fid() for f in fs])
                out.append(
                    f"- **{rule_id} {rule.title}**, {sev_txt} on {arts}. Why: "
                    f"{rule.why}. "
                    f"Verify: {rule.verify}. Fix: {rule.fix}. Refs: {refs}."
                )
        out.append("")
    return "\n".join(out).rstrip() or "Nothing to remediate."


def artifact_summary(a: Artifact) -> str:
    """One-line summary of an artifact's model for the inventory."""
    m = a.model
    if a.kind == "plan":
        tasks = m.get("tasks", [])
        done = sum(1 for t in tasks if t["checked"])
        critique = m.get("critique_verdict") or (
            "skipped" if m.get("critique_skipped") else "none"
        )
        return (
            f"{done}/{len(tasks)} tasks checked; readiness "
            f"{m.get('readiness') or '?'}; "
            f"critique {critique}; task ID {short(m.get('task_id') or '?', 30)}"
        )
    if a.kind == "changes":
        entries = plural(len(m.get("entries", [])), "entry", "entries")
        return (
            f"status {m.get('status') or '?'}; scope "
            f"{short(m.get('scope_raw') or '?', 25)}; "
            f"{entries}; task ID {short(m.get('task_id') or '?', 30)}"
        )
    if a.kind == "review":
        findings = m.get("findings", [])
        undecided = len([f for f in findings if f["id"] not in m.get("decided", [])])
        execution = "started" if m.get("started") else (m.get("execution") or "?")
        final = "pending" if m.get("final_pending") else m.get("final_outcome")
        scope = "bounded" if m.get("bounded_scope") else "full"
        return (
            f"{execution} / assessed {m.get('outcome') or '?'}; final {final}; "
            f"{plural(len(findings), 'finding')}, {undecided} undecided; scope {scope}"
        )
    if a.kind == "critique":
        findings = plural(len(m.get("finding_ids", [])), "finding")
        return (
            f"verdict {m.get('verdict') or '?'}; execution "
            f"{m.get('execution') or '?'}; {findings}"
        )
    if a.kind == "research":
        return (
            f"readiness {m.get('readiness') or '?'}; disposition "
            f"{m.get('disposition') or '?'}"
        )
    return "-"


def _render_task_inventory(
    slug: str, task: dict[str, list[Artifact]], max_rows: int
) -> list[str]:
    out = [f"### {escape_inline(slug)}", ""]
    rows = [
        (KIND_LABEL[kind], a.rel, a.date_dir or "-", _iso(a.mtime), artifact_summary(a))
        for kind in KIND_ORDER
        for a in task[kind]
    ]
    out.append(
        table(
            ["Kind", "Path", "Date folder", "Modified", "Summary"],
            rows,
            max_rows,
            "artifacts",
        )
    )
    plan = Audit.latest(task, "plan")
    if plan is not None and plan.model["tasks"]:
        prow = []
        # by the heading that encloses the task, so a repeated phase ID (PL3) does not
        # list every task under each copy
        by_phase: dict[int | None, list[dict[str, Any]]] = {}
        for t in plan.model["tasks"]:
            by_phase.setdefault(t["enclosing_line"], []).append(t)
        for p in plan.model["phases"]:
            box = "x" if p["checked"] else " "
            prow.append((f"[{box}] {p['id']}", short(p["title"], 50), "phase", "-"))
            for t in by_phase.get(p["line"], ()):
                box = "x" if t["checked"] else " "
                deps = ", ".join(t["deps"]) or "-"
                prow.append((f"[{box}] {t['id']}", short(t["title"], 50), "task", deps))
        out += [
            "",
            table(["Marker", "Title", "Kind", "Depends on"], prow, max_rows, "items"),
        ]
    review = Audit.latest(task, "review")
    if review is not None and review.model["findings"]:
        rm = review.model
        rrows = [
            (
                f["id"],
                f["severity"] or "-",
                f["title"],
                f["destination"] or "(unrouted)",
                f["final_destination"] or "-",
                short(rm["decisions"].get(f["id"], "undecided"), 30),
            )
            for f in rm["findings"]
        ]
        headers = [
            "Finding",
            "Severity",
            "Title",
            "Proposed destination",
            "Final destination",
            "Decision",
        ]
        out += ["", table(headers, rrows, max_rows, "findings")]
    out.append("")
    return out


def _scalar(value: Any) -> str:
    """A state value for a table cell: collapsed, redacted, and truncated."""
    if isinstance(value, str):
        return dash(short(value, 60))
    if isinstance(value, (int, float)) or value is None:
        return dash(value)
    return short(json.dumps(value), 40)


def render_inventory(audit: Audit, max_rows: int) -> str:
    """Per-task artifacts, plan markers, review findings, then the other inventories."""
    out: list[str] = []
    for slug, task in audit.tasks.items():
        out += _render_task_inventory(slug, task, max_rows)
    for slug, arts in audit.legacy_tasks.items():
        rows = [
            (
                a.legacy,
                a.rel,
                a.date_dir or "-",
                _iso(a.mtime),
                f"{a.model.get('steps_checked', 0)}/{a.model['steps_total']} checklist "
                "items"
                if a.model.get("steps_total")
                else "-",
            )
            for a in arts
        ]
        out += [f"### {escape_inline(slug)} (legacy)", ""]
        out += [
            table(
                ["Kind", "Path", "Date folder", "Modified", "Summary"],
                rows,
                max_rows,
                "files",
            ),
            "",
        ]
    if audit.misnamed:
        out += [
            "### Files in RPI areas not matching the naming convention (not modeled)",
            "",
        ]
        rows = [(rel, area) for rel, area, _, _ in audit.misnamed]
        out += [table(["Path", "Area"], rows, max_rows, "files"), ""]
    if audit.state_files:
        rows = []
        for sf in audit.state_files:
            st = sf.state
            nxt = (
                st.get("next_action")
                if isinstance(st.get("next_action"), dict)
                else None
            )
            nxt_txt = (
                f"{_scalar(nxt.get('phase'))}: {_scalar(nxt.get('action'))}"
                if nxt
                else _scalar(st.get("next_action"))
            )
            rows.append(
                (
                    sf.rel,
                    _scalar(st.get("task_slug")),
                    _scalar(st.get("session_name")),
                    _scalar(st.get("mode")),
                    _scalar(st.get("active_phase")),
                    _scalar(st.get("status")),
                    _scalar(st.get("session_status")),
                    nxt_txt,
                )
            )
        headers = [
            "Path",
            "Task",
            "Session",
            "Mode",
            "Active phase",
            "Task status",
            "Session status",
            "Next action",
        ]
        out += [
            "### Session state files",
            "",
            table(headers, rows, max_rows, "files"),
            "",
        ]
    if audit.other_areas:
        rows = [
            (
                k,
                KNOWN_OTHER_AREAS.get(k, "not an HVE Core area this tool knows"),
                str(v),
            )
            for k, v in sorted(audit.other_areas.items())
        ]
        out += ["### Other tracking areas (not audited)", ""]
        out += [
            table(["Folder or files", "Owner", "Files"], rows, max_rows, "areas"),
            "",
        ]
    if audit.nested:
        out += ["### Nested tracking folders (listed, not read)", ""]
        # in a table, because text at the start of a list item can begin a heading, a
        # quote, or a link definition
        rows = [(n,) for n in audit.nested]
        out += [table(["Folder"], rows, max_rows, "folders"), ""]
    return "\n".join(out).rstrip() or "No RPI artifacts."


def render_method(brief: bool = False) -> str:
    """How the audit works and what it cannot see."""
    if brief:
        return (
            "The audit read the Markdown and JSON files under .copilot-tracking/ and "
            "evaluated "
            "the rules in references/rule-catalog.md, which approximate the RPI "
            "tracking "
            f"conventions in {CONVENTIONS}. Severity is an ordering heuristic, not a "
            "rating. "
            "States and next actions are derived from the artifacts' own fields and "
            "the joined session state, and are "
            "suggestions to confirm. It did not read source code, git history, or chat "
            "transcripts, and cannot tell whether a person approved anything."
        )
    return "\n".join(
        [
            f"- The rules approximate the conventions in {CONVENTIONS}. The sources "
            "are the copilot-tracking instructions and the templates and references of "
            "the RPI skills. Apart from the RPI Workflow canvas's warnings in an open "
            "session, no hve-core script or lint checks tracking files against each "
            "other; the RPI phase skills reconcile them at each handoff.",
            "- Artifacts written by the retired Task Researcher, Task Planner, Task "
            "Implementor, "
            "and Task Reviewer agents are listed as legacy with checklist progress and "
            "are not "
            "audited.",
            "- Severity is a heuristic for ordering work: high means a downstream RPI "
            "phase cannot "
            "navigate the artifact or a secret is exposed; medium means artifacts "
            "disagree in a "
            "way that misleads a resume or bypasses a gate; low is convention; info is "
            "a fact for "
            "the board.",
            "- The newest dated file of each kind is treated as the task's current "
            "artifact. Earlier plans, changes records, and research files are listed "
            "under TK5, and findings on a superseded critique or review are downgraded "
            "to info, except HY1.",
            "- Values matching a credential pattern are replaced with `[redacted ...]` "
            "before any "
            "field is parsed, so neither this report nor the JSON carries them; HY1 "
            "gives the "
            "file and line.",
            "- A task is `accepted` only when its plan and changes record exist, every "
            "plan task is checked, and its latest review covers the full task and "
            "records, in the Parent Decision Record, a final outcome of Conformant or "
            "Conformant with justified divergence; the Executive Summary's assessed "
            "outcome is the reviewer's proposal.",
            "- A session state file is joined to the task of the newest kind of "
            "artifact its artifact_paths name, because later work in a session names "
            "its documents for the work, and otherwise to the task whose task_slug it "
            "records. It also reaches the tasks whose plans, critiques, changes "
            "records, or reviews its documents list; reused research joins nothing.",
            "- Next actions are derived from the artifacts' own status fields and "
            "markers and from the joined session state: `/rpi task=<slug>` leads where "
            "the rpi skill owns the next step. They are suggestions for the user to "
            "confirm, not commands the audit ran.",
            "- Staleness uses file modification time against the reference date; "
            "copying a folder "
            "resets it.",
            "- Not visible: human approval, what happened in chat, which host or model "
            "ran a "
            "phase, whether validation commands ran, and anything outside the tracking "
            "folder.",
        ]
    )


def render_markdown(
    audit: Audit,
    version: str,
    brief: bool = False,
    max_rows: int = 25,
    single_path: str | None = None,
) -> str:
    """The full or brief Markdown report."""
    sev = Counter(f.severity for f in audit.findings)
    known = (
        {a.rel for a in audit.artifacts}
        | {a.rel for a in audit.legacy}
        | {sf.rel for sf in audit.state_files}
    )
    attention = {f.artifact for f in audit.findings if f.severity in ("high", "medium")}
    arts = len(attention & known)
    ws = len(attention - known)
    summary = (
        f"{plural(len(audit.findings), 'finding')}: {sev['high']} high, "
        f"{sev['medium']} medium, "
        f"{sev['low']} low, {sev['info']} info. "
        f"{plural(arts, 'artifact needs attention', 'artifacts need attention')}"
        + (f" plus {plural(ws, 'workspace-level item')}" if ws else "")
        + f". {plural(len(audit.board), 'task')} on the board"
        + (
            f", {plural(len(audit.legacy_tasks), 'legacy task')}"
            if audit.legacy_tasks
            else ""
        )
        + "."
    )
    parts = [
        "# HVE Core RPI tracking audit",
        "",
        render_header(audit, version, brief, single_path),
        "",
        "## Summary",
        "",
        summary,
        "",
        "## Task board",
        "",
        render_board(audit, max_rows, brief),
        "",
        "## Artifacts needing attention",
        "",
        render_attention(audit, max_rows),
        "",
        "## Findings",
        "",
        render_findings(audit, max_rows, brief),
        "",
        "## Remediation plan",
        "",
        render_remediation(audit, brief),
        "",
    ]
    if not brief:
        parts += ["## Inventory", "", render_inventory(audit, max_rows), ""]
    parts += ["## Method and limits", "", render_method(brief), ""]
    return "\n".join(parts)


def _art_json(a: Artifact) -> dict[str, Any]:
    m = dict(a.model)
    for k in ("phases", "tasks"):
        if k in m:
            slim = []
            for item in m[k]:
                entry = {kk: vv for kk, vv in item.items() if kk != "blocks"}
                entry["blocks"] = sorted(item.get("blocks", {}).keys())
                slim.append(entry)
            m[k] = slim
    if "h2" in m:
        m["sections"] = m.pop("h2")
    return {
        "path": a.rel,
        "kind": a.kind,
        "legacy_kind": a.legacy,
        "slug": a.slug,
        "date_dir": a.date_dir,
        "suffix_n": a.suffix_n,
        "modified": a.mtime.isoformat() if a.mtime else None,
        "unrecognized": a.unrecognized,
        "model": redact_obj(m, by_key=True),
    }


def to_json(
    audit: Audit, version: str, single_path: str | None = None
) -> dict[str, Any]:
    """The full audit as a redacted JSON-ready object."""

    def board_row(r: dict[str, Any]) -> dict[str, Any]:
        return dict(
            r, last_change=r["last_change"].isoformat() if r["last_change"] else None
        )

    severities = Counter(f.severity for f in audit.findings)
    # key names here are the audit's own, so only credential-shaped values are redacted
    return redact_obj(
        {
            "schema_version": JSON_SCHEMA_VERSION,
            "tool": {"name": TOOL_NAME, "version": version, "conventions": CONVENTIONS},
            "workspace": str(audit.root),
            "file": single_path,
            "tracking_root": relpath(audit.tracking_root, audit.root)
            if audit.tracking_root
            else None,
            "reference_date": audit.as_of.isoformat(),
            "gitignore_has_tracking": audit.gitignore_has_tracking,
            "nested_tracking_folders": audit.nested,
            "symlinks_skipped": audit.symlinks,
            "scan_depth_limited": audit.depth_limited,
            "other_areas": dict(audit.other_areas),
            "misnamed_files": [{"path": p, "area": a} for p, a, _, _ in audit.misnamed],
            "rules_not_evaluated": dict(audit.not_evaluated),
            "summary": {sev: severities.get(sev, 0) for sev in SEVERITY_ORDER},
            "unreadable_folders": audit.unreadable,
            "invalid_state_files": [
                {"path": p, "reason": r} for p, r in audit.bad_states
            ],
            "board": [board_row(r) for r in audit.board],
            "legacy_board": [board_row(r) for r in audit.legacy_board],
            "findings": [
                {
                    "id": f.fid(),
                    "rule": f.rule,
                    "title": RULES[f.rule].title,
                    "severity": f.severity,
                    "control": RULES[f.rule].control,
                    "task": f.slug,
                    "artifact": f.artifact,
                    "detail": f.detail,
                    "fix": RULES[f.rule].fix,
                }
                for f in audit.findings
            ],
            "artifacts": [_art_json(a) for a in audit.artifacts],
            "legacy_artifacts": [_art_json(a) for a in audit.legacy],
            "state_files": [
                {
                    "path": sf.rel,
                    "task": audit.state_slugs.get(sf.rel),
                    # only the State contract's fields: anything else in the file is not
                    # reported
                    "state": {
                        k: sf.state[k] for k in STATE_CONTRACT_FIELDS if k in sf.state
                    },
                }
                for sf in audit.state_files
            ],
            "rules": {
                k: {"title": v.title, "severity": v.severity, "control": v.control}
                for k, v in RULES.items()
            },
        },
        by_key=False,
    )
