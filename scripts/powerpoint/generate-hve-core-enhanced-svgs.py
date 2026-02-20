#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Generate enhanced standalone SVG diagrams for HVE-Core documentation and web use.

Produces SVGs covering:
  - RPI Pipeline: Type Transformation System (with 88% stat callout)
  - D-RPI Pipeline: Discovery + RPI extended workflow
  - Quality Comparison: Traditional vs RPI
  - Who Uses HVE-Core? Role → Collection → Workflow
"""

import os
import sys
import textwrap

EXIT_SUCCESS = 0
EXIT_FAILURE = 1

OUTPUT_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..",
    "docs",
)

COLORS = {
    "dark_bg": "#1B1B1B",
    "blue": "#0078D4",
    "green": "#107C10",
    "orange": "#FF8C00",
    "red": "#D13438",
    "purple": "#8864D8",
    "teal": "#038E8E",
    "white": "#FFFFFF",
    "light_gray": "#E0E0E0",
    "med_gray": "#909090",
    "dark_gray": "#404040",
    "card_bg": "#2D2D2D",
}


# ─────────────────────────────────────────────────
# SVG Helper Functions
# ─────────────────────────────────────────────────


def save(filename: str, content: str) -> str:
    """Write SVG content to OUTPUT_DIR/filename."""
    path = os.path.join(OUTPUT_DIR, filename)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"  ✅ {filename}")
    return path


def svg_header(width: int, height: int, title: str = "") -> str:
    """Return SVG opening tag with viewBox, dark background rect, and title."""
    return textwrap.dedent(f"""\
    <?xml version="1.0" encoding="UTF-8"?>
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" width="{width}" height="{height}">
    <title>{title}</title>
    <defs>
      <marker id="ah-blue" markerWidth="10" markerHeight="7" refX="9" refY="3.5" orient="auto"><polygon points="0 0,10 3.5,0 7" fill="{COLORS['blue']}"/></marker>
      <marker id="ah-green" markerWidth="10" markerHeight="7" refX="9" refY="3.5" orient="auto"><polygon points="0 0,10 3.5,0 7" fill="{COLORS['green']}"/></marker>
      <marker id="ah-orange" markerWidth="10" markerHeight="7" refX="9" refY="3.5" orient="auto"><polygon points="0 0,10 3.5,0 7" fill="{COLORS['orange']}"/></marker>
      <marker id="ah-red" markerWidth="10" markerHeight="7" refX="9" refY="3.5" orient="auto"><polygon points="0 0,10 3.5,0 7" fill="{COLORS['red']}"/></marker>
      <marker id="ah-purple" markerWidth="10" markerHeight="7" refX="9" refY="3.5" orient="auto"><polygon points="0 0,10 3.5,0 7" fill="{COLORS['purple']}"/></marker>
      <marker id="ah-teal" markerWidth="10" markerHeight="7" refX="9" refY="3.5" orient="auto"><polygon points="0 0,10 3.5,0 7" fill="{COLORS['teal']}"/></marker>
      <marker id="ah-white" markerWidth="10" markerHeight="7" refX="9" refY="3.5" orient="auto"><polygon points="0 0,10 3.5,0 7" fill="{COLORS['light_gray']}"/></marker>
      <marker id="ah-med-gray" markerWidth="10" markerHeight="7" refX="9" refY="3.5" orient="auto"><polygon points="0 0,10 3.5,0 7" fill="{COLORS['med_gray']}"/></marker>
      <style>
        text {{ font-family: 'Segoe UI', Arial, sans-serif; }}
        .title {{ font-size: 22px; font-weight: bold; fill: {COLORS['white']}; }}
        .subtitle {{ font-size: 14px; fill: {COLORS['light_gray']}; }}
        .zone-label {{ font-size: 15px; font-weight: bold; }}
        .node-title {{ font-size: 12px; font-weight: bold; fill: {COLORS['white']}; }}
        .node-detail {{ font-size: 11px; fill: {COLORS['light_gray']}; }}
        .node-small {{ font-size: 10px; fill: {COLORS['med_gray']}; }}
        .badge-text {{ font-size: 10px; font-weight: bold; fill: {COLORS['white']}; }}
        .type-label {{ font-size: 11px; font-style: italic; fill: {COLORS['light_gray']}; }}
      </style>
    </defs>
    <rect width="{width}" height="{height}" fill="{COLORS['dark_bg']}" rx="8"/>
    """)


def svg_footer() -> str:
    """Return SVG closing tag."""
    return "</svg>\n"


def zone_rect(
    x: int,
    y: int,
    w: int,
    h: int,
    fill: str,
    label: str,
    label_color: str,
    sublabel: str = "",
) -> str:
    """Return a rounded-rect zone with label text."""
    svg = textwrap.dedent(f"""\
    <rect x="{x}" y="{y}" width="{w}" height="{h}" rx="12" fill="{fill}" stroke="{label_color}" stroke-width="2"/>
    <text x="{x + 12}" y="{y + 22}" class="zone-label" fill="{label_color}">{label}</text>
    """)
    if sublabel:
        svg += f'<text x="{x + 12}" y="{y + 38}" class="node-small" fill="{COLORS["med_gray"]}">{sublabel}</text>\n'
    return svg


def node_box(
    x: int,
    y: int,
    w: int,
    h: int,
    fill: str,
    label: str,
    font_size: int = 12,
    stroke: str = "",
) -> str:
    """Return a rounded-rect node with centered text label."""
    stroke_attr = f' stroke="{stroke}" stroke-width="1.5"' if stroke else ""
    return textwrap.dedent(f"""\
    <rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8" fill="{fill}"{stroke_attr}/>
    <text x="{x + w // 2}" y="{y + h // 2 + font_size // 3}" text-anchor="middle" \
