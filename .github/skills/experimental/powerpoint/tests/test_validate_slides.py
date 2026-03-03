"""Tests for validate_slides module.

The validate_slides module depends on the Copilot SDK for vision model
interaction. Tests mock external dependencies and focus on pure logic.
"""

from validate_slides import (
    IMAGE_PATTERN,
    compute_cache_key,
    create_parser,
    discover_images,
    generate_report,
    load_cached_result,
    parse_model_response,
    parse_slide_filter,
    save_cached_result,
)


class TestParseModelResponse:
    """Tests for parse_model_response."""

    def test_valid_json(self):
        content = '{"issues": [], "overall_quality": "good"}'
        result = parse_model_response(content)
        assert result["overall_quality"] == "good"
        assert result["issues"] == []

    def test_json_in_code_fence(self):
        content = '```json\n{"issues": [], "overall_quality": "good"}\n```'
        result = parse_model_response(content)
        assert result["overall_quality"] == "good"

    def test_invalid_json(self):
        result = parse_model_response("not json at all")
        assert result.get("parse_error") is True
        assert "raw_response" in result

    def test_none_input(self):
        result = parse_model_response(None)
        assert result.get("parse_error") is True

    def test_empty_string(self):
        result = parse_model_response("")
        assert result.get("parse_error") is True


class TestParseSlideFilter:
    """Tests for parse_slide_filter."""

    def test_none(self):
        assert parse_slide_filter(None) is None

    def test_single(self):
        assert parse_slide_filter("3") == {3}

    def test_multiple(self):
        assert parse_slide_filter("1,3,5") == {1, 3, 5}

    def test_whitespace(self):
        assert parse_slide_filter(" 2 , 4 ") == {2, 4}


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


class TestComputeCacheKey:
    """Tests for compute_cache_key."""

    def test_deterministic(self, tmp_path):
        img = tmp_path / "test.jpg"
        img.write_bytes(b"image data")
        key1 = compute_cache_key(img, "prompt", "model")
        key2 = compute_cache_key(img, "prompt", "model")
        assert key1 == key2

    def test_different_prompt_different_key(self, tmp_path):
        img = tmp_path / "test.jpg"
        img.write_bytes(b"image data")
        key1 = compute_cache_key(img, "prompt1", "model")
        key2 = compute_cache_key(img, "prompt2", "model")
        assert key1 != key2

    def test_different_model_different_key(self, tmp_path):
        img = tmp_path / "test.jpg"
        img.write_bytes(b"image data")
        key1 = compute_cache_key(img, "prompt", "model-a")
        key2 = compute_cache_key(img, "prompt", "model-b")
        assert key1 != key2


class TestCacheOperations:
    """Tests for load_cached_result and save_cached_result."""

    def test_save_and_load(self, tmp_path):
        cache_dir = tmp_path / "cache"
        result = {"issues": [], "overall_quality": "good"}
        save_cached_result(cache_dir, "test-key", result)
        loaded = load_cached_result(cache_dir, "test-key")
        assert loaded == result

    def test_load_missing(self, tmp_path):
        assert load_cached_result(tmp_path, "missing-key") is None

    def test_creates_cache_dir(self, tmp_path):
        cache_dir = tmp_path / "nested" / "cache"
        save_cached_result(cache_dir, "key", {"data": True})
        assert cache_dir.exists()


class TestGenerateReport:
    """Tests for generate_report."""

    def test_report_header(self):
        results = {"model": "test-model", "slide_count": 2, "slides": []}
        report = generate_report(results, cached_count=0, validated_count=2)
        assert "# Slide Validation Report" in report
        assert "test-model" in report

    def test_report_cache_stats(self):
        results = {"model": "m", "slide_count": 3, "slides": []}
        report = generate_report(results, cached_count=2, validated_count=1)
        assert "Cache hits" in report
        assert "2" in report

    def test_report_per_slide(self):
        results = {
            "model": "m",
            "slide_count": 1,
            "slides": [
                {
                    "slide_number": 1,
                    "issues": [
                        {
                            "check_type": "overlap",
                            "severity": "warning",
                            "description": "Elements overlap",
                            "location": "center",
                        },
                    ],
                    "overall_quality": "needs-attention",
                },
            ],
        }
        report = generate_report(results, cached_count=0, validated_count=1)
        assert "Slide 1" in report
        assert "overlap" in report.lower()

    def test_report_parse_error(self):
        results = {
            "model": "m",
            "slide_count": 1,
            "slides": [
                {
                    "slide_number": 1,
                    "parse_error": True,
                    "raw_response": "bad output",
                },
            ],
        }
        report = generate_report(results, cached_count=0, validated_count=1)
        assert "Could not parse" in report


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
            [
                "--image-dir",
                "images/",
                "--prompt",
                "Check slides",
            ]
        )
        assert str(args.image_dir) == "images"
        assert args.prompt == "Check slides"

    def test_defaults(self):
        parser = create_parser()
        args = parser.parse_args(
            [
                "--image-dir",
                "images/",
                "--prompt",
                "Check",
            ]
        )
        assert args.model == "claude-haiku-4.5"
        assert args.concurrency == 1
        assert args.no_cache is False


class TestConfigureLogging:
    """Tests for configure_logging."""

    def test_verbose_sets_debug(self):
        from validate_slides import configure_logging

        configure_logging(verbose=True)

    def test_non_verbose(self):
        from validate_slides import configure_logging

        configure_logging(verbose=False)


class TestLoadPrompt:
    """Tests for load_prompt."""

    def test_loads_from_prompt_arg(self):
        import argparse

        from validate_slides import load_prompt

        args = argparse.Namespace(prompt="Evaluate the slide", prompt_file=None)
        result = load_prompt(args)
        assert result == "Evaluate the slide"

    def test_loads_from_file(self, tmp_path):
        import argparse

        from validate_slides import load_prompt

        prompt_file = tmp_path / "prompt.txt"
        prompt_file.write_text("From file prompt")
        args = argparse.Namespace(prompt=None, prompt_file=prompt_file)
        result = load_prompt(args)
        assert result == "From file prompt"
