#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '../../evals/lib/EquivalenceParsing.psm1'
    Import-Module $script:ModulePath -Force
    $script:FixturesRoot = Join-Path $PSScriptRoot 'fixtures/equivalence'
}

Describe 'Measure-CompareTrials' -Tag 'Unit' {
    BeforeAll {
        $script:Lines = Get-Content -LiteralPath (Join-Path $script:FixturesRoot 'vally-compare.log')
        $script:Tally = Measure-CompareTrials -Lines $script:Lines
    }

    It 'Counts the total number of trial rows' {
        $script:Tally.Total | Should -Be 4
    }

    It 'Counts ties' {
        $script:Tally.Ties | Should -Be 2
    }

    It 'Counts A wins' {
        $script:Tally.AWins | Should -Be 1
    }

    It 'Counts B wins' {
        $script:Tally.BWins | Should -Be 1
    }

    It 'Groups results per stimulus' {
        $script:Tally.PerStimulus.Keys | Should -Contain 'test-stim-a'
        $script:Tally.PerStimulus.Keys | Should -Contain 'test-stim-b'
        $script:Tally.PerStimulus['test-stim-a'].Ties | Should -Be 1
        $script:Tally.PerStimulus['test-stim-a'].AWins | Should -Be 1
        $script:Tally.PerStimulus['test-stim-b'].BWins | Should -Be 1
    }

    It 'Strips ANSI escapes before matching' {
        $ansiLine = " test-stim-c (trial 0)  $([char]0x1B)[32mtie$([char]0x1B)[0m     (score: 0.0)"
        $result = Measure-CompareTrials -Lines @($ansiLine)
        $result.Total | Should -Be 1
        $result.Ties | Should -Be 1
    }

    It 'Returns zeros for empty input' {
        $empty = Measure-CompareTrials -Lines @()
        $empty.Total | Should -Be 0
        $empty.Ties | Should -Be 0
    }
}

Describe 'Measure-InvariantFailures' -Tag 'Unit' {
    BeforeAll {
        $script:Lines = Get-Content -LiteralPath (Join-Path $script:FixturesRoot 'vally-compare.log')
        $script:Inv = Measure-InvariantFailures -Lines $script:Lines
    }

    It 'Counts every invariant row' {
        $script:Inv.Total | Should -Be 2
    }

    It 'Counts non-pass rows as failures' {
        $script:Inv.Failed | Should -Be 1
    }

    It 'Returns zeros for empty input' {
        $empty = Measure-InvariantFailures -Lines @()
        $empty.Total | Should -Be 0
        $empty.Failed | Should -Be 0
    }
}

Describe 'Get-VerdictFromAggregate' -Tag 'Unit' {
    It 'Returns fail when there are zero runs' {
        Get-VerdictFromAggregate -Runs 0 -Ties 0 -AWins 0 -BWins 0 -InvariantFailures 0 -DivergenceFailures 0 -Tier 'pr' | Should -Be 'fail'
    }

    It 'Returns pass when the tie ratio is at or above 0.80 and wins are symmetric' {
        Get-VerdictFromAggregate -Runs 10 -Ties 8 -AWins 1 -BWins 1 -InvariantFailures 0 -DivergenceFailures 0 -Tier 'pr' | Should -Be 'pass'
    }

    It 'Returns warn on PR when invariants fail' {
        Get-VerdictFromAggregate -Runs 10 -Ties 8 -AWins 1 -BWins 1 -InvariantFailures 1 -DivergenceFailures 0 -Tier 'pr' | Should -Be 'warn'
    }

    It 'Returns fail on nightly when invariants fail' {
        Get-VerdictFromAggregate -Runs 10 -Ties 8 -AWins 1 -BWins 1 -InvariantFailures 1 -DivergenceFailures 0 -Tier 'nightly' | Should -Be 'fail'
    }

    It 'Returns warn on PR when tie ratio is below 0.80' {
        Get-VerdictFromAggregate -Runs 10 -Ties 5 -AWins 3 -BWins 2 -InvariantFailures 0 -DivergenceFailures 0 -Tier 'pr' | Should -Be 'warn'
    }

    It 'Returns fail on nightly when tie ratio is below 0.80' {
        Get-VerdictFromAggregate -Runs 10 -Ties 5 -AWins 3 -BWins 2 -InvariantFailures 0 -DivergenceFailures 0 -Tier 'nightly' | Should -Be 'fail'
    }
}

