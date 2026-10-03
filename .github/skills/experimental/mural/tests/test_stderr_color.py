# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Tests for ``--color`` resolution and severity-styled stderr messages."""

from __future__ import annotations

import json
import logging
import pathlib
import sys
from typing import Any

import pytest
from test_constants import TEST_CLIENT_ID

ESC = "\x1b"


def _set_flags(mural_module: Any, *, quiet: bool = False, color: bool) -> None:
    mural_module._state.set_cli_flags(
        quiet=quiet, force_json=False, color=color, profile=None
    )


def _seed_store(path: pathlib.Path) -> None:
    profile = {
        "client_id": TEST_CLIENT_ID,
        "access_token": "x",
        "token_type": "Bearer",
        "obtained_at": 0,
        "expires_at": 0,
    }
    path.write_text(
        json.dumps(
            {
                "schema_version": 2,
                "profiles": {"default": profile},
                "active_profile": "default",
            }
        )
    )


# ---------------------------------------------------------------------------
# _color_mode precedence
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    ("choice", "no_color", "force_color", "tty", "expected"),
    [
        ("always", "1", None, False, True),
        ("never", None, "1", True, False),
        ("auto", "1", "1", True, False),
        ("auto", "", "1", False, True),
        ("auto", None, "1", False, True),
        ("auto", None, "", True, True),
        ("auto", None, "", False, False),
        ("auto", None, None, True, True),
        ("auto", None, None, False, False),
        (None, None, None, False, False),
    ],
)
def test_color_mode_precedence(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    choice: str | None,
    no_color: str | None,
    force_color: str | None,
    tty: bool,
    expected: bool,
) -> None:
    for name, value in (("NO_COLOR", no_color), ("FORCE_COLOR", force_color)):
        if value is None:
            monkeypatch.delenv(name, raising=False)
        else:
            monkeypatch.setenv(name, value)
    monkeypatch.setattr(sys.stderr, "isatty", lambda: tty, raising=False)
    assert mural_module._color_mode(choice) is expected


