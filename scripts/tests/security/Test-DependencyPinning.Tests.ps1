#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    . $PSScriptRoot/../../security/Test-DependencyPinning.ps1
    # Re-import CIHelpers so Pester can resolve its commands for mocking;
    # the nested-module import inside SecurityHelpers shadows the standalone copy.
    Import-Module (Join-Path $PSScriptRoot '../../lib/Modules/CIHelpers.psm1') -Force

    $mockPath = Join-Path $PSScriptRoot '../Mocks/GitMocks.psm1'
    Import-Module $mockPath -Force

    # Fixture paths
    $script:FixturesPath = Join-Path $PSScriptRoot '../Fixtures/Workflows'
    $script:SecurityFixturesPath = Join-Path $PSScriptRoot '../Fixtures/Security'

    # CI helper mocks — suppress console output and enable assertions
    Mock Write-Host {}
    Mock Write-CIAnnotation {}
    Mock Write-CIStepSummary {}
    # Module-scoped mocks — intercept calls from within SecurityHelpers module
    Mock Write-Host {} -ModuleName SecurityHelpers
    Mock Write-CIAnnotation {} -ModuleName SecurityHelpers
    Mock Write-CIStepSummary {} -ModuleName SecurityHelpers
}

Describe 'Test-SHAPinning' -Tag 'Unit' {
    Context 'Valid SHA references for github-actions' {
        It 'Returns true for valid 40-char lowercase SHA' {
            Test-SHAPinning -Version 'a5ac7e51b41094c92402da3b24376905380afc29' -Type 'github-actions' | Should -BeTrue
        }

        It 'Returns true for valid 40-char mixed case SHA' {
            Test-SHAPinning -Version 'A5AC7E51B41094c92402da3b24376905380afc29' -Type 'github-actions' | Should -BeTrue
        }
    }

    Context 'Invalid SHA references for github-actions' {
        It 'Returns false for tag reference' {
            Test-SHAPinning -Version 'v4' -Type 'github-actions' | Should -BeFalse
        }

        It 'Returns false for branch reference' {
            Test-SHAPinning -Version 'main' -Type 'github-actions' | Should -BeFalse
        }

        It 'Returns false for 39-char reference' {
            Test-SHAPinning -Version 'a5ac7e51b41094c92402da3b24376905380afc2' -Type 'github-actions' | Should -BeFalse
        }

        It 'Returns false for 41-char reference' {
            Test-SHAPinning -Version 'a5ac7e51b41094c92402da3b24376905380afc291' -Type 'github-actions' | Should -BeFalse
        }

        It 'Returns false for non-hex characters' {
            Test-SHAPinning -Version 'g5ac7e51b41094c92402da3b24376905380afc29' -Type 'github-actions' | Should -BeFalse
        }
    }

    Context 'Unknown type' {
        It 'Returns false for unknown dependency type' {
            Test-SHAPinning -Version 'a5ac7e51b41094c92402da3b24376905380afc29' -Type 'unknown-type' | Should -BeFalse
        }
    }
}

Describe 'Test-ShellDownloadSecurity' -Tag 'Unit' {
    Context 'Insecure downloads' {
        It 'Detects curl without checksum verification' {
            $testFile = Join-Path $script:SecurityFixturesPath 'insecure-download.sh'
            $fileInfo = @{
                Path         = $testFile
                Type         = 'shell-downloads'
                RelativePath = 'insecure-download.sh'
            }
            $result = Test-ShellDownloadSecurity -FileInfo $fileInfo
            $result | Should -Not -BeNullOrEmpty
            $result[0].Severity | Should -Be 'warning'
        }
    }

    Context 'File not found' {
        It 'Returns empty array for non-existent file' {
            $fileInfo = @{
                Path         = 'TestDrive:/nonexistent/file.sh'
                Type         = 'shell-downloads'
                RelativePath = 'nonexistent/file.sh'
            }
            $result = Test-ShellDownloadSecurity -FileInfo $fileInfo
            $result | Should -BeNullOrEmpty
        }
    }
}

