#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#
# Test fixture: Shell script with insecure download (no checksum)

echo "Downloading tool without verification..."
curl -o /tmp/tool.tar.gz https://example.com/tool.tar.gz

# This download lacks checksum verification
wget https://example.com/other-tool.zip -O /tmp/other-tool.zip

echo "Done"
