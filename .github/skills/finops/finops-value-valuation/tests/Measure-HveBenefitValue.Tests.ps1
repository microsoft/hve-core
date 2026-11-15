#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

Describe 'HveBenefitValuation and Measure-HveBenefitValue' -Tag 'Unit' {
    BeforeAll {
        $script:ModulePath = Join-Path $PSScriptRoot '../scripts/HveBenefitValuation.psm1'
        $script:CliPath = Join-Path $PSScriptRoot '../scripts/Measure-HveBenefitValue.ps1'
        if (-not (Get-Command -Name Get-HveBenefitValuation -ErrorAction SilentlyContinue)) {
            Import-Module $script:ModulePath
        }
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

        $jsonOut = & $script:CliPath -ClaimsPath $claimsFile -EvidencePath $evFile -OutputPath $outMd -Format json
        Test-Path -LiteralPath $outMd -PathType Leaf | Should -BeTrue
        $parsed = $jsonOut | ConvertFrom-Json
        # Delivery labor: 3 * (5 - 1) * 0.75 * 100 = 900.00
        # c1: 2 * 10 * 0.5 * 100 = 1000.00; c2: 800.00 deducted; c3: native-only
        $parsed.summary.totalStatedEvidencedValue | Should -Be 1900.00
        $parsed.summary.overlapDeductionsTotal | Should -Be 800.00
        $parsed.summary.modeledCounterfactualValue | Should -Be 5.00
        $parsed.summary.netStatedValue | Should -Be 1898.50

        # Also exercise inline -ClaimsJson, .json OutputPath, and -Format markdown
        $outJsonPath = Join-Path $TestDrive 'report.json'
        $mdOut = & $script:CliPath -ClaimsJson $claimsPayload -EvidencePath $evFile -OutputPath $outJsonPath -Format markdown -AsOf '2026-11-15'
        Test-Path -LiteralPath $outJsonPath -PathType Leaf | Should -BeTrue
        $mdOut | Should -Match 'Stated Monetary Value Report: hve-bundle-test'
    }

    It 'covers FX conversion, currency isolation, pending forecast claims, alternative category formulas, and guardrail refusals' {
        $doc = [pscustomobject]@{
            reportId  = 'fx-and-guardrails'
            asOf      = '2026-11-15'
            currency  = 'USD'
            fxRates   = [pscustomobject]@{ EUR = 1.10 }
            benefitClaims = @(
                [pscustomobject]@{
                    claimId          = 'eur-cost-unit'
                    category         = 'cost-avoidance'
                    hypothesis       = 'Reduce compute hours'
                    beneficiary      = 'Infra'
                    measurementOwner = 'FinOps'
                    status           = 'supported'
                    baseline         = [pscustomobject]@{ value = 100; unit = 'hours' }
                    observation      = [pscustomobject]@{ value = 60; unit = 'hours' }
                    evidenceLinks    = @('docs/infra.csv')
                    valuation        = [pscustomobject]@{ currency = 'EUR'; unitCost = 10; attributionShare = 1.0; confidenceBand = 'high' }
                }
                [pscustomobject]@{
                    claimId          = 'gbp-unconverted'
                    category         = 'capacity-gained'
                    hypothesis       = 'Avoid contractor backfill'
                    beneficiary      = 'Ops'
                    measurementOwner = 'Ops Lead'
                    status           = 'supported'
                    evidenceLinks    = @('docs/ops.csv')
                    valuation        = [pscustomobject]@{ currency = 'GBP'; avoidedExpenseAmount = 2000; attributionShare = 1.0 }
                }
                [pscustomobject]@{
                    claimId          = 'risk-per-incident'
                    category         = 'risk-reduction'
                    hypothesis       = 'Fewer P1 incidents'
                    beneficiary      = 'SRE'
                    measurementOwner = 'SRE Lead'
                    status           = 'supported'
                    baseline         = [pscustomobject]@{ value = 6; unit = 'incidents' }
                    observation      = [pscustomobject]@{ value = 2; unit = 'incidents' }
                    evidenceLinks    = @('docs/sre.csv')
                    valuation        = [pscustomobject]@{ costPerIncident = 500; attributionShare = 1.0; sensitivity = [pscustomobject]@{ low = 1500; high = 2500 } }
                }
                [pscustomobject]@{
                    claimId          = 'pending-forecast'
                    category         = 'revenue-enablement'
                    hypothesis       = 'Target Q1 expansion'
                    beneficiary      = 'Sales'
                    measurementOwner = 'RevOps'
                    status           = 'pending'
                    baseline         = [pscustomobject]@{ value = 10; unit = 'deals' }
                    target           = [pscustomobject]@{ value = 20; unit = 'deals' }
                    valuation        = [pscustomobject]@{ unitMargin = 100; conversionToRecognizedRate = 0.5; attributionShare = 1.0 }
                }
                [pscustomobject]@{
                    claimId          = 'pipeline-only-blocked'
                    category         = 'revenue_enablement'
                    hypothesis       = 'Unconverted pipeline'
                    beneficiary      = 'Sales'
                    measurementOwner = 'RevOps'
                    status           = 'supported'
                    baseline         = [pscustomobject]@{ value = 5; unit = 'deals' }
                    observation      = [pscustomobject]@{ value = 10; unit = 'deals' }
                    evidenceLinks    = @('docs/pipe.csv')
                    valuation        = [pscustomobject]@{ pipelineOnly = $true; unitValue = 100; attributionShare = 1.0 }
                }
                [pscustomobject]@{
                    claimId          = 'labour-quality-failed'
                    category         = 'labor-augmentation'
                    hypothesis       = 'Degraded review quality'
                    beneficiary      = 'Support'
                    measurementOwner = 'Support Lead'
                    status           = 'supported'
                    baseline         = [pscustomobject]@{ value = 5; unit = 'hours' }
                    observation      = [pscustomobject]@{ value = 2; unit = 'hours' }
                    evidenceLinks    = @('docs/sup.csv')
                    valuation        = [pscustomobject]@{ hourlyRate = 50; redeployedShare = 0.8; attributionShare = 1.0; qualityFloorMet = $false }
                }
                [pscustomobject]@{
                    claimId          = 'newcap-unverified'
                    category         = 'new_capacity'
                    hypothesis       = 'Unverified demand'
                    beneficiary      = 'Product'
                    measurementOwner = 'PM'
                    status           = 'supported'
                    baseline         = [pscustomobject]@{ value = 0; unit = 'audits' }
                    observation      = [pscustomobject]@{ value = 10; unit = 'audits' }
                    evidenceLinks    = @('docs/audits.csv')
                    valuation        = [pscustomobject]@{ unitValue = 100; attributionShare = 1.0; demandVerified = $false }
                }
                [pscustomobject]@{
                    claimId          = 'eng-leading-only'
                    category         = 'engagement'
                    hypothesis       = 'MAU increase without downstream conversion'
                    beneficiary      = 'Portal'
                    measurementOwner = 'PM'
                    status           = 'supported'
                    baseline         = [pscustomobject]@{ value = 50; unit = 'mau' }
                    observation      = [pscustomobject]@{ value = 100; unit = 'mau' }
                    evidenceLinks    = @('docs/mau.csv')
                    valuation        = [pscustomobject]@{ attributionShare = 1.0 }
                }
                [pscustomobject]@{
                    claimId          = 'unit-mismatch-claim'
                    category         = 'quality'
                    hypothesis       = 'Mismatched units'
                    beneficiary      = 'Core'
                    measurementOwner = 'QA'
                    status           = 'supported'
                    baseline         = [pscustomobject]@{ value = 10; unit = 'hours' }
                    observation      = [pscustomobject]@{ value = 3; unit = 'defects' }
                    evidenceLinks    = @('docs/qa.csv')
                    valuation        = [pscustomobject]@{ costPerDefect = 100; attributionShare = 1.0 }
                }
            )
            costEvidence = @(
                [pscustomobject]@{ scope = 'eur-tooling'; amount = 100; currency = 'EUR' }
                [pscustomobject]@{ scope = 'modeled-forecast'; amount = 9999; currency = 'USD'; basis = 'modeled' }
                [pscustomobject]@{ scope = 'gbp-missing-fx'; amount = 50; currency = 'GBP' }
            )
        }

        $res = Get-HveBenefitValuation -InputDocument $doc
        # eur-cost-unit: 40 * 10 * 1.10 = 440.00; risk-per-incident: 4 * 500 = 2000.00 => 2440.00
        $res.summary.totalStatedEvidencedValue | Should -Be 2440.00
        # costEvidence: 100 EUR * 1.10 = 110.00 (modeled 9999 and unconverted GBP 50 excluded)
        $res.summary.totalEvidencedCost | Should -Be 110.00
        $res.summary.netStatedValue | Should -Be 2330.00
        # pending-forecast: 10 * 100 * 0.5 = 500.00 in modeledCounterfactualValue
        $res.summary.modeledCounterfactualValue | Should -Be 500.00
        ($res.claims | Where-Object { $_.claimId -eq 'gbp-unconverted' }).monetaryBasis | Should -Be 'unmonetized-native-only'
        ($res.claims | Where-Object { $_.claimId -eq 'labour-quality-failed' }).monetaryBasis | Should -Be 'unmonetized-native-only'
        ($res.claims | Where-Object { $_.claimId -eq 'newcap-unverified' }).monetaryBasis | Should -Be 'unmonetized-native-only'
        ($res.claims | Where-Object { $_.claimId -eq 'eng-leading-only' }).monetaryBasis | Should -Be 'unmonetized-native-only'
        ($res.claims | Where-Object { $_.claimId -eq 'unit-mismatch-claim' }).monetaryBasis | Should -Be 'unmonetized-native-only'
    }

    It 'validates CLI argument and input error guards cleanly' {
        { & $script:CliPath } | Should -Throw '*Supply at least one input*'
        { & $script:CliPath -ClaimsPath 'a.json' -ClaimsJson '{}' } | Should -Throw '*not both*'
        { & $script:CliPath -ClaimsPath (Join-Path $TestDrive 'missing.json') } | Should -Throw '*was not found*'
        { & $script:CliPath -EvidencePath (Join-Path $TestDrive 'missing-ev.json') } | Should -Throw '*was not found*'
        { & $script:CliPath -ClaimsJson '{}' -OutputPath 'https://example.invalid/out.md' } | Should -Throw '*local filesystem path*'
        { Get-HveBenefitValuation -InputDocument @{ benefit_claims = @(@{ claim_id = 'bad-cat'; category = 'unknown' }) } } | Should -Throw '*Unsupported benefit category*'
        { Get-HveBenefitValuation -InputDocument @{ benefit_claims = @(@{ claim_id = 'bad-attr'; category = 'quality'; status = 'supported'; baseline = @{ value = 5; unit = 'd' }; observation = @{ value = 1; unit = 'd' }; evidence_links = @('x'); valuation = @{ attributionShare = 1.5; costPerDefect = 10 } }) } } | Should -Throw '*attributionShare*'
    }
}
