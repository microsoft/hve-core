#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ModulePath = (Resolve-Path (Join-Path $PSScriptRoot '../../docs/Modules/DocsHelpers.psm1')).Path
    Import-Module $script:ModulePath -Force

    function script:New-AssetFile {
        param(
            [string]$RepoRoot,
            [string]$RelativePath,
            [string[]]$Lines,
            [string]$Newline = "`n"
        )

        $full = Join-Path $RepoRoot $RelativePath
        New-Item -ItemType Directory -Path (Split-Path $full -Parent) -Force | Out-Null
        Set-Content -LiteralPath $full -Value ($Lines -join $Newline) -Encoding utf8NoBOM -NoNewline
        return $full
    }
}

AfterAll {
    Remove-Module DocsHelpers -Force -ErrorAction SilentlyContinue
}

Describe 'DocsHelpers module contract' -Tag 'Unit' {
    BeforeAll {
        $script:moduleSource = Get-Content -LiteralPath $script:ModulePath -Raw
        $script:module = Get-Module DocsHelpers
    }

    It 'Imports only ArtifactHelpers and PowerShell-Yaml' {
        $imports = @([regex]::Matches($script:moduleSource, '(?m)^Import-Module\s+(.+)$') | ForEach-Object { $_.Groups[1].Value.Trim() })
        $imports | Should -Be @(
            'PowerShell-Yaml -ErrorAction Stop'
            "(Join-Path `$PSScriptRoot '../../lib/Modules/ArtifactHelpers.psm1') -Force"
        )
    }

    It 'Declares no dependency on a collection helper module' {
        $script:moduleSource | Should -Not -Match 'CollectionHelpers'
    }

    It 'Exports the documented asset documentation surface' {
        @($script:module.ExportedFunctions.Keys | Sort-Object) | Should -Be @(
            'ConvertTo-TableCell'
            'Format-AssetInvocation'
            'Format-MarkdownTable'
            'Format-YamlScalar'
            'Get-AssetDocMarker'
            'Get-AssetDocSectionContract'
            'Get-AssetDocsPath'
            'Get-AssetFrontmatter'
            'Get-AssetInvocation'
            'Get-DocumentableAssets'
            'Merge-AssetDocRegion'
            'New-AssetGeneratedRegion'
            'New-AssetMetadataBlock'
            'New-AssetOverviewBody'
            'New-AssetPageModel'
            'Resolve-AssetDocSectionStatus'
            'Split-AssetDocByMarkers'
            'Test-AssetDocStub'
            'Test-AssetInteractive'
        )
    }
}

Describe 'Get-AssetFrontmatter' -Tag 'Unit' {
    BeforeAll {
        $script:root = Join-Path $TestDrive 'frontmatter'
        New-Item -ItemType Directory -Path $script:root -Force | Out-Null

        $script:validPath = New-AssetFile -RepoRoot $script:root -RelativePath 'valid.md' -Lines @(
            '---'
            'name: RPI Agent'
            'description: Coordinates the RPI lifecycle.'
            'applyTo: "**/*.ps1"'
            '---'
            ''
            '# Body'
        )
        $script:crlfPath = New-AssetFile -RepoRoot $script:root -RelativePath 'crlf.md' -Newline "`r`n" -Lines @(
            '---'
            'name: RPI Agent'
            'description: Coordinates the RPI lifecycle.'
            'applyTo: "**/*.ps1"'
            '---'
            ''
            '# Body'
        )
        $script:plainPath = New-AssetFile -RepoRoot $script:root -RelativePath 'plain.md' -Lines @('# Just a heading', '', 'Some text.')
        $script:malformedPath = New-AssetFile -RepoRoot $script:root -RelativePath 'malformed.md' -Lines @('---', 'name: [unclosed', ': : :', '---', '', 'Body')
    }

    It 'Returns every declared frontmatter field' {
        $frontmatter = Get-AssetFrontmatter -FilePath $script:validPath

        $frontmatter | Should -BeOfType [hashtable]
        $frontmatter['name'] | Should -Be 'RPI Agent'
        $frontmatter['description'] | Should -Be 'Coordinates the RPI lifecycle.'
        $frontmatter['applyTo'] | Should -Be '**/*.ps1'
    }

    It 'Parses CRLF frontmatter identically to LF frontmatter' {
        $crlf = Get-AssetFrontmatter -FilePath $script:crlfPath

        $crlf['name'] | Should -Be 'RPI Agent'
        $crlf['description'] | Should -Be 'Coordinates the RPI lifecycle.'
        $crlf['applyTo'] | Should -Be '**/*.ps1'
    }

    It 'Returns an empty hashtable when the file does not exist' {
        $frontmatter = Get-AssetFrontmatter -FilePath (Join-Path $script:root 'absent.md')

        $frontmatter | Should -BeOfType [hashtable]
        $frontmatter.Count | Should -Be 0
    }

    It 'Returns an empty hashtable when the file declares no frontmatter' {
        (Get-AssetFrontmatter -FilePath $script:plainPath).Count | Should -Be 0
    }

    It 'Returns a hashtable rather than throwing on malformed frontmatter' {
        Get-AssetFrontmatter -FilePath $script:malformedPath | Should -BeOfType [hashtable]
    }
}

