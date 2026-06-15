#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Canonical telemetry engine shared by the Copilot hook collectors.

This module is the single source of truth for telemetry collection. The bash
collector ``telemetry-collector.sh`` invokes the ``collect`` mode to record one
hook event (and enrich the session at ``Stop``), while
``generate-telemetry-report.sh`` invokes the ``aggregate-debug``,
``aggregate-session``, and ``list-dirs`` modes to join model/token data and
discover per-project telemetry stores for reports. ``clean-telemetry.sh``
invokes the ``clean`` mode to remove telemetry artifacts from one or every
registered store.

The PowerShell collector ``Invoke-TelemetryCollector.ps1`` is a thin wrapper
that delegates to this same engine via ``collect``, so the collection logic
stays single-sourced across platforms.
"""

from __future__ import annotations

import datetime
import glob
import json
import os
import shlex
import shutil
import sys
from collections.abc import Iterable, Iterator
from pathlib import Path


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
    "sessionEnd": "Stop",
    "preCompact": "PreCompact",
}


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
        return


def _is_safe_sid(sid: str) -> bool:
    """Return True when a session id is safe to embed in a filesystem path.

    Rejects empty ids and any value containing a path separator or ``..``
    traversal sequence so callers never build paths outside their store.
    """
    return bool(sid) and not (
        os.sep in sid or "/" in sid or "\\" in sid or ".." in sid
    )


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
    """Return the user-level registry that lists per-project telemetry dirs."""
    return hve_home() / "telemetry-dirs.txt"


def read_registry_dirs(registry: Path | None = None) -> list[str]:
    """Return registered telemetry directories in order, de-duplicated."""
    registry = registry if registry is not None else telemetry_registry()
    try:
        text = registry.read_text(encoding="utf-8")
    except OSError:
        return []
    dirs: list[str] = []
    seen: set[str] = set()
    for line in text.splitlines():
        entry = line.strip()
        if entry and entry not in seen:
            seen.add(entry)
            dirs.append(entry)
    return dirs


def register_telemetry_dir(tel_dir: Path, registry: Path | None = None) -> None:
    """Record an absolute telemetry directory in the user-level registry.

    Lets the report tooling discover every per-project telemetry store without
    relying on environment propagation. Resolves to an absolute path and skips
    the append when already present so the registry stays de-duplicated.
    """
    registry = registry if registry is not None else telemetry_registry()
    try:
        resolved = str(tel_dir.resolve())
    except OSError:
        resolved = os.path.abspath(str(tel_dir))
    if resolved in read_registry_dirs(registry):
        return
    try:
        registry.parent.mkdir(parents=True, exist_ok=True)
        with open(registry, "a", encoding="utf-8") as handle:
            handle.write(resolved + "\n")
    except OSError:
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
# alongside the registry of per-project telemetry stores. Requires bash (for
# example Git Bash). Run from this directory:
#   ./generate-report.ps1                # today, every project
#   ./generate-report.ps1 --date all     # every captured day, every project
$ReportScript = '__REPORT_SCRIPT__'
if (-not (Test-Path $ReportScript)) {
    Write-Error "Telemetry report script not found: $ReportScript"
    Write-Error 'Start a new Copilot session to regenerate this launcher.'
    exit 1
}
bash $ReportScript --all-dirs --output '__OUT__' @args
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
    on Windows, POSIX shell (``.sh``) elsewhere. The cleanup launcher is fully
    native per platform (bash wrapper on POSIX, PowerShell wrapper on Windows),
    so no cross-interpreter dependency is required for cleanup.
    """
    if script_dir is None:
        script_dir = Path(__file__).resolve().parent
    report_script = str(script_dir / "generate-telemetry-report.sh")
    clean_script = str(script_dir / "clean-telemetry.sh")
    clean_ps1 = str(script_dir / "Invoke-TelemetryClean.ps1")
    home = hve_home()
    out_path = str(home / "report.generated.html")
    try:
        home.mkdir(parents=True, exist_ok=True)
        if _is_windows():
            # Quote for PowerShell single-quoted strings (double embedded ').
            pwsh_text = _PWSH_LAUNCHER.replace(
                "__REPORT_SCRIPT__", report_script.replace("'", "''")
            ).replace("__OUT__", out_path.replace("'", "''"))
            pwsh_clean_text = _PWSH_CLEAN_LAUNCHER.replace(
                "__CLEAN_PS1__", clean_ps1.replace("'", "''")
            )
            (home / "generate-report.ps1").write_text(pwsh_text, encoding="utf-8")
            (home / "clean-telemetry.ps1").write_text(
                pwsh_clean_text, encoding="utf-8"
            )
        else:
            # Shell-quote so unusual install paths (spaces, quotes, ``$``)
            # cannot break or inject into the generated launchers.
            bash_text = _BASH_LAUNCHER.replace(
                "__REPORT_SCRIPT__", shlex.quote(report_script)
            ).replace("__OUT__", shlex.quote(out_path))
            bash_clean_text = _BASH_CLEAN_LAUNCHER.replace(
                "__CLEAN_SCRIPT__", shlex.quote(clean_script)
            )
            sh_path = home / "generate-report.sh"
            sh_path.write_text(bash_text, encoding="utf-8")
            sh_path.chmod(0o755)
            clean_sh_path = home / "clean-telemetry.sh"
            clean_sh_path.write_text(bash_clean_text, encoding="utf-8")
            clean_sh_path.chmod(0o755)
    except OSError:
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
        return None
    if not pid:
        return None
    candidates = glob.glob(str(home / "logs" / f"process-*-{pid}.log"))
    return candidates[0] if candidates else None


