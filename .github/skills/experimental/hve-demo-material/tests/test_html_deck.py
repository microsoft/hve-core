# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Tests for html_deck, check_html_deck, and the T-10 render check."""

import hashlib
import json
import sys
import types
from pathlib import Path

import pytest
import yaml
from check_html_deck import DECK_URL, check_deck
from check_html_deck import main as check_deck_main
from html_deck import (
    BUILD_SUMMARY,
    COPIED_FILES,
    build_deck_source,
    github_blob_base,
    level_sources,
    main,
    slide_markup,
)
from render_checks import CheckError, build_transcript_page, content_digest
from render_checks import check_html_deck as t10
from test_render_checks import _jpeg

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
_COMMIT = "0123456789abcdef0123456789abcdef01234567"
_BASE = f"https://github.com/contoso/widgets/blob/{_COMMIT}/"


@pytest.fixture
def template(tmp_path: Path) -> Path:
    root = tmp_path / "installed/templates/deck"
    root.mkdir(parents=True)
    for name in COPIED_FILES:
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
        with pytest.raises(CheckError, match="missing or unsupported image"):
            slide_markup(5, slide, slide_dir, css, missing)
        slide["elements"].pop(1)
        css.clear()
        markup = slide_markup(5, slide, slide_dir, css, missing)
        assert 'role="img" aria-label="The lifecycle table"' in markup
        assert "<img" not in markup and "src=" not in markup
        assert len(css) == 1 and "data:image/png;base64," in css[0]
        assert missing == []


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
            "L100",
            level_dir,
            template,
            level_dir / "html-deck" / "hve-demo-L100",
            _BASE,
        )

        for name in COPIED_FILES:
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
        assert f"{_BASE}docs/README.md" in content
        assert "microsoft/hve-core" not in content
        assert "<" not in content.split("\n", 2)[2]
        css = (deck / "components.css").read_text(encoding="utf-8")
        assert css.startswith(".panel { color: red; }")
        assert ".slide-body" in css
        summary = json.loads((deck / BUILD_SUMMARY).read_text(encoding="utf-8"))
        assert summary["slides"] == 2 and summary["missing_images"] == []
        assert summary["sources"] > 0

    def test_given_no_link_base_when_built_then_no_citations(self, tmp_path, template):
        level_dir = tmp_path / "L100"
        _slide(level_dir, 1, {"title": "One"})
        deck = build_deck_source("L100", level_dir, template, level_dir / "out")
        assert 'data-sources=""' in (deck / "index.html").read_text(encoding="utf-8")
        assert "sources: {}" in (deck / "content.js").read_text(encoding="utf-8")
        summary = json.loads((deck / BUILD_SUMMARY).read_text(encoding="utf-8"))
        assert summary["sources"] > 0
        assert "Sources:" in (deck / "index.html").read_text(encoding="utf-8")

    @pytest.mark.parametrize(
        "repo_url", ["http://github.com/o/r/blob/x/", "https://github.com/o/r"]
    )
    def test_given_invalid_link_base_when_built_then_raises(
        self, tmp_path, template, repo_url
    ):
        _slide(tmp_path / "L100", 1, {"title": "One"})
        with pytest.raises(CheckError, match="repo-url"):
            build_deck_source(
                "L100", tmp_path / "L100", template, tmp_path / "out", repo_url
            )

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


