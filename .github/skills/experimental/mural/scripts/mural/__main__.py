#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Entry point for ``python -m mural``."""

import sys

from mural import main

if __name__ == "__main__":
    sys.exit(main())
