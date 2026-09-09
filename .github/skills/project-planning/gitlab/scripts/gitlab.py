#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
# /// script
# requires-python = ">=3.11"
# ///

"""GitLab REST API v4 client for merge requests, pipelines, and jobs.

Environment variables:
    GITLAB_URL: Required GitLab base URL.
    GITLAB_AUTH_MODE: Authentication mode. Defaults to oauth.
    GITLAB_OAUTH_CLIENT_ID: Public OAuth application ID in oauth mode.
    GITLAB_TOKEN: Personal access token in explicit legacy-token mode only.
    GITLAB_PROFILE: Optional local OAuth profile name.
    GITLAB_TOKEN_STORE: Optional OAuth token-store path override.
    GITLAB_ALLOW_INSECURE: Allows loopback HTTP only when set to 1.
    XDG_DATA_HOME: Optional POSIX base directory for OAuth profile storage.
    LOCALAPPDATA: Optional Windows base directory for OAuth profile storage.
    GITLAB_PROJECT: Optional project id or path. Auto-detected from git remote.
"""

from __future__ import annotations

import json
import logging
import os
import pathlib
import re
import subprocess
import sys
import traceback
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Callable, cast

sys.dont_write_bytecode = True

import _gitlab_credentials as credentials  # noqa: E402
import _gitlab_oauth as oauth  # noqa: E402

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_USAGE = 2
REQUEST_TIMEOUT = 30
MAX_BODY_BYTES = 1_048_576
MAX_LOG_BYTES = 65_536
MAX_NUMERIC_ID = 2_147_483_647
MAX_POSITIVE_INT = 100
VALID_MR_STATES = {"all", "opened", "closed", "locked", "merged"}
REF_PATTERN = re.compile(r"^[\w./-]+$")

selected_fields: list[str] | None = None
gitlab_url = ""
api_url = ""
audit_actor = ""
# The resolved credential lives only on this immutable context, never in a
# mutable module global that repr(globals()) or a traceback frame could dump.
auth_context: "AuthContext | None" = None
_AUDIT_OP = ""

_OAUTH_AUDIT_OPERATIONS = {
    "oauth.authorization_code.exchange",
    "oauth.device.authorize",
    "oauth.device.poll",
    "oauth.refresh",
}
_OAUTH_FAILURE_KINDS = {
    "http",
    "network",
    "protocol",
    "timeout",
    "cancelled",
    "unknown",
}

LOGGER = logging.getLogger("gitlab")
# _emit prints to stderr itself and logs at ERROR. Without a handler, logging's
# lastResort fallback would also write every ERROR record to stderr, printing
# each message twice. The NullHandler suppresses that while leaving the logger
# available to an embedder that configures its own handlers.
LOGGER.addHandler(logging.NullHandler())

# Credential-bearing key names scrubbed from any string routed through
# ``_redact``. The first nine mirror the mural skill's OAuth/OIDC baseline and
# are live here: the skill runs Authorization Code with PKCE and the Device
# Authorization Grant. ``code_challenge`` is deliberately absent because a PKCE
# challenge is public by design and masking it would corrupt an authorize URL.
_REDACT_KEYS = (
    "access_token",
    "refresh_token",
    "code_verifier",
    "client_secret",
    "id_token",  # OIDC ID Token (JWT)
    "assertion",  # RFC 7521 4.2 - JWT/SAML bearer grant assertion
    "client_assertion",  # RFC 7521 4.2 - JWT/SAML client authentication
    "device_code",  # RFC 8628 device-authorization grant pre-auth secret
    "password",  # RFC 6749 4.3 ROPC credential
    "private_token",
    "oauth_token",
    "deploy_token",
    "job_token",
)
# JSON shape: "key": "value"
_REDACT_PATTERNS: list[tuple[re.Pattern[str], str]] = [
    (
        re.compile(
            rf'("{re.escape(key)}"\s*:\s*")((?:\\.|[^"\\])*)(")',
            re.IGNORECASE,
        ),
        r"\1[REDACTED]\3",
    )
    for key in _REDACT_KEYS
]
_REDACT_PATTERNS.extend(
    (
        re.compile(
            rf'(\\"{re.escape(key)}\\"\s*:\s*\\")((?:\\.|[^"\\])*)(\\")',
            re.IGNORECASE,
        ),
        r"\1[REDACTED]\3",
    )
    for key in _REDACT_KEYS
)
# Bare form shape: key=value, with no leading ? or & required. The existing
# query-string rule in ``_redact`` only fires after a ? or &, so a token echoed
# into a CI job trace or an error body would otherwise survive.
_REDACT_PATTERNS.extend(
    (
        re.compile(rf"(\b{re.escape(key)}=)([^&\s]+)", re.IGNORECASE),
        r"\1[REDACTED]",
    )
    for key in (*_REDACT_KEYS, "code")
)
_REDACT_PATTERNS.extend(
    (
        re.compile(
            rf"({urllib.parse.quote(key, safe='')}%3[Dd])([^&%\s]+)",
            re.IGNORECASE,
        ),
        r"\1[REDACTED]",
    )
    for key in (*_REDACT_KEYS, "code")
)
# Azure Blob SAS query strings: drop everything after the storage host's ?.
_REDACT_PATTERNS.append(
    (re.compile(r"(\.blob\.core\.windows\.net/[^\s?]+\?)\S+"), r"\1[REDACTED]")
)


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    """Refuse redirects so tokens are not replayed to a new host."""

    def redirect_request(
        self,
        req: urllib.request.Request,
        fp: object,
        code: int,
        msg: str,
        headers: object,
        newurl: str,
    ) -> urllib.request.Request | None:
        location = newurl or "<unknown>"
        raise urllib.error.HTTPError(
            req.full_url,
            code,
            f"refusing redirect to {location}",
            headers,
            fp,
        )


_OPENER = urllib.request.build_opener(_NoRedirect())


@dataclass(frozen=True)
class AuthContext:
    """Resolved GitLab authentication mode and credential state.

    Frozen so the resolved credential cannot be reassigned mid-run, and
    ``token`` carries ``repr=False`` so an accidental ``repr(auth_context)``,
    f-string interpolation, or traceback frame dump cannot surface the PAT.
    """

    mode: str
    issuer: str
    token: str | None = field(default=None, repr=False)
    profile_name: str | None = None
    store_path: pathlib.Path | None = None
    client_id: str | None = None


