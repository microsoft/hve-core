#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Open a single-file HTML slide deck offline and check it starts and fits.

Serves only the standalone deck bytes on an intercepted synthetic origin in
offline sandboxed Chromium. Check-only mode inspects the design canvas;
``--frames-dir`` exports ordered 1920x1080 JPEG canvas frames with hash-bound
evidence. Source files, presenter chrome and external assets are not captured.

Run it in the ``vscode-playwright`` environment, which provides Playwright::

    uv run --directory ../vscode-playwright python check_html_deck.py \
        --deck output/hve-demo-L100.html --output output/html-deck-check.json

Exit codes:
    0 - the deck started offline, every slide fits, and nothing else loaded
    1 - a check failed or the deck could not be opened
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

from render_checks import (
    CheckError,
    checked_path,
    content_digest,
    install_files,
    jpeg_dimensions,
)

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
READY_TIMEOUT_MS = 20_000
DECK_URL = "https://hve-slides.invalid/deck.html"

# Canvas-only framing preserves the 1600x900 design without presenter chrome.
_EXPORT_STYLE = """
.reveal { inset: 0 auto auto 0 !important; width: 1920px !important;
    height: 1080px !important; }
.reveal .slides { position: absolute !important; left: 0 !important; top: 0 !important;
    width: 1600px !important; height: 900px !important; zoom: 1 !important;
    transform: scale(1.2) !important; transform-origin: top left !important; }
.reveal .slides > section.present { transform: none !important; }
*, *::before, *::after { animation: none !important; transition: none !important;
    caret-color: transparent !important; }
"""

_ASSETS_READY = """async () => {
    await document.fonts.ready;
    const slide = document.querySelector('.slides > section.present');
    if (!slide) return false;
    const images = [...slide.querySelectorAll('img')];
    const urls = new Set();
    for (const node of [slide, ...slide.querySelectorAll('*')]) {
        const background = getComputedStyle(node).backgroundImage;
        for (const match of background.matchAll(/url\\(["']?(data:[^"')]+)["']?\\)/g)) {
            urls.add(match[1]);
        }
    }
    for (const url of urls) {
        const image = new Image();
        image.src = url;
        images.push(image);
    }
    await Promise.all(images.map(image => image.decode()));
    if (images.some(image => !image.complete || !image.naturalWidth)) return false;
    await new Promise(resolve => {
        requestAnimationFrame(() => requestAnimationFrame(resolve));
    });
    return true;
}"""

_CURRENT_SLIDE = """() => {
  const slide = document.querySelector('.slides > section.present');
  return {
        id: slide?.id || '',
    title: slide?.dataset.title || '',
        overflow: slide ? slide.scrollHeight > slide.clientHeight + 1
            || slide.scrollWidth > slide.clientWidth + 1 : true,
  };
}"""


