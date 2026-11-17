# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""File classification, tracking-root discovery, state detection, and paths."""

from __future__ import annotations

from pathlib import Path

import pytest
from builders import DAY, T, Workspace
from rpi_tracking_audit._discovery import (
    classify_file,
    discover,
    find_tracking_roots,
    load_state,
    resolve_ref,
)


@pytest.mark.parametrize(
    ("rel", "expected"),
    [
        (
            f"plans/{DAY}/alpha-plan.md",
            ("current", "plans", "plan", "alpha", DAY, None, True, True),
        ),
        (
            f"reviews/plans/{DAY}/alpha-plan-critique-2.md",
            ("current", "reviews/plans", "critique", "alpha", DAY, 2, True, True),
        ),
        (
            "plans/alpha-plan.md",
            ("current", "plans", "plan", "alpha", None, None, False, True),
        ),
        (
            f"plans/{DAY}/odd.md",
            ("current", "plans", "plan", "odd", DAY, None, True, False),
        ),
        (
            f"plans/{DAY}/old-plan.instructions.md",
            ("legacy", "plans", "implementation plan", "old", DAY),
        ),
        (
            f"plans/logs/{DAY}/old-log.md",
            ("legacy", "plans/logs", "planning log", "old", DAY),
        ),
        (
            f"reviews/{DAY}/old-plan-review.md",
            ("legacy", "reviews", "review log", "old", DAY),
        ),
        ("security-plans/a.md", None),
    ],
)
def test_given_tracking_path_when_classified_then_kind_and_slug(
    rel: str, expected: tuple
) -> None:
    # Act
    result = classify_file(rel)

    # Assert
    assert result == expected


def test_given_review_logs_path_when_classified_then_not_legacy() -> None:
    # Act
    result = classify_file(f"reviews/logs/{DAY}/alpha-review.md")

    # Assert
    assert result is not None and result[0] == "current"


def test_given_deep_tree_when_roots_found_then_depth_limit_reported(
    tmp_path: Path,
) -> None:
    # Arrange
    (tmp_path / "a/b/c/d/e/f/g").mkdir(parents=True)
    (tmp_path / "a/.copilot-tracking").mkdir()

    # Act
    roots = find_tracking_roots(tmp_path)

    # Assert
    assert roots.top is None
    assert roots.nested == ["a/.copilot-tracking"]
    assert roots.depth_limited is True


def test_given_symlinked_entries_when_discovered_then_listed_not_read(
    ws: Workspace,
) -> None:
    # Arrange
    target = ws.write("outside/alpha-plan.md", "x")
    (ws.root / T / "plans" / DAY).mkdir(parents=True)
    (ws.root / T / "plans" / DAY / "alpha-plan.md").symlink_to(target)
    (ws.root / T / "research").symlink_to(ws.root / "outside", target_is_directory=True)

    # Act
    found = discover(ws.root, ws.root / T)

    # Assert
    assert found.artifacts == []
    assert found.symlinks == [f"{T}/plans/{DAY}/alpha-plan.md", f"{T}/research"]


def test_given_json_that_is_not_state_when_discovered_then_extra_file(
    ws: Workspace,
) -> None:
    # Arrange
    ws.write(f"{T}/plans/{DAY}/data.json", '{"a": 1}')
    ws.write(f"{T}/plans/{DAY}/broken.json", "{")

    # Act
    found = discover(ws.root, ws.root / T)

    # Assert
    assert sorted(rel for rel, _, _ in found.extras) == [
        f"{T}/plans/{DAY}/broken.json",
        f"{T}/plans/{DAY}/data.json",
    ]


def test_given_state_shaped_json_when_loaded_then_returned(tmp_path: Path) -> None:
    # Arrange
    path = tmp_path / "s.json"
    path.write_text(
        '{"task_slug": "a", "active_phase": null, "artifact_paths": {}}',
        encoding="utf-8",
    )

    # Act
    loaded = load_state(path)

    # Assert
    assert loaded is not None
    assert loaded[0] == {"task_slug": "a", "active_phase": None, "artifact_paths": {}}


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        (
            f"[{T}/plans/{DAY}/a-plan.md](../../plans/{DAY}/a-plan.md)",
            (
                f"../../plans/{DAY}/a-plan.md (link text {T}/plans/{DAY}/a-plan.md)",
                True,
            ),
        ),
        (f"[plan]({T}/plans/{DAY}/a-plan.md)", (f"{T}/plans/{DAY}/a-plan.md", True)),
        (
            f"[My plan](../../plans/{DAY}/gone.md)",
            (f"../../plans/{DAY}/gone.md (link text My plan)", False),
        ),
        (f"`{T}/plans/{DAY}/a-plan.md`", (f"{T}/plans/{DAY}/a-plan.md", True)),
        ("skipped", None),
        ("see the plan", None),
        ("", None),
    ],
)
def test_given_reference_when_resolved_then_display_and_existence(
    ws: Workspace, raw: str, expected: tuple | None
) -> None:
    # Arrange
    ws.write(f"{T}/plans/{DAY}/a-plan.md", "x")
    art_dir = ws.root / T / "changes" / DAY

    # Act
    result = resolve_ref(raw, art_dir, ws.root)

    # Assert
    assert (result[:2] if result else None) == expected
