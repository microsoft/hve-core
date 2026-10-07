# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Tests for Threat Dragon v2.6.2 generation."""

from __future__ import annotations

import copy
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

import pytest
import yaml

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_DIR = ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import generate_threat_dragon  # noqa: E402
import generate_tm7  # noqa: E402
from validate_threat_dragon import validate_file  # noqa: E402

SCRIPT_PATH = SCRIPTS_DIR / "generate_threat_dragon.py"
FIXTURES = ROOT / "tests" / "fixtures"
COMMERCE_SPEC = FIXTURES / "threat-dragon" / "commerce-spec.yaml"
COMMERCE_EXPECTED = (
    FIXTURES / "threat-dragon" / "expected" / "commerce.threat-dragon.json"
)
COMPREHENSIVE_SPEC = FIXTURES / "comprehensive-spec.yaml"
EXAMPLE_SPEC = ROOT / "templates" / "threat-model-spec-example.yaml"


def _run_cli(spec_path: Path, output_path: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT_PATH), str(spec_path), "-o", str(output_path)],
        capture_output=True,
        text=True,
        check=False,
    )


def _load_commerce_spec() -> dict[str, Any]:
    return yaml.safe_load(COMMERCE_SPEC.read_text(encoding="utf-8"))


def _write_spec(path: Path, spec: dict[str, Any]) -> Path:
    path.write_text(yaml.safe_dump(spec, sort_keys=False), encoding="utf-8")
    return path


def _cells(model: dict[str, Any], diagram: int) -> dict[str, dict[str, Any]]:
    return {
        cell["data"]["name"]: cell
        for cell in model["detail"]["diagrams"][diagram]["cells"]
    }


@pytest.fixture(scope="module")
def commerce_model(tmp_path_factory: pytest.TempPathFactory) -> dict[str, Any]:
    output = tmp_path_factory.mktemp("commerce") / "model.json"
    return generate_threat_dragon.generate(COMMERCE_SPEC, output)


def test_given_commerce_spec_when_generated_then_matches_golden(tmp_path: Path) -> None:
    # Arrange
    output = tmp_path / "model.json"

    # Act
    result = _run_cli(COMMERCE_SPEC, output)

    # Assert
    assert result.returncode == 0, result.stderr
    assert output.read_bytes() == COMMERCE_EXPECTED.read_bytes()


def test_given_same_spec_when_generated_twice_then_output_is_byte_identical(
    tmp_path: Path,
) -> None:
    # Arrange
    first = tmp_path / "first.json"
    second = tmp_path / "second.json"

    # Act
    generate_threat_dragon.generate(COMMERCE_SPEC, first)
    generate_threat_dragon.generate(COMMERCE_SPEC, second)

    # Assert
    assert first.read_bytes() == second.read_bytes()


@pytest.mark.parametrize(
    "spec_path", [COMMERCE_SPEC, COMPREHENSIVE_SPEC, EXAMPLE_SPEC], ids=lambda p: p.stem
)
def test_given_repository_spec_when_generated_then_model_validates(
    spec_path: Path, tmp_path: Path
) -> None:
    # Arrange
    output = tmp_path / "model.json"

    # Act
    generate_threat_dragon.generate(spec_path, output)

    # Assert
    assert validate_file(output) == []


def test_given_open_threats_when_generated_then_canvas_attributes_are_written(
    commerce_model: dict[str, Any],
) -> None:
    # Arrange
    cells = _cells(commerce_model, 0)

    # Act
    browse = cells["Browse and order"]
    pay = cells["Authorize payment"]
    web = cells["Web application"]
    payments = cells["Payment provider"]
    internet = cells["Internet"]

    # Assert
    assert browse["labels"][0]["attrs"]["label"]["text"] == "Browse and order"
    assert browse["attrs"]["line"]["stroke"] == "red"
    assert browse["attrs"]["line"]["strokeWidth"] == 2.5
    assert browse["attrs"]["line"]["sourceMarker"] == {"name": "block"}
    assert pay["attrs"]["line"]["stroke"] == "#333333"
    assert pay["attrs"]["line"]["sourceMarker"] == {"name": ""}
    assert web["attrs"]["text"]["text"] == "Web application"
    assert web["attrs"]["body"]["stroke"] == "red"
    assert payments["attrs"]["body"]["strokeDasharray"] == "4 3"
    assert payments["data"]["outOfScope"] is True
    assert internet["attrs"]["label"]["text"] == "Internet"


def test_given_store_when_generated_then_both_store_lines_are_styled(
    commerce_model: dict[str, Any],
) -> None:
    # Arrange
    store = _cells(commerce_model, 1)["Order store"]

    # Act
    attrs = store["attrs"]

    # Assert
    assert attrs["text"]["text"] == "Order store"
    assert attrs["topLine"] == attrs["bottomLine"]
    assert "body" not in attrs


