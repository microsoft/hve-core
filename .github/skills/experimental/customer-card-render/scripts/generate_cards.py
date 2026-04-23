#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

"""Generate PowerPoint skill content YAML from canonical DT markdown artifacts."""

from __future__ import annotations

import argparse
import logging
import re
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

LOGGER = logging.getLogger(__name__)

_SCRIPT_DIR = Path(__file__).resolve().parent
_SKILL_ROOT = _SCRIPT_DIR.parent
_TEMPLATES_DIR = _SKILL_ROOT / "templates"
_DEFAULT_CANONICAL = _SKILL_ROOT / "canonical"
_DEFAULT_OUTPUT = _SCRIPT_DIR / "content"

STYLE_TEMPLATE = _TEMPLATES_DIR / "global-style.yaml"

TYPE_TO_TEMPLATE = {
    "Vision Statement": "vision.content.yaml",
    "Problem Statement": "problem.content.yaml",
    "Scenario": "scenario.content.yaml",
    "Use Case": "use-case-slide1.content.yaml",
    "Persona": "persona.content.yaml",
}

ORDER = ["Vision Statement", "Problem Statement", "Scenario", "Use Case", "Persona"]


@dataclass(frozen=True)
class Card:
    artifact_type: str
    title: str
    summary: str
    source_path: str
    last_updated: str
    slide_part: int = 0
    sections: dict[str, str] | None = None


def configure_logging(verbose: bool) -> None:
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(level=level, format="%(levelname)s: %(message)s")


def parse_frontmatter(text: str) -> tuple[dict[str, str], str]:
    match = re.match(r"^---\s*\n(.*?)\n---\s*\n", text, re.DOTALL)
    if not match:
        return {}, text

    fields: dict[str, str] = {}
    for line in match.group(1).splitlines():
        key, _, value = line.partition(":")
        if key and _:
            fields[key.strip().lower()] = value.strip().strip('"').strip("'")

    return fields, text[match.end() :]


def extract_section(body: str, heading: str) -> str:
    pattern = (
        rf"(?ims)^\s*#{{2,3}}\s+(?:\d+\.?\s*)?{re.escape(heading)}\s*\r?\n"
        r"(.*?)(?=^\s*#{2,3}\s+|\Z)"
    )
    match = re.search(pattern, body)
    return match.group(1).strip() if match else ""


def extract_first_heading(body: str) -> str:
    match = re.search(r"(?im)^\s*#{1,3}\s+(.+?)\s*$", body)
    return match.group(1).strip() if match else ""


def extract_intro_block(body: str) -> str:
    match = re.search(r"(?ims)^\s*##\s+.+?\s*\r?\n(.*?)(?=^\s*#{2,3}\s+|\Z)", body)
    return match.group(1).strip() if match else ""


def infer_artifact_type(path: Path) -> str:
    filename = path.name.lower()
    parent = path.parent.name.lower()
    if filename == "vision-statement.md":
        return "Vision Statement"
    if filename == "problem-statement.md":
        return "Problem Statement"
    if parent == "scenarios":
        return "Scenario"
    if parent == "use-cases":
        return "Use Case"
    if parent == "personas":
        return "Persona"
    return "Unknown"


def template_for_type(artifact_type: str, slide_part: int = 0) -> Path:
    if artifact_type == "Use Case" and slide_part > 0:
        return _TEMPLATES_DIR / f"use-case-slide{slide_part}.content.yaml"
    try:
        return _TEMPLATES_DIR / TYPE_TO_TEMPLATE[artifact_type]
    except KeyError as exc:
        raise ValueError(f"Unsupported artifact type: {artifact_type}") from exc


def yaml_escape(text: str) -> str:
    # Normalize canonical prose before YAML encoding.
    # Hard-wrapped lines are merged into single-line paragraphs while list
    # item boundaries are preserved.
    text = normalize_text(text)
    # Escape backslashes first to avoid double-escaping, then quotes, then
    # convert logical line breaks to explicit escape sequences.
    text = text.replace("\\", "\\\\").replace('"', '\\"')
    return text.replace("\n", "\\n")


def normalize_text(text: str) -> str:
    """Merge hard-wrapped prose lines while preserving list structure."""
    if not text.strip():
        return ""

    list_pattern = re.compile(r"^\s*(?:[-*+]\s+|\d+[\.)]\s+)")
    normalized_blocks: list[str] = []
    prose_lines: list[str] = []
    list_lines: list[str] = []

    def flush_prose() -> None:
        if prose_lines:
            normalized_blocks.append(
                " ".join(line.strip() for line in prose_lines if line.strip())
            )
            prose_lines.clear()

    def flush_list() -> None:
        if list_lines:
            normalized_blocks.append(
                "\n".join(line.strip() for line in list_lines if line.strip())
            )
            list_lines.clear()

    for raw_line in text.splitlines():
        line = raw_line.rstrip()
        if not line.strip():
            flush_prose()
            flush_list()
            continue

        if list_pattern.match(line):
            flush_prose()
            list_lines.append(line)
            continue

        flush_list()
        prose_lines.append(line)

    flush_prose()
    flush_list()

    return "\n\n".join(block for block in normalized_blocks if block.strip())


