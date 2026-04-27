#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../security/Test-PSModulePins.ps1')

    Mock Write-Host {}

    function script:New-PinFixtureRepo {
        param(
            [Parameter(Mandatory)][string]$Path,
            [Parameter(Mandatory)][hashtable]$Files,
            [Parameter(Mandatory)][string]$ConfigJson
        )

        New-Item -ItemType Directory -Force -Path $Path | Out-Null
        Push-Location $Path
        try {
            git init --quiet --initial-branch=main 2>&1 | Out-Null
            git config user.email 'test@example.com' 2>&1 | Out-Null
            git config user.name  'Test' 2>&1 | Out-Null

            $configDir = Join-Path $Path 'scripts/security'
            New-Item -ItemType Directory -Force -Path $configDir | Out-Null
            $configPath = Join-Path $configDir 'ps-module-versions.json'
            Set-Content -LiteralPath $configPath -Value $ConfigJson -Encoding utf8

            foreach ($rel in $Files.Keys) {
                $full = Join-Path $Path $rel
                $dir = Split-Path -Parent $full
                if ($dir -and -not (Test-Path $dir)) {
                    New-Item -ItemType Directory -Force -Path $dir | Out-Null
                }
                Set-Content -LiteralPath $full -Value $Files[$rel] -Encoding utf8
            }

            git add -A 2>&1 | Out-Null
            git commit --quiet -m 'fixture' 2>&1 | Out-Null
        } finally {
            Pop-Location
        }

        return $configPath
    }

    $script:CanonicalConfig = @'
{
  "modules": {
    "Pester":          { "version": "5.7.1" },
    "PowerShell-Yaml": { "version": "0.4.7" },
    "PSScriptAnalyzer":{ "version": "1.25.0" }
  }
}
'@
}

