# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from __future__ import annotations

import json
import subprocess
from types import SimpleNamespace

import pytest
import runtime_a11y.__main__ as cli
from runtime_a11y._errors import ScriptError


def test_normalize_probe_id_resolves_prefix_and_rejects_ambiguous() -> None:
    known = {"probe-axe", "probe-contrast"}

    assert cli._normalize_probe_id("axe", known) == "probe-axe"
    assert cli._normalize_probe_id("probe-contrast", known) == "probe-contrast"
    assert cli._normalize_probe_id("unknown", known) is None
    # "probe" is a substring of both known ids -> ambiguous -> None.
    assert cli._normalize_probe_id("probe", known) is None


def test_iter_runs_skips_unknown_and_filtered_probes(monkeypatch) -> None:
    monkeypatch.setattr(cli, "_all_probe_ids", lambda: ["probe-axe", "probe-contrast"])
    config = {
        "surfaces": [{"id": "web"}],
        "probeScoping": [
            {"probe": "does-not-exist", "surfaces": ["web"], "states": ["default"]},
            {"probe": "probe-contrast", "surfaces": ["web"], "states": ["default"]},
        ],
    }

    runs = list(cli._iter_runs(config, probe_filter="probe-axe"))

    # Unknown probe is skipped; probe-contrast is filtered out; probe-axe is unscoped.
    assert runs == []


def test_iter_runs_yields_scoped_combinations(monkeypatch) -> None:
    monkeypatch.setattr(cli, "_all_probe_ids", lambda: ["probe-axe"])
    config = {
        "surfaces": [{"id": "web"}],
        "probeScoping": [
            {"probe": "probe-axe", "surfaces": ["web"], "states": ["default", "dark"]}
        ],
    }

    runs = list(cli._iter_runs(config))

    assert runs == [("probe-axe", "web", "default"), ("probe-axe", "web", "dark")]


def test_run_probe_raises_when_a_failing_probe_produced_no_payload(mocker) -> None:
    mocker.patch.object(cli, "_NODE_MODULES", cli._PACKAGE_DIR)
    mocker.patch(
        "runtime_a11y.__main__.subprocess.run",
        return_value=SimpleNamespace(returncode=1, stdout="", stderr="boom"),
    )

    with pytest.raises(ScriptError) as excinfo:
        cli._run_probe(
            {}, "probe-axe", "web", "default", "http://127.0.0.1:3000", False
        )

    assert "boom" in str(excinfo.value)


def test_run_probe_keeps_a_valid_payload_from_a_failing_probe(mocker) -> None:
    """An operational failure is not a reason to discard findings already made."""
    mocker.patch.object(cli, "_NODE_MODULES", cli._PACKAGE_DIR)
    payload = {"probeId": "probe-real-sr", "results": [{"criterionId": "4.1.2"}]}
    mocker.patch(
        "runtime_a11y.__main__.subprocess.run",
        return_value=SimpleNamespace(
            returncode=1, stdout=json.dumps(payload), stderr="stop unverified"
        ),
    )

    result = cli._run_probe(
        {}, "probe-real-sr", "web", "default", "http://127.0.0.1:3000", False
    )

    assert result["results"] == [{"criterionId": "4.1.2"}]
    assert result["operationalFailure"]["reason"] == "stop unverified"


def test_run_probe_raises_when_dependencies_missing(mocker, tmp_path) -> None:
    mocker.patch.object(cli, "_NODE_MODULES", tmp_path / "missing")
    run = mocker.patch("runtime_a11y.__main__.subprocess.run")

    with pytest.raises(ScriptError) as excinfo:
        cli._run_probe(
            {}, "probe-axe", "web", "default", "http://127.0.0.1:3000", False
        )

    assert "npm ci" in str(excinfo.value)
    run.assert_not_called()


