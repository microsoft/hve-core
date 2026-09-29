# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Tests for artifact_lookup: run discovery and published-bundle recovery."""

import json
from datetime import datetime, timedelta, timezone

import pytest
from artifact_lookup import (
    PAGE_SIZE,
    ArtifactLookupError,
    find_artifact,
    main,
    recover_site,
)

NOW = datetime(2026, 9, 28, tzinfo=timezone.utc)
SITE = "https://microsoft.github.io/hve-core/"


def _stamp(days_ago: float) -> str:
    return (NOW - timedelta(days=days_ago)).isoformat().replace("+00:00", "Z")


class FakeApi:
    """Serves paginated workflow runs and per-run artifacts like the REST API."""

    def __init__(self, runs, artifacts):
        self.runs = runs
        self.artifacts = artifacts
        self.calls = []

    def get(self, path, params=None):
        self.calls.append((path, dict(params or {})))
        page, size = params["page"], params["per_page"]
        if path.endswith("/runs"):
            assert params["status"] == "completed"
            return {"workflow_runs": self.runs[(page - 1) * size : page * size]}
        run_id = int(path.split("/")[3])
        items = self.artifacts.get(run_id, [])
        return {"artifacts": items[(page - 1) * size : page * size]}


def _run(run_id, days_ago, conclusion="success", branch="main"):
    return {
        "id": run_id,
        "created_at": _stamp(days_ago),
        "conclusion": conclusion,
        "head_branch": branch,
    }


def _bundle(run_id, expired=False, prefix="demo-material-site"):
    return {"id": run_id * 10, "name": f"{prefix}-{run_id}", "expired": expired}


class TestFindArtifact:
    def test_given_bundle_beyond_twenty_bundleless_runs_when_found_then_returned(self):
        runs = [_run(1000 - i, days_ago=i * 0.3) for i in range(150)]
        api = FakeApi(runs, {1000 - 140: [_bundle(1000 - 140)]})

        result = find_artifact(
            api, "demo-material-render.yml", "main", "demo-material-site", now=NOW
        )

        assert result["run-id"] == "860"
        assert result["artifact-id"] == "8600"
        assert any(call[1].get("page") == 2 for call in api.calls)

    def test_given_failed_run_with_bundle_when_found_then_used(self):
        api = FakeApi(
            [_run(7, 1, conclusion="failure"), _run(6, 2)],
            {7: [_bundle(7)], 6: [_bundle(6)]},
        )

        result = find_artifact(api, "w.yml", "main", "demo-material-site", now=NOW)

        assert result["run-id"] == "7"
        assert result["run-conclusion"] == "failure"

    def test_given_expired_newest_when_found_then_falls_back_to_older(self):
        api = FakeApi(
            [_run(9, 1), _run(8, 5)], {9: [_bundle(9, expired=True)], 8: [_bundle(8)]}
        )

        assert (
            find_artifact(api, "w.yml", "main", "demo-material-site", now=NOW)["run-id"]
            == "8"
        )

    def test_given_only_runs_past_retention_when_found_then_empty(self):
        api = FakeApi([_run(5, 95)], {5: [_bundle(5)]})

        assert find_artifact(api, "w.yml", "main", "demo-material-site", now=NOW) == {}

    def test_given_excluded_and_foreign_branch_runs_when_found_then_skipped(self):
        runs = [_run(4, 1), _run(3, 2, branch="feature"), _run(2, 3)]
        api = FakeApi(runs, {4: [_bundle(4)], 3: [_bundle(3)], 2: [_bundle(2)]})

        result = find_artifact(
            api, "w.yml", "main", "demo-material-site", exclude_run_id=4, now=NOW
        )

        assert result["run-id"] == "2"

    def test_given_artifact_on_second_artifact_page_when_found_then_returned(self):
        filler = [
            {"id": i, "name": f"other-{i}", "expired": False} for i in range(PAGE_SIZE)
        ]
        api = FakeApi(
            [_run(1, 1)], {1: filler + [_bundle(1, prefix="demo-material-index")]}
        )

        assert (
            find_artifact(api, "w.yml", "main", "demo-material-index", now=NOW)[
                "run-id"
            ]
            == "1"
        )

    def test_given_github_output_when_run_then_writes_keys(self, tmp_path, capsys):
        output = tmp_path / "out"
        api = FakeApi([_run(1, 1)], {1: [_bundle(1)]})

        code = main(
            [
                "find",
                "--workflow",
                "w.yml",
                "--artifact-prefix",
                "demo-material-site",
                "--branch",
                "main",
                "--github-output",
                str(output),
            ],
            api=api,
        )

        assert code == 0
        assert "artifact-id=10\nrun-id=1\n" in output.read_text(encoding="utf-8")
        assert json.loads(capsys.readouterr().out)["run-id"] == "1"


