#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Offline readiness and command-scope policy for the Mural CLI."""

from __future__ import annotations

import argparse
import importlib.util
import os
import pathlib
import sys
from typing import Any, Callable, Mapping, Sequence

COMMAND_REQUIRED_SCOPES: Mapping[tuple[str, str], tuple[str, ...]] = {
    ("room", "create"): ("rooms:write",),
    ("mural", "create"): ("murals:write",),
    ("mural", "duplicate"): ("murals:write",),
    ("mural", "clone-with-tags"): ("murals:write",),
    ("mural", "archive"): ("murals:write",),
    ("mural", "unarchive"): ("murals:write",),
    ("mural", "repair-tag-drift"): ("murals:write",),
    ("template", "instantiate"): ("templates:read", "murals:write"),
    ("template", "create"): ("murals:read", "templates:write"),
    ("widget", "update"): ("murals:write",),
    ("widget", "delete"): ("murals:write",),
    ("widget", "create-bulk"): ("murals:write",),
    ("widget", "update-bulk"): ("murals:write",),
    ("widget", "create"): ("murals:write",),
    ("tag", "create"): ("murals:write",),
    ("tag", "apply"): ("murals:write",),
    ("tag", "remove"): ("murals:write",),
    ("area", "create"): ("murals:write",),
    ("area", "probe"): ("murals:write",),
    ("layout", "grid"): ("murals:write",),
    ("layout", "cluster"): ("murals:write",),
    ("layout", "column"): ("murals:write",),
    ("layout", "row"): ("murals:write",),
    ("compose", "bootstrap-dt-board"): ("rooms:write", "murals:write"),
    ("compose", "bootstrap-ux-board"): ("murals:write",),
    ("compose", "populate-dt-section"): ("murals:write",),
    ("compose", "affinity-cluster"): ("murals:write",),
    ("voting", "session-create"): ("murals:write",),
    ("voting", "session-open"): ("murals:write",),
    ("voting", "session-close"): ("murals:write",),
    ("voting", "session-delete"): ("murals:write",),
}


def evaluate_readiness(
    *,
    cwd_ok: bool,
    dependencies_available: bool,
    configured: bool,
    logged_in: bool,
    granted_scopes: Sequence[str],
    required_scopes: Sequence[str],
) -> dict[str, Any]:
    """Return the first dependency-ordered readiness verdict."""
    if not cwd_ok:
        verdict = "wrong_cwd"
    elif not dependencies_available:
        verdict = "deps_missing"
    elif not configured:
        verdict = "needs_setup"
    elif not logged_in:
        verdict = "needs_login"
    elif not set(required_scopes) <= set(granted_scopes):
        verdict = "needs_scope_upgrade"
    else:
        verdict = "ready"
    return {
        "verdict": verdict,
        "required_scopes": list(required_scopes),
        "granted_scopes": list(granted_scopes),
    }


def command_key(args: argparse.Namespace) -> tuple[str, str] | None:
    """Return the policy key for a parsed command namespace."""
    command = getattr(args, "command", None)
    if command == "widget":
        subcommand = getattr(args, "widget_command", None)
        if subcommand == "create":
            return ("widget", "create")
        if subcommand == "diff" and not getattr(args, "apply", False):
            return None
        return ("widget", subcommand) if subcommand else None
    attribute = {
        "room": "room_command",
        "mural": "mural_command",
        "template": "template_command",
        "tag": "tag_command",
        "area": "area_command",
        "layout": "layout_command",
        "compose": "compose_command",
        "voting": "voting_command",
    }.get(command)
    if attribute is None:
        return None
    subcommand = getattr(args, attribute, None)
    return (command, subcommand) if subcommand else None


def required_scopes_for_args(args: argparse.Namespace) -> tuple[str, ...]:
    """Return every scope required before dispatching ``args``."""
    if (
        getattr(args, "command", None) == "widget"
        and getattr(args, "widget_command", None) == "diff"
        and getattr(args, "apply", False)
    ):
        return ("murals:write",)
    key = command_key(args)
    return COMMAND_REQUIRED_SCOPES.get(key, ()) if key else ()


def _cwd_is_supported(cwd: pathlib.Path) -> bool:
    module_path = pathlib.Path(__file__).resolve()
    skill_root = module_path.parents[2]
    repo_root = module_path.parents[6]
    resolved = cwd.resolve()
    return resolved in {skill_root, skill_root / "scripts", repo_root}


def _dependencies_available() -> bool:
    return all(
        importlib.util.find_spec(name) is not None
        for name in ("keyring", "networkx", "shapely", "yaml")
    )


def collect_readiness(
    args: argparse.Namespace,
    *,
    cwd: pathlib.Path | None = None,
    dependency_probe: Callable[[], bool] | None = None,
    credential_file_resolver: Callable[[str], pathlib.Path] | None = None,
    token_store_path_resolver: Callable[[], pathlib.Path] | None = None,
    token_store_loader: Callable[[pathlib.Path], dict[str, Any] | None] | None = None,
) -> dict[str, Any]:
    """Inspect local state without refreshing tokens or contacting Mural."""
    package = sys.modules[__package__]

    profile_name = getattr(args, "profile", None) or os.environ.get(
        "MURAL_PROFILE", "default"
    )
    resolve_credential_file = (
        credential_file_resolver or package._resolve_credential_file
    )
    resolve_token_store_path = (
        token_store_path_resolver or package._resolve_token_store_path
    )
    load_token_store = token_store_loader or package._load_token_store
    credential_file = resolve_credential_file(profile_name)
    configured = bool(os.environ.get("MURAL_CLIENT_ID")) or credential_file.exists()
    store = load_token_store(resolve_token_store_path())
    try:
        profile = package._select_profile(store or {}, profile_name)
    except Exception:
        profile = {}
    logged_in = bool(profile.get("access_token") or profile.get("refresh_token"))
    return evaluate_readiness(
        cwd_ok=_cwd_is_supported(cwd or pathlib.Path.cwd()),
        dependencies_available=(dependency_probe or _dependencies_available)(),
        configured=configured,
        logged_in=logged_in,
        granted_scopes=package._token_granted_scopes(store, profile_name),
        required_scopes=tuple(getattr(args, "require_scope", ()) or ()),
    )


def _cmd_doctor(args: argparse.Namespace) -> int:
    """Emit one local readiness verdict without authentication or network use."""
    package = sys.modules[__package__]
    return package._emit_record(collect_readiness(args), args)
