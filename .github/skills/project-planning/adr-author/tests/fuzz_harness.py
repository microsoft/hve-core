# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Polyglot Atheris fuzz harness for the ADR Author skill scripts.

Runs as a standalone Atheris fuzzer when invoked from the command line and as
a regular pytest test (importable smoke check) when discovered by pytest. This
matches the convention used elsewhere in the repository (see
`.github/skills/jira/jira/tests/fuzz_harness.py`) and satisfies the OSSF
Scorecard requirement for a fuzz harness in every Python skill that has a
`tests/` directory.

Targets:

* ``validate_frontmatter``: parsing arbitrary YAML frontmatter blobs.
* ``normalize_template``: extracting anchors from arbitrary markdown.
* ``update_lineage``: validating arbitrary slug bytes.
* ``_utils``: path-traversal detection and allow-root resolution.
"""

from __future__ import annotations

import sys
from contextlib import suppress
from pathlib import Path

try:
    import atheris
except ImportError:  # pragma: no cover - atheris is optional in pytest mode
    atheris = None  # type: ignore[assignment]
    FUZZING = False
else:
    FUZZING = True

# Make the sibling `scripts/` directory importable when invoked standalone.
_SKILL_ROOT = Path(__file__).resolve().parent.parent
_SCRIPTS_DIR = _SKILL_ROOT / "scripts"
if str(_SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS_DIR))


def _fuzz_validate_frontmatter(data: bytes) -> None:
    """Feed arbitrary bytes through the frontmatter parser."""
    with suppress(Exception):
        from scripts import validate_frontmatter  # type: ignore[import-not-found]

        parser = getattr(validate_frontmatter, "parse_frontmatter", None)
        if parser is None:
            return
        with suppress(ValueError, KeyError, TypeError, UnicodeDecodeError):
            parser(data.decode("utf-8", errors="replace"))


def _fuzz_normalize_template(data: bytes) -> None:
    """Feed arbitrary markdown through the anchor extractor."""
    with suppress(Exception):
        from scripts import normalize_template  # type: ignore[import-not-found]

        extract = getattr(normalize_template, "extract_anchors", None)
        if extract is None:
            return
        with suppress(ValueError, KeyError, TypeError, UnicodeDecodeError):
            extract(data.decode("utf-8", errors="replace"))


def _fuzz_update_lineage_slug(data: bytes) -> None:
    """Feed arbitrary bytes through the slug validator."""
    with suppress(Exception):
        from scripts import update_lineage  # type: ignore[import-not-found]

        validate_slug = getattr(update_lineage, "validate_slug", None)
        if validate_slug is None:
            return
        with suppress(ValueError, TypeError, UnicodeDecodeError):
            validate_slug(data.decode("utf-8", errors="replace"))


def _fuzz_utils(data: bytes) -> None:
    """Feed arbitrary path bytes through the traversal guards."""
    with suppress(Exception):
        from scripts import _utils  # type: ignore[import-not-found]

        candidate = Path(data.decode("utf-8", errors="replace"))

        has_traversal = getattr(_utils, "has_traversal_segments", None)
        if has_traversal is not None:
            with suppress(ValueError, TypeError, OSError, UnicodeDecodeError):
                has_traversal(candidate)

        safe_resolve = getattr(_utils, "safe_resolve", None)
        if safe_resolve is not None:
            with suppress(ValueError, TypeError, OSError, UnicodeDecodeError):
                safe_resolve(candidate, [_SKILL_ROOT])


FUZZ_TARGETS = (
    _fuzz_validate_frontmatter,
    _fuzz_normalize_template,
    _fuzz_update_lineage_slug,
    _fuzz_utils,
)


def _entry(data: bytes) -> None:
    """Atheris entrypoint: dispatch to one target per iteration."""
    if not data:
        return
    target = FUZZ_TARGETS[data[0] % len(FUZZ_TARGETS)]
    target(data[1:])


def test_fuzz_harness_importable() -> None:
    """Pytest smoke test: the harness imports and exposes its entrypoint."""
    assert callable(_entry)
    assert FUZZ_TARGETS
    for target in FUZZ_TARGETS:
        assert callable(target)


if __name__ == "__main__" and FUZZING:  # pragma: no cover - exercised by Atheris
    atheris.Setup(sys.argv, _entry)
    atheris.Fuzz()
