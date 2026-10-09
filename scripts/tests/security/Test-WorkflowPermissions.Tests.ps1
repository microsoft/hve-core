#Requires -Modules Pester

# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

using module ../../security/Modules/SecurityClasses.psm1

BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '../../security/Test-WorkflowPermissions.ps1'
    . $scriptPath

    Import-Module (Join-Path $PSScriptRoot '../Mocks/GitMocks.psm1') -Force
    Save-CIEnvironment

    $script:FixturesPath = Join-Path $PSScriptRoot '../fixtures/Workflows'
}

AfterAll {
    Restore-CIEnvironment
    Remove-Module CIHelpers -Force -ErrorAction SilentlyContinue
    Remove-Module SecurityHelpers -Force -ErrorAction SilentlyContinue
}

Describe 'Write-SecurityLog integration' -Tag 'Unit' {
    BeforeAll {
        Mock Write-Host { }
    }

    It 'Should not throw for Info level' {
        { Write-SecurityLog -Message 'Test info' -Level Info } | Should -Not -Throw
    }

    It 'Should not throw for Warning level' {
        { Write-SecurityLog -Message 'Test warning' -Level Warning } | Should -Not -Throw
    }

    It 'Should not throw for Error level' {
        { Write-SecurityLog -Message 'Test error' -Level Error } | Should -Not -Throw
    }

    It 'Should not throw for Success level' {
        { Write-SecurityLog -Message 'Test success' -Level Success } | Should -Not -Throw
    }
}

