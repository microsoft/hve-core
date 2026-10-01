# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

"""Pure composition of product-neutral accessibility evidence bundles."""

from __future__ import annotations

from copy import deepcopy
from datetime import datetime
from typing import Any

from runtime_a11y._errors import EXIT_USAGE, ScriptError
from runtime_a11y.evidence_bundle._adapters import collect_artifacts, normalize_sources
from runtime_a11y.evidence_bundle._canonical import canonical_digest
from runtime_a11y.evidence_bundle._validate import validate_document
from runtime_a11y.matrix._provenance import (
    EVIDENCE_LIMITS_STATEMENT,
    NON_ATTESTATION_STATEMENT,
)

_HUMAN_METHODS = frozenset(
    {
        "manual-keyboard",
        "screen-reader",
        "cognitive-walkthrough",
        "qualified-human",
        "NVDA",
        "JAWS",
        "VOICEOVER",
        "BRAILLE",
        "COGNITIVE_REVIEW",
        "MEDIA_EQUIVALENCE_REVIEW",
    }
)


def _parse_time(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def _cell_id(requirement_id: str, journey_id: str, state: str, method: str) -> str:
    digest = canonical_digest(
        [requirement_id, journey_id, state, method], domain="hve-a11y:cell:v1"
    )
    return f"cell-{digest[:20]}"


def _require_unique(items: list[dict[str, Any]], key: str, label: str) -> None:
    values = [item[key] for item in items]
    if len(values) != len(set(values)):
        raise ScriptError(f"Duplicate {label} identity", EXIT_USAGE)


def _validate_inputs(
    asset_catalog: dict[str, Any],
    requirement_catalog: dict[str, Any],
    scope: dict[str, Any],
    run_context: dict[str, Any],
    state_proofs: list[dict[str, Any]],
    registry: dict[str, Any] | None,
    supplements: list[dict[str, Any]],
    prior_bundle: dict[str, Any] | None,
) -> None:
    validate_document(
        asset_catalog,
        "evidence-bundle.schema.json",
        definition="assetJourneyCatalogInput",
    )
    validate_document(
        requirement_catalog,
        "evidence-bundle.schema.json",
        definition="requirementMethodCatalogInput",
    )
    _require_unique(asset_catalog["assets"], "assetId", "asset")
    _require_unique(asset_catalog["fixtures"], "fixtureId", "fixture")
    _require_unique(asset_catalog["journeys"], "journeyId", "journey")
    _require_unique(requirement_catalog["requirements"], "requirementId", "requirement")
    for requirement in requirement_catalog["requirements"]:
        methods = [item["method"] for item in requirement["methods"]]
        if len(methods) != len(set(methods)):
            raise ScriptError("Duplicate requirement method assignment", EXIT_USAGE)
    validate_document(scope, "evidence-scope.schema.json")
    validate_document(
        run_context, "evidence-bundle.schema.json", definition="runContextInput"
    )
    journeys = {item["journeyId"]: item for item in asset_catalog["journeys"]}
    proof_ids: set[str] = set()
    for proof in state_proofs:
        validate_document(
            proof, "evidence-bundle.schema.json", definition="stateProofInput"
        )
        if proof["proofId"] in proof_ids:
            raise ScriptError("Duplicate state proof identity", EXIT_USAGE)
        proof_ids.add(proof["proofId"])
        journey = journeys.get(proof["journeyId"])
        if (
            proof["runId"] != run_context["runId"]
            or journey is None
            or proof["fixtureId"] != journey["fixtureId"]
            or proof["state"] != journey["state"]
        ):
            raise ScriptError(
                "State proof has mismatched run or journey bindings", EXIT_USAGE
            )
        if (
            proof["steps"][0].get("action") != "navigate"
            or proof["steps"][-1].get("action") != "assert"
        ):
            raise ScriptError(
                "State proof must begin with navigate and end with assert",
                EXIT_USAGE,
            )
    if registry is not None:
        validate_document(
            registry,
            "qualified-human-result.schema.json",
            definition="qualificationApprovalRegistryInput",
        )
    for supplement in supplements:
        validate_document(supplement, "qualified-human-result.schema.json")
    if prior_bundle is not None:
        validate_document(prior_bundle, "evidence-bundle.schema.json")


def _obligations(
    asset_catalog: dict[str, Any],
    requirement_catalog: dict[str, Any],
    scope: dict[str, Any],
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    journeys = {item["journeyId"]: item for item in asset_catalog["journeys"]}
    selectors = scope["selectors"]
    selected_journeys = set(selectors["journeyIds"])
    selected_methods = set(selectors["methods"])
    available_assets = {item["assetId"] for item in asset_catalog["assets"]}
    available_fixtures = {item["fixtureId"] for item in asset_catalog["fixtures"]}
    available_journeys = set(journeys)
    available_states = {item["state"] for item in asset_catalog["journeys"]}
    assignments = [
        assignment
        for requirement in requirement_catalog["requirements"]
        for assignment in requirement["methods"]
    ]
    available_methods = {item["method"] for item in assignments}
    available_probes = {
        item.get("probe")
        or (
            "qualified-human"
            if item.get("human") or item["method"] in _HUMAN_METHODS
            else item["method"]
        )
        for item in assignments
    }
    for selected, available, label in (
        (set(selectors["assetIds"]), available_assets, "assets"),
        (set(selectors["fixtureIds"]), available_fixtures, "fixtures"),
        (selected_journeys, available_journeys, "journeys"),
        (set(selectors["states"]), available_states, "states"),
        (selected_methods, available_methods, "methods"),
        (set(selectors["probes"]), available_probes, "probes"),
    ):
        if unknown := selected - available:
            raise ScriptError(
                f"Evidence scope references unknown {label}: {sorted(unknown)}",
                EXIT_USAGE,
            )
    deferred_records = scope.get("deferred", [])
    deferred_keys = [
        (item["requirementId"], item["journeyId"], item["method"])
        for item in deferred_records
    ]
    if len(deferred_keys) != len(set(deferred_keys)):
        raise ScriptError("Duplicate deferred obligation", EXIT_USAGE)
    explicit_deferred = {
        (item["requirementId"], item["journeyId"], item["method"]): item
        for item in deferred_records
    }
    expected: list[dict[str, Any]] = []
    deferred: list[dict[str, Any]] = []
    matched_deferred: set[tuple[str, str, str]] = set()
    for requirement in requirement_catalog["requirements"]:
        for journey_id in requirement["journeyIds"]:
            journey = journeys.get(journey_id)
            if journey is None:
                raise ScriptError(
                    f"Unknown journey in requirement catalog: {journey_id}", EXIT_USAGE
                )
            if (
                journey_id not in selected_journeys
                or journey["assetId"] not in selectors["assetIds"]
                or journey["state"] not in selectors["states"]
            ):
                continue
            if journey["fixtureId"] not in selectors["fixtureIds"]:
                continue
            for assignment in requirement["methods"]:
                method = assignment["method"]
                if method not in selected_methods:
                    continue
                human = bool(assignment.get("human")) or method in _HUMAN_METHODS
                probe = assignment.get("probe") or (
                    "qualified-human" if human else method
                )
                if probe not in selectors["probes"]:
                    continue
                state = journey["state"]
                cell = {
                    "cellId": _cell_id(
                        requirement["requirementId"], journey_id, state, method
                    ),
                    "requirementId": requirement["requirementId"],
                    "journeyId": journey_id,
                    "state": state,
                    "method": method,
                    "probe": probe,
                    "disposition": assignment["disposition"],
                    "expected": assignment["proposition"],
                    "human": human,
                }
                deferred_record = explicit_deferred.get(
                    (requirement["requirementId"], journey_id, method)
                )
                policy_deferred = human and scope["manualEvidencePolicy"] == "defer"
                if deferred_record or policy_deferred:
                    if deferred_record:
                        matched_deferred.add(
                            (requirement["requirementId"], journey_id, method)
                        )
                    if scope["cadenceClass"] == "release":
                        raise ScriptError(
                            "Release-required obligations cannot be deferred",
                            EXIT_USAGE,
                        )
                    deferred.append(
                        {
                            **cell,
                            "targetCadence": (deferred_record or {}).get(
                                "targetCadence", "release"
                            ),
                            "reason": (deferred_record or {}).get(
                                "reason", "Deferred by manual evidence policy"
                            ),
                        }
                    )
                else:
                    expected.append(cell)
    unmatched_deferred = set(explicit_deferred) - matched_deferred
    if unmatched_deferred:
        detail = sorted(unmatched_deferred)
        raise ScriptError(
            f"Deferred obligations do not match selected catalog cells: {detail}",
            EXIT_USAGE,
        )
    if not expected and not deferred:
        raise ScriptError("Evidence scope selected no obligations", EXIT_USAGE)
    return expected, deferred


def _registry_records(
    registry: dict[str, Any] | None,
    expected_registry_digest: str | None,
) -> tuple[dict[str, dict[str, Any]], bool]:
    """Accept reviewer records only against an independently supplied anchor.

    A registry that carries its own expected digest proves only self-consistency,
    so the expected value has to arrive from a separate caller-controlled
    boundary before any record can approve reviewer evidence.
    """
    if registry is None:
        if expected_registry_digest is not None:
            raise ScriptError(
                "Expected review registry digest supplied without a registry",
                EXIT_USAGE,
            )
        return {}, False
    computed = canonical_digest(
        {key: value for key, value in registry.items() if key != "digest"},
        domain="hve-a11y:review-registry:v1",
    )
    if registry["digest"] != computed:
        raise ScriptError("Review registry digest mismatch", EXIT_USAGE)
    _require_unique(registry["records"], "recordId", "review registry record")
    for record in registry["records"]:
        material = {key: value for key, value in record.items() if key != "digest"}
        if record["digest"] != canonical_digest(
            material, domain="hve-a11y:review-record:v1"
        ):
            raise ScriptError(
                f"Review registry record digest mismatch: {record['recordId']}",
                EXIT_USAGE,
            )
    if expected_registry_digest is None:
        return {}, True
    if expected_registry_digest != computed:
        raise ScriptError(
            "Review registry does not match the expected digest", EXIT_USAGE
        )
    return {record["recordId"]: record for record in registry["records"]}, False


def _resolve_lineage(
    supplements: list[dict[str, Any]],
) -> dict[str, dict[str, Any]]:
    """Select one current supplement per cell from a validated lineage chain.

    Selection walks explicit supersession links rather than input order, so a
    caller cannot decide which reviewer result wins by reordering its inputs.
    A cycle cannot form because each link binds the predecessor's digest, which
    the successor's own digest then covers.
    """
    by_id = {item["supplementId"]: item for item in supplements}
    by_cell: dict[str, list[dict[str, Any]]] = {}
    for item in supplements:
        by_cell.setdefault(item["cellId"], []).append(item)

    current: dict[str, dict[str, Any]] = {}
    for cell_id, items in by_cell.items():
        successors: dict[str, str] = {}
        for item in items:
            predecessor_id = item.get("supersedesSupplementId")
            if predecessor_id is None:
                if item.get("previousSupplementDigest"):
                    raise ScriptError(
                        "Reviewer supplement declares a previous digest without a "
                        f"predecessor: {item['supplementId']}",
                        EXIT_USAGE,
                    )
                continue
            predecessor = by_id.get(predecessor_id)
            if predecessor is None or predecessor["cellId"] != cell_id:
                raise ScriptError(
                    f"Reviewer supplement {item['supplementId']} supersedes an "
                    f"unknown supplement for its cell: {predecessor_id}",
                    EXIT_USAGE,
                )
            if item.get("previousSupplementDigest") != predecessor["digest"]:
                raise ScriptError(
                    "Reviewer supplement previous digest does not match its "
                    f"predecessor: {item['supplementId']}",
                    EXIT_USAGE,
                )
            if predecessor_id in successors:
                raise ScriptError(
                    f"Reviewer supplement lineage forks at {predecessor_id}",
                    EXIT_USAGE,
                )
            successors[predecessor_id] = item["supplementId"]

        leaves = [item for item in items if item["supplementId"] not in successors]
        if len(leaves) != 1:
            raise ScriptError(
                f"Reviewer supplement lineage for {cell_id} must resolve to exactly "
                f"one current supplement, found {len(leaves)}",
                EXIT_USAGE,
            )
        current[cell_id] = leaves[0]
    return current


def _supplement_is_current(
    supplement: dict[str, Any],
    records: dict[str, dict[str, Any]],
    run_context: dict[str, Any],
    evaluated_at: Any,
) -> bool:
    matching = (
        supplement["campaignId"] == run_context["campaignId"]
        and supplement["sourceRevision"] == run_context["sourceRevision"]
        and supplement["buildDigest"] == run_context["buildDigest"]
        and supplement["configDigest"] == run_context["configDigest"]
    )
    for record, kind, digest_field in (
        (
            records.get(supplement["qualificationRecordId"]),
            "qualification",
            "qualificationRecordDigest",
        ),
        (
            records.get(supplement["approvalRecordId"]),
            "approval",
            "approvalRecordDigest",
        ),
    ):
        matching = matching and bool(
            record
            and record["kind"] == kind
            and record["reviewerId"] == supplement["reviewerId"]
            and record["digest"] == supplement[digest_field]
            and record["status"] == "current"
            and supplement["method"] in record["scopes"]
            and _parse_time(record["validUntil"]) >= evaluated_at
        )
    if supplement.get("validUntil"):
        matching = matching and _parse_time(supplement["validUntil"]) >= evaluated_at
    return matching


def _approved_supplements(
    supplements: list[dict[str, Any]],
    registry: dict[str, Any] | None,
    run_context: dict[str, Any],
    expected_registry_digest: str | None,
) -> tuple[dict[str, dict[str, Any]], bool, bool]:
    records, unanchored = _registry_records(registry, expected_registry_digest)
    evaluated_at = _parse_time(run_context["composedAt"])
    for supplement in supplements:
        material = {key: value for key, value in supplement.items() if key != "digest"}
        if supplement["digest"] != canonical_digest(
            material, domain="hve-a11y:reviewer-supplement:v1"
        ):
            raise ScriptError("Reviewer supplement digest mismatch", EXIT_USAGE)

    approved: dict[str, dict[str, Any]] = {}
    invalid = False
    for cell_id, supplement in _resolve_lineage(supplements).items():
        if _supplement_is_current(supplement, records, run_context, evaluated_at):
            approved[cell_id] = supplement
        else:
            invalid = True
    return approved, invalid, unanchored


def _history(
    prior_bundle: dict[str, Any] | None,
    supplements: list[dict[str, Any]],
    run_context: dict[str, Any],
    expected_prior_bundle_digest: str | None,
) -> tuple[list[dict[str, Any]], str, str | None]:
    if prior_bundle is None:
        if expected_prior_bundle_digest is not None:
            raise ScriptError(
                "Prior bundle digest supplied without a bundle", EXIT_USAGE
            )
        if supplements:
            raise ScriptError(
                "Reviewer supplements require a prior evidence bundle", EXIT_USAGE
            )
        return [], "genesis", None
    if expected_prior_bundle_digest is None:
        raise ScriptError("Prior bundle requires its expected digest", EXIT_USAGE)
    if prior_bundle["runManifest"]["campaignId"] != run_context["campaignId"]:
        raise ScriptError(
            "Prior evidence bundle belongs to a different campaign", EXIT_USAGE
        )
    prior_material = {
        key: value for key, value in prior_bundle.items() if key != "bundleDigest"
    }
    prior_digest = canonical_digest(
        prior_material, domain="hve-a11y:evidence-bundle:v1"
    )
    if (
        prior_bundle["bundleDigest"] != prior_digest
        or expected_prior_bundle_digest != prior_digest
    ):
        raise ScriptError("Prior evidence bundle digest mismatch", EXIT_USAGE)
    prior_supplements = list(prior_bundle.get("supplements", []))
    _require_unique(prior_supplements, "supplementId", "prior supplement")
    _require_unique(supplements, "supplementId", "new supplement")
    existing = {item["supplementId"]: item for item in prior_supplements}
    for supplement in supplements:
        if (
            supplement["supplementId"] in existing
            and existing[supplement["supplementId"]] != supplement
        ):
            raise ScriptError(
                "Prior reviewer supplement history was mutated", EXIT_USAGE
            )
        existing[supplement["supplementId"]] = supplement
    # Sorting by identity keeps the emitted history, and therefore the bundle
    # bytes, independent of the order the caller supplied supplements in.
    ordered = sorted(existing.values(), key=lambda item: item["supplementId"])
    return ordered, "continued", prior_digest


def compose_evidence(
    *,
    asset_catalog: dict[str, Any],
    requirement_catalog: dict[str, Any],
    scope: dict[str, Any],
    run_context: dict[str, Any],
    sources: list[dict[str, Any]],
    state_proofs: list[dict[str, Any]],
    registry: dict[str, Any] | None = None,
    supplements: list[dict[str, Any]] | None = None,
    prior_bundle: dict[str, Any] | None = None,
    expected_prior_bundle_digest: str | None = None,
    expected_registry_digest: str | None = None,
) -> dict[str, Any]:
    """Compose validated inputs into one deterministic evidence bundle."""
    asset_catalog = deepcopy(asset_catalog)
    requirement_catalog = deepcopy(requirement_catalog)
    scope = deepcopy(scope)
    run_context = deepcopy(run_context)
    sources = deepcopy(sources)
    state_proofs = deepcopy(state_proofs)
    registry = deepcopy(registry)
    prior_bundle = deepcopy(prior_bundle)
    new_supplements = deepcopy(list(supplements or []))
    _validate_inputs(
        asset_catalog,
        requirement_catalog,
        scope,
        run_context,
        state_proofs,
        registry,
        new_supplements,
        prior_bundle,
    )
    expected, deferred = _obligations(asset_catalog, requirement_catalog, scope)
    history, history_state, prior_digest = _history(
        prior_bundle,
        new_supplements,
        run_context,
        expected_prior_bundle_digest,
    )
    approved, invalid_review, registry_unanchored = _approved_supplements(
        history, registry, run_context, expected_registry_digest
    )
    normalized = normalize_sources(
        sources,
        run_context=run_context,
        expected_cells=expected,
        asset_catalog=asset_catalog,
        requirement_catalog=requirement_catalog,
        state_proofs=state_proofs,
    )
    artifacts = collect_artifacts(sources)
    artifact_ids = {artifact["artifactId"] for artifact in artifacts}
    for proof in state_proofs:
        if unknown := set(proof["artifactIds"]) - artifact_ids:
            raise ScriptError(
                f"State proof references unknown artifacts: {sorted(unknown)}",
                EXIT_USAGE,
            )
    source_by_key: dict[tuple[str, str, str, str], list[dict[str, Any]]] = {}
    result_by_id: dict[str, dict[str, Any]] = {}
    for result in normalized:
        if result["resultId"] in result_by_id:
            raise ScriptError("Duplicate evidence result identity", EXIT_USAGE)
        result_by_id[result["resultId"]] = result
        key = (
            result["requirementId"],
            result["journeyId"],
            result["state"],
            result["method"],
        )
        source_by_key.setdefault(key, []).append(result)
    superseded_result_ids: set[str] = set()
    for result in normalized:
        previous_id = result.get("supersedesResultId")
        if previous_id is None:
            continue
        previous = result_by_id.get(previous_id)
        if previous is None:
            raise ScriptError(
                "Evidence result supersedes an unknown result", EXIT_USAGE
            )
        result_key = (
            result["requirementId"],
            result["journeyId"],
            result["state"],
            result["method"],
        )
        previous_key = (
            previous["requirementId"],
            previous["journeyId"],
            previous["state"],
            previous["method"],
        )
        if result_key != previous_key or _parse_time(
            result["observedAt"]
        ) <= _parse_time(previous["observedAt"]):
            raise ScriptError("Evidence result has invalid supersession", EXIT_USAGE)
        superseded_result_ids.add(previous_id)
    expected_keys = {
        (cell["requirementId"], cell["journeyId"], cell["state"], cell["method"])
        for cell in expected
        if not cell["human"]
    }
    unexpected_source_keys = set(source_by_key) - expected_keys
    if unexpected_source_keys:
        detail = sorted(unexpected_source_keys)
        raise ScriptError(
            f"Source results do not match expected cells: {detail}",
            EXIT_USAGE,
        )
    proofs = {proof["proofId"]: proof for proof in state_proofs}
    results: list[dict[str, Any]] = []
    conflicts: list[dict[str, Any]] = []
    automated_missing = False
    human_missing = False
    bundle_quarantined = False
    adverse_cells: list[str] = []
    for cell in expected:
        if cell["human"]:
            supplement = approved.get(cell["cellId"])
            journey = next(
                item
                for item in asset_catalog["journeys"]
                if item["journeyId"] == cell["journeyId"]
            )
            if supplement is not None and (
                supplement["requirementId"] != cell["requirementId"]
                or supplement["journeyId"] != cell["journeyId"]
                or supplement["state"] != cell["state"]
                or supplement["method"] != cell["method"]
                or supplement["fixtureId"] != journey["fixtureId"]
            ):
                invalid_review = True
                supplement = None
            if supplement is None:
                human_missing = True
                results.append(
                    {
                        "resultId": f"result-{cell['cellId']}-pending",
                        "cellId": cell["cellId"],
                        "status": "NOT_ASSESSED",
                        "observed": "Qualified reviewer evidence is pending",
                        "quarantined": False,
                    }
                )
            else:
                results.append(
                    {
                        "resultId": supplement["supplementId"],
                        "cellId": cell["cellId"],
                        "status": supplement["status"],
                        "observed": supplement["observedSummary"],
                        "quarantined": False,
                        "reviewerId": supplement["reviewerId"],
                    }
                )
                if supplement["status"] != "PASS":
                    adverse_cells.append(cell["cellId"])
            continue
        key = (cell["requirementId"], cell["journeyId"], cell["state"], cell["method"])
        matches = source_by_key.get(key, [])
        current_matches = [
            match for match in matches if match["resultId"] not in superseded_result_ids
        ]
        if not current_matches:
            automated_missing = True
            adverse_cells.append(cell["cellId"])
            results.append(
                {
                    "resultId": f"result-{cell['cellId']}-missing",
                    "cellId": cell["cellId"],
                    "status": "NOT_ASSESSED",
                    "observed": "Expected automated evidence was not supplied",
                    "quarantined": False,
                }
            )
            continue
        current_statuses: set[str] = set()
        match_ids: list[str] = []
        for match in matches:
            is_current = match["resultId"] not in superseded_result_ids
            if (
                match["probe"] != cell["probe"]
                or match["disposition"] != cell["disposition"]
                or match["expected"] != cell["expected"]
            ):
                raise ScriptError(
                    "Evidence source metadata does not match the expected cell",
                    EXIT_USAGE,
                )
            if unknown := set(match.get("artifactIds", [])) - artifact_ids:
                raise ScriptError(
                    f"Evidence result references unknown artifacts: {sorted(unknown)}",
                    EXIT_USAGE,
                )
            status = match["status"]
            quarantined = bool(match.get("quarantined"))
            proof_id = match.get("stateProofId")
            if match["disposition"] == "informs" and status in {"PASS", "FAIL"}:
                status = "CANT_TELL"
            if match.get("invalidated") or (
                match.get("validUntil")
                and _parse_time(match["validUntil"])
                < _parse_time(run_context["composedAt"])
            ):
                status = "CANT_TELL"
            if match["disposition"] == "decides" and match["sourceKind"] in {
                "hve-probe",
                "playwright",
                "axe",
                "visual",
            }:
                proof = proofs.get(proof_id or "")
                if proof is None or proof["status"] != "PROVED":
                    status = "CANT_TELL"
                    quarantined = True
            if is_current:
                bundle_quarantined = bundle_quarantined or quarantined
                current_statuses.add(status)
            match_ids.append(match["resultId"])
            results.append(
                {
                    **match,
                    "cellId": cell["cellId"],
                    "status": status,
                    "quarantined": quarantined,
                    "current": is_current,
                }
            )
        if "PASS" in current_statuses and "FAIL" in current_statuses:
            conflict_id = canonical_digest(match_ids, domain="hve-a11y:conflict:v1")[
                :20
            ]
            conflicts.append(
                {
                    "conflictId": f"conflict-{conflict_id}",
                    "cellId": cell["cellId"],
                    "resultIds": [
                        result_id
                        for result_id in match_ids
                        if result_id not in superseded_result_ids
                    ],
                    "state": "unresolved",
                }
            )
        # A release claim needs every deciding cell to actually pass. Presence of
        # a current result says only that the cell was assessed.
        if current_statuses != {"PASS"}:
            adverse_cells.append(cell["cellId"])
    reviewer_state = "not-required"
    if any(cell["human"] for cell in expected):
        reviewer_state = (
            "invalid"
            if invalid_review
            else ("pending" if human_missing else "complete")
        )
    release_state = "not-applicable"
    if scope["cadenceClass"] == "release":
        release_state = (
            "complete"
            if not automated_missing
            and not adverse_cells
            and reviewer_state in {"not-required", "complete"}
            and not conflicts
            and not bundle_quarantined
            else "incomplete"
        )
    run_digest = canonical_digest(run_context, domain="hve-a11y:run-context:v1")
    scope_digest = canonical_digest(scope, domain="hve-a11y:evidence-scope:v1")
    bundle_id = canonical_digest(
        [run_context["runId"], scope_digest], domain="hve-a11y:bundle-id:v1"
    )[:20]
    reasons: list[str] = []
    if automated_missing:
        reasons.append("Expected automated evidence is incomplete")
    if adverse_cells:
        reasons.append(
            "Deciding evidence did not resolve to PASS for: "
            + ", ".join(sorted(set(adverse_cells)))
        )
    if reviewer_state in {"pending", "invalid"}:
        reasons.append(f"Reviewer evidence is {reviewer_state}")
    if registry_unanchored:
        reasons.append(
            "Review registry has no independent trust anchor, so reviewer "
            "records are diagnostic only"
        )
    if conflicts:
        reasons.append("Current deciding evidence conflicts")
    if bundle_quarantined:
        reasons.append("At least one current result is quarantined")
    bundle = {
        "schemaVersion": "1.0.0",
        "composedAt": run_context["composedAt"],
        "catalogs": {
            "assetJourney": asset_catalog,
            "requirementMethod": requirement_catalog,
            "assetJourneyDigest": canonical_digest(
                asset_catalog, domain="hve-a11y:asset-journey-catalog:v1"
            ),
            "requirementMethodDigest": canonical_digest(
                requirement_catalog, domain="hve-a11y:requirement-method-catalog:v1"
            ),
        },
        "runManifest": run_context,
        "bundleManifest": {
            "bundleId": f"bundle-{bundle_id}",
            "runId": run_context["runId"],
            "runManifestDigest": run_digest,
            "scopeDigest": scope_digest,
            "artifacts": artifacts,
            "quarantineState": "quarantined" if bundle_quarantined else "clear",
            "quarantineReasons": ["Current evidence includes a quarantined result"]
            if bundle_quarantined
            else [],
        },
        "expectedCells": expected,
        "deferredCells": deferred,
        "stateProofs": state_proofs,
        "evidenceResults": results,
        "supplements": history,
        "historyState": history_state,
        "conflicts": conflicts,
        "scopeCompleteness": {
            "automatedCollection": "incomplete" if automated_missing else "complete",
            "reviewerEvidence": reviewer_state,
            "releaseEvidence": release_state,
            "reasons": reasons,
        },
        "nonAttestation": {
            "attestation": False,
            "statement": NON_ATTESTATION_STATEMENT,
            "evidenceLimits": EVIDENCE_LIMITS_STATEMENT,
        },
    }
    if prior_digest is not None:
        bundle["priorBundleDigest"] = prior_digest
    bundle["bundleDigest"] = canonical_digest(
        bundle, domain="hve-a11y:evidence-bundle:v1"
    )
    validate_document(bundle, "evidence-bundle.schema.json")
    return bundle
