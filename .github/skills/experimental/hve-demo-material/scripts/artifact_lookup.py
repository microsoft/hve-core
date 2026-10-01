#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Find the newest demo-material artifact, or recover the published bundle.

``find`` pages through every completed run of a workflow on a branch back to
the artifact retention window, whatever each run concluded, and returns the
newest unexpired artifact named ``<prefix>-<run id>``. A run whose matrix
partly failed still uploads a valid bundle, and a fixed first page of runs can
miss an older bundle, so neither the conclusion nor a page size bounds the
search.

``recover`` downloads the bundle that is currently published on the site,
using its ``index.json`` as the file list. GitHub Pages replaces the whole
site on every deployment, so when no artifact is left this is the only copy,
and restaging it keeps an unrelated docs deployment from deleting it.

Uses only the standard library, so any job can run it with ``python3``.

Usage::

    python artifact_lookup.py find --workflow demo-material-render.yml \
        --artifact-prefix demo-material-site [--branch main] \
        [--exclude-run-id ID] [--github-output "$GITHUB_OUTPUT"]
    python artifact_lookup.py recover --target DIR [--site-url URL] [--index-only]

Both read ``GITHUB_REPOSITORY``; ``find`` also reads ``GITHUB_TOKEN`` and
``GITHUB_API_URL``. The branch defaults to the repository default branch and
the site URL to the repository's GitHub Pages URL.

Exit codes:
    0 - success; ``find`` prints ``{}`` when no artifact exists and
        ``recover`` prints ``"status": "none"`` when nothing is published
    1 - an API or download failed, or published content was invalid
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Callable

EXIT_SUCCESS = 0
EXIT_FAILURE = 1

ARTIFACT_RETENTION_DAYS = 90
PAGE_SIZE = 100
REQUEST_TIMEOUT_S = 60
SITE_SCHEMA = "demo-material-site/v1"
SITE_FILE = re.compile(
    r"^L[1-4]00/(hve-demo-L[1-4]00\.(pptx|mp4|vtt|html)|index\.html"
    r"|render-result\.json|source-register\.md)$"
)
OPTIONAL_LEVEL_FILES = ("render-result.json", "source-register.md")


class ArtifactLookupError(RuntimeError):
    """Raised when an API call, download, or published bundle is invalid."""


