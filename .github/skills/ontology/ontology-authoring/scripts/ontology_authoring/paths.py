# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Confine Ontology Builder state and artifact paths to one project root."""

from __future__ import annotations

import re
import subprocess
from pathlib import Path

PROJECT_SLUG_PATTERN = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


class PathBoundaryError(ValueError):
    """Raised when a requested path escapes the project boundary."""


def resolve_project_root(workspace_root: Path, project_slug: str) -> Path:
    """Return a confined project root for a validated project slug."""
    if not PROJECT_SLUG_PATTERN.fullmatch(project_slug):
        raise PathBoundaryError(f"Invalid project slug: {project_slug}")

    workspace = workspace_root.expanduser().resolve(strict=True)
    tracking_root = workspace / ".copilot-tracking" / "ontology-builder"
    project_root = tracking_root / project_slug
    _reject_existing_symlink(project_root)
    return project_root


def resolve_descendant(
    project_root: Path,
    requested_path: Path,
    *,
    must_exist: bool = False,
) -> Path:
    """Resolve a path and reject traversal or symlink escape from the project root."""
    expanded_root = project_root.expanduser().absolute()
    root = expanded_root.resolve(strict=True)
    if project_root.is_symlink() or expanded_root != root:
        raise PathBoundaryError(
            f"Project root contains a symlink: {project_root}")
    candidate = requested_path if requested_path.is_absolute() else root / \
        requested_path
    resolved = candidate.expanduser().resolve(strict=must_exist)
    if not resolved.is_relative_to(root):
        raise PathBoundaryError(f"Path escapes project root: {requested_path}")
    return resolved


def is_ignored_path(workspace_root: Path, requested_path: Path) -> bool:
    """Return whether Git excludes a confined workspace path."""
    workspace = workspace_root.expanduser().resolve(strict=True)
    candidate = resolve_descendant(workspace, requested_path)
    relative_path = candidate.relative_to(workspace)
    result = subprocess.run(
        ["git", "-C", str(workspace), "check-ignore",
         "--quiet", "--", str(relative_path)],
        check=False,
        capture_output=True,
    )
    if result.returncode not in {0, 1}:
        message = result.stderr.decode(errors="replace").strip()
        raise PathBoundaryError(f"Could not evaluate ignore rules: {message}")
    return result.returncode == 0


def _reject_existing_symlink(path: Path) -> None:
    """Reject any existing symlink component in a not-yet-created project path."""
    current = path
    while not current.exists() and current != current.parent:
        current = current.parent
    if current.is_symlink():
        raise PathBoundaryError(f"Project path contains a symlink: {current}")
    resolved_parent = current.resolve(strict=True)
    if current.absolute() != resolved_parent:
        raise PathBoundaryError(
            f"Project path escapes through a symlink: {current}")
