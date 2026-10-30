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
        --artifact-prefix demo-material-site-v2 [--branch main] \
        [--exclude-run-id ID] [--github-output "$GITHUB_OUTPUT"]
    python artifact_lookup.py recover --target DIR [--site-url URL] [--index-only]
    python artifact_lookup.py retry-levels --index FILE [--github-output FILE]

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
import hashlib
import json
import os
import re
import shutil
import stat
import sys
import tempfile
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
SITE_SCHEMA = "demo-material-site/v2"
CONTENT_SCHEMA = "demo-material-content/v2"
SITE_FILE = re.compile(
    r"L[1-4]00/(hve-demo-L[1-4]00\.(?:raw\.mp4|mp4|vtt|html)|index\.html"
    r"|render-result\.json|source-register\.md|manifest\.yml"
    r"|html-deck-(?:build|check)\.json|open-captions\.json)"
)
EVIDENCE_FILES = (
    "render-result.json",
    "html-deck-build.json",
    "html-deck-check.json",
    "open-captions.json",
    "manifest.yml",
    "source-register.md",
)
LEVELS = ("L100", "L200", "L300", "L400")
PUBLISHED_FILE_KEYS = ("mp4", "vtt", "html", "page")


class ArtifactLookupError(RuntimeError):
    """Raised when an API call, download, or published bundle is invalid."""


def safe_path(root: Path, relative: str = "") -> Path:
    """Reject traversal, symlinks, reparse points and special filesystem nodes."""
    root = root.absolute()
    path = root / relative
    if not path.is_relative_to(root) or ".." in path.parts:
        raise ArtifactLookupError(f"unsafe bundle path: {relative}")
    for candidate in (*reversed(path.parents), path):
        try:
            info = candidate.lstat()
        except FileNotFoundError:
            continue
        if (
            stat.S_ISLNK(info.st_mode)
            or getattr(info, "st_file_attributes", 0) & 0x400
            or not (stat.S_ISDIR(info.st_mode) or stat.S_ISREG(info.st_mode))
        ):
            raise ArtifactLookupError(f"non-regular bundle path: {candidate.name}")
    return path


def file_hash(path: Path) -> str:
    """Hash regular bundle content without loading media into memory."""
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def delivery_names(level: str) -> tuple[str, ...]:
    """Return the complete fixed HTML/media/evidence delivery inventory."""
    if level not in LEVELS:
        raise ArtifactLookupError("invalid delivery level")
    return tuple(
        f"hve-demo-{level}.{ext}" for ext in ("html", "mp4", "vtt", "raw.mp4")
    ) + ("index.html", *EVIDENCE_FILES)


def valid_entry(level: str, entry: object) -> bool:
    """Recognize current delivery metadata without accepting old-format files."""
    if level not in LEVELS or not isinstance(entry, dict):
        return False
    expected = {
        ext: f"{level}/hve-demo-{level}.{ext}" for ext in ("mp4", "vtt", "html")
    }
    expected["page"] = f"{level}/index.html"
    hashes = entry.get("sha256")
    names = {f"{level}/{name}" for name in delivery_names(level)}
    return (
        entry.get("renderer") == "hve-slides"
        and entry.get("format") == "html"
        and entry.get("render_schema_version") == 2
        and entry.get("manifest_schema_version") == 6
        and entry.get("files") == expected
        and isinstance(hashes, dict)
        and set(hashes) == names
        and all(
            isinstance(value, str) and re.fullmatch(r"[0-9a-f]{64}", value)
            for value in hashes.values()
        )
        and isinstance(entry.get("source_sha"), str)
        and re.fullmatch(r"[0-9a-f]{40}", entry["source_sha"]) is not None
        and all(
            re.fullmatch(r"[0-9]+", str(entry.get(key, "")))
            for key in ("author_run_id", "render_run_id")
        )
    )


