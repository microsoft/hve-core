# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

"""Behavior tests for product-neutral accessibility evidence composition."""

from __future__ import annotations

import hashlib
from copy import deepcopy

import pytest

from runtime_a11y._errors import ScriptError
from runtime_a11y.evidence_bundle import (
    canonical_digest,
    canonical_json,
    compose_evidence,
)
from runtime_a11y.evidence_bundle._adapters import collect_artifacts
from runtime_a11y.evidence_bundle._validate import (
    reject_prohibited_content,
    verify_artifacts,
)

_DIGEST = "a" * 64
_REVISION = "b" * 40


@pytest.fixture()
def inputs() -> dict:
    data = {
        "asset_catalog": {
            "schemaVersion": "1.0.0",
            "assets": [{"assetId": "asset-docs"}],
            "fixtures": [{"fixtureId": "fixture-docs"}],
            "journeys": [
                {
                    "journeyId": "journey-read",
                    "assetId": "asset-docs",
                    "fixtureId": "fixture-docs",
                    "state": "default",
                    "role": "reader",
                    "requiredMethods": ["playwright", "screen-reader"],
                }
            ],
        },
        "requirement_catalog": {
            "schemaVersion": "1.0.0",
            "requirements": [
                {
                    "requirementId": "req-keyboard",
                    "framework": "wcag-22",
                    "journeyIds": ["journey-read"],
                    "freshnessRule": "Invalidate on interaction changes",
                    "methods": [
                        {
                            "method": "playwright",
                            "probe": "project-playwright",
                            "disposition": "decides",
                            "proposition": "The task completes by keyboard",
                        },
                        {
                            "method": "screen-reader",
                            "probe": "qualified-human",
                            "disposition": "decides",
                            "proposition": (
                                "The task is understandable with a screen reader"
                            ),
                            "human": True,
                        },
                    ],
                }
            ],
        },
        "scope": {
            "schemaVersion": "1.0.0",
            "profileId": "scope-pr",
            "cadenceClass": "pull-request",
            "manualEvidencePolicy": "reviewer-required",
            "selectors": {
                "assetIds": ["asset-docs"],
                "journeyIds": ["journey-read"],
                "states": ["default"],
                "methods": ["playwright", "screen-reader"],
                "probes": ["project-playwright", "qualified-human"],
                "fixtureIds": ["fixture-docs"],
            },
        },
        "run_context": {
            "schemaVersion": "1.0.0",
            "runId": "run-1",
            "campaignId": "campaign-1",
            "composedAt": "2026-09-16T12:00:00Z",
            "sourceRevision": _REVISION,
            "buildDigest": _DIGEST,
            "configDigest": _DIGEST,
            "fixtureDigest": _DIGEST,
            "lockfileDigest": _DIGEST,
            "toolDigest": _DIGEST,
            "harnessDigest": _DIGEST,
            "mappingDigest": _DIGEST,
            "environment": {
                "class": "local-ci",
                "operatingSystem": "Linux test image",
                "browser": "Chrome 140",
                "locale": "en-US",
                "viewport": "1280x720",
                "inputModes": ["keyboard"],
            },
        },
        "sources": [
            {
                "schemaVersion": "1.0.0",
                "sourceKind": "playwright",
                "producer": "project tests",
                "sourceRunId": "source-1",
                "observedAt": "2026-09-16T11:55:00Z",
                "sourceDigest": _DIGEST,
                "boundTo": {
                    "sourceRevision": _REVISION,
                    "buildDigest": _DIGEST,
                    "configDigest": _DIGEST,
                    "fixtureDigest": _DIGEST,
                },
                "results": [
                    {
                        "resultId": "result-auto",
                        "requirementId": "req-keyboard",
                        "journeyId": "journey-read",
                        "state": "default",
                        "method": "playwright",
                        "probe": "project-playwright",
                        "disposition": "decides",
                        "status": "PASS",
                        "expected": "The task completes by keyboard",
                        "observed": "The task completed",
                        "stateProofId": "proof-1",
                        "artifactIds": [],
                    }
                ],
                "artifacts": [
                    {
                        "artifactId": "proof-record",
                        "path": "proof.json",
                        "mediaType": "application/json",
                        "sizeBytes": 2,
                        "sha256": _DIGEST,
                    }
                ],
            }
        ],
        "state_proofs": [
            {
                "schemaVersion": "1.0.0",
                "proofId": "proof-1",
                "runId": "run-1",
                "journeyId": "journey-read",
                "fixtureId": "fixture-docs",
                "state": "default",
                "status": "PROVED",
                "expected": "Page loaded",
                "observed": "Page loaded",
                "steps": [{"action": "navigate"}, {"action": "assert"}],
                "artifactIds": ["proof-record"],
            }
        ],
    }
    _refresh_source_digest(data)
    return data


def _refresh_source_digest(inputs: dict) -> None:
    _set_source_digest(inputs["sources"][0])


def _set_source_digest(source: dict) -> None:
    material = {key: value for key, value in source.items() if key != "sourceDigest"}
    source["sourceDigest"] = canonical_digest(
        material, domain="hve-a11y:evidence-source:v1"
    )


