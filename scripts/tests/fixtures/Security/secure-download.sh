#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#
# Test fixture: Shell script with secure downloads (checksum verified)

echo "Downloading tool with sha256sum verification..."
curl -o /tmp/tool.tar.gz https://example.com/tool.tar.gz
sha256sum -c /tmp/tool.tar.gz.sha256

echo "Downloading tool with shasum verification..."
wget https://example.com/other-tool.zip -O /tmp/other-tool.zip
shasum -a 256 /tmp/other-tool.zip

echo "Done"
