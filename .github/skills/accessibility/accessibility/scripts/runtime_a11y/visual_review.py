# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

"""Helpers for local-only visual review evidence manifests and provenance."""

from __future__ import annotations

import contextlib
import hashlib
import json
import os
import platform
import re
import secrets
import subprocess
import tempfile
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath
from typing import Any
from urllib.parse import urlparse

import jsonschema

from runtime_a11y._config import assert_target_allowed
from runtime_a11y._errors import EXIT_USAGE, ScriptError

_SCHEMA_PATH = Path(__file__).with_name("visual-review-manifest.schema.json")
_CONFIG_SCHEMA_PATH = Path(__file__).with_name("config-schema.json")
_DEFAULT_EVIDENCE_ROOT = Path(".copilot-tracking/accessibility/local-runs")
_DEFAULT_MAX_ARTIFACT_BYTES = 1024 * 1024 * 1024
_SENSITIVE_KEY_TOKENS = (
    "authorization",
    "cookie",
    "credential",
    "env",
    "header",
    "password",
    "secret",
    "session",
    "token",
)
_FAILING_PROBE_STATUSES = frozenset(
    {"fail", "failed", "failure", "capture-failure", "error"}
)
_HIGH_ENTROPY_PATTERN = re.compile(r"^[A-Za-z0-9+/_-]{32,}={0,2}$")
_HEX_DIGEST_PATTERN = re.compile(r"^[a-f0-9]+$", re.IGNORECASE)


def compute_sha256(data: bytes | str | Path) -> str:
    """Return a SHA-256 digest for bytes, text, or an existing file path.

    A path that does not exist raises. Digesting the path string instead would
    yield a schema-valid digest for an artifact that was never captured.
    """
    if isinstance(data, Path):
        if not data.exists():
            raise ScriptError(
                f"Cannot hash a visual review artifact that does not exist: {data}",
                EXIT_USAGE,
            )
        payload = data.read_bytes()
    elif isinstance(data, str):
        payload = data.encode("utf-8")
    else:
        payload = data
    return hashlib.sha256(payload).hexdigest()


def _normalize_run_date(value: str | None = None) -> str:
    if value:
        return value
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


def resolve_run_root(
    base_dir: str | Path,
    *,
    run_id: str | None = None,
    date: str | None = None,
) -> Path:
    """Resolve the default local evidence root for one run."""
    base_path = Path(base_dir).expanduser()
    if not base_path.is_absolute():
        base_path = (Path.cwd() / base_path).resolve()
    else:
        base_path = base_path.resolve()

    resolved_date = _normalize_run_date(date)
    resolved_run_id = run_id or f"run-{secrets.token_hex(4)}"
    root = (
        base_path
        / ".copilot-tracking"
        / "accessibility"
        / "local-runs"
        / resolved_date
        / resolved_run_id
    )
    root.parent.mkdir(parents=True, exist_ok=True)
    if root.exists():
        raise ScriptError(
            f"Visual review evidence root already exists: {root}", EXIT_USAGE
        )

    candidate = root
    suffix = 0
    while True:
        try:
            candidate.mkdir(parents=False, exist_ok=False)
            return PurePosixPath(candidate.as_posix())
        except FileExistsError:
            suffix += 1
            candidate = root.parent / f"{root.name}-{suffix}"
            if suffix > 100:
                raise ScriptError(
                    f"Visual review evidence root already exists: {root}", EXIT_USAGE
                )


def _path_is_absolute(path_text: str) -> bool:
    parsed = urlparse(path_text)
    if parsed.scheme and parsed.scheme not in {"file"}:
        return True
    return (
        Path(path_text).is_absolute()
        or path_text.startswith("/")
        or path_text.startswith("\\")
    )


