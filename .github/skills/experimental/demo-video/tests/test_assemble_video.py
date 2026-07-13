# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Tests for the demo-video manifest assembly module."""

from __future__ import annotations

from types import SimpleNamespace

import assemble_video
import pytest


@pytest.fixture()
def mock_ffmpeg_dependencies(mocker):
    mocker.patch.object(
        assemble_video,
        "_require_command",
        side_effect=lambda command: f"/usr/bin/{command}",
    )
    mocker.patch.object(assemble_video, "_run_ffmpeg")


class TestAssembleVideo:
    """Tests for the manifest-driven assembly workflow."""

    def test_given_valid_manifest_when_assemble_video_then_returns_output_path(
        self, tmp_path, mocker, mock_ffmpeg_dependencies
    ):
        # Arrange
        manifest_path = tmp_path / "segments.yml"
        output_path = tmp_path / "output" / "demo.mp4"
        visual_path = tmp_path / "intro.png"
        narration_path = tmp_path / "intro.wav"
        visual_path.write_bytes(b"png")
        narration_path.write_bytes(b"wav")
        manifest_path.write_text(
            "\n".join(
                [
                    "output: ./output/demo.mp4",
                    "resolution: 1280x720",
                    "fps: 24",
                    "segments:",
                    "  - type: frame",
                    f"    visual: {visual_path.name}",
                    f"    narration: {narration_path.name}",
                ]
            ),
            encoding="utf-8",
        )

        mocker.patch.object(assemble_video, "_probe_duration", return_value=1.25)
        mocker.patch.object(assemble_video, "_render_segment")

        # Act
        result = assemble_video.assemble_video(
            manifest_path=manifest_path,
            output_path=None,
            fps=None,
            resolution=None,
        )

        # Assert
        assert result == output_path.resolve()

    def test_given_duration_missing_when_assemble_video_then_uses_probe_duration(
        self, tmp_path, mocker, mock_ffmpeg_dependencies
    ):
        # Arrange
        manifest_path = tmp_path / "segments.yml"
        visual_path = tmp_path / "intro.png"
        narration_path = tmp_path / "intro.wav"
        visual_path.write_bytes(b"png")
        narration_path.write_bytes(b"wav")
        manifest_path.write_text(
            "\n".join(
                [
                    "segments:",
                    "  - type: frame",
                    f"    visual: {visual_path.name}",
                    f"    narration: {narration_path.name}",
                ]
            ),
            encoding="utf-8",
        )

        render_calls = []

        def fake_render_segment(*, segment, output_path, resolution, fps, ffmpeg_path):
            render_calls.append(segment["duration"])

        mocker.patch.object(assemble_video, "_probe_duration", return_value=2.5)
        mocker.patch.object(
            assemble_video,
            "_render_segment",
            side_effect=fake_render_segment,
        )

        # Act
        assemble_video.assemble_video(
            manifest_path=manifest_path,
            output_path=tmp_path / "demo.mp4",
            fps=None,
            resolution=None,
        )

        # Assert
        assert render_calls == [2.5]

    def test_given_explicit_duration_when_assemble_video_then_does_not_probe(
        self, tmp_path, mocker, mock_ffmpeg_dependencies
    ):
        # Arrange
        manifest_path = tmp_path / "segments.yml"
        visual_path = tmp_path / "intro.png"
        narration_path = tmp_path / "intro.wav"
        visual_path.write_bytes(b"png")
        narration_path.write_bytes(b"wav")
        manifest_path.write_text(
            "\n".join(
                [
                    "segments:",
                    "  - type: frame",
                    f"    visual: {visual_path.name}",
                    f"    narration: {narration_path.name}",
                    "    duration: 3.5",
                ]
            ),
            encoding="utf-8",
        )

        render_calls = []

        def fake_render_segment(*, segment, output_path, resolution, fps, ffmpeg_path):
            render_calls.append(segment["duration"])

        probe_mock = mocker.patch.object(
            assemble_video,
            "_probe_duration",
            return_value=9.9,
        )
        mocker.patch.object(
            assemble_video,
            "_render_segment",
            side_effect=fake_render_segment,
        )

        # Act
        assemble_video.assemble_video(
            manifest_path=manifest_path,
            output_path=tmp_path / "demo.mp4",
            fps=None,
            resolution=None,
        )

        # Assert
        assert render_calls == [3.5]
        probe_mock.assert_not_called()

    def test_given_frame_segment_when_render_segment_then_uses_image_branch(
        self, tmp_path, mocker
    ):
        # Arrange
        output_path = tmp_path / "frame.mp4"
        command_calls = []
        mocker.patch.object(
            assemble_video,
            "_run_ffmpeg",
            side_effect=lambda command: command_calls.append(command),
        )

        # Act
        assemble_video._render_segment(
            segment={
                "visual": "frame.png",
                "narration": "narration.wav",
                "duration": 1.0,
            },
            output_path=output_path,
            resolution="1280x720",
            fps=24,
            ffmpeg_path="/usr/bin/ffmpeg",
        )

        # Assert
        assert command_calls
        assert "-loop" in command_calls[0]
        assert command_calls[0][command_calls[0].index("-loop") + 1] == "1"
        assert str(output_path) in command_calls[0]

    def test_given_clip_segment_when_render_segment_then_uses_clip_branch(
        self, tmp_path, mocker
    ):
        # Arrange
        output_path = tmp_path / "clip.mp4"
        command_calls = []
        mocker.patch.object(
            assemble_video,
            "_run_ffmpeg",
            side_effect=lambda command: command_calls.append(command),
        )

        # Act
        assemble_video._render_segment(
            segment={
                "clip": "clip.mp4",
                "narration": "narration.wav",
                "duration": 2.0,
            },
            output_path=output_path,
            resolution="1280x720",
            fps=24,
            ffmpeg_path="/usr/bin/ffmpeg",
        )

        # Assert
        assert command_calls
        assert "-loop" not in command_calls[0]
        assert "-map" in command_calls[0]
        assert str(output_path) in command_calls[0]

    def test_given_missing_file_when_assemble_video_then_raises_manifest_error(
        self, tmp_path, mock_ffmpeg_dependencies
    ):
        # Arrange
        manifest_path = tmp_path / "segments.yml"
        narration_path = tmp_path / "narration.wav"
        narration_path.write_bytes(b"wav")
        manifest_path.write_text(
            "output: demo.mp4\n"
            "segments:\n"
            "  - type: frame\n"
            "    visual: missing.png\n"
            "    narration: narration.wav\n",
            encoding="utf-8",
        )

        # Act / Assert
        with pytest.raises(assemble_video.ManifestError, match="Visual file not found"):
            assemble_video.assemble_video(
                manifest_path=manifest_path,
                output_path=None,
                fps=None,
                resolution=None,
            )

    def test_given_empty_segments_when_validate_manifest_then_raises(self, tmp_path):
        # Arrange
        manifest_path = tmp_path / "segments.yml"
        manifest_path.write_text("segments: []\n", encoding="utf-8")

        # Act / Assert
        with pytest.raises(assemble_video.ManifestError, match="non-empty 'segments'"):
            assemble_video._validate_manifest(
                assemble_video._read_manifest(manifest_path),
            )

    def test_given_unknown_segment_key_when_validate_manifest_then_raises(
        self, tmp_path
    ):
        # Arrange
        manifest_path = tmp_path / "segments.yml"
        manifest_path.write_text(
            "segments:\n  - narration: intro.wav\n    unknown: false\n",
            encoding="utf-8",
        )

        # Act / Assert
        with pytest.raises(assemble_video.ManifestError, match="unsupported keys"):
            assemble_video._validate_manifest(
                assemble_video._read_manifest(manifest_path),
            )

    def test_given_type_mismatched_source_when_validate_manifest_then_raises(
        self, tmp_path
    ):
        # Arrange
        manifest_path = tmp_path / "segments.yml"
        manifest_path.write_text(
            "segments:\n"
            "  - type: frame\n"
            "    clip: motion.mp4\n"
            "    narration: intro.wav\n",
            encoding="utf-8",
        )

        # Act / Assert
        with pytest.raises(
            assemble_video.ManifestError, match="declares type 'frame'"
        ):
            assemble_video._validate_manifest(
                assemble_video._read_manifest(manifest_path),
            )

    def test_given_non_positive_fps_when_assemble_video_then_raises(
        self, tmp_path, mock_ffmpeg_dependencies
    ):
        # Arrange
        manifest_path = tmp_path / "segments.yml"
        visual_path = tmp_path / "intro.png"
        narration_path = tmp_path / "intro.wav"
        visual_path.write_bytes(b"png")
        narration_path.write_bytes(b"wav")
        manifest_path.write_text(
            "output: demo.mp4\n"
            "segments:\n"
            "  - visual: intro.png\n"
            "    narration: intro.wav\n"
            "    duration: 1.0\n",
            encoding="utf-8",
        )

        # Act / Assert
        with pytest.raises(
            assemble_video.ManifestError, match="Frame rate must be greater than zero"
        ):
            assemble_video.assemble_video(
                manifest_path=manifest_path,
                output_path=tmp_path / "demo.mp4",
                fps=0,
                resolution=None,
            )

    def test_given_subprocess_run_when_ffmpeg_command_then_uses_list_args_without_shell(
        self, mocker
    ):
        # Arrange
        run_mock = mocker.patch(
            "assemble_video.subprocess.run",
            return_value=SimpleNamespace(returncode=0, stdout="", stderr=""),
        )

        # Act
        assemble_video._run_ffmpeg(["/usr/bin/ffmpeg", "-i", "input.mp4", "output.mp4"])

        # Assert
        assert run_mock.call_count == 1
        args, kwargs = run_mock.call_args
        assert isinstance(args[0], list)
        assert kwargs.get("shell") is not True
