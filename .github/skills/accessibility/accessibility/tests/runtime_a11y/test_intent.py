# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

"""Tests for the design-intent verification adapter."""

from __future__ import annotations

import json
from collections.abc import Iterator
from pathlib import Path

import pytest
import runtime_a11y.__main__ as cli
from pytest_mock import MockerFixture
from runtime_a11y import _intent as intent
from runtime_a11y._errors import (
    EXIT_INTENT_DRIFT,
    EXIT_INTENT_UNCOVERED,
    EXIT_SUCCESS,
    EXIT_USAGE,
    ScriptError,
)

_REPO_ROOT = Path(__file__).resolve().parents[6]
_FIXTURE_REPO = _REPO_ROOT / "scripts/tests/fixtures/design-intent/valid-repo"
_FIXTURE_RECORD = _FIXTURE_REPO / "design-intent/valid-surface.intent.yaml"
_FIXTURE_RESULTS = _FIXTURE_REPO / "harness-results.json"
_FIXTURE_ARTIFACT = (
    _FIXTURE_REPO / "design-intent/.verification/valid-surface.earl.json"
)
_FIXTURE_DIGEST = (
    "sha256:02e31c5823b0044fe1d5c4ea90b74fe679f2af29cdd8bc51016d9a4abab4de02"
)

# The shared contract fixture lives in the hve-core repository, not in the
# skill. When the skill is packaged into a consuming project those files are
# absent, so tests that assert parity with the reference validator skip rather
# than fail. Adapter behavior itself is covered by the self-contained tests.
_requires_contract_fixture = pytest.mark.skipif(
    not _FIXTURE_RECORD.exists(),
    reason="shared design-intent contract fixture is not present",
)


@pytest.fixture()
def preserve_fixture_artifact() -> Iterator[None]:
    """Restore the committed fixture sidecar after a generation test."""
    before = _FIXTURE_ARTIFACT.read_bytes()
    yield
    _FIXTURE_ARTIFACT.write_bytes(before)


def _write_record(tmp_path: Path, body: str, surface_id: str = "s1") -> Path:
    record_dir = tmp_path / "design-intent"
    record_dir.mkdir(parents=True, exist_ok=True)
    path = record_dir / f"{surface_id}.intent.yaml"
    path.write_text(body, encoding="utf-8")
    return path


def _write_results(tmp_path: Path, rows: list[dict[str, object]]) -> Path:
    path = tmp_path / "results.json"
    path.write_text(json.dumps({"results": rows}), encoding="utf-8")
    return path


_SIMPLE_RECORD = """
schemaVersion: "1.1"
surfaceId: s1
title: Simple surface
owner: Team
status: accepted
decidedOn: "2026-01-01"
decidedBy:
  - A. Person
version: 1
intents:
  - id: INT-001
    conveys: Controls are reachable by keyboard.
    rationale: Keyboard users must reach every control.
    audience:
      - Keyboard users
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
        role: decides
        blocking: true
"""


def _row(**overrides: object) -> dict[str, object]:
    base = {
        "criterionId": "2.1.1",
        "framework": "wcag-22",
        "surfaceId": "s1",
        "state": "default",
        "status": "pass",
        "probeId": "probe-keyboard-traversal",
    }
    base.update(overrides)
    return base


class TestDigest:
    @_requires_contract_fixture
    def test_given_fixture_record_when_digest_then_matches_validator_value(
        self,
    ) -> None:
        raw = intent.read_record_text(_FIXTURE_RECORD)
        assert intent.compute_intent_digest(raw) == _FIXTURE_DIGEST

    def test_given_crlf_content_when_digest_then_equals_lf_digest(self) -> None:
        assert intent.compute_intent_digest("a\r\nb") == intent.compute_intent_digest(
            "a\nb"
        )

    def test_given_mutated_record_when_digest_then_differs(
        self, tmp_path: Path
    ) -> None:
        path = _write_record(tmp_path, _SIMPLE_RECORD)
        before = intent.compute_intent_digest(intent.read_record_text(path))
        path.write_text(_SIMPLE_RECORD + "\n# drift\n", encoding="utf-8")
        after = intent.compute_intent_digest(intent.read_record_text(path))
        assert before != after


class TestCriterionReference:
    def test_given_plain_reference_when_split_then_returns_pair(self) -> None:
        assert intent.split_criterion_reference("wcag-22:2.1.1") == ("wcag-22", "2.1.1")

    def test_given_reference_with_inner_colon_when_split_then_keeps_remainder(
        self,
    ) -> None:
        assert intent.split_criterion_reference(
            "aria-apg:APG:notification-live-region"
        ) == ("aria-apg", "APG:notification-live-region")

    @pytest.mark.parametrize("value", ["nocolon", ":missing", "missing:"])
    def test_given_malformed_reference_when_split_then_raises(self, value: str) -> None:
        with pytest.raises(ScriptError):
            intent.split_criterion_reference(value)


