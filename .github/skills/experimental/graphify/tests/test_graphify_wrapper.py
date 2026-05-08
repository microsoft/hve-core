# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Tests for the graphify subprocess wrapper."""

from __future__ import annotations

from pathlib import Path

import pytest
from graphify_wrapper import (
    GraphifyNotInstalledError,
    build_graph,
    graphify_executable,
)

GRAPHIFY_BIN = "/usr/local/bin/graphify"


def test_graphify_executable_raises_when_missing(monkeypatch):
    monkeypatch.setattr("graphify_wrapper.shutil.which", lambda _: None)
    with pytest.raises(GraphifyNotInstalledError):
        graphify_executable()


def test_build_graph_rejects_unknown_mode(monkeypatch):
    monkeypatch.setattr("graphify_wrapper.shutil.which", lambda _: GRAPHIFY_BIN)
    with pytest.raises(ValueError):
        build_graph(Path("."), mode="ultra")


def test_build_graph_invokes_subprocess(monkeypatch):
    monkeypatch.setattr("graphify_wrapper.shutil.which", lambda _: GRAPHIFY_BIN)
    captured: dict[str, list[str]] = {}

    class FakeCompleted:
        returncode = 0

    def fake_run(cmd, check):
        captured["cmd"] = cmd
        return FakeCompleted()

    monkeypatch.setattr("graphify_wrapper.subprocess.run", fake_run)
    rc = build_graph(Path("/tmp/repo"), mode="fast", update=False)
    assert rc == 0
    assert captured["cmd"] == ["/usr/local/bin/graphify", "/tmp/repo", "--mode", "fast"]
