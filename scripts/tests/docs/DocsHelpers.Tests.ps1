#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    Import-Module $PSScriptRoot/../../docs/Modules/DocsHelpers.psm1 -Force
}

AfterAll {
    Remove-Module DocsHelpers, CollectionHelpers -Force -ErrorAction SilentlyContinue
}

Describe 'Get-AssetFrontmatter' -Tag 'Unit' {
    BeforeAll {
        $script:root = Join-Path $TestDrive 'frontmatter'
        New-Item -ItemType Directory -Path $script:root -Force | Out-Null

        $script:validPath = Join-Path $script:root 'valid.md'
        Set-Content -LiteralPath $script:validPath -Value (@(
                '---'
                'name: RPI Agent'
                'description: An orchestrator'
                'applyTo: "**/*.ps1"'
                '---'
                ''
                '# Body'
            ) -join "`n")

        $script:noFrontmatterPath = Join-Path $script:root 'plain.md'
        Set-Content -LiteralPath $script:noFrontmatterPath -Value "# Just a heading`n`nSome text."

        $script:malformedPath = Join-Path $script:root 'malformed.md'
        Set-Content -LiteralPath $script:malformedPath -Value (@(
                '---'
                'name: [unclosed'
                ': : :'
                '---'
                ''
                'Body'
            ) -join "`n")
    }

    It 'Returns all frontmatter fields as a hashtable' {
        $fm = Get-AssetFrontmatter -FilePath $script:validPath
        $fm | Should -BeOfType [hashtable]
        $fm['name'] | Should -Be 'RPI Agent'
        $fm['description'] | Should -Be 'An orchestrator'
        $fm['applyTo'] | Should -Be '**/*.ps1'
    }

    It 'Returns an empty hashtable when the file is missing' {
        $fm = Get-AssetFrontmatter -FilePath (Join-Path $script:root 'does-not-exist.md')
        $fm | Should -BeOfType [hashtable]
        $fm.Count | Should -Be 0
    }

    It 'Returns an empty hashtable when there is no frontmatter' {
        $fm = Get-AssetFrontmatter -FilePath $script:noFrontmatterPath
        $fm.Count | Should -Be 0
    }

    It 'Returns an empty hashtable when frontmatter is malformed' {
        $fm = Get-AssetFrontmatter -FilePath $script:malformedPath
        $fm | Should -BeOfType [hashtable]
    }
}

Describe 'Get-DocumentableAssets' -Tag 'Unit' {
    BeforeAll {
        $script:repoRoot = Join-Path $TestDrive 'repo'
        $ghDir = Join-Path $script:repoRoot '.github'

        function New-Fixture {
            param([string]$RelativePath, [string]$Content = '---')
            $full = Join-Path $ghDir $RelativePath
            $dir = Split-Path -Parent $full
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Set-Content -LiteralPath $full -Value $Content
        }

        # Documentable, collection-scoped
        New-Fixture 'agents/hve-core/rpi-agent.agent.md'
        New-Fixture 'agents/hve-core/subagents/researcher.agent.md'
        New-Fixture 'prompts/hve-core/task.prompt.md'
        New-Fixture 'instructions/shared/loc.instructions.md'
        New-Fixture 'skills/hve-core/documentation/SKILL.md'

        # Excluded: root-level repo-specific
        New-Fixture 'agents/internal.agent.md'
        New-Fixture 'instructions/workflows.instructions.md'

        # Excluded: deprecated tree
        New-Fixture 'agents/deprecated/old.agent.md'

        # Excluded: hooks are not a documentable kind
        New-Fixture 'hooks/shared/telemetry.json' '{ "version": 1 }'

        $script:assets = @(Get-DocumentableAssets -RepoRoot $script:repoRoot)
        $script:paths = $script:assets | ForEach-Object { $_.path }
    }

    It 'Includes collection-scoped agents, prompts, instructions, and skills' {
        $script:paths | Should -Contain '.github/agents/hve-core/rpi-agent.agent.md'
        $script:paths | Should -Contain '.github/prompts/hve-core/task.prompt.md'
        $script:paths | Should -Contain '.github/instructions/shared/loc.instructions.md'
        $script:paths | Should -Contain '.github/skills/hve-core/documentation'
    }

    It 'Includes nested subagents' {
        $script:paths | Should -Contain '.github/agents/hve-core/subagents/researcher.agent.md'
    }

    It 'Excludes root-level repo-specific assets' {
        $script:paths | Should -Not -Contain '.github/agents/internal.agent.md'
        $script:paths | Should -Not -Contain '.github/instructions/workflows.instructions.md'
    }

    It 'Excludes deprecated assets' {
        $script:paths | Should -Not -Contain '.github/agents/deprecated/old.agent.md'
    }

    It 'Excludes hooks (not a documentable kind)' {
        $script:assets.kind | Should -Not -Contain 'hook'
    }

    It 'Returns only documentable kinds' {
        $script:assets.kind | Sort-Object -Unique | Should -Be @('agent', 'instruction', 'prompt', 'skill')
    }

    It 'Sorts results by kind then path' {
        $ordered = $script:assets | Sort-Object -Property @{ Expression = 'kind' }, @{ Expression = 'path' }
        ($script:assets | ForEach-Object { "$($_.kind)|$($_.path)" }) |
            Should -Be ($ordered | ForEach-Object { "$($_.kind)|$($_.path)" })
    }
}