def test_run_visual_review_capture_handles_dependency_and_output_errors(
    mocker, tmp_path
) -> None:
    mocker.patch.object(cli, "_NODE_MODULES", tmp_path / "missing")
    run = mocker.patch("runtime_a11y.__main__.subprocess.run")

    with pytest.raises(ScriptError, match="npm ci"):
        cli._run_visual_review_capture({}, "http://127.0.0.1:3000", tmp_path, False)
    run.assert_not_called()

    mocker.patch.object(cli, "_NODE_MODULES", cli._PACKAGE_DIR)
    mocker.patch(
        "runtime_a11y.__main__.subprocess.run",
        side_effect=subprocess.CalledProcessError(1, "node", stderr="boom"),
    )
    with pytest.raises(ScriptError, match="boom"):
        cli._run_visual_review_capture({}, "http://127.0.0.1:3000", tmp_path, False)

    mocker.patch(
        "runtime_a11y.__main__.subprocess.run",
        return_value=SimpleNamespace(stdout="", stderr=""),
    )
    with pytest.raises(ScriptError, match="no JSON output"):
        cli._run_visual_review_capture({}, "http://127.0.0.1:3000", tmp_path, False)

    mocker.patch(
        "runtime_a11y.__main__.subprocess.run",
        return_value=SimpleNamespace(stdout="not json", stderr=""),
    )
    with pytest.raises(ScriptError, match="invalid JSON output"):
        cli._run_visual_review_capture({}, "http://127.0.0.1:3000", tmp_path, False)


def test_probe_visual_review_server_accepts_loopback_http_responses(mocker) -> None:
    class _Response:
        def __enter__(self) -> "_Response":
            return self

        def __exit__(self, exc_type, exc, tb) -> bool:
            return False

        def getcode(self) -> int:
            return 200

    mocker.patch("runtime_a11y.__main__.urlopen", return_value=_Response())

    assert cli._probe_visual_review_server("http://127.0.0.1:3000/") is True


def test_run_at_plan_handles_unsupported_and_force_execute_cases(
    mocker, tmp_path
) -> None:
    matrix_path = tmp_path / "matrix.json"
    matrix_path.write_text("{}", encoding="utf-8")
    cases = [
        {
            "caseId": "manual-only",
            "automationEligible": False,
            "automationExclusionReason": "human-only",
            "variants": [],
            "commands": [],
            "assertions": [],
        },
        {
            "caseId": "force",
            "automationEligible": False,
            "automationExclusionReason": "human-only",
            "variants": [],
            "commands": [],
            "assertions": [],
        },
    ]
    mocker.patch.object(cli, "_derive_at_plan_cases", return_value=cases)
    mocker.patch.object(cli, "_run_at_plan_case", return_value={"caseId": "force"})

    result = cli.main(
        ["run-at-plan", "--matrix", str(matrix_path), "--driver", "synthetic"]
    )

    assert result == cli.EXIT_SUCCESS


def test_assert_case_urls_allowed_handles_visit_target_shape() -> None:
    runtime_config = {"baseUrl": "http://127.0.0.1:3000"}

    cli._assert_case_urls_allowed(
        runtime_config,
        {"route": "/home"},
        {"action": "visit", "target": {"value": "/visit"}},
        allow_external=False,
    )


def test_run_at_plan_reports_missing_matrix_and_derivation_errors(
    mocker, tmp_path
) -> None:
    missing_path = tmp_path / "missing.json"

    exit_code = cli.main(["run-at-plan", "--matrix", str(missing_path)])

    assert exit_code == cli.EXIT_USAGE

    matrix_path = tmp_path / "matrix.json"
    matrix_path.write_text("{}", encoding="utf-8")
    mocker.patch.object(cli, "_derive_at_plan_cases", side_effect=ValueError("bad"))

    exit_code = cli.main(["run-at-plan", "--matrix", str(matrix_path)])

    assert exit_code == cli.EXIT_USAGE


def test_run_at_plan_reports_human_only_cases_and_executes_eligible_variants(
    mocker, tmp_path
) -> None:
    matrix_path = tmp_path / "matrix.json"
    matrix_path.write_text("{}", encoding="utf-8")
    cases = [
        {
            "caseId": "manual-only",
            "automationEligible": False,
            "automationExclusionReason": "human-only",
            "variants": [],
            "commands": [],
            "assertions": [],
        },
        {
            "caseId": "auto",
            "automationEligible": True,
            "automationExclusionReason": None,
            "commands": ["command"],
            "assertions": ["assert"],
            "variants": [
                {
                    "automationEligible": True,
                    "commands": ["variant-command"],
                    "assertions": ["variant-assert"],
                    "at": "nvda",
                }
            ],
        },
    ]
    mocker.patch.object(cli, "_derive_at_plan_cases", return_value=cases)
    run_case = mocker.patch.object(
        cli, "_run_at_plan_case", side_effect=lambda case, *_args, **_kwargs: case
    )

    result = cli.main(["run-at-plan", "--matrix", str(matrix_path)])

    assert result == cli.EXIT_SUCCESS
    assert run_case.call_count == 1


