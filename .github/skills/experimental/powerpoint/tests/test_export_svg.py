# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Tests for export_svg module."""

from pathlib import Path
from unittest.mock import MagicMock

from export_svg import (
    create_parser,
    export_pdf_to_svg,
    find_libreoffice,
    main,
    run,
)


class TestCreateParser:
    """Tests for create_parser."""

    def test_required_args(self):
        parser = create_parser()
        args = parser.parse_args(["--input", "deck.pptx", "--output-dir", "svg"])
        assert str(args.input) == "deck.pptx"
        assert str(args.output_dir) == "svg"

    def test_optional_slides(self):
        parser = create_parser()
        args = parser.parse_args(
            ["--input", "d.pptx", "--output-dir", "o/", "--slides", "1,3,5"]
        )
        assert args.slides == "1,3,5"

    def test_verbose(self):
        parser = create_parser()
        args = parser.parse_args(["--input", "d.pptx", "--output-dir", "o/", "-v"])
        assert args.verbose is True


class TestFindLibreoffice:
    """Tests for find_libreoffice."""

    def test_returns_string_or_none(self):
        result = find_libreoffice()
        assert result is None or isinstance(result, str)

    def test_finds_on_path(self, mocker):
        mocker.patch("shutil.which", return_value="/usr/bin/libreoffice")
        assert find_libreoffice() == "/usr/bin/libreoffice"

    def test_returns_none_when_missing(self, mocker):
        mocker.patch("shutil.which", return_value=None)
        mocker.patch.object(Path, "is_file", return_value=False)
        assert find_libreoffice() is None


class TestRun:
    """Tests for run function."""

    def test_missing_input_file(self, tmp_path):
        parser = create_parser()
        args = parser.parse_args(
            [
                "--input",
                str(tmp_path / "missing.pptx"),
                "--output-dir",
                str(tmp_path / "out"),
            ]
        )
        rc = run(args)
        assert rc == 2

    def test_missing_libreoffice(self, mocker, tmp_path):
        deck = tmp_path / "test.pptx"
        deck.write_bytes(b"PK")  # minimal zip header
        mocker.patch("export_svg.find_libreoffice", return_value=None)
        parser = create_parser()
        args = parser.parse_args(
            [
                "--input",
                str(deck),
                "--output-dir",
                str(tmp_path / "out"),
            ]
        )
        rc = run(args)
        assert rc == 1


class TestMain:
    """Tests for main entry point."""

    def test_missing_input(self, tmp_path, monkeypatch):
        monkeypatch.setattr(
            "sys.argv",
            [
                "export_svg",
                "--input",
                str(tmp_path / "missing.pptx"),
                "--output-dir",
                str(tmp_path),
            ],
        )
        rc = main()
        assert rc == 2


class TestRunExtended:
    """Extended tests for run function edge cases."""

    def test_non_pptx_extension(self, tmp_path):
        """Non-.pptx input file returns EXIT_ERROR."""
        bad_file = tmp_path / "test.pdf"
        bad_file.write_bytes(b"fake")
        parser = create_parser()
        args = parser.parse_args(
            ["--input", str(bad_file), "--output-dir", str(tmp_path / "out")]
        )
        rc = run(args)
        assert rc == 2

    def test_with_slide_filter(self, mocker, tmp_path):
        """Slide filter is parsed and passed through."""
        deck = tmp_path / "test.pptx"
        deck.write_bytes(b"PK")
        mocker.patch("export_svg.find_libreoffice", return_value=None)
        parser = create_parser()
        args = parser.parse_args(
            [
                "--input",
                str(deck),
                "--output-dir",
                str(tmp_path / "out"),
                "--slides",
                "1,3",
            ]
        )
        rc = run(args)
        assert rc == 1


class TestExportPdfToSvg:
    """Tests for export_pdf_to_svg with mocked fitz."""

    def test_exports_all_pages(self, mocker, tmp_path):
        """All pages are exported when no slide filter is provided."""
        mock_page = MagicMock()
        mock_page.get_svg_image.return_value = "<svg></svg>"

        mock_doc = MagicMock()
        mock_doc.__len__ = MagicMock(return_value=3)
        mock_doc.__getitem__ = MagicMock(return_value=mock_page)

        mock_fitz = MagicMock()
        mock_fitz.open.return_value = mock_doc
        mocker.patch.dict("sys.modules", {"fitz": mock_fitz})

        pdf = tmp_path / "slides.pdf"
        pdf.write_bytes(b"fake")
        out = tmp_path / "svg"

        result = export_pdf_to_svg(pdf, out)
        assert len(result) == 3
        assert all(p.suffix == ".svg" for p in result)

    def test_exports_filtered_pages(self, mocker, tmp_path):
        """Only specified slides are exported."""
        mock_page = MagicMock()
        mock_page.get_svg_image.return_value = "<svg></svg>"

        mock_doc = MagicMock()
        mock_doc.__len__ = MagicMock(return_value=5)
        mock_doc.__getitem__ = MagicMock(return_value=mock_page)

        mock_fitz = MagicMock()
        mock_fitz.open.return_value = mock_doc
        mocker.patch.dict("sys.modules", {"fitz": mock_fitz})

        pdf = tmp_path / "slides.pdf"
        pdf.write_bytes(b"fake")
        out = tmp_path / "svg"

        result = export_pdf_to_svg(pdf, out, slides=[1, 3])
        assert len(result) == 2

    def test_out_of_range_slides_skipped(self, mocker, tmp_path):
        """Out-of-range slide numbers are skipped."""
        mock_page = MagicMock()
        mock_page.get_svg_image.return_value = "<svg></svg>"

        mock_doc = MagicMock()
        mock_doc.__len__ = MagicMock(return_value=2)
        mock_doc.__getitem__ = MagicMock(return_value=mock_page)

        mock_fitz = MagicMock()
        mock_fitz.open.return_value = mock_doc
        mocker.patch.dict("sys.modules", {"fitz": mock_fitz})

        pdf = tmp_path / "slides.pdf"
        pdf.write_bytes(b"fake")
        out = tmp_path / "svg"

        result = export_pdf_to_svg(pdf, out, slides=[1, 5, 10])
        assert len(result) == 1


class TestFindLibreofficePathlib:
    """Tests for find_libreoffice using Path-based file checks."""

    def test_finds_platform_candidate(self, mocker):
        """Finds LibreOffice at a platform-specific path."""
        mocker.patch("shutil.which", return_value=None)
        mocker.patch("platform.system", return_value="Linux")
        mocker.patch.object(
            Path,
            "is_file",
            lambda p: str(p) == "/usr/bin/soffice",
        )
        result = find_libreoffice()
        assert result == "/usr/bin/soffice"
