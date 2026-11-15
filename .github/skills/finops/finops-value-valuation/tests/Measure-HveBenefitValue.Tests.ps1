#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

Describe 'HveBenefitValuation and Measure-HveBenefitValue' {
    BeforeAll {
        $script:ModulePath = Join-Path $PSScriptRoot '../scripts/HveBenefitValuation.psm1'
        $script:CliPath = Join-Path $PSScriptRoot '../scripts/Measure-HveBenefitValue.ps1'
        Import-Module $script:ModulePath -Force
    }

    It 'monetizes all nine FinOps categories, separates finance-approved from stated-indicative, and computes BCR and ROI' {
        $doc = @{
            report_id = 'hve-nine-cat'
            as_of     = '2026-11-15'
            currency  = 'USD'
            benefit_claims = @(
                @{
                    claim_id          = 'c-rev'
                    category          = 'revenue enablement'
                    hypothesis        = 'Increase checkout conversion'
                    beneficiary       = 'Commerce'
                    measurement_owner = 'Growth'
                    status            = 'supported'
                    baseline          = @{ value = 100; unit = 'orders' }
                    observation       = @{ value = 140; unit = 'orders' }
                    evidence_links    = @('docs/orders.csv')
                    business_decision = @{ status = 'approved'; owner = 'CFO'; reference = 'FIN-1' }
                    valuation         = @{ unitValue = 50; attributionShare = 0.8; financeApproved = $true }
                }
                @{
                    claim_id          = 'c-avoid'
                    category          = 'cost avoidance'
                    hypothesis        = 'Prevent GPU over-provisioning'
                    beneficiary       = 'AI Platform'
                    measurement_owner = 'FinOps'
                    status            = 'supported'
                    evidence_links    = @('docs/acm.csv')
                    valuation         = @{ counterfactualCost = 5000; observedCost = 3200; attributionShare = 1.0 }
                }
                @{
                    claim_id          = 'c-cap'
                    category          = 'capacity gained'
                    hypothesis        = 'Release engineering hours via HVE RPI'
                    beneficiary       = 'Platform Eng'
                    measurement_owner = 'Eng Lead'
                    status            = 'supported'
                    baseline          = @{ value = 10; unit = 'hours' }
                    observation       = @{ value = 4; unit = 'hours' }
                    evidence_links    = @('docs/cycle.csv')
                    valuation         = @{ direction = 'decrease'; volume = 20; hourlyRate = 100; redeployedShare = 0.75; attributionShare = 1.0 }
                }
                @{
                    claim_id          = 'c-lab'
                    category          = 'labour augmentation'
                    hypothesis        = 'Assisted dossier completion at constant quality'
                    beneficiary       = 'Risk Ops'
                    measurement_owner = 'Risk Lead'
                    status            = 'supported'
                    baseline          = @{ value = 4; unit = 'hours' }
                    observation       = @{ value = 2; unit = 'hours' }
                    evidence_links    = @('docs/risk.csv')
                    valuation         = @{ direction = 'decrease'; volume = 50; hourlyRate = 80; redeployedShare = 0.5; attributionShare = 1.0; qualityFloorMet = $true }
                }
                @{
                    claim_id          = 'c-qual'
                    category          = 'quality'
                    hypothesis        = 'Reduce escaped production defects'
                    beneficiary       = 'Core API'
                    measurement_owner = 'QA Lead'
                    status            = 'supported'
                    baseline          = @{ value = 15; unit = 'defects' }
                    observation       = @{ value = 5; unit = 'defects' }
                    evidence_links    = @('docs/defects.csv')
                    valuation         = @{ direction = 'decrease'; costPerDefect = 250; attributionShare = 1.0 }
                }
                @{
                    claim_id          = 'c-speed'
                    category          = 'speed'
                    hypothesis        = 'Avoid SLA delay penalties'
                    beneficiary       = 'Onboarding'
                    measurement_owner = 'Delivery'
                    status            = 'supported'
                    baseline          = @{ value = 8; unit = 'days' }
                    observation       = @{ value = 5; unit = 'days' }
                    evidence_links    = @('docs/sla.csv')
                    valuation         = @{ direction = 'decrease'; volume = 10; valuePerTimeUnit = 100; attributionShare = 1.0 }
                }
                @{
                    claim_id          = 'c-risk'
                    category          = 'risk reduction'
                    hypothesis        = 'Lower incident probability'
                    beneficiary       = 'SecOps'
                    measurement_owner = 'CISO'
                    status            = 'supported'
                    evidence_links    = @('docs/sec.csv')
                    valuation         = @{ baselineLikelihood = 0.20; observedLikelihood = 0.05; impactAmount = 20000; attributionShare = 1.0 }
                }
                @{
                    claim_id          = 'c-new'
                    category          = 'new capacity'
                    hypothesis        = 'Deliver compliance reviews previously declined'
                    beneficiary       = 'Legal'
                    measurement_owner = 'Legal Ops'
                    status            = 'supported'
                    baseline          = @{ value = 0; unit = 'reviews' }
                    observation       = @{ value = 20; unit = 'reviews' }
                    evidence_links    = @('docs/legal.csv')
                    valuation         = @{ unitValue = 150; attributionShare = 1.0; demandVerified = $true }
                }
                @{
                    claim_id          = 'c-eng'
                    category          = 'engagement'
                    hypothesis        = 'Self-service adoption driving verified renewals'
                    beneficiary       = 'CS'
                    measurement_owner = 'CS Lead'
                    status            = 'supported'
                    baseline          = @{ value = 100; unit = 'users' }
                    observation       = @{ value = 300; unit = 'users' }
                    evidence_links    = @('docs/cs.csv')
                    valuation         = @{ downstreamConversionRate = 0.10; downstreamUnitValue = 100; attributionShare = 1.0 }
                }
            )
            cost_evidence = @(
                @{ scope = 'enablement'; amount = 5000; currency = 'USD' }
            )
        }

        $res = Get-HveBenefitValuation -InputDocument $doc
        $res.summary.financeApprovedValue | Should -Be 1600.00
        $res.summary.statedIndicativeValue | Should -Be 28300.00
        $res.summary.totalStatedEvidencedValue | Should -Be 29900.00
        $res.summary.netStatedValue | Should -Be 24900.00
        $res.summary.benefitCostRatio | Should -Be 5.98
        $res.summary.statedRoiPct | Should -Be 498.0
    }

    It 'enforces guardrails, overlap_group deduplication, and HVE evidence bundle valuation via CLI' {
        $claimsFile = Join-Path $TestDrive 'claims.json'
        $evFile = Join-Path $TestDrive 'evidence.json'
        $outMd = Join-Path $TestDrive 'report.md'

        $evPayload = @{
            fileManifestSha256 = 'abc123'
            rpiDelivery        = @{ deliverablesProduced = 4; acceptedReviews = 3 }
            accounting         = @{ costUsd = 1.50; counterfactualBaselineUsd = 6.50 }
        } | ConvertTo-Json -Depth 6
        Set-Content -LiteralPath $evFile -Value $evPayload

        $claimsPayload = @{
            report_id          = 'hve-bundle-test'
            as_of              = '2026-11-15'
            delivery_valuation = @{
                baselineHoursPerDeliverable = 5.0
                observedHoursPerDeliverable = 1.0
                hourlyRate                  = 100.0
                redeployedShare             = 0.75
            }
            benefit_claims     = @(
                @{
                    claim_id          = 'c1'
                    category          = 'capacity gained'
                    hypothesis        = 'Primary pool'
                    beneficiary       = 'Eng'
                    measurement_owner = 'Lead'
                    status            = 'supported'
                    overlap_group     = 'shared-pool'
                    baseline          = @{ value = 4; unit = 'hours' }
                    observation       = @{ value = 2; unit = 'hours' }
                    evidence_links    = @('docs/a.csv')
                    valuation         = @{ direction = 'decrease'; volume = 10; hourlyRate = 100; redeployedShare = 0.5; attributionShare = 1.0; primaryInGroup = $true }
                }
                @{
                    claim_id          = 'c2'
                    category          = 'speed'
                    hypothesis        = 'Overlapping speed claim'
                    beneficiary       = 'Eng'
                    measurement_owner = 'Lead'
                    status            = 'supported'
                    overlap_group     = 'shared-pool'
                    baseline          = @{ value = 4; unit = 'hours' }
                    observation       = @{ value = 2; unit = 'hours' }
                    evidence_links    = @('docs/a.csv')
                    valuation         = @{ direction = 'decrease'; volume = 10; valuePerTimeUnit = 40; attributionShare = 1.0 }
                }
                @{
                    claim_id          = 'c3-no-redeploy'
                    category          = 'capacity gained'
                    hypothesis        = 'Unmonetized hours'
                    beneficiary       = 'Eng'
                    measurement_owner = 'Lead'
                    status            = 'supported'
                    baseline          = @{ value = 3; unit = 'hours' }
                    observation       = @{ value = 1; unit = 'hours' }
                    evidence_links    = @('docs/b.csv')
                    valuation         = @{ direction = 'decrease'; hourlyRate = 100; attributionShare = 1.0 }
                }
            )
        } | ConvertTo-Json -Depth 10
        Set-Content -LiteralPath $claimsFile -Value $claimsPayload

        $jsonOut = & pwsh -NoProfile -File $script:CliPath -ClaimsPath $claimsFile -EvidencePath $evFile -OutputPath $outMd -Format json
        $LASTEXITCODE | Should -Be 0
        Test-Path -LiteralPath $outMd -PathType Leaf | Should -BeTrue
        $parsed = $jsonOut | ConvertFrom-Json
        # Delivery labor: 3 * (5 - 1) * 0.75 * 100 = 900.00
        # c1: 2 * 10 * 0.5 * 100 = 1000.00; c2: 800.00 deducted; c3: native-only
        $parsed.summary.totalStatedEvidencedValue | Should -Be 1900.00
        $parsed.summary.overlapDeductionsTotal | Should -Be 800.00
        $parsed.summary.modeledCounterfactualValue | Should -Be 5.00
        $parsed.summary.netStatedValue | Should -Be 1898.50
    }
}
