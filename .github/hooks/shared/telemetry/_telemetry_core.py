#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Canonical telemetry engine shared by the Copilot hook collectors.

This module is the single source of truth for telemetry collection. The bash
collector invokes the ``collect`` mode to record one hook event (and enrich
the session at ``Stop``, ``SessionEnd``, and ``PreCompact``), while the report
generators invoke the
``aggregate-debug``, ``aggregate-session``, and ``list-dirs`` modes to join
model/token data and discover per-project telemetry stores for reports.
Clean scripts invoke the ``clean`` mode to remove telemetry artifacts
from one or every registered store.

The PowerShell collector ``Invoke-TelemetryCollector.ps1`` is a thin wrapper
that delegates to this same engine via ``collect``, so the collection logic
stays single-sourced across platforms.
"""

from __future__ import annotations

import datetime
import glob
import hashlib
import json
import os
import secrets
import shlex
import shutil
import sys
import time
from collections.abc import Iterable, Iterator
from pathlib import Path, PureWindowsPath
from typing import Any

if os.name == "nt":
    import msvcrt


def _detect_client() -> str:
    """Infer the Copilot surface that invoked this hook."""
    if os.environ.get("GITHUB_COPILOT_API_TOKEN"):
        return "cloud-agent"
    if os.environ.get("VSCODE_PID") or os.environ.get("VSCODE_IPC_HOOK_CLI"):
        return "vscode"
    return "cli"


EVENT_ALIASES = {
    "sessionStart": "SessionStart",
    "userPromptSubmitted": "UserPromptSubmit",
    "preToolUse": "PreToolUse",
    "postToolUse": "PostToolUse",
    "subagentStart": "SubagentStart",
    "subagentStop": "SubagentStop",
    "agentStop": "Stop",
    "sessionEnd": "SessionEnd",
    "preCompact": "PreCompact",
}

# Documented sessionEnd ``reason`` values (GitHub Copilot hooks reference).
# Shape inference matches only these so an unrelated ``reason`` key on some
# other or future event is not mistaken for a session end.
SESSION_END_REASONS = frozenset({"complete", "error", "abort", "timeout", "user_exit"})

# Canonical field -> the payload keys that carry it, in priority order. Three
# documented payload formats reach this collector: VS Code (snake_case), the
# Copilot CLI camelCase format, and the CLI "VS Code compatible" format it sends
# when events are configured in PascalCase. They disagree on both casing and
# naming (tool output is ``tool_response`` in VS Code, ``tool_result`` in the
# CLI compatible format, ``toolResult`` in CLI camelCase). This table is the
# only place surface-specific key names appear, so shape inference and entry
# building cannot drift apart when a surface adds or renames a key. Add keys
# only when a surface documents them.
PAYLOAD_ALIASES: dict[str, tuple[str, ...]] = {
    "event_name": ("hook_event_name", "hookEventName", "event"),
    "session_id": ("session_id", "sessionId"),
    "cwd": ("cwd",),
    "timestamp": ("timestamp",),
    "tool_name": ("tool_name", "toolName"),
    "tool_input": ("tool_input", "toolArgs"),
    "tool_use_id": ("tool_use_id", "toolUseId"),
    "tool_result": ("tool_response", "tool_result", "toolResult"),
    "tool_result_text": ("text_result_for_llm", "textResultForLlm"),
    # VS Code names the subagent only as ``agent_type``; the CLI sends a name.
    "agent_name": ("agent_name", "agentName", "agent_type", "agentType"),
    # Unique per subagent invocation on VS Code; absent on surfaces that send
    # only a name, which then has to serve as the identity.
    "agent_id": ("agent_id", "agentId"),
    "agent_display_name": ("agent_display_name", "agentDisplayName"),
    "prompt": ("prompt",),
    "source": ("source",),
    "trigger": ("trigger",),
    "stop_reason": ("stop_reason", "stopReason"),
    "reason": ("reason",),
}


def _payload_get(data: dict, field: str, default: Any = "") -> Any:
    """Return the first non-empty alias value for a canonical payload field."""
    for key in PAYLOAD_ALIASES[field]:
        value = data.get(key)
        if value:
            return value
    return default


def _payload_has(data: dict, field: str) -> bool:
    """Return True when a payload carries any alias of a canonical field."""
    return any(key in data for key in PAYLOAD_ALIASES[field])


def iter_jsonl(path: str | os.PathLike[str]) -> Iterator[dict]:
    """Yield each well-formed JSON object from a JSONL file, skipping junk."""
    try:
        with open(path, encoding="utf-8") as handle:
            for line in handle:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except ValueError:
                    continue
                if isinstance(obj, dict):
                    yield obj
    except OSError:
        # File cannot be opened or read (e.g., does not exist or permission denied)
        return


def _fallback_stem() -> str:
    """Return a filename stem no other live collector process will produce.

    The UTC time orders fallback files beside their day log, the pid separates
    concurrent writers, and the random suffix keeps a recycled pid from
    reopening a departed process's file. The suffix carries the uniqueness on
    Windows, whose clock resolution is coarse enough to collapse the timestamp
    for writers started in the same tick.
    """
    stamp = datetime.datetime.now(datetime.UTC).strftime("%H%M%S%f")
    return f"{stamp}-{os.getpid()}-{secrets.token_hex(8)}"


# O_BINARY keeps Windows from expanding "\n" and desynchronizing the byte count.
_APPEND_FLAGS = os.O_WRONLY | os.O_CREAT | os.O_APPEND | getattr(os, "O_BINARY", 0)

# Telemetry records carry prompt previews and working-directory paths, and the
# registry carries every store location, so nothing here is readable by group or
# other. umask can only clear further bits, never restore them.
_OWNER_ONLY_FILE = 0o600
_OWNER_ONLY_EXEC = 0o700


def _write_all(fd: int, payload: bytes) -> None:
    """Write every byte; a signal or a full disk can cut one write short."""
    view = memoryview(payload)
    while view:
        written = os.write(fd, view)
        if not written:
            # Retrying a write that consumed nothing spins forever inside a
            # synchronous hook, so surface it to the caller's fallback instead.
            raise OSError("write made no progress")
        view = view[written:]


# Copilot runs hooks concurrently: parallel tool calls and subagents each spawn
# their own collector process, and they share one log per day. POSIX resolves
# O_APPEND under the inode lock, so nothing further is needed there. The Windows
# CRT emulates O_APPEND as seek-to-end plus write in user space, so racing
# collectors resolve the same offset and the second overwrites the first; a
# byte-range lock closes that window. A writer that cannot take the lock falls
# back to a private shard, which readers merge alongside the log.
if os.name == "nt":
    # A record is a few hundred bytes, so a collision clears in microseconds.
    # LK_LOCK would sleep a full second per retry for up to ten seconds, which
    # is charged to the agent turn; poll instead, at the timescale of the write.
    _LOCK_ATTEMPTS = 2000
    _LOCK_BACKOFF_SECONDS = 0.001

    def _lock_append(fd: int) -> bool:
        """Take the byte-0 mutex and seek to end. False if the lock is refused.

        Byte 0 is never read as data; it is only somewhere to anchor the lock.
        Windows drops the lock when the handle closes, including on a crash, so
        a dead collector cannot wedge the log.
        """
        os.lseek(fd, 0, os.SEEK_SET)
        for _ in range(_LOCK_ATTEMPTS):
            try:
                msvcrt.locking(fd, msvcrt.LK_NBLCK, 1)
            except OSError:
                time.sleep(_LOCK_BACKOFF_SECONDS)
                continue
            os.lseek(fd, 0, os.SEEK_END)
            return True
        return False

    def _unlock_append(fd: int) -> None:
        os.lseek(fd, 0, os.SEEK_SET)
        try:
            msvcrt.locking(fd, msvcrt.LK_UNLCK, 1)
        except OSError:
            # The lock is released by the close in _append_shared's finally, and
            # by the OS if this process dies, so a failed explicit unlock leaves
            # nothing to repair and must not mask the record that was written.
            pass

else:

    def _lock_append(fd: int) -> bool:
        """POSIX appends atomically under O_APPEND; there is no lock to take."""
        return True

    def _unlock_append(fd: int) -> None:
        return


def append_line(target: Path, line: str) -> None:
    """Append one newline-terminated line to the shared log for its day.

    Best-effort: a store that cannot be written is a telemetry failure, not a
    turn failure, so every path returns rather than raising into the hook.

    Args:
        target: The shared log path. Its parent is created when missing, and a
            sibling shard is used when the log cannot be locked or written.
        line: The record text, already newline-terminated by the caller.
    """
    payload = line.encode("utf-8")
    try:
        target.parent.mkdir(parents=True, exist_ok=True)
        if _append_shared(target, payload):
            return
    except OSError:
        # A refused lock returns False; an unwritable or torn log raises. Both
        # reach the shard below, which is the only way the record still lands.
        pass
    # A filesystem that refuses locks would let writers interleave, so this
    # process takes a file of its own. Readers match the shard alongside the
    # log, so the record still lands.
    try:
        _append_private(
            target.with_name(f"{target.stem}.{_fallback_stem()}{target.suffix}"), payload
        )
    except OSError:
        # Nothing in this store is writable; drop the record.
        return


def _append_shared(target: Path, payload: bytes) -> bool:
    """Append under the platform's append guarantee. False if unavailable."""
    fd = os.open(target, _APPEND_FLAGS, _OWNER_ONLY_FILE)
    try:
        if not _lock_append(fd):
            return False
        try:
            _write_all(fd, payload)
        finally:
            _unlock_append(fd)
    finally:
        os.close(fd)
    return True


