# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from __future__ import annotations

import json
from pathlib import Path

from runtime_a11y.matrix._model import Cell, Criterion, Matrix, Surface
from runtime_a11y.matrix._render_earl import build_earl, earl_outcome, render_earl


def _cell(
    status: str, method: str | None, *, adequate: set[str], applicable: bool = True
) -> Cell:
    return Cell(
        criterionId="4.1.2",
        surfaceId="web",
        state="open",
        status=status,
        verifiedByMethod=method,
        adequateMethods=adequate,
        isApplicable=applicable,
    )


def test_earl_outcome_applies_method_adequacy() -> None:
    # A pass decided by an adequate method is earl:passed.
    assert (
        earl_outcome(_cell("pass", "screen-reader", adequate={"screen-reader"}))
        == "earl:passed"
    )
    # A pass whose winning method only informs the criterion is earl:cantTell.
    assert (
        earl_outcome(_cell("pass", "axe-auto", adequate={"screen-reader"}))
        == "earl:cantTell"
    )
    # A pass on a cell with no declared adequate methods is earl:cantTell, not
    # earl:passed. Matrix loading defaults an absent adequateMethods field to an
    # empty set, so an empty set cannot be distinguished from "not configured".
    # EARL feeds conformance reporting, so the undetermined case must not be
    # published as a decided pass.
    assert earl_outcome(_cell("pass", "axe-auto", adequate=set())) == "earl:cantTell"
    # Partial (informs-only) is earl:cantTell.
    assert (
        earl_outcome(_cell("partial", "runtime-automation", adequate={"screen-reader"}))
        == "earl:cantTell"
    )
    # Fail is earl:failed.
    assert (
        earl_outcome(_cell("fail", "runtime-automation", adequate={"screen-reader"}))
        == "earl:failed"
    )
    # Not applicable is earl:inapplicable.
    assert (
        earl_outcome(_cell("not-applicable", None, adequate=set(), applicable=False))
        == "earl:inapplicable"
    )
    # Unknown is earl:untested.
    assert earl_outcome(_cell("unknown", None, adequate=set())) == "earl:untested"
    # An unrecognized status falls through to earl:untested rather than passing.
    assert earl_outcome(_cell("weird-status", None, adequate=set())) == "earl:untested"


def test_build_earl_emits_assertions_and_omits_untested() -> None:
    matrix = Matrix(
        criteria=[
            Criterion(id="4.1.2", framework="wcag-22", title="Name, Role, Value")
        ],
        surfaces=[Surface(id="web", name="Web", platform="web", states=["open"])],
        cells=[
            _cell("fail", "screen-reader", adequate={"screen-reader"}),
            _cell("unknown", None, adequate={"screen-reader"}),
        ],
    )

    doc = build_earl(matrix, {"overall": {"coverage": 0.0}})

    assert "@context" in doc and "earl" in doc["@context"]
    assertions = [
        node for node in doc["@graph"] if node.get("@type") == "earl:Assertion"
    ]
    # The untested cell is omitted; only the evaluated cell is asserted.
    assert len(assertions) == 1
    assertion = assertions[0]
    assert assertion["earl:result"]["earl:outcome"]["@id"] == "earl:failed"
    assert assertion["earl:test"]["dct:identifier"] == "4.1.2"
    assert assertion["earl:test"]["dct:isPartOf"] == "https://www.w3.org/TR/WCAG22/"
    assert assertion["earl:mode"]["@id"] == "earl:manual"
    assert assertion["earl:subject"]["dct:identifier"] == "web#open"
    assert assertion["@id"] == "_:assertion-4-1-2-web-open"
    assert assertion["hve:method"] == "screen-reader"
    assert assertion["hve:methodAdequacy"] == "decides"


def test_render_earl_writes_jsonld(tmp_path: Path) -> None:
    matrix = Matrix(
        criteria=[
            Criterion(id="4.1.2", framework="wcag-22", title="Name, Role, Value")
        ],
        surfaces=[Surface(id="web", name="Web", platform="web", states=["open"])],
        cells=[_cell("pass", "axe-auto", adequate={"screen-reader"})],
    )
    out_path = tmp_path / "earl.jsonld"

    render_earl(matrix, {"overall": {"coverage": 0.0}}, out_path)

    doc = json.loads(out_path.read_text(encoding="utf-8"))
    assertion = next(
        node for node in doc["@graph"] if node.get("@type") == "earl:Assertion"
    )
    # pass by an inadequate (informs-only) method -> cantTell.
    assert assertion["earl:result"]["earl:outcome"]["@id"] == "earl:cantTell"
    assert assertion["hve:methodAdequacy"] == "informs"


def test_given_dated_evidence_when_building_earl_then_provenance_is_preserved() -> None:
    # Arrange
    cell = _cell("fail", None, adequate={"screen-reader"})
    cell.date = "2026-07-10"
    cell.evidence = "evidence://search/open"
    cell.rationale = "The announcement omitted the accessible name."
    matrix = Matrix(
        criteria=[Criterion(id="4.1.2", framework="coga", title="Name")],
        surfaces=[Surface(id="web", name="Web", platform="web")],
        cells=[cell],
    )

    # Act
    document = build_earl(matrix)

    # Assert
    assertion = next(
        node for node in document["@graph"] if node.get("@type") == "earl:Assertion"
    )
    assert assertion["earl:mode"]["@id"] == "earl:undisclosed"
    assert (
        assertion["earl:test"]["dct:isPartOf"] == "https://www.w3.org/TR/coga-usable/"
    )
    assert assertion["earl:result"]["dct:date"] == "2026-07-10"
    assert assertion["earl:result"]["dct:source"] == "evidence://search/open"
    assert assertion["earl:result"]["earl:info"] == (
        "The announcement omitted the accessible name."
    )
