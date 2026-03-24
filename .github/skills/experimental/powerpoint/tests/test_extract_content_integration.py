# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Integration tests for extract_content using a real PPTX fixture."""

from unittest.mock import patch

import pytest
import yaml
from extract_content import main

EXPECTED_FIXTURE = {
    "metadata": {
        "title": "Minimal Test Fixture",
        "author": "ChatGPT",
    },
    "slides": {
        1: {
            "layout": "Title Slide",
            "speaker_notes": "This is a speaker note for slide 1.",
            "texts": [
                "Test Fixture Presentation",
                "Slide with theme colors and notes",
            ],
        },
        2: {
            "layout": "Title and Content",
            "texts": ["Slide with Image", "Below is an embedded image."],
            "element_types": ["textbox", "textbox", "image"],
            "image_path": "images/image-01.png",
        },
    },
    "theme_colors": {
        "dark_1": "#000000",
        "accent_1": "#4F81BD",
    },
    "slide_1_font_color": "#0066CC",
}


def _read_yaml(path):
    return yaml.safe_load(path.read_text(encoding="utf-8"))


@pytest.mark.integration
def test_main_extracts_real_fixture(minimal_test_fixture_path, tmp_path):
    output_dir = tmp_path / "output"

    with patch(
        "sys.argv",
        [
            "extract_content.py",
            "--input",
            str(minimal_test_fixture_path),
            "--output-dir",
            str(output_dir),
        ],
    ):
        main()

    style_path = output_dir / "global" / "style.yaml"
    slide_1_path = output_dir / "slide-001" / "content.yaml"
    slide_2_path = output_dir / "slide-002" / "content.yaml"
    image_path = output_dir / "slide-002" / "images" / "image-01.png"

    assert style_path.exists()
    assert slide_1_path.exists()
    assert slide_2_path.exists()
    assert image_path.exists()

    style = _read_yaml(style_path)
    slide_1 = _read_yaml(slide_1_path)
    slide_2 = _read_yaml(slide_2_path)

    expected_slide_1 = EXPECTED_FIXTURE["slides"][1]
    expected_slide_2 = EXPECTED_FIXTURE["slides"][2]

    assert style["metadata"] == EXPECTED_FIXTURE["metadata"]
    assert slide_1["slide"] == 1
    assert slide_1["layout"] == expected_slide_1["layout"]
    assert slide_1["speaker_notes"] == expected_slide_1["speaker_notes"]
    assert [element["text"] for element in slide_1["elements"]] == expected_slide_1[
        "texts"
    ]
    assert slide_2["slide"] == 2
    assert slide_2["layout"] == expected_slide_2["layout"]
    assert [element["text"] for element in slide_2["elements"][:2]] == expected_slide_2[
        "texts"
    ]
    assert [element["type"] for element in slide_2["elements"]] == expected_slide_2[
        "element_types"
    ]
    assert slide_2["elements"][2]["path"] == expected_slide_2["image_path"]


@pytest.mark.integration
def test_main_resolves_theme_colors_for_real_fixture(
    minimal_test_fixture_path, tmp_path
):
    output_dir = tmp_path / "output"

    with patch(
        "sys.argv",
        [
            "extract_content.py",
            "--input",
            str(minimal_test_fixture_path),
            "--output-dir",
            str(output_dir),
            "--resolve-themes",
        ],
    ):
        main()

    style = _read_yaml(output_dir / "global" / "style.yaml")
    slide_1 = _read_yaml(output_dir / "slide-001" / "content.yaml")

    assert EXPECTED_FIXTURE["theme_colors"].items() <= style["theme_colors"].items()
    assert slide_1["elements"][0]["font_color"].startswith("#")
    assert (
        slide_1["elements"][0]["font_color"] == EXPECTED_FIXTURE["slide_1_font_color"]
    )
