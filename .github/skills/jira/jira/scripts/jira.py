#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
# /// script
# requires-python = ">=3.11"
# ///

"""Jira REST API client for common issue workflows.

Supports Jira Cloud with email plus API token authentication and Jira
Server/Data Center with bearer token authentication.
"""

from __future__ import annotations

import argparse
import base64
import io
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_USAGE = 2
REQUEST_TIMEOUT_SECONDS = 20
MAX_BODY_BYTES = 256 * 1024
MAX_RESULTS = 100
ISSUE_KEY_PATTERN = re.compile(r"^[A-Za-z][A-Za-z0-9]+-\d+$")
INTEGER_PATTERN = re.compile(r"^\d+$")

_AUDIT_OP = ""


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    """Refuse redirects so credentials are never replayed cross-host."""

    def redirect_request(
        self,
        req: urllib.request.Request,
        fp: Any,
        code: int,
        msg: str,
        headers: Any,
        newurl: str,
    ) -> Any:
        location = headers.get("Location", "<unknown>") if headers else "<unknown>"
        raise urllib.error.HTTPError(
            req.full_url,
            code,
            f"redirect blocked to {location}",
            hdrs={},
            fp=io.BytesIO(b""),
        )


_OPENER = urllib.request.build_opener(_NoRedirect())


class ScriptError(Exception):
    """Raised when the script cannot complete the requested operation."""

    def __init__(self, message: str, exit_code: int = EXIT_FAILURE) -> None:
        super().__init__(message)
        self.exit_code = exit_code


def _is_loopback_host(hostname: str | None) -> bool:
    """Return True for loopback hosts that may allow local development."""
    return hostname in {"localhost", "127.0.0.1", "::1"}


def _canonicalize_base_url(base_url: str) -> str:
    """Return an origin-only Jira base URL after validation."""
    raw_value = base_url
    value = raw_value.strip()
    if not value:
        raise ScriptError("JIRA_BASE_URL is not set", EXIT_USAGE)
    if any(ord(char) < 32 or ord(char) == 127 for char in raw_value):
        raise ScriptError(
            "JIRA_BASE_URL must be an origin-only URL",
            EXIT_USAGE,
        )

    parsed = urllib.parse.urlsplit(value)
    if parsed.scheme not in {"http", "https"}:
        raise ScriptError(
            "JIRA_BASE_URL must start with https:// (or http:// for local development)",
            EXIT_USAGE,
        )
    if parsed.username is not None or parsed.password is not None:
        raise ScriptError(
            "JIRA_BASE_URL must not include userinfo",
            EXIT_USAGE,
        )
    if parsed.path not in {"", "/"}:
        raise ScriptError(
            "JIRA_BASE_URL must be an origin-only URL",
            EXIT_USAGE,
        )
    if parsed.query or parsed.fragment:
        raise ScriptError(
            "JIRA_BASE_URL must be an origin-only URL",
            EXIT_USAGE,
        )
    if not parsed.hostname:
        raise ScriptError(
            "JIRA_BASE_URL must include a host",
            EXIT_USAGE,
        )

    if parsed.scheme == "http":
        allow_insecure = os.environ.get("JIRA_ALLOW_INSECURE", "").strip() == "1"
        if not allow_insecure and not _is_loopback_host(parsed.hostname):
            raise ScriptError(
                "JIRA_BASE_URL must use https:// for non-loopback hosts",
                EXIT_USAGE,
            )

    return urllib.parse.urlunsplit((parsed.scheme, parsed.netloc, "", "", ""))


def _validate_base_url(base_url: str) -> str:
    """Validate the base URL and enforce TLS for non-loopback hosts."""
    return _canonicalize_base_url(base_url)


def _open_url(request: urllib.request.Request, *, timeout: int) -> Any:
    """Open a URL with the configured opener."""
    return _OPENER.open(request, timeout=timeout)


def _read_response_body(response: Any) -> bytes:
    """Read a response body up to the configured limit."""
    read = getattr(response, "read", None)
    if read is None:
        return b""

    try:
        body = read(MAX_BODY_BYTES + 1)
    except TypeError:
        body = read()

    if isinstance(body, str):
        body = body.encode("utf-8")
    if body is None:
        return b""
    if len(body) > MAX_BODY_BYTES:
        raise ScriptError(
            f"Response body exceeds {MAX_BODY_BYTES} bytes (too large)",
            EXIT_FAILURE,
        )
    return body