Describe 'Get-DocumentableAssets' -Tag 'Unit' {
    BeforeAll {
        $script:repoRoot = Join-Path $TestDrive 'discovery-repo'

        # Documentable assets live under a package directory within each kind.
        New-AssetFile -RepoRoot $script:repoRoot -RelativePath '.github/agents/hve-core/rpi-agent.agent.md' -Lines @('---', 'description: Agent.', '---') | Out-Null
        New-AssetFile -RepoRoot $script:repoRoot -RelativePath '.github/agents/hve-core/subagents/rpi-planner.agent.md' -Lines @('---', 'description: Subagent.', '---') | Out-Null
        New-AssetFile -RepoRoot $script:repoRoot -RelativePath '.github/prompts/hve-core/rpi.prompt.md' -Lines @('---', 'description: Prompt.', '---') | Out-Null
        New-AssetFile -RepoRoot $script:repoRoot -RelativePath '.github/instructions/shared/telemetry-overlay.instructions.md' -Lines @('---', 'description: Instructions.', '---') | Out-Null
        New-AssetFile -RepoRoot $script:repoRoot -RelativePath '.github/skills/hve-core/documentation/SKILL.md' -Lines @('---', 'description: Skill.', '---') | Out-Null

        # Root-level repo-specific assets are excluded from the package surface.
        New-AssetFile -RepoRoot $script:repoRoot -RelativePath '.github/agents/issue-triage.agent.md' -Lines @('---', 'description: Repo agent.', '---') | Out-Null
        New-AssetFile -RepoRoot $script:repoRoot -RelativePath '.github/instructions/workflows.instructions.md' -Lines @('---', 'description: Repo instructions.', '---') | Out-Null

        # Deprecated trees and non-documentable kinds are excluded.
        New-AssetFile -RepoRoot $script:repoRoot -RelativePath '.github/agents/deprecated/retired.agent.md' -Lines @('---', 'description: Retired.', '---') | Out-Null
        New-AssetFile -RepoRoot $script:repoRoot -RelativePath '.github/hooks/shared/telemetry.json' -Lines @('{ "version": 1 }') | Out-Null

        $script:assets = @(Get-DocumentableAssets -RepoRoot $script:repoRoot)
        $script:paths = @($script:assets | ForEach-Object { $_.path })
    }

    It 'Discovers exactly the package-scoped documentable assets' {
        @($script:paths | Sort-Object) | Should -Be @(
            '.github/agents/hve-core/rpi-agent.agent.md'
            '.github/agents/hve-core/subagents/rpi-planner.agent.md'
            '.github/instructions/shared/telemetry-overlay.instructions.md'
            '.github/prompts/hve-core/rpi.prompt.md'
            '.github/skills/hve-core/documentation'
        )
    }

    It 'Excludes root-level repo-specific assets' {
        $script:paths | Should -Not -Contain '.github/agents/issue-triage.agent.md'
        $script:paths | Should -Not -Contain '.github/instructions/workflows.instructions.md'
    }

    It 'Excludes deprecated assets' {
        $script:paths | Should -Not -Contain '.github/agents/deprecated/retired.agent.md'
    }

    It 'Excludes hooks because they are not a documentable kind' {
        @($script:assets | Where-Object { $_.kind -eq 'hook' }) | Should -BeNullOrEmpty
    }

    It 'Returns assets sorted by kind then path' {
        @($script:assets | ForEach-Object { "$($_.kind)|$($_.path)" }) | Should -Be @(
            'agent|.github/agents/hve-core/rpi-agent.agent.md'
            'agent|.github/agents/hve-core/subagents/rpi-planner.agent.md'
            'instruction|.github/instructions/shared/telemetry-overlay.instructions.md'
            'prompt|.github/prompts/hve-core/rpi.prompt.md'
            'skill|.github/skills/hve-core/documentation'
        )
    }
}

