#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Shared process-level mutable state for the Mural package.

This is a dependency-free leaf module: it imports only the standard library
and never imports sibling ``mural`` submodules. It holds cross-module mutable
globals so that extracted submodules and the package facade observe a single
live binding. Consumers read and write these via attribute access on the
module object (``from . import _state`` then ``_state.X``) rather than by-name
import, so updates remain visible across module boundaries.
"""

from __future__ import annotations

import collections
from typing import Any

# CLI presentation flags set once by ``main()`` from parsed arguments and read
# by output helpers across the package. Defaults apply when invoked as a
# library without going through ``main()``.
_CLI_QUIET: bool = False
_CLI_FORCE_JSON: bool = False
_CLI_COLOR: bool = False
_CLI_PROFILE: str | None = None

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
