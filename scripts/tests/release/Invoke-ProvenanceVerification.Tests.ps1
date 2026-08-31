#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../release/Invoke-ProvenanceVerification.ps1')
}

Describe 'Invoke-ProvenanceVerification' -Tag 'Unit' {
    BeforeEach {
        $script:tempDir = Join-Path $TestDrive 'artifacts'
        New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null
    }

    It 'Invokes attestation verification with the expected arguments for a VSIX' {
        $vsixPath = Join-Path $script:tempDir 'sample.vsix'
        Set-Content -Path $vsixPath -Value 'x'

        Mock Invoke-ExternalCommand {
            return [pscustomobject]@{ ExitCode = 0 }
        }

        { Invoke-ProvenanceVerification -ArtifactDirectory $script:tempDir -Repository 'microsoft/hve-core' } | Should -Not -Throw
        Should -Invoke Invoke-ExternalCommand -Times 1 -Exactly -ParameterFilter { $Command -eq 'gh' -and $Arguments[0] -eq 'attestation' -and $Arguments[1] -eq 'verify' }
    }

    It 'Throws when no artifacts are present' {
        $script:tempDir = Join-Path $TestDrive 'empty-artifacts'
        New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null

        { Invoke-ProvenanceVerification -ArtifactDirectory $script:tempDir -Repository 'microsoft/hve-core' } | Should -Throw '*No release artifacts found*'
    }
}
