#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../evals/Test-EvalSpecText.ps1'
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path

    $script:NodeAvailable = $null -ne (Get-Command node -ErrorAction SilentlyContinue)
    if ($script:NodeAvailable) {
        $script:DependenciesInstalled = $true
        $pkgs = @('alex', 'unified', 'retext-english', 'retext-profanities', 'retext-stringify')
        foreach ($p in $pkgs) {
            & node -e "try{require.resolve('$p');process.exit(0)}catch(e){process.exit(1)}" 2>$null | Out-Null
            if ($LASTEXITCODE -ne 0) {
                $script:DependenciesInstalled = $false
                break
            }
        }
    }
    else {
        $script:DependenciesInstalled = $false
    }
}

Describe 'Test-EvalSpecText.ps1 (alex + retext-profanities)' -Tag 'Unit' {
    BeforeEach {
        $script:OutputPath = Join-Path $TestDrive "eval-spec-text-$([Guid]::NewGuid()).json"
        $script:CorpusRoot = Join-Path $TestDrive "corpus-$([Guid]::NewGuid())"
        New-Item -ItemType Directory -Path (Join-Path $script:CorpusRoot '.github/instructions') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:CorpusRoot '.github/agents') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:CorpusRoot 'docs') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:CorpusRoot 'evals') -Force | Out-Null
    }

    It 'Skips when node or required packages are unavailable' {
        if ($script:NodeAvailable -and $script:DependenciesInstalled) {
            Set-ItResult -Skipped -Because 'Dependencies are installed; this guard test is informational only'
            return
        }
        Set-ItResult -Skipped -Because 'node or required npm packages (alex, retext-*) are not installed'
    }

    It 'Discovers markdown under .github/<kind>/ and docs/ when scoped to a corpus root' {
        if (-not ($script:NodeAvailable -and $script:DependenciesInstalled)) {
            Set-ItResult -Skipped -Because 'node or required npm packages are not available'
            return
        }

        Set-Content -LiteralPath (Join-Path $script:CorpusRoot '.github/instructions/clean.md') -Value "# Clean instructions`n`nThis paragraph is fine." -Encoding UTF8
        Set-Content -LiteralPath (Join-Path $script:CorpusRoot '.github/agents/clean.md') -Value "# Clean agent`n`nNothing flagged here." -Encoding UTF8
        Set-Content -LiteralPath (Join-Path $script:CorpusRoot 'docs/clean.md') -Value "# Clean docs`n`nAll good." -Encoding UTF8

        $globs = @(
            (Join-Path $script:CorpusRoot '.github/instructions/**/*.md'),
            (Join-Path $script:CorpusRoot '.github/agents/**/*.md'),
            (Join-Path $script:CorpusRoot 'docs/**/*.md')
        )

        & $script:ScriptPath -CorpusGlob $globs -RepoRoot $script:RepoRoot -OutputPath $script:OutputPath *> $null
        $exit = $LASTEXITCODE

        Test-Path -LiteralPath $script:OutputPath | Should -BeTrue
        $report = Get-Content -LiteralPath $script:OutputPath -Raw | ConvertFrom-Json
        $exit | Should -Be 0
        $report.scanned | Should -Be 3
        $report.flagged | Should -Be 0
    }

    It 'Treats alex.js findings as warnings by default (exit 0) and still records them in the report' {
        if (-not ($script:NodeAvailable -and $script:DependenciesInstalled)) {
            Set-ItResult -Skipped -Because 'node or required npm packages are not available'
            return
        }

        $flagFile = Join-Path $script:CorpusRoot '.github/instructions/flag.md'
        Set-Content -LiteralPath $flagFile -Value "# Flagged instructions`n`nThis is crazy behavior to avoid." -Encoding UTF8

        $globs = @((Join-Path $script:CorpusRoot '.github/instructions/**/*.md'))

        & $script:ScriptPath -CorpusGlob $globs -RepoRoot $script:RepoRoot -OutputPath $script:OutputPath *> $null
        $exit = $LASTEXITCODE

        Test-Path -LiteralPath $script:OutputPath | Should -BeTrue
        $report = Get-Content -LiteralPath $script:OutputPath -Raw | ConvertFrom-Json
        $exit | Should -Be 0
        $report.flagged | Should -BeGreaterOrEqual 1
        $report.warningCount | Should -BeGreaterOrEqual 1
        $report.errorCount | Should -Be 0
        $report.failOnAlex | Should -BeFalse
        ($report.results | Where-Object { $_.spec -like '*flag.md' }).Count | Should -BeGreaterOrEqual 1
    }

    It 'Exits 1 on alex.js findings when -FailOnAlex is supplied' {
        if (-not ($script:NodeAvailable -and $script:DependenciesInstalled)) {
            Set-ItResult -Skipped -Because 'node or required npm packages are not available'
            return
        }

        $flagFile = Join-Path $script:CorpusRoot '.github/instructions/flag.md'
        Set-Content -LiteralPath $flagFile -Value "# Flagged instructions`n`nThis is crazy behavior to avoid." -Encoding UTF8

        $globs = @((Join-Path $script:CorpusRoot '.github/instructions/**/*.md'))

        & $script:ScriptPath -CorpusGlob $globs -RepoRoot $script:RepoRoot -OutputPath $script:OutputPath -FailOnAlex *> $null
        $exit = $LASTEXITCODE

        $report = Get-Content -LiteralPath $script:OutputPath -Raw | ConvertFrom-Json
        $exit | Should -Be 1
        $report.errorCount | Should -BeGreaterOrEqual 1
        $report.failOnAlex | Should -BeTrue
    }

    It 'Flags profanity via retext-profanities' {
        if (-not ($script:NodeAvailable -and $script:DependenciesInstalled)) {
            Set-ItResult -Skipped -Because 'node or required npm packages are not available'
            return
        }

        $flagFile = Join-Path $script:CorpusRoot 'docs/profane.md'
        Set-Content -LiteralPath $flagFile -Value "# Profane doc`n`nThis is fucking unacceptable." -Encoding UTF8

        $globs = @((Join-Path $script:CorpusRoot 'docs/**/*.md'))

        & $script:ScriptPath -CorpusGlob $globs -RepoRoot $script:RepoRoot -OutputPath $script:OutputPath *> $null
        $exit = $LASTEXITCODE

        $report = Get-Content -LiteralPath $script:OutputPath -Raw | ConvertFrom-Json
        $exit | Should -Be 1
        $report.errorCount | Should -BeGreaterOrEqual 1
        ($report.results | Where-Object { $_.spec -like '*profane.md' }).Count | Should -BeGreaterOrEqual 1
    }

    It 'Does not include evals/ markdown when scanning the default corpus' {
        if (-not ($script:NodeAvailable -and $script:DependenciesInstalled)) {
            Set-ItResult -Skipped -Because 'node or required npm packages are not available'
            return
        }

        # A file placed under evals/ with flag-worthy content must be ignored when the
        # corpus globs target only .github/** and docs/**.
        Set-Content -LiteralPath (Join-Path $script:CorpusRoot 'evals/should-be-skipped.md') -Value "# Skipped`n`nThis is crazy and should not be scanned." -Encoding UTF8

        $globs = @(
            (Join-Path $script:CorpusRoot '.github/instructions/**/*.md'),
            (Join-Path $script:CorpusRoot '.github/agents/**/*.md'),
            (Join-Path $script:CorpusRoot 'docs/**/*.md')
        )

        & $script:ScriptPath -CorpusGlob $globs -RepoRoot $script:RepoRoot -OutputPath $script:OutputPath *> $null
        $exit = $LASTEXITCODE

        $report = Get-Content -LiteralPath $script:OutputPath -Raw | ConvertFrom-Json
        $exit | Should -Be 0
        $report.scanned | Should -Be 0
        $report.flagged | Should -Be 0
    }

    It 'Uses the documented default corpus globs targeting .github/{agents,prompts,instructions,skills} and docs' {
        # ParameterAttribute does not expose default values; parse the AST instead.
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:ScriptPath, [ref]$null, [ref]$null)
        $param = $ast.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'CorpusGlob' }
        $param | Should -Not -BeNullOrEmpty

        $defaultText = $param.DefaultValue.Extent.Text
        $defaultText | Should -Match "\.github/agents/\*\*/\*\.md"
        $defaultText | Should -Match "\.github/prompts/\*\*/\*\.md"
        $defaultText | Should -Match "\.github/instructions/\*\*/\*\.md"
        $defaultText | Should -Match "\.github/skills/\*\*/\*\.md"
        $defaultText | Should -Match "docs/\*\*/\*\.md"
        $defaultText | Should -Not -Match "(^|['""])evals(['""/])"
    }
}
