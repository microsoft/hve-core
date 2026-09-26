#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Generate an HVE Slides deck source folder from a level's slide content.

Maps each ``content/slide-*/content.yaml`` to semantic slide markup with its
speaker notes, lists the level's pinned sources for the Sources dialog, and
embeds images as CSS data URLs, because the single-file bundler accepts no
resource markup. The starter's build, bundle, theme, and runtime files are
copied unchanged, so ``npm ci`` and ``node bundle.mjs`` in the deck folder
produce one offline HTML file from the same content as the video and deck.

Usage::

    python html_deck.py --level L100 --level-dir DIR \
        --template .github/skills/hve-slides/templates/deck \
        --deck-dir DIR/html-deck/slides/hve-demo-L100
"""

from __future__ import annotations

import argparse
import base64
import html
import json
import shutil
import sys
from pathlib import Path

from render_checks import (
    EXIT_FAILURE,
    EXIT_SUCCESS,
    LEVELS,
    SKILL_ROOT,
    CheckError,
    _normalized,
    _style_metadata,
    load_curriculum,
    load_slides,
    notes_text,
    on_screen_text,
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
REPO_URL = "https://github.com/microsoft/hve-core/blob/main/"
BUILD_SUMMARY = "demo-material-build.json"
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
    items = []
    for entry in value if isinstance(value, list) else []:
        if isinstance(entry, str):
            items.append(entry)
        elif isinstance(entry, dict):
            for key in ("bullet", "text", "label", "title"):
                if isinstance(entry.get(key), str):
                    items.append(entry[key])
                    break
    return [item for item in items if item.strip()]


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
    for row in elem.get("rows") or []:
        cells = row.get("cells") if isinstance(row, dict) else row
        rows.append(_items(cells) if isinstance(cells, list) else [])
    rows = [row for row in rows if row]
    if not rows:
        return ""
    head = "".join(f'<th scope="col">{_esc(cell)}</th>' for cell in rows[0])
    body = "".join(
        "<tr>" + "".join(f"<td>{_esc(cell)}</td>" for cell in row) + "</tr>"
        for row in rows[1:]
    )
    return f"<table><thead><tr>{head}</tr></thead><tbody>{body}</tbody></table>"


def _image(
    elem: dict, slide_dir: Path, name: str, css: list[str], missing: list[str]
) -> str:
    if elem.get("decorative"):
        return ""
    alt = str(elem.get("alt") or "").strip()
    rel = str(elem.get("path") or "")
    candidates = [slide_dir / rel, slide_dir.parent / rel]
    found = next((p for p in candidates if rel and p.is_file()), None)
    mime = IMAGE_TYPES.get(found.suffix.lower()) if found else None
    if not mime:
        missing.append(f"{slide_dir.name}/{rel}")
        return f'<p class="footnote">Image: {_esc(alt or rel)}</p>'
    data = base64.b64encode(found.read_bytes()).decode("ascii")
    css.append(f'.{name} {{ background-image: url("data:{mime};base64,{data}"); }}')
    return f'<div class="shot {name}" role="img" aria-label="{_esc(alt or rel)}"></div>'


def _num(elem: dict, key: str) -> float | None:
    value = elem.get(key)
    return float(value) if isinstance(value, (int, float)) else None


def _flatten(elements) -> list[dict]:
    flat = []
    for elem in elements or []:
        if isinstance(elem, dict):
            if elem.get("type") == "group":
                flat += _flatten(elem.get("elements"))
            else:
                flat.append(elem)
    return flat


def _is_panel_shape(elem: dict) -> bool:
    """Return whether a text-free shape frames other text as a panel."""
    width, height = _num(elem, "width") or 0, _num(elem, "height") or 0
    if elem.get("type") != "shape" or str(elem.get("text") or "").strip():
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
    number: int, slide: dict, slide_dir: Path, css: list[str], missing: list[str]
) -> str:
    """Return one slide's inner markup, adding image rules to ``css`` and
    unresolved image paths to ``missing``.

    Text placed inside a framing shape becomes one panel, panels and cards
    that share a row become a grid, and every block follows the slide's
    top-to-bottom, left-to-right reading order.
    """
    title = str(slide.get("title") or f"Slide {number}")
    heading = "h1" if number == 1 else "h2"
    elements = [
        e for e in _flatten(slide.get("elements")) if e.get("type") != "connector"
    ]
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
            if not text and not _items(elem.get("bullets") or elem.get("paragraphs")):
                continue
            if _normalized(text) == _normalized(title):
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
        return "".join(
            f"<p>{_esc(text)}</p>" for text in on_screen_text({"elements": [elem]})
        )

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
    notes = notes_text(slide)
    body = '<div class="slide-body">' + "".join(p for p in parts if p) + "</div>"
    return body + (f'<aside class="notes">{_esc(notes)}</aside>' if notes else "")


def _json_script(value) -> str:
    return json.dumps(value, ensure_ascii=True).replace("<", "\\u003c")


def build_deck_source(
    level: str, level_dir: Path, template: Path, deck_dir: Path
) -> Path:
    """Write the deck source folder and return ``deck_dir``."""
    for name in (*COPIED_FILES, "index.html", "components.css"):
        if not (template / name).is_file():
            raise CheckError(f"HVE Slides template file missing: {template / name}")
    slides = load_slides(level_dir / "content")
    if not slides:
        raise CheckError(f"no slides under {level_dir / 'content'}")
    curriculum = load_curriculum()
    metadata = _style_metadata(level_dir)
    title = str(metadata.get("title") or f"HVE Core {level}")
    description = str(metadata.get("subject") or f"HVE Core {level} demo material")

    sources = {
        f"source-{i}": {
            "title": path,
            "url": REPO_URL + path,
            "note": f"Pinned {level} source document.",
        }
        for i, path in enumerate(curriculum.get(level, {}).get("sources", []), 1)
    }
    source_ids = ",".join(sources)

    css: list[str] = []
    missing: list[str] = []
    sections = []
    for number, slide in slides:
        slide_title = str(slide.get("title") or f"Slide {number}")
        chapter = str(slide.get("section") or level)
        slide_dir = level_dir / "content" / f"slide-{number:03d}"
        body = slide_markup(number, slide, slide_dir, css, missing)
        sections.append(
            f'      <section id="slide-{number}" data-title="{_esc(slide_title)}" '
            f'data-chapter="{_esc(chapter)}" data-sources="{source_ids}">'
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
    first_chapter = _esc(str(slides[0][1].get("section") or level))
    page = page.replace(
        '<span id="chapter-label">Introduction</span>',
        f'<span id="chapter-label">{first_chapter}</span>',
        1,
    )

    if deck_dir.exists():
        shutil.rmtree(deck_dir)
    deck_dir.mkdir(parents=True)
    for name in COPIED_FILES:
        shutil.copy2(template / name, deck_dir / name)
    (deck_dir / "index.html").write_text(page, encoding="utf-8")
    (deck_dir / "components.css").write_text(
        (template / "components.css").read_text(encoding="utf-8").rstrip()
        + "\n"
        + DECK_CSS_FILE.read_text(encoding="utf-8")
        + "".join(f"{rule}\n" for rule in css),
        encoding="utf-8",
    )
    (deck_dir / "content.js").write_text(
        "// Copyright (c) Microsoft Corporation. Licensed under the MIT License.\n"
        "// Generated from the level's slide content; walkthroughs are not used.\n"
        f"globalThis.DeckContent = {{ sources: {_json_script(sources)}, "
        "examples: {}, demos: {} };\n",
        encoding="utf-8",
    )
    (deck_dir / "deck.json").write_text(
        json.dumps(
            {
                "title": title,
                "description": description,
                "sourceNote": (
                    f"Built from the pinned {level} source documents. The same "
                    "slide content drives the narrated video and the PowerPoint deck."
                ),
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    (deck_dir / BUILD_SUMMARY).write_text(
        json.dumps({"slides": len(slides), "missing_images": missing}, indent=2) + "\n",
        encoding="utf-8",
    )
    return deck_dir


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--level", required=True, choices=LEVELS)
    parser.add_argument("--level-dir", type=Path, required=True)
    parser.add_argument("--template", type=Path, required=True)
    parser.add_argument("--deck-dir", type=Path, required=True)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        build_deck_source(args.level, args.level_dir, args.template, args.deck_dir)
    except (CheckError, OSError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return EXIT_FAILURE
    print(args.deck_dir)
    return EXIT_SUCCESS


if __name__ == "__main__":
    sys.exit(main())