def validate_delivery(root: Path, level: str) -> dict:
    """Require current silent HTML/media evidence before bundling or restaging."""
    paths = {name: safe_path(root, name) for name in delivery_names(level)}
    if any(not path.is_file() for path in paths.values()):
        raise ArtifactLookupError(f"incomplete delivery: {level}")
    result = json.loads(paths["render-result.json"].read_text(encoding="utf-8"))
    required = {"T-04", "T-07", "T-08", "T-09", "T-10", "T-11"}
    if isinstance(result, dict) and result.get("capture_profile") == "live":
        required |= {"T-05", "T-06"}
    checks = result.get("checks") if isinstance(result, dict) else None
    if (
        not isinstance(checks, dict)
        or result.get("schema_version") != 2
        or result.get("renderer") != "hve-slides"
        or result.get("format") != "html"
        or result.get("manifest_schema_version") != 6
        or result.get("level") != level
        or result.get("manifest_sha256") != file_hash(paths["manifest.yml"])
        or result.get("ok") is not True
        or result.get("narration_engine") != "none"
        or result.get("timing_basis") != "notes-word-count"
        or result.get("capture_profile") not in ("live", "deck-export")
        or not required.issubset(checks)
        or any(
            not isinstance(value, dict) or value.get("result") != "pass"
            for value in checks.values()
        )
    ):
        raise ArtifactLookupError(f"non-pass or incompatible render evidence: {level}")
    browser = json.loads(paths["html-deck-check.json"].read_text(encoding="utf-8"))
    build = json.loads(paths["html-deck-build.json"].read_text(encoding="utf-8"))
    captions = json.loads(paths["open-captions.json"].read_text(encoding="utf-8"))
    if not all(isinstance(value, dict) for value in (browser, build, captions)):
        raise ArtifactLookupError("evidence must be JSON objects")
    ids = build.get("slide_ids")
    frames = browser.get("frames")
    if (
        build.get("schema_version") != 2
        or build.get("renderer") != "hve-slides"
        or build.get("format") != "html"
        or not isinstance(ids, list)
        or not ids
        or not all(isinstance(item, str) for item in ids)
        or len(ids) != len(set(ids))
        or browser.get("schema_version") != 2
        or browser.get("renderer") != "hve-slides"
        or browser.get("format") != "html"
        or browser.get("result") != "pass"
        or browser.get("html_sha256") != file_hash(paths[f"hve-demo-{level}.html"])
        or browser.get("build_sha256") != file_hash(paths["html-deck-build.json"])
        or browser.get("slide_ids") != ids
        or not isinstance(frames, list)
        or len(frames) != len(ids)
        or any(
            browser.get(key)
            for key in ("errors", "external_requests", "overflowing_slides")
        )
    ):
        raise ArtifactLookupError("HTML/frame evidence is missing or stale")
    for identity, frame in zip(ids, frames, strict=True):
        if (
            not isinstance(identity, str)
            or not re.fullmatch(r"slide-[1-9][0-9]*", identity)
            or not isinstance(frame, dict)
            or frame.get("slide_id") != identity
            or (frame.get("width"), frame.get("height")) != (1920, 1080)
            or not re.fullmatch(r"[0-9a-f]{64}", str(frame.get("sha256", "")))
        ):
            raise ArtifactLookupError("invalid ordered frame evidence")
    if (
        captions.get("result") != "pass"
        or captions.get("video_sha256") != file_hash(paths[f"hve-demo-{level}.mp4"])
        or captions.get("source_video_sha256")
        != file_hash(paths[f"hve-demo-{level}.raw.mp4"])
        or captions.get("captions_sha256") != file_hash(paths[f"hve-demo-{level}.vtt"])
    ):
        raise ArtifactLookupError("caption evidence is missing or stale")
    return result


def validate_site(root: Path) -> dict:
    """Refuse incompatible, empty, incomplete or hash-mismatched site bundles."""
    index = json.loads(safe_path(root, "index.json").read_text(encoding="utf-8"))
    entries = index.get("levels") if isinstance(index, dict) else None
    if (
        not isinstance(entries, dict)
        or not entries
        or index.get("schema_version") != SITE_SCHEMA
    ):
        raise ArtifactLookupError(
            "incompatible or empty site; preserve existing media and regenerate"
        )
    for level, entry in entries.items():
        if not valid_entry(level, entry):
            raise ArtifactLookupError(f"incomplete site metadata: {level}")
        for relative, expected in entry["sha256"].items():
            path = safe_path(root, relative)
            if not path.is_file() or file_hash(path) != expected:
                raise ArtifactLookupError(
                    f"missing or mismatched site file: {relative}"
                )
        validate_delivery(safe_path(root, level), level)
    for path in root.rglob("*"):
        safe_path(root, path.relative_to(root).as_posix())
        if (
            path.is_file()
            and path.relative_to(root).as_posix() != "index.json"
            and not SITE_FILE.fullmatch(path.relative_to(root).as_posix())
        ):
            raise ArtifactLookupError(f"unexpected file in site: {path.name}")
    return index