def _log_references_interactions(
    log_path: str, interaction_ids: set[str]
) -> bool:
    """Return True when a process log references any of the interaction ids.

    Uses a cheap line substring scan so logs that cannot belong to the session
    are rejected without a full JSON parse.
    """
    try:
        with open(log_path, encoding="utf-8", errors="replace") as handle:
            for line in handle:
                if "interaction_id" in line and any(
                    iid in line for iid in interaction_ids
                ):
                    return True
    except OSError:
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
                    msg_output_by_model[model] = (
                        msg_output_by_model.get(model, 0) + output_tokens
                    )
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
                agent_usage = _per_agent_usage_from_process_log(
                    entries, meta["subagent_map"]
                )
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


def _normalize_event(data: dict) -> str:
    """Resolve the canonical PascalCase event name from a hook payload."""
    event = data.get("hook_event_name", "unknown")
    if event == "unknown":
        for key in ("hookEventName", "event"):
            value = data.get(key)
            if value and value != "unknown":
                event = value
                break
    return EVENT_ALIASES.get(event, event)


def _normalize_timestamp(raw_ts: object) -> str:
    """Coerce a hook timestamp (epoch ms or string) to an ISO-8601 string."""
    if isinstance(raw_ts, (int, float)):
        return datetime.datetime.fromtimestamp(
            raw_ts / 1000, tz=datetime.UTC
        ).isoformat()
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
        return 0


class _AgentStack:
    """Per-session agent stack persisted as a JSON array on disk.

    Tracks the active agent (root vs subagent) so telemetry entries can
    attribute tool calls to the correct agent context.
    """

    def __init__(self, stack_dir: Path, sid: str) -> None:
        self.stack_dir = stack_dir
        self.stack_file = (
            stack_dir / f"{sid}.json" if _is_safe_sid(sid) else None
        )

    def _read(self) -> list[str]:
        if self.stack_file and self.stack_file.exists():
            try:
                with open(self.stack_file, encoding="utf-8") as handle:
                    data = json.load(handle)
                if isinstance(data, list):
                    return data
            except (OSError, ValueError):
                return []
        return []

    def current(self) -> str:
        stack = self._read()
        return stack[-1] if stack else "root"

    def push(self, name: str) -> None:
        if not self.stack_file:
            return
        self.stack_dir.mkdir(parents=True, exist_ok=True)
        stack = self._read()
        stack.append(name)
        with open(self.stack_file, "w", encoding="utf-8") as handle:
            json.dump(stack, handle)

    def pop(self) -> None:
        """Remove the topmost agent. Deletes the file when the stack empties."""
        if not self.stack_file or not self.stack_file.exists():
            return
        stack = self._read()
        if len(stack) > 1:
            with open(self.stack_file, "w", encoding="utf-8") as handle:
                json.dump(stack[:-1], handle)
        else:
            self.stack_file.unlink(missing_ok=True)

    def clear(self) -> None:
        if self.stack_file and self.stack_file.exists():
            self.stack_file.unlink(missing_ok=True)


