"""Shared Hypothesis strategies for PowerPoint skill property tests."""

from hypothesis import strategies as st
from pptx_colors import THEME_COLOR_MAP

THEME_NAMES = list(THEME_COLOR_MAP.keys())

hex_color = st.text(alphabet="0123456789abcdefABCDEF", min_size=6, max_size=6).map(
    lambda s: f"#{s}"
)

theme_ref = st.sampled_from(THEME_NAMES)

theme_with_brightness = st.fixed_dictionaries(
    {"theme": theme_ref},
    optional={"brightness": st.floats(min_value=-1.0, max_value=1.0)},
)

color_inputs = st.one_of(
    hex_color,
    theme_ref.map(lambda name: f"@{name}"),
    theme_with_brightness,
)


@st.composite
def table_element(draw):
    """Generate a valid table element dictionary matching add_table_element schema."""
    cols = draw(st.integers(min_value=1, max_value=8))
    rows_count = draw(st.integers(min_value=1, max_value=10))
    # Restrict to characters safe for XML serialization in python-pptx
    safe_text = st.text(
        alphabet=st.characters(whitelist_categories=("L", "N", "P", "S", "Zs")),
        max_size=50,
    )
    rows = []
    for _ in range(rows_count):
        cells = [{"text": draw(safe_text)} for _ in range(cols)]
        rows.append({"cells": cells})
    columns = [
        {"width": draw(st.floats(min_value=0.5, max_value=5.0))} for _ in range(cols)
    ]
    return {"type": "table", "columns": columns, "rows": rows}


position = st.fixed_dictionaries(
    {
        "left": st.floats(min_value=0.0, max_value=12.0),
        "top": st.floats(min_value=0.0, max_value=7.0),
        "width": st.floats(min_value=0.5, max_value=12.0),
        "height": st.floats(min_value=0.5, max_value=7.0),
    }
)


issue = st.fixed_dictionaries(
    {
        "check_type": st.text(min_size=1, max_size=20),
        "severity": st.sampled_from(["info", "warning", "error"]),
        "description": st.text(max_size=100),
        "location": st.text(max_size=50),
    }
)

severity_results = st.fixed_dictionaries(
    {
        "slides": st.lists(
            st.fixed_dictionaries(
                {
                    "slide_number": st.integers(min_value=1, max_value=50),
                    "issues": st.lists(issue, max_size=5),
                }
            ),
            max_size=10,
        ),
    },
    optional={
        "deck_issues": st.lists(issue, max_size=5),
    },
)
