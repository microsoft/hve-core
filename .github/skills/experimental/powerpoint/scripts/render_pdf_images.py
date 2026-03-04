"""Render PDF pages to JPG images using PyMuPDF.

Converts each page of a PDF file to a JPG image at the specified DPI.
Output files follow the naming pattern slide-001.jpg, slide-002.jpg, etc.

Usage:
    python render_pdf_images.py --input slides.pdf --output-dir validation/ --dpi 150
"""

import argparse
import logging
import sys
from pathlib import Path

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
        "-v", "--verbose", action="store_true", help="Enable verbose output"
    )
    return parser


def render_pages(pdf_path: Path, output_dir: Path, dpi: int) -> int:
    """Render each PDF page to a JPG image.

    Args:
        pdf_path: Path to the input PDF file.
        output_dir: Directory where JPG files will be written.
        dpi: Resolution for rendered images.

    Returns:
        Number of pages rendered.
    """
    try:
        import fitz  # noqa: PLC0415 — PyMuPDF
    except ImportError:
        logger.error("PyMuPDF is required. Install via: pip install pymupdf")
        sys.exit(EXIT_FAILURE)

    output_dir.mkdir(parents=True, exist_ok=True)
    doc = fitz.open(str(pdf_path))
    page_count = len(doc)

    for i, page in enumerate(doc):
        pix = page.get_pixmap(dpi=dpi)
        output_file = output_dir / f"slide-{i + 1:03d}.jpg"
        pix.save(str(output_file))
        logger.debug("Rendered page %d -> %s", i + 1, output_file.name)

    doc.close()
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

    render_pages(pdf_path, output_dir, args.dpi)
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