Describe 'Test-WorkflowPermissions' -Tag 'Unit' {
    BeforeAll {
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

    Context 'File with top-level permissions block' {
        It 'Should return null for workflow with permissions' {
            $testPath = Join-Path $TestDrive 'with-permissions'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Copy-Item -Path (Join-Path $script:FixturesPath 'workflow-with-permissions.yml') -Destination $testPath

            $filePath = Join-Path $testPath 'workflow-with-permissions.yml'
            $result = Test-WorkflowPermissions -FilePath $filePath

            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Four-state classification matrix' {
        It 'Row 1: absent workflow-level and absent job-level yields a file-level violation' {
            $testPath = Join-Path $TestDrive 'matrix-row1'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Copy-Item -Path (Join-Path $script:FixturesPath 'workflow-without-permissions.yml') -Destination $testPath

            $result = @(Test-WorkflowPermissions -FilePath (Join-Path $testPath 'workflow-without-permissions.yml'))

            $result | Should -HaveCount 1
            $result[0].ViolationType | Should -Be 'MissingPermissions'
        }

        It 'Row 2: empty workflow-level and absent job-level yields no violation' {
            $testPath = Join-Path $TestDrive 'matrix-row2'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Copy-Item -Path (Join-Path $script:FixturesPath 'workflow-empty-permissions.yml') -Destination $testPath

            $result = @(Test-WorkflowPermissions -FilePath (Join-Path $testPath 'workflow-empty-permissions.yml'))

            $result | Should -HaveCount 0
        }

        It 'Row 3: populated workflow-level and absent job-level yields a job-level violation' {
            $testPath = Join-Path $TestDrive 'matrix-row3'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Copy-Item -Path (Join-Path $script:FixturesPath 'workflow-job-missing-permissions.yml') -Destination $testPath

            $result = @(Test-WorkflowPermissions -FilePath (Join-Path $testPath 'workflow-job-missing-permissions.yml'))

            $result | Should -HaveCount 1
            $result[0].ViolationType | Should -Be 'MissingJobPermissions'
            $result[0].Name | Should -Be 'build'
            $result[0].Type | Should -Be 'workflow-job-permissions'
            $result[0].Severity | Should -Be 'Medium'
        }

        It 'Row 3: reports the job declaration line rather than line 0' {
            $testPath = Join-Path $TestDrive 'matrix-row3-line'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Copy-Item -Path (Join-Path $script:FixturesPath 'workflow-job-missing-permissions.yml') -Destination $testPath

            $result = @(Test-WorkflowPermissions -FilePath (Join-Path $testPath 'workflow-job-missing-permissions.yml'))

            $result[0].Line | Should -BeGreaterThan 0
        }

        It 'Row 3: ignores a same-named key declared before the jobs block' {
            $filePath = New-TestWorkflow -Name 'duplicate-key-before-jobs' -Content @'
name: Duplicate Key Before Jobs
on:
  workflow_call:
    outputs:
      build:
        description: A key that shares the job name
        value: ${{ jobs.build.outputs.result }}
permissions:
  contents: read
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: echo hello
'@

            $result = @(Test-WorkflowPermissions -FilePath $filePath)
            $rawLines = @((Get-Content -Path $filePath -Raw) -split "\r?\n")

            $result | Should -HaveCount 1
            $rawLines[$result[0].Line - 1] | Should -Match '^\s{2}build\s*:'
        }

        It 'Row 4: populated workflow-level and present job-level yields no violation' {
            $testPath = Join-Path $TestDrive 'matrix-row4'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Copy-Item -Path (Join-Path $script:FixturesPath 'workflow-with-permissions.yml') -Destination $testPath

            $result = @(Test-WorkflowPermissions -FilePath (Join-Path $testPath 'workflow-with-permissions.yml'))

            $result | Should -HaveCount 0
        }
    }

    Context 'Permissions value shapes' {
        It 'Should treat a null-valued permissions block as empty' {
            $filePath = New-TestWorkflow -Name 'null-permissions' -Content @'
name: Null Permissions
on: push
permissions:
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: echo hello
'@

            $result = @(Test-WorkflowPermissions -FilePath $filePath)

            $result | Should -HaveCount 0
        }

        It 'Should treat flow-style empty permissions as empty' {
            $filePath = New-TestWorkflow -Name 'flow-empty-permissions' -Content @'
name: Flow Empty Permissions
on: push
permissions: {}
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: echo hello
'@

            $result = @(Test-WorkflowPermissions -FilePath $filePath)

            $result | Should -HaveCount 0
        }

        It 'Should treat flow-style populated permissions as populated' {
            $filePath = New-TestWorkflow -Name 'flow-populated-permissions' -Content @'
name: Flow Populated Permissions
on: push
permissions: { contents: read }
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: echo hello
'@

            $result = @(Test-WorkflowPermissions -FilePath $filePath)

            $result | Should -HaveCount 1
            $result[0].ViolationType | Should -Be 'MissingJobPermissions'
        }

        It 'Should treat a scalar read-all permissions value as populated' {
            $filePath = New-TestWorkflow -Name 'scalar-permissions' -Content @'
name: Scalar Permissions
on: push
permissions: read-all
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: echo hello
'@

            $result = @(Test-WorkflowPermissions -FilePath $filePath)

            $result | Should -HaveCount 2
            $result.ViolationType | Should -Contain 'MissingJobPermissions'
            $result.ViolationType | Should -Contain 'BroadPermissionsScalar'
        }

        It 'Should enumerate jobs indented with four spaces' {
            $filePath = New-TestWorkflow -Name 'four-space-jobs' -Content @'
name: Four Space Jobs
on: push
permissions:
    contents: read
jobs:
    build:
        runs-on: ubuntu-latest
        steps:
            - run: echo hello
'@

            $result = @(Test-WorkflowPermissions -FilePath $filePath)

            $result | Should -HaveCount 1
            $result[0].Name | Should -Be 'build'
        }
    }

    Context 'Lock-file shape regression' {
        It 'Should not flag a job with no block under an empty workflow-level block' {
            $testPath = Join-Path $TestDrive 'lock-file-shape'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Copy-Item -Path (Join-Path $script:FixturesPath 'workflow-lock-file-shape.yml') -Destination $testPath

            $result = @(Test-WorkflowPermissions -FilePath (Join-Path $testPath 'workflow-lock-file-shape.yml'))

            $result | Should -HaveCount 0
        }

        It 'Should not count a step-level permissions key as a job declaration' {
            $filePath = New-TestWorkflow -Name 'nested-permissions-key' -Content @'
name: Nested Permissions Key
on: push
permissions:
  contents: read
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Render config
        with:
          permissions: read-all
        run: echo hello
'@

            $result = @(Test-WorkflowPermissions -FilePath $filePath)

            $result | Should -HaveCount 1
            $result[0].ViolationType | Should -Be 'MissingJobPermissions'
            $result[0].Name | Should -Be 'build'
        }
    }

    Context 'Permission breadth rules' {
        It 'Should reject a workflow-level write grant' {
            $filePath = New-TestWorkflow -Name 'workflow-level-write' -Content @'
name: Workflow Level Write
on: push
permissions:
  contents: read
  issues: write
jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      issues: write
    steps:
      - run: echo hello
'@

            $result = @(Test-WorkflowPermissions -FilePath $filePath)

            $result | Should -HaveCount 1
            $result[0].ViolationType | Should -Be 'ExcessiveWorkflowPermissions'
            $result[0].Type | Should -Be 'workflow-permissions'
            $result[0].Line | Should -Be 3
        }

        It 'Should reject a workflow-level read grant other than contents' {
            $filePath = New-TestWorkflow -Name 'workflow-level-security-read' -Content @'
name: Workflow Level Security Read
on: push
permissions:
  contents: read
  security-events: read
jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - run: echo hello
'@

            $result = @(Test-WorkflowPermissions -FilePath $filePath)

            $result | Should -HaveCount 1
            $result[0].ViolationType | Should -Be 'ExcessiveWorkflowPermissions'
        }

        It 'Should accept a workflow-level block of only none values' {
            $filePath = New-TestWorkflow -Name 'workflow-level-none' -Content @'
name: Workflow Level None
on: push
permissions:
  contents: none
  issues: none
jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - run: echo hello
'@

            $result = @(Test-WorkflowPermissions -FilePath $filePath)

            $result | Should -HaveCount 0
        }

        It 'Should report a workflow-level write-all only as a broad scalar' {
            $filePath = New-TestWorkflow -Name 'workflow-level-write-all' -Content @'
name: Workflow Level Write All
on: push
permissions: write-all
jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - run: echo hello
'@

            $result = @(Test-WorkflowPermissions -FilePath $filePath)

            $result | Should -HaveCount 1
            $result[0].ViolationType | Should -Be 'BroadPermissionsScalar'
            $result[0].Type | Should -Be 'workflow-permissions'
            $result[0].Metadata.Value | Should -Be 'write-all'
        }

        It 'Should reject a job-level read-all under an empty workflow-level block' {
            $filePath = New-TestWorkflow -Name 'job-level-read-all' -Content @'
name: Job Level Read All
on: push
permissions: {}
jobs:
  build:
    runs-on: ubuntu-latest
    permissions: read-all
    steps:
      - run: echo hello
'@

            $result = @(Test-WorkflowPermissions -FilePath $filePath)

            $result | Should -HaveCount 1
            $result[0].ViolationType | Should -Be 'BroadPermissionsScalar'
            $result[0].Type | Should -Be 'workflow-job-permissions'
            $result[0].Name | Should -Be 'build'
        }

        It 'Should reject a job-level write-all when the workflow-level block is absent' {
            $filePath = New-TestWorkflow -Name 'job-level-write-all-absent' -Content @'
name: Job Level Write All Absent
on: push
jobs:
  build:
    runs-on: ubuntu-latest
    permissions: write-all
    steps:
      - run: echo hello
'@

            $result = @(Test-WorkflowPermissions -FilePath $filePath)

            $result | Should -HaveCount 2
            $result.ViolationType | Should -Contain 'MissingPermissions'
            $result.ViolationType | Should -Contain 'BroadPermissionsScalar'
        }
    }

    Context 'Unrecognized permissions shapes' {
        It 'Should report an unrecognized workflow-level scalar as excessive' {
            $filePath = New-TestWorkflow -Name 'workflow-level-unknown-scalar' -Content @'
name: Workflow Level Unknown Scalar
on: push
permissions: read
jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - run: echo hello
'@

            $result = @(Test-WorkflowPermissions -FilePath $filePath)

            $result | Should -HaveCount 1
            $result[0].ViolationType | Should -Be 'ExcessiveWorkflowPermissions'
            $result[0].Line | Should -Be 3
        }

        It 'Should report a workflow-level sequence as excessive' {
            $filePath = New-TestWorkflow -Name 'workflow-level-sequence' -Content @'
name: Workflow Level Sequence
on: push
permissions:
  - contents
jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - run: echo hello
'@

            $result = @(Test-WorkflowPermissions -FilePath $filePath)

            $result | Should -HaveCount 1
            $result[0].ViolationType | Should -Be 'ExcessiveWorkflowPermissions'
        }

        It 'Should report line 0 when a flow-style document hides the permissions key' {
            $filePath = New-TestWorkflow -Name 'flow-style-document' -Content @'
{name: Flow Style, on: push, permissions: {issues: write}, jobs: {build: {runs-on: ubuntu-latest, permissions: {issues: write}, steps: [{run: echo hello}]}}}
'@

            $result = @(Test-WorkflowPermissions -FilePath $filePath)

            $result | Should -HaveCount 1
            $result[0].ViolationType | Should -Be 'ExcessiveWorkflowPermissions'
            $result[0].Line | Should -Be 0
        }
    }

    Context 'Unparseable workflow' {
        It 'Should return no violations rather than throwing' {
            $filePath = New-TestWorkflow -Name 'malformed' -Content @'
name: Malformed
on: push
permissions:
  contents: read
jobs:
  build:
   - this is not a mapping
     and: [unclosed
'@

            { Test-WorkflowPermissions -FilePath $filePath } | Should -Not -Throw
            @(Test-WorkflowPermissions -FilePath $filePath) | Should -HaveCount 0
        }
    }

    Context 'File with empty permissions block' {
        It 'Should return null for workflow with empty permissions' {
            $testPath = Join-Path $TestDrive 'empty-permissions'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Copy-Item -Path (Join-Path $script:FixturesPath 'workflow-empty-permissions.yml') -Destination $testPath

            $filePath = Join-Path $testPath 'workflow-empty-permissions.yml'
            $result = Test-WorkflowPermissions -FilePath $filePath

            $result | Should -BeNullOrEmpty
        }
    }

    Context 'File without permissions block' {
        It 'Should return a violation' {
            $testPath = Join-Path $TestDrive 'without-permissions'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Copy-Item -Path (Join-Path $script:FixturesPath 'workflow-without-permissions.yml') -Destination $testPath

            $filePath = Join-Path $testPath 'workflow-without-permissions.yml'
            $result = Test-WorkflowPermissions -FilePath $filePath

            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should set ViolationType to MissingPermissions' {
            $testPath = Join-Path $TestDrive 'without-permissions-type'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Copy-Item -Path (Join-Path $script:FixturesPath 'workflow-without-permissions.yml') -Destination $testPath

            $filePath = Join-Path $testPath 'workflow-without-permissions.yml'
            $result = Test-WorkflowPermissions -FilePath $filePath

            $result.ViolationType | Should -Be 'MissingPermissions'
        }

        It 'Should set Severity to High' {
            $testPath = Join-Path $TestDrive 'without-permissions-sev'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Copy-Item -Path (Join-Path $script:FixturesPath 'workflow-without-permissions.yml') -Destination $testPath

            $filePath = Join-Path $testPath 'workflow-without-permissions.yml'
            $result = Test-WorkflowPermissions -FilePath $filePath

            $result.Severity | Should -Be 'High'
        }

        It 'Should set Type to workflow-permissions' {
            $testPath = Join-Path $TestDrive 'without-permissions-wftype'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Copy-Item -Path (Join-Path $script:FixturesPath 'workflow-without-permissions.yml') -Destination $testPath

            $filePath = Join-Path $testPath 'workflow-without-permissions.yml'
            $result = Test-WorkflowPermissions -FilePath $filePath

            $result.Type | Should -Be 'workflow-permissions'
        }

        It 'Should set Line to 0 for file-level violation' {
            $testPath = Join-Path $TestDrive 'without-permissions-line'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Copy-Item -Path (Join-Path $script:FixturesPath 'workflow-without-permissions.yml') -Destination $testPath

            $filePath = Join-Path $testPath 'workflow-without-permissions.yml'
            $result = Test-WorkflowPermissions -FilePath $filePath

            $result.Line | Should -Be 0
        }

        It 'Should include FullPath in Metadata' {
            $testPath = Join-Path $TestDrive 'without-permissions-meta'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Copy-Item -Path (Join-Path $script:FixturesPath 'workflow-without-permissions.yml') -Destination $testPath

            $filePath = Join-Path $testPath 'workflow-without-permissions.yml'
            $result = Test-WorkflowPermissions -FilePath $filePath

            $result.Metadata.FullPath | Should -Be $filePath
        }
    }
}

Describe 'Get-BroadPermissionsScalar' -Tag 'Unit' {
    It 'Should return <Expected> for <Description>' -ForEach @(
        @{ Description = 'read-all'; Node = 'read-all'; Expected = 'read-all' }
        @{ Description = 'mixed-case write-all with whitespace'; Node = ' Write-All '; Expected = 'write-all' }
        @{ Description = 'an unrecognized scalar'; Node = 'read'; Expected = '' }
        @{ Description = 'null'; Node = $null; Expected = '' }
    ) {
        Get-BroadPermissionsScalar -Node $Node | Should -BeExactly $Expected
    }

    It 'Should return an empty string for a mapping' {
        Get-BroadPermissionsScalar -Node @{ contents = 'read' } | Should -BeExactly ''
    }
}

Describe 'Test-NarrowWorkflowPermission' -Tag 'Unit' {
    It 'Should return <Expected> for <Description>' -ForEach @(
        @{ Description = 'null'; Node = $null; Expected = $true }
        @{ Description = 'a blank scalar'; Node = '  '; Expected = $true }
        @{ Description = 'a non-blank scalar'; Node = 'read'; Expected = $false }
    ) {
        Test-NarrowWorkflowPermission -Node $Node | Should -Be $Expected
    }

    It 'Should return true for an empty mapping' {
        Test-NarrowWorkflowPermission -Node @{} | Should -BeTrue
    }

    It 'Should return true for contents read with none entries' {
        Test-NarrowWorkflowPermission -Node @{ contents = 'Read'; issues = 'none' } | Should -BeTrue
    }

    It 'Should return false for any other scope' {
        Test-NarrowWorkflowPermission -Node @{ contents = 'read'; 'security-events' = 'read' } | Should -BeFalse
    }

    It 'Should return false for a sequence' {
        Test-NarrowWorkflowPermission -Node @('contents') | Should -BeFalse
    }
}

Describe 'Get-TopLevelKeyLine' -Tag 'Unit' {
    It 'Should return the 1-based line of an unindented key' {
        Get-TopLevelKeyLine -RawLines @('name: x', 'permissions:', '  contents: read') -Key 'permissions' | Should -Be 2
    }

    It 'Should match a quoted key' {
        Get-TopLevelKeyLine -RawLines @('name: x', '"permissions": {}') -Key 'permissions' | Should -Be 2
    }

    It 'Should ignore an indented key' {
        Get-TopLevelKeyLine -RawLines @('jobs:', '  build:', '    permissions: {}') -Key 'permissions' | Should -Be 0
    }

    It 'Should return 0 when the key is absent' {
        Get-TopLevelKeyLine -RawLines @() -Key 'permissions' | Should -Be 0
    }
}

Describe 'ConvertTo-PermissionsSarif' -Tag 'Unit' {
    Context 'With violations' {
        It 'Should produce valid SARIF structure' {
            $violation = [DependencyViolation]::new()
            $violation.File = 'test.yml'
            $violation.Line = 0
            $violation.Type = 'workflow-permissions'
            $violation.Name = 'test.yml'
            $violation.Severity = 'High'
            $violation.ViolationType = 'MissingPermissions'
            $violation.Description = 'Missing top-level permissions'
            $violation.Remediation = 'Add permissions block'

            $sarif = ConvertTo-PermissionsSarif -Violations @($violation)

            $sarif.'$schema' | Should -Not -BeNullOrEmpty
            $sarif.version | Should -Be '2.1.0'
            $sarif.runs | Should -HaveCount 1
            $sarif.runs[0].tool.driver.name | Should -Be 'Test-WorkflowPermissions'
        }

        It 'Should include missing-permissions rule' {
            $violation = [DependencyViolation]::new()
            $violation.File = 'test.yml'
            $violation.Line = 0
            $violation.Type = 'workflow-permissions'
            $violation.Name = 'test.yml'
            $violation.Severity = 'High'
            $violation.ViolationType = 'MissingPermissions'
            $violation.Description = 'Missing top-level permissions'
            $violation.Remediation = 'Add permissions block'

            $sarif = ConvertTo-PermissionsSarif -Violations @($violation)

            $sarif.runs[0].tool.driver.rules[0].id | Should -Be 'missing-permissions'
            $sarif.runs[0].results | Should -HaveCount 1
        }
    }

    Context 'Without violations' {
        It 'Should produce valid SARIF with empty results' {
            $sarif = ConvertTo-PermissionsSarif -Violations @()

            $sarif.version | Should -Be '2.1.0'
            $sarif.runs[0].results | Should -HaveCount 0
        }
    }

    Context 'SARIF document contract' {
        BeforeAll {
            $fileLevel = [DependencyViolation]::new()
            $fileLevel.File = '.github/workflows/no-permissions.yml'
            $fileLevel.Line = 0
            $fileLevel.Type = 'workflow-permissions'
            $fileLevel.Name = 'no-permissions.yml'
            $fileLevel.Severity = 'High'
            $fileLevel.ViolationType = 'MissingPermissions'
            $fileLevel.Description = 'Missing top-level permissions'
            $fileLevel.Remediation = 'Add permissions block'

            $jobLevel = [DependencyViolation]::new()
            $jobLevel.File = '.github/workflows/inherits.yml'
            $jobLevel.Line = 18
            $jobLevel.Type = 'workflow-job-permissions'
            $jobLevel.Name = 'evaluate'
            $jobLevel.Severity = 'Medium'
            $jobLevel.ViolationType = 'MissingJobPermissions'
            $jobLevel.Description = 'Missing job permissions'
            $jobLevel.Remediation = 'Add job permissions block'

            $script:ContractSarif = ConvertTo-PermissionsSarif -Violations @($fileLevel, $jobLevel)
        }

        It 'Should declare a rule for every emitted ruleId' {
            $declared = $script:ContractSarif.runs[0].tool.driver.rules | ForEach-Object { $_.id }

            foreach ($result in $script:ContractSarif.runs[0].results) {
                $declared | Should -Contain $result.ruleId
            }
        }

        It 'Should route each violation type to its own rule' {
            $ruleIds = $script:ContractSarif.runs[0].results | ForEach-Object { $_.ruleId }

            $ruleIds | Should -Contain 'missing-permissions'
            $ruleIds | Should -Contain 'missing-job-permissions'
        }

        It 'Should never emit a startLine below 1' {
            foreach ($result in $script:ContractSarif.runs[0].results) {
                $result.locations[0].physicalLocation.region.startLine | Should -BeGreaterOrEqual 1
            }
        }

        It 'Should route breadth violations to their own declared rules' {
            $excessive = [DependencyViolation]::new()
            $excessive.File = '.github/workflows/broad.yml'
            $excessive.Line = 3
            $excessive.Type = 'workflow-permissions'
            $excessive.Name = 'broad.yml'
            $excessive.Severity = 'Medium'
            $excessive.ViolationType = 'ExcessiveWorkflowPermissions'
            $excessive.Description = 'Workflow-level grant beyond contents: read'
            $excessive.Remediation = 'Move scopes to jobs'

            $scalar = [DependencyViolation]::new()
            $scalar.File = '.github/workflows/broad.yml'
            $scalar.Line = 8
            $scalar.Type = 'workflow-job-permissions'
            $scalar.Name = 'build'
            $scalar.Severity = 'High'
            $scalar.ViolationType = 'BroadPermissionsScalar'
            $scalar.Description = 'Job uses read-all'
            $scalar.Remediation = 'Declare specific scopes'

            $sarif = ConvertTo-PermissionsSarif -Violations @($excessive, $scalar)
            $declared = $sarif.runs[0].tool.driver.rules | ForEach-Object { $_.id }
            $emitted = $sarif.runs[0].results | ForEach-Object { $_.ruleId }

            $emitted | Should -Contain 'excessive-workflow-permissions'
            $emitted | Should -Contain 'broad-permissions-scalar'
            foreach ($ruleId in $emitted) {
                $declared | Should -Contain $ruleId
            }
        }
    }
}

Describe 'Invoke-WorkflowPermissionsCheck' -Tag 'Integration' {
    BeforeAll {
        Mock Write-CIAnnotation { } -ModuleName CIHelpers
        Mock Write-Host { }
    }

    Context 'Scanning directory with mixed workflows' {
        It 'Should detect missing permissions' {
            $testPath = Join-Path $TestDrive 'mixed-scan'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Copy-Item -Path (Join-Path $script:FixturesPath 'workflow-with-permissions.yml') -Destination $testPath
            Copy-Item -Path (Join-Path $script:FixturesPath 'workflow-without-permissions.yml') -Destination $testPath

            $outputPath = Join-Path $TestDrive 'mixed-results.json'

            $exitCode = Invoke-WorkflowPermissionsCheck -Path $testPath -OutputPath $outputPath

            $exitCode | Should -Be 0
            Test-Path $outputPath | Should -BeTrue
        }

        It 'Should fail with FailOnViolation when violations exist' {
            $testPath = Join-Path $TestDrive 'fail-scan'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Copy-Item -Path (Join-Path $script:FixturesPath 'workflow-without-permissions.yml') -Destination $testPath

            $outputPath = Join-Path $TestDrive 'fail-results.json'

            $exitCode = Invoke-WorkflowPermissionsCheck -Path $testPath -OutputPath $outputPath -FailOnViolation

            $exitCode | Should -Be 1
        }

        It 'Should return exit code 0 when all workflows have permissions' {
            $testPath = Join-Path $TestDrive 'pass-scan'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Copy-Item -Path (Join-Path $script:FixturesPath 'workflow-with-permissions.yml') -Destination $testPath

            $outputPath = Join-Path $TestDrive 'pass-results.json'

            $exitCode = Invoke-WorkflowPermissionsCheck -Path $testPath -OutputPath $outputPath -FailOnViolation

            $exitCode | Should -Be 0
        }
    }

    Context 'Job-level reporting' {
        It 'Should fail when a job omits its own permissions block' {
            $testPath = Join-Path $TestDrive 'job-level-fail'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Copy-Item -Path (Join-Path $script:FixturesPath 'workflow-job-missing-permissions.yml') -Destination $testPath

            $outputPath = Join-Path $TestDrive 'job-level-fail.json'

            $exitCode = Invoke-WorkflowPermissionsCheck -Path $testPath -OutputPath $outputPath -FailOnViolation

            $exitCode | Should -Be 1
        }

        It 'Should report file-level and job-level metrics separately' {
            $testPath = Join-Path $TestDrive 'job-level-metrics'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Copy-Item -Path (Join-Path $script:FixturesPath 'workflow-job-missing-permissions.yml') -Destination $testPath

            $outputPath = Join-Path $TestDrive 'job-level-metrics.json'

            Invoke-WorkflowPermissionsCheck -Path $testPath -OutputPath $outputPath

            $content = Get-Content $outputPath -Raw | ConvertFrom-Json
            $content.Metadata.FileChecks | Should -Be 1
            $content.Metadata.FilesWithPermissions | Should -Be 1
            $content.Metadata.FileLevelViolations | Should -Be 0
            $content.Metadata.JobChecks | Should -Be 2
            $content.Metadata.JobsPassing | Should -Be 1
            $content.Metadata.JobsDeclaringOwnBlock | Should -Be 1
            $content.Metadata.JobLevelViolations | Should -Be 1
        }

        It 'Should not credit a job passing by empty-block inheritance as declaring its own block' {
            $testPath = Join-Path $TestDrive 'inherited-not-declared'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Copy-Item -Path (Join-Path $script:FixturesPath 'workflow-lock-file-shape.yml') -Destination $testPath

            $outputPath = Join-Path $TestDrive 'inherited-not-declared.json'

            Invoke-WorkflowPermissionsCheck -Path $testPath -OutputPath $outputPath

            $content = Get-Content $outputPath -Raw | ConvertFrom-Json
            # Both jobs pass, but only 'agent' declares a block; 'pre_activation' passes
            # by inheriting an empty workflow-level grant.
            $content.Metadata.JobChecks | Should -Be 2
            $content.Metadata.JobsPassing | Should -Be 2
            $content.Metadata.JobsDeclaringOwnBlock | Should -Be 1
            $content.Metadata.JobLevelViolations | Should -Be 0
        }

        It 'Should count breadth violations and exclude them from passing checks' {
            $testPath = Join-Path $TestDrive 'breadth-metrics'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Set-Content -Path (Join-Path $testPath 'broad.yml') -Encoding utf8 -Value @'
name: Broad
on: push
permissions:
  contents: read
  issues: write
jobs:
  build:
    runs-on: ubuntu-latest
    permissions: read-all
    steps:
      - run: echo hello
  lint:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - run: echo hello
'@

            $outputPath = Join-Path $TestDrive 'breadth-metrics.json'

            $exitCode = Invoke-WorkflowPermissionsCheck -Path $testPath -OutputPath $outputPath -FailOnViolation

            $exitCode | Should -Be 1
            $content = Get-Content $outputPath -Raw | ConvertFrom-Json
            $content.Metadata.FilesWithPermissions | Should -Be 1
            $content.Metadata.FilesPassing | Should -Be 0
            $content.Metadata.ExcessiveWorkflowPermissionViolations | Should -Be 1
            $content.Metadata.BroadPermissionsScalarViolations | Should -Be 1
            $content.Metadata.JobChecks | Should -Be 2
            $content.Metadata.JobsPassing | Should -Be 1
        }

        It 'Should report an unparseable workflow without counting it as compliant' {
            $testPath = Join-Path $TestDrive 'unparseable-scan'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Set-Content -Path (Join-Path $testPath 'malformed.yml') -Encoding utf8 -Value @'
name: Malformed
on: push
jobs:
  build:
   - this is not a mapping
     and: [unclosed
'@

            $outputPath = Join-Path $TestDrive 'unparseable-scan.json'

            $exitCode = Invoke-WorkflowPermissionsCheck -Path $testPath -OutputPath $outputPath -FailOnViolation

            $exitCode | Should -Be 1
            $content = Get-Content $outputPath -Raw | ConvertFrom-Json
            $content.Metadata.UnparsedFiles | Should -Be 1
            $content.Metadata.FilesWithPermissions | Should -Be 0
            @($content.Violations).Count | Should -Be 1
            $content.Violations[0].ViolationType | Should -Be 'MissingPermissions'
        }

        It 'Should emit violation paths with forward slashes only' {
            $testPath = Join-Path $TestDrive 'path-separator'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Copy-Item -Path (Join-Path $script:FixturesPath 'workflow-job-missing-permissions.yml') -Destination $testPath
            Copy-Item -Path (Join-Path $script:FixturesPath 'workflow-without-permissions.yml') -Destination $testPath

            $outputPath = Join-Path $TestDrive 'path-separator.json'

            Invoke-WorkflowPermissionsCheck -Path $testPath -OutputPath $outputPath

            $content = Get-Content $outputPath -Raw | ConvertFrom-Json
            @($content.Violations).Count | Should -BeGreaterThan 0
            foreach ($violation in $content.Violations) {
                # SARIF artifactLocation.uri must not contain Windows path separators.
                $violation.File | Should -Not -Match '\\'
            }
        }
    }

    Context 'Exclusion filtering' {
        It 'Should exclude specified files' {
            $testPath = Join-Path $TestDrive 'exclude-scan'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Copy-Item -Path (Join-Path $script:FixturesPath 'workflow-without-permissions.yml') -Destination $testPath

            $outputPath = Join-Path $TestDrive 'exclude-results.json'

            $exitCode = Invoke-WorkflowPermissionsCheck -Path $testPath -OutputPath $outputPath -ExcludePaths 'workflow-without-permissions.yml' -FailOnViolation

            $exitCode | Should -Be 0
        }
    }

    Context 'Output formats' {
        It 'Should produce SARIF output' {
            $testPath = Join-Path $TestDrive 'sarif-scan'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Copy-Item -Path (Join-Path $script:FixturesPath 'workflow-without-permissions.yml') -Destination $testPath

            $outputPath = Join-Path $TestDrive 'sarif-results.json'

            Invoke-WorkflowPermissionsCheck -Path $testPath -Format sarif -OutputPath $outputPath

            $content = Get-Content $outputPath -Raw | ConvertFrom-Json
            $content.version | Should -Be '2.1.0'
            $content.'$schema' | Should -Not -BeNullOrEmpty
        }

        It 'Should produce console output when workflows are missing permissions' {
            $testPath = Join-Path $TestDrive 'console-violation-scan'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Copy-Item -Path (Join-Path $script:FixturesPath 'workflow-without-permissions.yml') -Destination $testPath

            $outputPath = Join-Path $TestDrive 'console-results.txt'

            Invoke-WorkflowPermissionsCheck -Path $testPath -Format console -OutputPath $outputPath

            $content = Get-Content $outputPath -Raw
            $content | Should -Match 'Workflow permissions violations found'
            $content | Should -Match 'Remediation'
        }

        It 'Should produce JSON output by default' {
            $testPath = Join-Path $TestDrive 'json-scan'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Copy-Item -Path (Join-Path $script:FixturesPath 'workflow-with-permissions.yml') -Destination $testPath

            $outputPath = Join-Path $TestDrive 'json-results.json'

            Invoke-WorkflowPermissionsCheck -Path $testPath -OutputPath $outputPath

            $content = Get-Content $outputPath -Raw | ConvertFrom-Json
            $content.ScanPath | Should -Not -BeNullOrEmpty
        }
    }
}