def _append_private(target: Path, payload: bytes) -> None:
    """Append to a file only this process writes, so no lock is required."""
    fd = os.open(target, _APPEND_FLAGS, _OWNER_ONLY_FILE)
    try:
        _write_all(fd, payload)
    finally:
        os.close(fd)


def append_jsonl(target: Path, entry: dict) -> None:
    """Append one JSON object as a JSONL record.

    Args:
        target: The shared log path, as for :func:`append_line`.
        entry: The record, serialized on one line.
    """
    append_line(target, json.dumps(entry) + "\n")


def _write_text_atomic(path: Path, text: str, mode: int = _OWNER_ONLY_FILE) -> None:
    """Replace ``path`` in one step so a reader never observes a partial file.

    Plain truncate-then-write leaves a window in which the file is empty or
    half written, and every collector racing on ``first_write`` rewrites these
    files at once. The temp name carries the pid so concurrent writers do not
    collide on the staging file itself.

    Args:
        path: The destination, replaced by an atomic rename.
        text: The full file contents, written as UTF-8.
        mode: Permission bits the staging file is created with, so the content
            is never briefly readable more widely than the destination.
    """
    tmp = path.with_name(f"{path.name}.{os.getpid()}.tmp")
    try:
        fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, mode)
        try:
            _write_all(fd, text.encode("utf-8"))
        finally:
            os.close(fd)
        os.replace(tmp, path)
    except OSError:
        tmp.unlink(missing_ok=True)
        raise


def _is_safe_sid(sid: str) -> bool:
    """Return True when a session id is safe to embed in a filesystem path.

    Rejects empty ids and any value containing a path separator or ``..``
    traversal sequence so callers never build paths outside their store. A bare
    drive or UNC specifier such as ``C:`` holds no separator yet still re-anchors
    the path when joined, discarding the store prefix, so reject anchors too.
    """
    if not sid or ".." in sid:
        return False
    if os.sep in sid or "/" in sid or "\\" in sid:
        return False
    return not PureWindowsPath(sid).anchor


def _is_contained(child: Path, parent: Path) -> bool:
    """Return True when ``child`` resolves inside ``parent``.

    Checked immediately before a destructive operation so a path that escaped
    its store cannot be removed, whatever produced it.
    """
    try:
        return child.resolve().is_relative_to(parent.resolve())
    except OSError:
        return False


def collect_sids(hook_files: Iterable[str]) -> set[str]:
    """Collect every safe session id referenced across the given hook files."""
    sids: set[str] = set()
    for hook_file in hook_files:
        for obj in iter_jsonl(hook_file):
            sid = obj.get("sid")
            if sid and _is_safe_sid(sid):
                sids.add(sid)
    return sids


def copilot_home() -> Path:
    """Return the Copilot home directory, honoring ``COPILOT_HOME``."""
    override = os.environ.get("COPILOT_HOME")
    return Path(override) if override else Path.home() / ".copilot"


def hve_home() -> Path:
    """Return the HVE user-level directory, honoring ``HVE_HOME``."""
    override = os.environ.get("HVE_HOME")
    return Path(override) if override else Path.home() / ".hve"


def telemetry_registry() -> Path:
    """Return the user-level registry of per-project telemetry dirs.

    A directory holding one marker per store rather than a shared list file:
    every writer targets a distinct path and rewriting it is a no-op, so
    collectors racing on the first write of the day need no coordination.
    """
    return hve_home() / "telemetry-dirs"


def _registry_marker(registry: Path, resolved: str) -> Path:
    """Return the marker path for one store, named by a digest of its path."""
    return registry / f"{hashlib.sha256(resolved.encode('utf-8')).hexdigest()[:32]}.path"


# Registry file used before the marker directory: one absolute path per line.
_LEGACY_REGISTRY_NAME = "telemetry-dirs.txt"


def _migrate_legacy_registry(registry: Path) -> None:
    """Import the pre-directory registry file once, then retire it.

    Without this an upgraded install silently drops every store it had already
    registered. Active projects re-register on their next event, but a retired
    one never does, and that is exactly the set ``clean --all-dirs`` exists to
    reclaim. Renaming rather than deleting keeps the original recoverable.
    """
    legacy = registry.parent / _LEGACY_REGISTRY_NAME
    try:
        if not legacy.is_file():
            return
        lines = legacy.read_text(encoding="utf-8").splitlines()
    except OSError:
        return
    for line in lines:
        entry = line.strip()
        if entry:
            register_telemetry_dir(Path(entry), registry)
    try:
        legacy.rename(legacy.with_name(_LEGACY_REGISTRY_NAME + ".migrated"))
    except OSError:
        # Left in place; re-importing is idempotent, so the next call retries.
        return


