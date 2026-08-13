# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
from types import SimpleNamespace
from typing import Any

import pytest
from runtime_a11y._errors import ScriptError
from runtime_a11y.visual_review import (
    build_visual_review_manifest,
    collect_environment_provenance,
    compute_sha256,
    merge_evidence_state,
    normalize_manifest_path,
    redact_sensitive_metadata,
    resolve_run_root,
    validate_visual_review_config,
    validate_visual_review_manifest,
    write_json_atomic,
)


def _make_manifest(*, run_root: Path | None = None) -> dict[str, Any]:
    root = run_root or Path("/tmp/local-run")
    return {
        "schemaVersion": "1.0",
        "runId": "run-001",
        "createdAt": "2026-07-17T00:00:00Z",
        "route": "/",
        "surface": "home",
        "state": "default",
        "viewport": {"width": 1440, "height": 900},
        "zoom": {"scale": 1.0},
        "browser": {"name": "chrome", "version": "126.0"},
        "platform": {"os": "windows", "version": "11"},
        "artifacts": {
            "screenshots": [
                {
                    "id": "desktop",
                    "path": "artifacts/screenshot.png",
                    "sha256": "0" * 64,
                    "width": 1440,
                    "height": 900,
                }
            ],
            "traces": [
                {
                    "id": "trace",
                    "path": "artifacts/trace.zip",
                    "sha256": "0" * 64,
                    "sizeBytes": 1200,
                }
            ],
            "deterministicMeasurements": [
                {
                    "id": "geometry",
                    "path": "artifacts/metrics.json",
                    "sha256": "0" * 64,
                    "sizeBytes": 600,
                }
            ],
            "manifestPayload": {
                "id": "manifest",
                "path": "manifest.json",
                "sha256": "0" * 64,
                "sizeBytes": 400,
            },
        },
        "probeOutcomes": [{"id": "reflow", "status": "pass"}],
        "provenance": {
            "environment": {
                "cwd": str(root),
                "pythonVersion": "3.11",
            },
            "git": {
                "available": False,
                "commit": None,
                "dirty": False,
            },
        },
        "evidenceState": "deterministic-pass",
    }


def test_given_valid_manifest_when_validating_then_accepts_schema(
    tmp_path: Path,
) -> None:
    manifest = _make_manifest(run_root=tmp_path)

    validated = validate_visual_review_manifest(manifest, run_root=tmp_path)

    assert validated["schemaVersion"] == "1.0"
    assert validated["artifacts"]["manifestPayload"]["path"] == "manifest.json"


def test_given_manifest_with_traversal_path_when_validating_then_rejects(
    tmp_path: Path,
) -> None:
    manifest = _make_manifest(run_root=tmp_path)
    manifest["artifacts"]["screenshots"][0]["path"] = "../escape.png"

    with pytest.raises(ScriptError, match="containment"):
        validate_visual_review_manifest(manifest, run_root=tmp_path)


def test_given_valid_runtime_config_when_validating_then_accepts_opt_in_visual_review(
    tmp_path: Path,
) -> None:
    config = {
        "baseUrl": "http://127.0.0.1:3000",
        "visualReview": {
            "enabled": True,
            "operatorConfirmedNoPersonalData": True,
            "evidenceRoot": str(tmp_path / "evidence"),
            "maxArtifactBytes": 512 * 1024 * 1024,
            "allowlist": ["127.0.0.1"],
        },
    }

    validated = validate_visual_review_config(config)

    assert validated["visualReview"]["enabled"] is True


def test_given_config_with_over_limit_bytes_when_validating_then_rejects() -> None:
    config = {
        "baseUrl": "http://127.0.0.1:3000",
        "visualReview": {
            "enabled": True,
            "operatorConfirmedNoPersonalData": True,
            "maxArtifactBytes": 2 * 1024 * 1024 * 1024,
        },
    }

    with pytest.raises(ScriptError, match="1 GB"):
        validate_visual_review_config(config)


def test_given_non_object_visual_review_when_validating_then_rejects() -> None:
    config = {
        "baseUrl": "http://127.0.0.1:3000",
        "visualReview": [],
    }

    with pytest.raises(ScriptError, match="JSON object"):
        validate_visual_review_config(config)


