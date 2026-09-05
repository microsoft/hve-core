#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../docs/Generate-AssetDocs.ps1')
    $script:TemplatePath = (Resolve-Path (Join-Path $PSScriptRoot '../../docs/templates/asset-doc.template.md')).Path
    $script:FixtureCounter = 0

    # Six package-scoped assets across four documentable kinds, plus one
    # root-level repo-specific agent that must never receive a page.
    $script:ExpectedAssetPages = @(
        'docs/reference/agents/hve-core/alpha-agent.md'
        'docs/reference/agents/hve-core/subagents/nested-sub.md'
        'docs/reference/agents/hve-core/zulu-agent.md'
        'docs/reference/instructions/shared/demo.md'
        'docs/reference/prompts/hve-core/demo.md'
        'docs/reference/skills/hve-core/demo-skill.md'
    )
    $script:ExpectedIndexPages = @(
        'docs/reference/README.md'
        'docs/reference/agents/README.md'
        'docs/reference/instructions/README.md'
        'docs/reference/prompts/README.md'
        'docs/reference/skills/README.md'
    )

    function script:New-AssetFixtureRepo {
        param([string]$Newline = "`n")

        $script:FixtureCounter++
        $repo = Join-Path $TestDrive "asset-fixture-$($script:FixtureCounter)"

        $fixtures = @{
            '.github/agents/hve-core/alpha-agent.agent.md'          = @('---', 'name: Alpha Agent', 'description: The first demo agent.', '---', '', '# Body')
            '.github/agents/hve-core/zulu-agent.agent.md'           = @('---', 'name: Zulu Agent', 'description: The last demo agent.', '---', '', '# Body')
            '.github/agents/hve-core/subagents/nested-sub.agent.md' = @('---', 'name: Nested Sub', 'description: A delegated demo subagent.', '---', '', '# Body')
            '.github/prompts/hve-core/demo.prompt.md'               = @('---', 'description: A demo prompt.', 'argument-hint: "input=path"', '---', '', '# Body')
            '.github/instructions/shared/demo.instructions.md'      = @('---', 'description: Demo instructions.', 'applyTo: "**/*.ps1"', '---', '', '# Body')
            '.github/skills/hve-core/demo-skill/SKILL.md'           = @('---', 'name: demo-skill', 'description: A demo skill.', '---', '', '# Body')
            '.github/agents/repo-only.agent.md'                     = @('---', 'name: Repo Only', 'description: A root-level repository agent.', '---', '', '# Body')
        }

        foreach ($rel in $fixtures.Keys) {
            $full = Join-Path $repo $rel
            New-Item -ItemType Directory -Path (Split-Path $full -Parent) -Force | Out-Null
            Set-Content -LiteralPath $full -Value ($fixtures[$rel] -join $Newline) -Encoding utf8NoBOM -NoNewline
        }

        return $repo
    }

    function script:Get-SourceSnapshot {
        param([string]$RepoRoot)

        $gitHub = Join-Path $RepoRoot '.github'
        return @(Get-ChildItem -LiteralPath $gitHub -Recurse -File |
                Sort-Object FullName |
                ForEach-Object { "$([System.IO.Path]::GetRelativePath($RepoRoot, $_.FullName))|$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)" })
    }

    function script:Get-PageField {
        param([string]$Path, [string]$Field)

        $content = Get-Content -LiteralPath $Path -Raw
        return [regex]::Match($content, "(?m)^$([regex]::Escape($Field)):\s*(.+?)\s*$").Groups[1].Value
    }
}

