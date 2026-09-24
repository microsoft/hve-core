#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Deterministic checks for rendering HVE demo material outside an agent.

Reads the level contracts and pinned sources from ``references/curriculum.md``
so CI and the agent share one policy source, decides which levels need a new
run, writes the ``demo-video`` segments manifest, generates captions and an
accessible transcript page, and scores the criteria a machine can verify
(T-04 through T-09).

Usage::

    python render_checks.py levels
    python render_checks.py changed --index index.json --repo . [--force]
    python render_checks.py segments --level-dir DIR --output-name x.mp4
    python render_checks.py captions --level-dir DIR --output DIR/output/x.vtt
    python render_checks.py transcript --level L100 --level-dir DIR
    python render_checks.py evaluate --level L100 --level-dir DIR

``levels`` and ``changed`` use only the standard library so a runner can call
them before any environment is synced.

Exit codes:
    0 - success; for ``evaluate``, every applicable check passed
    1 - a check failed or the inputs were invalid
"""

from __future__ import annotations

import argparse
import html
import json
import re
import subprocess
import sys
import wave
import xml.etree.ElementTree as ET
import zipfile
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
    result = subprocess.run(
        [
            "ffprobe",
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


def _normalized(text: str) -> str:
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
        if text and _normalized(text) not in {_normalized(u) for u in unique}:
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


def build_captions(level_dir: Path) -> str:
    """Return WebVTT captions for the level's narration.

    Each slide's cues span exactly that slide's narration WAV, which is how
    ``demo-video`` sizes a segment. Within a slide, time is shared across
    sentences by length, so cue text is exact and cue timing is estimated.
    """
    lines = ["WEBVTT", ""]
    offset = 0.0
    index = 1
    for number, slide in load_slides(level_dir / "content"):
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
        start = offset
        for chunk in chunks:
            end = start + duration * len(chunk) / total
            lines += [
                str(index),
                f"{_timestamp(start)} --> {_timestamp(end)}",
                html.escape(_caption_lines(chunk), quote=False),
                "",
            ]
            index += 1
            start = end
        offset += duration
    return "\n".join(lines)


def _style_metadata(level_dir: Path) -> dict:
    import yaml

    style_file = level_dir / "content" / "global" / "style.yaml"
    if not style_file.is_file():
        return {}
    style = yaml.safe_load(style_file.read_text(encoding="utf-8")) or {}
    metadata = style.get("metadata") if isinstance(style, dict) else None
    return metadata if isinstance(metadata, dict) else {}


_PAGE_STYLE = (
    "body{font-family:system-ui,sans-serif;line-height:1.5;color:#1f2328;"
    "background:#fff;margin:0}main{max-width:60rem;margin:auto;padding:1.5rem}"
    "video{width:100%;height:auto;background:#000}a{color:#0969da}"
    "section{border-top:1px solid #d0d7de;padding-top:.5rem}"
)


def build_transcript_page(level: str, level_dir: Path) -> str:
    """Return an HTML page with a captioned player and a full transcript.

    The transcript lists every slide's title, on-screen text, and narration,
    so it serves as a text alternative for the video. All authored text is
    escaped, and the page loads nothing but its own media.
    """
    esc = html.escape
    metadata = _style_metadata(level_dir)
    title = str(metadata.get("title") or f"HVE Core {level}")
    language = str(metadata.get("language") or "en-US")
    minutes = measure_minutes(level_dir / "output" / f"hve-demo-{level}.mp4")
    length = f" &middot; {minutes:.1f} minutes" if minutes else ""
    stem = f"hve-demo-{level}"
    sections = []
    for number, slide in load_slides(level_dir / "content"):
        slide_title = str(slide.get("title") or f"Slide {number}")
        shown = [
            text
            for text in on_screen_text(slide)
            if _normalized(text) != _normalized(slide_title)
        ]
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
        f'<video controls preload="metadata"><source src="{stem}.mp4" type="video/mp4">'
        f'<track kind="captions" src="{stem}.vtt" srclang="{esc(language[:2])}" '
        'label="English" default></video>'
        f'<p><a href="{stem}.mp4">Download the video (MP4)</a> &middot; '
        f'<a href="{stem}.pptx">Download the deck (PowerPoint)</a> &middot; '
        f'<a href="{stem}.vtt">Download the captions (WebVTT)</a></p>'
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


def check_accessibility(level: str, level_dir: Path) -> dict:
    """Score T-09: captions, a transcript page, and an accessible deck."""
    output = level_dir / "output"
    problems = []
    captions = output / f"hve-demo-{level}.vtt"
    narrated = sum(
        1 for _, slide in load_slides(level_dir / "content") if notes_text(slide)
    )
    if not captions.is_file():
        problems.append("captions file missing")
    else:
        cues = captions.read_text(encoding="utf-8").count(" --> ")
        if cues < narrated:
            problems.append(f"{cues} caption cues for {narrated} narrated slides")
    page = output / "index.html"
    if not page.is_file() or '<track kind="captions"' not in page.read_text(
        encoding="utf-8"
    ):
        problems.append("transcript page with a captions track missing")
    deck = output / f"hve-demo-{level}.pptx"
    if deck.is_file():
        language = _style_metadata(level_dir).get("language")
        problems += deck_accessibility_problems(deck, language)
    else:
        problems.append("deck missing")
    return {
        "result": "fail" if problems else "pass",
        "evidence": "; ".join(problems)
        or "captions, transcript page, slide titles, alt text, and language present",
    }


def default_capture_profile(level: str) -> str:
    """Return the curriculum's default capture profile for ``level``."""
    return "live" if level in LIVE_LEVELS else "deck-export"


def evaluate(
    level: str,
    level_dir: Path,
    curriculum: dict[str, dict],
    capture_profile: str | None = None,
    narration_engine: str = "piper",
) -> dict:
    """Score the machine-verifiable criteria for one rendered level."""
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
    return {
        "schema_version": 1,
        "level": level,
        "capture_profile": "live" if live else "deck-export",
        "narration_engine": narration_engine,
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
    captions = sub.add_parser("captions", help="Write WebVTT captions")
    captions.add_argument("--level-dir", type=Path, required=True)
    captions.add_argument("--output", type=Path, required=True)
    transcript = sub.add_parser("transcript", help="Write output/index.html")
    transcript.add_argument("--level", required=True, choices=LEVELS)
    transcript.add_argument("--level-dir", type=Path, required=True)
    evaluate_cmd = sub.add_parser("evaluate", help="Score a rendered level")
    evaluate_cmd.add_argument("--level", required=True, choices=LEVELS)
    evaluate_cmd.add_argument("--level-dir", type=Path, required=True)
    evaluate_cmd.add_argument("--capture", choices=("live", "deck-export"))
    evaluate_cmd.add_argument(
        "--narration", choices=("azure", "piper"), default="piper"
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
            target = args.level_dir / "output" / "index.html"
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(
                build_transcript_page(args.level, args.level_dir), encoding="utf-8"
            )
            return EXIT_SUCCESS
        result = evaluate(
            args.level,
            args.level_dir,
            load_curriculum(),
            capture_profile=args.capture,
            narration_engine=args.narration,
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
