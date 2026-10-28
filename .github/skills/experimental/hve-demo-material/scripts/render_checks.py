#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Deterministic checks for rendering HVE demo material outside an agent.

Reads the level contracts and pinned sources from ``references/curriculum.md``
so CI and the agent share one policy source, decides which levels need a new
run, writes the ``demo-video`` segments manifest, generates captions and an
accessible transcript page, and scores the criteria a machine can verify
(T-04 through T-10).

Usage::

    python render_checks.py levels
    python render_checks.py changed --index index.json --repo . [--force]
    python render_checks.py segments --level-dir DIR --output-name x.mp4
    python render_checks.py captions --level-dir DIR --output DIR/output/x.vtt
    python render_checks.py transcript --level L100 --level-dir DIR
    python render_checks.py verify-open-captions --control BASE --finalized MP4 \
        --captions VTT --output JSON
    python render_checks.py check-open-caption-evidence --video MP4 \
        --captions VTT --evidence JSON
    python render_checks.py evaluate --level L100 --level-dir DIR --slides-skill-root ROOT

``levels`` and ``changed`` use only the standard library so a runner can call
them before any environment is synced.

Exit codes:
    0 - success; for ``evaluate``, every applicable check passed
    1 - a check failed or the inputs were invalid
"""

from __future__ import annotations

import argparse
import hashlib
import html
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import wave
from html.parser import HTMLParser
from pathlib import Path

EXIT_SUCCESS = 0
EXIT_FAILURE = 1

SKILL_ROOT = Path(__file__).resolve().parent.parent
CURRICULUM = SKILL_ROOT / "references" / "curriculum.md"
STYLE_TEMPLATE = SKILL_ROOT / "templates" / "style.yaml"

LEVELS = ("L100", "L200", "L300", "L400")
LIVE_LEVELS = frozenset({"L300", "L400"})

# A change under any of these paths rebuilds every level.
SHARED_TRIGGER_PATHS = (
    ".github/skills/experimental/hve-demo-material/",
    ".github/skills/experimental/hve-slides/",
    ".github/agents/experimental/hve-demo-material.agent.md",
    "docs/getting-started/tts-voiceover.md",
)

MIN_LIVE_CAPTURES = 2
MIN_RENDERED_FONT_PT = 18.0

# Two caption lines of about 42 characters each, the common broadcast limit.
CAPTION_LINE_CHARS = 42
CAPTION_MAX_CHARS = 2 * CAPTION_LINE_CHARS
MIN_OPEN_CAPTION_LUMA_DIFFERENCE = 64
MIN_OPEN_CAPTION_BOX_DIMENSION = 8
MIN_OPEN_CAPTION_BOX_AREA = 64


def ffmpeg_command() -> str:
    """Return the caller-selected FFmpeg executable."""
    return os.environ.get("FFMPEG_COMMAND", "ffmpeg")


def ffprobe_command() -> str:
    """Return the caller-selected FFprobe executable."""
    return os.environ.get("FFPROBE_COMMAND", "ffprobe")


TEXT_KEYS = ("text", "title", "subtitle", "label", "heading", "description", "content", "bullet")
TEXT_LIST_KEYS = ("bullets", "items", "segments", "paragraphs", "rows", "cells", "content")
_IMAGE_FILE_NAME = re.compile(r"\.(png|jpe?g|gif|bmp|svg|webp)$", re.IGNORECASE)
_SENTENCE_END = re.compile(r"(?<=[.!?])\s+")
MIN_SOURCE_WIDTH = 1920
MIN_SOURCE_HEIGHT = 1080

_DURATION = re.compile(r"(\d+(?:\.\d+)?)\s+to\s+(\d+(?:\.\d+)?)\s+minutes")
_BACKTICK_PATH = re.compile(r"`([^`]+)`")
_SLIDE_DIR = re.compile(r"^slide-(\d{3})$")


class CheckError(ValueError):
    """Raised when inputs are missing or malformed."""


def checked_path(path: Path, root: Path | None = None) -> Path:
    """Reject links, special files and paths outside an approved root.

    Missing leaves are allowed for outputs. Concurrent hostile local writers
    remain outside this check's guarantees.
    """
    path = path.absolute()
    if ".." in path.parts:
        raise CheckError(f"Parent traversal is not allowed: {path}")
    for parent in (*reversed(path.parents), path):
        try:
            info = parent.lstat()
        except FileNotFoundError:
            continue
        if (
            stat.S_ISLNK(info.st_mode)
            or getattr(info, "st_file_attributes", 0) & 0x400
            or not (stat.S_ISREG(info.st_mode) or stat.S_ISDIR(info.st_mode))
        ):
            raise CheckError(f"Expected an ordinary file or directory, not a link: {parent}")
    if root is not None and not path.is_relative_to(checked_path(root)):
        raise CheckError(f"Path is outside the approved root {root}: {path}")
    return path


def install_files(output: Path, files: dict[str, bytes]) -> None:
    """Replace only named flat files, with staged writes and rollback.

    Unrelated files and directories are preserved. Cleanup is nonrecursive and
    limited to this invocation's staging files.
    """
    output = checked_path(output)
    for name in files:
        if not re.fullmatch(r"[A-Za-z0-9_.-]+", name) or name in (".", ".."):
            raise CheckError(f"Invalid output filename: {name}")
        target = checked_path(output / name, output)
        if target.exists() and not target.is_file():
            raise CheckError(f"Output is not a regular file: {target}")
    output.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix=".render-stage-", dir=output))
    installed: list[str] = []
    saved: set[str] = set()
    try:
        for name, data in files.items():
            (stage / name).write_bytes(data)
            target = checked_path(output / name, output)
            if target.exists():
                (stage / f"backup-{name}").write_bytes(target.read_bytes())
                saved.add(name)
        try:
            for name in files:
                os.replace(stage / name, checked_path(output / name, output))
                installed.append(name)
        except (OSError, KeyboardInterrupt):
            for name in reversed(installed):
                if name in saved:
                    os.replace(stage / f"backup-{name}", output / name)
                else:
                    (output / name).unlink()
            raise
    finally:
        for name in files:
            (stage / name).unlink(missing_ok=True)
            (stage / f"backup-{name}").unlink(missing_ok=True)
        stage.rmdir()


def _section(text: str, heading: str) -> list[str]:
    """Return the lines under ``heading`` up to the next heading of equal or
    higher level."""
    lines = text.splitlines()
    try:
        start = lines.index(heading)
    except ValueError as exc:
        raise CheckError(f"heading not found in curriculum: {heading}") from exc
    depth = len(heading) - len(heading.lstrip("#"))
    body = []
    for line in lines[start + 1 :]:
        stripped = line.lstrip("#")
        line_depth = len(line) - len(stripped)
        if line_depth and line_depth <= depth and stripped.startswith(" "):
            break
        body.append(line)
    return body


def _table_rows(lines: list[str]) -> list[list[str]]:
    """Return the cells of each markdown table body row that starts with a
    level label."""
    rows = []
    for line in lines:
        if not line.startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if cells and cells[0] in LEVELS:
            rows.append(cells)
    return rows


def parse_curriculum(text: str) -> dict[str, dict]:
    """Parse the level duration contracts and pinned sources.

    Returns:
        ``{level: {"min": float, "max": float, "sources": [path, ...]}}``
    """
    levels: dict[str, dict] = {}
    for cells in _table_rows(_section(text, "## Level Contracts")):
        match = _DURATION.search(cells[2]) if len(cells) > 2 else None
        if not match:
            raise CheckError(f"no duration range for {cells[0]}")
        levels[cells[0]] = {
            "min": float(match.group(1)),
            "max": float(match.group(2)),
            "sources": [],
        }
    pinned = _section(text, "### Pinned Sources for `hve-core-general`")
    for cells in _table_rows(pinned):
        if cells[0] in levels and len(cells) > 2:
            levels[cells[0]]["sources"] = _BACKTICK_PATH.findall(cells[2])
    missing = [level for level in LEVELS if not levels.get(level, {}).get("sources")]
    if missing:
        raise CheckError(f"curriculum lacks contracts or sources for {missing}")
    return levels


def load_curriculum(path: Path = CURRICULUM) -> dict[str, dict]:
    """Load and parse the curriculum reference."""
    return parse_curriculum(path.read_text(encoding="utf-8"))


def level_touched(changed_files: list[str], sources: list[str]) -> bool:
    """Return True when a changed path is a level source or a shared trigger."""
    prefixes = (*sources, *SHARED_TRIGGER_PATHS)
    return any(
        path == prefix or path.startswith(prefix.rstrip("/") + "/")
        for path in changed_files
        for prefix in prefixes
    )


def _git_changed_files(repo: Path, base: str) -> list[str] | None:
    """Return files changed between ``base`` and HEAD, or None if unknown."""
    result = subprocess.run(
        ["git", "-C", str(repo), "diff", "--name-only", f"{base}...HEAD"],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        return None
    return [line for line in result.stdout.splitlines() if line]


def changed_levels(
    curriculum: dict[str, dict],
    index: dict,
    repo: Path,
    force: bool = False,
) -> list[str]:
    """Return the levels whose sources changed since their last render.

    A level with no recorded ``source_sha`` in ``index``, or whose recorded
    commit cannot be diffed, is treated as changed.
    """
    from artifact_lookup import SITE_SCHEMA, valid_entry

    schema = index.get("schema_version") if isinstance(index, dict) else None
    if schema not in (None, SITE_SCHEMA, "demo-material-site/v1"):
        raise CheckError("Unknown render index schema; preserve it and investigate")
    recorded = index.get("levels", {}) if isinstance(index, dict) and schema == SITE_SCHEMA else {}
    selected = []
    for level in LEVELS:
        entry = recorded.get(level) if isinstance(recorded, dict) else None
        base = entry.get("source_sha") if isinstance(entry, dict) else None
        if (
            force
            or not valid_entry(level, entry)
            or isinstance(entry.get("last_failed_attempt"), dict)
            or not isinstance(base, str)
            or not re.fullmatch(r"[0-9a-f]{40}", base)
        ):
            selected.append(level)
            continue
        files = _git_changed_files(repo, base)
        if files is None or level_touched(files, curriculum[level]["sources"]):
            selected.append(level)
    return selected


def slide_numbers(content_dir: Path) -> list[int]:
    """Return the sorted slide numbers found under ``content_dir``."""
    content_dir = checked_path(content_dir)
    numbers = []
    for child in content_dir.iterdir() if content_dir.is_dir() else ():
        if not child.name.startswith("slide-"):
            continue
        match = _SLIDE_DIR.fullmatch(child.name)
        if not match or int(match.group(1)) == 0:
            raise CheckError(f"Expected slide-NNN with a positive number: {child.name}")
        source = checked_path(child / "content.yaml", content_dir)
        if not source.is_file():
            raise CheckError(f"Missing slide content: {source}")
        numbers.append(int(match.group(1)))
    return sorted(numbers)


def validate_scripted_render(
    level: str, level_dir: Path, capture: str, animation: str = "none",
    slides_skill_root: Path | None = None,
) -> None:
    """Reject inputs that the deck-frame scripted renderer cannot preserve."""
    import yaml

    level_dir = checked_path(level_dir)
    for root in (SKILL_ROOT, slides_skill_root):
        if root is not None and level_dir.is_relative_to(checked_path(root)):
            raise CheckError("Level outputs must not be inside a skill installation")
    for relative in ("output", "frames/deck", "audio", "html-deck", "output/html-deck-build.json", "output/html-deck-check.json", "output/render-result.json", "output/captures.json", f"output/hve-demo-{level}.html"):
        checked_path(level_dir / relative, level_dir)
    if level in {"L100", "L200"} and capture != "deck-export":
        raise CheckError(f"{level} requires capture: deck-export")
    if animation != "none":
        raise CheckError(
            "Character animation requires the HVE Demo Material Builder's "
            "clip-aware workflow; render-level.sh supports animation: none only"
        )
    for relative in ("manifest.yml", "output/manifest.yml", "output/segments.yml"):
        manifest = level_dir / relative
        if not manifest.is_file():
            continue
        try:
            data = yaml.safe_load(manifest.read_text(encoding="utf-8"))
        except (OSError, yaml.YAMLError) as error:
            raise CheckError(
                f"Cannot read scripted-render input: {relative}"
            ) from error
        if not isinstance(data, dict):
            raise CheckError(f"Scripted-render input must be a mapping: {relative}")
        if data.get("animation", "none") != "none":
            raise CheckError(
                f"{relative} declares character animation; use the "
                "HVE Demo Material Builder's clip-aware workflow"
            )
        if relative == "output/segments.yml":
            segments = data.get("segments", [])
            if not isinstance(segments, list):
                raise CheckError("Existing segments must be a list")
            if any(
                isinstance(segment, dict)
                and (segment.get("type") == "clip" or "clip" in segment)
                for segment in segments
            ):
                raise CheckError(
                    "Existing clip segments would be replaced by deck frames; "
                    "use the HVE Demo Material Builder's clip-aware workflow"
                )


def build_silent_timing(level_dir: Path) -> None:
    """Write silent timing WAVs from notes at the curriculum's 2.8 words/second."""
    slides = load_slides(level_dir / "content")
    if not slides:
        raise CheckError(f"no slides under {level_dir / 'content'}")
    durations = []
    for number, slide in slides:
        words = len(notes_text(slide).split())
        if not words:
            raise CheckError(f"Slide {number} needs speaker notes for silent timing")
        durations.append((number, max(2.0, words / 2.8)))
    audio_dir = level_dir / "audio"
    audio_dir.mkdir(parents=True, exist_ok=True)
    for number, duration in durations:
        with wave.open(str(audio_dir / f"slide-{number:03d}.wav"), "wb") as audio:
            audio.setnchannels(1)
            audio.setsampwidth(2)
            audio.setframerate(8000)
            audio.writeframes(b"\x00\x00" * round(duration * 8000))


