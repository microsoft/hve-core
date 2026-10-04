#Requires -Modules Pester

# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

using module ../../security/Modules/SecurityClasses.psm1

BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '../../security/Test-WorkflowRunner.ps1'
    . $scriptPath

    Import-Module (Join-Path $PSScriptRoot '../Mocks/GitMocks.psm1') -Force
    Save-CIEnvironment

    function New-TestWorkflow {
        param(
            [Parameter(Mandatory = $true)][string]$Name,
            [Parameter(Mandatory = $true)][string]$Content
        )

        $directory = Join-Path $TestDrive $Name
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
        $filePath = Join-Path $directory 'workflow.yml'
        Set-Content -Path $filePath -Value $Content -Encoding utf8
        return $filePath
    }
}

AfterAll {
    Restore-CIEnvironment
    Remove-Module CIHelpers -Force -ErrorAction SilentlyContinue
    Remove-Module SecurityHelpers -Force -ErrorAction SilentlyContinue
}

Describe 'Test-UbuntuRunnerLabel' -Tag 'Unit' {
    It 'Should accept dated ubuntu labels' {
        Test-UbuntuRunnerLabel -Label 'ubuntu-24.04' | Should -BeTrue
        Test-UbuntuRunnerLabel -Label 'ubuntu-22.04' | Should -BeTrue
        Test-UbuntuRunnerLabel -Label 'ubuntu-26.04' | Should -BeTrue
    }

    It 'Should accept arm variants of dated ubuntu labels' {
        Test-UbuntuRunnerLabel -Label 'ubuntu-24.04-arm' | Should -BeTrue
    }

    It 'Should accept firewall variants of dated ubuntu labels' {
        Test-UbuntuRunnerLabel -Label 'ubuntu-24.04-firewall' | Should -BeTrue
    }

    It 'Should reject the floating label <Label>' -TestCases @(
        @{ Label = 'ubuntu-latest' }
        @{ Label = 'ubuntu-slim' }
    ) {
        param($Label)
        Test-UbuntuRunnerLabel -Label $Label | Should -BeFalse
    }

    It 'Should reject windows-latest' {
        Test-UbuntuRunnerLabel -Label 'windows-latest' | Should -BeFalse
    }

    It 'Should reject macos-latest' {
        Test-UbuntuRunnerLabel -Label 'macos-latest' | Should -BeFalse
    }

    It 'Should reject self-hosted' {
        Test-UbuntuRunnerLabel -Label 'self-hosted' | Should -BeFalse
    }

    It 'Should reject a label that merely contains an allowed label as a substring' {
        Test-UbuntuRunnerLabel -Label 'ubuntu-24.04-custom' | Should -BeFalse
        Test-UbuntuRunnerLabel -Label 'ubuntu-24.04-arm-firewall' | Should -BeFalse
        Test-UbuntuRunnerLabel -Label 'my-ubuntu-24.04' | Should -BeFalse
    }
}

