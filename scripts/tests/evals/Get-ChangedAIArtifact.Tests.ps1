#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '../../evals/Modules/ArtifactDetection.psm1'
    $script:ScriptPath = Join-Path $PSScriptRoot '../../evals/Get-ChangedAIArtifact.ps1'

    Import-Module $script:ModulePath -Force
    Import-Module (Join-Path $PSScriptRoot '../../evals/Modules/EvalChangeSet.psm1') -Force
    . $script:ScriptPath
}

Describe 'ArtifactDetection module' -Tag 'Unit' {
    Context 'Get-ArtifactDescriptor' {
        It 'Classifies nested agent artifacts' {
            $result = Get-ArtifactDescriptor -Path '.github/agents/hve-core/sample-agent.agent.md'
            $result.kind | Should -Be 'agent'
            $result.artifactId | Should -Be 'sample-agent'
            $result.path | Should -Be '.github/agents/hve-core/sample-agent.agent.md'
        }

        It 'Classifies repo-root-only agent artifacts (no collection subdirectory)' {
            $result = Get-ArtifactDescriptor -Path '.github/agents/local-only.agent.md'
            $result.kind | Should -Be 'agent'
            $result.artifactId | Should -Be 'local-only'
        }

        It 'Classifies prompt artifacts' {
            $result = Get-ArtifactDescriptor -Path '.github/prompts/hve-core/sample-prompt.prompt.md'
            $result.kind | Should -Be 'prompt'
            $result.artifactId | Should -Be 'sample-prompt'
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
            $result = Get-ArtifactDescriptor -Path '.github\agents\hve-core\sample-agent.agent.md'
            $result.kind | Should -Be 'agent'
            $result.path | Should -Be '.github/agents/hve-core/sample-agent.agent.md'
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

Describe 'Get-ChangedAIArtifact.ps1 entry script' -Tag 'Unit' {
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
            # The default equivalence subject must resolve to exactly one agent file.
            'rpi agent' | Set-Content -LiteralPath '.github/agents/hve-core/rpi-agent.agent.md'
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
            $changeSetPath = Join-Path $TestDrive 'change-set.json'
            New-EvalChangeSet -BaseRef $baseSha -HeadRef $headSha -RepoRoot $repo |
                ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $changeSetPath
            & pwsh -NoProfile -File $script:ScriptPath `
                -ChangeSetPath $changeSetPath -OutFile $outFile -RepoRoot $repo *> $null
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
            Get-ChildItem -LiteralPath $repo -Recurse -Force -File | ForEach-Object { $_.IsReadOnly = $false }
        }
    }
}

Describe 'AI artifact canonical input' -Tag 'Unit' {
    BeforeEach {
        $script:ChangeSetPath = Join-Path $TestDrive 'selection.json'
        $script:Selection = @{
            schemaVersion = '1.0'; baseRef = 'a' * 40; headRef = 'b' * 40; comparisonBase = 'c' * 40
            changes = @()
        }
    }

    It 'preserves resolved revision metadata in an empty artifact manifest' {
        $script:Selection | ConvertTo-Json -Depth 6 | Set-Content $script:ChangeSetPath
        $result = Invoke-ChangedArtifactScan -ChangeSetPath $script:ChangeSetPath -RepoRoot $TestDrive
        $result.artifacts | Should -HaveCount 0
        $result.affectedAgents | Should -HaveCount 0
        $result.baseRef | Should -Be ('a' * 40)
        $result.headRef | Should -Be ('b' * 40)
    }

    It 'does not select upstream artifacts present only in the checkout' {
        $script:Selection.changes = @(@{ status = 'M'; path = 'CONTRIBUTING.md'; previousPath = $null })
        $script:Selection | ConvertTo-Json -Depth 6 | Set-Content $script:ChangeSetPath
        $agentDir = Join-Path $TestDrive '.github/agents/core'
        $null = New-Item -ItemType Directory -Path $agentDir -Force
        Set-Content (Join-Path $agentDir 'upstream.agent.md') 'upstream'
        $result = Invoke-ChangedArtifactScan -ChangeSetPath $script:ChangeSetPath -RepoRoot $TestDrive -EquivalenceSubject @()
        $result.artifacts | Should -HaveCount 0
        $result.affectedAgents | Should -HaveCount 0
    }

    It 'rejects malformed and missing manifests rather than creating empty evidence' {
        '{"schemaVersion":"1.0"}' | Set-Content $script:ChangeSetPath
        { Invoke-ChangedArtifactScan -ChangeSetPath $script:ChangeSetPath -RepoRoot $TestDrive } | Should -Throw
        { Invoke-ChangedArtifactScan -ChangeSetPath (Join-Path $TestDrive 'missing.json') -RepoRoot $TestDrive } | Should -Throw
    }
}

Describe 'Equivalence surface gate' -Tag 'Unit' {
    BeforeAll {
        # The subject names its skill in backticks, as the real RPI agent does, so the
        # path-only dependency map records no skill for it.
        $script:SurfaceRepo = Join-Path $TestDrive ('surface-' + [Guid]::NewGuid().ToString('N'))
        $agentDir = Join-Path $script:SurfaceRepo '.github/agents/hve-core'
        $null = New-Item -ItemType Directory -Path $agentDir -Force
        Set-Content -LiteralPath (Join-Path $agentDir 'rpi-agent.agent.md') -Value "---`nname: RPI Agent`n---`n`nActivate ``rpi-research`` first.`n"
        foreach ($skill in @('rpi/rpi-research', 'shared/unrelated')) {
            $skillDir = Join-Path $script:SurfaceRepo ".github/skills/$skill"
            $null = New-Item -ItemType Directory -Path (Join-Path $skillDir 'references') -Force
            Set-Content -LiteralPath (Join-Path $skillDir 'SKILL.md') -Value 'skill'
            Set-Content -LiteralPath (Join-Path $skillDir 'references/notes.md') -Value 'notes'
        }

        $script:ScanChange = {
            param([string]$Path, [string[]]$Subject = @('rpi-agent'))

            $changeSetPath = Join-Path $TestDrive ('surface-change-' + [Guid]::NewGuid().ToString('N') + '.json')
            @{
                schemaVersion = '1.0'; baseRef = 'a' * 40; headRef = 'b' * 40; comparisonBase = 'c' * 40
                changes = @(@{ status = 'M'; path = $Path; previousPath = $null })
            } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $changeSetPath
            return Invoke-ChangedArtifactScan -ChangeSetPath $changeSetPath -RepoRoot $script:SurfaceRepo -EquivalenceSubject $Subject
        }
    }

    It 'marks the subject affected when a backtick-named skill changes' {
        $result = & $script:ScanChange '.github/skills/rpi/rpi-research/SKILL.md'
        @($result.affectedAgents) | Should -BeExactly @('rpi-agent')
    }

    It 'marks the subject affected when a file inside that skill directory changes' {
        $result = & $script:ScanChange '.github/skills/rpi/rpi-research/references/notes.md'
        @($result.affectedAgents) | Should -BeExactly @('rpi-agent')
    }

    It 'leaves the subject unaffected by a skill outside its surface' {
        $result = & $script:ScanChange '.github/skills/shared/unrelated/SKILL.md'
        $result.affectedAgents | Should -HaveCount 0
    }

    It 'checks only the configured equivalence subjects' {
        $result = & $script:ScanChange '.github/skills/rpi/rpi-research/SKILL.md' @()
        $result.affectedAgents | Should -HaveCount 0
    }

    It 'fails closed when a subject matches no agent file' {
        { & $script:ScanChange '.github/skills/rpi/rpi-research/SKILL.md' @('rpi-agnet') } |
            Should -Throw -ExpectedMessage "*'rpi-agnet' matches no agent file*"
    }

    It 'fails closed when a subject matches more than one agent file' {
        $duplicateDir = Join-Path $script:SurfaceRepo '.github/agents/other'
        $null = New-Item -ItemType Directory -Path $duplicateDir -Force
        Set-Content -LiteralPath (Join-Path $duplicateDir 'rpi-agent.agent.md') -Value 'duplicate'
        try {
            { & $script:ScanChange '.github/skills/rpi/rpi-research/SKILL.md' } |
                Should -Throw -ExpectedMessage "*'rpi-agent' matches 2 agent files*"
        }
        finally {
            Remove-Item -LiteralPath $duplicateDir -Recurse -Force
        }
    }

    It 'writes no manifest when the entry script meets a <Case> subject' -ForEach @(
        @{ Case = 'missing'; Subject = 'rpi-agnet' }
        @{ Case = 'duplicate'; Subject = 'rpi-agent' }
    ) {
        $duplicateDir = Join-Path $script:SurfaceRepo '.github/agents/other'
        if ($Case -eq 'duplicate') {
            $null = New-Item -ItemType Directory -Path $duplicateDir -Force
            Set-Content -LiteralPath (Join-Path $duplicateDir 'rpi-agent.agent.md') -Value 'duplicate'
        }
        try {
            $changeSetPath = Join-Path $TestDrive ('entry-change-' + [Guid]::NewGuid().ToString('N') + '.json')
            @{
                schemaVersion = '1.0'; baseRef = 'a' * 40; headRef = 'b' * 40; comparisonBase = 'c' * 40
                changes = @(@{ status = 'M'; path = '.github/skills/rpi/rpi-research/SKILL.md'; previousPath = $null })
            } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $changeSetPath
            $outFile = Join-Path $TestDrive ('entry-manifest-' + [Guid]::NewGuid().ToString('N') + '.json')

            & pwsh -NoProfile -File $script:ScriptPath -ChangeSetPath $changeSetPath -OutFile $outFile `
                -RepoRoot $script:SurfaceRepo -EquivalenceSubject $Subject *> $null

            $LASTEXITCODE | Should -Be 2
            Test-Path -LiteralPath $outFile | Should -BeFalse
        }
        finally {
            Remove-Item -LiteralPath $duplicateDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Equivalence surface gate at the comparison base' -Tag 'Unit' {
    BeforeAll {
        # Commits a base where the subject names `rpi-research` in backticks, applies
        # one change in a second commit, and scans the resulting canonical change set.
        $script:ScanCommittedChange = {
            param([scriptblock]$Mutation)

            $repo = Join-Path $TestDrive ('base-' + [Guid]::NewGuid().ToString('N'))
            $agentDir = Join-Path $repo '.github/agents/hve-core'
            $null = New-Item -ItemType Directory -Path $agentDir -Force
            Set-Content -LiteralPath (Join-Path $agentDir 'rpi-agent.agent.md') -Value "---`nname: RPI Agent`n---`n`nActivate ``rpi-research`` first.`n"
            foreach ($skill in @('rpi/rpi-research', 'shared/unrelated')) {
                $skillDir = Join-Path $repo ".github/skills/$skill"
                $null = New-Item -ItemType Directory -Path (Join-Path $skillDir 'references') -Force
                Set-Content -LiteralPath (Join-Path $skillDir 'SKILL.md') -Value "skill $skill"
                Set-Content -LiteralPath (Join-Path $skillDir 'references/notes.md') -Value "notes $skill"
            }

            $git = @{ RepoRoot = $repo }
            $null = Invoke-EvalGit @git -Arguments @('init', '--quiet', '--initial-branch=main')
            $null = Invoke-EvalGit @git -Arguments @('config', 'user.email', 'test@example.com')
            $null = Invoke-EvalGit @git -Arguments @('config', 'user.name', 'Test User')
            $null = Invoke-EvalGit @git -Arguments @('config', 'commit.gpgsign', 'false')
            $null = Invoke-EvalGit @git -Arguments @('add', '-A')
            $null = Invoke-EvalGit @git -Arguments @('commit', '--quiet', '-m', 'base')
            $baseSha = (Invoke-EvalGit @git -Arguments @('rev-parse', 'HEAD')).Trim()

            & $Mutation $repo
            $null = Invoke-EvalGit @git -Arguments @('add', '-A')
            $null = Invoke-EvalGit @git -Arguments @('commit', '--quiet', '-m', 'change')
            $headSha = (Invoke-EvalGit @git -Arguments @('rev-parse', 'HEAD')).Trim()

            $changeSet = New-EvalChangeSet -BaseRef $baseSha -HeadRef $headSha -RepoRoot $repo
            $changeSetPath = Join-Path $TestDrive ('base-change-' + [Guid]::NewGuid().ToString('N') + '.json')
            $changeSet | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $changeSetPath
            return @{
                ChangeSet = $changeSet
                Result    = Invoke-ChangedArtifactScan -ChangeSetPath $changeSetPath -RepoRoot $repo
            }
        }
    }

    It 'marks the subject affected when its backtick-named skill is deleted' {
        $scan = & $script:ScanCommittedChange {
            param($Repo)
            Remove-Item -LiteralPath (Join-Path $Repo '.github/skills/rpi/rpi-research') -Recurse -Force
        }

        @($scan.ChangeSet.changes.status | Sort-Object -Unique) | Should -BeExactly @('D')
        @($scan.Result.affectedAgents) | Should -BeExactly @('rpi-agent')
    }

    It 'marks the subject affected when its backtick-named skill is renamed away' {
        $scan = & $script:ScanCommittedChange {
            param($Repo)
            $null = New-Item -ItemType Directory -Path (Join-Path $Repo '.github/skills/archive') -Force
            $null = Invoke-EvalGit -RepoRoot $Repo -Arguments @('mv', '.github/skills/rpi/rpi-research', '.github/skills/archive/old-research')
        }

        @($scan.ChangeSet.changes.status | Sort-Object -Unique) | Should -BeExactly @('R')
        @($scan.ChangeSet.changes.previousPath) | Should -Contain '.github/skills/rpi/rpi-research/SKILL.md'
        @($scan.Result.affectedAgents) | Should -BeExactly @('rpi-agent')
    }

    It 'leaves the subject unaffected when a skill outside its surface is deleted' {
        $scan = & $script:ScanCommittedChange {
            param($Repo)
            Remove-Item -LiteralPath (Join-Path $Repo '.github/skills/shared/unrelated') -Recurse -Force
        }

        @($scan.ChangeSet.changes.status | Sort-Object -Unique) | Should -BeExactly @('D')
        $scan.Result.affectedAgents | Should -HaveCount 0
    }
}

Describe 'AI artifact full-scope input' -Tag 'Unit' {
    BeforeAll {
        $script:FullScopeRepo = Join-Path $TestDrive ('full-' + [Guid]::NewGuid())
        $null = New-Item -ItemType Directory -Path (Join-Path $script:FullScopeRepo '.github/agents/core') -Force
        $null = New-Item -ItemType Directory -Path (Join-Path $script:FullScopeRepo '.github/prompts/core') -Force
        & git -C $script:FullScopeRepo init --quiet --initial-branch=main 2>&1 | Out-Null
        & git -C $script:FullScopeRepo config user.email 'test@example.com' 2>&1 | Out-Null
        & git -C $script:FullScopeRepo config user.name 'Test User' 2>&1 | Out-Null
        & git -C $script:FullScopeRepo config commit.gpgsign false 2>&1 | Out-Null
        Set-Content (Join-Path $script:FullScopeRepo '.github/agents/core/tracked.agent.md') 'agent'
        Set-Content (Join-Path $script:FullScopeRepo '.github/prompts/core/tracked.prompt.md') 'prompt'
        Set-Content (Join-Path $script:FullScopeRepo 'README.md') 'readme'
        & git -C $script:FullScopeRepo add . 2>&1 | Out-Null
        & git -C $script:FullScopeRepo commit --quiet -m 'tracked' 2>&1 | Out-Null
        Set-Content (Join-Path $script:FullScopeRepo '.github/agents/core/untracked.agent.md') 'untracked'
        $script:FullScopeHead = (& git -C $script:FullScopeRepo rev-parse HEAD).Trim()
    }

    It 'classifies every tracked artifact as added without a change set' {
        $result = Invoke-ChangedArtifactScan -AllTracked -RepoRoot $script:FullScopeRepo -EquivalenceSubject @()

        $result.baseRef | Should -BeNullOrEmpty
        $result.headRef | Should -BeExactly $script:FullScopeHead
        @($result.artifacts.path | Sort-Object) | Should -BeExactly @('.github/agents/core/tracked.agent.md', '.github/prompts/core/tracked.prompt.md')
        @($result.artifacts.status | Sort-Object -Unique) | Should -BeExactly @('A')
        @($result.affectedAgents) | Should -Contain 'tracked'
    }

    It 'rejects combining the full-scope option with a change set' {
        $outFile = Join-Path $TestDrive 'exclusive.json'
        & pwsh -NoProfile -File $script:ScriptPath -AllTracked -ChangeSetPath 'logs/eval-change-set.json' -OutFile $outFile -RepoRoot $script:FullScopeRepo *> $null

        $LASTEXITCODE | Should -Not -Be 0
        Test-Path -LiteralPath $outFile | Should -BeFalse
    }
}
