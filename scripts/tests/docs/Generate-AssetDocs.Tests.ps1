#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../docs/Generate-AssetDocs.ps1')
    $script:TemplatePath = (Resolve-Path (Join-Path $PSScriptRoot '../../docs/templates/asset-doc.template.md')).Path

    $script:fixtureRepoCounter = 0
    function script:New-AssetFixtureRepo {
        param([string]$Newline = "`n")

        $script:fixtureRepoCounter++
        $repo = Join-Path $TestDrive "asset-fixture-$($script:fixtureRepoCounter)"
        $gh = Join-Path $repo '.github'

        $fixtures = @{
            'agents/hve-core/alpha-agent.agent.md'          = @('---', 'name: Alpha Agent', 'description: The first demo agent.', '---', '', '# Body')
            'agents/hve-core/zulu-agent.agent.md'           = @('---', 'name: Zulu Agent', 'description: The last demo agent.', '---', '', '# Body')
            'agents/hve-core/subagents/nested-sub.agent.md' = @('---', 'name: Nested Sub', 'description: A nested subagent.', '---', '', '# Body')
            'prompts/hve-core/demo.prompt.md'               = @('---', 'name: demo', 'description: A demo prompt.', 'argument-hint: "input=path"', '---', '', '# Body')
            'instructions/shared/demo.instructions.md'      = @('---', 'description: Demo instructions.', 'applyTo: "**/*.ps1"', '---', '', '# Body')
            'skills/hve-core/demo-skill/SKILL.md'           = @('---', 'name: demo-skill', 'description: A demo skill.', '---', '', '# Body')
        }

        foreach ($rel in $fixtures.Keys) {
            $full = Join-Path $gh $rel
            New-Item -ItemType Directory -Path (Split-Path $full -Parent) -Force | Out-Null
            Set-Content -LiteralPath $full -Value ($fixtures[$rel] -join $Newline) -Encoding utf8NoBOM -NoNewline
        }

        return $repo
    }

    function script:Get-SidebarPosition {
        param([string]$Path)
        $content = Get-Content -LiteralPath $Path -Raw
        return [int]([regex]::Match($content, '(?m)^sidebar_position:\s*(\d+)').Groups[1].Value)
    }
}

AfterAll {
    Remove-Module DocsHelpers, CollectionHelpers -Force -ErrorAction SilentlyContinue
}

Describe 'Invoke-AssetDocsGeneration - scaffolding' -Tag 'Unit' {
    BeforeAll {
        $script:repo = New-AssetFixtureRepo
        $script:result = Invoke-AssetDocsGeneration -RepoRoot $script:repo -TemplatePath $script:TemplatePath
    }

    It 'Creates one page per documentable asset plus index pages' {
        # 6 asset pages + 4 per-kind index pages + 1 root index = 11
        $script:result.Created.Count | Should -Be 11
        $script:result.Updated.Count | Should -Be 0
        $script:result.Unchanged.Count | Should -Be 0
    }

    It 'Scaffolds an asset page for each kind' {
        $script:result.Created | Should -Contain 'docs/reference/agents/hve-core/alpha-agent.md'
        $script:result.Created | Should -Contain 'docs/reference/prompts/hve-core/demo.md'
        $script:result.Created | Should -Contain 'docs/reference/instructions/shared/demo.md'
        $script:result.Created | Should -Contain 'docs/reference/skills/hve-core/demo-skill.md'
    }

    It 'Preserves nested subagent hierarchy' {
        $expected = Join-Path $script:repo 'docs/reference/agents/hve-core/subagents/nested-sub.md'
        Test-Path -LiteralPath $expected | Should -BeTrue
    }

    It 'Generates the root and per-kind index pages' {
        Test-Path -LiteralPath (Join-Path $script:repo 'docs/reference/README.md') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $script:repo 'docs/reference/agents/README.md') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $script:repo 'docs/reference/skills/README.md') | Should -BeTrue
    }

    It 'Writes required frontmatter fields to each page' {
        $content = Get-Content -LiteralPath (Join-Path $script:repo 'docs/reference/agents/hve-core/alpha-agent.md') -Raw
        $content | Should -Match '(?m)^title: Alpha Agent$'
        $content | Should -Match '(?m)^description: '
        $content | Should -Match '(?m)^sidebar_position: \d+$'
        $content | Should -Match '(?m)^ms\.date: \d{4}-\d{2}-\d{2}$'
    }

    It 'Lists assets in the per-kind index with relative links' {
        $content = Get-Content -LiteralPath (Join-Path $script:repo 'docs/reference/agents/README.md') -Raw
        $content | Should -Match 'hve-core/alpha-agent\.md'
    }

    It 'Lists categories with counts in the root index' {
        $content = Get-Content -LiteralPath (Join-Path $script:repo 'docs/reference/README.md') -Raw
        $content | Should -Match 'agents/README\.md'
    }
}

