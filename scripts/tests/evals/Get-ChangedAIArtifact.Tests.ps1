#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '../../evals/Modules/ArtifactDetection.psm1'
    $script:ScriptPath = Join-Path $PSScriptRoot '../../evals/Get-ChangedAIArtifact.ps1'

    Import-Module $script:ModulePath -Force
}

Describe 'ArtifactDetection module' -Tag 'Unit' {
    Context 'Get-ArtifactDescriptor' {
        It 'Classifies nested agent artifacts' {
            $result = Get-ArtifactDescriptor -Path '.github/agents/hve-core/researcher.agent.md'
            $result.kind | Should -Be 'agent'
            $result.artifactId | Should -Be 'researcher'
            $result.path | Should -Be '.github/agents/hve-core/researcher.agent.md'
        }

        It 'Classifies repo-root-only agent artifacts (no collection subdirectory)' {
            $result = Get-ArtifactDescriptor -Path '.github/agents/local-only.agent.md'
            $result.kind | Should -Be 'agent'
            $result.artifactId | Should -Be 'local-only'
        }

        It 'Classifies prompt artifacts' {
            $result = Get-ArtifactDescriptor -Path '.github/prompts/hve-core/task-research.prompt.md'
            $result.kind | Should -Be 'prompt'
            $result.artifactId | Should -Be 'task-research'
        }

        It 'Classifies instruction artifacts' {
            $result = Get-ArtifactDescriptor -Path '.github/instructions/coding-standards/powershell/powershell.instructions.md'
            $result.kind | Should -Be 'instruction'
            $result.artifactId | Should -Be 'powershell'
        }

        It 'Classifies skill SKILL.md files' {
            $result = Get-ArtifactDescriptor -Path '.github/skills/shared/pr-reference/SKILL.md'
            $result.kind | Should -Be 'skill'
            $result.artifactId | Should -Be 'pr-reference'
        }

        It 'Classifies repo-root-only skill SKILL.md (no collection subdirectory)' {
            $result = Get-ArtifactDescriptor -Path '.github/skills/local-only/SKILL.md'
            $result.kind | Should -Be 'skill'
            $result.artifactId | Should -Be 'local-only'
        }

        It 'Normalizes backslash separators' {
            $result = Get-ArtifactDescriptor -Path '.github\agents\hve-core\researcher.agent.md'
            $result.kind | Should -Be 'agent'
            $result.path | Should -Be '.github/agents/hve-core/researcher.agent.md'
        }

        It 'Returns null for non-artifact paths' {
            Get-ArtifactDescriptor -Path 'scripts/evals/Test-EvalSpec.ps1' | Should -BeNullOrEmpty
            Get-ArtifactDescriptor -Path 'docs/README.md' | Should -BeNullOrEmpty
            Get-ArtifactDescriptor -Path '.github/skills/shared/pr-reference/scripts/helper.ps1' | Should -BeNullOrEmpty
            Get-ArtifactDescriptor -Path '' | Should -BeNullOrEmpty
        }

        It 'Does not match files that merely contain artifact suffixes elsewhere' {
            Get-ArtifactDescriptor -Path 'docs/agent.md' | Should -BeNullOrEmpty
            Get-ArtifactDescriptor -Path '.github/agents/notes/README.md' | Should -BeNullOrEmpty
        }
    }

    Context 'ConvertFrom-GitDiffNameStatus' {
        It 'Parses added, modified, and deleted entries' {
            $lines = @(
                "A`tdocs/README.md",
                "M`tscripts/run.ps1",
                "D`tlegacy/old.txt"
            )
            $records = ConvertFrom-GitDiffNameStatus -Lines $lines
            $records.Count | Should -Be 3
            ($records | Where-Object { $_.status -eq 'A' }).path | Should -Be 'docs/README.md'
            ($records | Where-Object { $_.status -eq 'M' }).path | Should -Be 'scripts/run.ps1'
            ($records | Where-Object { $_.status -eq 'D' }).path | Should -Be 'legacy/old.txt'
        }

        It 'Parses rename entries and preserves both paths' {
            $lines = @("R100`told/path.md`tnew/path.md")
            $records = ConvertFrom-GitDiffNameStatus -Lines $lines
            $records.Count | Should -Be 1
            $records[0].status | Should -Be 'R'
            $records[0].previousPath | Should -Be 'old/path.md'
            $records[0].path | Should -Be 'new/path.md'
        }

        It 'Parses copy entries' {
            $lines = @("C75`tsrc.md`tdst.md")
            $records = ConvertFrom-GitDiffNameStatus -Lines $lines
            $records[0].status | Should -Be 'C'
            $records[0].previousPath | Should -Be 'src.md'
            $records[0].path | Should -Be 'dst.md'
        }

        It 'Skips empty or malformed lines' {
            $lines = @('', '   ', "A", "A`t")
            $records = ConvertFrom-GitDiffNameStatus -Lines $lines
            $records.Count | Should -Be 0
        }

        It 'Returns empty array for null input' {
            $records = ConvertFrom-GitDiffNameStatus -Lines $null
            $records.Count | Should -Be 0
        }
    }

    Context 'Get-ChangedArtifactRecord' {
        It 'Returns null for non-artifact paths' {
            $change = @{ status = 'M'; path = 'scripts/foo.ps1'; previousPath = $null }
            Get-ChangedArtifactRecord -Change $change | Should -BeNullOrEmpty
        }

        It 'Returns an artifact record for an added agent' {
            $change = @{ status = 'A'; path = '.github/agents/hve-core/foo.agent.md'; previousPath = $null }
            $rec = Get-ChangedArtifactRecord -Change $change
            $rec.kind | Should -Be 'agent'
            $rec.artifactId | Should -Be 'foo'
            $rec.status | Should -Be 'A'
        }

        It 'Returns an artifact record for a deleted skill' {
            $change = @{ status = 'D'; path = '.github/skills/shared/pr-reference/SKILL.md'; previousPath = $null }
            $rec = Get-ChangedArtifactRecord -Change $change
            $rec.kind | Should -Be 'skill'
            $rec.artifactId | Should -Be 'pr-reference'
            $rec.status | Should -Be 'D'
        }

        It 'Returns the destination as the artifact for a rename' {
            $change = @{
                status       = 'R'
                path         = '.github/prompts/hve-core/new-name.prompt.md'
                previousPath = '.github/prompts/hve-core/old-name.prompt.md'
            }
            $rec = Get-ChangedArtifactRecord -Change $change
            $rec.kind | Should -Be 'prompt'
            $rec.artifactId | Should -Be 'new-name'
            $rec.status | Should -Be 'R'
            $rec.previousPath | Should -Be '.github/prompts/hve-core/old-name.prompt.md'
        }

        It 'Treats a rename out of artifact space as a deletion' {
            $change = @{
                status       = 'R'
                path         = 'archive/foo.md'
                previousPath = '.github/prompts/hve-core/foo.prompt.md'
            }
            $rec = Get-ChangedArtifactRecord -Change $change
            $rec.kind | Should -Be 'prompt'
            $rec.artifactId | Should -Be 'foo'
            $rec.status | Should -Be 'D'
        }
    }
}

