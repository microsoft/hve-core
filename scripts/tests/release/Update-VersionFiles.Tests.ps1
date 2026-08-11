#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../release/Update-VersionFiles.ps1'
    # Pass a dummy version to satisfy the mandatory parameter during dot-source.
    # The main execution guard prevents any file changes.
    . $script:ScriptPath -Version '0.0.0' -Channel Stable
    Mock Write-Host {}
}

Describe 'Resolve-RepoRoot' -Tag 'Unit' {
    It 'Returns the supplied path when provided' {
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "rr-$([guid]::NewGuid())"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        try {
            $result = Resolve-RepoRoot -Supplied $tempDir
            $result | Should -Be (Resolve-Path $tempDir).Path
        }
        finally {
            Remove-Item -Recurse -Force $tempDir
        }
    }

    It 'Auto-detects repo root when no path is supplied' {
        $result = Resolve-RepoRoot -Supplied ''
        $result | Should -Not -BeNullOrEmpty
        Test-Path (Join-Path $result '.git') | Should -BeTrue
    }

    It 'Throws when auto-detection fails and no path is supplied' {
        Mock Resolve-Path { return [PSCustomObject]@{ Path = '/nonexistent/path' } } -ParameterFilter {
            $Path -like "*..[\/]..*"
        }
        Mock Test-Path { return $false } -ParameterFilter {
            $Path -like "*[\/].git"
        }
        { Resolve-RepoRoot -Supplied '' } | Should -Throw "*Unable to determine repository root*"
    }
}

Describe 'Update-JsonVersion' -Tag 'Unit' {
    BeforeAll {
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "ujv-$([guid]::NewGuid())"
        New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
    }

    AfterAll {
        if (Test-Path $script:TempDir) {
            Remove-Item -Recurse -Force $script:TempDir
        }
    }

    It 'Updates a simple version field' {
        $filePath = Join-Path $script:TempDir 'simple.json'
        @{ version = '1.0.0'; name = 'test' } | ConvertTo-Json | Set-Content $filePath

        Update-JsonVersion -FilePath $filePath -Description 'simple.json' -Transform {
            param($j) $j.version = '2.0.0'; $j
        }

        $result = Get-Content -Raw $filePath | ConvertFrom-Json
        $result.version | Should -Be '2.0.0'
        $result.name | Should -Be 'test'
        (Get-Content -Raw $filePath).EndsWith("`n", [System.StringComparison]::Ordinal) | Should -BeTrue
    }

    It 'Preserves a missing final newline' {
        $filePath = Join-Path $script:TempDir 'no-final-newline.json'
        [System.IO.File]::WriteAllText(
            $filePath,
            '{"version":"1.0.0"}',
            [System.Text.UTF8Encoding]::new($false)
        )

        Update-JsonVersion -FilePath $filePath -Description 'no-final-newline.json' -Transform {
            param($j) $j.version = '2.0.0'; $j
        }

        $content = Get-Content -Raw $filePath
        ($content | ConvertFrom-Json).version | Should -Be '2.0.0'
        $content.EndsWith("`n", [System.StringComparison]::Ordinal) | Should -BeFalse
    }

    It 'Skips without error when file does not exist' {
        $missingPath = Join-Path $script:TempDir 'does-not-exist.json'
        { Update-JsonVersion -FilePath $missingPath -Description 'missing' -Transform { param($j) $j } } |
            Should -Not -Throw
    }

    It 'Updates nested properties via transform' {
        $filePath = Join-Path $script:TempDir 'nested.json'
        @{
            metadata = @{ version = '1.0.0' }
            plugins  = @(@{ version = '1.0.0'; id = 'p1' })
        } | ConvertTo-Json -Depth 10 | Set-Content $filePath

        Update-JsonVersion -FilePath $filePath -Description 'nested.json' -Transform {
            param($j)
            $j.metadata.version = '3.0.0'
            foreach ($p in $j.plugins) { $p.version = '3.0.0' }
            $j
        }

        $result = Get-Content -Raw $filePath | ConvertFrom-Json -Depth 10
        $result.metadata.version | Should -Be '3.0.0'
        $result.plugins[0].version | Should -Be '3.0.0'
    }

    It 'Preserves dot-key in release-please manifest' {
        $filePath = Join-Path $script:TempDir 'manifest.json'
        @{ '.' = '1.0.0' } | ConvertTo-Json | Set-Content $filePath

        Update-JsonVersion -FilePath $filePath -Description 'manifest' -Transform {
            param($j) $j.'.' = '4.0.0'; $j
        }

        $result = Get-Content -Raw $filePath | ConvertFrom-Json
        $result.'.' | Should -Be '4.0.0'
    }

    It 'Updates both version and packages[""].version in package-lock.json' {
        $filePath = Join-Path $script:TempDir 'package-lock.json'
        @{
            name            = 'hve-core'
            version         = '1.0.0'
            lockfileVersion = 3
            packages        = @{ '' = @{ version = '1.0.0'; name = 'hve-core' } }
        } | ConvertTo-Json -Depth 10 | Set-Content $filePath

        $targetVersion = '5.0.0'
        Update-JsonVersion -FilePath $filePath -Description 'package-lock.json' -AsHashtable -Transform {
            param($j)
            $j['version'] = $targetVersion
            if ($j.ContainsKey('packages') -and $j['packages'].ContainsKey('')) {
                $j['packages']['']['version'] = $targetVersion
            }
            $j
        }

        $result = Get-Content -Raw $filePath | ConvertFrom-Json -Depth 10 -AsHashtable
        $result['version'] | Should -Be '5.0.0'
        $result['packages']['']['version'] | Should -Be '5.0.0'
        $result['name'] | Should -Be 'hve-core'
    }

    It 'Updates only top-level version when packages[""] is absent' {
        $filePath = Join-Path $script:TempDir 'lock-no-root-pkg.json'
        @{
            name            = 'hve-core'
            version         = '1.0.0'
            lockfileVersion = 3
        } | ConvertTo-Json -Depth 10 | Set-Content $filePath

        $targetVersion = '6.0.0'
        Update-JsonVersion -FilePath $filePath -Description 'package-lock.json' -AsHashtable -Transform {
            param($j)
            $j['version'] = $targetVersion
            if ($j.ContainsKey('packages') -and $j['packages'].ContainsKey('')) {
                $j['packages']['']['version'] = $targetVersion
            }
            $j
        }

        $result = Get-Content -Raw $filePath | ConvertFrom-Json -Depth 10 -AsHashtable
        $result['version'] | Should -Be '6.0.0'
        $result['name'] | Should -Be 'hve-core'
    }

    It 'Throws when file contains malformed JSON' {
        $filePath = Join-Path $script:TempDir 'malformed.json'
        Set-Content -Path $filePath -Value '{ invalid json }'

        { Update-JsonVersion -FilePath $filePath -Description 'malformed' -Transform { param($j) $j } } |
            Should -Throw
    }

    It 'Throws when file is empty' {
        $filePath = Join-Path $script:TempDir 'empty.json'
        Set-Content -Path $filePath -Value ''

        { Update-JsonVersion -FilePath $filePath -Description 'empty' -Transform { param($j) $j } } |
            Should -Throw
    }

    It 'Propagates errors thrown by the transform block' {
        $filePath = Join-Path $script:TempDir 'transform-err.json'
        @{ version = '1.0.0' } | ConvertTo-Json | Set-Content $filePath

        { Update-JsonVersion -FilePath $filePath -Description 'transform-err' -Transform {
            param($j) throw 'deliberate transform error'
        } } | Should -Throw '*deliberate transform error*'
    }

    It 'Throws when file is read-only' -Skip:($IsWindows -eq $false -and (id -u) -eq 0) {
        $filePath = Join-Path $script:TempDir 'readonly.json'
        @{ version = '1.0.0' } | ConvertTo-Json | Set-Content $filePath
        Set-ItemProperty -Path $filePath -Name IsReadOnly -Value $true

        try {
            { Update-JsonVersion -FilePath $filePath -Description 'readonly' -Transform {
                param($j) $j.version = '2.0.0'; $j
            } } | Should -Throw
        }
        finally {
            Set-ItemProperty -Path $filePath -Name IsReadOnly -Value $false
        }
    }
}

