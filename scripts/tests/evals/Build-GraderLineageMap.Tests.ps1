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
        $first.Counts.authoredAliases | Should -Be 397
        $first.Counts.generatedCopies | Should -Be 171
        $first.Counts.semanticChanges | Should -Be 0
        ($second.Counts | ConvertTo-Json -Compress) | Should -BeExactly ($first.Counts | ConvertTo-Json -Compress)
    }

    It 'Rejects replacing mapped code checks with a different result kind' {
        $realResultKind = Get-Command -Name Get-GraderResultKind -CommandType Function
        Mock Get-GraderResultKind { & $realResultKind @PesterBoundParameters }
        Mock Get-GraderResultKind { 'llm' } -ParameterFilter { $GraderType -eq 'program' }
        { Invoke-GraderLineageMap -RepoRoot $script:RepoRoot -Check } | Should -Throw '*Mapped current grader*was not found*'
    }

    It 'Maps authored grader type <GraderType> to result kind <ExpectedKind>' -ForEach @(
        @{ GraderType = 'diff-contains'; ExpectedKind = 'code' }
        @{ GraderType = 'diff-empty'; ExpectedKind = 'code' }
        @{ GraderType = 'diff-not-contains'; ExpectedKind = 'code' }
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

    It 'Applies the reply-to-code replacement rule for target type <TargetType>' -ForEach @(
        @{ TargetType = 'output-matches'; Allowed = $true }
        @{ TargetType = 'program'; Allowed = $true }
        @{ TargetType = 'diff-not-contains'; Allowed = $true }
        @{ TargetType = 'diff-empty'; Allowed = $false }
    ) {
        $map = Get-Content -Raw -LiteralPath (Join-Path $script:RepoRoot 'evals/migrations/vally-0.16-grader-name-aliases.json') | ConvertFrom-Json
        $paths = @($map.aliases.source | Sort-Object -Unique)
        $records = @(Get-CurrentGraderLineageRecords -RepoRoot $script:RepoRoot -Paths $paths | ForEach-Object { $_.PSObject.Copy() })
        $alias = @($map.aliases | Where-Object { $_.graderType -eq 'output-matches' })[0]
        $target = @($records | Where-Object { $_.Source -eq $alias.source -and $_.Stimulus -eq $alias.stimulus -and $_.Name -eq $alias.newName })
        $target | Should -HaveCount 1
        $target[0].GraderType = $TargetType
        $script:LineageRecords = $records
        Mock Get-CurrentGraderLineageRecords { $script:LineageRecords }

        if ($Allowed) {
            (Test-CommittedGraderLineageMap -RepoRoot $script:RepoRoot -Map $map).authoredAliases | Should -Be 397
        }
        else {
            { Test-CommittedGraderLineageMap -RepoRoot $script:RepoRoot -Map $map } | Should -Throw '*incompatible type drift*'
        }
    }

    Context 'Explicit committed-map retirement' {
        BeforeEach {
            $activeMap = Get-Content -Raw -LiteralPath (Join-Path $script:RepoRoot $script:LineageMapPath) | ConvertFrom-Json
            $script:ActiveMapJson = $activeMap | ConvertTo-Json -Depth 20 -Compress
            $script:RetirementMap = $script:ActiveMapJson | ConvertFrom-Json
            $number = 0
            foreach ($source in @('code-review.yml', 'code-review-standards.yml')) {
                $alias = $activeMap.aliases[0].PSObject.Copy()
                $alias.source = "evals/agent-behavior/stimuli/$source"
                $alias.stimulus = 'retired-lineage-case'
                $alias.oldName = "retired-old-$number"
                $alias.newName = "retired-new-$number"
                $script:RetirementMap.aliases += $alias
                $number++
            }
            $script:RetirementMap.counts.authoredAliases = $script:RetirementMap.aliases.Count
            $script:RetirementMap.mapSha256 = Get-LineageSha256 -Text ($script:RetirementMap.aliases | ConvertTo-Json -Depth 20 -Compress)
            $script:RetirementOutput = Join-Path $TestDrive 'retirement.json'
            [System.IO.File]::WriteAllText($script:RetirementOutput, ($script:RetirementMap | ConvertTo-Json -Depth 20))

            Mock Invoke-LineageGit { throw "Unexpected Git request: $($Arguments -join ' ')" }
            Mock Invoke-LineageGit { $script:RetirementMap | ConvertTo-Json -Depth 20 } -ParameterFilter {
                $Arguments.Count -eq 2 -and $Arguments[0] -eq 'show' -and
                $Arguments[1] -eq "HEAD:$($script:LineageMapPath)"
            }
            Mock Assert-GraderLineageRevisions { throw 'Historical regeneration is unavailable.' }
        }

        It 'Prunes only listed aliases, preserves all other map data, and is idempotent without historical objects' {
            $originalMapJson = $script:RetirementMap | ConvertTo-Json -Depth 20 -Compress
            $result = Invoke-GraderLineageMap -RepoRoot $script:RepoRoot -OutputPath $script:RetirementOutput -Retire
            $result.Outcome | Should -BeExactly 'Retired'
            $result.RetiredAliases | Should -Be 2
            $result.Counts.authoredAliases | Should -Be 397
            $actual = Get-Content -Raw -LiteralPath $script:RetirementOutput | ConvertFrom-Json
            ($actual | ConvertTo-Json -Depth 20 -Compress) | Should -BeExactly $script:ActiveMapJson
            ($script:RetirementMap | ConvertTo-Json -Depth 20 -Compress) | Should -BeExactly $originalMapJson

            $bytesAfterRetirement = [System.IO.File]::ReadAllText($script:RetirementOutput)
            (Invoke-GraderLineageMap -RepoRoot $script:RepoRoot -OutputPath $script:RetirementOutput -Retire).Outcome |
                Should -BeExactly 'NoDrift'
            (Invoke-GraderLineageMap -RepoRoot $script:RepoRoot -OutputPath $script:RetirementOutput -Check).Outcome |
                Should -BeExactly 'NoDrift'
            [System.IO.File]::ReadAllText($script:RetirementOutput) | Should -BeExactly $bytesAfterRetirement
            Should -Invoke Assert-GraderLineageRevisions -Times 0 -Exactly
        }

        It 'Previews retirement without modifying the map' {
            $before = [System.IO.File]::ReadAllText($script:RetirementOutput)
            (Invoke-GraderLineageMap -RepoRoot $script:RepoRoot -OutputPath $script:RetirementOutput -Retire -WhatIf).Outcome |
                Should -BeExactly 'WhatIf'
            [System.IO.File]::ReadAllText($script:RetirementOutput) | Should -BeExactly $before
        }

        It 'Leaves an unretired map unchanged during the non-mutating check' {
            $before = [System.IO.File]::ReadAllText($script:RetirementOutput)
            { Invoke-GraderLineageMap -RepoRoot $script:RepoRoot -OutputPath $script:RetirementOutput -Check } |
                Should -Throw '*counts are invalid*'
            [System.IO.File]::ReadAllText($script:RetirementOutput) | Should -BeExactly $before
            Should -Invoke Invoke-LineageGit -Times 0 -Exactly
        }

        It 'Refuses uncommitted changes outside the exact retirement projection' {
            $changedMap = Get-Content -Raw -LiteralPath $script:RetirementOutput | ConvertFrom-Json
            $changedMap.sourceRevision = '1' * 40
            $before = $changedMap | ConvertTo-Json -Depth 20
            [System.IO.File]::WriteAllText($script:RetirementOutput, $before)
            { Invoke-GraderLineageMap -RepoRoot $script:RepoRoot -OutputPath $script:RetirementOutput -Retire } |
                Should -Throw '*refuses changes beyond the committed retirement projection*'
            [System.IO.File]::ReadAllText($script:RetirementOutput) | Should -BeExactly $before
        }

        It 'Rejects committed-map corruption in <Scenario> before writing' -ForEach @(
            @{ Scenario = 'identity'; Corrupt = { param($Map) $Map.migrationId = 'other-migration' }; Rehash = $false; ExpectedMessage = '*identity is invalid*' }
            @{ Scenario = 'historical pairs'; Corrupt = { param($Map) $Map.counts.sourceToTargetPairs-- }; Rehash = $false; ExpectedMessage = '*counts are invalid*' }
            @{ Scenario = 'active count'; Corrupt = { param($Map) $Map.counts.authoredAliases-- }; Rehash = $false; ExpectedMessage = '*counts are invalid*' }
            @{ Scenario = 'generated copies'; Corrupt = { param($Map) $Map.counts.generatedCopies-- }; Rehash = $false; ExpectedMessage = '*counts are invalid*' }
            @{ Scenario = 'semantic changes'; Corrupt = { param($Map) $Map.counts.semanticChanges = 1 }; Rehash = $false; ExpectedMessage = '*counts are invalid*' }
            @{ Scenario = 'alias digest'; Corrupt = { param($Map) $Map.mapSha256 = '0' * 64 }; Rehash = $false; ExpectedMessage = '*alias digest does not match*' }
            @{ Scenario = 'source digest'; Corrupt = { param($Map) $Map.sourceSpecSha256 = 'invalid' }; Rehash = $false; ExpectedMessage = '*invalid digest*' }
            @{ Scenario = 'source revision'; Corrupt = { param($Map) $Map.sourceRevision = 'invalid' }; Rehash = $false; ExpectedMessage = '*invalid revision*' }
            @{ Scenario = 'retired historical key'; Corrupt = { param($Map) $Map.aliases[-1].oldName = $Map.aliases[-2].oldName }; Rehash = $true; ExpectedMessage = '*Duplicate historical composite key*' }
            @{ Scenario = 'retired current key'; Corrupt = { param($Map) $Map.aliases[-1].newName = $Map.aliases[-2].newName }; Rehash = $true; ExpectedMessage = '*Duplicate current composite key*' }
            @{ Scenario = 'retired result kind'; Corrupt = { param($Map) $Map.aliases[-1].resultKind = 'human' }; Rehash = $true; ExpectedMessage = '*Result kind does not match grader type*' }
        ) {
            & $Corrupt $script:RetirementMap
            if ($Rehash) {
                $script:RetirementMap.mapSha256 = Get-LineageSha256 -Text ($script:RetirementMap.aliases | ConvertTo-Json -Depth 20 -Compress)
            }
            $before = $script:RetirementMap | ConvertTo-Json -Depth 20
            [System.IO.File]::WriteAllText($script:RetirementOutput, $before)
            { Invoke-GraderLineageMap -RepoRoot $script:RepoRoot -OutputPath $script:RetirementOutput -Retire } |
                Should -Throw $ExpectedMessage
            [System.IO.File]::ReadAllText($script:RetirementOutput) | Should -BeExactly $before
        }

        It 'Rejects an unlisted missing source instead of retiring it' {
            $script:RetirementMap.aliases[0].source = 'evals/agent-behavior/stimuli/unlisted-retirement.yml'
            $script:RetirementMap.mapSha256 = Get-LineageSha256 -Text ($script:RetirementMap.aliases | ConvertTo-Json -Depth 20 -Compress)
            $before = $script:RetirementMap | ConvertTo-Json -Depth 20
            [System.IO.File]::WriteAllText($script:RetirementOutput, $before)
            { Invoke-GraderLineageMap -RepoRoot $script:RepoRoot -OutputPath $script:RetirementOutput -Retire } |
                Should -Throw "*Current lineage input 'evals/agent-behavior/stimuli/unlisted-retirement.yml' was not found*"
            [System.IO.File]::ReadAllText($script:RetirementOutput) | Should -BeExactly $before
        }

        It 'Rejects a missing retained grader before writing' {
            $activeMap = $script:ActiveMapJson | ConvertFrom-Json
            $missingAlias = $activeMap.aliases[0]
            $paths = @($activeMap.aliases.source | Sort-Object -Unique)
            $script:IncompleteRecords = @(Get-CurrentGraderLineageRecords -RepoRoot $script:RepoRoot -Paths $paths | Where-Object {
                -not ($_.Source -eq $missingAlias.source -and $_.Stimulus -eq $missingAlias.stimulus -and $_.Name -eq $missingAlias.newName)
            })
            Mock Get-CurrentGraderLineageRecords { $script:IncompleteRecords }
            $before = [System.IO.File]::ReadAllText($script:RetirementOutput)
            { Invoke-GraderLineageMap -RepoRoot $script:RepoRoot -OutputPath $script:RetirementOutput -Retire } |
                Should -Throw '*Mapped current grader*was not found*'
            [System.IO.File]::ReadAllText($script:RetirementOutput) | Should -BeExactly $before
        }

        It 'Rejects mixing retirement with checking or historical revision overrides' {
            $before = [System.IO.File]::ReadAllText($script:RetirementOutput)
            { Invoke-GraderLineageMap -RepoRoot $script:RepoRoot -OutputPath $script:RetirementOutput -Retire -Check } |
                Should -Throw '*Parameter set cannot be resolved*'
            { Invoke-GraderLineageMap -RepoRoot $script:RepoRoot -OutputPath $script:RetirementOutput -Retire -SourceRevision ('1' * 40) } |
                Should -Throw '*Parameter set cannot be resolved*'
            [System.IO.File]::ReadAllText($script:RetirementOutput) | Should -BeExactly $before
        }
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
