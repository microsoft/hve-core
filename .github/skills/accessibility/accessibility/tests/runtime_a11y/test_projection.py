# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

"""Tests for the design-intent Markdown projection."""

from __future__ import annotations

from pathlib import Path

import pytest
import runtime_a11y.__main__ as cli
from runtime_a11y import _projection as projection
from runtime_a11y._errors import EXIT_SUCCESS, EXIT_USAGE, ScriptError

_FULL_RECORD = """
schemaVersion: "1.1"
surfaceId: checkout-panel
title: Checkout summary panel
owner: Design Systems Guild
status: accepted
decidedOn: "2026-07-14"
decidedBy:
  - A. Designer
  - B. Engineer
version: 2
groundedIn:
  - id: wcag-22
    title: Web Content Accessibility Guidelines 2.2
    url: https://www.w3.org/TR/WCAG22/
    use: Criterion identifiers referenced by expectations.
    reproduction: paraphrase-only
intents:
  - id: INT-001
    conveys: Every control is reachable without a pointing device.
    rationale: Keyboard-only shoppers abandoned at the summary step.
    audience:
      - Keyboard-only shoppers
      - Screen reader users
    evidence: observed
    binding:
      state: default
    expectations:
      - id: EXP-001
        method: runtime-automation
        assert: probe-keyboard-traversal
        detail: Tab order reaches every control.
        criteria:
          - wcag-22:2.1.1
          - wcag-22:2.1.2
        role: decides
        blocking: true
      - id: EXP-002
        method: cognitive-walkthrough
        assert: custom
        detail: A reviewer confirms reading order matches visual grouping.
        criteria:
          - wcag-22:1.3.2
        role: informs
        blocking: false
"""

_MINIMAL_RECORD = """
schemaVersion: "1.1"
surfaceId: bare
title: Bare surface
owner: Team
status: proposed
decidedOn: "2026-01-01"
decidedBy:
  - A. Person
version: 1
intents:
  - id: INT-001
    conveys: The surface has a documented intent.
    rationale: "Projection requires one valid authored intent."
    audience: [Users]
    evidence: assumed
    binding: {state: default}
    expectations:
      - id: EXP-001
        method: cognitive-walkthrough
        assert: custom
        detail: A reviewer confirms the intent.
        criteria: [wcag-22:1.3.1]
        role: informs
        blocking: false
"""


def _write(tmp_path: Path, body: str, stem: str) -> Path:
    path = tmp_path / f"{stem}.intent.yaml"
    path.write_text(body, encoding="utf-8")
    return path


class TestRenderMetadata:
    def test_given_record_when_rendered_then_carries_generated_marker(self) -> None:
        markdown = projection.render({"surfaceId": "s", "title": "T"})
        assert markdown.startswith(projection.GENERATED_MARKER)
        assert "regenerate instead" in markdown

    def test_given_record_when_rendered_then_includes_metadata_fields(
        self, tmp_path: Path
    ) -> None:
        record_path = _write(tmp_path, _FULL_RECORD, "checkout-panel")
        markdown, _ = projection.project(record_path)
        assert "# Design intent: Checkout summary panel" in markdown
        assert "| Owner | Design Systems Guild |" in markdown
        assert "| Decided by | A. Designer, B. Engineer |" in markdown
        assert "| Revision | 2 |" in markdown

    def test_given_record_without_title_when_rendered_then_falls_back_to_surface(
        self,
    ) -> None:
        markdown = projection.render({"surfaceId": "only-surface"})
        assert "# Design intent: only-surface" in markdown

    def test_given_empty_record_when_rendered_then_uses_default_heading(self) -> None:
        markdown = projection.render({})
        assert "# Design intent: Design intent" in markdown


