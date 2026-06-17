#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Asserts planner startup prompts and instruction-level disclaimer contracts are present.
.NOTES
    Effective case count: 9 (1 `It` block x `-ForEach $script:prompts` arity 6, plus 3 Accessibility contract tests).
#>

$script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path

$securityAttribution = 'OWASP ASVS • OWASP Top 10 • NIST SSDF'
$ssscAttribution = 'OpenSSF Scorecard • SLSA Build Levels • OpenSSF Best Practices Badge • Sigstore • SBOM'

$script:prompts = @(
    @{ Name = 'security-capture';          Attribution = $securityAttribution }
    @{ Name = 'security-plan-from-prd';    Attribution = $securityAttribution }
    @{ Name = 'sssc-capture';              Attribution = $ssscAttribution }
    @{ Name = 'sssc-from-brd';             Attribution = $ssscAttribution }
    @{ Name = 'sssc-from-prd';             Attribution = $ssscAttribution }
    @{ Name = 'sssc-from-security-plan';   Attribution = $ssscAttribution }
)

Describe 'Planner startup disclosures' -Tag 'Unit' {
    BeforeAll {
        $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
        $script:accessibilityIdentityPath = Join-Path $script:repoRoot '.github/instructions/accessibility/accessibility-identity.instructions.md'
    }

    Context 'Security and SSSC entry prompts' {
        It 'Prompt <Name> contains ## Startup and expected attribution' -ForEach $script:prompts {
            $path = Join-Path $script:repoRoot ".github/prompts/security/$Name.prompt.md"
            Test-Path $path | Should -BeTrue -Because "$Name.prompt.md must exist"
            $content = Get-Content -Path $path -Raw
            $content | Should -Match '(?m)^##\s+Startup\s*$' -Because "$Name must have a ## Startup heading"
            $content | Should -BeLike "*$Attribution*" -Because "$Name must reference its framework attribution"
        }
    }

    Context 'Accessibility instruction disclaimer contract' {
        It 'Requires the canonical accessibility disclaimer before Phase 1 work begins' {
            Test-Path $script:accessibilityIdentityPath | Should -BeTrue -Because 'Accessibility identity instructions must exist'
            $content = Get-Content -Path $script:accessibilityIdentityPath -Raw

            $content | Should -Match "The planner follows the shared base's Session Start Display cadence" -Because 'Accessibility should inherit shared startup cadence'
            $content | Should -Match 'emit the canonical accessibility disclaimer block below verbatim before Phase 1 work begins' -Because 'Accessibility disclaimer must be upfront, not handoff-only'
        }

        It 'Records session-start disclaimer state and notice log updates' {
            Test-Path $script:accessibilityIdentityPath | Should -BeTrue -Because 'Accessibility identity instructions must exist'
            $content = Get-Content -Path $script:accessibilityIdentityPath -Raw

            $content | Should -Match 'Record the timestamp in `state\.disclaimerShownAt`' -Because 'Startup display must update planner state'
            $content | Should -Match 'noticeType: "session-start-disclaimer"' -Because 'Startup display must log the session-start notice type'
        }

        It 'Keeps session-start logging distinct from handoff artifact disclaimer logging' {
            Test-Path $script:accessibilityIdentityPath | Should -BeTrue -Because 'Accessibility identity instructions must exist'
            $content = Get-Content -Path $script:accessibilityIdentityPath -Raw

            $content | Should -Match 'emit the canonical accessibility disclaimer block below verbatim before Phase 1 work begins' -Because 'Canonical disclaimer source must define startup behavior'
            $content | Should -Match 'noticeType: "session-start-disclaimer"' -Because 'Canonical disclaimer source must define startup notice logging'
            $content | Should -Match 'noticeType: "handoff-disclaimer"' -Because 'Handoff artifact logging must remain separate from startup display'
        }
    }
}