class TestDeckSourceOwnership:
    """Rebuilds never overwrite source the build did not write."""

    def _build(self, level_dir, template):
        return build_deck_source("L100", level_dir, template, level_dir / "deck")

    def test_given_unchanged_previous_build_when_rebuilt_then_succeeds(
        self, tmp_path, template
    ):
        level_dir = tmp_path / "L100"
        _slide(level_dir, 1, {"title": "One"})
        deck = self._build(level_dir, template)
        first = (deck / "index.html").read_bytes()

        self._build(level_dir, template)

        assert (deck / "index.html").read_bytes() == first

    def test_given_unowned_files_when_built_then_raises(self, tmp_path, template):
        level_dir = tmp_path / "L100"
        _slide(level_dir, 1, {"title": "One"})
        deck = level_dir / "deck"
        deck.mkdir()
        (deck / "index.html").write_text("hand written", encoding="utf-8")

        with pytest.raises(CheckError, match="unowned files"):
            self._build(level_dir, template)

        assert (deck / "index.html").read_text(encoding="utf-8") == "hand written"

    @pytest.mark.parametrize(
        ("name", "content", "message"),
        [
            (
                BUILD_SUMMARY,
                '{"schema_version": 1}',
                "ownership record is incompatible",
            ),
            (BUILD_SUMMARY, "[]", "ownership record is incompatible"),
            ("index.html", "<p>edited by hand</p>", "Generated source was edited"),
        ],
        ids=["old-schema", "not-a-mapping", "edited-source"],
    )
    def test_given_changed_previous_build_when_rebuilt_then_raises_and_keeps_file(
        self, tmp_path, template, name, content, message
    ):
        level_dir = tmp_path / "L100"
        _slide(level_dir, 1, {"title": "One"})
        deck = self._build(level_dir, template)
        (deck / name).write_text(content, encoding="utf-8")

        with pytest.raises(CheckError, match=message):
            self._build(level_dir, template)

        assert (deck / name).read_text(encoding="utf-8") == content


class TestCitationSources:
    """Citation link base and the level's source list."""

    @pytest.mark.parametrize(
        "remote",
        [
            "https://github.com/contoso/widgets.git",
            "https://x-access-token:secret@github.com/contoso/widgets.git",
            "git@github.com:contoso/widgets.git",
            "ssh://git@github.com/contoso/widgets",
        ],
    )
    def test_given_github_remote_when_resolved_then_commit_blob_base(self, remote):
        assert github_blob_base(remote, _COMMIT) == _BASE

    @pytest.mark.parametrize(
        ("remote", "commit"),
        [
            ("https://dev.azure.com/contoso/_git/widgets", _COMMIT),
            ("https://github.com/contoso/widgets.git", "main"),
            ("https://github.com/contoso/widgets/extra.git", _COMMIT),
        ],
    )
    def test_given_unsupported_remote_or_ref_when_resolved_then_none(
        self, remote, commit
    ):
        assert github_blob_base(remote, commit) is None

    @pytest.mark.parametrize("name", ["output/manifest.yml", "manifest.yml"])
    def test_given_manifest_sources_when_listed_then_used_in_order(
        self, tmp_path, name
    ):
        manifest = tmp_path / name
        manifest.parent.mkdir(parents=True, exist_ok=True)
        manifest.write_text(
            yaml.safe_dump(
                {
                    "sources": [
                        {"path": "guide/intro.md"},
                        {"path": "../outside.md"},
                        {"path": "/etc/passwd"},
                        {"path": "guide/intro.md"},
                        {"path": "src/app.py"},
                    ]
                }
            ),
            encoding="utf-8",
        )
        with pytest.raises(CheckError, match="Invalid source register"):
            level_sources("L100", tmp_path)

    def test_given_no_manifest_when_listed_then_pinned_sources(self, tmp_path):
        sources = level_sources("L100", tmp_path)
        assert sources and "docs/README.md" in sources


class TestCheckHtmlDeckScript:
    """The offline browser check's file handling."""

    def test_given_missing_deck_when_run_then_fail_json(self, tmp_path):
        output = tmp_path / "check.json"
        code = check_deck_main(
            ["--deck", str(tmp_path / "none.html"), "--output", str(output)]
        )
        assert code == 1
        assert json.loads(output.read_text(encoding="utf-8"))["result"] == "fail"


class _FakeError(Exception):
    """Stands in for playwright.sync_api.Error."""


class _FakeRequest:
    def __init__(self, url, frame):
        self.url = url
        self.method = "GET"
        self.frame = frame

    def is_navigation_request(self):
        return True


