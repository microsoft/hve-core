#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../plugins/Assert-PluginReleaseEvidence.ps1')
    Import-Module (Join-Path $PSScriptRoot 'PluginTestFixtures.psm1') -Force
    Mock Write-Host {}

    $script:SourceCommit = '0123456789abcdef0123456789abcdef01234567'

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

Describe 'Compare-PluginReleaseEvidence' -Tag 'Unit' {
    BeforeEach {
        $script:compareRepo = New-CanonicalEvidenceRepository -Root (Join-Path $TestDrive ([System.Guid]::NewGuid().ToString()))
        $script:actualEvidence = New-PluginCanonicalEvidenceDocument -SourceCommit $script:SourceCommit -Version '9.9.9' `
            -Locator (New-PluginReleaseLocator -Version '9.9.9' -Channel PreRelease) `
            -PackageEvidence (Get-PluginCanonicalPackageEvidence -RepoRoot $script:compareRepo `
                -CatalogPath '.github/plugin/marketplace.json' -Channel PreRelease)
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
            $script:recordedEvidence['locator']['ref'] = 'v1.0.0'
            $differences = @(Compare-PluginReleaseEvidence -Expected $script:recordedEvidence -Actual $script:actualEvidence)
            ($differences -join ' ') | Should -Match "locator.ref disagreement: recorded 'v1\.0\.0'"
        }

        It 'Reports a missing locator' {
            $script:recordedEvidence.Remove('locator')
            $differences = @(Compare-PluginReleaseEvidence -Expected $script:recordedEvidence -Actual $script:actualEvidence)
            ($differences -join ' ') | Should -Match "recorded evidence is missing required field 'locator'"
        }
    }

    Context 'when the package set disagrees' {
        It 'Reports a package present only in the snapshot' {
            $script:recordedEvidence['packages'] = @($script:recordedEvidence['packages'] | Where-Object { $_['name'] -ne 'rpi' })
            $differences = @(Compare-PluginReleaseEvidence -Expected $script:recordedEvidence -Actual $script:actualEvidence)
            ($differences -join ' ') | Should -Match "package 'rpi' is present in the snapshot but absent from recorded evidence"
        }

        It 'Reports a package present only in recorded evidence' {
            $script:recordedEvidence['packages'] += @{ name = 'charlie'; digest = 'deadbeef'; fileCount = 1 }
            $differences = @(Compare-PluginReleaseEvidence -Expected $script:recordedEvidence -Actual $script:actualEvidence)
            ($differences -join ' ') | Should -Match "package 'charlie' is recorded in evidence but absent from the snapshot"
        }

        It 'Reports a per-package digest disagreement' {
            $script:recordedEvidence['packages'][0]['digest'] = 'deadbeef'
            $differences = @(Compare-PluginReleaseEvidence -Expected $script:recordedEvidence -Actual $script:actualEvidence)
            ($differences -join ' ') | Should -Match "package 'ado' digest disagreement: recorded 'deadbeef'"
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
            -Channel PreRelease
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

        It 'Binds a pathless channel release locator' {
            @($script:canonicalDocument['locator'].Keys) | Should -Be @('source', 'repo', 'ref')
            $script:canonicalDocument['locator']['ref'] | Should -BeExactly 'prerelease-v9.9.9'
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
        $script:canonicalRunRepo = New-CanonicalEvidenceRepository -Root (Join-Path $TestDrive ([System.Guid]::NewGuid().ToString()))
        $script:canonicalRun = Invoke-PluginReleaseEvidence -RepoRoot $script:canonicalRunRepo `
            -SourceCommit $script:SourceCommit -Channel PreRelease -ReleaseTag 'prerelease-v9.9.9' `
            -OutputPath 'logs/plugin-release-evidence.json'
    }

    Context 'when recording canonical evidence' {
        It 'Needs no staging root and no generated tree' {
            $script:canonicalRun.Success | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $script:canonicalRunRepo 'plugins') | Should -BeFalse
        }

        It 'Records the canonical schema and pathless locator' {
            $script:canonicalRun.Evidence['schema'] | Should -BeExactly 'hve-core/plugin-release-evidence/v2'
            $script:canonicalRun.Evidence['locator']['ref'] | Should -BeExactly 'prerelease-v9.9.9'
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
                -SourceCommit $script:SourceCommit -Channel PreRelease -ReleaseTag 'prerelease-v9.9.9' `
                -OutputPath '' -ExpectedEvidencePath 'logs/plugin-release-evidence.json'
            $verify.Success | Should -BeTrue
            $verify.ErrorCount | Should -Be 0
        }

        It 'Refuses an altered canonical file' {
            Add-PluginFixtureFile -RepoRoot $script:canonicalRunRepo `
                -RelativePath '.github/agents/rpi/rpi-planner.agent.md' `
                -Content "---`ndescription: Plans RPI work`n---`n`n# Tampered`n" | Out-Null
            $verify = Invoke-PluginReleaseEvidence -RepoRoot $script:canonicalRunRepo `
                -SourceCommit $script:SourceCommit -Channel PreRelease -ReleaseTag 'prerelease-v9.9.9' `
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
                -SourceCommit $script:SourceCommit -Channel PreRelease -ReleaseTag 'prerelease-v9.9.9' `
                -OutputPath '' -ExpectedEvidencePath 'logs/plugin-release-evidence.json'
            $verify.Success | Should -BeFalse
            ($verify.Errors -join ' ') | Should -Match "package 'ado' is recorded in evidence but absent from the snapshot"
        }

        It 'Refuses evidence computed from a different source commit' {
            $verify = Invoke-PluginReleaseEvidence -RepoRoot $script:canonicalRunRepo `
                -SourceCommit 'fedcba9876543210fedcba9876543210fedcba98' `
                -Channel PreRelease -ReleaseTag 'prerelease-v9.9.9' `
                -OutputPath '' -ExpectedEvidencePath 'logs/plugin-release-evidence.json'
            $verify.Success | Should -BeFalse
            ($verify.Errors -join ' ') | Should -Match 'sourceCommit disagreement'
        }

        It 'Reports a recorded locator field the canonical document does not carry' {
            $recordedPath = Join-Path $script:canonicalRunRepo 'logs/plugin-release-evidence.json'
            $recorded = Get-Content -LiteralPath $recordedPath -Raw | ConvertFrom-Json -AsHashtable
            $recorded['locator']['path'] = 'plugins'
            Set-Content -LiteralPath $recordedPath -Value ($recorded | ConvertTo-Json -Depth 10) -Encoding utf8NoBOM
            $verify = Invoke-PluginReleaseEvidence -RepoRoot $script:canonicalRunRepo `
                -SourceCommit $script:SourceCommit -Channel PreRelease -ReleaseTag 'prerelease-v9.9.9' `
                -OutputPath '' -ExpectedEvidencePath 'logs/plugin-release-evidence.json'
            $verify.Success | Should -BeFalse
            ($verify.Errors -join ' ') | Should -Match "locator.path disagreement: recorded 'plugins'"
        }
    }

    Context 'when recording canonical evidence for the Stable channel' {
        BeforeEach {
            $script:stableRun = Invoke-PluginReleaseEvidence -RepoRoot $script:canonicalRunRepo `
                -SourceCommit $script:SourceCommit -Channel Stable -ReleaseTag 'v9.9.9' `
                -OutputPath 'logs/plugin-release-evidence-stable.json'
        }

        It 'Binds the exact Stable release tag' {
            $script:stableRun.Success | Should -BeTrue
            $script:stableRun.Evidence['locator']['ref'] | Should -BeExactly 'v9.9.9'
            $script:stableRun.Evidence['schema'] | Should -BeExactly 'hve-core/plugin-release-evidence/v2'
        }

        It 'Covers the same package set both channels distribute' {
            @($script:stableRun.Evidence['packages'] | ForEach-Object { $_['name'] }) | Should -Be @('ado', 'rpi')
            $script:stableRun.Evidence['digest'] | Should -BeExactly $script:canonicalRun.Evidence['digest']
        }

        It 'Self-verifies through the expected-evidence mode' {
            $verify = Invoke-PluginReleaseEvidence -RepoRoot $script:canonicalRunRepo `
                -SourceCommit $script:SourceCommit -Channel Stable -ReleaseTag 'v9.9.9' `
                -OutputPath '' -ExpectedEvidencePath 'logs/plugin-release-evidence-stable.json'
            $verify.Success | Should -BeTrue
            $verify.ErrorCount | Should -Be 0
        }

        It 'Refuses PreRelease evidence recorded for the same version' {
            $verify = Invoke-PluginReleaseEvidence -RepoRoot $script:canonicalRunRepo `
                -SourceCommit $script:SourceCommit -Channel Stable -ReleaseTag 'v9.9.9' `
                -OutputPath '' -ExpectedEvidencePath 'logs/plugin-release-evidence.json'
            $verify.Success | Should -BeFalse
            ($verify.Errors -join ' ') | Should -Match 'locator.ref disagreement'
        }
    }

    Context 'when a package count precondition is supplied' {
        It 'Accepts the resolved package count' {
            $run = Invoke-PluginReleaseEvidence -RepoRoot $script:canonicalRunRepo `
                -SourceCommit $script:SourceCommit -Channel PreRelease -ReleaseTag 'prerelease-v9.9.9' `
                -OutputPath '' -ExpectedPackageCount 2
            $run.Success | Should -BeTrue
        }

        It 'Refuses a package count the catalog does not meet' {
            $run = Invoke-PluginReleaseEvidence -RepoRoot $script:canonicalRunRepo `
                -SourceCommit $script:SourceCommit -Channel PreRelease -ReleaseTag 'prerelease-v9.9.9' `
                -OutputPath '' -ExpectedPackageCount 3
            $run.Success | Should -BeFalse
            ($run.Errors -join ' ') | Should -Match 'package count precondition failed: expected 3, snapshot has 2'
        }
    }
}

AfterAll {
    Remove-Module PluginTestFixtures -Force -ErrorAction SilentlyContinue
    Remove-Module PluginHelpers -Force -ErrorAction SilentlyContinue
    Remove-Module CIHelpers -Force -ErrorAction SilentlyContinue
}
