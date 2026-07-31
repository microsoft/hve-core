# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Tests for the canonical telemetry engine (_telemetry_core)."""

from __future__ import annotations

import io
import json
import os
import re
import subprocess
import sys

import pytest

import _telemetry_core as core


def _write_jsonl(path, rows):
    """Write a list of dicts as newline-delimited JSON."""
    path.write_text("".join(json.dumps(r) + "\n" for r in rows))


@pytest.fixture(autouse=True)
def _isolate_hve_home(tmp_path, monkeypatch):
    """Keep registry and launcher writes out of the real user home."""
    monkeypatch.setenv("HVE_HOME", str(tmp_path / "hve-home"))


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


def _session_records(tel_dir):
    """Read every record the store holds, in file order."""
    records = []
    for path in _session_files(tel_dir):
        text = path.read_text(encoding="utf-8")
        records.extend(json.loads(line) for line in text.splitlines() if line.strip())
    return records


def _session_files(tel_dir):
    """Return every session log and shard the store holds, in name order."""
    return sorted(tel_dir.glob("sessions-*.jsonl"))


def test_given_one_active_agent_when_replayed_then_reports_full_name(tmp_path):
    stack = core._AgentStack(tmp_path / ".stacks", "sid1")
    stack.push("sub-1", "Researcher")
    assert stack.active() == ["Researcher"]


def test_given_overlapping_subagents_when_one_stops_then_removes_it_by_id(tmp_path):
    """Subagents can overlap, so a stop must not simply drop the newest entry."""
    stack = core._AgentStack(tmp_path / ".stacks", "sid1")
    stack.push("sub-1", "Alpha")
    stack.push("sub-2", "Beta")
    stack.pop("sub-1", "Alpha")
    assert stack.active() == ["Beta"]
    stack.pop("sub-2", "Beta")
    assert stack.active() == []


def test_given_same_named_subagents_when_one_stops_then_keeps_the_other(tmp_path):
    """Concurrent subagents share a type name; only the invocation id separates them."""
    stack = core._AgentStack(tmp_path / ".stacks", "sid1")
    stack.push("sub-1", "Explore")
    stack.push("sub-2", "Explore")
    stack.pop("sub-1", "Explore")
    assert stack.active() == ["Explore"]


def test_given_unmatched_pop_when_replaying_then_keeps_live_agents(tmp_path):
    """A lost push must not let the stop evict an unrelated running agent."""
    stack = core._AgentStack(tmp_path / ".stacks", "sid1")
    stack.push("sub-1", "Alpha")
    stack.pop("sub-9", "Ghost")
    assert stack.active() == ["Alpha"]


def test_given_same_timestamp_push_and_pop_when_replaying_then_cancels(tmp_path):
    """A short subagent stamps both ops in one tick on a coarse clock.

    Sorting the pop first would leave it unmatched and the agent active forever.
    """
    stack = core._AgentStack(tmp_path / ".stacks", "sid1")
    same_ts = "2026-01-01T00:00:00+00:00"
    for op in ("pop", "push"):
        core.append_jsonl(stack.stack_file, {"ts": same_ts, "op": op, "id": "sub-1", "agent": "A"})
    assert stack.active() == []


def test_given_name_only_surface_when_pushed_then_name_serves_as_identity(tmp_path):
    stack = core._AgentStack(tmp_path / ".stacks", "sid1")
    stack.push("", "Alpha")
    stack.pop("", "Alpha")
    assert stack.active() == []


def test_given_active_agents_when_cleared_then_returns_to_root(tmp_path):
    stack = core._AgentStack(tmp_path / ".stacks", "sid1")
    stack.push("sub-1", "Alpha")
    stack.push("sub-2", "Beta")
    stack.clear()
    assert stack.active() == []


