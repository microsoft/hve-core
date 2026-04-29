# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Tests for export_svg module."""

from export_svg import (
    create_parser,
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
        mocker.patch("os.path.isfile", return_value=False)
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
