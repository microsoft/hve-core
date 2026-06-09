# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""CLI handler tests for mural.py.

Drives commands through ``mural_module.main([...])`` while monkey-patching
network seams (``_authenticated_request``, ``_paginate``, ``_create_asset_url``,
``_upload_to_sas``) and OAuth helpers.  Exercises happy paths, validation
errors, and exit-code mapping for each subcommand registered by
``_add_resource_subcommands`` and the ``auth`` group.
"""

from __future__ import annotations

import json
import pathlib
from typing import Any

import pytest
from test_constants import (
    ENV_DEFAULT_WORKSPACE,
    ENV_ENV_FILE,
    ENV_TOKEN_STORE,
    TEST_CLIENT_ID,
    TEST_MURAL_ID,
    TEST_WIDGET_ID,
    TEST_WORKSPACE_ID,
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _patch_request(
    monkeypatch: pytest.MonkeyPatch,
    mural_module: Any,
    *,
    return_value: Any = None,
    return_values: list[Any] | None = None,
    side_effect: BaseException | None = None,
) -> list[dict[str, Any]]:
    """Replace ``_authenticated_request`` with a recorder."""
    calls: list[dict[str, Any]] = []
    iterator = iter(return_values) if return_values is not None else None

    def _fake(method: str, path: str, **kwargs: Any) -> Any:
        calls.append({"method": method, "path": path, **kwargs})
        if side_effect is not None:
            raise side_effect
        if iterator is not None:
            return next(iterator)
        return return_value

    monkeypatch.setattr(mural_module, "_authenticated_request", _fake)
    return calls


def _patch_paginate(
    monkeypatch: pytest.MonkeyPatch,
    mural_module: Any,
    records: list[Any],
) -> list[dict[str, Any]]:
    """Replace ``_paginate`` with a recorder yielding ``records``."""
    calls: list[dict[str, Any]] = []

    def _fake(method: str, path: str, **kwargs: Any):
        calls.append({"method": method, "path": path, **kwargs})
        yield from records

    monkeypatch.setattr(mural_module, "_paginate", _fake)
    return calls


# ---------------------------------------------------------------------------
# auth login / logout / status
# ---------------------------------------------------------------------------


def test_auth_login_happy_path(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    fake_token_store: pathlib.Path,
) -> None:
    record = {"access_token": "x", "granted_scopes": ["murals:read"]}
    seen: dict[str, Any] = {}

    def _fake_login(*, scopes: str | None, timeout_seconds: int) -> dict[str, Any]:
        seen["scopes"] = scopes
        seen["timeout"] = timeout_seconds
        return dict(record)

    saved: list[tuple[pathlib.Path, dict[str, Any]]] = []

    monkeypatch.setattr(mural_module, "_run_login", _fake_login)
    monkeypatch.setattr(mural_module, "_load_token_store_locked", lambda path: None)
    monkeypatch.setattr(
        mural_module,
        "_save_token_store_locked",
        lambda path, data: saved.append((path, data)),
    )

    rc = mural_module.main(["auth", "login", "--timeout", "12"])

    assert rc == mural_module.EXIT_SUCCESS
    assert seen == {"scopes": None, "timeout": 12}
    assert len(saved) == 1
    saved_path, saved_data = saved[0]
    assert saved_path == fake_token_store
    assert saved_data["schema_version"] == mural_module.TOKEN_STORE_SCHEMA_VERSION
    profile = saved_data["profiles"][mural_module.DEFAULT_PROFILE_NAME]
    assert profile["access_token"] == "x"
    assert "scope" not in profile
    assert profile["client_id"] == TEST_CLIENT_ID
    assert profile["granted_scopes"] == list(mural_module.READ_SCOPES)


def test_auth_login_propagates_mural_error(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    fake_token_store: pathlib.Path,
) -> None:
    def _boom(**_kwargs: Any) -> dict[str, Any]:
        raise mural_module.MuralError("login boom")

    monkeypatch.setattr(mural_module, "_run_login", _boom)

    rc = mural_module.main(["auth", "login"])

    assert rc == mural_module.EXIT_FAILURE


def _patch_login_capture(
    monkeypatch: pytest.MonkeyPatch, mural_module: Any
) -> dict[str, Any]:
    """Stub out ``_run_login`` and store persistence; return the capture dict."""
    seen: dict[str, Any] = {}

    def _fake_login(*, scopes: str | None, timeout_seconds: int) -> dict[str, Any]:
        seen["scopes"] = scopes
        seen["timeout"] = timeout_seconds
        return {
            "access_token": "x",
            "granted_scopes": scopes.split() if scopes else ["murals:read"],
        }

    monkeypatch.setattr(mural_module, "_run_login", _fake_login)
    monkeypatch.setattr(mural_module, "_load_token_store_locked", lambda path: None)
    monkeypatch.setattr(
        mural_module, "_save_token_store_locked", lambda path, data: None
    )
    return seen


def test_auth_login_mural_scopes_env_used_when_no_flags(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    fake_token_store: pathlib.Path,
) -> None:
    seen = _patch_login_capture(monkeypatch, mural_module)
    monkeypatch.setenv("MURAL_SCOPES", "murals:read")

    rc = mural_module.main(["auth", "login"])

    assert rc == mural_module.EXIT_SUCCESS
    assert seen["scopes"] == "murals:read"


def test_auth_login_mural_scopes_env_overrides_write_flag(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    fake_token_store: pathlib.Path,
) -> None:
    seen = _patch_login_capture(monkeypatch, mural_module)
    monkeypatch.setenv("MURAL_SCOPES", "murals:read,workspaces:read")

    rc = mural_module.main(["auth", "login", "--write"])

    assert rc == mural_module.EXIT_SUCCESS
    # Env wins over --write; commas split into individual scopes joined by space.
    assert seen["scopes"] == "murals:read workspaces:read"


def test_auth_login_explicit_scopes_overrides_env(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    fake_token_store: pathlib.Path,
) -> None:
    seen = _patch_login_capture(monkeypatch, mural_module)
    monkeypatch.setenv("MURAL_SCOPES", "murals:read")

    rc = mural_module.main(
        ["auth", "login", "--scopes", "murals:write templates:write"]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert seen["scopes"] == "murals:write templates:write"


def test_auth_login_mural_scopes_whitespace_only_rejected(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    fake_token_store: pathlib.Path,
) -> None:
    called: dict[str, Any] = {}

    def _fake_login(**kwargs: Any) -> dict[str, Any]:
        called["invoked"] = True
        return {"access_token": "x"}

    monkeypatch.setattr(mural_module, "_run_login", _fake_login)
    monkeypatch.setenv("MURAL_SCOPES", "   ")

    rc = mural_module.main(["auth", "login"])

    assert rc == mural_module.EXIT_USAGE
    assert "invoked" not in called


def test_auth_login_default_read_scopes_when_env_unset(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    fake_token_store: pathlib.Path,
) -> None:
    seen = _patch_login_capture(monkeypatch, mural_module)
    monkeypatch.delenv("MURAL_SCOPES", raising=False)

    rc = mural_module.main(["auth", "login"])

    assert rc == mural_module.EXIT_SUCCESS
    # Read-only default leaves scopes=None so _run_login uses DEFAULT_SCOPES.
    assert seen["scopes"] is None


def test_auth_login_write_flag_when_env_unset(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    fake_token_store: pathlib.Path,
) -> None:
    seen = _patch_login_capture(monkeypatch, mural_module)
    monkeypatch.delenv("MURAL_SCOPES", raising=False)

    rc = mural_module.main(["auth", "login", "--write"])

    assert rc == mural_module.EXIT_SUCCESS
    expected = " ".join(mural_module.READ_SCOPES + mural_module.WRITE_SCOPES)
    assert seen["scopes"] == expected


def test_auth_login_short_circuits_when_credentials_present_without_force(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    fake_token_store: pathlib.Path,
    capsys: pytest.CaptureFixture[str],
) -> None:
    """Login exits 0 with hint when credentials exist and --force absent."""

    class _StubBackend:
        name = "stub"

        def get(self, service: str, key: str) -> str | None:
            return "seeded" if key == mural_module.ENV_CLIENT_ID else None

    monkeypatch.setattr(mural_module, "resolve_backend", lambda profile: _StubBackend())

    def _boom(**_kwargs: Any) -> dict[str, Any]:
        raise AssertionError("_run_login must not be invoked")

    monkeypatch.setattr(mural_module, "_run_login", _boom)

    rc = mural_module.main(["auth", "login"])

    assert rc == mural_module.EXIT_SUCCESS
    assert "already has stored credentials" in capsys.readouterr().err


def test_auth_login_proceeds_with_force_when_credentials_present(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    fake_token_store: pathlib.Path,
) -> None:
    """Login with --force ignores stored credentials and runs OAuth."""

    class _StubBackend:
        name = "stub"

        def get(self, service: str, key: str) -> str | None:
            return "seeded" if key == mural_module.ENV_CLIENT_ID else None

    monkeypatch.setattr(mural_module, "resolve_backend", lambda profile: _StubBackend())
    invoked: dict[str, Any] = {}

    def _fake_login(*, scopes: str | None, timeout_seconds: int) -> dict[str, Any]:
        invoked["called"] = True
        return {
            "access_token": "x",
            "granted_scopes": scopes.split() if scopes else ["murals:read"],
        }

    monkeypatch.setattr(mural_module, "_run_login", _fake_login)
    monkeypatch.setattr(mural_module, "_load_token_store_locked", lambda path: None)
    monkeypatch.setattr(
        mural_module, "_save_token_store_locked", lambda path, data: None
    )

    rc = mural_module.main(["auth", "login", "--force"])

    assert rc == mural_module.EXIT_SUCCESS
    assert invoked.get("called") is True


def test_auth_logout_removes_token_store(
    mural_module: Any, fake_token_store: pathlib.Path
) -> None:
    # Seed a v2 envelope so logout has profiles to clear.
    fake_token_store.write_text(
        json.dumps(
            {
                "schema_version": 2,
                "profiles": {
                    "default": {
                        "client_id": TEST_CLIENT_ID,
                        "access_token": "x",
                        "token_type": "Bearer",
                        "obtained_at": 0,
                        "expires_at": 0,
                    },
                },
                "active_profile": "default",
            }
        )
    )

    rc = mural_module.main(["auth", "logout", "--all"])

    assert rc == mural_module.EXIT_SUCCESS
    # --all writes an empty envelope rather than deleting the file.
    assert fake_token_store.exists()
    data = json.loads(fake_token_store.read_text())
    assert data == {"schema_version": 2, "profiles": {}}


def test_auth_logout_missing_store_is_success(
    mural_module: Any,
    tmp_path: pathlib.Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    missing = tmp_path / "absent.json"
    monkeypatch.setenv(ENV_TOKEN_STORE, str(missing))

    rc = mural_module.main(["auth", "logout"])

    assert rc == mural_module.EXIT_SUCCESS


def test_auth_logout_oserror_returns_failure(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    fake_token_store: pathlib.Path,
) -> None:
    # Seed a valid v2 envelope so _load_token_store does not trigger the
    # v1 -> v2 migration save path before reaching the logout handler's
    # try/except (mocked _save_token_store_locked must fire only inside the
    # handler, not during load-time migration).
    fake_token_store.write_text(json.dumps({"schema_version": 2, "profiles": {}}))

    def _boom(path: pathlib.Path, data: dict[str, Any]) -> None:
        raise OSError("permission denied")

    monkeypatch.setattr(mural_module, "_save_token_store_locked", _boom)

    rc = mural_module.main(["auth", "logout", "--all", "--keep-credentials"])

    assert rc == mural_module.EXIT_FAILURE


def test_auth_status_no_store(
    mural_module: Any,
    tmp_path: pathlib.Path,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    missing = tmp_path / "no-store.json"
    monkeypatch.setenv(ENV_TOKEN_STORE, str(missing))
    cred_path = tmp_path / "mural.default.env"
    monkeypatch.setenv(ENV_ENV_FILE, str(cred_path))
    monkeypatch.setenv("MURAL_CREDENTIAL_BACKEND", "env-only")
    monkeypatch.setattr(
        mural_module,
        "_probe_keyring_availability",
        lambda: (False, None, None),
    )

    rc = mural_module.main(["auth", "status"])

    assert rc == mural_module.EXIT_FAILURE
    out = json.loads(capsys.readouterr().out)
    assert out == {
        "authenticated": False,
        "token_store": str(missing),
        "credential_file": str(cred_path),
        "credential_file_exists": False,
        "backend": "env-only",
        "backend_selector": "env-only",
        "keyring_available": False,
        "keyring_backend": None,
        "concurrent_state": {
            "keyring_populated": False,
            "file_populated": False,
            "both_populated": False,
        },
    }


def test_auth_status_with_store(
    mural_module: Any,
    tmp_path: pathlib.Path,
    monkeypatch: pytest.MonkeyPatch,
    fake_token_store: pathlib.Path,
    capsys: pytest.CaptureFixture[str],
) -> None:
    cred_path = tmp_path / "mural.default.env"
    monkeypatch.setenv(ENV_ENV_FILE, str(cred_path))
    monkeypatch.setenv("MURAL_CREDENTIAL_BACKEND", "env-only")
    monkeypatch.setattr(
        mural_module,
        "_probe_keyring_availability",
        lambda: (False, None, None),
    )
    monkeypatch.setattr(
        mural_module,
        "_load_token_store",
        lambda path: {
            "schema_version": 2,
            "profiles": {
                "default": {
                    "client_id": TEST_CLIENT_ID,
                    "access_token": "x",
                    "refresh_token": "y",
                    "token_type": "Bearer",
                    "obtained_at": 0,
                    "granted_scopes": ["murals:read", "murals:write"],
                    "expires_at": 9999,
                },
            },
        },
    )

    rc = mural_module.main(["auth", "status"])

    assert rc == mural_module.EXIT_SUCCESS
    out = json.loads(capsys.readouterr().out)
    assert out == {
        "authenticated": True,
        "token_store": str(fake_token_store),
        "profile": "default",
        "granted_scopes": ["murals:read", "murals:write"],
        "expires_at": 9999,
        "has_refresh_token": True,
        "credential_file": str(cred_path),
        "credential_file_exists": False,
        "backend": "env-only",
        "backend_selector": "env-only",
        "keyring_available": False,
        "keyring_backend": None,
        "concurrent_state": {
            "keyring_populated": False,
            "file_populated": False,
            "both_populated": False,
        },
    }


AUTH_STATUS_UNAUTHENTICATED_KEYS = frozenset(
    {
        "authenticated",
        "token_store",
        "credential_file",
        "credential_file_exists",
        "backend",
        "backend_selector",
        "keyring_available",
        "keyring_backend",
        "concurrent_state",
    }
)
AUTH_STATUS_AUTHENTICATED_KEYS = frozenset(
    AUTH_STATUS_UNAUTHENTICATED_KEYS
    | {"profile", "granted_scopes", "expires_at", "has_refresh_token"}
)


def test_auth_status_unauthenticated_contract(
    mural_module: Any,
    tmp_path: pathlib.Path,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    """Lock the unauthenticated CLI response key set."""
    monkeypatch.setenv(ENV_TOKEN_STORE, str(tmp_path / "no-store.json"))
    monkeypatch.setenv(ENV_ENV_FILE, str(tmp_path / "mural.default.env"))
    monkeypatch.setenv("MURAL_CREDENTIAL_BACKEND", "env-only")
    monkeypatch.setattr(
        mural_module,
        "_probe_keyring_availability",
        lambda: (False, None, None),
    )

    rc = mural_module.main(["auth", "status"])

    assert rc == mural_module.EXIT_FAILURE
    out = json.loads(capsys.readouterr().out)
    assert out["authenticated"] is False
    assert frozenset(out.keys()) == AUTH_STATUS_UNAUTHENTICATED_KEYS


def test_auth_status_authenticated_contract(
    mural_module: Any,
    tmp_path: pathlib.Path,
    monkeypatch: pytest.MonkeyPatch,
    fake_token_store: pathlib.Path,
    capsys: pytest.CaptureFixture[str],
) -> None:
    """Lock the authenticated CLI response key set."""
    monkeypatch.setenv(ENV_ENV_FILE, str(tmp_path / "mural.default.env"))
    monkeypatch.setenv("MURAL_CREDENTIAL_BACKEND", "env-only")
    monkeypatch.setattr(
        mural_module,
        "_probe_keyring_availability",
        lambda: (False, None, None),
    )
    monkeypatch.setattr(
        mural_module,
        "_load_token_store",
        lambda path: {
            "schema_version": 2,
            "profiles": {
                "default": {
                    "client_id": TEST_CLIENT_ID,
                    "access_token": "x",
                    "refresh_token": "y",
                    "token_type": "Bearer",
                    "obtained_at": 0,
                    "granted_scopes": ["murals:read"],
                    "expires_at": 9999,
                },
            },
        },
    )

    rc = mural_module.main(["auth", "status"])

    assert rc == mural_module.EXIT_SUCCESS
    out = json.loads(capsys.readouterr().out)
    assert out["authenticated"] is True
    assert frozenset(out.keys()) == AUTH_STATUS_AUTHENTICATED_KEYS


def test_auth_status_returns_success_when_file_backend_has_credentials_but_no_store(
    mural_module: Any,
    tmp_path: pathlib.Path,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    """Backend-only credential state succeeds when no token store exists."""
    missing = tmp_path / "no-store.json"
    cred_path = tmp_path / "mural.default.env"
    monkeypatch.setenv(ENV_TOKEN_STORE, str(missing))
    monkeypatch.setenv(ENV_ENV_FILE, str(cred_path))
    monkeypatch.setenv("MURAL_CREDENTIAL_BACKEND", "file")
    monkeypatch.delenv("MURAL_CLIENT_ID", raising=False)
    monkeypatch.delenv("MURAL_CLIENT_SECRET", raising=False)
    monkeypatch.delenv("MURAL_REFRESH_TOKEN", raising=False)
    monkeypatch.setattr(
        mural_module,
        "_probe_keyring_availability",
        lambda: (False, None, None),
    )
    file_backend = mural_module.FileBackend(cred_path)
    file_backend.set("ignored", "MURAL_CLIENT_ID", "client-id-value")
    file_backend.set("ignored", "MURAL_CLIENT_SECRET", "client-secret-value")

    rc = mural_module.main(["auth", "status"])

    assert rc == mural_module.EXIT_SUCCESS
    out = json.loads(capsys.readouterr().out)
    assert out["authenticated"] is False
    assert out["concurrent_state"]["file_populated"] is True


def test_auth_status_returns_failure_when_authenticated_profile_has_no_refresh_token(
    mural_module: Any,
    tmp_path: pathlib.Path,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    """Authenticated path fails without a refresh token or backend creds."""
    monkeypatch.setenv(ENV_TOKEN_STORE, str(tmp_path / "store.json"))
    monkeypatch.setenv(ENV_ENV_FILE, str(tmp_path / "mural.default.env"))
    monkeypatch.setenv("MURAL_CREDENTIAL_BACKEND", "env-only")
    monkeypatch.delenv("MURAL_CLIENT_ID", raising=False)
    monkeypatch.delenv("MURAL_CLIENT_SECRET", raising=False)
    monkeypatch.delenv("MURAL_REFRESH_TOKEN", raising=False)
    monkeypatch.setattr(
        mural_module,
        "_probe_keyring_availability",
        lambda: (False, None, None),
    )
    monkeypatch.setattr(
        mural_module,
        "_load_token_store",
        lambda path: {
            "schema_version": 2,
            "profiles": {
                "default": {
                    "client_id": TEST_CLIENT_ID,
                    "access_token": "x",
                    "refresh_token": "",
                    "token_type": "Bearer",
                    "obtained_at": 0,
                    "granted_scopes": ["murals:read"],
                    "expires_at": 9999,
                },
            },
        },
    )

    rc = mural_module.main(["auth", "status"])

    assert rc == mural_module.EXIT_FAILURE
    out = json.loads(capsys.readouterr().out)
    assert out["authenticated"] is True
    assert out["has_refresh_token"] is False


# ---------------------------------------------------------------------------
# Multi-profile resolution + auth setup / list / use
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


def test_resolve_active_profile_precedence(mural_module: Any) -> None:
    store_with_active = {"schema_version": 2, "profiles": {}, "active_profile": "env"}
    store_without_active = {"schema_version": 2, "profiles": {}}

    # CLI value wins over env and envelope.
    assert (
        mural_module._resolve_active_profile(
            store_with_active, {"MURAL_PROFILE": "envvar"}, "cli"
        )
        == "cli"
    )
    # Env wins over envelope when CLI is None.
    assert (
        mural_module._resolve_active_profile(
            store_with_active, {"MURAL_PROFILE": "envvar"}, None
        )
        == "envvar"
    )
    # Envelope wins when env is unset.
    assert mural_module._resolve_active_profile(store_with_active, {}, None) == "env"
    # Falls back to DEFAULT_PROFILE_NAME when nothing else is set.
    assert (
        mural_module._resolve_active_profile(store_without_active, {}, None)
        == mural_module.DEFAULT_PROFILE_NAME
    )


def test_cli_profile_overrides_env(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    fake_token_store: pathlib.Path,
) -> None:
    _seed_envelope(
        fake_token_store,
        {
            "alpha": {
                "client_id": "cid-alpha",
                "access_token": "tok-alpha",
                "token_type": "Bearer",
                "obtained_at": 0,
                "expires_at": 0,
            },
            "beta": {
                "client_id": "cid-beta",
                "access_token": "tok-beta",
                "token_type": "Bearer",
                "obtained_at": 0,
                "expires_at": 0,
            },
        },
        active="alpha",
    )
    monkeypatch.setenv("MURAL_PROFILE", "alpha")

    captured: dict[str, Any] = {}

    def _fake_request(method: str, path: str, **_kwargs: Any) -> dict[str, Any]:
        captured["cli_profile"] = mural_module._state._CLI_PROFILE
        return {"id": TEST_WORKSPACE_ID}

    monkeypatch.setattr(mural_module, "_authenticated_request", _fake_request)

    rc = mural_module.main(
        ["--profile", "beta", "workspace", "get", "--workspace", TEST_WORKSPACE_ID]
    )

    assert rc == mural_module.EXIT_SUCCESS
    # CLI override takes precedence over the MURAL_PROFILE env var.
    assert captured["cli_profile"] == "beta"


def test_auth_setup_non_interactive(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    fake_token_store: pathlib.Path,
) -> None:
    monkeypatch.setenv("MURAL_CLIENT_ID", "env-client")
    monkeypatch.setenv("MURAL_SCOPES", "murals:read")

    rc = mural_module.main(["auth", "setup", "--profile", "alpha"])

    assert rc == mural_module.EXIT_SUCCESS
    data = json.loads(fake_token_store.read_text())
    assert data["schema_version"] == 2
    profile = data["profiles"]["alpha"]
    assert profile["client_id"] == "env-client"
    assert profile["access_token"] == ""
    assert "scope" not in profile
    assert profile["granted_scopes"] == ["murals:read"]


def test_auth_setup_requires_client_id(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    fake_token_store: pathlib.Path,
) -> None:
    # ENV_CLIENT_ID is seeded by the autouse fixture; clear it.
    monkeypatch.delenv("MURAL_CLIENT_ID", raising=False)
    # Pin env-only backend so a sibling test that wrote MURAL_CLIENT_ID into
    # the keyring (via _cmd_auth_setup -> backend.set) cannot be re-hydrated
    # back into os.environ by _autoload_credentials in this run.
    monkeypatch.setenv("MURAL_CREDENTIAL_BACKEND", "env-only")

    rc = mural_module.main(["auth", "setup", "--profile", "alpha"])

    assert rc == mural_module.EXIT_USAGE


def test_auth_list_formatting_empty(
    mural_module: Any,
    capsys: pytest.CaptureFixture[str],
    fake_token_store: pathlib.Path,
) -> None:
    fake_token_store.write_text(json.dumps({"schema_version": 2, "profiles": {}}))

    rc = mural_module.main(["auth", "list", "--format", "table"])

    assert rc == mural_module.EXIT_SUCCESS
    assert "(no profiles)" in capsys.readouterr().out


def test_auth_list_formatting_table(
    mural_module: Any,
    capsys: pytest.CaptureFixture[str],
    fake_token_store: pathlib.Path,
) -> None:
    _seed_envelope(
        fake_token_store,
        {
            "alpha": {
                "client_id": "abcdefghijKLMNOP",
                "access_token": "x",
                "token_type": "Bearer",
                "obtained_at": 0,
                "granted_scopes": ["murals:read"],
                "expires_at": 1700000000,
            },
            "beta": {
                "client_id": "short",
                "access_token": "y",
                "token_type": "Bearer",
                "obtained_at": 0,
                "expires_at": 0,
            },
        },
        active="beta",
    )

    rc = mural_module.main(["auth", "list", "--format", "table"])

    assert rc == mural_module.EXIT_SUCCESS
    out = capsys.readouterr().out
    # client_id truncated to last 4 chars when longer than 4.
    assert "MNOP" in out
    # 5-char client_id is also truncated to last 4 chars.
    assert "hort" in out
    # Active marker on beta.
    assert "* beta" in out
    # ISO8601 UTC formatting for expires_at.
    assert "2023-11-14" in out


def test_auth_list_json_output(
    mural_module: Any,
    capsys: pytest.CaptureFixture[str],
    fake_token_store: pathlib.Path,
) -> None:
    _seed_envelope(
        fake_token_store,
        {
            "alpha": {
                "client_id": "abcdefghijKLMNOP",
                "access_token": "x",
                "token_type": "Bearer",
                "obtained_at": 0,
                "expires_at": 0,
            },
        },
        active="alpha",
    )

    rc = mural_module.main(["--json", "auth", "list"])

    assert rc == mural_module.EXIT_SUCCESS
    payload = json.loads(capsys.readouterr().out)
    assert payload["active_profile"] == "alpha"
    assert payload["profiles"][0]["name"] == "alpha"
    assert payload["profiles"][0]["client_id"] == "MNOP"
    assert payload["profiles"][0]["active"] is True
    assert payload["profiles"][0]["has_refresh_token"] is False


def test_auth_use_writes_active_profile(
    mural_module: Any,
    fake_token_store: pathlib.Path,
) -> None:
    _seed_envelope(
        fake_token_store,
        {
            "alpha": {
                "client_id": "cid-alpha",
                "access_token": "x",
                "token_type": "Bearer",
                "obtained_at": 0,
                "expires_at": 0,
            },
            "beta": {
                "client_id": "cid-beta",
                "access_token": "y",
                "token_type": "Bearer",
                "obtained_at": 0,
                "expires_at": 0,
            },
        },
    )

    rc = mural_module.main(["auth", "use", "beta"])

    assert rc == mural_module.EXIT_SUCCESS
    data = json.loads(fake_token_store.read_text())
    assert data["active_profile"] == "beta"


def test_auth_use_unknown_profile_fails(
    mural_module: Any,
    fake_token_store: pathlib.Path,
) -> None:
    _seed_envelope(
        fake_token_store,
        {
            "alpha": {
                "client_id": "cid-alpha",
                "access_token": "x",
                "token_type": "Bearer",
                "obtained_at": 0,
                "expires_at": 0,
            },
        },
    )

    rc = mural_module.main(["auth", "use", "missing"])

    assert rc == mural_module.EXIT_FAILURE


def test_auth_logout_named_profile(
    mural_module: Any,
    fake_token_store: pathlib.Path,
) -> None:
    _seed_envelope(
        fake_token_store,
        {
            "alpha": {
                "client_id": "cid-alpha",
                "access_token": "x",
                "token_type": "Bearer",
                "obtained_at": 0,
                "expires_at": 0,
            },
            "beta": {
                "client_id": "cid-beta",
                "access_token": "y",
                "token_type": "Bearer",
                "obtained_at": 0,
                "expires_at": 0,
            },
        },
        active="alpha",
    )

    rc = mural_module.main(["auth", "logout", "--profile", "alpha"])

    assert rc == mural_module.EXIT_SUCCESS
    data = json.loads(fake_token_store.read_text())
    assert "alpha" not in data["profiles"]
    assert "beta" in data["profiles"]
    # active_profile cleared because it pointed at the removed profile.
    assert "active_profile" not in data


def test_auth_logout_default_clears_active_profile(
    mural_module: Any,
    fake_token_store: pathlib.Path,
) -> None:
    _seed_envelope(
        fake_token_store,
        {
            "alpha": {
                "client_id": "cid-alpha",
                "access_token": "x",
                "token_type": "Bearer",
                "obtained_at": 0,
                "expires_at": 0,
            },
            "beta": {
                "client_id": "cid-beta",
                "access_token": "y",
                "token_type": "Bearer",
                "obtained_at": 0,
                "expires_at": 0,
            },
        },
        active="beta",
    )

    rc = mural_module.main(["auth", "logout"])

    assert rc == mural_module.EXIT_SUCCESS
    data = json.loads(fake_token_store.read_text())
    assert "beta" not in data["profiles"]
    assert "alpha" in data["profiles"]


# ---------------------------------------------------------------------------
# IV-001 TOCTOU + uniform JSON envelopes for auth setup/use/logout
# ---------------------------------------------------------------------------


def test_token_store_session_serializes_writes(
    mural_module: Any, fake_token_store: pathlib.Path
) -> None:
    """Two threads entering ``_token_store_session`` must serialize.

    Proves the IV-001 fix: the read+modify+write happens under a single lock
    acquisition per logical operation, so concurrent invocations cannot
    interleave their read/modify phases.
    """
    import threading

    _seed_envelope(
        fake_token_store,
        {
            "default": {
                "client_id": "cid",
                "access_token": "tok",
                "token_type": "Bearer",
                "obtained_at": 0,
                "expires_at": 0,
            },
        },
    )

    barrier = threading.Barrier(2)
    inside_holder = {"count": 0, "max": 0}
    inside_lock = threading.Lock()
    errors: list[Exception] = []

    def _worker(name: str) -> None:
        try:
            barrier.wait(timeout=5)
            with mural_module._token_store_session(fake_token_store) as (
                envelope,
                commit,
            ):
                with inside_lock:
                    inside_holder["count"] += 1
                    inside_holder["max"] = max(
                        inside_holder["max"], inside_holder["count"]
                    )
                # Simulate non-trivial modify work; if the lock is not held
                # exclusively the second thread would race in here.
                envelope = envelope or {
                    "schema_version": 2,
                    "profiles": {},
                }
                profiles = dict(envelope.get("profiles") or {})
                profiles[name] = {
                    "client_id": f"cid-{name}",
                    "access_token": f"tok-{name}",
                    "token_type": "Bearer",
                    "obtained_at": 0,
                    "expires_at": 0,
                }
                new_envelope = dict(envelope)
                new_envelope["profiles"] = profiles
                commit(new_envelope)
                with inside_lock:
                    inside_holder["count"] -= 1
        except Exception as exc:  # noqa: BLE001
            errors.append(exc)

    t1 = threading.Thread(target=_worker, args=("alpha",))
    t2 = threading.Thread(target=_worker, args=("beta",))
    t1.start()
    t2.start()
    t1.join(timeout=10)
    t2.join(timeout=10)

    assert not errors
    # At no point did two threads sit inside the session simultaneously.
    assert inside_holder["max"] == 1
    # Both writes landed (no lost update).
    data = json.loads(fake_token_store.read_text())
    assert "alpha" in data["profiles"]
    assert "beta" in data["profiles"]


def test_auth_setup_json_envelope(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    fake_token_store: pathlib.Path,
    capsys: pytest.CaptureFixture[str],
) -> None:
    monkeypatch.setenv("MURAL_CLIENT_ID", "env-client")
    monkeypatch.setenv("MURAL_SCOPES", "murals:read")

    rc = mural_module.main(["auth", "setup", "--profile", "alpha", "--json"])

    assert rc == mural_module.EXIT_SUCCESS
    out = capsys.readouterr().out
    payload = json.loads(out)
    assert payload == {
        "profile": "alpha",
        "token_store": str(fake_token_store),
        "status": "prepared",
        "next_steps": ["python -m mural auth login --profile alpha"],
    }


def test_auth_setup_human_walkthrough_emitted(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    fake_token_store: pathlib.Path,
    capsys: pytest.CaptureFixture[str],
) -> None:
    monkeypatch.setenv("MURAL_CLIENT_ID", "env-client")
    monkeypatch.setenv("MURAL_SCOPES", "murals:read")

    rc = mural_module.main(["auth", "setup", "--profile", "alpha"])

    assert rc == mural_module.EXIT_SUCCESS
    out = capsys.readouterr().out
    assert mural_module._OAUTH_SETUP_WALKTHROUGH.splitlines()[0] in out


def test_auth_list_table_includes_refresh_column(
    mural_module: Any,
    capsys: pytest.CaptureFixture[str],
    fake_token_store: pathlib.Path,
) -> None:
    _seed_envelope(
        fake_token_store,
        {
            "alpha": {
                "client_id": "cid-alpha",
                "access_token": "x",
                "refresh_token": "r",
                "token_type": "Bearer",
                "obtained_at": 0,
                "expires_at": 0,
            },
            "beta": {
                "client_id": "cid-beta",
                "access_token": "y",
                "token_type": "Bearer",
                "obtained_at": 0,
                "expires_at": 0,
            },
        },
    )

    rc = mural_module.main(["auth", "list", "--format", "table"])

    assert rc == mural_module.EXIT_SUCCESS
    out = capsys.readouterr().out
    assert "REFRESH" in out
    # alpha has refresh_token, beta does not.
    lines = [line for line in out.splitlines() if " alpha " in line or " beta " in line]
    assert any("yes" in line for line in lines if " alpha " in line)
    assert any("no" in line for line in lines if " beta " in line)


def test_auth_use_json_envelope(
    mural_module: Any,
    fake_token_store: pathlib.Path,
    capsys: pytest.CaptureFixture[str],
) -> None:
    _seed_envelope(
        fake_token_store,
        {
            "alpha": {
                "client_id": "cid-alpha",
                "access_token": "x",
                "token_type": "Bearer",
                "obtained_at": 0,
                "expires_at": 0,
            },
            "beta": {
                "client_id": "cid-beta",
                "access_token": "y",
                "token_type": "Bearer",
                "obtained_at": 0,
                "expires_at": 0,
            },
        },
    )

    rc = mural_module.main(["auth", "use", "beta", "--json"])

    assert rc == mural_module.EXIT_SUCCESS
    payload = json.loads(capsys.readouterr().out)
    assert payload == {
        "profile": "beta",
        "token_store": str(fake_token_store),
        "status": "active",
    }


def test_auth_logout_all_json_envelope(
    mural_module: Any,
    fake_token_store: pathlib.Path,
    capsys: pytest.CaptureFixture[str],
) -> None:
    _seed_envelope(
        fake_token_store,
        {
            "alpha": {
                "client_id": "cid-alpha",
                "access_token": "x",
                "token_type": "Bearer",
                "obtained_at": 0,
                "expires_at": 0,
            },
        },
        active="alpha",
    )

    rc = mural_module.main(["auth", "logout", "--all", "--keep-credentials", "--json"])

    assert rc == mural_module.EXIT_SUCCESS
    payload = json.loads(capsys.readouterr().out)
    assert payload == {
        "token_store": str(fake_token_store),
        "status": "cleared",
        "scope": "all",
        "credentials_removed": [],
        "keep_credentials": True,
    }


def test_auth_logout_named_json_envelope(
    mural_module: Any,
    fake_token_store: pathlib.Path,
    capsys: pytest.CaptureFixture[str],
) -> None:
    _seed_envelope(
        fake_token_store,
        {
            "alpha": {
                "client_id": "cid-alpha",
                "access_token": "x",
                "token_type": "Bearer",
                "obtained_at": 0,
                "expires_at": 0,
            },
        },
        active="alpha",
    )

    rc = mural_module.main(
        ["auth", "logout", "--profile", "alpha", "--keep-credentials", "--json"]
    )

    assert rc == mural_module.EXIT_SUCCESS
    payload = json.loads(capsys.readouterr().out)
    assert payload == {
        "profile": "alpha",
        "token_store": str(fake_token_store),
        "status": "removed",
        "credentials_removed": [],
        "keep_credentials": True,
    }


def test_auth_logout_named_absent_json_envelope(
    mural_module: Any,
    fake_token_store: pathlib.Path,
    capsys: pytest.CaptureFixture[str],
) -> None:
    _seed_envelope(
        fake_token_store,
        {
            "alpha": {
                "client_id": "cid-alpha",
                "access_token": "x",
                "token_type": "Bearer",
                "obtained_at": 0,
                "expires_at": 0,
            },
        },
    )

    rc = mural_module.main(
        [
            "auth",
            "logout",
            "--profile",
            "missing",
            "--keep-credentials",
            "--json",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    payload = json.loads(capsys.readouterr().out)
    assert payload == {
        "profile": "missing",
        "token_store": str(fake_token_store),
        "status": "absent",
        "credentials_removed": [],
        "keep_credentials": True,
    }


def test_auth_logout_no_store_json_envelope(
    mural_module: Any,
    tmp_path: pathlib.Path,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    missing = tmp_path / "absent.json"
    monkeypatch.setenv(ENV_TOKEN_STORE, str(missing))

    rc = mural_module.main(["auth", "logout", "--keep-credentials", "--json"])

    assert rc == mural_module.EXIT_SUCCESS
    payload = json.loads(capsys.readouterr().out)
    assert payload == {
        "token_store": str(missing),
        "status": "absent",
        "credentials_removed": [],
        "keep_credentials": True,
    }


# ---------------------------------------------------------------------------
# Workspace / room / mural list+get
# ---------------------------------------------------------------------------


def test_workspace_list_uses_paginate(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    calls = _patch_paginate(monkeypatch, mural_module, [{"id": "w1"}, {"id": "w2"}])

    rc = mural_module.main(["workspace", "list", "--limit", "10"])

    assert rc == mural_module.EXIT_SUCCESS
    assert calls == [
        {
            "method": "GET",
            "path": "/workspaces",
            "limit": 10,
            "page_size": mural_module._DEFAULT_PAGE_SIZE,
            "max_pages": None,
        }
    ]
    assert json.loads(capsys.readouterr().out) == [{"id": "w1"}, {"id": "w2"}]


def test_workspace_get_resolves_from_env(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    monkeypatch.setenv(ENV_DEFAULT_WORKSPACE, TEST_WORKSPACE_ID)
    calls = _patch_request(
        monkeypatch, mural_module, return_value={"id": TEST_WORKSPACE_ID}
    )

    rc = mural_module.main(["workspace", "get"])

    assert rc == mural_module.EXIT_SUCCESS
    assert calls == [{"method": "GET", "path": f"/workspaces/{TEST_WORKSPACE_ID}"}]
    assert json.loads(capsys.readouterr().out) == {"id": TEST_WORKSPACE_ID}


def test_room_list_uses_workspace_path(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv(ENV_DEFAULT_WORKSPACE, TEST_WORKSPACE_ID)
    calls = _patch_paginate(monkeypatch, mural_module, [{"id": "r1"}])

    rc = mural_module.main(["room", "list"])

    assert rc == mural_module.EXIT_SUCCESS
    assert calls[0]["path"] == f"/workspaces/{TEST_WORKSPACE_ID}/rooms"


def test_room_get_uses_room_path(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls = _patch_request(monkeypatch, mural_module, return_value={"id": "r1"})

    rc = mural_module.main(["room", "get", "--room", "r1"])

    assert rc == mural_module.EXIT_SUCCESS
    assert calls == [{"method": "GET", "path": "/rooms/r1"}]


def test_room_create_posts_to_workspace_path(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    monkeypatch.setenv(ENV_DEFAULT_WORKSPACE, TEST_WORKSPACE_ID)
    calls = _patch_request(
        monkeypatch, mural_module, return_value={"id": "r-new", "name": "Live Test"}
    )

    rc = mural_module.main(
        [
            "room",
            "create",
            "--name",
            "Live Test",
            "--type",
            "open",
            "--description",
            "scratch",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert calls == [
        {
            "method": "POST",
            "path": "/rooms",
            "json_body": {
                "workspaceId": TEST_WORKSPACE_ID,
                "name": "Live Test",
                "type": "open",
                "description": "scratch",
            },
        }
    ]
    assert json.loads(capsys.readouterr().out) == {"id": "r-new", "name": "Live Test"}


def test_room_create_defaults_to_private_without_description(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv(ENV_DEFAULT_WORKSPACE, TEST_WORKSPACE_ID)
    calls = _patch_request(monkeypatch, mural_module, return_value={"id": "r-x"})

    rc = mural_module.main(["room", "create", "--name", "Solo"])

    assert rc == mural_module.EXIT_SUCCESS
    assert calls == [
        {
            "method": "POST",
            "path": "/rooms",
            "json_body": {
                "workspaceId": TEST_WORKSPACE_ID,
                "name": "Solo",
                "type": "private",
            },
        }
    ]


def test_mural_list_uses_workspace_path(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv(ENV_DEFAULT_WORKSPACE, TEST_WORKSPACE_ID)
    calls = _patch_paginate(monkeypatch, mural_module, [])

    rc = mural_module.main(["mural", "list", "--page-size", "25"])

    assert rc == mural_module.EXIT_SUCCESS
    assert calls[0]["path"] == f"/workspaces/{TEST_WORKSPACE_ID}/murals"
    assert calls[0]["page_size"] == 25


def test_mural_create_posts_to_murals_path(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    calls = _patch_request(
        monkeypatch,
        mural_module,
        return_value={"id": "ws.m-new", "title": "Live Mural"},
    )

    rc = mural_module.main(
        [
            "mural",
            "create",
            "--room",
            "1778094575426809",
            "--title",
            "Live Mural",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert calls == [
        {
            "method": "POST",
            "path": "/murals",
            "json_body": {
                "roomId": 1778094575426809,
                "title": "Live Mural",
            },
        }
    ]
    assert json.loads(capsys.readouterr().out) == {
        "id": "ws.m-new",
        "title": "Live Mural",
    }


def test_mural_create_rejects_non_integer_room(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    _patch_request(monkeypatch, mural_module, return_value={"id": "ws.m-x"})

    with pytest.raises(SystemExit):
        mural_module.main(
            [
                "mural",
                "create",
                "--room",
                "not-an-int",
                "--title",
                "Solo",
            ]
        )


def test_mural_get_invalid_id_returns_failure(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    _patch_request(monkeypatch, mural_module, return_value={})

    rc = mural_module.main(["mural", "get", "--mural", "not-valid"])

    assert rc == mural_module.EXIT_FAILURE


def test_mural_get_happy_path(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls = _patch_request(
        monkeypatch, mural_module, return_value={"id": TEST_MURAL_ID}
    )

    rc = mural_module.main(["mural", "get", "--mural", TEST_MURAL_ID])

    assert rc == mural_module.EXIT_SUCCESS
    assert calls == [{"method": "GET", "path": f"/murals/{TEST_MURAL_ID}"}]


# ---------------------------------------------------------------------------
# Widget list / get / update / delete
# ---------------------------------------------------------------------------


def test_widget_list_passes_filters(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls = _patch_paginate(monkeypatch, mural_module, [])

    rc = mural_module.main(
        [
            "widget",
            "list",
            "--mural",
            TEST_MURAL_ID,
            "--type",
            "sticky-note",
            "--parent-id",
            "p1",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert calls[0]["path"] == f"/murals/{TEST_MURAL_ID}/widgets"
    assert calls[0]["params"] == {"type": "sticky-note", "parentId": "p1"}


# ---------------------------------------------------------------------------
# Area list / get with /widgets?type=area fallback
# ---------------------------------------------------------------------------


def _patch_paginate_sequenced(
    monkeypatch: pytest.MonkeyPatch,
    mural_module: Any,
    responses: list[Any],
) -> list[dict[str, Any]]:
    """Replace ``_paginate`` with a recorder consuming ``responses`` per call.

    Each entry is either a ``list`` of records to yield, or a
    ``BaseException`` instance to raise when iterated.
    """
    calls: list[dict[str, Any]] = []
    iterator = iter(responses)

    def _fake(method: str, path: str, **kwargs: Any):
        calls.append({"method": method, "path": path, **kwargs})
        item = next(iterator)
        if isinstance(item, BaseException):
            raise item
        yield from item

    monkeypatch.setattr(mural_module, "_paginate", _fake)
    return calls


def _patch_request_sequenced(
    monkeypatch: pytest.MonkeyPatch,
    mural_module: Any,
    responses: list[Any],
) -> list[dict[str, Any]]:
    """Replace ``_authenticated_request`` with a sequenced recorder.

    Each entry in ``responses`` is either a value to return or a
    ``BaseException`` instance to raise on the matching call.
    """
    calls: list[dict[str, Any]] = []
    iterator = iter(responses)

    def _fake(method: str, path: str, **kwargs: Any) -> Any:
        calls.append({"method": method, "path": path, **kwargs})
        item = next(iterator)
        if isinstance(item, BaseException):
            raise item
        return item

    monkeypatch.setattr(mural_module, "_authenticated_request", _fake)
    return calls


def test_area_list_uses_dedicated_endpoint_when_available(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls = _patch_paginate(monkeypatch, mural_module, [{"id": "a1", "type": "area"}])

    rc = mural_module.main(["area", "list", "--mural", TEST_MURAL_ID])

    assert rc == mural_module.EXIT_SUCCESS
    assert len(calls) == 1
    assert calls[0]["path"] == f"/murals/{TEST_MURAL_ID}/areas"


def test_area_list_falls_back_to_widget_endpoint_on_404(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    fallback_records = [
        {"id": "a1", "type": "area"},
        {"id": "a2", "type": "area"},
    ]
    calls = _patch_paginate_sequenced(
        monkeypatch,
        mural_module,
        [
            mural_module.MuralAPIError(404, "AREA_NOT_FOUND", "no /areas route"),
            fallback_records,
        ],
    )

    rc = mural_module.main(["area", "list", "--mural", TEST_MURAL_ID])

    assert rc == mural_module.EXIT_SUCCESS
    assert len(calls) == 2
    assert calls[0]["path"] == f"/murals/{TEST_MURAL_ID}/areas"
    assert calls[1]["path"] == f"/murals/{TEST_MURAL_ID}/widgets"
    assert calls[1]["params"] == {"type": "area"}
    assert mural_module._area_cache["a1"] == fallback_records[0]
    assert mural_module._area_cache["a2"] == fallback_records[1]


def test_area_list_propagates_non_404_errors(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls = _patch_paginate_sequenced(
        monkeypatch,
        mural_module,
        [mural_module.MuralAPIError(500, "INTERNAL", "boom")],
    )

    rc = mural_module.main(["area", "list", "--mural", TEST_MURAL_ID])

    assert rc != mural_module.EXIT_SUCCESS
    assert len(calls) == 1
    assert calls[0]["path"] == f"/murals/{TEST_MURAL_ID}/areas"


def test_area_get_uses_dedicated_endpoint_when_available(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls = _patch_request(
        monkeypatch, mural_module, return_value={"id": "a1", "type": "area"}
    )

    rc = mural_module.main(["area", "get", "--mural", TEST_MURAL_ID, "--area", "a1"])

    assert rc == mural_module.EXIT_SUCCESS
    assert calls == [{"method": "GET", "path": f"/murals/{TEST_MURAL_ID}/areas/a1"}]


def test_area_get_falls_back_to_widget_on_404(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    fallback_record = {"id": "a1", "type": "area", "title": "Section A"}
    calls = _patch_request_sequenced(
        monkeypatch,
        mural_module,
        [
            mural_module.MuralAPIError(404, "AREA_NOT_FOUND", "no /areas route"),
            fallback_record,
        ],
    )

    rc = mural_module.main(["area", "get", "--mural", TEST_MURAL_ID, "--area", "a1"])

    assert rc == mural_module.EXIT_SUCCESS
    assert len(calls) == 2
    assert calls[0]["path"] == f"/murals/{TEST_MURAL_ID}/areas/a1"
    assert calls[1]["path"] == f"/murals/{TEST_MURAL_ID}/widgets/a1"


def test_area_get_rejects_widget_with_wrong_type(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    _patch_request_sequenced(
        monkeypatch,
        mural_module,
        [
            mural_module.MuralAPIError(404, "AREA_NOT_FOUND", "no /areas route"),
            {"id": "a1", "type": "sticky-note"},
        ],
    )

    rc = mural_module.main(["area", "get", "--mural", TEST_MURAL_ID, "--area", "a1"])

    assert rc != mural_module.EXIT_SUCCESS


def test_area_get_populates_cache_on_fallback_path(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    fallback_record = {"id": "a1", "type": "area", "title": "Section A"}
    _patch_request_sequenced(
        monkeypatch,
        mural_module,
        [
            mural_module.MuralAPIError(404, "AREA_NOT_FOUND", "no /areas route"),
            fallback_record,
        ],
    )

    rc = mural_module.main(["area", "get", "--mural", TEST_MURAL_ID, "--area", "a1"])

    assert rc == mural_module.EXIT_SUCCESS
    assert mural_module._area_cache["a1"] == fallback_record


def test_widget_list_rejects_oversized_page_size(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    _patch_paginate(monkeypatch, mural_module, [])

    rc = mural_module.main(
        [
            "widget",
            "list",
            "--mural",
            TEST_MURAL_ID,
            "--page-size",
            str(mural_module._MAX_PAGE_SIZE + 1),
        ]
    )

    assert rc == mural_module.EXIT_FAILURE


def test_widget_get(mural_module: Any, monkeypatch: pytest.MonkeyPatch) -> None:
    calls = _patch_request(
        monkeypatch, mural_module, return_value={"id": TEST_WIDGET_ID}
    )

    rc = mural_module.main(
        ["widget", "get", "--mural", TEST_MURAL_ID, "--widget", TEST_WIDGET_ID]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert calls == [
        {
            "method": "GET",
            "path": f"/murals/{TEST_MURAL_ID}/widgets/{TEST_WIDGET_ID}",
        }
    ]


def test_widget_update_parses_json_body(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls = _patch_request(
        monkeypatch, mural_module, return_value={"id": TEST_WIDGET_ID}
    )

    rc = mural_module.main(
        [
            "widget",
            "update",
            "--mural",
            TEST_MURAL_ID,
            "--widget",
            TEST_WIDGET_ID,
            "--body",
            '{"text": "updated"}',
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert calls[0]["method"] == "PATCH"
    assert calls[0]["json_body"] == {"text": "updated"}


def test_widget_update_invalid_json_returns_failure(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    _patch_request(monkeypatch, mural_module, return_value={})

    rc = mural_module.main(
        [
            "widget",
            "update",
            "--mural",
            TEST_MURAL_ID,
            "--widget",
            TEST_WIDGET_ID,
            "--body",
            "not-json",
        ]
    )

    assert rc == mural_module.EXIT_FAILURE


def test_widget_delete_prints_payload(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    calls = _patch_request(monkeypatch, mural_module, return_value=None)

    rc = mural_module.main(
        ["widget", "delete", "--mural", TEST_MURAL_ID, "--widget", TEST_WIDGET_ID]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert calls[0]["method"] == "DELETE"
    assert calls[0]["path"] == f"/murals/{TEST_MURAL_ID}/widgets/{TEST_WIDGET_ID}"
    assert json.loads(capsys.readouterr().out) == {
        "ok": True,
        "deleted": TEST_WIDGET_ID,
    }


# ---------------------------------------------------------------------------
# Widget create variants
# ---------------------------------------------------------------------------


def test_widget_create_sticky_note(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls = _patch_request(
        monkeypatch, mural_module, return_value={"id": TEST_WIDGET_ID}
    )

    rc = mural_module.main(
        [
            "widget",
            "create",
            "sticky-note",
            "--mural",
            TEST_MURAL_ID,
            "--text",
            "hello",
            "--x",
            "10",
            "--y",
            "20",
            "--style",
            '{"backgroundColor":"#fff"}',
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert calls[0]["method"] == "POST"
    assert calls[0]["path"] == f"/murals/{TEST_MURAL_ID}/widgets/sticky-note"
    body = calls[0]["json_body"]
    assert body["text"] == "hello"
    assert body["x"] == 10.0
    assert body["y"] == 20.0
    assert body["shape"] == "rectangle"
    assert body["style"] == {"backgroundColor": "#fff"}


def test_widget_create_textbox(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls = _patch_request(
        monkeypatch, mural_module, return_value={"id": TEST_WIDGET_ID}
    )

    rc = mural_module.main(
        [
            "widget",
            "create",
            "textbox",
            "--mural",
            TEST_MURAL_ID,
            "--text",
            "hi",
            "--x",
            "0",
            "--y",
            "0",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert calls[0]["path"].endswith("/widgets/textbox")
    assert calls[0]["json_body"]["text"] == "hi"


def test_widget_create_shape(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls = _patch_request(
        monkeypatch, mural_module, return_value={"id": TEST_WIDGET_ID}
    )

    rc = mural_module.main(
        [
            "widget",
            "create",
            "shape",
            "--mural",
            TEST_MURAL_ID,
            "--shape",
            "circle",
            "--x",
            "5",
            "--y",
            "6",
            "--text",
            "label",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert calls[0]["path"].endswith("/widgets/shape")
    body = calls[0]["json_body"]
    assert body == {"shape": "circle", "x": 5.0, "y": 6.0, "text": "label"}


def test_widget_create_arrow(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls = _patch_request(
        monkeypatch, mural_module, return_value={"id": TEST_WIDGET_ID}
    )

    rc = mural_module.main(
        [
            "widget",
            "create",
            "arrow",
            "--mural",
            TEST_MURAL_ID,
            "--x1",
            "1",
            "--y1",
            "2",
            "--x2",
            "3",
            "--y2",
            "4",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert calls[0]["path"].endswith("/widgets/arrow")
    assert calls[0]["json_body"] == {"x1": 1.0, "y1": 2.0, "x2": 3.0, "y2": 4.0}


def test_widget_create_image_happy_path(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: pathlib.Path,
) -> None:
    image_path = tmp_path / "pic.png"
    image_path.write_bytes(b"\x89PNG\r\n\x1a\nfake")

    asset = {
        "url": "https://example.blob.core.windows.net/c/pic.png?sig=x",
        "name": "asset-1",
        "headers": {"x-ms-blob-type": "BlockBlob"},
    }

    asset_calls: list[tuple[str, str]] = []

    def _fake_create_asset(mural_id: str, ext: str, **_kwargs: Any) -> dict[str, Any]:
        asset_calls.append((mural_id, ext))
        return asset

    upload_calls: list[dict[str, Any]] = []

    def _fake_upload(**kwargs: Any) -> None:
        upload_calls.append(kwargs)

    monkeypatch.setattr(mural_module, "_create_asset_url", _fake_create_asset)
    monkeypatch.setattr(mural_module, "_upload_to_sas", _fake_upload)
    request_calls = _patch_request(
        monkeypatch, mural_module, return_value={"id": TEST_WIDGET_ID}
    )

    rc = mural_module.main(
        [
            "widget",
            "create",
            "image",
            "--mural",
            TEST_MURAL_ID,
            "--file",
            str(image_path),
            "--x",
            "0",
            "--y",
            "0",
            "--title",
            "Pic",
            "--alt-text",
            "a fake test image",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert asset_calls == [(TEST_MURAL_ID, ".png")]
    assert upload_calls == [
        {
            "url": asset["url"],
            "headers": asset["headers"],
            "body": image_path.read_bytes(),
            "content_type": "image/png",
        }
    ]
    assert request_calls[0]["method"] == "POST"
    assert request_calls[0]["path"] == f"/murals/{TEST_MURAL_ID}/widgets/image"
    assert request_calls[0]["json_body"]["name"] == "asset-1"
    assert request_calls[0]["json_body"]["title"] == "Pic"
    assert request_calls[0]["json_body"]["altText"] == "a fake test image"


def test_widget_create_image_missing_file_returns_failure(
    mural_module: Any, tmp_path: pathlib.Path
) -> None:
    rc = mural_module.main(
        [
            "widget",
            "create",
            "image",
            "--mural",
            TEST_MURAL_ID,
            "--file",
            str(tmp_path / "nope.png"),
            "--x",
            "0",
            "--y",
            "0",
            "--alt-text",
            "alt",
        ]
    )

    assert rc == mural_module.EXIT_FAILURE


def test_widget_create_image_unsupported_extension_returns_failure(
    mural_module: Any, tmp_path: pathlib.Path
) -> None:
    bad = tmp_path / "doc.txt"
    bad.write_bytes(b"hi")

    rc = mural_module.main(
        [
            "widget",
            "create",
            "image",
            "--mural",
            TEST_MURAL_ID,
            "--file",
            str(bad),
            "--x",
            "0",
            "--y",
            "0",
            "--alt-text",
            "alt",
        ]
    )

    assert rc == mural_module.EXIT_FAILURE


# ---------------------------------------------------------------------------
# Phase 2: widget create-bulk
# ---------------------------------------------------------------------------


def test_widget_create_bulk_happy_path(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: pathlib.Path,
    capsys: pytest.CaptureFixture[str],
) -> None:
    payload_path = tmp_path / "widgets.json"
    payload_path.write_text(
        json.dumps(
            [
                {"type": "sticky-note", "text": "a"},
                {"type": "textbox", "text": "b"},
            ]
        ),
        encoding="utf-8",
    )
    calls = _patch_request(
        monkeypatch,
        mural_module,
        return_values=[{"id": "wA"}, {"id": "wB"}],
    )

    rc = mural_module.main(
        [
            "widget",
            "create-bulk",
            "--mural",
            TEST_MURAL_ID,
            "--file",
            str(payload_path),
            "--no-author-tag",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert [(c["method"], c["path"]) for c in calls] == [
        ("POST", f"/murals/{TEST_MURAL_ID}/widgets/sticky-note"),
        ("POST", f"/murals/{TEST_MURAL_ID}/widgets/textbox"),
    ]
    assert calls[0]["json_body"] == {"text": "a"}
    assert calls[1]["json_body"] == {"text": "b"}
    for call in calls:
        assert "type" not in call["json_body"]
    out = json.loads(capsys.readouterr().out)
    assert out["succeeded"] == [{"id": "wA"}, {"id": "wB"}]
    assert out["skipped"] == []


def test_widget_create_bulk_rejects_invalid_payload(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: pathlib.Path,
) -> None:
    payload_path = tmp_path / "bad.json"
    payload_path.write_text(json.dumps([]), encoding="utf-8")
    _patch_request(monkeypatch, mural_module, return_value=[])

    rc = mural_module.main(
        [
            "widget",
            "create-bulk",
            "--mural",
            TEST_MURAL_ID,
            "--file",
            str(payload_path),
        ]
    )
    assert rc == mural_module.EXIT_FAILURE


# ---------------------------------------------------------------------------
# Phase 2: mural duplicate / clone-with-tags / archive / unarchive / poll
# ---------------------------------------------------------------------------


def test_mural_duplicate_happy_path(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    new_id = "workspace1.mural-new999"
    calls = _patch_request(monkeypatch, mural_module, return_value={"id": new_id})

    rc = mural_module.main(["mural", "duplicate", "--mural", TEST_MURAL_ID])

    assert rc == mural_module.EXIT_SUCCESS
    assert calls[0]["method"] == "POST"
    assert calls[0]["path"] == f"/murals/{TEST_MURAL_ID}/duplicate"
    out = json.loads(capsys.readouterr().out)
    assert out == {"new_mural_id": new_id, "source_mural_id": TEST_MURAL_ID}


def test_mural_duplicate_missing_id_returns_failure(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    _patch_request(monkeypatch, mural_module, return_value={})

    rc = mural_module.main(["mural", "duplicate", "--mural", TEST_MURAL_ID])
    assert rc == mural_module.EXIT_FAILURE


def test_mural_clone_with_tags_replays_manifest(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    new_id = "workspace1.mural-clone1"

    def _fake_duplicate(source: str) -> str:
        assert source == TEST_MURAL_ID
        return new_id

    ensure_calls: list[tuple[str, list[Any]]] = []

    def _fake_ensure(mural_id: str, manifest: list[Any]) -> dict[str, str]:
        ensure_calls.append((mural_id, manifest))
        return {entry["text"]: f"tag-{i}" for i, entry in enumerate(manifest)}

    _patch_paginate(
        monkeypatch,
        mural_module,
        [{"text": "red", "color": "#ff0000"}, {"text": "blue"}],
    )
    monkeypatch.setattr(mural_module, "_duplicate_mural", _fake_duplicate)
    monkeypatch.setattr(mural_module, "_ensure_tag_manifest", _fake_ensure)

    rc = mural_module.main(["mural", "clone-with-tags", "--mural", TEST_MURAL_ID])

    assert rc == mural_module.EXIT_SUCCESS
    assert ensure_calls == [
        (
            new_id,
            [
                {"text": "red", "color": "#ff0000"},
                {"text": "blue"},
            ],
        )
    ]
    out = json.loads(capsys.readouterr().out)
    assert out["source_mural_id"] == TEST_MURAL_ID
    assert out["new_mural_id"] == new_id
    assert out["tag_count"] == 2
    assert out["tag_map"] == {"red": "tag-0", "blue": "tag-1"}
    assert out["warnings"] == ["widget ids are not preserved across mural duplication"]


def test_mural_archive_patches_status(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls = _patch_request(
        monkeypatch, mural_module, return_value={"id": TEST_MURAL_ID}
    )

    rc = mural_module.main(["mural", "archive", "--mural", TEST_MURAL_ID])

    assert rc == mural_module.EXIT_SUCCESS
    assert calls[0] == {
        "method": "PATCH",
        "path": f"/murals/{TEST_MURAL_ID}",
        "json_body": {"status": "archived"},
    }


def test_mural_unarchive_patches_status(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls = _patch_request(
        monkeypatch, mural_module, return_value={"id": TEST_MURAL_ID}
    )

    rc = mural_module.main(["mural", "unarchive", "--mural", TEST_MURAL_ID])

    assert rc == mural_module.EXIT_SUCCESS
    assert calls[0] == {
        "method": "PATCH",
        "path": f"/murals/{TEST_MURAL_ID}",
        "json_body": {"status": "active"},
    }


def test_mural_poll_returns_match(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    _patch_request(
        monkeypatch,
        mural_module,
        return_value={"status": "active"},
    )

    rc = mural_module.main(
        [
            "mural",
            "poll",
            "--mural",
            TEST_MURAL_ID,
            "--condition",
            "status==active",
            "--interval",
            "1",
            "--timeout",
            "5",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    out = json.loads(capsys.readouterr().out)
    assert out["matched"] is True
    assert out["attempts"] == 1
    assert out["condition"] == "status==active"


# ---------------------------------------------------------------------------
# Phase 2: template instantiate / create
# ---------------------------------------------------------------------------


def test_template_instantiate_posts_body(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    monkeypatch.setenv(ENV_DEFAULT_WORKSPACE, TEST_WORKSPACE_ID)
    calls = _patch_request(monkeypatch, mural_module, return_value={"id": "new-mural"})

    rc = mural_module.main(
        [
            "template",
            "instantiate",
            "--template",
            "tpl-123",
            "--name",
            "From Template",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert calls[0]["method"] == "POST"
    assert calls[0]["path"] == "/templates/tpl-123/instantiate"
    assert calls[0]["json_body"] == {
        "workspaceId": TEST_WORKSPACE_ID,
        "name": "From Template",
    }
    assert json.loads(capsys.readouterr().out) == {"id": "new-mural"}


def test_template_instantiate_requires_template(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv(ENV_DEFAULT_WORKSPACE, TEST_WORKSPACE_ID)
    _patch_request(monkeypatch, mural_module, return_value={})

    rc = mural_module.main(["template", "instantiate", "--template", ""])
    assert rc == mural_module.EXIT_FAILURE


def test_template_create_posts_body(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv(ENV_DEFAULT_WORKSPACE, TEST_WORKSPACE_ID)
    calls = _patch_request(monkeypatch, mural_module, return_value={"id": "tpl-new"})

    rc = mural_module.main(
        [
            "template",
            "create",
            "--mural",
            TEST_MURAL_ID,
            "--name",
            "Saved Template",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert calls[0]["method"] == "POST"
    assert calls[0]["path"] == f"/murals/{TEST_MURAL_ID}/template"
    assert calls[0]["json_body"] == {
        "workspaceId": TEST_WORKSPACE_ID,
        "name": "Saved Template",
    }


# ---------------------------------------------------------------------------
# spatial widgets-in-shape / widgets-in-region
# ---------------------------------------------------------------------------


def test_spatial_widgets_in_shape_center_mode(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    shape = {"id": "shape1", "x": 0, "y": 0, "width": 100, "height": 100}
    widgets = [
        {"id": "w-inside", "x": 25, "y": 25, "width": 10, "height": 10},
        {"id": "w-outside", "x": 200, "y": 200, "width": 10, "height": 10},
    ]
    req_calls = _patch_request(monkeypatch, mural_module, return_value=shape)
    pag_calls = _patch_paginate(monkeypatch, mural_module, widgets)

    rc = mural_module.main(
        [
            "spatial",
            "widgets-in-shape",
            "--mural-id",
            TEST_MURAL_ID,
            "--shape-id",
            "shape1",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert req_calls[0]["path"] == f"/murals/{TEST_MURAL_ID}/widgets/shape1"
    assert pag_calls[0]["path"] == f"/murals/{TEST_MURAL_ID}/widgets"
    out = json.loads(capsys.readouterr().out)
    assert [w["id"] for w in out] == ["w-inside"]


def test_spatial_widgets_in_shape_bbox_mode_includes_partial_overlap(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    shape = {"id": "shape1", "x": 0, "y": 0, "width": 100, "height": 100}
    # Center at (115,115) is outside the shape, but the bounding box overlaps.
    widgets = [
        {"id": "w-overlap", "x": 90, "y": 90, "width": 50, "height": 50},
    ]
    _patch_request(monkeypatch, mural_module, return_value=shape)
    _patch_paginate(monkeypatch, mural_module, widgets)

    rc = mural_module.main(
        [
            "spatial",
            "widgets-in-shape",
            "--mural-id",
            TEST_MURAL_ID,
            "--shape-id",
            "shape1",
            "--mode",
            "bbox",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    out = json.loads(capsys.readouterr().out)
    assert [w["id"] for w in out] == ["w-overlap"]


def test_spatial_widgets_in_shape_rotation_aware_flag(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    captured: dict[str, Any] = {}

    def _fake_widgets_in_shape(widgets, shape, *, mode, rotation_aware):
        captured["mode"] = mode
        captured["rotation_aware"] = rotation_aware
        return []

    shape = {"id": "shape1", "x": 0, "y": 0, "width": 100, "height": 100}
    _patch_request(monkeypatch, mural_module, return_value=shape)
    _patch_paginate(monkeypatch, mural_module, [])
    monkeypatch.setattr(mural_module, "widgets_in_shape", _fake_widgets_in_shape)

    rc = mural_module.main(
        [
            "spatial",
            "widgets-in-shape",
            "--mural-id",
            TEST_MURAL_ID,
            "--shape-id",
            "shape1",
            "--rotation-aware",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert captured == {"mode": "center", "rotation_aware": True}


def test_spatial_widgets_in_shape_rejects_non_object_response(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    _patch_request(monkeypatch, mural_module, return_value=["not", "a", "dict"])
    _patch_paginate(monkeypatch, mural_module, [])

    rc = mural_module.main(
        [
            "spatial",
            "widgets-in-shape",
            "--mural-id",
            TEST_MURAL_ID,
            "--shape-id",
            "shape1",
        ]
    )

    assert rc == mural_module.EXIT_FAILURE


def test_spatial_widgets_in_region_center_mode(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    widgets = [
        {"id": "w-inside", "x": 10, "y": 10, "width": 10, "height": 10},
        {"id": "w-outside", "x": 200, "y": 200, "width": 10, "height": 10},
    ]
    pag_calls = _patch_paginate(monkeypatch, mural_module, widgets)

    rc = mural_module.main(
        [
            "spatial",
            "widgets-in-region",
            "--mural-id",
            TEST_MURAL_ID,
            "--x",
            "0",
            "--y",
            "0",
            "--w",
            "100",
            "--h",
            "100",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert pag_calls[0]["path"] == f"/murals/{TEST_MURAL_ID}/widgets"
    out = json.loads(capsys.readouterr().out)
    assert [w["id"] for w in out] == ["w-inside"]


def test_spatial_widgets_in_region_negative_dimensions_sign_corrected(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    # safe_rect normalizes (0,0,-100,-100) into the rect [-100,-100]..[0,0],
    # so widgets in the negative quadrant must match.
    widgets = [
        {"id": "w-q3", "x": -50, "y": -50, "width": 10, "height": 10},
        {"id": "w-q1", "x": 50, "y": 50, "width": 10, "height": 10},
    ]
    _patch_paginate(monkeypatch, mural_module, widgets)

    rc = mural_module.main(
        [
            "spatial",
            "widgets-in-region",
            "--mural-id",
            TEST_MURAL_ID,
            "--x",
            "0",
            "--y",
            "0",
            "--w",
            "-100",
            "--h",
            "-100",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    out = json.loads(capsys.readouterr().out)
    assert [w["id"] for w in out] == ["w-q3"]


def test_spatial_widgets_in_region_table_format(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    widgets = [{"id": "w-inside", "x": 10, "y": 10, "width": 10, "height": 10}]
    _patch_paginate(monkeypatch, mural_module, widgets)

    rc = mural_module.main(
        [
            "spatial",
            "widgets-in-region",
            "--mural-id",
            TEST_MURAL_ID,
            "--x",
            "0",
            "--y",
            "0",
            "--w",
            "100",
            "--h",
            "100",
            "--format",
            "table",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    out = capsys.readouterr().out
    assert "w-inside" in out


def test_spatial_group_help_lists_pr1_and_pr2_verbs(
    mural_module: Any, capsys: pytest.CaptureFixture[str]
) -> None:
    with pytest.raises(SystemExit) as exc:
        mural_module.main(["spatial", "--help"])
    assert exc.value.code == 0
    out = capsys.readouterr().out
    for verb in (
        "widgets-in-shape",
        "widgets-in-region",
        "pairwise-overlaps",
        "cluster",
        "sort-along-axis",
        "arrow-graph",
    ):
        assert verb in out


# ---------------------------------------------------------------------------
# Parent containment verification
# ---------------------------------------------------------------------------


def test_widget_create_with_parent_verifies_containment_ok(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    parent_id = "area-1"
    calls = _patch_request_sequenced(
        monkeypatch,
        mural_module,
        [
            {"id": TEST_WIDGET_ID},
            {"id": TEST_WIDGET_ID, "parentId": parent_id},
            {"id": parent_id},
        ],
    )

    rc = mural_module.main(
        [
            "widget",
            "create",
            "sticky-note",
            "--mural",
            TEST_MURAL_ID,
            "--text",
            "hello",
            "--x",
            "10",
            "--y",
            "20",
            "--parent-id",
            parent_id,
            "--no-author-tag",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert calls[0]["method"] == "POST"
    assert calls[0]["json_body"]["parentId"] == parent_id
    assert calls[1]["method"] == "GET"
    payload = json.loads(capsys.readouterr().out)
    verdict = payload["containment_verification"]
    assert verdict["verdict"] == "parent_match"
    assert verdict["via"] == "parentId"
    assert verdict["expected_parent_id"] == parent_id


def test_widget_create_textbox_with_parent_verifies_containment_ok(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    parent_id = "area-1"
    calls = _patch_request_sequenced(
        monkeypatch,
        mural_module,
        [
            {"id": TEST_WIDGET_ID},
            {"id": TEST_WIDGET_ID, "parentId": parent_id},
            {"id": parent_id},
        ],
    )

    rc = mural_module.main(
        [
            "widget",
            "create",
            "textbox",
            "--mural",
            TEST_MURAL_ID,
            "--text",
            "hello",
            "--x",
            "10",
            "--y",
            "20",
            "--parent-id",
            parent_id,
            "--no-author-tag",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert calls[0]["method"] == "POST"
    assert calls[0]["path"].endswith("/widgets/textbox")
    assert calls[0]["json_body"]["parentId"] == parent_id
    assert calls[1]["method"] == "GET"
    payload = json.loads(capsys.readouterr().out)
    verdict = payload["containment_verification"]
    assert verdict["verdict"] == "parent_match"
    assert verdict["via"] == "parentId"
    assert verdict["expected_parent_id"] == parent_id


def test_widget_create_with_parent_mismatch_returns_failure(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    expected = "area-expected"
    calls = _patch_request_sequenced(
        monkeypatch,
        mural_module,
        [
            {"id": TEST_WIDGET_ID},
            {"id": TEST_WIDGET_ID, "parentId": "area-other"},
            {"id": "area-other"},
        ],
    )

    rc = mural_module.main(
        [
            "widget",
            "create",
            "sticky-note",
            "--mural",
            TEST_MURAL_ID,
            "--text",
            "hello",
            "--x",
            "10",
            "--y",
            "20",
            "--parent-id",
            expected,
            "--no-author-tag",
        ]
    )

    assert rc == mural_module.EXIT_FAILURE
    assert calls[0]["method"] == "POST"
    assert calls[1]["method"] == "GET"
    payload = json.loads(capsys.readouterr().out)
    verdict = payload["containment_verification"]
    assert verdict["verdict"] == "parent_mismatch"
    assert verdict["expected_parent_id"] == expected
    assert verdict["persisted_parent_id"] == "area-other"


def test_widget_create_with_parent_readback_failure_returns_failure(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    _patch_request_sequenced(
        monkeypatch,
        mural_module,
        [
            {"id": TEST_WIDGET_ID},
            mural_module.MuralAPIError(500, "BOOM", "transient"),
        ],
    )

    rc = mural_module.main(
        [
            "widget",
            "create",
            "sticky-note",
            "--mural",
            TEST_MURAL_ID,
            "--text",
            "hello",
            "--x",
            "10",
            "--y",
            "20",
            "--parent-id",
            "area-x",
            "--no-author-tag",
        ]
    )

    assert rc == mural_module.EXIT_FAILURE
    payload = json.loads(capsys.readouterr().out)
    assert payload["containment_verification"]["verdict"] == "readback_failed"


def test_widget_create_with_parent_geometry_match_returns_success(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    parent_id = "area-1"
    _patch_request_sequenced(
        monkeypatch,
        mural_module,
        [
            {"id": TEST_WIDGET_ID},
            {"id": TEST_WIDGET_ID, "parentId": parent_id, "x": 10, "y": 20},
            {"id": parent_id, "width": 1000, "height": 800},
        ],
    )

    rc = mural_module.main(
        [
            "widget",
            "create",
            "sticky-note",
            "--mural",
            TEST_MURAL_ID,
            "--text",
            "in-bounds",
            "--x",
            "10",
            "--y",
            "20",
            "--parent-id",
            parent_id,
            "--no-author-tag",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    payload = json.loads(capsys.readouterr().out)
    verdict = payload["containment_verification"]
    assert verdict["verdict"] == "geometry_match"
    assert verdict["via"] == "parentId"


def test_widget_create_with_parent_geometry_mismatch_returns_failure(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    parent_id = "area-1"
    _patch_request_sequenced(
        monkeypatch,
        mural_module,
        [
            {"id": TEST_WIDGET_ID},
            {"id": TEST_WIDGET_ID, "parentId": parent_id, "x": 2000, "y": 20},
            {"id": parent_id, "width": 1000, "height": 800},
        ],
    )

    rc = mural_module.main(
        [
            "widget",
            "create",
            "sticky-note",
            "--mural",
            TEST_MURAL_ID,
            "--text",
            "out-of-bounds",
            "--x",
            "2000",
            "--y",
            "20",
            "--parent-id",
            parent_id,
            "--no-author-tag",
        ]
    )

    assert rc == mural_module.EXIT_FAILURE
    payload = json.loads(capsys.readouterr().out)
    verdict = payload["containment_verification"]
    assert verdict["verdict"] == "geometry_mismatch"
    assert verdict["via"] == "parentId"
    assert "off-area" in verdict["recommendation"]


def test_widget_create_rejects_empty_parent_id(
    mural_module: Any,
    capsys: pytest.CaptureFixture[str],
) -> None:
    with pytest.raises(SystemExit):
        mural_module.main(
            [
                "widget",
                "create",
                "sticky-note",
                "--mural",
                TEST_MURAL_ID,
                "--text",
                "hi",
                "--x",
                "10",
                "--y",
                "20",
                "--parent-id",
                "   ",
                "--no-author-tag",
            ]
        )

    err = capsys.readouterr().err
    assert "--parent-id" in err
    assert "non-empty string" in err


def test_widget_update_body_file_loads_patch(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: pathlib.Path,
) -> None:
    body_file = tmp_path / "patch.json"
    body_file.write_text(json.dumps({"text": "from-file"}), encoding="utf-8")
    calls = _patch_request(
        monkeypatch, mural_module, return_value={"id": TEST_WIDGET_ID}
    )

    rc = mural_module.main(
        [
            "widget",
            "update",
            "--mural",
            TEST_MURAL_ID,
            "--widget",
            TEST_WIDGET_ID,
            "--body-file",
            str(body_file),
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert calls[0]["method"] == "PATCH"
    assert calls[0]["json_body"] == {"text": "from-file"}


def test_widget_update_body_and_body_file_mutually_exclusive(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: pathlib.Path,
) -> None:
    body_file = tmp_path / "patch.json"
    body_file.write_text(json.dumps({"text": "x"}), encoding="utf-8")
    _patch_request(monkeypatch, mural_module, return_value={})

    rc = mural_module.main(
        [
            "widget",
            "update",
            "--mural",
            TEST_MURAL_ID,
            "--widget",
            TEST_WIDGET_ID,
            "--body",
            '{"text":"y"}',
            "--body-file",
            str(body_file),
        ]
    )

    assert rc == mural_module.EXIT_FAILURE


def test_widget_update_with_parent_verifies_and_emits_verdict(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    parent_id = "area-2"
    calls = _patch_request_sequenced(
        monkeypatch,
        mural_module,
        [
            {"id": TEST_WIDGET_ID, "parentId": parent_id},
            {"id": TEST_WIDGET_ID, "parentId": parent_id},
            {"id": parent_id},
        ],
    )

    rc = mural_module.main(
        [
            "widget",
            "update",
            "--mural",
            TEST_MURAL_ID,
            "--widget",
            TEST_WIDGET_ID,
            "--body",
            json.dumps({"parentId": parent_id}),
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert calls[0]["method"] == "PATCH"
    assert calls[1]["method"] == "GET"
    payload = json.loads(capsys.readouterr().out)
    assert payload["containment_verification"]["verdict"] == "parent_match"