def _configure_single_automated_method(
    inputs: dict, *, method: str, probe: str
) -> None:
    journey = inputs["asset_catalog"]["journeys"][0]
    journey["surfaceId"] = "web"
    journey["requiredMethods"] = [method]
    requirement = inputs["requirement_catalog"]["requirements"][0]
    requirement["methods"] = [
        {
            "method": method,
            "probe": probe,
            "disposition": "decides",
            "proposition": "The task completes by keyboard",
        }
    ]
    inputs["scope"]["selectors"].update({"methods": [method], "probes": [probe]})
    inputs["state_proofs"][0]["artifactIds"] = []


def _run_all_source() -> dict:
    return {
        "tool": "runtime_a11y",
        "runAt": "2026-09-16T11:55:00Z",
        "baseUrl": "http://127.0.0.1:3000",
        "runs": [{"probeId": "probe-keyboard", "surfaceId": "web", "state": "default"}],
        "results": [
            {
                "criterionId": "req-keyboard",
                "framework": "wcag-22",
                "surfaceId": "web",
                "state": "default",
                "status": "pass",
                "method": "runtime-automation",
                "probeId": "probe-keyboard",
                "evidence": "Keyboard task completed",
            }
        ],
    }


def _visual_manifest() -> dict:
    return {
        "schemaVersion": "1.0",
        "runId": "visual-run-1",
        "createdAt": "2026-09-16T11:55:00Z",
        "route": "/docs",
        "surface": "web",
        "state": "default",
        "viewport": {"width": 1280, "height": 720},
        "browser": {"name": "chromium", "version": "140"},
        "platform": {"os": "linux", "version": "test"},
        "artifacts": {
            "screenshots": [],
            "traces": [],
            "deterministicMeasurements": [],
            "manifestPayload": {
                "id": "manifest",
                "path": "manifest.json",
                "sha256": _DIGEST,
                "sizeBytes": 1,
            },
        },
        "probeOutcomes": [{"id": "docs:web:default", "status": "pass"}],
        "provenance": {},
        "evidenceState": "deterministic-pass",
    }


def test_given_same_inputs_in_different_order_when_composed_then_bytes_match(
    inputs: dict,
) -> None:
    # Arrange
    shuffled = deepcopy(inputs)
    shuffled["asset_catalog"]["journeys"][0]["requiredMethods"].reverse()
    shuffled["scope"]["selectors"]["methods"].reverse()
    shuffled["scope"]["selectors"]["probes"].reverse()

    # Act
    first = compose_evidence(**inputs)
    second = compose_evidence(**shuffled)

    # Assert
    assert canonical_json(first) == canonical_json(second)


def test_given_missing_pr_review_when_composed_then_reviewer_is_pending(
    inputs: dict,
) -> None:
    # Act
    bundle = compose_evidence(**inputs)

    # Assert
    assert bundle["scopeCompleteness"] == {
        "automatedCollection": "complete",
        "reviewerEvidence": "pending",
        "releaseEvidence": "not-applicable",
        "reasons": ["Reviewer evidence is pending"],
    }


def test_given_subset_of_states_when_composed_then_excluded_states_do_not_apply(
    inputs: dict,
) -> None:
    # Arrange
    open_journey = deepcopy(inputs["asset_catalog"]["journeys"][0])
    open_journey.update({"journeyId": "journey-read-open", "state": "open"})
    inputs["asset_catalog"]["journeys"].append(open_journey)
    inputs["requirement_catalog"]["requirements"][0]["journeyIds"].append(
        "journey-read-open"
    )
    inputs["scope"]["selectors"]["journeyIds"].append("journey-read-open")

    # Act
    bundle = compose_evidence(**inputs)

    # Assert
    selected_cells = bundle["expectedCells"] + bundle["deferredCells"]
    assert {cell["state"] for cell in selected_cells} == {"default"}
    assert bundle["scopeCompleteness"]["automatedCollection"] == "complete"


def test_given_current_run_all_output_when_composed_then_adapter_normalizes_it(
    inputs: dict,
) -> None:
    # Arrange
    _configure_single_automated_method(
        inputs, method="runtime-automation", probe="probe-keyboard"
    )
    inputs["sources"] = [_run_all_source()]

    # Act
    bundle = compose_evidence(**inputs)
    result = bundle["evidenceResults"][0]

    # Assert
    assert (
        result["status"],
        result["producer"],
        result["sourceSchemaVersion"],
        bundle["scopeCompleteness"]["automatedCollection"],
    ) == ("PASS", "runtime_a11y run-all", "unversioned-current", "complete")


@pytest.mark.parametrize(
    ("field", "value", "message"),
    [
        ("probeId", "unknown-probe", "requires exactly one selected catalog mapping"),
        ("status", "unknown", "Unsupported runtime_a11y result status"),
    ],
)
def test_given_unmappable_run_all_result_when_composed_then_fails_closed(
    inputs: dict, field: str, value: str, message: str
) -> None:
    # Arrange
    _configure_single_automated_method(
        inputs, method="runtime-automation", probe="probe-keyboard"
    )
    source = _run_all_source()
    source["results"][0][field] = value
    inputs["sources"] = [source]

    # Act and Assert
    with pytest.raises(ScriptError, match=message):
        compose_evidence(**inputs)