def check_deck(
    deck: Path, frames_dir: Path | None = None, level_dir: Path | None = None
) -> dict:
    """Inspect a deck and optionally install a complete ordered frame set.

    Export requires a caller-owned level root. Existing unowned/stale frames
    are preserved with an actionable failure, never recursively removed.
    """
    from playwright.sync_api import Error as PlaywrightError
    from playwright.sync_api import sync_playwright

    deck = checked_path(deck)
    payload = deck.read_bytes()
    build = checked_path(deck.parent / "html-deck-build.json")
    build_bytes = build.read_bytes() if build.is_file() else None
    build_record = json.loads(build_bytes) if build_bytes else {}
    if not isinstance(build_record, dict):
        raise CheckError("HTML build evidence must be a mapping")
    if frames_dir is not None:
        if level_dir is None:
            raise CheckError("Frame export requires --level-dir")
        level_dir = checked_path(level_dir)
        checked_path(deck, level_dir / "output")
        frames_dir = checked_path(frames_dir, level_dir / "frames")
        if frames_dir == level_dir / "frames":
            raise CheckError("Use a dedicated frame directory beneath frames/")
        if (
            build_record.get("schema_version") != 2
            or build_record.get("renderer") != "hve-slides"
            or build_record.get("format") != "html"
            or build_record.get("content_sha256") != content_digest(level_dir)
        ):
            raise CheckError(
                "Current HTML build evidence is required before frame export"
            )
    requests: list[str] = []
    errors: list[str] = []
    overflow: list[str] = []
    slide_ids: list[str] = []
    frames: dict[str, bytes] = {}
    frame_records: list[dict] = []
    started = False
    with sync_playwright() as playwright:
        try:
            browser = playwright.chromium.launch(
                chromium_sandbox=True, timeout=READY_TIMEOUT_MS
            )
        except PlaywrightError as error:
            raise CheckError(f"Sandboxed Chromium is unavailable: {error}") from error
        try:
            context = browser.new_context(
                viewport={"width": 1920, "height": 1200}
                if frames_dir
                else {"width": 1600, "height": 968},
                device_scale_factor=1,
                offline=True,
                service_workers="block",
                reduced_motion="reduce",
                accept_downloads=False,
            )
            context.set_default_timeout(READY_TIMEOUT_MS)
            served = False

            def route_request(route):
                nonlocal served
                if (
                    not served
                    and route.request.url == DECK_URL
                    and route.request.method == "GET"
                    and route.request.is_navigation_request()
                    and route.request.frame == page.main_frame
                ):
                    served = True
                    route.fulfill(
                        status=200,
                        content_type="text/html; charset=utf-8",
                        body=payload,
                    )
                else:
                    requests.append(route.request.url)
                    route.abort()

            def close_socket(socket):
                requests.append(socket.url)
                socket.close()

            context.route("**/*", route_request)
            context.route_web_socket("**/*", close_socket)
            page = context.new_page()

            def close_popup(popup):
                errors.append("unexpected popup")
                popup.close()

            context.on("page", close_popup)
            page.on(
                "dialog",
                lambda dialog: (errors.append("unexpected dialog"), dialog.dismiss()),
            )
            page.on("pageerror", lambda error: errors.append(str(error)))
            page.goto(DECK_URL, wait_until="load", timeout=READY_TIMEOUT_MS)
            try:
                page.wait_for_selector(
                    "html[data-deck-ready='true']",
                    state="attached",
                    timeout=READY_TIMEOUT_MS,
                )
                started = True
            except PlaywrightError:
                notice = page.locator("#startup").text_content() or ""
                errors.append(f"deck did not start: {' '.join(notice.split())}")
            if started:
                slide_ids = page.locator(".slides > section").evaluate_all(
                    "nodes => nodes.map(node => node.id)"
                )
                if (
                    not slide_ids
                    or not all(slide_ids)
                    or len(set(slide_ids)) != len(slide_ids)
                ):
                    raise CheckError("Deck needs nonempty unique slide IDs")
                if frames_dir and any(
                    not re.fullmatch(r"slide-[1-9][0-9]*", value) for value in slide_ids
                ):
                    raise CheckError("Frame export requires canonical slide-N IDs")
                if frames_dir and build_record.get("slide_ids") != slide_ids:
                    raise CheckError("HTML slide order differs from its build evidence")
                if frames_dir:
                    page.add_style_tag(content=_EXPORT_STYLE)
                for index, slide_id in enumerate(slide_ids):
                    page.wait_for_function(
                        "id => { const node = document.querySelector("
                        "'.slides > section.present'); return node?.id === id && "
                        "node.getAttribute('aria-current') === 'page'; }",
                        arg=slide_id,
                        timeout=READY_TIMEOUT_MS,
                    )
                    page.wait_for_function(_ASSETS_READY, timeout=READY_TIMEOUT_MS)
                    current = page.evaluate(_CURRENT_SLIDE)
                    if current["overflow"]:
                        overflow.append(f"{index + 1}. {current['title']}")
                    if frames_dir and not current["overflow"]:
                        canvas = page.locator(".slides > section.present")
                        bounds = canvas.bounding_box()
                        if (
                            not bounds
                            or abs(bounds["width"] - 1920) > 0.01
                            or abs(bounds["height"] - 1080) > 0.01
                        ):
                            raise CheckError("Slide canvas is not exactly 1920x1080")
                        image = canvas.screenshot(
                            type="jpeg",
                            quality=95,
                            animations="disabled",
                            caret="hide",
                            scale="css",
                            timeout=READY_TIMEOUT_MS,
                        )
                        width, height = jpeg_dimensions(image)
                        if (width, height) != (1920, 1080):
                            raise CheckError(
                                "Exported JPEG dimensions differ from the canvas"
                            )
                        name = f"slide-{int(slide_id.removeprefix('slide-')):03d}.jpg"
                        frames[name] = image
                        frame_records.append(
                            {
                                "slide_id": slide_id,
                                "path": (frames_dir / name)
                                .relative_to(level_dir)
                                .as_posix(),
                                "sha256": hashlib.sha256(image).hexdigest(),
                                "width": width,
                                "height": height,
                            }
                        )
                    if index < len(slide_ids) - 1:
                        page.click("#next-slide")
            context.close()
        except PlaywrightError as error:
            errors.append(str(error))
        finally:
            browser.close()
    ok = started and bool(slide_ids) and not requests and not errors and not overflow
    if deck.read_bytes() != payload or (
        build_bytes and build.read_bytes() != build_bytes
    ):
        raise CheckError("HTML/build evidence changed during export; regenerate")
    if frames_dir and build_record.get("content_sha256") != content_digest(level_dir):
        raise CheckError("Authored content changed during export; regenerate")
    if frames_dir and ok:
        prior = checked_path(deck.parent / "html-deck-check.json")
        previous = (
            json.loads(prior.read_text(encoding="utf-8")) if prior.is_file() else {}
        )
        if not isinstance(previous, dict):
            raise CheckError(
                "Prior frame evidence is invalid; preserve existing frames"
            )
        prior_frames = previous.get("frames") or previous.get("retained_frames", [])
        if not isinstance(prior_frames, list):
            raise CheckError("Prior frame evidence is invalid")
        owned = {
            entry.get("path"): entry.get("sha256")
            for entry in prior_frames
            if isinstance(entry, dict)
        }
        for existing in frames_dir.iterdir() if frames_dir.is_dir() else ():
            existing = checked_path(existing, frames_dir)
            relative = existing.relative_to(level_dir).as_posix()
            if (
                not existing.is_file()
                or existing.name not in frames
                or owned.get(relative)
                != hashlib.sha256(existing.read_bytes()).hexdigest()
            ):
                raise CheckError(
                    "Unowned, edited or obsolete frames exist; "
                    "preserve/archive the directory before regenerating"
                )
        install_files(frames_dir, frames)
    return {
        "schema_version": 2,
        "renderer": "hve-slides",
        "format": "html",
        "result": "pass" if ok else "fail",
        "html_sha256": hashlib.sha256(payload).hexdigest(),
        "build_sha256": hashlib.sha256(build_bytes).hexdigest()
        if build_bytes
        else None,
        "slides": len(slide_ids),
        "slide_ids": slide_ids,
        "frames": frame_records if ok else [],
        "overflowing_slides": overflow,
        "external_requests": requests,
        "errors": errors,
    }