def _scenario_summary(body: str) -> str:
    description = extract_section(body, "Description")
    narrative = extract_section(body, "Scenario Narrative")
    hmw = extract_section(body, "How Might We")

    blocks = []
    if description:
        blocks.append(f"Description:\\n{description}")
    if narrative:
        blocks.append(f"Scenario Narrative:\\n{narrative}")
    if hmw:
        blocks.append(f"How Might We:\\n{hmw}")
    return "\\n\\n".join(blocks)


def _vision_sections(body: str) -> dict[str, str]:
    """Extract sections for Vision Statement card."""
    return {
        "V_VISION_STATEMENT": extract_section(body, "Vision Statement"),
        "V_WHY_THIS_MATTERS": extract_section(body, "Why This Matters"),
    }


def _problem_sections(body: str) -> dict[str, str]:
    """Extract sections for Problem Statement card."""
    return {
        "P_PROBLEM_STATEMENT": extract_section(body, "Problem Statement")
        or extract_section(body, "Customer-friendly summary"),
    }


def _scenario_sections(body: str) -> dict[str, str]:
    """Extract sections for Scenario card."""
    return {
        "SC_DESCRIPTION": extract_section(body, "Description"),
        "SC_SCENARIO_NARRATIVE": extract_section(body, "Scenario Narrative"),
        "SC_HOW_MIGHT_WE": extract_section(body, "How Might We"),
    }


def _persona_sections(body: str) -> dict[str, str]:
    """Extract sections for Persona card."""
    return {
        "PE_DESCRIPTION": extract_section(body, "Description"),
        "PE_USER_GOAL": extract_section(body, "User Goal"),
        "PE_USER_NEEDS": extract_section(body, "User Needs"),
        "PE_USER_MINDSET": extract_section(body, "User Mindset"),
    }


def _use_case_slide1(body: str) -> dict[str, str]:
    """Extract sections for Use Case Slide 1."""
    return {
        "UC_DESCRIPTION": extract_section(body, "Use Case Description"),
        "UC_OVERVIEW": extract_section(body, "Use Case Overview"),
        "UC_BUSINESS_VALUE": extract_section(body, "Business Value"),
        "UC_PRIMARY_USER": extract_section(body, "Primary User"),
    }


def _use_case_slide2(body: str) -> dict[str, str]:
    """Extract sections for Use Case Slide 2."""
    return {
        "UC_PRIMARY_USER": extract_section(body, "Primary User"),
        "UC_SECONDARY_USER": extract_section(body, "Secondary User"),
        "UC_STEPS": extract_section(body, "Steps"),
        "UC_PRECONDITIONS": extract_section(body, "Preconditions"),
        "UC_DATA_REQUIREMENTS": extract_section(body, "Data Requirements"),
    }


def _use_case_slide3(body: str) -> dict[str, str]:
    """Extract sections for Use Case Slide 3."""
    return {
        "UC_EQUIPMENT_REQUIREMENTS": extract_section(body, "Equipment Requirements"),
        "UC_SUCCESS_CRITERIA": extract_section(body, "Success Criteria"),
        "UC_OPERATING_ENVIRONMENT": extract_section(body, "Operating Environment"),
        "UC_PAIN_POINTS": extract_section(body, "Pain Points"),
    }


def _use_case_slide4(body: str) -> dict[str, str]:
    """Extract sections for Use Case Slide 4."""
    return {
        "UC_EXTENSIONS": extract_section(body, "Extensions"),
        "UC_EVIDENCE": extract_section(body, "Evidence"),
    }


def parse_card(path: Path, canonical_root: Path) -> Card | None:
    text = path.read_text(encoding="utf-8")
    frontmatter, body = parse_frontmatter(text)

    artifact_type = infer_artifact_type(path)
    if artifact_type == "Unknown":
        LOGGER.debug("Skipping unknown artifact: %s", path)
        return None

    title = (
        frontmatter.get("title")
        or extract_first_heading(body)
        or path.stem.replace("-", " ").title()
    )
    source_path = frontmatter.get("source path") or frontmatter.get("source file path")
    if not source_path:
        source_path = path.relative_to(canonical_root).as_posix()

    metadata_last_updated = frontmatter.get("last updated")
    last_updated = metadata_last_updated or datetime.now(timezone.utc).strftime(
        "%Y-%m-%d"
    )

    # Default summary (used as fallback if sections are empty)
    summary = extract_intro_block(body) or ""

    return Card(
        artifact_type=artifact_type,
        title=title,
        summary=summary,
        source_path=source_path,
        last_updated=last_updated,
    )


