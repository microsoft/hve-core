# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Tests for the canonical telemetry engine (_telemetry_core)."""

from __future__ import annotations

import io
import json
import os
import shlex
import shutil
import subprocess
from pathlib import Path

import _telemetry_core as core


def _write_jsonl(path, rows):
    """Write a list of dicts as newline-delimited JSON."""
    path.write_text("".join(json.dumps(r) + "\n" for r in rows))


def _run_wrapper(command, payload, tmp_path):
    """Run a hook wrapper with isolated telemetry and return its response."""
    use_bash_paths = os.name == "nt" and Path(command[0]).name.lower().startswith("bash")
    bash_prefix = "/"
    if use_bash_paths:
        runtime = subprocess.run(
            [command[0], "-c", "uname -s"],
            capture_output=True,
            text=True,
            check=False,
        ).stdout.strip()
        bash_prefix = "/mnt/" if runtime == "Linux" else "/"

    def environment_path(path):
        resolved = path.resolve().as_posix()
        if use_bash_paths and len(resolved) >= 3 and resolved[1:3] == ":/":
            return f"{bash_prefix}{resolved[0].lower()}/{resolved[3:]}"
        return resolved

    env = os.environ.copy()
    env["HVE_TELEMETRY"] = "1"
    env["HVE_TELEMETRY_DIR"] = environment_path(tmp_path / "telemetry")
    env["COPILOT_HOME"] = environment_path(tmp_path / "home")
    env["HVE_TOKEN_BUDGET"] = "100"
    if use_bash_paths and runtime == "Linux":
        assignments = " ".join(
            (
                "HVE_TELEMETRY=1",
                f"HVE_TELEMETRY_DIR={shlex.quote(env['HVE_TELEMETRY_DIR'])}",
                f"COPILOT_HOME={shlex.quote(env['COPILOT_HOME'])}",
                "HVE_TOKEN_BUDGET=100",
            )
        )
        command = [command[0], "-c", f"{assignments} bash {shlex.quote(command[1])}"]
    completed = subprocess.run(
        command,
        input=json.dumps(payload),
        cwd=Path(__file__).resolve().parents[5],
        capture_output=True,
        text=True,
        env=env,
        check=False,
    )
    return completed, json.loads(completed.stdout)


def _seed_wrapper_budget_session(tmp_path, sid):
    """Create state-fallback usage that crosses the 50% threshold."""
    state_dir = tmp_path / "home" / "session-state" / sid
    state_dir.mkdir(parents=True)
    _write_jsonl(
        state_dir / "events.jsonl",
        [
            {
                "type": "session.shutdown",
                "timestamp": "2026-07-11T12:00:00Z",
                "data": {
                    "modelMetrics": {
                        "test-model": {
                            "requests": {"count": 1},
                            "usage": {
                                "inputTokens": 40,
                                "outputTokens": 20,
                                "cacheReadTokens": 0,
                                "cacheWriteTokens": 0,
                            },
                        }
                    }
                },
            }
        ],
    )


def test_given_blank_and_malformed_lines_when_iter_jsonl_then_skips_them(tmp_path):
    f = tmp_path / "events.jsonl"
    f.write_text('{"a": 1}\n\n  \nnot-json\n{"b": 2}\n')
    rows = list(core.iter_jsonl(f))
    assert rows == [{"a": 1}, {"b": 2}]


def test_given_payload_when_powershell_wrapper_runs_then_returns_one_json(tmp_path):
    pwsh = shutil.which("pwsh")
    if not pwsh:
        return
    _seed_wrapper_budget_session(tmp_path, "pwsh-wrapper")
    script = Path(__file__).resolve().parents[1] / "Invoke-TelemetryCollector.ps1"
    completed, response = _run_wrapper(
        [pwsh, "-NoProfile", "-File", str(script)],
        {"hook_event_name": "UserPromptSubmit", "session_id": "pwsh-wrapper"},
        tmp_path,
    )
    assert completed.returncode == 0
    assert completed.stderr == ""
    assert response["continue"] is True
    assert "60% used" in response["systemMessage"]


def test_given_payload_when_bash_wrapper_runs_then_returns_one_json(tmp_path):
    bash = shutil.which("bash")
    if not bash:
        return
    _seed_wrapper_budget_session(tmp_path, "bash-wrapper")
    completed, response = _run_wrapper(
        [bash, ".github/hooks/shared/telemetry/telemetry-collector.sh"],
        {"hook_event_name": "UserPromptSubmit", "session_id": "bash-wrapper"},
        tmp_path,
    )
    assert completed.returncode == 0
    assert completed.stderr == ""
    assert response["continue"] is True
    assert "60% used" in response["systemMessage"]


def test_given_missing_file_when_iter_jsonl_then_returns_empty(tmp_path):
    assert list(core.iter_jsonl(tmp_path / "nope.jsonl")) == []


def test_given_overlapping_sids_when_collect_sids_then_dedups(tmp_path):
    a = tmp_path / "a.jsonl"
    b = tmp_path / "b.jsonl"
    _write_jsonl(a, [{"sid": "s1"}, {"sid": "s2"}, {"event": "x"}])
    _write_jsonl(b, [{"sid": "s2"}, {"sid": "s3"}])
    assert core.collect_sids([str(a), str(b)]) == {"s1", "s2", "s3"}