def test_color_mode_treats_unusable_stderr_as_no_tty(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.delenv("NO_COLOR", raising=False)
    monkeypatch.delenv("FORCE_COLOR", raising=False)

    def closed() -> bool:
        raise ValueError("I/O operation on closed file")

    monkeypatch.setattr(sys.stderr, "isatty", closed, raising=False)
    assert mural_module._color_mode("auto") is False


# ---------------------------------------------------------------------------
# _stderr_color_enabled
# ---------------------------------------------------------------------------


def test_stderr_color_disabled_under_json(mural_module: Any) -> None:
    assert mural_module._stderr_color_enabled("always", force_json=True) is False


def test_stderr_color_follows_color_mode_off_windows(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(sys, "platform", "linux")
    assert mural_module._stderr_color_enabled("always", force_json=False) is True
    assert mural_module._stderr_color_enabled("never", force_json=False) is False


@pytest.mark.parametrize("vt_available", [True, False])
def test_stderr_color_on_windows_requires_vt_processing(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch, vt_available: bool
) -> None:
    output = sys.modules["mural._output"]
    monkeypatch.setattr(sys, "platform", "win32")
    monkeypatch.setattr(output, "_enable_windows_vt", lambda: vt_available)
    assert (
        mural_module._stderr_color_enabled("always", force_json=False) is vt_available
    )


def test_stderr_color_skips_windows_probe_when_disabled(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    output = sys.modules["mural._output"]
    monkeypatch.setattr(sys, "platform", "win32")

    def probe() -> bool:
        raise AssertionError("console probed while color is off")

    monkeypatch.setattr(output, "_enable_windows_vt", probe)
    assert mural_module._stderr_color_enabled("never", force_json=False) is False


# ---------------------------------------------------------------------------
# _emit styling
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    ("level", "sgr"),
    [
        (logging.CRITICAL, "1;31"),
        (logging.ERROR, "1;31"),
        (logging.WARNING, "33"),
        (logging.INFO, "36"),
        (logging.DEBUG, "2"),
        (5, "2"),
    ],
)
def test_emit_styles_stderr_by_level(
    mural_module: Any, capsys: pytest.CaptureFixture[str], level: int, sgr: str
) -> None:
    _set_flags(mural_module, color=True)
    mural_module._emit("hello", level=level)
    assert capsys.readouterr().err == f"{ESC}[{sgr}mhello{ESC}[0m\n"


def test_emit_levels_have_distinct_styles(mural_module: Any) -> None:
    styles = [sgr for _, sgr in sys.modules["mural._output"]._LEVEL_STYLES]
    assert len(set(styles)) == len(styles) == 4


def test_emit_is_plain_when_color_disabled(
    mural_module: Any, capsys: pytest.CaptureFixture[str]
) -> None:
    _set_flags(mural_module, color=False)
    for level in (logging.ERROR, logging.WARNING, logging.INFO, logging.DEBUG):
        mural_module._emit("plain", level=level)
    err = capsys.readouterr().err
    assert ESC not in err
    assert err == "plain\n" * 4


def test_emit_redacts_before_styling(
    mural_module: Any, capsys: pytest.CaptureFixture[str]
) -> None:
    _set_flags(mural_module, color=True)
    mural_module._emit("POST /token access_token=ATKN", level=logging.WARNING)
    err = capsys.readouterr().err
    assert "ATKN" not in err
    expected = mural_module._redact("POST /token access_token=ATKN")
    assert err == f"{ESC}[33m{expected}{ESC}[0m\n"


def test_emit_logger_record_is_never_colored(
    mural_module: Any,
    capsys: pytest.CaptureFixture[str],
    caplog: pytest.LogCaptureFixture,
) -> None:
    _set_flags(mural_module, color=True)
    caplog.set_level(logging.DEBUG, logger="mural")
    mural_module._emit("to the log", level=logging.WARNING)
    capsys.readouterr()
    assert [r.getMessage() for r in caplog.records] == ["to the log"]
    assert ESC not in caplog.text


def test_emit_quiet_suppresses_the_same_lines_when_colored(
    mural_module: Any, capsys: pytest.CaptureFixture[str]
) -> None:
    _set_flags(mural_module, quiet=True, color=True)
    mural_module._emit("info", level=logging.INFO)
    mural_module._emit("warn", level=logging.WARNING)
    mural_module._emit("boom", level=logging.ERROR)
    assert capsys.readouterr().err == f"{ESC}[1;31mboom{ESC}[0m\n"


def test_json_writers_are_never_colored(
    mural_module: Any, capsys: pytest.CaptureFixture[str]
) -> None:
    _set_flags(mural_module, color=True)
    mural_module._emit_json({"status": "ok"})
    mural_module._emit_json_error({"error": "bad"})
    captured = capsys.readouterr()
    assert ESC not in captured.out
    assert ESC not in captured.err
    assert json.loads(captured.out) == {"status": "ok"}
    assert json.loads(captured.err) == {"error": "bad"}


# ---------------------------------------------------------------------------
# main() wiring
# ---------------------------------------------------------------------------


def test_main_color_always_styles_stderr_but_not_stdout(
    mural_module: Any,
    fake_token_store: pathlib.Path,
    capsys: pytest.CaptureFixture[str],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(sys, "platform", "linux")
    _seed_store(fake_token_store)

    rc = mural_module.main(
        ["--color", "always", "auth", "logout", "--all", "--keep-credentials"]
    )

    assert rc == mural_module.EXIT_SUCCESS
    captured = capsys.readouterr()
    assert mural_module._state.cli_color() is True
    first_line = mural_module._LOGOUT_TRANSPARENCY_LINES[0]
    assert f"{ESC}[36m{first_line}{ESC}[0m" in captured.err
    assert ESC not in captured.out


def test_main_json_disables_color(
    mural_module: Any,
    fake_token_store: pathlib.Path,
    capsys: pytest.CaptureFixture[str],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(sys, "platform", "linux")
    _seed_store(fake_token_store)

    rc = mural_module.main(
        ["--color", "always", "--json", "auth", "logout", "--all", "--keep-credentials"]
    )

    assert rc == mural_module.EXIT_SUCCESS
    captured = capsys.readouterr()
    assert mural_module._state.cli_color() is False
    assert ESC not in captured.out
    assert ESC not in captured.err
    assert json.loads(captured.out)["status"] == "cleared"


def test_main_color_never_keeps_stderr_plain(
    mural_module: Any,
    fake_token_store: pathlib.Path,
    capsys: pytest.CaptureFixture[str],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("FORCE_COLOR", "1")
    _seed_store(fake_token_store)

    rc = mural_module.main(
        ["--color", "never", "auth", "logout", "--all", "--keep-credentials"]
    )

    assert rc == mural_module.EXIT_SUCCESS
    captured = capsys.readouterr()
    assert ESC not in captured.err
    assert ESC not in captured.out
    for line in mural_module._LOGOUT_TRANSPARENCY_LINES:
        assert f"{line}\n" in captured.err
