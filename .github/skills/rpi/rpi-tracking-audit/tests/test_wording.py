# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""How status, readiness, outcome, and empty-list wording is read."""

from __future__ import annotations

import pytest
from builders import DAY, T, Workspace, changes_text, review_text
from rpi_tracking_audit._markdown import real_bullets, vocab_match

REVIEW = f"{T}/reviews/logs/{DAY}/alpha-review.md"


@pytest.mark.parametrize(
    "bullet",
    [
        "None - n/a",
        "*None*",
        "**None**",
        "`None`",
        "No blockers (yet)",
        "None (yet)",
        "None. Ready for review.",
        "None - all cleared in P02",
        "No release blockers",
        "No critical issues",
        "No pending items",
        "No open follow-up items",
    ],
)
def test_given_bullet_that_records_nothing_when_read_then_it_is_empty(
    bullet: str,
) -> None:
    # Act
    result = real_bullets(f"* {bullet}\n")

    # Assert
    assert result == []


@pytest.mark.parametrize(
    "bullet",
    [
        "None - resolved the login defect; the export defect is still open",
        "None - all resolved; no access to prod yet",
        "None - resolved, but export still fails",
        "No reply on issues",
        "No access to the staging database",
    ],
)
def test_given_bullet_with_a_second_clause_when_read_then_it_is_real(
    bullet: str,
) -> None:
    # Act
    result = real_bullets(f"* {bullet}\n")

    # Assert
    assert len(result) == 1


@pytest.mark.parametrize(
    "status",
    [
        "unable to fully complete",
        "yet to be Complete",
        "half complete",
        "Half-complete",
        "to be completed",
    ],
)
def test_given_status_word_qualified_away_when_matched_then_no_status(
    status: str,
) -> None:
    # Act
    result = vocab_match(status, ("Complete", "Partial", "Blocked"))

    # Assert
    assert result is None


@pytest.mark.parametrize(
    "final_outcome",
    [
        "Conformant (provisionally)",
        "Conformant, tentatively",
        "Conformant (not final)",
        "Conformant - rejected by the user",
        "Conformant if RV-002 is fixed",
    ],
)
def test_given_final_outcome_with_a_caveat_when_audited_then_not_accepted(
    ws: Workspace, final_outcome: str
) -> None:
    # Arrange
    ws.full_task(review=review_text(final_outcome=final_outcome))

    # Act
    row = ws.audit().board[0]

    # Assert
    assert row["state"] != "accepted"


@pytest.mark.parametrize(
    "final_outcome",
    ['"Conformant"', "Final: Conformant", "**Conformant**", "Conformant"],
)
def test_given_final_outcome_in_quotes_or_labeled_when_audited_then_accepted(
    ws: Workspace, final_outcome: str
) -> None:
    # Arrange
    ws.full_task(review=review_text(final_outcome=final_outcome))

    # Act
    row = ws.audit().board[0]

    # Assert
    assert row["state"] == "accepted"


@pytest.mark.parametrize(
    "readiness",
    [
        "ready for review once CI passes",
        "Ready - waiting for approval",
        "This isn't ready",
        "nearly ready",
        "Not quite ready",
    ],
)
def test_given_readiness_with_a_condition_when_audited_then_readiness_comes_first(
    ws: Workspace, readiness: str
) -> None:
    # Arrange
    ws.full_task("alpha", changes=changes_text("alpha", review_readiness=readiness))
    (ws.root / REVIEW).unlink()

    # Act
    row = ws.audit().board[0]

    # Assert
    assert row["next"].startswith("clear Review readiness")


@pytest.mark.parametrize("readiness", ["Ready", "Ready for review", "ready."])
def test_given_plain_ready_when_audited_then_review_is_next(
    ws: Workspace, readiness: str
) -> None:
    # Arrange
    ws.full_task("alpha", changes=changes_text("alpha", review_readiness=readiness))
    (ws.root / REVIEW).unlink()

    # Act
    row = ws.audit().board[0]

    # Assert
    assert "/rpi-review" in row["next"]
    assert not row["next"].startswith("clear Review readiness")
