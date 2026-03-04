"""Tests for validate_slides module.

The validate_slides module depends on the Copilot SDK for vision model
interaction. Tests mock external dependencies and focus on pure logic.
"""

import argparse
import json

import pytest
from validate_slides import (
    DEFAULT_RESPONSE_SCHEMA,
    DEFAULT_SYSTEM_MESSAGE,
    IMAGE_PATTERN,
    create_parser,
    discover_images,
    load_response_schema,
    load_system_message,
    parse_slide_filter,
)


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


class TestImagePattern:
    """Tests for IMAGE_PATTERN regex."""

    def test_matches_jpg(self):
        assert IMAGE_PATTERN.match("slide-001.jpg") is not None

    def test_matches_jpeg(self):
        assert IMAGE_PATTERN.match("slide-002.jpeg") is not None

    def test_no_match_png(self):
        assert IMAGE_PATTERN.match("slide-001.png") is None

    def test_extracts_number(self):
        m = IMAGE_PATTERN.match("slide-005.jpg")
        assert m.group(1) == "005"


class TestCreateParser:
    """Tests for create_parser."""

    def test_required_args(self):
        parser = create_parser()
        args = parser.parse_args(
            ["--image-dir", "images/", "--prompt", "Check slides"]
        )
        assert str(args.image_dir) == "images"
        assert args.prompt == "Check slides"

    def test_defaults(self):
        parser = create_parser()
        args = parser.parse_args(
            ["--image-dir", "images/", "--prompt", "Check"]
        )
        assert args.model == "claude-haiku-4.5"
        assert args.system_message is None
        assert args.system_message_file is None
        assert args.response_schema is None
        assert args.response_schema_file is None

    def test_system_message_arg(self):
        parser = create_parser()
        args = parser.parse_args(
            ["--image-dir", "images/", "--prompt", "Check",
             "--system-message", "Custom message"]
        )
        assert args.system_message == "Custom message"

    def test_system_message_file_arg(self):
        parser = create_parser()
        args = parser.parse_args(
            ["--image-dir", "images/", "--prompt", "Check",
             "--system-message-file", "msg.txt"]
        )
        assert str(args.system_message_file) == "msg.txt"

    def test_response_schema_arg(self):
        parser = create_parser()
        args = parser.parse_args(
            ["--image-dir", "images/", "--prompt", "Check",
             "--response-schema", '{"key": "value"}']
        )
        assert args.response_schema == '{"key": "value"}'

    def test_response_schema_file_arg(self):
        parser = create_parser()
        args = parser.parse_args(
            ["--image-dir", "images/", "--prompt", "Check",
             "--response-schema-file", "schema.json"]
        )
        assert str(args.response_schema_file) == "schema.json"


class TestLoadSystemMessage:
    """Tests for load_system_message."""

    def test_returns_default_when_no_args(self):
        args = argparse.Namespace(
            system_message=None, system_message_file=None
        )
        result = load_system_message(args)
        assert result == DEFAULT_SYSTEM_MESSAGE

    def test_returns_arg_value(self):
        args = argparse.Namespace(
            system_message="Custom prompt", system_message_file=None
        )
        result = load_system_message(args)
        assert result == "Custom prompt"

    def test_reads_from_file(self, tmp_path):
        msg_file = tmp_path / "message.txt"
        msg_file.write_text("File message content")
        args = argparse.Namespace(
            system_message=None, system_message_file=msg_file
        )
        result = load_system_message(args)
        assert result == "File message content"

    def test_default_contains_visual_analysis(self):
        assert "BACKGROUND" in DEFAULT_SYSTEM_MESSAGE
        assert "SHAPES" in DEFAULT_SYSTEM_MESSAGE
        assert "TEXT BOXES" in DEFAULT_SYSTEM_MESSAGE
        assert "IMAGES" in DEFAULT_SYSTEM_MESSAGE
        assert "ADDITIONAL CHARACTERISTICS" in DEFAULT_SYSTEM_MESSAGE


class TestLoadResponseSchema:
    """Tests for load_response_schema."""

    def test_returns_default_when_no_args(self):
        args = argparse.Namespace(
            response_schema=None, response_schema_file=None
        )
        result = load_response_schema(args)
        assert result == DEFAULT_RESPONSE_SCHEMA

    def test_returns_arg_value(self):
        custom_schema = '{"custom": true}'
        args = argparse.Namespace(
            response_schema=custom_schema, response_schema_file=None
        )
        result = load_response_schema(args)
        assert result == custom_schema

    def test_reads_from_file(self, tmp_path):
        schema_file = tmp_path / "schema.json"
        schema_file.write_text('{"from_file": true}')
        args = argparse.Namespace(
            response_schema=None, response_schema_file=schema_file
        )
        result = load_response_schema(args)
        assert result == '{"from_file": true}'

    def test_default_schema_is_valid_json(self):
        parsed = json.loads(DEFAULT_RESPONSE_SCHEMA)
        assert "slide_description" in parsed

    def test_default_schema_has_expected_sections(self):
        parsed = json.loads(DEFAULT_RESPONSE_SCHEMA)
        desc = parsed["slide_description"]
        assert "background" in desc
        assert "shapes" in desc
        assert "text_boxes" in desc
        assert "images" in desc
        assert "issues" in parsed
        assert "overall_quality" in parsed


class TestCreateParserNoConcurrency:
    """Verify concurrency flag was removed."""

    def test_no_concurrency_arg(self):
        parser = create_parser()
        args = parser.parse_args(
            ["--image-dir", "images/", "--prompt", "Check"]
        )
        assert not hasattr(args, "concurrency")

    def test_default_schema_is_valid_json(self):
        parsed = json.loads(DEFAULT_RESPONSE_SCHEMA)
        assert "slide_description" in parsed
        assert "issues" in parsed
        assert "overall_quality" in parsed

    def test_default_schema_has_expected_sections(self):
        parsed = json.loads(DEFAULT_RESPONSE_SCHEMA)
        desc = parsed["slide_description"]
        assert "background" in desc
        assert "shapes" in desc
        assert "text_boxes" in desc
        assert "images" in desc
        assert "additional_characteristics" in desc
