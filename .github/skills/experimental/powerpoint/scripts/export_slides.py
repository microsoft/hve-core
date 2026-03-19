# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Export PowerPoint slides to PDF with optional slide filtering.

Converts a PPTX file to PDF using LibreOffice headless mode. When specific
slide numbers are provided, filters the resulting PDF to include only those
pages using PyMuPDF.

Usage:
    python export_slides.py --input presentation.pptx --output slides.pdf
    python export_slides.py --input presentation.pptx --output slides.pdf --slides 1,3,5
"""

import argparse
import logging
import os
import platform
import shutil
import subprocess
import sys
import tempfile
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
    parser = argparse.ArgumentParser(description="Export PowerPoint slides to PDF")
    parser.add_argument(
        "--input", required=True, type=Path, help="Input PPTX file path"
    )
    parser.add_argument(
        "--output", required=True, type=Path, help="Output PDF file path"
    )
    parser.add_argument(
        "--slides",
        help="Comma-separated slide numbers to export (1-based, default: all)",
    )
    parser.add_argument(
        "-v", "--verbose", action="store_true", help="Enable verbose output"
    )
    return parser


def find_libreoffice() -> str | None:
    """Locate the LibreOffice/soffice executable across platforms."""
    for cmd in ("libreoffice", "soffice"):
        path = shutil.which(cmd)
        if path:
            return path

    system = platform.system()
    if system == "Darwin":
        candidates = [
            "/Applications/LibreOffice.app/Contents/MacOS/soffice",
        ]
    elif system == "Windows":
        candidates = [
            r"C:\Program Files\LibreOffice\program\soffice.exe",
            r"C:\Program Files (x86)\LibreOffice\program\soffice.exe",
        ]
    else:
        candidates = [
            "/usr/bin/libreoffice",
            "/usr/bin/soffice",
            "/snap/bin/libreoffice",
        ]

    for candidate in candidates:
        if os.path.isfile(candidate):
            return candidate

    return None


def convert_pptx_to_pdf(pptx_path: Path, output_dir: Path) -> Path:
    """Convert a PPTX file to PDF using LibreOffice headless mode.

    Args:
        pptx_path: Path to the input PPTX file.
        output_dir: Directory where the PDF will be written.

    Returns:
        Path to the generated PDF file.
    """
    soffice = find_libreoffice()
    if not soffice:
        logger.error("LibreOffice is required for PPTX-to-PDF conversion.")
        logger.error("Install via:")
        logger.error("  macOS:   brew install --cask libreoffice")
        logger.error("  Linux:   sudo apt-get install libreoffice")
        logger.error("  Windows: winget install TheDocumentFoundation.LibreOffice")
        sys.exit(EXIT_FAILURE)

    output_dir.mkdir(parents=True, exist_ok=True)
    logger.info("Converting %s to PDF via LibreOffice", pptx_path.name)

    try:
        result = subprocess.run(
            [
                soffice,
                "--headless",
                "--convert-to",
                "pdf",
                "--outdir",
                str(output_dir),
                str(pptx_path),
            ],
            capture_output=True,
            text=True,
            check=True,
        )
        logger.debug("LibreOffice stdout: %s", result.stdout)
    except subprocess.CalledProcessError as e:
        logger.error("LibreOffice conversion failed: %s", e.stderr)
        sys.exit(EXIT_FAILURE)
    except FileNotFoundError:
        logger.error("LibreOffice executable not found: %s", soffice)
        sys.exit(EXIT_FAILURE)

    pdf_name = pptx_path.stem + ".pdf"
    pdf_path = output_dir / pdf_name
    if not pdf_path.exists():
        logger.error("Expected PDF not found: %s", pdf_path)
        sys.exit(EXIT_FAILURE)

    return pdf_path


def filter_pdf_pages(pdf_path: Path, pages: list[int], output_path: Path) -> Path:
    """Extract specific pages from a PDF using PyMuPDF.

    Args:
        pdf_path: Path to the full PDF.
        pages: 1-based page numbers to keep.
        output_path: Where to write the filtered PDF.

    Returns:
        Path to the filtered PDF.
    """
    try:
        import fitz  # noqa: PLC0415 — PyMuPDF
    except ImportError:
        logger.error(
            "PyMuPDF is required for slide filtering. Install via: pip install pymupdf"
        )
        sys.exit(EXIT_FAILURE)

    doc = fitz.open(str(pdf_path))
    new_doc = fitz.open()
    total_pages = len(doc)

    for page_num in pages:
        if 1 <= page_num <= total_pages:
            new_doc.insert_pdf(doc, from_page=page_num - 1, to_page=page_num - 1)
        else:
            logger.warning(
                "Slide %d out of range (1-%d), skipping", page_num, total_pages
            )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    new_doc.save(str(output_path))
    new_doc.close()
    doc.close()

    logger.info("Filtered PDF saved: %s (%d pages)", output_path, len(pages))
    return output_path


def parse_slide_numbers(slides_str: str) -> list[int]:
    """Parse comma-separated slide numbers into a sorted list of integers."""
    numbers = []
    for part in slides_str.split(","):
        part = part.strip()
        if part:
            numbers.append(int(part))
    return sorted(set(numbers))


def run(args: argparse.Namespace) -> int:
    """Execute the export pipeline."""
    pptx_path = args.input.resolve()
    output_path = args.output.resolve()

    if not pptx_path.exists():
        logger.error("Input file not found: %s", pptx_path)
        return EXIT_ERROR

    if not pptx_path.suffix.lower() == ".pptx":
        logger.error("Input file must be a .pptx file: %s", pptx_path)
        return EXIT_ERROR

    with tempfile.TemporaryDirectory() as tmp_dir:
        tmp_path = Path(tmp_dir)
        full_pdf = convert_pptx_to_pdf(pptx_path, tmp_path)

        if args.slides:
            slide_nums = parse_slide_numbers(args.slides)
            logger.info("Filtering to slides: %s", slide_nums)
            filter_pdf_pages(full_pdf, slide_nums, output_path)
        else:
            output_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(str(full_pdf), str(output_path))
            logger.info("Full PDF exported: %s", output_path)

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
