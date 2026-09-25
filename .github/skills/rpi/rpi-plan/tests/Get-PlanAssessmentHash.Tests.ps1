#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $ScriptPath = Join-Path $PSScriptRoot '..\scripts\Get-PlanAssessmentHash.ps1'
    . $ScriptPath
    $Utf8 = [System.Text.UTF8Encoding]::new($false)
    $PlanPath = Join-Path $TestDrive 'plan [candidate].md'
    $Plan = @'
# Plan

## Executive Summary

Keep this summary.

## Phase Checklist

<!-- rpi:phase id=P01 -->
### [ ] P01: Implement

Goals:
* Phase goal.

<!-- rpi:task id=P01-T01 -->
#### [ ] P01-T01: Build

Goals:
* Task goal.

Requirements:
* Preserve this requirement.

Details:
* Use the existing API.

References:
* source.md

Dependencies:
* None.

## User Decisions and Requirements

Preserve this decision.
'@
    $Plan = $Plan.Replace("`r`n", "`n") + "`n"

    function Get-TestAssessment {
        param([string]$Content)
        [System.IO.File]::WriteAllText($PlanPath, $Content, $Utf8)
        Get-PlanAssessmentHash -PlanPath $PlanPath
    }
}

Describe 'Get-PlanAssessmentHash' -Tag 'Unit' {
    It 'Emits exact projection, version and independently computed digest without changing input' {
        $Result = Get-TestAssessment $Plan
        $Result.projection_version | Should -BeExactly 'rpi-plan-assessment-v1'
        $Result.projection | Should -BeExactly $Plan
        $Result.sha256 | Should -Match '^[a-f0-9]{64}$'
        $Result.sha256 | Should -BeExactly (Get-FileHash -LiteralPath $PlanPath -Algorithm SHA256).Hash.ToLowerInvariant()
        [System.IO.File]::ReadAllText($PlanPath) | Should -BeExactly $Plan
        ($Result.PSObject.Properties.Name -join ',') | Should -BeExactly 'projection_version,sha256,projection'
    }

    It 'Normalizes BOM and <Ending> line endings' -ForEach @(
        @{ Ending = 'LF'; Separator = "`n" }
        @{ Ending = 'CRLF'; Separator = "`r`n" }
        @{ Ending = 'CR'; Separator = "`r" }
    ) {
        $Baseline = Get-TestAssessment $Plan
        $Result = Get-TestAssessment (([string][char]0xFEFF) + $Plan.Replace("`n", $Separator))
        $Result.projection | Should -BeExactly $Baseline.projection
        $Result.sha256 | Should -BeExactly $Baseline.sha256
    }

    It 'Removes only the complete <Section> section through the next peer heading' -ForEach @(
        @{ Section = 'Critique Disposition' }
        @{ Section = 'Artifact Self-Check' }
        @{ Section = 'Planning Readiness and Next Step' }
        @{ Section = 'Follow-Up Items' }
        @{ Section = 'Handoff' }
    ) {
        $Inserted = "## $Section`n`nbookkeeping`n### Nested`nmore bookkeeping`n`n"
        $Result = Get-TestAssessment $Plan.Replace('## User Decisions', $Inserted + '## User Decisions')
        $Result.projection | Should -BeExactly $Plan
        (Get-TestAssessment ($Plan + $Inserted)).projection | Should -BeExactly $Plan
    }

    It 'Preserves assessed content after an excluded section ending at H1' {
        $Result = Get-TestAssessment ($Plan + "## Handoff`nignore`n# Appendix`nretain`n")
        $Result.projection | Should -BeExactly ($Plan + "# Appendix`nretain`n")
    }

    It 'Recognizes closing ATX hashes but keeps differently named or nested sections' {
        (Get-TestAssessment ($Plan + "## Handoff ###  `nignore`n")).projection | Should -BeExactly $Plan
        $Content = $Plan + "## handoff`nassessed`n### Handoff`nalso assessed`n## Handoff notes`nretained`n"
        (Get-TestAssessment $Content).projection | Should -BeExactly $Content
    }

    It 'Normalizes only matching marked phase and task status' {
        $Result = Get-TestAssessment $Plan.Replace('[ ] P01', '[x] P01')
        $Result.projection | Should -BeExactly $Plan
        $Unmarked = $Plan.Replace('<!-- rpi:task id=P01-T01 -->', '<!-- ordinary comment -->').Replace('[ ] P01-T01', '[x] P01-T01')
        (Get-TestAssessment $Unmarked).projection | Should -BeExactly $Unmarked
        $Mismatch = $Plan.Replace('<!-- rpi:task id=P01-T01 -->', '<!-- rpi:task id=P01-T02 -->').Replace('[ ] P01-T01', '[x] P01-T01')
        (Get-TestAssessment $Mismatch).projection | Should -BeExactly $Mismatch
    }

    It 'Removes task-local pointer Guidance without removing surrounding task blocks' {
        $WithGuidance = $Plan.Replace("References:`n", "Guidance:`n* created-helper.ps1`n`nReferences:`n")
        $Result = Get-TestAssessment $WithGuidance.Replace('[ ] P01', '[x] P01')
        $Result.projection | Should -BeExactly $Plan
        $Result.sha256 | Should -BeExactly (Get-TestAssessment $Plan).sha256
    }

    It 'Preserves Guidance outside marked tasks and outside Phase Checklist' {
        $Outside = $Plan.Replace('## Executive Summary', "Guidance:`n* assessed`n`n## Executive Summary")
        $Outside += "`n<!-- rpi:task id=P02-T01 -->`n#### [x] P02-T01: Outside`nDetails:`ntext`nGuidance:`nassessed`nReferences:`nref`n"
        (Get-TestAssessment $Outside).projection | Should -BeExactly $Outside
        $Unmarked = $Plan.Replace('<!-- rpi:task id=P01-T01 -->', '<!-- task -->').Replace("References:`n", "Guidance:`nassessed`nReferences:`n")
        (Get-TestAssessment $Unmarked).projection | Should -BeExactly $Unmarked
    }

    It 'Keeps heading status when its marker is not immediately adjacent' {
        $Content = $Plan.Replace('<!-- rpi:task id=P01-T01 -->', "<!-- rpi:task id=P01-T01 -->`n").Replace('[ ] P01-T01', '[x] P01-T01')
        (Get-TestAssessment $Content).projection | Should -BeExactly $Content
    }

    It 'Preserves a shorter fence and apparent markers inside a longer fence' {
        $Example = @'
````markdown
```
<!-- rpi:task id=P01-T01 -->
#### [x] P01-T01: Example
## Handoff
````
'@
        $Content = $Plan.Replace('Keep this summary.', $Example.Replace("`r`n", "`n"))
        (Get-TestAssessment $Content).projection | Should -BeExactly $Content
    }

    It 'Preserves inline comments containing heading text and multiple comment spans' {
        $Content = $Plan + "<!-- one --> <!-- two`n## Handoff`n-->`n"
        (Get-TestAssessment $Content).projection | Should -BeExactly $Content
    }

    It 'Hashes Unicode as UTF-8 without changing code points' {
        $Content = $Plan.Replace('Keep this summary.', ([string][char]0x00E9) + ' text')
        $Result = Get-TestAssessment $Content
        $Result.projection | Should -BeExactly $Content
        $Result.sha256 | Should -BeExactly (Get-FileHash -LiteralPath $PlanPath).Hash.ToLowerInvariant()
    }

    It 'Preserves syntax-like content inside <Kind>' -ForEach @(
        @{ Kind = 'backtick fence'; Open = '````markdown'; Close = '````' }
        @{ Kind = 'tilde fence'; Open = '~~~text'; Close = '~~~~' }
        @{ Kind = 'multiline comment'; Open = '<!-- example'; Close = '-->' }
    ) {
        $Example = "$Open`n## Handoff`n<!-- rpi:task id=P01-T01 -->`n#### [x] P01-T01: Example`nGuidance:`nReferences:`n$Close`n"
        if ($Kind -eq 'multiline comment') {
            $Example = "$Open`n## Handoff`n#### [x] P01-T01: Example`nGuidance:`nReferences:`n$Close`n"
        }
        $Content = $Plan.Replace('Keep this summary.', $Example)
        (Get-TestAssessment $Content).projection | Should -BeExactly $Content
    }

    It 'Does not end a section or Guidance block at a fenced example' {
        $Content = $Plan.Replace("References:`n", "Guidance:`n``````text`nReferences:`n## User Decisions`n```````n`nReferences:`n")
        (Get-TestAssessment $Content).projection | Should -BeExactly $Plan
        $Content = $Plan + "## Handoff`n~~~text`n## Assessed example`n~~~`n"
        (Get-TestAssessment $Content).projection | Should -BeExactly $Plan
    }

    It 'Changes the hash for assessed <Area> changes' -ForEach @(
        @{ Area = 'summary'; From = 'Keep this summary.'; To = 'Changed summary.' }
        @{ Area = 'goal'; From = 'Task goal.'; To = 'Different goal.' }
        @{ Area = 'requirement'; From = 'Preserve this requirement.'; To = 'Different requirement.' }
        @{ Area = 'details'; From = 'existing API'; To = 'new API' }
        @{ Area = 'reference'; From = 'source.md'; To = 'other.md' }
        @{ Area = 'dependency'; From = '* None.'; To = '* P00.' }
        @{ Area = 'decision'; From = 'Preserve this decision.'; To = 'Different decision.' }
        @{ Area = 'title'; From = 'P01-T01: Build'; To = 'P01-T01: Test' }
        @{ Area = 'whitespace'; From = 'Phase goal.'; To = 'Phase  goal.' }
    ) {
        $Baseline = Get-TestAssessment $Plan
        (Get-TestAssessment $Plan.Replace($From, $To)).sha256 | Should -Not -BeExactly $Baseline.sha256
    }

    It 'Preserves other checkboxes and terminal newline differences' {
        $Content = $Plan + "`n* [x] Human review`n"
        (Get-TestAssessment $Content).projection | Should -BeExactly $Content
        (Get-TestAssessment $Plan.TrimEnd("`n")).sha256 | Should -Not -BeExactly (Get-TestAssessment $Plan).sha256
    }

    It 'Rejects <Kind> rather than returning a hash' -ForEach @(
        @{ Kind = 'empty input'; Content = '' }
        @{ Kind = 'missing checklist'; Content = "# Plan`n" }
        @{ Kind = 'unterminated fence'; Content = "## Phase Checklist`n~~~text`n" }
        @{ Kind = 'unterminated comment'; Content = "## Phase Checklist`n<!--`n" }
        @{ Kind = 'duplicate checklist'; Content = "## Phase Checklist`n## Phase Checklist`n" }
    ) {
        { Get-TestAssessment $Content } | Should -Throw
    }

    It 'Rejects Guidance without a valid boundary' {
        { Get-TestAssessment $Plan.Replace("Details:`n", "Guidance:`n") } | Should -Throw '*Guidance*'
        { Get-TestAssessment $Plan.Replace("References:`n", "Guidance:`n") } | Should -Throw '*Guidance*'
        { Get-TestAssessment ($Plan.Substring(0, $Plan.IndexOf('References:')) + "Guidance:`npointer") } | Should -Throw '*unterminated*'
        { Get-TestAssessment $Plan.Replace("References:`n", "Guidance:`n## New section`n") } | Should -Throw '*Guidance*'
        { Get-TestAssessment $Plan.Replace("References:`n", "Guidance:`n<!-- rpi:task id=P01-T02 -->`n") } | Should -Throw '*Guidance*'
    }

    It 'Rejects missing files and invalid UTF-8' {
        { Get-PlanAssessmentHash -PlanPath (Join-Path $TestDrive 'missing.md') } | Should -Throw
        [System.IO.File]::WriteAllBytes($PlanPath, [byte[]]@(0xFF, 0xFE, 0x41, 0))
        { Get-PlanAssessmentHash -PlanPath $PlanPath } | Should -Throw
    }

    It 'Emits identical JSON from fresh processes and a relocated standalone script' {
        $Expected = Get-TestAssessment $Plan
        $Copy = Join-Path $TestDrive 'installed helper.ps1'
        Copy-Item -LiteralPath $ScriptPath -Destination $Copy
        foreach ($Executable in @($ScriptPath, $Copy)) {
            $Json = & pwsh -NoProfile -File $Executable -PlanPath $PlanPath
            $LASTEXITCODE | Should -Be 0
            $Actual = $Json | ConvertFrom-Json
            $Actual.projection | Should -BeExactly $Expected.projection
            $Actual.sha256 | Should -BeExactly $Expected.sha256
            $Actual.projection_version | Should -BeExactly $Expected.projection_version
        }
    }

    It 'Returns nonzero and no success JSON for invalid CLI input' {
        $Output = & pwsh -NoProfile -File $ScriptPath -PlanPath (Join-Path $TestDrive 'missing.md') 2>&1
        $LASTEXITCODE | Should -Be 1
        ($Output -join "`n") | Should -Match 'Plan assessment hash failed'
        ($Output -join "`n") | Should -Not -Match '"sha256"'
    }

    It 'Forwards identical JSON and failure status through the Bash entry point' {
        $Bash = if ($IsWindows) {
            Join-Path (Split-Path (Split-Path (Get-Command git -ErrorAction Stop).Source)) 'bin\bash.exe'
        }
        else {
            (Get-Command bash -ErrorAction Stop).Source
        }
        $Wrapper = (Join-Path $PSScriptRoot '..\scripts\get-plan-assessment-hash.sh').Replace('\', '/')
        $Expected = Get-TestAssessment $Plan
        & $Bash -n $Wrapper
        $LASTEXITCODE | Should -Be 0
        $Json = & $Bash $Wrapper -PlanPath $PlanPath
        $LASTEXITCODE | Should -Be 0
        $Actual = $Json | ConvertFrom-Json
        $Actual.projection | Should -BeExactly $Expected.projection
        $Actual.sha256 | Should -BeExactly $Expected.sha256
        $Actual.projection_version | Should -BeExactly $Expected.projection_version
        $Failure = & $Bash $Wrapper -PlanPath (Join-Path $TestDrive 'missing.md') 2>&1
        $LASTEXITCODE | Should -Be 1
        ($Failure -join "`n") | Should -Match 'Plan assessment hash failed'
    }
}
