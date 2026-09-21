#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
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
        $script:securityAgentPath = Join-Path $script:repoRoot '.github/agents/security/security-planner.agent.md'
        $script:securityIdentityPath = Join-Path $script:repoRoot '.github/instructions/security/identity.instructions.md'
        $script:sharedBasePath = Join-Path $script:repoRoot '.github/instructions/shared/planner-identity-base.instructions.md'
        $script:disclaimerSourcePath = Join-Path $script:repoRoot '.github/instructions/shared/disclaimer-language.instructions.md'
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

    Context 'Security disclaimer cadence contract' {
        It 'Security entry surfaces load the canonical instruction and halt when it is unavailable' {
            $paths = @(
                $script:securityAgentPath
                (Join-Path $script:repoRoot '.github/prompts/security/security-capture.prompt.md')
                (Join-Path $script:repoRoot '.github/prompts/security/security-plan-from-prd.prompt.md')
            )

            foreach ($path in $paths) {
                $content = Get-Content -Path $path -Raw
                $content | Should -Match 'locate .*instruction file named `disclaimer-language\.instructions\.md`'
                $content | Should -Not -Match '#file:\.\./\.\./instructions/shared/disclaimer-language\.instructions\.md'
                $content | Should -Match 'read .*disclaimer-language\.instructions\.md.*in full'
                $content | Should -Match 'cannot be found or loaded, halt before questions, analysis, state initialization, or phase work'
            }
        }

        It 'Security entry surfaces use null-gated automatic display and explicit redisplay details' {
            $paths = @(
                $script:securityAgentPath
                (Join-Path $script:repoRoot '.github/prompts/security/security-capture.prompt.md')
                (Join-Path $script:repoRoot '.github/prompts/security/security-plan-from-prd.prompt.md')
            )

            foreach ($path in $paths) {
                $content = Get-Content -Path $path -Raw
                $content | Should -Match 'disclaimerShownAt.*null'
                $content | Should -Match 'suppress automatic redisplay during normal continuation'
                $content | Should -Match 'details\.reason: "user-requested-redisplay"'
                $content | Should -Not -Match 'start of every new conversation'
            }
        }

        It 'Shared and Security instructions agree on latest-display semantics' {
            $sharedBase = Get-Content -Path $script:sharedBasePath -Raw
            $securityIdentity = Get-Content -Path $script:securityIdentityPath -Raw
            $disclaimerSource = Get-Content -Path $script:disclaimerSourcePath -Raw

            $sharedBase | Should -Match 'RAI, SSSC, Security, Accessibility, and Privacy planners do'
            $sharedBase | Should -Not -Match 'Security Planner does not'
            $sharedBase | Should -Match 'details\.reason: "user-requested-redisplay"'
            $securityIdentity | Should -Match 'adopts the shared Disclaimer Cadence'
            $disclaimerSource | Should -Match 'most recent time the full disclaimer was shown'
            $disclaimerSource | Should -Not -Match 'never overwritten'
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