class GitLabError(Exception):
    """Base CLI failure carrying an exit code and a redacted string form.

    This is the only failure mechanism in the module. Every error path raises
    this class or a subclass; nothing calls ``sys.exit`` or raises
    ``SystemExit`` outside the ``__main__`` guard. A single mechanism keeps the
    contract verifiable by static analysis, guarantees that a helper promising
    a return value cannot fall through to a silent ``None``, and gives
    :func:`main` one place to emit and translate a failure.

    ``main`` catches this class, emits the redacted message once through
    :func:`_emit`, and returns :attr:`exit_code` as the process status. Raising
    sites therefore do not emit; the message travels on the exception.
    """

    def __init__(self, message: str = "", exit_code: int = EXIT_FAILURE) -> None:
        super().__init__(message)
        self.message = message
        self.exit_code = exit_code

    def __str__(self) -> str:
        return _redact(self.message)


class GitLabAPIError(GitLabError):
    """GitLab API failure with a controlled, secret-free string form.

    Only the status, method, query-stripped resource, redacted summary, and
    request ID are rendered. Raw response bodies, request URLs with query
    strings, and header dictionaries are never part of the string form.
    """

    def __init__(
        self,
        *,
        status: int | None = None,
        method: str = "",
        resource: str = "",
        message: str = "",
        request_id: str = "",
        exit_code: int = EXIT_FAILURE,
    ) -> None:
        super().__init__(message, exit_code)
        self.status = status
        self.method = method
        self.resource = resource
        self.request_id = request_id

    def __str__(self) -> str:
        head = "GitLab API request failed"
        if self.status is not None:
            head = f"HTTP {self.status}"
        if self.method and self.resource:
            head = f"{head} from {self.method} {self.resource}"
        detail = _redact(self.message).strip() if self.message else ""
        if detail:
            head = f"{head}: {detail}"
        if self.request_id:
            head = f"{head} (request_id={self.request_id})"
        return head

    def __repr__(self) -> str:
        return (
            f"GitLabAPIError(status={self.status!r}, method={self.method!r}, "
            f"resource={self.resource!r}, request_id={self.request_id!r})"
        )


def _emit(message: str, *, level: int = logging.ERROR) -> None:
    """Write a redacted message to the module logger and stderr."""
    redacted = _redact(message)
    LOGGER.log(level, redacted)
    print(redacted, file=sys.stderr)


def _emit_stdout(text: str, *, end: str = "\n") -> None:
    """Write redacted text to stdout.

    Command results and CI job traces are attacker-influenced upstream content,
    so stdout passes the same redaction barrier as stderr rather than bypassing
    it.
    """
    print(_redact(text), end=end)


def _emit_structured_stdout(text: str, *, end: str = "\n") -> None:
    """Write already-sanitized machine-readable output to stdout."""
    print(text, end=end)


def _emit_debug_traceback(exc: BaseException) -> None:
    """Write a redacted traceback to stderr when ``GITLAB_DEBUG`` is set."""
    if not os.environ.get("GITLAB_DEBUG"):
        return
    formatted = "".join(traceback.format_exception(type(exc), exc, exc.__traceback__))
    print(_redact(formatted), file=sys.stderr)


def _scrub_url(url: str) -> str:
    """Return a URL with the query string and fragment removed."""
    parsed = urllib.parse.urlsplit(url)
    return urllib.parse.urlunsplit((parsed.scheme, parsed.netloc, parsed.path, "", ""))


def _response_request_id(response: Any) -> str:
    """Extract a bounded, safe request-correlation ID when the server sends one."""
    headers = getattr(response, "headers", None)
    if headers is None or not hasattr(headers, "get"):
        return ""
    for name in ("X-Request-Id", "X-Gitlab-Meta", "X-Trace-Id"):
        value = headers.get(name)
        if value:
            candidate = str(value).strip()[:128]
            if re.fullmatch(r"[A-Za-z0-9._:-]+", candidate):
                return candidate
    return ""


def _redact(text: str) -> str:
    """Remove common secret-looking values from any text bound for output."""
    if not text:
        return text
    redacted = re.sub(
        r"(?i)\b(Bearer|Basic)\s+[A-Za-z0-9._~+/=-]+",
        r"\1 [REDACTED]",
        text,
    )
    redacted = re.sub(
        r"(?i)(^|[\s,;])((?:private-token|x-api-key|authorization|proxy-authorization|cookie|set-cookie|token|password|secret))\b\s*[:=]?\s*([^\s,;]+)",
        r"\1\2=[REDACTED]",
        redacted,
    )
    redacted = re.sub(
        r"(?i)([?&](?:private_token|access_token|token|api_key|password|secret)=)([^&#\s]+)",
        r"\1[REDACTED]",
        redacted,
    )
    for pattern, replacement in _REDACT_PATTERNS:
        redacted = pattern.sub(replacement, redacted)
    return redacted


def _sanitize_structured(value: Any, *, sensitive: bool = False) -> Any:
    """Return JSON-compatible data with sensitive-key values redacted.

    Container values beneath a sensitive key retain their topology while every
    scalar descendant is replaced. Non-sensitive free text is preserved so
    serialized JSON and tabular output remain valid and useful.
    """
    if isinstance(value, dict):
        return {
            key: _sanitize_structured(
                child,
                sensitive=sensitive or str(key).lower() in _REDACT_KEYS,
            )
            for key, child in value.items()
        }
    if isinstance(value, list):
        return [_sanitize_structured(item, sensitive=sensitive) for item in value]
    if sensitive:
        return "[REDACTED]"
    return value


def _preview_text(text: str, limit: int | None = None) -> str:
    """Cap preview output while preserving the full preview marker."""
    if limit is None:
        limit = MAX_BODY_BYTES
    if len(text) <= limit:
        return text
    return text[:limit] + "\n... [truncated]"


def _normalize_base_url(value: str) -> str:
    """Return an origin-only GitLab base URL."""
    if not value:
        raise ValueError("GITLAB_URL is not set")
    if any(ord(char) < 32 or ord(char) == 127 for char in value):
        raise ValueError(
            "GITLAB_URL must be an origin-only URL without control characters"
        )

    parsed_url = urllib.parse.urlsplit(value)
    if parsed_url.scheme not in {"http", "https"}:
        raise ValueError(
            "GITLAB_URL must start with https:// (or http:// for local dev)"
        )
    if parsed_url.username or parsed_url.password:
        raise ValueError("GITLAB_URL must be an origin-only URL without userinfo")
    if parsed_url.query or parsed_url.fragment:
        raise ValueError(
            "GITLAB_URL must be an origin-only URL without query or fragment"
        )
    if parsed_url.path not in {"", "/"}:
        raise ValueError("GITLAB_URL must be an origin-only URL without a path")
    if not parsed_url.hostname:
        raise ValueError("GITLAB_URL must include a hostname")

    return urllib.parse.urlunsplit((parsed_url.scheme, parsed_url.netloc, "", "", ""))