Describe 'Invoke-AssetDocsGeneration - stable sidebar positions' -Tag 'Unit' {
    BeforeAll {
        $script:repo = New-AssetFixtureRepo
        Invoke-AssetDocsGeneration -RepoRoot $script:repo -TemplatePath $script:TemplatePath | Out-Null
    }

    It 'Assigns sibling positions alphabetically' {
        $alpha = Get-SidebarPosition -Path (Join-Path $script:repo 'docs/reference/agents/hve-core/alpha-agent.md')
        $zulu = Get-SidebarPosition -Path (Join-Path $script:repo 'docs/reference/agents/hve-core/zulu-agent.md')
        $alpha | Should -Be 1
        $zulu | Should -Be 2
    }

    It 'Keeps positions stable across regeneration' {
        Invoke-AssetDocsGeneration -RepoRoot $script:repo -TemplatePath $script:TemplatePath | Out-Null
        Get-SidebarPosition -Path (Join-Path $script:repo 'docs/reference/agents/hve-core/alpha-agent.md') | Should -Be 1
        Get-SidebarPosition -Path (Join-Path $script:repo 'docs/reference/agents/hve-core/zulu-agent.md') | Should -Be 2
    }
}

Describe 'Invoke-AssetDocsGeneration - idempotency' -Tag 'Unit' {
    BeforeAll {
        $script:repo = New-AssetFixtureRepo
        Invoke-AssetDocsGeneration -RepoRoot $script:repo -TemplatePath $script:TemplatePath | Out-Null
        $script:second = Invoke-AssetDocsGeneration -RepoRoot $script:repo -TemplatePath $script:TemplatePath
    }

    It 'Writes nothing on a second run' {
        $script:second.Created.Count | Should -Be 0
        $script:second.Updated.Count | Should -Be 0
        $script:second.DriftCount | Should -Be 0
    }

    It 'Reports every page as unchanged' {
        $script:second.Unchanged.Count | Should -Be 11
    }
}

Describe 'Invoke-AssetDocsGeneration - CRLF source assets' -Tag 'Unit' {
    BeforeAll {
        $script:lfRepo = New-AssetFixtureRepo
        $script:crlfRepo = New-AssetFixtureRepo -Newline "`r`n"

        $script:lfResult = Invoke-AssetDocsGeneration -RepoRoot $script:lfRepo -TemplatePath $script:TemplatePath
        $script:crlfResult = Invoke-AssetDocsGeneration -RepoRoot $script:crlfRepo -TemplatePath $script:TemplatePath
    }

    It 'Creates the same set of pages regardless of source line endings' {
        ($script:crlfResult.Created | Sort-Object) | Should -Be ($script:lfResult.Created | Sort-Object)
        $script:crlfResult.Updated.Count | Should -Be 0
        $script:crlfResult.Unchanged.Count | Should -Be 0
    }

    It 'Generates byte-identical page content from CRLF and LF sources' {
        foreach ($rel in $script:lfResult.Created) {
            $lfContent = Get-Content -LiteralPath (Join-Path $script:lfRepo $rel) -Raw
            $crlfContent = Get-Content -LiteralPath (Join-Path $script:crlfRepo $rel) -Raw
            $crlfContent | Should -Be $lfContent -Because "generated page '$rel' must not depend on source line endings"
        }
    }

    It 'Reports every page as unchanged on a second run over CRLF sources' {
        $second = Invoke-AssetDocsGeneration -RepoRoot $script:crlfRepo -TemplatePath $script:TemplatePath
        $second.Created.Count | Should -Be 0
        $second.Updated.Count | Should -Be 0
        $second.DriftCount | Should -Be 0
        $second.Unchanged.Count | Should -Be $script:crlfResult.Created.Count
    }
}

