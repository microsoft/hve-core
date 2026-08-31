#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../extension/Export-AttestationBundle.ps1')
    Import-Module (Join-Path $PSScriptRoot 'ExtensionTestFixtures.psm1') -Force

    $script:BundleContent = [ordered]@{
        mediaType    = 'application/vnd.dev.sigstore.bundle+json;version=0.3'
        dsseEnvelope = [ordered]@{
            payload     = 'Zml4dHVyZS1wYXlsb2Fk'
            payloadType = 'application/vnd.in-toto+json'
            signatures  = @([ordered]@{ sig = 'ZmFrZS1zaWduYXR1cmU=' })
        }
    } | ConvertTo-Json -Depth 8
}

Describe 'Export-AttestationBundle' -Tag 'Unit' {
    Context 'when the bundle contains a DSSE envelope' {
        BeforeAll {
            $script:WorkDirectory = (New-Item -Path (Join-Path $TestDrive 'attestation') -ItemType Directory -Force).FullName
            $script:BundlePath = Join-Path $script:WorkDirectory 'attestation.jsonl'
            Set-FixtureFile -Path $script:BundlePath -Value $script:BundleContent
            $script:SigstorePath = Join-Path $script:WorkDirectory 'nested/output/hve-core-3.3.106.vsix.sigstore.json'
            $script:IntotoPath = Join-Path $script:WorkDirectory 'nested/output/hve-core-3.3.106.vsix.intoto.jsonl'
            $script:Result = Export-AttestationBundle -BundlePath $script:BundlePath `
                -SigstorePath $script:SigstorePath -IntotoPath $script:IntotoPath
        }

        It 'Creates destination directories that do not exist yet' {
            Test-Path -LiteralPath (Split-Path -Parent $script:SigstorePath) -PathType Container | Should -BeTrue
        }

        It 'Copies the bundle verbatim to the sigstore path' {
            Get-Content -LiteralPath $script:SigstorePath -Raw | Should -BeExactly $script:BundleContent
        }

        It 'Writes the DSSE envelope as a single compact JSON line' {
            @(Get-Content -LiteralPath $script:IntotoPath) | Should -HaveCount 1
            $envelope = Get-Content -LiteralPath $script:IntotoPath -Raw | ConvertFrom-Json
            $envelope.payloadType | Should -BeExactly 'application/vnd.in-toto+json'
            $envelope.payload | Should -BeExactly 'Zml4dHVyZS1wYXlsb2Fk'
            @($envelope.signatures.sig) | Should -Be @('ZmFrZS1zaWduYXR1cmU=')
        }

        It 'Returns the absolute output paths' {
            $script:Result.SigstorePath | Should -BeExactly ([System.IO.Path]::GetFullPath($script:SigstorePath))
            $script:Result.IntotoPath | Should -BeExactly ([System.IO.Path]::GetFullPath($script:IntotoPath))
        }
    }

    Context 'when the bundle file is missing' {
        It 'Throws the missing bundle message' {
            $missing = Join-Path $TestDrive 'absent-bundle.json'
            { Export-AttestationBundle -BundlePath $missing `
                    -SigstorePath (Join-Path $TestDrive 'out.sigstore.json') `
                    -IntotoPath (Join-Path $TestDrive 'out.intoto.jsonl') } |
                Should -Throw "Bundle file not found: $missing"
        }
    }

    Context 'when the bundle omits the DSSE envelope' {
        It 'Throws the missing envelope message' {
            $bundlePath = Join-Path $TestDrive 'no-envelope.json'
            Set-FixtureFile -Path $bundlePath -Value '{"mediaType":"application/vnd.dev.sigstore.bundle+json;version=0.3"}'
            { Export-AttestationBundle -BundlePath $bundlePath `
                    -SigstorePath (Join-Path $TestDrive 'no-envelope.sigstore.json') `
                    -IntotoPath (Join-Path $TestDrive 'no-envelope.intoto.jsonl') } |
                Should -Throw 'The attestation bundle does not contain a dsseEnvelope property.'
        }
    }
}

AfterAll {
    Remove-Module ExtensionTestFixtures -Force -ErrorAction SilentlyContinue
}
