"""Build a PowerPoint slide deck from YAML content and style definitions.

Usage:
    python build_deck.py --content-dir content/ --style content/global/style.yaml --output slide-deck/presentation.pptx
    python build_deck.py --content-dir content/ --style content/global/style.yaml --source existing.pptx --output slide-deck/presentation.pptx --slides 3,7,15
"""

import argparse
import importlib.util
import re
import sys
from pathlib import Path

from lxml import etree
from pptx import Presentation
from pptx.enum.shapes import MSO_CONNECTOR_TYPE, MSO_SHAPE
from pptx.oxml.ns import qn
from pptx.util import Inches, Pt

from pptx_colors import apply_color_to_font, resolve_color
from pptx_fills import apply_fill, apply_line, apply_effect_list
from pptx_fonts import ALIGNMENT_MAP
from pptx_shapes import SHAPE_MAP, apply_rotation
from pptx_text import apply_paragraph_properties, apply_run_properties, apply_text_properties, apply_bullet_properties
from pptx_utils import load_yaml

CONNECTOR_TYPE_MAP = {
    "straight": MSO_CONNECTOR_TYPE.STRAIGHT,
    "elbow": MSO_CONNECTOR_TYPE.ELBOW,
    "curve": MSO_CONNECTOR_TYPE.CURVE,
}


def set_slide_bg(slide, fill_spec, colors: dict):
    """Set a background fill on a slide."""
    apply_fill(slide.background, fill_spec, colors)


def set_slide_bg_image(slide, image_path: str, content_dir: Path):
    """Set a background image on a slide using blipFill in the background element."""
    img_file = content_dir / image_path
    if not img_file.exists():
        return

    from pptx.opc.constants import RELATIONSHIP_TYPE as RT
    from pptx.parts.image import Image, ImagePart

    sld = slide._element
    cSld = sld.find(qn("p:cSld"))
    if cSld is None:
        return

    spTree = cSld.find(qn("p:spTree"))

    # Remove existing p:bg element if present
    existing_bg = cSld.find(qn("p:bg"))
    if existing_bg is not None:
        cSld.remove(existing_bg)

    # Create image part and relate to slide
    image = Image.from_file(str(img_file))
    image_part = ImagePart.new(slide.part.package, image)
    rel = slide.part.relate_to(image_part, RT.IMAGE)

    # Build p:bg > p:bgPr > a:blipFill structure
    bg = etree.SubElement(cSld, qn("p:bg"))
    bgPr = etree.SubElement(bg, qn("p:bgPr"))
    blipFill = etree.SubElement(bgPr, qn("a:blipFill"))
    blipFill.set("dpi", "0")
    blipFill.set("rotWithShape", "1")

    blip = etree.SubElement(blipFill, qn("a:blip"))
    blip.set(qn("r:embed"), rel)

    stretch = etree.SubElement(blipFill, qn("a:stretch"))
    etree.SubElement(stretch, qn("a:fillRect"))

    etree.SubElement(bgPr, qn("a:effectLst"))

    # Ensure p:bg appears before p:spTree (required by schema)
    if spTree is not None:
        cSld.remove(bg)
        cSld.insert(list(cSld).index(spTree), bg)



def add_textbox(slide, left, top, width, height, text, font_name="Segoe UI",
                font_size=16, font_color=None, bold=False, italic=False,
                alignment=None, name=None, rotation=None, elem=None,
                colors=None):
    """Add a text box to a slide. Splits text on newlines into separate paragraphs."""
    txBox = slide.shapes.add_textbox(Inches(left), Inches(top), Inches(width), Inches(height))
    if name:
        txBox.name = name
    apply_rotation(txBox, rotation)
    tf = txBox.text_frame
    tf.word_wrap = True

    # Apply text frame-level properties (margins, auto_size, vertical_anchor)
    if elem:
        apply_text_properties(tf, elem)

    # Split on newlines and vertical tabs (\v / \x0b) which map to <a:br/>
    lines = re.split(r'\n|\v', text) if ('\n' in text or '\v' in text) else [text]

    for i, line in enumerate(lines):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        if alignment:
            p.alignment = ALIGNMENT_MAP.get(alignment, ALIGNMENT_MAP["left"])
        if elem:
            apply_paragraph_properties(p, elem)
            apply_bullet_properties(p, elem)
        run = p.add_run()
        run.text = line
        run.font.name = font_name
        run.font.size = Pt(font_size)
        if font_color:
            apply_color_to_font(run.font.color, font_color)
        run.font.bold = bold
        run.font.italic = italic
        if elem:
            apply_run_properties(run, elem, colors or {})
    return txBox


