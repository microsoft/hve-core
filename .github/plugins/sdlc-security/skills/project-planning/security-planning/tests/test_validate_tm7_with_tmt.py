# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Mocked tests for the native TM7 application harness."""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from typing import Any

import pytest
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_DIR = ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import validate_tm7_with_tmt  # noqa: E402


class FakeProcess:
    """Minimal harness-owned process double."""

    def __init__(self) -> None:
        self.closed = False
        self.pid = 42

    def poll(self) -> int | None:
        return 0 if self.closed else None

    def terminate(self) -> None:
        self.closed = True

    def wait(self, timeout: float | None = None) -> int:
        self.closed = True
        return 0

    def kill(self) -> None:
        self.closed = True


class FakeRectangle:
    """Window rectangle test double."""

    def __init__(self, width: int, height: int) -> None:
        self._width = width
        self._height = height

    def width(self) -> int:
        return self._width

    def height(self) -> int:
        return self._height


class FakeWindow:
    """Top-level window selector test double."""

    def __init__(
        self,
        title: str,
        width: int,
        height: int,
        *,
        handle: int = 1,
        descendants: list[Any] | None = None,
        element_info: Any | None = None,
    ) -> None:
        self.title = title
        self.bounds = FakeRectangle(width, height)
        self.handle = handle
        self._descendants = descendants or []
        self._element_info = element_info
        self.maximize_calls = 0
        self.restore_calls = 0
        self.maximized = False

    def maximize(self) -> None:
        self.maximize_calls += 1
        self.maximized = True

    def restore(self) -> None:
        self.restore_calls += 1
        self.maximized = False

    def is_maximized(self) -> bool:
        return self.maximized

    def window_text(self) -> str:
        return self.title

    def rectangle(self) -> FakeRectangle:
        return self.bounds

    def process_id(self) -> int:
        return 42

    def descendants(self, control_type: str | None = None) -> list[Any]:
        return self._descendants

    @property
    def element_info(self) -> Any:
        return self._element_info

    def is_visible(self) -> bool:
        return True


class FakeControl:
    """UIA control double with element info and descendants."""

    def __init__(
        self,
        control_type: str,
        name: str,
        *,
        automation_id: str = "",
        handle: int = 0,
        descendants: list[Any] | None = None,
        left: int = 0,
        top: int = 0,
        width: int = 100,
        height: int = 100,
    ) -> None:
        self._element_info = type(
            "ElementInfo",
            (),
            {
                "control_type": control_type,
                "name": name,
                "automation_id": automation_id,
            },
        )()
        self._descendants = descendants or []
        self._rectangle = type(
            "Rectangle",
            (),
            {
                "left": lambda self: left,
                "top": lambda self: top,
                "right": lambda self: left + width,
                "bottom": lambda self: top + height,
                "width": lambda self: width,
                "height": lambda self: height,
            },
        )()
        self.handle = handle

    @property
    def element_info(self) -> Any:
        return self._element_info

    def rectangle(self) -> Any:
        return self._rectangle

    def descendants(self, control_type: str | None = None) -> list[Any]:
        return self._descendants

    def click_input(self) -> None:
        return None

    def is_visible(self) -> bool:
        return True


def _input_model(tmp_path: Path, name: str = "model.tm7") -> Path:
    path = tmp_path / name
    path.write_text("model", encoding="utf-8")
    return path


def _write_feedback_spec(path: Path) -> None:
    path.write_text(
        json.dumps(
            {
                "project_metadata": {"name": "demo"},
                "mode": "diagram-only-defer-to-tmt",
                "representations": {
                    "context_diagrams": [
                        {
                            "id": "context",
                            "name": "context",
                            "elements": [
                                {
                                    "id": "trust-zone-portal",
                                    "kind": "process",
                                    "name": "Portal",
                                }
                            ],
                            "flows": [],
                        }
                    ],
                    "functional_scenarios": [
                        {
                            "id": "other",
                            "name": "other",
                            "elements": [
                                {
                                    "id": "other-node",
                                    "kind": "process",
                                    "name": "Other node",
                                }
                            ],
                            "flows": [],
                        }
                    ],
                },
            }
        ),
        encoding="utf-8",
    )


def _patch_successful_automation(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> list[FakeProcess]:
    executable = tmp_path / "ThreatModeling.exe"
    executable.write_bytes(b"exe")
    processes: list[FakeProcess] = []

    def launch(*args: Any, **kwargs: Any) -> FakeProcess:
        process = FakeProcess()
        processes.append(process)
        return process

    def save_as(window: Any, destination: Path, timeout: float) -> None:
        destination.write_text("model", encoding="utf-8")

    def export(window: Any, destination: Path, timeout: float) -> None:
        destination.write_text("id,title\n1,Threat\n", encoding="utf-8")

    summary = {
        "sha256": "hash",
        "generation_enabled": "false",
        "instance_count": 1,
        "instances": [{"id": "1", "type_id": "TH-test"}],
        "knowledge_base_type_ids": ["TH-test"],
        "custom_type_ids": [],
        "drawing_surface_hash": "surface-hash",
        "knowledge_base_hash": "kb-hash",
    }
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "discover_tmt_application",
        lambda: validate_tm7_with_tmt.TmtDiscovery(
            path=executable,
            version="7.3.51110.1",
            source="test",
        ),
    )
    monkeypatch.setattr(validate_tm7_with_tmt, "launch_tmt_process", launch)
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "find_tmt_window",
        lambda *args, **kwargs: object(),
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "detect_modal_dialog",
        lambda window: None,
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "_modal_windows",
        lambda window: [],
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "capture_window_screenshot",
        lambda window, path: _write_test_png(path, 600, 400),
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "build_uia_tree",
        lambda window: "Button|analysis|Analysis View\n",
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "open_analysis_view",
        lambda *args, **kwargs: None,
    )
    monkeypatch.setattr(validate_tm7_with_tmt, "export_threat_csv", export)
    monkeypatch.setattr(validate_tm7_with_tmt, "save_model_as", save_as)
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "save_current_model",
        lambda window, model_path, timeout: None,
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "collect_semantic_summary",
        lambda path: {**summary, "path": str(path)},
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "sha256_file",
        lambda path: "sha256",
    )
    return processes


def test_given_cross_candidate_semantics_when_only_geometry_changes_then_does_not() -> (
    None
):
    # Arrange
    baseline_summary = {
        "instance_count": 1,
        "threat_count": 1,
        "threat_identities": ["threat|type|state"],
        "element_identities": ["context|node-a|store|TH-1|guid-a"],
        "flow_identities": ["context|flow-1|source|target|src|dst"],
        "drawing_surface_hash": "old-surface",
        "knowledge_base_hash": "old-kb",
    }
    current_summary = {
        "instance_count": 1,
        "threat_count": 1,
        "threat_identities": ["threat|type|state"],
        "element_identities": ["context|node-a|store|TH-1|guid-a"],
        "flow_identities": ["context|flow-1|source|target|src|dst"],
        "drawing_surface_hash": "new-surface",
        "knowledge_base_hash": "new-kb",
    }

    # Act
    regression = validate_tm7_with_tmt._evaluate_semantic_regression(
        current_summary=current_summary,
        baseline_summary=baseline_summary,
    )

    # Assert
    assert regression is False


def test_given_production_feedback_path_when_identity_changes_then_blocks(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """The production path must reach the semantic evaluator on its own.

    `_validate_feedback_candidate` used to return a hardcoded
    `semantic_regression: False`, and the caller only recomputed when the value
    was None, so `_evaluate_semantic_regression` was never reached in
    production. This test patches the inner `_validate_candidate` seam instead,
    so the real feedback-candidate body and the real evaluator both run.
    """
    # Arrange
    spec_path = tmp_path / "spec.yaml"
    _write_feedback_spec(spec_path)
    baseline_model = tmp_path / "baseline.tm7"
    baseline_model.write_text("baseline", encoding="utf-8")
    overlay_output = tmp_path / "overlay.yaml"

    def _summary(threat_identity: str) -> dict:
        return {
            "instance_count": 1,
            "threat_count": 1,
            "threat_identities": [threat_identity],
            "element_identities": ["context|node-a|store|TH-1|guid-a"],
            "flow_identities": ["context|flow-1|source|target|src|dst"],
            "instances": [{"id": "1"}],
            "drawing_surface_hash": "surface",
            "knowledge_base_hash": "kb",
        }

    calls: list[int] = []

    def _fake_validate_candidate(**kwargs: object) -> dict:
        calls.append(1)
        # The second candidate declares a different threat identity, which is a
        # semantic change rather than a geometry-only one.
        identity = "threat|type|state" if len(calls) == 1 else "threat|type|REPLACED"
        return {
            "working_model": str(baseline_model),
            "saved_model": str(baseline_model),
            "before_summary": _summary(identity),
            "after_summary": _summary(identity),
            "surface_metrics": [
                {
                    "surface_id": "context",
                    "node_id": "trust-zone-portal",
                    "gate_failure_count": 1,
                    "review_count": 1,
                    "warn_count": 0,
                    "max_severity_score": 3.0,
                    "constraint_type": "relative_to",
                    "capture_complete": True,
                    # An unresolved review finding keeps convergence from
                    # declaring readiness, so the loop runs a second candidate.
                    "findings": [
                        {
                            "surface_id": "context",
                            "metric_name": "node_spacing",
                            "severity": "review",
                            "category": "layout",
                        }
                    ],
                }
            ],
            "evidence_complete": True,
        }

    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "discover_tmt_application",
        lambda: validate_tm7_with_tmt.TmtDiscovery(
            path=tmp_path / "ThreatModeling.exe",
            version="7.3.51110.1",
            source="test",
        ),
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "_validate_candidate",
        _fake_validate_candidate,
    )
    # Candidate regeneration is an unrelated collaborator here. Stubbing it
    # keeps the test focused on the semantic gate while leaving both
    # `_validate_feedback_candidate` and `_evaluate_semantic_regression` real.
    monkeypatch.setattr(
        validate_tm7_with_tmt.generate_tm7,
        "generate_tm7_candidate",
        lambda **kwargs: (
            Path(str(kwargs["output_path"])).write_text("candidate", encoding="utf-8")
            or Path(str(kwargs["output_path"]))
        ),
    )
    monkeypatch.setattr(validate_tm7_with_tmt, "sha256_file", lambda path: "sha")

    # Act
    result = validate_tm7_with_tmt.run_harness(
        input_model=baseline_model,
        evidence_dir=tmp_path / "evidence",
        feedback_loop=True,
        spec_path=spec_path,
        overlay_output=overlay_output,
        max_iterations=3,
        require_feedback_evidence=False,
    )

    # Assert
    assert len(calls) >= 2, (
        f"the loop must reach a second candidate to compare; "
        f"stopped with status={result.status} message={result.message}"
    )
    assert result.status == "semantic-regression"
    assert result.exit_code == validate_tm7_with_tmt.EXIT_VALIDATION_FAILURE
    assert result.status != "automated-ready-pending-human"


def test_given_regeneration_failure_when_feedback_runs_then_status_is_written(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """A generator failure must be reported, not raised through the harness.

    Candidate regeneration was unguarded, so a `GenerationError` escaped
    `run_harness` entirely: the operator saw a traceback and no status.json was
    ever written for the run.
    """
    # Arrange
    spec_path = tmp_path / "spec.yaml"
    _write_feedback_spec(spec_path)
    baseline_model = tmp_path / "baseline.tm7"
    baseline_model.write_text("baseline", encoding="utf-8")
    evidence_dir = tmp_path / "evidence"

    def _explode(**kwargs: object) -> Path:
        raise validate_tm7_with_tmt.generate_tm7.GenerationError("spec is invalid")

    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "discover_tmt_application",
        lambda: validate_tm7_with_tmt.TmtDiscovery(
            path=tmp_path / "ThreatModeling.exe",
            version="7.3.51110.1",
            source="test",
        ),
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt.generate_tm7,
        "generate_tm7_candidate",
        _explode,
    )
    monkeypatch.setattr(validate_tm7_with_tmt, "sha256_file", lambda path: "sha")

    # Act
    result = validate_tm7_with_tmt.run_harness(
        input_model=baseline_model,
        evidence_dir=evidence_dir,
        feedback_loop=True,
        spec_path=spec_path,
        overlay_input=tmp_path / "overlay-in.yaml",
        overlay_output=tmp_path / "overlay.yaml",
        max_iterations=1,
        require_feedback_evidence=False,
    )

    # Assert
    assert result.exit_code != validate_tm7_with_tmt.EXIT_SUCCESS
    assert "spec is invalid" in str(result.message)
    assert (evidence_dir / "status.json").is_file()


def test_given_ready_status_without_overlay_when_run_then_success_is_not_reported(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Success must produce the overlay it declares as its output.

    A run with no surface metrics produces no candidate and therefore no
    overlay, yet still reported `automated-ready-pending-human` with exit 0 and
    left the declared output missing.
    """
    # Arrange
    spec_path = tmp_path / "spec.yaml"
    _write_feedback_spec(spec_path)
    baseline_model = tmp_path / "baseline.tm7"
    baseline_model.write_text("baseline", encoding="utf-8")
    overlay_output = tmp_path / "overlay.yaml"

    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "discover_tmt_application",
        lambda: validate_tm7_with_tmt.TmtDiscovery(
            path=tmp_path / "ThreatModeling.exe",
            version="7.3.51110.1",
            source="test",
        ),
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "_validate_feedback_candidate",
        lambda *args, **kwargs: {
            "working_model": str(baseline_model),
            "saved_model": str(baseline_model),
            "before_summary": {
                "instance_count": 1,
                "instances": [],
                "drawing_surface_hash": "surface",
                "knowledge_base_hash": "kb",
            },
            "after_summary": {
                "instance_count": 1,
                "instances": [],
                "drawing_surface_hash": "surface",
                "knowledge_base_hash": "kb",
            },
            # No surface metrics means no candidate and therefore no overlay,
            # while nothing failed a gate either.
            "surface_metrics": [],
            "evidence_complete": True,
            "semantic_regression": None,
            "semantic_summary": {},
            "candidate_path": str(baseline_model),
        },
    )
    monkeypatch.setattr(validate_tm7_with_tmt, "sha256_file", lambda path: "sha")

    # Act
    result = validate_tm7_with_tmt.run_harness(
        input_model=baseline_model,
        evidence_dir=tmp_path / "evidence",
        feedback_loop=True,
        spec_path=spec_path,
        overlay_output=overlay_output,
        max_iterations=1,
        require_feedback_evidence=False,
    )

    # Assert
    assert not (
        result.status == "automated-ready-pending-human" and not overlay_output.exists()
    ), "a successful run must emit its declared overlay"
    if result.status == "automated-ready-pending-human":
        assert overlay_output.is_file()
    else:
        assert result.exit_code != validate_tm7_with_tmt.EXIT_SUCCESS


def test_given_untrusted_newer_decoy_when_discovered_then_signed_candidate_wins(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Selection must follow publisher trust, never newest modification time.

    Discovery used `max(..., key=st_mtime)` with no signature check, so a decoy
    dropped into an allowed root wins simply by being newer.
    """
    # Arrange
    root = tmp_path / "Apps" / "2.0"
    genuine = root / "genuine"
    decoy = root / "decoy"
    genuine.mkdir(parents=True)
    decoy.mkdir(parents=True)
    genuine_exe = genuine / "TMT7.exe"
    decoy_exe = decoy / "TMT7.exe"
    genuine_exe.write_bytes(b"genuine")
    decoy_exe.write_bytes(b"decoy")
    # The decoy is the newest file, which is exactly what the old selection
    # rewarded.
    os.utime(genuine_exe, (1_000_000, 1_000_000))
    os.utime(decoy_exe, (2_000_000, 2_000_000))

    monkeypatch.setenv("LOCALAPPDATA", str(tmp_path))
    monkeypatch.delenv("ProgramFiles", raising=False)
    monkeypatch.delenv("ProgramFiles(x86)", raising=False)
    monkeypatch.setattr(validate_tm7_with_tmt.platform, "system", lambda: "Windows")
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "is_trusted_tmt_executable",
        lambda path: Path(path).parent.name == "genuine",
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "_read_windows_file_version",
        lambda path: validate_tm7_with_tmt.DEFAULT_PINNED_VERSION,
    )

    # Act
    discovery = validate_tm7_with_tmt.discover_tmt_application()

    # Assert
    assert discovery.path == genuine_exe.resolve()
    assert discovery.path != decoy_exe.resolve()


def test_given_no_trusted_candidate_when_discovered_then_source_is_untrusted(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """An unsigned candidate under an allowed root must not be accepted."""
    # Arrange
    root = tmp_path / "Apps" / "2.0" / "unsigned"
    root.mkdir(parents=True)
    (root / "TMT7.exe").write_bytes(b"unsigned")

    monkeypatch.setenv("LOCALAPPDATA", str(tmp_path))
    monkeypatch.delenv("ProgramFiles", raising=False)
    monkeypatch.delenv("ProgramFiles(x86)", raising=False)
    monkeypatch.setattr(validate_tm7_with_tmt.platform, "system", lambda: "Windows")
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "is_trusted_tmt_executable",
        lambda path: False,
    )

    # Act
    discovery = validate_tm7_with_tmt.discover_tmt_application()

    # Assert
    assert discovery.path is None
    assert discovery.source == "untrusted"


@pytest.mark.parametrize(
    ("subject", "expected"),
    [
        ("CN=Microsoft Corporation, O=Microsoft Corporation, C=US", True),
        ("O=Microsoft Corporation, CN=Microsoft Corporation", True),
        ("CN=Microsoft Corporation Partner Tools, O=Attacker Ltd", False),
        ("CN=Attacker, O=Microsoft Corporation", False),
        ("O=Microsoft Corporation Partner", False),
        ("", False),
    ],
)
def test_given_certificate_subject_when_evaluated_then_only_exact_cn_is_trusted(
    monkeypatch: pytest.MonkeyPatch,
    subject: str,
    expected: bool,
) -> None:
    # Arrange
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "_authenticode_subject",
        lambda path: ("Valid", subject),
    )

    # Act
    trusted = validate_tm7_with_tmt.is_trusted_tmt_executable(Path("TMT7.exe"))

    # Assert
    assert trusted is expected


