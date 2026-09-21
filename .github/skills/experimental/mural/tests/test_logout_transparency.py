# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
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


# ---------------------------------------------------------------------------
# removed_keys names the credentials that were actually deleted
#
# Every test above passes --keep-credentials, so none of them reach
# ``_logout_remove_credentials``. The tests below close that gap: they pin the
# *content* of ``removed_keys`` rather than only the presence of transparency
# lines. ``_KNOWN_CREDENTIAL_KEYS`` holds env-style identifiers, not secret
# values, so masking them discloses nothing and only hides which credentials an
# operator just deleted.
# ---------------------------------------------------------------------------


class _RecordingBackend:
    """Backend stub holding every known credential key for one service."""

    name = "stub"

    def __init__(self) -> None:
        self.deleted: list[str] = []

    def get(self, service: str, key: str) -> str | None:
        return "stored-value"

    def delete(self, service: str, key: str) -> None:
        self.deleted.append(key)


def test_logout_removed_keys_are_real_credential_key_names(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    """``removed_keys`` reports the deleted key names, never a mask."""
    backend = _RecordingBackend()
    monkeypatch.setattr(mural_module, "resolve_backend", lambda profile: backend)

    entry = mural_module._logout_remove_credentials(
        "default", require_force_for_file=False
    )

    assert entry["status"] == "removed"
    assert entry["removed_keys"] == list(mural_module._KNOWN_CREDENTIAL_KEYS)
    assert "MURAL_CLIENT_SECRET" in entry["removed_keys"]
    assert "***" not in entry["removed_keys"]
    assert backend.deleted == list(mural_module._KNOWN_CREDENTIAL_KEYS)


def test_logout_summary_names_each_removed_key(
    mural_module: Any, capsys: pytest.CaptureFixture[str]
) -> None:
    """The operator-facing summary spells out which keys were removed."""
    mural_module._emit_logout_credential_summary(
        {
            "profile": "default",
            "backend": "keyring",
            "status": "removed",
            "removed_keys": list(mural_module._KNOWN_CREDENTIAL_KEYS),
        }
    )

    err = capsys.readouterr().err
    for key in mural_module._KNOWN_CREDENTIAL_KEYS:
        assert key in err
    assert "***" not in err


def test_logout_partial_summary_names_removed_and_errored_keys(
    mural_module: Any, capsys: pytest.CaptureFixture[str]
) -> None:
    """A partial removal distinguishes what was removed from what failed."""
    mural_module._emit_logout_credential_summary(
        {
            "profile": "default",
            "backend": "keyring",
            "status": "partial",
            "removed_keys": ["MURAL_CLIENT_ID"],
            "errors": {"MURAL_CLIENT_SECRET": "delete failed: locked"},
        }
    )

    err = capsys.readouterr().err
    assert "MURAL_CLIENT_ID" in err
    assert "MURAL_CLIENT_SECRET" in err
    assert "***" not in err


def test_logout_json_envelope_preserves_removed_key_names(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    fake_token_store: pathlib.Path,
    capsys: pytest.CaptureFixture[str],
) -> None:
    """Key names survive the stdout redaction barrier in ``_emit_json``.

    ``removed_keys`` is not a sensitive mapping key and its values are bare
    identifiers, so neither the key-aware nor the pattern-based arm of
    ``_redact_payload`` should touch them.
    """
    _seed_envelope(fake_token_store, {"alpha": _profile("cid-alpha")}, active="alpha")
    monkeypatch.setattr(
        mural_module, "resolve_backend", lambda profile: _RecordingBackend()
    )

    rc = mural_module.main(["auth", "logout", "--profile", "alpha", "--json"])

    assert rc == mural_module.EXIT_SUCCESS
    payload = json.loads(capsys.readouterr().out)
    removed = payload["credentials_removed"][0]["removed_keys"]
    assert removed == list(mural_module._KNOWN_CREDENTIAL_KEYS)
    assert "MURAL_CLIENT_SECRET" in removed
