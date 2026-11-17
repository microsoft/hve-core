# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Markdown parsing, vocabulary matching, and redaction helpers."""

from __future__ import annotations

from pathlib import Path

import pytest
from rpi_tracking_audit._markdown import (
    Doc,
    bullet_fields,
    capped,
    dash,
    field_table,
    labeled_blocks,
    line_number_reference,
    md_escape,
    nesting_depth,
    plural,
    read_text_checked,
    real_bullets,
    redact,
    redact_obj,
    short,
    strip_fences_and_comments,
    table_blocks,
    table_rows,
    vocab_match,
)
from rpi_tracking_audit._rules import OUTCOMES, PLAN_READINESS, VERDICTS


@pytest.mark.parametrize(
    ("value", "expected"),
    [
        ("Complete and Ready", "Ready"),
        ("Not ready: research gap", "Not ready"),
        ("Blocked: none. Ready", "Ready"),
        ("{{Complete/Partial}}", None),
        ("", None),
    ],
)
def test_given_readiness_text_when_matched_then_vocabulary_entry(
    value: str, expected: str | None
) -> None:
    # Act
    result = vocab_match(value, PLAN_READINESS)

    # Assert
    assert result == expected


def test_given_negated_outcome_when_matched_then_next_entry_wins() -> None:
    # Act
    result = vocab_match("No defects found; Conformant", OUTCOMES)

    # Assert
    assert result == "Conformant"


def test_given_verdict_in_file_name_when_matched_with_strip_paths_then_ignored() -> (
    None
):
    # Act
    result = vocab_match(
        "[link](reviews/revise-plan-critique.md) Pass", VERDICTS, strip_paths=True
    )

    # Assert
    assert result == "Pass"


def test_given_bold_labels_when_parsed_then_fields_read() -> None:
    # Act
    fields = bullet_fields(
        "* **Status:** Partial\n- Scope: full plan\n* Status: ignored"
    )

    # Assert
    assert fields == {"Status": "Partial", "Scope": "full plan"}


def test_given_table_without_outer_pipes_when_parsed_then_rows_read() -> None:
    # Act
    blocks = table_blocks("A | B\n--- | ---\n1 | 2\n\ntext")

    # Assert
    assert blocks == [(["A", "B"], [["1", "2"]])]


def test_given_field_table_with_bold_field_when_parsed_then_label_unwrapped() -> None:
    # Act
    table = field_table("| Field | Record |\n|---|---|\n| **Blockers** | none |")

    # Assert
    assert table == {"Blockers": "none"}


def test_given_doc_when_parsed_then_fenced_headings_ignored_and_sections_found() -> (
    None
):
    # Arrange
    doc = Doc(
        "# T\n\n## One\n\n```\n## Not a heading\n```\n\n### Sub\n\nbody\n\n## Two\n"
    )

    # Act
    subs = doc.subsection_bodies("One")

    # Assert
    assert doc.h2_titles() == ["One", "Two"]
    assert [t for t, _, _ in subs] == ["Sub"]
    assert doc.section("missing") == ""
    assert doc.heading_range(999) == (999, 1000)


def test_given_task_body_when_blocks_read_then_markers_end_blocks_and_fences_stay() -> (
    None
):
    # Arrange
    lines = [
        "Goals:",
        "* g <!-- note -->",
        "<!-- rpi:task id=P01-T01 -->",
        "* stray",
        "Details:",
        "* d",
        "```python",
        "# fixed columns",
        "```",
        "* FR-001",
        "#### Next",
        "* after",
    ]

    # Act
    blocks = labeled_blocks(lines)

    # Assert
    assert blocks == {
        "Goals": "* g  ",
        "Details": "* d\n```python\n# fixed columns\n```\n* FR-001",
    }


def test_given_private_key_when_redacted_then_line_count_kept() -> None:
    # Arrange
    text = "a\n-----BEGIN RSA PRIVATE KEY-----\nabc\n-----END RSA PRIVATE KEY-----\nb"

    # Act
    result = redact(text)

    # Assert
    assert "abc" not in result
    assert result.count("\n") == text.count("\n")


def test_given_nested_state_when_redacted_then_credential_keys_replaced() -> None:
    # Arrange
    obj = {
        "api_key": "x" * 10,
        "short_token": "abc",
        "list": [{"note": "AKIA" + "C" * 16}],
    }

    # Act
    result = redact_obj(obj)

    # Assert
    assert result["api_key"] == "[redacted value of api_key]"
    assert result["short_token"] == "abc"
    assert result["list"][0]["note"] == "[redacted AWS access key]"


@pytest.mark.parametrize(
    ("text", "expected"),
    [
        ("see src/app.py:42 for it", "src/app.py:42"),
        ("[x](a.md#L12)", "#L12"),
        ("on lines 3-5", "lines 3-5"),
        ("`src/app.py:42` only in code", None),
        ("x" * 2500 + " a.py:1", None),
    ],
)
def test_given_text_when_scanned_then_line_reference_found(
    text: str, expected: str | None
) -> None:
    # Act
    result = line_number_reference(text)

    # Assert
    assert result == expected


def test_given_small_helpers_when_called_then_formatting_matches() -> None:
    # Assert
    assert plural(1, "task") == "1 task"
    assert plural(2, "entry", "entries") == "2 entries"
    assert capped(["a", "b", "c"], 2) == "a, b and 1 more"
    assert dash(None) == "-"
    assert md_escape("a|b\nc") == "a\\|b c"
    assert short("x" * 100, 10) == "x" * 9 + "…"
    assert real_bullets("* None\n* {{x}}\n- real\ntext") == ["real"]


def test_given_unreadable_path_when_read_then_empty(tmp_path: Path) -> None:
    # Act
    result, _ = read_text_checked(tmp_path / "missing.md")

    # Assert
    assert result == ""


