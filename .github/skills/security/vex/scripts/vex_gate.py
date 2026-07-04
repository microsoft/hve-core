# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Deterministic gate for the VEX drafting workflow.

Parses the vulnerability IDs from a VEX detection issue's findings table and
decides whether the ``vex-draft`` agentic workflow should proceed. The workflow
PROCEEDS when at least one finding is untriaged or carries a non-terminal VEX
status, and SKIPS when every finding already carries a terminal status
(``not_affected`` or ``fixed``). Exit code contract: ``0`` = proceed,
``1`` = skip.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

TERMINAL_STATUSES = frozenset({"not_affected", "fixed"})

# Vulnerability identifier prefixes emitted by OSV-Scanner and public advisories.
# The identifier body allows ':' so distro advisories such as RHSA-2024:1234 parse.
_VULN_ID_RE = re.compile(
    r"^(?:CVE|GHSA|PYSEC|OSV|RUSTSEC|GO|GMS|GLSA|DSA|USN|ALSA|ELSA|RHSA)-"
    r"[0-9A-Za-z._:-]+$"
)


def parse_finding_ids(issue_body: str) -> list[str]:
    """Return the vulnerability IDs from a detection-issue markdown table.

    Only the first cell of each table row is considered, and only tokens that
    match a known vulnerability-ID pattern are kept. The header row and the
    markdown separator row are skipped because their first cells never match the
    pattern. Duplicate IDs are collapsed while preserving first-seen order.
    """
    seen: dict[str, None] = {}
    for line in issue_body.splitlines():
        stripped = line.strip()
        if not stripped.startswith("|"):
            continue
        cells = stripped.split("|")
        if len(cells) < 2:
            continue
        first_cell = cells[1].strip()
        if _VULN_ID_RE.match(first_cell):
            seen.setdefault(first_cell, None)
    return list(seen)


def _iter_statement_ids(document: dict):
    """Yield every vulnerability name/alias paired with its statement status."""
    for statement in document.get("statements", []) or []:
        if not isinstance(statement, dict):
            continue
        status = statement.get("status")
        vuln = statement.get("vulnerability")
        names: list[str] = []
        if isinstance(vuln, str):
            names.append(vuln)
        elif isinstance(vuln, dict):
            name = vuln.get("name") or vuln.get("@id")
            if isinstance(name, str):
                names.append(name)
            for alias in vuln.get("aliases", []) or []:
                if isinstance(alias, str):
                    names.append(alias)
        for name in names:
            yield name, status


def all_terminal(document: dict, finding_ids: list[str]) -> bool:
    """Return True only when every finding has an exact-match terminal statement.

    Matching is exact (no substring containment) so that, for example,
    ``CVE-2024-1`` is not considered covered by a statement for
    ``CVE-2024-100``. An empty finding list is not terminal (nothing is proven
    safe).
    """
    if not finding_ids:
        return False
    terminal_ids = {
        name
        for name, status in _iter_statement_ids(document)
        if isinstance(status, str) and status in TERMINAL_STATUSES
    }
    return all(fid in terminal_ids for fid in finding_ids)


def evaluate(issue_body: str, document: dict | None) -> bool:
    """Return True when the workflow should PROCEED with drafting."""
    finding_ids = parse_finding_ids(issue_body)
    if not finding_ids:
        # No parseable findings: nothing to draft.
        return False
    if document is None:
        # No VEX document yet: everything is untriaged, so proceed.
        return True
    return not all_terminal(document, finding_ids)


def main(argv: list[str] | None = None) -> int:
    """CLI entrypoint. Reads the issue body from stdin.

    Usage: ``vex_gate.py <openvex-path>`` with the detection-issue body piped on
    stdin. Returns ``0`` to proceed and ``1`` to skip. A missing OpenVEX
    document is treated as "everything untriaged" (proceed).
    """
    args = list(sys.argv[1:] if argv is None else argv)
    if not args:
        print(
            "usage: vex_gate.py <openvex-path> (issue body on stdin)",
            file=sys.stderr,
        )
        return 2
    openvex_path = Path(args[0])
    issue_body = sys.stdin.read()
    document: dict | None = None
    if openvex_path.exists():
        try:
            document = json.loads(openvex_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            document = None
    if evaluate(issue_body, document):
        print("VEX gate: proceed (untriaged or non-terminal findings present).")
        return 0
    print("VEX gate: skip (no findings, or all findings already terminal).")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
