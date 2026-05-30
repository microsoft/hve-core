#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ScriptPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../linting/Validate-AdrConsistency.ps1')).Path
    $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
    $script:FixtureRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot 'fixtures/adr-consistency')).Path

    # Dot-source the script. The script's tail guard (InvocationName -ne '.') skips
    # orchestration so we get its helper functions in the current scope.
    . $script:ScriptPath

    Mock Write-Host {}
    Mock Write-CIAnnotation {}
    Mock Write-CIStepSummary {}
}

AfterAll {
    Remove-Module AdrConsistency -Force -ErrorAction SilentlyContinue
    Remove-Module AdrBodyParser -Force -ErrorAction SilentlyContinue
    Remove-Module LintingHelpers -Force -ErrorAction SilentlyContinue
    Remove-Module CIHelpers -Force -ErrorAction SilentlyContinue
}

Describe 'Get-AdrRepoRoot' -Tag 'Unit' {
    It 'returns an absolute path that exists' {
        $root = Get-AdrRepoRoot
        $root | Should -Not -BeNullOrEmpty
        [System.IO.Path]::IsPathRooted($root) | Should -BeTrue
        Test-Path -LiteralPath $root | Should -BeTrue
    }
}

Describe 'Resolve-AdrFiles' -Tag 'Unit' {
    It 'resolves explicit -Files relative to repo root' {
        $relFile = 'scripts/tests/linting/fixtures/adr-consistency/affected-components-mirror/pass.md'
        $result = Resolve-AdrFiles -Files @($relFile) -ExcludePaths @() -RepoRoot $script:RepoRoot -BaseBranch 'origin/main'
        $result | Should -HaveCount 1
        $result[0] | Should -Match 'affected-components-mirror'
    }

    It 'expands directories via -Paths recursively' {
        $result = Resolve-AdrFiles -Paths @($script:FixtureRoot) -ExcludePaths @() -RepoRoot $script:RepoRoot -BaseBranch 'origin/main'
        ($result.Count) | Should -BeGreaterThan 1
        ($result | Where-Object { $_ -like '*pass.md' }).Count | Should -BeGreaterThan 0
    }

    It 'applies -ExcludePaths wildcard filter' {
        $all = Resolve-AdrFiles -Paths @($script:FixtureRoot) -ExcludePaths @() -RepoRoot $script:RepoRoot -BaseBranch 'origin/main'
        $filtered = Resolve-AdrFiles -Paths @($script:FixtureRoot) `
            -ExcludePaths @('scripts/tests/linting/fixtures/adr-consistency/*/fail.md') `
            -RepoRoot $script:RepoRoot -BaseBranch 'origin/main'
        $filtered.Count | Should -BeLessThan $all.Count
        ($filtered | Where-Object { $_ -like '*fail.md' }).Count | Should -Be 0
    }

    It 'rejects files outside the repository root with a warning' {
        $outside = if ($IsWindows) { 'C:\Windows\System32\drivers\etc\hosts' } else { '/etc/hostname' }
        $warnings = @()
        $result = Resolve-AdrFiles -Files @($outside) -ExcludePaths @() -RepoRoot $script:RepoRoot -BaseBranch 'origin/main' -WarningVariable warnings -WarningAction SilentlyContinue
        $result | Should -BeNullOrEmpty
        $warnings.Count | Should -BeGreaterThan 0
    }

    It 'limits changed files to supplied paths' {
        Mock Get-ChangedFilesFromGit {
            @(
                'scripts/tests/linting/fixtures/adr-consistency/affected-components-mirror/pass.md',
                'README.md'
            )
        }

        $result = Resolve-AdrFiles -Paths @('scripts/tests/linting/fixtures/adr-consistency') `
            -ExcludePaths @() -ChangedFilesOnly -RepoRoot $script:RepoRoot -BaseBranch 'origin/main'

        $result | Should -HaveCount 1
        $result[0] | Should -Match 'affected-components-mirror'
    }
}

Describe 'Invoke-AdrConsistencyValidator' -Tag 'Unit' {
    BeforeEach {
        $script:OutPath = Join-Path ([System.IO.Path]::GetTempPath()) ("adr-consistency-{0}.json" -f [Guid]::NewGuid())
        $script:SarifPath = Join-Path ([System.IO.Path]::GetTempPath()) ("adr-consistency-{0}.sarif" -f [Guid]::NewGuid())
        $script:ProcessOutputPath = Join-Path ([System.IO.Path]::GetTempPath()) ("adr-consistency-{0}.log" -f [Guid]::NewGuid())
    }

    AfterEach {
        if (Test-Path -LiteralPath $script:OutPath) { Remove-Item -LiteralPath $script:OutPath -Force }
        if (Test-Path -LiteralPath $script:SarifPath) { Remove-Item -LiteralPath $script:SarifPath -Force }
        if (Test-Path -LiteralPath $script:ProcessOutputPath) { Remove-Item -LiteralPath $script:ProcessOutputPath -Force }
    }

    It 'returns ExitCode 0 and writes JSON report when all fixtures pass' {
        $passFiles = Get-ChildItem -LiteralPath $script:FixtureRoot -Recurse -Filter 'pass.md' -File |
            ForEach-Object { $_.FullName.Substring($script:RepoRoot.Length).TrimStart('\', '/').Replace('\', '/') }

        $report = Invoke-AdrConsistencyValidator -Paths @() -Files $passFiles -ExcludePaths @() `
            -ChangedFilesOnly:$false -BaseBranch 'origin/main' -OutputPath $script:OutPath -WarningsAsErrors:$false

        $report.ExitCode | Should -Be 0
        $report.summary.errorCount | Should -Be 0
        Test-Path -LiteralPath $script:OutPath | Should -BeTrue
        $json = Get-Content -LiteralPath $script:OutPath -Raw | ConvertFrom-Json
        $json.summary.totalFiles | Should -Be $passFiles.Count
    }

    It 'returns ExitCode 1 when error-severity violations are present' {
        $failFile = 'scripts/tests/linting/fixtures/adr-consistency/success-criteria-source-resolves/fail.md'
        $report = Invoke-AdrConsistencyValidator -Paths @() -Files @($failFile) -ExcludePaths @() `
            -ChangedFilesOnly:$false -BaseBranch 'origin/main' -OutputPath $script:OutPath -WarningsAsErrors:$false

        $report.summary.errorCount | Should -BeGreaterThan 0
        $report.ExitCode | Should -Be 1
        ($report.violations | Where-Object { $_.ruleId -eq 'ADR-CONSISTENCY-002' }).Count | Should -BeGreaterThan 0
    }

    It 'writes SARIF report when SARIF output path is provided' {
        $failFile = 'scripts/tests/linting/fixtures/adr-consistency/success-criteria-source-resolves/fail.md'
        $report = Invoke-AdrConsistencyValidator -Paths @() -Files @($failFile) -ExcludePaths @() `
            -ChangedFilesOnly:$false -BaseBranch 'origin/main' -OutputPath $script:OutPath `
            -SarifOutputPath $script:SarifPath -WarningsAsErrors:$false

        $report.ExitCode | Should -Be 1
        Test-Path -LiteralPath $script:SarifPath | Should -BeTrue
        $sarif = Get-Content -LiteralPath $script:SarifPath -Raw | ConvertFrom-Json
        $sarif.version | Should -Be '2.1.0'
        $sarif.'$schema' | Should -Be 'https://json.schemastore.org/sarif-2.1.0.json'
        $sarif.runs[0].tool.driver.name | Should -Be 'ADR Consistency Validator'
        ($sarif.runs[0].results | Where-Object { $_.ruleId -eq 'ADR-CONSISTENCY-002' }).Count | Should -BeGreaterThan 0
        $sarif.runs[0].results[0].locations[0].physicalLocation.artifactLocation.uri | Should -Not -BeNullOrEmpty
        $sarif.runs[0].results[0].locations[0].physicalLocation.region.startLine | Should -BeGreaterThan 0
    }

    It 'supports CLI invocation with JSON and SARIF outputs' {
        $failFile = 'scripts/tests/linting/fixtures/adr-consistency/success-criteria-source-resolves/fail.md'
        $pwsh = (Get-Command pwsh).Source

        & $pwsh -NoProfile -File $script:ScriptPath -Files $failFile `
            -OutputPath $script:OutPath -SarifOutputPath $script:SarifPath *> $script:ProcessOutputPath

        $LASTEXITCODE | Should -Be 1
        Test-Path -LiteralPath $script:OutPath | Should -BeTrue
        Test-Path -LiteralPath $script:SarifPath | Should -BeTrue
        $json = Get-Content -LiteralPath $script:OutPath -Raw | ConvertFrom-Json
        $sarif = Get-Content -LiteralPath $script:SarifPath -Raw | ConvertFrom-Json
        ($json.violations | Where-Object { $_.ruleId -eq 'ADR-CONSISTENCY-002' }).Count | Should -BeGreaterThan 0
        ($sarif.runs[0].results | Where-Object { $_.ruleId -eq 'ADR-CONSISTENCY-002' }).Count | Should -BeGreaterThan 0
    }
}