def test_given_visual_manifest_v1_when_composed_then_adapter_normalizes_it(
    inputs: dict,
) -> None:
    # Arrange
    _configure_single_automated_method(
        inputs, method="visual-review", probe="visual-review"
    )
    inputs["sources"] = [_visual_manifest()]

    # Act
    bundle = compose_evidence(**inputs)
    result = bundle["evidenceResults"][0]

    # Assert
    assert (
        result["status"],
        result["producer"],
        result["sourceSchemaVersion"],
        bundle["scopeCompleteness"]["automatedCollection"],
    ) == ("PASS", "runtime_a11y capture-visual-review", "1.0", "complete")
    # The deciding artifact is bound through the canonical contract so it is
    # covered by artifact verification.
    assert result["artifactIds"] == ["manifestPayload:manifest"]
    artifact = next(
        item
        for item in bundle["bundleManifest"]["artifacts"]
        if item["artifactId"] == "manifestPayload:manifest"
    )
    assert artifact["path"] == "manifest.json"
    assert artifact["mediaType"] == "application/json"
    assert artifact["sizeBytes"] == 1
    assert "limitation" not in result


def test_given_visual_artifact_without_size_when_composed_then_cannot_pass(
    inputs: dict,
) -> None:
    # Arrange
    _configure_single_automated_method(
        inputs, method="visual-review", probe="visual-review"
    )
    manifest = _visual_manifest()
    del manifest["artifacts"]["manifestPayload"]["sizeBytes"]
    inputs["sources"] = [manifest]

    # Act
    bundle = compose_evidence(**inputs)
    result = bundle["evidenceResults"][0]

    # Assert
    assert result["status"] == "CANT_TELL"
    assert result["artifactIds"] == []
    assert "manifestPayload:manifest" in result["limitation"]
    assert bundle["bundleManifest"]["artifacts"] == []


def test_given_duplicate_visual_artifact_ids_when_composed_then_fails_closed(
    inputs: dict,
) -> None:
    _configure_single_automated_method(
        inputs, method="visual-review", probe="visual-review"
    )
    manifest = _visual_manifest()
    manifest["artifacts"]["screenshots"] = [
        {"id": "shot", "path": "a.png", "sha256": _DIGEST, "sizeBytes": 1},
        {"id": "shot", "path": "b.png", "sha256": _DIGEST, "sizeBytes": 2},
    ]
    inputs["sources"] = [manifest]

    with pytest.raises(ScriptError, match="Duplicate visual artifact identity"):
        compose_evidence(**inputs)


@pytest.mark.parametrize(
    ("source_factory", "message"),
    [
        (
            lambda: {**_run_all_source(), "schemaVersion": "2.0"},
            "Unsupported runtime_a11y run-all schema version",
        ),
        (
            lambda: {**_visual_manifest(), "schemaVersion": "2.0"},
            "Unsupported visual-review manifest version",
        ),
    ],
)
def test_given_unknown_hve_source_version_when_composed_then_fails_closed(
    inputs: dict, source_factory, message: str
) -> None:
    # Arrange
    _configure_single_automated_method(
        inputs, method="visual-review", probe="visual-review"
    )
    inputs["sources"] = [source_factory()]

    # Act and Assert
    with pytest.raises(ScriptError, match=message):
        compose_evidence(**inputs)


def test_given_release_scope_when_manual_result_missing_then_release_is_incomplete(
    inputs: dict,
) -> None:
    # Arrange
    inputs["scope"]["cadenceClass"] = "release"
    inputs["scope"]["manualEvidencePolicy"] = "required"

    # Act
    bundle = compose_evidence(**inputs)

    # Assert
    assert bundle["scopeCompleteness"]["releaseEvidence"] == "incomplete"


@pytest.mark.parametrize(
    "status", ["FAIL", "CANT_TELL", "NOT_ASSESSED", "INAPPLICABLE"]
)
def test_given_release_scope_when_deciding_result_is_adverse_then_incomplete(
    inputs: dict,
    status: str,
) -> None:
    # A schema-valid, self-consistent source must not promote a release when its
    # own deciding result says the requirement did not pass.
    inputs["scope"]["cadenceClass"] = "release"
    inputs["scope"]["manualEvidencePolicy"] = "required"
    inputs["sources"][0]["results"][0]["status"] = status
    _refresh_source_digest(inputs)

    bundle = compose_evidence(**inputs)

    assert bundle["scopeCompleteness"]["releaseEvidence"] == "incomplete"
    assert any(
        "did not resolve to PASS" in reason
        for reason in bundle["scopeCompleteness"]["reasons"]
    )


@pytest.mark.parametrize(
    "field",
    ["sourceRevision", "buildDigest", "configDigest", "fixtureDigest"],
)
def test_given_source_bound_to_other_context_when_composed_then_fails_closed(
    inputs: dict,
    field: str,
) -> None:
    # A self-consistent source from an earlier revision must not be combined
    # with the current run context.
    inputs["sources"][0]["boundTo"][field] = (
        "c" * 40 if field == "sourceRevision" else "c" * 64
    )
    _refresh_source_digest(inputs)

    with pytest.raises(ScriptError, match=f"bound to a different {field}"):
        compose_evidence(**inputs)


def test_given_unbound_source_when_composed_then_fails_closed(inputs: dict) -> None:
    del inputs["sources"][0]["boundTo"]
    _refresh_source_digest(inputs)

    with pytest.raises(ScriptError, match="schema validation failed"):
        compose_evidence(**inputs)


def test_given_unproved_browser_state_when_composed_then_result_is_quarantined(
    inputs: dict,
) -> None:
    # Arrange
    inputs["state_proofs"][0]["status"] = "FAILED"
    inputs["state_proofs"][0]["errors"] = ["Expected page did not load"]

    # Act
    bundle = compose_evidence(**inputs)
    result = next(
        item for item in bundle["evidenceResults"] if item["resultId"] == "result-auto"
    )

    # Assert
    assert (result["status"], result["quarantined"]) == ("CANT_TELL", True)


