#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
# /// script
# requires-python = ">=3.11"
# ///

from __future__ import annotations

"""GitLab REST API v4 client for merge requests, pipelines, and jobs.

Environment variables:
    GITLAB_URL: Required GitLab base URL.
    GITLAB_TOKEN: Required personal access token.
    GITLAB_PROJECT: Optional project id or path. Auto-detected from git remote.
"""

import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from typing import Any, Callable, NoReturn, cast

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_USAGE = 2

selected_fields: list[str] | None = None
gitlab_url = ""
gitlab_token = ""
api_url = ""

sys.dont_write_bytecode = True


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


def require_environment() -> None:
    """Load and validate required environment variables."""
    global api_url
    global gitlab_token
    global gitlab_url

    gitlab_url = os.environ.get("GITLAB_URL", "")
    gitlab_token = os.environ.get("GITLAB_TOKEN", "")

    if not gitlab_url:
        die("GITLAB_URL is not set", EXIT_USAGE)
    if not re.match(r"^https?://", gitlab_url):
        die("GITLAB_URL must start with https:// (or http:// for local dev)", EXIT_USAGE)
    if not gitlab_token:
        die("GITLAB_TOKEN is not set", EXIT_USAGE)

    api_url = gitlab_url.rstrip("/") + "/api/v4"


def strip_git_suffix(path: str) -> str:
    """Remove a trailing .git suffix when present."""
    if path.endswith(".git"):
        return path[:-4]
    return path


def project() -> str:
    """Resolve the target GitLab project from environment or git remote."""
    configured_project = os.environ.get("GITLAB_PROJECT", "")
    if configured_project:
        return urllib.parse.quote(configured_project, safe="")

    try:
        remote_url = subprocess.check_output(
            ["git", "remote", "get-url", "origin"],
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        die("GITLAB_PROJECT not set and no git remote found", EXIT_USAGE)

    if remote_url.startswith("git@"):
        path = remote_url.split(":", 1)[1]
    elif re.match(r"^https?://", remote_url):
        path = re.sub(r"^https?://[^/]*/", "", remote_url)
    else:
        die(f"cannot parse git remote URL: {remote_url}", EXIT_USAGE)

    path = strip_git_suffix(path)
    if not path:
        die(f"cannot extract project path from remote: {remote_url}", EXIT_USAGE)
    return urllib.parse.quote(path, safe="")


def validate_numeric_id(value: str) -> None:
    """Validate that a CLI argument is a numeric identifier."""
    if not re.match(r"^\d+$", value):
        die(f"expected numeric ID, got: {value}", EXIT_USAGE)


def validate_positive_int(value: str, label: str = "value") -> None:
    """Validate that a CLI argument is a positive integer string."""
    if not re.match(r"^\d+$", value):
        die(f"{label} must be a positive integer, got: {value}", EXIT_USAGE)


def request(method: str, url: str, data: object | None = None, quiet: bool = False) -> object | None:
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
    body = json.dumps(data).encode() if data is not None else None
    request_obj = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request_obj) as response:
            raw = response.read().decode()
    except urllib.error.HTTPError as error:
        raw = error.read().decode()
        try:
            parsed_error = json.loads(raw)
            print(parsed_error.get("message", parsed_error.get("error", parsed_error)), file=sys.stderr)
        except (json.JSONDecodeError, ValueError):
            print(raw, file=sys.stderr)
        die(f"HTTP {error.code} from {method} {url}")

    if not raw.strip():
        return None

    try:
        parsed = json.loads(raw)
    except (json.JSONDecodeError, ValueError):
        print(raw)
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
            print("\t".join(extract_field(item, field_name) for field_name in selected_fields))
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
    max_results = args[1] if len(args) > 1 else "20"
    validate_positive_int(max_results, "max_results")
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
    raw_payload = args[0] if args else sys.stdin.read().strip()
    usage = "usage: gitlab mr-create <json> or pipe JSON to stdin"
    if not raw_payload:
        die(usage, EXIT_USAGE)
    request("POST", f"{api_url}/projects/{project()}/merge_requests", load_json_payload(raw_payload, usage))


def cmd_mr_update(args: list[str]) -> None:
    """Update a merge request from JSON input."""
    if not args:
        die("usage: gitlab mr-update <mr-iid> <json>", EXIT_USAGE)
    merge_request_iid = args[0]
    validate_numeric_id(merge_request_iid)
    raw_payload = args[1] if len(args) > 1 else sys.stdin.read().strip()
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
    body = args[1] if len(args) > 1 else sys.stdin.read().strip()
    if not body:
        die("usage: gitlab mr-comment <mr-iid> <body> or pipe body to stdin", EXIT_USAGE)
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
    validate_positive_int(max_results, "max_results")
    data = request(
        "GET",
        f"{api_url}/projects/{project()}/merge_requests/{merge_request_iid}/notes?per_page={max_results}&sort=asc",
        quiet=bool(selected_fields),
    )
    if selected_fields and isinstance(data, list):
        notes = [
            cast(dict[str, Any], note)
            for note in cast(list[Any], data)
            if isinstance(note, dict) and not cast(dict[str, Any], note).get("system", False)
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
    request_obj = urllib.request.Request(url, headers={"PRIVATE-TOKEN": gitlab_token}, method="GET")
    try:
        with urllib.request.urlopen(request_obj) as response:
            print(response.read().decode())
    except urllib.error.HTTPError as error:
        print(error.read().decode(), file=sys.stderr)
        die(f"HTTP {error.code} fetching job log")


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
    arguments = parse_fields(sys.argv[1:])
    require_environment()

    if not arguments or arguments[0] not in COMMANDS:
        die(
            "usage: gitlab {mr-list|mr-get|mr-create|mr-update|mr-comment|mr-notes|pipeline-get|pipeline-run|pipeline-jobs|job-log} [args...]",
            EXIT_USAGE,
        )

    COMMANDS[arguments[0]](arguments[1:])
    return EXIT_SUCCESS


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("Interrupted by user", file=sys.stderr)
        raise SystemExit(130)
    except BrokenPipeError:
        raise SystemExit(EXIT_FAILURE)