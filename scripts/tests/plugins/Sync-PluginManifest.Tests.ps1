#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../plugins/Sync-PluginManifest.ps1')
    Mock Write-Host {}

    $script:RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path

    function New-SkillFile {
        param(
            [string]$Path,
            [string]$Name,
            [string]$License
        )

        New-Item -ItemType Directory -Path (Split-Path $Path -Parent) -Force | Out-Null
        $frontmatter = @('---', "name: $Name", "description: $Name skill.")
        if ($License) {
            $frontmatter += "license: $License"
        }
        $frontmatter += @('metadata:', '  license: MIT', '---', '', "# $Name")
        Set-Content -LiteralPath $Path -Value ($frontmatter -join "`n") -Encoding UTF8
    }

    function New-PluginFixture {
        <#
        .SYNOPSIS
            Builds a git-tracked fixture repository with one plugin root.
        #>
        param(
            [string]$Root,
            [string]$Version = '1.2.3'
        )

        $github = Join-Path $Root '.github'
        foreach ($relative in @(
                'agents/alpha/one.agent.md',
                'agents/alpha/subagents/two.agent.md',
                'agents/root-only.agent.md',
                'prompts/alpha/one.prompt.md',
                'prompts/root-only.prompt.md',
                'instructions/beta/one.instructions.md',
                'instructions/root-only.instructions.md',
                'README.md',
                'agents/alpha/notes.md'
            )) {
            $path = Join-Path $github $relative
            New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force | Out-Null
            Set-Content -LiteralPath $path -Value "content for $relative" -Encoding UTF8
        }

        New-SkillFile -Path (Join-Path $github 'skills/alpha/open-skill/SKILL.md') -Name 'open-skill' -License 'MIT'
        New-SkillFile -Path (Join-Path $github 'skills/alpha/unlicensed-skill/SKILL.md') -Name 'unlicensed-skill'
        New-SkillFile -Path (Join-Path $github 'skills/beta/noncommercial-skill/SKILL.md') -Name 'noncommercial-skill' -License 'CC-BY-NC-SA-4.0'
        New-SkillFile -Path (Join-Path $github 'skills/root-only/SKILL.md') -Name 'root-only' -License 'MIT'

        Set-Content -LiteralPath (Join-Path $Root 'package.json') `
            -Value ("{`n  `"name`": `"fixture`",`n  `"version`": `"$Version`"`n}`n") -Encoding UTF8
        Set-Content -LiteralPath (Join-Path $Root 'README.md') -Value "# Fixture`n" -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath (Join-Path $Root 'LICENSE') -Value "MIT`n" -Encoding UTF8 -NoNewline

        $manifest = [ordered]@{
            name        = 'hve-core'
            description = 'Fixture plugin'
            version     = $Version
            author      = [ordered]@{ name = 'Microsoft'; url = 'https://www.microsoft.com' }
            homepage    = 'https://github.com/microsoft/hve-core'
            repository  = 'https://github.com/microsoft/hve-core'
            license     = 'MIT'
            keywords    = @('hve', 'agents')
            agents      = @()
            commands    = @()
            rules       = @()
            skills      = @()
        }
        Set-Content -LiteralPath (Join-Path $Root 'plugin.json') `
            -Value (ConvertTo-PluginManifestJson -Manifest $manifest) -Encoding UTF8 -NoNewline

        $catalogPath = Join-Path $github 'plugin/marketplace.json'
        New-Item -ItemType Directory -Path (Split-Path $catalogPath -Parent) -Force | Out-Null
        $catalog = [ordered]@{
            name     = 'hve-core'
            metadata = [ordered]@{ description = 'HVE Core'; version = $Version }
            owner    = [ordered]@{ name = 'Microsoft' }
            plugins  = @(
                [ordered]@{
                    name        = 'hve-core'
                    source      = '.'
                    description = 'Fixture plugin'
                    version     = $Version
                    author      = [ordered]@{ name = 'Microsoft'; url = 'https://www.microsoft.com' }
                    homepage    = 'https://github.com/microsoft/hve-core'
                    repository  = 'https://github.com/microsoft/hve-core'
                    license     = 'MIT'
                    keywords    = @('hve', 'agents')
                }
            )
        }
        Set-Content -LiteralPath $catalogPath -Value (($catalog | ConvertTo-Json -Depth 10) + "`n") -Encoding UTF8 -NoNewline

        & git -C $Root init --quiet --initial-branch main
        & git -C $Root add --all
        return $Root
    }

    function Set-FixtureManifest {
        <#
        .SYNOPSIS
            Rewrites the fixture manifest from a transform of its current content.
        #>
        param(
            [string]$Root,
            [scriptblock]$Transform
        )

        $path = Join-Path $Root 'plugin.json'
        $manifest = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable
        $manifest = & $Transform $manifest
        Set-Content -LiteralPath $path -Value (ConvertTo-PluginManifestJson -Manifest $manifest) -Encoding UTF8 -NoNewline
    }

    function Set-FixtureCatalog {
        <#
        .SYNOPSIS
            Rewrites the fixture catalog from a transform of its current content.
        #>
        param(
            [string]$Root,
            [scriptblock]$Transform
        )

        $path = Join-Path $Root '.github/plugin/marketplace.json'
        $catalog = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable
        $catalog = & $Transform $catalog
        Set-Content -LiteralPath $path -Value (($catalog | ConvertTo-Json -Depth 10) + "`n") -Encoding UTF8 -NoNewline
    }
}

