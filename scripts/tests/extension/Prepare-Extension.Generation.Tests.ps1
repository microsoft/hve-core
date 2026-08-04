#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    # MarketplaceHelpers reloads its nested ArtifactHelpers dependency, so shared
    # modules load before the script whose own imports settle the session state.
    Import-Module (Join-Path $PSScriptRoot '../../lib/Modules/MarketplaceHelpers.psm1') -Force
    . (Join-Path $PSScriptRoot '../../extension/Prepare-Extension.ps1')
    Import-Module (Join-Path $PSScriptRoot 'ExtensionTestFixtures.psm1') -Force

    $script:RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    # Both channels distribute the same active packages, so one expected set
    # covers Stable, PreRelease, and every transition between them.
    $script:ChannelFiles = @(
        'README.hve-core-all.md'
        'README.labs.md'
        'README.md'
        'README.sample.md'
        'package.hve-core-all.json'
        'package.json'
        'package.labs.json'
        'package.sample.json'
    )

    function Get-GeneratedFileName {
        <#
        .SYNOPSIS
        Returns sorted generated manifest and README names in an extension directory.
        .PARAMETER ExtensionDirectory
        Extension directory to inspect.
        .OUTPUTS
        [string[]] Sorted file names.
        #>
        [CmdletBinding()]
        [OutputType([string[]])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$ExtensionDirectory
        )

        $names = [string[]]@(
            Get-ChildItem -LiteralPath $ExtensionDirectory -File |
                Where-Object { $_.Name -like 'package*.json' -or $_.Name -like 'README*.md' } |
                Select-Object -ExpandProperty Name
        )
        [array]::Sort($names, [System.StringComparer]::Ordinal)
        return $names
    }

    function Get-DirectorySnapshot {
        <#
        .SYNOPSIS
        Captures file hashes and write timestamps for a directory.
        .PARAMETER Path
        Directory to snapshot.
        .OUTPUTS
        [hashtable] File name to hash and timestamp record.
        #>
        [CmdletBinding()]
        [OutputType([hashtable])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Path
        )

        $snapshot = @{}
        foreach ($file in Get-ChildItem -LiteralPath $Path -File -Recurse) {
            $snapshot[$file.FullName] = @{
                Hash      = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
                WriteTime = $file.LastWriteTimeUtc.Ticks
            }
        }
        return $snapshot
    }

    Mock Write-Host {}
}

