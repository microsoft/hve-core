#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    Import-Module PowerShell-Yaml -ErrorAction Stop

    $script:RepoRoot = Join-Path $PSScriptRoot '../../..'
    $script:ActionPath = Join-Path $script:RepoRoot '.github/actions/setup-zizmor/action.yml'
    $script:ActionYaml = Get-Content -Raw $script:ActionPath | ConvertFrom-Yaml
    $script:InstallStep = $script:ActionYaml.runs.steps | Where-Object { $_.id -eq 'install' }
    $script:Manifest = Get-Content -Raw (Join-Path $script:RepoRoot 'scripts/security/tool-checksums.json') | ConvertFrom-Json
    $script:Zizmor = $script:Manifest.tools | Where-Object name -EQ 'zizmor'
}

Describe 'setup-zizmor composite action' -Tag 'Unit' {
    It 'Reads zizmor from the tool manifest' {
        $script:InstallStep.env.MANIFEST_PATH | Should -Be '${{ github.action_path }}/../../../scripts/security/tool-checksums.json'
        $script:InstallStep.run | Should -Match 'select\(\.name == \\"zizmor\\"\)'
    }

    It 'Hard-codes no zizmor version or checksum' {
        $raw = Get-Content -Raw $script:ActionPath
        $raw | Should -Not -Match ([regex]::Escape($script:Zizmor.version))
        foreach ($digest in $script:Zizmor.sha256ByArch.PSObject.Properties.Value) {
            $raw | Should -Not -Match $digest
        }
    }

    It 'Verifies the archive checksum before extracting and the installed version after' {
        $run = $script:InstallStep.run
        $run | Should -Match 'sha256sum -c'
        $run.IndexOf('sha256sum -c') | Should -BeLessThan $run.IndexOf('tar -xzf')
        $run | Should -Match '"\$\{installed\}" != "\$\{version\}"'
    }

    It 'Restricts downloads to HTTPS zizmorcore/zizmor release assets' {
        $script:InstallStep.run | Should -Match "--proto '=https'"
        $script:InstallStep.run | Should -Match 'https://github\.com/zizmorcore/zizmor/releases/download/v'
    }

    It 'Installs without writing GITHUB_PATH and rejects a shadowing binary' {
        $script:InstallStep.run | Should -Not -Match '>>\s*"?\$\{?GITHUB_(PATH|ENV)'
        $script:InstallStep.run | Should -Match '"\$\{resolved\}" != ''/usr/local/bin/zizmor'''
    }

    It 'Supports only Linux X64 and ARM64 runners' {
        $script:InstallStep.run | Should -Match 'Linux/X64\) arch_key=''linux_amd64'''
        $script:InstallStep.run | Should -Match 'Linux/ARM64\) arch_key=''linux_arm64'''
    }

    It 'Keeps expressions out of the run script' {
        $script:InstallStep.run | Should -Not -Match '\$\{\{'
    }

    It 'Has an attested manifest entry for every architecture it supports' {
        $script:Zizmor.verification | Should -Be 'attestation'
        $script:Zizmor.attestation.signerWorkflow | Should -Be '.github/workflows/release-binaries.yml'
        foreach ($arch in 'linux_amd64', 'linux_arm64') {
            $script:Zizmor.assetTemplateByArch.$arch | Should -Match '^https://github\.com/zizmorcore/zizmor/releases/download/v\{version\}/.+\.tar\.gz$'
            $script:Zizmor.sha256ByArch.$arch | Should -Match '^[0-9a-f]{64}$'
        }
    }
}
