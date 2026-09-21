# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Tests for `scripts.scan_sensitive_content`.

Covers high-confidence PII and public internal-URL findings, benign ADR prose
true negatives, non-PII credential-shaped text, and the external-sink gating
contract that non-zero exit accompanies any high-confidence finding.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

scan_sensitive_content = pytest.importorskip("scripts.scan_sensitive_content")


def _invoke(args: list[str], capsys: pytest.CaptureFixture[str]) -> tuple[int, dict]:
    """Invoke `scan_sensitive_content.main` and return exit code plus parsed JSON."""
    try:
        exit_code = int(scan_sensitive_content.main(args) or 0)
    except SystemExit as exc:
        exit_code = int(exc.code or 0)
    out = capsys.readouterr().out
    report = json.loads(out) if out.strip() else {}
    return exit_code, report


class TestScanHighConfidenceTruePositives:
    @pytest.mark.parametrize(
        ("pii", "category"),
        [
            ("alice@example.com", "email_address"),
            ("425-555-0100", "phone_number"),
            ("123-45-6789", "national_identifier"),
        ],
    )
    def test_given_pii_when_scan_then_high_finding_and_nonzero_exit(
        self,
        tmp_path: Path,
        capsys: pytest.CaptureFixture[str],
        pii: str,
        category: str,
    ) -> None:
        # Arrange
        target = tmp_path / "adr.md"
        target.write_text(f"Contact detail: {pii}\n", encoding="utf-8")

        # Act
        exit_code, report = _invoke([str(target)], capsys)

        # Assert
        assert exit_code == scan_sensitive_content.EXIT_FAILURE
        categories = {f["category"] for f in report["findings"]}
        assert category in categories
        assert report["summary"]["high"] >= 1
        # The raw PII must not be echoed back verbatim (redaction contract).
        assert pii not in json.dumps(report)


