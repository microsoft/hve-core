#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Generate an HVE Slides deck source folder from a level's slide content.

Maps each ``content/slide-*/content.yaml`` to semantic slide markup with its
speaker notes, lists the level's resolved sources for the Sources dialog, and
embeds images as CSS data URLs, because the single-file bundler accepts no
resource markup. The starter's build, bundle, theme, and runtime files are
copied unchanged. The loaded HVE Slides render-only CLI, not a source-supplied
build program, produces offline HTML from the same content as the video.

Sources come from the level manifest's source register, falling back to the
curriculum's pinned sources. Citation links point at the workspace repository:
its GitHub ``origin`` remote at the checked-out commit, or ``--repo-url``. When
neither yields a link base, source paths remain visible without hyperlinks.

Usage::

    python html_deck.py --level L100 --level-dir DIR \
        --template <loaded-hve-slides-root>/templates/deck \
        --deck-dir DIR/html-deck/slides/hve-demo-L100 [--workspace REPO] \
        [--repo-url https://github.com/OWNER/REPO/blob/REF/]
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import html
import json
import math
import re
import subprocess
import sys
import urllib.parse
from pathlib import Path

import yaml
from render_checks import (
    EXIT_FAILURE,
    EXIT_SUCCESS,
    LEVELS,
    SKILL_ROOT,
    CheckError,
    checked_path,
    content_digest,
    install_files,
    load_curriculum,
    load_slides,
    normalized_text,
    notes_text,
    style_metadata,
)

COPIED_FILES = (
    "build.mjs",
    "bundle.mjs",
    "theme.css",
    "components.js",
    "deck.js",
    "package.json",
    "package-lock.json",
    ".npmrc",
    "LICENSE",
)
BUILD_SUMMARY = "demo-material-build.json"
MANIFEST_PATHS = ("output/manifest.yml", "manifest.yml")
_GITHUB_REMOTE = re.compile(
    r"^(?:https://(?:[^@/]+@)?github\.com/|git@github\.com:|ssh://git@github\.com/)"
    r"([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+?)(?:\.git)?/?$"
)
_COMMIT = re.compile(r"^[0-9a-f]{40}$")
IMAGE_TYPES = {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg"}

# Slide geometry is in inches on a 13.333 by 7.5 canvas.
PANEL_MIN_WIDTH_IN = 1.5
PANEL_MIN_HEIGHT_IN = 0.6
PANEL_MAX_WIDTH_IN = 12.5
PANEL_MAX_HEIGHT_IN = 7.0
ROW_TOLERANCE_IN = 0.35
FOOTNOTE_MAX_PT = 10
LABEL_MAX_PT = 13
PANEL_HEADING_MIN_PT = 19
BULLET_MARKS = "-*\u2022"

DECK_CSS_FILE = SKILL_ROOT / "templates" / "html-deck.css"


def _esc(text) -> str:
    return html.escape(" ".join(str(text).split()), quote=True)


def _items(value) -> list[str]:
    """Return the display strings of a bullet, row, or item list."""
    if not isinstance(value, list):
        raise CheckError("Expected a list of text items")
    items = []
    for entry in value:
        if isinstance(entry, str):
            items.append(entry)
        elif type(entry) in (int, float) and math.isfinite(entry):
            items.append(str(entry))
        elif isinstance(entry, dict):
            keys = set(entry) & {"bullet", "text", "label", "title"}
            if len(keys) != 1 or set(entry) != keys:
                raise CheckError("List items require exactly one bullet/text/label/title; map extra content explicitly")
            items.extend(_items([entry[next(iter(keys))]]))
        else:
            raise CheckError("Unsupported list item; use text or a finite number")
    if any(not item.strip() for item in items):
        raise CheckError("Empty list/table items are not supported")
    return items


def _list(items: list[str]) -> str:
    return "<ul>" + "".join(f"<li>{_esc(item)}</li>" for item in items) + "</ul>"


def _card(elem: dict) -> str:
    body = ""
    content = elem.get("content")
    if isinstance(content, list):
        body = _list(_items(content))
    elif isinstance(content, str):
        body = f"<p>{_esc(content)}</p>"
    title = f"<h3>{_esc(elem['title'])}</h3>" if elem.get("title") else ""
    return f'<article class="panel">{title}{body}</article>'


def _table(elem: dict) -> str:
    rows = []
    if not isinstance(elem.get("rows"), list) or not elem["rows"]:
        raise CheckError("A table requires a nonempty rows list with a header row")
    for row in elem["rows"]:
        if isinstance(row, dict) and set(row) != {"cells"}:
            raise CheckError("Table rows support cells only; map merged cells explicitly")
        cells = row.get("cells") if isinstance(row, dict) else row
        rows.append(_items(cells))
    if not rows[0] or any(len(row) != len(rows[0]) for row in rows):
        raise CheckError("Table rows must have the same nonzero cell count")
    head = "".join(f'<th scope="col">{_esc(cell)}</th>' for cell in rows[0])
    body = "".join(
        "<tr>" + "".join(f"<td>{_esc(cell)}</td>" for cell in row) + "</tr>"
        for row in rows[1:]
    )
    return f"<table><thead><tr>{head}</tr></thead><tbody>{body}</tbody></table>"


def _image(
    elem: dict, slide_dir: Path, name: str, css: list[str], missing: list[str]
) -> str:
    if elem.get("decorative") is True:
        return ""
    alt = str(elem.get("alt") or "").strip()
    if not alt or re.search(r"\.(png|jpe?g)$", alt, re.I):
        raise CheckError(f"{slide_dir.name}: image requires descriptive alt text")
    rel = str(elem.get("path") or "")
    if _safe_source_path(rel) is None:
        raise CheckError(f"{slide_dir.name}: image path must be a plain relative path")
    candidates = [checked_path(base / rel, slide_dir.parent) for base in (slide_dir, slide_dir.parent)]
    found = next((p for p in candidates if p.is_file()), None)
    mime = IMAGE_TYPES.get(found.suffix.lower()) if found else None
    if not mime:
        raise CheckError(f"{slide_dir.name}/{rel}: missing or unsupported image; supply PNG/JPEG")
    data = base64.b64encode(found.read_bytes()).decode("ascii")
    css.append(f'.{name} {{ background-image: url("data:{mime};base64,{data}"); }}')
    return f'<div class="shot {name}" role="img" aria-label="{_esc(alt or rel)}"></div>'


def _num(elem: dict, key: str) -> float | None:
    value = elem.get(key)
    return float(value) if isinstance(value, (int, float)) else None


def _flatten(elements) -> list[dict]:
    if not isinstance(elements, list):
        raise CheckError("elements must be a list of mappings")
    flat = []
    styles = {"left", "top", "width", "height", "font", "font_size", "font_color", "font_bold", "auto_size", "alignment", "fill", "line", "border_color", "border_width", "shape", "corner_radius", "decorative"}
    fields = {
        "textbox": {"text", "bullets", "paragraphs"},
        "shape": {"text", "bullets", "paragraphs"},
        "card": {"title", "content"}, "table": {"rows"},
        "arrow_flow": {"items"}, "numbered_step": {"label", "description"},
        "image": {"path", "alt"},
    }
    for elem in elements:
        if not isinstance(elem, dict):
            raise CheckError("Every element must be a mapping")
        kind = elem.get("type")
        if not isinstance(kind, str) or any(not isinstance(key, str) for key in elem):
            raise CheckError("Element type and field names must be text")
        if kind == "group":
            if set(elem) - {"type", "elements"}:
                raise CheckError("Groups support elements only; flatten transformed/labeled groups explicitly")
            flat += _flatten(elem.get("elements"))
            continue
        if kind == "connector":
            raise CheckError("connector is unsupported; express the relationship as arrow_flow, numbered_step or labeled text")
        if kind not in fields:
            raise CheckError(f"Unsupported element type {kind!r}; map meaningful content explicitly")
        if kind == "shape" and elem.get("shape", "rectangle") not in ("rectangle", "rounded_rectangle"):
            raise CheckError("Only rectangular panel shapes are supported; express other shape meaning in text")
        extra = set(elem) - {"type"} - styles - fields[kind]
        if extra:
            raise CheckError(f"{kind}: unsupported fields {sorted(extra)}; map rather than discard them")
        for key in ("left", "top", "width", "height", "font_size"):
            if key in elem and (type(elem[key]) not in (int, float) or not math.isfinite(elem[key])):
                raise CheckError(f"{kind}.{key} must be a finite number")
        if "decorative" in elem and type(elem["decorative"]) is not bool:
            raise CheckError("decorative must be a boolean")
        for key in fields[kind] & {"text", "title", "label", "description", "path", "alt"}:
            if key in elem and not isinstance(elem[key], str):
                raise CheckError(f"{kind}.{key} must be text")
        if kind in ("textbox", "shape") and sum(key in elem for key in ("text", "bullets", "paragraphs")) > 1:
            raise CheckError(f"{kind}: use one of text, bullets or paragraphs, not overlapping content")
        if kind == "card" and not isinstance(elem.get("content"), (str, list)):
            raise CheckError("card.content must be text or a list")
        if kind == "numbered_step" and not str(elem.get("label", "")).strip():
            raise CheckError("numbered_step requires a label")
        flat.append(elem)
    return flat


def _is_panel_shape(elem: dict) -> bool:
    """Return whether a text-free shape frames other text as a panel."""
    width, height = _num(elem, "width") or 0, _num(elem, "height") or 0
    if elem.get("type") != "shape" or any(elem.get(key) for key in ("text", "bullets", "paragraphs")):
        return False
    full_slide = width >= PANEL_MAX_WIDTH_IN and height >= PANEL_MAX_HEIGHT_IN
    return (
        width >= PANEL_MIN_WIDTH_IN and height >= PANEL_MIN_HEIGHT_IN and not full_slide
    )


def _contains(frame: dict, elem: dict) -> bool:
    left, top = _num(elem, "left"), _num(elem, "top")
    if left is None or top is None:
        return False
    x = left + (_num(elem, "width") or 0) / 2
    y = top + (_num(elem, "height") or 0) / 2
    fl, ft = _num(frame, "left") or 0, _num(frame, "top") or 0
    return fl <= x <= fl + (_num(frame, "width") or 0) and ft <= y <= ft + (
        _num(frame, "height") or 0
    )


def _text_lines(text: str) -> list[str]:
    """Split text into lines, joining a hard wrap back onto its sentence.

    A line that starts in lowercase continues the previous line unless that
    line is a bullet, so only separately authored lines become list items.
    """
    lines: list[str] = []
    for raw in str(text or "").splitlines():
        line = raw.strip()
        if not line:
            continue
        bullet = line[0] in BULLET_MARKS
        if lines and not bullet and line[0].islower():
            lines[-1] = f"{lines[-1]} {line}"
        else:
            lines.append(line.lstrip(BULLET_MARKS + " ").strip() or line)
    return lines


def _text_markup(elem: dict, in_panel: bool) -> str:
    """Return a text element as a label, heading, list, or paragraph."""
    lines = _text_lines(elem.get("text"))
    size = _num(elem, "font_size") or 18
    if not lines:
        return _list(_items(elem.get("bullets") or elem.get("paragraphs") or []))
    if len(lines) > 1:
        return _list(lines)
    text = _esc(lines[0])
    if size <= FOOTNOTE_MAX_PT:
        return f'<p class="footnote">{text}</p>'
    if in_panel and elem.get("font_bold") and size <= LABEL_MAX_PT:
        return f'<p class="label">{text}</p>'
    if in_panel and size >= PANEL_HEADING_MIN_PT:
        return f"<h3>{text}</h3>"
    if elem.get("font_bold"):
        return f"<p><strong>{text}</strong></p>"
    return f"<p>{text}</p>"


def slide_markup(
    number: int, slide: dict, slide_dir: Path, css: list[str], missing: list[str],
    *, citations: list[str] | None = None,
) -> str:
    """Return semantic markup and image rules; reject missing meaningful images.

    Text placed inside a framing shape becomes one panel, panels and cards
    that share a row become a grid, and every block follows the slide's
    top-to-bottom, left-to-right reading order.
    """
    title = slide.get("title")
    if not isinstance(title, str) or not title.strip():
        raise CheckError(f"Slide {number} requires a nonempty title")
    if "speaker_notes" in slide and not isinstance(slide["speaker_notes"], str):
        raise CheckError(f"Slide {number}: speaker_notes must be text")
    heading = "h1" if number == 1 else "h2"
    elements = _flatten(slide.get("elements", []))
    frames = [e for e in elements if _is_panel_shape(e)]
    members: dict[int, list[dict]] = {id(frame): [] for frame in frames}

    def is_frame(elem: dict) -> bool:
        return id(elem) in members

    units = []
    last_top = 0.0
    for order, elem in enumerate(elements):
        kind = elem.get("type")
        text = str(elem.get("text") or "").strip()
        top = _num(elem, "top")
        last_top = top if top is not None else last_top
        if is_frame(elem):
            continue
        if kind in ("textbox", "shape"):
            if not text and not _items(elem.get("bullets") or elem.get("paragraphs") or []):
                if elem.get("decorative") is True:
                    continue
                raise CheckError(f"Slide {number}: empty {kind}; supply text or explicitly mark decorative")
            if normalized_text(text) == normalized_text(title):
                continue
            holders = [f for f in frames if _contains(f, elem)]
            if holders:
                smallest = min(
                    holders,
                    key=lambda f: (_num(f, "width") or 0) * (_num(f, "height") or 0),
                )
                members[id(smallest)].append(elem)
                continue
        units.append((last_top, _num(elem, "left") or 0.0, order, elem))
    for order, frame in enumerate(frames):
        if members[id(frame)]:
            units.append(
                (_num(frame, "top") or 0.0, _num(frame, "left") or 0.0, -1, frame)
            )
        elif frame.get("decorative") is not True:
            raise CheckError(f"Slide {number}: empty panel shape; mark decorative or supply its meaning")
    units.sort(key=lambda unit: (unit[0], unit[1], unit[2]))

    rows: list[list[tuple]] = []
    for unit in units:
        if rows and abs(unit[0] - rows[-1][0][0]) < ROW_TOLERANCE_IN:
            rows[-1].append(unit)
        else:
            rows.append([unit])

    parts = []
    if slide.get("section"):
        parts.append(
            f'<div class="eyebrow">{_esc(str(slide["section"]).upper())}</div>'
        )
    parts.append(f"<{heading}>{_esc(title)}</{heading}>")
    steps: list[str] = []
    lead_open = True

    def block(elem: dict) -> str:
        nonlocal lead_open
        kind = elem.get("type")
        if is_frame(elem):
            lead_open = False
            inner = sorted(
                members[id(elem)],
                key=lambda e: (_num(e, "top") or 0, _num(e, "left") or 0),
            )
            return (
                '<article class="panel">'
                + "".join(_text_markup(e, True) for e in inner)
                + "</article>"
            )
        if kind == "card":
            return _card(elem)
        if kind in ("textbox", "shape"):
            markup = _text_markup(elem, False)
            if lead_open and markup.startswith("<p>"):
                markup = '<p class="lead">' + markup[3:]
            lead_open = False
            return markup
        lead_open = False
        if kind == "arrow_flow":
            labels = _items(elem.get("items"))
            return (
                '<ol class="flow">'
                + "".join(f"<li>{_esc(label)}</li>" for label in labels)
                + "</ol>"
                if labels
                else ""
            )
        if kind == "table":
            return _table(elem)
        if kind == "image":
            return _image(elem, slide_dir, f"shot-{number}-{len(css)}", css, missing)
        raise CheckError(f"Slide {number}: unsupported element {kind!r}")

    for row in rows:
        row.sort(key=lambda unit: (unit[1], unit[2]))
        row_elements = [unit[3] for unit in row]
        if all(e.get("type") == "numbered_step" for e in row_elements):
            for elem in row_elements:
                description = elem.get("description")
                detail = f"<span>{_esc(description)}</span>" if description else ""
                steps.append(
                    f"<li><strong>{_esc(elem.get('label', ''))}</strong>{detail}</li>"
                )
            continue
        if steps:
            parts.append('<ol class="demo-steps">' + "".join(steps) + "</ol>")
            steps = []
            lead_open = False
        panels = [e for e in row_elements if is_frame(e) or e.get("type") == "card"]
        if len(panels) > 1 and len(panels) == len(row_elements):
            parts.append(
                '<div class="card-grid">'
                + "".join(block(e) for e in row_elements)
                + "</div>"
            )
            lead_open = False
        elif len(row_elements) > 1 and all(
            e.get("type") in ("textbox", "shape") and not is_frame(e)
            for e in row_elements
        ):
            lead_open = False
            parts.append(
                '<div class="text-row">'
                + "".join(block(e) for e in row_elements)
                + "</div>"
            )
        else:
            parts += [block(e) for e in row_elements]
    if steps:
        parts.append('<ol class="demo-steps">' + "".join(steps) + "</ol>")
    if citations:
        parts.append(f'<p class="footnote">Sources: {_esc("; ".join(citations))}</p>')
    notes = notes_text(slide)
    body = '<div class="slide-body">' + "".join(p for p in parts if p) + "</div>"
    return body + (f'<aside class="notes">{_esc(notes)}</aside>' if notes else "")


def _json_script(value) -> str:
    return json.dumps(value, ensure_ascii=True).replace("<", "\\u003c")


def _git(workspace: Path, *args: str) -> str | None:
    try:
        result = subprocess.run(
            ["git", "-C", str(workspace), *args],
            capture_output=True,
            text=True,
            check=False,
            timeout=30,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    return result.stdout.strip() if result.returncode == 0 else None


def github_blob_base(remote: str, commit: str) -> str | None:
    """Return ``https://github.com/OWNER/REPO/blob/COMMIT/`` for a GitHub remote.

    Only the owner and repository name are kept, so credentials embedded in the
    remote URL never reach the deck. Returns ``None`` for other hosts.
    """
    match = _GITHUB_REMOTE.match(remote.strip())
    if not match or not _COMMIT.match(commit):
        return None
    owner, repo = match.groups()
    return f"https://github.com/{owner}/{repo}/blob/{commit}/"


def workspace_blob_base(workspace: Path) -> str | None:
    """Return the citation link base for the repository checked out at ``workspace``."""
    remote = _git(workspace, "remote", "get-url", "origin")
    commit = _git(workspace, "rev-parse", "HEAD")
    return github_blob_base(remote, commit) if remote and commit else None


def _safe_source_path(path: object) -> str | None:
    text = str(path).strip() if isinstance(path, str) else ""
    parts = text.split("/")
    if not text or text.startswith("/") or ":" in text or "\\" in text:
        return None
    if any(part in ("", ".", "..") for part in parts):
        return None
    return text


def level_sources(level: str, level_dir: Path) -> list[str]:
    """Return the level's resolved source paths.

    Reads the manifest's source register when one exists, so a dynamic topic
    cites what it actually used, and falls back to the curriculum's pinned
    sources for the level. Invalid paths fail rather than disappearing.
    """
    for name in MANIFEST_PATHS:
        manifest = checked_path(level_dir / name, level_dir)
        if not manifest.is_file():
            continue
        data = yaml.safe_load(manifest.read_text(encoding="utf-8")) or {}
        entries = data.get("sources") if isinstance(data, dict) else None
        if entries is not None and not isinstance(entries, list):
            raise CheckError(f"Invalid source register in {name}; sources must be a list")
        paths = [
            _safe_source_path(entry.get("path"))
            for entry in entries or []
            if isinstance(entry, dict)
        ]
        if entries is not None and (
            not isinstance(entries, list) or len(paths) != len(entries) or None in paths
        ):
            raise CheckError(f"Invalid source register in {name}; use plain repository-relative paths")
        resolved = list(dict.fromkeys(path for path in paths if path))
        if resolved:
            return resolved
    return list(load_curriculum().get(level, {}).get("sources", []))


def build_deck_source(
    level: str,
    level_dir: Path,
    template: Path,
    deck_dir: Path,
    repo_url: str | None = None,
) -> Path:
    """Write the deck source folder and return ``deck_dir``.

    ``repo_url`` is the link base; without it citations remain visible text.
    """
    parsed_url = urllib.parse.urlsplit(repo_url or "")
    if repo_url is not None and not (
        parsed_url.scheme == "https" and parsed_url.hostname and repo_url.endswith("/")
        and not parsed_url.username and not parsed_url.password
        and not parsed_url.query and not parsed_url.fragment
    ):
        raise CheckError("--repo-url must be an https URL ending in '/'")
    level_dir = checked_path(level_dir)
    template = checked_path(template)
    for name in (*COPIED_FILES, "index.html", "components.css"):
        if not checked_path(template / name, template).is_file():
            raise CheckError(f"HVE Slides template file missing: {template / name}")
    slides = load_slides(level_dir / "content")
    if not slides:
        raise CheckError(f"no slides under {level_dir / 'content'}")
    metadata = style_metadata(level_dir)
    for field in ("title", "subject", "keywords"):
        if field in metadata and not isinstance(metadata[field], str):
            raise CheckError(f"metadata.{field} must be text")
    title = str(metadata.get("title") or f"HVE Core {level}")
    description = str(metadata.get("subject") or f"HVE Core {level} demo material")
    language = metadata.get("language", "en-US")
    if not isinstance(language, str) or not re.fullmatch(r"[A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*", language):
        raise CheckError("metadata.language must be a language tag such as en-US")
    deck_dir = checked_path(deck_dir, level_dir)
    if deck_dir == level_dir or deck_dir.is_relative_to(level_dir / "content"):
        raise CheckError("--deck-dir must be a generated directory outside content/")
    if deck_dir.is_relative_to(template.parent.parent) or deck_dir.is_relative_to(SKILL_ROOT):
        raise CheckError("Deck source must not be written inside a skill installation")

    source_paths = level_sources(level, level_dir)
    sources = (
        {
            f"source-{i}": {
                "title": path,
                "url": repo_url + urllib.parse.quote(path),
                "note": f"{level} source document.",
            }
            for i, path in enumerate(source_paths, 1)
        }
        if repo_url
        else {}
    )
    css: list[str] = []
    missing: list[str] = []
    sections = []
    for number, slide in slides:
        if any(not isinstance(key, str) for key in slide):
            raise CheckError(f"Slide {number}: field names must be text")
        extra = set(slide) - {"slide", "slide_number", "id", "title", "section", "layout", "background", "elements", "speaker_notes", "language", "citations"}
        if extra:
            raise CheckError(f"Slide {number}: unsupported fields {sorted(extra)}")
        for identity in ("slide", "slide_number"):
            if identity in slide and (type(slide[identity]) is not int or slide[identity] != number):
                raise CheckError(f"Slide {number}: {identity} must match its directory number")
        slide_language = slide.get("language", language)
        if not isinstance(slide_language, str) or not re.fullmatch(r"[A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*", slide_language):
            raise CheckError(f"Slide {number}: invalid language tag")
        slide_title = str(slide.get("title") or f"Slide {number}")
        chapter = str(slide.get("section") or level)
        slide_dir = level_dir / "content" / f"slide-{number:03d}"
        citations = slide.get("citations", source_paths)
        if not isinstance(citations, list) or any(path not in source_paths for path in citations):
            raise CheckError(f"Slide {number}: citations must name paths in the source register")
        selected_ids = ",".join(f"source-{source_paths.index(path) + 1}" for path in citations) if repo_url else ""
        body = slide_markup(number, slide, slide_dir, css, missing, citations=citations)
        sections.append(
            f'      <section id="slide-{number}" data-title="{_esc(slide_title)}" '
            f'lang="{_esc(slide_language)}" data-chapter="{_esc(chapter)}" data-sources="{selected_ids}">'
            f"{body}</section>"
        )

    template_html = (template / "index.html").read_text(encoding="utf-8")
    start = template_html.index('<main class="slides"')
    start = template_html.index(">", start) + 1
    end = template_html.index("</main>")
    page = (
        template_html[:start]
        + "\n"
        + "\n".join(sections)
        + "\n    "
        + template_html[end:]
    )
    page = page.replace(
        "<title>HTML slide deck</title>", f"<title>{_esc(title)}</title>", 1
    )
    page = re.sub(r'<html lang="[^"]*">', f'<html lang="{language}">', page, count=1)
    first_chapter = _esc(str(slides[0][1].get("section") or level))
    page = page.replace(
        '<span id="chapter-label">Introduction</span>',
        f'<span id="chapter-label">{first_chapter}</span>',
        1,
    )

    files = {name: (template / name).read_bytes() for name in COPIED_FILES}
    files["index.html"] = page.encode("utf-8")
    files["components.css"] = (
        (template / "components.css").read_text(encoding="utf-8").rstrip()
        + "\n"
        + DECK_CSS_FILE.read_text(encoding="utf-8")
        + "".join(f"{rule}\n" for rule in css)
    ).encode("utf-8")
    files["content.js"] = (
        "// Copyright (c) Microsoft Corporation. Licensed under the MIT License.\n"
        "// Generated from the level's slide content; walkthroughs are not used.\n"
        f"globalThis.DeckContent = {{ sources: {_json_script(sources)}, "
        "examples: {}, demos: {} };\n"
    ).encode("utf-8")
    files["deck.json"] = (
        json.dumps(
            {
                "title": title,
                "description": description,
                "sourceNote": (
                    f"Built from the {level} source documents. The same "
                    "slide content drives the HTML deck and the video."
                ),
            },
            indent=2,
        )
        + "\n"
    ).encode("utf-8")
    files[BUILD_SUMMARY] = (
        json.dumps(
            {
                "schema_version": 2, "renderer": "hve-slides", "format": "html",
                "slides": len(slides), "slide_ids": [f"slide-{n}" for n, _ in slides],
                "content_sha256": content_digest(level_dir),
                "missing_images": missing, "sources": len(source_paths),
                "source_files": {name: hashlib.sha256(data).hexdigest() for name, data in files.items()},
                "template_files": {
                    name: hashlib.sha256((template / name).read_bytes()).hexdigest()
                    for name in (*COPIED_FILES, "index.html", "components.css")
                },
            },
            indent=2,
        )
        + "\n"
    ).encode("utf-8")
    existing = [name for name in files if checked_path(deck_dir / name, level_dir).exists()]
    if existing:
        marker = checked_path(deck_dir / BUILD_SUMMARY, level_dir)
        if not marker.is_file():
            raise CheckError("Source directory contains unowned files; choose a new --deck-dir")
        previous = json.loads(marker.read_text(encoding="utf-8"))
        if not isinstance(previous, dict) or previous.get("schema_version") != 2 or previous.get("renderer") != "hve-slides":
            raise CheckError("Source ownership record is incompatible; preserve it and choose a new --deck-dir")
        recorded = previous.get("source_files")
        if not isinstance(recorded, dict) or any(
            name != BUILD_SUMMARY and recorded.get(name) != hashlib.sha256((deck_dir / name).read_bytes()).hexdigest()
            for name in existing
        ):
            raise CheckError("Generated source was edited; preserve it and choose a new --deck-dir")
    install_files(deck_dir, files)
    return deck_dir


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--level", required=True, choices=LEVELS)
    parser.add_argument("--level-dir", type=Path, required=True)
    parser.add_argument("--template", type=Path, required=True)
    parser.add_argument("--deck-dir", type=Path, required=True)
    parser.add_argument(
        "--workspace",
        type=Path,
        help="Repository whose GitHub origin and commit the citations link to",
    )
    parser.add_argument(
        "--repo-url",
        help="Citation link base, overriding --workspace, for example "
        "https://github.com/OWNER/REPO/blob/main/",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    repo_url = args.repo_url or (
        workspace_blob_base(args.workspace) if args.workspace else None
    )
    if repo_url is None:
        print(
            "No citation link base; retaining source paths as visible text.",
            file=sys.stderr,
        )
    try:
        build_deck_source(
            args.level, args.level_dir, args.template, args.deck_dir, repo_url
        )
    except (CheckError, OSError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return EXIT_FAILURE
    print(args.deck_dir)
    return EXIT_SUCCESS


if __name__ == "__main__":
    sys.exit(main())