def test_given_subagent_pushed_when_build_entry_pretooluse_then_lists_candidates(tmp_path):
    """Tool calls run in parallel, so an active subagent is only a candidate."""
    stack = core._AgentStack(tmp_path / ".stacks", "sid1")
    core.build_entry(
        {"hook_event_name": "SubagentStart", "agent_name": "Coder"}, "SubagentStart", stack
    )
    entry = core.build_entry(
        {"hook_event_name": "PreToolUse", "tool_name": "read"}, "PreToolUse", stack
    )
    assert "agent" not in entry
    assert entry["agents"] == ["root", "Coder"]


def test_given_no_subagent_when_build_entry_pretooluse_then_credits_root(tmp_path):
    stack = core._AgentStack(tmp_path / ".stacks", "sid1")
    entry = core.build_entry(
        {"hook_event_name": "PreToolUse", "tool_name": "read"}, "PreToolUse", stack
    )
    assert entry["agent"] == "root"
    assert "agents" not in entry


def test_given_overlapping_subagents_when_build_entry_then_declines_to_guess(tmp_path):
    """No tool payload names its caller, so overlap must not credit one agent."""
    stack = core._AgentStack(tmp_path / ".stacks", "sid1")
    stack.push("sub-1", "Alpha")
    stack.push("sub-2", "Beta")
    entry = core.build_entry(
        {"hook_event_name": "PostToolUse", "tool_name": "read", "tool_response": ""},
        "PostToolUse",
        stack,
    )
    assert "agent" not in entry
    assert entry["agents"] == ["root", "Alpha", "Beta"]


def test_given_tool_use_id_when_build_entry_then_records_it(tmp_path):
    stack = core._AgentStack(tmp_path / ".stacks", "sid1")
    entry = core.build_entry(
        {"hook_event_name": "PreToolUse", "tool_name": "read", "tool_use_id": "call-7"},
        "PreToolUse",
        stack,
    )
    assert entry["tool_use_id"] == "call-7"


def test_given_no_tool_use_id_when_build_entry_then_omits_it(tmp_path):
    stack = core._AgentStack(tmp_path / ".stacks", "sid1")
    entry = core.build_entry(
        {"hook_event_name": "PreToolUse", "tool_name": "read"}, "PreToolUse", stack
    )
    assert "tool_use_id" not in entry


def test_given_vscode_subagent_lifecycle_when_build_entry_then_stops_by_id(tmp_path):
    """VS Code identifies a subagent by agent_id; agent_type is only its label."""
    stack = core._AgentStack(tmp_path / ".stacks", "sid1")
    for aid in ("sub-1", "sub-2"):
        core.build_entry(
            {"session_id": "sid1", "agent_id": aid, "agent_type": "Explore"},
            "SubagentStart",
            stack,
        )
    core.build_entry(
        {"session_id": "sid1", "agent_id": "sub-1", "agent_type": "Explore"},
        "SubagentStop",
        stack,
    )
    assert stack.active() == ["Explore"]


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


def test_given_flat_skill_path_when_build_entry_then_detects_skill(tmp_path):
    """VS Code ships skills as ``skills/<name>/SKILL.md``, with no collection dir."""
    stack = core._AgentStack(tmp_path / ".stacks", "sid1")
    data = {
        "hook_event_name": "PreToolUse",
        "tool_name": "read_file",
        "tool_input": {"filePath": r"/repo/.github/skills/chronicle/SKILL.md"},
    }
    entry = core.build_entry(data, "PreToolUse", stack)
    assert entry["skill"] == "chronicle"


def test_given_cli_pretooluse_payload_when_normalize_event_then_infers_pretooluse():
    # The CLI omits the event name and sends a tool payload without toolResult.
    assert (
        core._normalize_event({"sessionId": "s", "toolName": "bash", "toolArgs": "{}"})
        == "PreToolUse"
    )


def test_given_cli_posttooluse_payload_when_normalize_event_then_infers_posttooluse():
    data = {"sessionId": "s", "toolName": "bash", "toolArgs": "{}", "toolResult": {}}
    assert core._normalize_event(data) == "PostToolUse"


