# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""EV-06 readiness and dispatch-time scope tests."""

from __future__ import annotations

import argparse
import importlib
import importlib.util
import pathlib
import re
from typing import Any

import pytest
from test_constants import TEST_CLIENT_ID


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
    paths = [
        repo_root
        / ".github/instructions/experimental/mural/mural-bootstrap.instructions.md",
        repo_root / ".github/agents/design-thinking/dt-coach.agent.md",
        repo_root / ".github/agents/rai-planning/rai-planner.agent.md",
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
