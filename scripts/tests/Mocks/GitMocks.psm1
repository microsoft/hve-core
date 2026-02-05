# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

# GitMocks.psm1
#
# Purpose: Reusable mock helpers for Git CLI and CI environment testing in Pester
# Author: HVE Core Team
#

#region Environment State Management

function Save-CIEnvironment {
    <#
    .SYNOPSIS
    Saves current CI environment variables for later restoration.
    #>
    [CmdletBinding()]
    param()

    $script:SavedEnvironment = @{
        # GitHub Actions
        GITHUB_ACTIONS      = $env:GITHUB_ACTIONS
        GITHUB_OUTPUT       = $env:GITHUB_OUTPUT
        GITHUB_ENV          = $env:GITHUB_ENV
        GITHUB_STEP_SUMMARY = $env:GITHUB_STEP_SUMMARY
        GITHUB_BASE_REF     = $env:GITHUB_BASE_REF
        GITHUB_HEAD_REF     = $env:GITHUB_HEAD_REF
        GITHUB_WORKSPACE    = $env:GITHUB_WORKSPACE
        GITHUB_REPOSITORY   = $env:GITHUB_REPOSITORY
        # Azure DevOps
        TF_BUILD                         = $env:TF_BUILD
        AZURE_PIPELINES                  = $env:AZURE_PIPELINES
        BUILD_ARTIFACTSTAGINGDIRECTORY   = $env:BUILD_ARTIFACTSTAGINGDIRECTORY
        SYSTEM_TEAMFOUNDATIONCOLLECTIONURI = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI
    }

    Write-Verbose "Saved CI environment state"
}

function Restore-CIEnvironment {
    <#
    .SYNOPSIS
    Restores CI environment variables to saved state.
    #>
    [CmdletBinding()]
    param()

    if (-not $script:SavedEnvironment) {
        Write-Warning "No saved environment state found"
        return
    }

    foreach ($key in $script:SavedEnvironment.Keys) {
        if ($null -eq $script:SavedEnvironment[$key]) {
            Remove-Item -Path "env:$key" -ErrorAction SilentlyContinue
        }
        else {
            Set-Item -Path "env:$key" -Value $script:SavedEnvironment[$key]
        }
    }

    Write-Verbose "Restored CI environment state"
}

function Initialize-MockCIEnvironment {
    <#
    .SYNOPSIS
    Sets up a mock CI environment with temp files.

    .DESCRIPTION
    Creates temporary files for GITHUB_OUTPUT, GITHUB_ENV, and GITHUB_STEP_SUMMARY,
    then sets all standard GitHub Actions environment variables to simulate a CI
    environment. Returns a hashtable of temp file paths for verification in tests.
    Use with Remove-MockCIFiles for cleanup in AfterEach blocks.

    .PARAMETER BaseRef
    The base branch for PR context (default: main).

    .PARAMETER HeadRef
    The head branch for PR context (default: feature/test-branch).

    .PARAMETER Workspace
    The workspace path (default: current directory).

    .PARAMETER Repository
    The repository name (default: microsoft/hve-core).

    .OUTPUTS
    Hashtable containing paths to temp files for verification.
    #>
    [CmdletBinding()]
    param(
        [string]$BaseRef = 'main',
        [string]$HeadRef = 'feature/test-branch',
        [string]$Workspace = $PWD.Path,
        [string]$Repository = 'microsoft/hve-core'
    )

    $tempDir = [System.IO.Path]::GetTempPath()
    $guid = [System.Guid]::NewGuid().ToString('N').Substring(0, 8)

    $mockFiles = @{
        Output  = Join-Path $tempDir "ci_output_$guid.txt"
        Env     = Join-Path $tempDir "ci_env_$guid.txt"
        Summary = Join-Path $tempDir "ci_summary_$guid.md"
    }

    # Create empty files
    $mockFiles.Values | ForEach-Object {
        New-Item -Path $_ -ItemType File -Force | Out-Null
    }

    # Set environment variables
    $env:GITHUB_ACTIONS = 'true'
    $env:GITHUB_OUTPUT = $mockFiles.Output
    $env:GITHUB_ENV = $mockFiles.Env
    $env:GITHUB_STEP_SUMMARY = $mockFiles.Summary
    $env:GITHUB_BASE_REF = $BaseRef
    $env:GITHUB_HEAD_REF = $HeadRef
    $env:GITHUB_WORKSPACE = $Workspace
    $env:GITHUB_REPOSITORY = $Repository

    Write-Verbose "Initialized mock CI environment"
    return $mockFiles
}

