# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Builders for synthetic .copilot-tracking/ workspaces in the current RPI format."""

from __future__ import annotations

import json
from datetime import date
from pathlib import Path
from typing import Any

from rpi_tracking_audit._audit import Audit

AS_OF = date(2026, 10, 25)
DAY = "2026-10-20"
T = ".copilot-tracking"


def plan_text(
    slug: str = "alpha",
    tasks: tuple[tuple[str, bool], ...] = (("P01-T01", True), ("P01-T02", True)),
    phase_checked: bool | None = None,
    readiness: str = "Complete and Ready",
    critique_status: str = "Complete",
    critique_latest: str = "",
    disposed: tuple[str, ...] = ("PC-001",),
    task_id: str | None = None,
    meta_slug: str | None = None,
    decisions: tuple[tuple[str, str, str], ...] = (
        ("D1", "Export format", "confirmed"),
    ),
    requirements: tuple[str, ...] = ("FR-001",),
    extra_phase: str = "",
) -> str:
    """A plan with one phase P01 and the given tasks, each citing FR-001."""
    if phase_checked is None:
        phase_checked = all(c for _, c in tasks)
    critique_latest = critique_latest or (
        f"{T}/reviews/plans/{DAY}/{slug}-plan-critique.md with verdict Pass"
    )
    lines = [
        "<!-- markdownlint-disable-file -->",
        f"# RPI Plan: {slug}",
        "",
        "## Task Metadata",
        "",
        f"* Task ID: {task_id or slug}",
        f"* Task slug: {meta_slug or slug}",
        f"* Plan date: {DAY}",
        "",
        "## Executive Summary",
        "",
        "Adds the export.",
        "",
        "## Phase Checklist",
        "",
        "<!-- rpi:phase id=P01 -->",
        f"### [{'x' if phase_checked else ' '}] P01: Build the export",
        "",
        "Goals:",
        "* The export works.",
        "",
        "Dependencies:",
        "* none",
        "",
        "Changes in the map: the exporter.",
        "",
    ]
    for tid, checked in tasks:
        lines += [
            f"<!-- rpi:task id={tid} -->",
            f"#### [{'x' if checked else ' '}] {tid}: Task {tid}",
            "",
            "Goals:",
            "* Behavior.",
            "",
            "Requirements:",
            "* " + ", ".join(requirements),
            "",
            "Details:",
            "* Detail.",
            "",
            "References:",
            "* `src/export.py`",
            "",
            "Dependencies:",
            "* none",
            "",
        ]
    lines.append(extra_phase)
    lines += [
        "## User Decisions and Requirements",
        "",
        "### Planning Decisions and Feedback",
        "",
        "| Group | Item | Status | Owner | Rationale | Evidence | Impact |",
        "|-------|------|--------|-------|-----------|----------|--------|",
    ]
    lines += [
        f"| {g} | {item} | {status} | user | why | none | P01-T01 |"
        for g, item, status in decisions
    ]
    lines += [
        "",
        "## Planning Readiness and Next Step",
        "",
        "| Field | Record |",
        "|-------|--------|",
        f"| Planning execution and readiness | {readiness} |",
        "| Blockers | none |",
        f"| Latest critique | {critique_latest} |",
        "| Next action | implement |",
        "",
        "## Functional Requirements",
        "",
    ]
    lines += [
        f"* {r}: The export writes CSV." for r in requirements if r.startswith("FR")
    ]
    lines += [
        "",
        "## Critique Disposition",
        "",
        "* Critique setting and provenance: standard; default",
        f"* Critique status: {critique_status}",
        f"* Latest critique and verdict: {critique_latest}",
        "",
        "| Critique run and finding | Disposition | Action owner | Evidence | Route | "
        "Response |",
        "|--------------------------|-------------|--------------|----------|-------|----------|",
    ]
    lines += [
        f"| {pc} | resolved | planner | P01-T01 | none | fixed |" for pc in disposed
    ]
    lines += [
        "",
        "## Artifact Self-Check",
        "",
        "* [x] Checked.",
        "",
        "## Follow-Up Items",
        "",
        "* None",
        "",
        "## Handoff",
        "",
        "Ready for implementation.",
        "",
    ]
    return "\n".join(lines)