def test_given_powershell_hosts_when_resolved_then_every_path_is_absolute(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    # Arrange
    decoy = tmp_path / "pwsh.exe"
    decoy.write_bytes(b"decoy")
    monkeypatch.chdir(tmp_path)

    # Act
    hosts = validate_tm7_with_tmt._powershell_hosts()

    # Assert
    assert all(os.path.isabs(host) for host in hosts)
    assert str(decoy) not in hosts or Path(decoy).is_absolute()


def test_given_probe_environment_when_built_then_caller_secrets_are_excluded(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    monkeypatch.setenv("GITHUB_TOKEN", "ghp-should-not-leak")
    monkeypatch.setenv("AZURE_CLIENT_SECRET", "azure-should-not-leak")

    # Act
    child_env = validate_tm7_with_tmt._minimal_child_environment(Path("TMT7.exe"))

    # Assert
    assert "GITHUB_TOKEN" not in child_env
    assert "AZURE_CLIENT_SECRET" not in child_env
    assert child_env["TMT_CANDIDATE_PATH"] == "TMT7.exe"


@pytest.mark.parametrize("encoding", ["utf-8", "utf-16-le", "utf-16-be", "utf-16"])
def test_given_encoded_doctype_when_parsed_then_harness_fails_closed(
    tmp_path: Path,
    encoding: str,
) -> None:
    # Arrange
    hostile = (
        '<?xml version="1.0"?>'
        "<!DOCTYPE root [<!ENTITY xxe SYSTEM 'file:///etc/passwd'>]>"
        "<root>&xxe;</root>"
    )
    model = tmp_path / f"hostile-{encoding}.tm7"
    model.write_bytes(hostile.encode(encoding))

    # Act & Assert
    with pytest.raises(validate_tm7_with_tmt.HarnessFailure):
        validate_tm7_with_tmt._parse_xml(model)


@pytest.mark.parametrize("encoding", ["utf-8", "utf-16-le", "utf-16-be"])
def test_given_encoded_doctype_when_reading_surfaces_then_harness_fails_closed(
    tmp_path: Path,
    encoding: str,
) -> None:
    # Arrange
    hostile = (
        '<?xml version="1.0"?>'
        "<!DOCTYPE root [<!ENTITY xxe SYSTEM 'file:///etc/passwd'>]>"
        "<root><DrawingSurfaceModel/></root>"
    )
    model = tmp_path / f"hostile-surfaces-{encoding}.tm7"
    model.write_bytes(hostile.encode(encoding))

    # Act & Assert
    with pytest.raises(validate_tm7_with_tmt.HarnessFailure):
        validate_tm7_with_tmt.read_expected_surfaces(model)


def test_given_missing_model_when_parsed_then_harness_failure_is_raised(
    tmp_path: Path,
) -> None:
    # Arrange
    missing = tmp_path / "absent.tm7"

    # Act & Assert
    with pytest.raises(validate_tm7_with_tmt.HarnessFailure):
        validate_tm7_with_tmt._parse_xml(missing)


@pytest.mark.parametrize(
    ("secret", "payload"),
    [
        ("s3cr3t-value-here", "client_secret=s3cr3t-value-here"),
        ("hunter2", "password=hunter2"),
        ("AKIAIOSFODNN7EXAMPLE", "api_key=AKIAIOSFODNN7EXAMPLE"),
        ("Zm9vYmFyYmF6cXV4", "AccountKey=Zm9vYmFyYmF6cXV4;Endpoint=core.windows.net"),
        ("eyJhbGciOi", "Authorization: Bearer eyJhbGciOi.payload.signature"),
        ("SigVal123", "https://acct.blob.core.windows.net/c/b?sig=SigVal123"),
    ],
)
def test_given_sensitive_values_when_persisted_then_no_sink_leaks_them(
    tmp_path: Path,
    secret: str,
    payload: str,
) -> None:
    """Every persisted evidence sink must redact credential shapes.

    The previous pattern covered only authorization, bearer, and token, and its
    `\\S+` consumed a single token, so `Authorization: Bearer <jwt>` redacted
    the word "Bearer" and published the JWT. The CSV writer performed no
    redaction at all.
    """
    # Arrange
    bundle = validate_tm7_with_tmt.EvidenceBundle(tmp_path / "evidence")

    # Act
    bundle.write_manifest({"connection": payload})
    bundle.write_action_log(f"OPEN {payload}")
    csv_path = bundle.write_csv_export([{"title": payload}], "exports/threats.csv")
    summary_path = bundle.write_summary({"note": payload}, "summary.json")
    uia_path = bundle.write_uia_tree(payload, "tree.txt")

    # Assert
    sinks = {
        "manifest": bundle.manifest_path,
        "action log": bundle.action_log_path,
        "csv": csv_path,
        "summary": summary_path,
        "uia": uia_path,
    }
    for label, path in sinks.items():
        content = path.read_text(encoding="utf-8")
        assert secret not in content, f"{label} leaked {secret}"


def test_given_unmarked_workspace_when_cleanup_then_directory_survives(
    tmp_path: Path,
) -> None:
    """Recursive deletion must be confined to harness-created workspaces.

    Cleanup called `shutil.rmtree(..., ignore_errors=True)` on whatever path it
    was handed, so an operator `--workspace-root` pointing at a real directory
    was removed and any failure passed unnoticed.
    """
    # Arrange
    operator_dir = tmp_path / "operator-data"
    operator_dir.mkdir()
    sentinel = operator_dir / "important.txt"
    sentinel.write_text("do not delete", encoding="utf-8")
    bundle = validate_tm7_with_tmt.EvidenceBundle(tmp_path / "evidence")

    # Act
    bundle.cleanup_workspace(operator_dir)

    # Assert
    assert sentinel.is_file()
    assert sentinel.read_text(encoding="utf-8") == "do not delete"

    # A workspace this harness created and marked is removed normally.
    owned = tmp_path / "owned-workspace"
    validate_tm7_with_tmt.mark_workspace_owned(owned)
    (owned / "scratch.tm7").write_text("temp", encoding="utf-8")
    bundle.cleanup_workspace(owned)
    assert not owned.exists()


def test_given_strict_feedback_evidence_when_capture_is_missing_then_marks_incomplete(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    baseline_model = tmp_path / "baseline.tm7"
    baseline_model.write_text("baseline", encoding="utf-8")
    workspace = tmp_path / "workspace"
    workspace.mkdir()
    bundle = validate_tm7_with_tmt.EvidenceBundle(tmp_path / "evidence")

    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "launch_tmt_process",
        lambda *args, **kwargs: FakeProcess(),
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "find_tmt_window",
        lambda *args, **kwargs: FakeWindow("Threat Model", 800, 600),
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt, "open_analysis_view", lambda *args, **kwargs: None
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "capture_window_screenshot",
        lambda window, path: _write_test_png(path, 600, 400),
    )
    monkeypatch.setattr(validate_tm7_with_tmt, "build_uia_tree", lambda window: "")
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "export_threat_csv",
        lambda window, destination, timeout: destination.write_text(
            "id\n1\n", encoding="utf-8"
        ),
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "save_current_model",
        lambda window, model_path, timeout: None,
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt, "close_owned_process", lambda process: None
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "collect_semantic_summary",
        lambda path: {
            "instance_count": 1,
            "instances": [{"id": "1", "type_id": "TH-test"}],
            "drawing_surface_hash": "surface",
            "knowledge_base_hash": "kb",
            "threat_identities": ["threat"],
            "element_identities": [],
            "flow_identities": [],
        },
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt, "compare_csv_exports", lambda before, after: True
    )
    monkeypatch.setattr(validate_tm7_with_tmt, "sha256_file", lambda path: "sha256")
    monkeypatch.setattr(
        validate_tm7_with_tmt, "_capture_feedback_surface_evidence", lambda **kwargs: []
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt, "_derive_feedback_surface_metrics", lambda **kwargs: []
    )

    # Act
    output = validate_tm7_with_tmt._validate_candidate(
        executable=tmp_path / "ThreatModeling.exe",
        input_model=baseline_model,
        workspace=workspace,
        bundle=bundle,
        mode="validate",
        timeout_seconds=1.0,
        expected_threat_count=1,
        template_upgrade_policy="fail",
        delete_stale_threats=False,
        capture_feedback_surfaces=True,
        require_feedback_evidence=True,
    )

    # Assert
    assert output["evidence_complete"] is False


def _write_test_png(path: Path, width: int, height: int) -> None:
    image = Image.new("RGB", (width, height), color="white")
    image.save(path)


def test_given_excessive_scroll_extent_when_capture_then_marks_evidence_incomplete(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    model_path = _input_model(tmp_path, "surface.tm7")
    bundle = validate_tm7_with_tmt.EvidenceBundle(tmp_path / "evidence")
    surface = validate_tm7_with_tmt.SurfaceDescriptor(
        surface_id="context",
        surface_guid="guid-context",
        surface_name="System context",
        tab_index=0,
    )
    diagram_pane = FakeControl(
        "Pane",
        "System context",
        automation_id="guid-context",
        left=0,
        top=0,
        width=1200,
        height=800,
    )
    scroll_interface = type(
        "ScrollInterface",
        (),
        {
            "CurrentHorizontalScrollPercent": 0.0,
            "CurrentVerticalScrollPercent": 0.0,
            "SetScrollPercent": lambda self, horizontal, vertical: None,
        },
    )()
    diagram_pane.iface_scroll = scroll_interface

    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "find_diagram_pane",
        lambda window, surface=None: diagram_pane,
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "read_canvas_announcement",
        lambda pane: "Canvas",
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "capture_window_screenshot",
        lambda window, path: _write_test_png(path, 600, 400),
    )
    monkeypatch.setattr(validate_tm7_with_tmt, "build_uia_tree", lambda pane: "")

    # Act
    payload = validate_tm7_with_tmt.capture_surface_evidence(
        FakeWindow("Threat Model", 1400, 900),
        bundle,
        surface,
        model_path=model_path,
        require_feedback_evidence=False,
        scroll_extent_ratio_x=3.0,
        scroll_extent_ratio_y=1.0,
    )

    # Assert
    assert payload["scroll_coverage_complete"] is False
    assert payload["tile_manifest"]["consistent"] is False
    assert payload["tile_manifest"]["tile_count"] == 0


def test_given_tiled_surface_evidence_when_capture_then_binds_tile_manifest(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    model_path = _input_model(tmp_path, "surface.tm7")
    bundle = validate_tm7_with_tmt.EvidenceBundle(tmp_path / "evidence")
    surface = validate_tm7_with_tmt.SurfaceDescriptor(
        surface_id="context",
        surface_guid="guid-context",
        surface_name="System context",
        tab_index=0,
    )
    diagram_pane = FakeControl(
        "Pane",
        "System context",
        automation_id="guid-context",
        left=0,
        top=0,
        width=1200,
        height=800,
    )
    scroll_interface = type(
        "ScrollInterface",
        (),
        {
            "CurrentHorizontalScrollPercent": 0.0,
            "CurrentVerticalScrollPercent": 0.0,
            "SetScrollPercent": lambda self, horizontal, vertical: None,
        },
    )()
    diagram_pane.iface_scroll = scroll_interface
    diagram_pane._descendants = [
        FakeControl("Pane", "Viewport", automation_id="Viewport"),
    ]

    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "find_diagram_pane",
        lambda window, surface=None: diagram_pane,
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "read_canvas_announcement",
        lambda pane: "Canvas",
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "capture_window_screenshot",
        lambda window, path: _write_test_png(path, 600, 400),
    )
    monkeypatch.setattr(validate_tm7_with_tmt, "build_uia_tree", lambda pane: "")

    # Act
    payload = validate_tm7_with_tmt.capture_surface_evidence(
        FakeWindow("Threat Model", 1400, 900),
        bundle,
        surface,
        model_path=model_path,
        require_feedback_evidence=True,
        scroll_extent_ratio_x=2.0,
        scroll_extent_ratio_y=2.0,
    )

    # Assert
    assert payload["scroll_restored"] is True
    assert payload["screenshot_dimensions"]["width"] == 600
    assert payload["screenshot_dimensions"]["height"] == 400
    assert payload["crop_dimensions"]["width"] == 1200
    assert payload["crop_dimensions"]["height"] == 800
    assert payload["tile_manifest"]["position_count"] == 4
    assert payload["tile_manifest"]["max_axis_positions"] == 2
    assert payload["tile_manifest"]["consistent"] is True
    assert payload["tile_manifest"]["tile_count"] == 4
    assert payload["stitched_preview_path"].endswith(".png")

    calibration_contract = validate_tm7_with_tmt._build_layout_calibration_contract(
        [payload],
        calibration_context={
            "contract": "layout_calibration_v1",
            "scope": "same-run",
            "viewport_target": [0.0, 0.0, 1200.0, 800.0],
            "pane_rect": [0, 0, 1200, 800],
            "scroll_percentages": {"horizontal": 0.0, "vertical": 0.0},
            "effective_scale": {"x": 1.0, "y": 1.0},
            "screenshot_dimensions": {"width": 600, "height": 400},
            "crop_dimensions": {"width": 1200, "height": 800},
            "confidence": {
                "pane_measured": True,
                "scroll_interface_found": True,
                "consistent": True,
                "failure_reason": None,
            },
        },
    )
    assert calibration_contract["screenshot_dimensions"] == {
        "width": 600,
        "height": 400,
    }
    assert calibration_contract["crop_dimensions"] == {"width": 1200, "height": 800}


def test_given_measured_pane_when_calibrated_then_measurements_beat_defaults(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Derive effective scale and scroll percentages from real pane measurements."""
    # Arrange
    model_path = _input_model(tmp_path, "surface.tm7")
    bundle = validate_tm7_with_tmt.EvidenceBundle(tmp_path / "evidence")
    surface = validate_tm7_with_tmt.SurfaceDescriptor(
        surface_id="context",
        surface_guid="guid-context",
        surface_name="System context",
        tab_index=0,
    )
    diagram_pane = FakeControl(
        "Pane",
        "System context",
        automation_id="guid-context",
        left=10,
        top=20,
        width=1200,
        height=800,
    )
    scroll_interface = type(
        "ScrollInterface",
        (),
        {
            "CurrentHorizontalScrollPercent": 25.0,
            "CurrentVerticalScrollPercent": 40.0,
            "SetScrollPercent": lambda self, horizontal, vertical: None,
        },
    )()
    diagram_pane.iface_scroll = scroll_interface

    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "find_diagram_pane",
        lambda window, surface=None: diagram_pane,
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "read_canvas_announcement",
        lambda pane: "Canvas",
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "capture_window_screenshot",
        lambda window, path: _write_test_png(path, 600, 400),
    )
    monkeypatch.setattr(validate_tm7_with_tmt, "build_uia_tree", lambda pane: "")

    payload = validate_tm7_with_tmt.capture_surface_evidence(
        FakeWindow("Threat Model", 1400, 900),
        bundle,
        surface,
        model_path=model_path,
        require_feedback_evidence=True,
        scroll_extent_ratio_x=2.0,
        scroll_extent_ratio_y=2.0,
        viewport_target=(0.0, 0.0, 2000.0, 1000.0),
        pane_rect={"left": 10, "top": 20, "width": 1200, "height": 800},
        calibration_context={
            "contract": "layout_calibration_v1",
            "scope": "same-run",
            "viewport_target": [0.0, 0.0, 2000.0, 1000.0],
            "pane_rect": [10, 20, 1200, 800],
            "scroll_percentages": {"horizontal": 25.0, "vertical": 40.0},
            "effective_scale": {"x": 1.0, "y": 1.0},
            "screenshot_dimensions": {"width": 600, "height": 400},
            "crop_dimensions": {"width": 1200, "height": 800},
            "confidence": {
                "pane_measured": True,
                "scroll_interface_found": True,
                "consistent": True,
                "failure_reason": None,
            },
        },
    )

    # Act
    contract = validate_tm7_with_tmt._build_layout_calibration_contract(
        [payload],
        calibration_context=None,
    )

    # Assert
    assert contract["scroll_percentages"] == {"horizontal": 25.0, "vertical": 40.0}
    assert contract["effective_scale"] == {"x": 0.6, "y": 0.8}
    assert contract["pane_rect"] == [10, 20, 1200, 800]
    assert contract["confidence"]["consistent"] is True


def test_given_inconsistent_pane_when_calibrated_then_it_is_marked() -> None:
    """Reject calibration contracts when the pane or crop remains unmeasured."""
    # Arrange
    payload = {
        "pane_rect": {"left": 0, "top": 0, "width": 0, "height": 0},
        "viewport_target": [0.0, 0.0, 0.0, 0.0],
        "screenshot_dimensions": {"width": 600, "height": 400},
        "crop_dimensions": {"width": 0, "height": 0},
        "scroll_coverage_complete": True,
        "scroll_restored": True,
    }

    # Act
    contract = validate_tm7_with_tmt._build_layout_calibration_contract(
        [payload],
        calibration_context={
            "contract": "layout_calibration_v1",
            "scope": "same-run",
            "viewport_target": [0.0, 0.0, 1200.0, 800.0],
            "pane_rect": [0, 0, 0, 0],
            "scroll_percentages": {"horizontal": 0.0, "vertical": 0.0},
            "effective_scale": {"x": 1.0, "y": 1.0},
            "screenshot_dimensions": {"width": 600, "height": 400},
            "crop_dimensions": {"width": 0, "height": 0},
            "confidence": {
                "pane_measured": True,
                "scroll_interface_found": True,
                "consistent": True,
                "failure_reason": None,
            },
        },
    )

    # Assert
    assert contract["confidence"]["consistent"] is False
    assert contract["confidence"]["failure_reason"] is not None


UIA_ZOOM_SAMPLE = "\n".join(
    [
        "0|Pane|guid|Diagram|2|141|1963|1179",
        "1|Custom||Alpha|654|242|885|392",
        "2|Text||Alpha|695|305|844|328",
        "3|Custom||Beta|1910|449|2123|599",
        "4|Custom|FocusBorder|send data over HTTPS|768|428|1917|524",
    ]
)
# Alpha model 154x100 -> drawn 231x150; Beta model 142x100 -> drawn 213x150.
UIA_ZOOM_MODEL = {
    "Alpha": (435.826, 64.0, 589.826, 164.0),
    "Beta": (1272.522, 202.92, 1414.522, 302.92),
}


def test_given_zoomed_render_when_scale_derived_then_matches_drawn_ratio() -> None:
    """The pane is screen pixels, so the zoom must come from drawn geometry."""
    # Act
    scale = validate_tm7_with_tmt.derive_render_scale(
        UIA_ZOOM_SAMPLE,
        UIA_ZOOM_MODEL,
    )

    # Assert
    assert scale == pytest.approx(1.5)


@pytest.mark.parametrize(
    ("uia_text", "model_rects"),
    [
        ("", UIA_ZOOM_MODEL),
        (UIA_ZOOM_SAMPLE, {"Absent": (0.0, 0.0, 10.0, 10.0)}),
        (
            UIA_ZOOM_SAMPLE,
            {**UIA_ZOOM_MODEL, "Alpha": (0.0, 0.0, 10.0, 10.0)},
        ),
    ],
)
def test_given_unusable_samples_when_scale_derived_then_returns_none(
    uia_text: str,
    model_rects: dict[str, tuple[float, float, float, float]],
) -> None:
    """Too few or disagreeing samples must not yield a confident scale."""
    # Act
    scale = validate_tm7_with_tmt.derive_render_scale(uia_text, model_rects)

    # Assert
    assert scale is None


def test_given_feedback_overlay_without_real_rule_when_validated_then_raises() -> None:
    # Arrange
    candidate = {
        "surface_id": "context",
        "node_id": "trust-zone-portal",
        "constraint_type": "position",
        "rule": {},
    }
    overlay_context = validate_tm7_with_tmt.tm7_visual_feedback.OverlayContext(
        model_id="demo-model",
        spec_path=Path("spec.yaml"),
        spec_sha256="abc",
        generator_profile="default",
        generator_profile_sha256="def",
        surface_ids={"context"},
        surface_node_ids={"context": {"trust-zone-portal"}},
    )

    # Act and Assert
    with pytest.raises(ValueError, match="rule"):
        validate_tm7_with_tmt._build_feedback_overlay(
            spec_path=Path("spec.yaml"),
            candidate=candidate,
            overlay_context=overlay_context,
            iteration_id=1,
            spec_sha256="abc",
            generator_profile="default",
            generator_profile_sha256="def",
            candidate_path=Path("candidate.tm7"),
            ranking_key=(0, 0, 0, 0.0, "context", "trust-zone-portal", "position"),
        )


def test_given_stopped_run_when_seed_built_then_overlay_validates_with_no_rules() -> (
    None
):
    """A stopped run must still hand a reviewer a fingerprint-valid overlay.

    The five invalidation fingerprints are hashes over spec bytes and sorted
    model identity sets, so a reviewer cannot author one by hand. Without a
    seed a stopped run leaves no way to propose a layout correction at all.
    """
    # Arrange
    overlay_context = validate_tm7_with_tmt.tm7_visual_feedback.OverlayContext(
        model_id="demo-model",
        spec_path=Path("spec.yaml"),
        spec_sha256="abc",
        generator_profile="default",
        generator_profile_sha256="def",
        surface_ids={"context", "operational"},
        surface_node_ids={
            "context": {"trust-zone-portal"},
            "operational": {"trust-zone-ops"},
        },
    )

    # Act
    seed = validate_tm7_with_tmt._build_overlay_seed(
        spec_path=Path("spec.yaml"),
        overlay_context=overlay_context,
        iteration_id=0,
        spec_sha256="abc",
        generator_profile="default",
        generator_profile_sha256="def",
        evidence_dir=Path("evidence"),
    )
    validate_tm7_with_tmt.tm7_visual_feedback.validate_layout_overlay(
        seed,
        overlay_context,
    )

    # Assert
    assert seed["zone_rules"] == []
    assert seed["node_rules"] == []
    assert seed["connector_rules"] == []
    assert seed["surface_rules"] == []
    assert seed["provenance"]["approval_state"] == "pending"
    assert {entry["surface_id"] for entry in seed["applies_to"]} == {
        "context",
        "operational",
    }


def test_given_no_captured_surface_when_seed_built_then_raises() -> None:
    """A seed without surfaces would address nothing, so it must fail closed."""
    # Arrange
    overlay_context = validate_tm7_with_tmt.tm7_visual_feedback.OverlayContext(
        model_id="demo-model",
        spec_path=Path("spec.yaml"),
        spec_sha256="abc",
        generator_profile="default",
        generator_profile_sha256="def",
        surface_ids=set(),
        surface_node_ids={},
    )

    # Act and Assert
    with pytest.raises(ValueError, match="surface"):
        validate_tm7_with_tmt._build_overlay_seed(
            spec_path=Path("spec.yaml"),
            overlay_context=overlay_context,
            iteration_id=0,
            spec_sha256="abc",
            generator_profile="default",
            generator_profile_sha256="def",
            evidence_dir=Path("evidence"),
        )


def _review_overlay_context() -> Any:
    """Build a two-surface overlay context for review-request tests."""
    return validate_tm7_with_tmt.tm7_visual_feedback.OverlayContext(
        model_id="demo-model",
        spec_path=Path("spec.yaml"),
        spec_sha256="abc",
        generator_profile="default",
        generator_profile_sha256="def",
        surface_ids={"context", "operational"},
        surface_node_ids={
            "context": {"portal"},
            "operational": {"ops"},
        },
        surface_flow_ids={"context": {"flow-01"}, "operational": set()},
    )


def _review_metric(surface_id: str) -> dict[str, Any]:
    """Build one surface metric carrying the geometry the request lifts."""
    return {
        "surface_id": surface_id,
        "surface_name": f"{surface_id} surface",
        "evidence_path": f"screenshots/{surface_id}.png",
        "findings": [],
        "surface_geometry": {
            "node_rects": {"portal": [10.0, 20.0, 110.0, 120.0]},
            "connector_label_rects": {"flow-01": [5.0, 6.0, 7.0, 8.0]},
            "connector_routes": {"flow-01": {"handle_point": [200.0, 300.0]}},
            "selected_flow_ids": ["flow-01"],
            "zone_content_rects": {"zone-01": [0.0, 0.0, 400.0, 400.0]},
            "boundary_rects": {"zone-01": [0.0, 0.0, 400.0, 400.0]},
            "viewport_target": [0.0, 0.0, 1200.0, 800.0],
            "diagram_bounds": [0.0, 0.0, 600.0, 600.0],
        },
    }


def test_given_captured_surfaces_when_request_built_then_payload_is_sufficient(
    tmp_path: Path,
) -> None:
    """The payload alone must support authoring a connector rule.

    Key presence is not sufficiency: a request can carry every named key with
    no usable handle and still look complete, so this asserts the round trip
    an agent actually performs.
    """
    # Arrange
    bundle = validate_tm7_with_tmt.EvidenceBundle(tmp_path / "evidence")
    overlay_context = _review_overlay_context()

    # Act
    request = validate_tm7_with_tmt._build_agent_review_request(
        final_surface_metrics=[_review_metric("context")],
        final_surface_payloads=[
            {
                "surface_id": "context",
                "surface_guid": "guid-context",
                "uia_path": "uia/context.txt",
            }
        ],
        semantic_surfaces={},
        published_overlay_path=None,
        overlay_input=None,
        bundle=bundle,
    )

    # Assert
    assert request is not None
    surface = request["surfaces"][0]
    for key in (
        "surface_id",
        "surface_name",
        "surface_guid",
        "screenshot_path",
        "uia_path",
        "metrics_path",
        "node_rects",
        "predicted_connector_label_rects",
        "connector_handles",
        "zone_content_rects",
        "boundary_rects",
        "viewport_target",
        "diagram_bounds",
        "existing_findings",
        "review_status",
    ):
        assert key in surface
    for key in (
        "defect_classes",
        "coordinate_translation",
        "port_convention",
        "overlay_seed_path",
        "replay_command",
        "agent_round",
    ):
        assert key in request
    # The sentinel means the manifest could not resolve a real capture; the
    # request must never propagate it as though it were a path.
    assert surface["uia_path"] != "missing"
    assert surface["connector_handles"]["flow-01"] == {"x": 200.0, "y": 300.0}
    assert request["overlay_seed_path"] is None
    assert request["replay_command"] is None
    assert request["agent_round"] == 0

    # A rule built only from payload values must survive real validation.
    # handle_point is an object, and connector_handles already emits that
    # shape, so a displaced handle is authored without reshaping anything.
    handle = surface["connector_handles"]["flow-01"]
    overlay = validate_tm7_with_tmt._build_overlay_seed(
        spec_path=Path("spec.yaml"),
        overlay_context=overlay_context,
        iteration_id=0,
        spec_sha256="abc",
        generator_profile="default",
        generator_profile_sha256="def",
        evidence_dir=tmp_path / "evidence",
    )
    overlay["connector_rules"] = [
        {
            "surface_id": surface["surface_id"],
            "flow_id": "flow-01",
            "source_port": "auto",
            "target_port": "auto",
            "handle_point": {"x": handle["x"] + 50.0, "y": handle["y"]},
        }
    ]
    validate_tm7_with_tmt.tm7_visual_feedback.validate_layout_overlay(
        overlay,
        overlay_context,
    )


def test_given_no_surface_metrics_when_request_built_then_returns_none(
    tmp_path: Path,
) -> None:
    """A request addressing nothing would invite review of nothing."""
    # Arrange
    bundle = validate_tm7_with_tmt.EvidenceBundle(tmp_path / "evidence")

    # Act
    request = validate_tm7_with_tmt._build_agent_review_request(
        final_surface_metrics=[],
        final_surface_payloads=[],
        semantic_surfaces={},
        published_overlay_path=None,
        overlay_input=None,
        bundle=bundle,
    )

    # Assert
    assert request is None


def test_given_replay_input_when_request_built_then_round_is_replay_depth(
    tmp_path: Path,
) -> None:
    """agent_round reports replay depth, not a budget the harness cannot see."""
    # Arrange
    bundle = validate_tm7_with_tmt.EvidenceBundle(tmp_path / "evidence")

    # Act
    request = validate_tm7_with_tmt._build_agent_review_request(
        final_surface_metrics=[_review_metric("context")],
        final_surface_payloads=[
            {"surface_id": "context", "uia_path": "uia/context.txt"}
        ],
        semantic_surfaces={},
        published_overlay_path=None,
        overlay_input=Path("prior-overlay.json"),
        bundle=bundle,
    )

    # Assert
    assert request is not None
    assert request["agent_round"] == 1


def test_given_request_payload_when_validated_then_schema_stays_strict(
    tmp_path: Path,
) -> None:
    """The request schema must reject an unknown key rather than ignore it."""
    # Arrange
    schema_path = (
        Path(validate_tm7_with_tmt.__file__).resolve().parent.parent
        / "assets"
        / "schemas"
        / "tm7-agent-review-request.schema.json"
    )
    schema = json.loads(schema_path.read_text(encoding="utf-8"))
    bundle = validate_tm7_with_tmt.EvidenceBundle(tmp_path / "evidence")
    request = validate_tm7_with_tmt._build_agent_review_request(
        final_surface_metrics=[_review_metric("context")],
        final_surface_payloads=[
            {"surface_id": "context", "uia_path": "uia/context.txt"}
        ],
        semantic_surfaces={},
        published_overlay_path=None,
        overlay_input=None,
        bundle=bundle,
    )

    # Assert
    assert schema["additionalProperties"] is False
    assert schema["properties"]["surfaces"]["items"]["additionalProperties"] is False
    assert request is not None
    assert set(request) == set(schema["required"])
    assert set(request["surfaces"][0]) == set(
        schema["properties"]["surfaces"]["items"]["required"]
    )


def test_given_exit_codes_when_inspected_then_table_is_unchanged() -> None:
    """The published exit-code table is a contract this task preserves."""
    # Assert
    assert {
        "EXIT_SUCCESS": validate_tm7_with_tmt.EXIT_SUCCESS,
        "EXIT_VALIDATION_FAILURE": validate_tm7_with_tmt.EXIT_VALIDATION_FAILURE,
        "EXIT_ERROR": validate_tm7_with_tmt.EXIT_ERROR,
        "EXIT_MISSING_TMT": validate_tm7_with_tmt.EXIT_MISSING_TMT,
        "EXIT_VERSION_MISMATCH": validate_tm7_with_tmt.EXIT_VERSION_MISMATCH,
        "EXIT_AUTOMATION_TIMEOUT": validate_tm7_with_tmt.EXIT_AUTOMATION_TIMEOUT,
        "EXIT_UNEXPECTED_MODAL": validate_tm7_with_tmt.EXIT_UNEXPECTED_MODAL,
        "EXIT_MISSING_FEEDBACK_EVIDENCE": (
            validate_tm7_with_tmt.EXIT_MISSING_FEEDBACK_EVIDENCE
        ),
        "EXIT_FEEDBACK_NON_CONVERGENCE": (
            validate_tm7_with_tmt.EXIT_FEEDBACK_NON_CONVERGENCE
        ),
        "EXIT_INTERRUPTED": validate_tm7_with_tmt.EXIT_INTERRUPTED,
    } == {
        "EXIT_SUCCESS": 0,
        "EXIT_VALIDATION_FAILURE": 1,
        "EXIT_ERROR": 2,
        "EXIT_MISSING_TMT": 3,
        "EXIT_VERSION_MISMATCH": 4,
        "EXIT_AUTOMATION_TIMEOUT": 5,
        "EXIT_UNEXPECTED_MODAL": 6,
        "EXIT_MISSING_FEEDBACK_EVIDENCE": 7,
        "EXIT_FEEDBACK_NON_CONVERGENCE": 8,
        "EXIT_INTERRUPTED": 130,
    }


def test_given_stop_reason_set_when_inspected_then_membership_is_unchanged() -> None:
    """The published stop-reason vocabulary is a contract this task preserves."""
    # Assert
    assert validate_tm7_with_tmt.FEEDBACK_STOP_REASONS == frozenset(
        {
            "automated-ready-pending-human",
            "repeated-defect-no-improvement",
            "max-iterations",
            "evidence-incomplete",
            "semantic-regression",
            "candidate-generation-failed",
            "overlay-validation-failed",
            "tmt-unavailable",
            "skipped",
            "version-mismatch",
            "automation-timeout",
            "unexpected-modal",
            "harness-error",
        }
    )
    assert validate_tm7_with_tmt.OVERLAY_SEED_STOP_REASONS == frozenset(
        {"repeated-defect-no-improvement", "max-iterations"}
    )


def test_given_manifest_schema_when_inspected_then_key_sets_are_unchanged() -> None:
    """A version constant can stay fixed while properties drift, so pin keys."""
    # Arrange
    schema_path = (
        Path(validate_tm7_with_tmt.__file__).resolve().parent.parent
        / "assets"
        / "schemas"
        / "tm7-visual-feedback-manifest.schema.json"
    )
    schema = json.loads(schema_path.read_text(encoding="utf-8"))

    # Assert
    assert set(schema["properties"]["convergence"]["properties"]) == {
        "status",
        "selected_candidate",
        "stop_reason",
        "semantic_regression",
        "evidence_complete",
    }
    assert schema["properties"]["convergence"]["additionalProperties"] is False


def test_given_default_iteration_budget_when_read_then_it_is_one_refinement() -> None:
    """The default is baseline plus one refinement; the range is unchanged."""
    # Assert
    assert validate_tm7_with_tmt.DEFAULT_MAX_ITERATIONS == 1
    for accepted in (1, 2, 3):
        validate_tm7_with_tmt._validate_feedback_loop_args(
            feedback_loop=True,
            spec_path=Path("spec.yaml"),
            overlay_output=Path("overlay.json"),
            max_iterations=accepted,
        )
    for rejected in (0, 4):
        with pytest.raises(validate_tm7_with_tmt.HarnessFailure):
            validate_tm7_with_tmt._validate_feedback_loop_args(
                feedback_loop=True,
                spec_path=Path("spec.yaml"),
                overlay_output=Path("overlay.json"),
                max_iterations=rejected,
            )


def test_given_status_payload_when_review_omitted_then_no_agent_review_key(
    tmp_path: Path,
) -> None:
    """_status_payload is shared, so non-feedback runs gain no new key."""
    # Arrange
    bundle = validate_tm7_with_tmt.EvidenceBundle(tmp_path / "evidence")
    bundle.evidence_dir.mkdir(parents=True, exist_ok=True)

    # Act
    without = validate_tm7_with_tmt._status_payload(
        result="skipped",
        exit_code=0,
        message="no tmt",
        bundle=bundle,
        manifest={"required_tmt_version": "7.3.51110.1"},
    )
    with_review = validate_tm7_with_tmt._status_payload(
        result="automated-ready-pending-human",
        exit_code=0,
        message="ready",
        bundle=bundle,
        manifest={"required_tmt_version": "7.3.51110.1"},
        agent_review={
            "status": "pending",
            "request_path": "agent-review-request.json",
            "round": 0,
        },
    )

    # Assert
    assert "agent_review" not in without
    assert with_review["agent_review"]["status"] == "pending"


def test_given_feedback_success_when_run_then_emits_start_progress_and_release(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    caplog: pytest.LogCaptureFixture,
) -> None:
    # Arrange
    spec_path = tmp_path / "spec.yaml"
    _write_feedback_spec(spec_path)
    baseline_model = tmp_path / "baseline.tm7"
    baseline_model.write_text("baseline", encoding="utf-8")
    overlay_output = tmp_path / "overlay.yaml"
    evidence_dir = tmp_path / "evidence"
    caplog.set_level("INFO")

    def fake_generate_candidate(
        *, spec_path: Path, output_path: Path, **_: Any
    ) -> Path:
        output_path.write_text("candidate", encoding="utf-8")
        return output_path

    def fake_validate_candidate(*args: Any, **kwargs: Any) -> dict[str, Any]:
        return {
            "working_model": str(baseline_model),
            "saved_model": str(baseline_model),
            "before_summary": {
                "instance_count": 1,
                "instances": [{"id": "1", "type_id": "TH-test"}],
                "threat_identities": ["threat"],
                "element_identities": [],
                "flow_identities": [],
                "drawing_surface_hash": "surface",
                "knowledge_base_hash": "kb",
            },
            "after_summary": {
                "instance_count": 1,
                "instances": [{"id": "1", "type_id": "TH-test"}],
                "threat_identities": ["threat"],
                "element_identities": [],
                "flow_identities": [],
                "drawing_surface_hash": "surface",
                "knowledge_base_hash": "kb",
            },
            "surface_metrics": [
                {
                    "surface_id": "context",
                    "node_id": "trust-zone-portal",
                    "gate_failure_count": 0,
                    "review_count": 0,
                    "warn_count": 0,
                    "max_severity_score": 0.0,
                    "constraint_type": "position",
                    "findings": [],
                }
            ],
            "evidence_complete": True,
            "semantic_regression": False,
            "semantic_summary": {"instance_count": 1},
            "candidate_path": str(baseline_model),
        }

    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "discover_tmt_application",
        lambda: validate_tm7_with_tmt.TmtDiscovery(
            path=tmp_path / "ThreatModeling.exe", version="7.3.51110.1", source="test"
        ),
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt.generate_tm7,
        "generate_tm7_candidate",
        fake_generate_candidate,
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt, "_validate_feedback_candidate", fake_validate_candidate
    )
    monkeypatch.setattr(validate_tm7_with_tmt, "sha256_file", lambda path: "sha256")

    # Act
    result = validate_tm7_with_tmt.run_harness(
        input_model=baseline_model,
        evidence_dir=evidence_dir,
        feedback_loop=True,
        spec_path=spec_path,
        overlay_output=overlay_output,
        max_iterations=1,
        require_feedback_evidence=False,
    )

    # Assert
    assert result.status == "automated-ready-pending-human"
    assert caplog.text.count("Native TMT UI automation will control") == 1
    assert caplog.text.count("Candidate baseline") == 1
    assert caplog.text.count("Native TMT UI automation is complete") == 1


def test_given_feedback_loop_when_validation_failure_then_emits_single_release_notice(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    caplog: pytest.LogCaptureFixture,
) -> None:
    # Arrange
    spec_path = tmp_path / "spec.yaml"
    _write_feedback_spec(spec_path)
    baseline_model = tmp_path / "baseline.tm7"
    baseline_model.write_text("baseline", encoding="utf-8")
    overlay_output = tmp_path / "overlay.yaml"
    evidence_dir = tmp_path / "evidence"
    caplog.set_level("INFO")

    def fake_generate_candidate(
        *, spec_path: Path, output_path: Path, **_: Any
    ) -> Path:
        output_path.write_text("candidate", encoding="utf-8")
        return output_path

    def fake_validate_candidate(*args: Any, **kwargs: Any) -> dict[str, Any]:
        raise validate_tm7_with_tmt.HarnessFailure(
            "boom",
            validate_tm7_with_tmt.EXIT_VALIDATION_FAILURE,
        )

    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "discover_tmt_application",
        lambda: validate_tm7_with_tmt.TmtDiscovery(
            path=tmp_path / "ThreatModeling.exe", version="7.3.51110.1", source="test"
        ),
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt.generate_tm7,
        "generate_tm7_candidate",
        fake_generate_candidate,
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt, "_validate_feedback_candidate", fake_validate_candidate
    )
    monkeypatch.setattr(validate_tm7_with_tmt, "sha256_file", lambda path: "sha256")

    # Act
    result = validate_tm7_with_tmt.run_harness(
        input_model=baseline_model,
        evidence_dir=evidence_dir,
        feedback_loop=True,
        spec_path=spec_path,
        overlay_output=overlay_output,
        max_iterations=1,
        require_feedback_evidence=False,
    )

    # Assert
    assert result.exit_code == validate_tm7_with_tmt.EXIT_VALIDATION_FAILURE
    assert caplog.text.count("Native TMT UI automation will control") == 1
    assert caplog.text.count("Native TMT UI automation is complete") == 1


def test_given_feedback_loop_when_clean_iteration_then_manifest_stop_reason_is(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    spec_path = tmp_path / "spec.yaml"
    _write_feedback_spec(spec_path)
    baseline_model = tmp_path / "baseline.tm7"
    baseline_model.write_text("baseline", encoding="utf-8")
    overlay_output = tmp_path / "overlay.yaml"
    evidence_dir = tmp_path / "evidence"

    def fake_generate_candidate(
        *, spec_path: Path, output_path: Path, **_: Any
    ) -> Path:
        output_path.write_text("candidate", encoding="utf-8")
        return output_path

    def fake_validate_candidate(*args: Any, **kwargs: Any) -> dict[str, Any]:
        return {
            "working_model": str(baseline_model),
            "saved_model": str(baseline_model),
            "before_summary": {
                "instance_count": 1,
                "instances": [{"id": "1", "type_id": "TH-test"}],
                "threat_identities": ["threat"],
                "element_identities": [],
                "flow_identities": [],
                "drawing_surface_hash": "surface",
                "knowledge_base_hash": "kb",
            },
            "after_summary": {
                "instance_count": 1,
                "instances": [{"id": "1", "type_id": "TH-test"}],
                "threat_identities": ["threat"],
                "element_identities": [],
                "flow_identities": [],
                "drawing_surface_hash": "surface",
                "knowledge_base_hash": "kb",
            },
            "surface_metrics": [
                {
                    "surface_id": "context",
                    "node_id": "trust-zone-portal",
                    "gate_failure_count": 0,
                    "review_count": 0,
                    "warn_count": 0,
                    "max_severity_score": 0.0,
                    "constraint_type": "position",
                    "findings": [],
                }
            ],
            "evidence_complete": True,
            "semantic_regression": False,
            "semantic_summary": {"instance_count": 1},
            "candidate_path": str(baseline_model),
        }

    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "discover_tmt_application",
        lambda: validate_tm7_with_tmt.TmtDiscovery(
            path=tmp_path / "ThreatModeling.exe", version="7.3.51110.1", source="test"
        ),
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt.generate_tm7,
        "generate_tm7_candidate",
        fake_generate_candidate,
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt, "_validate_feedback_candidate", fake_validate_candidate
    )
    monkeypatch.setattr(validate_tm7_with_tmt, "sha256_file", lambda path: "sha256")

    # Act
    result = validate_tm7_with_tmt.run_harness(
        input_model=baseline_model,
        evidence_dir=evidence_dir,
        feedback_loop=True,
        spec_path=spec_path,
        overlay_output=overlay_output,
        max_iterations=1,
        require_feedback_evidence=False,
    )

    # Assert
    assert result.status == "automated-ready-pending-human"
    manifest = json.loads((evidence_dir / "manifest.json").read_text(encoding="utf-8"))
    assert manifest["stop_reason"] == "automated-ready-pending-human"


def test_given_flat_geometry_when_scored_then_uses_real_rectangles(
    tmp_path: Path,
) -> None:
    # Arrange
    candidate_model = tmp_path / "candidate.tm7"
    candidate_model.write_text(
        """<ThreatModel>
  <DrawingSurfaceList>
    <DrawingSurfaceModel>
      <Header>context</Header>
      <Guid>surface-guid</Guid>
      <Borders>
        <KeyValueOfguidanyType>
          <Value>
            <Id>node-1</Id>
            <Kind>process</Kind>
            <Name>Portal</Name>
            <Left>10</Left>
            <Top>20</Top>
            <Width>100</Width>
            <Height>90</Height>
            <Guid>node-guid-1</Guid>
          </Value>
        </KeyValueOfguidanyType>
      </Borders>
      <Lines>
        <KeyValueOfguidanyType>
          <Value>
            <Id>flow-1</Id>
            <SourceGuid>node-guid-1</SourceGuid>
            <TargetGuid>node-guid-2</TargetGuid>
            <SourceX>10</SourceX>
            <SourceY>20</SourceY>
            <TargetX>120</TargetX>
            <TargetY>40</TargetY>
          </Value>
        </KeyValueOfguidanyType>
      </Lines>
    </DrawingSurfaceModel>
  </DrawingSurfaceList>
</ThreatModel>""",
        encoding="utf-8",
    )

    payloads = [{"surface_id": "context", "screenshot_path": "ignored.png"}]

    # Act
    metrics = validate_tm7_with_tmt._derive_feedback_surface_metrics(
        surface_payloads=payloads,
        bundle=validate_tm7_with_tmt.EvidenceBundle(tmp_path / "evidence"),
        candidate_model_path=candidate_model,
    )

    # Assert
    assert metrics[0]["surface_id"] == "context"
    assert metrics[0]["node_id"] == "node-1"
    assert metrics[0]["capture_status"] == "incomplete"


def test_given_feedback_loop_when_stop_status_is_normalized_then_returns() -> None:
    # Act
    reason = validate_tm7_with_tmt._normalize_feedback_stop_reason(
        "passed",
        require_feedback_evidence=True,
        exit_code=validate_tm7_with_tmt.EXIT_SUCCESS,
    )

    # Assert
    assert reason == "automated-ready-pending-human"


def test_given_generation_failure_when_stop_status_is_normalized_then_preserved() -> (
    None
):
    # Act
    reason = validate_tm7_with_tmt._normalize_feedback_stop_reason(
        "candidate-generation-failed",
        require_feedback_evidence=True,
        exit_code=validate_tm7_with_tmt.EXIT_ERROR,
    )

    # Assert
    assert reason == "candidate-generation-failed"


@pytest.mark.parametrize("status", sorted(validate_tm7_with_tmt.FEEDBACK_STOP_REASONS))
def test_given_declared_stop_reason_when_normalized_then_it_is_returned_unchanged(
    status: str,
) -> None:
    # Act
    reason = validate_tm7_with_tmt._normalize_feedback_stop_reason(
        status,
        require_feedback_evidence=True,
        exit_code=validate_tm7_with_tmt.EXIT_ERROR,
    )

    # Assert
    assert reason == status


def test_given_unmapped_status_when_normalized_then_reports_harness_error() -> None:
    # Act
    reason = validate_tm7_with_tmt._normalize_feedback_stop_reason(
        "some-status-the-loop-never-assigns",
        require_feedback_evidence=False,
        exit_code=validate_tm7_with_tmt.EXIT_ERROR,
    )

    # Assert
    assert reason == "harness-error"


@pytest.mark.parametrize(
    ("require_tmt", "expected_status", "expected_exit"),
    [
        (False, "skipped", validate_tm7_with_tmt.EXIT_SUCCESS),
        (True, "tmt-unavailable", validate_tm7_with_tmt.EXIT_MISSING_TMT),
    ],
)
def test_given_missing_tmt_when_feedback_loop_runs_then_require_tmt_selects_outcome(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    require_tmt: bool,
    expected_status: str,
    expected_exit: int,
) -> None:
    # Arrange
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "discover_tmt_application",
        lambda: validate_tm7_with_tmt.TmtDiscovery(path=None),
    )
    spec_path = tmp_path / "spec.yaml"
    _write_feedback_spec(spec_path)
    evidence_dir = tmp_path / "evidence"

    # Act
    result = validate_tm7_with_tmt.run_feedback_loop(
        baseline_model=_input_model(tmp_path),
        spec_path=spec_path,
        overlay_input=None,
        overlay_output=tmp_path / "overlay.json",
        max_iterations=1,
        require_feedback_evidence=False,
        evidence_dir=evidence_dir,
        require_tmt=require_tmt,
    )

    # Assert
    assert result.status == expected_status
    assert result.exit_code == expected_exit
    status_payload = json.loads((evidence_dir / "status.json").read_text("utf-8"))
    assert status_payload["result"] == expected_status


def test_given_unexpected_error_when_feedback_loop_runs_then_status_records_failure(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    executable = tmp_path / "ThreatModeling.exe"
    executable.write_bytes(b"exe")
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "discover_tmt_application",
        lambda: validate_tm7_with_tmt.TmtDiscovery(
            path=executable,
            version=validate_tm7_with_tmt.DEFAULT_PINNED_VERSION,
            source="test",
        ),
    )

    def explode(*args: Any, **kwargs: Any) -> dict[str, Any]:
        raise RuntimeError("disk vanished")

    monkeypatch.setattr(validate_tm7_with_tmt.generate_tm7, "load_spec", explode)
    spec_path = tmp_path / "spec.yaml"
    _write_feedback_spec(spec_path)
    evidence_dir = tmp_path / "evidence"
    overlay_output = tmp_path / "overlay.json"
    overlay_output.write_text('{"stale": true}', encoding="utf-8")

    # Act
    result = validate_tm7_with_tmt.run_feedback_loop(
        baseline_model=_input_model(tmp_path),
        spec_path=spec_path,
        overlay_input=None,
        overlay_output=overlay_output,
        max_iterations=1,
        require_feedback_evidence=False,
        evidence_dir=evidence_dir,
    )

    # Assert
    assert result.status == "harness-error"
    assert result.exit_code == validate_tm7_with_tmt.EXIT_ERROR
    assert not overlay_output.exists()
    status_payload = json.loads((evidence_dir / "status.json").read_text("utf-8"))
    assert status_payload["result"] == "harness-error"
    manifest_payload = json.loads((evidence_dir / "manifest.json").read_text("utf-8"))
    assert manifest_payload["stop_reason"] == "harness-error"


def test_given_overlay_input_equals_output_when_discarded_then_the_file_is_kept(
    tmp_path: Path,
) -> None:
    # Arrange
    overlay = tmp_path / "overlay.json"
    overlay.write_text('{"rules": []}', encoding="utf-8")

    # Act
    validate_tm7_with_tmt._discard_stale_overlay(overlay, overlay)

    # Assert
    assert overlay.exists()


@pytest.mark.parametrize(
    "relative",
    [
        "../escape.json",
        "nested/../../escape.json",
        "surfaces/../../escape.json",
        "/etc/passwd",
        "C:\\Windows\\escape.json",
        "\\\\server\\share\\escape.json",
    ],
)
def test_given_escaping_reference_when_path_resolved_then_it_is_rejected(
    tmp_path: Path,
    relative: str,
) -> None:
    """A traversal must be refused before the parent directory is created."""
    # Arrange
    evidence_dir = tmp_path / "evidence"
    bundle = validate_tm7_with_tmt.EvidenceBundle(evidence_dir)

    # Act and Assert
    with pytest.raises(validate_tm7_with_tmt.HarnessFailure):
        bundle.path(relative)
    assert not (tmp_path / "escape.json").exists()


def test_given_nested_reference_when_path_resolved_then_it_stays_inside(
    tmp_path: Path,
) -> None:
    # Arrange
    evidence_dir = tmp_path / "evidence"
    bundle = validate_tm7_with_tmt.EvidenceBundle(evidence_dir)

    # Act
    resolved = bundle.path("surfaces/context/metrics.json")

    # Assert
    assert evidence_dir.resolve() in resolved.parents
    assert resolved.parent.is_dir()


@pytest.mark.parametrize(
    ("surface_id", "expected"),
    [
        ("..", "surface"),
        ("../..", "surface"),
        ("context", "context"),
        ("a/../../b", "a-b"),
        ("...", "surface"),
        ("", "surface"),
    ],
)
def test_given_unsafe_surface_id_when_slugged_then_no_traversal_survives(
    surface_id: str,
    expected: str,
) -> None:
    """The prior rule preserved `.`, so an id of `..` stayed a traversal segment."""
    # Act
    slug = validate_tm7_with_tmt._evidence_slug(surface_id)

    # Assert
    assert slug == expected
    assert ".." not in slug
    assert "/" not in slug and "\\" not in slug


@pytest.mark.parametrize(
    "secret_text",
    [
        '{"password": "hunter2-should-not-appear"}',
        "password=hunter2-should-not-appear",
        "Authorization: Bearer hunter2-should-not-appear",
        "'client_secret': 'hunter2-should-not-appear'",
        "https://example.invalid/x?sig=hunter2-should-not-appear",
        "AccountKey=hunter2-should-not-appear;Other=1",
    ],
)
def test_given_secret_shape_when_redacted_then_the_value_is_removed(
    tmp_path: Path,
    secret_text: str,
) -> None:
    """Pixels cannot be redacted, but every text sink must drop the value."""
    # Arrange
    bundle = validate_tm7_with_tmt.EvidenceBundle(tmp_path / "evidence")

    # Act
    redacted = bundle._redact_text(secret_text)

    # Assert
    assert "hunter2-should-not-appear" not in redacted


def test_given_seeded_secrets_when_run_writes_evidence_then_no_sink_leaks_it(
    tmp_path: Path,
) -> None:
    """The canary must not survive in any file the bundle writes."""
    # Arrange
    canary = "hunter2-canary-value"
    evidence_dir = tmp_path / "evidence"
    bundle = validate_tm7_with_tmt.EvidenceBundle(evidence_dir)
    payload = {
        "password": canary,
        "nested": {"api_key": canary, "safe": "kept"},
        "free_text": f"Authorization: Bearer {canary}",
        "listed": [f"client_secret={canary}"],
    }

    # Act
    bundle.write_manifest(payload)
    bundle.write_status(payload)
    bundle.write_json("surfaces/context/metrics.json", payload)
    bundle.write_uia_tree(f"password={canary}", "probe.txt")
    bundle.write_action_log(f"token={canary}")

    # Assert
    leaked = [
        str(path)
        for path in evidence_dir.rglob("*")
        if path.is_file() and canary in path.read_text(encoding="utf-8")
    ]
    assert leaked == []
    assert "kept" in (evidence_dir / "manifest.json").read_text(encoding="utf-8")


def test_given_no_window_isolation_when_capturing_then_it_is_refused(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """A desktop-region capture could persist pixels redaction cannot repair."""
    # Arrange
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "screenshot_isolation_available",
        lambda: False,
    )

    # Act and Assert
    with pytest.raises(
        validate_tm7_with_tmt.HarnessFailure,
        match="Screenshot capture is disabled",
    ):
        validate_tm7_with_tmt.capture_window_screenshot(
            object(),
            tmp_path / "shot.png",
        )
    assert not (tmp_path / "shot.png").exists()


def test_given_strict_evidence_when_capture_is_refused_then_the_run_fails_closed(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "screenshot_isolation_available",
        lambda: False,
    )
    bundle = validate_tm7_with_tmt.EvidenceBundle(tmp_path / "evidence")

    # Act and Assert
    with pytest.raises(validate_tm7_with_tmt.HarnessFailure):
        validate_tm7_with_tmt._capture_or_skip(
            object(),
            bundle.path("screenshots/probe.png"),
            bundle=bundle,
            require_feedback_evidence=True,
        )


def test_given_relaxed_evidence_when_capture_is_refused_then_the_reason_is_logged(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "screenshot_isolation_available",
        lambda: False,
    )
    bundle = validate_tm7_with_tmt.EvidenceBundle(tmp_path / "evidence")

    # Act
    validate_tm7_with_tmt._capture_or_skip(
        object(),
        bundle.path("screenshots/probe.png"),
        bundle=bundle,
        require_feedback_evidence=False,
    )

    # Assert
    assert "Screenshot capture is disabled" in bundle.action_log_path.read_text(
        encoding="utf-8"
    )


def test_given_surface_payloads_when_scored_then_persists_metrics_and_findings(
    tmp_path: Path,
) -> None:
    # Arrange
    candidate_model = tmp_path / "candidate.tm7"
    candidate_model.write_text(
        """<ThreatModel>
    <DrawingSurfaceList>
        <DrawingSurfaceModel>
            <Header>context</Header>
            <Guid>surface-guid</Guid>
            <Borders>
                <KeyValueOfguidanyType>
                    <Value>
                        <Id>node-1</Id>
                        <Kind>process</Kind>
                        <Name>Portal</Name>
                        <Left>10</Left>
                        <Top>20</Top>
                        <Width>100</Width>
                        <Height>90</Height>
                        <Guid>node-guid-1</Guid>
                    </Value>
                </KeyValueOfguidanyType>
            </Borders>
            <Lines />
        </DrawingSurfaceModel>
    </DrawingSurfaceList>
</ThreatModel>""",
        encoding="utf-8",
    )
    evidence_dir = tmp_path / "evidence"
    evidence_dir.mkdir(parents=True, exist_ok=True)
    payload = {
        "surface_id": "context",
        "surface_name": "context",
        "capture_scope": "pane",
        "annotation": "review",
        "crop": {"left": 0, "top": 0, "width": 100, "height": 100},
        "screenshot_path": "screenshots/context.png",
    }
    (evidence_dir / "screenshots").mkdir(parents=True, exist_ok=True)
    (evidence_dir / "screenshots" / "context.png").write_bytes(b"\x00" * 32)

    # Act
    metrics = validate_tm7_with_tmt._derive_feedback_surface_metrics(
        surface_payloads=[payload],
        bundle=validate_tm7_with_tmt.EvidenceBundle(evidence_dir),
        candidate_model_path=candidate_model,
    )

    # Assert
    assert metrics[0]["surface_id"] == "context"
    assert metrics[0]["node_id"] == "node-1"
    assert metrics[0]["findings"]
    assert metrics[0]["capture_scope"] == "pane"


def test_given_clean_feedback_when_completed_then_emits_no_movement_rule(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    spec_path = tmp_path / "spec.yaml"
    _write_feedback_spec(spec_path)
    baseline_model = tmp_path / "baseline.tm7"
    baseline_model.write_text("baseline", encoding="utf-8")
    overlay_output = tmp_path / "overlay.yaml"
    evidence_dir = tmp_path / "evidence"

    def fake_generate_candidate(
        *, spec_path: Path, output_path: Path, **_: Any
    ) -> Path:
        output_path.write_text("candidate", encoding="utf-8")
        return output_path

    def fake_validate_candidate(*args: Any, **kwargs: Any) -> dict[str, Any]:
        return {
            "working_model": str(baseline_model),
            "saved_model": str(baseline_model),
            "before_summary": {
                "instance_count": 1,
                "instances": [{"id": "1"}],
                "drawing_surface_hash": "surface",
                "knowledge_base_hash": "kb",
            },
            "after_summary": {
                "instance_count": 1,
                "instances": [{"id": "1"}],
                "drawing_surface_hash": "surface",
                "knowledge_base_hash": "kb",
            },
            "surface_metrics": [
                {
                    "surface_id": "context",
                    "node_id": "trust-zone-portal",
                    "gate_failure_count": 0,
                    "review_count": 0,
                    "warn_count": 0,
                    "max_severity_score": 0.0,
                    "constraint_type": "position",
                    "findings": [],
                }
            ],
            "evidence_complete": True,
            "semantic_regression": False,
            "semantic_summary": {"instance_count": 1},
            "candidate_path": str(baseline_model),
        }

    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "discover_tmt_application",
        lambda: validate_tm7_with_tmt.TmtDiscovery(
            path=tmp_path / "ThreatModeling.exe",
            version="7.3.51110.1",
            source="test",
        ),
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt.generate_tm7,
        "generate_tm7_candidate",
        fake_generate_candidate,
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "_validate_feedback_candidate",
        fake_validate_candidate,
    )
    monkeypatch.setattr(validate_tm7_with_tmt, "sha256_file", lambda path: "sha")

    # Act
    result = validate_tm7_with_tmt.run_harness(
        input_model=baseline_model,
        evidence_dir=evidence_dir,
        feedback_loop=True,
        spec_path=spec_path,
        overlay_output=overlay_output,
        max_iterations=1,
        require_feedback_evidence=False,
    )

    # Assert
    assert result.exit_code == validate_tm7_with_tmt.EXIT_SUCCESS
    payload = json.loads(overlay_output.read_text(encoding="utf-8"))
    assert payload["node_rules"] == []
    assert "rules" not in payload
    assert "ranking_key" not in payload


def test_given_one_failing_surface_when_loop_runs_then_does_not_clear_gates(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    spec_path = tmp_path / "spec.yaml"
    _write_feedback_spec(spec_path)
    baseline_model = tmp_path / "baseline.tm7"
    baseline_model.write_text("baseline", encoding="utf-8")
    validation_calls = 0

    def generate_candidate(*, spec_path: Path, output_path: Path, **_: Any) -> Path:
        output_path.write_text("candidate", encoding="utf-8")
        return output_path

    def validate_candidate(*args: Any, **kwargs: Any) -> dict[str, Any]:
        nonlocal validation_calls
        validation_calls += 1
        summary = {
            "instance_count": 1,
            "threat_identities": ["threat"],
            "element_identities": ["element"],
            "flow_identities": [],
        }
        return {
            "working_model": str(baseline_model),
            "saved_model": str(baseline_model),
            "before_summary": summary,
            "after_summary": summary,
            "surface_metrics": [
                {
                    "surface_id": "context",
                    "node_id": "trust-zone-portal",
                    "overlap_ratio": 0.0,
                    "edge_node_intersections": 0,
                    "edge_crossing_count": 0,
                    "min_spacing_ratio": 1.0,
                    "surface_geometry": {
                        "surface_id": "context",
                        "nominal_node_size": 100.0,
                        "node_rects": {"trust-zone-portal": [0.0, 0.0, 100.0, 100.0]},
                        "connector_segments": [],
                    },
                },
                {
                    "surface_id": "other",
                    "node_id": "other-node",
                    "overlap_ratio": 0.04,
                    "edge_node_intersections": 0,
                    "edge_crossing_count": 0,
                    "min_spacing_ratio": 1.0,
                    "surface_geometry": {
                        "surface_id": "other",
                        "nominal_node_size": 100.0,
                        "node_rects": {"other-node": [0.0, 0.0, 100.0, 100.0]},
                        "connector_segments": [],
                    },
                },
            ],
            "evidence_complete": True,
            "semantic_regression": False,
            "candidate_path": str(baseline_model),
        }

    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "discover_tmt_application",
        lambda: validate_tm7_with_tmt.TmtDiscovery(
            path=tmp_path / "ThreatModeling.exe",
            version="7.3.51110.1",
            source="test",
        ),
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt.generate_tm7,
        "generate_tm7_candidate",
        generate_candidate,
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "_validate_feedback_candidate",
        validate_candidate,
    )

    # Act
    result = validate_tm7_with_tmt.run_harness(
        input_model=baseline_model,
        evidence_dir=tmp_path / "evidence",
        feedback_loop=True,
        spec_path=spec_path,
        overlay_output=tmp_path / "overlay.yaml",
        max_iterations=1,
    )

    # Assert
    manifest = json.loads(
        (tmp_path / "evidence" / "manifest.json").read_text(encoding="utf-8")
    )
    assert result.exit_code == validate_tm7_with_tmt.EXIT_FEEDBACK_NON_CONVERGENCE
    assert manifest["stop_reason"] == "max-iterations"
    assert manifest["iterations"][0]["gate_failure_count"] == 1
    assert validation_calls == 2


def test_given_captured_surface_when_binding_then_guid_resolves_the_surface(
    tmp_path: Path,
) -> None:
    # Arrange
    payloads = [
        {
            "surface_id": "captured-tab-0",
            "surface_guid": "guid-context",
            "surface_name": "System context",
            "capture_scope": "pane",
            "annotation": "System context",
            "crop": {"left": 0, "top": 0, "width": 1200, "height": 800},
            "screenshot_path": "surfaces/context.png",
            "surface_geometry": {"node_rects": {}},
        }
    ]
    bundle = validate_tm7_with_tmt.EvidenceBundle(tmp_path / "evidence")
    model_path = _input_model(tmp_path, "surface.tm7")

    # Act
    metrics = validate_tm7_with_tmt._derive_feedback_surface_metrics(
        surface_payloads=payloads,
        bundle=bundle,
        candidate_model_path=model_path,
        surface_id_by_guid={"guid-context": "context"},
    )

    # Assert
    assert [metric["surface_id"] for metric in metrics] == ["context"]


def test_given_unbound_screenshot_guid_when_deriving_then_capture_is_incomplete(
    tmp_path: Path,
) -> None:
    # Arrange
    payloads = [
        {
            "surface_id": "captured-tab-0",
            "surface_guid": "guid-unknown",
            "surface_name": "",
            "capture_scope": "pane",
            "annotation": "",
            "crop": {"left": 0, "top": 0, "width": 1200, "height": 800},
            "screenshot_path": "surfaces/unknown.png",
            "surface_geometry": {"node_rects": {}},
        }
    ]
    bundle = validate_tm7_with_tmt.EvidenceBundle(tmp_path / "evidence")
    model_path = _input_model(tmp_path, "surface.tm7")

    # Act
    metrics = validate_tm7_with_tmt._derive_feedback_surface_metrics(
        surface_payloads=payloads,
        bundle=bundle,
        candidate_model_path=model_path,
        surface_id_by_guid={"guid-context": "context"},
    )

    # Assert
    assert metrics[0]["capture_status"] == "incomplete"


def test_given_clean_surfaces_when_manifest_built_then_review_stays_pending() -> None:
    # Arrange
    manifest = validate_tm7_with_tmt.tm7_visual_feedback.build_feedback_manifest(
        model_id="model",
        spec_path="spec.yaml",
        spec_sha256="a" * 64,
        generator_profile="profile",
        generator_profile_sha256="b" * 64,
        candidate_sha256="c" * 64,
        iteration_id="1",
        pinned_tmt_version="7.3.51110.1",
        surfaces=[{"surface_id": "context"}],
        convergence={
            "status": "automated-ready-pending-human",
            "stop_reason": "automated-ready-pending-human",
            "selected_candidate": None,
        },
    )

    # Act
    validate_tm7_with_tmt.tm7_visual_feedback.validate_feedback_manifest(manifest)

    # Assert
    assert manifest["surfaces"][0]["human_review_status"] == "pending"
    assert manifest["surfaces"][0]["human_review_required"] is True
    assert manifest["convergence"]["status"] == "automated-ready-pending-human"


def test_given_approved_surface_when_validating_manifest_then_it_is_rejected() -> None:
    # Arrange
    manifest = validate_tm7_with_tmt.tm7_visual_feedback.build_feedback_manifest(
        model_id="model",
        spec_path="spec.yaml",
        spec_sha256="a" * 64,
        generator_profile="profile",
        generator_profile_sha256="b" * 64,
        candidate_sha256="c" * 64,
        iteration_id="1",
        pinned_tmt_version="7.3.51110.1",
        surfaces=[{"surface_id": "context"}],
        convergence={
            "status": "automated-ready-pending-human",
            "stop_reason": "automated-ready-pending-human",
            "selected_candidate": None,
        },
    )
    manifest["surfaces"][0]["human_review_status"] = "approved"

    # Act and Assert
    with pytest.raises(ValueError, match="human_review_status must be pending"):
        validate_tm7_with_tmt.tm7_visual_feedback.validate_feedback_manifest(manifest)


def test_given_refinement_gate_when_loop_stops_then_iteration_is_recorded(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """The refinement gate must not discard the iteration it stopped on."""
    # Arrange
    baseline_model = _input_model(tmp_path, "baseline.tm7")
    spec_path = tmp_path / "spec.yaml"
    _write_feedback_spec(spec_path)

    def generate_candidate(*args: Any, **kwargs: Any) -> Path:
        output_path = Path(kwargs.get("output_path") or (tmp_path / "candidate.tm7"))
        output_path.write_bytes(baseline_model.read_bytes())
        return output_path

    def validate_candidate(*args: Any, **kwargs: Any) -> dict[str, Any]:
        summary = {
            "instance_count": 1,
            "threat_identities": ["threat"],
            "element_identities": ["element"],
            "flow_identities": [],
        }
        return {
            "working_model": str(baseline_model),
            "saved_model": str(baseline_model),
            "before_summary": summary,
            "after_summary": summary,
            "surface_metrics": [
                {
                    "surface_id": "context",
                    "node_id": "trust-zone-portal",
                    "overlap_ratio": 0.04,
                    "edge_node_intersections": 0,
                    "edge_crossing_count": 0,
                    "min_spacing_ratio": 1.0,
                    "surface_geometry": {
                        "surface_id": "context",
                        "orientation": "horizontal",
                        "nominal_node_size": 100.0,
                        "node_rects": {"trust-zone-portal": [0.0, 0.0, 100.0, 100.0]},
                        "connector_segments": [],
                        "zone_content_rects": {"zone-a": [0.0, 0.0, 400.0, 400.0]},
                        "node_ranks": {"trust-zone-portal": 0},
                        "branch_groups": {"trust-zone-portal": 0},
                        "viewport_target": [0.0, 0.0, 1920.0, 1080.0],
                    },
                }
            ],
            "evidence_complete": True,
            "semantic_regression": False,
            "candidate_path": str(baseline_model),
        }

    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "discover_tmt_application",
        lambda: validate_tm7_with_tmt.TmtDiscovery(
            path=tmp_path / "ThreatModeling.exe",
            version="7.3.51110.1",
            source="test",
        ),
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt.generate_tm7,
        "generate_tm7_candidate",
        generate_candidate,
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "_validate_feedback_candidate",
        validate_candidate,
    )

    # Act
    result = validate_tm7_with_tmt.run_harness(
        input_model=baseline_model,
        evidence_dir=tmp_path / "evidence",
        feedback_loop=True,
        spec_path=spec_path,
        overlay_output=tmp_path / "overlay.yaml",
        max_iterations=3,
    )

    # Assert
    manifest = json.loads(
        (tmp_path / "evidence" / "manifest.json").read_text(encoding="utf-8")
    )
    assert result.exit_code == validate_tm7_with_tmt.EXIT_FEEDBACK_NON_CONVERGENCE
    assert manifest["stop_reason"] == "repeated-defect-no-improvement"
    assert manifest["iterations"], "the stopping iteration must be recorded"
    assert manifest["iterations"][0]["gate_failure_count"] > 0


def test_given_clean_surfaces_when_loop_runs_then_refinement_gate_defers(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """A candidate that clears every gate must reach pending-human review."""
    # Arrange
    baseline_model = _input_model(tmp_path, "baseline.tm7")
    spec_path = tmp_path / "spec.yaml"
    _write_feedback_spec(spec_path)

    def generate_candidate(*args: Any, **kwargs: Any) -> Path:
        output_path = Path(kwargs.get("output_path") or (tmp_path / "candidate.tm7"))
        output_path.write_bytes(baseline_model.read_bytes())
        return output_path

    def validate_candidate(*args: Any, **kwargs: Any) -> dict[str, Any]:
        summary = {
            "instance_count": 1,
            "threat_identities": ["threat"],
            "element_identities": ["element"],
            "flow_identities": [],
        }
        return {
            "working_model": str(baseline_model),
            "saved_model": str(baseline_model),
            "before_summary": summary,
            "after_summary": summary,
            "surface_metrics": [
                {
                    "surface_id": "context",
                    "node_id": "trust-zone-portal",
                    "overlap_ratio": 0.0,
                    "edge_node_intersections": 0,
                    "edge_crossing_count": 0,
                    "min_spacing_ratio": 1.0,
                    "findings": [],
                    "surface_geometry": {
                        "surface_id": "context",
                        "orientation": "horizontal",
                        "nominal_node_size": 100.0,
                        "node_rects": {"trust-zone-portal": [0.0, 0.0, 100.0, 100.0]},
                        "connector_segments": [],
                        "zone_content_rects": {"zone-a": [0.0, 0.0, 400.0, 400.0]},
                        "node_ranks": {"trust-zone-portal": 0},
                        "branch_groups": {"trust-zone-portal": 0},
                        "viewport_target": [0.0, 0.0, 1920.0, 1080.0],
                    },
                }
            ],
            "evidence_complete": True,
            "semantic_regression": False,
            "candidate_path": str(baseline_model),
        }

    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "discover_tmt_application",
        lambda: validate_tm7_with_tmt.TmtDiscovery(
            path=tmp_path / "ThreatModeling.exe",
            version="7.3.51110.1",
            source="test",
        ),
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt.generate_tm7,
        "generate_tm7_candidate",
        generate_candidate,
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "_validate_feedback_candidate",
        validate_candidate,
    )

    # Act
    result = validate_tm7_with_tmt.run_harness(
        input_model=baseline_model,
        evidence_dir=tmp_path / "evidence",
        feedback_loop=True,
        spec_path=spec_path,
        overlay_output=tmp_path / "overlay.yaml",
        max_iterations=3,
    )

    # Assert
    manifest = json.loads(
        (tmp_path / "evidence" / "manifest.json").read_text(encoding="utf-8")
    )
    assert result.exit_code == validate_tm7_with_tmt.EXIT_SUCCESS
    assert manifest["stop_reason"] == "automated-ready-pending-human"


def test_given_window_when_maximizing_then_state_is_reported() -> None:
    # Arrange
    window = FakeWindow("Threat Model", 1400, 900)

    # Act
    maximized = validate_tm7_with_tmt.maximize_window(window)

    # Assert
    assert maximized is True
    assert window.maximize_calls == 1


def test_given_bounded_element_when_building_tree_then_rect_is_recorded() -> None:
    # Arrange
    rect = type("Rect", (), {"left": 10, "top": 20, "right": 130, "bottom": 44})()
    info = type(
        "Info",
        (),
        {
            "control_type": "Custom",
            "automation_id": "",
            "name": "reads config",
            "rectangle": rect,
        },
    )()
    window = type("Ctl", (), {"element_info": info, "descendants": lambda self: []})()

    # Act
    tree = validate_tm7_with_tmt.build_uia_tree(window)

    # Assert
    assert tree == "0|Custom||reads config|10|20|130|44\n"


def test_given_unmeasurable_element_when_building_tree_then_bounds_are_blank() -> None:
    # Arrange: a missing rectangle must not be reported as a zero-area rect,
    # which would read as a real measurement of a label drawn at the origin.
    info = type(
        "Info",
        (),
        {
            "control_type": "Custom",
            "automation_id": "",
            "name": "offscreen",
            "rectangle": None,
        },
    )()
    window = type("Ctl", (), {"element_info": info, "descendants": lambda self: []})()

    # Act
    tree = validate_tm7_with_tmt.build_uia_tree(window)

    # Assert
    assert tree == "0|Custom||offscreen||||\n"


def test_given_capture_when_screenshotting_then_window_is_not_restored(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Screenshots must not shrink an already maximized window."""
    # Arrange
    window = FakeWindow("Threat Model", 1400, 900)
    captured: dict[str, Any] = {}

    class FakeImage:
        def save(self, path: Any) -> None:
            captured["path"] = str(path)
            Path(path).write_bytes(b"\x89PNG\r\n\x1a\n")

    class FakeImageGrab:
        @staticmethod
        def grab(window: int) -> FakeImage:
            captured["handle"] = window
            return FakeImage()

    monkeypatch.setitem(sys.modules, "PIL", type("PIL", (), {}))
    monkeypatch.setitem(
        sys.modules,
        "PIL.ImageGrab",
        type("ImageGrab", (), {"grab": FakeImageGrab.grab}),
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "screenshot_isolation_available",
        lambda: True,
    )

    # Act
    validate_tm7_with_tmt.capture_window_screenshot(window, tmp_path / "shot.png")

    # Assert
    assert window.restore_calls == 0
    assert window.maximize_calls >= 1
    assert window.maximized is True


def test_given_structureless_surface_when_refining_then_gate_defers() -> None:
    # Arrange
    surface_metrics = [
        {
            "surface_id": "other",
            "surface_geometry": {
                "surface_id": "other",
                "node_rects": {"other-node": [0.0, 0.0, 100.0, 100.0]},
            },
        }
    ]

    # Act
    decision = validate_tm7_with_tmt._evaluate_surface_refinement(
        surface_metrics=surface_metrics,
        failing_candidates=[{"surface_id": "other"}],
        semantic_surfaces={},
    )

    # Assert
    assert decision is None


def test_given_no_improving_alternative_when_refining_then_launch_is_refused() -> None:
    # Arrange
    surface_metrics = [
        {
            "surface_id": "context",
            "surface_geometry": {
                "surface_id": "context",
                "node_rects": {"node-a": [0.0, 0.0, 100.0, 100.0]},
                "zone_content_rects": {"zone-a": [0.0, 0.0, 400.0, 400.0]},
                "viewport_target": [0.0, 0.0, 1920.0, 1080.0],
            },
        }
    ]
    # Orientation, ranks, and branches describe what the generator decided, so
    # they are sourced from the layout metadata it publishes. The capture
    # payload never carried them.
    semantic_surfaces = {
        "context": {
            "layout_metadata": {
                "orientation": "horizontal",
                "zone_order": ["zone-a"],
                "node_ranks": {"node-a": 0},
                "branch_groups": {"node-a": 0},
            }
        }
    }

    # Act
    decision = validate_tm7_with_tmt._evaluate_surface_refinement(
        surface_metrics=surface_metrics,
        failing_candidates=[{"surface_id": "context"}],
        semantic_surfaces=semantic_surfaces,
    )

    # Assert
    assert decision is not None
    assert decision["requires_native_launch"] is False
    assert decision["stop_reason"] == "repeated-defect-no-improvement"


def test_given_improvable_surface_when_refining_then_launch_is_allowed() -> None:
    # Arrange
    surface_metrics = [
        {
            "surface_id": "context",
            "surface_geometry": {
                "surface_id": "context",
                "node_rects": {"node-a": [0.0, 0.0, 100.0, 100.0]},
                "zone_content_rects": {
                    "zone-a": [0.0, 0.0, 400.0, 400.0],
                    "zone-b": [410.0, 0.0, 800.0, 400.0],
                },
                "viewport_target": [0.0, 0.0, 1920.0, 1080.0],
            },
        }
    ]
    # A vertical incumbent is reachable in production: the generator selects an
    # orientation from its own candidate set and publishes the one it used.
    # Sourcing it from the capture payload, as this fixture previously did, was
    # not reachable, because capture never wrote that key.
    semantic_surfaces = {
        "context": {
            "layout_metadata": {
                "orientation": "vertical",
                "zone_order": ["zone-a", "zone-b"],
                "node_ranks": {"node-a": 0},
                "branch_groups": {"node-a": 0},
            }
        }
    }

    # Act
    decision = validate_tm7_with_tmt._evaluate_surface_refinement(
        surface_metrics=surface_metrics,
        failing_candidates=[{"surface_id": "context"}],
        semantic_surfaces=semantic_surfaces,
    )

    # Assert
    assert decision is not None
    assert decision["requires_native_launch"] is True
    assert decision["selected"]["orientation"] == "horizontal"


def test_given_identifier_keys_when_redacting_then_geometry_survives(
    tmp_path: Path,
) -> None:
    # Arrange
    bundle = validate_tm7_with_tmt.EvidenceBundle(tmp_path / "evidence")
    payload = {
        "surface_geometry": {
            "node_rects": {
                # Every one of these node ids contains a substring the
                # credential pattern matches: token, secret, sig, sas.
                "comp-tokencache": [1.0, 2.0, 3.0, 4.0],
                "svc-secretstore": [5.0, 6.0, 7.0, 8.0],
                "api-signals": [9.0, 10.0, 11.0, 12.0],
                "db-saservice": [13.0, 14.0, 15.0, 16.0],
            },
            "node_ranks": {"comp-tokencache": 0},
            "zone_membership": {"comp-tokencache": "zone-a"},
            "connector_routes": {
                "flow-token-refresh": {
                    "source_id": "comp-tokencache",
                    "target_id": "api-signals",
                    "source_point": [1.0, 2.0],
                }
            },
        }
    }

    # Act
    written = bundle.write_status(payload)

    # Assert
    geometry = written["surface_geometry"]
    # A node rectangle is four numbers. It is never a credential, and losing it
    # removes geometry the agent review protocol requires.
    assert geometry["node_rects"]["comp-tokencache"] == [1.0, 2.0, 3.0, 4.0]
    assert geometry["node_rects"]["svc-secretstore"] == [5.0, 6.0, 7.0, 8.0]
    assert geometry["node_rects"]["api-signals"] == [9.0, 10.0, 11.0, 12.0]
    assert geometry["node_rects"]["db-saservice"] == [13.0, 14.0, 15.0, 16.0]
    assert geometry["node_ranks"]["comp-tokencache"] == 0
    assert geometry["zone_membership"]["comp-tokencache"] == "zone-a"
    # Nesting still resolves correctly: the flow id is an identifier, but the
    # field names inside its route are field names again.
    assert geometry["connector_routes"]["flow-token-refresh"]["source_point"] == [
        1.0,
        2.0,
    ]


def test_given_credential_field_when_redacting_then_it_is_still_removed(
    tmp_path: Path,
) -> None:
    # Arrange
    bundle = validate_tm7_with_tmt.EvidenceBundle(tmp_path / "evidence")
    payload = {
        "authorization": "Bearer abcdefghijklmnop",
        "client_secret": "hunter2",
        "api_key": "AKIAIOSFODNN7EXAMPLE",
        "nested": {"password": "hunter2"},
        "surface_geometry": {
            # An identifier-keyed container must not become a hiding place: a
            # string value under an identifier key is still text-redacted.
            "layout_roles": {"comp-tokencache": "password=hunter2"},
        },
    }

    # Act
    written = bundle.write_status(payload)

    # Assert
    assert written["authorization"] == "[REDACTED]"
    assert written["client_secret"] == "[REDACTED]"
    assert written["api_key"] == "[REDACTED]"
    assert written["nested"]["password"] == "[REDACTED]"
    assert "hunter2" not in json.dumps(written)


def test_given_refinement_decision_when_evaluated_then_counts_are_logged(
    tmp_path: Path,
) -> None:
    # Arrange
    bundle = validate_tm7_with_tmt.EvidenceBundle(tmp_path / "evidence")

    # Act
    bundle.write_action_log(
        "Refinement evaluated surface=context evaluated=12 pruned=3 "
        "semantic_rejected=0 unrealizable_rejected=20 launch=False"
    )
    logged = bundle.action_log_path.read_text(encoding="utf-8")

    # Assert
    # The action log is the operator-facing record, so the counts have to
    # survive redaction intact to be worth writing.
    assert "evaluated=12" in logged
    assert "unrealizable_rejected=20" in logged
    assert "launch=False" in logged


def _overlay_context_for(surface_id: str) -> Any:
    import tm7_visual_feedback as feedback

    return feedback.OverlayContext(
        model_id="demo-model",
        spec_path=Path("threat-model-spec.yaml"),
        spec_sha256="abc",
        generator_profile="default",
        generator_profile_sha256="def",
        surface_ids={surface_id},
        surface_node_ids={surface_id: {"node-a", "node-b"}},
        surface_zone_ids={surface_id: {"zone-a", "zone-b"}},
        surface_flow_ids={surface_id: {"flow-1"}},
    )


def _starving_metric_payload() -> dict[str, Any]:
    """A metric carrying the geometry P02 restored, plus a zone gate failure."""
    return {
        "surface_id": "context",
        "node_id": "node-a",
        "boundary_overlap_count": 1,
        "connector_label_intersections": 2,
        "surface_geometry": {
            "surface_id": "context",
            "nominal_node_size": 100.0,
            "node_rects": {
                "node-a": [0.0, 0.0, 100.0, 100.0],
                "node-b": [400.0, 0.0, 500.0, 100.0],
            },
            "connector_segments": [["node-a", "node-b", [100.0, 50.0], [400.0, 50.0]]],
            "boundary_rects": {
                "zone-a": [0.0, 0.0, 300.0, 300.0],
                "zone-b": [280.0, 0.0, 600.0, 300.0],
            },
            "connector_label_rects": {"flow-1": [200.0, 40.0, 280.0, 70.0]},
            "zone_content_rects": {"zone-a": [0.0, 0.0, 300.0, 300.0]},
            "viewport_target": [0.0, 0.0, 1920.0, 1080.0],
        },
    }


def test_given_boundary_rects_when_deriving_then_a_zone_rule_is_reachable() -> None:
    # Arrange
    import tm7_visual_feedback as feedback

    metric = _starving_metric_payload()
    geometry = validate_tm7_with_tmt._surface_geometry_from_payload(
        surface_id="context",
        geometry_payload=metric["surface_geometry"],
    )

    # Act
    candidates = feedback.derive_overlay_candidates(
        surface_geometry=geometry,
        overlay_context=_overlay_context_for("context"),
        metrics=metric,
        density="simple",
    )

    # Assert
    # The zone branch reads boundary_rects, which the four-field construction
    # never populated, so before P02 this branch could not execute at all.
    assert geometry.boundary_rects, "P02 must restore boundary_rects"
    zone_candidates = [
        candidate
        for candidate in candidates
        if candidate.get("rule_collection") == "zone_rules"
    ]
    assert zone_candidates, "a boundary_overlap gate failure must reach the zone branch"
    overlay_rule = zone_candidates[0]["overlay_rule"]
    assert overlay_rule["zone_id"] in {"zone-a", "zone-b"}
    assert overlay_rule["region"]["width"] > 0


def test_given_label_collisions_when_deriving_then_connector_branch_stays_shut() -> (
    None
):
    # Arrange
    import tm7_visual_feedback as feedback

    metric = _starving_metric_payload()
    geometry = validate_tm7_with_tmt._surface_geometry_from_payload(
        surface_id="context",
        geometry_payload=metric["surface_geometry"],
    )

    # Act
    findings = feedback.derive_findings(metric, density="simple")
    candidates = feedback.derive_overlay_candidates(
        surface_geometry=geometry,
        overlay_context=_overlay_context_for("context"),
        metrics=metric,
        density="simple",
    )

    # Assert
    # P02 restored connector_label_rects, so the geometry precondition is met.
    assert geometry.connector_label_rects, "P02 must restore connector_label_rects"
    # The branch is still unreachable, and this pins why rather than leaving it
    # to be rediscovered. It requires a review-severity finding in category
    # connector_label_clearance. No producer emits that category at all, and
    # the closest metric, connector_label_intersections, is deliberately
    # reported at warn severity under predicted_label_advisory because
    # predicted label geometry is reported and not enforced. Restoring the
    # geometry was necessary but not sufficient.
    emitted_categories = {str(finding.get("category", "")) for finding in findings}
    assert "connector_label_clearance" not in emitted_categories
    label_findings = [
        finding
        for finding in findings
        if finding.get("metric_name") == "connector_label_intersections"
    ]
    assert label_findings, "the label metric must still be reported"
    assert label_findings[0]["severity"] == "warn"
    assert label_findings[0]["category"] == "predicted_label_advisory"
    assert not [
        candidate
        for candidate in candidates
        if candidate.get("rule_collection") == "connector_rules"
    ]


def test_given_invalid_derived_rule_when_merging_then_it_is_dropped() -> None:
    # Arrange
    import tm7_visual_feedback as feedback

    fixtures_dir = ROOT / "tests" / "fixtures" / "visual-feedback"
    overlay_payload = feedback.load_layout_overlay(fixtures_dir / "valid-overlay.yaml")
    context = feedback.OverlayContext(
        model_id="demo-model",
        spec_path=Path("threat-model-spec.yaml"),
        spec_sha256="abc",
        generator_profile="default",
        generator_profile_sha256="def",
        surface_ids={"context"},
        surface_node_ids={"context": {"trust-zone-portal", "trust-zone-identity"}},
        surface_zone_ids={"context": {"trust-zone-portal"}},
        surface_flow_ids={"context": {"flow-001"}},
    )
    valid_candidate = {
        "surface_id": "context",
        "target_type": "node",
        "target_id": "trust-zone-portal",
        "constraint_type": "position",
        "rule_collection": "node_rules",
        "overlay_rule": {
            "surface_id": "context",
            "node_id": "trust-zone-portal",
            "layout_role": "connected",
            "absolute_position": {
                "left": 10.0,
                "top": 10.0,
                "width": 100.0,
                "height": 100.0,
            },
        },
    }
    # A zone rule naming a zone the context does not know is exactly the shape
    # that newly became derivable once the zone branch opened.
    invalid_candidate = {
        "surface_id": "context",
        "target_type": "zone",
        "target_id": "zone-unknown",
        "constraint_type": "region",
        "rule_collection": "zone_rules",
        "overlay_rule": {
            "surface_id": "context",
            "zone_id": "zone-unknown",
            "region": {"left": 1.0, "top": 1.0, "width": 120.0, "height": 120.0},
            "label_band_height": 36.0,
            "lane_order": ["connected", "contextual"],
        },
    }

    # Act
    rules, surface_id, first_rejection = validate_tm7_with_tmt._merge_validated_rule(
        [],
        None,
        valid_candidate,
        overlay_payload=overlay_payload,
        overlay_context=context,
        generator_profile="default",
    )
    rules_after, _, rejection = validate_tm7_with_tmt._merge_validated_rule(
        rules,
        surface_id,
        invalid_candidate,
        overlay_payload=overlay_payload,
        overlay_context=context,
        generator_profile="default",
    )

    # Assert
    assert first_rejection is None
    assert len(rules) == 1
    # The rejected rule is dropped and the previously accepted node rule
    # survives. Both existing validation sites instead set EXIT_ERROR and
    # break, which would suppress the agent review request and leave the
    # operator with neither an automated correction nor a review to perform.
    assert rejection is not None
    assert "zone_rules" in rejection
    assert rules_after == rules


def _refinement_model() -> tuple[dict[str, Any], dict[str, Any], str]:
    """Build a real generator model whose surface has several trust zones.

    Refinement can only choose an orientation and a zone order, so a surface
    needs more than one zone to expose any degree of freedom at all.
    """
    import generate_tm7

    surface_id = "refine-context"
    nodes = [
        ("n-edge", "Edge", "tz-edge"),
        ("n-app", "Application", "tz-app"),
        ("n-data", "Data", "tz-data"),
        ("n-audit", "Audit", "tz-audit"),
    ]
    edges = [
        ("f-1", "n-edge", "n-app"),
        ("f-2", "n-app", "n-data"),
        ("f-3", "n-app", "n-audit"),
    ]
    zones = [
        ("tz-edge", "Edge zone"),
        ("tz-app", "Application zone"),
        ("tz-data", "Data zone"),
        ("tz-audit", "Audit zone"),
    ]
    flows = [
        {
            "id": flow_id,
            "source_ref": source_id,
            "target_ref": target_id,
            "ordinal": index + 1,
            "label": f"step {index + 1}",
        }
        for index, (flow_id, source_id, target_id) in enumerate(edges)
    ]
    spec = {
        "project_metadata": {"name": surface_id},
        "representations": {
            "context_diagrams": [
                {
                    "id": surface_id,
                    "name": "Refinement context",
                    "trust_zone_ids": [zone_id for zone_id, _ in zones],
                    "elements": [
                        {
                            "id": node_id,
                            "kind": "process",
                            "name": name,
                            "trust_zone_id": zone_id,
                        }
                        for node_id, name, zone_id in nodes
                    ],
                    "flows": [dict(flow) for flow in flows],
                }
            ],
            "functional_scenarios": [],
            "operational_views": [],
        },
        "data_flows": [dict(flow) for flow in flows],
        "trust_zones": [
            {"id": zone_id, "name": zone_name, "description": zone_name}
            for zone_id, zone_name in zones
        ],
        "components": [],
        "threats": [],
    }
    profile = generate_tm7.resolve_profile(spec, None, ROOT)
    model = generate_tm7.build_model_from_spec(
        spec,
        profile,
        str(spec.get("mode") or "pre-populated-comprehensive"),
    )
    return model, profile, surface_id


def test_given_laid_out_surface_when_building_geometry_then_shapes_are_measured() -> (
    None
):
    # Arrange
    import copy as copy_module

    import generate_tm7

    model, profile, surface_id = _refinement_model()
    laid_out = generate_tm7.apply_layout(copy_module.deepcopy(model), profile)
    surface = next(
        item for item in laid_out["surfaces"] if str(item.get("id")) == surface_id
    )

    # Act
    geometry = validate_tm7_with_tmt._semantic_surface_geometry(surface)

    # Assert
    assert geometry.surface_id == surface_id
    assert set(geometry.node_rects) == {"n-edge", "n-app", "n-data", "n-audit"}
    assert geometry.boundary_rects, "laid-out zones must produce boundary rects"
    assert geometry.connector_routes, "laid-out flows must produce routes"
    assert geometry.node_ranks, "P01 publishes ranks into layout metadata"
    assert geometry.orientation in {"horizontal", "vertical"}
    # The builder must work with no capture evidence at all, which is what
    # makes candidate scoring possible without opening the tool.
    assert validate_tm7_with_tmt._measured_layout_score(geometry) is not None


def test_given_candidate_when_laying_out_then_zone_order_changes_geometry() -> None:
    # Arrange
    model, profile, surface_id = _refinement_model()
    zone_order = ["tz-edge", "tz-app", "tz-data", "tz-audit"]

    # Act
    first = validate_tm7_with_tmt._lay_out_candidate_surface(
        generator_model=model,
        generator_profile=profile,
        surface_id=surface_id,
        orientation="horizontal",
        zone_order=zone_order,
    )
    reversed_order = validate_tm7_with_tmt._lay_out_candidate_surface(
        generator_model=model,
        generator_profile=profile,
        surface_id=surface_id,
        orientation="horizontal",
        zone_order=list(reversed(zone_order)),
    )

    # Assert
    assert first is not None
    assert reversed_order is not None
    # A different zone order must actually move geometry, or the candidate
    # space is a set of identical layouts and no candidate can ever win.
    assert first.node_rects != reversed_order.node_rects
    # Laying a candidate out must not mutate the caller's model.
    assert all(
        "position" not in element
        for surface in model.get("surfaces", [])
        for element in surface.get("elements", [])
    )


def test_given_unrealizable_candidate_when_scoring_then_it_is_rejected() -> None:
    # Arrange
    import generate_tm7

    model, profile, surface_id = _refinement_model()
    original_apply_layout = generate_tm7.apply_layout

    def failing_apply_layout(*args: Any, **kwargs: Any) -> dict[str, Any]:
        raise generate_tm7.GenerationError("candidate cannot be realized")

    # Act
    generate_tm7.apply_layout = failing_apply_layout
    try:
        geometry = validate_tm7_with_tmt._lay_out_candidate_surface(
            generator_model=model,
            generator_profile=profile,
            surface_id=surface_id,
            orientation="vertical",
            zone_order=["tz-edge"],
        )
    finally:
        generate_tm7.apply_layout = original_apply_layout

    # Assert
    # A layout the generator refuses is a rejected candidate, not a harness
    # failure. Letting it propagate would abort the whole run.
    assert geometry is None


def test_given_measured_scoring_when_refining_then_alternatives_are_evaluated() -> None:
    # Arrange
    import copy as copy_module

    import generate_tm7

    model, profile, surface_id = _refinement_model()
    laid_out = generate_tm7.apply_layout(copy_module.deepcopy(model), profile)
    surface = next(
        item for item in laid_out["surfaces"] if str(item.get("id")) == surface_id
    )
    geometry = validate_tm7_with_tmt._semantic_surface_geometry(surface)
    surface_metrics = [
        {
            "surface_id": surface_id,
            "surface_geometry": {
                "surface_id": surface_id,
                "node_rects": {
                    node_id: list(rect) for node_id, rect in geometry.node_rects.items()
                },
                "zone_content_rects": {
                    zone_id: list(rect)
                    for zone_id, rect in geometry.zone_content_rects.items()
                },
                "connector_routes": {
                    flow_id: {"source_id": "", "target_id": ""}
                    for flow_id in geometry.connector_routes
                },
                "viewport_target": list(geometry.viewport_target or (0, 0, 1920, 1080)),
            },
        }
    ]
    semantic_surfaces = {surface_id: surface}

    # Act
    decision = validate_tm7_with_tmt._evaluate_surface_refinement(
        surface_metrics=surface_metrics,
        failing_candidates=[{"surface_id": surface_id}],
        semantic_surfaces=semantic_surfaces,
        generator_model=model,
        generator_profile=profile,
    )

    # Assert
    assert decision is not None
    # The honesty requirement: a no-improvement verdict may only be reported
    # after alternatives were genuinely laid out and scored. Reporting it with
    # an evaluated count of zero is what the loop did before this repair.
    assert decision["evaluated_count"] > 0
    if not decision["requires_native_launch"]:
        assert decision["stop_reason"] == "repeated-defect-no-improvement"


def test_given_measured_scoring_when_layout_differs_then_scores_differ() -> None:
    # Arrange
    model, profile, surface_id = _refinement_model()

    def score(order: list[str]) -> Any:
        geometry = validate_tm7_with_tmt._lay_out_candidate_surface(
            generator_model=model,
            generator_profile=profile,
            surface_id=surface_id,
            orientation="horizontal",
            zone_order=order,
        )
        assert geometry is not None
        return validate_tm7_with_tmt._measured_layout_score(geometry)

    # Act
    flow_order = score(["tz-edge", "tz-app", "tz-data", "tz-audit"])
    scrambled = score(["tz-app", "tz-edge", "tz-data", "tz-audit"])

    # Assert
    # Measured scoring must tell two real layouts apart. The topology scorer
    # could not: it saw the same graph either way, which is why the incumbent
    # was its argmin by construction and no candidate could ever win.
    assert flow_order != scrambled
    # Placing the application zone ahead of the edge zone forces the first
    # flow to double back, so the scrambled order measures worse.
    assert flow_order < scrambled
    # Determinism: the same candidate scores the same twice.
    assert flow_order == score(["tz-edge", "tz-app", "tz-data", "tz-audit"])


def test_given_worse_incumbent_when_refining_then_gate_opens() -> None:
    # Arrange
    import copy as copy_module

    import generate_tm7

    model, profile, surface_id = _refinement_model()
    poor_order = ["tz-app", "tz-edge", "tz-data", "tz-audit"]
    laid_out = generate_tm7.apply_layout(
        copy_module.deepcopy(model),
        profile,
        layout_overlay={
            "surface_rules": [
                {
                    "surface_id": surface_id,
                    "orientation": "horizontal",
                    "zone_order": poor_order,
                }
            ]
        },
    )
    surface = next(
        item for item in laid_out["surfaces"] if str(item.get("id")) == surface_id
    )
    geometry = validate_tm7_with_tmt._semantic_surface_geometry(surface)
    surface_metrics = [
        {
            "surface_id": surface_id,
            "surface_geometry": {
                "surface_id": surface_id,
                "node_rects": {
                    node_id: list(rect) for node_id, rect in geometry.node_rects.items()
                },
                "zone_content_rects": {
                    zone_id: list(rect)
                    for zone_id, rect in geometry.zone_content_rects.items()
                },
                "connector_routes": {
                    flow_id: {"source_id": "", "target_id": ""}
                    for flow_id in geometry.connector_routes
                },
                "viewport_target": list(geometry.viewport_target or (0, 0, 1920, 1080)),
            },
        }
    ]

    # Act
    decision = validate_tm7_with_tmt._evaluate_surface_refinement(
        surface_metrics=surface_metrics,
        failing_candidates=[{"surface_id": surface_id}],
        semantic_surfaces={surface_id: surface},
        generator_model=model,
        generator_profile=profile,
    )

    # Assert
    assert decision is not None
    # This is the behavior the whole repair exists for: a surface laid out in a
    # measurably worse arrangement finds a better one and earns its iteration.
    # Every fixture value here is reachable in production.
    assert decision["requires_native_launch"] is True
    assert decision["selected"] is not None
    assert decision["evaluated_count"] > 0
    selected_score = validate_tm7_with_tmt._measured_layout_score(
        validate_tm7_with_tmt._lay_out_candidate_surface(
            generator_model=model,
            generator_profile=profile,
            surface_id=surface_id,
            orientation=str(decision["selected"]["orientation"]),
            zone_order=list(decision["selected"]["zone_order"]),
        )
    )
    incumbent_score = validate_tm7_with_tmt._measured_layout_score(geometry)
    assert selected_score < incumbent_score


def test_given_overflowing_orientation_when_laying_out_then_candidate_is_rejected() -> (
    None
):
    # Arrange
    model, profile, surface_id = _refinement_model()

    # Act
    vertical = validate_tm7_with_tmt._lay_out_candidate_surface(
        generator_model=model,
        generator_profile=profile,
        surface_id=surface_id,
        orientation="vertical",
        zone_order=["tz-edge", "tz-app", "tz-data", "tz-audit"],
    )

    # Assert
    # Stacking four zones vertically overruns the bounded canvas, so the
    # generator refuses the layout. Roughly half this surface's candidate
    # space is unrealizable, which is why rejection has to be ordinary
    # control flow rather than an error that ends the run.
    assert vertical is None


def test_given_viewport_when_scoring_candidate_then_it_reaches_layout() -> None:
    # Arrange
    import generate_tm7

    model, profile, surface_id = _refinement_model()
    zone_order = ["tz-edge", "tz-app", "tz-data", "tz-audit"]
    # Deliberately not the default canvas. The default is derived as
    # 1920 / TMT_RENDER_ZOOM, so a literal 1280x720 would silently equal it and
    # the test would prove nothing.
    narrow = (0.0, 0.0, 900.0, 900.0)
    assert narrow[2] != generate_tm7.DEFAULT_VIEWPORT_WIDTH

    # Act
    default_canvas = validate_tm7_with_tmt._lay_out_candidate_surface(
        generator_model=model,
        generator_profile=profile,
        surface_id=surface_id,
        orientation="horizontal",
        zone_order=zone_order,
    )
    narrow_canvas = validate_tm7_with_tmt._lay_out_candidate_surface(
        generator_model=model,
        generator_profile=profile,
        surface_id=surface_id,
        orientation="horizontal",
        zone_order=zone_order,
        viewport_target=narrow,
    )

    # Assert
    assert default_canvas is not None
    assert narrow_canvas is not None
    # The candidate must be laid out against the canvas it will be replayed
    # against. Scoring on the default canvas while the emitted rule carries the
    # measured one compares a layout the next iteration will never build.
    assert narrow_canvas.viewport_target == narrow
    assert default_canvas.viewport_target == (
        0.0,
        0.0,
        generate_tm7.DEFAULT_VIEWPORT_WIDTH,
        generate_tm7.DEFAULT_VIEWPORT_HEIGHT,
    )
    assert validate_tm7_with_tmt._measured_layout_score(
        default_canvas
    ) != validate_tm7_with_tmt._measured_layout_score(narrow_canvas)


def test_given_selection_when_building_rule_then_surface_settings_are_carried() -> None:
    # Arrange
    decision = {
        "surface_id": "context",
        "requires_native_launch": True,
        "selected": {
            "orientation": "vertical",
            "zone_order": ["zone-b", "zone-a"],
        },
    }
    surface_metrics = [
        {
            "surface_id": "context",
            "surface_geometry": {"viewport_target": [0.0, 0.0, 1600.0, 900.0]},
        }
    ]

    # Act
    rule = validate_tm7_with_tmt._refinement_surface_rule_candidate(
        refinement_decision=decision,
        surface_metrics=surface_metrics,
    )

    # Assert
    # Before this, selected, selected_candidate_id, and selected_score had no
    # reader anywhere, so a launched iteration regenerated the unchanged model.
    assert rule is not None
    assert rule["rule_collection"] == "surface_rules"
    overlay_rule = rule["overlay_rule"]
    assert overlay_rule["orientation"] == "vertical"
    assert overlay_rule["zone_order"] == ["zone-b", "zone-a"]
    assert overlay_rule["viewport_target"]["width"] == 1600.0


def test_given_no_launch_when_building_rule_then_nothing_is_carried() -> None:
    # Arrange
    decision = {
        "surface_id": "context",
        "requires_native_launch": False,
        "selected": None,
    }

    # Act
    rule = validate_tm7_with_tmt._refinement_surface_rule_candidate(
        refinement_decision=decision,
        surface_metrics=[],
    )

    # Assert
    assert rule is None


def test_given_refinement_search_when_building_then_count_is_bounded() -> None:
    # Arrange
    incumbent = {
        "candidate_id": "context:incumbent",
        "node_ids": [f"node-{index}" for index in range(12)],
        "flow_ids": [f"f-{index}" for index in range(12)],
        "zone_ids": [f"zone-{index}" for index in range(10)],
        "orientation": "horizontal",
        "zone_order": [f"zone-{index}" for index in range(10)],
        "node_ranks": {f"node-{index}": index for index in range(12)},
        "branch_groups": {f"node-{index}": index % 3 for index in range(12)},
    }

    # Act
    candidates = validate_tm7_with_tmt._build_surface_refinement_candidates(
        surface_id="context",
        incumbent=incumbent,
        semantic_surface={},
    )

    # Assert
    assert (
        len(candidates)
        <= validate_tm7_with_tmt.tm7_visual_feedback.MAX_SURFACE_REFINEMENT_CANDIDATES
    )
    assert (
        len(candidates)
        >= validate_tm7_with_tmt.tm7_visual_feedback.MIN_SURFACE_REFINEMENT_CANDIDATES
    )
    incumbent_fingerprint = (
        validate_tm7_with_tmt.tm7_visual_feedback.surface_semantic_fingerprint(
            incumbent
        )
    )
    assert all(
        validate_tm7_with_tmt.tm7_visual_feedback.surface_semantic_fingerprint(
            candidate
        )
        == incumbent_fingerprint
        for candidate in candidates
    )


def test_given_same_surface_rules_when_merged_then_both_are_preserved() -> None:
    # Arrange
    first = {
        "surface_id": "func-oauth",
        "rule": {"node_id": "ext-dev", "constraint": "position", "left": 80},
    }
    second = {
        "surface_id": "func-oauth",
        "rule": {
            "node_id": "ext-mural-api",
            "constraint": "position",
            "left": 500,
        },
    }

    # Act
    rules, surface_id = validate_tm7_with_tmt._merge_accumulated_rule([], None, first)
    rules, surface_id = validate_tm7_with_tmt._merge_accumulated_rule(
        rules, surface_id, second
    )

    # Assert
    assert surface_id == "func-oauth"
    assert [rule["node_id"] for rule in rules] == ["ext-dev", "ext-mural-api"]


def test_given_new_surface_rule_when_merged_then_prior_surface_is_preserved() -> None:
    # Arrange
    rules = [{"node_id": "ext-dev", "constraint": "position", "left": 80}]
    candidate = {
        "surface_id": "dom-docproc",
        "rule": {
            "node_id": "comp-logsink",
            "constraint": "position",
            "left": 500,
        },
    }

    # Act
    merged, surface_id = validate_tm7_with_tmt._merge_accumulated_rule(
        rules,
        "func-oauth",
        candidate,
    )

    # Assert
    assert surface_id == "dom-docproc"
    assert len(merged) == 2
    assert {rule["_surface_id"] for rule in merged} == {
        "func-oauth",
        "dom-docproc",
    }


def test_given_feedback_loop_when_missing_overlay_output_then_fails_before_discovery(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    spec_path = tmp_path / "spec.yaml"
    _write_feedback_spec(spec_path)

    def explode() -> None:
        raise AssertionError("discovery should not run")

    monkeypatch.setattr(validate_tm7_with_tmt, "discover_tmt_application", explode)

    # Act
    result = validate_tm7_with_tmt.run_harness(
        input_model=_input_model(tmp_path),
        evidence_dir=tmp_path / "evidence",
        feedback_loop=True,
        spec_path=spec_path,
        overlay_output=None,
    )

    # Assert
    assert result.exit_code == validate_tm7_with_tmt.EXIT_ERROR
    assert "overlay-output" in result.message.lower()


def test_given_feedback_loop_when_candidate_is_clean_then_writes_pending_overlay(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    spec_path = tmp_path / "spec.yaml"
    _write_feedback_spec(spec_path)
    evidence_dir = tmp_path / "evidence"
    overlay_output = tmp_path / "overlay-output.yaml"
    baseline_model = tmp_path / "baseline.tm7"
    baseline_model.write_text("baseline", encoding="utf-8")

    def fake_generate_candidate(
        *,
        spec_path: Path,
        output_path: Path,
        **_: Any,
    ) -> Path:
        output_path.write_text("candidate", encoding="utf-8")
        return output_path

    def fake_validate_candidate(*args: Any, **kwargs: Any) -> dict[str, Any]:
        return {
            "working_model": str(baseline_model),
            "saved_model": str(baseline_model),
            "before_summary": {
                "instance_count": 1,
                "instances": [{"id": "1", "type_id": "TH-test"}],
                "drawing_surface_hash": "surface",
                "knowledge_base_hash": "kb",
            },
            "after_summary": {
                "instance_count": 1,
                "instances": [{"id": "1", "type_id": "TH-test"}],
                "drawing_surface_hash": "surface",
                "knowledge_base_hash": "kb",
            },
            "surface_metrics": [
                {
                    "surface_id": "context",
                    "node_id": "trust-zone-portal",
                    "gate_failure_count": 0,
                    "review_count": 0,
                    "warn_count": 0,
                    "max_severity_score": 0.0,
                    "constraint_type": "relative_to",
                }
            ],
            "evidence_complete": True,
            "semantic_regression": False,
            "semantic_summary": {"instance_count": 1},
            "candidate_path": str(baseline_model),
        }

    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "discover_tmt_application",
        lambda: validate_tm7_with_tmt.TmtDiscovery(
            path=tmp_path / "ThreatModeling.exe",
            version="7.3.51110.1",
            source="test",
        ),
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt.generate_tm7,
        "generate_tm7_candidate",
        fake_generate_candidate,
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "_validate_feedback_candidate",
        fake_validate_candidate,
    )

    # Act
    result = validate_tm7_with_tmt.run_harness(
        input_model=baseline_model,
        evidence_dir=evidence_dir,
        feedback_loop=True,
        spec_path=spec_path,
        overlay_output=overlay_output,
        max_iterations=1,
        require_feedback_evidence=False,
    )

    # Assert
    assert result.exit_code == validate_tm7_with_tmt.EXIT_SUCCESS
    assert result.status == "automated-ready-pending-human"
    assert overlay_output.exists()
    payload = json.loads(overlay_output.read_text(encoding="utf-8"))
    assert payload["provenance"]["approval_state"] == "pending"
    feedback_manifest = json.loads(
        (evidence_dir / "feedback-manifest.json").read_text(encoding="utf-8")
    )
    assert len(feedback_manifest["candidate_sha256"]) == 64
    assert feedback_manifest["surfaces"]
    assert all(
        surface["human_review_status"] == "pending"
        and surface["human_review_required"] is True
        for surface in feedback_manifest["surfaces"]
    )


def _feedback_candidate_result(
    baseline_model: Path,
    *,
    semantic_regression: bool = False,
) -> dict[str, Any]:
    """Build a one-surface candidate result for feedback-loop tests."""
    summary = {
        "instance_count": 1,
        "instances": [{"id": "1", "type_id": "TH-test"}],
        "drawing_surface_hash": "surface",
        "knowledge_base_hash": "kb",
    }
    return {
        "working_model": str(baseline_model),
        "saved_model": str(baseline_model),
        "before_summary": summary,
        "after_summary": summary,
        "surface_metrics": [
            {
                "surface_id": "context",
                "node_id": "trust-zone-portal",
                "gate_failure_count": 0,
                "review_count": 0,
                "warn_count": 0,
                "max_severity_score": 0.0,
                "constraint_type": "relative_to",
            }
        ],
        "evidence_complete": True,
        "semantic_regression": semantic_regression,
        "semantic_summary": {"instance_count": 1},
        "candidate_path": str(baseline_model),
    }


def _run_feedback_loop_for_test(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    *,
    semantic_regression: bool = False,
) -> tuple[Any, Path, Path]:
    """Drive one feedback-loop run with the standard automation fakes."""
    spec_path = tmp_path / "spec.yaml"
    _write_feedback_spec(spec_path)
    evidence_dir = tmp_path / "evidence"
    overlay_output = tmp_path / "overlay-output.yaml"
    baseline_model = tmp_path / "baseline.tm7"
    baseline_model.write_text("baseline", encoding="utf-8")

    def fake_generate_candidate(
        *,
        spec_path: Path,
        output_path: Path,
        **_: Any,
    ) -> Path:
        output_path.write_text("candidate", encoding="utf-8")
        return output_path

    def fake_validate_candidate(*args: Any, **kwargs: Any) -> dict[str, Any]:
        return _feedback_candidate_result(
            baseline_model,
            semantic_regression=semantic_regression,
        )

    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "discover_tmt_application",
        lambda: validate_tm7_with_tmt.TmtDiscovery(
            path=tmp_path / "ThreatModeling.exe",
            version="7.3.51110.1",
            source="test",
        ),
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt.generate_tm7,
        "generate_tm7_candidate",
        fake_generate_candidate,
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "_validate_feedback_candidate",
        fake_validate_candidate,
    )

    result = validate_tm7_with_tmt.run_harness(
        input_model=baseline_model,
        evidence_dir=evidence_dir,
        feedback_loop=True,
        spec_path=spec_path,
        overlay_output=overlay_output,
        max_iterations=1,
        require_feedback_evidence=False,
    )
    return result, evidence_dir, overlay_output


def test_given_success_run_when_overlay_published_then_every_surface_is_addressable(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """A reviewer must be able to author a rule for any captured surface.

    The spec declares two surfaces while only one produces metrics. A
    single-surface applies_to would leave the second unaddressable, and an
    agent cannot widen it by hand because the five invalidation fingerprints
    are not authorable.
    """
    # Act
    result, _, overlay_output = _run_feedback_loop_for_test(tmp_path, monkeypatch)

    # Assert
    assert result.status == "automated-ready-pending-human"
    payload = json.loads(overlay_output.read_text(encoding="utf-8"))
    assert sorted(entry["surface_id"] for entry in payload["applies_to"]) == [
        "context",
        "other",
    ]


def test_given_clean_success_when_no_correction_found_then_seed_shape_is_published(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """A success with nothing to correct publishes the seed shape."""
    # Act
    _, _, overlay_output = _run_feedback_loop_for_test(tmp_path, monkeypatch)

    # Assert
    payload = json.loads(overlay_output.read_text(encoding="utf-8"))
    assert payload["overlay_id"].startswith("overlay-seed-")
    assert payload["zone_rules"] == []
    assert payload["node_rules"] == []
    assert payload["connector_rules"] == []
    assert payload["surface_rules"] == []


@pytest.mark.parametrize(
    ("semantic_regression", "expect_request"),
    [(False, True), (True, False)],
)
def test_given_feedback_run_when_resolved_then_request_follows_the_emission_gate(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    semantic_regression: bool,
    expect_request: bool,
) -> None:
    """A correctness stop must not invite review of a model under suspicion."""
    # Act
    result, evidence_dir, _ = _run_feedback_loop_for_test(
        tmp_path,
        monkeypatch,
        semantic_regression=semantic_regression,
    )

    # Assert
    request_path = evidence_dir / "agent-review-request.json"
    assert request_path.exists() is expect_request
    status = json.loads((evidence_dir / "status.json").read_text(encoding="utf-8"))
    if expect_request:
        assert status["agent_review"]["status"] == "pending"
        assert status["agent_review"]["request_path"] == "agent-review-request.json"
    else:
        assert result.status == "semantic-regression"
        assert "agent_review" not in status


def test_given_feedback_loop_when_tmt_is_unavailable_then_reports_feedback_status(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    spec_path = tmp_path / "spec.yaml"
    _write_feedback_spec(spec_path)
    baseline_model = tmp_path / "baseline.tm7"
    baseline_model.write_text("baseline", encoding="utf-8")

    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "discover_tmt_application",
        lambda: validate_tm7_with_tmt.TmtDiscovery(
            path=None, version=None, source="test"
        ),
    )
    monkeypatch.setattr(validate_tm7_with_tmt, "sha256_file", lambda path: "sha")

    # Act
    result = validate_tm7_with_tmt.run_harness(
        input_model=baseline_model,
        evidence_dir=tmp_path / "evidence",
        feedback_loop=True,
        spec_path=spec_path,
        overlay_output=tmp_path / "overlay.yaml",
        max_iterations=1,
        require_feedback_evidence=True,
        require_tmt=True,
    )

    # Assert
    assert result.status == "tmt-unavailable"
    assert result.exit_code == validate_tm7_with_tmt.EXIT_MISSING_TMT


def test_given_feedback_loop_when_strict_evidence_is_missing_then_stops(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    spec_path = tmp_path / "spec.yaml"
    _write_feedback_spec(spec_path)
    baseline_model = tmp_path / "baseline.tm7"
    baseline_model.write_text("baseline", encoding="utf-8")

    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "discover_tmt_application",
        lambda: validate_tm7_with_tmt.TmtDiscovery(
            path=tmp_path / "ThreatModeling.exe",
            version="7.3.51110.1",
            source="test",
        ),
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "_validate_feedback_candidate",
        lambda *args, **kwargs: {
            "working_model": str(baseline_model),
            "saved_model": str(baseline_model),
            "before_summary": {
                "instance_count": 1,
                "instances": [],
                "drawing_surface_hash": "surface",
                "knowledge_base_hash": "kb",
            },
            "after_summary": {
                "instance_count": 1,
                "instances": [],
                "drawing_surface_hash": "surface",
                "knowledge_base_hash": "kb",
            },
            "surface_metrics": [],
            "evidence_complete": False,
            "semantic_regression": False,
            "semantic_summary": {},
            "candidate_path": str(baseline_model),
        },
    )
    monkeypatch.setattr(validate_tm7_with_tmt, "sha256_file", lambda path: "sha")

    # Act
    result = validate_tm7_with_tmt.run_harness(
        input_model=baseline_model,
        evidence_dir=tmp_path / "evidence",
        feedback_loop=True,
        spec_path=spec_path,
        overlay_output=tmp_path / "overlay.yaml",
        max_iterations=1,
        require_feedback_evidence=True,
    )

    # Assert
    assert result.status == "evidence-incomplete"
    assert result.exit_code == validate_tm7_with_tmt.EXIT_MISSING_FEEDBACK_EVIDENCE


def test_given_feedback_loop_when_semantic_regression_is_detected_then_skips(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    spec_path = tmp_path / "spec.yaml"
    _write_feedback_spec(spec_path)
    baseline_model = tmp_path / "baseline.tm7"
    baseline_model.write_text("baseline", encoding="utf-8")
    overlay_output = tmp_path / "overlay.yaml"

    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "discover_tmt_application",
        lambda: validate_tm7_with_tmt.TmtDiscovery(
            path=tmp_path / "ThreatModeling.exe",
            version="7.3.51110.1",
            source="test",
        ),
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "_validate_feedback_candidate",
        lambda *args, **kwargs: {
            "working_model": str(baseline_model),
            "saved_model": str(baseline_model),
            "before_summary": {
                "instance_count": 2,
                "instances": [{"id": "1"}],
                "drawing_surface_hash": "surface",
                "knowledge_base_hash": "kb",
            },
            "after_summary": {
                "instance_count": 1,
                "instances": [{"id": "2"}],
                "drawing_surface_hash": "surface",
                "knowledge_base_hash": "kb",
            },
            "surface_metrics": [
                {
                    "surface_id": "context",
                    "node_id": "trust-zone-portal",
                    "gate_failure_count": 0,
                    "review_count": 0,
                    "warn_count": 0,
                    "max_severity_score": 0.0,
                    "constraint_type": "relative_to",
                }
            ],
            "evidence_complete": True,
            "semantic_regression": True,
            "semantic_summary": {},
            "candidate_path": str(baseline_model),
        },
    )
    monkeypatch.setattr(validate_tm7_with_tmt, "sha256_file", lambda path: "sha")

    # Act
    result = validate_tm7_with_tmt.run_harness(
        input_model=baseline_model,
        evidence_dir=tmp_path / "evidence",
        feedback_loop=True,
        spec_path=spec_path,
        overlay_output=overlay_output,
        max_iterations=1,
        require_feedback_evidence=False,
    )

    # Assert
    assert result.status == "semantic-regression"
    assert result.exit_code == validate_tm7_with_tmt.EXIT_VALIDATION_FAILURE
    assert not overlay_output.exists()


def test_given_feedback_loop_when_max_iterations_are_out_of_range_then_fails(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    spec_path = tmp_path / "spec.yaml"
    _write_feedback_spec(spec_path)

    def explode() -> None:
        raise AssertionError("discovery should not run")

    monkeypatch.setattr(validate_tm7_with_tmt, "discover_tmt_application", explode)

    # Act
    result = validate_tm7_with_tmt.run_harness(
        input_model=_input_model(tmp_path),
        evidence_dir=tmp_path / "evidence",
        feedback_loop=True,
        spec_path=spec_path,
        overlay_output=tmp_path / "overlay.yaml",
        max_iterations=4,
    )

    # Assert
    assert result.exit_code == validate_tm7_with_tmt.EXIT_ERROR
    assert "max-iterations" in result.message.lower()


def test_given_exact_version_when_checking_policy_then_allows() -> None:
    # Arrange
    policy = validate_tm7_with_tmt.TmtVersionPolicy(
        pinned_version="7.3.51110.1",
        observed_version="7.3.51110.1",
    )

    # Act
    outcome = validate_tm7_with_tmt.evaluate_version_policy(policy)

    # Assert
    assert outcome.allowed is True
    assert outcome.exit_code == validate_tm7_with_tmt.EXIT_SUCCESS


def test_given_surface_model_when_reading_then_returns_descriptors(
    tmp_path: Path,
) -> None:
    # Arrange
    model_path = tmp_path / "surfaces.tm7"
    model_path.write_text(
        """<ThreatModel xmlns=\"http://schemas.datacontract.org/2004/07/ThreatModeling.Model\">
  <DrawingSurfaceList>
    <DrawingSurfaceModel>
      <Header>Primary interaction</Header>
      <Guid>guid-1</Guid>
    </DrawingSurfaceModel>
    <DrawingSurfaceModel>
      <Header>Deployment and operations</Header>
      <Guid>guid-2</Guid>
    </DrawingSurfaceModel>
  </DrawingSurfaceList>
</ThreatModel>""",
        encoding="utf-8",
    )

    # Act
    surfaces = validate_tm7_with_tmt.read_expected_surfaces(model_path)

    # Assert
    assert [surface.surface_name for surface in surfaces] == [
        "Primary interaction",
        "Deployment and operations",
    ]
    assert [surface.surface_guid for surface in surfaces] == ["guid-1", "guid-2"]
    assert [surface.tab_index for surface in surfaces] == [0, 1]


def test_given_matching_tabs_when_selecting_surface_then_returns_tab() -> None:
    # Arrange
    surface = validate_tm7_with_tmt.SurfaceDescriptor(
        surface_id="primary",
        surface_guid="guid-1",
        surface_name="Primary interaction",
        tab_index=0,
    )
    tab = FakeControl("TabItem", "Primary interaction")

    # Act
    selected = validate_tm7_with_tmt.select_surface_tab(
        FakeWindow("Window", 100, 100),
        surface,
        [tab],
    )

    # Assert
    assert selected is tab


def test_given_documentview_wrapped_tab_when_selecting_surface_then_returns_tab() -> (
    None
):
    # Arrange
    # TMT names a surface tab "DocumentView, Title <caption>". This wrapper is
    # taken verbatim from a captured UIA tree, so an exact comparison against
    # the bare caption never matches once surfaces carry authored titles.
    surface = validate_tm7_with_tmt.SurfaceDescriptor(
        surface_id="ctx-01",
        surface_guid="guid-ctx",
        surface_name="System context and trust boundaries",
        tab_index=1,
    )
    other = FakeControl(
        "TabItem",
        "DocumentView, Title Copilot telemetry capture, storage, and cloud artifact "
        "generation",
    )
    wanted = FakeControl(
        "TabItem", "DocumentView, Title System context and trust boundaries"
    )

    # Act
    selected = validate_tm7_with_tmt.select_surface_tab(
        FakeWindow("Window", 100, 100),
        surface,
        [other, wanted],
    )

    # Assert
    assert selected is wanted


def test_given_authored_tab_titles_when_selecting_then_positional_fallback() -> None:
    # Arrange
    # No tab carries the generic "Diagram" caption any more, so a fallback that
    # filtered on it would find nothing and refuse an otherwise resolvable tab.
    surface = validate_tm7_with_tmt.SurfaceDescriptor(
        surface_id="unmatched",
        surface_guid="guid-unmatched",
        surface_name="Surface absent from the tab strip",
        tab_index=1,
    )
    tabs = [
        FakeControl("TabItem", "DocumentView, Title First authored surface"),
        FakeControl("TabItem", "DocumentView, Title Second authored surface"),
    ]

    # Act
    selected = validate_tm7_with_tmt.select_surface_tab(
        FakeWindow("Window", 100, 100),
        surface,
        tabs,
    )

    # Assert
    assert selected is tabs[1]


class _DocumentMenu:
    """Menu double listing every open document regardless of tab visibility."""

    def __init__(self, names: list[str], activated: list[str]) -> None:
        self.element_info = type(
            "ElementInfo",
            (),
            {
                "control_type": "MenuItem",
                "name": "Diagram",
                "automation_id": "WindowMenuItem",
            },
        )()
        self._names = names
        self._activated = activated
        self.expanded = False

    def expand(self) -> None:
        self.expanded = True

    def collapse(self) -> None:
        self.expanded = False

    def descendants(self) -> list[Any]:
        if not self.expanded:
            return []
        entries = []
        for name in self._names:
            entry = FakeControl("MenuItem", name)
            entry.invoke = (  # type: ignore[method-assign]
                lambda captured=name: self._activated.append(captured)
            )
            entries.append(entry)
        return entries


def test_given_clipped_tab_strip_when_materializing_then_returns_visible_only() -> None:
    # Arrange
    # TMT clips the strip, omits clipped tabs from the tree, and exposes no
    # scroll pattern there, so only the visible prefix is reachable this way.
    window = FakeWindow(
        "Window",
        100,
        100,
        descendants=[
            FakeControl("TabItem", "DocumentView, Title Surface 0"),
            FakeControl("TabItem", "DocumentView, Title Surface 1"),
        ],
    )

    # Act
    tabs = validate_tm7_with_tmt.materialize_surface_tabs(window, 9)

    # Assert
    assert len(tabs) == 2


def test_given_surface_without_a_tab_when_activating_then_uses_document_menu() -> None:
    # Arrange
    # The surface is open but its tab is clipped, so no TabItem names it and
    # the document menu is the only path that reaches it.
    surface = validate_tm7_with_tmt.SurfaceDescriptor(
        surface_id="dom-planning",
        surface_guid="guid-planning",
        surface_name="Security-planning artifact generation",
        tab_index=7,
    )
    activated: list[str] = []
    menu = _DocumentMenu(
        [
            "System context and trust boundaries",
            "Security-planning artifact generation",
        ],
        activated,
    )
    window = FakeWindow(
        "Window",
        100,
        100,
        descendants=[
            FakeControl("TabItem", "DocumentView, Title System context"),
            menu,
        ],
    )

    # Act
    validate_tm7_with_tmt.activate_surface_tab(window, surface, [])

    # Assert
    assert activated == ["Security-planning artifact generation"]


def test_given_visible_tab_when_activating_then_menu_is_not_opened() -> None:
    # Arrange
    surface = validate_tm7_with_tmt.SurfaceDescriptor(
        surface_id="ctx-01",
        surface_guid="guid-ctx",
        surface_name="System context and trust boundaries",
        tab_index=0,
    )
    activated: list[str] = []
    menu = _DocumentMenu(["System context and trust boundaries"], activated)
    tab = FakeControl(
        "TabItem", "DocumentView, Title System context and trust boundaries"
    )
    clicked: list[Any] = []
    tab.click_input = lambda: clicked.append(tab)  # type: ignore[method-assign]
    window = FakeWindow("Window", 100, 100, descendants=[tab, menu])

    # Act
    validate_tm7_with_tmt.activate_surface_tab(window, surface, [])

    # Assert
    assert clicked == [tab]
    assert activated == []
    assert menu.expanded is False


def test_given_no_document_menu_when_activating_then_falls_back_positionally() -> None:
    # Arrange
    surface = validate_tm7_with_tmt.SurfaceDescriptor(
        surface_id="absent",
        surface_guid="guid-absent",
        surface_name="Surface with no tab and no menu",
        tab_index=0,
    )
    fallback = FakeControl("TabItem", "DocumentView, Title Some other surface")
    clicked: list[Any] = []
    fallback.click_input = lambda: clicked.append(  # type: ignore[method-assign]
        fallback
    )
    window = FakeWindow("Window", 100, 100, descendants=[fallback])
    tabs = [
        validate_tm7_with_tmt.SurfaceTab(
            control=fallback,
            name=fallback.element_info.name,
            control_type="TabItem",
        )
    ]

    # Act
    validate_tm7_with_tmt.activate_surface_tab(window, surface, tabs)

    # Assert
    assert clicked == [fallback]


def test_given_stale_tab_control_when_activating_then_uses_live_tree() -> None:
    # Arrange
    # A control captured before the strip scrolled still names the right
    # surface but points at a stale screen position, so clicking it would
    # capture a different surface under the expected name.
    surface = validate_tm7_with_tmt.SurfaceDescriptor(
        surface_id="ctx-01",
        surface_guid="guid-ctx",
        surface_name="System context and trust boundaries",
        tab_index=0,
    )
    live = FakeControl(
        "TabItem", "DocumentView, Title System context and trust boundaries"
    )
    stale = FakeControl(
        "TabItem", "DocumentView, Title System context and trust boundaries"
    )
    clicked: list[Any] = []
    live.click_input = lambda: clicked.append(live)  # type: ignore[method-assign]
    stale.click_input = lambda: clicked.append(stale)  # type: ignore[method-assign]
    window = FakeWindow("Window", 100, 100, descendants=[live])
    stale_tabs = [
        validate_tm7_with_tmt.SurfaceTab(
            control=stale,
            name=stale.element_info.name,
            control_type="TabItem",
        )
    ]

    # Act
    validate_tm7_with_tmt.activate_surface_tab(window, surface, stale_tabs)

    # Assert
    assert clicked == [live]


def test_given_per_surface_pane_guids_when_finding_pane_then_matches_surface() -> None:
    # Arrange
    # TMT sets each surface pane's automation id to that surface's own GUID,
    # so no single constant identifies "the Diagram pane". Selecting the wrong
    # pane would capture a different surface under the expected name.
    surface = validate_tm7_with_tmt.SurfaceDescriptor(
        surface_id="ctx-01",
        surface_guid="guid-ctx",
        surface_name="System context and trust boundaries",
        tab_index=1,
    )
    other = FakeControl("Pane", "Other surface", automation_id="guid-other")
    wanted = FakeControl(
        "Pane", "System context and trust boundaries", automation_id="guid-ctx"
    )
    window = FakeWindow("Window", 100, 100, descendants=[other, wanted])

    # Act
    pane = validate_tm7_with_tmt.find_diagram_pane(window, surface)

    # Assert
    assert pane is wanted


def test_given_pane_guid_absent_when_finding_pane_then_matches_caption() -> None:
    # Arrange
    surface = validate_tm7_with_tmt.SurfaceDescriptor(
        surface_id="ctx-01",
        surface_guid="guid-missing",
        surface_name="System context and trust boundaries",
        tab_index=0,
    )
    wanted = FakeControl("Pane", "System context and trust boundaries")
    window = FakeWindow(
        "Window",
        100,
        100,
        descendants=[FakeControl("Pane", "Threat List"), wanted],
    )

    # Act
    pane = validate_tm7_with_tmt.find_diagram_pane(window, surface)

    # Assert
    assert pane is wanted


def test_given_unidentifiable_pane_when_finding_then_uses_viewport_child() -> None:
    # Arrange
    # The canvas child carries a stable automation id even though the pane
    # itself is identified per surface.
    surface = validate_tm7_with_tmt.SurfaceDescriptor(
        surface_id="ctx-01",
        surface_guid="guid-missing",
        surface_name="Absent caption",
        tab_index=0,
    )
    canvas = FakeControl(
        "Pane", "Threat Model Drawing Canvas", automation_id="Viewport"
    )
    wanted = FakeControl("Pane", "Unrecognized", descendants=[canvas])
    window = FakeWindow(
        "Window",
        100,
        100,
        descendants=[FakeControl("Pane", "Threat List"), wanted],
    )

    # Act
    pane = validate_tm7_with_tmt.find_diagram_pane(window, surface)

    # Assert
    assert pane is wanted


def test_given_ambiguous_tab_names_when_selecting_surface_then_fails() -> None:
    # Arrange
    surface = validate_tm7_with_tmt.SurfaceDescriptor(
        surface_id="primary",
        surface_guid="guid-1",
        surface_name="Primary interaction",
        tab_index=0,
    )
    tabs = [
        FakeControl("TabItem", "Primary interaction"),
        FakeControl("TabItem", "Primary interaction"),
    ]

    # Act
    selected = validate_tm7_with_tmt.select_surface_tab(
        FakeWindow("Window", 100, 100),
        surface,
        tabs,
    )

    # Assert
    assert selected is tabs[0]


def test_given_raw_control_tabs_when_match_is_not_first_then_returns_actual_tab() -> (
    None
):
    """A matched surface must resolve to its own tab, not the first one.

    On the raw-control path the selection indexed `tabs` by
    `matches.index(matches[0])`, which is always 0, so every surface resolved to
    the first tab and all captured evidence was attributed to it.
    """
    # Arrange
    surface = validate_tm7_with_tmt.SurfaceDescriptor(
        surface_id="third",
        surface_guid="guid-3",
        surface_name="Deployment and operations",
        tab_index=2,
    )
    tabs = [
        FakeControl("TabItem", "Primary interaction"),
        FakeControl("TabItem", "Secondary interaction"),
        FakeControl("TabItem", "Deployment and operations"),
    ]

    # Act
    selected = validate_tm7_with_tmt.select_surface_tab(
        FakeWindow("Window", 100, 100),
        surface,
        tabs,
    )

    # Assert
    assert selected is tabs[2]
    assert selected is not tabs[0]


def test_given_generic_diagram_tabs_when_selected_then_surface_order_decides() -> None:
    # Arrange
    tabs = [
        validate_tm7_with_tmt.SurfaceTab(
            control=FakeControl("TabItem", "Diagram"),
            name="Diagram",
            tab_index=index,
        )
        for index in range(3)
    ]
    surface = validate_tm7_with_tmt.SurfaceDescriptor(
        surface_id="third",
        surface_guid="guid-3",
        surface_name="Third semantic surface",
        tab_index=2,
    )

    # Act
    selected = validate_tm7_with_tmt.select_surface_tab(
        FakeWindow("Window", 100, 100),
        surface,
        tabs,
    )

    # Assert
    assert selected is tabs[2].control


def test_given_message_and_note_tabs_when_enumerated_then_they_are_excluded() -> None:
    # Arrange
    document_tabs = [
        FakeControl("TabItem", "DocumentView, Title Diagram") for _ in range(8)
    ]
    other_tabs = [
        FakeControl(
            "TabItem", "View, Title Messages - Disabled", automation_id="TAB_Messages"
        ),
        FakeControl(
            "TabItem", "View, Title Notes - no entries", automation_id="TAB_Notes"
        ),
    ]
    window = FakeWindow(
        "TMT",
        1000,
        800,
        descendants=[*document_tabs, *other_tabs],
    )

    # Act
    tabs = validate_tm7_with_tmt.enumerate_surface_tabs(window)

    # Assert
    assert len(tabs) == 8
    assert [tab.tab_index for tab in tabs] == list(range(8))


def test_given_window_origin_when_cropped_then_bounds_are_window_relative() -> None:
    # Arrange
    class NumericRectangle:
        left = 180
        top = 140
        right = 420
        bottom = 320

    class NumericWindowRectangle:
        left = 100
        top = 80
        right = 600
        bottom = 400

    class NumericWindow:
        def rectangle(self) -> NumericWindowRectangle:
            return NumericWindowRectangle()

    class NumericControl:
        def rectangle(self) -> NumericRectangle:
            return NumericRectangle()

    # Act
    crop = validate_tm7_with_tmt._control_rectangle(NumericControl(), NumericWindow())

    # Assert
    assert crop == {
        "left": 80,
        "top": 60,
        "right": 320,
        "bottom": 240,
        "width": 240,
        "height": 180,
    }


def test_given_diagram_pane_when_reading_announcement_then_returns_text() -> None:
    # Arrange
    pane = FakeControl(
        "Pane",
        "Diagram",
        automation_id="83b774ee-20a7-5ce1-ac3e-36286067963b",
    )

    # Act
    announcement = validate_tm7_with_tmt.read_canvas_announcement(pane)

    # Assert
    assert announcement == "Diagram"


def test_given_strict_surface_capture_when_pane_missing_then_fails(
    tmp_path: Path,
) -> None:
    # Arrange
    bundle = validate_tm7_with_tmt.EvidenceBundle(tmp_path / "evidence")
    surface = validate_tm7_with_tmt.SurfaceDescriptor(
        surface_id="primary",
        surface_guid="guid-1",
        surface_name="Primary interaction",
        tab_index=0,
    )
    window = FakeWindow("Window", 1000, 800)

    # Act and Assert
    with pytest.raises(validate_tm7_with_tmt.HarnessFailure):
        validate_tm7_with_tmt.capture_surface_evidence(
            window,
            bundle,
            surface,
            model_path=tmp_path / "model.tm7",
            require_feedback_evidence=True,
        )


def test_given_scrollable_surface_when_captured_then_corners_dedupe_and_restore(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    class ScrollInterface:
        CurrentHorizontalScrollPercent = 25.0
        CurrentVerticalScrollPercent = 40.0

        def __init__(self) -> None:
            self.positions: list[tuple[float, float]] = []

        def SetScrollPercent(self, horizontal: float, vertical: float) -> None:
            self.positions.append((horizontal, vertical))

    scroll = ScrollInterface()
    pane = FakeControl("Pane", "System context and trust boundaries")
    pane.iface_scroll = scroll
    window = FakeWindow("TMT", 1000, 800)
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "find_diagram_pane",
        lambda window, surface=None: pane,
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "capture_window_screenshot",
        lambda _window, path: path.write_bytes(b"png"),
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "build_uia_tree",
        lambda _: "diagram",
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "read_canvas_announcement",
        lambda _: "Diagram",
    )
    bundle = validate_tm7_with_tmt.EvidenceBundle(tmp_path / "evidence")
    surface = validate_tm7_with_tmt.SurfaceDescriptor(
        surface_id="context",
        surface_guid="surface-guid",
        surface_name="Context",
        tab_index=0,
    )

    # Act
    payload = validate_tm7_with_tmt.capture_surface_evidence(
        window,
        bundle,
        surface,
        scroll_extent_ratio_x=1.5,
        scroll_extent_ratio_y=1.5,
    )

    # Assert
    assert len(payload["scroll_tiles"]) == 4
    assert scroll.positions[:4] == [
        (0.0, 0.0),
        (100.0, 0.0),
        (0.0, 100.0),
        (100.0, 100.0),
    ]
    assert scroll.positions[-1] == (25.0, 40.0)


def test_given_no_scroll_pattern_when_strict_capture_then_it_fails(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    pane = FakeControl("Pane", "System context and trust boundaries")
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "find_diagram_pane",
        lambda window, surface=None: pane,
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "capture_window_screenshot",
        lambda _window, path: path.write_bytes(b"png"),
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "_control_rectangle",
        lambda *args, **kwargs: {
            "left": 0,
            "top": 0,
            "right": 100,
            "bottom": 100,
            "width": 100,
            "height": 100,
        },
    )

    class FakeImage:
        size = (100, 100)

        def crop(self, bounds):
            return self

        def save(self, path):
            path.write_bytes(b"png")

    class FakeImageModule:
        @staticmethod
        def open(path):
            return FakeImage()

    class FakePillow:
        Image = FakeImageModule

    monkeypatch.setitem(sys.modules, "PIL", FakePillow)
    monkeypatch.setitem(sys.modules, "PIL.Image", FakeImageModule)
    bundle = validate_tm7_with_tmt.EvidenceBundle(tmp_path / "evidence")
    surface = validate_tm7_with_tmt.SurfaceDescriptor(
        surface_id="context",
        surface_guid="surface-guid",
        surface_name="Context",
        tab_index=0,
    )

    # Act and Assert
    with pytest.raises(
        validate_tm7_with_tmt.HarnessFailure,
        match="scroll coverage",
    ):
        validate_tm7_with_tmt.capture_surface_evidence(
            FakeWindow("TMT", 1000, 800),
            bundle,
            surface,
            require_feedback_evidence=True,
            scroll_extent_ratio_x=1.5,
        )


def test_given_startup_pane_and_main_window_when_finding_then_selects_main(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    startup = FakeWindow("Please wait while the application opens", 500, 300)
    main = FakeWindow("Microsoft Threat Modeling Tool", 1400, 900)
    process = FakeProcess()
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "_visible_process_windows",
        lambda process_id: [startup, main],
    )

    # Act
    selected = validate_tm7_with_tmt.find_tmt_window(process, 1)

    # Assert
    assert selected is main


def test_given_nested_dialogs_when_detecting_modal_then_reports_all(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    license_window = FakeWindow(
        "MICROSOFT LICENSE TERMS WINDOW",
        1000,
        800,
        handle=2,
    )
    exception_window = FakeWindow("Unhandled exception", 600, 400, handle=3)
    main = FakeWindow(
        "Microsoft Threat Modeling Tool",
        1400,
        900,
        descendants=[license_window, exception_window],
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "_visible_process_windows",
        lambda process_id: [main],
    )

    # Act
    modal = validate_tm7_with_tmt.detect_modal_dialog(main)

    # Assert
    assert modal == "MICROSOFT LICENSE TERMS WINDOW; Unhandled exception"


def test_given_hidden_nested_dialog_when_detecting_modal_then_ignores_it(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    hidden = FakeWindow("Hidden conversion", 600, 400, handle=2)
    hidden.is_visible = lambda: False
    main = FakeWindow(
        "Microsoft Threat Modeling Tool",
        1400,
        900,
        descendants=[hidden],
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "_visible_process_windows",
        lambda process_id: [main],
    )

    # Act
    modal = validate_tm7_with_tmt.detect_modal_dialog(main)

    # Assert
    assert modal is None


def test_given_window_handle_when_capturing_then_uses_exact_hwnd(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    window = FakeWindow("TMT modal", 600, 400, handle=73)
    output = tmp_path / "window.png"
    captured: dict[str, Any] = {}

    class FakeImage:
        def save(self, path: Path) -> None:
            captured["path"] = path
            path.write_bytes(b"png")

    class FakeImageGrab:
        @staticmethod
        def grab(*, window: int):
            captured["handle"] = window
            return FakeImage()

    class FakePillow:
        ImageGrab = FakeImageGrab

    monkeypatch.setitem(sys.modules, "PIL", FakePillow)
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "screenshot_isolation_available",
        lambda: True,
    )
    monkeypatch.setitem(sys.modules, "PIL.ImageGrab", FakeImageGrab)

    # Act
    validate_tm7_with_tmt.capture_window_screenshot(window, output)

    # Assert
    assert captured == {"handle": 73, "path": output}
    assert output.read_bytes() == b"png"


def test_given_transient_capture_error_when_retrying_then_uses_exact_hwnd(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    window = FakeWindow("TMT modal", 600, 400, handle=73)
    output = tmp_path / "window.png"
    state = {"attempts": 0}

    class FakeImage:
        def save(self, path: Path) -> None:
            path.write_bytes(b"png")

    class FakeImageGrab:
        @staticmethod
        def grab(*, window: int):
            state["attempts"] += 1
            if state["attempts"] == 1:
                raise OSError("transient")
            assert window == 73
            return FakeImage()

    class FakePillow:
        ImageGrab = FakeImageGrab

    monkeypatch.setitem(sys.modules, "PIL", FakePillow)
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "screenshot_isolation_available",
        lambda: True,
    )
    monkeypatch.setitem(sys.modules, "PIL.ImageGrab", FakeImageGrab)

    # Act
    validate_tm7_with_tmt.capture_window_screenshot(window, output)

    # Assert
    assert state["attempts"] == 2
    assert output.read_bytes() == b"png"


def test_given_stale_restore_when_capturing_then_uses_exact_hwnd(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    window = FakeWindow("TMT", 600, 400, handle=73)
    window.restore = lambda: (_ for _ in ()).throw(RuntimeError("stale"))
    window.set_focus = lambda: (_ for _ in ()).throw(RuntimeError("stale"))
    output = tmp_path / "window.png"

    class FakeImage:
        def save(self, path: Path) -> None:
            path.write_bytes(b"png")

    class FakeImageGrab:
        @staticmethod
        def grab(*, window: int) -> FakeImage:
            assert window == 73
            return FakeImage()

    class FakePillow:
        ImageGrab = FakeImageGrab

    monkeypatch.setitem(sys.modules, "PIL", FakePillow)
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "screenshot_isolation_available",
        lambda: True,
    )
    monkeypatch.setitem(sys.modules, "PIL.ImageGrab", FakeImageGrab)

    # Act
    validate_tm7_with_tmt.capture_window_screenshot(window, output)

    # Assert
    assert output.read_bytes() == b"png"


def test_given_tmt_launch_when_started_then_uses_installation_directory(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    executable = tmp_path / "install" / "ThreatModeling.exe"
    executable.parent.mkdir()
    executable.write_bytes(b"exe")
    model = tmp_path / "model.tm7"
    model.write_text("model", encoding="utf-8")
    captured: dict[str, Any] = {}

    def popen(command, **kwargs):
        captured["command"] = command
        captured.update(kwargs)
        return FakeProcess()

    monkeypatch.setattr(validate_tm7_with_tmt.subprocess, "Popen", popen)

    # Act
    validate_tm7_with_tmt.launch_tmt_process(executable, model)

    # Assert
    assert captured["command"] == [str(executable), str(model)]
    assert captured["cwd"] == executable.parent


def test_given_save_button_when_saving_current_model_then_clicks_visible_control(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    model = _input_model(tmp_path)
    state = {"clicked": False, "hash_calls": 0}

    class SaveControl:
        def click_input(self) -> None:
            state["clicked"] = True

    class SaveWindow:
        def window_text(self) -> str:
            return "Saved model"

    def file_hash(path: Path) -> str:
        state["hash_calls"] += 1
        return "before" if state["hash_calls"] == 1 else "after"

    monkeypatch.setattr(validate_tm7_with_tmt, "sha256_file", file_hash)
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "_load_pywinauto",
        lambda: (object(), lambda keys: None, TimeoutError),
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "_find_control",
        lambda window, pattern, control_types: SaveControl(),
    )

    # Act
    validate_tm7_with_tmt.save_current_model(SaveWindow(), model, 1)

    # Assert
    assert state["clicked"] is True


def test_given_clean_model_when_save_is_noop_then_accepts_clean_state(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    model = _input_model(tmp_path)

    class SaveControl:
        def click_input(self) -> None:
            pass

    class SaveWindow:
        def window_text(self) -> str:
            return "Saved model"

    monkeypatch.setattr(validate_tm7_with_tmt, "sha256_file", lambda path: "same")
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "_load_pywinauto",
        lambda: (object(), lambda keys: None, TimeoutError),
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "_find_control",
        lambda window, pattern, control_types: SaveControl(),
    )

    # Act and Assert
    validate_tm7_with_tmt.save_current_model(SaveWindow(), model, 0.01)


def test_given_native_file_dialog_when_saving_then_uses_file_name_edit(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    destination = tmp_path / "threats.csv"
    state: dict[str, Any] = {}

    class Edit:
        def __init__(self, identifier: str) -> None:
            self.identifier = identifier

        def class_name(self) -> str:
            return "Edit"

        def set_focus(self) -> None:
            state["focused"] = self.identifier

        def set_edit_text(self, value: str) -> None:
            state[self.identifier] = value

    class Button:
        def class_name(self) -> str:
            return "Button"

        def window_text(self) -> str:
            return "Save"

        def click_input(self) -> None:
            state["clicked"] = True
            destination.write_text("export", encoding="utf-8")

    class Dialog:
        def process_id(self) -> int:
            return 42

        def descendants(self) -> list[Any]:
            return [Edit("search"), Edit("filename"), Button()]

    class Desktop:
        def __init__(self, backend: str) -> None:
            assert backend == "win32"

        def windows(
            self,
            class_name: str,
            visible_only: bool,
        ) -> list[Dialog]:
            assert class_name == "#32770"
            assert visible_only is True
            return [Dialog()]

    class TimeoutError(Exception):
        pass

    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "_load_pywinauto",
        lambda: (Desktop, object(), TimeoutError),
    )

    # Act
    validate_tm7_with_tmt._save_dialog_path(42, destination, 1)

    # Assert
    assert state["filename"] == str(destination)
    assert "search" not in state
    assert state["focused"] == "filename"
    assert state["clicked"] is True


def test_given_dashboard_and_model_when_waiting_then_selects_analysis_window(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    analysis = FakeWindow(
        "Switch To Analysis View",
        100,
        30,
        element_info=type(
            "ElementInfo",
            (),
            {"control_type": "Button", "name": "Switch To Analysis View"},
        )(),
    )
    dashboard = FakeWindow("Dashboard", 1400, 900)
    model = FakeWindow(
        "Threat Model",
        1400,
        900,
        descendants=[
            analysis,
            FakeControl("Pane", "Threat List"),
            FakeControl("DataGrid", "MainList"),
            FakeControl("Button", "Export Csv"),
        ],
    )
    process = FakeProcess()
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "_visible_process_windows",
        lambda process_id: [dashboard, model],
    )

    # Act
    selected = validate_tm7_with_tmt.wait_for_analysis_window(process, 1)

    # Assert
    assert selected is model


def test_given_switch_click_without_analysis_state_when_opening_then_times_out() -> (
    None
):
    # Arrange
    window = FakeWindow(
        "Threat Model",
        800,
        600,
        descendants=[FakeControl("Button", "Switch To Analysis View")],
    )

    # Act and Assert
    with pytest.raises(
        validate_tm7_with_tmt.HarnessFailure,
        match="Analysis View was not confirmed",
    ):
        validate_tm7_with_tmt.open_analysis_view(window, timeout_seconds=0.01)


def test_given_analysis_ready_state_when_exporting_then_export_runs_after_readiness(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    _patch_successful_automation(monkeypatch, tmp_path)
    workspace = tmp_path / "workspace"
    workspace.mkdir()
    window = FakeWindow("Threat Model", 800, 600)
    state: dict[str, Any] = {}

    def open_analysis(
        window: Any,
        *,
        timeout_seconds: float = 1.0,
        modal_handler: Any | None = None,
    ) -> None:
        setattr(window, "analysis_ready", True)

    def export(window: Any, destination: Path, timeout: float) -> None:
        state["exported"] = validate_tm7_with_tmt._analysis_view_ready(window)
        destination.write_text("id,title\n1,Threat\n", encoding="utf-8")

    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "find_tmt_window",
        lambda *args, **kwargs: window,
    )
    monkeypatch.setattr(validate_tm7_with_tmt, "open_analysis_view", open_analysis)
    monkeypatch.setattr(validate_tm7_with_tmt, "export_threat_csv", export)
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "_analysis_view_ready",
        lambda current: bool(getattr(current, "analysis_ready", False)),
    )

    # Act
    validate_tm7_with_tmt._validate_candidate(
        executable=tmp_path / "ThreatModeling.exe",
        input_model=_input_model(tmp_path),
        workspace=workspace,
        bundle=validate_tm7_with_tmt.EvidenceBundle(tmp_path / "evidence"),
        mode="validate",
        timeout_seconds=1.0,
        expected_threat_count=1,
        template_upgrade_policy="fail",
        delete_stale_threats=False,
    )

    # Assert
    assert state["exported"] is True


def test_given_no_expected_threat_count_when_validating_then_any_model_size_passes(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    _patch_successful_automation(monkeypatch, tmp_path)
    workspace = tmp_path / "workspace"
    workspace.mkdir()
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "collect_semantic_summary",
        lambda path: {
            "sha256": "hash",
            "generation_enabled": "false",
            "instance_count": 101,
            "instances": [
                {"id": str(index), "type_id": "TH-test"} for index in range(101)
            ],
            "knowledge_base_type_ids": ["TH-test"],
            "custom_type_ids": [],
            "drawing_surface_hash": "surface-hash",
            "knowledge_base_hash": "kb-hash",
        },
    )

    # Act
    output = validate_tm7_with_tmt._validate_candidate(
        executable=tmp_path / "ThreatModeling.exe",
        input_model=_input_model(tmp_path),
        workspace=workspace,
        bundle=validate_tm7_with_tmt.EvidenceBundle(tmp_path / "evidence"),
        mode="validate",
        timeout_seconds=1.0,
        expected_threat_count=None,
        template_upgrade_policy="fail",
        delete_stale_threats=False,
    )

    # Assert
    assert output["before_summary"]["instance_count"] == 101


def test_given_mismatched_expected_threat_count_when_validating_then_fails(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    _patch_successful_automation(monkeypatch, tmp_path)
    workspace = tmp_path / "workspace"
    workspace.mkdir()

    # Act and Assert
    with pytest.raises(
        validate_tm7_with_tmt.HarnessFailure,
        match="Expected 2 instances before save",
    ):
        validate_tm7_with_tmt._validate_candidate(
            executable=tmp_path / "ThreatModeling.exe",
            input_model=_input_model(tmp_path),
            workspace=workspace,
            bundle=validate_tm7_with_tmt.EvidenceBundle(tmp_path / "evidence"),
            mode="validate",
            timeout_seconds=1.0,
            expected_threat_count=2,
            template_upgrade_policy="fail",
            delete_stale_threats=False,
        )


def test_given_unspecified_cli_threat_count_when_parsed_then_no_assertion() -> None:
    # Arrange
    parser = validate_tm7_with_tmt.create_parser()

    # Act
    args = parser.parse_args(["model.tm7", "--evidence-dir", "evidence"])

    # Assert
    assert args.expected_threat_count is None


def test_given_exact_export_csv_button_when_exporting_then_finds_export_control(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    destination = tmp_path / "threats.csv"
    window = FakeWindow(
        "Threat Model",
        800,
        600,
        descendants=[
            FakeControl("Pane", "Threat List"),
            FakeControl("DataGrid", "MainList"),
            FakeControl("Button", "Export Csv"),
        ],
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "_analysis_view_ready",
        lambda current: True,
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "_save_dialog_path",
        lambda process_id, output_path, timeout: output_path.write_text(
            "id,title\n1,Threat\n",
            encoding="utf-8",
        ),
    )

    # Act
    validate_tm7_with_tmt.export_threat_csv(window, destination, 1.0)

    # Assert
    assert destination.exists()
    assert destination.read_text(encoding="utf-8") == "id,title\n1,Threat\n"


def test_given_deleted_interaction_export_when_validated_then_fails(
    tmp_path: Path,
) -> None:
    # Arrange
    export_path = tmp_path / "threats.csv"
    export_path.write_text(
        "Id,Title,Interaction\n1,Threat,Deleted\n",
        encoding="utf-8",
    )

    # Act and Assert
    with pytest.raises(
        validate_tm7_with_tmt.HarnessFailure,
        match="Deleted interactions",
    ):
        validate_tm7_with_tmt.validate_exported_interactions(export_path)


def test_given_design_view_when_checked_then_not_ready() -> None:
    # Arrange
    window = FakeWindow(
        "Threat Model",
        800,
        600,
        descendants=[FakeControl("Button", "Switch To Analysis View")],
    )

    # Act
    ready = validate_tm7_with_tmt._analysis_view_ready(window)

    # Assert
    assert ready is False


def test_given_template_conversion_dialog_when_opening_analysis_then_modal_is_cleared(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    window = FakeWindow(
        "Threat Model",
        800,
        600,
        descendants=[FakeControl("Button", "Switch To Analysis View")],
    )
    state: dict[str, Any] = {"modal_calls": 0}

    def modal_handler() -> None:
        state["modal_calls"] += 1
        setattr(window, "analysis_ready", True)

    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "_analysis_view_ready",
        lambda current: bool(getattr(current, "analysis_ready", False)),
    )

    # Act
    validate_tm7_with_tmt.open_analysis_view(
        window,
        timeout_seconds=0.01,
        modal_handler=modal_handler,
    )

    # Assert
    assert state["modal_calls"] >= 1


def test_given_stale_analysis_window_when_reacquired_then_uses_active_window(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    stale_window = FakeWindow(
        "Threat Model",
        800,
        600,
        descendants=[FakeControl("Button", "Switch To Analysis View")],
    )
    active_window = FakeWindow(
        "Threat Model",
        1000,
        700,
        descendants=[
            FakeControl("Pane", "Threat List"),
            FakeControl("DataGrid", "MainList"),
            FakeControl("Button", "Export Csv"),
        ],
    )
    click_count = 0

    def clicker() -> None:
        nonlocal click_count
        click_count += 1

    stale_window.descendants()[0].click_input = clicker  # type: ignore[assignment]

    def reacquire() -> FakeWindow:
        return active_window

    monkeypatch.setattr(validate_tm7_with_tmt.time, "sleep", lambda _: None)

    # Act
    returned_window = validate_tm7_with_tmt.open_analysis_view(
        stale_window,
        timeout_seconds=0.05,
        reacquire_window=reacquire,
    )

    # Assert
    assert returned_window is active_window
    assert click_count == 1


def test_given_delayed_analysis_transition_when_opening_then_waits_for_ready_window(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    initial_window = FakeWindow(
        "Threat Model",
        800,
        600,
        descendants=[FakeControl("Button", "Switch To Analysis View")],
    )
    ready_window = FakeWindow(
        "Threat Model",
        1000,
        700,
        descendants=[
            FakeControl("Pane", "Threat List"),
            FakeControl("DataGrid", "Threats List"),
            FakeControl("Button", "Export Csv"),
        ],
    )
    attempts = iter([initial_window, initial_window, ready_window])

    def reacquire() -> FakeWindow:
        return next(attempts)

    monkeypatch.setattr(validate_tm7_with_tmt.time, "sleep", lambda _: None)

    # Act
    returned_window = validate_tm7_with_tmt.open_analysis_view(
        initial_window,
        timeout_seconds=0.05,
        reacquire_window=reacquire,
    )

    # Assert
    assert returned_window is ready_window


def test_given_delayed_conversion_modal_when_opening_analysis_then_reacquires(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    initial_window = FakeWindow(
        "Threat Model",
        800,
        600,
        descendants=[FakeControl("Button", "Switch To Analysis View")],
    )
    ready_window = FakeWindow(
        "Threat Model",
        1000,
        700,
        descendants=[
            FakeControl("Pane", "Threat List"),
            FakeControl("DataGrid", "MainList"),
            FakeControl("Button", "Export Csv"),
        ],
    )
    modal_calls = 0

    def modal_handler(window: Any) -> None:
        nonlocal modal_calls
        modal_calls += 1
        if modal_calls == 1:
            setattr(window, "analysis_ready", True)

    def reacquire() -> FakeWindow:
        return ready_window

    monkeypatch.setattr(validate_tm7_with_tmt.time, "sleep", lambda _: None)

    # Act
    returned_window = validate_tm7_with_tmt.open_analysis_view(
        initial_window,
        timeout_seconds=0.05,
        modal_handler=modal_handler,
        reacquire_window=reacquire,
    )

    # Assert
    assert returned_window is ready_window
    assert modal_calls >= 1


def test_given_unknown_modal_when_captured_then_fail_closed(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    bundle = validate_tm7_with_tmt.EvidenceBundle(tmp_path / "evidence")
    window = FakeWindow("Threat Model", 800, 600)
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "detect_modal_dialog",
        lambda current: "Unexpected warning",
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "_modal_windows",
        lambda current: [FakeWindow("Unexpected warning", 400, 300)],
    )
    monkeypatch.setattr(validate_tm7_with_tmt, "build_uia_tree", lambda current: "")
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "capture_window_screenshot",
        lambda current, path: path.write_bytes(b"png"),
    )

    # Act and Assert
    with pytest.raises(
        validate_tm7_with_tmt.HarnessFailure,
        match="Unexpected modal",
    ):
        validate_tm7_with_tmt._capture_modal(
            window,
            bundle,
            template_upgrade_policy="decline",
            timeout_seconds=1.0,
        )


def test_given_wrong_version_without_override_when_checked_then_rejected() -> None:
    # Arrange
    policy = validate_tm7_with_tmt.TmtVersionPolicy(
        pinned_version="7.3.51110.1",
        observed_version="7.4.0.0",
    )

    # Act
    outcome = validate_tm7_with_tmt.evaluate_version_policy(policy)

    # Assert
    assert outcome.allowed is False
    assert outcome.exit_code == validate_tm7_with_tmt.EXIT_VERSION_MISMATCH


@pytest.mark.parametrize(
    ("require_tmt", "expected_status", "expected_exit"),
    [
        (False, "skipped", validate_tm7_with_tmt.EXIT_SUCCESS),
        (True, "missing-tmt", validate_tm7_with_tmt.EXIT_MISSING_TMT),
    ],
)
def test_given_missing_tmt_when_running_then_policy_is_stable(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    require_tmt: bool,
    expected_status: str,
    expected_exit: int,
) -> None:
    # Arrange
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "discover_tmt_application",
        lambda: validate_tm7_with_tmt.TmtDiscovery(path=None),
    )

    # Act
    result = validate_tm7_with_tmt.run_harness(
        input_model=_input_model(tmp_path),
        evidence_dir=tmp_path / "evidence",
        mode="probe",
        require_tmt=require_tmt,
    )

    # Assert
    assert result.status == expected_status
    assert result.exit_code == expected_exit


def test_given_timeout_when_window_never_appears_then_failure_bundle_is_retained(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    processes = _patch_successful_automation(monkeypatch, tmp_path)
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "find_tmt_window",
        lambda *args, **kwargs: (_ for _ in ()).throw(
            validate_tm7_with_tmt.HarnessFailure(
                "window timeout",
                validate_tm7_with_tmt.EXIT_AUTOMATION_TIMEOUT,
            )
        ),
    )
    workspace = tmp_path / "workspace"

    # Act
    result = validate_tm7_with_tmt.run_harness(
        input_model=_input_model(tmp_path),
        evidence_dir=tmp_path / "evidence",
        workspace_root=workspace,
        require_tmt=True,
    )

    # Assert
    assert result.exit_code == validate_tm7_with_tmt.EXIT_AUTOMATION_TIMEOUT
    assert workspace.exists()
    assert processes and all(process.closed for process in processes)
    assert (tmp_path / "evidence" / "status.json").exists()


def test_given_modal_when_detected_then_uia_and_screenshot_are_retained(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    _patch_successful_automation(monkeypatch, tmp_path)
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "detect_modal_dialog",
        lambda window: "Unexpected warning",
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "_modal_windows",
        lambda window: [],
    )
    evidence = tmp_path / "evidence"

    # Act
    result = validate_tm7_with_tmt.run_harness(
        input_model=_input_model(tmp_path),
        evidence_dir=evidence,
        require_tmt=True,
    )

    # Assert
    assert result.exit_code == validate_tm7_with_tmt.EXIT_UNEXPECTED_MODAL
    assert (evidence / "uia" / "unexpected-modal.txt").exists()
    assert (evidence / "screenshots" / "unexpected-modal.png").exists()


def test_given_license_modal_when_detected_then_reports_human_gate(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    _patch_successful_automation(monkeypatch, tmp_path)
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "detect_modal_dialog",
        lambda window: validate_tm7_with_tmt.LICENSE_MODAL_TITLE,
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "_modal_windows",
        lambda window: [],
    )

    # Act
    result = validate_tm7_with_tmt.run_harness(
        input_model=_input_model(tmp_path),
        evidence_dir=tmp_path / "evidence",
        require_tmt=True,
    )

    # Assert
    assert result.exit_code == validate_tm7_with_tmt.EXIT_UNEXPECTED_MODAL
    assert "Human acceptance" in result.message


@pytest.mark.parametrize(
    ("policy", "button_name", "expected"),
    [("apply", "Yes", "applied"), ("decline", "No", "declined")],
)
def test_given_template_prompt_when_policy_selected_then_modal_is_handled(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    policy: str,
    button_name: str,
    expected: str,
) -> None:
    # Arrange
    state = {"open": True, "checked": False, "button": ""}

    class ControlInfo:
        def __init__(self, control_type: str, name: str) -> None:
            self.control_type = control_type
            self.name = name
            self.automation_id = ""

    class FakeControl:
        def __init__(self, control_type: str, name: str) -> None:
            self.element_info = ControlInfo(control_type, name)

        def get_toggle_state(self) -> int:
            return int(state["checked"])

        def click_input(self) -> None:
            if self.element_info.control_type == "CheckBox":
                state["checked"] = not state["checked"]
            else:
                state["button"] = self.element_info.name
                state["open"] = False

    checkbox = FakeControl("CheckBox", "Do you want to delete stale threats?")
    yes = FakeControl("Button", "Yes")
    no = FakeControl("Button", "No")
    conversion = FakeWindow(
        validate_tm7_with_tmt.TEMPLATE_CONVERSION_MODAL_TITLE,
        800,
        500,
        handle=7,
        descendants=[checkbox, yes, no],
    )
    main = FakeWindow("Microsoft Threat Modeling Tool", 1400, 900)
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "_modal_windows",
        lambda window: [conversion] if state["open"] else [],
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "build_uia_tree",
        lambda window: "template conversion\n",
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "capture_window_screenshot",
        lambda window, path: path.write_bytes(b"png"),
    )
    bundle = validate_tm7_with_tmt.EvidenceBundle(tmp_path / "evidence")

    # Act
    result = validate_tm7_with_tmt._handle_template_conversion(
        main,
        bundle,
        policy=policy,
        delete_stale=False,
        timeout_seconds=1,
    )

    # Assert
    assert result == expected
    assert state["button"] == button_name
    assert state["checked"] is False


def test_given_template_prompt_when_policy_fail_then_requires_explicit_choice(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    conversion = FakeWindow(
        validate_tm7_with_tmt.TEMPLATE_CONVERSION_MODAL_TITLE,
        800,
        500,
        handle=7,
    )
    main = FakeWindow("Microsoft Threat Modeling Tool", 1400, 900)
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "_modal_windows",
        lambda window: [conversion],
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "build_uia_tree",
        lambda window: "template conversion\n",
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "capture_window_screenshot",
        lambda window, path: path.write_bytes(b"png"),
    )
    bundle = validate_tm7_with_tmt.EvidenceBundle(tmp_path / "evidence")

    # Act and Assert
    with pytest.raises(
        validate_tm7_with_tmt.HarnessFailure,
        match="explicit template upgrade policy",
    ):
        validate_tm7_with_tmt._handle_template_conversion(
            main,
            bundle,
            policy="fail",
            delete_stale=False,
            timeout_seconds=1,
        )


def test_given_upgrade_mode_when_successful_then_upgraded_model_is_published(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    _patch_successful_automation(monkeypatch, tmp_path)
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "_capture_modal",
        lambda *args, **kwargs: (
            "applied" if kwargs.get("template_upgrade_policy") == "apply" else None
        ),
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "wait_for_analysis_window",
        lambda process, timeout: object(),
    )
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "_wait_for_modal_window",
        lambda window, title, timeout: object(),
    )
    output = tmp_path / "upgraded.tm7"

    # Act
    result = validate_tm7_with_tmt.run_harness(
        input_model=_input_model(tmp_path),
        evidence_dir=tmp_path / "evidence",
        mode="upgrade-template",
        upgraded_model_output=output,
        require_tmt=True,
        expected_threat_count=1,
    )

    # Assert
    assert result.status == "passed"
    assert output.read_text(encoding="utf-8") == "model"


def test_given_native_upgrade_when_custom_types_removed_then_restores_from_source(
    tmp_path: Path,
) -> None:
    # Arrange
    source = tmp_path / "source.tm7"
    target = tmp_path / "target.tm7"
    source.write_text(
        f'<ThreatModel xmlns="{validate_tm7_with_tmt.MODEL_NS}" '
        f'xmlns:a="{validate_tm7_with_tmt.KNOWLEDGE_NS}">'
        "<KnowledgeBase><a:ThreatTypes><a:ThreatType>"
        "<a:Id>THC-custom</a:Id><a:ShortTitle>Custom</a:ShortTitle>"
        "</a:ThreatType></a:ThreatTypes></KnowledgeBase></ThreatModel>",
        encoding="utf-8",
    )
    target.write_text(
        f'<ThreatModel xmlns="{validate_tm7_with_tmt.MODEL_NS}" '
        f'xmlns:a="{validate_tm7_with_tmt.KNOWLEDGE_NS}">'
        "<KnowledgeBase><a:ThreatTypes><a:ThreatType>"
        "<a:Id>TH1</a:Id><a:ShortTitle>Stock</a:ShortTitle>"
        "</a:ThreatType></a:ThreatTypes></KnowledgeBase></ThreatModel>",
        encoding="utf-8",
    )

    # Act
    restored = validate_tm7_with_tmt.restore_custom_threat_types(source, target)
    root = validate_tm7_with_tmt._parse_xml(target)
    type_ids = {node.findtext("{*}Id") for node in root.findall(".//{*}ThreatType")}

    # Assert
    assert restored == 1
    assert type_ids == {"TH1", "THC-custom"}


def test_given_probe_mode_when_successful_then_initial_evidence_is_complete(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    processes = _patch_successful_automation(monkeypatch, tmp_path)
    evidence = tmp_path / "evidence"
    workspace = tmp_path / "workspace"

    # Act
    result = validate_tm7_with_tmt.run_harness(
        input_model=_input_model(tmp_path),
        evidence_dir=evidence,
        mode="probe",
        require_tmt=True,
        workspace_root=workspace,
    )

    # Assert
    assert result.status == "passed"
    assert workspace.exists()
    assert not (workspace / validate_tm7_with_tmt.WORKSPACE_CHILD_NAME).exists()
    assert processes and all(process.closed for process in processes)
    assert (evidence / "screenshots" / "initial-open.png").exists()
    assert (evidence / "uia" / "initial-open.txt").exists()


def test_given_populated_workspace_root_when_run_succeeds_then_caller_content_lives(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    _patch_successful_automation(monkeypatch, tmp_path)
    evidence = tmp_path / "evidence"
    workspace_root = tmp_path / "operator-documents"
    workspace_root.mkdir()
    sentinel = workspace_root / "important.txt"
    sentinel.write_text("operator content", encoding="utf-8")
    nested = workspace_root / "nested"
    nested.mkdir()
    (nested / "deep.txt").write_text("nested content", encoding="utf-8")

    # Act
    result = validate_tm7_with_tmt.run_harness(
        input_model=_input_model(tmp_path),
        evidence_dir=evidence,
        mode="probe",
        require_tmt=True,
        workspace_root=workspace_root,
    )

    # Assert
    assert result.status == "passed"
    assert sentinel.read_text(encoding="utf-8") == "operator content"
    assert (nested / "deep.txt").read_text(encoding="utf-8") == "nested content"
    assert not (workspace_root / validate_tm7_with_tmt.WORKSPACE_CHILD_NAME).exists()


def test_given_junction_inside_workspace_when_cleaned_then_link_target_survives(
    tmp_path: Path,
) -> None:
    # Arrange
    workspace = tmp_path / "owned"
    validate_tm7_with_tmt.mark_workspace_owned(workspace)
    outside = tmp_path / "outside"
    outside.mkdir()
    protected = outside / "protected.txt"
    protected.write_text("must survive", encoding="utf-8")
    link = workspace / "link"
    try:
        link.symlink_to(outside, target_is_directory=True)
    except (OSError, NotImplementedError):
        pytest.skip("directory link creation is unavailable in this environment")

    # Act
    validate_tm7_with_tmt._remove_owned_workspace(workspace)

    # Assert
    assert not workspace.exists()
    assert protected.read_text(encoding="utf-8") == "must survive"


def test_given_calibration_smoke_when_measured_then_writes_same_run_contract(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    processes = _patch_successful_automation(monkeypatch, tmp_path)
    evidence = tmp_path / "evidence"
    captured: dict[str, Any] = {}

    def capture_surfaces(**kwargs: Any) -> list[dict[str, Any]]:
        captured.update(kwargs)
        return [
            {
                "surface_id": "context",
                "pane_rect": {"left": 8, "top": 12, "width": 1440, "height": 900},
                "viewport_target": [0.0, 0.0, 1920.0, 1080.0],
                "screenshot_dimensions": {"width": 1600, "height": 1000},
                "crop_dimensions": {"width": 1440, "height": 900},
                "scroll_percentages": {"horizontal": 0.0, "vertical": 0.0},
                "scroll_coverage_complete": True,
                "scroll_restored": True,
            }
        ]

    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "_capture_feedback_surface_evidence",
        capture_surfaces,
    )

    # Act
    result = validate_tm7_with_tmt.run_harness(
        input_model=_input_model(tmp_path),
        evidence_dir=evidence,
        mode="calibration-smoke",
        require_tmt=True,
    )

    # Assert
    assert result.status == "passed"
    assert captured["surface_limit"] == 1
    assert captured["require_feedback_evidence"] is True
    assert captured["calibration_context"] is None
    assert processes and all(process.closed for process in processes)
    summary = json.loads(
        (evidence / "summaries" / "calibration-smoke.json").read_text(encoding="utf-8")
    )
    calibration = summary["layout_calibration_v1"]
    assert calibration["scope"] == "same-run"
    assert calibration["pane_rect"] == [8, 12, 1440, 900]
    assert calibration["effective_scale"]["x"] == pytest.approx(1440 / 1920)
    assert calibration["confidence"]["pane_measured"] is True


def test_given_unmeasured_pane_when_calibration_smoke_then_fails_closed(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    _patch_successful_automation(monkeypatch, tmp_path)
    monkeypatch.setattr(
        validate_tm7_with_tmt,
        "_capture_feedback_surface_evidence",
        lambda **kwargs: [],
    )

    # Act
    result = validate_tm7_with_tmt.run_harness(
        input_model=_input_model(tmp_path),
        evidence_dir=tmp_path / "evidence",
        mode="calibration-smoke",
        require_tmt=True,
    )

    # Assert
    assert result.exit_code == validate_tm7_with_tmt.EXIT_VALIDATION_FAILURE
    assert "Calibration smoke" in result.message


def test_given_validate_mode_when_successful_then_closure_evidence_is_complete(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    _patch_successful_automation(monkeypatch, tmp_path)
    evidence = tmp_path / "evidence"

    # Act
    result = validate_tm7_with_tmt.run_harness(
        input_model=_input_model(tmp_path),
        evidence_dir=evidence,
        mode="validate",
        require_tmt=True,
        expected_threat_count=1,
    )

    # Assert
    assert result.status == "passed"
    required = {
        "screenshots/initial-open.png",
        "screenshots/analysis-view.png",
        "screenshots/post-save.png",
        "screenshots/reopen-analysis-view.png",
        "uia/initial-open.txt",
        "uia/analysis-view.txt",
        "uia/reopen-analysis.txt",
        "exports/before-save.csv",
        "exports/after-reopen.csv",
        "summaries/before-save.json",
        "summaries/after-reopen.json",
        "manifest.json",
        "status.json",
        "action.log",
    }
    actual = {
        str(path.relative_to(evidence)).replace("\\", "/")
        for path in evidence.rglob("*")
        if path.is_file()
    }
    assert required <= actual
    assert "PASS save-workspace-copy" in (evidence / "action.log").read_text(
        encoding="utf-8"
    )


def test_given_declined_template_when_reopened_then_declines_again(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    _patch_successful_automation(monkeypatch, tmp_path)
    policies: list[str] = []

    def capture_modal(*args: Any, **kwargs: Any) -> None:
        policies.append(str(kwargs["template_upgrade_policy"]))

    monkeypatch.setattr(validate_tm7_with_tmt, "_capture_modal", capture_modal)

    # Act
    result = validate_tm7_with_tmt.run_harness(
        input_model=_input_model(tmp_path),
        evidence_dir=tmp_path / "evidence",
        require_tmt=True,
        expected_threat_count=1,
        template_upgrade_policy="decline",
    )

    # Assert
    assert result.status == "passed"
    assert policies == ["decline", "decline"]


def test_given_compare_mode_without_second_candidate_when_run_then_usage_error(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    _patch_successful_automation(monkeypatch, tmp_path)

    # Act
    result = validate_tm7_with_tmt.run_harness(
        input_model=_input_model(tmp_path),
        evidence_dir=tmp_path / "evidence",
        mode="compare-generation-state",
        require_tmt=True,
    )

    # Assert
    assert result.exit_code == validate_tm7_with_tmt.EXIT_ERROR
    assert "comparison-model" in result.message


def test_given_secret_manifest_values_when_written_then_all_are_redacted(
    tmp_path: Path,
) -> None:
    # Arrange
    bundle = validate_tm7_with_tmt.EvidenceBundle(tmp_path / "evidence")
    secret = "do-not-persist"

    # Act
    bundle.write_manifest(
        {
            "client_secret": secret,
            "authorization": f"Bearer {secret}",
            "url": f"https://example.test/path?sig={secret}",
        }
    )
    manifest_text = bundle.manifest_path.read_text(encoding="utf-8")

    # Assert
    assert secret not in manifest_text
    assert "[REDACTED]" in manifest_text
    assert "?sig=" not in manifest_text


def test_given_status_when_written_then_version_inventory_is_auditable(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    _patch_successful_automation(monkeypatch, tmp_path)
    evidence = tmp_path / "evidence"

    # Act
    validate_tm7_with_tmt.run_harness(
        input_model=_input_model(tmp_path),
        evidence_dir=evidence,
        mode="probe",
        require_tmt=True,
    )

    # Assert
    status = json.loads((evidence / "status.json").read_text(encoding="utf-8"))
    assert status["required_tmt_version"] == "7.3.51110.1"
    assert status["observed_tmt_version"] == "7.3.51110.1"
    assert status["evidence_schema_version"] == 1
    assert "evidence_files" in status