def test_given_root_agent_values_when_normalized_then_bounds_and_flattens_them():
    value = "  RPI\nAgent  " + ("x" * 200)
    normalized = core.normalize_root_agent_label(value)
    assert normalized.startswith("RPI Agent x")
    assert len(normalized) == 128


def test_given_session_start_when_root_agent_hint_then_uses_payload_before_environment(
    monkeypatch,
):
    monkeypatch.setenv("HVE_TELEMETRY_ROOT_AGENT", "Environment Agent")
    data = {"root_agent": "Payload Agent", "agent_name": "Alias Agent"}
    assert core.root_agent_hint(data, "SessionStart") == "Payload Agent"


def test_given_subagent_event_when_root_agent_hint_then_ignores_child_and_environment(
    monkeypatch,
):
    monkeypatch.setenv("HVE_TELEMETRY_ROOT_AGENT", "Environment Agent")
    data = {"agent_name": "Child Agent"}
    assert core.root_agent_hint(data, "SubagentStart") == ""


def test_given_hook_records_when_collect_root_agents_then_groups_unique_labels(tmp_path):
    hook_file = tmp_path / "hooks.jsonl"
    _write_jsonl(
        hook_file,
        [
            {"sid": "s1", "root_agent": "RPI Agent"},
            {"sid": "s1", "gen_ai.agent.name": "RPI Agent"},
            {"sid": "s2", "gen_ai.agent.name": "First"},
            {"sid": "s2", "gen_ai.agent.name": "Second"},
        ],
    )
    assert core.collect_root_agent_candidates([str(hook_file)]) == {
        "s1": {"RPI Agent"},
        "s2": {"First", "Second"},
    }


def test_given_budget_values_when_parsed_then_only_positive_integers_are_accepted():
    assert core.parse_token_budget("100000") == 100000
    assert core.parse_token_budget("0") is None
    assert core.parse_token_budget("-1") is None
    assert core.parse_token_budget("100.5") is None
    assert core.parse_token_budget(True) is None


def test_given_multiple_crossings_when_budget_status_built_then_notifies_highest_once():
    summary = {
        "input_tokens": 40,
        "output_tokens": 20,
        "token_source": "process_log",
        "last_ts": "2026-07-11T12:00:00Z",
    }
    first, threshold = core.build_budget_status(summary, 100, "PreCompact")
    second, repeated = core.build_budget_status(
        summary,
        100,
        "UserPromptSubmit",
        previous=first,
    )
    assert threshold == 50
    assert first["crossed_thresholds"] == [30, 50]
    assert first["notified_thresholds"] == [30, 50]
    assert first["accuracy"] == "exact"
    assert repeated is None
    assert second["notified_thresholds"] == [30, 50]


def test_given_stop_crossing_when_budget_status_built_then_updates_without_notifying():
    summary = {
        "input_tokens": 60,
        "output_tokens": 15,
        "token_source": "state_fallback",
        "last_ts": "2026-07-11T12:00:00Z",
    }
    status, threshold = core.build_budget_status(
        summary,
        100,
        "Stop",
        notify=False,
    )
    assert threshold is None
    assert status["crossed_thresholds"] == [30, 50, 70]
    assert status["notified_thresholds"] == []
    assert status["accuracy"] == "approximate"


def test_given_unknown_input_when_budget_status_built_then_usage_is_unavailable():
    summary = {
        "input_tokens": None,
        "output_tokens": 15,
        "token_source": "state_fallback",
    }
    status, threshold = core.build_budget_status(summary, 100, "PreCompact")
    assert threshold is None
    assert status["observed_tokens"] is None
    assert status["usage_percent"] is None
    assert status["accuracy"] == "unavailable"


def test_given_budget_change_when_status_built_then_notification_state_resets():
    previous = {
        "budget_tokens": 100,
        "notified_thresholds": [30, 50],
    }
    summary = {
        "input_tokens": 50,
        "output_tokens": 10,
        "token_source": "process_log",
    }
    status, threshold = core.build_budget_status(summary, 200, "UserPromptSubmit", previous)
    assert threshold == 30
    assert status["notified_thresholds"] == [30]


def test_given_budget_status_when_formatted_then_message_is_advisory():
    status = {
        "observed_tokens": 52_410,
        "budget_tokens": 100_000,
        "usage_percent": 52.41,
        "token_source": "process_log",
        "accuracy": "exact",
        "updated_at": "2026-07-11T12:00:00Z",
    }
    message = core.format_budget_advisory(status, 50)
    assert "52% used" in message
    assert "52,410 of 100,000" in message
    assert "Execution will continue" in message


def test_given_lock_pid_when_find_process_log_then_resolves_path(tmp_path):
    home = tmp_path / "home"
    state_dir = home / "session-state" / "sid1"
    state_dir.mkdir(parents=True)
    (state_dir / "inuse.4242.lock").write_text("")
    logs = home / "logs"
    logs.mkdir()
    target = logs / "process-abc-4242.log"
    target.write_text("{}\n")
    assert core.find_process_log(state_dir, home) == str(target)


def test_given_no_lock_when_find_process_log_then_returns_none(tmp_path):
    home = tmp_path / "home"
    state_dir = home / "session-state" / "sid1"
    state_dir.mkdir(parents=True)
    assert core.find_process_log(state_dir, home) is None


