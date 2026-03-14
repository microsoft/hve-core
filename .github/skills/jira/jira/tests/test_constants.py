"""Shared constants for Jira skill tests."""

from __future__ import annotations

TEST_BASE_URL = "https://jira.example.com"
TEST_API_URL = f"{TEST_BASE_URL}/rest/api/2"
TEST_PAT = "server-token"
TEST_USER_EMAIL = "user@example.com"
TEST_API_TOKEN = "cloud-token"
TEST_PROJECT_KEY = "PROJ"
TEST_ISSUE_KEY = "PROJ-123"
TEST_ISSUE_KEY_TWO = "PROJ-456"
TEST_ISSUE_TYPE_ID = "10001"
TEST_JQL = "project = PROJ ORDER BY updated DESC"

FIELDS_ISSUE = ["key", "fields.summary"]
FIELDS_COMMENT = ["_issue", "author.displayName", "body"]

ERROR_BASE_URL_MISSING = "JIRA_BASE_URL is not set"
ERROR_BASE_URL_INVALID = (
    "JIRA_BASE_URL must start with https:// (or http:// for local development)"
)
ERROR_AUTH_MISSING = (
    "Set JIRA_PAT for Jira Server/Data Center or set both JIRA_USER_EMAIL and "
    "JIRA_API_TOKEN for Jira Cloud"
)
ERROR_MAX_RESULTS = "max_results must be a positive integer"
ERROR_ISSUE_TYPE_ID = "issue_type_id must be a positive integer"
ERROR_FIELDS_EMPTY = "--fields requires at least one field name"
USAGE_CREATE = (
    "Provide a JSON payload as an argument or pipe it through stdin for create"
)
USAGE_UPDATE = (
    "Provide a JSON payload as an argument or pipe it through stdin for update"
)
USAGE_COMMENT = (
    "Provide a comment body as an argument or pipe it through stdin for comment"
)
