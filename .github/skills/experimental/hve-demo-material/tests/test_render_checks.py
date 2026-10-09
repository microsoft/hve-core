# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Tests for render_checks module."""

import json
import os
import shutil
import subprocess
import sys
import wave
import zipfile
from pathlib import Path

import pytest
from render_checks import (
    LEVELS,
    STYLE_TEMPLATE,
    CheckError,
    build_captions,
    build_parser,
    build_segments,
    build_silent_timing,
    build_transcript_page,
    changed_levels,
    check_accessibility,
    check_audio_mode,
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
    open_caption_evidence_problems,
    parse_curriculum,
    parse_webvtt,
    publish_generation,
    style_metadata,
    subtitle_languages,
    validate_media_timeline,
    validate_scripted_render,
    verify_open_captions,
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


class TestScriptedRenderPreflight:
    @pytest.mark.parametrize(
        ("level", "capture"),
        [
            ("L100", "deck-export"),
            ("L200", "deck-export"),
            ("L300", "live"),
            ("L400", "live"),
            ("L300", "deck-export"),
            ("L400", "deck-export"),
        ],
    )
    def test_given_supported_profile_when_checked_then_accepted(
        self, tmp_path, level, capture
    ):
        validate_scripted_render(level, tmp_path, capture)

    @pytest.mark.parametrize("level", ["L100", "L200"])
    def test_given_low_level_live_capture_when_checked_then_rejected(
        self, tmp_path, level
    ):
        with pytest.raises(CheckError, match="requires capture: deck-export"):
            validate_scripted_render(level, tmp_path, "live")

    def test_given_character_argument_when_checked_then_rejected(self, tmp_path):
        with pytest.raises(CheckError, match="supports animation: none only"):
            validate_scripted_render("L300", tmp_path, "live", "characters")

    @pytest.mark.parametrize("relative", ["manifest.yml", "output/manifest.yml"])
    def test_given_character_manifest_when_checked_then_preserved(
        self, tmp_path, relative
    ):
        # Arrange
        manifest = tmp_path / relative
        manifest.parent.mkdir(parents=True, exist_ok=True)
        content = "animation: characters\n"
        manifest.write_text(content, encoding="utf-8")

        # Act / Assert
        with pytest.raises(CheckError, match="declares character animation"):
            validate_scripted_render("L300", tmp_path, "live")
        assert manifest.read_text(encoding="utf-8") == content

    def test_given_clip_segments_when_checked_then_preserved(self, tmp_path):
        # Arrange
        manifest = tmp_path / "output/segments.yml"
        manifest.parent.mkdir()
        content = "segments:\n  - type: clip\n    clip: ../clips/scene.webm\n"
        manifest.write_text(content, encoding="utf-8")

        # Act / Assert
        with pytest.raises(CheckError, match="clip segments would be replaced"):
            validate_scripted_render("L300", tmp_path, "live")
        assert manifest.read_text(encoding="utf-8") == content

    @pytest.mark.parametrize(
        ("relative", "content"),
        [
            ("manifest.yml", "animation: ["),
            ("output/manifest.yml", "- characters\n"),
            ("output/segments.yml", "segments: invalid\n"),
        ],
    )
    def test_given_invalid_manifest_when_checked_then_rejected_without_writing(
        self, tmp_path, relative, content
    ):
        manifest = tmp_path / relative
        manifest.parent.mkdir(parents=True, exist_ok=True)
        manifest.write_text(content, encoding="utf-8")

        with pytest.raises(CheckError):
            validate_scripted_render("L300", tmp_path, "live")
        assert manifest.read_text(encoding="utf-8") == content

    @pytest.mark.parametrize(
        ("level", "capture", "animation", "relative", "content", "message"),
        [
            ("L100", "live", "none", None, None, "requires capture: deck-export"),
            ("L200", "live", "none", None, None, "requires capture: deck-export"),
            (
                "L300",
                "deck-export",
                "characters",
                None,
                None,
                "supports animation: none only",
            ),
            (
                "L300",
                "deck-export",
                "none",
                "output/manifest.yml",
                "animation: characters\n",
                "declares character animation",
            ),
            (
                "L300",
                "deck-export",
                "none",
                "output/segments.yml",
                "segments:\n  - type: clip\n    path: ../clips/scene.webm\n",
                "clip segments would be replaced",
            ),
        ],
    )
    def test_given_unsupported_run_when_shell_invoked_then_level_files_unchanged(
        self,
        tmp_path,
        monkeypatch,
        level,
        capture,
        animation,
        relative,
        content,
        message,
    ):
        level_dir = tmp_path / "level"
        (level_dir / "content").mkdir(parents=True)
        if relative:
            manifest = level_dir / relative
            manifest.parent.mkdir(parents=True, exist_ok=True)
            manifest.write_text(content, encoding="utf-8")
        before = {
            entry.relative_to(level_dir): entry.read_bytes()
            for entry in level_dir.rglob("*")
            if entry.is_file()
        }
        bin_dir = tmp_path / "bin"
        bin_dir.mkdir()
        uv = bin_dir / "uv"
        uv.write_text(
            f'#!/bin/sh\ncd "$3"\nshift 4\nexec "{sys.executable}" "$@"\n',
            encoding="utf-8",
        )
        uv.chmod(0o755)
        monkeypatch.setenv("PATH", f"{bin_dir}{os.pathsep}{os.environ['PATH']}")
        script = Path(__file__).resolve().parents[1] / "scripts/render-level.sh"

        result = subprocess.run(
            [
                "bash",
                str(script),
                "--level",
                level,
                "--level-dir",
                str(level_dir),
                "--workspace",
                str(tmp_path),
                "--capture",
                capture,
                "--animation",
                animation,
                "--narration",
                "none",
                "--no-html-deck",
            ],
            capture_output=True,
            text=True,
            timeout=15,
        )

        assert result.returncode != 0
        assert message in result.stderr
        after = {
            entry.relative_to(level_dir): entry.read_bytes()
            for entry in level_dir.rglob("*")
            if entry.is_file()
        }
        assert after == before
        if relative is None:
            assert not (level_dir / "output").exists()


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
        assert "type: crossfade" in text
        assert "duration: 0.5" in text
        assert "fade_in: true" in text
        assert "fade_out: true" in text
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
        mocker.patch("render_checks.open_caption_evidence_problems", return_value=[])

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


class TestSilentTiming:
    @pytest.mark.parametrize(
        "engine,audio_check,published",
        [
            ("none", "pass", True),
            ("piper", "pass", False),
            ("azure", "pass", False),
            ("none", "fail", False),
        ],
    )
    def test_given_render_when_bundled_then_only_verified_silent_output_replaces_prior(
        self, tmp_path, engine, audio_check, published
    ):
        import yaml

        workflow = (
            Path(__file__).resolve().parents[5]
            / ".github/workflows/demo-material-render.yml"
        )
        config = yaml.safe_load(workflow.read_text(encoding="utf-8"))
        command = next(
            step["run"]
            for step in config["jobs"]["bundle"]["steps"]
            if step["name"] == "Assemble the bundle"
        )
        site = tmp_path / "site"
        prior = site / "L100"
        prior.mkdir(parents=True)
        (prior / "hve-demo-L100.mp4").write_bytes(b"previous passing video")
        (site / "index.json").write_text(
            json.dumps(
                {
                    "schema_version": "demo-material-site/v1",
                    "levels": {
                        "L100": {
                            "source_sha": "prior",
                            "files": {"mp4": "L100/hve-demo-L100.mp4"},
                        }
                    },
                }
            ),
            encoding="utf-8",
        )
        renders = tmp_path / "renders"
        candidate = renders / "L100"
        candidate.mkdir(parents=True)
        for extension in ("mp4", "pptx", "vtt", "html"):
            (candidate / f"hve-demo-L100.{extension}").write_bytes(b"new render")
        (candidate / "index.html").write_text("Transcript", encoding="utf-8")
        (candidate / "render-result.json").write_text(
            json.dumps(
                {
                    "ok": True,
                    "narration_engine": engine,
                    "timing_basis": "notes-word-count",
                    "checks": {"T-11": {"result": audio_check}},
                }
            ),
            encoding="utf-8",
        )

        subprocess.run(
            ["bash", "-c", command],
            check=True,
            env={
                "PATH": os.pathsep.join(
                    (str(Path(sys.executable).parent), os.environ["PATH"])
                ),
                "SITE": str(site),
                "RENDERS": str(renders),
                "SOURCE_SHA": "candidate",
                "AUTHOR_RUN_ID": "1",
                "RENDER_RUN_ID": "2",
                "RUNNER_TEMP": str(tmp_path),
            },
            capture_output=True,
            text=True,
        )

        entry = json.loads((site / "index.json").read_text())["levels"]["L100"]
        assert (prior / "hve-demo-L100.mp4").read_bytes() == (
            b"new render" if published else b"previous passing video"
        )
        if published:
            assert entry["narration_engine"] == "none"
            assert entry["timing_basis"] == "notes-word-count"
        else:
            assert entry["last_failed_attempt"]["render_run_id"] == "2"

    def test_given_default_arguments_when_parsed_then_azure_remains_default(self):
        args = build_parser().parse_args(
            ["evaluate", "--level", "L100", "--level-dir", "."]
        )
        assert args.narration == "azure"

    @pytest.mark.parametrize("engine", ["azure", "piper"])
    def test_given_ci_voice_selection_when_rendered_then_rejected_before_writes(
        self, tmp_path, monkeypatch, engine
    ):
        (tmp_path / "content").mkdir()
        script = Path(__file__).resolve().parents[1] / "scripts/render-level.sh"
        monkeypatch.setenv("GITHUB_ACTIONS", "true")

        result = subprocess.run(
            [
                "bash",
                str(script),
                "--level",
                "L100",
                "--level-dir",
                str(tmp_path),
                "--workspace",
                str(tmp_path),
                "--narration",
                engine,
            ],
            capture_output=True,
            text=True,
            check=False,
        )

        assert result.returncode != 0
        assert "speech synthesis is disabled" in result.stderr
        assert not (tmp_path / "output").exists()

    def test_given_workflow_when_inspected_then_synthesis_is_not_configured(self):
        import yaml

        workflow = (
            Path(__file__).resolve().parents[5]
            / ".github/workflows/demo-material-render.yml"
        )
        source = workflow.read_text(encoding="utf-8")
        config = yaml.safe_load(source)
        render = next(
            step
            for step in config["jobs"]["render"]["steps"]
            if step["name"].startswith("Render ")
        )
        assert "--narration none" in render["run"]
        assert "piper" not in source.lower()
        assert "SPEECH_KEY" not in source

    @pytest.mark.parametrize(
        "streams,expected", [([], "pass"), ([{"index": 1}], "fail")]
    )
    def test_given_silent_mode_when_scored_then_audio_presence_is_enforced(
        self, tmp_path, mocker, streams, expected
    ):
        mocker.patch(
            "render_checks.subprocess.run",
            return_value=subprocess.CompletedProcess(
                [], 0, json.dumps({"streams": streams}), ""
            ),
        )
        assert check_audio_mode(tmp_path / "video.mp4", "none")["result"] == expected

    def test_given_notes_when_timed_then_canonical_wavs_contain_only_silence(
        self, tmp_path
    ):
        _write_slides(tmp_path, 2, notes=" ".join(["word"] * 28))

        build_silent_timing(tmp_path)

        for number in (1, 2):
            with wave.open(str(tmp_path / f"audio/slide-{number:03d}.wav")) as audio:
                assert audio.getnframes() / audio.getframerate() == 10
                assert not any(audio.readframes(audio.getnframes()))
        assert parse_webvtt(build_captions(tmp_path))[-1][1] == 20

    def test_given_short_notes_when_timed_then_scene_has_minimum_reading_time(
        self, tmp_path
    ):
        _write_slides(tmp_path, 1, notes="Short.")

        assert main(["silent-timing", "--level-dir", str(tmp_path)]) == 0

        assert parse_webvtt(build_captions(tmp_path))[-1][1] == 2

    def test_given_missing_notes_when_timed_then_existing_audio_is_preserved(
        self, tmp_path
    ):
        _write_slides(tmp_path, 1, notes="")
        audio = tmp_path / "audio/slide-001.wav"
        before = audio.read_bytes()

        with pytest.raises(CheckError, match="needs speaker notes"):
            build_silent_timing(tmp_path)

        assert audio.read_bytes() == before


class TestCaptionTimeline:
    @pytest.mark.parametrize("crossfade,expected", [(False, 4.0), (True, 5.5)])
    def test_given_silent_closing_scene_when_validated_then_full_duration_counts(
        self, tmp_path, mocker, crossfade, expected
    ):
        import yaml

        _write_slides(tmp_path, 2, notes="Opening narration.")
        closing = tmp_path / "content/slide-002/content.yaml"
        closing.write_text(
            "slide: 2\ntitle: Closing\nspeaker_notes: ''\n", encoding="utf-8"
        )
        (tmp_path / "output").mkdir()
        segments = yaml.safe_load(build_segments(tmp_path, "raw.mp4"))
        if not crossfade:
            segments["transition"] = "none"
        (tmp_path / "output/segments.yml").write_text(
            yaml.safe_dump(segments), encoding="utf-8"
        )
        mocker.patch("render_checks.measure_minutes", return_value=expected / 60)

        validate_media_timeline(tmp_path, tmp_path / "raw.mp4")

        assert parse_webvtt(build_captions(tmp_path))[-1][1] < expected

    def test_given_wrong_raw_duration_when_checked_then_requires_reassembly(
        self, tmp_path, mocker
    ):
        _write_slides(tmp_path, 1)
        mocker.patch("render_checks.measure_minutes", return_value=1 / 60)
        with pytest.raises(CheckError, match="reassemble"):
            validate_media_timeline(tmp_path, tmp_path / "raw.mp4")

    def test_given_failed_frame_decode_when_compared_then_retains_diagnostics(
        self, tmp_path, mocker
    ):
        captions = tmp_path / "captions.vtt"
        captions.write_text(
            "WEBVTT\n\n1\n00:00:00.000 --> 00:00:02.000\nWords\n", encoding="utf-8"
        )
        mocker.patch(
            "render_checks.subprocess.run",
            return_value=subprocess.CompletedProcess([], 23, "", "decoder failed"),
        )
        with pytest.raises(CheckError, match=r"exit 23.*decoder failed"):
            verify_open_captions(
                tmp_path / "control.mp4",
                tmp_path / "final.mp4",
                captions,
                tmp_path / "evidence.json",
            )

    @pytest.mark.parametrize("mutation", ["order", "duration", "narration"])
    def test_given_noncanonical_segments_when_captioned_then_rejected(
        self, tmp_path, mutation
    ):
        import yaml

        _write_slides(tmp_path, 2)
        output = tmp_path / "output"
        output.mkdir()
        data = yaml.safe_load(build_segments(tmp_path, "demo.mp4"))
        if mutation == "order":
            data["segments"].reverse()
        elif mutation == "duration":
            data["segments"][0]["duration"] = 1
        else:
            data["segments"][0]["narration"] = "../audio/other.wav"
        (output / "segments.yml").write_text(yaml.safe_dump(data), encoding="utf-8")
        with pytest.raises(CheckError, match="canonical"):
            build_captions(tmp_path)


class TestDeliveryRollback:
    @pytest.mark.parametrize(
        "failing_name",
        ["hve-demo-L100.mp4", "hve-demo-L100.vtt", "open-captions.json", "index.html"],
    )
    def test_given_replacement_failure_when_published_then_all_prior_files_restored(
        self, tmp_path, mocker, failing_name
    ):
        output = tmp_path / "output"
        stage = tmp_path / "stage"
        output.mkdir()
        stage.mkdir()
        names = (
            "hve-demo-L100.mp4",
            "hve-demo-L100.vtt",
            "open-captions.json",
            "index.html",
        )
        for name in names:
            (output / name).write_bytes(b"prior")
            (stage / name).write_bytes(b"next")
        mocker.patch("render_checks.open_caption_evidence_problems", return_value=[])
        replace = os.replace

        def fail_selected(source, destination):
            if Path(source).parent == stage and Path(source).name == failing_name:
                raise OSError("injected install failure")
            replace(source, destination)

        mocker.patch("render_checks.os.replace", side_effect=fail_selected)
        with pytest.raises(OSError, match="injected"):
            publish_generation("L100", stage, output)
        assert all((output / name).read_bytes() == b"prior" for name in names)


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

    def test_given_crossfade_when_built_then_cues_follow_overlapped_timeline(
        self, tmp_path
    ):
        # Arrange
        _write_slides(tmp_path, 2, notes="First sentence. Second sentence.")
        output = tmp_path / "output"
        output.mkdir()
        (output / "segments.yml").write_text(
            "transition:\n"
            "  type: crossfade\n"
            "  duration: 0.5\n"
            "segments:\n"
            "  - narration: ../audio/slide-001.wav\n"
            "  - narration: ../audio/slide-002.wav\n",
            encoding="utf-8",
        )

        # Act
        cues = parse_webvtt(build_captions(tmp_path))

        # Assert
        assert cues[2][0] == pytest.approx(3.0)
        assert cues[-1][1] == pytest.approx(5.0)

    def test_given_short_final_sentence_when_crossfaded_then_cues_stay_ordered(
        self, tmp_path
    ):
        _write_slides(
            tmp_path,
            2,
            notes=(
                "This scene explains how the product supports a repeatable "
                "review of source files. OK."
            ),
        )
        for number in (1, 2):
            _write_wav(tmp_path / f"audio/slide-{number:03d}.wav", 4)
        (tmp_path / "content/slide-002/content.yaml").write_text(
            "slide: 2\ntitle: Next\nspeaker_notes: Next scene.\n", encoding="utf-8"
        )
        output = tmp_path / "output"
        output.mkdir()
        (output / "segments.yml").write_text(
            "transition: {type: crossfade, duration: 0.5}\n"
            "segments:\n  - narration: ../audio/slide-001.wav\n"
            "  - narration: ../audio/slide-002.wav\n",
            encoding="utf-8",
        )

        captions = build_captions(tmp_path)
        cues = parse_webvtt(captions)
        (output / "hve-demo-L300.vtt").write_text(captions, encoding="utf-8")

        assert [cue[0] for cue in cues] == sorted(cue[0] for cue in cues)
        assert cues[1][2] == "OK."
        assert cues[2][0] == pytest.approx(5.0)
        assert (
            "caption text does not match"
            not in check_accessibility("L300", tmp_path)["evidence"]
        )


class TestAccessibleVideoFinalizer:
    """Tests for the portable accessible-media finalizer."""

    @pytest.mark.parametrize("narration_engine", ["azure", "none"])
    def test_given_two_audio_scenes_when_finalized_then_handles_are_silent(
        self, tmp_path, monkeypatch, narration_engine
    ):
        import array
        import importlib.util
        import math

        import yaml

        script = (
            Path(__file__).resolve().parents[1] / "scripts/finalize-accessible-video.sh"
        )
        prerequisites = subprocess.run(
            ["bash", str(script), "--check-prerequisites"],
            capture_output=True,
            text=True,
        )
        if prerequisites.returncode:
            pytest.skip(prerequisites.stderr)
        tools = dict(line.split("=", 1) for line in prerequisites.stdout.splitlines())
        monkeypatch.setenv("FFMPEG_COMMAND", tools["ffmpeg"])
        monkeypatch.setenv("FFPROBE_COMMAND", tools["ffprobe"])
        monkeypatch.setenv(
            "PATH", f"{Path(tools['ffmpeg']).parent}{os.pathsep}{os.environ['PATH']}"
        )
        _write_slides(tmp_path, 2, notes="First voice describes the scene.")
        for number, frequency in ((1, 440), (2, 880)):
            samples = array.array(
                "h",
                [
                    int(12000 * math.sin(2 * math.pi * frequency * index / 8000))
                    for index in range(16000)
                ],
            )
            with wave.open(
                str(tmp_path / f"audio/slide-{number:03d}.wav"), "wb"
            ) as audio:
                audio.setnchannels(1)
                audio.setsampwidth(2)
                audio.setframerate(8000)
                audio.writeframes(samples.tobytes())
            (tmp_path / f"frames/frame-{number}.ppm").write_bytes(
                b"P6\n640 360\n255\n" + bytes((number * 40, 90, 40)) * (640 * 360)
            )
        output = tmp_path / "output"
        output.mkdir()
        manifest = output / "segments.yml"
        manifest.write_text(
            yaml.safe_dump(
                {
                    "output": "hve-demo-L300.raw.mp4",
                    "resolution": "640x360",
                    "fps": 24,
                    "transition": {"duration": 0.5},
                    "segments": [
                        {
                            "visual": f"../frames/frame-{number}.ppm",
                            "narration": f"../audio/slide-{number:03d}.wav",
                        }
                        for number in (1, 2)
                    ],
                }
            ),
            encoding="utf-8",
        )
        recorder_root = Path(__file__).resolve().parents[2] / "vscode-playwright"
        recorder_python = recorder_root / ".venv/bin/python"
        if recorder_python.is_file():
            scene = tmp_path / "scene.html"
            scene.write_text(
                '<body data-animation-ready="true" style="margin:0;background:red">'
                '<script>window.startAnimation=()=>{document.body.style.background="red";'
                'setTimeout(()=>document.body.style.background="blue",1000);};</script></body>',
                encoding="utf-8",
            )
            clip = tmp_path / "scene.webm"
            subprocess.run(
                [
                    str(recorder_python),
                    str(recorder_root / "scripts/record_browser_video.py"),
                    "--scene",
                    str(scene),
                    "--output",
                    str(clip),
                    "--duration",
                    "2",
                    "--resolution",
                    "640x360",
                ],
                check=True,
                timeout=60,
            )
            data = yaml.safe_load(manifest.read_text(encoding="utf-8"))
            data["segments"][0].pop("visual")
            data["segments"][0]["clip"] = "../scene.webm"
            manifest.write_text(yaml.safe_dump(data), encoding="utf-8")
        else:
            pytest.skip(
                "Browser-clip integration requires the sibling recorder environment"
            )
        module_path = (
            Path(__file__).resolve().parents[2] / "demo-video/scripts/assemble_video.py"
        )
        spec = importlib.util.spec_from_file_location("runtime_assembler", module_path)
        assembler = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(assembler)

        raw = assembler.assemble_video(
            manifest_path=manifest, output_path=None, fps=None, resolution=None
        )
        finalizer_args = [
            "bash",
            str(script),
            "--level",
            "L300",
            "--level-dir",
            str(tmp_path),
        ]
        subprocess.run(
            finalizer_args,
            check=True,
        )
        if narration_engine == "none":
            subprocess.run(finalizer_args + ["--narration", "none"], check=True)
        cues = parse_webvtt((output / "hve-demo-L300.vtt").read_text())
        assert measure_minutes(raw) * 60 == pytest.approx(5.5, abs=0.15)
        assert max(cue[1] for cue in cues) == pytest.approx(5)
        silent = subprocess.run(
            [
                tools["ffmpeg"],
                "-v",
                "error",
                "-ss",
                "2.7",
                "-i",
                str(raw),
                "-t",
                "0.1",
                "-f",
                "s16le",
                "-acodec",
                "pcm_s16le",
                "-",
            ],
            capture_output=True,
            check=True,
        ).stdout
        assert max(abs(sample) for sample in array.array("h", silent)) < 200
        streams = json.loads(
            subprocess.run(
                [
                    tools["ffprobe"],
                    "-v",
                    "error",
                    "-show_streams",
                    "-of",
                    "json",
                    str(output / "hve-demo-L300.mp4"),
                ],
                capture_output=True,
                text=True,
                check=True,
            ).stdout
        )["streams"]
        assert any(
            stream["codec_type"] == "subtitle"
            and stream["disposition"]["forced"] == 0
            and stream.get("tags", {}).get("language") == "eng"
            for stream in streams
        )
        assert " default" not in (output / "index.html").read_text()
        assert any(stream["codec_type"] == "audio" for stream in streams) == (
            narration_engine != "none"
        )
        if narration_engine == "none":
            assert "Silent video: no voiceover" in (output / "index.html").read_text()
            scored = evaluate(
                "L300", tmp_path, load_curriculum(), narration_engine="none"
            )
            assert scored["narration_engine"] == "none"
            assert scored["timing_basis"] == "notes-word-count"
            assert scored["checks"]["T-11"]["result"] == "pass"

    @pytest.mark.parametrize("folder_name", ["level", "demo's workspace"])
    def test_given_authored_level_when_finalized_then_captions_are_visible(
        self, tmp_path, monkeypatch, folder_name
    ):
        # Arrange
        tmp_path = tmp_path / folder_name
        tmp_path.mkdir()
        script = (
            Path(__file__).resolve().parents[1]
            / "scripts"
            / "finalize-accessible-video.sh"
        )
        prerequisite_check = subprocess.run(
            ["bash", str(script), "--check-prerequisites"],
            capture_output=True,
            text=True,
            check=False,
        )
        if prerequisite_check.returncode != 0:
            pytest.skip(prerequisite_check.stderr.strip())
        tools = {
            name: value
            for line in prerequisite_check.stdout.splitlines()
            for name, value in [line.split("=", 1)]
        }
        ffmpeg = tools["ffmpeg"]
        ffprobe = tools["ffprobe"]
        _write_slides(tmp_path, 1, notes="These captions must be visible.")
        output = tmp_path / "output"
        output.mkdir()
        video = output / "hve-demo-L100.mp4"
        subprocess.run(
            [
                ffmpeg,
                "-y",
                "-v",
                "error",
                "-f",
                "lavfi",
                "-i",
                "color=c=black:s=640x360:r=24:d=2",
                "-f",
                "lavfi",
                "-i",
                "anullsrc=r=8000:cl=mono",
                "-t",
                "2",
                "-c:v",
                "libx264",
                "-pix_fmt",
                "yuv420p",
                "-c:a",
                "aac",
                str(video),
            ],
            check=True,
        )
        source = tmp_path / "source.mp4"
        shutil.copyfile(video, source)
        shutil.copyfile(video, output / "hve-demo-L100.raw.mp4")
        # Act
        subprocess.run(
            ["bash", str(script), "--level", "L100", "--level-dir", str(tmp_path)],
            check=True,
        )

        # Assert
        streams = json.loads(
            subprocess.run(
                [
                    ffprobe,
                    "-v",
                    "error",
                    "-show_entries",
                    "stream=codec_type,codec_name:stream_tags=language",
                    "-of",
                    "json",
                    str(video),
                ],
                capture_output=True,
                text=True,
                check=True,
            ).stdout
        )["streams"]
        assert any(
            stream.get("codec_type") == "subtitle"
            and stream.get("codec_name") == "mov_text"
            and stream.get("tags", {}).get("language") == "eng"
            for stream in streams
        )
        assert (
            open_caption_evidence_problems(
                video,
                output / "hve-demo-L100.vtt",
                output / "open-captions.json",
            )
            == []
        )
        raw = output / "hve-demo-L100.raw.mp4"
        raw_bytes = raw.read_bytes()
        original_hash = video.read_bytes()
        (tmp_path / "content/slide-001/content.yaml").write_text(
            "slide: 1\ntitle: Updated\nspeaker_notes: Updated caption text.\n",
            encoding="utf-8",
        )
        subprocess.run(
            ["bash", str(script), "--level", "L100", "--level-dir", str(tmp_path)],
            check=True,
        )
        assert raw.read_bytes() == raw_bytes
        assert video.read_bytes() != original_hash
        assert "Updated caption text." in (output / "hve-demo-L100.vtt").read_text()
        current_hash = video.read_bytes()
        (output / "open-captions.json").unlink()
        subprocess.run(
            ["bash", str(script), "--level", "L100", "--level-dir", str(tmp_path)],
            check=True,
        )
        assert video.read_bytes() == current_hash
        prior = {
            name: (output / name).read_bytes()
            for name in (
                "hve-demo-L100.mp4",
                "hve-demo-L100.vtt",
                "open-captions.json",
                "index.html",
            )
        }
        tool_bin = tmp_path / "test-bin"
        tool_bin.mkdir()
        fake_uv = tool_bin / "uv"
        fake_uv.write_text(
            '#!/bin/sh\ncd "$3"\nshift 4\n'
            'if [ "$2" = "$FAIL_STAGE" ]; then '
            'echo "injected stage failure" >&2; exit 71; fi\n'
            f'exec "{sys.executable}" "$@"\n',
            encoding="utf-8",
        )
        fake_uv.chmod(0o755)
        fake_ffmpeg = tool_bin / "ffmpeg"
        fake_ffmpeg.write_text(
            '#!/bin/sh\nif [ "$1" = "-y" ] && [ "$FAIL_STAGE" = "encode" ]; '
            "then exit 72; fi\n"
            f'exec "{ffmpeg}" "$@"\n',
            encoding="utf-8",
        )
        fake_ffmpeg.chmod(0o755)
        successful_content = (tmp_path / "content/slide-001/content.yaml").read_bytes()
        (tmp_path / "content/slide-001/content.yaml").write_text(
            "slide: 1\ntitle: Failed generation\n"
            "speaker_notes: This update must not publish.\n",
            encoding="utf-8",
        )
        with monkeypatch.context() as environment:
            environment.setenv("PATH", f"{tool_bin}{os.pathsep}{os.environ['PATH']}")
            environment.setenv("FFMPEG_COMMAND", str(fake_ffmpeg))
            environment.setenv("FFPROBE_COMMAND", ffprobe)
            for stage in ("encode", "verify-open-captions", "transcript"):
                environment.setenv("FAIL_STAGE", stage)
                attempt = subprocess.run(
                    [
                        "bash",
                        str(script),
                        "--level",
                        "L100",
                        "--level-dir",
                        str(tmp_path),
                    ],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                assert attempt.returncode != 0
                assert all(
                    (output / name).read_bytes() == content
                    for name, content in prior.items()
                )
        raw.unlink()
        failed = subprocess.run(
            ["bash", str(script), "--level", "L100", "--level-dir", str(tmp_path)],
            capture_output=True,
            text=True,
            check=False,
        )
        assert failed.returncode != 0
        assert "reassemble" in failed.stderr
        assert all(
            (output / name).read_bytes() == content for name, content in prior.items()
        )
        raw.write_bytes(raw_bytes)
        (tmp_path / "content/slide-001/content.yaml").write_bytes(successful_content)
        pixels = subprocess.run(
            [
                ffmpeg,
                "-v",
                "error",
                "-ss",
                "1",
                "-i",
                str(video),
                "-frames:v",
                "1",
                "-vf",
                "crop=iw:ih/3:0:2*ih/3,signalstats,metadata=mode=print:file=-",
                "-f",
                "null",
                "-",
            ],
            capture_output=True,
            text=True,
            check=True,
        ).stdout
        ymax = next(
            int(line.rsplit("=", 1)[1])
            for line in pixels.splitlines()
            if line.startswith("lavfi.signalstats.YMAX=")
        )
        assert ymax > 100
        assert (output / "hve-demo-L100.vtt").is_file()
        assert (output / "index.html").is_file()
        first_render = video.read_bytes()

        subprocess.run(
            ["bash", str(script), "--level", "L100", "--level-dir", str(tmp_path)],
            check=True,
        )

        assert video.read_bytes() == first_render

        control = tmp_path / "uncaptioned-control.mp4"
        candidate = tmp_path / "uncaptioned-candidate.mp4"
        for target in (control, candidate):
            subprocess.run(
                [
                    ffmpeg,
                    "-y",
                    "-v",
                    "error",
                    "-i",
                    str(source),
                    "-map",
                    "0:v:0",
                    "-map",
                    "0:a?",
                    "-c:v",
                    "libx264",
                    "-preset",
                    "medium",
                    "-crf",
                    "18",
                    "-c:a",
                    "copy",
                    str(target),
                ],
                check=True,
            )

        with pytest.raises(CheckError, match="visible frame difference"):
            verify_open_captions(
                control,
                candidate,
                output / "hve-demo-L100.vtt",
                output / "false-evidence.json",
            )

    def test_given_invalid_override_when_checked_then_reports_it(self):
        # Arrange
        script = (
            Path(__file__).resolve().parents[1]
            / "scripts"
            / "finalize-accessible-video.sh"
        )
        environment = {**os.environ, "FFMPEG_COMMAND": "/missing/ffmpeg"}

        # Act
        result = subprocess.run(
            ["bash", str(script), "--check-prerequisites"],
            capture_output=True,
            text=True,
            env=environment,
            check=False,
        )

        # Assert
        assert result.returncode == 1
        assert "FFMPEG_COMMAND does not resolve" in result.stderr

    def test_given_relocated_script_when_called_with_bash_then_tools_resolve(
        self, tmp_path
    ):
        original = (
            Path(__file__).resolve().parents[1] / "scripts/finalize-accessible-video.sh"
        )
        relocated = (
            tmp_path
            / "installed/skills/demo-material/scripts/finalize-accessible-video.sh"
        )
        relocated.parent.mkdir(parents=True)
        shutil.copyfile(original, relocated)
        relocated.chmod(0o644)

        result = subprocess.run(
            ["bash", str(relocated), "--check-prerequisites"],
            capture_output=True,
            text=True,
            check=False,
        )

        if result.returncode:
            pytest.skip(result.stderr)
        assert "ffmpeg=" in result.stdout and "ffprobe=" in result.stdout

    def test_given_unusable_ffprobe_override_when_checked_then_reports_it(
        self, tmp_path
    ):
        # Arrange
        script = (
            Path(__file__).resolve().parents[1]
            / "scripts"
            / "finalize-accessible-video.sh"
        )
        fake_probe = tmp_path / "ffprobe"
        fake_probe.write_text("#!/usr/bin/env bash\nexit 1\n", encoding="utf-8")
        fake_probe.chmod(0o755)
        environment = {**os.environ, "FFPROBE_COMMAND": str(fake_probe)}

        # Act
        result = subprocess.run(
            ["bash", str(script), "--check-prerequisites"],
            capture_output=True,
            text=True,
            env=environment,
            check=False,
        )

        # Assert
        assert result.returncode == 1
        assert "FFPROBE_COMMAND is not a usable" in result.stderr


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
        assert '<a href="../../docs/demo-material/">Back to Demo Material</a>' in page
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
        mocker.patch("render_checks.open_caption_evidence_problems", return_value=[])
        return tmp_path

    def test_given_complete_delivery_when_scored_then_pass(self, tmp_path, mocker):
        level_dir = self._level(tmp_path, mocker)

        assert check_accessibility("L100", level_dir)["result"] == "pass"

    def test_given_soft_captions_only_when_scored_then_fail(self, tmp_path, mocker):
        level_dir = self._level(tmp_path, mocker)
        mocker.patch(
            "render_checks.open_caption_evidence_problems",
            return_value=["open-caption verification evidence missing"],
        )

        result = check_accessibility("L100", level_dir)

        assert "open-caption verification evidence missing" in result["evidence"]

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


class TestRenderCommandContracts:
    """Exercise command dispatch and generated artifacts without media services."""

    def test_given_authored_notes_when_commands_run_then_silent_assets_agree(
        self, tmp_path, mocker
    ):
        _write_slides(tmp_path, 1)
        mocker.patch("render_checks.measure_minutes", return_value=2.0)
        captions = tmp_path / "output/hve-demo-L100.vtt"

        assert main(["silent-timing", "--level-dir", str(tmp_path)]) == 0
        assert (
            main(
                [
                    "segments",
                    "--level-dir",
                    str(tmp_path),
                    "--output-name",
                    "hve-demo-L100.raw.mp4",
                ]
            )
            == 0
        )
        assert (
            main(["captions", "--level-dir", str(tmp_path), "--output", str(captions)])
            == 0
        )
        assert (
            main(
                [
                    "transcript",
                    "--level",
                    "L100",
                    "--level-dir",
                    str(tmp_path),
                    "--narration",
                    "none",
                ]
            )
            == 0
        )

        assert parse_webvtt(captions.read_text())[0][2] == "one two three"
        assert "hve-demo-L100.raw.mp4" in (tmp_path / "output/segments.yml").read_text()
        assert (
            "Silent video: no voiceover" in (tmp_path / "output/index.html").read_text()
        )

    @pytest.mark.parametrize(
        ("report", "returncode", "expected"),
        [
            ('{"streams": []}', 0, 0),
            ('{"streams": [{"index": 1}]}', 0, 1),
            ("{}", 0, 1),
            ("invalid JSON", 0, 1),
            ('{"streams": false}', 0, 1),
            ("", 1, 1),
        ],
    )
    def test_given_probe_report_when_silence_checked_then_fails_closed(
        self, tmp_path, mocker, capsys, report, returncode, expected
    ):
        mocker.patch("render_checks.ffprobe_command", return_value="ffprobe")
        mocker.patch(
            "render_checks.subprocess.run",
            return_value=subprocess.CompletedProcess(
                [], returncode, report, "probe failed"
            ),
        )

        result = main(
            [
                "check-audio-mode",
                "--video",
                str(tmp_path / "video.mp4"),
                "--narration",
                "none",
            ]
        )

        assert result == expected
        assert json.loads(capsys.readouterr().out)["result"] == (
            "fail" if expected else "pass"
        )

    def test_given_missing_slides_when_timing_run_then_reports_failure(
        self, tmp_path, capsys
    ):
        result = main(["silent-timing", "--level-dir", str(tmp_path)])

        assert result == 1
        assert "no slides" in capsys.readouterr().err
        assert not (tmp_path / "audio").exists()


class TestCaptionEvidenceContracts:
    """Bind accepted caption evidence to all delivery inputs and visibility checks."""

    @pytest.fixture
    def verified_delivery(self, tmp_path, mocker):
        _write_slides(tmp_path, 1)
        paths = {
            name: tmp_path / name
            for name in (
                "control.mp4",
                "video.mp4",
                "raw.mp4",
                "captions.vtt",
                "evidence.json",
            )
        }
        for name in ("control.mp4", "video.mp4", "raw.mp4"):
            paths[name].write_bytes(name.encode())
        paths["captions.vtt"].write_text(build_captions(tmp_path), encoding="utf-8")
        mocker.patch("render_checks.measure_minutes", return_value=2 / 60)
        mocker.patch("render_checks.ffmpeg_command", return_value="ffmpeg")
        mocker.patch(
            "render_checks.subprocess.run",
            return_value=subprocess.CompletedProcess(
                [],
                0,
                "lavfi.signalstats.YMAX=100\nlavfi.bbox.w=300\nlavfi.bbox.h=40\n",
                "",
            ),
        )
        result = main(
            [
                "verify-open-captions",
                "--control",
                str(paths["control.mp4"]),
                "--finalized",
                str(paths["video.mp4"]),
                "--captions",
                str(paths["captions.vtt"]),
                "--output",
                str(paths["evidence.json"]),
                "--source",
                str(paths["raw.mp4"]),
                "--level-dir",
                str(tmp_path),
            ]
        )
        assert result == 0
        return paths

    @pytest.mark.parametrize(
        ("mutation", "problem"),
        [
            ("none", None),
            ("missing", "evidence missing"),
            ("unreadable", "unreadable"),
            ("result", "did not pass"),
            ("luma", "frame difference"),
            ("box", "difference region"),
            ("video.mp4", "delivered MP4"),
            ("captions.vtt", "delivered WebVTT"),
            ("raw.mp4", "raw assembly"),
        ],
    )
    def test_given_delivery_evidence_when_verified_then_rejects_tampering(
        self, verified_delivery, capsys, mutation, problem
    ):
        paths = verified_delivery
        evidence = paths["evidence.json"]
        if mutation == "missing":
            evidence.unlink()
        elif mutation == "unreadable":
            evidence.write_text("invalid JSON")
        elif mutation in ("result", "luma", "box"):
            record = json.loads(evidence.read_text())
            key = {
                "result": "result",
                "luma": "maximum_luma_difference",
                "box": "difference_box_area",
            }[mutation]
            record[key] = "fail" if mutation == "result" else 0
            evidence.write_text(json.dumps(record))
        elif mutation != "none":
            paths[mutation].write_bytes(b"modified delivery")
        capsys.readouterr()

        result = main(
            [
                "check-open-caption-evidence",
                "--video",
                str(paths["video.mp4"]),
                "--captions",
                str(paths["captions.vtt"]),
                "--evidence",
                str(evidence),
                "--source",
                str(paths["raw.mp4"]),
            ]
        )

        report = json.loads(capsys.readouterr().out)
        assert result == int(problem is not None)
        assert report["ok"] == (problem is None)
        assert (
            any(problem in message for message in report["problems"])
            if problem
            else report["problems"] == []
        )
