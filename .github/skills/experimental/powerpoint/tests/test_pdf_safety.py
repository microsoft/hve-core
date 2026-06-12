# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Unit tests for :mod:`pdf_safety` defense-in-depth helpers.

These tests exercise the three bounds enforced before the MuPDF C
parser sees any bytes: file regularity + magic-byte prefix, size
ceiling, and post-open page-count ceiling. They also verify that
``safe_open_pdf`` wraps C-level parser exceptions as
:class:`PdfParseError` and always closes the document on exit.
"""

from unittest.mock import MagicMock

import pytest
from pdf_safety import (
    MAX_PDF_BYTES,
    MAX_PDF_PAGES,
    PDF_MAGIC_BYTES,
    PdfInvalidFormatError,
    PdfParseError,
    PdfRenderError,
    PdfSafetyError,
    PdfTooLargeError,
    PdfTooManyPagesError,
    safe_open_pdf,
    validate_pdf_path,
)


class TestValidatePdfPath:
    """Cheap checks that run before any MuPDF parsing."""

    def test_rejects_missing_file(self, tmp_path):
        missing = tmp_path / "nope.pdf"
        with pytest.raises(PdfInvalidFormatError, match="not a regular file"):
            validate_pdf_path(missing)

    def test_rejects_directory(self, tmp_path):
        with pytest.raises(PdfInvalidFormatError, match="not a regular file"):
            validate_pdf_path(tmp_path)

    def test_rejects_empty_file(self, tmp_path):
        empty = tmp_path / "empty.pdf"
        empty.write_bytes(b"")
        with pytest.raises(PdfInvalidFormatError, match="magic bytes missing"):
            validate_pdf_path(empty)

    def test_rejects_non_pdf_magic(self, tmp_path):
        bogus = tmp_path / "bogus.pdf"
        bogus.write_bytes(b"not a pdf file at all")
        with pytest.raises(PdfInvalidFormatError, match="magic bytes missing"):
            validate_pdf_path(bogus)

    def test_rejects_truncated_magic(self, tmp_path):
        """A file shorter than the full magic prefix must be rejected."""
        short = tmp_path / "short.pdf"
        short.write_bytes(PDF_MAGIC_BYTES[:-1])
        with pytest.raises(PdfInvalidFormatError, match="magic bytes missing"):
            validate_pdf_path(short)

    def test_rejects_oversized(self, oversized_pdf):
        """A file whose size exceeds the ceiling raises ``PdfTooLargeError``.

        Uses a small synthetic ceiling so the test stays cheap; the
        sparse-file fixture would otherwise need 100+ MB of bytes.
        """
        # 4 KB ceiling against a sparse 8 KB file — bytes never committed.
        huge = oversized_pdf(size_bytes=8 * 1024)
        with pytest.raises(PdfTooLargeError, match="exceeds limit"):
            validate_pdf_path(huge, max_bytes=4 * 1024)

    def test_accepts_valid_minimal_input(self, minimal_valid_pdf):
        """A file passing magic+size checks does not raise."""
        validate_pdf_path(minimal_valid_pdf())

    def test_uses_default_max_bytes(self, minimal_valid_pdf):
        """Default ``max_bytes`` is the module-level ceiling."""
        # Just verify it doesn't raise on a tiny file; ceiling is 100 MB.
        validate_pdf_path(minimal_valid_pdf())
        assert MAX_PDF_BYTES == 100 * 1024 * 1024


class TestSafeOpenPdf:
    """Page-count ceiling, parser-error wrapping, and resource cleanup."""

    def test_rejects_too_many_pages(self, mocker, many_page_pdf):
        path, page_count = many_page_pdf(page_count=MAX_PDF_PAGES + 1)
        mock_doc = MagicMock()
        mock_doc.__len__ = MagicMock(return_value=page_count)
        mock_fitz = MagicMock()
        mock_fitz.open.return_value = mock_doc
        mocker.patch.dict("sys.modules", {"fitz": mock_fitz})

        with pytest.raises(PdfTooManyPagesError, match="exceeds limit"):
            with safe_open_pdf(path):
                pass

        # Even on the page-count failure path, the document is closed.
        mock_doc.close.assert_called_once()

    def test_accepts_at_page_ceiling(self, mocker, many_page_pdf):
        """Exactly ``max_pages`` is allowed; ceiling is inclusive."""
        path, page_count = many_page_pdf(page_count=MAX_PDF_PAGES)
        mock_doc = MagicMock()
        mock_doc.__len__ = MagicMock(return_value=page_count)
        mock_fitz = MagicMock()
        mock_fitz.open.return_value = mock_doc
        mocker.patch.dict("sys.modules", {"fitz": mock_fitz})

        with safe_open_pdf(path) as doc:
            assert len(doc) == MAX_PDF_PAGES
        mock_doc.close.assert_called_once()

    def test_wraps_fitz_open_errors(self, mocker, minimal_valid_pdf):
        """Any ``fitz.open`` exception becomes ``PdfParseError``."""
        mock_fitz = MagicMock()
        mock_fitz.open.side_effect = RuntimeError("MuPDF: syntax error")
        mocker.patch.dict("sys.modules", {"fitz": mock_fitz})

        with pytest.raises(PdfParseError, match="failed to open PDF"):
            with safe_open_pdf(minimal_valid_pdf()):
                pass

    def test_closes_doc_on_caller_exception(self, mocker, minimal_valid_pdf):
        """``finally`` closes the doc even when the caller raises inside ``with``."""
        mock_doc = MagicMock()
        mock_doc.__len__ = MagicMock(return_value=1)
        mock_fitz = MagicMock()
        mock_fitz.open.return_value = mock_doc
        mocker.patch.dict("sys.modules", {"fitz": mock_fitz})

        with pytest.raises(ValueError, match="caller bailed"):
            with safe_open_pdf(minimal_valid_pdf()):
                raise ValueError("caller bailed")

        mock_doc.close.assert_called_once()

    def test_propagates_validation_errors(self, tmp_path):
        """Pre-open validation errors propagate as ``PdfSafetyError`` subclasses."""
        bogus = tmp_path / "bogus.pdf"
        bogus.write_bytes(b"not a pdf")
        with pytest.raises(PdfSafetyError):
            with safe_open_pdf(bogus):
                pass


class TestPdfRenderError:
    """Type-hierarchy and chaining guarantees for ``PdfRenderError``."""

    def test_is_pdf_safety_error_subclass(self):
        """``PdfRenderError`` participates in the shared safety hierarchy."""
        assert issubclass(PdfRenderError, PdfSafetyError)

    def test_distinct_from_pdf_parse_error(self):
        """Render failures must not collide with open-time parse failures."""
        assert PdfRenderError is not PdfParseError
        assert not issubclass(PdfRenderError, PdfParseError)
        assert not issubclass(PdfParseError, PdfRenderError)

    def test_exception_chaining_with_from(self):
        """``raise PdfRenderError(...) from exc`` preserves the cause chain."""
        root = RuntimeError("MuPDF: render error")
        try:
            try:
                raise root
            except RuntimeError as exc:
                raise PdfRenderError("page 3 render failed") from exc
        except PdfRenderError as caught:
            assert caught.__cause__ is root
            assert "page 3" in str(caught)