def read_registry_dirs(registry: Path | None = None) -> list[str]:
    """Return registered telemetry directories, sorted and de-duplicated."""
    registry = registry if registry is not None else telemetry_registry()
    _migrate_legacy_registry(registry)
    try:
        markers = sorted(registry.glob("*.path"))
    except OSError:
        # Registry dir is missing or unreadable; treat as no registered dirs.
        return []
    dirs: set[str] = set()
    for marker in markers:
        try:
            entry = marker.read_text(encoding="utf-8").strip()
        except OSError:
            continue
        if entry:
            dirs.add(entry)
    return sorted(dirs)


def register_telemetry_dir(tel_dir: Path, registry: Path | None = None) -> None:
    """Record an absolute telemetry directory in the user-level registry.

    Lets the report tooling discover every per-project telemetry store without
    relying on environment propagation. Resolves to an absolute path and writes
    the marker whole, so repeated and concurrent registrations converge on the
    same content instead of appending duplicates.
    """
    registry = registry if registry is not None else telemetry_registry()
    try:
        resolved = str(tel_dir.resolve())
    except OSError:
        resolved = os.path.abspath(str(tel_dir))
    marker = _registry_marker(registry, resolved)
    if marker.exists():
        return
    try:
        registry.mkdir(parents=True, exist_ok=True)
        _write_text_atomic(marker, resolved + "\n")
    except OSError:
        # Cannot create the registry entry; skip recording this dir.
        return


_BASH_LAUNCHER = """#!/usr/bin/env bash
# Generated by HVE telemetry. Regenerated each session; edits will be lost.
# Cross-project telemetry report launcher. Lives in the HVE home directory
# alongside the registry of per-project telemetry stores, so it does not need
# the (version-pinned) extension install path. Run from this directory:
#   ./generate-report.sh                # today, every project
#   ./generate-report.sh --date all     # every captured day, every project
REPORT_SCRIPT=__REPORT_SCRIPT__
if [[ ! -f "$REPORT_SCRIPT" ]]; then
  echo "Telemetry report script not found: $REPORT_SCRIPT" >&2
  echo "Start a new Copilot session to regenerate this launcher." >&2
  exit 1
fi
exec bash "$REPORT_SCRIPT" --all-dirs --output __OUT__ "$@"
"""

_PWSH_LAUNCHER = """# Generated by HVE telemetry. Regenerated each session; edits will be lost.
# Cross-project telemetry report launcher. Lives in the HVE home directory
# alongside the registry of per-project telemetry stores. Runs natively through
# PowerShell. Run from this directory:
#   ./generate-report.ps1                 # today, every project
#   ./generate-report.ps1 -Date all       # every captured day, every project
$ReportScript = '__REPORT_SCRIPT__'
if (-not (Test-Path $ReportScript)) {
    Write-Error "Telemetry report script not found: $ReportScript"
    Write-Error 'Start a new Copilot session to regenerate this launcher.'
    exit 1
}
& $ReportScript -AllDirs -Output '__OUT__' @args
"""


_BASH_CLEAN_LAUNCHER = """#!/usr/bin/env bash
# Generated by HVE telemetry. Regenerated each session; edits will be lost.
# Cross-project telemetry cleanup launcher. Removes telemetry artifacts from
# every registered per-project store and this HVE home directory. Run from
# this directory:
#   ./clean-telemetry.sh             # remove all telemetry artifacts
#   ./clean-telemetry.sh --dry-run   # list what would be removed
CLEAN_SCRIPT=__CLEAN_SCRIPT__
if [[ ! -f "$CLEAN_SCRIPT" ]]; then
  echo "Telemetry clean script not found: $CLEAN_SCRIPT" >&2
  echo "Start a new Copilot session to regenerate this launcher." >&2
  exit 1
fi
exec bash "$CLEAN_SCRIPT" --all-dirs "$@"
"""

_PWSH_CLEAN_LAUNCHER = """\
# Generated by HVE telemetry. Regenerated each session; edits will be lost.
# Cross-project telemetry cleanup launcher. Removes telemetry artifacts from
# every registered per-project store and this HVE home directory. Runs natively
# through PowerShell. Run from this directory:
#   ./clean-telemetry.ps1             # remove all telemetry artifacts
#   ./clean-telemetry.ps1 -DryRun     # list what would be removed
$CleanScript = '__CLEAN_PS1__'
if (-not (Test-Path $CleanScript)) {
    Write-Error "Telemetry clean script not found: $CleanScript"
    Write-Error 'Start a new Copilot session to regenerate this launcher.'
    exit 1
}
& $CleanScript -AllDirs @args
"""


def _is_windows() -> bool:
    """Return True when running on Windows.

    Factored out so launcher generation can pick the native interpreter and so
    tests can exercise both platform branches.
    """
    return os.name == "nt"


def write_report_launchers(script_dir: Path | None = None) -> None:
    """Emit cross-project report and cleanup launchers into the HVE home dir.

    Extension users lack the repository's launcher scripts and cannot easily
    locate the version-pinned extension install path. These launchers live next
    to the registry in the HVE home directory, are refreshed each session, and
    delegate to the canonical report generator and cleanup wrappers in
    cross-project mode so running them spans every project.

    Only the launchers for the host platform are written: PowerShell (``.ps1``)
    on Windows, POSIX shell (``.sh``) elsewhere. Both the report and cleanup
    launchers are fully native per platform (bash wrappers on POSIX, PowerShell
    wrappers on Windows), so no cross-interpreter dependency is required.
    """
    if script_dir is None:
        script_dir = Path(__file__).resolve().parent
    report_script = str(script_dir / "generate-telemetry-report.sh")
    report_ps1 = str(script_dir / "Invoke-TelemetryReport.ps1")
    clean_script = str(script_dir / "clean-telemetry.sh")
    clean_ps1 = str(script_dir / "Invoke-TelemetryClean.ps1")
    home = hve_home()
    out_path = str(home / "report.generated.html")
    try:
        home.mkdir(parents=True, exist_ok=True)
        if _is_windows():
            # Quote for PowerShell single-quoted strings (double embedded ').
            pwsh_text = _PWSH_LAUNCHER.replace(
                "__REPORT_SCRIPT__", report_ps1.replace("'", "''")
            ).replace("__OUT__", out_path.replace("'", "''"))
            pwsh_clean_text = _PWSH_CLEAN_LAUNCHER.replace(
                "__CLEAN_PS1__", clean_ps1.replace("'", "''")
            )
            _write_text_atomic(home / "generate-report.ps1", pwsh_text)
            _write_text_atomic(home / "clean-telemetry.ps1", pwsh_clean_text)
        else:
            # Shell-quote so unusual install paths (spaces, quotes, ``$``)
            # cannot break or inject into the generated launchers.
            bash_text = _BASH_LAUNCHER.replace(
                "__REPORT_SCRIPT__", shlex.quote(report_script)
            ).replace("__OUT__", shlex.quote(out_path))
            bash_clean_text = _BASH_CLEAN_LAUNCHER.replace(
                "__CLEAN_SCRIPT__", shlex.quote(clean_script)
            )
            _write_text_atomic(home / "generate-report.sh", bash_text, mode=_OWNER_ONLY_EXEC)
            _write_text_atomic(home / "clean-telemetry.sh", bash_clean_text, mode=_OWNER_ONLY_EXEC)
    except OSError:
        # Cannot write launchers (e.g., permission denied); skip generation.
        return