def normalize_manifest_path(path_value: str | Path, *, run_root: str | Path) -> str:
    """Normalize a manifest artifact path and enforce root containment."""
    path_text = str(path_value)
    if not path_text:
        raise ScriptError(
            "Manifest artifact paths must be non-empty and relative.", EXIT_USAGE
        )
    if _path_is_absolute(path_text):
        raise ScriptError(
            "Manifest artifact paths must be relative for containment.", EXIT_USAGE
        )

    parsed = urlparse(path_text)
    if parsed.scheme:
        raise ScriptError(
            "Manifest artifact paths must be relative for containment.", EXIT_USAGE
        )

    if path_text.startswith("\\") or path_text.startswith("/"):
        raise ScriptError(
            "Manifest artifact paths must be relative for containment.", EXIT_USAGE
        )

    normalized = path_text.replace("\\", "/")
    pure_path = PurePosixPath(normalized)
    if any(part == ".." for part in pure_path.parts):
        raise ScriptError("Manifest artifact paths violate containment.", EXIT_USAGE)

    resolved_root = Path(run_root).resolve()
    unresolved_candidate = resolved_root / normalized
    candidate_path = unresolved_candidate.resolve(strict=False)
    try:
        candidate_path.relative_to(resolved_root)
    except ValueError as exc:
        raise ScriptError(
            "Manifest artifact paths violate containment.", EXIT_USAGE
        ) from exc

    # Reject symlinks on the unresolved path. Path.resolve() already follows
    # them, so an is_symlink() test on the resolved path can never be true.
    # Containment itself is enforced above by relative_to; this additionally
    # refuses a symlinked artifact whose target is inside the root, because an
    # evidence path that can be retargeted after validation is not a durable
    # integrity claim.
    probe = unresolved_candidate
    while True:
        if probe.is_symlink():
            raise ScriptError(
                "Manifest artifact paths violate containment.", EXIT_USAGE
            )
        if probe == resolved_root or probe == probe.parent:
            break
        probe = probe.parent
    return normalized


def _iter_artifact_items(manifest: dict[str, Any]) -> list[tuple[str, dict[str, Any]]]:
    artifacts = manifest.get("artifacts") or {}
    items: list[tuple[str, dict[str, Any]]] = []
    for key in ("screenshots", "traces", "deterministicMeasurements"):
        for entry in artifacts.get(key, []) or []:
            if isinstance(entry, dict):
                items.append((key, entry))
    manifest_payload = artifacts.get("manifestPayload") or {}
    if isinstance(manifest_payload, dict):
        items.append(("manifestPayload", manifest_payload))
    return items


def validate_visual_review_manifest(
    manifest: dict[str, Any],
    *,
    run_root: str | Path,
    max_artifact_bytes: int = _DEFAULT_MAX_ARTIFACT_BYTES,
) -> dict[str, Any]:
    """Validate a manifest against the local visual-review schema and safety rules."""
    if not isinstance(manifest, dict):
        raise ScriptError("Visual review manifest must be a JSON object.", EXIT_USAGE)

    resolved_root = Path(run_root).resolve()
    total_bytes = 0
    for _, entry in _iter_artifact_items(manifest):
        path_value = entry.get("path")
        if path_value is None:
            raise ScriptError(
                "Visual review manifest entries must include a relative path.",
                EXIT_USAGE,
            )
        normalized = normalize_manifest_path(path_value, run_root=resolved_root)
        # Measure the artifact's real bytes on disk. A declared sizeBytes is
        # only trusted when the artifact is not yet written, as is the case for
        # the manifest payload describing the file being produced.
        artifact_path = (resolved_root / normalized).resolve(strict=False)
        if artifact_path.exists() and artifact_path.is_file():
            total_bytes += artifact_path.stat().st_size
        else:
            size_bytes = entry.get("sizeBytes")
            if size_bytes is not None:
                total_bytes += int(size_bytes)
        sha256_value = entry.get("sha256")
        if not isinstance(sha256_value, str) or len(sha256_value) != 64:
            raise ScriptError(
                "Visual review artifact hashes must be 64-character SHA-256 digests.",
                EXIT_USAGE,
            )

    try:
        jsonschema.validate(
            instance=manifest,
            schema=json.loads(_SCHEMA_PATH.read_text(encoding="utf-8")),
        )
    except jsonschema.ValidationError as exc:
        raise ScriptError(
            f"Visual review manifest schema validation failed: {exc.message}",
            EXIT_USAGE,
        ) from exc

    if total_bytes > max_artifact_bytes:
        raise ScriptError(
            "Visual review artifact bytes exceed the byte ceiling of "
            f"{max_artifact_bytes} bytes.",
            EXIT_USAGE,
        )

    if total_bytes > _DEFAULT_MAX_ARTIFACT_BYTES:
        raise ScriptError(
            "Visual review artifact bytes exceed the 1 GB byte ceiling.",
            EXIT_USAGE,
        )
    return manifest


