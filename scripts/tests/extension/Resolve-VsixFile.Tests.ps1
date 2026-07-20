#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../extension/Resolve-VsixFile.ps1')
}

Describe 'Resolve-VsixFile' -Tag 'Unit' {
    It 'Returns the single matching VSIX file' {
        $tempDir = Join-Path $TestDrive 'vsix-dir'
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        Set-Content -Path (Join-Path $tempDir 'sample.vsix') -Value 'x'

        $result = Resolve-VsixFile -DirectoryPath $tempDir
        $result | Should -Be (Join-Path $tempDir 'sample.vsix')
    }

    It 'Throws when no VSIX files are present' {
        $tempDir = Join-Path $TestDrive 'vsix-empty'
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

        { Resolve-VsixFile -DirectoryPath $tempDir } | Should -Throw '*No VSIX file found*'
    }

    It 'Throws when more than one VSIX file is present' {
        $tempDir = Join-Path $TestDrive 'vsix-multi'
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        Set-Content -Path (Join-Path $tempDir 'first.vsix') -Value 'x'
        Set-Content -Path (Join-Path $tempDir 'second.vsix') -Value 'x'

        { Resolve-VsixFile -DirectoryPath $tempDir } | Should -Throw '*Expected exactly one VSIX file*'
    }
}
