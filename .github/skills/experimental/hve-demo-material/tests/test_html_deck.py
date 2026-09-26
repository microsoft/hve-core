# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Tests for html_deck, check_html_deck, and the T-10 render check."""

import json
from pathlib import Path

import check_html_deck
import html_deck
import pytest
import yaml
from html_deck import build_deck_source, main, slide_markup
from render_checks import CheckError, build_transcript_page
from render_checks import check_html_deck as t10

_TEMPLATE_INDEX = """<!doctype html>
<html lang="en">
<head>
  <title>HTML slide deck</title>
  <link rel="stylesheet" href="components.css">
</head>
<body>
    <main class="slides" tabindex="0" aria-label="Presentation">
      <section id="opening" data-title="Welcome">starter</section>
    </main>
  <nav id="presenter-controls"><span id="chapter-label">Introduction</span></nav>
</body>
</html>
"""

_PNG = (
    b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01"
    b"\x08\x06\x00\x00\x00\x1f\x15\xc4\x89"
)


@pytest.fixture
def template(tmp_path: Path) -> Path:
    root = tmp_path / "template"
    root.mkdir()
    for name in html_deck.COPIED_FILES:
        (root / name).write_text(f"/* {name} */\n", encoding="utf-8")
    (root / "components.css").write_text(".panel { color: red; }\n", encoding="utf-8")
    (root / "index.html").write_text(_TEMPLATE_INDEX, encoding="utf-8")
    return root


def _slide(level_dir: Path, number: int, data: dict) -> Path:
    slide_dir = level_dir / "content" / f"slide-{number:03d}"
    slide_dir.mkdir(parents=True, exist_ok=True)
    (slide_dir / "content.yaml").write_text(yaml.safe_dump(data), encoding="utf-8")
    return slide_dir


def _style(level_dir: Path, title: str = "HVE Core: Orientation") -> None:
    style = level_dir / "content" / "global" / "style.yaml"
    style.parent.mkdir(parents=True, exist_ok=True)
    style.write_text(
        yaml.safe_dump({"metadata": {"title": title, "subject": "First use"}}),
        encoding="utf-8",
    )


