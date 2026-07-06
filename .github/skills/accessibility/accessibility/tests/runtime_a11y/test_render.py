# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from runtime_a11y.matrix._model import Cell, Criterion, Matrix, Surface
from runtime_a11y.matrix._render_json import render_json
from runtime_a11y.matrix._render_md import render_markdown


def _sample_matrix() -> Matrix:
    return Matrix(
        criteria=[
            Criterion(
                id="1.3.1",
                framework="wcag-22",
                title="Info and Relationships",
                adequateMethods={"axe-auto"},
            )
        ],
        surfaces=[Surface(id="web", name="Web", platform="web", states=["default"])],
        cells=[
            Cell(
                criterionId="1.3.1",
                surfaceId="web",
                state="default",
                status="pass",
                verifiedByMethod="axe-auto",
                date="2026-01-01",
                evidence="probe-axe (report.json)",
                severity="minor",
                rationale="auto",
                requiredMethods={"axe-auto"},
                adequateMethods={"axe-auto"},
                isApplicable=True,
                methodProvenance="axe-auto",
            )
        ],
    )


def _sample_coverage() -> dict[str, Any]:
    return {
        "overall": {"coverage": 50.0, "numerator": 1, "denominator": 2},
        "frameworks": {"wcag-22": {"coverage": 50.0, "numerator": 1, "denominator": 2}},
        "residual": [
            {
                "criterionId": "2.4.7",
                "surfaceId": "web",
                "state": "default",
                "status": "fail",
                "verifiedByMethod": "manual-keyboard",
            }
        ],
        "nextActions": [
            {
                "criterionId": "2.4.7",
                "surfaceId": "web",
                "state": "default",
                "priority": "human",
            }
        ],
    }


def test_render_json_writes_matrix_and_coverage(tmp_path: Path) -> None:
    out = tmp_path / "matrix.json"

    render_json(_sample_matrix(), _sample_coverage(), out)

    payload = json.loads(out.read_text(encoding="utf-8"))
    assert payload["criteria"][0]["id"] == "1.3.1"
    assert payload["criteria"][0]["adequateMethods"] == ["axe-auto"]
    assert payload["surfaces"][0]["id"] == "web"
    assert payload["cells"][0]["requiredMethods"] == ["axe-auto"]
    assert payload["cells"][0]["adequateMethods"] == ["axe-auto"]
    assert payload["coverage"]["overall"]["coverage"] == 50.0


def test_render_json_creates_parent_directories(tmp_path: Path) -> None:
    out = tmp_path / "nested" / "deep" / "matrix.json"

    render_json(_sample_matrix(), _sample_coverage(), out)

    assert out.exists()


def test_render_markdown_includes_summary_table_and_residual(tmp_path: Path) -> None:
    out = tmp_path / "matrix.md"

    render_markdown(_sample_matrix(), _sample_coverage(), out, repo_slug="octo/repo")

    text = out.read_text(encoding="utf-8")
    assert "# Accessibility Coverage Matrix" in text
    assert "Reviewed and validated by a qualified human reviewer" in text
    assert "Disclaimer:" in text
    assert "Repository: octo/repo" in text
    assert "| wcag-22 | 50.0% | 1 | 2 |" in text
    assert "### manual-keyboard" in text
    assert "- 2.4.7 / web / default (fail)" in text
    assert "- 2.4.7 / web / default (human)" in text


def test_render_markdown_handles_empty_residual_and_next_actions(
    tmp_path: Path,
) -> None:
    out = tmp_path / "matrix.md"
    coverage: dict[str, Any] = {
        "overall": {"coverage": 0.0},
        "frameworks": {},
        "residual": [],
        "nextActions": [],
    }

    render_markdown(_sample_matrix(), coverage, out, repo_slug="octo/repo")

    text = out.read_text(encoding="utf-8")
    assert "## Residual by Method" in text
    assert "## Next Actions" in text
    # Both the residual and next-actions else-branches render a "- None" bullet.
    assert text.count("- None") == 2