class TestAuthoredContract:
    @pytest.mark.parametrize(
        ("replacement", "message"),
        [
            ('schemaVersion: "2.0"', "authored schema"),
            ('decidedOn: "2026-02-30"', "real calendar date"),
            ("version: 1\nunexpectedField: value", "authored schema"),
        ],
    )
    def test_given_invalid_record_contract_when_parse_then_raises(
        self, tmp_path: Path, replacement: str, message: str
    ) -> None:
        body = _SIMPLE_RECORD
        if replacement.startswith("schemaVersion"):
            body = body.replace('schemaVersion: "1.1"', replacement)
        elif replacement.startswith("decidedOn"):
            body = body.replace('decidedOn: "2026-01-01"', replacement)
        else:
            body = body.replace("version: 1", replacement)
        path = tmp_path / "s1.intent.yaml"

        with pytest.raises(ScriptError, match=message):
            intent.parse_record(body, path)

    def test_given_duplicate_yaml_key_when_parse_then_raises(
        self, tmp_path: Path
    ) -> None:
        body = _SIMPLE_RECORD.replace("owner: Team", "owner: Team\nowner: Other")
        path = tmp_path / "s1.intent.yaml"

        with pytest.raises(ScriptError, match="duplicate key"):
            intent.parse_record(body, path)

    def test_given_empty_intents_when_parse_then_schema_error(
        self, tmp_path: Path
    ) -> None:
        body = _SIMPLE_RECORD[: _SIMPLE_RECORD.index("intents:")] + "intents: []\n"
        path = tmp_path / "s1.intent.yaml"

        with pytest.raises(ScriptError, match="authored schema"):
            intent.parse_record(body, path)

    def test_given_invalid_method_pairing_when_parse_then_raises(
        self, tmp_path: Path
    ) -> None:
        body = _SIMPLE_RECORD.replace(
            "method: runtime-automation", "method: screen-reader"
        )
        path = tmp_path / "s1.intent.yaml"

        with pytest.raises(ScriptError, match="authored schema|requires method"):
            intent.parse_record(body, path)

    def test_given_duplicate_intent_id_when_parse_then_raises(
        self, tmp_path: Path
    ) -> None:
        duplicate = _SIMPLE_RECORD[_SIMPLE_RECORD.index("  - id: INT-001") :]
        body = _SIMPLE_RECORD + duplicate.replace("EXP-001", "EXP-002")
        path = tmp_path / "s1.intent.yaml"

        with pytest.raises(ScriptError, match="Duplicate intent id"):
            intent.parse_record(body, path)

    @pytest.mark.parametrize(
        "override",
        [
            "        override:\n          outcome: passed\n",
            (
                "        override:\n"
                "          outcome: unknown\n"
                "          rationale: Reviewed manually.\n"
                "          reviewedBy: C. Reviewer\n"
                '          reviewedOn: "2026-08-07"\n'
            ),
            (
                "        override:\n"
                "          outcome: passed\n"
                "          rationale: Reviewed manually.\n"
                "          reviewedBy: C. Reviewer\n"
                '          reviewedOn: "2026-02-30"\n'
            ),
        ],
    )
    def test_given_invalid_override_when_parse_then_raises(
        self, tmp_path: Path, override: str
    ) -> None:
        body = _SIMPLE_RECORD.replace(
            "        blocking: true\n", "        blocking: true\n" + override
        )
        path = tmp_path / "s1.intent.yaml"

        with pytest.raises(ScriptError, match="authored schema|real calendar date"):
            intent.parse_record(body, path)


class TestOutcomeMapping:
    @pytest.mark.parametrize(
        ("status", "expected"),
        [("pass", "passed"), ("fail", "failed"), ("candidate", "cantTell")],
    )
    def test_given_status_when_build_then_maps_to_outcome(
        self, tmp_path: Path, status: str, expected: str
    ) -> None:
        record_path = _write_record(tmp_path, _SIMPLE_RECORD)
        results_path = _write_results(tmp_path, [_row(status=status)])
        _, document = intent.generate(record_path, results_path)
        assert document["assertions"][0]["outcome"] == expected

    def test_given_unknown_status_when_build_then_reports_cant_tell(
        self, tmp_path: Path
    ) -> None:
        record_path = _write_record(tmp_path, _SIMPLE_RECORD)
        results_path = _write_results(tmp_path, [_row(status="weird")])
        _, document = intent.generate(record_path, results_path)
        assert document["assertions"][0]["outcome"] == "cantTell"

    def test_given_partial_status_when_build_then_maps_explicitly_to_cant_tell(
        self, tmp_path: Path
    ) -> None:
        record_path = _write_record(tmp_path, _SIMPLE_RECORD)
        results_path = _write_results(tmp_path, [_row(status="partial")])
        _, document = intent.generate(record_path, results_path)
        assert document["assertions"][0]["outcome"] == "cantTell"


class TestJoin:
    @pytest.mark.parametrize(
        "override",
        [
            {"surfaceId": "other"},
            {"state": "error"},
            {"probeId": "probe-axe"},
            {"criterionId": "9.9.9"},
            {"framework": "other-framework"},
        ],
    )
    def test_given_non_matching_row_when_build_then_untested(
        self, tmp_path: Path, override: dict[str, object]
    ) -> None:
        record_path = _write_record(tmp_path, _SIMPLE_RECORD)
        results_path = _write_results(tmp_path, [_row(**override)])
        _, document = intent.generate(record_path, results_path)
        assertion = document["assertions"][0]
        assert assertion["outcome"] == "untested"
        assert assertion["info"]

    def test_given_non_dict_row_when_build_then_ignored(self, tmp_path: Path) -> None:
        record_path = _write_record(tmp_path, _SIMPLE_RECORD)
        results_path = tmp_path / "results.json"
        results_path.write_text(json.dumps({"results": ["junk"]}), encoding="utf-8")
        _, document = intent.generate(record_path, results_path)
        assert document["assertions"][0]["outcome"] == "untested"

    def test_given_non_list_results_when_build_then_all_untested(
        self, tmp_path: Path
    ) -> None:
        record_path = _write_record(tmp_path, _SIMPLE_RECORD)
        results_path = tmp_path / "results.json"
        results_path.write_text(json.dumps({"results": "nope"}), encoding="utf-8")
        _, document = intent.generate(record_path, results_path)
        assert document["assertions"][0]["outcome"] == "untested"


