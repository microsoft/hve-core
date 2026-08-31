# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Regression tests for TM7 threat population and TB7 filter stability."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_DIR = ROOT / "scripts"
FIXTURES_DIR = Path(__file__).resolve().parent / "fixtures"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import generate_tb7  # noqa: E402
import generate_tm7  # noqa: E402
import populate_tm7_threats  # noqa: E402
import tm7_threat_contract  # noqa: E402

COMPREHENSIVE_SPEC_PATH = FIXTURES_DIR / "comprehensive-spec.yaml"


def _render_base(spec: dict, tmp_path: Path, name: str) -> Path:
    profile = generate_tm7.resolve_profile(spec, None, ROOT)
    profile["name"] = "sdl_core_generic"
    payload = generate_tm7.build_tm7_payload(
        spec,
        profile,
        "pre-populated-comprehensive",
        threat_generation_enabled=False,
    )
    xml_text = generate_tm7.render_tm7_xml(
        payload,
        ROOT,
        "sdl_core_generic",
    )
    base_path = tmp_path / name
    base_path.write_text(xml_text, encoding="utf-8")
    return base_path


def _write_complete_base(tmp_path: Path) -> Path:
    spec = generate_tm7.load_spec(COMPREHENSIVE_SPEC_PATH)
    return _render_base(spec, tmp_path, "complete-base.tm7")


@pytest.fixture(scope="module")
def complete_base(tmp_path_factory: pytest.TempPathFactory) -> Path:
    """Render the comprehensive base once per module.

    Rendering the full spec is expensive and population never writes to the base,
    so every test can share one rendered copy.
    """
    return _write_complete_base(tmp_path_factory.mktemp("complete-base"))


def _write_base_missing_flow(tmp_path: Path, flow_id: str) -> Path:
    """Render a base whose topology omits one flow the full spec's threats reference.

    The base spec must also drop the threats that reference the removed flow,
    because generation validates every threat's interaction_ref. Populating this
    base with the full spec then exercises the absent-connector guard.
    """
    spec = generate_tm7.load_spec(COMPREHENSIVE_SPEC_PATH)
    remaining = [
        flow
        for flow in spec.get("data_flows") or []
        if isinstance(flow, dict) and flow.get("id") != flow_id
    ]
    spec["data_flows"] = remaining
    spec["threats"] = [
        threat
        for threat in spec.get("threats") or []
        if isinstance(threat, dict) and threat.get("interaction_ref") != flow_id
    ]
    still_connected = {flow.get("source_ref") for flow in remaining}
    still_connected.update(flow.get("target_ref") for flow in remaining)
    for component in spec.get("components") or []:
        if not isinstance(component, dict):
            continue
        if component.get("id") not in still_connected and not component.get(
            "layout_role"
        ):
            component["layout_role"] = "contextual"
    return _render_base(spec, tmp_path, "base-missing-flow.tm7")


def test_given_tb7_generation_when_filters_are_built_then_expression_is_safe() -> None:
    # Act
    filters = generate_tb7._build_generation_filters()

    # Assert
    include_text = filters.findtext("Include") or ""
    exclude_text = filters.findtext("Exclude") or ""
    assert include_text == "source is 'ROOT'"
    assert exclude_text == ""
    assert "and" not in include_text.lower()


def test_given_comprehensive_spec_when_populated_then_has_expected_count(
    complete_base: Path,
) -> None:
    # Act
    result = populate_tm7_threats.populate_tm7_threats(
        COMPREHENSIVE_SPEC_PATH,
        complete_base,
        generation_state=False,
    )

    # Assert
    assert result["ThreatGenerationEnabled"] is False
    assert len(result["ThreatInstances"]) == 80
    assert result["counts"]["threat_instances"] == 80
    assert result["counts"]["custom_types"] == 80
    assert (
        result["hashes"]["drawing_surface_list_before"]
        == (result["hashes"]["drawing_surface_list_after"])
    )
    assert (
        result["hashes"]["knowledge_base_before"]
        == (result["hashes"]["knowledge_base_after"])
    )


