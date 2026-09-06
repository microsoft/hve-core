#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../evals/Test-EvalSpecText.ps1'
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path

    $script:NodeAvailable = $null -ne (Get-Command node -ErrorAction SilentlyContinue)
    if ($script:NodeAvailable) {
        $script:DependenciesInstalled = $true
        $pkgs = @('unified', 'retext-english', 'retext-equality', 'retext-profanities', 'retext-stringify', 'vfile-sort')
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

Describe 'Test-EvalSpecText.ps1 (retext-equality + retext-profanities)' -Tag 'Unit' {
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
        Set-ItResult -Skipped -Because 'node or required retext npm packages are not installed'
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

    It 'Treats alex-compatible findings as warnings by default and records them in the report' {
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
        @($report.results | Where-Object { $_.spec -like '*flag.md' }).Count | Should -BeGreaterOrEqual 1
    }

    It 'Exits 1 on alex-compatible findings when -FailOnAlex is supplied' {
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

    It 'Reports a profanity occurrence once as an error without an alex warning' {
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
        $entry = $report.results | Where-Object { $_.spec -like '*profane.md' }
        $exit | Should -Be 1
        $report.errorCount | Should -Be 1
        $report.warningCount | Should -Be 0
        $report.flagged | Should -Be 1
        $report.failOnAlex | Should -BeFalse
        @($entry.messages) | Should -HaveCount 1
        $entry.messages[0].source | Should -Be 'retext-profanities'
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

    It 'Reports equality warnings before profanity errors without mixing rule ownership' {
        if (-not ($script:NodeAvailable -and $script:DependenciesInstalled)) {
            Set-ItResult -Skipped -Because 'node or required npm packages are not available'
            return
        }

        $mixedFile = Join-Path $script:CorpusRoot 'docs/mixed.md'
        Set-Content -LiteralPath $mixedFile -Value "# Mixed`n`nThis is crazy and fucking wrong." -Encoding UTF8
        $globs = @((Join-Path $script:CorpusRoot 'docs/**/*.md'))

        & $script:ScriptPath -CorpusGlob $globs -RepoRoot $script:RepoRoot -OutputPath $script:OutputPath *> $null
        $exit = $LASTEXITCODE

        $report = Get-Content -LiteralPath $script:OutputPath -Raw | ConvertFrom-Json
        $entry = $report.results | Where-Object { $_.spec -like '*mixed.md' }
        $sources = @($entry.messages | ForEach-Object { $_.source })
        $equalityMessages = @($entry.messages | Where-Object { $_.source -eq 'alex' })
        $profanityMessages = @($entry.messages | Where-Object { $_.source -eq 'retext-profanities' })
        $lastAlexIndex = [array]::LastIndexOf($sources, 'alex')
        $firstProfanityIndex = [array]::IndexOf($sources, 'retext-profanities')

        $exit | Should -Be 1
        $report.warningCount | Should -Be 1
        $report.errorCount | Should -Be 1
        $report.failOnAlex | Should -BeFalse
        $equalityMessages | Should -HaveCount 1
        $profanityMessages | Should -HaveCount 1
        $equalityMessages[0].rule | Should -Not -Be $profanityMessages[0].rule
        $lastAlexIndex | Should -BeGreaterOrEqual 0
        $firstProfanityIndex | Should -BeGreaterOrEqual 0
        $lastAlexIndex | Should -BeLessThan $firstProfanityIndex
    }

    It 'Suppresses an allowlisted <Rule> phrase while its control keeps source <Source>' -ForEach @(
        @{
            Rule = 'host-hostess'
            AllowText = 'Use an HTTP host.'
            ControlText = 'The host was ready.'
            Source = 'alex'
            WarningCount = 1
            ErrorCount = 0
            ExitCode = 0
        }
        @{
            Rule = 'penetration'
            AllowText = 'Run a penetration test to verify security.'
            ControlText = 'The penetration level is high.'
            Source = 'retext-profanities'
            WarningCount = 0
            ErrorCount = 1
            ExitCode = 1
        }
    ) {
        if (-not ($script:NodeAvailable -and $script:DependenciesInstalled)) {
            Set-ItResult -Skipped -Because 'node or required npm packages are not available'
            return
        }

        $allowFile = Join-Path $script:CorpusRoot 'docs/allow.md'
        $controlFile = Join-Path $script:CorpusRoot 'docs/control.md'
        Set-Content -LiteralPath $allowFile -Value "# Allowlisted`n`n$AllowText" -Encoding UTF8
        Set-Content -LiteralPath $controlFile -Value "# Control`n`n$ControlText" -Encoding UTF8
        $globs = @((Join-Path $script:CorpusRoot 'docs/**/*.md'))

        & $script:ScriptPath -CorpusGlob $globs -RepoRoot $script:RepoRoot -OutputPath $script:OutputPath *> $null
        $exit = $LASTEXITCODE

        $report = Get-Content -LiteralPath $script:OutputPath -Raw | ConvertFrom-Json
        $allowEntry = $report.results | Where-Object { $_.spec -like '*allow.md' }
        $controlEntry = $report.results | Where-Object { $_.spec -like '*control.md' }
        $controlMessage = @(
            $controlEntry.messages |
                Where-Object { $_.rule -eq $Rule -and $_.source -eq $Source }
        )

        $allowEntry | Should -BeNullOrEmpty
        @($controlEntry.messages) | Should -HaveCount 1
        $controlMessage | Should -HaveCount 1
        $controlMessage[0].message | Should -Not -BeNullOrEmpty
        $controlMessage[0].line | Should -Be 3
        $controlMessage[0].column | Should -Be 5
        $report.warningCount | Should -Be $WarningCount
        $report.errorCount | Should -Be $ErrorCount
        $report.failOnAlex | Should -BeFalse
        $exit | Should -Be $ExitCode
    }

    It 'Treats a rating-zero profanity as an error while preserving its technical allowlist' {
        if (-not ($script:NodeAvailable -and $script:DependenciesInstalled)) {
            Set-ItResult -Skipped -Because 'node or required npm packages are not available'
            return
        }

        $allowFile = Join-Path $script:CorpusRoot 'docs/allow.md'
        $controlFile = Join-Path $script:CorpusRoot 'docs/control.md'
        Set-Content -LiteralPath $allowFile -Value "# Allowlisted`n`nMap the attack surface." -Encoding UTF8
        Set-Content -LiteralPath $controlFile -Value "# Control`n`nAn attack occurred." -Encoding UTF8
        $globs = @((Join-Path $script:CorpusRoot 'docs/**/*.md'))

        & $script:ScriptPath -CorpusGlob $globs -RepoRoot $script:RepoRoot -OutputPath $script:OutputPath *> $null
        $exit = $LASTEXITCODE

        $report = Get-Content -LiteralPath $script:OutputPath -Raw | ConvertFrom-Json
        $allowEntry = $report.results | Where-Object { $_.spec -like '*allow.md' }
        $controlEntry = $report.results | Where-Object { $_.spec -like '*control.md' }

        $allowEntry | Should -BeNullOrEmpty
        @($controlEntry.messages) | Should -HaveCount 1
        $controlEntry.messages[0].rule | Should -Be 'attack'
        $controlEntry.messages[0].source | Should -Be 'retext-profanities'
        $report.warningCount | Should -Be 0
        $report.errorCount | Should -Be 1
        $report.flagged | Should -Be 1
        $report.failOnAlex | Should -BeFalse
        $exit | Should -Be 1
    }
}
