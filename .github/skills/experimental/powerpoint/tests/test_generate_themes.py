# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Tests for generate_themes module."""

import pytest
import yaml
from generate_themes import (
    create_parser,
    generate_theme,
    load_themes,
    process_directory,
    process_file,
    remap_hex_in_text,
    remap_rgb_in_python,
    run,
    update_style_metadata,
)


@pytest.fixture()
def themes_yaml(tmp_path):
    """Create a minimal themes YAML file."""
    themes = {
        "themes": {
            "light": {
                "label": "Light Theme",
                "colors": {
                    "#1B1B1F": "#FFFFFF",
                    "#F8F8FC": "#242424",
                    "#0078D4": "#0F6CBD",
                },
            },
        },
    }
    path = tmp_path / "themes.yaml"
    path.write_text(yaml.dump(themes), encoding="utf-8")
    return path


@pytest.fixture()
def base_content(tmp_path):
    """Create a minimal content directory structure."""
    content = tmp_path / "content"
    global_dir = content / "global"
    global_dir.mkdir(parents=True)

    style = {
        "dimensions": {"width_inches": 13.333, "height_inches": 7.5},
        "metadata": {"title": "Test Deck"},
        "themes": [
            {
                "name": "dark",
                "slides": [1],
                "colors": {"bg_dark": "#1B1B1F", "accent_blue": "#0078D4"},
            }
        ],
    }
    (global_dir / "style.yaml").write_text(yaml.dump(style), encoding="utf-8")

    slide_dir = content / "slide-001"
    slide_dir.mkdir()
    slide_yaml = (
        'slide: 1\ntitle: "Hello"\n'
        'background:\n  fill: "#1B1B1F"\n'
        'speaker_notes: "Test notes"\n'
    )
    (slide_dir / "content.yaml").write_text(slide_yaml, encoding="utf-8")

    # Image directory with a dummy file
    images = slide_dir / "images"
    images.mkdir()
    (images / "badge.png").write_bytes(b"\x89PNG\r\n")

    return content


class TestRemapHexInText:
    """Tests for remap_hex_in_text."""

    def test_simple_replacement(self):
        text = 'fill: "#1B1B1F"'
        result = remap_hex_in_text(text, {"#1B1B1F": "#FFFFFF"})
        assert "#FFFFFF" in result
        assert "#1B1B1F" not in result

    def test_case_insensitive(self):
        text = "color: #1b1b1f"
        result = remap_hex_in_text(text, {"#1B1B1F": "#FFFFFF"})
        assert "#FFFFFF" in result

    def test_no_match(self):
        text = "color: #AABBCC"
        result = remap_hex_in_text(text, {"#1B1B1F": "#FFFFFF"})
        assert result == text

    def test_multiple_values(self):
        text = "#1B1B1F and #0078D4"
        result = remap_hex_in_text(text, {"#1B1B1F": "#FFFFFF", "#0078D4": "#0F6CBD"})
        assert "#FFFFFF" in result
        assert "#0F6CBD" in result


class TestRemapRgbInPython:
    """Tests for remap_rgb_in_python."""

    def test_rgb_color_replacement(self):
        text = "RGBColor(0x1B, 0x1B, 0x1F)"
        result = remap_rgb_in_python(text, {"#1B1B1F": "#FFFFFF"})
        assert "RGBColor(0xFF, 0xFF, 0xFF)" in result

    def test_hex_string_in_python(self):
        text = 'shape.fill = "#1B1B1F"'
        result = remap_rgb_in_python(text, {"#1B1B1F": "#FFFFFF"})
        assert '"#FFFFFF"' in result

    def test_preserves_other_code(self):
        text = "x = 42\ny = RGBColor(0x1B, 0x1B, 0x1F)\nz = 99"
        result = remap_rgb_in_python(text, {"#1B1B1F": "#FFFFFF"})
        assert "x = 42" in result
        assert "z = 99" in result


class TestLoadThemes:
    """Tests for load_themes."""

    def test_valid_themes(self, themes_yaml):
        themes = load_themes(themes_yaml)
        assert "light" in themes
        assert "colors" in themes["light"]

    def test_missing_themes_key(self, tmp_path):
        bad = tmp_path / "bad.yaml"
        bad.write_text("not_themes: {}", encoding="utf-8")
        with pytest.raises(ValueError, match="top-level"):
            load_themes(bad)

    def test_missing_colors(self, tmp_path):
        bad = tmp_path / "bad.yaml"
        bad.write_text(
            yaml.dump({"themes": {"t1": {"label": "Test"}}}),
            encoding="utf-8",
        )
        with pytest.raises(ValueError, match="colors"):
            load_themes(bad)


