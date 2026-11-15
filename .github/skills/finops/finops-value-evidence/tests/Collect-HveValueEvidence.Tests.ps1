#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

Describe 'Collect-HveValueEvidence' -Tag 'Unit' {
    BeforeAll {
        $script:CollectorScript = Join-Path $PSScriptRoot '../scripts/Collect-HveValueEvidence.ps1'
    }

    It 'collects git manifest, agent declarations, RPI deliverables, XML test report, and sessionRows accounting outside RepoRoot' {
        $repo = Join-Path $TestDrive 'sample-repo'
        $outJson = Join-Path $TestDrive 'evidence-out/snapshot.json'
        $accJson = Join-Path $TestDrive 'accounting.json'

        New-Item -ItemType Directory -Path (Join-Path $repo '.github/agents/finops'), (Join-Path $repo '.copilot-tracking/research'), (Join-Path $repo '.copilot-tracking/plans'), (Join-Path $repo '.copilot-tracking/changes'), (Join-Path $repo '.copilot-tracking/reviews'), (Join-Path $repo 'docs'), (Join-Path $repo 'tests') -Force | Out-Null
        & git -C $repo init --quiet -b main
        & git -C $repo config user.email 'test@example.invalid'
        & git -C $repo config user.name 'Fixture'

        Set-Content -LiteralPath (Join-Path $repo '.github/agents/sample.agent.md') -Value "---`nname: 'Sample Agent'`nmodel: ['Claude Sonnet 4.6']`ndescription: 'Sample'`n---`n"
        Set-Content -LiteralPath (Join-Path $repo '.copilot-tracking/research/2026-11-15-res.md') -Value "# Research`n"
        Set-Content -LiteralPath (Join-Path $repo '.copilot-tracking/plans/2026-11-15-plan.md') -Value "# Plan`n"
        Set-Content -LiteralPath (Join-Path $repo '.copilot-tracking/changes/2026-11-15-change.md') -Value "# Change`n"
        Set-Content -LiteralPath (Join-Path $repo '.copilot-tracking/reviews/2026-11-15-pass.md') -Value "# Review`n`nVerdict: Pass`n"
        Set-Content -LiteralPath (Join-Path $repo '.copilot-tracking/reviews/2026-11-15-fail.md') -Value "# Review`n`nVerdict: Fail`n"
        Set-Content -LiteralPath (Join-Path $repo 'docs/readme.md') -Value "# Docs`n"
        Set-Content -LiteralPath (Join-Path $repo 'testResults.xml') -Value '<?xml version="1.0" encoding="utf-8"?><test-results total="12" passed="11" failed="1" skipped="0" result="Failure" duration="1.25" />'
        & git -C $repo add -A
        & git -C $repo commit --quiet -m 'initial'

        # Add one untracked file to exercise untracked path collection
        Set-Content -LiteralPath (Join-Path $repo 'tests/untracked.txt') -Value 'untracked'

        $accPayload = @{
            sessions                  = 2
            calls                     = 8
            counterfactualBaselineUsd = 1.80
            sessionRows               = @(
                @{ id = 'sess-role1-implementer'; calls = 5; knownNanoAiu = 30000000000 }
                @{ id = 'sess-coord'; calls = 3; knownNanoAiu = 15500000000 }
            )
            basis                     = 'measured'
        } | ConvertTo-Json -Depth 6
        Set-Content -LiteralPath $accJson -Value $accPayload

        $summaryJson = & $script:CollectorScript -RepoRoot $repo -OutputPath $outJson -AccountingPath $accJson
        Test-Path -LiteralPath $outJson -PathType Leaf | Should -BeTrue
        $summary = $summaryJson | ConvertFrom-Json
        $summary.statusStableDuringCollection | Should -BeTrue
        $summary.trackedPaths | Should -Be 8
        $summary.untrackedNonignoredPaths | Should -Be 1
        $summary.rpiDelivery.present | Should -BeTrue
        $summary.rpiDelivery.researchArtifacts | Should -Be 1
        $summary.rpiDelivery.planArtifacts | Should -Be 1
        $summary.rpiDelivery.deliverablesProduced | Should -Be 1
        $summary.rpiDelivery.acceptedReviews | Should -Be 1
        $summary.rpiDelivery.rejectedReviews | Should -Be 1
        $summary.accounting.knownProviderUnits | Should -Be 45.5
        $summary.accounting.costUsd | Should -Be 0.455
        $summary.accounting.counterfactualBaselineUsd | Should -Be 1.80
        $summary.testReport.root | Should -Be 'test-results'
        $summary.testReport.attributes.total | Should -Be '12'

        $fullBundle = Get-Content -LiteralPath $outJson -Raw | ConvertFrom-Json
        $fullBundle.agentDeclarations.Count | Should -Be 1
        $fullBundle.agentDeclarations[0].name | Should -Be 'Sample Agent'
        $fullBundle.accounting.actors.Count | Should -Be 2
    }

    It 'handles unborn HEAD repositories without .copilot-tracking and refuses inside-RepoRoot OutputPath' {
        $repo = Join-Path $TestDrive 'guard-repo'
        New-Item -ItemType Directory -Path $repo -Force | Out-Null
        & git -C $repo init --quiet -b main
        Set-Content -LiteralPath (Join-Path $repo 'hello.txt') -Value 'hi'

        $outsideOut = Join-Path $TestDrive 'unborn-out.json'
        $unbornSummary = (& $script:CollectorScript -RepoRoot $repo -OutputPath $outsideOut) | ConvertFrom-Json
        $unbornSummary.head | Should -Be 'unborn'
        $unbornSummary.rpiDelivery.present | Should -BeFalse

        $insideOut = Join-Path $repo 'nested/out.json'
        { & $script:CollectorScript -RepoRoot $repo -OutputPath $insideOut } | Should -Throw '*outside RepoRoot*'
    }
}
