# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Tests for the demo-video manifest assembly module."""

from __future__ import annotations

from pathlib import Path
from types import SimpleNamespace

import assemble_video
import pytest


def _write_command_output(command, **_kwargs):
    Path(command[-1]).write_bytes(b"mp4")


@pytest.fixture()
def mock_ffmpeg_dependencies(mocker):
    mocker.patch.object(
        assemble_video,
        "_require_command",
        side_effect=lambda command: f"/usr/bin/{command}",
    )
    mocker.patch.object(
        assemble_video, "_run_ffmpeg", side_effect=_write_command_output
    )


class TestRuntimeTransitions:
    def test_given_long_audio_when_scene_trimmed_then_trailing_handle_is_silent(
        self, tmp_path
    ):
        import array
        import math
        import shutil
        import subprocess
        import wave

        ffmpeg = shutil.which("ffmpeg")
        if not ffmpeg:
            pytest.skip("Existing FFmpeg required")
        visual = tmp_path / "frame.ppm"
        visual.write_bytes(b"P6\n160 90\n255\n" + b"\x40\x90\x40" * (160 * 90))
        narration = tmp_path / "long.wav"
        samples = array.array(
            "h",
            [
                int(12000 * math.sin(2 * math.pi * 440 * index / 48000))
                for index in range(4 * 48000)
            ],
        )
        with wave.open(str(narration), "wb") as audio:
            audio.setnchannels(1)
            audio.setsampwidth(2)
            audio.setframerate(48000)
            audio.writeframes(samples.tobytes())
        output = tmp_path / "trimmed.mp4"

        assemble_video._render_segment(
            segment={
                "visual": str(visual),
                "narration": str(narration),
                "duration": 2,
                "lead": 0.5,
                "tail": 0.5,
            },
            output_path=output,
            resolution="160x90",
            fps=24,
            ffmpeg_path=ffmpeg,
        )
        decoded = subprocess.run(
            [
                ffmpeg,
                "-v",
                "error",
                "-ss",
                "2.52",
                "-i",
                str(output),
                "-t",
                "0.48",
                "-f",
                "s16le",
                "-acodec",
                "pcm_s16le",
                "-",
            ],
            capture_output=True,
            check=True,
        ).stdout

        assert decoded
        assert max(abs(sample) for sample in array.array("h", decoded)) < 200

    def test_given_short_scene_without_fades_when_filtered_then_noop(self):
        assert assemble_video._transition_filter(
            [0.4], {"duration": 0.5, "fade_in": False, "fade_out": False}
        ) == ("", "0:v:0", "0:a:0")

    @pytest.mark.parametrize(
        "endpoints", [None, (False, False), (False, True), (True, False), (True, True)]
    )
    def test_given_one_scene_when_encoded_then_all_endpoint_combinations_work(
        self, tmp_path, endpoints
    ):
        import json
        import shutil
        import subprocess
        import wave

        import yaml

        ffmpeg = shutil.which("ffmpeg")
        ffprobe = shutil.which("ffprobe")
        if not ffmpeg or not ffprobe:
            pytest.skip("Existing FFmpeg and ffprobe required")
        visual = tmp_path / "frame.ppm"
        visual.write_bytes(b"P6\n160 90\n255\n" + b"\x40\x90\x40" * (160 * 90))
        with wave.open(str(tmp_path / "voice.wav"), "wb") as audio:
            audio.setnchannels(1)
            audio.setsampwidth(2)
            audio.setframerate(8000)
            audio.writeframes(b"\x00\x00" * 16000)
        data = {
            "output": "result.mp4",
            "resolution": "160x90",
            "fps": 24,
            "segments": [{"visual": "frame.ppm", "narration": "voice.wav"}],
        }
        if endpoints is not None:
            data["transition"] = {
                "duration": 0.5,
                "fade_in": endpoints[0],
                "fade_out": endpoints[1],
            }
        else:
            data["transition"] = "none"
        manifest = tmp_path / "segments.yml"
        manifest.write_text(yaml.safe_dump(data), encoding="utf-8")

        result = assemble_video.assemble_video(
            manifest_path=manifest, output_path=None, fps=None, resolution=None
        )
        measured = json.loads(
            subprocess.run(
                [
                    ffprobe,
                    "-v",
                    "error",
                    "-show_entries",
                    "format=duration",
                    "-of",
                    "json",
                    str(result),
                ],
                capture_output=True,
                text=True,
                check=True,
            ).stdout
        )
        expected = 2 + (sum(endpoints) * 0.5 if endpoints else 0)
        assert float(measured["format"]["duration"]) == pytest.approx(
            expected, abs=0.15
        )


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

        def fake_render_segment(
            *, segment, output_path, resolution, fps, ffmpeg_path, **_
        ):
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

        def fake_render_segment(
            *, segment, output_path, resolution, fps, ffmpeg_path, **_
        ):
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
            side_effect=lambda command, **_: command_calls.append(command),
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
            side_effect=lambda command, **_: command_calls.append(command),
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

    def test_given_non_string_top_level_key_when_validate_manifest_then_raises(
        self, tmp_path
    ):
        # Arrange
        manifest_path = tmp_path / "segments.yml"
        manifest_path.write_text("null: true\n", encoding="utf-8")

        # Act / Assert
        with pytest.raises(
            assemble_video.ManifestError, match="unsupported top-level keys"
        ):
            assemble_video._validate_manifest(
                assemble_video._read_manifest(manifest_path),
            )

    def test_given_crossfade_when_validated_then_normalizes_configuration(self):
        # Arrange
        manifest = {
            "transition": {
                "type": "fade",
                "duration": 0.5,
                "fade_in": True,
                "fade_out": True,
            },
            "segments": [
                {"visual": "intro.png", "narration": "intro.wav"},
            ],
        }

        # Act
        config, _ = assemble_video._validate_manifest(manifest)

        # Assert
        assert config["transition"] == {
            "type": "crossfade",
            "duration": 0.5,
            "fade_in": True,
            "fade_out": True,
        }

    @pytest.mark.parametrize(
        ("transition", "message"),
        [
            ([], "must be a mapping"),
            ({"duration": "invalid"}, "must be a number"),
            ({"duration": []}, "must be a number"),
            ({"type": "wipe"}, "Unsupported transition type"),
            ({"duration": 0}, "positive finite"),
            ({"duration": float("nan")}, "positive finite"),
            ({"fade_in": "yes"}, "must be booleans"),
            ({"unknown": True}, "unsupported keys"),
        ],
    )
    def test_given_invalid_transition_when_validated_then_raises(
        self, transition, message
    ):
        # Arrange
        manifest = {
            "transition": transition,
            "segments": [
                {"visual": "intro.png", "narration": "intro.wav"},
            ],
        }

        # Act / Assert
        with pytest.raises(assemble_video.ManifestError, match=message):
            assemble_video._validate_manifest(manifest)

    def test_given_transition_when_assembled_then_uses_video_and_audio_fades(
        self, tmp_path, mocker, mock_ffmpeg_dependencies
    ):
        # Arrange
        manifest_path = tmp_path / "segments.yml"
        for name in ("one.png", "two.png", "one.wav", "two.wav"):
            (tmp_path / name).write_bytes(b"fixture")
        manifest_path.write_text(
            "output: demo.mp4\n"
            "transition:\n"
            "  type: crossfade\n"
            "  duration: 0.5\n"
            "  fade_in: true\n"
            "  fade_out: true\n"
            "segments:\n"
            "  - visual: one.png\n"
            "    narration: one.wav\n"
            "    duration: 3\n"
            "  - visual: two.png\n"
            "    narration: two.wav\n"
            "    duration: 4\n",
            encoding="utf-8",
        )
        commands = []

        def record_command(command, **_kwargs):
            commands.append(command)
            Path(command[-1]).write_bytes(b"mp4")

        mocker.patch.object(assemble_video, "_render_segment")
        mocker.patch.object(assemble_video, "_run_ffmpeg", side_effect=record_command)

        # Act
        assemble_video.assemble_video(
            manifest_path=manifest_path,
            output_path=None,
            fps=None,
            resolution=None,
        )

        # Assert
        final_command = commands[-1]
        filter_graph = final_command[final_command.index("-filter_complex") + 1]
        assert "fade=t=in:st=0:d=0.5" in filter_graph
        assert "afade=t=in:st=0:d=0.5" in filter_graph
        assert "xfade=transition=fade:duration=0.5:offset=3.5" in filter_graph
        assert "acrossfade=d=0.5:c1=tri:c2=tri" in filter_graph
        assert "fade=t=out:st=8:d=0.5" in filter_graph
        assert "afade=t=out:st=8:d=0.5" in filter_graph

    def test_given_missing_encoded_output_when_assembled_then_preserves_previous(
        self, tmp_path, mocker, mock_ffmpeg_dependencies
    ):
        for name in ("frame.png", "voice.wav"):
            (tmp_path / name).write_bytes(b"fixture")
        manifest = tmp_path / "segments.yml"
        manifest.write_text(
            "segments:\n  - visual: frame.png\n"
            "    narration: voice.wav\n    duration: 2\n",
            encoding="utf-8",
        )
        output = tmp_path / "previous.mp4"
        output.write_bytes(b"previous delivery")
        mocker.patch.object(assemble_video, "_render_segment")
        mocker.patch.object(assemble_video, "_run_ffmpeg")

        with pytest.raises(assemble_video.ManifestError, match="wrote no output"):
            assemble_video.assemble_video(
                manifest_path=manifest, output_path=output, fps=None, resolution=None
            )

        assert output.read_bytes() == b"previous delivery"

    @pytest.mark.parametrize(
        ("error", "expected"),
        [
            (None, assemble_video.EXIT_SUCCESS),
            (
                assemble_video.ManifestError("invalid manifest"),
                assemble_video.EXIT_ERROR,
            ),
            (FileNotFoundError("missing media"), assemble_video.EXIT_FAILURE),
            (KeyboardInterrupt(), 130),
        ],
    )
    def test_given_cli_assembly_when_run_then_preserves_exit_contract(
        self, tmp_path, mocker, capsys, error, expected
    ):
        output = tmp_path / "video.mp4"
        manifest = tmp_path / "segments.yml"
        mocker.patch.object(
            assemble_video.sys, "argv", ["assemble_video", "--manifest", str(manifest)]
        )
        operation = mocker.patch.object(
            assemble_video, "assemble_video", return_value=output, side_effect=error
        )

        result = assemble_video.main()

        assert result == expected
        assert operation.call_args.kwargs["manifest_path"] == manifest.resolve()
        captured = capsys.readouterr()
        if error is None:
            assert captured.out.strip() == str(output.resolve())
            assert captured.err == ""
        else:
            assert captured.out == ""
            assert (
                "Interrupted by user"
                if isinstance(error, KeyboardInterrupt)
                else str(error)
            ) in captured.err

    def test_given_short_segment_when_transition_built_then_raises(self):
        # Act / Assert
        with pytest.raises(assemble_video.ManifestError, match="longer than twice"):
            assemble_video._transition_filter(
                [0.8, 3.0],
                {
                    "type": "crossfade",
                    "duration": 0.5,
                    "fade_in": True,
                    "fade_out": True,
                },
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
        with pytest.raises(assemble_video.ManifestError, match="declares type 'frame'"):
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

    def test_given_command_override_when_required_then_returns_override(
        self, monkeypatch, mocker
    ):
        # Arrange
        monkeypatch.setenv("FFMPEG_COMMAND", "/opt/tools/ffmpeg-full")
        which_mock = mocker.patch(
            "assemble_video.shutil.which", return_value="/opt/tools/ffmpeg-full"
        )

        # Act
        result = assemble_video._require_command("ffmpeg")

        # Assert
        assert result == "/opt/tools/ffmpeg-full"
        which_mock.assert_called_once_with("/opt/tools/ffmpeg-full")