class TestRenderIntents:
    def test_given_intent_when_rendered_then_shows_claim_and_rationale(
        self, tmp_path: Path
    ) -> None:
        record_path = _write(tmp_path, _FULL_RECORD, "checkout-panel")
        markdown, _ = projection.project(record_path)
        assert (
            "## INT-001: Every control is reachable without a pointing device."
            in markdown
        )
        assert "Keyboard-only shoppers abandoned at the summary step." in markdown

    def test_given_intent_when_rendered_then_lists_audience(
        self, tmp_path: Path
    ) -> None:
        record_path = _write(tmp_path, _FULL_RECORD, "checkout-panel")
        markdown, _ = projection.project(record_path)
        assert "* Keyboard-only shoppers" in markdown
        assert "* Screen reader users" in markdown

    def test_given_evidence_grade_when_rendered_then_explained_in_words(
        self, tmp_path: Path
    ) -> None:
        record_path = _write(tmp_path, _FULL_RECORD, "checkout-panel")
        markdown, _ = projection.project(record_path)
        assert "Basis: observed directly. Applies to the `default` state." in markdown

    def test_given_unknown_evidence_grade_when_rendered_then_passes_through(
        self,
    ) -> None:
        markdown = projection.render(
            {
                "surfaceId": "s",
                "intents": [{"id": "INT-001", "conveys": "c", "evidence": "novel"}],
            }
        )
        assert "Basis: novel." in markdown

    def test_given_missing_evidence_grade_when_rendered_then_unspecified(self) -> None:
        markdown = projection.render(
            {"surfaceId": "s", "intents": [{"id": "INT-001", "conveys": "c"}]}
        )
        assert "Basis: unspecified." in markdown

    def test_given_record_without_intents_when_rendered_then_says_so(self) -> None:
        markdown = projection.render({"surfaceId": "s", "intents": []})
        assert "This record declares no intents." in markdown

    def test_given_malformed_intents_when_rendered_then_raises(self) -> None:
        with pytest.raises(ScriptError, match="intents"):
            projection.render({"surfaceId": "s", "intents": ["bad"]})

    def test_given_intent_without_expectations_when_rendered_then_says_so(self) -> None:
        markdown = projection.render(
            {"surfaceId": "s", "intents": [{"id": "INT-001", "conveys": "c"}]}
        )
        assert "No expectations are declared for this intent." in markdown

    def test_given_malformed_expectations_when_rendered_then_raises(self) -> None:
        with pytest.raises(ScriptError, match="expectations"):
            projection.render(
                {
                    "surfaceId": "s",
                    "intents": [
                        {"id": "INT-001", "conveys": "c", "expectations": ["bad"]}
                    ],
                }
            )


class TestRenderExpectations:
    def test_given_expectations_when_rendered_then_table_shows_checks(
        self, tmp_path: Path
    ) -> None:
        record_path = _write(tmp_path, _FULL_RECORD, "checkout-panel")
        markdown, _ = projection.project(record_path)
        assert "| Expectation | Checked by | Criteria | Role | Blocks |" in markdown
        assert "`probe-keyboard-traversal`" in markdown
        assert "`wcag-22:2.1.1`, `wcag-22:2.1.2`" in markdown

    def test_given_blocking_flag_when_rendered_then_shown_as_yes_or_no(
        self, tmp_path: Path
    ) -> None:
        record_path = _write(tmp_path, _FULL_RECORD, "checkout-panel")
        markdown, _ = projection.project(record_path)
        assert "| EXP-001 | `probe-keyboard-traversal` |" in markdown
        assert "| decides | yes |" in markdown
        assert "| informs | no |" in markdown

    def test_given_expectation_without_criteria_when_rendered_then_shows_none(
        self,
    ) -> None:
        markdown = projection.render(
            {
                "surfaceId": "s",
                "intents": [
                    {
                        "id": "INT-001",
                        "conveys": "c",
                        "expectations": [{"id": "EXP-001", "assert": "custom"}],
                    }
                ],
            }
        )
        assert "| none |" in markdown

    def test_given_pipe_in_content_when_rendered_then_escaped(self) -> None:
        markdown = projection.render(
            {
                "surfaceId": "s",
                "intents": [
                    {
                        "id": "INT-001",
                        "conveys": "c",
                        "expectations": [
                            {"id": "EXP-|-001", "assert": "custom", "role": "informs"}
                        ],
                    }
                ],
            }
        )
        assert r"EXP-\|-001" in markdown

    def test_given_newline_in_content_when_rendered_then_flattened(self) -> None:
        markdown = projection.render({"surfaceId": "s", "owner": "line1\nline2"})
        assert "| Owner | line1 line2 |" in markdown


