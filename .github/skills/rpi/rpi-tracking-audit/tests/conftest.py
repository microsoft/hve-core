# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Shared fixtures for the RPI tracking audit tests."""

from __future__ import annotations

from pathlib import Path

import pytest
from builders import Workspace


@pytest.fixture
def ws(tmp_path: Path) -> Workspace:
    """An empty workspace with a .gitignore that ignores the tracking folder."""
    return Workspace(tmp_path)
