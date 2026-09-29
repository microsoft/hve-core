# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Tests for render_checks module."""

import json
import subprocess
import wave
import zipfile
from pathlib import Path

import pytest
from render_checks import (
    LEVELS,
    STYLE_TEMPLATE,
    CheckError,
    build_captions,
    build_segments,
    build_transcript_page,
    changed_levels,
    check_accessibility,
    check_captures,
    check_duration,
    check_style,
    deck_accessibility_problems,
    evaluate,
    level_touched,
    load_curriculum,
    main,
    measure_minutes,
    normalized_text,
    on_screen_text,
    parse_curriculum,
    parse_webvtt,
    style_metadata,
    subtitle_languages,
)

_MINI_CURRICULUM = """# Curriculum

## Level Contracts

| Level | Audience | Target duration  | Capture fidelity |
|-------|----------|------------------|------------------|
| L100  | New      | 4 to 6 minutes   | deck             |
| L200  | Guided   | 6 to 8 minutes   | deck             |
| L300  | Applied  | 8 to 10 minutes  | live             |
| L400  | Extend   | 10 to 12 minutes | live             |

## Narration Budget

| Level | Duration contract | Target narration words |
|-------|-------------------|------------------------|
| L100  | 99 to 100 minutes | ignored                |

### Pinned Sources for `hve-core-general`

| Level | Purpose | Required local sources          |
|-------|---------|---------------------------------|
| L100  | Intro   | `docs/a.md`; `docs/b.md`        |
| L200  | Guided  | `docs/c.md`                     |
| L300  | Applied | `docs/d.md`                     |
| L400  | Extend  | `docs/e.md`; `docs/f.md`        |

## Atomic Acceptance Criterion Templates

| Level | ID      | Template |
|-------|---------|----------|
| L100  | L100-01 | `docs/not-a-source.md` |
"""


def _write_wav(path: Path, seconds: float) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(8000)
        wav.writeframes(b"\x00\x00" * int(8000 * seconds))


def _write_slides(level_dir: Path, count: int, notes: str = "one two three") -> None:
    for number in range(1, count + 1):
        slide = level_dir / "content" / f"slide-{number:03d}"
        slide.mkdir(parents=True)
        (slide / "content.yaml").write_text(
            f"slide: {number}\ntitle: Slide title {number}\nspeaker_notes: {notes}\n",
            encoding="utf-8",
        )
        frame = level_dir / "frames" / "deck" / f"slide-{number:03d}.jpg"
        frame.parent.mkdir(parents=True, exist_ok=True)
        frame.write_bytes(b"jpg")
        _write_wav(level_dir / "audio" / f"slide-{number:03d}.wav", 2.0)


_P = "http://schemas.openxmlformats.org/presentationml/2006/main"
_A = "http://schemas.openxmlformats.org/drawingml/2006/main"


def _write_deck(
    path: Path,
    slides: int,
    language: str | None = "en-US",
    titled: bool = True,
    picture_descr: str | None = None,
) -> None:
    """Write the minimal PPTX parts that deck_accessibility_problems reads."""
    lang = f"<dc:language>{language}</dc:language>" if language else ""
    core = (
        '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/'
        '2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/">'
        f"{lang}</cp:coreProperties>"
    )
    ph = '<p:ph type="title"/>' if titled else ""
    title = (
        f'<p:sp><p:nvSpPr><p:cNvPr id="2" name="T"/><p:cNvSpPr/><p:nvPr>{ph}'
        "</p:nvPr></p:nvSpPr><p:txBody><a:p><a:r><a:t>Title</a:t></a:r></a:p>"
        "</p:txBody></p:sp>"
    )
    pic = (
        f'<p:pic><p:nvPicPr><p:cNvPr id="3" name="Picture" descr="{picture_descr}"/>'
        "</p:nvPicPr></p:pic>"
        if picture_descr is not None
        else ""
    )
    with zipfile.ZipFile(path, "w") as archive:
        archive.writestr("docProps/core.xml", core)
        for number in range(1, slides + 1):
            archive.writestr(
                f"ppt/slides/slide{number}.xml",
                f'<p:sld xmlns:p="{_P}" xmlns:a="{_A}"><p:cSld><p:spTree>'
                f"{title}{pic}</p:spTree></p:cSld></p:sld>",
            )


