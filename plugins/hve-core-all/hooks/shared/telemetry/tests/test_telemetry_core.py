# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Tests for the canonical telemetry engine (_telemetry_core)."""

from __future__ import annotations

import io
import json

import pytest

import _telemetry_core as core


def _write_jsonl(path, rows):
    """Write a list of dicts as newline-delimited JSON."""
    path.write_text("".join(json.dumps(r) + "\n" for r in rows))


def test_given_blank_and_malformed_lines_when_iter_jsonl_then_skips_them(tmp_path):
    f = tmp_path / "events.jsonl"
    f.write_text('{"a": 1}\n\n  \nnot-json\n{"b": 2}\n')
    rows = list(core.iter_jsonl(f))
    assert rows == [{"a": 1}, {"b": 2}]


def test_given_missing_file_when_iter_jsonl_then_returns_empty(tmp_path):
    assert list(core.iter_jsonl(tmp_path / "nope.jsonl")) == []


def test_given_overlapping_sids_when_collect_sids_then_dedups(tmp_path):
    a = tmp_path / "a.jsonl"
    b = tmp_path / "b.jsonl"
    _write_jsonl(a, [{"sid": "s1"}, {"sid": "s2"}, {"event": "x"}])
    _write_jsonl(b, [{"sid": "s2"}, {"sid": "s3"}])
    assert core.collect_sids([str(a), str(b)]) == {"s1", "s2", "s3"}


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
    summary = core.build_session_summary("sid1", state_dir, state_file, home)
    assert summary["input_tokens"] == 10
    assert summary["input_tokens_uncached"] == 7
    assert summary["output_tokens"] == 20
    assert summary["cache_write_tokens"] == 2
    assert summary["total_nano_aiu"] == 99
    assert summary["model_usage"]["m"]["input_tokens"] == 10
    assert summary["model_usage"]["m"]["input_tokens_uncached"] == 7
    assert summary["token_source"] == "process_log"


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


def test_given_cli_pretooluse_payload_when_normalize_event_then_infers_pretooluse():
    # The CLI omits the event name and sends a tool payload without toolResult.
    assert (
        core._normalize_event({"sessionId": "s", "toolName": "bash", "toolArgs": "{}"})
        == "PreToolUse"
    )


def test_given_cli_posttooluse_payload_when_normalize_event_then_infers_posttooluse():
    data = {"sessionId": "s", "toolName": "bash", "toolArgs": "{}", "toolResult": {}}
    assert core._normalize_event(data) == "PostToolUse"


def test_given_cli_prompt_payload_when_normalize_event_then_infers_userpromptsubmit():
    assert core._normalize_event({"sessionId": "s", "prompt": "hi"}) == "UserPromptSubmit"


def test_given_cli_subagent_start_payload_when_normalize_event_then_infers_start():
    data = {"sessionId": "s", "agentName": "explore", "agentDescription": "x"}
    assert core._normalize_event(data) == "SubagentStart"


def test_given_cli_subagent_stop_payload_when_normalize_event_then_infers_stop():
    data = {"sessionId": "s", "agentName": "explore", "stopReason": "end_turn"}
    assert core._normalize_event(data) == "SubagentStop"


def test_given_cli_agent_stop_payload_when_normalize_event_then_infers_stop():
    # An agent turn end carries stopReason but no agentName.
    assert core._normalize_event({"sessionId": "s", "stopReason": "end_turn"}) == "Stop"


def test_given_cli_session_end_payload_when_normalize_event_then_infers_sessionend():
    # A real sessionEnd payload carries a top-level reason and no stopReason.
    data = {"sessionId": "s", "reason": "user_exit"}
    assert core._normalize_event(data) == "SessionEnd"


@pytest.mark.parametrize("reason", ["complete", "error", "abort", "timeout", "user_exit"])
def test_given_documented_reason_value_when_normalize_event_then_infers_sessionend(reason):
    assert core._normalize_event({"sessionId": "s", "reason": reason}) == "SessionEnd"


def test_given_unrelated_reason_value_when_normalize_event_then_stays_unknown():
    # An arbitrary reason on an unrecognized payload must not be mistaken for
    # a session end; only the documented sessionEnd values match.
    assert core._normalize_event({"sessionId": "s", "reason": "tool_denied"}) == "unknown"


def test_given_cli_session_start_payload_when_normalize_event_then_infers_sessionstart():
    assert core._normalize_event({"sessionId": "s", "source": "startup"}) == "SessionStart"


def test_given_vscode_session_end_payload_when_normalize_event_then_infers_sessionend():
    data = {"hook_event_name": "SessionEnd", "session_id": "s", "reason": "complete"}
    assert core._normalize_event(data) == "SessionEnd"


def test_given_explicit_event_name_when_normalize_event_then_shape_inference_skipped():
    # VS Code supplies the event name, so inference must not override it.
    data = {"hook_event_name": "SessionStart", "toolName": "bash"}
    assert core._normalize_event(data) == "SessionStart"


def test_given_cli_json_string_toolargs_when_build_entry_then_extracts_keys(tmp_path):
    # The CLI serializes tool arguments as a JSON string; build_entry decodes it.
    stack = core._AgentStack(tmp_path / ".stacks", "sid1")
    data = {
        "sessionId": "s",
        "toolName": "bash",
        "toolArgs": json.dumps({"command": "ls", "description": "list"}),
    }
    entry = core.build_entry(data, "PreToolUse", stack)
    assert sorted(entry["tool_input_keys"]) == ["command", "description"]


def test_given_session_end_when_build_entry_then_records_reason(tmp_path):
    stack = core._AgentStack(tmp_path / ".stacks", "sid1")
    data = {"sessionId": "sid1", "reason": "user_exit"}
    entry = core.build_entry(data, "SessionEnd", stack)
    assert entry["event"] == "SessionEnd"
    assert entry["reason"] == "user_exit"
    assert "stop_reason" not in entry


def test_given_stop_event_with_reason_only_when_build_entry_then_falls_back_to_reason(tmp_path):
    # A surface may name the event Stop yet send a session-end style payload.
    stack = core._AgentStack(tmp_path / ".stacks", "sid1")
    data = {"sessionId": "sid1", "reason": "complete"}
    entry = core.build_entry(data, "Stop", stack)
    assert entry["stop_reason"] == "complete"


def test_given_session_end_event_when_mode_collect_then_writes_entry_and_summary(
    tmp_path, monkeypatch
):
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
    # A real CLI sessionEnd payload: top-level reason, no event name, no stopReason.
    payload = {
        "sessionId": "sid1",
        "timestamp": 1753195629801,
        "cwd": str(tmp_path),
        "reason": "complete",
    }
    monkeypatch.setattr("sys.stdin", io.StringIO(json.dumps(payload)))
    assert core._mode_collect() == 0

    logs = list(tel_dir.glob("sessions-*.jsonl"))
    assert len(logs) == 1
    events = [json.loads(line) for line in logs[0].read_text().splitlines()]
    assert events[0]["event"] == "SessionEnd"
    assert events[0]["reason"] == "complete"
    assert any(e["event"] == "SessionSummary" for e in events)


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
    # Unrelated files are preserved.
    assert keep.exists()
    assert len(removed) == 5


def test_given_dry_run_when_clean_telemetry_dir_then_reports_without_deleting(tmp_path):
    tel_dir = tmp_path / "tel"
    _seed_telemetry_store(tel_dir)
    removed = []
    core.clean_telemetry_dir(tel_dir, dry_run=True, removed=removed)
    assert (tel_dir / "raw-input.jsonl").exists()
    assert (tel_dir / ".stacks").exists()
    assert len(removed) == 5


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
