# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Tests for generate_voiceover module."""

import shlex
import sys
from pathlib import Path

import yaml
from generate_voiceover import (
    _resolve_lexicon,
    apply_acronym_aliases,
    apply_plain_aliases,
    create_parser,
    generate_audio_piper,
    wrap_ssml,
)

_FAKE_PIPER = """
import sys, wave
args = sys.argv[1:]
text = sys.stdin.read()
if "FAIL" in text:
    sys.stderr.write("boom")
    sys.exit(3)
out = args[args.index("--output-file") + 1]
with wave.open(out, "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(22050)
    w.writeframes(b"\\x00\\x00" * 22050)
"""


def _fake_piper(tmp_path: Path) -> list[str]:
    script = tmp_path / "fake_piper.py"
    script.write_text(_FAKE_PIPER, encoding="utf-8")
    return [sys.executable, str(script)]


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
        assert args.engine == "azure"
        assert args.voice is None
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


class TestCollapseNewlines:
    """Tests for the --collapse-newlines option."""

    def _run_dry(self, tmp_path, notes, extra_args):
        from generate_voiceover import _run

        content = tmp_path / "content"
        slide = content / "slide-001"
        slide.mkdir(parents=True)
        (slide / "content.yaml").write_text(
            yaml.dump({"slide": 1, "title": "Multi", "speaker_notes": notes}),
            encoding="utf-8",
        )
        parser = create_parser()
        args = parser.parse_args(
            [
                "--content-dir",
                str(content),
                "--output-dir",
                str(tmp_path / "output"),
                "--dry-run",
                *extra_args,
            ]
        )
        return _run(args)

    def test_given_multiline_notes_when_collapse_then_no_newlines_in_ssml(
        self, tmp_path, capsys
    ):
        # Arrange
        notes = "First line.\nSecond line.\nThird line."

        # Act
        rc = self._run_dry(tmp_path, notes, ["--collapse-newlines"])
        out = capsys.readouterr().out

        # Assert
        assert rc == 0
        assert "First line. Second line. Third line." in out

    def test_given_multiline_notes_when_not_collapsed_then_newlines_preserved(
        self, tmp_path, capsys
    ):
        # Arrange
        notes = "First line.\nSecond line."

        # Act
        rc = self._run_dry(tmp_path, notes, [])
        out = capsys.readouterr().out

        # Assert
        assert rc == 0
        assert "First line.\nSecond line." in out


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


class TestApplyPlainAliases:
    """Tests for apply_plain_aliases."""

    def test_given_spaced_letter_alias_when_applied_then_hyphenated(self):
        # Act
        result = apply_plain_aliases("Welcome to HVE Core", {"HVE": "H V E"})

        # Assert
        assert result == "Welcome to H-V-E Core"

    def test_given_mixed_alias_when_applied_then_only_letter_run_hyphenated(self):
        # Act
        result = apply_plain_aliases("HVE-Core", {"HVE-Core": "H V E Core"})

        # Assert
        assert result == "H-V-E Core"

    def test_given_word_alias_when_applied_then_unchanged_alias(self):
        # Act
        result = apply_plain_aliases(
            "OWASP and SBOM", {"OWASP": "Oh wasp", "SBOM": "S Bomb"}
        )

        # Assert
        assert result == "Oh wasp and S Bomb"

    def test_given_overlapping_keys_when_applied_then_longest_wins(self):
        # Act
        result = apply_plain_aliases(
            "HVE-Core and HVE", {"HVE": "H V E", "HVE-Core": "H V E Core"}
        )

        # Assert
        assert result == "H-V-E Core and H-V-E"

    def test_given_markup_characters_when_applied_then_not_escaped(self):
        # Act
        result = apply_plain_aliases("A & B <c>", {"RPI": "R P I"})

        # Assert
        assert result == "A & B <c>"


class TestGenerateAudioPiper:
    """Tests for generate_audio_piper."""

    def test_given_working_command_when_generated_then_returns_duration(self, tmp_path):
        # Arrange
        out = tmp_path / "slide-001.wav"

        # Act
        duration = generate_audio_piper(
            "Hello", out, _fake_piper(tmp_path), "voice", None
        )

        # Assert
        assert duration == 1.0
        assert out.is_file()

    def test_given_failing_command_when_generated_then_returns_none(self, tmp_path):
        # Act
        duration = generate_audio_piper(
            "FAIL", tmp_path / "x.wav", _fake_piper(tmp_path), "voice", None
        )

        # Assert
        assert duration is None

    def test_given_missing_executable_when_generated_then_returns_none(self, tmp_path):
        # Act
        duration = generate_audio_piper(
            "Hello", tmp_path / "x.wav", [str(tmp_path / "nope")], "voice", None
        )

        # Assert
        assert duration is None


class TestRunPiper:
    """Tests for _run with the piper engine."""

    def _args(self, tmp_path, notes, extra_args):
        content = tmp_path / "content"
        slide = content / "slide-001"
        slide.mkdir(parents=True)
        (slide / "content.yaml").write_text(
            yaml.dump({"slide": 1, "title": "T", "speaker_notes": notes}),
            encoding="utf-8",
        )
        return create_parser().parse_args(
            [
                "--engine",
                "piper",
                "--content-dir",
                str(content),
                "--output-dir",
                str(tmp_path / "output"),
                *extra_args,
            ]
        )

    def test_given_dry_run_when_piper_then_prints_plain_text(self, tmp_path, capsys):
        from generate_voiceover import _run

        # Act
        rc = _run(self._args(tmp_path, "Meet HVE Core & friends", ["--dry-run"]))
        out = capsys.readouterr().out

        # Assert
        assert rc == 0
        assert "Meet H-V-E Core & friends" in out
        assert "<speak" not in out

    def test_given_missing_piper_when_run_then_returns_error(
        self, tmp_path, monkeypatch
    ):
        from generate_voiceover import _run

        # Arrange
        monkeypatch.setenv("PIPER_COMMAND", str(tmp_path / "missing-piper"))

        # Act
        rc = _run(self._args(tmp_path, "Hello", []))

        # Assert
        assert rc == 2

    def test_given_piper_command_when_run_then_writes_wav(self, tmp_path, monkeypatch):
        from generate_voiceover import _run

        # Arrange
        monkeypatch.setenv("PIPER_COMMAND", shlex.join(_fake_piper(tmp_path)))
        monkeypatch.delenv("SPEECH_KEY", raising=False)
        monkeypatch.delenv("SPEECH_RESOURCE_ID", raising=False)

        # Act
        rc = _run(self._args(tmp_path, "Hello", []))

        # Assert
        assert rc == 0
        assert (tmp_path / "output" / "slide-001.wav").is_file()


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
