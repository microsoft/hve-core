#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Asserts every Security / SSSC entry prompt has a `## Startup` block and the correct
    framework attribution string.
.NOTES
    Effective case count: 6 (1 `It` block × `-ForEach $script:prompts` arity 6).
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

Describe 'Planner entry prompts expose Startup block + framework attribution' {
    BeforeAll {
        $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    }

    It 'Prompt <Name> contains ## Startup and expected attribution' -ForEach $script:prompts {
        $path = Join-Path $script:repoRoot ".github/prompts/security/$Name.prompt.md"
        Test-Path $path | Should -BeTrue -Because "$Name.prompt.md must exist"
        $content = Get-Content -Path $path -Raw
        $content | Should -Match '(?m)^##\s+Startup\s*$' -Because "$Name must have a ## Startup heading"
        $content | Should -BeLike "*$Attribution*" -Because "$Name must reference its framework attribution"
    }
}