def test_given_raw_speech_when_source_validated_then_composition_rejects_it(
    inputs: dict,
) -> None:
    # Arrange
    inputs["sources"][0]["transcript"] = {
        "phraseCount": 1,
        "sha256": _DIGEST,
        "retained": False,
        "phrases": ["private speech"],
    }

    # Act and Assert
    with pytest.raises(ScriptError, match="schema validation|forbidden"):
        compose_evidence(**inputs)


def test_given_registry_backed_supplement_when_recomposed_then_review_is_complete(
    inputs: dict,
) -> None:
    # Arrange
    initial, cell_id = _manual_cell_id(inputs)

    # Act
    bundle = _recompose(inputs, initial, [_supplement(cell_id, "supplement-1")])

    # Assert
    assert bundle["scopeCompleteness"]["reviewerEvidence"] == "complete"


def test_given_registry_without_anchor_when_recomposed_then_review_is_invalid(
    inputs: dict,
) -> None:
    # A registry that only attests to itself cannot approve reviewer evidence.
    initial, cell_id = _manual_cell_id(inputs)
    registry = _review_registry()

    bundle = compose_evidence(
        **inputs,
        registry=registry,
        supplements=[_supplement(cell_id, "supplement-1")],
        prior_bundle=initial,
        expected_prior_bundle_digest=initial["bundleDigest"],
    )

    assert bundle["scopeCompleteness"]["reviewerEvidence"] == "invalid"
    assert any(
        "no independent trust anchor" in reason
        for reason in bundle["scopeCompleteness"]["reasons"]
    )


def test_given_wrong_registry_anchor_when_recomposed_then_fails_closed(
    inputs: dict,
) -> None:
    initial, cell_id = _manual_cell_id(inputs)
    registry = _review_registry()

    with pytest.raises(ScriptError, match="does not match the expected digest"):
        compose_evidence(
            **inputs,
            registry=registry,
            expected_registry_digest=_DIGEST,
            supplements=[_supplement(cell_id, "supplement-1")],
            prior_bundle=initial,
            expected_prior_bundle_digest=initial["bundleDigest"],
        )


def test_given_tampered_registry_record_when_recomposed_then_fails_closed(
    inputs: dict,
) -> None:
    # A record edited after signing must not pass the recomputation.
    initial, cell_id = _manual_cell_id(inputs)
    registry = _review_registry()
    registry["records"][1]["scopes"] = ["screen-reader", "visual"]
    registry["digest"] = _registry_anchor(registry)

    with pytest.raises(ScriptError, match="record digest mismatch: approval-1"):
        compose_evidence(
            **inputs,
            registry=registry,
            expected_registry_digest=_registry_anchor(registry),
            supplements=[_supplement(cell_id, "supplement-1")],
            prior_bundle=initial,
            expected_prior_bundle_digest=initial["bundleDigest"],
        )


def test_given_anchor_without_registry_when_composed_then_fails_closed(
    inputs: dict,
) -> None:
    with pytest.raises(ScriptError, match="supplied without a registry"):
        compose_evidence(**inputs, expected_registry_digest=_DIGEST)


def _registry_record(record_id: str, kind: str, valid_until: str) -> dict:
    material = {
        "recordId": record_id,
        "reviewerId": "reviewer-1",
        "kind": kind,
        "status": "current",
        "scopes": ["screen-reader"],
        "verifiedBy": "accessibility-lead",
        "verifiedAt": "2026-09-01T00:00:00Z",
        "validUntil": valid_until,
    }
    return {
        **material,
        "digest": canonical_digest(material, domain="hve-a11y:review-record:v1"),
    }


def _review_registry() -> dict:
    material = {
        "schemaVersion": "1.0.0",
        "generatedAt": "2026-09-16T11:00:00Z",
        "records": [
            _registry_record(
                "qualification-1", "qualification", "2027-09-01T00:00:00Z"
            ),
            _registry_record("approval-1", "approval", "2026-10-16T00:00:00Z"),
        ],
    }
    return {
        **material,
        "digest": canonical_digest(material, domain="hve-a11y:review-registry:v1"),
    }


def _registry_anchor(registry: dict) -> str:
    return canonical_digest(
        {key: value for key, value in registry.items() if key != "digest"},
        domain="hve-a11y:review-registry:v1",
    )


def _supplement(cell_id: str, supplement_id: str, **overrides) -> dict:
    registry = _review_registry()
    records = {record["recordId"]: record for record in registry["records"]}
    material = {
        "schemaVersion": "1.0.0",
        "supplementId": supplement_id,
        "campaignId": "campaign-1",
        "cellId": cell_id,
        "requirementId": "req-keyboard",
        "journeyId": "journey-read",
        "state": "default",
        "fixtureId": "fixture-docs",
        "method": "screen-reader",
        "sourceRevision": _REVISION,
        "buildDigest": _DIGEST,
        "configDigest": _DIGEST,
        "reviewerId": "reviewer-1",
        "qualificationRecordId": "qualification-1",
        "qualificationRecordDigest": records["qualification-1"]["digest"],
        "approvalRecordId": "approval-1",
        "approvalRecordDigest": records["approval-1"]["digest"],
        "observedAt": "2026-09-16T11:58:00Z",
        "status": "PASS",
        "observedSummary": "Task completed with expected announcements",
        "privacy": {
            "classification": "internal",
            "redacted": True,
            "personalDataPresent": False,
        },
    }
    material.update(overrides)
    return {
        **material,
        "digest": canonical_digest(material, domain="hve-a11y:reviewer-supplement:v1"),
    }


