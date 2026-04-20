#!/usr/bin/env python3
"""
Customer Card YAML Generator

Reads canonical markdown from <canonical-dir> and produces PowerPoint skill
YAML content files under <output-dir>/content/. Each canonical artifact type
maps to one slide per the mapping spec in mapping-spec.md.

Usage:
    python generate_cards.py [--canonical-dir PATH] [--output-dir PATH] [-v]
"""

import argparse
import datetime as dt
import logging
import re
import shutil
import sys
from pathlib import Path

logger = logging.getLogger(__name__)

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_ERROR = 2

_SCRIPT_DIR = Path(__file__).parent
_DEFAULT_CANONICAL = _SCRIPT_DIR.parent / "canonical"
_DEFAULT_OUTPUT = _SCRIPT_DIR / "content"

ACCENT_COLORS: dict[str, str] = {
    "Vision Statement": "#0078D4",
    "Problem Statement": "#D83B01",
    "Scenario": "#107C10",
    "Persona": "#5C2D91",
    "Use Case": "#0E7490",
}

TYPE_LABELS: dict[str, str] = {
    "Vision Statement": "VISION STATEMENT",
    "Problem Statement": "PROBLEM STATEMENT",
    "Scenario": "SCENARIO",
    "Persona": "PERSONA",
    "Use Case": "USE CASE",
}


def configure_logging(verbose: bool = False) -> None:
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(level=level, format="%(levelname)s: %(message)s")


def parse_frontmatter(text: str) -> tuple[dict[str, str], str]:
    match = re.match(r"^---\s*\n(.*?)\n---\s*\n", text, re.DOTALL)
    if not match:
        return {}, text
    fields: dict[str, str] = {}
    for line in match.group(1).splitlines():
        if ":" in line:
            key, _, val = line.partition(":")
            fields[key.strip()] = val.strip()
    return fields, text[match.end():]


def extract_first_heading(body: str) -> str:
    match = re.search(r"(?im)^\s*#{1,3}\s+(.+?)\s*$", body)
    return match.group(1).strip() if match else ""


def extract_summary(body: str) -> str:
    explicit = extract_section(body, "Customer-friendly summary")
    if explicit:
        return explicit

    match = re.search(
        r"(?ims)^\s*#{1,3}\s+.+?\s*\r?\n(.*?)(?=^\s*#{1,3}\s+Internal Metadata\s*$|\Z)",
        body,
    )
    if not match:
        return ""
    return match.group(1).strip()


def extract_intro_under_primary_heading(body: str) -> str:
    """Extract prose directly under the first primary heading before subsections."""
    match = re.search(
        r"(?ims)^\s*##\s+.+?\s*\r?\n(.*?)(?=^\s*#{2,3}\s+|\Z)",
        body,
    )
    if not match:
        return ""
    return match.group(1).strip()


def extract_section_summary(body: str, headings: list[str]) -> str:
    """Extract a single section body for card summary use.

    This avoids falling back to the entire document body when a card type
    should render only a specific canonical section.
    """
    return extract_first_available_section(body, headings)


def extract_section(body: str, heading: str) -> str:
    pattern = rf"(?ims)^\s*#{{2,3}}\s+(?:\d+\.?\s*)?{re.escape(heading)}\s*\r?\n(.*?)(?=^\s*#{{2,3}}\s+|\Z)"
    match = re.search(pattern, body)
    return match.group(1).strip() if match else ""


def extract_first_available_section(body: str, headings: list[str]) -> str:
    for heading in headings:
        section = extract_section(body, heading)
        if section:
            return section
    return ""


def extract_metadata_field(body: str, field_name: str) -> str:
    match = re.search(
        rf"(?im)^\|\s*{re.escape(field_name)}\s*\|\s*(.+?)\s*\|\s*\r?$", body
    )
    return match.group(1).strip() if match else ""


def extract_metadata_table(body: str) -> dict[str, str]:
    metadata: dict[str, str] = {}
    table_block_match = re.search(
        r"(?ims)^\s*#{2,3}\s+Internal Metadata\s*\r?\n(.*?)(?=^\s*#{2,3}\s+|\Z)",
        body,
    )
    if not table_block_match:
        return metadata

    table_block = table_block_match.group(1)
    for line in table_block.splitlines():
        stripped = line.strip()
        if not stripped.startswith("|"):
            continue
        cells = [cell.strip() for cell in stripped.strip("|").split("|")]
        if len(cells) < 2:
            continue
        key = cells[0]
        value = cells[1]
        if set(key) <= {"-", ":"}:
            continue
        metadata[key.lower()] = value
    return metadata


def infer_artifact_type(path: Path) -> str:
    lower_name = path.name.lower()
    parent = path.parent.name.lower()
    if lower_name == "vision-statement.md":
        return "Vision Statement"
    if lower_name == "problem-statement.md":
        return "Problem Statement"
    if parent == "scenarios":
        return "Scenario"
    if parent == "personas":
        return "Persona"
    if parent == "use-cases":
        return "Use Case"
    return "Unknown"