class TestAggregation:
    def test_given_mixed_criteria_when_build_then_worst_outcome_wins(
        self, tmp_path: Path
    ) -> None:
        body = _SIMPLE_RECORD.replace(
            "          - wcag-22:2.1.1",
            "          - wcag-22:2.1.1\n          - wcag-22:2.1.2",
        )
        record_path = _write_record(tmp_path, body)
        results_path = _write_results(
            tmp_path,
            [
                _row(criterionId="2.1.1", status="pass"),
                _row(criterionId="2.1.2", status="fail"),
            ],
        )
        _, document = intent.generate(record_path, results_path)
        assert document["assertions"][0]["outcome"] == "failed"

    def test_given_pass_and_candidate_when_build_then_cant_tell_wins(
        self, tmp_path: Path
    ) -> None:
        body = _SIMPLE_RECORD.replace(
            "          - wcag-22:2.1.1",
            "          - wcag-22:2.1.1\n          - wcag-22:2.1.2",
        )
        record_path = _write_record(tmp_path, body)
        results_path = _write_results(
            tmp_path,
            [
                _row(criterionId="2.1.1", status="pass"),
                _row(criterionId="2.1.2", status="candidate"),
            ],
        )
        _, document = intent.generate(record_path, results_path)
        assertion = document["assertions"][0]
        assert assertion["outcome"] == "cantTell"
        assert assertion["info"]


class TestFixtureRecord:
    @_requires_contract_fixture
    def test_given_fixture_when_generate_then_one_assertion_per_expectation(
        self, preserve_fixture_artifact: None
    ) -> None:
        _, document = intent.generate(_FIXTURE_RECORD, _FIXTURE_RESULTS)
        assert len(document["assertions"]) == 5
        ids = [item["expectationId"] for item in document["assertions"]]
        assert ids == ["EXP-001", "EXP-002", "EXP-003", "EXP-004", "EXP-005"]

    @_requires_contract_fixture
    def test_given_fixture_when_generate_then_outcomes_are_mixed(
        self, preserve_fixture_artifact: None
    ) -> None:
        _, document = intent.generate(_FIXTURE_RECORD, _FIXTURE_RESULTS)
        outcomes = {item["outcome"] for item in document["assertions"]}
        # Every outcome the adapter can produce from a probe run appears here,
        # so a stub emitting one blanket outcome cannot pass.
        assert outcomes == {"passed", "failed", "cantTell", "untested"}

    @_requires_contract_fixture
    def test_given_fixture_when_generate_then_each_expectation_resolves_as_declared(
        self, preserve_fixture_artifact: None
    ) -> None:
        _, document = intent.generate(_FIXTURE_RECORD, _FIXTURE_RESULTS)
        by_id = {item["expectationId"]: item for item in document["assertions"]}
        assert by_id["EXP-001"]["outcome"] == "passed"
        # Worst-wins: a single failing criterion fails the whole expectation.
        assert by_id["EXP-002"]["outcome"] == "failed"
        # Worst-wins again, with one criterion passing and one undecided.
        assert by_id["EXP-003"]["outcome"] == "cantTell"
        assert by_id["EXP-004"]["outcome"] == "untested"
        assert by_id["EXP-005"]["outcome"] == "untested"

        # Every assertion without an override reports the observed outcome as
        # its effective outcome and never claims a conflict, so a branch that
        # forgets the derivation cannot pass on the conclusive cases alone.
        for expectation_id in ("EXP-001", "EXP-002", "EXP-003", "EXP-004"):
            assertion = by_id[expectation_id]
            assert assertion["effectiveOutcome"] == assertion["outcome"]
            assert assertion["overrideConflict"] is False
        # EXP-005 carries a human override settling an untested expectation.
        assert by_id["EXP-005"]["effectiveOutcome"] == "passed"
        assert by_id["EXP-005"]["overrideConflict"] is False

    @_requires_contract_fixture
    def test_given_fixture_when_only_non_blocking_fails_then_no_blocking_failure(
        self,
    ) -> None:
        raw = intent.read_record_text(_FIXTURE_RECORD)
        record = intent.parse_record(raw, _FIXTURE_RECORD)
        results = intent.load_results(_FIXTURE_RESULTS)
        assertions = intent.build_assertions(record, results)
        # EXP-002 fails but is declared non-blocking, so no blocking failure.
        verdict = intent.evaluate_blocking(record, assertions)
        assert verdict != intent.BLOCKING_FAILED
        # The fixture is not clean either: blocking EXP-003 declares two criteria
        # and the run settled only part of them, so its claim is unproven. The
        # old boolean gate reported success here, which is the silent pass this
        # contract now refuses. Blocking EXP-005 is untested but carries a human
        # override, so it does not contribute.
        assert verdict == intent.BLOCKING_UNCOVERED

    @_requires_contract_fixture
    def test_given_custom_assert_when_generate_then_untested_and_manual(
        self, preserve_fixture_artifact: None
    ) -> None:
        _, document = intent.generate(_FIXTURE_RECORD, _FIXTURE_RESULTS)
        custom = next(
            item
            for item in document["assertions"]
            if item["expectationId"] == "EXP-004"
        )
        assert custom["outcome"] == "untested"
        assert custom["mode"] == "manual"
        assert custom["info"]

    @_requires_contract_fixture
    def test_given_fixture_when_generate_then_digest_matches_record(
        self, preserve_fixture_artifact: None
    ) -> None:
        _, document = intent.generate(_FIXTURE_RECORD, _FIXTURE_RESULTS)
        assert document["intentDigest"] == _FIXTURE_DIGEST

    @_requires_contract_fixture
    def test_given_committed_fixture_sidecar_then_generation_does_not_touch_it(
        self, preserve_fixture_artifact: None
    ) -> None:
        intent.generate(_FIXTURE_RECORD, _FIXTURE_RESULTS)
        assert _FIXTURE_ARTIFACT.exists()