Describe 'Invoke-PSModulePinScan' -Tag 'Unit' {
    Context 'when all pins match canonical versions' {
        It 'Returns 0 and reports zero violations' {
            $repo = Join-Path $TestDrive 'happy'
            $files = @{
                'scripts/install.ps1' = @(
                    "Install-Module -Name Pester -RequiredVersion 5.7.1 -Force"
                    "Install-Module -Name PowerShell-Yaml -RequiredVersion '0.4.7' -Force"
                ) -join "`n"
                'workflows/lint.yml'  = "      Install-Module -Name PSScriptAnalyzer -RequiredVersion 1.25.0 -Scope CurrentUser"
            }
            $configPath = New-PinFixtureRepo -Path $repo -Files $files -ConfigJson $script:CanonicalConfig

            Push-Location $repo
            try {
                $exit = Invoke-PSModulePinScan -ConfigPath $configPath
            } finally {
                Pop-Location
            }

            $exit | Should -Be 0

            $results = Get-Content -Raw (Join-Path $repo 'logs/ps-module-pins-results.json') | ConvertFrom-Json
            $results.violationCount | Should -Be 0
            $results.pinsFound       | Should -BeGreaterOrEqual 3
        }
    }

    Context 'when a pin does not match the canonical version' {
        It 'Returns 1 and reports the violation with file, line, module, expected, and found fields' {
            $repo = Join-Path $TestDrive 'violation'
            $files = @{
                'scripts/bad.ps1' = @(
                    "# header"
                    "Install-Module -Name Pester -RequiredVersion 5.6.0 -Force"
                ) -join "`n"
            }
            $configPath = New-PinFixtureRepo -Path $repo -Files $files -ConfigJson $script:CanonicalConfig

            Push-Location $repo
            try {
                $exit = Invoke-PSModulePinScan -ConfigPath $configPath
            } finally {
                Pop-Location
            }

            $exit | Should -Be 1

            $results = Get-Content -Raw (Join-Path $repo 'logs/ps-module-pins-results.json') | ConvertFrom-Json
            $results.violationCount | Should -Be 1

            $v = $results.violations[0]
            $v.file     | Should -Be 'scripts/bad.ps1'
            $v.module   | Should -Be 'Pester'
            $v.found    | Should -Be '5.6.0'
            $v.expected | Should -Be '5.7.1'
            $v.line     | Should -Be 2
            $v.snippet  | Should -Match 'Install-Module'
        }
    }

    Context 'when the violation is in a path on the allowed list' {
        It 'Skips the file and returns 0' {
            $repo = Join-Path $TestDrive 'allowed'
            $files = @{
                # This path is in the script's hardcoded $allowedFiles list and must be ignored.
                'scripts/tests/security/Test-SHAStaleness.Tests.ps1' = @(
                    "Install-Module -Name Pester -RequiredVersion 9.9.9 -Force"
                ) -join "`n"
            }
            $configPath = New-PinFixtureRepo -Path $repo -Files $files -ConfigJson $script:CanonicalConfig

            Push-Location $repo
            try {
                $exit = Invoke-PSModulePinScan -ConfigPath $configPath
            } finally {
                Pop-Location
            }

            $exit | Should -Be 0

            $results = Get-Content -Raw (Join-Path $repo 'logs/ps-module-pins-results.json') | ConvertFrom-Json
            $results.violationCount | Should -Be 0
        }
    }

    Context 'when a #Requires-style hashtable pin is mismatched' {
        It 'Detects the violation via the hashtable pattern' {
            $repo = Join-Path $TestDrive 'requires'
            $files = @{
                'scripts/needs.ps1' = "#Requires -Modules @{ ModuleName='PSScriptAnalyzer'; RequiredVersion='1.20.0' }"
            }
            $configPath = New-PinFixtureRepo -Path $repo -Files $files -ConfigJson $script:CanonicalConfig

            Push-Location $repo
            try {
                $exit = Invoke-PSModulePinScan -ConfigPath $configPath
            } finally {
                Pop-Location
            }

            $exit | Should -Be 1

            $results = Get-Content -Raw (Join-Path $repo 'logs/ps-module-pins-results.json') | ConvertFrom-Json
            $results.violationCount | Should -Be 1
            $results.violations[0].module   | Should -Be 'PSScriptAnalyzer'
            $results.violations[0].found    | Should -Be '1.20.0'
            $results.violations[0].expected | Should -Be '1.25.0'
        }
    }

    Context 'when the config path does not exist' {
        It 'Throws a descriptive error' {
            $repo = Join-Path $TestDrive 'missing-config'
            New-Item -ItemType Directory -Force -Path $repo | Out-Null
            Push-Location $repo
            try {
                git init --quiet --initial-branch=main 2>&1 | Out-Null
                { Invoke-PSModulePinScan -ConfigPath (Join-Path $repo 'nope.json') } |
                    Should -Throw '*Pin config not found*'
            } finally {
                Pop-Location
            }
        }
    }

    Context 'when pins use Import-Module or Update-Module verbs' {
        It 'Detects matched and mismatched pins for all three verbs' {
            $repo = Join-Path $TestDrive 'verbs'
            $files = @{
                'scripts/verbs.ps1' = @(
                    "Import-Module -Name Pester -RequiredVersion 5.7.1"
                    "Update-Module -Name PowerShell-Yaml -RequiredVersion 0.4.6"
                ) -join "`n"
            }
            $configPath = New-PinFixtureRepo -Path $repo -Files $files -ConfigJson $script:CanonicalConfig

            Push-Location $repo
            try {
                $exit = Invoke-PSModulePinScan -ConfigPath $configPath
            } finally {
                Pop-Location
            }

            $exit | Should -Be 1

            $results = Get-Content -Raw (Join-Path $repo 'logs/ps-module-pins-results.json') | ConvertFrom-Json
            $results.pinsFound      | Should -Be 2
            $results.violationCount | Should -Be 1
            $results.violations[0].module | Should -Be 'PowerShell-Yaml'
            $results.violations[0].found  | Should -Be '0.4.6'
        }
    }

    Context 'when multiple violations exist across multiple files' {
        It 'Aggregates every violation with correct file and line attribution' {
            $repo = Join-Path $TestDrive 'multi'
            $files = @{
                'scripts/a.ps1' = @(
                    "Install-Module -Name Pester -RequiredVersion 5.0.0 -Force"
                    "Install-Module -Name PowerShell-Yaml -RequiredVersion 0.4.0 -Force"
                ) -join "`n"
                'scripts/b.ps1' = "Install-Module -Name PSScriptAnalyzer -RequiredVersion 1.21.0 -Force"
            }
            $configPath = New-PinFixtureRepo -Path $repo -Files $files -ConfigJson $script:CanonicalConfig

            Push-Location $repo
            try {
                $exit = Invoke-PSModulePinScan -ConfigPath $configPath
            } finally {
                Pop-Location
            }

            $exit | Should -Be 1

            $results = Get-Content -Raw (Join-Path $repo 'logs/ps-module-pins-results.json') | ConvertFrom-Json
            $results.violationCount | Should -Be 3

            $byFile = $results.violations | Group-Object file
            ($byFile | Where-Object Name -eq 'scripts/a.ps1').Count | Should -Be 2
            ($byFile | Where-Object Name -eq 'scripts/b.ps1').Count | Should -Be 1

            $aLines = ($results.violations | Where-Object file -eq 'scripts/a.ps1' | Sort-Object line).line
            $aLines | Should -Be @(1, 2)
        }
    }

    Context 'when a violation is in an untracked file' {
        It 'Ignores the untracked file and returns 0' {
            $repo = Join-Path $TestDrive 'untracked'
            $files = @{
                'scripts/clean.ps1' = "Install-Module -Name Pester -RequiredVersion 5.7.1 -Force"
            }
            $configPath = New-PinFixtureRepo -Path $repo -Files $files -ConfigJson $script:CanonicalConfig

            # Add an untracked file containing a clear violation after the fixture commit.
            Set-Content -LiteralPath (Join-Path $repo 'scripts/untracked.ps1') `
                -Value "Install-Module -Name Pester -RequiredVersion 9.9.9 -Force" -Encoding utf8

            Push-Location $repo
            try {
                $exit = Invoke-PSModulePinScan -ConfigPath $configPath
            } finally {
                Pop-Location
            }

            $exit | Should -Be 0
            $results = Get-Content -Raw (Join-Path $repo 'logs/ps-module-pins-results.json') | ConvertFrom-Json
            $results.violationCount | Should -Be 0
        }
    }

    Context 'when a violation appears in a file with an unsupported extension' {
        It 'Skips the file based on extension filtering' {
            $repo = Join-Path $TestDrive 'ext'
            $files = @{
                'notes.txt'         = "Install-Module -Name Pester -RequiredVersion 9.9.9 -Force"
                'scripts/keep.ps1'  = "Install-Module -Name Pester -RequiredVersion 5.7.1 -Force"
            }
            $configPath = New-PinFixtureRepo -Path $repo -Files $files -ConfigJson $script:CanonicalConfig

            Push-Location $repo
            try {
                $exit = Invoke-PSModulePinScan -ConfigPath $configPath
            } finally {
                Pop-Location
            }

            $exit | Should -Be 0
            $results = Get-Content -Raw (Join-Path $repo 'logs/ps-module-pins-results.json') | ConvertFrom-Json
            $results.violationCount | Should -Be 0
            $results.pinsFound      | Should -Be 1
        }
    }

    Context 'results JSON metadata' {
        It 'Records configPath, canonical map, filesScanned, and allowedFiles' {
            $repo = Join-Path $TestDrive 'metadata'
            $files = @{
                'scripts/install.ps1' = "Install-Module -Name Pester -RequiredVersion 5.7.1 -Force"
            }
            $configPath = New-PinFixtureRepo -Path $repo -Files $files -ConfigJson $script:CanonicalConfig

            Push-Location $repo
            try {
                Invoke-PSModulePinScan -ConfigPath $configPath | Out-Null
            } finally {
                Pop-Location
            }

            $results = Get-Content -Raw (Join-Path $repo 'logs/ps-module-pins-results.json') | ConvertFrom-Json
            $results.configPath              | Should -Match 'ps-module-versions\.json$'
            $results.canonical.Pester        | Should -Be '5.7.1'
            $results.canonical.'PowerShell-Yaml' | Should -Be '0.4.7'
            $results.filesScanned            | Should -BeGreaterOrEqual 1
            $results.allowedFiles            | Should -Contain 'scripts/security/ps-module-versions.json'
            $results.allowedFiles            | Should -Contain 'scripts/security/Test-PSModulePins.ps1'
        }
    }
}