def add_shape_element(slide, elem, colors, typography):
    """Add a shape element from a content.yaml definition."""
    shape_type = SHAPE_MAP.get(elem.get("shape", "rectangle"), MSO_SHAPE.RECTANGLE)
    left = Inches(elem["left"])
    top = Inches(elem["top"])
    width = Inches(elem["width"])
    height = Inches(elem["height"])

    shape = slide.shapes.add_shape(shape_type, left, top, width, height)

    if "name" in elem:
        shape.name = elem["name"]

    apply_rotation(shape, elem.get("rotation"))

    apply_fill(shape, elem.get("fill"), colors)
    apply_line(shape, elem, colors)

    if "corner_radius" in elem:
        shape.adjustments[0] = elem["corner_radius"]

    if "effect" in elem:
        apply_effect_list(shape, elem["effect"])

    if "text" in elem:
        tf = shape.text_frame
        tf.word_wrap = True
        apply_text_properties(tf, elem)
        text = elem["text"]
        lines = re.split(r'\n|\v', text) if ('\n' in text or '\v' in text) else [text]
        for i, line in enumerate(lines):
            p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
            apply_paragraph_properties(p, elem)
            apply_bullet_properties(p, elem)
            run = p.add_run()
            run.text = line
            run.font.name = elem.get("text_font", "Segoe UI")
            run.font.size = Pt(elem.get("text_size", 16))
            if "text_color" in elem:
                color_spec = resolve_color(elem["text_color"])
                apply_color_to_font(run.font.color, color_spec)
            run.font.bold = elem.get("text_bold", False)
            apply_run_properties(run, elem, colors)

    return shape


def add_image_element(slide, elem, content_dir: Path):
    """Add an image element from a content.yaml definition."""
    img_path = content_dir / elem["path"]
    if not img_path.exists():
        # Fallback: add a text box with the path as placeholder
        add_textbox(slide, elem["left"], elem["top"], elem["width"], elem["height"],
                    f"[Image: {elem['path']}]", font_size=12)
        return None

    left = Inches(elem["left"])
    top = Inches(elem["top"])
    width = Inches(elem["width"])
    height = Inches(elem["height"])
    pic = slide.shapes.add_picture(str(img_path), left, top, width, height)
    if "name" in elem:
        pic.name = elem["name"]
    apply_rotation(pic, elem.get("rotation"))

    # Apply image opacity via alphaModFix on the blip element
    if "opacity" in elem:
        blip = pic._element.find('.//' + qn('a:blip'))
        if blip is not None:
            amt = str(int(elem["opacity"] * 1000))
            amf = blip.find(qn('a:alphaModFix'))
            if amf is None:
                amf = etree.SubElement(blip, qn('a:alphaModFix'))
            amf.set('amt', amt)

    return pic


def add_rich_text_element(slide, elem, colors, typography):
    """Add a rich text element with mixed font/color segments."""
    txBox = slide.shapes.add_textbox(
        Inches(elem["left"]), Inches(elem["top"]),
        Inches(elem["width"]), Inches(elem["height"])
    )
    if "name" in elem:
        txBox.name = elem["name"]
    tf = txBox.text_frame
    tf.word_wrap = True
    p = tf.paragraphs[0]

    # Apply text frame-level properties
    apply_text_properties(tf, elem)

    for i, seg in enumerate(elem.get("segments", [])):
        run = p.add_run() if i > 0 else (p.runs[0] if p.runs else p.add_run())
        run.text = seg["text"]
        run.font.name = seg.get("font", "Segoe UI")
        run.font.size = Pt(seg.get("size", 16))
        if "color" in seg:
            color_spec = resolve_color(seg["color"])
            apply_color_to_font(run.font.color, color_spec)
        run.font.bold = seg.get("bold", False)
        run.font.italic = seg.get("italic", False)
        apply_run_properties(run, seg, colors)

    return txBox


