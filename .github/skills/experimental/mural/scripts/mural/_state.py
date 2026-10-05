#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Shared process-level mutable state for the Mural package.

This is a dependency-free leaf module: it imports only the standard library
and never imports sibling ``mural`` submodules. It holds cross-module mutable
state so that extracted submodules and the package facade observe a single
live object. Consumers reach that state through the accessor functions below
(``from . import _state`` then ``_state.cli_quiet()``) rather than by-name
import, so updates remain visible across module boundaries.

Each holder is a container that is mutated in place and never rebound, and
every holder is read here by its accessor. A module-level name rebound from
another module, or from inside a function, would leave its defining module
with no reader of the stored value.
"""

from __future__ import annotations

import collections
import dataclasses
from typing import Any


@dataclasses.dataclass
class _CliFlags:
    """CLI presentation flags resolved once by ``main()``."""

    quiet: bool = False
    force_json: bool = False
    color: bool = False
    profile: str | None = None


# CLI presentation flags set once by ``main()`` from parsed arguments and read
# by output helpers across the package. Defaults apply when invoked as a
# library without going through ``main()``.
_CLI_FLAGS = _CliFlags()

# Module-level dedup sets enforce one-WARN-per-process semantics across
# repeated resolve_backend calls within the same Python process.
_seen_fallback_warn: set[str] = set()
_seen_concurrent_warn: set[tuple[str, str]] = set()
# Tracks credential paths that already emitted the relaxed-mode WARN.
_seen_relaxed_warn: set[str] = set()

# In-process registry of pending confirmation previews. Keyed by an opaque
# UUID returned in a ``confirmation_required`` envelope; consumed when the
# caller re-invokes with ``confirmed_id`` matching the preview.
_PENDING_CONFIRMATIONS: dict[str, dict[str, Any]] = {}
_CONFIRMATION_TTL_S = 600.0

# In-process registry of templates surfaced by ``mural_template_list``.
_TEMPLATE_REGISTRY: list[dict[str, str]] = []

# In-process idempotency cache for create-style tools. Bounded LRU using
# ``OrderedDict``; holds previously formatted tool results keyed by
# ``(tool_name, idempotency_key)``. Process-local only — not persisted.
_IDEMPOTENCY_MAX = 128
_IDEMPOTENCY_CACHE: "collections.OrderedDict[tuple[str, str], dict[str, Any]]" = (
    collections.OrderedDict()
)


def set_cli_flags(
    *, quiet: bool, force_json: bool, color: bool, profile: str | None
) -> None:
    """Record the CLI presentation flags resolved from parsed arguments."""
    _CLI_FLAGS.quiet = quiet
    _CLI_FLAGS.force_json = force_json
    _CLI_FLAGS.color = color
    _CLI_FLAGS.profile = profile


def cli_quiet() -> bool:
    return _CLI_FLAGS.quiet


def cli_force_json() -> bool:
    return _CLI_FLAGS.force_json


def cli_color() -> bool:
    return _CLI_FLAGS.color


def cli_profile() -> str | None:
    return _CLI_FLAGS.profile


def seen_fallback_warn() -> set[str]:
    return _seen_fallback_warn


def seen_concurrent_warn() -> set[tuple[str, str]]:
    return _seen_concurrent_warn


def seen_relaxed_warn() -> set[str]:
    return _seen_relaxed_warn


def pending_confirmations() -> dict[str, dict[str, Any]]:
    return _PENDING_CONFIRMATIONS


def confirmation_ttl_seconds() -> float:
    return _CONFIRMATION_TTL_S


def template_registry() -> list[dict[str, str]]:
    return _TEMPLATE_REGISTRY


def idempotency_cache() -> "collections.OrderedDict[tuple[str, str], dict[str, Any]]":
    return _IDEMPOTENCY_CACHE


def idempotency_max() -> int:
    return _IDEMPOTENCY_MAX