def _is_loopback(host: str | None) -> bool:
    """Return True when a URL host is loopback-only."""
    if not host:
        return False
    host = host.lower()
    return host in {"localhost", "127.0.0.1", "::1"} or host.startswith("127.")


def _sanitize_remote_url(remote_url: str) -> str:
    """Strip any embedded credentials from a git remote URL for logging."""
    pattern = re.compile(
        r"^(?P<scheme>https?://)(?P<user>[^/@]+)(?::(?P<password>[^@/]+))?@"
    )
    return pattern.sub(r"\g<scheme>", remote_url)


def _validate_project_path(path: str) -> None:
    """Reject project paths that contain traversal or separator escapes."""
    if not path:
        raise GitLabError("invalid project path", EXIT_USAGE)
    if any(char in path for char in {"%", "\\"}):
        raise GitLabError("invalid project path", EXIT_USAGE)

    for segment in path.split("/"):
        if segment in {"", ".", ".."}:
            raise GitLabError("invalid project path", EXIT_USAGE)


def _summarize_error_body(raw_error: str) -> str:
    """Prefer a structured message and otherwise return a redacted preview."""
    try:
        parsed_error = json.loads(raw_error)
    except (json.JSONDecodeError, ValueError):
        return _preview_text(_redact(raw_error))

    if isinstance(parsed_error, dict):
        message = parsed_error.get("message") or parsed_error.get("error")
        if isinstance(message, str) and message.strip():
            return _preview_text(_redact(message))

    return _preview_text(_redact(raw_error))


def _audit_write(event: dict[str, Any]) -> bool:
    """Append one audit event as a JSON line when auditing is enabled.

    Returns:
        True when an event was written, False when auditing is disabled.

    Raises:
        OSError: The audit log path is set but cannot be written.
    """
    path = os.environ.get("GITLAB_AUDIT_LOG", "").strip()
    if not path:
        return False
    # Redact per value rather than trusting each call site to redact its own
    # fields. Redacting the serialized line instead would corrupt the JSON,
    # because the bare form-shape rule consumes the closing quote and comma.
    record = {
        key: _redact(value) if isinstance(value, str) else value
        for key, value in _sanitize_structured(event).items()
    }
    with open(path, "a", encoding="utf-8") as handle:
        handle.write(json.dumps(record) + "\n")
    return True


def _audit_event(actor: str, method: str, resource: str, event: str) -> dict[str, Any]:
    """Build a base audit event record with the query string stripped."""
    parsed = urllib.parse.urlsplit(resource)
    return {
        "ts": datetime.now(timezone.utc).isoformat(),
        "skill": "gitlab",
        "actor": actor,
        "op": _AUDIT_OP,
        "method": method,
        "origin": urllib.parse.urlunsplit((parsed.scheme, parsed.netloc, "", "", "")),
        "auth_mode": auth_context.mode if auth_context is not None else "unknown",
        "event": event,
    }


def _audit_attempt(actor: str, method: str, resource: str) -> None:
    """Write the write-ahead attempt record, failing closed when unwritable."""
    try:
        _audit_write(_audit_event(actor, method, resource, "attempt"))
    except OSError as exc:
        raise GitLabError(
            f"audit log write failed; refusing to proceed: {exc}", EXIT_FAILURE
        ) from exc


def _audit_outcome(
    actor: str,
    method: str,
    resource: str,
    outcome: str,
    *,
    status: int | None = None,
    error: str | None = None,
) -> None:
    """Write the post-operation outcome record (best-effort)."""
    record = _audit_event(actor, method, resource, "outcome")
    record["outcome"] = outcome
    if status is not None:
        record["status"] = status
    if error:
        record["error"] = _redact(error)
    try:
        _audit_write(record)
    except OSError as exc:
        _emit(f"warning: audit outcome write failed: {exc}", level=logging.WARNING)


def _oauth_audit_event(operation: str, event: str) -> dict[str, Any]:
    """Build one bounded OAuth lifecycle audit event."""
    if operation not in _OAUTH_AUDIT_OPERATIONS or event not in {"attempt", "outcome"}:
        raise ValueError("invalid OAuth audit event")
    return {
        "ts": datetime.now(timezone.utc).isoformat(),
        "skill": "gitlab",
        "transport": "oauth",
        "auth_mode": "oauth",
        "operation": operation,
        "event": event,
    }


def _oauth_audit_attempt(operation: str) -> None:
    """Write an OAuth attempt before egress, failing closed when configured."""
    try:
        _audit_write(_oauth_audit_event(operation, "attempt"))
    except OSError as exc:
        raise GitLabError(
            "audit log write failed; refusing OAuth request", EXIT_FAILURE
        ) from exc


def _oauth_audit_outcome(
    operation: str,
    outcome: str,
    status: int | None,
    failure_kind: str | None,
) -> None:
    """Write one bounded OAuth outcome without changing exchange behavior."""
    record = _oauth_audit_event(operation, "outcome")
    record["outcome"] = outcome
    if status is not None:
        record["status"] = status
    if failure_kind is not None:
        if failure_kind not in _OAUTH_FAILURE_KINDS:
            failure_kind = "unknown"
        record["failure_kind"] = failure_kind
    try:
        _audit_write(record)
    except OSError:
        _emit("warning: OAuth audit outcome write failed", level=logging.WARNING)


def require_base_environment() -> None:
    """Load and validate the GitLab instance before credential access."""
    global api_url
    global gitlab_url

    gitlab_url = os.environ.get("GITLAB_URL", "")
    if not gitlab_url:
        raise GitLabError("GITLAB_URL is not set", EXIT_USAGE)
    try:
        gitlab_url = _normalize_base_url(gitlab_url)
    except ValueError as error:
        raise GitLabError(str(error), EXIT_USAGE) from error
    parsed_url = urllib.parse.urlsplit(gitlab_url)
    if parsed_url.scheme == "http":
        allow_insecure = os.environ.get("GITLAB_ALLOW_INSECURE", "").strip() == "1"
        if not _is_loopback(parsed_url.hostname) or not allow_insecure:
            raise GitLabError(
                "GITLAB_URL must use https:// for non-loopback hosts; "
                "plaintext http is allowed only for loopback hosts when "
                "GITLAB_ALLOW_INSECURE=1",
                EXIT_USAGE,
            )
    api_url = gitlab_url + "/api/v4"