Describe 'ConvertFrom-EquivalenceResults' -Tag 'Unit' {
    BeforeAll {
        $script:Records = ConvertFrom-EquivalenceResults -RunDir (Join-Path $script:FixturesRoot 'baseline') -WarningAction SilentlyContinue
    }

    It 'Loads one record per JSONL line' {
        $script:Records.Count | Should -Be 2
    }

    It 'Extracts the stimulus name' {
        ($script:Records | Where-Object { $_.stimulusName -eq 'test-stim-a' }).Count | Should -Be 1
    }

    It 'Numbers trials per stimulus starting at zero' {
        ($script:Records | Where-Object { $_.stimulusName -eq 'test-stim-a' }).trial | Should -Be 0
    }

    It 'Computes a deterministic output hash' {
        $a = ($script:Records | Where-Object { $_.stimulusName -eq 'test-stim-a' })[0]
        $a.outputHash | Should -Match '^[0-9a-f]{64}$'
    }

    It 'Captures metrics' {
        $a = ($script:Records | Where-Object { $_.stimulusName -eq 'test-stim-a' })[0]
        $a.wallTimeMs | Should -Be 100
        $a.totalTokens | Should -Be 50
    }

    It 'Buckets known grader kinds' {
        $a = ($script:Records | Where-Object { $_.stimulusName -eq 'test-stim-a' })[0]
        $a.details.code.Count | Should -Be 1
        $a.details.llm.Count | Should -Be 1
    }

    It 'Buckets unknown grader kinds under other and warns' {
        $warnings = $null
        $records = ConvertFrom-EquivalenceResults -RunDir (Join-Path $script:FixturesRoot 'baseline') -WarningVariable warnings -WarningAction SilentlyContinue
        $b = ($records | Where-Object { $_.stimulusName -eq 'test-stim-b' })[0]
        $b.details.other.Count | Should -Be 1
        $warnings | Where-Object { $_ -match 'weirdkind' } | Should -Not -BeNullOrEmpty
    }

    It 'Throws when the run directory does not exist' {
        { ConvertFrom-EquivalenceResults -RunDir (Join-Path $TestDrive 'missing') } | Should -Throw
    }

    It 'Throws when no results.jsonl files exist under the run directory' {
        $empty = Join-Path $TestDrive 'empty'
        New-Item -ItemType Directory -Path $empty -Force | Out-Null
        { ConvertFrom-EquivalenceResults -RunDir $empty } | Should -Throw
    }
}

Describe 'Merge-EquivalenceStimuli' -Tag 'Unit' {
    BeforeAll {
        $script:Baseline = ConvertFrom-EquivalenceResults -RunDir (Join-Path $script:FixturesRoot 'baseline') -WarningAction SilentlyContinue
        $script:Customized = ConvertFrom-EquivalenceResults -RunDir (Join-Path $script:FixturesRoot 'customized') -WarningAction SilentlyContinue
        $script:Compare = Measure-CompareTrials -Lines (Get-Content -LiteralPath (Join-Path $script:FixturesRoot 'vally-compare.log'))
        $script:Merged = Merge-EquivalenceStimuli -Baseline $script:Baseline -Customized $script:Customized -Compare $script:Compare
    }

    It 'Produces one row per stimulus' {
        $script:Merged.Count | Should -Be 2
    }

    It 'Counts identical outputs by hash' {
        $a = $script:Merged | Where-Object { $_.stimulusName -eq 'test-stim-a' }
        $a.identicalCount | Should -Be 1
        $a.identicalTotal | Should -Be 1
        $b = $script:Merged | Where-Object { $_.stimulusName -eq 'test-stim-b' }
        $b.identicalCount | Should -Be 0
        $b.identicalTotal | Should -Be 1
    }

    It 'Computes pass rates for each side' {
        $a = $script:Merged | Where-Object { $_.stimulusName -eq 'test-stim-a' }
        $a.baselinePassRate | Should -Be 1.0
        $a.customizedPassRate | Should -Be 1.0
        $b = $script:Merged | Where-Object { $_.stimulusName -eq 'test-stim-b' }
        $b.baselinePassRate | Should -Be 1.0
        $b.customizedPassRate | Should -Be 0.0
    }

    It 'Computes mean wall-time and token deltas' {
        $a = $script:Merged | Where-Object { $_.stimulusName -eq 'test-stim-a' }
        $a.meanWallTimeDeltaMs | Should -Be 20
        $a.meanTokenDelta | Should -Be 5
    }

    It 'Carries per-stimulus compare tallies through' {
        $a = $script:Merged | Where-Object { $_.stimulusName -eq 'test-stim-a' }
        $a.ties | Should -Be 1
        $a.aWins | Should -Be 1
        $a.bWins | Should -Be 0
    }

    It 'Handles missing-side stimuli with zero pass rate' {
        $bOnly = [pscustomobject]@{
            stimulusName = 'lonely'
            trial        = 0
            output       = 'x'
            outputHash   = 'h'
            passed       = $true
            score        = 1
            wallTimeMs   = 1
            totalTokens  = 1
            details      = @{ code = @(); llm = @(); human = @(); other = @() }
        }
        $merged = Merge-EquivalenceStimuli -Baseline @($bOnly) -Customized @() -Compare @{ PerStimulus = @{} }
        ($merged | Where-Object { $_.stimulusName -eq 'lonely' }).customizedPassRate | Should -Be 0
    }
}