def assemble_site(
    site: Path, renders: Path, source_sha: str, author_run_id: str, render_run_id: str
) -> dict:
    """Merge validated levels without discarding previous compatible media."""
    site = safe_path(site)
    renders = safe_path(renders)
    index_path = safe_path(site, "index.json")
    if index_path.exists():
        index = validate_site(site)
    else:
        if site.exists() and any(site.iterdir()):
            raise ArtifactLookupError(
                "Unindexed site files exist; preserve them before migration"
            )
        index = {"schema_version": SITE_SCHEMA, "levels": {}}
    now = datetime.now(timezone.utc).isoformat(timespec="seconds")
    for candidate in sorted(renders.iterdir() if renders.is_dir() else ()):
        safe_path(renders, candidate.name)
        if candidate.name not in LEVELS or not candidate.is_dir():
            raise ArtifactLookupError("unexpected render directory")
        level = candidate.name
        attempt = {
            "source_sha": source_sha,
            "author_run_id": author_run_id,
            "render_run_id": render_run_id,
            "at": now,
        }
        try:
            result = validate_delivery(candidate, level)
        except (ArtifactLookupError, OSError, ValueError):
            if level in index["levels"]:
                index["levels"][level]["last_failed_attempt"] = attempt
            continue
        entry = {
            **attempt,
            "rendered_at": now,
            "renderer": "hve-slides",
            "format": "html",
            "render_schema_version": 2,
            "manifest_schema_version": 6,
            "narration_engine": "none",
            "timing_basis": "notes-word-count",
            "capture_profile": result["capture_profile"],
            "measured_duration_minutes": result.get("measured_duration_minutes"),
            "files": {
                **{
                    ext: f"{level}/hve-demo-{level}.{ext}"
                    for ext in ("mp4", "vtt", "html")
                },
                "page": f"{level}/index.html",
            },
            "sha256": {
                f"{level}/{name}": file_hash(candidate / name)
                for name in delivery_names(level)
            },
        }
        if not valid_entry(level, entry):
            raise ArtifactLookupError("render provenance is invalid")
        target = safe_path(site, level)
        target.mkdir(parents=True, exist_ok=True)
        stage = Path(tempfile.mkdtemp(prefix=".delivery-", dir=site))
        installed = []
        saved = set()
        names = delivery_names(level)
        try:
            next_index = {
                **index,
                "levels": {**index["levels"], level: entry},
                "generated_at": now,
                "render_run_id": render_run_id,
            }
            (stage / "next-index.json").write_text(
                json.dumps(next_index, indent=2) + "\n", encoding="utf-8"
            )
            for name in names:
                shutil.copyfile(safe_path(candidate, name), stage / f"new-{name}")
                if safe_path(target, name).exists():
                    shutil.copyfile(target / name, stage / f"old-{name}")
                    saved.add(name)
            try:
                for name in names:
                    os.replace(stage / f"new-{name}", safe_path(target, name))
                    installed.append(name)
                os.replace(stage / "next-index.json", index_path)
            except (OSError, KeyboardInterrupt):
                for name in reversed(installed):
                    if name in saved:
                        os.replace(stage / f"old-{name}", target / name)
                    else:
                        (target / name).unlink()
                raise
        finally:
            for name in names:
                (stage / f"new-{name}").unlink(missing_ok=True)
                (stage / f"old-{name}").unlink(missing_ok=True)
            (stage / "next-index.json").unlink(missing_ok=True)
            stage.rmdir()
        index = next_index
    if not index["levels"]:
        raise ArtifactLookupError(
            "No valid delivery; refusing an empty site publication"
        )
    # Records attempted author runs even when no level is recorded, so a scheduled
    # pickup does not select the same author run again.
    if re.fullmatch(r"[0-9]+", author_run_id):
        attempted = str(index.get("latest_attempted_author_run_id", ""))
        if not re.fullmatch(r"[0-9]+", attempted) or int(author_run_id) > int(
            attempted
        ):
            index["latest_attempted_author_run_id"] = author_run_id
    index.update(generated_at=now, render_run_id=render_run_id)
    descriptor, temporary = tempfile.mkstemp(prefix=".site-index-", dir=site)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            stream.write(json.dumps(index, indent=2) + "\n")
        os.replace(temporary, index_path)
    finally:
        Path(temporary).unlink(missing_ok=True)
    return validate_site(site)


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
    if (
        isinstance(index, dict)
        and index.get("schema_version") == "demo-material-site/v1"
        and index_only
    ):
        target = safe_path(target)
        target.mkdir(parents=True, exist_ok=True)
        safe_path(target, "index.json").write_bytes(body)
        return {"status": "obsolete", "levels": list(LEVELS), "files": 1}
    if not isinstance(index, dict) or index.get("schema_version") != SITE_SCHEMA:
        raise ArtifactLookupError("published index.json has an unknown schema")

    required: list[str] = []
    levels = []
    entries = index.get("levels")
    if not isinstance(entries, dict) or not entries:
        raise ArtifactLookupError("published site is empty or incomplete")
    for level, entry in sorted(entries.items()):
        if not valid_entry(level, entry):
            raise ArtifactLookupError(
                "published index lists an unexpected file or incomplete metadata: "
                f"{level}"
            )
        levels.append(level)
        required += list(entry["sha256"])
    for path in required:
        if not SITE_FILE.fullmatch(path):
            raise ArtifactLookupError(
                f"published index lists an unexpected file: {path}"
            )

    target = safe_path(target)
    if not index_only and target.exists() and any(target.iterdir()):
        raise ArtifactLookupError(
            "Recovery requires an empty target; "
            "preserve existing media and choose a new directory"
        )
    target.mkdir(parents=True, exist_ok=True)
    if index_only:
        safe_path(target, "index.json").write_bytes(body)
        return {"status": "recovered", "levels": levels, "files": 1}
    written = 1
    for path in dict.fromkeys(required):
        content = fetch(base + path)
        if content is None:
            raise ArtifactLookupError(f"published file is missing: {path}")
        if (
            hashlib.sha256(content).hexdigest()
            != entries[path.split("/")[0]]["sha256"][path]
        ):
            raise ArtifactLookupError(f"published file hash mismatch: {path}")
        destination = safe_path(target, path)
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(content)
        written += 1
    safe_path(target, "index.json").write_bytes(body)
    validate_site(target)
    return {"status": "recovered", "levels": levels, "files": written}


