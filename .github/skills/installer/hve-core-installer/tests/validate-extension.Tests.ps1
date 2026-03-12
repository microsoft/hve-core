#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

Describe 'validate-extension' -Tag 'Unit' {
    BeforeAll {
        $script:scriptPath = Join-Path $PSScriptRoot '../scripts/validate-extension.ps1'
        $script:testRoot = Join-Path ([System.IO.Path]::GetTempPath()) "hve-test-valext-$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $script:testRoot -Force | Out-Null
    }

    AfterAll {
        if (Test-Path $script:testRoot) {
            Remove-Item $script:testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Extension installed' {
        It 'Reports EXTENSION_INSTALLED=True when extension is listed' {
            # Create a mock script that simulates the code CLI
            $mockPath = Join-Path $script:testRoot 'mock-code-found.ps1'
            @'
if ($args -contains '--show-versions') {
    'ms-vscode.powershell@2024.1.0'
    'ise-hve-essentials.hve-core@3.0.2'
    'github.copilot@1.0.0'
} else {
    'ms-vscode.powershell'
    'ise-hve-essentials.hve-core'
    'github.copilot'
}
'@ | Set-Content $mockPath

            $output = & $script:scriptPath -CodeCli $mockPath 6>&1 | Out-String

            $output | Should -Match 'EXTENSION_INSTALLED=True'
        }

        It 'Reports extension version when available' {
            $mockPath = Join-Path $script:testRoot 'mock-code-version.ps1'
            @'
if ($args -contains '--show-versions') {
    'ise-hve-essentials.hve-core@3.0.2'
} else {
    'ise-hve-essentials.hve-core'
}
'@ | Set-Content $mockPath

            $output = & $script:scriptPath -CodeCli $mockPath 6>&1 | Out-String

            $output | Should -Match '3\.0\.2'
        }
    }

    Context 'Extension not installed' {
        It 'Reports EXTENSION_INSTALLED=False when extension is not listed' {
            $mockPath = Join-Path $script:testRoot 'mock-code-notfound.ps1'
            @'
'ms-vscode.powershell'
'github.copilot'
'@ | Set-Content $mockPath

            $output = & $script:scriptPath -CodeCli $mockPath 6>&1 | Out-String

            $output | Should -Match 'EXTENSION_INSTALLED=False'
        }
    }

    Context 'Default codeCli' {
        It 'Has a default value for CodeCli parameter' {
            $param = (Get-Command $script:scriptPath).Parameters['CodeCli']
            $param | Should -Not -BeNullOrEmpty
            $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } | Should -Not -BeNullOrEmpty
        }
    }
}
