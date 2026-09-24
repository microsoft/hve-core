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
        @{ GraderType = 'program'; ExpectedKind = 'code' }
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
        # Repository history cannot carry this contract: the revisions it would
        # need stop being ancestors of HEAD once their branch is squash-merged.
        $fixture = Join-Path ([System.IO.Path]::GetTempPath()) ((New-Guid).Guid)
        $stimulus = Join-Path $fixture 'evals/agent-behavior/stimuli'
        try {
            New-Item -ItemType Directory -Path $stimulus -Force | Out-Null
            & git -C $fixture -c init.defaultBranch=main init --quiet
            & git -C $fixture config user.email 'lineage@example.invalid'
            & git -C $fixture config user.name 'Lineage Fixture'

            $seed = Join-Path $stimulus 'seed.yml'
            Set-Content -LiteralPath $seed -Value 'graders: []' -Encoding utf8
            & git -C $fixture add -A
            & git -C $fixture commit --quiet -m 'provenance'
            $provenance = (& git -C $fixture rev-parse HEAD).Trim()

            Set-Content -LiteralPath $seed -Value 'graders: [drifted]' -Encoding utf8
            & git -C $fixture add -A
            & git -C $fixture commit --quiet -m 'source'
            $source = (& git -C $fixture rev-parse HEAD).Trim()

            Set-Content -LiteralPath $seed -Value 'graders: [target]' -Encoding utf8
            & git -C $fixture add -A
            & git -C $fixture commit --quiet -m 'target'
            $target = (& git -C $fixture rev-parse HEAD).Trim()

            # A revision that exists nowhere fails the object check first.
            {
                Assert-GraderLineageRevisions -RepoRoot $fixture `
                    -SourceProvenanceRevision $provenance `
                    -SourceRevision ('0' * 40) `
                    -TargetRevision $target
            } | Should -Throw -ExpectedMessage '*Git command failed*'

            # A real commit on an unmerged side branch is not an ancestor of HEAD.
            & git -C $fixture checkout --quiet -b side $provenance
            Set-Content -LiteralPath $seed -Value 'graders: [side]' -Encoding utf8
            & git -C $fixture add -A
            & git -C $fixture commit --quiet -m 'side'
            $side = (& git -C $fixture rev-parse HEAD).Trim()
            & git -C $fixture checkout --quiet main

            {
                Assert-GraderLineageRevisions -RepoRoot $fixture `
                    -SourceProvenanceRevision $provenance `
                    -SourceRevision $side `
                    -TargetRevision $target
            } | Should -Throw -ExpectedMessage '*is not an ancestor of replacement head*'

            # Reachable and correctly ordered, but the source drifted from provenance.
            {
                Assert-GraderLineageRevisions -RepoRoot $fixture `
                    -SourceProvenanceRevision $provenance `
                    -SourceRevision $source `
                    -TargetRevision $target
            } | Should -Throw -ExpectedMessage '*does not match provenance*'

            # The same inputs pass once provenance matches the source revision.
            {
                Assert-GraderLineageRevisions -RepoRoot $fixture `
                    -SourceProvenanceRevision $source `
                    -SourceRevision $source `
                    -TargetRevision $target
            } | Should -Not -Throw
        }
        finally {
            if (Test-Path $fixture) {
                & git -C $fixture gc --quiet --prune=now 2>$null
                Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