def add_card_element(slide, elem, colors, typography):
    """Add a card panel with optional title bar and bullet content."""
    left = Inches(elem["left"])
    top = Inches(elem["top"])
    width = Inches(elem["width"])
    height = Inches(elem["height"])

    # Card background
    shape = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, left, top, width, height)
    apply_fill(shape, elem.get("fill", "#2D2D35"), colors)
    if "border_color" in elem:
        apply_line(shape, {"line_color": elem["border_color"], "line_width": elem.get("border_width", 1)}, colors)
    else:
        shape.line.fill.background()

    # Accent bar
    if elem.get("accent_bar"):
        bar = slide.shapes.add_shape(
            MSO_SHAPE.RECTANGLE,
            Inches(elem["left"] + 0.15), Inches(elem["top"] + 0.1),
            Inches(elem["width"] - 0.3), Inches(0.04)
        )
        apply_fill(bar, elem.get("accent_color", "#0078D4"), colors)
        bar.line.fill.background()

    # Title
    y_offset = 0.2
    if "title" in elem:
        add_textbox(
            slide, elem["left"] + 0.2, elem["top"] + y_offset,
            elem["width"] - 0.4, 0.4,
            elem["title"],
            font_name="Segoe UI",
            font_size=elem.get("title_size", 16),
            font_color=resolve_color(elem.get("title_color", "#F8F8FC")),
            bold=elem.get("title_bold", True)
        )
        y_offset += 0.5

    # Content bullets
    for item in elem.get("content", []):
        bullet_text = f"\u2022 {item['bullet']}" if "bullet" in item else item.get("text", "")
        color = resolve_color(item.get("color", "#F8F8FC"))
        add_textbox(
            slide, elem["left"] + 0.2, elem["top"] + y_offset,
            elem["width"] - 0.4, 0.35,
            bullet_text,
            font_name="Segoe UI",
            font_size=item.get("size", 14),
            font_color=color
        )
        y_offset += 0.35

    return shape


def add_arrow_flow_element(slide, elem, colors, typography):
    """Add a horizontal arrow flow diagram."""
    items = elem.get("items", [])
    if not items:
        return

    total_width = elem["width"]
    item_width = total_width / len(items) - 0.3
    x = elem["left"]

    for item in items:
        shape = slide.shapes.add_shape(
            MSO_SHAPE.CHEVRON,
            Inches(x), Inches(elem["top"]),
            Inches(item_width), Inches(elem["height"])
        )
        apply_fill(shape, item.get("color", "#0078D4"), colors)
        shape.line.fill.background()

        tf = shape.text_frame
        tf.word_wrap = True
        p = tf.paragraphs[0]
        p.text = item["label"]
        p.alignment = ALIGNMENT_MAP["center"]
        run = p.runs[0]
        run.font.name = "Segoe UI"
        run.font.size = Pt(14)
        apply_color_to_font(run.font.color, resolve_color("#F8F8FC"))
        run.font.bold = True

        x += item_width + 0.3


def add_numbered_step_element(slide, elem, colors, typography):
    """Add a numbered step with circle, label, and description."""
    number = elem.get("number", 1)

    # Number circle
    circle = slide.shapes.add_shape(
        MSO_SHAPE.OVAL,
        Inches(elem["left"]), Inches(elem["top"]),
        Inches(0.5), Inches(0.5)
    )
    apply_fill(circle, elem.get("accent_color", "#0078D4"), colors)
    circle.line.fill.background()
    tf = circle.text_frame
    p = tf.paragraphs[0]
    p.text = str(number)
    p.alignment = ALIGNMENT_MAP["center"]
    run = p.runs[0]
    run.font.name = "Segoe UI"
    run.font.size = Pt(16)
    apply_color_to_font(run.font.color, resolve_color("#F8F8FC"))
    run.font.bold = True

    # Label
    add_textbox(
        slide, elem["left"] + 0.6, elem["top"],
        elem["width"] - 0.6, 0.35,
        elem["label"],
        font_name="Segoe UI",
        font_size=16,
        font_color=resolve_color("#F8F8FC"),
        bold=True
    )

    # Description
    if "description" in elem:
        add_textbox(
            slide, elem["left"] + 0.6, elem["top"] + 0.35,
            elem["width"] - 0.6, 0.4,
            elem["description"],
            font_name="Segoe UI",
            font_size=14,
            font_color=resolve_color("#9CA3AF")
        )


