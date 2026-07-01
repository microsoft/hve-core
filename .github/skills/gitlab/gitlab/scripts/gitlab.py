#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
# /// script
# requires-python = ">=3.11"
# ///

"""GitLab REST API v4 client for merge requests, pipelines, and jobs.

Environment variables:
    GITLAB_URL: Required GitLab base URL.
    GITLAB_TOKEN: Required personal access token.
    GITLAB_PROJECT: Optional project id or path. Auto-detected from git remote.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from typing import Any, Callable, NoReturn, cast

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_USAGE = 2
REQUEST_TIMEOUT = 30
MAX_BODY_BYTES = 1_048_576
MAX_LOG_BYTES = 65_536
MAX_NUMERIC_ID = 2_147_483_647
MAX_POSITIVE_INT = 100
VALID_MR_STATES = {"all", "opened", "closed", "locked", "merged"}
REF_PATTERN = re.compile(r"^[\w./-]+$")

selected_fields: list[str] | None = None
gitlab_url = ""
gitlab_token = ""
api_url = ""
audit_actor = ""
_AUDIT_OP = ""

sys.dont_write_bytecode = True


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    """Refuse redirects so tokens are not replayed to a new host."""

    def redirect_request(
        self,
        req: urllib.request.Request,
        fp: object,
        code: int,
        msg: str,
        headers: object,
        newurl: str,
    ) -> urllib.request.Request | None:
        location = newurl or "<unknown>"
        raise urllib.error.HTTPError(
            req.full_url,
            code,
            f"refusing redirect to {location}",
            headers,
            fp,
        )


_OPENER = urllib.request.build_opener(_NoRedirect())


def die(message: str, exit_code: int = EXIT_FAILURE) -> NoReturn:
    """Print an error and raise SystemExit.

    Args:
        message: Error text to print.
        exit_code: Process exit code.

    Returns:
        Never returns. The annotation is kept simple for CLI usage.
    """
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(exit_code)


def _redact(text: str) -> str:
    """Remove common secret-looking values from error text."""
    if not text:
        return text
    redacted = re.sub(
        r"(?i)(^|[\s,;])((?:private-token|x-api-key|authorization|proxy-authorization|cookie|set-cookie|token|password|secret))\b\s*[:=]?\s*([^\s,;]+)",
        r"\1\2=[REDACTED]",
        text,
    )
    redacted = re.sub(
        r"(?i)([?&](?:private_token|access_token|token|api_key|password|secret)=)([^&#\s]+)",
        r"\1[REDACTED]",
        redacted,
    )
    return redacted


def _preview_text(text: str, limit: int | None = None) -> str:
    """Cap preview output while preserving the full preview marker."""
    if limit is None:
        limit = MAX_BODY_BYTES
    if len(text) <= limit:
        return text
    return text[:limit] + "\n... [truncated]"


def _normalize_base_url(value: str) -> str:
    """Return an origin-only GitLab base URL."""
    if not value:
        raise ValueError("GITLAB_URL is not set")
    if any(ord(char) < 32 or ord(char) == 127 for char in value):
        raise ValueError(
            "GITLAB_URL must be an origin-only URL without control characters"
        )

    parsed_url = urllib.parse.urlsplit(value)
    if parsed_url.scheme not in {"http", "https"}:
        raise ValueError(
            "GITLAB_URL must start with https:// (or http:// for local dev)"
        )
    if parsed_url.username or parsed_url.password:
        raise ValueError("GITLAB_URL must be an origin-only URL without userinfo")
    if parsed_url.query or parsed_url.fragment:
        raise ValueError(
            "GITLAB_URL must be an origin-only URL without query or fragment"
        )
    if parsed_url.path not in {"", "/"}:
        raise ValueError("GITLAB_URL must be an origin-only URL without a path")
    if not parsed_url.hostname:
        raise ValueError("GITLAB_URL must include a hostname")

    return urllib.parse.urlunsplit((parsed_url.scheme, parsed_url.netloc, "", "", ""))


def _is_loopback(host: str | None) -> bool:
    """Return True when a URL host is loopback-only."""
    if not host:
        return False
    host = host.lower()
    return host in {"localhost", "127.0.0.1", "::1"} or host.startswith("127.")


def _sanitize_remote_url(remote_url: str) -> str:
    """Strip any embedded credentials from a git remote URL for logging."""
    pattern = re.compile(
        r"^(?P<scheme>https?://)(?P<user>[^/@]+)(?::(?P<password>[^@/]+))?@"
    )
    return pattern.sub(r"\g<scheme>", remote_url)


def _validate_project_path(path: str) -> None:
    """Reject project paths that contain traversal or separator escapes."""
    if not path:
        die("invalid project path", EXIT_USAGE)
    if any(char in path for char in {"%", "\\"}):
        die("invalid project path", EXIT_USAGE)

    for segment in path.split("/"):
        if segment in {"", ".", ".."}:
            die("invalid project path", EXIT_USAGE)


def _summarize_error_body(raw_error: str) -> str:
    """Prefer a structured message and otherwise return a redacted preview."""
    try:
        parsed_error = json.loads(raw_error)
    except (json.JSONDecodeError, ValueError):
        return _preview_text(_redact(raw_error))

    if isinstance(parsed_error, dict):
        message = parsed_error.get("message") or parsed_error.get("error")
        if isinstance(message, str) and message.strip():
            return _preview_text(_redact(message))

    return _preview_text(_redact(raw_error))


def _audit_write(event: dict[str, Any]) -> bool:
    """Append one audit event as a JSON line when auditing is enabled.

    Returns:
        True when an event was written, False when auditing is disabled.

    Raises:
        OSError: The audit log path is set but cannot be written.
    """
    path = os.environ.get("GITLAB_AUDIT_LOG", "").strip()
    if not path:
        return False
    with open(path, "a", encoding="utf-8") as handle:
        handle.write(json.dumps(event) + "\n")
    return True


def _audit_event(actor: str, method: str, resource: str, event: str) -> dict[str, Any]:
    """Build a base audit event record with the query string stripped."""
    return {
        "ts": datetime.now(timezone.utc).isoformat(),
        "skill": "gitlab",
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
        die(f"audit log write failed; refusing to proceed: {exc}", EXIT_FAILURE)


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
        record["error"] = _redact(error)
    try:
        _audit_write(record)
    except OSError as exc:
        print(f"warning: audit outcome write failed: {exc}", file=sys.stderr)


def require_environment() -> None:
    """Load and validate required environment variables."""
    global api_url
    global audit_actor
    global gitlab_token
    global gitlab_url

    gitlab_url = os.environ.get("GITLAB_URL", "")
    gitlab_token = os.environ.get("GITLAB_TOKEN", "")

    if not gitlab_url:
        die("GITLAB_URL is not set", EXIT_USAGE)
    try:
        gitlab_url = _normalize_base_url(gitlab_url)
    except ValueError as error:
        die(str(error), EXIT_USAGE)

    parsed_url = urllib.parse.urlsplit(gitlab_url)
    if parsed_url.scheme == "http" and not _is_loopback(parsed_url.hostname):
        die(
            "GITLAB_URL must use https:// for non-local hosts; "
            "plaintext http is not allowed",
            EXIT_USAGE,
        )
    if not gitlab_token:
        die("GITLAB_TOKEN is not set", EXIT_USAGE)

    api_url = gitlab_url + "/api/v4"
    audit_actor = os.environ.get("GITLAB_AUDIT_ACTOR", "").strip() or "gitlab-token"


def strip_git_suffix(path: str) -> str:
    """Remove a trailing .git suffix when present."""
    if path.endswith(".git"):
        return path[:-4]
    return path


def project() -> str:
    """Resolve the target GitLab project from environment or git remote."""
    configured_project = os.environ.get("GITLAB_PROJECT", "")
    if configured_project:
        _validate_project_path(configured_project)
        return urllib.parse.quote(configured_project, safe="")

    try:
        remote_url = subprocess.check_output(
            ["git", "remote", "get-url", "origin"],
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=REQUEST_TIMEOUT,
        ).strip()
    except subprocess.TimeoutExpired:
        die("timed out resolving git remote for project", EXIT_FAILURE)
    except (subprocess.CalledProcessError, FileNotFoundError):
        die("GITLAB_PROJECT not set and no git remote found", EXIT_USAGE)

    sanitized_remote_url = _sanitize_remote_url(remote_url)
    if remote_url.startswith("git@"):
        path = remote_url.split(":", 1)[1]
    elif re.match(r"^https?://", remote_url):
        parsed_remote = urllib.parse.urlsplit(remote_url)
        path = parsed_remote.path.lstrip("/")
    else:
        die(f"cannot parse git remote URL: {sanitized_remote_url}", EXIT_USAGE)

    path = strip_git_suffix(path)
    if not path:
        die(
            f"cannot extract project path from remote: {sanitized_remote_url}",
            EXIT_USAGE,
        )
    _validate_project_path(path)
    return urllib.parse.quote(path, safe="")


def validate_numeric_id(value: str) -> None:
    """Validate that a CLI argument is a numeric identifier."""
    if not re.fullmatch(r"\d+", value):
        die(f"expected numeric ID, got: {value}", EXIT_USAGE)
    numeric_value = int(value)
    if numeric_value <= 0 or numeric_value > MAX_NUMERIC_ID:
        die(
            f"expected numeric ID between 1 and {MAX_NUMERIC_ID}, got: {value}",
            EXIT_USAGE,
        )


def validate_positive_int(
    value: str,
    label: str = "value",
    upper_bound: int = MAX_POSITIVE_INT,
) -> None:
    """Validate that a CLI argument is a positive integer string."""
    if not re.fullmatch(r"\d+", value):
        die(f"{label} must be a positive integer, got: {value}", EXIT_USAGE)
    numeric_value = int(value)
    if numeric_value <= 0 or numeric_value > upper_bound:
        die(
            f"{label} must be a positive integer between 1 and "
            f"{upper_bound}, got: {value}",
            EXIT_USAGE,
        )


def validate_state(value: str) -> None:
    """Validate that a merge request state is allowed."""
    if value not in VALID_MR_STATES:
        die(f"invalid merge request state: {value}", EXIT_USAGE)


def validate_ref(value: str) -> None:
    """Validate that a pipeline ref matches the supported pattern."""
    if not REF_PATTERN.fullmatch(value):
        die(f"invalid ref: {value}", EXIT_USAGE)


def _read_capped(response: Any, limit: int, *, fail_on_limit: bool = True) -> bytes:
    """Read up to the limit and optionally reject oversized bodies."""
    chunk = response.read(limit + 1)
    if chunk is None:
        return b""
    if len(chunk) > limit and fail_on_limit:
        die("response body exceeds size limit", EXIT_FAILURE)
    return chunk[:limit]


def _request_bytes(
    method: str,
    url: str,
    *,
    headers: dict[str, str] | None = None,
    data: object | None = None,
    require_json: bool = True,
    error_context: str | None = None,
) -> bytes:
    """Issue an HTTP request through the hardened transport."""
    request_headers = {"Accept": "application/json"}
    if headers:
        request_headers.update(headers)
    if data is not None:
        body = json.dumps(data).encode("utf-8")
    else:
        body = None
    request_obj = urllib.request.Request(
        url, data=body, headers=request_headers, method=method
    )
    _audit_attempt(audit_actor, method, url)
    try:
        with _OPENER.open(request_obj, timeout=REQUEST_TIMEOUT) as response:
            content_type = ""
            if hasattr(response, "headers"):
                content_type = str(response.headers.get("Content-Type", "") or "")
            result = _read_capped(response, MAX_BODY_BYTES, fail_on_limit=require_json)
            # Enforce JSON content type only when a body is present; empty 2xx
            # responses (for example 204 No Content) carry no body and often
            # omit Content-Type.
            if require_json and result.strip():
                if not content_type:
                    die("unexpected Content-Type: <missing>", EXIT_FAILURE)
                if not content_type.lower().startswith("application/json"):
                    die(f"unexpected Content-Type: {content_type}", EXIT_FAILURE)
            _audit_outcome(audit_actor, method, url, "success")
            return result
    except urllib.error.HTTPError as error:
        body_bytes = _read_capped(error, MAX_BODY_BYTES, fail_on_limit=False)
        raw_error = body_bytes.decode("utf-8", errors="replace")
        if error_context:
            failure_message = f"HTTP {error.code} {error_context}"
        else:
            failure_message = f"HTTP {error.code} from {method} {url}"
        if error.code in {401, 403}:
            failure_message += (
                "; the token may be expired or revoked — rotate GITLAB_TOKEN"
            )
        _audit_outcome(
            audit_actor, method, url, "error", status=error.code, error=raw_error
        )
        summary = _summarize_error_body(raw_error)
        if summary.strip():
            print(summary, file=sys.stderr)
        die(failure_message)


def request(
    method: str,
    url: str,
    data: object | None = None,
    quiet: bool = False,
) -> object | None:
    """Issue an HTTP request to the GitLab API.

    Args:
        method: HTTP method.
        url: Fully qualified request URL.
        data: Optional JSON-serializable payload.
        quiet: When True, suppress pretty-printed JSON output.

    Returns:
        Parsed JSON content, or None for empty or non-JSON responses.
    """
    headers = {
        "PRIVATE-TOKEN": gitlab_token,
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    raw_bytes = _request_bytes(
        method,
        url,
        headers=headers,
        data=data,
        require_json=False,
    )
    raw = raw_bytes.decode("utf-8", errors="replace")

    if not raw.strip():
        return None

    try:
        parsed = json.loads(raw)
    except (json.JSONDecodeError, ValueError):
        print(_preview_text(_redact(raw)))
        return None

    if not quiet:
        print(json.dumps(parsed, indent=2))
    return parsed


def parse_fields(arguments: list[str]) -> list[str]:
    """Extract the optional --fields argument from the CLI."""
    global selected_fields

    cleaned_arguments: list[str] = []
    index = 0
    while index < len(arguments):
        current = arguments[index]
        if current == "--fields":
            if index + 1 >= len(arguments):
                die("usage: --fields requires a comma-separated value list", EXIT_USAGE)
            selected_fields = arguments[index + 1].split(",")
            index += 2
            continue
        cleaned_arguments.append(current)
        index += 1
    return cleaned_arguments


def extract_field(obj: Any, path: str) -> str:
    """Extract a value using dot notation such as author.name."""
    current = obj
    for part in path.split("."):
        if isinstance(current, dict):
            current_dict = cast(dict[str, Any], current)
            current = current_dict.get(part)
        else:
            return ""

    if current is None:
        return ""
    if isinstance(current, list):
        current_list = cast(list[Any], current)
        return ", ".join(str(item) for item in current_list)
    return str(cast(object, current))


def print_fields(data: Any) -> None:
    """Print extracted fields for a list response or a single object."""
    if not selected_fields:
        return

    if isinstance(data, list):
        print("\t".join(selected_fields))
        for item in cast(list[Any], data):
            print(
                "\t".join(
                    extract_field(item, field_name) for field_name in selected_fields
                )
            )
        return

    for field_name in selected_fields:
        print(f"{field_name}: {extract_field(data, field_name)}")


def load_json_payload(raw_payload: str, usage: str) -> object:
    """Parse a JSON payload or stop with a usage error."""
    try:
        return json.loads(raw_payload)
    except json.JSONDecodeError as error:
        die(f"invalid JSON payload: {error.msg}. {usage}", EXIT_USAGE)


def cmd_mr_list(args: list[str]) -> None:
    """List merge requests."""
    state = args[0] if args else "all"
    validate_state(state)
    max_results = args[1] if len(args) > 1 else "20"
    validate_positive_int(max_results, "max_results", MAX_POSITIVE_INT)
    data = request(
        "GET",
        f"{api_url}/projects/{project()}/merge_requests?state={state}&per_page={max_results}&order_by=created_at&sort=desc",
        quiet=bool(selected_fields),
    )
    if selected_fields and data is not None:
        print_fields(data)


def cmd_mr_get(args: list[str]) -> None:
    """Get one merge request."""
    if not args:
        die("usage: gitlab mr-get <mr-iid>", EXIT_USAGE)
    merge_request_iid = args[0]
    validate_numeric_id(merge_request_iid)
    data = request(
        "GET",
        f"{api_url}/projects/{project()}/merge_requests/{merge_request_iid}",
        quiet=bool(selected_fields),
    )
    if selected_fields and data is not None:
        print_fields(data)


def cmd_mr_create(args: list[str]) -> None:
    """Create a merge request from JSON input."""
    raw_payload = args[0] if args else sys.stdin.read(MAX_BODY_BYTES + 1)
    if not args and len(raw_payload) > MAX_BODY_BYTES:
        die("request body exceeds size limit", EXIT_FAILURE)
    raw_payload = raw_payload.strip()
    usage = "usage: gitlab mr-create <json> or pipe JSON to stdin"
    if not raw_payload:
        die(usage, EXIT_USAGE)
    request(
        "POST",
        f"{api_url}/projects/{project()}/merge_requests",
        load_json_payload(raw_payload, usage),
    )


def cmd_mr_update(args: list[str]) -> None:
    """Update a merge request from JSON input."""
    if not args:
        die("usage: gitlab mr-update <mr-iid> <json>", EXIT_USAGE)
    merge_request_iid = args[0]
    validate_numeric_id(merge_request_iid)
    raw_payload = args[1] if len(args) > 1 else sys.stdin.read(MAX_BODY_BYTES + 1)
    if len(args) <= 1 and len(raw_payload) > MAX_BODY_BYTES:
        die("request body exceeds size limit", EXIT_FAILURE)
    raw_payload = raw_payload.strip()
    usage = "usage: gitlab mr-update <mr-iid> <json> or pipe JSON to stdin"
    if not raw_payload:
        die(usage, EXIT_USAGE)
    request(
        "PUT",
        f"{api_url}/projects/{project()}/merge_requests/{merge_request_iid}",
        load_json_payload(raw_payload, usage),
    )


def cmd_mr_comment(args: list[str]) -> None:
    """Create a merge request note."""
    if not args:
        die("usage: gitlab mr-comment <mr-iid> <body>", EXIT_USAGE)
    merge_request_iid = args[0]
    validate_numeric_id(merge_request_iid)
    body = args[1] if len(args) > 1 else sys.stdin.read(MAX_BODY_BYTES + 1)
    if len(args) <= 1 and len(body) > MAX_BODY_BYTES:
        die("request body exceeds size limit", EXIT_FAILURE)
    body = body.strip()
    if not body:
        die(
            "usage: gitlab mr-comment <mr-iid> <body> or pipe body to stdin",
            EXIT_USAGE,
        )
    request(
        "POST",
        f"{api_url}/projects/{project()}/merge_requests/{merge_request_iid}/notes",
        {"body": body},
    )


def cmd_mr_notes(args: list[str]) -> None:
    """List merge request notes."""
    if not args:
        die("usage: gitlab mr-notes <mr-iid> [max]", EXIT_USAGE)
    merge_request_iid = args[0]
    validate_numeric_id(merge_request_iid)
    max_results = args[1] if len(args) > 1 else "100"
    validate_positive_int(max_results, "max_results", MAX_POSITIVE_INT)
    data = request(
        "GET",
        f"{api_url}/projects/{project()}/merge_requests/{merge_request_iid}/notes?per_page={max_results}&sort=asc",
        quiet=bool(selected_fields),
    )
    if selected_fields and isinstance(data, list):
        notes = [
            cast(dict[str, Any], note)
            for note in cast(list[Any], data)
            if isinstance(note, dict)
            and not cast(dict[str, Any], note).get("system", False)
        ]
        print_fields(notes)


def cmd_pipeline_get(args: list[str]) -> None:
    """Get one pipeline."""
    if not args:
        die("usage: gitlab pipeline-get <pipeline-id>", EXIT_USAGE)
    pipeline_id = args[0]
    validate_numeric_id(pipeline_id)
    data = request(
        "GET",
        f"{api_url}/projects/{project()}/pipelines/{pipeline_id}",
        quiet=bool(selected_fields),
    )
    if selected_fields and data is not None:
        print_fields(data)


def cmd_pipeline_run(args: list[str]) -> None:
    """Trigger a pipeline for a branch or tag."""
    if not args:
        die("usage: gitlab pipeline-run <branch-or-tag>", EXIT_USAGE)
    validate_ref(args[0])
    request("POST", f"{api_url}/projects/{project()}/pipelines", {"ref": args[0]})


def cmd_pipeline_jobs(args: list[str]) -> None:
    """List pipeline jobs."""
    if not args:
        die("usage: gitlab pipeline-jobs <pipeline-id>", EXIT_USAGE)
    pipeline_id = args[0]
    validate_numeric_id(pipeline_id)
    data = request(
        "GET",
        f"{api_url}/projects/{project()}/pipelines/{pipeline_id}/jobs",
        quiet=bool(selected_fields),
    )
    if selected_fields and data is not None:
        print_fields(data)


def cmd_job_log(args: list[str]) -> None:
    """Print raw job trace output."""
    if not args:
        die("usage: gitlab job-log <job-id>", EXIT_USAGE)
    job_id = args[0]
    validate_numeric_id(job_id)
    url = f"{api_url}/projects/{project()}/jobs/{job_id}/trace"
    raw_bytes = _request_bytes(
        "GET",
        url,
        headers={"PRIVATE-TOKEN": gitlab_token},
        require_json=False,
        error_context="fetching job log",
    )
    log_text = _redact(raw_bytes.decode("utf-8", errors="replace"))
    if len(log_text) > MAX_LOG_BYTES:
        log_text = log_text[:MAX_LOG_BYTES] + "\n... [truncated]"
    print(log_text, end="")


COMMANDS: dict[str, Callable[[list[str]], None]] = {
    "mr-list": cmd_mr_list,
    "mr-get": cmd_mr_get,
    "mr-create": cmd_mr_create,
    "mr-update": cmd_mr_update,
    "mr-comment": cmd_mr_comment,
    "mr-notes": cmd_mr_notes,
    "pipeline-get": cmd_pipeline_get,
    "pipeline-run": cmd_pipeline_run,
    "pipeline-jobs": cmd_pipeline_jobs,
    "job-log": cmd_job_log,
}


def main() -> int:
    """Run the GitLab CLI."""
    try:
        arguments = parse_fields(sys.argv[1:])
        require_environment()

        if not arguments or arguments[0] not in COMMANDS:
            die(
                "usage: gitlab {mr-list|mr-get|mr-create|mr-update|mr-comment|"
                "mr-notes|pipeline-get|pipeline-run|pipeline-jobs|job-log} "
                "[args...]",
                EXIT_USAGE,
            )

        global _AUDIT_OP
        _AUDIT_OP = arguments[0]
        COMMANDS[arguments[0]](arguments[1:])
        return EXIT_SUCCESS
    except KeyboardInterrupt:
        print("Interrupted by user", file=sys.stderr)
        return 130
    except BrokenPipeError:
        devnull_fd = os.open(os.devnull, os.O_WRONLY)
        os.dup2(devnull_fd, sys.stdout.fileno())
        os.close(devnull_fd)
        return 141


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
