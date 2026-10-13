# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Subprocess, output-integrity, and cleanup tests for the demo-video assembler.

FFmpeg and ffprobe are replaced with an in-process fake for ``subprocess.run``;
inputs are byte stubs, so no media tools or media files are required.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import assemble_video
import pytest


def _write_inputs(base_dir: Path, *, duration: float | None = 1.0) -> Path:
    """Write a one-segment manifest with stub inputs and return its path."""
    base_dir.mkdir(parents=True, exist_ok=True)
    (base_dir / "intro.png").write_bytes(b"png")
    (base_dir / "intro.wav").write_bytes(b"wav")
    lines = [
        "segments:",
        "  - type: frame",
        "    visual: intro.png",
        "    narration: intro.wav",
    ]
    if duration is not None:
        lines.append(f"    duration: {duration}")
    manifest_path = base_dir / "segments.yml"
    manifest_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return manifest_path


class FakeFfmpeg:
    """Programmable stand-in for ``subprocess.run`` covering ffmpeg and ffprobe."""

    def __init__(self) -> None:
        self.calls: list[tuple[list[str], dict]] = []
        self.concat_list: str | None = None
        self.concat_returncode = 0
        self.concat_partial_bytes: bytes | None = None
        self.raise_on_call: BaseException | None = None
        self.probe_stdout = "1.5"

    def __call__(self, command, **kwargs):
        self.calls.append((list(command), kwargs))
        if self.raise_on_call is not None:
            raise self.raise_on_call
        if str(command[0]).endswith("ffprobe"):
            return subprocess.CompletedProcess(command, 0, self.probe_stdout, "")
        if "concat" in command:
            list_path = Path(command[command.index("-i") + 1])
            self.concat_list = list_path.read_text(encoding="utf-8")
            if self.concat_partial_bytes is not None:
                Path(command[-1]).write_bytes(self.concat_partial_bytes)
            if self.concat_returncode != 0:
                return subprocess.CompletedProcess(
                    command, self.concat_returncode, "", "Invalid data found"
                )
        Path(command[-1]).write_bytes(b"mp4")
        return subprocess.CompletedProcess(command, 0, "", "")


@pytest.fixture()
def fake_ffmpeg(mocker):
    fake = FakeFfmpeg()
    mocker.patch.object(
        assemble_video,
        "_require_command",
        side_effect=lambda command: f"/usr/bin/{command}",
    )
    mocker.patch("assemble_video.subprocess.run", side_effect=fake)
    return fake


def _leftover_temp_dirs(directory: Path) -> list[Path]:
    return [path for path in directory.glob("demo-video-*") if path.is_dir()]


