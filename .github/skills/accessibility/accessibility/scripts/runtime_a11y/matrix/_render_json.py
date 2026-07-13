# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from runtime_a11y.matrix._model import Matrix


def render_json(matrix: Matrix, coverage: dict[str, Any], out_path: Path) -> None:
    """Write a JSON representation of the matrix and coverage summary."""
    payload = {
        "criteria": [
            {
                "id": criterion.id,
                "framework": criterion.framework,
                "title": criterion.title,
                "adequateMethods": sorted(criterion.adequateMethods),
            }
            for criterion in matrix.criteria
        ],
        "surfaces": [
            {
                "id": surface.id,
                "name": surface.name,
                "platform": surface.platform,
                "states": list(surface.states),
            }
            for surface in matrix.surfaces
        ],
        "cells": [
            {
                "criterionId": cell.criterionId,
                "surfaceId": cell.surfaceId,
                "state": cell.state,
                "status": cell.status,
                "verifiedByMethod": cell.verifiedByMethod,
                "date": cell.date,
                "evidence": cell.evidence,
                "severity": cell.severity,
                "rationale": cell.rationale,
                "requiredMethods": sorted(cell.requiredMethods),
                "adequateMethods": sorted(cell.adequateMethods),
                "isApplicable": cell.isApplicable,
                "methodProvenance": cell.methodProvenance,
            }
            for cell in matrix.cells
        ],
        "coverage": coverage,
    }

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