def build_segments(level_dir: Path, output_name: str) -> str:
    """Return a ``segments.yml`` that pairs each deck frame with its WAV.

    Paths are relative to ``output/`` because ``demo-video`` resolves them
    against the manifest file.
    """
    numbers = slide_numbers(level_dir / "content")
    if not numbers:
        raise CheckError(f"no slides under {level_dir / 'content'}")
    lines = [
        f"output: ./{output_name}",
        "resolution: 1920x1080",
        "fps: 24",
        "transition:",
        "  type: crossfade",
        "  duration: 0.5",
        "  fade_in: true",
        "  fade_out: true",
        "segments:",
    ]
    for number in numbers:
        name = f"slide-{number:03d}"
        frame = level_dir / "frames" / "deck" / f"{name}.jpg"
        audio = level_dir / "audio" / f"{name}.wav"
        if not frame.is_file():
            raise CheckError(f"missing frame {frame}")
        if not audio.is_file():
            raise CheckError(f"missing narration {audio}")
        lines += [
            "  - type: frame",
            f"    visual: ../frames/deck/{name}.jpg",
            f"    narration: ../audio/{name}.wav",
        ]
    return "\n".join(lines) + "\n"


def check_style(
    deck_html: str, theme_css: str, components_css: str
) -> dict:
    """Score T-08 from actual bundled CSS, allowing only embedded-image rules."""
    styles = re.findall(r'<style data-bundled-source="([^"]+)">\n([\s\S]*?)\n</style>', deck_html)
    bundled = dict(styles)
    evidence = []
    if len(styles) != 3 or set(bundled) != {"vendor/reveal.css", "theme.css", "components.css"}:
        evidence.append("expected exactly the canonical three bundled stylesheets")
    if bundled.get("theme.css") != theme_css:
        evidence.append("bundled theme.css differs from the canonical HVE Slides theme")
    prefix = components_css.rstrip() + "\n" + (SKILL_ROOT / "templates/html-deck.css").read_text(encoding="utf-8")
    components = bundled.get("components.css", "")
    if not components.startswith(prefix):
        evidence.append("bundled components.css differs from the permitted template/layout")
    else:
        image_rules = components[len(prefix):]
        if not re.fullmatch(r'(?:\.shot-\d+-\d+ \{ background-image: url\("data:image/(?:png|jpeg);base64,[A-Za-z0-9+/]+=*"\); \}\n)*', image_rules):
            evidence.append("components.css contains styling outside the permitted image rules")
    if len(re.findall(r"<style\b", deck_html, re.I)) != len(styles):
        evidence.append("additional untracked styling in HTML")
    return {
        "result": "fail" if evidence else "pass",
        "evidence": "; ".join(evidence) or "delivered HTML uses canonical HVE Slides theme and permitted demo styling",
    }