Describe 'Get-AssetDocsPath' -Tag 'Unit' {
    It 'Maps an agent to its reference page' {
        Get-AssetDocsPath -Path '.github/agents/hve-core/rpi-agent.agent.md' -Kind 'agent' |
            Should -Be 'docs/reference/agents/hve-core/rpi-agent.md'
    }

    It 'Preserves the subagent directory level' {
        Get-AssetDocsPath -Path '.github/agents/hve-core/subagents/rpi-planner.agent.md' -Kind 'agent' |
            Should -Be 'docs/reference/agents/hve-core/subagents/rpi-planner.md'
    }

    It 'Maps a prompt to its reference page' {
        Get-AssetDocsPath -Path '.github/prompts/hve-core/rpi.prompt.md' -Kind 'prompt' |
            Should -Be 'docs/reference/prompts/hve-core/rpi.md'
    }

    It 'Maps an instruction to its reference page' {
        Get-AssetDocsPath -Path '.github/instructions/shared/telemetry-overlay.instructions.md' -Kind 'instruction' |
            Should -Be 'docs/reference/instructions/shared/telemetry-overlay.md'
    }

    It 'Maps a skill directory to its reference page' {
        Get-AssetDocsPath -Path '.github/skills/hve-core/documentation' -Kind 'skill' |
            Should -Be 'docs/reference/skills/hve-core/documentation.md'
    }

    It 'Normalizes backslash separators' {
        Get-AssetDocsPath -Path '.github\agents\hve-core\rpi-agent.agent.md' -Kind 'agent' |
            Should -Be 'docs/reference/agents/hve-core/rpi-agent.md'
    }

    It 'Throws for a path outside the documentable kind directories' {
        { Get-AssetDocsPath -Path '.github/workflows/pr-validation.yml' -Kind 'agent' } |
            Should -Throw -ExpectedMessage 'Path is not a documentable .github asset: .github/workflows/pr-validation.yml'
    }
}

Describe 'Get-AssetInvocation' -Tag 'Unit' {
    It 'Reports an agent as selectable in the chat agent picker under its display name' {
        $invocation = Get-AssetInvocation -Kind 'agent' -Name 'rpi-agent' -Frontmatter @{ name = 'RPI Agent' } -Path '.github/agents/hve-core/rpi-agent.agent.md'

        $invocation.Mechanism | Should -Be 'agent-picker'
        $invocation.Token | Should -Be 'RPI Agent'
    }

    It 'Falls back to the artifact key when an agent declares no display name' {
        (Get-AssetInvocation -Kind 'agent' -Name 'rpi-agent' -Path '.github/agents/hve-core/rpi-agent.agent.md').Token | Should -Be 'rpi-agent'
    }

    It 'Reports an agent under a subagents directory as delegated' {
        (Get-AssetInvocation -Kind 'agent' -Name 'rpi-planner' -Path '.github/agents/hve-core/subagents/rpi-planner.agent.md').Mechanism |
            Should -Be 'subagent-delegated'
    }

    It 'Reports a prompt as a slash command' {
        $invocation = Get-AssetInvocation -Kind 'prompt' -Name 'rpi'

        $invocation.Mechanism | Should -Be 'slash-command'
        $invocation.Token | Should -Be '/rpi'
    }

    It 'Reports an instruction as auto-applied to its applyTo glob' {
        $invocation = Get-AssetInvocation -Kind 'instruction' -Name 'markdown' -Frontmatter @{ applyTo = '**/*.md' }

        $invocation.Mechanism | Should -Be 'auto-applied'
        $invocation.Token | Should -Be '**/*.md'
    }

    It 'Reports an instruction with no applyTo as auto-applied with an empty token' {
        (Get-AssetInvocation -Kind 'instruction' -Name 'markdown').Token | Should -Be ''
    }

    It 'Reports a skill as user-invocable and model-loadable by default' {
        $invocation = Get-AssetInvocation -Kind 'skill' -Name 'documentation'

        $invocation.Mechanism | Should -Be 'skill-user-and-load'
        $invocation.Token | Should -Be '/documentation'
    }

    It 'Reports a skill with model invocation disabled as user-only' {
        (Get-AssetInvocation -Kind 'skill' -Name 'documentation' -Frontmatter @{ 'disable-model-invocation' = $true }).Mechanism |
            Should -Be 'skill-user-only'
    }

    It 'Reports a skill that is not user-invocable as load-only' {
        $invocation = Get-AssetInvocation -Kind 'skill' -Name 'documentation' -Frontmatter @{ 'user-invocable' = $false }

        $invocation.Mechanism | Should -Be 'skill-load'
        $invocation.Token | Should -Be 'documentation'
    }

    It 'Treats the quoted string false as false rather than truthy' {
        (Get-AssetInvocation -Kind 'skill' -Name 'documentation' -Frontmatter @{ 'user-invocable' = 'false' }).Mechanism |
            Should -Be 'skill-load'
    }
}

