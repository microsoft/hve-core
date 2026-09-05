#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

"""CLI entry point for the runtime accessibility probe harness.

Subcommands:
    run-all              Run every scoped probe and aggregate normalized results.
    probe                Run one probe across its scoped surfaces and states.
    render-artifacts     Render coverage and review artifacts from a matrix.
    capture-visual-review
                         Capture deterministic visual-review evidence.
    run-calibration      Run the local calibration loop.
    run-at-plan          List or execute persisted assistive-technology cases.
    verify-intent        Write a Design Intent verification artifact.
    project-intent       Render a Design Intent record as Markdown.

The harness invokes the Playwright probes with the skill-local Node package under
``scripts/runtime_a11y`` (``package.json`` + ``package-lock.json``). Install the
dependencies once with ``npm ci`` in that directory; the probes then resolve
Playwright, axe-core, and the virtual screen reader from the local
``node_modules``. Config is passed to the Node runner through environment
variables. Exit code is 0 on a completed run even when findings exist; a non-zero
exit signals a harness error (bad config, missing dependencies, missing Node or
browser, or a blocked target). ``verify-intent`` additionally exits with
EXIT_INTENT_DRIFT when a blocking expectation failed and EXIT_INTENT_UNCOVERED
when a blocking expectation was not evaluated.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import signal
import subprocess
import sys
import time
from copy import deepcopy
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterator
from urllib.error import URLError
from urllib.parse import urljoin, urlparse
from urllib.request import urlopen

if __package__ in {None, ""}:
    sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from runtime_a11y import _intent as intent
from runtime_a11y import _projection as projection
from runtime_a11y._config import (
    LOOPBACK_HOSTS,
    assert_target_allowed,
    load_validated_config,
)
from runtime_a11y._errors import (
    EXIT_FAILURE,
    EXIT_INTENT_DRIFT,
    EXIT_INTENT_UNCOVERED,
    EXIT_SUCCESS,
    EXIT_USAGE,
    ScriptError,
)
from runtime_a11y.matrix import compute_coverage, render_artifact_bundle
from runtime_a11y.matrix._catalog import apply_criteria_catalog, catalog_provenance
from runtime_a11y.matrix._model import Matrix
from runtime_a11y.matrix._provenance import build_artifact_metadata
from runtime_a11y.matrix._render_test_plan import build_manual_test_cases
from runtime_a11y.visual_review import (
    build_visual_review_manifest,
    resolve_run_root,
    validate_visual_review_config,
    validate_visual_review_manifest,
    write_json_atomic,
)

_PACKAGE_DIR = Path(__file__).resolve().parent
_PACKAGE_ROOT = _PACKAGE_DIR.parent.parent
_RUNNER_INDEX = _PACKAGE_DIR / "runner" / "index.mjs"
_PROBE_MAP_PATH = _PACKAGE_DIR / "probe-criteria-map.json"
_NODE_MODULES = _PACKAGE_DIR / "node_modules"
_REPO_ROOT = _PACKAGE_DIR.parents[5]
# An owned server builds the production site before it listens, and that build
# dominates startup. A full build of this site was measured at 259 seconds, so
# the owned-start budget is set well above it. Confirming an already-running
# server needs no budget here, because that path probes once with its own
# request timeout rather than waiting for a build.
_VISUAL_REVIEW_SERVER_BUILD_TIMEOUT_SECONDS = 900.0
_VISUAL_REVIEW_SERVER_POLL_INTERVAL_SECONDS = 0.5
_LIVE_TEST_START_NOTICE = (
    "LIVE ACCESSIBILITY TESTING WILL CONTROL NVDA, CHROME, KEYBOARD FOCUS, "
    "AND PAGE INPUT. DO NOT INTERACT WITH THIS COMPUTER UNTIL THE TEST "
    "ROUTINE REPORTS COMPLETION."
)
_LIVE_TEST_FINISH_NOTICE = (
    "LIVE ACCESSIBILITY TESTING HAS FINISHED. IT IS SAFE TO INTERACT WITH "
    "THIS COMPUTER AGAIN."
)


def _local_runs_root() -> Path:
    return (_REPO_ROOT / ".copilot-tracking" / "accessibility" / "local-runs").resolve(
        strict=False
    )


def _require_harness_dependencies(purpose: str) -> None:
    """Fail before any server or browser work when Node dependencies are absent.

    Callers invoke this before starting or probing a server so an unprepared
    checkout reports the install step instead of paying for a server startup
    first.
    """
    if _NODE_MODULES.exists():
        return
    raise ScriptError(
        "Runtime probe dependencies are not installed. Run 'npm ci' in "
        f"{_PACKAGE_DIR} to install Playwright, axe-core, and the virtual "
        f"screen reader before {purpose}.",
        EXIT_USAGE,
    )


def _split_loopback_target(base_url: str) -> tuple[str, int]:
    """Return the host and port a managed local server must bind."""
    parsed = urlparse(base_url)
    host = parsed.hostname or "127.0.0.1"
    port = parsed.port
    if port is None:
        port = 443 if parsed.scheme == "https" else 80
    return host, port


def _is_within(path_value: Path, root_value: Path) -> bool:
    try:
        path_value.relative_to(root_value)
        return True
    except ValueError:
        return False


def _resolve_output_allowed_root(
    run_root: Path | None,
    out_path: Path | None,
) -> Path:
    if run_root is None or out_path is None:
        return _local_runs_root()

    resolved_run_root = Path(run_root).expanduser()
    if not resolved_run_root.is_absolute():
        resolved_run_root = (_REPO_ROOT / resolved_run_root).expanduser()
    resolved_run_root = resolved_run_root.resolve(strict=False)

    resolved_out_path = Path(out_path).expanduser()
    if not resolved_out_path.is_absolute():
        resolved_out_path = (_REPO_ROOT / resolved_out_path).expanduser()
    resolved_out_path = resolved_out_path.resolve(strict=False)

    candidate = resolved_run_root
    while True:
        if _is_within(resolved_out_path, candidate):
            return candidate
        if candidate == _local_runs_root() or candidate == candidate.parent:
            break
        candidate = candidate.parent
    return _local_runs_root()


def _resolve_repo_path(
    path_value: str | Path | None,
    *,
    allowed_root: Path | None = None,
    kind: str,
) -> Path:
    if path_value is None:
        raise ScriptError(f"{kind} is required.", EXIT_USAGE)

    raw_text = str(path_value).strip()
    if not raw_text:
        raise ScriptError(f"{kind} must not be empty.", EXIT_USAGE)

    candidate = Path(raw_text).expanduser()
    if not candidate.is_absolute():
        candidate = (_REPO_ROOT / candidate).expanduser()

    parsed = urlparse(raw_text)
    is_windows_drive = (
        len(parsed.scheme) == 1
        and len(raw_text) >= 3
        and raw_text[1] == ":"
        and raw_text[2] in {"/", "\\"}
    )
    if raw_text.startswith("file://") or (parsed.scheme and not is_windows_drive):
        raise ScriptError(
            f"{kind} must be a local filesystem path, not a URI.", EXIT_USAGE
        )

    resolved = candidate.resolve(strict=False)
    if allowed_root is None:
        if kind == "--run-root":
            root_candidate = _local_runs_root()
        else:
            root_candidate = None
    else:
        root_candidate = Path(allowed_root).expanduser()
    if root_candidate is not None:
        if not root_candidate.is_absolute():
            root_candidate = (_REPO_ROOT / root_candidate).expanduser()
        root = root_candidate.resolve(strict=False)

        if not _is_within(resolved, root):
            raise ScriptError(
                f"{kind} must resolve inside {root}.",
                EXIT_USAGE,
            )
        if resolved == root:
            raise ScriptError(
                f"{kind} must resolve to a child path beneath {root}.",
                EXIT_USAGE,
            )
    if any(part == ".." for part in candidate.parts):
        raise ScriptError(
            f"{kind} must not contain traversal segments.",
            EXIT_USAGE,
        )
    return resolved


def _public_path(path_value: str | Path | None) -> str | None:
    if path_value is None:
        return None

    candidate = Path(path_value).expanduser()
    if not candidate.is_absolute():
        candidate = (_PACKAGE_ROOT / candidate).expanduser()

    resolved = candidate.resolve(strict=False)
    try:
        return resolved.relative_to(_REPO_ROOT.resolve()).as_posix()
    except ValueError:
        return resolved.as_posix()


def _resolve_within_root(
    path_value: str | Path | None,
    *,
    base_dir: Path | None = None,
    allowed_root: Path,
    kind: str,
) -> Path:
    if path_value is None:
        raise ScriptError(f"{kind} is required.", EXIT_USAGE)

    raw_text = str(path_value).strip()
    if not raw_text:
        raise ScriptError(f"{kind} must not be empty.", EXIT_USAGE)

    candidate = Path(raw_text).expanduser()
    if not candidate.is_absolute():
        base_path = base_dir or _REPO_ROOT
        candidate = (base_path / candidate).expanduser()

    parsed = urlparse(raw_text)
    is_windows_drive = (
        len(parsed.scheme) == 1
        and len(raw_text) >= 3
        and raw_text[1] == ":"
        and raw_text[2] in {"/", "\\"}
    )
    if raw_text.startswith("file://") or (parsed.scheme and not is_windows_drive):
        raise ScriptError(
            f"{kind} must be a local filesystem path, not a URI.", EXIT_USAGE
        )

    resolved = candidate.resolve(strict=False)
    root = Path(allowed_root).expanduser().resolve(strict=False)
    if not _is_within(resolved, root):
        raise ScriptError(f"{kind} must resolve inside {root}.", EXIT_USAGE)
    if any(part == ".." for part in candidate.parts):
        raise ScriptError(f"{kind} must not contain traversal segments.", EXIT_USAGE)
    if resolved.exists() and resolved.is_dir():
        raise ScriptError(f"{kind} must resolve to a file.", EXIT_USAGE)
    return resolved


def _all_probe_ids() -> list[str]:
    payload = json.loads(_PROBE_MAP_PATH.read_text(encoding="utf-8"))
    return [probe["probeId"] for probe in payload.get("probes", [])]


def _normalize_probe_id(name: str, known: set[str]) -> str | None:
    """Resolve a config probe name to a known runner probe id, or None."""
    if name in known:
        return name
    prefixed = name if name.startswith("probe-") else f"probe-{name}"
    if prefixed in known:
        return prefixed
    matches = [pid for pid in known if name in pid]
    return matches[0] if len(matches) == 1 else None


def _iter_runs(
    config: dict[str, Any],
    probe_filter: str | None = None,
    surface_filter: str | None = None,
    state_filter: str | None = None,
) -> Iterator[tuple[str, str, str]]:
    """Yield (probeId, surfaceId, state) combinations to execute."""
    known = set(_all_probe_ids())
    surfaces = {s["id"]: s for s in config.get("surfaces", []) if "id" in s}
    scoping = config.get("probeScoping") or []
    if scoping:
        for entry in scoping:
            probe = _normalize_probe_id(str(entry.get("probe", "")), known)
            if probe is None:
                continue
            if probe_filter and probe != probe_filter:
                continue
            surface_ids = entry.get("surfaces") or list(surfaces)
            states = entry.get("states") or ["default"]
            for sid in surface_ids:
                if surface_filter and str(sid) != surface_filter:
                    continue
                for state in states:
                    if state_filter and str(state) != state_filter:
                        continue
                    yield probe, sid, state
        return
    probes = [probe_filter] if probe_filter else sorted(known)
    for probe in probes:
        for sid, surface in surfaces.items():
            if surface_filter and sid != surface_filter:
                continue
            states = [st.get("state") for st in surface.get("states", [])] or [
                "default"
            ]
            for state in states:
                if state_filter and state != state_filter:
                    continue
                yield probe, sid, state


def _run_probe(
    config: dict[str, Any],
    probe_id: str,
    surface_id: str,
    state: str,
    base_url: str,
    trace: bool,
) -> dict[str, Any]:
    """Invoke the Node runner for one probe/surface/state and parse its JSON."""
    _require_harness_dependencies("running the harness")
    command = [
        "node",
        str(_RUNNER_INDEX),
        probe_id,
    ]
    env = {
        **os.environ,
        "RUNTIME_A11Y_CONFIG": json.dumps(config),
        "RUNTIME_A11Y_PROBE_ID": probe_id,
        "RUNTIME_A11Y_SURFACE_ID": surface_id,
        "RUNTIME_A11Y_STATE": state,
        "RUNTIME_A11Y_BASE_URL": base_url,
        "RUNTIME_A11Y_TRACE": "1" if trace else "0",
    }
    try:
        completed = subprocess.run(
            command,
            capture_output=True,
            text=True,
            check=False,
            env=env,
            cwd=str(_PACKAGE_DIR),
        )
    except FileNotFoundError as exc:
        raise ScriptError(
            "Node is unavailable. Install Node.js and system Google Chrome, then "
            f"run 'npm ci' in {_PACKAGE_DIR}, to run runtime probes.",
            EXIT_USAGE,
        ) from exc

    # A probe may produce valid accessibility findings and still report an
    # operational failure, such as being unable to prove it stopped a screen
    # reader it started. The finding and the failure are separate facts: the
    # payload is kept so the evidence is not lost, and the failure is carried
    # alongside it so the run still fails.
    payload: dict[str, Any] | None = None
    if completed.stdout.strip():
        try:
            payload = json.loads(completed.stdout)
        except json.JSONDecodeError:
            payload = None

    if completed.returncode != 0:
        stderr = (completed.stderr or "").strip() or "No probe output captured"
        if payload is None:
            raise ScriptError(
                f"Probe '{probe_id}' failed for surface '{surface_id}' "
                f"state '{state}': {stderr}"
            )
        payload["operationalFailure"] = {
            "probeId": probe_id,
            "surfaceId": surface_id,
            "state": state,
            "reason": stderr,
        }
        return payload

    if payload is None:
        raise ScriptError(f"Probe '{probe_id}' returned invalid JSON output")
    return payload


def _run_prerequisite_probe(
    config: dict[str, Any],
    base_url: str,
    trace: bool = False,
) -> dict[str, Any]:
    """Probe local calibration prerequisites through the Node executor."""
    _require_harness_dependencies("running calibration")

    script = (
        "import { pathToFileURL } from 'node:url';"
        "const modulePath = process.env.RUNTIME_A11Y_CALIBRATION_EXECUTOR_MODULE;"
        "const { probePrerequisites } = await import(pathToFileURL(modulePath).href);"
        "const config = JSON.parse(process.env.RUNTIME_A11Y_CONFIG || '{}');"
        "const payload = await probePrerequisites(config, null);"
        "process.stdout.write(JSON.stringify(payload));"
    )
    env = {
        **os.environ,
        "RUNTIME_A11Y_CONFIG": json.dumps(config),
        "RUNTIME_A11Y_BASE_URL": base_url,
        "RUNTIME_A11Y_TRACE": "1" if trace else "0",
        "RUNTIME_A11Y_CALIBRATION_EXECUTOR_MODULE": str(
            _PACKAGE_DIR / "runner" / "calibration-executor.mjs"
        ),
    }
    try:
        completed = subprocess.run(
            ["node", "--input-type=module", "-e", script],
            capture_output=True,
            text=True,
            check=True,
            env=env,
            cwd=str(_PACKAGE_DIR),
        )
    except FileNotFoundError as exc:
        raise ScriptError(
            "Node is unavailable. Install Node.js and system Google Chrome, then "
            f"run 'npm ci' in {_PACKAGE_DIR}, to run calibration.",
            EXIT_USAGE,
        ) from exc
    except subprocess.CalledProcessError as exc:
        stderr = (exc.stderr or "").strip() or "No prerequisite output captured"
        raise ScriptError(f"Calibration prerequisite probe failed: {stderr}") from exc

    stdout = (completed.stdout or "").strip()
    if not stdout:
        return {"ok": True, "reason": "Calibration prerequisites are ready."}
    try:
        return json.loads(stdout)
    except json.JSONDecodeError:
        return {"ok": True, "reason": "Calibration prerequisites are ready."}


def _run_calibration_session(
    config: dict[str, Any],
    base_url: str,
    run_root: str | None,
    trace: bool = False,
) -> dict[str, Any]:
    """Invoke the Node calibration executor and parse its JSON payload."""
    if not _NODE_MODULES.exists():
        raise ScriptError(
            "Runtime probe dependencies are not installed. Run 'npm ci' in "
            f"{_PACKAGE_DIR} to install Playwright, axe-core, and the virtual "
            "screen reader before running calibration.",
            EXIT_USAGE,
        )

    command = ["node", str(_PACKAGE_DIR / "runner" / "calibration-executor.mjs")]
    env = {
        **os.environ,
        "RUNTIME_A11Y_CONFIG": json.dumps(config),
        "RUNTIME_A11Y_BASE_URL": base_url,
        "RUNTIME_A11Y_TRACE": "1" if trace else "0",
        "RUNTIME_A11Y_RUN_ROOT": run_root or "",
    }
    try:
        completed = subprocess.run(
            command,
            capture_output=True,
            text=True,
            check=True,
            env=env,
            cwd=str(_PACKAGE_DIR),
        )
    except FileNotFoundError as exc:
        raise ScriptError(
            "Node is unavailable. Install Node.js and system Google Chrome, then "
            f"run 'npm ci' in {_PACKAGE_DIR}, to run calibration.",
            EXIT_USAGE,
        ) from exc
    except subprocess.CalledProcessError as exc:
        stderr = (exc.stderr or "").strip() or "No calibration output captured"
        raise ScriptError(f"Calibration failed: {stderr}") from exc

    stdout = (completed.stdout or "").strip()
    if not stdout:
        raise ScriptError("Calibration produced no JSON output", EXIT_USAGE)
    try:
        return json.loads(stdout)
    except json.JSONDecodeError as exc:
        raise ScriptError("Calibration returned invalid JSON output") from exc


def _run_visual_review_capture(
    config: dict[str, Any],
    base_url: str,
    run_root: Path,
    trace: bool,
    *,
    surfaces: list[str] | None = None,
    states: list[str] | None = None,
) -> dict[str, Any]:
    """Invoke the Node visual-review runner and parse its JSON payload."""
    _require_harness_dependencies("running visual review capture")

    command = ["node", str(_PACKAGE_DIR / "runner" / "visual-review-executor.mjs")]
    env = {
        **os.environ,
        "RUNTIME_A11Y_CONFIG": json.dumps(config),
        "RUNTIME_A11Y_BASE_URL": base_url,
        "RUNTIME_A11Y_TRACE": "1" if trace else "0",
        "RUNTIME_A11Y_VISUAL_REVIEW_RUN_ROOT": str(run_root),
        "RUNTIME_A11Y_VISUAL_REVIEW_SURFACES": json.dumps(surfaces or []),
        "RUNTIME_A11Y_VISUAL_REVIEW_STATES": json.dumps(states or []),
    }
    try:
        completed = subprocess.run(
            command,
            capture_output=True,
            text=True,
            check=True,
            env=env,
            cwd=str(_PACKAGE_DIR),
        )
    except FileNotFoundError as exc:
        raise ScriptError(
            "Node is unavailable. Install Node.js and system Google Chrome, then "
            f"run 'npm ci' in {_PACKAGE_DIR}, to run visual review capture.",
            EXIT_USAGE,
        ) from exc
    except subprocess.CalledProcessError as exc:
        stderr = (exc.stderr or "").strip() or "No visual review output captured"
        raise ScriptError(f"Visual review capture failed: {stderr}") from exc

    stdout = (completed.stdout or "").strip()
    if not stdout:
        raise ScriptError("Visual review capture produced no JSON output", EXIT_USAGE)
    try:
        return json.loads(stdout)
    except json.JSONDecodeError as exc:
        raise ScriptError("Visual review capture returned invalid JSON output") from exc


def _materialize_visual_review_artifact(
    source_path: str,
    *,
    run_root: Path,
    manifest_dir: Path,
) -> str:
    """Copy a run-root artifact into the manifest directory.

    The path is preserved as a safe relative path inside the manifest directory.
    """
    if not source_path:
        raise ScriptError(
            "Visual review artifact paths must be non-empty.",
            EXIT_USAGE,
        )

    candidate = Path(source_path)
    if isinstance(source_path, str) and (
        source_path.startswith("http://")
        or source_path.startswith("https://")
        or source_path.startswith("file://")
    ):
        raise ScriptError(
            "Visual review artifact paths must be relative for containment.",
            EXIT_USAGE,
        )

    resolved_root = run_root.resolve()
    candidate_path = (
        candidate if candidate.is_absolute() else (resolved_root / candidate)
    )
    resolved_source = candidate_path.resolve(strict=False)
    if not resolved_source.exists() and candidate.is_absolute():
        if not resolved_source.is_relative_to(resolved_root):
            raise ScriptError(
                "Visual review artifact paths violate containment.",
                EXIT_USAGE,
            )

    try:
        resolved_source.relative_to(resolved_root)
    except ValueError as exc:
        raise ScriptError(
            "Visual review artifact paths violate containment.",
            EXIT_USAGE,
        ) from exc

    if resolved_source.exists():
        try:
            resolved_source = resolved_source.resolve(strict=True)
        except OSError as exc:
            raise ScriptError(
                "Visual review artifact paths violate containment.",
                EXIT_USAGE,
            ) from exc
        try:
            resolved_source.relative_to(resolved_root)
        except ValueError as exc:
            raise ScriptError(
                "Visual review artifact paths violate containment.",
                EXIT_USAGE,
            ) from exc

    if not resolved_source.exists():
        raise ScriptError(
            f"Visual review artifact does not exist: {resolved_source}",
            EXIT_USAGE,
        )

    relative_source = resolved_source.relative_to(resolved_root).as_posix()

    target_path = (manifest_dir / relative_source).resolve()
    try:
        target_path.relative_to(manifest_dir.resolve())
    except ValueError as exc:
        raise ScriptError(
            "Visual review artifact paths violate containment.",
            EXIT_USAGE,
        ) from exc

    target_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(resolved_source, target_path)
    return relative_source


def _select_visual_review_plan(
    config: dict[str, Any],
    *,
    surfaces: list[str] | None = None,
    states: list[str] | None = None,
) -> dict[str, list[str]]:
    """Validate and select visual-review surfaces and states from config."""
    if not isinstance(config, dict):
        raise ScriptError("Runtime config must be a JSON object.", EXIT_USAGE)

    visual_review = config.get("visualReview") or {}
    routes = []
    if isinstance(visual_review.get("routes"), list):
        routes = [entry for entry in visual_review["routes"] if isinstance(entry, dict)]
    elif isinstance(config.get("surfaces"), list):
        for entry in config.get("surfaces") or []:
            if isinstance(entry, dict):
                routes.append(
                    {
                        "path": entry.get("route") or "/",
                        "surfaceId": entry.get("id")
                        or entry.get("surfaceId")
                        or "surface",
                    }
                )

    configured_states = []
    if isinstance(visual_review.get("states"), list):
        configured_states = [
            str(entry) for entry in visual_review["states"] if str(entry)
        ]
    if not configured_states:
        configured_states = [
            "desktop",
            "reflow-320",
            "zoom-200",
            "text-spacing",
            "forced-colors",
        ]

    available_surfaces = [
        str(entry.get("surfaceId") or entry.get("id") or "surface") for entry in routes
    ]
    if not available_surfaces:
        available_surfaces = ["surface"]

    requested_surfaces = [str(surface) for surface in (surfaces or []) if str(surface)]
    if requested_surfaces:
        unknown_surfaces = [
            surface
            for surface in requested_surfaces
            if surface not in available_surfaces
        ]
        if unknown_surfaces:
            raise ScriptError(
                (
                    "Requested visual review surface(s) are not in the "
                    "configured plan: "
                    f"{', '.join(unknown_surfaces)}"
                ),
                EXIT_USAGE,
            )
        selected_surfaces = requested_surfaces
    else:
        selected_surfaces = available_surfaces

    requested_states = [str(state) for state in (states or []) if str(state)]
    if requested_states:
        unknown_states = [
            state for state in requested_states if state not in configured_states
        ]
        if unknown_states:
            raise ScriptError(
                (
                    "Requested visual review state(s) are not in the configured plan: "
                    f"{', '.join(unknown_states)}"
                ),
                EXIT_USAGE,
            )
        selected_states = requested_states
    else:
        selected_states = configured_states

    return {"surfaces": selected_surfaces, "states": selected_states}


def _resolve_guarded_base_url(
    config: dict[str, Any],
    override: str | None,
    *,
    allow_external: bool,
) -> str:
    """Return the effective base URL, re-entering the guard for an override.

    ``load_validated_config`` guards the config's own base URL. A ``--base-url``
    override replaces that value after the check, so the override is validated
    here and every navigable target passes the guard exactly once.
    """
    base_url = override or config.get("baseUrl", "")
    if override:
        assert_target_allowed(
            {"baseUrl": override, "allowlist": config.get("allowlist") or []},
            allow_external=allow_external,
        )
    return base_url


def _probe_visual_review_server(base_url: str) -> bool:
    """Return True when an already-running loopback server answers healthily."""
    try:
        parsed = urlparse(base_url)
    except ValueError:
        return False
    if parsed.scheme not in {"http", "https"}:
        return False
    host = (parsed.hostname or "").lower()
    # One definition of loopback, shared with the SSRF guard, so a host the
    # guard refuses cannot be probed here.
    if host not in LOOPBACK_HOSTS:
        return False
    probe_url = (
        base_url
        if base_url.rstrip("/").endswith(parsed.path or "")
        else base_url.rstrip("/") + "/"
    )
    try:
        with urlopen(probe_url, timeout=1.5) as response:
            return 200 <= response.getcode() < 500
    except (URLError, TimeoutError, OSError):
        return False


class _VisualReviewServerLease(tuple):
    """Backward-compatible lease object for visual-review server ownership."""

    def __new__(cls, process: Any, owned: bool) -> "_VisualReviewServerLease":
        return super().__new__(cls, (process, owned))

    def __eq__(self, other: object) -> bool:
        if isinstance(other, tuple) and len(other) == 2:
            return tuple(self) == tuple(other)
        return self[0] == other


def _emit_runtime_notice(message: str) -> None:
    """Emit a human-readable safety notice to stderr without disturbing JSON output."""
    print(message, file=sys.stderr)


def _emit_live_test_start_notice(
    run_root: str | Path | None, journey_count: int
) -> None:
    """Emit the safety start notice before live accessibility control begins."""
    _emit_runtime_notice(_LIVE_TEST_START_NOTICE)
    safe_run_root = _public_path(run_root) if run_root is not None else "."
    if not safe_run_root:
        safe_run_root = "."
    _emit_runtime_notice(f"Run root: {safe_run_root} | Journey count: {journey_count}")


def _emit_live_test_finish_notice() -> None:
    """Emit the safety finish notice after owned cleanup completes."""
    _emit_runtime_notice(_LIVE_TEST_FINISH_NOTICE)


def _start_visual_review_server(base_url: str) -> subprocess.Popen[str]:
    """Start the local Docusaurus production preview for visual review capture.

    Capture produces durable visual evidence, so it targets the built site the
    end-to-end suite also verifies rather than the development bundle, whose
    rendering Docusaurus documents as differing from production.
    """
    docs_dir = _REPO_ROOT / "docs" / "docusaurus"
    if not docs_dir.exists():
        raise ScriptError(
            "Visual review capture requires the docs/docusaurus workspace to be "
            "available.",
            EXIT_USAGE,
        )

    host, port = _split_loopback_target(base_url)
    # Build the site, then serve it. Capture is durable evidence, so it targets
    # a freshly built production bundle rather than whatever build output
    # happens to be on disk.
    # Resolve npm through PATH. On Windows the executable is npm.cmd, which
    # CreateProcess does not discover from the bare name, so a literal "npm"
    # argument fails to launch.
    npm_executable = shutil.which("npm") or "npm"
    command = [npm_executable, "run", "serve:preview"]
    # Give the server its own process group so stopping it reaches the child npm
    # spawns. Windows uses taskkill for the same reason and needs no flag here.
    group_kwargs: dict[str, Any] = (
        {} if sys.platform == "win32" else {"start_new_session": True}
    )
    try:
        process = subprocess.Popen(
            command,
            cwd=str(docs_dir),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.STDOUT,
            stdin=subprocess.DEVNULL,
            text=True,
            env={**os.environ, "HOST": host, "PORT": str(port)},
            **group_kwargs,
        )
    except FileNotFoundError as exc:
        raise ScriptError(
            "Visual review capture requires npm to be available on PATH.",
            EXIT_USAGE,
        ) from exc

    deadline = time.monotonic() + _VISUAL_REVIEW_SERVER_BUILD_TIMEOUT_SECONDS
    while time.monotonic() < deadline:
        if _probe_visual_review_server(base_url):
            return process
        if process.poll() is not None:
            raise ScriptError(
                "Visual review server exited before becoming ready. Confirm "
                f"'npm run serve:preview' succeeds in {docs_dir}.",
                EXIT_USAGE,
            )
        time.sleep(_VISUAL_REVIEW_SERVER_POLL_INTERVAL_SECONDS)

    if process.poll() is None:
        terminate = getattr(process, "terminate", None)
        if callable(terminate):
            terminate()
        try:
            wait = getattr(process, "wait", None)
            if callable(wait):
                wait(timeout=5)
        except subprocess.TimeoutExpired:
            kill = getattr(process, "kill", None)
            if callable(kill):
                kill()
    raise ScriptError(
        "Visual review server did not become ready in time.",
        EXIT_USAGE,
    )


def _terminate_owned_server(process: subprocess.Popen[str]) -> None:
    """Stop a spawned server and every descendant it created.

    npm runs the server in a child process, so stopping only the npm wrapper
    orphans that child while it still holds the port. A later capture would then
    find a listener this command does not own and reuse it instead of serving a
    freshly built site.
    """
    pid = getattr(process, "pid", None)
    if pid is not None:
        if sys.platform == "win32":
            # TerminateProcess stops only the named process. taskkill /T walks
            # the tree, which is the only way to reach npm's server child.
            subprocess.run(
                ["taskkill", "/T", "/F", "/PID", str(pid)],
                capture_output=True,
                check=False,
            )
            return
        try:
            os.killpg(os.getpgid(pid), signal.SIGTERM)
            return
        except (OSError, ProcessLookupError):
            pass

    terminate = getattr(process, "terminate", None)
    if callable(terminate):
        terminate()


def _stop_visual_review_server(process: subprocess.Popen[str] | None) -> None:
    """Stop a process created by this command without touching an existing server."""
    if process is None:
        return
    if process.poll() is not None:
        return
    try:
        _terminate_owned_server(process)
        wait = getattr(process, "wait", None)
        if callable(wait):
            wait(timeout=5)
    except (OSError, ProcessLookupError):
        return
    except subprocess.TimeoutExpired:
        kill = getattr(process, "kill", None)
        if callable(kill):
            kill()


def _ensure_visual_review_server(
    base_url: str, serve_mode: str = "auto"
) -> _VisualReviewServerLease:
    """Resolve server ownership for the configured serve mode.

    A startup failure is raised with its cause. Returning an unowned lease would
    be indistinguishable from reusing a healthy server, so capture would proceed
    against a server that is not running.
    """
    mode = (serve_mode or "auto").strip().lower()
    if mode in {"external", "off"}:
        # The caller owns reachability. Probing would imply this command can
        # manage a target it is not allowed to start or stop.
        return _VisualReviewServerLease(None, False)

    if mode not in {"auto", "served"}:
        raise ScriptError(
            f"Unsupported serveMode '{serve_mode}'. Use auto, served, external, "
            "or off.",
            EXIT_USAGE,
        )

    # auto and served manage or health-check a local server, so they accept only
    # loopback targets. A non-loopback target remains valid under external/off
    # once the existing allowlist or --allow-external guard authorizes it.
    host = (urlparse(base_url).hostname or "").lower()
    if host not in LOOPBACK_HOSTS:
        raise ScriptError(
            f"serveMode '{mode}' manages a local server and requires a loopback "
            f"base URL, but '{base_url}' resolves to host '{host}'. Use "
            "serveMode 'external' or 'off' for a target this command must not "
            "manage.",
            EXIT_USAGE,
        )

    if _probe_visual_review_server(base_url):
        return _VisualReviewServerLease(None, False)

    if mode == "served":
        raise ScriptError(
            f"serveMode 'served' expects a server already answering {base_url}. "
            "Start it first (for example 'npm run serve:preview' in "
            "docs/docusaurus), or set serveMode to 'auto' to let this command "
            "start and stop its own server.",
            EXIT_USAGE,
        )

    return _VisualReviewServerLease(_start_visual_review_server(base_url), True)


def _write_visual_review_manifests(
    payload: dict[str, Any],
    run_root: Path,
    *,
    max_artifact_bytes: int | None = None,
) -> list[str]:
    """Create validated local manifests for each captured visual-review run."""
    runs = payload.get("runs") or []
    if not runs:
        raise ScriptError(
            "Visual review capture produced no runs to manifest.", EXIT_USAGE
        )

    manifest_paths: list[str] = []
    max_bytes = (
        max_artifact_bytes if max_artifact_bytes is not None else 1024 * 1024 * 1024
    )
    total_bytes = 0

    for index, run in enumerate(runs):
        if not isinstance(run, dict):
            raise ScriptError(
                f"Visual review run {index + 1} is not an object.",
                EXIT_USAGE,
            )
        route = str(run.get("route") or "/")
        surface = str(run.get("surface") or "surface")
        state = str(run.get("state") or "default")

        # Capture failures are validated before any directory is created, so a
        # run that cannot produce evidence never leaves a partial manifest tree
        # behind and never reports success with an empty manifest list.
        probe_outcomes = run.get("probeOutcomes") or []
        if not isinstance(probe_outcomes, list):
            raise ScriptError(
                f"Visual review run {index + 1} ({surface}/{state}) reported "
                "probe outcomes that are not a list.",
                EXIT_USAGE,
            )
        for outcome in probe_outcomes:
            if not isinstance(outcome, dict):
                raise ScriptError(
                    f"Visual review run {index + 1} ({surface}/{state}) reported "
                    "a probe outcome that is not an object.",
                    EXIT_USAGE,
                )
            if str(outcome.get("status")) == "capture-failure":
                raise ScriptError(
                    f"Visual review run {index + 1} ({surface}/{state}) failed to "
                    "capture its evidence.",
                    EXIT_USAGE,
                )

        label = "-".join([surface, state]).lower().replace(" ", "-")
        label = (
            "".join(ch if ch.isalnum() else "-" for ch in label).strip("-")
            or f"run-{index + 1}"
        )
        # The run index keeps the directory unique: sanitizing distinct surface
        # and state pairs can produce the same label, and colliding runs would
        # otherwise overwrite each other's manifest.
        manifest_dir = run_root / "runs" / f"{index + 1:03d}-{label}"
        manifest_dir.mkdir(parents=True, exist_ok=True)

        screenshot_path = run.get("screenshotPath")
        measurement_path = run.get("measurementPath")
        trace_path = run.get("tracePath")
        if not screenshot_path or not measurement_path or not trace_path:
            raise ScriptError(
                "Visual review capture payload is missing required artifact paths.",
                EXIT_USAGE,
            )

        server_artifact_paths = [screenshot_path, measurement_path, trace_path]
        for candidate_path in server_artifact_paths:
            if not isinstance(candidate_path, str):
                continue
            resolved = (
                (run_root / candidate_path).resolve(strict=False)
                if not Path(candidate_path).is_absolute()
                else Path(candidate_path).resolve(strict=False)
            )
            if resolved.exists():
                candidate_bytes = resolved.stat().st_size
                if total_bytes + candidate_bytes > max_bytes:
                    raise ScriptError(
                        "Visual review artifact bytes exceed the byte ceiling of "
                        f"{max_bytes} bytes.",
                        EXIT_USAGE,
                    )
                total_bytes += candidate_bytes

        relative_screenshot = _materialize_visual_review_artifact(
            screenshot_path,
            run_root=run_root,
            manifest_dir=manifest_dir,
        )
        relative_measurement = _materialize_visual_review_artifact(
            measurement_path,
            run_root=run_root,
            manifest_dir=manifest_dir,
        )
        relative_trace = _materialize_visual_review_artifact(
            trace_path,
            run_root=run_root,
            manifest_dir=manifest_dir,
        )

        manifest = build_visual_review_manifest(
            run_root=manifest_dir,
            run_id=f"{route}-{surface}-{state}-{index + 1}",
            route=route,
            surface=surface,
            state=state,
            viewport=run.get("viewport") or {"width": 1440, "height": 900},
            browser=run.get("browser") or {"name": "chrome", "version": "unknown"},
            platform={"os": os.name, "version": "local"},
            screenshot_path=relative_screenshot,
            trace_path=relative_trace,
            measurement_path=relative_measurement,
            deterministic_metrics=run.get("deterministicMetrics") or {},
            probe_outcomes=probe_outcomes,
            provenance={
                "environment": {
                    "cwd": str(run_root),
                    "pythonVersion": sys.version.split()[0],
                },
                "git": {
                    "available": False,
                    "commit": None,
                    "dirty": False,
                },
            },
        )
        validate_visual_review_manifest(
            manifest,
            run_root=manifest_dir,
            max_artifact_bytes=max_bytes,
        )
        manifest_path = write_json_atomic(manifest_dir / "manifest.json", manifest)
        manifest_paths.append(str(manifest_path))

    return manifest_paths


def run(
    config: dict[str, Any],
    probe_filter: str | None,
    base_url: str,
    trace: bool,
    surface_filter: str | None = None,
    state_filter: str | None = None,
) -> dict[str, Any]:
    """Execute the scoped runs and aggregate normalized probe results.

    An operational failure stops the run. The harness has just shown it cannot
    account for the state of the machine, so it does not keep driving it. The
    evidence collected up to that point is retained and the document is marked
    quarantined, because a run that did not finish is not a basis for a
    conformance claim even though its findings are real.
    """
    runs: list[dict[str, Any]] = []
    results: list[dict[str, Any]] = []
    operational_failure: dict[str, Any] | None = None
    for probe_id, surface_id, state in _iter_runs(
        config,
        probe_filter,
        surface_filter=surface_filter,
        state_filter=state_filter,
    ):
        payload = _run_probe(config, probe_id, surface_id, state, base_url, trace)
        emitting_probe = payload.get("probeId", probe_id)
        runs.append(
            {
                "probeId": emitting_probe,
                "surfaceId": surface_id,
                "state": state,
            }
        )
        for item in payload.get("results", []):
            # Stamp the emitting probe on every row. Probes may push rows
            # inline rather than exclusively through the shared result
            # builder, so this aggregation point is the only place that sees
            # them all. Consumers that join a row back to a declared
            # expectation need it because criterion coverage overlaps across
            # probes.
            results.append({**item, "probeId": emitting_probe})

        operational_failure = payload.get("operationalFailure")
        if operational_failure:
            if payload.get("cleanup"):
                operational_failure["cleanup"] = payload["cleanup"]
            break

    document = {
        "tool": "runtime_a11y",
        "runAt": datetime.now(timezone.utc).isoformat(),
        "baseUrl": base_url,
        "runs": runs,
        "results": results,
    }
    if operational_failure:
        document["quarantined"] = True
        document["operationalFailure"] = operational_failure
    return document


def _write_output(document: dict[str, Any], out_path: Path | None) -> None:
    payload = json.dumps(document, indent=2)
    if out_path is None:
        print(payload)
        return
    resolved_out_path = _resolve_repo_path(out_path, kind="--out")
    resolved_out_path.parent.mkdir(parents=True, exist_ok=True)
    resolved_out_path.write_text(payload + "\n", encoding="utf-8")


def _load_runtime_config(
    runtime_config_path: Path | None,
    allow_external: bool = False,
    require_target: bool = True,
) -> dict[str, Any] | None:
    if runtime_config_path is None:
        return None
    try:
        return load_validated_config(
            runtime_config_path,
            allow_external=allow_external,
            require_target=require_target,
        )
    except ScriptError:
        raise
    except (OSError, json.JSONDecodeError) as exc:
        raise ScriptError(
            f"Unable to read runtime config JSON from {runtime_config_path}: {exc}",
            EXIT_USAGE,
        ) from exc


def _normalize_case_id(case: dict[str, Any]) -> str:
    return str(case.get("id") or "")


def _safe_source_matrix_reference(matrix_path: Path) -> str:
    return str(matrix_path.name)


def _sanitize_runtime_config(runtime_config: dict[str, Any] | None) -> dict[str, Any]:
    if not isinstance(runtime_config, dict):
        return {}
    allowed_keys = {
        "baseUrl",
        "syntheticPhrases",
        "surfaces",
    }
    return {key: value for key, value in runtime_config.items() if key in allowed_keys}


def _assert_case_urls_allowed(
    runtime_config: dict[str, Any] | None,
    surface: dict[str, Any] | None,
    trigger: dict[str, Any] | None,
    allow_external: bool,
) -> None:
    if not runtime_config:
        return

    base_url = str(runtime_config.get("baseUrl") or "")
    candidate_urls: list[str] = []
    if surface and surface.get("route"):
        candidate_urls.append(urljoin(base_url, str(surface["route"])))
    if trigger and trigger.get("action") == "navigate" and trigger.get("value"):
        candidate_urls.append(urljoin(base_url, str(trigger["value"])))
    if trigger and trigger.get("action") == "visit":
        target = trigger.get("target")
        if isinstance(target, str):
            candidate_urls.append(urljoin(base_url, target))
        elif isinstance(target, dict) and target.get("value"):
            candidate_urls.append(urljoin(base_url, str(target["value"])))

    for candidate_url in candidate_urls:
        candidate_config = dict(runtime_config)
        candidate_config["baseUrl"] = candidate_url
        assert_target_allowed(candidate_config, allow_external=allow_external)


def _derive_at_plan_cases(
    matrix_path: Path,
    runtime_config_path: Path | None = None,
    allow_external: bool = False,
    require_target: bool = True,
) -> list[dict[str, Any]]:
    payload_bytes = matrix_path.read_bytes()
    payload_text = payload_bytes.decode("utf-8")
    payload = json.loads(payload_text)
    runtime_config = _load_runtime_config(
        runtime_config_path,
        allow_external=allow_external,
        require_target=require_target,
    )
    matrix = apply_criteria_catalog(Matrix.from_dict(payload))
    # A test plan derived from a quarantined matrix is still worth running for
    # triage, but the operator reading a case has to be told the source run did
    # not complete. Carrying the marker on each case means it survives selection,
    # execution, and result export rather than living only on a wrapper document.
    source_metadata = build_artifact_metadata(
        catalog=catalog_provenance(),
        quarantined=bool(payload.get("quarantined")),
        quarantine_reason=(payload.get("operationalFailure") or {}).get("reason"),
    ).to_dict()
    manual_cases = build_manual_test_cases(matrix, runtime_config)
    cases: list[dict[str, Any]] = []
    runtime_config_payload = _sanitize_runtime_config(runtime_config)
    if isinstance(runtime_config_payload.get("surfaces"), list):
        runtime_config_payload["surfaces"] = [
            {
                "id": entry.get("id"),
                "route": entry.get("route"),
                "selector": entry.get("selector"),
                "widgetPattern": entry.get("widgetPattern"),
                "states": [
                    {
                        "state": state_entry.get("state"),
                        "trigger": state_entry.get("trigger"),
                    }
                    for state_entry in (entry.get("states") or [])
                    if isinstance(state_entry, dict)
                ],
            }
            for entry in runtime_config_payload["surfaces"]
            if isinstance(entry, dict)
        ]
    for case in manual_cases:
        aria_at = case.get("ariaAt", {})
        case_id = _normalize_case_id(case)
        variant = None
        for candidate in aria_at.get("variants", []) or []:
            if candidate.get("automationEligible"):
                variant = candidate
                break
        surface_id = case.get("surfaceId")
        surface_entry = None
        if isinstance(runtime_config_payload.get("surfaces"), list):
            for entry in runtime_config_payload["surfaces"]:
                if entry.get("id") == surface_id:
                    surface_entry = entry
                    break
        state_entry = None
        if surface_entry and isinstance(surface_entry.get("states"), list):
            for entry in surface_entry.get("states", []):
                if entry.get("state") == case.get("state"):
                    state_entry = entry
                    break
        trigger = None
        if state_entry:
            trigger = state_entry.get("trigger")
        _assert_case_urls_allowed(
            runtime_config,
            surface_entry,
            trigger,
            allow_external,
        )
        base_url = runtime_config_payload.get("baseUrl") or ""
        cases.append(
            {
                "caseId": case_id,
                "criterionId": case.get("criterionId"),
                "surfaceId": case.get("surfaceId"),
                "state": case.get("state"),
                "mappingId": aria_at.get("mappingId"),
                "automationEligible": bool(aria_at.get("automationEligible")),
                "automationExclusionReason": aria_at.get("automationExclusionReason"),
                "commands": list(aria_at.get("commands", []) or []),
                "assertions": list(aria_at.get("assertions", []) or []),
                "variants": list(aria_at.get("variants", []) or []),
                "variant": variant,
                "sourceMatrixRef": _safe_source_matrix_reference(matrix_path),
                "sourceMatrixMetadata": {
                    "path": _safe_source_matrix_reference(matrix_path),
                    "sha256": hashlib.sha256(payload_bytes).hexdigest(),
                    **source_metadata,
                },
                "ariaAtReferences": [
                    aria_at.get("sourceUrl"),
                    aria_at.get("immutableUrl"),
                    aria_at.get("runbookReference"),
                ],
                "baseUrl": base_url,
                "surface": surface_entry,
                "trigger": trigger,
                "targetUrl": None,
                "runtimeConfig": {
                    key: value
                    for key, value in runtime_config_payload.items()
                    if key != "surfaces"
                },
            }
        )
    return cases


def _render_artifacts(
    matrix_path: Path,
    output_dir: Path,
    repo_slug: str,
    runtime_config_path: Path | None = None,
) -> dict[str, Any]:
    """Load a matrix document and render its canonical evidence bundle."""
    try:
        payload = json.loads(matrix_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ScriptError(
            f"Unable to read matrix JSON from {matrix_path}: {exc}", EXIT_USAGE
        ) from exc

    runtime_config = _load_runtime_config(runtime_config_path, require_target=False)

    matrix = Matrix.from_dict(payload)
    if not matrix.criteria or not matrix.surfaces:
        raise ScriptError(
            "Matrix JSON must contain non-empty criteria and surfaces arrays.",
            EXIT_USAGE,
        )
    matrix = apply_criteria_catalog(matrix)
    coverage = payload.get("coverage") or compute_coverage(matrix)
    # A matrix derived from a quarantined run stays usable for triage, but every
    # artifact it produces says so rather than presenting itself as a completed
    # assessment.
    metadata = build_artifact_metadata(
        repository=repo_slug,
        catalog=catalog_provenance(),
        quarantined=bool(payload.get("quarantined")),
        quarantine_reason=(payload.get("operationalFailure") or {}).get("reason"),
    )
    paths = render_artifact_bundle(
        matrix,
        coverage,
        output_dir,
        repo_slug,
        runtime_config=runtime_config,
        metadata=metadata,
    )
    return {
        "tool": "runtime_a11y",
        "command": "render-artifacts",
        "repository": repo_slug,
        "manifest": str(paths.manifest_json),
        "artifacts": paths.relative_manifest(output_dir),
    }


def _run_at_plan_case(
    case: dict[str, Any],
    driver_name: str,
    trace: bool,
) -> dict[str, Any]:
    command = ["node", str(_PACKAGE_DIR / "runner" / "at-plan-executor.mjs")]
    payload = json.dumps(case, ensure_ascii=False)
    try:
        completed = subprocess.run(
            command,
            input=payload,
            capture_output=True,
            text=True,
            check=True,
            env={
                **os.environ,
                "RUNTIME_A11Y_TRACE": "1" if trace else "0",
                "RUNTIME_A11Y_DRIVER_NAME": driver_name,
            },
            cwd=str(_PACKAGE_DIR),
        )
    except FileNotFoundError as exc:
        raise ScriptError(
            "Node is unavailable. Install Node.js and system Google Chrome, then "
            f"run 'npm ci' in {_PACKAGE_DIR}, to run AT plans.",
            EXIT_USAGE,
        ) from exc
    except subprocess.CalledProcessError as exc:
        stderr = (exc.stderr or "").strip() or "No AT execution output captured"
        raise ScriptError(
            f"AT plan case '{case.get('caseId')}' failed: {stderr}"
        ) from exc

    stdout = (completed.stdout or "").strip()
    if not stdout:
        raise ScriptError(
            f"AT plan case '{case.get('caseId')}' produced no JSON output",
            EXIT_USAGE,
        )
    try:
        result = json.loads(stdout)
    except json.JSONDecodeError as exc:
        raise ScriptError(
            f"AT plan case '{case.get('caseId')}' returned invalid JSON output",
            EXIT_USAGE,
        ) from exc

    return result


def create_parser() -> argparse.ArgumentParser:
    """Create and configure the argument parser."""
    parser = argparse.ArgumentParser(
        prog="runtime_a11y",
        description="Run project-parameterized accessibility runtime probes.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    def _add_common(sub: argparse.ArgumentParser) -> None:
        sub.add_argument(
            "--config",
            type=Path,
            required=True,
            help="Path to a11y-runtime.config.json",
        )
        sub.add_argument(
            "--out",
            type=Path,
            default=None,
            help="Path to write the aggregated results JSON (defaults to stdout)",
        )
        sub.add_argument(
            "--base-url",
            default=None,
            help="Override the config baseUrl",
        )
        sub.add_argument(
            "--trace",
            action="store_true",
            help="Capture Playwright traces and screenshots for each run",
        )
        sub.add_argument(
            "--allow-external",
            action="store_true",
            help="Confirm intentional probing of a non-loopback host",
        )
        sub.add_argument(
            "--surface",
            default=None,
            help="Limit execution to the given surface id",
        )
        sub.add_argument(
            "--state",
            default=None,
            help="Limit execution to the given surface state",
        )

    def _add_run_root(sub: argparse.ArgumentParser) -> None:
        sub.add_argument(
            "--run-root",
            default=None,
            help=(
                "Override the evidence run root for calibration and "
                "visual-review outputs"
            ),
        )

    run_all = subparsers.add_parser("run-all", help="Run every scoped probe")
    _add_common(run_all)

    probe = subparsers.add_parser("probe", help="Run a single probe by id")
    probe.add_argument("probe_id", help="Probe id, e.g. probe-axe")
    _add_common(probe)

    verify_intent = subparsers.add_parser(
        "verify-intent",
        help="Write a design-intent verification artifact from probe results",
    )
    verify_intent.add_argument(
        "--record",
        type=Path,
        required=True,
        help="Path to design-intent/<surface-id>.intent.yaml",
    )
    verify_intent.add_argument(
        "--results",
        type=Path,
        required=True,
        help="Path to a results document produced by run-all",
    )
    verify_intent.add_argument(
        "--config",
        type=Path,
        default=None,
        help="Optional runtime config used to validate surface and state bindings",
    )
    verify_intent.add_argument(
        "--out",
        type=Path,
        default=None,
        help=(
            "Path to write the verification artifact "
            "(defaults to the record's .verification directory)"
        ),
    )

    project_intent = subparsers.add_parser(
        "project-intent",
        help="Render a design intent record as Markdown for engineering review",
    )
    project_intent.add_argument(
        "--record",
        type=Path,
        required=True,
        help="Path to design-intent/<surface-id>.intent.yaml",
    )
    project_intent.add_argument(
        "--out",
        type=Path,
        default=None,
        help="Path to write the Markdown projection (defaults to stdout)",
    )

    render = subparsers.add_parser(
        "render-artifacts",
        help="Render coverage, EARL, and manual test-plan artifacts",
    )
    render.add_argument("--matrix", type=Path, required=True)
    render.add_argument("--output-dir", type=Path, required=True)
    render.add_argument("--repo-slug", required=True)
    render.add_argument("--runtime-config", type=Path, default=None)

    capture_visual_review = subparsers.add_parser(
        "capture-visual-review",
        help="Capture deterministic local visual-review evidence artifacts",
    )
    _add_common(capture_visual_review)
    _add_run_root(capture_visual_review)
    capture_visual_review.add_argument(
        "--visual-surface",
        action="append",
        default=[],
        help="Limit visual-review capture to the given surface id",
    )
    capture_visual_review.add_argument(
        "--visual-state",
        action="append",
        default=[],
        help="Limit visual-review capture to the given state id",
    )

    run_calibration = subparsers.add_parser(
        "run-calibration",
        help="Run the local calibration loop as a single uninterrupted session",
    )
    _add_common(run_calibration)
    _add_run_root(run_calibration)
    run_calibration.add_argument(
        "--prerequisite-only",
        action="store_true",
        help=(
            "Probe local NVDA and Chrome prerequisites without running "
            "calibration journeys"
        ),
    )

    run_at_plan = subparsers.add_parser(
        "run-at-plan",
        help="List or execute AT-plan cases derived from the persisted matrix",
    )
    run_at_plan.add_argument("--matrix", type=Path, required=True)
    run_at_plan.add_argument("--config", type=Path, default=None)
    run_at_plan.add_argument("--case-id", action="append", default=[])
    run_at_plan.add_argument("--driver", default="guidepup")
    run_at_plan.add_argument("--out", type=Path, default=None)
    run_at_plan.add_argument("--trace", action="store_true")
    run_at_plan.add_argument("--allow-external", action="store_true")
    run_at_plan.add_argument("--list", action="store_true")

    return parser


def _project_intent(args: argparse.Namespace) -> int:
    """Render a record as Markdown, to a file or stdout."""
    markdown, destination = projection.project(args.record, args.out)
    if destination is None:
        print(markdown, end="")
    else:
        print(f"Wrote {destination}")
    return EXIT_SUCCESS


def _warn_override_conflicts(
    record: dict[str, Any], assertions: list[dict[str, Any]]
) -> None:
    """Report each conclusive disagreement between a probe and its override.

    The gate fails closed on a conclusive disagreement. The artifact does not
    reproduce human-authored override fields, so diagnostics read the authored
    record to report the override outcome accurately.
    """
    override_outcomes = {
        (intent_item.get("id"), expectation.get("id")): (
            expectation.get("override") or {}
        ).get("outcome")
        for intent_item in record.get("intents", [])
        for expectation in intent_item.get("expectations", [])
    }
    for item in assertions:
        if not item.get("overrideConflict"):
            continue
        override_outcome = override_outcomes.get(
            (item["intentId"], item["expectationId"])
        )
        print(
            "Warning: design intent override conflict: "
            f"intent '{item['intentId']}' expectation '{item['expectationId']}'; "
            f"observed outcome '{item['outcome']}'; "
            f"override outcome '{override_outcome}'.",
            file=sys.stderr,
        )


def _verify_intent(args: argparse.Namespace) -> int:
    """Generate a verification artifact and report blocking intent drift."""
    raw_text = intent.read_record_text(args.record)
    config = load_validated_config(args.config) if args.config else None
    record = intent.parse_record(raw_text, args.record, config)
    destination, document = intent.generate(
        args.record, args.results, args.out, prepared=(raw_text, record)
    )
    print(f"Wrote {destination}")
    _warn_override_conflicts(record, document["assertions"])
    blocking = intent.evaluate_blocking(record, document["assertions"])
    if blocking == intent.BLOCKING_FAILED:
        print(
            "Error: a blocking design intent expectation failed",
            file=sys.stderr,
        )
        return EXIT_INTENT_DRIFT
    if blocking == intent.BLOCKING_UNCOVERED:
        print(
            "Error: a blocking design intent expectation was never evaluated",
            file=sys.stderr,
        )
        return EXIT_INTENT_UNCOVERED
    return EXIT_SUCCESS


def _cmd_run_at_plan(args: argparse.Namespace) -> int:
    """Derives AT-plan cases from a matrix and executes the eligible ones."""
    if not args.matrix.exists():
        raise ScriptError(f"Matrix file does not exist: {args.matrix}", EXIT_USAGE)
    try:
        cases = _derive_at_plan_cases(
            args.matrix,
            args.config,
            allow_external=args.allow_external,
            require_target=True,
        )
    except (ValueError, json.JSONDecodeError, OSError) as exc:
        raise ScriptError(
            f"Unable to derive AT-plan cases from {args.matrix}: {exc}",
            EXIT_USAGE,
        ) from exc
    if args.list:
        # The listing is what an operator reads before committing to a manual
        # run, so it repeats the source-run marker instead of only naming cases.
        source_metadata = cases[0]["sourceMatrixMetadata"] if cases else {}
        _write_output(
            {
                "quarantined": bool(source_metadata.get("quarantined")),
                "quarantineReason": source_metadata.get("quarantineReason"),
                "cases": [
                    {
                        "id": case["caseId"],
                        "automationEligible": case["automationEligible"],
                        "automationExclusionReason": case["automationExclusionReason"],
                    }
                    for case in cases
                ],
            },
            None,
        )
        return EXIT_SUCCESS
    force_execute = args.driver.lower() in {"fake", "synthetic"}
    if args.case_id:
        requested = set(args.case_id)
        selected = [case for case in cases if case["caseId"] in requested]
        if len(selected) != len(requested):
            raise ScriptError(
                "One or more requested case IDs were not found in the matrix.",
                EXIT_USAGE,
            )
    elif force_execute:
        selected = list(cases)
    else:
        selected = [case for case in cases if case["automationEligible"]]
    if not selected:
        raise ScriptError("No executable AT-plan cases were selected.", EXIT_USAGE)
    results = []
    for case in selected:
        if not case.get("automationEligible") and not force_execute:
            results.append(
                {
                    "caseId": case["caseId"],
                    "status": "unsupported",
                    "reason": case.get("automationExclusionReason") or "human-only",
                }
            )
            continue
        eligible_variants = [
            variant
            for variant in case.get("variants", [])
            if variant.get("automationEligible", False)
        ]
        if not eligible_variants:
            if not force_execute:
                results.append(
                    {
                        "caseId": case["caseId"],
                        "status": "unsupported",
                        "reason": "No automation-eligible variant was resolved.",
                    }
                )
                continue
            variant_case = dict(case)
            variant_case["variant"] = None
            variant_case["commands"] = list(case.get("commands", []))
            variant_case["assertions"] = list(case.get("assertions", []))
            variant_case["at"] = case.get("at")
            results.append(_run_at_plan_case(variant_case, args.driver, args.trace))
            continue
        for variant in eligible_variants:
            variant_case = dict(case)
            variant_case["variant"] = variant
            variant_case["commands"] = list(
                variant.get("commands") or case.get("commands", [])
            )
            variant_case["assertions"] = list(
                variant.get("assertions") or case.get("assertions", [])
            )
            variant_case["at"] = variant.get("at")
            results.append(_run_at_plan_case(variant_case, args.driver, args.trace))
    document = {
        "tool": "runtime_a11y",
        "command": "run-at-plan",
        "runAt": datetime.now(timezone.utc).isoformat(),
        "cases": results,
    }
    _write_output(document, args.out)
    return EXIT_SUCCESS


def _cmd_render_artifacts(args: argparse.Namespace) -> int:
    """Renders review artifacts from a matrix without executing probes."""
    document = _render_artifacts(
        args.matrix,
        args.output_dir,
        args.repo_slug,
        runtime_config_path=args.runtime_config,
    )
    _write_output(document, None)
    return EXIT_SUCCESS


def _cmd_capture_visual_review(args: argparse.Namespace) -> int:
    """Captures visual-review evidence for the configured surfaces and states."""
    config = load_validated_config(args.config, allow_external=args.allow_external)
    config = validate_visual_review_config(config)
    visual_review = config.get("visualReview") or {}
    if visual_review.get("enabled") is not True:
        raise ScriptError(
            "Visual review capture requires visualReview.enabled to be "
            "true in the runtime config.",
            EXIT_USAGE,
        )
    selected_plan = _select_visual_review_plan(
        config,
        surfaces=list(args.visual_surface or []),
        states=list(args.visual_state or []),
    )
    base_url = _resolve_guarded_base_url(
        config, args.base_url, allow_external=args.allow_external
    )
    # Check dependencies before any server work so an unprepared checkout does
    # not pay for a build and server startup before reporting the install step.
    _require_harness_dependencies("running visual review capture")
    run_root = (
        _resolve_repo_path(args.run_root, kind="--run-root")
        if args.run_root is not None
        else resolve_run_root(
            _REPO_ROOT,
            run_id=f"visual-review-{datetime.now(timezone.utc).strftime('%Y%m%d%H%M%S')}",
        )
    )
    server_process = None
    server_owned = False
    try:
        server_process, server_owned = _ensure_visual_review_server(
            base_url, config.get("serveMode", "auto")
        )
        payload = _run_visual_review_capture(
            config,
            base_url,
            Path(run_root),
            args.trace,
            surfaces=selected_plan["surfaces"],
            states=selected_plan["states"],
        )
        manifest_paths = _write_visual_review_manifests(
            payload,
            Path(run_root),
            max_artifact_bytes=visual_review.get("maxArtifactBytes"),
        )
    finally:
        if server_owned:
            _stop_visual_review_server(server_process)
    document = {
        "tool": "runtime_a11y",
        "command": "capture-visual-review",
        "runAt": datetime.now(timezone.utc).isoformat(),
        "baseUrl": base_url,
        "runRoot": _public_path(run_root),
        "manifestPaths": manifest_paths,
        "runs": payload.get("runs", []),
    }
    _write_output(document, args.out)
    return EXIT_SUCCESS


def _resolve_calibration_run_root(args: argparse.Namespace) -> Path:
    """Chooses the run root for a calibration session.

    An explicit --run-root wins. Otherwise an --out that already points inside
    the local runs tree keeps its own parent, so a caller directing output at an
    existing run does not scatter artifacts across two roots. Anything else gets
    a fresh timestamped root.
    """
    if args.run_root is not None:
        return _resolve_repo_path(args.run_root, kind="--run-root")

    if args.out is not None:
        output_candidate = Path(args.out).expanduser()
        if not output_candidate.is_absolute():
            output_candidate = (_REPO_ROOT / output_candidate).expanduser()
        resolved_output_candidate = output_candidate.resolve(strict=False)
        if _is_within(resolved_output_candidate, _local_runs_root()):
            return resolved_output_candidate.parent

    return resolve_run_root(
        _REPO_ROOT,
        run_id=f"calibration-{datetime.now(timezone.utc).strftime('%Y%m%d%H%M%S')}",
    )


def _normalize_calibration_aggregate(payload: dict[str, Any]) -> dict[str, Any]:
    """Returns a calibration aggregate with a status the caller can trust.

    A missing or unrecognized status is reported as unsuccessful rather than
    passed through, so an incomplete run cannot read as a clean one downstream.
    """
    aggregate = payload.get("aggregate")
    if not isinstance(aggregate, dict):
        return {
            "status": "unsuccessful",
            "reason": "Calibration completed without an aggregate status.",
        }

    aggregate_status = str(aggregate.get("status") or "").lower()
    if aggregate_status not in {"successful", "unsuccessful", "incomplete"}:
        return {
            "status": "unsuccessful",
            "reason": (
                aggregate.get("reason")
                or "Calibration completed without an aggregate status."
            ),
        }
    return aggregate


def _cmd_run_calibration(args: argparse.Namespace) -> int:
    """Runs a calibration session, or only its prerequisite probe."""
    config = load_validated_config(args.config, allow_external=args.allow_external)
    calibration = config.get("calibration") or {}
    journey_ids = [
        str(item.get("id"))
        for item in calibration.get("journeys", [])
        if str(item.get("id"))
    ]
    base_url = _resolve_guarded_base_url(
        config, args.base_url, allow_external=args.allow_external
    )
    run_root = _resolve_calibration_run_root(args)

    if args.out is not None:
        out_path = _resolve_repo_path(
            args.out,
            kind="--out",
            allowed_root=_resolve_output_allowed_root(run_root, args.out),
        )
    elif run_root is not None:
        out_path = Path(run_root) / "calibration-output.json"
    else:
        out_path = None

    config_for_execution = deepcopy(config)
    if args.base_url:
        config_for_execution["baseUrl"] = args.base_url

    if args.prerequisite_only:
        payload = _run_prerequisite_probe(config_for_execution, base_url, args.trace)
        aggregate = {
            "status": "successful",
            "reason": "Calibration prerequisites are ready.",
        }
        if isinstance(payload, dict) and payload.get("ok") is False:
            aggregate = {
                "status": "unsuccessful",
                "reason": (
                    payload.get("reason") or "Calibration prerequisites were not met."
                ),
            }
        elif isinstance(payload, dict) and payload.get("reason"):
            aggregate = {"status": "successful", "reason": payload.get("reason")}
        document = {
            "tool": "runtime_a11y",
            "command": "run-calibration",
            "runAt": datetime.now(timezone.utc).isoformat(),
            "baseUrl": base_url,
            "journeys": journey_ids,
            "visualStates": calibration.get("visualStates") or [],
            "runRoot": _public_path(run_root),
            "aggregate": aggregate,
            "checkpoints": [],
            "state": {"journeys": []},
            "prerequisiteOnly": True,
        }
        _write_output(document, out_path)
        return EXIT_SUCCESS

    server_process = None
    server_owned = False
    _emit_live_test_start_notice(run_root, len(journey_ids))
    try:
        if (config.get("visualReview") or {}).get("enabled") is True:
            server_process, server_owned = _ensure_visual_review_server(
                base_url, config.get("serveMode", "auto")
            )
        payload = _run_calibration_session(
            config_for_execution,
            base_url,
            str(run_root) if run_root is not None else None,
            args.trace,
        )
    finally:
        if server_owned:
            _stop_visual_review_server(server_process)
        _emit_live_test_finish_notice()

    document = {
        "tool": "runtime_a11y",
        "command": "run-calibration",
        "runAt": datetime.now(timezone.utc).isoformat(),
        "baseUrl": base_url,
        "journeys": payload.get("journeys", journey_ids),
        "visualStates": calibration.get("visualStates") or [],
        "runRoot": _public_path(
            payload.get("runRoot") or (run_root if run_root is not None else None)
        ),
        "aggregate": _normalize_calibration_aggregate(payload),
        "checkpoints": payload.get("checkpoints", []),
        "state": payload.get("state", {}),
    }
    _write_output(document, out_path)
    return EXIT_SUCCESS


def main(argv: list[str] | None = None) -> int:
    """Parses arguments and dispatches to the selected command."""
    parser = create_parser()
    args = parser.parse_args(argv)

    try:
        if args.command == "verify-intent":
            return _verify_intent(args)
        if args.command == "project-intent":
            return _project_intent(args)
        if args.command == "render-artifacts":
            return _cmd_render_artifacts(args)
        if args.command == "capture-visual-review":
            return _cmd_capture_visual_review(args)
        if args.command == "run-calibration":
            return _cmd_run_calibration(args)
        if args.command == "run-at-plan":
            return _cmd_run_at_plan(args)
        config = load_validated_config(args.config, allow_external=args.allow_external)
        base_url = _resolve_guarded_base_url(
            config, args.base_url, allow_external=args.allow_external
        )
        probe_filter = getattr(args, "probe_id", None)
        document = run(
            config,
            probe_filter,
            base_url,
            args.trace,
            surface_filter=getattr(args, "surface", None),
            state_filter=getattr(args, "state", None),
        )
    except ScriptError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return exc.exit_code

    _write_output(document, args.out)
    if document.get("quarantined"):
        # Evidence is persisted first so a failed run is still diagnosable, then
        # the operational failure is reported. An unverified screen-reader stop
        # means the operator should confirm the state of their machine, and
        # their own assistive technology, before running anything further.
        failure = document.get("operationalFailure") or {}
        print(
            "Error: run stopped after an operational failure "
            f"({failure.get('reason', 'reason not recorded')}). "
            "Evidence collected before the failure was written and is marked "
            "quarantined. Confirm the machine state before starting another run.",
            file=sys.stderr,
        )
        return EXIT_FAILURE
    return EXIT_SUCCESS


if __name__ == "__main__":
    sys.exit(main())
