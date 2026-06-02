# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Scan ADR and handoff content for high-confidence sensitive data.

Deterministic, regex-based scanner that flags high-confidence secrets
(API keys, tokens, private keys) and internal-only URLs/hostnames before
durable ADR writes or external handoff emission. Detection is intentionally
conservative to minimize false positives: it favors well-known, high-entropy
token shapes and explicit internal-network markers over broad PII heuristics.

Findings carry a ``confidence`` label:

* ``high`` -- a token, key, or internal URL that must block durable/external
  writes until redacted. Any high-confidence finding sets a non-zero exit.
* ``warn`` -- advisory matches (such as email addresses) that surface for
  review but do not block on their own.

Input may be one or more file paths or, when no paths are given, stdin. Output
is a JSON object on stdout with ``findings`` (a list) and summary counts.

Usage::

    python -m scripts.scan_sensitive_content <path> [<path> ...]
    cat adr.md | python -m scripts.scan_sensitive_content
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any, NamedTuple

try:
    from ._utils import safe_resolve
except ImportError:  # executed directly as ``python scan_sensitive_content.py``
    from _utils import safe_resolve

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_ERROR = 2

SKILL_ROOT = Path(__file__).resolve().parent.parent
REPO_ROOT = SKILL_ROOT.parents[3] if len(SKILL_ROOT.parents) >= 4 else SKILL_ROOT

STDIN_SOURCE = "<stdin>"


class Rule(NamedTuple):
    """A named detection rule with a compiled pattern and confidence label."""

    category: str
    confidence: str
    pattern: re.Pattern[str]


# High-confidence secret patterns. Each shape is well-known and high-entropy
# enough that a match is very unlikely to be benign ADR prose.
RULES: tuple[Rule, ...] = (
    Rule(
        "github_token",
        "high",
        re.compile(r"\bghp_[A-Za-z0-9]{36}\b"),
    ),
    Rule(
        "github_token",
        "high",
        re.compile(r"\bgithub_pat_[A-Za-z0-9_]{22,}\b"),
    ),
    Rule(
        "aws_access_key",
        "high",
        re.compile(r"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b"),
    ),
    Rule(
        "google_api_key",
        "high",
        re.compile(r"\bAIza[0-9A-Za-z_\-]{35}\b"),
    ),
    Rule(
        "slack_token",
        "high",
        re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{10,}\b"),
    ),
    Rule(
        "openai_api_key",
        "high",
        re.compile(r"\bsk-[A-Za-z0-9]{32,}\b"),
    ),
    Rule(
        "private_key",
        "high",
        re.compile(
            r"-----BEGIN (?:RSA |EC |DSA |OPENSSH |PGP )?PRIVATE KEY-----"
        ),
    ),
    Rule(
        "email_address",
        "warn",
        re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b"),
    ),
)


# Rules applied only when the target repository is public (``--public``).
# Internal-only URLs and hostnames are a leak concern only when the ADR or
# handoff content lands in a publicly visible repository; in a private repo
# they are expected operational references and flagging them is noise.
PUBLIC_ONLY_RULES: tuple[Rule, ...] = (
    Rule(
        "internal_url",
        "high",
        re.compile(
            r"https?://"
            r"(?:localhost|127\.0\.0\.1"
            r"|10\.\d{1,3}\.\d{1,3}\.\d{1,3}"
            r"|192\.168\.\d{1,3}\.\d{1,3}"
            r"|172\.(?:1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3}"
            r"|[A-Za-z0-9.-]+\.(?:corp|internal|local))"
            r"(?:[:/][^\s)\"']*)?",
            re.IGNORECASE,
        ),
    ),
)


def _redact(match: str) -> str:
    """Return a masked preview of a matched secret for safe reporting."""
    stripped = match.strip()
    if len(stripped) <= 8:
        return stripped[0] + "***" if stripped else "***"
    return f"{stripped[:4]}***{stripped[-2:]}"


def scan_text(
    text: str, source: str, *, public: bool = False
) -> list[dict[str, Any]]:
    """Return a list of finding dicts for ``text`` attributed to ``source``.

    When ``public`` is true, internal-URL rules are included; in a private
    repository those references are expected and are not flagged.
    """
    active_rules = (*RULES, *PUBLIC_ONLY_RULES) if public else RULES
    findings: list[dict[str, Any]] = []
    for line_number, line in enumerate(text.splitlines(), start=1):
        for rule in active_rules:
            for match in rule.pattern.finditer(line):
                findings.append(
                    {
                        "source": source,
                        "line": line_number,
                        "column": match.start() + 1,
                        "category": rule.category,
                        "confidence": rule.confidence,
                        "match": _redact(match.group(0)),
                    }
                )
    return findings


def create_parser() -> argparse.ArgumentParser:
    """Create the argument parser."""
    parser = argparse.ArgumentParser(
        prog="scan_sensitive_content",
        description=(
            "Scan ADR/handoff content for high-confidence secrets and "
            "internal URLs before durable or external writes."
        ),
    )
    parser.add_argument(
        "paths",
        nargs="*",
        type=Path,
        help="File paths to scan; reads stdin when no paths are given.",
    )
    parser.add_argument(
        "--allow-root",
        type=Path,
        action="append",
        default=[],
        help="Additional directory under which scanned paths may live.",
    )
    parser.add_argument(
        "--public",
        action="store_true",
        help=(
            "Treat the target repository as public; enables internal-URL "
            "detection, which is suppressed for private repositories."
        ),
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    """Main entry point."""
    args = create_parser().parse_args(argv)

    findings: list[dict[str, Any]] = []

    if args.paths:
        auto_allow: list[Path] = [SKILL_ROOT, REPO_ROOT]
        for raw in args.paths:
            try:
                auto_allow.append(raw.expanduser().resolve().parent)
            except OSError:
                # Unresolvable path (e.g. broken symlink); skip adding its
                # parent to the allowlist and rely on safe_resolve below to
                # reject it explicitly.
                continue
        allow_roots = [
            *auto_allow,
            *(p.expanduser().resolve() for p in args.allow_root),
        ]
        for raw in args.paths:
            try:
                resolved = safe_resolve(raw, allow_roots)
            except ValueError as exc:
                print(
                    f"scan_sensitive_content: path error: {exc}",
                    file=sys.stderr,
                )
                return EXIT_ERROR
            try:
                text = resolved.read_text(encoding="utf-8")
            except OSError as exc:
                print(
                    f"scan_sensitive_content: failed to read '{raw}': {exc}",
                    file=sys.stderr,
                )
                return EXIT_FAILURE
            findings.extend(scan_text(text, str(raw), public=args.public))
    else:
        text = sys.stdin.read()
        findings.extend(scan_text(text, STDIN_SOURCE, public=args.public))

    high_count = sum(1 for f in findings if f["confidence"] == "high")
    warn_count = sum(1 for f in findings if f["confidence"] == "warn")
    report = {
        "findings": findings,
        "summary": {
            "high": high_count,
            "warn": warn_count,
            "total": len(findings),
        },
    }
    print(json.dumps(report, indent=2))

    return EXIT_FAILURE if high_count else EXIT_SUCCESS


if __name__ == "__main__":
    sys.exit(main())
