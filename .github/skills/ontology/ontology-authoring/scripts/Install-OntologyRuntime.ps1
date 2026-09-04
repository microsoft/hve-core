#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Provisions the portable ontology-authoring runtime from its canonical lock.
.DESCRIPTION
    Finds Python 3.11, delegates frozen runtime-only installation to the shared
    provisioner, and writes optional redacted provisioning evidence.
.PARAMETER Environment
    Optional external virtual-environment path. The default is a platform cache
    directory keyed by the canonical lock digest.
.PARAMETER EvidenceOutput
    Optional path for the runtime provisioning evidence JSON.
.PARAMETER UvCommand
    uv executable name or path. The provisioner requires uv 0.10.8.
.PARAMETER DryRun
    Validates prerequisites and prints the planned frozen synchronization command.
.EXAMPLE
    ./Install-OntologyRuntime.ps1
.EXAMPLE
    ./Install-OntologyRuntime.ps1 -EvidenceOutput ./runtime-evidence.json
.NOTES
    The script never records configured package-index endpoint values.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Environment,

    [Parameter(Mandatory = $false)]
    [string]$EvidenceOutput,

    [Parameter(Mandatory = $false)]
    [string]$UvCommand = 'uv',

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

#region Functions
function Get-PythonInvocation {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    foreach ($Candidate in @('python3.11', 'python3', 'python')) {
        $Command = Get-Command -Name $Candidate -ErrorAction SilentlyContinue
        if ($null -ne $Command) {
            return @{ Command = $Command.Source; Prefix = @() }
        }
    }

    $Launcher = Get-Command -Name 'py' -ErrorAction SilentlyContinue
    if ($null -ne $Launcher) {
        return @{ Command = $Launcher.Source; Prefix = @('-3.11') }
    }

    throw 'Python 3.11 is required. Install Python 3.11 and rerun this command.'
}

function Invoke-OntologyRuntimeProvisioning {
    [CmdletBinding()]
    [OutputType([void])]
    param()

    $Python = Get-PythonInvocation
    $SkillRoot = Split-Path -Parent $PSScriptRoot
    $Provisioner = Join-Path $PSScriptRoot 'ontology_authoring/runtime_provisioning.py'
    $Arguments = @(
        $Python.Prefix
        $Provisioner
        '--project-root'
        $SkillRoot
        '--uv-command'
        $UvCommand
    )
    if ($Environment) {
        $Arguments += @('--environment', $Environment)
    }
    if ($EvidenceOutput) {
        $Arguments += @('--evidence-output', $EvidenceOutput)
    }
    if ($DryRun) {
        $Arguments += '--dry-run'
    }

    & $Python.Command @Arguments
}
#endregion Functions

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-OntologyRuntimeProvisioning
        exit $LASTEXITCODE
    }
    catch {
        Write-Error -ErrorAction Continue "Ontology runtime provisioning failed: $($_.Exception.Message)"
        exit 2
    }
}
#endregion Main Execution