Describe 'Invoke-AssetDocsGeneration scaffolding' -Tag 'Unit' {
    BeforeAll {
        $script:repo = New-AssetFixtureRepo
        $script:result = Invoke-AssetDocsGeneration -RepoRoot $script:repo -TemplatePath $script:TemplatePath
    }

    It 'Creates one page per package-scoped asset plus the index pages' {
        @($script:result.Created | Sort-Object) | Should -Be @(($script:ExpectedAssetPages + $script:ExpectedIndexPages) | Sort-Object)
        $script:result.Updated.Count | Should -Be 0
        $script:result.Unchanged.Count | Should -Be 0
        $script:result.NeedsAttention.Count | Should -Be 0
    }

    It 'Creates no page for a root-level repository asset' {
        $script:result.Created | Should -Not -Contain 'docs/reference/agents/repo-only.md'
        Test-Path -LiteralPath (Join-Path $script:repo 'docs/reference/agents/repo-only.md') | Should -BeFalse
    }

    It 'Writes the frontmatter contract to each asset page' {
        $page = Join-Path $script:repo 'docs/reference/agents/hve-core/alpha-agent.md'

        Get-PageField -Path $page -Field 'title' | Should -Be 'Alpha Agent'
        Get-PageField -Path $page -Field 'description' | Should -Be 'The first demo agent.'
        Get-PageField -Path $page -Field 'sidebar_position' | Should -Be '1'
        Get-PageField -Path $page -Field 'ms.date' | Should -Be (Get-Date -Format 'yyyy-MM-dd')
    }

    It 'Assigns sibling sidebar positions alphabetically within a package folder' {
        Get-PageField -Path (Join-Path $script:repo 'docs/reference/agents/hve-core/alpha-agent.md') -Field 'sidebar_position' | Should -Be '1'
        Get-PageField -Path (Join-Path $script:repo 'docs/reference/agents/hve-core/zulu-agent.md') -Field 'sidebar_position' | Should -Be '2'
        Get-PageField -Path (Join-Path $script:repo 'docs/reference/agents/hve-core/subagents/nested-sub.md') -Field 'sidebar_position' | Should -Be '1'
    }

    It 'Writes both generated regions with the resolved asset metadata' {
        $content = Get-Content -LiteralPath (Join-Path $script:repo 'docs/reference/agents/hve-core/alpha-agent.md') -Raw

        $metadata = Split-AssetDocByMarkers -Content $content -Region 'metadata'
        $metadata.HasMarkers | Should -BeTrue
        $metadata.Body | Should -Match '(?m)^\| Kind\s+\| agent\s+\|$'
        $metadata.Body | Should -Match '(?m)^\| Source\s+\| `\.github/agents/hve-core/alpha-agent\.agent\.md`\s+\|$'
        $metadata.Body | Should -Match 'Selected from the chat agent picker as `Alpha Agent`'
        $metadata.Body | Should -Match '(?m)^\| Interactive\s+\| Yes\s+\|$'

        $overview = Split-AssetDocByMarkers -Content $content -Region 'overview'
        $overview.HasMarkers | Should -BeTrue
        $overview.Body | Should -Be 'The first demo agent.'
    }

    It 'Links each asset page from its per-kind index using a package-relative path' {
        $index = Get-Content -LiteralPath (Join-Path $script:repo 'docs/reference/agents/README.md') -Raw

        $index | Should -Match '\[Alpha Agent\]\(hve-core/alpha-agent\.md\)'
        $index | Should -Match '\[Nested Sub\]\(hve-core/subagents/nested-sub\.md\)'
        $index | Should -Not -Match 'repo-only'
    }

    It 'Lists each kind with its asset count in the root index' {
        $index = Get-Content -LiteralPath (Join-Path $script:repo 'docs/reference/README.md') -Raw

        $index | Should -Match '\[Agents\]\(agents/README\.md\)\s*\|\s*3\s*\|'
        $index | Should -Match '\[Instructions\]\(instructions/README\.md\)\s*\|\s*1\s*\|'
        $index | Should -Match '\[Prompts\]\(prompts/README\.md\)\s*\|\s*1\s*\|'
        $index | Should -Match '\[Skills\]\(skills/README\.md\)\s*\|\s*1\s*\|'
    }

    It 'Uses package terminology and no collection wording in generated output' {
        foreach ($rel in ($script:ExpectedAssetPages + $script:ExpectedIndexPages)) {
            (Get-Content -LiteralPath (Join-Path $script:repo $rel) -Raw) | Should -Not -Match '(?i)collection' -Because "generated page '$rel' must not reintroduce collection vocabulary"
        }
    }
}

