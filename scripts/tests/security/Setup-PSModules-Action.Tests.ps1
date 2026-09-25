#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    Import-Module PowerShell-Yaml -ErrorAction Stop

    $script:ActionPath = Join-Path $PSScriptRoot '../../../.github/actions/setup-ps-modules/action.yml'
    $script:ActionYaml = Get-Content -Raw $script:ActionPath | ConvertFrom-Yaml
    $script:ActionRaw  = Get-Content -Raw $script:ActionPath
    $script:EvalWorkflowPath = Join-Path $PSScriptRoot '../../../.github/workflows/eval-validation.yml'
    $script:EvalWorkflow = Get-Content -Raw $script:EvalWorkflowPath | ConvertFrom-Yaml
}

Describe 'setup-ps-modules composite action' -Tag 'Unit' {
    Context 'inputs' {
        It 'Does not expose a scope input' {
            $script:ActionYaml.inputs.Keys | Should -Not -Contain 'scope'
        }

        It 'Exposes import, force, and cache-key-suffix inputs' {
            $script:ActionYaml.inputs.Keys | Should -Contain 'import'
            $script:ActionYaml.inputs.Keys | Should -Contain 'force'
            $script:ActionYaml.inputs.Keys | Should -Contain 'cache-key-suffix'
        }
    }

    Context 'install step' {
        It 'Hardcodes Scope to CurrentUser' {
            $script:ActionRaw | Should -Match "Scope\s*=\s*'CurrentUser'"
        }

        It 'Does not reference inputs.scope' {
            $script:ActionRaw | Should -Not -Match 'inputs\.scope'
        }

        It 'Runs unconditionally without a cache-hit gate' {
            $installStep = $script:ActionYaml.runs.steps | Where-Object { $_.name -eq 'Install PowerShell modules' }
            $installStep.Keys | Should -Not -Contain 'if'
        }
    }

    Context 'cache path' {
        It 'Caches the CurrentUser module location' {
            $cacheStep = $script:ActionYaml.runs.steps | Where-Object { $_.id -eq 'ps-cache' }
            $cacheStep.with.path | Should -Be '~/.local/share/powershell/Modules'
        }
    }

    Context 'eval workflow consumers' {
        It 'Uses fail-closed shared setup after checkout in <Job>' -ForEach @(
            @{ Job = 'eval-validation'; NextStep = 'Create logs directory' }
            @{ Job = 'content-moderation'; NextStep = 'Install uv' }
            @{ Job = 'agent-plan'; NextStep = 'Download changed-artifact manifest' }
            @{ Job = 'eval-execute'; NextStep = 'Install uv' }
            @{ Job = 'equivalence-execute'; NextStep = 'Create logs directory' }
        ) {
            $steps = @($script:EvalWorkflow.jobs[$Job].steps)
            $setupSteps = @($steps | Where-Object { $_.uses -eq './.github/actions/setup-ps-modules' })
            $setupSteps | Should -HaveCount 1
            $setupStep = $setupSteps[0]
            $setupIndex = [array]::IndexOf($steps, $setupStep)
            $checkoutStep = @($steps | Where-Object { $_.uses -like 'actions/checkout@*' })
            $checkoutStep | Should -HaveCount 1
            $setupIndex | Should -BeGreaterThan ([array]::IndexOf($steps, $checkoutStep[0]))
            $steps[$setupIndex + 1].name | Should -Be $NextStep
            $setupStep.Keys | Should -Not -Contain 'if'
            $setupStep.Keys | Should -Not -Contain 'continue-on-error'
            $setupStep.Keys | Should -Not -Contain 'run'
            $setupStep.with.Keys | Should -Not -Contain 'force'
            ($steps.run -join "`n") | Should -Not -Match '\bInstall-Module\b'
        }
    }
}
