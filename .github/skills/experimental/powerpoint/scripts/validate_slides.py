#!/usr/bin/env python3
"""Validate slide images using Copilot SDK vision models.

Sends each rendered slide image to a vision-capable model via the GitHub
Copilot SDK and returns structured JSON validation findings.

Usage:
    python validate_slides.py --image-dir /path/to/images/ --prompt "Check for..."
    python validate_slides.py --image-dir images/ --prompt-file prompt.txt --model claude-haiku-4.5
    python validate_slides.py --image-dir images/ --prompt "..." --output results.json
    python validate_slides.py --image-dir images/ --prompt "..." --report validation-report.md
    python validate_slides.py --image-dir images/ --prompt "..." --concurrency 5
    python validate_slides.py --image-dir images/ --prompt "..." --no-cache
"""

import argparse
import asyncio
import hashlib
import json
import logging
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

from copilot import CopilotClient, PermissionHandler

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_ERROR = 2

logger = logging.getLogger(__name__)

SYSTEM_MESSAGE = (
    "You are a slide presentation quality inspector. Analyze each slide image "
    "and return your findings as valid JSON only — no additional text, no "
    "markdown formatting, no code fences.\n\n"
    "Response schema:\n"
    "{\n"
    '    "issues": [\n'
    "        {\n"
    '            "check_type": "<check name>",\n'
    '            "severity": "error|warning|info",\n'
    '            "description": "<what is wrong>",\n'
    '            "location": "<where on the slide>"\n'
    "        }\n"
    "    ],\n"
    '    "overall_quality": "good|needs-attention|poor"\n'
    "}\n\n"
    'If no issues are found, return: {"issues": [], "overall_quality": "good"}'
)

IMAGE_PATTERN = re.compile(r"slide[-_](\d+)\.jpe?g$", re.IGNORECASE)