class TestBlockingEvaluation:
    def test_given_blocking_failure_when_checked_then_true(
        self, tmp_path: Path
    ) -> None:
        record_path = _write_record(tmp_path, _SIMPLE_RECORD)
        results_path = _write_results(tmp_path, [_row(status="fail")])
        raw = intent.read_record_text(record_path)
        record = intent.parse_record(raw, record_path)
        _, document = intent.generate(record_path, results_path)
        assert (
            intent.evaluate_blocking(record, document["assertions"])
            == intent.BLOCKING_FAILED
        )

    def test_given_non_blocking_failure_when_checked_then_false(
        self, tmp_path: Path
    ) -> None:
        body = _SIMPLE_RECORD.replace("blocking: true", "blocking: false").replace(
            "role: decides", "role: informs"
        )
        record_path = _write_record(tmp_path, body)
        results_path = _write_results(tmp_path, [_row(status="fail")])
        raw = intent.read_record_text(record_path)
        record = intent.parse_record(raw, record_path)
        _, document = intent.generate(record_path, results_path)
        verdict = intent.evaluate_blocking(record, document["assertions"])
        assert verdict == intent.BLOCKING_OK

    def test_given_passing_run_when_checked_then_false(self, tmp_path: Path) -> None:
        record_path = _write_record(tmp_path, _SIMPLE_RECORD)
        results_path = _write_results(tmp_path, [_row(status="pass")])
        raw = intent.read_record_text(record_path)
        record = intent.parse_record(raw, record_path)
        _, document = intent.generate(record_path, results_path)
        verdict = intent.evaluate_blocking(record, document["assertions"])
        assert verdict == intent.BLOCKING_OK

    def test_given_partial_coverage_for_blocking_when_checked_then_uncovered(
        self, tmp_path: Path
    ) -> None:
        body = _SIMPLE_RECORD.replace(
            "          - wcag-22:2.1.1",
            "          - wcag-22:2.1.1\n          - wcag-22:2.1.2",
        )
        record_path = _write_record(tmp_path, body)
        rows = [_row(criterionId="2.1.1", status="pass")]
        results_path = _write_results(tmp_path, rows)
        raw = intent.read_record_text(record_path)
        record = intent.parse_record(raw, record_path)
        _, document = intent.generate(record_path, results_path)
        assert (
            intent.evaluate_blocking(record, document["assertions"])
            == intent.BLOCKING_UNCOVERED
        )

    def test_given_duplicate_expectation_id_across_intents_when_parsed_then_raises(
        self, tmp_path: Path
    ) -> None:
        body = """
schemaVersion: "1.1"
surfaceId: s1
title: Multi intent
owner: Team
status: accepted
decidedOn: "2026-01-01"
decidedBy:
  - A. Person
version: 1
intents:
  - id: INT-001
    conveys: Blocking expectation.
    rationale: r1
    audience: [A]
    evidence: observed
    binding: { state: default }
    expectations:
      - id: EXP-001
        method: runtime-automation
        assert: probe-keyboard-traversal
        detail: d1
        criteria: [wcag-22:2.1.1]
        role: decides
        blocking: true
  - id: INT-002
    conveys: Informing expectation with same id.
    rationale: r2
    audience: [B]
    evidence: observed
    binding: { state: default }
    expectations:
      - id: EXP-001
        method: runtime-automation
        assert: probe-keyboard-traversal
        detail: d2
        criteria: [wcag-22:2.1.2]
        role: informs
        blocking: false
"""
        record_path = _write_record(tmp_path, body)
        raw = intent.read_record_text(record_path)
        with pytest.raises(ScriptError, match="Duplicate expectation id"):
            intent.parse_record(raw, record_path)

    def test_given_non_boolean_blocking_when_checked_then_raises(
        self, tmp_path: Path
    ) -> None:
        body = _SIMPLE_RECORD.replace("blocking: true", "blocking: 'true'")
        record_path = _write_record(tmp_path, body)
        results_path = _write_results(tmp_path, [_row(status="pass")])
        with pytest.raises(ScriptError, match="authored schema"):
            intent.generate(record_path, results_path)

    def test_given_override_settles_uncovered_blocking_when_checked_then_ok(
        self, tmp_path: Path
    ) -> None:
        # A human review settled a blocking expectation the probe cannot drive.
        # The artifact still records 'untested', but the gate must not fire.
        body = _SIMPLE_RECORD.replace(
            "        blocking: true\n",
            "        blocking: true\n"
            "        override:\n"
            "          outcome: passed\n"
            "          rationale: Manual review on a platform the probe cannot drive.\n"
            "          reviewedBy: C. Reviewer\n"
            '          reviewedOn: "2026-08-06"\n',
        )
        record_path = _write_record(tmp_path, body)
        results_path = _write_results(tmp_path, [])
        raw = intent.read_record_text(record_path)
        record = intent.parse_record(raw, record_path)
        _, document = intent.generate(record_path, results_path)

        assert document["assertions"][0]["outcome"] == "untested"
        assert document["assertions"][0]["effectiveOutcome"] == "passed"
        # Settling an untested expectation is the documented use of an
        # override, so it must not register as a conflict.
        assert document["assertions"][0]["overrideConflict"] is False
        verdict = intent.evaluate_blocking(record, document["assertions"])
        assert verdict == intent.BLOCKING_OK

    def test_given_override_failed_when_checked_then_blocking_failed(
        self, tmp_path: Path
    ) -> None:
        body = _SIMPLE_RECORD.replace(
            "        blocking: true\n",
            "        blocking: true\n"
            "        override:\n"
            "          outcome: failed\n"
            "          rationale: Manual review found the announcement missing.\n"
            "          reviewedBy: C. Reviewer\n"
            '          reviewedOn: "2026-08-06"\n',
        )
        record_path = _write_record(tmp_path, body)
        results_path = _write_results(tmp_path, [_row(status="pass")])
        raw = intent.read_record_text(record_path)
        record = intent.parse_record(raw, record_path)
        _, document = intent.generate(record_path, results_path)

        assertion = document["assertions"][0]
        assert assertion["outcome"] == "passed", "observation is never overwritten"
        assert assertion["effectiveOutcome"] == "failed"
        assert assertion["overrideConflict"] is True
        verdict = intent.evaluate_blocking(record, document["assertions"])
        assert verdict == intent.BLOCKING_FAILED

    def test_given_override_passed_over_observed_failure_when_checked_then_failed(
        self, tmp_path: Path
    ) -> None:
        # A prior human pass must not mask a current failing probe.
        body = _SIMPLE_RECORD.replace(
            "        blocking: true\n",
            "        blocking: true\n"
            "        override:\n"
            "          outcome: passed\n"
            "          rationale: Manual review found the probe result spurious.\n"
            "          reviewedBy: C. Reviewer\n"
            '          reviewedOn: "2026-08-06"\n',
        )
        record_path = _write_record(tmp_path, body)
        results_path = _write_results(tmp_path, [_row(status="fail")])
        raw = intent.read_record_text(record_path)
        record = intent.parse_record(raw, record_path)
        _, document = intent.generate(record_path, results_path)

        assertion = document["assertions"][0]
        assert assertion["outcome"] == "failed", "observation is never overwritten"
        assert assertion["effectiveOutcome"] == "failed"
        assert assertion["overrideConflict"] is True
        verdict = intent.evaluate_blocking(record, document["assertions"])
        assert verdict == intent.BLOCKING_FAILED

    def test_given_missing_expectation_id_when_generate_then_raises_before_write(
        self, tmp_path: Path
    ) -> None:
        body = _SIMPLE_RECORD.replace("      - id: EXP-001\n", "      -\n")
        record_path = _write_record(tmp_path, body)
        results_path = _write_results(tmp_path, [_row(status="pass")])
        out = tmp_path / "out.json"
        with pytest.raises(ScriptError, match="authored schema"):
            intent.generate(record_path, results_path, out)
        assert not out.exists()