class _FakeRoute:
    def __init__(self, request):
        self.request = request

    def fulfill(self, **kwargs):
        pass

    def abort(self):
        pass


class _FakeLocator:
    """Answers only the element reads check_deck makes for its selector."""

    def __init__(self, options, selector):
        self._options = options
        self._selector = selector

    def _require(self, selector):
        assert self._selector == selector, f"unexpected read of {self._selector}"

    def evaluate_all(self, script):
        self._require(".slides > section")
        return list(self._options.slide_ids)

    def text_content(self):
        self._require("#startup")
        return "Deck could not start"

    def bounding_box(self):
        self._require(".slides > section.present")
        return dict(self._options.bounds)

    def screenshot(self, **kwargs):
        self._require(".slides > section.present")
        return _jpeg(*self._options.frame_size)


_SELECTORS = {".slides > section", ".slides > section.present", "#startup"}


class _FakePage:
    def __init__(self, context, options):
        self._context = context
        self._options = options
        self.main_frame = object()

    def on(self, event, handler):
        pass

    def goto(self, url, **kwargs):
        for target in (url, *self._options.extra_requests):
            self._context.handler(_FakeRoute(_FakeRequest(target, self.main_frame)))
        if self._options.on_goto:
            self._options.on_goto()

    def wait_for_selector(self, selector, **kwargs):
        if not self._options.ready:
            raise _FakeError("timed out waiting for the deck")

    def locator(self, selector):
        assert selector in _SELECTORS, f"unexpected selector {selector}"
        return _FakeLocator(self._options, selector)

    def add_style_tag(self, **kwargs):
        pass

    def wait_for_function(self, script, **kwargs):
        pass

    def evaluate(self, script):
        return {"id": "slide-1", "title": "Welcome", "overflow": self._options.overflow}

    def click(self, selector, **kwargs):
        pass


class _FakeContext:
    def __init__(self, options):
        self._options = options
        self.handler = None

    def set_default_timeout(self, timeout):
        pass

    def route(self, pattern, handler):
        self.handler = handler

    def route_web_socket(self, pattern, handler):
        pass

    def new_page(self):
        return _FakePage(self, self._options)

    def on(self, event, handler):
        pass

    def close(self):
        pass


class _FakeBrowser:
    def __init__(self, options):
        self._options = options

    def new_context(self, **kwargs):
        return _FakeContext(self._options)

    def close(self):
        pass


class _FakePlaywright:
    def __init__(self, options):
        def launch(**kwargs):
            options.launches += 1
            return _FakeBrowser(options)

        self.chromium = types.SimpleNamespace(launch=launch)

    def __enter__(self):
        return self

    def __exit__(self, *exc_info):
        return False


@pytest.fixture
def browser(monkeypatch):
    """Install a minimal playwright.sync_api double that check_deck can drive."""
    options = types.SimpleNamespace(
        ready=True,
        overflow=False,
        extra_requests=[],
        slide_ids=["slide-1"],
        bounds={"x": 0, "y": 0, "width": 1920, "height": 1080},
        frame_size=(1920, 1080),
        on_goto=None,
        launches=0,
    )
    module = types.ModuleType("playwright.sync_api")
    module.Error = _FakeError
    module.sync_playwright = lambda: _FakePlaywright(options)
    monkeypatch.setitem(sys.modules, "playwright", types.ModuleType("playwright"))
    monkeypatch.setitem(sys.modules, "playwright.sync_api", module)
    return options


def _export_level(tmp_path, content_sha256=None):
    level_dir = tmp_path / "L100"
    (level_dir / "content").mkdir(parents=True)
    (level_dir / "content" / "notes.md").write_text("notes", encoding="utf-8")
    output = level_dir / "output"
    output.mkdir()
    deck = output / "hve-demo-L100.html"
    deck.write_bytes(b"<!doctype html><title>Deck</title>")
    build = {
        "schema_version": 2,
        "renderer": "hve-slides",
        "format": "html",
        "slide_ids": ["slide-1"],
        "content_sha256": content_sha256 or content_digest(level_dir),
    }
    (output / "html-deck-build.json").write_text(json.dumps(build), encoding="utf-8")
    return level_dir, deck


