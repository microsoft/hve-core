# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Mutation-focused tests for the shared TM7 threat contract."""

from __future__ import annotations

import copy
import os
import subprocess
import sys
import threading
from collections.abc import Iterator
from pathlib import Path
from xml.etree import ElementTree as ET

import pytest

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_DIR = ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import generate_tb7  # noqa: E402
import generate_tm7  # noqa: E402
import populate_tm7_threats  # noqa: E402
import tm7_threat_contract  # noqa: E402

XXE_DOCUMENT = (
    '<?xml version="1.0"?>\n'
    '<!DOCTYPE root [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>\n'
    "<root>&xxe;</root>\n"
)


@pytest.mark.parametrize("encoding", ["utf-8", "utf-16", "utf-16-le", "utf-16-be"])
@pytest.mark.parametrize(
    "reader",
    ["contract", "generate_tm7", "populate", "generate_tb7"],
)
def test_given_entity_declaration_when_parsed_then_every_reader_fails_closed(
    tmp_path: Path,
    encoding: str,
    reader: str,
) -> None:
    """Every XML entry point must reject DTD and entity declarations.

    The guard was a byte scan for `<!DOCTYPE`, which only matches UTF-8. The
    same document encoded as UTF-16 interleaves NUL bytes, so the marker never
    appeared and the check silently passed. Encoding is therefore a test axis
    rather than an incidental detail.
    """
    # Arrange
    data = XXE_DOCUMENT.encode(encoding)
    path = tmp_path / "payload.xml"
    path.write_bytes(data)

    readers = {
        "contract": lambda: tm7_threat_contract.parse_hardened_xml_bytes(data),
        "generate_tm7": lambda: generate_tm7._parse_hardened_xml_bytes(data),
        "populate": lambda: populate_tm7_threats._parse_model(path),
        "generate_tb7": lambda: generate_tb7._load_source_template(path),
    }
    expected = {
        "contract": tm7_threat_contract.UnsafeXmlError,
        "generate_tm7": generate_tm7.GenerationError,
        "populate": populate_tm7_threats.GenerationError,
        "generate_tb7": generate_tb7.GenerationError,
    }

    # Act and Assert
    with pytest.raises(expected[reader]):
        readers[reader]()


TYPE_ID = "TH-test"
GUIDS = {
    "drawing_surface_guid": "11111111-1111-1111-1111-111111111111",
    "source_guid": "22222222-2222-2222-2222-222222222222",
    "flow_guid": "33333333-3333-3333-3333-333333333333",
    "target_guid": "44444444-4444-4444-4444-444444444444",
}


def _threat(source_id: str = "threat-01") -> dict[str, object]:
    interaction_key = tm7_threat_contract.build_interaction_key(
        GUIDS["source_guid"],
        GUIDS["flow_guid"],
        GUIDS["target_guid"],
    )
    dictionary_key = tm7_threat_contract.build_entry_key(
        TYPE_ID,
        GUIDS["source_guid"],
        GUIDS["flow_guid"],
        GUIDS["target_guid"],
    )
    return {
        "source_id": source_id,
        "interaction_ref": "flow-01",
        "title": "Threat title",
        "description": "Threat description",
        "category": "tampering",
        "state": "Open",
        "mitigations": "Apply mitigation",
        "type_id": TYPE_ID,
        **GUIDS,
        "interaction_key": interaction_key,
        "dictionary_key": dictionary_key,
    }


def _serialized_entries(count: int = 1) -> ET.Element:
    threats = [_threat(f"threat-{index:02d}") for index in range(1, count + 1)]
    if count > 1:
        for index, threat in enumerate(threats, start=1):
            flow_guid = f"33333333-3333-3333-3333-{index:012d}"
            threat["flow_guid"] = flow_guid
            threat["interaction_key"] = tm7_threat_contract.build_interaction_key(
                str(threat["source_guid"]),
                flow_guid,
                str(threat["target_guid"]),
            )
            threat["dictionary_key"] = tm7_threat_contract.build_entry_key(
                TYPE_ID,
                str(threat["source_guid"]),
                flow_guid,
                str(threat["target_guid"]),
            )
    root = ET.Element("ThreatModel")
    tm7_threat_contract.serialize_threat_instances(
        root,
        threats,
        type_ids={TYPE_ID},
    )
    threat_instances = root.find("ThreatInstances")
    assert threat_instances is not None
    return threat_instances


def _first_entry(threat_instances: ET.Element) -> ET.Element:
    entry = threat_instances.find("{*}KeyValueOfstringThreatpc_P0_PhOB")
    assert entry is not None
    return entry


