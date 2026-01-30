# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

# CIHelpers.psm1
#
# Purpose: Shared CI platform detection and output utilities for hve-core scripts.
# Author: HVE Core Team

function Get-CIPlatform {
    <#
    .SYNOPSIS
    Detects the current CI platform.

    .DESCRIPTION
    Returns the CI platform identifier based on environment variables.
    Supports GitHub Actions, Azure DevOps, and local development.

    .OUTPUTS
    System.String - 'github', 'azdo', or 'local'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    if ($env:GITHUB_ACTIONS -eq 'true') {
        return 'github'
    }
    if ($env:TF_BUILD -eq 'True' -or $env:AZURE_PIPELINES -eq 'True') {
        return 'azdo'
    }
    return 'local'
}

function Test-CIEnvironment {
    <#
    .SYNOPSIS
    Tests whether running in a CI environment.

    .DESCRIPTION
    Returns true if running in GitHub Actions or Azure DevOps.

    .OUTPUTS
    System.Boolean - $true if in CI, $false otherwise
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return (Get-CIPlatform) -ne 'local'
}

function Set-CIOutput {
    <#
    .SYNOPSIS
    Sets a CI output variable.

    .DESCRIPTION
    Sets an output variable that can be consumed by subsequent workflow steps.
    Uses GITHUB_OUTPUT for GitHub Actions and task.setvariable for Azure DevOps.

    .PARAMETER Name
    The variable name.

    .PARAMETER Value
    The variable value.

    .PARAMETER IsOutput
    For Azure DevOps, marks the variable as an output variable.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Value,

        [Parameter(Mandatory = $false)]
        [switch]$IsOutput
    )

    $platform = Get-CIPlatform

    switch ($platform) {
        'github' {
            if ($env:GITHUB_OUTPUT) {
                "$Name=$Value" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
            }
            else {
                Write-Verbose "GITHUB_OUTPUT not set, would set: $Name=$Value"
            }
        }
        'azdo' {
            $outputFlag = if ($IsOutput) { ';isOutput=true' } else { '' }
            Write-Output "##vso[task.setvariable variable=$Name$outputFlag]$Value"
        }
        'local' {
            Write-Verbose "CI Output: $Name=$Value"
        }
    }
}

function Write-CIStepSummary {
    <#
    .SYNOPSIS
    Writes content to the CI step summary.

    .DESCRIPTION
    Appends markdown content to the step summary for GitHub Actions.
    For Azure DevOps, outputs as a section header and content.

    .PARAMETER Content
    The markdown content to append.

    .PARAMETER Path
    Path to a file containing markdown content.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Content')]
        [string]$Content,

        [Parameter(Mandatory = $true, ParameterSetName = 'Path')]
        [string]$Path
    )

    $platform = Get-CIPlatform
    $markdown = if ($PSCmdlet.ParameterSetName -eq 'Path') {
        Get-Content -Path $Path -Raw
    }
    else {
        $Content
    }

    switch ($platform) {
        'github' {
            if ($env:GITHUB_STEP_SUMMARY) {
                $markdown | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
            }
            else {
                Write-Verbose "GITHUB_STEP_SUMMARY not set"
                Write-Verbose $markdown
            }
        }
        'azdo' {
            Write-Output "##[section]Step Summary"
            Write-Output $markdown
        }
        'local' {
            Write-Verbose "Step Summary:"
            Write-Verbose $markdown
        }
    }
}

