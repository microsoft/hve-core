#!/usr/bin/env python3
"""Validate slide images using Copilot SDK vision models.

Sends each rendered slide image to a vision-capable model via the
GitHub Copilot SDK and returns structured JSON validation findings.

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
    "You are a slide presentation visual analyst and quality inspector. "
    "Analyze each slide image and return your findings as valid JSON only "
    "-- no additional text, no markdown formatting, no code fences.\n\n"
    "CRITICAL: Each slide is unique. Examine the SPECIFIC content, layout, "
    "colors, and text visible in THIS slide image. Do NOT copy or repeat "
    "findings from other slides. Your response must reflect what you "
    "actually see in the provided image.\n\n"
    "For each slide, describe everything you observe:\n\n"
    "1. BACKGROUND: Describe background images or solid colors, gradients, "
    "patterns, or any visual treatment applied to the slide background.\n\n"
    "2. SHAPES: For each shape, describe its type, any image inside it, "
    "fill colors, alpha/transparency, visual effects (shadow, glow, "
    "reflection, soft edges), rotation angle, position on the slide, "
    "and size.\n\n"
    "3. TEXT BOXES: For each text box, describe the text content, font "
    "family, font styles (bold, italic, underline), font size, text "
    "color, alpha/transparency, visual effects (shadow, outline, glow), "
    "rotation angle, position on the slide, size, line and paragraph "
    "spacing, text orientation (horizontal, vertical, rotated), and "
    "alignment (left, center, right, justify).\n\n"
    "4. IMAGES: For each image, describe what the image shows, its "
    "dominant colors, alpha/transparency, visual effects (shadow, border, "
    "reflection), rotation angle, position on the slide, any visible "
    "cropping, and size.\n\n"
    "5. ADDITIONAL CHARACTERISTICS: Note any other unique or notable "
    "visual features not covered above, such as animations indicators, "
    "grouped elements, layering order, or decorative elements.\n\n"
    "Also evaluate the slide for quality issues including text overlay, "
    "overflow, font consistency, edge margins, element spacing, color "
    "contrast, narrow text boxes, leftover placeholders, decorative line "
    "positioning, citation collisions, column alignment, and readable "
    "fill combinations."
)

DEFAULT_RESPONSE_SCHEMA = json.dumps(
    {
        "slide_description": {
            "background": {
                "type": "solid_color|gradient|image|pattern",
                "details": "description of background",
            },
            "shapes": [
                {
                    "type": "shape type",
                    "image": "description if shape contains image, or null",
                    "fill_color": "color value or null",
                    "alpha": "transparency value 0-100",
                    "effects": "shadow, glow, reflection, etc. or none",
                    "rotation": "degrees",
                    "position": {"left": "inches from left", "top": "inches from top"},
                    "size": {"width": "inches", "height": "inches"},
                }
            ],
            "text_boxes": [
                {
                    "content": "text content",
                    "font": "font family",
                    "font_style": "bold, italic, underline, or normal",
                    "font_size": "size in points",
                    "color": "text color",
                    "alpha": "transparency value 0-100",
                    "effects": "shadow, outline, glow, or none",
                    "rotation": "degrees",
                    "position": {"left": "inches from left", "top": "inches from top"},
                    "size": {"width": "inches", "height": "inches"},
                    "spacing": "line and paragraph spacing",
                    "orientation": "horizontal, vertical, or rotated",
                    "alignment": "left, center, right, or justify",
                }
            ],
            "images": [
                {
                    "description": "what the image shows",
                    "colors": "dominant colors",
                    "alpha": "transparency value 0-100",
                    "effects": "shadow, border, reflection, or none",
                    "rotation": "degrees",
                    "position": {"left": "inches from left", "top": "inches from top"},
                    "size": {"width": "inches", "height": "inches"},
                    "cropping": "any visible cropping or none",
                }
            ],
            "additional_characteristics": "any other notable features",
        },
        "issues": [
            {
                "check_type": "check name",
                "severity": "error|warning|info",
                "description": "what is wrong",
                "location": "where on the slide",
            }
        ],
        "overall_quality": "good|needs-attention|poor",
    },
    indent=4,
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
    sys_group = parser.add_mutually_exclusive_group()
    sys_group.add_argument(
        "--system-message",
        help="Custom system message text (default: built-in visual analysis prompt)",
    )
    sys_group.add_argument(
        "--system-message-file",
        type=Path,
        help="Path to file containing a custom system message",
    )
    schema_group = parser.add_mutually_exclusive_group()
    schema_group.add_argument(
        "--response-schema",
        help="Custom response schema JSON text (default: built-in schema)",
    )
    schema_group.add_argument(
        "--response-schema-file",
        type=Path,
        help="Path to file containing a custom response schema JSON",
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


def load_system_message(args: argparse.Namespace) -> str:
    """Load the system message from argument, file, or default.

    Args:
        args: Parsed CLI arguments.

    Returns:
        System message string.
    """
    if args.system_message:
        return args.system_message
    if args.system_message_file:
        path = args.system_message_file
        if not path.exists():
            logger.error("System message file not found: %s", path)
            sys.exit(EXIT_ERROR)
        return path.read_text(encoding="utf-8").strip()
    return DEFAULT_SYSTEM_MESSAGE


def load_response_schema(args: argparse.Namespace) -> str:
    """Load the response schema from argument, file, or default.

    Args:
        args: Parsed CLI arguments.

    Returns:
        Response schema JSON string.
    """
    if args.response_schema:
        return args.response_schema
    if args.response_schema_file:
        path = args.response_schema_file
        if not path.exists():
            logger.error("Response schema file not found: %s", path)
            sys.exit(EXIT_ERROR)
        return path.read_text(encoding="utf-8").strip()
    return DEFAULT_RESPONSE_SCHEMA


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
    system_message = load_system_message(args)
    response_schema = load_response_schema(args)

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

    # Build the full system message with response schema
    full_system_message = (
        f"{system_message}\n\n"
        f"Response schema:\n{response_schema}\n\n"
        "If no issues are found, return the response schema with an empty "
        "issues array and overall_quality set to \"good\"."
    )

    client = CopilotClient()
    await client.start()

    try:
        session = await client.create_session(
            {
                "model": args.model,
                "system_message": {"mode": "replace", "content": full_system_message},
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

    # Write per-slide validation JSON files next to slide images
    for result in slide_results:
        slide_num = result.get("slide_number", 0)
        per_slide_path = image_dir / f"slide-{slide_num:03d}-validation.json"
        per_slide_json = json.dumps(result, indent=2)
        per_slide_path.write_text(per_slide_json, encoding="utf-8")
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