def test_given_mixed_blocks_when_parse_process_log_then_filters_by_interaction_and_kind(tmp_path):
    log = tmp_path / "process.log"
    log.write_text(
        "{\n"
        '  "kind": "assistant_usage",\n'
        '  "properties": {"interaction_id": "i1", "model": "m"},\n'
        '  "metrics": {"output_tokens": 5}\n'
        "}\n"
        "{\n"
        '  "kind": "assistant_usage",\n'
        '  "properties": {"interaction_id": "other"}\n'
        "}\n"
        "{\n"
        '  "kind": "something_else"\n'
        "}\n"
    )
    entries = core.parse_process_log(str(log), {"i1"})
    assert len(entries) == 1
    assert entries[0]["properties"]["interaction_id"] == "i1"


def test_given_session_events_when_scan_session_state_then_collects_metadata(tmp_path):
    state = tmp_path / "events.jsonl"
    _write_jsonl(
        state,
        [
            {
                "type": "assistant.message",
                "timestamp": "2026-01-01T00:00:01Z",
                "data": {"model": "gpt", "interactionId": "i1"},
            },
            {
                "type": "assistant.turn_start",
                "timestamp": "2026-01-01T00:00:00Z",
                "data": {"interactionId": "i2"},
            },
            {
                "type": "session.model_change",
                "timestamp": "2026-01-01T00:00:02Z",
                "data": {"reasoningEffort": "high"},
            },
            {
                "type": "subagent.started",
                "timestamp": "2026-01-01T00:00:03Z",
                "data": {"toolCallId": "t1", "agentName": "Researcher"},
            },
        ],
    )
    meta = core.scan_session_state(state)
    assert meta["messages"] == 1
    assert meta["turns"] == 1
    assert meta["models"] == {"gpt": 1}
    assert meta["interaction_ids"] == {"i1", "i2"}
    assert meta["reasoning_effort"] == "high"
    assert meta["subagent_map"] == {"t1": "Researcher"}
    assert meta["first_ts"] == "2026-01-01T00:00:00Z"
    assert meta["last_ts"] == "2026-01-01T00:00:03Z"


def _make_session(tmp_path, sid, state_rows, process_rows=None, pid=None, write_lock=True):
    """Create a minimal session directory tree with optional process log.

    Set ``write_lock=False`` to simulate a session that has ended (its lock
    file removed) while its process log still exists, exercising the
    interaction-id fallback path.
    """
    home = tmp_path / "home"
    state_dir = home / "session-state" / sid
    state_dir.mkdir(parents=True)
    _write_jsonl(state_dir / "events.jsonl", state_rows)
    if pid is not None and write_lock:
        (state_dir / f"inuse.{pid}.lock").write_text("")
    if process_rows is not None and pid is not None:
        logs = home / "logs"
        logs.mkdir(exist_ok=True)
        # Build process-log blocks in the brace-delimited format the parser
        # expects (top-level '{' on its own line, not JSONL).
        blocks = []
        for r in process_rows:
            inner = json.dumps(r, indent=2)
            blocks.append(inner + "\n")
        text = "".join(blocks)
        (logs / f"process-x-{pid}.log").write_text(text)
    return home, state_dir, state_dir / "events.jsonl"


def test_given_process_log_when_build_session_summary_then_uses_process_log(tmp_path):
    state_rows = [
        {
            "type": "assistant.message",
            "timestamp": "2026-01-01T00:00:00Z",
            "data": {"model": "m", "interactionId": "i1"},
        }
    ]
    process_rows = [
        {
            "kind": "assistant_usage",
            "properties": {"interaction_id": "i1", "model": "m"},
            "metrics": {
                "input_tokens": 10,
                "input_tokens_uncached": 7,
                "output_tokens": 20,
                "cache_read_tokens": 1,
                "cache_write_tokens": 2,
                "total_nano_aiu": 99,
            },
        }
    ]
    home, state_dir, state_file = _make_session(tmp_path, "sid1", state_rows, process_rows, pid=777)
    summary = core.build_session_summary(
        "sid1", state_dir, state_file, home, root_agent="RPI Agent"
    )
    assert summary["input_tokens"] == 10
    assert summary["input_tokens_uncached"] == 7
    assert summary["output_tokens"] == 20
    assert summary["cache_write_tokens"] == 2
    assert summary["total_nano_aiu"] == 99
    assert summary["model_usage"]["m"]["input_tokens"] == 10
    assert summary["model_usage"]["m"]["input_tokens_uncached"] == 7
    assert summary["token_source"] == "process_log"
    assert summary["gen_ai.agent.name"] == "RPI Agent"


def test_given_ended_session_when_build_summary_then_matches_log_by_iid(tmp_path):
    state_rows = [
        {
            "type": "assistant.message",
            "timestamp": "2026-01-01T00:00:00Z",
            "data": {"model": "m", "interactionId": "i1"},
        }
    ]
    process_rows = [
        {
            "kind": "assistant_usage",
            "properties": {"interaction_id": "i1", "model": "m"},
            "metrics": {
                "input_tokens": 30,
                "input_tokens_uncached": 5,
                "output_tokens": 12,
                "cache_read_tokens": 25,
                "cache_write_tokens": 0,
                "total_nano_aiu": 42,
            },
        }
    ]
    # pid names the process log file, but write_lock=False removes the lock so
    # the PID-based lookup fails and the interaction-id scan must recover it.
    home, state_dir, state_file = _make_session(
        tmp_path, "sid1", state_rows, process_rows, pid=888, write_lock=False
    )
    summary = core.build_session_summary("sid1", state_dir, state_file, home)
    assert summary["token_source"] == "process_log"
    assert summary["input_tokens"] == 30
    assert summary["input_tokens_uncached"] == 5