Describe 'Get-SkillLicense' -Tag 'Unit' {
    BeforeAll {
        $script:SkillRoot = Join-Path $TestDrive 'licenses'
    }

    It 'Reads the top-level license and ignores nested metadata' {
        $path = Join-Path $script:SkillRoot 'top/SKILL.md'
        New-SkillFile -Path $path -Name 'top' -License 'CC-BY-NC-SA-4.0'
        Get-SkillLicense -Path $path | Should -BeExactly 'CC-BY-NC-SA-4.0'
    }

    It 'Returns an empty string when no top-level license is declared' {
        $path = Join-Path $script:SkillRoot 'none/SKILL.md'
        New-SkillFile -Path $path -Name 'none'
        Get-SkillLicense -Path $path | Should -BeExactly ''
    }

    It 'Returns an empty string when the file has no frontmatter' {
        $path = Join-Path $script:SkillRoot 'bare/SKILL.md'
        New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force | Out-Null
        Set-Content -LiteralPath $path -Value "# bare`nlicense: CC-BY-NC-SA-4.0" -Encoding UTF8
        Get-SkillLicense -Path $path | Should -BeExactly ''
    }
}

Describe 'Test-NoncommercialLicense' -Tag 'Unit' {
    It 'Classifies <License> as noncommercial=<Expected>' -ForEach @(
        @{ License = 'CC-BY-NC-SA-4.0'; Expected = $true }
        @{ License = 'CC BY-NC 4.0'; Expected = $true }
        @{ License = 'NonCommercial'; Expected = $true }
        @{ License = 'CC-BY-4.0'; Expected = $false }
        @{ License = 'CC-BY-SA-4.0'; Expected = $false }
        @{ License = 'Apache-2.0 AND CC-BY-4.0'; Expected = $false }
        @{ License = 'MIT'; Expected = $false }
        @{ License = 'mixed'; Expected = $false }
        @{ License = ''; Expected = $false }
    ) {
        Test-NoncommercialLicense -License $License | Should -Be $Expected
    }
}

Describe 'Get-TrackedPluginFile' -Tag 'Unit' {
    BeforeAll {
        $script:TrackedRoot = New-PluginFixture -Root (Join-Path $TestDrive 'tracked')
        $untracked = Join-Path $script:TrackedRoot '.github/agents/alpha/untracked.agent.md'
        Set-Content -LiteralPath $untracked -Value 'untracked' -Encoding UTF8
        $script:Tracked = Get-TrackedPluginFile -RepoRoot $script:TrackedRoot
    }

    It 'Returns plugin-root-relative paths' {
        $script:Tracked | Should -Contain 'agents/alpha/one.agent.md'
    }

    It 'Excludes untracked files' {
        $script:Tracked | Should -Not -Contain 'agents/alpha/untracked.agent.md'
    }
}

