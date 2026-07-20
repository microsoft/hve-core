# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from __future__ import annotations

import json
from pathlib import Path
from types import SimpleNamespace

import pytest
import runtime_a11y.__main__ as cli
from runtime_a11y._errors import EXIT_SUCCESS, EXIT_USAGE


@pytest.fixture()
def canned_probe_document() -> dict[str, object]:
    return {
        "probeId": "probe-axe",
        "results": [
            {
                "criterionId": "1.3.1",
                "surfaceId": "web",
                "state": "default",
                "status": "pass",
                "method": "runtime-automation",
            }
        ],
    }


def test_given_run_all_when_subprocess_returns_probe_data_then_aggregates_results(
    mocker, canned_probe_document: dict[str, object], tmp_path: Path
) -> None:
    mocker.patch(
        "runtime_a11y.__main__.subprocess.run",
        return_value=SimpleNamespace(
            stdout=json.dumps(canned_probe_document), stderr=""
        ),
    )
    config_path = tmp_path / "a11y-runtime.config.json"
    config_path.write_text(
        '{"baseUrl": "http://127.0.0.1:3000", '
        '"surfaces": [{"id": "web", "type": "page"}], '
        '"probeScoping": [{"probe": "probe-axe", '
        '"surfaces": ["web"], "states": ["default"]}]}',
        encoding="utf-8",
    )
    out_path = tmp_path / "results.json"

    exit_code = cli.main(
        ["run-all", "--config", str(config_path), "--out", str(out_path)]
    )

    assert exit_code == EXIT_SUCCESS
    document = json.loads(out_path.read_text(encoding="utf-8"))
    assert document["tool"] == "runtime_a11y"
    assert document["results"][0]["criterionId"] == "1.3.1"
    assert document["runs"][0]["probeId"] == "probe-axe"


def test_given_probe_command_when_subprocess_fails_then_returns_usage_error(
    mocker, tmp_path: Path
) -> None:
    mocker.patch(
        "runtime_a11y.__main__.subprocess.run",
        side_effect=FileNotFoundError("npx"),
    )
    config_path = tmp_path / "a11y-runtime.config.json"
    config_path.write_text(
        '{"baseUrl": "http://127.0.0.1:3000", "surfaces": '
        '[{"id": "web", "type": "page"}]}',
        encoding="utf-8",
    )

    exit_code = cli.main(["probe", "probe-axe", "--config", str(config_path)])

    assert exit_code == EXIT_USAGE


def test_given_external_target_without_allowlist_when_run_all_then_returns_usage_error(
    tmp_path: Path,
) -> None:
    config_path = tmp_path / "a11y-runtime.config.json"
    config_path.write_text(
        '{"baseUrl": "https://example.com", '
        '"surfaces": [{"id": "web", "type": "page"}]}',
        encoding="utf-8",
    )

    exit_code = cli.main(["run-all", "--config", str(config_path)])

    assert exit_code == EXIT_USAGE