Describe 'Test-AssetInteractive' -Tag 'Unit' {
    It 'Treats a chat-picker agent as interactive' {
        Test-AssetInteractive -Kind 'agent' -Path '.github/agents/hve-core/rpi-agent.agent.md' | Should -BeTrue
    }

    It 'Treats a delegated subagent as non-interactive' {
        Test-AssetInteractive -Kind 'agent' -Path '.github/agents/hve-core/subagents/rpi-planner.agent.md' | Should -BeFalse
    }

    It 'Treats a prompt declaring an argument hint as interactive' {
        Test-AssetInteractive -Kind 'prompt' -Frontmatter @{ 'argument-hint' = 'task description' } | Should -BeTrue
    }

    It 'Treats a prompt binding an agent as interactive' {
        Test-AssetInteractive -Kind 'prompt' -Frontmatter @{ agent = 'RPI Agent' } | Should -BeTrue
    }

    It 'Treats a prompt with neither inputs nor an agent as non-interactive' {
        Test-AssetInteractive -Kind 'prompt' -Frontmatter @{ description = 'A prompt.' } | Should -BeFalse
    }

    It 'Treats instructions and skills as non-interactive' {
        Test-AssetInteractive -Kind 'instruction' | Should -BeFalse
        Test-AssetInteractive -Kind 'skill' | Should -BeFalse
    }
}

Describe 'Asset documentation section contract' -Tag 'Unit' {
    BeforeAll {
        $script:sections = @(Get-AssetDocSectionContract)
    }

    It 'Declares the canonical heading order once' {
        $script:sections.Heading | Should -Be @(
            '## What it does'
            '## When to use it'
            '## How to use it'
            '## Example usage'
        )
    }

    It 'Resolves How to use it from kind and interactivity' -ForEach @(
        @{ Kind = 'agent'; Interactive = $true; Expected = 'Required' }
        @{ Kind = 'agent'; Interactive = $false; Expected = 'NotApplicable' }
        @{ Kind = 'prompt'; Interactive = $true; Expected = 'Required' }
        @{ Kind = 'prompt'; Interactive = $false; Expected = 'NotApplicable' }
        @{ Kind = 'instruction'; Interactive = $false; Expected = 'NotApplicable' }
        @{ Kind = 'skill'; Interactive = $false; Expected = 'NotApplicable' }
    ) {
        $section = $script:sections | Where-Object Name -EQ 'how-to-use-it'

        Resolve-AssetDocSectionStatus -Section $section -Kind $Kind -Interactive $Interactive |
            Should -Be $Expected
    }

    It 'Resolves Example usage from the shared contract' -ForEach @(
        @{ Kind = 'agent'; Interactive = $true; Expected = 'Required' }
        @{ Kind = 'agent'; Interactive = $false; Expected = 'Required' }
        @{ Kind = 'prompt'; Interactive = $true; Expected = 'Required' }
        @{ Kind = 'skill'; Interactive = $false; Expected = 'Required' }
        @{ Kind = 'instruction'; Interactive = $false; Expected = 'Optional' }
    ) {
        $section = $script:sections | Where-Object Name -EQ 'example-usage'

        Resolve-AssetDocSectionStatus -Section $section -Kind $Kind -Interactive $Interactive |
            Should -Be $Expected
    }

    It 'Rejects unsupported resolved statuses' {
        $section = [PSCustomObject]@{
            Name         = 'invalid-example'
            Requirements = @{ instruction = 'Conditional' }
        }

        { Resolve-AssetDocSectionStatus -Section $section -Kind 'instruction' -Interactive $false } |
            Should -Throw -ExpectedMessage "Section 'invalid-example' resolves to unsupported status 'Conditional'."
    }
}