function Write-CIAnnotation {
    <#
    .SYNOPSIS
    Writes a CI annotation (warning, error, notice).

    .DESCRIPTION
    Creates a workflow annotation that appears in the GitHub Actions or Azure DevOps UI.

    .PARAMETER Message
    The annotation message.

    .PARAMETER Level
    The severity level: Warning, Error, or Notice.

    .PARAMETER File
    Optional file path for file-level annotations.

    .PARAMETER Line
    Optional line number for the annotation.

    .PARAMETER Column
    Optional column number for the annotation.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Warning', 'Error', 'Notice')]
        [string]$Level = 'Warning',

        [Parameter(Mandatory = $false)]
        [string]$File,

        [Parameter(Mandatory = $false)]
        [int]$Line,

        [Parameter(Mandatory = $false)]
        [int]$Column
    )

    $platform = Get-CIPlatform

    switch ($platform) {
        'github' {
            $levelLower = $Level.ToLower()
            $annotation = "::$levelLower"
            $params = @()
            if ($File) {
                $normalizedFile = $File -replace '\\', '/'
                $params += "file=$normalizedFile"
            }
            if ($Line -gt 0) { $params += "line=$Line" }
            if ($Column -gt 0) { $params += "col=$Column" }
            if ($params.Count -gt 0) {
                $annotation += " $($params -join ',')"
            }
            Write-Output "$annotation::$Message"
        }
        'azdo' {
            $typeMap = @{
                'Warning' = 'warning'
                'Error'   = 'error'
                'Notice'  = 'info'
            }
            $adoType = $typeMap[$Level]
            $annotation = "##vso[task.logissue type=$adoType"
            if ($File) {
                $annotation += ";sourcepath=$File"
            }
            if ($Line -gt 0) { $annotation += ";linenumber=$Line" }
            if ($Column -gt 0) { $annotation += ";columnnumber=$Column" }
            Write-Output "$annotation]$Message"
        }
        'local' {
            $prefix = switch ($Level) {
                'Warning' { 'WARNING' }
                'Error' { 'ERROR' }
                'Notice' { 'NOTICE' }
            }
            $location = if ($File) { " [$File" + $(if ($Line) { ":$Line" } else { '' }) + ']' } else { '' }
            Write-Warning "$prefix$location $Message"
        }
    }
}

function Set-CITaskResult {
    <#
    .SYNOPSIS
    Sets the CI task/step result status.

    .DESCRIPTION
    Sets the overall result of the current task or step.

    .PARAMETER Result
    The result status: Succeeded, SucceededWithIssues, or Failed.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Succeeded', 'SucceededWithIssues', 'Failed')]
        [string]$Result
    )

    $platform = Get-CIPlatform

    switch ($platform) {
        'github' {
            Write-Verbose "GitHub Actions task result: $Result"
            if ($Result -eq 'Failed') {
                Write-Output "::error::Task failed"
            }
        }
        'azdo' {
            Write-Output "##vso[task.complete result=$Result]"
        }
        'local' {
            Write-Verbose "Task result: $Result"
        }
    }
}

function Publish-CIArtifact {
    <#
    .SYNOPSIS
    Publishes a CI artifact.

    .DESCRIPTION
    Publishes a file or folder as a CI artifact.
    For GitHub Actions, outputs the path for use with actions/upload-artifact.
    For Azure DevOps, uses the artifact.upload command.

    .PARAMETER Path
    The path to the file or folder to publish.

    .PARAMETER Name
    The artifact name.

    .PARAMETER ContainerFolder
    For Azure DevOps, the container folder path within the artifact.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [string]$ContainerFolder
    )

    $platform = Get-CIPlatform

    if (-not (Test-Path $Path)) {
        Write-Warning "Artifact path not found: $Path"
        return
    }

    switch ($platform) {
        'github' {
            Set-CIOutput -Name "artifact-path-$Name" -Value $Path
            Set-CIOutput -Name "artifact-name-$Name" -Value $Name
            Write-Verbose "GitHub artifact ready: $Name at $Path"
        }
        'azdo' {
            $container = if ($ContainerFolder) { $ContainerFolder } else { $Name }
            Write-Output "##vso[artifact.upload containerfolder=$container;artifactname=$Name]$Path"
        }
        'local' {
            Write-Verbose "Artifact: $Name at $Path"
        }
    }
}

Export-ModuleMember -Function @(
    'Get-CIPlatform',
    'Test-CIEnvironment',
    'Set-CIOutput',
    'Write-CIStepSummary',
    'Write-CIAnnotation',
    'Set-CITaskResult',
    'Publish-CIArtifact'
)
