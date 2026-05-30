# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Tests for `scripts._utils` path-safety helpers.

Covers the consolidated guards extracted during PR review:

* `has_traversal_segments` detects `..` separated by `/` or `\\` (cross-platform)
* `safe_resolve` rejects traversal, enforces allow-root containment, and is
  symlink-safe by resolving both candidate and roots before comparison
"""

from __future__ import annotations

from pathlib import Path

import pytest

_utils = pytest.importorskip("scripts._utils")


class TestHasTraversalSegments:
    def test_given_forward_slash_dotdot_when_checked_then_true(self) -> None:
        # Arrange
        path = Path("a/../b")

        # Act / Assert
        assert _utils.has_traversal_segments(path) is True

    def test_given_backslash_dotdot_when_checked_then_true(self) -> None:
        # Arrange — on POSIX this parses as a single filename, so the
        # normalization step is what catches it.
        path = Path("..\\..\\evil")

        # Act / Assert
        assert _utils.has_traversal_segments(path) is True

    def test_given_plain_relative_path_when_checked_then_false(self) -> None:
        # Arrange
        path = Path("docs/planning/adrs/demo")

        # Act / Assert
        assert _utils.has_traversal_segments(path) is False

    def test_given_filename_containing_dotdot_substring_when_checked_then_false(self) -> None:
        # Arrange — "..foo" is a legitimate single segment, not a traversal.
        path = Path("docs/..foo/bar")

        # Act / Assert
        assert _utils.has_traversal_segments(path) is False


class TestSafeResolve:
    def test_given_path_inside_allow_root_when_resolved_then_returns_resolved(self, tmp_path: Path) -> None:
        # Arrange
        root = tmp_path / "project"
        root.mkdir()
        target = root / "0001-decision.md"
        target.write_text("x", encoding="utf-8")

        # Act
        resolved = _utils.safe_resolve(target, [root])

        # Assert
        assert resolved == target.resolve()

    def test_given_path_with_traversal_when_resolved_then_raises(self, tmp_path: Path) -> None:
        # Arrange
        root = tmp_path / "project"
        root.mkdir()
        target = root / ".." / "escape.md"

        # Act / Assert
        with pytest.raises(ValueError, match="traversal segments"):
            _utils.safe_resolve(target, [root])

    def test_given_path_outside_all_roots_when_resolved_then_raises(self, tmp_path: Path) -> None:
        # Arrange
        root = tmp_path / "allowed"
        root.mkdir()
        outside = tmp_path / "other" / "file.md"
        outside.parent.mkdir()
        outside.write_text("x", encoding="utf-8")

        # Act / Assert
        with pytest.raises(ValueError, match="outside permitted roots"):
            _utils.safe_resolve(outside, [root])

    def test_given_multiple_roots_when_one_matches_then_returns_resolved(self, tmp_path: Path) -> None:
        # Arrange
        root_a = tmp_path / "a"
        root_b = tmp_path / "b"
        root_a.mkdir()
        root_b.mkdir()
        target = root_b / "0002-decision.md"
        target.write_text("x", encoding="utf-8")

        # Act
        resolved = _utils.safe_resolve(target, [root_a, root_b])

        # Assert
        assert resolved == target.resolve()