def find_process_log(state_dir: Path, home: Path) -> str | None:
    """Locate the CLI process log via the session lock file PID."""
    pid = None
    try:
        for lock_file in os.listdir(state_dir):
            if lock_file.startswith("inuse.") and lock_file.endswith(".lock"):
                pid = lock_file.split(".")[1]
                break
    except OSError:
        # State dir cannot be listed (e.g., does not exist); no log to find.
        return None
    if not pid:
        return None
    candidates = glob.glob(str(home / "logs" / f"process-*-{pid}.log"))
    return candidates[0] if candidates else None


def _log_references_interactions(log_path: str, interaction_ids: set[str]) -> bool:
    """Return True when a process log references any of the interaction ids.

    Uses a cheap line substring scan so logs that cannot belong to the session
    are rejected without a full JSON parse.
    """
    try:
        with open(log_path, encoding="utf-8", errors="replace") as handle:
            for line in handle:
                if "interaction_id" in line and any(iid in line for iid in interaction_ids):
                    return True
    except OSError:
        # Log cannot be read; treat as not referencing this session.
        return False
    return False


def find_process_logs_for_session(
    state_dir: Path, home: Path, interaction_ids: set[str]
) -> list[str]:
    """Return the process logs that hold usage for a session.

    Prefers the log named after the live session lock PID. When that lock is
    gone (the session has ended), falls back to scanning every process log for
    one whose entries reference this session's interaction ids, so per-request
    input token data survives past session end rather than degrading to the
    compaction-only state fallback.
    """
    locked = find_process_log(state_dir, home)
    if locked:
        return [locked]
    if not interaction_ids:
        return []
    matches: list[str] = []
    for path in sorted(glob.glob(str(home / "logs" / "process-*.log"))):
        if _log_references_interactions(path, interaction_ids):
            matches.append(path)
    return matches


def parse_process_log(log_path: str, interaction_ids: set[str]) -> list[dict]:
    """Parse assistant_usage blocks from a process log, filtered by id."""
    results: list[dict] = []
    # Process logs use brace-delimited JSON blocks (one top-level '{' … '}' per
    # entry) rather than newline-delimited JSON, so we accumulate lines between
    # matching braces and only parse blocks containing assistant_usage data.
    in_block = False
    block_lines: list[str] = []
    block_has_usage = False
    try:
        with open(log_path, encoding="utf-8") as handle:
            for line in handle:
                stripped = line.rstrip()
                if stripped == "{":
                    in_block = True
                    block_lines = [stripped]
                    block_has_usage = False
                elif in_block:
                    block_lines.append(stripped)
                    if '"assistant_usage"' in stripped:
                        block_has_usage = True
                    if stripped == "}":
                        if block_has_usage:
                            try:
                                obj = json.loads("\n".join(block_lines))
                            except ValueError:
                                obj = None
                            if obj and obj.get("kind") == "assistant_usage":
                                props = obj.get("properties", {})
                                if props.get("interaction_id", "") in interaction_ids:
                                    results.append(obj)
                        in_block = False
                        block_lines = []
    except OSError:
        # Log cannot be read; return whatever was parsed so far.
        return results
    return results


def scan_session_state(state_file: str | os.PathLike[str]) -> dict:
    """Read events.jsonl once for session metadata and interaction ids."""
    interaction_ids: set[str] = set()
    models: dict[str, int] = {}
    subagent_map: dict[str, str] = {}
    messages = 0
    turns = 0
    reasoning_effort = ""
    first_ts = ""
    last_ts = ""
    for evt in iter_jsonl(state_file):
        data = evt.get("data", {})
        if not isinstance(data, dict):
            continue
        ts = evt.get("timestamp", "")
        if ts:
            if not first_ts or ts < first_ts:
                first_ts = ts
            if not last_ts or ts > last_ts:
                last_ts = ts
        etype = evt.get("type", "")
        if etype == "assistant.message":
            messages += 1
            model = data.get("model", "")
            if model:
                models[model] = models.get(model, 0) + 1
            iid = data.get("interactionId", "")
            if iid:
                interaction_ids.add(iid)
        elif etype == "assistant.turn_start":
            turns += 1
            iid = data.get("interactionId", "")
            if iid:
                interaction_ids.add(iid)
        elif etype == "session.model_change":
            reasoning_effort = data.get("reasoningEffort", "")
        elif etype == "subagent.started":
            tcid = data.get("toolCallId", "")
            aname = data.get("agentName", "") or data.get("agentDisplayName", "")
            if tcid and aname:
                subagent_map[tcid] = aname
    return {
        "interaction_ids": interaction_ids,
        "models": models,
        "subagent_map": subagent_map,
        "messages": messages,
        "turns": turns,
        "reasoning_effort": reasoning_effort,
        "first_ts": first_ts,
        "last_ts": last_ts,
    }


def _totals_from_process_log(entries: list[dict]) -> dict:
    """Accumulate token totals and per-model usage from process-log entries."""
    total_input = total_output = cache_read = cache_write = total_nano_aiu = 0
    total_input_uncached = 0
    model_usage: dict[str, dict] = {}
    for entry in entries:
        props = entry.get("properties", {})
        metrics = entry.get("metrics", {})
        model = props.get("model", "unknown")
        total_input += metrics.get("input_tokens", 0)
        total_input_uncached += metrics.get("input_tokens_uncached", 0)
        total_output += metrics.get("output_tokens", 0)
        cache_read += metrics.get("cache_read_tokens", 0)
        cache_write += metrics.get("cache_write_tokens", 0)
        total_nano_aiu += metrics.get("total_nano_aiu", 0)
        bucket = model_usage.setdefault(
            model,
            {
                "output_tokens": 0,
                "messages": 0,
                "input_tokens": 0,
                "input_tokens_uncached": 0,
            },
        )
        bucket["output_tokens"] += metrics.get("output_tokens", 0)
        bucket["input_tokens"] += metrics.get("input_tokens", 0)
        bucket["input_tokens_uncached"] += metrics.get("input_tokens_uncached", 0)
        bucket["messages"] += 1
    return {
        "output_tokens": total_output,
        "input_tokens": total_input,
        "input_tokens_uncached": total_input_uncached,
        "cache_read_tokens": cache_read,
        "cache_write_tokens": cache_write,
        "total_nano_aiu": total_nano_aiu,
        "model_usage": model_usage,
    }


def _per_agent_usage_from_process_log(
    entries: list[dict], subagent_map: dict[str, str]
) -> dict[str, dict]:
    """Partition process-log entries by agent_id and compute per-agent totals.

    Returns a dict keyed by agent display name with token usage per subagent.
    Only includes agents that have at least one request attributed to them.
    The root agent (entries without agent_id or with initiator != "sub-agent")
    is keyed as "root".
    """
    agent_entries: dict[str, list[dict]] = {}
    for entry in entries:
        props = entry.get("properties", {})
        if props.get("initiator") == "sub-agent":
            agent_id = props.get("agent_id", "")
            label = subagent_map.get(agent_id, agent_id or "sub-agent")
        else:
            label = "root"
        agent_entries.setdefault(label, []).append(entry)

    result: dict[str, dict] = {}
    for label, agent_list in agent_entries.items():
        totals = _totals_from_process_log(agent_list)
        result[label] = {
            "output_tokens": totals["output_tokens"],
            "input_tokens": totals["input_tokens"],
            "input_tokens_uncached": totals.get("input_tokens_uncached", 0),
            "cache_read_tokens": totals["cache_read_tokens"],
            "cache_write_tokens": totals["cache_write_tokens"],
            "total_nano_aiu": totals["total_nano_aiu"],
            "requests": sum(1 for _ in agent_list),
        }
    return result


