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
    It 'renders only completed Demo Material Author runs on main' {
        $script:Render | Should -Match '(?ms)^on:\r?\n  workflow_run:\r?\n    workflows:\r?\n      - Demo Material Author\r?\n    branches:\r?\n      - main\r?\n    types:\r?\n      - completed'
        $script:Render | Should -Match 'authorRun = context\.payload\.workflow_run'
    }

    It 'does not poll or dispatch rendering from the author workflow' {
        $script:Render | Should -Not -Match 'waitForRun|30 \* 60 \* 1000'
        $script:AuthorSource | Should -Not -Match '(?m)^  dispatch-render:'
        $script:AuthorLock | Should -Not -Match '(?m)^  dispatch-render:'
    }
}
