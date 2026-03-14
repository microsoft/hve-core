#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
# /// script
# requires-python = ">=3.11"
# ///

from __future__ import annotations

"""Jira REST API client for common issue workflows.

Supports Jira Cloud with email plus API token authentication and Jira
Server/Data Center with bearer token authentication.
"""

import argparse
import base64
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from typing import Any

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_USAGE = 2
ISSUE_KEY_PATTERN = re.compile(r"^[A-Za-z][A-Za-z0-9]+-\d+$")
INTEGER_PATTERN = re.compile(r"^\d+$")


class ScriptError(Exception):
    """Raised when the script cannot complete the requested operation."""

    def __init__(self, message: str, exit_code: int = EXIT_FAILURE) -> None:
        super().__init__(message)
        self.exit_code = exit_code


@dataclass(frozen=True)
class JiraClient:
    """Authenticated Jira REST client."""

    api_url: str
    auth_header: str
    use_legacy_search: bool

    @classmethod
    def from_environment(cls) -> "JiraClient":
        """Create a Jira client from environment variables.

        Returns:
            Configured Jira client.

        Raises:
            ScriptError: Environment is incomplete or invalid.
        """
        base_url = os.environ.get("JIRA_BASE_URL", "").strip()
        if not base_url:
            raise ScriptError("JIRA_BASE_URL is not set", EXIT_USAGE)
        if not re.match(r"^https?://", base_url):
            raise ScriptError(
                "JIRA_BASE_URL must start with https:// (or http:// for local development)",
                EXIT_USAGE,
            )

        jira_pat = os.environ.get("JIRA_PAT", "").strip()
        jira_user_email = os.environ.get("JIRA_USER_EMAIL", "").strip()
        jira_api_token = os.environ.get("JIRA_API_TOKEN", "").strip()

        if jira_pat:
            auth_header = f"Bearer {jira_pat}"
            use_legacy_search = True
        elif jira_user_email and jira_api_token:
            credentials = base64.b64encode(
                f"{jira_user_email}:{jira_api_token}".encode("utf-8")
            ).decode("utf-8")
            auth_header = f"Basic {credentials}"
            use_legacy_search = False
        else:
            raise ScriptError(
                "Set JIRA_PAT for Jira Server/Data Center or set both JIRA_USER_EMAIL and JIRA_API_TOKEN for Jira Cloud",
                EXIT_USAGE,
            )

        return cls(
            api_url=f"{base_url.rstrip('/')}/rest/api/2",
            auth_header=auth_header,
            use_legacy_search=use_legacy_search,
        )

    def request(self, method: str, path: str, data: Any | None = None) -> Any | None:
        """Run an authenticated Jira API request.

        Args:
            method: HTTP method.
            path: API-relative path beginning with `/`.
            data: Optional JSON-serializable request body.

        Returns:
            Parsed JSON response, plain text response, or None for empty bodies.

        Raises:
            ScriptError: Request fails or Jira returns an error response.
        """
        url = f"{self.api_url}{path}"
        headers = {
            "Authorization": self.auth_header,
            "Content-Type": "application/json",
            "Accept": "application/json",
        }
        body = json.dumps(data).encode("utf-8") if data is not None else None
        request = urllib.request.Request(url, data=body, headers=headers, method=method)

        try:
            with urllib.request.urlopen(request) as response:
                raw = response.read().decode("utf-8")
        except urllib.error.HTTPError as exc:
            raw = exc.read().decode("utf-8")
            details = _extract_error_message(raw)
            raise ScriptError(f"HTTP {exc.code} from {method} {url}: {details}") from exc
        except urllib.error.URLError as exc:
            raise ScriptError(f"Could not reach Jira API at {url}: {exc.reason}") from exc

        if not raw.strip():
            return None

        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            return raw


def _extract_error_message(raw: str) -> str:
    """Extract the clearest available message from an error payload."""
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        return raw.strip() or "No error details returned"

    if isinstance(payload, dict):
        error_messages = payload.get("errorMessages")
        if isinstance(error_messages, list) and error_messages:
            return "; ".join(str(item) for item in error_messages)
        errors = payload.get("errors")
        if isinstance(errors, dict) and errors:
            return "; ".join(f"{key}: {value}" for key, value in errors.items())

    return raw.strip() or "No error details returned"


def _validate_issue_key(issue_key: str) -> None:
    """Validate a Jira issue key."""
    if not ISSUE_KEY_PATTERN.match(issue_key):
        raise ScriptError(f"Invalid issue key: {issue_key}", EXIT_USAGE)