def _published(levels=("L100",)):
    index = {
        "schema_version": "demo-material-site/v1",
        "levels": {
            level: {
                "files": {
                    "pptx": f"{level}/hve-demo-{level}.pptx",
                    "mp4": f"{level}/hve-demo-{level}.mp4",
                    "page": f"{level}/index.html",
                }
            }
            for level in levels
        },
    }
    files = {f"{SITE}demo-material/index.json": json.dumps(index).encode()}
    for level in levels:
        for path in index["levels"][level]["files"].values():
            files[f"{SITE}demo-material/{path}"] = f"body of {path}".encode()
    return files


class TestRecoverSite:
    def test_given_published_bundle_when_recovered_then_every_listed_file_written(
        self, tmp_path
    ):
        files = _published(("L100", "L200"))

        result = recover_site(SITE, tmp_path, fetch=files.get)

        assert result["status"] == "recovered"
        assert result["levels"] == ["L100", "L200"]
        assert (
            tmp_path / "L200" / "hve-demo-L200.mp4"
        ).read_bytes() == b"body of L200/hve-demo-L200.mp4"
        assert (
            json.loads((tmp_path / "index.json").read_text())["schema_version"]
            == "demo-material-site/v1"
        )

    def test_given_nothing_published_when_recovered_then_none(self, tmp_path):
        assert recover_site(SITE, tmp_path, fetch={}.get) == {
            "status": "none",
            "levels": [],
        }
        assert not (tmp_path / "index.json").exists()

    def test_given_listed_file_missing_when_recovered_then_raises(self, tmp_path):
        files = _published()
        del files[f"{SITE}demo-material/L100/hve-demo-L100.mp4"]

        with pytest.raises(
            ArtifactLookupError, match="missing: L100/hve-demo-L100.mp4"
        ):
            recover_site(SITE, tmp_path, fetch=files.get)

    def test_given_traversal_in_published_index_when_recovered_then_raises(
        self, tmp_path
    ):
        index = {
            "schema_version": "demo-material-site/v1",
            "levels": {"L100": {"files": {"page": "../../etc/passwd"}}},
        }
        files = {f"{SITE}demo-material/index.json": json.dumps(index).encode()}

        with pytest.raises(ArtifactLookupError, match="unexpected file"):
            recover_site(SITE, tmp_path, fetch=files.get)

    @pytest.mark.parametrize("body", [b"not json", b'{"schema_version": "other"}'])
    def test_given_invalid_published_index_when_recovered_then_raises(
        self, tmp_path, body
    ):
        with pytest.raises(ArtifactLookupError):
            recover_site(
                SITE, tmp_path, fetch={f"{SITE}demo-material/index.json": body}.get
            )

    def test_given_plain_http_site_when_recovered_then_raises(self, tmp_path):
        with pytest.raises(ArtifactLookupError, match="https"):
            recover_site("http://example.com/", tmp_path, fetch={}.get)

    def test_given_index_only_when_recovered_then_skips_media(self, tmp_path):
        result = recover_site(SITE, tmp_path, fetch=_published().get, index_only=True)

        assert result["files"] == 1
        assert not (tmp_path / "L100").exists()