def test_given_nested_zones_when_generated_then_parent_box_sits_below_child(
    commerce_model: dict[str, Any],
) -> None:
    # Arrange
    cells = _cells(commerce_model, 1)

    # Act
    platform = cells["Commerce platform"]
    data_tier = cells["Data tier"]
    store_id = cells["Order store"]["id"]

    # Assert
    assert platform["zIndex"] < data_tier["zIndex"]
    assert store_id in platform["data"]["containedElements"]
    assert data_tier["data"]["containedElements"] == [store_id]
    assert platform["data"]["crossingFlows"] == []


def test_given_threat_targets_when_generated_then_each_threat_is_placed_once(
    commerce_model: dict[str, Any],
) -> None:
    # Arrange
    placements = {
        threat["threatId"]: (diagram["id"], cell["data"]["name"])
        for diagram in commerce_model["detail"]["diagrams"]
        for cell in diagram["cells"]
        for threat in cell["data"]["threats"]
    }

    # Act
    numbers = sorted(
        threat["number"]
        for diagram in commerce_model["detail"]["diagrams"]
        for cell in diagram["cells"]
        for threat in cell["data"]["threats"]
    )

    # Assert
    assert placements == {
        "T-100": (0, "Browse and order"),
        "T-101": (1, "Order store"),
        "T-102": (1, "Web application"),
        "T-103": (0, "Web application"),
    }
    assert numbers == [0, 1, 2, 3]
    assert commerce_model["detail"]["threatTop"] == 3


def test_given_spec_states_and_risk_when_generated_then_native_values_are_mapped(
    commerce_model: dict[str, Any],
) -> None:
    # Arrange
    threats = {
        threat["threatId"]: threat
        for diagram in commerce_model["detail"]["diagrams"]
        for cell in diagram["cells"]
        for threat in cell["data"]["threats"]
    }

    # Act
    mapped = {
        key: (value["status"], value["severity"], value["type"])
        for key, value in threats.items()
    }

    # Assert
    assert mapped == {
        "T-100": ("Open", "High", "Tampering"),
        "T-101": ("Mitigated", "Low", "Information disclosure"),
        "T-102": ("NotApplicable", "TBD", "Denial of service"),
        "T-103": ("Open", "Critical", "Spoofing"),
    }
    assert "Risk: Informational" in threats["T-101"]["description"]
    assert "Placement flow: flow-browse" in threats["T-103"]["description"]
    assert threats["T-103"]["mitigation"].count(";") == 1


def test_given_absent_optional_fields_when_generated_then_properties_are_omitted(
    tmp_path: Path,
) -> None:
    # Arrange
    output = tmp_path / "model.json"

    # Act
    model = generate_threat_dragon.generate(EXAMPLE_SPEC, output)

    # Assert
    cells = [cell for d in model["detail"]["diagrams"] for cell in d["cells"]]
    flows = [cell for cell in cells if cell["shape"] == "flow"]
    processes = [cell for cell in cells if cell["shape"] == "process"]
    threats = [threat for cell in cells for threat in cell["data"]["threats"]]
    assert flows and processes and threats
    for flow in flows:
        assert not {"isBidirectional", "isEncrypted", "isPublicNetwork"} & set(
            flow["data"]
        )
        assert flow["attrs"]["line"]["sourceMarker"] == {"name": ""}
    for process in processes:
        assert "isWebApplication" not in process["data"]
    assert {threat["severity"] for threat in threats} == {"TBD"}
    assert model["summary"]["owner"] == ""


def test_given_option_for_wrong_element_kind_when_generated_then_exit_two(
    tmp_path: Path,
) -> None:
    # Arrange
    spec = _load_commerce_spec()
    spec["export_options"]["threat_dragon"]["elements"]["ds-orders"] = {
        "is_web_application": True
    }
    spec_path = _write_spec(tmp_path / "spec.yaml", spec)
    output = tmp_path / "model.json"

    # Act
    result = _run_cli(spec_path, output)

    # Assert
    assert result.returncode == 2
    assert "applies only to process elements" in result.stderr
    assert not output.exists()


@pytest.mark.parametrize(
    ("path", "value", "message"),
    [
        (("data_flows", 0, "bidirectional"), "yes", "must be true or false"),
        (("threats", 0, "severity"), "severe", "severity must be one of"),
    ],
)
def test_given_invalid_optional_value_when_generated_then_generation_fails(
    tmp_path: Path, path: tuple[Any, ...], value: Any, message: str
) -> None:
    # Arrange
    spec = _load_commerce_spec()
    target = spec
    for key in path[:-1]:
        target = target[key]
    target[path[-1]] = value
    spec_path = _write_spec(tmp_path / "spec.yaml", spec)

    # Act and Assert
    with pytest.raises(generate_tm7.GenerationError, match=message):
        generate_threat_dragon.generate(spec_path, tmp_path / "model.json")