def _read_json_argument(payload: str | None, usage_message: str) -> Any:
    """Read JSON from an argument or stdin and parse it."""
    raw_payload = payload if payload is not None else sys.stdin.read().strip()
    if not raw_payload:
        raise ScriptError(usage_message, EXIT_USAGE)

    try:
        return json.loads(raw_payload)
    except json.JSONDecodeError as exc:
        raise ScriptError(f"Invalid JSON payload: {exc.msg}", EXIT_USAGE) from exc


def _extract_field(obj: Any, path: str) -> str:
    """Extract a dot-notated field from a nested JSON structure."""
    value = obj
    for part in path.split("."):
        if isinstance(value, dict):
            value = value.get(part)
        else:
            return ""

    if value is None:
        return ""
    if isinstance(value, list):
        return ", ".join(_stringify_value(item) for item in value)
    return _stringify_value(value)


def _stringify_value(value: Any) -> str:
    """Render a value as compact text output."""
    if isinstance(value, (dict, list)):
        return json.dumps(value, ensure_ascii=True)
    return str(value)


def _print_selected_fields(data: Any, fields: list[str]) -> None:
    """Print selected fields for a single item or a list of items."""
    if isinstance(data, list):
        print("\t".join(fields))
        for item in data:
            print("\t".join(_extract_field(item, field) for field in fields))
        return

    for field in fields:
        print(f"{field}: {_extract_field(data, field)}")


def _print_result(result: Any, fields: list[str] | None) -> None:
    """Render the command result to stdout."""
    if result is None:
        return
    if fields:
        _print_selected_fields(result, fields)
        return
    if isinstance(result, str):
        print(result)
        return
    print(json.dumps(result, indent=2))


def _split_fields(raw_fields: str | None) -> list[str] | None:
    """Parse the comma-delimited --fields argument."""
    if not raw_fields:
        return None
    fields = [field.strip() for field in raw_fields.split(",") if field.strip()]
    if not fields:
        raise ScriptError("--fields requires at least one field name", EXIT_USAGE)
    return fields


def handle_search(client: JiraClient, args: argparse.Namespace) -> Any:
    """Search for Jira issues using JQL."""
    if args.max_results <= 0:
        raise ScriptError("max_results must be a positive integer", EXIT_USAGE)

    encoded_jql = urllib.parse.quote(args.jql, safe="")
    if client.use_legacy_search:
        path = f"/search?jql={encoded_jql}&maxResults={args.max_results}"
    else:
        path = (
            f"/search/jql?jql={encoded_jql}&maxResults={args.max_results}"
            "&fields=*navigable"
        )
    response = client.request("GET", path)
    if args.fields:
        return (response or {}).get("issues", [])
    return response


def handle_get(client: JiraClient, args: argparse.Namespace) -> Any:
    """Fetch one Jira issue."""
    _validate_issue_key(args.issue_key)
    return client.request("GET", f"/issue/{args.issue_key}")


def handle_create(client: JiraClient, args: argparse.Namespace) -> Any:
    """Create a Jira issue from JSON payload data."""
    payload = _read_json_argument(
        args.payload,
        "Provide a JSON payload as an argument or pipe it through stdin for create",
    )
    return client.request("POST", "/issue", payload)


def handle_update(client: JiraClient, args: argparse.Namespace) -> Any:
    """Update a Jira issue."""
    _validate_issue_key(args.issue_key)
    payload = _read_json_argument(
        args.payload,
        "Provide a JSON payload as an argument or pipe it through stdin for update",
    )
    client.request("PUT", f"/issue/{args.issue_key}", payload)
    return {"key": args.issue_key, "status": "updated"}


def handle_transition(client: JiraClient, args: argparse.Namespace) -> Any:
    """Transition a Jira issue by transition ID or display name."""
    _validate_issue_key(args.issue_key)

    target = args.transition
    if INTEGER_PATTERN.match(target):
        transition_id = target
    else:
        response = client.request("GET", f"/issue/{args.issue_key}/transitions")
        transitions = (response or {}).get("transitions", [])
        match = next((item for item in transitions if item.get("name") == target), None)
        if match is None:
            available = ", ".join(
                sorted(item.get("name", "") for item in transitions if item.get("name"))
            )
            details = f" Available transitions: {available}" if available else ""
            raise ScriptError(
                f"Transition '{target}' was not found for {args.issue_key}.{details}",
                EXIT_FAILURE,
            )
        transition_id = str(match["id"])

    client.request(
        "POST",
        f"/issue/{args.issue_key}/transitions",
        {"transition": {"id": transition_id}},
    )
    return {"key": args.issue_key, "transitionId": transition_id, "status": "transitioned"}


def handle_comment(client: JiraClient, args: argparse.Namespace) -> Any:
    """Add a comment to a Jira issue."""
    _validate_issue_key(args.issue_key)
    body = args.body if args.body is not None else sys.stdin.read().strip()
    if not body:
        raise ScriptError(
            "Provide a comment body as an argument or pipe it through stdin for comment",
            EXIT_USAGE,
        )
    return client.request("POST", f"/issue/{args.issue_key}/comment", {"body": body})