def _new_usage_bucket() -> dict:
    """Return a fresh per-model usage bucket with the unified key shape."""
    return {
        "output_tokens": 0,
        "messages": 0,
        "input_tokens": 0,
        "input_tokens_uncached": 0,
    }


def _totals_from_state_fallback(state_file: str | os.PathLike[str]) -> dict:
    """Approximate token totals from events.jsonl when no process log exists.

    Sums per-model ``session.shutdown`` ``modelMetrics`` across every shutdown
    in the file. A resumed session writes one shutdown per run segment with
    counters that reset on each resume, so the segments must be summed to
    recover whole-session totals. ``usage.inputTokens`` already includes cache
    reads and writes, so fresh (uncached) input is recovered by subtracting
    them.

    Output is reconciled against the ``assistant.message`` per-message sum,
    which stays complete even when a run segment ends without ``modelMetrics``
    (an aborted or minimal shutdown) or emits subagent output under no tracked
    model. The larger of the two sources wins so output is never undercounted.

    When no shutdown exists yet (a live session that has not ended a segment),
    only per-message output is known; input, cache, and AIU are reported as
    ``None`` so the report can distinguish "unknown" from a true zero.
    """
    total_input = shutdown_output = cache_read = cache_write = total_nano_aiu = 0
    total_input_uncached = 0
    model_usage: dict[str, dict] = {}
    msg_output_total = 0
    msg_output_by_model: dict[str, int] = {}
    had_shutdown = False
    for evt in iter_jsonl(state_file):
        data = evt.get("data", {})
        if not isinstance(data, dict):
            continue
        etype = evt.get("type", "")
        if etype == "assistant.message":
            output_tokens = data.get("outputTokens", 0)
            if output_tokens:
                msg_output_total += output_tokens
                model = data.get("model", "")
                if model:
                    msg_output_by_model[model] = msg_output_by_model.get(model, 0) + output_tokens
            continue
        if etype != "session.shutdown":
            continue
        metrics = data.get("modelMetrics", {})
        if not isinstance(metrics, dict):
            continue
        had_shutdown = True
        for model, m in metrics.items():
            if not isinstance(m, dict):
                continue
            usage = m.get("usage", {})
            in_tok = usage.get("inputTokens", 0)
            out_tok = usage.get("outputTokens", 0)
            cr = usage.get("cacheReadTokens", 0)
            cw = usage.get("cacheWriteTokens", 0)
            uncached = max(in_tok - cr - cw, 0)
            requests = m.get("requests", {}).get("count", 0)
            total_input += in_tok
            shutdown_output += out_tok
            cache_read += cr
            cache_write += cw
            total_input_uncached += uncached
            total_nano_aiu += m.get("totalNanoAiu", 0)
            bucket = model_usage.setdefault(model, _new_usage_bucket())
            bucket["output_tokens"] += out_tok
            bucket["input_tokens"] += in_tok
            bucket["input_tokens_uncached"] += uncached
            bucket["messages"] += requests
    if had_shutdown:
        # Reconcile output per model and in total against the message sum,
        # which is complete even when a segment lacked modelMetrics.
        for model, out_tok in msg_output_by_model.items():
            bucket = model_usage.setdefault(model, _new_usage_bucket())
            if out_tok > bucket["output_tokens"]:
                bucket["output_tokens"] = out_tok
        return {
            "output_tokens": max(shutdown_output, msg_output_total),
            "input_tokens": total_input,
            "input_tokens_uncached": total_input_uncached,
            "cache_read_tokens": cache_read,
            "cache_write_tokens": cache_write,
            "total_nano_aiu": total_nano_aiu,
            "model_usage": model_usage,
        }
    # Live session with no completed segment: only per-message output is known.
    for model, out_tok in msg_output_by_model.items():
        model_usage.setdefault(model, _new_usage_bucket())["output_tokens"] += out_tok
    return {
        "output_tokens": msg_output_total,
        "input_tokens": None,
        "input_tokens_uncached": None,
        "cache_read_tokens": None,
        "cache_write_tokens": None,
        "total_nano_aiu": None,
        "model_usage": model_usage,
    }


def build_session_summary(
    sid: str,
    state_dir: Path,
    state_file: str | os.PathLike[str],
    home: Path,
    ts_override: str | None = None,
    client: str = "",
) -> dict:
    """Build a SessionSummary event for a session.

    Prefers precise per-request metrics from the CLI process log and falls
    back to summed ``session.shutdown`` metrics in events.jsonl when the
    process log is unavailable. The inner readers each swallow their own
    ``OSError`` and yield empty data, so a summary is produced even when the
    underlying files are unreadable.
    """
    meta = scan_session_state(state_file)
    interaction_ids = meta["interaction_ids"]
    process_logs = find_process_logs_for_session(state_dir, home, interaction_ids)
    totals = None
    agent_usage: dict[str, dict] | None = None
    token_source = "state_fallback"
    if process_logs and interaction_ids:
        entries: list[dict] = []
        for log in process_logs:
            entries.extend(parse_process_log(log, interaction_ids))
        if entries:
            totals = _totals_from_process_log(entries)
            token_source = "process_log"
            # Compute per-subagent token attribution when subagents were used.
            if meta["subagent_map"]:
                agent_usage = _per_agent_usage_from_process_log(entries, meta["subagent_map"])
    if totals is None:
        totals = _totals_from_state_fallback(state_file)

    summary = {
        "ts": ts_override if ts_override is not None else meta["last_ts"],
        "sid": sid,
        "event": "SessionSummary",
        "first_ts": meta["first_ts"],
        "last_ts": meta["last_ts"],
        "models": meta["models"],
        "model_usage": totals["model_usage"],
        "output_tokens": totals["output_tokens"],
        "input_tokens": totals["input_tokens"],
        "cache_read_tokens": totals["cache_read_tokens"],
        "cache_write_tokens": totals["cache_write_tokens"],
        "total_nano_aiu": totals["total_nano_aiu"],
        "token_source": token_source,
        "turns": meta["turns"],
        "messages": meta["messages"],
    }
    # Fresh (uncached) input is available from the process log and from summed
    # session.shutdown metrics; omit the key only when the fallback found no
    # shutdown (None) so the report can distinguish "unknown" from a true zero.
    uncached = totals.get("input_tokens_uncached")
    if uncached is not None:
        summary["input_tokens_uncached"] = uncached
    if meta["reasoning_effort"]:
        summary["reasoning_effort"] = meta["reasoning_effort"]
    if meta["subagent_map"]:
        summary["subagent_map"] = meta["subagent_map"]
    if agent_usage:
        summary["agent_usage"] = agent_usage
    if client:
        summary["client"] = client
    return summary


