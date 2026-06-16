# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

"""Tests for the ADR frontmatter and body validator.

Covers MADR v4 schema rules from ``adr-standards.instructions.md`` plus the
extensions defined in the v2 ADR Creator plan: ``proposed_date``/``accepted_date``,
``affected_components``, ``effort``, ``success_criteria``, single-parent
supersession, and required body sections.
"""

from __future__ import annotations

from pathlib import Path

import pytest

validate_frontmatter = pytest.importorskip("scripts.validate_frontmatter")


_VALID_FRONTMATTER = """\
---
id: '0001'
title: Pick the primary database
status: proposed
proposed_date: 2026-05-03
deciders:
  - alice
affected_components:
  - adr-author
effort: M
consulted: []
informed: []
supersedes: null
superseded-by: null
asr_triggers:
  - kind: performance
    evidence: docs/perf/baseline.md
    note: p99 latency under 300ms required for checkout flow
success_criteria:
  - metric: p99_latency_ms
    target: '<300'
    measurement_window: 7d
    source: prometheus
---
"""

_VALID_BODY = """\
## Context

Choosing the primary database for the checkout service.

> Source: docs/perf/baseline.md — p99 latency budget is 300ms.
> Source: docs/scale/forecast.md — 10x growth expected within 18 months.
> Source: docs/ops/runbooks.md — operations team supports PostgreSQL.

## Decision Outcome

Chosen option: "PostgreSQL".

| Driver | PostgreSQL | DynamoDB |
|--------|------------|----------|
| Latency | Good | Good |
| Ops familiarity | Strong | Weak |

## Risks and Mitigations

* Risk: schema migrations under load. Mitigation: blue/green deploy.

## Rollback / Exit Strategy

Restore prior service from snapshot; revert config flag.

## Affected Components

* adr-author
"""


def _write_adr(tmp_path: Path, content: str) -> Path:
    path = tmp_path / "0001-pick-database.md"
    path.write_text(content, encoding="utf-8")
    return path


def _invoke(args: list[str], capsys: pytest.CaptureFixture[str]) -> tuple[int, str, str]:
    try:
        rc = validate_frontmatter.main(args)
    except SystemExit as exc:
        rc = int(exc.code) if exc.code is not None else 0
    captured = capsys.readouterr()
    return rc, captured.out + captured.err, captured.err