def default_site_url(repository: str) -> str:
    """Return the GitHub Pages project URL for ``owner/name``."""
    if not re.fullmatch(r"[\w.-]+/[\w.-]+", repository or ""):
        raise ArtifactLookupError("GITHUB_REPOSITORY must be owner/name")
    owner, name = repository.split("/")
    return f"https://{owner.lower()}.github.io/{name}/"


def retry_levels(index: dict) -> list[str]:
    """Return failed or unpublished levels that need fresh authored content."""
    if isinstance(index, dict) and index.get("schema_version") not in (
        None,
        SITE_SCHEMA,
        "demo-material-site/v1",
    ):
        raise ArtifactLookupError("render index has an unknown schema")
    recorded = (
        index.get("levels")
        if isinstance(index, dict) and index.get("schema_version") == SITE_SCHEMA
        else None
    )
    recorded = recorded if isinstance(recorded, dict) else {}
    selected = []
    for level in LEVELS:
        entry = recorded.get(level)
        entry = entry if isinstance(entry, dict) else {}
        complete = valid_entry(level, entry)
        if not complete or isinstance(entry.get("last_failed_attempt"), dict):
            selected.append(level)
    return selected


def _write_outputs(path: str | None, values: dict) -> None:
    if not path:
        return
    with open(path, "a", encoding="utf-8") as out:
        for key, value in values.items():
            if any(char in str(value) for char in ("\r", "\n")):
                raise ArtifactLookupError("workflow outputs must be single-line")
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
    retry = sub.add_parser(
        "retry-levels", help="Print failed or unpublished levels from an index"
    )
    retry.add_argument("--index", type=Path, required=True)
    retry.add_argument("--github-output")
    validate = sub.add_parser(
        "validate-site", help="Validate a complete current bundle"
    )
    validate.add_argument("--target", type=Path, required=True)
    assemble = sub.add_parser(
        "assemble-site", help="Merge only validated current deliveries"
    )
    assemble.add_argument("--target", type=Path, required=True)
    assemble.add_argument("--renders", type=Path, required=True)
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
        elif args.command == "recover":
            site_url = args.site_url or default_site_url(
                os.environ.get("GITHUB_REPOSITORY", "")
            )
            result = recover_site(site_url, args.target, index_only=args.index_only)
            result = {**result, "levels": " ".join(result["levels"])}
        elif args.command == "validate-site":
            result = {"levels": list(validate_site(args.target)["levels"])}
        elif args.command == "assemble-site":
            result = assemble_site(
                args.target,
                args.renders,
                os.environ.get("SOURCE_SHA", ""),
                os.environ.get("AUTHOR_RUN_ID", ""),
                os.environ.get("RENDER_RUN_ID", ""),
            )
        else:
            if args.index.is_file():
                index = json.loads(args.index.read_text(encoding="utf-8"))
                if not isinstance(index, dict) or index.get("schema_version") not in (
                    SITE_SCHEMA,
                    "demo-material-site/v1",
                ):
                    raise ArtifactLookupError("render index has an unknown schema")
            else:
                index = {}
            result = {"levels": " ".join(retry_levels(index))}
    except (ArtifactLookupError, OSError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return EXIT_FAILURE
    _write_outputs(getattr(args, "github_output", None), result)
    print(json.dumps(result))
    return EXIT_SUCCESS


if __name__ == "__main__":
    sys.exit(main())
