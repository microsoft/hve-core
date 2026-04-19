#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    # Stub external tools when not installed so Pester can mock them
    if (-not (Get-Command uv -ErrorAction SilentlyContinue)) { function global:uv { } }
    if (-not (Get-Command uvx -ErrorAction SilentlyContinue)) { function global:uvx { } }

    . $PSScriptRoot/../../security/Invoke-PipAudit.ps1
    Import-Module (Join-Path $PSScriptRoot '../../lib/Modules/CIHelpers.psm1') -Force

    $mockPath = Join-Path $PSScriptRoot '../Mocks/GitMocks.psm1'
    Import-Module $mockPath -Force

    # CI helper mocks — suppress console output and enable assertions
    Mock Write-Host {}
    Mock Write-CIAnnotation {}
    Mock Write-CIStepSummary {}
}

Describe 'Find-PythonProjects' -Tag 'Unit' {
    Context 'Project discovery' {
        It 'Finds Python projects with pyproject.toml' {
            $testDir = Join-Path $TestDrive 'projects'
            New-Item -ItemType Directory -Path "$testDir/skill-a" -Force | Out-Null
            New-Item -ItemType File -Path "$testDir/skill-a/pyproject.toml" -Force | Out-Null

            $projects = @(Find-PythonProjects -SearchPath $testDir)

            $projects.Count | Should -Be 1
            $projects[0] | Should -BeLike "*skill-a*"
        }

        It 'Excludes node_modules directories' {
            $testDir = Join-Path $TestDrive 'nm-test'
            New-Item -ItemType Directory -Path "$testDir/node_modules/pkg" -Force | Out-Null
            New-Item -ItemType File -Path "$testDir/node_modules/pkg/pyproject.toml" -Force | Out-Null

            $projects = Find-PythonProjects -SearchPath $testDir

            $projects.Count | Should -Be 0
        }

        It 'Returns empty when no projects found' {
            $testDir = Join-Path $TestDrive 'empty'
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null

            $projects = Find-PythonProjects -SearchPath $testDir

            $projects.Count | Should -Be 0
        }

        It 'Excludes paths matching exclude patterns' {
            $testDir = Join-Path $TestDrive 'exclude-test'
            New-Item -ItemType Directory -Path "$testDir/include-me" -Force | Out-Null
            New-Item -ItemType File -Path "$testDir/include-me/pyproject.toml" -Force | Out-Null
            New-Item -ItemType Directory -Path "$testDir/skip-me" -Force | Out-Null
            New-Item -ItemType File -Path "$testDir/skip-me/pyproject.toml" -Force | Out-Null

            $projects = @(Find-PythonProjects -SearchPath $testDir -Exclude @('skip-me'))

            $projects.Count | Should -Be 1
            $projects[0] | Should -BeLike "*include-me*"
        }

        It 'Finds multiple projects sorted' {
            $testDir = Join-Path $TestDrive 'multi'
            New-Item -ItemType Directory -Path "$testDir/z-skill" -Force | Out-Null
            New-Item -ItemType File -Path "$testDir/z-skill/pyproject.toml" -Force | Out-Null
            New-Item -ItemType Directory -Path "$testDir/a-skill" -Force | Out-Null
            New-Item -ItemType File -Path "$testDir/a-skill/pyproject.toml" -Force | Out-Null

            $projects = Find-PythonProjects -SearchPath $testDir

            $projects.Count | Should -Be 2
            $projects[0] | Should -BeLike "*a-skill*"
            $projects[1] | Should -BeLike "*z-skill*"
        }
    }
}

Describe 'Invoke-PipAuditForProject' -Tag 'Unit' {
    Context 'Audit execution' {
        It 'Runs uv export and pip-audit for a project' {
            $testDir = Join-Path $TestDrive 'audit-test'
            $outputDir = Join-Path $TestDrive 'audit-output'
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

            Mock uv {}
            Mock uvx {}
            $global:LASTEXITCODE = 0

            $result = Invoke-PipAuditForProject -ProjectPath $testDir -OutputPath $outputDir

            $result | Should -Be $false
            Should -Invoke uv -Times 1
            Should -Invoke uvx -Times 1
        }

        It 'Returns true when vulnerabilities are found' {
            $testDir = Join-Path $TestDrive 'vuln-test'
            $outputDir = Join-Path $TestDrive 'vuln-output'
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

            Mock uv {}
            Mock uvx { $global:LASTEXITCODE = 1 }

            $result = Invoke-PipAuditForProject -ProjectPath $testDir -OutputPath $outputDir

            $result | Should -Be $true
        }
    }
}

Describe 'Start-PipAudit' -Tag 'Unit' {
    Context 'Orchestration' {
        It 'Returns 0 when no projects found' {
            Mock Find-PythonProjects { @() }

            $result = Start-PipAudit -SearchPath $TestDrive -OutputPath (Join-Path $TestDrive 'out-none')

            $result | Should -Be 0
            Should -Invoke Write-Host -ParameterFilter { $Object -eq 'No Python projects found' }
        }

        It 'Audits all discovered projects and returns 0 when clean' {
            $outputDir = Join-Path $TestDrive 'out-clean'
            Mock Find-PythonProjects { @("$TestDrive/proj-a", "$TestDrive/proj-b") }
            Mock Invoke-PipAuditForProject { $false }

            $result = Start-PipAudit -SearchPath $TestDrive -OutputPath $outputDir

            $result | Should -Be 0
            Should -Invoke Invoke-PipAuditForProject -Times 2 -Exactly
        }

        It 'Returns 1 when vulnerabilities found and FailOnVulnerability set' {
            $outputDir = Join-Path $TestDrive 'out-vuln-fail'
            Mock Find-PythonProjects { @("$TestDrive/proj-a") }
            Mock Invoke-PipAuditForProject { $true }

            $result = Start-PipAudit -SearchPath $TestDrive -OutputPath $outputDir -FailOnVulnerability

            $result | Should -Be 1
            Should -Invoke Write-Host -ParameterFilter { $Object -like '::error::*' }
        }

        It 'Returns 0 when vulnerabilities found without FailOnVulnerability' {
            $outputDir = Join-Path $TestDrive 'out-vuln-nofail'
            Mock Find-PythonProjects { @("$TestDrive/proj-a") }
            Mock Invoke-PipAuditForProject { $true }

            $result = Start-PipAudit -SearchPath $TestDrive -OutputPath $outputDir

            $result | Should -Be 0
            Should -Not -Invoke Write-Host -ParameterFilter { $Object -like '::error::*' }
        }
    }
}
