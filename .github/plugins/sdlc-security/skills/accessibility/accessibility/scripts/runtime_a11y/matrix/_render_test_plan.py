# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

"""Render manual accessibility test plans from unresolved matrix cells."""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

from runtime_a11y.matrix._aria_at import resolve_aria_at_mapping
from runtime_a11y.matrix._model import Cell, Matrix
from runtime_a11y.matrix._provenance import ArtifactMetadata
from runtime_a11y.matrix._render_md import (
    ACCESSIBILITY_DISCLAIMER,
    HUMAN_REVIEW_CHECKBOX,
)

_HUMAN_METHOD_PRIORITY = (
    "screen-reader",
    "manual-keyboard",
    "cognitive-walkthrough",
)


def _token(*parts: str) -> str:
    value = "-".join(parts).lower()
    return re.sub(r"[^a-z0-9]+", "-", value).strip("-") or "unknown"


def _recommended_method(cell: Cell, criterion: Any | None = None) -> str | None:
    candidate_methods = set(cell.adequateMethods)
    if not candidate_methods and criterion is not None:
        candidate_methods = set(criterion.adequateMethods)
    for method in _HUMAN_METHOD_PRIORITY:
        if method in candidate_methods:
            return method
    if not candidate_methods:
        return _HUMAN_METHOD_PRIORITY[0]
    return None


def build_manual_test_cases(
    matrix: Matrix,
    runtime_config: dict[str, Any] | None = None,
) -> list[dict[str, Any]]:
    """Build unresolved cases that require a human-deciding method."""
    criterion_by_id = {criterion.id: criterion for criterion in matrix.criteria}
    surface_by_id = {surface.id: surface for surface in matrix.surfaces}
    cases: list[dict[str, Any]] = []

    for cell in matrix.cells:
        method = _recommended_method(cell)
        adequately_passed = (
            cell.status == "pass"
            and cell.verifiedByMethod is not None
            and cell.verifiedByMethod in cell.adequateMethods
        )
        if not cell.isApplicable or method is None or adequately_passed:
            continue

        criterion = criterion_by_id.get(cell.criterionId)
        surface = surface_by_id.get(cell.surfaceId)
        pattern = None
        if surface is not None:
            pattern = surface.widgetPattern
        if not pattern and runtime_config and surface is not None:
            for entry in runtime_config.get("surfaces", []) or []:
                if entry.get("id") != surface.id:
                    continue
                pattern = entry.get("widgetPattern")
                break
        aria_at = resolve_aria_at_mapping(
            pattern,
            cell.state,
            surface.id if surface else None,
            runtime_config,
        )
        steps = [
            f"Open the {surface.name if surface else cell.surfaceId} surface.",
            f"Place the surface in the {cell.state} state.",
            f"Evaluate the surface using {method}.",
            "Record the observed result and evidence reference.",
        ]
        if aria_at["mappingStatus"] == "mapped" and aria_at["automationEligible"]:
            steps.insert(
                2,
                "Review the ARIA-AT mapping and execute the documented AT commands.",
            )
        elif aria_at["mappingStatus"] == "mapped":
            steps.insert(
                2,
                "Review the ARIA-AT mapping and use its manual variant guidance "
                "with the shared runbook.",
            )
        elif aria_at["mappingStatus"] == "unmapped":
            steps.insert(
                2,
                "Confirm whether the project intends to refine this pattern "
                "into a dedicated ARIA-AT mapping.",
            )
        cases.append(
            {
                "id": f"manual-{_token(cell.criterionId, cell.surfaceId, cell.state)}",
                "criterionId": cell.criterionId,
                "framework": criterion.framework if criterion else "unknown",
                "criterionTitle": criterion.title if criterion else cell.criterionId,
                "surfaceId": cell.surfaceId,
                "surfaceName": surface.name if surface else cell.surfaceId,
                "platform": surface.platform if surface else "unknown",
                "state": cell.state,
                "currentStatus": cell.status,
                "recommendedMethod": method,
                "adequateMethods": sorted(cell.adequateMethods),
                "rationale": cell.rationale or "",
                "evidence": cell.evidence or "",
                "steps": steps,
                "expectedResult": (
                    f"The {criterion.title if criterion else cell.criterionId} "
                    "requirement is satisfied in this surface and state."
                ),
                "ariaAt": aria_at,
            }
        )

    return sorted(
        cases,
        key=lambda item: (
            item["framework"],
            item["criterionId"],
            item["surfaceId"],
            item["state"],
        ),
    )