def _get_response_content_type(response: Any) -> str:
    """Extract the response content type from headers when available."""
    headers = getattr(response, "headers", None)
    if headers is None:
        return ""
    if hasattr(headers, "get"):
        content_type = headers.get("Content-Type") or headers.get("content-type") or ""
        return str(content_type)
    return ""


def _redact_sensitive_text(text: str) -> str:
    """Redact common secrets from diagnostic text."""
    redacted = text.strip()
    redacted = re.sub(
        r"(?i)\b(Bearer|Basic)\s+[A-Za-z0-9._~+/=-]+",
        r"\1 [REDACTED]",
        redacted,
    )
    redacted = re.sub(
        r"(?i)\b(Authorization|Proxy-Authorization|X-API-Key|PRIVATE-TOKEN|Cookie|Set-Cookie)\s*[:=]\s*[^\s,;]+",
        r"\1=[REDACTED]",
        redacted,
    )
    redacted = re.sub(
        r"(?i)([?&])(private_token|access_token|token|api_key|apikey)=([^&#\s]+)",
        r"\1\2=[REDACTED]",
        redacted,
    )
    return redacted


def _preview_for_logging(text: str, *, limit: int = 2048) -> str:
    """Return a capped, redacted preview suitable for diagnostics."""
    preview = text if len(text) <= limit else f"{text[:limit]}..."
    return _redact_sensitive_text(preview)


def _audit_write(event: dict[str, Any]) -> bool:
    """Append one audit event as a JSON line when auditing is enabled.

    Returns:
        True when an event was written, False when auditing is disabled.

    Raises:
        OSError: The audit log path is set but cannot be written.
    """
    path = os.environ.get("JIRA_AUDIT_LOG", "").strip()
    if not path:
        return False
    with open(path, "a", encoding="utf-8") as handle:
        handle.write(json.dumps(event) + "\n")
    return True


def _audit_event(actor: str, method: str, resource: str, event: str) -> dict[str, Any]:
    """Build a base audit event record with the query string stripped."""
    return {
        "ts": datetime.now(timezone.utc).isoformat(),
        "skill": "jira",
        "actor": actor,
        "op": _AUDIT_OP,
        "method": method,
        "resource": urllib.parse.urlsplit(resource).path,
        "event": event,
    }


def _audit_attempt(actor: str, method: str, resource: str) -> None:
    """Write the write-ahead attempt record, failing closed when unwritable."""
    try:
        _audit_write(_audit_event(actor, method, resource, "attempt"))
    except OSError as exc:
        raise ScriptError(
            f"audit log write failed; refusing to proceed: {exc}",
            EXIT_FAILURE,
        ) from exc


def _audit_outcome(
    actor: str,
    method: str,
    resource: str,
    outcome: str,
    *,
    status: int | None = None,
    error: str | None = None,
) -> None:
    """Write the post-operation outcome record (best-effort)."""
    record = _audit_event(actor, method, resource, "outcome")
    record["outcome"] = outcome
    if status is not None:
        record["status"] = status
    if error:
        record["error"] = _redact_sensitive_text(error)
    try:
        _audit_write(record)
    except OSError as exc:
        print(f"warning: audit outcome write failed: {exc}", file=sys.stderr)


def _create_response_with_body(
    body: str | bytes,
    *,
    content_type: str = "",
) -> Any:
    """Create a minimal response-like object with a body and optional headers."""
    if isinstance(body, str):
        payload = body.encode("utf-8")
    else:
        payload = body

    class _Response:
        def __init__(self, payload: bytes, content_type: str) -> None:
            self._payload = payload
            self.headers = {"Content-Type": content_type} if content_type else {}

        def __enter__(self) -> "_Response":
            return self

        def __exit__(self, exc_type: Any, exc: Any, tb: Any) -> bool:
            return False

        def read(self, size: int | None = None) -> bytes:
            if size is None:
                return self._payload
            return self._payload[:size]

    return _Response(payload, content_type)