def add_connector_element(slide, elem: dict, colors: dict):
    """Add a connector element from a content.yaml definition.

    YAML schema:
    - type: connector
      connector_type: straight
      begin_x: 3.0
      begin_y: 2.0
      end_x: 7.0
      end_y: 4.0
      line_color: "#0078D4"
      line_width: 2
      dash_style: solid
      head_end: none
      tail_end: arrow
    """
    conn_type = CONNECTOR_TYPE_MAP.get(
        elem.get("connector_type", "straight"), MSO_CONNECTOR_TYPE.STRAIGHT
    )

    connector = slide.shapes.add_connector(
        conn_type,
        Inches(elem["begin_x"]), Inches(elem["begin_y"]),
        Inches(elem["end_x"]), Inches(elem["end_y"]),
    )

    apply_line(connector, elem, colors)

    # Arrow heads via lxml XML manipulation
    sp_pr = connector._element.find(qn("a:ln"))
    if sp_pr is None:
        ln_parent = connector._element.spPr
        sp_pr = ln_parent.find(qn("a:ln"))
    if sp_pr is None:
        sp_pr = etree.SubElement(connector._element.spPr, qn("a:ln"))

    if "head_end" in elem and elem["head_end"] != "none":
        head = etree.SubElement(sp_pr, qn("a:headEnd"))
        head.set("type", elem["head_end"])
    if "tail_end" in elem and elem["tail_end"] != "none":
        tail = etree.SubElement(sp_pr, qn("a:tailEnd"))
        tail.set("type", elem["tail_end"])

    if "name" in elem:
        connector.name = elem["name"]

    return connector


def add_group_element(slide, elem: dict, colors: dict, typography: dict,
                      content_dir: Path):
    """Add a group element containing nested child elements.

    YAML schema:
    - type: group
      left: 1.0
      top: 2.0
      width: 5.0
      height: 3.0
      elements:
        - type: shape
          shape: rectangle
          left: 0
          top: 0
          width: 5.0
          height: 3.0
          fill: "#2D2D35"
        - type: textbox
          left: 0.2
          top: 0.2
          width: 4.6
          height: 0.5
          text: "Group Title"
    """
    group = slide.shapes.add_group_shape()

    group.left = Inches(elem["left"])
    group.top = Inches(elem["top"])
    group.width = Inches(elem["width"])
    group.height = Inches(elem["height"])

    for child_elem in elem.get("elements", []):
        build_element_in_group(group, child_elem, colors, typography, content_dir)

    if "name" in elem:
        group.name = elem["name"]

    return group