def _manual_cell_id(inputs: dict) -> tuple[dict, str]:
    initial = compose_evidence(**inputs)
    cell = next(item for item in initial["expectedCells"] if item["human"])
    return initial, cell["cellId"]


def _recompose(inputs: dict, initial: dict, supplements: list[dict]) -> dict:
    registry = _review_registry()
    return compose_evidence(
        **inputs,
        registry=registry,
        expected_registry_digest=_registry_anchor(registry),
        supplements=supplements,
        prior_bundle=initial,
        expected_prior_bundle_digest=initial["bundleDigest"],
    )


def test_given_superseding_supplement_when_recomposed_then_leaf_decides_result(
    inputs: dict,
) -> None:
    # A later FAIL must win over the PASS it supersedes regardless of input order.
    initial, cell_id = _manual_cell_id(inputs)
    first = _supplement(cell_id, "supplement-1", status="PASS")
    second = _supplement(
        cell_id,
        "supplement-2",
        status="FAIL",
        observedAt="2026-09-16T11:59:00Z",
        supersedesSupplementId="supplement-1",
        previousSupplementDigest=first["digest"],
    )

    forward = _recompose(inputs, initial, [first, second])
    reversed_order = _recompose(inputs, initial, [second, first])

    result = next(
        item for item in forward["evidenceResults"] if item["cellId"] == cell_id
    )
    assert result["status"] == "FAIL"
    assert result["resultId"] == "supplement-2"
    assert forward["bundleDigest"] == reversed_order["bundleDigest"]


def test_given_repeated_identical_history_when_recomposed_then_bytes_match(
    inputs: dict,
) -> None:
    initial, cell_id = _manual_cell_id(inputs)
    supplement = _supplement(cell_id, "supplement-1")
    once = _recompose(inputs, initial, [supplement])

    # Re-supplying an unchanged supplement that the prior bundle already holds
    # must not alter the resolved history.
    registry = _review_registry()
    again = compose_evidence(
        **inputs,
        registry=registry,
        expected_registry_digest=_registry_anchor(registry),
        supplements=[supplement],
        prior_bundle=once,
        expected_prior_bundle_digest=once["bundleDigest"],
    )

    assert again["supplements"] == once["supplements"]


@pytest.mark.parametrize(
    ("build", "message"),
    [
        (
            lambda cell_id: [
                _supplement(cell_id, "supplement-1"),
                _supplement(cell_id, "supplement-2"),
            ],
            "exactly one current supplement",
        ),
        (
            lambda cell_id: [
                _supplement(
                    cell_id,
                    "supplement-2",
                    supersedesSupplementId="supplement-missing",
                    previousSupplementDigest=_DIGEST,
                )
            ],
            "supersedes an unknown supplement",
        ),
        (
            lambda cell_id: [
                _supplement(cell_id, "supplement-1"),
                _supplement(
                    cell_id,
                    "supplement-2",
                    supersedesSupplementId="supplement-1",
                    previousSupplementDigest=_DIGEST,
                ),
            ],
            "previous digest does not match",
        ),
        (
            lambda cell_id: [
                _supplement(cell_id, "supplement-1", previousSupplementDigest=_DIGEST)
            ],
            "previous digest without a predecessor",
        ),
    ],
)
def test_given_invalid_supplement_lineage_when_recomposed_then_fails_closed(
    inputs: dict, build, message: str
) -> None:
    initial, cell_id = _manual_cell_id(inputs)

    with pytest.raises(ScriptError, match=message):
        _recompose(inputs, initial, build(cell_id))


def test_given_forked_lineage_when_recomposed_then_fails_closed(
    inputs: dict,
) -> None:
    # Two supplements claiming the same predecessor is an unresolvable fork.
    initial, cell_id = _manual_cell_id(inputs)
    root = _supplement(cell_id, "supplement-1")
    fork_a = _supplement(
        cell_id,
        "supplement-2",
        supersedesSupplementId="supplement-1",
        previousSupplementDigest=root["digest"],
    )
    fork_b = _supplement(
        cell_id,
        "supplement-3",
        supersedesSupplementId="supplement-1",
        previousSupplementDigest=root["digest"],
    )

    with pytest.raises(ScriptError, match="lineage forks at supplement-1"):
        _recompose(inputs, initial, [root, fork_a, fork_b])


def test_given_detached_lineage_when_recomposed_then_fails_closed(
    inputs: dict,
) -> None:
    # Two independent chains for one cell leave no single current supplement.
    initial, cell_id = _manual_cell_id(inputs)
    root = _supplement(cell_id, "supplement-1")
    leaf = _supplement(
        cell_id,
        "supplement-2",
        supersedesSupplementId="supplement-1",
        previousSupplementDigest=root["digest"],
    )
    detached_root = _supplement(cell_id, "supplement-3")
    detached_leaf = _supplement(
        cell_id,
        "supplement-4",
        supersedesSupplementId="supplement-3",
        previousSupplementDigest=detached_root["digest"],
    )

    with pytest.raises(ScriptError, match="exactly one current supplement"):
        _recompose(inputs, initial, [root, leaf, detached_root, detached_leaf])