font-size="{font_size}" font-weight="bold" fill="{COLORS['white']}" \
font-family="'Segoe UI', sans-serif">{label}</text>
    """)


def dashed_rect(
    x: int,
    y: int,
    w: int,
    h: int,
    stroke_color: str,
    fill: str = "none",
) -> str:
    """Return a rounded-rect with dashed border."""
    fill_attr = f' fill="{fill}"' if fill != "none" else ' fill="none"'
    return (
        f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="12"{fill_attr} '
        f'stroke="{stroke_color}" stroke-width="2" stroke-dasharray="10 6"/>\n'
    )


def arrow(
    x1: int,
    y1: int,
    x2: int,
    y2: int,
    color: str = "blue",
    label: str = "",
) -> str:
    """Return a line with arrowhead marker, optionally with a midpoint label."""
    marker = f"ah-{color}"
    c = COLORS.get(color, color)
    s = (
        f'<path d="M {x1} {y1} L {x2} {y2}" stroke="{c}" '
        f'stroke-width="2" fill="none" marker-end="url(#{marker})"/>\n'
    )
    if label:
        mx, my = (x1 + x2) // 2, (y1 + y2) // 2
        s += (
            f'<text x="{mx}" y="{my - 6}" text-anchor="middle" '
            f'class="node-small" fill="{c}">{label}</text>\n'
        )
    return s


def dashed_arrow(
    x1: int,
    y1: int,
    x2: int,
    y2: int,
    color: str = "med_gray",
    label: str = "",
) -> str:
    """Return a dashed line with arrowhead marker."""
    marker = f"ah-{color}"
    c = COLORS.get(color, color)
    s = (
        f'<path d="M {x1} {y1} L {x2} {y2}" stroke="{c}" '
        f'stroke-width="2" fill="none" stroke-dasharray="8 6" marker-end="url(#{marker})"/>\n'
    )
    if label:
        mx, my = (x1 + x2) // 2, (y1 + y2) // 2
        s += (
            f'<text x="{mx}" y="{my - 6}" text-anchor="middle" '
            f'class="node-small" fill="{c}">{label}</text>\n'
        )
    return s


def arrow_path(
    d: str,
    color: str = "blue",
    label: str = "",
    lx: int = 0,
    ly: int = 0,
    dashed: bool = False,
) -> str:
    """Return an SVG path with arrowhead marker, optionally with a label."""
    marker = f"ah-{color}"
    c = COLORS.get(color, color)
    dash_attr = ' stroke-dasharray="8 6"' if dashed else ""
    s = (
        f'<path d="{d}" stroke="{c}" stroke-width="2" '
        f'fill="none"{dash_attr} marker-end="url(#{marker})"/>\n'
    )
    if label and lx and ly:
        s += (
            f'<text x="{lx}" y="{ly}" text-anchor="middle" '
            f'class="node-small" fill="{c}">{label}</text>\n'
        )
    return s


def text_label(
    x: int,
    y: int,
    text: str,
    color: str = "#FFFFFF",
    font_size: int = 12,
    anchor: str = "middle",
) -> str:
    """Return an SVG text element."""
    return (
        f'<text x="{x}" y="{y}" text-anchor="{anchor}" '
        f'font-size="{font_size}" fill="{color}" '
        f"font-family=\"'Segoe UI', sans-serif\">{text}</text>\n"
    )


# ─────────────────────────────────────────────────
# 1. Enhanced RPI Pipeline
# ─────────────────────────────────────────────────


def generate_rpi_pipeline_svg() -> str:
    """Generate the enhanced RPI pipeline with 88% stat callout (1920x650)."""
    w, h = 1920, 650
    svg = svg_header(w, h, "RPI Pipeline: Type Transformation System")

    svg += text_label(w // 2, 40,
                      "RPI Pipeline: Type Transformation System", COLORS["white"], 24)
    svg += text_label(
        w // 2, 65,
        "Research  →  Plan  →  Implement  →  Review   ·   Each phase transforms typed artifacts",
        COLORS["light_gray"], 14,
    )

    phases = [
        ("Research", COLORS["blue"], "blue"),
        ("Plan", COLORS["green"], "green"),
        ("Implement", COLORS["orange"], "orange"),
        ("Review", COLORS["purple"], "purple"),
    ]

    box_w, box_h = 300, 160
    gap = 100
    total = len(phases) * box_w + (len(phases) - 1) * gap
    start_x = (w - total) // 2
    box_y = 200

    type_labels = [
        "Uncertainty → Knowledge",
        "Knowledge → Strategy",
        "Strategy → Working Code",
        "Working Code → Validated Code",
    ]

    artifacts = [
        "Research findings",
        "Implementation plan",
        "Code + tests",
        "Validated output",
    ]

    for i, (name, color, color_key) in enumerate(phases):
        bx = start_x + i * (box_w + gap)

        svg += f'<rect x="{bx}" y="{box_y}" width="{box_w}" height="{box_h}" rx="12" fill="{COLORS["card_bg"]}" stroke="{color}" stroke-width="3"/>\n'
        svg += text_label(bx + box_w // 2, box_y + 50, name, color, 26)
        svg += text_label(bx + box_w // 2, box_y + 80,
                          f"Phase {i + 1}", COLORS["med_gray"], 13)
        svg += text_label(bx + box_w // 2, box_y + 110,
                          artifacts[i], COLORS["light_gray"], 11)

        if i < len(phases) - 1:
            label_x = bx + box_w + gap // 2
            svg += text_label(label_x, box_y - 30,
                              type_labels[i], COLORS["light_gray"], 11)

        if i == 0:
            svg += text_label(bx + box_w // 2, box_y - 30,
                              "Uncertainty", COLORS["blue"], 12)
        if i == len(phases) - 1:
            svg += text_label(bx + box_w // 2, box_y - 30,
                              "Validated Code", COLORS["purple"], 12)

        if i < len(phases) - 1:
            ax1 = bx + box_w
            ax2 = bx + box_w + gap
            ay = box_y + box_h // 2
            svg += arrow(ax1 + 18, ay, ax2 - 18, ay, color_key)
            cx = ax1 + gap // 2
            svg += f'<circle cx="{cx}" cy="{ay}" r="14" fill="{COLORS["red"]}" opacity="0.9"/>\n'
            svg += text_label(cx, ay + 4, "/clear", COLORS["white"], 8)

    # 88% stat callout
    stat_y = box_y + box_h + 40
    stat_w, stat_h = 420, 40
    stat_x = (w - stat_w) // 2
    svg += f'<rect x="{stat_x}" y="{stat_y}" width="{stat_w}" height="{stat_h}" rx="8" fill="{COLORS["green"]}"/>\n'
    svg += text_label(stat_x + stat_w // 2, stat_y + 26,
                      "Up to 88% faster task completion", COLORS["white"], 15)

    legend_y = stat_y + 60
    svg += text_label(w // 2, legend_y,
                      "/clear — Context reset between phases prevents knowledge leakage",
                      COLORS["med_gray"], 13)

    summary_y = legend_y + 30
    for i, tl in enumerate(type_labels):
        x_pos = start_x + i * (box_w + gap) + box_w // 2
        svg += text_label(x_pos, summary_y, tl, COLORS["light_gray"], 10)

    svg += svg_footer()
    return save("hve-core-rpi-pipeline-enhanced.svg", svg)


# ─────────────────────────────────────────────────
# 2. D-RPI Pipeline: Discovery + RPI
# ─────────────────────────────────────────────────


def generate_drpi_pipeline_svg() -> str:
    """Generate the D-RPI extended pipeline diagram (1920x700)."""
    w, h = 1920, 700
    svg = svg_header(w, h, "D-RPI Pipeline: Discovery + Research → Plan → Implement → Review")

    svg += text_label(w // 2, 40,
                      "D-RPI Pipeline: Discovery + RPI", COLORS["white"], 24)
    svg += text_label(
        w // 2, 65,
        "Optional Discovery phase extends the core RPI pipeline for ambiguous or complex projects",
        COLORS["light_gray"], 14,
    )

    # Discovery box — dashed outline
    disc_x, disc_y = 80, 260
    disc_w, disc_h = 240, 140
    svg += dashed_rect(disc_x, disc_y, disc_w, disc_h,
                       COLORS["med_gray"], COLORS["card_bg"])
    svg += text_label(disc_x + disc_w // 2, disc_y + 60,
                      "Discovery", COLORS["med_gray"], 22)
    svg += text_label(disc_x + disc_w // 2, disc_y + 85,
                      "(optional)", COLORS["dark_gray"], 12)
    svg += text_label(disc_x + disc_w // 2, disc_y - 25,
                      "Empathize / Define", COLORS["med_gray"], 11)

    # 4 RPI phases
    phases = [
        ("Research", COLORS["blue"], "blue"),
        ("Plan", COLORS["green"], "green"),
        ("Implement", COLORS["orange"], "orange"),
        ("Review", COLORS["purple"], "purple"),
    ]

    type_labels = ["Uncertainty", "Knowledge", "Strategy",
                   "Working Code", "Validated Code"]

    box_w, box_h = 260, 140
    gap = 70
    rpi_start_x = 400
    box_y = 260

    for i, (name, color, color_key) in enumerate(phases):
        bx = rpi_start_x + i * (box_w + gap)

        svg += f'<rect x="{bx}" y="{box_y}" width="{box_w}" height="{box_h}" rx="12" fill="{COLORS["card_bg"]}" stroke="{color}" stroke-width="3"/>\n'
        svg += text_label(bx + box_w // 2, box_y + 55, name, color, 22)
        svg += text_label(bx + box_w // 2, box_y + 80,
                          f"Phase {i + 1}", COLORS["med_gray"], 12)

        svg += text_label(bx + box_w // 2, box_y - 25,
                          type_labels[i], COLORS["light_gray"], 11)

        if i < len(phases) - 1:
            ax1 = bx + box_w
            ax2 = bx + box_w + gap
            ay = box_y + box_h // 2
            svg += arrow(ax1 + 18, ay, ax2 - 18, ay, color_key)
            cx = ax1 + gap // 2
            svg += f'<circle cx="{cx}" cy="{ay}" r="14" fill="{COLORS["red"]}" opacity="0.9"/>\n'
            svg += text_label(cx, ay + 4, "/clear", COLORS["white"], 8)

    # Output label after last box
    last_bx = rpi_start_x + 3 * (box_w + gap)
    svg += text_label(last_bx + box_w // 2, box_y - 25,
                      type_labels[4], COLORS["purple"], 11)

    # Dashed arrow: Discovery → Research
    svg += dashed_arrow(
        disc_x + disc_w + 10, disc_y + disc_h // 2,
        rpi_start_x - 10, box_y + box_h // 2,
        "med-gray",
    )

    # Iteration loop: Review bottom → Research bottom
    loop_y = box_y + box_h + 50
    review_cx = last_bx + box_w // 2
    research_cx = rpi_start_x + box_w // 2

    svg += arrow_path(
        f"M {review_cx} {box_y + box_h} L {review_cx} {loop_y} "
        f"L {research_cx} {loop_y} L {research_cx} {box_y + box_h}",
        "purple",
        label="iteration loops",
        lx=(review_cx + research_cx) // 2,
        ly=loop_y - 8,
    )

    # Legend
    legend_y = loop_y + 50
    svg += text_label(w // 2 - 300, legend_y,
                      "Dashed border = optional Discovery phase",
                      COLORS["med_gray"], 13)
    svg += text_label(w // 2 + 300, legend_y,
                      "Red circles = /clear (context reset)  |  Purple loop = iteration",
                      COLORS["med_gray"], 13)

    svg += svg_footer()
    return save("hve-core-drpi-pipeline.svg", svg)


# ─────────────────────────────────────────────────
# 3. Quality Comparison: Traditional vs RPI
# ─────────────────────────────────────────────────


def generate_quality_comparison_svg() -> str:
    """Generate the enhanced quality comparison diagram (1920x800)."""
    w, h = 1920, 800
    svg = svg_header(w, h, "Quality Comparison: Traditional vs RPI")

    svg += text_label(w // 2, 40,
                      "Quality Comparison: Traditional vs RPI", COLORS["white"], 24)
    svg += text_label(
        w // 2, 65,
        "Side-by-side evaluation across five quality dimensions",
        COLORS["light_gray"], 14,
    )

    zone_w = 820
    zone_gap = 60
    zone_x_left = (w - 2 * zone_w - zone_gap) // 2
    zone_x_right = zone_x_left + zone_w + zone_gap
    zone_y = 100
    zone_h = 650

    svg += zone_rect(zone_x_left, zone_y, zone_w, zone_h,
                     "#2D1A1A", "Traditional AI Coding", COLORS["red"])
    svg += zone_rect(zone_x_right, zone_y, zone_w, zone_h,
                     "#1A2D1A", "RPI Framework", COLORS["green"])

    comparisons = [
        {
            "dimension": "Knowledge Acquisition",
            "traditional": "Pattern Matching",
            "traditional_desc": "Relies on pre-trained patterns; no active research",
            "rpi": "Research-Grounded",
            "rpi_desc": "Dedicated research phase gathers domain context",
        },
        {
            "dimension": "Traceability",
            "traditional": "None / Lost",
            "traditional_desc": "No artifact chain; decisions untraceable",
            "rpi": "Full Traceability",
            "rpi_desc": "Research → Plan → Code → Review artifact chain",
        },
        {
            "dimension": "Knowledge Transfer",
            "traditional": "Prompt-Dependent",
            "traditional_desc": "Knowledge lives in prompts; lost on context change",
            "rpi": "Artifact-Based Knowledge",
            "rpi_desc": "Durable markdown artifacts persist across sessions",
        },
        {
            "dimension": "Rework Rate",
            "traditional": "Common",
            "traditional_desc": "Frequent rework from misunderstood requirements",
            "rpi": "Rare",
            "rpi_desc": "Research and planning prevent downstream rework",
        },
        {
            "dimension": "Validation",
            "traditional": "Ad Hoc",
            "traditional_desc": "No systematic review; quality varies by prompt",
            "rpi": "Systematic Validation",
            "rpi_desc": "Dedicated review phase with structured criteria",
        },
    ]

    row_h = 105
    row_start_y = zone_y + 55
    padding = 20

    for i, comp in enumerate(comparisons):
        ry = row_start_y + i * (row_h + 15)

        svg += text_label(w // 2, ry + 15,
                          comp["dimension"], COLORS["white"], 14)

        card_x = zone_x_left + padding
        card_w = zone_w - 2 * padding
        svg += f'<rect x="{card_x}" y="{ry + 25}" width="{card_w}" height="{row_h - 30}" rx="8" fill="{COLORS["dark_bg"]}" stroke="{COLORS["red"]}" stroke-width="1.5"/>\n'
        svg += text_label(card_x + card_w // 2, ry + 55,
                          comp["traditional"], COLORS["red"], 16)
        svg += text_label(card_x + card_w // 2, ry + 78,
                          comp["traditional_desc"], COLORS["med_gray"], 11)

        badge_w = 50
        svg += f'<rect x="{card_x + card_w - badge_w - 10}" y="{ry + 35}" width="{badge_w}" height="20" rx="4" fill="{COLORS["red"]}"/>\n'
        svg += text_label(card_x + card_w - badge_w // 2 - 10,
                          ry + 49, "✗", COLORS["white"], 11)

        card_x_r = zone_x_right + padding
        svg += f'<rect x="{card_x_r}" y="{ry + 25}" width="{card_w}" height="{row_h - 30}" rx="8" fill="{COLORS["dark_bg"]}" stroke="{COLORS["green"]}" stroke-width="1.5"/>\n'
        svg += text_label(card_x_r + card_w // 2, ry + 55,
                          comp["rpi"], COLORS["green"], 16)
        svg += text_label(card_x_r + card_w // 2, ry + 78,
                          comp["rpi_desc"], COLORS["med_gray"], 11)

        svg += f'<rect x="{card_x_r + card_w - badge_w - 10}" y="{ry + 35}" width="{badge_w}" height="20" rx="4" fill="{COLORS["green"]}"/>\n'
        svg += text_label(card_x_r + card_w - badge_w // 2 - 10,
                          ry + 49, "✓", COLORS["white"], 11)

    svg += svg_footer()
    return save("hve-core-quality-comparison-enhanced.svg", svg)


# ─────────────────────────────────────────────────
# 4. Who Uses HVE-Core? Role → Collection → Workflow
# ─────────────────────────────────────────────────


def generate_role_mapping_svg() -> str:
    """Generate the enhanced role-to-collection mapping diagram (1920x1000)."""
    w, h = 1920, 1000
    svg = svg_header(w, h, "Eight Roles, One Framework")

    svg += text_label(w // 2, 40,
                      "Eight Roles, One Framework", COLORS["white"], 24)
    svg += text_label(
        w // 2, 65,
        "Each role maps to a collection with tailored agents, prompts, and workflows",
        COLORS["light_gray"], 14,
    )

    roles = [
        {"name": "Developer", "color": COLORS["blue"],
         "collection": "hve-core", "workflow": "RPI Pipeline"},
        {"name": "TPM / Lead", "color": COLORS["green"],
         "collection": "project-planning", "workflow": "Reqs → PRD → WIT"},
        {"name": "Platform Engineer", "color": COLORS["orange"],
         "collection": "coding-standards", "workflow": "Artifact Authoring"},
        {"name": "OSS Contributor", "color": COLORS["teal"],
         "collection": "github", "workflow": "Backlog Management"},
        {"name": "Security Engineer", "color": COLORS["red"],
         "collection": "security-planning", "workflow": "Threat Modeling"},
        {"name": "Data Scientist", "color": COLORS["purple"],
         "collection": "data-science", "workflow": "Spec → Notebook → Dashboard"},
        {"name": "Project Planner", "color": COLORS["green"],
         "collection": "project-planning", "workflow": "PRD / BRD / ADR"},
        {"name": "UX / DT Practitioner", "color": COLORS["teal"],
         "collection": "design-thinking", "workflow": "9-Method Coaching"},
    ]

    cols = 4
    rows = 2
    card_w = 380
    card_h = 320
    gap_x = 40
    gap_y = 50
    total_w = cols * card_w + (cols - 1) * gap_x
    total_h = rows * card_h + (rows - 1) * gap_y
    start_x = (w - total_w) // 2
    start_y = (h - total_h) // 2 + 30

    for idx, role in enumerate(roles):
        col = idx % cols
        row = idx // cols
        cx = start_x + col * (card_w + gap_x)
        cy = start_y + row * (card_h + gap_y)
        color = role["color"]

        svg += f'<rect x="{cx}" y="{cy}" width="{card_w}" height="{card_h}" rx="12" fill="{COLORS["card_bg"]}" stroke="{color}" stroke-width="2"/>\n'

        header_h = 60
        svg += f'<rect x="{cx}" y="{cy}" width="{card_w}" height="{header_h}" rx="12" fill="{color}"/>\n'
        svg += f'<rect x="{cx}" y="{cy + header_h - 12}" width="{card_w}" height="12" fill="{color}"/>\n'

        svg += text_label(cx + card_w // 2, cy + 38,
                          role["name"], COLORS["white"], 20)

        badge_y = cy + header_h + 30
        collection_text = role["collection"]
        badge_text_w = len(collection_text) * 9 + 24
        badge_x = cx + (card_w - badge_text_w) // 2
        svg += f'<rect x="{badge_x}" y="{badge_y}" width="{badge_text_w}" height="28" rx="6" fill="{COLORS["dark_bg"]}" stroke="{color}" stroke-width="1.5"/>\n'
        svg += text_label(badge_x + badge_text_w // 2,
                          badge_y + 19, collection_text, color, 13)

        svg += text_label(cx + card_w // 2, badge_y + 50,
                          "Collection", COLORS["med_gray"], 10)

        workflow_y = badge_y + 75
        svg += text_label(cx + card_w // 2, workflow_y,
                          role["workflow"], COLORS["light_gray"], 15)

        svg += text_label(cx + card_w // 2, workflow_y + 22,
                          "Workflow Pattern", COLORS["med_gray"], 10)

        line_y = cy + card_h - 15
        svg += f'<line x1="{cx + 20}" y1="{line_y}" x2="{cx + card_w - 20}" y2="{line_y}" stroke="{color}" stroke-width="1" opacity="0.3"/>\n'

    svg += svg_footer()
    return save("hve-core-role-mapping-enhanced.svg", svg)


# ─────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────


def main() -> int:
    """Generate enhanced standalone SVG diagrams for HVE-Core documentation."""
    print("Generating enhanced HVE-Core SVG diagrams...")
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    generate_rpi_pipeline_svg()
    generate_drpi_pipeline_svg()
    generate_quality_comparison_svg()
    generate_role_mapping_svg()

    print(f"\n✅ Enhanced SVG diagrams saved to: {OUTPUT_DIR}")
    return EXIT_SUCCESS


if __name__ == "__main__":
    sys.exit(main())