def validate_visual_review_config(config: dict[str, Any]) -> dict[str, Any]:
    """Validate the local visual-review opt-in settings."""
    if not isinstance(config, dict):
        raise ScriptError("Runtime config must be a JSON object.", EXIT_USAGE)

    base_url = str(config.get("baseUrl") or "")
    if base_url:
        parsed = urlparse(base_url)
        if parsed.username or parsed.password:
            raise ScriptError(
                "Visual review targets must not embed credentials.", EXIT_USAGE
            )
        if parsed.query:
            lowered_query = parsed.query.lower()
            if any(
                token in lowered_query
                for token in ("token", "auth", "cookie", "session")
            ):
                raise ScriptError(
                    "Visual review targets must not include "
                    "credential-bearing query parameters.",
                    EXIT_USAGE,
                )

    visual_review = config.get("visualReview")
    if visual_review is None:
        visual_review = {}
    elif not isinstance(visual_review, dict):
        raise ScriptError(
            "visualReview must be a JSON object when provided.", EXIT_USAGE
        )

    if visual_review.get("enabled") is True:
        max_artifact_bytes = visual_review.get("maxArtifactBytes")
        if max_artifact_bytes is None:
            visual_review["maxArtifactBytes"] = _DEFAULT_MAX_ARTIFACT_BYTES
        elif int(max_artifact_bytes) > _DEFAULT_MAX_ARTIFACT_BYTES:
            raise ScriptError(
                "Visual review maxArtifactBytes cannot exceed "
                "the 1 GB default ceiling.",
                EXIT_USAGE,
            )
        visual_review.setdefault("publicLoopbackOnly", True)
        visual_review.setdefault("rejectPersonalData", True)
        visual_review.setdefault("evidenceRoot", str(_DEFAULT_EVIDENCE_ROOT))
    else:
        visual_review.setdefault("enabled", False)
        visual_review.setdefault("publicLoopbackOnly", True)
        visual_review.setdefault("rejectPersonalData", True)
        visual_review.setdefault("maxArtifactBytes", _DEFAULT_MAX_ARTIFACT_BYTES)

    if visual_review.get("enabled") is True:
        assert_target_allowed(config, allow_external=False)
        # A full-page screenshot and a Playwright trace capture whatever the
        # surface renders, including any real data behind it. The harness cannot
        # detect personal data, so this setting records what the operator
        # asserts about the target rather than implying a check the tool cannot
        # perform. Capturing anyway requires setting it to false deliberately.
        if visual_review.get("rejectPersonalData") is True and not visual_review.get(
            "operatorConfirmedNoPersonalData"
        ):
            raise ScriptError(
                "Visual review captures full-page screenshots and traces of the "
                "target, so it must not run against a surface holding personal "
                "data. Set visualReview.operatorConfirmedNoPersonalData to true "
                "to confirm the target holds none, or set "
                "visualReview.rejectPersonalData to false to capture anyway.",
                EXIT_USAGE,
            )

    try:
        jsonschema.validate(
            instance=config,
            schema=json.loads(_CONFIG_SCHEMA_PATH.read_text(encoding="utf-8")),
        )
    except jsonschema.ValidationError as exc:
        raise ScriptError(f"Invalid runtime config: {exc.message}", EXIT_USAGE) from exc

    config["visualReview"] = visual_review
    return config