@pytest.mark.parametrize("invalid_id", ["abc", "0", "-1"])
def test_given_invalid_numeric_id_when_validated_then_rejected(invalid_id: str) -> None:
    # Arrange
    entry = _first_entry(_serialized_entries())
    id_node = entry.find("{*}Value/{*}Id")
    assert id_node is not None
    id_node.text = invalid_id

    # Act and Assert
    with pytest.raises(
        tm7_threat_contract.ThreatContractError,
        match="positive integer",
    ):
        tm7_threat_contract.validate_serialized_threat_entry(entry)


def test_given_missing_type_id_when_validated_then_rejected() -> None:
    # Arrange
    entry = _first_entry(_serialized_entries())
    type_node = entry.find("{*}Value/{*}TypeId")
    assert type_node is not None
    type_node.text = None

    # Act and Assert
    with pytest.raises(tm7_threat_contract.ThreatContractError, match="required"):
        tm7_threat_contract.validate_serialized_threat_entry(entry)


def test_given_connector_name_when_serialized_then_interaction_string_uses_name() -> (
    None
):
    # Arrange
    threat = _threat()
    threat["interaction_string"] = "Submit request over HTTPS"

    # Act
    properties = dict(tm7_threat_contract.build_threat_instance_properties(threat))

    # Assert
    assert properties["InteractionString"] == "Submit request over HTTPS"


def test_given_unknown_type_id_when_validated_then_rejected() -> None:
    # Arrange
    entry = _first_entry(_serialized_entries())

    # Act and Assert
    with pytest.raises(
        tm7_threat_contract.ThreatContractError,
        match="not embedded",
    ):
        tm7_threat_contract.validate_serialized_threat_entry(
            entry,
            type_ids={"another-type"},
        )


def test_given_bad_member_order_when_validated_then_rejected() -> None:
    # Arrange
    entry = _first_entry(_serialized_entries())
    value = entry.find("{*}Value")
    assert value is not None
    first = value[0]
    value.remove(first)
    value.append(first)

    # Act and Assert
    with pytest.raises(tm7_threat_contract.ThreatContractError, match="order"):
        tm7_threat_contract.validate_serialized_threat_entry(entry)


def test_given_bad_dictionary_key_when_validated_then_rejected() -> None:
    # Arrange
    entry = _first_entry(_serialized_entries())
    key = entry.find("{*}Key")
    assert key is not None
    key.text = "bad-key"

    # Act and Assert
    with pytest.raises(
        tm7_threat_contract.ThreatContractError,
        match="dictionary_key",
    ):
        tm7_threat_contract.validate_serialized_threat_entry(entry)


def test_given_duplicate_numeric_id_when_collection_validated_then_rejected() -> None:
    # Arrange
    threat_instances = _serialized_entries(2)
    entries = threat_instances.findall("{*}KeyValueOfstringThreatpc_P0_PhOB")
    first_id = entries[0].find("{*}Value/{*}Id")
    second_id = entries[1].find("{*}Value/{*}Id")
    assert first_id is not None
    assert second_id is not None
    second_id.text = first_id.text

    # Act and Assert
    with pytest.raises(tm7_threat_contract.ThreatContractError, match="duplicate"):
        tm7_threat_contract.validate_serialized_threat_entries(threat_instances)


def test_given_duplicate_key_when_collection_validated_then_rejected() -> None:
    # Arrange
    threat_instances = _serialized_entries(2)
    entries = threat_instances.findall("{*}KeyValueOfstringThreatpc_P0_PhOB")
    first_key = entries[0].findtext("{*}Key")
    second_key = entries[1].find("{*}Key")
    first_value = entries[0].find("{*}Value")
    second_value = entries[1].find("{*}Value")
    assert second_key is not None
    assert first_value is not None
    assert second_value is not None
    second_key.text = first_key
    entries[1].remove(second_value)
    cloned_value = copy.deepcopy(first_value)
    cloned_id = cloned_value.find("{*}Id")
    assert cloned_id is not None
    cloned_id.text = "2"
    entries[1].append(cloned_value)

    # Act and Assert
    with pytest.raises(tm7_threat_contract.ThreatContractError, match="duplicate"):
        tm7_threat_contract.validate_serialized_threat_entries(threat_instances)


def test_given_null_guid_when_validated_then_rejected() -> None:
    # Arrange
    entry = _first_entry(_serialized_entries())
    source_guid = entry.find("{*}Value/{*}SourceGuid")
    assert source_guid is not None
    source_guid.text = tm7_threat_contract.NULL_GUID

    # Act and Assert
    with pytest.raises(tm7_threat_contract.ThreatContractError, match="non-null"):
        tm7_threat_contract.validate_serialized_threat_entry(entry)


