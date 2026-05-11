# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Tests for generate_voiceover module."""

from pathlib import Path

import yaml
from generate_voiceover import (
    _resolve_lexicon,
    apply_acronym_aliases,
    create_parser,
    wrap_ssml,
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


class TestApplyAcronymAliases:
    """Tests for apply_acronym_aliases."""

    def test_given_known_acronym_when_applied_then_wraps_in_sub(self):
        # Arrange
        text = "Use OWASP guidelines"
        acronyms = {"OWASP": "Oh wasp"}

        # Act
        result = apply_acronym_aliases(text, acronyms)

        # Assert
        assert '<sub alias="Oh wasp">OWASP</sub>' in result

    def test_given_empty_acronyms_when_applied_then_returns_unchanged(self):
        # Arrange
        text = "no replacements here"

        # Act
        result = apply_acronym_aliases(text, {})

        # Assert
        assert result == text

    def test_given_escaped_input_when_applied_then_no_double_escape(self):
        # Arrange
        text = "&amp; &lt;tag&gt;"

        # Act
        result = apply_acronym_aliases(text, {})

        # Assert
        assert result == text

    def test_given_multiple_acronyms_when_applied_then_all_replaced(self):
        # Arrange
        text = "Use API and SDK"
        acronyms = {"API": "A P I", "SDK": "S D K"}

        # Act
        result = apply_acronym_aliases(text, acronyms)

        # Assert
        assert '<sub alias="A P I">API</sub>' in result
        assert '<sub alias="S D K">SDK</sub>' in result


class TestWrapSsml:
    """Tests for wrap_ssml."""

    def test_given_text_when_wrapped_then_contains_speak_element(self):
        # Arrange
        text = "Hello world"

        # Act
        result = wrap_ssml(text, voice="en-US-AriaNeural", rate="0%")

        # Assert
        assert "<speak" in result
        assert "</speak>" in result

    def test_given_voice_when_wrapped_then_voice_attribute_present(self):
        # Arrange
        voice = "en-US-AriaNeural"

        # Act
        result = wrap_ssml("test", voice=voice, rate="0%")

        # Assert
        assert voice in result

    def test_given_rate_when_wrapped_then_prosody_rate_set(self):
        # Arrange
        rate = "-10%"

        # Act
        result = wrap_ssml("test", voice="en-US-AriaNeural", rate=rate)

        # Assert
        assert rate in result

    def test_given_ssml_output_when_parsed_then_valid_xml(self):
        # Arrange
        import xml.etree.ElementTree as ET

        text = "Hello &amp; world"

        # Act
        result = wrap_ssml(text, voice="en-US-AriaNeural", rate="0%")

        # Assert
        ET.fromstring(result)
