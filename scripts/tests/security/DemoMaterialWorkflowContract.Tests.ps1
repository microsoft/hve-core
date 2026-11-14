#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:RepoRoot = Join-Path $PSScriptRoot '../../..'
    $script:Render = Get-Content -Raw -LiteralPath (Join-Path $script:RepoRoot '.github/workflows/demo-material-render.yml')
    $script:AuthorSource = Get-Content -Raw -LiteralPath (Join-Path $script:RepoRoot '.github/workflows/demo-material-author.md')
    $script:AuthorLock = Get-Content -Raw -LiteralPath (Join-Path $script:RepoRoot '.github/workflows/demo-material-author.lock.yml')
}

Describe 'demo material workflow chaining' -Tag 'Unit' {
    It 'picks up Demo Material Author runs on a daily schedule instead of workflow_run' {
        $script:Render | Should -Not -Match '(?m)^  workflow_run:'
        $script:Render | Should -Match "(?m)^    - cron: '47 3 \* \* \*'"
        $script:Render | Should -Match "(?m)^    - cron: '47 5 \* \* 1'"
        $script:Render | Should -Match 'process\.env\.SCHEDULE === "47 3 \* \* \*"'
        $script:Render | Should -Match 'workflow_id: "demo-material-author\.lock\.yml"'
        $script:Render | Should -Match "if: \$\{\{ github\.event_name == 'schedule' && github\.event\.schedule == '47 5 \* \* 1' \}\}"
    }

    It 'does not poll or dispatch rendering from the author workflow' {
        $script:Render | Should -Not -Match 'waitForRun|30 \* 60 \* 1000'
        $script:AuthorSource | Should -Not -Match '(?m)^  dispatch-render:'
        $script:AuthorLock | Should -Not -Match '(?m)^  dispatch-render:'
    }
}