class TestSlideMarkup:
    """Semantic mapping of positioned slide elements."""

    def test_given_title_textbox_when_mapped_then_heading_once_and_lead(self, tmp_path):
        slide = {
            "title": "Your First Interaction",
            "section": "First Use",
            "elements": [
                {"type": "textbox", "top": 0.5, "text": "Your First Interaction"},
                {"type": "textbox", "top": 1.2, "text": "About one minute."},
            ],
            "speaker_notes": "Open chat <now>.",
        }
        markup = slide_markup(2, slide, tmp_path, [], [])
        assert markup.count("Your First Interaction") == 1
        assert "<h2>Your First Interaction</h2>" in markup
        assert '<div class="eyebrow">FIRST USE</div>' in markup
        assert '<p class="lead">About one minute.</p>' in markup
        assert '<aside class="notes">Open chat &lt;now&gt;.</aside>' in markup

    def test_given_text_inside_frames_when_mapped_then_one_panel_per_frame_in_a_row(
        self, tmp_path
    ):
        frame = {"type": "shape", "top": 1.6, "width": 3.6, "height": 4.0}
        slide = {
            "title": "Start from the work state",
            "elements": [
                {**frame, "left": 0.7},
                {
                    "type": "textbox",
                    "left": 1.0,
                    "top": 1.9,
                    "width": 3.0,
                    "height": 0.4,
                    "font_size": 12,
                    "font_bold": True,
                    "text": "DISCOVERY",
                },
                {
                    "type": "textbox",
                    "left": 1.0,
                    "top": 3.5,
                    "width": 3.0,
                    "height": 1.0,
                    "font_size": 16,
                    "text": "Research requirements\n- Gather evidence",
                },
                {**frame, "left": 4.8},
                {
                    "type": "textbox",
                    "left": 5.1,
                    "top": 2.4,
                    "width": 3.0,
                    "height": 0.8,
                    "font_size": 23,
                    "font_bold": True,
                    "text": "Direction is approved",
                },
            ],
        }
        markup = slide_markup(2, slide, tmp_path, [], [])
        assert markup.count('<article class="panel">') == 2
        assert '<div class="card-grid">' in markup
        assert '<p class="label">DISCOVERY</p>' in markup
        assert "<li>Gather evidence</li>" in markup
        assert "<h3>Direction is approved</h3>" in markup

    def test_given_steps_cards_flow_and_table_when_mapped_then_semantic_lists(
        self, tmp_path
    ):
        slide = {
            "title": "Journey",
            "elements": [
                {
                    "type": "numbered_step",
                    "top": 2.0,
                    "label": "Open chat",
                    "description": "Ctrl+Alt+I",
                },
                {"type": "numbered_step", "top": 3.0, "label": "Ask"},
                {
                    "type": "arrow_flow",
                    "top": 4.0,
                    "items": [{"label": "Plan"}, {"label": "Do"}],
                },
                {
                    "type": "table",
                    "top": 5.0,
                    "rows": [
                        {"cells": [{"text": "Step"}, {"text": "Time"}]},
                        {"cells": [{"text": "First"}, {"text": "1 min"}]},
                    ],
                },
                {
                    "type": "card",
                    "top": 6.0,
                    "left": 0.9,
                    "title": "A",
                    "content": [{"bullet": "x"}],
                },
                {
                    "type": "card",
                    "top": 6.0,
                    "left": 6.9,
                    "title": "B",
                    "content": ["y"],
                },
                {"type": "connector"},
            ],
        }
        markup = slide_markup(3, slide, tmp_path, [], [])
        assert (
            '<ol class="demo-steps"><li><strong>Open chat</strong>'
            "<span>Ctrl+Alt+I</span>" in markup
        )
        assert '<ol class="flow"><li>Plan</li><li>Do</li></ol>' in markup
        assert '<th scope="col">Step</th>' in markup
        assert "<td>1 min</td>" in markup
        assert '<div class="card-grid"><article class="panel"><h3>A</h3>' in markup

    def test_given_wrapped_sentence_when_mapped_then_one_paragraph(self, tmp_path):
        slide = {
            "title": "Intro",
            "elements": [
                {
                    "type": "textbox",
                    "top": 1.0,
                    "text": "Agents, prompts, and\nexecutable skills for Copilot.",
                },
                {"type": "textbox", "top": 3.0, "text": "Research\n- plan\nImplement"},
            ],
        }
        markup = slide_markup(2, slide, tmp_path, [], [])
        assert (
            '<p class="lead">Agents, prompts, and executable skills for Copilot.</p>'
            in markup
        )
        assert "<ul><li>Research</li><li>plan</li><li>Implement</li></ul>" in markup

    def test_given_image_when_mapped_then_embedded_as_css_with_label(self, tmp_path):
        slide_dir = tmp_path / "slide-005"
        (slide_dir / "images").mkdir(parents=True)
        (slide_dir / "images" / "capture-01.png").write_bytes(_PNG)
        css, missing = [], []
        slide = {
            "title": "Capture",
            "elements": [
                {
                    "type": "image",
                    "top": 1.0,
                    "path": "images/capture-01.png",
                    "alt": "The lifecycle table",
                },
                {
                    "type": "image",
                    "top": 2.0,
                    "path": "images/missing.png",
                    "alt": "Gone",
                },
                {
                    "type": "image",
                    "top": 3.0,
                    "path": "images/logo.png",
                    "decorative": True,
                },
            ],
        }
        markup = slide_markup(5, slide, slide_dir, css, missing)
        assert 'role="img" aria-label="The lifecycle table"' in markup
        assert "<img" not in markup and "src=" not in markup
        assert len(css) == 1 and "data:image/png;base64," in css[0]
        assert missing == ["slide-005/images/missing.png"]


