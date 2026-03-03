"""Validate a PowerPoint slide deck against content definitions and styling rules.

Usage:
    python validate_deck.py --input slide-deck/presentation.pptx --content-dir content/
"""

import argparse
from pathlib import Path

import yaml
from pptx import Presentation
from pptx.util import Emu


def emu_to_inches(emu_val) -> float:
    """Convert EMU to inches."""
    if emu_val is None:
        return 0.0
    return round(emu_val / 914400, 3)


def load_yaml(path: Path) -> dict:
    """Load a YAML file and return the parsed dictionary."""
    with open(path, encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def check_text_overlay(slide, slide_num: int) -> list[str]:
    """Check for overlapping text elements on a slide."""
    issues = []
    text_elements = []

    for shape in slide.shapes:
        if shape.has_text_frame and shape.text_frame.text.strip():
            top = emu_to_inches(shape.top)
            height = emu_to_inches(shape.height)
            bottom = top + height
            text_elements.append({
                "name": shape.name,
                "top": top,
                "bottom": bottom,
                "text": shape.text_frame.text[:50],
            })

    # Sort by vertical position
    text_elements.sort(key=lambda x: x["top"])

    for i in range(len(text_elements) - 1):
        current = text_elements[i]
        next_elem = text_elements[i + 1]
        gap = next_elem["top"] - current["bottom"]
        if gap < 0:
            issues.append(
                f"Slide {slide_num}: Text overlay between "
                f"'{current['name']}' (bottom={current['bottom']:.2f}) and "
                f"'{next_elem['name']}' (top={next_elem['top']:.2f}), "
                f"gap={gap:.2f}\""
            )

    return issues


def check_width_overflow(slide, slide_num: int, max_width: float = 13.333) -> list[str]:
    """Check for elements extending beyond the slide width."""
    issues = []
    for shape in slide.shapes:
        left = emu_to_inches(shape.left)
        width = emu_to_inches(shape.width)
        right = left + width
        if right > max_width + 0.01:
            issues.append(
                f"Slide {slide_num}: Width overflow on '{shape.name}' "
                f"(left={left:.2f} + width={width:.2f} = {right:.2f} > {max_width})"
            )
    return issues


def check_speaker_notes(slide, slide_num: int) -> list[str]:
    """Check for missing speaker notes."""
    issues = []
    try:
        notes = slide.notes_slide.notes_text_frame.text.strip()
        if not notes:
            issues.append(f"Slide {slide_num}: Empty speaker notes")
    except (AttributeError, TypeError):
        issues.append(f"Slide {slide_num}: Missing speaker notes")
    return issues


def check_font_consistency(slide, slide_num: int, expected_fonts: set[str] | None = None) -> list[str]:
    """Check for unexpected or inconsistent fonts."""
    issues = []
    if not expected_fonts:
        return issues

    for shape in slide.shapes:
        if shape.has_text_frame:
            for para in shape.text_frame.paragraphs:
                for run in para.runs:
                    if run.font.name and run.font.name not in expected_fonts:
                        issues.append(
                            f"Slide {slide_num}: Unexpected font '{run.font.name}' "
                            f"in '{shape.name}' (expected: {expected_fonts})"
                        )
    return issues


def validate_deck(pptx_path: Path, content_dir: Path | None = None) -> list[str]:
    """Run all validation checks on a PPTX file."""
    prs = Presentation(str(pptx_path))
    all_issues = []

    # Load expected fonts from style if available
    expected_fonts = None
    if content_dir:
        style_path = content_dir / "global" / "style.yaml"
        if style_path.exists():
            style = load_yaml(style_path)
            typo = style.get("typography", {})
            expected_fonts = set()
            if "body_font" in typo:
                expected_fonts.add(typo["body_font"])
            if "code_font" in typo:
                expected_fonts.add(typo["code_font"])

    max_width = emu_to_inches(prs.slide_width)

    for i, slide in enumerate(prs.slides):
        slide_num = i + 1
        all_issues.extend(check_text_overlay(slide, slide_num))
        all_issues.extend(check_width_overflow(slide, slide_num, max_width))
        all_issues.extend(check_speaker_notes(slide, slide_num))
        all_issues.extend(check_font_consistency(slide, slide_num, expected_fonts))

    # Check slide count against content
    if content_dir:
        slide_dirs = sorted(
            [d for d in content_dir.iterdir() if d.is_dir() and d.name.startswith("slide-")]
        )
        if len(slide_dirs) != len(prs.slides):
            all_issues.append(
                f"Slide count mismatch: {len(prs.slides)} slides in PPTX, "
                f"{len(slide_dirs)} content directories"
            )

    return all_issues


def main():
    parser = argparse.ArgumentParser(description="Validate a PowerPoint deck")
    parser.add_argument("--input", required=True, help="Input PPTX file path")
    parser.add_argument("--content-dir", help="Content directory for comparison")
    args = parser.parse_args()

    pptx_path = Path(args.input)
    content_dir = Path(args.content_dir) if args.content_dir else None

    print(f"Validating: {pptx_path}")
    issues = validate_deck(pptx_path, content_dir)

    if issues:
        print(f"\n{len(issues)} issue(s) found:\n")
        for issue in issues:
            print(f"  - {issue}")
        return 1
    else:
        print("\nAll validation checks passed.")
        return 0


if __name__ == "__main__":
    exit(main())