def test_given_non_80_threat_spec_when_populated_then_count_is_caller_controlled(
    tmp_path: Path,
) -> None:
    """A valid spec is accepted on its own terms, not against a fixed 80.

    The count was hardcoded, so every internally consistent model that did not
    happen to declare exactly 80 threats was rejected. It is now an optional
    caller assertion that fails only when the caller's own number disagrees.
    """
    # Arrange
    spec = generate_tm7.load_spec(COMPREHENSIVE_SPEC_PATH)
    kept_ids = {
        str(threat.get("id"))
        for threat in (spec.get("threats") or [])[:3]
        if isinstance(threat, dict)
    }
    spec["threats"] = [
        threat
        for threat in spec.get("threats") or []
        if isinstance(threat, dict) and str(threat.get("id")) in kept_ids
    ]
    spec_path = tmp_path / "three-threat-spec.yaml"
    spec_path.write_text(yaml.safe_dump(spec, sort_keys=False), encoding="utf-8")
    base_path = _render_base(spec, tmp_path, "three-threat-base.tm7")

    # Act
    result = populate_tm7_threats.populate_tm7_threats(
        spec_path,
        base_path,
        generation_state=False,
    )

    # Assert
    assert len(result["ThreatInstances"]) == 3

    matching = populate_tm7_threats.populate_tm7_threats(
        spec_path,
        base_path,
        generation_state=False,
        expected_threat_count=3,
    )
    assert len(matching["ThreatInstances"]) == 3

    with pytest.raises(populate_tm7_threats.GenerationError) as conflict:
        populate_tm7_threats.populate_tm7_threats(
            spec_path,
            base_path,
            generation_state=False,
            expected_threat_count=80,
        )
    assert "expected 80 unique threat ids, found 3" in str(conflict.value)


def test_given_comprehensive_spec_when_validated_then_all_mappings_resolve() -> None:
    # Arrange
    with COMPREHENSIVE_SPEC_PATH.open("r", encoding="utf-8") as handle:
        spec = yaml.safe_load(handle) or {}
    threats = spec.get("threats") or []
    assert len(threats) == 80

    # Act
    errors = tm7_threat_contract.collect_mapping_failures(spec)

    # Assert
    assert errors == []


def test_given_reordered_threats_when_populated_then_output_is_deterministic(
    tmp_path: Path,
    complete_base: Path,
) -> None:
    # Arrange
    with COMPREHENSIVE_SPEC_PATH.open("r", encoding="utf-8") as handle:
        spec = yaml.safe_load(handle) or {}
    spec["threats"] = list(reversed(spec.get("threats") or []))

    spec_path = tmp_path / "reordered-spec.yaml"
    spec_path.write_text(yaml.safe_dump(spec), encoding="utf-8")
    base_path = complete_base
    output_path = tmp_path / "reordered.tm7"
    original_output_path = tmp_path / "original.tm7"

    # Act
    result = populate_tm7_threats.populate_tm7_threats(
        spec_path,
        base_path,
        output_path=output_path,
        generation_state=False,
    )
    populate_tm7_threats.populate_tm7_threats(
        COMPREHENSIVE_SPEC_PATH,
        base_path,
        output_path=original_output_path,
        generation_state=False,
    )

    # Assert
    instance_ids = [item["id"] for item in result["ThreatInstances"]]
    expected_ids = [
        tm7_threat_contract.derive_threat_numeric_id(str(threat["id"]))
        for threat in sorted(spec["threats"], key=lambda item: str(item["id"]))
    ]
    assert instance_ids == expected_ids
    assert len(set(instance_ids)) == 80
    assert output_path.read_bytes() == original_output_path.read_bytes()


def test_given_non_endpoint_mapping_without_override_when_populated_then_rejected(
    tmp_path: Path,
    complete_base: Path,
) -> None:
    # Arrange
    with COMPREHENSIVE_SPEC_PATH.open("r", encoding="utf-8") as handle:
        spec = yaml.safe_load(handle) or {}
    first_threat = next(
        threat for threat in spec.get("threats") or [] if isinstance(threat, dict)
    )
    first_threat["target_ref"] = "target-02"
    spec_path = tmp_path / "invalid-topology.yaml"
    spec_path.write_text(yaml.safe_dump(spec), encoding="utf-8")

    # Act and Assert
    with pytest.raises(
        populate_tm7_threats.GenerationError,
        match=r"placement_override is required",
    ):
        populate_tm7_threats.populate_tm7_threats(
            spec_path,
            complete_base,
            generation_state=False,
        )


def test_given_unknown_flow_reference_when_validated_then_reports_source_threat(
    tmp_path: Path,
    complete_base: Path,
) -> None:
    # Arrange
    with COMPREHENSIVE_SPEC_PATH.open("r", encoding="utf-8") as handle:
        spec = yaml.safe_load(handle) or {}
    first_threat = next(
        threat for threat in spec.get("threats") or [] if isinstance(threat, dict)
    )
    first_threat["interaction_ref"] = "missing-flow"
    spec_path = tmp_path / "invalid-spec.yaml"
    spec_path.write_text(yaml.safe_dump(spec), encoding="utf-8")

    # Act and Assert
    with pytest.raises(
        populate_tm7_threats.GenerationError,
        match=r"S-1: unknown interaction_ref missing-flow",
    ):
        populate_tm7_threats.populate_tm7_threats(
            spec_path,
            complete_base,
            generation_state=False,
        )


