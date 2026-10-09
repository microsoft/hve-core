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
    python render_checks.py evaluate --level L100 --level-dir DIR [--html-deck]

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
import subprocess
import sys
import tempfile
import wave
import xml.etree.ElementTree as ET
import zipfile
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
    ".github/agents/experimental/hve-demo-material.agent.md",
    "docs/getting-started/tts-voiceover.md",
)

SUBSTITUTABLE_STYLE_FIELDS = (
    ("metadata", "title"),
    ("metadata", "subject"),
    ("metadata", "keywords"),
    ("themes", 0, "slides"),
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


TEXT_KEYS = ("text", "title", "subtitle", "label", "heading", "description")
TEXT_LIST_KEYS = ("bullets", "items", "segments", "paragraphs", "rows", "cells")

_NS = {
    "p": "http://schemas.openxmlformats.org/presentationml/2006/main",
    "a": "http://schemas.openxmlformats.org/drawingml/2006/main",
    "dc": "http://purl.org/dc/elements/1.1/",
    "adec": "http://schemas.microsoft.com/office/drawing/2017/decorative",
}
_IMAGE_FILE_NAME = re.compile(r"\.(png|jpe?g|gif|bmp|svg|webp)$", re.IGNORECASE)
_SENTENCE_END = re.compile(r"(?<=[.!?])\s+")
MIN_SOURCE_WIDTH = 1920
MIN_SOURCE_HEIGHT = 1080

_HEX_COLOUR = re.compile(r"#[0-9A-Fa-f]{6}\b")
_DURATION = re.compile(r"(\d+(?:\.\d+)?)\s+to\s+(\d+(?:\.\d+)?)\s+minutes")
_BACKTICK_PATH = re.compile(r"`([^`]+)`")
_SLIDE_DIR = re.compile(r"^slide-(\d{3})$")


class CheckError(ValueError):
    """Raised when inputs are missing or malformed."""


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
    recorded = index.get("levels", {}) if isinstance(index, dict) else {}
    selected = []
    for level in LEVELS:
        entry = recorded.get(level) if isinstance(recorded, dict) else None
        base = entry.get("source_sha") if isinstance(entry, dict) else None
        if (
            force
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
    numbers = []
    for child in content_dir.iterdir() if content_dir.is_dir() else ():
        match = _SLIDE_DIR.match(child.name)
        if match and (child / "content.yaml").is_file():
            numbers.append(int(match.group(1)))
    return sorted(numbers)


def validate_scripted_render(
    level: str, level_dir: Path, capture: str, animation: str = "none"
) -> None:
    """Reject inputs that the deck-frame scripted renderer cannot preserve."""
    import yaml

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


def _get(data, path):
    for key in path:
        if isinstance(key, int):
            if not isinstance(data, list) or len(data) <= key:
                return None
        elif not isinstance(data, dict):
            return None
        data = data[key] if isinstance(key, int) else data.get(key)
    return data


def _strip(data, path):
    """Remove the value at ``path`` in place when present."""
    parent = _get(data, path[:-1])
    key = path[-1]
    if isinstance(parent, dict):
        parent.pop(key, None)


def check_style(
    style_text: str, template_text: str, content: dict[str, str] | None = None
) -> dict:
    """Score T-08: fixed style fields match the template, and every colour in
    the style file and in each slide's ``content.yaml`` is in the pinned
    palette."""
    import yaml

    palette = {colour.upper() for colour in _HEX_COLOUR.findall(template_text)}
    outside = sorted({c.upper() for c in _HEX_COLOUR.findall(style_text)} - palette)
    content_outside = {
        name: sorted({c.upper() for c in _HEX_COLOUR.findall(text)} - palette)
        for name, text in sorted((content or {}).items())
    }
    content_outside = {name: found for name, found in content_outside.items() if found}
    style = yaml.safe_load(style_text)
    template = yaml.safe_load(template_text)
    for path in SUBSTITUTABLE_STYLE_FIELDS:
        _strip(style, path)
        _strip(template, path)
    fixed_match = style == template
    passed = fixed_match and not outside and not content_outside
    evidence = []
    if not fixed_match:
        evidence.append("a fixed field differs from templates/style.yaml")
    if outside:
        evidence.append(f"colours outside the pinned palette: {', '.join(outside)}")
    for name, found in content_outside.items():
        evidence.append(f"{name} uses colours outside the palette: {', '.join(found)}")
    return {
        "result": "pass" if passed else "fail",
        "evidence": "; ".join(evidence) or "fixed fields and palette match",
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
        data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        slides.append((number, data if isinstance(data, dict) else {}))
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
                if name in TEXT_KEYS and isinstance(value, str):
                    found.append(value)
                elif isinstance(value, (dict, list)):
                    walk(value, name)
        elif isinstance(node, list):
            for item in node:
                if isinstance(item, str) and key in TEXT_LIST_KEYS:
                    found.append(item)
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

    style_file = level_dir / "content" / "global" / "style.yaml"
    if not style_file.is_file():
        return {}
    style = yaml.safe_load(style_file.read_text(encoding="utf-8")) or {}
    metadata = style.get("metadata") if isinstance(style, dict) else None
    return metadata if isinstance(metadata, dict) else {}


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
    slides_link = (
        f' &middot; <a href="{stem}.html">Open the slides (HTML)</a>'
        if (level_dir / "output" / f"{stem}.html").is_file()
        else ""
    )
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
        f'<a href="{stem}.pptx">Download the deck (PowerPoint)</a> &middot; '
        f'<a href="{stem}.vtt">Download the captions (WebVTT)</a>{slides_link}</p>'
        f"<h2>Transcript</h2>{''.join(sections)}</main></body></html>\n"
    )


def deck_accessibility_problems(pptx: Path, language: str | None) -> list[str]:
    """Return the deck's missing slide titles, alt text, and language."""
    problems = []
    with zipfile.ZipFile(pptx) as archive:
        names = archive.namelist()
        declared = None
        if "docProps/core.xml" in names:
            core = ET.fromstring(archive.read("docProps/core.xml"))
            declared = core.findtext("dc:language", namespaces=_NS)
        if not declared:
            problems.append("document language is not set")
        elif language and declared != language:
            problems.append(f"document language is {declared}, expected {language}")
        slides = sorted(
            (int(match.group(1)), name)
            for name in names
            if (match := re.fullmatch(r"ppt/slides/slide(\d+)\.xml", name))
        )
        for number, name in slides:
            root = ET.fromstring(archive.read(name))
            titled = any(
                (ph := sp.find("p:nvSpPr/p:nvPr/p:ph", _NS)) is not None
                and ph.get("type") in ("title", "ctrTitle")
                and "".join(t.text or "" for t in sp.iter(f"{{{_NS['a']}}}t")).strip()
                for sp in root.iter(f"{{{_NS['p']}}}sp")
            )
            if not titled:
                problems.append(f"slide {number} has no title")
            for pic in root.iter(f"{{{_NS['p']}}}pic"):
                c_nv_pr = pic.find("p:nvPicPr/p:cNvPr", _NS)
                if c_nv_pr is None:
                    continue
                descr = (c_nv_pr.get("descr") or "").strip()
                decorative = c_nv_pr.find(".//adec:decorative", _NS) is not None
                if not decorative and (not descr or _IMAGE_FILE_NAME.search(descr)):
                    problems.append(
                        f"slide {number} image {c_nv_pr.get('name')!r} has no "
                        "alternative text"
                    )
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
    deck = output / f"hve-demo-{level}.pptx"
    if deck.is_file():
        language = style_metadata(level_dir).get("language")
        problems += deck_accessibility_problems(deck, language)
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
    output = level_dir / "output"
    problems = []
    deck = output / f"hve-demo-{level}.html"
    slides = len(slide_numbers(level_dir / "content"))
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
    build = output / "html-deck-build.json"
    if build.is_file():
        missing = json.loads(build.read_text(encoding="utf-8")).get("missing_images")
        problems += [f"image not embedded: {path}" for path in missing or []]
    browser = output / "html-deck-check.json"
    if not browser.is_file():
        problems.append("offline browser check not run")
    else:
        result = json.loads(browser.read_text(encoding="utf-8"))
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
    html_deck: bool = False,
) -> dict:
    """Score the machine-verifiable criteria for one rendered level.

    ``html_deck`` adds T-10 when the render built the HTML slide deck.
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
    style_file = level_dir / "content" / "global" / "style.yaml"
    minutes = measure_minutes(level_dir / "output" / f"hve-demo-{level}.mp4")
    checks = {"T-04": check_segments(level_dir)}
    if live:
        checks["T-05"], checks["T-06"] = check_captures(captures)
    checks["T-07"] = check_duration(minutes, contract)
    content = {
        f"slide-{number:03d}": (
            level_dir / "content" / f"slide-{number:03d}" / "content.yaml"
        ).read_text(encoding="utf-8")
        for number in slide_numbers(level_dir / "content")
    }
    checks["T-08"] = (
        check_style(
            style_file.read_text(encoding="utf-8"),
            STYLE_TEMPLATE.read_text(encoding="utf-8"),
            content,
        )
        if style_file.is_file()
        else {"result": "deferred", "evidence": "content/global/style.yaml missing"}
    )
    checks["T-09"] = check_accessibility(level, level_dir)
    if narration_engine == "none":
        checks["T-11"] = check_audio_mode(
            level_dir / "output" / f"hve-demo-{level}.mp4", narration_engine
        )
        checks["T-04"]["evidence"] += "; WAVs provide silent timing, not narration"
    if html_deck:
        checks["T-10"] = check_html_deck(level, level_dir)
    return {
        "schema_version": 1,
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
        "ok": all(check["result"] == "pass" for check in checks.values()),
    }


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
    captions = sub.add_parser("captions", help="Write WebVTT captions")
    captions.add_argument("--level-dir", type=Path, required=True)
    captions.add_argument("--output", type=Path, required=True)
    transcript = sub.add_parser("transcript", help="Write output/index.html")
    transcript.add_argument("--level", required=True, choices=LEVELS)
    transcript.add_argument("--level-dir", type=Path, required=True)
    transcript.add_argument("--output-dir", type=Path)
    transcript.add_argument(
        "--narration", choices=("azure", "piper", "none"), default="azure"
    )
    audio_check = sub.add_parser("check-audio-mode", help="Verify delivery audio mode")
    audio_check.add_argument("--video", type=Path, required=True)
    audio_check.add_argument(
        "--narration", choices=("azure", "piper", "none"), required=True
    )
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
    evaluate_cmd.add_argument(
        "--narration", choices=("azure", "piper", "none"), default="azure"
    )
    evaluate_cmd.add_argument(
        "--html-deck", action="store_true", help="Score T-10 for the HTML deck"
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
                args.level, args.level_dir, args.capture, args.animation
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
            html_deck=args.html_deck,
        )
        print(json.dumps(result, indent=2))
        return EXIT_SUCCESS if result["ok"] else EXIT_FAILURE
    except (
        CheckError,
        OSError,
        json.JSONDecodeError,
        wave.Error,
        zipfile.BadZipFile,
    ) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return EXIT_FAILURE


if __name__ == "__main__":
    sys.exit(main())