def critique_text(
    slug: str = "alpha",
    execution: str = "Complete",
    verdict: str = "Pass",
    findings: tuple[str, ...] = ("PC-001",),
    plan_ref: str | None = None,
    critique_type: str = "initial",
    reconciliation: bool = False,
) -> str:
    """A plan critique with the given findings."""
    lines = [
        "<!-- markdownlint-disable-file -->",
        f"# RPI Plan Critique: {slug}",
        "",
        "## Metadata",
        "",
        f"* Task ID: {slug}",
        f"* Plan: {plan_ref or f'{T}/plans/{DAY}/{slug}-plan.md'}",
        f"* Critique execution: {execution}",
        "* Critique depth: standard",
        f"* Critique type: {critique_type}",
        "",
        "## Lens Assessments",
        "",
        "| Lens | Scope | Effort | Status | Candidates |",
        "|------|-------|--------|--------|------------|",
        "| Coverage | all | direct | Complete | 1 adopted |",
        "",
        "## Verdict",
        "",
        f"* Verdict: {verdict}",
        "",
    ]
    if reconciliation:
        lines += [
            "## Earlier Finding Reconciliation",
            "",
            "| Earlier finding | Status |",
            "",
        ]
    lines += ["## Findings", ""]
    for pc in findings:
        lines += [
            f"<!-- rpi:critique id={pc} -->",
            f"### {pc} [Medium]: A concern",
            "",
            "* Concern: c",
            "",
        ]
    lines += ["## Recommended Next Action", "", "* Action: revise", ""]
    return "\n".join(lines)


def changes_text(
    slug: str = "alpha",
    status: str = "Complete",
    scope: str = "full plan",
    entries: tuple[tuple[str, str], ...] = (
        ("P01-T01", "passed"),
        ("P01-T02", "passed"),
    ),
    completed: str = "P01, P01-T01, P01-T02",
    remaining: str = "none",
    blockers: tuple[str, ...] = (),
    review_readiness: str = "ready",
    plan_ref: str | None = None,
    validation_rows: tuple[tuple[str, str], ...] = (("`npm test`", "Passed"),),
    alignment: str | None = None,
    task_id: str | None = None,
) -> str:
    """A changes record with one entry per (marker, validation) pair."""
    plan_ref = (
        plan_ref
        or f"[{T}/plans/{DAY}/{slug}-plan.md](../../plans/{DAY}/{slug}-plan.md)"
    )
    lines = [
        "<!-- markdownlint-disable-file -->",
        f"# RPI Changes: {slug}",
        "",
        "## Metadata",
        "",
        f"* Task ID: {task_id or slug}",
        f"* Related plan: {plan_ref}",
        "",
        "## Execution Status",
        "",
        f"* Status: {status}",
        f"* Declared invocation scope: {scope}",
        f"* Completed scope markers: {completed}",
        f"* All remaining active-plan markers: {remaining}",
        "",
        "## Completed Work",
        "",
    ]
    for marker, validation in entries:
        lines += [f"### Work for {marker}", "", f"* Related phase or task: {marker}"]
        if validation:
            lines.append(f"* Validation: {validation}")
        lines.append("")
    lines += ["## Business Alignment", ""]
    if alignment:
        lines += ["### BRD-1", "", f"* Alignment: {alignment}", ""]
    else:
        lines += ["None", ""]
    lines += [
        "## Validation Record",
        "",
        "| Check | Scope | Status | Evidence |",
        "|-------|-------|--------|----------|",
    ]
    lines += [
        f"| {check} | all | {result} | log |" for check, result in validation_rows
    ]
    lines += [
        "",
        "## Pre-Review Reconciliation",
        "",
        f"* Review readiness: {review_readiness}",
        "",
        "## Blockers",
        "",
    ]
    lines += [f"* {b}" for b in blockers] or ["* None"]
    lines += [
        "",
        "## Remaining Work",
        "",
        "* None",
        "",
        "## Return-to-Caller State",
        "",
        "Done.",
        "",
    ]
    return "\n".join(lines)


def review_text(
    slug: str = "alpha",
    execution: str = "Complete",
    outcome: str = "Conformant",
    final_outcome: str = "Conformant",
    findings: tuple[tuple[str, str, str], ...] = (("RV-001", "Low", "rpi-implement"),),
    decisions: tuple[tuple[str, str, str, str], ...] = (
        ("RD-001", "RV-001", "accepted", "rpi-implement"),
    ),
    scope: str = "full task",
    record_execution: str | None = None,
    plan_ref: str | None = None,
    changes_ref: str | None = None,
) -> str:
    """A review record; decisions are (event, subject, status, final destination)."""
    lines = [
        "<!-- markdownlint-disable-file -->",
        f"# Review: {slug}",
        "",
        "## Executive Summary",
        "",
        "* Assessment: fine",
        f"* Review execution: {execution}",
        f"* Assessed outcome: {outcome}",
        "",
        "## Findings and Proposed Routes",
        "",
    ]
    for rv, sev, dest in findings:
        lines += [
            f"<!-- rpi:review id={rv} -->",
            f"### {rv} [{sev}]: Something",
            "",
            f"* Proposed destination: {dest}",
            "",
        ]
    lines += [
        "## Parent Decision Record",
        "",
        "### Current Disposition",
        "",
        f"* Final outcome: {final_outcome}",
        "",
        "### Decision History",
        "",
        "| Event | Subject | Decision source | Status or value | Proposed destination "
        "| Final destination |",
        "|-------|---------|-----------------|-----------------|----------------------"
        "|-------------------|",
    ]
    lines += [
        f"| {e} | {s} | user | {st} | rpi-implement | {fd} |"
        for e, s, st, fd in decisions
    ]
    lines += [
        "",
        "## Review Record",
        "",
        f"* Task ID: {slug}",
        f"* Review scope: {scope}",
        f"* Review execution: {record_execution or execution}",
        f"* Plan: {plan_ref or f'{T}/plans/{DAY}/{slug}-plan.md'}",
        f"* Changes: {changes_ref or f'{T}/changes/{DAY}/{slug}-changes.md'}",
        "",
    ]
    return "\n".join(lines)