Describe 'Get-PluginComponentSet' -Tag 'Unit' {
    BeforeAll {
        $script:ClassifyRoot = New-PluginFixture -Root (Join-Path $TestDrive 'classify')
        $script:Components = Get-PluginComponentSet -RepoRoot $script:ClassifyRoot
    }

    It 'Includes package-scoped agents from nested directories' {
        $script:Components.agents | Should -Be @(
            '.github/agents/alpha/one.agent.md',
            '.github/agents/alpha/subagents/two.agent.md'
        )
    }

    It 'Includes package-scoped prompts as commands' {
        $script:Components.commands | Should -Be @('.github/prompts/alpha/one.prompt.md')
    }

    It 'Includes package-scoped instructions as rules' {
        $script:Components.rules | Should -Be @('.github/instructions/beta/one.instructions.md')
    }

    It 'Includes skill roots whose license permits distribution' {
        $script:Components.skills | Should -Be @(
            '.github/skills/alpha/open-skill',
            '.github/skills/alpha/unlicensed-skill'
        )
    }

    It 'Excludes skills carrying a noncommercial license' {
        $script:Components.skills | Should -Not -Contain 'skills/beta/noncommercial-skill'
    }

    It 'Excludes repository-root <Kind> artifacts' -ForEach @(
        @{ Kind = 'agent'; Path = 'agents/root-only.agent.md'; Set = 'agents' }
        @{ Kind = 'prompt'; Path = 'prompts/root-only.prompt.md'; Set = 'commands' }
        @{ Kind = 'instruction'; Path = 'instructions/root-only.instructions.md'; Set = 'rules' }
        @{ Kind = 'skill'; Path = 'skills/root-only'; Set = 'skills' }
    ) {
        $script:Components[$Set] | Should -Not -Contain $Path
    }

    It 'Ignores files that match no component convention' {
        @($script:Components.Values | ForEach-Object { $_ }) | Should -Not -Contain 'agents/alpha/notes.md'
    }

    It 'Orders <Set> ordinally without duplicates' -ForEach @(
        @{ Set = 'agents' }
        @{ Set = 'commands' }
        @{ Set = 'rules' }
        @{ Set = 'skills' }
    ) {
        $paths = @($script:Components[$Set])
        $sorted = [System.Collections.Generic.List[string]]::new([string[]]$paths)
        $sorted.Sort([System.StringComparer]::Ordinal)
        $paths | Should -Be @($sorted)
        @($paths | Select-Object -Unique).Count | Should -Be $paths.Count
    }
}

Describe 'New-PluginManifest' -Tag 'Unit' {
    BeforeAll {
        $script:ManifestRoot = New-PluginFixture -Root (Join-Path $TestDrive 'manifest') -Version '4.5.6'
        $script:Manifest = New-PluginManifest `
            -RepoRoot $script:ManifestRoot `
            -Component (Get-PluginComponentSet -RepoRoot $script:ManifestRoot) `
            -Version (Get-RepositoryVersion -RepoRoot $script:ManifestRoot)
    }

    It 'Takes the version from the root package manifest' {
        $script:Manifest.version | Should -BeExactly '4.5.6'
    }

    It 'Preserves committed manifest metadata' {
        $script:Manifest.name | Should -BeExactly 'hve-core'
        $script:Manifest.description | Should -BeExactly 'Fixture plugin'
        $script:Manifest.license | Should -BeExactly 'MIT'
    }

    It 'Emits no hooks field' {
        $script:Manifest.Contains('hooks') | Should -BeFalse
    }

    It 'Orders manifest keys deterministically' {
        @($script:Manifest.Keys) | Should -Be @(
            'name', 'description', 'version', 'author', 'homepage',
            'repository', 'license', 'keywords',
            'agents', 'commands', 'rules', 'skills'
        )
    }

    It 'Serializes with LF endings and a single trailing newline' {
        $json = ConvertTo-PluginManifestJson -Manifest $script:Manifest
        $json | Should -Not -Match "`r"
        $json.EndsWith("}`n") | Should -BeTrue
    }
}

