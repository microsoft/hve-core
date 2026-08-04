# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

# ExtensionIdentity.psm1
# Purpose: Single source for marketplace package ID to VS Code extension identity mapping.

#Requires -Version 7.4

function Get-ExtensionTemplateName {
    <#
    .SYNOPSIS
    Returns the default extension identifier declared by the package template.
    .PARAMETER TemplatePath
    Package template path.
    .OUTPUTS
    [string] Template extension identifier.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TemplatePath
    )

    if (-not (Test-Path -LiteralPath $TemplatePath -PathType Leaf)) {
        throw "Package template not found: $TemplatePath"
    }
    $name = [string]((Get-Content -LiteralPath $TemplatePath -Raw -Encoding utf8 | ConvertFrom-Json).name)
    if ([string]::IsNullOrWhiteSpace($name)) {
        throw "Package template does not declare a name: $TemplatePath"
    }
    return $name
}

function Get-ExtensionIdentity {
    <#
    .SYNOPSIS
    Returns the VS Code extension identifier for a marketplace package ID.
    .PARAMETER PackageId
    Marketplace package ID.
    .PARAMETER TemplateName
    Default extension identifier. Read from the package template when omitted.
    .OUTPUTS
    [string] Extension identifier.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$PackageId,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$TemplateName = ''
    )

    if ($PackageId -ne 'hve-core') { return "hve-$PackageId" }

    if (-not [string]::IsNullOrWhiteSpace($TemplateName)) { return $TemplateName }
    return Get-ExtensionTemplateName -TemplatePath (Join-Path $PSScriptRoot '../../../extension/templates/package.template.json')
}

function Get-ExtensionVsixPattern {
    <#
    .SYNOPSIS
    Returns the anchored VSIX filename pattern for one extension identifier.
    .DESCRIPTION
    Anchoring on the version segment keeps one identifier from matching a
    longer identifier that shares its prefix.
    .PARAMETER ExtensionIdentity
    Extension identifier.
    .OUTPUTS
    [string] Regular expression matching one extension's VSIX filenames.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ExtensionIdentity
    )

    return "^$([regex]::Escape($ExtensionIdentity))-\d+\.\d+\.\d+(-[0-9A-Za-z][0-9A-Za-z.]*)?\.vsix$"
}

function Get-ExtensionVsixGlob {
    <#
    .SYNOPSIS
    Returns the release-asset download glob for one extension identifier.
    .PARAMETER ExtensionIdentity
    Extension identifier.
    .OUTPUTS
    [string] Asset glob.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ExtensionIdentity
    )

    return "$ExtensionIdentity-*.vsix"
}

Export-ModuleMember -Function @(
    'Get-ExtensionIdentity',
    'Get-ExtensionTemplateName',
    'Get-ExtensionVsixGlob',
    'Get-ExtensionVsixPattern'
)