Describe 'Test-WorkflowRunner' -Tag 'Unit' {
    Context 'Compliant runners' {
        It 'Should return no violations for <Label>' -TestCases @(
            @{ Label = 'ubuntu-24.04' }
            @{ Label = 'ubuntu-24.04-arm' }
            @{ Label = 'ubuntu-24.04-firewall' }
        ) {
            param($Label)
            $filePath = New-TestWorkflow -Name "compliant-$Label" -Content @"
name: Compliant
on: push
permissions:
  contents: read
jobs:
  build:
    runs-on: $Label
    steps:
      - run: echo hi
"@
            $result = @(Test-WorkflowRunner -FilePath $filePath)
            $result | Should -HaveCount 0
        }

        It 'Should not flag a job that calls a reusable workflow with uses:' {
            $filePath = New-TestWorkflow -Name 'reusable-caller' -Content @'
name: Reusable Caller
on: push
permissions:
  contents: read
jobs:
  call-other:
    uses: ./.github/workflows/other.yml
    permissions:
      contents: read
'@
            $result = @(Test-WorkflowRunner -FilePath $filePath)
            $result | Should -HaveCount 0
        }
    }

    Context 'Floating runners' {
        It 'Should flag <Label> as FloatingRunnerLabel' -TestCases @(
            @{ Label = 'ubuntu-latest' }
            @{ Label = 'ubuntu-slim' }
        ) {
            param($Label)
            $filePath = New-TestWorkflow -Name "floating-$Label" -Content @"
name: Floating
on: push
permissions:
  contents: read
jobs:
  build:
    runs-on: $Label
    steps:
      - run: echo hi
"@
            $result = @(Test-WorkflowRunner -FilePath $filePath)
            $result | Should -HaveCount 1
            $result[0].ViolationType | Should -Be 'FloatingRunnerLabel'
            $result[0].Severity | Should -Be 'High'
            $result[0].Remediation | Should -Match 'ubuntu-24\.04'
        }

        It 'Should classify a list mixing a floating and a non-Ubuntu label as NonUbuntuRunner' {
            $filePath = New-TestWorkflow -Name 'floating-and-windows' -Content @'
name: Mixed
on: push
permissions:
  contents: read
jobs:
  build:
    runs-on: [ubuntu-latest, windows-latest]
    steps:
      - run: echo hi
'@
            $result = @(Test-WorkflowRunner -FilePath $filePath)
            $result | Should -HaveCount 1
            $result[0].ViolationType | Should -Be 'NonUbuntuRunner'
        }
    }

    Context 'Non-Ubuntu runners' {
        It 'Should flag windows-latest as NonUbuntuRunner' {
            $filePath = New-TestWorkflow -Name 'windows-job' -Content @'
name: Windows Job
on: push
permissions:
  contents: read
jobs:
  build:
    runs-on: windows-latest
    steps:
      - run: echo hi
'@
            $result = @(Test-WorkflowRunner -FilePath $filePath)
            $result | Should -HaveCount 1
            $result[0].ViolationType | Should -Be 'NonUbuntuRunner'
            $result[0].Name | Should -Be 'build'
            $result[0].Severity | Should -Be 'High'
        }

        It 'Should flag self-hosted as NonUbuntuRunner' {
            $filePath = New-TestWorkflow -Name 'self-hosted-job' -Content @'
name: Self Hosted Job
on: push
permissions:
  contents: read
jobs:
  build:
    runs-on: self-hosted
    steps:
      - run: echo hi
'@
            $result = @(Test-WorkflowRunner -FilePath $filePath)
            $result | Should -HaveCount 1
            $result[0].ViolationType | Should -Be 'NonUbuntuRunner'
        }

        It 'Should flag a runs-on list containing a non-Ubuntu label' {
            $filePath = New-TestWorkflow -Name 'list-job' -Content @'
name: List Job
on: push
permissions:
  contents: read
jobs:
  build:
    runs-on: [self-hosted, linux]
    steps:
      - run: echo hi
'@
            $result = @(Test-WorkflowRunner -FilePath $filePath)
            $result | Should -HaveCount 1
            $result[0].ViolationType | Should -Be 'NonUbuntuRunner'
        }

        It 'Should report the job declaration line rather than line 0' {
            $filePath = New-TestWorkflow -Name 'windows-job-line' -Content @'
name: Windows Job
on: push
permissions:
  contents: read
jobs:
  build:
    runs-on: windows-latest
    steps:
      - run: echo hi
'@
            $result = @(Test-WorkflowRunner -FilePath $filePath)
            $result[0].Line | Should -BeGreaterThan 0
        }
    }

    Context 'Unresolvable runners' {
        It 'Should flag a matrix expression as NonUbuntuRunner' {
            $filePath = New-TestWorkflow -Name 'matrix-job' -Content @'
name: Matrix Job
on: push
permissions:
  contents: read
jobs:
  build:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest]
    steps:
      - run: echo hi
'@
            $result = @(Test-WorkflowRunner -FilePath $filePath)
            $result | Should -HaveCount 1
            $result[0].ViolationType | Should -Be 'NonUbuntuRunner'
            $result[0].Description | Should -Match 'matrix\.os'
        }
    }

    Context 'Missing runners' {
        It 'Should flag a job with no runs-on value as MissingRunner' {
            $filePath = New-TestWorkflow -Name 'missing-runs-on' -Content @'
name: Missing Runs On
on: push
permissions:
  contents: read
jobs:
  build:
    permissions:
      contents: read
    steps:
      - run: echo hi
'@
            $result = @(Test-WorkflowRunner -FilePath $filePath)
            $result | Should -HaveCount 1
            $result[0].ViolationType | Should -Be 'MissingRunner'
            $result[0].Severity | Should -Be 'High'
        }
    }

    Context 'Unparseable workflow' {
        It 'Should return no violations rather than throwing' {
            $filePath = New-TestWorkflow -Name 'invalid-yaml' -Content @'
name: Invalid
on: push
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: echo "unterminated
'@
            { Test-WorkflowRunner -FilePath $filePath } | Should -Not -Throw
        }
    }
}