Describe 'Get-PluginMetadataViolations' -Tag 'Unit' {
    It 'Accepts tracked non-empty regular root metadata' {
        $root = New-PluginFixture -Root (Join-Path $TestDrive 'metadata-valid')
        Get-PluginMetadataViolations -RepoRoot $root | Should -HaveCount 0
    }

    It 'Rejects missing root metadata' {
        $root = New-PluginFixture -Root (Join-Path $TestDrive 'metadata-missing')
        Remove-Item -LiteralPath (Join-Path $root 'README.md') -Force
        (Get-PluginMetadataViolations -RepoRoot $root) -join "`n" |
            Should -Match 'missing or not a regular file: README\.md'
    }

    It 'Rejects untracked root metadata' {
        $root = New-PluginFixture -Root (Join-Path $TestDrive 'metadata-untracked')
        Set-Content -LiteralPath (Join-Path $root 'NOTICE') -Value 'notice' -Encoding UTF8
        $original = $script:RequiredPluginMetadata
        try {
            $script:RequiredPluginMetadata = @('NOTICE')
            (Get-PluginMetadataViolations -RepoRoot $root) -join "`n" |
                Should -Match 'not tracked: NOTICE'
        }
        finally {
            $script:RequiredPluginMetadata = $original
        }
    }

    It 'Rejects empty root metadata' {
        $root = New-PluginFixture -Root (Join-Path $TestDrive 'metadata-empty')
        Set-Content -LiteralPath (Join-Path $root 'LICENSE') -Value '' -Encoding UTF8 -NoNewline
        (Get-PluginMetadataViolations -RepoRoot $root) -join "`n" |
            Should -Match 'empty: LICENSE'
    }

    It 'Rejects symbolic-link root metadata by git mode' {
        $root = New-PluginFixture -Root (Join-Path $TestDrive 'metadata-symlink')
        $targetPath = Join-Path $root 'license-target.txt'
        Set-Content -LiteralPath $targetPath -Value 'MIT' -Encoding UTF8 -NoNewline
        Remove-Item -LiteralPath (Join-Path $root 'LICENSE') -Force
        New-Item -ItemType SymbolicLink -Path (Join-Path $root 'LICENSE') -Target $targetPath | Out-Null
        & git -C $root add --all

        (Get-PluginMetadataViolations -RepoRoot $root) -join "`n" |
            Should -Match 'not a tracked regular file: LICENSE \(mode 120000\)'
    }
}

Describe 'Invoke-PluginManifestSync write mode' -Tag 'Unit' {
    BeforeAll {
        $script:WriteRoot = New-PluginFixture -Root (Join-Path $TestDrive 'write')
        $script:WriteResult = Invoke-PluginManifestSync -RepoRoot $script:WriteRoot
        $script:WrittenManifest = Get-Content -LiteralPath (Join-Path $script:WriteRoot 'plugin.json') -Raw | ConvertFrom-Json -AsHashtable
    }

    It 'Reports the manifest as changed' {
        $script:WriteResult.Changed | Should -BeTrue
    }

    It 'Writes the derived component membership' {
        $script:WrittenManifest['agents'] | Should -HaveCount 2
        $script:WrittenManifest['skills'] | Should -HaveCount 2
    }

    It 'Reports no catalog violations' {
        $script:WriteResult.Violations | Should -HaveCount 0
    }

    It 'Makes no change on a second synchronization' {
        $before = (Get-FileHash (Join-Path $script:WriteRoot 'plugin.json') -Algorithm SHA256).Hash
        $second = Invoke-PluginManifestSync -RepoRoot $script:WriteRoot
        $second.Changed | Should -BeFalse
        (Get-FileHash (Join-Path $script:WriteRoot 'plugin.json') -Algorithm SHA256).Hash | Should -BeExactly $before
    }
}

