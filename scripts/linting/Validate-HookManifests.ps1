#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Validates collection-scoped hook manifests under .github/hooks/.

.DESCRIPTION
    Discovers hook manifests at .github/hooks/<collection>/<name>.json and
    validates them against the hook manifest contract: required fields,
    permitted top-level keys, lifecycle event names (Copilot CLI lowercase
    form only), and per-command properties. Declaring an event in both the
    CLI-lowercase and PascalCase form is rejected so each event fires once.

.EXAMPLE
    ./Validate-HookManifests.ps1 -OutputPath 'logs/hook-manifest-validation-results.json'
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = 'logs/hook-manifest-validation-results.json'
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '../lib/Modules/CIHelpers.psm1') -Force

#region Contract

$script:HookAllowedEvents = @(
    'sessionStart',
    'userPromptSubmit',
    'preToolUse',
    'postToolUse',
    'preCompact',
    'subagentStart',
    'subagentStop',
    'stop'
)

$script:HookAllowedTopLevel = @('version', 'description', 'hooks')
$script:HookAllowedCommandProps = @('type', 'command', 'bash', 'powershell', 'windows', 'linux', 'osx', 'cwd', 'env', 'timeout', 'timeoutSec')
$script:HookCommandProps = @('command', 'bash', 'powershell', 'windows', 'linux', 'osx')
$script:HookSchemaRelativePath = 'scripts/linting/schemas/hook-manifest.schema.json'

#endregion Contract

#region Validation Helpers

function Test-HookManifest {
    <#
    .SYNOPSIS
        Validates a parsed hook manifest against the hook manifest contract.

    .PARAMETER Manifest
        Parsed manifest as a hashtable (from ConvertFrom-Json -AsHashtable).

    .OUTPUTS
        [string[]] Array of validation error messages. Empty when valid.

    .EXAMPLE
        Test-HookManifest -Manifest $manifest
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        $Manifest
    )

    $errors = [System.Collections.Generic.List[string]]::new()

    if ($Manifest -isnot [System.Collections.IDictionary]) {
        $errors.Add('manifest must be a JSON object')
        return $errors.ToArray()
    }

    # Unknown top-level keys
    foreach ($key in $Manifest.Keys) {
        if ($script:HookAllowedTopLevel -notcontains $key) {
            $errors.Add("unknown top-level field '$key'")
        }
    }

    # version
    if (-not $Manifest.ContainsKey('version') -or $null -eq $Manifest['version']) {
        $errors.Add("missing required field 'version'")
    }
    elseif ([int]$Manifest['version'] -ne 1) {
        $errors.Add("field 'version' must be 1")
    }

    # description (optional)
    if ($Manifest.ContainsKey('description') -and [string]::IsNullOrWhiteSpace([string]$Manifest['description'])) {
        $errors.Add("field 'description' must be a non-empty string when present")
    }

    # hooks
    if (-not $Manifest.ContainsKey('hooks') -or $null -eq $Manifest['hooks']) {
        $errors.Add("missing required field 'hooks'")
        return $errors.ToArray()
    }

    $hooks = $Manifest['hooks']
    if ($hooks -isnot [System.Collections.IDictionary]) {
        $errors.Add("field 'hooks' must be an object")
        return $errors.ToArray()
    }

    if ($hooks.Keys.Count -eq 0) {
        $errors.Add("field 'hooks' must declare at least one event")
    }

    $lowerToCanonical = @{}
    foreach ($canonicalEvent in $script:HookAllowedEvents) {
        $lowerToCanonical[$canonicalEvent.ToLowerInvariant()] = $canonicalEvent
    }

    foreach ($eventName in $hooks.Keys) {
        if ($script:HookAllowedEvents -ccontains $eventName) {
            # canonical CLI-lowercase form
        }
        elseif ($lowerToCanonical.ContainsKey($eventName.ToLowerInvariant())) {
            $errors.Add("event '$eventName' must use the Copilot CLI lowercase form '$($lowerToCanonical[$eventName.ToLowerInvariant()])'")
            continue
        }
        else {
            $errors.Add("unknown event '$eventName'")
            continue
        }

        $entries = $hooks[$eventName]
        if ($entries -isnot [System.Collections.IEnumerable] -or $entries -is [string] -or $entries -is [System.Collections.IDictionary]) {
            $errors.Add("event '$eventName' must be an array of command entries")
            continue
        }

        $entryList = @($entries)
        if ($entryList.Count -eq 0) {
            $errors.Add("event '$eventName' must declare at least one command entry")
            continue
        }

        $index = 0
        foreach ($entry in $entryList) {
            $label = "event '$eventName' entry [$index]"
            $index++

            if ($entry -isnot [System.Collections.IDictionary]) {
                $errors.Add("$label must be an object")
                continue
            }

            foreach ($prop in $entry.Keys) {
                if ($script:HookAllowedCommandProps -notcontains $prop) {
                    $errors.Add("$label has unknown property '$prop'")
                }
            }

            if (-not $entry.ContainsKey('type')) {
                $errors.Add("$label missing required property 'type'")
            }
            elseif ([string]$entry['type'] -ne 'command') {
                $errors.Add("$label property 'type' must be 'command'")
            }

            $hasCommand = $false
            foreach ($commandProp in $script:HookCommandProps) {
                if ($entry.ContainsKey($commandProp)) {
                    if ([string]::IsNullOrWhiteSpace([string]$entry[$commandProp])) {
                        $errors.Add("$label property '$commandProp' must be a non-empty string")
                    }
                    else {
                        $hasCommand = $true
                    }
                }
            }

            if (-not $hasCommand) {
                $errors.Add("$label must define at least one command property ($($script:HookCommandProps -join ', '))")
            }
        }
    }

    return $errors.ToArray()
}

