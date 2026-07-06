# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

"""Load, validate, and guard the project-supplied a11y-runtime config.

The config schema is described by config-schema.json (JSON Schema 2020-12).
The SSRF guard restricts probing to loopback hosts unless the target host is
explicitly allowlisted or external access is confirmed by the caller.
"""

from __future__ import annotations

import json
from fnmatch import fnmatch
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

from runtime_a11y._errors import EXIT_USAGE, ScriptError

_SCHEMA_PATH = Path(__file__).with_name("config-schema.json")
_LOOPBACK_HOSTS = frozenset({"localhost", "127.0.0.1", "::1"})


def load_schema() -> dict[str, Any]:
    """Load the runtime config JSON Schema."""
    return json.loads(_SCHEMA_PATH.read_text(encoding="utf-8"))


def load_config(config_path: Path) -> dict[str, Any]:
    """Read and parse the config file, returning the raw mapping.

    Args:
        config_path: Path to a11y-runtime.config.json.

    Raises:
        ScriptError: If the file is missing or not valid JSON.
    """
    try:
        raw = config_path.read_text(encoding="utf-8")
    except OSError as exc:
        raise ScriptError(
            f"Cannot read config file: {config_path}", EXIT_USAGE
        ) from exc
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ScriptError(
            f"Config file is not valid JSON: {config_path} ({exc})", EXIT_USAGE
        ) from exc
    if not isinstance(parsed, dict):
        raise ScriptError("Config root must be a JSON object", EXIT_USAGE)
    return parsed


def validate_config(config: dict[str, Any]) -> None:
    """Validate the config against config-schema.json.

    Raises:
        ScriptError: If the config does not conform to the schema.
    """
    try:
        import jsonschema
    except ImportError as exc:  # pragma: no cover - dependency guard
        raise ScriptError(
            "The 'jsonschema' package is required to validate the config. "
            "Install it via 'uv sync'.",
            EXIT_USAGE,
        ) from exc

    try:
        jsonschema.validate(instance=config, schema=load_schema())
    except jsonschema.ValidationError as exc:
        raise ScriptError(
            f"Invalid a11y-runtime config: {exc.message}", EXIT_USAGE
        ) from exc


def _host_is_loopback(host: str) -> bool:
    return host.lower() in _LOOPBACK_HOSTS


def _host_is_allowlisted(host: str, allowlist: list[str]) -> bool:
    """Return True if the host matches any host-shaped allowlist entry.

    Route/path globs (entries beginning with '/') do not authorize a host and
    are ignored here.
    """
    for entry in allowlist:
        if not entry or entry.startswith("/"):
            continue
        candidate = entry.split("/", 1)[0]
        if fnmatch(host.lower(), candidate.lower()):
            return True
    return False


def assert_target_allowed(config: dict[str, Any], allow_external: bool = False) -> None:
    """Enforce the SSRF/localhost-allowlist guard on the config baseUrl.

    Loopback hosts are always permitted. A non-loopback host is permitted only
    when it matches a host-shaped allowlist entry or when ``allow_external`` is
    explicitly set by the caller. Otherwise a ScriptError instructs the caller
    to confirm external access.

    Raises:
        ScriptError: If the target host is neither loopback nor authorized.
    """
    base_url = config.get("baseUrl", "")
    host = urlparse(base_url).hostname or ""
    if not host:
        raise ScriptError(
            "Config baseUrl must include a host (for example http://127.0.0.1:3000).",
            EXIT_USAGE,
        )
    if _host_is_loopback(host):
        return
    allowlist = config.get("allowlist") or []
    if isinstance(allowlist, list) and _host_is_allowlisted(host, allowlist):
        return
    if allow_external:
        return
    raise ScriptError(
        f"Refusing to probe non-loopback host '{host}'. Add it to the config "
        "allowlist or re-run with --allow-external to confirm intentional "
        "external access.",
        EXIT_USAGE,
    )


def load_validated_config(
    config_path: Path, allow_external: bool = False
) -> dict[str, Any]:
    """Load, schema-validate, and SSRF-guard a config in one call."""
    config = load_config(config_path)
    validate_config(config)
    assert_target_allowed(config, allow_external=allow_external)
    return config