def test_given_snake_case_tool_response_when_normalize_event_then_infers_posttooluse():
    # VS Code names the tool output tool_response; without alias-aware
    # inference this payload is mistaken for a PreToolUse.
    data = {"session_id": "s", "tool_name": "read", "tool_response": {}}
    assert core._normalize_event(data) == "PostToolUse"


def test_given_snake_case_stop_reason_when_normalize_event_then_infers_subagent_stop():
    data = {"session_id": "s", "agent_name": "explore", "stop_reason": "end_turn"}
    assert core._normalize_event(data) == "SubagentStop"


def test_given_tool_response_payload_when_build_entry_then_measures_length(tmp_path):
    stack = core._AgentStack(tmp_path / ".stacks", "sid1")
    data = {
        "session_id": "sid1",
        "tool_name": "read",
        "tool_response": {"text_result_for_llm": "abcde"},
    }
    entry = core.build_entry(data, "PostToolUse", stack)
    assert entry["tool_response_len"] == 5


def test_given_vscode_subagent_payload_when_build_entry_then_names_agent(tmp_path):
    # VS Code labels the subagent with agent_type and identifies it by agent_id.
    stack = core._AgentStack(tmp_path / ".stacks", "sid1")
    data = {"session_id": "sid1", "agent_id": "sub-1", "agent_type": "Plan"}
    entry = core.build_entry(data, "SubagentStart", stack)
    assert entry["agent_name"] == "Plan"
    assert entry["agent_id"] == "sub-1"
    assert stack.active() == ["Plan"]


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

    events = _session_records(tel_dir)
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

    events = _session_records(tel_dir)
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

    events = _session_records(tel_dir)
    assert events[0]["event"] == "PreCompact"
    # PreCompact captures a summary before process logs rotate.
    assert any(e["event"] == "SessionSummary" for e in events)


def test_given_tool_pair_when_mode_collect_then_carries_tool_use_id(tmp_path, monkeypatch):
    """The id survives to disk on both halves so offline analysis can pair them.

    The bundled report correlates by tool name, which cannot separate two
    concurrent calls to the same tool; the recorded id can.
    """
    tel_dir = tmp_path / "tel"
    monkeypatch.setenv("HVE_TELEMETRY_DIR", str(tel_dir))
    for payload in (
        {
            "hook_event_name": "PreToolUse",
            "session_id": "sid1",
            "tool_name": "read_file",
            "toolUseId": "call-42",
        },
        {
            "hook_event_name": "PostToolUse",
            "session_id": "sid1",
            "tool_name": "read_file",
            "tool_use_id": "call-42",
        },
    ):
        monkeypatch.setattr("sys.stdin", io.StringIO(json.dumps(payload)))
        assert core._mode_collect() == 0

    events = _session_records(tel_dir)
    pairs = [(e["event"], e.get("tool_use_id")) for e in events if e["event"].endswith("ToolUse")]
    assert pairs == [("PreToolUse", "call-42"), ("PostToolUse", "call-42")]


def test_given_traversal_sid_when_mode_collect_then_rejects(tmp_path, monkeypatch):
    tel_dir = tmp_path / "tel"
    monkeypatch.setenv("HVE_TELEMETRY_DIR", str(tel_dir))
    payload = {"hook_event_name": "SessionStart", "session_id": "../escape"}
    monkeypatch.setattr("sys.stdin", io.StringIO(json.dumps(payload)))
    assert core._mode_collect() == 0
    # No telemetry written for a rejected sid.
    assert not tel_dir.exists() or not _session_files(tel_dir)


@pytest.mark.parametrize(
    "sid",
    ["", "..", "../escape", "a/b", "a\\b", "C:", "C:x", "\\\\server\\share", "//server/share"],
)
def test_given_unsafe_sid_when_is_safe_sid_then_rejects(sid):
    """A drive or UNC anchor holds no separator yet still re-anchors a join."""
    assert not core._is_safe_sid(sid)


@pytest.mark.parametrize("sid", ["sid1", "abc-123", "a.b"])
def test_given_ordinary_sid_when_is_safe_sid_then_accepts(sid):
    assert core._is_safe_sid(sid)