Describe 'Invoke-AssetDocsGeneration human sections' -Tag 'Unit' {
    BeforeAll {
        $script:repo = New-AssetFixtureRepo
        Invoke-AssetDocsGeneration -RepoRoot $script:repo -TemplatePath $script:TemplatePath | Out-Null
    }

    It 'Scaffolds the How to use it section for an interactive asset' {
        $content = Get-Content -LiteralPath (Join-Path $script:repo 'docs/reference/agents/hve-core/alpha-agent.md') -Raw

        @([regex]::Matches($content, '(?m)^## .+$').Value) | Should -Be @(
            '## What it does'
            '## When to use it'
            '## How to use it'
            '## Example usage'
        )
    }

    It 'Omits the How to use it section for a delegated subagent' {
        $content = Get-Content -LiteralPath (Join-Path $script:repo 'docs/reference/agents/hve-core/subagents/nested-sub.md') -Raw

        @([regex]::Matches($content, '(?m)^## .+$').Value) | Should -Be @(
            '## What it does'
            '## When to use it'
            '## Example usage'
        )
    }

    It 'Omits the How to use it section for passive instructions and skills' {
        foreach ($rel in @('docs/reference/instructions/shared/demo.md', 'docs/reference/skills/hve-core/demo-skill.md')) {
            (Get-Content -LiteralPath (Join-Path $script:repo $rel) -Raw) | Should -Not -Match '(?m)^## How to use it$'
        }
    }

    It 'Marks every scaffolded human section as an unwritten stub' {
        Test-AssetDocStub -Content (Get-Content -LiteralPath (Join-Path $script:repo 'docs/reference/prompts/hve-core/demo.md') -Raw) | Should -BeTrue
    }

    It 'Keeps output headings out of the scaffold body template' {
        Get-Content -LiteralPath $script:TemplatePath -Raw | Should -Not -Match '(?m)^## '
    }

    It 'Preserves an authored human tail while refreshing the generated regions' {
        $pageRel = 'docs/reference/agents/hve-core/alpha-agent.md'
        $page = Join-Path $script:repo $pageRel
        $authored = "`n`n## When to use it`n`nUse Alpha Agent when the demo needs a first agent.`n`n## Example usage`n`nAuthored example.`n"
        $original = Get-Content -LiteralPath $page -Raw
        $split = Split-AssetDocByMarkers -Content $original -Region 'overview'
        Set-Content -LiteralPath $page -Value ("$($split.Before)$(New-AssetGeneratedRegion -Region 'overview' -Body $split.Body)$authored") -Encoding utf8NoBOM -NoNewline

        $sourcePath = Join-Path $script:repo '.github/agents/hve-core/alpha-agent.agent.md'
        Set-Content -LiteralPath $sourcePath -Value (@('---', 'name: Alpha Agent', 'description: A revised first demo agent.', '---', '', '# Body') -join "`n") -Encoding utf8NoBOM -NoNewline

        $result = Invoke-AssetDocsGeneration -RepoRoot $script:repo -TemplatePath $script:TemplatePath
        $result.Updated | Should -Contain $pageRel

        $updated = Get-Content -LiteralPath $page -Raw
        (Split-AssetDocByMarkers -Content $updated -Region 'overview').Body | Should -Be 'A revised first demo agent.'
        (Split-AssetDocByMarkers -Content $updated -Region 'overview').After | Should -Be $authored
        Test-AssetDocStub -Content $updated | Should -BeFalse
    }
}

Describe 'Invoke-AssetDocsGeneration idempotence' -Tag 'Unit' {
    BeforeAll {
        $script:repo = New-AssetFixtureRepo
        $script:first = Invoke-AssetDocsGeneration -RepoRoot $script:repo -TemplatePath $script:TemplatePath
        $script:second = Invoke-AssetDocsGeneration -RepoRoot $script:repo -TemplatePath $script:TemplatePath
    }

    It 'Writes nothing on a second run' {
        $script:second.Created.Count | Should -Be 0
        $script:second.Updated.Count | Should -Be 0
        $script:second.Removed.Count | Should -Be 0
        $script:second.DriftCount | Should -Be 0
    }

    It 'Reports every page from the first run as unchanged' {
        @($script:second.Unchanged | Sort-Object) | Should -Be @($script:first.Created | Sort-Object)
    }

    It 'Preserves ms.date when regeneration produces identical content' {
        $pageRel = 'docs/reference/agents/hve-core/zulu-agent.md'
        $page = Join-Path $script:repo $pageRel
        Set-Content -LiteralPath $page -Value ((Get-Content -LiteralPath $page -Raw) -replace '(?m)^ms\.date:.*$', 'ms.date: 2020-01-01') -Encoding utf8NoBOM -NoNewline

        $result = Invoke-AssetDocsGeneration -RepoRoot $script:repo -TemplatePath $script:TemplatePath

        $result.Updated | Should -Not -Contain $pageRel
        Get-PageField -Path $page -Field 'ms.date' | Should -Be '2020-01-01'
    }

    It 'Generates identical pages from CRLF and LF sources' {
        $lfRepo = New-AssetFixtureRepo
        $crlfRepo = New-AssetFixtureRepo -Newline "`r`n"

        $lfResult = Invoke-AssetDocsGeneration -RepoRoot $lfRepo -TemplatePath $script:TemplatePath
        $crlfResult = Invoke-AssetDocsGeneration -RepoRoot $crlfRepo -TemplatePath $script:TemplatePath

        @($crlfResult.Created | Sort-Object) | Should -Be @($lfResult.Created | Sort-Object)
        foreach ($rel in $lfResult.Created) {
            (Get-Content -LiteralPath (Join-Path $crlfRepo $rel) -Raw) |
                Should -Be (Get-Content -LiteralPath (Join-Path $lfRepo $rel) -Raw) -Because "page '$rel' must not depend on source line endings"
        }
    }
}

