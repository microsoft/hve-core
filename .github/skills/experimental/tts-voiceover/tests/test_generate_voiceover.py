# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Tests for generate_voiceover module."""

from pathlib import Path

import yaml
from generate_voiceover import (
    _resolve_lexicon,
    create_parser,
)


class TestResolveLexicon:
    """Tests for _resolve_lexicon."""

    def test_given_explicit_arg_when_resolved_then_returns_arg(self, tmp_path):
        # Arrange
        explicit = tmp_path / "custom.yaml"

        # Act
        result = _resolve_lexicon(explicit, tmp_path)

        # Assert
        assert result == explicit

    def test_given_content_dir_lexicon_when_resolved_then_returns_it(self, tmp_path):
        # Arrange
        lexicon = tmp_path / "acronyms.yaml"
        lexicon.write_text("acronyms:\n  FOO: bar\n", encoding="utf-8")

        # Act
        result = _resolve_lexicon(None, tmp_path)

        # Assert
        assert result == lexicon

    def test_given_no_lexicon_and_no_content_file_when_resolved_then_returns_default(
        self,
    ):
        # Act
        result = _resolve_lexicon(None, Path("/nonexistent"))

        # Assert
        assert result == Path("acronyms.yaml")


class TestCreateParser:
    """Tests for create_parser."""

    def test_given_defaults_when_parsed_then_has_expected_values(self):
        # Act
        parser = create_parser()
        args = parser.parse_args(["--content-dir", "c", "--output-dir", "o"])

        # Assert
        assert str(args.content_dir) == "c"
        assert str(args.output_dir) == "o"
        assert args.dry_run is False
        assert args.voice is not None
        assert args.rate is not None

    def test_given_dry_run_flag_when_parsed_then_dry_run_true(self):
        # Act
        parser = create_parser()
        args = parser.parse_args(
            ["--content-dir", "c", "--output-dir", "o", "--dry-run"]
        )

        # Assert
        assert args.dry_run is True

    def test_given_custom_voice_when_parsed_then_voice_set(self):
        # Act
        parser = create_parser()
        args = parser.parse_args(
            [
                "--content-dir",
                "c",
                "--output-dir",
                "o",
                "--voice",
                "en-US-Jenny",
            ]
        )

        # Assert
        assert args.voice == "en-US-Jenny"


class TestRunDryRun:
    """Tests for _run in dry-run mode."""

    def test_given_valid_content_when_dry_run_then_returns_success(self, tmp_path):
        from generate_voiceover import _run

        # Arrange
        content = tmp_path / "content"
        slide = content / "slide-001"
        slide.mkdir(parents=True)
        (slide / "content.yaml").write_text(
            yaml.dump(
                {
                    "slide": 1,
                    "title": "Test",
                    "speaker_notes": "Hello world",
                }
            ),
            encoding="utf-8",
        )
        output = tmp_path / "output"
        parser = create_parser()
        args = parser.parse_args(
            [
                "--content-dir",
                str(content),
                "--output-dir",
                str(output),
                "--dry-run",
            ]
        )

        # Act
        rc = _run(args)

        # Assert
        assert rc == 0

    def test_given_missing_content_dir_when_run_then_returns_failure(self, tmp_path):
        from generate_voiceover import _run

        # Arrange
        parser = create_parser()
        args = parser.parse_args(
            [
                "--content-dir",
                str(tmp_path / "missing"),
                "--output-dir",
                str(tmp_path / "out"),
                "--dry-run",
            ]
        )

        # Act
        rc = _run(args)

        # Assert
        assert rc == 1

    def test_given_empty_notes_when_dry_run_then_slide_skipped(self, tmp_path, capsys):
        from generate_voiceover import _run

        # Arrange
        content = tmp_path / "content"
        slide = content / "slide-001"
        slide.mkdir(parents=True)
        (slide / "content.yaml").write_text(
            yaml.dump({"slide": 1, "title": "Empty", "speaker_notes": ""}),
            encoding="utf-8",
        )
        output = tmp_path / "output"
        parser = create_parser()
        args = parser.parse_args(
            [
                "--content-dir",
                str(content),
                "--output-dir",
                str(output),
                "--dry-run",
            ]
        )

        # Act
        rc = _run(args)

        # Assert
        assert rc == 0