class TestFailurePaths:
    def test_given_missing_record_when_generate_then_usage_error(
        self, tmp_path: Path
    ) -> None:
        with pytest.raises(ScriptError) as excinfo:
            intent.generate(tmp_path / "absent.intent.yaml", tmp_path / "r.json")
        assert excinfo.value.exit_code == EXIT_USAGE

    def test_given_malformed_yaml_when_generate_then_raises_and_writes_nothing(
        self, tmp_path: Path
    ) -> None:
        record_path = _write_record(tmp_path, "surfaceId: [unclosed\n")
        out = tmp_path / "out.json"
        with pytest.raises(ScriptError):
            intent.generate(record_path, tmp_path / "r.json", out)
        assert not out.exists()

    def test_given_non_mapping_record_when_generate_then_raises(
        self, tmp_path: Path
    ) -> None:
        record_path = _write_record(tmp_path, "- just\n- a\n- list\n")
        with pytest.raises(ScriptError):
            intent.generate(record_path, tmp_path / "r.json")

    def test_given_record_without_surface_id_when_generate_then_raises(
        self, tmp_path: Path
    ) -> None:
        record_path = _write_record(tmp_path, "title: no surface\n")
        with pytest.raises(ScriptError):
            intent.generate(record_path, tmp_path / "r.json")

    def test_given_surface_id_filename_mismatch_when_generate_then_raises(
        self, tmp_path: Path
    ) -> None:
        record_path = _write_record(
            tmp_path, _SIMPLE_RECORD.replace("surfaceId: s1", "surfaceId: other")
        )
        with pytest.raises(ScriptError) as excinfo:
            intent.generate(record_path, tmp_path / "r.json")
        assert "does not match filename" in str(excinfo.value)

    def test_given_missing_results_when_generate_then_usage_error(
        self, tmp_path: Path
    ) -> None:
        record_path = _write_record(tmp_path, _SIMPLE_RECORD)
        with pytest.raises(ScriptError) as excinfo:
            intent.generate(record_path, tmp_path / "absent.json")
        assert excinfo.value.exit_code == EXIT_USAGE

    def test_given_invalid_results_json_when_generate_then_raises(
        self, tmp_path: Path
    ) -> None:
        record_path = _write_record(tmp_path, _SIMPLE_RECORD)
        results_path = tmp_path / "results.json"
        results_path.write_text("{not json", encoding="utf-8")
        with pytest.raises(ScriptError):
            intent.generate(record_path, results_path)

    def test_given_non_object_results_when_generate_then_raises(
        self, tmp_path: Path
    ) -> None:
        record_path = _write_record(tmp_path, _SIMPLE_RECORD)
        results_path = tmp_path / "results.json"
        results_path.write_text("[]", encoding="utf-8")
        with pytest.raises(ScriptError):
            intent.generate(record_path, results_path)


