# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path


def _load_module():
    script_path = (
        Path(__file__).resolve().parents[1] / "scripts" / "generate_cards.py"
    )
    spec = importlib.util.spec_from_file_location("generate_cards", script_path)
    module = importlib.util.module_from_spec(spec)
    assert spec is not None and spec.loader is not None
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def test_extract_section_parses_markdown_block() -> None:
    module = _load_module()
    body = "## Scenario\n\n### Description\nAlpha\n\n### How Might We\nBeta\n"
    assert module.extract_section(body, "Description") == "Alpha"
    assert module.extract_section(body, "How Might We") == "Beta"


def test_template_selection_for_supported_card_types() -> None:
    module = _load_module()
    assert module.template_for_type("Vision Statement").name == "vision.content.yaml"
    assert module.template_for_type("Problem Statement").name == "problem.content.yaml"
    assert module.template_for_type("Scenario").name == "scenario.content.yaml"
    assert module.template_for_type("Use Case").name == "use-case-slide1.content.yaml"
    assert module.template_for_type("Persona").name == "persona.content.yaml"


def test_emit_content_yaml_shape(tmp_path: Path) -> None:
    module = _load_module()
    canonical = tmp_path / "canonical"
    canonical.mkdir(parents=True)
    (canonical / "vision-statement.md").write_text(
        "---\ntitle: Vision Statement\n---\n\n"
        "## Vision Statement\nA customer-ready vision.",
        encoding="utf-8",
    )

    cards = module.collect_cards(canonical)
    output_dir = tmp_path / "render" / "content"
    module.write_outputs(cards, output_dir)

    rendered = (output_dir / "slide-001" / "content.yaml").read_text(encoding="utf-8")
    assert "slide:" in rendered
    assert "elements:" in rendered
    assert "{{TITLE}}" not in rendered


def test_regression_body_max_does_not_raise(tmp_path: Path) -> None:
    module = _load_module()
    canonical = tmp_path / "canonical"
    (canonical / "scenarios").mkdir(parents=True)
    (canonical / "scenarios" / "scenario-a.md").write_text(
        "---\ntitle: Scenario A\n---\n\n## Scenario A\n\n"
        "### Description\nA\n\n"
        "### Scenario Narrative\nB\n\n"
        "### How Might We\nC\n",
        encoding="utf-8",
    )

    cards = module.collect_cards(canonical)
    output_dir = tmp_path / "render" / "content"
    module.write_outputs(cards, output_dir)

    assert (output_dir / "slide-001" / "content.yaml").exists()


def test_regression_t_s_escaped_in_rendered_yaml() -> None:
    module = _load_module()
    card = module.Card(
        artifact_type="Vision Statement",
        title='A "quoted" title',
        summary='Summary with "quotes" and newline\\nnext',
        source_path="vision-statement.md",
        last_updated="2026-04-21",
    )
    rendered = module.render_slide(card, 1)
    assert '\\"quoted\\"' in rendered
    assert "{{TITLE}}" not in rendered


def test_yaml_escape_encodes_list_newlines() -> None:
    module = _load_module()
    raw = "- first item\n- second item\n- third item"
    escaped = module.yaml_escape(raw)
    assert escaped == "- first item\\n- second item\\n- third item"


def test_yaml_escape_unwraps_hard_wrapped_prose() -> None:
    module = _load_module()
    raw = (
        "Enable shift-based operations teams to hand off maintenance issues "
        "as complete,\n"
        "actionable work so the incoming shift can recognize urgency, "
        "understand context,\n"
        "and continue follow-up without re-diagnosing the issue."
    )
    escaped = module.yaml_escape(raw)
    assert "\\n" not in escaped
    assert "complete, actionable work" in escaped


