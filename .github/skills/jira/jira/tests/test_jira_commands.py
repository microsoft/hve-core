# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Command-level tests for jira.py."""

from __future__ import annotations

import argparse
import urllib.parse

import jira
import pytest
from conftest import ClientRecorder, StdinFactory
from test_constants import (
    ERROR_ISSUE_TYPE_ID,
    ERROR_MAX_RESULTS,
    FIELDS_ISSUE,
    TEST_ISSUE_KEY,
    TEST_ISSUE_KEY_TWO,
    TEST_ISSUE_TYPE_ID,
    TEST_JQL,
    TEST_PROJECT_KEY,
    USAGE_COMMENT,
)


def test_handle_search_requires_positive_max_results(
    handler_client: jira.JiraClient,
) -> None:
    args = argparse.Namespace(jql=TEST_JQL, max_results=0, fields=None)

    with pytest.raises(jira.ScriptError) as exc_info:
        jira.handle_search(handler_client, args)

    assert exc_info.value.exit_code == jira.EXIT_USAGE
    assert str(exc_info.value) == ERROR_MAX_RESULTS


@pytest.mark.parametrize(
    ("use_legacy_search", "expected_path"),
    [
        (
            True,
            f"/search?jql={urllib.parse.quote(TEST_JQL, safe='')}&maxResults=25",
        ),
        (
            False,
            f"/search/jql?jql={urllib.parse.quote(TEST_JQL, safe='')}&"
            "maxResults=25&fields=*navigable",
        ),
    ],
)
def test_handle_search_builds_expected_path(
    client_recorder: ClientRecorder,
    handler_client: jira.JiraClient,
    use_legacy_search: bool,
    expected_path: str,
) -> None:
    client_recorder.use_legacy_search = use_legacy_search
    client_recorder.responses = [{"issues": [{"key": TEST_ISSUE_KEY}]}]
    args = argparse.Namespace(jql=TEST_JQL, max_results=25, fields=None)

    result = jira.handle_search(handler_client, args)

    assert result == {"issues": [{"key": TEST_ISSUE_KEY}]}
    assert client_recorder.calls[0].method == "GET"
    assert client_recorder.calls[0].path == expected_path


def test_handle_search_returns_issue_rows_when_fields_selected(
    client_recorder: ClientRecorder,
    handler_client: jira.JiraClient,
) -> None:
    client_recorder.responses = [{"issues": [{"key": TEST_ISSUE_KEY}]}]
    args = argparse.Namespace(jql=TEST_JQL, max_results=10, fields=FIELDS_ISSUE)

    assert jira.handle_search(handler_client, args) == [{"key": TEST_ISSUE_KEY}]


def test_handle_get_fetches_issue(
    client_recorder: ClientRecorder,
    handler_client: jira.JiraClient,
) -> None:
    client_recorder.responses = [{"key": TEST_ISSUE_KEY}]
    args = argparse.Namespace(issue_key=TEST_ISSUE_KEY)

    result = jira.handle_get(handler_client, args)

    assert result == {"key": TEST_ISSUE_KEY}
    assert client_recorder.calls[0].path == f"/issue/{TEST_ISSUE_KEY}"


@pytest.mark.parametrize(
    ("payload", "stdin_text", "expected_data"),
    [
        ('{"fields": {"summary": "New"}}', None, {"fields": {"summary": "New"}}),
        (None, '{"fields": {"summary": "stdin"}}', {"fields": {"summary": "stdin"}}),
    ],
)
def test_handle_create_forwards_exact_json_payloads(
    stdin_factory: StdinFactory,
    client_recorder: ClientRecorder,
    handler_client: jira.JiraClient,
    payload: str | None,
    stdin_text: str | None,
    expected_data: object,
) -> None:
    if stdin_text is not None:
        stdin_factory(stdin_text)
    args = argparse.Namespace(payload=payload)

    result = jira.handle_create(handler_client, args)

    assert result is None
    assert client_recorder.calls[0].path == "/issue"
    assert client_recorder.calls[0].data == expected_data


@pytest.mark.parametrize(
    ("payload", "stdin_text", "expected_data"),
    [
        (
            '{"fields": {"summary": "Updated"}}',
            None,
            {"fields": {"summary": "Updated"}},
        ),
        (
            None,
            '{"fields": {"summary": "stdin update"}}',
            {"fields": {"summary": "stdin update"}},
        ),
    ],
)
def test_handle_update_forwards_exact_json_payloads(
    stdin_factory: StdinFactory,
    client_recorder: ClientRecorder,
    handler_client: jira.JiraClient,
    payload: str | None,
    stdin_text: str | None,
    expected_data: object,
) -> None:
    if stdin_text is not None:
        stdin_factory(stdin_text)
    args = argparse.Namespace(issue_key=TEST_ISSUE_KEY, payload=payload)

    result = jira.handle_update(handler_client, args)

    assert result == {"key": TEST_ISSUE_KEY, "status": "updated"}
    assert client_recorder.calls[0].path == f"/issue/{TEST_ISSUE_KEY}"
    assert client_recorder.calls[0].data == expected_data


