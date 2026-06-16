#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""POSIX signal-handler installation for the Mural CLI.

Carved from ``mural/__init__.py`` (Step 5.3 of the modularization plan).
"""

from __future__ import annotations

import contextlib
import signal
import sys
from typing import Any


def _install_signal_handlers() -> None:
    """Register POSIX signal handlers for SIGINT (130) and SIGPIPE (141).

    Idempotent: safe to call multiple times. SIGPIPE is a no-op on platforms
    that don't define it (e.g. Windows).
    """

    def _on_sigint(_signum: int, _frame: Any) -> None:  # pragma: no cover - thin
        sys.exit(130)

    def _on_sigpipe(_signum: int, _frame: Any) -> None:  # pragma: no cover - thin
        sys.exit(141)

    with contextlib.suppress(ValueError, OSError):
        signal.signal(signal.SIGINT, _on_sigint)
    if hasattr(signal, "SIGPIPE"):
        with contextlib.suppress(ValueError, OSError):
            signal.signal(signal.SIGPIPE, _on_sigpipe)
