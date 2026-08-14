#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Generate a markdown STRIDE/NIST report from a threat-model spec."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Any

from generate_tm7 import (
    DISCLAIMER_TEXT,
    GenerationError,
    build_tm7_payload,
    load_spec,
    resolve_profile,
)

EXIT_SUCCESS = 0
EXIT_ERROR = 2


def create_parser() -> argparse.ArgumentParser:
    """Create the CLI parser for markdown generation."""
    parser = argparse.ArgumentParser(
        description="Generate a markdown threat-model report"
    )
    parser.add_argument("spec", type=Path, help="Path to the input threat-model spec")
    parser.add_argument("-o", "--output", type=Path, default=Path("report.md"))
    return parser


def _format_section(title: str, content: list[str]) -> str:
    """Format a markdown section."""
    lines = [f"## {title}", ""]
    lines.extend(content)
    lines.append("")
    return "\n".join(lines)


def _format_optional_text(value: Any) -> str:
    """Format optional values for markdown output."""
    if value in (None, "", []):
        return "n/a"
    if isinstance(value, list):
        return ", ".join(str(item) for item in value if str(item))
    return str(value)


def build_markdown_report(
    spec: dict[str, Any], profile: dict[str, Any], mode: str
) -> str:
    """Build a markdown report from the threat-model spec."""
    project_name = str(spec.get("project_metadata", {}).get("name", "Threat Model"))
    project_summary = str(spec.get("project_metadata", {}).get("summary", ""))
    representations = spec.get("representations") or {}
    context_diagrams = representations.get("context_diagrams") or []
    functional_scenarios = representations.get("functional_scenarios") or []
    operational_views = representations.get("operational_views") or []
    payload = build_tm7_payload(spec, profile, mode)
    threats = payload.get("ThreatInstances", [])

    lines = [
        "# Threat Model STRIDE/NIST Report",
        "",
        "> [!CAUTION]",
        f"> **Disclaimer:** {DISCLAIMER_TEXT}",
        "",
        "## Overview",
        "",
        f"- Project: {project_name}",
        f"- Summary: {project_summary}",
        f"- Mode: {mode}",
        f"- Profile: {profile.get('name', 'sdl_core_generic')}",
        "",
        "## System Overview",
        "",
        f"- Project summary: {project_summary}",
        f"- Context diagrams: {len(context_diagrams)}",
        f"- Functional scenarios: {len(functional_scenarios)}",
        f"- Operational views: {len(operational_views)}",
        "",
        "## Data Flow Diagram Summary",
        "",
    ]

    for surface in payload.get("Surfaces", []):
        lines.append(
            f"- {surface.get('name', surface.get('id', 'surface'))}: "
            f"{len(surface.get('elements', []))} elements, "
            f"{len(surface.get('flows', []))} flows"
        )

    lines.extend(["", "## Per-Element STRIDE Threat Tables", ""])
    for element in payload.get("Elements", []):
        element_threats = [
            threat
            for threat in threats
            if threat.get("target_ref") == element.get("id")
        ]
        if not element_threats:
            continue
        lines.append(f"### {element.get('name', element.get('id', 'element'))}")
        lines.append("")
        lines.append("| ID | STRIDE | Title | Notes |")
        lines.append("| --- | --- | --- | --- |")
        for threat in element_threats:
            stride = ", ".join(threat.get("citations", {}).get("stride", []))
            lines.append(
                f"| {threat.get('id', '')} | {stride} | "
                f"{threat.get('title', '')} | {threat.get('notes', '')} |"
            )
        lines.append("")

    lines.extend(["## NIST Control-Family Mappings", ""])
    nist_families = sorted(
        {
            family
            for threat in threats
            for family in threat.get("citations", {}).get("nist", [])
        }
    )
    if nist_families:
        lines.extend(f"- {family}" for family in nist_families)
    else:
        lines.append("- None")

    lines.extend(["", "## Evil User Stories", ""])
    evil_user_stories = []
    for abuse_case in spec.get("abuse_cases") or []:
        if not isinstance(abuse_case, dict):
            continue
        evil_story = abuse_case.get("evil_user_story")
        if evil_story:
            evil_user_stories.append(evil_story)
            lines.append(f"- {evil_story}")
    if not evil_user_stories:
        lines.append("- None")

    lines.extend(["", "## Data Classification", ""])
    classification_rows: list[str] = []
    for asset in spec.get("assets") or []:
        if not isinstance(asset, dict):
            continue
        category = _format_optional_text(asset.get("category"))
        sensitivity = _format_optional_text(asset.get("sensitivity"))
        classification_rows.append(
            f"- {asset.get('name', asset.get('id', 'asset'))}: "
            f"category={category}, sensitivity={sensitivity}"
        )
    if classification_rows:
        lines.extend(classification_rows)
    else:
        lines.append("- None")

    lines.extend(["", "## Data Flow Retention", ""])
    retention_rows: list[str] = []
    for flow in spec.get("data_flows") or []:
        if not isinstance(flow, dict):
            continue
        retention = flow.get("retention")
        if retention:
            retention_rows.append(f"- {flow.get('id', 'flow')}: retention={retention}")
    if retention_rows:
        lines.extend(retention_rows)
    else:
        lines.append("- None")

    lines.extend(["", "## Abuse Cases", ""])
    for abuse_case in spec.get("abuse_cases") or []:
        if isinstance(abuse_case, dict):
            lines.append(
                f"- {abuse_case.get('title', 'Abuse case')}: "
                f"{abuse_case.get('description', '')}"
            )

    lines.extend(["", "## Security Test Cases", ""])
    for test_case in spec.get("security_test_cases") or []:
        if isinstance(test_case, dict):
            lines.append(
                f"- {test_case.get('title', 'Test case')}: "
                f"{test_case.get('expected_result', '')}"
            )

    lines.extend(["", "## Threat Summary", ""])
    for threat in threats:
        stride_text = ", ".join(threat.get("citations", {}).get("stride", []))
        nist_text = ", ".join(threat.get("citations", {}).get("nist", []))
        lines.append(
            f"- ID: {threat.get('id', '')} | STRIDE: {stride_text} | NIST: {nist_text}"
        )

    lines.append("")
    return "\n".join(lines)


def write_markdown(output_path: Path, content: str) -> None:
    """Write markdown content to disk."""
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(content, encoding="utf-8")


def main() -> int:
    """CLI entry point."""
    parser = create_parser()
    args = parser.parse_args()
    try:
        spec = load_spec(args.spec)
        # Profiles ship with the package, so they resolve from the package root
        # exactly as generate_tm7 resolves them. Deriving the directory from the
        # spec location would let an external spec select a different profile
        # than the TM7 generator chose for the same input.
        template_dir = Path(__file__).resolve().parent.parent
        profile = resolve_profile(spec, None, template_dir)
        profile["name"] = spec.get("template_profile") or "sdl_core_generic"
        mode = str(spec.get("mode") or "pre-populated-comprehensive")
        report = build_markdown_report(spec, profile, mode)
        write_markdown(args.output, report)
        print(f"Generated {args.output}")
        return EXIT_SUCCESS
    except GenerationError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return EXIT_ERROR
    except KeyboardInterrupt:
        print("\nInterrupted by user", file=sys.stderr)
        return 130
    except BrokenPipeError:
        sys.stderr.close()
        return EXIT_ERROR


if __name__ == "__main__":
    sys.exit(main())