def build_element_in_group(group, elem: dict, colors: dict, typography: dict,
                           content_dir: Path):
    """Dispatch a child element build within a group shape.

    Uses group.shapes as the target shapes collection so children are added
    inside the group rather than on the slide.
    """
    elem_type = elem.get("type", "textbox")
    shapes = group.shapes

    if elem_type == "shape":
        shape_type = SHAPE_MAP.get(elem.get("shape", "rectangle"), MSO_SHAPE.RECTANGLE)
        shape = shapes.add_shape(
            shape_type,
            Inches(elem["left"]), Inches(elem["top"]),
            Inches(elem["width"]), Inches(elem["height"]),
        )
        if "name" in elem:
            shape.name = elem["name"]
        apply_rotation(shape, elem.get("rotation"))
        apply_fill(shape, elem.get("fill"), colors)
        apply_line(shape, elem, colors)
        if "text" in elem:
            tf = shape.text_frame
            tf.word_wrap = True
            apply_text_properties(tf, elem)
            text = elem["text"]
            lines = re.split(r'\n|\v', text) if ('\n' in text or '\v' in text) else [text]
            for i, line in enumerate(lines):
                p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
                apply_bullet_properties(p, elem)
                run = p.add_run()
                run.text = line
                run.font.name = elem.get("text_font", "Segoe UI")
                run.font.size = Pt(elem.get("text_size", 16))
                if "text_color" in elem:
                    apply_color_to_font(run.font.color, resolve_color(elem["text_color"], colors))
                run.font.bold = elem.get("text_bold", False)
                apply_run_properties(run, elem, colors)
    elif elem_type == "textbox":
        txBox = shapes.add_textbox(
            Inches(elem["left"]), Inches(elem["top"]),
            Inches(elem["width"]), Inches(elem["height"]),
        )
        if "name" in elem:
            txBox.name = elem["name"]
        tf = txBox.text_frame
        tf.word_wrap = True
        apply_text_properties(tf, elem)
        text = elem.get("text", "")
        lines = re.split(r'\n|\v', text) if ('\n' in text or '\v' in text) else [text]
        for i, line in enumerate(lines):
            p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
            if "alignment" in elem:
                p.alignment = ALIGNMENT_MAP.get(elem["alignment"], ALIGNMENT_MAP["left"])
            apply_paragraph_properties(p, elem)
            apply_bullet_properties(p, elem)
            run = p.add_run()
            run.text = line
            run.font.name = elem.get("font", "Segoe UI")
            run.font.size = Pt(elem.get("font_size", 16))
            if "font_color" in elem:
                apply_color_to_font(run.font.color, resolve_color(elem["font_color"], colors))
            run.font.bold = elem.get("font_bold", False)
            run.font.italic = elem.get("italic", False)
            apply_run_properties(run, elem, colors)
    elif elem_type == "connector":
        add_connector_element(group, elem, colors)
    elif elem_type == "image":
        add_image_element(group, elem, content_dir)


def clear_slide_shapes(slide):
    """Remove all shapes from a slide, preserving the slide itself."""
    sp_tree = slide.shapes._spTree
    shapes_to_remove = [sp for sp in sp_tree.iterchildren() if sp.tag.endswith('}sp')
                        or sp.tag.endswith('}pic') or sp.tag.endswith('}grpSp')
                        or sp.tag.endswith('}cxnSp')]
    for sp in shapes_to_remove:
        sp_tree.remove(sp)


def _all_layouts(prs):
    """Iterate layouts across all slide masters."""
    for master in prs.slide_masters:
        yield from master.slide_layouts


def _find_blank_layout(prs):
    """Find the best blank layout in the presentation, with fallbacks."""
    # Try index 6 first (default blank in standard templates)
    try:
        return prs.slide_layouts[6]
    except IndexError:
        pass
    # Search by name across all masters
    for layout in _all_layouts(prs):
        if layout.name.lower() in ("blank", "blank slide"):
            return layout
    # Fall back to last layout of first master
    return prs.slide_layouts[len(prs.slide_layouts) - 1]


def get_slide_layout(prs, slide_content: dict, style: dict):
    """Select slide layout based on content.yaml or style.yaml configuration."""
    layout_spec = slide_content.get("layout")
    layouts_map = style.get("layouts", {})

    if layout_spec is None or layout_spec == "blank":
        return _find_blank_layout(prs)

    # Resolve through style.yaml layouts map
    if layout_spec in layouts_map:
        layout_ref = layouts_map[layout_spec]
        if isinstance(layout_ref, int):
            try:
                return prs.slide_layouts[layout_ref]
            except IndexError:
                return _find_blank_layout(prs)
        elif isinstance(layout_ref, str):
            for layout in _all_layouts(prs):
                if layout.name == layout_ref:
                    return layout

    # Direct name lookup across all slide masters
    if isinstance(layout_spec, str):
        for layout in _all_layouts(prs):
            if layout.name == layout_spec:
                return layout

    # Direct index lookup
    if isinstance(layout_spec, int):
        try:
            return prs.slide_layouts[layout_spec]
        except IndexError:
            return _find_blank_layout(prs)

    # Fallback to blank
    return _find_blank_layout(prs)


