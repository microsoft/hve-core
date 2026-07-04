#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../linting/Test-ExtensionArtifactNaming.ps1')
}

Describe 'Test-ExtensionArtifactNaming' -Tag 'Unit' {
    It 'Returns success when producer and consumer names match' {
        $tempDir = Join-Path $TestDrive 'repo'
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        $workflowPath = Join-Path $tempDir '.github/workflows/extension-package.yml'
        New-Item -ItemType Directory -Path (Split-Path $workflowPath -Parent) -Force | Out-Null
        Set-Content -Path $workflowPath -Value 'name: extension-vsix-${{ matrix.id }}'
        $consumerPath = Join-Path $tempDir '.github/workflows/extension-marketplace-publish.yml'
        New-Item -ItemType Directory -Path (Split-Path $consumerPath -Parent) -Force | Out-Null
        Set-Content -Path $consumerPath -Value 'name: extension-vsix-${{ matrix.id }}'

        $result = Test-ExtensionArtifactNaming -RepoRoot $tempDir
        $result.Passed | Should -BeTrue
    }

    It 'Returns failure when producer and consumer differ' {
        $tempDir = Join-Path $TestDrive 'repo-mismatch'
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        $workflowPath = Join-Path $tempDir '.github/workflows/extension-package.yml'
        New-Item -ItemType Directory -Path (Split-Path $workflowPath -Parent) -Force | Out-Null
        Set-Content -Path $workflowPath -Value 'name: extension-vsix-${{ matrix.id }}'
        $consumerPath = Join-Path $tempDir '.github/workflows/extension-marketplace-publish.yml'
        New-Item -ItemType Directory -Path (Split-Path $consumerPath -Parent) -Force | Out-Null
        Set-Content -Path $consumerPath -Value 'name: extension-vsix-${{ matrix.id }}-other'

        $result = Test-ExtensionArtifactNaming -RepoRoot $tempDir
        $result.Passed | Should -BeFalse
        ($result.Issues -join "`n") | Should -Match 'Producer and consumer artifact names differ'
    }
}