def yaml_str(text: str, max_chars: int = 0, preserve_lines: bool = False) -> str:
    """Normalize and escape text for YAML double-quoted strings without truncation."""
    _ = max_chars
    if preserve_lines:
        normalized_lines = [ln.strip() for ln in text.splitlines()]
        text = "\n".join(normalized_lines).strip()
    else:
        text = re.sub(r"\s+", " ", text).strip()
    return text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def format_markdown_for_slide(text: str) -> str:
    """Convert markdown-like blocks into slide-friendly text preserving list semantics."""
    lines = text.splitlines()
    out: list[str] = []
    paragraph_parts: list[str] = []

    def flush_paragraph() -> None:
        if paragraph_parts:
            out.append(" ".join(paragraph_parts).strip())
            paragraph_parts.clear()

    for raw in lines:
        line = raw.strip()
        if not line:
            flush_paragraph()
            continue

        bullet_match = re.match(r"^[*]\s+(.*)$", line)
        if bullet_match:
            flush_paragraph()
            out.append(f"• {bullet_match.group(1).strip()}")
            continue

        ordered_match = re.match(r"^(\d+)\.\s+(.*)$", line)
        if ordered_match:
            flush_paragraph()
            out.append(f"{ordered_match.group(1)}. {ordered_match.group(2).strip()}")
            continue

        paragraph_parts.append(line)

    flush_paragraph()
    return "\n".join(out)


def _slide_yaml(
    slide_num: int,
    artifact_type: str,
    title: str,
    summary: str,
    source_path: str,
    last_updated: str,
    extra_fields: dict[str, str],
    has_image_slot: bool,
) -> str:
    """Render a complete content.yaml string for one customer card slide."""
    accent = ACCENT_COLORS.get(artifact_type, "#0078D4")
    badge_label = TYPE_LABELS.get(artifact_type, artifact_type.upper())

    wide_body = not has_image_slot
    body_max = 380 if wide_body else 260
    body_w = 11.8 if wide_body else 7.9

    needs_extra_rows = len(extra_fields)
    if needs_extra_rows >= 2:
        body_h = 2.7
    elif needs_extra_rows == 1:
        body_h = 3.1
    else:
        body_h = 3.85

    t = yaml_str(title)
    s = yaml_str(summary)
    src = yaml_str(source_path)

    lines = [
        f"slide: {slide_num}",
        f'title: "{t}"',
        'section: "Customer Cards"',
        'layout: "blank"',
        "",
        "background:",
        '  fill: "#0F1117"',
        "",
        "elements:",
        "",
        "  # Card frame",
        "  - type: shape",
        "    shape: rectangle",
        "    left: 0.25",
        "    top: 0.25",
        "    width: 12.833",
        "    height: 7.0",
        '    fill: "#1A1D27"',
        "",
        "  # Top accent bar",
        "  - type: shape",
        "    shape: rectangle",
        "    left: 0.25",
        "    top: 0.25",
        "    width: 12.833",
        "    height: 0.08",
        f'    fill: "{accent}"',
        "",
        "  # Card type badge",
        "  - type: shape",
        "    shape: rounded_rectangle",
        "    left: 0.55",
        "    top: 0.55",
        "    width: 2.50",
        "    height: 0.36",
        f'    fill: "{accent}"',
        "    corner_radius: 0.08",
        f'    text: "{badge_label}"',
        '    text_font: "Segoe UI"',
        "    text_size: 9",
        '    text_color: "#FFFFFF"',
        "    text_bold: true",
        "",
        "  # Title",
        "  - type: textbox",
        "    left: 0.55",
        "    top: 1.10",
        "    width: 11.80",
        "    height: 1.35",
        f'    text: "{t}"',
        '    font: "Segoe UI"',
        "    font_size: 28",
        '    font_color: "#FFFFFF"',
        "    font_bold: true",
        "    alignment: left",
        "",
        "  # Divider",
        "  - type: shape",
        "    shape: rectangle",
        "    left: 0.55",
        "    top: 2.58",
        "    width: 11.80",
        "    height: 0.02",
        f'    fill: "{accent}"',
        "",
        "  # Summary",
        "  - type: textbox",
        "    left: 0.55",
        "    top: 2.75",
        f"    width: {body_w:.2f}",
        f"    height: {body_h:.2f}",
        f'    text: "{s}"',
        '    font: "Segoe UI"',
        "    font_size: 15",
        '    font_color: "#C8C8DC"',
        '    auto_size: "shrink"',
        "    alignment: left",
    ]

    if has_image_slot:
        lines += [
            "",
            "  # Image placeholder — replace path with an actual image asset",
            "  - type: shape",
            "    shape: rounded_rectangle",
            "    left: 9.10",
            "    top: 2.75",
            "    width: 3.70",
            "    height: 3.40",
            '    fill: "#2D3142"',
            "    corner_radius: 0.12",
            '    text: "[Add Image]"',
            '    text_font: "Segoe UI"',
            "    text_size: 13",
            '    text_color: "#4D506A"',
        ]

    if extra_fields:
        extra_top = 2.75 + body_h + 0.10
        for field_label, value in extra_fields.items():
            v = yaml_str(value)
            al = field_label.upper()
            lines += [
                "",
                f"  # Extra field: {field_label}",
                "  - type: textbox",
                "    left: 0.55",
                f"    top: {extra_top:.2f}",
                "    width: 7.90",
                "    height: 0.38",
                f'    text: "{al}  {v}"',
                '    font: "Segoe UI"',
                "    font_size: 12",
                f'    font_color: "{accent}"',
                "    font_bold: false",
                '    auto_size: "shrink"',
                "    alignment: left",
            ]
            extra_top += 0.50

    lines += [
        "",
        "  # Footer: source path",
        "  - type: textbox",
        "    left: 0.55",
        "    top: 6.88",
        "    width: 9.50",
        "    height: 0.25",
        f'    text: "Source: {src}"',
        '    font: "Segoe UI"',
        "    font_size: 9",
        '    font_color: "#555570"',
        "    alignment: left",
        "",
        "  # Footer: last updated",
        "  - type: textbox",
        "    left: 11.00",
        "    top: 6.88",
        "    width: 2.10",
        "    height: 0.25",
        f'    text: "{last_updated}"',
        '    font: "Segoe UI"',
        "    font_size: 9",
        '    font_color: "#555570"',
        "    alignment: right",
        "",
        f'speaker_notes: "Card type: {badge_label}. Source: {src}"',
    ]

    return "\n".join(lines) + "\n"


