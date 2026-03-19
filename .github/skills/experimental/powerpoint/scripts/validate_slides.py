# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Validate slide images using Copilot SDK vision models.

Sends each rendered slide image to a vision-capable model via the
GitHub Copilot SDK and returns plain-text validation findings.

Usage::

    python validate_slides.py \
        --image-dir /path/to/images/ \
        --prompt "Check for..."

    python validate_slides.py \
        --image-dir images/ \
        --prompt-file prompt.txt \
        --model claude-haiku-4.5
"""

import argparse
import asyncio
import json
import logging
import re
import sys
from pathlib import Path

from copilot import CopilotClient, PermissionHandler
from pptx_utils import (
    EXIT_ERROR,
    EXIT_FAILURE,
    EXIT_SUCCESS,
    configure_logging,
    parse_slide_filter,
)

logger = logging.getLogger(__name__)

DEFAULT_SYSTEM_MESSAGE = (
    "You are a slide presentation quality inspector. "
    "Only report issues and problems you can see in the provided slide image. "
    "Do not provide a full visual inventory of the slide.\n\n"
    "Focus on these checks:\n"
    "- Overlapping elements "
    "(text through shapes, lines through words, stacked elements)\n"
    "- Text overflow or cut off at edges/box boundaries\n"
    "- Decorative lines positioned for single-line text "
    "but title wrapped to two lines\n"
    "- Source citations or footers colliding with content above\n"
    "- Elements too close (< 0.3 in gaps) or cards/sections nearly touching\n"
    "- Uneven gaps (large empty area in one place, cramped in another)\n"
    "- Insufficient margin from slide edges (< 0.5 in)\n"
    "- Columns or similar elements not aligned consistently\n"
    "- Low-contrast text (for example, light gray text on cream background)\n"
    "- Low-contrast icons (for example, dark icons on dark backgrounds "
    "without a contrasting circle)\n"
    "- Text boxes too narrow causing excessive wrapping\n"
    "- Leftover placeholder content\n\n"
    "Important judgment rule for dense slides: some decks intentionally "
    "pack content near edges or slightly outside ideal margins. "
    "Do not flag edge proximity or boundary pressure by itself when "
    "readability remains acceptable and placement appears intentional. "
    "Flag these only when content is visibly cut off, collisions occur, "
    "or readability/usability is meaningfully reduced.\n\n"
    "Return plain text only using this flexible template:\n"
    "Slide: <slide number>\n"
    "Status: <no significant issues | issues found>\n"
    "Findings:\n"
    "- [error|warning|info] <issue type>: <what is wrong> (location: <where>)\n"
    "If there are no issues, write: No significant issues found."
)

IMAGE_PATTERN = re.compile(r"slide[-_](\d+)\.jpe?g$", re.IGNORECASE)


def create_parser() -> argparse.ArgumentParser:
    """Create and configure argument parser."""
    parser = argparse.ArgumentParser(
        description="Validate slide images using Copilot SDK vision models"
    )
    parser.add_argument(
        "--image-dir",
        required=True,
        type=Path,
        help="Directory containing slide-NNN.jpg images",
    )
    prompt_group = parser.add_mutually_exclusive_group(required=True)
    prompt_group.add_argument("--prompt", help="Validation prompt text")
    prompt_group.add_argument(
        "--prompt-file", type=Path, help="Path to file containing validation prompt"
    )
    parser.add_argument(
        "--model",
        default="claude-haiku-4.5",
        help="Model ID for vision evaluation (default: claude-haiku-4.5)",
    )
    parser.add_argument(
        "--output", type=Path, help="Output JSON file path (default: stdout)"
    )
    parser.add_argument(
        "--slides", help="Comma-separated slide numbers to validate (default: all)"
    )
    parser.add_argument(
        "-v", "--verbose", action="store_true", help="Enable verbose logging"
    )
    return parser


def load_prompt(args: argparse.Namespace) -> str:
    """Load the validation prompt from argument or file."""
    if args.prompt:
        return args.prompt
    prompt_path = args.prompt_file
    if not prompt_path.exists():
        logger.error("Prompt file not found: %s", prompt_path)
        sys.exit(EXIT_ERROR)
    return prompt_path.read_text(encoding="utf-8").strip()


def discover_images(
    image_dir: Path, slide_filter: set[int] | None = None
) -> list[tuple[int, Path]]:
    """Discover slide images sorted by slide number.

    Args:
        image_dir: Directory containing slide images.
        slide_filter: Optional set of slide numbers to include.

    Returns:
        Sorted list of (slide_number, image_path) tuples.
    """
    images = []
    for f in sorted(image_dir.iterdir()):
        m = IMAGE_PATTERN.match(f.name)
        if m:
            num = int(m.group(1))
            if slide_filter is None or num in slide_filter:
                images.append((num, f))
    return images


async def validate_slide(
    session,
    slide_num: int,
    image_path: Path,
    prompt: str,
    max_retries: int = 3,
) -> dict:
    """Send a single slide image to the vision model for evaluation.

    Retries with exponential backoff on failure. Returns the raw model
    response content without parsing.

    Args:
        session: Active Copilot SDK session.
        slide_num: Slide number for context.
        image_path: Path to the slide JPG image.
        prompt: Validation prompt describing what to check.
        max_retries: Maximum number of retry attempts.

    Returns:
        Dict with slide_number, image_path, and raw response content.
    """
    last_error = None
    for attempt in range(max_retries):
        try:
            logger.info(
                "Validating slide %d: %s (attempt %d)",
                slide_num,
                image_path.name,
                attempt + 1,
            )

            response = await session.send_and_wait(
                {
                    "prompt": f"Slide {slide_num}:\n\n{prompt}",
                    "attachments": [
                        {"type": "file", "path": str(image_path.resolve())}
                    ],
                }
            )

            return {
                "slide_number": slide_num,
                "image_path": image_path.name,
                "response": response.data.content,
            }
        except Exception as e:
            last_error = e
            if attempt < max_retries - 1:
                delay = 2**attempt
                logger.warning(
                    "Slide %d failed (attempt %d): %s. Retrying in %ds...",
                    slide_num,
                    attempt + 1,
                    e,
                    delay,
                )
                await asyncio.sleep(delay)

    logger.error(
        "Slide %d failed after %d attempts: %s", slide_num, max_retries, last_error
    )
    return {
        "slide_number": slide_num,
        "image_path": image_path.name,
        "error": f"Validation failed after {max_retries} attempts: {last_error}",
    }


async def run(args: argparse.Namespace) -> int:
    """Execute slide validation workflow.

    Args:
        args: Parsed CLI arguments.

    Returns:
        Exit code.
    """
    prompt = load_prompt(args)
    slide_filter = parse_slide_filter(args.slides)
    image_dir = args.image_dir.resolve()

    if not image_dir.is_dir():
        logger.error("Image directory not found: %s", image_dir)
        return EXIT_ERROR

    images = discover_images(image_dir, slide_filter)
    if not images:
        logger.error("No slide images found in %s", image_dir)
        return EXIT_FAILURE

    logger.info(
        "Found %d slide image(s) to validate with model %s", len(images), args.model
    )

    client = CopilotClient()
    await client.start()

    try:
        session = await client.create_session(
            {
                "model": args.model,
                "system_message": {
                    "mode": "replace",
                    "content": DEFAULT_SYSTEM_MESSAGE,
                },
                "on_permission_request": PermissionHandler.approve_all,
            }
        )

        slide_results = []
        for slide_num, image_path in images:
            result = await validate_slide(session, slide_num, image_path, prompt)
            slide_results.append(result)

        await session.destroy()
    finally:
        await client.stop()

    # Sort results by slide number
    slide_results.sort(key=lambda r: r.get("slide_number", 0))

    # Write per-slide validation text files next to slide images.
    for result in slide_results:
        slide_num = result.get("slide_number", 0)
        per_slide_path = image_dir / f"slide-{slide_num:03d}-validation.txt"
        per_slide_text = result.get("response", "")
        if result.get("error"):
            per_slide_text = f"Validation error: {result['error']}"
        per_slide_path.write_text(per_slide_text.strip() + "\n", encoding="utf-8")
        logger.debug("Per-slide results written to %s", per_slide_path)

    results = {
        "model": args.model,
        "slide_count": len(images),
        "slides": slide_results,
    }

    # Output consolidated results
    output_json = json.dumps(results, indent=2)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(output_json, encoding="utf-8")
        logger.info("Results written to %s", args.output)
    else:
        print(output_json)

    # Report summary
    error_count = sum(1 for s in slide_results if s.get("error"))
    logger.info(
        "Validation complete: %d slide(s) processed, %d error(s)",
        len(images),
        error_count,
    )

    return EXIT_SUCCESS


def main() -> int:
    """Main entry point."""
    parser = create_parser()
    args = parser.parse_args()
    configure_logging(args.verbose)

    try:
        return asyncio.run(run(args))
    except KeyboardInterrupt:
        print("\nInterrupted by user", file=sys.stderr)
        return 130
    except BrokenPipeError:
        sys.stderr.close()
        return EXIT_FAILURE
    except Exception as e:
        logger.error("Validation failed: %s", e)
        return EXIT_FAILURE


if __name__ == "__main__":
    sys.exit(main())