def test_given_unsupported_state_when_validated_then_rejected() -> None:
    # Arrange
    entry = _first_entry(_serialized_entries())
    state = entry.find("{*}Value/{*}State")
    assert state is not None
    state.text = "Unsupported"

    # Act and Assert
    with pytest.raises(tm7_threat_contract.ThreatContractError, match="unsupported"):
        tm7_threat_contract.validate_serialized_threat_entry(entry)


def test_given_missing_interaction_ref_when_mapping_validated_then_rejected() -> None:
    # Arrange
    spec = _mapping_spec()
    spec["threats"][0].pop("interaction_ref")

    # Act
    failures = tm7_threat_contract.collect_mapping_failures(spec)

    # Assert
    assert failures == ["threat-01: missing interaction_ref"]


def test_given_unknown_flow_when_mapping_validated_then_rejected() -> None:
    # Arrange
    spec = _mapping_spec()
    spec["threats"][0]["interaction_ref"] = "unknown"

    # Act
    failures = tm7_threat_contract.collect_mapping_failures(spec)

    # Assert
    assert failures == ["threat-01: unknown interaction_ref unknown"]


def test_given_non_endpoint_without_override_when_validated_then_rejected() -> None:
    # Arrange
    spec = _mapping_spec()
    spec["threats"][0]["target_ref"] = "target-02"

    # Act
    failures = tm7_threat_contract.collect_mapping_failures(spec)

    # Assert
    assert failures == [
        "threat-01: semantic target target-02 is not an endpoint of "
        "interaction_ref flow-01 and placement_override is required"
    ]


def test_given_reviewed_override_when_non_endpoint_validated_then_passes() -> None:
    # Arrange
    spec = _mapping_spec()
    spec["threats"][0]["target_ref"] = "target-02"
    spec["threats"][0]["placement_override"] = {
        "rationale": "The placement carrier is reviewed for this non-endpoint mapping.",
        "reviewed": True,
    }

    # Act
    failures = tm7_threat_contract.collect_mapping_failures(spec)

    # Assert
    assert failures == []


@pytest.mark.parametrize(
    "override",
    [
        {"rationale": "Needs review", "reviewed": False},
        {"rationale": "", "reviewed": True},
        {"reviewed": True},
        "reviewed",
    ],
)
def test_given_invalid_override_when_non_endpoint_mapping_validated_then_rejected(
    override: object,
) -> None:
    # Arrange
    spec = _mapping_spec()
    spec["threats"][0]["target_ref"] = "target-02"
    spec["threats"][0]["placement_override"] = override

    # Act
    failures = tm7_threat_contract.collect_mapping_failures(spec)

    # Assert
    assert failures == [
        "threat-01: semantic target target-02 is not an endpoint of "
        "interaction_ref flow-01 and placement_override is required"
    ]


def test_given_portable_valid_spec_without_base_when_reconciled_then_passes() -> None:
    # Arrange
    spec = _mapping_spec()

    # Act
    failures = tm7_threat_contract.reconcile_authored_base(spec, None)

    # Assert
    assert failures == []


def test_given_missing_connector_when_reconciled_then_absence_is_reported() -> None:
    # Arrange
    spec = _mapping_spec()
    authored_base = {
        "connectors": {},
        "surfaces": [_authored_surface("surface-01")],
    }

    # Act
    failures = tm7_threat_contract.reconcile_authored_base(spec, authored_base)

    # Assert
    assert failures == ["threat-01: authored-base connector flow-01 is absent"]


def test_given_wrong_authored_surface_when_reconciled_then_reports_mismatch() -> None:
    # Arrange
    spec = _mapping_spec()
    authored_base = {
        "connectors": {
            "flow-01": {
                "drawing_surface_guid": "surface-guid-02",
                "flow_guid": "flow-guid",
                "source_guid": "source-guid",
                "target_guid": "target-guid",
            }
        },
        "surfaces": [
            _authored_surface("surface-01"),
            _authored_surface("surface-02"),
        ],
    }

    # Act
    failures = tm7_threat_contract.reconcile_authored_base(spec, authored_base)

    # Assert
    assert failures == ["threat-01: authored-base surface mismatch for flow-01"]


def test_given_null_authored_endpoints_when_reconciled_then_reports_null_guid() -> None:
    # Arrange
    spec = _mapping_spec()
    authored_base = {
        "connectors": {
            "flow-01": {
                "drawing_surface_guid": "surface-guid-01",
                "flow_guid": "flow-guid",
                "source_guid": tm7_threat_contract.NULL_GUID,
                "target_guid": "target-guid",
            }
        },
        "surfaces": [_authored_surface("surface-01")],
    }

    # Act
    failures = tm7_threat_contract.reconcile_authored_base(spec, authored_base)

    # Assert
    assert failures == ["threat-01: authored-base connector flow-01 has null GUIDs"]