class TestBuildDeckSource:
    """Deck source folder generation."""

    def test_given_level_when_built_then_starter_files_and_generated_sources(
        self, tmp_path, template
    ):
        level_dir = tmp_path / "L100"
        _style(level_dir)
        _slide(level_dir, 1, {"title": "Welcome & hello", "speaker_notes": "Hi."})
        _slide(level_dir, 2, {"title": "Next", "section": "Close"})
        deck = build_deck_source(
            "L100", level_dir, template, tmp_path / "slides" / "hve-demo-L100"
        )

        for name in html_deck.COPIED_FILES:
            assert (deck / name).read_text(encoding="utf-8") == f"/* {name} */\n"
        page = (deck / "index.html").read_text(encoding="utf-8")
        assert "starter" not in page
        assert "<title>HVE Core: Orientation</title>" in page
        assert page.count('<section id="slide-') == 2
        assert 'data-title="Welcome &amp; hello"' in page
        assert "<h1>Welcome &amp; hello</h1>" in page
        assert 'data-sources="source-1,' in page
        config = json.loads((deck / "deck.json").read_text(encoding="utf-8"))
        assert config["title"] == "HVE Core: Orientation"
        assert config["description"] == "First use"
        content = (deck / "content.js").read_text(encoding="utf-8")
        assert (
            "https://github.com/microsoft/hve-core/blob/main/docs/README.md" in content
        )
        assert "<" not in content.split("\n", 2)[2]
        css = (deck / "components.css").read_text(encoding="utf-8")
        assert css.startswith(".panel { color: red; }")
        assert ".slide-body" in css
        summary = json.loads(
            (deck / html_deck.BUILD_SUMMARY).read_text(encoding="utf-8")
        )
        assert summary == {"slides": 2, "missing_images": []}

    def test_given_incomplete_template_when_built_then_raises(self, tmp_path, template):
        (template / "bundle.mjs").unlink()
        _slide(tmp_path / "L100", 1, {"title": "One"})
        with pytest.raises(CheckError, match="bundle.mjs"):
            build_deck_source("L100", tmp_path / "L100", template, tmp_path / "out")

    def test_given_no_slides_when_run_then_exit_failure(
        self, tmp_path, template, capsys
    ):
        (tmp_path / "L100" / "content").mkdir(parents=True)
        code = main(
            [
                "--level",
                "L100",
                "--level-dir",
                str(tmp_path / "L100"),
                "--template",
                str(template),
                "--deck-dir",
                str(tmp_path / "out"),
            ]
        )
        assert code == 1
        assert "no slides" in capsys.readouterr().err


class TestCheckHtmlDeckScript:
    """The offline browser check's file handling."""

    def test_given_missing_deck_when_run_then_fail_json(self, tmp_path):
        output = tmp_path / "check.json"
        code = check_html_deck.main(
            ["--deck", str(tmp_path / "none.html"), "--output", str(output)]
        )
        assert code == 1
        assert json.loads(output.read_text(encoding="utf-8"))["result"] == "fail"


class TestT10:
    """T-10 scoring from the deck file and the browser result."""

    def _level(self, tmp_path: Path, slides: int = 2) -> Path:
        level_dir = tmp_path / "L100"
        for number in range(1, slides + 1):
            _slide(level_dir, number, {"title": f"S{number}"})
        (level_dir / "output").mkdir(parents=True)
        return level_dir

    def _publish(
        self, level_dir: Path, sections: int = 2, browser: str = "pass"
    ) -> None:
        body = "".join(
            f'<section id="slide-{n}"></section>' for n in range(1, sections + 1)
        )
        (level_dir / "output" / "hve-demo-L100.html").write_text(
            f'<html><body>{body}<script type="application/json" '
            'id="hve-slide-metadata">{}</script></body></html>',
            encoding="utf-8",
        )
        (level_dir / "output" / "html-deck-check.json").write_text(
            json.dumps({"result": browser, "overflowing_slides": ["2. S2"]}),
            encoding="utf-8",
        )

    def test_given_bundled_deck_and_passing_browser_when_scored_then_pass(
        self, tmp_path
    ):
        level_dir = self._level(tmp_path)
        self._publish(level_dir)
        assert t10("L100", level_dir)["result"] == "pass"

    def test_given_problems_when_scored_then_each_reported(self, tmp_path):
        level_dir = self._level(tmp_path, slides=3)
        self._publish(level_dir, sections=2, browser="fail")
        (level_dir / "output" / "html-deck-build.json").write_text(
            json.dumps({"missing_images": ["slide-002/images/a.png"]}), encoding="utf-8"
        )
        result = t10("L100", level_dir)
        assert result["result"] == "fail"
        assert "all 3 slides" in result["evidence"]
        assert "slide-002/images/a.png" in result["evidence"]
        assert "2. S2" in result["evidence"]

    def test_given_no_deck_when_scored_then_fail(self, tmp_path):
        result = t10("L100", self._level(tmp_path))
        assert result["result"] == "fail"
        assert "HTML deck missing" in result["evidence"]

    def test_given_html_deck_when_transcript_built_then_links_slides(self, tmp_path):
        level_dir = self._level(tmp_path)
        self._publish(level_dir)
        page = build_transcript_page("L100", level_dir)
        assert '<a href="hve-demo-L100.html">Open the slides (HTML)</a>' in page