class TestGroundedIn:
    def test_given_grounded_sources_when_rendered_then_linked(
        self, tmp_path: Path
    ) -> None:
        record_path = _write(tmp_path, _FULL_RECORD, "checkout-panel")
        markdown, _ = projection.project(record_path)
        assert "## Grounded in" in markdown
        assert (
            "* [Web Content Accessibility Guidelines 2.2](https://www.w3.org/TR/WCAG22/)"
            in markdown
        )

    def test_given_source_without_url_when_rendered_then_plain_entry(self) -> None:
        markdown = projection.render(
            {"surfaceId": "s", "groundedIn": [{"id": "x", "title": "No link"}]}
        )
        assert "* No link" in markdown

    def test_given_record_without_sources_when_rendered_then_section_omitted(
        self, tmp_path: Path
    ) -> None:
        record_path = _write(tmp_path, _MINIMAL_RECORD, "bare")
        markdown, _ = projection.project(record_path)
        assert "## Grounded in" not in markdown


class TestDeterminism:
    def test_given_unchanged_record_when_rendered_twice_then_byte_identical(
        self, tmp_path: Path
    ) -> None:
        record_path = _write(tmp_path, _FULL_RECORD, "checkout-panel")
        first, _ = projection.project(record_path)
        second, _ = projection.project(record_path)
        assert first == second

    def test_given_written_projection_when_regenerated_then_no_diff(
        self, tmp_path: Path
    ) -> None:
        record_path = _write(tmp_path, _FULL_RECORD, "checkout-panel")
        out = tmp_path / "projection.md"
        projection.project(record_path, out)
        first = out.read_bytes()
        projection.project(record_path, out)
        assert out.read_bytes() == first

    def test_given_rendered_output_when_inspected_then_ends_with_single_newline(
        self, tmp_path: Path
    ) -> None:
        record_path = _write(tmp_path, _FULL_RECORD, "checkout-panel")
        markdown, _ = projection.project(record_path)
        assert markdown.endswith("\n")
        assert not markdown.endswith("\n\n")


class TestFailurePaths:
    def test_given_missing_record_when_project_then_usage_error(
        self, tmp_path: Path
    ) -> None:
        with pytest.raises(ScriptError) as excinfo:
            projection.project(tmp_path / "absent.intent.yaml")
        assert excinfo.value.exit_code == EXIT_USAGE

    def test_given_record_without_surface_id_when_project_then_raises(
        self, tmp_path: Path
    ) -> None:
        record_path = _write(tmp_path, "title: no surface\n", "x")
        with pytest.raises(ScriptError):
            projection.project(record_path)


class TestCli:
    def test_given_out_path_when_project_intent_then_writes_file(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        record_path = _write(tmp_path, _FULL_RECORD, "checkout-panel")
        out = tmp_path / "nested" / "projection.md"
        code = cli.main(
            [
                "project-intent",
                "--record",
                str(record_path),
                "--out",
                str(out),
            ]
        )
        assert code == EXIT_SUCCESS
        assert out.exists()
        assert "Wrote" in capsys.readouterr().out

    def test_given_no_out_path_when_project_intent_then_prints_markdown(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        record_path = _write(tmp_path, _FULL_RECORD, "checkout-panel")
        code = cli.main(["project-intent", "--record", str(record_path)])
        assert code == EXIT_SUCCESS
        assert "# Design intent: Checkout summary panel" in capsys.readouterr().out

    def test_given_missing_record_when_project_intent_then_usage_exit(
        self, tmp_path: Path
    ) -> None:
        code = cli.main(
            ["project-intent", "--record", str(tmp_path / "absent.intent.yaml")]
        )
        assert code == EXIT_USAGE
