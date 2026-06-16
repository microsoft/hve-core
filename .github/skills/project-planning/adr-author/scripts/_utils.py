# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Shared path-safety helpers for adr-author scripts.

Consolidates the path-traversal guard and allow-root containment check that
were previously duplicated (with subtle divergences) across the skill's
scripts. The canonical ``safe_resolve`` rejects ``..`` segments using a
cross-platform check and resolves both the candidate path and every allow-root
before the containment test so the guard remains symlink-safe.
"""

from __future__ import annotations

from pathlib import Path


def has_traversal_segments(path: Path) -> bool:
    """Return True if ``path`` contains ``..`` segments separated by ``/`` or ``\\``.

    Cross-platform: on Linux ``Path("..\\..\\evil")`` parses as a single
    filename, so checking only ``path.parts`` misses backslash-separated
    traversals. This helper normalizes both separators before splitting.
    """
    normalized = str(path).replace("\\", "/")
    return ".." in path.parts or ".." in normalized.split("/")


def safe_resolve(path: Path, allow_roots: list[Path]) -> Path:
    """Resolve ``path`` ensuring it stays under one of ``allow_roots``.

    Rejects any input containing ``..`` segments (``/`` or ``\\`` separated)
    before resolution, then resolves both the candidate and each allow-root so
    the containment check follows symlinks consistently. Raises ``ValueError``
    when the path contains traversal segments or escapes every allow-root.
    """
    if has_traversal_segments(path):
        raise ValueError(f"path '{path}' contains traversal segments")
    resolved = path.expanduser().resolve()
    for root in allow_roots:
        try:
            root_resolved = root.expanduser().resolve()
        except OSError:
            continue
        try:
            if resolved.is_relative_to(root_resolved):
                return resolved
        except ValueError:
            continue
    raise ValueError(f"path '{path}' resolves outside permitted roots: " + ", ".join(str(r) for r in allow_roots))