def test_given_no_process_log_when_build_session_summary_then_falls_back_to_state(tmp_path):
    state_rows = [
        {
            "type": "session.shutdown",
            "timestamp": "2026-01-01T00:00:01Z",
            "data": {
                "modelMetrics": {
                    "m": {
                        "requests": {"count": 2},
                        "usage": {
                            "inputTokens": 12,
                            "outputTokens": 7,
                            "cacheReadTokens": 4,
                            "cacheWriteTokens": 5,
                        },
                        "totalNanoAiu": 50,
                    }
                }
            },
        },
    ]
    home, state_dir, state_file = _make_session(tmp_path, "sid1", state_rows)
    summary = core.build_session_summary("sid1", state_dir, state_file, home)
    assert summary["output_tokens"] == 7
    assert summary["input_tokens"] == 12
    assert summary["cache_read_tokens"] == 4
    # Unified schema always reports cache_write_tokens.
    assert summary["cache_write_tokens"] == 5
    assert summary["token_source"] == "state_fallback"
    assert summary["total_nano_aiu"] == 50
    # inputTokens includes cache, so fresh input is recovered by subtraction.
    assert summary["input_tokens_uncached"] == 3


def test_given_resumed_session_when_build_session_summary_then_sums_shutdowns(tmp_path):
    def _shutdown(ts, in_tok, out_tok, cr, cw, nano):
        return {
            "type": "session.shutdown",
            "timestamp": ts,
            "data": {
                "modelMetrics": {
                    "m": {
                        "requests": {"count": 1},
                        "usage": {
                            "inputTokens": in_tok,
                            "outputTokens": out_tok,
                            "cacheReadTokens": cr,
                            "cacheWriteTokens": cw,
                        },
                        "totalNanoAiu": nano,
                    }
                }
            },
        }

    state_rows = [
        _shutdown("2026-01-01T00:00:01Z", 10, 3, 4, 2, 20),
        _shutdown("2026-01-01T00:00:02Z", 30, 5, 8, 6, 40),
    ]
    home, state_dir, state_file = _make_session(tmp_path, "sid1", state_rows)
    summary = core.build_session_summary("sid1", state_dir, state_file, home)
    assert summary["token_source"] == "state_fallback"
    assert summary["input_tokens"] == 40
    assert summary["output_tokens"] == 8
    assert summary["cache_read_tokens"] == 12
    assert summary["cache_write_tokens"] == 8
    assert summary["total_nano_aiu"] == 60
    # Fresh input summed per segment: (10-4-2) + (30-8-6) = 4 + 16 = 20.
    assert summary["input_tokens_uncached"] == 20


def test_given_no_shutdown_when_build_session_summary_then_input_unknown(tmp_path):
    state_rows = [
        {
            "type": "assistant.message",
            "timestamp": "2026-01-01T00:00:00Z",
            "data": {"model": "m", "outputTokens": 7, "interactionId": "i1"},
        },
    ]
    home, state_dir, state_file = _make_session(tmp_path, "sid1", state_rows)
    summary = core.build_session_summary("sid1", state_dir, state_file, home)
    assert summary["output_tokens"] == 7
    # No shutdown segment exists, so input is unknown (None), not a true zero.
    assert summary["input_tokens"] is None
    assert summary["cache_read_tokens"] is None
    assert summary["total_nano_aiu"] is None
    assert summary["token_source"] == "state_fallback"
    # Fresh input is unknown, so the key is omitted.
    assert "input_tokens_uncached" not in summary


def test_given_shutdown_missing_metrics_when_summary_then_output_from_messages(tmp_path):
    # One segment ends with modelMetrics; a later segment aborts without them.
    # assistant.message output stays complete, so the message sum (3+9=12)
    # must win over the lone shutdown's output (3).
    state_rows = [
        {
            "type": "assistant.message",
            "timestamp": "2026-01-01T00:00:00Z",
            "data": {"model": "m", "outputTokens": 3, "interactionId": "i1"},
        },
        {
            "type": "session.shutdown",
            "timestamp": "2026-01-01T00:00:01Z",
            "data": {
                "modelMetrics": {
                    "m": {
                        "requests": {"count": 1},
                        "usage": {
                            "inputTokens": 10,
                            "outputTokens": 3,
                            "cacheReadTokens": 4,
                            "cacheWriteTokens": 2,
                        },
                        "totalNanoAiu": 20,
                    }
                }
            },
        },
        {
            "type": "assistant.message",
            "timestamp": "2026-01-01T00:00:02Z",
            "data": {"model": "m", "outputTokens": 9, "interactionId": "i2"},
        },
        # Aborted resume segment: shutdown present but no modelMetrics.
        {
            "type": "session.shutdown",
            "timestamp": "2026-01-01T00:00:03Z",
            "data": {},
        },
    ]
    home, state_dir, state_file = _make_session(tmp_path, "sid1", state_rows)
    summary = core.build_session_summary("sid1", state_dir, state_file, home)
    assert summary["token_source"] == "state_fallback"
    # Output reconciled to the complete message sum, not the undercounting shutdown.
    assert summary["output_tokens"] == 12
    assert summary["model_usage"]["m"]["output_tokens"] == 12
    # Input/cache/AIU still come from the one segment that reported metrics.
    assert summary["input_tokens"] == 10
    assert summary["cache_read_tokens"] == 4
    assert summary["input_tokens_uncached"] == 4


