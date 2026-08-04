#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../plugins/Assert-PluginReleaseEvidence.ps1')
    Import-Module (Join-Path $PSScriptRoot 'PluginTestFixtures.psm1') -Force
    Mock Write-Host {}

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

Describe 'Invoke-PluginReleaseEvidence' -Tag 'Unit' {
    BeforeEach {
        $script:evidenceRepo = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
        New-PluginFixtureRepository -Path $script:evidenceRepo -Version '9.9.9' -SkipSharedResources | Out-Null
        New-EvidenceTree -Root (Join-Path $script:evidenceRepo 'plugins') | Out-Null
        $script:snapshotRoot = Join-Path $script:evidenceRepo 'plugins'
        $script:recordedPath = Join-Path $script:evidenceRepo 'logs/plugin-release-evidence.json'
    }

    Context 'when recording evidence for a snapshot' {
        BeforeEach {
            $script:recordRun = Invoke-PluginReleaseEvidence -RepoRoot $script:evidenceRepo `
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
            Invoke-PluginReleaseEvidence -RepoRoot $script:evidenceRepo -SourceCommit $script:SourceCommit `
                -OutputPath 'logs/plugin-release-evidence.json' | Out-Null
        }

        It 'Succeeds when the snapshot reproduces' {
            $verifyRun = Invoke-PluginReleaseEvidence -RepoRoot $script:evidenceRepo -SourceCommit $script:SourceCommit `
                -OutputPath '' -ExpectedEvidencePath 'logs/plugin-release-evidence.json'
            $verifyRun.Success | Should -BeTrue
            $verifyRun.ErrorCount | Should -Be 0
        }

        It 'Refuses a snapshot whose content changed' {
            Set-Content -LiteralPath (Join-Path $script:snapshotRoot 'alpha/README.md') -Value "# tampered`n" -Encoding utf8NoBOM -NoNewline
            $verifyRun = Invoke-PluginReleaseEvidence -RepoRoot $script:evidenceRepo -SourceCommit $script:SourceCommit `
                -OutputPath '' -ExpectedEvidencePath 'logs/plugin-release-evidence.json'
            $verifyRun.Success | Should -BeFalse
            ($verifyRun.Errors -join ' ') | Should -Match 'digest disagreement'
            ($verifyRun.Errors -join ' ') | Should -Match "package 'alpha' digest disagreement"
        }

        It 'Refuses a snapshot built from a different source commit' {
            $verifyRun = Invoke-PluginReleaseEvidence -RepoRoot $script:evidenceRepo `
                -SourceCommit 'fedcba9876543210fedcba9876543210fedcba98' `
                -OutputPath '' -ExpectedEvidencePath 'logs/plugin-release-evidence.json'
            $verifyRun.Success | Should -BeFalse
            ($verifyRun.Errors -join ' ') | Should -Match 'sourceCommit disagreement'
        }
    }

    Context 'when the recorded evidence cannot be read' {
        It 'Reports a missing evidence document' {
            $run = Invoke-PluginReleaseEvidence -RepoRoot $script:evidenceRepo -SourceCommit $script:SourceCommit `
                -OutputPath '' -ExpectedEvidencePath 'logs/absent-evidence.json'
            $run.Success | Should -BeFalse
            ($run.Errors -join ' ') | Should -Match 'recorded evidence not found: logs/absent-evidence.json'
        }

        It 'Reports evidence that is not valid JSON' {
            New-Item -ItemType Directory -Path (Join-Path $script:evidenceRepo 'logs') -Force | Out-Null
            Set-Content -LiteralPath $script:recordedPath -Value '{ "digest": ' -Encoding utf8NoBOM -NoNewline
            $run = Invoke-PluginReleaseEvidence -RepoRoot $script:evidenceRepo -SourceCommit $script:SourceCommit `
                -OutputPath '' -ExpectedEvidencePath 'logs/plugin-release-evidence.json'
            $run.Success | Should -BeFalse
            ($run.Errors -join ' ') | Should -Match 'recorded evidence is not valid JSON'
        }

        It 'Reports evidence that is not an evidence document' {
            New-Item -ItemType Directory -Path (Join-Path $script:evidenceRepo 'logs') -Force | Out-Null
            Set-Content -LiteralPath $script:recordedPath -Value '[]' -Encoding utf8NoBOM -NoNewline
            $run = Invoke-PluginReleaseEvidence -RepoRoot $script:evidenceRepo -SourceCommit $script:SourceCommit `
                -OutputPath '' -ExpectedEvidencePath 'logs/plugin-release-evidence.json'
            $run.Success | Should -BeFalse
            ($run.Errors -join ' ') | Should -Match 'recorded evidence is not an evidence document'
        }
    }

    Context 'when a package count precondition is supplied' {
        It 'Accepts the observed package count' {
            $observedCount = @(Get-ChildItem -LiteralPath $script:snapshotRoot -Directory).Count
            $run = Invoke-PluginReleaseEvidence -RepoRoot $script:evidenceRepo -SourceCommit $script:SourceCommit `
                -OutputPath '' -ExpectedPackageCount $observedCount
            $run.Success | Should -BeTrue
        }

        It 'Refuses a package count the snapshot does not meet' {
            $observedCount = @(Get-ChildItem -LiteralPath $script:snapshotRoot -Directory).Count
            $run = Invoke-PluginReleaseEvidence -RepoRoot $script:evidenceRepo -SourceCommit $script:SourceCommit `
                -OutputPath '' -ExpectedPackageCount ($observedCount + 1)
            $run.Success | Should -BeFalse
            ($run.Errors -join ' ') |
                Should -Match "package count precondition failed: expected $($observedCount + 1), snapshot has $observedCount"
        }

        It 'Applies no precondition by default' {
            $run = Invoke-PluginReleaseEvidence -RepoRoot $script:evidenceRepo -SourceCommit $script:SourceCommit -OutputPath ''
            $run.Success | Should -BeTrue
            ($run.Errors -join ' ') | Should -Not -Match 'package count precondition'
        }
    }

    Context 'when exactly one package is required' {
        It 'Accepts a snapshot holding only the surviving package' {
            Remove-Item -LiteralPath (Join-Path $script:snapshotRoot 'bravo') -Recurse -Force
            $run = Invoke-PluginReleaseEvidence -RepoRoot $script:evidenceRepo -SourceCommit $script:SourceCommit `
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
            $run = Invoke-PluginReleaseEvidence -RepoRoot $script:evidenceRepo -SourceCommit $script:SourceCommit `
                -OutputPath '' -ExpectedPackageCount 1
            $run.Success | Should -BeFalse
            ($run.Errors -join ' ') |
                Should -Match "package count precondition failed: expected 1, snapshot has $Count"
        }
    }

    Context 'when the snapshot tree is absent' {
        It 'Refuses to record evidence' {
            { Invoke-PluginReleaseEvidence -RepoRoot $script:evidenceRepo -SourceCommit $script:SourceCommit `
                    -PluginsDir 'absent-plugins' -OutputPath '' } |
                Should -Throw -ExpectedMessage '*Generated package tree not found*'
        }
    }
}

AfterAll {
    Remove-Module PluginTestFixtures -Force -ErrorAction SilentlyContinue
    Remove-Module PluginHelpers -Force -ErrorAction SilentlyContinue
    Remove-Module CIHelpers -Force -ErrorAction SilentlyContinue
}