def test_given_escaped_session_dir_when_clear_then_removes_nothing(tmp_path):
    """Containment is re-checked at the point of deletion, not only at parse."""
    stack_dir = tmp_path / ".stacks"
    outside = tmp_path / "outside"
    outside.mkdir()
    (outside / "keep.txt").write_text("user data", encoding="utf-8")
    stack = core._AgentStack(stack_dir, "sid1")
    stack.session_dir = outside
    stack.clear()
    assert (outside / "keep.txt").exists()


def test_given_unicode_line_when_append_line_then_writes_bytes_verbatim(tmp_path):
    target = tmp_path / "sessions.jsonl"
    core.append_line(target, "caf\u00e9 \u65e5\u672c\u8a9e\n")
    core.append_line(target, "\u00fcber\n")
    # No BOM, and no CRLF expansion from Windows text mode.
    assert target.read_bytes() == "caf\u00e9 \u65e5\u672c\u8a9e\n\u00fcber\n".encode()


def test_given_missing_parent_when_append_jsonl_then_creates_it(tmp_path):
    target = tmp_path / "nested" / "sessions.jsonl"
    core.append_jsonl(target, {"event": "PreToolUse"})
    assert json.loads(target.read_text(encoding="utf-8")) == {"event": "PreToolUse"}


def test_given_append_when_written_then_leaves_no_sidecar(tmp_path):
    """The lock lives on a byte of the log itself, so no lock file is needed."""
    target = tmp_path / "sessions.jsonl"
    core.append_jsonl(target, {"event": "Stop"})
    assert list(tmp_path.iterdir()) == [target]


def test_given_refused_lock_when_appending_then_falls_back_to_private_shard(tmp_path, monkeypatch):
    """A filesystem without working locks must not let writers interleave."""
    target = tmp_path / "sessions-2026-01-01.jsonl"
    core.append_jsonl(target, {"event": "first"})
    monkeypatch.setattr(core, "_lock_append", lambda fd: False)
    core.append_jsonl(target, {"event": "second"})

    files = sorted(tmp_path.glob("*.jsonl"))
    assert len(files) == 2
    # The shard is a sibling of its day log, so the report's session glob and the
    # cleanup allow-list both reach it without a separate rule.
    shard = next(p for p in files if p != target)
    assert shard.name.startswith("sessions-2026-01-01.")
    # The refused write went to that shard, leaving the shared log untouched.
    assert json.loads(target.read_text(encoding="utf-8")) == {"event": "first"}
    records = [json.loads(p.read_text(encoding="utf-8")) for p in files]
    assert {r["event"] for r in records} == {"first", "second"}


def test_given_raising_shared_append_when_appending_then_still_shards(tmp_path, monkeypatch):
    """The shard is reached when the shared write raises, not only when it returns False."""

    def boom(target, payload):
        raise OSError("no space left on device")

    monkeypatch.setattr(core, "_append_shared", boom)
    target = tmp_path / "sessions-2026-01-01.jsonl"
    core.append_jsonl(target, {"event": "rescued"})

    files = sorted(tmp_path.glob("*.jsonl"))
    assert len(files) == 1
    assert json.loads(files[0].read_text(encoding="utf-8")) == {"event": "rescued"}


def test_given_unwritable_store_when_appending_then_returns_quietly(tmp_path, monkeypatch):
    """A hook that raises stalls the turn, so the last resort is to drop the record."""

    def boom(*args, **kwargs):
        raise OSError("permission denied")

    monkeypatch.setattr(core, "_append_shared", boom)
    monkeypatch.setattr(core, "_append_private", boom)
    core.append_jsonl(tmp_path / "sessions-2026-01-01.jsonl", {"event": "dropped"})
    assert list(tmp_path.glob("*.jsonl")) == []


