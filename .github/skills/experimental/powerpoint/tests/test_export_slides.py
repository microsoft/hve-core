# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Tests for export_slides module.

Tests mock subprocess and shutil for LibreOffice interaction and fitz for
PyMuPDF operations since these external tools may not be available.
"""

from unittest.mock import MagicMock

import pytest
from export_slides import (
    configure_logging,
    convert_pptx_to_pdf,
    create_parser,
    filter_pdf_pages,
    find_libreoffice,
    parse_slide_numbers,
    run,
)


class TestParseSlideNumbers:
    """Tests for parse_slide_numbers."""

    @pytest.mark.parametrize(
        "input_str,expected",
        [
            ("3", [3]),
            ("1,3,5", [1, 3, 5]),
            ("2,2,3", [2, 3]),
            ("5,1,3", [1, 3, 5]),
            (" 2 , 4 , 6 ", [2, 4, 6]),
            ("1,,3", [1, 3]),
        ],
    )
    def test_parse(self, input_str, expected):
        assert parse_slide_numbers(input_str) == expected


class TestFindLibreoffice:
    """Tests for find_libreoffice."""

    def test_found_on_path(self, mocker):
        mocker.patch("shutil.which", return_value="/usr/bin/libreoffice")
        result = find_libreoffice()
        assert result == "/usr/bin/libreoffice"

    def test_not_found(self, mocker):
        mocker.patch("shutil.which", return_value=None)
        mocker.patch("os.path.isfile", return_value=False)
        result = find_libreoffice()
        assert result is None

    def test_macos_fallback(self, mocker):
        mocker.patch("shutil.which", return_value=None)
        mocker.patch("platform.system", return_value="Darwin")
        mock_isfile = mocker.patch("os.path.isfile")

        def check_path(path):
            return path == "/Applications/LibreOffice.app/Contents/MacOS/soffice"

        mock_isfile.side_effect = check_path
        result = find_libreoffice()
        assert result == "/Applications/LibreOffice.app/Contents/MacOS/soffice"


class TestCreateParser:
    """Tests for create_parser."""

    def test_required_args(self):
        parser = create_parser()
        args = parser.parse_args(["--input", "deck.pptx", "--output", "out.pdf"])
        assert str(args.input) == "deck.pptx"
        assert str(args.output) == "out.pdf"

    def test_optional_slides(self):
        parser = create_parser()
        args = parser.parse_args(
            [
                "--input",
                "deck.pptx",
                "--output",
                "out.pdf",
                "--slides",
                "1,3",
            ]
        )
        assert args.slides == "1,3"

    def test_verbose_flag(self):
        parser = create_parser()
        args = parser.parse_args(
            [
                "--input",
                "deck.pptx",
                "--output",
                "out.pdf",
                "-v",
            ]
        )
        assert args.verbose is True


class TestRun:
    """Tests for run function."""

    def test_missing_input_file(self, tmp_path):
        parser = create_parser()
        args = parser.parse_args(
            [
                "--input",
                str(tmp_path / "nonexistent.pptx"),
                "--output",
                str(tmp_path / "out.pdf"),
            ]
        )
        result = run(args)
        assert result != 0

    def test_wrong_extension(self, tmp_path):
        bad_file = tmp_path / "test.txt"
        bad_file.write_text("not a pptx")
        parser = create_parser()
        args = parser.parse_args(
            [
                "--input",
                str(bad_file),
                "--output",
                str(tmp_path / "out.pdf"),
            ]
        )
        result = run(args)
        assert result != 0

    def test_full_export_no_filter(self, mocker, tmp_path):
        mock_convert = mocker.patch("export_slides.convert_pptx_to_pdf")
        pptx_file = tmp_path / "deck.pptx"
        pptx_file.write_bytes(b"PK\x03\x04")  # Minimal zip header
        mock_pdf = tmp_path / "deck.pdf"
        mock_pdf.write_bytes(b"%PDF-1.4")
        mock_convert.return_value = mock_pdf

        out_path = tmp_path / "output" / "result.pdf"
        parser = create_parser()
        args = parser.parse_args(
            [
                "--input",
                str(pptx_file),
                "--output",
                str(out_path),
            ]
        )
        result = run(args)
        assert result == 0
        assert out_path.exists()

    def test_export_with_slide_filter(self, mocker, tmp_path):
        mock_convert = mocker.patch("export_slides.convert_pptx_to_pdf")
        mock_filter = mocker.patch("export_slides.filter_pdf_pages")
        pptx_file = tmp_path / "deck.pptx"
        pptx_file.write_bytes(b"PK\x03\x04")
        mock_pdf = tmp_path / "deck.pdf"
        mock_pdf.write_bytes(b"%PDF-1.4")
        mock_convert.return_value = mock_pdf
        mock_filter.return_value = tmp_path / "filtered.pdf"

        out_path = tmp_path / "output" / "result.pdf"
        parser = create_parser()
        args = parser.parse_args(
            [
                "--input",
                str(pptx_file),
                "--output",
                str(out_path),
                "--slides",
                "1,3",
            ]
        )
        result = run(args)
        assert result == 0
        mock_filter.assert_called_once()


class TestConvertPptxToPdf:
    """Tests for convert_pptx_to_pdf via mocked subprocess."""

    def test_missing_libreoffice_exits(self, mocker, tmp_path):
        mocker.patch("export_slides.find_libreoffice", return_value=None)
        with pytest.raises(SystemExit):
            convert_pptx_to_pdf(tmp_path / "deck.pptx", tmp_path)

    def test_successful_conversion(self, mocker, tmp_path):
        mocker.patch("export_slides.find_libreoffice", return_value="/usr/bin/soffice")
        mock_run = mocker.patch("subprocess.run")
        pptx = tmp_path / "deck.pptx"
        pptx.write_bytes(b"PK")
        # Simulate LibreOffice producing the PDF
        expected_pdf = tmp_path / "deck.pdf"
        expected_pdf.write_bytes(b"%PDF-1.4")
        mock_run.return_value = MagicMock(stdout="", stderr="")

        result = convert_pptx_to_pdf(pptx, tmp_path)
        assert result == expected_pdf

    def test_libreoffice_not_found_exits(self, mocker, tmp_path):
        mocker.patch("export_slides.find_libreoffice", return_value="/usr/bin/soffice")
        mocker.patch("subprocess.run", side_effect=FileNotFoundError("not found"))
        with pytest.raises(SystemExit):
            convert_pptx_to_pdf(tmp_path / "deck.pptx", tmp_path)


class TestFilterPdfPages:
    """Tests for filter_pdf_pages via mocked fitz."""

    def test_filters_pages(self, mocker, tmp_path):
        mocker.patch.dict("sys.modules", {"fitz": MagicMock()})
        import sys

        mock_fitz = sys.modules["fitz"]
        mock_doc = MagicMock()
        mock_doc.__len__ = MagicMock(return_value=5)
        mock_new_doc = MagicMock()
        mock_fitz.open.side_effect = [mock_doc, mock_new_doc]

        pdf_path = tmp_path / "full.pdf"
        pdf_path.write_bytes(b"%PDF")
        out_path = tmp_path / "filtered.pdf"

        result = filter_pdf_pages(pdf_path, [1, 3], out_path)
        assert result == out_path
        assert mock_new_doc.insert_pdf.call_count == 2


class TestConfigureLogging:
    """Tests for configure_logging."""

    def test_verbose(self):
        configure_logging(verbose=True)

    def test_non_verbose(self):
        configure_logging(verbose=False)