Describe 'Edit-HtmlEscape' -Tag 'Unit' {
    It 'Escapes ampersands first' {
        Edit-HtmlEscape '&' | Should -Be '&amp;'
    }

    It 'Escapes angle brackets' {
        Edit-HtmlEscape '<x>' | Should -Be '&lt;x&gt;'
    }

    It 'Escapes double quotes' {
        Edit-HtmlEscape '"x"' | Should -Be '&quot;x&quot;'
    }

    It "Escapes apostrophes" {
        Edit-HtmlEscape "it's" | Should -Be 'it&#39;s'
    }

    It 'Returns empty string for null input' {
        Edit-HtmlEscape $null | Should -Be ''
    }

    It 'Returns empty string for empty input' {
        Edit-HtmlEscape '' | Should -Be ''
    }

    It 'Passes through text with no special characters unchanged' {
        Edit-HtmlEscape 'plain text 123' | Should -Be 'plain text 123'
    }

    It 'Escapes ampersand before other entities so injected entities are double-escaped' {
        Edit-HtmlEscape '&lt;' | Should -Be '&amp;lt;'
    }

    It 'Escapes every special character in a combined payload' {
        Edit-HtmlEscape '<a href="x">it''s & co</a>' |
            Should -Be '&lt;a href=&quot;x&quot;&gt;it&#39;s &amp; co&lt;/a&gt;'
    }
}