def test_given_single_element_stack_when_current_then_returns_full_name(tmp_path):
    stack = core._AgentStack(tmp_path / ".stacks", "sid1")
    stack.push("Researcher")
    assert stack.current() == "Researcher"


def test_given_unique_and_conflicting_labels_when_root_store_resolves_conservatively(
    tmp_path,
):
    store = core._RootAgentStore(tmp_path / ".stacks", "sid1")
    assert store.record("RPI Agent") is True
    assert store.record("RPI Agent") is False
    assert store.resolved() == "RPI Agent"
    assert store.record("Other Agent") is True
    assert store.resolved() == ""


def test_given_subagent_pushed_when_build_entry_pretooluse_then_reports_agent(tmp_path):
    stack = core._AgentStack(tmp_path / ".stacks", "sid1")
    core.build_entry(
        {"hook_event_name": "SubagentStart", "agent_name": "Coder"}, "SubagentStart", stack
    )
    entry = core.build_entry(
        {"hook_event_name": "PreToolUse", "tool_name": "read"}, "PreToolUse", stack
    )
    assert entry["agent"] == "Coder"


def test_given_unknown_event_when_build_entry_then_returns_none(tmp_path):
    stack = core._AgentStack(tmp_path / ".stacks", "sid1")
    assert core.build_entry({"hook_event_name": "unknown"}, "unknown", stack) is None


def test_given_skill_path_when_build_entry_then_detects_skill(tmp_path):
    stack = core._AgentStack(tmp_path / ".stacks", "sid1")
    skill_file = tmp_path / "SKILL.md"
    skill_file.write_text("x" * 40)
    data = {
        "hook_event_name": "PreToolUse",
        "tool_name": "read",
        "tool_input": {"filePath": "/repo/.github/skills/coll/my-skill/SKILL.md"},
    }
    entry = core.build_entry(data, "PreToolUse", stack)
    assert entry["skill"] == "my-skill"


def test_given_stop_event_when_mode_collect_then_writes_entry_and_summary(tmp_path, monkeypatch):
    tel_dir = tmp_path / "tel"
    home = tmp_path / "home"
    state_dir = home / "session-state" / "sid1"
    state_dir.mkdir(parents=True)
    _write_jsonl(
        state_dir / "events.jsonl",
        [
            {
                "type": "assistant.message",
                "timestamp": "2026-01-01T00:00:00Z",
                "data": {"model": "m", "outputTokens": 9},
            }
        ],
    )
    monkeypatch.setenv("HVE_TELEMETRY_DIR", str(tel_dir))
    monkeypatch.setenv("COPILOT_HOME", str(home))
    payload = {
        "hook_event_name": "Stop",
        "session_id": "sid1",
        "timestamp": "2026-01-02T00:00:00Z",
    }
    monkeypatch.setattr("sys.stdin", io.StringIO(json.dumps(payload)))
    assert core._mode_collect() == 0

    logs = list(tel_dir.glob("sessions-*.jsonl"))
    assert len(logs) == 1
    events = [json.loads(line) for line in logs[0].read_text().splitlines()]
    assert events[0]["event"] == "Stop"
    assert any(e["event"] == "SessionSummary" for e in events)


def test_given_root_agent_environment_when_session_stops_then_summary_is_attributed(
    tmp_path, monkeypatch
):
    tel_dir = tmp_path / "tel"
    home = tmp_path / "home"
    hve = tmp_path / "hve"
    state_dir = home / "session-state" / "sid1"
    state_dir.mkdir(parents=True)
    _write_jsonl(
        state_dir / "events.jsonl",
        [
            {
                "type": "assistant.message",
                "timestamp": "2026-01-01T00:00:00Z",
                "data": {"model": "m", "outputTokens": 9},
            }
        ],
    )
    monkeypatch.setenv("HVE_TELEMETRY_DIR", str(tel_dir))
    monkeypatch.setenv("COPILOT_HOME", str(home))
    monkeypatch.setenv("HVE_HOME", str(hve))
    monkeypatch.setenv("HVE_TELEMETRY_ROOT_AGENT", "RPI Agent")

    start = {"hook_event_name": "SessionStart", "session_id": "sid1"}
    monkeypatch.setattr("sys.stdin", io.StringIO(json.dumps(start)))
    assert core._mode_collect() == 0

    stop = {"hook_event_name": "Stop", "session_id": "sid1"}
    monkeypatch.setattr("sys.stdin", io.StringIO(json.dumps(stop)))
    assert core._mode_collect() == 0

    log_file = next(tel_dir.glob("sessions-*.jsonl"))
    events = [json.loads(line) for line in log_file.read_text().splitlines()]
    summaries = [event for event in events if event["event"] == "SessionSummary"]
    assert summaries[-1]["gen_ai.agent.name"] == "RPI Agent"
    assert not (tel_dir / ".stacks" / "root-sid1.json").exists()


