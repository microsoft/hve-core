# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Tests for logout transparency emission and active_profile reset (Phase D).

Covers ``_LOGOUT_TRANSPARENCY_LINES`` content/emission across every branch of
``_cmd_auth_logout`` and confirms ``active_profile`` is dropped when its
target is removed.
"""

from __future__ import annotations

import json
import pathlib
from typing import Any

import pytest
from test_constants import (
    ENV_TOKEN_STORE,
    TEST_CLIENT_ID,
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _seed_envelope(
    path: pathlib.Path,
    profiles: dict[str, dict[str, Any]],
    *,
    active: str | None = None,
) -> None:
    envelope: dict[str, Any] = {"schema_version": 2, "profiles": profiles}
    if active is not None:
        envelope["active_profile"] = active
    path.write_text(json.dumps(envelope))


def _profile(client_id: str = TEST_CLIENT_ID) -> dict[str, Any]:
    return {
        "client_id": client_id,
        "access_token": "x",
        "token_type": "Bearer",
        "obtained_at": 0,
        "expires_at": 0,
    }


def _patch_keep_credentials_only(
    monkeypatch: pytest.MonkeyPatch, mural_module: Any
) -> None:
    """No-op patch placeholder: tests pass --keep-credentials to skip backend
    cleanup so we do not need to mock keyring/file backends."""


# ---------------------------------------------------------------------------
# Module-level constant content
# ---------------------------------------------------------------------------


def test_logout_transparency_lines_content(mural_module: Any) -> None:
    lines = mural_module._LOGOUT_TRANSPARENCY_LINES
    assert isinstance(lines, tuple)
    assert len(lines) == 3
    assert lines[0] == "Credentials have been cleared from this machine."
    assert lines[1] == (
        "Your Mural OAuth tokens may remain active server-side until they "
        "expire (access tokens have a documented 15-minute TTL; "
        "refresh tokens persist longer and are not rotated on use)."
    )
    assert lines[2] == (
        "To fully revoke access, visit https://app.mural.co/me/apps and "
        "remove this integration."
    )


def test_emit_logout_transparency_emits_each_line(
    mural_module: Any, capsys: pytest.CaptureFixture[str]
) -> None:
    mural_module._emit_logout_transparency()
    err = capsys.readouterr().err
    for line in mural_module._LOGOUT_TRANSPARENCY_LINES:
        assert line in err


# ---------------------------------------------------------------------------
# --all branch
# ---------------------------------------------------------------------------


def test_logout_all_non_json_emits_transparency(
    mural_module: Any,
    fake_token_store: pathlib.Path,
    capsys: pytest.CaptureFixture[str],
) -> None:
    _seed_envelope(fake_token_store, {"default": _profile()}, active="default")

    rc = mural_module.main(["auth", "logout", "--all", "--keep-credentials"])

    assert rc == mural_module.EXIT_SUCCESS
    err = capsys.readouterr().err
    for line in mural_module._LOGOUT_TRANSPARENCY_LINES:
        assert line in err


def test_logout_all_json_omits_transparency(
    mural_module: Any,
    fake_token_store: pathlib.Path,
    capsys: pytest.CaptureFixture[str],
) -> None:
    _seed_envelope(fake_token_store, {"default": _profile()}, active="default")

    rc = mural_module.main(["auth", "logout", "--all", "--keep-credentials", "--json"])

    assert rc == mural_module.EXIT_SUCCESS
    captured = capsys.readouterr()
    for line in mural_module._LOGOUT_TRANSPARENCY_LINES:
        assert line not in captured.err
        assert line not in captured.out
    payload = json.loads(captured.out)
    assert payload["status"] == "cleared"
    assert payload["scope"] == "all"


def test_logout_all_clears_active_profile(
    mural_module: Any, fake_token_store: pathlib.Path
) -> None:
    _seed_envelope(
        fake_token_store,
        {"alpha": _profile("cid-alpha"), "beta": _profile("cid-beta")},
        active="alpha",
    )

    rc = mural_module.main(["auth", "logout", "--all", "--keep-credentials"])

    assert rc == mural_module.EXIT_SUCCESS
    data = json.loads(fake_token_store.read_text())
    assert data == {
        "schema_version": mural_module.TOKEN_STORE_SCHEMA_VERSION,
        "profiles": {},
    }
    assert "active_profile" not in data


# ---------------------------------------------------------------------------
# Per-profile branch
# ---------------------------------------------------------------------------


def test_logout_per_profile_removed_emits_transparency(
    mural_module: Any,
    fake_token_store: pathlib.Path,
    capsys: pytest.CaptureFixture[str],
) -> None:
    _seed_envelope(
        fake_token_store,
        {"alpha": _profile("cid-alpha"), "beta": _profile("cid-beta")},
        active="beta",
    )

    rc = mural_module.main(
        [
            "auth",
            "logout",
            "--profile",
            "alpha",
            "--keep-credentials",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    err = capsys.readouterr().err
    for line in mural_module._LOGOUT_TRANSPARENCY_LINES:
        assert line in err


def test_logout_per_profile_absent_omits_transparency(
    mural_module: Any,
    fake_token_store: pathlib.Path,
    capsys: pytest.CaptureFixture[str],
) -> None:
    _seed_envelope(
        fake_token_store,
        {"alpha": _profile("cid-alpha")},
        active="alpha",
    )

    rc = mural_module.main(
        [
            "auth",
            "logout",
            "--profile",
            "ghost",
            "--keep-credentials",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    err = capsys.readouterr().err
    for line in mural_module._LOGOUT_TRANSPARENCY_LINES:
        assert line not in err
    assert "not present" in err


def test_logout_per_profile_json_omits_transparency(
    mural_module: Any,
    fake_token_store: pathlib.Path,
    capsys: pytest.CaptureFixture[str],
) -> None:
    _seed_envelope(
        fake_token_store,
        {"alpha": _profile("cid-alpha")},
        active="alpha",
    )

    rc = mural_module.main(
        [
            "auth",
            "logout",
            "--profile",
            "alpha",
            "--keep-credentials",
            "--json",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    captured = capsys.readouterr()
    for line in mural_module._LOGOUT_TRANSPARENCY_LINES:
        assert line not in captured.err
        assert line not in captured.out
    payload = json.loads(captured.out)
    assert payload["profile"] == "alpha"
    assert payload["status"] == "removed"


def test_logout_per_profile_clears_active_when_target_active(
    mural_module: Any, fake_token_store: pathlib.Path
) -> None:
    _seed_envelope(
        fake_token_store,
        {"alpha": _profile("cid-alpha"), "beta": _profile("cid-beta")},
        active="alpha",
    )

    rc = mural_module.main(
        [
            "auth",
            "logout",
            "--profile",
            "alpha",
            "--keep-credentials",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    data = json.loads(fake_token_store.read_text())
    assert "alpha" not in data["profiles"]
    assert "beta" in data["profiles"]
    assert "active_profile" not in data


def test_logout_per_profile_preserves_active_when_target_not_active(
    mural_module: Any, fake_token_store: pathlib.Path
) -> None:
    _seed_envelope(
        fake_token_store,
        {"alpha": _profile("cid-alpha"), "beta": _profile("cid-beta")},
        active="alpha",
    )

    rc = mural_module.main(
        [
            "auth",
            "logout",
            "--profile",
            "beta",
            "--keep-credentials",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    data = json.loads(fake_token_store.read_text())
    assert "beta" not in data["profiles"]
    assert "alpha" in data["profiles"]
    assert data.get("active_profile") == "alpha"


# ---------------------------------------------------------------------------
# Absent token-store branch
# ---------------------------------------------------------------------------


def test_logout_no_store_omits_transparency(
    mural_module: Any,
    tmp_path: pathlib.Path,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    missing = tmp_path / "absent.json"
    monkeypatch.setenv(ENV_TOKEN_STORE, str(missing))

    rc = mural_module.main(["auth", "logout", "--keep-credentials"])

    assert rc == mural_module.EXIT_SUCCESS
    err = capsys.readouterr().err
    for line in mural_module._LOGOUT_TRANSPARENCY_LINES:
        assert line not in err
    assert "no token store" in err


def test_logout_no_store_json_omits_transparency(
    mural_module: Any,
    tmp_path: pathlib.Path,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    missing = tmp_path / "absent.json"
    monkeypatch.setenv(ENV_TOKEN_STORE, str(missing))

    rc = mural_module.main(["auth", "logout", "--keep-credentials", "--json"])

    assert rc == mural_module.EXIT_SUCCESS
    captured = capsys.readouterr()
    for line in mural_module._LOGOUT_TRANSPARENCY_LINES:
        assert line not in captured.err
        assert line not in captured.out
    payload = json.loads(captured.out)
    assert payload["status"] == "absent"


# ---------------------------------------------------------------------------
# OSError branch
# ---------------------------------------------------------------------------


def test_logout_all_oserror_omits_transparency(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    fake_token_store: pathlib.Path,
    capsys: pytest.CaptureFixture[str],
) -> None:
    fake_token_store.write_text(json.dumps({"schema_version": 2, "profiles": {}}))

    def _boom(path: pathlib.Path, data: dict[str, Any]) -> None:
        raise OSError("permission denied")

    monkeypatch.setattr(mural_module, "_save_token_store_locked", _boom)

    rc = mural_module.main(["auth", "logout", "--all", "--keep-credentials"])

    assert rc == mural_module.EXIT_FAILURE
    err = capsys.readouterr().err
    for line in mural_module._LOGOUT_TRANSPARENCY_LINES:
        assert line not in err