Describe 'Update-MarketplaceCatalogVersion' -Tag 'Unit' {
    BeforeAll {
        function New-TestCatalog {
            param(
                [string]$Ref,
                [string]$Sha
            )

            $source = [ordered]@{ source = 'github'; repo = 'contoso/hve'; path = '.github' }
            if (-not [string]::IsNullOrWhiteSpace($Ref)) {
                $source['ref'] = $Ref
            }
            if (-not [string]::IsNullOrWhiteSpace($Sha)) {
                $source['sha'] = $Sha
            }
            return ([ordered]@{
                    metadata = [ordered]@{ version = '1.0.0' }
                    plugins  = @(
                        [ordered]@{ name = 'alpha'; version = '1.0.0'; source = [PSCustomObject]$source }
                        [ordered]@{ name = 'bravo'; version = '1.0.0'; source = [PSCustomObject]$source }
                    )
                } | ConvertTo-Json -Depth 10 | ConvertFrom-Json)
        }

        $script:TestSha = '0123456789abcdef0123456789abcdef01234567'
    }

    It 'Adds an exact channel ref when entries omit it' -ForEach @(
        @{ Channel = 'PreRelease'; Ref = 'prerelease-v2.3.4' }
        @{ Channel = 'Stable'; Ref = 'v2.3.4' }
    ) {
        $catalog = Update-MarketplaceCatalogVersion -Catalog (New-TestCatalog) -Version '2.3.4' -Channel $Channel
        @($catalog.plugins | ForEach-Object { $_.source.ref }) | Should -Be @($Ref, $Ref)
    }

    It 'Replaces a ref from the other channel namespace and drops the sha' -ForEach @(
        @{ Channel = 'PreRelease'; Existing = 'v1.0.0'; Ref = 'prerelease-v2.3.4' }
        @{ Channel = 'Stable'; Existing = 'prerelease-v1.0.0'; Ref = 'v2.3.4' }
    ) {
        $catalog = Update-MarketplaceCatalogVersion `
            -Catalog (New-TestCatalog -Ref $Existing -Sha $script:TestSha) -Version '2.3.4' -Channel $Channel
        @($catalog.plugins | ForEach-Object { $_.source.ref }) | Should -Be @($Ref, $Ref)
        foreach ($plugin in $catalog.plugins) {
            $plugin.source.PSObject.Properties.Name | Should -Not -Contain 'sha'
        }
    }

    It 'Advances catalog and package versions with the ref change' -ForEach @(
        @{ Channel = 'PreRelease' }
        @{ Channel = 'Stable' }
    ) {
        $catalog = Update-MarketplaceCatalogVersion -Catalog (New-TestCatalog -Ref 'v1.0.0') -Version '2.3.4' -Channel $Channel
        $catalog.metadata.version | Should -BeExactly '2.3.4'
        @($catalog.plugins | ForEach-Object { $_.version }) | Should -Be @('2.3.4', '2.3.4')
    }

    It 'Is byte-stable when applied twice with the same inputs' -ForEach @(
        @{ Channel = 'PreRelease' }
        @{ Channel = 'Stable' }
    ) {
        $catalog = New-TestCatalog -Ref 'v1.0.0' -Sha $script:TestSha
        $first = Update-MarketplaceCatalogVersion -Catalog $catalog -Version '2.3.4' -Channel $Channel
        $firstJson = $first | ConvertTo-Json -Depth 10
        $second = Update-MarketplaceCatalogVersion -Catalog $first -Version '2.3.4' -Channel $Channel
        ($second | ConvertTo-Json -Depth 10) | Should -BeExactly $firstJson
    }

    It 'Maps each channel to its exact ref namespace' -ForEach @(
        @{ Channel = 'PreRelease'; Expected = 'prerelease-v2.3.4' }
        @{ Channel = 'Stable'; Expected = 'v2.3.4' }
    ) {
        Get-MarketplaceChannelRef -Channel $Channel -Version '2.3.4' | Should -BeExactly $Expected
    }

    It 'Produces no hve-core-v ref for any channel' -ForEach @(
        @{ Channel = 'PreRelease' }
        @{ Channel = 'Stable' }
    ) {
        Get-MarketplaceChannelRef -Channel $Channel -Version '2.3.4' | Should -Not -Match '^hve-core-v'
    }
}

Describe 'Assert-BaselineLocator' -Tag 'Unit' {
    # OMITTED is the reserved locator for the ref-less bootstrap catalog a
    # release branch is seeded with. Every later baseline is the exact tag its
    # own channel writes, so nothing else may reach a candidate record.
    It 'Accepts the reserved OMITTED locator on <Channel>' -ForEach @(
        @{ Channel = 'PreRelease' }
        @{ Channel = 'Stable' }
    ) {
        { Assert-BaselineLocator -Channel $Channel -BaselineTag 'OMITTED' } | Should -Not -Throw
    }

    It 'Accepts the exact <Channel> channel tag <Baseline>' -ForEach @(
        @{ Channel = 'PreRelease'; Baseline = 'prerelease-v3.3.101' }
        @{ Channel = 'Stable'; Baseline = 'v3.2.2' }
    ) {
        { Assert-BaselineLocator -Channel $Channel -BaselineTag $Baseline } | Should -Not -Throw
    }

    It 'Rejects <Label> on <Channel>' -ForEach @(
        @{ Label = 'a legacy namespace'; Channel = 'PreRelease'; Baseline = 'hve-core-v1.0.0' }
        @{ Label = 'a legacy namespace'; Channel = 'Stable'; Baseline = 'hve-core-v1.0.0' }
        @{ Label = 'a retired projected namespace'; Channel = 'Stable'; Baseline = 'plugins-v1.0.0' }
        @{ Label = 'the other channel tag'; Channel = 'PreRelease'; Baseline = 'v1.0.0' }
        @{ Label = 'the other channel tag'; Channel = 'Stable'; Baseline = 'prerelease-v1.0.0' }
        @{ Label = 'a lowercased reserved locator'; Channel = 'PreRelease'; Baseline = 'omitted' }
        @{ Label = 'an arbitrary ref'; Channel = 'Stable'; Baseline = 'release/stable' }
        @{ Label = 'an empty locator'; Channel = 'PreRelease'; Baseline = '' }
    ) {
        { Assert-BaselineLocator -Channel $Channel -BaselineTag $Baseline } |
            Should -Throw -ExpectedMessage "*is neither 'OMITTED' nor an exact $Channel channel tag*"
    }
}

Describe 'Release candidate digest and record semantics' -Tag 'Unit' {
    BeforeAll {
        $script:SourceCommit = '0123456789abcdef0123456789abcdef01234567'

        function New-CandidateSourceCatalog {
            param([string]$Name = 'alpha')

            return ([ordered]@{
                    metadata = [ordered]@{ version = '1.0.0' }
                    plugins  = @(
                        [ordered]@{
                            name    = $Name
                            version = '1.0.0'
                            source  = [ordered]@{ source = 'github'; repo = 'contoso/hve'; path = '.github' }
                        }
                    )
                } | ConvertTo-Json -Depth 10 | ConvertFrom-Json)
        }

        function New-CandidateRecordFixture {
            param(
                [string]$Channel = 'PreRelease',
                [string]$BaselineTag = 'prerelease-v1.0.0',
                [string]$Version = '1.1.0',
                [object]$SourceCatalog
            )

            if ($null -eq $SourceCatalog) { $SourceCatalog = New-CandidateSourceCatalog }
            return New-ReleaseCandidateRecord `
                -Channel $Channel `
                -SourceCommit $script:SourceCommit `
                -BaselineTag $BaselineTag `
                -Version $Version `
                -SourceCatalog $SourceCatalog
        }
    }

    It 'Digests the compressed UTF-8 no-BOM no-final-newline bytes' {
        $catalog = New-CandidateSourceCatalog
        $canonical = $catalog | ConvertTo-Json -Compress -Depth 20
        $expected = [System.Convert]::ToHexString(
            [System.Security.Cryptography.SHA256]::HashData(
                [System.Text.UTF8Encoding]::new($false).GetBytes($canonical))).ToLowerInvariant()

        Get-MarketplaceCatalogDigest -Catalog $catalog | Should -BeExactly $expected
        $canonical | Should -Not -Match "`n"
    }

    It 'Records the schema, channel binding, and both canonical digests' {
        $record = New-CandidateRecordFixture
        $record['schema'] | Should -BeExactly 'hve-core/release-candidate/v1'
        $record['channel'] | Should -BeExactly 'PreRelease'
        $record['sourceCommit'] | Should -BeExactly $script:SourceCommit
        $record['baselineTag'] | Should -BeExactly 'prerelease-v1.0.0'
        $record['version'] | Should -BeExactly '1.1.0'
        $record['sourceCatalogDigest'] | Should -Match '^[0-9a-f]{64}$'
        $record['transformedCatalogDigest'] | Should -Match '^[0-9a-f]{64}$'
        $record['sourceCatalogDigest'] | Should -Not -BeExactly $record['transformedCatalogDigest']
    }

    It 'Leaves the source catalog unmodified while recording the transform' {
        $catalog = New-CandidateSourceCatalog
        $before = $catalog | ConvertTo-Json -Compress -Depth 20
        $null = New-CandidateRecordFixture -SourceCatalog $catalog
        ($catalog | ConvertTo-Json -Compress -Depth 20) | Should -BeExactly $before
    }

    It 'Creates or overwrites the record file deterministically' {
        $root = Join-Path ([System.IO.Path]::GetTempPath()) "cand-$([guid]::NewGuid())"
        try {
            $path = Join-Path $root '.github/plugin/release-candidate.json'
            Write-ReleaseCandidateRecordFile -Path $path -Record (New-CandidateRecordFixture)
            $first = Get-Content -Raw -LiteralPath $path
            Write-ReleaseCandidateRecordFile -Path $path -Record (New-CandidateRecordFixture -Version '1.2.0')
            $second = Get-Content -Raw -LiteralPath $path

            $first | Should -Not -BeExactly $second
            (Get-ReleaseCandidateRecordFile -Path $path).version | Should -BeExactly '1.2.0'
        }
        finally {
            if (Test-Path $root) { Remove-Item -Recurse -Force $root }
        }
    }

    It 'Returns the recorded transform when every current-intent binding agrees' {
        $catalog = New-CandidateSourceCatalog
        $record = New-CandidateRecordFixture -SourceCatalog $catalog
        $resolved = Resolve-ReleaseCandidateCatalog `
            -Record $record -Channel PreRelease -SourceCommit $script:SourceCommit `
            -BaselineTag 'prerelease-v1.0.0' -Version '1.1.0' -SourceCatalog $catalog

        $resolved.metadata.version | Should -BeExactly '1.1.0'
        @($resolved.plugins | ForEach-Object { $_.source.ref }) | Should -Be @('prerelease-v1.1.0')
        Get-MarketplaceCatalogDigest -Catalog $resolved | Should -BeExactly $record['transformedCatalogDigest']
    }

    It 'Is idempotent across replayed resolution' {
        $record = New-CandidateRecordFixture
        $first = Resolve-ReleaseCandidateCatalog `
            -Record $record -Channel PreRelease -SourceCommit $script:SourceCommit `
            -BaselineTag 'prerelease-v1.0.0' -Version '1.1.0' -SourceCatalog (New-CandidateSourceCatalog)
        $second = Resolve-ReleaseCandidateCatalog `
            -Record $record -Channel PreRelease -SourceCommit $script:SourceCommit `
            -BaselineTag 'prerelease-v1.0.0' -Version '1.1.0' -SourceCatalog (New-CandidateSourceCatalog)

        Get-MarketplaceCatalogDigest -Catalog $second |
            Should -BeExactly (Get-MarketplaceCatalogDigest -Catalog $first)
    }

    It 'Fails closed on <Label>' -ForEach @(
        @{ Label = 'a cross-channel baseline locator'; Channel = 'Stable'; Commit = '0123456789abcdef0123456789abcdef01234567'; Baseline = 'prerelease-v1.0.0'; Version = '1.1.0'; Tamper = ''; Pattern = "*is neither 'OMITTED' nor an exact Stable channel tag*" }
        @{ Label = 'a record channel mismatch'; Channel = 'Stable'; Commit = '0123456789abcdef0123456789abcdef01234567'; Baseline = 'v1.0.0'; Version = '1.1.0'; Tamper = ''; Pattern = '*does not match the requested channel*' }
        @{ Label = 'the wrong baseline'; Channel = 'PreRelease'; Commit = '0123456789abcdef0123456789abcdef01234567'; Baseline = 'prerelease-v0.9.0'; Version = '1.1.0'; Tamper = ''; Pattern = '*does not match the target baseline*' }
        @{ Label = 'the wrong version'; Channel = 'PreRelease'; Commit = '0123456789abcdef0123456789abcdef01234567'; Baseline = 'prerelease-v1.0.0'; Version = '1.2.0'; Tamper = ''; Pattern = '*does not match the managed release version*' }
        @{ Label = 'a different immutable source'; Channel = 'PreRelease'; Commit = 'fedcba9876543210fedcba9876543210fedcba98'; Baseline = 'prerelease-v1.0.0'; Version = '1.1.0'; Tamper = ''; Pattern = '*does not match the fetched source*' }
        @{ Label = 'a tampered source digest'; Channel = 'PreRelease'; Commit = '0123456789abcdef0123456789abcdef01234567'; Baseline = 'prerelease-v1.0.0'; Version = '1.1.0'; Tamper = 'sourceCatalogDigest'; Pattern = '*Candidate source catalog digest*' }
        @{ Label = 'a tampered transformed digest'; Channel = 'PreRelease'; Commit = '0123456789abcdef0123456789abcdef01234567'; Baseline = 'prerelease-v1.0.0'; Version = '1.1.0'; Tamper = 'transformedCatalogDigest'; Pattern = '*Candidate transformed catalog digest*' }
        @{ Label = 'a foreign record schema'; Channel = 'PreRelease'; Commit = '0123456789abcdef0123456789abcdef01234567'; Baseline = 'prerelease-v1.0.0'; Version = '1.1.0'; Tamper = 'schema'; Pattern = '*schema*is not*' }
    ) {
        $record = New-CandidateRecordFixture
        if ($Tamper -eq 'schema') {
            $record[$Tamper] = 'hve-core/release-candidate/v0'
        }
        elseif ($Tamper) {
            $record[$Tamper] = ('0' * 64)
        }

        {
            Resolve-ReleaseCandidateCatalog `
                -Record $record -Channel $Channel -SourceCommit $Commit `
                -BaselineTag $Baseline -Version $Version -SourceCatalog (New-CandidateSourceCatalog)
        } | Should -Throw -ExpectedMessage $Pattern
    }

    It 'Fails closed when the immutable source drifts' {
        $record = New-CandidateRecordFixture
        {
            Resolve-ReleaseCandidateCatalog `
                -Record $record -Channel PreRelease -SourceCommit $script:SourceCommit `
                -BaselineTag 'prerelease-v1.0.0' -Version '1.1.0' `
                -SourceCatalog (New-CandidateSourceCatalog -Name 'bravo')
        } | Should -Throw -ExpectedMessage '*Candidate source catalog digest*'
    }

    It 'Rejects a partially staged record' -ForEach @(
        @{ Field = 'sourceCommit' }
        @{ Field = 'baselineTag' }
        @{ Field = 'transformedCatalogDigest' }
    ) {
        $record = New-CandidateRecordFixture
        $record[$Field] = ''
        {
            Assert-ReleaseCandidateIdentity -Record $record -Channel PreRelease -Version '1.1.0'
        } | Should -Throw -ExpectedMessage "*missing required field '$Field'*"
    }

    It 'Rejects a committed catalog that is not the recorded candidate' {
        $record = New-CandidateRecordFixture
        {
            Assert-ReleaseCandidateCatalog -Record $record -Channel PreRelease -Version '1.1.0' `
                -Catalog (New-CandidateSourceCatalog)
        } | Should -Throw -ExpectedMessage '*Committed catalog digest*'
    }

    It 'Accepts the committed catalog the record describes' {
        $catalog = New-CandidateSourceCatalog
        $record = New-CandidateRecordFixture -SourceCatalog $catalog
        $applied = Resolve-ReleaseCandidateCatalog `
            -Record $record -Channel PreRelease -SourceCommit $script:SourceCommit `
            -BaselineTag 'prerelease-v1.0.0' -Version '1.1.0' -SourceCatalog $catalog

        {
            Assert-ReleaseCandidateCatalog -Record $record -Channel PreRelease -Version '1.1.0' -Catalog $applied
        } | Should -Not -Throw
    }

    # A branch still seeded with the ref-less bootstrap catalog advances from
    # OMITTED, so the reserved locator must survive record and replay intact.
    It 'Records and replays the reserved OMITTED baseline on <Channel>' -ForEach @(
        @{ Channel = 'PreRelease' }
        @{ Channel = 'Stable' }
    ) {
        $catalog = New-CandidateSourceCatalog
        $record = New-CandidateRecordFixture -Channel $Channel -BaselineTag 'OMITTED' -SourceCatalog $catalog
        $record['baselineTag'] | Should -BeExactly 'OMITTED'

        $resolved = Resolve-ReleaseCandidateCatalog `
            -Record $record -Channel $Channel -SourceCommit $script:SourceCommit `
            -BaselineTag 'OMITTED' -Version '1.1.0' -SourceCatalog $catalog
        Get-MarketplaceCatalogDigest -Catalog $resolved |
            Should -BeExactly $record['transformedCatalogDigest']
    }

    It 'Refuses to record a <Label> baseline locator' -ForEach @(
        @{ Label = 'legacy'; Baseline = 'hve-core-v1.0.0' }
        @{ Label = 'cross-channel'; Baseline = 'v1.0.0' }
        @{ Label = 'arbitrary'; Baseline = 'release/prerelease' }
    ) {
        { New-CandidateRecordFixture -BaselineTag $Baseline } |
            Should -Throw -ExpectedMessage "*is neither 'OMITTED' nor an exact PreRelease channel tag*"
    }
}

