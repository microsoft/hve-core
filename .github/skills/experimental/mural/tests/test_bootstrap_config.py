# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Tests for bootstrap-related constants and argparse wiring (Phase C).

Covers ``DEFAULT_LOGIN_SCOPES`` composition, ``DEFAULT_REDIRECT_URI``
loopback host choice, the ``_OAUTH_SETUP_WALKTHROUGH`` content, and the
``--no-test`` argparse flag added to ``mural auth bootstrap``.
"""

from __future__ import annotations

from typing import Any

# ---------------------------------------------------------------------------
# Scope and redirect-URI constants
# ---------------------------------------------------------------------------


def test_default_login_scopes_is_union_of_read_and_write(
    mural_module: Any,
) -> None:
    expected = " ".join(mural_module.READ_SCOPES + mural_module.WRITE_SCOPES)
    assert mural_module.DEFAULT_LOGIN_SCOPES == expected


def test_default_login_scopes_includes_each_read_scope(
    mural_module: Any,
) -> None:
    tokens = mural_module.DEFAULT_LOGIN_SCOPES.split()
    for scope in mural_module.READ_SCOPES:
        assert scope in tokens


def test_default_login_scopes_includes_each_write_scope(
    mural_module: Any,
) -> None:
    tokens = mural_module.DEFAULT_LOGIN_SCOPES.split()
    for scope in mural_module.WRITE_SCOPES:
        assert scope in tokens


def test_default_scopes_is_read_only(mural_module: Any) -> None:
    """Back-compat alias: ``DEFAULT_SCOPES`` stays read-only."""
    expected = " ".join(mural_module.READ_SCOPES)
    assert mural_module.DEFAULT_SCOPES == expected
    for scope in mural_module.WRITE_SCOPES:
        assert scope not in mural_module.DEFAULT_SCOPES.split()


def test_default_redirect_uri_uses_localhost_loopback(
    mural_module: Any,
) -> None:
    assert mural_module.DEFAULT_REDIRECT_URI == ("http://localhost:8765/callback")
    assert "127.0.0.1" not in mural_module.DEFAULT_REDIRECT_URI


# ---------------------------------------------------------------------------
# OAuth setup walkthrough content
# ---------------------------------------------------------------------------


def test_oauth_setup_walkthrough_documents_localhost_redirect(
    mural_module: Any,
) -> None:
    walkthrough = mural_module._OAUTH_SETUP_WALKTHROUGH
    assert "http://localhost:8765/callback" in walkthrough


def test_oauth_setup_walkthrough_references_default_login_scopes(
    mural_module: Any,
) -> None:
    walkthrough = mural_module._OAUTH_SETUP_WALKTHROUGH
    assert "DEFAULT_LOGIN_SCOPES" in walkthrough


def test_oauth_setup_walkthrough_references_bootstrap_command(
    mural_module: Any,
) -> None:
    walkthrough = mural_module._OAUTH_SETUP_WALKTHROUGH
    assert "mural auth bootstrap" in walkthrough


def test_oauth_setup_walkthrough_documents_credential_backends(
    mural_module: Any,
) -> None:
    walkthrough = mural_module._OAUTH_SETUP_WALKTHROUGH
    assert "MURAL_CREDENTIAL_BACKEND" in walkthrough
    for backend in ("keyring", "file", "env-only"):
        assert backend in walkthrough


def test_oauth_setup_walkthrough_documents_redaction_contract(
    mural_module: Any,
) -> None:
    walkthrough = mural_module._OAUTH_SETUP_WALKTHROUGH
    assert "Redaction contract" in walkthrough


# ---------------------------------------------------------------------------
# --no-test argparse wiring
# ---------------------------------------------------------------------------


def test_bootstrap_no_test_flag_parses_true(mural_module: Any) -> None:
    parser = mural_module._build_parser()
    args = parser.parse_args(["auth", "bootstrap", "--no-test"])
    assert getattr(args, "no_test", None) is True


def test_bootstrap_no_test_flag_default_is_false(mural_module: Any) -> None:
    parser = mural_module._build_parser()
    args = parser.parse_args(["auth", "bootstrap"])
    assert getattr(args, "no_test", None) is False


def test_bootstrap_no_test_flag_help_mentions_probe(
    mural_module: Any,
) -> None:
    parser = mural_module._build_parser()
    auth_action = next(
        a for a in parser._actions if getattr(a, "dest", None) == "command"
    )
    auth_subparsers = auth_action.choices["auth"]  # type: ignore[attr-defined]
    bootstrap_parser = auth_subparsers._actions[1].choices[  # type: ignore[attr-defined]
        "bootstrap"
    ]
    help_strings = [
        a.help
        for a in bootstrap_parser._actions
        if getattr(a, "dest", None) == "no_test"
    ]
    assert help_strings, "no --no-test action found on bootstrap parser"
    assert "probe" in (help_strings[0] or "").lower()
