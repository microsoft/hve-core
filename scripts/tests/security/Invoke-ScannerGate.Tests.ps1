#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../security/Invoke-ScannerGate.ps1')

    $script:Empty = Join-Path $TestDrive 'exceptions-empty.yml'
    Set-Content -LiteralPath $script:Empty -Value 'exceptions: []' -Encoding utf8

    function script:New-Definition {
        param([int]$ExitCode = 0, [int[]]$ExitCodes = @(0, 1), [object[]]$Results = @(), [switch]$NoSarif)
        $sarifJson = [ordered]@{
            version = '2.1.0'
            runs    = @([ordered]@{
                    tool    = [ordered]@{ driver = [ordered]@{ name = 'fake-scanner'; rules = @([ordered]@{ id = 'fake/rule' }) } }
                    results = @($Results)
                })
        } | ConvertTo-Json -Depth 20
        $writeSarif = -not $NoSarif
        return @{
            SarifPath = 'logs/fake.sarif'
            ExitCodes = $ExitCodes
            Command   = {
                param($sarif)
                if ($writeSarif) { Set-Content -LiteralPath $sarif -Value $sarifJson -Encoding utf8 }
                $global:LASTEXITCODE = $ExitCode
            }.GetNewClosure()
        }
    }

    $script:Finding = [ordered]@{
        ruleId    = 'fake/rule'
        level     = 'error'
        message   = @{ text = 'finding' }
        locations = @(@{ physicalLocation = @{ artifactLocation = @{ uri = 'src/app.py' }; region = @{ startLine = 3 } } })
    }

    function script:Invoke-Fake {
        param([hashtable]$Definition, [string]$Exceptions = $script:Empty)
        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $root | Out-Null
        return Invoke-ScannerGate -Name 'fake' -Definition $Definition -RepoRoot $root -ExceptionsPath $Exceptions 6>$null
    }
}

Describe 'Get-ScannerDefinition' -Tag 'Unit' {
    It 'maps <Scanner> to the SARIF path its CI workflow gates' -ForEach @(
        @{ Scanner = 'workflows'; Sarif = 'logs/workflow-validation.sarif'; Codes = @(0, 1) }
        @{ Scanner = 'tool-version-consistency'; Sarif = 'logs/tool-version-consistency.sarif'; Codes = @(0, 1) }
        @{ Scanner = 'dependency-pinning'; Sarif = 'logs/dependency-pinning-results.sarif'; Codes = @(0) }
    ) {
        $definition = Get-ScannerDefinition -Scanner $Scanner

        $definition.SarifPath | Should -Be $Sarif
        $definition.ExitCodes | Should -Be $Codes
        $definition.Command | Should -BeOfType [scriptblock]
    }
}

Describe 'Invoke-ScannerGate' -Tag 'Unit' {
    It 'passes a clean scan' {
        Invoke-Fake (New-Definition) | Should -Be 0
    }

    It 'passes a scan whose findings exit code is expected and whose findings are excused' {
        $exceptions = Join-Path $TestDrive 'exceptions-fake.yml'
        $expires = [datetime]::UtcNow.Date.AddDays(30).ToString('yyyy-MM-dd')
        Set-Content -LiteralPath $exceptions -Encoding utf8 -Value @"
exceptions:
  - tool: fake-scanner
    rule: fake/rule
    path: src/app.py
    count: 1
    kind: false-positive
    upstream: https://github.com/example/scanner/issues/1
    issue: 1
    owner: octocat
    reason: test fixture
    expires: $expires
"@
        Invoke-Fake (New-Definition -ExitCode 1 -Results @($script:Finding)) -Exceptions $exceptions | Should -Be 0
    }

    It 'fails on an unexcused finding even though the scanner exit code is expected' {
        Invoke-Fake (New-Definition -ExitCode 1 -Results @($script:Finding)) | Should -Not -Be 0
    }

    It 'fails when the scanner exits with a code it never uses for findings' {
        Invoke-Fake (New-Definition -ExitCode 2) 2>$null | Should -Be 1
    }

    It 'fails when the scanner writes no SARIF' {
        Invoke-Fake (New-Definition -NoSarif) 2>$null | Should -Be 1
    }
}
