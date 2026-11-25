# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path


def test_given_modal_dialog_matrix_when_public_workflow_runs_then_case_ids_align(
    tmp_path: Path,
) -> None:
    matrix_path = tmp_path / "matrix.json"
    matrix_path.write_text(
        (
            Path(__file__).parent / "fixtures" / "aria-at-modal-dialog-matrix.json"
        ).read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    original_matrix_bytes = matrix_path.read_bytes()
    config_path = tmp_path / "runtime.json"
    config_path.write_text(
        json.dumps(
            {
                "baseUrl": "http://127.0.0.1:3000",
                "surfaces": [
                    {
                        "id": "dialog",
                        "widgetPattern": "dialog-modal",
                        "states": [
                            {
                                "state": "open",
                                "ariaAt": {
                                    "commands": [
                                        {"kind": "command", "value": "perform"}
                                    ],
                                    "assertions": [
                                        {"type": "contains", "value": "dialog"}
                                    ],
                                },
                            }
                        ],
                    }
                ],
                "syntheticPhrases": ["dialog"],
            }
        ),
        encoding="utf-8",
    )
    output_dir = tmp_path / "artifacts"
    output_dir.mkdir(parents=True, exist_ok=True)
    out_path = output_dir / "evidence.json"

    repo_root = Path(__file__).resolve().parents[2]

    rendered = subprocess.run(
        [
            sys.executable,
            "-m",
            "runtime_a11y",
            "render-artifacts",
            "--matrix",
            str(matrix_path),
            "--output-dir",
            str(output_dir),
            "--repo-slug",
            "dogfood/modal",
            "--runtime-config",
            str(config_path),
        ],
        capture_output=True,
        text=True,
        cwd=repo_root,
        check=True,
        env={**dict(os.environ), "PYTHONPATH": str(repo_root / "scripts")},
    )
    assert rendered.returncode == 0

    listed = subprocess.run(
        [
            sys.executable,
            "-m",
            "runtime_a11y",
            "run-at-plan",
            "--matrix",
            str(matrix_path),
            "--list",
        ],
        capture_output=True,
        text=True,
        cwd=repo_root,
        check=True,
        env={**dict(os.environ), "PYTHONPATH": str(repo_root / "scripts")},
    )
    list_payload = json.loads(listed.stdout)
    assert list_payload["cases"]
    listed_case_id = list_payload["cases"][0]["id"]

    execute = subprocess.run(
        [
            sys.executable,
            "-m",
            "runtime_a11y",
            "run-at-plan",
            "--matrix",
            str(matrix_path),
            "--config",
            str(config_path),
            "--case-id",
            listed_case_id,
            "--out",
            str(out_path),
            "--driver",
            "synthetic",
        ],
        capture_output=True,
        text=True,
        cwd=repo_root,
        check=True,
        env={**dict(os.environ), "PYTHONPATH": str(repo_root / "scripts")},
    )
    assert execute.returncode == 0

    evidence = json.loads(out_path.read_text(encoding="utf-8"))
    assert evidence["cases"]
    result_case_ids = [result["caseId"] for result in evidence["cases"]]
    assert result_case_ids == [listed_case_id] * len(result_case_ids)
    for result in evidence["cases"]:
        assert result["caseId"] == listed_case_id
        assert result["status"] != "pass"
        assert result["evidence"]["synthetic"] is True
        assert result["evidence"]["reason"] is not None
        assert result["sourceMatrixRef"] == matrix_path.name
        assert result["sourceMatrixMetadata"]["path"] == matrix_path.name
        assert (
            result["sourceMatrixMetadata"]["sha256"]
            == hashlib.sha256(original_matrix_bytes).hexdigest()
        )
    assert matrix_path.read_bytes() == original_matrix_bytes

    markdown_output = (output_dir / "manual-at-testplan-dogfood-modal.md").read_text(
        encoding="utf-8"
    )
    yaml_output = (output_dir / "manual-at-testplan-dogfood-modal.yaml").read_text(
        encoding="utf-8"
    )
    assert listed_case_id in markdown_output
    assert listed_case_id in yaml_output