def test_given_authored_endpoint_mismatch_when_reconciled_then_reports_identity() -> (
    None
):
    # Arrange
    spec = _mapping_spec()
    authored_base = {
        "connectors": {
            "flow-01": {
                "drawing_surface_guid": "surface-guid-01",
                "flow_guid": "flow-guid",
                "source_guid": "other-source-guid",
                "target_guid": "target-guid",
            }
        },
        "surfaces": [_authored_surface("surface-01")],
    }

    # Act
    failures = tm7_threat_contract.reconcile_authored_base(spec, authored_base)

    # Assert
    assert failures == [
        "threat-01: authored-base connector flow-01 endpoint identity mismatch"
    ]


def test_given_reordered_authored_surfaces_when_reconciled_then_identity_binds() -> (
    None
):
    """Authored order must not decide which surface a connector belongs to."""
    # Arrange
    spec = _mapping_spec()
    connectors = {
        "flow-01": [
            {
                "drawing_surface_guid": "surface-guid-01",
                "flow_guid": "flow-guid",
                "source_guid": "source-guid",
                "target_guid": "target-guid",
            }
        ]
    }
    ordered = {
        "connectors": connectors,
        "surfaces": [
            _authored_surface("surface-01"),
            _authored_surface("surface-99"),
        ],
    }
    reordered = {
        "connectors": connectors,
        "surfaces": list(reversed(ordered["surfaces"])),
    }

    # Act
    ordered_failures = tm7_threat_contract.reconcile_authored_base(spec, ordered)
    reordered_failures = tm7_threat_contract.reconcile_authored_base(spec, reordered)

    # Assert
    assert ordered_failures == []
    assert reordered_failures == []


def test_given_unmatched_declared_surface_when_reconciled_then_absence_is_named() -> (
    None
):
    # Arrange
    spec = _mapping_spec()
    authored_base = {
        "connectors": {},
        "surfaces": [_authored_surface("surface-99")],
    }

    # Act
    failures = tm7_threat_contract.reconcile_authored_base(spec, authored_base)

    # Assert
    assert failures == [
        "threat-01: authored-base surface surface-01 for flow-01 is absent"
    ]


def test_given_duplicate_authored_surface_when_reconciled_then_duplication_fails() -> (
    None
):
    # Arrange
    spec = _mapping_spec()
    authored_base = {
        "connectors": {},
        "surfaces": [
            _authored_surface("surface-01"),
            _authored_surface("surface-01"),
        ],
    }

    # Act
    failures = tm7_threat_contract.reconcile_authored_base(spec, authored_base)

    # Assert
    assert failures == [
        "authored-base surface surface-01 is declared more than once",
        "threat-01: authored-base connector flow-01 is absent",
    ]


def test_given_non_mapping_authored_base_when_reconciled_then_shape_is_rejected() -> (
    None
):
    # Arrange
    spec = _mapping_spec()

    # Act
    failures = tm7_threat_contract.reconcile_authored_base(spec, [])

    # Assert
    assert failures == ["authored base must be an index mapping"]


def test_given_reordered_sources_when_prepared_then_numeric_ids_are_stable() -> None:
    # Arrange
    first = _threat("threat-a")
    second = copy.deepcopy(_threat("threat-b"))
    second["flow_guid"] = "55555555-5555-5555-5555-555555555555"
    second["interaction_key"] = tm7_threat_contract.build_interaction_key(
        str(second["source_guid"]),
        str(second["flow_guid"]),
        str(second["target_guid"]),
    )
    second["dictionary_key"] = tm7_threat_contract.build_entry_key(
        TYPE_ID,
        str(second["source_guid"]),
        str(second["flow_guid"]),
        str(second["target_guid"]),
    )

    # Act
    original = tm7_threat_contract.prepare_threat_instances([first, second])
    reordered = tm7_threat_contract.prepare_threat_instances([second, first])

    # Assert
    assert [(item["source_id"], item["id"]) for item in original] == [
        (item["source_id"], item["id"]) for item in reordered
    ]


def _distinct_threat(source_id: str, ordinal: int) -> dict[str, object]:
    """Return a threat whose GUID tuple is unique within a collection."""
    threat = copy.deepcopy(_threat(source_id))
    flow_guid = f"33333333-3333-3333-3333-{ordinal:012d}"
    threat["flow_guid"] = flow_guid
    threat["interaction_key"] = tm7_threat_contract.build_interaction_key(
        str(threat["source_guid"]),
        flow_guid,
        str(threat["target_guid"]),
    )
    threat["dictionary_key"] = tm7_threat_contract.build_entry_key(
        TYPE_ID,
        str(threat["source_guid"]),
        flow_guid,
        str(threat["target_guid"]),
    )
    return threat