Describe 'Update-VersionFiles script execution' -Tag 'Unit' {
    BeforeAll {
        $script:FakeRoot = Join-Path ([System.IO.Path]::GetTempPath()) "uvf-$([guid]::NewGuid())"
        New-Item -ItemType Directory -Path $script:FakeRoot -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:FakeRoot '.git') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:FakeRoot 'extension/templates') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:FakeRoot '.github/plugin') -Force | Out-Null

        # Seed all version file types at 1.0.0
        @{ version = '1.0.0'; name = 'hve-core' } |
            ConvertTo-Json | Set-Content (Join-Path $script:FakeRoot 'package.json')
        @{ version = '1.0.0' } |
            ConvertTo-Json | Set-Content (Join-Path $script:FakeRoot 'extension/templates/package.template.json')
        @{
            metadata = @{ version = '1.0.0' }
            plugins  = @(
                @{ version = '1.0.0'; id = 'hve-core'; source = @{ ref = 'v1.0.0' } }
                @{ version = '1.0.0'; id = 'ado'; source = @{ ref = 'v1.0.0' } }
            )
        } | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $script:FakeRoot '.github/plugin/marketplace.json')
        @{ '.' = '1.0.0' } |
            ConvertTo-Json | Set-Content (Join-Path $script:FakeRoot '.release-please-manifest.json')
        @{ '.' = '1.0.0' } |
            ConvertTo-Json | Set-Content (Join-Path $script:FakeRoot '.release-please-prerelease-manifest.json')
        @{
            name            = 'hve-core'
            version         = '1.0.0'
            lockfileVersion = 3
            packages        = @{ '' = @{ version = '1.0.0'; name = 'hve-core' } }
        } | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $script:FakeRoot 'package-lock.json')
    }

    AfterAll {
        if (Test-Path $script:FakeRoot) {
            Remove-Item -Recurse -Force $script:FakeRoot
        }
    }

    It 'Updates all version files to the target version' {
        & $script:ScriptPath -Version '2.5.0' -Channel Stable -RepoRoot $script:FakeRoot -SkipPluginGenerate

        $pkg = Get-Content -Raw (Join-Path $script:FakeRoot 'package.json') | ConvertFrom-Json
        $pkg.version | Should -Be '2.5.0'
        $pkg.name | Should -Be 'hve-core'

        $tmpl = Get-Content -Raw (Join-Path $script:FakeRoot 'extension/templates/package.template.json') | ConvertFrom-Json
        $tmpl.version | Should -Be '2.5.0'

        $mkt = Get-Content -Raw (Join-Path $script:FakeRoot '.github/plugin/marketplace.json') | ConvertFrom-Json -Depth 10
        $mkt.metadata.version | Should -Be '2.5.0'
        $mkt.plugins[0].version | Should -Be '2.5.0'
        $mkt.plugins[1].version | Should -Be '2.5.0'
        $mkt.plugins[0].source.ref | Should -Be 'v2.5.0'
        $mkt.plugins[1].source.ref | Should -Be 'v2.5.0'

        $manifest = Get-Content -Raw (Join-Path $script:FakeRoot '.release-please-manifest.json') | ConvertFrom-Json
        $manifest.'.' | Should -Be '2.5.0'
        $preReleaseManifest = Get-Content -Raw (Join-Path $script:FakeRoot '.release-please-prerelease-manifest.json') | ConvertFrom-Json
        $preReleaseManifest.'.' | Should -Be '1.0.0'

        $lock = Get-Content -Raw (Join-Path $script:FakeRoot 'package-lock.json') | ConvertFrom-Json -Depth 10 -AsHashtable
        $lock['version'] | Should -Be '2.5.0'
        $lock['packages']['']['version'] | Should -Be '2.5.0'

        foreach ($relativePath in @(
                'package.json',
                'package-lock.json',
                'extension/templates/package.template.json',
                '.github/plugin/marketplace.json',
                '.release-please-manifest.json'
            )) {
            (Get-Content -Raw (Join-Path $script:FakeRoot $relativePath)).EndsWith(
                "`n",
                [System.StringComparison]::Ordinal
            ) | Should -BeTrue
        }
    }

    It 'Succeeds when optional files are missing' {
        $sparseRoot = Join-Path ([System.IO.Path]::GetTempPath()) "uvf-sparse-$([guid]::NewGuid())"
        New-Item -ItemType Directory -Path $sparseRoot -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $sparseRoot '.git') -Force | Out-Null

        # Only create package.json — other files are absent
        @{ version = '1.0.0' } | ConvertTo-Json | Set-Content (Join-Path $sparseRoot 'package.json')

        try {
            { & $script:ScriptPath -Version '3.0.0' -Channel Stable -RepoRoot $sparseRoot -SkipPluginGenerate } |
                Should -Not -Throw

            $pkg = Get-Content -Raw (Join-Path $sparseRoot 'package.json') | ConvertFrom-Json
            $pkg.version | Should -Be '3.0.0'
        }
        finally {
            Remove-Item -Recurse -Force $sparseRoot
        }
    }

    It 'Updates an explicitly selected manifest without changing the Stable manifest' {
        & $script:ScriptPath `
            -Version '2.6.0' `
            -Channel PreRelease `
            -RepoRoot $script:FakeRoot `
            -ManifestPath '.release-please-prerelease-manifest.json' `
            -SkipPluginGenerate

        $stable = Get-Content -Raw (Join-Path $script:FakeRoot '.release-please-manifest.json') | ConvertFrom-Json
        $preRelease = Get-Content -Raw (Join-Path $script:FakeRoot '.release-please-prerelease-manifest.json') | ConvertFrom-Json
        $stable.'.' | Should -Be '2.5.0'
        $preRelease.'.' | Should -Be '2.6.0'

        $mkt = Get-Content -Raw (Join-Path $script:FakeRoot '.github/plugin/marketplace.json') | ConvertFrom-Json -Depth 10
        $mkt.plugins[0].source.ref | Should -Be 'prerelease-v2.6.0'
    }

    It 'Skips both manifests while updating shared version metadata' {
        & $script:ScriptPath `
            -Version '2.7.0' `
            -Channel Stable `
            -RepoRoot $script:FakeRoot `
            -SkipManifest `
            -SkipPluginGenerate

        $stable = Get-Content -Raw (Join-Path $script:FakeRoot '.release-please-manifest.json') | ConvertFrom-Json
        $preRelease = Get-Content -Raw (Join-Path $script:FakeRoot '.release-please-prerelease-manifest.json') | ConvertFrom-Json
        $package = Get-Content -Raw (Join-Path $script:FakeRoot 'package.json') | ConvertFrom-Json
        $stable.'.' | Should -Be '2.5.0'
        $preRelease.'.' | Should -Be '2.6.0'
        $package.version | Should -Be '2.7.0'
    }

    It 'Rejects a manifest path when manifest updates are skipped' {
        {
            & $script:ScriptPath `
                -Version '2.8.0' `
                -Channel Stable `
                -RepoRoot $script:FakeRoot `
                -ManifestPath '.release-please-prerelease-manifest.json' `
                -SkipManifest `
                -SkipPluginGenerate
        } | Should -Throw
    }

    It 'Rejects an explicitly selected missing manifest' {
        {
            & $script:ScriptPath `
                -Version '2.8.0' `
                -Channel Stable `
                -RepoRoot $script:FakeRoot `
                -ManifestPath '.missing-release-manifest.json' `
                -SkipPluginGenerate
        } | Should -Throw '*Manifest file not found*'
    }

    It 'Rejects invalid version "<Version>"' -ForEach @(
        @{ Version = 'abc' }
        @{ Version = '1.2' }
        @{ Version = 'v1.2.3' }
        @{ Version = '1.2.3-suffix' }
        @{ Version = "1.2.3`n" }
    ) {
        { & $script:ScriptPath -Version $Version -Channel Stable -RepoRoot $script:FakeRoot -SkipPluginGenerate } |
            Should -Throw
    }

    It 'Rejects invocation without an explicit channel' {
        & pwsh -NoProfile -NonInteractive -File $script:ScriptPath `
            -Version '2.8.0' -RepoRoot $script:FakeRoot -SkipPluginGenerate 2>$null
        $LASTEXITCODE | Should -Not -Be 0
    }

    It 'Rejects an unknown channel value' {
        & pwsh -NoProfile -NonInteractive -File $script:ScriptPath `
            -Version '2.9.0' -Channel 'Main' -RepoRoot $script:FakeRoot -SkipManifest -SkipPluginGenerate 2>$null
        $LASTEXITCODE | Should -Not -Be 0
    }

    # Promotion restores the complete prior catalog before recording. The
    # baseline locator is read from that restored catalog rather than rebuilt
    # from the baseline version, and the catalog itself is never rewritten.
    It 'Preserves the restored catalog byte-for-byte while recording a candidate' {
        $root = Join-Path $TestDrive 'promotion-record'
        New-Item -ItemType Directory -Path (Join-Path $root '.github/plugin') -Force | Out-Null

        $priorCatalog = @'
{
    "metadata": {
        "version": "1.0.0"
    },
    "plugins": [
        {
            "id": "hve-core",
            "version": "1.0.0",
            "source": {
                "source": "github",
                "repo": "contoso/hve",
                "path": ".github",
                "ref": "prerelease-v1.0.0",
                "sha": "fedcba9876543210fedcba9876543210fedcba98"
            }
        }
    ]
}
'@ + "`n"
        $catalogPath = Join-Path $root '.github/plugin/marketplace.json'
        [System.IO.File]::WriteAllText($catalogPath, $priorCatalog, [System.Text.UTF8Encoding]::new($false))
        $catalogDigestBefore = [System.Convert]::ToHexString(
            [System.Security.Cryptography.SHA256]::HashData([System.IO.File]::ReadAllBytes($catalogPath)))

        @{ version = '0.9.0'; name = 'hve-core' } |
            ConvertTo-Json | Set-Content -LiteralPath (Join-Path $root 'package.json')

        # The immutable source the record names is fetched outside the repo,
        # exactly as the promotion writes it to RUNNER_TEMP.
        $sourceCatalogPath = Join-Path $TestDrive 'candidate-source-marketplace.json'
        @{
            metadata = @{ version = '0.9.0' }
            plugins  = @(@{ id = 'hve-core'; version = '0.9.0'; source = @{ source = 'github'; repo = 'contoso/hve' } })
        } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $sourceCatalogPath

        $sourceCommit = '0123456789abcdef0123456789abcdef01234567'
        & $script:ScriptPath `
            -Version '1.0.0' `
            -Channel PreRelease `
            -RepoRoot $root `
            -SkipManifest `
            -SkipPluginGenerate `
            -CandidateAction Record `
            -CandidateVersion '1.1.0' `
            -CandidateSourceCommit $sourceCommit `
            -CandidateSourceCatalog $sourceCatalogPath `
            -BaselineTag 'prerelease-v1.0.0'

        [System.IO.File]::ReadAllText($catalogPath) | Should -BeExactly $priorCatalog
        [System.Convert]::ToHexString(
            [System.Security.Cryptography.SHA256]::HashData([System.IO.File]::ReadAllBytes($catalogPath))) |
            Should -BeExactly $catalogDigestBefore

        (Get-Content -Raw -LiteralPath (Join-Path $root 'package.json') | ConvertFrom-Json).version |
            Should -BeExactly '1.0.0'

        $record = Get-ReleaseCandidateRecordFile -Path (Join-Path $root '.github/plugin/release-candidate.json')
        $record.channel | Should -BeExactly 'PreRelease'
        $record.version | Should -BeExactly '1.1.0'
        $record.baselineTag | Should -BeExactly 'prerelease-v1.0.0'
        $record.sourceCommit | Should -BeExactly $sourceCommit

        # Both digests come from the immutable source, never the restored catalog.
        $sourceCatalog = Get-MarketplaceCatalogFile -Path $sourceCatalogPath
        $record.sourceCatalogDigest |
            Should -BeExactly (Get-MarketplaceCatalogDigest -Catalog $sourceCatalog)
        $record.transformedCatalogDigest | Should -BeExactly (
            Get-MarketplaceCatalogDigest -Catalog (
                Update-MarketplaceCatalogVersion -Catalog $sourceCatalog -Version '1.1.0' -Channel PreRelease))
    }

    It 'Keeps the committed catalog outside the channel transform on Record' {
        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            (Resolve-Path -LiteralPath $script:ScriptPath).Path, [ref]$tokens, [ref]$parseErrors)
        $parseErrors | Should -BeNullOrEmpty

        $catalogWrites = @($ast.FindAll({
                    param($node)
                    $node -is [System.Management.Automation.Language.CommandAst] -and
                    $node.GetCommandName() -eq 'Update-JsonVersion' -and
                    $node.Extent.Text -match 'Update-MarketplaceCatalogVersion'
                }, $true))
        $catalogWrites | Should -HaveCount 1

        $guard = $catalogWrites[0].Parent
        while ($null -ne $guard -and $guard -isnot [System.Management.Automation.Language.IfStatementAst]) {
            $guard = $guard.Parent
        }
        $guard | Should -Not -BeNullOrEmpty
        $guard.Clauses[0].Item1.Extent.Text | Should -BeLike "*`$CandidateAction -eq 'Record'*"
        $guard.ElseClause | Should -Not -BeNullOrEmpty
        $catalogWrites[0].Extent.StartOffset |
            Should -BeGreaterThan $guard.ElseClause.Extent.StartOffset
    }
}

