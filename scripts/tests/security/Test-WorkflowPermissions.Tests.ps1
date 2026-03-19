#Requires -Modules Pester

# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

using module ../../security/Modules/SecurityClasses.psm1

BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '../../security/Test-WorkflowPermissions.ps1'
    . $scriptPath

    Import-Module (Join-Path $PSScriptRoot '../Mocks/GitMocks.psm1') -Force
    Save-CIEnvironment

    $script:FixturesPath = Join-Path $PSScriptRoot '../Fixtures/Workflows'
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