def expand_cards(card: Card, body: str) -> list[Card]:
    """Expand a single card into multiple slides if needed.

    Use Case artifacts expand into 4 slides; all others return a single-element list
    with section-specific placeholders.
    """
    sections: dict[str, str] | None = None
    slide_part = 0

    if card.artifact_type == "Use Case":
        # Use Cases expand to 4 slides
        slide1_sections = _use_case_slide1(body)
        slide2_sections = _use_case_slide2(body)
        slide3_sections = _use_case_slide3(body)
        slide4_sections = _use_case_slide4(body)

        return [
            Card(
                artifact_type=card.artifact_type,
                title=card.title,
                summary=card.summary,
                source_path=card.source_path,
                last_updated=card.last_updated,
                slide_part=1,
                sections=slide1_sections,
            ),
            Card(
                artifact_type=card.artifact_type,
                title=card.title,
                summary=card.summary,
                source_path=card.source_path,
                last_updated=card.last_updated,
                slide_part=2,
                sections=slide2_sections,
            ),
            Card(
                artifact_type=card.artifact_type,
                title=card.title,
                summary=card.summary,
                source_path=card.source_path,
                last_updated=card.last_updated,
                slide_part=3,
                sections=slide3_sections,
            ),
            Card(
                artifact_type=card.artifact_type,
                title=card.title,
                summary=card.summary,
                source_path=card.source_path,
                last_updated=card.last_updated,
                slide_part=4,
                sections=slide4_sections,
            ),
        ]
    elif card.artifact_type == "Vision Statement":
        sections = _vision_sections(body)
    elif card.artifact_type == "Problem Statement":
        sections = _problem_sections(body)
    elif card.artifact_type == "Scenario":
        sections = _scenario_sections(body)
    elif card.artifact_type == "Persona":
        sections = _persona_sections(body)

    return [
        Card(
            artifact_type=card.artifact_type,
            title=card.title,
            summary=card.summary,
            source_path=card.source_path,
            last_updated=card.last_updated,
            slide_part=slide_part,
            sections=sections,
        )
    ]


def collect_cards(canonical_root: Path) -> list[Card]:
    files: list[Path] = []
    files.extend(
        path
        for path in [
            canonical_root / "vision-statement.md",
            canonical_root / "problem-statement.md",
        ]
        if path.exists()
    )

    for folder in ["scenarios", "use-cases", "personas"]:
        dir_path = canonical_root / folder
        if dir_path.exists():
            files.extend(sorted(dir_path.glob("*.md"), key=lambda p: p.name.lower()))

    cards: list[Card] = []
    for path in files:
        card = parse_card(path, canonical_root)
        if card is None:
            continue
        _, body = parse_frontmatter(path.read_text(encoding="utf-8"))
        expanded = expand_cards(card, body)
        cards.extend(expanded)

    cards.sort(
        key=lambda card: (
            ORDER.index(card.artifact_type),
            card.title.lower(),
            card.slide_part,
        )
    )
    return cards


def render_slide(card: Card, slide_number: int) -> str:
    template_text = template_for_type(card.artifact_type, card.slide_part).read_text(
        encoding="utf-8"
    )

    # Base replacements for all slides
    replacements = {
        "SLIDE_NUMBER": str(slide_number),
        "TITLE": yaml_escape(card.title),
        "SOURCE_PATH": yaml_escape(card.source_path),
        "LAST_UPDATED": yaml_escape(card.last_updated),
        "TYPE_LABEL": yaml_escape(card.artifact_type.upper()),
    }

    # All artifact types now use section-specific placeholders
    if card.sections:
        for key, value in card.sections.items():
            replacements[key] = yaml_escape(value)

    rendered = template_text
    for key, value in replacements.items():
        rendered = rendered.replace(f"{{{{{key}}}}}", value)
    return rendered


def write_outputs(cards: list[Card], output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "global").mkdir(parents=True, exist_ok=True)

    (output_dir / "global" / "style.yaml").write_text(
        STYLE_TEMPLATE.read_text(encoding="utf-8"),
        encoding="utf-8",
    )

    for index, card in enumerate(cards, start=1):
        slide_dir = output_dir / f"slide-{index:03d}"
        slide_dir.mkdir(parents=True, exist_ok=True)
        (slide_dir / "content.yaml").write_text(
            render_slide(card, index),
            encoding="utf-8",
        )

    LOGGER.info("Generated %d slide content files in %s", len(cards), output_dir)


def create_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=("Generate customer-card content YAML from canonical markdown.")
    )
    parser.add_argument("--canonical-dir", type=Path, default=_DEFAULT_CANONICAL)
    parser.add_argument("--output-dir", type=Path, default=_DEFAULT_OUTPUT)
    parser.add_argument("-v", "--verbose", action="store_true")
    return parser


def main() -> int:
    args = create_parser().parse_args()
    configure_logging(args.verbose)

    canonical_dir = args.canonical_dir.resolve()
    output_dir = args.output_dir.resolve()

    if not canonical_dir.exists() or not any(canonical_dir.glob("**/*.md")):
        LOGGER.error("Canonical directory is missing or empty: %s", canonical_dir)
        return 1

    cards = collect_cards(canonical_dir)
    if not cards:
        LOGGER.error("No canonical artifacts found in: %s", canonical_dir)
        return 1

    write_outputs(cards, output_dir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