Describe 'Invoke-PluginManifestSync failure atomicity' -Tag 'Unit' {
    It 'Stops before manifest derivation when required root metadata is invalid' {
        $root = New-PluginFixture -Root (Join-Path $TestDrive 'invalid-metadata')
        Remove-Item -LiteralPath (Join-Path $root 'README.md') -Force

        $result = Invoke-PluginManifestSync -RepoRoot $root

        $result.Changed | Should -BeFalse
        $result.Violations -join "`n" | Should -Match 'missing or not a regular file: README\.md'
        $result.Manifest | Should -BeNullOrEmpty
    }

    It 'Leaves a drifted manifest unchanged when catalog validation fails' {
        $root = New-PluginFixture -Root (Join-Path $TestDrive 'atomicity')
        Set-FixtureCatalog -Root $root -Transform {
            param($c) @($c['plugins'])[0]['description'] = 'Drifted description'; $c
        }
        $manifestPath = Join-Path $root 'plugin.json'
        $before = (Get-FileHash $manifestPath -Algorithm SHA256).Hash

        $result = Invoke-PluginManifestSync -RepoRoot $root

        $result.Changed | Should -BeTrue
        $result.Violations -join "`n" | Should -Match "field 'description' does not match"
        (Get-FileHash $manifestPath -Algorithm SHA256).Hash | Should -BeExactly $before
    }

    It 'Rejects a tracked symbolic link before component discovery' {
        $root = New-PluginFixture -Root (Join-Path $TestDrive 'symlink')
        $targetPath = Join-Path $root 'link-target.txt'
        Set-Content -LiteralPath $targetPath -Value 'agents/alpha/one.agent.md' -Encoding UTF8 -NoNewline
        $blob = (& git -C $root hash-object -w $targetPath).Trim()
        Remove-Item -LiteralPath $targetPath -Force
        & git -C $root update-index --add --cacheinfo 120000 $blob '.github/agents/alpha/link.agent.md'
        $LASTEXITCODE | Should -Be 0

        $result = Invoke-PluginManifestSync -RepoRoot $root

        $result.Violations -join "`n" | Should -Match 'symbolic link: agents/alpha/link\.agent\.md'
        $result.Manifest['agents'] | Should -Not -Contain 'agents/alpha/link.agent.md'
    }
}

Describe 'Invoke-PluginManifestSync check mode' -Tag 'Unit' {
    BeforeAll {
        $script:CheckRoot = New-PluginFixture -Root (Join-Path $TestDrive 'check')
        $script:CheckExpected = (Invoke-PluginManifestSync -RepoRoot $script:CheckRoot).Manifest
        $script:CheckManifestPath = Join-Path $script:CheckRoot 'plugin.json'
        $script:CheckManifestBytes = [System.IO.File]::ReadAllBytes($script:CheckManifestPath)

        function New-CommittedManifest {
            <#
            .SYNOPSIS
                Copies the derived manifest so a drift case can mutate one field.
            #>
            param([hashtable]$Override)

            $committed = [ordered]@{}
            foreach ($key in $script:CheckExpected.Keys) { $committed[$key] = $script:CheckExpected[$key] }
            foreach ($key in $Override.Keys) { $committed[$key] = $Override[$key] }
            return $committed
        }
    }

    It 'Reports no violations for a synchronized manifest' {
        (Invoke-PluginManifestSync -RepoRoot $script:CheckRoot -Check).Violations | Should -HaveCount 0
    }

    It 'Leaves the manifest untouched when drift exists' {
        Set-FixtureManifest -Root $script:CheckRoot -Transform {
            param($m) $m['agents'] = @('agents/alpha/one.agent.md'); $m
        }
        $before = (Get-FileHash $script:CheckManifestPath -Algorithm SHA256).Hash
        Invoke-PluginManifestSync -RepoRoot $script:CheckRoot -Check | Out-Null
        (Get-FileHash $script:CheckManifestPath -Algorithm SHA256).Hash | Should -BeExactly $before
    }

    It 'Names components missing from the committed manifest' {
        $committed = New-CommittedManifest -Override @{ agents = @('.github/agents/alpha/one.agent.md') }
        (Compare-PluginManifest -Committed $committed -Expected $script:CheckExpected) -join "`n" |
            Should -Match 'agents missing 1: \.github/agents/alpha/subagents/two\.agent\.md'
    }

    It 'Names components the committed manifest adds' {
        $committed = New-CommittedManifest -Override @{ skills = @($script:CheckExpected['skills']) + 'skills/beta/noncommercial-skill' }
        (Compare-PluginManifest -Committed $committed -Expected $script:CheckExpected) -join "`n" |
            Should -Match 'skills unexpected 1: skills/beta/noncommercial-skill'
    }

    It 'Detects stale version drift' {
        $committed = New-CommittedManifest -Override @{ version = '9.9.9' }
        (Compare-PluginManifest -Committed $committed -Expected $script:CheckExpected) -join "`n" |
            Should -Match "version differs: committed '9\.9\.9'; expected '1\.2\.3'"
    }

    It 'Names an unsupported committed field rather than reporting drift without detail' {
        $committed = New-CommittedManifest -Override @{ unknown = 'value' }
        (Compare-PluginManifest -Committed $committed -Expected $script:CheckExpected) -join "`n" |
            Should -Match 'unknown is declared but the manifest no longer supports it'
    }

    It 'Reports unsupported raw-only drift explicitly' {
        # Key order is the drift no field-level comparison can describe.
        Set-FixtureManifest -Root $script:CheckRoot -Transform {
            param($m)
            $reordered = [ordered]@{}
            foreach ($key in @($m.Keys) | Sort-Object) { $reordered[$key] = $m[$key] }
            $reordered
        }
        (Invoke-PluginManifestSync -RepoRoot $script:CheckRoot -Check).Violations -join "`n" |
            Should -Match 'no supported drift detail is available'
    }

    AfterEach {
        [System.IO.File]::WriteAllBytes($script:CheckManifestPath, $script:CheckManifestBytes)
    }
}

