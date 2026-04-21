#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Embed per-slide WAV voice-over files into a PowerPoint deck.

Reads slide-NNN.wav files from an audio directory and adds them as embedded
media objects in the corresponding slides of a PPTX file.

Usage:
    python embed_audio.py --input deck.pptx --audio-dir voice-over
    python embed_audio.py --input deck.pptx --audio-dir voice-over \
        --output deck-narrated.pptx

Note: python-pptx has limited audio embedding support. The audio is added via
``add_movie()`` with a small off-screen icon. Manual PowerPoint audio
configuration may produce better auto-play results.
"""

from __future__ import annotations

import argparse
import logging
import sys
from pathlib import Path

from pptx import Presentation
from pptx.slide import Slide
from pptx.util import Inches

logger = logging.getLogger(__name__)

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_ERROR = 2

AUDIO_MIME_TYPE = "audio/wav"
ICON_SIZE = Inches(0.1)


def embed_slide_audio(slide: Slide, wav_path: Path) -> bool:
    """Embed a WAV file into a PowerPoint slide.

    Returns True on success, False on failure.
    """
    try:
        slide.shapes.add_movie(
            str(wav_path),
            left=0,
            top=0,
            width=ICON_SIZE,
            height=ICON_SIZE,
            mime_type=AUDIO_MIME_TYPE,
        )
        return True
    except Exception:
        logger.exception("Failed to embed audio %s", wav_path.name)
        return False


def create_parser() -> argparse.ArgumentParser:
    """Create and configure the argument parser."""
    parser = argparse.ArgumentParser(
        description="Embed per-slide WAV voice-over files into a PPTX deck"
    )
    parser.add_argument(
        "--input",
        type=Path,
        required=True,
        help="Source PPTX file path",
    )
    parser.add_argument(
        "--audio-dir",
        type=Path,
        default=Path("voice-over"),
        help="Directory containing slide-NNN.wav files (default: voice-over)",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Output PPTX file path (default: input stem + '-narrated.pptx')",
    )
    return parser


def main() -> int:
    """Entry point for audio embedding."""
    logging.basicConfig(level=logging.INFO,
                        format="%(levelname)s: %(message)s")
    parser = create_parser()
    args = parser.parse_args()

    input_path: Path = args.input
    audio_dir: Path = args.audio_dir

    if not input_path.is_file():
        logger.error("Input PPTX not found: %s", input_path)
        return EXIT_FAILURE

    if not audio_dir.is_dir():
        logger.error("Audio directory not found: %s", audio_dir)
        return EXIT_FAILURE

    output_path: Path = args.output or input_path.with_name(
        f"{input_path.stem}-narrated.pptx"
    )

    prs = Presentation(str(input_path))
    embedded_count = 0

    for idx, slide in enumerate(prs.slides, start=1):
        wav_name = f"slide-{idx:03d}.wav"
        wav_path = audio_dir / wav_name
        if not wav_path.is_file():
            logger.info("SKIP slide %d: %s not found", idx, wav_name)
            continue

        if embed_slide_audio(slide, wav_path):
            embedded_count += 1
            logger.info("Embedded %s into slide %d", wav_name, idx)
        else:
            logger.error("FAILED to embed %s into slide %d", wav_name, idx)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    prs.save(str(output_path))
    logger.info("Saved %s with %d embedded audio files",
                output_path, embedded_count)

    return EXIT_SUCCESS


if __name__ == "__main__":
    sys.exit(main())
