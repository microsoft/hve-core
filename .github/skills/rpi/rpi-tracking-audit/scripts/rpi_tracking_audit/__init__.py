# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Audit the RPI tracking artifacts a repository keeps under .copilot-tracking/.

The audit reads the research, plan, plan critique, changes, and review artifacts and the
RPI session state files, groups them by task slug, evaluates the rules in
references/rule-catalog.md, and reports where each task stands, the command that
continues it, and the findings with a remediation plan. Standard library only, no
network access, and read-only: it writes nothing except the report files it is asked to
write.
"""

from ._cli import VERSION, create_parser, main

__all__ = ["VERSION", "create_parser", "main"]