Describe 'Invoke-AssetDocsGeneration interactivity migration' -Tag 'Unit' {
    It 'Removes untouched interactive scaffolding when an existing agent becomes background-only' {
        $repo = New-AssetFixtureRepo
        Invoke-AssetDocsGeneration -RepoRoot $repo -TemplatePath $script:TemplatePath | Out-Null
        $pagePath = Join-Path $repo 'docs/reference/agents/hve-core/alpha-agent.md'
        $page = Get-Content -LiteralPath $pagePath -Raw
        $page = $page -replace 'Provide a concrete example that shows the asset in action, including representative input and the resulting output\.', 'Run the alpha agent with a representative request and preserve this authored example.'
        Set-Content -LiteralPath $pagePath -Value $page -Encoding utf8NoBOM -NoNewline
        $expectedTail = [regex]::Match($page, '(?ms)^## Example usage\s*\r?\n.*\z').Value
        $agentPath = Join-Path $repo '.github/agents/hve-core/alpha-agent.agent.md'
        $agent = Get-Content -LiteralPath $agentPath -Raw
        $agent = $agent -replace '(?m)^description:', "user-invocable: false`ndescription:"
        Set-Content -LiteralPath $agentPath -Value $agent -Encoding utf8NoBOM -NoNewline

        Invoke-AssetDocsGeneration -RepoRoot $repo -TemplatePath $script:TemplatePath | Out-Null

        $content = Get-Content -LiteralPath $pagePath -Raw
        $content | Should -Match 'Background agent'
        $content | Should -Match '(?m)^\| Interactive\s+\| No\s+\|$'
        $content | Should -Not -Match '## How to use it'
        [regex]::Match($content, '(?ms)^## Example usage\s*\r?\n.*\z').Value | Should -BeExactly $expectedTail
    }
}

Describe 'Invoke-AssetDocsGeneration WhatIf' -Tag 'Unit' {
    It 'Reports drift without creating any documentation page' {
        $repo = New-AssetFixtureRepo

        $result = Invoke-AssetDocsGeneration -RepoRoot $repo -TemplatePath $script:TemplatePath -WhatIf

        $result.WhatIf | Should -BeTrue
        @($result.Created | Sort-Object) | Should -Be @(($script:ExpectedAssetPages + $script:ExpectedIndexPages) | Sort-Object)
        $result.DriftCount | Should -Be ($script:ExpectedAssetPages.Count + $script:ExpectedIndexPages.Count)
        Test-Path -LiteralPath (Join-Path $repo 'docs/reference') | Should -BeFalse
    }

    It 'Leaves every source asset byte-identical' {
        $repo = New-AssetFixtureRepo
        $before = Get-SourceSnapshot -RepoRoot $repo

        Invoke-AssetDocsGeneration -RepoRoot $repo -TemplatePath $script:TemplatePath -WhatIf | Out-Null

        Get-SourceSnapshot -RepoRoot $repo | Should -Be $before
    }

    It 'Removes no orphaned page' {
        $repo = New-AssetFixtureRepo
        Invoke-AssetDocsGeneration -RepoRoot $repo -TemplatePath $script:TemplatePath | Out-Null
        Remove-Item -LiteralPath (Join-Path $repo '.github/agents/hve-core/zulu-agent.agent.md') -Force

        $result = Invoke-AssetDocsGeneration -RepoRoot $repo -TemplatePath $script:TemplatePath -WhatIf

        $result.Removed | Should -Be @('docs/reference/agents/hve-core/zulu-agent.md')
        Test-Path -LiteralPath (Join-Path $repo 'docs/reference/agents/hve-core/zulu-agent.md') | Should -BeTrue
    }
}

