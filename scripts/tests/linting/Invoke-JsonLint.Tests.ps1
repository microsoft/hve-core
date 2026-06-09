#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Pester tests for Invoke-JsonLint.ps1 script
.DESCRIPTION
    Tests for the strict JSON validator:
    - Strict parsing of valid and invalid JSON
    - Detection of trailing commas, comments, and trailing content
    - File discovery across target paths
    - CI integration
#>

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../linting/Invoke-JsonLint.ps1'
    $script:ModulePath = Join-Path $PSScriptRoot '../../linting/Modules/LintingHelpers.psm1'
    $script:CIHelpersPath = Join-Path $PSScriptRoot '../../lib/Modules/CIHelpers.psm1'

    Import-Module $script:ModulePath -Force
    Import-Module $script:CIHelpersPath -Force

    . $script:ScriptPath

    $script:TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("json-lint-tests-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $script:TestRoot | Out-Null
}

AfterAll {
    if ($script:TestRoot -and (Test-Path $script:TestRoot)) {
        Remove-Item -Path $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    Remove-Module LintingHelpers -Force -ErrorAction SilentlyContinue
    Remove-Module CIHelpers -Force -ErrorAction SilentlyContinue
}

#region Test-JsonFile Tests

Describe 'Test-JsonFile' -Tag 'Unit' {
    BeforeEach {
        $script:CaseDir = Join-Path $script:TestRoot ([System.Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Force -Path $script:CaseDir | Out-Null
    }

    It 'Returns null for valid JSON' {
        $file = Join-Path $script:CaseDir 'valid.json'
        '{ "name": "ok", "values": [1, 2, 3] }' | Set-Content -LiteralPath $file
        Test-JsonFile -Path $file | Should -BeNullOrEmpty
    }

    It 'Returns an issue for a trailing comma' {
        $file = Join-Path $script:CaseDir 'trailing-comma.json'
        '{ "name": "bad", }' | Set-Content -LiteralPath $file
        $result = Test-JsonFile -Path $file
        $result | Should -Not -BeNullOrEmpty
        $result.File | Should -Be $file
    }

    It 'Returns an issue for a JSON comment' {
        $file = Join-Path $script:CaseDir 'comment.json'
        @'
{
  // not allowed
  "name": "bad"
}
'@ | Set-Content -LiteralPath $file
        Test-JsonFile -Path $file | Should -Not -BeNullOrEmpty
    }

    It 'Returns an issue for trailing content after the root value' {
        $file = Join-Path $script:CaseDir 'concat.json'
        '{ "a": 1 }{ "b": 2 }' | Set-Content -LiteralPath $file
        Test-JsonFile -Path $file | Should -Not -BeNullOrEmpty
    }

    It 'Returns an issue for an empty file' {
        $file = Join-Path $script:CaseDir 'empty.json'
        '' | Set-Content -LiteralPath $file
        $result = Test-JsonFile -Path $file
        $result | Should -Not -BeNullOrEmpty
        $result.Message | Should -Match 'empty'
    }

    It 'Reports a positive line number for malformed JSON on a later line' {
        $file = Join-Path $script:CaseDir 'line.json'
        @'
{
  "a": 1,
  "b": 2,
}
'@ | Set-Content -LiteralPath $file
        $result = Test-JsonFile -Path $file
        $result.Line | Should -BeGreaterThan 0
    }
}

#endregion Test-JsonFile Tests

#region Invoke-JsonLintCore Tests

Describe 'Invoke-JsonLintCore' -Tag 'Unit' {
    BeforeEach {
        Mock Set-CIOutput {}
        Mock Set-CIEnv {}
        Mock Write-CIStepSummary {}
        Mock Write-CIAnnotation {}

        $script:CaseDir = Join-Path $script:TestRoot ([System.Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Force -Path $script:CaseDir | Out-Null
        $script:Output = Join-Path $script:CaseDir 'json-lint-results.json'
    }

    It 'Does not throw when all JSON files are valid' {
        '{ "ok": true }' | Set-Content -LiteralPath (Join-Path $script:CaseDir 'a.json')
        '[1, 2, 3]' | Set-Content -LiteralPath (Join-Path $script:CaseDir 'b.json')
        { Invoke-JsonLintCore -Paths @($script:CaseDir) -OutputPath $script:Output } | Should -Not -Throw
    }

    It 'Throws when a JSON file is malformed' {
        '{ "ok": true }' | Set-Content -LiteralPath (Join-Path $script:CaseDir 'good.json')
        '{ "bad": true, }' | Set-Content -LiteralPath (Join-Path $script:CaseDir 'bad.json')
        { Invoke-JsonLintCore -Paths @($script:CaseDir) -OutputPath $script:Output } | Should -Throw
    }

    It 'Does not throw when there are no JSON files to analyze' {
        { Invoke-JsonLintCore -Paths @($script:CaseDir) -OutputPath $script:Output } | Should -Not -Throw
    }

    It 'Skips missing target paths without throwing' {
        $missing = Join-Path $script:CaseDir 'does-not-exist'
        { Invoke-JsonLintCore -Paths @($missing) -OutputPath $script:Output } | Should -Not -Throw
    }

    It 'Accepts a single JSON file as a target path' {
        $file = Join-Path $script:CaseDir 'single.json'
        '{ "ok": true }' | Set-Content -LiteralPath $file
        { Invoke-JsonLintCore -Paths @($file) -OutputPath $script:Output } | Should -Not -Throw
    }

    It 'Filters changed files to only those under target Paths in ChangedFilesOnly mode' {
        Mock Get-ChangedFilesFromGit { @('scripts/linting/schemas/a.json', 'docs/x.json') }
        Mock Test-JsonFile { $null }
        Invoke-JsonLintCore -Paths @('scripts/linting/schemas') -ChangedFilesOnly -OutputPath $script:Output
        Assert-MockCalled Test-JsonFile -Times 1 -Exactly -ParameterFilter { $Path -eq 'scripts/linting/schemas/a.json' }
        Assert-MockCalled Test-JsonFile -Times 0 -Exactly -ParameterFilter { $Path -eq 'docs/x.json' }
    }

    It 'Creates the OutputPath parent directory when missing' {
        '{ "ok": true }' | Set-Content -LiteralPath (Join-Path $script:CaseDir 'a.json')
        $nested = Join-Path $script:CaseDir 'nested/sub/json-lint-results.json'
        { Invoke-JsonLintCore -Paths @($script:CaseDir) -OutputPath $nested } | Should -Not -Throw
        Test-Path (Split-Path $nested -Parent) | Should -BeTrue
    }

    It 'Emits a CI annotation with File and Error level for malformed JSON' {
        '{ "x": 1, }' | Set-Content -LiteralPath (Join-Path $script:CaseDir 'bad.json')
        { Invoke-JsonLintCore -Paths @($script:CaseDir) -OutputPath $script:Output } | Should -Throw
        Assert-MockCalled Write-CIAnnotation -ParameterFilter { $File -like '*bad.json' -and $Level -eq 'Error' }
    }
}

#endregion Invoke-JsonLintCore Tests

#region Repository JSON Tests

Describe 'Repository JSON validity' -Tag 'Integration' {
    It 'All schema and fixture JSON files parse strictly' {
        $repoRoot = Join-Path $PSScriptRoot '../../..'
        $targets = @('scripts/linting/schemas', 'scripts/tests/fixtures') | ForEach-Object {
            Join-Path $repoRoot $_
        }

        $failures = @()
        foreach ($target in $targets) {
            if (-not (Test-Path $target)) { continue }
            Get-ChildItem -Path $target -File -Recurse -Filter '*.json' | ForEach-Object {
                $issue = Test-JsonFile -Path $_.FullName
                if ($null -ne $issue) {
                    $failures += "$($issue.File): $($issue.Message)"
                }
            }
        }

        $failures | Should -BeNullOrEmpty
    }
}

#endregion Repository JSON Tests
