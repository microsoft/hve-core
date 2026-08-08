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

    It 'Removes stale results before invoking run-all' {
        $removeIndex = $script:template.IndexOf('rm -f -- "${{ env.TARGET_RESULTS }}"')
        $runIndex = $script:template.IndexOf('runtime_a11y run-all')

        $removeIndex | Should -BeGreaterThan -1
        $removeIndex | Should -BeLessThan $runIndex
    }

    It 'Fails when authored records exist without current runtime results' {
        $script:template | Should -Match 'Design intent records exist, but no current runtime results file was produced'
    }
}