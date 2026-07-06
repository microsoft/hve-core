#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../extension/Select-CollectionVsix.ps1')
}

Describe 'Select-CollectionVsix' -Tag 'Unit' {
    It 'Returns the single matching VSIX for the requested collection' {
        $tempDir = Join-Path $TestDrive 'assets'
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        Set-Content -Path (Join-Path $tempDir 'hve-ado-1.0.0.vsix') -Value 'x'
        Set-Content -Path (Join-Path $tempDir 'hve-security-1.0.0.vsix') -Value 'x'

        $result = Select-CollectionVsix -AssetDirectory $tempDir -CollectionId 'ado'

        (Split-Path $result -Leaf) | Should -Be 'hve-ado-1.0.0.vsix'
    }

    It 'Throws when no VSIX matches the collection' {
        $tempDir = Join-Path $TestDrive 'assets-empty'
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        Set-Content -Path (Join-Path $tempDir 'hve-security-1.0.0.vsix') -Value 'x'

        { Select-CollectionVsix -AssetDirectory $tempDir -CollectionId 'ado' } | Should -Throw '*No VSIX assets matched collection ado*'
    }

    It 'Throws when multiple VSIX assets match the collection' {
        $tempDir = Join-Path $TestDrive 'assets-multi'
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        Set-Content -Path (Join-Path $tempDir 'hve-ado-1.0.0.vsix') -Value 'x'
        Set-Content -Path (Join-Path $tempDir 'hve-ado-2.0.0.vsix') -Value 'x'

        { Select-CollectionVsix -AssetDirectory $tempDir -CollectionId 'ado' } | Should -Throw '*Multiple VSIX assets matched collection ado*'
    }
}