def test_run_at_plan_marks_cases_without_eligible_variants_as_unsupported(
    mocker, tmp_path
) -> None:
    matrix_path = tmp_path / "matrix.json"
    matrix_path.write_text("{}", encoding="utf-8")
    cases = [
        {
            "caseId": "manual-only",
            "automationEligible": True,
            "automationExclusionReason": None,
            "commands": [],
            "assertions": [],
            "variants": [
                {
                    "automationEligible": False,
                    "commands": [],
                    "assertions": [],
                    "at": None,
                }
            ],
        }
    ]
    mocker.patch.object(cli, "_derive_at_plan_cases", return_value=cases)
    mocker.patch.object(
        cli, "_run_at_plan_case", return_value={"caseId": "manual-only"}
    )

    result = cli.main(["run-at-plan", "--matrix", str(matrix_path)])

    assert result == cli.EXIT_SUCCESS


def test_run_probe_raises_on_invalid_json(mocker) -> None:
    mocker.patch.object(cli, "_NODE_MODULES", cli._PACKAGE_DIR)
    mocker.patch(
        "runtime_a11y.__main__.subprocess.run",
        return_value=SimpleNamespace(returncode=0, stdout="not json", stderr=""),
    )

    with pytest.raises(ScriptError):
        cli._run_probe(
            {}, "probe-axe", "web", "default", "http://127.0.0.1:3000", False
        )


def test_write_output_prints_to_stdout_when_no_path(capsys) -> None:
    cli._write_output({"a": 1}, None)

    assert '"a": 1' in capsys.readouterr().out


def test_load_runtime_config_returns_none_when_path_is_absent() -> None:
    # Act
    result = cli._load_runtime_config(None)

    # Assert
    assert result is None


def test_load_runtime_config_wraps_file_errors_as_usage_errors(
    mocker, tmp_path
) -> None:
    # Arrange
    config_path = tmp_path / "runtime.json"
    mocker.patch(
        "runtime_a11y.__main__.load_validated_config",
        side_effect=OSError("unreadable"),
    )

    # Act & Assert
    with pytest.raises(ScriptError) as exc_info:
        cli._load_runtime_config(config_path)

    assert exc_info.value.exit_code == cli.EXIT_USAGE


def test_run_at_plan_case_reports_missing_node_as_usage_error(mocker) -> None:
    # Arrange
    mocker.patch(
        "runtime_a11y.__main__.subprocess.run",
        side_effect=FileNotFoundError("node"),
    )

    # Act & Assert
    with pytest.raises(ScriptError, match="Node is unavailable") as exc_info:
        cli._run_at_plan_case({"caseId": "case-1"}, "synthetic", False)

    assert exc_info.value.exit_code == cli.EXIT_USAGE


def test_run_at_plan_case_reports_executor_process_errors(mocker) -> None:
    # Arrange
    mocker.patch(
        "runtime_a11y.__main__.subprocess.run",
        side_effect=subprocess.CalledProcessError(
            1,
            "node",
            stderr="executor failed",
        ),
    )

    # Act & Assert
    with pytest.raises(ScriptError, match="executor failed"):
        cli._run_at_plan_case({"caseId": "case-1"}, "synthetic", False)


@pytest.mark.parametrize("stdout", ["", "not-json"])
def test_run_at_plan_case_rejects_missing_or_invalid_json(mocker, stdout) -> None:
    # Arrange
    mocker.patch(
        "runtime_a11y.__main__.subprocess.run",
        return_value=SimpleNamespace(stdout=stdout, stderr=""),
    )

    # Act & Assert
    with pytest.raises(ScriptError) as exc_info:
        cli._run_at_plan_case({"caseId": "case-1"}, "synthetic", False)

    assert exc_info.value.exit_code == cli.EXIT_USAGE


def test_run_at_plan_case_returns_executor_json(mocker) -> None:
    # Arrange
    mocker.patch(
        "runtime_a11y.__main__.subprocess.run",
        return_value=SimpleNamespace(
            stdout='{"caseId":"case-1","status":"candidate"}',
            stderr="",
        ),
    )

    # Act
    result = cli._run_at_plan_case({"caseId": "case-1"}, "synthetic", True)

    # Assert
    assert result == {"caseId": "case-1", "status": "candidate"}


