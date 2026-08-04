# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Reports component maturity and target collisions before copying HVE-Core components.
.DESCRIPTION
    Delegates to component-copy.ps1 in report-only mode so the pre-write check
    resolves components exactly as the copy does. Emits one line per selected
    component, then the collision summary. Collisions are component-level: a
    file component collides on its full target path and a skill component
    collides on its target directory.
.PARAMETER HveCoreBasePath
    Root path of the local HVE-Core clone used as the copy source.
.PARAMETER TargetRoot
    Root of the repository that would receive the copied components.
.PARAMETER PackageName
    Marketplace package name whose recipe declares the installable components.
.PARAMETER Component
    Marketplace component paths such as agents/hve-core/rpi-agent.md or skills/rpi/rpi-plan.
.EXAMPLE
    ./scripts/collision-detection.ps1 -HveCoreBasePath ../hve-core -TargetRoot . -PackageName hve-core -Component @('agents/hve-core/rpi-agent.md')
.OUTPUTS
    COMPONENT lines plus COLLISIONS_DETECTED, COLLISION_COMPONENTS, and COLLISION_TARGETS.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$HveCoreBasePath,

    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$TargetRoot,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$PackageName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$Component
)

$ErrorActionPreference = 'Stop'

& (Join-Path $PSScriptRoot 'component-copy.ps1') -HveCoreBasePath $HveCoreBasePath -TargetRoot $TargetRoot `
    -PackageName $PackageName -SelectionName 'custom' -Component $Component -ReportOnly