def require_environment() -> None:
    """Load and validate required environment variables."""
    global api_url
    global auth_context
    global audit_actor
    global gitlab_url

    require_base_environment()
    configured_mode = os.environ.get("GITLAB_AUTH_MODE")
    mode = configured_mode.strip() if configured_mode is not None else "oauth"
    if not mode:
        mode = "oauth"
    if mode not in {"oauth", "legacy-token"}:
        raise GitLabError("GITLAB_AUTH_MODE must be oauth or legacy-token", EXIT_USAGE)
    configured_token = os.environ.get("GITLAB_TOKEN", "")
    if mode == "legacy-token":
        if not configured_token:
            raise GitLabError(
                "GITLAB_TOKEN is not set for legacy-token mode", EXIT_USAGE
            )
        auth_context = AuthContext(mode=mode, issuer=gitlab_url, token=configured_token)
    else:
        if configured_token:
            raise GitLabError("GITLAB_TOKEN must not be set in oauth mode", EXIT_USAGE)
        client_id = os.environ.get("GITLAB_OAUTH_CLIENT_ID", "").strip()
        if not client_id:
            raise GitLabError(
                "GITLAB_OAUTH_CLIENT_ID is not set. Configure OAuth and run "
                "auth login, or explicitly set GITLAB_AUTH_MODE=legacy-token "
                "with GITLAB_TOKEN",
                EXIT_USAGE,
            )
        try:
            profile_name = credentials.resolve_profile_name(None, os.environ)
            store_path = credentials.resolve_store_path(os.environ)
            store = credentials.load_store(store_path)
            profile = credentials.get_profile(store, profile_name)
        except credentials.CredentialError as exc:
            raise GitLabError(str(exc), EXIT_USAGE) from exc
        if profile["issuer"] != gitlab_url or profile["client_id"] != client_id:
            raise GitLabError(
                "GitLab OAuth profile does not match this instance and client ID",
                EXIT_USAGE,
            )
        if not profile["usable"]:
            raise GitLabError(
                "GitLab OAuth profile is unusable; run auth login", EXIT_USAGE
            )
        auth_context = AuthContext(
            mode=mode,
            issuer=gitlab_url,
            profile_name=profile_name,
            store_path=store_path,
            client_id=client_id,
        )
    default_actor = "gitlab-token" if mode == "legacy-token" else "oauth"
    audit_actor = os.environ.get("GITLAB_AUDIT_ACTOR", "").strip() or default_actor


def _oauth_profile(context: AuthContext) -> credentials.Profile:
    """Return a current OAuth profile, refreshing within the expiry leeway."""
    if context.store_path is None or context.profile_name is None:
        raise GitLabError("GitLab OAuth context is incomplete", EXIT_FAILURE)
    try:
        with credentials.store_lock(context.store_path):
            store = credentials.load_store(context.store_path)
            profile = credentials.get_profile(store, context.profile_name)
            _assert_profile_binding(context, profile)
            expires_at = int(profile["expires_at"])
            current_time = int(datetime.now(timezone.utc).timestamp())
            if expires_at - oauth.REFRESH_LEEWAY_SECONDS <= current_time:
                if not profile["refresh_token"]:
                    profile["usable"] = False
                    credentials.set_profile(store, context.profile_name, profile)
                    credentials.save_store(context.store_path, store)
                    raise GitLabError(
                        "GitLab device access token expired; run auth device-login",
                        EXIT_FAILURE,
                    )
                previous_profile = credentials.Profile(**profile)
                profile["usable"] = False
                credentials.set_profile(store, context.profile_name, profile)
                credentials.save_store(context.store_path, store)
                try:
                    replacement = oauth.refresh_profile(
                        profile,
                        expected_issuer=context.issuer,
                        expected_client_id=_required_oauth_client_id(context),
                        opener=_OPENER.open,
                        timeout=REQUEST_TIMEOUT,
                        audit_attempt=_oauth_audit_attempt,
                        audit_outcome=_oauth_audit_outcome,
                    )
                except oauth.OAuthError as exc:
                    if _refresh_error_can_restore_profile(exc):
                        previous_profile["usable"] = True
                        credentials.set_profile(
                            store,
                            context.profile_name,
                            previous_profile,
                        )
                        credentials.save_store(context.store_path, store)
                        raise GitLabError(
                            "GitLab OAuth refresh could not complete; the stored "
                            f"credential remains available for retry: {exc}",
                            EXIT_FAILURE,
                        ) from exc
                    profile["usable"] = False
                    credentials.set_profile(store, context.profile_name, profile)
                    credentials.save_store(context.store_path, store)
                    raise GitLabError(
                        f"GitLab OAuth refresh failed; re-login required: {exc}",
                        EXIT_FAILURE,
                    ) from exc
                credentials.set_profile(store, context.profile_name, replacement)
                credentials.save_store(context.store_path, store)
                profile = replacement
            return profile
    except credentials.CredentialError as exc:
        raise GitLabError(str(exc), EXIT_FAILURE) from exc


def _auth_headers() -> dict[str, str]:
    """Return the header for the resolved authentication mode."""
    if auth_context is None:
        raise GitLabError("GitLab authentication is not configured", EXIT_FAILURE)
    if auth_context.mode == "legacy-token":
        return {"PRIVATE-TOKEN": str(auth_context.token)}
    profile = _oauth_profile(auth_context)
    return {"Authorization": f"Bearer {profile['access_token']}"}


def _required_oauth_client_id(context: AuthContext) -> str:
    """Return the trusted OAuth client ID or fail on an incomplete context."""
    if not context.client_id:
        raise GitLabError("GitLab OAuth context is missing a client ID", EXIT_FAILURE)
    return context.client_id


def _assert_profile_binding(
    context: AuthContext,
    profile: dict[str, Any],
) -> None:
    """Reject a locked profile reload that no longer matches trusted context."""
    if profile["issuer"] != context.issuer or profile[
        "client_id"
    ] != _required_oauth_client_id(context):
        raise GitLabError(
            "GitLab OAuth profile changed and no longer matches this instance",
            EXIT_FAILURE,
        )


def _refresh_error_can_restore_profile(error: oauth.OAuthError) -> bool:
    """Return whether refresh conclusively left the provider token unchanged."""
    return error.retryable and not error.completion_uncertain