def test_given_inserted_threat_when_prepared_then_existing_ids_are_unchanged() -> None:
    """Adding a threat must not renumber the threats already in the model.

    Numeric ids were the 1-based position in a sorted list, so inserting one
    threat silently reassigned every id that sorted after it. Reviewers and
    exported worksheets track threats by that visible number.
    """
    # Arrange
    first = _distinct_threat("threat-aa", 1)
    last = _distinct_threat("threat-zz", 2)
    inserted = _distinct_threat("threat-mm", 3)

    # Act
    before = {
        str(item["source_id"]): item["id"]
        for item in tm7_threat_contract.prepare_threat_instances([first, last])
    }
    after = {
        str(item["source_id"]): item["id"]
        for item in tm7_threat_contract.prepare_threat_instances(
            [first, inserted, last]
        )
    }

    # Assert
    assert after["threat-aa"] == before["threat-aa"]
    assert after["threat-zz"] == before["threat-zz"]
    assert after["threat-mm"] not in before.values()


@pytest.mark.parametrize(
    ("source_id", "expected_id"),
    [
        ("threat-01", 1806730184),
        ("T-01", 221371277),
        ("T-80", 964846201),
    ],
)
def test_given_known_source_id_when_derived_then_the_recorded_value_is_emitted(
    source_id: str,
    expected_id: int,
) -> None:
    """Derived ids must match recorded constants, not merely agree with themselves.

    Every other id test computes its expectation by calling the same derivation,
    so swapping the digest or the mapping would shift all of them together and
    still pass. These constants are the only in-suite evidence that the emitted
    identifier a reviewer or CSV export cites is the one previously published.
    """
    # Act
    derived = tm7_threat_contract.derive_threat_numeric_id(source_id)

    # Assert
    assert derived == expected_id


def test_given_fresh_process_when_id_derived_then_the_value_matches() -> None:
    """A restarted interpreter must derive the same numeric id.

    ``PYTHONHASHSEED`` randomizes the built-in ``hash`` per process, so an id
    built on it would drift between runs while looking stable inside one test
    session. Only a separate interpreter with a hostile seed observes that.
    """
    # Arrange
    source_id = "threat-stability-probe"
    in_process = tm7_threat_contract.derive_threat_numeric_id(source_id)
    program = (
        "import sys; sys.path.insert(0, sys.argv[1]); "
        "import tm7_threat_contract as contract; "
        "print(contract.derive_threat_numeric_id(sys.argv[2]))"
    )
    environment = {**os.environ, "PYTHONHASHSEED": "12345"}

    # Act
    completed = subprocess.run(
        [sys.executable, "-c", program, str(SCRIPTS_DIR), source_id],
        capture_output=True,
        text=True,
        check=True,
        env=environment,
    )

    # Assert
    assert int(completed.stdout.strip()) == in_process


@pytest.mark.parametrize(
    "source_id",
    ["a", "threat-01", "T-80", "\u5a01\u80c1-\u03a9", "x" * 512, "0", "-"],
)
def test_given_any_source_id_when_derived_then_id_stays_in_the_interval(
    source_id: str,
) -> None:
    """Derived ids must stay inside the signed 32-bit interval with 0 reserved."""
    # Act
    numeric_id = tm7_threat_contract.derive_threat_numeric_id(source_id)

    # Assert
    assert numeric_id != 0
    assert (
        tm7_threat_contract.THREAT_ID_MIN
        <= numeric_id
        <= tm7_threat_contract.THREAT_ID_MAX
    )


@pytest.mark.parametrize(
    "numeric_id",
    [tm7_threat_contract.THREAT_ID_MIN, tm7_threat_contract.THREAT_ID_MAX],
)
def test_given_interval_boundary_id_when_serialized_then_text_round_trips(
    numeric_id: int,
) -> None:
    """Both interval endpoints must serialize as exact decimal text."""
    # Arrange
    threat = {**_threat(), "id": numeric_id, "state": "Open"}

    # Act
    value = tm7_threat_contract.serialize_threat_instance(threat)

    # Assert
    rendered = value.find(f"{{{tm7_threat_contract.KNOWLEDGE_NS}}}Id")
    assert rendered is not None
    assert rendered.text == str(numeric_id)