def test_given_invalid_manifest_schema_when_validating_then_rejects(
    tmp_path: Path,
) -> None:
    manifest = _make_manifest(run_root=tmp_path)
    manifest.pop("schemaVersion")

    with pytest.raises(ScriptError, match="schema validation"):
        validate_visual_review_manifest(manifest, run_root=tmp_path)


def test_given_human_state_when_merging_then_human_state_wins() -> None:
    merged = merge_evidence_state(
        authoritative_state="deterministic-pass",
        advisory_state="model-clear-advisory",
        human_state="human-override",
    )

    assert merged == "human-override"


def test_advisory_state_without_authoritative_uses_advisory() -> None:
    merged = merge_evidence_state(
        authoritative_state=None,
        advisory_state="model-clear-advisory",
        human_state=None,
    )

    assert merged == "model-clear-advisory"


def test_given_malicious_path_when_normalizing_then_rejects_absolute_and_scheme(
    tmp_path: Path,
) -> None:
    with pytest.raises(ScriptError, match="relative"):
        normalize_manifest_path("/tmp/evil.png", run_root=tmp_path)

    with pytest.raises(ScriptError, match="relative"):
        normalize_manifest_path("https://example.com/evil.png", run_root=tmp_path)

    with pytest.raises(ScriptError, match="containment"):
        normalize_manifest_path("../evil.png", run_root=tmp_path)


def test_given_manifest_without_required_relative_path_when_validating_then_rejects(
    tmp_path: Path,
) -> None:
    manifest = _make_manifest(run_root=tmp_path)
    manifest["artifacts"]["screenshots"][0].pop("path")

    with pytest.raises(ScriptError, match="relative path"):
        validate_visual_review_manifest(manifest, run_root=tmp_path)


def test_given_manifest_with_invalid_hash_when_validating_then_rejects(
    tmp_path: Path,
) -> None:
    manifest = _make_manifest(run_root=tmp_path)
    manifest["artifacts"]["screenshots"][0]["sha256"] = "abc"

    with pytest.raises(ScriptError, match="SHA-256"):
        validate_visual_review_manifest(manifest, run_root=tmp_path)


def test_given_manifest_bytes_when_exceeding_ceiling_then_rejects(
    tmp_path: Path,
) -> None:
    manifest = _make_manifest(run_root=tmp_path)
    manifest["artifacts"]["screenshots"][0]["sizeBytes"] = 2 * 1024 * 1024 * 1024

    with pytest.raises(ScriptError, match="byte ceiling"):
        validate_visual_review_manifest(
            manifest,
            run_root=tmp_path,
            max_artifact_bytes=512 * 1024 * 1024,
        )


def test_given_missing_path_when_computing_sha256_then_fails_closed(
    tmp_path: Path,
) -> None:
    missing_path = tmp_path / "missing.bin"

    with pytest.raises(ScriptError, match="does not exist"):
        compute_sha256(missing_path)


def test_given_empty_path_when_normalizing_then_rejects() -> None:
    with pytest.raises(ScriptError, match="non-empty"):
        normalize_manifest_path("", run_root=".")


def test_given_non_object_manifest_when_validating_then_rejects() -> None:
    with pytest.raises(ScriptError, match="JSON object"):
        validate_visual_review_manifest([], run_root=".")


def test_given_non_object_config_when_validating_then_rejects() -> None:
    with pytest.raises(ScriptError, match="JSON object"):
        validate_visual_review_config([])


