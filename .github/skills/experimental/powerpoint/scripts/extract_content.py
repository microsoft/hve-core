"""Extract content from an existing PPTX into YAML content and style definitions.

Usage:
    python extract_content.py --input existing-deck.pptx --output-dir content/
"""

import argparse
import re
from pathlib import Path

import yaml
from pptx import Presentation
from pptx.util import Emu


def emu_to_inches(emu_val) -> float:
    """Convert EMU to inches, rounded to 3 decimal places."""
    if emu_val is None:
        return 0.0
    return round(emu_val / 914400, 3)


def rgb_to_hex(rgb_color) -> str | None:
    """Convert an RGBColor to a hex string."""
    if rgb_color is None:
        return None
    return f"#{rgb_color}"


def extract_font_info(font) -> dict:
    """Extract font information from a python-pptx font object."""
    info = {}
    if font.name:
        info["font"] = font.name
    if font.size:
        info["size"] = int(font.size.pt)
    try:
        if font.color and font.color.rgb:
            info["color"] = rgb_to_hex(font.color.rgb)
    except (AttributeError, TypeError):
        pass
    if font.bold:
        info["bold"] = True
    if font.italic:
        info["italic"] = True
    return info


def extract_shape(shape) -> dict:
    """Extract a shape element definition."""
    elem = {
        "type": "shape",
        "shape": "rectangle",
        "left": emu_to_inches(shape.left),
        "top": emu_to_inches(shape.top),
        "width": emu_to_inches(shape.width),
        "height": emu_to_inches(shape.height),
        "name": shape.name,
    }

    # Detect shape type from name
    name_lower = shape.name.lower()
    if "rounded" in name_lower:
        elem["shape"] = "rounded_rectangle"
    elif "oval" in name_lower or "circle" in name_lower:
        elem["shape"] = "oval"
    elif "arrow" in name_lower:
        elem["shape"] = "right_arrow"
    elif "chevron" in name_lower:
        elem["shape"] = "chevron"

    # Extract fill color
    try:
        fill = shape.fill
        if fill.type is not None:
            color = rgb_to_hex(fill.fore_color.rgb)
            if color:
                elem["fill"] = color
    except (AttributeError, TypeError):
        pass

    # Extract text if present
    if shape.has_text_frame:
        text = shape.text_frame.text.strip()
        if text:
            elem["text"] = text
            # Extract text styling from first run
            for para in shape.text_frame.paragraphs:
                for run in para.runs:
                    font_info = extract_font_info(run.font)
                    if "font" in font_info:
                        elem["text_font"] = font_info["font"]
                    if "size" in font_info:
                        elem["text_size"] = font_info["size"]
                    if "color" in font_info:
                        elem["text_color"] = font_info["color"]
                    if font_info.get("bold"):
                        elem["text_bold"] = True
                    break
                break

    return elem


def extract_textbox(shape) -> dict:
    """Extract a text box element definition."""
    elem = {
        "type": "textbox",
        "left": emu_to_inches(shape.left),
        "top": emu_to_inches(shape.top),
        "width": emu_to_inches(shape.width),
        "height": emu_to_inches(shape.height),
        "text": shape.text_frame.text.strip() if shape.has_text_frame else "",
        "name": shape.name,
    }

    # Check if this is a rich text element (multiple runs with different formatting)
    if shape.has_text_frame:
        runs = []
        for para in shape.text_frame.paragraphs:
            for run in para.runs:
                font_info = extract_font_info(run.font)
                runs.append({"text": run.text, **font_info})

        # If multiple runs with different formatting, mark as rich_text
        if len(runs) > 1:
            fonts = {r.get("font") for r in runs if "font" in r}
            colors = {r.get("color") for r in runs if "color" in r}
            if len(fonts) > 1 or len(colors) > 1:
                elem["type"] = "rich_text"
                elem["segments"] = runs
                del elem["text"]
                return elem

        # Single-style text box
        if runs:
            first = runs[0]
            if "font" in first:
                elem["font"] = first["font"]
            if "size" in first:
                elem["font_size"] = first["size"]
            if "color" in first:
                elem["font_color"] = first["color"]
            if first.get("bold"):
                elem["bold"] = True
            if first.get("italic"):
                elem["italic"] = True

    return elem


def extract_image(shape, output_dir: Path, slide_num: int, img_count: int) -> dict:
    """Extract an image element and save the image file."""
    img = shape.image
    ext = img.content_type.split("/")[-1]
    if ext == "jpeg":
        ext = "jpg"

    img_name = f"image-{img_count:02d}.{ext}"
    img_path = output_dir / "images" / img_name
    img_path.parent.mkdir(parents=True, exist_ok=True)

    with open(img_path, "wb") as f:
        f.write(img.blob)

    elem = {
        "type": "image",
        "path": f"images/{img_name}",
        "left": emu_to_inches(shape.left),
        "top": emu_to_inches(shape.top),
        "width": emu_to_inches(shape.width),
        "height": emu_to_inches(shape.height),
        "name": shape.name,
    }
    return elem


