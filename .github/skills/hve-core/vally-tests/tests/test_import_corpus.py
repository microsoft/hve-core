# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Pytest coverage for import_corpus.py."""

from __future__ import annotations

import csv
import json
from datetime import datetime, timezone
from pathlib import Path

import import_corpus
import pytest
import yaml

CANONICAL_HEADER = list(import_corpus.REQUIRED_COLUMNS)


def _write_csv(path: Path, rows: list[dict[str, str]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=CANONICAL_HEADER)
        writer.writeheader()
        for row in rows:
            writer.writerow({key: row.get(key, "") for key in CANONICAL_HEADER})


def _sample_row(**overrides: str) -> dict[str, str]:
    base = {
        "prompt": "Summarize the Vally test author skill in one sentence.",
        "kind": "agent",
        "target_artifact": ".github/agents/hve-core/vally-test-author.agent.md",
        "grader": "ContainsAll",
        "tags": "smoke,agent",
        "expected_refusal_category": "",
        "notes": "baseline",
    }
    base.update(overrides)
    return base


class TestNormalization:
    def test_normalize_collapses_whitespace_and_lowercases(self) -> None:
        assert (
            import_corpus.normalize_prompt("  Hello   WORLD\nFoo\tBar  ")
            == "hello world foo bar"
        )

    def test_normalize_handles_none(self) -> None:
        assert import_corpus.normalize_prompt(None) == ""  # type: ignore[arg-type]

    def test_normalize_is_nfc_stable(self) -> None:
        composed = "caf\u00e9"
        decomposed = "cafe\u0301"
        composed_normal = import_corpus.normalize_prompt(composed)
        decomposed_normal = import_corpus.normalize_prompt(decomposed)
        assert composed_normal == decomposed_normal

    def test_hash_is_deterministic(self) -> None:
        first = import_corpus.hash_prompt("hello world")
        second = import_corpus.hash_prompt("hello world")
        assert first == second
        assert len(first) == 64


class TestRowValidation:
    def test_rejects_empty_prompt(self) -> None:
        result = import_corpus.validate_row(_sample_row(prompt=""), 2)
        assert result is not None and "empty prompt" in result

    def test_rejects_unknown_kind(self) -> None:
        result = import_corpus.validate_row(_sample_row(kind="container"), 3)
        assert result is not None and "container" in result

    def test_accepts_canonical_row(self) -> None:
        assert import_corpus.validate_row(_sample_row(), 4) is None


class TestCsvReading:
    def test_round_trips_canonical_row(self, tmp_path: Path) -> None:
        source = tmp_path / "in.csv"
        _write_csv(source, [_sample_row()])
        rows = list(import_corpus.read_csv_rows(source))
        assert len(rows) == 1
        assert rows[0]["kind"] == "agent"
        assert rows[0]["tags"] == "smoke,agent"

    def test_missing_columns_raises(self, tmp_path: Path) -> None:
        source = tmp_path / "bad.csv"
        with source.open("w", encoding="utf-8", newline="") as handle:
            handle.write("prompt,kind\nhello,agent\n")
        with pytest.raises(import_corpus.CorpusImportError):
            list(import_corpus.read_csv_rows(source))

    def test_unknown_suffix_raises(self, tmp_path: Path) -> None:
        source = tmp_path / "data.tsv"
        source.write_text("prompt\thello\n", encoding="utf-8")
        with pytest.raises(import_corpus.CorpusImportError):
            list(import_corpus.read_rows(source))


class TestDedupe:
    def test_loads_existing_hashes_from_target(self, tmp_path: Path) -> None:
        digest_a = "0" * 64
        digest_b = "f" * 64
        target = tmp_path / "stimuli.yml"
        target.write_text(
            f"# sha256:{digest_a}\n# sha256:{digest_b}\n",
            encoding="utf-8",
        )
        loaded = import_corpus.load_existing_hashes(target)
        assert loaded == {digest_a, digest_b}

    def test_missing_target_yields_empty_set(self, tmp_path: Path) -> None:
        assert import_corpus.load_existing_hashes(tmp_path / "absent.yml") == set()
        assert import_corpus.load_existing_hashes(None) == set()


class TestPatchEntry:
    def test_advisory_tag_is_forced(self) -> None:
        row = _sample_row(tags="")
        normal = import_corpus.normalize_prompt(row["prompt"])
        digest = import_corpus.hash_prompt(normal)
        block = import_corpus.build_patch_entry(row, digest)
        assert "advisory: true" in block
        assert f"# sha256:{digest}" in block
        assert "# kind:agent" in block

    def test_multiline_prompt_is_indented(self) -> None:
        row = _sample_row(prompt="line one\nline two\nline three")
        digest = "a" * 64
        block = import_corpus.build_patch_entry(row, digest)
        assert "    line one\n" in block
        assert "    line two\n" in block
        assert "    line three\n" in block

    def test_yaml_significant_chars_round_trip(self) -> None:
        row = _sample_row(
            prompt="prompt: with #hash and - dash\nsecond line",
            grader="Equals: foo # not a comment",
            tags="- injected: true\nmalicious",
            expected_refusal_category='"quoted": value',
            notes="line one\nline two: trailing",
        )
        digest = "b" * 64
        block = import_corpus.build_patch_entry(row, digest)
        parsed = yaml.safe_load(block)
        assert isinstance(parsed, list) and len(parsed) == 1
        entry = parsed[0]
        # The prompt uses a literal block scalar, which clips a trailing newline.
        assert entry["prompt"].rstrip("\n") == row["prompt"]
        assert entry["grader"] == row["grader"]
        assert entry["tags"]["raw"] == row["tags"]
        assert entry["tags"]["advisory"] is True
        assert entry["expected_refusal_category"] == row["expected_refusal_category"]
        assert entry["notes"] == row["notes"]

    def test_comment_lines_stay_single_line(self) -> None:
        row = _sample_row(
            kind="agent",
            target_artifact=".github/agents/x.md\n- injected: true",
        )
        digest = "c" * 64
        block = import_corpus.build_patch_entry(row, digest)
        comment_lines = [line for line in block.splitlines() if line.startswith("#")]
        assert all("\n" not in line for line in comment_lines)
        # The injected mapping must not survive as a parsed document key.
        parsed = yaml.safe_load(block)
        assert isinstance(parsed, list) and len(parsed) == 1


class TestImportCorpus:
    def test_end_to_end_with_skip_safety(self, tmp_path: Path) -> None:
        source = tmp_path / "in.csv"
        rows = [_sample_row(), _sample_row(prompt="distinct second prompt")]
        _write_csv(source, rows)
        report_dir = tmp_path / "out"
        report, report_path, patch_path = import_corpus.import_corpus(
            source,
            target=None,
            report_dir=report_dir,
            lint_script=tmp_path / "lint-missing.ps1",
            skip_safety=True,
            now=datetime(2026, 1, 13, 12, 0, 0, tzinfo=timezone.utc),
        )
        assert report.totals() == {
            "accepted": 2,
            "rejected": 0,
            "flagged": 0,
            "duplicates": 0,
        }
        assert report_path.exists()
        assert patch_path.exists()
        payload = json.loads(report_path.read_text(encoding="utf-8"))
        assert payload["totals"]["accepted"] == 2

    def test_generated_patch_parses_as_yaml(self, tmp_path: Path) -> None:
        source = tmp_path / "in.csv"
        rows = [
            _sample_row(
                grader="Equals: tricky # value",
                tags="smoke,agent",
                notes="multi\nline: note",
            ),
            _sample_row(
                prompt="distinct second prompt: with #hash",
                target_artifact=".github/agents/x.md\n- injected: true",
            ),
        ]
        _write_csv(source, rows)
        report_dir = tmp_path / "out"
        _, _, patch_path = import_corpus.import_corpus(
            source,
            target=None,
            report_dir=report_dir,
            lint_script=tmp_path / "lint-missing.ps1",
            skip_safety=True,
        )
        parsed = yaml.safe_load(patch_path.read_text(encoding="utf-8"))
        assert isinstance(parsed, list)
        assert len(parsed) == 2
        assert all(entry["tags"]["advisory"] is True for entry in parsed)
        assert parsed[0]["grader"] == "Equals: tricky # value"
        assert parsed[0]["notes"] == "multi\nline: note"

    def test_dedupes_against_existing_target(self, tmp_path: Path) -> None:
        row = _sample_row()
        normal = import_corpus.normalize_prompt(row["prompt"])
        digest = import_corpus.hash_prompt(normal)
        target = tmp_path / "stimuli.yml"
        target.write_text(f"# sha256:{digest}\n", encoding="utf-8")
        source = tmp_path / "in.csv"
        _write_csv(source, [row])
        report_dir = tmp_path / "out"
        report, _, _ = import_corpus.import_corpus(
            source,
            target=target,
            report_dir=report_dir,
            lint_script=tmp_path / "lint-missing.ps1",
            skip_safety=True,
        )
        assert report.totals()["duplicates"] == 1
        assert report.totals()["accepted"] == 0

    def test_duplicate_row_runs_safety_before_dedupe(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        # Arrange
        row = _sample_row()
        digest = import_corpus.hash_prompt(
            import_corpus.normalize_prompt(row["prompt"])
        )
        target = tmp_path / "stimuli.yml"
        target.write_text(f"# sha256:{digest}\n", encoding="utf-8")
        source = tmp_path / "in.csv"
        _write_csv(source, [row])
        safety_calls: list[str] = []

        def flagged_safety_check(
            prompt: str, lint_script: Path, *, pwsh: str = "pwsh"
        ) -> dict[str, object]:
            del lint_script, pwsh
            safety_calls.append(prompt)
            return {"exit_code": 1, "output": "flagged", "category": None}

        monkeypatch.setattr(import_corpus, "safety_check", flagged_safety_check)

        # Act
        report, _, _ = import_corpus.import_corpus(
            source,
            target=target,
            report_dir=tmp_path / "out",
            lint_script=tmp_path / "lint.ps1",
        )

        # Assert
        assert safety_calls == [row["prompt"]]
        assert report.totals()["flagged"] == 1
        assert report.totals()["duplicates"] == 0

    def test_rejected_rows_propagate(self, tmp_path: Path) -> None:
        source = tmp_path / "in.csv"
        _write_csv(source, [_sample_row(kind="container")])
        report_dir = tmp_path / "out"
        report, _, _ = import_corpus.import_corpus(
            source,
            target=None,
            report_dir=report_dir,
            lint_script=tmp_path / "lint-missing.ps1",
            skip_safety=True,
        )
        assert report.totals()["rejected"] == 1

    def test_missing_source_raises(self, tmp_path: Path) -> None:
        with pytest.raises(import_corpus.CorpusImportError):
            import_corpus.import_corpus(
                tmp_path / "missing.csv",
                target=None,
                report_dir=tmp_path,
                lint_script=tmp_path / "lint.ps1",
                skip_safety=True,
            )


class TestCli:
    def test_parser_accepts_required_args(self) -> None:
        parser = import_corpus.build_parser()
        args = parser.parse_args(["sample.csv", "--skip-safety"])
        assert args.source == "sample.csv"
        assert args.skip_safety is True

    def test_main_returns_zero_on_clean_import(self, tmp_path: Path) -> None:
        source = tmp_path / "in.csv"
        _write_csv(source, [_sample_row()])
        exit_code = import_corpus.main(
            [
                str(source),
                "--report-dir",
                str(tmp_path / "out"),
                "--skip-safety",
            ]
        )
        assert exit_code == 0

    def test_main_returns_one_when_rejected_present(self, tmp_path: Path) -> None:
        source = tmp_path / "in.csv"
        _write_csv(source, [_sample_row(kind="oops")])
        exit_code = import_corpus.main(
            [
                str(source),
                "--report-dir",
                str(tmp_path / "out"),
                "--skip-safety",
            ]
        )
        assert exit_code == 1