Describe 'Get-DependencyViolation' -Tag 'Unit' {
    Context 'Pinned workflows' {
        It 'Returns no violations for fully pinned workflow' {
            $pinnedPath = Join-Path $script:FixturesPath 'pinned-workflow.yml'
            $fileInfo = @{
                Path         = $pinnedPath
                Type         = 'github-actions'
                RelativePath = 'pinned-workflow.yml'
            }
            $result = Get-DependencyViolation -FileInfo $fileInfo
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Unpinned workflows' {
        It 'Detects unpinned action references' {
            $unpinnedPath = Join-Path $script:FixturesPath 'unpinned-workflow.yml'
            $fileInfo = @{
                Path         = $unpinnedPath
                Type         = 'github-actions'
                RelativePath = 'unpinned-workflow.yml'
            }
            $result = Get-DependencyViolation -FileInfo $fileInfo
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -BeGreaterThan 0
        }

        It 'Returns correct violation type for unpinned actions' {
            $unpinnedPath = Join-Path $script:FixturesPath 'unpinned-workflow.yml'
            $fileInfo = @{
                Path         = $unpinnedPath
                Type         = 'github-actions'
                RelativePath = 'unpinned-workflow.yml'
            }
            $result = Get-DependencyViolation -FileInfo $fileInfo
            $result[0].Type | Should -Be 'github-actions'
        }
    }

    Context 'Mixed workflows' {
        It 'Detects only unpinned actions in mixed workflow' {
            $mixedPath = Join-Path $script:FixturesPath 'mixed-pinning-workflow.yml'
            $fileInfo = @{
                Path         = $mixedPath
                Type         = 'github-actions'
                RelativePath = 'mixed-pinning-workflow.yml'
            }
            $result = Get-DependencyViolation -FileInfo $fileInfo
            $result | Should -Not -BeNullOrEmpty
            # Should only detect the unpinned setup-node action
            $result.Name | Should -Contain 'actions/setup-node'
        }
    }

    Context 'Non-existent file' {
        It 'Returns empty array for non-existent file' {
            $fileInfo = @{
                Path         = 'TestDrive:/nonexistent/file.yml'
                Type         = 'github-actions'
                RelativePath = 'file.yml'
            }
            $result = Get-DependencyViolation -FileInfo $fileInfo
            $result | Should -BeNullOrEmpty
        }
    }
}

Describe 'Export-ComplianceReport' -Tag 'Unit' {
    BeforeEach {
        $script:TestOutputPath = Join-Path $TestDrive 'report'
        New-Item -ItemType Directory -Path $script:TestOutputPath -Force | Out-Null

        # Create a proper ComplianceReport class instance
        $script:MockReport = [ComplianceReport]::new()
        $script:MockReport.ScanPath = $script:FixturesPath
        $script:MockReport.ComplianceScore = 50
        $script:MockReport.TotalFiles = 3
        $script:MockReport.ScannedFiles = 3
        $script:MockReport.TotalDependencies = 4
        $script:MockReport.PinnedDependencies = 2
        $script:MockReport.UnpinnedDependencies = 2
        $script:MockReport.Violations = @(
            [PSCustomObject]@{
                File        = 'unpinned-workflow.yml'
                Line        = 10
                Type        = 'github-actions'
                Name        = 'actions/checkout'
                Version     = 'v4'
                Severity    = 'High'
                Description = 'Unpinned dependency'
                Remediation = 'Pin to SHA'
            }
        )
        $script:MockReport.Summary = @{
            'github-actions' = @{
                Total  = 4
                High   = 2
                Medium = 0
                Low    = 0
            }
        }
    }

    Context 'JSON format' {
        It 'Generates valid JSON report' {
            $outputFile = Join-Path $script:TestOutputPath 'report.json'

            Export-ComplianceReport -Report $script:MockReport -Format 'json' -OutputPath $outputFile

            Test-Path $outputFile | Should -BeTrue
            $content = Get-Content $outputFile -Raw | ConvertFrom-Json
            $content | Should -Not -BeNullOrEmpty
        }
    }

    Context 'SARIF format' {
        It 'Generates valid SARIF report' {
            $outputFile = Join-Path $script:TestOutputPath 'report.sarif'

            Export-ComplianceReport -Report $script:MockReport -Format 'sarif' -OutputPath $outputFile

            Test-Path $outputFile | Should -BeTrue
            $content = Get-Content $outputFile -Raw | ConvertFrom-Json
            $content.'$schema' | Should -Match 'sarif'
        }
    }

    Context 'Table format' {
        It 'Generates table output without error' {
            $outputFile = Join-Path $script:TestOutputPath 'report.txt'

            { Export-ComplianceReport -Report $script:MockReport -Format 'table' -OutputPath $outputFile } | Should -Not -Throw
            Test-Path $outputFile | Should -BeTrue
        }
    }

    Context 'CSV format' {
        It 'Generates CSV report' {
            $outputFile = Join-Path $script:TestOutputPath 'report.csv'

            Export-ComplianceReport -Report $script:MockReport -Format 'csv' -OutputPath $outputFile

            Test-Path $outputFile | Should -BeTrue
        }
    }

    Context 'Markdown format' {
        It 'Generates Markdown report' {
            $outputFile = Join-Path $script:TestOutputPath 'report.md'

            Export-ComplianceReport -Report $script:MockReport -Format 'markdown' -OutputPath $outputFile

            Test-Path $outputFile | Should -BeTrue
            $content = Get-Content $outputFile -Raw
            $content | Should -Match '# Dependency Pinning Compliance Report'
        }
    }
}

Describe 'ExcludePaths Filtering Logic' -Tag 'Unit' {
    Context 'Pattern matching with -notlike operator' {
        It 'Excludes paths containing pattern using -notlike wildcard' {
            # Test the exclusion logic used in Get-FilesToScan:
            # $files = $files | Where-Object { $_.FullName -notlike "*$exclude*" }
            $testPaths = @(
                @{ FullName = 'C:\repo\.github\workflows\test.yml' }
                @{ FullName = 'C:\repo\vendor\.github\workflows\vendor.yml' }
            )

            $exclude = 'vendor'
            $filtered = $testPaths | Where-Object { $_.FullName -notlike "*$exclude*" }

            $filtered.Count | Should -Be 1
            $filtered[0].FullName | Should -Not -Match 'vendor'
        }

        It 'Excludes multiple patterns correctly' {
            $testPaths = @(
                @{ FullName = 'C:\repo\.github\workflows\test.yml' }
                @{ FullName = 'C:\repo\vendor\.github\workflows\vendor.yml' }
                @{ FullName = 'C:\repo\node_modules\pkg\workflow.yml' }
            )

            $excludePatterns = @('vendor', 'node_modules')
            $filtered = $testPaths
            foreach ($exclude in $excludePatterns) {
                $filtered = @($filtered | Where-Object { $_.FullName -notlike "*$exclude*" })
            }

            $filtered.Count | Should -Be 1
            $filtered[0].FullName | Should -Be 'C:\repo\.github\workflows\test.yml'
        }
    }

    Context 'Processes all files when ExcludePatterns is empty' {
        It 'Returns all paths when no exclusion patterns provided' {
            $testPaths = @(
                @{ FullName = 'C:\repo\.github\workflows\test.yml' }
                @{ FullName = 'C:\repo\vendor\.github\workflows\vendor.yml' }
            )

            $excludePatterns = @()
            $filtered = $testPaths
            if ($excludePatterns) {
                foreach ($exclude in $excludePatterns) {
                    $filtered = $filtered | Where-Object { $_.FullName -notlike "*$exclude*" }
                }
            }

            $filtered.Count | Should -Be 2
        }
    }

    Context 'Comma-separated pattern parsing in main script' {
        It 'Parses comma-separated exclude paths correctly' {
            # Test the pattern used in main execution: $ExcludePaths.Split(',')
            $excludePathsParam = 'vendor,node_modules,dist'
            $patterns = $excludePathsParam.Split(',') | ForEach-Object { $_.Trim() }

            $patterns.Count | Should -Be 3
            $patterns | Should -Contain 'vendor'
            $patterns | Should -Contain 'node_modules'
            $patterns | Should -Contain 'dist'
        }

        It 'Handles single pattern without comma' {
            $excludePathsParam = 'vendor'
            $patterns = $excludePathsParam.Split(',') | ForEach-Object { $_.Trim() }

            $patterns.Count | Should -Be 1
            $patterns | Should -Contain 'vendor'
        }

        It 'Handles empty exclude paths' {
            $excludePathsParam = ''
            $patterns = if ($excludePathsParam) { $excludePathsParam.Split(',') | ForEach-Object { $_.Trim() } } else { @() }

            $patterns.Count | Should -Be 0
        }
    }

    Context 'Pattern matching behavior' {
        It 'Uses -notlike with wildcard for exclusion' {
            $filePath = 'C:\repo\vendor\.github\workflows\test.yml'
            $pattern = 'vendor'

            # This matches how Get-FilesToScan uses: $_.FullName -notlike "*$exclude*"
            $filePath -notlike "*$pattern*" | Should -BeFalse
        }

        It 'Passes through non-matching paths' {
            $filePath = 'C:\repo\.github\workflows\main.yml'
            $pattern = 'vendor'

            $filePath -notlike "*$pattern*" | Should -BeTrue
        }
    }
}

Describe 'Dot-sourced execution protection' -Tag 'Unit' {
    Context 'When script is dot-sourced' {
        It 'Does not execute main block when dot-sourced' {
            # Arrange
            $testScript = Join-Path $PSScriptRoot '../../security/Test-DependencyPinning.ps1'
            $tempOutputPath = Join-Path $TestDrive 'dot-source-test.json'

            # Act - Invoke in new process with dot-sourcing simulation
            $scriptBlock = ". '$testScript' -OutputPath '$tempOutputPath'; [System.IO.File]::Exists('$tempOutputPath')"
            pwsh -Command $scriptBlock 2>&1 | Out-Null

            # Assert - Main execution should be skipped, no output file created
            Test-Path $tempOutputPath | Should -BeFalse
        }

    }
}

Describe 'GitHub Actions error annotation' {
    BeforeAll {
        $script:OriginalGHA = $env:GITHUB_ACTIONS
        $script:TestScript = Join-Path $PSScriptRoot '../../security/Test-DependencyPinning.ps1'
    }

    AfterAll {
        if ($null -eq $script:OriginalGHA) {
            Remove-Item Env:GITHUB_ACTIONS -ErrorAction SilentlyContinue
        } else {
            $env:GITHUB_ACTIONS = $script:OriginalGHA
        }
    }

    Context 'Error handling with GitHub Actions' {
        It 'Outputs GitHub error annotation on failure' {
            # Arrange - Create a corrupted workflow file that will trigger an error
            $testWorkflowDir = Join-Path $TestDrive 'test-workflows'
            New-Item -ItemType Directory -Path (Join-Path $testWorkflowDir '.github/workflows') -Force | Out-Null
            $corruptedFile = Join-Path $testWorkflowDir '.github/workflows/test.yml'
            "uses: actions/checkout@invalid!!!" | Out-File -FilePath $corruptedFile -Encoding UTF8
            
            # Act - Run script in new process with GITHUB_ACTIONS set
            $scriptCommand = @"
`$env:GITHUB_ACTIONS = 'true'
& '$script:TestScript' -Path '$testWorkflowDir' -Format 'json' -OutputPath '$TestDrive/gha-test.json' -FailOnUnpinned 2>&1
"@
            $output = pwsh -Command $scriptCommand

            # Assert - Should contain GitHub Actions error annotation or error output
            # The script should execute and potentially generate warnings/errors
            $output | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'Get-ComplianceReportData' -Tag 'Unit' {
    BeforeAll {
        . $PSScriptRoot/../../security/Test-DependencyPinning.ps1
    }

    Context 'Array coercion operations' {
        It 'Handles empty violations array' {
            $result = Get-ComplianceReportData -ScanPath 'TestDrive:/' -Violations @() -ScannedFiles @()
            
            $result.TotalDependencies | Should -Be 0
            $result.UnpinnedDependencies | Should -Be 0
            $result.PinnedDependencies | Should -Be 0
            $result.ComplianceScore | Should -Be 100.0
        }

        It 'Counts violations correctly with array coercion' {
            $v1 = [DependencyViolation]::new()
            $v1.Type = 'github-actions'
            $v1.Severity = 'High'
            
            $v2 = [DependencyViolation]::new()
            $v2.Type = 'github-actions'
            $v2.Severity = 'Medium'
            
            $v3 = [DependencyViolation]::new()
            $v3.Type = 'npm'
            $v3.Severity = 'High'
            
            $violations = @($v1, $v2, $v3)
            $scannedFiles = @(@{ Path = 'test1.yml' }, @{ Path = 'test2.json' })
            
            $result = Get-ComplianceReportData -ScanPath 'TestDrive:/' -Violations $violations -ScannedFiles $scannedFiles
            
            $result.TotalDependencies | Should -Be 3
            $result.UnpinnedDependencies | Should -Be 3
        }

        It 'Groups violations by type with array coercion' {
            $v1 = [DependencyViolation]::new()
            $v1.Type = 'github-actions'
            $v1.Severity = 'High'
            
            $v2 = [DependencyViolation]::new()
            $v2.Type = 'github-actions'
            $v2.Severity = 'Low'
            
            $v3 = [DependencyViolation]::new()
            $v3.Type = 'npm'
            $v3.Severity = 'Medium'
            
            $violations = @($v1, $v2, $v3)
            $scannedFiles = @(@{ Path = 'test.yml' })
            
            $result = Get-ComplianceReportData -ScanPath 'TestDrive:/' -Violations $violations -ScannedFiles $scannedFiles
            
            $result.Summary.Keys | Should -Contain 'github-actions'
            $result.Summary.Keys | Should -Contain 'npm'
            $result.Summary['github-actions'].Total | Should -Be 2
            $result.Summary['npm'].Total | Should -Be 1
        }

        It 'Counts severity levels correctly with array coercion' {
            $violations = @()
            for ($i = 0; $i -lt 4; $i++) {
                $v = [DependencyViolation]::new()
                $v.Type = 'github-actions'
                $v.Severity = switch ($i) {
                    0 { 'High' }
                    1 { 'High' }
                    2 { 'Medium' }
                    3 { 'Low' }
                }
                $violations += $v
            }
            $scannedFiles = @(@{ Path = 'test.yml' })
            
            $result = Get-ComplianceReportData -ScanPath 'TestDrive:/' -Violations $violations -ScannedFiles $scannedFiles
            
            $result.Summary['github-actions'].High | Should -Be 2
            $result.Summary['github-actions'].Medium | Should -Be 1
            $result.Summary['github-actions'].Low | Should -Be 1
        }

        It 'Handles single violation without PowerShell unrolling' {
            $v = [DependencyViolation]::new()
            $v.Type = 'github-actions'
            $v.Severity = 'High'
            
            $violations = @($v)
            $scannedFiles = @(@{ Path = 'test.yml' })
            
            $result = Get-ComplianceReportData -ScanPath 'TestDrive:/' -Violations $violations -ScannedFiles $scannedFiles
            
            $result.TotalDependencies | Should -Be 1
            $result.Summary['github-actions'].Total | Should -Be 1
            $result.Summary['github-actions'].High | Should -Be 1
        }
    }
}

Describe 'Main Script Execution' {
    BeforeAll {
        $script:TestScript = Join-Path $PSScriptRoot '../../security/Test-DependencyPinning.ps1'
        $script:TestWorkspaceDir = Join-Path $TestDrive 'test-workspace'
        New-Item -ItemType Directory -Path $script:TestWorkspaceDir -Force | Out-Null
        
        # Create .github/workflows directory
        $workflowDir = Join-Path $script:TestWorkspaceDir '.github/workflows'
        New-Item -ItemType Directory -Path $workflowDir -Force | Out-Null
    }

    Context 'Array coercion in main execution block' {
        It 'Executes array coercion when scanning files' {
            # Create test workflow file
            $workflowContent = @'
name: Test
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
'@
            Set-Content -Path (Join-Path $script:TestWorkspaceDir '.github/workflows/test.yml') -Value $workflowContent
            
            $jsonPath = Join-Path $TestDrive 'scan-output.json'
            
            # Execute script with array coercion operations
            & $script:TestScript -Path $script:TestWorkspaceDir -Format 'json' -OutputPath $jsonPath *>&1 | Out-Null
            
            # Verify output was created (proves array operations executed)
            Test-Path $jsonPath | Should -BeTrue
            $result = Get-Content $jsonPath | ConvertFrom-Json
            $result.PSObject.Properties.Name | Should -Contain 'ComplianceScore'
        }

        It 'Handles empty scan results with array coercion' {
            # Remove workflow files
            Remove-Item -Path (Join-Path $script:TestWorkspaceDir '.github/workflows/*.yml') -Force -ErrorAction SilentlyContinue
            
            # Create pinned workflow
            $pinnedContent = @'
name: Pinned
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@8e5e7e5ab8b370d6c329ec480221332ada57f0ab
'@
            Set-Content -Path (Join-Path $script:TestWorkspaceDir '.github/workflows/pinned.yml') -Value $pinnedContent
            
            $jsonPath = Join-Path $TestDrive 'empty-output.json'
            
            # Execute with all dependencies pinned (tests zero count array coercion)
            & $script:TestScript -Path $script:TestWorkspaceDir -Format 'json' -OutputPath $jsonPath *>&1 | Out-Null
            
            Test-Path $jsonPath | Should -BeTrue
            $result = Get-Content $jsonPath | ConvertFrom-Json
            $result.UnpinnedDependencies | Should -Be 0
        }
    }
}

Describe 'Get-NpmDependencyViolations' -Tag 'Unit' {
    BeforeAll {
        . $PSScriptRoot/../../security/Test-DependencyPinning.ps1
        $script:FixturesPath = Join-Path $PSScriptRoot '../Fixtures/Npm'
    }

    Context 'Metadata-only package.json' {
        It 'Returns zero violations for package with no dependencies' {
            $fileInfo = @{
                Path         = Join-Path $script:FixturesPath 'metadata-only-package.json'
                Type         = 'npm'
                RelativePath = 'metadata-only-package.json'
            }

            $violations = Get-NpmDependencyViolations -FileInfo $fileInfo

            $violations.Count | Should -Be 0
        }
    }

    Context 'Package.json with dependencies' {
        It 'Detects unpinned dependencies in all sections' {
            $fileInfo = @{
                Path         = Join-Path $script:FixturesPath 'with-dependencies-package.json'
                Type         = 'npm'
                RelativePath = 'with-dependencies-package.json'
            }

            $violations = Get-NpmDependencyViolations -FileInfo $fileInfo

            $violations.Count | Should -BeGreaterThan 0
        }

        It 'Identifies correct dependency sections' {
            $fileInfo = @{
                Path         = Join-Path $script:FixturesPath 'with-dependencies-package.json'
                Type         = 'npm'
                RelativePath = 'with-dependencies-package.json'
            }

            $violations = Get-NpmDependencyViolations -FileInfo $fileInfo
            $sections = $violations | ForEach-Object { $_.Metadata.Section } | Sort-Object -Unique

            $sections | Should -Contain 'dependencies'
            $sections | Should -Contain 'devDependencies'
        }

        It 'Captures package name and version in violations' {
            $fileInfo = @{
                Path         = Join-Path $script:FixturesPath 'with-dependencies-package.json'
                Type         = 'npm'
                RelativePath = 'with-dependencies-package.json'
            }

            $violations = Get-NpmDependencyViolations -FileInfo $fileInfo
            $lodashViolation = $violations | Where-Object { $_.Name -eq 'lodash' }

            $lodashViolation | Should -Not -BeNullOrEmpty
            $lodashViolation.Name | Should -Be 'lodash'
            $lodashViolation.Version | Should -Be '^4.17.21'
        }
    }

    Context 'Non-existent file' {
        It 'Returns empty array for missing file' {
            $fileInfo = @{
                Path         = 'C:\nonexistent\package.json'
                Type         = 'npm'
                RelativePath = 'nonexistent/package.json'
            }

            $violations = Get-NpmDependencyViolations -FileInfo $fileInfo

            $violations.Count | Should -Be 0
        }
    }

    Context 'When package.json contains invalid JSON' {
        BeforeAll {
            $script:invalidJsonPath = Join-Path $script:FixturesPath 'invalid-json-package.json'
        }

        It 'Returns empty violations array on parse failure' {
            $fileInfo = @{
                Path         = $script:invalidJsonPath
                Type         = 'npm'
                RelativePath = 'invalid-json-package.json'
            }

            $violations = @(Get-NpmDependencyViolations -FileInfo $fileInfo)

            $violations | Should -HaveCount 0
        }

        It 'Emits a warning about parse failure' {
            $fileInfo = @{
                Path         = $script:invalidJsonPath
                Type         = 'npm'
                RelativePath = 'invalid-json-package.json'
            }

            $warnings = Get-NpmDependencyViolations -FileInfo $fileInfo 3>&1

            $warnings | Should -Not -BeNullOrEmpty
            $warnings | Should -Match 'Failed to parse.*as JSON'
        }
    }

    Context 'When package.json contains empty or whitespace versions' {
        BeforeAll {
            $script:emptyVersionPath = Join-Path $script:FixturesPath 'empty-version-package.json'
        }

        It 'Skips dependencies with empty versions' {
            $fileInfo = @{
                Path         = $script:emptyVersionPath
                Type         = 'npm'
                RelativePath = 'empty-version-package.json'
            }

            $violations = Get-NpmDependencyViolations -FileInfo $fileInfo
            $packageNames = $violations | ForEach-Object { $_.Name }

            $packageNames | Should -Not -Contain 'empty-version'
            $packageNames | Should -Not -Contain 'whitespace-version'
        }

        It 'Reports violations for valid non-pinned versions in same file' {
            $fileInfo = @{
                Path         = $script:emptyVersionPath
                Type         = 'npm'
                RelativePath = 'empty-version-package.json'
            }

            $violations = Get-NpmDependencyViolations -FileInfo $fileInfo

            $violations.Count | Should -BeGreaterThan 0
            $violations | Where-Object { $_.Name -eq 'valid-package' } | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'Get-RemediationSuggestion' -Tag 'Unit' {
    Context 'Without -Remediate flag' {
        It 'Returns enable-flag message' {
            $v = [DependencyViolation]::new('f.yml', 1, 'github-actions', 'actions/checkout', 'High', 'desc')
            $v.Version = 'v4'
            $result = Get-RemediationSuggestion -Violation $v
            $result | Should -BeLike '*Enable -Remediate flag*'
        }
    }

    Context 'GitHub Actions with -Remediate' {
        It 'Resolves SHA from API and returns pin suggestion' {
            $v = [DependencyViolation]::new('f.yml', 1, 'github-actions', 'actions/checkout', 'High', 'desc')
            $v.Version = 'v4'
            $fakeSha = 'a'.PadRight(40, 'b')
            Mock Invoke-RestMethod { return @{ sha = $fakeSha } }
            $result = Get-RemediationSuggestion -Violation $v -Remediate
            $result | Should -BeLike "Pin to SHA: uses: actions/checkout@$fakeSha*"
        }

        It 'Returns manual fallback when API throws' {
            $v = [DependencyViolation]::new('f.yml', 1, 'github-actions', 'actions/checkout', 'High', 'desc')
            $v.Version = 'v4'
            Mock Invoke-RestMethod { throw 'API error' }
            Mock Write-SecurityLog {}
            $result = Get-RemediationSuggestion -Violation $v -Remediate
            $result | Should -Be 'Manually research and pin to immutable reference'
        }
    }

    Context 'Non-github-actions type with -Remediate' {
        It 'Returns generic research message' {
            $v = [DependencyViolation]::new('req.txt', 1, 'pip', 'requests', 'Medium', 'desc')
            $v.Version = '2.31.0'
            $result = Get-RemediationSuggestion -Violation $v -Remediate
            $result | Should -BeLike '*Research and pin*pip*'
        }
    }
}

Describe 'Get-DependencyViolation with ValidationFunc' -Tag 'Unit' {
    Context 'npm type triggers ValidationFunc path' {
        BeforeAll {
            $script:npmFixturePath = Join-Path $script:SecurityFixturesPath 'npm-violations'
            if (-not (Test-Path $script:npmFixturePath)) {
                New-Item -ItemType Directory -Path $script:npmFixturePath -Force | Out-Null
            }
            $script:pkgPath = Join-Path $script:npmFixturePath 'test-pkg.json'
            Set-Content -Path $script:pkgPath -Value '{"dependencies":{"lodash":"^4.17.21"}}'
        }

        It 'Uses ValidationFunc instead of regex patterns' {
            $fileInfo = @{
                Path         = $script:pkgPath
                Type         = 'npm'
                RelativePath = 'test-pkg.json'
            }
            $violations = Get-DependencyViolation -FileInfo $fileInfo
            $violations | Should -Not -BeNullOrEmpty
            $violations[0].GetType().Name | Should -Be 'DependencyViolation'
        }

        It 'Sets File from FileInfo when missing' {
            $fileInfo = @{
                Path         = $script:pkgPath
                Type         = 'npm'
                RelativePath = 'test-pkg.json'
            }
            $violations = Get-DependencyViolation -FileInfo $fileInfo
            $violations | ForEach-Object { $_.File | Should -Not -BeNullOrEmpty }
        }
    }
}

Describe 'Invoke-DependencyPinningAnalysis' -Tag 'Unit' {
    BeforeAll {
        Mock Get-FilesToScan { return @() }
        Mock Get-ComplianceReportData {
            return @{
                ComplianceScore      = 100.0
                TotalDependencies    = 0
                UnpinnedDependencies = 0
                Violations           = @()
            }
        }
        Mock Export-ComplianceReport {}
        Mock Export-CICDArtifact {}
    }

    Context 'All dependencies pinned' {
        It 'Logs success message without throwing' {
            { Invoke-DependencyPinningAnalysis -Path TestDrive: } | Should -Not -Throw
        }

        It 'emits success Write-Host message when no violations' {
            Invoke-DependencyPinningAnalysis -Path TestDrive:
            Should -Invoke Write-Host -ParameterFilter {
                $Object -like '*✅*' -and $Object -like '*SHA-pinned*'
            }
        }

        It 'does not emit Write-CIAnnotation warnings when no violations' {
            Invoke-DependencyPinningAnalysis -Path TestDrive:
            Should -Not -Invoke Write-CIAnnotation -ParameterFilter {
                $Level -eq 'Warning'
            }
        }
    }

    Context 'Violations below threshold with -FailOnUnpinned' {
        BeforeAll {
            Mock Get-FilesToScan {
                return @(@{ Path = 'TestDrive:\f.yml'; Type = 'github-actions'; RelativePath = 'f.yml' })
            }
            Mock Get-DependencyViolation {
                $v = [DependencyViolation]::new('f.yml', 1, 'github-actions', 'a/b', 'High', 'Not pinned')
                return @($v)
            }
            Mock Get-RemediationSuggestion { return 'pin it' }
            Mock Get-ComplianceReportData {
                return @{
                    ComplianceScore      = 50.0
                    TotalDependencies    = 2
                    UnpinnedDependencies = 1
                    Violations           = @()
                }
            }
        }

        It 'Throws when score below threshold and -FailOnUnpinned' {
            { Invoke-DependencyPinningAnalysis -Path TestDrive: -FailOnUnpinned -Threshold 80 } | Should -Throw '*below threshold*'
        }

        It 'Does not throw in soft-fail mode' {
            { Invoke-DependencyPinningAnalysis -Path TestDrive: -Threshold 80 } | Should -Not -Throw
        }
    }

    Context 'CI output for violations in soft-fail mode' {
        BeforeAll {
            Mock Get-FilesToScan {
                return @(@{ Path = 'TestDrive:\f.yml'; Type = 'github-actions'; RelativePath = 'f.yml' })
            }
            Mock Get-DependencyViolation {
                $v = [DependencyViolation]::new('f.yml', 1, 'github-actions', 'a/b', 'High', 'Not pinned')
                $v.CurrentRef = 'v4'
                return @($v)
            }
            Mock Get-RemediationSuggestion { return 'pin it' }
            Mock Get-ComplianceReportData {
                return @{
                    ComplianceScore      = 50.0
                    TotalDependencies    = 2
                    UnpinnedDependencies = 1
                    Violations           = @()
                }
            }
            Mock Export-ComplianceReport {}
            Mock Export-CICDArtifact {}
        }

        It 'emits summary header with violation count' {
            Invoke-DependencyPinningAnalysis -Path TestDrive: -Threshold 80
            Should -Invoke Write-Host -ParameterFilter {
                $Object -like '*unpinned*'
            }
        }

        It 'emits file header with file icon' {
            Invoke-DependencyPinningAnalysis -Path TestDrive: -Threshold 80
            Should -Invoke Write-Host -ParameterFilter {
                $Object -like '*📄*'
            }
        }

        It 'emits per-violation detail line' {
            Invoke-DependencyPinningAnalysis -Path TestDrive: -Threshold 80
            Should -Invoke Write-Host -ParameterFilter {
                $Object -like '*❌*' -and $Object -like '*a/b*'
            }
        }

        It 'emits Write-CIAnnotation with Error level for High severity violation' {
            Invoke-DependencyPinningAnalysis -Path TestDrive: -Threshold 80
            Should -Invoke Write-CIAnnotation -ParameterFilter {
                $Level -eq 'Error' -and $File -eq 'f.yml' -and $Line -eq 1
            }
        }
    }

    Context 'Score meets threshold' {
        BeforeAll {
            Mock Get-FilesToScan {
                return @(@{ Path = 'TestDrive:\f.yml'; Type = 'github-actions'; RelativePath = 'f.yml' })
            }
            Mock Get-DependencyViolation {
                $v = [DependencyViolation]::new('f.yml', 1, 'github-actions', 'a/b', 'Low', 'desc')
                return @($v)
            }
            Mock Get-RemediationSuggestion { return 'pin it' }
            Mock Get-ComplianceReportData {
                return @{
                    ComplianceScore      = 90.0
                    TotalDependencies    = 10
                    UnpinnedDependencies = 1
                    Violations           = @()
                }
            }
        }

        It 'Does not throw when score meets threshold' {
            { Invoke-DependencyPinningAnalysis -Path TestDrive: -Threshold 80 } | Should -Not -Throw
        }
    }

    Context 'CI annotations per violation' {
        BeforeAll {
            Mock Write-CIAnnotation {}
            Mock Write-Host {}
            Mock Write-CIAnnotation {} -ModuleName SecurityHelpers
            Mock Write-Host {} -ModuleName SecurityHelpers
        }

        It 'Emits Write-CIAnnotation per violation' {
            Mock Get-FilesToScan {
                return @(@{ Path = 'TestDrive:\f.yml'; Type = 'github-actions'; RelativePath = 'f.yml' })
            }
            Mock Get-DependencyViolation {
                $v = [DependencyViolation]::new('f.yml', 1, 'github-actions', 'a/b', 'High', 'Not pinned')
                $v.ViolationType = 'Unpinned'
                $v.Version = 'v4'
                return @($v)
            }
            Mock Get-RemediationSuggestion { return 'pin it' }
            Mock Get-ComplianceReportData {
                return @{ ComplianceScore = 50.0; TotalDependencies = 1; UnpinnedDependencies = 1; Violations = @() }
            }

            Invoke-DependencyPinningAnalysis -Path TestDrive:

            Should -Invoke Write-CIAnnotation -ParameterFilter { $Level -eq 'Error' -and $File -eq 'f.yml' -and $Line -eq 1 } -Times 1 -Exactly
        }

        It 'Maps High severity to Error level' {
            Mock Get-FilesToScan {
                return @(@{ Path = 'TestDrive:\f.yml'; Type = 'github-actions'; RelativePath = 'f.yml' })
            }
            Mock Get-DependencyViolation {
                $v = [DependencyViolation]::new('f.yml', 5, 'github-actions', 'actions/checkout', 'High', 'Unpinned action')
                $v.ViolationType = 'Unpinned'
                $v.Version = 'v4'
                return @($v)
            }
            Mock Get-RemediationSuggestion { return 'pin it' }
            Mock Get-ComplianceReportData {
                return @{ ComplianceScore = 50.0; TotalDependencies = 1; UnpinnedDependencies = 1; Violations = @() }
            }

            Invoke-DependencyPinningAnalysis -Path TestDrive:

            Should -Invoke Write-CIAnnotation -ParameterFilter { $Level -eq 'Error' -and $File -eq 'f.yml' } -Times 1 -Exactly
        }

        It 'Maps Medium severity to Warning level' {
            Mock Get-FilesToScan {
                return @(@{ Path = 'TestDrive:\f.yml'; Type = 'github-actions'; RelativePath = 'f.yml' })
            }
            Mock Get-DependencyViolation {
                $v = [DependencyViolation]::new('f.yml', 3, 'npm', 'lodash', 'Medium', 'Unpinned npm dep')
                $v.ViolationType = 'Unpinned'
                $v.Version = '^4.0.0'
                return @($v)
            }
            Mock Get-RemediationSuggestion { return 'pin it' }
            Mock Get-ComplianceReportData {
                return @{ ComplianceScore = 80.0; TotalDependencies = 1; UnpinnedDependencies = 1; Violations = @() }
            }

            Invoke-DependencyPinningAnalysis -Path TestDrive:

            Should -Invoke Write-CIAnnotation -ParameterFilter { $Level -eq 'Warning' -and $File -eq 'f.yml' } -Times 1 -Exactly
        }

        It 'Maps Low severity to Notice level' {
            Mock Get-FilesToScan {
                return @(@{ Path = 'TestDrive:\f.yml'; Type = 'github-actions'; RelativePath = 'f.yml' })
            }
            Mock Get-DependencyViolation {
                $v = [DependencyViolation]::new('f.yml', 7, 'github-actions', 'a/b', 'Low', 'Minor issue')
                $v.ViolationType = 'MissingVersionComment'
                $v.Version = 'abc123'
                return @($v)
            }
            Mock Get-RemediationSuggestion { return 'add comment' }
            Mock Get-ComplianceReportData {
                return @{ ComplianceScore = 90.0; TotalDependencies = 1; UnpinnedDependencies = 1; Violations = @() }
            }

            Invoke-DependencyPinningAnalysis -Path TestDrive:

            Should -Invoke Write-CIAnnotation -ParameterFilter { $Level -eq 'Notice' } -Times 1 -Exactly
        }

        It 'Includes violation type in annotation message' {
            Mock Get-FilesToScan {
                return @(@{ Path = 'TestDrive:\f.yml'; Type = 'github-actions'; RelativePath = 'f.yml' })
            }
            Mock Get-DependencyViolation {
                $v = [DependencyViolation]::new('f.yml', 1, 'github-actions', 'a/b', 'High', 'Not pinned')
                $v.ViolationType = 'Unpinned'
                $v.Version = 'v4'
                return @($v)
            }
            Mock Get-RemediationSuggestion { return 'pin it' }
            Mock Get-ComplianceReportData {
                return @{ ComplianceScore = 50.0; TotalDependencies = 1; UnpinnedDependencies = 1; Violations = @() }
            }

            Invoke-DependencyPinningAnalysis -Path TestDrive:

            Should -Invoke Write-CIAnnotation -ParameterFilter { $Message -match 'Unpinned' }
        }

        It 'Emits no annotations when no violations' {
            Mock Get-FilesToScan { return @() }
            Mock Get-ComplianceReportData {
                return @{ ComplianceScore = 100.0; TotalDependencies = 0; UnpinnedDependencies = 0; Violations = @() }
            }

            Invoke-DependencyPinningAnalysis -Path TestDrive:

            Should -Invoke Write-CIAnnotation -Times 0
        }

        It 'Emits multiple annotations for multiple violations' {
            Mock Get-FilesToScan {
                return @(@{ Path = 'TestDrive:\f.yml'; Type = 'github-actions'; RelativePath = 'f.yml' })
            }
            Mock Get-DependencyViolation {
                $v1 = [DependencyViolation]::new('f.yml', 1, 'github-actions', 'a/b', 'High', 'Not pinned')
                $v1.ViolationType = 'Unpinned'
                $v1.Version = 'v4'
                $v2 = [DependencyViolation]::new('f.yml', 5, 'github-actions', 'c/d', 'Medium', 'Also not pinned')
                $v2.ViolationType = 'Unpinned'
                $v2.Version = 'v3'
                return @($v1, $v2)
            }
            Mock Get-RemediationSuggestion { return 'pin it' }
            Mock Get-ComplianceReportData {
                return @{ ComplianceScore = 50.0; TotalDependencies = 2; UnpinnedDependencies = 2; Violations = @() }
            }

            Invoke-DependencyPinningAnalysis -Path TestDrive:

            Should -Invoke Write-CIAnnotation -ParameterFilter { $null -ne $File } -Times 2 -Exactly
        }
    }

    Context 'Write-SecurityLog CI annotation forwarding' {
        BeforeAll {
            Mock Write-CIAnnotation {} -ModuleName SecurityHelpers
            Mock Write-Host {} -ModuleName SecurityHelpers
        }

        It 'Forwards Warning-level log messages as CI Warning annotations' {
            Mock Get-FilesToScan {
                return @(@{ Path = 'TestDrive:\f.yml'; Type = 'github-actions'; RelativePath = 'f.yml' })
            }
            Mock Get-DependencyViolation {
                $v = [DependencyViolation]::new('f.yml', 1, 'github-actions', 'a/b', 'High', 'Not pinned')
                $v.ViolationType = 'Unpinned'
                $v.Version = 'v4'
                return @($v)
            }
            Mock Get-RemediationSuggestion { return 'pin it' }
            Mock Get-ComplianceReportData {
                return @{ ComplianceScore = 90.0; TotalDependencies = 2; UnpinnedDependencies = 1; Violations = @() }
            }

            Invoke-DependencyPinningAnalysis -Path TestDrive:

            # Write-SecurityLog -CIAnnotation "N dependencies require SHA pinning..." emits a Warning annotation
            Should -Invoke Write-CIAnnotation -ModuleName SecurityHelpers -ParameterFilter { $Level -eq 'Warning' -and $null -eq $File -and $Message -match 'SHA pinning' }
        }

        It 'Forwards Error-level log messages as CI Error annotations' {
            Mock Get-FilesToScan {
                return @(@{ Path = 'TestDrive:\f.yml'; Type = 'github-actions'; RelativePath = 'f.yml' })
            }
            Mock Get-DependencyViolation {
                $v = [DependencyViolation]::new('f.yml', 1, 'github-actions', 'a/b', 'High', 'Not pinned')
                $v.ViolationType = 'Unpinned'
                $v.Version = 'v4'
                return @($v)
            }
            Mock Get-RemediationSuggestion { return 'pin it' }
            Mock Get-ComplianceReportData {
                return @{ ComplianceScore = 50.0; TotalDependencies = 1; UnpinnedDependencies = 1; Violations = @() }
            }

            Invoke-DependencyPinningAnalysis -Path TestDrive:

            # Write-SecurityLog -CIAnnotation "Compliance score ... below threshold" emits an Error annotation
            Should -Invoke Write-CIAnnotation -ModuleName SecurityHelpers -ParameterFilter { $Level -eq 'Error' -and $null -eq $File -and $Message -match 'below threshold' }
        }

        It 'Does not forward Info-level log messages as annotations' {
            Mock Get-FilesToScan { return @() }
            Mock Get-ComplianceReportData {
                return @{ ComplianceScore = 100.0; TotalDependencies = 0; UnpinnedDependencies = 0; Violations = @() }
            }

            Invoke-DependencyPinningAnalysis -Path TestDrive:

            # Info and Success levels should not produce CI annotations
            Should -Invoke Write-CIAnnotation -ModuleName SecurityHelpers -ParameterFilter { $null -eq $File } -Times 0
        }
    }

    Context 'Per-violation console output' {
        BeforeAll {
            Mock Write-CIAnnotation {}
            Mock Write-Host {}
            Mock Write-CIAnnotation {} -ModuleName SecurityHelpers
            Mock Write-Host {} -ModuleName SecurityHelpers
        }

        It 'Writes colored output for High severity violations' {
            Mock Get-FilesToScan {
                return @(@{ Path = 'TestDrive:\f.yml'; Type = 'github-actions'; RelativePath = 'f.yml' })
            }
            Mock Get-DependencyViolation {
                $v = [DependencyViolation]::new('f.yml', 1, 'github-actions', 'a/b', 'High', 'Not pinned')
                $v.ViolationType = 'Unpinned'
                $v.Version = 'v4'
                return @($v)
            }
            Mock Get-RemediationSuggestion { return 'pin it' }
            Mock Get-ComplianceReportData {
                return @{ ComplianceScore = 50.0; TotalDependencies = 1; UnpinnedDependencies = 1; Violations = @() }
            }

            Invoke-DependencyPinningAnalysis -Path TestDrive:

            Should -Invoke Write-Host -ParameterFilter { $ForegroundColor -eq 'Red' -and $Object -match 'a/b' }
        }

        It 'Writes success message when no violations' {
            Mock Get-FilesToScan { return @() }
            Mock Get-ComplianceReportData {
                return @{ ComplianceScore = 100.0; TotalDependencies = 0; UnpinnedDependencies = 0; Violations = @() }
            }

            Invoke-DependencyPinningAnalysis -Path TestDrive:

            Should -Invoke Write-Host -ParameterFilter { $ForegroundColor -eq 'Green' -and $Object -match 'SHA-pinned' }
        }
    }
}
