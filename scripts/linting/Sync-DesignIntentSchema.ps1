#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

#Requires -Version 7.4

<#
.SYNOPSIS
    Synchronizes the canonical Design Intent schema into the runtime package.

.DESCRIPTION
    Copies the sole canonical authored schema byte-for-byte into the
    accessibility skill's runtime package. The runtime copy is generated and
    must never be edited independently.

.PARAMETER RepoRoot
    Repository root that contains scripts/ and .github/.

.EXAMPLE
    ./scripts/linting/Sync-DesignIntentSchema.ps1

.NOTES
    Runs via: npm run design-intent:schema:sync
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
)

$ErrorActionPreference = 'Stop'

if ($MyInvocation.InvocationName -ne '.') {
    $SourcePath = Join-Path $RepoRoot 'scripts/linting/schemas/design-intent.schema.json'
    $DestinationPath = Join-Path $RepoRoot '.github/skills/accessibility/accessibility/scripts/runtime_a11y/design-intent.schema.json'

    Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath -Force
    Write-Host "Synchronized Design Intent schema to '$DestinationPath'."
}