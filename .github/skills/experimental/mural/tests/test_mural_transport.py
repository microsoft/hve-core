# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Transport layer tests: refresh, retry, throttle, pagination."""

from __future__ import annotations

import json
import pathlib
from typing import Any

import pytest
from test_constants import (
    TEST_ACCESS_TOKEN,
    TEST_REFRESH_TOKEN,
)


def _seed_store(
    path: pathlib.Path,
    *,
    access_token: str = TEST_ACCESS_TOKEN,
    refresh_token: str = TEST_REFRESH_TOKEN,
    expires_at: int = 9_999_999_999,
) -> None:
    payload = {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "expires_at": expires_at,
    }
    path.write_text(json.dumps(payload), encoding="utf-8")


def _fresh_bucket(mural_module: Any) -> Any:
    bucket = mural_module._TokenBucket()
    bucket.tokens = bucket.capacity
    return bucket


def _record_sleeps() -> tuple[list[float], Any]:
    sleeps: list[float] = []

    def _sleep(seconds: float) -> None:
        sleeps.append(float(seconds))

    return sleeps, _sleep


def test_authenticated_request_happy_path_uses_bearer(
    mural_module: Any,
    fake_token_store: pathlib.Path,
    recorded_http: Any,
    response_factory: Any,
    fake_now: Any,
) -> None:
    _seed_store(fake_token_store)
    recorded_http.responses.append(response_factory(b'{"id":"ws-1"}', status=200))

    result = mural_module._authenticated_request(
        "GET",
        "/workspaces/ws-1",
        token_store_path=fake_token_store,
        _http=recorded_http,
        _token_http=recorded_http,
        _now=fake_now,
        _sleep=lambda _s: None,
        _bucket=_fresh_bucket(mural_module),
    )

    assert result == {"id": "ws-1"}
    assert len(recorded_http.calls) == 1
    auth = recorded_http.calls[0].headers.get("Authorization")
    assert auth == f"Bearer {TEST_ACCESS_TOKEN}"


def test_authenticated_request_uses_finite_transport_timeout(
    mural_module: Any,
    fake_token_store: pathlib.Path,
    response_factory: Any,
    fake_now: Any,
) -> None:
    _seed_store(fake_token_store)
    observed: list[float] = []

    def http(request: Any, *, timeout: float) -> Any:
        del request
        observed.append(timeout)
        return response_factory(b'{"ok":true}', status=200)

    mural_module._authenticated_request(
        "GET",
        "/workspaces",
        token_store_path=fake_token_store,
        _http=http,
        _now=fake_now,
        _sleep=lambda _s: None,
        _bucket=_fresh_bucket(mural_module),
    )

    assert observed == [mural_module.REQUEST_TIMEOUT_SECONDS]


