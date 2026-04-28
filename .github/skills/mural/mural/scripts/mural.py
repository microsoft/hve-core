#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See LICENSE in the project root for details.
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Mural REST API client and (future) embedded MCP server.

Phase 2 surface: env-var resolution, token-store I/O, PKCE, the
``_authenticated_request`` transport with auto-refresh and 429 backoff, and the
loopback OAuth ``auth login`` / ``logout`` / ``status`` subcommands. Mural REST
resource subcommands (workspace, room, mural, widget) and the MCP stdio server
are introduced in later phases; the ``mcp`` subparser is declared here as a
stub that exits non-zero.

Runtime dependencies are stdlib-only. Test seams are exposed via private
parameters (``_http``, ``_now``, ``_open_browser``, ``_server_factory``) so
unit tests can substitute fakes without monkey-patching.
"""

from __future__ import annotations

import argparse
import base64
import binascii
import contextlib
import hashlib
import http.server
import json
import logging
import os
import pathlib
import re
import secrets
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
from dataclasses import dataclass
from typing import Any, Callable

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

MURAL_BASE_URL_DEFAULT = "https://app.mural.co/api/public/v1"
MURAL_AUTHORIZE_URL = "https://app.mural.co/api/public/v1/authorization/oauth2/"
MURAL_TOKEN_URL = "https://app.mural.co/api/public/v1/authorization/oauth2/token"

ENV_BASE_URL = "MURAL_BASE_URL"
ENV_CLIENT_ID = "MURAL_CLIENT_ID"
ENV_CLIENT_SECRET = "MURAL_CLIENT_SECRET"
ENV_REDIRECT_URI = "MURAL_REDIRECT_URI"
ENV_TOKEN_STORE = "MURAL_TOKEN_STORE"
ENV_DEFAULT_WORKSPACE = "MURAL_DEFAULT_WORKSPACE"
ENV_XDG_DATA_HOME = "XDG_DATA_HOME"

DEFAULT_SCOPES = (
    "identity:read workspaces:read rooms:read murals:read templates:read "
    "murals:write"
)

USER_AGENT = "hve-core-mural/1.0"

# Proactive client-side rate limit (Mural enforces ~60 req/min globally; we
# cap at 20 req/sec per process and back off on 429 regardless).
RATE_LIMIT_TOKENS_PER_SEC = 20.0
RATE_LIMIT_BUCKET_CAPACITY = 20.0

# 429 / transient retry policy.
MAX_RETRIES = 3
MAX_BACKOFF_SECONDS = 30.0

# Access tokens are refreshed if they expire within this many seconds.
REFRESH_LEEWAY_SECONDS = 60

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_USAGE = 2

# Patterns used by ``_redact``. Matches both JSON shapes and form/header
# shapes so log-line scrubbing works regardless of payload encoding.
_REDACT_KEYS = (
    "access_token",
    "refresh_token",
    "code_verifier",
    "code_challenge",
)
_REDACT_PATTERNS = [
    # JSON-style: "key": "value"
    (re.compile(rf'("{re.escape(k)}"\s*:\s*")([^"]*)(")'), r"\1***\3")
    for k in _REDACT_KEYS
]
_REDACT_PATTERNS.extend(
    [
        # form-style: key=value (until & or whitespace)
        (re.compile(rf"(\b{re.escape(k)}=)([^&\s]+)"), r"\1***")
        for k in (*_REDACT_KEYS, "code")
    ]
)
_REDACT_PATTERNS.append(
    (re.compile(r"(?i)(authorization\s*[:=]\s*)(bearer\s+)?(\S+)", re.IGNORECASE),
     r"\1\2***")
)
# Azure Blob SAS query strings (used for image uploads): scrub everything
# after the storage host's `?` so the `sig=` token is not logged.
_REDACT_PATTERNS.append(
    (re.compile(r"(\.blob\.core\.windows\.net/[^\s?]+\?)\S+"), r"\1***")
)

LOGGER = logging.getLogger("mural")


# ---------------------------------------------------------------------------
# Exceptions
# ---------------------------------------------------------------------------


class MuralError(Exception):
    """Base exception for Mural CLI errors."""


class MuralAPIError(MuralError):
    """Raised when Mural responds with a non-2xx status."""

    def __init__(
        self,
        status: int,
        code: str | None,
        message: str,
        request_id: str | None = None,
    ) -> None:
        super().__init__(message)
        self.status = status
        self.code = code
        self.message = message
        self.request_id = request_id

    def __str__(self) -> str:  # pragma: no cover - trivial formatting
        rid = f" request_id={self.request_id}" if self.request_id else ""
        code = f" code={self.code}" if self.code else ""
        return f"HTTP {self.status}{code}: {self.message}{rid}"


class MuralSecurityError(MuralError):
    """Raised when a security invariant is violated (e.g. unsafe redirect)."""


class MuralAmbiguousWorkspaceError(MuralError):
    """Raised when a workspace-scoped command is invoked without a selector."""

    def __init__(
        self,
        workspace_ids: list[str] | None = None,
        message: str | None = None,
    ) -> None:
        self.workspace_ids = list(workspace_ids or [])
        if message is None:
            available = (
                ", ".join(self.workspace_ids)
                if self.workspace_ids
                else "unknown"
            )
            message = (
                "multiple workspaces available; pass --workspace <id> or set "
                f"{ENV_DEFAULT_WORKSPACE} (available: {available})"
            )
        super().__init__(message)


class MuralValidationError(MuralError):
    """Raised when client-side validation rejects user input before any HTTP call."""


class MCPProtocolError(Exception):
    """Frame- or transport-level MCP error (maps to JSON-RPC code -32700)."""


class MCPInvalidParamsError(Exception):
    """Schema or parameter validation error (maps to JSON-RPC code -32602).

    The ``path`` attribute points to the offending location using a
    dotted/JSON-pointer-ish notation (e.g. ``$.arguments.mural``).
    """

    def __init__(self, message: str, path: str = "$") -> None:
        super().__init__(message)
        self.message = message
        self.path = path


# ---------------------------------------------------------------------------
# Step 2.1 — Env-var resolution, token-store I/O, PKCE helpers
# ---------------------------------------------------------------------------


def _resolve_token_store_path(env: dict[str, str] | None = None) -> pathlib.Path:
    """Return the on-disk token store path.

    Precedence: ``MURAL_TOKEN_STORE`` env var > ``$XDG_DATA_HOME/hve-core`` >
    ``~/.local/share/hve-core``.
    """
    src = env if env is not None else os.environ
    explicit = src.get(ENV_TOKEN_STORE)
    if explicit:
        return pathlib.Path(explicit).expanduser()
    xdg = src.get(ENV_XDG_DATA_HOME)
    if xdg:
        base = pathlib.Path(xdg).expanduser()
    else:
        base = pathlib.Path.home() / ".local" / "share"
    return base / "hve-core" / "mural-token.json"


def _load_token_store(path: pathlib.Path) -> dict[str, Any] | None:
    """Load a token store from disk, returning ``None`` when absent."""
    try:
        raw = path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return None
    except OSError as exc:
        raise MuralError(f"cannot read token store at {path}: {exc}") from exc
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise MuralError(f"token store at {path} is not valid JSON: {exc}") from exc
    if not isinstance(data, dict):
        raise MuralError(f"token store at {path} is not a JSON object")
    return data


def _save_token_store(path: pathlib.Path, data: dict[str, Any]) -> None:
    """Persist a token store atomically with mode 0600."""
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(data, indent=2, sort_keys=True).encode("utf-8")
    tmp = path.with_suffix(path.suffix + ".tmp")
    prev_umask = os.umask(0o077)
    try:
        # Use os.open so we can apply mode 0600 at creation.
        flags = os.O_WRONLY | os.O_CREAT | os.O_TRUNC
        fd = os.open(str(tmp), flags, 0o600)
        try:
            with os.fdopen(fd, "wb") as fh:
                fh.write(payload)
        except BaseException:
            with contextlib.suppress(OSError):
                os.close(fd)
            raise
        os.replace(tmp, path)
        with contextlib.suppress(OSError):
            os.chmod(path, 0o600)
    finally:
        os.umask(prev_umask)
        with contextlib.suppress(FileNotFoundError):
            tmp.unlink()


def _b64url_nopad(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode("ascii").rstrip("=")


def _generate_pkce_pair() -> tuple[str, str]:
    """Return ``(verifier, challenge)`` for the PKCE S256 method."""
    verifier = secrets.token_urlsafe(64)
    challenge = _b64url_nopad(hashlib.sha256(verifier.encode("ascii")).digest())
    return verifier, challenge


def _verify_pkce(verifier: str, challenge: str) -> bool:
    """Return ``True`` when ``challenge`` is the S256 digest of ``verifier``."""
    try:
        verifier_bytes = verifier.encode("ascii")
        challenge_bytes = challenge.encode("ascii")
    except UnicodeEncodeError:
        # PKCE values are ASCII per RFC 7636; non-ASCII input cannot match.
        return False
    expected = _b64url_nopad(hashlib.sha256(verifier_bytes).digest()).encode("ascii")
    # Constant-time comparison to mirror what the auth server does.
    return secrets.compare_digest(expected, challenge_bytes)


# ---------------------------------------------------------------------------
# Step 2.2 — Transport: redact, token bucket, refresh, _authenticated_request
# ---------------------------------------------------------------------------


def _redact(text: str) -> str:
    """Scrub token-shaped substrings from ``text`` before logging."""
    if not text:
        return text
    redacted = text
    for pattern, replacement in _REDACT_PATTERNS:
        redacted = pattern.sub(replacement, redacted)
    return redacted


@dataclass
class _TokenBucket:
    """Simple token-bucket throttle, instantiated per-process."""

    capacity: float = RATE_LIMIT_BUCKET_CAPACITY
    tokens_per_sec: float = RATE_LIMIT_TOKENS_PER_SEC
    tokens: float = RATE_LIMIT_BUCKET_CAPACITY
    last_refill: float = 0.0
    lock: threading.Lock = None  # type: ignore[assignment]

    def __post_init__(self) -> None:
        self.lock = threading.Lock()
        self.last_refill = time.monotonic()


_RATE_BUCKET = _TokenBucket()


def _token_bucket_acquire(
    *,
    bucket: _TokenBucket | None = None,
    now: Callable[[], float] = time.monotonic,
    sleep: Callable[[float], None] = time.sleep,
) -> None:
    """Block until one token is available in the bucket."""
    bucket = bucket or _RATE_BUCKET
    while True:
        with bucket.lock:
            current = now()
            elapsed = max(0.0, current - bucket.last_refill)
            bucket.tokens = min(
                bucket.capacity,
                bucket.tokens + elapsed * bucket.tokens_per_sec,
            )
            bucket.last_refill = current
            if bucket.tokens >= 1.0:
                bucket.tokens -= 1.0
                return
            deficit = 1.0 - bucket.tokens
            wait = deficit / bucket.tokens_per_sec if bucket.tokens_per_sec else 0.05
        sleep(max(wait, 0.001))


def _parse_rate_limit_headers(
    headers: Any,
    *,
    bucket: _TokenBucket | None = None,
    now: Callable[[], float] = time.monotonic,
) -> dict[str, int | None]:
    """Parse ``X-RateLimit-*`` headers and tighten the local bucket if needed."""
    bucket = bucket or _RATE_BUCKET

    def _header(name: str) -> str | None:
        # urllib's HTTPMessage and plain dicts both expose ``get``.
        getter = getattr(headers, "get", None)
        if getter is None:
            return None
        value = getter(name)
        if value is None:
            value = getter(name.lower())
        return value

    def _to_int(value: str | None) -> int | None:
        if value is None:
            return None
        try:
            return int(value)
        except (TypeError, ValueError):
            return None

    remaining = _to_int(_header("X-RateLimit-Remaining"))
    reset = _to_int(_header("X-RateLimit-Reset"))

    if remaining is not None and remaining <= 0 and reset is not None:
        # Drain the bucket; the next acquire will sleep until refill.
        with bucket.lock:
            bucket.tokens = 0.0
            bucket.last_refill = now()
    return {"remaining": remaining, "reset": reset}


def _refresh_access_token(
    refresh_token: str,
    *,
    client_id: str,
    client_secret: str | None = None,
    token_url: str = MURAL_TOKEN_URL,
    _http: Callable[..., Any] = urllib.request.urlopen,
) -> dict[str, Any]:
    """Exchange a refresh token for a new access token."""
    body: dict[str, str] = {
        "grant_type": "refresh_token",
        "refresh_token": refresh_token,
        "client_id": client_id,
    }
    if client_secret:
        body["client_secret"] = client_secret
    encoded = urllib.parse.urlencode(body).encode("ascii")
    request = urllib.request.Request(
        token_url,
        data=encoded,
        method="POST",
        headers={
            "Content-Type": "application/x-www-form-urlencoded",
            "Accept": "application/json",
            "User-Agent": USER_AGENT,
        },
    )
    LOGGER.debug("POST %s", token_url)
    try:
        with _http(request) as resp:  # type: ignore[arg-type]
            payload = resp.read().decode("utf-8")
            status = getattr(resp, "status", 200)
    except urllib.error.HTTPError as exc:
        text = exc.read().decode("utf-8", errors="replace") if exc.fp else ""
        _emit(f"refresh failed: HTTP {exc.code} {text}", level=logging.ERROR)
        raise MuralAPIError(
            exc.code, "REFRESH_FAILED", text or "refresh failed"
        ) from exc
    if status >= 400:
        raise MuralAPIError(status, "REFRESH_FAILED", payload)
    try:
        data = json.loads(payload)
    except json.JSONDecodeError as exc:
        raise MuralAPIError(status, "REFRESH_INVALID_JSON", payload) from exc
    if not isinstance(data, dict) or "access_token" not in data:
        raise MuralAPIError(status, "REFRESH_INVALID_PAYLOAD", "missing access_token")
    return data


def _emit(message: str, *, level: int = logging.INFO) -> None:
    """Write a redacted message to stderr and the module logger."""
    redacted = _redact(message)
    LOGGER.log(level, redacted)
    print(redacted, file=sys.stderr)


def _apply_refresh(
    store: dict[str, Any],
    *,
    client_id: str,
    client_secret: str | None,
    token_url: str,
    _http: Callable[..., Any],
    _now: Callable[[], float],
) -> dict[str, Any]:
    refresh_token = store.get("refresh_token")
    if not refresh_token:
        raise MuralError("token store has no refresh_token; run `mural.py auth login`")
    fresh = _refresh_access_token(
        refresh_token,
        client_id=client_id,
        client_secret=client_secret,
        token_url=token_url,
        _http=_http,
    )
    expires_in = int(fresh.get("expires_in", 0) or 0)
    new_store = dict(store)
    new_store["access_token"] = fresh["access_token"]
    if "refresh_token" in fresh and fresh["refresh_token"]:
        new_store["refresh_token"] = fresh["refresh_token"]
    if expires_in:
        new_store["expires_at"] = int(_now()) + expires_in
    if "scope" in fresh:
        new_store["scope"] = fresh["scope"]
    return new_store


def _authenticated_request(
    method: str,
    path: str,
    *,
    params: dict[str, Any] | None = None,
    json_body: Any | None = None,
    token_store_path: pathlib.Path | None = None,
    base_url: str | None = None,
    env: dict[str, str] | None = None,
    _now: Callable[[], float] = time.time,
    _http: Callable[..., Any] = urllib.request.urlopen,
    _sleep: Callable[[float], None] = time.sleep,
    _bucket: _TokenBucket | None = None,
) -> Any | None:
    """Perform an authenticated request with refresh, retry, and backoff."""
    src = env if env is not None else os.environ
    base = base_url or src.get(ENV_BASE_URL) or MURAL_BASE_URL_DEFAULT
    client_id = src.get(ENV_CLIENT_ID)
    if not client_id:
        raise MuralError(f"{ENV_CLIENT_ID} is not set")
    client_secret = src.get(ENV_CLIENT_SECRET) or None

    store_path = token_store_path or _resolve_token_store_path(env=src)
    store = _load_token_store(store_path)
    if not store:
        raise MuralError(
            f"no token store at {store_path}; run `mural.py auth login` first"
        )

    expires_at = int(store.get("expires_at") or 0)
    if expires_at and expires_at - REFRESH_LEEWAY_SECONDS <= _now():
        store = _apply_refresh(
            store,
            client_id=client_id,
            client_secret=client_secret,
            token_url=src.get("MURAL_TOKEN_URL", MURAL_TOKEN_URL),
            _http=_http,
            _now=_now,
        )
        _save_token_store(store_path, store)

    url = _join_url(base, path, params)
    encoded: bytes | None = None
    headers = {
        "User-Agent": USER_AGENT,
        "Accept": "application/json",
    }
    if json_body is not None:
        encoded = json.dumps(json_body).encode("utf-8")
        headers["Content-Type"] = "application/json"

    refreshed_due_to_401 = False
    attempt = 0
    while True:
        _token_bucket_acquire(bucket=_bucket, now=time.monotonic, sleep=_sleep)
        request_headers = dict(headers)
        request_headers["Authorization"] = f"Bearer {store['access_token']}"
        request = urllib.request.Request(
            url,
            data=encoded,
            method=method.upper(),
            headers=request_headers,
        )
        LOGGER.debug("%s %s", method.upper(), url)
        try:
            with _http(request) as resp:  # type: ignore[arg-type]
                status = getattr(resp, "status", 200)
                body_bytes = resp.read()
                _parse_rate_limit_headers(resp.headers, bucket=_bucket)
                return _decode_body(status, body_bytes)
        except urllib.error.HTTPError as exc:
            status = exc.code
            try:
                body_bytes = exc.read() if exc.fp else b""
            except Exception:  # pragma: no cover - defensive
                body_bytes = b""
            headers_obj = getattr(exc, "headers", None)
            if headers_obj is not None:
                _parse_rate_limit_headers(headers_obj, bucket=_bucket)

            if status == 401 and not refreshed_due_to_401:
                refreshed_due_to_401 = True
                _emit("access token rejected; forcing refresh", level=logging.INFO)
                store = _apply_refresh(
                    store,
                    client_id=client_id,
                    client_secret=client_secret,
                    token_url=src.get("MURAL_TOKEN_URL", MURAL_TOKEN_URL),
                    _http=_http,
                    _now=_now,
                )
                _save_token_store(store_path, store)
                continue

            if status == 429 or 500 <= status < 600:
                if attempt >= MAX_RETRIES:
                    raise _build_api_error(status, body_bytes, headers_obj) from exc
                wait = _backoff_seconds(headers_obj, attempt)
                _emit(
                    f"HTTP {status}; retrying in {wait:.2f}s "
                    f"(attempt {attempt + 1}/{MAX_RETRIES})",
                    level=logging.WARNING,
                )
                _sleep(wait)
                attempt += 1
                continue

            raise _build_api_error(status, body_bytes, headers_obj) from exc
        except urllib.error.URLError as exc:
            if attempt >= MAX_RETRIES:
                raise MuralError(f"network error contacting {url}: {exc}") from exc
            wait = min(MAX_BACKOFF_SECONDS, 2 ** attempt)
            _emit(
                f"network error: {exc}; retrying in {wait:.2f}s "
                f"(attempt {attempt + 1}/{MAX_RETRIES})",
                level=logging.WARNING,
            )
            _sleep(wait)
            attempt += 1
            continue


def _join_url(base: str, path: str, params: dict[str, Any] | None) -> str:
    if path.startswith(("http://", "https://")):
        url = path
    else:
        url = base.rstrip("/") + "/" + path.lstrip("/")
    if params:
        flat = {k: v for k, v in params.items() if v is not None}
        if flat:
            url = f"{url}?{urllib.parse.urlencode(flat, doseq=True)}"
    return url


def _decode_body(status: int, body_bytes: bytes) -> Any | None:
    if status == 204 or not body_bytes:
        return None
    try:
        return json.loads(body_bytes.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        return body_bytes.decode("utf-8", errors="replace")


def _extract_error_payload(
    body_bytes: bytes,
    headers_obj: Any,
) -> tuple[str | None, str | None, str | None]:
    """Decode a Mural error response into ``(code, message, request_id)``.

    ``request_id`` falls back to the ``X-Request-Id`` header when the body
    omits it.  This helper exists as a discrete fuzzable seam so error
    extraction logic can be exercised without issuing real HTTP calls.
    """
    code: str | None = None
    message: str | None = None
    request_id: str | None = None
    if headers_obj is not None:
        getter = getattr(headers_obj, "get", None)
        if callable(getter):
            request_id = getter("X-Request-Id") or getter("x-request-id")
    if body_bytes:
        try:
            payload = json.loads(body_bytes.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            payload = None
        if isinstance(payload, dict):
            raw_code = payload.get("code")
            code = str(raw_code) if raw_code is not None else None
            raw_message = payload.get("message") or payload.get("error")
            message = str(raw_message) if raw_message else None
        if message is None:
            message = body_bytes.decode("utf-8", errors="replace")
    return code, message, request_id


def _build_api_error(status: int, body_bytes: bytes, headers_obj: Any) -> MuralAPIError:
    code, message, request_id = _extract_error_payload(body_bytes, headers_obj)
    if not message:
        message = f"HTTP {status}"
    return MuralAPIError(status, code, message, request_id)


def _backoff_seconds(headers_obj: Any, attempt: int) -> float:
    retry_after: float | None = None
    if headers_obj is not None:
        getter = getattr(headers_obj, "get", None)
        if callable(getter):
            raw = getter("Retry-After") or getter("retry-after")
            if raw is not None:
                try:
                    retry_after = float(raw)
                except (TypeError, ValueError):
                    retry_after = None
    if retry_after is None:
        retry_after = float(min(MAX_BACKOFF_SECONDS, 2 ** attempt))
    return min(MAX_BACKOFF_SECONDS, max(0.0, retry_after))


# ---------------------------------------------------------------------------
# Step 2.3 — Loopback OAuth login flow
# ---------------------------------------------------------------------------


def _build_authorize_url(
    client_id: str,
    redirect_uri: str,
    state: str,
    code_challenge: str,
    scopes: str,
    *,
    authorize_url: str = MURAL_AUTHORIZE_URL,
) -> str:
    """Construct the OAuth 2.0 authorize URL with PKCE S256 parameters."""
    if not client_id:
        raise MuralError("client_id is required to build authorize URL")
    if not redirect_uri:
        raise MuralError("redirect_uri is required to build authorize URL")
    if not state:
        raise MuralError("state is required to build authorize URL")
    if not code_challenge:
        raise MuralError("code_challenge is required to build authorize URL")
    query = {
        "response_type": "code",
        "client_id": client_id,
        "redirect_uri": redirect_uri,
        "state": state,
        "code_challenge": code_challenge,
        "code_challenge_method": "S256",
        "scope": scopes,
    }
    return f"{authorize_url}?{urllib.parse.urlencode(query)}"


@dataclass
class _CallbackResult:
    code: str | None = None
    state: str | None = None
    error: str | None = None
    error_description: str | None = None


class _LoopbackHandler(http.server.BaseHTTPRequestHandler):
    """Single-shot HTTP handler that captures the OAuth callback query."""

    server_version = "MuralLoopback/1.0"

    def do_GET(self) -> None:  # noqa: N802 - http.server contract
        parsed = urllib.parse.urlsplit(self.path)
        params = urllib.parse.parse_qs(parsed.query)
        result: _CallbackResult = self.server.callback_result  # type: ignore[attr-defined]
        result.code = (params.get("code") or [None])[0]
        result.state = (params.get("state") or [None])[0]
        result.error = (params.get("error") or [None])[0]
        result.error_description = (params.get("error_description") or [None])[0]

        body = (
            "<html><body><h1>Mural authentication complete</h1>"
            "<p>You may close this window and return to the terminal.</p>"
            "</body></html>"
        ).encode("utf-8")
        if result.error:
            self.send_response(400)
        else:
            self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
        # Signal the main thread that the callback has been received.
        self.server.callback_received.set()  # type: ignore[attr-defined]

    def log_message(self, format: str, *args: Any) -> None:  # noqa: A002
        # Suppress default stderr access logging; route through our redactor.
        _emit("loopback: " + (format % args), level=logging.DEBUG)


def _exchange_authorization_code(
    *,
    code: str,
    code_verifier: str,
    client_id: str,
    client_secret: str | None,
    redirect_uri: str,
    token_url: str = MURAL_TOKEN_URL,
    _http: Callable[..., Any] = urllib.request.urlopen,
    _now: Callable[[], float] = time.time,
) -> dict[str, Any]:
    body: dict[str, str] = {
        "grant_type": "authorization_code",
        "code": code,
        "redirect_uri": redirect_uri,
        "code_verifier": code_verifier,
        "client_id": client_id,
    }
    if client_secret:
        body["client_secret"] = client_secret
    encoded = urllib.parse.urlencode(body).encode("ascii")
    request = urllib.request.Request(
        token_url,
        data=encoded,
        method="POST",
        headers={
            "Content-Type": "application/x-www-form-urlencoded",
            "Accept": "application/json",
            "User-Agent": USER_AGENT,
        },
    )
    try:
        with _http(request) as resp:  # type: ignore[arg-type]
            payload = resp.read().decode("utf-8")
            status = getattr(resp, "status", 200)
    except urllib.error.HTTPError as exc:
        text = exc.read().decode("utf-8", errors="replace") if exc.fp else ""
        raise MuralAPIError(
            exc.code, "TOKEN_EXCHANGE_FAILED", text or "exchange failed"
        ) from exc
    if status >= 400:
        raise MuralAPIError(status, "TOKEN_EXCHANGE_FAILED", payload)
    try:
        data = json.loads(payload)
    except json.JSONDecodeError as exc:
        raise MuralAPIError(status, "TOKEN_EXCHANGE_INVALID_JSON", payload) from exc
    if not isinstance(data, dict) or "access_token" not in data:
        raise MuralAPIError(
            status, "TOKEN_EXCHANGE_INVALID_PAYLOAD", "missing access_token"
        )
    expires_in = int(data.get("expires_in", 0) or 0)
    record = {
        "access_token": data["access_token"],
        "refresh_token": data.get("refresh_token"),
        "scope": data.get("scope"),
        "token_type": data.get("token_type", "Bearer"),
        "expires_at": int(_now()) + expires_in if expires_in else 0,
        "obtained_at": int(_now()),
    }
    return record


def _start_loopback_server(
    *,
    server_factory: Callable[..., http.server.HTTPServer] = http.server.HTTPServer,
    bind_host: str = "127.0.0.1",
) -> tuple[http.server.HTTPServer, _CallbackResult, threading.Event, int]:
    server = server_factory((bind_host, 0), _LoopbackHandler)
    # Attach state holders the handler reads from.
    server.callback_result = _CallbackResult()  # type: ignore[attr-defined]
    server.callback_received = threading.Event()  # type: ignore[attr-defined]
    port = server.server_address[1]
    return server, server.callback_result, server.callback_received, port  # type: ignore[attr-defined]


def _run_login(
    *,
    env: dict[str, str] | None = None,
    scopes: str | None = None,
    timeout_seconds: int = 300,
    open_browser: Callable[[str], bool] = webbrowser.open,
    server_factory: Callable[..., http.server.HTTPServer] = http.server.HTTPServer,
    _http: Callable[..., Any] = urllib.request.urlopen,
    _now: Callable[[], float] = time.time,
) -> dict[str, Any]:
    src = env if env is not None else os.environ
    client_id = src.get(ENV_CLIENT_ID)
    if not client_id:
        raise MuralError(f"{ENV_CLIENT_ID} is not set")
    client_secret = src.get(ENV_CLIENT_SECRET) or None

    server, result, received, port = _start_loopback_server(
        server_factory=server_factory
    )
    redirect_uri = src.get(ENV_REDIRECT_URI) or f"http://127.0.0.1:{port}/callback"

    verifier, challenge = _generate_pkce_pair()
    state = secrets.token_urlsafe(32)
    authorize_url = _build_authorize_url(
        client_id=client_id,
        redirect_uri=redirect_uri,
        state=state,
        code_challenge=challenge,
        scopes=scopes or DEFAULT_SCOPES,
    )

    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        _emit(f"listening on http://127.0.0.1:{port}/callback", level=logging.INFO)
        _emit("open this URL in your browser to complete login:", level=logging.INFO)
        # Print the authorize URL on stdout so it can be piped if needed.
        # The redactor never matches this URL because PKCE challenges are
        # not in the redact key list (they are public by design).
        print(authorize_url)
        with contextlib.suppress(Exception):
            open_browser(authorize_url)

        if not received.wait(timeout=timeout_seconds):
            raise MuralError("timed out waiting for OAuth callback")
    finally:
        server.shutdown()
        with contextlib.suppress(Exception):
            server.server_close()

    if result.error:
        raise MuralError(
            f"authorization failed: {result.error}: {result.error_description or ''}"
        )
    if not result.code:
        raise MuralError("authorization callback returned no code")
    if not result.state or not secrets.compare_digest(result.state, state):
        raise MuralSecurityError("state parameter mismatch on OAuth callback")

    record = _exchange_authorization_code(
        code=result.code,
        code_verifier=verifier,
        client_id=client_id,
        client_secret=client_secret,
        redirect_uri=redirect_uri,
        _http=_http,
        _now=_now,
    )
    return record


# ---------------------------------------------------------------------------
# Step 3 — Validation, projection, pagination, asset upload helpers
# ---------------------------------------------------------------------------


_MURAL_ID_RE = re.compile(r"^[A-Za-z0-9]+\.[A-Za-z0-9-]+$")
_AZURE_BLOB_HOST_SUFFIX = ".blob.core.windows.net"
_DEFAULT_PAGE_SIZE = 50
_MAX_PAGE_SIZE = 200
_MAX_CURSOR_BYTES = 4096
_IMAGE_CONTENT_TYPES: dict[str, str] = {
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".gif": "image/gif",
    ".webp": "image/webp",
    ".svg": "image/svg+xml",
}


def _validate_mural_id(value: str) -> str:
    """Return ``value`` after asserting it is a well-formed Mural id.

    Mural ids look like ``workspace.muralslug``.  Any input containing path
    separators, parent traversal sequences, or null bytes is rejected with
    ``MuralValidationError`` to prevent path injection in URL construction.
    """
    if not isinstance(value, str) or not value:
        raise MuralValidationError("mural id must be a non-empty string")
    if "\x00" in value or "/" in value or "\\" in value or ".." in value:
        raise MuralValidationError(
            f"mural id contains forbidden characters: {value!r}"
        )
    if not _MURAL_ID_RE.match(value):
        raise MuralValidationError(
            f"mural id must match {_MURAL_ID_RE.pattern}, got {value!r}"
        )
    return value


def _extract_field(obj: Any, path: str) -> Any:
    """Return the value at ``path`` (dotted notation) within ``obj`` or ``None``.

    Accepts ``a.b.c`` and indexes both dict keys and integer list indices.
    Never raises; missing or type-mismatched segments yield ``None``.
    """
    if not path:
        return obj
    current: Any = obj
    for segment in path.split("."):
        if current is None:
            return None
        if isinstance(current, dict):
            current = current.get(segment)
        elif isinstance(current, list):
            try:
                idx = int(segment)
            except ValueError:
                return None
            if 0 <= idx < len(current):
                current = current[idx]
            else:
                return None
        else:
            return None
    return current


def _project_record(record: Any, fields: list[str] | None) -> Any:
    """Return a shallow projection of ``record`` to ``fields`` (dotted paths)."""
    if not fields:
        return record
    if isinstance(record, list):
        return [_project_record(item, fields) for item in record]
    if not isinstance(record, dict):
        return record
    return {field: _extract_field(record, field) for field in fields}


def _format_output(data: Any, fields: list[str] | None, fmt: str) -> str:
    """Render ``data`` for stdout in ``json`` or ``table`` form."""
    projected = _project_record(data, fields)
    if fmt == "table":
        rows = projected if isinstance(projected, list) else [projected]
        if not rows:
            return ""
        keys = fields or sorted(
            {k for r in rows if isinstance(r, dict) for k in r}
        )
        if not keys:
            return ""
        widths = [
            max(
                len(k),
                *(len(str(_extract_field(r, k) or "")) for r in rows),
            )
            for k in keys
        ]
        header = "  ".join(k.ljust(w) for k, w in zip(keys, widths))
        sep = "  ".join("-" * w for w in widths)
        body_lines = [
            "  ".join(
                str(_extract_field(r, k) or "").ljust(w)
                for k, w in zip(keys, widths)
            )
            for r in rows
        ]
        return "\n".join([header, sep, *body_lines])
    return json.dumps(projected, indent=2)


def _parse_pagination_cursor(token: str) -> dict[str, Any]:
    """Decode and validate an opaque pagination cursor token.

    The cursor is treated as base64url-encoded JSON.  Tokens larger than
    ``_MAX_CURSOR_BYTES`` raw bytes or that fail to decode are rejected with
    ``MuralValidationError``; the helper exists primarily as a fuzzable seam.
    """
    if not isinstance(token, str) or not token:
        raise MuralValidationError("cursor token must be a non-empty string")
    if len(token.encode("utf-8")) > _MAX_CURSOR_BYTES:
        raise MuralValidationError("cursor token exceeds maximum size")
    padding = "=" * (-len(token) % 4)
    try:
        raw = base64.urlsafe_b64decode(token + padding)
    except (binascii.Error, ValueError) as exc:
        raise MuralValidationError("cursor token is not base64url") from exc
    try:
        decoded = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise MuralValidationError("cursor token payload is not JSON") from exc
    if not isinstance(decoded, dict):
        raise MuralValidationError("cursor token payload must be a JSON object")
    return decoded


def _paginate(
    method: str,
    path: str,
    *,
    params: dict[str, Any] | None = None,
    limit: int | None = None,
    page_size: int | None = None,
    **request_kwargs: Any,
) -> Any:
    """Yield records across Mural's ``next``-cursor pagination.

    ``params`` is applied to every page so that ``type``, ``parentId``, and
    other filters remain consistent per Mural's pagination contract.
    ``page_size`` maps to the ``limit`` query parameter.  ``limit`` (the
    function argument) caps the total number of records yielded.
    """
    base_params = dict(params or {})
    if page_size is not None:
        base_params["limit"] = int(page_size)
    yielded = 0
    next_token: str | None = None
    while True:
        page_params = dict(base_params)
        if next_token is not None:
            page_params["next"] = next_token
        response = _authenticated_request(
            method, path, params=page_params, **request_kwargs
        )
        if isinstance(response, dict) and "value" in response:
            records = response.get("value") or []
            next_token = response.get("next") or None
        elif isinstance(response, list):
            records = response
            next_token = None
        else:
            yield response
            return
        for record in records:
            yield record
            yielded += 1
            if limit is not None and yielded >= limit:
                return
        if not next_token:
            return


def _resolve_workspace_id(
    explicit: str | None,
    *,
    env: dict[str, str] | None = None,
    **request_kwargs: Any,
) -> str:
    """Return the workspace id, falling back to env or list discovery."""
    src = env if env is not None else os.environ
    if explicit:
        return explicit
    fallback = src.get(ENV_DEFAULT_WORKSPACE)
    if fallback:
        return fallback
    workspaces = list(
        _paginate("GET", "/workspaces", env=src, **request_kwargs)
    )
    ids = [
        w.get("id")
        for w in workspaces
        if isinstance(w, dict) and w.get("id")
    ]
    if len(ids) == 1:
        return ids[0]
    raise MuralAmbiguousWorkspaceError(workspace_ids=ids)


def _validate_asset_url(url: str) -> None:
    """Raise ``MuralSecurityError`` when ``url`` is not a safe Azure SAS link.

    SSRF allowlist: requires https, no userinfo, no fragment, no IP-literal
    host, and a hostname ending in ``.blob.core.windows.net``.
    """
    if not isinstance(url, str) or not url:
        raise MuralSecurityError("asset upload url is empty")
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme != "https":
        raise MuralSecurityError(
            f"asset upload url must be https, got {parsed.scheme!r}"
        )
    if parsed.username or parsed.password:
        raise MuralSecurityError("asset upload url must not contain userinfo")
    if parsed.fragment:
        raise MuralSecurityError("asset upload url must not contain a fragment")
    host = (parsed.hostname or "").lower()
    if not host:
        raise MuralSecurityError("asset upload url has no host")
    # Reject bare IPv4 (all dots+digits) and bracketed IPv6 (':' present).
    if host.replace(".", "").isdigit() or ":" in host:
        raise MuralSecurityError(
            f"asset upload url host must be a name, not an address: {host!r}"
        )
    if not host.endswith(_AZURE_BLOB_HOST_SUFFIX):
        raise MuralSecurityError(
            f"asset upload url host {host!r} is not on the Azure Blob allowlist"
        )


def _parse_json_arg(value: str, flag: str) -> Any:
    """Parse a JSON CLI argument, raising ``MuralValidationError`` on failure."""
    try:
        return json.loads(value)
    except json.JSONDecodeError as exc:
        raise MuralValidationError(f"{flag} is not valid JSON: {exc}") from exc


def _coerce_xy(value: Any, name: str) -> float:
    try:
        return float(value)
    except (TypeError, ValueError) as exc:
        raise MuralValidationError(
            f"{name} must be numeric, got {value!r}"
        ) from exc


def _build_sticky_note_body(args: argparse.Namespace) -> dict[str, Any]:
    if not getattr(args, "text", None):
        raise MuralValidationError("--text is required for sticky-note widgets")
    body: dict[str, Any] = {
        "text": args.text,
        "x": _coerce_xy(args.x, "--x"),
        "y": _coerce_xy(args.y, "--y"),
        "shape": getattr(args, "shape", None) or "rectangle",
    }
    if getattr(args, "width", None) is not None:
        body["width"] = _coerce_xy(args.width, "--width")
    if getattr(args, "height", None) is not None:
        body["height"] = _coerce_xy(args.height, "--height")
    if getattr(args, "style", None):
        body["style"] = _parse_json_arg(args.style, "--style")
    return body


def _build_textbox_body(args: argparse.Namespace) -> dict[str, Any]:
    if not getattr(args, "text", None):
        raise MuralValidationError("--text is required for textbox widgets")
    body: dict[str, Any] = {
        "text": args.text,
        "x": _coerce_xy(args.x, "--x"),
        "y": _coerce_xy(args.y, "--y"),
    }
    if getattr(args, "width", None) is not None:
        body["width"] = _coerce_xy(args.width, "--width")
    if getattr(args, "height", None) is not None:
        body["height"] = _coerce_xy(args.height, "--height")
    if getattr(args, "style", None):
        body["style"] = _parse_json_arg(args.style, "--style")
    return body


def _build_shape_body(args: argparse.Namespace) -> dict[str, Any]:
    if not getattr(args, "shape", None):
        raise MuralValidationError("--shape is required for shape widgets")
    body: dict[str, Any] = {
        "shape": args.shape,
        "x": _coerce_xy(args.x, "--x"),
        "y": _coerce_xy(args.y, "--y"),
    }
    if getattr(args, "width", None) is not None:
        body["width"] = _coerce_xy(args.width, "--width")
    if getattr(args, "height", None) is not None:
        body["height"] = _coerce_xy(args.height, "--height")
    if getattr(args, "text", None):
        body["text"] = args.text
    if getattr(args, "style", None):
        body["style"] = _parse_json_arg(args.style, "--style")
    return body


def _build_arrow_body(args: argparse.Namespace) -> dict[str, Any]:
    body: dict[str, Any] = {
        "x1": _coerce_xy(getattr(args, "x1", None), "--x1"),
        "y1": _coerce_xy(getattr(args, "y1", None), "--y1"),
        "x2": _coerce_xy(getattr(args, "x2", None), "--x2"),
        "y2": _coerce_xy(getattr(args, "y2", None), "--y2"),
    }
    if getattr(args, "style", None):
        body["style"] = _parse_json_arg(args.style, "--style")
    return body


def _build_image_body(
    *,
    asset_name: str,
    args: argparse.Namespace,
) -> dict[str, Any]:
    body: dict[str, Any] = {
        "name": asset_name,
        "x": _coerce_xy(args.x, "--x"),
        "y": _coerce_xy(args.y, "--y"),
    }
    if getattr(args, "width", None) is not None:
        body["width"] = _coerce_xy(args.width, "--width")
    if getattr(args, "height", None) is not None:
        body["height"] = _coerce_xy(args.height, "--height")
    if getattr(args, "title", None):
        body["title"] = args.title
    return body


def _create_asset_url(
    mural_id: str,
    file_extension: str,
    **request_kwargs: Any,
) -> dict[str, Any]:
    """Call ``POST /murals/{id}/assets`` and return the ``value`` payload."""
    if not file_extension:
        raise MuralValidationError(
            "file_extension is required to create an asset url"
        )
    ext = file_extension.lstrip(".").lower()
    response = _authenticated_request(
        "POST",
        f"/murals/{mural_id}/assets",
        json_body={"fileExtension": ext},
        **request_kwargs,
    )
    if not isinstance(response, dict):
        raise MuralAPIError(
            0, "ASSET_URL_INVALID", "asset response is not an object"
        )
    value = (
        response.get("value")
        if isinstance(response.get("value"), dict)
        else response
    )
    if (
        not isinstance(value, dict)
        or "url" not in value
        or "name" not in value
    ):
        raise MuralAPIError(
            0, "ASSET_URL_INVALID", "asset response missing url/name"
        )
    return value


def _upload_to_sas(
    *,
    url: str,
    headers: dict[str, str],
    body: bytes,
    content_type: str,
    _http: Callable[..., Any] = urllib.request.urlopen,
) -> None:
    """PUT ``body`` to the Azure SAS ``url`` after validating it.

    ``headers`` is the dictionary returned by Mural's ``POST /assets`` call
    and must include ``x-ms-blob-type: BlockBlob``.  No Mural Bearer token is
    sent on this request.
    """
    _validate_asset_url(url)
    request_headers: dict[str, str] = {
        "Content-Type": content_type,
        "Content-Length": str(len(body)),
        "User-Agent": USER_AGENT,
    }
    for key, value in (headers or {}).items():
        if key.lower() == "authorization":
            continue
        request_headers[key] = value
    if request_headers.get("x-ms-blob-type", "").lower() != "blockblob":
        request_headers["x-ms-blob-type"] = "BlockBlob"
    request = urllib.request.Request(
        url,
        data=body,
        method="PUT",
        headers=request_headers,
    )
    LOGGER.debug("PUT %s", _redact(url))
    try:
        with _http(request) as resp:  # type: ignore[arg-type]
            status = getattr(resp, "status", 200)
            if status >= 400:
                payload = resp.read().decode("utf-8", errors="replace")
                raise MuralAPIError(
                    status, "ASSET_UPLOAD_FAILED", payload
                )
    except urllib.error.HTTPError as exc:
        text = exc.read().decode("utf-8", errors="replace") if exc.fp else ""
        raise MuralAPIError(
            exc.code, "ASSET_UPLOAD_FAILED", text or "upload failed"
        ) from exc
    except urllib.error.URLError as exc:
        raise MuralError(
            f"network error uploading to asset url: {exc}"
        ) from exc


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def _cmd_auth_login(args: argparse.Namespace) -> int:
    try:
        record = _run_login(scopes=args.scopes, timeout_seconds=args.timeout)
    except MuralError as exc:
        _emit(str(exc), level=logging.ERROR)
        return EXIT_FAILURE
    path = _resolve_token_store_path()
    _save_token_store(path, record)
    _emit(f"saved token store at {path}", level=logging.INFO)
    return EXIT_SUCCESS


def _cmd_auth_logout(_args: argparse.Namespace) -> int:
    path = _resolve_token_store_path()
    try:
        path.unlink()
    except FileNotFoundError:
        _emit(f"no token store at {path}", level=logging.INFO)
        return EXIT_SUCCESS
    except OSError as exc:
        _emit(f"cannot delete {path}: {exc}", level=logging.ERROR)
        return EXIT_FAILURE
    _emit(f"removed token store at {path}", level=logging.INFO)
    return EXIT_SUCCESS


def _cmd_auth_status(_args: argparse.Namespace) -> int:
    path = _resolve_token_store_path()
    store = _load_token_store(path)
    if not store:
        print(json.dumps({"authenticated": False, "token_store": str(path)}, indent=2))
        return EXIT_SUCCESS
    info = {
        "authenticated": True,
        "token_store": str(path),
        "scope": store.get("scope"),
        "expires_at": store.get("expires_at"),
        "has_refresh_token": bool(store.get("refresh_token")),
    }
    print(json.dumps(info, indent=2))
    return EXIT_SUCCESS


def _read_fields(args: argparse.Namespace) -> list[str] | None:
    raw = getattr(args, "fields", None)
    if not raw:
        return None
    return [f.strip() for f in raw.split(",") if f.strip()]


def _list_kwargs(args: argparse.Namespace) -> dict[str, int | None]:
    limit = getattr(args, "limit", None)
    page_size = getattr(args, "page_size", None)
    for name, value in (("--limit", limit), ("--page-size", page_size)):
        if value is not None and value <= 0:
            raise MuralValidationError(f"{name} must be positive")
        if value is not None and value > _MAX_PAGE_SIZE * 100:
            raise MuralValidationError(f"{name} exceeds safe maximum")
    if page_size is not None and page_size > _MAX_PAGE_SIZE:
        raise MuralValidationError(
            f"--page-size cannot exceed {_MAX_PAGE_SIZE}"
        )
    return {"limit": limit, "page_size": page_size}


def _emit_records(records: list[Any], args: argparse.Namespace) -> int:
    fields = _read_fields(args)
    fmt = getattr(args, "format", None) or "json"
    print(_format_output(records, fields, fmt))
    return EXIT_SUCCESS


def _emit_record(record: Any, args: argparse.Namespace) -> int:
    fields = _read_fields(args)
    fmt = getattr(args, "format", None) or "json"
    print(_format_output(record, fields, fmt))
    return EXIT_SUCCESS


def _cmd_workspace_list(args: argparse.Namespace) -> int:
    records = list(_paginate("GET", "/workspaces", **_list_kwargs(args)))
    return _emit_records(records, args)


def _cmd_workspace_get(args: argparse.Namespace) -> int:
    workspace_id = _resolve_workspace_id(getattr(args, "workspace", None))
    record = _authenticated_request("GET", f"/workspaces/{workspace_id}")
    return _emit_record(record, args)


def _cmd_room_list(args: argparse.Namespace) -> int:
    workspace_id = _resolve_workspace_id(getattr(args, "workspace", None))
    records = list(
        _paginate(
            "GET",
            f"/workspaces/{workspace_id}/rooms",
            **_list_kwargs(args),
        )
    )
    return _emit_records(records, args)


def _cmd_room_get(args: argparse.Namespace) -> int:
    record = _authenticated_request("GET", f"/rooms/{args.room}")
    return _emit_record(record, args)


def _cmd_mural_list(args: argparse.Namespace) -> int:
    workspace_id = _resolve_workspace_id(getattr(args, "workspace", None))
    records = list(
        _paginate(
            "GET",
            f"/workspaces/{workspace_id}/murals",
            **_list_kwargs(args),
        )
    )
    return _emit_records(records, args)


def _cmd_mural_get(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    record = _authenticated_request("GET", f"/murals/{mural_id}")
    return _emit_record(record, args)


def _cmd_widget_list(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    params: dict[str, Any] = {}
    widget_type = getattr(args, "type", None)
    parent_id = getattr(args, "parent_id", None)
    if widget_type:
        params["type"] = widget_type
    if parent_id:
        params["parentId"] = parent_id
    records = list(
        _paginate(
            "GET",
            f"/murals/{mural_id}/widgets",
            params=params or None,
            **_list_kwargs(args),
        )
    )
    return _emit_records(records, args)


def _cmd_widget_get(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    record = _authenticated_request(
        "GET", f"/murals/{mural_id}/widgets/{args.widget}"
    )
    return _emit_record(record, args)


def _cmd_widget_delete(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    _authenticated_request(
        "DELETE", f"/murals/{mural_id}/widgets/{args.widget}"
    )
    print(json.dumps({"deleted": args.widget}))
    return EXIT_SUCCESS


def _cmd_widget_update(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    body = _parse_json_arg(args.body, "--body")
    record = _authenticated_request(
        "PATCH",
        f"/murals/{mural_id}/widgets/{args.widget}",
        json_body=body,
    )
    return _emit_record(record, args)


def _create_widget(
    mural_id: str,
    widget_type: str,
    body: dict[str, Any],
    args: argparse.Namespace,
) -> int:
    record = _authenticated_request(
        "POST",
        f"/murals/{mural_id}/widgets/{widget_type}",
        json_body=body,
    )
    return _emit_record(record, args)


def _cmd_widget_create_sticky_note(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    return _create_widget(
        mural_id, "sticky-note", _build_sticky_note_body(args), args
    )


def _cmd_widget_create_textbox(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    return _create_widget(
        mural_id, "textbox", _build_textbox_body(args), args
    )


def _cmd_widget_create_shape(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    return _create_widget(
        mural_id, "shape", _build_shape_body(args), args
    )


def _cmd_widget_create_arrow(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    return _create_widget(
        mural_id, "arrow", _build_arrow_body(args), args
    )


def _cmd_widget_create_image(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    file_path = pathlib.Path(args.file).expanduser()
    if not file_path.is_file():
        raise MuralValidationError(f"image file not found: {file_path}")
    suffix = file_path.suffix.lower()
    if suffix not in _IMAGE_CONTENT_TYPES:
        raise MuralValidationError(
            f"unsupported image extension {suffix!r}; allowed: "
            + ", ".join(sorted(_IMAGE_CONTENT_TYPES))
        )
    body_bytes = file_path.read_bytes()
    asset = _create_asset_url(mural_id, suffix)
    _upload_to_sas(
        url=asset["url"],
        headers=asset.get("headers") or {},
        body=body_bytes,
        content_type=_IMAGE_CONTENT_TYPES[suffix],
    )
    record = _authenticated_request(
        "POST",
        f"/murals/{mural_id}/widgets/image",
        json_body=_build_image_body(asset_name=asset["name"], args=args),
    )
    return _emit_record(record, args)


def _cmd_mcp(_args: argparse.Namespace) -> int:
    return _run_mcp_stdio()


# ---------------------------------------------------------------------------
# Step 4 — MCP stdio server (NDJSON framing, JSON-RPC lifecycle, tool registry)
# ---------------------------------------------------------------------------


_MCP_PROTOCOL_PREFERRED = "2025-11-25"
_MCP_PROTOCOL_FALLBACK = "2025-06-18"
_MCP_SERVER_INFO = {"name": "mural", "version": "1.0.0"}
_MCP_CAPABILITIES: dict[str, Any] = {"tools": {"listChanged": False}}
_MCP_METHODS: frozenset[str] = frozenset(
    {
        "initialize",
        "notifications/initialized",
        "tools/list",
        "tools/call",
    }
)


def _frame_mcp_message(obj: dict[str, Any]) -> bytes:
    """Encode ``obj`` as a single newline-delimited JSON frame."""
    return (json.dumps(obj, ensure_ascii=False, separators=(",", ":")) + "\n").encode(
        "utf-8"
    )


def _parse_mcp_frame(line: bytes) -> dict[str, Any] | None:
    """Decode one NDJSON line into a JSON-RPC message; ``None`` for blank lines."""
    try:
        text = line.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise MCPProtocolError(f"frame is not valid utf-8: {exc}") from exc
    text = text.strip()
    if not text:
        return None
    try:
        msg = json.loads(text)
    except json.JSONDecodeError as exc:
        raise MCPProtocolError(f"invalid json frame: {exc}") from exc
    if not isinstance(msg, dict):
        raise MCPProtocolError("frame must be a JSON object")
    return msg


_JSON_TYPE_NAMES = ("string", "integer", "number", "boolean", "array", "object", "null")


def _matches_json_type(value: Any, allowed: tuple[str, ...]) -> bool:
    for name in allowed:
        if name == "null":
            if value is None:
                return True
        elif name == "boolean":
            if isinstance(value, bool):
                return True
        elif name == "integer":
            if isinstance(value, int) and not isinstance(value, bool):
                return True
        elif name == "number":
            if isinstance(value, (int, float)) and not isinstance(value, bool):
                return True
        elif name == "string":
            if isinstance(value, str):
                return True
        elif name == "array":
            if isinstance(value, list):
                return True
        elif name == "object":
            if isinstance(value, dict):
                return True
    return False


def _validate_tool_input_schema(
    schema: dict[str, Any], value: Any, path: str = "$"
) -> None:
    """Minimal JSON Schema validator covering the subset used by tool registry.

    Raises :class:`MCPInvalidParamsError` on the first violation.
    """
    if "type" in schema:
        types = schema["type"]
        if isinstance(types, str):
            allowed = (types,)
        elif isinstance(types, list):
            allowed = tuple(types)
        else:
            raise MCPInvalidParamsError(
                f"{path}: schema 'type' must be string or list, "
                f"got {type(types).__name__}",
                path=path,
            )
        if not _matches_json_type(value, allowed):
            raise MCPInvalidParamsError(
                f"{path}: expected type {list(allowed)}, got {type(value).__name__}",
                path=path,
            )
    if "enum" in schema and value not in schema["enum"]:
        raise MCPInvalidParamsError(
            f"{path}: value not in enum {schema['enum']!r}", path=path
        )
    if isinstance(value, str):
        if "minLength" in schema and len(value) < schema["minLength"]:
            raise MCPInvalidParamsError(
                f"{path}: string shorter than minLength {schema['minLength']}",
                path=path,
            )
        if "maxLength" in schema and len(value) > schema["maxLength"]:
            raise MCPInvalidParamsError(
                f"{path}: string longer than maxLength {schema['maxLength']}",
                path=path,
            )
        if "pattern" in schema and not re.search(schema["pattern"], value):
            raise MCPInvalidParamsError(
                f"{path}: string does not match pattern {schema['pattern']!r}",
                path=path,
            )
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        if "minimum" in schema and value < schema["minimum"]:
            raise MCPInvalidParamsError(
                f"{path}: value less than minimum {schema['minimum']}", path=path
            )
        if "maximum" in schema and value > schema["maximum"]:
            raise MCPInvalidParamsError(
                f"{path}: value greater than maximum {schema['maximum']}", path=path
            )
    if isinstance(value, list):
        if "minItems" in schema and len(value) < schema["minItems"]:
            raise MCPInvalidParamsError(
                f"{path}: array shorter than minItems {schema['minItems']}", path=path
            )
        if "maxItems" in schema and len(value) > schema["maxItems"]:
            raise MCPInvalidParamsError(
                f"{path}: array longer than maxItems {schema['maxItems']}", path=path
            )
        item_schema = schema.get("items")
        if isinstance(item_schema, dict):
            for index, item in enumerate(value):
                _validate_tool_input_schema(item_schema, item, f"{path}[{index}]")
    if isinstance(value, dict):
        properties = schema.get("properties") or {}
        required = schema.get("required") or []
        for key in required:
            if key not in value:
                raise MCPInvalidParamsError(
                    f"{path}: missing required property {key!r}",
                    path=f"{path}.{key}",
                )
        additional = schema.get("additionalProperties", True)
        for key, sub in value.items():
            if key in properties:
                _validate_tool_input_schema(properties[key], sub, f"{path}.{key}")
            elif additional is False:
                raise MCPInvalidParamsError(
                    f"{path}: unexpected property {key!r}",
                    path=f"{path}.{key}",
                )


# --- Tool handlers --------------------------------------------------------
#
# Each handler receives the validated MCP ``arguments`` dict and returns a
# Python object that will be JSON-encoded into the ``content[].text`` payload.
# Handlers reuse the same Mural API helpers (``_authenticated_request``,
# ``_paginate``, body builders) as the CLI ``_cmd_*`` functions but skip the
# argparse Namespace + stdout-printing layer.


def _ns_for_list(arguments: dict[str, Any]) -> argparse.Namespace:
    return argparse.Namespace(
        limit=arguments.get("limit"),
        page_size=arguments.get("page_size"),
    )


def _ns_for_widget_body(arguments: dict[str, Any]) -> argparse.Namespace:
    """Build a Namespace compatible with the ``_build_*_body`` helpers.

    ``style`` accepts a JSON object via MCP; we re-encode it so the existing
    builder (which calls ``_parse_json_arg``/``json.loads``) decodes it back.
    """
    ns = argparse.Namespace(**arguments)
    style = arguments.get("style")
    if isinstance(style, (dict, list)):
        ns.style = json.dumps(style)
    return ns


def _tool_workspace_list(arguments: dict[str, Any]) -> Any:
    kwargs = _list_kwargs(_ns_for_list(arguments))
    return list(_paginate("GET", "/workspaces", **kwargs))


def _tool_workspace_get(arguments: dict[str, Any]) -> Any:
    workspace_id = _resolve_workspace_id(arguments.get("workspace"))
    return _authenticated_request("GET", f"/workspaces/{workspace_id}")


def _tool_room_list(arguments: dict[str, Any]) -> Any:
    workspace_id = _resolve_workspace_id(arguments.get("workspace"))
    return list(
        _paginate(
            "GET",
            f"/workspaces/{workspace_id}/rooms",
            **_list_kwargs(_ns_for_list(arguments)),
        )
    )


def _tool_room_get(arguments: dict[str, Any]) -> Any:
    return _authenticated_request("GET", f"/rooms/{arguments['room']}")


def _tool_mural_list(arguments: dict[str, Any]) -> Any:
    workspace_id = _resolve_workspace_id(arguments.get("workspace"))
    return list(
        _paginate(
            "GET",
            f"/workspaces/{workspace_id}/murals",
            **_list_kwargs(_ns_for_list(arguments)),
        )
    )


def _tool_mural_get(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    return _authenticated_request("GET", f"/murals/{mural_id}")


def _tool_widget_list(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    params: dict[str, Any] = {}
    if arguments.get("type"):
        params["type"] = arguments["type"]
    if arguments.get("parent_id"):
        params["parentId"] = arguments["parent_id"]
    return list(
        _paginate(
            "GET",
            f"/murals/{mural_id}/widgets",
            params=params or None,
            **_list_kwargs(_ns_for_list(arguments)),
        )
    )


def _tool_widget_get(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    return _authenticated_request(
        "GET", f"/murals/{mural_id}/widgets/{arguments['widget']}"
    )


def _tool_widget_update(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    body = arguments["body"]
    if not isinstance(body, dict):
        raise MuralValidationError("body must be a JSON object")
    return _authenticated_request(
        "PATCH",
        f"/murals/{mural_id}/widgets/{arguments['widget']}",
        json_body=body,
    )


def _tool_widget_delete(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    _authenticated_request(
        "DELETE", f"/murals/{mural_id}/widgets/{arguments['widget']}"
    )
    return {"ok": True, "deleted": arguments["widget"]}


def _tool_widget_create_sticky_note(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    body = _build_sticky_note_body(_ns_for_widget_body(arguments))
    return _authenticated_request(
        "POST", f"/murals/{mural_id}/widgets/sticky-note", json_body=body
    )


def _tool_widget_create_textbox(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    body = _build_textbox_body(_ns_for_widget_body(arguments))
    return _authenticated_request(
        "POST", f"/murals/{mural_id}/widgets/textbox", json_body=body
    )


def _tool_widget_create_shape(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    body = _build_shape_body(_ns_for_widget_body(arguments))
    return _authenticated_request(
        "POST", f"/murals/{mural_id}/widgets/shape", json_body=body
    )


def _tool_widget_create_arrow(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    body = _build_arrow_body(_ns_for_widget_body(arguments))
    return _authenticated_request(
        "POST", f"/murals/{mural_id}/widgets/arrow", json_body=body
    )


def _tool_widget_create_image(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    file_path = pathlib.Path(arguments["file"]).expanduser()
    if not file_path.is_file():
        raise MuralValidationError(f"image file not found: {file_path}")
    suffix = file_path.suffix.lower()
    if suffix not in _IMAGE_CONTENT_TYPES:
        raise MuralValidationError(
            f"unsupported image extension {suffix!r}; allowed: "
            + ", ".join(sorted(_IMAGE_CONTENT_TYPES))
        )
    body_bytes = file_path.read_bytes()
    asset = _create_asset_url(mural_id, suffix)
    _upload_to_sas(
        url=asset["url"],
        headers=asset.get("headers") or {},
        body=body_bytes,
        content_type=_IMAGE_CONTENT_TYPES[suffix],
    )
    return _authenticated_request(
        "POST",
        f"/murals/{mural_id}/widgets/image",
        json_body=_build_image_body(
            asset_name=asset["name"], args=_ns_for_widget_body(arguments)
        ),
    )


def _tool_auth_status(_arguments: dict[str, Any]) -> Any:
    path = _resolve_token_store_path()
    store = _load_token_store(path)
    if not store:
        return {"authenticated": False, "token_store": str(path)}
    return {
        "authenticated": True,
        "token_store": str(path),
        "scope": store.get("scope"),
        "expires_at": store.get("expires_at"),
        "has_refresh_token": bool(store.get("refresh_token")),
    }


# --- Tool schemas + registry ---------------------------------------------


_LIMIT_PROPERTY: dict[str, Any] = {
    "type": "integer",
    "minimum": 1,
    "maximum": _MAX_PAGE_SIZE * 100,
    "description": "Maximum total records to return.",
}
_PAGE_SIZE_PROPERTY: dict[str, Any] = {
    "type": "integer",
    "minimum": 1,
    "maximum": _MAX_PAGE_SIZE,
    "description": f"Page size (max {_MAX_PAGE_SIZE}).",
}
_WIDGET_XY_PROPERTY: dict[str, Any] = {"type": "number"}


_TOOL_REGISTRY: dict[str, dict[str, Any]] = {
    "mural_workspace_list": {
        "title": "List workspaces",
        "description": "List Mural workspaces visible to the authenticated user.",
        "input_schema": {
            "type": "object",
            "properties": {"limit": _LIMIT_PROPERTY, "page_size": _PAGE_SIZE_PROPERTY},
            "additionalProperties": False,
        },
        "handler": _tool_workspace_list,
    },
    "mural_workspace_get": {
        "title": "Get workspace",
        "description": (
            "Get a single workspace by id "
            "(defaults to MURAL_DEFAULT_WORKSPACE)."
        ),
        "input_schema": {
            "type": "object",
            "properties": {"workspace": {"type": "string", "minLength": 1}},
            "additionalProperties": False,
        },
        "handler": _tool_workspace_get,
    },
    "mural_room_list": {
        "title": "List rooms",
        "description": "List rooms within a workspace.",
        "input_schema": {
            "type": "object",
            "properties": {
                "workspace": {"type": "string", "minLength": 1},
                "limit": _LIMIT_PROPERTY,
                "page_size": _PAGE_SIZE_PROPERTY,
            },
            "additionalProperties": False,
        },
        "handler": _tool_room_list,
    },
    "mural_room_get": {
        "title": "Get room",
        "description": "Get a single room by id.",
        "input_schema": {
            "type": "object",
            "properties": {"room": {"type": "string", "minLength": 1}},
            "required": ["room"],
            "additionalProperties": False,
        },
        "handler": _tool_room_get,
    },
    "mural_mural_list": {
        "title": "List murals",
        "description": "List murals within a workspace.",
        "input_schema": {
            "type": "object",
            "properties": {
                "workspace": {"type": "string", "minLength": 1},
                "limit": _LIMIT_PROPERTY,
                "page_size": _PAGE_SIZE_PROPERTY,
            },
            "additionalProperties": False,
        },
        "handler": _tool_mural_list,
    },
    "mural_mural_get": {
        "title": "Get mural",
        "description": "Get a single mural by id (workspace.id format).",
        "input_schema": {
            "type": "object",
            "properties": {"mural": {"type": "string", "minLength": 1}},
            "required": ["mural"],
            "additionalProperties": False,
        },
        "handler": _tool_mural_get,
    },
    "mural_widget_list": {
        "title": "List widgets",
        "description": "List widgets on a mural with optional type/parent filter.",
        "input_schema": {
            "type": "object",
            "properties": {
                "mural": {"type": "string", "minLength": 1},
                "type": {"type": "string", "minLength": 1},
                "parent_id": {"type": "string", "minLength": 1},
                "limit": _LIMIT_PROPERTY,
                "page_size": _PAGE_SIZE_PROPERTY,
            },
            "required": ["mural"],
            "additionalProperties": False,
        },
        "handler": _tool_widget_list,
    },
    "mural_widget_get": {
        "title": "Get widget",
        "description": "Get a single widget by id.",
        "input_schema": {
            "type": "object",
            "properties": {
                "mural": {"type": "string", "minLength": 1},
                "widget": {"type": "string", "minLength": 1},
            },
            "required": ["mural", "widget"],
            "additionalProperties": False,
        },
        "handler": _tool_widget_get,
    },
    "mural_widget_update": {
        "title": "Update widget",
        "description": "PATCH a widget with a JSON body.",
        "input_schema": {
            "type": "object",
            "properties": {
                "mural": {"type": "string", "minLength": 1},
                "widget": {"type": "string", "minLength": 1},
                "body": {"type": "object"},
            },
            "required": ["mural", "widget", "body"],
            "additionalProperties": False,
        },
        "handler": _tool_widget_update,
    },
    "mural_widget_delete": {
        "title": "Delete widget",
        "description": "DELETE a widget. Returns {ok: true, deleted: <id>}.",
        "input_schema": {
            "type": "object",
            "properties": {
                "mural": {"type": "string", "minLength": 1},
                "widget": {"type": "string", "minLength": 1},
            },
            "required": ["mural", "widget"],
            "additionalProperties": False,
        },
        "handler": _tool_widget_delete,
    },
    "mural_widget_create_sticky_note": {
        "title": "Create sticky-note widget",
        "description": "Create a sticky-note widget on a mural.",
        "input_schema": {
            "type": "object",
            "properties": {
                "mural": {"type": "string", "minLength": 1},
                "text": {"type": "string", "minLength": 1},
                "x": _WIDGET_XY_PROPERTY,
                "y": _WIDGET_XY_PROPERTY,
                "shape": {"type": "string", "minLength": 1},
                "width": {"type": "number"},
                "height": {"type": "number"},
                "style": {"type": "object"},
            },
            "required": ["mural", "text", "x", "y"],
            "additionalProperties": False,
        },
        "handler": _tool_widget_create_sticky_note,
    },
    "mural_widget_create_textbox": {
        "title": "Create textbox widget",
        "description": "Create a textbox widget on a mural.",
        "input_schema": {
            "type": "object",
            "properties": {
                "mural": {"type": "string", "minLength": 1},
                "text": {"type": "string", "minLength": 1},
                "x": _WIDGET_XY_PROPERTY,
                "y": _WIDGET_XY_PROPERTY,
                "width": {"type": "number"},
                "height": {"type": "number"},
                "style": {"type": "object"},
            },
            "required": ["mural", "text", "x", "y"],
            "additionalProperties": False,
        },
        "handler": _tool_widget_create_textbox,
    },
    "mural_widget_create_shape": {
        "title": "Create shape widget",
        "description": "Create a shape widget on a mural.",
        "input_schema": {
            "type": "object",
            "properties": {
                "mural": {"type": "string", "minLength": 1},
                "shape": {"type": "string", "minLength": 1},
                "x": _WIDGET_XY_PROPERTY,
                "y": _WIDGET_XY_PROPERTY,
                "width": {"type": "number"},
                "height": {"type": "number"},
                "text": {"type": "string"},
                "style": {"type": "object"},
            },
            "required": ["mural", "shape", "x", "y"],
            "additionalProperties": False,
        },
        "handler": _tool_widget_create_shape,
    },
    "mural_widget_create_arrow": {
        "title": "Create arrow widget",
        "description": "Create an arrow widget connecting two points on a mural.",
        "input_schema": {
            "type": "object",
            "properties": {
                "mural": {"type": "string", "minLength": 1},
                "x1": _WIDGET_XY_PROPERTY,
                "y1": _WIDGET_XY_PROPERTY,
                "x2": _WIDGET_XY_PROPERTY,
                "y2": _WIDGET_XY_PROPERTY,
                "style": {"type": "object"},
            },
            "required": ["mural", "x1", "y1", "x2", "y2"],
            "additionalProperties": False,
        },
        "handler": _tool_widget_create_arrow,
    },
    "mural_widget_create_image": {
        "title": "Create image widget",
        "description": (
            "Upload a local image file via Azure Blob SAS and attach it as an "
            "image widget on a mural."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "mural": {"type": "string", "minLength": 1},
                "file": {"type": "string", "minLength": 1},
                "x": _WIDGET_XY_PROPERTY,
                "y": _WIDGET_XY_PROPERTY,
                "width": {"type": "number"},
                "height": {"type": "number"},
                "title": {"type": "string"},
            },
            "required": ["mural", "file", "x", "y"],
            "additionalProperties": False,
        },
        "handler": _tool_widget_create_image,
    },
    "mural_auth_status": {
        "title": "Auth status",
        "description": "Report whether the local token store is authenticated.",
        "input_schema": {
            "type": "object",
            "properties": {},
            "additionalProperties": False,
        },
        "handler": _tool_auth_status,
    },
}


# --- JSON-RPC dispatch ----------------------------------------------------


def _mcp_error_response(
    msg_id: Any,
    code: int,
    message: str,
    data: Any = None,
) -> dict[str, Any]:
    err: dict[str, Any] = {"code": code, "message": message}
    if data is not None:
        err["data"] = data
    return {"jsonrpc": "2.0", "id": msg_id, "error": err}


def _mcp_handle_initialize(params: dict[str, Any]) -> dict[str, Any]:
    if not isinstance(params, dict):
        raise MCPInvalidParamsError("params must be an object")
    requested = params.get("protocolVersion")
    if requested == _MCP_PROTOCOL_PREFERRED:
        chosen = _MCP_PROTOCOL_PREFERRED
    elif requested == _MCP_PROTOCOL_FALLBACK or requested is None:
        chosen = _MCP_PROTOCOL_FALLBACK
    else:
        raise MCPInvalidParamsError(
            f"unsupported protocolVersion {requested!r}",
            path="$.protocolVersion",
        )
    return {
        "protocolVersion": chosen,
        "capabilities": _MCP_CAPABILITIES,
        "serverInfo": _MCP_SERVER_INFO,
    }


def _mcp_list_tools() -> list[dict[str, Any]]:
    tools: list[dict[str, Any]] = []
    for name, spec in _TOOL_REGISTRY.items():
        tools.append(
            {
                "name": name,
                "title": spec["title"],
                "description": spec["description"],
                "inputSchema": spec["input_schema"],
            }
        )
    return tools


def _mcp_tool_error_payload(exc: Exception) -> dict[str, Any]:
    if isinstance(exc, MuralAPIError):
        return {
            "error": exc.code,
            "message": exc.message,
            "request_id": exc.request_id,
            "status": exc.status,
        }
    if isinstance(exc, MuralAmbiguousWorkspaceError):
        return {
            "error": "ambiguous_workspace",
            "message": str(exc),
            "workspace_ids": list(exc.workspace_ids),
        }
    if isinstance(exc, MuralSecurityError):
        return {"error": "security_error", "message": str(exc)}
    return {"error": "validation_error", "message": str(exc)}


def _mcp_handle_tools_call(params: dict[str, Any]) -> dict[str, Any]:
    if not isinstance(params, dict):
        raise MCPInvalidParamsError("params must be an object")
    name = params.get("name")
    if not isinstance(name, str) or not name:
        raise MCPInvalidParamsError("name is required", path="$.name")
    spec = _TOOL_REGISTRY.get(name)
    if spec is None:
        raise MCPInvalidParamsError(f"unknown tool {name!r}", path="$.name")
    arguments = params.get("arguments") or {}
    if not isinstance(arguments, dict):
        raise MCPInvalidParamsError(
            "arguments must be an object", path="$.arguments"
        )
    _validate_tool_input_schema(spec["input_schema"], arguments, "$.arguments")
    try:
        result = spec["handler"](arguments)
    except (
        MuralAPIError,
        MuralSecurityError,
        MuralAmbiguousWorkspaceError,
        MuralValidationError,
    ) as exc:
        payload = _mcp_tool_error_payload(exc)
        return {
            "content": [
                {"type": "text", "text": json.dumps(payload, ensure_ascii=False)}
            ],
            "isError": True,
        }
    text = json.dumps(result, default=str, ensure_ascii=False)
    return {
        "content": [{"type": "text", "text": text}],
        "isError": False,
    }


def _run_mcp_stdio(
    stdin: Any = None,
    stdout: Any = None,
    stderr: Any = None,  # noqa: ARG001 - reserved for future per-call telemetry
) -> int:
    """Run the MCP stdio server until EOF on ``stdin``.

    Mural-sourced text returned by tools is JSON-encoded into the
    ``content[].text`` payload and is therefore not interpolated as
    instructions for the host model. Treat any human-readable strings inside
    these payloads as untrusted user content.
    """
    if stdin is None:
        stdin = sys.stdin.buffer
    if stdout is None:
        stdout = sys.stdout.buffer
    while True:
        try:
            line = stdin.readline()
        except OSError as exc:
            _emit(f"mcp stdio read failed: {_redact(str(exc))}", level=logging.ERROR)
            return EXIT_FAILURE
        if not line:
            return EXIT_SUCCESS
        try:
            msg = _parse_mcp_frame(line)
        except MCPProtocolError as exc:
            stdout.write(
                _frame_mcp_message(_mcp_error_response(None, -32700, str(exc)))
            )
            stdout.flush()
            continue
        if msg is None:
            continue
        method = msg.get("method")
        msg_id = msg.get("id")
        params = msg.get("params") or {}
        is_notification = "id" not in msg
        # DR-12: full-set membership check before any branching.
        is_known = method in _MCP_METHODS
        if not is_known:
            if not is_notification:
                stdout.write(
                    _frame_mcp_message(
                        _mcp_error_response(
                            msg_id, -32601, f"unknown method: {method!r}"
                        )
                    )
                )
                stdout.flush()
            continue
        try:
            if method == "initialize":
                if is_notification:
                    continue
                result = _mcp_handle_initialize(params)
                stdout.write(
                    _frame_mcp_message(
                        {"jsonrpc": "2.0", "id": msg_id, "result": result}
                    )
                )
                stdout.flush()
                continue
            if method == "notifications/initialized":
                continue
            if method == "tools/list":
                if is_notification:
                    continue
                stdout.write(
                    _frame_mcp_message(
                        {
                            "jsonrpc": "2.0",
                            "id": msg_id,
                            "result": {"tools": _mcp_list_tools()},
                        }
                    )
                )
                stdout.flush()
                continue
            if method == "tools/call":
                if is_notification:
                    continue
                result = _mcp_handle_tools_call(params)
                stdout.write(
                    _frame_mcp_message(
                        {"jsonrpc": "2.0", "id": msg_id, "result": result}
                    )
                )
                stdout.flush()
                continue
        except MCPInvalidParamsError as exc:
            if not is_notification:
                stdout.write(
                    _frame_mcp_message(
                        _mcp_error_response(
                            msg_id, -32602, exc.message, data={"path": exc.path}
                        )
                    )
                )
                stdout.flush()
        except MCPProtocolError as exc:
            if not is_notification:
                stdout.write(
                    _frame_mcp_message(
                        _mcp_error_response(msg_id, -32700, str(exc))
                    )
                )
                stdout.flush()
        except Exception as exc:  # noqa: BLE001 - boundary
            _emit(
                f"mcp internal error: {_redact(repr(exc))}", level=logging.ERROR
            )
            if not is_notification:
                stdout.write(
                    _frame_mcp_message(
                        _mcp_error_response(msg_id, -32603, "internal error")
                    )
                )
                stdout.flush()


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="mural",
        description="Mural REST API CLI and (future) MCP server.",
    )
    parser.add_argument(
        "--log-level",
        default="WARNING",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        help="Logging verbosity (default: WARNING).",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    auth = sub.add_parser("auth", help="OAuth 2.0 + PKCE authentication helpers")
    auth_sub = auth.add_subparsers(dest="auth_command", required=True)

    login = auth_sub.add_parser("login", help="Interactive loopback OAuth login")
    login.add_argument(
        "--scopes",
        default=None,
        help="Override the default scope string.",
    )
    login.add_argument(
        "--timeout",
        type=int,
        default=300,
        help="Seconds to wait for the OAuth callback (default: 300).",
    )
    login.set_defaults(func=_cmd_auth_login)

    logout = auth_sub.add_parser("logout", help="Delete the local token store")
    logout.set_defaults(func=_cmd_auth_logout)

    status = auth_sub.add_parser("status", help="Show current auth status")
    status.set_defaults(func=_cmd_auth_status)

    mcp = sub.add_parser("mcp", help="Run the embedded MCP stdio server (Phase 4)")
    mcp.set_defaults(func=_cmd_mcp)

    _add_resource_subcommands(sub)

    return parser


def _add_output_flags(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--fields",
        default=None,
        help="Comma-separated dotted field paths to project from each record.",
    )
    parser.add_argument(
        "--format",
        default="json",
        choices=["json", "table"],
        help="Output format (default: json).",
    )


def _add_pagination_flags(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--limit",
        type=int,
        default=_DEFAULT_PAGE_SIZE,
        help=(
            f"Maximum total records to return (default: {_DEFAULT_PAGE_SIZE})."
        ),
    )
    parser.add_argument(
        "--page-size",
        type=int,
        default=None,
        help=f"Per-page limit forwarded to Mural (max {_MAX_PAGE_SIZE}).",
    )


def _add_xy(parser: argparse.ArgumentParser, *, required: bool = True) -> None:
    parser.add_argument("--x", type=float, required=required, help="X coordinate")
    parser.add_argument("--y", type=float, required=required, help="Y coordinate")
    parser.add_argument("--width", type=float, default=None, help="Width")
    parser.add_argument("--height", type=float, default=None, help="Height")


def _add_resource_subcommands(sub: argparse._SubParsersAction) -> None:
    workspace = sub.add_parser("workspace", help="Workspace operations")
    ws_sub = workspace.add_subparsers(dest="workspace_command", required=True)
    ws_list = ws_sub.add_parser("list", help="List workspaces")
    _add_output_flags(ws_list)
    _add_pagination_flags(ws_list)
    ws_list.set_defaults(func=_cmd_workspace_list)
    ws_get = ws_sub.add_parser("get", help="Get a workspace")
    ws_get.add_argument("--workspace", default=None, help="Workspace id")
    _add_output_flags(ws_get)
    ws_get.set_defaults(func=_cmd_workspace_get)

    room = sub.add_parser("room", help="Room operations")
    room_sub = room.add_subparsers(dest="room_command", required=True)
    room_list = room_sub.add_parser("list", help="List rooms in a workspace")
    room_list.add_argument("--workspace", default=None, help="Workspace id")
    _add_output_flags(room_list)
    _add_pagination_flags(room_list)
    room_list.set_defaults(func=_cmd_room_list)
    room_get = room_sub.add_parser("get", help="Get a room")
    room_get.add_argument("--room", required=True, help="Room id")
    _add_output_flags(room_get)
    room_get.set_defaults(func=_cmd_room_get)

    mural_p = sub.add_parser("mural", help="Mural operations")
    mural_sub = mural_p.add_subparsers(dest="mural_command", required=True)
    mural_list = mural_sub.add_parser("list", help="List murals in a workspace")
    mural_list.add_argument("--workspace", default=None, help="Workspace id")
    _add_output_flags(mural_list)
    _add_pagination_flags(mural_list)
    mural_list.set_defaults(func=_cmd_mural_list)
    mural_get = mural_sub.add_parser("get", help="Get a mural")
    mural_get.add_argument("--mural", required=True, help="Mural id (workspace.slug)")
    _add_output_flags(mural_get)
    mural_get.set_defaults(func=_cmd_mural_get)

    widget = sub.add_parser("widget", help="Widget operations")
    widget_sub = widget.add_subparsers(dest="widget_command", required=True)

    w_list = widget_sub.add_parser("list", help="List widgets on a mural")
    w_list.add_argument("--mural", required=True, help="Mural id")
    w_list.add_argument("--type", default=None, help="Filter by widget type")
    w_list.add_argument("--parent-id", default=None, help="Filter by parent widget id")
    _add_output_flags(w_list)
    _add_pagination_flags(w_list)
    w_list.set_defaults(func=_cmd_widget_list)

    w_get = widget_sub.add_parser("get", help="Get a single widget")
    w_get.add_argument("--mural", required=True, help="Mural id")
    w_get.add_argument("--widget", required=True, help="Widget id")
    _add_output_flags(w_get)
    w_get.set_defaults(func=_cmd_widget_get)

    w_update = widget_sub.add_parser("update", help="Patch a widget with a JSON body")
    w_update.add_argument("--mural", required=True, help="Mural id")
    w_update.add_argument("--widget", required=True, help="Widget id")
    w_update.add_argument("--body", required=True, help="JSON patch body")
    _add_output_flags(w_update)
    w_update.set_defaults(func=_cmd_widget_update)

    w_delete = widget_sub.add_parser("delete", help="Delete a widget")
    w_delete.add_argument("--mural", required=True, help="Mural id")
    w_delete.add_argument("--widget", required=True, help="Widget id")
    w_delete.set_defaults(func=_cmd_widget_delete)

    w_create = widget_sub.add_parser("create", help="Create a widget by type")
    create_sub = w_create.add_subparsers(dest="widget_create_kind", required=True)

    sticky = create_sub.add_parser("sticky-note", help="Create a sticky-note widget")
    sticky.add_argument("--mural", required=True, help="Mural id")
    sticky.add_argument("--text", required=True, help="Sticky note text")
    sticky.add_argument(
        "--shape", default=None, help="Sticky shape (default: rectangle)"
    )
    sticky.add_argument("--style", default=None, help="JSON style overrides")
    _add_xy(sticky)
    _add_output_flags(sticky)
    sticky.set_defaults(func=_cmd_widget_create_sticky_note)

    textbox = create_sub.add_parser("textbox", help="Create a textbox widget")
    textbox.add_argument("--mural", required=True, help="Mural id")
    textbox.add_argument("--text", required=True, help="Textbox text")
    textbox.add_argument("--style", default=None, help="JSON style overrides")
    _add_xy(textbox)
    _add_output_flags(textbox)
    textbox.set_defaults(func=_cmd_widget_create_textbox)

    shape = create_sub.add_parser("shape", help="Create a shape widget")
    shape.add_argument("--mural", required=True, help="Mural id")
    shape.add_argument("--shape", required=True, help="Shape kind")
    shape.add_argument("--text", default=None, help="Optional shape text")
    shape.add_argument("--style", default=None, help="JSON style overrides")
    _add_xy(shape)
    _add_output_flags(shape)
    shape.set_defaults(func=_cmd_widget_create_shape)

    arrow = create_sub.add_parser("arrow", help="Create an arrow widget")
    arrow.add_argument("--mural", required=True, help="Mural id")
    arrow.add_argument("--x1", type=float, required=True, help="Start x")
    arrow.add_argument("--y1", type=float, required=True, help="Start y")
    arrow.add_argument("--x2", type=float, required=True, help="End x")
    arrow.add_argument("--y2", type=float, required=True, help="End y")
    arrow.add_argument("--style", default=None, help="JSON style overrides")
    _add_output_flags(arrow)
    arrow.set_defaults(func=_cmd_widget_create_arrow)

    image = create_sub.add_parser("image", help="Upload an image and create a widget")
    image.add_argument("--mural", required=True, help="Mural id")
    image.add_argument("--file", required=True, help="Local image file path")
    image.add_argument("--title", default=None, help="Optional image title")
    _add_xy(image)
    _add_output_flags(image)
    image.set_defaults(func=_cmd_widget_create_image)


def main(argv: list[str] | None = None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)
    logging.basicConfig(
        level=getattr(logging, args.log_level, logging.WARNING),
        format="%(levelname)s %(name)s: %(message)s",
    )
    func: Callable[[argparse.Namespace], int] = getattr(args, "func", None)
    if func is None:
        parser.print_help(sys.stderr)
        return EXIT_USAGE
    try:
        return func(args)
    except MuralError as exc:
        _emit(str(exc), level=logging.ERROR)
        return EXIT_FAILURE


# Quiet unused-import warnings for stdlib modules reserved for Phase 3+ use.


if __name__ == "__main__":
    sys.exit(main())
