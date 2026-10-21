#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    Import-Module PowerShell-Yaml -ErrorAction Stop

    $script:RepoRoot = Join-Path $PSScriptRoot '../../..'
    $script:ActionPath = Join-Path $script:RepoRoot '.github/actions/setup-shellcheck/action.yml'
    $script:ActionYaml = Get-Content -Raw $script:ActionPath | ConvertFrom-Yaml
    $script:InstallStep = $script:ActionYaml.runs.steps | Where-Object { $_.id -eq 'install' }
    $script:Manifest = Get-Content -Raw (Join-Path $script:RepoRoot 'scripts/security/tool-checksums.json') | ConvertFrom-Json
    $script:Shellcheck = $script:Manifest.tools | Where-Object name -EQ 'shellcheck'
}

Describe 'setup-shellcheck composite action' -Tag 'Unit' {
    It 'Reads shellcheck from the tool manifest' {
        $script:InstallStep.env.MANIFEST_PATH | Should -Be '${{ github.action_path }}/../../../scripts/security/tool-checksums.json'
        $script:InstallStep.run | Should -Match 'select\(\.name == \\"shellcheck\\"\)'
    }

    It 'Hard-codes no shellcheck version or checksum' {
        $raw = Get-Content -Raw $script:ActionPath
        $raw | Should -Not -Match ([regex]::Escape($script:Shellcheck.version))
        foreach ($digest in $script:Shellcheck.sha256ByArch.PSObject.Properties.Value) {
            $raw | Should -Not -Match $digest
        }
    }

    It 'Verifies the archive checksum before extracting and the installed version after' {
        $run = $script:InstallStep.run
        $run | Should -Match 'sha256sum -c'
        $run.IndexOf('sha256sum -c') | Should -BeLessThan $run.IndexOf('tar -xJf')
        $run | Should -Match '"\$\{installed\}" != "\$\{version\}"'
    }

    It 'Restricts downloads to HTTPS koalaman/shellcheck release assets' {
        $script:InstallStep.run | Should -Match "--proto '=https'"
        $script:InstallStep.run | Should -Match 'https://github\.com/koalaman/shellcheck/releases/download/v'
    }

    It 'Supports only Linux X64 and ARM64 runners' {
        $script:InstallStep.run | Should -Match 'Linux/X64\) arch_key=''linux_amd64'''
        $script:InstallStep.run | Should -Match 'Linux/ARM64\) arch_key=''linux_arm64'''
    }

    It 'Keeps expressions out of the run script' {
        $script:InstallStep.run | Should -Not -Match '\$\{\{'
    }

    It 'Has a manifest asset template for every architecture it supports' {
        foreach ($arch in 'linux_amd64', 'linux_arm64') {
            $script:Shellcheck.assetTemplateByArch.$arch | Should -Match '^https://github\.com/koalaman/shellcheck/releases/download/v\{version\}/.+\.tar\.xz$'
            $script:Shellcheck.sha256ByArch.$arch | Should -Match '^[0-9a-f]{64}$'
        }
    }
}