function Clear-MockCIEnvironment {
    <#
    .SYNOPSIS
    Removes CI platform environment variables (simulates local/non-CI environment).

    .DESCRIPTION
    Clears both GitHub Actions and Azure DevOps environment variables to
    simulate a local development environment for testing.
    #>
    [CmdletBinding()]
    param()

    @(
        # GitHub Actions
        'GITHUB_ACTIONS',
        'GITHUB_OUTPUT',
        'GITHUB_ENV',
        'GITHUB_STEP_SUMMARY',
        'GITHUB_BASE_REF',
        'GITHUB_HEAD_REF',
        'GITHUB_WORKSPACE',
        'GITHUB_REPOSITORY',
        # Azure DevOps
        'TF_BUILD',
        'AZURE_PIPELINES',
        'BUILD_ARTIFACTSTAGINGDIRECTORY',
        'SYSTEM_TEAMFOUNDATIONCOLLECTIONURI'
    ) | ForEach-Object {
        Remove-Item -Path "env:$_" -ErrorAction SilentlyContinue
    }

    Write-Verbose "Cleared CI environment variables"
}

function Remove-MockCIFiles {
    <#
    .SYNOPSIS
    Cleans up temp files created by Initialize-MockCIEnvironment.

    .PARAMETER MockFiles
    Hashtable returned from Initialize-MockCIEnvironment.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$MockFiles
    )

    $MockFiles.Values | ForEach-Object {
        if ($_ -and (Test-Path $_)) {
            Remove-Item $_ -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Verbose "Removed mock CI files"
}

#endregion

#region Git Mock Helpers

function Initialize-GitMocks {
    <#
    .SYNOPSIS
    Sets up standard git command mocks for a test context.

    .DESCRIPTION
    Configures Pester mocks for git merge-base, git diff --name-only, and git rev-parse
    commands within a specified module scope. Enables isolated testing of scripts that
    depend on git CLI output without requiring an actual git repository. The mocks set
    $LASTEXITCODE appropriately based on configured exit codes. Optionally mocks Test-Path
    for file existence checks when MockTestPath is specified.

    .PARAMETER ModuleName
    The module to inject mocks into (e.g., 'LintingHelpers').

    .PARAMETER MergeBase
    SHA to return from git merge-base (default: 'abc123def456789').

    .PARAMETER ChangedFiles
    Array of file paths to return from git diff.

    .PARAMETER MergeBaseExitCode
    Exit code for merge-base command (0 = success).

    .PARAMETER DiffExitCode
    Exit code for diff command (0 = success).

    .PARAMETER MockTestPath
    Also mock Test-Path to return true for file existence checks.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,

        [string]$MergeBase = 'abc123def456789',

        [string[]]$ChangedFiles = @('scripts/linting/Test-Script.ps1', 'docs/README.md'),

        [int]$MergeBaseExitCode = 0,

        [int]$DiffExitCode = 0,

        [switch]$MockTestPath
    )

    # Store values for closure
    $mergeBaseValue = $MergeBase
    $mergeBaseExit = $MergeBaseExitCode
    $changedFilesValue = $ChangedFiles
    $diffExit = $DiffExitCode

    # Mock merge-base
    Mock git {
        $global:LASTEXITCODE = $mergeBaseExit
        if ($mergeBaseExit -eq 0) {
            return $mergeBaseValue
        }
        return $null
    } -ModuleName $ModuleName -ParameterFilter {
        $args[0] -eq 'merge-base'
    }

    # Mock diff --name-only
    Mock git {
        $global:LASTEXITCODE = $diffExit
        return $changedFilesValue
    } -ModuleName $ModuleName -ParameterFilter {
        $args[0] -eq 'diff' -and ($args -contains '--name-only')
    }

    # Mock rev-parse (fallback for HEAD~1)
    Mock git {
        $global:LASTEXITCODE = 0
        return 'HEAD~1-sha'
    } -ModuleName $ModuleName -ParameterFilter {
        $args[0] -eq 'rev-parse'
    }

    # Optionally mock Test-Path for file existence checks
    if ($MockTestPath) {
        Mock Test-Path {
            return $true
        } -ModuleName $ModuleName -ParameterFilter {
            # Match explicit -PathType Leaf OR no PathType specified (default file check)
            $PathType -eq 'Leaf' -or $null -eq $PathType
        }
    }

    Write-Verbose "Initialized git mocks for module: $ModuleName"
}