def build_parser() -> argparse.ArgumentParser:
    """Create check-only and explicit frame-export arguments."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--deck", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--frames-dir", type=Path)
    parser.add_argument("--level-dir", type=Path)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        output = checked_path(
            args.output, args.level_dir / "output" if args.level_dir else None
        )
        if output == checked_path(args.deck):
            raise CheckError("Evidence must not replace the deck")
        if args.frames_dir is not None and output != checked_path(
            args.deck.parent / "html-deck-check.json"
        ):
            raise CheckError(
                "Export evidence must be html-deck-check.json beside the deck"
            )
        previous = (
            json.loads(output.read_text(encoding="utf-8")) if output.is_file() else {}
        )
        if not isinstance(previous, dict):
            previous = {}
        try:
            result = check_deck(args.deck, args.frames_dir, args.level_dir)
        except (OSError, ValueError, ImportError) as error:
            result = {"result": "fail", "errors": [str(error)]}
        if not result.get("frames"):
            result["retained_frames"] = previous.get("frames") or previous.get(
                "retained_frames", []
            )
        install_files(
            output.parent,
            {output.name: (json.dumps(result, indent=2) + "\n").encode("utf-8")},
        )
    except (OSError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return EXIT_FAILURE
    print(json.dumps(result))
    return EXIT_SUCCESS if result["result"] == "pass" else EXIT_FAILURE


if __name__ == "__main__":
    sys.exit(main())
