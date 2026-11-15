#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

Describe 'HveBenefitValuation module edge cases' -Tag 'Unit' {
    BeforeAll {
        $script:ModulePath = Join-Path $PSScriptRoot '../scripts/HveBenefitValuation.psm1'
        if (-not (Get-Command -Name Get-HveBenefitValuation -ErrorAction SilentlyContinue)) {
            Import-Module $script:ModulePath
        }
    }

    It 'handles empty input documents, pure finance-approved basis, and unmonetized HVE evidence bundles' {
        $emptyRes = Get-HveBenefitValuation -InputDocument @{}
        $emptyRes.summary.overallBasis | Should -Be 'unmonetized-native-only'
        $emptyRes.summary.totalStatedEvidencedValue | Should -BeNullOrEmpty
        $emptyRes.summary.overlapDeductionsTotal | Should -Be 0

        $emptyMd = ConvertTo-HveBenefitValuationMarkdown -Model $emptyRes
        $emptyMd | Should -Match 'unavailable'

        $finOnly = Get-HveBenefitValuation -InputDocument @{
            currency       = 'EUR'
            benefit_claims = @(
                @{
                    claim_id          = 'fin-1'
                    category          = 'quality'
                    hypothesis        = 'Approved defect savings'
                    beneficiary       = 'API'
                    measurement_owner = 'QA'
                    status            = 'supported'
                    baseline          = @{ value = 10; unit = 'defects' }
                    observation       = @{ value = 2; unit = 'defects' }
                    evidence_links    = @('docs/qa.csv')
                    business_decision = @{ status = 'approved'; owner = 'CFO'; reference = 'FIN-99' }
                    valuation         = @{ currency = 'EUR'; costPerDefect = 100; attributionShare = 1.0; financeApproved = $true; uncertaintyPct = 0.15 }
                }
            )
        } -EvidenceDocument @{
            fileManifestSha256 = 'deadbeef'
            rpiDelivery        = @{ deliverablesProduced = 2; acceptedReviews = 2 }
            accounting         = @{ costUsd = 2.00; counterfactualBaselineUsd = 5.00 }
        }
        $finOnly.summary.overallBasis | Should -Be 'finance-approved'
        $finOnly.summary.financeApprovedValue | Should -Be 800.00
        # USD AI spend without EUR fx_rates is quarantined into gaps rather than mixed across currencies
        $finOnly.gaps.Count | Should -BeGreaterThan 0
        $finOnly.hveDelivery.statedDeliveryLaborBasis | Should -Be 'unmonetized-native-only'
    }

    It 'rejects invalid currency codes, boolean numeric fields, and out-of-range overlap or FX parameters' {
        { Get-HveBenefitValuation -InputDocument @{ currency = 'US$' } } | Should -Throw '*3-letter ISO*'
        { Get-HveBenefitValuation -InputDocument @{ benefit_claims = @(@{ claim_id = '' }) } } | Should -Throw '*claim_id*'
        { Get-HveBenefitValuation -InputDocument @{ benefit_claims = @(@{ claim_id = 'b'; category = 'quality'; status = 'invalid' }) } } | Should -Throw '*invalid status*'
        { Get-HveBenefitValuation -InputDocument @{ benefit_claims = @(@{ claim_id = 'bool-val'; category = 'quality'; baseline = @{ value = $true; unit = 'd' } }) } } | Should -Throw '*boolean*'
        { Get-HveBenefitValuation -InputDocument @{ fx_rates = @{ EUR = 0 }; benefit_claims = @(@{ claim_id = 'fx0'; category = 'quality'; status = 'supported'; baseline = @{ value = 5; unit = 'd' }; observation = @{ value = 1; unit = 'd' }; evidence_links = @('a'); valuation = @{ currency = 'EUR'; costPerDefect = 10; attributionShare = 1.0 } }) } } | Should -Throw '*FX rate*'
        { Get-HveBenefitValuation -InputDocument @{ benefit_claims = @(@{ claim_id = 'ov'; category = 'quality'; valuation = @{ overlapShare = 2.0 } }) } } | Should -Throw '*overlapShare*'
    }
}
