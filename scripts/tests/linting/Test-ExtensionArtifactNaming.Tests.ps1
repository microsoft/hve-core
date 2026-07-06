#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    Import-Module PowerShell-Yaml -ErrorAction Stop
    . (Join-Path $PSScriptRoot '../../linting/Test-ExtensionArtifactNaming.ps1')

    function New-TestWorkflow {
        param(
            [string]$RepoRoot,
            [string]$FileName,
            [string]$JobName,
            [string]$StepName,
            [string]$Uses,
            [hashtable]$With
        )
        $dir = Join-Path $RepoRoot '.github/workflows'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $withLines = foreach ($key in $With.Keys) { "          ${key}: `"$($With[$key])`"" }
        $content = @(
            "name: $JobName"
            'on: push'
            'jobs:'
            "  ${JobName}:"
            '    runs-on: ubuntu-latest'
            '    steps:'
            "      - name: $StepName"
            "        uses: $Uses"
            '        with:'
            $withLines
        ) -join "`n"
        Set-Content -Path (Join-Path $dir $FileName) -Value $content
    }
}

Describe 'Test-ExtensionArtifactNaming' -Tag 'Unit' {
    It 'Passes when a consumed artifact name has a producing upload site' {
        $repo = Join-Path $TestDrive 'match'
        New-TestWorkflow -RepoRoot $repo -FileName 'producer.yml' -JobName 'build' -StepName 'Upload' -Uses 'actions/upload-artifact@v4' -With @{ name = 'extension-vsix-hve-ado'; path = 'dist/*.vsix' }
        New-TestWorkflow -RepoRoot $repo -FileName 'consumer.yml' -JobName 'publish' -StepName 'Download' -Uses 'actions/download-artifact@v4' -With @{ name = 'extension-vsix-hve-ado'; path = './dist' }

        $result = Test-ExtensionArtifactNaming -RepoRoot $repo
        $result.Passed | Should -BeTrue
    }

    It 'Fails when a consumed artifact name has no producing upload site' {
        $repo = Join-Path $TestDrive 'orphan'
        New-TestWorkflow -RepoRoot $repo -FileName 'consumer.yml' -JobName 'publish' -StepName 'Download' -Uses 'actions/download-artifact@v4' -With @{ name = 'extension-vsix-hve-ghost'; path = './dist' }

        $result = Test-ExtensionArtifactNaming -RepoRoot $repo
        $result.Passed | Should -BeFalse
        ($result.Issues -join "`n") | Should -Match 'extension-vsix-hve-ghost'
    }

    It 'Tolerates a producer-only artifact name with no consumer' {
        $repo = Join-Path $TestDrive 'producer-only'
        New-TestWorkflow -RepoRoot $repo -FileName 'producer.yml' -JobName 'build' -StepName 'Upload' -Uses 'actions/upload-artifact@v4' -With @{ name = 'extension-vsix-hve-retain'; path = 'dist/*.vsix' }

        $result = Test-ExtensionArtifactNaming -RepoRoot $repo
        $result.Passed | Should -BeTrue
    }

    It 'Skips cross-run download-artifact steps with run-id or repository inputs' {
        $repo = Join-Path $TestDrive 'cross-run'
        New-TestWorkflow -RepoRoot $repo -FileName 'consumer.yml' -JobName 'publish' -StepName 'Download' -Uses 'actions/download-artifact@v4' -With @{ name = 'extension-vsix-hve-crossrun'; 'run-id' = '123'; repository = 'microsoft/hve-core' }

        $result = Test-ExtensionArtifactNaming -RepoRoot $repo
        $result.Passed | Should -BeTrue
    }
}
