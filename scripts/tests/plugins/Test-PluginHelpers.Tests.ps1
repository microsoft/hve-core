#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()

BeforeAll {
    Import-Module $PSScriptRoot/../../plugins/Modules/PluginHelpers.psm1 -Force
    Import-Module $PSScriptRoot/../../collections/Modules/CollectionHelpers.psm1 -Force
    Import-Module $PSScriptRoot/../../lib/Modules/CIHelpers.psm1 -Force

    $script:channelManifest = @{
        id           = 'channel-fixture'
        name         = 'Channel Fixture'
        description  = 'Base manifest description'
        descriptions = @(
            @{ channel = 'stable'; text = 'Stable channel text for channel-fixture' }
            @{ channel = 'prerelease'; text = 'Experimental: prerelease channel text for channel-fixture' }
        )
    }
}

Describe 'New-PluginManifestContent - channel-aware description' {
    It 'Resolves the stable description when Channel is Stable' {
        $result = New-PluginManifestContent `
            -CollectionId 'channel-fixture' `
            -Collection $channelManifest `
            -Channel 'Stable' `
            -Version '1.0.0'
        $result.description | Should -Be 'Stable channel text for channel-fixture'
    }

    It 'Resolves the prerelease description when Channel is PreRelease' {
        $result = New-PluginManifestContent `
            -CollectionId 'channel-fixture' `
            -Collection $channelManifest `
            -Channel 'PreRelease' `
            -Version '1.0.0'
        $result.description | Should -Be 'Experimental: prerelease channel text for channel-fixture'
    }

    It 'Falls back to the base manifest description when no channel override is present' {
        $fallback = @{
            id          = 'fallback-fixture'
            name        = 'Fallback Fixture'
            description = 'Only base description'
        }
        $result = New-PluginManifestContent `
            -CollectionId 'fallback-fixture' `
            -Collection $fallback `
            -Channel 'PreRelease' `
            -Version '1.0.0'
        $result.description | Should -Be 'Only base description'
    }

    It 'Rejects Channel values outside Stable and PreRelease' {
        { New-PluginManifestContent `
                -CollectionId 'channel-fixture' `
                -Collection $channelManifest `
                -Channel 'Beta' `
                -Version '1.0.0' } | Should -Throw
    }
}

Describe 'New-PluginReadmeContent - channel-aware description' {
    BeforeAll {
        $script:readmeItems = @(
            @{ Name = 'sample-agent'; Description = 'Sample agent'; Kind = 'agent' }
        )
    }

    It 'Emits the stable description in the README body when Channel is Stable' {
        $result = New-PluginReadmeContent `
            -Collection $channelManifest `
            -Items $readmeItems `
            -Channel 'Stable'
        $result | Should -Match 'Stable channel text for channel-fixture'
        $result | Should -Not -Match 'Experimental: prerelease channel text for channel-fixture'
    }

    It 'Emits the prerelease description in the README body when Channel is PreRelease' {
        $result = New-PluginReadmeContent `
            -Collection $channelManifest `
            -Items $readmeItems `
            -Channel 'PreRelease'
        $result | Should -Match 'Experimental: prerelease channel text for channel-fixture'
        $result | Should -Not -Match 'Stable channel text for channel-fixture'
    }

    It 'Rejects Channel values outside Stable and PreRelease' {
        { New-PluginReadmeContent `
                -Collection $channelManifest `
                -Items $readmeItems `
                -Channel 'Beta' } | Should -Throw
    }
}

Describe 'Write-MarketplaceManifest - channel-aware description' {
    BeforeAll {
        $script:tempRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null

        $packageJsonContent = [ordered]@{
            name        = 'test-marketplace'
            description = 'Test marketplace'
            version     = '9.9.9'
            author      = 'Test Author'
        } | ConvertTo-Json -Depth 4
        Set-Content -Path (Join-Path $script:tempRoot 'package.json') -Value $packageJsonContent -Encoding UTF8

        $script:marketplaceCollections = @($channelManifest)
        $script:marketplacePath = Join-Path $script:tempRoot '.github' 'plugin' 'marketplace.json'
    }

    It 'Writes the prerelease description to marketplace.json when Channel is PreRelease' {
        Write-MarketplaceManifest `
            -RepoRoot $script:tempRoot `
            -Collections $script:marketplaceCollections `
            -Channel 'PreRelease' 6>$null
        Test-Path -Path $script:marketplacePath | Should -BeTrue
        $manifest = Get-Content -Path $script:marketplacePath -Raw | ConvertFrom-Json
        $entry = $manifest.plugins | Where-Object { $_.name -eq 'channel-fixture' }
        $entry | Should -Not -BeNullOrEmpty
        $entry.description | Should -Be 'Experimental: prerelease channel text for channel-fixture'
    }

    It 'Writes the stable description to marketplace.json when Channel is Stable' {
        Write-MarketplaceManifest `
            -RepoRoot $script:tempRoot `
            -Collections $script:marketplaceCollections `
            -Channel 'Stable' 6>$null
        Test-Path -Path $script:marketplacePath | Should -BeTrue
        $manifest = Get-Content -Path $script:marketplacePath -Raw | ConvertFrom-Json
        $entry = $manifest.plugins | Where-Object { $_.name -eq 'channel-fixture' }
        $entry | Should -Not -BeNullOrEmpty
        $entry.description | Should -Be 'Stable channel text for channel-fixture'
    }

    It 'Rejects Channel values outside Stable and PreRelease' {
        { Write-MarketplaceManifest `
                -RepoRoot $script:tempRoot `
                -Collections $script:marketplaceCollections `
                -Channel 'Beta' 6>$null } | Should -Throw
    }
}