Describe 'Invoke-AssetDocsGeneration orphan disposition' -Tag 'Unit' {
    It 'Removes an orphaned page that is still an untouched scaffold' {
        $repo = New-AssetFixtureRepo
        Invoke-AssetDocsGeneration -RepoRoot $repo -TemplatePath $script:TemplatePath | Out-Null
        Remove-Item -LiteralPath (Join-Path $repo '.github/agents/hve-core/zulu-agent.agent.md') -Force

        $result = Invoke-AssetDocsGeneration -RepoRoot $repo -TemplatePath $script:TemplatePath

        $result.Removed | Should -Be @('docs/reference/agents/hve-core/zulu-agent.md')
        $result.NeedsAttention | Should -BeNullOrEmpty
        Test-Path -LiteralPath (Join-Path $repo 'docs/reference/agents/hve-core/zulu-agent.md') | Should -BeFalse
    }

    It 'Preserves an orphaned page whose human sections were authored' {
        $repo = New-AssetFixtureRepo
        Invoke-AssetDocsGeneration -RepoRoot $repo -TemplatePath $script:TemplatePath | Out-Null

        $pageRel = 'docs/reference/agents/hve-core/zulu-agent.md'
        $page = Join-Path $repo $pageRel
        Add-Content -LiteralPath $page -Value "`nAuthored guidance that must survive.`n" -Encoding utf8NoBOM
        $authoredContent = Get-Content -LiteralPath $page -Raw
        Remove-Item -LiteralPath (Join-Path $repo '.github/agents/hve-core/zulu-agent.agent.md') -Force

        $result = Invoke-AssetDocsGeneration -RepoRoot $repo -TemplatePath $script:TemplatePath -WarningAction SilentlyContinue

        $result.Removed | Should -BeNullOrEmpty
        $result.NeedsAttention | Should -Contain $pageRel
        Get-Content -LiteralPath $page -Raw | Should -Be $authoredContent
    }

    It 'Preserves an orphaned page whose generated markers were damaged' {
        $repo = New-AssetFixtureRepo
        Invoke-AssetDocsGeneration -RepoRoot $repo -TemplatePath $script:TemplatePath | Out-Null

        $pageRel = 'docs/reference/agents/hve-core/zulu-agent.md'
        $page = Join-Path $repo $pageRel
        Set-Content -LiteralPath $page -Value ((Get-Content -LiteralPath $page -Raw) -replace '<!-- END AUTO-GENERATED: overview -->', '') -Encoding utf8NoBOM -NoNewline
        $damagedContent = Get-Content -LiteralPath $page -Raw
        Remove-Item -LiteralPath (Join-Path $repo '.github/agents/hve-core/zulu-agent.agent.md') -Force

        $result = Invoke-AssetDocsGeneration -RepoRoot $repo -TemplatePath $script:TemplatePath -WarningAction SilentlyContinue

        $result.Removed | Should -BeNullOrEmpty
        $result.NeedsAttention | Should -Contain $pageRel
        Get-Content -LiteralPath $page -Raw | Should -Be $damagedContent
    }

    It 'Skips regeneration of a live page whose overview markers are missing' {
        $repo = New-AssetFixtureRepo
        Invoke-AssetDocsGeneration -RepoRoot $repo -TemplatePath $script:TemplatePath | Out-Null

        $pageRel = 'docs/reference/agents/hve-core/alpha-agent.md'
        $page = Join-Path $repo $pageRel
        Set-Content -LiteralPath $page -Value ((Get-Content -LiteralPath $page -Raw) -replace '<!-- BEGIN AUTO-GENERATED: overview -->', '') -Encoding utf8NoBOM -NoNewline
        $damagedContent = Get-Content -LiteralPath $page -Raw

        $result = Invoke-AssetDocsGeneration -RepoRoot $repo -TemplatePath $script:TemplatePath -WarningAction SilentlyContinue

        $result.NeedsAttention | Should -Contain $pageRel
        $result.Updated | Should -Not -Contain $pageRel
        Get-Content -LiteralPath $page -Raw | Should -Be $damagedContent
    }
}

