# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Run the audit as a module (`-m rpi_tracking_audit`) or as a folder path."""

import sys
from pathlib import Path

if not __package__:
    # run as a directory path: make the package importable from its parent folder
    sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from rpi_tracking_audit import main  # noqa: E402

if __name__ == "__main__":
    sys.exit(main())
