#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    Import-Module PowerShell-Yaml -ErrorAction Stop

    $script:RepoRoot = Join-Path $PSScriptRoot '../../..'
    $script:ActionPath = Join-Path $script:RepoRoot '.github/actions/resolve-merged-pr/action.yml'
    $script:Action = Get-Content -Raw -LiteralPath $script:ActionPath | ConvertFrom-Yaml
    $script:ResolveStep = $script:Action.runs.steps | Where-Object id -EQ 'resolve'
}

Describe 'resolve-merged-pr composite action' -Tag 'Unit' {
    It 'exports the release identity fields used by both callers' {
        @($script:Action.outputs.Keys | Sort-Object) | Should -Be @(
            'base-ref'
            'head-ref'
            'head-repository'
            'head-sha'
            'merge-sha'
            'merged'
        )
    }

    It 'uses bounded backoff and fails when association remains empty' {
        $run = $script:ResolveStep.run
        $run | Should -Match 'readonly MAX_ATTEMPTS=4'
        $run | Should -Match 'sleep "\$\{delay\}"'
        $run | Should -Match 'if \(\( count == 0 \)\); then'
        $run | Should -Match 'exit 1'
        $run | Should -Not -Match 'merged=false'
    }

    It 'preserves branch repository head and merge identity outputs' {
        $run = $script:ResolveStep.run
        foreach ($name in 'merged', 'base-ref', 'head-ref', 'head-repository', 'head-sha', 'merge-sha') {
            $run | Should -Match ([regex]::Escape("$name="))
        }
    }

    It 'is the only merge resolver used by stable and prerelease workflows' {
        foreach ($workflow in 'release-prerelease.yml', 'release-stable-publish.yml') {
            $content = Get-Content -Raw -LiteralPath (Join-Path $script:RepoRoot ".github/workflows/$workflow")
            ([regex]::Matches($content, 'uses: \$/.github/actions/resolve-merged-pr')).Count | Should -Be 1
            $content | Should -Not -Match '/commits/\$EVENT_SHA/pulls'
        }
    }
}