Describe 'Invoke-AssetDocsGeneration - ms.date last-modified semantics' -Tag 'Unit' {
    BeforeAll {
        function script:Get-PageMsDate {
            param([string]$Path)
            $content = Get-Content -LiteralPath $Path -Raw
            return [regex]::Match($content, '(?m)^ms\.date:\s*(\S+)').Groups[1].Value
        }

        function script:Set-PageMsDate {
            param([string]$Path, [string]$Date)
            $content = Get-Content -LiteralPath $Path -Raw
            Set-Content -LiteralPath $Path -Value ($content -replace '(?m)^ms\.date:.*$', "ms.date: $Date") -Encoding utf8NoBOM -NoNewline
        }

        $script:today = Get-Date -Format 'yyyy-MM-dd'
        $script:pageRel = 'docs/reference/agents/hve-core/alpha-agent.md'
    }

    It 'Preserves ms.date when regeneration produces identical content' {
        $repo = New-AssetFixtureRepo
        Invoke-AssetDocsGeneration -RepoRoot $repo -TemplatePath $script:TemplatePath | Out-Null

        $page = Join-Path $repo $script:pageRel
        Set-PageMsDate -Path $page -Date '2020-01-01'

        $result = Invoke-AssetDocsGeneration -RepoRoot $repo -TemplatePath $script:TemplatePath
        $result.Updated | Should -Not -Contain $script:pageRel
        Get-PageMsDate -Path $page | Should -Be '2020-01-01'
    }

    It 'Advances ms.date to today when a generated region changes' {
        $repo = New-AssetFixtureRepo
        Invoke-AssetDocsGeneration -RepoRoot $repo -TemplatePath $script:TemplatePath | Out-Null

        $page = Join-Path $repo $script:pageRel
        Set-PageMsDate -Path $page -Date '2020-01-01'

        # Change the source asset description so the overview and frontmatter differ.
        $source = Join-Path $repo '.github/agents/hve-core/alpha-agent.agent.md'
        Set-Content -LiteralPath $source -Value (@(
                '---'
                'name: Alpha Agent'
                'description: An updated description for the first demo agent.'
                '---'
                ''
                '# Body'
            ) -join "`n") -Encoding utf8NoBOM -NoNewline

        $result = Invoke-AssetDocsGeneration -RepoRoot $repo -TemplatePath $script:TemplatePath
        $result.Updated | Should -Contain $script:pageRel
        Get-PageMsDate -Path $page | Should -Be $script:today
    }

    It 'Does not advance ms.date when only a human section changes' {
        $repo = New-AssetFixtureRepo
        Invoke-AssetDocsGeneration -RepoRoot $repo -TemplatePath $script:TemplatePath | Out-Null

        $page = Join-Path $repo $script:pageRel
        Set-PageMsDate -Path $page -Date '2020-01-01'
        $edited = (Get-Content -LiteralPath $page -Raw) -replace 'Describe the situations[^\n]*', 'HUMAN EDIT.'
        Set-Content -LiteralPath $page -Value $edited -Encoding utf8NoBOM -NoNewline

        $result = Invoke-AssetDocsGeneration -RepoRoot $repo -TemplatePath $script:TemplatePath
        $result.Updated | Should -Not -Contain $script:pageRel
        Get-PageMsDate -Path $page | Should -Be '2020-01-01'
    }

    It 'Advances index ms.date to today when the asset list changes' {
        $repo = New-AssetFixtureRepo
        Invoke-AssetDocsGeneration -RepoRoot $repo -TemplatePath $script:TemplatePath | Out-Null

        $index = Join-Path $repo 'docs/reference/agents/README.md'
        Set-PageMsDate -Path $index -Date '2020-01-01'

        # Add a new agent so the agents index region changes.
        $newAgent = Join-Path $repo '.github/agents/hve-core/mike-agent.agent.md'
        Set-Content -LiteralPath $newAgent -Value (@(
                '---'
                'name: Mike Agent'
                'description: A newly added agent.'
                '---'
                ''
                '# Body'
            ) -join "`n") -Encoding utf8NoBOM -NoNewline

        $result = Invoke-AssetDocsGeneration -RepoRoot $repo -TemplatePath $script:TemplatePath
        $result.Updated | Should -Contain 'docs/reference/agents/README.md'
        Get-PageMsDate -Path $index | Should -Be $script:today
    }
}

Describe 'Invoke-AssetDocsGeneration - human section preservation' -Tag 'Unit' {
    BeforeAll {
        $script:repo = New-AssetFixtureRepo
        Invoke-AssetDocsGeneration -RepoRoot $script:repo -TemplatePath $script:TemplatePath | Out-Null

        $script:page = Join-Path $script:repo 'docs/reference/agents/hve-core/alpha-agent.md'
        $edited = (Get-Content -LiteralPath $script:page -Raw) -replace 'Describe the situations[^\n]*', 'MY CUSTOM HUMAN CONTENT.'
        Set-Content -LiteralPath $script:page -Value $edited -Encoding utf8NoBOM -NoNewline

        $script:result = Invoke-AssetDocsGeneration -RepoRoot $script:repo -TemplatePath $script:TemplatePath
    }

    It 'Does not rewrite pages when only human sections changed' {
        $script:result.Updated | Should -Not -Contain 'docs/reference/agents/hve-core/alpha-agent.md'
    }

    It 'Preserves the human-authored edit' {
        (Get-Content -LiteralPath $script:page -Raw) | Should -Match 'MY CUSTOM HUMAN CONTENT\.'
    }

    It 'Refreshes the auto-generated regions while preserving human sections' {
        $content = Get-Content -LiteralPath $script:page -Raw
        $content | Should -Match '<!-- BEGIN AUTO-GENERATED: metadata -->'
        $content | Should -Match 'MY CUSTOM HUMAN CONTENT\.'
    }
}