def test_run_at_plan_reports_human_only_cases_without_dispatching_driver(
    mocker, tmp_path
) -> None:
    matrix_path = tmp_path / "matrix.json"
    matrix_path.write_text(
        json.dumps(
            {
                "criteria": [
                    {
                        "id": "4.1.2",
                        "framework": "wcag-22",
                        "title": "Name, Role, Value",
                    }
                ],
                "surfaces": [
                    {
                        "id": "dialog",
                        "name": "Dialog",
                        "platform": "web",
                        "widgetPattern": "dialog-modal",
                        "states": ["open"],
                    }
                ],
                "cells": [
                    {
                        "criterionId": "4.1.2",
                        "surfaceId": "dialog",
                        "state": "open",
                        "status": "partial",
                        "adequateMethods": ["screen-reader"],
                    }
                ],
            }
        ),
        encoding="utf-8",
    )
    config_path = tmp_path / "config.json"
    config_path.write_text(
        json.dumps(
            {
                "baseUrl": "http://127.0.0.1:3000",
                "surfaces": [
                    {
                        "id": "dialog",
                        "widgetPattern": "dialog-modal",
                        "states": [
                            {
                                "state": "open",
                                "ariaAt": {
                                    "commands": [],
                                    "assertions": [],
                                },
                            }
                        ],
                    }
                ],
            }
        ),
        encoding="utf-8",
    )
    drive = mocker.patch("runtime_a11y.__main__._run_at_plan_case")

    exit_code = cli.main(
        [
            "run-at-plan",
            "--matrix",
            str(matrix_path),
            "--config",
            str(config_path),
            "--case-id",
            "manual-4-1-2-dialog-open",
        ]
    )

    assert exit_code == 0
    drive.assert_not_called()


def test_run_at_plan_executes_selected_cases_and_writes_report(
    mocker, tmp_path
) -> None:
    matrix_path = tmp_path / "matrix.json"
    matrix_path.write_text(
        json.dumps(
            {
                "criteria": [
                    {
                        "id": "4.1.2",
                        "framework": "wcag-22",
                        "title": "Name, Role, Value",
                    }
                ],
                "surfaces": [
                    {
                        "id": "dialog",
                        "name": "Dialog",
                        "platform": "web",
                        "widgetPattern": "dialog-modal",
                        "states": ["open"],
                    }
                ],
                "cells": [
                    {
                        "criterionId": "4.1.2",
                        "surfaceId": "dialog",
                        "state": "open",
                        "status": "partial",
                        "adequateMethods": ["screen-reader"],
                    }
                ],
            }
        ),
        encoding="utf-8",
    )
    config_path = tmp_path / "config.json"
    config_path.write_text(
        json.dumps(
            {
                "baseUrl": "http://127.0.0.1:3000",
                "surfaces": [
                    {
                        "id": "dialog",
                        "widgetPattern": "dialog-modal",
                        "states": [
                            {
                                "state": "open",
                                "ariaAt": {
                                    "commands": [
                                        {"kind": "command", "value": "Escape"}
                                    ],
                                    "assertions": [
                                        {"type": "contains", "value": "Closed"}
                                    ],
                                },
                            }
                        ],
                    }
                ],
            }
        ),
        encoding="utf-8",
    )
    mocker.patch(
        "runtime_a11y.__main__._run_at_plan_case",
        return_value={"caseId": "manual-4-1-2-dialog-open", "status": "passed"},
    )

    out_path = tmp_path / "report.json"
    exit_code = cli.main(
        [
            "run-at-plan",
            "--matrix",
            str(matrix_path),
            "--config",
            str(config_path),
            "--case-id",
            "manual-4-1-2-dialog-open",
            "--out",
            str(out_path),
        ]
    )

    assert exit_code == 0
    report = json.loads(out_path.read_text(encoding="utf-8"))
    assert report["command"] == "run-at-plan"
    assert report["cases"][0]["status"] == "unsupported"


