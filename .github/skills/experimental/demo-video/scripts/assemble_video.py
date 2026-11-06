#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Assemble ordered visual segments with narration into an MP4 via FFmpeg.

This script reads a YAML manifest describing ordered visual segments (still
images or motion clips) and matching narration WAV files. Each segment is
normalized into a short MP4 clip, then concatenated into a final output MP4
with the narration audio track.
"""

from __future__ import annotations

import argparse
import logging
import math
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

import yaml

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_ERROR = 2

DEFAULT_TIMEOUT_SECONDS = 600
MAX_TIMEOUT_SECONDS = 86400


class ManifestError(ValueError):
    """Raised for invalid or incomplete manifest definitions."""


def create_parser() -> argparse.ArgumentParser:
    """Create and configure the argument parser."""
    parser = argparse.ArgumentParser(
        description="Assemble ordered visual segments and narration into an MP4"
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        required=True,
        help="Path to the YAML manifest describing visual segments",
    )
    parser.add_argument(
        "--output",
        type=Path,
        help="Destination MP4 path (overrides manifest output when supplied)",
    )
    parser.add_argument(
        "--fps",
        type=int,
        help="Frame rate to use when rendering segments",
    )
    parser.add_argument(
        "--resolution",
        help="Output resolution in WIDTHxHEIGHT format, for example 1280x720",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=DEFAULT_TIMEOUT_SECONDS,
        help=(
            "Maximum seconds for each ffprobe or ffmpeg invocation "
            f"(1-{MAX_TIMEOUT_SECONDS}, default {DEFAULT_TIMEOUT_SECONDS})"
        ),
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="Enable verbose logging",
    )
    return parser


def configure_logging(verbose: bool = False) -> None:
    """Configure logging based on verbosity level."""
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(level=level, format="%(levelname)s: %(message)s")


def _require_command(command: str) -> str:
    """Return an available executable path or raise a clear error."""
    override = os.environ.get(f"{command.upper()}_COMMAND")
    resolved = shutil.which(override or command)
    if resolved is None:
        requested = override or command
        raise ManifestError(f"Required executable '{requested}' was not found on PATH")
    return resolved


def _read_manifest(path: Path) -> dict[str, Any]:
    """Read and parse the manifest file."""
    if not path.is_file():
        raise ManifestError(f"Manifest not found: {path}")

    try:
        with path.open("r", encoding="utf-8") as handle:
            data = yaml.safe_load(handle) or {}
    except yaml.YAMLError as exc:  # pragma: no cover - defensive branch
        raise ManifestError(f"Unable to parse YAML manifest {path}: {exc}") from exc

    if not isinstance(data, dict):
        raise ManifestError("Manifest root must be a YAML mapping")
    return data


def _validate_manifest(
    data: dict[str, Any],
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    """Validate manifest structure and return normalized values."""
    allowed_top_level_keys = {
        "output",
        "resolution",
        "fps",
        "transition",
        "segments",
    }
    unexpected_top_level = set(data) - allowed_top_level_keys
    if unexpected_top_level:
        unexpected = ", ".join(sorted(str(key) for key in unexpected_top_level))
        raise ManifestError(
            f"Manifest contains unsupported top-level keys: {unexpected}"
        )

    segments = data.get("segments")
    if not isinstance(segments, list) or not segments:
        raise ManifestError("Manifest must define a non-empty 'segments' list")

    normalized_segments: list[dict[str, Any]] = []
    for index, item in enumerate(segments, start=1):
        if not isinstance(item, dict):
            raise ManifestError(f"Segment #{index} must be a YAML mapping")

        allowed_segment_keys = {
            "type",
            "visual",
            "clip",
            "narration",
            "narration_wav",
            "duration",
        }
        unexpected_segment_keys = set(item) - allowed_segment_keys
        if unexpected_segment_keys:
            unexpected = ", ".join(sorted(str(key) for key in unexpected_segment_keys))
            raise ManifestError(
                f"Segment #{index} contains unsupported keys: {unexpected}"
            )

        segment_type = item.get("type")
        if segment_type is not None:
            segment_type = str(segment_type).strip().lower()
            if segment_type not in {"frame", "clip"}:
                raise ManifestError(
                    f"Segment #{index} has unsupported 'type': {segment_type}"
                )

        has_visual = "visual" in item and item["visual"] not in {None, ""}
        has_clip = "clip" in item and item["clip"] not in {None, ""}
        if has_visual == has_clip:
            raise ManifestError(
                f"Segment #{index} must define exactly one of 'visual' or 'clip'"
            )

        inferred_type = "frame" if has_visual else "clip"
        if segment_type is None:
            segment_type = inferred_type
        elif segment_type != inferred_type:
            provided_source = "visual" if has_visual else "clip"
            raise ManifestError(
                f"Segment #{index} declares type '{segment_type}' but provides a "
                f"'{provided_source}' source"
            )

        narration_value = item.get("narration")
        if narration_value is None and "narration_wav" in item:
            narration_value = item.get("narration_wav")
        if not isinstance(narration_value, str) or not narration_value.strip():
            raise ManifestError(
                f"Segment #{index} must define a non-empty 'narration' path"
            )

        duration_value = item.get("duration")
        if duration_value is not None:
            try:
                duration = float(duration_value)
            except (TypeError, ValueError) as exc:
                raise ManifestError(
                    f"Segment #{index} has an invalid 'duration': {duration_value}"
                ) from exc
            if duration <= 0:
                raise ManifestError(f"Segment #{index} has a non-positive 'duration'")
        else:
            duration = None

        normalized_segments.append(
            {
                "type": segment_type,
                "visual": str(item["visual"]) if has_visual else None,
                "clip": str(item["clip"]) if has_clip else None,
                "narration": str(narration_value),
                "duration": duration,
            }
        )

    output_value = data.get("output")
    if output_value is not None and not isinstance(output_value, str):
        raise ManifestError("Manifest 'output' must be a string path")

    resolution_value = data.get("resolution")
    if resolution_value is not None:
        if not isinstance(resolution_value, str):
            raise ManifestError(
                "Manifest 'resolution' must be a string in WIDTHxHEIGHT form"
            )
        _validate_resolution(resolution_value)

    fps_value = data.get("fps")
    if fps_value is not None:
        try:
            fps = int(fps_value)
        except (TypeError, ValueError) as exc:
            raise ManifestError("Manifest 'fps' must be an integer") from exc
        if fps <= 0:
            raise ManifestError("Manifest 'fps' must be greater than zero")
    else:
        fps = None

    transition = _validate_transition(data.get("transition"))

    return {
        "output": output_value,
        "resolution": resolution_value,
        "fps": fps,
        "transition": transition,
        "segments": normalized_segments,
    }, normalized_segments


def _validate_transition(value: Any) -> dict[str, Any] | None:
    """Validate and normalize the optional scene-transition configuration."""
    if value is None or value == "none":
        return None
    if not isinstance(value, dict):
        raise ManifestError("Manifest 'transition' must be a mapping or 'none'")
    allowed_keys = {"type", "duration", "fade_in", "fade_out"}
    unexpected = set(value) - allowed_keys
    if unexpected:
        keys = ", ".join(sorted(str(key) for key in unexpected))
        raise ManifestError(f"Transition contains unsupported keys: {keys}")
    transition_type = str(value.get("type", "crossfade")).strip().lower()
    if transition_type not in {"crossfade", "fade"}:
        raise ManifestError(f"Unsupported transition type: {transition_type}")
    try:
        duration = float(value.get("duration", 0.5))
    except (TypeError, ValueError) as exc:
        raise ManifestError("Transition duration must be a number") from exc
    if not math.isfinite(duration) or duration <= 0:
        raise ManifestError("Transition duration must be a positive finite number")
    fade_in = value.get("fade_in", True)
    fade_out = value.get("fade_out", True)
    if not isinstance(fade_in, bool) or not isinstance(fade_out, bool):
        raise ManifestError("Transition fade_in and fade_out must be booleans")
    return {
        "type": "crossfade",
        "duration": duration,
        "fade_in": fade_in,
        "fade_out": fade_out,
    }


def _validate_resolution(resolution: str) -> None:
    """Validate that the resolution is in WIDTHxHEIGHT format."""
    if "x" not in resolution.lower():
        raise ManifestError("Resolution must be in WIDTHxHEIGHT format")
    width_str, height_str = resolution.lower().split("x", 1)
    try:
        width = int(width_str)
        height = int(height_str)
    except ValueError as exc:
        raise ManifestError("Resolution must use integer pixel values") from exc
    if width <= 0 or height <= 0:
        raise ManifestError("Resolution values must be greater than zero")


def _resolve_path(path_value: str, *, base_dir: Path) -> Path:
    """Resolve a path relative to the supplied base directory."""
    candidate = Path(path_value)
    if candidate.is_absolute():
        return candidate.resolve()
    return (base_dir / candidate).resolve()


def _run_bounded(
    command: list[str], *, timeout: int, step: str
) -> subprocess.CompletedProcess[str]:
    """Run a command with captured text output under a wall-clock timeout.

    ``subprocess.run`` kills the child when the timeout expires or when any
    exception, including ``KeyboardInterrupt``, interrupts the wait.
    """
    try:
        return subprocess.run(
            command, capture_output=True, text=True, check=False, timeout=timeout
        )
    except subprocess.TimeoutExpired as exc:
        raise ManifestError(f"{step} timed out after {timeout} seconds") from exc


def _probe_duration(
    audio_path: Path, *, timeout: int = DEFAULT_TIMEOUT_SECONDS
) -> float:
    """Get the duration of a WAV file via ffprobe."""
    ffprobe = _require_command("ffprobe")
    command = [
        ffprobe,
        "-v",
        "error",
        "-show_entries",
        "format=duration",
        "-of",
        "default=noprint_wrappers=1:nokey=1",
        str(audio_path),
    ]
    result = _run_bounded(
        command, timeout=timeout, step=f"ffprobe for {audio_path.name}"
    )
    if result.returncode != 0:
        raise ManifestError(
            "Unable to determine narration duration for "
            f"{audio_path}: {result.stderr.strip()}"
        )
    try:
        duration = float(result.stdout.strip())
    except ValueError as exc:
        raise ManifestError(
            "Unable to parse ffprobe duration for "
            f"{audio_path}: {result.stdout.strip()}"
        ) from exc
    if duration <= 0:
        raise ManifestError(f"Narration duration must be positive for {audio_path}")
    return duration


def _build_filter_string(resolution: str, fps: int) -> str:
    """Build the FFmpeg video filter string for scaling and frame rate."""
    return f"scale={resolution},fps={fps}"


def _render_segment(
    *,
    segment: dict[str, Any],
    output_path: Path,
    resolution: str,
    fps: int,
    ffmpeg_path: str,
    timeout: int = DEFAULT_TIMEOUT_SECONDS,
) -> None:
    """Render a single segment to a normalized MP4 file."""
    visual_source = segment.get("visual")
    clip_source = segment.get("clip")
    narration_path = Path(segment["narration"])
    duration = segment["duration"]
    lead = segment.get("lead", 0.0)
    tail = segment.get("tail", 0.0)
    rendered_duration = duration + lead + tail
    video_filter = _build_filter_string(resolution, fps)
    if lead or tail:
        video_filter += (
            f",trim=duration={duration},setpts=PTS-STARTPTS,"
            f"tpad=start_duration={lead}:stop_duration={tail}:"
            "start_mode=clone:stop_mode=clone"
        )

    if visual_source is not None:
        command = [
            ffmpeg_path,
            "-y",
            "-loop",
            "1",
            "-i",
            str(visual_source),
            "-i",
            str(narration_path),
            "-c:v",
            "libx264",
            "-tune",
            "stillimage",
            "-pix_fmt",
            "yuv420p",
            "-vf",
            video_filter,
            "-c:a",
            "aac",
            "-b:a",
            "192k",
            "-shortest",
            "-t",
            f"{rendered_duration}",
            str(output_path),
        ]
    else:
        command = [
            ffmpeg_path,
            "-y",
            "-stream_loop",
            "-1",
            "-i",
            str(clip_source),
            "-i",
            str(narration_path),
            "-map",
            "0:v:0",
            "-map",
            "1:a:0",
            "-c:v",
            "libx264",
            "-pix_fmt",
            "yuv420p",
            "-vf",
            video_filter,
            "-c:a",
            "aac",
            "-b:a",
            "192k",
            "-t",
            f"{rendered_duration}",
            str(output_path),
        ]

    if lead or tail:
        command[-1:-1] = [
            "-af",
            f"atrim=duration={duration},asetpts=PTS-STARTPTS,"
            + f"adelay={round(lead * 1000)}:all=1,apad,"
            + f"atrim=duration={rendered_duration}",
        ]
    _run_ffmpeg(command, timeout=timeout, step=f"FFmpeg render of {output_path.name}")


def _run_ffmpeg(
    command: list[str],
    *,
    timeout: int = DEFAULT_TIMEOUT_SECONDS,
    step: str = "FFmpeg command",
) -> None:
    """Run an FFmpeg command and raise a clear error on failure."""
    logging.debug("Running FFmpeg: %s", " ".join(command))
    result = _run_bounded(command, timeout=timeout, step=step)
    if result.returncode != 0:
        stderr = (
            result.stderr.strip() or result.stdout.strip() or "unknown FFmpeg error"
        )
        joined_command = " ".join(command)
        raise ManifestError(f"FFmpeg command failed: {joined_command}\n{stderr}")


def _concat_entry(path: Path) -> str:
    """Return a concat demuxer ``file`` line with FFmpeg single-quote escaping."""
    escaped = path.as_posix().replace("'", "'\\''")
    return f"file '{escaped}'"


def _transition_filter(
    durations: list[float], transition: dict[str, Any]
) -> tuple[str, str, str]:
    """Return filter graph and final video/audio labels for smooth transitions."""
    if len(durations) == 1 and not transition["fade_in"] and not transition["fade_out"]:
        return "", "0:v:0", "0:a:0"
    duration = float(transition["duration"])
    if any(segment_duration <= duration * 2 for segment_duration in durations):
        raise ManifestError(
            "Each segment must be longer than twice the transition duration"
        )
    filters: list[str] = []
    video_label = "0:v:0"
    audio_label = "0:a:0"
    if transition["fade_in"]:
        filters.extend(
            [
                f"[{video_label}]fade=t=in:st=0:d={duration:g}[vin]",
                f"[{audio_label}]afade=t=in:st=0:d={duration:g}[ain]",
            ]
        )
        video_label = "vin"
        audio_label = "ain"

    for index in range(1, len(durations)):
        offset = sum(durations[:index]) - duration * index
        filters.extend(
            [
                f"[{video_label}][{index}:v:0]xfade=transition=fade:"
                f"duration={duration:g}:offset={offset:g}[vx{index}]",
                f"[{audio_label}][{index}:a:0]acrossfade=d={duration:g}:"
                f"c1=tri:c2=tri[ax{index}]",
            ]
        )
        video_label = f"vx{index}"
        audio_label = f"ax{index}"

    final_duration = sum(durations) - duration * (len(durations) - 1)
    if transition["fade_out"]:
        fade_start = final_duration - duration
        filters.extend(
            [
                f"[{video_label}]fade=t=out:st={fade_start:g}:d={duration:g}[vout]",
                f"[{audio_label}]afade=t=out:st={fade_start:g}:d={duration:g}[aout]",
            ]
        )
        video_label = "vout"
        audio_label = "aout"

    return ";".join(filters), video_label, audio_label


def assemble_video(
    *,
    manifest_path: Path,
    output_path: Path | None,
    fps: int | None,
    resolution: str | None,
    timeout: int = DEFAULT_TIMEOUT_SECONDS,
) -> Path:
    """Assemble the final MP4 from the manifest.

    The concatenated file is written inside the temporary directory and moved
    to ``output_path`` only after FFmpeg succeeds, so a failed or interrupted
    run never leaves a partial file and keeps any existing output unchanged.
    """
    if not 1 <= timeout <= MAX_TIMEOUT_SECONDS:
        raise ManifestError(
            f"Timeout must be between 1 and {MAX_TIMEOUT_SECONDS} seconds, "
            f"got {timeout}"
        )

    ffmpeg_path = _require_command("ffmpeg")

    manifest_data = _read_manifest(manifest_path)
    config, segments = _validate_manifest(manifest_data)

    manifest_dir = manifest_path.parent.resolve()
    output_config = config.get("output")
    if output_path is None:
        if output_config is None or not str(output_config).strip():
            raise ManifestError(
                "No output path was provided and manifest had no 'output' value"
            )
        output_path = _resolve_path(str(output_config), base_dir=manifest_dir)
    else:
        output_path = output_path.resolve()

    selected_fps = int(fps if fps is not None else config.get("fps") or 24)
    if selected_fps <= 0:
        raise ManifestError(f"Frame rate must be greater than zero, got {selected_fps}")
    selected_resolution = resolution or config.get("resolution") or "1280x720"
    _validate_resolution(selected_resolution)

    output_path.parent.mkdir(parents=True, exist_ok=True)

    normalized_paths: list[Path] = []
    segment_durations: list[float] = []
    transition = config.get("transition")
    with tempfile.TemporaryDirectory(
        prefix="demo-video-", dir=str(output_path.parent)
    ) as temp_dir_name:
        temp_dir = Path(temp_dir_name)

        for index, segment in enumerate(segments, start=1):
            visual_source = segment.get("visual")
            clip_source = segment.get("clip")
            narration_path = _resolve_path(segment["narration"], base_dir=manifest_dir)
            if not narration_path.is_file():
                raise ManifestError(f"Narration file not found: {narration_path}")

            if visual_source is not None:
                visual_path = _resolve_path(visual_source, base_dir=manifest_dir)
                if not visual_path.is_file():
                    raise ManifestError(f"Visual file not found: {visual_path}")
            else:
                clip_path = _resolve_path(clip_source, base_dir=manifest_dir)
                if not clip_path.is_file():
                    raise ManifestError(f"Clip file not found: {clip_path}")

            if segment.get("duration") is None:
                duration = _probe_duration(narration_path, timeout=timeout)
            else:
                duration = segment["duration"]
            logging.debug(
                "Rendering segment #%d (duration=%.3fs)", index, float(duration)
            )

            normalized_path = temp_dir / f"segment-{index:02d}.mp4"
            segment_data = dict(segment)
            segment_data["narration"] = str(narration_path)
            segment_data["duration"] = duration
            lead = tail = 0.0
            if transition:
                handle = float(transition["duration"])
                lead = handle if index > 1 or transition["fade_in"] else 0.0
                tail = (
                    handle if index < len(segments) or transition["fade_out"] else 0.0
                )
            segment_data["lead"] = lead
            segment_data["tail"] = tail
            if visual_source is not None:
                segment_data["visual"] = str(visual_path)
            else:
                segment_data["clip"] = str(clip_path)

            _render_segment(
                segment=segment_data,
                output_path=normalized_path,
                resolution=selected_resolution,
                fps=int(selected_fps),
                ffmpeg_path=ffmpeg_path,
                timeout=timeout,
            )
            normalized_paths.append(normalized_path)
            segment_durations.append(float(duration) + lead + tail)

        staged_output = temp_dir / f"assembled{output_path.suffix or '.mp4'}"
        transition = config.get("transition")
        if transition:
            filter_graph, video_label, audio_label = _transition_filter(
                segment_durations, transition
            )
            transition_command = [ffmpeg_path, "-y"]
            for normalized_path in normalized_paths:
                transition_command.extend(["-i", str(normalized_path)])
            if filter_graph:
                transition_command.extend(
                    [
                        "-filter_complex",
                        filter_graph,
                        "-map",
                        f"[{video_label}]",
                        "-map",
                        f"[{audio_label}]",
                    ]
                )
            else:
                transition_command.extend(["-map", video_label, "-map", audio_label])
            transition_command.extend(
                [
                    "-c:v",
                    "libx264",
                    "-pix_fmt",
                    "yuv420p",
                    "-c:a",
                    "aac",
                    "-b:a",
                    "192k",
                    "-movflags",
                    "+faststart",
                    str(staged_output),
                ]
            )
            _run_ffmpeg(transition_command, timeout=timeout, step="FFmpeg transitions")
        else:
            concat_list_path = temp_dir / "concat.txt"
            with concat_list_path.open("w", encoding="utf-8") as handle:
                for normalized_path in normalized_paths:
                    handle.write(_concat_entry(normalized_path) + "\n")
            concat_command = [
                ffmpeg_path,
                "-y",
                "-f",
                "concat",
                "-safe",
                "0",
                "-i",
                str(concat_list_path),
                "-c",
                "copy",
                str(staged_output),
            ]
            _run_ffmpeg(concat_command, timeout=timeout, step="FFmpeg concat")
        if not staged_output.is_file():
            raise ManifestError("FFmpeg concat reported success but wrote no output")
        os.replace(staged_output, output_path)

    return output_path.resolve()


def main() -> int:
    """Run the assembly process and exit with a suitable code."""
    parser = create_parser()
    args = parser.parse_args()
    configure_logging(args.verbose)

    try:
        output_path = assemble_video(
            manifest_path=args.manifest.resolve(),
            output_path=args.output,
            fps=args.fps,
            resolution=args.resolution,
            timeout=args.timeout,
        )
    except KeyboardInterrupt:
        print("Interrupted by user", file=sys.stderr)
        return 130
    except ManifestError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return EXIT_ERROR
    except FileNotFoundError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return EXIT_FAILURE
    except Exception as exc:  # pragma: no cover - defensive top-level fallback
        print(f"Error: {exc}", file=sys.stderr)
        return EXIT_FAILURE

    print(output_path.resolve())
    return EXIT_SUCCESS


if __name__ == "__main__":
    sys.exit(main())
