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
        { Get-HveBenefitValuation -InputDocument @{ benefit_claims = @(@{ claim_id = 'nan-val'; category = 'quality'; baseline = @{ value = 'not-a-number'; unit = 'd' } }) } } | Should -Throw '*finite decimal*'
        { Get-HveBenefitValuation -InputDocument @{ fx_rates = @{ EUR = 0 }; benefit_claims = @(@{ claim_id = 'fx0'; category = 'quality'; status = 'supported'; baseline = @{ value = 5; unit = 'd' }; observation = @{ value = 1; unit = 'd' }; evidence_links = @('a'); valuation = @{ currency = 'EUR'; costPerDefect = 10; attributionShare = 1.0 } }) } } | Should -Throw '*FX rate*'
        { Get-HveBenefitValuation -InputDocument @{ benefit_claims = @(@{ claim_id = 'ov'; category = 'quality'; valuation = @{ overlapShare = 2.0 } }) } } | Should -Throw '*overlapShare*'
        { Get-HveBenefitValuation -InputDocument @{ benefit_claims = @(@{ claim_id = 'pf'; category = 'quality'; valuation = @{ periodFactor = 0 } }) } } | Should -Throw '*periodFactor*'
        { Get-HveBenefitValuation -InputDocument @{ benefit_claims = @(@{ claim_id = 'neg-vol'; category = 'quality'; status = 'supported'; evidence_links = @('a'); valuation = @{ attributionShare = 1.0; volume = -2; costPerDefect = 10 } }) } } | Should -Throw '*volume cannot be negative*'
        { Get-HveBenefitValuation -InputDocument @{ benefit_claims = @(@{ claim_id = 'bad-conv'; category = 'revenue enablement'; status = 'supported'; baseline = @{ value = 1; unit = 'u' }; observation = @{ value = 5; unit = 'u' }; evidence_links = @('a'); valuation = @{ attributionShare = 1.0; unitValue = 10; conversionToRecognizedRate = 1.5 } }) } } | Should -Throw '*conversionToRecognizedRate*'
        { Get-HveBenefitValuation -InputDocument @{ benefit_claims = @(@{ claim_id = 'bad-cap-redep'; category = 'capacity gained'; status = 'supported'; baseline = @{ value = 5; unit = 'h' }; observation = @{ value = 1; unit = 'h' }; evidence_links = @('a'); valuation = @{ direction = 'decrease'; attributionShare = 1.0; hourlyRate = 50; redeployedShare = 1.5 } }) } } | Should -Throw '*redeployedShare*'
        { Get-HveBenefitValuation -InputDocument @{ benefit_claims = @(@{ claim_id = 'bad-lab-redep'; category = 'labour augmentation'; status = 'supported'; baseline = @{ value = 5; unit = 'h' }; observation = @{ value = 1; unit = 'h' }; evidence_links = @('a'); valuation = @{ direction = 'decrease'; attributionShare = 1.0; hourlyRate = 50; redeployedShare = 1.5 } }) } } | Should -Throw '*redeployedShare*'
        { Get-HveBenefitValuation -InputDocument @{ benefit_claims = @(@{ claim_id = 'bad-eng-conv'; category = 'engagement'; status = 'supported'; baseline = @{ value = 10; unit = 'u' }; observation = @{ value = 20; unit = 'u' }; evidence_links = @('a'); valuation = @{ attributionShare = 1.0; downstreamConversionRate = 1.5; downstreamUnitValue = 10 } }) } } | Should -Throw '*downstreamConversionRate*'

        $realDir = Join-Path $TestDrive 'safe-real'
        New-Item -ItemType Directory -Path $realDir -Force | Out-Null
        $linkDir = Join-Path $TestDrive 'safe-link'
        if ($IsWindows) {
            New-Item -ItemType Junction -Path $linkDir -Target $realDir | Out-Null
        }
        else {
            New-Item -ItemType SymbolicLink -Path $linkDir -Target $realDir | Out-Null
        }
        { Assert-HveSafePath -CandidatePath (Join-Path $linkDir 'claims.json') } | Should -Throw '*Linked path refused*'
    }

    It 'quarantines incomplete category conversion inputs as unmonetized-native-only and supports finance-approved HVE delivery' {
        $res = Get-HveBenefitValuation -InputDocument @{
            delivery_valuation = @{
                hoursSavedPerAcceptedDeliverable = 3.0
                hourlyRate                       = 120.0
                redeployedShare                  = 0.5
                financeApproved                  = $true
                decisionReference                = 'FIN-DELIV-1'
            }
            benefit_claims     = @(
                @{ claim_id = 'missing-cat'; category = ''; status = 'gap' }
                @{ claim_id = 'no-links'; category = 'quality'; status = 'supported'; evidence_links = @() }
                @{ claim_id = 'no-val'; category = 'quality'; status = 'supported'; evidence_links = @('a') }
                @{ claim_id = 'no-attr'; category = 'quality'; status = 'supported'; evidence_links = @('a'); valuation = @{} }
                @{ claim_id = 'rev-no-unit'; category = 'revenue enablement'; status = 'supported'; baseline = @{ value = 1; unit = 'u' }; observation = @{ value = 5; unit = 'u' }; evidence_links = @('a'); valuation = @{ attributionShare = 1.0 } }
                @{ claim_id = 'cost-neg-diff'; category = 'cost avoidance'; status = 'supported'; evidence_links = @('a'); valuation = @{ attributionShare = 1.0; counterfactualCost = 100; observedCost = 120 } }
                @{ claim_id = 'cost-no-driver'; category = 'cost avoidance'; status = 'supported'; evidence_links = @('a'); valuation = @{ attributionShare = 1.0 } }
                @{ claim_id = 'lab-no-rate'; category = 'labour augmentation'; status = 'supported'; baseline = @{ value = 5; unit = 'h' }; observation = @{ value = 2; unit = 'h' }; evidence_links = @('a'); valuation = @{ attributionShare = 1.0 } }
                @{ claim_id = 'qual-no-cost'; category = 'quality'; status = 'supported'; baseline = @{ value = 5; unit = 'd' }; observation = @{ value = 2; unit = 'd' }; evidence_links = @('a'); valuation = @{ attributionShare = 1.0 } }
                @{ claim_id = 'speed-no-val'; category = 'speed'; status = 'supported'; baseline = @{ value = 5; unit = 'd' }; observation = @{ value = 2; unit = 'd' }; evidence_links = @('a'); valuation = @{ attributionShare = 1.0 } }
                @{ claim_id = 'risk-neg-prob'; category = 'risk reduction'; status = 'supported'; evidence_links = @('a'); valuation = @{ attributionShare = 1.0; baselineLikelihood = 0.05; observedLikelihood = 0.10; impactAmount = 1000 } }
                @{ claim_id = 'risk-no-driver'; category = 'risk reduction'; status = 'supported'; evidence_links = @('a'); valuation = @{ attributionShare = 1.0 } }
                @{ claim_id = 'newcap-no-unit'; category = 'new capacity'; status = 'supported'; baseline = @{ value = 0; unit = 'u' }; observation = @{ value = 5; unit = 'u' }; evidence_links = @('a'); valuation = @{ attributionShare = 1.0 } }
            )
        } -EvidenceDocument @{
            fileManifestSha256 = 'abc999'
            rpiDelivery        = @{ deliverablesProduced = 2; acceptedReviews = 2 }
        }

        # 2 * 3.0 * 0.5 * 120 = 360.00 finance-approved delivery labor value; all 13 incomplete claims quarantined
        $res.hveDelivery.statedDeliveryLaborBasis | Should -Be 'finance-approved'
        $res.summary.financeApprovedValue | Should -Be 360.00
        $res.summary.statedIndicativeValue | Should -Be 0.00
        @($res.claims | Where-Object { $_.monetaryBasis -ne 'unmonetized-native-only' }).Count | Should -Be 0
    }
}