def build_slide(prs, slide_content: dict, style: dict, content_dir: Path, existing_slide=None):
    """Build a single slide from content.yaml data and style context.

    When existing_slide is provided, clears its shapes and rebuilds in place
    instead of appending a new slide.
    """
    colors = {}
    typography = {}

    if existing_slide is not None:
        slide = existing_slide
        clear_slide_shapes(slide)
    else:
        layout = get_slide_layout(prs, slide_content, style)
        slide = prs.slides.add_slide(layout)

    # Populate themed layout placeholders
    placeholders = slide_content.get("placeholders", {})
    for idx_str, value in placeholders.items():
        idx = int(idx_str)
        if idx in slide.placeholders:
            ph = slide.placeholders[idx]
            if isinstance(value, str):
                ph.text = value
            elif isinstance(value, list):
                tf = ph.text_frame
                tf.text = value[0]
                for line in value[1:]:
                    tf.add_paragraph().text = line

    # Set background from per-slide definition only
    bg_block = slide_content.get("background")
    if bg_block and "image" in bg_block:
        set_slide_bg_image(slide, bg_block["image"], content_dir)
    elif bg_block and "fill" in bg_block:
        set_slide_bg(slide, bg_block["fill"], colors)

    # Sort elements by z_order to preserve stacking order
    elements = slide_content.get("elements", [])
    elements = sorted(elements, key=lambda e: e.get("z_order", 0))

    # Filter out empty placeholder elements
    elements = [e for e in elements if not (e.get("_placeholder") and not e.get("text", "").strip())]

    turbo_enabled = len(elements) > 20
    if turbo_enabled:
        slide.shapes.turbo_add_enabled = True

    # Process elements in order
    for elem in elements:
        elem_type = elem.get("type", "textbox")

        if elem_type == "shape":
            add_shape_element(slide, elem, colors, typography)
        elif elem_type == "textbox":
            font_name = elem.get("font", "Segoe UI")
            font_color = resolve_color(elem["font_color"]) if "font_color" in elem else None
            is_bold = elem.get("font_bold", elem.get("bold", False))
            add_textbox(
                slide, elem["left"], elem["top"], elem["width"], elem["height"],
                elem.get("text", ""),
                font_name=font_name,
                font_size=elem.get("font_size", 16),
                font_color=font_color,
                bold=is_bold,
                italic=elem.get("italic", False),
                alignment=elem.get("alignment"),
                name=elem.get("name"),
                rotation=elem.get("rotation"),
                elem=elem,
                colors=colors
            )
        elif elem_type == "image":
            add_image_element(slide, elem, content_dir)
        elif elem_type == "rich_text":
            add_rich_text_element(slide, elem, colors, typography)
        elif elem_type == "card":
            add_card_element(slide, elem, colors, typography)
        elif elem_type == "arrow_flow":
            add_arrow_flow_element(slide, elem, colors, typography)
        elif elem_type == "numbered_step":
            add_numbered_step_element(slide, elem, colors, typography)
        elif elem_type == "table":
            from pptx_tables import add_table_element
            add_table_element(slide, elem, colors, typography)
        elif elem_type == "chart":
            from pptx_charts import add_chart_element
            add_chart_element(slide, elem, colors)
        elif elem_type == "connector":
            add_connector_element(slide, elem, colors)
        elif elem_type == "group":
            add_group_element(slide, elem, colors, typography, content_dir)

    # Execute content-extra.py if present
    extra_script = content_dir / "content-extra.py"
    if extra_script.exists():
        spec = importlib.util.spec_from_file_location("content_extra", str(extra_script))
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        if hasattr(mod, "render"):
            mod.render(slide, style, content_dir)

    if turbo_enabled:
        slide.shapes.turbo_add_enabled = False

    # Add speaker notes (preserve empty strings when notes slide exists)
    notes = slide_content.get("speaker_notes")
    if notes is not None:
        notes_slide = slide.notes_slide
        notes_text = re.sub(r'\v', '\n', notes) if notes else ""
        notes_slide.notes_text_frame.text = notes_text

    return slide


def discover_slides(content_dir: Path) -> list[tuple[int, Path]]:
    """Discover slide content directories and return sorted (number, path) pairs."""
    slides = []
    for child in content_dir.iterdir():
        if child.is_dir() and child.name.startswith("slide-"):
            match = re.match(r"slide-(\d+)", child.name)
            if match:
                num = int(match.group(1))
                content_yaml = child / "content.yaml"
                if content_yaml.exists():
                    slides.append((num, child))
    return sorted(slides, key=lambda x: x[0])


