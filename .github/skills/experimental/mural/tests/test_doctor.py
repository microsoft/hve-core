# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""EV-06 readiness and dispatch-time scope tests."""

from __future__ import annotations

import argparse
import importlib
import importlib.util
import json
import pathlib
import re
from typing import Any

import pytest
from test_constants import ENV_ENV_FILE, ENV_TOKEN_STORE, TEST_CLIENT_ID


def doctor_module() -> Any:
    """Load the planned doctor module after asserting that it exists."""
    assert importlib.util.find_spec("mural._doctor") is not None
    return importlib.import_module("mural._doctor")


@pytest.mark.parametrize(
    ("overrides", "expected"),
    [
        ({"cwd_ok": False}, "wrong_cwd"),
        ({"dependencies_available": False}, "deps_missing"),
        ({"configured": False}, "needs_setup"),
        ({"logged_in": False}, "needs_login"),
        ({"required_scopes": ("murals:write",)}, "needs_scope_upgrade"),
        ({}, "ready"),
    ],
)
def test_doctor_verdict_precedence(overrides: dict[str, Any], expected: str) -> None:
    module = doctor_module()
    inputs = {
        "cwd_ok": True,
        "dependencies_available": True,
        "configured": True,
        "logged_in": True,
        "granted_scopes": ("murals:read",),
        "required_scopes": (),
    }
    inputs.update(overrides)

    result = module.evaluate_readiness(**inputs)

    assert result["verdict"] == expected


def test_parser_registers_doctor_and_repeatable_required_scope(
    mural_module: Any,
) -> None:
    args = mural_module._build_parser().parse_args(
        ["doctor", "--require-scope", "murals:read", "--require-scope", "murals:write"]
    )

    assert args.command == "doctor"
    assert args.require_scope == ["murals:read", "murals:write"]
    assert args.func is mural_module._cmd_doctor