Describe 'Managed release head verification' -Tag 'Unit' {
    BeforeAll {
        $script:HeadSourceCommit = '0123456789abcdef0123456789abcdef01234567'

        function New-ManagedHeadFixture {
            <#
            .SYNOPSIS
            Builds a synchronized managed release head and its immutable source.
            .DESCRIPTION
            Mirrors the state a managed release pull request head carries once the
            candidate is applied: prior shared version metadata, the retained
            record, the transformed catalog, and the immutable source catalog the
            record names, which the pull request gate stages outside the tree.
            .PARAMETER Channel
            Release channel the candidate belongs to.
            .PARAMETER Version
            Release version the managed head carries.
            .PARAMETER BaselineTag
            Baseline locator the retained record advances from.
            .OUTPUTS
            [hashtable] Managed head root and immutable source catalog path.
            #>
            [CmdletBinding()]
            [OutputType([hashtable])]
            param(
                [Parameter(Mandatory = $false)]
                [string]$Channel = 'PreRelease',

                [Parameter(Mandatory = $false)]
                [string]$Version = '1.1.0',

                [Parameter(Mandatory = $false)]
                [string]$BaselineTag = 'prerelease-v1.0.0'
            )

            $id = [guid]::NewGuid()
            $root = Join-Path $TestDrive "managed-head-$id"
            $sourceCatalogPath = Join-Path $TestDrive "managed-source-$id.json"
            New-Item -ItemType Directory -Path (Join-Path $root '.github/plugin') -Force | Out-Null

            # Shared version metadata stays at the prior version, so any write
            # past the verification return is observable.
            @{ version = '0.9.0'; name = 'hve-core' } |
                ConvertTo-Json | Set-Content -LiteralPath (Join-Path $root 'package.json')

            @{
                metadata = @{ version = '1.0.0' }
                plugins  = @(
                    @{
                        id      = 'hve-core'
                        version = '1.0.0'
                        source  = @{ source = 'github'; repo = 'contoso/hve'; path = '.github' }
                    }
                )
            } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $sourceCatalogPath

            $sourceCatalog = Get-MarketplaceCatalogFile -Path $sourceCatalogPath
            Write-ReleaseCandidateRecordFile `
                -Path (Join-Path $root '.github/plugin/release-candidate.json') `
                -Record (New-ReleaseCandidateRecord `
                    -Channel $Channel `
                    -SourceCommit $script:HeadSourceCommit `
                    -BaselineTag $BaselineTag `
                    -Version $Version `
                    -SourceCatalog $sourceCatalog)

            Update-MarketplaceCatalogVersion `
                -Catalog (Copy-MarketplaceCatalog -Catalog $sourceCatalog) `
                -Version $Version `
                -Channel $Channel |
                ConvertTo-Json -Depth 20 |
                Set-Content -LiteralPath (Join-Path $root '.github/plugin/marketplace.json')

            return @{ Root = $root; SourceCatalog = $sourceCatalogPath }
        }
    }

    # Plugin generation is deliberately not skipped: a verification that failed
    # to return before the shared writes would run npm inside the fixture.
    It 'Replays the immutable source and baseline for <Channel>' -ForEach @(
        @{ Channel = 'PreRelease'; BaselineTag = 'prerelease-v1.0.0' }
        @{ Channel = 'Stable'; BaselineTag = 'v1.0.0' }
    ) {
        $fixture = New-ManagedHeadFixture -Channel $Channel -BaselineTag $BaselineTag

        {
            & $script:ScriptPath `
                -Version '1.1.0' `
                -Channel $Channel `
                -RepoRoot $fixture.Root `
                -CandidateAction Verify `
                -CandidateSourceCommit $script:HeadSourceCommit `
                -CandidateSourceCatalog $fixture.SourceCatalog `
                -BaselineTag $BaselineTag
        } | Should -Not -Throw
    }

    It 'Writes nothing while proving the managed head' {
        $fixture = New-ManagedHeadFixture
        $tracked = @(
            'package.json'
            '.github/plugin/marketplace.json'
            '.github/plugin/release-candidate.json'
        )
        $before = @{}
        foreach ($relativePath in $tracked) {
            $before[$relativePath] = [System.Convert]::ToHexString(
                [System.Security.Cryptography.SHA256]::HashData(
                    [System.IO.File]::ReadAllBytes((Join-Path $fixture.Root $relativePath))))
        }

        & $script:ScriptPath `
            -Version '1.1.0' `
            -Channel PreRelease `
            -RepoRoot $fixture.Root `
            -CandidateAction Verify `
            -CandidateSourceCommit $script:HeadSourceCommit `
            -CandidateSourceCatalog $fixture.SourceCatalog `
            -BaselineTag 'prerelease-v1.0.0'

        foreach ($relativePath in $tracked) {
            [System.Convert]::ToHexString(
                [System.Security.Cryptography.SHA256]::HashData(
                    [System.IO.File]::ReadAllBytes((Join-Path $fixture.Root $relativePath)))) |
                Should -BeExactly $before[$relativePath]
        }
        (Get-Content -Raw -LiteralPath (Join-Path $fixture.Root 'package.json') | ConvertFrom-Json).version |
            Should -BeExactly '0.9.0'
    }

    # The committed catalog still matches the record in each case, so only the
    # source replay can reject these managed heads.
    It 'Fails closed when full verification replays <Label>' -ForEach @(
        @{ Label = 'a different immutable source commit'; Commit = 'fedcba9876543210fedcba9876543210fedcba98'; Baseline = 'prerelease-v1.0.0'; Drift = $false; Pattern = '*does not match the fetched source*' }
        @{ Label = 'a different baseline locator'; Commit = ''; Baseline = 'prerelease-v0.9.0'; Drift = $false; Pattern = '*does not match the target baseline*' }
        @{ Label = 'a drifted immutable source catalog'; Commit = ''; Baseline = 'prerelease-v1.0.0'; Drift = $true; Pattern = '*Candidate source catalog digest*' }
    ) {
        $fixture = New-ManagedHeadFixture
        if ($Drift) {
            @{
                metadata = @{ version = '1.0.0' }
                plugins  = @(
                    @{
                        id      = 'ado'
                        version = '1.0.0'
                        source  = @{ source = 'github'; repo = 'contoso/hve'; path = '.github' }
                    }
                )
            } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $fixture.SourceCatalog
        }
        $sourceCommit = if ($Commit) { $Commit } else { $script:HeadSourceCommit }

        {
            & $script:ScriptPath `
                -Version '1.1.0' `
                -Channel PreRelease `
                -RepoRoot $fixture.Root `
                -CandidateAction Verify `
                -CandidateSourceCommit $sourceCommit `
                -CandidateSourceCatalog $fixture.SourceCatalog `
                -BaselineTag $Baseline
        } | Should -Throw -ExpectedMessage $Pattern
    }

    It 'Replays the recorded transform before reading the committed catalog' {
        $fixture = New-ManagedHeadFixture
        $recordPath = Join-Path $fixture.Root '.github/plugin/release-candidate.json'
        $record = Get-Content -Raw -LiteralPath $recordPath | ConvertFrom-Json -Depth 20 -AsHashtable
        $record['transformedCatalogDigest'] = ('0' * 64)
        Write-ReleaseCandidateRecordFile -Path $recordPath -Record $record

        $verify = @{
            Version         = '1.1.0'
            Channel         = 'PreRelease'
            RepoRoot        = $fixture.Root
            CandidateAction = 'Verify'
        }
        { & $script:ScriptPath @verify } |
            Should -Throw -ExpectedMessage '*Committed catalog digest*'
        {
            & $script:ScriptPath @verify `
                -CandidateSourceCommit $script:HeadSourceCommit `
                -CandidateSourceCatalog $fixture.SourceCatalog `
                -BaselineTag 'prerelease-v1.0.0'
        } | Should -Throw -ExpectedMessage '*Candidate transformed catalog digest*'
    }

    It 'Accepts the record-only verification the tagged release replays' {
        $fixture = New-ManagedHeadFixture
        {
            & $script:ScriptPath `
                -Version '1.1.0' `
                -Channel PreRelease `
                -RepoRoot $fixture.Root `
                -CandidateAction Verify
        } | Should -Not -Throw
    }

    It 'Rejects the partial source verification argument set <Label>' -ForEach @(
        @{ Label = 'commit only'; Supplied = @('CandidateSourceCommit'); Pattern = '*requires -CandidateSourceCatalog*' }
        @{ Label = 'catalog only'; Supplied = @('CandidateSourceCatalog'); Pattern = '*requires -CandidateSourceCommit*' }
        @{ Label = 'baseline only'; Supplied = @('BaselineTag'); Pattern = '*requires -CandidateSourceCommit*' }
        @{ Label = 'commit and catalog'; Supplied = @('CandidateSourceCommit', 'CandidateSourceCatalog'); Pattern = '*requires -BaselineTag*' }
        @{ Label = 'commit and baseline'; Supplied = @('CandidateSourceCommit', 'BaselineTag'); Pattern = '*requires -CandidateSourceCatalog*' }
        @{ Label = 'catalog and baseline'; Supplied = @('CandidateSourceCatalog', 'BaselineTag'); Pattern = '*requires -CandidateSourceCommit*' }
    ) {
        $fixture = New-ManagedHeadFixture
        $available = @{
            CandidateSourceCommit  = $script:HeadSourceCommit
            CandidateSourceCatalog = $fixture.SourceCatalog
            BaselineTag            = 'prerelease-v1.0.0'
        }
        $arguments = @{
            Version         = '1.1.0'
            Channel         = 'PreRelease'
            RepoRoot        = $fixture.Root
            CandidateAction = 'Verify'
        }
        foreach ($name in $Supplied) {
            $arguments[$name] = $available[$name]
        }

        { & $script:ScriptPath @arguments } | Should -Throw -ExpectedMessage $Pattern
    }
}

Describe 'Release preparation repair' -Tag 'Unit' {
    BeforeAll {
        $script:RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path

        function New-PreparedRoot {
            <#
            .SYNOPSIS
            Builds a root in release-please's prepared state.
            .DESCRIPTION
            release-please's json extra-files updater writes bare version values,
            so every version field already carries the new version while the
            catalog still pins the previous plugins-v<version> locator.
            .OUTPUTS
            [string] Prepared root path.
            #>
            [CmdletBinding()]
            [OutputType([string])]
            param()

            $root = Join-Path ([System.IO.Path]::GetTempPath()) "uvf-prepared-$([guid]::NewGuid())"
            New-Item -ItemType Directory -Path (Join-Path $root '.git') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $root '.github/plugin') -Force | Out-Null

            @{ version = '3.4.0'; name = 'hve-core' } |
                ConvertTo-Json | Set-Content (Join-Path $root 'package.json')
            @{ '.' = '3.4.0' } |
                ConvertTo-Json | Set-Content (Join-Path $root '.release-please-manifest.json')
            @{
                metadata = @{ version = '3.4.0' }
                plugins  = @(@{ version = '3.4.0'; id = 'hve-core'; source = @{ ref = 'v3.2.2' } })
            } | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $root '.github/plugin/marketplace.json')

            return $root
        }
    }

    It 'Rewrites a stale plugin locator when every bare version is already current' {
        $root = New-PreparedRoot
        try {
            & $script:ScriptPath -Version '3.4.0' -Channel Stable -RepoRoot $root -SkipPluginGenerate

            $catalog = Get-Content -Raw (Join-Path $root '.github/plugin/marketplace.json') | ConvertFrom-Json -Depth 10
            $catalog.plugins[0].source.ref | Should -Be 'v3.4.0'
            $catalog.metadata.version | Should -Be '3.4.0'
            $catalog.plugins[0].version | Should -Be '3.4.0'
        }
        finally {
            Remove-Item -Recurse -Force $root
        }
    }

    It 'Leaves an already-consistent preparation byte-identical' {
        $root = New-PreparedRoot
        try {
            & $script:ScriptPath -Version '3.4.0' -Channel Stable -RepoRoot $root -SkipPluginGenerate
            $catalogPath = Join-Path $root '.github/plugin/marketplace.json'
            $first = Get-Content -Raw $catalogPath

            & $script:ScriptPath -Version '3.4.0' -Channel Stable -RepoRoot $root -SkipPluginGenerate

            Get-Content -Raw $catalogPath | Should -BeExactly $first
        }
        finally {
            Remove-Item -Recurse -Force $root
        }
    }

    # A lint gate that only fails on a stale locator would block every release.
    # The release workflow must call this updater on the release-please branch
    # so the managed PR owns the complete committed release state.
    It 'Is invoked on each managed release preparation branch' -ForEach @(
        @{
            Workflow = 'release-prerelease.yml'
            TargetBranch = 'release/prerelease'
            ManifestPath = '.release-please-prerelease-manifest.json'
            ConfigPath = 'release-please-prerelease-config.json'
            Channel = 'PreRelease'
            BaselineBranch = 'release/prerelease'
        }
        @{
            Workflow = 'release-stable-publish.yml'
            TargetBranch = 'release/stable'
            ManifestPath = ''
            ConfigPath = 'release-please-config.json'
            Channel = 'Stable'
            BaselineBranch = 'release/stable'
        }
    ) {
        $workflowPath = Join-Path $script:RepositoryRoot ".github/workflows/$Workflow"
        $workflow = Get-Content -LiteralPath $workflowPath -Raw -Encoding utf8
        $document = $workflow | ConvertFrom-Yaml

        $release = $document['jobs']['release-please']
        [string]$release['steps'][1]['with']['target-branch'] | Should -BeExactly $TargetBranch

        $sync = $document['jobs']['sync-release-pr']
        $sync | Should -Not -BeNullOrEmpty
        @($sync['needs']) | Should -Be @('release-please')
        [string]$sync['if'] | Should -Match "needs\.release-please\.outputs\.release-pr-branch != ''"

        $checkouts = @($sync['steps'] | Where-Object { $_.Contains('uses') -and [string]$_['uses'] -match '^actions/checkout@' })
        $checkouts | Should -HaveCount 2

        $trusted = @($checkouts | Where-Object { [string]$_['name'] -eq 'Checkout trusted release updater' })
        $trusted | Should -HaveCount 1
        [string]$trusted[0]['with']['ref'] | Should -BeExactly '${{ github.sha }}'
        [string]$trusted[0]['with']['sparse-checkout'] | Should -BeExactly 'scripts/release/Update-VersionFiles.ps1'
        [bool]$trusted[0]['with']['persist-credentials'] | Should -BeFalse

        $preparation = @($checkouts | Where-Object { [string]$_['name'] -eq 'Checkout release preparation data' })
        $preparation | Should -HaveCount 1
        [string]$preparation[0]['with']['ref'] | Should -BeExactly '${{ needs.release-please.outputs.release-pr-branch }}'
        [string]$preparation[0]['with']['path'] | Should -BeExactly 'release-preparation'
        [bool]$preparation[0]['with']['persist-credentials'] | Should -BeTrue
        $workflow | Should -Match 'Data-only checkout: executable tooling comes from the trusted github\.sha checkout\.'

        $runs = [string[]]@($sync['steps'] | Where-Object { $_.Contains('run') } | ForEach-Object { [string]$_['run'] })
        $invocation = @($runs | Where-Object { $_ -match 'scripts/release/Update-VersionFiles\.ps1' })
        $invocation | Should -HaveCount 1
        $invocation[0] | Should -Match '\$GITHUB_WORKSPACE/scripts/release/Update-VersionFiles\.ps1'
        $invocation[0] | Should -Match 'RELEASE_REPO="\$GITHUB_WORKSPACE/release-preparation"'
        $invocation[0] | Should -Match '-RepoRoot "\$RELEASE_REPO"'
        $invocation[0] | Should -Match "-Channel $Channel"
        $invocation[0] | Should -Not -Match '-CatalogRefMode'
        $invocation[0] | Should -Match '-SkipPluginGenerate'

        # Candidate membership is rebuilt from the retained record and the
        # immutable source it names, and verified before the managed head moves.
        $invocation[0] | Should -Match ([regex]::Escape('RECORD="$RELEASE_REPO/.github/plugin/release-candidate.json"'))
        $invocation[0] | Should -Match ([regex]::Escape("jq -r '.sourceCommit // `"`"' `"`$RECORD`""))
        $invocation[0] | Should -Match '\^\[0-9a-f\]\{40\}\$'
        $invocation[0] | Should -Match ([regex]::Escape('git -C "$RELEASE_REPO" fetch --no-tags --depth 1 origin "$SOURCE_COMMIT"'))
        $invocation[0] | Should -Match ([regex]::Escape("'+refs/heads/${BaselineBranch}:refs/remotes/origin/${BaselineBranch}'"))
        $invocation[0] | Should -Match ([regex]::Escape('git -C "$RELEASE_REPO" show "$SOURCE_COMMIT:.github/plugin/marketplace.json"'))
        $invocation[0] | Should -Match '-CandidateAction Apply'
        $invocation[0] | Should -Match ([regex]::Escape('-CandidateSourceCommit "$SOURCE_COMMIT"'))
        $invocation[0] | Should -Match ([regex]::Escape('-CandidateSourceCatalog "$CANDIDATE_SOURCE_CATALOG"'))

        # The baseline locator is the one uniform locator the target branch
        # catalog already publishes across a complete catalog at its own
        # metadata version: the reserved OMITTED locator when no entry names a
        # ref, otherwise the one non-empty ref they all share. A historical
        # string-form source names no ref, so it reads as omitted instead of
        # failing while indexing a string. A drifted target therefore fails the
        # record instead of reissuing a locator rebuilt from a version.
        foreach ($clause in @(
                "refs/remotes/origin/${BaselineBranch}:.github/plugin/marketplace.json"
                '(.metadata.version // "") as $version'
                '[.plugins[] | (.version // "")] as $versions'
                'if (.source | type) == "object" then (.source.ref // null) else null end] as $refs'
                '($version | test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))'
                '($versions | length) > 0'
                '($versions | all(. == $version))'
                'if ($refs | all(. == null))'
                'then "OMITTED"'
                'elif ($refs | all(type == "string" and length > 0))'
                '(($refs | unique) | length) == 1'
                'if [ -z "$BASELINE_TAG" ]'
                'does not carry one uniform baseline locator across a complete catalog at its own metadata version'
            )) {
            $invocation[0] | Should -Match ([regex]::Escape($clause))
        }
        foreach ($retired in @(
                'jq -r --arg version "$BASELINE"'
                'select((.version // "") == $version)'
                '| (.source.ref // null)] as $refs'
            )) {
            $invocation[0] | Should -Not -Match ([regex]::Escape($retired))
        }

        # The catalog read is the only producer, and the updater consumes it verbatim.
        [string[]]@(
            [regex]::Matches($invocation[0], '(?m)^\s*BASELINE_TAG=\S*') | ForEach-Object { $_.Value.Trim() }
        ) | Should -Be @('BASELINE_TAG=$(git')
        [string[]]@(
            [regex]::Matches($invocation[0], '-BaselineTag\s+\S+') | ForEach-Object { $_.Value }
        ) | Should -Be @('-BaselineTag "$BASELINE_TAG"')
        foreach ($constructed in @(
                '-BaselineTag "prerelease-v'
                '-BaselineTag "v'
                'BASELINE_TAG="'
                '${BASELINE_TAG:-'
            )) {
            $invocation[0] | Should -Not -Match ([regex]::Escape($constructed))
        }
        $invocation[0] | Should -Not -Match 'hve-core-v'
        if ($ManifestPath) {
            $invocation[0] | Should -Match "-ManifestPath $([regex]::Escape($ManifestPath))"
        }
        else {
            $invocation[0] | Should -Not -Match '-ManifestPath'
        }
        $invocation[0] | Should -Match ([regex]::Escape($ConfigPath))
        $invocation[0] | Should -Match 'release-as'
        $invocation[0] | Should -Match 'del\(\.packages\["\."\]\["release-as"\]\)'
        $invocation[0] | Should -Match 'cd "\$RELEASE_REPO"'
        $invocation[0] | Should -Match 'git push origin "HEAD:refs/heads/\$RELEASE_BRANCH"'
        $invocation[0] | Should -Not -Match 'push --force'

        $runScript = $invocation[0]
        $updaterIndex = $runScript.IndexOf(
            'pwsh -NoProfile -File "$GITHUB_WORKSPACE/scripts/release/Update-VersionFiles.ps1"',
            [System.StringComparison]::Ordinal
        )
        $cdIndex = $runScript.IndexOf('cd "$RELEASE_REPO"', [System.StringComparison]::Ordinal)
        $updaterIndex | Should -BeGreaterThan -1
        $updaterIndex | Should -BeLessThan $cdIndex
        foreach ($gitCommand in @(
                'git config user.name',
                'git config user.email',
                'git add --all',
                'git diff --cached --quiet',
                'git commit -m',
                'git push origin'
            )) {
            $commandIndex = $runScript.IndexOf($gitCommand, [System.StringComparison]::Ordinal)
            $commandIndex | Should -BeGreaterThan $cdIndex -Because "$gitCommand must target release-preparation"
        }
        $runScript | Should -Not -Match 'git add --update'
    }

    It 'Validates every committed release field after the managed PR merges' {
        $workflowPath = Join-Path $script:RepositoryRoot '.github/workflows/release-stable-publish.yml'
        $workflow = Get-Content -LiteralPath $workflowPath -Raw -Encoding utf8
        $document = $workflow | ConvertFrom-Yaml
        $validate = $document['jobs']['validate-release']

        @($validate['needs']) | Should -Be @('release-please')
        [string]$validate['if'] | Should -Match "release_created == 'true'"
        [string]$validate['outputs']['sha'] | Should -BeExactly '${{ github.sha }}'

        $steps = @($validate['steps'])
        $identity = @($steps | Where-Object { [string]$_['name'] -eq 'Verify trusted release identity' })
        $identity | Should -HaveCount 1
        [string]$identity[0]['env']['EVENT_SHA'] | Should -BeExactly '${{ github.sha }}'
        [string]$identity[0]['env']['RELEASE_SHA'] | Should -BeExactly '${{ needs.release-please.outputs.sha }}'
        [string]$identity[0]['run'] | Should -Match '(?s)if \[ "\$RELEASE_SHA" != "\$EVENT_SHA" \]; then\s+echo "::error::release-please SHA does not match the merged release/stable commit"\s+exit 1\s+fi'

        $checkout = @($steps | Where-Object { $_.Contains('uses') -and [string]$_['uses'] -match '^actions/checkout@' })
        $checkout | Should -HaveCount 1
        [string]$checkout[0]['with']['ref'] | Should -BeExactly 'release/stable'
        [string]$checkout[0]['with']['fetch-depth'] | Should -BeExactly '0'
        $steps.IndexOf($identity[0]) | Should -BeLessThan $steps.IndexOf($checkout[0])
        $workflow | Should -Not -Match 'ref:\s*\$\{\{\s*needs\.release-please\.outputs\.sha'

        foreach ($jobName in @('extension-provenance', 'plugin-package-release')) {
            [string]$document['jobs'][$jobName]['with']['source-ref'] |
                Should -BeExactly '${{ needs.validate-release.outputs.sha }}'
        }

        foreach ($jobName in @('generate-dependency-sbom', 'upload-plugin-packages', 'verify-provenance')) {
            $sourceCheckout = @(
                $document['jobs'][$jobName]['steps'] |
                    Where-Object { $_.Contains('uses') -and [string]$_['uses'] -match '^actions/checkout@' }
            )
            $sourceCheckout | Should -HaveCount 1
            [string]$sourceCheckout[0]['with']['ref'] |
                Should -BeExactly '${{ needs.validate-release.outputs.sha }}'
        }

        $runs = [string[]]@($validate['steps'] | Where-Object { $_.Contains('run') } | ForEach-Object { [string]$_['run'] })
        $consistency = @($runs | Where-Object { $_ -match 'package-lock\.json:\.version' })
        $consistency | Should -HaveCount 1
        foreach ($required in @(
                'package.json:.version',
                'package-lock.json:.version',
                '.release-please-manifest.json',
                'extension/templates/package.template.json:.version',
                '.github/plugin/marketplace.json:.metadata.version'
            )) {
            $consistency[0] | Should -Match ([regex]::Escape($required))
        }
        $consistency[0] | Should -Match ([regex]::Escape('.source.ref == ("v" + $version)'))
        $consistency[0] | Should -Not -Match 'hve-core-v'

        $candidate = @($runs | Where-Object { $_ -match '-CandidateAction Verify' })
        $candidate | Should -HaveCount 1
        $candidate[0] | Should -Match '-Channel Stable'
        $candidate[0] | Should -Match 'scripts/release/Update-VersionFiles\.ps1'

        $config = Get-Content -LiteralPath (Join-Path $script:RepositoryRoot 'release-please-config.json') -Raw -Encoding utf8 | ConvertFrom-Json
        $jsonPaths = [string[]]@($config.packages.'.'.'extra-files' | ForEach-Object { [string]$_.jsonpath })
        @($jsonPaths | Where-Object { $_ -match 'source|ref' }) | Should -HaveCount 0
    }
}