class GitHubApi:
    """Minimal authenticated GitHub REST client."""

    def __init__(self, token: str, repository: str, api_url: str) -> None:
        if not re.fullmatch(r"[\w.-]+/[\w.-]+", repository or ""):
            raise ArtifactLookupError("GITHUB_REPOSITORY must be owner/name")
        self._token = token
        self._base = f"{api_url.rstrip('/')}/repos/{repository}"

    def get(self, path: str, params: dict | None = None) -> dict:
        query = f"?{urllib.parse.urlencode(params)}" if params else ""
        request = urllib.request.Request(
            f"{self._base}{path}{query}",
            headers={
                "Accept": "application/vnd.github+json",
                "Authorization": f"Bearer {self._token}",
                "X-GitHub-Api-Version": "2022-11-28",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=REQUEST_TIMEOUT_S) as response:
                return json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as error:
            if error.code == 404:
                return {}
            raise ArtifactLookupError(
                f"GitHub API {path} returned {error.code}"
            ) from error
        except (urllib.error.URLError, OSError, json.JSONDecodeError) as error:
            raise ArtifactLookupError(f"GitHub API {path} failed: {error}") from error


def _parse_time(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def completed_runs(
    api, workflow: str, branch: str, now: datetime, max_age_days: int
) -> list[dict]:
    """Return completed runs newest first, back to ``max_age_days`` ago."""
    oldest = now - timedelta(days=max_age_days)
    runs: list[dict] = []
    page = 1
    while True:
        data = api.get(
            f"/actions/workflows/{workflow}/runs",
            {
                "branch": branch,
                "status": "completed",
                "per_page": PAGE_SIZE,
                "page": page,
            },
        )
        batch = data.get("workflow_runs") or []
        runs += [run for run in batch if _parse_time(run["created_at"]) >= oldest]
        if len(batch) < PAGE_SIZE or _parse_time(batch[-1]["created_at"]) < oldest:
            return runs
        page += 1


def run_artifacts(api, run_id: int) -> list[dict]:
    """Return every artifact of a run."""
    artifacts: list[dict] = []
    page = 1
    while True:
        data = api.get(
            f"/actions/runs/{run_id}/artifacts", {"per_page": PAGE_SIZE, "page": page}
        )
        batch = data.get("artifacts") or []
        artifacts += batch
        if len(batch) < PAGE_SIZE:
            return artifacts
        page += 1


def find_artifact(
    api,
    workflow: str,
    branch: str,
    prefix: str,
    exclude_run_id: int | None = None,
    now: datetime | None = None,
    max_age_days: int = ARTIFACT_RETENTION_DAYS,
) -> dict:
    """Return the newest unexpired ``<prefix>-<run id>`` artifact, or ``{}``."""
    now = now or datetime.now(timezone.utc)
    for run in completed_runs(api, workflow, branch, now, max_age_days):
        if run["id"] == exclude_run_id or run.get("head_branch") != branch:
            continue
        name = f"{prefix}-{run['id']}"
        matches = [
            artifact
            for artifact in run_artifacts(api, run["id"])
            if artifact.get("name") == name and not artifact.get("expired")
        ]
        if len(matches) == 1:
            return {
                "artifact-id": str(matches[0]["id"]),
                "run-id": str(run["id"]),
                "created-at": matches[0].get("created_at") or run["created_at"],
                "run-conclusion": run.get("conclusion") or "",
            }
    return {}


def fetch_url(url: str) -> bytes | None:
    """Return the body at ``url``, or ``None`` when it does not exist."""
    try:
        with urllib.request.urlopen(url, timeout=REQUEST_TIMEOUT_S) as response:
            return response.read()
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return None
        raise ArtifactLookupError(f"{url} returned {error.code}") from error
    except (urllib.error.URLError, OSError) as error:
        raise ArtifactLookupError(f"{url} failed: {error}") from error


def recover_site(
    site_url: str,
    target: Path,
    fetch: Callable[[str], bytes | None] = fetch_url,
    index_only: bool = False,
) -> dict:
    """Download the published bundle into ``target`` and describe the result.

    Returns ``{"status": "none"}`` when the site publishes no demo material.
    Raises ``ArtifactLookupError`` when the published index is invalid or a file it
    lists cannot be downloaded, so a caller never stages a partial bundle.
    """
    if not site_url.startswith("https://"):
        raise ArtifactLookupError("site URL must use https")
    base = site_url.rstrip("/") + "/demo-material/"
    body = fetch(base + "index.json")
    if body is None:
        return {"status": "none", "levels": []}
    try:
        index = json.loads(body.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ArtifactLookupError(
            f"published index.json is not JSON: {error}"
        ) from error
    if not isinstance(index, dict) or index.get("schema_version") != SITE_SCHEMA:
        raise ArtifactLookupError("published index.json has an unknown schema")

    required: list[str] = []
    optional: list[str] = []
    levels = []
    for level, entry in sorted((index.get("levels") or {}).items()):
        files = entry.get("files") if isinstance(entry, dict) else None
        if not isinstance(files, dict) or not re.fullmatch(r"L[1-4]00", level):
            continue
        levels.append(level)
        required += [str(path) for path in files.values()]
        optional += [f"{level}/{name}" for name in OPTIONAL_LEVEL_FILES]
    for path in required + optional:
        if not SITE_FILE.match(path):
            raise ArtifactLookupError(
                f"published index lists an unexpected file: {path}"
            )

    target.mkdir(parents=True, exist_ok=True)
    (target / "index.json").write_bytes(body)
    if index_only:
        return {"status": "recovered", "levels": levels, "files": 1}
    written = 1
    for path in dict.fromkeys(required + optional):
        content = fetch(base + path)
        if content is None:
            if path in required:
                raise ArtifactLookupError(f"published file is missing: {path}")
            continue
        destination = target / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(content)
        written += 1
    return {"status": "recovered", "levels": levels, "files": written}


def default_site_url(repository: str) -> str:
    """Return the GitHub Pages project URL for ``owner/name``."""
    if not re.fullmatch(r"[\w.-]+/[\w.-]+", repository or ""):
        raise ArtifactLookupError("GITHUB_REPOSITORY must be owner/name")
    owner, name = repository.split("/")
    return f"https://{owner.lower()}.github.io/{name}/"


def _write_outputs(path: str | None, values: dict) -> None:
    if not path:
        return
    with open(path, "a", encoding="utf-8") as out:
        for key, value in values.items():
            out.write(f"{key}={value}\n")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)
    find = sub.add_parser("find", help="Print the newest unexpired artifact")
    find.add_argument("--workflow", required=True)
    find.add_argument("--artifact-prefix", required=True)
    find.add_argument("--branch", help="Default: the repository default branch")
    find.add_argument("--exclude-run-id", type=int)
    find.add_argument("--max-age-days", type=int, default=ARTIFACT_RETENTION_DAYS)
    find.add_argument("--github-output")
    recover = sub.add_parser("recover", help="Download the published bundle")
    recover.add_argument(
        "--site-url", help="Default: the GitHub Pages URL of GITHUB_REPOSITORY"
    )
    recover.add_argument("--target", type=Path, required=True)
    recover.add_argument("--index-only", action="store_true")
    recover.add_argument("--github-output")
    return parser


def main(argv: list[str] | None = None, api=None) -> int:
    args = build_parser().parse_args(argv)
    try:
        if args.command == "find":
            api = api or GitHubApi(
                os.environ.get("GITHUB_TOKEN", ""),
                os.environ.get("GITHUB_REPOSITORY", ""),
                os.environ.get("GITHUB_API_URL", "https://api.github.com"),
            )
            branch = args.branch or api.get("").get("default_branch")
            if not branch:
                raise ArtifactLookupError("cannot resolve the default branch")
            result = find_artifact(
                api,
                args.workflow,
                branch,
                args.artifact_prefix,
                args.exclude_run_id,
                max_age_days=args.max_age_days,
            )
        else:
            site_url = args.site_url or default_site_url(
                os.environ.get("GITHUB_REPOSITORY", "")
            )
            result = recover_site(site_url, args.target, index_only=args.index_only)
            result = {**result, "levels": " ".join(result["levels"])}
    except ArtifactLookupError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return EXIT_FAILURE
    _write_outputs(args.github_output, result)
    print(json.dumps(result))
    return EXIT_SUCCESS


if __name__ == "__main__":
    sys.exit(main())