def test_run_at_plan_reports_executor_failures_as_usage_errors(
    mocker, tmp_path
) -> None:
    matrix_path = tmp_path / "matrix.json"
    matrix_path.write_text(
        json.dumps(
            {
                "criteria": [
                    {
                        "id": "4.1.2",
                        "framework": "wcag-22",
                        "title": "Name, Role, Value",
                    }
                ],
                "surfaces": [
                    {
                        "id": "dialog",
                        "name": "Dialog",
                        "platform": "web",
                        "widgetPattern": "dialog-modal",
                        "states": ["open"],
                    }
                ],
                "cells": [
                    {
                        "criterionId": "4.1.2",
                        "surfaceId": "dialog",
                        "state": "open",
                        "status": "partial",
                        "adequateMethods": ["screen-reader"],
                    }
                ],
            }
        ),
        encoding="utf-8",
    )
    config_path = tmp_path / "config.json"
    config_path.write_text(
        json.dumps(
            {
                "baseUrl": "http://127.0.0.1:3000",
                "surfaces": [
                    {
                        "id": "dialog",
                        "widgetPattern": "dialog-modal",
                        "states": [{"state": "open"}],
                    }
                ],
            }
        ),
        encoding="utf-8",
    )
    mocker.patch(
        "runtime_a11y.__main__._run_at_plan_case",
        side_effect=cli.ScriptError("driver exploded", cli.EXIT_USAGE),
    )

    exit_code = cli.main(
        [
            "run-at-plan",
            "--matrix",
            str(matrix_path),
            "--config",
            str(config_path),
            "--case-id",
            "manual-4-1-2-dialog-open",
            "--driver",
            "synthetic",
        ]
    )

    assert exit_code == cli.EXIT_USAGE


def test_run_at_plan_returns_usage_error_when_no_cases_selected(tmp_path) -> None:
    matrix_path = tmp_path / "matrix.json"
    matrix_path.write_text(
        json.dumps(
            {
                "criteria": [
                    {
                        "id": "4.1.2",
                        "framework": "wcag-22",
                        "title": "Name, Role, Value",
                    }
                ],
                "surfaces": [
                    {
                        "id": "dialog",
                        "name": "Dialog",
                        "platform": "web",
                        "widgetPattern": "dialog-modal",
                        "states": ["open"],
                    }
                ],
                "cells": [
                    {
                        "criterionId": "4.1.2",
                        "surfaceId": "dialog",
                        "state": "open",
                        "status": "partial",
                        "adequateMethods": ["screen-reader"],
                    }
                ],
            }
        ),
        encoding="utf-8",
    )
    config_path = tmp_path / "config.json"
    config_path.write_text(
        json.dumps(
            {
                "baseUrl": "http://127.0.0.1:3000",
                "surfaces": [
                    {
                        "id": "dialog",
                        "widgetPattern": "dialog-modal",
                        "states": [
                            {
                                "state": "open",
                                "ariaAt": {"commands": [], "assertions": []},
                            }
                        ],
                    }
                ],
            }
        ),
        encoding="utf-8",
    )

    exit_code = cli.main(
        [
            "run-at-plan",
            "--matrix",
            str(matrix_path),
            "--config",
            str(config_path),
            "--case-id",
            "missing-case",
        ]
    )

    assert exit_code == cli.EXIT_USAGE


def test_run_at_plan_supports_synthetic_driver_for_explicit_execution(
    mocker, tmp_path
) -> None:
    matrix_path = tmp_path / "matrix.json"
    matrix_path.write_text(
        json.dumps(
            {
                "criteria": [
                    {
                        "id": "4.1.2",
                        "framework": "wcag-22",
                        "title": "Name, Role, Value",
                    }
                ],
                "surfaces": [
                    {
                        "id": "dialog",
                        "name": "Dialog",
                        "platform": "web",
                        "widgetPattern": "dialog-modal",
                        "states": ["open"],
                    }
                ],
                "cells": [
                    {
                        "criterionId": "4.1.2",
                        "surfaceId": "dialog",
                        "state": "open",
                        "status": "partial",
                        "adequateMethods": ["screen-reader"],
                    }
                ],
            }
        ),
        encoding="utf-8",
    )
    config_path = tmp_path / "config.json"
    config_path.write_text(
        json.dumps(
            {
                "baseUrl": "http://127.0.0.1:3000",
                "surfaces": [
                    {
                        "id": "dialog",
                        "widgetPattern": "dialog-modal",
                        "states": [{"state": "open"}],
                    }
                ],
            }
        ),
        encoding="utf-8",
    )
    mocker.patch(
        "runtime_a11y.__main__._run_at_plan_case",
        return_value={"caseId": "manual-4-1-2-dialog-open", "status": "candidate"},
    )

    exit_code = cli.main(
        [
            "run-at-plan",
            "--matrix",
            str(matrix_path),
            "--config",
            str(config_path),
            "--driver",
            "synthetic",
        ]
    )

    assert exit_code == 0
