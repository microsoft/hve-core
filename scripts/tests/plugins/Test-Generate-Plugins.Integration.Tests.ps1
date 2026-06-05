#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    . $PSScriptRoot/../../plugins/Generate-Plugins.ps1
    # PluginHelpers re-imports CollectionHelpers with -Force during dot-sourcing,
    # which removes it from the caller's scope; re-import to access the resolver.
    Import-Module (Join-Path $PSScriptRoot '../../collections/Modules/CollectionHelpers.psm1') -Force

    function New-IntegrationFixture {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Root,

            [Parameter(Mandatory = $true)]
            [string]$StableDescription,

            [Parameter(Mandatory = $true)]
            [string]$PrereleaseDescription
        )

        New-Item -ItemType Directory -Path $Root -Force | Out-Null

        @{
            name        = 'hve-core'
            version     = '0.0.0-test'
            description = 'test'
            author      = 'test-author'
        } | ConvertTo-Json | Set-Content -Path (Join-Path $Root 'package.json')

        $collectionsDir = Join-Path $Root 'collections'
        New-Item -ItemType Directory -Path $collectionsDir -Force | Out-Null

        $agentsDir = Join-Path $Root '.github/agents/fixture'
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
        @'
---
description: "Fixture agent"
---
'@ | Set-Content -Path (Join-Path $agentsDir 'fixture.agent.md')

        New-Item -ItemType Directory -Path (Join-Path $Root 'docs/templates') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $Root 'scripts/lib') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $Root 'plugins') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $Root '.github/plugin') -Force | Out-Null

        # hve-core-all is required by Update-HveCoreAllCollection
        @"
id: hve-core-all
name: hve-core
description: All artifacts
descriptions:
  - channel: stable
    text: Stable hve-core-all description
  - channel: prerelease
    text: 'Experimental: hve-core-all description'
tags: []
items:
  - path: .github/agents/fixture/fixture.agent.md
    kind: agent
display: {}
"@ | Set-Content -Path (Join-Path $collectionsDir 'hve-core-all.collection.yml')

        # Channel-fixture collection with distinct stable and prerelease descriptions.
        # Descriptions are single-quoted in YAML because they may contain ':' which would
        # otherwise be interpreted as a mapping in plain scalar context.
        @"
id: fixture-channel
name: Fixture Channel Collection
description: Fallback description (should not appear)
descriptions:
  - channel: stable
    text: '$StableDescription'
  - channel: prerelease
    text: '$PrereleaseDescription'
items:
  - path: .github/agents/fixture/fixture.agent.md
    kind: agent
"@ | Set-Content -Path (Join-Path $collectionsDir 'fixture-channel.collection.yml')

        @'
# Fixture Channel Collection

Integration fixture body.
'@ | Set-Content -Path (Join-Path $collectionsDir 'fixture-channel.collection.md')
    }
}

Describe 'Generate-Plugins integration: channel-aware description threading' {
    BeforeAll {
        $script:stableDesc = 'Stable fixture description ZZ-INTEG-STABLE'
        $script:prereleaseDesc = 'Experimental: fixture description ZZ-INTEG-PRE'

        $script:fixtureRoot = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
        New-IntegrationFixture -Root $script:fixtureRoot `
            -StableDescription $script:stableDesc `
            -PrereleaseDescription $script:prereleaseDesc

        $script:pluginManifestPath = Join-Path $script:fixtureRoot 'plugins/fixture-channel/.github/plugin/plugin.json'
        $script:pluginReadmePath = Join-Path $script:fixtureRoot 'plugins/fixture-channel/README.md'
        $script:marketplacePath = Join-Path $script:fixtureRoot '.github/plugin/marketplace.json'
    }

    AfterAll {
        Remove-Item -Path $script:fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'PreRelease channel run' {
        BeforeAll {
            $script:preReleaseResult = Invoke-PluginGeneration `
                -RepoRoot $script:fixtureRoot `
                -CollectionIds @('fixture-channel') `
                -Refresh `
                -Channel 'PreRelease'
        }

        It 'Completes successfully' {
            $script:preReleaseResult.Success | Should -BeTrue
        }

        It 'Writes the prerelease description into plugin.json' {
            Test-Path $script:pluginManifestPath | Should -BeTrue
            $manifest = Get-Content -Path $script:pluginManifestPath -Raw | ConvertFrom-Json
            $manifest.description | Should -Be $script:prereleaseDesc
        }

        It 'Writes the prerelease description into README.md' {
            Test-Path $script:pluginReadmePath | Should -BeTrue
            $readme = Get-Content -Path $script:pluginReadmePath -Raw
            $readme | Should -Match ([regex]::Escape($script:prereleaseDesc))
            $readme | Should -Not -Match ([regex]::Escape($script:stableDesc))
        }

        It 'Writes the prerelease description into the marketplace entry' {
            Test-Path $script:marketplacePath | Should -BeTrue
            $marketplace = Get-Content -Path $script:marketplacePath -Raw | ConvertFrom-Json
            $entry = $marketplace.plugins | Where-Object { $_.name -eq 'fixture-channel' } | Select-Object -First 1
            $entry | Should -Not -BeNullOrEmpty
            $entry.description | Should -Be $script:prereleaseDesc
        }
    }

    Context 'Stable channel run after PreRelease' {
        BeforeAll {
            $script:stableResult = Invoke-PluginGeneration `
                -RepoRoot $script:fixtureRoot `
                -CollectionIds @('fixture-channel') `
                -Refresh `
                -Channel 'Stable'
        }

        It 'Completes successfully' {
            $script:stableResult.Success | Should -BeTrue
        }

        It 'Overwrites plugin.json with the stable description (no stale prerelease text)' {
            Test-Path $script:pluginManifestPath | Should -BeTrue
            $manifest = Get-Content -Path $script:pluginManifestPath -Raw | ConvertFrom-Json
            $manifest.description | Should -Be $script:stableDesc
        }

        It 'Overwrites README.md with the stable description (no stale prerelease text)' {
            Test-Path $script:pluginReadmePath | Should -BeTrue
            $readme = Get-Content -Path $script:pluginReadmePath -Raw
            $readme | Should -Match ([regex]::Escape($script:stableDesc))
            $readme | Should -Not -Match ([regex]::Escape($script:prereleaseDesc))
        }

        It 'Overwrites the marketplace entry with the stable description' {
            Test-Path $script:marketplacePath | Should -BeTrue
            $marketplace = Get-Content -Path $script:marketplacePath -Raw | ConvertFrom-Json
            $entry = $marketplace.plugins | Where-Object { $_.name -eq 'fixture-channel' } | Select-Object -First 1
            $entry | Should -Not -BeNullOrEmpty
            $entry.description | Should -Be $script:stableDesc
        }
    }
}
