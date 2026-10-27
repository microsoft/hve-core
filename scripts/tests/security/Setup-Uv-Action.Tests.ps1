#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    Import-Module PowerShell-Yaml -ErrorAction Stop

    $script:RepoRoot = Join-Path $PSScriptRoot '../../..'
    $script:ActionPath = Join-Path $script:RepoRoot '.github/actions/setup-uv/action.yml'
    $script:ActionYaml = Get-Content -Raw $script:ActionPath | ConvertFrom-Yaml
    $script:InstallStep = $script:ActionYaml.runs.steps | Where-Object { $_.id -eq 'install' }
    $script:Manifest = Get-Content -Raw (Join-Path $script:RepoRoot 'scripts/security/tool-checksums.json') | ConvertFrom-Json
    $script:Uv = $script:Manifest.tools | Where-Object name -EQ 'uv'
}

Describe 'setup-uv composite action' -Tag 'Unit' {
    Context 'verified install' {
        It 'Reads uv from the tool manifest' {
            $script:InstallStep.env.MANIFEST_PATH | Should -Be '${{ github.action_path }}/../../../scripts/security/tool-checksums.json'
            $script:InstallStep.run | Should -Match 'select\(\.name == \\"uv\\"\)'
        }

        It 'Hard-codes no uv version or checksum' {
            $raw = Get-Content -Raw $script:ActionPath
            $raw | Should -Not -Match ([regex]::Escape($script:Uv.version))
            foreach ($digest in $script:Uv.sha256ByArch.PSObject.Properties.Value) {
                $raw | Should -Not -Match $digest
            }
        }

        It 'Verifies the archive checksum and the installed version' {
            $script:InstallStep.run | Should -Match 'sha256sum -c'
            $script:InstallStep.run | Should -Match '"\$\{installed\}" != "\$\{version\}"'
        }

        It 'Restricts downloads to HTTPS astral-sh/uv release assets' {
            $script:InstallStep.run | Should -Match "--proto '=https'"
            $script:InstallStep.run | Should -Match 'https://github\.com/astral-sh/uv/releases/download/'
        }

        It 'Keeps expressions out of the run script' {
            $script:InstallStep.run | Should -Not -Match '\$\{\{'
        }
    }

    Context 'cache' {
        It 'Disables auto caching for privileged and tag events' {
            $script:InstallStep.run | Should -Match 'release \| pull_request_target \| workflow_run\) cache=''false'''
            $script:InstallStep.run | Should -Match 'refs/tags/\*'
        }

        It 'Never saves the cache on merge_group' {
            $script:InstallStep.run | Should -Match '"\$\{GITHUB_EVENT_NAME\}" != ''merge_group'''
            $restoreOnly = $script:ActionYaml.runs.steps | Where-Object { $_.id -eq 'cache-restore' }
            $restoreOnly.uses | Should -Match '^actions/cache/restore@[0-9a-f]{40}$'
            $restoreOnly.if | Should -Match "save != 'true'"
        }

        It 'Uses SHA-pinned cache actions with matching keys' {
            $cacheSteps = @($script:ActionYaml.runs.steps | Where-Object { $_.id -in 'cache-save', 'cache-restore' })
            $cacheSteps | Should -HaveCount 2
            $cacheSteps.uses | ForEach-Object { $_ | Should -Match '^actions/cache(/restore)?@[0-9a-f]{40}$' }
            $cacheSteps[0].with.key | Should -Be $cacheSteps[1].with.key
            $cacheSteps[0].with.key | Should -Match 'uv-version'
            $cacheSteps[0].with.key | Should -Match "hashFiles\('\*\*/\*requirements\*\.txt'.*'\*\*/uv\.lock'"
        }
    }

    Context 'workflow consumers' {
        It 'Leaves no astral-sh/setup-uv step in workflows' {
            $workflowDir = Join-Path $script:RepoRoot '.github/workflows'
            $hits = Get-ChildItem $workflowDir -Filter '*.yml' | Select-String -Pattern 'uses:\s*[''"]?astral-sh/setup-uv'
            $hits | Should -BeNullOrEmpty
        }

        It 'Installs uv through the composite in <File>' -ForEach @(
            @{ File = 'demo-material-render.yml'; Count = 1 }
            @{ File = 'eval-validation.yml'; Count = 2 }
            @{ File = 'fuzz-tests.yml'; Count = 1 }
            @{ File = 'pip-audit.yml'; Count = 1 }
            @{ File = 'pytest-tests.yml'; Count = 1 }
            @{ File = 'python-lint.yml'; Count = 1 }
        ) {
            $workflow = Get-Content -Raw (Join-Path $script:RepoRoot ".github/workflows/$File") | ConvertFrom-Yaml
            $found = 0
            foreach ($job in $workflow.jobs.Values) {
                $steps = @($job.steps)
                for ($i = 0; $i -lt $steps.Count; $i++) {
                    if ($steps[$i].uses -ne '$/.github/actions/setup-uv') { continue }
                    $found++
                    $checkout = @($steps[0..$i] | Where-Object { $_.uses -like 'actions/checkout@*' })
                    $checkout | Should -HaveCount 1
                    $checkout[0].with.Keys | Should -Not -Contain 'path'
                    $checkout[0].with.Keys | Should -Not -Contain 'repository'
                }
            }
            $found | Should -Be $Count
        }
    }
}
