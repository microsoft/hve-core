# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Tests for `scripts.render_template`.

Covers happy-path substitution, path-traversal rejection, and missing-field
placeholder handling. The script populates an ADR template with field values
written from the agent state and writes the rendered file under the project's
ADR directory.
"""

from __future__ import annotations

from pathlib import Path

import pytest

render_template = pytest.importorskip("scripts.render_template")


def _invoke(args: list[str], capsys: pytest.CaptureFixture[str]) -> int:
    """Invoke `render_template.main` with argv and return the exit code."""
    try:
        return int(render_template.main(args) or 0)
    except SystemExit as exc:
        return int(exc.code or 0)


class TestRenderTemplateHappyPath:
    def test_given_valid_substitutions_when_render_then_writes_expected_output(
        self,
        tmp_skill_root: Path,
        sample_madr_template: str,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange
        template_path = tmp_skill_root / "templates" / "adr-template.md"
        template_path.write_text(sample_madr_template, encoding="utf-8")
        output_path = tmp_skill_root / "docs" / "project" / "demo" / "adr" / "0001-pick-database.md"

        # Act
        exit_code = _invoke(
            [
                "--template",
                str(template_path),
                "--output",
                str(output_path),
                "--field",
                "title=Pick Database",
                "--field",
                "status=proposed",
                "--field",
                "date=2026-05-03",
                "--field",
                "deciders=alice, bob",
                "--field",
                "consulted=carol",
                "--field",
                "informed=dave",
                "--field",
                "context=We need a primary store.",
                "--field",
                "driver=Latency",
                "--field",
                "option=Postgres",
                "--field",
                "chosen_option=Postgres",
                "--field",
                "justification=mature ecosystem",
                "--field",
                "good_consequence=ACID guarantees",
                "--field",
                "bad_consequence=operational overhead",
                "--field",
                "pro=well-supported",
                "--field",
                "con=requires tuning",
                "--field",
                "more_information=See ADR-0002.",
            ],
            capsys,
        )

        # Assert
        assert exit_code == 0, capsys.readouterr().err
        assert output_path.is_file()
        rendered = output_path.read_text(encoding="utf-8")
        assert "Pick Database" in rendered
        assert "Postgres" in rendered


class TestRenderTemplatePathTraversal:
    @pytest.mark.parametrize(
        "adversarial",
        [
            "../../../etc/passwd",
            "..\\..\\..\\Windows\\System32\\drivers\\etc\\hosts",
            "/etc/shadow",
        ],
    )
    def test_given_traversal_path_when_render_then_exits_non_zero(
        self,
        tmp_skill_root: Path,
        sample_madr_template: str,
        adversarial: str,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange
        template_path = tmp_skill_root / "templates" / "adr-template.md"
        template_path.write_text(sample_madr_template, encoding="utf-8")

        # Act
        exit_code = _invoke(
            [
                "--template",
                str(template_path),
                "--output",
                adversarial,
                "--field",
                "title=Adversarial",
            ],
            capsys,
        )

        # Assert
        assert exit_code != 0
        captured = capsys.readouterr()
        assert "path" in (captured.err + captured.out).lower()


class TestRenderTemplateMissingField:
    def test_given_missing_field_when_render_then_leaves_placeholder_or_errors(
        self,
        tmp_skill_root: Path,
        sample_madr_template: str,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange — supply only `title`; other placeholders unfilled.
        template_path = tmp_skill_root / "templates" / "adr-template.md"
        template_path.write_text(sample_madr_template, encoding="utf-8")
        output_path = tmp_skill_root / "docs" / "project" / "demo" / "adr" / "0002-partial.md"

        # Act
        exit_code = _invoke(
            [
                "--template",
                str(template_path),
                "--output",
                str(output_path),
                "--field",
                "title=Partial Render",
            ],
            capsys,
        )

        # Assert documented behavior: either the script preserves unsubstituted
        # placeholders (exit 0) or it errors out non-zero. Both are acceptable so
        # long as the behavior is deterministic and the missing field is visible.
        captured = capsys.readouterr()
        if exit_code == 0:
            rendered = output_path.read_text(encoding="utf-8")
            assert "Partial Render" in rendered
            assert "{context}" in rendered or "context" in rendered.lower()
        else:
            assert "context" in (captured.err + captured.out).lower()