def check_segments(level_dir: Path) -> dict:
    """Score T-04: every segment names an existing WAV and counts match."""
    import yaml

    manifest = level_dir / "output" / "segments.yml"
    if not manifest.is_file():
        return {"result": "deferred", "evidence": "output/segments.yml missing"}
    segments = (yaml.safe_load(manifest.read_text(encoding="utf-8")) or {}).get(
        "segments"
    ) or []
    wavs = {p.name for p in (level_dir / "audio").glob("*.wav")}
    referenced = [Path(str(s.get("narration", ""))).name for s in segments]
    missing = [name for name in referenced if name not in wavs]
    passed = bool(segments) and not missing and len(referenced) == len(wavs)
    return {
        "result": "pass" if passed else "fail",
        "evidence": f"{len(segments)} segments, {len(wavs)} WAV files"
        + (f", missing {missing}" if missing else ""),
    }


def check_captures(captures: dict | None) -> tuple[dict, dict]:
    """Score T-05 and T-06 from a ``capture_vscode.py`` result."""
    if not captures:
        deferred = {"result": "deferred", "evidence": "no capture result"}
        return deferred, dict(deferred)
    items = [c for c in captures.get("captures", []) if isinstance(c, dict)]
    written = [c for c in items if c.get("path") and not c.get("debug_screenshot")]
    ids = {c.get("capture_id") for c in written}
    t05 = {
        "result": "pass" if len(ids) >= MIN_LIVE_CAPTURES else "fail",
        "evidence": f"{len(ids)} live capture IDs",
    }
    readable = []
    for capture in written:
        size = capture.get("rendered_font_size_pt") or 0
        width, _, height = str(capture.get("source_resolution", "")).partition("x")
        readable.append(
            size >= MIN_RENDERED_FONT_PT
            and width.isdigit()
            and height.isdigit()
            and int(width) >= MIN_SOURCE_WIDTH
            and int(height) >= MIN_SOURCE_HEIGHT
        )
    t06 = {
        "result": "pass" if written and all(readable) else "fail",
        "evidence": ", ".join(
            f"{c.get('capture_id')}: {c.get('rendered_font_size_pt')} pt at "
            f"{c.get('source_resolution')}"
            for c in written
        )
        or "no written captures",
    }
    return t05, t06


def check_duration(minutes: float | None, contract: dict) -> dict:
    """Score T-07: the measured MP4 duration lands inside the contract."""
    if minutes is None:
        return {"result": "deferred", "evidence": "duration was not measured"}
    passed = contract["min"] <= minutes <= contract["max"]
    return {
        "result": "pass" if passed else "fail",
        "evidence": f"{minutes:.2f} min against {contract['min']:g} to "
        f"{contract['max']:g} min",
    }


def measure_minutes(mp4: Path) -> float | None:
    """Return the MP4 duration in minutes via ffprobe, or None."""
    if not mp4.is_file():
        return None
    try:
        result = subprocess.run(
            [
                ffprobe_command(),
                "-v",
                "error",
                "-show_entries",
                "format=duration",
                "-of",
                "csv=p=0",
                str(mp4),
            ],
            capture_output=True,
            text=True,
            check=False,
        )
    except OSError:
        return None
    try:
        return float(result.stdout.strip()) / 60
    except ValueError:
        return None


def word_count(content_dir: Path) -> int:
    """Return the number of words across all slide speaker notes."""
    import yaml

    total = 0
    for number in slide_numbers(content_dir):
        path = content_dir / f"slide-{number:03d}" / "content.yaml"
        data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        total += len(str(data.get("speaker_notes") or "").split())
    return total


def load_slides(content_dir: Path) -> list[tuple[int, dict]]:
    """Return ``(number, content)`` for every slide in order."""
    import yaml

    slides = []
    for number in slide_numbers(content_dir):
        path = content_dir / f"slide-{number:03d}" / "content.yaml"
        try:
            data = yaml.safe_load(checked_path(path, content_dir).read_text(encoding="utf-8"))
        except yaml.YAMLError as error:
            raise CheckError(f"Invalid slide YAML: {path}") from error
        if not isinstance(data, dict):
            raise CheckError(f"Slide content must be a mapping: {path}")
        if "slide_number" in data and (
            type(data["slide_number"]) is not int or data["slide_number"] != number
        ):
            raise CheckError(f"slide_number must match directory {path.parent.name}")
        if "id" in data and data["id"] != f"slide-{number}":
            raise CheckError(f"Slide id must be slide-{number}: {path}")
        slides.append((number, data))
    return slides


def notes_text(slide: dict) -> str:
    """Return a slide's speaker notes with whitespace collapsed."""
    return " ".join(str(slide.get("speaker_notes") or "").split())


def normalized_text(text: str) -> str:
    """Return ``text`` with whitespace collapsed and case folded, for comparison."""
    return " ".join(str(text).split()).casefold()


def on_screen_text(slide: dict) -> list[str]:
    """Return the text a slide shows, in element order, including image alt
    text, so a transcript can stand in for the visuals."""
    found: list[str] = []

    def walk(node, key=None):
        if isinstance(node, dict):
            if node.get("type") == "image":
                if node.get("alt") and not node.get("decorative"):
                    found.append(f"Image: {node['alt']}")
                return
            for name, value in node.items():
                if name in TEXT_KEYS and type(value) in (str, int, float):
                    found.append(str(value))
                elif isinstance(value, (dict, list)):
                    walk(value, name)
        elif isinstance(node, list):
            for item in node:
                if type(item) in (str, int, float) and key in TEXT_LIST_KEYS:
                    found.append(str(item))
                else:
                    walk(item, key)

    walk(slide.get("elements", []))
    unique: list[str] = []
    for text in (" ".join(t.split()) for t in found):
        if text and normalized_text(text) not in {normalized_text(u) for u in unique}:
            unique.append(text)
    return unique


def _wav_seconds(path: Path) -> float:
    with wave.open(str(path), "rb") as wav:
        return wav.getnframes() / wav.getframerate()


def _caption_chunks(sentence: str) -> list[str]:
    """Split a sentence into cues no longer than two caption lines."""
    chunks, current = [], ""
    for word in sentence.split():
        candidate = f"{current} {word}".strip()
        if current and len(candidate) > CAPTION_MAX_CHARS:
            chunks.append(current)
            current = word
        else:
            current = candidate
    if current:
        chunks.append(current)
    return chunks


def _caption_lines(text: str) -> str:
    """Break a cue into two lines at the word boundary nearest its middle."""
    if len(text) <= CAPTION_LINE_CHARS:
        return text
    spaces = [i for i, char in enumerate(text) if char == " "]
    split = min(spaces, key=lambda i: abs(i - len(text) / 2)) if spaces else len(text)
    return f"{text[:split]}\n{text[split + 1 :]}".rstrip()


def _timestamp(seconds: float) -> str:
    millis = round(seconds * 1000)
    hours, millis = divmod(millis, 3_600_000)
    minutes, millis = divmod(millis, 60_000)
    secs, millis = divmod(millis, 1000)
    return f"{hours:02d}:{minutes:02d}:{secs:02d}.{millis:03d}"


