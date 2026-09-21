# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

"""EARL (Evaluation and Report Language) renderer for the coverage matrix.

EARL is the W3C vocabulary for expressing accessibility test results as
assertor -> subject -> test -> outcome, used by the ACT Rules ecosystem for tool
interoperability and by conformance reporting (VPAT/EAA). This renderer is the
normalized results export for the runtime harness: it maps each evaluated
coverage cell to one earl:Assertion. The method-adequacy rule is expressed
natively through earl:cantTell -- a result whose winning method only informs the
criterion (rather than deciding it) is reported as cantTell, never a false
earl:passed.
"""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

from runtime_a11y.matrix._model import HUMAN_EVIDENCE_METHODS, Cell, Matrix
from runtime_a11y.matrix._provenance import HVE_NAMESPACE, ArtifactMetadata

# Framework identifier -> canonical spec URL used as dct:isPartOf for a criterion.
_FRAMEWORK_SOURCE = {
    "wcag-22": "https://www.w3.org/TR/WCAG22/",
    "aria-apg": "https://www.w3.org/WAI/ARIA/apg/",
    "coga": "https://www.w3.org/TR/coga-usable/",
    "section-508": "https://www.access-board.gov/ict/",
    "en-301-549": "https://www.etsi.org/deliver/etsi_en/301500_301599/301549/",
    "defect-scan": "https://github.com/microsoft/hve-core",
}

# Methods a person performed. EARL reports these as manual mode.
_MANUAL_METHODS = HUMAN_EVIDENCE_METHODS


def _identifier_token(*parts: str) -> str:
    value = "-".join(parts).lower()
    return re.sub(r"[^a-z0-9]+", "-", value).strip("-") or "unknown"


def _method_adequacy(cell: Cell) -> str:
    """Report whether the winning method decides the criterion, or only informs it.

    An empty adequacy list means no method has been declared adequate for this
    criterion, so whether the winning method decides it is unknown. Unknown is
    reported as "informs" rather than "decides": absent configuration is not
    evidence that every method is sufficient.
    """
    if not cell.adequateMethods:
        return "informs"
    if cell.verifiedByMethod in cell.adequateMethods:
        return "decides"
    return "informs"


def earl_outcome(cell: Cell) -> str:
    """Map a coverage cell to an EARL outcome.

    A pass counts as earl:passed only when decided by a method that is adequate
    for the criterion. A method that merely informs the criterion (a static or
    simulated check on a class it cannot decide) yields earl:cantTell -- the EARL
    expression of the method-adequacy rule. Inapplicable cells are earl:inapplicable
    and unevaluated cells are earl:untested.

    A cell with no declared adequate methods is also earl:cantTell. EARL feeds
    conformance reporting, so an undeclared adequacy list must not be read as
    "any method suffices"; that would publish an unverified pass as a decided one.
    """
    if not cell.isApplicable or cell.status == "not-applicable":
        return "earl:inapplicable"
    if cell.status in (None, "unknown"):
        return "earl:untested"
    if cell.status == "fail":
        return "earl:failed"
    if cell.status == "partial":
        return "earl:cantTell"
    if cell.status == "pass":
        if not cell.adequateMethods:
            return "earl:cantTell"
        if cell.verifiedByMethod not in cell.adequateMethods:
            return "earl:cantTell"
        return "earl:passed"
    return "earl:untested"


def _earl_mode(method: str | None) -> str:
    if method in _MANUAL_METHODS:
        return "earl:manual"
    if method:
        return "earl:automatic"
    return "earl:undisclosed"


def build_earl(
    matrix: Matrix,
    coverage: dict[str, Any] | None = None,
    metadata: ArtifactMetadata | None = None,
) -> dict[str, Any]:
    """Build an EARL JSON-LD document from the coverage matrix.

    Emits one earl:Assertion per evaluated cell. Cells that were never evaluated
    (applicable but still ``unknown``) are omitted; inapplicable cells are kept as
    earl:inapplicable so the report records the determination.
    """
    framework_by_criterion = {
        criterion.id: criterion.framework for criterion in matrix.criteria
    }

    overall = (coverage or {}).get("overall", {}) if coverage else {}
    coverage_pct = overall.get("coverage", 0)
    assertor = {
        "@id": "_:assertor",
        "@type": "earl:Software",
        "dct:title": "hve-core runtime_a11y",
        "dct:description": (
            f"Runtime accessibility probe harness; adequate coverage {coverage_pct}%"
            if coverage
            else "Runtime accessibility probe harness"
        ),
    }
    graph: list[dict[str, Any]] = [assertor]

    for cell in matrix.cells:
        if cell.isApplicable and cell.status in (None, "unknown"):
            continue

        framework = framework_by_criterion.get(cell.criterionId, "")
        identifier = _identifier_token(
            cell.criterionId, cell.surfaceId, cell.state or "default"
        )
        subject_id = (
            f"{cell.surfaceId}#{cell.state}"
            if cell.state and cell.state != "default"
            else cell.surfaceId
        )
        result: dict[str, Any] = {
            "@type": "earl:TestResult",
            "earl:outcome": {"@id": earl_outcome(cell)},
            "earl:info": cell.rationale or cell.evidence or "",
        }
        if cell.date:
            result["dct:date"] = cell.date
        if cell.evidence:
            result["dct:source"] = cell.evidence

        graph.append(
            {
                "@id": f"_:assertion-{identifier}",
                "@type": "earl:Assertion",
                "earl:assertedBy": {"@id": "_:assertor"},
                "earl:mode": {"@id": _earl_mode(cell.verifiedByMethod)},
                "hve:method": cell.verifiedByMethod or "unknown",
                "hve:methodAdequacy": _method_adequacy(cell),
                "hve:state": cell.state or "default",
                "earl:subject": {
                    "@id": f"_:subject-{_identifier_token(subject_id)}",
                    "@type": "earl:TestSubject",
                    "dct:identifier": subject_id,
                },
                "earl:test": {
                    "@type": "earl:TestCriterion",
                    "dct:identifier": cell.criterionId,
                    "dct:isPartOf": _FRAMEWORK_SOURCE.get(framework, framework),
                },
                "earl:result": result,
            }
        )

    return {
        "@context": {
            "earl": "http://www.w3.org/ns/earl#",
            "dct": "http://purl.org/dc/terms/",
            "hve": HVE_NAMESPACE,
        },
        **(metadata.to_earl_terms() if metadata is not None else {}),
        "@graph": graph,
    }


def render_earl(
    matrix: Matrix,
    coverage: dict[str, Any],
    out_path: Path,
    metadata: ArtifactMetadata | None = None,
) -> None:
    """Write an EARL JSON-LD representation of the matrix results to ``out_path``.

    This export is designed for machine ingestion by conformance tooling and is
    read without its Markdown sibling, so the non-attestation and review state
    travel in the document itself.
    """
    document = build_earl(matrix, coverage, metadata)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
