#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../evals/Invoke-ContentModeration.ps1'
    $script:ModulePath = Join-Path $PSScriptRoot '../../evals/Modules/ModerationRunner.psm1'

    Import-Module $script:ModulePath -Force
}

Describe 'ModerationRunner module' -Tag 'Unit' {
    Context 'New-ModerationInputFile' {
        It 'Writes JSON-lines for each record' {
            $records = @(
                @{ id = 'rec-1'; text = 'hello' },
                @{ id = 'rec-2'; text = 'world' }
            )
            $path = New-ModerationInputFile -Records $records
            try {
                $lines = Get-Content -LiteralPath $path
                $lines.Count | Should -Be 2
                ($lines[0] | ConvertFrom-Json).id | Should -Be 'rec-1'
                ($lines[1] | ConvertFrom-Json).text | Should -Be 'world'
            }
            finally {
                Remove-Item -LiteralPath $path -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'ConvertTo-ModerationRecords' {
        It 'Reads files and emits records keyed by relative path' {
            $tmp = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'corpus')
            $f1 = Join-Path $tmp 'a.md'
            $f2 = Join-Path $tmp 'b.md'
            Set-Content -LiteralPath $f1 -Value 'alpha' -Encoding utf8 -NoNewline
            Set-Content -LiteralPath $f2 -Value 'bravo' -Encoding utf8 -NoNewline

            $records = ConvertTo-ModerationRecords -FileList @($f1, $f2) -RepoRoot $tmp
            $records.Count | Should -Be 2
            $records[0].text | Should -Be 'alpha'
            $records[1].text | Should -Be 'bravo'
        }

        It 'Skips missing files with a warning' {
            $records = ConvertTo-ModerationRecords -FileList @((Join-Path $TestDrive 'does-not-exist.md')) -RepoRoot $TestDrive -WarningAction SilentlyContinue
            $records.Count | Should -Be 0
        }
    }

    Context 'Test-ModerationOutput' {
        It 'Returns false when no records are flagged' {
            $outFile = Join-Path $TestDrive 'clean.json'
            @{
                records = @(
                    @{ id = 'a'; scores = @{ toxicity = 0.1 }; flagged = $false; flaggedLabels = @() }
                )
                summary = @{ total = 1; flaggedCount = 0 }
            } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $outFile -Encoding utf8

            Test-ModerationOutput -OutputPath $outFile | Should -BeFalse
        }

        It 'Returns true and emits annotations for flagged records' {
            $outFile = Join-Path $TestDrive 'flagged.json'
            @{
                records = @(
                    @{ id = 'docs/bad.md'; scores = @{ toxicity = 0.9 }; flagged = $true; flaggedLabels = @('toxicity') }
                )
                summary = @{ total = 1; flaggedCount = 1 }
            } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $outFile -Encoding utf8

            $output = & { Test-ModerationOutput -OutputPath $outFile -WarningAction SilentlyContinue } 6>&1
            $result = $output | Where-Object { $_ -is [bool] } | Select-Object -Last 1
            $result | Should -BeTrue
        }
    }
}

Describe 'Invoke-ContentModeration.ps1' -Tag 'Unit' {
    BeforeAll {
        $script:StubRoot = Join-Path $TestDrive 'pystub'
        New-Item -ItemType Directory -Path $script:StubRoot -Force | Out-Null
        $script:OrigPath = $env:PATH

        function New-PythonStub {
            param(
                [Parameter(Mandatory)][string]$OutputJson
            )
            $stubDir = Join-Path $TestDrive ("stub-" + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $stubDir -Force | Out-Null

            $stubScript = Join-Path $stubDir 'python.ps1'
            $jsonLiteral = $OutputJson.Replace("'", "''")
@"
param([Parameter(ValueFromRemainingArguments=`$true)]`$Args)
`$outIndex = [Array]::IndexOf(`$Args, '--output')
if (`$outIndex -lt 0) { exit 2 }
`$outPath = `$Args[`$outIndex + 1]
Set-Content -LiteralPath `$outPath -Value '$jsonLiteral' -Encoding utf8
`$json = '$jsonLiteral' | ConvertFrom-Json
if (`$json.summary.flaggedCount -gt 0) { exit 1 } else { exit 0 }
"@ | Set-Content -LiteralPath $stubScript -Encoding utf8

            $shim = Join-Path $stubDir 'python.cmd'
            "@pwsh -NoProfile -File `"$stubScript`" %*" | Set-Content -LiteralPath $shim -Encoding ascii
            return $stubDir
        }
    }

    AfterEach {
        $env:PATH = $script:OrigPath
    }

    It 'Errors when both -FileList and -Records are supplied' {
        $stubDir = New-PythonStub -OutputJson '{"records":[],"summary":{"total":0,"flaggedCount":0}}'
        $env:PATH = "$stubDir;$($script:OrigPath)"
        $tmpFile = Join-Path $TestDrive 'x.md'
        Set-Content -LiteralPath $tmpFile -Value 'hello' -Encoding utf8
        $outFile = Join-Path $TestDrive 'o.json'
        $cmd = "& '$($script:ScriptPath)' -FileList @('$tmpFile') -Records @(@{id='r';text='t'}) -Scope 'unit' -OutFile '$outFile' -RepoRoot '$TestDrive'; exit `$LASTEXITCODE"

        & pwsh -NoProfile -Command $cmd 2>$null
        $LASTEXITCODE | Should -Be 2
    }

    It 'Writes empty result and exits 0 when no records' {
        $stubDir = New-PythonStub -OutputJson '{"records":[],"summary":{"total":0,"flaggedCount":0}}'
        $env:PATH = "$stubDir;$($script:OrigPath)"
        $outFile = Join-Path $TestDrive 'empty.json'
        $cmd = "& '$($script:ScriptPath)' -Records @() -Scope 'unit' -OutFile '$outFile' -RepoRoot '$TestDrive'; exit `$LASTEXITCODE"

        & pwsh -NoProfile -Command $cmd 2>$null
        $LASTEXITCODE | Should -Be 0
        Test-Path $outFile | Should -BeTrue
        $data = Get-Content -LiteralPath $outFile -Raw | ConvertFrom-Json
        $data.summary.total | Should -Be 0
    }

    It 'Returns non-zero when stub reports flagged content' {
        $stubJson = '{"records":[{"id":"r1","scores":{"toxicity":0.9},"flagged":true,"flaggedLabels":["toxicity"]}],"summary":{"total":1,"flaggedCount":1}}'
        $stubDir = New-PythonStub -OutputJson $stubJson
        $env:PATH = "$stubDir;$($script:OrigPath)"
        $outFile = Join-Path $TestDrive 'flag.json'
        $cmd = "& '$($script:ScriptPath)' -Records @(@{id='r1';text='bad text'}) -Scope 'unit' -OutFile '$outFile' -RepoRoot '$TestDrive'; exit `$LASTEXITCODE"

        & pwsh -NoProfile -Command $cmd 2>$null
        $LASTEXITCODE | Should -Be 1
    }
}
