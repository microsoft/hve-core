# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from __future__ import annotations

import json
from pathlib import Path

import pytest
from runtime_a11y._errors import ScriptError
from runtime_a11y.matrix._catalog import (
    catalog_provenance,
    load_criteria_catalog,
    partition_path,
)
from runtime_a11y.matrix._model import METHOD_VOCABULARY

PARTITIONS = ("wcag-22", "aria-apg", "defect-scan")


def _copy_catalog(destination: Path) -> None:
    for framework in PARTITIONS:
        source = partition_path(framework)
        (destination / source.name).write_text(
            source.read_text(encoding="utf-8"), encoding="utf-8"
        )


def test_catalog_covers_every_criterion_the_probe_map_references() -> None:
    probe_map = json.loads(
        (partition_path("wcag-22").parent / "probe-criteria-map.json").read_text(
            encoding="utf-8"
        )
    )
    referenced = {
        (item["framework"], item["criterionId"])
        for probe in probe_map.get("probes", [])
        for key in ("decides", "informs")
        for item in probe.get(key, [])
    }
    catalogued = {(entry.framework, entry.id) for entry in load_criteria_catalog()}

    assert referenced - catalogued == set()


def test_catalog_names_only_known_methods() -> None:
    for entry in load_criteria_catalog():
        assert entry.adequateMethods <= set(METHOD_VOCABULARY)


def test_criteria_needing_human_judgment_declare_a_reason() -> None:
    for framework in PARTITIONS:
        payload = json.loads(partition_path(framework).read_text(encoding="utf-8"))
        for entry in payload["criteria"]:
            if entry["adequateMethods"]:
                continue
            assert entry["humanJudgment"]["required"] is True
            assert entry["humanJudgment"]["reason"].strip()


def test_announcement_and_interaction_classes_never_rest_on_static_evidence() -> None:
    """The adequacy doctrine caps these classes until an adequate method runs."""
    static_only = {"axe-auto", "static-source", "plan-derived"}
    for framework in PARTITIONS:
        payload = json.loads(partition_path(framework).read_text(encoding="utf-8"))
        for entry in payload["criteria"]:
            if entry["failureClass"] not in {
                "interaction",
                "announcement",
                "adaptive-rendering",
                "faux-semantics",
            }:
                continue
            methods = set(entry["adequateMethods"])
            assert not methods or not methods <= static_only, entry["id"]


def test_missing_partition_refuses_rather_than_defaulting(tmp_path: Path) -> None:
    _copy_catalog(tmp_path)
    (tmp_path / "criteria-catalog.wcag-22.json").unlink()

    with pytest.raises(ScriptError) as excinfo:
        load_criteria_catalog(tmp_path)

    assert "missing" in str(excinfo.value).lower()


def test_unknown_method_is_rejected(tmp_path: Path) -> None:
    _copy_catalog(tmp_path)
    target = tmp_path / "criteria-catalog.aria-apg.json"
    payload = json.loads(target.read_text(encoding="utf-8"))
    payload["criteria"][0]["adequateMethods"] = ["vibes-based"]
    target.write_text(json.dumps(payload), encoding="utf-8")

    with pytest.raises(ScriptError):
        load_criteria_catalog(tmp_path)


def test_malformed_partition_refuses(tmp_path: Path) -> None:
    _copy_catalog(tmp_path)
    (tmp_path / "criteria-catalog.defect-scan.json").write_text(
        "{not json", encoding="utf-8"
    )

    with pytest.raises(ScriptError):
        load_criteria_catalog(tmp_path)


def test_provenance_reports_unreviewed_until_a_reviewer_signs() -> None:
    provenance = catalog_provenance()

    assert set(provenance["partitions"]) == set(PARTITIONS)
    assert provenance["reviewed"] is False
