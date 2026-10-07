# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Tests for the offline browser-scene recorder."""

import os
import shutil
import subprocess
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

import pytest
from record_browser_video import RecordingError, parse_resolution, record_scene


class TestRecordBrowserVideo:
    """Tests for record_scene."""

    @pytest.mark.parametrize(
        ("value", "expected"),
        [("1920x1080", (1920, 1080)), ("640X360", (640, 360))],
    )
    def test_given_resolution_when_parsed_then_returns_dimensions(
        self, value, expected
    ):
        assert parse_resolution(value) == expected

    @pytest.mark.parametrize("value", ["wide", "0x1080", "1920x-1"])
    def test_given_invalid_resolution_when_parsed_then_raises(self, value):
        with pytest.raises(RecordingError):
            parse_resolution(value)

    def test_given_offline_scene_when_recorded_then_writes_webm(self, tmp_path, mocker):
        # Arrange
        scene = tmp_path / "scene.html"
        scene.write_text(
            '<body data-animation-ready="true">Scene</body>', encoding="utf-8"
        )
        output = tmp_path / "clips" / "scene.webm"
        playwright_context = mocker.MagicMock()
        playwright = playwright_context.__enter__.return_value
        context = playwright.chromium.launch.return_value.new_context.return_value
        page = context.new_page.return_value

        def encode_frames(_frames, destination, _duration):
            destination.write_bytes(b"webm")

        mocker.patch("record_browser_video._encode_frames", side_effect=encode_frames)
        mocker.patch(
            "record_browser_video.sync_playwright", return_value=playwright_context
        )

        # Act
        result = record_scene(scene, output, 2.5, "640x360")

        # Assert
        assert result == output.resolve()
        assert output.read_bytes() == b"webm"
        page.goto.assert_called_once_with(
            "https://scene.invalid/scene.html", wait_until="load"
        )
        context.set_offline.assert_called_once_with(True)
        context.route_web_socket.assert_called_once()
        assert page.screenshot.call_count == 60
        page.wait_for_timeout.assert_not_called()
        context.new_page.assert_called_once()

    def test_given_network_request_when_routed_then_aborts(self, mocker, tmp_path):
        # Arrange
        from record_browser_video import _route_offline

        route = mocker.MagicMock()
        route.request.url = "https://example.com/asset.png"

        # Act
        _route_offline(route, tmp_path)

        # Assert
        route.abort.assert_called_once()
        route.continue_.assert_not_called()

    def test_given_delayed_ready_scene_when_recorded_then_no_startup_or_egress(
        self, tmp_path
    ):
        from playwright.sync_api import sync_playwright

        ffmpeg = shutil.which(os.environ.get("FFMPEG_COMMAND", "ffmpeg"))
        with sync_playwright() as playwright:
            available = Path(playwright.chromium.executable_path).is_file()
        if not ffmpeg or not available:
            pytest.skip(
                "Requires existing Chromium and FFmpeg; no installation attempted"
            )
        requests = []

        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                requests.append(self.path)
                self.send_response(200)
                self.end_headers()

            def log_message(self, *_args):
                pass

        server = HTTPServer(("127.0.0.1", 0), Handler)
        worker = threading.Thread(target=server.serve_forever, daemon=True)
        worker.start()
        scene = tmp_path / "scene.html"
        endpoint = f"127.0.0.1:{server.server_port}"
        scene.write_text(
            '<body style="margin:0;background:black;height:100vh">'
            "<script>setTimeout(() => "
            'document.body.dataset.animationReady="true", 250);'
            'window.startAnimation=()=>{document.body.style.background="red";'
            'setTimeout(()=>document.body.style.background="blue",750);'
            f'fetch("http://{endpoint}/fetch").catch(()=>{{}});'
            f'window.open("http://{endpoint}/popup");'
            f'new WebSocket("ws://{endpoint}/socket");'
            "};</script></body>",
            encoding="utf-8",
        )
        output = tmp_path / "scene.webm"
        try:
            record_scene(scene, output, 1, "320x180")
        finally:
            server.shutdown()
            server.server_close()
            worker.join(timeout=5)
        assert requests == []
        pixels = []
        for timestamp in (0, 0.9):
            pixels.append(
                subprocess.run(
                    [
                        ffmpeg,
                        "-v",
                        "error",
                        "-ss",
                        str(timestamp),
                        "-i",
                        str(output),
                        "-frames:v",
                        "1",
                        "-vf",
                        "scale=1:1",
                        "-pix_fmt",
                        "rgb24",
                        "-f",
                        "rawvideo",
                        "-",
                    ],
                    capture_output=True,
                    check=True,
                ).stdout
            )
        assert pixels[0][0] > 200 and pixels[0][2] < 50
        assert pixels[1][2] > 200 and pixels[1][0] < 50

    @pytest.mark.parametrize("resource", ["../private.png", "%2e%2e/private.png"])
    def test_given_escaping_resource_when_routed_then_aborts(
        self, tmp_path, mocker, resource
    ):
        from record_browser_video import _route_offline

        assets = tmp_path / "assets"
        assets.mkdir()
        (tmp_path / "private.png").write_bytes(b"private")
        route = mocker.MagicMock()
        route.request.url = f"https://scene.invalid/{resource}"

        _route_offline(route, assets)

        route.abort.assert_called_once()
        route.fulfill.assert_not_called()

    def test_given_allowed_asset_when_routed_then_fulfills_without_network(
        self, tmp_path, mocker
    ):
        from record_browser_video import _route_offline

        (tmp_path / "scene.html").write_text("<body>Scene</body>", encoding="utf-8")
        route = mocker.MagicMock()
        route.request.url = "https://scene.invalid/scene.html"

        _route_offline(route, tmp_path)

        route.fulfill.assert_called_once()
        route.continue_.assert_not_called()

    def test_given_escaping_symlink_when_routed_then_never_reads_private_asset(
        self, tmp_path, mocker
    ):
        from record_browser_video import _route_offline

        assets = tmp_path / "approved"
        assets.mkdir()
        private = tmp_path / "private.png"
        private.write_bytes(b"fixture private image")
        (assets / "link.png").symlink_to(private)
        route = mocker.MagicMock()
        route.request.url = "https://scene.invalid/link.png"

        _route_offline(route, assets)

        route.abort.assert_called_once()
        route.fulfill.assert_not_called()
