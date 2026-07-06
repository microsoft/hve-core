#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'PowerShell-Yaml'; RequiredVersion = '0.4.7' }

<#
.SYNOPSIS
    Validates that every consumed extension-vsix-* artifact name has a producing upload-artifact site.

.DESCRIPTION
    Globs every workflow under .github/workflows, parses each with PowerShell-Yaml,
    and derives producer/consumer roles from each step's actions/upload-artifact or
    actions/download-artifact usage. Asserts the one-directional invariant that every
    consumed extension-vsix-* artifact name is produced by at least one upload-artifact
    site. Producer-only names (release-retention uploads) are tolerated, and
    download-artifact steps that pull cross-run (run-id or repository inputs) are skipped
    because they have no in-repo producer.

.PARAMETER RepoRoot
    Repository root to scan.

.EXAMPLE
    ./Test-ExtensionArtifactNaming.ps1 -RepoRoot .
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-WorkflowYamlValue {
    <#
    .SYNOPSIS
        Safely reads a key from a parsed YAML dictionary node.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        $Node,

        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    if ($null -eq $Node) {
        return $null
    }

    if ($Node -is [System.Collections.IDictionary] -and $Node.Contains($Key)) {
        return $Node[$Key]
    }

    return $null
}

function Test-ExtensionArtifactNaming {
    <#
    .SYNOPSIS
        Confirms every consumed extension-vsix-* artifact name has a producing upload-artifact site.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias('RepositoryRoot')]
        [string]$RepoRoot
    )

    $workflowDirectory = Join-Path $RepoRoot '.github/workflows'
    if (-not (Test-Path -Path $workflowDirectory -PathType Container)) {
        throw "Workflows directory not found: $workflowDirectory"
    }

    $workflowFiles = @(
        Get-ChildItem -Path $workflowDirectory -File |
            Where-Object { $_.Extension -in '.yml', '.yaml' }
    )

    $producers = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $consumers = [System.Collections.Generic.List[object]]::new()
    $issues = [System.Collections.Generic.List[string]]::new()

    foreach ($workflowFile in $workflowFiles) {
        try {
            $document = (Get-Content -Path $workflowFile.FullName -Raw) | ConvertFrom-Yaml
        }
        catch {
            # Skip files that are not valid workflow YAML (for example, generated lock files).
            continue
        }

        $jobs = Get-WorkflowYamlValue -Node $document -Key 'jobs'
        if ($jobs -isnot [System.Collections.IDictionary]) {
            continue
        }

        foreach ($jobEntry in $jobs.GetEnumerator()) {
            $steps = Get-WorkflowYamlValue -Node $jobEntry.Value -Key 'steps'
            if ($null -eq $steps) {
                continue
            }

            foreach ($step in $steps) {
                $uses = [string](Get-WorkflowYamlValue -Node $step -Key 'uses')
                if ([string]::IsNullOrWhiteSpace($uses)) {
                    continue
                }

                $with = Get-WorkflowYamlValue -Node $step -Key 'with'
                $artifactName = [string](Get-WorkflowYamlValue -Node $with -Key 'name')
                if ([string]::IsNullOrWhiteSpace($artifactName) -or $artifactName -notlike 'extension-vsix-*') {
                    continue
                }

                if ($uses -match 'actions/upload-artifact') {
                    [void]$producers.Add($artifactName)
                }
                elseif ($uses -match 'actions/download-artifact') {
                    # Cross-run pulls (run-id/repository inputs) have no in-repo producer; skip them.
                    $runId = Get-WorkflowYamlValue -Node $with -Key 'run-id'
                    $repository = Get-WorkflowYamlValue -Node $with -Key 'repository'
                    if ($null -ne $runId -or $null -ne $repository) {
                        continue
                    }

                    $consumers.Add([pscustomobject]@{ Name = $artifactName; File = $workflowFile.Name })
                }
            }
        }
    }

    foreach ($consumer in $consumers) {
        if (-not $producers.Contains($consumer.Name)) {
            $issues.Add("Consumed extension-vsix artifact '$($consumer.Name)' in $($consumer.File) has no producing upload-artifact site.")
        }
    }

    return @{
        Passed    = ($issues.Count -eq 0)
        Issues    = $issues.ToArray()
        Producers = @($producers)
        Consumers = @($consumers | ForEach-Object { $_.Name })
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $result = Test-ExtensionArtifactNaming -RepoRoot $RepoRoot
        if (-not $result.Passed) {
            foreach ($issue in $result.Issues) {
                Write-Error -ErrorAction Continue $issue
            }
            exit 1
        }

        Write-Host 'Extension artifact naming check passed.' -ForegroundColor Green
    }
    catch {
        Write-Error -ErrorAction Continue "Test-ExtensionArtifactNaming failed: $($_.Exception.Message)"
        exit 1
    }
}