def transition_overlap(level_dir: Path, segment_count: int) -> float:
    """Return the scene overlap declared by ``output/segments.yml``."""
    import yaml

    manifest = level_dir / "output" / "segments.yml"
    if not manifest.is_file():
        return 0.0
    data = yaml.safe_load(manifest.read_text(encoding="utf-8")) or {}
    if not isinstance(data, dict):
        raise CheckError("segments.yml must contain a mapping")
    segments = data.get("segments") or []
    if not isinstance(segments, list) or len(segments) != segment_count:
        raise CheckError(
            "caption generation requires one authored content item per video segment"
        )
    slides = load_slides(level_dir / "content")
    for segment, (number, _) in zip(segments, slides, strict=True):
        canonical = (level_dir / "audio" / f"slide-{number:03d}.wav").resolve()
        if not isinstance(segment, dict) or not isinstance(
            segment.get("narration"), str
        ):
            raise CheckError(
                "Each caption segment requires its canonical narration path"
            )
        narration = (manifest.parent / segment["narration"]).resolve()
        if narration != canonical:
            raise CheckError("Caption segments must follow canonical slide/WAV order")
        if segment.get("duration") is not None:
            try:
                matches = (
                    abs(float(segment["duration"]) - _wav_seconds(canonical)) < 0.001
                )
            except (TypeError, ValueError) as error:
                raise CheckError("Invalid caption segment duration") from error
            if not matches:
                raise CheckError(
                    "Caption segments require full canonical WAV durations"
                )
    transition = data.get("transition")
    if transition in (None, "none"):
        return 0.0
    if not isinstance(transition, dict):
        raise CheckError("Caption transition must be a mapping or none")
    try:
        duration = float(transition.get("duration", 0.5))
    except (TypeError, ValueError) as exc:
        raise CheckError("segments.yml has an invalid transition duration") from exc
    if duration <= 0:
        raise CheckError("segments.yml transition duration must be positive")
    return duration


def build_captions(level_dir: Path) -> str:
    """Return WebVTT captions for the level's narration.

    Cues span each unpadded narration WAV, offset by the assembler's silent
    handles. Sentence lengths estimate within-slide timing; cue text is exact.
    """
    lines = ["WEBVTT", ""]
    offset = 0.0
    cues: list[tuple[float, float, str]] = []
    slides = load_slides(level_dir / "content")
    overlap = transition_overlap(level_dir, len(slides))
    transition = {}
    if overlap:
        import yaml

        transition = yaml.safe_load(
            (level_dir / "output/segments.yml").read_text(encoding="utf-8")
        )["transition"]
    for slide_index, (number, slide) in enumerate(slides):
        wav = level_dir / "audio" / f"slide-{number:03d}.wav"
        if not wav.is_file():
            raise CheckError(f"missing narration {wav}")
        duration = _wav_seconds(wav)
        chunks = [
            chunk
            for sentence in _SENTENCE_END.split(notes_text(slide))
            for chunk in _caption_chunks(sentence)
        ]
        total = sum(len(chunk) for chunk in chunks) or 1
        lead = overlap if slide_index > 0 or transition.get("fade_in", True) else 0.0
        tail = (
            overlap
            if slide_index < len(slides) - 1 or transition.get("fade_out", True)
            else 0.0
        )
        start = offset + lead
        for chunk in chunks:
            end = start + duration * len(chunk) / total
            cues.append((start, end, chunk))
            start = end
        offset += duration + lead + tail
        if slide_index < len(slides) - 1:
            offset -= overlap
    for index, (start, end, chunk) in enumerate(
        sorted(cues, key=lambda cue: cue[0]), 1
    ):
        lines += [
            str(index),
            f"{_timestamp(start)} --> {_timestamp(end)}",
            html.escape(_caption_lines(chunk), quote=False),
            "",
        ]
    return "\n".join(lines)


def style_metadata(level_dir: Path) -> dict:
    """Return the ``metadata`` mapping of the level's style file, or ``{}``."""
    import yaml

    style_file = checked_path(level_dir / "content" / "global" / "style.yaml", level_dir)
    if not style_file.is_file():
        return {}
    style = yaml.safe_load(style_file.read_text(encoding="utf-8")) or {}
    if not isinstance(style, dict) or not isinstance(style.get("metadata", {}), dict):
        raise CheckError("style.yaml and its metadata must be mappings")
    return style.get("metadata", {})


def validate_media_timeline(level_dir: Path, video: Path) -> None:
    """Reject raw assemblies whose duration differs from the canonical timeline."""
    import yaml

    slides = load_slides(level_dir / "content")
    if not slides:
        raise CheckError("Canonical timeline has no scenes")
    overlap = transition_overlap(level_dir, len(slides))
    expected = sum(
        _wav_seconds(level_dir / "audio" / f"slide-{number:03d}.wav")
        for number, _slide in slides
    )
    if overlap:
        data = yaml.safe_load(
            (level_dir / "output/segments.yml").read_text(encoding="utf-8")
        )
        transition = data["transition"]
        expected += overlap * (
            len(slides)
            - 1
            + int(transition.get("fade_in", True))
            + int(transition.get("fade_out", True))
        )
    minutes = measure_minutes(video)
    if minutes is None or abs(minutes * 60 - expected) > 0.15:
        raise CheckError(
            f"Raw assembly differs from canonical captions ({expected:.3f}s); "
            "reassemble with canonical WAV order, full durations, and silent handles"
        )


_PAGE_STYLE = (
    "body{font-family:system-ui,sans-serif;line-height:1.5;color:#1f2328;"
    "background:#fff;margin:0}main{max-width:60rem;margin:auto;padding:1.5rem}"
    "video{width:100%;height:auto;background:#000}a{color:#0969da}"
    "section{border-top:1px solid #d0d7de;padding-top:.5rem}"
)


def transcript_on_screen(slide: dict, title: str) -> list[str]:
    """Return the on-screen text a transcript lists for a slide, minus its title."""
    return [
        text
        for text in on_screen_text(slide)
        if normalized_text(text) != normalized_text(title)
    ]


def build_transcript_page(
    level: str,
    level_dir: Path,
    output_dir: Path | None = None,
    narration_engine: str = "azure",
) -> str:
    """Return an HTML page with a captioned player and a full transcript.

    The transcript lists every slide's title, on-screen text, and narration,
    so it serves as a text alternative for the video. All authored text is
    escaped, and the page loads nothing but its own media.
    """
    esc = html.escape
    metadata = style_metadata(level_dir)
    title = str(metadata.get("title") or f"HVE Core {level}")
    language = str(metadata.get("language") or "en-US")
    minutes = measure_minutes(
        (output_dir or level_dir / "output") / f"hve-demo-{level}.mp4"
    )
    length = f" &middot; {minutes:.1f} minutes" if minutes else ""
    stem = f"hve-demo-{level}"
    narration_notice = (
        "<p>Silent video: no voiceover. The transcript contains the authored notes.</p>"
        if narration_engine == "none"
        else ""
    )
    slides_link = f' &middot; <a href="{stem}.html">Open the slides (HTML)</a>'
    sections = []
    for number, slide in load_slides(level_dir / "content"):
        slide_title = str(slide.get("title") or f"Slide {number}")
        shown = transcript_on_screen(slide, slide_title)
        on_screen = (
            "<h4>On screen</h4><ul>"
            + "".join(f"<li>{esc(text)}</li>" for text in shown)
            + "</ul>"
            if shown
            else ""
        )
        sections.append(
            f'<section aria-labelledby="slide-{number}">'
            f'<h3 id="slide-{number}">Slide {number}: {esc(slide_title)}</h3>'
            f"{on_screen}<h4>Narration</h4><p>{esc(notes_text(slide))}</p></section>"
        )
    return (
        f'<!doctype html><html lang="{esc(language)}"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width,initial-scale=1">'
        '<meta http-equiv="Content-Security-Policy" content="default-src \'none\'; '
        "media-src 'self'; style-src 'unsafe-inline'; base-uri 'none'; "
        "form-action 'none'\">"
        f"<title>{esc(title)}: video and transcript</title>"
        f"<style>{_PAGE_STYLE}</style></head><body><main>"
        '<p><a href="../../docs/demo-material/">Back to Demo Material</a></p>'
        f"<h1>{esc(title)}</h1><p>{esc(level)}{length}</p>"
        f"{narration_notice}"
        f'<video controls preload="metadata"><source src="{stem}.mp4" type="video/mp4">'
        f'<track kind="captions" src="{stem}.vtt" srclang="{esc(language[:2])}" '
        'label="English"></video>'
        f'<p><a href="{stem}.mp4">Download the video (MP4)</a> &middot; '
        f'<a href="{stem}.vtt">Download the captions (WebVTT)</a>{slides_link}</p>'
        f"<h2>Transcript</h2>{''.join(sections)}</main></body></html>\n"
    )


