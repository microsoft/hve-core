# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from __future__ import annotations

import json
from pathlib import Path

from runtime_a11y.matrix._artifacts import artifact_paths, render_artifact_bundle
from runtime_a11y.matrix._coverage import compute_coverage
from runtime_a11y.matrix._model import Cell, Criterion, Matrix, Surface
from runtime_a11y.matrix._render_test_plan import (
    _yaml_scalar,
    build_manual_test_cases,
    render_manual_test_plan_markdown,
    render_manual_test_plan_yaml,
)


def _matrix() -> Matrix:
    return Matrix(
        criteria=[
            Criterion(
                id="4.1.2",
                framework="wcag-22",
                title="Name, Role, Value",
                adequateMethods={"screen-reader"},
            ),
            Criterion(
                id="2.4.7",
                framework="wcag-22",
                title="Focus Visible",
                adequateMethods={"manual-keyboard"},
            ),
            Criterion(
                id="1.4.3",
                framework="wcag-22",
                title="Contrast",
                adequateMethods={"axe-auto"},
            ),
        ],
        surfaces=[
            Surface(
                id="search",
                name="Search dialog",
                platform="web",
                states=["open"],
                widgetPattern="dialog-modal",
            )
        ],
        cells=[
            Cell(
                criterionId="4.1.2",
                surfaceId="search",
                state="open",
                status="pass",
                verifiedByMethod="axe-auto",
                evidence="axe.json",
                rationale="Static evidence only",
                adequateMethods={"screen-reader"},
            ),
            Cell(
                criterionId="2.4.7",
                surfaceId="search",
                state="open",
                status="pass",
                verifiedByMethod="manual-keyboard",
                adequateMethods={"manual-keyboard"},
            ),
            Cell(
                criterionId="1.4.3",
                surfaceId="search",
                state="open",
                status="unknown",
                adequateMethods={"axe-auto"},
            ),
            Cell(
                criterionId="4.1.2",
                surfaceId="search",
                state="default",
                status="not-applicable",
                adequateMethods={"screen-reader"},
                isApplicable=False,
            ),
        ],
    )


def test_given_rendered_payload_when_deserialized_then_matrix_round_trips() -> None:
    # Arrange
    source = _matrix()

    # Act
    restored = Matrix.from_dict(source.to_dict())

    # Assert
    assert restored.to_dict() == source.to_dict()


def test_given_surface_widget_pattern_when_round_tripping_then_value_is_preserved() -> (
    None
):
    # Arrange
    source = Matrix(
        criteria=[Criterion(id="4.1.2", framework="wcag-22", title="Name")],
        surfaces=[
            Surface(
                id="search",
                name="Search",
                platform="web",
                widgetPattern="dialog-modal",
            )
        ],
        cells=[Cell(criterionId="4.1.2", surfaceId="search", state="open")],
    )

    # Act
    restored = Matrix.from_dict(source.to_dict())

    # Assert
    assert restored.surfaces[0].widgetPattern == "dialog-modal"


def test_given_minimal_payload_when_deserialized_then_defaults_are_applied() -> None:
    # Arrange
    payload = {
        "criteria": [{"id": "1.1.1", "framework": "wcag-22"}],
        "surfaces": [{"id": "home"}],
        "cells": [{"criterionId": "1.1.1", "surfaceId": "home"}],
    }

    # Act
    restored = Matrix.from_dict(payload)

    # Assert
    assert restored.criteria[0].title == "1.1.1"
    assert restored.surfaces[0].name == "home"
    assert restored.surfaces[0].platform == "web"
    assert restored.cells[0].state == "default"
    assert restored.cells[0].status == "unknown"


def test_given_unresolved_human_method_when_building_plan_then_case_is_emitted() -> (
    None
):
    # Act
    cases = build_manual_test_cases(_matrix())

    # Assert
    assert len(cases) == 1
    assert cases[0]["id"] == "manual-4-1-2-search-open"
    assert cases[0]["recommendedMethod"] == "screen-reader"
    assert cases[0]["currentStatus"] == "pass"


