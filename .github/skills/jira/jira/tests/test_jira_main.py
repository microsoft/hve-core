# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Entry-point and parser tests for jira.py."""

from __future__ import annotations

import argparse
from dataclasses import dataclass, field

import pytest
from test_constants import FIELDS_ISSUE, TEST_ISSUE_KEY, TEST_JQL

import jira


@dataclass
class PrintRecorder:
    """Capture _print_result calls for assertions."""

    calls: list[tuple[object, object]] = field(default_factory=list)

    def __call__(self, result: object, fields: object) -> None:
        self.calls.append((result, fields))


def test_create_parser_parses_search_arguments() -> None:
    parser = jira.create_parser()

    args = parser.parse_args(
        ["--fields", "key,fields.summary", "search", TEST_JQL, "10"]
    )

    assert args.command == "search"
    assert args.jql == TEST_JQL
    assert args.max_results == 10
    assert args.fields == "key,fields.summary"
    assert args.handler is jira.handle_search


def test_main_dispatches_and_splits_fields(monkeypatch: pytest.MonkeyPatch) -> None:
    seen: list[object] = []
    print_recorder = PrintRecorder()

    def fake_handler(client: object, args: argparse.Namespace) -> dict[str, str]:
        seen.append(client)
        seen.append(args.fields)
        return {"key": TEST_ISSUE_KEY}

    class FakeParser:
        def parse_args(self) -> argparse.Namespace:
            return argparse.Namespace(fields="key,fields.summary", handler=fake_handler)

    fake_client = object()

    def fake_from_environment() -> object:
        return fake_client

    monkeypatch.setattr(jira, "create_parser", FakeParser)
    monkeypatch.setattr(jira.JiraClient, "from_environment", fake_from_environment)
    monkeypatch.setattr(jira, "_print_result", print_recorder)

    result = jira.main()

    assert result == jira.EXIT_SUCCESS
    assert seen == [fake_client, FIELDS_ISSUE]
    assert print_recorder.calls == [({"key": TEST_ISSUE_KEY}, FIELDS_ISSUE)]


def test_main_returns_script_error_exit_code(
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    class FakeParser:
        def parse_args(self) -> argparse.Namespace:
            return argparse.Namespace(fields=None, handler=lambda *_args: None)

    def raise_script_error() -> object:
        raise jira.ScriptError("boom", jira.EXIT_USAGE)

    monkeypatch.setattr(jira, "create_parser", FakeParser)
    monkeypatch.setattr(jira.JiraClient, "from_environment", raise_script_error)

    result = jira.main()

    assert result == jira.EXIT_USAGE
    assert capsys.readouterr().err.strip() == "error: boom"


def test_main_handles_keyboard_interrupt(
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    class FakeParser:
        def parse_args(self) -> argparse.Namespace:
            raise KeyboardInterrupt

    monkeypatch.setattr(jira, "create_parser", FakeParser)

    result = jira.main()

    assert result == 130
    assert capsys.readouterr().err.strip() == "Interrupted by user"


def test_main_handles_broken_pipe(monkeypatch: pytest.MonkeyPatch) -> None:
    class FakeParser:
        def parse_args(self) -> argparse.Namespace:
            return argparse.Namespace(
                fields=None,
                handler=lambda *_args: {"key": TEST_ISSUE_KEY},
            )

    def fake_from_environment() -> object:
        return object()

    def raise_broken_pipe(_result: object, _fields: object) -> None:
        raise BrokenPipeError

    monkeypatch.setattr(jira, "create_parser", FakeParser)
    monkeypatch.setattr(jira.JiraClient, "from_environment", fake_from_environment)
    monkeypatch.setattr(jira, "_print_result", raise_broken_pipe)

    assert jira.main() == jira.EXIT_FAILURE
