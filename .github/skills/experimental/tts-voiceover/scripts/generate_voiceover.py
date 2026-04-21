#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Generate per-slide TTS voice-over from YAML speaker notes via Azure Speech SDK.

Part of the tts-voiceover skill. Reads content.yaml files from each slide
directory, extracts ``speaker_notes``, applies SSML acronym aliases, and
produces one WAV file per slide.

Usage:
    python generate_voiceover.py --dry-run --content-dir content
    python generate_voiceover.py --content-dir content --output-dir voice-over
    python generate_voiceover.py --lexicon custom-acronyms.yaml --content-dir content
"""

from __future__ import annotations

import argparse
import logging
import os
import sys
import time
import xml.sax.saxutils
from pathlib import Path

import yaml

logger = logging.getLogger(__name__)

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_ERROR = 2

DEFAULT_VOICE = "en-US-Andrew:DragonHDLatestNeural"
DEFAULT_RATE = "+10%"

_DEFAULT_ACRONYMS: dict[str, str] = {
    "HVE-Core": "H V E Core",
    "OWASP": "Oh wasp",
    "SSSC": "S S S C",
    "SPDX": "S P D X",
    "SBOM": "S Bomb",
    "SLSA": "Salsa",
    "SARIF": "Sareef",
    "CI/CD": "C I C D",
    "STRIDE": "STRIDE",
    "RAI": "R A I",
    "GSN": "G S N",
    "RPI": "R P I",
    "ISE": "I S E",
    "AST": "A S T",
    "MCP": "M C P",
}


def load_acronyms(path: Path) -> dict[str, str]:
    """Load acronym aliases from YAML, falling back to built-in defaults."""
    if path.is_file():
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
        acronyms = data.get("acronyms") if isinstance(data, dict) else None
        if isinstance(acronyms, dict):
            logger.info("Loaded %d acronyms from %s", len(acronyms), path)
            return acronyms
        logger.warning("Invalid acronyms format in %s; using defaults", path)
    return dict(_DEFAULT_ACRONYMS)


def apply_acronym_aliases(text: str, acronyms: dict[str, str]) -> str:
    """Replace acronyms with SSML ``<sub alias>`` elements.

    Processes longest acronyms first to avoid partial matches.
    """
    for acronym, alias in sorted(acronyms.items(), key=lambda x: -len(x[0])):
        if acronym in text:
            replacement = (
                f'<sub alias="{xml.sax.saxutils.escape(alias)}">'
                f"{xml.sax.saxutils.escape(acronym)}</sub>"
            )
            text = text.replace(acronym, replacement)
    return text


def wrap_ssml(text: str, voice: str, rate: str) -> str:
    """Wrap processed text in a full SSML document."""
    safe_voice = xml.sax.saxutils.quoteattr(voice)
    safe_rate = xml.sax.saxutils.quoteattr(rate)
    return (
        '<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis"'
        ' xmlns:mstts="http://www.w3.org/2001/mstts" xml:lang="en-US">\n'
        f"  <voice name={safe_voice}>\n"
        f"    <prosody rate={safe_rate}>\n"
        f"      {text}\n"
        "    </prosody>\n"
        "  </voice>\n"
        "</speak>"
    )


def generate_audio(ssml: str, output_path: Path, speech_config: object) -> float | None:
    """Generate a WAV file from SSML. Returns duration in seconds or ``None``."""
    import azure.cognitiveservices.speech as speechsdk

    audio_config = speechsdk.audio.AudioOutputConfig(filename=str(output_path))
    synthesizer = speechsdk.SpeechSynthesizer(
        speech_config=speech_config, audio_config=audio_config
    )
    result = synthesizer.speak_ssml_async(ssml).get()
    if result.reason == speechsdk.ResultReason.SynthesizingAudioCompleted:
        return result.audio_duration.total_seconds()
    cancellation = result.cancellation_details
    logger.error(
        "Synthesis failed: %s — %s", cancellation.reason, cancellation.error_details
    )
    return None


def _make_entra_config(
    speechsdk: object,
    credential: object,
    resource_id: str,
    region: str,
) -> tuple:
    """Create a SpeechConfig with a fresh Entra ID token.

    Returns (config, expires_at).
    """
    token_obj = credential.get_token("https://cognitiveservices.azure.com/.default")
    auth_token = f"aad#{resource_id}#{token_obj.token}"
    config = speechsdk.SpeechConfig(auth_token=auth_token, region=region)
    config.set_speech_synthesis_output_format(
        speechsdk.SpeechSynthesisOutputFormat.Riff24Khz16BitMonoPcm
    )
    return config, token_obj.expires_on


def _resolve_lexicon(args_lexicon: Path | None, content_dir: Path) -> Path:
    """Resolve the acronym lexicon path from argument, content dir, or defaults."""
    if args_lexicon is not None:
        return args_lexicon
    content_lexicon = content_dir / "acronyms.yaml"
    if content_lexicon.is_file():
        return content_lexicon
    return Path("acronyms.yaml")  # falls through to built-in defaults


def create_parser() -> argparse.ArgumentParser:
    """Create and configure the argument parser."""
    parser = argparse.ArgumentParser(
        description="Generate per-slide TTS voice-over from YAML speaker notes"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print SSML templates without generating audio",
    )
    parser.add_argument(
        "--voice",
        default=DEFAULT_VOICE,
        help=f"Azure TTS voice name (default: {DEFAULT_VOICE})",
    )
    parser.add_argument(
        "--rate",
        default=DEFAULT_RATE,
        help=f"Speech prosody rate (default: {DEFAULT_RATE})",
    )
    parser.add_argument(
        "--content-dir",
        type=Path,
        default=Path("content"),
        help="Path to slide content directory (default: content)",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("voice-over"),
        help="Path to WAV output directory (default: voice-over)",
    )
    parser.add_argument(
        "--lexicon",
        type=Path,
        default=None,
        help="Path to custom acronyms.yaml lexicon file",
    )
    return parser


def main() -> int:
    """Entry point for TTS voice-over generation."""
    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    parser = create_parser()
    args = parser.parse_args()

    content_dir: Path = args.content_dir
    output_dir: Path = args.output_dir

    if not content_dir.is_dir():
        logger.error("Content directory not found: %s", content_dir)
        return EXIT_FAILURE

    output_dir.mkdir(parents=True, exist_ok=True)

    lexicon_path = _resolve_lexicon(args.lexicon, content_dir)
    acronyms = load_acronyms(lexicon_path)

    speech_config = None
    credential = None
    token_expires_at = 0
    if not args.dry_run:
        try:
            import azure.cognitiveservices.speech as speechsdk
        except ImportError:
            logger.error(
                "azure-cognitiveservices-speech package is required"
                " for audio generation"
            )
            return EXIT_FAILURE

        speech_key = os.environ.get("SPEECH_KEY")
        speech_region = os.environ.get("SPEECH_REGION", "eastus")
        speech_resource_id = os.environ.get("SPEECH_RESOURCE_ID")

        if speech_key:
            speech_config = speechsdk.SpeechConfig(
                subscription=speech_key, region=speech_region
            )
            speech_config.set_speech_synthesis_output_format(
                speechsdk.SpeechSynthesisOutputFormat.Riff24Khz16BitMonoPcm
            )
        elif speech_resource_id:
            try:
                from azure.identity import DefaultAzureCredential
            except ImportError:
                logger.error("azure-identity package is required for Entra ID auth")
                return EXIT_FAILURE
            credential = DefaultAzureCredential()
            speech_config, token_expires_at = _make_entra_config(
                speechsdk, credential, speech_resource_id, speech_region
            )
        else:
            logger.error(
                "Set SPEECH_KEY (key auth) or SPEECH_RESOURCE_ID (Entra ID auth)"
                " with SPEECH_REGION"
            )
            return EXIT_ERROR

    total_duration = 0.0
    slide_count = 0

    for slide_dir in sorted(content_dir.glob("slide-*")):
        content_file = slide_dir / "content.yaml"
        if not content_file.is_file():
            continue

        data = yaml.safe_load(content_file.read_text(encoding="utf-8"))
        notes = data.get("speaker_notes", "").strip()
        title = data.get("title", slide_dir.name)

        if not notes:
            logger.info("SKIP %s: no speaker notes", slide_dir.name)
            continue

        safe_notes = xml.sax.saxutils.escape(notes)
        processed = apply_acronym_aliases(safe_notes, acronyms)
        ssml = wrap_ssml(processed, args.voice, args.rate)
        slide_count += 1

        if args.dry_run:
            print(f"\n=== {slide_dir.name}: {title} ===")
            print(ssml)
            continue

        # Refresh Entra ID token before expiry.
        if (
            speech_resource_id
            and not speech_key
            and time.time() > token_expires_at - 300
        ):
            speech_config, token_expires_at = _make_entra_config(
                speechsdk, credential, speech_resource_id, speech_region
            )
            logger.info("Refreshed Entra ID token")

        wav_path = output_dir / f"{slide_dir.name}.wav"
        logger.info("Generating %s: %s ...", slide_dir.name, title)
        duration = generate_audio(ssml, wav_path, speech_config)
        if duration is not None:
            total_duration += duration
            logger.info("  %s — %.1fs", wav_path.name, duration)
        else:
            logger.error("  FAILED: %s", wav_path.name)

    if args.dry_run:
        print(f"\n--- Dry run complete: {slide_count} slides processed ---")
    else:
        logger.info(
            "Total narration: %.1fs (%.1f min) across %d slides",
            total_duration,
            total_duration / 60,
            slide_count,
        )

    return EXIT_SUCCESS


if __name__ == "__main__":
    sys.exit(main())
