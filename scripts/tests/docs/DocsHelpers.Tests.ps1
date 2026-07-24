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

    It 'Parses frontmatter identically when the file uses CRLF line endings' {
        $lf = @(
            '---'
            'name: RPI Agent'
            'description: An orchestrator'
            'applyTo: "**/*.ps1"'
            '---'
            ''
            '# Body'
        ) -join "`n"
        $crlfPath = Join-Path $script:root 'crlf.md'
        Set-Content -LiteralPath $crlfPath -Value ($lf -replace "`n", "`r`n") -Encoding utf8NoBOM -NoNewline

        $fm = Get-AssetFrontmatter -FilePath $crlfPath
        $fm['name'] | Should -Be 'RPI Agent'
        $fm['description'] | Should -Be 'An orchestrator'
        $fm['applyTo'] | Should -Be '**/*.ps1'
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
        New-Fixture 'agents/hve-core/subagents/sample-subagent.agent.md'
        New-Fixture 'prompts/hve-core/sample-prompt.prompt.md'
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
        $script:paths | Should -Contain '.github/prompts/hve-core/sample-prompt.prompt.md'
        $script:paths | Should -Contain '.github/instructions/shared/loc.instructions.md'
        $script:paths | Should -Contain '.github/skills/hve-core/documentation'
    }

    It 'Includes nested subagents' {
        $script:paths | Should -Contain '.github/agents/hve-core/subagents/sample-subagent.agent.md'
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
        Get-AssetDocsPath -Path '.github/agents/hve-core/subagents/sample-subagent.agent.md' -Kind 'agent' |
            Should -Be 'docs/reference/agents/hve-core/subagents/sample-subagent.md'
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

    It 'Classifies an agent under a subagents directory as a delegated subagent' {
        $result = Get-AssetInvocation -Kind 'agent' -Name 'researcher-subagent' -Frontmatter @{ name = 'Researcher Subagent' } -Path '.github/agents/hve-core/subagents/researcher-subagent.agent.md'
        $result.Mechanism | Should -Be 'subagent-delegated'
        $result.Token | Should -Be 'Researcher Subagent'
    }

    It 'Keeps a top-level agent as agent-picker even when a path is provided' {
        $result = Get-AssetInvocation -Kind 'agent' -Name 'rpi-agent' -Frontmatter @{ name = 'RPI Agent' } -Path '.github/agents/hve-core/rpi-agent.agent.md'
        $result.Mechanism | Should -Be 'agent-picker'
    }
}