def test_given_unwritable_store_when_mode_collect_then_still_succeeds(tmp_path, monkeypatch):
    """The engine reports success so the wrapper's continue contract holds."""
    tel_dir = tmp_path / "tel"
    monkeypatch.setenv("HVE_TELEMETRY_DIR", str(tel_dir))
    monkeypatch.setattr(
        core.Path, "mkdir", lambda *a, **k: (_ for _ in ()).throw(OSError("read-only fs"))
    )
    payload = {"hook_event_name": "PreToolUse", "session_id": "sid1", "tool_name": "read"}
    monkeypatch.setattr("sys.stdin", io.StringIO(json.dumps(payload)))
    assert core._mode_collect() == 0


def test_given_short_write_when_append_line_then_finishes_the_record(tmp_path, monkeypatch):
    """A signal or a full disk can cut os.write short and truncate a record."""
    real_write = os.write
    calls = []

    def stingy(fd, data):
        calls.append(bytes(data))
        # Drip one byte at a time so a single unchecked write would truncate.
        return real_write(fd, bytes(data)[:1])

    monkeypatch.setattr(os, "write", stingy)
    target = tmp_path / "sessions.jsonl"
    core.append_jsonl(target, {"event": "Stop"})
    assert len(calls) > 1
    assert json.loads(target.read_text(encoding="utf-8")) == {"event": "Stop"}


def test_given_repeated_calls_when_fallback_stem_then_never_repeats():
    """Two live collectors sharing a stem would share a file and race on it."""
    stems = {core._fallback_stem() for _ in range(200)}
    assert len(stems) == 200


def _run_collectors(payloads, tel_dir, home):
    """Run one collector per payload; return their exit codes for the caller."""
    env = {
        **os.environ,
        "HVE_TELEMETRY_DIR": str(tel_dir),
        "HVE_HOME": str(home),
        "COPILOT_HOME": str(home),
    }
    procs = [
        subprocess.Popen(
            [sys.executable, core.__file__, "collect"],
            stdin=subprocess.PIPE,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            env=env,
        )
        for _ in payloads
    ]
    try:
        for proc, data in zip(procs, payloads):
            proc.stdin.write(json.dumps(data).encode("utf-8"))
        # Close in a tight loop so the collectors contend on the same write.
        for proc in procs:
            proc.stdin.close()
        return [proc.wait(timeout=60) for proc in procs]
    finally:
        for proc in procs:
            if proc.poll() is None:
                proc.kill()


@pytest.mark.slow
def test_given_concurrent_collectors_when_appending_then_every_event_lands(tmp_path):
    """End-to-end check that N collector processes each record their event.

    They share one log per day, so this is the regression guard for the
    overwrite the Windows CRT allows: it emulates append as seek-to-end plus
    write, letting two writers resolve the same offset.
    """
    tel_dir = tmp_path / "tel"
    count = 16
    payloads = [
        {
            "hook_event_name": "PreToolUse",
            "session_id": "race",
            "cwd": str(tmp_path),
            "tool_name": f"tool_{i}",
            # Vary the record length so a lost race tears a line rather than
            # cleanly replacing an equally sized record.
            "tool_input": {"pad": "x" * (100 + i * 37)},
        }
        for i in range(count)
    ]
    assert _run_collectors(payloads, tel_dir, tmp_path / "home") == [0] * len(payloads)

    records = _session_records(tel_dir)
    assert len(records) == count
    assert {r["tool"] for r in records} == {f"tool_{i}" for i in range(count)}
    if os.name != "nt":
        # POSIX resolves O_APPEND in the kernel, so the lock is never refused and
        # a shard here would be a real regression. Windows can legitimately shard
        # under contention, and readers pick it up either way.
        assert len(_session_files(tel_dir)) == 1