def render_manual_test_plan_markdown(
    matrix: Matrix,
    out_path: Path,
    repo_slug: str,
    runtime_config: dict[str, Any] | None = None,
) -> None:
    """Write a human-readable manual accessibility test plan."""
    cases = build_manual_test_cases(matrix, runtime_config)
    lines = [
        "<!-- markdownlint-disable-file -->",
        "# Manual Accessibility Test Plan",
        "",
        ACCESSIBILITY_DISCLAIMER,
        "",
        HUMAN_REVIEW_CHECKBOX,
        "",
        f"- Repository: {repo_slug}",
        f"- Pending manual cases: {len(cases)}",
        "",
        "## Execution Rules",
        "",
        "* A qualified tester records observed output and an evidence URI.",
        (
            "* A test result does not update matrix coverage until the "
            "evidence is ingested."
        ),
        "* JAWS, braille, and cognitive outcomes remain human-decided.",
        "",
        "## Test Cases",
        "",
    ]
    if not cases:
        lines.extend(["* None", ""])
    for case in cases:
        aria_at = case["ariaAt"]
        lines.extend(
            [
                f"### {case['id']}",
                "",
                f"* Criterion: {case['framework']} {case['criterionId']} "
                f"({case['criterionTitle']})",
                f"* Surface: {case['surfaceName']} ({case['surfaceId']})",
                f"* Platform: {case['platform']}",
                f"* State: {case['state']}",
                f"* Current status: {case['currentStatus']}",
                f"* Recommended method: {case['recommendedMethod']}",
                f"* ariaAt mapping status: {aria_at['mappingStatus']}",
                f"* ARIA-AT mapping ID: {aria_at.get('mappingId') or 'unmapped'}",
                f"* Upstream test ID: {aria_at.get('upstreamTestId') or 'unmapped'}",
                f"* ariaAt source: {aria_at['sourceUrl'] or 'unmapped'}",
                f"* ARIA-AT source: {aria_at['sourceUrl'] or 'unmapped'}",
                f"* Immutable source: {aria_at.get('immutableUrl') or 'unmapped'}",
                f"* Upstream SHA: {aria_at.get('upstreamSha') or 'unmapped'}",
                f"* Catalog version: {aria_at.get('catalogVersion') or 'unmapped'}",
                f"* Automation eligible: {aria_at['automationEligible']}",
                f"* Automation exclusion: "
                f"{aria_at['automationExclusionReason'] or 'None'}",
                f"* Runbook reference: {aria_at['runbookReference']}",
                "",
            ]
        )
        if aria_at.get("functionalExpectations"):
            lines.extend(["#### Functional Expectations", ""])
            lines.extend(
                f"* {expectation}" for expectation in aria_at["functionalExpectations"]
            )
            lines.append("")
        lines.extend(["#### Mapping Commands", ""])
        if aria_at.get("commands"):
            lines.extend(
                f"* `{json.dumps(command, ensure_ascii=False)}`"
                for command in aria_at["commands"]
            )
        else:
            lines.append("* None (manual-only)")
        lines.extend(["", "#### Mapping Assertions", ""])
        if aria_at.get("assertions"):
            lines.extend(
                f"* `{json.dumps(assertion, ensure_ascii=False)}`"
                for assertion in aria_at["assertions"]
            )
        else:
            lines.append("* None (manual-only)")
        lines.append("")
        variants = aria_at.get("variants", [])
        nvda_variants = [v for v in variants if v.get("at") == "nvda"]
        jaws_variants = [v for v in variants if v.get("at") == "jaws"]
        lines.extend(["#### Executable NVDA Variants", ""])
        if nvda_variants:
            for variant in nvda_variants:
                variant_commands = json.dumps(
                    variant.get("commands", []),
                    ensure_ascii=False,
                )
                variant_assertions = json.dumps(
                    variant.get("assertions", []),
                    ensure_ascii=False,
                )
                lines.extend(
                    [
                        f"##### {variant.get('id')}",
                        "",
                        f"* AT: {variant.get('at')}",
                        f"* Platform: {variant.get('platform')}",
                        f"* Automation eligible: {variant.get('automationEligible')}",
                        "* Automation exclusion: "
                        f"{variant.get('automationExclusionReason') or 'None'}",
                        f"* Commands: {variant_commands}",
                        f"* Assertions: {variant_assertions}",
                        "",
                    ]
                )
        else:
            lines.extend(["* None", ""])
        lines.extend(["#### Manual JAWS Variants", ""])
        if jaws_variants:
            for variant in jaws_variants:
                lines.extend(
                    [
                        f"##### {variant.get('id')}",
                        "",
                        f"* AT: {variant.get('at')}",
                        f"* Platform: {variant.get('platform')}",
                        "* Manual evidence required: "
                        f"{variant.get('manualEvidenceRequired', False)}",
                        "* Automation exclusion: "
                        f"{variant.get('automationExclusionReason') or 'None'}",
                        f"* Runbook reference: {variant.get('runbookReference') or ''}",
                        "",
                    ]
                )
                if variant.get("functionalExpectation"):
                    lines.extend(
                        [
                            "* Functional expectation: "
                            f"{variant.get('functionalExpectation')}",
                            "",
                        ]
                    )
                if variant.get("manualCommandGuidance"):
                    lines.append("* Manual command guidance:")
                    lines.extend(
                        f"  * {guidance}"
                        for guidance in variant.get("manualCommandGuidance", [])
                    )
                    lines.append("")
        else:
            lines.extend(["* None", ""])
        lines.extend(
            [
                "#### Steps",
                "",
            ]
        )
        lines.extend(
            f"{index}. {step}" for index, step in enumerate(case["steps"], start=1)
        )
        lines.extend(
            [
                "",
                "#### Expected Result",
                "",
                case["expectedResult"],
                "",
                "#### Result Record",
                "",
                "* Outcome: Not run",
                "* Observed result:",
                "* Evidence URI:",
                "* Tester:",
                "* Test date:",
                "",
            ]
        )

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("\n".join(lines), encoding="utf-8")


