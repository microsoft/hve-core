"""Command-level tests for gitlab.py."""

from __future__ import annotations

from collections.abc import Callable

import gitlab
import pytest
from conftest import RequestRecorder, StdinFactory
from test_constants import (
    FIELDS_JOB,
    FIELDS_MR,
    FIELDS_PIPELINE,
    TEST_API_URL,
    TEST_PROJECT_ENCODED,
    USAGE_MR_COMMENT,
    USAGE_MR_CREATE,
    USAGE_MR_GET,
    USAGE_MR_NOTES,
    USAGE_MR_UPDATE,
    USAGE_PIPELINE_GET,
    USAGE_PIPELINE_JOBS,
    USAGE_PIPELINE_RUN,
)

CommandFn = Callable[[list[str]], None]

MR_LIST_DEFAULT_URL = (
    f"{TEST_API_URL}/projects/{TEST_PROJECT_ENCODED}/merge_requests?state=all&"
    "per_page=20&order_by=created_at&sort=desc"
)
MR_GET_URL = f"{TEST_API_URL}/projects/{TEST_PROJECT_ENCODED}/merge_requests/42"
MR_CREATE_URL = f"{TEST_API_URL}/projects/{TEST_PROJECT_ENCODED}/merge_requests"
MR_UPDATE_URL = f"{TEST_API_URL}/projects/{TEST_PROJECT_ENCODED}/merge_requests/9"
MR_COMMENT_URL = (
    f"{TEST_API_URL}/projects/{TEST_PROJECT_ENCODED}/merge_requests/5/notes"
)
MR_NOTES_URL = (
    f"{TEST_API_URL}/projects/{TEST_PROJECT_ENCODED}/merge_requests/5/notes?"
    "per_page=100&sort=asc"
)
PIPELINE_GET_URL = f"{TEST_API_URL}/projects/{TEST_PROJECT_ENCODED}/pipelines/10"
PIPELINE_RUN_URL = f"{TEST_API_URL}/projects/{TEST_PROJECT_ENCODED}/pipelines"
PIPELINE_JOBS_URL = f"{TEST_API_URL}/projects/{TEST_PROJECT_ENCODED}/pipelines/10/jobs"

MR_LIST_RESPONSE = [{"iid": 1, "title": "MR"}]
MR_GET_RESPONSE = {"iid": 42, "title": "MR"}
PIPELINE_RESPONSE = {"id": 10, "status": "success"}
PIPELINE_JOBS_RESPONSE = [{"id": 1, "name": "build"}]
FILTERED_NOTES = [
    {"body": "human", "system": False},
    {"body": "default-human"},
]


def _configure_command_test(
    monkeypatch: pytest.MonkeyPatch,
    request_recorder: RequestRecorder,
    response: object | None = None,
) -> RequestRecorder:
    gitlab.api_url = TEST_API_URL
    request_recorder.response = response
    monkeypatch.setattr(gitlab, "project", lambda: TEST_PROJECT_ENCODED)
    monkeypatch.setattr(gitlab, "request", request_recorder)
    return request_recorder


def _capture_print_fields(monkeypatch: pytest.MonkeyPatch) -> list[object]:
    printed: list[object] = []
    monkeypatch.setattr(gitlab, "print_fields", printed.append)
    return printed


def _assert_usage_error(
    command: CommandFn,
    args: list[str],
    expected_message: str,
    capsys: pytest.CaptureFixture[str],
) -> None:
    with pytest.raises(SystemExit) as exc_info:
        command(args)

    assert exc_info.value.code == gitlab.EXIT_USAGE
    assert expected_message in capsys.readouterr().err


@pytest.mark.parametrize(
    ("command", "args", "expected_message"),
    [
        (gitlab.cmd_mr_get, [], USAGE_MR_GET),
        (gitlab.cmd_mr_update, [], "usage: gitlab mr-update <mr-iid> <json>"),
        (gitlab.cmd_mr_comment, [], "usage: gitlab mr-comment <mr-iid> <body>"),
        (gitlab.cmd_mr_notes, [], USAGE_MR_NOTES),
        (gitlab.cmd_pipeline_get, [], USAGE_PIPELINE_GET),
        (gitlab.cmd_pipeline_run, [], USAGE_PIPELINE_RUN),
        (gitlab.cmd_pipeline_jobs, [], USAGE_PIPELINE_JOBS),
    ],
)
def test_commands_require_minimum_arguments(
    command: CommandFn,
    args: list[str],
    expected_message: str,
    capsys: pytest.CaptureFixture[str],
) -> None:
    _assert_usage_error(command, args, expected_message, capsys)


@pytest.mark.parametrize(
    ("command", "args", "expected_url"),
    [
        (gitlab.cmd_mr_get, ["42"], MR_GET_URL),
        (gitlab.cmd_pipeline_get, ["10"], PIPELINE_GET_URL),
        (gitlab.cmd_pipeline_jobs, ["10"], PIPELINE_JOBS_URL),
    ],
)
def test_get_commands_build_expected_urls(
    monkeypatch: pytest.MonkeyPatch,
    request_recorder: RequestRecorder,
    command: CommandFn,
    args: list[str],
    expected_url: str,
) -> None:
    recorder = _configure_command_test(
        monkeypatch, request_recorder, response={})

    command(args)

    assert recorder.calls[0].method == "GET"
    assert recorder.calls[0].url == expected_url
    assert recorder.calls[0].quiet is False


def test_mr_list_uses_default_state_and_page_size(
    monkeypatch: pytest.MonkeyPatch,
    request_recorder: RequestRecorder,
) -> None:
    recorder = _configure_command_test(
        monkeypatch, request_recorder, response=[])

    gitlab.cmd_mr_list([])

    assert recorder.calls[0].method == "GET"
    assert recorder.calls[0].url == MR_LIST_DEFAULT_URL
    assert recorder.calls[0].quiet is False