def test_given_relative_base_dir_when_resolving_root_then_uses_cwd(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.chdir(tmp_path)

    root = resolve_run_root("evidence", run_id="abc123")

    assert root.name == "abc123"
    expected_prefix = (
        str(tmp_path).replace("\\", "/")
        + "/evidence/.copilot-tracking/accessibility/local-runs"
    )
    assert str(root).startswith(expected_prefix)


def test_given_existing_run_root_when_resolving_then_rejects(
    tmp_path: Path,
) -> None:
    root = (
        tmp_path
        / ".copilot-tracking"
        / "accessibility"
        / "local-runs"
        / "2026-07-17"
        / "abc123"
    )
    root.mkdir(parents=True, exist_ok=True)

    with pytest.raises(ScriptError, match="already exists"):
        resolve_run_root(tmp_path, run_id="abc123", date="2026-07-17")


def test_given_existing_run_root_when_resolving_then_uses_suffix_dir(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = (
        tmp_path
        / ".copilot-tracking"
        / "accessibility"
        / "local-runs"
        / "2026-07-17"
        / "abc123"
    )
    root.parent.mkdir(parents=True, exist_ok=True)

    original_mkdir = Path.mkdir

    def _mkdir(self: Path, *args: Any, **kwargs: Any) -> None:
        if self == root:
            raise FileExistsError("taken")
        return original_mkdir(self, *args, **kwargs)

    monkeypatch.setattr(Path, "mkdir", _mkdir)

    resolved = resolve_run_root(tmp_path, run_id="abc123", date="2026-07-17")

    assert resolved.name == "abc123-1"
    assert (root.parent / "abc123-1").exists()


@pytest.mark.skipif(not hasattr(os, "symlink"), reason="symlink support required")
def test_given_symlink_path_when_normalizing_then_rejects(tmp_path: Path) -> None:
    run_root = tmp_path / "run"
    run_root.mkdir()
    outside = tmp_path / "outside"
    outside.mkdir()
    (outside / "evil.png").write_bytes(b"escaped")
    try:
        os.symlink(outside, run_root / "artifacts", target_is_directory=True)
    except (OSError, NotImplementedError):
        pytest.skip("creating symlinks is not permitted in this environment")

    with pytest.raises(ScriptError, match="containment"):
        normalize_manifest_path("artifacts/evil.png", run_root=run_root)


@pytest.mark.skipif(not hasattr(os, "symlink"), reason="symlink support required")
def test_given_symlinked_leaf_when_normalizing_then_rejects(tmp_path: Path) -> None:
    run_root = tmp_path / "run"
    artifact_dir = run_root / "artifacts"
    artifact_dir.mkdir(parents=True)
    outside = tmp_path / "outside"
    outside.mkdir()
    target = outside / "evil.png"
    target.write_bytes(b"escaped")
    try:
        os.symlink(target, artifact_dir / "screenshot.png")
    except (OSError, NotImplementedError):
        pytest.skip("creating symlinks is not permitted in this environment")

    with pytest.raises(ScriptError, match="containment"):
        normalize_manifest_path("artifacts/screenshot.png", run_root=run_root)


@pytest.mark.skipif(not hasattr(os, "symlink"), reason="symlink support required")
def test_given_symlink_inside_root_when_normalizing_then_rejects(
    tmp_path: Path,
) -> None:
    # The target stays inside the run root, so path containment alone accepts
    # it. Only the symlink check can reject this, which makes it the assertion
    # that distinguishes a live check from one that runs after resolve().
    run_root = tmp_path / "run"
    real_dir = run_root / "real"
    real_dir.mkdir(parents=True)
    (real_dir / "screenshot.png").write_bytes(b"inside")
    try:
        os.symlink(real_dir, run_root / "artifacts", target_is_directory=True)
    except (OSError, NotImplementedError):
        pytest.skip("creating symlinks is not permitted in this environment")

    with pytest.raises(ScriptError, match="containment"):
        normalize_manifest_path("artifacts/screenshot.png", run_root=run_root)


def test_given_credential_query_when_validating_config_then_rejects() -> None:
    config = {
        "baseUrl": "http://127.0.0.1:3000?token=abc",
        "visualReview": {"enabled": True, "operatorConfirmedNoPersonalData": True},
    }

    with pytest.raises(ScriptError, match="credential-bearing"):
        validate_visual_review_config(config)


def test_given_tuple_metadata_when_redacting_then_values_are_preserved() -> None:
    redacted = redact_sensitive_metadata(("safe", {"authorization": "secret"}))

    assert redacted[0] == "safe"
    assert redacted[1]["authorization"] == "[REDACTED]"


def test_given_replace_failure_when_writing_json_then_temp_file_is_removed(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    output = tmp_path / "manifest.json"
    monkeypatch.setattr(
        os, "replace", lambda *_args, **_kwargs: (_ for _ in ()).throw(OSError("boom"))
    )

    with pytest.raises(OSError, match="boom"):
        write_json_atomic(output, {"schemaVersion": "1.0", "runId": "abc"})

    assert not any(tmp_path.glob("manifest*.tmp"))


def test_given_unlink_failure_when_writing_json_then_original_error_is_reraised(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    output = tmp_path / "manifest.json"
    monkeypatch.setattr(
        os,
        "replace",
        lambda *_args, **_kwargs: (_ for _ in ()).throw(FileNotFoundError("boom")),
    )
    monkeypatch.setattr(
        os,
        "unlink",
        lambda *_args, **_kwargs: (_ for _ in ()).throw(FileNotFoundError("gone")),
    )

    with pytest.raises(FileNotFoundError, match="boom"):
        write_json_atomic(output, {"schemaVersion": "1.0", "runId": "abc"})


def test_given_manifest_and_advisory_state_when_merging_then_pass_is_not_promoted(
    tmp_path: Path,
) -> None:
    manifest = _make_manifest(run_root=tmp_path)
    manifest["evidenceState"] = "deterministic-pass"

    merged = merge_evidence_state(
        authoritative_state="deterministic-pass",
        advisory_state="model-clear-advisory",
        human_state=None,
    )

    assert merged == "deterministic-pass"

    merged_fail = merge_evidence_state(
        authoritative_state="deterministic-fail",
        advisory_state="model-clear-advisory",
        human_state=None,
    )

    assert merged_fail == "deterministic-fail"


def test_given_config_with_credentials_when_validating_then_rejects() -> None:
    config = {
        "baseUrl": "https://user:pass@example.com",
        "visualReview": {"enabled": True, "operatorConfirmedNoPersonalData": True},
    }

    with pytest.raises(ScriptError, match="credentials"):
        validate_visual_review_config(config)


def test_disabled_visual_review_config_sets_defaults() -> None:
    config = {"baseUrl": "http://127.0.0.1:3000", "visualReview": {"enabled": False}}

    validated = validate_visual_review_config(config)

    assert validated["visualReview"]["enabled"] is False
    assert validated["visualReview"]["maxArtifactBytes"] > 0


def test_given_sensitive_metadata_when_redacting_then_values_are_masked() -> None:
    data = {
        "cookies": ["session=abc"],
        "headers": {"authorization": "Bearer secret"},
        "safe": "visible",
    }

    redacted = redact_sensitive_metadata(data)

    assert redacted["cookies"] == ["[REDACTED]"]
    assert redacted["headers"]["authorization"] == "[REDACTED]"
    assert redacted["safe"] == "visible"


def test_given_git_available_when_collecting_provenance_then_records_commit_and_dirty(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def _fake_run(*args: Any, **kwargs: Any) -> Any:
        if args[0][1:3] == ["rev-parse", "--is-inside-work-tree"]:
            return SimpleNamespace(returncode=0, stdout="true\n", stderr="")
        if args[0][1:3] == ["rev-parse", "--short"]:
            return SimpleNamespace(returncode=0, stdout="abc123\n", stderr="")
        if args[0][1:2] == ["status"]:
            return SimpleNamespace(returncode=0, stdout=" M file.py\n", stderr="")
        return SimpleNamespace(returncode=0, stdout="", stderr="")

    monkeypatch.setattr("runtime_a11y.visual_review.subprocess.run", _fake_run)

    provenance = collect_environment_provenance(Path.cwd())

    assert provenance["git"]["available"] is True
    assert provenance["git"]["commit"] == "abc123"
    assert provenance["git"]["dirty"] is True


def test_given_dirty_workspace_when_collecting_provenance_then_git_is_best_effort(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def _raise(*args: Any, **kwargs: Any) -> Any:
        raise FileNotFoundError("git unavailable")

    monkeypatch.setattr("runtime_a11y.visual_review.subprocess.run", _raise)

    provenance = collect_environment_provenance(Path.cwd())

    assert provenance["git"]["available"] is False
    assert provenance["git"]["dirty"] is False


def test_given_manifest_payload_when_writing_atomically_then_file_is_replaced(
    tmp_path: Path,
) -> None:
    output = tmp_path / "manifest.json"
    payload = {"schemaVersion": "1.0", "runId": "abc"}

    write_json_atomic(output, payload)

    loaded = json.loads(output.read_text(encoding="utf-8"))
    assert loaded == payload


def test_given_run_config_when_resolving_root_then_defaults_to_local_runs(
    tmp_path: Path,
) -> None:
    root = resolve_run_root(tmp_path, run_id="abc123", date="2026-07-17")

    assert root.name == "abc123"
    assert root.parent.name == "2026-07-17"
    assert str(root).endswith(
        ".copilot-tracking/accessibility/local-runs/2026-07-17/abc123"
    )


def test_given_manifest_when_building_then_hashes_and_rel_paths_are_populated(
    tmp_path: Path,
) -> None:
    artifact_dir = tmp_path / "artifacts"
    artifact_dir.mkdir(parents=True, exist_ok=True)
    (artifact_dir / "screenshot.png").write_bytes(b"screenshot-bytes")
    (artifact_dir / "trace.zip").write_bytes(b"trace-bytes")
    (artifact_dir / "metrics.json").write_text("{}", encoding="utf-8")

    payload = build_visual_review_manifest(
        run_root=tmp_path,
        run_id="abc123",
        route="/",
        surface="home",
        state="default",
        viewport={"width": 1440, "height": 900},
        browser={"name": "chrome", "version": "126.0"},
        platform={"os": "windows", "version": "11"},
        screenshot_path="artifacts/screenshot.png",
        trace_path="artifacts/trace.zip",
        measurement_path="artifacts/metrics.json",
        deterministic_metrics={"overflow": False},
        probe_outcomes=[{"id": "reflow", "status": "pass"}],
        provenance={"environment": {"cwd": str(tmp_path)}},
    )

    assert payload["artifacts"]["screenshots"][0]["path"] == "artifacts/screenshot.png"
    assert (
        payload["artifacts"]["screenshots"][0]["sha256"]
        == hashlib.sha256(b"screenshot-bytes").hexdigest()
    )
    assert payload["artifacts"]["manifestPayload"]["sha256"]
    assert payload["artifacts"]["manifestPayload"]["sizeBytes"] > 0
    assert payload["evidenceState"] == "deterministic-pass"


def test_given_absent_screenshot_when_building_manifest_then_fails_closed(
    tmp_path: Path,
) -> None:
    artifact_dir = tmp_path / "artifacts"
    artifact_dir.mkdir(parents=True, exist_ok=True)
    (artifact_dir / "trace.zip").write_bytes(b"trace-bytes")
    (artifact_dir / "metrics.json").write_text("{}", encoding="utf-8")

    with pytest.raises(ScriptError, match="does not exist"):
        build_visual_review_manifest(
            run_root=tmp_path,
            run_id="abc123",
            route="/",
            surface="home",
            state="default",
            viewport={"width": 1440, "height": 900},
            browser={"name": "chrome", "version": "126.0"},
            platform={"os": "windows", "version": "11"},
            screenshot_path="artifacts/screenshot.png",
            trace_path="artifacts/trace.zip",
            measurement_path="artifacts/metrics.json",
            deterministic_metrics={"overflow": False},
            probe_outcomes=[{"id": "reflow", "status": "pass"}],
            provenance={"environment": {"cwd": str(tmp_path)}},
        )


def test_given_capture_failure_outcome_when_building_manifest_then_state_is_fail(
    tmp_path: Path,
) -> None:
    artifact_dir = tmp_path / "artifacts"
    artifact_dir.mkdir(parents=True, exist_ok=True)
    (artifact_dir / "screenshot.png").write_bytes(b"screenshot-bytes")
    (artifact_dir / "trace.zip").write_bytes(b"trace-bytes")
    (artifact_dir / "metrics.json").write_text("{}", encoding="utf-8")

    payload = build_visual_review_manifest(
        run_root=tmp_path,
        run_id="abc123",
        route="/",
        surface="home",
        state="default",
        viewport={"width": 1440, "height": 900},
        browser={"name": "chrome", "version": "126.0"},
        platform={"os": "windows", "version": "11"},
        screenshot_path="artifacts/screenshot.png",
        trace_path="artifacts/trace.zip",
        measurement_path="artifacts/metrics.json",
        deterministic_metrics={"overflow": False},
        probe_outcomes=[{"id": "reflow", "status": "capture-failure"}],
        provenance={"environment": {"cwd": str(tmp_path)}},
    )

    assert payload["evidenceState"] == "deterministic-fail"


def test_given_opaque_token_value_when_redacting_then_masks_but_keeps_digests() -> None:
    redacted = redact_sensitive_metadata(
        {
            "buildTag": "ghp_A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8",
            "sha256": "a" * 64,
            "note": "a short value",
        }
    )

    assert redacted["buildTag"] == "[REDACTED]"
    assert redacted["sha256"] == "a" * 64
    assert redacted["note"] == "a short value"