Describe 'Test-AssetInteractive' -Tag 'Unit' {
    It 'Treats agents as interactive' {
        Test-AssetInteractive -Kind 'agent' | Should -BeTrue
    }

    It 'Treats a delegated subagent as non-interactive' {
        Test-AssetInteractive -Kind 'agent' -Path '.github/agents/hve-core/subagents/researcher-subagent.agent.md' | Should -BeFalse
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

    It 'Reports no markers when a begin marker is duplicated before the end' {
        $content = @(
            'before'
            '<!-- BEGIN AUTO-GENERATED: metadata -->'
            'first'
            '<!-- BEGIN AUTO-GENERATED: metadata -->'
            'second'
            '<!-- END AUTO-GENERATED: metadata -->'
            'after'
        ) -join "`n"
        $split = Split-AssetDocByMarkers -Content $content -Region 'metadata'
        $split.HasMarkers | Should -BeFalse
        $split.Before | Should -Be $content
    }

    It 'Extracts identical segments when content uses CRLF line endings' {
        $lf = @(
            'before'
            '<!-- BEGIN AUTO-GENERATED: metadata -->'
            'BODY'
            '<!-- END AUTO-GENERATED: metadata -->'
            'after'
        ) -join "`n"
        $crlf = $lf -replace "`n", "`r`n"

        $lfSplit = Split-AssetDocByMarkers -Content $lf -Region 'metadata'
        $crlfSplit = Split-AssetDocByMarkers -Content $crlf -Region 'metadata'

        $crlfSplit.HasMarkers | Should -Be $lfSplit.HasMarkers
        $crlfSplit.Body | Should -Be $lfSplit.Body
        # Before/After retain their native line endings; the IndexOf offsets must
        # still land on the marker boundaries so the segments match after
        # normalizing CRLF back to LF.
        ($crlfSplit.Before -replace "`r`n", "`n") | Should -Be $lfSplit.Before
        ($crlfSplit.After -replace "`r`n", "`n") | Should -Be $lfSplit.After
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

    It 'Merges identically apart from line endings when the page uses CRLF' {
        $crlf = $script:doc -replace "`n", "`r`n"
        $lfMerged = Merge-AssetDocRegion -Content $script:doc -Region 'metadata' -Body 'new metadata'
        $crlfMerged = Merge-AssetDocRegion -Content $crlf -Region 'metadata' -Body 'new metadata'
        ($crlfMerged -replace "`r`n", "`n") | Should -Be $lfMerged
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

Describe 'Format-YamlScalar' -Tag 'Unit' {
    It 'Leaves a safe scalar unquoted' {
        Format-YamlScalar -Value 'Alpha Agent' | Should -Be 'Alpha Agent'
    }

    It 'Quotes values containing a colon' {
        Format-YamlScalar -Value 'Triage: draft VEX' | Should -Be '"Triage: draft VEX"'
    }

    It 'Escapes embedded double quotes' {
        Format-YamlScalar -Value 'say "hi"' | Should -Be '"say \"hi\""'
    }

    It 'Quotes an empty string' {
        Format-YamlScalar -Value '' | Should -Be '""'
    }
}

Describe 'ConvertTo-TableCell' -Tag 'Unit' {
    It 'Collapses line breaks to spaces' {
        ConvertTo-TableCell -Value ('line one' + "`n" + 'line two') | Should -Be 'line one line two'
    }

    It 'Escapes pipe characters' {
        ConvertTo-TableCell -Value 'a | b' | Should -Be 'a \| b'
    }

    It 'Collapses CRLF line breaks identically to LF' {
        $lf = 'line one' + "`n" + 'line two'
        $crlf = $lf -replace "`n", "`r`n"
        ConvertTo-TableCell -Value $crlf | Should -Be (ConvertTo-TableCell -Value $lf)
    }
}

Describe 'Format-AssetInvocation' -Tag 'Unit' {
    It 'Describes an agent picker invocation' {
        $text = Format-AssetInvocation -Invocation @{ Mechanism = 'agent-picker'; Token = 'RPI Agent' }
        $text | Should -Match 'chat agent picker'
        $text | Should -Match 'RPI Agent'
    }

    It 'Describes a slash command invocation' {
        Format-AssetInvocation -Invocation @{ Mechanism = 'slash-command'; Token = '/demo' } |
            Should -Match 'Slash command'
    }

    It 'Describes an auto-applied instruction with a glob' {
        Format-AssetInvocation -Invocation @{ Mechanism = 'auto-applied'; Token = '**/*.ps1' } |
            Should -Match 'Applied automatically to'
    }

    It 'Describes an auto-applied instruction without a glob' {
        Format-AssetInvocation -Invocation @{ Mechanism = 'auto-applied'; Token = '' } |
            Should -Be 'Applied automatically'
    }

    It 'Describes a skill load' {
        Format-AssetInvocation -Invocation @{ Mechanism = 'skill-load'; Token = 'documentation' } |
            Should -Match 'Loaded on demand'
    }

    It 'Describes a delegated subagent' {
        Format-AssetInvocation -Invocation @{ Mechanism = 'subagent-delegated'; Token = 'Researcher Subagent' } |
            Should -Match 'Delegated subagent'
    }
}

Describe 'New-AssetPageModel' -Tag 'Unit' {
    BeforeAll {
        $script:modelRepo = Join-Path $TestDrive 'page-model'
        $modelGh = Join-Path $script:modelRepo '.github'

        function script:New-ModelFixture {
            param([string]$RelativePath, [string[]]$Lines)
            $full = Join-Path $modelGh $RelativePath
            New-Item -ItemType Directory -Path (Split-Path $full -Parent) -Force | Out-Null
            Set-Content -LiteralPath $full -Value ($Lines -join "`n") -Encoding utf8NoBOM
        }

        New-ModelFixture -RelativePath 'agents/hve-core/demo.agent.md' -Lines @(
            '---', 'name: Demo Agent', 'description: A demo agent for tests.', '---', '', '# Body')
        New-ModelFixture -RelativePath 'prompts/hve-core/demo-prompt.prompt.md' -Lines @(
            '---', 'description: A demo prompt for tests.', '---', '', '# Body')
        New-ModelFixture -RelativePath 'skills/hve-core/demo-skill/SKILL.md' -Lines @(
            '---', 'name: demo-skill', 'description: A demo skill for tests.', '---', '', '# Body')
        New-ModelFixture -RelativePath 'agents/hve-core/subagents/demo-sub.agent.md' -Lines @(
            '---', 'name: Demo Subagent', 'description: A demo subagent for tests.', '---', '', '# Body')
    }

    It 'Resolves the full page model for an agent' {
        $model = New-AssetPageModel -Asset @{ path = '.github/agents/hve-core/demo.agent.md'; kind = 'agent' } -RepoRoot $script:modelRepo
        $model.Kind | Should -Be 'agent'
        $model.Key | Should -Be 'demo'
        $model.Title | Should -Be 'Demo Agent'
        $model.Description | Should -Be 'A demo agent for tests.'
        $model.SourceRel | Should -Be '.github/agents/hve-core/demo.agent.md'
        $model.DocRel | Should -Be 'docs/reference/agents/hve-core/demo.md'
        $model.Folder | Should -Be 'docs/reference/agents/hve-core'
        $model.KindDir | Should -Be 'agents'
        $model.Invocation.Mechanism | Should -Be 'agent-picker'
        $model.Invocation.Token | Should -Be 'Demo Agent'
        $model.Interactive | Should -BeTrue
    }

    It 'Classifies a nested subagent as delegated and non-interactive' {
        $model = New-AssetPageModel -Asset @{ path = '.github/agents/hve-core/subagents/demo-sub.agent.md'; kind = 'agent' } -RepoRoot $script:modelRepo
        $model.Invocation.Mechanism | Should -Be 'subagent-delegated'
        $model.Invocation.Token | Should -Be 'Demo Subagent'
        $model.Interactive | Should -BeFalse
        $model.DocRel | Should -Be 'docs/reference/agents/hve-core/subagents/demo-sub.md'
    }

    It 'Falls back to a titlecased key when frontmatter has no name or title' {
        $model = New-AssetPageModel -Asset @{ path = '.github/prompts/hve-core/demo-prompt.prompt.md'; kind = 'prompt' } -RepoRoot $script:modelRepo
        $model.Key | Should -Be 'demo-prompt'
        $model.Title | Should -Be 'Demo Prompt'
        $model.Interactive | Should -BeFalse
    }

    It 'Reads SKILL.md and derives the skill page model' {
        $model = New-AssetPageModel -Asset @{ path = '.github/skills/hve-core/demo-skill'; kind = 'skill' } -RepoRoot $script:modelRepo
        $model.Key | Should -Be 'demo-skill'
        $model.Title | Should -Be 'demo-skill'
        $model.Description | Should -Be 'A demo skill for tests.'
        $model.DocRel | Should -Be 'docs/reference/skills/hve-core/demo-skill.md'
        $model.KindDir | Should -Be 'skills'
    }
}

Describe 'New-AssetMetadataBlock' -Tag 'Unit' {
    It 'Builds a metadata table with all rows' {
        $block = New-AssetMetadataBlock -Kind 'agent' -SourcePath '.github/agents/hve-core/demo.agent.md' -Invocation @{ Mechanism = 'agent-picker'; Token = 'Demo' } -Interactive $true
        $block | Should -Match '(?m)^\| Kind\s+\| agent\s+\|$'
        $block | Should -Match 'agents/hve-core/demo\.agent\.md'
        $block | Should -Match '(?m)^\| Interactive\s+\| Yes\s+\|$'
    }
}

Describe 'New-AssetOverviewBody' -Tag 'Unit' {
    It 'Collapses a multi-line description to a single trimmed line' {
        $model = [PSCustomObject]@{ Description = "First line`nSecond line" }
        New-AssetOverviewBody -Model $model | Should -Be 'First line Second line'
    }

    It 'Trims surrounding whitespace' {
        $model = [PSCustomObject]@{ Description = '  padded description  ' }
        New-AssetOverviewBody -Model $model | Should -Be 'padded description'
    }

    It 'Returns a fallback sentence when the description is empty' {
        $model = [PSCustomObject]@{ Description = '' }
        New-AssetOverviewBody -Model $model | Should -Be 'This asset does not declare a description.'
    }

    It 'Returns a fallback sentence when the description is whitespace only' {
        $model = [PSCustomObject]@{ Description = "   `n  " }
        New-AssetOverviewBody -Model $model | Should -Be 'This asset does not declare a description.'
    }
}