@pytest.mark.parametrize(
    ("command", "args", "selected_fields", "response", "expected_printed"),
    [
        (
            gitlab.cmd_mr_list,
            ["opened", "5"],
            FIELDS_MR,
            MR_LIST_RESPONSE,
            MR_LIST_RESPONSE,
        ),
        (gitlab.cmd_mr_get, ["42"], FIELDS_MR,
         MR_GET_RESPONSE, MR_GET_RESPONSE),
        (
            gitlab.cmd_pipeline_get,
            ["10"],
            FIELDS_PIPELINE,
            PIPELINE_RESPONSE,
            PIPELINE_RESPONSE,
        ),
        (
            gitlab.cmd_pipeline_jobs,
            ["10"],
            FIELDS_JOB,
            PIPELINE_JOBS_RESPONSE,
            PIPELINE_JOBS_RESPONSE,
        ),
    ],
)
def test_read_commands_print_selected_fields(
    monkeypatch: pytest.MonkeyPatch,
    request_recorder: RequestRecorder,
    command: CommandFn,
    args: list[str],
    selected_fields: list[str],
    response: object,
    expected_printed: object,
) -> None:
    gitlab.selected_fields = selected_fields
    recorder = _configure_command_test(
        monkeypatch, request_recorder, response=response)
    printed = _capture_print_fields(monkeypatch)

    command(args)

    assert recorder.calls[0].quiet is True
    assert printed == [expected_printed]


@pytest.mark.parametrize(
    ("command", "args", "expected_url", "expected_data"),
    [
        (
            gitlab.cmd_mr_create,
            ['{"title": "New MR"}'],
            MR_CREATE_URL,
            {"title": "New MR"},
        ),
        (
            gitlab.cmd_mr_update,
            ["9", '{"title": "Updated"}'],
            MR_UPDATE_URL,
            {"title": "Updated"},
        ),
        (
            gitlab.cmd_mr_comment,
            ["5", "Looks good"],
            MR_COMMENT_URL,
            {"body": "Looks good"},
        ),
        (gitlab.cmd_pipeline_run, ["main"], PIPELINE_RUN_URL, {"ref": "main"}),
    ],
)
def test_write_commands_forward_inline_payloads(
    monkeypatch: pytest.MonkeyPatch,
    request_recorder: RequestRecorder,
    command: CommandFn,
    args: list[str],
    expected_url: str,
    expected_data: object,
) -> None:
    recorder = _configure_command_test(monkeypatch, request_recorder)

    command(args)

    assert recorder.calls[0].url == expected_url
    assert recorder.calls[0].data == expected_data


@pytest.mark.parametrize(
    ("command", "args", "stdin_text", "expected_url", "expected_data"),
    [
        (
            gitlab.cmd_mr_create,
            [],
            '{"title": "stdin MR"}',
            MR_CREATE_URL,
            {"title": "stdin MR"},
        ),
        (
            gitlab.cmd_mr_update,
            ["9"],
            '{"description": "from stdin"}',
            MR_UPDATE_URL,
            {"description": "from stdin"},
        ),
        (
            gitlab.cmd_mr_comment,
            ["5"],
            "Ready for review",
            MR_COMMENT_URL,
            {"body": "Ready for review"},
        ),
    ],
)
def test_write_commands_read_payloads_from_stdin(
    monkeypatch: pytest.MonkeyPatch,
    request_recorder: RequestRecorder,
    stdin_factory: StdinFactory,
    command: CommandFn,
    args: list[str],
    stdin_text: str,
    expected_url: str,
    expected_data: object,
) -> None:
    recorder = _configure_command_test(monkeypatch, request_recorder)
    stdin_factory(stdin_text)

    command(args)

    assert recorder.calls[0].url == expected_url
    assert recorder.calls[0].data == expected_data


@pytest.mark.parametrize(
    ("command", "args", "usage_message"),
    [
        (gitlab.cmd_mr_create, [], USAGE_MR_CREATE),
        (gitlab.cmd_mr_update, ["9"], USAGE_MR_UPDATE),
        (gitlab.cmd_mr_comment, ["5"], USAGE_MR_COMMENT),
    ],
)
def test_write_commands_require_stdin_or_inline_content(
    stdin_factory: StdinFactory,
    command: CommandFn,
    args: list[str],
    usage_message: str,
    capsys: pytest.CaptureFixture[str],
) -> None:
    stdin_factory("")

    _assert_usage_error(command, args, usage_message, capsys)


def test_mr_notes_uses_default_max_results(
    monkeypatch: pytest.MonkeyPatch,
    request_recorder: RequestRecorder,
) -> None:
    recorder = _configure_command_test(
        monkeypatch, request_recorder, response=[])

    gitlab.cmd_mr_notes(["5"])

    assert recorder.calls[0].url == MR_NOTES_URL


def test_mr_notes_filters_system_notes_before_printing(
    monkeypatch: pytest.MonkeyPatch,
    request_recorder: RequestRecorder,
) -> None:
    gitlab.selected_fields = ["body"]
    recorder = _configure_command_test(
        monkeypatch,
        request_recorder,
        response=[
            {"body": "human", "system": False},
            {"body": "system", "system": True},
            {"body": "default-human"},
        ],
    )
    printed = _capture_print_fields(monkeypatch)

    gitlab.cmd_mr_notes(["5", "2"])

    assert recorder.calls[0].quiet is True
    assert printed == [FILTERED_NOTES]
