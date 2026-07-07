# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from __future__ import annotations

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


def test_run_probe_raises_on_called_process_error(mocker) -> None:
    mocker.patch(
        "runtime_a11y.__main__.subprocess.run",
        side_effect=subprocess.CalledProcessError(1, "npx", stderr="boom"),
    )

    with pytest.raises(ScriptError) as excinfo:
        cli._run_probe(
            {}, "probe-axe", "web", "default", "http://127.0.0.1:3000", False
        )

    assert "boom" in str(excinfo.value)


def test_run_probe_raises_on_invalid_json(mocker) -> None:
    mocker.patch(
        "runtime_a11y.__main__.subprocess.run",
        return_value=SimpleNamespace(stdout="not json", stderr=""),
    )

    with pytest.raises(ScriptError):
        cli._run_probe(
            {}, "probe-axe", "web", "default", "http://127.0.0.1:3000", False
        )


def test_write_output_prints_to_stdout_when_no_path(capsys) -> None:
    cli._write_output({"a": 1}, None)

    assert '"a": 1' in capsys.readouterr().out
