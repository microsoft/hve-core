# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

from __future__ import annotations

from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

import pytest
import scan


def test_given_parser_when_target_and_output_provided_then_arguments_are_parsed(
) -> None:
    parser = scan.create_parser()

    args = parser.parse_args(["https://example.com", "--output", "report.json"])

    assert args.target == "https://example.com"
    assert args.output == Path("report.json")


@pytest.mark.parametrize(
    ("raw_results", "expected_violation_ids"),
    [
        (
            {
                "violations": [
                    {
                        "id": "color-contrast",
                        "impact": "serious",
                        "description": "Text contrast must be sufficient",
                        "nodes": [{"target": ["#btn"]}],
                    }
                ],
                "passes": [{"id": "passthrough"}],
                "incomplete": [{"id": "incomplete"}],
                "inapplicable": [{"id": "inapplicable"}],
            },
            ["color-contrast"],
        ),
        (
            {
                "results": [
                    {
                        "violations": [
                            {
                                "id": "link-name",
                                "impact": "minor",
                                "description": "Links must have discernible names",
                                "nodes": [{"target": ["a"]}],
                            }
                        ]
                    }
                ]
            },
            ["link-name"],
        ),
    ],
)
def test_given_raw_results_when_normalize_results_then_returns_stable_shape(
    raw_results: dict[str, object],
    expected_violation_ids: list[str],
) -> None:
    normalized = scan.normalize_results(raw_results, target="https://example.com")

    assert normalized["target"] == "https://example.com"
    assert normalized["summary"]["violations"] == len(expected_violation_ids)
    assert [
        violation["id"] for violation in normalized["violations"]
    ] == expected_violation_ids
    assert normalized["violations"][0]["nodes"] == 1


def test_given_scanner_unavailable_when_run_scan_then_raises_actionable_error() -> None:
    with patch("scan.subprocess.run", side_effect=FileNotFoundError("npx")):
        with pytest.raises(scan.ScriptError, match="Node-based axe scanner"):
            scan.run_scan("https://example.com")


def test_given_target_when_run_scan_then_invokes_scanner_with_list_arguments() -> None:
    with patch("scan.subprocess.run") as mock_run:
        mock_run.return_value = SimpleNamespace(
            returncode=0,
            stdout='{"violations": []}',
            stderr="",
        )

        result = scan.run_scan("https://example.com")

    assert result["summary"]["violations"] == 0
    command = mock_run.call_args.args[0]
    assert command[0] == "npx"
    assert command[1:3] == ["--yes", "@axe-core/cli"]
    assert command[-1] == "https://example.com"
