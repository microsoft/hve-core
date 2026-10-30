# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Tests for artifact_lookup: run discovery and published-bundle recovery."""

import hashlib
import json
import os
import urllib.error
from datetime import datetime, timedelta, timezone

import artifact_lookup
import pytest
from artifact_lookup import (
    PAGE_SIZE,
    ArtifactLookupError,
    GitHubApi,
    assemble_site,
    fetch_url,
    find_artifact,
    main,
    recover_site,
    retry_levels,
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


def _resolve_steps():
    from pathlib import Path

    import yaml

    workflow = (
        Path(__file__).resolve().parents[5]
        / ".github/workflows/demo-material-render.yml"
    )
    return yaml.safe_load(workflow.read_text(encoding="utf-8"))["jobs"]["resolve"][
        "steps"
    ]


def _author_run(run_id):
    return {
        "id": run_id,
        "status": "completed",
        "conclusion": "success",
        "path": ".github/workflows/demo-material-author.lock.yml",
        "head_branch": "main",
        "head_sha": "a" * 40,
    }


def _run_resolve(context, author_runs, content_run_ids, env):
    """Run the resolve script under Node with a stubbed GitHub client."""
    import os
    import shutil
    import subprocess

    node = shutil.which("node")
    if not node:
        pytest.skip("Existing Node is required for contained workflow routing")
    script = next(
        step["with"]["script"]
        for step in _resolve_steps()
        if step.get("id") == "resolve"
    )
    runs = {run["id"]: run for run in author_runs}
    harness = (
        "const output = {}; const core = {"
        "setOutput:(key,value)=>output[key]=value,notice:()=>{}};"
        f"const context={json.dumps(context)};"
        f"const runs={json.dumps(runs)};"
        f"const contentRuns=new Set({json.dumps(content_run_ids)});"
        'const github={rest:{repos:{get:async()=>({data:{default_branch:"main"}})},'
        "actions:{listWorkflowRunArtifacts:()=>{},"
        "listWorkflowRuns:async()=>({data:{workflow_runs:Object.values(runs).sort((a,b)=>b.id-a.id)}}),"
        "getWorkflowRun:async({run_id})=>({data:runs[run_id]})}},"
        "paginate:async(_,{run_id})=>contentRuns.has(run_id)"
        "?[{id:run_id*10,name:`demo-material-content-v2-${run_id}`,expired:false}]:[]};"
        "const AsyncFunction=Object.getPrototypeOf(async()=>{}).constructor;"
        f'new AsyncFunction("github","context","core",{json.dumps(script)})'
        "(github,context,core)"
        ".then(()=>console.log(JSON.stringify(output))).catch(error=>{console.error(error);process.exit(1)});"
    )
    result = subprocess.run(
        [node, "-e", harness],
        capture_output=True,
        text=True,
        check=True,
        env={
            # Node cannot initialize on Windows without SYSTEMROOT.
            **{k: os.environ[k] for k in ("SYSTEMROOT",) if k in os.environ},
            "DISPATCH_AUTHOR_RUN_ID": "",
            "RETRY_LEVELS": "",
            "REFRESH_AFTER_DAYS": "60",
            "PREVIOUS_CREATED_AT": datetime.now(timezone.utc).isoformat(),
            "PUBLISHED_STATUS": "",
            "SCHEDULE": "",
            "RENDER_INDEX": "",
            **env,
        },
    )
    return json.loads(result.stdout)


class TestRenderEventRouting:
    @pytest.mark.parametrize(
        "author_run_id,expected", [("7", "render"), ("", "refresh")]
    )
    def test_given_usable_bundle_and_absent_index_when_resolved_then_skips_retry_fetch(
        self, author_run_id, expected
    ):
        steps = _resolve_steps()
        retry_names = {
            "Find the latest render index",
            "Download the latest render index",
            "Recover the published render index",
            "Select failed or unpublished levels",
        }
        retry_steps = [step for step in steps if step["name"] in retry_names]
        assert len(retry_steps) == 4
        assert all(
            "github.event_name == 'schedule'" in step["if"] for step in retry_steps
        )
        output = _run_resolve(
            {"eventName": "workflow_dispatch", "repo": {}, "payload": {}},
            [_author_run(7)],
            [7],
            {"DISPATCH_AUTHOR_RUN_ID": author_run_id},
        )
        assert output["mode"] == expected

    @pytest.mark.parametrize(
        "recorded,content_runs,expected",
        [
            (5, [6, 7, 9], "6"),
            (5, [7, 9], "7"),
            (None, [6, 7, 9], "9"),
            (9, [6, 7, 9], None),
        ],
    )
    def test_given_daily_schedule_when_resolved_then_picks_unrecorded_author_run(
        self, tmp_path, recorded, content_runs, expected
    ):
        index = tmp_path / "index.json"
        if recorded is not None:
            index.write_text(
                json.dumps(
                    {
                        "schema_version": "demo-material-site/v2",
                        "levels": {
                            "L100": {"author_run_id": "4"},
                            "L200": {
                                "author_run_id": "3",
                                "last_failed_attempt": {"author_run_id": str(recorded)},
                            },
                        },
                    }
                ),
                encoding="utf-8",
            )
        output = _run_resolve(
            {"eventName": "schedule", "repo": {}, "payload": {}},
            [_author_run(run_id) for run_id in (4, 6, 7, 9)],
            content_runs,
            {"SCHEDULE": "47 3 * * *", "RENDER_INDEX": str(index)},
        )
        if expected is None:
            assert output["mode"] != "render"
        else:
            assert output["mode"] == "render"
            assert output["author-run-id"] == expected

    def test_given_weekly_schedule_when_resolved_then_does_not_pick_up(self, tmp_path):
        output = _run_resolve(
            {"eventName": "schedule", "repo": {}, "payload": {}},
            [_author_run(9)],
            [9],
            {"SCHEDULE": "47 5 * * 1", "RENDER_INDEX": str(tmp_path / "index.json")},
        )
        assert output["mode"] != "render"

    def test_given_attempted_run_unrecorded_by_levels_when_resolved_then_picks_newer(
        self, tmp_path
    ):
        index = tmp_path / "index.json"
        index.write_text(
            json.dumps(
                {
                    "schema_version": "demo-material-site/v2",
                    "latest_attempted_author_run_id": "6",
                    "levels": {"L100": {"author_run_id": "4"}},
                }
            ),
            encoding="utf-8",
        )
        output = _run_resolve(
            {"eventName": "schedule", "repo": {}, "payload": {}},
            [_author_run(run_id) for run_id in (4, 6, 7)],
            [6, 7],
            {"SCHEDULE": "47 3 * * *", "RENDER_INDEX": str(index)},
        )
        assert output["mode"] == "render"
        assert output["author-run-id"] == "7"


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


def _published(levels=("L100",), revision=""):
    index = {
        "schema_version": "demo-material-site/v2",
        "levels": {
            level: {
                "files": {
                    "mp4": f"{level}/hve-demo-{level}.mp4",
                    "vtt": f"{level}/hve-demo-{level}.vtt",
                    "html": f"{level}/hve-demo-{level}.html",
                    "page": f"{level}/index.html",
                }
            }
            for level in levels
        },
    }
    files = {}
    for level in levels:
        entry = index["levels"][level]
        for path in index["levels"][level]["files"].values():
            files[f"{SITE}demo-material/{path}"] = f"body of {path}{revision}".encode()
        prefix = f"{SITE}demo-material/{level}/"
        raw_name = f"hve-demo-{level}.raw.mp4"
        files[prefix + raw_name] = b"raw assembly"
        files[prefix + "manifest.yml"] = b"schema_version: 6\n"
        files[prefix + "source-register.md"] = b"Source register"
        build = {
            "schema_version": 2,
            "renderer": "hve-slides",
            "format": "html",
            "slide_ids": ["slide-1"],
        }
        files[prefix + "html-deck-build.json"] = json.dumps(build).encode()
        browser = {
            "schema_version": 2,
            "renderer": "hve-slides",
            "format": "html",
            "result": "pass",
            "html_sha256": hashlib.sha256(
                files[prefix + f"hve-demo-{level}.html"]
            ).hexdigest(),
            "build_sha256": hashlib.sha256(
                files[prefix + "html-deck-build.json"]
            ).hexdigest(),
            "slide_ids": ["slide-1"],
            "frames": [
                {
                    "slide_id": "slide-1",
                    "path": "frames/deck/slide-001.jpg",
                    "sha256": "a" * 64,
                    "width": 1920,
                    "height": 1080,
                }
            ],
        }
        files[prefix + "html-deck-check.json"] = json.dumps(browser).encode()
        files[prefix + "open-captions.json"] = json.dumps(
            {
                "result": "pass",
                "video_sha256": hashlib.sha256(
                    files[prefix + f"hve-demo-{level}.mp4"]
                ).hexdigest(),
                "source_video_sha256": hashlib.sha256(
                    files[prefix + raw_name]
                ).hexdigest(),
                "captions_sha256": hashlib.sha256(
                    files[prefix + f"hve-demo-{level}.vtt"]
                ).hexdigest(),
            }
        ).encode()
        files[prefix + "render-result.json"] = json.dumps(
            {
                "schema_version": 2,
                "manifest_schema_version": 6,
                "renderer": "hve-slides",
                "format": "html",
                "manifest_sha256": hashlib.sha256(
                    files[prefix + "manifest.yml"]
                ).hexdigest(),
                "level": level,
                "ok": True,
                "capture_profile": "deck-export",
                "narration_engine": "none",
                "timing_basis": "notes-word-count",
                "checks": {
                    key: {"result": "pass"}
                    for key in ("T-04", "T-07", "T-08", "T-09", "T-10", "T-11")
                },
            }
        ).encode()
        entry.update(
            {
                "renderer": "hve-slides",
                "format": "html",
                "render_schema_version": 2,
                "manifest_schema_version": 6,
                "source_sha": "a" * 40,
                "author_run_id": "1",
                "render_run_id": "2",
                "sha256": {
                    url.removeprefix(f"{SITE}demo-material/"): hashlib.sha256(
                        body
                    ).hexdigest()
                    for url, body in files.items()
                    if url.startswith(prefix)
                },
            }
        )
    return {f"{SITE}demo-material/index.json": json.dumps(index).encode(), **files}


def _write_bundle(root, levels=("L100",), revision="", index=True):
    """Write a published bundle under root, optionally without its index."""
    for url, body in _published(levels, revision).items():
        relative = url.removeprefix(f"{SITE}demo-material/")
        if relative == "index.json" and not index:
            continue
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(body)


def _snapshot(root):
    return {
        path.relative_to(root).as_posix(): path.read_bytes()
        for path in sorted(root.rglob("*"))
        if path.is_file()
    }


def _fail_replace_call(mocker, module, number):
    """Make only the given os.replace call fail, delegating every other call."""
    real = os.replace
    calls = []

    def replace(source, target):
        calls.append(target)
        if len(calls) == number:
            raise OSError("simulated replace failure")
        return real(source, target)

    return mocker.patch.object(module.os, "replace", side_effect=replace)


class TestAssembleSite:
    def test_given_no_valid_render_when_assembled_then_records_attempted_run(
        self, tmp_path
    ):
        site = tmp_path / "site"
        _write_bundle(site)
        renders = tmp_path / "renders"
        renders.mkdir()

        first = assemble_site(site, renders, "b" * 40, "7", "8")
        second = assemble_site(site, renders, "b" * 40, "5", "9")

        assert first["latest_attempted_author_run_id"] == "7"
        assert second["latest_attempted_author_run_id"] == "7"
        assert second["levels"]["L100"]["author_run_id"] == "1"

    def test_given_fresh_site_when_assembled_then_level_installed(self, tmp_path):
        site = tmp_path / "site"
        renders = tmp_path / "renders"
        _write_bundle(renders, index=False)

        result = assemble_site(site, renders, "b" * 40, "7", "8")

        assert list(result["levels"]) == ["L100"]
        assert result["levels"]["L100"]["render_run_id"] == "8"
        assert result["levels"]["L100"]["rendered_at"]
        assert (site / "L100" / "hve-demo-L100.mp4").read_bytes() == (
            b"body of L100/hve-demo-L100.mp4"
        )
        assert not list(site.glob(".delivery-*"))

    def test_given_existing_site_when_new_level_assembled_then_both_listed(
        self, tmp_path
    ):
        site = tmp_path / "site"
        renders = tmp_path / "renders"
        _write_bundle(site)
        _write_bundle(renders, ("L200",), index=False)

        result = assemble_site(site, renders, "b" * 40, "7", "8")

        assert list(result["levels"]) == ["L100", "L200"]
        assert result["levels"]["L100"]["author_run_id"] == "1"
        assert result["levels"]["L200"]["author_run_id"] == "7"

    def test_given_replace_fails_when_level_reinstalled_then_prior_files_restored(
        self, tmp_path, mocker
    ):
        site = tmp_path / "site"
        renders = tmp_path / "renders"
        _write_bundle(site)
        _write_bundle(renders, revision=" v2", index=False)
        before = _snapshot(site)
        _fail_replace_call(mocker, artifact_lookup, 3)

        with pytest.raises(OSError, match="simulated replace failure"):
            assemble_site(site, renders, "b" * 40, "7", "8")

        assert _snapshot(site) == before
        assert not list(site.glob(".delivery-*"))

    def test_given_replace_fails_when_new_level_installed_then_added_files_removed(
        self, tmp_path, mocker
    ):
        site = tmp_path / "site"
        renders = tmp_path / "renders"
        _write_bundle(site)
        _write_bundle(renders, ("L200",), index=False)
        before = _snapshot(site)
        _fail_replace_call(mocker, artifact_lookup, 3)

        with pytest.raises(OSError, match="simulated replace failure"):
            assemble_site(site, renders, "b" * 40, "7", "8")

        assert _snapshot(site) == before
        assert not list((site / "L200").iterdir())
        assert not list(site.glob(".delivery-*"))

    def test_given_invalid_render_when_level_reassembled_then_failure_recorded(
        self, tmp_path
    ):
        site = tmp_path / "site"
        renders = tmp_path / "renders"
        _write_bundle(site)
        _write_bundle(renders, revision=" v2", index=False)
        (renders / "L100" / "render-result.json").write_text("{}", encoding="utf-8")

        result = assemble_site(site, renders, "b" * 40, "7", "8")

        entry = result["levels"]["L100"]
        assert entry["author_run_id"] == "1"
        assert entry["last_failed_attempt"]["author_run_id"] == "7"
        assert entry["last_failed_attempt"]["render_run_id"] == "8"
        assert (site / "L100" / "hve-demo-L100.mp4").read_bytes() == (
            b"body of L100/hve-demo-L100.mp4"
        )

    def test_given_malformed_provenance_when_assembled_then_raises_without_changes(
        self, tmp_path
    ):
        site = tmp_path / "site"
        renders = tmp_path / "renders"
        _write_bundle(site)
        _write_bundle(renders, ("L200",), index=False)
        before = _snapshot(site)

        with pytest.raises(ArtifactLookupError, match="render provenance is invalid"):
            assemble_site(site, renders, "x", "7", "8")

        assert _snapshot(site) == before

    def test_given_unindexed_site_files_when_assembled_then_raises(self, tmp_path):
        site = tmp_path / "site"
        site.mkdir()
        (site / "stray.html").write_text("kept", encoding="utf-8")
        renders = tmp_path / "renders"
        _write_bundle(renders, index=False)

        with pytest.raises(ArtifactLookupError, match="Unindexed site files exist"):
            assemble_site(site, renders, "b" * 40, "7", "8")

        assert (site / "stray.html").read_text(encoding="utf-8") == "kept"

    @pytest.mark.parametrize("name", ["L900", "notes.txt"])
    def test_given_unexpected_render_entry_when_assembled_then_raises(
        self, tmp_path, name
    ):
        site = tmp_path / "site"
        renders = tmp_path / "renders"
        _write_bundle(site)
        if name.endswith(".txt"):
            renders.mkdir()
            (renders / name).write_text("x", encoding="utf-8")
        else:
            (renders / name).mkdir(parents=True)

        with pytest.raises(ArtifactLookupError, match="unexpected render directory"):
            assemble_site(site, renders, "b" * 40, "7", "8")

    def test_given_symlinked_render_when_assembled_then_raises(self, tmp_path):
        site = tmp_path / "site"
        renders = tmp_path / "renders"
        real = tmp_path / "elsewhere"
        _write_bundle(site)
        _write_bundle(real, index=False)
        renders.mkdir()
        try:
            (renders / "L100").symlink_to(real / "L100", target_is_directory=True)
        except OSError:
            pytest.skip("symlinks are unavailable on this platform")

        with pytest.raises(ArtifactLookupError, match="non-regular bundle path"):
            assemble_site(site, renders, "b" * 40, "7", "8")


def _http_error(code):
    return urllib.error.HTTPError("https://example.test", code, "status", None, None)


def _response(mocker, body):
    response = mocker.MagicMock()
    response.__enter__.return_value.read.return_value = body
    return response


class TestGitHubApi:
    def test_given_malformed_repository_when_created_then_raises(self):
        with pytest.raises(ArtifactLookupError, match="owner/name"):
            GitHubApi("token", "not a repository", "https://api.github.com")

    def test_given_response_when_get_then_decodes_json_with_query(self, mocker):
        urlopen = mocker.patch(
            "artifact_lookup.urllib.request.urlopen",
            return_value=_response(mocker, b'{"total_count": 1}'),
        )
        api = GitHubApi("token", "contoso/widgets", "https://api.github.com/")

        result = api.get("/actions/runs", {"per_page": 5})

        assert result == {"total_count": 1}
        request = urlopen.call_args.args[0]
        assert request.full_url == (
            "https://api.github.com/repos/contoso/widgets/actions/runs?per_page=5"
        )

    def test_given_not_found_when_get_then_empty(self, mocker):
        mocker.patch(
            "artifact_lookup.urllib.request.urlopen", side_effect=_http_error(404)
        )
        api = GitHubApi("token", "contoso/widgets", "https://api.github.com")

        assert api.get("/actions/runs") == {}

    @pytest.mark.parametrize(
        ("error", "message"),
        [
            (_http_error(500), "returned 500"),
            (urllib.error.URLError("down"), "failed"),
        ],
    )
    def test_given_request_error_when_get_then_raises(self, mocker, error, message):
        mocker.patch("artifact_lookup.urllib.request.urlopen", side_effect=error)
        api = GitHubApi("token", "contoso/widgets", "https://api.github.com")

        with pytest.raises(ArtifactLookupError, match=message):
            api.get("/actions/runs")

    def test_given_invalid_json_when_get_then_raises(self, mocker):
        mocker.patch(
            "artifact_lookup.urllib.request.urlopen",
            return_value=_response(mocker, b"not json"),
        )
        api = GitHubApi("token", "contoso/widgets", "https://api.github.com")

        with pytest.raises(ArtifactLookupError, match="failed"):
            api.get("/actions/runs")


class TestFetchUrl:
    def test_given_response_when_fetched_then_body(self, mocker):
        mocker.patch(
            "artifact_lookup.urllib.request.urlopen",
            return_value=_response(mocker, b"payload"),
        )

        assert fetch_url("https://example.test/index.json") == b"payload"

    def test_given_not_found_when_fetched_then_none(self, mocker):
        mocker.patch(
            "artifact_lookup.urllib.request.urlopen", side_effect=_http_error(404)
        )

        assert fetch_url("https://example.test/index.json") is None

    @pytest.mark.parametrize(
        ("error", "message"),
        [
            (_http_error(503), "returned 503"),
            (urllib.error.URLError("down"), "failed"),
        ],
    )
    def test_given_request_error_when_fetched_then_raises(self, mocker, error, message):
        mocker.patch("artifact_lookup.urllib.request.urlopen", side_effect=error)

        with pytest.raises(ArtifactLookupError, match=message):
            fetch_url("https://example.test/index.json")


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
            == "demo-material-site/v2"
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
            "schema_version": "demo-material-site/v2",
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


class TestRetryLevels:
    def test_given_complete_levels_when_selected_then_none_retry(self):
        # Arrange
        index = json.loads(
            next(iter(_published(("L100", "L200", "L300", "L400")).values()))
        )

        # Act
        result = retry_levels(index)

        # Assert
        assert result == []

    def test_given_failed_and_unpublished_levels_when_selected_then_both_retry(self):
        # Arrange
        index = json.loads(next(iter(_published(("L100", "L200", "L300")).values())))
        index["levels"]["L300"]["last_failed_attempt"] = {"checks": {}}

        # Act
        result = retry_levels(index)

        # Assert
        assert result == ["L300", "L400"]

    def test_given_retry_cli_when_run_then_writes_space_separated_levels(
        self, tmp_path, capsys
    ):
        # Arrange
        index_path = tmp_path / "index.json"
        index_path.write_bytes(_published(("L100",))[f"{SITE}demo-material/index.json"])
        output = tmp_path / "out"

        # Act
        code = main(
            [
                "retry-levels",
                "--index",
                str(index_path),
                "--github-output",
                str(output),
            ]
        )

        # Assert
        assert code == 0
        assert output.read_text(encoding="utf-8") == "levels=L200 L300 L400\n"
        assert json.loads(capsys.readouterr().out) == {"levels": "L200 L300 L400"}
