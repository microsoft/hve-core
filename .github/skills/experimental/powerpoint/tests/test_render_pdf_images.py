"""Tests for render_pdf_images module.

Tests mock PyMuPDF (fitz) since it may not be installed in all environments.
"""

import argparse
from unittest.mock import MagicMock, patch

from render_pdf_images import (
    configure_logging,
    create_parser,
    main,
    run,
)


class TestCreateParser:
    """Tests for create_parser."""

    def test_required_args(self):
        parser = create_parser()
        args = parser.parse_args(["--input", "slides.pdf", "--output-dir", "images/"])
        assert str(args.input) == "slides.pdf"
        assert str(args.output_dir) == "images"

    def test_default_dpi(self):
        parser = create_parser()
        args = parser.parse_args(["--input", "slides.pdf", "--output-dir", "images/"])
        assert args.dpi == 150

    def test_custom_dpi(self):
        parser = create_parser()
        args = parser.parse_args(
            [
                "--input",
                "slides.pdf",
                "--output-dir",
                "images/",
                "--dpi",
                "300",
            ]
        )
        assert args.dpi == 300

    def test_verbose_flag(self):
        parser = create_parser()
        args = parser.parse_args(
            [
                "--input",
                "slides.pdf",
                "--output-dir",
                "images/",
                "-v",
            ]
        )
        assert args.verbose is True


class TestRenderPages:
    """Tests for render_pages with mocked fitz."""

    @patch.dict("sys.modules", {"fitz": MagicMock()})
    def test_render_creates_output(self, tmp_path):
        import sys

        mock_fitz = sys.modules["fitz"]
        mock_page = MagicMock()
        mock_pix = MagicMock()
        mock_page.get_pixmap.return_value = mock_pix
        mock_doc = MagicMock()
        mock_doc.__iter__ = MagicMock(return_value=iter([mock_page]))
        mock_doc.__len__ = MagicMock(return_value=1)
        mock_fitz.open.return_value = mock_doc

        from render_pdf_images import render_pages

        pdf_path = tmp_path / "test.pdf"
        pdf_path.write_bytes(b"fake pdf")
        output_dir = tmp_path / "output"

        count = render_pages(pdf_path, output_dir, 150)
        assert count == 1
        mock_pix.save.assert_called_once()

    @patch.dict("sys.modules", {"fitz": MagicMock()})
    def test_render_multiple_pages(self, tmp_path):
        import sys

        mock_fitz = sys.modules["fitz"]
        pages = [MagicMock() for _ in range(3)]
        for p in pages:
            p.get_pixmap.return_value = MagicMock()
        mock_doc = MagicMock()
        mock_doc.__iter__ = MagicMock(return_value=iter(pages))
        mock_doc.__len__ = MagicMock(return_value=3)
        mock_fitz.open.return_value = mock_doc

        from render_pdf_images import render_pages

        pdf_path = tmp_path / "test.pdf"
        pdf_path.write_bytes(b"fake pdf")
        output_dir = tmp_path / "output"

        count = render_pages(pdf_path, output_dir, 150)
        assert count == 3


class TestRun:
    """Tests for run function."""

    def test_missing_input(self, tmp_path):
        args = argparse.Namespace(
            input=tmp_path / "nonexistent.pdf",
            output_dir=tmp_path / "output",
            dpi=150,
        )
        result = run(args)
        assert result != 0  # EXIT_ERROR

    def test_wrong_extension(self, tmp_path):
        txt_file = tmp_path / "test.txt"
        txt_file.write_text("not a pdf")
        args = argparse.Namespace(
            input=txt_file,
            output_dir=tmp_path / "output",
            dpi=150,
        )
        result = run(args)
        assert result != 0  # EXIT_ERROR

    @patch("render_pdf_images.render_pages", return_value=3)
    def test_successful_run(self, mock_render, tmp_path):
        pdf_file = tmp_path / "test.pdf"
        pdf_file.write_bytes(b"%PDF-1.4")
        out_dir = tmp_path / "output"

        args = argparse.Namespace(
            input=pdf_file,
            output_dir=out_dir,
            dpi=150,
        )
        result = run(args)
        assert result == 0
        mock_render.assert_called_once()

    def test_configure_logging(self):
        configure_logging(verbose=True)
        configure_logging(verbose=False)


class TestMainRenderPdf:
    """Tests for main() entry point."""

    @patch("render_pdf_images.run", return_value=0)
    def test_main_success(self, mock_run, tmp_path):
        with patch(
            "sys.argv",
            [
                "render_pdf_images.py",
                "--input",
                str(tmp_path / "test.pdf"),
                "--output-dir",
                str(tmp_path / "out"),
            ],
        ):
            result = main()
        assert result == 0

    @patch("render_pdf_images.run", side_effect=KeyboardInterrupt)
    def test_main_keyboard_interrupt(self, mock_run, tmp_path):
        with patch(
            "sys.argv",
            [
                "render_pdf_images.py",
                "--input",
                str(tmp_path / "test.pdf"),
                "--output-dir",
                str(tmp_path / "out"),
            ],
        ):
            result = main()
        assert result == 130

    @patch("render_pdf_images.run", side_effect=RuntimeError("boom"))
    def test_main_unexpected_error(self, mock_run, tmp_path):
        with patch(
            "sys.argv",
            [
                "render_pdf_images.py",
                "--input",
                str(tmp_path / "test.pdf"),
                "--output-dir",
                str(tmp_path / "out"),
            ],
        ):
            result = main()
        assert result != 0