def collect_environment_provenance(cwd: str | Path) -> dict[str, Any]:
    """Capture best-effort environment provenance without sensitive data."""
    resolved_cwd = Path(cwd).resolve()
    provenance = {
        "environment": {
            "cwd": str(resolved_cwd),
            "pythonVersion": platform.python_version(),
            "platform": platform.platform(),
        },
        "git": {
            "available": False,
            "commit": None,
            "dirty": False,
        },
    }

    try:
        result = subprocess.run(
            ["git", "rev-parse", "--is-inside-work-tree"],
            capture_output=True,
            text=True,
            cwd=str(resolved_cwd),
            check=False,
        )
    except (FileNotFoundError, OSError):
        return provenance

    if result.returncode == 0 and "true" in result.stdout.lower():
        provenance["git"]["available"] = True
        commit_result = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            capture_output=True,
            text=True,
            cwd=str(resolved_cwd),
            check=False,
        )
        if commit_result.returncode == 0:
            provenance["git"]["commit"] = commit_result.stdout.strip()
        status_result = subprocess.run(
            ["git", "status", "--porcelain"],
            capture_output=True,
            text=True,
            cwd=str(resolved_cwd),
            check=False,
        )
        if status_result.returncode == 0:
            provenance["git"]["dirty"] = bool(status_result.stdout.strip())
    return provenance


def _resolve_evidence_state(probe_outcomes: list[dict[str, Any]]) -> str:
    """Derive the manifest evidence state from the run's actual probe outcomes."""
    for outcome in probe_outcomes or []:
        if not isinstance(outcome, dict):
            continue
        status = str(outcome.get("status") or "").strip().lower()
        if status in _FAILING_PROBE_STATUSES:
            return "deterministic-fail"
    return "deterministic-pass"


def redact_sensitive_metadata(value: Any) -> Any:
    """Recursively mask sensitive keys and high-entropy values in metadata."""
    if isinstance(value, dict):
        result: dict[str, Any] = {}
        for key, child in value.items():
            if any(token in str(key).lower() for token in _SENSITIVE_KEY_TOKENS):
                if isinstance(child, list):
                    result[str(key)] = ["[REDACTED]"]
                elif isinstance(child, dict):
                    result[str(key)] = redact_sensitive_metadata(child)
                else:
                    result[str(key)] = "[REDACTED]"
            else:
                result[str(key)] = redact_sensitive_metadata(child)
        return result
    if isinstance(value, list):
        return [redact_sensitive_metadata(item) for item in value]
    if isinstance(value, tuple):
        return tuple(redact_sensitive_metadata(item) for item in value)
    # A key-name allowlist cannot catch a secret stored under an innocuous key,
    # so mask values whose shape matches an opaque token or key. Hex digests are
    # excluded because artifact SHA-256 hashes are required manifest content.
    if (
        isinstance(value, str)
        and _HIGH_ENTROPY_PATTERN.match(value)
        and not _HEX_DIGEST_PATTERN.match(value)
    ):
        return "[REDACTED]"
    return value


def merge_evidence_state(
    *,
    authoritative_state: str | None = None,
    advisory_state: str | None = None,
    human_state: str | None = None,
) -> str:
    """Merge evidence states with deterministic and human authority precedence."""
    if human_state is not None:
        return human_state
    if authoritative_state in {"deterministic-fail", "real-at-fail"}:
        return authoritative_state
    if authoritative_state in {"deterministic-pass", "real-at-pass"}:
        return authoritative_state
    return advisory_state or authoritative_state or "ambiguous"


