#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $script:ScriptPath = Join-Path $script:RepoRoot 'scripts/evals/Build-GraderLineageMap.ps1'
    $script:SourceRevision = 'b4c940cc4067d9b2addbba48ea15e599f4c825c4'
    $script:TargetRevision = '0b8762fe0003396557820bd6093d88a932047033'
    $script:ProvenanceRevision = 'ce4c686f8906288db28ccf8a1108c26e2ea52bd9'

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

    It 'Rejects unreachable revisions and provenance drift' {
        {
            Assert-GraderLineageRevisions -RepoRoot $script:RepoRoot `
                -SourceProvenanceRevision $script:ProvenanceRevision `
                -SourceRevision ('0' * 40) `
                -TargetRevision $script:TargetRevision
        } | Should -Throw -ExpectedMessage '*Git command failed*'

        {
            Assert-GraderLineageRevisions -RepoRoot $script:RepoRoot `
                -SourceProvenanceRevision $script:TargetRevision `
                -SourceRevision $script:SourceRevision `
                -TargetRevision $script:TargetRevision
        } | Should -Throw -ExpectedMessage '*does not match provenance*'
    }
}
