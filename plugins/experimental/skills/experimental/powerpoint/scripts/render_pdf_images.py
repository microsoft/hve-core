# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Render PDF pages to JPG images using PyMuPDF.

Converts each page of a PDF file to a JPG image at the specified DPI.
Output files follow the naming pattern slide-001.jpg, slide-002.jpg, etc.
When --slide-numbers is provided, uses those numbers instead of sequential
numbering so output filenames match the original slide positions.

Usage:
    python render_pdf_images.py --input slides.pdf \
        --output-dir validation/ --dpi 150
    python render_pdf_images.py --input slides.pdf \
        --output-dir validation/ --slide-numbers 23,24,25
"""

import argparse
import logging
import sys
from pathlib import Path

from pdf_safety import PdfRenderError, PdfSafetyError, safe_open_pdf

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_ERROR = 2

logger = logging.getLogger(__name__)


def configure_logging(verbose: bool = False) -> None:
    """Configure logging based on verbosity level."""
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(level=level, format="%(levelname)s: %(message)s")


def create_parser() -> argparse.ArgumentParser:
    """Create and configure argument parser."""
    parser = argparse.ArgumentParser(
        description="Render PDF pages to JPG images via PyMuPDF"
    )
    parser.add_argument("--input", required=True, type=Path, help="Input PDF file path")
    parser.add_argument(
        "--output-dir", required=True, type=Path, help="Output directory for JPG files"
    )
    parser.add_argument(
        "--dpi", type=int, default=150, help="Resolution in DPI (default: 150)"
    )
    parser.add_argument(
        "--slide-numbers",
        help=(
            "Comma-separated original slide numbers for output naming. "
            "When provided, page N of the PDF is named slide-{slide_numbers[N]}.jpg "
            "instead of slide-{N+1}.jpg. Use when the PDF contains a filtered "
            "subset of slides so output filenames match original slide positions."
        ),
    )
    parser.add_argument(
        "-v", "--verbose", action="store_true", help="Enable verbose output"
    )
    return parser


def parse_slide_numbers(slide_numbers_str: str) -> list[int]:
    """Parse comma-separated slide numbers into a list of integers."""
    numbers = []
    for part in slide_numbers_str.split(","):
        part = part.strip()
        if part:
            numbers.append(int(part))
    return numbers


def render_pages(
    pdf_path: Path,
    output_dir: Path,
    dpi: int,
    slide_numbers: list[int] | None = None,
) -> int:
    """Render each PDF page to a JPG image.

    Args:
        pdf_path: Path to the input PDF file.
        output_dir: Directory where JPG files will be written.
        dpi: Resolution for rendered images.
        slide_numbers: Original slide numbers for output naming. When provided,
            page i of the PDF is named slide-{slide_numbers[i]}.jpg instead
            of slide-{i+1}.jpg. Must have the same length as the PDF page count.

    Returns:
        Number of pages rendered.

    Raises:
        PdfSafetyError: For any size, format, page-count, parse, or per-page
            render failure. The caller (typically :func:`run`) is responsible
            for translating the failure into a process exit code.
    """
    try:
        import fitz  # noqa: F401, PLC0415 — PyMuPDF availability check
    except ImportError:
        logger.error("PyMuPDF is required. Install via: pip install pymupdf")
        sys.exit(EXIT_FAILURE)

    output_dir.mkdir(parents=True, exist_ok=True)

    with safe_open_pdf(pdf_path) as doc:
        page_count = len(doc)

        if slide_numbers and len(slide_numbers) != page_count:
            logger.warning(
                "Slide numbers count (%d) does not match PDF page count (%d). "
                "Falling back to sequential numbering.",
                len(slide_numbers),
                page_count,
            )
            slide_numbers = None

        for i, page in enumerate(doc):
            try:
                pix = page.get_pixmap(dpi=dpi)
            except Exception as exc:  # MuPDF can raise generic RuntimeError
                raise PdfRenderError(f"render failed on page {i + 1}") from exc
            num = slide_numbers[i] if slide_numbers else i + 1
            output_file = output_dir / f"slide-{num:03d}.jpg"
            pix.save(str(output_file))
            logger.debug("Rendered page %d -> %s", i + 1, output_file.name)

        logger.info("Rendered %d pages to %s", page_count, output_dir)
        return page_count


def run(args: argparse.Namespace) -> int:
    """Execute the rendering pipeline."""
    pdf_path = args.input.resolve()
    output_dir = args.output_dir.resolve()

    if not pdf_path.exists():
        logger.error("Input file not found: %s", pdf_path)
        return EXIT_ERROR

    if not pdf_path.suffix.lower() == ".pdf":
        logger.error("Input file must be a .pdf file: %s", pdf_path)
        return EXIT_ERROR

    slide_numbers = None
    if args.slide_numbers:
        slide_numbers = parse_slide_numbers(args.slide_numbers)

    try:
        render_pages(pdf_path, output_dir, args.dpi, slide_numbers)
    except PdfSafetyError as exc:
        # PdfSafetyError covers PdfParseError (open-time failures) and
        # PdfRenderError (per-page get_pixmap failures); both are runtime
        # errors and exit EXIT_FAILURE per scripts coding standards.
        logger.error("PDF safety check failed for %s: %s", pdf_path, exc)
        return EXIT_FAILURE
    return EXIT_SUCCESS


def main() -> int:
    """Main entry point with error handling."""
    parser = create_parser()
    args = parser.parse_args()
    configure_logging(args.verbose)

    try:
        return run(args)
    except KeyboardInterrupt:
        print("\nInterrupted by user", file=sys.stderr)
        return 130
    except BrokenPipeError:
        sys.stderr.close()
        return EXIT_FAILURE
    except Exception as e:
        logger.error("Unexpected error: %s", e)
        return EXIT_FAILURE


if __name__ == "__main__":
    sys.exit(main())
