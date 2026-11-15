#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

Describe 'Collect-HveValueEvidence' {
    BeforeAll {
        $script:CollectorScript = Join-Path $PSScriptRoot '../scripts/Collect-HveValueEvidence.ps1'
    }

    It 'collects git manifest, RPI deliverables, review verdicts, and accounting outside RepoRoot without mutating repo state' {
        $repo = Join-Path $TestDrive 'sample-repo'
        $outJson = Join-Path $TestDrive 'evidence-out/snapshot.json'
        $accJson = Join-Path $TestDrive 'accounting.json'

        New-Item -ItemType Directory -Path (Join-Path $repo '.github/agents/finops'), (Join-Path $repo '.copilot-tracking/changes'), (Join-Path $repo '.copilot-tracking/reviews') -Force | Out-Null
        & git -C $repo init --quiet -b main
        & git -C $repo config user.email 'test@example.invalid'
        & git -C $repo config user.name 'Fixture'

        Set-Content -LiteralPath (Join-Path $repo '.github/agents/finops/sample.agent.md') -Value "---`nname: Sample`ndescription: 'Sample'`n---`n"
        Set-Content -LiteralPath (Join-Path $repo '.copilot-tracking/changes/2026-11-15-change.md') -Value "# Change`n"
        Set-Content -LiteralPath (Join-Path $repo '.copilot-tracking/reviews/2026-11-15-review.md') -Value "# Review`n`nVerdict: Pass`n"
        & git -C $repo add -A
        & git -C $repo commit --quiet -m 'initial'

        $accPayload = @{
            sessions                  = 2
            calls                     = 8
            knownProviderUnits        = 45.5
            costUsd                   = 0.455
            counterfactualBaselineUsd = 1.80
            basis                     = 'measured'
        } | ConvertTo-Json -Depth 5
        Set-Content -LiteralPath $accJson -Value $accPayload

        $summaryJson = & $script:CollectorScript -RepoRoot $repo -OutputPath $outJson -AccountingPath $accJson
        Test-Path -LiteralPath $outJson -PathType Leaf | Should -BeTrue
        $summary = $summaryJson | ConvertFrom-Json
        $summary.statusStableDuringCollection | Should -BeTrue
        $summary.trackedPaths | Should -Be 3
        $summary.rpiDelivery.present | Should -BeTrue
        $summary.rpiDelivery.deliverablesProduced | Should -Be 1
        $summary.rpiDelivery.acceptedReviews | Should -Be 1
        $summary.accounting.costUsd | Should -Be 0.455
        $summary.accounting.counterfactualBaselineUsd | Should -Be 1.80
    }

    It 'refuses an OutputPath inside RepoRoot' {
        $repo = Join-Path $TestDrive 'guard-repo'
        New-Item -ItemType Directory -Path $repo -Force | Out-Null
        & git -C $repo init --quiet -b main
        $insideOut = Join-Path $repo 'nested/out.json'
        { & $script:CollectorScript -RepoRoot $repo -OutputPath $insideOut } | Should -Throw '*outside RepoRoot*'
    }
}