Describe 'Invoke-AssetDocsGeneration - missing overview markers' -Tag 'Unit' {
    BeforeAll {
        $script:repo = New-AssetFixtureRepo
        Invoke-AssetDocsGeneration -RepoRoot $script:repo -TemplatePath $script:TemplatePath | Out-Null

        $script:page = Join-Path $script:repo 'docs/reference/agents/hve-core/alpha-agent.md'
        # Remove the overview markers but keep hand-authored prose in a human section.
        $mangled = (Get-Content -LiteralPath $script:page -Raw) `
            -replace '<!-- BEGIN AUTO-GENERATED: overview -->', '' `
            -replace '<!-- END AUTO-GENERATED: overview -->', '' `
            -replace 'Describe the situations[^\n]*', 'IRREPLACEABLE HUMAN CONTENT.'
        Set-Content -LiteralPath $script:page -Value $mangled -Encoding utf8NoBOM -NoNewline
        $script:before = Get-Content -LiteralPath $script:page -Raw

        $script:result = Invoke-AssetDocsGeneration -RepoRoot $script:repo -TemplatePath $script:TemplatePath
    }

    It 'Skips the page instead of overwriting it and flags it as needing attention' {
        $script:result.Updated | Should -Not -Contain 'docs/reference/agents/hve-core/alpha-agent.md'
        $script:result.NeedsAttention | Should -Contain 'docs/reference/agents/hve-core/alpha-agent.md'
    }

    It 'Preserves the human-authored content byte-for-byte' {
        (Get-Content -LiteralPath $script:page -Raw) | Should -Be $script:before
        (Get-Content -LiteralPath $script:page -Raw) | Should -Match 'IRREPLACEABLE HUMAN CONTENT\.'
    }

    It 'Counts the skipped page as drift' {
        $script:result.DriftCount | Should -BeGreaterThan 0
    }

    It 'New-AssetDocContent throws directly when overview markers are missing' {
        $model = Get-DocumentableAssets -RepoRoot $script:repo |
            Where-Object { $_.path -eq '.github/agents/hve-core/alpha-agent.agent.md' } |
                ForEach-Object { New-AssetPageModel -Asset $_ -RepoRoot $script:repo }
        { New-AssetDocContent -Model $model -RepoRoot $script:repo -TemplatePath $script:TemplatePath -SidebarPosition 1 } |
            Should -Throw
    }
}

Describe 'Invoke-AssetDocsGeneration - interactivity' -Tag 'Unit' {
    BeforeAll {
        $script:repo = New-AssetFixtureRepo
        Invoke-AssetDocsGeneration -RepoRoot $script:repo -TemplatePath $script:TemplatePath | Out-Null
    }

    It 'Keeps the How to use section for interactive assets' {
        $content = Get-Content -LiteralPath (Join-Path $script:repo 'docs/reference/prompts/hve-core/demo.md') -Raw
        $content | Should -Match '## How to use it'
        $content | Should -Match '(?m)^\| Interactive\s+\| Yes\s+\|$'
    }

    It 'Strips the How to use section for non-interactive assets' {
        $content = Get-Content -LiteralPath (Join-Path $script:repo 'docs/reference/instructions/shared/demo.md') -Raw
        $content | Should -Not -Match '## How to use it'
        $content | Should -Match '(?m)^\| Interactive\s+\| No\s+\|$'
    }

    It 'Renders a subagent as a delegated, non-interactive page' {
        $content = Get-Content -LiteralPath (Join-Path $script:repo 'docs/reference/agents/hve-core/subagents/nested-sub.md') -Raw
        $content | Should -Match 'Delegated subagent'
        $content | Should -Match '(?m)^\| Interactive\s+\| No\s+\|$'
        $content | Should -Not -Match '## How to use it'
    }
}

Describe 'Invoke-AssetDocsGeneration - WhatIf' -Tag 'Unit' {
    BeforeAll {
        $script:repo = New-AssetFixtureRepo
        $script:result = Invoke-AssetDocsGeneration -RepoRoot $script:repo -TemplatePath $script:TemplatePath -WhatIf
    }

    It 'Reports drift without writing files' {
        $script:result.DriftCount | Should -BeGreaterThan 0
        $script:result.WhatIf | Should -BeTrue
    }

    It 'Does not create any documentation pages' {
        $docsDir = Join-Path $script:repo 'docs/reference'
        $count = (Get-ChildItem -LiteralPath $docsDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
        $count | Should -Be 0
    }
}

Describe 'New-DocFrontmatter' -Tag 'Unit' {
    It 'Emits all required frontmatter fields' {
        $fm = New-DocFrontmatter -Title 'Demo' -Description 'A demo.' -SidebarPosition 3 -MsDate '2026-07-02'
        $fm | Should -Match '(?m)^title: Demo$'
        $fm | Should -Match '(?m)^description: A demo\.$'
        $fm | Should -Match '(?m)^sidebar_position: 3$'
        $fm | Should -Match '(?m)^ms\.date: 2026-07-02$'
    }
}

Describe 'Remove-HowToUseSection' -Tag 'Unit' {
    It 'Removes the How to use section but keeps Example usage' {
        $tail = @(
            ''
            '## When to use it'
            ''
            'Use it here.'
            ''
            '## How to use it'
            ''
            'Steps here.'
            ''
            '## Example usage'
            ''
            'An example.'
        ) -join "`n"
        $result = Remove-HowToUseSection -Tail $tail
        $result | Should -Not -Match '## How to use it'
        $result | Should -Match '## When to use it'
        $result | Should -Match '## Example usage'
    }

    It 'Removes the How to use section when it is the last H2' {
        $tail = @(
            ''
            '## When to use it'
            ''
            'Use it here.'
            ''
            '## How to use it'
            ''
            'Steps here.'
        ) -join "`n"
        $result = Remove-HowToUseSection -Tail $tail
        $result | Should -Not -Match '## How to use it'
        $result | Should -Match '## When to use it'
    }

    It 'Removes the How to use section identically when the tail uses CRLF' {
        $lfTail = @(
            ''
            '## When to use it'
            ''
            'Use it here.'
            ''
            '## How to use it'
            ''
            'Steps here.'
            ''
            '## Example usage'
            ''
            'An example.'
        ) -join "`n"
        $crlfTail = $lfTail -replace "`n", "`r`n"
        $lfResult = Remove-HowToUseSection -Tail $lfTail
        $crlfResult = Remove-HowToUseSection -Tail $crlfTail
        ($crlfResult -replace "`r`n", "`n") | Should -Be $lfResult
    }

    It 'Removes a trailing How to use section identically when the tail uses CRLF' {
        # Exercises the \z end-of-string branch of the lookahead under CRLF.
        $lfTail = @(
            ''
            '## When to use it'
            ''
            'Use it here.'
            ''
            '## How to use it'
            ''
            'Steps here.'
        ) -join "`n"
        $crlfTail = $lfTail -replace "`n", "`r`n"
        $lfResult = Remove-HowToUseSection -Tail $lfTail
        $crlfResult = Remove-HowToUseSection -Tail $crlfTail
        ($crlfResult -replace "`r`n", "`n") | Should -Be $lfResult
    }
}