def configure_logging(verbose: bool = False) -> None:
    """Configure logging based on verbosity level."""
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(level=level, format="%(levelname)s: %(message)s")


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
        "--report", type=Path, help="Output Markdown report file path",
    )
    parser.add_argument(
        "--slides", help="Comma-separated slide numbers to validate (default: all)"
    )
    parser.add_argument(
        "--concurrency",
        type=int,
        default=3,
        help="Max concurrent slide validations (default: 3)",
    )
    parser.add_argument(
        "--cache-dir",
        type=Path,
        help="Directory for caching validation results by image hash (default: {image-dir}/cache)",
    )
    parser.add_argument(
        "--no-cache",
        action="store_true",
        help="Disable caching and re-validate all slides",
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


def parse_slide_filter(slides_arg: str | None) -> set[int] | None:
    """Parse comma-separated slide numbers into a filter set."""
    if not slides_arg:
        return None
    return {int(s.strip()) for s in slides_arg.split(",")}


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


def parse_model_response(content: str) -> dict:
    """Parse model response as JSON, handling markdown code fences.

    Args:
        content: Raw model response text.

    Returns:
        Parsed JSON dict or a dict with raw_response and parse_error flag.
    """
    try:
        return json.loads(content)
    except (json.JSONDecodeError, TypeError):
        pass

    # Try extracting JSON from markdown code block
    json_match = re.search(r"```(?:json)?\s*\n(.*?)\n```", content or "", re.DOTALL)
    if json_match:
        try:
            return json.loads(json_match.group(1))
        except json.JSONDecodeError:
            pass

    return {"raw_response": content, "parse_error": True}


def compute_cache_key(image_path: Path, prompt: str, model: str) -> str:
    """Compute a SHA-256 cache key from image content, prompt, and model."""
    h = hashlib.sha256()
    h.update(image_path.read_bytes())
    h.update(prompt.encode("utf-8"))
    h.update(model.encode("utf-8"))
    return h.hexdigest()


def load_cached_result(cache_dir: Path, cache_key: str) -> dict | None:
    """Load a cached validation result if it exists."""
    cache_file = cache_dir / f"{cache_key}.json"
    if cache_file.exists():
        return json.loads(cache_file.read_text(encoding="utf-8"))
    return None


def save_cached_result(cache_dir: Path, cache_key: str, result: dict) -> None:
    """Save a validation result to the cache directory."""
    cache_dir.mkdir(parents=True, exist_ok=True)
    cache_file = cache_dir / f"{cache_key}.json"
    cache_file.write_text(json.dumps(result, indent=2), encoding="utf-8")


SEVERITY_ICON = {"error": "❌", "warning": "⚠️", "info": "ℹ️"}
QUALITY_ICON = {"good": "✅", "needs-attention": "⚠️", "poor": "❌"}


def generate_report(results: dict, cached_count: int, validated_count: int) -> str:
    """Generate a Markdown validation report from results.

    Args:
        results: Validation results dict with model, slide_count, slides.
        cached_count: Number of slides served from cache.
        validated_count: Number of slides validated fresh.

    Returns:
        Markdown report string.
    """
    lines = ["# Slide Validation Report", ""]
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    lines.append(f"**Generated**: {ts}  ")
    lines.append(f"**Model**: {results['model']}  ")
    lines.append(f"**Slides**: {results['slide_count']}")
    lines.append("")

    # Cache statistics
    if cached_count > 0 or validated_count > 0:
        total = cached_count + validated_count
        lines.append("## Cache Statistics")
        lines.append("")
        lines.append("| Metric | Count |")
        lines.append("|-|-|")
        lines.append(f"| Cache hits | {cached_count} |")
        lines.append(f"| Validated | {validated_count} |")
        lines.append(f"| Total | {total} |")
        lines.append("")

    # Summary counts
    error_count = 0
    warning_count = 0
    info_count = 0
    parse_errors = 0
    for slide in results["slides"]:
        if slide.get("parse_error"):
            parse_errors += 1
            continue
        for issue in slide.get("issues", []):
            sev = issue.get("severity", "info")
            if sev == "error":
                error_count += 1
            elif sev == "warning":
                warning_count += 1
            else:
                info_count += 1

    lines.append("## Summary")
    lines.append("")
    lines.append("| Severity | Count |")
    lines.append("|-|-|")
    lines.append(f"| ❌ Errors | {error_count} |")
    lines.append(f"| ⚠️ Warnings | {warning_count} |")
    lines.append(f"| ℹ️ Info | {info_count} |")
    if parse_errors:
        lines.append(f"| 🔴 Parse failures | {parse_errors} |")
    lines.append("")

    # Per-slide details
    lines.append("## Per-Slide Findings")
    lines.append("")
    for slide in results["slides"]:
        num = slide.get("slide_number", "?")
        quality = slide.get("overall_quality", "unknown")
        icon = QUALITY_ICON.get(quality, "❓")
        lines.append(f"### Slide {num} {icon} {quality}")
        lines.append("")

        if slide.get("parse_error"):
            lines.append("**Could not parse model response.**")
            raw = slide.get("raw_response", "")
            if raw:
                lines.append("")
                lines.append("<details><summary>Raw response</summary>")
                lines.append("")
                lines.append(f"```\n{raw}\n```")
                lines.append("")
                lines.append("</details>")
            lines.append("")
            continue

        issues = slide.get("issues", [])
        if not issues:
            lines.append("No issues found.")
            lines.append("")
            continue

        lines.append("| Severity | Check | Location | Description |")
        lines.append("|-|-|-|-|")
        for issue in issues:
            sev = issue.get("severity", "info")
            sev_icon = SEVERITY_ICON.get(sev, "")
            check = issue.get("check_type", "")
            loc = issue.get("location", "")
            desc = issue.get("description", "")
            lines.append(f"| {sev_icon} {sev} | {check} | {loc} | {desc} |")
        lines.append("")

    return "\n".join(lines)


async def validate_slide(
    session, slide_num: int, image_path: Path, prompt: str
) -> dict:
    """Send a single slide image to the vision model for evaluation.

    Args:
        session: Active Copilot SDK session.
        slide_num: Slide number for context.
        image_path: Path to the slide JPG image.
        prompt: Validation prompt describing what to check.

    Returns:
        Dict with slide_number, image_path, issues, and overall_quality.
    """
    logger.info("Validating slide %d: %s", slide_num, image_path.name)

    response = await session.send_and_wait(
        {
            "prompt": f"Slide {slide_num}:\n\n{prompt}",
            "attachments": [{"type": "file", "path": str(image_path.resolve())}],
        }
    )

    result = parse_model_response(response.data.content)
    result["slide_number"] = slide_num
    result["image_path"] = image_path.name
    return result


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

    # Resolve cache directory: default to {image_dir}/cache when not specified
    cache_dir = args.cache_dir if args.cache_dir else image_dir / "cache"
    use_cache = not args.no_cache
    cached_results = []
    to_validate = []

    for slide_num, image_path in images:
        if use_cache:
            key = compute_cache_key(image_path, prompt, args.model)
            cached = load_cached_result(cache_dir, key)
            if cached is not None:
                logger.debug("Cache hit for slide %d", slide_num)
                cached_results.append(cached)
                continue
            logger.debug("Cache miss for slide %d", slide_num)
        to_validate.append((slide_num, image_path))

    if use_cache and cached_results:
        logger.info(
            "Cache: %d hit(s), %d to validate", len(cached_results), len(to_validate)
        )

    # Validate uncached slides concurrently
    fresh_results = []
    if to_validate:
        client = CopilotClient()
        await client.start()

        try:
            session = await client.create_session(
                {
                    "model": args.model,
                    "system_message": {"mode": "replace", "content": SYSTEM_MESSAGE},
                    "on_permission_request": PermissionHandler.approve_all,
                }
            )

            semaphore = asyncio.Semaphore(args.concurrency)

            async def validate_with_limit(slide_num, image_path):
                async with semaphore:
                    return await validate_slide(session, slide_num, image_path, prompt)

            tasks = [validate_with_limit(sn, ip) for sn, ip in to_validate]
            fresh_results = list(await asyncio.gather(*tasks))

            # Cache fresh results
            if use_cache:
                for (slide_num, image_path), result in zip(to_validate, fresh_results):
                    key = compute_cache_key(image_path, prompt, args.model)
                    save_cached_result(cache_dir, key, result)

            for result in fresh_results:
                if result.get("parse_error"):
                    logger.warning(
                        "Slide %d: Could not parse JSON response",
                        result.get("slide_number", "?"),
                    )

            await session.destroy()
        finally:
            await client.stop()

    # Merge and sort results by slide number
    all_slides = cached_results + fresh_results
    all_slides.sort(key=lambda r: r.get("slide_number", 0))

    results = {
        "model": args.model,
        "slide_count": len(images),
        "slides": all_slides,
    }

    # Output results
    output_json = json.dumps(results, indent=2)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(output_json, encoding="utf-8")
        logger.info("Results written to %s", args.output)
    else:
        print(output_json)

    # Generate Markdown report
    if args.report:
        report_md = generate_report(results, len(cached_results), len(to_validate))
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(report_md, encoding="utf-8")
        logger.info("Report written to %s", args.report)

    # Report summary
    total_issues = sum(
        len(s.get("issues", [])) for s in results["slides"] if not s.get("parse_error")
    )
    logger.info("Validation complete: %d issue(s) across %d slide(s)", total_issues, len(images))

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