def _force_oauth_refresh(context: AuthContext) -> credentials.Profile:
    """Refresh one OAuth profile after a safe API request returns 401."""
    if context.store_path is None or context.profile_name is None:
        raise GitLabError("GitLab OAuth context is incomplete", EXIT_FAILURE)
    try:
        with credentials.store_lock(context.store_path):
            store = credentials.load_store(context.store_path)
            profile = credentials.get_profile(store, context.profile_name)
            _assert_profile_binding(context, profile)
            if not profile["refresh_token"]:
                profile["usable"] = False
                credentials.set_profile(store, context.profile_name, profile)
                credentials.save_store(context.store_path, store)
                raise GitLabError(
                    "GitLab OAuth profile cannot refresh; re-login required"
                )
            previous_profile = credentials.Profile(**profile)
            profile["usable"] = False
            credentials.set_profile(store, context.profile_name, profile)
            credentials.save_store(context.store_path, store)
            try:
                replacement = oauth.refresh_profile(
                    profile,
                    expected_issuer=context.issuer,
                    expected_client_id=_required_oauth_client_id(context),
                    opener=_OPENER.open,
                    timeout=REQUEST_TIMEOUT,
                    audit_attempt=_oauth_audit_attempt,
                    audit_outcome=_oauth_audit_outcome,
                )
            except oauth.OAuthError as exc:
                if _refresh_error_can_restore_profile(exc):
                    previous_profile["usable"] = True
                    credentials.set_profile(
                        store,
                        context.profile_name,
                        previous_profile,
                    )
                    credentials.save_store(context.store_path, store)
                    raise GitLabError(
                        "GitLab OAuth refresh could not complete; the stored "
                        f"credential remains available for retry: {exc}",
                        EXIT_FAILURE,
                    ) from exc
                profile["usable"] = False
                credentials.set_profile(store, context.profile_name, profile)
                credentials.save_store(context.store_path, store)
                raise GitLabError(
                    f"GitLab OAuth refresh failed; re-login required: {exc}",
                    EXIT_FAILURE,
                ) from exc
            credentials.set_profile(store, context.profile_name, replacement)
            credentials.save_store(context.store_path, store)
            return replacement
    except credentials.CredentialError as exc:
        raise GitLabError(str(exc), EXIT_FAILURE) from exc


def strip_git_suffix(path: str) -> str:
    """Remove a trailing .git suffix when present."""
    if path.endswith(".git"):
        return path[:-4]
    return path


def project() -> str:
    """Resolve the target GitLab project from environment or git remote."""
    configured_project = os.environ.get("GITLAB_PROJECT", "")
    if configured_project:
        _validate_project_path(configured_project)
        return urllib.parse.quote(configured_project, safe="")

    try:
        remote_url = subprocess.check_output(
            ["git", "remote", "get-url", "origin"],
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=REQUEST_TIMEOUT,
        ).strip()
    except subprocess.TimeoutExpired as exc:
        raise GitLabError(
            "timed out resolving git remote for project", EXIT_FAILURE
        ) from exc
    except (subprocess.CalledProcessError, FileNotFoundError) as exc:
        raise GitLabError(
            "GITLAB_PROJECT not set and no git remote found", EXIT_USAGE
        ) from exc

    sanitized_remote_url = _sanitize_remote_url(remote_url)
    if remote_url.startswith("git@"):
        path = remote_url.split(":", 1)[1]
    elif re.match(r"^https?://", remote_url):
        parsed_remote = urllib.parse.urlsplit(remote_url)
        path = parsed_remote.path.lstrip("/")
    else:
        raise GitLabError(
            f"cannot parse git remote URL: {sanitized_remote_url}", EXIT_USAGE
        )

    path = strip_git_suffix(path)
    if not path:
        raise GitLabError(
            f"cannot extract project path from remote: {sanitized_remote_url}",
            EXIT_USAGE,
        )
    _validate_project_path(path)
    return urllib.parse.quote(path, safe="")


def validate_numeric_id(value: str) -> None:
    """Validate that a CLI argument is a numeric identifier."""
    if not re.fullmatch(r"\d+", value):
        raise GitLabError(f"expected numeric ID, got: {value}", EXIT_USAGE)
    numeric_value = int(value)
    if numeric_value <= 0 or numeric_value > MAX_NUMERIC_ID:
        raise GitLabError(
            f"expected numeric ID between 1 and {MAX_NUMERIC_ID}, got: {value}",
            EXIT_USAGE,
        )


def validate_positive_int(
    value: str,
    label: str = "value",
    upper_bound: int = MAX_POSITIVE_INT,
) -> None:
    """Validate that a CLI argument is a positive integer string."""
    if not re.fullmatch(r"\d+", value):
        raise GitLabError(
            f"{label} must be a positive integer, got: {value}", EXIT_USAGE
        )
    numeric_value = int(value)
    if numeric_value <= 0 or numeric_value > upper_bound:
        raise GitLabError(
            f"{label} must be a positive integer between 1 and "
            f"{upper_bound}, got: {value}",
            EXIT_USAGE,
        )


def validate_state(value: str) -> None:
    """Validate that a merge request state is allowed."""
    if value not in VALID_MR_STATES:
        raise GitLabError(f"invalid merge request state: {value}", EXIT_USAGE)


def validate_ref(value: str) -> None:
    """Validate that a pipeline ref matches the supported pattern."""
    if not REF_PATTERN.fullmatch(value):
        raise GitLabError(f"invalid ref: {value}", EXIT_USAGE)


def _read_capped(response: Any, limit: int, *, fail_on_limit: bool = True) -> bytes:
    """Read up to the limit and optionally reject oversized bodies."""
    chunk = response.read(limit + 1)
    if chunk is None:
        return b""
    if len(chunk) > limit and fail_on_limit:
        raise GitLabError("response body exceeds size limit", EXIT_FAILURE)
    return chunk[:limit]