@pytest.mark.slow
def test_given_collectors_on_one_day_when_appending_then_shares_one_day_log(tmp_path):
    """Records are partitioned by UTC day so cleanup and reports stay day-scoped."""
    tel_dir = tmp_path / "tel"
    payloads = [
        {
            "hook_event_name": "PreToolUse",
            "session_id": "day",
            "cwd": str(tmp_path),
            "tool_name": f"tool_{i}",
        }
        for i in range(3)
    ]
    assert _run_collectors(payloads, tel_dir, tmp_path / "home") == [0] * len(payloads)

    files = _session_files(tel_dir)
    assert files
    assert all(re.fullmatch(r"sessions-\d{4}-\d{2}-\d{2}(\..+)?\.jsonl", p.name) for p in files)
    assert len(_session_records(tel_dir)) == 3


@pytest.mark.slow
def test_given_concurrent_subagent_starts_when_pushing_then_keeps_every_push(tmp_path):
    """Parallel subagents each record a start from their own collector process.

    The push is an append rather than a read-modify-write, so a simultaneous
    batch cannot lose all but one entry and misattribute later tool calls.
    Every racing collector also registers, because each sees ``first_write``.
    """
    tel_dir = tmp_path / "tel"
    home = tmp_path / "home"
    count = 16
    payloads = [
        {
            "hook_event_name": "SubagentStart",
            "session_id": "race",
            "cwd": str(tmp_path),
            "agent_type": f"Agent{i}",
        }
        for i in range(count)
    ]
    assert _run_collectors(payloads, tel_dir, home) == [0] * len(payloads)

    stack = core._AgentStack(tel_dir / ".stacks", "race")
    assert sorted(stack.active()) == sorted(f"Agent{i}" for i in range(count))

    # Registering is a racing whole-file write; it must converge on one entry.
    assert core.read_registry_dirs(home / "telemetry-dirs") == [str(tel_dir.resolve())]


def test_given_existing_file_when_write_text_atomic_then_replaces_without_residue(tmp_path):
    target = tmp_path / "launcher.ps1"
    target.write_text("old content")
    core._write_text_atomic(target, "new content")
    assert target.read_text() == "new content"
    assert list(tmp_path.iterdir()) == [target]


def test_given_session_log_when_clean_telemetry_dir_then_removes_it(tmp_path):
    tel_dir = tmp_path / "tel"
    tel_dir.mkdir()
    log = tel_dir / "sessions-2026-01-01.jsonl"
    log.write_text("{}\n", encoding="utf-8")
    removed = []
    core.clean_telemetry_dir(tel_dir, dry_run=False, removed=removed)
    assert not log.exists()
    assert removed == [str(log)]


def test_given_fallback_shard_when_clean_telemetry_dir_then_removes_it(tmp_path):
    """A shard sits beside its day log, so the allow-list must reach both."""
    tel_dir = tmp_path / "tel"
    tel_dir.mkdir()
    shard = tel_dir / "sessions-2026-01-01.010203000000-42-abcdef.jsonl"
    core.append_jsonl(shard, {"event": "Stop"})
    removed = []
    core.clean_telemetry_dir(tel_dir, dry_run=False, removed=removed)
    assert not shard.exists()
    assert removed == [str(shard)]


def test_given_unrelated_jsonl_when_clean_telemetry_dir_then_preserves_it(tmp_path):
    """A user can point HVE_TELEMETRY_DIR at a directory holding other work."""
    tel_dir = tmp_path / "tel"
    tel_dir.mkdir()
    keep_file = tel_dir / "sessions-notes.jsonl"
    keep_file.write_text("{}\n", encoding="utf-8")
    keep_dir = tel_dir / "notes"
    keep_dir.mkdir()
    (keep_dir / "a.jsonl").write_text("{}\n", encoding="utf-8")
    removed = []
    core.clean_telemetry_dir(tel_dir, dry_run=False, removed=removed)
    assert keep_file.exists()
    assert keep_dir.exists()
    assert removed == []