def detect_global_style(prs) -> dict:
    """Analyze the presentation to detect common styling patterns."""
    colors = {}
    fonts = set()
    font_sizes = set()

    for slide in prs.slides:
        # Detect background colors
        try:
            bg = slide.background
            if bg.fill.type is not None:
                color = rgb_to_hex(bg.fill.fore_color.rgb)
                if color:
                    colors.setdefault("bg_dark", color)
        except (AttributeError, TypeError):
            pass

        for shape in slide.shapes:
            # Collect fill colors
            try:
                if shape.fill.type is not None:
                    color = rgb_to_hex(shape.fill.fore_color.rgb)
                    if color:
                        # Heuristic: small horizontal bars are accent colors
                        h = emu_to_inches(shape.height)
                        if h < 0.1:
                            colors.setdefault("accent_blue", color)
            except (AttributeError, TypeError):
                pass

            # Collect font information
            if shape.has_text_frame:
                for para in shape.text_frame.paragraphs:
                    for run in para.runs:
                        if run.font.name:
                            fonts.add(run.font.name)
                        if run.font.size:
                            font_sizes.add(int(run.font.size.pt))
                        try:
                            if run.font.color and run.font.color.rgb:
                                color = rgb_to_hex(run.font.color.rgb)
                                if color:
                                    colors.setdefault("text_white", color)
                        except (AttributeError, TypeError):
                            pass

    # Determine primary fonts
    body_font = "Segoe UI"
    code_font = "Cascadia Code"
    for f in fonts:
        if "cascadia" in f.lower() or "consolas" in f.lower() or "mono" in f.lower():
            code_font = f
        elif "segoe" in f.lower() or "arial" in f.lower() or "calibri" in f.lower():
            body_font = f

    style = {
        "dimensions": {
            "width_inches": emu_to_inches(prs.slide_width),
            "height_inches": emu_to_inches(prs.slide_height),
            "format": "16:9",
        },
        "colors": colors,
        "typography": {
            "body_font": body_font,
            "code_font": code_font,
            "heading_size": max(font_sizes) if font_sizes else 28,
            "body_size": min(font_sizes) if font_sizes else 16,
        },
        "defaults": {
            "speaker_notes_required": True,
        },
    }
    return style


def extract_slide(slide, slide_num: int, output_dir: Path) -> dict:
    """Extract all elements from a slide into a content.yaml structure."""
    slide_dir = output_dir / f"slide-{slide_num:03d}"
    slide_dir.mkdir(parents=True, exist_ok=True)

    content = {
        "slide": slide_num,
        "title": "",
        "elements": [],
    }

    # Extract speaker notes
    try:
        notes = slide.notes_slide.notes_text_frame.text.strip()
        if notes:
            content["speaker_notes"] = notes
    except (AttributeError, TypeError):
        pass

    img_count = 0
    for shape in slide.shapes:
        shape_type = shape.shape_type

        if shape_type == 13:  # PICTURE
            img_count += 1
            elem = extract_image(shape, slide_dir, slide_num, img_count)
            content["elements"].append(elem)
        elif shape_type == 17:  # TEXT_BOX
            elem = extract_textbox(shape)
            content["elements"].append(elem)
            # Detect title (first large text near top)
            if not content["title"] and emu_to_inches(shape.top) < 1.5:
                text = shape.text_frame.text.strip() if shape.has_text_frame else ""
                if text and len(text) < 100:
                    content["title"] = text
        elif shape_type == 1:  # AUTO_SHAPE
            elem = extract_shape(shape)
            content["elements"].append(elem)

    return content, slide_dir


def main():
    parser = argparse.ArgumentParser(description="Extract content from a PPTX into YAML")
    parser.add_argument("--input", required=True, help="Input PPTX file path")
    parser.add_argument("--output-dir", required=True, help="Output content directory")
    args = parser.parse_args()

    pptx_path = Path(args.input)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    prs = Presentation(str(pptx_path))
    print(f"Extracting from: {pptx_path}")
    print(f"Slides: {len(prs.slides)}")
    print(f"Dimensions: {emu_to_inches(prs.slide_width)}\" x {emu_to_inches(prs.slide_height)}\"")

    # Detect and save global style
    global_style = detect_global_style(prs)
    global_dir = output_dir / "global"
    global_dir.mkdir(parents=True, exist_ok=True)
    style_path = global_dir / "style.yaml"
    with open(style_path, "w", encoding="utf-8") as f:
        yaml.dump(global_style, f, default_flow_style=False, sort_keys=False, allow_unicode=True)
    print(f"Global style saved to {style_path}")

    # Extract each slide
    for i, slide in enumerate(prs.slides):
        slide_num = i + 1
        content, slide_dir = extract_slide(slide, slide_num, output_dir)

        content_path = slide_dir / "content.yaml"
        with open(content_path, "w", encoding="utf-8") as f:
            yaml.dump(content, f, default_flow_style=False, sort_keys=False, allow_unicode=True)
        print(f"Slide {slide_num}: {content.get('title', 'Untitled')} -> {content_path}")

    print(f"\nExtraction complete. {len(prs.slides)} slides extracted to {output_dir}")


if __name__ == "__main__":
    main()