class _DeckParser(HTMLParser):
    """Read static HTML slide identity, headings, alternatives and language."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.language = ""
        self.slides: list[dict] = []
        self.current: dict | None = None
        self.heading = False

    def handle_starttag(self, tag, attrs):
        attributes = dict(attrs)
        if tag == "html":
            self.language = attributes.get("lang") or ""
        if tag == "section" and str(attributes.get("id", "")).startswith("slide-"):
            self.current = {"id": attributes["id"], "title": attributes.get("data-title", ""), "heading": "", "images": []}
            self.slides.append(self.current)
        if self.current is not None:
            if tag in ("h1", "h2"):
                self.heading = True
            if tag == "img" or attributes.get("role") == "img":
                self.current["images"].append(attributes)

    def handle_endtag(self, tag):
        if tag == "section":
            self.current = None
        if tag in ("h1", "h2"):
            self.heading = False

    def handle_data(self, data):
        if self.current is not None and self.heading:
            self.current["heading"] += data


def deck_accessibility_problems(deck: Path, language: str | None) -> list[str]:
    """Return HTML slide title, image-alternative and document-language gaps."""
    parser = _DeckParser()
    parser.feed(checked_path(deck).read_text(encoding="utf-8"))
    problems = []
    if not parser.language:
        problems.append("document language is not set")
    elif language and parser.language != language:
        problems.append(f"document language is {parser.language}, expected {language}")
    if not parser.slides:
        problems.append("HTML deck contains no slides")
    for number, slide in enumerate(parser.slides, 1):
        if not slide["heading"].strip():
            problems.append(f"slide {number} has no title")
        elif normalized_text(slide["heading"]) != normalized_text(slide["title"]):
            problems.append(f"slide {number} title does not match its visible heading")
        for image in slide["images"]:
            alt = image.get("aria-label") or image.get("alt") or ""
            if image.get("aria-hidden") != "true" and (not alt.strip() or _IMAGE_FILE_NAME.search(alt)):
                problems.append(f"slide {number} image has no alternative text")
    return problems


_VTT_TIMING = re.compile(
    r"^(\d{2,}):([0-5]\d):([0-5]\d)\.(\d{3}) --> "
    r"(\d{2,}):([0-5]\d):([0-5]\d)\.(\d{3})(?:[ \t].*)?$"
)


def _vtt_seconds(hours: str, minutes: str, seconds: str, millis: str) -> float:
    return int(hours) * 3600 + int(minutes) * 60 + int(seconds) + int(millis) / 1000


def parse_webvtt(text: str) -> list[tuple[float, float, str]]:
    """Return ``(start, end, text)`` for every cue in a WebVTT file.

    Raises ``CheckError`` for a missing header, a malformed or reversed
    timing line, an empty cue, or cues that go back in time.
    """
    blocks = text.replace("\r\n", "\n").split("\n\n")
    if not blocks[0].startswith("WEBVTT"):
        raise CheckError("captions file lacks the WEBVTT header")
    cues: list[tuple[float, float, str]] = []
    for block in blocks[1:]:
        rows = [row for row in block.split("\n") if row.strip()]
        if not rows or rows[0].startswith(("NOTE", "STYLE", "REGION")):
            continue
        timing = 0 if "-->" in rows[0] else 1
        match = _VTT_TIMING.match(rows[timing].strip()) if timing < len(rows) else None
        if not match:
            raise CheckError(f"malformed caption timing near {rows[0]!r}")
        start = _vtt_seconds(*match.groups()[:4])
        end = _vtt_seconds(*match.groups()[4:])
        body = " ".join(rows[timing + 1 :]).strip()
        if end <= start or not body:
            raise CheckError(f"empty or zero-length caption cue at {rows[timing]}")
        if cues and start < cues[-1][0]:
            raise CheckError(f"caption cue at {rows[timing]} goes back in time")
        cues.append((start, end, html.unescape(body)))
    return cues


def subtitle_languages(mp4: Path) -> list[str] | None:
    """Return the language tag of every subtitle stream in ``mp4``.

    Returns ``None`` when ffprobe is unavailable or cannot read the file.
    """
    try:
        result = subprocess.run(
            [
                ffprobe_command(),
                "-v",
                "error",
                "-select_streams",
                "s",
                "-show_entries",
                "stream=index:stream_tags=language",
                "-of",
                "json",
                str(mp4),
            ],
            capture_output=True,
            text=True,
            check=False,
        )
    except OSError:
        return None
    if result.returncode != 0:
        return None
    try:
        streams = json.loads(result.stdout or "{}").get("streams") or []
    except json.JSONDecodeError:
        return None
    return [
        str((stream.get("tags") or {}).get("language", "und")) for stream in streams
    ]


def check_audio_mode(video: Path, narration_engine: str) -> dict:
    """Verify that silent delivery contains no audio stream, even a silent one."""
    try:
        result = subprocess.run(
            [
                ffprobe_command(),
                "-v",
                "error",
                "-select_streams",
                "a",
                "-show_entries",
                "stream=index",
                "-of",
                "json",
                str(video),
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode:
            raise CheckError(f"Cannot inspect audio streams: {result.stderr.strip()}")
        streams = json.loads(result.stdout)["streams"]
        if not isinstance(streams, list):
            raise CheckError("Invalid audio stream report from FFprobe")
    except (OSError, ValueError, KeyError, CheckError) as error:
        return {"result": "fail", "evidence": str(error)}
    expected_silence = narration_engine == "none"
    passed = not streams if expected_silence else bool(streams)
    return {
        "result": "pass" if passed else "fail",
        "evidence": (
            "no audio stream; voiceover disabled"
            if expected_silence and passed
            else "audio stream present"
            if passed
            else "silent delivery contains an audio stream"
            if expected_silence
            else "narrated delivery has no audio stream"
        ),
    }


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def jpeg_dimensions(data: bytes) -> tuple[int, int]:
    """Read JPEG frame dimensions without introducing an image dependency."""
    if not data.startswith(b"\xff\xd8"):
        raise CheckError("Frame is not a JPEG")
    position = 2
    while position < len(data):
        if data[position] != 0xFF:
            break
        while position < len(data) and data[position] == 0xFF:
            position += 1
        if position >= len(data):
            break
        marker = data[position]
        position += 1
        if marker in (0xD9, 0xDA):
            break
        if marker == 0x01 or 0xD0 <= marker <= 0xD7:
            continue
        if position + 2 > len(data):
            break
        length = int.from_bytes(data[position:position + 2], "big")
        if length < 2 or position + length > len(data):
            break
        if marker in {0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF} and length >= 8:
            height = int.from_bytes(data[position + 3:position + 5], "big")
            width = int.from_bytes(data[position + 5:position + 7], "big")
            if width and height:
                return width, height
            break
        position += length
    raise CheckError("JPEG frame dimensions are missing or malformed")


def content_digest(level_dir: Path) -> str:
    """Bind rendered evidence to all current content files without following links."""
    root = checked_path(level_dir / "content", level_dir)
    digest = hashlib.sha256()
    for candidate in sorted(root.rglob("*")):
        candidate = checked_path(candidate, root)
        if candidate.is_file():
            digest.update(candidate.relative_to(root).as_posix().encode("utf-8") + b"\0")
            digest.update(_sha256(candidate).encode("ascii") + b"\0")
    return digest.hexdigest()


def verify_open_captions(
    control: Path,
    finalized: Path,
    captions: Path,
    evidence: Path,
    source: Path | None = None,
) -> dict:
    """Compare captioned and uncaptioned encodes and write hash-bound evidence."""
    cues = parse_webvtt(captions.read_text(encoding="utf-8"))
    if not cues:
        raise CheckError("captions file has no cues")
    sample_seconds = (cues[0][0] + cues[0][1]) / 2
    result = subprocess.run(
        [
            ffmpeg_command(),
            "-v",
            "error",
            "-ss",
            f"{sample_seconds:.3f}",
            "-i",
            str(control),
            "-ss",
            f"{sample_seconds:.3f}",
            "-i",
            str(finalized),
            "-filter_complex",
            "[0:v][1:v]blend=all_mode=difference,"
            + "crop=iw:ih/3:0:2*ih/3,signalstats,bbox=min_val=16,"
            + "metadata=mode=print:file=-",
            "-frames:v",
            "1",
            "-f",
            "null",
            "-",
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        detail = (
            result.stderr.strip() or result.stdout.strip() or "no FFmpeg diagnostics"
        )
        raise CheckError(
            f"FFmpeg frame comparison failed (exit {result.returncode}) for "
            f"{control} and {finalized} at {sample_seconds:.3f}s: {detail}. "
            "Verify that both inputs decode and FFmpeg supports the comparison filters."
        )
    values = {
        line.rsplit(".", 1)[1].split("=", 1)[0]: int(line.rsplit("=", 1)[1])
        for line in result.stdout.splitlines()
        if line.startswith(
            ("lavfi.signalstats.YMAX=", "lavfi.bbox.w=", "lavfi.bbox.h=")
        )
    }
    box_area = values.get("w", 0) * values.get("h", 0)
    if (
        values.get("YMAX", 0) < MIN_OPEN_CAPTION_LUMA_DIFFERENCE
        or values.get("w", 0) < MIN_OPEN_CAPTION_BOX_DIMENSION
        or values.get("h", 0) < MIN_OPEN_CAPTION_BOX_DIMENSION
        or box_area < MIN_OPEN_CAPTION_BOX_AREA
    ):
        raise CheckError(
            "caption burn-in did not create a visible frame difference "
            f"(YMAX={values.get('YMAX', 0)}, box={values.get('w', 0)}x"
            f"{values.get('h', 0)})"
        )
    record = {
        "schema_version": 1,
        "result": "pass",
        "sample_seconds": round(sample_seconds, 3),
        "maximum_luma_difference": values["YMAX"],
        "difference_box_width": values["w"],
        "difference_box_height": values["h"],
        "difference_box_area": box_area,
        "control_video_sha256": _sha256(control),
        "source_video_sha256": _sha256(source or control),
        "video_sha256": _sha256(finalized),
        "captions_sha256": _sha256(captions),
    }
    evidence.parent.mkdir(parents=True, exist_ok=True)
    evidence.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    return record


def open_caption_evidence_problems(
    video: Path, captions: Path, evidence: Path, source: Path | None = None
) -> list[str]:
    """Return problems with hash-bound open-caption verification evidence."""
    if not evidence.is_file():
        return ["open-caption verification evidence missing"]
    try:
        record = json.loads(evidence.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return ["open-caption verification evidence is unreadable"]
    problems = []
    if record.get("result") != "pass":
        problems.append("open-caption verification did not pass")
    if record.get("maximum_luma_difference", 0) < MIN_OPEN_CAPTION_LUMA_DIFFERENCE:
        problems.append("open-caption frame difference is below the visibility floor")
    if (
        record.get("difference_box_width", 0) < MIN_OPEN_CAPTION_BOX_DIMENSION
        or record.get("difference_box_height", 0) < MIN_OPEN_CAPTION_BOX_DIMENSION
        or record.get("difference_box_area", 0) < MIN_OPEN_CAPTION_BOX_AREA
    ):
        problems.append("open-caption difference region is below the visibility floor")
    if not video.is_file() or record.get("video_sha256") != _sha256(video):
        problems.append("open-caption evidence does not match the delivered MP4")
    if not captions.is_file() or record.get("captions_sha256") != _sha256(captions):
        problems.append("open-caption evidence does not match the delivered WebVTT")
    if source is not None and (
        not source.is_file() or record.get("source_video_sha256") != _sha256(source)
    ):
        problems.append("open-caption evidence does not match the raw assembly")
    return problems


def publish_generation(level: str, stage: Path, output: Path) -> None:
    """Install a validated delivery, rolling back replacements on failure."""
    names = (
        f"hve-demo-{level}.mp4",
        f"hve-demo-{level}.vtt",
        "open-captions.json",
        "index.html",
    )
    if any(not (stage / name).is_file() for name in names):
        raise CheckError("Incomplete staged delivery; previous output was preserved")
    problems = open_caption_evidence_problems(
        stage / names[0], stage / names[1], stage / names[2]
    )
    if problems:
        raise CheckError("Invalid staged delivery: " + "; ".join(problems))
    installed: list[str] = []
    with tempfile.TemporaryDirectory(prefix=".delivery-backup-", dir=output) as backup:
        backup_dir = Path(backup)
        for name in names:
            if (output / name).exists():
                shutil.copy2(output / name, backup_dir / name)
        try:
            for name in names:
                os.replace(stage / name, output / name)
                installed.append(name)
        except (OSError, KeyboardInterrupt):
            for name in reversed(installed):
                saved = backup_dir / name
                if saved.exists():
                    os.replace(saved, output / name)
                else:
                    (output / name).unlink(missing_ok=True)
            raise


class _TranscriptParser(HTMLParser):
    """Collect the captions tracks and per-slide sections of a transcript page."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.tracks: list[dict] = []
        self.sections: list[dict] = []
        self._section: dict | None = None
        self._field: str | None = None
        self._subhead = ""
        self._part = ""

    def handle_starttag(self, tag, attrs):
        attributes = dict(attrs)
        if tag == "track":
            self.tracks.append(attributes)
        elif tag == "section":
            self._section = {"heading": "", "on_screen": [], "narration": ""}
            self.sections.append(self._section)
            self._part = ""
        elif self._section is not None:
            if tag == "h3":
                self._field = "heading"
            elif tag == "h4":
                self._field, self._subhead = "subhead", ""
            elif tag == "li" and self._part == "on screen":
                self._field = "item"
                self._section["on_screen"].append("")
            elif tag == "p" and self._part == "narration":
                self._field = "narration"

    def handle_endtag(self, tag):
        if tag == "section":
            self._section = None
        if tag == "h4":
            self._part = normalized_text(self._subhead)
        if tag in ("h3", "h4", "li", "p"):
            self._field = None

    def handle_data(self, data):
        if self._section is None or self._field is None:
            return
        if self._field == "subhead":
            self._subhead += data
        elif self._field == "item":
            self._section["on_screen"][-1] += data
        else:
            self._section[self._field] += data


