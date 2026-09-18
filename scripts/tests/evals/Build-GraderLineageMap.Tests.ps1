#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $script:ScriptPath = Join-Path $script:RepoRoot 'scripts/evals/Build-GraderLineageMap.ps1'

    Import-Module powershell-yaml -ErrorAction Stop
    . $script:ScriptPath
}

Describe 'Build-GraderLineageMap.ps1' -Tag 'Unit' {
    It 'Checks the deterministic revision-bound migration contract without historical Git objects' {
        $first = Invoke-GraderLineageMap -RepoRoot $script:RepoRoot -Check
        $second = Invoke-GraderLineageMap -RepoRoot $script:RepoRoot -Check

        $first.Outcome | Should -BeExactly 'NoDrift'
        $first.Counts.sourceToTargetPairs | Should -Be 1240
        $first.Counts.authoredAliases | Should -Be 414
        $first.Counts.generatedCopies | Should -Be 171
        $first.Counts.semanticChanges | Should -Be 0
        ($second.Counts | ConvertTo-Json -Compress) | Should -BeExactly ($first.Counts | ConvertTo-Json -Compress)
    }

    It 'Maps authored grader type <GraderType> to result kind <ExpectedKind>' -ForEach @(
        @{ GraderType = 'diff-empty'; ExpectedKind = 'code' }
        @{ GraderType = 'file-exists'; ExpectedKind = 'code' }
        @{ GraderType = 'file-matches'; ExpectedKind = 'code' }
        @{ GraderType = 'file-not-exists'; ExpectedKind = 'code' }
        @{ GraderType = 'file-not-matches'; ExpectedKind = 'code' }
        @{ GraderType = 'output-matches'; ExpectedKind = 'code' }
        @{ GraderType = 'output-contains'; ExpectedKind = 'code' }
        @{ GraderType = 'tool-calls'; ExpectedKind = 'code' }
        @{ GraderType = 'transcript-matches'; ExpectedKind = 'code' }
        @{ GraderType = 'wall-time'; ExpectedKind = 'code' }
        @{ GraderType = 'prompt'; ExpectedKind = 'llm' }
        @{ GraderType = 'human'; ExpectedKind = 'human' }
    ) {
        Get-GraderResultKind -GraderType $GraderType | Should -BeExactly $ExpectedKind
    }

    It 'Rejects ambiguous and semantic source-to-target pairs' {
        $record = [pscustomobject]@{
            PairKey = 'source|stimulus|digest'
            GraderType = 'output-matches'
            ResultKind = 'code'
            Name = 'old-name'
        }
        $target = [pscustomobject]@{
            PairKey = 'source|stimulus|digest'
            GraderType = 'output-matches'
            ResultKind = 'code'
            Name = 'new-name'
        }
        $semanticChange = [pscustomobject]@{
            PairKey = 'source|stimulus|other-digest'
            GraderType = 'output-matches'
            ResultKind = 'code'
            Name = 'new-name'
        }

        { Compare-GraderLineageRecords -SourceRecords @($record, $record) -TargetRecords @($target, $target) } |
            Should -Throw -ExpectedMessage '*Ambiguous source grader pair*'
        { Compare-GraderLineageRecords -SourceRecords @($record) -TargetRecords @($semanticChange) } |
            Should -Throw -ExpectedMessage '*Semantic grader change*'
    }

    It 'Rejects unreachable revisions, non-ancestor revisions, and provenance drift' {
        if ($null -eq (Get-Command git -ErrorAction SilentlyContinue)) {
            Set-ItResult -Skipped -Because 'git executable not available in test environment'
            return
        }

        # A disposable repository gives the assertion known ancestry. The committed map's
        # revisions come from a squash-merged branch, so they are reachable by object ID
        # but are never ancestors of the current HEAD and cannot exercise the drift path.
        $repo = Join-Path $TestDrive ('lineage-' + [Guid]::NewGuid())
        New-Item -ItemType Directory -Path $repo | Out-Null
        $lineageFile = Join-Path $repo 'evals/baseline-equivalence/stimuli.yml'
        New-Item -ItemType Directory -Path (Split-Path -Parent $lineageFile) -Force | Out-Null

        & git -C $repo init --quiet --initial-branch=main 2>&1 | Out-Null
        & git -C $repo config user.email 'test@example.com' 2>&1 | Out-Null
        & git -C $repo config user.name 'Test User' 2>&1 | Out-Null
        & git -C $repo config commit.gpgsign false 2>&1 | Out-Null

        'stimuli: []' | Set-Content -LiteralPath $lineageFile
        & git -C $repo add . 2>&1 | Out-Null
        & git -C $repo commit --quiet -m 'provenance' 2>&1 | Out-Null
        $provenance = (& git -C $repo rev-parse HEAD).Trim()

        'stimuli: [renamed]' | Set-Content -LiteralPath $lineageFile
        & git -C $repo commit --quiet -am 'lineage drift' 2>&1 | Out-Null
        $drifted = (& git -C $repo rev-parse HEAD).Trim()

        'unrelated' | Set-Content -LiteralPath (Join-Path $repo 'README.md')
        & git -C $repo add . 2>&1 | Out-Null
        & git -C $repo commit --quiet -m 'target' 2>&1 | Out-Null
        $target = (& git -C $repo rev-parse HEAD).Trim()

        & git -C $repo checkout --quiet -b side $provenance 2>&1 | Out-Null
        'side' | Set-Content -LiteralPath (Join-Path $repo 'side.md')
        & git -C $repo add . 2>&1 | Out-Null
        & git -C $repo commit --quiet -m 'side' 2>&1 | Out-Null
        $sideCommit = (& git -C $repo rev-parse HEAD).Trim()
        & git -C $repo checkout --quiet main 2>&1 | Out-Null

        {
            Assert-GraderLineageRevisions -RepoRoot $repo `
                -SourceProvenanceRevision $provenance `
                -SourceRevision ('0' * 40) `
                -TargetRevision $target
        } | Should -Throw -ExpectedMessage '*Git command failed*'

        {
            Assert-GraderLineageRevisions -RepoRoot $repo `
                -SourceProvenanceRevision $provenance `
                -SourceRevision $sideCommit `
                -TargetRevision $target
        } | Should -Throw -ExpectedMessage '*is not an ancestor of replacement head*'

        {
            Assert-GraderLineageRevisions -RepoRoot $repo `
                -SourceProvenanceRevision $drifted `
                -SourceRevision $provenance `
                -TargetRevision $target
        } | Should -Throw -ExpectedMessage '*does not match provenance*'

        {
            Assert-GraderLineageRevisions -RepoRoot $repo `
                -SourceProvenanceRevision $provenance `
                -SourceRevision $provenance `
                -TargetRevision $target
        } | Should -Not -Throw
    }
}