class TestSubprocessTimeout:
    """Every external call is bounded by the configured timeout."""

    def test_given_ffmpeg_times_out_when_assemble_video_then_raises_manifest_error(
        self, tmp_path, fake_ffmpeg
    ):
        # Arrange
        manifest_path = _write_inputs(tmp_path)
        fake_ffmpeg.raise_on_call = subprocess.TimeoutExpired(["ffmpeg"], 5)

        # Act / Assert
        with pytest.raises(assemble_video.ManifestError, match="timed out after 5"):
            assemble_video.assemble_video(
                manifest_path=manifest_path,
                output_path=tmp_path / "demo.mp4",
                fps=None,
                resolution=None,
                timeout=5,
            )

    def test_given_ffprobe_times_out_when_probe_duration_then_raises_manifest_error(
        self, tmp_path, fake_ffmpeg
    ):
        # Arrange
        audio_path = tmp_path / "intro.wav"
        audio_path.write_bytes(b"wav")
        fake_ffmpeg.raise_on_call = subprocess.TimeoutExpired(["ffprobe"], 3)

        # Act / Assert
        with pytest.raises(assemble_video.ManifestError, match="timed out after 3"):
            assemble_video._probe_duration(audio_path, timeout=3)

    def test_given_no_timeout_flag_when_parse_args_then_defaults_to_600(self):
        # Act
        args = assemble_video.create_parser().parse_args(["--manifest", "m.yml"])

        # Assert
        assert args.timeout == 600

    @pytest.mark.parametrize("timeout", [0, 86401])
    def test_given_out_of_range_timeout_when_assemble_video_then_raises(
        self, tmp_path, fake_ffmpeg, timeout
    ):
        # Arrange
        manifest_path = _write_inputs(tmp_path)

        # Act / Assert
        with pytest.raises(assemble_video.ManifestError, match="Timeout"):
            assemble_video.assemble_video(
                manifest_path=manifest_path,
                output_path=tmp_path / "demo.mp4",
                fps=None,
                resolution=None,
                timeout=timeout,
            )

    def test_given_timeout_when_assemble_video_then_every_subprocess_receives_timeout(
        self, tmp_path, fake_ffmpeg
    ):
        # Arrange
        manifest_path = _write_inputs(tmp_path, duration=None)

        # Act
        assemble_video.assemble_video(
            manifest_path=manifest_path,
            output_path=tmp_path / "demo.mp4",
            fps=None,
            resolution=None,
            timeout=5,
        )

        # Assert
        assert fake_ffmpeg.calls
        assert all(kwargs.get("timeout") == 5 for _, kwargs in fake_ffmpeg.calls)


class TestMalformedMedia:
    """Decoder and probe failures surface as typed manifest errors."""

    def test_given_ffmpeg_rejects_input_when_assemble_video_then_raises_with_stderr(
        self, tmp_path, fake_ffmpeg
    ):
        # Arrange
        manifest_path = _write_inputs(tmp_path)
        fake_ffmpeg.concat_returncode = 1

        # Act / Assert
        with pytest.raises(assemble_video.ManifestError, match="Invalid data found"):
            assemble_video.assemble_video(
                manifest_path=manifest_path,
                output_path=tmp_path / "demo.mp4",
                fps=None,
                resolution=None,
            )

    @pytest.mark.parametrize(
        ("probe_stdout", "message"),
        [("N/A", "Unable to parse"), ("0", "must be positive")],
    )
    def test_given_unusable_probe_output_when_probe_duration_then_raises(
        self, tmp_path, fake_ffmpeg, probe_stdout, message
    ):
        # Arrange
        audio_path = tmp_path / "intro.wav"
        audio_path.write_bytes(b"wav")
        fake_ffmpeg.probe_stdout = probe_stdout

        # Act / Assert
        with pytest.raises(assemble_video.ManifestError, match=message):
            assemble_video._probe_duration(audio_path)