def test_given_crossed_budget_when_collect_emits_then_response_contains_one_advisory(
    tmp_path, monkeypatch, capsys
):
    tel_dir = tmp_path / "tel"
    home = tmp_path / "home"
    state_dir = home / "session-state" / "sid1"
    state_dir.mkdir(parents=True)
    (state_dir / "events.jsonl").write_text("", encoding="utf-8")
    summary = {
        "input_tokens": 40,
        "output_tokens": 20,
        "token_source": "process_log",
        "last_ts": "2026-07-11T12:00:00Z",
    }
    monkeypatch.setenv("HVE_TELEMETRY_DIR", str(tel_dir))
    monkeypatch.setenv("COPILOT_HOME", str(home))
    monkeypatch.setenv("HVE_TOKEN_BUDGET", "100")
    monkeypatch.setattr(core, "build_session_summary", lambda *args, **kwargs: summary)
    payload = {"hook_event_name": "UserPromptSubmit", "session_id": "sid1"}

    monkeypatch.setattr("sys.stdin", io.StringIO(json.dumps(payload)))
    assert core._mode_collect(emit_response=True) == 0
    first_response = json.loads(capsys.readouterr().out)

    monkeypatch.setattr("sys.stdin", io.StringIO(json.dumps(payload)))
    assert core._mode_collect(emit_response=True) == 0
    second_response = json.loads(capsys.readouterr().out)

    assert first_response["continue"] is True
    assert "60% used" in first_response["systemMessage"]
    assert second_response == {"continue": True}
    state = json.loads((tel_dir / ".budget-state" / "sid1.json").read_text())
    assert state["notified_thresholds"] == [30, 50]


def test_given_stop_budget_when_collect_emits_then_response_has_no_new_message(
    tmp_path, monkeypatch, capsys
):
    tel_dir = tmp_path / "tel"
    home = tmp_path / "home"
    state_dir = home / "session-state" / "sid1"
    state_dir.mkdir(parents=True)
    (state_dir / "events.jsonl").write_text("", encoding="utf-8")
    summary = {
        "input_tokens": 75,
        "output_tokens": 10,
        "token_source": "state_fallback",
        "last_ts": "2026-07-11T12:00:00Z",
    }
    monkeypatch.setenv("HVE_TELEMETRY_DIR", str(tel_dir))
    monkeypatch.setenv("COPILOT_HOME", str(home))
    monkeypatch.setenv("HVE_TOKEN_BUDGET", "100")
    monkeypatch.setattr(core, "build_session_summary", lambda *args, **kwargs: summary)
    payload = {"hook_event_name": "Stop", "session_id": "sid1"}
    monkeypatch.setattr("sys.stdin", io.StringIO(json.dumps(payload)))

    assert core._mode_collect(emit_response=True) == 0

    assert json.loads(capsys.readouterr().out) == {"continue": True}
    state = json.loads((tel_dir / ".budget-state" / "sid1.json").read_text())
    assert state["crossed_thresholds"] == [30, 50, 70]
    assert state["notified_thresholds"] == []


def test_given_hook_root_agent_when_aggregate_session_then_regenerated_summary_keeps_it(
    tmp_path, monkeypatch
):
    home = tmp_path / "home"
    state_dir = home / "session-state" / "sid1"
    state_dir.mkdir(parents=True)
    _write_jsonl(
        state_dir / "events.jsonl",
        [
            {
                "type": "session.shutdown",
                "timestamp": "2026-01-01T00:00:00Z",
                "data": {"modelMetrics": {}},
            }
        ],
    )
    hook_file = tmp_path / "hooks.jsonl"
    _write_jsonl(hook_file, [{"sid": "sid1", "gen_ai.agent.name": "RPI Agent"}])
    output = tmp_path / "summaries.jsonl"
    monkeypatch.setenv("COPILOT_HOME", str(home))

    assert core._mode_aggregate_session(str(output), [str(hook_file)]) == 0
    summary = json.loads(output.read_text().strip())
    assert summary["gen_ai.agent.name"] == "RPI Agent"


def test_given_precompact_event_when_mode_collect_then_writes_summary(tmp_path, monkeypatch):
    tel_dir = tmp_path / "tel"
    home = tmp_path / "home"
    state_dir = home / "session-state" / "sid1"
    state_dir.mkdir(parents=True)
    _write_jsonl(
        state_dir / "events.jsonl",
        [
            {
                "type": "assistant.message",
                "timestamp": "2026-01-01T00:00:00Z",
                "data": {"model": "m", "outputTokens": 9},
            }
        ],
    )
    monkeypatch.setenv("HVE_TELEMETRY_DIR", str(tel_dir))
    monkeypatch.setenv("COPILOT_HOME", str(home))
    payload = {
        "hook_event_name": "PreCompact",
        "session_id": "sid1",
        "timestamp": "2026-01-02T00:00:00Z",
    }
    monkeypatch.setattr("sys.stdin", io.StringIO(json.dumps(payload)))
    assert core._mode_collect() == 0

    logs = list(tel_dir.glob("sessions-*.jsonl"))
    assert len(logs) == 1
    events = [json.loads(line) for line in logs[0].read_text().splitlines()]
    assert events[0]["event"] == "PreCompact"
    # PreCompact captures a summary before process logs rotate.
    assert any(e["event"] == "SessionSummary" for e in events)


def test_given_traversal_sid_when_mode_collect_then_rejects(tmp_path, monkeypatch):
    tel_dir = tmp_path / "tel"
    monkeypatch.setenv("HVE_TELEMETRY_DIR", str(tel_dir))
    payload = {"hook_event_name": "SessionStart", "session_id": "../escape"}
    monkeypatch.setattr("sys.stdin", io.StringIO(json.dumps(payload)))
    assert core._mode_collect() == 0
    # No telemetry written for a rejected sid.
    assert not tel_dir.exists() or not list(tel_dir.glob("sessions-*.jsonl"))


