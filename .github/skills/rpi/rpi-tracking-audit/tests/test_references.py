# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Keep the reference documents in step with the rule table and the state vocabulary."""

from __future__ import annotations

import ast
import inspect
import re
import textwrap
from pathlib import Path

from rpi_tracking_audit._audit import Audit
from rpi_tracking_audit._rules import RULES

REFERENCES = Path(__file__).resolve().parent.parent / "references"
SKILL = REFERENCES.parent / "SKILL.md"


def _state_words_in_code() -> set[str]:
    """Every state word `Audit.task_state` can return, read from its syntax tree."""
    tree = ast.parse(textwrap.dedent(inspect.getsource(Audit.task_state)))
    words = {
        node.value
        for ret in ast.walk(tree)
        if isinstance(ret, ast.Return) and ret.value is not None
        for node in ast.walk(ret.value)
        if isinstance(node, ast.Constant)
        and isinstance(node.value, str)
        # the test of a conditional expression compares against artifact values
        and not any(
            isinstance(parent, ast.Compare) and node in ast.walk(parent)
            for parent in ast.walk(ret.value)
        )
        and not any(
            isinstance(parent, ast.JoinedStr) and node in ast.walk(parent)
            for parent in ast.walk(ret.value)
        )
    }
    words |= {f"review {w}" for w in ("complete", "partial", "blocked", "incomplete")}
    words.add("session only")  # a task known only from its session state file
    return words


def test_given_rule_catalog_when_read_then_every_rule_id_is_documented() -> None:
    # Arrange
    text = (REFERENCES / "rule-catalog.md").read_text(encoding="utf-8")

    # Act
    missing = [rule for rule in RULES if not re.search(rf"\b{rule}\b", text)]

    # Assert
    assert missing == []


def test_given_documents_when_read_then_rule_count_matches_table() -> None:
    # Arrange
    texts = [
        (REFERENCES / "rule-catalog.md").read_text(encoding="utf-8"),
        SKILL.read_text(encoding="utf-8"),
        (REFERENCES / "report-template.md").read_text(encoding="utf-8"),
    ]

    # Act
    counts = {int(n) for text in texts for n in re.findall(r"\b(\d+) rules\b", text)}
    counts |= {
        int(n) for text in texts for n in re.findall(r"\bN of (\d+) rules\b", text)
    }

    # Assert
    assert counts == {len(RULES)}


def test_given_report_template_when_read_then_state_words_match_code() -> None:
    # Arrange
    text = (REFERENCES / "report-template.md").read_text(encoding="utf-8")
    line = next(line for line in text.splitlines() if "uses these words:" in line)

    # Act
    # parenthetical notes quote fields and values, not state words
    documented = set(re.findall(r"`([^`]+)`", re.sub(r"\([^)]*\)", "", line)))

    # Assert
    assert documented == _state_words_in_code()