def _export(level_dir, deck):
    return check_deck_main(
        [
            "--deck",
            str(deck),
            "--output",
            str(deck.parent / "html-deck-check.json"),
            "--frames-dir",
            str(level_dir / "frames" / "deck"),
            "--level-dir",
            str(level_dir),
        ]
    )


class TestCheckDeckGuards:
    """Checks that refuse unsafe input before any browser starts."""

    @pytest.fixture(autouse=True)
    def _no_browser_launch(self, browser):
        yield
        assert browser.launches == 0, "guard ran after the browser launched"

    def test_given_missing_build_evidence_when_exported_then_raises(
        self, tmp_path, browser
    ):
        level_dir, deck = _export_level(tmp_path)
        (deck.parent / "html-deck-build.json").unlink()

        with pytest.raises(CheckError, match="Current HTML build evidence"):
            check_deck(deck, level_dir / "frames" / "deck", level_dir)

    def test_given_non_mapping_build_evidence_when_checked_then_raises(
        self, tmp_path, browser
    ):
        deck = tmp_path / "deck.html"
        deck.write_bytes(b"<html></html>")
        (tmp_path / "html-deck-build.json").write_text("[]", encoding="utf-8")

        with pytest.raises(CheckError, match="must be a mapping"):
            check_deck(deck)

    def test_given_frames_without_level_dir_when_checked_then_raises(
        self, tmp_path, browser
    ):
        level_dir, deck = _export_level(tmp_path)

        with pytest.raises(CheckError, match="requires --level-dir"):
            check_deck(deck, level_dir / "frames" / "deck")

    def test_given_frames_root_when_exported_then_raises(self, tmp_path, browser):
        level_dir, deck = _export_level(tmp_path)

        with pytest.raises(CheckError, match="dedicated frame directory"):
            check_deck(deck, level_dir / "frames", level_dir)

    def test_given_stale_build_evidence_when_exported_then_raises(
        self, tmp_path, browser
    ):
        level_dir, deck = _export_level(tmp_path, content_sha256="0" * 64)

        with pytest.raises(CheckError, match="Current HTML build evidence"):
            check_deck(deck, level_dir / "frames" / "deck", level_dir)

    def test_given_output_is_deck_when_run_then_error_and_deck_kept(
        self, tmp_path, browser, capsys
    ):
        deck = tmp_path / "deck.html"
        deck.write_bytes(b"<html></html>")

        code = check_deck_main(["--deck", str(deck), "--output", str(deck)])

        assert code == 1
        assert "Evidence must not replace the deck" in capsys.readouterr().err
        assert deck.read_bytes() == b"<html></html>"

    def test_given_export_evidence_elsewhere_when_run_then_error(
        self, tmp_path, browser, capsys
    ):
        level_dir, deck = _export_level(tmp_path)
        output = level_dir / "output" / "other.json"

        code = check_deck_main(
            [
                "--deck",
                str(deck),
                "--output",
                str(output),
                "--frames-dir",
                str(level_dir / "frames" / "deck"),
                "--level-dir",
                str(level_dir),
            ]
        )

        assert code == 1
        assert "html-deck-check.json beside the deck" in capsys.readouterr().err
        assert not output.exists()


