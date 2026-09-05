# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Scan authored content for guarded disclosure risks.

Deterministic, regex-based scanner that flags high-confidence PII and, for
public repositories, internal-only URLs/hostnames before durable writes or
external handoff emission. Optional data mode adds structured column,
connection, credential, sample-row, and international identifier detection.

Findings carry a ``confidence`` label:

* ``high`` -- PII or a public-repository internal URL that must block
    durable/external writes until redacted. Any high-confidence finding sets a
    non-zero exit.
* ``warn`` -- advisory matches that surface for review but do not block on
    their own.

Input may be one or more file paths or, when no paths are given, stdin. Every
terminal path prints one JSON report on stdout. Exit 0 means the scan completed
with no high-confidence finding, exit 1 means it completed with at least one,
and exit 2 means the scan did not complete and ``status`` is ``error``. Callers
accept a durable write only on exit 0 with ``status`` of ``completed`` and the
expected ``modes`` attestation.

Usage::

    python -m scripts.scan_sensitive_content <path> [<path> ...]
    python -m scripts.scan_sensitive_content --data --denylist terms.txt <path>
    cat adr.md | python -m scripts.scan_sensitive_content
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections.abc import Iterator
from pathlib import Path
from typing import Any, NamedTuple

try:
    from ._utils import safe_resolve
except ImportError:  # executed directly as ``python scan_sensitive_content.py``
    from _utils import safe_resolve

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_ERROR = 2

SCHEMA_VERSION = "scan-sensitive-content-v1"
STATUS_COMPLETED = "completed"
STATUS_ERROR = "error"

# Input bounds. Over-limit input fails closed before any rule executes.
MAX_INPUT_BYTES = 5 * 1024 * 1024
MAX_LINE_LENGTH = 10000
MAX_DENYLIST_BYTES = 64 * 1024
MAX_DENYLIST_TERMS = 1000
MIN_DENYLIST_TERM_LENGTH = 3

SKILL_ROOT = Path(__file__).resolve().parent.parent
REPO_ROOT = SKILL_ROOT.parents[3] if len(SKILL_ROOT.parents) >= 4 else SKILL_ROOT

STDIN_SOURCE = "<stdin>"


