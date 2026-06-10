# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Shared fixtures for ADR Author skill tests.

Fixtures avoid loading real template files at import time so the suite remains
runnable before Step 4.2 of the ADR agent improvement plan ships the canonical
MADR v4 and Y-Statement templates.
"""

from __future__ import annotations

from pathlib import Path
from textwrap import dedent

import pytest

# Minimal MADR v4 stand-in used when the real template file is not present.
# Mirrors the upstream structure (https://github.com/adr/madr) closely enough
# for substitution and anchor-extraction tests without bundling the file.
_MADR_V4_FALLBACK = dedent(
    """\
    ---
    # These are optional metadata elements. Feel free to remove any of them.
    status: "{status}"
    date: {date}
    decision-makers: {deciders}
    consulted: {consulted}
    informed: {informed}
    ---

    # {title}

    ## Context and Problem Statement

    {context}

    ## Decision Drivers

    * {driver}

    ## Considered Options

    * {option}

    ## Decision Outcome

    Chosen option: "{chosen_option}", because {justification}.

    ### Consequences

    * Good, because {good_consequence}
    * Bad, because {bad_consequence}

    ## Pros and Cons of the Options

    ### {option}

    * Good, because {pro}
    * Bad, because {con}

    ## More Information

    {more_information}
    """
)

_Y_STATEMENT_FALLBACK = dedent(
    """\
    In the context of {context},
    facing {problem},
    we decided for {chosen_option}
    and against {rejected_option},
    to achieve {benefit},
    accepting {drawback}.
    """
)


@pytest.fixture()
def tmp_skill_root(tmp_path: Path) -> Path:
    """Create a tmp directory mirroring the adr-author skill layout.

    Path-traversal guards anchor against this root, so tests can supply legitimate
    paths inside it and adversarial paths that escape it.
    """
    # Arrange directory structure
    (tmp_path / "templates").mkdir()
    (tmp_path / "scripts").mkdir()
    (tmp_path / "references").mkdir()
    (tmp_path / "schemas").mkdir()
    (tmp_path / "docs" / "planning" / "adrs" / "demo").mkdir(parents=True)
    return tmp_path


@pytest.fixture()
def sample_madr_template() -> str:
    """Return the MADR v4 template body, falling back to a minimal stand-in.

    Loads from `templates/adr-template.md` relative to the skill root when present;
    otherwise returns the embedded fallback so tests work before Step 4.2 lands.
    """
    template_path = Path(__file__).resolve().parent.parent / "templates" / "adr-template.md"
    if template_path.is_file():
        return template_path.read_text(encoding="utf-8")
    return _MADR_V4_FALLBACK


@pytest.fixture()
def sample_y_statement() -> str:
    """Return the Y-Statement template body, falling back to a minimal stand-in."""
    template_path = Path(__file__).resolve().parent.parent / "templates" / "y-statement.md"
    if template_path.is_file():
        return template_path.read_text(encoding="utf-8")
    return _Y_STATEMENT_FALLBACK


@pytest.fixture()
def sample_adr_config(tmp_skill_root: Path) -> Path:
    """Write a minimal `.adr-config.yml` with `last_decision_id: '0000'` and return path."""
    config_path = tmp_skill_root / "docs" / "planning" / "adrs" / "demo" / ".adr-config.yml"
    config_body = dedent(
        """\
        project_slug: demo
        owner: demo-team
        default_status: proposed
        decision_id_format: NNNN
        template_source: madr-v4
        last_decision_id: '0000'
        """
    )
    config_path.write_text(config_body, encoding="utf-8")
    return config_path
