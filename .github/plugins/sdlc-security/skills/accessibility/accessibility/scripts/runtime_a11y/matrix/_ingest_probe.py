# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from runtime_a11y.matrix._model import CandidateUpdate


def ingest_probe_results(
    payload: str | bytes | Path | dict[str, Any],
) -> list[CandidateUpdate]:
    """Parse probe-harness results into candidate matrix updates.

    Args:
        payload: Probe document content as JSON text, bytes, a path to a JSON file,
            or an already-decoded mapping.

    Returns:
        List of candidate updates derived from the probe results.
    """
    document = _load_document(payload)
    results = document.get("results", [])
    if not isinstance(results, list):
        return []

    updates: list[CandidateUpdate] = []
    for item in results:
        if not isinstance(item, dict):
            continue
        criterion_id = str(item.get("criterionId") or "").strip()
        if not criterion_id:
            continue

        surface_id = str(item.get("surfaceId") or "").strip() or "default"
        state = str(item.get("state") or "default").strip() or "default"
        method = (
            str(item.get("method") or "runtime-automation").strip()
            or "runtime-automation"
        )
        status = _normalize_status(item.get("status"))

        updates.append(
            CandidateUpdate(
                criterionId=criterion_id,
                surfaceId=surface_id,
                state=state,
                status=status,
                method=method,
                date=str(item.get("date") or "") or None,
                evidence=str(item.get("evidence") or "") or None,
                severity=str(item.get("severity") or "") or None,
                rationale=str(item.get("rationale") or "") or None,
            )
        )

    return updates


def _load_document(payload: str | bytes | Path | dict[str, Any]) -> dict[str, Any]:
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


def _normalize_status(value: Any) -> str:
    status = str(value or "").strip().lower()
    if status in {"candidate", "partial"}:
        return "partial"
    if status in {"pass", "fail"}:
        return status
    return "unknown"