class TestCheckDeckWithFakeBrowser:
    """Result logic and frame ownership driven through a browser double."""

    def test_given_clean_deck_when_checked_then_pass(self, tmp_path, browser):
        deck = tmp_path / "deck.html"
        deck.write_bytes(b"<html></html>")

        result = check_deck(deck)

        assert result["result"] == "pass"
        assert result["slide_ids"] == ["slide-1"]
        assert result["frames"] == []

    @pytest.mark.parametrize(
        ("setting", "value", "field"),
        [
            ("overflow", True, "overflowing_slides"),
            (
                "extra_requests",
                ["https://cdn.example.test/app.js"],
                "external_requests",
            ),
            ("ready", False, "errors"),
        ],
        ids=["overflow", "external-request", "not-started"],
    )
    def test_given_problem_when_checked_then_fail_with_reason(
        self, tmp_path, browser, setting, value, field
    ):
        deck = tmp_path / "deck.html"
        deck.write_bytes(b"<html></html>")
        setattr(browser, setting, value)

        result = check_deck(deck)

        assert result["result"] == "fail"
        assert result[field]

    def test_given_external_request_when_checked_then_url_recorded(
        self, tmp_path, browser
    ):
        deck = tmp_path / "deck.html"
        deck.write_bytes(b"<html></html>")
        browser.extra_requests = [DECK_URL, "https://cdn.example.test/app.js"]

        result = check_deck(deck)

        assert result["external_requests"] == [
            DECK_URL,
            "https://cdn.example.test/app.js",
        ]

    def test_given_current_build_when_exported_then_frame_and_record_written(
        self, tmp_path, browser
    ):
        level_dir, deck = _export_level(tmp_path)

        code = _export(level_dir, deck)

        frame = level_dir / "frames" / "deck" / "slide-001.jpg"
        evidence = json.loads(
            (deck.parent / "html-deck-check.json").read_text(encoding="utf-8")
        )
        assert code == 0
        assert frame.read_bytes() == _jpeg(1920, 1080)
        assert evidence["frames"] == [
            {
                "slide_id": "slide-1",
                "path": "frames/deck/slide-001.jpg",
                "sha256": hashlib.sha256(_jpeg(1920, 1080)).hexdigest(),
                "width": 1920,
                "height": 1080,
            }
        ]

    def test_given_owned_unchanged_frames_when_reexported_then_succeeds(
        self, tmp_path, browser
    ):
        level_dir, deck = _export_level(tmp_path)
        assert _export(level_dir, deck) == 0
        assert (level_dir / "frames" / "deck" / "slide-001.jpg").is_file()

        code = _export(level_dir, deck)

        assert code == 0

    @pytest.mark.parametrize(
        ("name", "content"),
        [("slide-001.jpg", b"edited frame"), ("notes.txt", b"stray")],
        ids=["edited-frame", "stray-file"],
    )
    def test_given_changed_frames_when_reexported_then_refused_and_kept(
        self, tmp_path, browser, name, content
    ):
        level_dir, deck = _export_level(tmp_path)
        assert _export(level_dir, deck) == 0
        target = level_dir / "frames" / "deck" / name
        target.write_bytes(content)

        code = _export(level_dir, deck)

        evidence = json.loads(
            (deck.parent / "html-deck-check.json").read_text(encoding="utf-8")
        )
        assert code == 1
        assert "Unowned, edited or obsolete frames exist" in evidence["errors"][0]
        assert target.read_bytes() == content
        assert evidence["retained_frames"][0]["path"] == "frames/deck/slide-001.jpg"