def main():
    parser = argparse.ArgumentParser(description="Build a PowerPoint deck from YAML content")
    parser.add_argument("--content-dir", required=True, help="Path to the content/ directory")
    parser.add_argument("--style", required=True, help="Path to the global style.yaml")
    parser.add_argument("--output", required=True, help="Output PPTX file path")
    parser.add_argument("--template", help="Template PPTX file path for themed builds")
    parser.add_argument("--source", help="Source PPTX to update (for partial rebuilds)")
    parser.add_argument("--slides", help="Comma-separated slide numbers to rebuild (requires --source)")
    args = parser.parse_args()

    content_dir = Path(args.content_dir)
    style = load_yaml(Path(args.style))
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    dims = style.get("dimensions", {})
    width = dims.get("width_inches", 13.333)
    height = dims.get("height_inches", 7.5)

    if args.template:
        # Template build: open template and preserve its theme/layouts
        prs = Presentation(args.template)
        # Only override dimensions when explicitly set in style.yaml
        if "dimensions" in style:
            prs.slide_width = Inches(width)
            prs.slide_height = Inches(height)

        # Remove existing slides from the template — keep only theme/layouts
        while len(prs.slides) > 0:
            rId = prs.slides._sldIdLst[0].rId
            prs.part.drop_rel(rId)
            prs.slides._sldIdLst.remove(prs.slides._sldIdLst[0])

        # Apply presentation metadata from style.yaml
        metadata = style.get("metadata", {})
        if metadata:
            props = prs.core_properties
            for key, value in metadata.items():
                if hasattr(props, key):
                    setattr(props, key, value)

        slides_data = discover_slides(content_dir)
        if not slides_data:
            print("No slide content found in", content_dir)
            sys.exit(1)

        for num, slide_dir in slides_data:
            slide_content = load_yaml(slide_dir / "content.yaml")
            build_slide(prs, slide_content, style, slide_dir)
            print(f"Built slide {num}: {slide_content.get('title', 'Untitled')}")
    elif args.source and args.slides:
        # Partial rebuild: open existing deck and replace specific slides
        prs = Presentation(args.source)
        slide_nums = [int(s.strip()) for s in args.slides.split(",")]
        slides_data = discover_slides(content_dir)
        slides_to_rebuild = {num: path for num, path in slides_data if num in slide_nums}

        for num in slide_nums:
            if num not in slides_to_rebuild:
                print(f"Warning: No content found for slide {num}, skipping")
                continue
            slide_dir = slides_to_rebuild[num]
            slide_content = load_yaml(slide_dir / "content.yaml")
            # Rebuild in-place: clear shapes on the existing slide and repopulate
            idx = num - 1
            if idx < len(prs.slides):
                existing_slide = prs.slides[idx]
                build_slide(prs, slide_content, style, slide_dir, existing_slide=existing_slide)
                print(f"Rebuilt slide {num} in-place")
            else:
                print(f"Warning: Slide {num} does not exist in deck (has {len(prs.slides)} slides), skipping")
    else:
        # Full build
        prs = Presentation()
        prs.slide_width = Inches(width)
        prs.slide_height = Inches(height)

        # Apply presentation metadata from style.yaml
        metadata = style.get("metadata", {})
        if metadata:
            props = prs.core_properties
            for key, value in metadata.items():
                if hasattr(props, key):
                    setattr(props, key, value)

        slides_data = discover_slides(content_dir)
        if not slides_data:
            print("No slide content found in", content_dir)
            sys.exit(1)

        for num, slide_dir in slides_data:
            slide_content = load_yaml(slide_dir / "content.yaml")
            build_slide(prs, slide_content, style, slide_dir)
            print(f"Built slide {num}: {slide_content.get('title', 'Untitled')}")

    prs.save(str(output_path))
    print(f"\nDeck saved to {output_path}")
    print(f"Total slides: {len(prs.slides)}")


if __name__ == "__main__":
    main()
