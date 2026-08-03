#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../extension/Select-PackageVsix.ps1')
    Import-Module (Join-Path $PSScriptRoot '../../extension/Modules/ExtensionIdentity.psm1') -Force
    Import-Module (Join-Path $PSScriptRoot 'ExtensionTestFixtures.psm1') -Force

    function New-VsixAssetDirectory {
        <#
        .SYNOPSIS
        Creates a directory populated with VSIX asset fixtures.
        .PARAMETER Path
        Directory to create.
        .PARAMETER FileName
        VSIX file names to create.
        .OUTPUTS
        [string] Created directory path.
        #>
        [CmdletBinding()]
        [OutputType([string])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Path,

            [Parameter(Mandatory = $true)]
            [AllowEmptyCollection()]
            [string[]]$FileName
        )

        $directory = (New-Item -Path $Path -ItemType Directory -Force).FullName
        foreach ($name in $FileName) {
            Set-FixtureFile -Path (Join-Path $directory $name) -Value 'fixture asset'
        }
        return $directory
    }
}

Describe 'Select-PackageVsix identity matching' -Tag 'Unit' {
    BeforeAll {
        $script:ReleaseAssets = @(
            'hve-core-3.3.106.vsix'
            'hve-core-all-3.3.106.vsix'
            'hve-coding-standards-3.3.106.vsix'
            'hve-security-3.3.106.vsix'
        )
        $script:ReleaseDirectory = New-VsixAssetDirectory -Path (Join-Path $TestDrive 'release-assets') -FileName $script:ReleaseAssets
    }

    It 'Selects <Expected> for package <PackageId>' -ForEach @(
        @{ PackageId = 'hve-core'; Expected = 'hve-core-3.3.106.vsix' }
        @{ PackageId = 'coding-standards'; Expected = 'hve-coding-standards-3.3.106.vsix' }
        @{ PackageId = 'security'; Expected = 'hve-security-3.3.106.vsix' }
    ) {
        Split-Path -Leaf (Select-PackageVsix -AssetDirectory $script:ReleaseDirectory -PackageId $PackageId) |
            Should -BeExactly $Expected
    }

    It 'Selects one asset when a longer identity shares the hve-core prefix' {
        $script:ReleaseAssets | Should -Contain 'hve-core-all-3.3.106.vsix'
        Split-Path -Leaf (Select-PackageVsix -AssetDirectory $script:ReleaseDirectory -PackageId 'hve-core') |
            Should -BeExactly 'hve-core-3.3.106.vsix'
    }

    It 'Returns an absolute path' {
        [System.IO.Path]::IsPathRooted((Select-PackageVsix -AssetDirectory $script:ReleaseDirectory -PackageId 'security')) | Should -BeTrue
    }

    It 'Matches development and pre-release version suffixes' {
        $directory = New-VsixAssetDirectory -Path (Join-Path $TestDrive 'dev-assets') -FileName @('hve-sample-1.2.3-dev.42.vsix')
        Split-Path -Leaf (Select-PackageVsix -AssetDirectory $directory -PackageId 'sample') |
            Should -BeExactly 'hve-sample-1.2.3-dev.42.vsix'
    }

    It 'Matches the extension identity case-insensitively' {
        $directory = New-VsixAssetDirectory -Path (Join-Path $TestDrive 'case-assets') -FileName @('HVE-Sample-1.2.3.vsix')
        Split-Path -Leaf (Select-PackageVsix -AssetDirectory $directory -PackageId 'sample') |
            Should -BeExactly 'HVE-Sample-1.2.3.vsix'
    }

    It 'Ignores assets that carry no version segment' {
        $directory = New-VsixAssetDirectory -Path (Join-Path $TestDrive 'unversioned-assets') -FileName @('hve-sample.vsix', 'hve-sample-1.2.3.vsix')
        Split-Path -Leaf (Select-PackageVsix -AssetDirectory $directory -PackageId 'sample') |
            Should -BeExactly 'hve-sample-1.2.3.vsix'
    }
}

Describe 'Select-PackageVsix failures' -Tag 'Unit' {
    It 'Throws when the asset directory does not exist' {
        $missing = Join-Path $TestDrive 'absent-assets'
        { Select-PackageVsix -AssetDirectory $missing -PackageId 'sample' } |
            Should -Throw "Asset directory not found: $missing"
    }

    It 'Throws when no asset matches the package identity' {
        $directory = New-VsixAssetDirectory -Path (Join-Path $TestDrive 'no-match-assets') -FileName @('hve-core-3.3.106.vsix')
        { Select-PackageVsix -AssetDirectory $directory -PackageId 'sample' } |
            Should -Throw "No VSIX assets matched extension hve-sample for package sample in $directory"
    }

    It 'Throws when the directory contains no assets at all' {
        $directory = New-VsixAssetDirectory -Path (Join-Path $TestDrive 'empty-assets') -FileName @()
        { Select-PackageVsix -AssetDirectory $directory -PackageId 'sample' } |
            Should -Throw "No VSIX assets matched extension hve-sample for package sample in $directory"
    }

    It 'Throws when multiple assets match the same package identity' {
        $directory = New-VsixAssetDirectory -Path (Join-Path $TestDrive 'ambiguous-assets') `
            -FileName @('hve-sample-1.2.3.vsix', 'hve-sample-1.2.4.vsix')
        { Select-PackageVsix -AssetDirectory $directory -PackageId 'sample' } |
            Should -Throw 'Multiple VSIX assets matched extension hve-sample for package sample: hve-sample-1.2.3.vsix, hve-sample-1.2.4.vsix'
    }
}

Describe 'Get-ExtensionVsixPattern' -Tag 'Unit' {
    It 'Matches only the exact identity for <Candidate>' -ForEach @(
        @{ Candidate = 'hve-core-3.3.106.vsix'; Expected = $true }
        @{ Candidate = 'hve-core-3.3.106-dev.7.vsix'; Expected = $true }
        @{ Candidate = 'hve-core-all-3.3.106.vsix'; Expected = $false }
        @{ Candidate = 'my-hve-core-3.3.106.vsix'; Expected = $false }
        @{ Candidate = 'hve-core-3.3.106.vsix.spdx.json'; Expected = $false }
        @{ Candidate = 'hve-core.vsix'; Expected = $false }
    ) {
        ($Candidate -match (Get-ExtensionVsixPattern -ExtensionIdentity 'hve-core')) | Should -Be $Expected
    }

    It 'Builds a download glob scoped to the extension identity' {
        Get-ExtensionVsixGlob -ExtensionIdentity 'hve-core' | Should -BeExactly 'hve-core-*.vsix'
        Get-ExtensionVsixGlob -ExtensionIdentity 'hve-security' | Should -BeExactly 'hve-security-*.vsix'
    }
}

AfterAll {
    Remove-Module ExtensionTestFixtures -Force -ErrorAction SilentlyContinue
    Remove-Module ExtensionIdentity -Force -ErrorAction SilentlyContinue
}