class TestOutputLocation:
    def test_given_no_out_path_when_generate_then_writes_contract_location(
        self, tmp_path: Path
    ) -> None:
        record_path = _write_record(tmp_path, _SIMPLE_RECORD)
        results_path = _write_results(tmp_path, [_row()])
        destination, _ = intent.generate(record_path, results_path)
        assert destination == record_path.parent / ".verification" / "s1.earl.json"
        assert destination.exists()

    def test_given_explicit_out_path_when_generate_then_creates_parents(
        self, tmp_path: Path
    ) -> None:
        record_path = _write_record(tmp_path, _SIMPLE_RECORD)
        results_path = _write_results(tmp_path, [_row()])
        out = tmp_path / "nested" / "deeper" / "artifact.json"
        destination, _ = intent.generate(record_path, results_path, out)
        assert destination == out
        assert json.loads(out.read_text(encoding="utf-8"))["surfaceId"] == "s1"

    def test_given_generation_when_complete_then_timestamp_is_populated(
        self, tmp_path: Path
    ) -> None:
        record_path = _write_record(tmp_path, _SIMPLE_RECORD)
        results_path = _write_results(tmp_path, [_row()])
        _, document = intent.generate(record_path, results_path)
        assert document["timestamp"]
        assert document["assertedBy"] == intent.ASSERTED_BY
        assert document["schemaVersion"] == intent.SCHEMA_VERSION

    def test_given_symlinked_parent_when_generate_then_raises_without_overwrite(
        self, tmp_path: Path
    ) -> None:
        record_path = _write_record(tmp_path, _SIMPLE_RECORD)
        results_path = _write_results(tmp_path, [_row()])
        external = tmp_path / "external"
        external.mkdir()
        linked_parent = record_path.parent / "linked"
        linked_parent.symlink_to(external, target_is_directory=True)

        with pytest.raises(ScriptError, match="unsafe"):
            intent.generate(record_path, results_path, linked_parent / "artifact.json")

        assert not (external / "artifact.json").exists()

    def test_given_symlinked_final_when_generate_then_raises_without_overwrite(
        self, tmp_path: Path
    ) -> None:
        record_path = _write_record(tmp_path, _SIMPLE_RECORD)
        results_path = _write_results(tmp_path, [_row()])
        external = tmp_path / "external.json"
        external.write_text("keep", encoding="utf-8")
        destination = record_path.parent / "artifact.json"
        destination.symlink_to(external)

        with pytest.raises(ScriptError, match="not a regular file"):
            intent.generate(record_path, results_path, destination)

        assert external.read_text(encoding="utf-8") == "keep"

    def test_given_out_of_root_path_when_generate_then_raises(
        self, tmp_path: Path
    ) -> None:
        project_root = tmp_path / "project"
        record_path = _write_record(project_root, _SIMPLE_RECORD)
        results_path = _write_results(project_root, [_row()])

        with pytest.raises(ScriptError, match="escapes the record directory"):
            intent.generate(record_path, results_path, tmp_path / "outside.json")

    def test_given_first_run_when_generate_then_creates_verification_directory(
        self, tmp_path: Path
    ) -> None:
        record_path = _write_record(tmp_path, _SIMPLE_RECORD)
        results_path = _write_results(tmp_path, [_row()])

        destination, _ = intent.generate(record_path, results_path)

        assert destination.is_file()
        assert destination.parent.name == ".verification"

    def test_given_directory_destination_when_generate_then_raises(
        self, tmp_path: Path
    ) -> None:
        record_path = _write_record(tmp_path, _SIMPLE_RECORD)
        results_path = _write_results(tmp_path, [_row()])
        destination = record_path.parent / "artifact.json"
        destination.mkdir()

        with pytest.raises(ScriptError, match="not a regular file"):
            intent.generate(record_path, results_path, destination)

    def test_given_unsupported_platform_when_generate_then_fails_closed(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        record_path = _write_record(tmp_path, _SIMPLE_RECORD)
        results_path = _write_results(tmp_path, [_row()])
        monkeypatch.setattr(intent.os, "supports_dir_fd", set())

        with pytest.raises(ScriptError, match="Secure verification artifact"):
            intent.generate(record_path, results_path)

    def test_given_fifo_destination_when_generate_then_raises(
        self, tmp_path: Path
    ) -> None:
        record_path = _write_record(tmp_path, _SIMPLE_RECORD)
        results_path = _write_results(tmp_path, [_row()])
        destination = record_path.parent / "artifact.json"
        intent.os.mkfifo(destination)

        with pytest.raises(ScriptError, match="not a regular file"):
            intent.generate(record_path, results_path, destination)

    def test_given_parent_replaced_after_open_when_generate_then_not_redirected(
        self,
        tmp_path: Path,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        record_path = _write_record(tmp_path, _SIMPLE_RECORD)
        results_path = _write_results(tmp_path, [_row()])
        destination = record_path.parent / "verified" / "artifact.json"
        original_open = intent._open_destination_directory

        def replace_parent(root_fd: int, parts: tuple[str, ...]) -> int:
            directory_fd = original_open(root_fd, parts)
            destination.parent.rename(record_path.parent / "retained")
            destination.parent.mkdir()
            return directory_fd

        monkeypatch.setattr(intent, "_open_destination_directory", replace_parent)

        written, _ = intent.generate(record_path, results_path, destination)

        assert written == destination
        assert (record_path.parent / "retained" / "artifact.json").is_file()
        assert not destination.exists()

    def test_given_temp_collision_when_generate_then_preserves_existing_entry(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        record_path = _write_record(tmp_path, _SIMPLE_RECORD)
        results_path = _write_results(tmp_path, [_row()])
        destination = record_path.parent / "artifact.json"
        collision = record_path.parent / ".artifact.json.fixed.tmp"
        collision.write_text("keep", encoding="utf-8")
        monkeypatch.setattr(intent.secrets, "token_hex", lambda _: "fixed")

        with pytest.raises(ScriptError, match="safely"):
            intent.generate(record_path, results_path, destination)

        assert collision.read_text(encoding="utf-8") == "keep"
        assert not destination.exists()

    def test_given_write_failure_when_generate_then_cleans_owned_temp_handle_relatively(
        self,
        tmp_path: Path,
        monkeypatch: pytest.MonkeyPatch,
        mocker: MockerFixture,
    ) -> None:
        record_path = _write_record(tmp_path, _SIMPLE_RECORD)
        results_path = _write_results(tmp_path, [_row()])
        destination = record_path.parent / "artifact.json"
        unlink = mocker.spy(intent.os, "unlink")
        monkeypatch.setattr(
            intent.os,
            "supports_dir_fd",
            set(intent.os.supports_dir_fd) | {unlink},
        )
        mocker.patch.object(intent.os, "fsync", side_effect=OSError("write failed"))

        with pytest.raises(ScriptError, match="safely"):
            intent.generate(record_path, results_path, destination)

        cleanup = next(call for call in unlink.call_args_list if call.kwargs)
        assert cleanup.kwargs["dir_fd"] >= 0
        assert not destination.exists()

    def test_given_successful_write_when_generate_then_renames_handle_relatively(
        self,
        tmp_path: Path,
        monkeypatch: pytest.MonkeyPatch,
        mocker: MockerFixture,
    ) -> None:
        record_path = _write_record(tmp_path, _SIMPLE_RECORD)
        results_path = _write_results(tmp_path, [_row()])
        destination = record_path.parent / "artifact.json"
        rename = mocker.spy(intent.os, "rename")
        monkeypatch.setattr(
            intent.os,
            "supports_dir_fd",
            set(intent.os.supports_dir_fd) | {rename},
        )

        intent.generate(record_path, results_path, destination)

        call = rename.call_args_list[-1]
        assert call.kwargs["src_dir_fd"] == call.kwargs["dst_dir_fd"]
        assert call.kwargs["src_dir_fd"] >= 0

    def test_given_stream_wrap_failure_when_generate_then_closes_raw_descriptor(
        self, tmp_path: Path, mocker: MockerFixture
    ) -> None:
        record_path = _write_record(tmp_path, _SIMPLE_RECORD)
        results_path = _write_results(tmp_path, [_row()])
        destination = record_path.parent / "artifact.json"
        captured: list[int] = []
        close = mocker.spy(intent.os, "close")

        def fail_to_wrap(descriptor: int, *_: object, **__: object) -> object:
            captured.append(descriptor)
            raise MemoryError("stream allocation failed")

        mocker.patch.object(intent.os, "fdopen", side_effect=fail_to_wrap)

        with pytest.raises(MemoryError, match="stream allocation failed"):
            intent.generate(record_path, results_path, destination)

        assert captured
        assert any(call.args == (captured[0],) for call in close.call_args_list)
        assert not destination.exists()


class TestManualDecidingCustom:
    def _custom_record(self, override: str = "") -> str:
        return _SIMPLE_RECORD.replace(
            "        method: runtime-automation\n"
            "        assert: probe-keyboard-traversal\n",
            "        method: cognitive-walkthrough\n        assert: custom\n",
        ).replace("        blocking: true\n", "        blocking: true\n" + override)

    def test_given_deciding_custom_without_review_when_checked_then_uncovered(
        self, tmp_path: Path
    ) -> None:
        record_path = _write_record(tmp_path, self._custom_record())
        results_path = _write_results(tmp_path, [])
        raw = intent.read_record_text(record_path)
        record = intent.parse_record(raw, record_path)
        _, document = intent.generate(record_path, results_path)

        assert document["assertions"][0]["outcome"] == "untested"
        assert (
            intent.evaluate_blocking(record, document["assertions"])
            == intent.BLOCKING_UNCOVERED
        )

    @pytest.mark.parametrize(
        ("outcome", "expected"),
        [("passed", intent.BLOCKING_OK), ("failed", intent.BLOCKING_FAILED)],
    )
    def test_given_deciding_custom_review_when_checked_then_applies_outcome(
        self, tmp_path: Path, outcome: str, expected: str
    ) -> None:
        override = (
            "        override:\n"
            f"          outcome: {outcome}\n"
            "          rationale: Human review settles the graphics meaning.\n"
            "          reviewedBy: C. Reviewer\n"
            '          reviewedOn: "2026-08-07"\n'
        )
        record_path = _write_record(tmp_path, self._custom_record(override))
        results_path = _write_results(tmp_path, [])
        raw = intent.read_record_text(record_path)
        record = intent.parse_record(raw, record_path)
        _, document = intent.generate(record_path, results_path)

        assert document["assertions"][0]["effectiveOutcome"] == outcome
        assert intent.evaluate_blocking(record, document["assertions"]) == expected

    def test_given_informational_custom_when_checked_then_remains_non_blocking(
        self, tmp_path: Path
    ) -> None:
        body = self._custom_record().replace(
            "        role: decides\n        blocking: true\n",
            "        role: informs\n        blocking: false\n",
        )
        record_path = _write_record(tmp_path, body)
        results_path = _write_results(tmp_path, [])
        raw = intent.read_record_text(record_path)
        record = intent.parse_record(raw, record_path)

        _, document = intent.generate(record_path, results_path)

        assert (
            intent.evaluate_blocking(record, document["assertions"])
            == intent.BLOCKING_OK
        )

    def test_given_existing_complete_override_when_parse_then_migration_preserves_it(
        self, tmp_path: Path
    ) -> None:
        override = (
            "        override:\n"
            "          outcome: passed\n"
            "          rationale: Existing review remains authoritative.\n"
            "          reviewedBy: C. Reviewer\n"
            '          reviewedOn: "2026-08-07"\n'
        )
        record_path = _write_record(tmp_path, self._custom_record(override))
        raw = intent.read_record_text(record_path)

        record = intent.parse_record(raw, record_path)

        assert record["intents"][0]["expectations"][0]["override"] == {
            "outcome": "passed",
            "rationale": "Existing review remains authoritative.",
            "reviewedBy": "C. Reviewer",
            "reviewedOn": "2026-08-07",
        }


class TestCli:
    @pytest.mark.parametrize(
        ("failure_marker", "explicit_output"),
        [
            ({"quarantined": True}, True),
            ({"operationalFailure": {"reason": "probe stopped"}}, False),
        ],
    )
    def test_given_incomplete_results_when_verify_intent_then_rejects_without_artifact(
        self,
        tmp_path: Path,
        failure_marker: dict[str, object],
        explicit_output: bool,
    ) -> None:
        record_path = _write_record(tmp_path, _SIMPLE_RECORD)
        results_path = tmp_path / "results.json"
        results_path.write_text(
            json.dumps({"results": [_row()], **failure_marker}),
            encoding="utf-8",
        )
        destination = (
            tmp_path / "explicit.json"
            if explicit_output
            else record_path.parent / ".verification" / "s1.earl.json"
        )
        argv = [
            "verify-intent",
            "--record",
            str(record_path),
            "--results",
            str(results_path),
        ]
        if explicit_output:
            argv.extend(["--out", str(destination)])

        code = cli.main(argv)

        assert code == EXIT_USAGE
        assert not destination.exists()

    def test_given_clean_run_when_verify_intent_then_exit_success(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        record_path = _write_record(tmp_path, _SIMPLE_RECORD)
        results_path = _write_results(tmp_path, [_row(status="pass")])
        out = tmp_path / "out.json"
        code = cli.main(
            [
                "verify-intent",
                "--record",
                str(record_path),
                "--results",
                str(results_path),
                "--out",
                str(out),
            ]
        )
        assert code == EXIT_SUCCESS
        assert "Wrote" in capsys.readouterr().out

    def test_given_override_conflict_when_verify_intent_then_warns_and_gates(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        # A conclusive conflict is written to stderr and fails closed.
        # Settling an unreachable expectation is the documented use of an
        # override, so that path must stay silent.
        conflict_body = _SIMPLE_RECORD.replace(
            "        blocking: true\n",
            "        blocking: true\n"
            "        override:\n"
            "          outcome: passed\n"
            "          rationale: Manual review found the probe result spurious.\n"
            "          reviewedBy: C. Reviewer\n"
            '          reviewedOn: "2026-08-06"\n',
        )
        conflict_record = _write_record(tmp_path, conflict_body)
        conflict_results = _write_results(tmp_path, [_row(status="fail")])
        conflict_code = cli.main(
            [
                "verify-intent",
                "--record",
                str(conflict_record),
                "--results",
                str(conflict_results),
                "--out",
                str(tmp_path / "conflict.json"),
            ]
        )
        conflict_stderr = capsys.readouterr().err

        settled_dir = tmp_path / "settled"
        settled_record = _write_record(settled_dir, conflict_body)
        settled_results = _write_results(settled_dir, [])
        settled_code = cli.main(
            [
                "verify-intent",
                "--record",
                str(settled_record),
                "--results",
                str(settled_results),
                "--out",
                str(settled_dir / "settled.json"),
            ]
        )
        settled_stderr = capsys.readouterr().err

        assert conflict_code == EXIT_INTENT_DRIFT
        assert "Warning: design intent override conflict" in conflict_stderr
        assert "INT-001" in conflict_stderr and "EXP-001" in conflict_stderr
        assert "observed outcome 'failed'" in conflict_stderr
        assert "override outcome 'passed'" in conflict_stderr
        assert settled_code == EXIT_SUCCESS
        assert "Warning:" not in settled_stderr

    def test_given_blocking_failure_when_verify_intent_then_exit_drift(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        record_path = _write_record(tmp_path, _SIMPLE_RECORD)
        results_path = _write_results(tmp_path, [_row(status="fail")])
        out = tmp_path / "out.json"
        code = cli.main(
            [
                "verify-intent",
                "--record",
                str(record_path),
                "--results",
                str(results_path),
                "--out",
                str(out),
            ]
        )
        assert code == EXIT_INTENT_DRIFT
        assert "blocking design intent expectation failed" in capsys.readouterr().err
        assert out.exists(), "the artifact is still written so CI can publish it"

    def test_given_blocking_uncovered_when_verify_intent_then_exit_uncovered(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        body = _SIMPLE_RECORD.replace(
            "          - wcag-22:2.1.1",
            "          - wcag-22:2.1.1\n          - wcag-22:2.1.2",
        )
        record_path = _write_record(tmp_path, body)
        results_path = _write_results(
            tmp_path, [_row(criterionId="2.1.1", status="pass")]
        )
        out = tmp_path / "out.json"
        code = cli.main(
            [
                "verify-intent",
                "--record",
                str(record_path),
                "--results",
                str(results_path),
                "--out",
                str(out),
            ]
        )
        assert code == EXIT_INTENT_UNCOVERED
        assert (
            "blocking design intent expectation was never evaluated"
            in capsys.readouterr().err
        )
        assert out.exists(), "the artifact is still written so CI can publish it"

    def test_given_missing_record_when_verify_intent_then_usage_exit(
        self, tmp_path: Path
    ) -> None:
        code = cli.main(
            [
                "verify-intent",
                "--record",
                str(tmp_path / "absent.intent.yaml"),
                "--results",
                str(tmp_path / "absent.json"),
            ]
        )
        assert code == EXIT_USAGE