class ScanError(Exception):
    """A scan that could not complete, carrying a stable non-secret error code."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code
        self.message = message


class Rule(NamedTuple):
    """A named detection rule with a compiled pattern and confidence label."""

    category: str
    confidence: str
    pattern: re.Pattern[str]


# High-confidence PII blocks durable/external writes. Names and roles are not
# scanned because deterministic regexes produce too many false positives there.
RULES: tuple[Rule, ...] = (
    Rule(
        "email_address",
        "high",
        re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b"),
    ),
    Rule(
        "phone_number",
        "high",
        re.compile(r"\b(?:\+?1[\s.-]?)?(?:\(?\d{3}\)?[\s.-]?)\d{3}[\s.-]?\d{4}\b"),
    ),
    Rule(
        "national_identifier",
        "high",
        re.compile(r"\b\d{3}-\d{2}-\d{4}\b"),
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


# Rules applied only in data mode. Column-name and sample-row detection use
# dedicated structural scanners below so ordinary prose does not activate
# those heuristics.
DATA_ONLY_RULES: tuple[Rule, ...] = (
    Rule(
        "connection_string",
        "high",
        re.compile(
            r"\b(?:Server|Data\s+Source|Initial\s+Catalog|User\s+Id|Password)\s*="
            r"[^\r\n;]*(?:;[^\r\n;=]+=[^\r\n;]*)+",
            re.IGNORECASE,
        ),
    ),
    Rule(
        "jdbc_odbc_uri",
        "high",
        re.compile(r"\b(?:jdbc|odbc):[^\s\"']+", re.IGNORECASE),
    ),
    Rule(
        "db_uri_with_credentials",
        "high",
        re.compile(
            r"\b(?:postgres(?:ql)?|mysql|mongodb(?:\+srv)?|redis)://" r"[^\s/@:]+:[^\s/@]+@[^\s\"']+",
            re.IGNORECASE,
        ),
    ),
    Rule(
        "storage_key",
        "high",
        re.compile(r"\bAccountKey\s*=\s*[A-Za-z0-9+/]{20,}={0,2}", re.IGNORECASE),
    ),
    Rule(
        "bearer_token",
        "high",
        re.compile(r"\bAuthorization\s*:\s*Bearer\s+[A-Za-z0-9._~+/-]{12,}", re.IGNORECASE),
    ),
    Rule(
        "private_key_block",
        "high",
        re.compile(r"-----BEGIN (?:RSA |EC |DSA |OPENSSH |PGP )?PRIVATE KEY-----"),
    ),
    Rule(
        "cloud_access_key_id",
        "high",
        re.compile(r"\b(?:AKIA|ASIA|AGPA|AIDA|AROA|ANPA|ANVA)[A-Z0-9]{16}\b"),
    ),
    Rule(
        "source_control_token",
        "high",
        re.compile(r"\bgh[pousr]_[A-Za-z0-9]{36,}\b"),
    ),
    Rule(
        "chat_webhook_token",
        "high",
        re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{10,}\b"),
    ),
    Rule(
        "web_token",
        "high",
        re.compile(r"\beyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b"),
    ),
    Rule(
        "generic_secret_assignment",
        "high",
        re.compile(
            r"\b(?:api[_-]?key|secret|password|passwd|token|client[_-]?secret)"
            r"\s*[:=]\s*[\"']?[A-Za-z0-9/+_=-]{16,}[\"']?",
            re.IGNORECASE,
        ),
    ),
    Rule(
        "uk_national_insurance",
        "warn",
        re.compile(r"\b[A-CEGHJ-PR-TW-Z]{2}\s?\d{2}\s?\d{2}\s?\d{2}\s?[A-D]\b", re.IGNORECASE),
    ),
    Rule(
        "canadian_sin",
        "warn",
        re.compile(r"\b\d{3}[ -]\d{3}[ -]\d{3}\b"),
    ),
    Rule(
        "international_phone",
        "warn",
        re.compile(r"(?<!\w)\+[2-9]\d{7,14}\b"),
    ),
)

HIGH_COLUMN_NAMES = frozenset(
    {
        "ssn",
        "social_security",
        "national_id",
        "passport",
        "tax_id",
        "drivers_license",
        "credit_card",
        "card_number",
        "cvv",
        "account_number",
        "routing_number",
    }
)
WARN_COLUMN_NAMES = frozenset(
    {
        "dob",
        "date_of_birth",
        "birth_date",
        "email",
        "phone",
        "address",
        "postal",
        "zip",
        "patient_id",
        "member_id",
        "mrn",
        "full_name",
        "first_name",
        "last_name",
        "salary",
        "compensation",
    }
)

STRUCTURED_COLUMN_PATTERNS: tuple[re.Pattern[str], ...] = (
    re.compile(
        r"^\s*-?\s*[\"']?(?:name|field|column)[\"']?\s*:\s*" r"[\"']?(?P<column>[A-Za-z][A-Za-z0-9_-]*)",
        re.IGNORECASE,
    ),
    # Bare ``key: value`` declarations only count when the right-hand side is a
    # structural or type-like token; free prose such as "Address: see the
    # runbook" is not a column declaration.
    re.compile(
        r"^\s*[\"']?(?P<column>[A-Za-z][A-Za-z0-9_-]*)[\"']?\s*:(?P<value>.*)$",
        re.IGNORECASE,
    ),
    re.compile(
        r"^\s*[\"`\[]?(?P<column>[A-Za-z][A-Za-z0-9_-]*)[\"`\]]?\s+"
        r"(?:bigint|boolean|date|datetime|decimal|float|int|integer|numeric|"
        r"text|timestamp|varchar)\b",
        re.IGNORECASE,
    ),
)
SCALAR_TYPE_NAMES = frozenset(
    {
        "bigint",
        "bool",
        "boolean",
        "bytes",
        "char",
        "date",
        "datetime",
        "decimal",
        "double",
        "float",
        "int",
        "int32",
        "int64",
        "integer",
        "json",
        "long",
        "null",
        "number",
        "numeric",
        "object",
        "str",
        "string",
        "text",
        "time",
        "timestamp",
        "uuid",
        "varchar",
    }
)
INLINE_COLUMNS_PATTERN = re.compile(
    r"[\"']?(?:columns?|fields?)[\"']?\s*:\s*\[(?P<columns>[^\]]*)\]",
    re.IGNORECASE,
)
IDENTIFIER_PATTERN = re.compile(r"[A-Za-z][A-Za-z0-9_-]*")
SAMPLE_CONTEXT_PATTERN = re.compile(
    r"(?:^\s*#{1,6}\s*|^\s*[\"']?)(?:sample|example|preview)(?:\s+rows?|\s+data)?" r"(?:[\"']?\s*:|\s*$)",
    re.IGNORECASE,
)
SAMPLE_CONTEXT_MAX_LINES = 50
MARKDOWN_HEADING_PATTERN = re.compile(r"^\s*#{1,6}\s")
CODE_FENCE_PATTERN = re.compile(r"^\s*(?:```|~~~)")
MARKDOWN_TABLE_ROW_PATTERN = re.compile(r"^\s*\|(?:[^|]+\|){2,}\s*$")
# Alignment/separator rows carry no data and must not be reported as samples.
MARKDOWN_SEPARATOR_CELL_PATTERN = re.compile(r"^[\s:-]+$")
JSON_ARRAY_PATTERN = re.compile(r"^\s*\[(?:[^\[\]]|\[[^\]]*\])*\]\s*,?\s*$")
SAS_URL_PATTERN = re.compile(r"https?://[^\s\"']{1,512}\?[^\s\"']{1,2048}", re.IGNORECASE)
# Documentation placeholders must not block writes.
PLACEHOLDER_VALUE_PATTERN = re.compile(
    r"^(?:[x*]{3,}"
    r"|<[^<>]{0,200}>"
    r"|[A-Za-z0-9_-]{0,80}(?:redacted|changeme|placeholder|todo|example|your[_-])"
    r"[A-Za-z0-9_-]{0,80})$",
    re.IGNORECASE,
)

# Categories whose matched text is itself the secret (or the customer-specific
# term the denylist exists to protect). No fragment of the match is reported.
NO_PREVIEW_CATEGORIES = frozenset(
    {
        "connection_string",
        "jdbc_odbc_uri",
        "db_uri_with_credentials",
        "storage_key",
        "bearer_token",
        "sas_token",
        "private_key_block",
        "cloud_access_key_id",
        "source_control_token",
        "chat_webhook_token",
        "web_token",
        "generic_secret_assignment",
        "sample_row",
        "denylist_term",
    }
)
REDACTED_PREVIEW = "[redacted]"


def _iter_lines(text: str) -> Iterator[tuple[int, str]]:
    """Yield 1-based numbered lines truncated to ``MAX_LINE_LENGTH``.

    Truncation bounds per-line regex work so one pathological line cannot
    dominate runtime; content past the cap is not scanned.
    """
    for line_number, line in enumerate(text.splitlines(), start=1):
        yield line_number, line[:MAX_LINE_LENGTH]


def _redact(match: str) -> str:
    """Return a masked preview of matched content for safe reporting."""
    stripped = match.strip()
    if len(stripped) <= 8:
        return stripped[0] + "***" if stripped else "***"
    return f"{stripped[:4]}***{stripped[-2:]}"


def _finding(
    source: str,
    line_number: int,
    column: int,
    category: str,
    confidence: str,
    match: str,
) -> dict[str, Any]:
    """Build one finding, suppressing any preview for secret-bearing categories."""
    finding: dict[str, Any] = {
        "source": source,
        "line": line_number,
        "column": column,
        "category": category,
        "confidence": confidence,
    }
    if category in NO_PREVIEW_CATEGORIES:
        finding["match"] = REDACTED_PREVIEW
        finding["length"] = len(match.strip())
    else:
        finding["match"] = _redact(match)
    return finding


def _assignment_value(match: str) -> str:
    """Return the right-hand side of the first ``:`` or ``=`` in ``match``."""
    parts = re.split(r"[:=]", match, maxsplit=1)
    if len(parts) < 2:
        return ""
    return parts[1].strip().strip("\"'")


def _is_structural_value(value: str) -> bool:
    """Return True when a ``key: value`` right-hand side is structural, not prose."""
    stripped = value.strip().rstrip(",").strip()
    if not stripped or stripped in {"{", "[", "|", ">", "{}", "[]", "~"}:
        return True
    if len(stripped) >= 2 and stripped[0] in "\"'" and stripped[-1] in "\"'":
        return True
    if re.fullmatch(r"-?\d+(?:\.\d+)?", stripped):
        return True
    return stripped.split("(", 1)[0].strip().lower() in SCALAR_TYPE_NAMES


def _normalize_identifier(value: str) -> str:
    """Normalize snake, kebab, and camel-case identifiers for comparison."""
    value = re.sub(r"(?<=[a-z0-9])(?=[A-Z])", "_", value)
    return re.sub(r"[^A-Za-z0-9]+", "_", value).strip("_").lower()


def _scan_structured_columns(text: str, source: str) -> list[dict[str, Any]]:
    """Detect sensitive column names only in structured declarations."""
    findings: list[dict[str, Any]] = []
    for line_number, line in _iter_lines(text):
        candidates: list[tuple[str, int]] = []
        for pattern in STRUCTURED_COLUMN_PATTERNS:
            match = pattern.search(line)
            if not match:
                continue
            value = match.groupdict().get("value")
            if value is not None and not _is_structural_value(value):
                continue
            candidates.append((match.group("column"), match.start("column")))
            break
        inline = INLINE_COLUMNS_PATTERN.search(line)
        if inline:
            candidates.extend(
                (match.group(0), match.start()) for match in IDENTIFIER_PATTERN.finditer(inline.group("columns"))
            )
        for candidate, column in candidates:
            normalized = _normalize_identifier(candidate)
            confidence = (
                "high" if normalized in HIGH_COLUMN_NAMES else "warn" if normalized in WARN_COLUMN_NAMES else None
            )
            if confidence:
                findings.append(
                    _finding(
                        source,
                        line_number,
                        column + 1,
                        "sensitive_column_name",
                        confidence,
                        candidate,
                    )
                )
    return findings


def _is_sample_row(line: str) -> bool:
    """Return True for a data-bearing table or array row.

    Markdown alignment rows (cells of only ``-``, ``:``, and whitespace) carry
    no data and are excluded.
    """
    if JSON_ARRAY_PATTERN.match(line):
        return True
    if not MARKDOWN_TABLE_ROW_PATTERN.match(line):
        return False
    cells = [cell for cell in line.strip().strip("|").split("|")]
    return not all(MARKDOWN_SEPARATOR_CELL_PATTERN.match(cell) for cell in cells)


def _scan_sample_rows(text: str, source: str) -> list[dict[str, Any]]:
    """Warn on table or array rows in an explicit, bounded sample context.

    The context ends at the next heading, a fenced-code delimiter, a blank line
    after at least one matched row, or ``SAMPLE_CONTEXT_MAX_LINES`` lines from
    the context start, so unrelated structures further down are not attributed
    to the sample.
    """
    findings: list[dict[str, Any]] = []
    sample_context = False
    context_start = 0
    matched_rows = 0
    for line_number, line in _iter_lines(text):
        if SAMPLE_CONTEXT_PATTERN.search(line):
            sample_context = True
            context_start = line_number
            matched_rows = 0
            continue
        if not sample_context:
            continue
        if (
            MARKDOWN_HEADING_PATTERN.match(line)
            or CODE_FENCE_PATTERN.match(line)
            or (not line.strip() and matched_rows > 0)
            or line_number - context_start > SAMPLE_CONTEXT_MAX_LINES
        ):
            sample_context = False
            continue
        if _is_sample_row(line):
            matched_rows += 1
            findings.append(_finding(source, line_number, 1, "sample_row", "warn", line))
    return findings


def _scan_sas_tokens(text: str, source: str) -> list[dict[str, Any]]:
    """Detect SAS URLs only when signature, expiry, and permission fields coexist."""
    findings: list[dict[str, Any]] = []
    for line_number, line in _iter_lines(text):
        for match in SAS_URL_PATTERN.finditer(line):
            query = match.group(0).split("?", 1)[1].lower()
            fields = {part.split("=", 1)[0] for part in query.split("&") if "=" in part}
            if {"sig", "se", "sp"}.issubset(fields):
                findings.append(
                    _finding(
                        source,
                        line_number,
                        match.start() + 1,
                        "sas_token",
                        "high",
                        match.group(0),
                    )
                )
    return findings


def _build_denylist_rules(terms: list[str]) -> tuple[Rule, ...]:
    """Build case-insensitive literal high-confidence rules."""
    return tuple(Rule("denylist_term", "high", re.compile(re.escape(term), re.IGNORECASE)) for term in terms)


def _finding_sort_key(finding: dict[str, Any]) -> tuple[str, int, int, str]:
    """Order findings deterministically across multi-path runs."""
    return (finding["source"], finding["line"], finding["column"], finding["category"])


def _load_denylist(path: Path) -> tuple[Rule, ...]:
    """Read unique nonblank UTF-8 denylist terms without exposing them.

    Fails closed: an unreadable, oversized, or effectively empty denylist is a
    configuration error rather than a scan with no denylist rules.
    """
    try:
        if not path.is_file():
            raise OSError("path is not a readable file")
        size = path.stat().st_size
    except OSError as exc:
        raise ScanError("denylist_unreadable", "denylist must be a readable UTF-8 text file") from exc
    if size > MAX_DENYLIST_BYTES:
        raise ScanError("denylist_too_large", f"denylist exceeds {MAX_DENYLIST_BYTES} bytes")
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeError) as exc:
        raise ScanError("denylist_unreadable", "denylist must be a readable UTF-8 text file") from exc
    terms: list[str] = []
    seen: set[str] = set()
    for line in lines:
        term = line.strip()
        if not term:
            continue
        if len(term) < MIN_DENYLIST_TERM_LENGTH:
            raise ScanError(
                "denylist_term_too_short",
                f"denylist terms must be at least {MIN_DENYLIST_TERM_LENGTH} characters",
            )
        key = term.casefold()
        if key in seen:
            continue
        terms.append(term)
        seen.add(key)
        if len(terms) > MAX_DENYLIST_TERMS:
            raise ScanError("denylist_too_large", f"denylist exceeds {MAX_DENYLIST_TERMS} terms")
    if not terms:
        raise ScanError("denylist_empty", "denylist contains no usable terms")
    return _build_denylist_rules(terms)


def scan_text(
    text: str,
    source: str,
    *,
    public: bool = False,
    data: bool = False,
    denylist_rules: tuple[Rule, ...] = (),
) -> list[dict[str, Any]]:
    """Return a list of finding dicts for ``text`` attributed to ``source``.

    When ``public`` is true, internal-URL rules are included; in a private
    repository those references are expected and are not flagged.
    """
    active_rules = RULES
    if public:
        active_rules = (*active_rules, *PUBLIC_ONLY_RULES)
    if data:
        active_rules = (*active_rules, *DATA_ONLY_RULES)
    active_rules = (*active_rules, *denylist_rules)
    findings: list[dict[str, Any]] = []
    for line_number, line in _iter_lines(text):
        for rule in active_rules:
            for match in rule.pattern.finditer(line):
                if rule.category == "generic_secret_assignment" and PLACEHOLDER_VALUE_PATTERN.match(
                    _assignment_value(match.group(0))
                ):
                    continue
                findings.append(
                    _finding(
                        source,
                        line_number,
                        match.start() + 1,
                        rule.category,
                        rule.confidence,
                        match.group(0),
                    )
                )
    if data:
        findings.extend(_scan_structured_columns(text, source))
        findings.extend(_scan_sample_rows(text, source))
        findings.extend(_scan_sas_tokens(text, source))
    findings.sort(key=_finding_sort_key)
    return findings


def create_parser() -> argparse.ArgumentParser:
    """Create the argument parser."""
    parser = argparse.ArgumentParser(
        prog="scan_sensitive_content",
        description=("Scan ADR/handoff content for high-confidence PII and public-repository internal URLs."),
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
    parser.add_argument(
        "--data",
        action="store_true",
        help=(
            "Enable structured column, connection, credential, sample-row, "
            "and international identifier detection for data artifacts."
        ),
    )
    parser.add_argument(
        "--denylist",
        type=Path,
        help=(
            "UTF-8 text file containing one literal customer-specific term "
            "per line; enables high-confidence matching independently."
        ),
    )
    return parser


def _summarize(findings: list[dict[str, Any]]) -> dict[str, int]:
    """Return high/warn/total counts for ``findings``."""
    return {
        "high": sum(1 for finding in findings if finding["confidence"] == "high"),
        "warn": sum(1 for finding in findings if finding["confidence"] == "warn"),
        "total": len(findings),
    }


def _build_report(
    *,
    status: str,
    modes: dict[str, bool],
    denylist_rule_count: int,
    findings: list[dict[str, Any]],
    error: ScanError | None = None,
) -> dict[str, Any]:
    """Build the versioned report emitted on every terminal path."""
    report: dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "status": status,
    }
    if error is not None:
        report["error"] = {"code": error.code, "message": error.message}
    report["modes"] = modes
    report["denylist_rule_count"] = denylist_rule_count
    report["findings"] = findings
    report["summary"] = _summarize(findings)
    return report


def _allow_roots(args: argparse.Namespace) -> list[Path]:
    """Build the allow-root list shared by scanned paths and the denylist."""
    roots: list[Path] = [SKILL_ROOT, REPO_ROOT]
    for raw in args.paths:
        try:
            roots.append(raw.expanduser().resolve().parent)
        except OSError:
            # Unresolvable path (e.g. broken symlink); safe_resolve rejects it
            # explicitly rather than widening the allowlist here.
            continue
    for raw in args.allow_root:
        try:
            roots.append(raw.expanduser().resolve())
        except OSError:
            continue
    return roots


def _scan_paths(
    args: argparse.Namespace,
    allow_roots: list[Path],
    denylist_rules: tuple[Rule, ...],
) -> list[dict[str, Any]]:
    """Scan every requested path, failing closed on any path, size, or read failure."""
    findings: list[dict[str, Any]] = []
    total_bytes = 0
    for raw in args.paths:
        try:
            resolved = safe_resolve(raw, allow_roots)
        except ValueError as exc:
            raise ScanError("path_error", f"path error: {exc}") from exc
        try:
            total_bytes += resolved.stat().st_size
        except OSError as exc:
            raise ScanError("read_error", f"failed to read '{raw}'") from exc
        if total_bytes > MAX_INPUT_BYTES:
            raise ScanError("input_too_large", f"input exceeds {MAX_INPUT_BYTES} bytes")
        try:
            text = resolved.read_text(encoding="utf-8")
        except UnicodeDecodeError as exc:
            raise ScanError("decode_error", f"failed to decode '{raw}' as UTF-8") from exc
        except OSError as exc:
            raise ScanError("read_error", f"failed to read '{raw}'") from exc
        findings.extend(
            scan_text(
                text,
                str(raw),
                public=args.public,
                data=args.data,
                denylist_rules=denylist_rules,
            )
        )
    return findings


def _scan_stdin(
    args: argparse.Namespace,
    denylist_rules: tuple[Rule, ...],
) -> list[dict[str, Any]]:
    """Scan stdin, failing closed on decode failure or over-limit input."""
    try:
        text = sys.stdin.read()
    except UnicodeDecodeError as exc:
        raise ScanError("decode_error", "failed to decode stdin as UTF-8") from exc
    except OSError as exc:
        raise ScanError("read_error", "failed to read stdin") from exc
    if len(text.encode("utf-8", errors="ignore")) > MAX_INPUT_BYTES:
        raise ScanError("input_too_large", f"input exceeds {MAX_INPUT_BYTES} bytes")
    return scan_text(
        text,
        STDIN_SOURCE,
        public=args.public,
        data=args.data,
        denylist_rules=denylist_rules,
    )


def main(argv: list[str] | None = None) -> int:
    """Main entry point."""
    args = create_parser().parse_args(argv)
    modes = {
        "public": bool(args.public),
        "data": bool(args.data),
        "denylist": args.denylist is not None,
    }
    denylist_rules: tuple[Rule, ...] = ()

    try:
        allow_roots = _allow_roots(args)
        if args.denylist is not None:
            try:
                denylist_path = safe_resolve(args.denylist, allow_roots)
            except ValueError as exc:
                raise ScanError("path_error", f"denylist path error: {exc}") from exc
            denylist_rules = _load_denylist(denylist_path)
        findings = _scan_paths(args, allow_roots, denylist_rules) if args.paths else _scan_stdin(args, denylist_rules)
    except ScanError as exc:
        print(f"scan_sensitive_content: {exc.message}", file=sys.stderr)
        print(
            json.dumps(
                _build_report(
                    status=STATUS_ERROR,
                    modes=modes,
                    denylist_rule_count=len(denylist_rules),
                    findings=[],
                    error=exc,
                ),
                indent=2,
            )
        )
        return EXIT_ERROR

    findings.sort(key=_finding_sort_key)
    report = _build_report(
        status=STATUS_COMPLETED,
        modes=modes,
        denylist_rule_count=len(denylist_rules),
        findings=findings,
    )
    print(json.dumps(report, indent=2))

    return EXIT_FAILURE if report["summary"]["high"] else EXIT_SUCCESS


if __name__ == "__main__":
    sys.exit(main())