def _request_bytes(
    method: str,
    url: str,
    *,
    headers: dict[str, str] | None = None,
    data: object | None = None,
    require_json: bool = True,
    error_context: str | None = None,
) -> bytes:
    """Issue an HTTP request through the hardened transport."""
    request_headers = {"Accept": "application/json"}
    if headers:
        request_headers.update(headers)
    if data is not None:
        body = json.dumps(data).encode("utf-8")
    else:
        body = None
    refreshed_after_401 = False
    while True:
        request_obj = urllib.request.Request(
            url, data=body, headers=request_headers, method=method
        )
        _audit_attempt(audit_actor, method, url)
        try:
            with _OPENER.open(request_obj, timeout=REQUEST_TIMEOUT) as response:
                content_type = ""
                if hasattr(response, "headers"):
                    content_type = str(response.headers.get("Content-Type", "") or "")
                try:
                    result = _read_capped(
                        response,
                        MAX_BODY_BYTES,
                        fail_on_limit=require_json,
                    )
                except GitLabError as error:
                    raise GitLabAPIError(
                        method=method,
                        resource=_scrub_url(url),
                        message=str(error),
                        request_id=_response_request_id(response),
                    ) from error
                if require_json and result.strip():
                    if not content_type:
                        raise GitLabAPIError(
                            method=method,
                            resource=_scrub_url(url),
                            message="unexpected Content-Type: <missing>",
                            request_id=_response_request_id(response),
                        )
                    if not content_type.lower().startswith("application/json"):
                        raise GitLabAPIError(
                            method=method,
                            resource=_scrub_url(url),
                            message=f"unexpected Content-Type: {content_type}",
                            request_id=_response_request_id(response),
                        )
                _audit_outcome(audit_actor, method, url, "success")
                return result
        except urllib.error.HTTPError as error:
            body_bytes = _read_capped(error, MAX_BODY_BYTES, fail_on_limit=False)
            raw_error = body_bytes.decode("utf-8", errors="replace")
            if (
                error.code == 401
                and method.upper() in {"GET", "HEAD"}
                and not refreshed_after_401
                and auth_context is not None
                and auth_context.mode == "oauth"
            ):
                _audit_outcome(
                    audit_actor,
                    method,
                    url,
                    "error",
                    status=error.code,
                    error="OAuth access token rejected; refreshing once",
                )
                replacement = _force_oauth_refresh(auth_context)
                request_headers["Authorization"] = (
                    f"Bearer {replacement['access_token']}"
                )
                refreshed_after_401 = True
                continue
            _audit_outcome(
                audit_actor, method, url, "error", status=error.code, error=raw_error
            )
            detail = _summarize_error_body(raw_error).strip()
            if error_context:
                detail = f"{error_context}{'; ' + detail if detail else ''}"
            if error.code in {401, 403}:
                if auth_context is not None and auth_context.mode == "legacy-token":
                    hint = (
                        "the credential may be expired or revoked; rotate GITLAB_TOKEN"
                    )
                else:
                    hint = "OAuth authorization may be expired or revoked; re-login"
                detail = f"{detail}; {hint}" if detail else hint
            raise GitLabAPIError(
                status=error.code,
                method=method,
                resource=_scrub_url(url),
                message=detail,
                request_id=_response_request_id(error),
            ) from error


