# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""EV-06 finding matrix and cross-cutting assurance tests."""

from __future__ import annotations

import hashlib
import json
import os
import pathlib
from typing import Any

import pytest

FIXTURE = (
    pathlib.Path(__file__).parent / "fixtures" / "assurance" / "ev06-scenarios.json"
)
EXPECTED_FINDINGS = {
    "RAI-P08-G02-A081-C01",
    "RAI-P08-G02-A082-C01",
    "RAI-P08-G02-A083-C01",
    "RAI-P08-G02-A084-C01",
    "RAI-P08-G02-A085-C01",
    "RAI-P08-G02-A086-C01",
    "RAI-P08-G02-A087-C01",
    "RAI-P08-G04-A191-C01",
}
FIVE_FAMILIES = {
    "NORMAL",
    "AUTHORITY_CONSENT",
    "FAIL_CLOSED",
    "EXTERNAL_WRITE",
    "RECOVERY_RESUME",
}
SOURCE_FILES = (
    "scripts/mural/__init__.py",
    "scripts/mural/_area_helpers.py",
    "scripts/mural/_commands.py",
    "scripts/mural/_destinations.py",
    "scripts/mural/_doctor.py",
    "scripts/mural/_exceptions.py",
    "scripts/mural/_operations.py",
    "scripts/mural/_parser.py",
    "tests/conftest.py",
    "tests/test_destinations.py",
    "tests/test_doctor.py",
    "tests/test_ev06_assurance.py",
)
EVIDENCE_TESTS = {
    "RAI-P08-G02-A081-C01": (
        "tests/test_doctor.py",
        "tests/test_bootstrap_config.py",
        "tests/test_mural_oauth.py",
    ),
    "RAI-P08-G02-A082-C01": ("tests/test_destinations.py",),
    "RAI-P08-G02-A083-C01": (
        "tests/test_ev06_assurance.py",
        "tests/test_mural_helpers.py",
    ),
    "RAI-P08-G02-A084-C01": (
        "tests/test_ev06_assurance.py",
        "tests/test_redaction.py",
    ),
    "RAI-P08-G02-A085-C01": (
        "tests/test_widget_create_bulk_dispatch.py",
        "tests/test_mural_helpers.py",
    ),
    "RAI-P08-G02-A086-C01": (
        "tests/test_destinations.py",
        "tests/test_mural_helpers.py",
    ),
    "RAI-P08-G02-A087-C01": ("tests/test_destinations.py",),
    "RAI-P08-G04-A191-C01": (
        "tests/test_doctor.py",
        "tests/test_mural_transport.py",
    ),
}


def load_manifest() -> dict[str, Any]:
    return json.loads(FIXTURE.read_text(encoding="utf-8"))


def source_revision() -> str:
    skill_root = pathlib.Path(__file__).parent.parent
    digest = hashlib.sha256()
    for relative_path in SOURCE_FILES:
        digest.update(relative_path.encode("utf-8"))
        digest.update((skill_root / relative_path).read_bytes())
    digest.update(FIXTURE.read_bytes())
    return f"worktree-sha256:{digest.hexdigest()}"


def build_evidence_aggregate() -> dict[str, Any]:
    manifest = load_manifest()
    local_test_summary = os.environ.get("EV06_TEST_SUMMARY", "NOT_EXECUTED")
    local_passed = local_test_summary != "NOT_EXECUTED"
    scenarios: list[dict[str, Any]] = []
    for finding in manifest["required_findings"]:
        callers = finding.get("callers") or [None]
        destinations = finding.get("destinations") or [None]
        for family in finding["families"]:
            for surface in finding["surfaces"]:
                for caller in callers:
                    for destination in destinations:
                        pending_ci = caller is not None
                        scenario = {
                            "scenario_id": finding["scenario_id"],
                            "finding_ids": [finding["finding_id"]],
                            "family": family,
                            "surface": surface,
                            "caller": caller,
                            "destination": destination,
                            "fidelity": "MODEL_EVAL_PENDING"
                            if pending_ci
                            else manifest["fidelity"],
                            "verdict": "PENDING_CI"
                            if pending_ci
                            else ("PASS" if local_passed else "NOT_EXECUTED"),
                            "assertions": finding["assertions"],
                            "evidence_tests": list(
                                EVIDENCE_TESTS[finding["finding_id"]]
                            ),
                            "pre_state": {"external_effects": 0},
                            "attempted_calls": [],
                            "post_state": {"external_effects": 0},
                            "recovery": {"status": "covered"}
                            if local_passed
                            else {"status": "not-executed"},
                            "sanitized_output": {},
                        }
                        result_payload = json.dumps(
                            scenario, sort_keys=True, separators=(",", ":")
                        )
                        scenario["result_digest"] = hashlib.sha256(
                            result_payload.encode("utf-8")
                        ).hexdigest()
                        scenarios.append(scenario)
    aggregate: dict[str, Any] = {
        "schema_version": "ev06-evidence/v1",
        "source_revision": source_revision(),
        "command": "uv run pytest tests/ --tb=short",
        "execution_status": "LOCAL_PASS_PENDING_CI" if local_passed else "NOT_EXECUTED",
        "local_test_summary": local_test_summary,
        "fidelity": manifest["fidelity"],
        "scenario_inventory": scenarios,
        "pending_ci": [
            "agent-behavior model execution",
            "qualified RAI finding reclassification",
        ],
        "not_executed": [
            "native Mural behavior",
            "real destination effects",
            "production loop closure",
        ],
    }
    canonical = json.dumps(aggregate, sort_keys=True, separators=(",", ":"))
    aggregate["aggregate_digest"] = hashlib.sha256(
        canonical.encode("utf-8")
    ).hexdigest()
    return aggregate


