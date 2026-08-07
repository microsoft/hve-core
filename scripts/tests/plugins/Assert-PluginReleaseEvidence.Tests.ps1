#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../plugins/Assert-PluginReleaseEvidence.ps1')
    Import-Module (Join-Path $PSScriptRoot 'PluginTestFixtures.psm1') -Force
    Mock Write-Host {}
    $script:OriginalPluginStagingRoot = $env:HVE_PLUGIN_STAGING_ROOT

    $script:SourceCommit = '0123456789abcdef0123456789abcdef01234567'

    function New-EvidenceTree {
        <#
        .SYNOPSIS
        Builds a two-package snapshot tree with known content.
        #>
        param([Parameter(Mandatory)][string]$Root)

        foreach ($file in @(
                @{ Path = 'alpha/plugin.json'; Content = '{"name":"alpha"}' }
                @{ Path = 'alpha/README.md'; Content = "# alpha`n" }
                @{ Path = 'bravo/plugin.json'; Content = '{"name":"bravo"}' }
                @{ Path = 'bravo/nested/notes.md'; Content = "# notes`n" }
            )) {
            $fullPath = Join-Path $Root $file.Path
            New-Item -ItemType Directory -Path (Split-Path -Parent $fullPath) -Force | Out-Null
            Set-Content -LiteralPath $fullPath -Value $file.Content -Encoding utf8NoBOM -NoNewline
        }
        return $Root
    }

    function New-CanonicalEvidenceRepository {
        <#
        .SYNOPSIS
        Builds a fixture repository with two catalog packages over canonical sources.

        .DESCRIPTION
        The rpi package declares one component of every kind, including a
        directory-valued skill and a hook manifest with a sibling payload, so
        expansion rules are proved rather than assumed. ReverseOrder writes the
        same content in the opposite order so enumeration order can be varied
        without varying content.
        #>
        param(
            [Parameter(Mandatory)][string]$Root,
            [switch]$ReverseOrder
        )

        New-PluginFixtureRepository -Path $Root -Version '9.9.9' -SkipSharedResources | Out-Null

        $entries = @(
            New-PluginFixtureEntry -Name 'rpi' -Version '9.9.9' `
                -Agents @('agents/rpi/rpi-planner.agent.md') `
                -Commands @('prompts/rpi/rpi-plan.prompt.md') `
                -Rules @('instructions/shared/hve-core-location.instructions.md') `
                -Skills @('skills/rpi/rpi-plan') `
                -Hook 'hooks/rpi/telemetry.json'
            New-PluginFixtureEntry -Name 'ado' -Version '9.9.9' `
                -Rules @('instructions/shared/hve-core-location.instructions.md')
        )

        if ($ReverseOrder) {
            Add-PluginFixtureCatalog -RepoRoot $Root -Entries @($entries[1], $entries[0]) -Version '9.9.9' | Out-Null
            Add-PluginFixtureArtifactSet -RepoRoot $Root | Out-Null
        }
        else {
            Add-PluginFixtureArtifactSet -RepoRoot $Root | Out-Null
            Add-PluginFixtureCatalog -RepoRoot $Root -Entries $entries -Version '9.9.9' | Out-Null
        }

        return $Root
    }
}

Describe 'Get-PluginContentDigest' -Tag 'Unit' {
    BeforeEach {
        $script:digestRoot = New-EvidenceTree -Root (Join-Path $TestDrive ([System.Guid]::NewGuid().ToString()))
    }

    Context 'when digesting a populated tree' {
        BeforeEach {
            $script:digestReport = Get-PluginContentDigest -Path $script:digestRoot
        }

        It 'Matches an independently computed path and content digest' {
            $script:digestReport.Digest | Should -BeExactly (Get-PluginFixtureTreeDigest -Path $script:digestRoot)
        }

        It 'Counts every file in the tree' {
            $script:digestReport.FileCount | Should -Be 4
        }

        It 'Sums the byte length of every file' {
            $expectedBytes = @(Get-ChildItem -LiteralPath $script:digestRoot -File -Recurse -Force |
                    Measure-Object -Property Length -Sum).Sum
            $script:digestReport.TotalBytes | Should -Be $expectedBytes
        }
    }

    Context 'when incidental file metadata changes' {
        It 'Produces the same digest after a timestamp change' {
            $before = (Get-PluginContentDigest -Path $script:digestRoot).Digest
            foreach ($file in Get-ChildItem -LiteralPath $script:digestRoot -File -Recurse -Force) {
                $file.LastWriteTimeUtc = [datetime]::UtcNow.AddDays(-30)
            }
            (Get-PluginContentDigest -Path $script:digestRoot).Digest | Should -BeExactly $before
        }

        It 'Produces the same digest for a tree written in a different order' {
            $reordered = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path (Join-Path $reordered 'bravo/nested') -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $reordered 'bravo/nested/notes.md') -Value "# notes`n" -Encoding utf8NoBOM -NoNewline
            Set-Content -LiteralPath (Join-Path $reordered 'bravo/plugin.json') -Value '{"name":"bravo"}' -Encoding utf8NoBOM -NoNewline
            New-Item -ItemType Directory -Path (Join-Path $reordered 'alpha') -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $reordered 'alpha/README.md') -Value "# alpha`n" -Encoding utf8NoBOM -NoNewline
            Set-Content -LiteralPath (Join-Path $reordered 'alpha/plugin.json') -Value '{"name":"alpha"}' -Encoding utf8NoBOM -NoNewline

            (Get-PluginContentDigest -Path $reordered).Digest |
                Should -BeExactly (Get-PluginContentDigest -Path $script:digestRoot).Digest
        }
    }

    Context 'when a path changes without a content change' {
        It 'Produces a different digest' {
            $before = (Get-PluginContentDigest -Path $script:digestRoot).Digest
            Rename-Item -LiteralPath (Join-Path $script:digestRoot 'alpha/README.md') -NewName 'OVERVIEW.md'
            (Get-PluginContentDigest -Path $script:digestRoot).Digest | Should -Not -BeExactly $before
        }
    }

    Context 'when the tree is absent' {
        It 'Reports an empty digest report' {
            $absentReport = Get-PluginContentDigest -Path (Join-Path $TestDrive 'absent-tree')
            $absentReport.FileCount | Should -Be 0
            $absentReport.TotalBytes | Should -Be 0
            $absentReport.Digest | Should -BeExactly (
                [System.Convert]::ToHexString(
                    [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes(''))
                ).ToLowerInvariant()
            )
        }
    }
}

