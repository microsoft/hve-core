# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

_METHODS_PATH = Path(__file__).resolve().parent.parent / "methods.json"


def _load_method_vocabulary() -> dict[str, dict[str, Any]]:
    """Load the shared evidence-method vocabulary.

    The vocabulary is data rather than code because the Node probe runner writes
    the same method names. Holding one definition keeps the two runtimes from
    drifting apart on names, ranks, or human-evidence status.
    """
    payload = json.loads(_METHODS_PATH.read_text(encoding="utf-8"))
    return {entry["name"]: entry for entry in payload["methods"]}


METHOD_VOCABULARY = _load_method_vocabulary()

METHOD_RANK = {name: entry["rank"] for name, entry in METHOD_VOCABULARY.items()}

# Methods a person performed. The EARL renderer reports these as manual mode.
HUMAN_EVIDENCE_METHODS = frozenset(
    name for name, entry in METHOD_VOCABULARY.items() if entry.get("humanEvidence")
)

# Methods a later automated result must never overwrite during merge.
OVERWRITE_LOCKED_METHODS = frozenset(
    name for name, entry in METHOD_VOCABULARY.items() if entry.get("overwriteLocked")
)

STATUS_PRIORITY = {
    "pass": 4,
    "partial": 3,
    "fail": 2,
    "not-applicable": 1,
    "unknown": 0,
}


@dataclass(slots=True)
class Criterion:
    id: str
    framework: str
    title: str
    adequateMethods: set[str] = field(default_factory=set)


@dataclass(slots=True)
class Surface:
    id: str
    name: str
    platform: str
    states: list[str] = field(default_factory=list)
    widgetPattern: str | None = None


@dataclass(slots=True)
class Cell:
    criterionId: str
    surfaceId: str
    state: str
    status: str = "unknown"
    verifiedByMethod: str | None = None
    date: str | None = None
    evidence: str | None = None
    severity: str | None = None
    rationale: str | None = None
    requiredMethods: set[str] = field(default_factory=set)
    adequateMethods: set[str] = field(default_factory=set)
    isApplicable: bool = True
    methodProvenance: str | None = None


@dataclass(slots=True)
class CandidateUpdate:
    criterionId: str
    surfaceId: str
    state: str
    status: str
    method: str
    date: str | None = None
    evidence: str | None = None
    severity: str | None = None
    rationale: str | None = None


@dataclass(slots=True)
class Matrix:
    criteria: list[Criterion]
    surfaces: list[Surface]
    cells: list[Cell]

    @classmethod
    def from_dict(cls, payload: dict[str, Any]) -> Matrix:
        """Reconstruct a matrix from the rendered JSON representation."""
        criteria = [
            Criterion(
                id=str(item["id"]),
                framework=str(item["framework"]),
                title=str(item.get("title", item["id"])),
                adequateMethods=set(item.get("adequateMethods", [])),
            )
            for item in payload.get("criteria", [])
        ]
        surfaces = [
            Surface(
                id=str(item["id"]),
                name=str(item.get("name", item["id"])),
                platform=str(item.get("platform", "web")),
                states=[str(state) for state in item.get("states", [])],
                widgetPattern=item.get("widgetPattern"),
            )
            for item in payload.get("surfaces", [])
        ]
        cells = [
            Cell(
                criterionId=str(item["criterionId"]),
                surfaceId=str(item["surfaceId"]),
                state=str(item.get("state", "default")),
                status=str(item.get("status", "unknown")),
                verifiedByMethod=item.get("verifiedByMethod"),
                date=item.get("date"),
                evidence=item.get("evidence"),
                severity=item.get("severity"),
                rationale=item.get("rationale"),
                requiredMethods=set(item.get("requiredMethods", [])),
                adequateMethods=set(item.get("adequateMethods", [])),
                isApplicable=bool(item.get("isApplicable", True)),
                methodProvenance=item.get("methodProvenance"),
            )
            for item in payload.get("cells", [])
        ]
        return cls(criteria=criteria, surfaces=surfaces, cells=cells)

    def to_dict(self) -> dict[str, Any]:
        return {
            "criteria": [
                {
                    "id": criterion.id,
                    "framework": criterion.framework,
                    "title": criterion.title,
                    "adequateMethods": sorted(criterion.adequateMethods),
                }
                for criterion in self.criteria
            ],
            "surfaces": [
                {
                    "id": surface.id,
                    "name": surface.name,
                    "platform": surface.platform,
                    "states": surface.states,
                    "widgetPattern": surface.widgetPattern,
                }
                for surface in self.surfaces
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
                for cell in self.cells
            ],
        }
