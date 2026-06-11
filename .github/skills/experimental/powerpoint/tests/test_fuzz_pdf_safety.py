# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Byte-level fuzz harness for :mod:`pdf_safety`.

Feeds arbitrary byte sequences into the validation boundary to confirm
that the only exception type which ever escapes is
:class:`PdfSafetyError` (or one of its subclasses).

Convention note: existing ``test_fuzz_*.py`` files in this skill use
Hypothesis for byte-level fuzzing; the polyglot Atheris harness lives
in :mod:`tests.fuzz_harness`. This file follows the established
``test_fuzz_*.py`` Hypothesis convention so it runs unconditionally
under pytest on every supported platform (Atheris is manylinux-only and
sits in the optional ``fuzz`` dependency group).
"""

from __future__ import annotations

import pytest
from hypothesis import given, settings
from hypothesis import strategies as st
from pdf_safety import PdfSafetyError, safe_open_pdf, validate_pdf_path


@pytest.mark.hypothesis
class TestFuzzValidatePdfPath:
    """Property: ``validate_pdf_path`` only ever raises ``PdfSafetyError``."""

    @settings(max_examples=200, deadline=None)
    @given(data=st.binary(max_size=8 * 1024))
    def test_only_pdf_safety_error_escapes(self, tmp_path_factory, data):
        path = tmp_path_factory.mktemp("fuzz") / "fuzz.pdf"
        path.write_bytes(data)
        try:
            validate_pdf_path(path)
        except PdfSafetyError:
            # Expected for any non-PDF or oversized input.
            pass
        # All other exception types propagate and fail the test, which
        # is the desired behaviour: validate_pdf_path must never leak
        # raw IOError, ValueError, or C-level crashes to callers.


@pytest.mark.hypothesis
class TestFuzzSafeOpenPdf:
    """Property: ``safe_open_pdf`` only ever raises ``PdfSafetyError``.

    Inputs that pass magic+size checks reach the real ``fitz.open``
    call, which exercises the C-level parser. Any crash, segfault, or
    raw ``fitz`` exception that escapes as something other than
    ``PdfSafetyError`` indicates a hole in the wrapping logic.
    """

    @settings(max_examples=100, deadline=None)
    @given(data=st.binary(max_size=8 * 1024))
    def test_only_pdf_safety_error_escapes(self, tmp_path_factory, data):
        path = tmp_path_factory.mktemp("fuzz") / "fuzz.pdf"
        path.write_bytes(data)
        try:
            with safe_open_pdf(path):
                # Consume one cycle and exit; we are not asserting on
                # the document content, only that no untyped exception
                # escapes the wrapper.
                pass
        except PdfSafetyError:
            pass

    @settings(max_examples=50, deadline=None)
    @given(
        magic_suffix=st.binary(min_size=0, max_size=4 * 1024),
    )
    def test_magic_prefixed_inputs_stay_bounded(self, tmp_path_factory, magic_suffix):
        """Focused arm: inputs starting with the PDF magic prefix exercise fitz."""
        path = tmp_path_factory.mktemp("fuzz") / "fuzz.pdf"
        path.write_bytes(b"%PDF-1.4\n" + magic_suffix)
        try:
            with safe_open_pdf(path):
                pass
        except PdfSafetyError:
            pass