def research_text(
    slug: str = "alpha",
    readiness: str = "Ready",
    disposition: str = "executed",
    cited: str = "C1",
    defined: tuple[str, ...] = ("C1",),
) -> str:
    """A research artifact with an evidence log."""
    lines = [
        "<!-- markdownlint-disable-file -->",
        f"# Task Research: {slug}",
        "",
        "## Executive Summary",
        "",
        "* Research status: complete",
        "",
        "## Findings",
        "",
        "### Finding one",
        "",
        f"* Evidence: {cited}",
        "",
        "## Planning Readiness and Next Step",
        "",
        "| Field | Record |",
        "|-------|--------|",
        f"| Research disposition | {disposition} |",
        f"| Planning Readiness | {readiness} |",
        "| Blockers | none |",
        "",
        "## Research Record",
        "",
        "### Evidence Log",
        "",
        "| ID | Claim | Source |",
        "|----|-------|--------|",
    ]
    lines += [f"| {c} | claim | `src/a.py` |" for c in defined]
    lines.append("")
    return "\n".join(lines)


def state_obj(slug: str = "alpha", **overrides: Any) -> dict[str, Any]:
    """An RPI session state object pointing at the alpha artifacts."""
    paths = {
        "research": f"{T}/research/{DAY}/{slug}-research.md",
        "plan": f"{T}/plans/{DAY}/{slug}-plan.md",
        "critique": f"{T}/reviews/plans/{DAY}/{slug}-plan-critique.md",
        "changes": f"{T}/changes/{DAY}/{slug}-changes.md",
        "review": f"{T}/reviews/logs/{DAY}/{slug}-review.md",
    }
    state: dict[str, Any] = {
        "task_id": slug,
        "task_slug": slug,
        "session_name": "Alpha work",
        "parent_task": None,
        "child_tasks": [],
        "mode": "automatic",
        "active_phase": "Follow-up",
        "status": "completed",
        "session_status": "stopped",
        "artifact_paths": paths,
        "documents": {k: [v] for k, v in paths.items()},
        "confirmed_decisions": [],
        "blockers": [],
        "next_action": {"phase": "Follow-up", "action": "assess"},
        "prioritized_follow_ups": [],
    }
    state.update(overrides)
    return state


class Workspace:
    """A temporary repository root with helpers to write tracking artifacts."""

    def __init__(self, root: Path) -> None:
        self.root = root
        (root / ".gitignore").write_text(".copilot-tracking/\n", encoding="utf-8")

    def write(self, rel: str, text: str) -> Path:
        """Write a file below the root and return its path."""
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        return path

    def state(self, rel: str, obj: dict[str, Any]) -> Path:
        """Write a state JSON file."""
        return self.write(rel, json.dumps(obj, indent=2))

    def full_task(self, slug: str = "alpha", **kw: Any) -> None:
        """Research, plan, critique, changes, and review for an accepted task."""
        self.write(
            f"{T}/research/{DAY}/{slug}-research.md",
            kw.get("research", research_text(slug)),
        )
        self.write(f"{T}/plans/{DAY}/{slug}-plan.md", kw.get("plan", plan_text(slug)))
        self.write(
            f"{T}/reviews/plans/{DAY}/{slug}-plan-critique.md",
            kw.get("critique", critique_text(slug)),
        )
        self.write(
            f"{T}/changes/{DAY}/{slug}-changes.md",
            kw.get("changes", changes_text(slug)),
        )
        self.write(
            f"{T}/reviews/logs/{DAY}/{slug}-review.md",
            kw.get("review", review_text(slug)),
        )

    def audit(self, stale_days: int = 30, task: str | None = None) -> Audit:
        """Run a workspace audit and finalize it."""
        audit = Audit(self.root, AS_OF, stale_days)
        audit.run_workspace()
        if task:
            audit.filter_task(task)
        audit.finalize()
        return audit


def rules_of(audit: Audit) -> set[str]:
    """The rule IDs the audit reported."""
    return {f.rule for f in audit.findings}


def details(audit: Audit, rule: str) -> list[str]:
    """The details of every finding for one rule."""
    return [f.detail for f in audit.findings if f.rule == rule]
