#Requires -Modules Pester

BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '../../security/Test-DependencyPinning.ps1'
    . $scriptPath

    $mockPath = Join-Path $PSScriptRoot '../Mocks/GitMocks.psm1'
    Import-Module $mockPath -Force

    # Fixture paths
    $script:FixturesPath = Join-Path $PSScriptRoot '../Fixtures/Workflows'
}

AfterAll {
    # Cleanup if needed
}

Describe 'Test-SHAPinning' -Tag 'Unit' {
    Context 'Valid SHA references' {
        It 'Returns true for valid 40-char lowercase SHA' {
            Test-SHAPinning -Reference 'a5ac7e51b41094c92402da3b24376905380afc29' | Should -BeTrue
        }

        It 'Returns true for valid 40-char mixed case SHA' {
            Test-SHAPinning -Reference 'A5AC7E51B41094c92402da3b24376905380afc29' | Should -BeTrue
        }
    }

    Context 'Invalid SHA references' {
        It 'Returns false for tag reference' {
            Test-SHAPinning -Reference 'v4' | Should -BeFalse
        }

        It 'Returns false for branch reference' {
            Test-SHAPinning -Reference 'main' | Should -BeFalse
        }

        It 'Returns false for 39-char reference' {
            Test-SHAPinning -Reference 'a5ac7e51b41094c92402da3b24376905380afc2' | Should -BeFalse
        }

        It 'Returns false for 41-char reference' {
            Test-SHAPinning -Reference 'a5ac7e51b41094c92402da3b24376905380afc291' | Should -BeFalse
        }

        It 'Returns false for non-hex characters' {
            Test-SHAPinning -Reference 'g5ac7e51b41094c92402da3b24376905380afc29' | Should -BeFalse
        }
    }
}

Describe 'Test-ShellDownloadSecurity' -Tag 'Unit' {
    Context 'Insecure downloads' {
        It 'Detects curl piped to bash without checksum' {
            $content = 'curl -sSL https://example.com/install.sh | bash'
            $result = Test-ShellDownloadSecurity -Content $content -LineNumber 10
            $result | Should -Not -BeNullOrEmpty
            $result.Severity | Should -Be 'High'
        }

        It 'Detects wget piped to sh without checksum' {
            $content = 'wget -O - https://example.com/script.sh | sh'
            $result = Test-ShellDownloadSecurity -Content $content -LineNumber 15
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Secure downloads' {
        It 'Returns null for download with checksum verification' {
            $content = @"
curl -sSL https://example.com/tool.tar.gz -o tool.tar.gz
echo "abc123 tool.tar.gz" | sha256sum -c -
"@
            $result = Test-ShellDownloadSecurity -Content $content -LineNumber 20
            $result | Should -BeNullOrEmpty
        }
    }
}

Describe 'Get-DependencyViolation' -Tag 'Unit' {
    Context 'Pinned workflows' {
        It 'Returns no violations for fully pinned workflow' {
            $pinnedPath = Join-Path $script:FixturesPath 'pinned-workflow.yml'
            $result = Get-DependencyViolation -FilePath $pinnedPath
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Unpinned workflows' {
        It 'Detects unpinned action references' {
            $unpinnedPath = Join-Path $script:FixturesPath 'unpinned-workflow.yml'
            $result = Get-DependencyViolation -FilePath $unpinnedPath
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -BeGreaterThan 0
        }

        It 'Returns correct violation type for unpinned actions' {
            $unpinnedPath = Join-Path $script:FixturesPath 'unpinned-workflow.yml'
            $result = Get-DependencyViolation -FilePath $unpinnedPath
            $result[0].Type | Should -Be 'action'
        }
    }

    Context 'Mixed workflows' {
        It 'Detects only unpinned actions in mixed workflow' {
            $mixedPath = Join-Path $script:FixturesPath 'mixed-pinning-workflow.yml'
            $result = Get-DependencyViolation -FilePath $mixedPath
            $result | Should -Not -BeNullOrEmpty
            # Should only detect the unpinned setup-node action
            $result.Reference | Should -Contain 'actions/setup-node@v4'
        }
    }
}

Describe 'Export-ComplianceReport' -Tag 'Unit' {
    BeforeEach {
        $script:TestOutputPath = Join-Path $TestDrive 'report'
    }

    Context 'JSON format' {
        It 'Generates valid JSON report' {
            $unpinnedPath = Join-Path $script:FixturesPath 'unpinned-workflow.yml'
            $outputFile = Join-Path $script:TestOutputPath 'report.json'

            Export-ComplianceReport -Path $unpinnedPath -Format 'json' -OutputPath $outputFile

            Test-Path $outputFile | Should -BeTrue
            $content = Get-Content $outputFile -Raw | ConvertFrom-Json
            $content | Should -Not -BeNullOrEmpty
        }
    }

    Context 'SARIF format' {
        It 'Generates valid SARIF report' {
            $unpinnedPath = Join-Path $script:FixturesPath 'unpinned-workflow.yml'
            $outputFile = Join-Path $script:TestOutputPath 'report.sarif'

            Export-ComplianceReport -Path $unpinnedPath -Format 'sarif' -OutputPath $outputFile

            Test-Path $outputFile | Should -BeTrue
            $content = Get-Content $outputFile -Raw | ConvertFrom-Json
            $content.'$schema' | Should -Match 'sarif'
        }
    }

    Context 'Table format' {
        It 'Generates table output without error' {
            $unpinnedPath = Join-Path $script:FixturesPath 'unpinned-workflow.yml'

            { Export-ComplianceReport -Path $unpinnedPath -Format 'table' } | Should -Not -Throw
        }
    }
}
