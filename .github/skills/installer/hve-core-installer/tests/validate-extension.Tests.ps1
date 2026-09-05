#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

Describe 'validate-extension' -Tag 'Unit' {
    BeforeAll {
        $script:scriptPath = Join-Path $PSScriptRoot '../scripts/validate-extension.ps1'
        $script:bashScriptPath = Join-Path $PSScriptRoot '../scripts/validate-extension.sh'
        $script:testRoot = Join-Path ([System.IO.Path]::GetTempPath()) "hve-test-valext-$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $script:testRoot -Force | Out-Null
    }

    AfterAll {
        Remove-Item Function:/code -ErrorAction SilentlyContinue
        Remove-Item Function:/code-insiders -ErrorAction SilentlyContinue
        if (Test-Path $script:testRoot) {
            Remove-Item $script:testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Extension installed' {
        It 'Reports EXTENSION_INSTALLED=True when extension is listed' {
            Set-Item Function:/code -Value {
                if ($args -contains '--show-versions') {
                    'ms-vscode.powershell@2024.1.0'
                    'ise-hve-essentials.hve-core@3.0.2'
                    'github.copilot@1.0.0'
                }
                else {
                    'ms-vscode.powershell'
                    'ise-hve-essentials.hve-core'
                    'github.copilot'
                }
            }

            $output = & $script:scriptPath -CodeCli 'code' 6>&1 | Out-String

            $output | Should -Match 'EXTENSION_INSTALLED=True'
        }

        It 'Reports extension version when available' {
            Set-Item Function:/code-insiders -Value {
                if ($args -contains '--show-versions') {
                    'ise-hve-essentials.hve-core@3.0.2'
                }
                else {
                    'ise-hve-essentials.hve-core'
                }
            }

            $output = & $script:scriptPath -CodeCli 'code-insiders' 6>&1 | Out-String

            $output | Should -Match '3\.0\.2'
        }
    }

    Context 'Extension not installed' {
        It 'Reports EXTENSION_INSTALLED=False when extension is not listed' {
            Set-Item Function:/code -Value {
                'ms-vscode.powershell'
                'github.copilot'
            }

            $output = & $script:scriptPath -CodeCli 'code' 6>&1 | Out-String

            $output | Should -Match 'EXTENSION_INSTALLED=False'
        }
    }

    Context 'Default codeCli' {
        It 'Has a default value for CodeCli parameter' {
            $param = (Get-Command $script:scriptPath).Parameters['CodeCli']
            $param | Should -Not -BeNullOrEmpty
            $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } | Should -Not -BeNullOrEmpty
        }

        It 'Restricts CodeCli to the two supported command names' {
            $validateSet = (Get-Command $script:scriptPath).Parameters['CodeCli'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }

            $validateSet.ValidValues | Should -Be @('code', 'code-insiders')
            { & $script:scriptPath -CodeCli (Join-Path $script:testRoot 'untrusted-code') } |
                Should -Throw -ExpectedMessage '*code*code-insiders*'
        }
    }

    Context 'Bash command allowlist' -Skip:(-not $IsLinux -and -not $IsMacOS) {
        It 'Rejects an unsupported command before execution and names allowed values' {
            $marker = Join-Path $script:testRoot 'executed.txt'
            $untrusted = Join-Path $script:testRoot 'untrusted-code'
            "#!/usr/bin/env bash`ntouch '$marker'" | Set-Content -LiteralPath $untrusted -NoNewline
            & chmod +x $untrusted

            $previous = [System.Environment]::GetEnvironmentVariable('code_cli')
            try {
                [System.Environment]::SetEnvironmentVariable('code_cli', $untrusted)
                $output = & bash $script:bashScriptPath 2>&1 | Out-String
                $LASTEXITCODE | Should -Not -Be 0
                $output | Should -Match 'Allowed values: code, code-insiders'
                Test-Path -LiteralPath $marker | Should -BeFalse
            }
            finally {
                [System.Environment]::SetEnvironmentVariable('code_cli', $previous)
            }
        }
    }
}
