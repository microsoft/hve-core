#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Open a single-file HTML slide deck offline and check it starts and fits.

Loads the deck from ``file://`` in headless Chromium with the network
disabled, waits for the presentation to report ready, then steps through every
slide and records any that overflow the 1600 by 900 slide frame. Any request
for another file or a remote resource fails the check, because the bundle must
work when it is the only file a recipient downloads.

Run it in the ``vscode-playwright`` environment, which provides Playwright::

    uv run --directory ../vscode-playwright python check_html_deck.py \
        --deck output/hve-demo-L100.html --output output/html-deck-check.json

Exit codes:
    0 - the deck started offline, every slide fits, and nothing else loaded
    1 - a check failed or the deck could not be opened
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
READY_TIMEOUT_MS = 20_000

_CURRENT_SLIDE = """() => {
  const slide = document.querySelector('.slides > section.present');
  return {
    title: slide?.dataset.title || '',
    overflow: slide ? slide.scrollHeight > slide.clientHeight + 1
      || slide.scrollWidth > slide.clientWidth + 1 : true,
  };
}"""


def check_deck(deck: Path) -> dict:
    """Return the offline start, request, and overflow evidence for ``deck``."""
    from playwright.sync_api import Error as PlaywrightError
    from playwright.sync_api import sync_playwright

    url = deck.resolve().as_uri()
    requests: list[str] = []
    errors: list[str] = []
    overflow: list[str] = []
    slides = 0
    started = False
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch()
        try:
            context = browser.new_context(
                viewport={"width": 1600, "height": 968}, offline=True
            )
            page = context.new_page()
            page.on(
                "request",
                lambda request: (
                    request.url == url
                    or request.url.startswith("data:")
                    or requests.append(request.url)
                ),
            )
            page.on("pageerror", lambda error: errors.append(str(error)))
            page.goto(url)
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
                slides = page.locator(".slides > section").count()
                for index in range(slides):
                    current = page.evaluate(_CURRENT_SLIDE)
                    if current["overflow"]:
                        overflow.append(f"{index + 1}. {current['title']}")
                    if index < slides - 1:
                        page.click("#next-slide")
                        page.wait_for_function(
                            "n => document.querySelector('#slide-count')"
                            "?.textContent.startsWith(`${n} /`)",
                            arg=index + 2,
                        )
        finally:
            browser.close()
    ok = started and not requests and not errors and not overflow
    return {
        "result": "pass" if ok else "fail",
        "slides": slides,
        "overflowing_slides": overflow,
        "external_requests": requests,
        "errors": errors,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--deck", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(argv)
    if not args.deck.is_file():
        result = {"result": "fail", "errors": [f"deck missing: {args.deck}"]}
    else:
        result = check_deck(args.deck)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result))
    return EXIT_SUCCESS if result["result"] == "pass" else EXIT_FAILURE


if __name__ == "__main__":
    sys.exit(main())
