#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $script:templatePath = Join-Path $script:repoRoot '.github/skills/accessibility/accessibility/references/ci/accessibility-coverage.workflow-template.yml'
    $script:template = Get-Content -LiteralPath $script:templatePath -Raw
}

Describe 'Accessibility coverage workflow template' -Tag 'Unit' {
    It 'Keeps intent verification inactive only when no authored records exist' {
        $script:template | Should -Match 'intent_records=\(.*TARGET_INTENT_DIR.*\.intent\.yaml.*\)'
        $script:template | Should -Match 'if \[ "\$\{#intent_records\[@\]\}" -eq 0 \]'
    }

    It 'Fails when authored records exist without a runtime config' {
        $script:template | Should -Match 'Design intent records exist, but .*TARGET_CONFIG.* is missing'
    }

    It 'Uses vendored direct-script invocations after removing stale results' {
        $removeIndex = $script:template.IndexOf('rm -f -- "${{ env.TARGET_RESULTS }}"')
        $runInvocation = 'uv run --project "${{ github.workspace }}/${{ env.HARNESS_PROJECT_DIR }}" "${{ github.workspace }}/${{ env.HARNESS_PROJECT_DIR }}/scripts/runtime_a11y/__main__.py" run-all'
        $verifyInvocation = 'uv run --project "${{ github.workspace }}/${{ env.HARNESS_PROJECT_DIR }}" "${{ github.workspace }}/${{ env.HARNESS_PROJECT_DIR }}/scripts/runtime_a11y/__main__.py" verify-intent'
        $runIndex = $script:template.IndexOf($runInvocation)

        $removeIndex | Should -BeGreaterThan -1
        $removeIndex | Should -BeLessThan $runIndex
        $runIndex | Should -BeGreaterThan -1
        $script:template.IndexOf($verifyInvocation) | Should -BeGreaterThan $runIndex
    }

    It 'Prefers explicit probe identity and falls back to evidence text' {
        $script:template | Should -Match '(?s)def probe_for\(item\):\s+probe_id = item\.get\("probeId"\)\s+if probe_id in all_gated:\s+return probe_id\s+evidence = str\(item\.get\("evidence", ""\)\)'
        $script:template | Should -Match 'probe_id = probe_for\(item\)'
    }

    It 'Fails when authored records exist without current runtime results' {
        $script:template | Should -Match 'Design intent records exist, but no current runtime results file was produced'
    }
}