def _yaml_scalar(value: Any) -> str:
    if value is True:
        return "true"
    if value is False:
        return "false"
    if value is None:
        return "null"
    return json.dumps(value, ensure_ascii=False)


def _append_yaml_commands(
    lines: list[str],
    indent: str,
    key: str,
    commands: list[dict[str, Any]],
) -> None:
    if not commands:
        lines.append(f"{indent}{key}: []")
        return
    lines.append(f"{indent}{key}:")
    for command in commands:
        lines.append(f"{indent}  - kind: {_yaml_scalar(command.get('kind'))}")
        if "value" in command:
            lines.append(f"{indent}    value: {_yaml_scalar(command.get('value'))}")
        if "durationMs" in command:
            lines.append(
                f"{indent}    durationMs: {_yaml_scalar(command.get('durationMs'))}"
            )


def _append_yaml_assertions(
    lines: list[str],
    indent: str,
    key: str,
    assertions: list[dict[str, Any]],
) -> None:
    if not assertions:
        lines.append(f"{indent}{key}: []")
        return
    lines.append(f"{indent}{key}:")
    for assertion in assertions:
        lines.append(f"{indent}  - type: {_yaml_scalar(assertion.get('type'))}")
        lines.append(f"{indent}    value: {_yaml_scalar(assertion.get('value'))}")