def parse_card_file(path: Path, canonical_root: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    fm, body = parse_frontmatter(text)
    metadata = extract_metadata_table(body)
    artifact_type = (
        metadata.get("artifact type")
        or metadata.get("source artifact type")
        or extract_metadata_field(body, "Artifact type")
        or extract_metadata_field(body, "Source artifact type")
        or infer_artifact_type(path)
    )
    source_path = (
        metadata.get("source path")
        or metadata.get("source file path")
        or extract_metadata_field(body, "Source path")
        or extract_metadata_field(body, "Source file path")
        or path.relative_to(canonical_root).as_posix()
    )
    last_updated = (
        metadata.get("last updated")
        or extract_metadata_field(body, "Last updated")
        or dt.date.today().isoformat()
    )
    title = (
        fm.get("title")
        or extract_first_heading(body)
        or path.stem.replace("-", " ").title()
    )

    summary = extract_summary(body)
    extra: dict[str, str] = {}
    sub_sections: dict[str, str] = {}
    has_image = False

    if artifact_type == "Vision Statement":
        summary = extract_section_summary(
            body, ["Vision Statement", "Vision", "Customer-friendly summary"]
        ) or extract_summary(body)
        sub_sections = {
            "why_this_matters": extract_section(body, "Why This Matters"),
        }

    elif artifact_type == "Problem Statement":
        summary = extract_section_summary(
            body, ["Problem Statement", "Customer-friendly summary"]
        ) or extract_summary(body)

    elif artifact_type == "Persona":
        sub_sections = {
            "description": extract_section(body, "Description"),
            "user_goal": extract_section(body, "User Goal"),
            "user_needs": extract_section(body, "User Needs"),
            "user_mindset": extract_section(body, "User Mindset"),
        }
        summary = sub_sections["description"] or extract_section_summary(
            body, ["Customer-friendly summary"]
        )

    elif artifact_type == "Scenario":
        description = extract_first_available_section(body, ["Description"])
        if not description:
            description = extract_intro_under_primary_heading(body)
        scenario_narrative = extract_section_summary(
            body,
            ["Scenario Narrative", "Scenario Overview", "Customer-friendly summary"],
        )
        sub_sections = {
            "description": description,
            "scenario_narrative": scenario_narrative,
            "how_might_we": extract_first_available_section(body, ["How Might We"]),
        }
        summary = description or scenario_narrative

    elif artifact_type == "Use Case":
        use_case_description = extract_first_available_section(
            body,
            ["Use Case Description", "Use Case Summary", "Customer-friendly summary"],
        ) or extract_summary(body)
        sub_sections = {
            "use_case_description": use_case_description,
            "business_value": extract_section(body, "Business Value"),
            "use_case_overview": extract_first_available_section(
                body, ["Use Case Overview", "Scenario Overview"]
            ),
            "primary_user": extract_first_available_section(
                body, ["Primary User", "Primary Actor"]
            ),
            "secondary_user": extract_first_available_section(
                body,
                ["Secondary User", "Secondary Users", "Secondary User Personas"],
            ),
            "preconditions": extract_section(body, "Preconditions"),
            "steps": extract_first_available_section(body, ["Steps", "Main Flow"]),
            "data_requirements": extract_section(body, "Data Requirements"),
            "equipment_requirements": extract_section(body, "Equipment Requirements"),
            "operating_environment": extract_section(body, "Operating Environment"),
            "success_criteria": extract_section(body, "Success Criteria"),
            "pain_points": extract_first_available_section(
                body, ["Pain Points", "Known Pain Point"]
            ),
            "evidence": extract_first_available_section(
                body, ["Evidence", "Observable Evidence"]
            ),
        }
        summary = use_case_description
    else:
        sub_sections = {}

    return {
        "artifact_type": artifact_type,
        "title": title,
        "summary": summary,
        "source_path": source_path,
        "last_updated": last_updated,
        "extra_fields": extra,
        "has_image_slot": has_image,
        "sub_sections": sub_sections,
    }


def _scenario_slide_yamls(
    slide_num: int,
    title: str,
    summary: str,
    source_path: str,
    last_updated: str,
    sub_sections: dict[str, str],
) -> list[str]:
    """Render a scenario card with Description, Scenario Narrative, and How Might We."""
    accent = ACCENT_COLORS["Scenario"]
    badge_label = TYPE_LABELS["Scenario"]

    t = yaml_str(title)
    src = yaml_str(source_path)

    def sub_block(
        label: str, raw_text: str, x: float, top: float, width: float, height: float
    ) -> list[str]:
        c = yaml_str(format_markdown_for_slide(raw_text), preserve_lines=True)
        return [
            f"  # {label}",
            "  - type: textbox",
            f"    left: {x:.2f}",
            f"    top: {top:.2f}",
            f"    width: {width:.2f}",
            "    height: 0.21",
            f'    text: "{label.upper()}"',
            '    font: "Segoe UI"',
            "    font_size: 9",
            f'    font_color: "{accent}"',
            "    font_bold: true",
            "    alignment: left",
            "",
            "  - type: textbox",
            f"    left: {x:.2f}",
            f"    top: {top + 0.23:.2f}",
            f"    width: {width:.2f}",
            f"    height: {height:.2f}",
            f'    text: "{c}"',
            '    font: "Segoe UI"',
            "    font_size: 11",
            '    font_color: "#C8C8DC"',
            "    font_bold: false",
            '    auto_size: "shrink"',
            "    alignment: left",
        ]

    lines = [
        f"slide: {slide_num}",
        f'title: "{t}"',
        'section: "Customer Cards"',
        'layout: "blank"',
        "",
        "background:",
        '  fill: "#0F1117"',
        "",
        "elements:",
        "",
        "  # Card frame",
        "  - type: shape",
        "    shape: rectangle",
        "    left: 0.25",
        "    top: 0.25",
        "    width: 12.833",
        "    height: 7.0",
        '    fill: "#1A1D27"',
        "",
        "  # Top accent bar",
        "  - type: shape",
        "    shape: rectangle",
        "    left: 0.25",
        "    top: 0.25",
        "    width: 12.833",
        "    height: 0.08",
        f'    fill: "{accent}"',
        "",
        "  # Card type badge",
        "  - type: shape",
        "    shape: rounded_rectangle",
        "    left: 0.55",
        "    top: 0.55",
        "    width: 2.50",
        "    height: 0.36",
        f'    fill: "{accent}"',
        "    corner_radius: 0.08",
        f'    text: "{badge_label}"',
        '    text_font: "Segoe UI"',
        "    text_size: 9",
        '    text_color: "#FFFFFF"',
        "    text_bold: true",
        "",
        "  # Title",
        "  - type: textbox",
        "    left: 0.55",
        "    top: 1.10",
        "    width: 11.80",
        "    height: 1.00",
        f'    text: "{t}"',
        '    font: "Segoe UI"',
        "    font_size: 22",
        '    font_color: "#FFFFFF"',
        "    font_bold: true",
        "    alignment: left",
        "",
        "  # Divider",
        "  - type: shape",
        "    shape: rectangle",
        "    left: 0.55",
        "    top: 2.30",
        "    width: 11.80",
        "    height: 0.02",
        f'    fill: "{accent}"',
    ]

    description = sub_sections.get("description", "") or summary
    narrative = sub_sections.get("scenario_narrative", "")
    hmw = sub_sections.get("how_might_we", "")
    narrative_top = 2.52
    narrative_height = 3.95

    if description:
        lines += [""] + sub_block("Description", description, 0.55, 2.52, 11.80, 0.95)
        lines += [
            "",
            "  # Section grid divider",
            "  - type: shape",
            "    shape: rectangle",
            "    left: 0.55",
            "    top: 3.95",
            "    width: 11.80",
            "    height: 0.01",
            '    fill: "#2D3142"',
        ]
        narrative_top = 4.12
        narrative_height = 2.35
    else:
        lines += [
            "",
            "  # Section grid divider",
            "  - type: shape",
            "    shape: rectangle",
            "    left: 0.55",
            "    top: 2.42",
            "    width: 11.80",
            "    height: 0.01",
            '    fill: "#2D3142"',
        ]

    if narrative:
        lines += [""] + sub_block(
            "Scenario Narrative", narrative, 0.55, narrative_top, 5.75, narrative_height
        )
    if hmw:
        lines += [""] + sub_block(
            "How Might We", hmw, 6.60, narrative_top, 5.75, narrative_height
        )

    lines += [
        "",
        "  # Footer: source path",
        "  - type: textbox",
        "    left: 0.55",
        "    top: 6.88",
        "    width: 9.50",
        "    height: 0.25",
        f'    text: "Source: {src}"',
        '    font: "Segoe UI"',
        "    font_size: 9",
        '    font_color: "#555570"',
        "    alignment: left",
        "",
        "  # Footer: last updated",
        "  - type: textbox",
        "    left: 11.00",
        "    top: 6.88",
        "    width: 2.10",
        "    height: 0.25",
        f'    text: "{last_updated}"',
        '    font: "Segoe UI"',
        "    font_size: 9",
        '    font_color: "#555570"',
        "    alignment: right",
        "",
        f'speaker_notes: "Card type: {badge_label}. Source: {src}"',
    ]
    return ["\n".join(lines) + "\n"]


def _vision_slide_yaml(
    slide_num: int,
    title: str,
    summary: str,
    source_path: str,
    last_updated: str,
    sub_sections: dict[str, str],
) -> str:
    """Render a vision card with the summary and Why This Matters section."""
    accent = ACCENT_COLORS["Vision Statement"]
    badge_label = TYPE_LABELS["Vision Statement"]

    t = yaml_str(title)
    s = yaml_str(format_markdown_for_slide(summary), preserve_lines=True)
    src = yaml_str(source_path)
    why_this_matters = sub_sections.get("why_this_matters", "")

    lines = [
        f"slide: {slide_num}",
        f'title: "{t}"',
        'section: "Customer Cards"',
        'layout: "blank"',
        "",
        "background:",
        '  fill: "#0F1117"',
        "",
        "elements:",
        "",
        "  # Card frame",
        "  - type: shape",
        "    shape: rectangle",
        "    left: 0.25",
        "    top: 0.25",
        "    width: 12.833",
        "    height: 7.0",
        '    fill: "#1A1D27"',
        "",
        "  # Top accent bar",
        "  - type: shape",
        "    shape: rectangle",
        "    left: 0.25",
        "    top: 0.25",
        "    width: 12.833",
        "    height: 0.08",
        f'    fill: "{accent}"',
        "",
        "  # Card type badge",
        "  - type: shape",
        "    shape: rounded_rectangle",
        "    left: 0.55",
        "    top: 0.55",
        "    width: 2.50",
        "    height: 0.36",
        f'    fill: "{accent}"',
        "    corner_radius: 0.08",
        f'    text: "{badge_label}"',
        '    text_font: "Segoe UI"',
        "    text_size: 9",
        '    text_color: "#FFFFFF"',
        "    text_bold: true",
        "",
        "  # Title",
        "  - type: textbox",
        "    left: 0.55",
        "    top: 1.10",
        "    width: 11.80",
        "    height: 1.15",
        f'    text: "{t}"',
        '    font: "Segoe UI"',
        "    font_size: 26",
        '    font_color: "#FFFFFF"',
        "    font_bold: true",
        "    alignment: left",
        "",
        "  # Divider",
        "  - type: shape",
        "    shape: rectangle",
        "    left: 0.55",
        "    top: 2.30",
        "    width: 11.80",
        "    height: 0.02",
        f'    fill: "{accent}"',
        "",
        "  # Vision summary",
        "  - type: textbox",
        "    left: 0.55",
        "    top: 2.55",
        "    width: 11.80",
        f'    height: {1.65 if why_this_matters else 3.85:.2f}',
        f'    text: "{s}"',
        '    font: "Segoe UI"',
        "    font_size: 14",
        '    font_color: "#C8C8DC"',
        '    auto_size: "shrink"',
        "    alignment: left",
    ]

    if why_this_matters:
        why = yaml_str(format_markdown_for_slide(why_this_matters), preserve_lines=True)
        lines += [
            "",
            "  # Why This Matters divider",
            "  - type: shape",
            "    shape: rectangle",
            "    left: 0.55",
            "    top: 4.35",
            "    width: 11.80",
            "    height: 0.01",
            '    fill: "#2D3142"',
            "",
            "  # Why This Matters label",
            "  - type: textbox",
            "    left: 0.55",
            "    top: 4.52",
            "    width: 11.80",
            "    height: 0.21",
            '    text: "WHY THIS MATTERS"',
            '    font: "Segoe UI"',
            "    font_size: 9",
            f'    font_color: "{accent}"',
            "    font_bold: true",
            "    alignment: left",
            "",
            "  # Why This Matters body",
            "  - type: textbox",
            "    left: 0.55",
            "    top: 4.75",
            "    width: 11.80",
            "    height: 1.75",
            f'    text: "{why}"',
            '    font: "Segoe UI"',
            "    font_size: 12",
            '    font_color: "#C8C8DC"',
            '    auto_size: "shrink"',
            "    alignment: left",
        ]

    lines += [
        "",
        "  # Footer: source path",
        "  - type: textbox",
        "    left: 0.55",
        "    top: 6.88",
        "    width: 9.50",
        "    height: 0.25",
        f'    text: "Source: {src}"',
        '    font: "Segoe UI"',
        "    font_size: 9",
        '    font_color: "#555570"',
        "    alignment: left",
        "",
        "  # Footer: last updated",
        "  - type: textbox",
        "    left: 11.00",
        "    top: 6.88",
        "    width: 2.10",
        "    height: 0.25",
        f'    text: "{last_updated}"',
        '    font: "Segoe UI"',
        "    font_size: 9",
        '    font_color: "#555570"',
        "    alignment: right",
        "",
        f'speaker_notes: "Card type: {badge_label}. Source: {src}"',
    ]
    return "\n".join(lines) + "\n"


def _use_case_slide_yamls(
    slide_num: int,
    title: str,
    source_path: str,
    last_updated: str,
    sub_sections: dict[str, str],
) -> list[str]:
    """Render paginated use case cards using the required section order."""
    accent = ACCENT_COLORS["Use Case"]
    badge_label = TYPE_LABELS["Use Case"]
    src = yaml_str(source_path)

    ordered_sections = [
        ("Use Case Description", sub_sections.get("use_case_description", "")),
        ("Business Value", sub_sections.get("business_value", "")),
        ("Use Case Overview", sub_sections.get("use_case_overview", "")),
        ("Primary User", sub_sections.get("primary_user", "")),
        ("Secondary User", sub_sections.get("secondary_user", "")),
        ("Preconditions", sub_sections.get("preconditions", "")),
        ("Steps", sub_sections.get("steps", "")),
        ("Data Requirements", sub_sections.get("data_requirements", "")),
        ("Equipment Requirements", sub_sections.get("equipment_requirements", "")),
        ("Operating Environment", sub_sections.get("operating_environment", "")),
        ("Success Criteria", sub_sections.get("success_criteria", "")),
        ("Pain Points", sub_sections.get("pain_points", "")),
        ("Evidence", sub_sections.get("evidence", "")),
    ]
    blocks = [(label, text) for label, text in ordered_sections if text]

    def sub_block(label: str, raw_text: str, x: float, top: float) -> list[str]:
        c = yaml_str(format_markdown_for_slide(raw_text), preserve_lines=True)
        return [
            f"  # {label}",
            "  - type: textbox",
            f"    left: {x:.2f}",
            f"    top: {top:.2f}",
            "    width: 5.75",
            "    height: 0.21",
            f'    text: "{label.upper()}"',
            '    font: "Segoe UI"',
            "    font_size: 9",
            f'    font_color: "{accent}"',
            "    font_bold: true",
            "    alignment: left",
            "",
            "  - type: textbox",
            f"    left: {x:.2f}",
            f"    top: {top + 0.23:.2f}",
            "    width: 5.75",
            "    height: 1.55",
            f'    text: "{c}"',
            '    font: "Segoe UI"',
            "    font_size: 10",
            '    font_color: "#C8C8DC"',
            "    font_bold: false",
            '    auto_size: "shrink"',
            "    alignment: left",
        ]

    def build_page(page_index: int, page_blocks: list[tuple[str, str]]) -> str:
        page_title_text = title if len(chunks) == 1 else f"{title} (Part {page_index + 1})"
        page_title = yaml_str(page_title_text)
        lines = [
            f"slide: {slide_num + page_index}",
            f'title: "{page_title}"',
            'section: "Customer Cards"',
            'layout: "blank"',
            "",
            "background:",
            '  fill: "#0F1117"',
            "",
            "elements:",
            "",
            "  # Card frame",
            "  - type: shape",
            "    shape: rectangle",
            "    left: 0.25",
            "    top: 0.25",
            "    width: 12.833",
            "    height: 7.0",
            '    fill: "#1A1D27"',
            "",
            "  # Top accent bar",
            "  - type: shape",
            "    shape: rectangle",
            "    left: 0.25",
            "    top: 0.25",
            "    width: 12.833",
            "    height: 0.08",
            f'    fill: "{accent}"',
            "",
            "  # Card type badge",
            "  - type: shape",
            "    shape: rounded_rectangle",
            "    left: 0.55",
            "    top: 0.55",
            "    width: 2.50",
            "    height: 0.36",
            f'    fill: "{accent}"',
            "    corner_radius: 0.08",
            f'    text: "{badge_label}"',
            '    text_font: "Segoe UI"',
            "    text_size: 9",
            '    text_color: "#FFFFFF"',
            "    text_bold: true",
            "",
            "  # Title",
            "  - type: textbox",
            "    left: 0.55",
            "    top: 1.10",
            "    width: 11.80",
            "    height: 1.00",
            f'    text: "{page_title}"',
            '    font: "Segoe UI"',
            "    font_size: 22",
            '    font_color: "#FFFFFF"',
            "    font_bold: true",
            "    alignment: left",
            "",
            "  # Divider",
            "  - type: shape",
            "    shape: rectangle",
            "    left: 0.55",
            "    top: 2.30",
            "    width: 11.80",
            "    height: 0.02",
            f'    fill: "{accent}"',
            "",
            "  # Section grid divider",
            "  - type: shape",
            "    shape: rectangle",
            "    left: 0.55",
            "    top: 2.42",
            "    width: 11.80",
            "    height: 0.01",
            '    fill: "#2D3142"',
        ]

        positions = [
            (0.55, 2.52),
            (0.55, 4.33),
            (6.60, 2.52),
            (6.60, 4.33),
        ]
        for (label, text), (x, top) in zip(page_blocks, positions, strict=False):
            lines += [""] + sub_block(label, text, x, top)

        lines += [
            "",
            "  # Footer: source path",
            "  - type: textbox",
            "    left: 0.55",
            "    top: 6.88",
            "    width: 9.50",
            "    height: 0.25",
            f'    text: "Source: {src}"',
            '    font: "Segoe UI"',
            "    font_size: 9",
            '    font_color: "#555570"',
            "    alignment: left",
            "",
            "  # Footer: last updated",
            "  - type: textbox",
            "    left: 11.00",
            "    top: 6.88",
            "    width: 2.10",
            "    height: 0.25",
            f'    text: "{last_updated}"',
            '    font: "Segoe UI"',
            "    font_size: 9",
            '    font_color: "#555570"',
            "    alignment: right",
            "",
            f'speaker_notes: "Card type: {badge_label}. Source: {src}"',
        ]
        return "\n".join(lines) + "\n"

    chunks = [blocks[index : index + 4] for index in range(0, len(blocks), 4)] or [[]]
    return [build_page(page_index, chunk) for page_index, chunk in enumerate(chunks)]


def _persona_slide_yamls(
    slide_num: int,
    title: str,
    summary: str,
    source_path: str,
    last_updated: str,
    sub_sections: dict[str, str],
) -> list[str]:
    """Render two persona slides so all persona sub-sections are represented without truncation."""
    accent = ACCENT_COLORS["Persona"]
    badge_label = TYPE_LABELS["Persona"]

    t = yaml_str(title)
    s = yaml_str(format_markdown_for_slide(summary), preserve_lines=True)
    src = yaml_str(source_path)

    def sub_block(label: str, raw_text: str, x: float, top: float, w: float, content_h: float) -> list[str]:
        c = yaml_str(format_markdown_for_slide(raw_text), preserve_lines=True)
        return [
            f"  # {label}",
            "  - type: textbox",
            f"    left: {x:.2f}",
            f"    top: {top:.2f}",
            f"    width: {w:.2f}",
            "    height: 0.21",
            f'    text: "{label.upper()}"',
            '    font: "Segoe UI"',
            "    font_size: 9",
            f'    font_color: "{accent}"',
            "    font_bold: true",
            "    alignment: left",
            "",
            "  - type: textbox",
            f"    left: {x:.2f}",
            f"    top: {top + 0.23:.2f}",
            f"    width: {w:.2f}",
            f"    height: {content_h:.2f}",
            f'    text: "{c}"',
            '    font: "Segoe UI"',
            "    font_size: 11",
            '    font_color: "#C8C8DC"',
            "    font_bold: false",
            '    auto_size: "shrink"',
            "    alignment: left",
        ]

    def build_page(
        slide_number: int,
        page_title: str,
        left_blocks: list[tuple[str, str]],
        right_blocks: list[tuple[str, str]],
    ) -> str:
        lines = [
            f"slide: {slide_number}",
            f'title: "{page_title}"',
            'section: "Customer Cards"',
            'layout: "blank"',
            "",
            "background:",
            '  fill: "#0F1117"',
            "",
            "elements:",
            "",
            "  # Card frame",
            "  - type: shape",
            "    shape: rectangle",
            "    left: 0.25",
            "    top: 0.25",
            "    width: 12.833",
            "    height: 7.0",
            '    fill: "#1A1D27"',
            "",
            "  # Top accent bar",
            "  - type: shape",
            "    shape: rectangle",
            "    left: 0.25",
            "    top: 0.25",
            "    width: 12.833",
            "    height: 0.08",
            f'    fill: "{accent}"',
            "",
            "  # Card type badge",
            "  - type: shape",
            "    shape: rounded_rectangle",
            "    left: 0.55",
            "    top: 0.55",
            "    width: 2.50",
            "    height: 0.36",
            f'    fill: "{accent}"',
            "    corner_radius: 0.08",
            f'    text: "{badge_label}"',
            '    text_font: "Segoe UI"',
            "    text_size: 9",
            '    text_color: "#FFFFFF"',
            "    text_bold: true",
            "",
            "  # Title",
            "  - type: textbox",
            "    left: 0.55",
            "    top: 1.10",
            "    width: 11.80",
            "    height: 1.00",
            f'    text: "{page_title}"',
            '    font: "Segoe UI"',
            "    font_size: 22",
            '    font_color: "#FFFFFF"',
            "    font_bold: true",
            "    alignment: left",
            "",
            "  # Divider",
            "  - type: shape",
            "    shape: rectangle",
            "    left: 0.55",
            "    top: 2.30",
            "    width: 11.80",
            "    height: 0.02",
            f'    fill: "{accent}"',
            "",
            "  # Section grid divider",
            "  - type: shape",
            "    shape: rectangle",
            "    left: 0.55",
            "    top: 2.42",
            "    width: 11.80",
            "    height: 0.01",
            '    fill: "#2D3142"',
        ]

        left_x, right_x = 0.55, 6.60
        col_w = 5.75
        y_positions = [2.52, 4.33]
        content_height = 1.55

        for i, (label, text) in enumerate(left_blocks[:2]):
            if not label or not text:
                continue
            lines += [""] + sub_block(label, text, left_x, y_positions[i], col_w, content_height)
        for i, (label, text) in enumerate(right_blocks[:2]):
            if not label or not text:
                continue
            lines += [""] + sub_block(label, text, right_x, y_positions[i], col_w, content_height)

        lines += [
            "",
            "  # Footer: source path",
            "  - type: textbox",
            "    left: 0.55",
            "    top: 6.88",
            "    width: 9.50",
            "    height: 0.25",
            f'    text: "Source: {src}"',
            '    font: "Segoe UI"',
            "    font_size: 9",
            '    font_color: "#555570"',
            "    alignment: left",
            "",
            "  # Footer: last updated",
            "  - type: textbox",
            "    left: 11.00",
            "    top: 6.88",
            "    width: 2.10",
            "    height: 0.25",
            f'    text: "{last_updated}"',
            '    font: "Segoe UI"',
            "    font_size: 9",
            '    font_color: "#555570"',
            "    alignment: right",
            "",
            f'speaker_notes: "Card type: {badge_label}. Source: {src}"',
        ]
        return "\n".join(lines) + "\n"

    page_1_title = yaml_str(f"{title} (Part 1)")
    page_2_title = yaml_str(f"{title} (Part 2)")

    page_1_left = [
        ("Customer Summary", summary),
        ("Description", sub_sections.get("description", "")),
    ]
    page_1_right = [
        ("User Goal", sub_sections.get("user_goal", "")),
        ("User Needs", sub_sections.get("user_needs", "")),
    ]

    page_2_left = [("User Mindset", sub_sections.get("user_mindset", ""))]
    page_2_right: list[tuple[str, str]] = []

    def pad_two(blocks: list[tuple[str, str]]) -> list[tuple[str, str]]:
        padded = blocks[:]
        while len(padded) < 2:
            padded.append(("", ""))
        return padded

    def sanitize(blocks: list[tuple[str, str]]) -> list[tuple[str, str]]:
        return [b for b in blocks if b[0] and b[1]]

    page_1_left = sanitize(page_1_left)
    page_1_right = sanitize(page_1_right)
    page_2_left = sanitize(page_2_left)
    page_2_right = sanitize(page_2_right)

    pages = [
        build_page(slide_num, page_1_title, pad_two(page_1_left), pad_two(page_1_right)),
    ]
    if page_2_left or page_2_right:
        pages.append(
            build_page(slide_num + 1, page_2_title, pad_two(page_2_left), pad_two(page_2_right))
        )
    return pages


def collect_cards(canonical_root: Path) -> list[dict]:
    cards = []

    for name in ("vision-statement.md", "problem-statement.md"):
        p = canonical_root / name
        if p.exists():
            card = parse_card_file(p, canonical_root)
            cards.append(card)
            logger.debug("Collected: %s (%s)", p.name, card["artifact_type"])
        else:
            logger.debug("Not found, skipping: %s", p)

    for subdir in ("scenarios", "use-cases", "personas"):
        d = canonical_root / subdir
        if d.is_dir():
            for p in sorted(d.glob("*.md")):
                card = parse_card_file(p, canonical_root)
                cards.append(card)
                logger.debug("Collected: %s (%s)", p.name, card["artifact_type"])

    return cards


_STYLE_YAML = """\
dimensions:
  width_inches: 13.333
  height_inches: 7.5
  format: "16:9"

metadata:
  title: "Customer Cards"
  subject: "HVE-Core Design Thinking Customer Cards"
  keywords: "HVE, design thinking, customer cards"
  category: "Customer Presentation"

defaults:
  speaker_notes_required: true
  card:
    fill: "#1A1D27"
    corner_radius_inches: 0.12
    border_color: "#2D3142"
    border_width_pt: 1
"""


def write_outputs(cards: list[dict], content_dir: Path) -> None:
    for existing in content_dir.glob("slide-*"):
        shutil.rmtree(existing)

    global_dir = content_dir / "global"
    global_dir.mkdir(parents=True, exist_ok=True)
    (global_dir / "style.yaml").write_text(_STYLE_YAML, encoding="utf-8")
    logger.info("Written: content/global/style.yaml")

    slide_num = 1
    for card in cards:
        if card["artifact_type"] == "Vision Statement":
            yaml_pages = [
                _vision_slide_yaml(
                    slide_num=slide_num,
                    title=card["title"],
                    summary=card["summary"],
                    source_path=card["source_path"],
                    last_updated=card["last_updated"],
                    sub_sections=card.get("sub_sections", {}),
                )
            ]
        elif card["artifact_type"] == "Scenario":
            yaml_pages = _scenario_slide_yamls(
                slide_num=slide_num,
                title=card["title"],
                summary=card["summary"],
                source_path=card["source_path"],
                last_updated=card["last_updated"],
                sub_sections=card.get("sub_sections", {}),
            )
        elif card["artifact_type"] == "Persona":
            yaml_pages = _persona_slide_yamls(
                slide_num=slide_num,
                title=card["title"],
                summary=card["summary"],
                source_path=card["source_path"],
                last_updated=card["last_updated"],
                sub_sections=card.get("sub_sections", {}),
            )
        elif card["artifact_type"] == "Use Case":
            yaml_pages = _use_case_slide_yamls(
                slide_num=slide_num,
                title=card["title"],
                source_path=card["source_path"],
                last_updated=card["last_updated"],
                sub_sections=card.get("sub_sections", {}),
            )
        else:
            yaml_pages = [
                _slide_yaml(
                    slide_num=slide_num,
                    artifact_type=card["artifact_type"],
                    title=card["title"],
                    summary=card["summary"],
                    source_path=card["source_path"],
                    last_updated=card["last_updated"],
                    extra_fields=card["extra_fields"],
                    has_image_slot=card["has_image_slot"],
                )
            ]

        for page in yaml_pages:
            slide_dir = content_dir / f"slide-{slide_num:03d}"
            slide_dir.mkdir(parents=True, exist_ok=True)
            (slide_dir / "content.yaml").write_text(page, encoding="utf-8")
            logger.info(
                "Written: content/slide-%03d/content.yaml  [%s]",
                slide_num,
                card["artifact_type"],
            )
            slide_num += 1


def create_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Generate PowerPoint content YAML from canonical customer card markdown."
    )
    parser.add_argument(
        "--canonical-dir",
        type=Path,
        default=_DEFAULT_CANONICAL,
        metavar="PATH",
        help="Path to the canonical markdown directory (default: %(default)s)",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=_DEFAULT_OUTPUT,
        metavar="PATH",
        help="Path to write content/ YAML files (default: %(default)s)",
    )
    parser.add_argument("-v", "--verbose", action="store_true")
    return parser


def main() -> int:
    args = create_parser().parse_args()
    configure_logging(args.verbose)

    canonical_root: Path = args.canonical_dir.resolve()
    content_dir: Path = args.output_dir.resolve()

    if not canonical_root.is_dir():
        logger.error("Canonical directory not found: %s", canonical_root)
        return EXIT_ERROR

    logger.info("Canonical source : %s", canonical_root)
    logger.info("Output directory : %s", content_dir)

    cards = collect_cards(canonical_root)
    if not cards:
        logger.error("No canonical card files found under %s", canonical_root)
        return EXIT_FAILURE

    write_outputs(cards, content_dir)
    logger.info("Generated %d card(s). Run build-cards.ps1 to build the deck.", len(cards))
    return EXIT_SUCCESS


if __name__ == "__main__":
    sys.exit(main())
