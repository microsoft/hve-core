# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from __future__ import annotations

import re
from pathlib import Path
from typing import Any

from runtime_a11y.matrix._model import CandidateUpdate, Surface


def ingest_report_markdown(
    payload: str | Path,
    surfaces: list[Surface] | list[str],
) -> list[CandidateUpdate]:
    """Parse prior accessibility report markdown into candidate matrix updates."""
    content = _read_text(payload)
    rows = _extract_rows(content)

    surface_ids = [
        surface if isinstance(surface, str) else getattr(surface, "id", "")
        for surface in surfaces
    ]
    surface_ids = [surface_id for surface_id in surface_ids if surface_id]
    if not surface_ids:
        return []

    updates: list[CandidateUpdate] = []
    for row in rows:
        criterion_id = str(row.get("ID") or "").strip()
        if not criterion_id:
            continue

        status = _map_status(row.get("Status"))
        evidence = _extract_evidence(row.get("File + Evidence")) or _extract_evidence(
            row.get("Location")
        )
        severity = str(row.get("Severity") or "").strip() or None

        for surface_id in surface_ids:
            updates.append(
                CandidateUpdate(
                    criterionId=criterion_id,
                    surfaceId=surface_id,
                    state="default",
                    status=status,
                    method="static-source",
                    evidence=evidence,
                    severity=severity,
                )
            )

    return updates


def _read_text(payload: str | Path) -> str:
    if isinstance(payload, Path):
        return payload.read_text(encoding="utf-8")
    return payload


def _extract_rows(markdown: str) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    headers: list[str] = []
    in_table = False
    for line in markdown.splitlines():
        if not line.strip():
            continue
        if not line.startswith("|"):
            if headers:
                in_table = False
                headers = []
            continue

        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if not headers:
            normalized = [cell.lower() for cell in cells]
            if (
                "id" in normalized
                and "status" in normalized
                and ("severity" in normalized or "finding type" in normalized)
            ):
                headers = cells
                in_table = True
            continue

        if in_table and len(cells) == len(headers):
            if re.fullmatch(r"[-: ]+", cells[0]):
                continue
            row: dict[str, Any] = {}
            for index, header in enumerate(headers):
                row[header] = cells[index] if index < len(cells) else ""
            rows.append(row)

    return rows


def _map_status(value: Any) -> str:
    status = str(value or "").strip().lower()
    if status in {"pass", "covered"}:
        return "pass"
    if status in {"partial", "informational", "caution"}:
        return "partial"
    if status in {"fail", "risk", "blocked"}:
        return "fail"
    if status in {"not_applicable", "not-applicable", "not applicable"}:
        return "not-applicable"
    return "fail"


def _extract_evidence(value: Any) -> str | None:
    text = str(value or "").strip()
    if not text or text in {"—", "-"}:
        return None
    match = re.search(r"\(([^)]+)\)", text)
    if match:
        return match.group(1)
    return text