class TestOutputIntegrity:
    """The final MP4 is published only after a successful concat."""

    def test_given_concat_fails_after_partial_write_when_assemble_video_then_no_output(
        self, tmp_path, fake_ffmpeg
    ):
        # Arrange
        manifest_path = _write_inputs(tmp_path)
        output_path = tmp_path / "out" / "demo.mp4"
        fake_ffmpeg.concat_partial_bytes = b"partial"
        fake_ffmpeg.concat_returncode = 1

        # Act
        with pytest.raises(assemble_video.ManifestError):
            assemble_video.assemble_video(
                manifest_path=manifest_path,
                output_path=output_path,
                fps=None,
                resolution=None,
            )

        # Assert
        assert not output_path.exists()

    def test_given_existing_output_when_assemble_video_succeeds_then_output_replaced(
        self, tmp_path, fake_ffmpeg
    ):
        # Arrange
        manifest_path = _write_inputs(tmp_path)
        output_path = tmp_path / "demo.mp4"
        output_path.write_bytes(b"previous")

        # Act
        result = assemble_video.assemble_video(
            manifest_path=manifest_path,
            output_path=output_path,
            fps=None,
            resolution=None,
        )

        # Assert
        assert result.read_bytes() == b"mp4"

    def test_given_existing_output_when_concat_fails_then_existing_output_unchanged(
        self, tmp_path, fake_ffmpeg
    ):
        # Arrange
        manifest_path = _write_inputs(tmp_path)
        output_path = tmp_path / "demo.mp4"
        output_path.write_bytes(b"previous")
        fake_ffmpeg.concat_partial_bytes = b"partial"
        fake_ffmpeg.concat_returncode = 1

        # Act
        with pytest.raises(assemble_video.ManifestError):
            assemble_video.assemble_video(
                manifest_path=manifest_path,
                output_path=output_path,
                fps=None,
                resolution=None,
            )

        # Assert
        assert output_path.read_bytes() == b"previous"

    def test_given_quote_in_output_dir_when_assemble_video_then_concat_entries_escaped(
        self, tmp_path, fake_ffmpeg
    ):
        # Arrange
        manifest_path = _write_inputs(tmp_path)
        output_path = tmp_path / "it's" / "demo.mp4"

        # Act
        assemble_video.assemble_video(
            manifest_path=manifest_path,
            output_path=output_path,
            fps=None,
            resolution=None,
        )

        # Assert
        segment_path = Path(fake_ffmpeg.calls[0][0][-1])
        escaped = segment_path.as_posix().replace("'", "'\\''")
        assert fake_ffmpeg.concat_list.splitlines() == [f"file '{escaped}'"]


class TestCleanup:
    """Temporary segment directories never outlive the run."""

    def test_given_interrupt_during_render_when_assemble_video_then_temp_dir_removed(
        self, tmp_path, fake_ffmpeg
    ):
        # Arrange
        manifest_path = _write_inputs(tmp_path)
        fake_ffmpeg.raise_on_call = KeyboardInterrupt()

        # Act
        with pytest.raises(KeyboardInterrupt):
            assemble_video.assemble_video(
                manifest_path=manifest_path,
                output_path=tmp_path / "demo.mp4",
                fps=None,
                resolution=None,
            )

        # Assert
        assert _leftover_temp_dirs(tmp_path) == []
        assert not (tmp_path / "demo.mp4").exists()

    def test_given_interrupt_when_main_then_returns_130(self, monkeypatch, mocker):
        # Arrange
        monkeypatch.setattr(sys, "argv", ["assemble_video.py", "--manifest", "m.yml"])
        mocker.patch.object(
            assemble_video, "assemble_video", side_effect=KeyboardInterrupt()
        )

        # Act
        exit_code = assemble_video.main()

        # Assert
        assert exit_code == 130

    def test_given_successful_run_when_assemble_video_then_temp_dir_removed(
        self, tmp_path, fake_ffmpeg
    ):
        # Arrange
        manifest_path = _write_inputs(tmp_path)

        # Act
        assemble_video.assemble_video(
            manifest_path=manifest_path,
            output_path=tmp_path / "demo.mp4",
            fps=None,
            resolution=None,
        )

        # Assert
        assert _leftover_temp_dirs(tmp_path) == []


class TestValidationBounds:
    """Manifest validation bounds resolution and duration from below only."""

    def test_given_extreme_resolution_and_duration_when_validate_manifest_then_accepted(
        self,
    ):
        # Arrange
        data = {
            "resolution": "100000x100000",
            "segments": [
                {"visual": "a.png", "narration": "a.wav", "duration": 1_000_000_000}
            ],
        }

        # Act
        config, segments = assemble_video._validate_manifest(data)

        # Assert
        assert config["resolution"] == "100000x100000"
        assert segments[0]["duration"] == 1_000_000_000

    @pytest.mark.parametrize("resolution", ["1280by720", "0x720", "axb", "1280x-1"])
    def test_given_malformed_resolution_when_validate_resolution_then_raises(
        self, resolution
    ):
        # Act / Assert
        with pytest.raises(assemble_video.ManifestError):
            assemble_video._validate_resolution(resolution)