Describe 'Get-AssetDocsPath' -Tag 'Unit' {
    It 'Derives the docs path for an agent' {
        Get-AssetDocsPath -Path '.github/agents/hve-core/rpi-agent.agent.md' -Kind 'agent' |
            Should -Be 'docs/reference/agents/hve-core/rpi-agent.md'
    }

    It 'Preserves hierarchy for nested subagents' {
        Get-AssetDocsPath -Path '.github/agents/hve-core/subagents/researcher-subagent.agent.md' -Kind 'agent' |
            Should -Be 'docs/reference/agents/hve-core/subagents/researcher-subagent.md'
    }

    It 'Derives the docs path for a prompt' {
        Get-AssetDocsPath -Path '.github/prompts/security/vex-triage.prompt.md' -Kind 'prompt' |
            Should -Be 'docs/reference/prompts/security/vex-triage.md'
    }

    It 'Derives the docs path for a nested instruction' {
        Get-AssetDocsPath -Path '.github/instructions/coding-standards/powershell/powershell.instructions.md' -Kind 'instruction' |
            Should -Be 'docs/reference/instructions/coding-standards/powershell/powershell.md'
    }

    It 'Appends .md to the skill directory name' {
        Get-AssetDocsPath -Path '.github/skills/hve-core/documentation' -Kind 'skill' |
            Should -Be 'docs/reference/skills/hve-core/documentation.md'
    }

    It 'Normalizes backslash separators' {
        Get-AssetDocsPath -Path '.github\agents\hve-core\rpi-agent.agent.md' -Kind 'agent' |
            Should -Be 'docs/reference/agents/hve-core/rpi-agent.md'
    }

    It 'Throws for a path outside the documentable .github tree' {
        { Get-AssetDocsPath -Path 'docs/reference/agents/foo.md' -Kind 'agent' } | Should -Throw
    }
}

Describe 'Get-AssetInvocation' -Tag 'Unit' {
    It 'Uses the agent display name from frontmatter' {
        $result = Get-AssetInvocation -Kind 'agent' -Name 'rpi-agent' -Frontmatter @{ name = 'RPI Agent' }
        $result.Mechanism | Should -Be 'agent-picker'
        $result.Token | Should -Be 'RPI Agent'
    }

    It 'Falls back to the name when the agent has no display name' {
        $result = Get-AssetInvocation -Kind 'agent' -Name 'rpi-agent'
        $result.Token | Should -Be 'rpi-agent'
    }

    It 'Renders a prompt as a slash command' {
        $result = Get-AssetInvocation -Kind 'prompt' -Name 'vex-triage'
        $result.Mechanism | Should -Be 'slash-command'
        $result.Token | Should -Be '/vex-triage'
    }

    It 'Renders an instruction as auto-applied with its applyTo glob' {
        $result = Get-AssetInvocation -Kind 'instruction' -Name 'powershell' -Frontmatter @{ applyTo = '**/*.ps1' }
        $result.Mechanism | Should -Be 'auto-applied'
        $result.Token | Should -Be '**/*.ps1'
    }

    It 'Returns an empty token when an instruction has no applyTo' {
        $result = Get-AssetInvocation -Kind 'instruction' -Name 'powershell'
        $result.Token | Should -Be ''
    }

    It 'Renders a skill as skill-load' {
        $result = Get-AssetInvocation -Kind 'skill' -Name 'documentation'
        $result.Mechanism | Should -Be 'skill-load'
        $result.Token | Should -Be 'documentation'
    }
}

Describe 'Test-AssetInteractive' -Tag 'Unit' {
    It 'Treats agents as interactive' {
        Test-AssetInteractive -Kind 'agent' | Should -BeTrue
    }

    It 'Treats a prompt with argument-hint as interactive' {
        Test-AssetInteractive -Kind 'prompt' -Frontmatter @{ 'argument-hint' = 'report=path' } | Should -BeTrue
    }

    It 'Treats a prompt that binds an agent as interactive' {
        Test-AssetInteractive -Kind 'prompt' -Frontmatter @{ agent = 'VEX Generator' } | Should -BeTrue
    }

    It 'Treats a bare prompt as non-interactive' {
        Test-AssetInteractive -Kind 'prompt' | Should -BeFalse
    }

    It 'Treats instructions as non-interactive' {
        Test-AssetInteractive -Kind 'instruction' | Should -BeFalse
    }

    It 'Treats skills as non-interactive' {
        Test-AssetInteractive -Kind 'skill' | Should -BeFalse
    }
}