Describe 'Get-ChangedAIArtifact.ps1 entry script' -Tag 'Integration' {
    BeforeAll {
        $script:gitAvailable = $null -ne (Get-Command git -ErrorAction SilentlyContinue)
    }

    It 'Emits a manifest classifying added artifacts between two commits' {
        if (-not $script:gitAvailable) {
            Set-ItResult -Skipped -Because 'git executable not available in test environment'
            return
        }

        $repo = Join-Path $TestDrive ('repo-' + [Guid]::NewGuid())
        New-Item -ItemType Directory -Path $repo | Out-Null

        Push-Location $repo
        try {
            & git init --quiet --initial-branch=main 2>&1 | Out-Null
            & git config user.email 'test@example.com' 2>&1 | Out-Null
            & git config user.name 'Test User' 2>&1 | Out-Null
            & git config commit.gpgsign false 2>&1 | Out-Null

            New-Item -ItemType Directory -Path '.github/agents/hve-core' -Force | Out-Null
            'seed' | Set-Content -LiteralPath 'README.md'
            & git add . 2>&1 | Out-Null
            & git commit --quiet -m 'baseline' 2>&1 | Out-Null
            $baseSha = (& git rev-parse HEAD).Trim()

            'agent body' | Set-Content -LiteralPath '.github/agents/hve-core/new-agent.agent.md'
            New-Item -ItemType Directory -Path '.github/skills/shared/sample-skill' -Force | Out-Null
            'skill body' | Set-Content -LiteralPath '.github/skills/shared/sample-skill/SKILL.md'
            'unrelated change' | Set-Content -LiteralPath 'docs.md'
            & git add . 2>&1 | Out-Null
            & git commit --quiet -m 'add artifacts' 2>&1 | Out-Null
            $headSha = (& git rev-parse HEAD).Trim()

            $outFile = Join-Path $TestDrive ('manifest-' + [Guid]::NewGuid() + '.json')
            & pwsh -NoProfile -File $script:ScriptPath `
                -BaseRef $baseSha -HeadRef $headSha -OutFile $outFile -RepoRoot $repo *> $null
            $LASTEXITCODE | Should -Be 0

            $manifest = Get-Content -LiteralPath $outFile -Raw | ConvertFrom-Json
            $manifest.artifacts.Count | Should -Be 2

            $kinds = @($manifest.artifacts | ForEach-Object { $_.kind } | Sort-Object -Unique)
            $kinds | Should -Contain 'agent'
            $kinds | Should -Contain 'skill'

            $agentEntry = $manifest.artifacts | Where-Object { $_.kind -eq 'agent' }
            $agentEntry.artifactId | Should -Be 'new-agent'
            $agentEntry.status | Should -Be 'A'

            $skillEntry = $manifest.artifacts | Where-Object { $_.kind -eq 'skill' }
            $skillEntry.artifactId | Should -Be 'sample-skill'
            $skillEntry.status | Should -Be 'A'

            $manifest.PSObject.Properties.Name | Should -Contain 'affectedAgents'
            @($manifest.affectedAgents) | Should -Contain 'new-agent'
        }
        finally {
            Pop-Location
        }
    }
}
