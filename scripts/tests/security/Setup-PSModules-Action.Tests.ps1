#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    Import-Module PowerShell-Yaml -ErrorAction Stop

    $script:ActionPath = Join-Path $PSScriptRoot '../../../.github/actions/setup-ps-modules/action.yml'
    $script:ActionYaml = Get-Content -Raw $script:ActionPath | ConvertFrom-Yaml
    $script:ActionRaw  = Get-Content -Raw $script:ActionPath
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
}
