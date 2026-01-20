#Requires -Modules Pester

BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '../../security/Test-DependencyPinning.ps1'
    . $scriptPath

    $mockPath = Join-Path $PSScriptRoot '../Mocks/GitMocks.psm1'
    Import-Module $mockPath -Force

    # Fixture paths
    $script:FixturesPath = Join-Path $PSScriptRoot '../Fixtures/Workflows'
    $script:SecurityFixturesPath = Join-Path $PSScriptRoot '../Fixtures/Security'
}

AfterAll {
    # Cleanup if needed
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
            $result = Test-ShellDownloadSecurity -FilePath $testFile
            $result | Should -Not -BeNullOrEmpty
            $result[0].Severity | Should -Be 'warning'
        }
    }

    Context 'File not found' {
        It 'Returns empty array for non-existent file' {
            $result = Test-ShellDownloadSecurity -FilePath 'C:\nonexistent\file.sh'
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
                Path         = 'C:\nonexistent\file.yml'
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
