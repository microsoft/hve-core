# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Tests for the VS Code Web capture plan validator and font measurement."""

from __future__ import annotations

import pytest
from capture_vscode import (
    DEFAULT_FONT_SIZE_PX,
    DEFAULT_MIN_FONT_PT,
    DEFAULT_START_ZOOM,
    EXIT_FAILURE,
    PlanError,
    capture_settings,
    contained_path,
    main,
    rendered_font_pt,
    validate_plan,
)


def _plan(**overrides):
    plan = {
        "captures": [
            {"id": "manifest", "file": "plugin.json", "output": "frames/a.png"},
        ]
    }
    plan.update(overrides)
    return plan


class TestValidatePlan:
    def test_given_minimal_plan_when_validated_then_applies_defaults(self):
        settings, captures = validate_plan(_plan())

        assert settings["width"] == 1920
        assert settings["height"] == 1080
        assert settings["min_font_pt"] == 18.0
        assert captures == [
            {
                "id": "manifest",
                "file": "plugin.json",
                "output": "frames/a.png",
                "line": 1,
            }
        ]

    def test_given_markdown_target_when_validated_then_rejects(self):
        plan = _plan(
            captures=[{"id": "doc", "file": "docs/README.md", "output": "a.png"}]
        )

        with pytest.raises(PlanError, match="cannot be measured"):
            validate_plan(plan)

    def test_given_duplicate_ids_when_validated_then_rejects(self):
        capture = {"id": "same", "file": "a.json", "output": "a.png"}

        with pytest.raises(PlanError, match="duplicate capture id"):
            validate_plan(_plan(captures=[capture, dict(capture)]))

    @pytest.mark.parametrize("field", ["id", "file", "output"])
    def test_given_missing_field_when_validated_then_rejects(self, field):
        capture = {"id": "x", "file": "a.json", "output": "a.png"}
        del capture[field]

        with pytest.raises(PlanError, match=f"non-empty '{field}'"):
            validate_plan(_plan(captures=[capture]))

    def test_given_empty_captures_when_validated_then_rejects(self):
        with pytest.raises(PlanError, match="non-empty 'captures'"):
            validate_plan({"captures": []})

    @pytest.mark.parametrize("value", ["1920", "axb", "0x1080", 1920])
    def test_given_bad_resolution_when_validated_then_rejects(self, value):
        with pytest.raises(PlanError, match="resolution"):
            validate_plan(_plan(resolution=value))

    @pytest.mark.parametrize("value", [4, "26", True, 12.5])
    def test_given_bad_font_size_when_validated_then_rejects(self, value):
        with pytest.raises(PlanError, match="font_size"):
            validate_plan(_plan(font_size=value))

    @pytest.mark.parametrize(
        "output",
        [
            "../outside.png",
            "frames/../../outside.png",
            "/tmp/outside.png",
            "C:/outside.png",
            "frames\\a.png",
            "frames//a.png",
            "./a.png",
            "frames/a.jpg",
        ],
    )
    def test_given_unsafe_output_when_validated_then_rejects(self, output):
        capture = {"id": "x", "file": "a.json", "output": output}

        with pytest.raises(PlanError, match="relative .png path"):
            validate_plan(_plan(captures=[capture]))

    @pytest.mark.parametrize("capture_id", ["../x", "a/b", "a\\b", ".hidden", "-x"])
    def test_given_unsafe_id_when_validated_then_rejects(self, capture_id):
        capture = {"id": capture_id, "file": "a.json", "output": "a.png"}

        with pytest.raises(PlanError, match="'id' must be"):
            validate_plan(_plan(captures=[capture]))


class TestContainedPath:
    def test_given_nested_path_when_resolved_then_stays_under_root(self, tmp_path):
        path = contained_path(tmp_path, "content/slide-005/images/a.png")

        assert path == tmp_path.resolve() / "content" / "slide-005" / "images" / "a.png"

    def test_given_traversal_when_resolved_then_rejects(self, tmp_path):
        with pytest.raises(PlanError, match="outside"):
            contained_path(tmp_path / "root", "../outside.png")

    def test_given_symlinked_parent_when_resolved_then_rejects(self, tmp_path):
        root = tmp_path / "root"
        (root).mkdir()
        (tmp_path / "elsewhere").mkdir()
        (root / "frames").symlink_to(tmp_path / "elsewhere")

        with pytest.raises(PlanError, match="symlink"):
            contained_path(root, "frames/a.png")


class TestCaptureSettings:
    def test_given_theme_when_built_then_disables_trust_and_chrome(self):
        settings = capture_settings("Default Dark Modern", 26)

        assert settings["workbench.colorTheme"] == "Default Dark Modern"
        assert settings["window.autoDetectColorScheme"] is False
        assert settings["security.workspace.trust.enabled"] is False
        assert settings["workbench.activityBar.location"] == "hidden"
        assert settings["editor.fontSize"] == 26

    def test_given_default_font_size_when_measured_then_clears_floor(self):
        # Zoom stays at 1.0 by default, so the font size alone must clear 18 pt.
        font_pt = rendered_font_pt(
            DEFAULT_FONT_SIZE_PX,
            DEFAULT_FONT_SIZE_PX,
            DEFAULT_START_ZOOM,
        )

        assert font_pt >= DEFAULT_MIN_FONT_PT


class TestRenderedFontPt:
    def test_given_unfolded_zoom_when_measured_then_applies_zoom_once(self):
        # Observed on VS Code Insiders: 12 px base, 2.25x zoom, reading unchanged.
        assert rendered_font_pt(12.0, 12.0, 2.25) == 20.25

    def test_given_folded_zoom_when_measured_then_does_not_double_count(self):
        assert rendered_font_pt(12.0, 27.0, 2.25) == 20.25


class TestMain:
    def test_given_invalid_plan_when_run_then_exits_nonzero_with_json(
        self, tmp_path, capsys
    ):
        plan_path = tmp_path / "plan.yml"
        plan_path.write_text("captures: []\n", encoding="utf-8")

        exit_code = main(["--plan", str(plan_path), "--workspace", str(tmp_path)])

        assert exit_code == EXIT_FAILURE
        assert '"ok": false' in capsys.readouterr().out.strip().splitlines()[-1]