def test_given_new_dir_when_register_telemetry_dir_then_appends_absolute_path(tmp_path):
    registry = tmp_path / "telemetry-dirs.txt"
    tel_dir = tmp_path / "proj" / "tel"
    tel_dir.mkdir(parents=True)
    core.register_telemetry_dir(tel_dir, registry)
    assert core.read_registry_dirs(registry) == [str(tel_dir.resolve())]


def test_given_existing_entry_when_register_telemetry_dir_then_dedups(tmp_path):
    registry = tmp_path / "telemetry-dirs.txt"
    tel_dir = tmp_path / "tel"
    tel_dir.mkdir()
    core.register_telemetry_dir(tel_dir, registry)
    core.register_telemetry_dir(tel_dir, registry)
    assert core.read_registry_dirs(registry) == [str(tel_dir.resolve())]


def test_given_blank_and_duplicate_lines_when_read_registry_dirs_then_normalizes(tmp_path):
    registry = tmp_path / "telemetry-dirs.txt"
    registry.write_text("/a\n\n  \n/b\n/a\n", encoding="utf-8")
    assert core.read_registry_dirs(registry) == ["/a", "/b"]


def test_given_session_start_when_mode_collect_then_registers_dir(tmp_path, monkeypatch):
    tel_dir = tmp_path / "tel"
    home = tmp_path / "home"
    hve = tmp_path / "hve"
    monkeypatch.setenv("HVE_TELEMETRY_DIR", str(tel_dir))
    monkeypatch.setenv("COPILOT_HOME", str(home))
    monkeypatch.setenv("HVE_HOME", str(hve))
    payload = {"hook_event_name": "SessionStart", "session_id": "sid1"}
    monkeypatch.setattr("sys.stdin", io.StringIO(json.dumps(payload)))
    assert core._mode_collect() == 0
    assert core.read_registry_dirs(hve / "telemetry-dirs.txt") == [str(tel_dir.resolve())]
    # A cross-project launcher for the host platform is emitted in the HVE home.
    if core._is_windows():
        assert (hve / "generate-report.ps1").is_file()
        assert (hve / "clean-telemetry.ps1").is_file()
    else:
        assert (hve / "generate-report.sh").is_file()
        assert (hve / "clean-telemetry.sh").is_file()


def test_given_stale_entries_when_mode_list_dirs_then_prunes_and_prints(
    tmp_path, monkeypatch, capsys
):
    hve = tmp_path / "hve"
    hve.mkdir()
    live = tmp_path / "live"
    live.mkdir()
    dead = tmp_path / "dead"
    registry = hve / "telemetry-dirs.txt"
    registry.write_text(f"{live}\n{dead}\n", encoding="utf-8")
    monkeypatch.setenv("HVE_HOME", str(hve))
    assert core._mode_list_dirs() == 0
    out = capsys.readouterr().out.splitlines()
    assert out == [str(live)]
    # Dead entry is pruned from the registry on read.
    assert core.read_registry_dirs(registry) == [str(live)]


def test_given_posix_when_write_report_launchers_then_writes_sh_only(tmp_path, monkeypatch):
    hve = tmp_path / "hve"
    script_dir = tmp_path / "hook"
    script_dir.mkdir()
    monkeypatch.setenv("HVE_HOME", str(hve))
    monkeypatch.setattr(core, "_is_windows", lambda: False)
    core.write_report_launchers(script_dir)
    report_script = str(script_dir / "generate-telemetry-report.sh")
    out_path = str(hve / "report.generated.html")
    sh = (hve / "generate-report.sh").read_text(encoding="utf-8")
    assert report_script in sh
    assert out_path in sh
    assert "--all-dirs" in sh
    # No PowerShell launcher on POSIX.
    assert not (hve / "generate-report.ps1").exists()


def test_given_windows_when_write_report_launchers_then_writes_ps1_only(tmp_path, monkeypatch):
    hve = tmp_path / "hve"
    script_dir = tmp_path / "hook"
    script_dir.mkdir()
    monkeypatch.setenv("HVE_HOME", str(hve))
    monkeypatch.setattr(core, "_is_windows", lambda: True)
    core.write_report_launchers(script_dir)
    report_ps1 = str(script_dir / "Invoke-TelemetryReport.ps1")
    out_path = str(hve / "report.generated.html")
    ps = (hve / "generate-report.ps1").read_text(encoding="utf-8")
    # Native delegation to the PowerShell generator, no bash.
    assert report_ps1 in ps
    assert out_path in ps
    assert "-AllDirs" in ps
    assert "bash" not in ps
    # No POSIX launcher on Windows.
    assert not (hve / "generate-report.sh").exists()


def test_given_posix_when_write_report_launchers_then_clean_sh_delegates_to_bash(
    tmp_path, monkeypatch
):
    hve = tmp_path / "hve"
    script_dir = tmp_path / "hook"
    script_dir.mkdir()
    monkeypatch.setenv("HVE_HOME", str(hve))
    monkeypatch.setattr(core, "_is_windows", lambda: False)
    core.write_report_launchers(script_dir)
    clean_script = str(script_dir / "clean-telemetry.sh")
    sh = (hve / "clean-telemetry.sh").read_text(encoding="utf-8")
    assert clean_script in sh
    assert "--all-dirs" in sh
    assert not (hve / "clean-telemetry.ps1").exists()


