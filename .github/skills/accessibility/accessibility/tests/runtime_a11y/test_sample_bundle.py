# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path


def _run_cli(
    *args: str, cwd: Path, env: dict[str, str] | None = None
) -> subprocess.CompletedProcess[str]:
    merged_env = {**dict(os.environ), **(env or {})}
    return subprocess.run(
        [sys.executable, "-m", "runtime_a11y", *args],
        capture_output=True,
        text=True,
        cwd=str(cwd),
        check=True,
        env=merged_env,
    )


def test_public_render_and_execution_dogfood_bundle(tmp_path: Path) -> None:
    repo_root = Path(__file__).resolve().parents[2]
    matrix_path = (
        repo_root / "tests" / "runtime_a11y" / "fixtures" / "aria-at-driver-matrix.json"
    )
    original_matrix_bytes = matrix_path.read_bytes()

    output_dir = tmp_path / "artifacts"
    output_dir.mkdir(parents=True, exist_ok=True)

    runtime_config_path = tmp_path / "runtime-config.json"
    runtime_config_path.write_text(
        json.dumps(
            {
                "baseUrl": "http://127.0.0.1:3000",
                "surfaces": [
                    {
                        "id": "modal-dialog",
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

    render_result = _run_cli(
        "render-artifacts",
        "--matrix",
        str(matrix_path),
        "--output-dir",
        str(output_dir),
        "--repo-slug",
        "sample/aria-at-driver",
        "--runtime-config",
        str(runtime_config_path),
        cwd=repo_root,
        env={"PYTHONPATH": str(repo_root / "scripts")},
    )
    assert render_result.returncode == 0

    list_result = _run_cli(
        "run-at-plan",
        "--matrix",
        str(matrix_path),
        "--list",
        cwd=repo_root,
        env={"PYTHONPATH": str(repo_root / "scripts")},
    )
    list_payload = json.loads(list_result.stdout)
    assert list_payload["cases"]

    listed_ids = [case["id"] for case in list_payload["cases"]]
    assert "manual-4-1-2-modal-dialog-open" in listed_ids
    assert "manual-4-1-2-checkbox-default" in listed_ids
    assert "manual-4-1-2-unknown-pattern-default" in listed_ids

    manifest_path = output_dir / "accessibility-artifacts-sample-aria-at-driver.json"
    assert manifest_path.exists()
    manifest_payload = json.loads(manifest_path.read_text(encoding="utf-8"))
    artifact_paths = manifest_payload["artifacts"]
    assert len(artifact_paths) == 5
    assert set(artifact_paths) == {
        "coverageJson",
        "coverageMarkdown",
        "earlJsonLd",
        "manualTestPlanMarkdown",
        "manualTestPlanYaml",
    }

    child_paths = [output_dir / artifact_paths[key] for key in artifact_paths]
    assert all(path.exists() for path in child_paths)

    coverage_json = output_dir / artifact_paths["coverageJson"]
    coverage_markdown = output_dir / artifact_paths["coverageMarkdown"]
    earl_json = output_dir / artifact_paths["earlJsonLd"]
    manual_markdown = output_dir / artifact_paths["manualTestPlanMarkdown"]
    manual_yaml = output_dir / artifact_paths["manualTestPlanYaml"]

    coverage_payload = json.loads(coverage_json.read_text(encoding="utf-8"))
    assert coverage_payload["coverage"]["overall"]["coverage"] == 14.3
    assert coverage_payload["coverage"]["overall"]["numerator"] == 1
    assert coverage_payload["coverage"]["overall"]["denominator"] == 7
    markdown_text = coverage_markdown.read_text(encoding="utf-8")
    assert "14.3%" in markdown_text
    assert "Reviewed and validated by a qualified human reviewer" in markdown_text
    assert "Disclaimer:" in markdown_text

    earl_payload = json.loads(earl_json.read_text(encoding="utf-8"))
    assertions = [
        node for node in earl_payload["@graph"] if node.get("@type") == "earl:Assertion"
    ]
    assert assertions
    outcomes = {
        assertion["earl:subject"]["dct:identifier"]: [
            assertion["earl:result"]["earl:outcome"]["@id"]
        ]
        for assertion in assertions
    }
    for assertion in assertions:
        subject_id = assertion["earl:subject"]["dct:identifier"]
        outcomes.setdefault(subject_id, []).append(
            assertion["earl:result"]["earl:outcome"]["@id"]
        )
    assert "earl:passed" in outcomes["modal-dialog#open"]
    assert "earl:cantTell" in outcomes["modal-dialog#open"]
    assert any(
        outcome == "earl:inapplicable"
        for outcomes_for_subject in outcomes.values()
        for outcome in outcomes_for_subject
    )

    markdown_text = manual_markdown.read_text(encoding="utf-8")
    yaml_text = manual_yaml.read_text(encoding="utf-8")
    assert "manual-4-1-2-checkbox-default" in markdown_text
    assert "manual-4-1-2-checkbox-default" in yaml_text
    assert "review:\n  required: true" in yaml_text
    assert "completed: false" in yaml_text
    assert (
        "human-only" in markdown_text.lower() or "manual-only" in markdown_text.lower()
    )
    assert "Unknown Pattern" in markdown_text
    assert "manual-4-1-2-unknown-pattern-default" in markdown_text
    assert "manual-4-1-2-unknown-pattern-default" in yaml_text

    selected_case_id = "manual-4-1-2-modal-dialog-open"
    synthetic_out_path = tmp_path / "synthetic-evidence.json"
    execute_result = _run_cli(
        "run-at-plan",
        "--matrix",
        str(matrix_path),
        "--config",
        str(runtime_config_path),
        "--case-id",
        selected_case_id,
        "--out",
        str(synthetic_out_path),
        "--driver",
        "synthetic",
        cwd=repo_root,
        env={"PYTHONPATH": str(repo_root / "scripts")},
    )
    assert execute_result.returncode == 0

    synthetic_payload = json.loads(synthetic_out_path.read_text(encoding="utf-8"))
    assert synthetic_payload["cases"]
    synthetic_result = synthetic_payload["cases"][0]
    assert synthetic_result["caseId"] == selected_case_id
    assert synthetic_result["status"] != "pass"
    assert synthetic_result["evidence"]["synthetic"] is True
    assert (
        synthetic_result["sourceMatrixMetadata"]["sha256"]
        == hashlib.sha256(original_matrix_bytes).hexdigest()
    )
    assert matrix_path.read_bytes() == original_matrix_bytes

    assert '"status": "unsupported"' not in synthetic_out_path.read_text(
        encoding="utf-8"
    )

    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)
        temp_matrix = temp_path / "matrix.json"
        temp_matrix.write_bytes(original_matrix_bytes)
        temp_output = temp_path / "out"
        temp_output.mkdir(parents=True, exist_ok=True)
        _run_cli(
            "render-artifacts",
            "--matrix",
            str(temp_matrix),
            "--output-dir",
            str(temp_output),
            "--repo-slug",
            "sample/aria-at-driver",
            cwd=repo_root,
            env={"PYTHONPATH": str(repo_root / "scripts")},
        )
        assert (
            temp_output / "accessibility-artifacts-sample-aria-at-driver.json"
        ).exists()