Describe 'Prepare-Extension channel generation' -Tag 'Unit' {
    BeforeEach {
        $script:Fixture = New-ExtensionFixtureRepo -Path (Join-Path $TestDrive "generation-$([guid]::NewGuid().ToString('N'))")
    }

    Context 'when generating the Stable channel' {
        BeforeEach {
            $script:Result = Invoke-PrepareExtension -ExtensionDirectory $script:Fixture.ExtensionDirectory `
                -RepoRoot $script:Fixture.RepoRoot -Channel Stable -PackageId 'hve-core'
        }

        It 'Generates a manifest and README for every Stable-eligible package' {
            $script:Result.Success | Should -BeTrue
            Get-GeneratedFileName -ExtensionDirectory $script:Fixture.ExtensionDirectory | Should -Be $script:ChannelFiles
        }

        It 'Excludes removed packages from the Stable channel' {
            Test-Path -LiteralPath (Join-Path $script:Fixture.ExtensionDirectory 'package.retired.json') | Should -BeFalse
        }

        It 'Reports the Stable contribution counts for the selected package' {
            $script:Result.Version | Should -BeExactly '9.9.9'
            $script:Result.AgentCount | Should -Be 1
            $script:Result.PromptCount | Should -Be 1
            $script:Result.InstructionCount | Should -Be 1
            $script:Result.SkillCount | Should -Be 1
        }

        It 'Writes the selected package contributions into the active manifest' {
            $manifest = Get-Content -LiteralPath (Join-Path $script:Fixture.ExtensionDirectory 'package.json') -Raw -Encoding utf8 | ConvertFrom-Json
            $manifest.name | Should -BeExactly 'hve-core'
            @($manifest.contributes.chatAgents.path) | Should -Be @('./.github/agents/core/alpha.agent.md')
            @($manifest.contributes.chatPromptFiles.path) | Should -Be @('./.github/prompts/core/build.prompt.md')
        }

        It 'Removes stale generated files while preserving the base manifest and README' {
            Test-Path -LiteralPath (Join-Path $script:Fixture.ExtensionDirectory 'package.obsolete.json') | Should -BeFalse
            Test-Path -LiteralPath (Join-Path $script:Fixture.ExtensionDirectory 'README.obsolete.md') | Should -BeFalse
            Test-Path -LiteralPath (Join-Path $script:Fixture.ExtensionDirectory 'package.json') | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $script:Fixture.ExtensionDirectory 'README.md') | Should -BeTrue
        }
    }

    Context 'when generating the PreRelease channel' {
        BeforeEach {
            $script:Result = Invoke-PrepareExtension -ExtensionDirectory $script:Fixture.ExtensionDirectory `
                -RepoRoot $script:Fixture.RepoRoot -Channel PreRelease -PackageId 'hve-core'
        }

        It 'Adds experimental packages to the generated set' {
            $script:Result.Success | Should -BeTrue
            Get-GeneratedFileName -ExtensionDirectory $script:Fixture.ExtensionDirectory | Should -Be $script:ChannelFiles
        }

        It 'Includes preview components in the selected package contributions' {
            $script:Result.PromptCount | Should -Be 1
            $manifest = Get-Content -LiteralPath (Join-Path $script:Fixture.ExtensionDirectory 'package.json') -Raw -Encoding utf8 | ConvertFrom-Json
            @($manifest.contributes.chatPromptFiles.path) | Should -Be @('./.github/prompts/core/build.prompt.md')
        }

        It 'Applies the extension identity to each generated manifest' {
            $identities = @{}
            foreach ($name in @('package.json', 'package.hve-core-all.json', 'package.sample.json', 'package.labs.json')) {
                $identities[$name] = [string]((Get-Content -LiteralPath (Join-Path $script:Fixture.ExtensionDirectory $name) -Raw -Encoding utf8 | ConvertFrom-Json).name)
            }
            $identities['package.json'] | Should -BeExactly 'hve-core'
            $identities['package.hve-core-all.json'] | Should -BeExactly 'hve-hve-core-all'
            $identities['package.sample.json'] | Should -BeExactly 'hve-sample'
            $identities['package.labs.json'] | Should -BeExactly 'hve-labs'
        }
    }

    Context 'when transitioning between channels' {
        It 'Keeps the generated set identical from PreRelease to Stable' {
            Invoke-PrepareExtension -ExtensionDirectory $script:Fixture.ExtensionDirectory `
                -RepoRoot $script:Fixture.RepoRoot -Channel PreRelease -PackageId 'hve-core' | Out-Null
            Get-GeneratedFileName -ExtensionDirectory $script:Fixture.ExtensionDirectory | Should -Be $script:ChannelFiles

            Invoke-PrepareExtension -ExtensionDirectory $script:Fixture.ExtensionDirectory `
                -RepoRoot $script:Fixture.RepoRoot -Channel Stable -PackageId 'hve-core' | Out-Null
            Get-GeneratedFileName -ExtensionDirectory $script:Fixture.ExtensionDirectory | Should -Be $script:ChannelFiles
        }

        It 'Produces byte-identical content on both channels' {
            Invoke-PrepareExtension -ExtensionDirectory $script:Fixture.ExtensionDirectory `
                -RepoRoot $script:Fixture.RepoRoot -Channel Stable -PackageId 'hve-core' | Out-Null
            $stable = Get-DirectorySnapshot -Path $script:Fixture.ExtensionDirectory

            Invoke-PrepareExtension -ExtensionDirectory $script:Fixture.ExtensionDirectory `
                -RepoRoot $script:Fixture.RepoRoot -Channel PreRelease -PackageId 'hve-core' | Out-Null
            $preRelease = Get-DirectorySnapshot -Path $script:Fixture.ExtensionDirectory

            @($preRelease.Keys | Sort-Object) | Should -Be @($stable.Keys | Sort-Object)
            foreach ($key in $stable.Keys) {
                $preRelease[$key].Hash | Should -BeExactly $stable[$key].Hash -Because "$key must not differ by channel"
            }
        }
    }

    Context 'when a retired identity remains in the extension directory' {
        It 'Removes the stale suffixed and unsuffixed generated output' {
            Set-FixtureFile -Path (Join-Path $script:Fixture.ExtensionDirectory 'package.security.json') -Value "{}`n"
            Set-FixtureFile -Path (Join-Path $script:Fixture.ExtensionDirectory 'README.security.md') -Value "# Security`n"
            Remove-StaleGeneratedFiles -RepoRoot $script:Fixture.RepoRoot -ExpectedFiles @()

            foreach ($name in @('package.security.json', 'README.security.md', 'package.json', 'README.md')) {
                Test-Path -LiteralPath (Join-Path $script:Fixture.ExtensionDirectory $name) | Should -BeFalse -Because "$name is generated output"
            }
        }
    }

    Context 'when running the same channel twice' {
        It 'Produces byte-identical generated output' {
            Invoke-PrepareExtension -ExtensionDirectory $script:Fixture.ExtensionDirectory `
                -RepoRoot $script:Fixture.RepoRoot -Channel PreRelease -PackageId 'sample' | Out-Null
            $first = Get-DirectorySnapshot -Path $script:Fixture.ExtensionDirectory

            Invoke-PrepareExtension -ExtensionDirectory $script:Fixture.ExtensionDirectory `
                -RepoRoot $script:Fixture.RepoRoot -Channel PreRelease -PackageId 'sample' | Out-Null
            $second = Get-DirectorySnapshot -Path $script:Fixture.ExtensionDirectory

            @($second.Keys | Sort-Object) | Should -Be @($first.Keys | Sort-Object)
            foreach ($key in $first.Keys) {
                $second[$key].Hash | Should -BeExactly $first[$key].Hash -Because "$key must be byte-identical across runs"
            }
        }
    }
}