Describe 'Format-AssetInvocation' -Tag 'Unit' {
    It 'Renders the chat agent picker mechanism' {
        Format-AssetInvocation -Invocation @{ Mechanism = 'agent-picker'; Token = 'RPI Agent' } |
            Should -Be 'Selected from the chat agent picker as `RPI Agent`'
    }

    It 'Renders the slash command mechanism' {
        Format-AssetInvocation -Invocation @{ Mechanism = 'slash-command'; Token = '/rpi' } |
            Should -Be 'Slash command `/rpi`'
    }

    It 'Renders the auto-applied mechanism with its glob' {
        Format-AssetInvocation -Invocation @{ Mechanism = 'auto-applied'; Token = '**/*.md' } |
            Should -Be 'Applied automatically to `**/*.md`'
    }

    It 'Renders the auto-applied mechanism without a glob' {
        Format-AssetInvocation -Invocation @{ Mechanism = 'auto-applied'; Token = '' } |
            Should -Be 'Applied automatically'
    }

    It 'Renders the delegated subagent mechanism' {
        Format-AssetInvocation -Invocation @{ Mechanism = 'subagent-delegated'; Token = 'RPI Planner' } |
            Should -Be 'Delegated subagent, dispatched by a parent agent (not selected directly)'
    }

    It 'Renders a drift marker and warns for an unrecognized mechanism' {
        $warnings = @()
        $rendered = Format-AssetInvocation -Invocation @{ Mechanism = 'not-a-mechanism'; Token = 'x' } -WarningVariable warnings -WarningAction SilentlyContinue

        $rendered | Should -Be '(unknown invocation: not-a-mechanism)'
        @($warnings).Count | Should -Be 1
    }
}

Describe 'Generated region markers' -Tag 'Unit' {
    It 'Builds the named begin and end markers' {
        Get-AssetDocMarker -Region 'metadata' -Boundary Begin | Should -Be '<!-- BEGIN AUTO-GENERATED: metadata -->'
        Get-AssetDocMarker -Region 'metadata' -Boundary End | Should -Be '<!-- END AUTO-GENERATED: metadata -->'
    }

    It 'Wraps a body between the markers and trims surrounding blank lines' {
        New-AssetGeneratedRegion -Region 'overview' -Body "`n`nBody text`n`n" |
            Should -Be "<!-- BEGIN AUTO-GENERATED: overview -->`nBody text`n<!-- END AUTO-GENERATED: overview -->"
    }

    It 'Splits a page into the human sections around the generated body' {
        $content = "Header`n`n<!-- BEGIN AUTO-GENERATED: overview -->`nGenerated`n<!-- END AUTO-GENERATED: overview -->`n`n## When to use it`n"

        $split = Split-AssetDocByMarkers -Content $content -Region 'overview'

        $split.HasMarkers | Should -BeTrue
        $split.Before | Should -Be "Header`n`n"
        $split.Body | Should -Be 'Generated'
        $split.After | Should -Be "`n`n## When to use it`n"
    }

    It 'Reports no markers and returns the whole page when the region is absent' {
        $split = Split-AssetDocByMarkers -Content "Header only`n" -Region 'overview'

        $split.HasMarkers | Should -BeFalse
        $split.Before | Should -Be "Header only`n"
        $split.Body | Should -Be ''
        $split.After | Should -Be ''
    }

    It 'Reports no markers when the end marker precedes the begin marker' {
        $content = "<!-- END AUTO-GENERATED: overview -->`nbody`n<!-- BEGIN AUTO-GENERATED: overview -->"

        (Split-AssetDocByMarkers -Content $content -Region 'overview').HasMarkers | Should -BeFalse
    }

    It 'Reports no markers when a second begin marker is nested in the region' {
        $content = "<!-- BEGIN AUTO-GENERATED: overview -->`n<!-- BEGIN AUTO-GENERATED: overview -->`nbody`n<!-- END AUTO-GENERATED: overview -->"

        (Split-AssetDocByMarkers -Content $content -Region 'overview').HasMarkers | Should -BeFalse
    }
}

