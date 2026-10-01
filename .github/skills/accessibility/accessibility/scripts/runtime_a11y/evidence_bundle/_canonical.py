# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

"""Canonical JSON and digest helpers for accessibility evidence."""

from __future__ import annotations

import hashlib
import json
from typing import Any

_ORDERED_ARRAY_KEYS = frozenset({"steps"})


def _canonicalize(value: Any, parent_key: str | None = None) -> Any:
    if isinstance(value, dict):
        return {key: _canonicalize(value[key], key) for key in sorted(value)}
    if isinstance(value, list):
        items = [_canonicalize(item) for item in value]
        if parent_key not in _ORDERED_ARRAY_KEYS:
            items.sort(
                key=lambda item: json.dumps(item, sort_keys=True, separators=(",", ":"))
            )
        return items
    return value


def canonical_json(value: Any) -> str:
    """Return deterministic UTF-8-compatible JSON with one LF terminator."""
    return (
        json.dumps(
            _canonicalize(value),
            ensure_ascii=False,
            separators=(",", ":"),
            sort_keys=True,
        )
        + "\n"
    )


def canonical_digest(value: Any, *, domain: str) -> str:
    """Return a domain-separated SHA-256 digest for a JSON-compatible value."""
    payload = domain.encode("utf-8") + b"\0" + canonical_json(value).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()