def _infer_event_from_shape(data: dict) -> str:
    """Infer a canonical event name from payload shape.

    The Copilot CLI does not send an event-name field in the hook payload
    (no ``hook_event_name``/``hookEventName``/``event``), unlike VS Code. It
    also fires one shared command for every manifest event, so the event must
    be inferred from which fields are present. Fields are resolved through
    ``PAYLOAD_ALIASES``, so inference is surface-agnostic. Checks are ordered
    so that events sharing fields are disambiguated by their distinguishing
    field:

    * tool result present -> PostToolUse (also carries a tool name)
    * tool name present -> PreToolUse
    * prompt present -> UserPromptSubmit
    * agent name present -> SubagentStop when a stop reason is set (a
      Subagent stop), otherwise SubagentStart
    * trigger present -> PreCompact
    * stop reason present without an agent name -> Stop (an agent turn end)
    * source present -> SessionStart
    * ``reason`` holding a documented session-end value (``complete``,
      ``error``, ``abort``, ``timeout``, ``user_exit``) -> SessionEnd (the
      session terminates; unlike an agent Stop, no stop reason)
    """
    if _payload_has(data, "tool_result"):
        return "PostToolUse"
    if _payload_has(data, "tool_name"):
        return "PreToolUse"
    if _payload_has(data, "prompt"):
        return "UserPromptSubmit"
    if _payload_has(data, "agent_name"):
        return "SubagentStop" if _payload_has(data, "stop_reason") else "SubagentStart"
    if _payload_has(data, "trigger"):
        return "PreCompact"
    if _payload_has(data, "stop_reason"):
        return "Stop"
    if _payload_has(data, "source"):
        return "SessionStart"
    if _payload_get(data, "reason") in SESSION_END_REASONS:
        return "SessionEnd"
    return "unknown"


def _normalize_event(data: dict) -> str:
    """Resolve the canonical PascalCase event name from a hook payload."""
    event = "unknown"
    for key in PAYLOAD_ALIASES["event_name"]:
        value = data.get(key)
        if value and value != "unknown":
            event = value
            break
    if event == "unknown":
        # The Copilot CLI omits the event name entirely; recover it from the
        # payload shape so CLI sessions record telemetry like VS Code sessions.
        event = _infer_event_from_shape(data)
    return EVENT_ALIASES.get(event, event)


def _normalize_timestamp(raw_ts: object) -> str:
    """Coerce a hook timestamp (epoch ms or string) to an ISO-8601 string."""
    if isinstance(raw_ts, (int, float)):
        return datetime.datetime.fromtimestamp(raw_ts / 1000, tz=datetime.UTC).isoformat()
    if isinstance(raw_ts, str) and raw_ts:
        return raw_ts
    return datetime.datetime.now(datetime.UTC).isoformat()


