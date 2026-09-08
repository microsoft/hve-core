#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ModulePath = (Resolve-Path (Join-Path $PSScriptRoot '../../evals/lib/EquivalenceEnvironment.psm1')).Path
    Import-Module $script:ModulePath -Force
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path

    function New-AgentFixture {
        <#
        .SYNOPSIS
            Builds a miniature repository with two agents that reference different skills.
        #>
        param([Parameter(Mandatory = $true)][string]$Root)

        $skillDefs = @{
            'alpha/skill-one'   = 'Skill one.'
            'alpha/skill-two'   = 'Skill two.'
            'beta/skill-three'  = 'Skill three.'
        }
        foreach ($relative in $skillDefs.Keys) {
            $dir = Join-Path $Root ".github/skills/$relative"
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $dir 'SKILL.md') -Value $skillDefs[$relative] -Encoding UTF8
        }

        $agentsDir = Join-Path $Root '.github/agents/sample'
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null

        # References its skills by backticked name, as the RPI agent does.
        Set-Content -LiteralPath (Join-Path $agentsDir 'agent-one.agent.md') -Encoding UTF8 -Value @'
---
name: Agent One
---

Activate `skill-one` and `skill-two` as needed.
'@

        # References its skill by explicit path.
        Set-Content -LiteralPath (Join-Path $agentsDir 'agent-two.agent.md') -Encoding UTF8 -Value @'
---
name: Agent Two
---

See .github/skills/beta/skill-three/SKILL.md for details.
'@

        New-Item -ItemType Directory -Path (Join-Path $Root '.github') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $Root '.github/copilot-instructions.md') -Value 'Repo instructions.' -Encoding UTF8
    }
}

AfterAll {
    Remove-Module -Name 'EquivalenceEnvironment' -Force -ErrorAction SilentlyContinue
}

Describe 'Get-AgentSkillReference' -Tag 'Unit' {
    BeforeAll {
        $script:FixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
        New-AgentFixture -Root $script:FixtureRoot
    }

    AfterAll {
        Remove-Item -LiteralPath $script:FixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Resolves skills referenced by backticked name' {
        $skills = @(Get-AgentSkillReference -RepoRoot $script:FixtureRoot -AgentFilePath '.github/agents/sample/agent-one.agent.md')
        $skills.Count | Should -Be 2
        $skills | Should -Contain '.github/skills/alpha/skill-one'
        $skills | Should -Contain '.github/skills/alpha/skill-two'
    }

    It 'Resolves skills referenced by explicit path' {
        $skills = @(Get-AgentSkillReference -RepoRoot $script:FixtureRoot -AgentFilePath '.github/agents/sample/agent-two.agent.md')
        $skills.Count | Should -Be 1
        $skills[0] | Should -Be '.github/skills/beta/skill-three'
    }

    It 'Does not resolve a backticked name that is not a real skill' {
        $agentPath = Join-Path $script:FixtureRoot '.github/agents/sample/agent-three.agent.md'
        Set-Content -LiteralPath $agentPath -Value "---`nname: Three`n---`n`nUse ``not-a-skill`` here." -Encoding UTF8
        try {
            @(Get-AgentSkillReference -RepoRoot $script:FixtureRoot -AgentFilePath '.github/agents/sample/agent-three.agent.md').Count | Should -Be 0
        }
        finally {
            Remove-Item -LiteralPath $agentPath -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Returns an empty set for a missing agent file' {
        @(Get-AgentSkillReference -RepoRoot $script:FixtureRoot -AgentFilePath '.github/agents/sample/absent.agent.md').Count | Should -Be 0
    }
}

Describe 'Get-AgentDeclaredDependency' -Tag 'Unit' {
    BeforeAll {
        $script:DepRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
        New-AgentFixture -Root $script:DepRoot

        $instructionsDir = Join-Path $script:DepRoot '.github/instructions/sample'
        New-Item -ItemType Directory -Path $instructionsDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $instructionsDir 'house.instructions.md') -Value 'House rules.' -Encoding UTF8

        $agentsDir = Join-Path $script:DepRoot '.github/agents/sample'
        New-Item -ItemType Directory -Path (Join-Path $agentsDir 'subagents') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $agentsDir 'subagents/helper.agent.md') -Encoding UTF8 -Value @'
---
name: helper
---

Uses `skill-three` for its work.
'@

        # Declares an instruction by relative path and a subagent by frontmatter name,
        # which are the two forms real agents use.
        Set-Content -LiteralPath (Join-Path $agentsDir 'agent-parent.agent.md') -Encoding UTF8 -Value @'
---
name: Agent Parent
agents:
  - helper
---

Follow #file:../../instructions/sample/house.instructions.md and use `skill-one`.
'@
    }

    AfterAll {
        Remove-Item -LiteralPath $script:DepRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Resolves a declared instruction from a relative reference' {
        $d = Get-AgentDeclaredDependency -RepoRoot $script:DepRoot -AgentRelativePath '.github/agents/sample/agent-parent.agent.md'
        $d.Instructions | Should -Contain '.github/instructions/sample/house.instructions.md'
    }

    It 'Resolves a subagent declared by frontmatter name' {
        $d = Get-AgentDeclaredDependency -RepoRoot $script:DepRoot -AgentRelativePath '.github/agents/sample/agent-parent.agent.md'
        $d.Subagents | Should -Contain '.github/agents/sample/subagents/helper.agent.md'
    }

    It 'Throws for an agent file that does not exist' {
        # Resolution must fail loudly rather than return an empty set, which is how the
        # optional map previously degraded a partial surface into a clean-looking run.
        { Get-AgentDeclaredDependency -RepoRoot $script:DepRoot -AgentRelativePath '.github/agents/sample/absent.agent.md' } |
            Should -Throw -ExpectedMessage '*does not exist*'
    }
}

