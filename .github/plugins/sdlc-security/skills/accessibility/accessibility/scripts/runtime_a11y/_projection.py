# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

"""Render a Design Intent Record as readable Markdown for engineering review.

The authored record is a decision record: it states what a surface must convey
and how each claim is checked, but carries no implementation or delivery scope.
Reviewers reading it during handoff benefit from prose rather than YAML.

The projection renders only what the record already says. It adds no analysis
and no verification results, so it stays true to its source. Output is
deterministic, and it is generated on demand rather than committed, so it can
never drift from the record it describes.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

from runtime_a11y._errors import ScriptError
from runtime_a11y._intent import parse_record, read_record_text

GENERATED_MARKER = (
    "<!-- Generated from the Design Intent Record by "
    "`runtime_a11y project-intent`. Do not edit; regenerate instead. -->"
)

_EVIDENCE_NOTE = {
    "observed": "observed directly",
    "reported": "reported by users or stakeholders",
    "assumed": "assumed, not yet validated",
}


def _escape_cell(value: Any) -> str:
    """Make a value safe to place inside a Markdown table cell."""
    text = "" if value is None else str(value)
    return text.replace("|", "\\|").replace("\n", " ").strip()


def _render_expectation_table(expectations: list[dict[str, Any]]) -> list[str]:
    """Render one intent's expectations as a table."""
    lines = [
        "",
        "| Expectation | Checked by | Criteria | Role | Blocks |",
        "|-------------|------------|----------|------|--------|",
    ]
    for expectation in expectations:
        criteria = ", ".join(
            f"`{_escape_cell(item)}`" for item in expectation.get("criteria") or []
        )
        blocking = "yes" if expectation.get("blocking") is True else "no"
        lines.append(
            "| {id} | `{assert_id}` | {criteria} | {role} | {blocking} |".format(
                id=_escape_cell(expectation.get("id")),
                assert_id=_escape_cell(expectation.get("assert")),
                criteria=criteria or "none",
                role=_escape_cell(expectation.get("role")),
                blocking=blocking,
            )
        )
    return lines


def _iter_intents(record: dict[str, Any]) -> list[dict[str, Any]]:
    """Return intents, rejecting malformed nested structures early."""
    intents = record.get("intents")
    if intents is None:
        return []
    if not isinstance(intents, list):
        raise ScriptError(
            f"Record 'intents' must be a list, got {type(intents).__name__}"
        )
    for entry in intents:
        if not isinstance(entry, dict):
            raise ScriptError(
                f"Each entry in 'intents' must be a mapping, got {type(entry).__name__}"
            )
    return intents


def _iter_expectations(intent: dict[str, Any]) -> list[dict[str, Any]]:
    """Return expectations, rejecting malformed nested structures early."""
    expectations = intent.get("expectations")
    if expectations is None:
        return []
    if not isinstance(expectations, list):
        raise ScriptError(
            f"Intent '{intent.get('id')}' expectations must be a list, got "
            f"{type(expectations).__name__}"
        )
    for entry in expectations:
        if not isinstance(entry, dict):
            raise ScriptError(
                f"Each entry in 'expectations' of intent "
                f"'{intent.get('id')}' must be a mapping, got "
                f"{type(entry).__name__}"
            )
    return expectations


def _render_intent(intent: dict[str, Any]) -> list[str]:
    """Render one intent: its claim, reasoning, audience, and checks."""
    lines: list[str] = []
    intent_id = intent.get("id")
    conveys = intent.get("conveys") or ""
    lines.append(f"## {intent_id}: {conveys}")
    lines.append("")

    rationale = intent.get("rationale")
    if rationale:
        lines.append(str(rationale))
        lines.append("")

    audience = intent.get("audience") or []
    if audience:
        lines.append("Who depends on this:")
        lines.append("")
        for member in audience:
            lines.append(f"* {member}")
        lines.append("")

    evidence = str(intent.get("evidence", ""))
    state = str((intent.get("binding") or {}).get("state", "default"))
    basis = _EVIDENCE_NOTE.get(evidence, evidence or "unspecified")
    lines.append(f"Basis: {basis}. Applies to the `{state}` state.")

    expectations = _iter_expectations(intent)
    if expectations:
        lines.extend(_render_expectation_table(expectations))
    else:
        lines.append("")
        lines.append("No expectations are declared for this intent.")
    lines.append("")
    return lines


def render(record: dict[str, Any]) -> str:
    """Render a parsed record as Markdown."""
    title = record.get("title") or record.get("surfaceId") or "Design intent"
    lines: list[str] = [GENERATED_MARKER, "", f"# Design intent: {title}", ""]

    decided_by = ", ".join(str(item) for item in record.get("decidedBy") or [])
    metadata = [
        ("Surface", record.get("surfaceId")),
        ("Owner", record.get("owner")),
        ("Status", record.get("status")),
        ("Decided on", record.get("decidedOn")),
        ("Decided by", decided_by),
        ("Revision", record.get("version")),
    ]
    lines.append("| Field | Value |")
    lines.append("|-------|-------|")
    for label, value in metadata:
        lines.append(f"| {label} | {_escape_cell(value)} |")
    lines.append("")

    intents = _iter_intents(record)
    if not intents:
        lines.append("This record declares no intents.")
        lines.append("")
    for intent in intents:
        lines.extend(_render_intent(intent))

    grounded_in = record.get("groundedIn") or []
    if grounded_in:
        lines.append("## Grounded in")
        lines.append("")
        for source in grounded_in:
            title_text = source.get("title") or source.get("id")
            url = source.get("url")
            use = source.get("use")
            entry = f"* [{title_text}]({url})" if url else f"* {title_text}"
            if use:
                entry += f" — {use}"
            lines.append(entry)
        lines.append("")

    return "\n".join(lines).rstrip("\n") + "\n"


def project(record_path: Path, out_path: Path | None = None) -> tuple[str, Path | None]:
    """Render a record from disk, optionally writing the result."""
    raw_text = read_record_text(record_path)
    record = parse_record(raw_text, record_path)
    if not record.get("surfaceId"):
        raise ScriptError(f"Record declares no surfaceId: {record_path}")

    markdown = render(record)
    if out_path is None:
        return markdown, None
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(markdown, encoding="utf-8")
    return markdown, out_path
