#Requires -Modules Pester

# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

using module ../../security/Modules/SecurityClasses.psm1

BeforeAll {
    . (Join-Path $PSScriptRoot '../../security/Test-DangerousWorkflow.ps1')

    Mock Write-Host {}

    function New-DangerousWorkflowFixture {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Name,

            [Parameter(Mandatory = $true)]
            [string]$WorkflowContent
        )

        $fixtureDir = Join-Path $TestDrive $Name
        New-Item -ItemType Directory -Path $fixtureDir -Force | Out-Null

        $workflowPath = Join-Path $fixtureDir 'workflow.yml'
        Set-Content -Path $workflowPath -Value $WorkflowContent -Encoding utf8

        return $fixtureDir
    }

    function Invoke-DangerousWorkflowFixture {
        param(
            [Parameter(Mandatory = $true)]
            [string]$FixturePath,

            [Parameter(Mandatory = $false)]
            [ValidateSet('json', 'sarif', 'console')]
            [string]$Format = 'json',

            [Parameter(Mandatory = $false)]
            [string]$OutputPath = '',

            [Parameter(Mandatory = $false)]
            [switch]$FailOnViolation
        )

        if ([string]::IsNullOrWhiteSpace($OutputPath)) {
            $OutputPath = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString() + '.out')
        }

        $params = @{
            Path = $FixturePath
            Format = $Format
            OutputPath = $OutputPath
        }

        if ($FailOnViolation) {
            $params.FailOnViolation = $true
        }

        return Invoke-DangerousWorkflowCheck @params
    }
}