@pytest.mark.parametrize(
    "numeric_id",
    [0, -1, tm7_threat_contract.THREAT_ID_MAX + 1, True, "1"],
)
def test_given_out_of_interval_id_when_validated_then_contract_fails(
    numeric_id: object,
) -> None:
    """Ids outside the documented interval must be rejected, including booleans."""
    # Arrange
    threat = {**_threat(), "id": numeric_id}

    # Act and Assert
    with pytest.raises(tm7_threat_contract.ThreatContractError, match="threat id"):
        tm7_threat_contract.validate_threat_instance(threat)


def test_given_forced_id_collision_when_prepared_then_failure_is_deterministic(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Two source ids mapping to one numeric id must fail, naming both."""
    # Arrange
    first = _distinct_threat("threat-aa", 1)
    second = _distinct_threat("threat-bb", 2)
    monkeypatch.setattr(
        tm7_threat_contract,
        "derive_threat_numeric_id",
        lambda source_id: 7,
    )

    # Act and Assert
    with pytest.raises(tm7_threat_contract.ThreatContractError) as error:
        tm7_threat_contract.prepare_threat_instances([second, first])
    assert "threat-aa and threat-bb both derive numeric id 7" in str(error.value)


def test_given_equivalent_threats_when_both_producers_run_then_contracts_agree() -> (
    None
):
    """Both TM7 producers must agree on type identity and threat properties.

    ``generate_tm7`` and ``populate_tm7_threats`` emit the same ThreatInstance
    DataContract. Divergent slug derivation makes custom type identifiers differ
    for punctuation-bearing ids, and an unresolved mitigation leaves
    ``PossibleMitigations`` empty on one path only.
    """
    # Arrange
    spec = {
        "mitigations": [
            {"id": "M-1", "description": "Pin every dependency by digest."},
        ],
        "threats": [
            {
                "id": "S--1",
                "title": "Punctuated identifier",
                "description": "Adjacent punctuation in the identifier.",
                "mitigation_ids": ["M-1"],
            }
        ],
    }
    threat = spec["threats"][0]

    # Act
    generated_type_id = generate_tm7._stable_custom_threat_type_id("S--1", threat)
    populated_type_id = populate_tm7_threats._resolve_type_id(threat, {}, {})
    mitigation_text = populate_tm7_threats._mitigation_text(spec, threat)
    generated_properties = dict(
        tm7_threat_contract.build_threat_instance_properties(
            {
                **threat,
                "mitigations": generate_tm7._resolve_mitigation_text(spec, threat),
            }
        )
    )
    populated_properties = dict(
        tm7_threat_contract.build_threat_instance_properties(
            {**threat, "mitigations": mitigation_text}
        )
    )

    # Assert
    assert generated_type_id == populated_type_id
    assert generated_properties == populated_properties
    assert generated_properties["PossibleMitigations"] == (
        "Pin every dependency by digest."
    )


def test_given_authored_labels_when_reconciled_then_semantic_ids_resolve() -> None:
    """Authored-base lookup must key on the stable identifier, not the label.

    A connector's first display attribute is its human-facing ``Name``, which the
    generator sets from ``display_label``. Resolving connectors through that value
    makes every relabelled flow unresolvable, because reconciliation looks the
    connector up by ``interaction_ref``.
    """
    # Arrange
    spec = _mapping_spec()
    spec["data_flows"][0]["display_label"] = "Authenticated read path"
    surface_guid = populate_tm7_threats._deterministic_guid("surface:surface-01")
    authored_model = ET.fromstring(
        f"""
        <ThreatModel>
          <DrawingSurfaceList>
            <DrawingSurfaceModel>
              <Guid>{surface_guid}</Guid>
              <Borders>
                <KeyValueOfguidanyType>
                  <Value>
                    <Guid>source-guid</Guid>
                    <Properties>
                      <anyType>
                        <DisplayName>Name</DisplayName>
                        <Value>source-01</Value>
                      </anyType>
                    </Properties>
                  </Value>
                </KeyValueOfguidanyType>
                <KeyValueOfguidanyType>
                  <Value>
                    <Guid>target-guid</Guid>
                    <Properties>
                      <anyType>
                        <DisplayName>Name</DisplayName>
                        <Value>target-01</Value>
                      </anyType>
                    </Properties>
                  </Value>
                </KeyValueOfguidanyType>
              </Borders>
              <Lines>
                <KeyValueOfguidanyType>
                  <Value>
                    <Guid>flow-guid</Guid>
                    <Properties>
                      <anyType>
                        <DisplayName>Name</DisplayName>
                        <Value>Authenticated read path</Value>
                      </anyType>
                    </Properties>
                    <SourceGuid>source-guid</SourceGuid>
                    <TargetGuid>target-guid</TargetGuid>
                  </Value>
                </KeyValueOfguidanyType>
              </Lines>
            </DrawingSurfaceModel>
          </DrawingSurfaceList>
        </ThreatModel>
        """.strip()
    )
    authored_base = populate_tm7_threats._build_authored_base_index(
        spec, authored_model
    )

    # Act
    failures = tm7_threat_contract.reconcile_authored_base(spec, authored_base)

    # Assert
    assert authored_base["surfaces"][0]["id"] == "surface-01"
    assert failures == []


def test_given_reordered_authored_model_when_indexed_then_surfaces_keep_identity() -> (
    None
):
    """Swapping authored drawing surfaces must not rebind them to other diagrams."""
    # Arrange
    first_guid = populate_tm7_threats._deterministic_guid("surface:surface-01")
    second_guid = populate_tm7_threats._deterministic_guid("surface:surface-02")
    spec = _mapping_spec()
    spec["representations"]["context_diagrams"].append(
        {
            "id": "surface-02",
            "elements": [{"id": "source-01"}, {"id": "target-01"}],
            "flows": [],
        }
    )
    reordered = ET.fromstring(
        f"""
        <ThreatModel>
          <DrawingSurfaceList>
            <DrawingSurfaceModel><Guid>{second_guid}</Guid></DrawingSurfaceModel>
            <DrawingSurfaceModel><Guid>{first_guid}</Guid></DrawingSurfaceModel>
          </DrawingSurfaceList>
        </ThreatModel>
        """.strip()
    )

    # Act
    index = populate_tm7_threats._build_authored_base_index(spec, reordered)

    # Assert
    assert [entry["id"] for entry in index["surfaces"]] == [
        "surface-02",
        "surface-01",
    ]


def _authored_surface(surface_id: str) -> dict[str, object]:
    """Return one authored-base surface entry in the single supported shape."""
    ordinal = surface_id.rsplit("-", 1)[-1]
    return {
        "id": surface_id,
        "guid": f"surface-guid-{ordinal}",
        "elements": {"source-01": "source-guid", "target-01": "target-guid"},
    }


def _mapping_spec() -> dict[str, object]:
    return {
        "representations": {
            "context_diagrams": [
                {
                    "id": "surface-01",
                    "elements": [
                        {"id": "source-01"},
                        {"id": "target-01"},
                        {"id": "target-02"},
                    ],
                    "flows": ["flow-01"],
                }
            ]
        },
        "data_flows": [
            {
                "id": "flow-01",
                "source_ref": "source-01",
                "target_ref": "target-01",
            }
        ],
        "threats": [
            {
                "id": "threat-01",
                "target_ref": "target-01",
                "interaction_ref": "flow-01",
            }
        ],
    }


@pytest.fixture
def caller_namespace_registry() -> Iterator[dict[str, str]]:
    """Register a caller-owned prefix and restore the process registry after."""
    original = dict(ET._namespace_map)
    ET.register_namespace("caller", "urn:caller-owned")
    snapshot = dict(ET._namespace_map)
    try:
        yield snapshot
    finally:
        ET._namespace_map.clear()
        ET._namespace_map.update(original)


def test_given_prior_prefixes_when_serialization_completes_then_registry_is_restored(
    caller_namespace_registry: dict[str, str],
) -> None:
    # Arrange
    root = ET.Element("ThreatModel")

    # Act
    with tm7_threat_contract.tm7_serialization_namespaces(root):
        active = dict(ET._namespace_map)

    # Assert
    assert active[tm7_threat_contract.MODEL_NS] == ""
    assert active[tm7_threat_contract.ARRAYS_NS] == "a"
    assert dict(ET._namespace_map) == caller_namespace_registry
    assert "xmlns:c" not in root.attrib


def test_given_exception_during_serialization_then_registry_is_still_restored(
    caller_namespace_registry: dict[str, str],
) -> None:
    # Arrange
    root = ET.Element("ThreatModel")

    # Act
    # The exception is captured explicitly rather than through a
    # `pytest.raises` context manager wrapping the `raise`. Static analysis
    # cannot see that `pytest.raises.__exit__` suppresses the exception, so
    # that shape makes every following assertion look unreachable. Capturing
    # it here keeps the control flow analyzable and asserts the same contract.
    raised: RuntimeError | None = None
    try:
        with tm7_threat_contract.tm7_serialization_namespaces(root):
            raise RuntimeError("write failed")
    except RuntimeError as exc:
        raised = exc

    # Assert
    assert raised is not None
    assert str(raised) == "write failed"
    assert dict(ET._namespace_map) == caller_namespace_registry
    assert "xmlns:c" not in root.attrib


def test_given_concurrent_serializations_when_run_then_bytes_and_registry_are_stable(
    caller_namespace_registry: dict[str, str],
) -> None:
    # Arrange
    expected = _serialize_probe_root()
    outputs: list[str] = []
    failures: list[Exception] = []

    def worker() -> None:
        try:
            for _ in range(25):
                outputs.append(_serialize_probe_root())
        except Exception as exc:  # pragma: no cover - reported below
            # `Exception` rather than `BaseException`: a worker thread is never
            # delivered KeyboardInterrupt or SystemExit, so the wider catch
            # bought nothing and masked the intent.
            failures.append(exc)

    threads = [threading.Thread(target=worker) for _ in range(8)]

    # Act
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()

    # Assert
    assert not failures
    assert set(outputs) == {expected}
    assert dict(ET._namespace_map) == caller_namespace_registry


def _serialize_probe_root() -> str:
    root = ET.Element(f"{{{tm7_threat_contract.MODEL_NS}}}ThreatModel")
    ET.SubElement(root, f"{{{tm7_threat_contract.ARRAYS_NS}}}Item")
    ET.SubElement(root, f"{{{tm7_threat_contract.KNOWLEDGE_NS}}}Entry")
    with tm7_threat_contract.tm7_serialization_namespaces(root):
        return ET.tostring(root, encoding="unicode")


def _gap_spec(properties: dict[str, object]) -> dict[str, object]:
    return {"threats": [{"id": "X-1", "properties": properties}]}


def test_given_resolvable_gap_citation_when_validated_then_no_failures() -> None:
    # Arrange
    spec = _gap_spec({"source_skill": "mural", "gap_ids": ["G-INF-1"]})
    registers = {"mural": {"G-INF-1"}, "jira": {"G-INF-1"}}

    # Act
    failures = tm7_threat_contract.collect_gap_citation_failures(spec, registers)

    # Assert
    assert failures == []


def test_given_gap_id_owned_by_another_skill_when_validated_then_reports_failure() -> (
    None
):
    # Arrange
    # G-DOS-2 is declared only by copilot-otel-metrics. Citing it from
    # security-planning is the exact misattribution that shipped as SP-1.
    spec = _gap_spec({"source_skill": "security-planning", "gap_ids": ["G-DOS-2"]})
    registers = {"security-planning": {"G-DOS-1"}, "copilot-otel-metrics": {"G-DOS-2"}}

    # Act
    failures = tm7_threat_contract.collect_gap_citation_failures(spec, registers)

    # Assert
    assert failures == ["X-1: G-DOS-2 is not declared by security-planning"]


def test_given_gap_citation_without_source_skill_when_validated_then_unresolvable() -> (
    None
):
    # Arrange
    spec = _gap_spec({"gap_ids": ["G-INF-1", "G-SUP-1"]})
    registers = {"mural": {"G-INF-1", "G-SUP-1"}}

    # Act
    failures = tm7_threat_contract.collect_gap_citation_failures(spec, registers)

    # Assert
    assert failures == [
        "X-1: cites G-INF-1, G-SUP-1 without a source_skill, so the gap ids "
        "cannot be resolved"
    ]


def test_given_unknown_source_skill_when_validated_then_reports_missing_register() -> (
    None
):
    # Arrange
    spec = _gap_spec({"source_skill": "not-a-skill", "gap_ids": ["G-INF-1"]})
    registers = {"mural": {"G-INF-1"}}

    # Act
    failures = tm7_threat_contract.collect_gap_citation_failures(spec, registers)

    # Assert
    assert failures == ["X-1: source_skill not-a-skill has no gap register"]


def test_given_same_gap_id_in_two_skills_when_validated_then_scoped_per_skill() -> None:
    # Arrange
    # G-INF-1 means different things per skill, so resolution must be scoped
    # to the citing skill rather than satisfied by any declaring skill.
    spec = {
        "threats": [
            {
                "id": "A-1",
                "properties": {"source_skill": "mural", "gap_ids": ["G-INF-1"]},
            },
            {
                "id": "B-1",
                "properties": {"source_skill": "vex", "gap_ids": ["G-INF-1"]},
            },
        ]
    }
    registers = {"mural": {"G-INF-1"}, "vex": {"G-TAM-1"}}

    # Act
    failures = tm7_threat_contract.collect_gap_citation_failures(spec, registers)

    # Assert
    assert failures == ["B-1: G-INF-1 is not declared by vex"]


def test_given_threat_without_gap_ids_when_validated_then_ignored() -> None:
    # Arrange
    spec = _gap_spec({"source_skill": "mural"})
    registers = {"mural": {"G-INF-1"}}

    # Act
    failures = tm7_threat_contract.collect_gap_citation_failures(spec, registers)

    # Assert
    assert failures == []
