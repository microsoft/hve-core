#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

<#!
.SYNOPSIS
    Starts the local Mural MCP server for workspace use.

.DESCRIPTION
    Loads Mural OAuth credentials from environment variables or a local
    `.mural-credentials` file, then launches the built mural-mcp server from
    `.mcp/mural-mcp/build/index.js` using stdio transport for VS Code MCP.

.PARAMETER RepoRoot
    Optional. Repository root containing `.mural-credentials` and `.mcp/`.

.EXAMPLE
    ./scripts/mcp/Start-MuralMcp.ps1

.EXAMPLE
    pwsh -File ./scripts/mcp/Start-MuralMcp.ps1 -RepoRoot /path/to/repo
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
)

$ErrorActionPreference = 'Stop'

#region Functions

function Import-MuralCredentials {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    if (-not (Test-Path -Path $FilePath -PathType Leaf)) {
        return
    }

    foreach ($line in Get-Content -Path $FilePath) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) {
            continue
        }

        if ($trimmed -match '^(?:export\s+)?(?<name>MURAL_CLIENT_ID|MURAL_CLIENT_SECRET)=(?<value>.+)$') {
            $name = $Matches.name
            $value = $Matches.value.Trim()
            if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
                $value = $value.Substring(1, $value.Length - 2)
            }

            if ([string]::IsNullOrWhiteSpace((Get-Item -Path Env:$name -ErrorAction SilentlyContinue).Value)) {
                Set-Item -Path Env:$name -Value $value
            }
        }
    }
}

function Test-MuralBuildExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BuildPath
    )

    return (Test-Path -Path $BuildPath -PathType Leaf)
}

function Invoke-StartMuralMcp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRootPath
    )

    $credentialsFile = Join-Path $RepoRootPath '.mural-credentials'
    $buildPath = Join-Path $RepoRootPath '.mcp/mural-mcp/build/index.js'

    Import-MuralCredentials -FilePath $credentialsFile

    if (-not (Test-MuralBuildExists -BuildPath $buildPath)) {
        throw "Mural MCP is not installed at '$buildPath'. Run 'npm run mcp:setup:mural' first."
    }

    if ([string]::IsNullOrWhiteSpace($env:MURAL_CLIENT_ID) -or [string]::IsNullOrWhiteSpace($env:MURAL_CLIENT_SECRET)) {
        throw "Mural credentials are missing. Create '.mural-credentials' from '.mural-credentials.example' or set MURAL_CLIENT_ID and MURAL_CLIENT_SECRET in your environment."
    }

    & node $buildPath
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        exit $exitCode
    }
}

#endregion Functions

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-StartMuralMcp -RepoRootPath $RepoRoot
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Start-MuralMcp.ps1 failed: $($_.Exception.Message)"
        exit 1
    }
}
#endregion Main Execution