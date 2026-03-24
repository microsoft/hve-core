# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Entry-point tests for gitlab.py."""

from __future__ import annotations

import gitlab
import pytest
from test_constants import FIELDS_MR, USAGE_MAIN

ARGV_MAIN_LIST = ["gitlab", "mr-list", "opened", "5"]
ARGV_MAIN_FIELDS = ["gitlab", "mr-get", "42", "--fields", "iid,title,author.name"]
ARGV_FIELDS_ONLY = ["gitlab", "--fields", "iid,title"]
EXPECTED_FIELD_SELECTION = [*FIELDS_MR, "author.name"]


class TestMain:
    """Tests for main."""

    def test_dispatches_to_selected_command(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        seen: list[object] = []

        def fake_require_environment() -> None:
            seen.append("env")

        def fake_handler(args: list[str]) -> None:
            seen.append(("handler", args))

        monkeypatch.setattr(gitlab, "require_environment", fake_require_environment)
        monkeypatch.setitem(gitlab.COMMANDS, "mr-list", fake_handler)
        monkeypatch.setattr("sys.argv", ARGV_MAIN_LIST)

        result = gitlab.main()

        assert result == gitlab.EXIT_SUCCESS
        assert seen == ["env", ("handler", ["opened", "5"])]

    def test_main_applies_fields_before_dispatch(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        captured: list[object] = []

        monkeypatch.setattr(
            gitlab, "require_environment", lambda: captured.append("env")
        )

        def fake_handler(args: list[str]) -> None:
            captured.append((args, gitlab.selected_fields))

        monkeypatch.setitem(gitlab.COMMANDS, "mr-get", fake_handler)
        monkeypatch.setattr("sys.argv", ARGV_MAIN_FIELDS)

        result = gitlab.main()

        assert result == gitlab.EXIT_SUCCESS
        assert captured == ["env", (["42"], EXPECTED_FIELD_SELECTION)]

    @pytest.mark.parametrize("argv", [["gitlab"], ["gitlab", "unknown-command"]])
    def test_main_rejects_missing_or_unknown_command(
        self,
        monkeypatch: pytest.MonkeyPatch,
        argv: list[str],
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        monkeypatch.setattr(gitlab, "require_environment", lambda: None)
        monkeypatch.setattr("sys.argv", argv)

        with pytest.raises(SystemExit) as exc_info:
            gitlab.main()

        assert exc_info.value.code == gitlab.EXIT_USAGE
        assert USAGE_MAIN in capsys.readouterr().err

    def test_main_passes_empty_arguments_when_only_fields_are_present(
        self,
        monkeypatch: pytest.MonkeyPatch,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        monkeypatch.setattr(gitlab, "require_environment", lambda: None)
        monkeypatch.setattr("sys.argv", ARGV_FIELDS_ONLY)

        with pytest.raises(SystemExit) as exc_info:
            gitlab.main()

        assert exc_info.value.code == gitlab.EXIT_USAGE
        assert gitlab.selected_fields == FIELDS_MR
        assert USAGE_MAIN in capsys.readouterr().err