def test_real_section_content_flows_into_rendered_cards(tmp_path: Path) -> None:
    module = _load_module()
    canonical = tmp_path / "canonical"
    (canonical / "scenarios").mkdir(parents=True)
    (canonical / "personas").mkdir(parents=True)

    (canonical / "vision-statement.md").write_text(
        "---\n"
        'title: "Rental Gap Finder - Vision"\n'
        "date: \"2026-04-21\"\n"
        "---\n\n"
        "## Vision Statement\n\n"
        "A clear operational back office.\n\n"
        "### Why This Matters\n\n"
        "Context reconstruction is expensive.\n",
        encoding="utf-8",
    )

    (canonical / "scenarios" / "maintenance-scramble.md").write_text(
        "---\n"
        'title: "Maintenance Scramble"\n'
        "---\n\n"
        "### Description\n\n"
        "Tenant reports sink issue at 9pm.\n\n"
        "### Scenario Narrative\n\n"
        "Landlord searches across tools before responding.\n\n"
        "### How Might We\n\n"
        "How might we provide instant unit context?\n",
        encoding="utf-8",
    )

    (canonical / "personas" / "part-time-landlord.md").write_text(
        "---\n"
        'title: "Part Time Landlord"\n'
        "---\n\n"
        "### Description\n\n"
        "Owns 1-3 units and self-manages.\n\n"
        "### User Goal\n\n"
        "Resolve tenant requests quickly.\n\n"
        "### User Needs\n\n"
        "Fast context retrieval across docs and contacts.\n\n"
        "### User Mindset\n\n"
        "I am not a professional property manager.\n",
        encoding="utf-8",
    )

    cards = module.collect_cards(canonical)
    output_dir = tmp_path / "render" / "content"
    module.write_outputs(cards, output_dir)

    vision = (output_dir / "slide-001" / "content.yaml").read_text(encoding="utf-8")
    scenario = (output_dir / "slide-002" / "content.yaml").read_text(encoding="utf-8")
    persona = (output_dir / "slide-003" / "content.yaml").read_text(encoding="utf-8")

    assert "A clear operational back office." in vision
    assert "Context reconstruction is expensive." in vision
    assert "Description" in scenario
    assert "Tenant reports sink issue at 9pm." in scenario
    assert "Scenario Narrative" in scenario
    assert "Landlord searches across tools before responding." in scenario
    assert "How Might We" in scenario
    assert "How might we provide instant unit context?" in scenario
    assert "Description" in persona
    assert "Owns 1-3 units and self-manages." in persona
    assert "Goal" in persona
    assert "Resolve tenant requests quickly." in persona
    assert "Needs" in persona
    assert "Fast context retrieval across docs and contacts." in persona
    assert "Mindset" in persona
    assert "I am not a professional property manager." in persona


def test_use_case_slide2_replaces_primary_user_placeholder(tmp_path: Path) -> None:
    module = _load_module()
    canonical = tmp_path / "canonical"
    (canonical / "use-cases").mkdir(parents=True)

    (canonical / "use-cases" / "resolve-maintenance.md").write_text(
        "---\n"
        'title: "Resolve Maintenance"\n'
        "---\n\n"
        "### Use Case Description\nA\n\n"
        "### Use Case Overview\nB\n\n"
        "### Business Value\nC\n\n"
        "### Primary User\nIncoming Shift Supervisor\n\n"
        "### Secondary User\nMaintenance Technician\n\n"
        "### Preconditions\nIssue exists\n\n"
        "### Steps\n1. Review issue\n\n"
        "### Data Requirements\nAsset id\n\n"
        "### Equipment Requirements\nDevice\n\n"
        "### Operating Environment\nFloor\n\n"
        "### Success Criteria\nResolved\n\n"
        "### Pain Points\nDelay\n\n"
        "### Extensions\nEscalate\n\n"
        "### Evidence\nInterview\n",
        encoding="utf-8",
    )

    cards = module.collect_cards(canonical)
    output_dir = tmp_path / "render" / "content"
    module.write_outputs(cards, output_dir)

    # Use Case expands to 4 slides; slide 2 should include primary user replacement.
    rendered = (output_dir / "slide-002" / "content.yaml").read_text(encoding="utf-8")
    assert "{{UC_PRIMARY_USER}}" not in rendered
    assert "Incoming Shift Supervisor" in rendered
