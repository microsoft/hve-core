# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Tests for `scripts.scan_sensitive_content`.

Covers high-confidence true positives (tokens, keys, internal URLs), benign
ADR prose true negatives, the warn-only email contract, and the external-sink
gating contract that non-zero exit accompanies any high-confidence finding.
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
        ("category", "secret"),
        [
            ("github_token", "ghp_" + "a" * 36),
            ("github_token", "github_pat_" + "A1b2C3d4E5f6G7h8I9j0K1"),
            ("aws_access_key", "AKIAIOSFODNN7EXAMPLE"),
            ("google_api_key", "AIza" + "B" * 35),  # gitleaks:allow
            ("slack_token", "xoxb-123456789012-abcdefABCDEF"),
            ("openai_api_key", "sk-" + "X" * 40),
            (
                "private_key",
                "-----BEGIN RSA PRIVATE KEY-----",
            ),
        ],
    )
    def test_given_secret_when_scan_then_high_finding_and_nonzero_exit(
        self,
        tmp_path: Path,
        category: str,
        secret: str,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange
        target = tmp_path / "adr.md"
        target.write_text(f"Context references {secret} in deployment.\n", encoding="utf-8")

        # Act
        exit_code, report = _invoke([str(target)], capsys)

        # Assert
        assert exit_code == scan_sensitive_content.EXIT_FAILURE
        categories = {f["category"] for f in report["findings"]}
        assert category in categories
        assert report["summary"]["high"] >= 1
        # The raw secret must not be echoed back verbatim (redaction contract).
        assert secret not in json.dumps(report)


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


class TestScanWarnOnly:
    def test_given_email_when_scan_then_warn_finding_and_zero_exit(
        self,
        tmp_path: Path,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange
        target = tmp_path / "adr.md"
        target.write_text("Contact alice@example.com for context.\n", encoding="utf-8")

        # Act
        exit_code, report = _invoke([str(target)], capsys)

        # Assert
        assert exit_code == scan_sensitive_content.EXIT_SUCCESS
        assert report["summary"]["warn"] >= 1
        assert report["summary"]["high"] == 0


class TestScanStdin:
    def test_given_secret_on_stdin_when_scan_then_nonzero_exit(
        self,
        monkeypatch: pytest.MonkeyPatch,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Arrange
        import io

        secret = "ghp_" + "z" * 36
        monkeypatch.setattr("sys.stdin", io.StringIO(f"token: {secret}\n"))

        # Act
        exit_code, report = _invoke([], capsys)

        # Assert
        assert exit_code == scan_sensitive_content.EXIT_FAILURE
        assert report["summary"]["high"] >= 1
        assert report["findings"][0]["source"] == scan_sensitive_content.STDIN_SOURCE


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
        exit_code, _ = _invoke([adversarial], capsys)

        # Assert
        assert exit_code == scan_sensitive_content.EXIT_ERROR