class TestValidateFrontmatterHappyPath:
    def test_given_valid_madr_v4_when_validate_then_exits_zero(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        adr = _write_adr(tmp_path, _VALID_FRONTMATTER + "\n" + _VALID_BODY)
        rc, _out, _err = _invoke([str(adr), "--allow-root", str(tmp_path)], capsys)
        assert rc == 0

    def test_given_withdrawn_status_without_accepted_date_when_validate_then_exits_zero(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        fm = _VALID_FRONTMATTER.replace("status: proposed", "status: withdrawn")
        adr = _write_adr(tmp_path, fm + "\n" + _VALID_BODY)
        rc, _out, _err = _invoke([str(adr), "--allow-root", str(tmp_path)], capsys)
        assert rc == 0

    def test_given_accepted_status_with_accepted_date_when_validate_then_exits_zero(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        fm = _VALID_FRONTMATTER.replace(
            "status: proposed",
            "status: accepted\naccepted_date: 2026-05-10",
        )
        adr = _write_adr(tmp_path, fm + "\n" + _VALID_BODY)
        rc, _out, _err = _invoke([str(adr), "--allow-root", str(tmp_path)], capsys)
        assert rc == 0


class TestRequiredFields:
    @pytest.mark.parametrize(
        "field",
        ["id", "title", "status", "proposed_date", "deciders", "affected_components"],
    )
    def test_given_missing_required_field_when_validate_then_reports_error(
        self,
        tmp_path: Path,
        capsys: pytest.CaptureFixture[str],
        field: str,
    ) -> None:
        lines = _VALID_FRONTMATTER.splitlines(keepends=True)
        filtered: list[str] = []
        skip_block = False
        for line in lines:
            if skip_block:
                if line.startswith(("  ", "\t", "- ")) or line.strip() == "":
                    if line.startswith(("  ", "\t", "- ")):
                        continue
                skip_block = False
            if line.startswith(f"{field}:"):
                if line.rstrip().endswith(":"):
                    skip_block = True
                continue
            filtered.append(line)
        adr = _write_adr(tmp_path, "".join(filtered) + "\n" + _VALID_BODY)
        rc, out, _err = _invoke([str(adr), "--allow-root", str(tmp_path)], capsys)
        assert rc == 1
        assert f"{field}:" in out


class TestIdFormat:
    def test_given_non_four_digit_id_when_validate_then_reports_error(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        fm = _VALID_FRONTMATTER.replace("id: '0001'", "id: '1'")
        adr = _write_adr(tmp_path, fm + "\n" + _VALID_BODY)
        rc, out, _err = _invoke([str(adr), "--allow-root", str(tmp_path)], capsys)
        assert rc == 1
        assert "id:" in out

    def test_given_id_as_list_when_validate_then_reports_error(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        fm = _VALID_FRONTMATTER.replace("id: '0001'", "id:\n  - '0001'")
        adr = _write_adr(tmp_path, fm + "\n" + _VALID_BODY)
        rc, out, _err = _invoke([str(adr), "--allow-root", str(tmp_path)], capsys)
        assert rc == 1
        assert "id:" in out


class TestStatusEnum:
    def test_given_invalid_status_when_validate_then_reports_error(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        fm = _VALID_FRONTMATTER.replace("status: proposed", "status: bogus")
        adr = _write_adr(tmp_path, fm + "\n" + _VALID_BODY)
        rc, out, _err = _invoke([str(adr), "--allow-root", str(tmp_path)], capsys)
        assert rc == 1
        assert "status:" in out


class TestAcceptedDate:
    def test_given_accepted_without_accepted_date_when_validate_then_reports_error(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        fm = _VALID_FRONTMATTER.replace("status: proposed", "status: accepted")
        adr = _write_adr(tmp_path, fm + "\n" + _VALID_BODY)
        rc, out, _err = _invoke([str(adr), "--allow-root", str(tmp_path)], capsys)
        assert rc == 1
        assert "accepted_date: required when status is 'accepted'" in out

    def test_given_accepted_date_bad_iso_when_validate_then_reports_error(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        fm = _VALID_FRONTMATTER.replace(
            "status: proposed",
            "status: accepted\naccepted_date: 5/10/2026",
        )
        adr = _write_adr(tmp_path, fm + "\n" + _VALID_BODY)
        rc, out, _err = _invoke([str(adr), "--allow-root", str(tmp_path)], capsys)
        assert rc == 1
        assert "must be ISO 8601" in out


class TestEffort:
    def test_given_invalid_effort_when_validate_then_reports_error(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        fm = _VALID_FRONTMATTER.replace("effort: M", "effort: X")
        adr = _write_adr(tmp_path, fm + "\n" + _VALID_BODY)
        rc, out, _err = _invoke([str(adr), "--allow-root", str(tmp_path)], capsys)
        assert rc == 1
        assert "effort:" in out
        assert "'X'" in out


class TestAffectedComponents:
    def test_given_empty_list_when_validate_then_reports_error(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        fm = _VALID_FRONTMATTER.replace(
            "affected_components:\n  - adr-author\n",
            "affected_components: []\n",
        )
        adr = _write_adr(tmp_path, fm + "\n" + _VALID_BODY)
        rc, out, _err = _invoke([str(adr), "--allow-root", str(tmp_path)], capsys)
        assert rc == 1
        assert "affected_components:" in out

    def test_given_non_string_item_when_validate_then_reports_error(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        fm = _VALID_FRONTMATTER.replace(
            "affected_components:\n  - adr-author\n",
            "affected_components:\n  - 42\n",
        )
        adr = _write_adr(tmp_path, fm + "\n" + _VALID_BODY)
        rc, out, _err = _invoke([str(adr), "--allow-root", str(tmp_path)], capsys)
        assert rc == 1
        assert "affected_components[" in out


class TestSuccessCriteria:
    def test_given_missing_required_subfield_when_validate_then_reports_error(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        fm = _VALID_FRONTMATTER.replace(
            "    source: prometheus\n",
            "",
        )
        adr = _write_adr(tmp_path, fm + "\n" + _VALID_BODY)
        rc, out, _err = _invoke([str(adr), "--allow-root", str(tmp_path)], capsys)
        assert rc == 1
        assert "success_criteria" in out
        assert "source" in out

    def test_given_empty_when_asr_triggers_present_then_reports_error(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        fm = _VALID_FRONTMATTER.replace(
            "success_criteria:\n  - metric: p99_latency_ms\n    target: '<300'\n"
            "    measurement_window: 7d\n    source: prometheus\n",
            "success_criteria: []\n",
        )
        adr = _write_adr(tmp_path, fm + "\n" + _VALID_BODY)
        rc, out, _err = _invoke([str(adr), "--allow-root", str(tmp_path)], capsys)
        assert rc == 1
        assert "success_criteria" in out


class TestAsrTriggers:
    def test_given_invalid_kind_when_validate_then_reports_error(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        fm = _VALID_FRONTMATTER.replace("kind: performance", "kind: vibes")
        adr = _write_adr(tmp_path, fm + "\n" + _VALID_BODY)
        rc, out, _err = _invoke([str(adr), "--allow-root", str(tmp_path)], capsys)
        assert rc == 1
        assert "asr_triggers" in out

    def test_given_note_exceeds_280_chars_when_validate_then_reports_error(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        long_note = "x" * 281
        fm = _VALID_FRONTMATTER.replace(
            "note: p99 latency under 300ms required for checkout flow",
            f"note: {long_note}",
        )
        adr = _write_adr(tmp_path, fm + "\n" + _VALID_BODY)
        rc, out, _err = _invoke([str(adr), "--allow-root", str(tmp_path)], capsys)
        assert rc == 1
        assert "asr_triggers" in out
        assert "note" in out


class TestSupersession:
    def test_given_supersedes_as_list_when_validate_then_reports_error(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        fm = _VALID_FRONTMATTER.replace(
            "supersedes: null\n",
            "supersedes:\n  - '0002'\n  - '0003'\n",
        )
        adr = _write_adr(tmp_path, fm + "\n" + _VALID_BODY)
        rc, out, _err = _invoke([str(adr), "--allow-root", str(tmp_path)], capsys)
        assert rc == 1
        assert "single NNNN string (GP-06 single-parent)" in out


class TestBody:
    def test_given_missing_context_section_when_validate_then_reports_error(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        body = _VALID_BODY.replace("## Context\n", "## Background\n")
        adr = _write_adr(tmp_path, _VALID_FRONTMATTER + "\n" + body)
        rc, out, _err = _invoke([str(adr), "--allow-root", str(tmp_path)], capsys)
        assert rc == 1
        assert "body: required section missing: '## Context'" in out

    def test_given_fewer_than_three_citations_when_validate_then_reports_error(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        body = _VALID_BODY.replace(
            "> Source: docs/scale/forecast.md — 10x growth expected within 18 months.\n"
            "> Source: docs/ops/runbooks.md — operations team supports PostgreSQL.\n",
            "",
        )
        adr = _write_adr(tmp_path, _VALID_FRONTMATTER + "\n" + body)
        rc, out, _err = _invoke([str(adr), "--allow-root", str(tmp_path)], capsys)
        assert rc == 1
        assert "blockquote citation lines" in out

    @pytest.mark.parametrize(
        "header",
        ["## Risks and Mitigations", "## Rollback / Exit Strategy", "## Affected Components"],
    )
    def test_given_missing_required_body_header_when_validate_then_reports_error(
        self,
        tmp_path: Path,
        capsys: pytest.CaptureFixture[str],
        header: str,
    ) -> None:
        body = _VALID_BODY.replace(header + "\n", "## Removed\n")
        adr = _write_adr(tmp_path, _VALID_FRONTMATTER + "\n" + body)
        rc, out, _err = _invoke([str(adr), "--allow-root", str(tmp_path)], capsys)
        assert rc == 1
        assert f"body: required section missing: '{header}'" in out

    def test_given_no_decision_outcome_section_when_validate_then_exits_zero(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        body = _VALID_BODY.replace(
            "## Decision Outcome\n\n"
            'Chosen option: "PostgreSQL".\n\n'
            "| Driver | PostgreSQL | DynamoDB |\n"
            "|--------|------------|----------|\n"
            "| Latency | Good | Good |\n"
            "| Ops familiarity | Strong | Weak |\n\n",
            "",
        )
        adr = _write_adr(tmp_path, _VALID_FRONTMATTER + "\n" + body)
        rc, _out, _err = _invoke([str(adr), "--allow-root", str(tmp_path)], capsys)
        assert rc == 0

    def test_given_decision_section_without_table_when_validate_then_reports_error(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        body = _VALID_BODY.replace(
            "| Driver | PostgreSQL | DynamoDB |\n"
            "|--------|------------|----------|\n"
            "| Latency | Good | Good |\n"
            "| Ops familiarity | Strong | Weak |\n",
            "",
        )
        adr = _write_adr(tmp_path, _VALID_FRONTMATTER + "\n" + body)
        rc, out, _err = _invoke([str(adr), "--allow-root", str(tmp_path)], capsys)
        assert rc == 1
        assert "driver-by-option comparison table" in out

    def test_given_considered_options_before_decision_outcome_when_validate_then_no_table_error(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        body = _VALID_BODY.replace(
            "## Decision Outcome\n",
            "## Considered Options\n\n- PostgreSQL\n- DynamoDB\n\n## Decision Outcome\n",
        )
        adr = _write_adr(tmp_path, _VALID_FRONTMATTER + "\n" + body)
        rc, out, _err = _invoke([str(adr), "--allow-root", str(tmp_path)], capsys)
        assert rc == 0
        assert "driver-by-option comparison table" not in out


class TestSchemaMissing:
    def test_given_missing_schema_when_validate_then_warns_and_continues(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        adr = _write_adr(tmp_path, _VALID_FRONTMATTER + "\n" + _VALID_BODY)
        rc, _out, err = _invoke(
            [
                str(adr),
                "--allow-root",
                str(tmp_path),
                "--schema",
                str(tmp_path / "nonexistent.schema.json"),
            ],
            capsys,
        )
        assert rc == 0
        assert "validate_frontmatter: schema not found" in err