Describe 'Plugin catalog validation' -Tag 'Unit' {
    BeforeAll {
        $script:CatalogRoot = New-PluginFixture -Root (Join-Path $TestDrive 'catalog')
        $script:CatalogManifest = (Invoke-PluginManifestSync -RepoRoot $script:CatalogRoot).Manifest
    }

    AfterEach {
        Set-FixtureCatalog -Root $script:CatalogRoot -Transform {
            param($c)
            $c['plugins'] = @(
                [ordered]@{
                    name        = 'hve-core'
                    source      = '.'
                    description = 'Fixture plugin'
                    version     = $c['metadata']['version']
                    author      = [ordered]@{ name = 'Microsoft'; url = 'https://www.microsoft.com' }
                    homepage    = 'https://github.com/microsoft/hve-core'
                    repository  = 'https://github.com/microsoft/hve-core'
                    license     = 'MIT'
                    keywords    = @('hve', 'agents')
                }
            )
            $c
        }
    }

    It 'Accepts one relative locator entry' {
        Get-PluginCatalogViolations -RepoRoot $script:CatalogRoot -Manifest $script:CatalogManifest | Should -HaveCount 0
    }

    It 'Rejects more than one entry' {
        Set-FixtureCatalog -Root $script:CatalogRoot -Transform {
            param($c) $c['plugins'] = @($c['plugins']) + @([ordered]@{ name = 'extra'; source = '.github'; version = '1.2.3' }); $c
        }
        (Get-PluginCatalogMetadataViolations -RepoRoot $script:CatalogRoot -Manifest $script:CatalogManifest).Violations -join "`n" |
            Should -Match 'declares 2 entries'
    }

    It 'Rejects a name that differs from the manifest' {
        Set-FixtureCatalog -Root $script:CatalogRoot -Transform {
            param($c) @($c['plugins'])[0]['name'] = 'other'; $c
        }
        (Get-PluginCatalogMetadataViolations -RepoRoot $script:CatalogRoot -Manifest $script:CatalogManifest).Violations -join "`n" |
            Should -Match "field 'name' does not match"
    }

    It 'Rejects an entry version that differs from the manifest' {
        Set-FixtureCatalog -Root $script:CatalogRoot -Transform {
            param($c) @($c['plugins'])[0]['version'] = '9.9.9'; $c
        }
        (Get-PluginCatalogMetadataViolations -RepoRoot $script:CatalogRoot -Manifest $script:CatalogManifest).Violations -join "`n" |
            Should -Match "field 'version' does not match"
    }

    It 'Rejects catalog metadata that differs from the manifest' {
        Set-FixtureCatalog -Root $script:CatalogRoot -Transform {
            param($c) $c['metadata']['version'] = '9.9.9'; $c
        }
        (Get-PluginCatalogMetadataViolations -RepoRoot $script:CatalogRoot -Manifest $script:CatalogManifest).Violations -join "`n" |
            Should -Match 'metadata version'

        Set-FixtureCatalog -Root $script:CatalogRoot -Transform {
            param($c) $c['metadata']['version'] = $script:CatalogManifest['version']; $c
        }
    }

    It 'Rejects duplicated field <Field> that differs from the manifest' -ForEach @(
        @{ Field = 'description'; Value = 'Different description' }
        @{ Field = 'author'; Value = [ordered]@{ name = 'Other'; url = 'https://example.com' } }
        @{ Field = 'homepage'; Value = 'https://example.com/home' }
        @{ Field = 'repository'; Value = 'https://example.com/repo' }
        @{ Field = 'license'; Value = 'Apache-2.0' }
        @{ Field = 'keywords'; Value = @('different') }
    ) {
        $field = $Field
        $value = $Value
        Set-FixtureCatalog -Root $script:CatalogRoot -Transform {
            param($c) @($c['plugins'])[0][$field] = $value; $c
        }.GetNewClosure()
        (Get-PluginCatalogMetadataViolations -RepoRoot $script:CatalogRoot -Manifest $script:CatalogManifest).Violations -join "`n" |
            Should -Match "field '$([regex]::Escape($Field))' does not match"
    }

    It 'Rejects retired package recipe field <Field>' -ForEach @(
        @{ Field = 'agents'; Value = @('agents/alpha/one.agent.md') }
        @{ Field = 'commands'; Value = @('prompts/alpha/one.prompt.md') }
        @{ Field = 'rules'; Value = @('instructions/beta/one.instructions.md') }
        @{ Field = 'skills'; Value = @('skills/alpha/open-skill') }
        @{ Field = 'hooks'; Value = 'hooks/shared/telemetry.json' }
        @{ Field = 'x-hve'; Value = @{ displayName = 'HVE Core' } }
    ) {
        $field = $Field
        $value = $Value
        Set-FixtureCatalog -Root $script:CatalogRoot -Transform {
            param($c) @($c['plugins'])[0][$field] = $value; $c
        }.GetNewClosure()
        (Get-PluginCatalogMetadataViolations -RepoRoot $script:CatalogRoot -Manifest $script:CatalogManifest).Violations -join "`n" |
            Should -Match "retired package recipe field '$([regex]::Escape($Field))'"
    }

    It 'Rejects an object source locator' {
        Set-FixtureCatalog -Root $script:CatalogRoot -Transform {
            param($c) @($c['plugins'])[0]['source'] = [ordered]@{ source = 'github'; repo = 'microsoft/hve-core'; path = '.github' }; $c
        }
        (Get-PluginCatalogMetadataViolations -RepoRoot $script:CatalogRoot -Manifest $script:CatalogManifest).Violations -join "`n" |
            Should -Match 'must be a relative path string'
    }

    It 'Rejects a source that escapes the repository' {
        Set-FixtureCatalog -Root $script:CatalogRoot -Transform {
            param($c) @($c['plugins'])[0]['source'] = '../elsewhere'; $c
        }
        (Get-PluginCatalogMetadataViolations -RepoRoot $script:CatalogRoot -Manifest $script:CatalogManifest).Violations -join "`n" |
            Should -Match 'escapes the repository'
    }

    It 'Rejects a source without a plugin manifest' {
        Set-FixtureCatalog -Root $script:CatalogRoot -Transform {
            param($c) @($c['plugins'])[0]['source'] = 'missing'; $c
        }
        (Get-PluginCatalogMetadataViolations -RepoRoot $script:CatalogRoot -Manifest $script:CatalogManifest).Violations -join "`n" |
            Should -Match 'has no plugin manifest'
    }

    It 'Reports a declared component that does not exist' {
        $manifest = [ordered]@{}
        foreach ($key in $script:CatalogManifest.Keys) { $manifest[$key] = $script:CatalogManifest[$key] }
        $manifest['agents'] = @('.github/agents/alpha/absent.agent.md')

        (Get-PluginCatalogViolations -RepoRoot $script:CatalogRoot -Manifest $manifest) -join "`n" |
            Should -Match 'agents path does not exist'
    }

    It 'Reports a declared component that escapes the plugin root' {
        $manifest = [ordered]@{}
        foreach ($key in $script:CatalogManifest.Keys) { $manifest[$key] = $script:CatalogManifest[$key] }
        $manifest['skills'] = @('../outside')

        (Get-PluginCatalogViolations -RepoRoot $script:CatalogRoot -Manifest $manifest) -join "`n" |
            Should -Match 'skills path escapes the plugin root'
    }

    It 'Reports a declared component whose <Scenario> link resolves outside the plugin root' -ForEach @(
        @{ Scenario = 'leaf'; TargetName = 'outside-leaf.agent.md'; TargetIsDirectory = $false; LinkRelative = '.github/agents/alpha/outside.agent.md'; Component = '.github/agents/alpha/outside.agent.md' }
        @{ Scenario = 'parent'; TargetName = 'outside-parent'; TargetIsDirectory = $true; LinkRelative = '.github/agents/gamma'; Component = '.github/agents/gamma/nested.agent.md' }
    ) {
        $target = Join-Path $TestDrive $TargetName
        if ($TargetIsDirectory) {
            New-Item -ItemType Directory -Path $target -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $target 'nested.agent.md') -Value 'outside' -Encoding UTF8
        }
        else {
            Set-Content -LiteralPath $target -Value 'outside' -Encoding UTF8
        }
        New-Item -ItemType SymbolicLink -Path (Join-Path $script:CatalogRoot $LinkRelative) -Target $target | Out-Null

        $manifest = [ordered]@{}
        foreach ($key in $script:CatalogManifest.Keys) { $manifest[$key] = $script:CatalogManifest[$key] }
        $manifest['agents'] = @($Component)

        (Get-PluginCatalogViolations -RepoRoot $script:CatalogRoot -Manifest $manifest) -join "`n" |
            Should -Match 'agents path resolves outside the plugin root'
    }
}