def test_given_trust_boundary_line_element_when_generated_then_exit_two_without_output(
    tmp_path: Path,
) -> None:
    # Arrange
    spec = _load_commerce_spec()
    spec["components"].append(
        {
            "id": "line-01",
            "name": "Perimeter line",
            "kind": "trust_boundary_line",
            "trust_zone_id": "tz-platform",
            "layout_role": "contextual",
        }
    )
    spec["representations"]["context_diagrams"][0]["elements"].append({"id": "line-01"})
    spec_path = _write_spec(tmp_path / "spec.yaml", spec)
    output = tmp_path / "model.json"

    # Act
    result = _run_cli(spec_path, output)

    # Assert
    assert result.returncode == 2
    assert "line-01" in result.stderr
    assert "trust_boundary_line" in result.stderr
    assert not output.exists()


def test_given_threat_generation_with_abuse_cases_when_generated_then_abuse_is_skipped(
    tmp_path: Path,
) -> None:
    # Arrange
    spec = yaml.safe_load(EXAMPLE_SPEC.read_text(encoding="utf-8"))
    spec["threat_generation_enabled"] = True
    spec["abuse_cases"].append(
        {
            "id": "abuse-02",
            "title": "Abuse case without a flow",
            "description": "No flow is linked to this abuse case",
        }
    )
    spec_path = _write_spec(tmp_path / "spec.yaml", spec)
    output = tmp_path / "model.json"

    # Act
    result = _run_cli(spec_path, output)

    # Assert
    assert result.returncode == 0, result.stderr
    assert validate_file(output) == []
    model = json.loads(output.read_text(encoding="utf-8"))
    threat_ids = [
        threat["threatId"]
        for diagram in model["detail"]["diagrams"]
        for cell in diagram["cells"]
        for threat in cell["data"]["threats"]
    ]
    assert not [tid for tid in threat_ids if tid.startswith("abuse-")]
    assert len(threat_ids) == len(set(threat_ids))
    assert any(tid.startswith("generated-") for tid in threat_ids)
    assert {"threat-01", "threat-02"} <= set(threat_ids)


def test_given_existing_output_when_validation_fails_then_output_is_preserved(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    # Arrange
    output = tmp_path / "model.json"
    output.write_text("previous", encoding="utf-8")
    monkeypatch.setattr(
        generate_threat_dragon, "validate_file", lambda _path: ["forced failure"]
    )

    # Act
    with pytest.raises(generate_tm7.GenerationError, match="forced failure"):
        generate_threat_dragon.generate(COMMERCE_SPEC, output)

    # Assert
    assert output.read_text(encoding="utf-8") == "previous"
    assert sorted(path.name for path in tmp_path.iterdir()) == ["model.json"]


def test_given_optional_fields_when_tm7_generated_then_tm7_output_is_unchanged(
    tmp_path: Path,
) -> None:
    # Arrange
    spec = yaml.safe_load(COMPREHENSIVE_SPEC.read_text(encoding="utf-8"))
    extended = copy.deepcopy(spec)
    extended["project_metadata"]["owner"] = "Platform security"
    extended["components"][0]["out_of_scope"] = True
    extended["components"][0]["out_of_scope_reason"] = "Provider managed"
    extended["data_flows"][0].update(
        {"bidirectional": True, "public_network": False, "encrypted": True}
    )
    extended["threats"][0].update(
        {"severity": "high", "likelihood": "low", "impact": "high", "risk": "medium"}
    )
    extended["export_options"] = {"threat_dragon": {"elements": {}}}
    baseline_path = _write_spec(tmp_path / "baseline.yaml", spec)
    extended_path = _write_spec(tmp_path / "extended.yaml", extended)
    outputs = []

    # Act
    for name, spec_path in (("baseline", baseline_path), ("extended", extended_path)):
        output = tmp_path / f"{name}.tm7"
        generate_tm7.generate_tm7_candidate(
            spec_path=spec_path,
            output_path=output,
            template=None,
            mode=None,
            update_path=None,
            overlay_path=None,
        )
        outputs.append(output.read_bytes())

    # Assert
    assert outputs[0] == outputs[1]


def test_given_golden_when_loaded_then_it_is_valid_json() -> None:
    # Arrange
    text = COMMERCE_EXPECTED.read_text(encoding="utf-8")

    # Act
    model = json.loads(text)

    # Assert
    assert model["version"] == "2.6.2"
    assert text.endswith("\n") and "\r" not in text
