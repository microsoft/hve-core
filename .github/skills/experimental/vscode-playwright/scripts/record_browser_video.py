#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Record a self-contained browser animation scene to a silent WebM clip."""

from __future__ import annotations

import argparse
import math
import mimetypes
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from urllib.parse import quote, unquote, urlparse

from playwright.sync_api import Error as PlaywrightError
from playwright.sync_api import Route, sync_playwright

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
MAX_DURATION_SECONDS = 600.0
SCENE_ORIGIN = "https://scene.invalid"
FPS = 24


class RecordingError(ValueError):
    """Raised when a browser scene cannot be recorded safely."""


def create_parser() -> argparse.ArgumentParser:
    """Create the command-line parser."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scene", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--duration", type=float, required=True)
    parser.add_argument("--resolution", default="1920x1080")
    parser.add_argument("--asset-root", type=Path)
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


def _route_offline(route: Route, asset_root: Path) -> None:
    """Fulfill approved local assets at a synthetic origin; never use the network."""
    parsed = urlparse(route.request.url)
    if parsed.scheme != "https" or parsed.netloc != "scene.invalid":
        route.abort()
        return
    resource = (asset_root / unquote(parsed.path).lstrip("/")).resolve()
    if not resource.is_relative_to(asset_root) or not resource.is_file():
        route.abort()
        return
    route.fulfill(
        body=resource.read_bytes(),
        content_type=mimetypes.guess_type(resource.name)[0]
        or "application/octet-stream",
    )


def _encode_frames(frames: Path, output: Path, duration: float) -> None:
    """Encode only the requested ready-scene interval, with reset timestamps."""
    ffmpeg = shutil.which(os.environ.get("FFMPEG_COMMAND", "ffmpeg"))
    if not ffmpeg:
        raise RecordingError("FFmpeg is required to encode ready-scene frames")
    result = subprocess.run(
        [
            ffmpeg,
            "-y",
            "-v",
            "error",
            "-framerate",
            str(FPS),
            "-i",
            str(frames / "frame-%06d.png"),
            "-t",
            str(duration),
            "-c:v",
            "libvpx-vp9",
            "-pix_fmt",
            "yuv420p",
            "-an",
            str(output),
        ],
        capture_output=True,
        text=True,
        check=False,
        timeout=MAX_DURATION_SECONDS,
    )
    if result.returncode:
        raise RecordingError(
            f"Scene encoding failed (exit {result.returncode}): {result.stderr.strip()}"
        )


def record_scene(
    scene: Path,
    output: Path,
    duration: float,
    resolution: str = "1920x1080",
    asset_root: Path | None = None,
) -> Path:
    """Record one ready-marked offline browser scene to ``output``."""
    scene = scene.resolve()
    output = output.resolve()
    validate_inputs(scene, output, duration)
    width, height = parse_resolution(resolution)
    asset_root = (asset_root or scene.parent).resolve()
    if not scene.is_relative_to(asset_root):
        raise RecordingError("Scene must be inside the approved asset root")
    output.parent.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(
        prefix="browser-video-", dir=str(output.parent)
    ) as temp_dir_name:
        temporary_output = Path(temp_dir_name) / "scene.webm"
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(
                headless=True,
                args=[
                    "--disable-background-networking",
                    "--force-webrtc-ip-handling-policy=disable_non_proxied_udp",
                ],
            )
            context = browser.new_context(
                viewport={"width": width, "height": height},
                service_workers="block",
            )
            context.set_offline(True)
            context.route("**/*", lambda route: _route_offline(route, asset_root))
            context.route_web_socket(
                "**/*", lambda socket: socket.on_message(lambda _message: None)
            )
            page = context.new_page()
            context.on("page", lambda popup: popup.close())
            page.clock.install()
            page.goto(
                f"{SCENE_ORIGIN}/{quote(scene.relative_to(asset_root).as_posix())}",
                wait_until="load",
            )
            page.wait_for_function(
                "document.fonts ? document.fonts.status === 'loaded' : true"
            )
            page.wait_for_function("document.body?.dataset.animationReady === 'true'")
            page.clock.pause_at(page.evaluate("Date.now() / 1000 + 0.1"))
            if not page.evaluate("typeof window.startAnimation === 'function'"):
                raise RecordingError("Ready scenes must define window.startAnimation()")
            page.evaluate("window.startAnimation()")
            for frame in range(math.ceil(duration * FPS)):
                if frame:
                    page.clock.run_for(
                        round(frame * 1000 / FPS) - round((frame - 1) * 1000 / FPS)
                    )
                page.evaluate(
                    "time => document.getAnimations().forEach(animation => {"
                    "animation.pause(); animation.currentTime = time; })",
                    frame * 1000 / FPS,
                )
                page.screenshot(
                    path=str(Path(temp_dir_name) / f"frame-{frame:06d}.png")
                )
            page.close()
            context.close()
            browser.close()
        _encode_frames(Path(temp_dir_name), temporary_output, duration)

        if not temporary_output.is_file() or temporary_output.stat().st_size == 0:
            raise RecordingError("Playwright produced no browser video")
        os.replace(temporary_output, output)
    return output


def main(argv: list[str] | None = None) -> int:
    """Run the browser-scene recorder."""
    args = create_parser().parse_args(argv)
    try:
        result = record_scene(
            args.scene, args.output, args.duration, args.resolution, args.asset_root
        )
    except (OSError, PlaywrightError, RecordingError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return EXIT_FAILURE
    print(result)
    return EXIT_SUCCESS


if __name__ == "__main__":
    sys.exit(main())