Describe 'Prepare-Extension README generation' -Tag 'Unit' {
    BeforeAll {
        $script:ReadmeFixture = New-ExtensionFixtureRepo -Path (Join-Path $TestDrive 'readme-repo')
        Invoke-PrepareExtension -ExtensionDirectory $script:ReadmeFixture.ExtensionDirectory `
            -RepoRoot $script:ReadmeFixture.RepoRoot -Channel PreRelease -PackageId 'hve-core' | Out-Null
        $script:SampleReadme = Get-Content -LiteralPath (Join-Path $script:ReadmeFixture.ExtensionDirectory 'README.sample.md') -Raw -Encoding utf8
    }

    It 'Renders the durable document intro and the disclosed artifact table' {
        $expected = @(
            '# Fixture Sample'
            ''
            '> Sample fixture package'
            ''
            'Fixture Sample intro paragraph.'
            ''
            '## Included Artifacts'
            ''
            '### Chat Agents'
            ''
            '| Name | Maturity | Description |'
            '|------|----------|-------------|'
            '| **alpha** | stable | Alpha fixture agent |'
            '| **beta** | stable | Beta fixture agent |'
            ''
        ) -join "`n"
        $script:SampleReadme | Should -BeExactly $expected
    }

    It 'Excludes the durable document artifact table from the generated README' {
        $script:SampleReadme | Should -Not -Match 'Durable table that must never reach the extension README'
    }

    It 'Omits the retired full-edition upsell from every generated README' {
        foreach ($name in @('README.md', 'README.hve-core-all.md', 'README.sample.md', 'README.labs.md')) {
            $readme = Get-Content -LiteralPath (Join-Path $script:ReadmeFixture.ExtensionDirectory $name) -Raw -Encoding utf8
            $readme | Should -Not -Match '## Full Edition'
            $readme | Should -Not -Match 'FULL_EDITION'
        }
    }

    It 'Discloses the canonical maturity of each component' {
        $coreReadme = Get-Content -LiteralPath (Join-Path $script:ReadmeFixture.ExtensionDirectory 'README.md') -Raw -Encoding utf8
        $coreReadme | Should -Match '(?m)^\| \*\*build\*\* \| preview \|'
        $coreReadme | Should -Match '(?m)^\| \*\*alpha\*\* \| stable \|'
        $allReadme = Get-Content -LiteralPath (Join-Path $script:ReadmeFixture.ExtensionDirectory 'README.hve-core-all.md') -Raw -Encoding utf8
        $allReadme | Should -Match '(?m)^\| \*\*probe\*\* \| experimental \|'
    }

    It 'Adds the experimental notice only for experimental packages' {
        $labsReadme = Get-Content -LiteralPath (Join-Path $script:ReadmeFixture.ExtensionDirectory 'README.labs.md') -Raw -Encoding utf8
        $labsReadme | Should -Match '> \*\*Experimental\*\*: This package is experimental\. Contents and behavior may change or be removed without notice\.'
        $script:SampleReadme | Should -Not -Match '\*\*Experimental\*\*'
    }

    It 'Groups artifact tables in agent, prompt, instruction, and skill order' {
        $coreReadme = Get-Content -LiteralPath (Join-Path $script:ReadmeFixture.ExtensionDirectory 'README.md') -Raw -Encoding utf8
        $headings = @([regex]::Matches($coreReadme, '(?m)^### (.+)$') | ForEach-Object { $_.Groups[1].Value })
        $headings | Should -Be @('Chat Agents', 'Prompts', 'Instructions', 'Skills')
    }
}

