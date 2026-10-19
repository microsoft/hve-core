# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

"""Schema, privacy, reference, and artifact validation for evidence bundles."""

from __future__ import annotations

import json
import re
from datetime import datetime
from pathlib import Path
from typing import Any

import jsonschema

from runtime_a11y._errors import EXIT_USAGE, ScriptError
from runtime_a11y.visual_review import compute_sha256, normalize_manifest_path

_SCHEMA_ROOT = Path(__file__).resolve().parent.parent
_KEY_SEPARATORS = re.compile(r"[^a-z0-9]")
# Matched exactly after normalization, so ordinary words that merely contain
# "key" or "token" are not rejected. Mirrors the binding-side key policy.
_FORBIDDEN_KEYS = frozenset(
    {
        "phrases",
        "rawspeech",
        "rawtranscript",
        "transcriptpath",
        "email",
        "reviewername",
        "auth",
        "authorization",
        "authorisation",
        "cookie",
        "cookies",
        "credential",
        "credentials",
        "header",
        "headers",
        "password",
        "passwd",
        "passphrase",
        "storagestate",
        "token",
        "tokens",
        "accesstoken",
        "bearertoken",
        "idtoken",
        "refreshtoken",
        "sessiontoken",
        "secret",
        "secrets",
        "clientsecret",
        "key",
        "apikey",
        "apikeys",
        "accesskey",
        "encryptionkey",
        "privatekey",
        "secretkey",
        "signingkey",
        "sastoken",
        "sharedaccesssignature",
        "connectionstring",
        "githubtoken",
        "ghtoken",
        "pat",
        "personalaccesstoken",
        "clientassertion",
        "awsaccesskeyid",
        "awssecretaccesskey",
        "sessionkey",
        "certificate",
        "pfx",
    }
)
_CREDENTIAL_PATTERN = re.compile(
    r"(?i)\b(?:password|passwd|api[-_ ]?key|access[-_ ]?token|"
    r"client[-_ ]?secret)\b\s*[:=]\s*\S+"
    # Bounded shape detectors for carriers that need no labelling word.
    r"|(?:^|[?&;])s(?:i)?g=[A-Za-z0-9%+/=]{16,}"
    r"|\bSharedAccessSignature\b|\bAccountKey\s*=\s*\S+"
    r"|\bBearer\s+[A-Za-z0-9\-._~+/]{20,}"
    r"|\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"
    r"|\bgh[pousr]_[A-Za-z0-9]{20,}"
    r"|\bgithub_pat_[A-Za-z0-9_]{20,}"
    r"|\bAKIA[0-9A-Z]{16}\b"
    r"|-----BEGIN(?:[A-Z ]+)?PRIVATE KEY-----"
)
_DATETIME_KEYS = frozenset(
    {"composedAt", "generatedAt", "observedAt", "validUntil", "verifiedAt"}
)


def _schema(name: str) -> dict[str, Any]:
    return json.loads((_SCHEMA_ROOT / name).read_text(encoding="utf-8"))


def validate_document(
    document: Any,
    schema_name: str,
    *,
    definition: str | None = None,
) -> None:
    """Validate a document against a root schema or named definition."""
    schema = _schema(schema_name)
    target = schema
    if definition is not None:
        target = {
            "$schema": schema["$schema"],
            "$defs": schema["$defs"],
            **schema["$defs"][definition],
        }
    try:
        jsonschema.Draft202012Validator(
            target,
            format_checker=jsonschema.FormatChecker(),
        ).validate(document)
    except (KeyError, jsonschema.ValidationError, jsonschema.SchemaError) as exc:
        message = getattr(exc, "message", str(exc))
        raise ScriptError(
            f"Evidence schema validation failed: {message}", EXIT_USAGE
        ) from exc
    reject_prohibited_content(document)
    _validate_datetimes(document)


def _validate_datetimes(value: Any, key: str | None = None) -> None:
    if key in _DATETIME_KEYS:
        try:
            parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
        except ValueError as exc:
            raise ScriptError(f"Invalid evidence timestamp: {key}", EXIT_USAGE) from exc
        if parsed.tzinfo is None or parsed.utcoffset() is None:
            raise ScriptError(
                f"Evidence timestamp requires a UTC offset: {key}", EXIT_USAGE
            )
    if isinstance(value, dict):
        for child_key, child in value.items():
            _validate_datetimes(child, str(child_key))
    elif isinstance(value, list):
        for child in value:
            _validate_datetimes(child, key)


def normalize_policy_key(key: str) -> str:
    """Normalize a metadata key for exact-match policy comparison."""
    return _KEY_SEPARATORS.sub("", key.lower())


def reject_prohibited_content(value: Any, key: str | None = None) -> None:
    """Reject secrets, raw speech, and unrestricted reviewer identity."""
    if key is not None and normalize_policy_key(key) in _FORBIDDEN_KEYS:
        raise ScriptError(f"Evidence field '{key}' is forbidden", EXIT_USAGE)
    if isinstance(value, dict):
        for child_key, child in value.items():
            reject_prohibited_content(child, str(child_key))
    elif isinstance(value, list):
        for child in value:
            reject_prohibited_content(child, key)
    elif isinstance(value, str) and _CREDENTIAL_PATTERN.search(value):
        raise ScriptError("Credential-shaped evidence content is forbidden", EXIT_USAGE)


def verify_artifacts(artifacts: list[dict[str, Any]], root: Path) -> None:
    """Verify contained artifact paths, sizes, and SHA-256 digests."""
    for artifact in artifacts:
        relative = normalize_manifest_path(artifact["path"], run_root=root)
        path = (root.resolve() / relative).resolve()
        if not path.is_file():
            raise ScriptError(f"Evidence artifact is missing: {relative}", EXIT_USAGE)
        if path.stat().st_size != artifact["sizeBytes"]:
            raise ScriptError(
                f"Evidence artifact size mismatch: {relative}", EXIT_USAGE
            )
        if compute_sha256(path) != artifact["sha256"]:
            raise ScriptError(
                f"Evidence artifact digest mismatch: {relative}", EXIT_USAGE
            )
