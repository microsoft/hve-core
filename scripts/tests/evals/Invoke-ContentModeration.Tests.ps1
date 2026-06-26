#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ScriptPath = (Resolve-Path (Join-Path $PSScriptRoot '../../evals/Invoke-ContentModeration.ps1')).Path
    $script:ModulePath = (Resolve-Path (Join-Path $PSScriptRoot '../../evals/Modules/ModerationRunner.psm1')).Path
    Import-Module $script:ModulePath -Force

    # Runs the script in a child pwsh process so that explicit `exit N` calls
    # set the process exit code. The call operator does not propagate a script
    # file's exit code, so the child relays $LASTEXITCODE explicitly. Returns the
    # child exit code. All output streams are suppressed to keep test output clean.
    function Invoke-Script {
        param([string]$Arguments)
        $command = "& '$script:ScriptPath' $Arguments; exit `$LASTEXITCODE"
        pwsh -NoProfile -NonInteractive -Command $command *> $null
        return $LASTEXITCODE
    }

    # Runs the script in a child pwsh process with a fake `python` function that
    # shadows the external interpreter. The fake function writes a canned
    # moderate.py output file (unless -SkipOutput) and sets the simulated process
    # exit code via $global:LASTEXITCODE. This exercises the python-in-PATH happy
    # path and the non-zero moderate.py exit handling without invoking torch.
    function Invoke-ScriptWithFakePython {
        param(
            [string]$Arguments,
            [int]$FlaggedCount = 0,
            [int]$PythonExitCode = 0,
            [switch]$SkipOutput
        )

        $recordItem = if ($FlaggedCount -gt 0) {
            "@{ id = 'rec1'; flagged = `$true; flaggedLabels = @('toxicity') }"
        }
        else {
            ''
        }

        if ($SkipOutput) {
            $writeBlock = ''
        }
        else {
            $writeBlock = @"
        `$outPath = `$null
        for (`$i = 0; `$i -lt `$args.Count; `$i++) {
            if (`$args[`$i] -eq '--output') { `$outPath = `$args[`$i + 1] }
        }
        @{ records = @($recordItem); summary = @{ total = 1; flaggedCount = $FlaggedCount } } |
            ConvertTo-Json -Depth 10 | Set-Content -Path `$outPath -Encoding utf8NoBOM
"@
        }

        $fakePython = @"
function python {
$writeBlock
    `$global:LASTEXITCODE = $PythonExitCode
}
"@

        $command = "$fakePython`n`$env:HVE_MODERATION_PYTHON = 'python'`n& '$script:ScriptPath' $Arguments; exit `$LASTEXITCODE"
        pwsh -NoProfile -NonInteractive -Command $command *> $null
        return $LASTEXITCODE
    }
}

Describe 'Invoke-ContentModeration exit codes' -Tag 'Unit' {
    Context 'when -FileList and -Records are both provided' {
        It 'Exits with code 2' {
            $code = Invoke-Script "-Scope 'test' -FileList 'a.md' -Records @(@{ id = 'x'; text = 'y' })"
            $code | Should -Be 2
        }
    }

    Context 'when neither -FileList nor -Records is provided' {
        It 'Exits with code 2' {
            $code = Invoke-Script "-Scope 'test'"
            $code | Should -Be 2
        }
    }

    Context 'when -Records is an empty array' {
        BeforeAll {
            $script:OutFile = Join-Path $TestDrive 'moderation-empty.json'
            $script:Code = Invoke-Script "-Scope 'empty' -Records @() -OutFile '$script:OutFile'"
        }

        It 'Exits with code 0' {
            $script:Code | Should -Be 0
        }

        It 'Writes an empty output file' {
            Test-Path $script:OutFile | Should -BeTrue
        }

        It 'Reports zero total records in the output' {
            $output = Get-Content -Path $script:OutFile -Raw | ConvertFrom-Json
            $output.summary.total | Should -Be 0
            $output.summary.flaggedCount | Should -Be 0
        }
    }
}

Describe 'Invoke-ContentModeration moderate.py invocation' -Tag 'Unit' {
    Context 'when python is available and content passes' {
        BeforeAll {
            $script:OutFile = Join-Path $TestDrive 'moderation-pass.json'
            $script:Code = Invoke-ScriptWithFakePython -Arguments "-Scope 'pass' -Records @(@{ id = 'x'; text = 'hello' }) -OutFile '$script:OutFile' -RepoRoot '$TestDrive'" -FlaggedCount 0 -PythonExitCode 0
        }

        It 'Exits with code 0' {
            $script:Code | Should -Be 0
        }
    }

    Context 'when python is available and content is flagged' {
        BeforeAll {
            $script:OutFile = Join-Path $TestDrive 'moderation-flagged.json'
            $script:Code = Invoke-ScriptWithFakePython -Arguments "-Scope 'flag' -Records @(@{ id = 'x'; text = 'bad' }) -OutFile '$script:OutFile' -RepoRoot '$TestDrive'" -FlaggedCount 1 -PythonExitCode 0
        }

        It 'Exits with code 1' {
            $script:Code | Should -Be 1
        }
    }

    Context 'when moderate.py exits non-zero but output shows flagged content' {
        BeforeAll {
            $script:OutFile = Join-Path $TestDrive 'moderation-err-flagged.json'
            $script:Code = Invoke-ScriptWithFakePython -Arguments "-Scope 'errflag' -Records @(@{ id = 'x'; text = 'bad' }) -OutFile '$script:OutFile' -RepoRoot '$TestDrive'" -FlaggedCount 1 -PythonExitCode 2
        }

        It 'Exits with code 1' {
            $script:Code | Should -Be 1
        }
    }

    Context 'when moderate.py exits non-zero with clean output' {
        BeforeAll {
            $script:OutFile = Join-Path $TestDrive 'moderation-err-clean.json'
            $script:Code = Invoke-ScriptWithFakePython -Arguments "-Scope 'errclean' -Records @(@{ id = 'x'; text = 'ok' }) -OutFile '$script:OutFile' -RepoRoot '$TestDrive'" -FlaggedCount 0 -PythonExitCode 2
        }

        It 'Propagates the moderate.py exit code' {
            $script:Code | Should -Be 2
        }
    }

    Context 'when moderate.py exits non-zero and writes no output' {
        BeforeAll {
            $script:OutFile = Join-Path $TestDrive 'moderation-err-missing.json'
            $script:Code = Invoke-ScriptWithFakePython -Arguments "-Scope 'errmissing' -Records @(@{ id = 'x'; text = 'ok' }) -OutFile '$script:OutFile' -RepoRoot '$TestDrive'" -PythonExitCode 2 -SkipOutput
        }

        It 'Propagates the moderate.py exit code' {
            $script:Code | Should -Be 2
        }
    }
}

Describe 'New-ModerationInputFile' -Tag 'Unit' {
    Context 'when given records' {
        BeforeAll {
            $script:Records = @(
                @{ id = 'rec1'; text = 'Hello world' }
                @{ id = 'rec2'; text = 'Test content' }
            )
            $script:InputFile = Join-Path $TestDrive 'input.jsonl'
            $script:Result = New-ModerationInputFile -Records $script:Records -OutFile $script:InputFile
        }

        It 'Returns the output file path' {
            $script:Result | Should -Be $script:InputFile
        }

        It 'Writes one JSON line per record' {
            $lines = Get-Content -Path $script:InputFile
            $lines | Should -HaveCount 2
        }

        It 'Writes valid JSON with id and text on each line' {
            $lines = Get-Content -Path $script:InputFile
            foreach ($line in $lines) {
                $record = $line | ConvertFrom-Json
                $record.id | Should -Not -BeNullOrEmpty
                $record.text | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'when no output file is specified' {
        It 'Creates a temp file and returns its path' {
            $records = @(@{ id = 'rec1'; text = 'content' })
            $path = New-ModerationInputFile -Records $records
            try {
                Test-Path $path | Should -BeTrue
            }
            finally {
                Remove-Item $path -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

Describe 'ConvertTo-ModerationRecords' -Tag 'Unit' {
    Context 'when given existing files' {
        BeforeAll {
            $script:FileA = Join-Path $TestDrive 'file-a.md'
            $script:FileB = Join-Path $TestDrive 'file-b.md'
            Set-Content -Path $script:FileA -Value 'Content A' -Encoding utf8NoBOM
            Set-Content -Path $script:FileB -Value 'Content B' -Encoding utf8NoBOM
            $script:Records = ConvertTo-ModerationRecords -FileList @($script:FileA, $script:FileB) -RepoRoot $TestDrive
        }

        It 'Returns one record per file' {
            $script:Records | Should -HaveCount 2
        }

        It 'Populates the text from file content' {
            $script:Records[0].text | Should -Match 'Content A'
            $script:Records[1].text | Should -Match 'Content B'
        }

        It 'Populates a relative id for each record' {
            $script:Records | ForEach-Object {
                $_.id | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'when a file does not exist' {
        It 'Skips the missing file and warns' {
            Mock Write-Warning {} -ModuleName ModerationRunner
            $missing = Join-Path $TestDrive 'does-not-exist.md'
            $records = ConvertTo-ModerationRecords -FileList @($missing) -RepoRoot $TestDrive
            $records | Should -HaveCount 0
            Should -Invoke Write-Warning -ModuleName ModerationRunner -Times 1 -Exactly
        }
    }

    Context 'when a file contains unicode content' {
        It 'Preserves unicode characters in the record text' {
            $unicodeFile = Join-Path $TestDrive 'unicode.md'
            Set-Content -Path $unicodeFile -Value 'Café ☕ 日本語 Ñoño — emoji 🎉' -Encoding utf8NoBOM
            $records = @(ConvertTo-ModerationRecords -FileList @($unicodeFile) -RepoRoot $TestDrive)
            $records | Should -HaveCount 1
            $records[0].text | Should -Match 'Café'
            $records[0].text | Should -Match '日本語'
            $records[0].text | Should -Match '🎉'
        }
    }

    Context 'when a file is large' {
        It 'Returns a single record containing the full content' {
            $largeFile = Join-Path $TestDrive 'large.md'
            $content = ('The quick brown fox jumps over the lazy dog. ' * 5000)
            Set-Content -Path $largeFile -Value $content -Encoding utf8NoBOM
            $records = @(ConvertTo-ModerationRecords -FileList @($largeFile) -RepoRoot $TestDrive)
            $records | Should -HaveCount 1
            $records[0].text.Length | Should -BeGreaterThan 100000
        }
    }

    Context 'when a file contains only whitespace' {
        It 'Returns a record without warning' {
            Mock Write-Warning {} -ModuleName ModerationRunner
            $wsFile = Join-Path $TestDrive 'whitespace.md'
            Set-Content -Path $wsFile -Value "   `n`t  `n" -Encoding utf8NoBOM
            $records = ConvertTo-ModerationRecords -FileList @($wsFile) -RepoRoot $TestDrive
            $records | Should -HaveCount 1
            Should -Invoke Write-Warning -ModuleName ModerationRunner -Times 0 -Exactly
        }
    }

    Context 'when a file is empty' {
        It 'Returns a record without warning' {
            Mock Write-Warning {} -ModuleName ModerationRunner
            $emptyFile = Join-Path $TestDrive 'empty.md'
            [System.IO.File]::WriteAllText($emptyFile, '')
            $records = ConvertTo-ModerationRecords -FileList @($emptyFile) -RepoRoot $TestDrive
            $records | Should -HaveCount 1
            Should -Invoke Write-Warning -ModuleName ModerationRunner -Times 0 -Exactly
        }
    }
}

Describe 'Test-ModerationOutput' -Tag 'Unit' {
    BeforeAll {
        Mock Write-Host {} -ModuleName ModerationRunner
        Mock Write-Warning {} -ModuleName ModerationRunner
        Mock Write-Error {} -ModuleName ModerationRunner
    }

    Context 'when no records are flagged' {
        It 'Returns false' {
            $outputPath = Join-Path $TestDrive 'clean.json'
            @{ records = @(); summary = @{ total = 3; flaggedCount = 0 } } |
                ConvertTo-Json -Depth 10 | Set-Content -Path $outputPath -Encoding utf8NoBOM
            Test-ModerationOutput -OutputPath $outputPath | Should -BeFalse
        }
    }

    Context 'when records are flagged' {
        It 'Returns true' {
            $outputPath = Join-Path $TestDrive 'flagged.json'
            @{
                records = @(
                    @{ id = 'rec1'; flagged = $true; flaggedLabels = @('toxicity') }
                )
                summary = @{ total = 1; flaggedCount = 1 }
            } | ConvertTo-Json -Depth 10 | Set-Content -Path $outputPath -Encoding utf8NoBOM
            Test-ModerationOutput -OutputPath $outputPath | Should -BeTrue
        }
    }

    Context 'when the output file is missing' {
        It 'Returns true' {
            $missing = Join-Path $TestDrive 'missing-output.json'
            Test-ModerationOutput -OutputPath $missing | Should -BeTrue
        }
    }
}

AfterAll {
    Remove-Module ModerationRunner -Force -ErrorAction SilentlyContinue
}