Describe 'Invoke-AssetDocsGeneration input validation' -Tag 'Unit' {
    It 'Throws when the page template is missing' {
        $repo = New-AssetFixtureRepo
        $missing = Join-Path $repo 'templates/absent.template.md'

        { Invoke-AssetDocsGeneration -RepoRoot $repo -TemplatePath $missing } |
            Should -Throw -ExpectedMessage "Template not found: $missing"
    }

    It 'Throws when an applicable template section body is missing' {
        $repo = New-AssetFixtureRepo
        $brokenTemplate = Join-Path $TestDrive 'broken-asset-doc.template.md'
        $template = Get-Content -LiteralPath $script:TemplatePath -Raw
        Set-Content -LiteralPath $brokenTemplate -Value ($template -replace '<!-- END ASSET-DOC TEMPLATE: example-usage -->', '') -Encoding utf8NoBOM -NoNewline

        { Invoke-AssetDocsGeneration -RepoRoot $repo -TemplatePath $brokenTemplate } |
            Should -Throw -ExpectedMessage "Template section 'example-usage' must contain exactly one begin marker and one end marker."
    }

    It 'Produces no pages for a repository with no documentable assets' {
        $repo = Join-Path $TestDrive 'empty-repo'
        New-Item -ItemType Directory -Path (Join-Path $repo '.github') -Force | Out-Null

        $result = Invoke-AssetDocsGeneration -RepoRoot $repo -TemplatePath $script:TemplatePath

        $result.Created.Count | Should -Be 0
        $result.DriftCount | Should -Be 0
    }
}

Describe 'New-DocFrontmatter' -Tag 'Unit' {
    It 'Emits all required frontmatter fields' {
        $fm = New-DocFrontmatter -Title 'Demo' -Description 'A demo.' -SidebarPosition 3 -MsDate '2026-07-02' -Topic 'reference' -Keywords @('agent', 'demo')
        $fm | Should -Match '(?m)^title: Demo$'
        $fm | Should -Match '(?m)^description: A demo\.$'
        $fm | Should -Match '(?m)^sidebar_position: 3$'
        $fm | Should -Match '(?m)^author: Microsoft$'
        $fm | Should -Match '(?m)^ms\.date: 2026-07-02$'
        $fm | Should -Match '(?m)^ms\.topic: reference$'
        $fm | Should -Match '(?ms)^keywords:\r?\n  - agent\r?\n  - demo$'
    }

    It 'Honors an explicit author' {
        $fm = New-DocFrontmatter -Title 'Demo' -Description 'A demo.' -SidebarPosition 1 -MsDate '2026-07-02' -Topic 'overview' -Keywords @('demo') -Author 'HVE Core Team'
        $fm | Should -Match '(?m)^author: HVE Core Team$'
    }

    It 'Rejects a topic outside the docs schema enum' {
        { New-DocFrontmatter -Title 'Demo' -Description 'A demo.' -SidebarPosition 1 -MsDate '2026-07-02' -Topic 'not-a-topic' -Keywords @('demo') } |
            Should -Throw
    }
}

Describe 'Get-AssetDocKeyword' -Tag 'Unit' {
    It 'Combines kind, collection, and key' {
        $model = [PSCustomObject]@{
            Kind   = 'agent'
            Key    = 'accessibility-planner'
            DocRel = 'docs/reference/agents/accessibility/accessibility-planner.md'
        }

        Get-AssetDocKeyword -Model $model | Should -Be @('agent', 'accessibility', 'accessibility-planner')
    }

    It 'Omits the collection segment for assets directly under the kind directory' {
        $model = [PSCustomObject]@{
            Kind   = 'prompt'
            Key    = 'standalone'
            DocRel = 'docs/reference/prompts/standalone.md'
        }

        Get-AssetDocKeyword -Model $model | Should -Be @('prompt', 'standalone')
    }

    It 'Deduplicates repeated segments case-insensitively' {
        $model = [PSCustomObject]@{
            Kind   = 'skill'
            Key    = 'jira'
            DocRel = 'docs/reference/skills/jira/jira.md'
        }

        Get-AssetDocKeyword -Model $model | Should -Be @('skill', 'jira')
    }
}

Describe 'Test-DocContentEqual' -Tag 'Unit' {
    It 'Treats CRLF and LF forms of the same content as equal' {
        Test-DocContentEqual -Left "a`nb`nc`n" -Right "a`r`nb`r`nc`r`n" | Should -BeTrue
    }

    It 'Reports genuinely different content as unequal' {
        Test-DocContentEqual -Left "a`nb`n" -Right "a`r`nB`r`n" | Should -BeFalse
    }

    It 'Reports differing trailing whitespace as unequal' {
        Test-DocContentEqual -Left "a`nb" -Right "a`r`nb`r`n" | Should -BeFalse
    }

    It 'Treats empty strings as equal' {
        Test-DocContentEqual -Left '' -Right '' | Should -BeTrue
    }
}
