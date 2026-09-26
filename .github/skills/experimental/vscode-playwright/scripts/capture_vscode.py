#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Capture measured VS Code Web screenshots from a YAML capture plan.

Starts ``serve-web``, drives it headless with Playwright, opens each planned
file in the Monaco editor, raises zoom until the rendered font clears the
readability floor, and writes one screenshot per capture.

Playwright is driven directly rather than through an MCP server, so the same
script runs on a developer machine and on a CI runner.

Usage::

    python capture_vscode.py --plan capture-plan.yml --workspace /path/to/repo

Exit code:
    0 - every capture was written and met the readability floor
    1 - a capture failed, fell below the floor, or the harness errored

Prints a single JSON object on the last stdout line::

    {"ok": bool, "captures": [...], "errors": [str, ...]}
"""

from __future__ import annotations

import argparse
import contextlib
import json
import os
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path

import yaml

EXIT_SUCCESS = 0
EXIT_FAILURE = 1

DEFAULT_WIDTH = 1920
DEFAULT_HEIGHT = 1080
DEFAULT_MIN_FONT_PT = 18.0
DEFAULT_FONT_SIZE_PX = 26
DEFAULT_START_ZOOM = 1.0
MAX_ZOOM = 4.0
ZOOM_STEP = 0.25
CSS_PX_TO_PT = 0.75
SERVER_READY_TIMEOUT_S = 180
UI_SETTLE_MS = 700

# Markdown opens as a cross-origin preview webview whose font cannot be read.
UNMEASURABLE_SUFFIXES = frozenset({".md", ".markdown"})


class PlanError(ValueError):
    """Raised when the capture plan is missing or malformed."""


def read_plan(path: Path) -> dict:
    """Load a capture plan YAML file into a dict."""
    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
    except (OSError, yaml.YAMLError) as exc:
        raise PlanError(f"cannot read capture plan {path}: {exc}") from exc
    if not isinstance(data, dict):
        raise PlanError("capture plan must be a YAML mapping")
    return data


def validate_plan(data: dict) -> tuple[dict, list[dict]]:
    """Validate and normalize a capture plan into settings and captures."""
    raw_captures = data.get("captures")
    if not isinstance(raw_captures, list) or not raw_captures:
        raise PlanError("capture plan requires a non-empty 'captures' list")

    width, height = _parse_resolution(data.get("resolution", "1920x1080"))
    min_font_pt = _as_positive_float(
        data.get("min_font_pt", DEFAULT_MIN_FONT_PT), "min_font_pt"
    )
    start_zoom = _as_positive_float(
        data.get("start_zoom", DEFAULT_START_ZOOM), "start_zoom"
    )
    font_size = data.get("font_size", DEFAULT_FONT_SIZE_PX)
    if not isinstance(font_size, int) or isinstance(font_size, bool) or font_size < 8:
        raise PlanError("'font_size' must be an integer of at least 8")

    settings = {
        "width": width,
        "height": height,
        "min_font_pt": min_font_pt,
        "start_zoom": start_zoom,
        "font_size": font_size,
        "theme": str(data.get("theme", "Default Dark Modern")),
    }

    seen_ids: set[str] = set()
    captures: list[dict] = []
    for index, item in enumerate(raw_captures):
        if not isinstance(item, dict):
            raise PlanError(f"capture {index} must be a mapping")
        capture_id = item.get("id")
        target = item.get("file")
        output = item.get("output")
        for field, value in (("id", capture_id), ("file", target), ("output", output)):
            if not isinstance(value, str) or not value.strip():
                raise PlanError(f"capture {index} requires a non-empty '{field}'")
        if capture_id in seen_ids:
            raise PlanError(f"duplicate capture id '{capture_id}'")
        seen_ids.add(capture_id)
        if Path(target).suffix.lower() in UNMEASURABLE_SUFFIXES:
            raise PlanError(
                f"capture '{capture_id}' targets markdown ({target}); markdown "
                "opens as a preview webview whose font size cannot be measured, "
                "so target a code or config file instead"
            )
        line = item.get("line", 1)
        if not isinstance(line, int) or line < 1:
            raise PlanError(f"capture '{capture_id}' 'line' must be a positive int")
        captures.append(
            {"id": capture_id, "file": target, "output": output, "line": line}
        )
    return settings, captures


def _parse_resolution(value) -> tuple[int, int]:
    if not isinstance(value, str) or "x" not in value:
        raise PlanError("resolution must look like WIDTHxHEIGHT")
    width_text, _, height_text = value.lower().partition("x")
    try:
        width, height = int(width_text), int(height_text)
    except ValueError as exc:
        raise PlanError("resolution must look like WIDTHxHEIGHT") from exc
    if width <= 0 or height <= 0:
        raise PlanError("resolution dimensions must be positive")
    return width, height


def _as_positive_float(value, name: str) -> float:
    try:
        number = float(value)
    except (TypeError, ValueError) as exc:
        raise PlanError(f"'{name}' must be a number") from exc
    if number <= 0:
        raise PlanError(f"'{name}' must be positive")
    return number


def rendered_font_pt(pre_zoom_px: float, post_zoom_px: float, zoom: float) -> float:
    """Return the rendered font size in points, counting zoom exactly once.

    When the host folds CSS zoom into the computed value, the post-zoom
    reading already includes it. Otherwise zoom is applied to the pre-zoom
    reading. Multiplying a folded reading by zoom again would inflate it.
    """
    effective_px = post_zoom_px if post_zoom_px != pre_zoom_px else pre_zoom_px * zoom
    return round(effective_px * CSS_PX_TO_PT, 2)


def _free_port() -> int:
    with contextlib.closing(socket.socket(socket.AF_INET, socket.SOCK_STREAM)) as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def _resolve_cli(explicit: str | None) -> str:
    candidates = [explicit] if explicit else ["code-insiders", "code"]
    for candidate in candidates:
        if candidate and shutil.which(candidate):
            return candidate
    raise RuntimeError(
        "VS Code CLI not found; install 'code' or 'code-insiders' or pass --cli"
    )


def _wait_for_server(url: str, timeout_s: int) -> None:
    deadline = time.monotonic() + timeout_s
    while time.monotonic() < deadline:
        try:
            with urllib.request.urlopen(url, timeout=5) as response:
                if response.status == 200:
                    return
        except (urllib.error.URLError, OSError):
            pass
        time.sleep(2)
    raise RuntimeError(f"serve-web did not become ready within {timeout_s}s")


@contextlib.contextmanager
def serve_web(cli: str, port: int, data_dir: Path):
    """Run ``serve-web`` for the duration of the block."""
    # serve-web answers 202 while downloading the inner server on first run.
    process = subprocess.Popen(
        [
            cli,
            "serve-web",
            "--port",
            str(port),
            "--without-connection-token",
            "--accept-server-license-terms",
            "--server-data-dir",
            str(data_dir),
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    try:
        _wait_for_server(f"http://127.0.0.1:{port}/", SERVER_READY_TIMEOUT_S)
        yield
    finally:
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()


def _run_command(page, command: str) -> None:
    page.keyboard.press("F1")
    box = page.locator(".quick-input-box input")
    box.wait_for(state="visible", timeout=10_000)
    box.press_sequentially(command, delay=15)
    page.wait_for_timeout(UI_SETTLE_MS)
    page.keyboard.press("Enter")
    page.wait_for_timeout(UI_SETTLE_MS)


def _open_file(page, relative_path: str) -> None:
    _run_command(page, "Go to File...")
    box = page.locator(".quick-input-box input")
    box.wait_for(state="visible", timeout=10_000)
    box.press_sequentially(relative_path, delay=15)
    # Wait for the picker to filter to a match before accepting it.
    page.locator(".quick-input-list .monaco-list-row").first.wait_for(
        state="visible", timeout=15_000
    )
    page.wait_for_timeout(UI_SETTLE_MS)
    page.keyboard.press("Enter")
    page.locator(".part.editor .monaco-editor .view-line").first.wait_for(
        state="visible", timeout=20_000
    )


def capture_settings(theme: str, font_size: int) -> dict:
    """Return the VS Code user settings applied before capturing."""
    return {
        "workbench.colorTheme": theme,
        "window.autoDetectColorScheme": False,
        "security.workspace.trust.enabled": False,
        "workbench.activityBar.location": "hidden",
        "workbench.statusBar.visible": False,
        "workbench.startupEditor": "none",
        "workbench.editor.showTabs": "single",
        "breadcrumbs.enabled": False,
        "window.commandCenter": False,
        "editor.fontSize": font_size,
        "editor.lineHeight": 1.5,
        "editor.minimap.enabled": False,
        "editor.stickyScroll.enabled": False,
        "editor.renderLineHighlight": "none",
        "editor.guides.indentation": False,
        "editor.links": False,
        "telemetry.telemetryLevel": "off",
    }


def _apply_settings(page, settings: dict) -> None:
    # VS Code Web keeps settings in IndexedDB, so write them via the editor.
    # Paste bypasses EditContext key handling and bracket auto-closing.
    _run_command(page, "Preferences: Open User Settings (JSON)")
    # Scope to the editor part: chat renders hidden .monaco-editor widgets too.
    editor = page.locator(".part.editor .monaco-editor .view-lines").first
    editor.wait_for(state="visible", timeout=20_000)
    editor.click()
    page.keyboard.press("ControlOrMeta+a")
    page.keyboard.press("Delete")
    payload = json.dumps(settings, indent=2)
    page.evaluate(
        """(text) => {
            const data = new DataTransfer();
            data.setData('text/plain', text);
            document.activeElement.dispatchEvent(
                new ClipboardEvent('paste', {clipboardData: data, bubbles: true})
            );
        }""",
        payload,
    )
    page.wait_for_timeout(UI_SETTLE_MS)
    page.keyboard.press("ControlOrMeta+s")
    page.wait_for_timeout(2 * UI_SETTLE_MS)
    # Reload closes the modal settings editor and applies window-level settings
    # such as workspace trust; the persistent context keeps them in IndexedDB.
    page.reload(wait_until="domcontentloaded")
    page.locator(".monaco-workbench").wait_for(state="visible", timeout=60_000)
    page.wait_for_timeout(3_000)


def _assert_dark_theme(page) -> None:
    # Fail loudly: a light capture silently clashes with the dark deck.
    is_dark = page.evaluate(
        "() => document.querySelector('.monaco-workbench')"
        ".classList.contains('vs-dark')"
    )
    if not is_dark:
        raise RuntimeError(
            "dark theme did not apply; the workbench is still in a light theme"
        )


def _prepare_workbench(page, settings: dict) -> None:
    page.locator(".monaco-workbench").wait_for(state="visible", timeout=60_000)
    page.wait_for_timeout(3_000)
    _apply_settings(page, capture_settings(settings["theme"], settings["font_size"]))
    _assert_dark_theme(page)
    for command in (
        "View: Close All Editors",
        "Notifications: Clear All Notifications",
    ):
        with contextlib.suppress(Exception):
            _run_command(page, command)


def _hide_side_bars(page) -> None:
    # Toggle commands flip state, so only act on bars that are visible.
    for selector, command in (
        (".part.sidebar", "View: Close Primary Side Bar"),
        (".part.auxiliarybar", "View: Close Secondary Side Bar"),
        (".part.panel", "View: Close Panel"),
    ):
        with contextlib.suppress(Exception):
            if page.locator(selector).first.is_visible():
                _run_command(page, command)


def _read_font_px(page) -> float:
    return page.evaluate(
        """() => {
            const el = document.querySelector(
                '.part.editor .monaco-editor .view-line span'
            ) || document.querySelector('.part.editor .monaco-editor .view-line');
            return el ? parseFloat(getComputedStyle(el).fontSize) : 0;
        }"""
    )


def _set_zoom(page, zoom: float) -> None:
    page.evaluate("(z) => { document.body.style.zoom = String(z); }", zoom)
    page.wait_for_timeout(UI_SETTLE_MS)


def measure_and_fit(page, start_zoom: float, min_font_pt: float) -> dict:
    """Raise zoom until the measured font clears the floor, then report it."""
    _set_zoom(page, 1.0)
    pre_px = _read_font_px(page)
    if pre_px <= 0:
        raise RuntimeError("no Monaco .view-line found to measure")
    zoom = start_zoom
    while True:
        _set_zoom(page, zoom)
        post_px = _read_font_px(page)
        font_pt = rendered_font_pt(pre_px, post_px, zoom)
        if font_pt >= min_font_pt or zoom >= MAX_ZOOM:
            return {
                "zoom": zoom,
                "pre_zoom_px": pre_px,
                "post_zoom_px": post_px,
                "rendered_font_size_pt": font_pt,
            }
        zoom = round(zoom + ZOOM_STEP, 2)


def run_captures(
    plan_path: Path, workspace: Path, output_root: Path, cli: str | None
) -> dict:
    """Execute every capture in the plan and return a result summary."""
    settings, captures = validate_plan(read_plan(plan_path))
    from playwright.sync_api import sync_playwright

    port = _free_port()
    results: list[dict] = []
    errors: list[str] = []
    with tempfile.TemporaryDirectory(prefix="vscode-capture-") as tmp:
        tmp_path = Path(tmp)
        with serve_web(_resolve_cli(cli), port, tmp_path / "server"):
            with sync_playwright() as playwright:
                # Persistent context keeps VS Code's IndexedDB settings stable.
                context = playwright.chromium.launch_persistent_context(
                    str(tmp_path / "browser"),
                    headless=True,
                    viewport={"width": settings["width"], "height": settings["height"]},
                )
                try:
                    page = context.pages[0] if context.pages else context.new_page()
                    page.goto(
                        f"http://127.0.0.1:{port}/?folder={workspace.resolve()}",
                        wait_until="domcontentloaded",
                    )
                    _prepare_workbench(page, settings)
                    for capture in captures:
                        results.append(
                            _capture_one(page, capture, settings, output_root, errors)
                        )
                finally:
                    context.close()

    ok = not errors and all(r.get("meets_floor") for r in results)
    return {"ok": ok, "captures": results, "errors": errors}


def _capture_one(
    page, capture: dict, settings: dict, output_root: Path, errors: list[str]
) -> dict:
    result = {"capture_id": capture["id"], "monaco_target": capture["file"]}
    try:
        _set_zoom(page, 1.0)
        with contextlib.suppress(Exception):
            _run_command(page, "View: Close All Editors")
        _open_file(page, capture["file"])
        if capture["line"] > 1:
            _run_command(page, "Go to Line/Column...")
            page.keyboard.type(str(capture["line"]))
            page.keyboard.press("Enter")
        _hide_side_bars(page)
        measurement = measure_and_fit(
            page, settings["start_zoom"], settings["min_font_pt"]
        )
        output_path = output_root / capture["output"]
        output_path.parent.mkdir(parents=True, exist_ok=True)
        page.screenshot(path=str(output_path))
        result.update(measurement)
        result.update(
            {
                "path": capture["output"],
                "source_resolution": f"{settings['width']}x{settings['height']}",
                "meets_floor": measurement["rendered_font_size_pt"]
                >= settings["min_font_pt"],
            }
        )
        if not result["meets_floor"]:
            errors.append(
                f"{capture['id']}: {measurement['rendered_font_size_pt']} pt is "
                f"below the {settings['min_font_pt']} pt floor at max zoom"
            )
    except Exception as exc:  # noqa: BLE001 - reported per capture, not raised
        result["meets_floor"] = False
        debug_path = output_root / f"debug-{capture['id']}.png"
        with contextlib.suppress(Exception):
            debug_path.parent.mkdir(parents=True, exist_ok=True)
            page.screenshot(path=str(debug_path))
            result["debug_screenshot"] = str(debug_path)
        errors.append(f"{capture['id']}: {exc}")
    return result


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--plan", required=True, type=Path, help="Capture plan YAML")
    parser.add_argument(
        "--workspace", required=True, type=Path, help="Folder opened in VS Code"
    )
    parser.add_argument(
        "--output-root",
        type=Path,
        help="Base directory for capture outputs (default: the plan's directory)",
    )
    parser.add_argument("--cli", help="VS Code CLI to run (default: auto-detect)")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    output_root = args.output_root or args.plan.parent
    try:
        summary = run_captures(args.plan, args.workspace, output_root, args.cli)
    except PlanError as exc:
        summary = {"ok": False, "captures": [], "errors": [f"plan: {exc}"]}
    except Exception as exc:  # noqa: BLE001 - surfaced as a JSON result
        summary = {"ok": False, "captures": [], "errors": [f"harness: {exc}"]}
    print(json.dumps(summary))
    return EXIT_SUCCESS if summary["ok"] else EXIT_FAILURE


if __name__ == "__main__":
    os.environ.setdefault("PYTHONUNBUFFERED", "1")
    sys.exit(main())