def test_given_crlf_file_when_read_then_newlines_normalized(tmp_path: Path) -> None:
    # Arrange
    path = tmp_path / "a.md"
    path.write_bytes(b"\xef\xbb\xbfa\r\nb\rc")

    # Act
    result, _ = read_text_checked(path)

    # Assert
    assert result == "a\nb\nc"


@pytest.mark.parametrize(
    "value",
    [
        "Not conformant",
        "Non conformant",
        "not yet Conformant",
        "was never Conformant",
        "isn't Conformant",
        "cannot be called Conformant",
    ],
)
def test_given_negated_value_when_vocab_matched_then_none(value: str) -> None:
    # Act
    result = vocab_match(value, OUTCOMES)

    # Assert
    assert result is None


@pytest.mark.parametrize(
    ("value", "expected"),
    [
        ("Not ready", "Not ready"),
        ("Not accepted", "Not accepted"),
        ("Partial (not Complete)", "Partial"),
        ("Conformant; nothing is pending", "Conformant"),
    ],
)
def test_given_entry_before_a_negation_when_vocab_matched_then_entry(
    value: str, expected: str
) -> None:
    # Act
    result = vocab_match(value, (*PLAN_READINESS, *OUTCOMES, "Partial", "Complete"))

    # Assert
    assert result == expected


def test_given_nested_and_mixed_fences_when_parsed_then_only_real_headings() -> None:
    # Arrange
    text = "\n".join(
        [
            "## Real",
            "````markdown",
            "```markdown",
            "#### [ ] P01-T01: Example only",
            "```",
            "````",
            "```text",
            "~~~~~~~~ build log ~~~~~~~~",
            "## Not a heading",
            "```",
            "## Also real",
        ]
    )

    # Act
    doc = Doc(text)

    # Assert
    assert [title for _, title, _ in doc.headings] == ["Real", "Also real"]


def test_given_heading_in_multi_line_comment_when_parsed_then_not_a_heading() -> None:
    # Arrange
    text = "## Real\n<!--\n### [x] P02: Retired\n-->\n## After"

    # Act
    doc = Doc(text)

    # Assert
    assert [title for _, title, _ in doc.headings] == ["Real", "After"]


def test_given_marker_beside_other_text_when_parsed_then_it_is_a_loose_marker() -> None:
    # Arrange
    text = "\n".join(
        [
            "<!-- rpi:task id=P01-T01 -->",
            "note <!-- rpi:task id=P01-T02 -->",
            "<!-- rpi:task id = P01-T03 -->",
        ]
    )

    # Act
    doc = Doc(text)

    # Assert
    assert [mid for _, mid, _ in doc.markers] == ["P01-T01"]
    assert [mid for _, mid, _ in doc.loose_markers] == ["P01-T02", "P01-T03"]


def test_given_escaped_pipe_in_a_cell_when_rows_read_then_cell_keeps_the_pipe() -> None:
    # Arrange
    text = "| Command | Result |\n|---|---|\n| `grep a \\| wc -l` | Failed |"

    # Act
    rows = table_rows(text)

    # Assert
    assert rows == [["`grep a | wc -l`", "Failed"]]


@pytest.mark.parametrize(
    ("value", "expected"),
    [
        ("A \\| B", "A \\\\\\| B"),
        ("a\r## Injected", "a ## Injected"),
        ("x \x1b[2J y", "x   y"),
        ("<img src=x onerror=alert(1)>", "\\<img src=x onerror=alert(1)>"),
        (
            "no `<!-- rpi:task id=P01-T01 -->` marker",
            "no `<!-- rpi:task id=P01-T01 -->` marker",
        ),
        ("3 < 4", "3 < 4"),
    ],
)
def test_given_untrusted_text_when_escaped_for_a_cell_then_it_cannot_leave_the_cell(
    value: str, expected: str
) -> None:
    # Act
    result = md_escape(value)

    # Assert
    assert result == expected


def test_given_private_key_without_end_when_redacted_then_material_is_gone() -> None:
    # Arrange
    text = (
        "deploy key: -----BEGIN RSA PRIVATE KEY----- "
        "MIIEowIBAAKCAQEAx3vQmZ8sJ0kL2pN\nnext line"
    )

    # Act
    result = redact(text)

    # Assert
    assert result == "deploy key: [redacted private key block]\nnext line"


def test_given_private_key_block_when_redacted_then_line_count_is_kept() -> None:
    # Arrange
    text = (
        "a\n-----BEGIN PRIVATE KEY-----\nMIIEowIBAAKCAQEAx3vQmZ8s\n-----END PRIVATE "
        "KEY-----\nb"
    )

    # Act
    result = redact(text)

    # Assert
    assert result == "a\n[redacted private key block]\n\n\nb"


def test_given_unclosed_comment_when_stripped_then_the_rest_is_hidden() -> None:
    # Act
    result = strip_fences_and_comments("a <!-- closed --> b <!-- open\nc")

    # Assert
    # an unclosed HTML comment hides the rest of the file, as it does when rendered
    assert result == "a   b "


def test_given_deeply_nested_value_when_redacted_then_no_recursion_error() -> None:
    # Arrange
    value: list = []
    for _ in range(5000):
        value = [value]

    # Act
    depth = nesting_depth(value)
    result = redact_obj({"blockers": value})

    # Assert
    assert depth == 65
    assert "[nested too deeply to report]" in str(result)


def test_given_report_keys_when_redacted_without_key_rule_then_values_are_kept() -> (
    None
):
    # Arrange
    obj = {"Token budget": "about 12000 tokens for the rerun"}

    # Act
    result = redact_obj(obj, by_key=False)

    # Assert
    assert result == obj
