# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

Describe "Invoke-PipInstallLint.ps1" {
    BeforeAll {
        $scriptPath = "$PSScriptRoot/../../linting/Invoke-PipInstallLint.ps1"
        . $scriptPath
        $testDir = "$PSScriptRoot/TestLintDir"
        if (Test-Path $testDir) { Remove-Item -Recurse -Force $testDir }
        New-Item -ItemType Directory -Path $testDir | Out-Null
    }

    AfterAll {
        if (Test-Path $testDir) { Remove-Item -Recurse -Force $testDir }
    }

    AfterEach {
        if (Test-Path $testDir) { Remove-Item -Recurse -Force $testDir }
        New-Item -ItemType Directory -Path $testDir | Out-Null
    }

    It "Should pass on clean state" {
        $testFile = Join-Path $testDir "clean.py"
        Set-Content -Path $testFile -Value "print('hello world')"

        $result = script:Invoke-Lint -TargetDir $testDir
        $result | Should -Be $true
        $script:Violations.Count | Should -Be 0
    }

    It "Should detect bare pip install violation" {
        $testFile = Join-Path $testDir "violation.yml"
        Set-Content -Path $testFile -Value "run: pip install malicious-package"

        # Invoke-Lint calls Write-Error on violations, which throws under $ErrorActionPreference=Stop
        { script:Invoke-Lint -TargetDir $testDir } | Should -Throw -ExpectedMessage "*bare 'pip install'*"
        $script:Violations.Count | Should -BeGreaterThan 0
        $script:Violations[0] | Should -Match "malicious-package"
    }

    It "Should respect exclusion logic (evals directory)" {
        $evalsDir = Join-Path $testDir "evals"
        New-Item -ItemType Directory -Path $evalsDir | Out-Null
        $testFile = Join-Path $evalsDir "fake_eval_test.py"
        Set-Content -Path $testFile -Value "run: pip install mock-package"

        $result = script:Invoke-Lint -TargetDir $testDir
        $result | Should -Be $true
        $script:Violations.Count | Should -Be 0
    }

    It "Should allow uv pip install" {
        $testFile = Join-Path $testDir "uv_allowed.py"
        Set-Content -Path $testFile -Value "run: uv pip install fastapi"

        $result = script:Invoke-Lint -TargetDir $testDir
        $result | Should -Be $true
        $script:Violations.Count | Should -Be 0
    }

    It "Should respect inline ignore marker for Python/YAML" {
        $testFile = Join-Path $testDir "ignored.py"
        Set-Content -Path $testFile -Value "run: pip install legacy-package # pip-install-ok"

        $result = script:Invoke-Lint -TargetDir $testDir
        $result | Should -Be $true
        $script:Violations.Count | Should -Be 0
    }

    It "Should respect inline ignore marker for Markdown" {
        $testFile = Join-Path $testDir "ignored.md"
        Set-Content -Path $testFile -Value "run: pip install legacy-package <!-- pip-install-ok -->"

        $result = script:Invoke-Lint -TargetDir $testDir
        $result | Should -Be $true
        $script:Violations.Count | Should -Be 0
    }

    It "Should scan correctly when TestDirectory uses default value" {
        $testFile = Join-Path $testDir "default_param_test.py"
        Set-Content -Path $testFile -Value "run: pip install default-violation"

        Push-Location $testDir
        try {
            { script:Invoke-Lint } | Should -Throw -ExpectedMessage "*bare 'pip install'*"
            $script:Violations.Count | Should -BeGreaterThan 0
            $script:Violations[0] | Should -Match "default-violation"
        } finally {
            Pop-Location
        }
    }

    It "Should NOT exclude files with similar names (regex escape regression)" {
        $testFile = Join-Path $testDir "Invoke-PipInstallLintXps1.py"
        Set-Content -Path $testFile -Value "run: pip install wildcard-false-negative"

        { script:Invoke-Lint -TargetDir $testDir } | Should -Throw -ExpectedMessage "*bare 'pip install'*"
        $script:Violations.Count | Should -BeGreaterThan 0
        $script:Violations[0] | Should -Match "wildcard-false-negative"
    }

    It "Should still exclude exact filename match after regex escaping" {
        $testFile = Join-Path $testDir "Invoke-PipInstallLint.ps1"
        Set-Content -Path $testFile -Value "run: pip install should-be-excluded"

        $result = script:Invoke-Lint -TargetDir $testDir
        $result | Should -Be $true
        $script:Violations.Count | Should -Be 0
    }
}