Describe 'ConvertTo-RunnerSarif' -Tag 'Unit' {
    Context 'With violations' {
        BeforeAll {
            $script:violation = [DependencyViolation]::new()
            $script:violation.File = '.github/workflows/example.yml'
            $script:violation.Line = 6
            $script:violation.Type = 'workflow-runner'
            $script:violation.Name = 'build'
            $script:violation.ViolationType = 'NonUbuntuRunner'
            $script:violation.Severity = 'High'
            $script:violation.Description = "Job 'build' runs on 'windows-latest'"
            $script:violation.Remediation = 'Use ubuntu-24.04'
        }

        It 'Should produce valid SARIF structure' {
            $sarif = ConvertTo-RunnerSarif -Violations @($script:violation)
            $sarif.version | Should -Be '2.1.0'
            $sarif.runs[0].results | Should -HaveCount 1
        }

        It 'Should route NonUbuntuRunner to the non-ubuntu-runner rule' {
            $sarif = ConvertTo-RunnerSarif -Violations @($script:violation)
            $sarif.runs[0].results[0].ruleId | Should -Be 'non-ubuntu-runner'
        }

        It 'Should route FloatingRunnerLabel to the floating-runner-label rule' {
            $floating = [DependencyViolation]::new()
            $floating.File = '.github/workflows/example.yml'
            $floating.Line = 6
            $floating.Type = 'workflow-runner'
            $floating.Name = 'build'
            $floating.ViolationType = 'FloatingRunnerLabel'
            $floating.Severity = 'High'
            $floating.Description = "Job 'build' runs on the floating label 'ubuntu-latest'"
            $sarif = ConvertTo-RunnerSarif -Violations @($floating)
            $sarif.runs[0].results[0].ruleId | Should -Be 'floating-runner-label'
            $sarif.runs[0].tool.driver.rules.id | Should -Contain 'floating-runner-label'
        }

        It 'Should never emit a startLine below 1' {
            $script:violation.Line = 0
            $sarif = ConvertTo-RunnerSarif -Violations @($script:violation)
            $sarif.runs[0].results[0].locations[0].physicalLocation.region.startLine | Should -BeGreaterOrEqual 1
        }
    }

    Context 'Without violations' {
        It 'Should produce valid SARIF with empty results' {
            $sarif = ConvertTo-RunnerSarif -Violations @()
            $sarif.runs[0].results | Should -HaveCount 0
        }
    }
}

