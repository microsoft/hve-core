# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Report Windows coverage over code supported by the local runtime."""

from __future__ import annotations

import os

import pytest
from coverage import Coverage
from pytest_cov.plugin import CovPlugin

_POSIX_WRITERS = (
    r"^def (?:_open_absolute_directory|_open_destination_directory|"
    r"_reject_unsafe_final_entry|_write_verification_artifact)\("
)


@pytest.hookimpl(trylast=True)
def pytest_sessionstart(session: pytest.Session) -> None:
    """Exclude only unsupported POSIX writer functions on native Windows."""
    if os.name != "nt" or session.config.getoption("no_cov"):
        return
    coverage = Coverage.current()
    if coverage is None:
        raise RuntimeError("Windows coverage requires an active pytest-cov session")
    coverage.exclude(_POSIX_WRITERS)
    plugin = session.config.pluginmanager.get_plugin("_cov")
    if not isinstance(plugin, CovPlugin) or plugin.cov_controller is None:
        raise RuntimeError("Windows coverage requires a pytest-cov report session")
    report_coverage = plugin.cov_controller.combining_cov
    if report_coverage is None:
        raise RuntimeError("Windows coverage requires a combined pytest-cov report")
    # pytest-cov reports from a separate combined Coverage instance.
    report_coverage.exclude(_POSIX_WRITERS)