def request(
    method: str,
    url: str,
    data: object | None = None,
    quiet: bool = False,
) -> object | None:
    """Issue an HTTP request to the GitLab API.

    Args:
        method: HTTP method.
        url: Fully qualified request URL.
        data: Optional JSON-serializable payload.
        quiet: When True, suppress pretty-printed JSON output.

    Returns:
        Parsed JSON content, or None for empty or non-JSON responses.
    """
    headers = {
        **_auth_headers(),
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    raw_bytes = _request_bytes(
        method,
        url,
        headers=headers,
        data=data,
        require_json=False,
    )
    raw = raw_bytes.decode("utf-8", errors="replace")

    if not raw.strip():
        return None

    try:
        parsed = json.loads(raw)
    except (json.JSONDecodeError, ValueError):
        _emit_stdout(_preview_text(_redact(raw)))
        return None

    if not quiet:
        _emit_structured_stdout(json.dumps(_sanitize_structured(parsed), indent=2))
    return parsed


def parse_fields(arguments: list[str]) -> list[str]:
    """Extract the optional --fields argument from the CLI."""
    global selected_fields

    cleaned_arguments: list[str] = []
    index = 0
    while index < len(arguments):
        current = arguments[index]
        if current == "--fields":
            if index + 1 >= len(arguments):
                raise GitLabError(
                    "usage: --fields requires a comma-separated value list", EXIT_USAGE
                )
            selected_fields = arguments[index + 1].split(",")
            index += 2
            continue
        cleaned_arguments.append(current)
        index += 1
    return cleaned_arguments


def extract_field(obj: Any, path: str) -> str:
    """Extract a value using dot notation such as author.name."""
    current = obj
    for part in path.split("."):
        if isinstance(current, dict):
            current_dict = cast(dict[str, Any], current)
            current = current_dict.get(part)
        else:
            return ""

    if current is None:
        return ""
    if isinstance(current, list):
        current_list = cast(list[Any], current)
        return ", ".join(str(item) for item in current_list)
    return str(cast(object, current))


def print_fields(data: Any) -> None:
    """Print extracted fields for a list response or a single object."""
    if not selected_fields:
        return

    sanitized = _sanitize_structured(data)
    if isinstance(sanitized, list):
        _emit_structured_stdout("\t".join(selected_fields))
        for item in cast(list[Any], sanitized):
            _emit_structured_stdout(
                "\t".join(
                    extract_field(item, field_name) for field_name in selected_fields
                )
            )
        return

    for field_name in selected_fields:
        _emit_structured_stdout(f"{field_name}: {extract_field(sanitized, field_name)}")


def load_json_payload(raw_payload: str, usage: str) -> object:
    """Parse a JSON payload or stop with a usage error."""
    try:
        return json.loads(raw_payload)
    except json.JSONDecodeError as error:
        raise GitLabError(
            f"invalid JSON payload: {error.msg}. {usage}", EXIT_USAGE
        ) from error


def cmd_mr_list(args: list[str]) -> None:
    """List merge requests."""
    state = args[0] if args else "all"
    validate_state(state)
    max_results = args[1] if len(args) > 1 else "20"
    validate_positive_int(max_results, "max_results", MAX_POSITIVE_INT)
    data = request(
        "GET",
        f"{api_url}/projects/{project()}/merge_requests?state={state}&per_page={max_results}&order_by=created_at&sort=desc",
        quiet=bool(selected_fields),
    )
    if selected_fields and data is not None:
        print_fields(data)


def cmd_mr_get(args: list[str]) -> None:
    """Get one merge request."""
    if not args:
        raise GitLabError("usage: gitlab mr-get <mr-iid>", EXIT_USAGE)
    merge_request_iid = args[0]
    validate_numeric_id(merge_request_iid)
    data = request(
        "GET",
        f"{api_url}/projects/{project()}/merge_requests/{merge_request_iid}",
        quiet=bool(selected_fields),
    )
    if selected_fields and data is not None:
        print_fields(data)


def cmd_mr_create(args: list[str]) -> None:
    """Create a merge request from JSON input."""
    raw_payload = args[0] if args else sys.stdin.read(MAX_BODY_BYTES + 1)
    if not args and len(raw_payload) > MAX_BODY_BYTES:
        raise GitLabError("request body exceeds size limit", EXIT_FAILURE)
    raw_payload = raw_payload.strip()
    usage = "usage: gitlab mr-create <json> or pipe JSON to stdin"
    if not raw_payload:
        raise GitLabError(usage, EXIT_USAGE)
    request(
        "POST",
        f"{api_url}/projects/{project()}/merge_requests",
        load_json_payload(raw_payload, usage),
    )


def cmd_mr_update(args: list[str]) -> None:
    """Update a merge request from JSON input."""
    if not args:
        raise GitLabError("usage: gitlab mr-update <mr-iid> <json>", EXIT_USAGE)
    merge_request_iid = args[0]
    validate_numeric_id(merge_request_iid)
    raw_payload = args[1] if len(args) > 1 else sys.stdin.read(MAX_BODY_BYTES + 1)
    if len(args) <= 1 and len(raw_payload) > MAX_BODY_BYTES:
        raise GitLabError("request body exceeds size limit", EXIT_FAILURE)
    raw_payload = raw_payload.strip()
    usage = "usage: gitlab mr-update <mr-iid> <json> or pipe JSON to stdin"
    if not raw_payload:
        raise GitLabError(usage, EXIT_USAGE)
    request(
        "PUT",
        f"{api_url}/projects/{project()}/merge_requests/{merge_request_iid}",
        load_json_payload(raw_payload, usage),
    )


def cmd_mr_comment(args: list[str]) -> None:
    """Create a merge request note."""
    if not args:
        raise GitLabError("usage: gitlab mr-comment <mr-iid> <body>", EXIT_USAGE)
    merge_request_iid = args[0]
    validate_numeric_id(merge_request_iid)
    body = args[1] if len(args) > 1 else sys.stdin.read(MAX_BODY_BYTES + 1)
    if len(args) <= 1 and len(body) > MAX_BODY_BYTES:
        raise GitLabError("request body exceeds size limit", EXIT_FAILURE)
    body = body.strip()
    if not body:
        raise GitLabError(
            "usage: gitlab mr-comment <mr-iid> <body> or pipe body to stdin",
            EXIT_USAGE,
        )
    request(
        "POST",
        f"{api_url}/projects/{project()}/merge_requests/{merge_request_iid}/notes",
        {"body": body},
    )


def cmd_mr_notes(args: list[str]) -> None:
    """List merge request notes."""
    if not args:
        raise GitLabError("usage: gitlab mr-notes <mr-iid> [max]", EXIT_USAGE)
    merge_request_iid = args[0]
    validate_numeric_id(merge_request_iid)
    max_results = args[1] if len(args) > 1 else "100"
    validate_positive_int(max_results, "max_results", MAX_POSITIVE_INT)
    data = request(
        "GET",
        f"{api_url}/projects/{project()}/merge_requests/{merge_request_iid}/notes?per_page={max_results}&sort=asc",
        quiet=bool(selected_fields),
    )
    if selected_fields and isinstance(data, list):
        notes = [
            cast(dict[str, Any], note)
            for note in cast(list[Any], data)
            if isinstance(note, dict)
            and not cast(dict[str, Any], note).get("system", False)
        ]
        print_fields(notes)


def cmd_pipeline_get(args: list[str]) -> None:
    """Get one pipeline."""
    if not args:
        raise GitLabError("usage: gitlab pipeline-get <pipeline-id>", EXIT_USAGE)
    pipeline_id = args[0]
    validate_numeric_id(pipeline_id)
    data = request(
        "GET",
        f"{api_url}/projects/{project()}/pipelines/{pipeline_id}",
        quiet=bool(selected_fields),
    )
    if selected_fields and data is not None:
        print_fields(data)


def cmd_pipeline_run(args: list[str]) -> None:
    """Trigger a pipeline for a branch or tag."""
    if not args:
        raise GitLabError("usage: gitlab pipeline-run <branch-or-tag>", EXIT_USAGE)
    validate_ref(args[0])
    request("POST", f"{api_url}/projects/{project()}/pipelines", {"ref": args[0]})


def cmd_pipeline_jobs(args: list[str]) -> None:
    """List pipeline jobs."""
    if not args:
        raise GitLabError("usage: gitlab pipeline-jobs <pipeline-id>", EXIT_USAGE)
    pipeline_id = args[0]
    validate_numeric_id(pipeline_id)
    data = request(
        "GET",
        f"{api_url}/projects/{project()}/pipelines/{pipeline_id}/jobs",
        quiet=bool(selected_fields),
    )
    if selected_fields and data is not None:
        print_fields(data)


def cmd_job_log(args: list[str]) -> None:
    """Print raw job trace output."""
    if not args:
        raise GitLabError("usage: gitlab job-log <job-id>", EXIT_USAGE)
    job_id = args[0]
    validate_numeric_id(job_id)
    url = f"{api_url}/projects/{project()}/jobs/{job_id}/trace"
    raw_bytes = _request_bytes(
        "GET",
        url,
        headers=_auth_headers(),
        require_json=False,
        error_context="fetching job log",
    )
    log_text = _redact(raw_bytes.decode("utf-8", errors="replace"))
    if len(log_text) > MAX_LOG_BYTES:
        log_text = log_text[:MAX_LOG_BYTES] + "\n... [truncated]"
    _emit_stdout(log_text, end="")


COMMANDS: dict[str, Callable[[list[str]], None]] = {
    "mr-list": cmd_mr_list,
    "mr-get": cmd_mr_get,
    "mr-create": cmd_mr_create,
    "mr-update": cmd_mr_update,
    "mr-comment": cmd_mr_comment,
    "mr-notes": cmd_mr_notes,
    "pipeline-get": cmd_pipeline_get,
    "pipeline-run": cmd_pipeline_run,
    "pipeline-jobs": cmd_pipeline_jobs,
    "job-log": cmd_job_log,
}


def _auth_configuration() -> tuple[str, pathlib.Path, str]:
    """Resolve OAuth settings after rejecting mixed or legacy configuration."""
    configured_mode = os.environ.get("GITLAB_AUTH_MODE", "oauth").strip() or "oauth"
    if configured_mode != "oauth":
        raise GitLabError("auth commands require GITLAB_AUTH_MODE=oauth", EXIT_USAGE)
    if os.environ.get("GITLAB_TOKEN", ""):
        raise GitLabError(
            "GITLAB_TOKEN must not be set for OAuth auth commands", EXIT_USAGE
        )
    global audit_actor
    require_base_environment()
    client_id = os.environ.get("GITLAB_OAUTH_CLIENT_ID", "").strip()
    if not client_id:
        raise GitLabError("GITLAB_OAUTH_CLIENT_ID is not set", EXIT_USAGE)
    try:
        profile_name = credentials.resolve_profile_name(None, os.environ)
        store_path = credentials.resolve_store_path(os.environ)
    except credentials.CredentialError as exc:
        raise GitLabError(str(exc), EXIT_USAGE) from exc
    audit_actor = os.environ.get("GITLAB_AUDIT_ACTOR", "").strip() or "oauth"
    return profile_name, store_path, client_id


def _save_auth_profile(
    profile_name: str,
    store_path: pathlib.Path,
    profile: credentials.Profile,
) -> None:
    """Persist one authenticated profile under the cross-process store lock."""
    try:
        with credentials.store_lock(store_path):
            store = credentials.load_store(store_path)
            credentials.set_profile(store, profile_name, profile)
            credentials.save_store(store_path, store)
    except credentials.CredentialError as exc:
        raise GitLabError(str(exc), EXIT_FAILURE) from exc


def cmd_auth_login(args: list[str]) -> None:
    """Authenticate interactively through public-client PKCE."""
    if args:
        raise GitLabError("usage: gitlab auth login", EXIT_USAGE)
    profile_name, store_path, client_id = _auth_configuration()
    try:
        profile = oauth.authorization_code_login(
            gitlab_url,
            client_id,
            opener=_OPENER.open,
            timeout=300,
            emit_authorize_url=lambda url: _emit_stdout(
                f"Open {url} to authorize this GitLab CLI"
            ),
            audit_attempt=_oauth_audit_attempt,
            audit_outcome=_oauth_audit_outcome,
        )
    except oauth.OAuthError as exc:
        raise GitLabError(_redact(str(exc)), EXIT_FAILURE) from None
    _save_auth_profile(profile_name, store_path, profile)
    _emit_stdout(f"authenticated GitLab OAuth profile {profile_name}")


def cmd_auth_device_login(args: list[str]) -> None:
    """Authenticate through human-assisted Device Authorization Grant."""
    if args:
        raise GitLabError("usage: gitlab auth device-login", EXIT_USAGE)
    profile_name, store_path, client_id = _auth_configuration()

    def emit(uri: str, code: str) -> None:
        _emit_stdout(f"Open {uri} and enter code {code}")

    try:
        profile = oauth.device_login(
            gitlab_url,
            client_id,
            opener=_OPENER.open,
            timeout=300,
            emit_instructions=emit,
            audit_attempt=_oauth_audit_attempt,
            audit_outcome=_oauth_audit_outcome,
        )
    except oauth.OAuthError as exc:
        raise GitLabError(_redact(str(exc)), EXIT_FAILURE) from None
    _save_auth_profile(profile_name, store_path, profile)
    _emit_stdout(f"authenticated GitLab OAuth profile {profile_name}")


def cmd_auth_status(args: list[str]) -> None:
    """Print secret-free OAuth profile status."""
    if args:
        raise GitLabError("usage: gitlab auth status", EXIT_USAGE)
    profile_name, store_path, client_id = _auth_configuration()
    try:
        store = credentials.load_store(store_path)
        profile = credentials.get_profile(store, profile_name)
    except credentials.CredentialError as exc:
        raise GitLabError(str(exc), EXIT_FAILURE) from exc
    _emit_stdout(
        json.dumps(
            {
                "profile": profile_name,
                "issuer": profile["issuer"],
                "client_id_matches": profile["client_id"] == client_id,
                "expires_at": profile["expires_at"],
                "scopes": profile["scopes"],
                "usable": profile["usable"],
            },
            indent=2,
        )
    )


def cmd_auth_logout(args: list[str]) -> None:
    """Delete one local OAuth profile without claiming server revocation."""
    if args:
        raise GitLabError("usage: gitlab auth logout", EXIT_USAGE)
    profile_name, store_path, _client_id = _auth_configuration()
    try:
        with credentials.store_lock(store_path):
            store = credentials.load_store(store_path)
            removed = credentials.delete_profile(store, profile_name)
            credentials.save_store(store_path, store)
    except credentials.CredentialError as exc:
        raise GitLabError(str(exc), EXIT_FAILURE) from exc
    _emit_stdout(
        f"local profile {profile_name} {'removed' if removed else 'was absent'}; "
        "server authorization was not revoked"
    )


AUTH_COMMANDS: dict[str, Callable[[list[str]], None]] = {
    "login": cmd_auth_login,
    "device-login": cmd_auth_device_login,
    "status": cmd_auth_status,
    "logout": cmd_auth_logout,
}


def main() -> int:
    """Run the GitLab CLI."""
    try:
        arguments = parse_fields(sys.argv[1:])

        if arguments and arguments[0] == "auth":
            if selected_fields:
                raise GitLabError(
                    "--fields is not valid with auth commands", EXIT_USAGE
                )
            handler = AUTH_COMMANDS.get(arguments[1]) if len(arguments) >= 2 else None
            if handler is None:
                raise GitLabError(
                    "usage: gitlab auth {login|device-login|status|logout}", EXIT_USAGE
                )
            global _AUDIT_OP
            _AUDIT_OP = f"auth-{arguments[1]}"
            handler(arguments[2:])
            return EXIT_SUCCESS

        require_environment()

        if not arguments or arguments[0] not in COMMANDS:
            raise GitLabError(
                "usage: gitlab {mr-list|mr-get|mr-create|mr-update|mr-comment|"
                "auth|mr-notes|pipeline-get|pipeline-run|pipeline-jobs|job-log} "
                "[args...]",
                EXIT_USAGE,
            )

        _AUDIT_OP = arguments[0]
        COMMANDS[arguments[0]](arguments[1:])
        return EXIT_SUCCESS
    except GitLabError as exc:
        _emit_debug_traceback(exc)
        _emit(f"error: {exc}")
        return exc.exit_code
    except KeyboardInterrupt:
        _emit("Interrupted by user", level=logging.WARNING)
        return 130
    except BrokenPipeError:
        devnull_fd = os.open(os.devnull, os.O_WRONLY)
        os.dup2(devnull_fd, sys.stdout.fileno())
        os.close(devnull_fd)
        return 141
    except Exception as exc:  # noqa: BLE001 - terminal CLI boundary
        _emit_debug_traceback(exc)
        _emit("error: unexpected GitLab CLI failure")
        return EXIT_FAILURE


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
