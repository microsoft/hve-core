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
        "-v",
        "--verbose",
        action="store_true",
        help="Enable verbose logging",
    )
    return parser


def configure_logging(verbose: bool = False) -> None:
    """Configure logging based on verbosity level."""
    import logging

    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(level=level, format="%(levelname)s: %(message)s")


def _require_command(command: str) -> str:
    """Return an available executable path or raise a clear error."""
    resolved = shutil.which(command)
    if resolved is None:
        raise ManifestError(f"Required executable '{command}' was not found on PATH")
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
    data: dict[str, Any], manifest_path: Path
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    """Validate manifest structure and return normalized values."""
    allowed_top_level_keys = {"output", "resolution", "fps", "segments"}
    unexpected_top_level = set(data) - allowed_top_level_keys
    if unexpected_top_level:
        unexpected = ", ".join(sorted(unexpected_top_level))
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
            unexpected = ", ".join(sorted(unexpected_segment_keys))
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

    return {
        "output": output_value,
        "resolution": resolution_value,
        "fps": fps,
        "segments": normalized_segments,
    }, normalized_segments


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


def _probe_duration(audio_path: Path) -> float:
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
    result = subprocess.run(command, capture_output=True, text=True, check=False)
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
) -> None:
    """Render a single segment to a normalized MP4 file."""
    visual_source = segment.get("visual")
    clip_source = segment.get("clip")
    narration_path = Path(segment["narration"])
    duration = segment["duration"]

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
            _build_filter_string(resolution, fps),
            "-c:a",
            "aac",
            "-b:a",
            "192k",
            "-shortest",
            "-t",
            f"{duration}",
            str(output_path),
        ]
    else:
        command = [
            ffmpeg_path,
            "-y",
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
            _build_filter_string(resolution, fps),
            "-c:a",
            "aac",
            "-b:a",
            "192k",
            "-shortest",
            "-t",
            f"{duration}",
            str(output_path),
        ]

    _run_ffmpeg(command)


def _run_ffmpeg(command: list[str]) -> None:
    """Run an FFmpeg command and raise a clear error on failure."""
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        stderr = (
            result.stderr.strip() or result.stdout.strip() or "unknown FFmpeg error"
        )
        joined_command = " ".join(command)
        raise ManifestError(f"FFmpeg command failed: {joined_command}\n{stderr}")


def assemble_video(
    *,
    manifest_path: Path,
    output_path: Path | None,
    fps: int | None,
    resolution: str | None,
) -> Path:
    """Assemble the final MP4 from the manifest."""
    ffmpeg_path = _require_command("ffmpeg")

    manifest_data = _read_manifest(manifest_path)
    config, segments = _validate_manifest(manifest_data, manifest_path)

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

    selected_fps = fps if fps is not None else config.get("fps") or 24
    selected_resolution = resolution or config.get("resolution") or "1280x720"
    _validate_resolution(selected_resolution)

    output_path.parent.mkdir(parents=True, exist_ok=True)

    normalized_paths: list[Path] = []
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
                duration = _probe_duration(narration_path)
            else:
                duration = segment["duration"]

            normalized_path = temp_dir / f"segment-{index:02d}.mp4"
            segment_data = dict(segment)
            segment_data["narration"] = str(narration_path)
            segment_data["duration"] = duration
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
            )
            normalized_paths.append(normalized_path)

        concat_list_path = temp_dir / "concat.txt"
        with concat_list_path.open("w", encoding="utf-8") as handle:
            for normalized_path in normalized_paths:
                handle.write(f"file '{normalized_path.as_posix()}'\n")

        concat_command = [
            ffmpeg_path,
            "-y",
            "-f",
            "concat",
            "-safe",
            "0",
            "-i",
            str(concat_list_path),
            "-c:v",
            "libx264",
            "-pix_fmt",
            "yuv420p",
            "-c:a",
            "aac",
            "-b:a",
            "192k",
            str(output_path),
        ]
        _run_ffmpeg(concat_command)

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
    except subprocess.CalledProcessError as exc:
        print(f"Error: FFmpeg exited with code {exc.returncode}", file=sys.stderr)
        return EXIT_FAILURE
    except Exception as exc:  # pragma: no cover - defensive top-level fallback
        print(f"Error: {exc}", file=sys.stderr)
        return EXIT_FAILURE

    print(output_path.resolve())
    return EXIT_SUCCESS


if __name__ == "__main__":
    sys.exit(main())