class TestCheckDeckExportGuards:
    """Guards that run in the browser session or after it, before frames install."""

    @pytest.mark.parametrize(
        "slide_ids",
        [[], ["slide-1", "slide-1"], ["slide-1", ""]],
        ids=["none", "duplicate", "blank"],
    )
    def test_given_bad_slide_ids_when_checked_then_raises(
        self, tmp_path, browser, slide_ids
    ):
        deck = tmp_path / "deck.html"
        deck.write_bytes(b"<html></html>")
        browser.slide_ids = slide_ids

        with pytest.raises(CheckError, match="nonempty unique slide IDs"):
            check_deck(deck)

    @pytest.mark.parametrize(
        ("setting", "value", "message"),
        [
            ("slide_ids", ["intro"], "canonical slide-N IDs"),
            ("slide_ids", ["slide-2"], "slide order differs"),
            ("bounds", {"x": 0, "y": 0, "width": 1280, "height": 720}, "1920x1080"),
            ("frame_size", (1280, 720), "JPEG dimensions differ"),
        ],
        ids=["non-canonical", "reordered", "canvas-size", "frame-size"],
    )
    def test_given_unusable_slide_when_exported_then_raises_without_frames(
        self, tmp_path, browser, setting, value, message
    ):
        level_dir, deck = _export_level(tmp_path)
        setattr(browser, setting, value)

        with pytest.raises(CheckError, match=message):
            check_deck(deck, level_dir / "frames" / "deck", level_dir)

        assert not (level_dir / "frames" / "deck").exists()

    @pytest.mark.parametrize(
        ("changed", "message"),
        [
            ("output/hve-demo-L100.html", "HTML/build evidence changed"),
            ("output/html-deck-build.json", "HTML/build evidence changed"),
            ("content/notes.md", "Authored content changed"),
        ],
        ids=["deck", "build-evidence", "content"],
    )
    def test_given_source_changed_during_export_when_exported_then_raises(
        self, tmp_path, browser, changed, message
    ):
        level_dir, deck = _export_level(tmp_path)
        path = level_dir / changed
        browser.on_goto = lambda: path.write_bytes(path.read_bytes() + b" ")

        with pytest.raises(CheckError, match=message):
            check_deck(deck, level_dir / "frames" / "deck", level_dir)

        assert not (level_dir / "frames" / "deck").exists()

    @pytest.mark.parametrize(
        ("prior", "message"),
        [
            ("[]", "preserve existing frames"),
            ('{"frames": "slide-001.jpg"}', "Prior frame evidence is invalid"),
        ],
        ids=["not-a-mapping", "frames-not-a-list"],
    )
    def test_given_invalid_prior_evidence_when_exported_then_frames_kept(
        self, tmp_path, browser, prior, message
    ):
        level_dir, deck = _export_level(tmp_path)
        frame = level_dir / "frames" / "deck" / "slide-001.jpg"
        frame.parent.mkdir(parents=True)
        frame.write_bytes(b"earlier frame")
        (deck.parent / "html-deck-check.json").write_text(prior, encoding="utf-8")

        with pytest.raises(CheckError, match=message):
            check_deck(deck, level_dir / "frames" / "deck", level_dir)

        assert frame.read_bytes() == b"earlier frame"


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
        build = level_dir / "output/html-deck-build.json"
        build.write_text(
            json.dumps(
                {
                    "schema_version": 2,
                    "renderer": "hve-slides",
                    "format": "html",
                    "slide_ids": [f"slide-{n}" for n in range(1, sections + 1)],
                    "content_sha256": content_digest(level_dir),
                    "missing_images": [],
                }
            ),
            encoding="utf-8",
        )
        frames = []
        for number in range(1, sections + 1):
            frame = level_dir / f"frames/deck/slide-{number:03d}.jpg"
            frame.parent.mkdir(parents=True, exist_ok=True)
            frame.write_bytes(
                bytes.fromhex("ffd8ffc00011080438078003011100021100031100ffd9")
            )
            frames.append(
                {
                    "slide_id": f"slide-{number}",
                    "path": frame.relative_to(level_dir).as_posix(),
                    "sha256": hashlib.sha256(frame.read_bytes()).hexdigest(),
                    "width": 1920,
                    "height": 1080,
                }
            )
        (level_dir / "output" / "html-deck-check.json").write_text(
            json.dumps(
                {
                    "schema_version": 2,
                    "renderer": "hve-slides",
                    "format": "html",
                    "result": browser,
                    "overflowing_slides": ["2. S2"] if browser != "pass" else [],
                    "html_sha256": hashlib.sha256(
                        (level_dir / "output/hve-demo-L100.html").read_bytes()
                    ).hexdigest(),
                    "build_sha256": hashlib.sha256(build.read_bytes()).hexdigest(),
                    "slide_ids": [f"slide-{n}" for n in range(1, sections + 1)],
                    "frames": frames,
                }
            ),
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
