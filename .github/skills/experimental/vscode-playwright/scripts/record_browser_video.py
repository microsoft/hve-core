#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Record a self-contained browser animation scene to a silent WebM clip."""

from __future__ import annotations

import argparse
import os
import sys
import tempfile
from pathlib import Path
from urllib.parse import urlparse

from playwright.sync_api import Error as PlaywrightError
from playwright.sync_api import Route, sync_playwright

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
MAX_DURATION_SECONDS = 600.0


class RecordingError(ValueError):
    """Raised when a browser scene cannot be recorded safely."""


def create_parser() -> argparse.ArgumentParser:
    """Create the command-line parser."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scene", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--duration", type=float, required=True)
    parser.add_argument("--resolution", default="1920x1080")
    return parser


def parse_resolution(value: str) -> tuple[int, int]:
    """Return positive width and height from ``WIDTHxHEIGHT``."""
    try:
        width_text, height_text = value.lower().split("x", 1)
        width, height = int(width_text), int(height_text)
    except (AttributeError, TypeError, ValueError) as exc:
        raise RecordingError("Resolution must use WIDTHxHEIGHT integers") from exc
    if width <= 0 or height <= 0:
        raise RecordingError("Resolution values must be greater than zero")
    return width, height


def validate_inputs(scene: Path, output: Path, duration: float) -> None:
    """Validate the scene, destination, and recording duration."""
    if not scene.is_file() or scene.suffix.lower() != ".html":
        raise RecordingError("Scene must be an existing HTML file")
    if output.suffix.lower() != ".webm":
        raise RecordingError("Output must use the .webm extension")
    if not 0 < duration <= MAX_DURATION_SECONDS:
        raise RecordingError(
            f"Duration must be between 0 and {MAX_DURATION_SECONDS:g} seconds"
        )


def _route_offline(route: Route) -> None:
    """Allow local scene resources and block network requests."""
    scheme = urlparse(route.request.url).scheme
    if scheme in {"file", "data", "blob", "about"}:
        route.continue_()
    else:
        route.abort()


def record_scene(
    scene: Path, output: Path, duration: float, resolution: str = "1920x1080"
) -> Path:
    """Record one ready-marked offline browser scene to ``output``."""
    scene = scene.resolve()
    output = output.resolve()
    validate_inputs(scene, output, duration)
    width, height = parse_resolution(resolution)
    output.parent.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(
        prefix="browser-video-", dir=str(output.parent)
    ) as temp_dir_name:
        temporary_output = Path(temp_dir_name) / "scene.webm"
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(headless=True)
            context = browser.new_context(
                viewport={"width": width, "height": height},
                record_video_dir=temp_dir_name,
                record_video_size={"width": width, "height": height},
            )
            page = context.new_page()
            page.route("**/*", _route_offline)
            page.goto(scene.as_uri(), wait_until="load")
            page.wait_for_function(
                "document.fonts ? document.fonts.status === 'loaded' : true"
            )
            page.wait_for_function("document.body?.dataset.animationReady === 'true'")
            video = page.video
            if video is None:
                raise RecordingError("Playwright did not create a video recorder")
            page.wait_for_timeout(round(duration * 1000))
            page.close()
            video.save_as(temporary_output)
            context.close()
            browser.close()

        if not temporary_output.is_file() or temporary_output.stat().st_size == 0:
            raise RecordingError("Playwright produced no browser video")
        os.replace(temporary_output, output)
    return output


def main(argv: list[str] | None = None) -> int:
    """Run the browser-scene recorder."""
    args = create_parser().parse_args(argv)
    try:
        result = record_scene(args.scene, args.output, args.duration, args.resolution)
    except (OSError, PlaywrightError, RecordingError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return EXIT_FAILURE
    print(result)
    return EXIT_SUCCESS


if __name__ == "__main__":
    sys.exit(main())
