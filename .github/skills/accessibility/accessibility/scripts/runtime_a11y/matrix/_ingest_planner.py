# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from runtime_a11y.matrix._model import CandidateUpdate, Surface


def ingest_planner_state(
    payload: str | bytes | Path | dict[str, Any],
    surfaces: list[Surface] | list[str],
) -> list[CandidateUpdate]:
    """Parse planner state data into candidate matrix updates.

    The planner surfaces are coarse platform classes. They are matched to the
    matrix surfaces by platform so the adapter can fan out without fabricating
    surface IDs that are not present in the matrix.
    """
    state = _load_state(payload)
    control_mappings = state.get("controlMappings", [])
    evidence_register = state.get("evidenceRegister", [])
    if not isinstance(control_mappings, list):
        return []

    evidence_by_control: dict[tuple[str | None, str | None], list[dict[str, Any]]] = {}
    for entry in evidence_register if isinstance(evidence_register, list) else []:
        if not isinstance(entry, dict):
            continue
        key = (
            str(entry.get("frameworkId") or "").strip() or None,
            str(entry.get("controlId") or "").strip() or None,
        )
        evidence_by_control.setdefault(key, []).append(entry)

    updates: list[CandidateUpdate] = []
    for mapping in control_mappings:
        if not isinstance(mapping, dict):
            continue
        criterion_id = str(mapping.get("controlId") or "").strip()
        if not criterion_id:
            continue

        matched_surface_ids = _match_surface_ids(
            surfaces,
            mapping.get("surfaces"),
            state.get("project", {}).get("surfaces"),
        )
        if not matched_surface_ids:
            continue

        status = _map_status(mapping.get("status"))
        evidence = _select_evidence(mapping, evidence_by_control)
        rationale = str(mapping.get("notes") or "").strip() or None
        for surface_id in matched_surface_ids:
            updates.append(
                CandidateUpdate(
                    criterionId=criterion_id,
                    surfaceId=surface_id,
                    state="default",
                    status=status,
                    method="plan-derived",
                    evidence=evidence,
                    rationale=rationale,
                )
            )

    return updates


def _load_state(payload: str | bytes | Path | dict[str, Any]) -> dict[str, Any]:
    if isinstance(payload, dict):
        return payload
    if isinstance(payload, (str, bytes)):
        content = payload.decode("utf-8") if isinstance(payload, bytes) else payload
        if content.lstrip().startswith("{"):
            return json.loads(content)
        path = Path(content)
        if path.exists():
            return json.loads(path.read_text(encoding="utf-8"))
        return {}

    path = Path(payload)
    if path.exists():
        return json.loads(path.read_text(encoding="utf-8"))
    return {}


def _collect_surface_ids(surfaces: list[Surface] | list[str]) -> list[str]:
    return [
        surface if isinstance(surface, str) else str(getattr(surface, "id", ""))
        for surface in surfaces
    ]


def _match_surface_ids(
    matrix_surfaces: list[Surface] | list[str],
    mapping_surfaces: Any,
    project_surfaces: Any,
) -> list[str]:
    requested = []
    if isinstance(mapping_surfaces, list):
        requested.extend(str(item) for item in mapping_surfaces if str(item).strip())
    if not requested and isinstance(project_surfaces, list):
        requested.extend(str(item) for item in project_surfaces if str(item).strip())

    if not requested:
        return []

    requested_norm = {item.strip().lower() for item in requested}
    matched: list[str] = []
    for surface in matrix_surfaces:
        if isinstance(surface, Surface):
            surface_id = str(surface.id)
            surface_platform = str(getattr(surface, "platform", "")).lower()
            if (
                surface_id.lower() in requested_norm
                or surface_platform in requested_norm
            ):
                matched.append(surface_id)
            continue

        surface_id = str(surface)
        if surface_id.lower() in requested_norm:
            matched.append(surface_id)
    return matched


def _map_status(value: Any) -> str:
    status = str(value or "").strip().lower()
    if status in {"covered"}:
        return "pass"
    if status in {"partial"}:
        return "partial"
    if status in {"gap", "pending"}:
        return "fail"
    if status in {"not-applicable", "not_applicable", "not applicable"}:
        return "not-applicable"
    return "fail"


def _select_evidence(
    mapping: dict[str, Any],
    evidence_by_control: dict[tuple[str | None, str | None], list[dict[str, Any]]],
) -> str | None:
    evidence = mapping.get("evidence")
    if evidence:
        return str(evidence)

    framework_id = str(mapping.get("frameworkId") or "").strip() or None
    control_id = str(mapping.get("controlId") or "").strip() or None
    entries = evidence_by_control.get((framework_id, control_id), [])
    if not entries and control_id:
        entries = [
            entry
            for (entry_framework_id, entry_control_id), entry_list in (
                evidence_by_control.items()
            )
            if entry_control_id == control_id
            and (framework_id is None or entry_framework_id in {None, framework_id})
            for entry in entry_list
        ]
    for entry in entries:
        source_uri = str(entry.get("sourceUri") or "").strip()
        if source_uri:
            return source_uri
    return None
