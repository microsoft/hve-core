# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Polyglot fuzz harness for telemetry core logic.

Runs as a pytest test when Atheris is not installed.
Runs as an Atheris coverage-guided fuzz target when executed directly.
"""

from __future__ import annotations

import sys
from contextlib import suppress
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import _telemetry_core as core  # noqa: E402

try:
    import atheris
except ImportError:
    atheris = None
    FUZZING = False
else:
    FUZZING = True


def fuzz_iter_jsonl(data: bytes) -> None:
    """Fuzz JSONL parsing with arbitrary bytes."""
    provider = atheris.FuzzedDataProvider(data)
    import tempfile
    from pathlib import Path

    content = provider.ConsumeUnicodeNoSurrogates(500)
    with tempfile.NamedTemporaryFile(mode="w", suffix=".jsonl", delete=False) as f:
        f.write(content)
        f.flush()
        list(core.iter_jsonl(f.name))
    Path(f.name).unlink(missing_ok=True)


def fuzz_normalize_event(data: bytes) -> None:
    """Fuzz event normalization with arbitrary payloads."""
    provider = atheris.FuzzedDataProvider(data)
    payload = {}
    for key in ("hook_event_name", "hookEventName", "event"):
        if provider.ConsumeBool():
            payload[key] = provider.ConsumeUnicodeNoSurrogates(30)
    core._normalize_event(payload)


def fuzz_build_entry(data: bytes) -> None:
    """Fuzz entry building with arbitrary payloads."""
    provider = atheris.FuzzedDataProvider(data)
    events = [
        "SessionStart",
        "UserPromptSubmit",
        "PreToolUse",
        "PostToolUse",
        "SubagentStart",
        "SubagentStop",
        "PreCompact",
        "Stop",
        "unknown",
    ]
    event = events[provider.ConsumeIntInRange(0, len(events) - 1)]
    payload = {
        "session_id": provider.ConsumeUnicodeNoSurrogates(20),
        "timestamp": provider.ConsumeUnicodeNoSurrogates(30),
        "tool_name": provider.ConsumeUnicodeNoSurrogates(15),
        "prompt": provider.ConsumeUnicodeNoSurrogates(50),
    }
    import tempfile
    from pathlib import Path

    stack_dir = Path(tempfile.mkdtemp())
    stack = core._AgentStack(stack_dir, payload["session_id"])
    with suppress(Exception):
        core.build_entry(payload, event, stack)
    # Cleanup
    for f in stack_dir.iterdir():
        f.unlink(missing_ok=True)
    stack_dir.rmdir()


FUZZ_TARGETS = [
    fuzz_iter_jsonl,
    fuzz_normalize_event,
    fuzz_build_entry,
]


def fuzz_dispatch(data: bytes) -> None:
    """Route input to one fuzz target."""
    if len(data) < 2:
        return
    target_index = data[0] % len(FUZZ_TARGETS)
    FUZZ_TARGETS[target_index](data[1:])


class TestTelemetryFuzzHarness:
    """Property tests mirroring fuzz-target behavior."""

    def test_given_aliased_events_when_normalize_event_then_resolves(self) -> None:
        assert core._normalize_event({"hook_event_name": "sessionStart"}) == "SessionStart"
        assert core._normalize_event({"hook_event_name": "agentStop"}) == "Stop"

    def test_given_unknown_event_when_normalize_event_then_passes_through(self) -> None:
        assert core._normalize_event({"hook_event_name": "CustomEvent"}) == "CustomEvent"

    def test_given_fallback_keys_when_normalize_event_then_resolves(self) -> None:
        assert core._normalize_event({"hookEventName": "preToolUse"}) == "PreToolUse"
        assert core._normalize_event({"event": "postToolUse"}) == "PostToolUse"

    def test_given_unknown_event_when_build_entry_then_returns_none(self, tmp_path) -> None:
        stack = core._AgentStack(tmp_path / ".stacks", "sid")
        assert core.build_entry({}, "unknown", stack) is None

    def test_given_session_start_when_build_entry_then_populates_fields(self, tmp_path) -> None:
        stack = core._AgentStack(tmp_path / ".stacks", "sid")
        entry = core.build_entry(
            {"hook_event_name": "SessionStart", "source": "cli", "timestamp": "t"},
            "SessionStart",
            stack,
        )
        assert entry["event"] == "SessionStart"
        assert entry["source"] == "cli"

    def test_given_non_dict_lines_when_iter_jsonl_then_skips_them(self, tmp_path) -> None:
        f = tmp_path / "test.jsonl"
        f.write_text('[1, 2]\n"string"\n{"valid": true}\n')
        rows = list(core.iter_jsonl(f))
        assert rows == [{"valid": True}]


if __name__ == "__main__" and FUZZING:
    atheris.instrument_all()
    atheris.Setup(sys.argv, fuzz_dispatch)
    atheris.Fuzz()