def build_visual_review_manifest(
    *,
    run_root: str | Path,
    run_id: str,
    route: str,
    surface: str,
    state: str,
    viewport: dict[str, Any],
    browser: dict[str, Any],
    platform: dict[str, Any],
    screenshot_path: str,
    trace_path: str,
    measurement_path: str,
    deterministic_metrics: dict[str, Any],
    probe_outcomes: list[dict[str, Any]],
    provenance: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Construct a local visual-review manifest with hashes and safe paths."""
    resolved_root = Path(run_root).resolve()
    resolved_root.mkdir(parents=True, exist_ok=True)
    safe_screenshot_path = normalize_manifest_path(
        screenshot_path, run_root=resolved_root
    )
    safe_trace_path = normalize_manifest_path(trace_path, run_root=resolved_root)
    safe_measurement_path = normalize_manifest_path(
        measurement_path, run_root=resolved_root
    )

    screenshot_bytes = _hash_source_bytes(screenshot_path, resolved_root)
    trace_bytes = _hash_source_bytes(trace_path, resolved_root)
    measurement_bytes = _hash_source_bytes(measurement_path, resolved_root)

    manifest_payload = {
        "schemaVersion": "1.0",
        "runId": run_id,
        "createdAt": datetime.now(timezone.utc).isoformat(),
        "route": route,
        "surface": surface,
        "state": state,
        "viewport": viewport,
        "zoom": {"scale": 1.0},
        "browser": browser,
        "platform": platform,
        "artifacts": {
            "screenshots": [
                {
                    "id": "default",
                    "path": safe_screenshot_path,
                    "sha256": screenshot_bytes,
                    "width": viewport.get("width"),
                    "height": viewport.get("height"),
                }
            ],
            "traces": [
                {
                    "id": "default",
                    "path": safe_trace_path,
                    "sha256": trace_bytes,
                }
            ],
            "deterministicMeasurements": [
                {
                    "id": "default",
                    "path": safe_measurement_path,
                    "sha256": measurement_bytes,
                }
            ],
            "manifestPayload": {
                "id": "manifest",
                "path": "manifest.json",
                "sha256": "",
                "sizeBytes": 0,
            },
        },
        "deterministicMetrics": redact_sensitive_metadata(deterministic_metrics),
        "probeOutcomes": redact_sensitive_metadata(probe_outcomes),
        "provenance": redact_sensitive_metadata(
            provenance or collect_environment_provenance(resolved_root)
        ),
        "evidenceState": _resolve_evidence_state(probe_outcomes),
    }

    payload_bytes = json.dumps(manifest_payload, indent=2, sort_keys=True).encode(
        "utf-8"
    )
    manifest_payload_hash = compute_sha256(payload_bytes)
    manifest_payload["artifacts"]["manifestPayload"]["sha256"] = manifest_payload_hash
    manifest_payload["artifacts"]["manifestPayload"]["sizeBytes"] = len(payload_bytes)
    return manifest_payload


def _hash_source_bytes(path_value: str, run_root: Path) -> str:
    """Digest an artifact's real bytes, failing closed when it does not exist."""
    candidate = Path(path_value)
    if not candidate.is_absolute():
        candidate = (run_root / candidate).resolve()
    if not candidate.exists():
        raise ScriptError(
            f"Cannot hash a visual review artifact that does not exist: {candidate}",
            EXIT_USAGE,
        )
    return compute_sha256(candidate.read_bytes())


def write_json_atomic(path_value: str | Path, payload: dict[str, Any]) -> Path:
    """Write a JSON document atomically to disk."""
    path = Path(path_value).expanduser()
    path.parent.mkdir(parents=True, exist_ok=True)
    payload_text = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    file_handle = tempfile.NamedTemporaryFile(
        mode="w",
        encoding="utf-8",
        dir=str(path.parent),
        prefix=path.name,
        suffix=".tmp",
        delete=False,
    )
    try:
        with file_handle:
            file_handle.write(payload_text)
        os.replace(file_handle.name, path)
    except Exception:
        # The temporary file is already gone when replace partially succeeded.
        with contextlib.suppress(FileNotFoundError):
            os.unlink(file_handle.name)
        raise
    return path
