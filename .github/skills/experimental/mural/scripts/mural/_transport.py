#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""HTTP transport tier for the Mural CLI.

Carved from ``mural/__init__`` (Step 2.2 of the modularization plan).
Contains log redaction, the per-process token-bucket throttle, the OAuth
token-refresh exchange, the core :func:`_authenticated_request` retry/backoff
loop, response-body helpers, error-payload extraction, and the asset upload
helpers (:func:`_create_asset_url`, :func:`_upload_to_sas`).

Helpers that stay in the package ``__init__`` (``_emit``,
``_load_token_store``, ``_resolve_active_profile``, ``_select_profile``,
``_state``) are imported from the package and bound when this submodule is first
imported by ``__init__.py`` (which happens after those helpers are defined).

Intra-package calls to ``_authenticated_request`` and ``_coalesced_refresh``
route through :func:`_pkg` (the live ``mural`` module) so monkeypatch interception
propagates to in-package callers.  ``_coalesced_refresh`` lives in ``_oauth``,
which is re-exported after this submodule, so it is resolved at call time rather
than bound at module load.
"""

from __future__ import annotations

import json
import logging
import os
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from typing import Any, Callable

from . import (  # noqa: E402 - package siblings defined before this import runs
    _emit,
    _load_token_store,
    _resolve_active_profile,
    _select_profile,
    _state,
)
from ._constants import (
    _REDACT_PATTERNS,
    ENV_BASE_URL,
    ENV_CLIENT_ID,
    ENV_CLIENT_SECRET,
    MAX_BACKOFF_SECONDS,
    MAX_RETRIES,
    MURAL_BASE_URL_DEFAULT,
    MURAL_MAX_BODY_BYTES,
    MURAL_TOKEN_URL,
    RATE_LIMIT_BUCKET_CAPACITY,
    RATE_LIMIT_TOKENS_PER_SEC,
    REFRESH_LEEWAY_SECONDS,
    USER_AGENT,
)
from ._credentials import _resolve_token_store_path
from ._exceptions import (
    MuralAPIError,
    MuralError,
    MuralSecurityError,
    MuralValidationError,
    ResponseTooLarge,
)
from ._validation import _validate_asset_url

LOGGER = logging.getLogger("mural")


def _pkg() -> Any:
    """Return the live ``mural`` package module for monkeypatch-aware routing."""
    return sys.modules[__package__]


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


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    """Redirect handler that refuses redirects on the OAuth token endpoint."""

    def _block(
        self,
        req: urllib.request.Request,
        fp: Any,
        code: int,
        msg: str,
        headers: Any,
    ) -> Any:
        location = headers.get("Location", "<unknown>") if headers else "<unknown>"
        raise MuralAPIError(
            code,
            "TOKEN_REDIRECT",
            f"token endpoint attempted redirect to {location}",
        )

    http_error_301 = _block
    http_error_302 = _block
    http_error_303 = _block
    http_error_307 = _block
    http_error_308 = _block


_TOKEN_OPENER = urllib.request.build_opener(_NoRedirect())


def _read_capped(stream: Any, limit: int) -> bytes:
    """Read bytes from ``stream`` up to ``limit`` and raise on overflow.

    Caps unbounded ``urllib`` response bodies so a hostile or misbehaving
    server cannot exhaust process memory. Reads ``limit + 1`` bytes; if the
    stream still has data, the response is rejected with ``ResponseTooLarge``.
    """
    chunk = stream.read(limit + 1)
    if chunk is None:
        return b""
    if len(chunk) > limit:
        raise ResponseTooLarge(f"response body exceeds {limit} bytes")
    return chunk


def _read_response_body(resp_or_err: Any) -> bytes:
    """Read a urllib response or :class:`HTTPError` body with the standard cap.

    Mirrors :func:`_read_capped` semantics but tolerates :class:`HTTPError`
    instances whose ``fp`` is ``None`` (returns ``b""``). Caps total bytes at
    :data:`MURAL_MAX_BODY_BYTES` so a hostile or misbehaving server cannot
    exhaust process memory via either a successful or error response body.
    """
    if getattr(resp_or_err, "fp", resp_or_err) is None:
        return b""
    try:
        return _read_capped(resp_or_err, MURAL_MAX_BODY_BYTES)
    except ResponseTooLarge:
        raise
    except Exception:  # pragma: no cover - defensive
        return b""


def _parse_token_response(resp: Any) -> dict[str, Any]:
    """Validate token endpoint Content-Type, read capped body, return parsed dict."""
    status = getattr(resp, "status", 200)
    headers = getattr(resp, "headers", None)
    content_type = ""
    if headers is not None:
        try:
            content_type = headers.get("Content-Type", "") or ""
        except AttributeError:
            content_type = ""
    if not content_type.lower().startswith("application/json"):
        raise MuralAPIError(
            status,
            "TOKEN_BAD_CONTENT_TYPE",
            f"token endpoint returned non-JSON Content-Type: {content_type}",
        )
    body_bytes = _read_capped(resp, MURAL_MAX_BODY_BYTES)
    text = body_bytes.decode("utf-8", errors="replace")
    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        raise MuralAPIError(status, "TOKEN_INVALID_JSON", text) from exc
    if not isinstance(data, dict):
        raise MuralAPIError(
            status,
            "TOKEN_INVALID_PAYLOAD",
            "token endpoint returned non-object JSON body",
        )
    return data


def _refresh_access_token(
    refresh_token: str,
    *,
    client_id: str,
    client_secret: str | None = None,
    token_url: str = MURAL_TOKEN_URL,
    _http: Callable[..., Any] = _TOKEN_OPENER.open,
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
    LOGGER.debug("POST %s", _redact(token_url))
    try:
        with _http(request) as resp:  # type: ignore[arg-type]
            data = _parse_token_response(resp)
            status = getattr(resp, "status", 200)
    except urllib.error.HTTPError as exc:
        text = _read_response_body(exc).decode("utf-8", errors="replace")
        _emit(f"refresh failed: HTTP {exc.code} {text}", level=logging.ERROR)
        raise MuralAPIError(
            exc.code, "REFRESH_FAILED", text or "refresh failed"
        ) from exc
    if status >= 400:
        raise MuralAPIError(status, "REFRESH_FAILED", json.dumps(data))
    if "access_token" not in data:
        raise MuralAPIError(status, "REFRESH_INVALID_PAYLOAD", "missing access_token")
    return data


def _authenticated_request(
    method: str,
    path: str,
    *,
    params: dict[str, Any] | None = None,
    json_body: Any | None = None,
    token_store_path: Any | None = None,
    base_url: str | None = None,
    env: dict[str, str] | None = None,
    profile: str | None = None,
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
            f"no token store at {store_path}; run `python -m mural auth login` first"
        )
    profile_name = _resolve_active_profile(
        store, src, profile if profile is not None else _state._CLI_PROFILE
    )
    profile_data = _select_profile(store, profile_name)
    profile_client_id = profile_data.get("client_id")
    if profile_client_id and profile_client_id != client_id:
        raise MuralSecurityError(
            f"profile {profile_name!r} was issued for a different client_id; "
            f"run `python -m mural auth login` to refresh"
        )

    expires_at = int(profile_data.get("expires_at") or 0)
    if expires_at - REFRESH_LEEWAY_SECONDS <= _now() and profile_data.get(
        "refresh_token"
    ):
        store = _pkg()._coalesced_refresh(
            store_path,
            profile_data.get("access_token", ""),
            client_id=client_id,
            client_secret=client_secret,
            token_url=MURAL_TOKEN_URL,
            _http=_http,
            _now=_now,
            profile_name=profile_name,
        )
        profile_data = _select_profile(store, profile_name)

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
        request_headers["Authorization"] = f"Bearer {profile_data['access_token']}"
        request = urllib.request.Request(
            url,
            data=encoded,
            method=method.upper(),
            headers=request_headers,
        )
        LOGGER.debug("%s %s", method.upper(), _redact(url))
        try:
            with _http(request) as resp:  # type: ignore[arg-type]
                status = getattr(resp, "status", 200)
                body_bytes = _read_capped(resp, MURAL_MAX_BODY_BYTES)
                _parse_rate_limit_headers(resp.headers, bucket=_bucket)
                return _decode_body(status, body_bytes)
        except urllib.error.HTTPError as exc:
            status = exc.code
            body_bytes = _read_response_body(exc)
            headers_obj = getattr(exc, "headers", None)
            if headers_obj is not None:
                _parse_rate_limit_headers(headers_obj, bucket=_bucket)

            if status == 401 and not refreshed_due_to_401:
                refreshed_due_to_401 = True
                _emit("access token rejected; forcing refresh", level=logging.INFO)
                store = _pkg()._coalesced_refresh(
                    store_path,
                    profile_data["access_token"],
                    client_id=client_id,
                    client_secret=client_secret,
                    token_url=MURAL_TOKEN_URL,
                    _http=_http,
                    _now=_now,
                    profile_name=profile_name,
                )
                profile_data = _select_profile(store, profile_name)
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
            wait = min(MAX_BACKOFF_SECONDS, 2**attempt)
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
        retry_after = float(min(MAX_BACKOFF_SECONDS, 2**attempt))
    return min(MAX_BACKOFF_SECONDS, max(0.0, retry_after))


def _create_asset_url(
    mural_id: str,
    file_extension: str,
    **request_kwargs: Any,
) -> dict[str, Any]:
    """Call ``POST /murals/{id}/assets`` and return the ``value`` payload."""
    if not file_extension:
        raise MuralValidationError("file_extension is required to create an asset url")
    ext = file_extension.lstrip(".").lower()
    response = _pkg()._authenticated_request(
        "POST",
        f"/murals/{mural_id}/assets",
        json_body={"fileExtension": ext},
        **request_kwargs,
    )
    if not isinstance(response, dict):
        raise MuralAPIError(0, "ASSET_URL_INVALID", "asset response is not an object")
    value = (
        response.get("value") if isinstance(response.get("value"), dict) else response
    )
    if not isinstance(value, dict) or "url" not in value or "name" not in value:
        raise MuralAPIError(0, "ASSET_URL_INVALID", "asset response missing url/name")
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
                payload = _read_response_body(resp).decode("utf-8", errors="replace")
                raise MuralAPIError(status, "ASSET_UPLOAD_FAILED", payload)
    except urllib.error.HTTPError as exc:
        text = _read_response_body(exc).decode("utf-8", errors="replace")
        raise MuralAPIError(
            exc.code, "ASSET_UPLOAD_FAILED", text or "upload failed"
        ) from exc
    except urllib.error.URLError as exc:
        raise MuralError(f"network error uploading to asset url: {exc}") from exc