def _token_estimate(path: str) -> int:
    """Estimate token count as ceil(file_size / 4).

    Uses the common ~4 chars-per-token heuristic for LLM token budgets.
    """
    try:
        # Ceiling division without importing math.
        return int(-(-os.path.getsize(path) // 4))
    except OSError:
        # File size unavailable (e.g., missing file); estimate zero tokens.
        return 0


class _AgentStack:
    """Per-session record of active agents, kept as an append-only op log.

    Tracks which subagents have started but not stopped so telemetry entries can
    attribute tool calls to the correct agent context. Subagents start and stop
    in their own collector processes, so the state is appended and replayed on
    read rather than read-modify-written, which would lose all but one of a
    simultaneous batch. Appends go through :func:`append_line`, so the replay
    also picks up any shard a writer left behind when it could not take the lock.

    Records are keyed by the surface's unique invocation id rather than the
    agent's name: concurrent subagents of the same type share a name, so
    name-keyed removal evicts an arbitrary one.
    """

    def __init__(self, stack_dir: Path, sid: str) -> None:
        self.stack_dir = stack_dir
        self.session_dir = stack_dir / sid if _is_safe_sid(sid) else None
        self.stack_file = self.session_dir / "ops.log" if self.session_dir else None

    def _replay(self) -> list[tuple[str, str]]:
        """Rebuild the (key, name) pairs of started-but-not-stopped agents."""
        active: list[tuple[str, str]] = []
        if not self.session_dir:
            return active
        ops: list[dict] = []
        for shard in self.session_dir.glob("*.log"):
            ops.extend(iter_jsonl(shard))
        # Shards interleave, so recover a single order from the recorded time.
        # A push must settle before a pop stamped in the same tick, or the pop
        # matches nothing and its agent stays active forever.
        ops.sort(key=lambda op: (str(op.get("ts", "")), 0 if op.get("op") == "push" else 1))
        for op in ops:
            name = op.get("agent", "")
            key = op.get("id") or name
            if op.get("op") == "push":
                active.append((key, name))
                continue
            for i in reversed(range(len(active))):
                if active[i][0] == key:
                    del active[i]
                    break
            # An unmatched pop means its push was lost; keeping the other
            # records reports the caller as unknown instead of evicting a
            # live agent and misattributing every tool call after it.
        return active

    def active(self) -> list[str]:
        """Return the names of every started-but-not-stopped agent."""
        return [name for _, name in self._replay()]

    def push(self, agent_id: str, name: str = "") -> None:
        """Record that an agent started.

        Args:
            agent_id: The surface's unique invocation id, used as the record
                key. Falls back to ``name`` when the payload omits it, which
                makes concurrent same-named agents indistinguishable.
            name: The agent's display name, reported by :meth:`active`.
        """
        if not self.stack_file:
            return
        append_jsonl(
            self.stack_file,
            {
                "ts": datetime.datetime.now(datetime.UTC).isoformat(),
                "op": "push",
                "id": agent_id or name,
                "agent": name,
            },
        )

    def pop(self, agent_id: str, name: str = "") -> None:
        """Record that an agent stopped. The log is discarded by :meth:`clear`.

        Args:
            agent_id: The invocation id passed to :meth:`push`; ``name`` is the
                fallback key, matching push so the pair cancels.
            name: The agent's display name, used only as that fallback.
        """
        if not self.session_dir or not self.session_dir.exists():
            return
        append_jsonl(
            self.stack_file,
            {
                "ts": datetime.datetime.now(datetime.UTC).isoformat(),
                "op": "pop",
                "id": agent_id or name,
            },
        )

    def clear(self) -> None:
        """Discard this session's op log directory."""
        if not self.session_dir or not self.session_dir.is_dir():
            return
        # Re-check containment at the point of deletion: _is_safe_sid gates the
        # id, but a recursive remove should not rest on that alone.
        if not _is_contained(self.session_dir, self.stack_dir):
            return
        shutil.rmtree(self.session_dir, ignore_errors=True)


def _attribute_agent(entry: dict, active: list[str]) -> None:
    """Credit a tool call to the agent that made it, when that is knowable.

    A tool payload names no caller and a turn's tool calls run in parallel, so
    an active subagent is not evidence that it issued this one. Only an empty
    active set is conclusive; otherwise every candidate is recorded and the
    choice is left to offline analysis.

    Args:
        entry: The telemetry record, mutated in place. Gains ``agents`` (a
            candidate list) when subagents are active, or ``agent`` (a single
            name) when none are. The two shapes are mutually exclusive.
        active: Names of every started-but-not-stopped agent.
    """
    if active:
        entry["agents"] = ["root", *active]
    else:
        entry["agent"] = "root"


def build_entry(data: dict, event: str, stack: _AgentStack) -> dict | None:
    """Build the JSONL telemetry entry for a single hook event.

    Returns ``None`` for unrecognized events, which the caller drops.
    """
    sid = _payload_get(data, "session_id")
    cwd = _payload_get(data, "cwd", os.getcwd())
    ts = _normalize_timestamp(_payload_get(data, "timestamp"))
    tool_name = _payload_get(data, "tool_name")
    tool_input = _payload_get(data, "tool_input", {})
    tool_result = _payload_get(data, "tool_result")

    # The Copilot CLI serializes tool arguments as a JSON string rather than an
    # object; decode it so key extraction and file-path detection below work.
    if isinstance(tool_input, str):
        try:
            tool_input = json.loads(tool_input)
        except ValueError:
            tool_input = {}

    if event == "unknown":
        return None

    entry: dict = {"ts": ts, "sid": sid, "event": event, "cwd": cwd}

    # Pairs a Pre with its Post, which is the only handle offline analysis has
    # on when a call was in flight.
    tool_use_id = _payload_get(data, "tool_use_id")
    if tool_use_id and event in ("PreToolUse", "PostToolUse"):
        entry["tool_use_id"] = tool_use_id

    if event == "SessionStart":
        entry["source"] = _payload_get(data, "source")
        entry["client"] = _detect_client()
    elif event == "UserPromptSubmit":
        entry["prompt"] = _payload_get(data, "prompt")[:200]
    elif event == "PreToolUse":
        entry["tool"] = tool_name
        entry["tool_input_keys"] = list(tool_input.keys()) if isinstance(tool_input, dict) else []
        _attribute_agent(entry, stack.active())
        # Detect instructions and skills by file path convention to track
        # which artifacts the agent loaded during the session. Normalize
        # Windows backslash separators so splitting works cross-platform.
        fpath = tool_input.get("filePath") if isinstance(tool_input, dict) else None
        if isinstance(fpath, str):
            norm = fpath.replace("\\", "/")
            if norm.endswith(".instructions.md"):
                entry["instruction"] = norm.split("/")[-1]
                entry["tokens"] = _token_estimate(fpath)
            elif norm.endswith("SKILL.md"):
                # SKILL.md sits at the skill root in every layout, collection or flat.
                parts = norm.rstrip("/").split("/")
                if len(parts) >= 2:
                    entry["skill"] = parts[-2]
                entry["tokens"] = _token_estimate(fpath)
        if isinstance(tool_input, dict) and tool_name in ("runSubagent", "task"):
            entry["subagent"] = (
                tool_input.get("agentName")
                or tool_input.get("agent_type")
                or tool_input.get("description", "")
            )
    elif event == "PostToolUse":
        entry["tool"] = tool_name
        if isinstance(tool_result, dict):
            text = _payload_get(tool_result, "tool_result_text")
            entry["tool_response_len"] = len(text if isinstance(text, str) else str(text))
        elif isinstance(tool_result, str):
            entry["tool_response_len"] = len(tool_result)
        else:
            entry["tool_response_len"] = len(json.dumps(tool_result))
        _attribute_agent(entry, stack.active())
    elif event == "SubagentStart":
        agent_name = _payload_get(data, "agent_name")
        agent_id = _payload_get(data, "agent_id")
        entry["agent_name"] = agent_name
        entry["agent_display_name"] = _payload_get(data, "agent_display_name")
        if agent_id:
            entry["agent_id"] = agent_id
        stack.push(agent_id, agent_name)
    elif event == "SubagentStop":
        agent_name = _payload_get(data, "agent_name")
        agent_id = _payload_get(data, "agent_id")
        entry["agent_name"] = agent_name
        if agent_id:
            entry["agent_id"] = agent_id
        stack.pop(agent_id, agent_name)
    elif event == "PreCompact":
        entry["trigger"] = _payload_get(data, "trigger")
    elif event == "Stop":
        # Fall back to ``reason`` for surfaces that name the event Stop but
        # supply a session-end style payload without a stop reason.
        entry["stop_reason"] = _payload_get(data, "stop_reason") or _payload_get(data, "reason")
        stack.clear()
    elif event == "SessionEnd":
        entry["reason"] = _payload_get(data, "reason")
        stack.clear()

    return entry


def _read_stdin_text() -> str:
    """Read the hook payload as UTF-8 regardless of the host locale.

    Windows decodes ``sys.stdin`` with the ANSI codepage and a POSIX/C locale
    decodes it as ASCII, either of which mangles or rejects UTF-8 payload
    bytes. ``UnicodeDecodeError`` subclasses ``ValueError``, so a rejected
    payload would otherwise be dropped as if it were malformed JSON.
    """
    buffer = getattr(sys.stdin, "buffer", None)
    if buffer is None:
        return sys.stdin.read()
    return buffer.read().decode("utf-8", errors="replace")


def _mode_collect() -> int:
    """Process a single hook event from stdin; returns a process exit code."""
    try:
        data = json.loads(_read_stdin_text())
    except ValueError:
        return 0
    if not isinstance(data, dict):
        return 0

    sid = _payload_get(data, "session_id")
    # Reject session IDs containing path separators or traversal sequences
    # to prevent writes outside the telemetry directory.
    if sid and not _is_safe_sid(sid):
        return 0

    event = _normalize_event(data)
    tel_dir = Path(os.environ.get("HVE_TELEMETRY_DIR", ".copilot-tracking/telemetry"))
    date_str = datetime.datetime.now(datetime.UTC).strftime("%Y-%m-%d")
    log_file = tel_dir / f"sessions-{date_str}.jsonl"
    stack_dir = tel_dir / ".stacks"
    stack = _AgentStack(stack_dir, sid)

    entry = build_entry(data, event, stack)
    if entry is None:
        return 0

    # Register before the first write of the day so a store whose SessionStart
    # was never delivered (telemetry enabled mid-session, or a surface that
    # omits the event) still reaches cross-project reports. Bounded to one
    # registry read per store per day plus each session start.
    first_write = not log_file.exists()
    try:
        tel_dir.mkdir(parents=True, exist_ok=True)
    except OSError:
        # An unwritable store is a telemetry failure, not a turn failure. The
        # writes below are best-effort and skip themselves for the same reason.
        return 0
    if event == "SessionStart" or first_write:
        register_telemetry_dir(tel_dir)
        write_report_launchers()
    append_jsonl(log_file, entry)

    # Enrich the log with a SessionSummary of token totals and model usage.
    # Emitted at SessionEnd (the authoritative final snapshot), at Stop (each
    # agent turn end, capturing periodically before process logs rotate), and
    # at PreCompact: process logs rotate aggressively, so capturing a snapshot
    # before compaction preserves per-request input data that would otherwise
    # degrade to the compaction-only state fallback once the log is gone.
    # Multiple summaries per session are expected; the report replaces by
    # provenance rank and freshness rather than accumulating, so snapshots
    # never double-count.
    if event in ("Stop", "SessionEnd", "PreCompact") and sid:
        home = copilot_home()
        state_dir = home / "session-state" / sid
        state_file = state_dir / "events.jsonl"
        if state_file.is_file():
            summary = build_session_summary(
                sid,
                state_dir,
                state_file,
                home,
                ts_override=entry["ts"],
                client=_detect_client(),
            )
            if summary is not None:
                append_jsonl(log_file, summary)
    return 0


def _workspace_storage_dirs() -> list[Path]:
    """Return candidate VS Code workspaceStorage roots for this host.

    Covers remote/server installs (``~/.vscode-server*/data``) and local
    installs, whose user-data dir is platform specific.
    """
    home = Path.home()
    roots = [home / d / "data" for d in (".vscode-server-insiders", ".vscode-server", ".vscode")]

    if _is_windows():
        appdata = os.environ.get("APPDATA")
        local_base = Path(appdata) if appdata else home / "AppData/Roaming"
    elif sys.platform == "darwin":
        local_base = home / "Library/Application Support"
    else:
        xdg = os.environ.get("XDG_CONFIG_HOME")
        local_base = Path(xdg) if xdg else home / ".config"

    roots += [local_base / d for d in ("Code - Insiders", "Code", "VSCodium")]
    return [r / "User/workspaceStorage" for r in roots]


def _mode_aggregate_debug(out: str, hook_files: list[str]) -> int:
    """Emit llm_request events from VS Code debug logs for collected sids."""
    sids = collect_sids(hook_files)
    if not sids:
        return 1

    patterns = [str(base / "**/debug-logs/**/*.jsonl") for base in _workspace_storage_dirs()]
    count = 0
    with open(out, "w", encoding="utf-8") as writer:
        for pattern in patterns:
            for path in glob.glob(pattern, recursive=True):
                for obj in iter_jsonl(path):
                    if obj.get("type") == "llm_request" and obj.get("sid") in sids:
                        writer.write(json.dumps(obj) + "\n")
                        count += 1
    return 0 if count else 1


def _mode_aggregate_session(out: str, hook_files: list[str]) -> int:
    """Emit SessionSummary events from CLI session state for collected sids."""
    sids = collect_sids(hook_files)
    if not sids:
        return 1

    home = copilot_home()
    state_base = home / "session-state"
    count = 0
    with open(out, "w", encoding="utf-8") as writer:
        for sid in sids:
            state_dir = state_base / sid
            state_file = state_dir / "events.jsonl"
            if not state_file.is_file():
                continue
            summary = build_session_summary(sid, state_dir, state_file, home, client="cli")
            if summary is not None:
                writer.write(json.dumps(summary) + "\n")
                count += 1
    return 0 if count else 1


# Telemetry artifacts written into a per-project store. Cleanup targets only
# these known names so a directory a user pointed ``HVE_TELEMETRY_DIR`` at is
# never removed wholesale.
_TELEMETRY_FILE_ARTIFACTS = ("raw-input.jsonl", "report.generated.html")
# One session log per UTC day, plus any fallback shard a collector wrote when it
# could not lock that log (sessions-<date>.<HHMMSSffffff>-<pid>-<hex>.jsonl).
_TELEMETRY_GLOB_ARTIFACTS = ("sessions-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]*.jsonl",)
_TELEMETRY_DIR_ARTIFACTS = (".stacks",)

# Artifacts written into the HVE home directory (registry plus generated
# cross-project launchers and report). ``telemetry-dirs.txt`` and its lock are
# the pre-directory registry, listed so an upgraded install is tidied up too.
_HVE_HOME_ARTIFACTS = (
    "telemetry-dirs",
    "telemetry-dirs.txt",
    "telemetry-dirs.txt.lock",
    "telemetry-dirs.txt.migrated",
    "report.generated.html",
    "generate-report.sh",
    "generate-report.ps1",
    "clean-telemetry.sh",
    "clean-telemetry.ps1",
)


def _remove_path(path: Path, dry_run: bool, removed: list[str]) -> None:
    """Remove a file or directory, recording the deleted path.

    Missing paths and removal errors are ignored so cleanup is best-effort and
    never aborts partway.
    """
    if not path.exists() and not path.is_symlink():
        return
    if dry_run:
        removed.append(str(path))
        return
    try:
        if path.is_dir() and not path.is_symlink():
            shutil.rmtree(path)
        else:
            path.unlink()
    except OSError:
        # Removal failed (e.g., permission denied); leave the path in place.
        return
    removed.append(str(path))


def clean_telemetry_dir(tel_dir: Path, dry_run: bool, removed: list[str]) -> None:
    """Remove known telemetry artifacts from a single per-project store."""
    if not tel_dir.is_dir():
        return
    for name in _TELEMETRY_FILE_ARTIFACTS:
        _remove_path(tel_dir / name, dry_run, removed)
    for pattern in _TELEMETRY_GLOB_ARTIFACTS:
        for match in sorted(tel_dir.glob(pattern)):
            _remove_path(match, dry_run, removed)
    for name in _TELEMETRY_DIR_ARTIFACTS:
        _remove_path(tel_dir / name, dry_run, removed)


def _mode_clean(all_dirs: bool, dry_run: bool) -> int:
    """Remove telemetry artifacts from the current store.

    With ``all_dirs`` the scope expands to every registered store plus the
    generated launchers, report, and registry in the HVE home directory.
    """
    removed: list[str] = []
    targets: list[Path] = []
    if all_dirs:
        targets.extend(Path(d) for d in read_registry_dirs())
    targets.append(Path(os.environ.get("HVE_TELEMETRY_DIR", ".copilot-tracking/telemetry")))

    seen: set[str] = set()
    for tel_dir in targets:
        try:
            key = str(tel_dir.resolve())
        except OSError:
            key = str(tel_dir)
        if key in seen:
            continue
        seen.add(key)
        clean_telemetry_dir(tel_dir, dry_run, removed)

    if all_dirs:
        home = hve_home()
        for name in _HVE_HOME_ARTIFACTS:
            _remove_path(home / name, dry_run, removed)

    verb = "Would remove" if dry_run else "Removed"
    if removed:
        for item in removed:
            sys.stdout.write(f"{verb}: {item}\n")
        sys.stdout.write(f"{verb} {len(removed)} item(s).\n")
    else:
        sys.stdout.write("No telemetry artifacts found to remove.\n")
    return 0


def _mode_list_dirs() -> int:
    """Print registered telemetry dirs that still exist; prune dead entries.

    Pruning unlinks the marker for a store that has been deleted, keeping the
    cross-project report scan fast as repositories come and go.
    """
    registry = telemetry_registry()
    for directory in read_registry_dirs(registry):
        if Path(directory).is_dir():
            sys.stdout.write(directory + "\n")
            continue
        try:
            _registry_marker(registry, directory).unlink(missing_ok=True)
        except OSError:
            # Cannot prune this marker; leave it rather than fail the listing.
            continue
    return 0


def main(argv: list[str]) -> int:
    """Dispatch a CLI mode. See module docstring for the contract."""
    if not argv:
        sys.stderr.write(
            "usage: _telemetry_core.py "
            "<collect|aggregate-debug|aggregate-session|list-dirs|clean> ...\n"
        )
        return 2
    mode = argv[0]
    if mode == "collect":
        return _mode_collect()
    if mode == "aggregate-debug":
        if len(argv) < 2:
            return 2
        return _mode_aggregate_debug(argv[1], argv[2:])
    if mode == "aggregate-session":
        if len(argv) < 2:
            return 2
        return _mode_aggregate_session(argv[1], argv[2:])
    if mode == "list-dirs":
        return _mode_list_dirs()
    if mode == "clean":
        rest = argv[1:]
        all_dirs = "--all-dirs" in rest or "-a" in rest
        dry_run = "--dry-run" in rest or "-n" in rest
        return _mode_clean(all_dirs=all_dirs, dry_run=dry_run)
    sys.stderr.write(f"unknown mode: {mode}\n")
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
