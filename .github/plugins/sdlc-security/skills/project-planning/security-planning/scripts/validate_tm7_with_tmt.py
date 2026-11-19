#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Validate TM7 models through the native Microsoft Threat Modeling Tool UI."""

from __future__ import annotations

import argparse
import contextlib
import copy
import csv
import ctypes
import hashlib
import inspect
import json
import logging
import os
import platform
import re
import shutil
import subprocess
import sys
import time
from contextlib import contextmanager
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path, PurePath, PureWindowsPath
from typing import Any, Callable, Iterable, Iterator
from urllib.parse import urlsplit, urlunsplit
from xml.etree import ElementTree as ET

import generate_tm7
import tm7_threat_contract
import tm7_visual_feedback

logger = logging.getLogger(__name__)

EXIT_SUCCESS = 0
EXIT_VALIDATION_FAILURE = 1
EXIT_ERROR = 2
EXIT_MISSING_TMT = 3
EXIT_VERSION_MISMATCH = 4
EXIT_AUTOMATION_TIMEOUT = 5
EXIT_UNEXPECTED_MODAL = 6
EXIT_MISSING_FEEDBACK_EVIDENCE = 7
EXIT_FEEDBACK_NON_CONVERGENCE = 8
# SIGINT convention: 128 + signal number.
EXIT_INTERRUPTED = 130