def test_handle_transition_accepts_numeric_transition_id(
    client_recorder: ClientRecorder,
    handler_client: jira.JiraClient,
) -> None:
    args = argparse.Namespace(issue_key=TEST_ISSUE_KEY, transition="31")

    result = jira.handle_transition(handler_client, args)

    assert result == {
        "key": TEST_ISSUE_KEY,
        "transitionId": "31",
        "status": "transitioned",
    }
    assert client_recorder.calls[0].path == f"/issue/{TEST_ISSUE_KEY}/transitions"
    assert client_recorder.calls[0].data == {"transition": {"id": "31"}}


def test_handle_transition_resolves_transition_name(
    client_recorder: ClientRecorder,
    handler_client: jira.JiraClient,
) -> None:
    client_recorder.responses = [
        {"transitions": [{"id": "21", "name": "In Progress"}]},
        None,
    ]
    args = argparse.Namespace(issue_key=TEST_ISSUE_KEY, transition="In Progress")

    result = jira.handle_transition(handler_client, args)

    assert result == {
        "key": TEST_ISSUE_KEY,
        "transitionId": "21",
        "status": "transitioned",
    }
    assert client_recorder.calls[0].path == f"/issue/{TEST_ISSUE_KEY}/transitions"
    assert client_recorder.calls[1].data == {"transition": {"id": "21"}}


def test_handle_transition_reports_available_names(
    handler_client: jira.JiraClient,
    client_recorder: ClientRecorder,
) -> None:
    client_recorder.responses = [
        {
            "transitions": [
                {"id": "21", "name": "Done"},
                {"id": "22", "name": "Review"},
            ]
        }
    ]
    args = argparse.Namespace(issue_key=TEST_ISSUE_KEY, transition="Missing")

    with pytest.raises(jira.ScriptError) as exc_info:
        jira.handle_transition(handler_client, args)

    assert exc_info.value.exit_code == jira.EXIT_FAILURE
    assert str(exc_info.value) == (
        f"Transition 'Missing' was not found for {TEST_ISSUE_KEY}. "
        "Available transitions: Done, Review"
    )


@pytest.mark.parametrize(
    ("body", "stdin_text", "expected_body"),
    [("Ship it", None, "Ship it"), (None, "From stdin", "From stdin")],
)
def test_handle_comment_posts_comment_body(
    stdin_factory: StdinFactory,
    client_recorder: ClientRecorder,
    handler_client: jira.JiraClient,
    body: str | None,
    stdin_text: str | None,
    expected_body: str,
) -> None:
    if stdin_text is not None:
        stdin_factory(stdin_text)
    args = argparse.Namespace(issue_key=TEST_ISSUE_KEY, body=body)

    jira.handle_comment(handler_client, args)

    assert client_recorder.calls[0].path == f"/issue/{TEST_ISSUE_KEY}/comment"
    assert client_recorder.calls[0].data == {"body": expected_body}


def test_handle_comment_requires_body(
    stdin_factory: StdinFactory,
    handler_client: jira.JiraClient,
) -> None:
    stdin_factory("")
    args = argparse.Namespace(issue_key=TEST_ISSUE_KEY, body=None)

    with pytest.raises(jira.ScriptError) as exc_info:
        jira.handle_comment(handler_client, args)

    assert exc_info.value.exit_code == jira.EXIT_USAGE
    assert str(exc_info.value) == USAGE_COMMENT


def test_handle_comments_aggregates_rows_by_issue(
    client_recorder: ClientRecorder,
    handler_client: jira.JiraClient,
) -> None:
    client_recorder.responses = [
        {"comments": [{"body": "one"}]},
        {"comments": [{"body": "two"}]},
    ]
    args = argparse.Namespace(issue_keys=[TEST_ISSUE_KEY, TEST_ISSUE_KEY_TWO])

    result = jira.handle_comments(handler_client, args)

    assert result == [
        {"body": "one", "_issue": TEST_ISSUE_KEY},
        {"body": "two", "_issue": TEST_ISSUE_KEY_TWO},
    ]


@pytest.mark.parametrize(
    ("issue_type_id", "expected_path"),
    [
        (None, f"/issue/createmeta/{TEST_PROJECT_KEY}/issuetypes"),
        (
            TEST_ISSUE_TYPE_ID,
            f"/issue/createmeta/{TEST_PROJECT_KEY}/issuetypes/{TEST_ISSUE_TYPE_ID}",
        ),
    ],
)
def test_handle_fields_builds_expected_paths(
    client_recorder: ClientRecorder,
    handler_client: jira.JiraClient,
    issue_type_id: str | None,
    expected_path: str,
) -> None:
    args = argparse.Namespace(project_key=TEST_PROJECT_KEY, issue_type_id=issue_type_id)

    jira.handle_fields(handler_client, args)

    assert client_recorder.calls[0].path == expected_path


def test_handle_fields_validates_issue_type_id(
    handler_client: jira.JiraClient,
) -> None:
    args = argparse.Namespace(project_key=TEST_PROJECT_KEY, issue_type_id="abc")

    with pytest.raises(jira.ScriptError) as exc_info:
        jira.handle_fields(handler_client, args)

    assert exc_info.value.exit_code == jira.EXIT_USAGE
    assert str(exc_info.value) == ERROR_ISSUE_TYPE_ID
