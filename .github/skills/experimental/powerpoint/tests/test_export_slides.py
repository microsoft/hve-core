"""Tests for export_slides module.

Tests mock subprocess and shutil for LibreOffice interaction and fitz for
PyMuPDF operations since these external tools may not be available.
"""

from unittest.mock import MagicMock, patch

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

    def test_single(self):
        assert parse_slide_numbers("3") == [3]

    def test_multiple(self):
        assert parse_slide_numbers("1,3,5") == [1, 3, 5]

    def test_deduplicates(self):
        result = parse_slide_numbers("2,2,3")
        assert result == [2, 3]

    def test_sorts(self):
        result = parse_slide_numbers("5,1,3")
        assert result == [1, 3, 5]

    def test_whitespace(self):
        result = parse_slide_numbers(" 2 , 4 , 6 ")
        assert result == [2, 4, 6]

    def test_empty_parts(self):
        result = parse_slide_numbers("1,,3")
        assert result == [1, 3]


class TestFindLibreoffice:
    """Tests for find_libreoffice."""

    @patch("shutil.which", return_value="/usr/bin/libreoffice")
    def test_found_on_path(self, mock_which):
        result = find_libreoffice()
        assert result == "/usr/bin/libreoffice"

    @patch("shutil.which", return_value=None)
    @patch("os.path.isfile", return_value=False)
    def test_not_found(self, mock_isfile, mock_which):
        result = find_libreoffice()
        assert result is None

    @patch("shutil.which", return_value=None)
    @patch("platform.system", return_value="Darwin")
    @patch("os.path.isfile")
    def test_macos_fallback(self, mock_isfile, mock_system, mock_which):
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

    @patch("export_slides.convert_pptx_to_pdf")
    def test_full_export_no_filter(self, mock_convert, tmp_path):
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

    @patch("export_slides.filter_pdf_pages")
    @patch("export_slides.convert_pptx_to_pdf")
    def test_export_with_slide_filter(self, mock_convert, mock_filter, tmp_path):
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

    @patch("export_slides.find_libreoffice", return_value=None)
    def test_missing_libreoffice_exits(self, mock_find, tmp_path):
        with pytest.raises(SystemExit):
            convert_pptx_to_pdf(tmp_path / "deck.pptx", tmp_path)

    @patch("subprocess.run")
    @patch("export_slides.find_libreoffice", return_value="/usr/bin/soffice")
    def test_successful_conversion(self, mock_find, mock_run, tmp_path):
        pptx = tmp_path / "deck.pptx"
        pptx.write_bytes(b"PK")
        # Simulate LibreOffice producing the PDF
        expected_pdf = tmp_path / "deck.pdf"
        expected_pdf.write_bytes(b"%PDF-1.4")
        mock_run.return_value = MagicMock(stdout="", stderr="")

        result = convert_pptx_to_pdf(pptx, tmp_path)
        assert result == expected_pdf

    @patch("subprocess.run", side_effect=FileNotFoundError("not found"))
    @patch("export_slides.find_libreoffice", return_value="/usr/bin/soffice")
    def test_libreoffice_not_found_exits(self, mock_find, mock_run, tmp_path):
        with pytest.raises(SystemExit):
            convert_pptx_to_pdf(tmp_path / "deck.pptx", tmp_path)


class TestFilterPdfPages:
    """Tests for filter_pdf_pages via mocked fitz."""

    @patch.dict("sys.modules", {"fitz": MagicMock()})
    def test_filters_pages(self, tmp_path):
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