@pytest.mark.parametrize(
    ("mutation", "message"),
    [
        (
            lambda data: data["requirement_catalog"]["requirements"][0][
                "journeyIds"
            ].append("missing"),
            "Unknown journey",
        ),
        (
            lambda data: data["scope"]["selectors"].update({"methods": ["missing"]}),
            "unknown methods",
        ),
        (
            lambda data: data["state_proofs"][0].update({"runId": "other"}),
            "mismatched run",
        ),
        (
            lambda data: data["state_proofs"][0].update(
                {"steps": [{"action": "click"}, {"action": "assert"}]}
            ),
            "begin with navigate",
        ),
    ],
)
def test_given_invalid_binding_when_composed_then_fails_closed(
    inputs: dict,
    mutation,
    message: str,
) -> None:
    # Arrange
    mutation(inputs)

    # Act and Assert
    with pytest.raises(ScriptError, match=message):
        compose_evidence(**inputs)


def test_given_missing_automated_source_when_composed_then_collection_is_incomplete(
    inputs: dict,
) -> None:
    # Arrange
    inputs["sources"] = []
    inputs["state_proofs"] = []

    # Act
    bundle = compose_evidence(**inputs)

    # Assert
    assert bundle["scopeCompleteness"]["automatedCollection"] == "incomplete"


def test_given_source_digest_mismatch_when_composed_then_fails_closed(
    inputs: dict,
) -> None:
    # Arrange
    inputs["sources"][0]["sourceDigest"] = _DIGEST

    # Act and Assert
    with pytest.raises(ScriptError, match="source digest mismatch"):
        compose_evidence(**inputs)


def test_given_invalid_timestamp_when_composed_then_fails_closed(
    inputs: dict,
) -> None:
    # Arrange
    inputs["sources"][0]["observedAt"] = "not-a-date"
    _refresh_source_digest(inputs)

    # Act and Assert
    with pytest.raises(ScriptError, match="Invalid evidence timestamp"):
        compose_evidence(**inputs)


def test_given_timestamp_without_offset_when_composed_then_fails_closed(
    inputs: dict,
) -> None:
    # Arrange
    inputs["run_context"]["composedAt"] = "2026-09-16T12:00:00"

    # Act and Assert
    with pytest.raises(ScriptError, match="requires a UTC offset"):
        compose_evidence(**inputs)


@pytest.mark.parametrize(
    ("mutation", "message"),
    [
        (
            lambda data: data["asset_catalog"]["assets"].append(
                deepcopy(data["asset_catalog"]["assets"][0])
            ),
            "Duplicate asset identity",
        ),
        (
            lambda data: data["requirement_catalog"]["requirements"][0][
                "methods"
            ].append(
                deepcopy(data["requirement_catalog"]["requirements"][0]["methods"][0])
            ),
            "Duplicate requirement method",
        ),
        (
            lambda data: data["state_proofs"].append(deepcopy(data["state_proofs"][0])),
            "Duplicate state proof identity",
        ),
    ],
)
def test_given_duplicate_identity_when_composed_then_fails_closed(
    inputs: dict,
    mutation,
    message: str,
) -> None:
    # Arrange
    mutation(inputs)

    # Act and Assert
    with pytest.raises(ScriptError, match=message):
        compose_evidence(**inputs)


def test_given_source_metadata_mismatch_when_composed_then_fails_closed(
    inputs: dict,
) -> None:
    # Arrange
    inputs["sources"][0]["results"][0]["expected"] = "Different proposition"
    _refresh_source_digest(inputs)

    # Act and Assert
    with pytest.raises(ScriptError, match="metadata does not match"):
        compose_evidence(**inputs)


def test_given_unknown_result_artifact_when_composed_then_fails_closed(
    inputs: dict,
) -> None:
    # Arrange
    inputs["sources"][0]["results"][0]["artifactIds"] = ["missing"]
    _refresh_source_digest(inputs)

    # Act and Assert
    with pytest.raises(ScriptError, match="unknown artifacts"):
        compose_evidence(**inputs)


def test_given_prior_digest_without_bundle_when_composed_then_fails_closed(
    inputs: dict,
) -> None:
    # Act and Assert
    with pytest.raises(ScriptError, match="without a bundle"):
        compose_evidence(**inputs, expected_prior_bundle_digest=_DIGEST)


def test_given_prior_bundle_without_expected_digest_then_fails_closed(
    inputs: dict,
) -> None:
    # Arrange
    prior = compose_evidence(**inputs)

    # Act and Assert
    with pytest.raises(ScriptError, match="requires its expected digest"):
        compose_evidence(**inputs, prior_bundle=prior)


def test_given_wrong_expected_prior_digest_when_recomposed_then_fails_closed(
    inputs: dict,
) -> None:
    # Arrange
    prior = compose_evidence(**inputs)

    # Act and Assert
    with pytest.raises(ScriptError, match="bundle digest mismatch"):
        compose_evidence(
            **inputs,
            prior_bundle=prior,
            expected_prior_bundle_digest=_DIGEST,
        )


