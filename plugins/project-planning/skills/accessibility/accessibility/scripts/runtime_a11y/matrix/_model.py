# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

METHOD_RANK = {
    "manual-keyboard": 70,
    "screen-reader": 65,
    "cognitive-walkthrough": 60,
    "runtime-automation": 50,
    "axe-auto": 45,
    "static-source": 40,
    "plan-derived": 35,
}

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