Describe 'Merge-AssetDocRegion' -Tag 'Unit' {
    It 'Replaces only the generated body and preserves both human sections' {
        $content = "## Head`n`n<!-- BEGIN AUTO-GENERATED: overview -->`nOld`n<!-- END AUTO-GENERATED: overview -->`n`n## Example usage`n`nAuthored prose.`n"

        Merge-AssetDocRegion -Content $content -Region 'overview' -Body 'New' |
            Should -Be "## Head`n`n<!-- BEGIN AUTO-GENERATED: overview -->`nNew`n<!-- END AUTO-GENERATED: overview -->`n`n## Example usage`n`nAuthored prose.`n"
    }

    It 'Throws rather than discarding human sections when the region is absent' {
        { Merge-AssetDocRegion -Content "## Head`n`nAuthored prose.`n" -Region 'overview' -Body 'New' } |
            Should -Throw -ExpectedMessage "Region markers for 'overview' not found; cannot merge without corrupting human-authored sections."
    }
}

Describe 'Test-AssetDocStub' -Tag 'Unit' {
    It 'Detects an unwritten human section' {
        Test-AssetDocStub -Content "## When to use it`n`n<!-- asset-docs:stub -->`nPlaceholder." | Should -BeTrue
    }

    It 'Returns false for a fully authored page' {
        Test-AssetDocStub -Content "## When to use it`n`nAuthored guidance." | Should -BeFalse
    }
}

Describe 'New-AssetPageModel' -Tag 'Unit' {
    BeforeAll {
        $script:modelRepo = Join-Path $TestDrive 'model-repo'

        New-AssetFile -RepoRoot $script:modelRepo -RelativePath '.github/agents/hve-core/rpi-agent.agent.md' -Lines @(
            '---'
            'name: RPI Agent'
            'description: Coordinates Research, Plan, and Implement.'
            '---'
            ''
            '# Body'
        ) | Out-Null
        New-AssetFile -RepoRoot $script:modelRepo -RelativePath '.github/prompts/hve-core/git-commit.prompt.md' -Lines @(
            '---'
            'description: Writes a commit message.'
            'argument-hint: "scope"'
            '---'
            ''
            '# Body'
        ) | Out-Null
        New-AssetFile -RepoRoot $script:modelRepo -RelativePath '.github/skills/hve-core/documentation/SKILL.md' -Lines @(
            '---'
            'name: documentation'
            'description: Documentation audit and authoring.'
            '---'
            ''
            '# Body'
        ) | Out-Null
    }

    It 'Resolves the agent model from its frontmatter and path' {
        $model = New-AssetPageModel -Asset @{ path = '.github/agents/hve-core/rpi-agent.agent.md'; kind = 'agent' } -RepoRoot $script:modelRepo

        $model.Kind | Should -Be 'agent'
        $model.Key | Should -Be 'rpi-agent'
        $model.Title | Should -Be 'RPI Agent'
        $model.Description | Should -Be 'Coordinates Research, Plan, and Implement.'
        $model.SourceRel | Should -Be '.github/agents/hve-core/rpi-agent.agent.md'
        $model.DocRel | Should -Be 'docs/reference/agents/hve-core/rpi-agent.md'
        $model.Folder | Should -Be 'docs/reference/agents/hve-core'
        $model.KindDir | Should -Be 'agents'
        $model.Interactive | Should -BeTrue
    }

    It 'Title-cases the artifact key when no name or title is declared' {
        $model = New-AssetPageModel -Asset @{ path = '.github/prompts/hve-core/git-commit.prompt.md'; kind = 'prompt' } -RepoRoot $script:modelRepo

        $model.Title | Should -Be 'Git Commit'
        $model.Invocation.Token | Should -Be '/git-commit'
        $model.Interactive | Should -BeTrue
    }

    It 'Reads a skill model from its SKILL.md' {
        $model = New-AssetPageModel -Asset @{ path = '.github/skills/hve-core/documentation'; kind = 'skill' } -RepoRoot $script:modelRepo

        $model.Key | Should -Be 'documentation'
        $model.Description | Should -Be 'Documentation audit and authoring.'
        $model.DocRel | Should -Be 'docs/reference/skills/hve-core/documentation.md'
        $model.Interactive | Should -BeFalse
    }
}