def handle_comments(client: JiraClient, args: argparse.Namespace) -> Any:
    """List comments for one or more Jira issues."""
    comment_rows: list[dict[str, Any]] = []
    for issue_key in args.issue_keys:
        _validate_issue_key(issue_key)
        response = client.request("GET", f"/issue/{issue_key}/comment")
        for comment in (response or {}).get("comments", []):
            comment["_issue"] = issue_key
            comment_rows.append(comment)
    return comment_rows


def handle_fields(client: JiraClient, args: argparse.Namespace) -> Any:
    """Discover Jira issue creation metadata."""
    if args.issue_type_id:
        if not INTEGER_PATTERN.match(args.issue_type_id):
            raise ScriptError("issue_type_id must be a positive integer", EXIT_USAGE)
        return client.request(
            "GET", f"/issue/createmeta/{args.project_key}/issuetypes/{args.issue_type_id}"
        )
    return client.request("GET", f"/issue/createmeta/{args.project_key}/issuetypes")


def create_parser() -> argparse.ArgumentParser:
    """Create the command-line parser."""
    parser = argparse.ArgumentParser(
        description="Jira REST API helper for search, issue changes, comments, and transitions."
    )
    parser.add_argument(
        "--fields",
        help="Comma-delimited field list for read commands, for example key,fields.summary.",
    )

    subparsers = parser.add_subparsers(dest="command", required=True)

    search_parser = subparsers.add_parser("search", help="Search for issues with JQL.")
    search_parser.add_argument("jql", help="JQL query string.")
    search_parser.add_argument(
        "max_results",
        nargs="?",
        default=50,
        type=int,
        help="Maximum number of issues to return. Defaults to 50.",
    )
    search_parser.set_defaults(handler=handle_search)

    get_parser = subparsers.add_parser("get", help="Fetch a single issue.")
    get_parser.add_argument("issue_key", help="Issue key, for example PROJ-123.")
    get_parser.set_defaults(handler=handle_get)

    create_parser_ = subparsers.add_parser("create", help="Create an issue from a JSON payload.")
    create_parser_.add_argument(
        "payload",
        nargs="?",
        help="JSON payload string. If omitted, the script reads from stdin.",
    )
    create_parser_.set_defaults(handler=handle_create)

    update_parser = subparsers.add_parser("update", help="Update an issue with a JSON payload.")
    update_parser.add_argument("issue_key", help="Issue key, for example PROJ-123.")
    update_parser.add_argument(
        "payload",
        nargs="?",
        help="JSON payload string. If omitted, the script reads from stdin.",
    )
    update_parser.set_defaults(handler=handle_update)

    transition_parser = subparsers.add_parser(
        "transition", help="Transition an issue by name or transition ID."
    )
    transition_parser.add_argument("issue_key", help="Issue key, for example PROJ-123.")
    transition_parser.add_argument(
        "transition", help="Transition display name or numeric transition ID."
    )
    transition_parser.set_defaults(handler=handle_transition)

    comment_parser = subparsers.add_parser("comment", help="Add a comment to an issue.")
    comment_parser.add_argument("issue_key", help="Issue key, for example PROJ-123.")
    comment_parser.add_argument(
        "body",
        nargs="?",
        help="Comment body. If omitted, the script reads from stdin.",
    )
    comment_parser.set_defaults(handler=handle_comment)

    comments_parser = subparsers.add_parser(
        "comments", help="List comments for one or more issues."
    )
    comments_parser.add_argument(
        "issue_keys",
        nargs="+",
        help="One or more issue keys, for example PROJ-123 PROJ-124.",
    )
    comments_parser.set_defaults(handler=handle_comments)

    fields_parser = subparsers.add_parser(
        "fields", help="Discover issue types or required fields for issue creation."
    )
    fields_parser.add_argument("project_key", help="Project key, for example PROJ.")
    fields_parser.add_argument(
        "issue_type_id",
        nargs="?",
        help="Optional issue type ID used to inspect required fields.",
    )
    fields_parser.set_defaults(handler=handle_fields)

    return parser


def main() -> int:
    """Run the Jira CLI."""
    try:
        parser = create_parser()
        args = parser.parse_args()
        args.fields = _split_fields(args.fields)

        client = JiraClient.from_environment()
        result = args.handler(client, args)
        _print_result(result, args.fields)
        return EXIT_SUCCESS
    except KeyboardInterrupt:
        print("Interrupted by user", file=sys.stderr)
        return 130
    except BrokenPipeError:
        return EXIT_FAILURE
    except ScriptError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return exc.exit_code


if __name__ == "__main__":
    sys.exit(main())