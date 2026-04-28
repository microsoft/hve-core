# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Shared constants for Mural skill tests."""

from __future__ import annotations

TEST_BASE_URL = "https://app.mural.co/api/public/v1"
TEST_AUTHORIZE_URL = "https://app.mural.co/api/public/v1/authorization/oauth2/"
TEST_TOKEN_URL = "https://app.mural.co/api/public/v1/authorization/oauth2/token"

TEST_CLIENT_ID = "test-client-id"
TEST_CLIENT_SECRET = "test-client-secret"
TEST_REDIRECT_URI = "http://127.0.0.1:53682/callback"

TEST_ACCESS_TOKEN = "test-access-token"
TEST_REFRESH_TOKEN = "test-refresh-token"
TEST_AUTH_CODE = "test-auth-code"
TEST_STATE = "test-state-value"
TEST_CODE_VERIFIER = "test-code-verifier-1234567890123456789012345"

TEST_WORKSPACE_ID = "workspace1"
TEST_ROOM_ID = "1234567890123"
TEST_MURAL_ID = "workspace1.mural-abc123"
TEST_WIDGET_ID = "0-1234567890"
TEST_REQUEST_ID = "req-abc-123"

ENV_BASE_URL = "MURAL_BASE_URL"
ENV_CLIENT_ID = "MURAL_CLIENT_ID"
ENV_CLIENT_SECRET = "MURAL_CLIENT_SECRET"
ENV_REDIRECT_URI = "MURAL_REDIRECT_URI"
ENV_TOKEN_STORE = "MURAL_TOKEN_STORE"
ENV_DEFAULT_WORKSPACE = "MURAL_DEFAULT_WORKSPACE"
ENV_XDG_DATA_HOME = "XDG_DATA_HOME"

MURAL_ENV_VARS = (
    ENV_BASE_URL,
    ENV_CLIENT_ID,
    ENV_CLIENT_SECRET,
    ENV_REDIRECT_URI,
    ENV_TOKEN_STORE,
    ENV_DEFAULT_WORKSPACE,
)