@pytest.mark.parametrize("condition", ["informs", "expired", "invalidated"])
def test_given_nondecisive_source_when_composed_then_status_is_cant_tell(
    inputs: dict,
    condition: str,
) -> None:
    # Arrange
    result = inputs["sources"][0]["results"][0]
    if condition == "informs":
        result["disposition"] = "informs"
        inputs["requirement_catalog"]["requirements"][0]["methods"][0][
            "disposition"
        ] = "informs"
    elif condition == "expired":
        result["validUntil"] = "2026-09-15T00:00:00Z"
    else:
        result["invalidated"] = True
        result["invalidationReasons"] = ["Fixture changed"]
    _refresh_source_digest(inputs)

    # Act
    bundle = compose_evidence(**inputs)
    actual = next(
        item for item in bundle["evidenceResults"] if item["resultId"] == "result-auto"
    )

    # Assert
    assert actual["status"] == "CANT_TELL"


def test_given_conflicting_deciding_results_when_composed_then_conflict_is_retained(
    inputs: dict,
) -> None:
    # Arrange
    conflicting = deepcopy(inputs["sources"][0]["results"][0])
    conflicting.update({"resultId": "result-fail", "status": "FAIL"})
    inputs["sources"][0]["results"].append(conflicting)
    _refresh_source_digest(inputs)

    # Act
    bundle = compose_evidence(**inputs)

    # Assert
    assert bundle["conflicts"][0]["state"] == "unresolved"


def test_given_newer_superseding_result_when_composed_then_history_is_preserved(
    inputs: dict,
) -> None:
    # Arrange
    previous = inputs["sources"][0]["results"][0]
    previous["status"] = "FAIL"
    _refresh_source_digest(inputs)
    current_source = deepcopy(inputs["sources"][0])
    current_source.update(
        {
            "sourceRunId": "source-2",
            "observedAt": "2026-09-16T11:59:00Z",
            "results": [
                {
                    **deepcopy(previous),
                    "resultId": "result-current",
                    "status": "PASS",
                    "supersedesResultId": "result-auto",
                }
            ],
        }
    )
    _set_source_digest(current_source)
    inputs["sources"].append(current_source)

    # Act
    bundle = compose_evidence(**inputs)
    results = {result["resultId"]: result for result in bundle["evidenceResults"]}

    # Assert
    assert (
        results["result-auto"]["current"],
        results["result-current"]["current"],
    ) == (
        False,
        True,
    )
    assert bundle["conflicts"] == []


def test_given_release_deferred_obligation_when_composed_then_fails_closed(
    inputs: dict,
) -> None:
    # Arrange
    inputs["scope"].update(
        {
            "cadenceClass": "release",
            "manualEvidencePolicy": "required",
            "deferred": [
                {
                    "requirementId": "req-keyboard",
                    "journeyId": "journey-read",
                    "method": "screen-reader",
                    "targetCadence": "release",
                    "reason": "Reviewer unavailable",
                }
            ],
        }
    )

    # Act and Assert
    with pytest.raises(ScriptError, match="cannot be deferred"):
        compose_evidence(**inputs)


def test_given_unmatched_deferred_obligation_when_composed_then_fails_closed(
    inputs: dict,
) -> None:
    # Arrange
    inputs["scope"]["deferred"] = [
        {
            "requirementId": "missing",
            "journeyId": "journey-read",
            "method": "screen-reader",
            "targetCadence": "release",
            "reason": "Deferred",
        }
    ]

    # Act and Assert
    with pytest.raises(ScriptError, match="do not match selected"):
        compose_evidence(**inputs)


def test_given_unexpected_source_cell_when_composed_then_fails_closed(
    inputs: dict,
) -> None:
    # Arrange
    inputs["sources"][0]["results"][0]["requirementId"] = "unexpected"
    _refresh_source_digest(inputs)

    # Act and Assert
    with pytest.raises(ScriptError, match="do not match expected cells"):
        compose_evidence(**inputs)


def test_given_invalid_registry_digest_when_composed_then_fails_closed(
    inputs: dict,
) -> None:
    # Arrange
    registry = {
        "schemaVersion": "1.0.0",
        "generatedAt": "2026-09-16T11:00:00Z",
        "records": [],
        "digest": _DIGEST,
    }

    # Act and Assert
    with pytest.raises(ScriptError, match="registry digest mismatch"):
        compose_evidence(**inputs, registry=registry)


def test_given_prior_bundle_from_other_campaign_when_recomposed_then_fails_closed(
    inputs: dict,
) -> None:
    # Arrange
    prior = compose_evidence(**inputs)
    inputs["run_context"]["campaignId"] = "campaign-2"

    # Act and Assert
    with pytest.raises(ScriptError, match="different campaign"):
        compose_evidence(
            **inputs,
            prior_bundle=prior,
            expected_prior_bundle_digest=prior["bundleDigest"],
        )


def test_given_conflicting_artifact_identity_when_collected_then_fails_closed() -> None:
    # Arrange
    first = {
        "artifactId": "artifact-1",
        "path": "a",
        "mediaType": "text/plain",
        "sizeBytes": 1,
        "sha256": _DIGEST,
    }
    second = {**first, "path": "b"}

    # Act and Assert
    with pytest.raises(ScriptError, match="Conflicting artifact identity"):
        collect_artifacts([{"artifacts": [first]}, {"artifacts": [second]}])