class TestScanSafeNegatives:
    @pytest.mark.parametrize(
        "benign",
        [
            "We chose Postgres for ACID guarantees and operational maturity.",
            "See https://learn.microsoft.com/azure for guidance.",
            "The decision ID is 0007 and supersedes 0003.",
            "Latency budget is 200ms at p99 under peak load.",
        ],
    )
    def test_given_benign_prose_when_scan_then_no_findings_and_zero_exit(
        self,
        tmp_path: Path,
        benign: str,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange
        target = tmp_path / "adr.md"
        target.write_text(benign + "\n", encoding="utf-8")

        # Act
        exit_code, report = _invoke([str(target)], capsys)

        # Assert
        assert exit_code == scan_sensitive_content.EXIT_SUCCESS
        assert report["summary"]["high"] == 0

    @pytest.mark.parametrize(
        "provider_key_shape",
        [
            "-----BEGIN RSA PRIVATE KEY-----",
            "ghp_0123456789abcdefghijklmnopqrstuvwxyz",
            "AKIAIOSFODNN7EXAMPLE",
            "AIzaSyA0123456789abcdefghijklmnopqrstuvwxyz0",
            "example slack token placeholder",
            "sk-0123456789abcdefghijklmnopqrstuvwxyzABCDEF",
        ],
    )
    def test_given_provider_key_shape_when_scan_then_no_findings_and_zero_exit(
        self,
        tmp_path: Path,
        provider_key_shape: str,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange
        target = tmp_path / "adr.md"
        target.write_text(f"Decision note includes {provider_key_shape} as sample text.\n", encoding="utf-8")

        # Act
        exit_code, report = _invoke([str(target)], capsys)

        # Assert
        assert exit_code == scan_sensitive_content.EXIT_SUCCESS
        assert report["summary"] == {"high": 0, "warn": 0, "total": 0}


class TestScanInternalUrlVisibility:
    @pytest.mark.parametrize(
        "internal_url",
        [
            "http://localhost:8080/admin",
            "https://10.1.2.3/healthz",
            "http://db.corp/status",
        ],
    )
    def test_given_internal_url_when_private_then_no_high_and_zero_exit(
        self,
        tmp_path: Path,
        internal_url: str,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange
        target = tmp_path / "adr.md"
        target.write_text(f"Service runs at {internal_url} today.\n", encoding="utf-8")

        # Act
        exit_code, report = _invoke([str(target)], capsys)

        # Assert
        assert exit_code == scan_sensitive_content.EXIT_SUCCESS
        categories = {f["category"] for f in report["findings"]}
        assert "internal_url" not in categories
        assert report["summary"]["high"] == 0

    @pytest.mark.parametrize(
        "internal_url",
        [
            "http://localhost:8080/admin",
            "https://10.1.2.3/healthz",
            "http://db.corp/status",
        ],
    )
    def test_given_internal_url_when_public_then_high_and_nonzero_exit(
        self,
        tmp_path: Path,
        internal_url: str,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange
        target = tmp_path / "adr.md"
        target.write_text(f"Service runs at {internal_url} today.\n", encoding="utf-8")

        # Act
        exit_code, report = _invoke(["--public", str(target)], capsys)

        # Assert
        assert exit_code == scan_sensitive_content.EXIT_FAILURE
        categories = {f["category"] for f in report["findings"]}
        assert "internal_url" in categories
        assert report["summary"]["high"] >= 1


class TestScanStdin:
    def test_given_pii_on_stdin_when_scan_then_nonzero_exit(
        self,
        monkeypatch: pytest.MonkeyPatch,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange
        import io

        monkeypatch.setattr("sys.stdin", io.StringIO("Contact: alice@example.com\n"))

        # Act
        exit_code, report = _invoke([], capsys)

        # Assert
        assert exit_code == scan_sensitive_content.EXIT_FAILURE
        assert report["summary"]["high"] >= 1
        assert report["findings"][0]["source"] == scan_sensitive_content.STDIN_SOURCE


class TestScanDataMode:
    @pytest.mark.parametrize(
        ("content", "category", "confidence"),
        [
            ("columns: [ssn]", "sensitive_column_name", "high"),
            ("- name: patientId", "sensitive_column_name", "warn"),
            ("customer_id varchar(40)", None, None),
            ("Server=db;Initial Catalog=orders;User Id=app;Password=secret", "connection_string", "high"),
            ("url: jdbc:postgresql://db/orders", "jdbc_odbc_uri", "high"),
            ("url: postgres://user:secret@db/orders", "db_uri_with_credentials", "high"),
            ("AccountKey=YWJjZGVmZ2hpamtsbW5vcHFyc3R1", "storage_key", "high"),
            ("Authorization: Bearer abcdefghijklmnop", "bearer_token", "high"),
            ("national_insurance: AB123456C", "uk_national_insurance", "warn"),
            ("sin: 046 454 286", "canadian_sin", "warn"),
            ("phone: +442079460958", "international_phone", "warn"),
            (
                "url: https://acct.blob.core.windows.net/c?sp=r&se=2030-01-01&sig=secret",
                "sas_token",
                "high",
            ),
        ],
    )
    def test_given_data_rule_when_data_mode_then_expected_finding(
        self,
        tmp_path: Path,
        capsys: pytest.CaptureFixture[str],
        content: str,
        category: str | None,
        confidence: str | None,
    ) -> None:
        # Arrange
        target = tmp_path / "data.txt"
        target.write_text(content + "\n", encoding="utf-8")

        # Act
        exit_code, report = _invoke(["--data", str(target)], capsys)

        # Assert
        categories = {finding["category"] for finding in report["findings"]}
        if category is None:
            assert exit_code == scan_sensitive_content.EXIT_SUCCESS
            assert categories == set()
        else:
            assert category in categories
            expected_exit = (
                scan_sensitive_content.EXIT_FAILURE if confidence == "high" else scan_sensitive_content.EXIT_SUCCESS
            )
            assert exit_code == expected_exit

    def test_given_sample_table_when_data_mode_then_warns_without_blocking(
        self,
        tmp_path: Path,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange
        target = tmp_path / "catalog.md"
        target.write_text(
            "## Sample rows\n\n| id | value |\n|----|-------|\n| 1 | synthetic |\n",
            encoding="utf-8",
        )

        # Act
        exit_code, report = _invoke(["--data", str(target)], capsys)

        # Assert
        assert exit_code == scan_sensitive_content.EXIT_SUCCESS
        assert any(finding["category"] == "sample_row" for finding in report["findings"])
        assert report["summary"]["warn"] >= 1

    def test_given_data_only_content_when_default_mode_then_preserves_empty_result(
        self,
        tmp_path: Path,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange
        target = tmp_path / "adr.md"
        target.write_text("columns: [ssn]\nurl: jdbc:postgresql://db/orders\n", encoding="utf-8")

        # Act
        exit_code, report = _invoke([str(target)], capsys)

        # Assert
        assert exit_code == scan_sensitive_content.EXIT_SUCCESS
        assert report["summary"] == {"high": 0, "warn": 0, "total": 0}


class TestScanDenylist:
    def test_given_denylist_when_term_differs_by_case_then_blocks_without_leak(
        self,
        tmp_path: Path,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange
        denylist = tmp_path / "terms.txt"
        denylist.write_text("Contoso-Blue\n\ncontoso-blue\n", encoding="utf-8")
        target = tmp_path / "artifact.md"
        target.write_text("Tenant: CONTOSO-BLUE\n", encoding="utf-8")

        # Act
        exit_code, report = _invoke(["--denylist", str(denylist), str(target)], capsys)

        # Assert
        assert exit_code == scan_sensitive_content.EXIT_FAILURE
        denylist_findings = [finding for finding in report["findings"] if finding["category"] == "denylist_term"]
        assert len(denylist_findings) == 1
        assert "contoso-blue" not in json.dumps(report).lower()

    def test_given_denylist_and_other_modes_when_scanned_then_rules_form_union(
        self,
        tmp_path: Path,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange
        denylist = tmp_path / "terms.txt"
        denylist.write_text("tenant-seven\n", encoding="utf-8")
        target = tmp_path / "artifact.md"
        target.write_text(
            "tenant-seven\ncolumns: [dob]\nhttp://localhost/admin\n",
            encoding="utf-8",
        )

        # Act
        _, report = _invoke(
            ["--public", "--data", "--denylist", str(denylist), str(target)],
            capsys,
        )

        # Assert
        categories = {finding["category"] for finding in report["findings"]}
        assert {"denylist_term", "sensitive_column_name", "internal_url"} <= categories

    @pytest.mark.parametrize("kind", ["missing", "directory", "invalid-utf8"])
    def test_given_invalid_denylist_when_scanned_then_returns_error(
        self,
        tmp_path: Path,
        capsys: pytest.CaptureFixture[str],
        kind: str,
    ) -> None:
        # Arrange
        denylist = tmp_path / "terms.txt"
        if kind == "directory":
            denylist.mkdir()
        elif kind == "invalid-utf8":
            denylist.write_bytes(b"\xff\xfe")

        # Act
        exit_code, report = _invoke(
            ["--allow-root", str(tmp_path), "--denylist", str(denylist)],
            capsys,
        )

        # Assert
        assert exit_code == scan_sensitive_content.EXIT_ERROR
        assert report["status"] == scan_sensitive_content.STATUS_ERROR
        assert report["error"]["code"] == "denylist_unreadable"
        assert report["summary"] == {"high": 0, "warn": 0, "total": 0}


class TestScanPerformance:
    def test_given_long_benign_input_when_data_mode_then_completes_without_findings(
        self,
        tmp_path: Path,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange
        target = tmp_path / "large.txt"
        target.write_text(("ordinary catalog context " * 20000) + "\n", encoding="utf-8")

        # Act
        exit_code, report = _invoke(["--data", str(target)], capsys)

        # Assert
        assert exit_code == scan_sensitive_content.EXIT_SUCCESS
        assert report["summary"] == {"high": 0, "warn": 0, "total": 0}


class TestScanPathTraversal:
    @pytest.mark.parametrize(
        "adversarial",
        [
            "../../../etc/passwd",
            "..\\..\\..\\Windows\\System32\\config\\SAM",
        ],
    )
    def test_given_traversal_path_when_scan_then_exits_error(
        self,
        adversarial: str,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Act
        exit_code, report = _invoke([adversarial], capsys)

        # Assert
        assert exit_code == scan_sensitive_content.EXIT_ERROR
        assert report["status"] == scan_sensitive_content.STATUS_ERROR
        assert report["error"]["code"] == "path_error"


def _set_stdin(monkeypatch: pytest.MonkeyPatch, text: str) -> None:
    """Replace stdin with an in-memory stream containing ``text``."""
    import io

    monkeypatch.setattr("sys.stdin", io.StringIO(text))


class _UndecodableStdin:
    """Stdin stub that fails to decode, mirroring a non-UTF-8 pipe."""

    def read(self) -> str:
        raise UnicodeDecodeError("utf-8", b"\xff", 0, 1, "invalid start byte")


class TestReportContract:
    def test_given_clean_file_when_scan_then_completed_report_with_mode_attestation(
        self,
        tmp_path: Path,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange
        target = tmp_path / "adr.md"
        target.write_text("We chose managed identities over shared keys.\n", encoding="utf-8")

        # Act
        exit_code, report = _invoke([str(target)], capsys)

        # Assert
        assert exit_code == scan_sensitive_content.EXIT_SUCCESS
        assert report["schema_version"] == scan_sensitive_content.SCHEMA_VERSION
        assert report["status"] == scan_sensitive_content.STATUS_COMPLETED
        assert report["modes"] == {"public": False, "data": False, "denylist": False}
        assert report["denylist_rule_count"] == 0
        assert report["summary"] == {"high": 0, "warn": 0, "total": 0}

    def test_given_same_clean_file_when_data_mode_then_modes_distinguish_reports(
        self,
        tmp_path: Path,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange
        target = tmp_path / "adr.md"
        target.write_text("We chose managed identities over shared keys.\n", encoding="utf-8")

        # Act
        default_exit, default_report = _invoke([str(target)], capsys)
        data_exit, data_report = _invoke(["--data", str(target)], capsys)

        # Assert
        assert default_exit == data_exit == scan_sensitive_content.EXIT_SUCCESS
        assert default_report["summary"] == data_report["summary"]
        assert default_report["modes"]["data"] is False
        assert data_report["modes"]["data"] is True
        assert default_report["modes"] != data_report["modes"]

    def test_given_high_finding_when_scan_then_status_completed_with_exit_one(
        self,
        tmp_path: Path,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange
        target = tmp_path / "adr.md"
        target.write_text("Contact: alice@example.com\n", encoding="utf-8")

        # Act
        exit_code, report = _invoke([str(target)], capsys)

        # Assert
        assert exit_code == scan_sensitive_content.EXIT_FAILURE
        assert report["status"] == scan_sensitive_content.STATUS_COMPLETED
        assert report["summary"]["high"] == 1

    def test_given_unreadable_path_when_scan_then_error_status_not_blocked_status(
        self,
        tmp_path: Path,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange
        target = tmp_path / "not-a-file"
        target.mkdir()

        # Act
        exit_code, report = _invoke([str(target)], capsys)

        # Assert
        assert exit_code == scan_sensitive_content.EXIT_ERROR
        assert report["status"] == scan_sensitive_content.STATUS_ERROR
        assert report["error"]["code"] == "read_error"
        assert report["findings"] == []

    def test_given_undecodable_file_when_scan_then_decode_error_and_exit_two(
        self,
        tmp_path: Path,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange
        target = tmp_path / "binary.md"
        target.write_bytes(b"\xff\xfe\x00binary")

        # Act
        exit_code, report = _invoke([str(target)], capsys)

        # Assert
        assert exit_code == scan_sensitive_content.EXIT_ERROR
        assert report["status"] == scan_sensitive_content.STATUS_ERROR
        assert report["error"]["code"] == "decode_error"

    def test_given_multiple_paths_when_scan_then_findings_sort_by_source(
        self,
        tmp_path: Path,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange
        first = tmp_path / "a.md"
        second = tmp_path / "b.md"
        first.write_text("Contact: alice@example.com\n", encoding="utf-8")
        second.write_text("Contact: bob@example.com\n", encoding="utf-8")

        # Act
        _, report = _invoke([str(second), str(first)], capsys)

        # Assert
        sources = [finding["source"] for finding in report["findings"]]
        assert sources == sorted(sources)
        assert sources == [str(first), str(second)]


class TestStdinTerminalStates:
    def test_given_clean_stdin_when_scan_then_completed_and_zero_exit(
        self,
        monkeypatch: pytest.MonkeyPatch,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange
        _set_stdin(monkeypatch, "We chose managed identities over shared keys.\n")

        # Act
        exit_code, report = _invoke([], capsys)

        # Assert
        assert exit_code == scan_sensitive_content.EXIT_SUCCESS
        assert report["status"] == scan_sensitive_content.STATUS_COMPLETED
        assert report["summary"] == {"high": 0, "warn": 0, "total": 0}

    def test_given_pii_stdin_when_scan_then_completed_and_exit_one(
        self,
        monkeypatch: pytest.MonkeyPatch,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange
        _set_stdin(monkeypatch, "Contact: alice@example.com\n")

        # Act
        exit_code, report = _invoke([], capsys)

        # Assert
        assert exit_code == scan_sensitive_content.EXIT_FAILURE
        assert report["status"] == scan_sensitive_content.STATUS_COMPLETED

    def test_given_undecodable_stdin_when_scan_then_error_and_exit_two(
        self,
        monkeypatch: pytest.MonkeyPatch,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange
        monkeypatch.setattr("sys.stdin", _UndecodableStdin())

        # Act
        exit_code, report = _invoke([], capsys)

        # Assert
        assert exit_code == scan_sensitive_content.EXIT_ERROR
        assert report["status"] == scan_sensitive_content.STATUS_ERROR
        assert report["error"]["code"] == "decode_error"

    def test_given_oversized_stdin_when_scan_then_input_too_large(
        self,
        monkeypatch: pytest.MonkeyPatch,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange
        monkeypatch.setattr(scan_sensitive_content, "MAX_INPUT_BYTES", 16)
        _set_stdin(monkeypatch, "Contact: alice@example.com and carol@example.com\n")

        # Act
        exit_code, report = _invoke([], capsys)

        # Assert
        assert exit_code == scan_sensitive_content.EXIT_ERROR
        assert report["error"]["code"] == "input_too_large"
        assert report["findings"] == []


class TestInputBounds:
    def test_given_oversized_file_when_scan_then_rejected_before_rules_run(
        self,
        tmp_path: Path,
        monkeypatch: pytest.MonkeyPatch,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange
        monkeypatch.setattr(scan_sensitive_content, "MAX_INPUT_BYTES", 16)
        target = tmp_path / "adr.md"
        target.write_text("Contact: alice@example.com\n", encoding="utf-8")

        # Act
        exit_code, report = _invoke([str(target)], capsys)

        # Assert
        assert exit_code == scan_sensitive_content.EXIT_ERROR
        assert report["error"]["code"] == "input_too_large"
        assert report["summary"] == {"high": 0, "warn": 0, "total": 0}

    def test_given_content_past_line_cap_when_scan_then_not_scanned(
        self,
        tmp_path: Path,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange
        padding = "a" * (scan_sensitive_content.MAX_LINE_LENGTH + 100)
        target = tmp_path / "adr.md"
        target.write_text(f"{padding} alice@example.com\n", encoding="utf-8")

        # Act
        exit_code, report = _invoke([str(target)], capsys)

        # Assert
        assert exit_code == scan_sensitive_content.EXIT_SUCCESS
        assert report["summary"]["high"] == 0

    def test_given_repeated_credential_segments_when_data_mode_then_scan_completes(
        self,
        tmp_path: Path,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange
        target = tmp_path / "adversarial.txt"
        target.write_text("Password=synthetic;User Id=synthetic\n" * 2000, encoding="utf-8")

        # Act
        exit_code, report = _invoke(["--data", str(target)], capsys)

        # Assert
        assert report["status"] == scan_sensitive_content.STATUS_COMPLETED
        assert exit_code == scan_sensitive_content.EXIT_FAILURE
        assert report["summary"]["high"] >= 1


class TestDenylistConfiguration:
    @pytest.mark.parametrize(
        ("contents", "code"),
        [
            ("", "denylist_empty"),
            ("   \n\t\n\n", "denylist_empty"),
            ("ab\n", "denylist_term_too_short"),
            ("x" * 70000, "denylist_too_large"),
            ("\n".join(f"term{index:05d}" for index in range(1001)), "denylist_too_large"),
        ],
        # Explicit ids keep the generated test id short. Deriving ids from the
        # parameter values embeds the oversized fixtures in PYTEST_CURRENT_TEST,
        # which exceeds the 32767-character environment variable limit on Windows.
        ids=[
            "empty",
            "whitespace-only",
            "term-too-short",
            "file-too-large",
            "too-many-terms",
        ],
    )
    def test_given_unusable_denylist_when_scanned_then_specific_error_code(
        self,
        tmp_path: Path,
        capsys: pytest.CaptureFixture[str],
        contents: str,
        code: str,
    ) -> None:
        # Arrange
        denylist = tmp_path / "terms.txt"
        denylist.write_text(contents, encoding="utf-8")
        target = tmp_path / "artifact.md"
        target.write_text("benign content\n", encoding="utf-8")

        # Act
        exit_code, report = _invoke(["--denylist", str(denylist), str(target)], capsys)

        # Assert
        assert exit_code == scan_sensitive_content.EXIT_ERROR
        assert report["status"] == scan_sensitive_content.STATUS_ERROR
        assert report["error"]["code"] == code
        assert report["summary"] == {"high": 0, "warn": 0, "total": 0}

    def test_given_denylist_outside_allow_roots_when_scanned_then_path_error(
        self,
        tmp_path: Path,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange
        outside = tmp_path / "outside"
        outside.mkdir()
        denylist = outside / "terms.txt"
        denylist.write_text("tenant-seven\n", encoding="utf-8")
        scanned = tmp_path / "scanned"
        scanned.mkdir()
        target = scanned / "artifact.md"
        target.write_text("benign content\n", encoding="utf-8")

        # Act
        exit_code, report = _invoke(["--denylist", str(denylist), str(target)], capsys)

        # Assert
        assert exit_code == scan_sensitive_content.EXIT_ERROR
        assert report["error"]["code"] == "path_error"

    def test_given_usable_denylist_when_scanned_then_rule_count_reported(
        self,
        tmp_path: Path,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange
        denylist = tmp_path / "terms.txt"
        denylist.write_text("tenant-seven\nTENANT-SEVEN\nproject-indigo\n\n", encoding="utf-8")
        target = tmp_path / "artifact.md"
        target.write_text("benign content\n", encoding="utf-8")

        # Act
        exit_code, report = _invoke(["--denylist", str(denylist), str(target)], capsys)

        # Assert
        assert exit_code == scan_sensitive_content.EXIT_SUCCESS
        assert report["modes"]["denylist"] is True
        assert report["denylist_rule_count"] == 2


class TestSecretDetection:
    SECRET_FIXTURES: tuple[tuple[str, str, str], ...] = (
        ("private_key_block", "-----BEGIN RSA PRIVATE KEY-----", "PRIVATE KEY"),
        ("cloud_access_key_id", "AKIAZZ7SYNTHETIC0000", "SYNTHETIC"),
        ("source_control_token", "ghp_synthetic" + "0" * 27, "synthetic"),
        ("chat_webhook_token", "xoxb-synthetic-000000", "synthetic"),
        (
            "web_token",
            "eyJsynthetic0000.eyJsynthetic1111.synthetic2222222",
            "synthetic1111",
        ),
        ("generic_secret_assignment", 'api_key = "synthetic0000000000"', "synthetic0000"),
    )

    @pytest.mark.parametrize(("category", "payload", "fragment"), SECRET_FIXTURES)
    def test_given_secret_when_data_mode_then_blocks_without_preview_leak(
        self,
        tmp_path: Path,
        capsys: pytest.CaptureFixture[str],
        category: str,
        payload: str,
        fragment: str,
    ) -> None:
        # Arrange
        target = tmp_path / "notes.md"
        target.write_text(f"{payload}\n", encoding="utf-8")

        # Act
        exit_code, report = _invoke(["--data", str(target)], capsys)

        # Assert
        assert exit_code == scan_sensitive_content.EXIT_FAILURE
        matched = [finding for finding in report["findings"] if finding["category"] == category]
        assert matched, f"expected a {category} finding"
        for finding in matched:
            assert finding["match"] == scan_sensitive_content.REDACTED_PREVIEW
            assert isinstance(finding["length"], int)
        assert fragment not in json.dumps(report)

    @pytest.mark.parametrize(
        "payload",
        [
            'api_key = "YOUR_API_KEY_HERE"',
            "password: xxxxxxxxxxxxxxxx",
            "client_secret = <REPLACE_WITH_SECRET>",
            "token = CHANGEME_CHANGEME_CH",
        ],
    )
    def test_given_placeholder_value_when_data_mode_then_no_finding(
        self,
        tmp_path: Path,
        capsys: pytest.CaptureFixture[str],
        payload: str,
    ) -> None:
        # Arrange
        target = tmp_path / "docs.md"
        target.write_text(f"{payload}\n", encoding="utf-8")

        # Act
        exit_code, report = _invoke(["--data", str(target)], capsys)

        # Assert
        assert exit_code == scan_sensitive_content.EXIT_SUCCESS
        categories = {finding["category"] for finding in report["findings"]}
        assert "generic_secret_assignment" not in categories

    def test_given_secret_bearing_categories_when_scanned_then_never_preview_content(
        self,
        tmp_path: Path,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange
        denylist = tmp_path / "terms.txt"
        denylist.write_text("tenant-synthetica\n", encoding="utf-8")
        target = tmp_path / "mixed.md"
        target.write_text(
            "tenant-synthetica\n"
            "Server=synthetichost;Initial Catalog=orders;Password=synthetic\n"
            "url: postgres://user:syntheticpass@db/orders\n"
            "AccountKey=c3ludGhldGljc3ludGhldGljMDAw\n"
            "Authorization: Bearer syntheticbearervalue\n",
            encoding="utf-8",
        )

        # Act
        exit_code, report = _invoke(["--data", "--denylist", str(denylist), str(target)], capsys)

        # Assert
        assert exit_code == scan_sensitive_content.EXIT_FAILURE
        serialized = json.dumps(report)
        assert "synthetic" not in serialized
        for finding in report["findings"]:
            if finding["category"] in scan_sensitive_content.NO_PREVIEW_CATEGORIES:
                assert finding["match"] == scan_sensitive_content.REDACTED_PREVIEW


class TestHeuristicNarrowing:
    @pytest.mark.parametrize(
        ("content", "expected"),
        [
            ("Address: see the runbook", False),
            ("address:", True),
            ("address: string", True),
            ("Postal: the mail room forwards these", False),
        ],
    )
    def test_given_key_value_line_when_data_mode_then_prose_is_not_a_column(
        self,
        tmp_path: Path,
        capsys: pytest.CaptureFixture[str],
        content: str,
        expected: bool,
    ) -> None:
        # Arrange
        target = tmp_path / "schema.md"
        target.write_text(content + "\n", encoding="utf-8")

        # Act
        _, report = _invoke(["--data", str(target)], capsys)

        # Assert
        categories = {finding["category"] for finding in report["findings"]}
        assert ("sensitive_column_name" in categories) is expected

    def test_given_table_separator_row_when_data_mode_then_no_sample_finding(
        self,
        tmp_path: Path,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange
        target = tmp_path / "catalog.md"
        target.write_text("## Sample rows\n\n|---|---|\n|:--|--:|\n", encoding="utf-8")

        # Act
        exit_code, report = _invoke(["--data", str(target)], capsys)

        # Assert
        assert exit_code == scan_sensitive_content.EXIT_SUCCESS
        assert not [finding for finding in report["findings"] if finding["category"] == "sample_row"]

    def test_given_distant_json_array_when_data_mode_then_sample_context_expired(
        self,
        tmp_path: Path,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange
        target = tmp_path / "catalog.md"
        target.write_text(
            "## Sample rows\n" + ("Narrative paragraph about the decision.\n" * 100) + '["unrelated", "array"]\n',
            encoding="utf-8",
        )

        # Act
        exit_code, report = _invoke(["--data", str(target)], capsys)

        # Assert
        assert exit_code == scan_sensitive_content.EXIT_SUCCESS
        assert not [finding for finding in report["findings"] if finding["category"] == "sample_row"]

    def test_given_blank_line_after_rows_when_data_mode_then_context_closes(
        self,
        tmp_path: Path,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange
        target = tmp_path / "catalog.md"
        target.write_text(
            "## Sample rows\n\n| id | value |\n| 1 | synthetic |\n\n[1, 2, 3]\n",
            encoding="utf-8",
        )

        # Act
        _, report = _invoke(["--data", str(target)], capsys)

        # Assert
        sample_lines = [finding["line"] for finding in report["findings"] if finding["category"] == "sample_row"]
        assert sample_lines == [3, 4]

    def test_given_url_with_query_when_not_sas_shaped_then_no_finding(
        self,
        tmp_path: Path,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange
        target = tmp_path / "adr.md"
        target.write_text("See https://learn.microsoft.com/azure?view=latest for guidance.\n", encoding="utf-8")

        # Act
        exit_code, report = _invoke(["--data", str(target)], capsys)

        # Assert
        assert exit_code == scan_sensitive_content.EXIT_SUCCESS
        categories = {finding["category"] for finding in report["findings"]}
        assert "sas_token" not in categories