Describe 'Retired hooks support' -Tag 'Unit' {
    It 'Reports a committed hooks declaration as drift rather than preserving it' {
        $root = New-PluginFixture -Root (Join-Path $TestDrive 'stray-hooks')
        $manifestPath = Join-Path $root 'plugin.json'
        $committed = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -AsHashtable
        $committed['hooks'] = '.github/hooks/shared/telemetry.json'
        Set-Content -LiteralPath $manifestPath `
            -Value (ConvertTo-PluginManifestJson -Manifest $committed) -Encoding UTF8 -NoNewline

        $result = Invoke-PluginManifestSync -RepoRoot $root -Check

        $result.Violations -join "`n" | Should -Match 'hooks is declared but the manifest no longer supports it'
        $result.Manifest.Contains('hooks') | Should -BeFalse
    }

    It 'Reports any other unsupported committed field as drift' {
        $root = New-PluginFixture -Root (Join-Path $TestDrive 'stray-field')
        $manifestPath = Join-Path $root 'plugin.json'
        $committed = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -AsHashtable
        $committed['x-hve'] = @{ displayName = 'HVE Core' }
        Set-Content -LiteralPath $manifestPath `
            -Value (ConvertTo-PluginManifestJson -Manifest $committed) -Encoding UTF8 -NoNewline

        (Invoke-PluginManifestSync -RepoRoot $root -Check).Violations -join "`n" |
            Should -Match 'x-hve is declared but the manifest no longer supports it'
    }

    It 'Drops a committed hooks declaration on write' {
        $root = New-PluginFixture -Root (Join-Path $TestDrive 'drop-hooks')
        $manifestPath = Join-Path $root 'plugin.json'
        $committed = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -AsHashtable
        $committed['hooks'] = '.github/hooks/shared/telemetry.json'
        Set-Content -LiteralPath $manifestPath `
            -Value (ConvertTo-PluginManifestJson -Manifest $committed) -Encoding UTF8 -NoNewline

        Invoke-PluginManifestSync -RepoRoot $root | Out-Null

        $written = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -AsHashtable
        $written.Contains('hooks') | Should -BeFalse
    }
}

Describe 'Committed repository manifest' -Tag 'Unit' {
    It 'Passes check mode without drift, catalog violations, or retired hooks' {
        Test-Path -LiteralPath (Join-Path $script:RepositoryRoot '.github/hooks') | Should -BeFalse

        $committed = Get-Content -LiteralPath (Join-Path $script:RepositoryRoot 'plugin.json') -Raw |
            ConvertFrom-Json -AsHashtable
        $committed.Contains('hooks') | Should -BeFalse

        $result = Invoke-PluginManifestSync -RepoRoot $script:RepositoryRoot -Check
        $result.Violations -join "`n" | Should -BeExactly ''
    }

    It 'Excludes the tracked noncommercial skill' {
        (Get-PluginComponentSet -RepoRoot $script:RepositoryRoot).skills |
            Should -Not -Contain '.github/skills/security/owasp-docker'
    }
}