def _git(repo: Path, *args: str) -> str:
    return subprocess.run(
        ["git", "-C", str(repo), *args],
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()


class TestParseCurriculum:
    """Tests for parse_curriculum."""

    def test_given_mini_curriculum_when_parsed_then_reads_scoped_tables(self):
        # Act
        levels = parse_curriculum(_MINI_CURRICULUM)

        # Assert
        assert levels["L100"] == {
            "min": 4.0,
            "max": 6.0,
            "sources": ["docs/a.md", "docs/b.md"],
        }
        assert levels["L400"]["max"] == 12.0

    def test_given_missing_sources_when_parsed_then_raises(self):
        # Arrange
        text = _MINI_CURRICULUM.replace(
            "| L200  | Guided  | `docs/c.md`", "| L200  | Guided  | none"
        )

        # Act / Assert
        with pytest.raises(CheckError, match="L200"):
            parse_curriculum(text)

    def test_given_repository_curriculum_when_loaded_then_all_levels_present(self):
        # Act
        levels = load_curriculum()

        # Assert
        assert set(levels) == {"L100", "L200", "L300", "L400"}
        assert "docs/README.md" in levels["L100"]["sources"]
        assert levels["L300"]["min"] == 8.0


class TestLevelTouched:
    """Tests for level_touched."""

    def test_given_source_change_when_checked_then_true(self):
        assert level_touched(["docs/a.md"], ["docs/a.md"])

    def test_given_shared_skill_change_when_checked_then_true(self):
        path = ".github/skills/experimental/hve-demo-material/SKILL.md"
        assert level_touched([path], ["docs/a.md"])

    def test_given_unrelated_change_when_checked_then_false(self):
        assert not level_touched(["docs/a.md.bak", "README.md"], ["docs/a.md"])


class TestChangedLevels:
    """Tests for changed_levels."""

    @pytest.fixture
    def repo(self, tmp_path):
        _git(tmp_path, "init", "-q")
        _git(tmp_path, "config", "user.email", "t@example.com")
        _git(tmp_path, "config", "user.name", "t")
        (tmp_path / "docs").mkdir()
        for name in "abcdef":
            (tmp_path / "docs" / f"{name}.md").write_text(name, encoding="utf-8")
        _git(tmp_path, "add", ".")
        _git(tmp_path, "commit", "-q", "-m", "base")
        return tmp_path

    def test_given_empty_index_when_checked_then_all_levels(self, repo):
        # Act
        result = changed_levels(parse_curriculum(_MINI_CURRICULUM), {}, repo)

        # Assert
        assert result == ["L100", "L200", "L300", "L400"]

    def test_given_one_source_changed_when_checked_then_only_that_level(self, repo):
        # Arrange
        base = _git(repo, "rev-parse", "HEAD")
        (repo / "docs" / "d.md").write_text("changed", encoding="utf-8")
        _git(repo, "commit", "-q", "-am", "change")
        index = {"levels": {level: {"source_sha": base} for level in LEVELS}}

        # Act
        result = changed_levels(parse_curriculum(_MINI_CURRICULUM), index, repo)

        # Assert
        assert result == ["L300"]

    def test_given_unknown_sha_when_checked_then_level_selected(self, repo):
        # Arrange
        head = _git(repo, "rev-parse", "HEAD")
        index = {"levels": {level: {"source_sha": head} for level in LEVELS}}
        index["levels"]["L200"]["source_sha"] = "0" * 40

        # Act
        result = changed_levels(parse_curriculum(_MINI_CURRICULUM), index, repo)

        # Assert
        assert result == ["L200"]

    def test_given_force_when_checked_then_all_levels(self, repo):
        # Arrange
        head = _git(repo, "rev-parse", "HEAD")
        index = {"levels": {level: {"source_sha": head} for level in LEVELS}}

        # Act
        result = changed_levels(
            parse_curriculum(_MINI_CURRICULUM), index, repo, force=True
        )

        # Assert
        assert len(result) == 4


class TestBuildSegments:
    """Tests for build_segments."""

    def test_given_frames_and_audio_when_built_then_pairs_relative_paths(
        self, tmp_path
    ):
        # Arrange
        _write_slides(tmp_path, 2)

        # Act
        text = build_segments(tmp_path, "hve-demo-L100.mp4")

        # Assert
        assert "output: ./hve-demo-L100.mp4" in text
        assert "visual: ../frames/deck/slide-002.jpg" in text
        assert "narration: ../audio/slide-001.wav" in text

    def test_given_missing_audio_when_built_then_raises(self, tmp_path):
        # Arrange
        _write_slides(tmp_path, 2)
        (tmp_path / "audio" / "slide-002.wav").unlink()

        # Act / Assert
        with pytest.raises(CheckError, match="slide-002.wav"):
            build_segments(tmp_path, "x.mp4")


class TestCheckStyle:
    """Tests for check_style (T-08)."""

    def test_given_template_with_substitutions_when_checked_then_pass(self):
        # Arrange
        template = STYLE_TEMPLATE.read_text(encoding="utf-8")
        style = template.replace(
            '"<deck title for this level and topic>"', '"HVE Core L100"'
        ).replace("[<every slide number in this deck>]", "[1, 2, 3]")

        # Act
        result = check_style(style, template)

        # Assert
        assert result["result"] == "pass"

    def test_given_changed_fixed_field_when_checked_then_fail(self):
        # Arrange
        template = STYLE_TEMPLATE.read_text(encoding="utf-8")
        style = template.replace(
            "corner_radius_inches: 0.06", "corner_radius_inches: 0.15"
        )

        # Act
        result = check_style(style, template)

        # Assert
        assert result["result"] == "fail"
        assert "fixed field" in result["evidence"]

    def test_given_colour_outside_palette_when_checked_then_fail(self):
        # Arrange
        template = STYLE_TEMPLATE.read_text(encoding="utf-8")
        style = template.replace('"#C9CDD6"', '"#9CA3AF"')

        # Act
        result = check_style(style, template)

        # Assert
        assert result["result"] == "fail"
        assert "#9CA3AF" in result["evidence"]


class TestCheckCaptures:
    """Tests for check_captures (T-05, T-06)."""

    def _capture(self, capture_id, pt=19.5, resolution="1920x1080"):
        return {
            "capture_id": capture_id,
            "path": f"content/slide-005/images/{capture_id}.png",
            "rendered_font_size_pt": pt,
            "source_resolution": resolution,
        }

    def test_given_two_readable_captures_when_checked_then_both_pass(self):
        # Act
        t05, t06 = check_captures(
            {"captures": [self._capture("a"), self._capture("b")]}
        )

        # Assert
        assert t05["result"] == "pass"
        assert t06["result"] == "pass"

    def test_given_small_font_when_checked_then_t06_fail(self):
        # Act
        _, t06 = check_captures(
            {"captures": [self._capture("a"), self._capture("b", pt=12.0)]}
        )

        # Assert
        assert t06["result"] == "fail"

    def test_given_one_capture_when_checked_then_t05_fail(self):
        # Act
        t05, _ = check_captures({"captures": [self._capture("a")]})

        # Assert
        assert t05["result"] == "fail"

    def test_given_no_result_when_checked_then_deferred(self):
        # Act
        t05, t06 = check_captures(None)

        # Assert
        assert t05["result"] == t06["result"] == "deferred"


class TestCheckDuration:
    """Tests for check_duration (T-07)."""

    @pytest.mark.parametrize(
        ("minutes", "expected"),
        [(4.0, "pass"), (5.2, "pass"), (6.0, "pass"), (3.9, "fail"), (6.1, "fail")],
    )
    def test_given_duration_when_checked_then_scored(self, minutes, expected):
        assert check_duration(minutes, {"min": 4.0, "max": 6.0})["result"] == expected

    def test_given_no_measurement_when_checked_then_deferred(self):
        assert check_duration(None, {"min": 4.0, "max": 6.0})["result"] == "deferred"


class TestEvaluate:
    """Tests for evaluate."""

    @pytest.fixture(autouse=True)
    def _english_subtitles(self, mocker):
        mocker.patch("render_checks.subtitle_languages", return_value=["eng"])

    @pytest.mark.parametrize("probe", [measure_minutes, subtitle_languages])
    def test_given_no_ffprobe_when_probed_then_none(self, tmp_path, mocker, probe):
        mp4 = tmp_path / "video.mp4"
        mp4.write_bytes(b"mp4")
        mocker.patch(
            "render_checks.subprocess.run", side_effect=FileNotFoundError("ffprobe")
        )
        assert probe(mp4) is None

    def _level(self, tmp_path, level="L100", mocker=None):
        _write_slides(tmp_path, 3)
        (tmp_path / "output").mkdir()
        (tmp_path / "output" / f"hve-demo-{level}.mp4").write_bytes(b"mp4")
        (tmp_path / "output" / "segments.yml").write_text(
            build_segments(tmp_path, f"hve-demo-{level}.mp4"), encoding="utf-8"
        )
        style = STYLE_TEMPLATE.read_text(encoding="utf-8").replace(
            "[<every slide number in this deck>]", "[1, 2, 3]"
        )
        (tmp_path / "content" / "global").mkdir()
        (tmp_path / "content" / "global" / "style.yaml").write_text(
            style, encoding="utf-8"
        )
        _write_deck(tmp_path / "output" / f"hve-demo-{level}.pptx", 3)
        (tmp_path / "output" / f"hve-demo-{level}.vtt").write_text(
            build_captions(tmp_path), encoding="utf-8"
        )
        (tmp_path / "output" / "index.html").write_text(
            build_transcript_page(level, tmp_path), encoding="utf-8"
        )
        return tmp_path

    def test_given_rendered_deck_level_when_evaluated_then_ok(self, tmp_path, mocker):
        # Arrange
        level_dir = self._level(tmp_path)
        mocker.patch("render_checks.measure_minutes", return_value=5.0)

        # Act
        result = evaluate("L100", level_dir, load_curriculum())

        # Assert
        assert result["ok"] is True, result["checks"]
        assert result["capture_profile"] == "deck-export"
        assert result["total_word_count"] == 9
        assert set(result["checks"]) == {"T-04", "T-07", "T-08", "T-09"}

    def test_given_live_level_without_captures_when_evaluated_then_not_ok(
        self, tmp_path, mocker
    ):
        # Arrange
        level_dir = self._level(tmp_path, "L300")
        mocker.patch("render_checks.measure_minutes", return_value=9.0)

        # Act
        result = evaluate("L300", level_dir, load_curriculum())

        # Assert
        assert result["ok"] is False
        assert result["capture_profile"] == "live"
        assert result["checks"]["T-05"]["result"] == "deferred"

    def test_given_caller_deck_export_when_evaluated_then_no_capture_checks(
        self, tmp_path, mocker
    ):
        # Arrange
        level_dir = self._level(tmp_path, "L300")
        mocker.patch("render_checks.measure_minutes", return_value=9.0)

        # Act
        result = evaluate(
            "L300", level_dir, load_curriculum(), capture_profile="deck-export"
        )

        # Assert
        assert result["ok"] is True
        assert "T-05" not in result["checks"]

    def test_given_evaluate_command_when_run_then_prints_json(
        self, tmp_path, mocker, capsys
    ):
        # Arrange
        level_dir = self._level(tmp_path)
        mocker.patch("render_checks.measure_minutes", return_value=7.0)

        # Act
        rc = main(["evaluate", "--level", "L100", "--level-dir", str(level_dir)])

        # Assert
        assert rc == 1
        assert json.loads(capsys.readouterr().out)["checks"]["T-07"]["result"] == "fail"


class TestContentPalette:
    """Tests for the content half of T-08."""

    def test_given_content_colour_outside_palette_when_checked_then_fail(self):
        # Arrange
        template = STYLE_TEMPLATE.read_text(encoding="utf-8")

        # Act
        result = check_style(
            template,
            template,
            {"slide-001": 'font_color: "#F8F8FC"', "slide-002": 'fill: "#10B981"'},
        )

        # Assert
        assert result["result"] == "fail"
        assert "slide-002" in result["evidence"]
        assert "slide-001" not in result["evidence"]


class TestOnScreenText:
    """Tests for on_screen_text."""

    def test_given_mixed_elements_when_extracted_then_ordered_unique_text(self):
        # Arrange
        slide = {
            "elements": [
                {"type": "textbox", "text": "Heading", "font": "Segoe UI"},
                {"type": "card", "title": "Card", "bullets": ["One", "Two"]},
                {"type": "image", "path": "images/x.png", "alt": "Editor view"},
                {"type": "image", "path": "images/y.png", "decorative": True},
                {"type": "textbox", "text": "heading"},
            ]
        }

        # Act
        text = on_screen_text(slide)

        # Assert
        assert text == ["Heading", "Card", "One", "Two", "Image: Editor view"]


class TestCaptions:
    """Tests for build_captions."""

    def test_given_two_slides_when_built_then_cues_span_each_wav(self, tmp_path):
        # Arrange
        _write_slides(tmp_path, 2, notes="First sentence. Second & last one.")

        # Act
        vtt = build_captions(tmp_path)

        # Assert
        assert vtt.startswith("WEBVTT\n")
        assert vtt.count(" --> ") == 4
        assert "00:00:00.000 --> " in vtt
        assert " --> 00:00:04.000" in vtt
        assert "Second &amp; last one." in vtt

    def test_given_long_sentence_when_built_then_cues_fit_two_lines(self, tmp_path):
        # Arrange
        words = " ".join(f"word{i}" for i in range(60))
        _write_slides(tmp_path, 1, notes=words)

        # Act
        cues = [
            block.split("\n", 2)[2]
            for block in build_captions(tmp_path).split("\n\n")[1:]
            if block.strip()
        ]

        # Assert
        assert len(cues) > 1
        assert all(len(line) <= 60 for cue in cues for line in cue.splitlines())


class TestTranscriptPage:
    """Tests for build_transcript_page."""

    def test_given_level_when_built_then_escaped_page_with_captions_track(
        self, tmp_path, mocker
    ):
        # Arrange
        _write_slides(tmp_path, 1, notes="Say <b>hi</b>.")
        mocker.patch("render_checks.measure_minutes", return_value=4.5)

        # Act
        page = build_transcript_page("L100", tmp_path)

        # Assert
        assert '<track kind="captions" src="hve-demo-L100.vtt"' in page
        assert "Say &lt;b&gt;hi&lt;/b&gt;." in page
        assert "<b>hi</b>" not in page
        assert '<html lang="en-US">' in page
        assert "Slide 1: Slide title 1" in page


class TestDeckAccessibility:
    """Tests for deck_accessibility_problems and check_accessibility."""

    def test_given_accessible_deck_when_checked_then_no_problems(self, tmp_path):
        # Arrange
        deck = tmp_path / "deck.pptx"
        _write_deck(deck, 2, picture_descr="VS Code editor")

        # Act / Assert
        assert deck_accessibility_problems(deck, "en-US") == []

    @pytest.mark.parametrize(
        ("kwargs", "problem"),
        [
            ({"language": None}, "language is not set"),
            ({"titled": False}, "slide 1 has no title"),
            ({"picture_descr": "capture.png"}, "no alternative text"),
            ({"picture_descr": ""}, "no alternative text"),
        ],
    )
    def test_given_gap_when_checked_then_reported(self, tmp_path, kwargs, problem):
        # Arrange
        deck = tmp_path / "deck.pptx"
        _write_deck(deck, 1, **kwargs)

        # Act
        problems = deck_accessibility_problems(deck, "en-US")

        # Assert
        assert any(problem in item for item in problems)

    def test_given_missing_captions_when_scored_then_fail(self, tmp_path):
        # Arrange
        _write_slides(tmp_path, 1)
        (tmp_path / "output").mkdir()
        _write_deck(tmp_path / "output" / "hve-demo-L100.pptx", 1)

        # Act
        result = check_accessibility("L100", tmp_path)

        # Assert
        assert result["result"] == "fail"
        assert "captions file missing" in result["evidence"]


class TestAccessibilityDelivery:
    """T-09 checks the delivered captions and the transcript's content."""

    def _level(self, tmp_path, mocker, languages=("eng",)):
        _write_slides(tmp_path, 2, notes="First sentence. Second one.")
        output = tmp_path / "output"
        output.mkdir()
        _write_deck(output / "hve-demo-L100.pptx", 2)
        (output / "hve-demo-L100.mp4").write_bytes(b"mp4")
        (output / "hve-demo-L100.vtt").write_text(
            build_captions(tmp_path), encoding="utf-8"
        )
        mocker.patch("render_checks.measure_minutes", return_value=4.5)
        (output / "index.html").write_text(
            build_transcript_page("L100", tmp_path), encoding="utf-8"
        )
        mocker.patch("render_checks.subtitle_languages", return_value=list(languages))
        return tmp_path

    def test_given_complete_delivery_when_scored_then_pass(self, tmp_path, mocker):
        level_dir = self._level(tmp_path, mocker)

        assert check_accessibility("L100", level_dir)["result"] == "pass"

    @pytest.mark.parametrize("languages", [(), ("deu",)])
    def test_given_mp4_without_english_subtitles_when_scored_then_fail(
        self, tmp_path, mocker, languages
    ):
        level_dir = self._level(tmp_path, mocker, languages)

        result = check_accessibility("L100", level_dir)

        assert result["result"] == "fail"
        assert "no English subtitle stream" in result["evidence"]

    def test_given_track_marker_but_missing_section_when_scored_then_fail(
        self, tmp_path, mocker
    ):
        level_dir = self._level(tmp_path, mocker)
        page = level_dir / "output" / "index.html"
        text = page.read_text(encoding="utf-8")
        start = text.index('<section aria-labelledby="slide-2">')
        page.write_text(text[:start] + text[text.index("</section>", start) + 10 :])

        result = check_accessibility("L100", level_dir)

        assert result["result"] == "fail"
        assert "1 sections for 2 slides" in result["evidence"]

    def test_given_transcript_narration_edited_when_scored_then_fail(
        self, tmp_path, mocker
    ):
        level_dir = self._level(tmp_path, mocker)
        page = level_dir / "output" / "index.html"
        page.write_text(
            page.read_text(encoding="utf-8").replace("Second one.", "Other.", 1)
        )

        result = check_accessibility("L100", level_dir)

        assert "slide 1 narration does not match" in result["evidence"]

    def test_given_caption_text_drift_when_scored_then_fail(self, tmp_path, mocker):
        level_dir = self._level(tmp_path, mocker)
        vtt = level_dir / "output" / "hve-demo-L100.vtt"
        vtt.write_text(vtt.read_text(encoding="utf-8").replace("Second", "Third"))

        result = check_accessibility("L100", level_dir)

        assert "caption text does not match the narration" in result["evidence"]

    @pytest.mark.parametrize(
        ("vtt", "message"),
        [
            ("1\n00:00:00.000 --> 00:00:01.000\nHi\n", "WEBVTT header"),
            ("WEBVTT\n\n1\n00:00:01.000 -> 00:00:02.000\nHi\n", "malformed"),
            ("WEBVTT\n\n1\n00:00:02.000 --> 00:00:01.000\nHi\n", "zero-length"),
            (
                "WEBVTT\n\n00:00:02.000 --> 00:00:03.000\nA\n\n"
                "00:00:01.000 --> 00:00:02.000\nB\n",
                "back in time",
            ),
        ],
    )
    def test_given_malformed_webvtt_when_parsed_then_raises(self, vtt, message):
        with pytest.raises(CheckError, match=message):
            parse_webvtt(vtt)

    def test_given_valid_webvtt_when_parsed_then_cues_unescaped(self):
        cues = parse_webvtt("WEBVTT\n\n1\n00:00:00.000 --> 00:00:01.500\nA &amp; B\n")

        assert cues == [(0.0, 1.5, "A & B")]


class TestPublicHelpers:
    """Helpers shared with html_deck."""

    def test_given_mixed_whitespace_and_case_when_normalized_then_equal(self):
        assert normalized_text("  Hello\n  World ") == normalized_text("hello world")

    def test_given_style_file_when_read_then_returns_metadata(self, tmp_path):
        style = tmp_path / "content" / "global" / "style.yaml"
        style.parent.mkdir(parents=True)
        style.write_text("metadata:\n  title: Demo\n  language: en-US\n")

        assert style_metadata(tmp_path) == {"title": "Demo", "language": "en-US"}

    def test_given_no_style_file_when_read_then_empty(self, tmp_path):
        assert style_metadata(tmp_path) == {}