def render_manual_test_plan_yaml(
    matrix: Matrix,
    out_path: Path,
    repo_slug: str,
    runtime_config: dict[str, Any] | None = None,
    metadata: ArtifactMetadata | None = None,
) -> None:
    """Write the machine-readable manual accessibility test plan as YAML."""
    cases = build_manual_test_cases(matrix, runtime_config)
    lines = [
        "version: 2",
        f"repository: {_yaml_scalar(repo_slug)}",
        "review:",
        "  required: true",
        "  completed: false",
    ]
    if metadata is not None:
        lines.extend(
            [
                "assessment:",
                f"  generatedAt: {_yaml_scalar(metadata.generatedAt)}",
                f"  tool: {_yaml_scalar(metadata.tool)}",
                f"  toolVersion: {_yaml_scalar(metadata.toolVersion)}",
                "  aiAssisted: true",
                f"  humanReviewCompleted: {str(metadata.humanReviewCompleted).lower()}",
                f"  quarantined: {str(metadata.quarantined).lower()}",
                f"  nonAttestation: {_yaml_scalar(metadata.nonAttestation)}",
                f"  evidenceLimits: {_yaml_scalar(metadata.evidenceLimits)}",
            ]
        )
        if metadata.quarantined:
            lines.append(
                "  quarantineReason: "
                f"{_yaml_scalar(metadata.quarantineReason or 'reason not recorded')}"
            )
    lines.append("cases:")
    if not cases:
        lines[-1] = "cases: []"
    for case in cases:
        aria_at = case["ariaAt"]
        lines.extend(
            [
                f"  - id: {_yaml_scalar(case['id'])}",
                f"    criterionId: {_yaml_scalar(case['criterionId'])}",
                f"    framework: {_yaml_scalar(case['framework'])}",
                f"    criterionTitle: {_yaml_scalar(case['criterionTitle'])}",
                f"    surfaceId: {_yaml_scalar(case['surfaceId'])}",
                f"    surfaceName: {_yaml_scalar(case['surfaceName'])}",
                f"    platform: {_yaml_scalar(case['platform'])}",
                f"    state: {_yaml_scalar(case['state'])}",
                f"    currentStatus: {_yaml_scalar(case['currentStatus'])}",
                f"    recommendedMethod: {_yaml_scalar(case['recommendedMethod'])}",
                "    ariaAt:",
                f"      mappingStatus: {_yaml_scalar(aria_at['mappingStatus'])}",
                f"      mappingId: {_yaml_scalar(aria_at['mappingId'])}",
                f"      upstreamTestId: {_yaml_scalar(aria_at.get('upstreamTestId'))}",
                f"      sourceUrl: {_yaml_scalar(aria_at['sourceUrl'])}",
                f"      immutableUrl: {_yaml_scalar(aria_at['immutableUrl'])}",
                f"      upstreamSha: {_yaml_scalar(aria_at['upstreamSha'])}",
                f"      catalogVersion: {_yaml_scalar(aria_at['catalogVersion'])}",
                f"      automationEligible: "
                f"{_yaml_scalar(aria_at['automationEligible'])}",
                f"      automationExclusionReason: "
                f"{_yaml_scalar(aria_at['automationExclusionReason'])}",
                f"      runbookReference: {_yaml_scalar(aria_at['runbookReference'])}",
            ]
        )
        expectations = aria_at.get("functionalExpectations", [])
        if expectations:
            lines.append("      functionalExpectations:")
            lines.extend(
                f"        - {_yaml_scalar(expectation)}" for expectation in expectations
            )
        else:
            lines.append("      functionalExpectations: []")
        _append_yaml_commands(
            lines,
            "      ",
            "commands",
            aria_at.get("commands", []),
        )
        _append_yaml_assertions(
            lines,
            "      ",
            "assertions",
            aria_at.get("assertions", []),
        )
        variants = aria_at.get("variants", [])
        if variants:
            lines.append("      variants:")
        else:
            lines.append("      variants: []")
        for variant in variants:
            lines.append(f"        - id: {_yaml_scalar(variant.get('id'))}")
            lines.append(f"          at: {_yaml_scalar(variant.get('at'))}")
            lines.append(f"          platform: {_yaml_scalar(variant.get('platform'))}")
            lines.append(
                "          automationEligible: "
                f"{_yaml_scalar(variant.get('automationEligible'))}"
            )
            lines.append(
                "          automationExclusionReason: "
                f"{_yaml_scalar(variant.get('automationExclusionReason'))}"
            )
            if variant.get("at") == "jaws":
                lines.append(
                    "          manualEvidenceRequired: "
                    f"{_yaml_scalar(variant.get('manualEvidenceRequired', False))}"
                )
                lines.append(
                    "          runbookReference: "
                    f"{_yaml_scalar(variant.get('runbookReference'))}"
                )
            _append_yaml_commands(
                lines,
                "          ",
                "commands",
                variant.get("commands", []),
            )
            _append_yaml_assertions(
                lines,
                "          ",
                "assertions",
                variant.get("assertions", []),
            )
        lines.extend(
            [
                "    adequateMethods:",
            ]
        )
        lines.extend(
            f"      - {_yaml_scalar(method)}" for method in case["adequateMethods"]
        )
        lines.append("    steps:")
        lines.extend(f"      - {_yaml_scalar(step)}" for step in case["steps"])
        lines.extend(
            [
                f"    expectedResult: {_yaml_scalar(case['expectedResult'])}",
                "    result:",
                '      outcome: "not-run"',
                '      observedResult: ""',
                '      evidenceUri: ""',
                '      tester: ""',
                '      testDate: ""',
            ]
        )

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