Describe 'Invoke-WorkflowRunnerCheck' -Tag 'Integration' {
    BeforeAll {
        function New-TestWorkflowDir {
            param([string]$Name)
            $directory = Join-Path $TestDrive $Name
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
            return $directory
        }
    }

    Context 'Scanning directory with mixed workflows' {
        BeforeAll {
            $script:scanDir = New-TestWorkflowDir -Name 'mixed-scan'
            Set-Content -Path (Join-Path $script:scanDir 'good.yml') -Value @'
name: Good
on: push
permissions:
  contents: read
jobs:
  build:
    runs-on: ubuntu-24.04
    steps:
      - run: echo hi
'@ -Encoding utf8
            Set-Content -Path (Join-Path $script:scanDir 'bad.yml') -Value @'
name: Bad
on: push
permissions:
  contents: read
jobs:
  build:
    runs-on: windows-latest
    steps:
      - run: echo hi
'@ -Encoding utf8
        }

        It 'Should detect the non-Ubuntu runner' {
            $outputPath = Join-Path $TestDrive 'results.json'
            $exitCode = Invoke-WorkflowRunnerCheck -Path $script:scanDir -Format json -OutputPath $outputPath -ExcludePaths ''
            $exitCode | Should -Be 0

            $results = Get-Content $outputPath -Raw | ConvertFrom-Json
            $results.Violations | Should -HaveCount 1
        }

        It 'Should fail with FailOnViolation when violations exist' {
            $outputPath = Join-Path $TestDrive 'results-fail.json'
            $exitCode = Invoke-WorkflowRunnerCheck -Path $script:scanDir -Format json -OutputPath $outputPath -FailOnViolation -ExcludePaths ''
            $exitCode | Should -Be 1
        }

        It 'Should return exit code 0 when all workflows are compliant' {
            $goodOnlyDir = New-TestWorkflowDir -Name 'good-only'
            Copy-Item -Path (Join-Path $script:scanDir 'good.yml') -Destination $goodOnlyDir

            $outputPath = Join-Path $TestDrive 'results-good.json'
            $exitCode = Invoke-WorkflowRunnerCheck -Path $goodOnlyDir -Format json -OutputPath $outputPath -FailOnViolation -ExcludePaths ''
            $exitCode | Should -Be 0
        }
    }

    Context 'Exclusion filtering' {
        It 'Should exclude specified files' {
            $excludeDir = New-TestWorkflowDir -Name 'exclusion-test'
            Set-Content -Path (Join-Path $excludeDir 'excluded.yml') -Value @'
name: Excluded
on: push
permissions:
  contents: read
jobs:
  build:
    runs-on: windows-latest
    steps:
      - run: echo hi
'@ -Encoding utf8

            $outputPath = Join-Path $TestDrive 'results-excluded.json'
            $exitCode = Invoke-WorkflowRunnerCheck -Path $excludeDir -Format json -OutputPath $outputPath -FailOnViolation -ExcludePaths 'excluded.yml'
            $exitCode | Should -Be 0
        }

        It 'Should scan copilot-setup-steps.yml by default' {
            $defaultDir = New-TestWorkflowDir -Name 'default-exclusions'
            Set-Content -Path (Join-Path $defaultDir 'copilot-setup-steps.yml') -Value @'
name: Copilot Setup Steps
on: workflow_dispatch
permissions:
  contents: read
jobs:
  copilot-setup-steps:
    runs-on: ubuntu-latest
    steps:
      - run: echo hi
'@ -Encoding utf8

            $outputPath = Join-Path $TestDrive 'results-default-exclusions.json'
            $exitCode = Invoke-WorkflowRunnerCheck -Path $defaultDir -Format json -OutputPath $outputPath -FailOnViolation
            $exitCode | Should -Be 1
            $results = Get-Content $outputPath -Raw | ConvertFrom-Json
            $results.Violations[0].ViolationType | Should -Be 'FloatingRunnerLabel'
        }
    }

    Context 'Output formats' {
        BeforeAll {
            $script:formatDir = New-TestWorkflowDir -Name 'format-test'
            Set-Content -Path (Join-Path $script:formatDir 'workflow.yml') -Value @'
name: Format Test
on: push
permissions:
  contents: read
jobs:
  build:
    runs-on: windows-latest
    steps:
      - run: echo hi
'@ -Encoding utf8
        }

        It 'Should produce SARIF output' {
            $outputPath = Join-Path $TestDrive 'results.sarif'
            Invoke-WorkflowRunnerCheck -Path $script:formatDir -Format sarif -OutputPath $outputPath -ExcludePaths '' | Out-Null
            $sarif = Get-Content $outputPath -Raw | ConvertFrom-Json
            $sarif.version | Should -Be '2.1.0'
        }

        It 'Should produce JSON output by default' {
            $outputPath = Join-Path $TestDrive 'results-default.json'
            Invoke-WorkflowRunnerCheck -Path $script:formatDir -Format json -OutputPath $outputPath -ExcludePaths '' | Out-Null
            { Get-Content $outputPath -Raw | ConvertFrom-Json } | Should -Not -Throw
        }
    }
}
