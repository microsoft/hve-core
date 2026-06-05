#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

# Discovery-time enumeration so each manifest produces its own It instance.
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$collectionsDir = Join-Path $repoRoot 'collections'
$CollectionFiles = @(Get-ChildItem -Path $collectionsDir -Filter '*.collection.yml' -File | Sort-Object Name)
$CollectionTestCases = @($CollectionFiles | ForEach-Object {
    @{
        CollectionId = [System.IO.Path]::GetFileNameWithoutExtension($_.Name) -replace '\.collection$', ''
        FilePath     = $_.FullName
    }
})

BeforeAll {
    Import-Module PowerShell-Yaml -Force
}

Describe 'Collection descriptions prerelease coverage' {
    It '<CollectionId> exposes a non-whitespace prerelease description with the expected prefix' -TestCases $CollectionTestCases {
        param($CollectionId, $FilePath)

        $manifest = Get-Content -Path $FilePath -Raw | ConvertFrom-Yaml

        $manifest.ContainsKey('descriptions') | Should -BeTrue -Because "collection '$CollectionId' must declare a top-level 'descriptions' array"
        $manifest.descriptions -is [System.Collections.IEnumerable] | Should -BeTrue -Because "collection '$CollectionId' must declare 'descriptions' as an array of channel entries"

        $prereleaseEntry = @($manifest.descriptions | Where-Object { [string]$_['channel'] -eq 'prerelease' })[0]
        $prereleaseEntry | Should -Not -BeNullOrEmpty -Because "collection '$CollectionId' must declare a 'prerelease' channel description"

        $prerelease = [string]$prereleaseEntry['text']
        [string]::IsNullOrWhiteSpace($prerelease) | Should -BeFalse -Because "collection '$CollectionId' must have a non-whitespace prerelease description text"

        $experimentalPrefixCollections = @('coding-standards', 'data-science', 'hve-core', 'hve-core-all', 'project-planning', 'security')
        $expectedPrefix = if ($experimentalPrefixCollections -contains $CollectionId) { 'Preview & Experimental:' } else { 'Preview:' }
        $prerelease | Should -BeLike "$expectedPrefix*" -Because "collection '$CollectionId' must use the '$expectedPrefix' prefix"
    }
}
