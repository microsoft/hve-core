# Copyright (c) Microsoft Corporation.
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
        _now=fake_now,
        _sleep=lambda _s: None,
        _bucket=_fresh_bucket(mural_module),
    )

    assert result == {"id": "ws-1"}
    assert len(recorded_http.calls) == 1
    auth = recorded_http.calls[0].headers.get("Authorization")
    assert auth == f"Bearer {TEST_ACCESS_TOKEN}"


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
            ),
            response_factory(b'{"ok":true}', status=200),
        ]
    )

    result = mural_module._authenticated_request(
        "GET",
        "/workspaces",
        token_store_path=fake_token_store,
        _http=recorded_http,
        _now=fake_now,
        _sleep=lambda _s: None,
        _bucket=_fresh_bucket(mural_module),
    )

    assert result == {"ok": True}
    refresh_call, api_call = recorded_http.calls
    assert refresh_call.method == "POST"
    assert mural_module.MURAL_TOKEN_URL.endswith(refresh_call.url.split("/")[-1]) or \
        refresh_call.url == mural_module.MURAL_TOKEN_URL
    assert api_call.headers["Authorization"] == "Bearer new-access"
    persisted = json.loads(fake_token_store.read_text(encoding="utf-8"))
    assert persisted["access_token"] == "new-access"
    assert persisted["refresh_token"] == "new-refresh"


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
            ),
            response_factory(b'{"ok":true}', status=200),
        ]
    )

    result = mural_module._authenticated_request(
        "GET",
        "/workspaces",
        token_store_path=fake_token_store,
        _http=recorded_http,
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
    bucket = mural_module._TokenBucket(
        capacity=2.0, tokens_per_sec=10.0, tokens=0.0
    )
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