def test_runtime_config_and_catalog_mapping_rendering_plans_has_metadata(
    tmp_path: Path,
) -> None:
    # Arrange
    matrix = Matrix(
        criteria=[
            Criterion(id="4.1.2", framework="wcag-22", title="Name, Role, Value")
        ],
        surfaces=[
            Surface(
                id="dialog",
                name="Dialog",
                platform="web",
                widgetPattern="dialog-modal",
            )
        ],
        cells=[
            Cell(
                criterionId="4.1.2",
                surfaceId="dialog",
                state="open",
                status="unknown",
            )
        ],
    )
    runtime_config = {
        "surfaces": [
            {
                "id": "dialog",
                "widgetPattern": "dialog-modal",
                "states": [
                    {
                        "state": "open",
                        "ariaAt": {
                            "commands": [
                                {"kind": "key", "value": "Escape"},
                                {"kind": "pause", "durationMs": 100},
                            ],
                            "assertions": [{"type": "contains", "value": "dialog"}],
                        },
                    }
                ],
            }
        ]
    }
    markdown_path = tmp_path / "plan.md"
    yaml_path = tmp_path / "plan.yaml"

    # Act
    render_manual_test_plan_markdown(matrix, markdown_path, "octo/repo", runtime_config)
    render_manual_test_plan_yaml(matrix, yaml_path, "octo/repo", runtime_config)

    # Assert
    markdown = markdown_path.read_text(encoding="utf-8")
    yaml = yaml_path.read_text(encoding="utf-8")
    assert "ariaAt" in markdown
    assert "ARIA-AT mapping ID: aria-at-modal-dialog" in markdown
    assert "Immutable source:" in markdown
    assert "Upstream SHA:" in markdown
    assert "#### Mapping Commands" in markdown
    assert "#### Executable NVDA Variants" in markdown
    assert "#### Manual JAWS Variants" in markdown
    assert 'mappingStatus: "mapped"' in yaml
    assert "automationEligible: false" in yaml
    assert 'upstreamTestId: "openModalDialog"' in yaml
    assert 'kind: "key"' in yaml
    assert 'value: "Escape"' in yaml
    assert "durationMs: 100" in yaml
    assert "manualEvidenceRequired: true" in yaml
    assert "runbookReference: " in yaml
    assert "          commands: []" in yaml
    assert "          assertions: []" in yaml


def test_given_manual_cases_when_rendering_plans_then_markdown_and_yaml_align(
    tmp_path: Path,
) -> None:
    # Arrange
    markdown_path = tmp_path / "plan.md"
    yaml_path = tmp_path / "plan.yaml"

    # Act
    render_manual_test_plan_markdown(_matrix(), markdown_path, "octo/repo")
    render_manual_test_plan_yaml(_matrix(), yaml_path, "octo/repo")

    # Assert
    markdown = markdown_path.read_text(encoding="utf-8")
    yaml = yaml_path.read_text(encoding="utf-8")
    assert markdown.startswith("<!-- markdownlint-disable-file -->")
    assert "# Manual Accessibility Test Plan" in markdown
    assert "manual-4-1-2-search-open" in markdown
    assert "- [ ] Reviewed and validated by a qualified human reviewer" in markdown
    assert "nvda-open" in markdown
    assert "Executable NVDA Variants" in markdown
    assert "Manual JAWS Variants" in markdown
    assert 'repository: "octo/repo"' in yaml
    assert 'recommendedMethod: "screen-reader"' in yaml
    assert 'outcome: "not-run"' in yaml


def test_given_no_pending_human_cases_when_rendering_then_empty_layout_is_valid(
    tmp_path: Path,
) -> None:
    # Arrange
    matrix = _matrix()
    matrix.cells = [matrix.cells[1]]
    markdown_path = tmp_path / "plan.md"
    yaml_path = tmp_path / "plan.yaml"

    # Act
    render_manual_test_plan_markdown(matrix, markdown_path, "octo/repo")
    render_manual_test_plan_yaml(matrix, yaml_path, "octo/repo")

    # Assert
    assert "* None" in markdown_path.read_text(encoding="utf-8")
    assert "cases: []" in yaml_path.read_text(encoding="utf-8")


def test_given_repository_slug_when_resolving_paths_then_names_are_portable(
    tmp_path: Path,
) -> None:
    # Act
    paths = artifact_paths(tmp_path, "Microsoft/HVE Core")
    fallback = artifact_paths(tmp_path, "///")

    # Assert
    assert (
        paths.earl_jsonld.name == "accessibility-results-microsoft-hve-core.earl.jsonld"
    )
    assert paths.manual_plan_yaml.name == "manual-at-testplan-microsoft-hve-core.yaml"
    assert fallback.manifest_json.name == "accessibility-artifacts-repository.json"


def test_given_matrix_when_rendering_bundle_then_manifest_lists_all_artifacts(
    tmp_path: Path,
) -> None:
    # Arrange
    matrix = _matrix()
    coverage = compute_coverage(matrix)

    # Act
    paths = render_artifact_bundle(matrix, coverage, tmp_path, "octo/repo")

    # Assert
    manifest = json.loads(paths.manifest_json.read_text(encoding="utf-8"))
    assert all(
        path.exists()
        for path in (
            paths.coverage_json,
            paths.coverage_markdown,
            paths.earl_jsonld,
            paths.manual_plan_markdown,
            paths.manual_plan_yaml,
            paths.manifest_json,
        )
    )
    assert manifest["repository"] == "octo/repo"
    assert set(manifest["artifacts"]) == {
        "coverageJson",
        "coverageMarkdown",
        "earlJsonLd",
        "manualTestPlanMarkdown",
        "manualTestPlanYaml",
    }


def test_given_scalar_types_when_rendering_yaml_then_values_are_valid() -> None:
    # Act and Assert
    assert _yaml_scalar(True) == "true"
    assert _yaml_scalar(False) == "false"
    assert _yaml_scalar(None) == "null"
    assert _yaml_scalar("text") == '"text"'
