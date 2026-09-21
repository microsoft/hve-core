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
        $report.Violations[0].Line | Should -Be 8
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
        $report.Violations[0].Line | Should -Be 10
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
      - name: later
        run: echo hi
'@

        $outputPath = Join-Path $TestDrive 'github-script-injection.json'
        Invoke-DangerousWorkflowFixture -FixturePath $fixturePath -Format json -OutputPath $outputPath | Out-Null

        $report = Get-Content -Path $outputPath -Raw | ConvertFrom-Json
        $report.Violations | Should -HaveCount 1
        $report.Violations[0].Metadata.RuleId | Should -Be 'dangerous-workflow/template-injection'
        # The injection is on line 11 (the script interpolation), not the innocent 'run: echo hi' at line 13.
        $report.Violations[0].Line | Should -Be 11
    }

    It 'reports the correct line for an injection in a later job regardless of job order' {
        $fixturePath = New-DangerousWorkflowFixture -Name 'multi-job-order' -WorkflowContent @'
name: test
on:
  pull_request_target:
jobs:
  alpha:
    runs-on: ubuntu-latest
    steps:
      - run: echo "safe"
  beta:
    runs-on: ubuntu-latest
    steps:
      - run: echo "${{ github.event.pull_request.title }}"
'@

        $outputPath = Join-Path $TestDrive 'multi-job-order.json'
        Invoke-DangerousWorkflowFixture -FixturePath $fixturePath -Format json -OutputPath $outputPath | Out-Null

        $report = Get-Content -Path $outputPath -Raw | ConvertFrom-Json
        $report.Violations | Should -HaveCount 1
        $report.Violations[0].Metadata.RuleId | Should -Be 'dangerous-workflow/template-injection'
        $report.Violations[0].Line | Should -Be 12
    }

    It 'does not flag a with.script input on a non-github-script action' {
        $fixturePath = New-DangerousWorkflowFixture -Name 'non-github-script-with-script' -WorkflowContent @'
name: test
on:
  pull_request_target:
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: some/other-action@v1
        with:
          script: echo "${{ github.event.pull_request.title }}"
'@

        $outputPath = Join-Path $TestDrive 'non-github-script-with-script.json'
        Invoke-DangerousWorkflowFixture -FixturePath $fixturePath -Format json -OutputPath $outputPath | Out-Null

        $report = Get-Content -Path $outputPath -Raw | ConvertFrom-Json
        $report.Violations | Should -HaveCount 0
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
        $sarif.runs[0].tool.driver.rules | Should -HaveCount 2
        @($sarif.runs[0].tool.driver.rules.id) | Should -Contain 'dangerous-workflow/template-injection'
        @($sarif.runs[0].tool.driver.rules.id) | Should -Contain 'dangerous-workflow/direct-input-interpolation'
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

    Context 'CQ-6 caller-controlled input isolation' {
        It 'flags a workflow_call string input interpolated into a pwsh run block' {
            $fixturePath = New-DangerousWorkflowFixture -Name 'cq6-string-pwsh' -WorkflowContent @'
name: test
on:
  workflow_call:
    inputs:
      base-branch:
        type: string
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - shell: pwsh
        run: |
          $base = '${{ inputs.base-branch }}'
          git diff --name-only "$base...HEAD"
'@

            $outputPath = Join-Path $TestDrive 'cq6-string-pwsh.json'
            Invoke-DangerousWorkflowFixture -FixturePath $fixturePath -Format json -OutputPath $outputPath | Out-Null

            $report = Get-Content -Path $outputPath -Raw | ConvertFrom-Json
            $report.Violations | Should -HaveCount 1
            $report.Violations[0].Metadata.RuleId | Should -Be 'dangerous-workflow/direct-input-interpolation'
            $report.Violations[0].Line | Should -Be 13
            $report.Violations[0].Description | Should -Match "inputs.base-branch"
            $report.Violations[0].Description | Should -Match 'type string'
            $report.Violations[0].Remediation | Should -Match 'INPUT_BASE_BRANCH'
        }

        It 'flags a workflow_call number input interpolated into a bash run block' {
            $fixturePath = New-DangerousWorkflowFixture -Name 'cq6-number-bash' -WorkflowContent @'
name: test
on:
  workflow_call:
    inputs:
      max-age-days:
        type: number
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - shell: bash
        run: echo "threshold ${{ inputs.max-age-days }}"
'@

            $outputPath = Join-Path $TestDrive 'cq6-number-bash.json'
            Invoke-DangerousWorkflowFixture -FixturePath $fixturePath -Format json -OutputPath $outputPath | Out-Null

            $report = Get-Content -Path $outputPath -Raw | ConvertFrom-Json
            $report.Violations | Should -HaveCount 1
            $report.Violations[0].Metadata.RuleId | Should -Be 'dangerous-workflow/direct-input-interpolation'
            $report.Violations[0].Description | Should -Match 'type number'
        }

        It 'flags a workflow_dispatch string input interpolated into a run block' {
            $fixturePath = New-DangerousWorkflowFixture -Name 'cq6-dispatch-string' -WorkflowContent @'
name: test
on:
  workflow_dispatch:
    inputs:
      target:
        type: string
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: echo "${{ inputs.target }}"
'@

            $outputPath = Join-Path $TestDrive 'cq6-dispatch-string.json'
            Invoke-DangerousWorkflowFixture -FixturePath $fixturePath -Format json -OutputPath $outputPath | Out-Null

            $report = Get-Content -Path $outputPath -Raw | ConvertFrom-Json
            $report.Violations | Should -HaveCount 1
            $report.Violations[0].Metadata.RuleId | Should -Be 'dangerous-workflow/direct-input-interpolation'
        }

        It 'fails closed when the referenced input is not declared' {
            $fixturePath = New-DangerousWorkflowFixture -Name 'cq6-undeclared' -WorkflowContent @'
name: test
on:
  workflow_call:
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: echo "${{ inputs.mystery }}"
'@

            $outputPath = Join-Path $TestDrive 'cq6-undeclared.json'
            Invoke-DangerousWorkflowFixture -FixturePath $fixturePath -Format json -OutputPath $outputPath | Out-Null

            $report = Get-Content -Path $outputPath -Raw | ConvertFrom-Json
            $report.Violations | Should -HaveCount 1
            $report.Violations[0].Metadata.RuleId | Should -Be 'dangerous-workflow/direct-input-interpolation'
            $report.Violations[0].Description | Should -Match 'type undeclared'
        }

        It 'flags an input interpolated into a github-script body' {
            $fixturePath = New-DangerousWorkflowFixture -Name 'cq6-github-script' -WorkflowContent @'
name: test
on:
  workflow_call:
    inputs:
      label:
        type: string
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/github-script@v7
        with:
          script: |
            console.log("${{ inputs.label }}")
'@

            $outputPath = Join-Path $TestDrive 'cq6-github-script.json'
            Invoke-DangerousWorkflowFixture -FixturePath $fixturePath -Format json -OutputPath $outputPath | Out-Null

            $report = Get-Content -Path $outputPath -Raw | ConvertFrom-Json
            $report.Violations | Should -HaveCount 1
            $report.Violations[0].Metadata.RuleId | Should -Be 'dangerous-workflow/direct-input-interpolation'
        }

        It 'flags an input reached through a compound expression' {
            $fixturePath = New-DangerousWorkflowFixture -Name 'cq6-compound' -WorkflowContent @'
name: test
on:
  workflow_call:
    inputs:
      threshold:
        type: number
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - shell: pwsh
        run: $days = ${{ inputs.threshold || 30 }}
'@

            $outputPath = Join-Path $TestDrive 'cq6-compound.json'
            Invoke-DangerousWorkflowFixture -FixturePath $fixturePath -Format json -OutputPath $outputPath | Out-Null

            $report = Get-Content -Path $outputPath -Raw | ConvertFrom-Json
            $report.Violations | Should -HaveCount 1
            $report.Violations[0].Metadata.RuleId | Should -Be 'dangerous-workflow/direct-input-interpolation'
        }

        It 'does not flag a boolean input compared inside a run block' {
            $fixturePath = New-DangerousWorkflowFixture -Name 'cq6-boolean-exception' -WorkflowContent @'
name: test
on:
  workflow_call:
    inputs:
      soft-fail:
        type: boolean
      changed-files-only:
        type: boolean
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - shell: pwsh
        run: |
          if ('${{ inputs.soft-fail }}' -ne 'true') { throw 'strict' }
          if ('${{ inputs.changed-files-only }}' -eq 'true') { Write-Host 'scoped' }
'@

            $outputPath = Join-Path $TestDrive 'cq6-boolean-exception.json'
            $exitCode = Invoke-DangerousWorkflowFixture -FixturePath $fixturePath -Format json -OutputPath $outputPath -FailOnViolation

            $exitCode | Should -Be 0
            $report = Get-Content -Path $outputPath -Raw | ConvertFrom-Json
            @($report.Violations) | Should -HaveCount 0
        }

        It 'does not flag a string input delivered through a step-level env mapping' {
            $fixturePath = New-DangerousWorkflowFixture -Name 'cq6-env-mapping' -WorkflowContent @'
name: test
on:
  workflow_call:
    inputs:
      working-directory:
        type: string
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - shell: bash
        env:
          INPUT_WORKING_DIRECTORY: ${{ inputs.working-directory }}
        run: echo "$INPUT_WORKING_DIRECTORY"
'@

            $outputPath = Join-Path $TestDrive 'cq6-env-mapping.json'
            $exitCode = Invoke-DangerousWorkflowFixture -FixturePath $fixturePath -Format json -OutputPath $outputPath -FailOnViolation

            $exitCode | Should -Be 0
            $report = Get-Content -Path $outputPath -Raw | ConvertFrom-Json
            @($report.Violations) | Should -HaveCount 0
        }

        It 'does not flag inputs used outside code execution contexts' {
            $fixturePath = New-DangerousWorkflowFixture -Name 'cq6-non-code-context' -WorkflowContent @'
name: test
on:
  workflow_call:
    inputs:
      working-directory:
        type: string
      changed-files-only:
        type: boolean
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - if: inputs.changed-files-only
        working-directory: ${{ inputs.working-directory }}
        run: npm test
      - uses: actions/upload-artifact@v4
        with:
          name: results
          path: ${{ inputs.working-directory }}/coverage.xml
'@

            $outputPath = Join-Path $TestDrive 'cq6-non-code-context.json'
            $exitCode = Invoke-DangerousWorkflowFixture -FixturePath $fixturePath -Format json -OutputPath $outputPath -FailOnViolation

            $exitCode | Should -Be 0
            $report = Get-Content -Path $outputPath -Raw | ConvertFrom-Json
            @($report.Violations) | Should -HaveCount 0
        }

        It 'reports both rules when a workflow carries an untrusted expression and a string input' {
            $fixturePath = New-DangerousWorkflowFixture -Name 'cq6-mixed' -WorkflowContent @'
name: test
on:
  workflow_call:
    inputs:
      label:
        type: string
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: echo "${{ github.event.pull_request.title }}"
      - run: echo "${{ inputs.label }}"
'@

            $outputPath = Join-Path $TestDrive 'cq6-mixed.sarif'
            Invoke-DangerousWorkflowFixture -FixturePath $fixturePath -Format sarif -OutputPath $outputPath | Out-Null

            $sarif = Get-Content -Path $outputPath -Raw | ConvertFrom-Json
            $sarif.runs[0].results | Should -HaveCount 2
            @($sarif.runs[0].results.ruleId) | Should -Contain 'dangerous-workflow/template-injection'
            @($sarif.runs[0].results.ruleId) | Should -Contain 'dangerous-workflow/direct-input-interpolation'
        }
    }

    Context 'CQ-6 composite action coverage' {
        It 'flags an action input interpolated into a composite run body' {
            $fixturePath = New-DangerousWorkflowFixture -Name 'cq6-composite-action' -WorkflowContent @'
name: Sample composite
description: fixture
inputs:
  force:
    description: 'Force reinstall'
    required: false
    default: 'false'
runs:
  using: composite
  steps:
    - name: Install
      shell: pwsh
      run: |
        if ('${{ inputs.force }}' -eq 'true') { Write-Host 'forced' }
'@

            $outputPath = Join-Path $TestDrive 'cq6-composite-action.json'
            Invoke-DangerousWorkflowFixture -FixturePath $fixturePath -Format json -OutputPath $outputPath | Out-Null

            $report = Get-Content -Path $outputPath -Raw | ConvertFrom-Json
            $report.Violations | Should -HaveCount 1
            $report.Violations[0].Metadata.RuleId | Should -Be 'dangerous-workflow/direct-input-interpolation'
            $report.Violations[0].Metadata.Job | Should -Be 'runs'
            $report.Violations[0].Description | Should -Match 'type untyped'
            $report.Violations[0].Remediation | Should -Match 'INPUT_FORCE'
        }

        It 'flags an untrusted event expression in a composite run body' {
            $fixturePath = New-DangerousWorkflowFixture -Name 'composite-template-injection' -WorkflowContent @'
name: Sample composite
description: fixture
runs:
  using: composite
  steps:
    - shell: bash
      run: echo "${{ github.event.issue.title }}"
'@

            $outputPath = Join-Path $TestDrive 'composite-template-injection.json'
            Invoke-DangerousWorkflowFixture -FixturePath $fixturePath -Format json -OutputPath $outputPath | Out-Null

            $report = Get-Content -Path $outputPath -Raw | ConvertFrom-Json
            $report.Violations | Should -HaveCount 1
            $report.Violations[0].Metadata.RuleId | Should -Be 'dangerous-workflow/template-injection'
        }

        It 'does not flag a composite action that delivers its input through env' {
            $fixturePath = New-DangerousWorkflowFixture -Name 'composite-env-mapping' -WorkflowContent @'
name: Sample composite
description: fixture
inputs:
  force:
    description: 'Force reinstall'
    required: false
    default: 'false'
runs:
  using: composite
  steps:
    - shell: pwsh
      env:
        INPUT_FORCE: ${{ inputs.force }}
      run: |
        if ($env:INPUT_FORCE -eq 'true') { Write-Host 'forced' }
'@

            $outputPath = Join-Path $TestDrive 'composite-env-mapping.json'
            $exitCode = Invoke-DangerousWorkflowFixture -FixturePath $fixturePath -Format json -OutputPath $outputPath -FailOnViolation

            $exitCode | Should -Be 0
            $report = Get-Content -Path $outputPath -Raw | ConvertFrom-Json
            @($report.Violations) | Should -HaveCount 0
        }

        It 'ignores a non-composite action metadata file' {
            $fixturePath = New-DangerousWorkflowFixture -Name 'javascript-action' -WorkflowContent @'
name: Sample JS action
description: fixture
inputs:
  force:
    description: 'Force reinstall'
    default: 'false'
runs:
  using: node24
  main: index.js
'@

            $outputPath = Join-Path $TestDrive 'javascript-action.json'
            $exitCode = Invoke-DangerousWorkflowFixture -FixturePath $fixturePath -Format json -OutputPath $outputPath -FailOnViolation

            $exitCode | Should -Be 0
            $report = Get-Content -Path $outputPath -Raw | ConvertFrom-Json
            @($report.Violations) | Should -HaveCount 0
        }

        It 'scans several roots and skips an absent default root' {
            $workflowRoot = New-DangerousWorkflowFixture -Name 'multi-root-workflows' -WorkflowContent @'
name: test
on:
  workflow_call:
    inputs:
      label:
        type: string
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: echo "${{ inputs.label }}"
'@

            $actionRoot = New-DangerousWorkflowFixture -Name 'multi-root-actions' -WorkflowContent @'
name: Sample composite
description: fixture
inputs:
  force:
    description: 'Force reinstall'
    default: 'false'
runs:
  using: composite
  steps:
    - shell: pwsh
      run: Write-Host '${{ inputs.force }}'
'@

            $outputPath = Join-Path $TestDrive 'multi-root.json'
            Invoke-DangerousWorkflowCheck -Path @($workflowRoot, $actionRoot) -Format json -OutputPath $outputPath | Out-Null

            $report = Get-Content -Path $outputPath -Raw | ConvertFrom-Json
            $report.Violations | Should -HaveCount 2
            @($report.Violations.Metadata.RuleId) | Should -Contain 'dangerous-workflow/direct-input-interpolation'
        }

        It 'throws when an explicitly supplied root does not exist' {
            $missingRoot = Join-Path $TestDrive 'no-such-root'
            $outputPath = Join-Path $TestDrive 'missing-root.json'

            { Invoke-DangerousWorkflowCheck -Path $missingRoot -Format json -OutputPath $outputPath } | Should -Throw
        }
    }

    Context 'Expressions spanning multiple lines' {
        It 'flags an input reference in an expression whose body spans lines' {
            $fixturePath = New-DangerousWorkflowFixture -Name 'multiline-expression-input' -WorkflowContent @'
name: test
on:
  workflow_call:
    inputs:
      flag:
        type: boolean
      target:
        type: string
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - shell: bash
        run: |
          echo "${{ inputs.flag
            && inputs.target
            || inputs.target }}"
'@

            $outputPath = Join-Path $TestDrive 'multiline-expression-input.json'
            Invoke-DangerousWorkflowFixture -FixturePath $fixturePath -Format json -OutputPath $outputPath | Out-Null

            $report = Get-Content -Path $outputPath -Raw | ConvertFrom-Json
            $report.Violations | Should -HaveCount 1
            $report.Violations[0].Metadata.RuleId | Should -Be 'dangerous-workflow/direct-input-interpolation'
            $report.Violations[0].Description | Should -Match 'inputs.target'
        }

        It 'flags an untrusted event value in an expression whose body spans lines' {
            $fixturePath = New-DangerousWorkflowFixture -Name 'multiline-expression-event' -WorkflowContent @'
name: test
on:
  pull_request_target:
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: |
          echo "${{ github.event.pull_request.title
            || 'fallback' }}"
'@

            $outputPath = Join-Path $TestDrive 'multiline-expression-event.json'
            Invoke-DangerousWorkflowFixture -FixturePath $fixturePath -Format json -OutputPath $outputPath | Out-Null

            $report = Get-Content -Path $outputPath -Raw | ConvertFrom-Json
            $report.Violations | Should -HaveCount 1
            $report.Violations[0].Metadata.RuleId | Should -Be 'dangerous-workflow/template-injection'
        }

        It 'reports a multi-line expression on a single line' {
            $fixturePath = New-DangerousWorkflowFixture -Name 'multiline-expression-report' -WorkflowContent @'
name: test
on:
  pull_request_target:
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: |
          echo "${{ github.event.issue.title
            || 'fallback' }}"
'@

            $outputPath = Join-Path $TestDrive 'multiline-expression-report.json'
            Invoke-DangerousWorkflowFixture -FixturePath $fixturePath -Format json -OutputPath $outputPath | Out-Null

            $report = Get-Content -Path $outputPath -Raw | ConvertFrom-Json
            $report.Violations[0].Description | Should -Not -Match "`n"
            $report.Violations[0].Description | Should -Match "github.event.issue.title \|\| 'fallback'"
        }
    }
}
