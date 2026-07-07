#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

<#
.SYNOPSIS
    Cross-platform launcher for the topic-integrity gate (validate-topics.mjs).
.DESCRIPTION
    Thin wrapper that runs the Node validator, forwarding all arguments and
    propagating its exit code (0 = all topics pass, 1 = a topic FAILs / gate is
    fail-closed, 2 = usage/parse/IO error). The .mjs holds all logic.
.EXAMPLE
    ./validate-topics.ps1 ../../../../scaffold/power-platform/copilot-studio/my-agent
.EXAMPLE
    ./validate-topics.ps1 <scaffold-root> --state <state.json> --json out.json
#>

$ErrorActionPreference = 'Stop'

if (-not (Get-Command -Name 'node' -ErrorAction SilentlyContinue)) {
    Write-Error 'Node.js is required to run validate-topics.mjs but was not found on PATH.'
    exit 2
}

$mjs = Join-Path -Path $PSScriptRoot -ChildPath 'validate-topics.mjs'
& node $mjs @args
exit $LASTEXITCODE
