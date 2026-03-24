# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Shared constants for GitLab skill tests."""

from __future__ import annotations

TEST_GITLAB_URL = "https://gitlab.example.com"
TEST_GITLAB_TOKEN = "test-token"
TEST_API_URL = f"{TEST_GITLAB_URL}/api/v4"
TEST_PROJECT = "group/project"
TEST_PROJECT_ENCODED = "group%2Fproject"

USAGE_MAIN = (
    "usage: gitlab {mr-list|mr-get|mr-create|mr-update|mr-comment|mr-notes|"
    "pipeline-get|pipeline-run|pipeline-jobs|job-log} [args...]"
)
USAGE_MR_GET = "usage: gitlab mr-get <mr-iid>"
USAGE_MR_CREATE = "usage: gitlab mr-create <json> or pipe JSON to stdin"
USAGE_MR_UPDATE = "usage: gitlab mr-update <mr-iid> <json> or pipe JSON to stdin"
USAGE_MR_COMMENT = "usage: gitlab mr-comment <mr-iid> <body> or pipe body to stdin"
USAGE_MR_NOTES = "usage: gitlab mr-notes <mr-iid> [max]"
USAGE_PIPELINE_GET = "usage: gitlab pipeline-get <pipeline-id>"
USAGE_PIPELINE_RUN = "usage: gitlab pipeline-run <branch-or-tag>"
USAGE_PIPELINE_JOBS = "usage: gitlab pipeline-jobs <pipeline-id>"
USAGE_JOB_LOG = "usage: gitlab job-log <job-id>"

FIELDS_MR = ["iid", "title"]
FIELDS_PIPELINE = ["id", "status"]
FIELDS_JOB = ["id", "name"]