@dataclass(frozen=True)
class JiraClient:
    """Authenticated Jira REST client."""

    api_url: str
    auth_header: str
    use_legacy_search: bool
    audit_actor: str

    @classmethod
    def from_environment(cls) -> "JiraClient":
        """Create a Jira client from environment variables.

        Returns:
            Configured Jira client.

        Raises:
            ScriptError: Environment is incomplete or invalid.
        """
        base_url = _canonicalize_base_url(os.environ.get("JIRA_BASE_URL", ""))

        jira_pat = os.environ.get("JIRA_PAT", "").strip()
        jira_user_email = os.environ.get("JIRA_USER_EMAIL", "").strip()
        jira_api_token = os.environ.get("JIRA_API_TOKEN", "").strip()

        if jira_pat:
            auth_header = f"Bearer {jira_pat}"
            use_legacy_search = True
        elif jira_user_email or jira_api_token:
            if not jira_user_email or not jira_api_token:
                raise ScriptError(
                    "Set JIRA_PAT for Jira Server/Data Center or set both "
                    "JIRA_USER_EMAIL and JIRA_API_TOKEN for Jira Cloud",
                    EXIT_USAGE,
                )
            _validate_ascii_no_newlines(jira_user_email, name="JIRA_USER_EMAIL")
            _validate_ascii_no_newlines(jira_api_token, name="JIRA_API_TOKEN")
            credentials = base64.b64encode(
                f"{jira_user_email}:{jira_api_token}".encode("ascii")
            ).decode("ascii")
            auth_header = f"Basic {credentials}"
            use_legacy_search = False
        else:
            raise ScriptError(
                "Set JIRA_PAT for Jira Server/Data Center or set both "
                "JIRA_USER_EMAIL and JIRA_API_TOKEN for Jira Cloud",
                EXIT_USAGE,
            )

        return cls(
            api_url=f"{base_url}/rest/api/2",
            auth_header=auth_header,
            use_legacy_search=use_legacy_search,
            audit_actor=(
                os.environ.get("JIRA_AUDIT_ACTOR", "").strip()
                or jira_user_email
                or "jira-pat"
            ),
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
        _audit_attempt(self.audit_actor, method, path)

        try:
            with _open_url(request, timeout=REQUEST_TIMEOUT_SECONDS) as response:
                body_bytes = _read_response_body(response)
                content_type = _get_response_content_type(response)
                raw = body_bytes.decode("utf-8", errors="replace")
                # Enforce JSON content type only when a body is present; empty
                # 2xx responses (for example 204 No Content from transitions)
                # carry no body and frequently omit Content-Type.
                if raw.strip():
                    if not content_type:
                        raise ScriptError(
                            "Missing Content-Type from Jira API",
                            EXIT_FAILURE,
                        )
                    if not content_type.lower().startswith("application/json"):
                        raise ScriptError(
                            f"Unexpected content type from Jira API: {content_type}",
                            EXIT_FAILURE,
                        )
        except urllib.error.HTTPError as exc:
            body_bytes = _read_response_body(exc)
            raw = body_bytes.decode("utf-8", errors="replace")
            details = _extract_error_message(raw)
            _audit_outcome(
                self.audit_actor, method, path, "error", status=exc.code, error=details
            )
            if exc.code in {401, 403}:
                raise ScriptError(
                    f"HTTP {exc.code} from {method} {url}: authentication failed; "
                    "the token may be expired or revoked — rotate JIRA_API_TOKEN "
                    f"or JIRA_PAT. {details}"
                ) from exc
            if exc.code in {301, 302, 303, 307, 308}:
                raise ScriptError(
                    "Refusing redirect from "
                    f"{method} {url}: {details or 'redirect blocked'}"
                ) from exc
            raise ScriptError(
                f"HTTP {exc.code} from {method} {url}: {details}"
            ) from exc
        except urllib.error.URLError as exc:
            _audit_outcome(
                self.audit_actor, method, path, "error", error=str(exc.reason)
            )
            raise ScriptError(
                f"Could not reach Jira API at {url}: {exc.reason}"
            ) from exc

        _audit_outcome(self.audit_actor, method, path, "success")

        if not raw.strip():
            return None

        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            return raw


def _validate_ascii_no_newlines(value: str, *, name: str) -> None:
    """Validate that a credential value is non-empty and ASCII-only."""
    if not value:
        raise ScriptError(f"{name} must not be empty", EXIT_USAGE)
    if any(ord(char) < 32 or ord(char) == 127 for char in value):
        raise ScriptError(f"{name} must not contain control characters", EXIT_USAGE)
    try:
        value.encode("ascii")
    except UnicodeEncodeError as exc:
        raise ScriptError(f"{name} must be ASCII", EXIT_USAGE) from exc


def _extract_error_message(raw: str) -> str:
    """Extract the clearest available message from an error payload."""
    sanitized = _preview_for_logging(raw)
    try:
        payload = json.loads(sanitized)
    except json.JSONDecodeError:
        return sanitized.strip() or "No error details returned"

    if isinstance(payload, dict):
        error_messages = payload.get("errorMessages")
        if isinstance(error_messages, list) and error_messages:
            return "; ".join(str(item) for item in error_messages)
        errors = payload.get("errors")
        if isinstance(errors, dict) and errors:
            return "; ".join(f"{key}: {value}" for key, value in errors.items())

    return sanitized.strip() or "No error details returned"


def _validate_issue_key(issue_key: str) -> None:
    """Validate a Jira issue key."""
    if not ISSUE_KEY_PATTERN.match(issue_key):
        raise ScriptError(f"Invalid issue key: {issue_key}", EXIT_USAGE)


def _read_stdin(limit: int) -> str:
    """Read from stdin using a bounded size when supported."""
    read = getattr(sys.stdin, "read", None)
    if read is None:
        return ""
    try:
        raw = read(limit + 1)
    except TypeError:
        raw = read()
    if raw is None:
        return ""
    return str(raw)


def _read_json_argument(payload: str | None, usage_message: str) -> Any:
    """Read JSON from an argument or stdin and parse it."""
    raw_payload = payload if payload is not None else _read_stdin(MAX_BODY_BYTES)
    if raw_payload is None:
        raw_payload = ""
    if len(raw_payload.encode("utf-8")) > MAX_BODY_BYTES:
        raise ScriptError("Input payload exceeds size limit", EXIT_USAGE)
    raw_payload = raw_payload.strip()
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
        print(_preview_for_logging(result))
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


def _clamp_max_results(value: int) -> int:
    """Clamp max_results to the Jira page-size maximum.

    Mirrors the Jira REST pagination contract: the server caps maxResults at the
    operation maximum and returns the value actually used, so over-limit requests
    are clamped rather than rejected. Non-positive values are invalid.
    """
    if value <= 0:
        raise ScriptError("max_results must be a positive integer", EXIT_USAGE)
    return min(value, MAX_RESULTS)


def _quote_path_segment(value: str) -> str:
    """Quote a path segment for safe interpolation into Jira routes."""
    return urllib.parse.quote(value, safe="")


def handle_search(client: JiraClient, args: argparse.Namespace) -> Any:
    """Search for Jira issues using JQL."""
    max_results = _clamp_max_results(args.max_results)

    encoded_jql = urllib.parse.quote(args.jql, safe="")
    if client.use_legacy_search:
        path = f"/search?jql={encoded_jql}&maxResults={max_results}"
    else:
        path = (
            f"/search/jql?jql={encoded_jql}&maxResults={max_results}&fields=*navigable"
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
    return {
        "key": args.issue_key,
        "transitionId": transition_id,
        "status": "transitioned",
    }


def handle_comment(client: JiraClient, args: argparse.Namespace) -> Any:
    """Add a comment to a Jira issue."""
    _validate_issue_key(args.issue_key)
    body = args.body if args.body is not None else _read_stdin(MAX_BODY_BYTES)
    if body is None:
        body = ""
    if len(body.encode("utf-8")) > MAX_BODY_BYTES:
        raise ScriptError("Comment body exceeds size limit", EXIT_USAGE)
    body = body.strip()
    if not body:
        raise ScriptError(
            "Provide a comment body as an argument or pipe it through "
            "stdin for comment",
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
        quoted_project_key = _quote_path_segment(args.project_key)
        return client.request(
            "GET",
            f"/issue/createmeta/{quoted_project_key}/issuetypes/{args.issue_type_id}",
        )
    quoted_project_key = _quote_path_segment(args.project_key)
    return client.request("GET", f"/issue/createmeta/{quoted_project_key}/issuetypes")


def create_parser() -> argparse.ArgumentParser:
    """Create the command-line parser."""
    parser = argparse.ArgumentParser(
        description=(
            "Jira REST API helper for search, issue changes, comments, and transitions."
        )
    )
    parser.add_argument(
        "--fields",
        help=(
            "Comma-delimited field list for read commands, for example "
            "key,fields.summary."
        ),
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

    create_parser_ = subparsers.add_parser(
        "create",
        help="Create an issue from a JSON payload.",
    )
    create_parser_.add_argument(
        "payload",
        nargs="?",
        help="JSON payload string. If omitted, the script reads from stdin.",
    )
    create_parser_.set_defaults(handler=handle_create)

    update_parser = subparsers.add_parser(
        "update",
        help="Update an issue with a JSON payload.",
    )
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
        global _AUDIT_OP
        _AUDIT_OP = getattr(args, "command", "") or ""

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


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