def test_main_denies_missing_scope_before_handler(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    called: list[str] = []

    def fake_handler(_args: argparse.Namespace) -> int:
        called.append("handler")
        return mural_module.EXIT_SUCCESS

    fake_args = argparse.Namespace(
        log_level="WARNING",
        quiet=False,
        json_output=False,
        profile="default",
        command="widget",
        widget_command="update",
        func=fake_handler,
    )

    class FakeParser:
        def parse_args(self, argv: list[str] | None = None) -> argparse.Namespace:
            return fake_args

    monkeypatch.setattr(mural_module, "_build_parser", FakeParser)
    monkeypatch.setattr(mural_module, "_autoload_credentials", lambda _profile: None)
    monkeypatch.setattr(
        mural_module,
        "_require_scope",
        lambda *args, **kwargs: (_ for _ in ()).throw(
            mural_module.MuralAuthScopeError("murals:write", ("murals:read",))
        ),
    )

    assert mural_module.main([]) == mural_module.EXIT_NOPERM
    assert called == []


def test_collect_readiness_uses_only_injected_local_probes(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: pathlib.Path,
) -> None:
    module = doctor_module()
    unexpected = lambda *_args, **_kwargs: (_ for _ in ()).throw(  # noqa: E731
        AssertionError("ambient readiness probe used")
    )
    monkeypatch.setattr(mural_module, "_resolve_credential_file", unexpected)
    monkeypatch.setattr(mural_module, "_resolve_token_store_path", unexpected)
    monkeypatch.setattr(mural_module, "_load_token_store", unexpected)
    token_path = tmp_path / "synthetic-token.json"
    store = {
        "schema_version": 2,
        "active_profile": "default",
        "profiles": {
            "default": {
                "client_id": TEST_CLIENT_ID,
                "access_token": "synthetic-access",
                "token_type": "Bearer",
                "obtained_at": 0,
                "expires_at": 1_900_000_000,
                "granted_scopes": ["murals:read"],
            }
        },
    }

    result = module.collect_readiness(
        argparse.Namespace(profile="default", require_scope=["murals:read"]),
        cwd=pathlib.Path(__file__).parents[1],
        dependency_probe=lambda: True,
        credential_file_resolver=lambda _profile: tmp_path / "credentials.env",
        token_store_path_resolver=lambda: token_path,
        token_store_loader=lambda path: store if path == token_path else None,
    )

    assert result["verdict"] == "ready"


def test_command_scope_map_covers_all_mutation_families(mural_module: Any) -> None:
    expected = {
        ("room", "create"),
        ("mural", "create"),
        ("mural", "duplicate"),
        ("mural", "clone-with-tags"),
        ("mural", "archive"),
        ("mural", "unarchive"),
        ("mural", "repair-tag-drift"),
        ("template", "instantiate"),
        ("template", "create"),
        ("widget", "update"),
        ("widget", "delete"),
        ("widget", "create-bulk"),
        ("widget", "update-bulk"),
        ("widget", "create"),
        ("tag", "create"),
        ("tag", "apply"),
        ("tag", "remove"),
        ("area", "create"),
        ("area", "probe"),
        ("layout", "grid"),
        ("layout", "cluster"),
        ("layout", "column"),
        ("layout", "row"),
        ("compose", "bootstrap-dt-board"),
        ("compose", "bootstrap-ux-board"),
        ("compose", "populate-dt-section"),
        ("compose", "affinity-cluster"),
        ("voting", "session-create"),
        ("voting", "session-open"),
        ("voting", "session-close"),
        ("voting", "session-delete"),
    }

    assert expected == set(mural_module.COMMAND_REQUIRED_SCOPES)


def test_every_scope_map_key_is_reachable_from_parsed_namespace(
    mural_module: Any,
) -> None:
    attributes = {
        "room": "room_command",
        "mural": "mural_command",
        "template": "template_command",
        "widget": "widget_command",
        "tag": "tag_command",
        "area": "area_command",
        "layout": "layout_command",
        "compose": "compose_command",
        "voting": "voting_command",
    }

    observed = {
        mural_module.command_key(
            argparse.Namespace(command=command, **{attributes[command]: subcommand})
        )
        for command, subcommand in mural_module.COMMAND_REQUIRED_SCOPES
    }

    assert observed == set(mural_module.COMMAND_REQUIRED_SCOPES)


def test_multi_scope_command_requires_every_declared_scope(mural_module: Any) -> None:
    args = argparse.Namespace(command="template", template_command="instantiate")

    assert mural_module.required_scopes_for_args(args) == (
        "templates:read",
        "murals:write",
    )


def test_caller_and_bootstrap_scope_declarations_match_exported_policy(
    mural_module: Any,
) -> None:
    repo_root = pathlib.Path(__file__).parents[5]
    skills = pathlib.Path(__file__).parents[3]
    paths = [
        skills / "experimental/mural/references/bootstrap.md",
        repo_root / ".github/agents/design-thinking/dt-coach.agent.md",
        skills / "project-planning/rai-planner/references/mural-board-bootstrap.md",
        repo_root / ".github/agents/project-planning/ux-ui-designer.agent.md",
    ]
    documented_scopes = {
        scope
        for path in paths
        for scope in re.findall(
            r"--require-scope\s+([a-z]+:(?:read|write))",
            path.read_text(encoding="utf-8"),
        )
    }
    policy_scopes = {
        scope
        for scopes in mural_module.COMMAND_REQUIRED_SCOPES.values()
        for scope in scopes
    }

    assert documented_scopes
    assert documented_scopes <= policy_scopes


def _record(
    *, access_token: str = "", refresh_token: str = "", scopes: tuple[str, ...] = ()
) -> dict[str, Any]:
    record: dict[str, Any] = {
        "client_id": TEST_CLIENT_ID,
        "access_token": access_token,
        "token_type": "Bearer",
        "obtained_at": 0,
        "expires_at": 1_900_000_000,
        "granted_scopes": list(scopes),
    }
    if refresh_token:
        record["refresh_token"] = refresh_token
    return record


def _store(
    profiles: dict[str, dict[str, Any]], active_profile: str | None = None
) -> dict[str, Any]:
    store: dict[str, Any] = {"schema_version": 2, "profiles": profiles}
    if active_profile is not None:
        store["active_profile"] = active_profile
    return store


def _doctor_verdict(
    module: Any,
    store: dict[str, Any] | None,
    tmp_path: pathlib.Path,
    *,
    profile: str | None = None,
    require_scope: tuple[str, ...] = (),
) -> str:
    token_path = tmp_path / "doctor-token.json"
    result = module.collect_readiness(
        argparse.Namespace(profile=profile, require_scope=list(require_scope)),
        cwd=pathlib.Path(__file__).parents[1],
        dependency_probe=lambda: True,
        credential_file_resolver=lambda _profile: tmp_path / "doctor-credentials.env",
        token_store_path_resolver=lambda: token_path,
        token_store_loader=lambda path: store if path == token_path else None,
    )
    return result["verdict"]


def _forbid_backend_probes(monkeypatch: pytest.MonkeyPatch, mural_module: Any) -> None:
    def _boom(*_args: Any, **_kwargs: Any) -> Any:
        raise AssertionError("doctor must not probe a credential backend")

    monkeypatch.setattr(mural_module, "_probe_keyring_availability", _boom)
    monkeypatch.setattr(mural_module, "KeyringBackend", _boom)
    monkeypatch.setattr(mural_module, "FileBackend", _boom)


_SESSION_STATES = [
    pytest.param(_store({"default": _record()}), False, False, id="setup-only-profile"),
    pytest.param(
        _store({"default": _record(access_token="access")}),
        False,
        True,
        id="store-access-token",
    ),
    pytest.param(
        _store({"default": _record(refresh_token="refresh")}),
        False,
        True,
        id="store-refresh-token-only",
    ),
    pytest.param(None, True, False, id="backend-refresh-token-only"),
    pytest.param(None, False, False, id="client-configuration-only"),
    pytest.param(
        _store(
            {"default": _record(), "work": _record(access_token="access")},
            active_profile="work",
        ),
        False,
        True,
        id="active-profile-authenticated",
    ),
    pytest.param(
        _store(
            {"default": _record(access_token="access"), "work": _record()},
            active_profile="work",
        ),
        False,
        False,
        id="active-profile-setup-only",
    ),
    pytest.param(
        _store({"default": {"access_token": "access", "refresh_token": "refresh"}}),
        False,
        False,
        id="malformed-record-with-tokens",
    ),
]


@pytest.mark.parametrize(
    ("store", "backend_refresh_token", "expected_logged_in"), _SESSION_STATES
)
def test_given_local_session_state_when_doctor_and_status_run_then_login_state_agrees(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: pathlib.Path,
    capsys: pytest.CaptureFixture[str],
    store: dict[str, Any] | None,
    backend_refresh_token: bool,
    expected_logged_in: bool,
) -> None:
    """Doctor reports logged in exactly when auth status reports authenticated."""
    # Arrange
    module = doctor_module()
    credential_path = tmp_path / "mural.parity.env"
    monkeypatch.setenv(ENV_ENV_FILE, str(credential_path))
    monkeypatch.setenv(ENV_TOKEN_STORE, str(tmp_path / "status-token.json"))
    monkeypatch.setenv("MURAL_CREDENTIAL_BACKEND", "file")
    monkeypatch.setenv("MURAL_REFRESH_TOKEN", "")
    monkeypatch.setattr(
        mural_module, "_probe_keyring_availability", lambda: (False, None, None)
    )
    monkeypatch.setattr(mural_module, "_load_token_store", lambda _path: store)
    if backend_refresh_token:
        mural_module.FileBackend(credential_path).set(
            "ignored", "MURAL_REFRESH_TOKEN", "seeded"
        )

    # Act
    mural_module.main(["auth", "status"])
    status = json.loads(capsys.readouterr().out)
    _forbid_backend_probes(monkeypatch, mural_module)
    verdict = _doctor_verdict(module, store, tmp_path)

    # Assert
    assert status["authenticated"] is expected_logged_in
    assert status["backend_refresh_token"] is backend_refresh_token
    assert (verdict == "ready") is expected_logged_in
    assert verdict in {"ready", "needs_login"}


def test_given_active_profile_with_write_scope_when_doctor_requires_write_then_ready(
    mural_module: Any,
    tmp_path: pathlib.Path,
) -> None:
    """Doctor reads granted scopes from the store's active profile."""
    # Arrange
    module = doctor_module()
    store = _store(
        {
            "default": _record(access_token="a", scopes=("murals:read",)),
            "work": _record(access_token="b", scopes=("murals:read", "murals:write")),
        },
        active_profile="work",
    )

    # Act
    verdict = _doctor_verdict(module, store, tmp_path, require_scope=("murals:write",))

    # Assert
    assert verdict == "ready"


def test_given_invalid_profile_name_when_doctor_runs_then_needs_login_verdict(
    mural_module: Any,
    tmp_path: pathlib.Path,
) -> None:
    """An invalid profile name yields a verdict instead of an exception."""
    # Arrange
    module = doctor_module()
    store = _store({"default": _record(access_token="access")})

    # Act
    verdict = _doctor_verdict(module, store, tmp_path, profile="not a profile!")

    # Assert
    assert verdict == "needs_login"


def _write_scope_store(
    path: pathlib.Path,
    *,
    active_profile: str,
    work_scopes: tuple[str, ...],
    default_scopes: tuple[str, ...],
) -> None:
    path.write_text(
        json.dumps(
            _store(
                {
                    "default": _record(access_token="a", scopes=default_scopes),
                    "work": _record(access_token="b", scopes=work_scopes),
                },
                active_profile=active_profile,
            )
        ),
        encoding="utf-8",
    )


def _dispatch_with_fake_handler(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    *,
    profile: str | None,
    command: str = "widget",
    subcommand_attr: str = "widget_command",
    subcommand: str = "update",
) -> tuple[int, list[str]]:
    called: list[str] = []

    def fake_handler(_args: argparse.Namespace) -> int:
        called.append("handler")
        return mural_module.EXIT_SUCCESS

    fake_args = argparse.Namespace(
        log_level="WARNING",
        quiet=False,
        json_output=False,
        profile=profile,
        command=command,
        func=fake_handler,
        **{subcommand_attr: subcommand},
    )

    class FakeParser:
        def parse_args(self, argv: list[str] | None = None) -> argparse.Namespace:
            return fake_args

    monkeypatch.setattr(mural_module, "_build_parser", FakeParser)
    monkeypatch.setattr(mural_module, "_autoload_credentials", lambda _profile: None)
    return mural_module.main([]), called


def test_given_active_write_scope_when_scoped_dispatch_then_allowed(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    fake_token_store: pathlib.Path,
) -> None:
    """The dispatch scope gate checks the store's active profile."""
    # Arrange
    _write_scope_store(
        fake_token_store,
        active_profile="work",
        work_scopes=("murals:read", "murals:write"),
        default_scopes=("murals:read",),
    )

    # Act
    rc, called = _dispatch_with_fake_handler(mural_module, monkeypatch, profile=None)

    # Assert
    assert rc == mural_module.EXIT_SUCCESS
    assert called == ["handler"]


def test_given_active_read_only_when_scoped_dispatch_then_denied(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    fake_token_store: pathlib.Path,
) -> None:
    """A write scope on the default profile does not authorize the active one."""
    # Arrange
    _write_scope_store(
        fake_token_store,
        active_profile="work",
        work_scopes=("murals:read",),
        default_scopes=("murals:read", "murals:write"),
    )

    # Act
    rc, called = _dispatch_with_fake_handler(mural_module, monkeypatch, profile=None)

    # Assert
    assert rc == mural_module.EXIT_NOPERM
    assert called == []


def test_given_profile_flag_when_scoped_dispatch_then_overrides_active(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    fake_token_store: pathlib.Path,
) -> None:
    """``--profile`` takes precedence over the store's active profile."""
    # Arrange
    _write_scope_store(
        fake_token_store,
        active_profile="work",
        work_scopes=("murals:read", "murals:write"),
        default_scopes=("murals:read",),
    )

    # Act
    rc, called = _dispatch_with_fake_handler(
        mural_module, monkeypatch, profile="default"
    )

    # Assert
    assert rc == mural_module.EXIT_NOPERM
    assert called == []


def test_given_invalid_profile_when_scoped_dispatch_then_validation_error(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    fake_token_store: pathlib.Path,
    capsys: pytest.CaptureFixture[str],
) -> None:
    """An invalid profile name fails as a usage error, not a scope denial."""
    # Arrange
    _write_scope_store(
        fake_token_store,
        active_profile="work",
        work_scopes=("murals:read", "murals:write"),
        default_scopes=("murals:read", "murals:write"),
    )

    # Act
    rc, called = _dispatch_with_fake_handler(
        mural_module, monkeypatch, profile="not a profile!"
    )

    # Assert
    assert rc == mural_module.EXIT_FAILURE
    assert called == []
    assert "invalid profile name" in capsys.readouterr().err


def test_given_malformed_store_when_unscoped_command_dispatches_then_handler_runs(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    fake_token_store: pathlib.Path,
) -> None:
    """Commands without required scopes never load the token store at dispatch."""
    # Arrange
    fake_token_store.write_text("not json", encoding="utf-8")

    # Act
    rc, called = _dispatch_with_fake_handler(
        mural_module,
        monkeypatch,
        profile=None,
        command="room",
        subcommand_attr="room_command",
        subcommand="list",
    )

    # Assert
    assert rc == mural_module.EXIT_SUCCESS
    assert called == ["handler"]