Describe 'Get-PluginTreeEvidence' -Tag 'Unit' {
    BeforeEach {
        $script:treeRoot = New-EvidenceTree -Root (Join-Path $TestDrive ([System.Guid]::NewGuid().ToString()))
        $script:treeEvidence = Get-PluginTreeEvidence -PluginsDir $script:treeRoot
    }

    Context 'when digesting a snapshot tree' {
        It 'Records every package in ordinal order' {
            @($script:treeEvidence.Packages | ForEach-Object { $_['name'] }) | Should -Be @('alpha', 'bravo')
        }

        It 'Records an independently computed digest per package' {
            foreach ($package in $script:treeEvidence.Packages) {
                $package['digest'] | Should -BeExactly (
                    Get-PluginFixtureTreeDigest -Path (Join-Path $script:treeRoot $package['name'])
                )
            }
        }

        It 'Records the file count per package' {
            @($script:treeEvidence.Packages | ForEach-Object { $_['fileCount'] }) | Should -Be @(2, 2)
        }

        It 'Records the tree digest over the whole snapshot' {
            $script:treeEvidence.Digest | Should -BeExactly (Get-PluginFixtureTreeDigest -Path $script:treeRoot)
            $script:treeEvidence.FileCount | Should -Be 4
        }

        It 'Contains no symbolic link' {
            @(Get-PluginFixtureReparsePoint -Path $script:treeRoot) | Should -HaveCount 0
        }
    }

    Context 'when the snapshot tree is absent' {
        It 'Refuses to record evidence' {
            { Get-PluginTreeEvidence -PluginsDir (Join-Path $TestDrive 'absent-snapshot') } |
                Should -Throw -ExpectedMessage '*Generated package tree not found*'
        }
    }
}