@pytest.mark.parametrize(
    "value",
    [
        {"rawSpeech": "private"},
        {"metadata": "api_key=secret"},
        {"reviewerName": "Person"},
        {"authorization": "Bearer abc"},
        {"Storage-State": {"cookies": []}},
        {"nested": [{"client_secret": "abc"}]},
        {"API_KEY": "abc"},
        {"extensions": {"headers": {"x-trace": "1"}}},
        {"deep": {"nested": {"privateKey": "abc"}}},
        {"sasToken": "sv=2021&sig=abcdefghijklmnopqrstuvwxyz0123456789"},
        {"connectionString": "AccountName=x;AccountKey=abcdef1234567890"},
        {"extensions": {"note": "sv=2021-08-06&sig=abcdefghijklmnopqrstuvwxyz012345"}},
        {
            "extensions": {
                "note": "Authorization value Bearer abcdefghijklmnopqrstuvwxyz123456"
            }
        },
        {
            "extensions": {
                "note": (
                    "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0"
                    ".dBjftJeZ4CVPmB92K27uhbUJU1p1r_wW1gFWFOEjXk"
                )
            }
        },
        {"extensions": {"note": "ghp_abcdefghijklmnopqrstuvwxyz0123456789"}},
        {"extensions": {"note": "AKIAIOSFODNN7EXAMPLE"}},
        {"extensions": {"note": "-----BEGIN RSA PRIVATE KEY-----"}},
        {"extensions": {"deeper": [{"awsAccessKeyId": "abc"}]}},
    ],
)
def test_given_prohibited_content_when_validated_then_rejects(value: dict) -> None:
    # Act and Assert
    with pytest.raises(ScriptError, match="forbidden"):
        reject_prohibited_content(value)


@pytest.mark.parametrize(
    "value",
    [
        {"journeyKey": "abc"},
        {"monkey": "abc"},
        {"keyboardOnly": True},
        {"tokenizer": "default"},
        {"observed": "The dialog exposes its accessible name and pressed state."},
        {"observed": "Reading view keeps one slide in the accessibility tree."},
        {"bundleDigest": "sha256:" + "a" * 64},
        {"observed": "Certificate of conformance is not claimed by this bundle."},
    ],
)
def test_given_ordinary_keys_when_validated_then_allowed(value: dict) -> None:
    # Ordinary words that merely contain a policy term must not be rejected.
    reject_prohibited_content(value)


@pytest.mark.parametrize(
    "mutate",
    [
        lambda data: data["asset_catalog"]["assets"][0].update({"apiKey": "abc"}),
        lambda data: data["scope"].update({"storageState": "abc"}),
        lambda data: data["run_context"].update({"authorization": "Bearer abc"}),
        lambda data: data["sources"][0]["results"][0].update({"cookie": "a=b"}),
    ],
)
def test_given_secret_bearing_input_when_composed_then_fails_closed(
    inputs: dict, mutate
) -> None:
    # Closed objects reject through the schema and open extension points reject
    # through the recursive privacy guard. Either way the value never lands in a
    # bundle.
    mutate(inputs)
    _refresh_source_digest(inputs)

    with pytest.raises(ScriptError, match="forbidden|not allowed"):
        compose_evidence(**inputs)


def test_given_secret_bearing_registry_when_recomposed_then_fails_closed(
    inputs: dict,
) -> None:
    initial, cell_id = _manual_cell_id(inputs)
    registry = _review_registry()
    registry["records"][0]["token"] = "abc"
    registry["digest"] = _registry_anchor(registry)

    with pytest.raises(ScriptError, match="forbidden|not allowed"):
        compose_evidence(
            **inputs,
            registry=registry,
            expected_registry_digest=_registry_anchor(registry),
            supplements=[_supplement(cell_id, "supplement-1")],
            prior_bundle=initial,
            expected_prior_bundle_digest=initial["bundleDigest"],
        )


def test_given_secret_bearing_supplement_when_recomposed_then_fails_closed(
    inputs: dict,
) -> None:
    initial, cell_id = _manual_cell_id(inputs)

    with pytest.raises(ScriptError, match="forbidden|not allowed"):
        _recompose(
            inputs, initial, [_supplement(cell_id, "supplement-1", password="abc")]
        )


def test_given_matching_artifact_when_verified_then_integrity_passes(
    tmp_path,
) -> None:
    # Arrange
    path = tmp_path / "artifact.txt"
    path.write_text("evidence", encoding="utf-8")
    artifact = {
        "artifactId": "artifact-1",
        "path": "artifact.txt",
        "mediaType": "text/plain",
        "sizeBytes": path.stat().st_size,
        "sha256": canonical_digest("evidence", domain="not-file-bytes"),
    }
    artifact["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()

    # Act and Assert
    verify_artifacts([artifact], tmp_path)


@pytest.mark.parametrize(
    ("field", "value", "message"),
    [
        ("path", "missing.txt", "missing"),
        ("sizeBytes", 1, "size mismatch"),
        ("sha256", _DIGEST, "digest mismatch"),
    ],
)
def test_given_invalid_artifact_when_verified_then_fails_closed(
    tmp_path,
    field: str,
    value,
    message: str,
) -> None:
    # Arrange
    path = tmp_path / "artifact.txt"
    path.write_text("evidence", encoding="utf-8")
    artifact = {
        "artifactId": "artifact-1",
        "path": "artifact.txt",
        "mediaType": "text/plain",
        "sizeBytes": path.stat().st_size,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    }
    artifact[field] = value

    # Act and Assert
    with pytest.raises(ScriptError, match=message):
        verify_artifacts([artifact], tmp_path)
