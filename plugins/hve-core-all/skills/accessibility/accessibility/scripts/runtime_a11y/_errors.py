# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

"""Error types and exit codes for the runtime accessibility harness CLI."""

from __future__ import annotations

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_USAGE = 2


class ScriptError(Exception):
    """Raised when the harness cannot complete the requested operation.

    A non-zero exit code signals a harness error (bad config, missing Node or
    browser, or a blocked target). Probe findings are not errors and never
    raise.
    """

    def __init__(self, message: str, exit_code: int = EXIT_FAILURE) -> None:
        super().__init__(message)
        self.exit_code = exit_code
