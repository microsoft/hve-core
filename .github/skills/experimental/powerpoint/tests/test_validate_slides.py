"""Tests for validate_slides module.

The validate_slides module depends on the Copilot SDK for vision model
interaction. Tests mock external dependencies and focus on pure logic.
"""

import argparse
import asyncio
import json
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from validate_slides import (
    DEFAULT_SYSTEM_MESSAGE,
    IMAGE_PATTERN,
    create_parser,
    discover_images,
    load_prompt,
    main,
    parse_slide_filter,
    run,
    validate_slide,
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_args(**overrides):
    """Build an argparse.Namespace with sensible defaults for run()."""
    defaults = {
        "image_dir": Path("/tmp/imgs"),
        "prompt": "Check slides",
        "prompt_file": None,
        "model": "claude-haiku-4.5",
        "output": None,
        "slides": None,
        "verbose": False,
    }
    defaults.update(overrides)
    return argparse.Namespace(**defaults)


def _make_session_response(content: str):
    """Simulate the nested object returned by session.send_and_wait()."""
    return SimpleNamespace(data=SimpleNamespace(content=content))


# ---------------------------------------------------------------------------
# parse_slide_filter (re-exported from pptx_utils)
# ---------------------------------------------------------------------------


class TestParseSlideFilter:
    """Tests for parse_slide_filter."""

    @pytest.mark.parametrize(
        "input_str,expected",
        [
            (None, None),
            ("3", {3}),
            ("1,3,5", {1, 3, 5}),
            (" 2 , 4 ", {2, 4}),
        ],
    )
    def test_parse(self, input_str, expected):
        assert parse_slide_filter(input_str) == expected


# ---------------------------------------------------------------------------
# discover_images
# ---------------------------------------------------------------------------


class TestDiscoverImages:
    """Tests for discover_images."""

    def test_finds_slide_images(self, tmp_path):
        (tmp_path / "slide-001.jpg").write_bytes(b"img1")
        (tmp_path / "slide-002.jpg").write_bytes(b"img2")
        (tmp_path / "other.txt").write_text("not an image")
        images = discover_images(tmp_path)
        assert len(images) == 2
        assert images[0][0] == 1
        assert images[1][0] == 2

    def test_filter(self, tmp_path):
        (tmp_path / "slide-001.jpg").write_bytes(b"img1")
        (tmp_path / "slide-002.jpg").write_bytes(b"img2")
        (tmp_path / "slide-003.jpg").write_bytes(b"img3")
        images = discover_images(tmp_path, slide_filter={1, 3})
        assert len(images) == 2
        assert [n for n, _ in images] == [1, 3]

    def test_empty_dir(self, tmp_path):
        assert discover_images(tmp_path) == []

    def test_jpeg_extension(self, tmp_path):
        (tmp_path / "slide-001.jpeg").write_bytes(b"img1")
        images = discover_images(tmp_path)
        assert len(images) == 1

    def test_underscore_separator(self, tmp_path):
        (tmp_path / "slide_001.jpg").write_bytes(b"img1")
        images = discover_images(tmp_path)
        assert len(images) == 1
        assert images[0][0] == 1


# ---------------------------------------------------------------------------
# IMAGE_PATTERN
# ---------------------------------------------------------------------------


class TestImagePattern:
    """Tests for IMAGE_PATTERN regex."""

    def test_matches_jpg(self):
        assert IMAGE_PATTERN.match("slide-001.jpg") is not None

    def test_matches_jpeg(self):
        assert IMAGE_PATTERN.match("slide-002.jpeg") is not None

    def test_matches_underscore(self):
        assert IMAGE_PATTERN.match("slide_010.jpg") is not None

    def test_no_match_png(self):
        assert IMAGE_PATTERN.match("slide-001.png") is None

    def test_extracts_number(self):
        m = IMAGE_PATTERN.match("slide-005.jpg")
        assert m.group(1) == "005"

    def test_case_insensitive(self):
        assert IMAGE_PATTERN.match("slide-001.JPG") is not None
        assert IMAGE_PATTERN.match("slide-001.Jpeg") is not None


# ---------------------------------------------------------------------------
# DEFAULT_SYSTEM_MESSAGE
# ---------------------------------------------------------------------------


class TestDefaultSystemMessage:
    """Tests for DEFAULT_SYSTEM_MESSAGE content."""

    def test_contains_role(self):
        assert "slide presentation quality inspector" in DEFAULT_SYSTEM_MESSAGE

    def test_contains_overlap_check(self):
        assert "Overlapping elements" in DEFAULT_SYSTEM_MESSAGE

    def test_contains_text_overflow_check(self):
        assert "Text overflow" in DEFAULT_SYSTEM_MESSAGE

    def test_contains_margin_check(self):
        assert "margin" in DEFAULT_SYSTEM_MESSAGE

    def test_contains_contrast_check(self):
        assert "contrast" in DEFAULT_SYSTEM_MESSAGE

    def test_contains_output_format(self):
        assert "Status:" in DEFAULT_SYSTEM_MESSAGE
        assert "Findings:" in DEFAULT_SYSTEM_MESSAGE


# ---------------------------------------------------------------------------
# create_parser
# ---------------------------------------------------------------------------


class TestCreateParser:
    """Tests for create_parser."""

    def test_required_image_dir_and_prompt(self):
        parser = create_parser()
        args = parser.parse_args(["--image-dir", "images/", "--prompt", "Check slides"])
        assert str(args.image_dir) == "images"
        assert args.prompt == "Check slides"

    def test_prompt_file_alternative(self):
        parser = create_parser()
        args = parser.parse_args(
            ["--image-dir", "images/", "--prompt-file", "prompt.txt"]
        )
        assert str(args.prompt_file) == "prompt.txt"
        assert args.prompt is None

    def test_prompt_and_prompt_file_mutually_exclusive(self):
        parser = create_parser()
        with pytest.raises(SystemExit):
            parser.parse_args(
                ["--image-dir", "images/", "--prompt", "A", "--prompt-file", "B"]
            )

    def test_defaults(self):
        parser = create_parser()
        args = parser.parse_args(["--image-dir", "images/", "--prompt", "Check"])
        assert args.model == "claude-haiku-4.5"
        assert args.output is None
        assert args.slides is None
        assert args.verbose is False

    def test_model_override(self):
        parser = create_parser()
        args = parser.parse_args(
            ["--image-dir", "images/", "--prompt", "Check", "--model", "gpt-4o"]
        )
        assert args.model == "gpt-4o"

    def test_output_arg(self):
        parser = create_parser()
        args = parser.parse_args(
            ["--image-dir", "images/", "--prompt", "Check", "--output", "results.json"]
        )
        assert str(args.output) == "results.json"

    def test_slides_arg(self):
        parser = create_parser()
        args = parser.parse_args(
            ["--image-dir", "images/", "--prompt", "Check", "--slides", "1,3,5"]
        )
        assert args.slides == "1,3,5"

    def test_verbose_flag(self):
        parser = create_parser()
        args = parser.parse_args(["--image-dir", "images/", "--prompt", "Check", "-v"])
        assert args.verbose is True

    def test_no_concurrency_arg(self):
        parser = create_parser()
        args = parser.parse_args(["--image-dir", "images/", "--prompt", "Check"])
        assert not hasattr(args, "concurrency")


# ---------------------------------------------------------------------------
# load_prompt
# ---------------------------------------------------------------------------


class TestLoadPrompt:
    """Tests for load_prompt."""

    def test_returns_inline_prompt(self):
        args = argparse.Namespace(prompt="Inline prompt", prompt_file=None)
        assert load_prompt(args) == "Inline prompt"

    def test_reads_from_file(self, tmp_path):
        pf = tmp_path / "prompt.txt"
        pf.write_text("  File prompt content  ")
        args = argparse.Namespace(prompt=None, prompt_file=pf)
        assert load_prompt(args) == "File prompt content"

    def test_exits_on_missing_file(self, tmp_path):
        args = argparse.Namespace(prompt=None, prompt_file=tmp_path / "missing.txt")
        with pytest.raises(SystemExit):
            load_prompt(args)


# ---------------------------------------------------------------------------
# validate_slide (async)
# ---------------------------------------------------------------------------


class TestValidateSlide:
    """Tests for validate_slide async function."""

    def test_success(self, tmp_path):
        session = AsyncMock()
        session.send_and_wait.return_value = _make_session_response("No issues")
        image = tmp_path / "slide-001.jpg"
        image.write_bytes(b"img")

        result = asyncio.run(validate_slide(session, 1, image, "Check"))
        assert result["slide_number"] == 1
        assert result["response"] == "No issues"
        assert "error" not in result
        session.send_and_wait.assert_called_once()

    def test_retry_then_success(self, tmp_path):
        session = AsyncMock()
        session.send_and_wait.side_effect = [
            RuntimeError("transient"),
            _make_session_response("OK"),
        ]
        image = tmp_path / "slide-002.jpg"
        image.write_bytes(b"img")

        result = asyncio.run(validate_slide(session, 2, image, "Check", max_retries=2))
        assert result["response"] == "OK"
        assert session.send_and_wait.call_count == 2

    def test_all_retries_exhausted(self, tmp_path):
        session = AsyncMock()
        session.send_and_wait.side_effect = RuntimeError("permanent")
        image = tmp_path / "slide-003.jpg"
        image.write_bytes(b"img")

        result = asyncio.run(validate_slide(session, 3, image, "Check", max_retries=2))
        assert "error" in result
        assert "2 attempts" in result["error"]
        assert result["slide_number"] == 3


# ---------------------------------------------------------------------------
# run (async orchestrator)
# ---------------------------------------------------------------------------


class TestRun:
    """Tests for run async orchestrator."""

    def test_missing_image_dir(self, tmp_path):
        args = _make_args(image_dir=tmp_path / "nonexistent")
        result = asyncio.run(run(args))
        assert result == 2  # EXIT_ERROR

    def test_no_images_found(self, tmp_path):
        args = _make_args(image_dir=tmp_path)
        result = asyncio.run(run(args))
        assert result == 1  # EXIT_FAILURE

    @patch("validate_slides.CopilotClient")
    def test_successful_run_stdout(self, mock_client_cls, tmp_path, capsys):
        (tmp_path / "slide-001.jpg").write_bytes(b"img")
        args = _make_args(image_dir=tmp_path)

        mock_session = AsyncMock()
        mock_session.send_and_wait.return_value = _make_session_response("No issues")
        mock_client = AsyncMock()
        mock_client.create_session.return_value = mock_session
        mock_client_cls.return_value = mock_client

        result = asyncio.run(run(args))
        assert result == 0  # EXIT_SUCCESS

        captured = capsys.readouterr()
        output = json.loads(captured.out)
        assert output["slide_count"] == 1
        assert output["slides"][0]["response"] == "No issues"

    @patch("validate_slides.CopilotClient")
    def test_successful_run_output_file(self, mock_client_cls, tmp_path):
        (tmp_path / "slide-001.jpg").write_bytes(b"img")
        out_file = tmp_path / "out" / "results.json"
        args = _make_args(image_dir=tmp_path, output=out_file)

        mock_session = AsyncMock()
        mock_session.send_and_wait.return_value = _make_session_response("All good")
        mock_client = AsyncMock()
        mock_client.create_session.return_value = mock_session
        mock_client_cls.return_value = mock_client

        result = asyncio.run(run(args))
        assert result == 0
        assert out_file.exists()
        data = json.loads(out_file.read_text())
        assert data["slides"][0]["response"] == "All good"

    @patch("validate_slides.CopilotClient")
    def test_writes_per_slide_txt(self, mock_client_cls, tmp_path):
        (tmp_path / "slide-001.jpg").write_bytes(b"img")
        args = _make_args(image_dir=tmp_path)

        mock_session = AsyncMock()
        mock_session.send_and_wait.return_value = _make_session_response("Finding text")
        mock_client = AsyncMock()
        mock_client.create_session.return_value = mock_session
        mock_client_cls.return_value = mock_client

        asyncio.run(run(args))
        txt = tmp_path / "slide-001-validation.txt"
        assert txt.exists()
        assert "Finding text" in txt.read_text()

    @patch("validate_slides.CopilotClient")
    def test_per_slide_txt_on_error(self, mock_client_cls, tmp_path):
        (tmp_path / "slide-001.jpg").write_bytes(b"img")
        args = _make_args(image_dir=tmp_path)

        mock_session = AsyncMock()
        mock_session.send_and_wait.side_effect = RuntimeError("boom")
        mock_client = AsyncMock()
        mock_client.create_session.return_value = mock_session
        mock_client_cls.return_value = mock_client

        asyncio.run(run(args))
        txt = tmp_path / "slide-001-validation.txt"
        assert txt.exists()
        assert "Validation error" in txt.read_text()

    @patch("validate_slides.CopilotClient")
    def test_slide_filter_applied(self, mock_client_cls, tmp_path):
        (tmp_path / "slide-001.jpg").write_bytes(b"img")
        (tmp_path / "slide-002.jpg").write_bytes(b"img")
        (tmp_path / "slide-003.jpg").write_bytes(b"img")
        args = _make_args(image_dir=tmp_path, slides="1,3")

        mock_session = AsyncMock()
        mock_session.send_and_wait.return_value = _make_session_response("OK")
        mock_client = AsyncMock()
        mock_client.create_session.return_value = mock_session
        mock_client_cls.return_value = mock_client

        asyncio.run(run(args))
        assert mock_session.send_and_wait.call_count == 2

    @patch("validate_slides.CopilotClient")
    def test_uses_system_message(self, mock_client_cls, tmp_path):
        """Verify the orchestrator passes DEFAULT_SYSTEM_MESSAGE to the session."""
        (tmp_path / "slide-001.jpg").write_bytes(b"img")
        args = _make_args(image_dir=tmp_path)

        mock_session = AsyncMock()
        mock_session.send_and_wait.return_value = _make_session_response("OK")
        mock_client = AsyncMock()
        mock_client.create_session.return_value = mock_session
        mock_client_cls.return_value = mock_client

        asyncio.run(run(args))
        session_cfg = mock_client.create_session.call_args[0][0]
        assert session_cfg["system_message"]["content"] == DEFAULT_SYSTEM_MESSAGE


# ---------------------------------------------------------------------------
# main (entry point)
# ---------------------------------------------------------------------------


class TestMain:
    """Tests for main entry point."""

    @patch("validate_slides.asyncio.run", return_value=0)
    @patch("validate_slides.create_parser")
    def test_success(self, mock_parser_fn, mock_arun):
        mock_parser = MagicMock()
        mock_parser.parse_args.return_value = _make_args(verbose=False)
        mock_parser_fn.return_value = mock_parser

        assert main() == 0
        mock_arun.assert_called_once()

    @patch("validate_slides.asyncio.run", side_effect=KeyboardInterrupt)
    @patch("validate_slides.create_parser")
    def test_keyboard_interrupt(self, mock_parser_fn, mock_arun):
        mock_parser = MagicMock()
        mock_parser.parse_args.return_value = _make_args(verbose=False)
        mock_parser_fn.return_value = mock_parser

        assert main() == 130

    @patch("validate_slides.sys")
    @patch("validate_slides.asyncio.run", side_effect=BrokenPipeError)
    @patch("validate_slides.create_parser")
    def test_broken_pipe(self, mock_parser_fn, mock_arun, mock_sys):
        mock_parser = MagicMock()
        mock_parser.parse_args.return_value = _make_args(verbose=False)
        mock_parser_fn.return_value = mock_parser

        assert main() == 1  # EXIT_FAILURE
        mock_sys.stderr.close.assert_called_once()

    @patch("validate_slides.asyncio.run", side_effect=RuntimeError("fail"))
    @patch("validate_slides.create_parser")
    def test_generic_exception(self, mock_parser_fn, mock_arun):
        mock_parser = MagicMock()
        mock_parser.parse_args.return_value = _make_args(verbose=False)
        mock_parser_fn.return_value = mock_parser

        assert main() == 1  # EXIT_FAILURE