Describe 'Get-AssetDocMarker' -Tag 'Unit' {
    It 'Builds the BEGIN marker for a region' {
        Get-AssetDocMarker -Region 'metadata' -Boundary Begin |
            Should -Be '<!-- BEGIN AUTO-GENERATED: metadata -->'
    }

    It 'Builds the END marker for a region' {
        Get-AssetDocMarker -Region 'metadata' -Boundary End |
            Should -Be '<!-- END AUTO-GENERATED: metadata -->'
    }
}

Describe 'New-AssetGeneratedRegion' -Tag 'Unit' {
    It 'Wraps the body between the region markers' {
        $region = New-AssetGeneratedRegion -Region 'overview' -Body 'Hello'
        $region | Should -Be "<!-- BEGIN AUTO-GENERATED: overview -->`nHello`n<!-- END AUTO-GENERATED: overview -->"
    }

    It 'Trims surrounding blank lines from the body' {
        $region = New-AssetGeneratedRegion -Region 'overview' -Body "`n`nHello`n`n"
        $region | Should -Be "<!-- BEGIN AUTO-GENERATED: overview -->`nHello`n<!-- END AUTO-GENERATED: overview -->"
    }
}

Describe 'Split-AssetDocByMarkers' -Tag 'Unit' {
    It 'Extracts the body and surrounding content when markers are present' {
        $content = @(
            'before'
            '<!-- BEGIN AUTO-GENERATED: metadata -->'
            'BODY'
            '<!-- END AUTO-GENERATED: metadata -->'
            'after'
        ) -join "`n"
        $split = Split-AssetDocByMarkers -Content $content -Region 'metadata'
        $split.HasMarkers | Should -BeTrue
        $split.Body | Should -Be 'BODY'
        $split.Before | Should -Be ('before' + "`n")
        $split.After | Should -Be ("`n" + 'after')
    }

    It 'Reports no markers when the region is absent' {
        $split = Split-AssetDocByMarkers -Content 'plain content' -Region 'metadata'
        $split.HasMarkers | Should -BeFalse
        $split.Before | Should -Be 'plain content'
    }

    It 'Reports no markers when begin and end are mis-ordered' {
        $content = "<!-- END AUTO-GENERATED: metadata -->x<!-- BEGIN AUTO-GENERATED: metadata -->"
        $split = Split-AssetDocByMarkers -Content $content -Region 'metadata'
        $split.HasMarkers | Should -BeFalse
    }
}

Describe 'Merge-AssetDocRegion' -Tag 'Unit' {
    BeforeAll {
        $script:doc = @(
            '<!-- BEGIN AUTO-GENERATED: metadata -->'
            'old metadata'
            '<!-- END AUTO-GENERATED: metadata -->'
            ''
            '## When to use it'
            ''
            'Human authored guidance.'
            ''
            '<!-- BEGIN AUTO-GENERATED: overview -->'
            'old overview'
            '<!-- END AUTO-GENERATED: overview -->'
        ) -join "`n"
    }

    It 'Replaces only the target region body' {
        $merged = Merge-AssetDocRegion -Content $script:doc -Region 'metadata' -Body 'new metadata'
        $merged | Should -Match 'new metadata'
        $merged | Should -Not -Match 'old metadata'
    }

    It 'Preserves human-authored sections and other regions' {
        $merged = Merge-AssetDocRegion -Content $script:doc -Region 'metadata' -Body 'new metadata'
        $merged | Should -Match 'Human authored guidance\.'
        $merged | Should -Match 'old overview'
    }

    It 'Is idempotent when merging the same body twice' {
        $once = Merge-AssetDocRegion -Content $script:doc -Region 'metadata' -Body 'new metadata'
        $twice = Merge-AssetDocRegion -Content $once -Region 'metadata' -Body 'new metadata'
        $twice | Should -Be $once
    }

    It 'Throws when the region markers are absent' {
        { Merge-AssetDocRegion -Content 'no markers here' -Region 'metadata' -Body 'x' } | Should -Throw
    }
}

Describe 'Test-AssetDocStub' -Tag 'Unit' {
    It 'Detects the stub sentinel' {
        Test-AssetDocStub -Content "## When to use it`n`n<!-- asset-docs:stub -->`nTODO" | Should -BeTrue
    }

    It 'Returns false when no stub sentinel is present' {
        Test-AssetDocStub -Content "## When to use it`n`nFully authored." | Should -BeFalse
    }
}
