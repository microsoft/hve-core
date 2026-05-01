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
import functools
import logging
import os
import re
import sys
import time
import xml.sax.saxutils
from pathlib import Path
from typing import Any

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
            clean = {
                str(k): str(v)
                for k, v in acronyms.items()
                if k is not None and v is not None
            }
            xml_special = {k for k in clean if any(c in k for c in ("&", "<", ">"))}
            if xml_special:
                logger.warning(
                    "Acronym keys with XML-special characters will never match "
                    "(input text is pre-escaped): %s",
                    ", ".join(sorted(xml_special)),
                )
            if clean:
                logger.info("Loaded %d acronyms from %s", len(clean), path)
                return clean
        logger.warning("Invalid acronyms format in %s; using defaults", path)
    return dict(_DEFAULT_ACRONYMS)


@functools.lru_cache(maxsize=8)
def _compile_acronym_pattern(keys: tuple[str, ...]) -> re.Pattern[str]:
    """Compile and cache a regex matching all acronym keys, longest first."""
    sorted_keys = sorted(keys, key=len, reverse=True)
    return re.compile("|".join(re.escape(k) for k in sorted_keys))


def apply_acronym_aliases(text: str, acronyms: dict[str, str]) -> str:
    """Replace acronyms with SSML ``<sub alias>`` elements.

    Uses a single-pass regex to avoid corrupting previously-inserted SSML
    tags when an acronym appears inside an alias value or tag content.

    **Input contract**: ``text`` must already be XML-escaped
    (e.g. via ``xml.sax.saxutils.escape()``).  The returned string is a
    mix of XML-escaped character data and SSML ``<sub>`` markup fragments
    intended for embedding directly inside an SSML ``<prosody>`` element.

    **Lexicon constraint**: acronym keys containing XML-special characters
    (``&``, ``<``, ``>``) will never match because the input text is
    pre-escaped.  Use only ASCII-safe acronym keys.
    """
    if not acronyms:
        return text
    pattern = _compile_acronym_pattern(tuple(acronyms.keys()))

    def _replace(m: re.Match) -> str:
        acronym = m.group(0)
        alias = acronyms[acronym]
        safe_alias = xml.sax.saxutils.quoteattr(alias)
        safe_acronym = xml.sax.saxutils.escape(acronym)
        return f"<sub alias={safe_alias}>{safe_acronym}</sub>"

    return pattern.sub(_replace, text)


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


def generate_audio(ssml: str, output_path: Path, speech_config: Any) -> float | None:
    """Generate a WAV file from SSML. Returns duration in seconds or ``None``."""
    import azure.cognitiveservices.speech as speechsdk  # noqa: PLC0415

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
    speechsdk: Any,
    credential: Any,
    resource_id: str,
    region: str,
) -> tuple[Any, int]:
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
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="Enable verbose (DEBUG) logging",
    )
    return parser


def _run(args: argparse.Namespace) -> int:
    """Execute TTS generation logic."""

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
    speechsdk: Any = None
    speech_key: str | None = None
    speech_region: str = "eastus"
    speech_resource_id: str | None = None
    if not args.dry_run:
        try:
            import azure.cognitiveservices.speech as speechsdk  # noqa: PLC0415
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

    use_entra_auth = bool(speech_resource_id and not speech_key)

    total_duration = 0.0
    slide_count = 0
    failed_count = 0

    for slide_dir in sorted(content_dir.glob("slide-*")):
        content_file = slide_dir / "content.yaml"
        if not content_file.is_file():
            continue

        try:
            data = yaml.safe_load(content_file.read_text(encoding="utf-8"))
        except yaml.YAMLError as exc:
            logger.warning("SKIP %s: invalid YAML — %s", slide_dir.name, exc)
            continue

        if not isinstance(data, dict):
            logger.warning(
                "SKIP %s: content.yaml is empty or not a mapping",
                slide_dir.name,
            )
            continue

        raw_notes = data.get("speaker_notes") or ""
        notes = str(raw_notes).strip()
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
        if use_entra_auth and time.time() > token_expires_at - 300:
            if speech_resource_id is None:
                raise RuntimeError(
                    "speech_resource_id must not be None when use_entra_auth is True"
                )
            try:
                speech_config, token_expires_at = _make_entra_config(
                    speechsdk, credential, speech_resource_id, speech_region
                )
                logger.info("Refreshed Entra ID token")
            except Exception:  # network/auth errors during refresh
                logger.exception("Token refresh failed; using existing token")

        wav_path = output_dir / f"{slide_dir.name}.wav"
        logger.info("Generating %s: %s ...", slide_dir.name, title)
        duration = generate_audio(ssml, wav_path, speech_config)
        if duration is not None:
            total_duration += duration
            logger.info("  %s — %.1fs", wav_path.name, duration)
        else:
            logger.error("  FAILED: %s", wav_path.name)
            failed_count += 1

    if args.dry_run:
        print(f"\n--- Dry run complete: {slide_count} slides processed ---")
    else:
        if slide_count == 0:
            logger.warning(
                "No slides with speaker_notes found in %s. "
                "Verify --content-dir points to a PowerPoint skill content directory.",
                content_dir,
            )
            return EXIT_FAILURE
        logger.info(
            "Total narration: %.1fs (%.1f min) across %d slides",
            total_duration,
            total_duration / 60,
            slide_count,
        )
        if failed_count:
            logger.error("%d slide(s) failed synthesis", failed_count)

    return EXIT_FAILURE if failed_count > 0 else EXIT_SUCCESS


def configure_logging(verbose: bool = False) -> None:
    """Configure logging based on verbosity level."""
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(level=level, format="%(levelname)s: %(message)s")


def main() -> int:
    """Entry point for TTS voice-over generation."""
    parser = create_parser()
    args = parser.parse_args()
    configure_logging(verbose=args.verbose)
    try:
        return _run(args)
    except KeyboardInterrupt:
        return 130
    except BrokenPipeError:
        sys.stderr.close()
        return 1


if __name__ == "__main__":
    sys.exit(main())