Describe 'Test-DangerousWorkflow' -Tag 'Unit' {
    It 'flags template injection in run blocks' {
        $fixturePath = New-DangerousWorkflowFixture -Name 'template-injection' -WorkflowContent @'
name: test
on:
  pull_request_target:
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: echo "${{ github.event.pull_request.title }}"
'@

        $outputPath = Join-Path $TestDrive 'template-injection.json'
        $exitCode = Invoke-DangerousWorkflowFixture -FixturePath $fixturePath -Format json -OutputPath $outputPath

        $exitCode | Should -Be 0
        $report = Get-Content -Path $outputPath -Raw | ConvertFrom-Json
        $report.Violations | Should -HaveCount 1
        $report.Violations[0].Metadata.RuleId | Should -Be 'dangerous-workflow/template-injection'
    }

    It 'flags multiline run-block template injection expressions' {
        $fixturePath = New-DangerousWorkflowFixture -Name 'multiline-template-injection' -WorkflowContent @'
name: test
on:
  pull_request_target:
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: |
          echo "before"
          echo "${{ github.event.pull_request.title }}"
'@

        $outputPath = Join-Path $TestDrive 'multiline-template-injection.json'
        Invoke-DangerousWorkflowFixture -FixturePath $fixturePath -Format json -OutputPath $outputPath | Out-Null

        $report = Get-Content -Path $outputPath -Raw | ConvertFrom-Json
        $report.Violations | Should -HaveCount 1
        $report.Violations[0].Metadata.RuleId | Should -Be 'dangerous-workflow/template-injection'
    }

    It 'flags template injection inside github-script blocks' {
        $fixturePath = New-DangerousWorkflowFixture -Name 'github-script-injection' -WorkflowContent @'
name: test
on:
  issues:
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/github-script@v7
        with:
          script: |
            console.log("${{ github.event.issue.title }}")
'@

        $outputPath = Join-Path $TestDrive 'github-script-injection.json'
        Invoke-DangerousWorkflowFixture -FixturePath $fixturePath -Format json -OutputPath $outputPath | Out-Null

        $report = Get-Content -Path $outputPath -Raw | ConvertFrom-Json
        $report.Violations | Should -HaveCount 1
        $report.Violations[0].Metadata.RuleId | Should -Be 'dangerous-workflow/template-injection'
    }

    It 'does not flag trusted expressions in run blocks' {
        $fixturePath = New-DangerousWorkflowFixture -Name 'trusted-expression' -WorkflowContent @'
name: test
on:
  pull_request_target:
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: echo "${{ github.sha }} ${{ github.repository }}"
'@

        $outputPath = Join-Path $TestDrive 'trusted-expression.json'
        $exitCode = Invoke-DangerousWorkflowFixture -FixturePath $fixturePath -Format json -OutputPath $outputPath

        $exitCode | Should -Be 0
        $report = Get-Content -Path $outputPath -Raw | ConvertFrom-Json
        $report.Violations | Should -HaveCount 0
    }

    It 'does not flag output-derived expressions as out-of-scope indirect derivations' {
        $fixturePath = New-DangerousWorkflowFixture -Name 'output-derived-injection' -WorkflowContent @'
name: test
on:
  pull_request_target:
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - id: setup
        run: echo "value=x" >> "$GITHUB_OUTPUT"
      - run: echo "${{ steps.setup.outputs.value }}"
'@

        $outputPath = Join-Path $TestDrive 'output-derived-injection.json'
        Invoke-DangerousWorkflowFixture -FixturePath $fixturePath -Format json -OutputPath $outputPath | Out-Null

        $report = Get-Content -Path $outputPath -Raw | ConvertFrom-Json
        $report.Violations | Should -HaveCount 0
    }

    It 'continues scanning when one workflow file is malformed YAML' {
        $fixturePath = Join-Path $TestDrive 'malformed-yaml'
        New-Item -ItemType Directory -Path $fixturePath -Force | Out-Null

        $badWorkflowPath = Join-Path $fixturePath 'bad.yml'
        Set-Content -Path $badWorkflowPath -Value @'
name: broken
on:
  pull_request_target:
    jobs:
      build:
        runs-on: ubuntu-latest
        steps:
          - run: echo "${{ github.event.pull_request.title }}"
              bad: [unterminated
'@ -Encoding utf8

        $validWorkflowPath = Join-Path $fixturePath 'good.yml'
        Set-Content -Path $validWorkflowPath -Value @'
name: good
on:
  pull_request_target:
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: echo "${{ github.event.pull_request.title }}"
'@ -Encoding utf8

        $outputPath = Join-Path $TestDrive 'malformed-yaml.json'
        { Invoke-DangerousWorkflowFixture -FixturePath $fixturePath -Format json -OutputPath $outputPath } | Should -Not -Throw

        $report = Get-Content -Path $outputPath -Raw | ConvertFrom-Json
        $report.Violations | Should -HaveCount 1
        $report.Violations[0].Metadata.RuleId | Should -Be 'dangerous-workflow/template-injection'
    }

    It 'writes SARIF output with the expected rule id and level' {
        $fixturePath = New-DangerousWorkflowFixture -Name 'sarif-output' -WorkflowContent @'
name: test
on:
  pull_request_target:
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: echo "${{ github.event.pull_request.title }}"
'@

        $outputPath = Join-Path $TestDrive 'sarif-output.sarif'
        Invoke-DangerousWorkflowFixture -FixturePath $fixturePath -Format sarif -OutputPath $outputPath | Out-Null

        $sarif = Get-Content -Path $outputPath -Raw | ConvertFrom-Json
        $sarif.runs[0].results | Should -HaveCount 1
        $sarif.runs[0].results[0].ruleId | Should -Be 'dangerous-workflow/template-injection'
        $sarif.runs[0].results[0].level | Should -Be 'error'
        $sarif.runs[0].tool.driver.rules | Should -HaveCount 1
        $sarif.runs[0].tool.driver.rules[0].id | Should -Be 'dangerous-workflow/template-injection'
    }

    It 'writes console output for violations' {
        $fixturePath = New-DangerousWorkflowFixture -Name 'console-output' -WorkflowContent @'
name: test
on:
  pull_request_target:
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: echo "${{ github.event.pull_request.title }}"
'@

        $outputPath = Join-Path $TestDrive 'console-output.txt'
        Invoke-DangerousWorkflowFixture -FixturePath $fixturePath -Format console -OutputPath $outputPath | Out-Null

        $consoleOutput = Get-Content -Path $outputPath -Raw
        $consoleOutput | Should -Match 'Dangerous workflow findings found:'
        $consoleOutput | Should -Match 'dangerous-workflow/template-injection'
    }

    It 'reports no findings for a clean workflow' {
        $fixturePath = New-DangerousWorkflowFixture -Name 'clean-workflow' -WorkflowContent @'
name: test
on:
  pull_request:
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: echo "no interpolation here"
'@

        $outputPath = Join-Path $TestDrive 'clean-workflow.txt'
        $exitCode = Invoke-DangerousWorkflowFixture -FixturePath $fixturePath -Format console -OutputPath $outputPath

        $exitCode | Should -Be 0
        $consoleOutput = Get-Content -Path $outputPath -Raw
        $consoleOutput | Should -Match 'No dangerous workflow findings were detected.'
    }

    It 'returns a non-zero exit code when FailOnViolation is used' {
        $fixturePath = New-DangerousWorkflowFixture -Name 'fail-on-violation' -WorkflowContent @'
name: test
on:
  pull_request_target:
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: echo "${{ github.event.pull_request.title }}"
'@

        $outputPath = Join-Path $TestDrive 'fail-on-violation.json'
        $exitCode = Invoke-DangerousWorkflowFixture -FixturePath $fixturePath -Format json -OutputPath $outputPath -FailOnViolation

        $exitCode | Should -Be 1
    }
}
