#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../collections/Modules/CollectionHelpers.psm1') -Force
}

Describe 'Resolve-CollectionDescription' -Tag 'Unit' {
    It 'Is exported from CollectionHelpers' {
        Get-Command -Module CollectionHelpers -Name 'Resolve-CollectionDescription' -ErrorAction SilentlyContinue |
            Should -Not -BeNullOrEmpty
    }

    It 'Returns prerelease entry on PreRelease channel when present' {
        $manifest = @{
            description  = 'Default'
            descriptions = @(
                @{ channel = 'stable'; text = 'Stable override' }
                @{ channel = 'prerelease'; text = 'Pre override' }
            )
        }
        $result = Resolve-CollectionDescription -CollectionManifest $manifest -Channel 'PreRelease' -DefaultDescription 'Fallback'
        $result | Should -Be 'Pre override'
    }

    It 'Returns stable entry on Stable channel when present' {
        $manifest = @{
            description  = 'Default'
            descriptions = @(
                @{ channel = 'stable'; text = 'Stable override' }
                @{ channel = 'prerelease'; text = 'Pre override' }
            )
        }
        $result = Resolve-CollectionDescription -CollectionManifest $manifest -Channel 'Stable' -DefaultDescription 'Fallback'
        $result | Should -Be 'Stable override'
    }

    It 'Falls back to top-level description when channel-specific entry is missing' {
        $manifest = @{
            description  = 'Top-level description'
            descriptions = @(
                @{ channel = 'stable'; text = 'Stable only' }
            )
        }
        $result = Resolve-CollectionDescription -CollectionManifest $manifest -Channel 'PreRelease' -DefaultDescription 'Fallback'
        $result | Should -Be 'Top-level description'
    }

    It 'Returns DefaultDescription when both channel entry and top-level description are absent' {
        $manifest = @{ id = 'no-desc' }
        $result = Resolve-CollectionDescription -CollectionManifest $manifest -Channel 'Stable' -DefaultDescription 'Fallback'
        $result | Should -Be 'Fallback'
    }

    It 'Treats whitespace-only channel value as missing and falls back to top-level description' {
        $manifest = @{
            description  = 'Top-level description'
            descriptions = @(
                @{ channel = 'prerelease'; text = '   ' }
            )
        }
        $result = Resolve-CollectionDescription -CollectionManifest $manifest -Channel 'PreRelease' -DefaultDescription 'Fallback'
        $result | Should -Be 'Top-level description'
    }
}