Describe 'New-PluginReleaseEvidenceDocument' -Tag 'Unit' {
    BeforeEach {
        $script:documentRoot = New-EvidenceTree -Root (Join-Path $TestDrive ([System.Guid]::NewGuid().ToString()))
        $script:documentTree = Get-PluginTreeEvidence -PluginsDir $script:documentRoot
        $script:documentLocator = New-PluginReleaseLocator -Version '9.9.9' -Repo 'contoso/contoso-hve'
        $script:evidenceDocument = New-PluginReleaseEvidenceDocument -SourceCommit $script:SourceCommit `
            -Version '9.9.9' -Locator $script:documentLocator -TreeEvidence $script:documentTree
    }

    Context 'when the source, version, locator, and digest agree' {
        It 'Emits document keys in a fixed order' {
            @($script:evidenceDocument.Keys) | Should -Be @(
                'schema', 'sourceCommit', 'version', 'locator', 'packageCount',
                'packages', 'fileCount', 'totalBytes', 'digest', 'generatedAt'
            )
        }

        It 'Binds the source commit and version' {
            $script:evidenceDocument['sourceCommit'] | Should -BeExactly $script:SourceCommit
            $script:evidenceDocument['version'] | Should -BeExactly '9.9.9'
        }

        It 'Binds the immutable locator without a sha field' {
            @($script:evidenceDocument['locator'].Keys) | Should -Be @('source', 'repo', 'path', 'ref')
            $script:evidenceDocument['locator']['ref'] | Should -BeExactly 'plugins-v9.9.9'
            $script:evidenceDocument['locator']['repo'] | Should -BeExactly 'contoso/contoso-hve'
            ($script:evidenceDocument | ConvertTo-Json -Depth 10) | Should -Not -Match '"sha"'
        }

        It 'Binds the package count, file count, byte total, and digest' {
            $expectedPackageCount = @(Get-ChildItem -LiteralPath $script:documentRoot -Directory).Count
            $script:evidenceDocument['packageCount'] | Should -Be $expectedPackageCount
            $script:evidenceDocument['fileCount'] | Should -Be 4
            $script:evidenceDocument['totalBytes'] | Should -Be (
                @(Get-ChildItem -LiteralPath $script:documentRoot -File -Recurse -Force | Measure-Object -Property Length -Sum).Sum
            )
            $script:evidenceDocument['digest'] | Should -BeExactly (Get-PluginFixtureTreeDigest -Path $script:documentRoot)
        }
    }

    Context 'when the binding inputs disagree' {
        It 'Refuses the source commit <Label>' -ForEach @(
            @{ Label = 'in uppercase'; Commit = '0123456789ABCDEF0123456789ABCDEF01234567' }
            @{ Label = 'that is abbreviated'; Commit = '0123456' }
            @{ Label = 'that is not hexadecimal'; Commit = 'z123456789abcdef0123456789abcdef01234567' }
        ) {
            { New-PluginReleaseEvidenceDocument -SourceCommit $Commit -Version '9.9.9' `
                    -Locator $script:documentLocator -TreeEvidence $script:documentTree } |
                Should -Throw -ExpectedMessage '*must be a full 40-character lowercase commit id*'
        }

        It 'Refuses a locator that does not match the version' {
            { New-PluginReleaseEvidenceDocument -SourceCommit $script:SourceCommit -Version '1.0.0' `
                    -Locator $script:documentLocator -TreeEvidence $script:documentTree } |
                Should -Throw -ExpectedMessage "*does not match package version '1.0.0'*"
        }
    }
}

Describe 'Compare-PluginReleaseEvidence' -Tag 'Unit' {
    BeforeEach {
        $script:compareRoot = New-EvidenceTree -Root (Join-Path $TestDrive ([System.Guid]::NewGuid().ToString()))
        $script:actualEvidence = New-PluginReleaseEvidenceDocument -SourceCommit $script:SourceCommit -Version '9.9.9' `
            -Locator (New-PluginReleaseLocator -Version '9.9.9') `
            -TreeEvidence (Get-PluginTreeEvidence -PluginsDir $script:compareRoot)
        $script:recordedEvidence = $script:actualEvidence | ConvertTo-Json -Depth 10 | ConvertFrom-Json -AsHashtable
    }

    Context 'when the recorded evidence reproduces' {
        It 'Reports no disagreement' {
            @(Compare-PluginReleaseEvidence -Expected $script:recordedEvidence -Actual $script:actualEvidence) |
                Should -HaveCount 0
        }

        It 'Ignores the incidental generation timestamp' {
            $script:recordedEvidence['generatedAt'] = '1999-01-01T00:00:00.0000000Z'
            @(Compare-PluginReleaseEvidence -Expected $script:recordedEvidence -Actual $script:actualEvidence) |
                Should -HaveCount 0
        }
    }

    Context 'when a bound value disagrees' {
        It 'Reports a <Field> disagreement' -ForEach @(
            @{ Field = 'schema'; Value = 'hve-core/plugin-release-evidence/v0' }
            @{ Field = 'sourceCommit'; Value = 'fedcba9876543210fedcba9876543210fedcba98' }
            @{ Field = 'version'; Value = '1.0.0' }
            @{ Field = 'digest'; Value = 'deadbeef' }
        ) {
            $script:recordedEvidence[$Field] = $Value
            $differences = @(Compare-PluginReleaseEvidence -Expected $script:recordedEvidence -Actual $script:actualEvidence)
            ($differences -join ' ') | Should -Match "$Field disagreement: recorded '$([regex]::Escape($Value))'"
        }

        It 'Reports a missing required field' {
            $script:recordedEvidence.Remove('digest')
            $differences = @(Compare-PluginReleaseEvidence -Expected $script:recordedEvidence -Actual $script:actualEvidence)
            ($differences -join ' ') | Should -Match "recorded evidence is missing required field 'digest'"
        }

        It 'Reports a locator disagreement' {
            $script:recordedEvidence['locator']['ref'] = 'plugins-v1.0.0'
            $differences = @(Compare-PluginReleaseEvidence -Expected $script:recordedEvidence -Actual $script:actualEvidence)
            ($differences -join ' ') | Should -Match "locator.ref disagreement: recorded 'plugins-v1\.0\.0'"
        }

        It 'Reports a missing locator' {
            $script:recordedEvidence.Remove('locator')
            $differences = @(Compare-PluginReleaseEvidence -Expected $script:recordedEvidence -Actual $script:actualEvidence)
            ($differences -join ' ') | Should -Match "recorded evidence is missing required field 'locator'"
        }
    }

    Context 'when the package set disagrees' {
        It 'Reports a package present only in the snapshot' {
            $script:recordedEvidence['packages'] = @($script:recordedEvidence['packages'] | Where-Object { $_['name'] -ne 'bravo' })
            $differences = @(Compare-PluginReleaseEvidence -Expected $script:recordedEvidence -Actual $script:actualEvidence)
            ($differences -join ' ') | Should -Match "package 'bravo' is present in the snapshot but absent from recorded evidence"
        }

        It 'Reports a package present only in recorded evidence' {
            $script:recordedEvidence['packages'] += @{ name = 'charlie'; digest = 'deadbeef'; fileCount = 1 }
            $differences = @(Compare-PluginReleaseEvidence -Expected $script:recordedEvidence -Actual $script:actualEvidence)
            ($differences -join ' ') | Should -Match "package 'charlie' is recorded in evidence but absent from the snapshot"
        }

        It 'Reports a per-package digest disagreement' {
            $script:recordedEvidence['packages'][0]['digest'] = 'deadbeef'
            $differences = @(Compare-PluginReleaseEvidence -Expected $script:recordedEvidence -Actual $script:actualEvidence)
            ($differences -join ' ') | Should -Match "package 'alpha' digest disagreement: recorded 'deadbeef'"
        }
    }
}

Describe 'Invoke-PluginReleaseEvidence generated-tree mode' -Tag 'Unit' {
    BeforeEach {
        $script:evidenceRepo = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
        New-PluginFixtureRepository -Path $script:evidenceRepo -Version '9.9.9' -SkipSharedResources | Out-Null
        $script:snapshotRoot = Join-Path $TestDrive "$([System.Guid]::NewGuid())-staging"
        $env:HVE_PLUGIN_STAGING_ROOT = $script:snapshotRoot
        New-EvidenceTree -Root $script:snapshotRoot | Out-Null
        $script:recordedPath = Join-Path $script:evidenceRepo 'logs/plugin-release-evidence.json'
    }

    Context 'when the staging root is unavailable or unsafe' {
        It 'Rejects a missing staging root' {
            $env:HVE_PLUGIN_STAGING_ROOT = ''
            { Invoke-PluginReleaseEvidence -RepoRoot $script:evidenceRepo -EvidenceVersion v1 -SourceCommit $script:SourceCommit -OutputPath '' } |
                Should -Throw -ExpectedMessage '*A staging root is required*'
        }

        It 'Rejects a staging root inside the repository' {
            { Invoke-PluginReleaseEvidence -RepoRoot $script:evidenceRepo -EvidenceVersion v1 `
                    -PluginsDir (Join-Path $script:evidenceRepo 'plugins') `
                    -SourceCommit $script:SourceCommit -OutputPath '' } |
                Should -Throw -ExpectedMessage '*resolves inside the repository root*'
        }
    }

    Context 'when recording evidence for a snapshot' {
        BeforeEach {
            $script:recordRun = Invoke-PluginReleaseEvidence -RepoRoot $script:evidenceRepo -EvidenceVersion v1 `
                -SourceCommit $script:SourceCommit -OutputPath 'logs/plugin-release-evidence.json'
        }

        It 'Succeeds with no finding' {
            $script:recordRun.Success | Should -BeTrue
            $script:recordRun.ErrorCount | Should -Be 0
            @($script:recordRun.Errors) | Should -HaveCount 0
        }

        It 'Reads the version from package.json and derives the locator' {
            $script:recordRun.Evidence['version'] | Should -BeExactly '9.9.9'
            $script:recordRun.Evidence['locator']['ref'] | Should -BeExactly 'plugins-v9.9.9'
        }

        It 'Writes a parsable evidence document' {
            $recorded = Get-Content -LiteralPath $script:recordedPath -Raw | ConvertFrom-Json -AsHashtable
            $recorded['digest'] | Should -BeExactly (Get-PluginFixtureTreeDigest -Path $script:snapshotRoot)
            $recorded['packageCount'] | Should -Be @(Get-ChildItem -LiteralPath $script:snapshotRoot -Directory).Count
        }

        It 'Records no symbolic-link evidence' {
            @(Get-PluginFixtureReparsePoint -Path $script:snapshotRoot) | Should -HaveCount 0
            $indexEntries = @(Invoke-PluginFixtureGit -RepoRoot $script:evidenceRepo -Arguments @('ls-files', '--cached', '--stage'))
            @($indexEntries | Where-Object { $_ -match '^120000' }) | Should -HaveCount 0
        }
    }

    Context 'when verifying against recorded evidence' {
        BeforeEach {
            Invoke-PluginReleaseEvidence -RepoRoot $script:evidenceRepo -EvidenceVersion v1 -SourceCommit $script:SourceCommit `
                -OutputPath 'logs/plugin-release-evidence.json' | Out-Null
        }

        It 'Succeeds when the snapshot reproduces' {
            $verifyRun = Invoke-PluginReleaseEvidence -RepoRoot $script:evidenceRepo -EvidenceVersion v1 -SourceCommit $script:SourceCommit `
                -OutputPath '' -ExpectedEvidencePath 'logs/plugin-release-evidence.json'
            $verifyRun.Success | Should -BeTrue
            $verifyRun.ErrorCount | Should -Be 0
        }

        It 'Refuses a snapshot whose content changed' {
            Set-Content -LiteralPath (Join-Path $script:snapshotRoot 'alpha/README.md') -Value "# tampered`n" -Encoding utf8NoBOM -NoNewline
            $verifyRun = Invoke-PluginReleaseEvidence -RepoRoot $script:evidenceRepo -EvidenceVersion v1 -SourceCommit $script:SourceCommit `
                -OutputPath '' -ExpectedEvidencePath 'logs/plugin-release-evidence.json'
            $verifyRun.Success | Should -BeFalse
            ($verifyRun.Errors -join ' ') | Should -Match 'digest disagreement'
            ($verifyRun.Errors -join ' ') | Should -Match "package 'alpha' digest disagreement"
        }

        It 'Refuses a snapshot built from a different source commit' {
            $verifyRun = Invoke-PluginReleaseEvidence -RepoRoot $script:evidenceRepo -EvidenceVersion v1 `
                -SourceCommit 'fedcba9876543210fedcba9876543210fedcba98' `
                -OutputPath '' -ExpectedEvidencePath 'logs/plugin-release-evidence.json'
            $verifyRun.Success | Should -BeFalse
            ($verifyRun.Errors -join ' ') | Should -Match 'sourceCommit disagreement'
        }
    }

    Context 'when the recorded evidence cannot be read' {
        It 'Reports a missing evidence document' {
            $run = Invoke-PluginReleaseEvidence -RepoRoot $script:evidenceRepo -EvidenceVersion v1 -SourceCommit $script:SourceCommit `
                -OutputPath '' -ExpectedEvidencePath 'logs/absent-evidence.json'
            $run.Success | Should -BeFalse
            ($run.Errors -join ' ') | Should -Match 'recorded evidence not found: logs/absent-evidence.json'
        }

        It 'Reports evidence that is not valid JSON' {
            New-Item -ItemType Directory -Path (Join-Path $script:evidenceRepo 'logs') -Force | Out-Null
            Set-Content -LiteralPath $script:recordedPath -Value '{ "digest": ' -Encoding utf8NoBOM -NoNewline
            $run = Invoke-PluginReleaseEvidence -RepoRoot $script:evidenceRepo -EvidenceVersion v1 -SourceCommit $script:SourceCommit `
                -OutputPath '' -ExpectedEvidencePath 'logs/plugin-release-evidence.json'
            $run.Success | Should -BeFalse
            ($run.Errors -join ' ') | Should -Match 'recorded evidence is not valid JSON'
        }

        It 'Reports evidence that is not an evidence document' {
            New-Item -ItemType Directory -Path (Join-Path $script:evidenceRepo 'logs') -Force | Out-Null
            Set-Content -LiteralPath $script:recordedPath -Value '[]' -Encoding utf8NoBOM -NoNewline
            $run = Invoke-PluginReleaseEvidence -RepoRoot $script:evidenceRepo -EvidenceVersion v1 -SourceCommit $script:SourceCommit `
                -OutputPath '' -ExpectedEvidencePath 'logs/plugin-release-evidence.json'
            $run.Success | Should -BeFalse
            ($run.Errors -join ' ') | Should -Match 'recorded evidence is not an evidence document'
        }
    }

    Context 'when a package count precondition is supplied' {
        It 'Accepts the observed package count' {
            $observedCount = @(Get-ChildItem -LiteralPath $script:snapshotRoot -Directory).Count
            $run = Invoke-PluginReleaseEvidence -RepoRoot $script:evidenceRepo -EvidenceVersion v1 -SourceCommit $script:SourceCommit `
                -OutputPath '' -ExpectedPackageCount $observedCount
            $run.Success | Should -BeTrue
        }

        It 'Refuses a package count the snapshot does not meet' {
            $observedCount = @(Get-ChildItem -LiteralPath $script:snapshotRoot -Directory).Count
            $run = Invoke-PluginReleaseEvidence -RepoRoot $script:evidenceRepo -EvidenceVersion v1 -SourceCommit $script:SourceCommit `
                -OutputPath '' -ExpectedPackageCount ($observedCount + 1)
            $run.Success | Should -BeFalse
            ($run.Errors -join ' ') |
                Should -Match "package count precondition failed: expected $($observedCount + 1), snapshot has $observedCount"
        }

        It 'Applies no precondition by default' {
            $run = Invoke-PluginReleaseEvidence -RepoRoot $script:evidenceRepo -EvidenceVersion v1 -SourceCommit $script:SourceCommit -OutputPath ''
            $run.Success | Should -BeTrue
            ($run.Errors -join ' ') | Should -Not -Match 'package count precondition'
        }
    }

    Context 'when exactly one package is required' {
        It 'Accepts a snapshot holding only the surviving package' {
            Remove-Item -LiteralPath (Join-Path $script:snapshotRoot 'bravo') -Recurse -Force
            $run = Invoke-PluginReleaseEvidence -RepoRoot $script:evidenceRepo -EvidenceVersion v1 -SourceCommit $script:SourceCommit `
                -OutputPath '' -ExpectedPackageCount 1
            $run.Success | Should -BeTrue
            $run.Evidence['packageCount'] | Should -Be 1
        }

        It 'Refuses a snapshot with <Count> package roots' -ForEach @(
            @{ Count = 0; Removed = @('alpha', 'bravo') }
            @{ Count = 2; Removed = @() }
        ) {
            foreach ($name in $Removed) {
                Remove-Item -LiteralPath (Join-Path $script:snapshotRoot $name) -Recurse -Force
            }
            $run = Invoke-PluginReleaseEvidence -RepoRoot $script:evidenceRepo -EvidenceVersion v1 -SourceCommit $script:SourceCommit `
                -OutputPath '' -ExpectedPackageCount 1
            $run.Success | Should -BeFalse
            ($run.Errors -join ' ') |
                Should -Match "package count precondition failed: expected 1, snapshot has $Count"
        }
    }

    Context 'when the snapshot tree is absent' {
        It 'Refuses to record evidence' {
            { Invoke-PluginReleaseEvidence -RepoRoot $script:evidenceRepo -EvidenceVersion v1 -SourceCommit $script:SourceCommit `
                    -PluginsDir (Join-Path $TestDrive 'absent-plugins') -OutputPath '' } |
                Should -Throw -ExpectedMessage '*Generated package tree not found*'
        }
    }
}

Describe 'Get-PluginCanonicalPackageEvidence' -Tag 'Unit' {
    BeforeEach {
        $script:canonicalRepo = New-CanonicalEvidenceRepository -Root (Join-Path $TestDrive ([System.Guid]::NewGuid().ToString()))
        $script:canonicalEvidence = Get-PluginCanonicalPackageEvidence -RepoRoot $script:canonicalRepo `
            -CatalogPath '.github/plugin/marketplace.json' -Channel PreRelease
    }

    Context 'when digesting the declared canonical source set' {
        It 'Covers every eligible package in ordinal order' {
            @($script:canonicalEvidence.Packages | ForEach-Object { $_['name'] }) | Should -Be @('ado', 'rpi')
        }

        It 'Expands a directory-valued component to its tracked files' {
            $rpi = @($script:canonicalEvidence.Packages | Where-Object { $_['name'] -eq 'rpi' })[0]
            # agent, command, rule, hook manifest, hook payload, and two skill files
            $rpi['fileCount'] | Should -Be 7
        }

        It 'Digests every package to lowercase 64-hex' {
            foreach ($package in $script:canonicalEvidence.Packages) {
                $package['digest'] | Should -Match '^[0-9a-f]{64}$'
                $package['fileCount'] | Should -BeGreaterThan 0
            }
            $script:canonicalEvidence.Digest | Should -Match '^[0-9a-f]{64}$'
        }

        It 'Sums file counts and byte totals across packages' {
            $expectedFiles = @($script:canonicalEvidence.Packages | ForEach-Object { $_['fileCount'] } | Measure-Object -Sum).Sum
            $script:canonicalEvidence.FileCount | Should -Be $expectedFiles
            $script:canonicalEvidence.TotalBytes | Should -BeGreaterThan 0
        }

        It 'Ingests no untracked working-tree residue' {
            Add-PluginFixtureFile -RepoRoot $script:canonicalRepo `
                -RelativePath '.github/skills/rpi/rpi-plan/.venv/pyvenv.cfg' -Content "home = /tmp`n" -Untracked | Out-Null
            $rerun = Get-PluginCanonicalPackageEvidence -RepoRoot $script:canonicalRepo `
                -CatalogPath '.github/plugin/marketplace.json' -Channel PreRelease
            $rerun.Digest | Should -BeExactly $script:canonicalEvidence.Digest
        }
    }

    Context 'when enumeration order or incidental metadata changes' {
        It 'Reproduces the same digest' {
            foreach ($file in Get-ChildItem -LiteralPath (Join-Path $script:canonicalRepo '.github') -File -Recurse -Force) {
                $file.LastWriteTimeUtc = [datetime]::UtcNow.AddDays(-30)
            }
            $reordered = New-CanonicalEvidenceRepository -Root (Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())) -ReverseOrder
            $rerun = Get-PluginCanonicalPackageEvidence -RepoRoot $reordered `
                -CatalogPath '.github/plugin/marketplace.json' -Channel PreRelease
            $rerun.Digest | Should -BeExactly $script:canonicalEvidence.Digest
            @($rerun.Packages | ForEach-Object { $_['digest'] }) |
                Should -Be @($script:canonicalEvidence.Packages | ForEach-Object { $_['digest'] })
        }
    }

    Context 'when one canonical file changes' {
        It 'Moves only the owning package digest and the total' {
            Add-PluginFixtureFile -RepoRoot $script:canonicalRepo `
                -RelativePath '.github/skills/rpi/rpi-plan/references/checklist.md' -Content "# Checklist changed`n" | Out-Null
            $rerun = Get-PluginCanonicalPackageEvidence -RepoRoot $script:canonicalRepo `
                -CatalogPath '.github/plugin/marketplace.json' -Channel PreRelease

            $beforeByName = @{}
            foreach ($package in $script:canonicalEvidence.Packages) { $beforeByName[$package['name']] = $package['digest'] }
            $afterByName = @{}
            foreach ($package in $rerun.Packages) { $afterByName[$package['name']] = $package['digest'] }

            $afterByName['rpi'] | Should -Not -BeExactly $beforeByName['rpi']
            $afterByName['ado'] | Should -BeExactly $beforeByName['ado']
            $rerun.Digest | Should -Not -BeExactly $script:canonicalEvidence.Digest
        }
    }

    Context 'when package membership changes' {
        It 'Moves the owning package digest and the total' {
            $entries = @(
                New-PluginFixtureEntry -Name 'rpi' -Version '9.9.9' `
                    -Agents @('agents/rpi/rpi-planner.agent.md') `
                    -Commands @('prompts/rpi/rpi-plan.prompt.md') `
                    -Skills @('skills/rpi/rpi-plan') `
                    -Hook 'hooks/rpi/telemetry.json'
                New-PluginFixtureEntry -Name 'ado' -Version '9.9.9' `
                    -Rules @('instructions/shared/hve-core-location.instructions.md')
            )
            Add-PluginFixtureCatalog -RepoRoot $script:canonicalRepo -Entries $entries -Version '9.9.9' | Out-Null
            $rerun = Get-PluginCanonicalPackageEvidence -RepoRoot $script:canonicalRepo `
                -CatalogPath '.github/plugin/marketplace.json' -Channel PreRelease

            $before = @($script:canonicalEvidence.Packages | Where-Object { $_['name'] -eq 'rpi' })[0]
            $after = @($rerun.Packages | Where-Object { $_['name'] -eq 'rpi' })[0]
            $after['fileCount'] | Should -Be ($before['fileCount'] - 1)
            $after['digest'] | Should -Not -BeExactly $before['digest']
            $rerun.Digest | Should -Not -BeExactly $script:canonicalEvidence.Digest
        }

        It 'Refuses a package whose declared component matches no tracked source' {
            $entries = @(
                New-PluginFixtureEntry -Name 'rpi' -Version '9.9.9' -Agents @('agents/rpi/absent.agent.md')
            )
            Add-PluginFixtureCatalog -RepoRoot $script:canonicalRepo -Entries $entries -Version '9.9.9' | Out-Null
            { Get-PluginCanonicalPackageEvidence -RepoRoot $script:canonicalRepo `
                    -CatalogPath '.github/plugin/marketplace.json' -Channel PreRelease } |
                Should -Throw -ExpectedMessage '*matches no git-tracked canonical source*'
        }

        It 'Refuses a package that declares no component at all' {
            $entries = @(New-PluginFixtureEntry -Name 'rpi' -Version '9.9.9')
            Add-PluginFixtureCatalog -RepoRoot $script:canonicalRepo -Entries $entries -Version '9.9.9' | Out-Null
            { Get-PluginCanonicalPackageEvidence -RepoRoot $script:canonicalRepo `
                    -CatalogPath '.github/plugin/marketplace.json' -Channel PreRelease } |
                Should -Throw -ExpectedMessage '*resolves to no git-tracked canonical source file*'
        }
    }
}

Describe 'New-PluginCanonicalEvidenceDocument' -Tag 'Unit' {
    BeforeEach {
        $script:documentCanonicalRepo = New-CanonicalEvidenceRepository -Root (Join-Path $TestDrive ([System.Guid]::NewGuid().ToString()))
        $script:canonicalPackages = Get-PluginCanonicalPackageEvidence -RepoRoot $script:documentCanonicalRepo `
            -CatalogPath '.github/plugin/marketplace.json' -Channel PreRelease
        $script:canonicalLocator = New-PluginReleaseLocator -Version '9.9.9' -Repo 'contoso/contoso-hve' `
            -TagPrefix 'hve-core-v' -PathPrefix ''
        $script:canonicalDocument = New-PluginCanonicalEvidenceDocument -SourceCommit $script:SourceCommit `
            -Version '9.9.9' -Locator $script:canonicalLocator -PackageEvidence $script:canonicalPackages
    }

    Context 'when the source, version, locator, and digest agree' {
        It 'Declares the canonical schema' {
            $script:canonicalDocument['schema'] | Should -BeExactly 'hve-core/plugin-release-evidence/v2'
        }

        It 'Emits document keys in a fixed order' {
            @($script:canonicalDocument.Keys) | Should -Be @(
                'schema', 'sourceCommit', 'version', 'locator', 'packageCount',
                'packages', 'fileCount', 'totalBytes', 'digest', 'generatedAt'
            )
        }

        It 'Binds a pathless hve-core-v locator' {
            @($script:canonicalDocument['locator'].Keys) | Should -Be @('source', 'repo', 'ref')
            $script:canonicalDocument['locator']['ref'] | Should -BeExactly 'hve-core-v9.9.9'
            $script:canonicalDocument['locator']['repo'] | Should -BeExactly 'contoso/contoso-hve'
            ($script:canonicalDocument | ConvertTo-Json -Depth 10) | Should -Not -Match '"path"'
            ($script:canonicalDocument | ConvertTo-Json -Depth 10) | Should -Not -Match '"sha"'
        }

        It 'Binds the package count, file count, byte total, and digest' {
            $script:canonicalDocument['packageCount'] | Should -Be @($script:canonicalPackages.Packages).Count
            $script:canonicalDocument['fileCount'] | Should -Be $script:canonicalPackages.FileCount
            $script:canonicalDocument['totalBytes'] | Should -Be $script:canonicalPackages.TotalBytes
            $script:canonicalDocument['digest'] | Should -BeExactly $script:canonicalPackages.Digest
        }
    }

    Context 'when the binding inputs disagree' {
        It 'Refuses a locator that does not match the version' {
            { New-PluginCanonicalEvidenceDocument -SourceCommit $script:SourceCommit -Version '1.0.0' `
                    -Locator $script:canonicalLocator -PackageEvidence $script:canonicalPackages } |
                Should -Throw -ExpectedMessage "*does not match package version '1.0.0'*"
        }

        It 'Refuses a locator that declares a package path' {
            $pathed = New-PluginReleaseLocator -Version '9.9.9' -TagPrefix 'hve-core-v' -PathPrefix 'plugins'
            { New-PluginCanonicalEvidenceDocument -SourceCommit $script:SourceCommit -Version '9.9.9' `
                    -Locator $pathed -PackageEvidence $script:canonicalPackages } |
                Should -Throw -ExpectedMessage '*must use a pathless locator*'
        }

        It 'Refuses an abbreviated source commit' {
            { New-PluginCanonicalEvidenceDocument -SourceCommit '0123456' -Version '9.9.9' `
                    -Locator $script:canonicalLocator -PackageEvidence $script:canonicalPackages } |
                Should -Throw -ExpectedMessage '*must be a full 40-character lowercase commit id*'
        }

        It 'Refuses an empty package set' {
            { New-PluginCanonicalEvidenceDocument -SourceCommit $script:SourceCommit -Version '9.9.9' `
                    -Locator $script:canonicalLocator `
                    -PackageEvidence @{ Digest = 'a'; FileCount = 0; TotalBytes = 0; Packages = @() } } |
                Should -Throw -ExpectedMessage '*must cover at least one package*'
        }

        It 'Refuses a package that covers no file' {
            { New-PluginCanonicalEvidenceDocument -SourceCommit $script:SourceCommit -Version '9.9.9' `
                    -Locator $script:canonicalLocator `
                    -PackageEvidence @{
                        Digest     = 'a'
                        FileCount  = 0
                        TotalBytes = 0
                        Packages   = @([ordered]@{ name = 'rpi'; digest = 'a'; fileCount = 0 })
                    } } |
                Should -Throw -ExpectedMessage '*resolves to no canonical source file*'
        }
    }
}

Describe 'Invoke-PluginReleaseEvidence canonical mode' -Tag 'Unit' {
    BeforeEach {
        $env:HVE_PLUGIN_STAGING_ROOT = ''
        $script:canonicalRunRepo = New-CanonicalEvidenceRepository -Root (Join-Path $TestDrive ([System.Guid]::NewGuid().ToString()))
        $script:canonicalRun = Invoke-PluginReleaseEvidence -RepoRoot $script:canonicalRunRepo `
            -SourceCommit $script:SourceCommit -ReleaseTag 'hve-core-v9.9.9' `
            -OutputPath 'logs/plugin-release-evidence.json'
    }

    Context 'when recording canonical evidence' {
        It 'Needs no staging root and no generated tree' {
            $script:canonicalRun.Success | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $script:canonicalRunRepo 'plugins') | Should -BeFalse
        }

        It 'Records the canonical schema and pathless locator' {
            $script:canonicalRun.Evidence['schema'] | Should -BeExactly 'hve-core/plugin-release-evidence/v2'
            $script:canonicalRun.Evidence['locator']['ref'] | Should -BeExactly 'hve-core-v9.9.9'
            $script:canonicalRun.Evidence['locator'].Contains('path') | Should -BeFalse
        }

        It 'Writes a parsable evidence document' {
            $recorded = Get-Content -LiteralPath (Join-Path $script:canonicalRunRepo 'logs/plugin-release-evidence.json') -Raw |
                ConvertFrom-Json -AsHashtable
            $recorded['packageCount'] | Should -Be 2
            $recorded['digest'] | Should -BeExactly $script:canonicalRun.Evidence['digest']
        }
    }

    Context 'when verifying recorded canonical evidence' {
        It 'Self-verifies through the expected-evidence mode' {
            $verify = Invoke-PluginReleaseEvidence -RepoRoot $script:canonicalRunRepo `
                -SourceCommit $script:SourceCommit -ReleaseTag 'hve-core-v9.9.9' `
                -OutputPath '' -ExpectedEvidencePath 'logs/plugin-release-evidence.json'
            $verify.Success | Should -BeTrue
            $verify.ErrorCount | Should -Be 0
        }

        It 'Refuses an altered canonical file' {
            Add-PluginFixtureFile -RepoRoot $script:canonicalRunRepo `
                -RelativePath '.github/agents/rpi/rpi-planner.agent.md' `
                -Content "---`ndescription: Plans RPI work`n---`n`n# Tampered`n" | Out-Null
            $verify = Invoke-PluginReleaseEvidence -RepoRoot $script:canonicalRunRepo `
                -SourceCommit $script:SourceCommit -ReleaseTag 'hve-core-v9.9.9' `
                -OutputPath '' -ExpectedEvidencePath 'logs/plugin-release-evidence.json'
            $verify.Success | Should -BeFalse
            ($verify.Errors -join ' ') | Should -Match "package 'rpi' digest disagreement"
            ($verify.Errors -join ' ') | Should -Match 'digest disagreement'
        }

        It 'Refuses a changed package set' {
            $entries = @(
                New-PluginFixtureEntry -Name 'rpi' -Version '9.9.9' -Agents @('agents/rpi/rpi-planner.agent.md')
            )
            Add-PluginFixtureCatalog -RepoRoot $script:canonicalRunRepo -Entries $entries -Version '9.9.9' | Out-Null
            $verify = Invoke-PluginReleaseEvidence -RepoRoot $script:canonicalRunRepo `
                -SourceCommit $script:SourceCommit -ReleaseTag 'hve-core-v9.9.9' `
                -OutputPath '' -ExpectedEvidencePath 'logs/plugin-release-evidence.json'
            $verify.Success | Should -BeFalse
            ($verify.Errors -join ' ') | Should -Match "package 'ado' is recorded in evidence but absent from the snapshot"
        }

        It 'Refuses evidence computed from a different source commit' {
            $verify = Invoke-PluginReleaseEvidence -RepoRoot $script:canonicalRunRepo `
                -SourceCommit 'fedcba9876543210fedcba9876543210fedcba98' -ReleaseTag 'hve-core-v9.9.9' `
                -OutputPath '' -ExpectedEvidencePath 'logs/plugin-release-evidence.json'
            $verify.Success | Should -BeFalse
            ($verify.Errors -join ' ') | Should -Match 'sourceCommit disagreement'
        }

        It 'Reports a recorded v1 locator path against canonical evidence' {
            $recordedPath = Join-Path $script:canonicalRunRepo 'logs/plugin-release-evidence.json'
            $recorded = Get-Content -LiteralPath $recordedPath -Raw | ConvertFrom-Json -AsHashtable
            $recorded['locator']['path'] = 'plugins'
            Set-Content -LiteralPath $recordedPath -Value ($recorded | ConvertTo-Json -Depth 10) -Encoding utf8NoBOM
            $verify = Invoke-PluginReleaseEvidence -RepoRoot $script:canonicalRunRepo `
                -SourceCommit $script:SourceCommit -ReleaseTag 'hve-core-v9.9.9' `
                -OutputPath '' -ExpectedEvidencePath 'logs/plugin-release-evidence.json'
            $verify.Success | Should -BeFalse
            ($verify.Errors -join ' ') | Should -Match "locator.path disagreement: recorded 'plugins'"
        }
    }

    Context 'when a package count precondition is supplied' {
        It 'Accepts the resolved package count' {
            $run = Invoke-PluginReleaseEvidence -RepoRoot $script:canonicalRunRepo `
                -SourceCommit $script:SourceCommit -ReleaseTag 'hve-core-v9.9.9' `
                -OutputPath '' -ExpectedPackageCount 2
            $run.Success | Should -BeTrue
        }

        It 'Refuses a package count the catalog does not meet' {
            $run = Invoke-PluginReleaseEvidence -RepoRoot $script:canonicalRunRepo `
                -SourceCommit $script:SourceCommit -ReleaseTag 'hve-core-v9.9.9' `
                -OutputPath '' -ExpectedPackageCount 3
            $run.Success | Should -BeFalse
            ($run.Errors -join ' ') | Should -Match 'package count precondition failed: expected 3, snapshot has 2'
        }
    }
}

AfterAll {
    $env:HVE_PLUGIN_STAGING_ROOT = $script:OriginalPluginStagingRoot
    Remove-Module PluginTestFixtures -Force -ErrorAction SilentlyContinue
    Remove-Module PluginHelpers -Force -ErrorAction SilentlyContinue
    Remove-Module CIHelpers -Force -ErrorAction SilentlyContinue
}