DEFAULT_PINNED_VERSION = "7.3.51110.1"
# Executable trust is anchored to the signing publisher, not to install
# location or file timestamp. Only a validly signed binary naming this common
# name is accepted as the native Threat Modeling Tool.
ACCEPTED_PUBLISHER_CN = "CN=Microsoft Corporation"
DEFAULT_TIMEOUT_SECONDS = 60.0
DEFAULT_MAX_ITERATIONS = 1
EVIDENCE_SCHEMA_VERSION = 1
# Stop reasons where the run captured trustworthy evidence and simply found no
# automated layout improvement. Only these publish a rules-empty overlay seed
# for a reviewer to build on. A correctness stop such as semantic-regression,
# an incomplete capture, or an environment failure must not, because the model
# or the evidence behind it is itself in question and inviting layout rules
# against it would misdirect the review.
OVERLAY_SEED_STOP_REASONS = frozenset(
    {"repeated-defect-no-improvement", "max-iterations"}
)
# Every status the feedback loop assigns to a run is a member of this set, and
# each member is a distinct operator action. An outcome outside the set is
# reported as harness-error rather than collapsed into unexpected-modal, which
# would send an operator looking for a dialog that never appeared.
FEEDBACK_STOP_REASONS = frozenset(
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
MODEL_NS = tm7_threat_contract.MODEL_NS
KNOWLEDGE_NS = tm7_threat_contract.KNOWLEDGE_NS
LICENSE_MODAL_TITLE = "MICROSOFT LICENSE TERMS WINDOW"
TEMPLATE_CONVERSION_MODAL_TITLE = "Threat Model Conversion Confirmation"
SENSITIVE_KEY = re.compile(
    r"authorization|client[_-]?secret|password|passwd|token|api[_-]?key|sas|"
    r"secret|credential|account[_-]?key|shared[_-]?access|connection[_-]?string|"
    r"private[_-]?key|signature|sig",
    re.IGNORECASE,
)
# Sensitive names carry their value in several inline shapes. The value run stops
# at a separator so a `key=value; next=...` pair does not swallow the rest of the
# string. The key and the value are each optionally quoted so the JSON shape
# `"password": "hunter2"` is covered as well as the bare and header forms.
SENSITIVE_VALUE = re.compile(
    r"(?i)(['\"]?\b(?:"
    r"authorization|client[_-]?secret|password|passwd|token|api[_-]?key|"
    r"secret|credential|account[_-]?key|shared[_-]?access[_-]?key|"
    r"private[_-]?key|sig|signature"
    r")\b['\"]?)(\s*[:=]\s*)['\"]?(?:bearer\s+)?[^\s;,&\"']+['\"]?",
    re.IGNORECASE,
)
# A bare bearer or basic credential can appear without a preceding key name.
SENSITIVE_SCHEME_VALUE = re.compile(
    r"(?i)\b(bearer|basic)\s+[A-Za-z0-9._~+/=-]{8,}",
)
# Query strings routinely carry credentials, so any query is dropped wholesale
# rather than matched name by name.
SENSITIVE_QUERY_KEY = SENSITIVE_KEY
# Containers whose child keys are model-supplied identifiers rather than field
# names this code chose. A key-name credential match inside one of these says
# nothing about the value, so the match is not applied to their child keys.
# Adding a container here is only safe when its values are structural, because
# any string value is still text-redacted wherever it appears.
IDENTIFIER_KEYED_CONTAINERS = frozenset(
    {
        "boundary_label_rects",
        "boundary_rects",
        "branch_groups",
        "connector_label_rects",
        "connector_routes",
        "layout_roles",
        "node_ranks",
        "node_rects",
        "zone_content_rects",
        "zone_membership",
        "zone_parent_map",
    }
)
# TMT sets a surface pane's automation id to that surface's own GUID, so no
# constant identifies "the Diagram pane". The canvas child inside every
# surface pane does carry a stable id, and that is what anchors discovery.
CANVAS_VIEWPORT_AUTOMATION_ID = "Viewport"
# TMT wraps a surface tab caption as "DocumentView, Title <caption>". The
# wrapper is the reliable marker; the caption itself is author-controlled.
SURFACE_TAB_NAME_MARKER = "documentview"
# Tabs owned by TMT's own panels are excluded by automation id rather than by
# caption, so an authored surface titled "Notes" is still treated as a surface.
NON_SURFACE_TAB_AUTOMATION_IDS = frozenset({"TAB_Messages", "TAB_Notes"})

# UIA treats -1 as "leave this axis alone" in SetScrollPercent.
UIA_SCROLL_NO_AMOUNT = -1.0
# TMT clips its tab strip and omits clipped tabs from the accessibility tree,
# and the strip exposes no scroll pattern, so tabs alone cannot reach every
# surface. This menu is the standard MDI document switcher and lists every
# open document regardless of tab visibility.
DOCUMENT_MENU_AUTOMATION_ID = "WindowMenuItem"


@dataclass(slots=True)
class SurfaceDescriptor:
    """Expected TM7 drawing surface identity for native capture."""

    surface_id: str
    surface_guid: str
    surface_name: str
    tab_index: int


@dataclass(slots=True)
class SurfaceTab:
    """Observed UIA tab descriptor for a drawing surface."""

    control: Any
    name: str
    automation_id: str = ""
    control_type: str = ""
    tab_index: int = 0


@dataclass(slots=True)
class TmtDiscovery:
    """Discovered TMT executable metadata."""

    path: Path | None
    version: str | None = None
    source: str | None = None


@dataclass(slots=True)
class TmtVersionPolicy:
    """Version acceptance contract for the harness."""

    pinned_version: str
    observed_version: str | None
    diagnostic_override: bool = False


@dataclass(slots=True)
class VersionPolicyOutcome:
    """Result of applying the version policy."""

    allowed: bool
    exit_code: int
    reason: str


@dataclass(slots=True)
class HarnessResult:
    """Outcome for a harness run."""

    exit_code: int
    status: str
    message: str
    evidence_dir: Path
    workspace_dir: Path | None = None
    manifest_path: Path | None = None


@dataclass(slots=True)
class FeedbackLoopResult:
    """Outcome for a bounded feedback loop run."""

    exit_code: int
    status: str
    message: str
    evidence_dir: Path
    overlay_output: Path | None = None
    workspace_dir: Path | None = None
    manifest_path: Path | None = None


class HarnessFailure(RuntimeError):
    """Native harness failure carrying a stable exit code."""

    def __init__(self, message: str, exit_code: int) -> None:
        super().__init__(message)
        self.exit_code = exit_code


@dataclass(slots=True)
class EvidenceBundle:
    """Write redacted, machine-readable and human-auditable run evidence."""

    evidence_dir: Path
    action_log_path: Path = field(init=False)
    manifest_path: Path = field(init=False)
    status_path: Path = field(init=False)
    last_action: str = field(default="not-started", init=False)

    def __post_init__(self) -> None:
        self.evidence_dir.mkdir(parents=True, exist_ok=True)
        self.action_log_path = self.evidence_dir / "action.log"
        self.manifest_path = self.evidence_dir / "manifest.json"
        self.status_path = self.evidence_dir / "status.json"
        for relative in ("screenshots", "uia", "exports", "summaries", "logs"):
            (self.evidence_dir / relative).mkdir(parents=True, exist_ok=True)

    def _redact_text(self, value: str) -> str:
        """Redact credential shapes that reach any persisted evidence sink."""
        value = SENSITIVE_VALUE.sub(r"\1\2[REDACTED]", value)
        value = SENSITIVE_SCHEME_VALUE.sub(r"\1 [REDACTED]", value)
        try:
            parsed = urlsplit(value)
        except ValueError:
            return value
        # A query string is dropped whenever it carries a sensitive parameter,
        # with or without a network location, so a relative URL reference is
        # covered as well.
        if parsed.query and SENSITIVE_QUERY_KEY.search(parsed.query):
            return urlunsplit((parsed.scheme, parsed.netloc, parsed.path, "", ""))
        if parsed.scheme and parsed.netloc and parsed.query:
            return urlunsplit((parsed.scheme, parsed.netloc, parsed.path, "", ""))
        return value

    def _redact_value(
        self,
        value: Any,
        key: str = "",
        *,
        key_is_identifier: bool = False,
    ) -> Any:
        if not key_is_identifier and SENSITIVE_KEY.search(key):
            return "[REDACTED]"
        if isinstance(value, dict):
            # Inside a geometry container the child keys are data identifiers
            # supplied by the model, not field names chosen by this code, so a
            # key-name match there says nothing about the value. Treating them
            # as field names destroyed real geometry: a node named
            # comp-tokencache matched "token" and had its whole rectangle
            # replaced, removing coordinates the agent review protocol
            # requires. Credential redaction is unaffected, because the values
            # under these keys are numbers, and any string reached anywhere is
            # still text-redacted.
            children_are_identifiers = key in IDENTIFIER_KEYED_CONTAINERS
            return {
                str(child_key): self._redact_value(
                    child_value,
                    str(child_key),
                    key_is_identifier=children_are_identifiers,
                )
                for child_key, child_value in value.items()
            }
        if isinstance(value, (list, tuple)):
            return [self._redact_value(item) for item in value]
        if isinstance(value, str):
            return self._redact_text(value)
        return value

    def _write_json(self, path: Path, values: dict[str, Any]) -> dict[str, Any]:
        redacted = self._redact_value(values)
        path.write_text(
            json.dumps(redacted, indent=2, sort_keys=True),
            encoding="utf-8",
        )
        return redacted

    def write_manifest(self, values: dict[str, Any]) -> dict[str, Any]:
        """Write the redacted run manifest."""
        return self._write_json(self.manifest_path, values)

    def write_status(self, values: dict[str, Any]) -> dict[str, Any]:
        """Write the final redacted status record."""
        return self._write_json(self.status_path, values)

    def write_action_log(self, message: str) -> None:
        """Append one redacted action event."""
        safe_message = self._redact_text(message)
        line = f"{datetime.now(timezone.utc).isoformat()} {safe_message}\n"
        with self.action_log_path.open("a", encoding="utf-8") as handle:
            handle.write(line)

    @contextmanager
    def action(self, name: str) -> Iterator[None]:
        """Record bounded action timing and the last successful operation."""
        started = time.monotonic()
        self.write_action_log(f"START {name}")
        _emit_operator_notice(f"Action START {name}")
        try:
            yield
        except Exception:
            duration = time.monotonic() - started
            self.write_action_log(f"FAIL {name} duration_seconds={duration:.3f}")
            _emit_operator_notice(f"Action FAIL {name} duration_seconds={duration:.3f}")
            raise
        duration = time.monotonic() - started
        self.last_action = name
        self.write_action_log(f"PASS {name} duration_seconds={duration:.3f}")
        _emit_operator_notice(f"Action PASS {name} duration_seconds={duration:.3f}")

    def path(self, relative: str) -> Path:
        """Resolve a confined evidence path and create its parent.

        The relative reference is confined to the evidence directory before any
        directory is created. An absolute path or a traversal segment would
        otherwise let a caller-influenced name write outside the bundle, and the
        parent mkdir would materialize that location on disk.

        Args:
            relative: Path relative to the evidence root.

        Returns:
            Resolved path inside the evidence directory.

        Raises:
            HarnessFailure: If the reference escapes the evidence directory.
        """
        output = self._confine(relative)
        output.parent.mkdir(parents=True, exist_ok=True)
        return output

    def _confine(self, relative: str) -> Path:
        """Resolve a relative reference strictly inside the evidence root."""
        candidate = PurePath(relative)
        if candidate.is_absolute() or PureWindowsPath(relative).is_absolute():
            raise HarnessFailure(
                f"Evidence path must be relative to the evidence directory: {relative}",
                EXIT_ERROR,
            )
        root = self.evidence_dir.resolve()
        resolved = (root / relative).resolve()
        if resolved != root and root not in resolved.parents:
            raise HarnessFailure(
                f"Evidence path escapes the evidence directory: {relative}",
                EXIT_ERROR,
            )
        return resolved

    def write_json(self, relative: str, values: Any) -> Path:
        """Write a redacted JSON document to a confined evidence path.

        Args:
            relative: Path relative to the evidence root.
            values: Document to redact and serialize.

        Returns:
            The written path.
        """
        path = self.path(relative)
        path.write_text(
            json.dumps(self._redact_value(values), indent=2, sort_keys=True),
            encoding="utf-8",
        )
        return path

    def redact(self, values: Any) -> Any:
        """Redact a document destined for a caller-declared output path.

        Confinement does not apply to a path the operator named on the command
        line, but redaction does: the document is built from the same run data
        as the confined sinks.

        Args:
            values: Document to redact.

        Returns:
            The redacted document.
        """
        return self._redact_value(values)

    def write_uia_tree(self, tree_text: str, filename: str) -> Path:
        """Write a redacted UI Automation tree snapshot."""
        path = self.path(f"uia/{filename}")
        path.write_text(self._redact_text(tree_text), encoding="utf-8")
        return path

    def write_csv_export(self, rows: Iterable[dict[str, Any]], path: str) -> Path:
        """Write a normalized threat CSV export.

        Rows are redacted like every other persisted sink. This writer was the
        only evidence path that persisted its payload verbatim, so a credential
        carried in exported threat text reached disk unredacted.
        """
        materialized = [self._redact_value(row) for row in rows]
        output_path = self.path(path)
        with output_path.open("w", encoding="utf-8", newline="") as handle:
            if materialized:
                writer = csv.DictWriter(
                    handle,
                    fieldnames=list(materialized[0].keys()),
                )
                writer.writeheader()
                writer.writerows(materialized)
        return output_path

    def write_summary(self, payload: dict[str, Any], filename: str) -> Path:
        """Write a semantic XML summary as JSON for deterministic comparison."""
        path = self.path(f"summaries/{filename}")
        self._write_json(path, payload)
        return path

    def write_surface_summary(self, payload: dict[str, Any], filename: str) -> Path:
        """Write a redacted per-surface evidence payload."""
        path = self.path(f"summaries/{filename}")
        self._write_json(path, payload)
        return path

    def cleanup_workspace(self, workspace_dir: Path | None) -> None:
        """Remove a harness-owned workspace, surfacing any deletion failure.

        Deletion is refused unless the directory carries the ownership marker
        this harness wrote into a directory it created itself.
        """
        _remove_owned_workspace(workspace_dir)


WORKSPACE_OWNER_MARKER = ".tm7-harness-owned"
WORKSPACE_CHILD_NAME = "tm7-harness-workspace"


def mark_workspace_owned(workspace_dir: Path) -> Path:
    """Record the ownership marker inside a harness-created workspace.

    Args:
        workspace_dir: Directory this harness created for its own working copies.

    Returns:
        Path to the ownership marker file.
    """
    workspace_dir.mkdir(parents=True, exist_ok=True)
    marker = workspace_dir / WORKSPACE_OWNER_MARKER
    marker.write_text(
        "Created by validate_tm7_with_tmt. Safe to delete with the workspace.\n",
        encoding="utf-8",
    )
    return marker


def prepare_owned_workspace(workspace_root: Path | None, evidence_dir: Path) -> Path:
    """Create a fresh harness-owned workspace beneath a caller-supplied parent.

    A caller-supplied root is treated as a parent directory only. The harness
    creates, marks, and later deletes a child directory it made itself, so no
    pre-existing caller directory can acquire the deletion marker.

    Args:
        workspace_root: Optional parent directory supplied by the operator.
        evidence_dir: Resolved evidence root used when no parent is supplied.

    Returns:
        Path to the newly created, harness-owned workspace directory.

    Raises:
        HarnessFailure: If the workspace cannot be created.
    """
    parent = (
        Path(workspace_root).resolve()
        if workspace_root is not None
        else evidence_dir / "workspace"
    )
    workspace = parent / WORKSPACE_CHILD_NAME
    if workspace.exists():
        _remove_owned_workspace(workspace)
    try:
        parent.mkdir(parents=True, exist_ok=True)
        workspace.mkdir(parents=False, exist_ok=False)
    except OSError as exc:
        raise HarnessFailure(
            f"Unable to create harness workspace {workspace}: {exc}",
            EXIT_ERROR,
        ) from exc
    mark_workspace_owned(workspace)
    return workspace


def _remove_owned_workspace(workspace_dir: Path | None) -> None:
    """Delete a workspace only when this harness marked it as its own.

    Traversal never descends into a symlink or Windows directory junction, so a
    reparse point placed inside the workspace cannot expose its target to
    deletion regardless of interpreter version.

    Args:
        workspace_dir: Candidate workspace directory, or None.
    """
    if workspace_dir is None or not workspace_dir.exists():
        return
    if not (workspace_dir / WORKSPACE_OWNER_MARKER).is_file():
        _emit_operator_notice(
            f"Refusing to delete unmarked workspace {workspace_dir}; "
            "only harness-created workspaces are removed automatically"
        )
        return
    errors: list[str] = []
    _remove_tree_without_following_links(workspace_dir, errors)
    if errors:
        # Cleanup failure leaves working copies of the model on disk, so it is
        # reported rather than silently swallowed.
        _emit_operator_notice(
            f"Workspace cleanup did not complete for {workspace_dir}: "
            + "; ".join(errors[:5])
        )


def _remove_tree_without_following_links(target: Path, errors: list[str]) -> None:
    """Recursively delete a directory without descending through reparse points.

    Args:
        target: Directory to delete.
        errors: Accumulator for per-path failure messages.
    """
    try:
        entries = list(os.scandir(target))
    except OSError as exc:
        errors.append(f"{target}: {exc}")
        return
    for entry in entries:
        entry_path = Path(entry.path)
        try:
            if entry.is_dir(follow_symlinks=False) and not entry.is_symlink():
                _remove_tree_without_following_links(entry_path, errors)
            elif entry.is_dir(follow_symlinks=False):
                # A directory symlink or junction is unlinked, never traversed.
                os.rmdir(entry_path)
            else:
                os.unlink(entry_path)
        except OSError as exc:
            errors.append(f"{entry_path}: {exc}")
    try:
        os.rmdir(target)
    except OSError as exc:
        errors.append(f"{target}: {exc}")


def configure_logging(verbose: bool = False) -> None:
    """Configure concise harness logging."""
    logging.basicConfig(
        level=logging.DEBUG if verbose else logging.INFO,
        format="%(levelname)s: %(message)s",
    )


def _emit_operator_notice(message: str, *, flush: bool = True) -> None:
    """Emit an operator-facing notice that is visible and flushed."""
    logger.info(message)
    if not flush:
        return
    for handler in logging.getLogger().handlers:
        handler.flush()
    try:
        sys.stderr.flush()
    except Exception:  # pragma: no cover - best-effort flush
        pass
    try:
        sys.stdout.flush()
    except Exception:  # pragma: no cover - best-effort flush
        pass


def _read_windows_file_version(path: Path) -> str | None:
    if platform.system() != "Windows":
        return None

    class FixedFileInfo(ctypes.Structure):
        _fields_ = [
            ("dwSignature", ctypes.c_uint32),
            ("dwStrucVersion", ctypes.c_uint32),
            ("dwFileVersionMS", ctypes.c_uint32),
            ("dwFileVersionLS", ctypes.c_uint32),
            ("dwProductVersionMS", ctypes.c_uint32),
            ("dwProductVersionLS", ctypes.c_uint32),
            ("dwFileFlagsMask", ctypes.c_uint32),
            ("dwFileFlags", ctypes.c_uint32),
            ("dwFileOS", ctypes.c_uint32),
            ("dwFileType", ctypes.c_uint32),
            ("dwFileSubtype", ctypes.c_uint32),
            ("dwFileDateMS", ctypes.c_uint32),
            ("dwFileDateLS", ctypes.c_uint32),
        ]

    version = ctypes.windll.version
    size = version.GetFileVersionInfoSizeW(str(path), None)
    if not size:
        return None
    buffer = ctypes.create_string_buffer(size)
    if not version.GetFileVersionInfoW(str(path), 0, size, buffer):
        return None
    pointer = ctypes.c_void_p()
    length = ctypes.c_uint()
    if not version.VerQueryValueW(
        buffer,
        "\\",
        ctypes.byref(pointer),
        ctypes.byref(length),
    ):
        return None
    info = ctypes.cast(pointer, ctypes.POINTER(FixedFileInfo)).contents
    parts = (
        info.dwFileVersionMS >> 16,
        info.dwFileVersionMS & 0xFFFF,
        info.dwFileVersionLS >> 16,
        info.dwFileVersionLS & 0xFFFF,
    )
    return ".".join(str(part) for part in parts)


def _powershell_hosts() -> list[str]:
    """Return absolute PowerShell host paths, never bare command names.

    CreateProcess resolves a bare application name against the calling process
    directory and the current working directory before System32, so a host
    planted beside a repository checkout could become the trust oracle.

    Returns:
        Absolute paths to available PowerShell hosts, in preference order.
    """
    hosts: list[str] = []
    resolved_pwsh = shutil.which("pwsh")
    if resolved_pwsh:
        candidate = Path(resolved_pwsh)
        if candidate.is_absolute() and candidate.is_file():
            hosts.append(str(candidate))
    system_root = os.environ.get("SystemRoot") or r"C:\Windows"
    windows_powershell = (
        Path(system_root) / "System32" / "WindowsPowerShell" / "v1.0" / "powershell.exe"
    )
    if windows_powershell.is_file():
        hosts.append(str(windows_powershell))
    return hosts


def _minimal_child_environment(candidate_path: Path) -> dict[str, str]:
    """Return the smallest environment the Authenticode probe needs.

    Developer environments routinely carry credentials such as `GITHUB_TOKEN`
    and `AZURE_*`, so only the variables the host itself requires are forwarded.

    Args:
        candidate_path: Executable whose signature is being inspected.

    Returns:
        Environment mapping for the child process.
    """
    passthrough = (
        "SystemRoot",
        "SystemDrive",
        "windir",
        "PATHEXT",
        "NUMBER_OF_PROCESSORS",
        "PROCESSOR_ARCHITECTURE",
        "TEMP",
        "TMP",
    )
    child_env = {name: os.environ[name] for name in passthrough if os.environ.get(name)}
    child_env["TMT_CANDIDATE_PATH"] = str(candidate_path)
    return child_env


def _authenticode_subject(path: Path) -> tuple[str, str] | None:
    """Return the Authenticode (status, subject) for a file, or None.

    Python has no built-in Authenticode check, so verification is delegated to
    the platform. Both PowerShell hosts are attempted because
    `Microsoft.PowerShell.Security` fails to load under Windows PowerShell in
    some constrained environments while PowerShell 7 succeeds. None means the
    signature could not be established, which callers treat as untrusted rather
    than as a pass.

    Args:
        path: Executable to inspect.

    Returns:
        Tuple of signature status and certificate subject, or None.
    """
    if platform.system() != "Windows":
        return None
    script = (
        "$s = Get-AuthenticodeSignature -LiteralPath $env:TMT_CANDIDATE_PATH; "
        "Write-Output $s.Status; "
        "Write-Output $s.SignerCertificate.Subject"
    )
    child_env = _minimal_child_environment(path)
    for host in _powershell_hosts():
        try:
            completed = subprocess.run(  # noqa: S603 - absolute argv, no shell
                [
                    host,
                    "-NoProfile",
                    "-NonInteractive",
                    "-Command",
                    script,
                ],
                capture_output=True,
                text=True,
                timeout=60,
                check=False,
                env=child_env,
            )
        except (OSError, subprocess.SubprocessError):
            continue
        lines = [line.strip() for line in completed.stdout.splitlines() if line.strip()]
        if completed.returncode == 0 and len(lines) >= 2:
            return (lines[0], lines[1])
    return None


def _subject_common_names(subject: str) -> set[str]:
    """Return the lowercased CN relative distinguished names from a subject.

    A substring test over the whole distinguished name accepts any subject that
    merely contains the publisher string in another position, such as
    `CN=Contoso, O=Microsoft Corporation Partner`.

    Args:
        subject: Certificate subject distinguished name.

    Returns:
        Set of lowercased CN component values.
    """
    names: set[str] = set()
    for component in subject.split(","):
        key, separator, value = component.partition("=")
        if separator and key.strip().lower() == "cn":
            names.add(value.strip().lower())
    return names


def is_trusted_tmt_executable(path: Path) -> bool:
    """Return True only for a validly signed executable from the pinned publisher.

    Newest modification time is not a trust signal. A decoy dropped into an
    otherwise allowed root would win on mtime alone, so acceptance requires a
    valid Authenticode signature whose parsed CN component exactly matches the
    accepted publisher.

    Args:
        path: Executable to evaluate.

    Returns:
        True when the executable is validly signed by the accepted publisher.
    """
    signature = _authenticode_subject(path)
    if signature is None:
        return False
    status, subject = signature
    if status != "Valid":
        return False
    expected = ACCEPTED_PUBLISHER_CN.split("=", 1)[1].strip().lower()
    return expected in _subject_common_names(subject)


def discover_tmt_application() -> TmtDiscovery:
    """Discover TMT across ClickOnce and conventional installation roots.

    Roots are absolute and derived from expanded environment locations. An empty
    or missing variable contributes no root, so a relative `./Apps/2.0`
    directory beside the working directory cannot supply candidates. Selection
    is deterministic over trusted, pinned-version candidates and never falls
    back to newest modification time.
    """
    if platform.system() != "Windows":
        return TmtDiscovery(path=None, source="non-windows")
    roots: list[Path] = []
    for raw_root, suffix in (
        (os.environ.get("LOCALAPPDATA", ""), ("Apps", "2.0")),
        (os.environ.get("ProgramFiles", ""), ("Microsoft Threat Modeling Tool",)),
        (os.environ.get("ProgramFiles(x86)", ""), ("Microsoft Threat Modeling Tool",)),
    ):
        if not raw_root:
            continue
        base = Path(raw_root)
        if not base.is_absolute():
            continue
        roots.append(base.joinpath(*suffix))
    names = {"ThreatModeling.exe", "ThreatModelingTool.exe", "TMT7.exe"}
    candidates: list[Path] = []
    for root in roots:
        if not root.is_dir():
            continue
        candidates.extend(path for path in root.rglob("*.exe") if path.name in names)
    if not candidates:
        return TmtDiscovery(path=None, source="not-found")
    # Trust before selection. An untrusted decoy must never be selected and
    # then rejected downstream, because selection order would still determine
    # which executable the operator is told about.
    trusted = [
        candidate
        for candidate in sorted(set(candidates), key=lambda item: str(item).lower())
        if is_trusted_tmt_executable(candidate)
    ]
    if not trusted:
        return TmtDiscovery(path=None, source="untrusted")
    # Among equally trusted candidates prefer the pinned version, then fall
    # back to the lexicographically first path. Both are stable across runs;
    # newest modification time is not.
    pinned = [
        candidate
        for candidate in trusted
        if _read_windows_file_version(candidate) == DEFAULT_PINNED_VERSION
    ]
    selected = (pinned or trusted)[0]
    return TmtDiscovery(
        path=selected.resolve(),
        version=_read_windows_file_version(selected),
        source="clickonce" if "Apps" in selected.parts else "installed",
    )


def evaluate_version_policy(policy: TmtVersionPolicy) -> VersionPolicyOutcome:
    """Require the exact compatibility version unless diagnostic override is set."""
    if policy.diagnostic_override:
        return VersionPolicyOutcome(True, EXIT_SUCCESS, "diagnostic override enabled")
    if policy.observed_version == policy.pinned_version:
        return VersionPolicyOutcome(True, EXIT_SUCCESS, "observed version matches pin")
    observed = policy.observed_version or "unavailable"
    return VersionPolicyOutcome(
        False,
        EXIT_VERSION_MISMATCH,
        f"observed version {observed} does not match {policy.pinned_version}",
    )


def sha256_file(path: Path) -> str:
    """Return a file SHA-256 digest."""
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _parse_xml(path: Path) -> ET.Element:
    """Parse a TM7 file under the single shared fail-closed XML policy.

    Args:
        path: TM7 file to parse.

    Returns:
        Parsed root element.

    Raises:
        HarnessFailure: If the file cannot be read or is unsafe to parse.
    """
    try:
        data = tm7_threat_contract.read_bounded_bytes(
            path, tm7_threat_contract.MAX_MODEL_BYTES
        )
    except tm7_threat_contract.InputTooLargeError as exc:
        raise HarnessFailure(f"TM7 input is too large: {exc}", EXIT_ERROR) from exc
    except OSError as exc:
        raise HarnessFailure(f"Unable to read TM7 input: {exc}", EXIT_ERROR) from exc
    try:
        return tm7_threat_contract.parse_hardened_xml_bytes(data)
    except tm7_threat_contract.UnsafeXmlError as exc:
        raise HarnessFailure(f"Unable to parse TM7 input: {exc}", EXIT_ERROR) from exc


def _text(parent: ET.Element, name: str) -> str:
    node = parent.find(f"{{*}}{name}")
    return "" if node is None or node.text is None else node.text.strip()


def collect_semantic_summary(model_path: Path) -> dict[str, Any]:
    """Extract instance identity and semantic subtree hashes from TM7 XML."""
    root = _parse_xml(model_path)
    instances: list[dict[str, str]] = []
    for entry in root.findall("{*}ThreatInstances/{*}KeyValueOfstringThreatpc_P0_PhOB"):
        value = entry.find("{*}Value")
        if value is None:
            continue
        instances.append(
            {
                "key": _text(entry, "Key"),
                "id": _text(value, "Id"),
                "type_id": _text(value, "TypeId"),
                "state": _text(value, "State"),
                "drawing_surface_guid": _text(value, "DrawingSurfaceGuid"),
                "source_guid": _text(value, "SourceGuid"),
                "flow_guid": _text(value, "FlowGuid"),
                "target_guid": _text(value, "TargetGuid"),
            }
        )
    surfaces = root.find("{*}DrawingSurfaceList")
    knowledge_base = root.find("{*}KnowledgeBase")
    knowledge_base_type_ids = sorted(
        {
            _text(threat_type, "Id")
            for threat_type in root.findall(".//{*}ThreatType")
            if _text(threat_type, "Id")
        }
    )
    custom_type_ids = [
        type_id for type_id in knowledge_base_type_ids if type_id.startswith("THC-")
    ]
    digest = lambda node: hashlib.sha256(  # noqa: E731
        ET.tostring(node, encoding="utf-8") if node is not None else b""
    ).hexdigest()
    threat_identities = sorted(
        {
            "|".join(
                (
                    str(instance.get("id") or "").strip().lower(),
                    str(instance.get("type_id") or "").strip().lower(),
                    str(instance.get("state") or "").strip().lower(),
                    str(instance.get("drawing_surface_guid") or "").strip().lower(),
                    str(instance.get("source_guid") or "").strip().lower(),
                    str(instance.get("flow_guid") or "").strip().lower(),
                    str(instance.get("target_guid") or "").strip().lower(),
                )
            )
            for instance in instances
        }
    )
    try:
        parsed_model = generate_tm7.parse_hardened_xml(model_path)
    except Exception:  # pragma: no cover - parser fallback for malformed models
        parsed_model = {}
    element_identities = sorted(
        {
            "|".join(
                (
                    str(element.get("surface_id") or "").strip().lower(),
                    str(element.get("id") or "").strip().lower(),
                    str(element.get("kind") or "").strip().lower(),
                    str(element.get("type_id") or "").strip().lower(),
                    str(element.get("guid") or "").strip().lower(),
                )
            )
            for element in parsed_model.get("elements", [])
            if isinstance(element, dict)
        }
    )
    flow_identities = sorted(
        {
            "|".join(
                (
                    str(flow.get("surface_id") or "").strip().lower(),
                    str(flow.get("id") or "").strip().lower(),
                    str(flow.get("source_guid") or "").strip().lower(),
                    str(flow.get("target_guid") or "").strip().lower(),
                    str(flow.get("source_ref") or "").strip().lower(),
                    str(flow.get("target_ref") or "").strip().lower(),
                )
            )
            for flow in parsed_model.get("flows", [])
            if isinstance(flow, dict)
        }
    )
    return {
        "path": str(model_path),
        "sha256": sha256_file(model_path),
        "generation_enabled": _text(root, "ThreatGenerationEnabled"),
        "instance_count": len(instances),
        "instances": sorted(instances, key=lambda item: item["id"]),
        "knowledge_base_type_ids": knowledge_base_type_ids,
        "custom_type_ids": custom_type_ids,
        "drawing_surface_hash": digest(surfaces),
        "knowledge_base_hash": digest(knowledge_base),
        "threat_count": len(instances),
        "threat_identities": threat_identities,
        "element_identities": element_identities,
        "flow_identities": flow_identities,
    }


def _load_pywinauto() -> tuple[Any, Any, Any]:
    try:
        from pywinauto import Desktop
        from pywinauto.keyboard import send_keys
        from pywinauto.timings import TimeoutError as PywinautoTimeoutError
    except ImportError as exc:
        raise HarnessFailure(
            "pywinauto is required for native TMT validation",
            EXIT_MISSING_TMT,
        ) from exc
    return Desktop, send_keys, PywinautoTimeoutError


def launch_tmt_process(target_path: Path, model_path: Path) -> subprocess.Popen[bytes]:
    """Launch a harness-owned TMT process against a working copy."""
    try:
        return subprocess.Popen(
            [str(target_path), str(model_path)],
            cwd=target_path.parent,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except OSError as exc:
        raise HarnessFailure(f"Unable to launch TMT: {exc}", EXIT_MISSING_TMT) from exc


def _visible_process_windows(process_id: int) -> list[Any]:
    try:
        Desktop, _, _ = _load_pywinauto()
    except HarnessFailure:
        return []
    return Desktop(backend="uia").windows(process=process_id, visible_only=True)


def _window_title(window: Any) -> str:
    try:
        return window.window_text().strip()
    except Exception:  # pragma: no cover - stale native window boundary
        return ""


def _window_area(window: Any) -> int:
    try:
        rectangle = window.rectangle()
        return max(0, rectangle.width()) * max(0, rectangle.height())
    except Exception:  # pragma: no cover - stale native window boundary
        return -1


def _is_transient_window(window: Any) -> bool:
    title = _window_title(window).lower()
    return not title or "please wait while the application opens" in title


def _is_visible_window(window: Any) -> bool:
    try:
        checker = getattr(window, "is_visible", None)
        return True if checker is None else bool(checker())
    except Exception:  # pragma: no cover - stale native window boundary
        return False


def maximize_window(window: Any) -> bool:
    """Maximize the TMT window so captures show the largest possible surface.

    A larger Diagram pane reduces tiling and scrolling, so more of each surface
    is visible per capture and layout defects are easier to judge. Returns
    whether the window reports a maximized state afterwards.
    """
    maximizer = getattr(window, "maximize", None)
    if maximizer is not None:
        try:
            maximizer()
        except Exception:  # pragma: no cover - stale native window boundary
            return False
    checker = getattr(window, "is_maximized", None)
    if checker is None:
        return maximizer is not None
    try:
        return bool(checker())
    except Exception:  # pragma: no cover - stale native window boundary
        return False


def find_tmt_window(process: subprocess.Popen[bytes], timeout_seconds: float) -> Any:
    """Connect to the harness-owned top-level TMT window through UIA."""
    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline:
        windows = _visible_process_windows(process.pid)
        candidates = [
            window
            for window in windows
            if not _is_transient_window(window) and _window_area(window) > 300_000
        ]
        if candidates:
            window = max(candidates, key=_window_area)
            maximize_window(window)
            return window
        if process.poll() is not None:
            break
        time.sleep(0.2)
    raise HarnessFailure("TMT window did not become ready", EXIT_AUTOMATION_TIMEOUT)


def _modal_windows(window: Any) -> list[Any]:
    """Return distinct top-level and nested modal windows owned by TMT."""
    process_id = window.process_id()
    windows = _visible_process_windows(process_id)
    main_handle = window.handle
    candidates: list[Any] = []
    for candidate in windows:
        if candidate.handle == main_handle or _is_transient_window(candidate):
            continue
        if _window_title(candidate):
            candidates.append(candidate)

    try:
        descendants = window.descendants(control_type="Window")
    except Exception:  # pragma: no cover - stale native window boundary
        descendants = []
    for candidate in descendants:
        title = _window_title(candidate)
        if title and title != _window_title(window) and _is_visible_window(candidate):
            candidates.append(candidate)

    distinct: list[Any] = []
    seen_handles: set[int] = set()
    for candidate in candidates:
        handle = int(getattr(candidate, "handle", 0))
        if handle and handle in seen_handles:
            continue
        if handle:
            seen_handles.add(handle)
        distinct.append(candidate)
    return distinct


def detect_modal_dialog(window: Any) -> str | None:
    """Return titles of unexpected harness-owned modal dialogs."""
    modal_titles = [_window_title(candidate) for candidate in _modal_windows(window)]

    if not modal_titles:
        return None
    unique_titles = list(dict.fromkeys(modal_titles))
    return "; ".join(unique_titles)


def _element_bounds(info: Any) -> tuple[str, str, str, str]:
    """Return screen-space left/top/right/bottom for a UIA element.

    Elements that are offscreen or expose no bounding rectangle yield empty
    strings so callers can distinguish "not measurable" from a zero-area rect.
    """
    rect = getattr(info, "rectangle", None)
    if rect is None:
        return ("", "", "", "")
    try:
        return (
            str(int(rect.left)),
            str(int(rect.top)),
            str(int(rect.right)),
            str(int(rect.bottom)),
        )
    except (AttributeError, TypeError, ValueError):
        return ("", "", "", "")


def build_uia_tree(window: Any) -> str:
    """Serialize stable UIA selector attributes for the TMT window.

    Each line is index|control_type|automation_id|name|left|top|right|bottom.
    Bounding rectangles are screen-space and describe what the renderer
    actually drew, which is the only available source of label geometry:
    the TM7 format persists connector label position nowhere.
    """
    lines: list[str] = []
    controls = [window, *window.descendants()]
    for index, control in enumerate(controls):
        info = control.element_info
        lines.append(
            "|".join(
                [
                    str(index),
                    str(getattr(info, "control_type", "")),
                    str(getattr(info, "automation_id", "")),
                    str(getattr(info, "name", "")),
                    *_element_bounds(info),
                ]
            )
        )
    return "\n".join(lines) + "\n"


def screenshot_isolation_available() -> bool:
    """Report whether the host can capture one window without its occluders.

    Pixels cannot be redacted after the fact, so a capture that may include an
    overlapping application is a disclosure the evidence bundle cannot repair.
    Capture is therefore permitted only where Pillow can address a specific
    native window handle, which requires Windows and the ``window`` keyword
    that Pillow exposes on that platform alone.

    Returns:
        True when window-isolated capture is available.
    """
    if sys.platform != "win32":
        return False
    try:
        from PIL import ImageGrab
    except Exception:
        return False
    return "window" in inspect.signature(ImageGrab.grab).parameters


def capture_window_screenshot(window: Any, output_path: Path) -> None:
    """Capture only the TMT window, or refuse rather than risk disclosure."""
    if not screenshot_isolation_available():
        raise HarnessFailure(
            "Screenshot capture is disabled: this host cannot isolate a single "
            "window, and a desktop-region capture could persist unrelated "
            "application content that redaction cannot remove",
            EXIT_VALIDATION_FAILURE,
        )
    handle = int(getattr(window, "handle", 0))
    if not handle:
        raise HarnessFailure(
            "Unable to capture the TMT window: missing native handle",
            EXIT_VALIDATION_FAILURE,
        )
    try:
        from PIL import ImageGrab
    except Exception as exc:
        raise HarnessFailure(
            f"Unable to capture the TMT window: {type(exc).__name__}",
            EXIT_VALIDATION_FAILURE,
        ) from exc

    last_error: Exception | None = None
    for _ in range(3):
        try:
            # Maximize rather than restore: restoring would shrink an already
            # maximized window and cut the captured diagram surface.
            maximize_window(window)
            focuser = getattr(window, "set_focus", None)
            if focuser is not None:
                try:
                    focuser()
                except Exception:
                    # Focus is best effort. A window that refuses focus can
                    # still be captured, and failing the capture here would
                    # lose evidence over a cosmetic precondition.
                    pass
            image = ImageGrab.grab(window=handle)
            image.save(output_path)
            return
        except Exception as exc:
            last_error = exc
            time.sleep(0.2)
    raise HarnessFailure(
        "Unable to capture the TMT window",
        EXIT_VALIDATION_FAILURE,
    ) from last_error


def capture_diagnostic_screenshot(
    window: Any,
    output_path: Path,
    bundle: EvidenceBundle,
) -> None:
    """Capture diagnostic evidence without turning a stale UIA handle into a gate."""
    try:
        capture_window_screenshot(window, output_path)
    except HarnessFailure as exc:
        bundle.write_action_log(str(exc))


def _capture_or_skip(
    window: Any,
    output_path: Path,
    *,
    bundle: EvidenceBundle,
    require_feedback_evidence: bool,
) -> None:
    """Capture a surface screenshot, or fail closed when evidence is required.

    Strict mode treats a host that cannot isolate a window as an evidence
    failure rather than silently producing a bundle with no screenshots. A
    non-strict run records the reason and continues, because the portable
    geometry gates do not depend on pixels.

    Args:
        window: Target window to capture.
        output_path: Confined destination inside the evidence bundle.
        bundle: Evidence bundle receiving the action log entry.
        require_feedback_evidence: Whether the run demands complete evidence.

    Raises:
        HarnessFailure: If capture fails while evidence is required.
    """
    try:
        capture_window_screenshot(window, output_path)
    except HarnessFailure as exc:
        if require_feedback_evidence:
            raise
        bundle.write_action_log(str(exc))


def _find_child_text(element: Any, name: str) -> str:
    """Return the trimmed text for the first child element with the supplied name."""
    for child in list(getattr(element, "iter", lambda: [])()):
        if tm7_threat_contract._local_name(child.tag) == name:
            return (child.text or "").strip()
    for child in list(element):
        if tm7_threat_contract._local_name(child.tag) == name:
            return (child.text or "").strip()
    return ""


def _normalize_name(value: str) -> str:
    """Normalize a UIA or surface name for deterministic matching."""
    return re.sub(r"[^a-z0-9]+", "", value.lower())


def _iter_controls(window: Any) -> Iterator[Any]:
    """Yield the window and all descendants in a stable traversal order."""
    yield window
    for child in getattr(window, "descendants", lambda: [])():
        yield child


def _control_name(control: Any) -> str:
    """Return the visible name for a control if available."""
    info = getattr(control, "element_info", None)
    if info is None:
        return ""
    return str(getattr(info, "name", ""))


def _control_automation_id(control: Any) -> str:
    """Return the automation ID for a control if available."""
    info = getattr(control, "element_info", None)
    if info is None:
        return ""
    return str(getattr(info, "automation_id", ""))


def _control_type(control: Any) -> str:
    """Return the UIA control type for a control if available."""
    info = getattr(control, "element_info", None)
    if info is None:
        return ""
    return str(getattr(info, "control_type", ""))


def _rectangle_value(rectangle: Any, attribute: str) -> int | None:
    """Return a rectangle coordinate from either callable or numeric members."""
    try:
        value = getattr(rectangle, attribute, None)
    except Exception:
        return None
    if value is None:
        return None
    if callable(value):
        try:
            value = value()
        except Exception:
            return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _control_rectangle(
    control: Any,
    window: Any | None = None,
    *,
    image_size: tuple[int, int] | None = None,
) -> dict[str, int] | None:
    """Return the control rectangle as window-relative coordinates."""
    rectangle = getattr(control, "rectangle", None)
    if rectangle is None:
        return None
    if callable(rectangle):
        try:
            rectangle = rectangle()
        except Exception:
            return None

    left = _rectangle_value(rectangle, "left")
    top = _rectangle_value(rectangle, "top")
    right = _rectangle_value(rectangle, "right")
    bottom = _rectangle_value(rectangle, "bottom")
    if None in {left, top, right, bottom}:
        return None

    if window is not None:
        window_rectangle = getattr(window, "rectangle", None)
        if window_rectangle is not None:
            if callable(window_rectangle):
                try:
                    window_rectangle = window_rectangle()
                except Exception:
                    window_rectangle = None
            if window_rectangle is not None:
                window_left = _rectangle_value(window_rectangle, "left")
                window_top = _rectangle_value(window_rectangle, "top")
                if window_left is not None:
                    left -= window_left
                    right -= window_left
                if window_top is not None:
                    top -= window_top
                    bottom -= window_top

    if image_size is not None:
        image_width, image_height = image_size
        left = max(0, min(left, image_width))
        top = max(0, min(top, image_height))
        right = max(0, min(right, image_width))
        bottom = max(0, min(bottom, image_height))

    width = max(0, right - left)
    height = max(0, bottom - top)
    if width <= 0 or height <= 0:
        return None
    return {
        "left": left,
        "top": top,
        "right": right,
        "bottom": bottom,
        "width": width,
        "height": height,
    }


def read_expected_surfaces(model_path: Path) -> list[SurfaceDescriptor]:
    """Parse drawing surface descriptors from a TM7 model.

    Args:
        model_path: TM7 model to inspect.

    Returns:
        Surface descriptors discovered in the model.

    Raises:
        HarnessFailure: If the model cannot be read or is unsafe to parse.
    """
    root = _parse_xml(model_path)
    surfaces: list[SurfaceDescriptor] = []
    surface_elements = [
        element
        for element in root.iter()
        if tm7_threat_contract._local_name(element.tag) == "DrawingSurfaceModel"
    ]
    for index, element in enumerate(surface_elements):
        surface_name = _find_child_text(element, "Header")
        surface_guid = _find_child_text(element, "Guid")
        if not surface_name or not surface_guid:
            continue
        surface_id = re.sub(r"[^a-z0-9]+", "-", surface_name.lower()).strip("-")
        if not surface_id:
            surface_id = f"surface-{index}"
        surfaces.append(
            SurfaceDescriptor(
                surface_id=surface_id,
                surface_guid=surface_guid,
                surface_name=surface_name,
                tab_index=index,
            )
        )
    return surfaces


def enumerate_surface_tabs(window: Any) -> list[SurfaceTab]:
    """Enumerate visible surface tabs from the TMT UIA tree."""
    tabs: list[SurfaceTab] = []
    for control in _iter_controls(window):
        control_type = _control_type(control)
        if control_type != "TabItem":
            continue
        name = _control_name(control)
        automation_id = _control_automation_id(control)
        normalized_name = _normalize_name(name)
        if automation_id in NON_SURFACE_TAB_AUTOMATION_IDS:
            continue
        if SURFACE_TAB_NAME_MARKER not in normalized_name:
            continue
        tabs.append(
            SurfaceTab(
                control=control,
                name=name,
                automation_id=automation_id,
                control_type=control_type,
                tab_index=len(tabs),
            )
        )
    return tabs


def select_surface_tab(
    window: Any,
    surface: SurfaceDescriptor,
    tabs: list[SurfaceTab] | list[Any],
) -> Any:
    """Select a surface tab only when its identity is unambiguous.

    TMT presents a surface tab as ``DocumentView, Title <surface name>``
    rather than the bare caption, so an exact comparison never matches a
    named surface. A suffix comparison recovers the caption without
    depending on the wrapper wording.
    """
    matches: list[Any] = []
    suffix_matches: list[Any] = []
    normalized_surface = _normalize_name(surface.surface_name)
    for tab in tabs:
        if isinstance(tab, SurfaceTab):
            candidate = tab.control
            name = tab.name
        else:
            candidate = tab
            name = _control_name(tab)
        normalized_tab = _normalize_name(name)
        if normalized_tab == normalized_surface:
            matches.append(candidate)
        elif normalized_surface and normalized_tab.endswith(normalized_surface):
            suffix_matches.append(candidate)
    if not matches and len(suffix_matches) == 1:
        return suffix_matches[0]
    if len(matches) == 1:
        # `matches` holds the resolved control for both the SurfaceTab and
        # raw-control shapes, so it is returned directly. Indexing `tabs`
        # instead would attribute every raw-control surface to the first tab.
        return matches[0]
    if len(matches) > 1:
        if surface.tab_index < len(matches):
            return matches[surface.tab_index]
    if not matches and len(suffix_matches) > 1:
        if surface.tab_index < len(suffix_matches):
            return suffix_matches[surface.tab_index]
    # Every enumerated tab is a drawing surface, so positional fallback uses
    # the full list. Filtering on a generic caption such as "Diagram" would
    # empty this list once surfaces carry their authored titles.
    positional_tabs = [
        tab.control if isinstance(tab, SurfaceTab) else tab for tab in tabs
    ]
    if surface.tab_index < len(positional_tabs):
        return positional_tabs[surface.tab_index]
    raise HarnessFailure(
        f"Unable to locate a matching surface tab for {surface.surface_name}",
        EXIT_VALIDATION_FAILURE,
    )


def find_live_surface_tab(window: Any, surface: SurfaceDescriptor) -> Any | None:
    """Return the currently materialized control for one expected surface."""
    normalized_surface = _normalize_name(surface.surface_name)
    if not normalized_surface:
        return None
    for tab in enumerate_surface_tabs(window):
        normalized_tab = _normalize_name(tab.name)
        if normalized_tab == normalized_surface or normalized_tab.endswith(
            normalized_surface
        ):
            return tab.control
    return None


def _invoke_control(control: Any) -> None:
    """Invoke a UIA control through whichever pattern it supports."""
    for attribute in ("invoke", "select", "click_input"):
        action = getattr(control, attribute, None)
        if callable(action):
            action()
            return
    raise HarnessFailure(
        "UI control supports neither invoke, select, nor click",
        EXIT_VALIDATION_FAILURE,
    )


def _expand_document_menu(window: Any) -> Any | None:
    """Open the document menu that lists every open drawing surface.

    TMT clips its tab strip and omits the clipped tabs from the accessibility
    tree entirely, so a model with more surfaces than fit on screen cannot be
    navigated through tabs alone. The menu carrying ``WindowMenuItem`` is the
    standard MDI document switcher and lists every open document regardless of
    tab visibility, which makes it the reliable activation path.
    """
    for control in _iter_controls(window):
        if _control_type(control) != "MenuItem":
            continue
        if _control_automation_id(control) != DOCUMENT_MENU_AUTOMATION_ID:
            continue
        try:
            expand = getattr(control, "expand", None)
            if callable(expand):
                expand()
            else:
                _invoke_control(control)
        except Exception:
            return None
        return control
    return None


def _collapse_menu(menu: Any) -> None:
    """Close an opened menu, ignoring a control that cannot be collapsed."""
    try:
        collapse = getattr(menu, "collapse", None)
        if callable(collapse):
            collapse()
    except Exception:
        # Collapsing is housekeeping so the next interaction starts from a
        # known state. A menu that will not collapse does not invalidate the
        # work already done, and the caller has no recovery to offer.
        pass


def activate_surface_via_document_menu(
    window: Any,
    surface: SurfaceDescriptor,
) -> bool:
    """Activate a surface through the document menu; report whether it worked."""
    menu = _expand_document_menu(window)
    if menu is None:
        return False
    normalized_surface = _normalize_name(surface.surface_name)
    try:
        for entry in _iter_controls(menu):
            if _control_type(entry) != "MenuItem":
                continue
            normalized_entry = _normalize_name(_control_name(entry))
            if not normalized_entry:
                continue
            if normalized_entry == normalized_surface or normalized_entry.endswith(
                normalized_surface
            ):
                _invoke_control(entry)
                return True
    except Exception:
        # Any failure walking or invoking the menu means this activation route
        # did not work. The caller falls back to another route on False, so a
        # raise here would remove that fallback.
        pass
    _collapse_menu(menu)
    return False


def activate_surface_tab(
    window: Any,
    surface: SurfaceDescriptor,
    tabs: list[SurfaceTab],
) -> None:
    """Activate one expected surface using semantic name or stable tab order.

    The strip scrolls as tabs are revealed, so a control captured during an
    earlier enumeration can name the right surface while pointing at a stale
    screen position. Clicking that position would silently capture a
    different surface, so the tab is re-resolved against the live tree first
    and the supplied list is consulted only as a positional fallback.
    """
    control = find_live_surface_tab(window, surface)
    if control is None:
        # The surface has no visible tab, so the document menu is the only
        # path that reaches it. Tab-strip scrolling cannot help: TMT exposes
        # no scroll pattern there and omits clipped tabs from the tree.
        if activate_surface_via_document_menu(window, surface):
            return
        control = find_live_surface_tab(window, surface)
    if control is None:
        selected = select_surface_tab(window, surface, tabs)
        control = selected.control if isinstance(selected, SurfaceTab) else selected
    selector = getattr(control, "select", None)
    if callable(selector):
        try:
            selector()
            return
        except Exception:
            # This control does not support selection, so fall through to the
            # click path below rather than failing the interaction.
            pass
    control.click_input()


def find_diagram_pane(window: Any, surface: SurfaceDescriptor | None = None) -> Any:
    """Locate the drawing-surface pane for the active surface.

    TMT names the surface pane with the surface caption and sets its
    automation id to that surface's own GUID, so there is no single constant
    that identifies "the Diagram pane". Resolution therefore runs from the
    most specific evidence to the least: the surface GUID, then the surface
    caption, then any pane containing the stable ``Viewport`` canvas child.
    """
    surface_guid = (surface.surface_guid or "") if surface else ""
    normalized_surface = _normalize_name(surface.surface_name) if surface else ""
    caption_match: Any | None = None
    viewport_match: Any | None = None

    for control in _iter_controls(window):
        if _control_type(control) != "Pane":
            continue
        automation_id = _control_automation_id(control)
        if surface_guid and automation_id == surface_guid:
            return control
        name = _control_name(control)
        if normalized_surface and _normalize_name(name) == normalized_surface:
            if caption_match is None:
                caption_match = control
            continue
        if viewport_match is None and _has_viewport_child(control):
            viewport_match = control

    if caption_match is not None:
        return caption_match
    if viewport_match is not None:
        return viewport_match
    raise HarnessFailure(
        "Unable to locate the Diagram pane for surface capture",
        EXIT_VALIDATION_FAILURE,
    )


def _has_viewport_child(control: Any) -> bool:
    """Report whether a pane owns the stable Viewport drawing canvas."""
    for child in getattr(control, "descendants", lambda: [])():
        if _control_automation_id(child) == CANVAS_VIEWPORT_AUTOMATION_ID:
            return True
    return False


def read_canvas_announcement(diagram_pane: Any) -> str:
    """Return the pane's canvas announcement text."""
    for control in _iter_controls(diagram_pane):
        if _control_automation_id(control) == "canvasAnnouncement":
            announcement = _control_name(control)
            if announcement:
                return announcement

    for control in _iter_controls(diagram_pane):
        announcement = _control_name(control)
        if not announcement:
            continue
        normalized = _normalize_name(announcement)
        if normalized in {"canvas", "drawingcanvas", "drawingcanvasannouncement"}:
            return announcement
        if "canvas" in normalized or "drawing" in normalized:
            return announcement

    return _control_name(diagram_pane)


def _find_tab_strip_scroll(window: Any) -> Any | None:
    """Return the horizontal Scroll pattern owning the surface tab strip.

    TMT was measured to expose no scroll pattern on its tab container, so this
    returns ``None`` there. It is retained because a future TMT build, or a
    differently sized session, may present one.
    """
    for control in _iter_controls(window):
        if _control_type(control) != "Tab":
            continue
        candidates = [control, *getattr(control, "descendants", lambda: [])()]
        for candidate in candidates:
            try:
                scroll_interface = candidate.iface_scroll
                float(scroll_interface.CurrentHorizontalScrollPercent)
            except Exception:
                continue
            return scroll_interface
    return None


def materialize_surface_tabs(window: Any, expected_count: int) -> list[SurfaceTab]:
    """Reveal every surface tab that TMT is willing to expose.

    TMT clips the tab strip to the available width and omits every clipped tab
    from the accessibility tree, so a model with more surfaces than fit on
    screen exposes only the visible prefix. Nine surfaces need roughly 3170 px
    of strip against a 2400 px display, and the strip carries no scroll
    pattern, so the remainder cannot be revealed here at all. Activation
    through the document menu reaches them instead, and each activation brings
    its document to the front of the strip.
    """
    discovered: dict[str, SurfaceTab] = {}
    for tab in enumerate_surface_tabs(window):
        key = _normalize_name(tab.name)
        if key and key not in discovered:
            discovered[key] = SurfaceTab(
                control=tab.control,
                name=tab.name,
                automation_id=tab.automation_id,
                control_type=tab.control_type,
                tab_index=len(discovered),
            )
    return list(discovered.values())


def _find_scroll_interface(diagram_pane: Any) -> Any | None:
    """Return the first usable UIA Scroll pattern in the diagram subtree."""
    controls = [diagram_pane, *getattr(diagram_pane, "descendants", lambda: [])()]
    controls.sort(
        key=lambda control: (
            _control_automation_id(control) != CANVAS_VIEWPORT_AUTOMATION_ID,
            _control_type(control) != "Pane",
        )
    )
    for control in controls:
        try:
            scroll_interface = control.iface_scroll
            float(scroll_interface.CurrentHorizontalScrollPercent)
            float(scroll_interface.CurrentVerticalScrollPercent)
        except Exception:
            continue
        return scroll_interface
    return None


def _read_image_dimensions(path: Path) -> tuple[int, int]:
    """Return image width and height when the file can be parsed."""
    try:
        from PIL import Image
    except Exception:
        return (0, 0)
    try:
        with Image.open(path) as image:
            return (image.width, image.height)
    except Exception:
        return (0, 0)


def _compose_stitched_preview(
    source_paths: Iterable[Path],
    output_path: Path,
) -> None:
    """Create a lightweight composite preview from captured tile images."""
    try:
        from PIL import Image
    except Exception:
        return

    images: list[Image.Image] = []
    for source_path in source_paths:
        if not source_path.exists():
            continue
        try:
            with Image.open(source_path) as image:
                images.append(image.convert("RGBA"))
        except Exception:
            continue
    if not images:
        return

    tile_width = max(image.width for image in images)
    tile_height = max(image.height for image in images)
    canvas = Image.new("RGBA", (tile_width * 2, tile_height * 2), (255, 255, 255, 255))
    for index, image in enumerate(images):
        offset_x = (index % 2) * (tile_width // 2)
        offset_y = (index // 2) * (tile_height // 2)
        canvas.paste(image, (offset_x, offset_y), image)
    canvas.save(output_path)


def capture_surface_evidence(
    window: Any,
    bundle: EvidenceBundle,
    surface: SurfaceDescriptor,
    *,
    model_path: Path | None = None,
    require_feedback_evidence: bool = False,
    scroll_extent_ratio_x: float = 1.0,
    scroll_extent_ratio_y: float = 1.0,
    viewport_target: tuple[float, float, float, float] | None = None,
    pane_rect: dict[str, int] | None = None,
    calibration_context: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Capture pane-scoped evidence for a single drawing surface."""
    # Maximize before measuring so the pane rectangle and calibration reflect
    # the largest available Diagram surface.
    window_maximized = maximize_window(window)
    # The surface id comes from spec content, so it is reduced to one safe path
    # segment before it can name a file inside the evidence bundle.
    surface_slug = _evidence_slug(surface.surface_id)
    try:
        diagram_pane = find_diagram_pane(window, surface)
    except HarnessFailure:
        if require_feedback_evidence:
            raise
        diagram_pane = None

    screenshot_dimensions = {"width": 0, "height": 0}
    crop_dimensions = {"width": 0, "height": 0}
    if diagram_pane is None:
        if require_feedback_evidence:
            raise HarnessFailure(
                "Strict feedback evidence requires a Diagram pane",
                EXIT_VALIDATION_FAILURE,
            )
        capture_scope = "window"
        screenshot_path = bundle.path(f"screenshots/{surface_slug}-surface.png")
        _capture_or_skip(
            window,
            screenshot_path,
            bundle=bundle,
            require_feedback_evidence=require_feedback_evidence,
        )
        uia_snapshot = build_uia_tree(window)
        ui_path = bundle.write_uia_tree(
            uia_snapshot,
            f"{surface_slug}-surface.txt",
        )
        announcement = ""
        crop = None
        screenshot_dimensions = {
            "width": _read_image_dimensions(screenshot_path)[0],
            "height": _read_image_dimensions(screenshot_path)[1],
        }
    else:
        screenshot_path = bundle.path(f"screenshots/{surface_slug}-surface.png")
        _capture_or_skip(
            window,
            screenshot_path,
            bundle=bundle,
            require_feedback_evidence=require_feedback_evidence,
        )
        screenshot_dimensions = {
            "width": _read_image_dimensions(screenshot_path)[0],
            "height": _read_image_dimensions(screenshot_path)[1],
        }
        crop = None
        capture_scope = "window"
        crop = _control_rectangle(diagram_pane, window)
        if crop is not None and crop["width"] > 0 and crop["height"] > 0:
            capture_scope = "pane"
            try:
                from PIL import Image
            except Exception:
                # Without Pillow the screenshot stays uncropped. The measured
                # crop rectangle is still reported, so downstream geometry is
                # unaffected by the missing crop.
                pass
            else:
                try:
                    image = Image.open(screenshot_path)
                    cropped = image.crop(
                        (crop["left"], crop["top"], crop["right"], crop["bottom"])
                    )
                    cropped.save(screenshot_path)
                except Exception:
                    # A crop failure leaves the full-frame capture in place,
                    # which is still valid evidence.
                    pass
        else:
            crop = None

        if crop is None and require_feedback_evidence:
            raise HarnessFailure(
                "Strict feedback evidence requires a visible Diagram pane",
                EXIT_VALIDATION_FAILURE,
            )

        if crop is not None:
            crop_dimensions = {
                "width": int(crop.get("width", 0) or 0),
                "height": int(crop.get("height", 0) or 0),
            }
        uia_snapshot = build_uia_tree(diagram_pane)
        ui_path = bundle.write_uia_tree(
            uia_snapshot,
            f"{surface_slug}-surface.txt",
        )
        announcement = read_canvas_announcement(diagram_pane)

    scroll_tiles: list[str] = []
    scroll_coverage_complete = True
    tile_manifest: dict[str, Any] | None = None
    stitched_preview_path: str | None = None
    scroll_restored = True
    scroll_percentages = {"horizontal": 0.0, "vertical": 0.0}
    if diagram_pane is not None and (
        scroll_extent_ratio_x > 1.0 or scroll_extent_ratio_y > 1.0
    ):
        scroll_interface = _find_scroll_interface(diagram_pane)
        if scroll_interface is None:
            scroll_coverage_complete = False
        else:
            horizontal_positions = (
                [0.0, 100.0] if scroll_extent_ratio_x > 1.0 else [0.0]
            )
            vertical_positions = [0.0, 100.0] if scroll_extent_ratio_y > 1.0 else [0.0]
            positions = list(
                dict.fromkeys(
                    (horizontal_value, vertical_value)
                    for vertical_value in vertical_positions
                    for horizontal_value in horizontal_positions
                )
            )
            if len(horizontal_positions) > 2 or len(vertical_positions) > 2:
                scroll_coverage_complete = False
            if len(positions) > 4:
                scroll_coverage_complete = False
            if scroll_extent_ratio_x > 2.0 or scroll_extent_ratio_y > 2.0:
                scroll_coverage_complete = False
            try:
                initial_horizontal = float(
                    scroll_interface.CurrentHorizontalScrollPercent
                )
                initial_vertical = float(scroll_interface.CurrentVerticalScrollPercent)
                scroll_percentages = {
                    "horizontal": initial_horizontal,
                    "vertical": initial_vertical,
                }
                for horizontal_value, vertical_value in positions:
                    scroll_interface.SetScrollPercent(
                        horizontal_value,
                        vertical_value,
                    )
                    tile_path = bundle.path(
                        "screenshots/"
                        f"{surface_slug}-tile-"
                        f"{int(horizontal_value):03d}-"
                        f"{int(vertical_value):03d}.png"
                    )
                    capture_window_screenshot(window, tile_path)
                    scroll_tiles.append(str(tile_path.relative_to(bundle.evidence_dir)))
                tile_manifest = {
                    "position_count": len(positions),
                    "max_axis_positions": max(
                        len(horizontal_positions),
                        len(vertical_positions),
                    ),
                    "positions": [
                        {"horizontal": horizontal_value, "vertical": vertical_value}
                        for horizontal_value, vertical_value in positions
                    ],
                    "source_tiles": scroll_tiles,
                    "tile_count": len(scroll_tiles),
                    "consistent": True,
                }
                stitched_preview_path = str(
                    bundle.path(
                        f"screenshots/{surface_slug}-stitched-preview.png"
                    ).relative_to(bundle.evidence_dir)
                )
                preview_path = bundle.path(
                    f"screenshots/{surface_slug}-stitched-preview.png"
                )
                tile_paths = [
                    bundle.evidence_dir / relative_tile
                    for relative_tile in scroll_tiles
                ]
                _compose_stitched_preview(tile_paths, preview_path)
            except Exception:
                scroll_coverage_complete = False
                scroll_tiles = []
                tile_manifest = {
                    "position_count": 0,
                    "max_axis_positions": 0,
                    "positions": [],
                    "source_tiles": [],
                    "tile_count": 0,
                    "consistent": False,
                }
            finally:
                try:
                    scroll_interface.SetScrollPercent(
                        initial_horizontal,
                        initial_vertical,
                    )
                except (AttributeError, UnboundLocalError, TypeError):
                    scroll_coverage_complete = False
                    scroll_restored = False
    if not scroll_coverage_complete and tile_manifest is None:
        tile_manifest = {
            "position_count": 0,
            "max_axis_positions": 0,
            "positions": [],
            "source_tiles": [],
            "tile_count": 0,
            "consistent": False,
        }
    elif not scroll_coverage_complete and tile_manifest is not None:
        tile_manifest["consistent"] = False
        tile_manifest["source_tiles"] = []
        tile_manifest["tile_count"] = 0
        tile_manifest["positions"] = []

    if require_feedback_evidence and not scroll_coverage_complete:
        raise HarnessFailure(
            "Strict feedback evidence requires controllable scroll coverage",
            EXIT_VALIDATION_FAILURE,
        )

    resolved_pane_rect = pane_rect
    if resolved_pane_rect is None and crop is not None:
        resolved_pane_rect = {
            "left": crop["left"],
            "top": crop["top"],
            "width": crop["width"],
            "height": crop["height"],
        }

    if require_feedback_evidence and resolved_pane_rect is None:
        raise HarnessFailure(
            "Strict feedback evidence requires a measured Diagram pane",
            EXIT_VALIDATION_FAILURE,
        )

    resolved_viewport_target = viewport_target
    if resolved_viewport_target is None and resolved_pane_rect is not None:
        resolved_viewport_target = (
            0.0,
            0.0,
            float(resolved_pane_rect.get("width", 0) or 0),
            float(resolved_pane_rect.get("height", 0) or 0),
        )

    if require_feedback_evidence and resolved_viewport_target is None:
        raise HarnessFailure(
            "Strict feedback evidence requires calibrated viewport targets",
            EXIT_VALIDATION_FAILURE,
        )

    payload = {
        "surface_id": surface.surface_id,
        "surface_guid": surface.surface_guid,
        "surface_name": surface.surface_name,
        "capture_scope": capture_scope,
        "annotation": announcement,
        "screenshot_path": str(screenshot_path.relative_to(bundle.evidence_dir)),
        "uia_path": str(ui_path.relative_to(bundle.evidence_dir)),
        "crop": crop,
        "model_path": str(model_path) if model_path is not None else None,
        "require_feedback_evidence": require_feedback_evidence,
        "scroll_extent_ratio_x": scroll_extent_ratio_x,
        "scroll_extent_ratio_y": scroll_extent_ratio_y,
        "scroll_tiles": scroll_tiles,
        "scroll_percentages": scroll_percentages,
        "scroll_coverage_complete": scroll_coverage_complete,
        "scroll_restored": scroll_restored,
        "window_maximized": window_maximized,
        "tile_manifest": tile_manifest,
        "stitched_preview_path": stitched_preview_path,
        "screenshot_dimensions": screenshot_dimensions,
        "crop_dimensions": crop_dimensions,
        "viewport_target": (
            list(resolved_viewport_target)
            if resolved_viewport_target is not None
            else None
        ),
        "pane_rect": resolved_pane_rect,
        "calibration_context": calibration_context,
    }
    bundle.write_surface_summary(payload, f"{surface.surface_id}-surface.json")
    return payload


def _find_control(window: Any, pattern: str, control_types: set[str]) -> Any:
    regex = re.compile(pattern, re.IGNORECASE)
    for control in window.descendants():
        info = control.element_info
        control_type = getattr(info, "control_type", "")
        if control_type not in control_types:
            continue
        name = str(getattr(info, "name", ""))
        if regex.search(name):
            return control
        automation_id = str(getattr(info, "automation_id", ""))
        if regex.search(automation_id):
            return control
    raise HarnessFailure(
        f"Unable to locate UI control matching {pattern}",
        EXIT_VALIDATION_FAILURE,
    )


def _reacquire_window(
    window: Any,
    *,
    process_id: int | None = None,
    reacquire_window: Callable[[], Any] | None = None,
) -> Any:
    """Reacquire the current harness-owned model window from UIA state."""
    if reacquire_window is not None:
        try:
            candidate = reacquire_window()
        except Exception:  # pragma: no cover - native window boundary
            candidate = None
        if candidate is not None:
            return candidate
    if process_id is None:
        return window
    try:
        candidates = [
            candidate
            for candidate in _visible_process_windows(process_id)
            if not _is_transient_window(candidate) and _window_area(candidate) > 300_000
        ]
    except Exception:  # pragma: no cover - stale native window boundary
        return window
    if not candidates:
        return window
    return max(candidates, key=_window_area)


def _analysis_view_ready(window: Any) -> bool:
    """Return True when the window is in a stable Analysis View state."""
    try:
        _find_control(window, r"^Threat List$", {"Pane", "Custom", "Group"})
    except HarnessFailure:
        return False
    try:
        _find_control(
            window,
            r"^(MainList|Threats List)$",
            {"DataGrid", "ListView", "Table"},
        )
    except HarnessFailure:
        return False
    try:
        _find_control(window, r"^Export Csv$", {"Button", "MenuItem", "SplitButton"})
    except HarnessFailure:
        return False
    return True


def _invoke_modal_handler(
    modal_handler: Callable[[Any], None] | Callable[[], None] | None,
    window: Any,
) -> None:
    """Invoke the modal handler with either the current window or no arguments."""
    if modal_handler is None:
        return
    try:
        signature = inspect.signature(modal_handler)
    except (TypeError, ValueError):
        signature = None

    if signature is None:
        modal_handler(window)
        return

    accepts_window = False
    for parameter in signature.parameters.values():
        if parameter.kind in (
            inspect.Parameter.POSITIONAL_ONLY,
            inspect.Parameter.POSITIONAL_OR_KEYWORD,
            inspect.Parameter.VAR_POSITIONAL,
        ):
            accepts_window = True
            break
    if accepts_window:
        modal_handler(window)
    else:
        modal_handler()


def _call_analysis_view_handler(
    handler: Callable[..., Any],
    window: Any,
    *,
    timeout_seconds: float,
    modal_handler: Callable[[Any], None] | Callable[[], None] | None,
    process: subprocess.Popen[bytes] | None,
    bundle: EvidenceBundle | None,
) -> Any:
    """Call the analysis-view opener with only the kwargs it accepts."""
    try:
        signature = inspect.signature(handler)
    except (TypeError, ValueError):
        signature = None

    if signature is None:
        return handler(
            window,
            timeout_seconds=timeout_seconds,
            modal_handler=modal_handler,
        )

    kwargs: dict[str, Any] = {}
    for name in ("timeout_seconds", "modal_handler", "process", "bundle"):
        if name in signature.parameters:
            kwargs[name] = {
                "timeout_seconds": timeout_seconds,
                "modal_handler": modal_handler,
                "process": process,
                "bundle": bundle,
            }[name]
    if any(
        parameter.kind == inspect.Parameter.VAR_KEYWORD
        for parameter in signature.parameters.values()
    ):
        kwargs.update(
            {
                "timeout_seconds": timeout_seconds,
                "modal_handler": modal_handler,
                "process": process,
                "bundle": bundle,
            }
        )
    result = handler(window, **kwargs)
    return window if result is None else result


def open_analysis_view(
    window: Any,
    *,
    timeout_seconds: float = DEFAULT_TIMEOUT_SECONDS,
    modal_handler: Callable[[Any], None] | Callable[[], None] | None = None,
    process: subprocess.Popen[bytes] | None = None,
    reacquire_window: Callable[[], Any] | None = None,
    bundle: EvidenceBundle | None = None,
) -> Any:
    """Navigate to Analysis View and wait for a confirmed Analysis state."""
    process_id = getattr(process, "pid", None)
    current_window = window
    if _analysis_view_ready(current_window):
        return current_window

    deadline = time.monotonic() + timeout_seconds
    switch_clicked = False
    while time.monotonic() < deadline:
        if not switch_clicked:
            control = _find_control(
                current_window,
                (
                    r"^(Analysis|Analysis View|Switch To Analysis View|"
                    r"View Analysis|Go To Analysis|Show Analysis)$"
                ),
                {
                    "Button",
                    "TabItem",
                    "MenuItem",
                    "Hyperlink",
                    "RadioButton",
                    "SplitButton",
                },
            )
            try:
                click = getattr(control, "click_input", None)
                if click is not None:
                    click()
                else:
                    invoke = getattr(control, "invoke", None)
                    if invoke is not None:
                        invoke()
                    else:
                        raise HarnessFailure(
                            "UI control does not support click or invoke",
                            EXIT_VALIDATION_FAILURE,
                        )
            except Exception as exc:  # pragma: no cover - native control boundary
                raise HarnessFailure(
                    "Unable to invoke the Analysis View switch control",
                    EXIT_VALIDATION_FAILURE,
                ) from exc
            switch_clicked = True

        current_window = _reacquire_window(
            current_window,
            process_id=process_id,
            reacquire_window=reacquire_window,
        )
        _invoke_modal_handler(modal_handler, current_window)
        current_window = _reacquire_window(
            current_window,
            process_id=process_id,
            reacquire_window=reacquire_window,
        )
        if _analysis_view_ready(current_window):
            return current_window
        time.sleep(0.2)
    if bundle is not None:
        try:
            bundle.write_uia_tree(
                build_uia_tree(current_window),
                "analysis-transition.txt",
            )
            capture_window_screenshot(
                current_window,
                bundle.path("screenshots/analysis-transition.png"),
            )
        except Exception:  # pragma: no cover - native capture boundary
            pass
    raise HarnessFailure(
        "Analysis View was not confirmed after switching",
        EXIT_AUTOMATION_TIMEOUT,
    )


def wait_for_analysis_window(
    process: subprocess.Popen[bytes],
    timeout_seconds: float,
) -> Any:
    """Wait for template conversion to return a model window with Analysis View."""
    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline:
        candidates = [
            window
            for window in _visible_process_windows(process.pid)
            if not _is_transient_window(window)
        ]
        for candidate in sorted(candidates, key=_window_area, reverse=True):
            if _analysis_view_ready(candidate):
                return candidate
        if process.poll() is not None:
            break
        time.sleep(0.2)
    raise HarnessFailure(
        "TMT did not return to a model window after template conversion",
        EXIT_AUTOMATION_TIMEOUT,
    )


def _save_dialog_path(
    process_id: int,
    destination: Path,
    timeout_seconds: float,
) -> None:
    Desktop, _, PywinautoTimeoutError = _load_pywinauto()
    try:
        deadline = time.monotonic() + timeout_seconds
        while time.monotonic() < deadline:
            try:
                dialogs = Desktop(backend="win32").windows(
                    class_name="#32770",
                    visible_only=True,
                )
            except Exception:  # pragma: no cover - native backend boundary
                dialogs = []
            for dialog in dialogs:
                try:
                    if dialog.process_id() != process_id:
                        continue
                    controls = dialog.descendants()
                except Exception:  # pragma: no cover - stale native dialog
                    continue
                buttons = [
                    control
                    for control in controls
                    if control.class_name() == "Button"
                    and _is_visible_window(control)
                    and re.fullmatch(
                        r"(?i)&?(Save|Export|Open)",
                        control.window_text().strip(),
                    )
                ]
                edits = [
                    control
                    for control in controls
                    if control.class_name() == "Edit" and _is_visible_window(control)
                ]
                if not buttons or not edits:
                    continue
                file_edit = edits[-1]
                try:
                    file_edit.set_focus()
                    file_edit.set_edit_text(str(destination))
                    buttons[0].click_input()
                except Exception:  # pragma: no cover - stale native control
                    continue
                close_deadline = time.monotonic() + timeout_seconds
                while time.monotonic() < close_deadline:
                    if destination.is_file() and destination.stat().st_size > 0:
                        return
                    time.sleep(0.2)
                raise PywinautoTimeoutError(
                    "native file dialog did not create the destination"
                )
            time.sleep(0.2)
        raise PywinautoTimeoutError("native file dialog was not found")
    except PywinautoTimeoutError as exc:
        raise HarnessFailure(
            "TMT file dialog timed out",
            EXIT_AUTOMATION_TIMEOUT,
        ) from exc


def export_threat_csv(window: Any, destination: Path, timeout_seconds: float) -> None:
    """Export Analysis View threats through the visible TMT UI."""
    if not _analysis_view_ready(window):
        raise HarnessFailure(
            "Analysis View was not confirmed before exporting threats",
            EXIT_VALIDATION_FAILURE,
        )
    export = _find_control(
        window,
        r"^Export Csv$",
        {"Button", "MenuItem", "SplitButton"},
    )
    export.click_input()
    _save_dialog_path(window.process_id(), destination, timeout_seconds)


def save_model_as(window: Any, destination: Path, timeout_seconds: float) -> None:
    """Save the working model to a new path through the TMT UI."""
    _, send_keys, _ = _load_pywinauto()
    window.set_focus()
    send_keys("^+s")
    _save_dialog_path(window.process_id(), destination, timeout_seconds)


def save_current_model(
    window: Any,
    model_path: Path,
    timeout_seconds: float,
) -> None:
    """Save the harness-owned working copy without opening a file dialog."""
    _, send_keys, _ = _load_pywinauto()
    before_hash = sha256_file(model_path)
    dirty_before = "*" in _window_title(window)

    def wait_for_write(seconds: float) -> bool:
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            if model_path.is_file() and sha256_file(model_path) != before_hash:
                return True
            time.sleep(0.2)
        return False

    stage_timeout = max(1.0, timeout_seconds / 3)
    try:
        save = _find_control(window, r"^Save$", {"Button", "MenuItem"})
        waiter = getattr(save, "wait", None)
        if waiter is not None:
            waiter("enabled", timeout=stage_timeout)
        save.click_input()
        if wait_for_write(stage_timeout):
            return
        if not dirty_before and "*" not in _window_title(window):
            return
        invoker = getattr(save, "invoke", None)
        if invoker is not None:
            invoker()
            if wait_for_write(stage_timeout):
                return
            if not dirty_before and "*" not in _window_title(window):
                return
    except Exception:  # pragma: no cover - native control boundary
        pass
    window.set_focus()
    send_keys("^s")
    if wait_for_write(stage_timeout):
        return
    if not dirty_before and "*" not in _window_title(window):
        return
    raise HarnessFailure(
        "TMT did not save the template-upgraded working copy",
        EXIT_AUTOMATION_TIMEOUT,
    )


def close_owned_process(process: subprocess.Popen[bytes]) -> None:
    """Close only the process launched by this harness."""
    if process.poll() is not None:
        return
    process.terminate()
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=10)
    _emit_operator_notice(f"Closed harness-owned TMT process PID {process.pid}")


def _read_csv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        return sorted(
            (
                {key.strip(): value.strip() for key, value in row.items()}
                for row in reader
            ),
            key=lambda row: json.dumps(row, sort_keys=True),
        )


def compare_csv_exports(before_path: Path, after_path: Path) -> bool:
    """Compare normalized exported rows across save and reopen."""
    return _read_csv(before_path) == _read_csv(after_path)


def validate_exported_interactions(path: Path) -> None:
    """Reject native threat exports containing deleted interaction links."""
    rows = _read_csv(path)
    deleted_rows = [
        row
        for row in rows
        if str(row.get("Interaction", "")).strip().casefold() == "deleted"
    ]
    if deleted_rows:
        raise HarnessFailure(
            f"TMT exported {len(deleted_rows)} threats with Deleted interactions",
            EXIT_VALIDATION_FAILURE,
        )


def _find_modal_window(window: Any, title: str) -> Any | None:
    return next(
        (
            candidate
            for candidate in _modal_windows(window)
            if _window_title(candidate).casefold() == title.casefold()
        ),
        None,
    )


def _checkbox_state(control: Any) -> bool:
    try:
        return bool(control.get_toggle_state())
    except Exception as exc:
        raise HarnessFailure(
            "Unable to inspect the stale-threat checkbox",
            EXIT_VALIDATION_FAILURE,
        ) from exc


def _set_stale_threat_policy(conversion_window: Any, delete_stale: bool) -> None:
    checkbox = _find_control(
        conversion_window,
        r"delete stale threats",
        {"CheckBox"},
    )
    if _checkbox_state(checkbox) != delete_stale:
        checkbox.click_input()
    if _checkbox_state(checkbox) != delete_stale:
        raise HarnessFailure(
            "Unable to set the stale-threat deletion policy",
            EXIT_VALIDATION_FAILURE,
        )


def _wait_for_modal_close(
    window: Any,
    title: str,
    timeout_seconds: float,
) -> None:
    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline:
        if _find_modal_window(window, title) is None:
            return
        time.sleep(0.2)
    raise HarnessFailure(
        f"{title} did not close",
        EXIT_AUTOMATION_TIMEOUT,
    )


def _wait_for_modal_window(
    window: Any,
    title: str,
    timeout_seconds: float,
) -> Any:
    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline:
        modal = _find_modal_window(window, title)
        if modal is not None:
            return modal
        time.sleep(0.2)
    raise HarnessFailure(
        f"Expected modal did not appear: {title}",
        EXIT_AUTOMATION_TIMEOUT,
    )


def _handle_template_conversion(
    window: Any,
    bundle: EvidenceBundle,
    *,
    policy: str,
    delete_stale: bool,
    timeout_seconds: float,
) -> str | None:
    conversion_window = _find_modal_window(
        window,
        TEMPLATE_CONVERSION_MODAL_TITLE,
    )
    if conversion_window is None:
        return None

    bundle.write_uia_tree(
        build_uia_tree(conversion_window),
        "template-conversion.txt",
    )
    capture_window_screenshot(
        conversion_window,
        bundle.path("screenshots/template-conversion.png"),
    )
    if policy == "fail":
        raise HarnessFailure(
            "A newer template is available; select an explicit template upgrade policy",
            EXIT_UNEXPECTED_MODAL,
        )

    _set_stale_threat_policy(conversion_window, delete_stale)
    button_name = "Yes" if policy == "apply" else "No"
    button = _find_control(
        conversion_window,
        rf"^{button_name}$",
        {"Button"},
    )
    button.click_input()
    result = "applied" if policy == "apply" else "declined"
    if policy == "decline":
        _wait_for_modal_close(
            window,
            TEMPLATE_CONVERSION_MODAL_TITLE,
            timeout_seconds,
        )
    bundle.write_action_log(
        f"Template conversion {result}; delete_stale_threats={delete_stale}"
    )
    return result


def _capture_modal(
    window: Any,
    bundle: EvidenceBundle,
    *,
    template_upgrade_policy: str = "fail",
    delete_stale_threats: bool = False,
    timeout_seconds: float = DEFAULT_TIMEOUT_SECONDS,
) -> str | None:
    conversion_result = _handle_template_conversion(
        window,
        bundle,
        policy=template_upgrade_policy,
        delete_stale=delete_stale_threats,
        timeout_seconds=timeout_seconds,
    )
    if conversion_result == "applied":
        return conversion_result
    modal = detect_modal_dialog(window)
    if not modal:
        return conversion_result
    modal_windows = _modal_windows(window)
    capture_target = modal_windows[0] if modal_windows else window
    bundle.write_uia_tree(
        build_uia_tree(capture_target),
        "unexpected-modal.txt",
    )
    try:
        capture_window_screenshot(
            capture_target,
            bundle.path("screenshots/unexpected-modal.png"),
        )
    except HarnessFailure as exc:
        bundle.write_action_log(str(exc))
    if LICENSE_MODAL_TITLE.lower() in modal.lower():
        raise HarnessFailure(
            "Human acceptance of the Microsoft Threat Modeling Tool license "
            "terms is required",
            EXIT_UNEXPECTED_MODAL,
        )
    raise HarnessFailure(f"Unexpected modal: {modal}", EXIT_UNEXPECTED_MODAL)


def _validate_candidate(
    *,
    executable: Path,
    input_model: Path,
    workspace: Path,
    bundle: EvidenceBundle,
    mode: str,
    timeout_seconds: float,
    expected_threat_count: int | None,
    template_upgrade_policy: str,
    delete_stale_threats: bool,
    capture_feedback_surfaces: bool = False,
    require_feedback_evidence: bool = False,
    feedback_surface_id_by_guid: dict[str, str] | None = None,
    feedback_node_id_by_guid: dict[str, dict[str, str]] | None = None,
    feedback_semantic_surfaces: dict[str, dict[str, Any]] | None = None,
) -> dict[str, Any]:
    saved_model = workspace / f"saved-{input_model.name}"
    working_model = saved_model
    shutil.copy2(input_model, working_model)
    process: subprocess.Popen[bytes] | None = None
    reopened_process: subprocess.Popen[bytes] | None = None
    try:
        with bundle.action("launch-initial"):
            process = launch_tmt_process(executable, working_model)
            window = find_tmt_window(process, timeout_seconds)
        conversion_result = _capture_modal(
            window,
            bundle,
            template_upgrade_policy=template_upgrade_policy,
            delete_stale_threats=delete_stale_threats,
            timeout_seconds=timeout_seconds,
        )
        if conversion_result == "applied":
            window = wait_for_analysis_window(process, timeout_seconds)
        capture_window_screenshot(window, bundle.path("screenshots/initial-open.png"))
        bundle.write_uia_tree(build_uia_tree(window), "initial-open.txt")
        if mode == "probe":
            return {"working_model": str(working_model), "probe": "passed"}

        if mode == "calibration-smoke":
            with bundle.action("calibration-smoke-capture"):
                smoke_payloads = _capture_feedback_surface_evidence(
                    window=window,
                    bundle=bundle,
                    model_path=working_model,
                    require_feedback_evidence=require_feedback_evidence,
                    surface_id_by_guid=feedback_surface_id_by_guid,
                    semantic_surfaces=feedback_semantic_surfaces,
                    calibration_context=None,
                    surface_limit=1,
                )
            calibration = _build_layout_calibration_contract(smoke_payloads)
            if calibration is None:
                raise HarnessFailure(
                    "Calibration smoke captured no Diagram pane evidence",
                    EXIT_VALIDATION_FAILURE,
                )
            tm7_visual_feedback._validate_layout_calibration_v1(calibration)
            bundle.write_summary(
                {
                    "layout_calibration_v1": calibration,
                    "surfaces": smoke_payloads,
                },
                "calibration-smoke.json",
            )
            return {
                "working_model": str(working_model),
                "calibration_smoke": "passed",
                "layout_calibration_v1": calibration,
                "surfaces": smoke_payloads,
            }

        surface_payloads: list[dict[str, Any]] = []
        surface_metrics: list[dict[str, Any]] = []
        evidence_complete = True
        if capture_feedback_surfaces:
            surface_payloads = _capture_feedback_surface_evidence(
                window=window,
                bundle=bundle,
                model_path=working_model,
                require_feedback_evidence=require_feedback_evidence,
                surface_id_by_guid=feedback_surface_id_by_guid,
                semantic_surfaces=feedback_semantic_surfaces,
                calibration_context=None,
            )
            surface_metrics = _derive_feedback_surface_metrics(
                surface_payloads=surface_payloads,
                bundle=bundle,
                candidate_model_path=working_model,
                surface_id_by_guid=feedback_surface_id_by_guid,
                node_id_by_guid=feedback_node_id_by_guid,
                semantic_surfaces=feedback_semantic_surfaces,
            )
            evidence_complete = (
                not require_feedback_evidence
                or not capture_feedback_surfaces
                or (
                    bool(surface_metrics)
                    and len(surface_metrics) == len(surface_payloads)
                    and all(
                        bool(metric.get("capture_complete"))
                        for metric in surface_metrics
                    )
                )
            )

        with bundle.action("open-analysis-view"):
            window = _call_analysis_view_handler(
                open_analysis_view,
                window,
                timeout_seconds=timeout_seconds,
                modal_handler=lambda current_window: _capture_modal(
                    current_window,
                    bundle,
                    template_upgrade_policy=template_upgrade_policy,
                    delete_stale_threats=delete_stale_threats,
                    timeout_seconds=timeout_seconds,
                ),
                process=process,
                bundle=bundle,
            )
        capture_diagnostic_screenshot(
            window,
            bundle.path("screenshots/analysis-view.png"),
            bundle,
        )
        bundle.write_uia_tree(build_uia_tree(window), "analysis-view.txt")

        before_csv = bundle.path("exports/before-save.csv")
        with bundle.action("export-before-save"):
            export_threat_csv(window, before_csv, timeout_seconds)
        validate_exported_interactions(before_csv)
        before_summary = collect_semantic_summary(working_model)
        bundle.write_summary(before_summary, "before-save.json")

        with bundle.action("save-workspace-copy"):
            save_current_model(window, saved_model, timeout_seconds)
        capture_diagnostic_screenshot(
            window,
            bundle.path("screenshots/post-save.png"),
            bundle,
        )
        close_owned_process(process)
        process = None

        with bundle.action("launch-reopen"):
            reopened_process = launch_tmt_process(executable, saved_model)
            reopened_window = find_tmt_window(reopened_process, timeout_seconds)
        _capture_modal(
            reopened_window,
            bundle,
            template_upgrade_policy=(
                "decline" if template_upgrade_policy == "decline" else "fail"
            ),
            delete_stale_threats=delete_stale_threats,
            timeout_seconds=timeout_seconds,
        )
        with bundle.action("reopen-analysis-view"):
            reopened_window = _call_analysis_view_handler(
                open_analysis_view,
                reopened_window,
                timeout_seconds=timeout_seconds,
                modal_handler=lambda current_window: _capture_modal(
                    current_window,
                    bundle,
                    template_upgrade_policy=(
                        "decline" if template_upgrade_policy == "decline" else "fail"
                    ),
                    delete_stale_threats=delete_stale_threats,
                    timeout_seconds=timeout_seconds,
                ),
                process=reopened_process,
                bundle=bundle,
            )
        capture_diagnostic_screenshot(
            reopened_window,
            bundle.path("screenshots/reopen-analysis-view.png"),
            bundle,
        )
        bundle.write_uia_tree(build_uia_tree(reopened_window), "reopen-analysis.txt")

        after_csv = bundle.path("exports/after-reopen.csv")
        with bundle.action("export-after-reopen"):
            export_threat_csv(reopened_window, after_csv, timeout_seconds)
        validate_exported_interactions(after_csv)
        after_summary = collect_semantic_summary(saved_model)
        bundle.write_summary(after_summary, "after-reopen.json")

        if (
            expected_threat_count is not None
            and before_summary["instance_count"] != expected_threat_count
        ):
            raise HarnessFailure(
                f"Expected {expected_threat_count} instances before save, found "
                f"{before_summary['instance_count']}",
                EXIT_VALIDATION_FAILURE,
            )
        if before_summary["instances"] != after_summary["instances"]:
            raise HarnessFailure(
                "Threat identities changed across save and reopen",
                EXIT_VALIDATION_FAILURE,
            )
        for field in ("drawing_surface_hash", "knowledge_base_hash"):
            if before_summary[field] != after_summary[field]:
                raise HarnessFailure(
                    f"{field} changed across save and reopen",
                    EXIT_VALIDATION_FAILURE,
                )
        if not compare_csv_exports(before_csv, after_csv):
            raise HarnessFailure(
                "Threat CSV exports differ across save and reopen",
                EXIT_VALIDATION_FAILURE,
            )
        return {
            "working_model": str(working_model),
            "saved_model": str(saved_model),
            "input_sha256": sha256_file(input_model),
            "saved_sha256": sha256_file(saved_model),
            "before_summary": before_summary,
            "after_summary": after_summary,
            "surface_metrics": surface_metrics,
            "surface_payloads": surface_payloads,
            "evidence_complete": evidence_complete,
        }
    finally:
        if process is not None:
            close_owned_process(process)
        if reopened_process is not None:
            close_owned_process(reopened_process)


def _validate_embedded_type_membership(summary: dict[str, Any]) -> None:
    type_ids = set(summary.get("knowledge_base_type_ids") or [])
    referenced = {
        str(instance.get("type_id") or "")
        for instance in summary.get("instances") or []
    }
    missing = sorted(referenced - type_ids)
    if missing:
        raise HarnessFailure(
            "Saved threats reference types missing from the upgraded template: "
            + ", ".join(missing),
            EXIT_VALIDATION_FAILURE,
        )


def _publish_upgraded_model(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_name(f".{destination.name}.tmp")
    try:
        shutil.copy2(source, temporary)
        os.replace(temporary, destination)
    finally:
        temporary.unlink(missing_ok=True)


def _write_tm7_root_atomic(root: ET.Element, destination: Path) -> None:
    temporary = destination.with_name(f".{destination.name}.compose.tmp")
    try:
        with tm7_threat_contract.tm7_serialization_namespaces(root):
            ET.ElementTree(root).write(
                temporary,
                encoding="utf-8",
                xml_declaration=True,
            )
        _parse_xml(temporary)
        os.replace(temporary, destination)
    finally:
        temporary.unlink(missing_ok=True)


def restore_custom_threat_types(source_model: Path, target_model: Path) -> int:
    """Restore deterministic custom threat types after native template upgrade."""
    source_root = _parse_xml(source_model)
    target_root = _parse_xml(target_model)
    source_types = source_root.find(".//{*}ThreatTypes")
    target_types = target_root.find(".//{*}ThreatTypes")
    if source_types is None or target_types is None:
        raise HarnessFailure(
            "Unable to locate embedded ThreatTypes for template composition",
            EXIT_VALIDATION_FAILURE,
        )

    existing_ids = {
        _text(threat_type, "Id")
        for threat_type in target_types.findall("{*}ThreatType")
        if _text(threat_type, "Id")
    }
    restored = 0
    for threat_type in source_types.findall("{*}ThreatType"):
        type_id = _text(threat_type, "Id")
        if not type_id.startswith("THC-") or type_id in existing_ids:
            continue
        target_types.append(copy.deepcopy(threat_type))
        existing_ids.add(type_id)
        restored += 1

    if restored:
        _write_tm7_root_atomic(target_root, target_model)
    return restored


def _upgrade_template_candidate(
    *,
    executable: Path,
    input_model: Path,
    output_model: Path,
    workspace: Path,
    bundle: EvidenceBundle,
    timeout_seconds: float,
    expected_threat_count: int | None,
    expected_custom_type_count: int | None,
    delete_stale_threats: bool,
) -> dict[str, Any]:
    working_model = workspace / input_model.name
    shutil.copy2(input_model, working_model)
    process: subprocess.Popen[bytes] | None = None
    reopened_process: subprocess.Popen[bytes] | None = None
    try:
        with bundle.action("launch-template-upgrade"):
            process = launch_tmt_process(executable, working_model)
            window = find_tmt_window(process, timeout_seconds)
        with bundle.action("wait-for-template-conversion"):
            _wait_for_modal_window(
                window,
                TEMPLATE_CONVERSION_MODAL_TITLE,
                timeout_seconds,
            )
        conversion_result = _capture_modal(
            window,
            bundle,
            template_upgrade_policy="apply",
            delete_stale_threats=delete_stale_threats,
            timeout_seconds=timeout_seconds,
        )
        if conversion_result != "applied":
            raise HarnessFailure(
                "Template upgrade mode requires a newer template prompt",
                EXIT_VALIDATION_FAILURE,
            )

        with bundle.action("wait-for-upgraded-model"):
            window = wait_for_analysis_window(process, timeout_seconds)
        bundle.write_uia_tree(
            build_uia_tree(window),
            "upgraded-model-ready.txt",
        )

        capture_window_screenshot(
            window,
            bundle.path("screenshots/upgraded-model.png"),
        )
        bundle.write_uia_tree(
            build_uia_tree(window),
            "upgraded-model.txt",
        )
        with bundle.action("save-template-upgrade"):
            save_current_model(window, working_model, timeout_seconds)
        close_owned_process(process)
        process = None

        post_save_summary = collect_semantic_summary(working_model)
        bundle.write_summary(post_save_summary, "after-template-save.json")
        if (
            expected_threat_count is not None
            and post_save_summary["instance_count"] != expected_threat_count
        ):
            raise HarnessFailure(
                f"Expected {expected_threat_count} threats after template upgrade, "
                f"found {post_save_summary['instance_count']}",
                EXIT_VALIDATION_FAILURE,
            )
        _validate_embedded_type_membership(post_save_summary)
        if expected_custom_type_count is not None:
            custom_count = len(post_save_summary["custom_type_ids"])
            if custom_count != expected_custom_type_count:
                with bundle.action("restore-custom-threat-types"):
                    restored = restore_custom_threat_types(
                        input_model,
                        working_model,
                    )
                bundle.write_action_log(f"Restored {restored} custom threat types")
                post_save_summary = collect_semantic_summary(working_model)
                bundle.write_summary(
                    post_save_summary,
                    "after-custom-type-restore.json",
                )
            if len(post_save_summary["custom_type_ids"]) != expected_custom_type_count:
                raise HarnessFailure(
                    f"Expected {expected_custom_type_count} custom types after "
                    f"template composition, found "
                    f"{len(post_save_summary['custom_type_ids'])}",
                    EXIT_VALIDATION_FAILURE,
                )

        with bundle.action("launch-upgraded-reopen"):
            reopened_process = launch_tmt_process(executable, working_model)
            reopened_window = find_tmt_window(reopened_process, timeout_seconds)
        _capture_modal(
            reopened_window,
            bundle,
            template_upgrade_policy="fail",
            timeout_seconds=timeout_seconds,
        )
        capture_window_screenshot(
            reopened_window,
            bundle.path("screenshots/upgraded-model-reopen.png"),
        )
        bundle.write_uia_tree(
            build_uia_tree(reopened_window),
            "upgraded-model-reopen.txt",
        )
        close_owned_process(reopened_process)
        reopened_process = None

        reopened_summary = collect_semantic_summary(working_model)
        bundle.write_summary(reopened_summary, "after-upgrade-reopen.json")
        _validate_embedded_type_membership(reopened_summary)
        if post_save_summary["instances"] != reopened_summary["instances"]:
            raise HarnessFailure(
                "Threat identities changed after upgraded-model reopen",
                EXIT_VALIDATION_FAILURE,
            )
        for field in ("drawing_surface_hash", "knowledge_base_hash"):
            if post_save_summary[field] != reopened_summary[field]:
                raise HarnessFailure(
                    f"{field} changed after upgraded-model reopen",
                    EXIT_VALIDATION_FAILURE,
                )
        _publish_upgraded_model(working_model, output_model)
        return {
            "input_model": str(input_model),
            "upgraded_model": str(output_model),
            "input_sha256": sha256_file(input_model),
            "upgraded_sha256": sha256_file(output_model),
            "delete_stale_threats": delete_stale_threats,
            "post_save_summary": post_save_summary,
            "reopened_summary": reopened_summary,
        }
    finally:
        if process is not None:
            close_owned_process(process)
        if reopened_process is not None:
            close_owned_process(reopened_process)


def _status_payload(
    *,
    result: str,
    exit_code: int,
    message: str,
    bundle: EvidenceBundle,
    manifest: dict[str, Any],
    agent_review: dict[str, Any] | None = None,
) -> dict[str, Any]:
    files = sorted(
        str(path.relative_to(bundle.evidence_dir)).replace("\\", "/")
        for path in bundle.evidence_dir.rglob("*")
        if path.is_file()
    )
    payload: dict[str, Any] = {
        "result": result,
        "exit_code": exit_code,
        "message": message,
        "last_successful_action": bundle.last_action,
        "required_tmt_version": manifest["required_tmt_version"],
        "observed_tmt_version": manifest.get("observed_tmt_version"),
        "evidence_schema_version": EVIDENCE_SCHEMA_VERSION,
        "evidence_files": files,
    }
    # The agent_review block is written only at the feedback-loop resolution
    # site; early returns and run_harness paths never provide it, so they
    # gain no new key.
    if agent_review is not None:
        payload["agent_review"] = agent_review
    return payload


def _validate_feedback_loop_args(
    *,
    feedback_loop: bool,
    spec_path: Path | None,
    overlay_output: Path | None,
    max_iterations: int,
) -> None:
    """Validate feedback-loop options before any discovery or process launch."""
    if not feedback_loop:
        return
    if spec_path is None:
        raise HarnessFailure(
            "feedback-loop requires --spec",
            EXIT_ERROR,
        )
    if overlay_output is None:
        raise HarnessFailure(
            "feedback-loop requires --overlay-output",
            EXIT_ERROR,
        )
    if not 1 <= max_iterations <= 3:
        raise HarnessFailure(
            "--max-iterations must be between 1 and 3",
            EXIT_ERROR,
        )


def _build_fallback_generator_model(spec: dict[str, Any]) -> dict[str, Any]:
    """Create a minimal surface model from the spec when strict generation fails."""
    surfaces: list[dict[str, Any]] = []
    representations = spec.get("representations") or {}
    for representation in (
        list(representations.get("context_diagrams") or [])
        + list(representations.get("functional_scenarios") or [])
        + list(representations.get("operational_views") or [])
    ):
        if not isinstance(representation, dict):
            continue
        surface_id = str(representation.get("id") or representation.get("name") or "")
        if not surface_id:
            continue
        elements: list[dict[str, Any]] = []
        for element in representation.get("elements") or []:
            if not isinstance(element, dict):
                continue
            element_id = str(element.get("id", "")).strip()
            if element_id:
                elements.append({"id": element_id})
        flows: list[dict[str, Any]] = []
        for flow in representation.get("flows") or []:
            if not isinstance(flow, dict):
                continue
            flow_id = str(flow.get("id", "")).strip()
            if flow_id:
                flows.append({"id": flow_id})
        surfaces.append(
            {
                "id": surface_id,
                "elements": elements,
                "flows": flows,
                "trust_zones": [],
            }
        )
    return {"surfaces": surfaces}


def _capture_feedback_surface_evidence(
    *,
    window: Any,
    bundle: EvidenceBundle,
    model_path: Path,
    require_feedback_evidence: bool,
    surface_id_by_guid: dict[str, str] | None = None,
    semantic_surfaces: dict[str, dict[str, Any]] | None = None,
    calibration_context: dict[str, Any] | None = None,
    surface_limit: int | None = None,
) -> list[dict[str, Any]]:
    """Capture pane-scoped evidence for each expected drawing surface."""
    surfaces = read_expected_surfaces(model_path)
    if surface_limit is not None:
        surfaces = surfaces[: max(0, int(surface_limit))]
    if not surfaces:
        return []
    tabs = materialize_surface_tabs(window, len(surfaces))
    # A visible tab per surface is not required, because TMT clips its tab
    # strip and activation falls back to the document menu. Missing evidence
    # is caught per surface below, where a failure names the surface it
    # belongs to instead of reporting an unactionable tab count.
    if require_feedback_evidence and not tabs:
        raise HarnessFailure(
            "Strict feedback evidence requires at least one surface tab; found 0",
            EXIT_VALIDATION_FAILURE,
        )
    payloads: list[dict[str, Any]] = []
    surface_id_by_guid = surface_id_by_guid or {}
    semantic_surfaces = semantic_surfaces or {}
    for surface in surfaces:
        semantic_surface_id = surface_id_by_guid.get(
            surface.surface_guid,
            surface.surface_id,
        )
        layout_metadata = semantic_surfaces.get(semantic_surface_id, {}).get(
            "layout_metadata",
            {},
        )
        try:
            activate_surface_tab(window, surface, tabs)
            payloads.append(
                capture_surface_evidence(
                    window,
                    bundle,
                    surface,
                    model_path=model_path,
                    require_feedback_evidence=require_feedback_evidence,
                    scroll_extent_ratio_x=float(
                        layout_metadata.get("scroll_extent_ratio_x", 1.0) or 1.0
                    ),
                    scroll_extent_ratio_y=float(
                        layout_metadata.get("scroll_extent_ratio_y", 1.0) or 1.0
                    ),
                    viewport_target=tuple(
                        float(item)
                        for item in (layout_metadata.get("viewport_target") or [])
                    )
                    if isinstance(layout_metadata.get("viewport_target"), list)
                    and len(layout_metadata.get("viewport_target", [])) == 4
                    else None,
                    pane_rect=layout_metadata.get("pane_rect")
                    if isinstance(layout_metadata.get("pane_rect"), dict)
                    else None,
                    calibration_context=calibration_context,
                )
            )
        except HarnessFailure:
            if require_feedback_evidence:
                raise
    return payloads


def _build_layout_calibration_contract(
    surface_payloads: list[dict[str, Any]],
    *,
    calibration_context: dict[str, Any] | None = None,
) -> dict[str, Any] | None:
    """Create a same-run layout calibration contract for the feedback manifest."""
    if not surface_payloads:
        return None
    payload = surface_payloads[0]
    pane_rect = payload.get("pane_rect") or (
        calibration_context.get("pane_rect") if calibration_context else None
    )
    if isinstance(pane_rect, dict):
        rect = [
            int(pane_rect.get("left", 0) or 0),
            int(pane_rect.get("top", 0) or 0),
            int(pane_rect.get("width", 0) or 0),
            int(pane_rect.get("height", 0) or 0),
        ]
    elif isinstance(pane_rect, (list, tuple)) and len(pane_rect) == 4:
        rect = [int(item) for item in pane_rect]
    else:
        rect = [0, 0, 0, 0]
    viewport_target = payload.get("viewport_target") or (
        calibration_context.get("viewport_target") if calibration_context else None
    )
    screenshot_dimensions = payload.get("screenshot_dimensions") or (
        calibration_context.get("screenshot_dimensions")
        if calibration_context
        else None
    )
    crop_dimensions = payload.get("crop_dimensions") or (
        calibration_context.get("crop_dimensions") if calibration_context else None
    )
    if isinstance(viewport_target, (list, tuple)) and len(viewport_target) == 4:
        viewport = [float(item) for item in viewport_target]
    else:
        viewport = [0.0, 0.0, 1200.0, 800.0]
    plane_rect_width = max(0, rect[2])
    plane_rect_height = max(0, rect[3])
    resolved_screenshot_dimensions = {
        "width": int(screenshot_dimensions.get("width", 0) or 0)
        if isinstance(screenshot_dimensions, dict)
        else 0,
        "height": int(screenshot_dimensions.get("height", 0) or 0)
        if isinstance(screenshot_dimensions, dict)
        else 0,
    }
    resolved_crop_dimensions = {
        "width": int(crop_dimensions.get("width", 0) or 0)
        if isinstance(crop_dimensions, dict)
        else 0,
        "height": int(crop_dimensions.get("height", 0) or 0)
        if isinstance(crop_dimensions, dict)
        else 0,
    }
    pane_measured = plane_rect_width > 0 and plane_rect_height > 0
    screenshot_measured = (
        resolved_screenshot_dimensions["width"] > 0
        and resolved_screenshot_dimensions["height"] > 0
    )
    crop_measured = (
        resolved_crop_dimensions["width"] > 0 and resolved_crop_dimensions["height"] > 0
    )
    consistent = (
        pane_measured
        and screenshot_measured
        and crop_measured
        and bool(payload.get("scroll_coverage_complete", False))
        and bool(payload.get("scroll_restored", False))
    )
    failure_reason = None if consistent else "strict evidence incomplete"
    if not pane_measured or not screenshot_measured or not crop_measured:
        failure_reason = "pane or crop dimensions unavailable"
    scroll_percentages = payload.get("scroll_percentages")
    if scroll_percentages is None and calibration_context:
        scroll_percentages = calibration_context.get("scroll_percentages")
    if isinstance(scroll_percentages, dict):
        resolved_scroll_percentages = {
            "horizontal": float(scroll_percentages.get("horizontal", 0.0) or 0.0),
            "vertical": float(scroll_percentages.get("vertical", 0.0) or 0.0),
        }
    else:
        resolved_scroll_percentages = {"horizontal": 0.0, "vertical": 0.0}
    viewport_width = max(0.0, float(viewport[2]) if len(viewport) > 2 else 0.0)
    viewport_height = max(0.0, float(viewport[3]) if len(viewport) > 3 else 0.0)
    effective_scale = {
        "x": 1.0,
        "y": 1.0,
    }
    if viewport_width > 0.0 and plane_rect_width > 0:
        effective_scale["x"] = plane_rect_width / viewport_width
    if viewport_height > 0.0 and plane_rect_height > 0:
        effective_scale["y"] = plane_rect_height / viewport_height
    return {
        "contract": "layout_calibration_v1",
        "scope": "same-run",
        "viewport_target": viewport,
        "pane_rect": rect,
        "scroll_percentages": resolved_scroll_percentages,
        "effective_scale": effective_scale,
        "screenshot_dimensions": {
            "width": resolved_screenshot_dimensions["width"]
            or max(0, plane_rect_width),
            "height": resolved_screenshot_dimensions["height"]
            or max(0, plane_rect_height),
        },
        "crop_dimensions": {
            "width": resolved_crop_dimensions["width"] or max(0, plane_rect_width),
            "height": resolved_crop_dimensions["height"] or max(0, plane_rect_height),
        },
        "confidence": {
            "pane_measured": pane_measured,
            "scroll_interface_found": bool(
                payload.get("scroll_tiles") or payload.get("scroll_coverage_complete")
            ),
            "consistent": consistent,
            "failure_reason": failure_reason,
        },
    }


def derive_render_scale(
    uia_text: str,
    model_rects: dict[str, tuple[float, float, float, float]],
) -> float | None:
    """Measure the zoom TMT applied, by comparing drawn size to model size.

    TMT renders the model faithfully but not at 1:1; a real run measured a
    uniform 1.5x. The pane rectangle is therefore screen pixels while every
    layout metric is model units, so comparing the two directly understates
    how much of the canvas the diagram consumes and hides content that is
    drawn past the right edge.

    Node names are the only stable join between the UIA tree and the model,
    and the ratio is taken from widths and heights rather than positions so
    that scroll offset and the toolbar band cancel out. Returns ``None`` when
    too few nodes match or the samples disagree, so callers fall back to
    treating the pane as model units rather than trusting a bad scale.
    """
    rendered: dict[str, tuple[float, float]] = {}
    for line in uia_text.splitlines():
        parts = line.split("|")
        if len(parts) < 8:
            continue
        _, control_type, automation_id, name = parts[:4]
        if control_type != "Custom" or automation_id:
            continue
        try:
            left, top, right, bottom = (float(value) for value in parts[4:8])
        except ValueError:
            continue
        width, height = right - left, bottom - top
        if width > 0.0 and height > 0.0:
            rendered[name] = (width, height)

    ratios: list[float] = []
    for name, (model_left, model_top, model_right, model_bottom) in model_rects.items():
        drawn = rendered.get(name)
        if drawn is None:
            continue
        model_width = model_right - model_left
        model_height = model_bottom - model_top
        if model_width > 0.0:
            ratios.append(drawn[0] / model_width)
        if model_height > 0.0:
            ratios.append(drawn[1] / model_height)

    if len(ratios) < 4:
        return None
    ratios.sort()
    median = ratios[len(ratios) // 2]
    if median <= 0.0:
        return None
    if max(abs(ratio - median) for ratio in ratios) > 0.05 * median:
        return None
    return median


def _derive_feedback_surface_metrics(
    *,
    surface_payloads: list[dict[str, Any]],
    bundle: EvidenceBundle,
    candidate_model_path: Path,
    surface_id_by_guid: dict[str, str] | None = None,
    node_id_by_guid: dict[str, dict[str, str]] | None = None,
    semantic_surfaces: dict[str, dict[str, Any]] | None = None,
) -> list[dict[str, Any]]:
    """Derive per-surface feedback metrics from native evidence snapshots."""
    try:
        parsed_model = generate_tm7.parse_hardened_xml(candidate_model_path)
    except Exception:  # pragma: no cover - parser fallback for malformed models
        parsed_model = {"elements": [], "flows": []}

    surface_id_by_guid = surface_id_by_guid or {}
    node_id_by_guid = node_id_by_guid or {}
    semantic_surfaces = semantic_surfaces or {}

    def surface_key(value: Any) -> str:
        return re.sub(r"[^a-z0-9]+", "-", str(value).lower()).strip("-")

    metrics: list[dict[str, Any]] = []
    for payload in surface_payloads:
        captured_surface_id = str(payload.get("surface_id", "")).strip()
        surface_guid = str(payload.get("surface_guid", "")).strip()
        surface_id = surface_id_by_guid.get(surface_guid, captured_surface_id)
        captured_surface_key = surface_key(payload.get("surface_name") or surface_id)
        semantic_surface = semantic_surfaces.get(surface_id, {})
        surface_nodes_by_guid = node_id_by_guid.get(surface_id, {})
        crop = payload.get("crop") or {}
        payload_geometry = payload.get("surface_geometry") or {}
        viewport = tm7_visual_feedback.ViewportBounds(
            left=int(crop.get("left", 0) or 0),
            top=int(crop.get("top", 0) or 0),
            width=int(crop.get("width", 0) or 0),
            height=int(crop.get("height", 0) or 0),
        )
        screenshot_path = bundle.evidence_dir / str(payload.get("screenshot_path", ""))
        image_metrics = tm7_visual_feedback.derive_image_metrics(
            screenshot_path,
            viewport,
        )

        def _coerce_rect(value: Any) -> tuple[float, float, float, float] | None:
            if not isinstance(value, (list, tuple)) or len(value) != 4:
                return None
            try:
                return tuple(float(item) for item in value)
            except (TypeError, ValueError):
                return None

        geometry_nodes: dict[str, tuple[float, float, float, float]] = {}
        boundary_rects: dict[str, tuple[float, float, float, float]] = {}
        connector_segments: list[
            tuple[str, str, tuple[float, float], tuple[float, float]]
        ] = []
        parsed_connector_routes: dict[str, dict[str, Any]] = {}
        for element in parsed_model.get("elements", []) or []:
            if surface_key(element.get("surface_id")) != captured_surface_key:
                continue
            element_guid = str(element.get("guid", "")).strip()
            parsed_element_id = str(element.get("id", "")).strip()
            element_id = surface_nodes_by_guid.get(
                element_guid,
                parsed_element_id or element_guid,
            )
            if not element_id:
                continue
            position = element.get("position") or {}
            left = float(position.get("left", 0.0) or 0.0)
            top = float(position.get("top", 0.0) or 0.0)
            width = float(position.get("width", 0.0) or 0.0)
            height = float(position.get("height", 0.0) or 0.0)
            if str(element.get("type_id", "")).strip() == "GE.TB.B":
                if not semantic_surface:
                    boundary_rects[element_id] = (
                        left,
                        top,
                        left + width,
                        top + height,
                    )
                continue
            geometry_nodes[element_id] = (left, top, left + width, top + height)
        for flow in parsed_model.get("flows", []) or []:
            if surface_key(flow.get("surface_id")) != captured_surface_key:
                continue
            position = flow.get("position") or {}
            source_x = float(position.get("source_x", 0.0) or 0.0)
            source_y = float(position.get("source_y", 0.0) or 0.0)
            target_x = float(position.get("target_x", 0.0) or 0.0)
            target_y = float(position.get("target_y", 0.0) or 0.0)
            handle_x = float(position.get("handle_x", 0.0) or 0.0)
            handle_y = float(position.get("handle_y", 0.0) or 0.0)
            source_guid = str(flow.get("source_guid", "") or "")
            target_guid = str(flow.get("target_guid", "") or "")
            parsed_flow_id = str(flow.get("id", "") or "").strip()
            if parsed_flow_id:
                parsed_connector_routes[parsed_flow_id] = {
                    "source_guid": source_guid,
                    "target_guid": target_guid,
                    "source_point": (source_x, source_y),
                    "handle_point": (handle_x, handle_y),
                    "target_point": (target_x, target_y),
                }
            connector_segments.extend(
                [
                    (
                        source_guid,
                        target_guid,
                        (source_x, source_y),
                        (handle_x, handle_y),
                    ),
                    (
                        source_guid,
                        target_guid,
                        (handle_x, handle_y),
                        (target_x, target_y),
                    ),
                ]
            )
        connector_segments = [
            (
                surface_nodes_by_guid.get(source_guid, source_guid),
                surface_nodes_by_guid.get(target_guid, target_guid),
                start,
                end,
            )
            for source_guid, target_guid, start, end in connector_segments
        ]
        semantic_elements = {
            str(element.get("id", "")): element
            for element in semantic_surface.get("elements", [])
            if isinstance(element, dict) and str(element.get("id", ""))
        }
        semantic_flows = {
            str(flow.get("id", "")): flow
            for flow in semantic_surface.get("flows", [])
            if isinstance(flow, dict) and str(flow.get("id", ""))
        }
        for element_id, element in semantic_elements.items():
            position = element.get("position") or {}
            left = float(position.get("left", 0.0) or 0.0)
            top = float(position.get("top", 0.0) or 0.0)
            width = float(position.get("width", 0.0) or 0.0)
            height = float(position.get("height", 0.0) or 0.0)
            rect = (left, top, left + width, top + height)
            if str(element.get("kind", "")).lower() == "trust_boundary_box":
                zone_id = str(element.get("trust_zone_id", "") or element_id)
                boundary_rects[zone_id] = rect
            elif element_id not in geometry_nodes:
                geometry_nodes[element_id] = rect
        connector_label_rects: dict[str, tuple[float, float, float, float]] = {}
        for flow_id, flow in semantic_flows.items():
            label_rect = flow.get("label_rect") or []
            if isinstance(label_rect, list) and len(label_rect) == 4:
                left, top, width, height = (float(value) for value in label_rect)
                connector_label_rects[flow_id] = (
                    left,
                    top,
                    left + width,
                    top + height,
                )
        boundary_label_rects = {
            zone_id: (left, top, right, min(bottom, top + 36.0))
            for zone_id, (left, top, right, bottom) in boundary_rects.items()
        }
        zone_membership = {
            element_id: str(element.get("trust_zone_id", "") or "")
            for element_id, element in semantic_elements.items()
            if str(element.get("kind", "")).lower() != "trust_boundary_box"
        }
        layout_roles = {
            element_id: str(element.get("layout_role", "") or "")
            for element_id, element in semantic_elements.items()
            if str(element.get("kind", "")).lower() != "trust_boundary_box"
        }
        zone_content_rects = {
            zone_id: (
                left,
                top,
                right,
                bottom,
            )
            for zone_id, (left, top, right, bottom) in boundary_rects.items()
        }
        zone_parent_map = {
            str(zone.get("id", "")): (
                str(zone.get("parent_trust_zone_id", "") or "") or None
            )
            for zone in semantic_surface.get("trust_zones", [])
            if isinstance(zone, dict) and str(zone.get("id", ""))
        }
        layout_metadata = semantic_surface.get("layout_metadata") or {}
        raw_bounds = layout_metadata.get("diagram_bounds") or []
        diagram_bounds = (
            tuple(float(value) for value in raw_bounds)
            if isinstance(raw_bounds, list) and len(raw_bounds) == 4
            else None
        )
        raw_viewport = layout_metadata.get("viewport") or []
        viewport_target = (
            tuple(float(value) for value in raw_viewport)
            if isinstance(raw_viewport, list) and len(raw_viewport) == 4
            else (0.0, 0.0, float(viewport.width), float(viewport.height))
        )
        # The captured pane is screen pixels while every layout metric is in
        # model units. Divide by the measured zoom so "does the diagram fit"
        # and "how much canvas does it fill" are asked in one coordinate
        # space. Without this the pane looks 1.5x wider than it is, so content
        # drawn past the right edge is reported as fitting.
        render_scale: float | None = None
        uia_relative_path = str(payload.get("uia_path", "") or "")
        if uia_relative_path and not raw_viewport:
            uia_file = bundle.evidence_dir / uia_relative_path
            try:
                uia_text = uia_file.read_text(encoding="utf-8")
            except OSError:
                uia_text = ""
            if uia_text:
                model_rects_by_name = {
                    str(element.get("name", "")): (
                        float((element.get("position") or {}).get("left", 0.0) or 0.0),
                        float((element.get("position") or {}).get("top", 0.0) or 0.0),
                        float((element.get("position") or {}).get("left", 0.0) or 0.0)
                        + float(
                            (element.get("position") or {}).get("width", 0.0) or 0.0
                        ),
                        float((element.get("position") or {}).get("top", 0.0) or 0.0)
                        + float(
                            (element.get("position") or {}).get("height", 0.0) or 0.0
                        ),
                    )
                    for element in semantic_elements.values()
                    if str(element.get("name", ""))
                    and str(element.get("kind", "")).lower() != "trust_boundary_box"
                }
                render_scale = derive_render_scale(uia_text, model_rects_by_name)
        if render_scale:
            viewport_target = (
                viewport_target[0],
                viewport_target[1],
                viewport_target[2] / render_scale,
                viewport_target[3] / render_scale,
            )
        payload_nodes = payload_geometry.get("node_rects") or {}
        for node_id, rect in payload_nodes.items():
            candidate_rect = _coerce_rect(rect)
            if candidate_rect is None:
                continue
            geometry_nodes[str(node_id)] = candidate_rect
        payload_connector_segments = payload_geometry.get("connector_segments") or []
        for segment in payload_connector_segments:
            if not isinstance(segment, (list, tuple)) or len(segment) != 4:
                continue
            source_id, target_id, start, end = segment
            if not isinstance(start, (list, tuple)) or len(start) != 2:
                continue
            if not isinstance(end, (list, tuple)) or len(end) != 2:
                continue
            connector_segments.append(
                (
                    str(source_id),
                    str(target_id),
                    (float(start[0]), float(start[1])),
                    (float(end[0]), float(end[1])),
                )
            )
        boundary_rects.update(
            {
                str(boundary_id): tuple(float(item) for item in rect)
                for boundary_id, rect in (
                    payload_geometry.get("boundary_rects") or {}
                ).items()
                if isinstance(rect, (list, tuple)) and len(rect) == 4
            }
        )
        boundary_label_rects.update(
            {
                str(label_id): tuple(float(item) for item in rect)
                for label_id, rect in (
                    payload_geometry.get("boundary_label_rects") or {}
                ).items()
                if isinstance(rect, (list, tuple)) and len(rect) == 4
            }
        )
        connector_label_rects.update(
            {
                str(label_id): tuple(float(item) for item in rect)
                for label_id, rect in (
                    payload_geometry.get("connector_label_rects") or {}
                ).items()
                if isinstance(rect, (list, tuple)) and len(rect) == 4
            }
        )
        layout_roles.update(
            {
                str(node_id): str(role)
                for node_id, role in (
                    payload_geometry.get("layout_roles") or {}
                ).items()
            }
        )
        zone_membership.update(
            {
                str(node_id): str(zone_id)
                for node_id, zone_id in (
                    payload_geometry.get("zone_membership") or {}
                ).items()
            }
        )
        zone_content_rects.update(
            {
                str(zone_id): tuple(float(item) for item in rect)
                for zone_id, rect in (
                    payload_geometry.get("zone_content_rects") or {}
                ).items()
                if isinstance(rect, (list, tuple)) and len(rect) == 4
            }
        )
        zone_parent_map.update(
            {
                str(zone_id): str(parent_id) if parent_id is not None else None
                for zone_id, parent_id in (
                    payload_geometry.get("zone_parent_map") or {}
                ).items()
            }
        )
        viewport_payload = payload_geometry.get("viewport_target")
        if isinstance(viewport_payload, (list, tuple)) and len(viewport_payload) == 4:
            viewport_target = tuple(float(item) for item in viewport_payload)
        diagram_bounds_payload = payload_geometry.get("diagram_bounds")
        if (
            isinstance(diagram_bounds_payload, (list, tuple))
            and len(diagram_bounds_payload) == 4
        ):
            diagram_bounds = tuple(float(item) for item in diagram_bounds_payload)
        outer_margin = float(payload_geometry.get("outer_margin", 24.0) or 24.0)
        selected_flow_ids = set(semantic_flows) | {
            str(flow_id)
            for flow_id in (payload_geometry.get("selected_flow_ids") or [])
        }
        expected_semantic_node_ids = set(geometry_nodes) | {
            str(node_id)
            for node_id in (payload_geometry.get("expected_semantic_node_ids") or [])
        }
        expected_semantic_flow_ids = set(semantic_flows) | {
            str(flow_id)
            for flow_id in (payload_geometry.get("expected_semantic_flow_ids") or [])
        }
        node_ids = sorted(geometry_nodes)
        node_id = node_ids[0] if node_ids else surface_id
        if geometry_nodes:
            size_values = [
                max(rect[2] - rect[0], rect[3] - rect[1])
                for rect in geometry_nodes.values()
            ]
            nominal_node_size = max(100.0, float(sum(size_values) / len(size_values)))
        else:
            nominal_node_size = 100.0
        connector_routes: dict[str, dict[str, Any]] = {
            flow_id: {
                "source_id": surface_nodes_by_guid.get(
                    route["source_guid"],
                    route["source_guid"],
                ),
                "target_id": surface_nodes_by_guid.get(
                    route["target_guid"],
                    route["target_guid"],
                ),
                "source_point": route["source_point"],
                "handle_point": route["handle_point"],
                "target_point": route["target_point"],
            }
            for flow_id, route in parsed_connector_routes.items()
        }
        for flow_id, route in (payload_geometry.get("connector_routes") or {}).items():
            if not isinstance(route, dict):
                continue
            normalized_route: dict[str, Any] = {
                "source_id": str(route.get("source_id", "")),
                "target_id": str(route.get("target_id", "")),
            }
            for point_key in ("source_point", "handle_point", "target_point"):
                point = route.get(point_key)
                if isinstance(point, (list, tuple)) and len(point) == 2:
                    normalized_route[point_key] = tuple(float(item) for item in point)
            if {"source_point", "target_point"} <= set(normalized_route):
                connector_routes[str(flow_id)] = normalized_route
        node_ranks = {
            str(node_id): int(rank)
            for node_id, rank in (payload_geometry.get("node_ranks") or {}).items()
        }
        branch_groups = {
            str(node_id): int(group_id)
            for node_id, group_id in (
                payload_geometry.get("branch_groups") or {}
            ).items()
        }
        orientation = str(payload_geometry.get("orientation") or "horizontal").lower()
        surface_geometry = tm7_visual_feedback.SurfaceGeometry(
            surface_id=surface_id,
            nominal_node_size=nominal_node_size,
            node_rects=geometry_nodes,
            connector_segments=connector_segments,
            boundary_rects=boundary_rects,
            boundary_label_rects=boundary_label_rects,
            connector_label_rects=connector_label_rects,
            layout_roles=layout_roles,
            zone_membership=zone_membership,
            zone_content_rects=zone_content_rects,
            zone_parent_map=zone_parent_map,
            viewport_target=viewport_target,
            diagram_bounds=diagram_bounds,
            outer_margin=outer_margin,
            selected_flow_ids=selected_flow_ids,
            expected_semantic_node_ids=expected_semantic_node_ids,
            expected_semantic_flow_ids=expected_semantic_flow_ids,
            connector_routes=connector_routes,
            node_ranks=node_ranks,
            branch_groups=branch_groups,
            orientation=orientation,
        )
        geometry_metrics = tm7_visual_feedback.derive_geometry_metrics(surface_geometry)
        affected_node_ids = geometry_metrics.get("affected_node_ids") or []
        if affected_node_ids:
            node_id = str(affected_node_ids[0])
        capture_scope = str(payload.get("capture_scope", "")).strip()
        annotation = str(payload.get("annotation", "")).strip()
        expected_identity = str(payload.get("surface_name", surface_id)).strip()
        capture_complete = (
            capture_scope == "pane"
            and viewport.width > 0
            and viewport.height > 0
            and bool(annotation)
            and bool(expected_identity)
            and (not semantic_surface.get("trust_zones") or bool(boundary_rects))
            and all(flow_id in connector_label_rects for flow_id in semantic_flows)
            and (not semantic_surface or diagram_bounds is not None)
            and bool(payload.get("scroll_coverage_complete", True))
        )
        capture_status = str(image_metrics.get("capture_status", "missing"))
        if not capture_complete:
            capture_status = "incomplete"
        metric = {
            **geometry_metrics,
            "surface_id": surface_id,
            "node_id": node_id,
            "evidence_path": str(screenshot_path.relative_to(bundle.evidence_dir))
            if screenshot_path.exists()
            else str(screenshot_path),
            "capture_status": capture_status,
            "severity": image_metrics.get("severity", "review"),
            "is_all_background": image_metrics.get("is_all_background", False),
            "viewport": image_metrics.get("viewport", {}),
            "capture_scope": capture_scope,
            "annotation": annotation,
            "surface_name": str(payload.get("surface_name", surface_id)).strip(),
            "expected_identity": expected_identity,
            "capture_complete": capture_complete,
            "scroll_tiles": list(payload.get("scroll_tiles") or []),
            "scroll_coverage_complete": bool(
                payload.get("scroll_coverage_complete", True)
            ),
            "surface_geometry": {
                "surface_id": surface_geometry.surface_id,
                "nominal_node_size": surface_geometry.nominal_node_size,
                "node_rects": {
                    key: [left, top, right, bottom]
                    for key, (
                        left,
                        top,
                        right,
                        bottom,
                    ) in surface_geometry.node_rects.items()
                },
                "connector_segments": [
                    [source_id, target_id, [start_x, start_y], [end_x, end_y]]
                    for source_id, target_id, (start_x, start_y), (
                        end_x,
                        end_y,
                    ) in surface_geometry.connector_segments
                ],
                "boundary_rects": {
                    boundary_id: [left, top, right, bottom]
                    for boundary_id, (
                        left,
                        top,
                        right,
                        bottom,
                    ) in surface_geometry.boundary_rects.items()
                },
                "boundary_label_rects": {
                    label_id: [left, top, right, bottom]
                    for label_id, (
                        left,
                        top,
                        right,
                        bottom,
                    ) in surface_geometry.boundary_label_rects.items()
                },
                "connector_label_rects": {
                    label_id: [left, top, right, bottom]
                    for label_id, (
                        left,
                        top,
                        right,
                        bottom,
                    ) in surface_geometry.connector_label_rects.items()
                },
                "layout_roles": dict(surface_geometry.layout_roles),
                "zone_membership": dict(surface_geometry.zone_membership),
                "zone_content_rects": {
                    zone_id: [left, top, right, bottom]
                    for zone_id, (
                        left,
                        top,
                        right,
                        bottom,
                    ) in surface_geometry.zone_content_rects.items()
                },
                "zone_parent_map": dict(surface_geometry.zone_parent_map),
                "viewport_target": list(surface_geometry.viewport_target)
                if surface_geometry.viewport_target is not None
                else None,
                "diagram_bounds": list(surface_geometry.diagram_bounds)
                if surface_geometry.diagram_bounds is not None
                else None,
                "outer_margin": surface_geometry.outer_margin,
                "selected_flow_ids": sorted(surface_geometry.selected_flow_ids),
                "expected_semantic_node_ids": sorted(
                    surface_geometry.expected_semantic_node_ids
                ),
                "expected_semantic_flow_ids": sorted(
                    surface_geometry.expected_semantic_flow_ids
                ),
                "connector_routes": {
                    flow_id: {
                        key: list(value) if isinstance(value, tuple) else value
                        for key, value in route.items()
                    }
                    for flow_id, route in surface_geometry.connector_routes.items()
                },
                "node_ranks": dict(surface_geometry.node_ranks),
                "branch_groups": dict(surface_geometry.branch_groups),
                "orientation": surface_geometry.orientation,
            },
        }
        density = "dense" if len(surface_geometry.selected_flow_ids) >= 6 else "simple"
        metric["density"] = density
        metric["findings"] = tm7_visual_feedback.derive_findings(
            metric,
            density=density,
        )
        metrics.append(metric)

        surface_slug = _evidence_slug(surface_id)
        bundle.write_json(f"surfaces/{surface_slug}/metrics.json", metric)
        bundle.write_json(f"surfaces/{surface_slug}/findings.json", metric["findings"])
    return metrics


def _evidence_slug(value: str) -> str:
    """Reduce a caller-supplied identifier to a single safe path segment.

    Only alphanumerics, hyphen, and underscore survive, so the result cannot
    form a traversal segment or an absolute path. Retaining `.` would allow an
    id of `..` to pass through intact.

    Args:
        value: Identifier taken from spec or model content.

    Returns:
        A non-empty, traversal-free path segment.
    """
    slug = re.sub(r"[^A-Za-z0-9_-]+", "-", value).strip("-")
    return slug or "surface"


def _build_feedback_overlay(
    *,
    spec_path: Path,
    candidate: dict[str, Any],
    overlay_context: tm7_visual_feedback.OverlayContext,
    iteration_id: int,
    spec_sha256: str,
    generator_profile: str,
    generator_profile_sha256: str,
    candidate_path: Path,
    ranking_key: tuple[Any, ...],
) -> dict[str, Any]:
    """Create a pending schema-v2 overlay from the selected feedback candidate."""
    if not isinstance(candidate, dict):
        raise ValueError("selected candidate must be a mapping")
    surface_id = str(candidate.get("surface_id", "")).strip()
    node_id = str(candidate.get("node_id", "")).strip()
    if not surface_id or not node_id:
        raise ValueError("selected candidate must include surface_id and node_id")
    if not isinstance(overlay_context, tm7_visual_feedback.OverlayContext):
        raise ValueError("overlay_context must be a valid OverlayContext")
    model_id = str(overlay_context.model_id or spec_path.stem or "tm7-model")
    overlay_id = f"overlay-{iteration_id:02d}"
    rule = candidate.get("rule")
    overlay_rule = candidate.get("overlay_rule")
    rule_collection = str(candidate.get("rule_collection", "node_rules"))
    zone_rules: list[dict[str, Any]] = []
    node_rules: list[dict[str, Any]] = []
    connector_rules: list[dict[str, Any]] = []
    surface_rules: list[dict[str, Any]] = []
    if isinstance(overlay_rule, dict) and overlay_rule:
        collections = {
            "zone_rules": zone_rules,
            "node_rules": node_rules,
            "connector_rules": connector_rules,
            "surface_rules": surface_rules,
        }
        if rule_collection not in collections:
            raise ValueError("selected candidate has an unknown rule collection")
        collections[rule_collection].append(dict(overlay_rule))
    elif isinstance(rule, dict) and rule:
        rule_node_id = str(rule.get("node_id") or "").strip()
        if rule_node_id != node_id:
            raise ValueError("selected candidate rule must target the ranked node")
        constraint = str(rule.get("constraint") or "").strip()
        if constraint == "relative_to":
            relative_to = str(rule.get("relative_to") or "").strip()
            if not relative_to or relative_to == node_id:
                raise ValueError("relative_to rules must target another node")
            available_nodes = overlay_context.surface_node_ids.get(surface_id, set())
            if relative_to not in available_nodes:
                raise ValueError("relative_to rules must target a known surface node")
        elif constraint not in {"position", "keep_route_clear"}:
            raise ValueError("selected candidate rule must use a supported constraint")
        left = float(rule.get("left", 0.0) or 0.0)
        top = float(rule.get("top", 0.0) or 0.0)
        node_rules = [
            {
                "surface_id": surface_id,
                "node_id": node_id,
                "layout_role": "connected",
                "absolute_position": {
                    "left": left,
                    "top": top,
                    "width": 100.0,
                    "height": 100.0,
                },
            }
        ]
    elif candidate.get("gate_failure_count") == 0:
        node_rules = []
    else:
        raise ValueError("selected candidate must include a real rule")
    surface_identity_fingerprint = tm7_visual_feedback._fingerprint(
        {
            "surface_ids": sorted(overlay_context.surface_ids),
            "surface_node_ids": {
                key: sorted(value)
                for key, value in sorted(overlay_context.surface_node_ids.items())
            },
        }
    )
    surface_zone_identity_fingerprint = tm7_visual_feedback._fingerprint(
        {
            "surface_ids": sorted(overlay_context.surface_ids),
            "surface_zone_ids": {
                key: sorted(value)
                for key, value in sorted(overlay_context.surface_zone_ids.items())
            },
        }
    )
    surface_flow_identity_fingerprint = tm7_visual_feedback._fingerprint(
        {
            "surface_ids": sorted(overlay_context.surface_ids),
            "surface_flow_ids": {
                key: sorted(value)
                for key, value in sorted(overlay_context.surface_flow_ids.items())
            },
        }
    )
    return {
        "schema_version": 2,
        "overlay_type": "tm7_layout_overlay",
        "model_id": model_id,
        "overlay_id": overlay_id,
        "applies_to": [
            {"surface_id": surface_id, "generator_profile": generator_profile}
        ],
        "zone_rules": zone_rules,
        "node_rules": node_rules,
        "connector_rules": connector_rules,
        "surface_rules": surface_rules,
        "provenance": {
            "evidence_ref": tm7_visual_feedback._normalize_path_reference(
                str(candidate_path), field_name="provenance.evidence_ref"
            ),
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "approval_state": "pending",
        },
        "invalidation": {
            "spec_fingerprint": spec_sha256,
            "generator_profile_fingerprint": generator_profile_sha256,
            "surface_identity_fingerprint": surface_identity_fingerprint,
            "surface_zone_identity_fingerprint": surface_zone_identity_fingerprint,
            "surface_flow_identity_fingerprint": surface_flow_identity_fingerprint,
        },
    }


def _build_overlay_seed(
    *,
    spec_path: Path,
    overlay_context: tm7_visual_feedback.OverlayContext,
    iteration_id: int,
    spec_sha256: str,
    generator_profile: str,
    generator_profile_sha256: str,
    evidence_dir: Path,
) -> dict[str, Any]:
    """Build a valid overlay carrying correct fingerprints and no rules.

    A stopped run publishes no populated overlay, which is deliberate: an
    accumulated overlay looks actionable while the run itself is blocked. That
    also left a reviewer with nothing to work from, because the five
    invalidation fingerprints are hashes over spec bytes and sorted model
    identity sets and cannot be authored by hand.

    This seed resolves that without weakening the guard. Replaying it changes
    no geometry, so it cannot be mistaken for a result, while its fingerprints
    are valid so a reviewer can add rules and replay. The empty collections are
    the signal that no automated correction was found; the run's stop reason
    stays in status.json alongside the evidence the seed points at.
    """
    if not isinstance(overlay_context, tm7_visual_feedback.OverlayContext):
        raise ValueError("overlay_context must be a valid OverlayContext")
    if not overlay_context.surface_ids:
        raise ValueError("overlay seed requires at least one captured surface")

    surface_identity_fingerprint = tm7_visual_feedback._fingerprint(
        {
            "surface_ids": sorted(overlay_context.surface_ids),
            "surface_node_ids": {
                key: sorted(value)
                for key, value in sorted(overlay_context.surface_node_ids.items())
            },
        }
    )
    surface_zone_identity_fingerprint = tm7_visual_feedback._fingerprint(
        {
            "surface_ids": sorted(overlay_context.surface_ids),
            "surface_zone_ids": {
                key: sorted(value)
                for key, value in sorted(overlay_context.surface_zone_ids.items())
            },
        }
    )
    surface_flow_identity_fingerprint = tm7_visual_feedback._fingerprint(
        {
            "surface_ids": sorted(overlay_context.surface_ids),
            "surface_flow_ids": {
                key: sorted(value)
                for key, value in sorted(overlay_context.surface_flow_ids.items())
            },
        }
    )
    return {
        "schema_version": 2,
        "overlay_type": "tm7_layout_overlay",
        "model_id": str(overlay_context.model_id or spec_path.stem or "tm7-model"),
        "overlay_id": f"overlay-seed-{iteration_id:02d}",
        # Every captured surface is addressable, so a reviewer can author a
        # rule for any of them without editing the fingerprinted identity.
        "applies_to": [
            {"surface_id": surface_id, "generator_profile": generator_profile}
            for surface_id in sorted(overlay_context.surface_ids)
        ],
        "zone_rules": [],
        "node_rules": [],
        "connector_rules": [],
        "surface_rules": [],
        "provenance": {
            "evidence_ref": tm7_visual_feedback._normalize_path_reference(
                str(evidence_dir), field_name="provenance.evidence_ref"
            ),
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "approval_state": "pending",
        },
        "invalidation": {
            "spec_fingerprint": spec_sha256,
            "generator_profile_fingerprint": generator_profile_sha256,
            "surface_identity_fingerprint": surface_identity_fingerprint,
            "surface_zone_identity_fingerprint": surface_zone_identity_fingerprint,
            "surface_flow_identity_fingerprint": surface_flow_identity_fingerprint,
        },
    }


def _build_agent_review_request(
    *,
    final_surface_metrics: list[dict[str, Any]],
    final_surface_payloads: list[dict[str, Any]],
    semantic_surfaces: dict[str, dict[str, Any]],
    published_overlay_path: Path | None,
    overlay_input: Path | None,
    bundle: EvidenceBundle,
) -> dict[str, Any] | None:
    """Build a self-sufficient per-surface review request for the agent.

    Carries model-coordinate geometry, screenshot and UIA paths, and the
    coordinate-translation constants an agent needs to author a correction
    without hand-parsing UI Automation trees. Returns None when no surface
    metrics are available.
    """
    payload_by_surface: dict[str, dict[str, Any]] = {
        str(p.get("surface_id", "")): p for p in final_surface_payloads
    }
    surfaces: list[dict[str, Any]] = []
    for metric in final_surface_metrics:
        surface_id = str(metric.get("surface_id", ""))
        if not surface_id:
            continue
        payload = payload_by_surface.get(surface_id, {})
        surface_guid = str(payload.get("surface_guid", "")).strip()
        if not surface_guid:
            surface_guid = generate_tm7._make_guid(f"surface:{surface_id}")
        surface_name = str(
            metric.get("surface_name", "")
            or (semantic_surfaces.get(surface_id) or {}).get("name", "")
            or surface_id
        )
        # uia_path lives on the surface payload, not the metric. The metric
        # carries no uia_path key and the manifest builder fills the gap with
        # "missing"; that sentinel must never be emitted here.
        uia_path = str(payload.get("uia_path") or "")
        geometry = metric.get("surface_geometry") or {}
        selected_flow_ids: list[str] = list(geometry.get("selected_flow_ids") or [])
        connector_routes = geometry.get("connector_routes") or {}
        connector_handles: dict[str, dict[str, float]] = {}
        for flow_id in sorted(selected_flow_ids):
            route = connector_routes.get(flow_id)
            if not isinstance(route, dict):
                continue
            handle = route.get("handle_point")
            if isinstance(handle, (list, tuple)) and len(handle) == 2:
                try:
                    connector_handles[flow_id] = {
                        "x": float(handle[0]),
                        "y": float(handle[1]),
                    }
                except (TypeError, ValueError):
                    # A handle that is not a numeric pair carries no geometry.
                    # The flow is omitted from the review request rather than
                    # published with a fabricated coordinate.
                    pass
        viewport_raw = geometry.get("viewport_target")
        viewport_target = (
            [float(v) for v in viewport_raw]
            if isinstance(viewport_raw, (list, tuple)) and len(viewport_raw) == 4
            else None
        )
        bounds_raw = geometry.get("diagram_bounds")
        diagram_bounds = (
            [float(v) for v in bounds_raw]
            if isinstance(bounds_raw, (list, tuple)) and len(bounds_raw) == 4
            else None
        )
        surface_slug = _evidence_slug(surface_id)
        surfaces.append(
            {
                "surface_id": surface_id,
                "surface_name": surface_name,
                "surface_guid": surface_guid,
                # evidence_path in the metric is the screenshot; renamed here
                # so callers never confuse it with the manifest capture_path.
                "screenshot_path": str(metric.get("evidence_path") or ""),
                "uia_path": uia_path,
                "metrics_path": f"surfaces/{surface_slug}/metrics.json",
                "node_rects": dict(geometry.get("node_rects") or {}),
                # These rectangles come from the generator's placement search,
                # not from what TMT renders. They predict where labels will
                # land given the current handle_point but are not authoritative.
                "predicted_connector_label_rects": dict(
                    geometry.get("connector_label_rects") or {}
                ),
                "connector_handles": connector_handles,
                "zone_content_rects": dict(geometry.get("zone_content_rects") or {}),
                "boundary_rects": dict(geometry.get("boundary_rects") or {}),
                "viewport_target": viewport_target,
                "diagram_bounds": diagram_bounds,
                "existing_findings": list(metric.get("findings") or []),
                "review_status": "pending",
            }
        )
    if not surfaces:
        return None
    # Relative path to the overlay file actually written, or null when no
    # overlay was published so the request cannot point at a stale file.
    seed_path_value: str | None = None
    if published_overlay_path is not None and published_overlay_path.is_file():
        try:
            seed_path_value = str(
                published_overlay_path.relative_to(bundle.evidence_dir)
            ).replace("\\", "/")
        except ValueError:
            # Overlay lives outside the evidence root; record the full path.
            seed_path_value = str(published_overlay_path).replace("\\", "/")
    return {
        "surfaces": surfaces,
        # The five defect classes no deterministic metric scores.
        "defect_classes": [
            "label-on-node collision",
            "label-on-label overlap",
            "unreadable or truncated label text",
            "connector routing through empty space",
            "visual crowding",
        ],
        # Inline so the request is self-sufficient without the reference doc.
        "coordinate_translation": (
            "Model coordinates are recoverable as (screen - offset) / 1.5 "
            "(uniform 1.5x zoom). TMT draws each connector label centred on "
            "its handle_point, not with its top-left corner there. "
            "handle_point is the only lever that reaches the renderer; "
            "label_offset feeds only the generator's internal placement "
            "search and produces no visible change when authored alone."
        ),
        "port_convention": (
            "An authored connector_rules entry requires non-empty "
            'source_port and target_port; the harness uses "auto" for both.'
        ),
        "overlay_seed_path": seed_path_value,
        "replay_command": None,
        # Replay depth: 0 on the initial run, 1 when --overlay-input was
        # supplied. Not a budget claim; the harness cannot see how many agent
        # rounds have run across separate invocations.
        "agent_round": 0 if overlay_input is None else 1,
    }


def _merge_accumulated_rule(
    accumulated_rules: list[dict[str, Any]],
    accumulated_surface_id: str | None,
    candidate: dict[str, Any],
) -> tuple[list[dict[str, Any]], str | None]:
    """Merge one typed rule into an all-surface cumulative overlay."""
    selected_rule = candidate.get("overlay_rule") or candidate.get("rule")
    if not isinstance(selected_rule, dict) or not selected_rule:
        return accumulated_rules, accumulated_surface_id
    selected_surface_id = str(candidate.get("surface_id", ""))
    target_type = str(candidate.get("target_type") or "node")
    target_id = str(
        candidate.get("target_id")
        or selected_rule.get("node_id")
        or selected_rule.get("zone_id")
        or selected_rule.get("flow_id")
        or selected_surface_id
    )
    constraint = str(
        candidate.get("constraint_type") or selected_rule.get("constraint") or "rule"
    )
    normalized_rules = [
        {
            **rule,
            "_surface_id": str(rule.get("_surface_id") or accumulated_surface_id or ""),
            "_target_type": str(rule.get("_target_type") or "node"),
            "_target_id": str(rule.get("_target_id") or rule.get("node_id") or ""),
            "_constraint": str(
                rule.get("_constraint") or rule.get("constraint") or "rule"
            ),
            "_rule_collection": str(rule.get("_rule_collection") or "node_rules"),
        }
        for rule in accumulated_rules
    ]
    merged_rules = [
        rule
        for rule in normalized_rules
        if not (
            str(rule.get("_surface_id", "")) == selected_surface_id
            and str(rule.get("_target_type", "")) == target_type
            and str(rule.get("_target_id", "")) == target_id
            and str(rule.get("_constraint", "")) == constraint
        )
    ]
    merged_rules.append(
        {
            **selected_rule,
            "_surface_id": selected_surface_id,
            "_target_type": target_type,
            "_target_id": target_id,
            "_constraint": constraint,
            "_rule_collection": str(candidate.get("rule_collection", "node_rules")),
        }
    )
    return merged_rules, selected_surface_id


def _apply_accumulated_rules(
    overlay: dict[str, Any],
    accumulated_rules: list[dict[str, Any]],
    *,
    generator_profile: str,
) -> None:
    """Apply cumulative internal rules to strict public overlay collections."""
    collection_names = (
        "zone_rules",
        "node_rules",
        "connector_rules",
        "surface_rules",
    )
    for collection_name in collection_names:
        overlay[collection_name] = []
    for internal_rule in accumulated_rules:
        collection_name = str(internal_rule.get("_rule_collection", "node_rules"))
        if collection_name not in collection_names:
            continue
        public_rule = {
            key: value
            for key, value in internal_rule.items()
            if not str(key).startswith("_") and key != "constraint"
        }
        if (
            collection_name == "node_rules"
            and "absolute_position" not in public_rule
            and "node_id" in public_rule
        ):
            public_rule = {
                "surface_id": str(internal_rule.get("_surface_id", "")),
                "node_id": str(public_rule["node_id"]),
                "layout_role": "connected",
                "absolute_position": {
                    "left": float(public_rule.get("left", 1.0)),
                    "top": float(public_rule.get("top", 1.0)),
                    "width": 100.0,
                    "height": 100.0,
                },
            }
        overlay[collection_name].append(public_rule)
    overlay.pop("rules", None)
    referenced_surfaces = sorted(
        {
            str(rule.get("_surface_id", ""))
            for rule in accumulated_rules
            if str(rule.get("_surface_id", ""))
        }
    )
    if not referenced_surfaces:
        return
    overlay["applies_to"] = [
        {
            "surface_id": surface_id,
            "generator_profile": generator_profile,
        }
        for surface_id in referenced_surfaces
    ]


def _build_semantic_identity_summary(summary: dict[str, Any]) -> dict[str, Any]:
    """Normalize topology and threat identities for candidate comparison."""
    return {
        "instance_count": int(summary.get("instance_count") or 0),
        "threat_count": int(
            summary.get("threat_count") or summary.get("instance_count") or 0
        ),
        "threat_identities": sorted(
            str(item).strip().lower()
            for item in (summary.get("threat_identities") or [])
            if str(item).strip()
        ),
        "element_identities": sorted(
            str(item).strip().lower()
            for item in (summary.get("element_identities") or [])
            if str(item).strip()
        ),
        "flow_identities": sorted(
            str(item).strip().lower()
            for item in (summary.get("flow_identities") or [])
            if str(item).strip()
        ),
    }


def _evaluate_semantic_regression(
    *,
    current_summary: dict[str, Any],
    baseline_summary: dict[str, Any],
) -> bool:
    """Reject candidates that change the semantic identity of the model."""
    current_identity = _build_semantic_identity_summary(current_summary)
    baseline_identity = _build_semantic_identity_summary(baseline_summary)
    return current_identity != baseline_identity


def _validate_feedback_candidate(
    *,
    executable: Path,
    input_model: Path,
    workspace: Path,
    bundle: EvidenceBundle,
    timeout_seconds: float,
    expected_threat_count: int | None,
    template_upgrade_policy: str,
    delete_stale_threats: bool,
    require_feedback_evidence: bool,
    feedback_surface_id_by_guid: dict[str, str] | None = None,
    feedback_node_id_by_guid: dict[str, dict[str, str]] | None = None,
    feedback_semantic_surfaces: dict[str, dict[str, Any]] | None = None,
) -> dict[str, Any]:
    """Run the existing validation flow and return feedback-specific details."""
    output = _validate_candidate(
        executable=executable,
        input_model=input_model,
        workspace=workspace,
        bundle=bundle,
        mode="validate",
        timeout_seconds=timeout_seconds,
        expected_threat_count=expected_threat_count,
        template_upgrade_policy=template_upgrade_policy,
        delete_stale_threats=delete_stale_threats,
        capture_feedback_surfaces=True,
        require_feedback_evidence=require_feedback_evidence,
        feedback_surface_id_by_guid=feedback_surface_id_by_guid,
        feedback_node_id_by_guid=feedback_node_id_by_guid,
        feedback_semantic_surfaces=feedback_semantic_surfaces,
    )
    before_summary = output["before_summary"]
    after_summary = output["after_summary"]
    candidate_path = output["working_model"]
    candidate_bundle = EvidenceBundle(bundle.evidence_dir / "current")
    candidate_bundle.write_summary(before_summary, "before-save.json")
    candidate_bundle.write_summary(after_summary, "after-reopen.json")
    surface_metrics = output.get("surface_metrics") or []
    evidence_complete = bool(output.get("evidence_complete", True))
    if require_feedback_evidence and not surface_metrics:
        evidence_complete = False
    return {
        **output,
        "candidate_path": candidate_path,
        "before_summary": before_summary,
        "after_summary": after_summary,
        "surface_metrics": surface_metrics,
        "evidence_complete": evidence_complete,
        # This function validates one candidate in isolation and holds no
        # baseline, so it cannot decide whether the model's semantic identity
        # regressed. Returning None defers that decision to the caller, which
        # owns the baseline. Returning False asserted "no regression" without
        # evaluating anything and made the caller's evaluation unreachable.
        "semantic_regression": None,
        "semantic_summary": before_summary,
    }


def _rect_map_from_payload(
    raw: Any,
) -> dict[str, tuple[float, float, float, float]]:
    """Read a mapping of ids to four-number rectangles from a geometry payload."""
    if not isinstance(raw, dict):
        return {}
    rects: dict[str, tuple[float, float, float, float]] = {}
    for key, rect in raw.items():
        if not isinstance(rect, (list, tuple)) or len(rect) != 4:
            continue
        try:
            rects[str(key)] = tuple(float(item) for item in rect)
        except (TypeError, ValueError):
            # A rect that is not numeric carries no geometry. Redaction can
            # replace one with a marker string, and a partly numeric rect is
            # not safe to reconstruct, so the entry is dropped rather than
            # guessed at.
            continue
    return rects


def _point_tuple_from_payload(raw: Any) -> tuple[float, ...] | None:
    """Read a fixed-length numeric tuple from a geometry payload."""
    if not isinstance(raw, (list, tuple)):
        return None
    try:
        return tuple(float(item) for item in raw)
    except (TypeError, ValueError):
        return None


def _surface_geometry_from_payload(
    *,
    surface_id: str,
    geometry_payload: dict[str, Any],
) -> tm7_visual_feedback.SurfaceGeometry:
    """Rebuild a full ``SurfaceGeometry`` from a published metric payload.

    The payload is the serialized form of the geometry the metrics were derived
    from, so every populated field is restored. Passing only the node rects and
    connector segments left the zone and connector correction branches of
    ``derive_overlay_candidates`` permanently unreachable, which meant no
    automatic connector-label correction could ever be proposed.
    """
    connector_segments: list[
        tuple[str, str, tuple[float, float], tuple[float, float]]
    ] = []
    for item in geometry_payload.get("connector_segments") or []:
        if not isinstance(item, (list, tuple)) or len(item) != 4:
            continue
        source_id, target_id, start, end = item
        start_point = _point_tuple_from_payload(start)
        end_point = _point_tuple_from_payload(end)
        if start_point is None or end_point is None:
            continue
        connector_segments.append(
            (str(source_id), str(target_id), start_point, end_point)
        )

    connector_routes: dict[str, dict[str, Any]] = {}
    for flow_id, route in (geometry_payload.get("connector_routes") or {}).items():
        if not isinstance(route, dict):
            continue
        normalized_route: dict[str, Any] = {
            "source_id": str(route.get("source_id", "")),
            "target_id": str(route.get("target_id", "")),
        }
        for point_key in ("source_point", "handle_point", "target_point"):
            point = _point_tuple_from_payload(route.get(point_key))
            if point is not None and len(point) == 2:
                normalized_route[point_key] = point
        if {"source_point", "target_point"} <= set(normalized_route):
            connector_routes[str(flow_id)] = normalized_route

    viewport_target = _point_tuple_from_payload(geometry_payload.get("viewport_target"))
    if viewport_target is not None and len(viewport_target) != 4:
        viewport_target = None
    diagram_bounds = _point_tuple_from_payload(geometry_payload.get("diagram_bounds"))
    if diagram_bounds is not None and len(diagram_bounds) != 4:
        diagram_bounds = None

    return tm7_visual_feedback.SurfaceGeometry(
        surface_id=surface_id,
        nominal_node_size=float(
            geometry_payload.get("nominal_node_size", 100.0) or 100.0
        ),
        node_rects=_rect_map_from_payload(geometry_payload.get("node_rects")),
        connector_segments=connector_segments,
        boundary_rects=_rect_map_from_payload(geometry_payload.get("boundary_rects")),
        boundary_label_rects=_rect_map_from_payload(
            geometry_payload.get("boundary_label_rects")
        ),
        connector_label_rects=_rect_map_from_payload(
            geometry_payload.get("connector_label_rects")
        ),
        layout_roles={
            str(node_id): str(role)
            for node_id, role in (geometry_payload.get("layout_roles") or {}).items()
        },
        zone_membership={
            str(node_id): str(zone_id)
            for node_id, zone_id in (
                geometry_payload.get("zone_membership") or {}
            ).items()
        },
        zone_content_rects=_rect_map_from_payload(
            geometry_payload.get("zone_content_rects")
        ),
        zone_parent_map={
            str(zone_id): (str(parent_id) if parent_id is not None else None)
            for zone_id, parent_id in (
                geometry_payload.get("zone_parent_map") or {}
            ).items()
        },
        viewport_target=viewport_target,
        diagram_bounds=diagram_bounds,
        outer_margin=float(geometry_payload.get("outer_margin", 0.0) or 0.0),
        selected_flow_ids={
            str(flow_id)
            for flow_id in (geometry_payload.get("selected_flow_ids") or [])
        },
        expected_semantic_node_ids={
            str(node_id)
            for node_id in (geometry_payload.get("expected_semantic_node_ids") or [])
        },
        expected_semantic_flow_ids={
            str(flow_id)
            for flow_id in (geometry_payload.get("expected_semantic_flow_ids") or [])
        },
        connector_routes=connector_routes,
        node_ranks={
            str(node_id): int(rank)
            for node_id, rank in (geometry_payload.get("node_ranks") or {}).items()
        },
        branch_groups={
            str(node_id): int(group_id)
            for node_id, group_id in (
                geometry_payload.get("branch_groups") or {}
            ).items()
        },
        orientation=str(geometry_payload.get("orientation") or "horizontal").lower(),
    )


def _semantic_surface_geometry(
    surface: dict[str, Any],
) -> tm7_visual_feedback.SurfaceGeometry:
    """Build a ``SurfaceGeometry`` from one laid-out generator surface.

    This is the portable path: it reads only what ``apply_layout`` produced, so
    it works for a hypothetical candidate layout that was never opened in the
    Threat Modeling Tool and has no capture evidence at all. The capture-time
    caller uses it as its semantic base and then overlays parsed and measured
    geometry on top, so both paths derive the same shapes from one place.
    """
    surface_id = str(surface.get("id", ""))
    elements = [
        element for element in surface.get("elements", []) if isinstance(element, dict)
    ]
    node_rects: dict[str, tuple[float, float, float, float]] = {}
    boundary_rects: dict[str, tuple[float, float, float, float]] = {}
    zone_membership: dict[str, str] = {}
    layout_roles: dict[str, str] = {}
    for element in elements:
        element_id = str(element.get("id", ""))
        if not element_id:
            continue
        position = element.get("position") or {}
        left = float(position.get("left", 0.0) or 0.0)
        top = float(position.get("top", 0.0) or 0.0)
        rect = (
            left,
            top,
            left + float(position.get("width", 0.0) or 0.0),
            top + float(position.get("height", 0.0) or 0.0),
        )
        if str(element.get("kind", "")).lower() == "trust_boundary_box":
            boundary_rects[str(element.get("trust_zone_id", "") or element_id)] = rect
            continue
        node_rects[element_id] = rect
        zone_membership[element_id] = str(element.get("trust_zone_id", "") or "")
        layout_roles[element_id] = str(element.get("layout_role", "") or "")

    connector_segments: list[
        tuple[str, str, tuple[float, float], tuple[float, float]]
    ] = []
    connector_label_rects: dict[str, tuple[float, float, float, float]] = {}
    connector_routes: dict[str, dict[str, Any]] = {}
    flow_ids: list[str] = []
    for flow in surface.get("flows", []):
        if not isinstance(flow, dict):
            continue
        flow_id = str(flow.get("id", ""))
        if not flow_id:
            continue
        flow_ids.append(flow_id)
        position = flow.get("position") or {}
        source_point = (
            float(position.get("source_x", 0.0) or 0.0),
            float(position.get("source_y", 0.0) or 0.0),
        )
        handle_point = (
            float(position.get("handle_x", 0.0) or 0.0),
            float(position.get("handle_y", 0.0) or 0.0),
        )
        target_point = (
            float(position.get("target_x", 0.0) or 0.0),
            float(position.get("target_y", 0.0) or 0.0),
        )
        source_id = str(flow.get("source_ref", ""))
        target_id = str(flow.get("target_ref", ""))
        # A connector is drawn as two straight runs through its handle, so it
        # is measured as two segments rather than one source-to-target line.
        connector_segments.append((source_id, target_id, source_point, handle_point))
        connector_segments.append((source_id, target_id, handle_point, target_point))
        connector_routes[flow_id] = {
            "source_id": source_id,
            "target_id": target_id,
            "source_point": source_point,
            "handle_point": handle_point,
            "target_point": target_point,
        }
        label_rect = flow.get("label_rect")
        if isinstance(label_rect, list) and len(label_rect) == 4:
            label_left, label_top, label_width, label_height = (
                float(value) for value in label_rect
            )
            connector_label_rects[flow_id] = (
                label_left,
                label_top,
                label_left + label_width,
                label_top + label_height,
            )

    layout_metadata = surface.get("layout_metadata") or {}
    if not isinstance(layout_metadata, dict):
        layout_metadata = {}
    diagram_bounds = _point_tuple_from_payload(layout_metadata.get("diagram_bounds"))
    if diagram_bounds is not None and len(diagram_bounds) != 4:
        diagram_bounds = None
    viewport_target = _point_tuple_from_payload(layout_metadata.get("viewport"))
    if viewport_target is not None and len(viewport_target) != 4:
        viewport_target = None

    size_values = [
        max(rect[2] - rect[0], rect[3] - rect[1]) for rect in node_rects.values()
    ]
    nominal_node_size = (
        max(100.0, float(sum(size_values) / len(size_values))) if size_values else 100.0
    )

    return tm7_visual_feedback.SurfaceGeometry(
        surface_id=surface_id,
        nominal_node_size=nominal_node_size,
        node_rects=node_rects,
        connector_segments=connector_segments,
        boundary_rects=boundary_rects,
        boundary_label_rects={
            zone_id: (left, top, right, min(bottom, top + 36.0))
            for zone_id, (left, top, right, bottom) in boundary_rects.items()
        },
        connector_label_rects=connector_label_rects,
        layout_roles=layout_roles,
        zone_membership=zone_membership,
        zone_content_rects=dict(boundary_rects),
        zone_parent_map={
            str(zone.get("id", "")): (
                str(zone.get("parent_trust_zone_id", "") or "") or None
            )
            for zone in surface.get("trust_zones", [])
            if isinstance(zone, dict) and str(zone.get("id", ""))
        },
        viewport_target=viewport_target,
        diagram_bounds=diagram_bounds,
        outer_margin=24.0,
        selected_flow_ids=set(flow_ids),
        expected_semantic_node_ids=set(node_rects),
        expected_semantic_flow_ids=set(flow_ids),
        connector_routes=connector_routes,
        node_ranks={
            str(node_id): int(rank)
            for node_id, rank in (layout_metadata.get("node_ranks") or {}).items()
        },
        branch_groups={
            str(node_id): int(group_id)
            for node_id, group_id in (
                layout_metadata.get("branch_groups") or {}
            ).items()
        },
        orientation=str(layout_metadata.get("orientation") or "horizontal").lower(),
    )


def _measured_layout_score(
    geometry: tm7_visual_feedback.SurfaceGeometry,
) -> tuple[float, ...]:
    """Score a laid-out surface on defects measured from its own geometry.

    The ordering is a severity ladder, most damaging first: content the reader
    cannot see at all, then content in the wrong place, then content that
    collides, then routing noise. Every term is derived from the drawn shapes,
    so it carries information the generation-time topology scorer could not
    have had.
    """
    metrics = tm7_visual_feedback.derive_geometry_metrics(geometry)
    return (
        float(metrics.get("canvas_clipping_count", 0)),
        float(metrics.get("node_outside_zone_count", 0)),
        float(metrics.get("boundary_overlap_count", 0)),
        float(metrics.get("edge_node_intersections", 0)),
        float(metrics.get("connector_label_intersections", 0)),
        float(metrics.get("boundary_label_intersections", 0)),
        float(metrics.get("edge_crossing_count", 0)),
        round(float(metrics.get("overlap_ratio", 0.0)), 6),
        round(float(metrics.get("scroll_extent_ratio_x", 0.0)), 6),
        round(float(metrics.get("scroll_extent_ratio_y", 0.0)), 6),
    )


def _lay_out_candidate_surface(
    *,
    generator_model: dict[str, Any],
    generator_profile: dict[str, Any],
    surface_id: str,
    orientation: str,
    zone_order: list[str],
    viewport_target: tuple[float, ...] | None = None,
) -> tm7_visual_feedback.SurfaceGeometry | None:
    """Lay out one alternative and return its geometry, or None if unrealizable.

    ``apply_layout`` mutates a whole model in place, so each alternative gets
    its own deep copy. A candidate reaches layout only through a synthesized
    ``surface_rules`` overlay, which is the sole channel carrying an orientation
    and a zone order into placement. A layout that raises is a candidate the
    generator cannot realize, not a harness failure, so it is rejected and the
    remaining candidates still run.

    ``viewport_target`` must match the canvas the winning candidate will be
    replayed against. Omitting it scores every candidate against the default
    canvas while the emitted rule carries the measured one, so the layout that
    was compared is not the layout the next iteration builds.
    """
    surface_rule: dict[str, Any] = {
        "surface_id": surface_id,
        "orientation": orientation,
        "zone_order": list(zone_order),
    }
    if viewport_target is not None and len(viewport_target) == 4:
        surface_rule["viewport_target"] = {
            "left": float(viewport_target[0]),
            "top": float(viewport_target[1]),
            "width": float(viewport_target[2]),
            "height": float(viewport_target[3]),
        }
    overlay = {"surface_rules": [surface_rule]}
    try:
        laid_out = generate_tm7.apply_layout(
            copy.deepcopy(generator_model),
            generator_profile,
            layout_overlay=overlay,
        )
    except generate_tm7.GenerationError:
        return None
    for surface in laid_out.get("surfaces", []):
        if isinstance(surface, dict) and str(surface.get("id", "")) == surface_id:
            return _semantic_surface_geometry(surface)
    return None


def _refinement_surface_rule_candidate(
    *,
    refinement_decision: dict[str, Any] | None,
    surface_metrics: list[dict[str, Any]],
) -> dict[str, Any] | None:
    """Convert a refinement selection into an accumulated surface rule.

    Without this the selection has no reader at all: the launch gate consumed
    the decision as a boolean and discarded the chosen layout, so an iteration
    that earned a native launch would reopen the tool against the unchanged
    model. That is worse than not launching, because it spends an operator
    takeover to produce identical evidence.
    """
    if not refinement_decision or not refinement_decision.get("requires_native_launch"):
        return None
    selected = refinement_decision.get("selected")
    if not isinstance(selected, dict):
        return None
    surface_id = str(refinement_decision.get("surface_id", ""))
    zone_order = [str(zone_id) for zone_id in (selected.get("zone_order") or [])]
    orientation = str(selected.get("orientation", "") or "")
    if (
        not surface_id
        or not zone_order
        or orientation
        not in {
            "horizontal",
            "vertical",
        }
    ):
        return None
    viewport_payload: Any = None
    for metric in surface_metrics:
        if str(metric.get("surface_id", "")) == surface_id:
            viewport_payload = (metric.get("surface_geometry") or {}).get(
                "viewport_target"
            )
            break
    viewport = _point_tuple_from_payload(viewport_payload)
    if viewport is None or len(viewport) != 4:
        viewport = (
            0.0,
            0.0,
            generate_tm7.DEFAULT_VIEWPORT_WIDTH,
            generate_tm7.DEFAULT_VIEWPORT_HEIGHT,
        )
    return {
        "surface_id": surface_id,
        "target_type": "surface",
        "target_id": surface_id,
        "constraint_type": "surface-refinement",
        "rule_collection": "surface_rules",
        "overlay_rule": {
            "surface_id": surface_id,
            "orientation": orientation,
            "zone_order": zone_order,
            "viewport_target": {
                "left": viewport[0],
                "top": viewport[1],
                "width": viewport[2],
                "height": viewport[3],
            },
            "outer_margin": 24.0,
        },
    }


def _merge_validated_rule(
    accumulated_rules: list[dict[str, Any]],
    accumulated_surface_id: str | None,
    candidate: dict[str, Any],
    *,
    overlay_payload: dict[str, Any],
    overlay_context: Any,
    generator_profile: str,
) -> tuple[list[dict[str, Any]], str | None, str | None]:
    """Merge a rule only when the resulting overlay still validates.

    Zone and connector rules became reachable once the full surface geometry
    reached candidate derivation, so a shape that fails overlay validation is
    now possible where it never was before. Both existing validation call sites
    abort the run, which would suppress the agent review request and leave the
    operator with neither an automated correction nor a review to perform. A
    rejected rule is dropped instead, so the run keeps whatever corrections did
    validate and still reports its ordinary outcome.
    """
    trial_rules, trial_surface_id = _merge_accumulated_rule(
        list(accumulated_rules),
        accumulated_surface_id,
        candidate,
    )
    if trial_rules == accumulated_rules:
        return accumulated_rules, accumulated_surface_id, None
    trial_overlay = copy.deepcopy(overlay_payload)
    _apply_accumulated_rules(
        trial_overlay,
        trial_rules,
        generator_profile=generator_profile,
    )
    try:
        tm7_visual_feedback.validate_layout_overlay(trial_overlay, overlay_context)
    except (ValueError, TypeError, KeyError) as exc:
        return (
            accumulated_rules,
            accumulated_surface_id,
            f"{candidate.get('rule_collection', 'node_rules')}: {exc}",
        )
    return trial_rules, trial_surface_id, None


def _evaluate_surface_refinement(
    *,
    surface_metrics: list[dict[str, Any]],
    failing_candidates: list[dict[str, Any]],
    semantic_surfaces: dict[str, dict[str, Any]],
    generator_model: dict[str, Any] | None = None,
    generator_profile: dict[str, Any] | None = None,
) -> dict[str, Any] | None:
    """Decide whether any whole-surface alternative earns a native TMT launch.

    Returns None when the caller has no failing surface to refine. Otherwise the
    result reports whether a complete alternative strictly improves the score,
    so a non-improving iteration never spends a native launch. Supplying the
    generator model and profile scores alternatives on measured geometry, which
    is the only basis on which one can win: without them the comparison uses the
    same topology scorer generation already minimized.
    """
    failing_surface_ids = {
        str(candidate.get("surface_id", "")) for candidate in failing_candidates
    }
    if not failing_surface_ids:
        return None
    metrics_by_surface = {
        str(metric.get("surface_id", "")): metric for metric in surface_metrics
    }
    aggregate: dict[str, Any] | None = None
    for surface_id in sorted(failing_surface_ids):
        metric = metrics_by_surface.get(surface_id)
        if metric is None:
            continue
        geometry_payload = metric.get("surface_geometry") or {}
        semantic_surface = semantic_surfaces.get(surface_id) or {}
        layout_metadata = semantic_surface.get("layout_metadata") or {}
        if not isinstance(layout_metadata, dict):
            layout_metadata = {}
        node_ids = sorted(
            str(node_id) for node_id in (geometry_payload.get("node_rects") or {})
        )
        flow_ids = sorted(
            str(flow_id) for flow_id in (geometry_payload.get("connector_routes") or {})
        )
        zone_ids = sorted(
            str(zone_id)
            for zone_id in (geometry_payload.get("zone_content_rects") or {})
        )
        node_ranks = dict(layout_metadata.get("node_ranks") or {})
        # Without zones or ranks the surface exposes no whole-surface degrees of
        # freedom, so the refinement search has no opinion and must not claim the
        # candidate space was exhausted.
        if not zone_ids and not node_ranks:
            continue
        # Orientation, ranks, branches, and zone order describe what the
        # generator decided, not what the tool drew, so they are read from the
        # layout metadata the generator published. The capture payload never
        # carried them; reading them from there scored every incumbent as an
        # unranked horizontal layout, which is the zero-penalty answer and made
        # a strict improvement arithmetically unreachable.
        incumbent = {
            "candidate_id": f"{surface_id}:incumbent",
            "node_ids": node_ids,
            "flow_ids": flow_ids,
            "zone_ids": zone_ids,
            "orientation": str(layout_metadata.get("orientation") or "horizontal"),
            "zone_order": [
                str(zone_id)
                for zone_id in (layout_metadata.get("zone_order") or zone_ids)
            ],
            "node_ranks": node_ranks,
            "branch_groups": dict(layout_metadata.get("branch_groups") or {}),
        }
        viewport_payload = geometry_payload.get("viewport_target")
        viewport_target = (
            tuple(float(value) for value in viewport_payload)
            if isinstance(viewport_payload, (list, tuple))
            and len(viewport_payload) == 4
            else None
        )
        incumbent_score = tm7_visual_feedback.score_surface_layout_candidate(
            incumbent,
            viewport_target=viewport_target,
        )
        alternatives = _build_surface_refinement_candidates(
            surface_id=surface_id,
            incumbent=incumbent,
            semantic_surface=semantic_surface,
        )
        # Measured scoring needs a model to lay candidates out against. When
        # the caller cannot supply one the search falls back to the topology
        # scorer, which cannot find an improvement, so the decision stays
        # honest rather than pretending alternatives were evaluated.
        score_candidate = None
        if generator_model is not None and generator_profile is not None:
            incumbent_geometry = _lay_out_candidate_surface(
                generator_model=generator_model,
                generator_profile=generator_profile,
                surface_id=surface_id,
                orientation=str(incumbent["orientation"]),
                zone_order=list(incumbent["zone_order"]),
                viewport_target=viewport_target,
            )
            if incumbent_geometry is not None:
                incumbent_score = _measured_layout_score(incumbent_geometry)

                def score_candidate(
                    candidate: dict[str, Any],
                    _surface_id: str = surface_id,
                    _viewport: tuple[float, ...] | None = viewport_target,
                ) -> tuple[float, ...] | None:
                    geometry = _lay_out_candidate_surface(
                        generator_model=generator_model,
                        generator_profile=generator_profile,
                        surface_id=_surface_id,
                        orientation=str(candidate.get("orientation", "horizontal")),
                        zone_order=list(candidate.get("zone_order") or []),
                        viewport_target=_viewport,
                    )
                    if geometry is None:
                        return None
                    return _measured_layout_score(geometry)

        decision = tm7_visual_feedback.select_surface_refinement(
            incumbent_score=incumbent_score,
            incumbent_semantic_fingerprint=(
                tm7_visual_feedback.surface_semantic_fingerprint(incumbent)
            ),
            candidates=alternatives,
            viewport_target=viewport_target,
            score_candidate=score_candidate,
        )
        decision["surface_id"] = surface_id
        if decision.get("requires_native_launch"):
            return decision
        aggregate = decision
    return aggregate


def _build_surface_refinement_candidates(
    *,
    surface_id: str,
    incumbent: dict[str, Any],
    semantic_surface: dict[str, Any],
) -> list[dict[str, Any]]:
    """Build bounded complete alternatives that preserve semantic identities.

    Only the orientation and the zone order can reach layout, so the search
    enumerates distinct pairs of those two. Earlier revisions also varied a rank
    spacing and a branch offset, but neither has an overlay channel: they moved
    numbers inside the candidate dict and produced byte-identical layouts. Under
    measured scoring their variants were exact ties, and ties are actively
    harmful here because dominated-candidate pruning discards equal scores and
    selection demands a strict improvement. Dropping them takes the space from
    192 mostly identical candidates to at most 32 distinct ones.
    """
    zone_ids = list(incumbent.get("zone_order") or [])
    orientations = ["horizontal", "vertical"]
    zone_orders: list[list[str]] = []
    if zone_ids:
        rotation_cap = min(
            len(zone_ids),
            tm7_visual_feedback.SURFACE_REFINEMENT_ZONE_ROTATION_CAP,
        )
        for rotation in range(rotation_cap):
            rotated = zone_ids[rotation:] + zone_ids[:rotation]
            zone_orders.append(rotated)
            zone_orders.append(list(reversed(rotated)))
    else:
        zone_orders.append([])
    candidates: list[dict[str, Any]] = []
    seen_signatures: set[tuple[str, tuple[str, ...]]] = set()
    for orientation in orientations:
        for zone_order in zone_orders:
            signature = (orientation, tuple(zone_order))
            if signature in seen_signatures:
                continue
            seen_signatures.add(signature)
            if len(candidates) >= (
                tm7_visual_feedback.MAX_SURFACE_REFINEMENT_CANDIDATES
            ):
                return candidates
            candidates.append(
                {
                    "candidate_id": (
                        f"{surface_id}:{orientation}:{'-'.join(zone_order) or 'none'}"
                    ),
                    "node_ids": list(incumbent["node_ids"]),
                    "flow_ids": list(incumbent["flow_ids"]),
                    "zone_ids": list(incumbent["zone_ids"]),
                    "orientation": orientation,
                    "zone_order": list(zone_order),
                    "node_ranks": dict(incumbent.get("node_ranks") or {}),
                    "branch_groups": dict(incumbent.get("branch_groups") or {}),
                }
            )
    return candidates


def _normalize_feedback_stop_reason(
    status: str,
    *,
    require_feedback_evidence: bool,
    exit_code: int,
) -> str:
    """Map loop outcomes to the stable stop-reason vocabulary."""
    if status in FEEDBACK_STOP_REASONS:
        return status
    if status == "passed" or exit_code == EXIT_SUCCESS:
        return "automated-ready-pending-human"
    if exit_code == EXIT_MISSING_TMT:
        return "tmt-unavailable"
    if exit_code == EXIT_VERSION_MISMATCH:
        return "version-mismatch"
    if exit_code == EXIT_AUTOMATION_TIMEOUT:
        return "automation-timeout"
    if exit_code == EXIT_UNEXPECTED_MODAL:
        return "unexpected-modal"
    if exit_code == EXIT_MISSING_FEEDBACK_EVIDENCE or require_feedback_evidence:
        return "evidence-incomplete"
    # Every status the loop assigns is a member of the vocabulary, so reaching
    # here means an outcome arrived from outside the loop's own assignments.
    # Naming it harness-error keeps that honest; naming it unexpected-modal
    # would send an operator hunting for a dialog that never appeared.
    return "harness-error"


def _discard_stale_overlay(overlay_output: Path, overlay_input: Path | None) -> None:
    """Remove an overlay this run did not produce.

    A run that publishes no overlay must not leave an earlier run's file at the
    declared output path, where it reads as the current result. The declared
    input is never removed, because a caller may point input and output at the
    same file to iterate in place.

    Args:
        overlay_output: Declared overlay output path.
        overlay_input: Declared overlay input path, when one was supplied.
    """
    if (
        overlay_input is not None
        and Path(overlay_input).resolve() == overlay_output.resolve()
    ):
        return
    overlay_output.unlink(missing_ok=True)


def run_feedback_loop(
    *,
    baseline_model: Path,
    spec_path: Path,
    overlay_input: Path | None,
    overlay_output: Path,
    max_iterations: int,
    require_feedback_evidence: bool,
    evidence_dir: Path,
    workspace_root: Path | None = None,
    require_tmt: bool = False,
    pinned_version: str = DEFAULT_PINNED_VERSION,
    diagnostic_override: bool = False,
    timeout_seconds: float = DEFAULT_TIMEOUT_SECONDS,
    expected_threat_count: int | None = None,
    expected_custom_type_count: int | None = None,
    template_upgrade_policy: str = "fail",
    delete_stale_threats: bool = False,
) -> FeedbackLoopResult:
    """Run the bounded native feedback loop and emit a pending overlay.

    ``expected_threat_count`` is an optional caller assertion. It defaults to
    ``None`` so a model of any size is accepted; a fixed count would reject
    every model that does not happen to match it.
    """
    baseline_model = Path(baseline_model).resolve()
    spec_path = Path(spec_path).resolve()
    evidence_dir = Path(evidence_dir).resolve()
    overlay_output = Path(overlay_output).resolve()
    workspace = prepare_owned_workspace(workspace_root, evidence_dir)
    bundle = EvidenceBundle(evidence_dir)
    manifest: dict[str, Any] = {
        "mode": "feedback-loop",
        "required_tmt_version": pinned_version,
        "observed_tmt_version": None,
        "diagnostic_override": diagnostic_override,
        "require_tmt": require_tmt,
        "spec_path": str(spec_path),
        "overlay_input": str(overlay_input) if overlay_input is not None else None,
        "overlay_output": str(overlay_output),
        "max_iterations": max_iterations,
        "require_feedback_evidence": require_feedback_evidence,
        "started_at": datetime.now(timezone.utc).isoformat(),
        "evidence_schema_version": EVIDENCE_SCHEMA_VERSION,
    }
    bundle.write_manifest(manifest)

    if not baseline_model.is_file():
        message = "Input model does not exist"
        bundle.write_status(
            _status_payload(
                result="error",
                exit_code=EXIT_ERROR,
                message=message,
                bundle=bundle,
                manifest=manifest,
            )
        )
        return FeedbackLoopResult(EXIT_ERROR, "error", message, evidence_dir)

    discovery = discover_tmt_application()
    manifest["observed_tmt_version"] = discovery.version
    manifest["discovery_source"] = discovery.source
    bundle.write_manifest(manifest)
    if discovery.path is None:
        # require_tmt is the caller's declaration that a missing tool is a
        # failure rather than an expected local condition, which distinguishes a
        # developer machine without TMT from a CI host that must have it.
        status = "tmt-unavailable" if require_tmt else "skipped"
        exit_code = EXIT_MISSING_TMT if require_tmt else EXIT_SUCCESS
        message = (
            "TMT was not found"
            if require_tmt
            else "TMT not found; feedback loop skipped"
        )
        bundle.write_status(
            _status_payload(
                result=status,
                exit_code=exit_code,
                message=message,
                bundle=bundle,
                manifest=manifest,
            )
        )
        return FeedbackLoopResult(exit_code, status, message, evidence_dir)

    policy = evaluate_version_policy(
        TmtVersionPolicy(pinned_version, discovery.version, diagnostic_override)
    )
    if not policy.allowed:
        bundle.write_status(
            _status_payload(
                result="version-mismatch",
                exit_code=policy.exit_code,
                message=policy.reason,
                bundle=bundle,
                manifest=manifest,
            )
        )
        return FeedbackLoopResult(
            policy.exit_code,
            "version-mismatch",
            policy.reason,
            evidence_dir,
        )

    history: list[tm7_visual_feedback.IterationResult] = []
    baseline_summary: dict[str, Any] | None = None
    final_overlay: dict[str, Any] | None = None
    final_candidate_path: Path | None = None
    final_surface_metrics: list[dict[str, Any]] = []
    final_surface_payloads: list[dict[str, Any]] = []
    final_status = "passed"
    final_exit_code = EXIT_SUCCESS
    final_message = "Feedback loop completed"
    iteration_overlay_path: Path | None = None
    accumulated_rules: list[dict[str, Any]] = []
    accumulated_surface_id: str | None = None
    iteration_index = 0
    preflight_emitted = False
    release_emitted = False

    # Spec loading and generator-context construction sit inside the guarded
    # region because a failure there can strand a traceback and an earlier run's
    # overlay just as readily as a failure during automation.
    try:
        spec = generate_tm7.load_spec(spec_path)
        template_dir = Path(generate_tm7.__file__).resolve().parent.parent
        profile = generate_tm7.resolve_profile(spec, None, template_dir)
        profile["name"] = str(spec.get("template_profile") or "sdl_core_generic")
        default_mode = (
            "pre-populated-comprehensive"
            if spec.get("threats")
            else "diagram-only-defer-to-tmt"
        )
        generation_mode = str(spec.get("mode") or default_mode)
        semantic_surfaces: dict[str, dict[str, Any]] = {}
        try:
            generator_model = generate_tm7.build_model_from_spec(
                spec,
                profile,
                generation_mode,
            )
            semantic_layout_model = generate_tm7.apply_layout(
                copy.deepcopy(generator_model),
                profile,
            )
            semantic_surfaces = {
                str(surface.get("id", "")): surface
                for surface in semantic_layout_model.get("surfaces", [])
                if isinstance(surface, dict) and str(surface.get("id", ""))
            }
        except generate_tm7.GenerationError as exc:
            generator_model = _build_fallback_generator_model(spec)
            _emit_operator_notice(
                "Falling back to spec-only overlay context after generation "
                f"failure: {exc}"
            )
        generator_context = generate_tm7._build_overlay_context(
            spec=spec,
            profile=profile,
            spec_path=spec_path,
            model=generator_model,
        )
        spec_sha256 = generator_context.spec_sha256
        generator_profile = generator_context.generator_profile
        generator_profile_sha256 = generator_context.generator_profile_sha256
        surface_id_by_guid = {
            generate_tm7._make_guid(f"surface:{surface_id}"): surface_id
            for surface_id in generator_context.surface_ids
        }
        node_id_by_guid: dict[str, dict[str, str]] = {}
        for surface in generator_model.get("surfaces", []):
            surface_id = str(surface.get("id", ""))
            node_id_by_guid[surface_id] = {
                str(element.get("guid", "")): str(element.get("id", ""))
                for element in surface.get("elements", [])
                if isinstance(element, dict)
                and str(element.get("guid", ""))
                and str(element.get("id", ""))
            }

        _emit_operator_notice(
            "Native TMT UI automation will control mouse/keyboard-facing "
            "application windows; do not use the mouse, keyboard, switch "
            "windows, or interact with TMT until the completion notice "
            "appears. TMT may open, close, and reopen twice per candidate "
            "for save/reopen validation."
        )
        preflight_emitted = True

        while iteration_index <= max_iterations:
            iteration_label = (
                "00-baseline" if iteration_index == 0 else f"{iteration_index:02d}"
            )
            iteration_dir = evidence_dir / "iterations" / iteration_label
            iteration_dir.mkdir(parents=True, exist_ok=True)
            iteration_bundle = EvidenceBundle(iteration_dir)
            candidate_model_path = iteration_dir / f"candidate-{iteration_label}.tm7"
            candidate_path_for_generation: Path
            # Candidate regeneration runs the generator, which fails closed on
            # invalid input. That failure is reported as a stopped run so the
            # operator gets a recorded status rather than a bare traceback.
            try:
                if iteration_index == 0:
                    if overlay_input is None:
                        candidate_model_path = baseline_model
                        candidate_path_for_generation = baseline_model
                    else:
                        candidate_path_for_generation = (
                            generate_tm7.generate_tm7_candidate(
                                spec_path=spec_path,
                                output_path=candidate_model_path,
                                template=None,
                                mode=None,
                                update_path=None,
                                overlay_path=overlay_input,
                                threat_generation_enabled=False,
                            )
                        )
                        candidate_model_path = candidate_path_for_generation
                else:
                    candidate_path_for_generation = generate_tm7.generate_tm7_candidate(
                        spec_path=spec_path,
                        output_path=candidate_model_path,
                        template=None,
                        mode=None,
                        update_path=None,
                        overlay_path=iteration_overlay_path,
                        threat_generation_enabled=False,
                    )
                    candidate_model_path = candidate_path_for_generation
            except generate_tm7.GenerationError as exc:
                final_status = "candidate-generation-failed"
                final_exit_code = EXIT_ERROR
                final_message = f"Candidate regeneration failed: {exc}"
                break

            iteration_workspace = workspace / iteration_label
            iteration_workspace.mkdir(parents=True, exist_ok=True)
            total_candidates = max_iterations + 1
            if iteration_index == 0:
                _emit_operator_notice(f"Candidate baseline (1 of {total_candidates})")
            else:
                _emit_operator_notice(
                    f"Candidate refinement {iteration_index} of {max_iterations}"
                )
            try:
                candidate_result = _validate_feedback_candidate(
                    executable=discovery.path,
                    input_model=candidate_model_path,
                    workspace=iteration_workspace,
                    bundle=iteration_bundle,
                    timeout_seconds=timeout_seconds,
                    expected_threat_count=expected_threat_count,
                    template_upgrade_policy=template_upgrade_policy,
                    delete_stale_threats=delete_stale_threats,
                    require_feedback_evidence=require_feedback_evidence,
                    feedback_surface_id_by_guid=surface_id_by_guid,
                    feedback_node_id_by_guid=node_id_by_guid,
                    feedback_semantic_surfaces=semantic_surfaces,
                )
            except HarnessFailure as exc:
                if exc.exit_code == EXIT_AUTOMATION_TIMEOUT:
                    final_status = "automation-timeout"
                    final_exit_code = exc.exit_code
                    final_message = str(exc)
                elif exc.exit_code == EXIT_UNEXPECTED_MODAL:
                    final_status = "unexpected-modal"
                    final_exit_code = exc.exit_code
                    final_message = str(exc)
                elif exc.exit_code == EXIT_VERSION_MISMATCH:
                    final_status = "version-mismatch"
                    final_exit_code = exc.exit_code
                    final_message = str(exc)
                elif exc.exit_code == EXIT_MISSING_TMT:
                    final_status = "tmt-unavailable"
                    final_exit_code = exc.exit_code
                    final_message = str(exc)
                else:
                    final_status = (
                        "evidence-incomplete"
                        if require_feedback_evidence
                        else "harness-error"
                    )
                    final_exit_code = exc.exit_code
                    final_message = str(exc)
                break
            candidate_summary = candidate_result["before_summary"]
            if baseline_summary is None:
                baseline_summary = candidate_summary
            semantic_regression = candidate_result.get("semantic_regression")
            if semantic_regression is None:
                semantic_regression = _evaluate_semantic_regression(
                    current_summary=candidate_summary,
                    baseline_summary=baseline_summary,
                )
            candidate_result["semantic_regression"] = bool(semantic_regression)

            surface_metrics = [
                dict(metric)
                for metric in (candidate_result.get("surface_metrics") or [])
            ]
            final_candidate_path = Path(
                str(candidate_result.get("working_model") or candidate_model_path)
            )
            final_surface_metrics = surface_metrics
            final_surface_payloads = [
                dict(payload)
                for payload in (candidate_result.get("surface_payloads") or [])
            ]
            evidence_complete = bool(candidate_result.get("evidence_complete", True))
            if semantic_regression:
                final_status = "semantic-regression"
                final_exit_code = EXIT_VALIDATION_FAILURE
                final_message = "Semantic regression detected"
                break
            if require_feedback_evidence and not evidence_complete:
                final_status = "evidence-incomplete"
                final_exit_code = EXIT_MISSING_FEEDBACK_EVIDENCE
                final_message = "Strict feedback evidence is incomplete"
                break

            overlay_context = generator_context
            candidates = []
            for metric in surface_metrics:
                geometry_payload = metric.get("surface_geometry") or {}
                geometry = _surface_geometry_from_payload(
                    surface_id=str(metric["surface_id"]),
                    geometry_payload=geometry_payload,
                )
                candidates.extend(
                    tm7_visual_feedback.derive_overlay_candidates(
                        surface_geometry=geometry,
                        overlay_context=overlay_context,
                        metrics=metric,
                        density=str(metric.get("density", "simple")),
                    )
                )
            ranked_candidates = tm7_visual_feedback.rank_overlay_candidates(candidates)
            failing_candidates = [
                candidate
                for candidate in ranked_candidates
                if int(candidate.get("gate_failure_count", 0)) > 0
            ]
            selected_candidate = (
                failing_candidates[0]
                if failing_candidates
                else ranked_candidates[0]
                if ranked_candidates
                else None
            )
            refinement_decision = _evaluate_surface_refinement(
                surface_metrics=surface_metrics,
                failing_candidates=failing_candidates,
                semantic_surfaces=semantic_surfaces or {},
                generator_model=generator_model,
                generator_profile=profile,
            )
            if refinement_decision is not None:
                # A stop reason has to be checkable, not just true. Without
                # this line an operator reading the evidence cannot tell a
                # genuine "no alternative was better" from the older behavior
                # where no alternative was ever evaluated, because both report
                # repeated-defect-no-improvement and neither leaves a trace.
                semantic_rejected = len(
                    refinement_decision.get("semantic_rejected_ids") or []
                )
                unrealizable_rejected = len(
                    refinement_decision.get("unrealizable_rejected_ids") or []
                )
                bundle.write_action_log(
                    "Refinement evaluated "
                    f"surface={refinement_decision.get('surface_id', 'unknown')} "
                    f"evaluated={int(refinement_decision.get('evaluated_count', 0))} "
                    f"pruned={int(refinement_decision.get('pruned_count', 0))} "
                    f"semantic_rejected={semantic_rejected} "
                    f"unrealizable_rejected={unrealizable_rejected} "
                    f"launch={bool(refinement_decision.get('requires_native_launch'))}"
                )
            all_findings = [
                finding
                for metric in surface_metrics
                for finding in (
                    metric.get("findings")
                    or tm7_visual_feedback.derive_findings(
                        metric,
                        density=str(metric.get("density", "simple")),
                    )
                )
            ]
            gate_failure_count = sum(
                1
                for finding in all_findings
                if finding.get("severity") == "review"
                and finding.get("category")
                not in {"screenshot_heuristic", "surface_completeness"}
            )
            review_count = sum(
                1
                for finding in all_findings
                if finding.get("severity") == "review"
                and finding.get("category") != "surface_completeness"
            )
            warn_count = sum(
                1 for finding in all_findings if finding.get("severity") == "warn"
            )
            max_severity_score = 3.0 if review_count else 2.0 if warn_count else 0.0
            defect_signature = "|".join(
                f"{entry['surface_id']}:{entry['metric_name']}:{entry['severity']}"
                for entry in sorted(
                    all_findings,
                    key=lambda finding: (
                        str(finding.get("surface_id", "")),
                        str(finding.get("metric_name", "")),
                        str(finding.get("severity", "")),
                    ),
                )
            )
            history.append(
                tm7_visual_feedback.IterationResult(
                    iteration_id=iteration_index,
                    defect_signature=defect_signature or "default",
                    gate_failure_count=gate_failure_count,
                    review_count=review_count,
                    warn_count=warn_count,
                    evidence_complete=evidence_complete,
                    max_severity_score=max_severity_score,
                )
            )

            convergence = tm7_visual_feedback.evaluate_convergence(
                history,
                max_iterations=max_iterations,
            )
            # The refinement gate only prevents spending the next native launch.
            # It runs after the iteration is recorded and after convergence has
            # had its say, so a passing candidate can still reach human review.
            if (
                not convergence.should_stop
                and gate_failure_count > 0
                and refinement_decision is not None
                and not refinement_decision.get("requires_native_launch", True)
            ):
                convergence = tm7_visual_feedback.ConvergenceResult(
                    should_stop=True,
                    stop_reason="repeated-defect-no-improvement",
                    reason_detail=(
                        "No whole-surface refinement improves the portable gates"
                    ),
                )
            if convergence.should_stop:
                if convergence.stop_reason == "automated-ready-pending-human":
                    final_status = "automated-ready-pending-human"
                    final_exit_code = EXIT_SUCCESS
                    final_message = (
                        convergence.reason_detail or "Feedback loop completed"
                    )
                else:
                    final_status = convergence.stop_reason
                    final_exit_code = EXIT_FEEDBACK_NON_CONVERGENCE
                    final_message = convergence.reason_detail or convergence.stop_reason
                if selected_candidate is not None:
                    overlay_payload = _build_feedback_overlay(
                        spec_path=spec_path,
                        candidate=selected_candidate,
                        overlay_context=overlay_context,
                        iteration_id=iteration_index,
                        spec_sha256=spec_sha256,
                        generator_profile=generator_profile,
                        generator_profile_sha256=generator_profile_sha256,
                        candidate_path=candidate_model_path,
                        ranking_key=selected_candidate["ranking_key"],
                    )
                    overlay_payload["provenance"]["evidence_ref"] = (
                        tm7_visual_feedback._normalize_path_reference(
                            str(iteration_dir / "candidate.tm7"),
                            field_name="provenance.evidence_ref",
                        )
                    )
                    (
                        accumulated_rules,
                        accumulated_surface_id,
                        rejected_rule,
                    ) = _merge_validated_rule(
                        accumulated_rules,
                        accumulated_surface_id,
                        selected_candidate,
                        overlay_payload=overlay_payload,
                        overlay_context=overlay_context,
                        generator_profile=generator_profile,
                    )
                    if rejected_rule is not None:
                        bundle.write_action_log(
                            f"Dropped an invalid overlay rule: {rejected_rule}"
                        )
                    _apply_accumulated_rules(
                        overlay_payload,
                        accumulated_rules,
                        generator_profile=generator_profile,
                    )
                    # On the success path every captured surface must be
                    # addressable, so a reviewer can author a rule for any of
                    # them without editing fingerprinted identity. The widening
                    # runs unconditionally: making it the alternative of the
                    # seed substitution would skip it exactly when the seed
                    # build fails, which is the case it exists for.
                    if final_status == "automated-ready-pending-human":
                        rules_empty = not any(
                            overlay_payload.get(collection)
                            for collection in (
                                "zone_rules",
                                "node_rules",
                                "connector_rules",
                                "surface_rules",
                            )
                        )
                        if rules_empty:
                            # The seed shape carries an overlay_id that signals
                            # no automated correction was found.
                            try:
                                overlay_payload = _build_overlay_seed(
                                    spec_path=spec_path,
                                    overlay_context=overlay_context,
                                    iteration_id=iteration_index,
                                    spec_sha256=spec_sha256,
                                    generator_profile=generator_profile,
                                    generator_profile_sha256=generator_profile_sha256,
                                    evidence_dir=evidence_dir,
                                )
                            except (ValueError, TypeError, KeyError):
                                # The seed is a convenience shape for a run
                                # that found no correction. If it cannot be
                                # built, the already-valid overlay payload
                                # stands and the run still reports normally.
                                pass
                        overlay_payload["applies_to"] = [
                            {
                                "surface_id": surface_id,
                                "generator_profile": generator_profile,
                            }
                            for surface_id in sorted(overlay_context.surface_ids)
                        ]
                    try:
                        tm7_visual_feedback.validate_layout_overlay(
                            overlay_payload,
                            overlay_context,
                        )
                    except (ValueError, TypeError, KeyError) as exc:
                        final_status = "overlay-validation-failed"
                        final_exit_code = EXIT_ERROR
                        final_message = f"Overlay validation failed: {exc}"
                        break
                    final_overlay = overlay_payload
                break

            if selected_candidate is not None:
                overlay_payload = _build_feedback_overlay(
                    spec_path=spec_path,
                    candidate=selected_candidate,
                    overlay_context=overlay_context,
                    iteration_id=iteration_index,
                    spec_sha256=spec_sha256,
                    generator_profile=generator_profile,
                    generator_profile_sha256=generator_profile_sha256,
                    candidate_path=candidate_model_path,
                    ranking_key=selected_candidate["ranking_key"],
                )
                (
                    accumulated_rules,
                    accumulated_surface_id,
                    rejected_rule,
                ) = _merge_validated_rule(
                    accumulated_rules,
                    accumulated_surface_id,
                    selected_candidate,
                    overlay_payload=overlay_payload,
                    overlay_context=overlay_context,
                    generator_profile=generator_profile,
                )
                if rejected_rule is not None:
                    bundle.write_action_log(
                        f"Dropped an invalid overlay rule: {rejected_rule}"
                    )
                # The refinement selection rides on the same accumulated set as
                # the node-level corrections, so the next iteration regenerates
                # against the chosen layout instead of the unchanged model, and
                # the merge keeps both.
                refinement_rule = _refinement_surface_rule_candidate(
                    refinement_decision=refinement_decision,
                    surface_metrics=surface_metrics,
                )
                if refinement_rule is not None:
                    (
                        accumulated_rules,
                        accumulated_surface_id,
                        rejected_refinement,
                    ) = _merge_validated_rule(
                        accumulated_rules,
                        accumulated_surface_id,
                        refinement_rule,
                        overlay_payload=overlay_payload,
                        overlay_context=overlay_context,
                        generator_profile=generator_profile,
                    )
                    if rejected_refinement is not None:
                        bundle.write_action_log(
                            "Dropped an invalid refinement surface rule: "
                            f"{rejected_refinement}"
                        )
                _apply_accumulated_rules(
                    overlay_payload,
                    accumulated_rules,
                    generator_profile=generator_profile,
                )
                try:
                    tm7_visual_feedback.validate_layout_overlay(
                        overlay_payload,
                        overlay_context,
                    )
                except (ValueError, TypeError, KeyError) as exc:
                    final_status = "overlay-validation-failed"
                    final_exit_code = EXIT_ERROR
                    final_message = f"Overlay validation failed: {exc}"
                    break
                iteration_overlay_path = iteration_bundle.write_json(
                    "overlay.yaml",
                    overlay_payload,
                )
                final_overlay = overlay_payload
            iteration_index += 1

        manifest_stop_reason = _normalize_feedback_stop_reason(
            final_status,
            require_feedback_evidence=require_feedback_evidence,
            exit_code=final_exit_code,
        )
        # The overlay is the declared output of a successful run, so success
        # without one is a broken contract rather than a quiet no-op. A stopped
        # run must not publish an overlay accumulated from an earlier iteration
        # either: that artifact looks actionable while the run itself is
        # blocked. A stopped run still writes a rules-empty seed, which carries
        # valid fingerprints a reviewer cannot compute by hand while changing
        # no geometry on replay.
        #
        # Publication is tracked rather than probed: _discard_stale_overlay
        # deliberately keeps the file when input and output are the same path,
        # so a filesystem probe would report a caller's earlier overlay as this
        # run's output and invite edits against stale fingerprints.
        published_overlay: Path | None = None
        if final_status == "automated-ready-pending-human":
            if final_overlay is None:
                final_status = "evidence-incomplete"
                final_exit_code = EXIT_MISSING_FEEDBACK_EVIDENCE
                final_message = (
                    "Feedback loop reported readiness without producing the "
                    "required layout overlay"
                )
                manifest_stop_reason = _normalize_feedback_stop_reason(
                    final_status,
                    require_feedback_evidence=require_feedback_evidence,
                    exit_code=final_exit_code,
                )
            else:
                overlay_output.parent.mkdir(parents=True, exist_ok=True)
                overlay_output.write_text(
                    json.dumps(bundle.redact(final_overlay), indent=2, sort_keys=True),
                    encoding="utf-8",
                )
                published_overlay = overlay_output
        if final_status != "automated-ready-pending-human" or final_overlay is None:
            seed_overlay = None
            if (
                final_status in OVERLAY_SEED_STOP_REASONS
                and generator_context is not None
                and generator_context.surface_ids
            ):
                try:
                    seed_overlay = _build_overlay_seed(
                        spec_path=spec_path,
                        overlay_context=generator_context,
                        iteration_id=iteration_index,
                        spec_sha256=spec_sha256,
                        generator_profile=generator_profile,
                        generator_profile_sha256=generator_profile_sha256,
                        evidence_dir=evidence_dir,
                    )
                    tm7_visual_feedback.validate_layout_overlay(
                        seed_overlay,
                        generator_context,
                    )
                except (ValueError, TypeError, KeyError):
                    # The seed is a convenience for the reviewer, not part of
                    # the run's verdict. Failing to build one must not change
                    # how the run itself is reported.
                    seed_overlay = None
            if seed_overlay is not None:
                overlay_output.parent.mkdir(parents=True, exist_ok=True)
                overlay_output.write_text(
                    json.dumps(bundle.redact(seed_overlay), indent=2, sort_keys=True),
                    encoding="utf-8",
                )
                published_overlay = overlay_output
            else:
                _discard_stale_overlay(overlay_output, overlay_input)
        # Build the agent visual-review request for a run that captured
        # trustworthy evidence. A build or write failure must not change the
        # result, stop_reason, or exit code, so the block is swallowed like the
        # seed-build precedent above. OSError is included because write_json
        # truncates before writing, so a disk failure would otherwise both
        # change the outcome and strand a partial artifact.
        agent_review_block: dict[str, Any] | None = None
        if (
            final_status == "automated-ready-pending-human"
            or final_status in OVERLAY_SEED_STOP_REASONS
        ) and final_surface_metrics:
            try:
                review_request = _build_agent_review_request(
                    final_surface_metrics=final_surface_metrics,
                    final_surface_payloads=final_surface_payloads,
                    semantic_surfaces=semantic_surfaces or {},
                    published_overlay_path=published_overlay,
                    overlay_input=overlay_input,
                    bundle=bundle,
                )
                if review_request is not None:
                    request_path = bundle.write_json(
                        "agent-review-request.json",
                        review_request,
                    )
                    agent_review_block = {
                        "status": "pending",
                        "request_path": request_path.name,
                        "round": review_request["agent_round"],
                    }
            except (ValueError, TypeError, KeyError, OSError) as exc:
                # Without this line a missing agent_review is indistinguishable
                # from a run the emission gate deliberately excluded.
                bundle.write_action_log(
                    f"Agent review request was not published: {exc}"
                )
                with contextlib.suppress(OSError):
                    (bundle.evidence_dir / "agent-review-request.json").unlink(
                        missing_ok=True
                    )
        candidate_sha256: str | None = None
        feedback_manifest_path: Path | None = None
        if final_candidate_path is not None and final_candidate_path.is_file():
            candidate_sha256 = hashlib.sha256(
                final_candidate_path.read_bytes()
            ).hexdigest()
            metrics_by_surface = {
                str(metric.get("surface_id", "")): metric
                for metric in final_surface_metrics
            }
            manifest_surfaces: list[dict[str, Any]] = []
            for surface_id in sorted(generator_context.surface_ids):
                metric = metrics_by_surface.get(surface_id, {})
                manifest_surfaces.append(
                    {
                        "surface_id": surface_id,
                        "surface_guid": generate_tm7._make_guid(
                            f"surface:{surface_id}"
                        ),
                        "surface_name": str(
                            semantic_surfaces.get(surface_id, {}).get(
                                "name",
                                surface_id,
                            )
                        ),
                        "capture_path": str(metric.get("evidence_path") or "missing"),
                        "uia_path": str(metric.get("uia_path") or "missing"),
                        "metrics": {
                            key: value
                            for key, value in metric.items()
                            if key not in {"findings", "surface_geometry"}
                        },
                        "findings": list(metric.get("findings") or []),
                        "human_review_status": "pending",
                        "human_review_required": True,
                    }
                )
            layout_calibration_v1 = _build_layout_calibration_contract(
                final_surface_payloads,
            )
            feedback_manifest = tm7_visual_feedback.build_feedback_manifest(
                model_id=generator_context.model_id,
                spec_path=spec_path.name,
                spec_sha256=spec_sha256,
                generator_profile=generator_profile,
                generator_profile_sha256=generator_profile_sha256,
                candidate_sha256=candidate_sha256,
                iteration_id=str(iteration_index),
                pinned_tmt_version=pinned_version,
                surfaces=manifest_surfaces,
                convergence={
                    "status": (
                        "automated-ready-pending-human"
                        if final_status == "automated-ready-pending-human"
                        else "stopped"
                    ),
                    "selected_candidate": final_candidate_path.name,
                    "stop_reason": manifest_stop_reason,
                    "semantic_regression": (
                        "detected" if final_status == "semantic-regression" else None
                    ),
                    "evidence_complete": all(
                        bool(metric.get("capture_complete", True))
                        for metric in final_surface_metrics
                    ),
                },
                created_at=datetime.now(timezone.utc).isoformat(),
                layout_calibration_v1=layout_calibration_v1,
            )
            tm7_visual_feedback.validate_feedback_manifest(feedback_manifest)
            feedback_manifest_path = bundle.write_json(
                "feedback-manifest.json",
                feedback_manifest,
            )
        manifest.update(
            {
                "completed_at": datetime.now(timezone.utc).isoformat(),
                "result": final_status,
                "stop_reason": manifest_stop_reason,
                "overlay_output": str(overlay_output),
                "candidate_sha256": candidate_sha256,
                "feedback_manifest": (
                    str(feedback_manifest_path) if feedback_manifest_path else None
                ),
                "iterations": [
                    {
                        "iteration_id": item.iteration_id,
                        "gate_failure_count": item.gate_failure_count,
                        "review_count": item.review_count,
                        "warn_count": item.warn_count,
                        "max_severity_score": item.max_severity_score,
                        "defect_signature": item.defect_signature,
                        "evidence_complete": item.evidence_complete,
                    }
                    for item in history
                ],
            }
        )
        bundle.write_manifest(manifest)
        bundle.write_status(
            _status_payload(
                result=final_status,
                exit_code=final_exit_code,
                message=final_message,
                bundle=bundle,
                manifest=manifest,
                agent_review=agent_review_block,
            )
        )
        return FeedbackLoopResult(
            exit_code=final_exit_code,
            status=final_status,
            message=final_message,
            evidence_dir=evidence_dir,
            overlay_output=overlay_output,
            workspace_dir=workspace,
            manifest_path=bundle.manifest_path,
        )
    except Exception as exc:
        # A recorded failure keeps the documented exit-code contract: an escaping
        # exception would leave no status.json, which the operator contract
        # reserves for a killed process, and would strand an earlier run's
        # overlay at the output path where it reads as this run's result.
        final_status = "harness-error"
        final_exit_code = EXIT_ERROR
        final_message = f"Feedback loop failed unexpectedly: {exc}"
        _discard_stale_overlay(overlay_output, overlay_input)
        manifest.update(
            {
                "completed_at": datetime.now(timezone.utc).isoformat(),
                "result": final_status,
                "stop_reason": _normalize_feedback_stop_reason(
                    final_status,
                    require_feedback_evidence=require_feedback_evidence,
                    exit_code=final_exit_code,
                ),
                "overlay_output": str(overlay_output),
            }
        )
        bundle.write_manifest(manifest)
        bundle.write_status(
            _status_payload(
                result=final_status,
                exit_code=final_exit_code,
                message=final_message,
                bundle=bundle,
                manifest=manifest,
            )
        )
        return FeedbackLoopResult(
            exit_code=final_exit_code,
            status=final_status,
            message=final_message,
            evidence_dir=evidence_dir,
            overlay_output=overlay_output,
            workspace_dir=workspace,
            manifest_path=bundle.manifest_path,
        )
    finally:
        if preflight_emitted and not release_emitted:
            _emit_operator_notice(
                "Native TMT UI automation is complete/stopped and you may "
                "resume using the computer."
            )


def run_harness(
    *,
    input_model: Path,
    evidence_dir: Path,
    mode: str = "validate",
    comparison_model: Path | None = None,
    upgraded_model_output: Path | None = None,
    require_tmt: bool = False,
    pinned_version: str = DEFAULT_PINNED_VERSION,
    diagnostic_override: bool = False,
    workspace_root: Path | None = None,
    timeout_seconds: float = DEFAULT_TIMEOUT_SECONDS,
    expected_threat_count: int | None = None,
    expected_custom_type_count: int | None = None,
    template_upgrade_policy: str = "fail",
    delete_stale_threats: bool = False,
    feedback_loop: bool = False,
    spec_path: Path | None = None,
    overlay_input: Path | None = None,
    overlay_output: Path | None = None,
    max_iterations: int = DEFAULT_MAX_ITERATIONS,
    require_feedback_evidence: bool = False,
) -> HarnessResult | FeedbackLoopResult:
    """Execute native validation, comparison, or controlled template upgrade.

    ``expected_threat_count`` is an optional caller assertion. It defaults to
    ``None`` so a model of any size is accepted; a fixed count would reject
    every model that does not happen to match it.
    """
    try:
        _validate_feedback_loop_args(
            feedback_loop=feedback_loop,
            spec_path=spec_path,
            overlay_output=overlay_output,
            max_iterations=max_iterations,
        )
    except HarnessFailure as exc:
        evidence_dir = Path(evidence_dir).resolve()
        bundle = EvidenceBundle(evidence_dir)
        manifest = {
            "mode": mode,
            "required_tmt_version": pinned_version,
            "feedback_loop": feedback_loop,
            "spec_path": str(spec_path) if spec_path is not None else None,
            "overlay_output": (
                str(overlay_output) if overlay_output is not None else None
            ),
        }
        bundle.write_manifest(manifest)
        bundle.write_status(
            _status_payload(
                result="error",
                exit_code=exc.exit_code,
                message=str(exc),
                bundle=bundle,
                manifest=manifest,
            )
        )
        return HarnessResult(exc.exit_code, "error", str(exc), evidence_dir)

    if feedback_loop:
        return run_feedback_loop(
            baseline_model=input_model,
            spec_path=spec_path,
            overlay_input=overlay_input,
            overlay_output=overlay_output,
            max_iterations=max_iterations,
            require_feedback_evidence=require_feedback_evidence,
            evidence_dir=evidence_dir,
            workspace_root=workspace_root,
            require_tmt=require_tmt,
            pinned_version=pinned_version,
            diagnostic_override=diagnostic_override,
            timeout_seconds=timeout_seconds,
            expected_threat_count=expected_threat_count,
            expected_custom_type_count=expected_custom_type_count,
            template_upgrade_policy=template_upgrade_policy,
            delete_stale_threats=delete_stale_threats,
        )
    input_model = Path(input_model).resolve()
    evidence_dir = Path(evidence_dir).resolve()
    bundle = EvidenceBundle(evidence_dir)
    workspace = prepare_owned_workspace(workspace_root, evidence_dir)
    manifest: dict[str, Any] = {
        "mode": mode,
        "required_tmt_version": pinned_version,
        "observed_tmt_version": None,
        "diagnostic_override": diagnostic_override,
        "require_tmt": require_tmt,
        "expected_threat_count": expected_threat_count,
        "expected_custom_type_count": expected_custom_type_count,
        "input_model": str(input_model),
        "input_sha256": sha256_file(input_model) if input_model.is_file() else None,
        "comparison_model": str(comparison_model) if comparison_model else None,
        "upgraded_model_output": (
            str(upgraded_model_output) if upgraded_model_output else None
        ),
        "template_upgrade_policy": template_upgrade_policy,
        "delete_stale_threats": delete_stale_threats,
        "started_at": datetime.now(timezone.utc).isoformat(),
        "evidence_schema_version": EVIDENCE_SCHEMA_VERSION,
    }
    bundle.write_manifest(manifest)
    if not input_model.is_file():
        failure = HarnessFailure("Input model does not exist", EXIT_ERROR)
        bundle.write_status(
            _status_payload(
                result="error",
                exit_code=failure.exit_code,
                message=str(failure),
                bundle=bundle,
                manifest=manifest,
            )
        )
        return HarnessResult(failure.exit_code, "error", str(failure), evidence_dir)

    discovery = discover_tmt_application()
    manifest["observed_tmt_version"] = discovery.version
    manifest["discovery_source"] = discovery.source
    bundle.write_manifest(manifest)
    if discovery.path is None:
        status = "missing-tmt" if require_tmt else "skipped"
        exit_code = EXIT_MISSING_TMT if require_tmt else EXIT_SUCCESS
        message = "TMT was not found" if require_tmt else "TMT not found; local skip"
        bundle.write_status(
            _status_payload(
                result=status,
                exit_code=exit_code,
                message=message,
                bundle=bundle,
                manifest=manifest,
            )
        )
        return HarnessResult(exit_code, status, message, evidence_dir)

    policy = evaluate_version_policy(
        TmtVersionPolicy(pinned_version, discovery.version, diagnostic_override)
    )
    if not policy.allowed:
        bundle.write_status(
            _status_payload(
                result="version-mismatch",
                exit_code=policy.exit_code,
                message=policy.reason,
                bundle=bundle,
                manifest=manifest,
            )
        )
        return HarnessResult(
            policy.exit_code,
            "version-mismatch",
            policy.reason,
            evidence_dir,
        )

    success = False
    try:
        if mode == "upgrade-template":
            if upgraded_model_output is None:
                raise HarnessFailure(
                    "upgrade-template requires --upgraded-model-output",
                    EXIT_ERROR,
                )
            details = _upgrade_template_candidate(
                executable=discovery.path,
                input_model=input_model,
                output_model=Path(upgraded_model_output).resolve(),
                workspace=workspace,
                bundle=bundle,
                timeout_seconds=timeout_seconds,
                expected_threat_count=expected_threat_count,
                expected_custom_type_count=expected_custom_type_count,
                delete_stale_threats=delete_stale_threats,
            )
        elif mode == "compare-generation-state":
            if comparison_model is None or not Path(comparison_model).is_file():
                raise HarnessFailure(
                    "compare-generation-state requires --comparison-model",
                    EXIT_ERROR,
                )
            first_bundle = EvidenceBundle(evidence_dir / "candidate-a")
            second_bundle = EvidenceBundle(evidence_dir / "candidate-b")
            first_workspace = workspace / "candidate-a"
            second_workspace = workspace / "candidate-b"
            first_workspace.mkdir()
            second_workspace.mkdir()
            first = _validate_candidate(
                executable=discovery.path,
                input_model=input_model,
                workspace=first_workspace,
                bundle=first_bundle,
                mode="validate",
                timeout_seconds=timeout_seconds,
                expected_threat_count=expected_threat_count,
                template_upgrade_policy=template_upgrade_policy,
                delete_stale_threats=delete_stale_threats,
            )
            second = _validate_candidate(
                executable=discovery.path,
                input_model=Path(comparison_model).resolve(),
                workspace=second_workspace,
                bundle=second_bundle,
                mode="validate",
                timeout_seconds=timeout_seconds,
                expected_threat_count=expected_threat_count,
                template_upgrade_policy=template_upgrade_policy,
                delete_stale_threats=delete_stale_threats,
            )
            first_instances = first["before_summary"]["instances"]
            second_instances = second["before_summary"]["instances"]
            if first_instances != second_instances:
                raise HarnessFailure(
                    "Generation-state candidates are not semantically identical",
                    EXIT_VALIDATION_FAILURE,
                )
            details: dict[str, Any] = {"candidate_a": first, "candidate_b": second}
        else:
            details = _validate_candidate(
                executable=discovery.path,
                input_model=input_model,
                workspace=workspace,
                bundle=bundle,
                mode=mode,
                timeout_seconds=timeout_seconds,
                expected_threat_count=expected_threat_count,
                template_upgrade_policy=template_upgrade_policy,
                delete_stale_threats=delete_stale_threats,
                require_feedback_evidence=(
                    True if mode == "calibration-smoke" else require_feedback_evidence
                ),
            )
        manifest.update(
            {
                "completed_at": datetime.now(timezone.utc).isoformat(),
                "result": "passed",
                "details": details,
            }
        )
        bundle.write_manifest(manifest)
        status = _status_payload(
            result="passed",
            exit_code=EXIT_SUCCESS,
            message="Native TMT validation completed",
            bundle=bundle,
            manifest=manifest,
        )
        bundle.write_status(status)
        success = True
        return HarnessResult(
            EXIT_SUCCESS,
            "passed",
            status["message"],
            evidence_dir,
            workspace,
            bundle.manifest_path,
        )
    except HarnessFailure as exc:
        manifest.update(
            {
                "completed_at": datetime.now(timezone.utc).isoformat(),
                "result": "failed",
                "failure": str(exc),
            }
        )
        bundle.write_manifest(manifest)
        status = _status_payload(
            result="failed",
            exit_code=exc.exit_code,
            message=str(exc),
            bundle=bundle,
            manifest=manifest,
        )
        bundle.write_status(status)
        return HarnessResult(
            exc.exit_code,
            "failed",
            str(exc),
            evidence_dir,
            workspace,
            bundle.manifest_path,
        )
    finally:
        if success:
            bundle.cleanup_workspace(workspace)


def create_parser() -> argparse.ArgumentParser:
    """Create the native harness command-line parser."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input_model", type=Path)
    parser.add_argument("--evidence-dir", type=Path, required=True)
    parser.add_argument(
        "--mode",
        choices=[
            "probe",
            "calibration-smoke",
            "validate",
            "compare-generation-state",
            "upgrade-template",
        ],
        default="validate",
    )
    parser.add_argument("--feedback-loop", action="store_true")
    parser.add_argument("--spec", type=Path)
    parser.add_argument("--overlay-input", type=Path)
    parser.add_argument("--overlay-output", type=Path)
    parser.add_argument("--max-iterations", type=int, default=DEFAULT_MAX_ITERATIONS)
    parser.add_argument("--require-feedback-evidence", action="store_true")
    parser.add_argument("--comparison-model", type=Path)
    parser.add_argument("--upgraded-model-output", type=Path)
    parser.add_argument(
        "--template-upgrade-policy",
        choices=["fail", "decline", "apply"],
        default="fail",
        help="Action when TMT offers a newer template",
    )
    parser.add_argument(
        "--delete-stale-threats",
        action="store_true",
        help="Delete stale threats while applying a newer template",
    )
    parser.add_argument("--require-tmt", action="store_true")
    parser.add_argument("--pinned-version", default=DEFAULT_PINNED_VERSION)
    parser.add_argument("--diagnostic-override", action="store_true")
    parser.add_argument("--workspace-root", type=Path)
    parser.add_argument(
        "--timeout-seconds",
        type=float,
        default=DEFAULT_TIMEOUT_SECONDS,
    )
    parser.add_argument(
        "--expected-threat-count",
        type=int,
        default=None,
        help=(
            "Assert the model carries exactly this many threat instances. "
            "Omit to accept any count."
        ),
    )
    parser.add_argument("--expected-custom-type-count", type=int)
    parser.add_argument("-v", "--verbose", action="store_true")
    return parser


def main() -> int:
    """Run the native application harness."""
    args = create_parser().parse_args()
    configure_logging(args.verbose)
    try:
        result = run_harness(
            input_model=args.input_model,
            evidence_dir=args.evidence_dir,
            mode=args.mode,
            comparison_model=args.comparison_model,
            upgraded_model_output=args.upgraded_model_output,
            require_tmt=args.require_tmt,
            pinned_version=args.pinned_version,
            diagnostic_override=args.diagnostic_override,
            workspace_root=args.workspace_root,
            timeout_seconds=args.timeout_seconds,
            expected_threat_count=args.expected_threat_count,
            expected_custom_type_count=args.expected_custom_type_count,
            template_upgrade_policy=args.template_upgrade_policy,
            delete_stale_threats=args.delete_stale_threats,
            feedback_loop=args.feedback_loop,
            spec_path=args.spec,
            overlay_input=args.overlay_input,
            overlay_output=args.overlay_output,
            max_iterations=args.max_iterations,
            require_feedback_evidence=args.require_feedback_evidence,
        )
    except KeyboardInterrupt:
        # An operator aborting a native run is expected, and the release notice
        # has already fired from the harness finally block.
        print("\nInterrupted by user", file=sys.stderr)
        return EXIT_INTERRUPTED
    except BrokenPipeError:
        sys.stderr.close()
        return EXIT_ERROR
    print(f"status={result.status} exit_code={result.exit_code} {result.message}")
    return result.exit_code


if __name__ == "__main__":
    sys.exit(main())
