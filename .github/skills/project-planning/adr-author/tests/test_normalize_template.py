# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Tests for `scripts.normalize_template`.

Covers BYO template normalization rules from `adr-byo-template.instructions.md`:

* Happy-path normalization preserves required canonical anchors.
* GP-05 anchor enforcement HARD-FAILS when required anchors are missing and
  emits a structured report listing every missing anchor.
* Path-traversal inputs and outputs are rejected.
"""

from __future__ import annotations

from pathlib import Path

import pytest

normalize_template = pytest.importorskip("scripts.normalize_template")


_REQUIRED_ANCHORS = (
    "title",
    "context-and-problem-statement",
    "decision-drivers",
    "considered-options",
    "decision-outcome",
    "consequences",
    "more-information",
)

_VALID_BYO = """\
# {{title}}

## Context and Problem Statement
{{context}}

## Decision Drivers
{{driver}}

## Considered Options
{{option}}

## Decision Outcome
{{chosen_option}} — {{justification}}

## Consequences
* Good: {{good_consequence}}
* Bad: {{bad_consequence}}

## More Information
{{more_information}}
"""


def _invoke(args: list[str], capsys: pytest.CaptureFixture[str]) -> int:
    try:
        return int(normalize_template.main(args) or 0)
    except SystemExit as exc:
        return int(exc.code or 0)


class TestNormalizeTemplateHappyPath:
    def test_given_template_with_all_anchors_when_normalize_then_writes_output(
        self,
        tmp_skill_root: Path,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange
        input_path = tmp_skill_root / "templates" / "byo.md"
        output_path = tmp_skill_root / "templates" / "byo.normalized.md"
        input_path.write_text(_VALID_BYO, encoding="utf-8")

        # Act
        exit_code = _invoke(
            ["--input", str(input_path), "--output", str(output_path)],
            capsys,
        )

        # Assert
        assert exit_code == 0, capsys.readouterr().err
        assert output_path.is_file()
        normalized = output_path.read_text(encoding="utf-8")
        for anchor_text in (
            "Context and Problem Statement",
            "Decision Drivers",
            "Considered Options",
            "Decision Outcome",
            "Consequences",
            "More Information",
        ):
            assert anchor_text in normalized


class TestNormalizeTemplateAnchorEnforcement:
    def test_given_missing_single_anchor_when_normalize_then_hard_fails_with_report(
        self,
        tmp_skill_root: Path,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange — drop the `title` anchor.
        broken = _VALID_BYO.replace("# {{title}}\n", "")
        input_path = tmp_skill_root / "templates" / "byo-missing-title.md"
        output_path = tmp_skill_root / "templates" / "byo-missing-title.normalized.md"
        input_path.write_text(broken, encoding="utf-8")

        # Act
        exit_code = _invoke(
            ["--input", str(input_path), "--output", str(output_path)],
            capsys,
        )

        # Assert — non-zero exit, structured report mentions missing anchor.
        assert exit_code != 0
        captured = capsys.readouterr()
        report = captured.err + captured.out
        assert "title" in report.lower()
        assert not output_path.exists()

    def test_given_multiple_missing_anchors_when_normalize_then_lists_all(
        self,
        tmp_skill_root: Path,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange — strip everything but the title heading.
        input_path = tmp_skill_root / "templates" / "byo-bare.md"
        output_path = tmp_skill_root / "templates" / "byo-bare.normalized.md"
        input_path.write_text("# {{title}}\n", encoding="utf-8")

        # Act
        exit_code = _invoke(
            ["--input", str(input_path), "--output", str(output_path)],
            capsys,
        )

        # Assert
        assert exit_code != 0
        captured = capsys.readouterr()
        report = (captured.err + captured.out).lower()
        for anchor in _REQUIRED_ANCHORS[1:]:
            assert anchor in report or anchor.replace("-", " ") in report


class TestNormalizeTemplatePathTraversal:
    @pytest.mark.parametrize(
        "adversarial",
        [
            "../../../etc/passwd",
            "..\\..\\..\\Windows\\System32\\drivers\\etc\\hosts",
        ],
    )
    def test_given_traversal_input_when_normalize_then_rejected(
        self,
        tmp_skill_root: Path,
        adversarial: str,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange
        output_path = tmp_skill_root / "templates" / "ignored.normalized.md"

        # Act
        exit_code = _invoke(
            ["--input", adversarial, "--output", str(output_path)],
            capsys,
        )

        # Assert
        assert exit_code != 0
        assert not output_path.exists()

    @pytest.mark.parametrize(
        "adversarial",
        [
            "../../../etc/normalized.md",
            "..\\..\\..\\evil.md",
        ],
    )
    def test_given_traversal_output_when_normalize_then_rejected(
        self,
        tmp_skill_root: Path,
        adversarial: str,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange
        input_path = tmp_skill_root / "templates" / "byo.md"
        input_path.write_text(_VALID_BYO, encoding="utf-8")

        # Act
        exit_code = _invoke(
            ["--input", str(input_path), "--output", adversarial],
            capsys,
        )

        # Assert
        assert exit_code != 0
