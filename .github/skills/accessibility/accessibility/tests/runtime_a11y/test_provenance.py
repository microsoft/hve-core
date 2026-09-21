# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from __future__ import annotations

import json
from pathlib import Path

from runtime_a11y.matrix._artifacts import render_artifact_bundle
from runtime_a11y.matrix._model import Cell, Criterion, Matrix, Surface
from runtime_a11y.matrix._provenance import (
    HVE_NAMESPACE,
    build_artifact_metadata,
)


def _matrix() -> Matrix:
    return Matrix(
        criteria=[
            Criterion(
                id="4.1.2",
                framework="wcag-22",
                title="Name, Role, Value",
                adequateMethods={"screen-reader", "runtime-automation"},
            )
        ],
        surfaces=[Surface(id="home", name="Home", platform="web", states=["default"])],
        cells=[
            Cell(
                criterionId="4.1.2",
                surfaceId="home",
                state="default",
                status="pass",
                verifiedByMethod="runtime-automation",
                adequateMethods={"screen-reader", "runtime-automation"},
            )
        ],
    )


def test_every_machine_readable_export_carries_provenance(tmp_path: Path) -> None:
    """A consumer reading one artifact alone still sees what produced it."""
    paths = render_artifact_bundle(_matrix(), {"overall": {}}, tmp_path, "acme/site")

    coverage = json.loads(paths.coverage_json.read_text(encoding="utf-8"))
    assert coverage["assessment"]["aiAssisted"] is True
    assert coverage["assessment"]["humanReviewCompleted"] is False
    assert coverage["assessment"]["nonAttestation"]

    earl = json.loads(paths.earl_jsonld.read_text(encoding="utf-8"))
    assert earl["hve:aiAssisted"] is True
    assert earl["hve:humanReviewCompleted"] is False
    assert earl["dct:rights"]
    assert earl["@context"]["hve"] == HVE_NAMESPACE

    plan_yaml = paths.manual_plan_yaml.read_text(encoding="utf-8")
    assert "aiAssisted: true" in plan_yaml
    assert "humanReviewCompleted: false" in plan_yaml
    assert "nonAttestation:" in plan_yaml

    manifest = json.loads(paths.manifest_json.read_text(encoding="utf-8"))
    assert manifest["assessment"]["aiAssisted"] is True
    assert manifest["assessment"]["humanReviewCompleted"] is False


def test_markdown_retains_its_existing_disclaimer_and_checkbox(tmp_path: Path) -> None:
    paths = render_artifact_bundle(_matrix(), {"overall": {}}, tmp_path, "acme/site")

    markdown = paths.coverage_markdown.read_text(encoding="utf-8")
    assert "[!CAUTION]" in markdown
    assert "- [ ] Reviewed and validated by a qualified human reviewer" in markdown


def test_human_review_is_never_recorded_as_complete_by_the_tool(
    tmp_path: Path,
) -> None:
    """Only a person marks review complete, so the default stays false."""
    metadata = build_artifact_metadata(repository="acme/site")

    assert metadata.humanReviewCompleted is False
    assert metadata.to_dict()["humanReviewCompleted"] is False
    assert metadata.to_earl_terms()["hve:humanReviewCompleted"] is False


def test_quarantine_marker_propagates_into_every_derived_artifact(
    tmp_path: Path,
) -> None:
    """Partial evidence stays usable while every artifact states its provenance."""
    metadata = build_artifact_metadata(
        repository="acme/site",
        quarantined=True,
        quarantine_reason="screen reader cleanup could not be verified",
    )
    paths = render_artifact_bundle(
        _matrix(), {"overall": {}}, tmp_path, "acme/site", metadata=metadata
    )

    coverage = json.loads(paths.coverage_json.read_text(encoding="utf-8"))
    assert coverage["assessment"]["quarantined"] is True
    assert coverage["assessment"]["quarantineReason"]

    earl = json.loads(paths.earl_jsonld.read_text(encoding="utf-8"))
    assert earl["hve:quarantined"] is True

    assert "quarantined: true" in paths.manual_plan_yaml.read_text(encoding="utf-8")
    assert "Quarantined:" in paths.coverage_markdown.read_text(encoding="utf-8")

    manifest = json.loads(paths.manifest_json.read_text(encoding="utf-8"))
    assert manifest["assessment"]["quarantined"] is True


def test_namespace_resolves_to_the_published_vocabulary() -> None:
    """Emitted custom terms must have a published definition to be interpretable."""
    assert HVE_NAMESPACE.startswith("https://microsoft.github.io/hve-core/")

    published = (
        Path(__file__).resolve().parents[6]
        / "docs"
        / "docusaurus"
        / "static"
        / "ns"
        / "accessibility"
    )
    context = json.loads((published / "context.jsonld").read_text(encoding="utf-8"))

    assert context["@context"]["hve"] == HVE_NAMESPACE
    for term in (
        "aiAssisted",
        "humanReviewCompleted",
        "evidenceLimits",
        "quarantined",
        "method",
        "methodAdequacy",
    ):
        assert term in context["@context"]