Describe 'New-AssetMetadataBlock' -Tag 'Unit' {
    It 'Renders an aligned metadata table for an interactive asset' {
        $block = New-AssetMetadataBlock -Kind 'agent' -SourcePath '.github/agents/hve-core/rpi-agent.agent.md' `
            -Invocation @{ Mechanism = 'agent-picker'; Token = 'RPI Agent' } -Interactive $true

        $lines = @($block -split "`n")
        $cells = @($lines | ForEach-Object { , @(($_ -replace '^\|', '' -replace '\|$', '') -split '\|' | ForEach-Object { $_.Trim() }) })

        $cells[0] | Should -Be @('Field', 'Value')
        $lines[1] | Should -Match '^\|-+\|-+\|$'
        $cells[2] | Should -Be @('Kind', 'agent')
        $cells[3] | Should -Be @('Source', '`.github/agents/hve-core/rpi-agent.agent.md`')
        $cells[4] | Should -Be @('Invocation', 'Selected from the chat agent picker as `RPI Agent`')
        $cells[5] | Should -Be @('Interactive', 'Yes')
        @($lines | ForEach-Object { $_.Length } | Sort-Object -Unique).Count | Should -Be 1 -Because 'every row is padded to the widest cell'
    }

    It 'Renders Interactive as No for a passive asset' {
        $block = New-AssetMetadataBlock -Kind 'instruction' -SourcePath '.github/instructions/hve-core/markdown.instructions.md' `
            -Invocation @{ Mechanism = 'auto-applied'; Token = '**/*.md' } -Interactive $false

        $block | Should -Match '(?m)^\| Interactive \| No\s+\|$'
    }
}

Describe 'New-AssetOverviewBody' -Tag 'Unit' {
    It 'Returns the description collapsed onto one line' {
        $body = New-AssetOverviewBody -Model ([PSCustomObject]@{ Description = "First line`nsecond line" })

        $body | Should -Be 'First line second line'
    }

    It 'Returns a stable sentence when the asset declares no description' {
        New-AssetOverviewBody -Model ([PSCustomObject]@{ Description = '' }) |
            Should -Be 'This asset does not declare a description.'
    }

    It 'Wraps a long description at 500 characters on word boundaries' {
        $word = 'alpha'
        $description = (1..200 | ForEach-Object { $word }) -join ' '

        $lines = @((New-AssetOverviewBody -Model ([PSCustomObject]@{ Description = $description })) -split "`n")

        $lines.Count | Should -BeGreaterThan 1
        foreach ($line in $lines[0..($lines.Count - 2)]) {
            $line.Length | Should -BeLessOrEqual 500
        }
        ($lines -join ' ') | Should -Be $description
    }
}

Describe 'Text formatting helpers' -Tag 'Unit' {
    It 'Leaves a safe YAML scalar unquoted' {
        Format-YamlScalar -Value 'RPI Agent' | Should -Be 'RPI Agent'
    }

    It 'Quotes and escapes a YAML scalar containing a colon' {
        Format-YamlScalar -Value 'Agent: the sequel' | Should -Be '"Agent: the sequel"'
    }

    It 'Quotes an empty YAML scalar' {
        Format-YamlScalar -Value '' | Should -Be '""'
    }

    It 'Collapses newlines and escapes pipes in a table cell' {
        ConvertTo-TableCell -Value "one|two`nthree" | Should -Be 'one\|two three'
    }

    It 'Pads every column of a Markdown table to its widest cell' {
        Format-MarkdownTable -Header @('Asset', 'Description') -Rows @(, @('rpi-agent', 'Coordinates RPI')) |
            Should -Be (@(
                    '| Asset     | Description     |'
                    '|-----------|-----------------|'
                    '| rpi-agent | Coordinates RPI |'
                ) -join "`n")
    }
}
