# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Defense-in-depth helpers for opening PDF files with PyMuPDF.

PyMuPDF wraps the MuPDF C library, whose parser has a non-trivial CVE
history (CWE-120 buffer overflows, integer overflows, use-after-free).
A malicious or malformed PDF can crash or potentially compromise the
host process before any Python-level error handling runs.

This module provides one of several defense layers. Validation here is
necessary but not sufficient: callers should also keep PyMuPDF pinned to
a vetted version range, monitor CVE feeds, and avoid passing untrusted
PDFs to long-lived processes.

The helpers enforce three bounds before any C-level parsing occurs:

* File size ceiling -- bounds parser memory pressure.
* PDF magic-byte prefix -- rejects obvious non-PDF inputs cheaply.
* Page count ceiling -- bounds per-page allocations downstream.

Callers must not forward user-controlled values into ``max_bytes`` or
``max_pages`` without bounds-checking those parameters themselves; the
limits exist to constrain the parser's attack surface.
"""

from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path
from typing import Any

# First bytes of every valid PDF per ISO 32000-1.
PDF_MAGIC_BYTES = b"%PDF-"

# 100 MB default ceiling. Typical slide-deck PDFs are < 20 MB; 100 MB
# leaves headroom for image-heavy decks while bounding parser memory
# pressure from adversarial inputs.
MAX_PDF_BYTES = 100 * 1024 * 1024

# 1000-page default ceiling. Largest known internal decks are ~300
# pages; 1000 leaves margin without enabling DoS via 10k+ page inputs.
MAX_PDF_PAGES = 1000


class PdfSafetyError(Exception):
    """Base class for PDF validation and parsing failures."""


class PdfTooLargeError(PdfSafetyError):
    """Raised when a PDF exceeds the configured byte ceiling."""


class PdfInvalidFormatError(PdfSafetyError):
    """Raised when a file does not begin with the PDF magic bytes."""


class PdfTooManyPagesError(PdfSafetyError):
    """Raised when a PDF exceeds the configured page-count ceiling."""


class PdfParseError(PdfSafetyError):
    """Wraps any C-level MuPDF exception raised during ``fitz.open``."""


class PdfRenderError(PdfSafetyError):
    """Wraps a per-page MuPDF render failure.

    Distinct from :class:`PdfParseError`, which covers failures during
    ``fitz.open`` (document-level parsing). ``PdfRenderError`` is raised
    by callers that exercise per-page MuPDF operations such as
    ``page.get_pixmap()`` and need to surface render-time C-level
    exceptions through the typed :class:`PdfSafetyError` hierarchy.
    """


def validate_pdf_path(path: Path, max_bytes: int = MAX_PDF_BYTES) -> None:
    """Validate a PDF path before handing it to the MuPDF parser.

    Runs three cheap checks in order: regular-file check, size ceiling,
    and magic-byte prefix. Each failure raises a typed
    :class:`PdfSafetyError` subclass identifying the specific bound that
    was violated.

    Args:
        path: Filesystem path to the candidate PDF.
        max_bytes: Maximum allowed file size in bytes. Defaults to
            :data:`MAX_PDF_BYTES`.

    Raises:
        PdfInvalidFormatError: If ``path`` does not point to a regular
            file or does not begin with :data:`PDF_MAGIC_BYTES`.
        PdfTooLargeError: If the file size exceeds ``max_bytes``.
    """
    if not path.is_file():
        raise PdfInvalidFormatError(f"PDF path is not a regular file: {path}")

    size = path.stat().st_size
    if size > max_bytes:
        raise PdfTooLargeError(
            f"PDF size {size} bytes exceeds limit of {max_bytes} bytes: {path}"
        )

    with path.open("rb") as fh:
        prefix = fh.read(len(PDF_MAGIC_BYTES))
    if prefix != PDF_MAGIC_BYTES:
        raise PdfInvalidFormatError(f"PDF magic bytes missing (got {prefix!r}): {path}")


@contextmanager
def safe_open_pdf(
    path: Path,
    max_bytes: int = MAX_PDF_BYTES,
    max_pages: int = MAX_PDF_PAGES,
) -> Iterator[Any]:
    """Open a PDF with PyMuPDF under defense-in-depth bounds.

    Performs path validation via :func:`validate_pdf_path`, then opens
    the document with PyMuPDF inside a ``try`` block that converts any
    C-level exception into :class:`PdfParseError`. After a successful
    open, enforces the page-count ceiling before yielding the document.
    The document is always closed on exit, even when the caller raises.

    Args:
        path: Filesystem path to the PDF.
        max_bytes: Maximum allowed file size in bytes.
        max_pages: Maximum allowed page count.

    Yields:
        The opened :class:`fitz.Document` instance.

    Raises:
        PdfSafetyError: For any validation failure (size, format, page
            count) or any exception raised by ``fitz.open``.
    """
    validate_pdf_path(path, max_bytes)

    import fitz  # noqa: PLC0415 — PyMuPDF

    doc: Any = None
    try:
        try:
            doc = fitz.open(str(path))
        except Exception as exc:
            raise PdfParseError(f"PyMuPDF failed to open PDF: {path}") from exc

        page_count = len(doc)
        if page_count > max_pages:
            raise PdfTooManyPagesError(
                f"PDF page count {page_count} exceeds limit of {max_pages}: {path}"
            )

        yield doc
    finally:
        if doc is not None:
            doc.close()