Describe 'ConvertTo-EquivalenceHtml' -Tag 'Unit' {
    BeforeAll {
        $script:Baseline = ConvertFrom-EquivalenceResults -RunDir (Join-Path $script:FixturesRoot 'baseline') -WarningAction SilentlyContinue
        $script:Customized = ConvertFrom-EquivalenceResults -RunDir (Join-Path $script:FixturesRoot 'customized') -WarningAction SilentlyContinue
        $script:Compare = Measure-CompareTrials -Lines (Get-Content -LiteralPath (Join-Path $script:FixturesRoot 'vally-compare.log'))
        $script:Merged = Merge-EquivalenceStimuli -Baseline $script:Baseline -Customized $script:Customized -Compare $script:Compare
        $script:Html = ConvertTo-EquivalenceHtml -Stimuli $script:Merged -Model 'test-model' -RunId 'test-run-id' -Agent 'task-researcher'
    }

    It 'Includes the model and run id in escaped form' {
        $script:Html | Should -Match 'test-model'
        $script:Html | Should -Match 'test-run-id'
    }

    It 'Renders the Agent identity in the meta line' {
        $script:Html | Should -Match 'Agent: <strong>task-researcher</strong>'
        $script:Html | Should -Not -Match 'Subject: <strong>'
    }

    It 'Marks -Agent as a mandatory parameter' {
        $param = (Get-Command ConvertTo-EquivalenceHtml).Parameters['Agent']
        $param | Should -Not -BeNullOrEmpty
        $param.Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -Contain $true
    }

    It 'HTML-escapes the Agent value in the meta line' {
        $html = ConvertTo-EquivalenceHtml -Stimuli $script:Merged -Model 'm' -RunId 'r' -Agent '<x>'
        $html | Should -Match 'Agent: <strong>&lt;x&gt;</strong>'
        $html | Should -Not -Match 'Agent: <strong><x>'
    }

    It 'Embeds the run data inside a script tag' {
        $script:Html | Should -Match '<script id="data"'
    }

    It 'Does not reference any external http resources' {
        $script:Html | Should -Not -Match 'http://'
        $script:Html | Should -Not -Match 'https://'
    }

    It 'Escapes raw less-than from stimulus content' {
        $stim = [pscustomobject]@{
            stimulusName        = '<script>alert(1)</script>'
            baselineTrials      = 1
            customizedTrials    = 1
            baselinePassed      = 1
            customizedPassed    = 1
            baselinePassRate    = 1.0
            customizedPassRate  = 1.0
            identicalCount      = 1
            identicalTotal      = 1
            ties                = 1
            aWins               = 0
            bWins               = 0
            meanWallTimeDeltaMs = 0
            meanTokenDelta      = 0
            trials              = @()
        }
        $html = ConvertTo-EquivalenceHtml -Stimuli @($stim) -Model '<m>' -RunId '<r>' -Agent 'agent-x'
        $html | Should -Match '&lt;m&gt;'
        $html | Should -Match '&lt;r&gt;'
        $html | Should -Not -Match '<script>alert\(1\)</script>'
    }

    It 'Neutralizes script-close sequences via JSON forward-slash escape (IV-001)' {
        $stim = [pscustomobject]@{
            stimulusName        = '</script><script>alert(1)</script>'
            baselineTrials      = 1
            customizedTrials    = 1
            baselinePassed      = 1
            customizedPassed    = 1
            baselinePassRate    = 1.0
            customizedPassRate  = 1.0
            identicalCount      = 1
            identicalTotal      = 1
            ties                = 1
            aWins               = 0
            bWins               = 0
            meanWallTimeDeltaMs = 0
            meanTokenDelta      = 0
            trials              = @()
        }
        $html = ConvertTo-EquivalenceHtml -Stimuli @($stim) -Model 'm' -RunId 'r' -Agent 'agent-x'
        $html | Should -Not -Match '</script><script>alert'
        $html | Should -Match '\\u003c\\/script\\u003e'
    }

    It 'Renders custom variant labels, kinds, descriptions, and applied lists' {
        $stim = [pscustomobject]@{
            stimulusName        = 'simple-test'
            baselineTrials      = 1
            customizedTrials    = 1
            baselinePassed      = 1
            customizedPassed    = 1
            baselinePassRate    = 1.0
            customizedPassRate  = 1.0
            identicalCount      = 1
            identicalTotal      = 1
            ties                = 1
            aWins               = 0
            bWins               = 0
            meanWallTimeDeltaMs = 0
            meanTokenDelta      = 0
            trials              = @()
        }
        $variants = @{
            a       = @{ kind = 'baseline'; name = 'empty'; label = 'Baseline-Custom'; description = 'desc-a'; applied = @('p1') }
            b       = @{ kind = 'prompt';   name = 'varB';  label = 'VarB-Custom';     description = 'desc-b'; applied = @('p2', 'p3') }
            subject = 'varB'
        }
        $html = ConvertTo-EquivalenceHtml -Stimuli @($stim) -Model 'm' -RunId 'r' -Agent 'agent-x' -Variants $variants
        $html | Should -Match 'Baseline-Custom'
        $html | Should -Match 'VarB-Custom'
        $html | Should -Match 'desc-a'
        $html | Should -Match 'desc-b'
        $html | Should -Match '<li>p1</li>'
        $html | Should -Match '<li>p2</li>'
        $html | Should -Match '<li>p3</li>'
        $html | Should -Match 'Baseline-Custom pass'
        $html | Should -Match 'VarB-Custom pass'
        $html | Should -Match 'Baseline-Custom wins'
        $html | Should -Match 'VarB-Custom wins'
        $html | Should -Not -Match 'Baseline \(A\)'
        $html | Should -Not -Match 'Customized \(B\)'
    }

    It 'Suppresses default variant labels when custom -Variants labels are supplied' {
        $stim = [pscustomobject]@{
            stimulusName        = 'simple-test'
            baselineTrials      = 1
            customizedTrials    = 1
            baselinePassed      = 1
            customizedPassed    = 1
            baselinePassRate    = 1.0
            customizedPassRate  = 1.0
            identicalCount      = 1
            identicalTotal      = 1
            ties                = 1
            aWins               = 0
            bWins               = 0
            meanWallTimeDeltaMs = 0
            meanTokenDelta      = 0
            trials              = @()
        }
        $variants = @{
            a       = @{ kind = 'baseline'; name = 'one'; label = 'Side One'; description = 'd1'; applied = @() }
            b       = @{ kind = 'prompt';   name = 'two'; label = 'Side Two'; description = 'd2'; applied = @() }
            subject = 'two'
        }
        $html = ConvertTo-EquivalenceHtml -Stimuli @($stim) -Model 'm' -RunId 'r' -Agent 'agent-x' -Variants $variants
        $html | Should -Match 'Side One'
        $html | Should -Match 'Side Two'
        $html | Should -Not -Match 'Baseline \(A\)'
        $html | Should -Not -Match 'Customized \(B\)'
    }

    It 'Falls back to default variant labels when -Variants is omitted' {
        $stim = [pscustomobject]@{
            stimulusName        = 'simple-test'
            baselineTrials      = 1
            customizedTrials    = 1
            baselinePassed      = 1
            customizedPassed    = 1
            baselinePassRate    = 1.0
            customizedPassRate  = 1.0
            identicalCount      = 1
            identicalTotal      = 1
            ties                = 1
            aWins               = 0
            bWins               = 0
            meanWallTimeDeltaMs = 0
            meanTokenDelta      = 0
            trials              = @()
        }
        $html = ConvertTo-EquivalenceHtml -Stimuli @($stim) -Model 'm' -RunId 'r' -Agent 'agent-x'
        $html | Should -Match 'Baseline \(A\)'
        $html | Should -Match 'Customized \(B\)'
    }
}

