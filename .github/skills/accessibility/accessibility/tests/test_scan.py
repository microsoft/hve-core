# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from __future__ import annotations

from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

import pytest
import scan


def test_given_parser_when_target_and_output_provided_then_arguments_are_parsed() -> (
    None
):
    parser = scan.create_parser()

    args = parser.parse_args(
        [
            "https://example.com",
            "--output",
            "report.json",
            "--allow-host",
            "example.com",
        ]
    )

    assert args.target == "https://example.com"
    assert args.output == Path("report.json")
    assert args.allow_host == ["example.com"]


@pytest.mark.parametrize(
    ("raw_results", "expected_violation_ids"),
    [
        (
            {
                "violations": [
                    {
                        "id": "color-contrast",
                        "impact": "serious",
                        "description": "Text contrast must be sufficient",
                        "nodes": [{"target": ["#btn"]}],
                    }
                ],
                "passes": [{"id": "passthrough"}],
                "incomplete": [{"id": "incomplete"}],
                "inapplicable": [{"id": "inapplicable"}],
            },
            ["color-contrast"],
        ),
        (
            {
                "results": [
                    {
                        "violations": [
                            {
                                "id": "link-name",
                                "impact": "minor",
                                "description": "Links must have discernible names",
                                "nodes": [{"target": ["a"]}],
                            }
                        ]
                    }
                ]
            },
            ["link-name"],
        ),
    ],
)
def test_given_raw_results_when_normalize_results_then_returns_stable_shape(
    raw_results: dict[str, object],
    expected_violation_ids: list[str],
) -> None:
    normalized = scan.normalize_results(raw_results, target="https://example.com")

    assert normalized["target"] == "https://example.com"
    assert normalized["summary"]["violations"] == len(expected_violation_ids)
    assert [
        violation["id"] for violation in normalized["violations"]
    ] == expected_violation_ids
    assert normalized["violations"][0]["nodes"] == 1


def test_given_scanner_unavailable_when_run_scan_then_raises_actionable_error() -> None:
    with patch("scan.subprocess.run", side_effect=FileNotFoundError("npx")):
        with pytest.raises(scan.ScriptError, match="Node-based axe scanner"):
            scan.run_scan("http://127.0.0.1:3000")


def test_given_target_when_run_scan_then_invokes_scanner_with_list_arguments() -> None:
    with patch("scan.subprocess.run") as mock_run:
        mock_run.return_value = SimpleNamespace(
            returncode=0,
            stdout='{"violations": []}',
            stderr="",
        )

        result = scan.run_scan("https://example.com", allow_hosts=["example.com"])

    assert result["summary"]["violations"] == 0
    command = mock_run.call_args.args[0]
    assert command[0] == "npx"
    assert command[1:3] == ["--yes", "@axe-core/cli@4.12.1"]
    assert command[-2:] == ["--", "https://example.com"]


def test_given_regular_local_file_when_resolve_scan_target_then_returns_file_uri(
    tmp_path: Path,
) -> None:
    target = tmp_path / "page with space.html"
    target.write_text("<h1>Local</h1>", encoding="utf-8")

    resolved = scan.resolve_scan_target(str(target))

    assert resolved == target.resolve().as_uri()


def test_given_local_file_uri_when_resolve_scan_target_then_preserves_local_access(
    tmp_path: Path,
) -> None:
    target = tmp_path / "page.html"
    target.write_text("<h1>Local</h1>", encoding="utf-8")

    resolved = scan.resolve_scan_target(target.resolve().as_uri())

    assert resolved == target.resolve().as_uri()


def test_given_allowlisted_remote_url_when_resolve_scan_target_then_succeeds() -> None:
    target = "https://docs.example.com/page"

    resolved = scan.resolve_scan_target(target, allow_hosts=["*.example.com"])

    assert resolved == target


@pytest.mark.parametrize(
    ("target", "message"),
    [
        ("-target", "must not begin"),
        ("//example.com/page", "protocol-relative"),
        (r"\\server\share\page.html", "Network-share"),
        ("ftp://example.com/page", "Unsupported"),
        ("https://user:password@example.com", "credentials"),
        ("https://example.com:invalid", "invalid port"),
        ("file://server/share/page.html", "Remote file authorities"),
        ("missing-page.html", "does not exist"),
    ],
)
def test_given_unsafe_target_when_resolve_scan_target_then_rejects(
    target: str,
    message: str,
) -> None:
    with pytest.raises(scan.ScriptError, match=message):
        scan.resolve_scan_target(target, allow_external=True)


def test_given_external_target_without_authorization_when_resolve_then_rejects() -> (
    None
):
    with pytest.raises(scan.ScriptError, match="--allow-host HOST"):
        scan.resolve_scan_target("https://example.com/page")


@pytest.mark.parametrize(
    "target",
    [
        "file:////attacker.example/share/page.html",
        "file://localhost//attacker.example/share/page.html",
    ],
)
def test_given_unc_file_uri_when_resolve_then_rejects_before_network_probe(
    target: str,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    probes: list[str] = []
    original_exists = Path.exists

    def _record_exists(self: Path) -> bool:
        probes.append(str(self))
        return original_exists(self)

    monkeypatch.setattr(Path, "exists", _record_exists)

    with pytest.raises(scan.ScriptError, match="Network-share"):
        scan.resolve_scan_target(target, allow_external=True)

    assert not any(scan._is_network_path(Path(probe)) for probe in probes)


def test_given_unc_path_when_canonical_local_file_then_rejects_without_probe(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    probes: list[str] = []

    def _record_exists(self: Path) -> bool:
        probes.append(str(self))
        return True

    monkeypatch.setattr(Path, "exists", _record_exists)

    with pytest.raises(scan.ScriptError, match="Network-share"):
        scan._canonical_local_file(Path(r"\\attacker.example\share\page.html"))

    assert probes == []