def test_given_windows_when_write_report_launchers_then_clean_ps1_is_native(tmp_path, monkeypatch):
    hve = tmp_path / "hve"
    script_dir = tmp_path / "hook"
    script_dir.mkdir()
    monkeypatch.setenv("HVE_HOME", str(hve))
    monkeypatch.setattr(core, "_is_windows", lambda: True)
    core.write_report_launchers(script_dir)
    clean_ps1 = str(script_dir / "Invoke-TelemetryClean.ps1")
    ps = (hve / "clean-telemetry.ps1").read_text(encoding="utf-8")
    # Native delegation to the PowerShell wrapper, no bash.
    assert clean_ps1 in ps
    assert "-AllDirs" in ps
    assert "bash" not in ps
    assert not (hve / "clean-telemetry.sh").exists()


def _seed_telemetry_store(tel_dir):
    """Populate a telemetry directory with representative artifacts plus an
    unrelated file that cleanup must preserve."""
    tel_dir.mkdir(parents=True)
    (tel_dir / "sessions-2026-01-01.jsonl").write_text("{}\n", encoding="utf-8")
    (tel_dir / "sessions-2026-01-02.jsonl").write_text("{}\n", encoding="utf-8")
    (tel_dir / "raw-input.jsonl").write_text("{}\n", encoding="utf-8")
    (tel_dir / "report.generated.html").write_text("<html>", encoding="utf-8")
    stacks = tel_dir / ".stacks"
    stacks.mkdir()
    (stacks / "sid1.json").write_text("[]", encoding="utf-8")
    (stacks / "root-sid1.json").write_text('["RPI Agent"]', encoding="utf-8")
    budget_state = tel_dir / ".budget-state"
    budget_state.mkdir()
    (budget_state / "sid1.json").write_text("{}", encoding="utf-8")
    keep = tel_dir / "keep-me.txt"
    keep.write_text("user data", encoding="utf-8")
    return keep


def test_given_store_when_clean_telemetry_dir_then_removes_only_artifacts(tmp_path):
    tel_dir = tmp_path / "tel"
    keep = _seed_telemetry_store(tel_dir)
    removed = []
    core.clean_telemetry_dir(tel_dir, dry_run=False, removed=removed)
    assert not (tel_dir / "sessions-2026-01-01.jsonl").exists()
    assert not (tel_dir / "sessions-2026-01-02.jsonl").exists()
    assert not (tel_dir / "raw-input.jsonl").exists()
    assert not (tel_dir / "report.generated.html").exists()
    assert not (tel_dir / ".stacks").exists()
    assert not (tel_dir / ".budget-state").exists()
    # Unrelated files are preserved.
    assert keep.exists()
    assert len(removed) == 6


def test_given_dry_run_when_clean_telemetry_dir_then_reports_without_deleting(tmp_path):
    tel_dir = tmp_path / "tel"
    _seed_telemetry_store(tel_dir)
    removed = []
    core.clean_telemetry_dir(tel_dir, dry_run=True, removed=removed)
    assert (tel_dir / "raw-input.jsonl").exists()
    assert (tel_dir / ".stacks").exists()
    assert (tel_dir / ".budget-state").exists()
    assert len(removed) == 6


def test_given_current_store_when_mode_clean_then_cleans_only_current(tmp_path, monkeypatch):
    current = tmp_path / "current"
    other = tmp_path / "other"
    hve = tmp_path / "hve"
    _seed_telemetry_store(current)
    _seed_telemetry_store(other)
    hve.mkdir()
    registry = hve / "telemetry-dirs.txt"
    registry.write_text(f"{other}\n", encoding="utf-8")
    monkeypatch.setenv("HVE_TELEMETRY_DIR", str(current))
    monkeypatch.setenv("HVE_HOME", str(hve))
    assert core._mode_clean(all_dirs=False, dry_run=False) == 0
    assert not (current / "raw-input.jsonl").exists()
    # Without --all-dirs, registered stores and the registry are untouched.
    assert (other / "raw-input.jsonl").exists()
    assert registry.exists()


def test_given_all_dirs_when_mode_clean_then_cleans_registry_and_home(tmp_path, monkeypatch):
    current = tmp_path / "current"
    other = tmp_path / "other"
    hve = tmp_path / "hve"
    _seed_telemetry_store(current)
    _seed_telemetry_store(other)
    hve.mkdir()
    registry = hve / "telemetry-dirs.txt"
    registry.write_text(f"{other}\n", encoding="utf-8")
    (hve / "report.generated.html").write_text("<html>", encoding="utf-8")
    (hve / "generate-report.sh").write_text("#!/usr/bin/env bash\n", encoding="utf-8")
    monkeypatch.setenv("HVE_TELEMETRY_DIR", str(current))
    monkeypatch.setenv("HVE_HOME", str(hve))
    assert core._mode_clean(all_dirs=True, dry_run=False) == 0
    assert not (current / "raw-input.jsonl").exists()
    assert not (other / "raw-input.jsonl").exists()
    assert not registry.exists()
    assert not (hve / "report.generated.html").exists()
    assert not (hve / "generate-report.sh").exists()


def test_given_clean_mode_when_main_dispatches_then_parses_flags(tmp_path, monkeypatch):
    current = tmp_path / "current"
    _seed_telemetry_store(current)
    monkeypatch.setenv("HVE_TELEMETRY_DIR", str(current))
    assert core.main(["clean", "--dry-run"]) == 0
    # Dry-run leaves artifacts in place.
    assert (current / "raw-input.jsonl").exists()