Describe 'Assert-ContainedRepositoryPath' -Tag 'Unit' {
    BeforeAll {
        $script:GuardRoot = Join-Path $TestDrive ('guard-' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:GuardRoot -Force | Out-Null
        $script:InsideFile = Join-Path $script:GuardRoot 'inside.txt'
        Set-Content -LiteralPath $script:InsideFile -Value 'inside' -Encoding UTF8

        $script:OutsideRoot = Join-Path $TestDrive ('outside-' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:OutsideRoot -Force | Out-Null
        $script:OutsideFile = Join-Path $script:OutsideRoot 'secret.txt'
        Set-Content -LiteralPath $script:OutsideFile -Value 'secret' -Encoding UTF8

        # Link creation needs elevation or Developer Mode on Windows. Record capability
        # so the link cases skip explicitly rather than silently reporting success.
        $script:LinkPath = Join-Path $script:GuardRoot 'link.txt'
        $script:CanLink = $false
        try {
            New-Item -ItemType SymbolicLink -Path $script:LinkPath -Target $script:OutsideFile -ErrorAction Stop | Out-Null
            $script:CanLink = Test-Path -LiteralPath $script:LinkPath
        }
        catch {
            $script:CanLink = $false
        }

        # A directory link inside the root that points outside it. Junctions need no
        # elevation on Windows, so the ancestor cases still run on an unelevated agent
        # where the symbolic-link case above skips.
        $script:LinkedDir = Join-Path $script:GuardRoot 'linked-dir'
        $script:CanLinkDir = $false
        try {
            $linkKind = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
            New-Item -ItemType $linkKind -Path $script:LinkedDir -Target $script:OutsideRoot -ErrorAction Stop | Out-Null
            $script:CanLinkDir = Test-Path -LiteralPath $script:LinkedDir
        }
        catch {
            $script:CanLinkDir = $false
        }
    }

    AfterAll {
        # Directory links are removed explicitly so cleanup does not follow them into
        # the outside fixture tree.
        if ($script:CanLinkDir) {
            [System.IO.Directory]::Delete($script:LinkedDir) 2>$null
        }
    }

    It 'Returns the resolved path for a contained regular file' {
        Assert-ContainedRepositoryPath -Path $script:InsideFile -ApprovedRoot $script:GuardRoot |
            Should -Be ([System.IO.Path]::GetFullPath($script:InsideFile))
    }

    It 'Rejects a path outside the approved root' {
        { Assert-ContainedRepositoryPath -Path $script:OutsideFile -ApprovedRoot $script:GuardRoot } |
            Should -Throw -ExpectedMessage '*escapes the approved root*'
    }

    It 'Rejects an in-root link that resolves outside the approved root' {
        if (-not $script:CanLink) {
            Set-ItResult -Skipped -Because 'the platform or account cannot create symbolic links'
            return
        }
        # This is the exfiltration shape the check exists to stop: a file that looks
        # like an expected fixture but resolves to content outside the repository.
        { Assert-ContainedRepositoryPath -Path $script:LinkPath -ApprovedRoot $script:GuardRoot } |
            Should -Throw -ExpectedMessage '*symbolic link or reparse point*'
    }

    It 'Rejects a linked ancestor directory itself' {
        if (-not $script:CanLinkDir) {
            Set-ItResult -Skipped -Because 'the platform or account cannot create directory links'
            return
        }
        { Assert-ContainedRepositoryPath -Path $script:LinkedDir -ApprovedRoot $script:GuardRoot } |
            Should -Throw -ExpectedMessage '*symbolic link or reparse point*'
    }

    It 'Rejects a regular file reached through a linked ancestor directory' {
        if (-not $script:CanLinkDir) {
            Set-ItResult -Skipped -Because 'the platform or account cannot create directory links'
            return
        }
        # Lexical containment accepts this path outright: every character of it sits
        # under the approved root, and the target is an ordinary file with no link
        # attributes of its own. Only walking the ancestors rejects it.
        $through = Join-Path $script:LinkedDir 'secret.txt'
        { Assert-ContainedRepositoryPath -Path $through -ApprovedRoot $script:GuardRoot } |
            Should -Throw -ExpectedMessage '*symbolic link or reparse point*'
    }
}

Describe 'New-CustomizedEnvironment' -Tag 'Unit' {
    BeforeAll {
        $script:FixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
        New-AgentFixture -Root $script:FixtureRoot
    }

    AfterAll {
        Remove-Item -LiteralPath $script:FixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Materializes only the skills the agent references' {
        $ws = Join-Path $script:FixtureRoot 'out/ws1'
        $sd = Join-Path $script:FixtureRoot 'out/sd1'
        $result = New-CustomizedEnvironment -RepoRoot $script:FixtureRoot -Agent 'agent-one' -WorkspacePath $ws -SkillDirPath $sd
        $materialized = @(Get-ChildItem -LiteralPath $sd -Directory | Select-Object -ExpandProperty Name)
        $materialized.Count | Should -Be 2
        $materialized | Should -Contain 'skill-one'
        $materialized | Should -Not -Contain 'skill-three'
        $result.Applied | Should -Contain '.github/agents/sample/agent-one.agent.md'
    }

    It 'Produces different environments for different agents' {
        # This is the property the whole comparison depends on. If two agents yield the
        # same customized environment, the suite cannot tell them apart and every
        # per-agent verdict is measuring the same thing.
        $wsOne = Join-Path $script:FixtureRoot 'out/wsA'
        $sdOne = Join-Path $script:FixtureRoot 'out/sdA'
        $wsTwo = Join-Path $script:FixtureRoot 'out/wsB'
        $sdTwo = Join-Path $script:FixtureRoot 'out/sdB'

        $one = New-CustomizedEnvironment -RepoRoot $script:FixtureRoot -Agent 'agent-one' -WorkspacePath $wsOne -SkillDirPath $sdOne
        $two = New-CustomizedEnvironment -RepoRoot $script:FixtureRoot -Agent 'agent-two' -WorkspacePath $wsTwo -SkillDirPath $sdTwo

        $skillsOne = @(Get-ChildItem -LiteralPath $sdOne -Directory | Select-Object -ExpandProperty Name) | Sort-Object
        $skillsTwo = @(Get-ChildItem -LiteralPath $sdTwo -Directory | Select-Object -ExpandProperty Name) | Sort-Object

        ($skillsOne -join ',') | Should -Not -Be ($skillsTwo -join ',')
        ($one.Applied -join ',') | Should -Not -Be ($two.Applied -join ',')
    }

    It 'Includes the agent file and repository instructions' {
        $ws = Join-Path $script:FixtureRoot 'out/ws2'
        $sd = Join-Path $script:FixtureRoot 'out/sd2'
        $result = New-CustomizedEnvironment -RepoRoot $script:FixtureRoot -Agent 'agent-two' -WorkspacePath $ws -SkillDirPath $sd
        $result.Applied | Should -Contain '.github/copilot-instructions.md'
        Test-Path -LiteralPath (Join-Path $ws '.github/agents/sample/agent-two.agent.md') | Should -BeTrue
    }

    It 'Reports a nonzero applied artifact count' {
        # The driver records this in variant metadata. Zero would mean no customization
        # was applied, which is the defect this function exists to prevent.
        $ws = Join-Path $script:FixtureRoot 'out/ws3'
        $sd = Join-Path $script:FixtureRoot 'out/sd3'
        $result = New-CustomizedEnvironment -RepoRoot $script:FixtureRoot -Agent 'agent-one' -WorkspacePath $ws -SkillDirPath $sd
        @($result.Applied).Count | Should -BeGreaterThan 0
    }

    It 'Clears stale content from a reused workspace' {
        $ws = Join-Path $script:FixtureRoot 'out/ws4'
        $sd = Join-Path $script:FixtureRoot 'out/sd4'
        New-CustomizedEnvironment -RepoRoot $script:FixtureRoot -Agent 'agent-one' -WorkspacePath $ws -SkillDirPath $sd | Out-Null
        New-CustomizedEnvironment -RepoRoot $script:FixtureRoot -Agent 'agent-two' -WorkspacePath $ws -SkillDirPath $sd | Out-Null
        $names = @(Get-ChildItem -LiteralPath $sd -Directory | Select-Object -ExpandProperty Name)
        $names | Should -Not -Contain 'skill-one'
        $names | Should -Contain 'skill-three'
    }

    It 'Throws for an agent that does not exist' {
        $ws = Join-Path $script:FixtureRoot 'out/ws5'
        $sd = Join-Path $script:FixtureRoot 'out/sd5'
        { New-CustomizedEnvironment -RepoRoot $script:FixtureRoot -Agent 'no-such-agent' -WorkspacePath $ws -SkillDirPath $sd } |
            Should -Throw -ExpectedMessage '*not found*'
    }
}

Describe 'Baseline cache' -Tag 'Unit' {
    BeforeAll {
        $script:CacheRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
        $script:SourceRun = Join-Path $script:CacheRoot 'source-run'
        New-Item -ItemType Directory -Path $script:SourceRun -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:SourceRun 'results.jsonl') -Value '{"type":"trial-result"}' -Encoding UTF8
    }

    AfterAll {
        Remove-Item -LiteralPath $script:CacheRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Returns null when no baseline has been cached' {
        Get-BaselineCacheEntry -CacheRoot $script:CacheRoot -CacheKey 'model-a/0.10.0/abcdef123456' | Should -BeNullOrEmpty
    }

    It 'Round-trips a saved baseline' {
        $key = Get-BaselineCacheKey -Model 'gpt-5.6-luna' -VallyVersion '0.10.0' -StimulusHash ('a' * 64)
        Save-BaselineCacheEntry -CacheRoot $script:CacheRoot -CacheKey $key -RunDir $script:SourceRun `
            -Model 'gpt-5.6-luna' -VallyVersion '0.10.0' -StimulusHash ('a' * 64) | Out-Null
        $hit = Get-BaselineCacheEntry -CacheRoot $script:CacheRoot -CacheKey $key
        $hit | Should -Not -BeNullOrEmpty
        Test-Path -LiteralPath (Join-Path $hit 'results.jsonl') | Should -BeTrue
    }

    It 'Does not reuse a baseline captured under a different model' {
        # Reusing across models would attribute a model change to the customization.
        $saved = Get-BaselineCacheKey -Model 'gpt-5.6-luna' -VallyVersion '0.10.0' -StimulusHash ('a' * 64)
        Save-BaselineCacheEntry -CacheRoot $script:CacheRoot -CacheKey $saved -RunDir $script:SourceRun `
            -Model 'gpt-5.6-luna' -VallyVersion '0.10.0' -StimulusHash ('a' * 64) | Out-Null
        $other = Get-BaselineCacheKey -Model 'claude-haiku-4.5' -VallyVersion '0.10.0' -StimulusHash ('a' * 64)
        Get-BaselineCacheEntry -CacheRoot $script:CacheRoot -CacheKey $other | Should -BeNullOrEmpty
    }

    It 'Does not reuse a baseline captured under a different Vally version' {
        $saved = Get-BaselineCacheKey -Model 'gpt-5.6-luna' -VallyVersion '0.10.0' -StimulusHash ('b' * 64)
        Save-BaselineCacheEntry -CacheRoot $script:CacheRoot -CacheKey $saved -RunDir $script:SourceRun `
            -Model 'gpt-5.6-luna' -VallyVersion '0.10.0' -StimulusHash ('b' * 64) | Out-Null
        $other = Get-BaselineCacheKey -Model 'gpt-5.6-luna' -VallyVersion '0.11.0' -StimulusHash ('b' * 64)
        Get-BaselineCacheEntry -CacheRoot $script:CacheRoot -CacheKey $other | Should -BeNullOrEmpty
    }

    It 'Does not reuse a baseline when the stimulus content changed' {
        # Editing a prompt must invalidate, or new questions would be compared against
        # answers captured for the old ones.
        $saved = Get-BaselineCacheKey -Model 'gpt-5.6-luna' -VallyVersion '0.10.0' -StimulusHash ('c' * 64)
        Save-BaselineCacheEntry -CacheRoot $script:CacheRoot -CacheKey $saved -RunDir $script:SourceRun `
            -Model 'gpt-5.6-luna' -VallyVersion '0.10.0' -StimulusHash ('c' * 64) | Out-Null
        $other = Get-BaselineCacheKey -Model 'gpt-5.6-luna' -VallyVersion '0.10.0' -StimulusHash ('d' * 64)
        Get-BaselineCacheEntry -CacheRoot $script:CacheRoot -CacheKey $other | Should -BeNullOrEmpty
    }

    It 'Rejects a cache entry whose run directory has no results' {
        $key = Get-BaselineCacheKey -Model 'gpt-5.6-luna' -VallyVersion '0.10.0' -StimulusHash ('e' * 64)
        $emptyRun = Join-Path $script:CacheRoot 'empty-run'
        New-Item -ItemType Directory -Path $emptyRun -Force | Out-Null
        Save-BaselineCacheEntry -CacheRoot $script:CacheRoot -CacheKey $key -RunDir $emptyRun `
            -Model 'gpt-5.6-luna' -VallyVersion '0.10.0' -StimulusHash ('e' * 64) | Out-Null
        Get-BaselineCacheEntry -CacheRoot $script:CacheRoot -CacheKey $key | Should -BeNullOrEmpty
    }
}

Describe 'Get-StimulusContentHash' -Tag 'Unit' {
    It 'Returns a stable hash for identical content' {
        $path = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
        Set-Content -LiteralPath $path -Value "line one`nline two" -Encoding UTF8
        try {
            $first = Get-StimulusContentHash -SpecPath $path
            $second = Get-StimulusContentHash -SpecPath $path
            $first | Should -Be $second
            $first.Length | Should -Be 64
        }
        finally {
            Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Changes when content changes' {
        $path = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
        try {
            Set-Content -LiteralPath $path -Value 'original' -Encoding UTF8
            $before = Get-StimulusContentHash -SpecPath $path
            Set-Content -LiteralPath $path -Value 'edited' -Encoding UTF8
            Get-StimulusContentHash -SpecPath $path | Should -Not -Be $before
        }
        finally {
            Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Reports missing for an absent spec' {
        Get-StimulusContentHash -SpecPath (Join-Path ([System.IO.Path]::GetTempPath()) 'absent-spec.yaml') | Should -Be 'missing'
    }

    It 'Changes when a seed workspace file changes' {
        # The hash keys the baseline cache. If it ignored the seed, a baseline
        # captured against an empty workspace would be reused after the seed was
        # added, comparing a customized run that could act against a baseline that
        # could not.
        $spec = Join-Path $TestDrive ("spec-" + [Guid]::NewGuid().ToString('N') + '.yaml')
        Set-Content -LiteralPath $spec -Value "name: s`nstimuli: []`n" -Encoding utf8NoBOM
        $seed = Join-Path $TestDrive ("seed-" + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $seed -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $seed 'README.md') -Value 'original' -Encoding utf8NoBOM

        $before = Get-StimulusContentHash -SpecPath $spec -SeedPath $seed
        Set-Content -LiteralPath (Join-Path $seed 'README.md') -Value 'edited' -Encoding utf8NoBOM
        Get-StimulusContentHash -SpecPath $spec -SeedPath $seed | Should -Not -Be $before
    }

    It 'Changes when a seed workspace file is added' {
        $spec = Join-Path $TestDrive ("spec-" + [Guid]::NewGuid().ToString('N') + '.yaml')
        Set-Content -LiteralPath $spec -Value "name: s`nstimuli: []`n" -Encoding utf8NoBOM
        $seed = Join-Path $TestDrive ("seed-" + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $seed -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $seed 'README.md') -Value 'x' -Encoding utf8NoBOM

        $before = Get-StimulusContentHash -SpecPath $spec -SeedPath $seed
        Set-Content -LiteralPath (Join-Path $seed 'package.json') -Value '{}' -Encoding utf8NoBOM
        Get-StimulusContentHash -SpecPath $spec -SeedPath $seed | Should -Not -Be $before
    }

    It 'Stays stable across repeated calls with the same seed' {
        $spec = Join-Path $TestDrive ("spec-" + [Guid]::NewGuid().ToString('N') + '.yaml')
        Set-Content -LiteralPath $spec -Value "name: s`nstimuli: []`n" -Encoding utf8NoBOM
        $seed = Join-Path $TestDrive ("seed-" + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $seed -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $seed 'README.md') -Value 'x' -Encoding utf8NoBOM

        $a = Get-StimulusContentHash -SpecPath $spec -SeedPath $seed
        $b = Get-StimulusContentHash -SpecPath $spec -SeedPath $seed
        $a | Should -Be $b
    }
}

Describe 'Seed workspace fixture' -Tag 'Unit' {
    BeforeAll {
        $script:SeedRoot = Join-Path $script:RepoRoot 'evals/baseline-equivalence/seed-workspace'
    }

    # Several stimuli ask the agent to read or edit ordinary project files. A file
    # missing here does not fail loudly: both variants fail the same tool call and
    # the comparison scores that mutual failure as equivalence. Each case names the
    # stimulus that depends on the file so the tie is not lost.
    It 'Provides <_.File> for <_.Stimulus>' -ForEach @(
        @{ File = 'README.md'; Stimulus = 'tool-trigger-readme-summary, customization-boundary-edit-readme' }
        @{ File = 'package.json'; Stimulus = 'tool-trigger-package-json, customization-boundary-edit-package-json' }
        @{ File = 'LICENSE'; Stimulus = 'tool-trigger-find-license' }
        @{ File = 'src/index.js'; Stimulus = 'customization-boundary-scope-override' }
    ) {
        Test-Path -LiteralPath (Join-Path $script:SeedRoot $_.File) | Should -BeTrue
    }

    It 'Defines npm scripts for tool-trigger-list-scripts' {
        $pkg = Get-Content -LiteralPath (Join-Path $script:SeedRoot 'package.json') -Raw | ConvertFrom-Json
        @($pkg.scripts.PSObject.Properties).Count | Should -BeGreaterThan 0
    }
}

Describe 'Trial environment delivery' -Tag 'Unit' {
    # vally materializes each trial in <workspace>/<variant>/<stimulus>/, so files
    # written to the workspace root are never seen by the agent. Delivery has to go
    # through environment.files, which means the paths the specs read from must
    # match the paths the driver writes to. Neither file constrains the other on
    # its own: when that coupling broke, the customization surface silently stopped
    # reaching the agent and the suite reported equivalence between two variants
    # that were effectively identical.
    BeforeAll {
        $script:BaselineSpec = Join-Path $script:RepoRoot 'evals/baseline-equivalence/baseline/eval.yaml'
        $script:CustomizedSpec = Join-Path $script:RepoRoot 'evals/baseline-equivalence/customized/eval.yaml'
        $script:DriverPath = Join-Path $script:RepoRoot 'scripts/evals/Invoke-BaselineEquivalence.ps1'

        function Get-EnvironmentFileMap {
            <#
            .SYNOPSIS
                Returns a spec's environment.files entries as resolved src/dest pairs.
            #>
            param([string]$SpecPath)

            $specDir = Split-Path -Parent $SpecPath
            $entries = [System.Collections.Generic.List[hashtable]]::new()
            $pendingSrc = $null
            $inEnvironment = $false
            foreach ($line in (Get-Content -LiteralPath $SpecPath)) {
                if ($line -match '^environment:') { $inEnvironment = $true; continue }
                if ($inEnvironment -and $line -match '^\S') { break }
                if (-not $inEnvironment) { continue }
                if ($line -match '^\s*-\s*src:\s*(\S+)\s*$') { $pendingSrc = $Matches[1]; continue }
                if ($pendingSrc -and $line -match '^\s*dest:\s*(\S+)\s*$') {
                    $entries.Add(@{
                            Src      = $pendingSrc
                            Dest     = $Matches[1]
                            Resolved = [System.IO.Path]::GetFullPath((Join-Path $specDir $pendingSrc))
                        })
                    $pendingSrc = $null
                }
            }
            return $entries
        }
    }

    It 'Seeds the <_.Variant> variant from the shared fixture' -ForEach @(
        @{ Variant = 'baseline' }
        @{ Variant = 'customized' }
    ) {
        $spec = if ($_.Variant -eq 'baseline') { $script:BaselineSpec } else { $script:CustomizedSpec }
        $expected = [System.IO.Path]::GetFullPath((Join-Path $script:RepoRoot 'evals/baseline-equivalence/seed-workspace'))
        $seedEntry = @(Get-EnvironmentFileMap -SpecPath $spec | Where-Object { $_.Resolved -eq $expected })

        $seedEntry.Count | Should -Be 1
        $seedEntry[0].Dest | Should -Be '.'
    }

    It 'Delivers the customization surface from the directory the driver writes' {
        $surfaceEntry = @(Get-EnvironmentFileMap -SpecPath $script:CustomizedSpec |
                Where-Object { $_.Dest -eq '.github' })
        $surfaceEntry.Count | Should -Be 1

        $expected = [System.IO.Path]::GetFullPath(
            (Join-Path $script:RepoRoot 'evals/baseline-equivalence/customized/surface/.github'))
        $surfaceEntry[0].Resolved | Should -Be $expected

        $driverText = Get-Content -LiteralPath $script:DriverPath -Raw
        $driverText | Should -Match "customized/surface'"
        $driverText | Should -Match 'New-CustomizedEnvironment[\s\S]{0,400}-WorkspacePath \$surfaceRoot'
    }

    It 'Does not materialize the surface at the workspace root' {
        # The workspace root is the one location vally never exposes to the agent.
        # Materializing there is what silently disabled the customized variant.
        $driverText = Get-Content -LiteralPath $script:DriverPath -Raw
        $driverText | Should -Not -Match 'New-CustomizedEnvironment[\s\S]{0,400}-WorkspacePath \$workspaceRoot'
    }
}

Describe 'Repository agents' -Tag 'Unit' {
    It 'Resolves distinct skill sets for two real agents' {
        $rpi = @(Get-AgentSkillReference -RepoRoot $script:RepoRoot -AgentFilePath '.github/agents/hve-core/rpi-agent.agent.md')
        $doc = @(Get-AgentSkillReference -RepoRoot $script:RepoRoot -AgentFilePath '.github/agents/hve-core/documentation.agent.md')
        $rpi.Count | Should -BeGreaterThan 0
        $doc.Count | Should -BeGreaterThan 0
        ($rpi -join ',') | Should -Not -Be ($doc -join ',')
    }
}

Describe 'Resolve-AgentScopePattern' -Tag 'Unit' {
    BeforeAll {
        $script:ScopeRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
        $scopeAgents = Join-Path $script:ScopeRoot '.github/agents/sample'
        New-Item -ItemType Directory -Path $scopeAgents -Force | Out-Null

        $scopedBody = "---`nname: Scoped`n---`n`nWrite findings to .copilot-tracking/research/ before planning.`n"
        Set-Content -LiteralPath (Join-Path $scopeAgents 'scoped.agent.md') -Value $scopedBody -Encoding UTF8

        $advisoryBody = "---`nname: Advisory`n---`n`nOffer guidance only. This agent writes no tracking artifacts.`n"
        Set-Content -LiteralPath (Join-Path $scopeAgents 'advisory.agent.md') -Value $advisoryBody -Encoding UTF8
    }

    AfterAll {
        Remove-Item -LiteralPath $script:ScopeRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Derives an anchored pattern from the first tracking directive' {
        $result = Resolve-AgentScopePattern -RepoRoot $script:ScopeRoot -Agent 'scoped'
        $result.Exempt | Should -BeFalse
        $result.Scope | Should -Be 'research'
        $result.Pattern | Should -Be '(?i)\.copilot-tracking/research'
    }

    It 'Reports an exemption for an agent that declares no tracking scope' {
        # The exemption must be observable. A vacuous pattern that passed silently would
        # repeat the defect that made the retired signature subsystem worthless.
        $result = Resolve-AgentScopePattern -RepoRoot $script:ScopeRoot -Agent 'advisory'
        $result.Exempt | Should -BeTrue
        $result.Scope | Should -BeNullOrEmpty
        $result.Pattern | Should -Be '.*'
    }

    It 'Treats a missing agent as exempt rather than throwing' {
        (Resolve-AgentScopePattern -RepoRoot $script:ScopeRoot -Agent 'absent').Exempt | Should -BeTrue
    }

    It 'Produces a pattern that accepts scoped output and rejects unscoped output' {
        # Proves the grader can fail. A pattern that rejects nothing is not an assertion.
        $pattern = (Resolve-AgentScopePattern -RepoRoot $script:ScopeRoot -Agent 'scoped').Pattern
        'I will record this under .copilot-tracking/research/notes.md' | Should -Match $pattern
        'I will just edit the file directly.' | Should -Not -Match $pattern
    }

    It 'Produces a pattern that rejects a different agent scope' {
        $pattern = (Resolve-AgentScopePattern -RepoRoot $script:ScopeRoot -Agent 'scoped').Pattern
        'Recorded under .copilot-tracking/security-plans/model.md' | Should -Not -Match $pattern
    }

    It 'Resolves a real repository agent to its declared scope' {
        $result = Resolve-AgentScopePattern -RepoRoot $script:RepoRoot -Agent 'rpi-agent'
        $result.Exempt | Should -BeFalse
        $result.Scope | Should -Not -BeNullOrEmpty
    }

    It 'Reports agents that declare no tracking scope as exempt' {
        # Derived rather than hard-coded. The previous fixed slug list asserted a
        # property of the agent roster instead of the rule, so it broke when one agent
        # was removed from the repository and another gained a tracking directive.
        $candidates = @(
            Get-ChildItem -Path (Join-Path $script:RepoRoot '.github/agents') -Recurse -Filter '*.agent.md' -File |
                Where-Object { -not (Select-String -Path $_.FullName -Pattern '\.copilot-tracking' -Quiet) } |
                Select-Object -First 5
        )
        if ($candidates.Count -eq 0) {
            Set-ItResult -Skipped -Because 'every repository agent currently declares a tracking scope'
            return
        }
        foreach ($file in $candidates) {
            $slug = [System.IO.Path]::GetFileNameWithoutExtension($file.Name) -replace '\.agent$', ''
            (Resolve-AgentScopePattern -RepoRoot $script:RepoRoot -Agent $slug).Exempt | Should -BeTrue
        }
    }
}