def transcript_problems(level_dir: Path, page: str) -> list[str]:
    """Return what the transcript page lacks against the level's slides."""
    parser = _TranscriptParser()
    parser.feed(page)
    problems = []
    if not any(track.get("kind") == "captions" for track in parser.tracks):
        problems.append("transcript page has no captions track")
    slides = load_slides(level_dir / "content")
    if len(parser.sections) != len(slides):
        problems.append(
            f"transcript has {len(parser.sections)} sections for {len(slides)} slides"
        )
    for (number, slide), section in zip(slides, parser.sections):
        title = str(slide.get("title") or f"Slide {number}")
        expected = {
            "title": normalized_text(f"Slide {number}: {title}"),
            "on-screen text": [
                normalized_text(text) for text in transcript_on_screen(slide, title)
            ],
            "narration": normalized_text(notes_text(slide)),
        }
        found = {
            "title": normalized_text(section["heading"]),
            "on-screen text": [normalized_text(text) for text in section["on_screen"]],
            "narration": normalized_text(section["narration"]),
        }
        problems += [
            f"transcript slide {number} {name} does not match the deck"
            for name in expected
            if expected[name] != found[name]
        ]
    return problems


def check_accessibility(level: str, level_dir: Path) -> dict:
    """Score T-09: delivered captions, a complete transcript, and an
    accessible deck."""
    output = level_dir / "output"
    problems = []
    captions = output / f"hve-demo-{level}.vtt"
    if not captions.is_file():
        problems.append("captions file missing")
    else:
        try:
            cues = parse_webvtt(captions.read_text(encoding="utf-8"))
            expected_cues = parse_webvtt(build_captions(level_dir))
        except CheckError as error:
            problems.append(str(error))
        else:
            expected = normalized_text(" ".join(cue[2] for cue in expected_cues))
            if normalized_text(" ".join(cue[2] for cue in cues)) != expected:
                problems.append("caption text does not match the narration")
    video = output / f"hve-demo-{level}.mp4"
    if not video.is_file():
        problems.append("video missing")
    else:
        problems += open_caption_evidence_problems(
            video, captions, output / "open-captions.json"
        )
        languages = subtitle_languages(video)
        if languages is None:
            problems.append("could not read the MP4 streams")
        elif not {"eng", "en"} & set(languages):
            problems.append("MP4 has no English subtitle stream")
    page = output / "index.html"
    if not page.is_file():
        problems.append("transcript page missing")
    else:
        problems += transcript_problems(level_dir, page.read_text(encoding="utf-8"))
    deck = output / f"hve-demo-{level}.html"
    if deck.is_file():
        language = style_metadata(level_dir).get("language")
        problems += deck_accessibility_problems(deck, language)
        parsed = _DeckParser()
        parsed.feed(deck.read_text(encoding="utf-8"))
        expected = [(f"slide-{n}", normalized_text(slide.get("title", ""))) for n, slide in load_slides(level_dir / "content")]
        if [(slide["id"], normalized_text(slide["title"])) for slide in parsed.slides] != expected:
            problems.append("HTML slide IDs/titles do not match canonical content order")
    else:
        problems.append("deck missing")
    return {
        "result": "fail" if problems else "pass",
        "evidence": "; ".join(problems)
        or "open captions, an English selectable caption track, captions matching "
        "the narration, a transcript covering every slide, slide titles, alt text, "
        "and language present",
    }