Describe 'Prepare-Extension durable inputs' -Tag 'Unit' {
    BeforeAll {
        $script:DurableFixture = New-ExtensionFixtureRepo -Path (Join-Path $TestDrive 'durable-repo')
        $script:DocsBefore = Get-DirectorySnapshot -Path $script:DurableFixture.DocsDirectory
        $script:CatalogHashBefore = (Get-FileHash -LiteralPath $script:DurableFixture.CatalogPath -Algorithm SHA256).Hash
        Invoke-PrepareExtension -ExtensionDirectory $script:DurableFixture.ExtensionDirectory `
            -RepoRoot $script:DurableFixture.RepoRoot -Channel PreRelease -PackageId 'hve-core' | Out-Null
        $script:DocsAfter = Get-DirectorySnapshot -Path $script:DurableFixture.DocsDirectory
    }

    It 'Reads a non-empty set of durable package documents' {
        @($script:DocsBefore.Keys) | Should -HaveCount 4
    }

    It 'Leaves durable package document content unchanged' {
        foreach ($key in $script:DocsBefore.Keys) {
            $script:DocsAfter[$key].Hash | Should -BeExactly $script:DocsBefore[$key].Hash -Because "$key is a durable input"
        }
    }

    It 'Leaves durable package document timestamps unchanged' {
        foreach ($key in $script:DocsBefore.Keys) {
            $script:DocsAfter[$key].WriteTime | Should -Be $script:DocsBefore[$key].WriteTime -Because "$key must not be rewritten"
        }
    }

    It 'Leaves the marketplace catalog unchanged' {
        (Get-FileHash -LiteralPath $script:DurableFixture.CatalogPath -Algorithm SHA256).Hash | Should -BeExactly $script:CatalogHashBefore
    }
}

Describe 'Prepare-Extension canonical inputs' -Tag 'Unit' {
    It 'Has no collection manifest directory in the repository' {
        Test-Path -LiteralPath (Join-Path $script:RepositoryRoot 'collections') | Should -BeFalse
    }

    It 'Has no collection manifest reader under the extension scripts' {
        @(Get-ChildItem -LiteralPath (Join-Path $script:RepositoryRoot 'scripts/extension') -Recurse -File -Include '*.ps1', '*.psm1' |
                Where-Object { $_.Name -match 'Collection' }) | Should -HaveCount 0
    }

    It 'Never references collection manifests from extension script code' {
        $collectionManifestPattern = '\.collection\.(yml|md)|collections/|CollectionManifest|CollectionHelpers'
        $offenders = @(
            Get-ChildItem -LiteralPath (Join-Path $script:RepositoryRoot 'scripts/extension') -Recurse -File -Include '*.ps1', '*.psm1' |
                Where-Object { (Get-Content -LiteralPath $_.FullName -Raw) -match $collectionManifestPattern }
        )
        @($offenders).Count | Should -Be 0 -Because "no extension script may read collection manifests: $($offenders.Name -join ', ')"
    }

    It 'Resolves the marketplace catalog as the only package definition input' {
        $prepareSource = Get-Content -LiteralPath (Join-Path $script:RepositoryRoot 'scripts/extension/Prepare-Extension.ps1') -Raw
        $prepareSource | Should -Match '\.github/plugin/marketplace\.json'
    }
}

Describe 'Prepare-Extension dry run and changelog' -Tag 'Unit' {
    BeforeEach {
        $script:DryRunFixture = New-ExtensionFixtureRepo -Path (Join-Path $TestDrive "dryrun-$([guid]::NewGuid().ToString('N'))")
        $script:ChangelogPath = Join-Path $script:DryRunFixture.RepoRoot 'CHANGELOG.md'
        Set-FixtureFile -Path $script:ChangelogPath -Value "# Fixture changelog`n"
    }

    Context 'when running with DryRun' {
        BeforeEach {
            $script:DryRunResult = Invoke-PrepareExtension -ExtensionDirectory $script:DryRunFixture.ExtensionDirectory `
                -RepoRoot $script:DryRunFixture.RepoRoot -Channel PreRelease -PackageId 'sample' `
                -ChangelogPath $script:ChangelogPath -DryRun
        }

        It 'Still generates every eligible package manifest and README' {
            $script:DryRunResult.Success | Should -BeTrue
            Get-GeneratedFileName -ExtensionDirectory $script:DryRunFixture.ExtensionDirectory | Should -Be $script:ChannelFiles
        }

        It 'Reports the selected package contribution counts without writing them' {
            $script:DryRunResult.AgentCount | Should -Be 2
            $manifest = Get-Content -LiteralPath (Join-Path $script:DryRunFixture.ExtensionDirectory 'package.json') -Raw -Encoding utf8 | ConvertFrom-Json
            $manifest.name | Should -BeExactly 'hve-core'
            @($manifest.contributes.PSObject.Properties) | Should -HaveCount 0
        }

        It 'Copies no changelog into the extension directory' {
            Test-Path -LiteralPath (Join-Path $script:DryRunFixture.ExtensionDirectory 'CHANGELOG.md') | Should -BeFalse
        }
    }

    Context 'when running without DryRun' {
        It 'Copies the changelog into the extension directory' {
            Invoke-PrepareExtension -ExtensionDirectory $script:DryRunFixture.ExtensionDirectory `
                -RepoRoot $script:DryRunFixture.RepoRoot -Channel PreRelease -PackageId 'sample' `
                -ChangelogPath $script:ChangelogPath | Out-Null
            Get-Content -LiteralPath (Join-Path $script:DryRunFixture.ExtensionDirectory 'CHANGELOG.md') -Raw |
                Should -BeExactly "# Fixture changelog`n"
        }

        It 'Writes the selected package identity and contributions into the active manifest' {
            Invoke-PrepareExtension -ExtensionDirectory $script:DryRunFixture.ExtensionDirectory `
                -RepoRoot $script:DryRunFixture.RepoRoot -Channel PreRelease -PackageId 'sample' | Out-Null
            $manifest = Get-Content -LiteralPath (Join-Path $script:DryRunFixture.ExtensionDirectory 'package.json') -Raw -Encoding utf8 | ConvertFrom-Json
            $manifest.name | Should -BeExactly 'hve-sample'
            @($manifest.contributes.chatAgents.name) | Should -Be @('alpha', 'beta')
        }

        It 'Warns when the requested changelog is missing' {
            Mock Write-Warning {}
            $missing = Join-Path $script:DryRunFixture.RepoRoot 'ABSENT-CHANGELOG.md'
            Invoke-PrepareExtension -ExtensionDirectory $script:DryRunFixture.ExtensionDirectory `
                -RepoRoot $script:DryRunFixture.RepoRoot -Channel PreRelease -PackageId 'sample' `
                -ChangelogPath $missing | Out-Null
            Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter {
                $Message -eq "Changelog path specified but file not found: $missing"
            }
        }
    }
}

AfterAll {
    Remove-Module ExtensionTestFixtures -Force -ErrorAction SilentlyContinue
}