def test_given_legacy_registry_file_when_read_registry_dirs_then_imports_once(tmp_path):
    """An upgraded install must not silently lose its registered stores."""
    registry = tmp_path / "telemetry-dirs"
    legacy = tmp_path / "telemetry-dirs.txt"
    first = tmp_path / "a" / "tel"
    second = tmp_path / "b" / "tel"
    first.mkdir(parents=True)
    second.mkdir(parents=True)
    legacy.write_text(f"{first.resolve()}\n\n{second.resolve()}\n", encoding="utf-8")

    assert core.read_registry_dirs(registry) == sorted(
        [str(first.resolve()), str(second.resolve())]
    )
    # The legacy file is retired rather than deleted, and is not re-read.
    assert not legacy.exists()
    assert (tmp_path / "telemetry-dirs.txt.migrated").is_file()
    assert core.read_registry_dirs(registry) == sorted(
        [str(first.resolve()), str(second.resolve())]
    )


def test_given_new_dir_when_register_telemetry_dir_then_records_absolute_path(tmp_path):
    registry = tmp_path / "telemetry-dirs"
    tel_dir = tmp_path / "proj" / "tel"
    tel_dir.mkdir(parents=True)
    core.register_telemetry_dir(tel_dir, registry)
    assert core.read_registry_dirs(registry) == [str(tel_dir.resolve())]


def test_given_existing_entry_when_register_telemetry_dir_then_dedups(tmp_path):
    registry = tmp_path / "telemetry-dirs"
    tel_dir = tmp_path / "tel"
    tel_dir.mkdir()
    core.register_telemetry_dir(tel_dir, registry)
    core.register_telemetry_dir(tel_dir, registry)
    assert core.read_registry_dirs(registry) == [str(tel_dir.resolve())]


def test_given_several_stores_when_registered_then_each_gets_its_own_marker(tmp_path):
    registry = tmp_path / "telemetry-dirs"
    first = tmp_path / "a"
    second = tmp_path / "b"
    first.mkdir()
    second.mkdir()
    core.register_telemetry_dir(first, registry)
    core.register_telemetry_dir(second, registry)
    core.register_telemetry_dir(first, registry)
    assert core.read_registry_dirs(registry) == sorted(
        [str(first.resolve()), str(second.resolve())]
    )
    assert len(list(registry.glob("*.path"))) == 2


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
    assert core.read_registry_dirs(hve / "telemetry-dirs") == [str(tel_dir.resolve())]
    # A cross-project launcher for the host platform is emitted in the HVE home.
    if core._is_windows():
        assert (hve / "generate-report.ps1").is_file()
        assert (hve / "clean-telemetry.ps1").is_file()
    else:
        assert (hve / "generate-report.sh").is_file()
        assert (hve / "clean-telemetry.sh").is_file()


def test_given_no_session_start_when_mode_collect_then_still_registers_dir(tmp_path, monkeypatch):
    tel_dir = tmp_path / "tel"
    hve = tmp_path / "hve"
    monkeypatch.setenv("HVE_TELEMETRY_DIR", str(tel_dir))
    monkeypatch.setenv("COPILOT_HOME", str(tmp_path / "home"))
    monkeypatch.setenv("HVE_HOME", str(hve))
    payload = {"hook_event_name": "UserPromptSubmit", "session_id": "sid1", "prompt": "hi"}
    monkeypatch.setattr("sys.stdin", io.StringIO(json.dumps(payload)))
    assert core._mode_collect() == 0
    assert core.read_registry_dirs(hve / "telemetry-dirs") == [str(tel_dir.resolve())]


def test_given_stale_entries_when_mode_list_dirs_then_prunes_and_prints(
    tmp_path, monkeypatch, capsys
):
    hve = tmp_path / "hve"
    hve.mkdir()
    live = tmp_path / "live"
    live.mkdir()
    dead = tmp_path / "dead"
    registry = hve / "telemetry-dirs"
    core.register_telemetry_dir(live, registry)
    core.register_telemetry_dir(dead, registry)
    monkeypatch.setenv("HVE_HOME", str(hve))
    assert core._mode_list_dirs() == 0
    out = capsys.readouterr().out.splitlines()
    assert out == [str(live.resolve())]
    # Dead entry is pruned from the registry on read.
    assert core.read_registry_dirs(registry) == [str(live.resolve())]


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
    core.append_jsonl(tel_dir / "sessions-2026-01-01.jsonl", {})
    core.append_jsonl(tel_dir / "sessions-2026-01-02.jsonl", {})
    (tel_dir / "raw-input.jsonl").write_text("{}\n", encoding="utf-8")
    (tel_dir / "report.generated.html").write_text("<html>", encoding="utf-8")
    stacks = tel_dir / ".stacks" / "sid1"
    stacks.mkdir(parents=True)
    (stacks / "010203000000-42-aaaaaa.log").write_text(
        '{"op": "push", "agent": "A"}\n', encoding="utf-8"
    )
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
    assert (tel_dir / "sessions-2026-01-01.jsonl").exists()
    assert len(removed) == 5


