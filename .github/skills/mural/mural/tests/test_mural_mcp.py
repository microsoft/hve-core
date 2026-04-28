# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""MCP stdio server tests for mural.py."""

from __future__ import annotations

import io
import json
from typing import Any

import pytest


def _drive(
    mural_module: Any,
    frames: list[dict[str, Any] | bytes],
) -> list[dict[str, Any]]:
    """Drive `_run_mcp_stdio` with a sequence of NDJSON frames or raw bytes."""
    buf = io.BytesIO()
    for frame in frames:
        if isinstance(frame, bytes):
            buf.write(frame)
            if not frame.endswith(b"\n"):
                buf.write(b"\n")
        else:
            buf.write(mural_module._frame_mcp_message(frame))
    buf.seek(0)
    out = io.BytesIO()
    err = io.BytesIO()
    rc = mural_module._run_mcp_stdio(stdin=buf, stdout=out, stderr=err)
    assert rc == mural_module.EXIT_SUCCESS
    out.seek(0)
    responses: list[dict[str, Any]] = []
    for line in out.read().splitlines():
        if not line:
            continue
        responses.append(json.loads(line.decode("utf-8")))
    return responses


def test_initialize_returns_preferred_protocol(mural_module: Any) -> None:
    responses = _drive(
        mural_module,
        [
            {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": {"protocolVersion": mural_module._MCP_PROTOCOL_PREFERRED},
            },
        ],
    )

    assert len(responses) == 1
    res = responses[0]["result"]
    assert res["protocolVersion"] == mural_module._MCP_PROTOCOL_PREFERRED
    assert res["serverInfo"] == mural_module._MCP_SERVER_INFO
    assert res["capabilities"] == mural_module._MCP_CAPABILITIES


def test_initialize_falls_back_when_unknown_protocol_omitted(mural_module: Any) -> None:
    responses = _drive(
        mural_module,
        [
            {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}},
        ],
    )

    expected_version = mural_module._MCP_PROTOCOL_FALLBACK
    assert responses[0]["result"]["protocolVersion"] == expected_version


def test_initialize_rejects_unsupported_protocol(mural_module: Any) -> None:
    responses = _drive(
        mural_module,
        [
            {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": {"protocolVersion": "1999-01-01"},
            },
        ],
    )

    err = responses[0]["error"]
    assert err["code"] == -32602
    assert err["data"] == {"path": "$.protocolVersion"}


def test_notifications_initialized_does_not_reply(mural_module: Any) -> None:
    responses = _drive(
        mural_module,
        [
            {"jsonrpc": "2.0", "method": "notifications/initialized"},
        ],
    )

    assert responses == []


def test_tools_list_returns_registered_tools(mural_module: Any) -> None:
    responses = _drive(
        mural_module,
        [
            {"jsonrpc": "2.0", "id": 2, "method": "tools/list"},
        ],
    )

    tools = responses[0]["result"]["tools"]
    names = {tool["name"] for tool in tools}
    assert "mural_workspace_list" in names
    assert "mural_widget_create_sticky_note" in names
    for tool in tools:
        assert tool["inputSchema"]["additionalProperties"] is False


def test_tools_call_happy_path(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    captured: dict[str, Any] = {}

    def fake_handler(arguments: dict[str, Any]) -> Any:
        captured["arguments"] = arguments
        return [{"id": "ws-1", "name": "Test"}]

    registry = dict(mural_module._TOOL_REGISTRY)
    spec = dict(registry["mural_workspace_list"])
    spec["handler"] = fake_handler
    registry["mural_workspace_list"] = spec
    monkeypatch.setattr(mural_module, "_TOOL_REGISTRY", registry)

    responses = _drive(
        mural_module,
        [
            {
                "jsonrpc": "2.0",
                "id": 3,
                "method": "tools/call",
                "params": {"name": "mural_workspace_list", "arguments": {}},
            },
        ],
    )

    result = responses[0]["result"]
    assert result["isError"] is False
    payload = json.loads(result["content"][0]["text"])
    assert payload == [{"id": "ws-1", "name": "Test"}]
    assert captured["arguments"] == {}


def test_tools_call_handler_error_returns_iserror(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    def boom(_arguments: dict[str, Any]) -> Any:
        raise mural_module.MuralAPIError(
            status=404,
            code="NOT_FOUND",
            message="missing",
            request_id="req-1",
        )

    registry = dict(mural_module._TOOL_REGISTRY)
    spec = dict(registry["mural_workspace_get"])
    spec["handler"] = boom
    registry["mural_workspace_get"] = spec
    monkeypatch.setattr(mural_module, "_TOOL_REGISTRY", registry)

    responses = _drive(
        mural_module,
        [
            {
                "jsonrpc": "2.0",
                "id": 4,
                "method": "tools/call",
                "params": {
                    "name": "mural_workspace_get",
                    "arguments": {"workspace": "ws-1"},
                },
            },
        ],
    )

    result = responses[0]["result"]
    assert result["isError"] is True
    payload = json.loads(result["content"][0]["text"])
    assert payload["error"] == "NOT_FOUND"
    assert payload["status"] == 404


def test_tools_call_invalid_params_returns_minus_32602(mural_module: Any) -> None:
    responses = _drive(
        mural_module,
        [
            {
                "jsonrpc": "2.0",
                "id": 5,
                "method": "tools/call",
                "params": {"name": "unknown_tool", "arguments": {}},
            },
        ],
    )

    err = responses[0]["error"]
    assert err["code"] == -32602
    assert err["data"] == {"path": "$.name"}


def test_unknown_method_returns_minus_32601(mural_module: Any) -> None:
    responses = _drive(
        mural_module,
        [
            {"jsonrpc": "2.0", "id": 6, "method": "nope/please"},
        ],
    )

    assert responses[0]["error"]["code"] == -32601


def test_malformed_json_returns_minus_32700_and_loop_continues(
    mural_module: Any,
) -> None:
    responses = _drive(
        mural_module,
        [
            b"not-json{",
            {"jsonrpc": "2.0", "id": 7, "method": "tools/list"},
        ],
    )

    assert responses[0]["error"]["code"] == -32700
    assert responses[0]["id"] is None
    assert "tools" in responses[1]["result"]


def test_handler_exception_returns_minus_32603(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    def explode(_arguments: dict[str, Any]) -> Any:
        raise RuntimeError("oops")

    registry = dict(mural_module._TOOL_REGISTRY)
    spec = dict(registry["mural_workspace_list"])
    spec["handler"] = explode
    registry["mural_workspace_list"] = spec
    monkeypatch.setattr(mural_module, "_TOOL_REGISTRY", registry)

    responses = _drive(
        mural_module,
        [
            {
                "jsonrpc": "2.0",
                "id": 8,
                "method": "tools/call",
                "params": {"name": "mural_workspace_list", "arguments": {}},
            },
        ],
    )

    err = responses[0]["error"]
    assert err["code"] == -32603
    assert err["message"] == "internal error"


def test_frame_round_trip(mural_module: Any) -> None:
    msg = {"jsonrpc": "2.0", "id": 1, "method": "ping"}
    framed = mural_module._frame_mcp_message(msg)
    assert framed.endswith(b"\n")
    parsed = mural_module._parse_mcp_frame(framed)
    assert parsed == msg


def test_parse_blank_line_returns_none(mural_module: Any) -> None:
    assert mural_module._parse_mcp_frame(b"\n") is None
    assert mural_module._parse_mcp_frame(b"   \n") is None