def check_html_deck(level: str, level_dir: Path) -> dict:
    """Score T-10: a single-file HTML deck that starts offline and fits."""
    output = checked_path(level_dir / "output", level_dir)
    problems = []
    deck = checked_path(output / f"hve-demo-{level}.html", output)
    slide_ids = [f"slide-{n}" for n in slide_numbers(level_dir / "content")]
    slides = len(slide_ids)
    if not deck.is_file():
        problems.append("HTML deck missing")
    else:
        page = deck.read_text(encoding="utf-8")
        if page.count('id="hve-slide-metadata"') != 1:
            problems.append("slide catalog metadata missing")
        if page.count('<section id="slide-') != slides:
            problems.append(f"HTML deck does not hold all {slides} slides")
        if re.search(r'<link rel="stylesheet"|<script defer src=', page):
            problems.append("HTML deck still references sibling files")
    build = checked_path(output / "html-deck-build.json", output)
    if build.is_file():
        record = json.loads(build.read_text(encoding="utf-8"))
        if not isinstance(record, dict):
            record = {}
        problems += [f"image not embedded: {path}" for path in record.get("missing_images", [])]
        if record.get("schema_version") != 2 or record.get("renderer") != "hve-slides" or record.get("format") != "html":
            problems.append("incompatible HTML build evidence")
        if record.get("slide_ids") != slide_ids or record.get("content_sha256") != content_digest(level_dir):
            problems.append("HTML build evidence does not match current content")
    else:
        problems.append("HTML build evidence missing")
    browser = checked_path(output / "html-deck-check.json", output)
    if not browser.is_file():
        problems.append("offline browser check not run")
    else:
        result = json.loads(browser.read_text(encoding="utf-8"))
        if not isinstance(result, dict):
            result = {}
        if result.get("schema_version") != 2 or result.get("renderer") != "hve-slides" or result.get("format") != "html":
            problems.append("incompatible offline browser evidence")
        if not deck.is_file() or result.get("html_sha256") != _sha256(deck):
            problems.append("offline evidence does not match delivered HTML")
        if not slide_ids or result.get("slide_ids") != slide_ids:
            problems.append("offline evidence has missing or mismatched slide IDs")
        if build.is_file() and result.get("build_sha256") != _sha256(build):
            problems.append("offline evidence does not match HTML build evidence")
        if any(result.get(key) for key in ("overflowing_slides", "errors", "external_requests")):
            problems.append("offline evidence contains unresolved browser findings")
        frames = result.get("frames")
        if not isinstance(frames, list) or len(frames) != len(slide_ids):
            problems.append("ordered frame evidence missing or incomplete")
        else:
            for slide_id, frame in zip(slide_ids, frames, strict=True):
                try:
                    if not isinstance(frame, dict) or frame.get("slide_id") != slide_id or not isinstance(frame.get("path"), str):
                        raise CheckError(f"frame identity mismatch for {slide_id}")
                    path = checked_path(level_dir / frame["path"], level_dir / "frames")
                    name = f"slide-{int(slide_id.removeprefix('slide-')):03d}.jpg"
                    if path.name != name or frame.get("sha256") != _sha256(path):
                        raise CheckError(f"frame hash/path mismatch for {slide_id}")
                    if (frame.get("width"), frame.get("height")) != (1920, 1080) or jpeg_dimensions(path.read_bytes()) != (1920, 1080):
                        raise CheckError(f"frame dimensions mismatch for {slide_id}")
                except (CheckError, OSError) as error:
                    problems.append(str(error))
        if result.get("result") != "pass":
            detail = (
                result.get("overflowing_slides")
                or result.get("errors")
                or result.get("external_requests")
            )
            problems.append(f"offline browser check failed: {detail}")
    return {
        "result": "fail" if problems else "pass",
        "evidence": "; ".join(problems)
        or "single-file deck with every slide, started offline, no slide overflows",
    }


def default_capture_profile(level: str) -> str:
    """Return the curriculum's default capture profile for ``level``."""
    return "live" if level in LIVE_LEVELS else "deck-export"