def test_given_current_store_when_mode_clean_then_cleans_only_current(tmp_path, monkeypatch):
    current = tmp_path / "current"
    other = tmp_path / "other"
    hve = tmp_path / "hve"
    _seed_telemetry_store(current)
    _seed_telemetry_store(other)
    hve.mkdir()
    registry = hve / "telemetry-dirs"
    core.register_telemetry_dir(other, registry)
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
    registry = hve / "telemetry-dirs"
    core.register_telemetry_dir(other, registry)
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


class _ByteStdin:
    """Stdin stand-in exposing a raw byte buffer, as the real stream does.

    Feeding bytes rather than str exercises the decode boundary where a host
    locale would otherwise corrupt or reject the payload.
    """

    def __init__(self, data: bytes) -> None:
        self.buffer = io.BytesIO(data)


def _collect_one(payload_bytes, tel_dir, monkeypatch):
    """Run a single collect pass over raw stdin bytes and return the entries."""
    monkeypatch.setenv("HVE_TELEMETRY_DIR", str(tel_dir))
    monkeypatch.setattr("sys.stdin", _ByteStdin(payload_bytes))
    assert core._mode_collect() == 0
    return _session_records(tel_dir)


def test_given_non_ascii_utf8_stdin_bytes_when_mode_collect_then_preserves_text(
    tmp_path, monkeypatch
):
    payload = {
        "hook_event_name": "UserPromptSubmit",
        "session_id": "sid1",
        "timestamp": "2026-01-02T00:00:00Z",
        "cwd": "/home/M\u00fcller/\u30d7\u30ed\u30b8\u30a7\u30af\u30c8",
        "prompt": "caf\u00e9 \u65e5\u672c\u8a9e",
    }
    events = _collect_one(
        # ensure_ascii=False emits real multi-byte UTF-8 rather than \u escapes,
        # which is what actually crosses the decode boundary at runtime.
        json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        tmp_path / "tel",
        monkeypatch,
    )
    # cwd is a grouping key for cross-project reporting, so it must round-trip
    # byte-for-byte rather than degrade to replacement characters.
    assert events[0]["cwd"] == "/home/M\u00fcller/\u30d7\u30ed\u30b8\u30a7\u30af\u30c8"
    assert events[0]["prompt"] == "caf\u00e9 \u65e5\u672c\u8a9e"


def test_given_invalid_utf8_stdin_bytes_when_mode_collect_then_still_records_event(
    tmp_path, monkeypatch
):
    # A lone 0xE9 is valid cp1252 but invalid UTF-8. UnicodeDecodeError
    # subclasses ValueError, so an unguarded decode would drop the event as
    # though the JSON were malformed.
    raw = b'{"hook_event_name": "UserPromptSubmit", "session_id": "sid1", "prompt": "caf\xe9"}'
    events = _collect_one(raw, tmp_path / "tel", monkeypatch)
    assert events[0]["event"] == "UserPromptSubmit"
    assert events[0]["prompt"] == "caf\ufffd"


def test_given_stdin_without_buffer_when_read_stdin_text_then_falls_back_to_read(monkeypatch):
    monkeypatch.setattr("sys.stdin", io.StringIO("plain text"))
    assert core._read_stdin_text() == "plain text"