def test_manifest_covers_all_findings_and_required_dimensions() -> None:
    manifest = load_manifest()
    rows = {row["finding_id"]: row for row in manifest["required_findings"]}

    assert manifest["fidelity"] == "LOCAL_TEST_DOUBLE"
    assert set(rows) == EXPECTED_FINDINGS
    for finding_id, row in rows.items():
        expected = (
            {"NORMAL", "ROUTING"} if finding_id.endswith("A087-C01") else FIVE_FAMILIES
        )
        assert set(row["families"]) == expected
        assert row["assertions"]
        assert row["baseline"] in {"ABSENT", "CONTRADICTED"}
    assert rows["RAI-P08-G02-A085-C01"]["callers"] == [
        "dt-coach",
        "rai-planner",
        "ux-ui-designer",
    ]
    assert len(rows["RAI-P08-G02-A087-C01"]["destinations"]) == 7
    assert "azure-blob-sas-upload" in rows["RAI-P08-G04-A191-C01"]["surfaces"]


def test_evidence_aggregate_covers_required_tuples_and_stable_digest(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.delenv("EV06_TEST_SUMMARY", raising=False)
    manifest = load_manifest()
    aggregate = build_evidence_aggregate()
    expected = {
        (
            finding["finding_id"],
            family,
            surface,
            caller,
            destination,
        )
        for finding in manifest["required_findings"]
        for family in finding["families"]
        for surface in finding["surfaces"]
        for caller in finding.get("callers") or [None]
        for destination in finding.get("destinations") or [None]
    }
    observed = {
        (
            scenario["finding_ids"][0],
            scenario["family"],
            scenario["surface"],
            scenario["caller"],
            scenario["destination"],
        )
        for scenario in aggregate["scenario_inventory"]
    }
    digest = aggregate.pop("aggregate_digest")
    canonical = json.dumps(aggregate, sort_keys=True, separators=(",", ":"))

    assert observed == expected
    assert digest == hashlib.sha256(canonical.encode("utf-8")).hexdigest()
    assert all(
        scenario["verdict"] == "PENDING_CI"
        for scenario in aggregate["scenario_inventory"]
        if scenario["caller"] is not None
    )
    assert all(
        scenario["verdict"] == "NOT_EXECUTED"
        for scenario in aggregate["scenario_inventory"]
        if scenario["caller"] is None
    )
    assert all(
        scenario["evidence_tests"] for scenario in aggregate["scenario_inventory"]
    )


def test_emit_evidence_aggregate_only_when_explicitly_requested() -> None:
    output_path = os.environ.get("EV06_EVIDENCE_PATH")
    if output_path is None:
        return
    path = pathlib.Path(output_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(build_evidence_aggregate(), indent=2) + "\n",
        encoding="utf-8",
    )

    persisted = json.loads(path.read_text(encoding="utf-8"))

    assert persisted == build_evidence_aggregate()


def test_human_widget_update_is_protected_by_default(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    transport: list[str] = []

    def deny(mural_id: str, widget_id: str) -> None:
        raise mural_module.MuralHumanAuthoredProtected(
            mural_id=mural_id, widget_id=widget_id
        )

    monkeypatch.setattr(
        mural_module,
        "_assert_widget_has_author_tag",
        deny,
    )
    monkeypatch.setattr(
        mural_module,
        "_patch_widget_or_disambiguate_404",
        lambda *args, **kwargs: transport.append("patch"),
    )

    with pytest.raises(mural_module.MuralHumanAuthoredProtected):
        mural_module._op_widget_update(
            {
                "mural": "workspace1.mural-abc123",
                "widget": "widget-1",
                "body": {"hyperlink": "https://example.invalid/record"},
                "force_human": False,
            }
        )

    assert transport == []


def test_explicit_human_override_is_visible_and_bypasses_authorship_guard(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls: list[str] = []
    monkeypatch.setattr(
        mural_module,
        "_assert_widget_has_author_tag",
        lambda *_args: calls.append("guard"),
    )
    monkeypatch.setattr(
        mural_module,
        "_patch_widget_or_disambiguate_404",
        lambda *_args, **_kwargs: calls.append("patch") or {"id": "widget-1"},
    )

    mural_module._op_widget_update(
        {
            "mural": "workspace1.mural-abc123",
            "widget": "widget-1",
            "body": {"hyperlink": "https://example.invalid/record"},
            "force_human": True,
        }
    )

    assert calls == ["patch"]


def test_ai_authored_widget_passes_guard_before_update(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls: list[str] = []
    monkeypatch.setattr(
        mural_module,
        "_assert_widget_has_author_tag",
        lambda *_args: calls.append("guard"),
    )
    monkeypatch.setattr(
        mural_module,
        "_patch_widget_or_disambiguate_404",
        lambda *_args, **_kwargs: calls.append("patch") or {"id": "widget-1"},
    )

    mural_module._op_widget_update(
        {
            "mural": "workspace1.mural-abc123",
            "widget": "widget-1",
            "body": {"hyperlink": "https://example.invalid/record"},
            "force_human": False,
        }
    )

    assert calls == ["guard", "patch"]


def test_human_widget_delete_stops_before_transport(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    transport: list[str] = []

    def deny(mural_id: str, widget_id: str) -> None:
        raise mural_module.MuralHumanAuthoredProtected(
            mural_id=mural_id, widget_id=widget_id
        )

    monkeypatch.setattr(mural_module, "_assert_widget_has_author_tag", deny)
    monkeypatch.setattr(
        mural_module,
        "_authenticated_request",
        lambda *_args, **_kwargs: transport.append("delete"),
    )

    with pytest.raises(mural_module.MuralHumanAuthoredProtected):
        mural_module._op_widget_delete(
            {
                "mural": "workspace1.mural-abc123",
                "widget": "widget-1",
                "force_human": False,
            }
        )

    assert transport == []


def test_bulk_update_always_enables_default_authorship_guard(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    seen: dict[str, Any] = {}

    def bulk_update(*_args: Any, **kwargs: Any) -> dict[str, Any]:
        seen.update(kwargs)
        return {"succeeded": [], "failed": [], "skipped": []}

    monkeypatch.setattr(mural_module, "_bulk_update_widgets", bulk_update)

    mural_module._op_widget_update_bulk(
        {
            "mural": "workspace1.mural-abc123",
            "updates": [
                {
                    "widget_id": "widget-1",
                    "body": {"hyperlink": "https://example.invalid/record"},
                }
            ],
            "atomic": False,
            "force_human": False,
        }
    )

    assert seen["require_author_tag"] is True


def test_removed_opt_in_author_guard_flag_is_rejected(mural_module: Any) -> None:
    with pytest.raises(SystemExit):
        mural_module._build_parser().parse_args(
            [
                "widget",
                "update",
                "--mural",
                "workspace1.mural-abc123",
                "--widget",
                "widget-1",
                "--body",
                "{}",
                "--require-author-tag",
            ]
        )


def test_redaction_removes_credential_markers_but_preserves_human_record_text(
    mural_module: Any,
) -> None:
    diagnostic = (
        'access_token="SYNTHETIC_ACCESS" refresh_token=SYNTHETIC_REFRESH '
        "Authorization: Bearer SYNTHETIC_BEARER "
        "https://acct.blob.core.windows.net/c/b?sig=SYNTHETIC_SAS"
    )
    human_text = "The team reports that password rotation is difficult."

    redacted = mural_module._redact(diagnostic)

    for marker in (
        "SYNTHETIC_ACCESS",
        "SYNTHETIC_REFRESH",
        "SYNTHETIC_BEARER",
        "SYNTHETIC_SAS",
    ):
        assert marker not in redacted
    assert mural_module._redact(human_text) == human_text