function Write-HookValidationReport {
    <#
    .SYNOPSIS
        Writes hook manifest validation results to a JSON report.

    .PARAMETER RepoRoot
        Absolute path to the repository root directory.

    .PARAMETER OutputPath
        Output report path, absolute or relative to RepoRoot.

    .PARAMETER ErrorCount
        Total number of validation errors.

    .PARAMETER Results
        Validation results grouped by manifest.

    .OUTPUTS
        [void]
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [string]$OutputPath = 'logs/hook-manifest-validation-results.json',

        [Parameter(Mandatory = $true)]
        [int]$ErrorCount,

        [Parameter(Mandatory = $false)]
        [array]$Results = @()
    )

    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        return
    }

    $resolvedOutputPath = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
        $OutputPath
    }
    else {
        Join-Path -Path $RepoRoot -ChildPath $OutputPath
    }

    $outputDirectory = Split-Path -Path $resolvedOutputPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($outputDirectory) -and -not (Test-Path -Path $outputDirectory -PathType Container)) {
        New-Item -Path $outputDirectory -ItemType Directory -Force | Out-Null
    }

    $report = [ordered]@{
        Timestamp  = (Get-Date).ToUniversalTime().ToString('o')
        Schema     = $script:HookSchemaRelativePath
        ErrorCount = $ErrorCount
        Results    = @($Results)
    }

    $report | ConvertTo-Json -Depth 10 | Set-Content -Path $resolvedOutputPath -Encoding UTF8
}

#endregion Validation Helpers

#region Orchestration

function Invoke-HookManifestValidation {
    <#
    .SYNOPSIS
        Validates all collection-scoped hook manifests in the repository.

    .PARAMETER RepoRoot
        Absolute path to the repository root directory.

    .PARAMETER OutputPath
        Output report path, absolute or relative to RepoRoot.

    .OUTPUTS
        Hashtable with Success bool and ErrorCount int.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [string]$OutputPath = 'logs/hook-manifest-validation-results.json'
    )

    $hooksRoot = Join-Path -Path $RepoRoot -ChildPath '.github' -AdditionalChildPath 'hooks'

    if (-not (Test-Path -Path $hooksRoot -PathType Container)) {
        Write-Host 'No .github/hooks directory found; nothing to validate.'
        Write-HookValidationReport -RepoRoot $RepoRoot -OutputPath $OutputPath -ErrorCount 0 -Results @()
        return @{ Success = $true; ErrorCount = 0 }
    }

    # Collection-scoped manifests live at .github/hooks/<collection>/<name>.json.
    $manifestFiles = @(Get-ChildItem -Path $hooksRoot -Filter '*.json' -File -Recurse |
            Where-Object { $_.Directory.Parent.FullName -eq (Get-Item $hooksRoot).FullName })

    Write-Host "Validating hook manifests ($($manifestFiles.Count) found)..."

    $totalErrors = 0
    $results = @()

    foreach ($file in $manifestFiles) {
        $relativePath = [System.IO.Path]::GetRelativePath($RepoRoot, $file.FullName)
        $fileErrors = @()

        try {
            $manifest = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json -AsHashtable
        }
        catch {
            $fileErrors = @("invalid JSON: $($_.Exception.Message)")
        }

        if ($fileErrors.Count -eq 0) {
            $fileErrors = @(Test-HookManifest -Manifest $manifest)
        }

        $results += @{
            Manifest = $relativePath
            IsValid  = ($fileErrors.Count -eq 0)
            Errors   = @($fileErrors)
        }

        if ($fileErrors.Count -gt 0) {
            $totalErrors += $fileErrors.Count
            Write-Host "  FAIL $relativePath - $($fileErrors.Count) error(s)" -ForegroundColor Red
            foreach ($err in $fileErrors) {
                Write-Host "      $err" -ForegroundColor Red
            }
            Write-Host "      See contract: $script:HookSchemaRelativePath" -ForegroundColor Yellow
        }
        else {
            Write-Host "  OK $relativePath"
        }
    }

    Write-HookValidationReport -RepoRoot $RepoRoot -OutputPath $OutputPath -ErrorCount $totalErrors -Results $results

    return @{
        Success    = ($totalErrors -eq 0)
        ErrorCount = $totalErrors
    }
}

#endregion Orchestration

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
        $RepoRoot = (Get-Item "$ScriptDir/../..").FullName

        $result = Invoke-HookManifestValidation -RepoRoot $RepoRoot -OutputPath $OutputPath

        if (-not $result.Success) {
            throw "Hook manifest validation failed with $($result.ErrorCount) error(s)."
        }

        exit 0
    }
    catch {
        Write-Error "Hook manifest validation failed: $($_.Exception.Message)"
        Write-CIAnnotation -Message $_.Exception.Message -Level Error
        exit 1
    }
}
#endregion