class TestProcessFile:
    """Tests for process_file."""

    def test_yaml_color_remap(self, tmp_path):
        src = tmp_path / "in.yaml"
        dst = tmp_path / "out.yaml"
        src.write_text('fill: "#1B1B1F"', encoding="utf-8")
        process_file(src, dst, {"#1B1B1F": "#FFFFFF"})
        assert "#FFFFFF" in dst.read_text()

    def test_py_color_remap(self, tmp_path):
        src = tmp_path / "in.py"
        dst = tmp_path / "out.py"
        src.write_text('color = "#1B1B1F"', encoding="utf-8")
        process_file(src, dst, {"#1B1B1F": "#FFFFFF"})
        assert "#FFFFFF" in dst.read_text()

    def test_other_file_copied(self, tmp_path):
        src = tmp_path / "image.png"
        dst = tmp_path / "copy.png"
        src.write_bytes(b"\x89PNG")
        process_file(src, dst, {"#1B1B1F": "#FFFFFF"})
        assert dst.read_bytes() == b"\x89PNG"


class TestProcessDirectory:
    """Tests for process_directory."""

    def test_recursive_copy(self, base_content, tmp_path):
        dest = tmp_path / "output"
        process_directory(base_content, dest, {"#1B1B1F": "#FFFFFF"})
        assert (dest / "global" / "style.yaml").exists()
        assert (dest / "slide-001" / "content.yaml").exists()
        assert (dest / "slide-001" / "images" / "badge.png").exists()


class TestUpdateStyleMetadata:
    """Tests for update_style_metadata."""

    def test_updates_theme_name(self, tmp_path):
        style = tmp_path / "style.yaml"
        style.write_text(
            'metadata:\n  title: "My Deck"\nthemes:\n  - name: "dark"\n',
            encoding="utf-8",
        )
        update_style_metadata(style, "light", "Light Theme")
        text = style.read_text()
        assert "light" in text
        assert "Light Theme" in text

    def test_missing_file_noop(self, tmp_path):
        update_style_metadata(tmp_path / "missing.yaml", "t", "T")


class TestGenerateTheme:
    """Tests for generate_theme."""

    def test_generates_themed_dir(self, base_content, tmp_path):
        config = {
            "label": "Light Theme",
            "colors": {"#1B1B1F": "#FFFFFF", "#0078D4": "#0F6CBD"},
        }
        result = generate_theme(base_content, tmp_path, "deck", "light", config)
        assert result.exists()
        assert (result / "content" / "global" / "style.yaml").exists()
        assert (result / "content" / "slide-001" / "content.yaml").exists()
        # Verify colors were remapped
        content = (result / "content" / "slide-001" / "content.yaml").read_text()
        assert "#FFFFFF" in content


class TestCreateParser:
    """Tests for create_parser."""

    def test_required_args(self):
        parser = create_parser()
        args = parser.parse_args(
            ["--content-dir", "c", "--themes", "t.yaml", "--output-dir", "o"]
        )
        assert str(args.content_dir) == "c"
        assert str(args.themes) == "t.yaml"


class TestRun:
    """Tests for run function."""

    def test_full_run(self, base_content, themes_yaml, tmp_path):
        parser = create_parser()
        args = parser.parse_args(
            [
                "--content-dir",
                str(base_content),
                "--themes",
                str(themes_yaml),
                "--output-dir",
                str(tmp_path),
            ]
        )
        rc = run(args)
        assert rc == 0
        # Output dir name is derived from parent dir name + theme ID
        themed_dirs = list(tmp_path.glob("*-light"))
        assert len(themed_dirs) == 1
        assert (themed_dirs[0] / "content").exists()

    def test_missing_content_dir(self, themes_yaml, tmp_path):
        parser = create_parser()
        args = parser.parse_args(
            [
                "--content-dir",
                str(tmp_path / "missing"),
                "--themes",
                str(themes_yaml),
                "--output-dir",
                str(tmp_path),
            ]
        )
        rc = run(args)
        assert rc == 2