Describe 'Write-DocIfChanged' -Tag 'Unit' {
    It 'Creates a new file and reports Created' {
        $path = Join-Path $TestDrive 'new-page.md'
        $status = Write-DocIfChanged -Path $path -Content "hello`n"
        $status | Should -Be 'Created'
        (Get-Content -LiteralPath $path -Raw) | Should -Be "hello`n"
    }

    It 'Reports Unchanged when content matches' {
        $path = Join-Path $TestDrive 'same-page.md'
        Set-Content -LiteralPath $path -Value "same`n" -Encoding utf8NoBOM -NoNewline
        Write-DocIfChanged -Path $path -Content "same`n" | Should -Be 'Unchanged'
    }

    It 'Reports Updated when content differs' {
        $path = Join-Path $TestDrive 'diff-page.md'
        Set-Content -LiteralPath $path -Value "old`n" -Encoding utf8NoBOM -NoNewline
        Write-DocIfChanged -Path $path -Content "new`n" | Should -Be 'Updated'
        (Get-Content -LiteralPath $path -Raw) | Should -Be "new`n"
    }

    It 'Does not write under WhatIf' {
        $path = Join-Path $TestDrive 'whatif-page.md'
        $status = Write-DocIfChanged -Path $path -Content "content`n" -WhatIf
        $status | Should -Be 'Created'
        Test-Path -LiteralPath $path | Should -BeFalse
    }
}