def test_given_output_path_matches_base_when_populated_then_refuses_in_place_write(
    tmp_path: Path,
) -> None:
    # Arrange
    output_path = tmp_path / "population.tm7"
    output_path.write_text("placeholder", encoding="utf-8")

    # Act and Assert
    with pytest.raises(
        populate_tm7_threats.GenerationError,
        match="Refusing to overwrite",
    ):
        populate_tm7_threats.populate_tm7_threats(
            COMPREHENSIVE_SPEC_PATH,
            output_path,
            output_path=output_path,
            generation_state=False,
        )


def test_given_production_base_when_writing_then_missing_connectors_block_output(
    tmp_path: Path,
) -> None:
    # Arrange
    output_path = tmp_path / "blocked.tm7"
    base_path = _write_base_missing_flow(tmp_path, "flow-21")

    # Act and Assert
    with pytest.raises(
        populate_tm7_threats.GenerationError,
        match=r"AX-1: authored-base connector flow-21 is absent",
    ):
        populate_tm7_threats.populate_tm7_threats(
            COMPREHENSIVE_SPEC_PATH,
            base_path,
            output_path=output_path,
            generation_state=False,
        )

    assert not output_path.exists()


def test_given_comprehensive_spec_when_inspected_then_ax_1_uses_scan_target_flow() -> (
    None
):
    # Arrange
    with COMPREHENSIVE_SPEC_PATH.open("r", encoding="utf-8") as handle:
        spec = yaml.safe_load(handle) or {}

    # Act
    threat = next(
        item
        for item in spec.get("threats") or []
        if isinstance(item, dict) and item.get("id") == "AX-1"
    )
    flow = next(
        item
        for item in spec.get("data_flows") or []
        if isinstance(item, dict) and item.get("id") == "flow-21"
    )

    # Assert
    assert threat["interaction_ref"] == "flow-21"
    assert threat["target_ref"] == "ext-scan-target"
    assert flow["source_ref"] == "ext-axe"
    assert flow["target_ref"] == "ext-scan-target"


def test_given_output_without_generation_state_when_populated_then_defaults_false(
    tmp_path: Path,
    complete_base: Path,
) -> None:
    # Arrange
    output_path = tmp_path / "candidate.tm7"

    # Act
    result = populate_tm7_threats.populate_tm7_threats(
        COMPREHENSIVE_SPEC_PATH,
        complete_base,
        output_path=output_path,
    )

    # Assert
    assert result["ThreatGenerationEnabled"] is False
    assert output_path.exists()


@pytest.mark.parametrize("subtree_name", ["DrawingSurfaceList", "KnowledgeBase"])
def test_given_semantic_subtree_mutation_when_populated_then_rejected(
    complete_base: Path,
    monkeypatch: pytest.MonkeyPatch,
    subtree_name: str,
) -> None:
    # Arrange
    base_path = complete_base
    original_serializer = populate_tm7_threats.serialize_threat_instances

    def mutate_subtree(root, threats, *, type_ids=None):
        prepared = original_serializer(root, threats, type_ids=type_ids)
        subtree = root.find(f"{{*}}{subtree_name}")
        assert subtree is not None
        subtree.set("mutated", "true")
        return prepared

    monkeypatch.setattr(
        populate_tm7_threats,
        "serialize_threat_instances",
        mutate_subtree,
    )

    # Act and Assert
    with pytest.raises(populate_tm7_threats.GenerationError, match="mutated"):
        populate_tm7_threats.populate_tm7_threats(
            COMPREHENSIVE_SPEC_PATH,
            base_path,
            generation_state=False,
        )


def test_given_separate_output_when_populated_then_base_bytes_remain_unchanged(
    tmp_path: Path,
    complete_base: Path,
) -> None:
    # Arrange
    base_path = complete_base
    original_bytes = base_path.read_bytes()
    output_path = tmp_path / "candidate.tm7"

    # Act
    result = populate_tm7_threats.populate_tm7_threats(
        COMPREHENSIVE_SPEC_PATH,
        base_path,
        output_path=output_path,
        generation_state=True,
    )

    # Assert
    assert base_path.read_bytes() == original_bytes
    assert result["ThreatGenerationEnabled"] is True
    assert (
        result["hashes"]["base_sha256_before"] == result["hashes"]["base_sha256_after"]
    )
    xml_text = output_path.read_text(encoding="utf-8")
    assert f'xmlns="{populate_tm7_threats.MODEL_NS}"' in xml_text
    assert f'xmlns:b="{populate_tm7_threats.KNOWLEDGE_NS}"' in xml_text
    assert f'xmlns:c="{populate_tm7_threats.XSD_NS}"' in xml_text