def evaluate(
    level: str,
    level_dir: Path,
    curriculum: dict[str, dict],
    capture_profile: str | None = None,
    narration_engine: str = "azure",
    slides_skill_root: Path | None = None,
) -> dict:
    """Score the machine-verifiable criteria for one rendered level.

    HTML is mandatory; missing renderer or browser evidence never opts out.
    """
    if level not in curriculum:
        raise CheckError(f"unknown level {level}")
    contract = curriculum[level]
    profile = capture_profile or default_capture_profile(level)
    live = level in LIVE_LEVELS and profile == "live"
    captures_file = level_dir / "output" / "captures.json"
    captures = (
        json.loads(captures_file.read_text(encoding="utf-8"))
        if captures_file.is_file()
        else None
    )
    minutes = measure_minutes(level_dir / "output" / f"hve-demo-{level}.mp4")
    checks = {"T-04": check_segments(level_dir)}
    if live:
        checks["T-05"], checks["T-06"] = check_captures(captures)
    checks["T-07"] = check_duration(minutes, contract)
    deck = checked_path(level_dir / "output" / f"hve-demo-{level}.html", level_dir)
    if slides_skill_root is None:
        checks["T-08"] = {"result": "deferred", "evidence": "resolved hve-slides root missing"}
    else:
        template = checked_path(slides_skill_root / "templates/deck")
        try:
            checks["T-08"] = check_style(
                deck.read_text(encoding="utf-8"),
                checked_path(template / "theme.css", template).read_text(encoding="utf-8"),
                checked_path(template / "components.css", template).read_text(encoding="utf-8"),
            )
        except OSError as error:
            checks["T-08"] = {"result": "deferred", "evidence": str(error)}
    checks["T-09"] = check_accessibility(level, level_dir)
    if narration_engine == "none":
        checks["T-11"] = check_audio_mode(
            level_dir / "output" / f"hve-demo-{level}.mp4", narration_engine
        )
        checks["T-04"]["evidence"] += "; WAVs provide silent timing, not narration"
    checks["T-10"] = check_html_deck(level, level_dir)
    import yaml

    manifest_path = checked_path(level_dir / "manifest.yml", level_dir)
    if not manifest_path.is_file():
        manifest_path = checked_path(level_dir / "output/manifest.yml", level_dir)
    manifest = yaml.safe_load(manifest_path.read_text(encoding="utf-8")) if manifest_path.is_file() else {}
    expected_outputs = {
        "html_deck": f"output/hve-demo-{level}.html",
        "mp4": f"output/hve-demo-{level}.mp4",
        "raw_assembly": f"output/hve-demo-{level}.raw.mp4",
        "captions": f"output/hve-demo-{level}.vtt", "transcript_page": "output/index.html",
        "open_caption_evidence": "output/open-captions.json",
        "html_build_evidence": "output/html-deck-build.json",
        "html_frame_evidence": "output/html-deck-check.json",
        "render_result": "output/render-result.json",
    }
    deliverables = manifest.get("deliverables", {}) if isinstance(manifest, dict) else {}
    manifest_valid = (
        isinstance(manifest, dict) and manifest.get("schema_version") == 6
        and manifest.get("renderer") == "hve-slides" and manifest.get("format") == "html"
        and manifest.get("level") == level and isinstance(deliverables, dict)
        and deliverables == expected_outputs
    )
    result = {
        "schema_version": 2,
        "renderer": "hve-slides",
        "format": "html",
        "manifest_schema_version": 6 if manifest_valid else None,
        "manifest_valid": manifest_valid,
        "level": level,
        "capture_profile": "live" if live else "deck-export",
        "narration_engine": narration_engine,
        "timing_basis": "notes-word-count"
        if narration_engine == "none"
        else "speech-wav",
        "total_word_count": word_count(level_dir / "content"),
        "measured_duration_minutes": round(minutes, 2) if minutes else None,
        "contract_duration_minutes": {"min": contract["min"], "max": contract["max"]},
        "checks": checks,
        "ok": manifest_valid and all(check["result"] == "pass" for check in checks.values()),
    }
    if manifest_valid:
        validation = manifest.setdefault("validation", {})
        if not isinstance(validation, dict):
            raise CheckError("manifest.validation must be a mapping")
        validation["machine_checks"] = checks
        validation["deck"] = "deferred" if all(checks[key]["result"] == "pass" for key in ("T-08", "T-09", "T-10")) else "fail"
        validation["video"] = "pass" if result["ok"] else "fail"
        # Machine scoring does not grant human delivery approval or visual review.
        manifest["state"] = "Deferred"
        install_files(level_dir / "output", {"manifest.yml": yaml.safe_dump(manifest, sort_keys=False).encode("utf-8")})
        result["manifest_sha256"] = _sha256(level_dir / "output/manifest.yml")
    return result


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("levels", help="Print level contracts and pinned sources")
    changed = sub.add_parser("changed", help="Print levels that need a new run")
    changed.add_argument("--index", type=Path, help="Previous bundle index.json")
    changed.add_argument("--repo", type=Path, default=Path("."))
    changed.add_argument("--force", action="store_true")
    segments = sub.add_parser("segments", help="Write output/segments.yml")
    segments.add_argument("--level-dir", type=Path, required=True)
    segments.add_argument("--output-name", required=True)
    silent_timing = sub.add_parser(
        "silent-timing", help="Write silent timing WAVs without speech synthesis"
    )
    silent_timing.add_argument("--level-dir", type=Path, required=True)
    preflight = sub.add_parser(
        "scripted-preflight", help="Reject unsupported deck-frame render inputs"
    )
    preflight.add_argument("--level", required=True, choices=LEVELS)
    preflight.add_argument("--level-dir", type=Path, required=True)
    preflight.add_argument("--capture", required=True, choices=("live", "deck-export"))
    preflight.add_argument(
        "--animation", choices=("none", "characters"), default="none"
    )
    preflight.add_argument("--slides-skill-root", type=Path)
    captions = sub.add_parser("captions", help="Write WebVTT captions")
    captions.add_argument("--level-dir", type=Path, required=True)
    captions.add_argument("--output", type=Path, required=True)
    transcript = sub.add_parser("transcript", help="Write output/index.html")
    transcript.add_argument("--level", required=True, choices=LEVELS)
    transcript.add_argument("--level-dir", type=Path, required=True)
    transcript.add_argument("--output-dir", type=Path)
    transcript.add_argument("--narration", choices=("azure", "none"), default="azure")
    audio_check = sub.add_parser("check-audio-mode", help="Verify delivery audio mode")
    audio_check.add_argument("--video", type=Path, required=True)
    audio_check.add_argument("--narration", choices=("azure", "none"), required=True)
    publish = sub.add_parser("publish-generation", help="Install a staged delivery")
    publish.add_argument("--level", required=True, choices=LEVELS)
    publish.add_argument("--stage", type=Path, required=True)
    publish.add_argument("--output-dir", type=Path, required=True)
    verify_captions = sub.add_parser(
        "verify-open-captions", help="Verify caption burn-in and write evidence"
    )
    verify_captions.add_argument("--control", type=Path, required=True)
    verify_captions.add_argument("--finalized", type=Path, required=True)
    verify_captions.add_argument("--captions", type=Path, required=True)
    verify_captions.add_argument("--output", type=Path, required=True)
    verify_captions.add_argument("--source", type=Path)
    verify_captions.add_argument("--level-dir", type=Path)
    caption_status = sub.add_parser(
        "check-open-caption-evidence", help="Check existing caption evidence"
    )
    caption_status.add_argument("--video", type=Path, required=True)
    caption_status.add_argument("--captions", type=Path, required=True)
    caption_status.add_argument("--evidence", type=Path, required=True)
    caption_status.add_argument("--source", type=Path)
    evaluate_cmd = sub.add_parser("evaluate", help="Score a rendered level")
    evaluate_cmd.add_argument("--level", required=True, choices=LEVELS)
    evaluate_cmd.add_argument("--level-dir", type=Path, required=True)
    evaluate_cmd.add_argument("--capture", choices=("live", "deck-export"))
    evaluate_cmd.add_argument("--narration", choices=("azure", "none"), default="azure")
    evaluate_cmd.add_argument(
        "--slides-skill-root", type=Path, help="Resolved trusted hve-slides installation for T-08"
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        if args.command == "levels":
            print(json.dumps(load_curriculum(), indent=2))
            return EXIT_SUCCESS
        if args.command == "changed":
            index = {}
            if args.index and args.index.is_file():
                index = json.loads(args.index.read_text(encoding="utf-8"))
            print(
                " ".join(
                    changed_levels(load_curriculum(), index, args.repo, args.force)
                )
            )
            return EXIT_SUCCESS
        if args.command == "scripted-preflight":
            validate_scripted_render(
                args.level, args.level_dir, args.capture, args.animation, args.slides_skill_root
            )
            return EXIT_SUCCESS
        if args.command == "silent-timing":
            build_silent_timing(args.level_dir)
            return EXIT_SUCCESS
        if args.command == "segments":
            target = args.level_dir / "output" / "segments.yml"
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(
                build_segments(args.level_dir, args.output_name), encoding="utf-8"
            )
            return EXIT_SUCCESS
        if args.command == "captions":
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(build_captions(args.level_dir), encoding="utf-8")
            return EXIT_SUCCESS
        if args.command == "transcript":
            target = (args.output_dir or args.level_dir / "output") / "index.html"
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(
                build_transcript_page(
                    args.level, args.level_dir, args.output_dir, args.narration
                ),
                encoding="utf-8",
            )
            return EXIT_SUCCESS
        if args.command == "check-audio-mode":
            result = check_audio_mode(args.video, args.narration)
            print(json.dumps(result))
            return EXIT_SUCCESS if result["result"] == "pass" else EXIT_FAILURE
        if args.command == "publish-generation":
            publish_generation(args.level, args.stage, args.output_dir)
            return EXIT_SUCCESS
        if args.command == "verify-open-captions":
            if args.level_dir:
                validate_media_timeline(args.level_dir, args.source or args.control)
            result = verify_open_captions(
                args.control, args.finalized, args.captions, args.output, args.source
            )
            print(json.dumps(result, indent=2))
            return EXIT_SUCCESS
        if args.command == "check-open-caption-evidence":
            problems = open_caption_evidence_problems(
                args.video, args.captions, args.evidence, args.source
            )
            print(json.dumps({"ok": not problems, "problems": problems}, indent=2))
            return EXIT_FAILURE if problems else EXIT_SUCCESS
        result = evaluate(
            args.level,
            args.level_dir,
            load_curriculum(),
            capture_profile=args.capture,
            narration_engine=args.narration,
            slides_skill_root=args.slides_skill_root,
        )
        print(json.dumps(result, indent=2))
        return EXIT_SUCCESS if result["ok"] else EXIT_FAILURE
    except (
        CheckError,
        OSError,
        json.JSONDecodeError,
        wave.Error,
    ) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return EXIT_FAILURE


if __name__ == "__main__":
    sys.exit(main())