def test_authenticated_request_rejects_base_before_token_store_load(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def _fail_load(_path: object) -> None:
        raise AssertionError("token store must not be loaded")

    import mural._transport as transport

    monkeypatch.setattr(transport, "_load_token_store", _fail_load)
    with pytest.raises(mural_module.MuralSecurityError):
        mural_module._authenticated_request(
            "GET",
            "/workspaces",
            base_url="https://evil.example/api/public/v1",
            env={"MURAL_CLIENT_ID": "client"},
        )


def test_authenticated_request_uses_distinct_api_and_token_http(
    mural_module: Any,
    fake_token_store: pathlib.Path,
    recorded_http: Any,
    response_factory: Any,
    fake_now: Any,
) -> None:
    _seed_store(fake_token_store, expires_at=0)
    token_http = type(recorded_http)()
    token_http.responses.append(
        response_factory(
            json.dumps(
                {
                    "access_token": "new-access",
                    "refresh_token": "new-refresh",
                    "expires_in": 3600,
                }
            ).encode(),
            headers={"Content-Type": "application/json"},
        )
    )
    recorded_http.responses.append(response_factory(b'{"ok":true}'))

    result = mural_module._authenticated_request(
        "GET",
        "/workspaces",
        token_store_path=fake_token_store,
        _http=recorded_http,
        _token_http=token_http,
        _now=fake_now,
        _sleep=lambda _s: None,
        _bucket=_fresh_bucket(mural_module),
    )

    assert result == {"ok": True}
    assert len(token_http.calls) == 1
    assert len(recorded_http.calls) == 1


def test_authenticated_request_proactive_refresh_within_leeway(
    mural_module: Any,
    fake_token_store: pathlib.Path,
    recorded_http: Any,
    response_factory: Any,
    fake_now: Any,
) -> None:
    expires_at = int(fake_now()) + mural_module.REFRESH_LEEWAY_SECONDS - 5
    _seed_store(fake_token_store, expires_at=expires_at)
    recorded_http.responses.extend(
        [
            response_factory(
                json.dumps(
                    {
                        "access_token": "new-access",
                        "refresh_token": "new-refresh",
                        "expires_in": 3600,
                    }
                ).encode("utf-8"),
                status=200,
                headers={"Content-Type": "application/json"},
            ),
            response_factory(b'{"ok":true}', status=200),
        ]
    )

    result = mural_module._authenticated_request(
        "GET",
        "/workspaces",
        token_store_path=fake_token_store,
        _http=recorded_http,
        _token_http=recorded_http,
        _now=fake_now,
        _sleep=lambda _s: None,
        _bucket=_fresh_bucket(mural_module),
    )

    assert result == {"ok": True}
    refresh_call, api_call = recorded_http.calls
    assert refresh_call.method == "POST"
    assert (
        mural_module.MURAL_TOKEN_URL.endswith(refresh_call.url.split("/")[-1])
        or refresh_call.url == mural_module.MURAL_TOKEN_URL
    )
    assert api_call.headers["Authorization"] == "Bearer new-access"
    persisted = json.loads(fake_token_store.read_text(encoding="utf-8"))
    profile = persisted["profiles"]["default"]
    assert profile["access_token"] == "new-access"
    assert profile["refresh_token"] == "new-refresh"


def test_authenticated_request_401_forces_single_refresh_then_retry(
    mural_module: Any,
    fake_token_store: pathlib.Path,
    recorded_http: Any,
    response_factory: Any,
    http_error_factory: Any,
    fake_now: Any,
) -> None:
    _seed_store(fake_token_store)
    recorded_http.responses.extend(
        [
            http_error_factory(b'{"message":"expired"}', code=401),
            response_factory(
                json.dumps(
                    {
                        "access_token": "post-refresh",
                        "refresh_token": "rotated",
                        "expires_in": 3600,
                    }
                ).encode("utf-8"),
                status=200,
                headers={"Content-Type": "application/json"},
            ),
            response_factory(b'{"ok":true}', status=200),
        ]
    )

    result = mural_module._authenticated_request(
        "GET",
        "/workspaces",
        token_store_path=fake_token_store,
        _http=recorded_http,
        _token_http=recorded_http,
        _now=fake_now,
        _sleep=lambda _s: None,
        _bucket=_fresh_bucket(mural_module),
    )

    assert result == {"ok": True}
    assert len(recorded_http.calls) == 3
    assert recorded_http.calls[2].headers["Authorization"] == "Bearer post-refresh"


def test_authenticated_request_401_does_not_loop(
    mural_module: Any,
    fake_token_store: pathlib.Path,
    recorded_http: Any,
    response_factory: Any,
    http_error_factory: Any,
    fake_now: Any,
) -> None:
    _seed_store(fake_token_store)
    recorded_http.responses.extend(
        [
            http_error_factory(b'{"message":"expired"}', code=401),
            response_factory(
                json.dumps(
                    {
                        "access_token": "post-refresh",
                        "refresh_token": "rotated",
                        "expires_in": 3600,
                    }
                ).encode("utf-8"),
                status=200,
                headers={"Content-Type": "application/json"},
            ),
            http_error_factory(b'{"message":"still 401"}', code=401),
        ]
    )

    with pytest.raises(mural_module.MuralAPIError) as excinfo:
        mural_module._authenticated_request(
            "GET",
            "/workspaces",
            token_store_path=fake_token_store,
            _http=recorded_http,
            _token_http=recorded_http,
            _now=fake_now,
            _sleep=lambda _s: None,
            _bucket=_fresh_bucket(mural_module),
        )
    assert excinfo.value.status == 401


def test_authenticated_request_retries_429_with_retry_after(
    mural_module: Any,
    fake_token_store: pathlib.Path,
    recorded_http: Any,
    response_factory: Any,
    http_error_factory: Any,
    fake_now: Any,
) -> None:
    _seed_store(fake_token_store)
    recorded_http.responses.extend(
        [
            http_error_factory(
                b'{"message":"too many"}', code=429, headers={"Retry-After": "2"}
            ),
            response_factory(b'{"ok":true}', status=200),
        ]
    )
    sleeps, sleep = _record_sleeps()

    result = mural_module._authenticated_request(
        "GET",
        "/workspaces",
        token_store_path=fake_token_store,
        _http=recorded_http,
        _now=fake_now,
        _sleep=sleep,
        _bucket=_fresh_bucket(mural_module),
    )

    assert result == {"ok": True}
    assert 2.0 in sleeps


def test_authenticated_request_5xx_capped_backoff(
    mural_module: Any,
    fake_token_store: pathlib.Path,
    recorded_http: Any,
    http_error_factory: Any,
    fake_now: Any,
) -> None:
    _seed_store(fake_token_store)
    recorded_http.responses.extend(
        [
            http_error_factory(b"err", code=500)
            for _ in range(mural_module.MAX_RETRIES + 1)
        ]
    )
    sleeps, sleep = _record_sleeps()

    with pytest.raises(mural_module.MuralAPIError) as excinfo:
        mural_module._authenticated_request(
            "GET",
            "/workspaces",
            token_store_path=fake_token_store,
            _http=recorded_http,
            _now=fake_now,
            _sleep=sleep,
            _bucket=_fresh_bucket(mural_module),
        )
    assert excinfo.value.status == 500
    assert all(value <= mural_module.MAX_BACKOFF_SECONDS for value in sleeps)
    assert len(sleeps) == mural_module.MAX_RETRIES


def test_authenticated_request_url_error_retries(
    mural_module: Any,
    fake_token_store: pathlib.Path,
    recorded_http: Any,
    response_factory: Any,
    fake_now: Any,
) -> None:
    import urllib.error

    _seed_store(fake_token_store)
    recorded_http.responses.extend(
        [
            urllib.error.URLError("connection refused"),
            response_factory(b'{"ok":true}', status=200),
        ]
    )
    sleeps, sleep = _record_sleeps()

    result = mural_module._authenticated_request(
        "GET",
        "/workspaces",
        token_store_path=fake_token_store,
        _http=recorded_http,
        _now=fake_now,
        _sleep=sleep,
        _bucket=_fresh_bucket(mural_module),
    )
    assert result == {"ok": True}
    assert sleeps and sleeps[0] >= 1.0


def test_authenticated_request_204_returns_none(
    mural_module: Any,
    fake_token_store: pathlib.Path,
    recorded_http: Any,
    response_factory: Any,
    fake_now: Any,
) -> None:
    _seed_store(fake_token_store)
    recorded_http.responses.append(response_factory(b"", status=204))

    result = mural_module._authenticated_request(
        "DELETE",
        "/widgets/abc",
        token_store_path=fake_token_store,
        _http=recorded_http,
        _now=fake_now,
        _sleep=lambda _s: None,
        _bucket=_fresh_bucket(mural_module),
    )
    assert result is None


def test_token_bucket_acquire_blocks_when_empty(mural_module: Any) -> None:
    bucket = mural_module._TokenBucket(capacity=2.0, tokens_per_sec=10.0, tokens=0.0)
    times = [0.0, 0.0, 1.0]

    def now() -> float:
        return times[-1]

    waits: list[float] = []

    def sleep(seconds: float) -> None:
        waits.append(seconds)
        times.append(times[-1] + seconds)

    mural_module._token_bucket_acquire(bucket=bucket, now=now, sleep=sleep)
    assert waits and waits[0] > 0


def test_token_bucket_acquire_passes_when_tokens_available(
    mural_module: Any,
) -> None:
    bucket = mural_module._TokenBucket(capacity=5.0, tokens_per_sec=10.0, tokens=5.0)
    waits: list[float] = []

    mural_module._token_bucket_acquire(
        bucket=bucket, now=lambda: 0.0, sleep=lambda s: waits.append(s)
    )
    assert waits == []
    assert bucket.tokens < 5.0


def test_paginate_walks_next_cursor(
    mural_module: Any,
    fake_token_store: pathlib.Path,
    recorded_http: Any,
    response_factory: Any,
    fake_now: Any,
) -> None:
    _seed_store(fake_token_store)
    recorded_http.responses.extend(
        [
            response_factory(
                json.dumps({"value": [{"id": "a"}, {"id": "b"}], "next": "c1"}).encode(
                    "utf-8"
                ),
                status=200,
            ),
            response_factory(
                json.dumps({"value": [{"id": "c"}], "next": None}).encode("utf-8"),
                status=200,
            ),
        ]
    )

    items = list(
        mural_module._paginate(
            "GET",
            "/workspaces",
            token_store_path=fake_token_store,
            _http=recorded_http,
            _now=fake_now,
            _sleep=lambda _s: None,
            _bucket=_fresh_bucket(mural_module),
        )
    )

    assert [i["id"] for i in items] == ["a", "b", "c"]
    assert "next=c1" in recorded_http.calls[1].url


def test_paginate_respects_limit(
    mural_module: Any,
    fake_token_store: pathlib.Path,
    recorded_http: Any,
    response_factory: Any,
    fake_now: Any,
) -> None:
    _seed_store(fake_token_store)
    recorded_http.responses.append(
        response_factory(
            json.dumps({"value": [{"id": x} for x in "abcde"], "next": "more"}).encode(
                "utf-8"
            ),
            status=200,
        )
    )

    items = list(
        mural_module._paginate(
            "GET",
            "/workspaces",
            limit=2,
            token_store_path=fake_token_store,
            _http=recorded_http,
            _now=fake_now,
            _sleep=lambda _s: None,
            _bucket=_fresh_bucket(mural_module),
        )
    )
    assert [i["id"] for i in items] == ["a", "b"]


def test_parse_rate_limit_drains_bucket_when_remaining_zero(mural_module: Any) -> None:
    bucket = mural_module._TokenBucket(capacity=20.0, tokens_per_sec=20.0, tokens=20.0)
    headers = {"X-RateLimit-Remaining": "0", "X-RateLimit-Reset": "30"}

    parsed = mural_module._parse_rate_limit_headers(
        headers, bucket=bucket, now=lambda: 100.0
    )
    assert parsed == {"remaining": 0, "reset": 30}
    assert bucket.tokens == 0.0


@pytest.mark.parametrize("code", [301, 302, 303, 307, 308])
def test_api_no_redirect_handler_refuses_without_location_disclosure(
    mural_module: Any, code: int
) -> None:
    import io
    import urllib.request
    from email.message import Message

    request = urllib.request.Request(mural_module.MURAL_BASE_URL_DEFAULT)
    headers = Message()
    headers["Location"] = "https://example.invalid/sensitive"
    with pytest.raises(mural_module.MuralAPIError) as excinfo:
        mural_module._NoRedirect("API_REDIRECT", "Mural API request")._block(
            request, io.BytesIO(), code, "redirect", headers
        )
    assert excinfo.value.code == "API_REDIRECT"
    assert "example.invalid" not in str(excinfo.value)


@pytest.mark.parametrize("code", [301, 302, 303, 307, 308])
def test_sas_no_redirect_handler_refuses(mural_module: Any, code: int) -> None:
    import io
    import urllib.request
    from email.message import Message

    request = urllib.request.Request("https://blob.example.invalid")
    headers = Message()
    with pytest.raises(mural_module.MuralAPIError) as excinfo:
        mural_module._NoRedirect("ASSET_UPLOAD_REDIRECT", "asset upload")._block(
            request, io.BytesIO(), code, "redirect", headers
        )
    assert excinfo.value.code == "ASSET_UPLOAD_REDIRECT"


# ---------------------------------------------------------------------------
# Phase 4: response-body cap, Retry-After backoff, refresh-lock idempotency
# ---------------------------------------------------------------------------


def test_authenticated_request_caps_oversized_response_body(
    mural_module: Any,
    fake_token_store: pathlib.Path,
    recorded_http: Any,
    response_factory: Any,
    fake_now: Any,
) -> None:
    """Step 4.3: bodies exceeding MURAL_MAX_BODY_BYTES raise ResponseTooLarge."""
    _seed_store(fake_token_store)
    big = b"x" * (mural_module.MURAL_MAX_BODY_BYTES + 1024)
    recorded_http.responses.append(response_factory(big, status=200))
    sleeps, _sleep = _record_sleeps()

    with pytest.raises(mural_module.ResponseTooLarge) as excinfo:
        mural_module._authenticated_request(
            "GET",
            "/workspaces/ws-1",
            token_store_path=fake_token_store,
            _http=recorded_http,
            _now=fake_now,
            _sleep=_sleep,
            _bucket=_fresh_bucket(mural_module),
        )

    assert "exceeds" in str(excinfo.value)
    assert str(mural_module.MURAL_MAX_BODY_BYTES) in str(excinfo.value)


def test_authenticated_request_honours_retry_after_then_succeeds(
    mural_module: Any,
    fake_token_store: pathlib.Path,
    recorded_http: Any,
    response_factory: Any,
    http_error_factory: Any,
    fake_now: Any,
) -> None:
    """Step 4.6: 3x429 (Retry-After:2) then 200 -> 3 backoff sleeps + success."""
    _seed_store(fake_token_store)
    for _ in range(mural_module.MAX_RETRIES):
        recorded_http.responses.append(
            http_error_factory(
                b'{"error":"rate_limited"}',
                code=429,
                headers={"Retry-After": "2"},
            )
        )
    recorded_http.responses.append(response_factory(b'{"id":"ws-1"}', status=200))
    sleeps, _sleep = _record_sleeps()

    result = mural_module._authenticated_request(
        "GET",
        "/workspaces/ws-1",
        token_store_path=fake_token_store,
        _http=recorded_http,
        _now=fake_now,
        _sleep=_sleep,
        _bucket=_fresh_bucket(mural_module),
    )

    assert result == {"id": "ws-1"}
    assert len(recorded_http.calls) == mural_module.MAX_RETRIES + 1
    backoff_sleeps = [s for s in sleeps if s == 2.0]
    assert len(backoff_sleeps) == mural_module.MAX_RETRIES


# ---------------------------------------------------------------------------
# expires_at fallback and schema enforcement (SNW #1, #3)
# ---------------------------------------------------------------------------


def test_compute_expires_at_returns_now_when_expires_in_missing(
    mural_module: Any,
) -> None:
    assert mural_module._compute_expires_at(1000.5, None) == 1000


def test_compute_expires_at_returns_now_when_expires_in_zero(
    mural_module: Any,
) -> None:
    assert mural_module._compute_expires_at(1000.0, 0) == 1000


def test_compute_expires_at_returns_now_when_expires_in_negative(
    mural_module: Any,
) -> None:
    assert mural_module._compute_expires_at(1000.0, -5) == 1000


def test_compute_expires_at_adds_positive_expires_in(mural_module: Any) -> None:
    assert mural_module._compute_expires_at(1000.0, 900) == 1900


def test_apply_refresh_writes_int_now_when_expires_in_missing(
    mural_module: Any,
    fake_token_store: pathlib.Path,
    recorded_http: Any,
    response_factory: Any,
    fake_now: Any,
) -> None:
    """A refresh response without ``expires_in`` must persist a stale ``expires_at``."""
    expires_at = int(fake_now()) + mural_module.REFRESH_LEEWAY_SECONDS - 5
    _seed_store(fake_token_store, expires_at=expires_at)
    recorded_http.responses.extend(
        [
            response_factory(
                json.dumps(
                    {
                        "access_token": "no-expires-in-token",
                        "refresh_token": "rotated",
                    }
                ).encode("utf-8"),
                status=200,
                headers={"Content-Type": "application/json"},
            ),
            response_factory(b'{"ok":true}', status=200),
        ]
    )

    mural_module._authenticated_request(
        "GET",
        "/workspaces",
        token_store_path=fake_token_store,
        _http=recorded_http,
        _token_http=recorded_http,
        _now=fake_now,
        _sleep=lambda _s: None,
        _bucket=_fresh_bucket(mural_module),
    )

    persisted = json.loads(fake_token_store.read_text(encoding="utf-8"))
    profile = persisted["profiles"]["default"]
    assert profile["access_token"] == "no-expires-in-token"
    assert profile["expires_at"] == int(fake_now())


def test_proactive_refresh_triggers_when_stored_expires_at_is_zero(
    mural_module: Any,
    fake_token_store: pathlib.Path,
    recorded_http: Any,
    response_factory: Any,
    fake_now: Any,
) -> None:
    """A persisted ``expires_at == 0`` plus a refresh_token must trigger refresh."""
    _seed_store(fake_token_store, expires_at=0)
    recorded_http.responses.extend(
        [
            response_factory(
                json.dumps(
                    {
                        "access_token": "after-zero-refresh",
                        "refresh_token": "rotated",
                        "expires_in": 3600,
                    }
                ).encode("utf-8"),
                status=200,
                headers={"Content-Type": "application/json"},
            ),
            response_factory(b'{"ok":true}', status=200),
        ]
    )

    mural_module._authenticated_request(
        "GET",
        "/workspaces",
        token_store_path=fake_token_store,
        _http=recorded_http,
        _token_http=recorded_http,
        _now=fake_now,
        _sleep=lambda _s: None,
        _bucket=_fresh_bucket(mural_module),
    )

    assert len(recorded_http.calls) == 2
    retry_auth = recorded_http.calls[1].headers["Authorization"]
    assert retry_auth == "Bearer after-zero-refresh"


def test_validate_profile_rejects_missing_expires_at(mural_module: Any) -> None:
    profile = {
        "client_id": "cid",
        "access_token": "tok",
        "token_type": "Bearer",
        "obtained_at": 0,
    }
    with pytest.raises(mural_module.MuralError) as excinfo:
        mural_module._validate_profile(profile)
    assert "missing keys" in str(excinfo.value)
    assert "expires_at" in str(excinfo.value)


def test_validate_profile_rejects_non_int_expires_at(mural_module: Any) -> None:
    profile = {
        "client_id": "cid",
        "access_token": "tok",
        "token_type": "Bearer",
        "obtained_at": 0,
        "expires_at": "2030-01-01",
    }
    with pytest.raises(mural_module.MuralError) as excinfo:
        mural_module._validate_profile(profile)
    assert "'expires_at' must be an integer" in str(excinfo.value)


def test_validate_profile_rejects_bool_expires_at(mural_module: Any) -> None:
    profile = {
        "client_id": "cid",
        "access_token": "tok",
        "token_type": "Bearer",
        "obtained_at": 0,
        "expires_at": True,
    }
    with pytest.raises(mural_module.MuralError) as excinfo:
        mural_module._validate_profile(profile)
    assert "'expires_at' must be an integer" in str(excinfo.value)


def test_validate_profile_accepts_zero_expires_at(mural_module: Any) -> None:
    profile = {
        "client_id": "cid",
        "access_token": "tok",
        "token_type": "Bearer",
        "obtained_at": 0,
        "expires_at": 0,
    }
    mural_module._validate_profile(profile)


def test_migrate_v1_to_v2_backfills_missing_expires_at(mural_module: Any) -> None:
    legacy = {
        "access_token": "tok",
        "refresh_token": "ref",
    }
    envelope = mural_module._migrate_v1_to_v2(legacy)
    profile = envelope["profiles"]["default"]
    assert profile["expires_at"] == 0
    mural_module._validate_profile(profile)


def test_migrate_v1_to_v2_replaces_non_int_expires_at(mural_module: Any) -> None:
    legacy = {
        "access_token": "tok",
        "refresh_token": "ref",
        "expires_at": "not-an-int",
    }
    envelope = mural_module._migrate_v1_to_v2(legacy)
    assert envelope["profiles"]["default"]["expires_at"] == 0


def test_concurrent_401_responses_trigger_single_refresh(
    mural_module: Any,
    fake_token_store: pathlib.Path,
    fake_now: Any,
    response_factory: Any,
    http_error_factory: Any,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """N threads racing on a stale token must coalesce on a single refresh."""
    import threading

    _seed_store(fake_token_store)
    rotated_token = "rotated-access-token"  # noqa: S105 - test fixture

    refresh_calls = {"count": 0}

    def _counting_apply_refresh(store: dict, **kwargs: Any) -> dict:
        refresh_calls["count"] += 1
        profiles = dict(store.get("profiles") or {})
        profile = dict(profiles.get(mural_module.DEFAULT_PROFILE_NAME, {}))
        profile["access_token"] = rotated_token
        profile["expires_at"] = int(kwargs["_now"]()) + 3600
        profiles[mural_module.DEFAULT_PROFILE_NAME] = profile
        return {**store, "profiles": profiles}

    monkeypatch.setattr(mural_module, "_apply_refresh", _counting_apply_refresh)

    def _token_http(*_args: Any, **_kwargs: Any) -> Any:
        raise AssertionError("patched refresh must not use the token network")

    http_lock = threading.Lock()
    api_calls: list[str] = []

    def _http(request: Any, *args: Any, **kwargs: Any) -> Any:
        auth = (request.headers or {}).get("Authorization", "")
        with http_lock:
            api_calls.append(auth)
        if rotated_token in auth:
            return response_factory(b'{"ok": true}', status=200)
        raise http_error_factory(b'{"error":"unauthorized"}', code=401)

    n_threads = 4
    barrier = threading.Barrier(n_threads)
    results: list[Any] = [None] * n_threads
    errors: list[Exception | None] = [None] * n_threads

    def _worker(index: int) -> None:
        try:
            barrier.wait(timeout=5.0)
            results[index] = mural_module._authenticated_request(
                "GET",
                "/workspaces/ws-1",
                token_store_path=fake_token_store,
                _http=_http,
                _token_http=_token_http,
                _now=fake_now,
                _sleep=lambda _s: None,
                _bucket=_fresh_bucket(mural_module),
            )
        except Exception as exc:  # noqa: BLE001 - propagated via assertion
            errors[index] = exc

    threads = [threading.Thread(target=_worker, args=(i,)) for i in range(n_threads)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join(timeout=10.0)

    assert errors == [None] * n_threads, errors
    assert refresh_calls["count"] == 1
    assert all(result == {"ok": True} for result in results)
    rotated_calls = [auth for auth in api_calls if rotated_token in auth]
    assert len(rotated_calls) == n_threads


def test_concurrent_proactive_refreshes_coalesce(
    mural_module: Any,
    fake_token_store: pathlib.Path,
    fake_now: Any,
    response_factory: Any,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """N threads racing in the proactive expiry-leeway window must coalesce."""
    import threading

    _seed_store(fake_token_store, expires_at=int(fake_now()) + 10)
    rotated_token = "rotated-access-token"  # noqa: S105 - test fixture

    refresh_calls = {"count": 0}

    def _counting_apply_refresh(store: dict, **kwargs: Any) -> dict:
        refresh_calls["count"] += 1
        profiles = dict(store.get("profiles") or {})
        profile = dict(profiles.get(mural_module.DEFAULT_PROFILE_NAME, {}))
        profile["access_token"] = rotated_token
        profile["expires_at"] = int(kwargs["_now"]()) + 3600
        profiles[mural_module.DEFAULT_PROFILE_NAME] = profile
        return {**store, "profiles": profiles}

    monkeypatch.setattr(mural_module, "_apply_refresh", _counting_apply_refresh)

    def _token_http(*_args: Any, **_kwargs: Any) -> Any:
        raise AssertionError("patched refresh must not use the token network")

    http_lock = threading.Lock()
    api_calls: list[str] = []

    def _http(request: Any, *args: Any, **kwargs: Any) -> Any:
        auth = (request.headers or {}).get("Authorization", "")
        with http_lock:
            api_calls.append(auth)
        return response_factory(b'{"ok": true}', status=200)

    n_threads = 4
    barrier = threading.Barrier(n_threads)
    results: list[Any] = [None] * n_threads
    errors: list[Exception | None] = [None] * n_threads

    def _worker(index: int) -> None:
        try:
            barrier.wait(timeout=5.0)
            results[index] = mural_module._authenticated_request(
                "GET",
                "/workspaces/ws-1",
                token_store_path=fake_token_store,
                _http=_http,
                _token_http=_token_http,
                _now=fake_now,
                _sleep=lambda _s: None,
                _bucket=_fresh_bucket(mural_module),
            )
        except Exception as exc:  # noqa: BLE001 - propagated via assertion
            errors[index] = exc

    threads = [threading.Thread(target=_worker, args=(i,)) for i in range(n_threads)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join(timeout=10.0)

    assert errors == [None] * n_threads, errors
    assert refresh_calls["count"] == 1
    assert all(result == {"ok": True} for result in results)
    rotated_calls = [auth for auth in api_calls if rotated_token in auth]
    assert len(rotated_calls) == n_threads


# ---------------------------------------------------------------------------
# Issue 2756: ordinary API exceptions carry a bounded, redacted excerpt
# ---------------------------------------------------------------------------

_EXCERPT_SECRET = "s3cr3t-VALUE.with-symbols_42"


def test_error_excerpt_masks_token_shaped_body(mural_module: Any) -> None:
    body = f'{{"refresh_token": "{_EXCERPT_SECRET}"}}'

    result = mural_module._error_excerpt(body)

    assert _EXCERPT_SECRET not in result
    assert '"refresh_token": "***"' in result


def test_error_excerpt_returns_empty_for_empty_body(mural_module: Any) -> None:
    assert mural_module._error_excerpt("") == ""


def test_error_excerpt_bounds_oversized_body(mural_module: Any) -> None:
    limit = mural_module.MAX_ERROR_EXCERPT_CHARS
    body = "A" * (limit * 4)

    result = mural_module._error_excerpt(body)

    assert result.endswith("... (truncated)")
    assert len(result) == limit + len("... (truncated)")


def test_error_excerpt_leaves_short_body_unmarked(mural_module: Any) -> None:
    body = "upstream rejected the request"

    assert mural_module._error_excerpt(body) == body


# ---------------------------------------------------------------------------
# _build_api_error applies the ordinary API diagnostic bound
# ---------------------------------------------------------------------------


def test_build_api_error_bounds_oversized_body(mural_module: Any) -> None:
    """Ordinary non-2xx API responses flow through the bounded diagnostic path.

    ``_read_capped`` allows up to ``MURAL_MAX_BODY_BYTES`` (16 MiB by default),
    four orders of magnitude above the excerpt limit.
    """
    limit = mural_module.MAX_ERROR_EXCERPT_CHARS
    body = ("A" * (limit * 8)).encode("utf-8")

    exc = mural_module._build_api_error(500, body, None)

    assert len(exc.message) == limit + len("... (truncated)")
    assert exc.message.endswith("... (truncated)")


def test_build_api_error_masks_token_in_message(mural_module: Any) -> None:
    """A secret quoted in the upstream `message` field does not reach the exception."""
    body = json.dumps(
        {"code": "BAD_REQUEST", "message": f"rejected access_token={_EXCERPT_SECRET}"}
    ).encode("utf-8")

    exc = mural_module._build_api_error(400, body, None)

    assert _EXCERPT_SECRET not in exc.message
    assert exc.code == "BAD_REQUEST"


def test_build_api_error_masks_token_in_non_json_body(mural_module: Any) -> None:
    """The raw-decode fallback is bounded and redacted too."""
    body = f"gateway failure refresh_token={_EXCERPT_SECRET}".encode("utf-8")

    exc = mural_module._build_api_error(502, body, None)

    assert _EXCERPT_SECRET not in exc.message


def test_build_api_error_falls_back_to_status_for_empty_body(
    mural_module: Any,
) -> None:
    """An empty body still yields a usable message rather than a blank string."""
    exc = mural_module._build_api_error(503, b"", None)

    assert exc.message == "HTTP 503"


def test_refresh_http_error_excludes_raw_refresh_token(
    mural_module: Any,
    recorded_http: Any,
    http_error_factory: Any,
    capsys: pytest.CaptureFixture[str],
) -> None:
    """A failing refresh must not carry the upstream body into the exception."""
    recorded_http.responses.append(
        http_error_factory(
            f'{{"Access_Token":"{_EXCERPT_SECRET}"}}'.encode(),
            code=400,
        )
    )

    with pytest.raises(mural_module.MuralAPIError) as excinfo:
        mural_module._refresh_access_token(
            _EXCERPT_SECRET,
            client_id="client-abc",
            _http=recorded_http,
        )

    assert excinfo.value.code == "REFRESH_FAILED"
    assert excinfo.value.message == "token refresh failed"
    assert _EXCERPT_SECRET not in str(excinfo.value)
    assert _EXCERPT_SECRET not in capsys.readouterr().err


def test_refresh_error_status_excludes_raw_payload(
    mural_module: Any,
    recorded_http: Any,
    response_factory: Any,
) -> None:
    """A returned 4xx refresh payload never enters the typed error."""
    recorded_http.responses.append(
        response_factory(
            f'{{"\\u0041ccess_Token":"{_EXCERPT_SECRET}"}}'.encode(),
            status=400,
            headers={"Content-Type": "application/json"},
        )
    )

    with pytest.raises(mural_module.MuralAPIError) as excinfo:
        mural_module._refresh_access_token(
            _EXCERPT_SECRET,
            client_id="client-abc",
            _http=recorded_http,
        )

    assert excinfo.value.code == "REFRESH_FAILED"
    assert excinfo.value.message == "token refresh failed"
    assert _EXCERPT_SECRET not in str(excinfo.value)


def test_token_invalid_json_excludes_raw_body(
    mural_module: Any,
    response_factory: Any,
) -> None:
    """A malformed token response never enters the exception."""
    resp = response_factory(
        f'{{"Access_Token":"{_EXCERPT_SECRET}',
        status=200,
        headers={"Content-Type": "application/json"},
    )

    with pytest.raises(mural_module.MuralAPIError) as excinfo:
        mural_module._parse_token_response(resp)

    assert excinfo.value.code == "TOKEN_INVALID_JSON"
    assert excinfo.value.message == "token endpoint returned malformed JSON"
    assert _EXCERPT_SECRET not in str(excinfo.value)


def test_sas_error_status_excludes_response_body(
    mural_module: Any, response_factory: Any
) -> None:
    response = response_factory(
        f'{{"Access_Token":"{_EXCERPT_SECRET}"}}',
        status=400,
    )

    with pytest.raises(mural_module.MuralAPIError) as excinfo:
        mural_module._upload_to_sas(
            url="https://example.blob.core.windows.net/c/b?sig=fixture",
            headers={},
            body=b"fixture",
            content_type="text/plain",
            _http=lambda *_args, **_kwargs: response,
        )

    assert excinfo.value.status == 400
    assert excinfo.value.code == "ASSET_UPLOAD_FAILED"
    assert excinfo.value.message == "asset upload failed"
    assert _EXCERPT_SECRET not in str(excinfo.value)


def test_sas_http_error_excludes_response_body(
    mural_module: Any, http_error_factory: Any
) -> None:
    error = http_error_factory(
        f'{{"\\u0041ccess_Token":"{_EXCERPT_SECRET}"}}'.encode(),
        code=403,
    )

    def _raise_error(*_args: Any, **_kwargs: Any) -> None:
        raise error

    with pytest.raises(mural_module.MuralAPIError) as excinfo:
        mural_module._upload_to_sas(
            url="https://example.blob.core.windows.net/c/b?sig=fixture",
            headers={},
            body=b"fixture",
            content_type="text/plain",
            _http=_raise_error,
        )

    assert excinfo.value.status == 403
    assert excinfo.value.code == "ASSET_UPLOAD_FAILED"
    assert excinfo.value.message == "asset upload failed"
    assert _EXCERPT_SECRET not in str(excinfo.value)
