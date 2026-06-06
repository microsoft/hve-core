# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Entry-point and parser tests for mural.py."""

from __future__ import annotations

import argparse
from typing import Any

import pytest


def test_build_parser_registers_top_level_commands(mural_module: Any) -> None:
    parser = mural_module._build_parser()

    args = parser.parse_args(["auth", "status"])

    assert args.command == "auth"
    assert args.auth_command == "status"
    assert args.func is mural_module._cmd_auth_status


def test_build_parser_routes_widget_create_sticky_note(mural_module: Any) -> None:
    parser = mural_module._build_parser()

    args = parser.parse_args(
        [
            "widget",
            "create",
            "sticky-note",
            "--mural",
            "workspace1.mural-abc123",
            "--text",
            "hello",
            "--x",
            "10",
            "--y",
            "20",
        ]
    )

    assert args.command == "widget"
    assert args.widget_command == "create"
    assert args.widget_create_kind == "sticky-note"
    assert args.func is mural_module._cmd_widget_create_sticky_note
    assert args.text == "hello"
    assert args.x == 10.0
    assert args.y == 20.0


def test_build_parser_help_exits_zero(
    mural_module: Any,
    capsys: pytest.CaptureFixture[str],
) -> None:
    parser = mural_module._build_parser()

    with pytest.raises(SystemExit) as exc_info:
        parser.parse_args(["--help"])

    assert exc_info.value.code == 0
    assert "mural" in capsys.readouterr().out.lower()


def test_main_dispatches_to_func(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    seen: list[argparse.Namespace] = []

    def fake_func(args: argparse.Namespace) -> int:
        seen.append(args)
        return mural_module.EXIT_SUCCESS

    fake_args = argparse.Namespace(log_level="WARNING", func=fake_func)

    class FakeParser:
        def parse_args(self, argv: list[str] | None = None) -> argparse.Namespace:
            return fake_args

        def print_help(self, *args: Any, **kwargs: Any) -> None:
            return None

    monkeypatch.setattr(mural_module, "_build_parser", FakeParser)

    result = mural_module.main([])

    assert result == mural_module.EXIT_SUCCESS
    assert seen == [fake_args]


def test_main_returns_failure_for_mural_error(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    def boom(_args: argparse.Namespace) -> int:
        raise mural_module.MuralError("boom")

    fake_args = argparse.Namespace(log_level="WARNING", func=boom)

    class FakeParser:
        def parse_args(self, argv: list[str] | None = None) -> argparse.Namespace:
            return fake_args

        def print_help(self, *args: Any, **kwargs: Any) -> None:
            return None

    monkeypatch.setattr(mural_module, "_build_parser", FakeParser)

    result = mural_module.main([])

    assert result == mural_module.EXIT_FAILURE
    assert "boom" in capsys.readouterr().err


def test_main_returns_usage_when_no_func(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    fake_args = argparse.Namespace(log_level="WARNING")
    printed: list[Any] = []

    class FakeParser:
        def parse_args(self, argv: list[str] | None = None) -> argparse.Namespace:
            return fake_args

        def print_help(self, file: Any = None) -> None:
            printed.append(file)

    monkeypatch.setattr(mural_module, "_build_parser", FakeParser)

    result = mural_module.main([])

    assert result == mural_module.EXIT_USAGE
    assert printed  # print_help was invoked


# ---------------------------------------------------------------------------
# Phase 4: exit-code matrix
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "scenario",
    [
        pytest.param("ok", id="exit-0-ok"),
        pytest.param(
            "config_error",
            id="exit-78-config-error",
            marks=pytest.mark.skip(
                reason="depends on Phase 7.3 exception envelope (EX_CONFIG=78)"
            ),
        ),
        pytest.param(
            "data_error",
            id="exit-65-data-error",
            marks=pytest.mark.skip(
                reason="depends on Phase 7.3 exception envelope (EX_DATAERR=65)"
            ),
        ),
        pytest.param(
            "unavailable",
            id="exit-69-unavailable",
            marks=pytest.mark.skip(
                reason="depends on Phase 7.3 exception envelope (EX_UNAVAILABLE=69)"
            ),
        ),
        pytest.param(
            "noperm",
            id="exit-77-noperm",
            marks=pytest.mark.skip(
                reason="depends on Phase 7.3 exception envelope (EX_NOPERM=77)"
            ),
        ),
        pytest.param(
            "tempfail",
            id="exit-75-tempfail",
            marks=pytest.mark.skip(
                reason="depends on Phase 7.3 exception envelope (EX_TEMPFAIL=75)"
            ),
        ),
        pytest.param(
            "protocol",
            id="exit-76-protocol",
            marks=pytest.mark.skip(
                reason="depends on Phase 7.3 exception envelope (EX_PROTOCOL=76)"
            ),
        ),
        pytest.param(
            "sigint",
            id="exit-130-sigint",
        ),
        pytest.param(
            "sigpipe",
            id="exit-141-sigpipe",
        ),
    ],
)
def test_main_exit_code_matrix(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch, scenario: str
) -> None:
    """Step 4.8: enumerate stable CLI exit codes; only ok=0 is wired today."""
    expected = {
        "ok": mural_module.EXIT_SUCCESS,
        "sigint": 130,
        "sigpipe": 141,
    }[scenario]

    def _ok(_a: Any) -> int:
        return mural_module.EXIT_SUCCESS

    def _raise_sigint(_a: Any) -> int:
        raise KeyboardInterrupt

    def _raise_sigpipe(_a: Any) -> int:
        raise BrokenPipeError

    func_map = {"ok": _ok, "sigint": _raise_sigint, "sigpipe": _raise_sigpipe}

    fake_args = argparse.Namespace(
        log_level="WARNING",
        func=func_map[scenario],
    )

    class FakeParser:
        def parse_args(self, argv: list[str] | None = None) -> argparse.Namespace:
            return fake_args

        def print_help(self, *args: Any, **kwargs: Any) -> None:
            return None

    monkeypatch.setattr(mural_module, "_build_parser", FakeParser)

    assert mural_module.main([]) == expected
