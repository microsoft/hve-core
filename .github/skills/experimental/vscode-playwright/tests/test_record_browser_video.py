# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Tests for the offline browser-scene recorder."""

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

        def save_video(path):
            Path(path).write_bytes(b"webm")

        page.video.save_as.side_effect = save_video
        mocker.patch(
            "record_browser_video.sync_playwright", return_value=playwright_context
        )

        # Act
        result = record_scene(scene, output, 2.5, "640x360")

        # Assert
        assert result == output.resolve()
        assert output.read_bytes() == b"webm"
        page.goto.assert_called_once_with(scene.resolve().as_uri(), wait_until="load")
        page.wait_for_timeout.assert_called_once_with(2500)
        context.new_page.assert_called_once()
        page.video.save_as.assert_called_once()

    def test_given_network_request_when_routed_then_aborts(self, mocker):
        # Arrange
        from record_browser_video import _route_offline

        route = mocker.MagicMock()
        route.request.url = "https://example.com/asset.png"

        # Act
        _route_offline(route)

        # Assert
        route.abort.assert_called_once()
        route.continue_.assert_not_called()
