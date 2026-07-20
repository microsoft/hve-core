#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../extension/Export-AttestationBundle.ps1')
}

Describe 'Export-AttestationBundle' -Tag 'Unit' {
    It 'Exports the signature and DSSE envelope to the requested paths' {
        $tempDir = Join-Path $TestDrive 'bundle'
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        $bundlePath = Join-Path $tempDir 'bundle.json'
        $payload = [ordered]@{
            dsseEnvelope = [ordered]@{ payloadType = 'application/vnd.in-toto+json' }
            predicateType = 'https://example.test/predicate'
        }
        $payload | ConvertTo-Json -Depth 10 | Set-Content -Path $bundlePath -Encoding utf8NoBOM

        $sigstorePath = Join-Path $tempDir 'bundle.sigstore.json'
        $intotoPath = Join-Path $tempDir 'bundle.intoto.jsonl'

        Export-AttestationBundle -BundlePath $bundlePath -SigstorePath $sigstorePath -IntotoPath $intotoPath

        Test-Path $sigstorePath | Should -BeTrue
        Test-Path $intotoPath | Should -BeTrue
        (Get-Content -Path $sigstorePath -Raw) | Should -Match '"dsseEnvelope"'
        (Get-Content -Path $intotoPath -Raw) | Should -Match 'application/vnd.in-toto\+json'
    }

    It 'Throws when the bundle file does not exist' {
        $tempDir = Join-Path $TestDrive 'bundle-missing'
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        $bundlePath = Join-Path $tempDir 'missing.json'

        { Export-AttestationBundle -BundlePath $bundlePath -SigstorePath (Join-Path $tempDir 'out.sigstore.json') -IntotoPath (Join-Path $tempDir 'out.intoto.jsonl') } | Should -Throw '*Bundle file not found*'
    }
}