function Set-GitMockChangedFiles {
    <#
    .SYNOPSIS
    Updates the changed files returned by git diff mock.

    .PARAMETER ModuleName
    The module to inject mocks into.

    .PARAMETER Files
    Array of file paths to return.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,

        [Parameter(Mandatory = $true)]
        [string[]]$Files
    )

    $filesValue = $Files

    Mock git {
        $global:LASTEXITCODE = 0
        return $filesValue
    } -ModuleName $ModuleName -ParameterFilter {
        $args[0] -eq 'diff' -and ($args -contains '--name-only')
    }
}

function Set-GitMockMergeBaseFailure {
    <#
    .SYNOPSIS
    Configures git mock to simulate merge-base failure (triggers fallback logic).

    .PARAMETER ModuleName
    The module to inject mocks into.

    .PARAMETER ExitCode
    Exit code for merge-base failure (default: 128).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,

        [int]$ExitCode = 128
    )

    $exitCodeValue = $ExitCode

    Mock git {
        $global:LASTEXITCODE = $exitCodeValue
        return $null
    } -ModuleName $ModuleName -ParameterFilter {
        $args[0] -eq 'merge-base'
    }
}

#endregion

#region Test Data Generators

function New-MockFileList {
    <#
    .SYNOPSIS
    Generates a list of mock file paths for testing.

    .PARAMETER Count
    Number of files to generate.

    .PARAMETER Extensions
    Array of extensions to cycle through.

    .PARAMETER BasePath
    Base path prefix for generated files.

    .OUTPUTS
    Array of file path strings.
    #>
    [CmdletBinding()]
    param(
        [int]$Count = 5,

        [string[]]$Extensions = @('.ps1', '.md', '.json'),

        [string]$BasePath = 'scripts'
    )

    $files = @()
    for ($i = 1; $i -le $Count; $i++) {
        $ext = $Extensions[($i - 1) % $Extensions.Count]
        $files += "$BasePath/file$i$ext"
    }
    return $files
}

function Get-MockGitDiffScenario {
    <#
    .SYNOPSIS
    Returns predefined test scenarios for git diff testing.

    .PARAMETER Scenario
    The scenario name to return.

    .OUTPUTS
    Array of file paths for the specified scenario.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Empty', 'SingleFile', 'MultipleFiles', 'MixedExtensions', 'DeepPaths')]
        [string]$Scenario
    )

    switch ($Scenario) {
        'Empty' {
            return @()
        }
        'SingleFile' {
            return @('scripts/linting/Test.ps1')
        }
        'MultipleFiles' {
            return @(
                'scripts/linting/Script1.ps1',
                'scripts/linting/Script2.ps1',
                'scripts/linting/Script3.ps1'
            )
        }
        'MixedExtensions' {
            return @(
                'scripts/linting/Script.ps1',
                'docs/README.md',
                'config/settings.json',
                'scripts/security/Check.ps1'
            )
        }
        'DeepPaths' {
            return @(
                'scripts/linting/Modules/Helpers/Utils.psm1',
                'scripts/linting/Modules/Helpers/Tests/Utils.Tests.ps1',
                'docs/api/v1/endpoints/users.md'
            )
        }
    }
}

#endregion

# Export functions
Export-ModuleMember -Function @(
    # Environment management
    'Save-CIEnvironment',
    'Restore-CIEnvironment',
    'Initialize-MockCIEnvironment',
    'Clear-MockCIEnvironment',
    'Remove-MockCIFiles',
    # Git mocks
    'Initialize-GitMocks',
    'Set-GitMockChangedFiles',
    'Set-GitMockMergeBaseFailure',
    # Test data
    'New-MockFileList',
    'Get-MockGitDiffScenario'
)