def build_entry(data: dict, event: str, stack: _AgentStack) -> dict | None:
    """Build the JSONL telemetry entry for a single hook event.

    Returns ``None`` for unrecognized events, which the caller drops.
    """
    sid = data.get("session_id") or data.get("sessionId", "")
    cwd = data.get("cwd", os.getcwd())
    ts = _normalize_timestamp(data.get("timestamp", ""))
    tool_name = data.get("tool_name") or data.get("toolName", "")
    tool_input = data.get("tool_input") or data.get("toolArgs", {})
    tool_result = data.get("tool_result") or data.get("toolResult", "")

    if event == "unknown":
        return None

    entry: dict = {"ts": ts, "sid": sid, "event": event, "cwd": cwd}

    if event == "SessionStart":
        entry["source"] = data.get("source", "")
        entry["client"] = _detect_client()
    elif event == "UserPromptSubmit":
        entry["prompt"] = (data.get("prompt", "") or "")[:200]
    elif event == "PreToolUse":
        entry["tool"] = tool_name
        entry["tool_input_keys"] = (
            list(tool_input.keys()) if isinstance(tool_input, dict) else []
        )
        entry["agent"] = stack.current()
        # Detect instructions and skills by file path convention to track
        # which artifacts the agent loaded during the session.
        fpath = tool_input.get("filePath") if isinstance(tool_input, dict) else None
        if isinstance(fpath, str):
            if fpath.endswith(".instructions.md"):
                entry["instruction"] = fpath.split("/")[-1]
                entry["tokens"] = _token_estimate(fpath)
            elif fpath.endswith("SKILL.md"):
                parts = fpath.rstrip("/").split("/")
                idx = next((i for i, p in enumerate(parts) if p == "skills"), -1)
                if idx >= 0 and idx + 2 < len(parts):
                    entry["skill"] = parts[idx + 2]
                elif len(parts) >= 2:
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
            text = tool_result.get("text_result_for_llm") or tool_result.get(
                "textResultForLlm", ""
            )
            entry["tool_response_len"] = len(text if isinstance(text, str) else str(text))
        elif isinstance(tool_result, str):
            entry["tool_response_len"] = len(tool_result)
        else:
            entry["tool_response_len"] = len(json.dumps(tool_result))
        entry["agent"] = stack.current()
    elif event == "SubagentStart":
        agent_name = data.get("agent_name") or data.get("agentName", "")
        entry["agent_name"] = agent_name
        entry["agent_display_name"] = data.get("agent_display_name") or data.get(
            "agentDisplayName", ""
        )
        stack.push(agent_name)
    elif event == "SubagentStop":
        agent_name = data.get("agent_name") or data.get("agentName", "")
        entry["agent_name"] = agent_name
        stack.pop()
    elif event == "PreCompact":
        entry["trigger"] = data.get("trigger", "")
    elif event == "Stop":
        entry["stop_reason"] = data.get("stop_reason") or data.get("stopReason", "")
        stack.clear()

    return entry


def _mode_collect() -> int:
    """Process a single hook event from stdin; returns a process exit code."""
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return 0
    if not isinstance(data, dict):
        return 0

    sid = data.get("session_id") or data.get("sessionId", "")
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

    tel_dir.mkdir(parents=True, exist_ok=True)
    # Record this project's telemetry dir once per session so cross-project
    # reports can discover every store, and refresh the user-level launcher.
    # SessionStart keeps these writes infrequent.
    if event == "SessionStart":
        register_telemetry_dir(tel_dir)
        write_report_launchers()
    with open(log_file, "a", encoding="utf-8") as handle:
        handle.write(json.dumps(entry) + "\n")

    # Enrich the log with a SessionSummary of token totals and model usage.
    # Emitted at Stop (session end) and at PreCompact: process logs rotate
    # aggressively, so capturing a snapshot before compaction preserves
    # per-request input data that would otherwise degrade to the
    # compaction-only state fallback once the log is gone. Multiple summaries
    # per session are expected; the report replaces by provenance rank and
    # freshness rather than accumulating, so snapshots never double-count.
    if event in ("Stop", "PreCompact") and sid:
        home = copilot_home()
        state_dir = home / "session-state" / sid
        state_file = state_dir / "events.jsonl"
        if state_file.is_file():
            summary = build_session_summary(
                sid, state_dir, state_file, home,
                ts_override=entry["ts"], client=_detect_client(),
            )
            if summary is not None:
                with open(log_file, "a", encoding="utf-8") as handle:
                    handle.write(json.dumps(summary) + "\n")
    return 0


def _mode_aggregate_debug(out: str, hook_files: list[str]) -> int:
    """Emit llm_request events from VS Code debug logs for collected sids."""
    sids = collect_sids(hook_files)
    if not sids:
        return 1

    home = Path.home()
    patterns = [
        str(home / d / "data/User/workspaceStorage/**/debug-logs/**/*.jsonl")
        for d in (".vscode-server-insiders", ".vscode-server", ".vscode")
    ]
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
_TELEMETRY_GLOB_ARTIFACTS = ("sessions-*.jsonl",)
_TELEMETRY_DIR_ARTIFACTS = (".stacks",)

# Artifacts written into the HVE home directory (registry plus generated
# cross-project launchers and report).
_HVE_HOME_ARTIFACTS = (
    "telemetry-dirs.txt",
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
    targets.append(
        Path(os.environ.get("HVE_TELEMETRY_DIR", ".copilot-tracking/telemetry"))
    )

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

    Pruning rewrites the registry only when stale paths are dropped, keeping
    the cross-project report scan fast as repositories come and go.
    """
    registry = telemetry_registry()
    dirs = read_registry_dirs(registry)
    live = [d for d in dirs if Path(d).is_dir()]
    if live != dirs:
        try:
            registry.parent.mkdir(parents=True, exist_ok=True)
            with open(registry, "w", encoding="utf-8") as handle:
                handle.write("".join(d + "\n" for d in live))
        except OSError:
            pass
    for directory in live:
        sys.stdout.write(directory + "\n")
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