Describe 'Get-AppliedArtifacts' -Tag 'Unit' {
    BeforeAll {
        $script:WorkspaceRoot = Join-Path $TestDrive 'workspace'
        $script:Anchors = @(
            '.github/agents',
            '.github/skills/foo',
            '.github/skills/bar',
            '.github/instructions',
            '.github/prompts'
        )
        foreach ($a in $script:Anchors) {
            New-Item -ItemType Directory -Path (Join-Path $script:WorkspaceRoot $a) -Force | Out-Null
        }
        $script:SeededFiles = @(
            '.github/agents/example.agent.md',
            '.github/skills/foo/SKILL.md',
            '.github/skills/bar/SKILL.md',
            '.github/instructions/example.instructions.md',
            '.github/prompts/example.prompt.md'
        )
        foreach ($f in $script:SeededFiles) {
            Set-Content -LiteralPath (Join-Path $script:WorkspaceRoot $f) -Value 'x' -Encoding utf8NoBOM
        }
        # README must not be enumerated.
        Set-Content -LiteralPath (Join-Path $script:WorkspaceRoot '.github/agents/README.md') -Value 'x' -Encoding utf8NoBOM

        $script:Result = Get-AppliedArtifacts -WorkspaceRoot $script:WorkspaceRoot
    }

    It 'Returns one entry per seeded artifact' {
        $script:Result.Count | Should -Be 5
    }

    It 'Includes every seeded artifact path' {
        foreach ($f in $script:SeededFiles) {
            $script:Result | Should -Contain $f
        }
    }

    It 'Retains distinct SKILL.md files in different subdirectories' {
        ($script:Result | Where-Object { $_ -like '*SKILL.md' }).Count | Should -Be 2
    }

    It 'Excludes README.md' {
        $script:Result | Should -Not -Contain '.github/agents/README.md'
    }

    It 'Returns results in sorted order' {
        $sorted = @($script:Result | Sort-Object)
        for ($i = 0; $i -lt $sorted.Count; $i++) {
            $script:Result[$i] | Should -Be $sorted[$i]
        }
    }

    It 'Uses forward slashes in every returned path' {
        foreach ($entry in $script:Result) {
            $entry | Should -Not -Match '\\'
        }
    }

    It 'Returns an empty array when the workspace path is missing' {
        $missing = Join-Path $TestDrive 'does-not-exist'
        $result = Get-AppliedArtifacts -WorkspaceRoot $missing
        @($result).Count | Should -Be 0
    }

    It 'Returns an empty array when the workspace path is empty string' {
        $result = Get-AppliedArtifacts -WorkspaceRoot ''
        @($result).Count | Should -Be 0
    }

    It 'Returns an empty array when no anchor directories exist' {
        $bareRoot = Join-Path $TestDrive 'bare'
        New-Item -ItemType Directory -Path $bareRoot -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $bareRoot 'stray.md') -Value 'x' -Encoding utf8NoBOM
        $result = Get-AppliedArtifacts -WorkspaceRoot $bareRoot
        @($result).Count | Should -Be 0
    }
}
