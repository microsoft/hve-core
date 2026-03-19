# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

#Requires -Modules Pester
# CIHelpers.Tests.ps1
#
# Purpose: Unit tests for CIHelpers.psm1 module
# Author: HVE Core Team

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../lib/Modules/CIHelpers.psm1'
    Import-Module $modulePath -Force

    $mockPath = Join-Path $PSScriptRoot '../Mocks/GitMocks.psm1'
    Import-Module $mockPath -Force
}

Describe 'Get-CIPlatform' -Tag 'Unit' {
    BeforeAll {
        Save-CIEnvironment
    }

    AfterAll {
        Restore-CIEnvironment
    }

    Context 'In GitHub Actions environment' {
        BeforeEach {
            Clear-MockCIEnvironment
            $env:GITHUB_ACTIONS = 'true'
        }

        It 'Returns github' {
            Get-CIPlatform | Should -Be 'github'
        }
    }

    Context 'In Azure DevOps environment with TF_BUILD' {
        BeforeEach {
            Clear-MockCIEnvironment
            $env:TF_BUILD = 'True'
        }

        It 'Returns azdo' {
            Get-CIPlatform | Should -Be 'azdo'
        }
    }

    Context 'In Azure DevOps environment with AZURE_PIPELINES' {
        BeforeEach {
            Clear-MockCIEnvironment
            $env:AZURE_PIPELINES = 'True'
        }

        It 'Returns azdo' {
            Get-CIPlatform | Should -Be 'azdo'
        }
    }

    Context 'In local environment' {
        BeforeEach {
            Clear-MockCIEnvironment
        }

        It 'Returns local' {
            Get-CIPlatform | Should -Be 'local'
        }
    }

    Context 'GitHub takes priority over Azure DevOps' {
        BeforeEach {
            Clear-MockCIEnvironment
            $env:GITHUB_ACTIONS = 'true'
            $env:TF_BUILD = 'True'
        }

        It 'Returns github when both are set' {
            Get-CIPlatform | Should -Be 'github'
        }
    }
}

Describe 'Test-CIEnvironment' -Tag 'Unit' {
    BeforeAll {
        Save-CIEnvironment
    }

    AfterAll {
        Restore-CIEnvironment
    }

    Context 'In GitHub Actions environment' {
        BeforeEach {
            Clear-MockCIEnvironment
            $env:GITHUB_ACTIONS = 'true'
        }

        It 'Returns true' {
            Test-CIEnvironment | Should -BeTrue
        }
    }

    Context 'In Azure DevOps environment' {
        BeforeEach {
            Clear-MockCIEnvironment
            $env:TF_BUILD = 'True'
        }

        It 'Returns true' {
            Test-CIEnvironment | Should -BeTrue
        }
    }

    Context 'In local environment' {
        BeforeEach {
            Clear-MockCIEnvironment
        }

        It 'Returns false' {
            Test-CIEnvironment | Should -BeFalse
        }
    }
}

Describe 'Set-CIOutput' -Tag 'Unit' {
    BeforeAll {
        Save-CIEnvironment
    }

    AfterAll {
        Restore-CIEnvironment
    }

    Context 'In GitHub Actions environment' {
        BeforeEach {
            $script:mockFiles = Initialize-MockCIEnvironment
        }

        AfterEach {
            Remove-MockCIFiles -MockFiles $script:mockFiles
        }

        It 'Writes output to GITHUB_OUTPUT file' {
            Set-CIOutput -Name 'test-key' -Value 'test-value'
            $content = Get-Content -Path $env:GITHUB_OUTPUT -Raw
            $content | Should -Match 'test-key=test-value'
        }

        It 'Appends multiple outputs' {
            Set-CIOutput -Name 'key1' -Value 'value1'
            Set-CIOutput -Name 'key2' -Value 'value2'
            $content = Get-Content -Path $env:GITHUB_OUTPUT -Raw
            $content | Should -Match 'key1=value1'
            $content | Should -Match 'key2=value2'
        }
    }

    Context 'In Azure DevOps environment' {
        BeforeEach {
            Clear-MockCIEnvironment
            $env:TF_BUILD = 'True'
        }

        It 'Outputs task.setvariable format' {
            $output = Set-CIOutput -Name 'test-key' -Value 'test-value'
            $output | Should -Be '##vso[task.setvariable variable=test-key]test-value'
        }

        It 'Includes isOutput flag when specified' {
            $output = Set-CIOutput -Name 'test-key' -Value 'test-value' -IsOutput
            $output | Should -Be '##vso[task.setvariable variable=test-key;isOutput=true]test-value'
        }
    }

    Context 'In local environment' {
        BeforeEach {
            Clear-MockCIEnvironment
        }

        It 'Does not produce console output' {
            $output = Set-CIOutput -Name 'test-key' -Value 'test-value'
            $output | Should -BeNullOrEmpty
        }
    }

    Context 'GitHub with missing GITHUB_OUTPUT' {
        BeforeEach {
            Clear-MockCIEnvironment
            $env:GITHUB_ACTIONS = 'true'
        }

        It 'Handles missing GITHUB_OUTPUT gracefully' {
            { Set-CIOutput -Name 'test-key' -Value 'test-value' } | Should -Not -Throw
        }
    }

    Context 'Workflow command injection prevention (Azure DevOps)' {
        BeforeEach {
            Clear-MockCIEnvironment
            $env:TF_BUILD = 'True'
        }

        It 'Escapes newlines in value to prevent command injection' {
            $maliciousValue = "value`n##vso[task.setvariable variable=pwned]true"
            $output = Set-CIOutput -Name 'test-key' -Value $maliciousValue
            $output | Should -Not -Match '##vso\[task\.setvariable variable=pwned\]'
            $output | Should -Match '%AZP0A'
        }

        It 'Escapes semicolons in variable name to prevent property injection' {
            $maliciousName = 'test;isOutput=true'
            $output = Set-CIOutput -Name $maliciousName -Value 'value'
            $output | Should -Match '%AZP3B'
        }
    }
}

Describe 'Set-CIEnv' -Tag 'Unit' {
    BeforeAll {
        Save-CIEnvironment
    }

    AfterAll {
        Restore-CIEnvironment
    }

    Context 'In GitHub Actions environment' {
        BeforeEach {
            $script:mockFiles = Initialize-MockCIEnvironment
        }

        AfterEach {
            Remove-MockCIFiles -MockFiles $script:mockFiles
        }

        It 'Writes environment variable to GITHUB_ENV file' {
            Set-CIEnv -Name 'TEST_VAR' -Value 'test-value'
            $content = Get-Content -Path $env:GITHUB_ENV -Raw
            $content | Should -Match 'TEST_VAR<<EOF_[a-f0-9]+'
            $content | Should -Match 'test-value'
        }

        It 'Preserves newlines in environment variable value using delimiter format' {
            Set-CIEnv -Name 'TEST_VAR' -Value "line1`nline2"
            $content = Get-Content -Path $env:GITHUB_ENV -Raw
            $content | Should -Match 'line1'
            $content | Should -Match 'line2'
            $content | Should -Not -Match '%0A'
        }

        It 'Rejects invalid variable names' {
            { Set-CIEnv -Name 'invalid-name' -Value 'test' } | Should -Throw -ExpectedMessage '*Invalid GitHub Actions environment variable name*'
            { Set-CIEnv -Name '123start' -Value 'test' } | Should -Throw
        }
    }

    Context 'In Azure DevOps environment' {
        BeforeEach {
            Clear-MockCIEnvironment
            $env:TF_BUILD = 'True'
        }

        It 'Outputs task.setvariable format' {
            $output = Set-CIEnv -Name 'test_var' -Value 'test-value'
            $output | Should -Be '##vso[task.setvariable variable=test_var]test-value'
        }

        It 'Escapes semicolons in variable name to prevent property injection' {
            $output = Set-CIEnv -Name 'test;isOutput=true' -Value 'value'
            $output | Should -Match '%AZP3B'
        }
    }

    Context 'In local environment' {
        BeforeEach {
            Clear-MockCIEnvironment
        }

        It 'Does not produce console output' {
            $output = Set-CIEnv -Name 'test_var' -Value 'test-value'
            $output | Should -BeNullOrEmpty
        }
    }

    Context 'GitHub with missing GITHUB_ENV' {
        BeforeEach {
            Clear-MockCIEnvironment
            $env:GITHUB_ACTIONS = 'true'
        }

        It 'Handles missing GITHUB_ENV gracefully' {
            { Set-CIEnv -Name 'test_var' -Value 'test-value' } | Should -Not -Throw
        }
    }
}

Describe 'Write-CIStepSummary' -Tag 'Unit' {
    BeforeAll {
        Save-CIEnvironment
    }

    AfterAll {
        Restore-CIEnvironment
    }

    Context 'In GitHub Actions environment with Content' {
        BeforeEach {
            $script:mockFiles = Initialize-MockCIEnvironment
        }

        AfterEach {
            Remove-MockCIFiles -MockFiles $script:mockFiles
        }

        It 'Writes content to GITHUB_STEP_SUMMARY file' {
            Write-CIStepSummary -Content '## Test Summary'
            $content = Get-Content -Path $env:GITHUB_STEP_SUMMARY -Raw
            $content | Should -Match '## Test Summary'
        }
    }

    Context 'In GitHub Actions environment with Path' {
        BeforeEach {
            $script:mockFiles = Initialize-MockCIEnvironment
            $script:tempSummaryFile = Join-Path ([System.IO.Path]::GetTempPath()) 'test-summary.md'
            '## Summary from file' | Set-Content -Path $script:tempSummaryFile
        }

        AfterEach {
            Remove-MockCIFiles -MockFiles $script:mockFiles
            Remove-Item -Path $script:tempSummaryFile -Force -ErrorAction SilentlyContinue
        }

        It 'Reads content from file path' {
            Write-CIStepSummary -Path $script:tempSummaryFile
            $content = Get-Content -Path $env:GITHUB_STEP_SUMMARY -Raw
            $content | Should -Match '## Summary from file'
        }
    }

    Context 'In Azure DevOps environment' {
        BeforeEach {
            Clear-MockCIEnvironment
            $env:TF_BUILD = 'True'
        }

        It 'Outputs section header and content' {
            $output = Write-CIStepSummary -Content '## Test Summary'
            $output[0] | Should -Be '##[section]Step Summary'
            $output[1] | Should -Be '## Test Summary'
        }
    }

    Context 'In local environment' {
        BeforeEach {
            Clear-MockCIEnvironment
        }

        It 'Does not produce console output' {
            $output = Write-CIStepSummary -Content '## Test Summary'
            $output | Should -BeNullOrEmpty
        }
    }
}

Describe 'Write-CIAnnotation' -Tag 'Unit' {
    BeforeAll {
        Save-CIEnvironment
    }

    AfterAll {
        Restore-CIEnvironment
    }

    Context 'In GitHub Actions environment' {
        BeforeEach {
            $script:mockFiles = Initialize-MockCIEnvironment
        }

        AfterEach {
            Remove-MockCIFiles -MockFiles $script:mockFiles
        }

        It 'Outputs warning annotation' {
            $output = Write-CIAnnotation -Message 'Test warning' -Level Warning
            $output | Should -Be '::warning::Test warning'
        }

        It 'Outputs error annotation' {
            $output = Write-CIAnnotation -Message 'Test error' -Level Error
            $output | Should -Be '::error::Test error'
        }

        It 'Outputs notice annotation' {
            $output = Write-CIAnnotation -Message 'Test notice' -Level Notice
            $output | Should -Be '::notice::Test notice'
        }

        It 'Includes file in annotation' {
            $output = Write-CIAnnotation -Message 'Test' -Level Warning -File 'src/test.ps1'
            $output | Should -Be '::warning file=src/test.ps1::Test'
        }

        It 'Normalizes backslashes to forward slashes' {
            $output = Write-CIAnnotation -Message 'Test' -Level Warning -File 'src\path\test.ps1'
            $output | Should -Be '::warning file=src/path/test.ps1::Test'
        }

        It 'Includes line number in annotation' {
            $output = Write-CIAnnotation -Message 'Test' -Level Warning -File 'test.ps1' -Line 42
            $output | Should -Be '::warning file=test.ps1,line=42::Test'
        }

        It 'Includes column number in annotation' {
            $output = Write-CIAnnotation -Message 'Test' -Level Warning -File 'test.ps1' -Line 42 -Column 10
            $output | Should -Be '::warning file=test.ps1,line=42,col=10::Test'
        }

        It 'Defaults to Warning level' {
            $output = Write-CIAnnotation -Message 'Test message'
            $output | Should -Be '::warning::Test message'
        }
    }

    Context 'In Azure DevOps environment' {
        BeforeEach {
            Clear-MockCIEnvironment
            $env:TF_BUILD = 'True'
        }

        It 'Outputs task.logissue for warning' {
            $output = Write-CIAnnotation -Message 'Test warning' -Level Warning
            $output | Should -Be '##vso[task.logissue type=warning]Test warning'
        }

        It 'Outputs task.logissue for error' {
            $output = Write-CIAnnotation -Message 'Test error' -Level Error
            $output | Should -Be '##vso[task.logissue type=error]Test error'
        }

        It 'Maps Notice to info type' {
            $output = Write-CIAnnotation -Message 'Test notice' -Level Notice
            $output | Should -Be '##vso[task.logissue type=info]Test notice'
        }

        It 'Includes sourcepath for file' {
            $output = Write-CIAnnotation -Message 'Test' -Level Warning -File 'src/test.ps1'
            $output | Should -Be '##vso[task.logissue type=warning;sourcepath=src/test.ps1]Test'
        }

        It 'Includes line and column numbers' {
            $output = Write-CIAnnotation -Message 'Test' -Level Warning -File 'test.ps1' -Line 42 -Column 10
            $output | Should -Be '##vso[task.logissue type=warning;sourcepath=test.ps1;linenumber=42;columnnumber=10]Test'
        }
    }

    Context 'In local environment' {
        BeforeEach {
            Clear-MockCIEnvironment
        }

        It 'Uses Write-Warning for all levels' {
            # Write-Warning outputs to warning stream, not standard output
            $output = Write-CIAnnotation -Message 'Test message' -Level Warning 3>&1
            $output | Should -Match 'WARNING.*Test message'
        }

        It 'Includes file location in local output' {
            $output = Write-CIAnnotation -Message 'Test' -Level Warning -File 'test.ps1' -Line 42 3>&1
            $output | Should -Match '\[test\.ps1:42\]'
        }
    }

    Context 'Workflow command injection prevention (GitHub Actions)' {
        BeforeEach {
            $script:mockFiles = Initialize-MockCIEnvironment
        }

        AfterEach {
            Remove-MockCIFiles -MockFiles $script:mockFiles
        }

        It 'Escapes newlines in message to prevent command injection' {
            $maliciousMessage = "Test`n::set-output name=pwned::true"
            $output = Write-CIAnnotation -Message $maliciousMessage -Level Warning
            $output | Should -Not -Match '::set-output'
            $output | Should -Match '%0A'
        }

        It 'Escapes carriage returns in message' {
            $maliciousMessage = "Test`r::error::Injected"
            $output = Write-CIAnnotation -Message $maliciousMessage -Level Warning
            $output | Should -Not -Match '::error::Injected'
            $output | Should -Match '%0D'
        }

        It 'Escapes percent signs in message' {
            $maliciousMessage = 'Test %0A injection attempt'
            $output = Write-CIAnnotation -Message $maliciousMessage -Level Warning
            $output | Should -Match '%250A'
        }

        It 'Escapes colons and commas in file path' {
            $maliciousFile = 'file:injection,col=1'
            $output = Write-CIAnnotation -Message 'Test' -Level Warning -File $maliciousFile
            $output | Should -Match '%3A'
            $output | Should -Match '%2C'
        }

        It 'Prevents full command injection via file parameter' {
            $maliciousFile = "path`n::error::Pwned"
            $output = Write-CIAnnotation -Message 'Test' -Level Warning -File $maliciousFile
            $output | Should -Not -Match '::error::Pwned'
        }
    }

    Context 'Workflow command injection prevention (Azure DevOps)' {
        BeforeEach {
            Clear-MockCIEnvironment
            $env:TF_BUILD = 'True'
        }

        It 'Escapes newlines in message to prevent command injection' {
            $maliciousMessage = "Test`n##vso[task.setvariable variable=pwned]true"
            $output = Write-CIAnnotation -Message $maliciousMessage -Level Warning
            $output | Should -Not -Match '##vso\[task\.setvariable'
            $output | Should -Match '%AZP0A'
        }

        It 'Escapes closing brackets in file path' {
            $maliciousFile = 'path]##vso[task.setvariable variable=pwned]true'
            $output = Write-CIAnnotation -Message 'Test' -Level Warning -File $maliciousFile
            $output | Should -Match '%AZP5D'
        }

        It 'Escapes semicolons in file path' {
            $maliciousFile = 'path;linenumber=999'
            $output = Write-CIAnnotation -Message 'Test' -Level Warning -File $maliciousFile
            $output | Should -Match '%AZP3B'
        }

        It 'Prevents full command injection via message' {
            $maliciousMessage = "Test`n##vso[task.complete result=Failed]"
            $output = Write-CIAnnotation -Message $maliciousMessage -Level Warning
            $output | Should -Not -Match '##vso\[task\.complete'
        }
    }
}

Describe 'Write-CIAnnotations' -Tag 'Unit' {
    BeforeAll {
        Save-CIEnvironment
    }

    AfterAll {
        Restore-CIEnvironment
    }

    Context 'In GitHub Actions environment' {
        BeforeEach {
            $script:mockFiles = Initialize-MockCIEnvironment
        }

        AfterEach {
            Remove-MockCIFiles -MockFiles $script:mockFiles
        }

        It 'Outputs error and warning annotations from summary' {
            $summary = [pscustomobject]@{
                Results = @(
                    [pscustomobject]@{
                        RelativePath = 'test.md'
                        Issues = @(
                            [pscustomobject]@{ Type = 'Error'; Message = 'Test error'; Line = 42 },
                            [pscustomobject]@{ Type = 'Warning'; Message = 'Test warning'; Line = 0 }
                        )
                    }
                )
            }

            $output = Write-CIAnnotations -Summary $summary
            $output | Should -Contain '::error file=test.md,line=42::Test error'
            $output | Should -Contain '::warning file=test.md,line=1::Test warning'
        }

        It 'Escapes newlines in message' {
            $summary = [pscustomobject]@{
                Results = @(
                    [pscustomobject]@{
                        RelativePath = 'test.md'
                        Issues = @(
                            [pscustomobject]@{ Type = 'Error'; Message = "line1`nline2"; Line = 1 }
                        )
                    }
                )
            }

            $output = Write-CIAnnotations -Summary $summary
            $output | Should -Match 'line1%0Aline2'
        }
    }

    Context 'In Azure DevOps environment' {
        BeforeEach {
            Clear-MockCIEnvironment
            $env:TF_BUILD = 'True'
        }

        It 'Outputs task.logissue entries for issues' {
            $summary = [pscustomobject]@{
                Results = @(
                    [pscustomobject]@{
                        RelativePath = 'test.md'
                        Issues = @(
                            [pscustomobject]@{ Type = 'Error'; Message = 'Test error'; Line = 10; Column = 4 }
                        )
                    }
                )
            }

            $output = Write-CIAnnotations -Summary $summary
            $output | Should -Be '##vso[task.logissue type=error;sourcepath=test.md;linenumber=10;columnnumber=4]Test error'
        }
    }

    Context 'In local environment' {
        BeforeEach {
            Clear-MockCIEnvironment
        }

        It 'Does not throw when emitting annotations' {
            $summary = [pscustomobject]@{
                Results = @(
                    [pscustomobject]@{
                        RelativePath = 'test.md'
                        Issues = @(
                            [pscustomobject]@{ Type = 'Warning'; Message = 'Test warning'; Line = 2 }
                        )
                    }
                )
            }

            { Write-CIAnnotations -Summary $summary } | Should -Not -Throw
        }
    }

    Context 'With no issues' {
        BeforeEach {
            Clear-MockCIEnvironment
        }

        It 'Returns nothing when no issues exist' {
            $summary = [pscustomobject]@{
                Results = @(
                    [pscustomobject]@{ RelativePath = 'test.md'; Issues = @() }
                )
            }

            $output = Write-CIAnnotations -Summary $summary
            $output | Should -BeNullOrEmpty
        }
    }
}

Describe 'Set-CITaskResult' -Tag 'Unit' {
    BeforeAll {
        Save-CIEnvironment
    }

    AfterAll {
        Restore-CIEnvironment
    }

    Context 'In GitHub Actions environment' {
        BeforeEach {
            $script:mockFiles = Initialize-MockCIEnvironment
        }

        AfterEach {
            Remove-MockCIFiles -MockFiles $script:mockFiles
        }

        It 'Outputs error for Failed result' {
            $output = Set-CITaskResult -Result Failed
            $output | Should -Be '::error::Task failed'
        }

        It 'Does not output for Succeeded result' {
            $output = Set-CITaskResult -Result Succeeded
            $output | Should -BeNullOrEmpty
        }

        It 'Does not output for SucceededWithIssues result' {
            $output = Set-CITaskResult -Result SucceededWithIssues
            $output | Should -BeNullOrEmpty
        }
    }

    Context 'In Azure DevOps environment' {
        BeforeEach {
            Clear-MockCIEnvironment
            $env:TF_BUILD = 'True'
        }

        It 'Outputs task.complete for Succeeded' {
            $output = Set-CITaskResult -Result Succeeded
            $output | Should -Be '##vso[task.complete result=Succeeded]'
        }

        It 'Outputs task.complete for SucceededWithIssues' {
            $output = Set-CITaskResult -Result SucceededWithIssues
            $output | Should -Be '##vso[task.complete result=SucceededWithIssues]'
        }

        It 'Outputs task.complete for Failed' {
            $output = Set-CITaskResult -Result Failed
            $output | Should -Be '##vso[task.complete result=Failed]'
        }
    }

    Context 'In local environment' {
        BeforeEach {
            Clear-MockCIEnvironment
        }

        It 'Does not produce console output' {
            $output = Set-CITaskResult -Result Succeeded
            $output | Should -BeNullOrEmpty
        }
    }
}

Describe 'Publish-CIArtifact' -Tag 'Unit' {
    BeforeAll {
        Save-CIEnvironment
    }

    AfterAll {
        Restore-CIEnvironment
    }

    Context 'In GitHub Actions environment' {
        BeforeEach {
            $script:mockFiles = Initialize-MockCIEnvironment
            $script:tempArtifact = Join-Path ([System.IO.Path]::GetTempPath()) 'test-artifact.txt'
            'artifact content' | Set-Content -Path $script:tempArtifact
        }

        AfterEach {
            Remove-MockCIFiles -MockFiles $script:mockFiles
            Remove-Item -Path $script:tempArtifact -Force -ErrorAction SilentlyContinue
        }

        It 'Sets artifact outputs' {
            Publish-CIArtifact -Path $script:tempArtifact -Name 'test-artifact'
            $content = Get-Content -Path $env:GITHUB_OUTPUT -Raw
            $content | Should -Match "artifact-path-test-artifact=$([regex]::Escape($script:tempArtifact))"
            $content | Should -Match 'artifact-name-test-artifact=test-artifact'
        }
    }

    Context 'In Azure DevOps environment' {
        BeforeEach {
            Clear-MockCIEnvironment
            $env:TF_BUILD = 'True'
            $script:tempArtifact = Join-Path ([System.IO.Path]::GetTempPath()) 'test-artifact.txt'
            'artifact content' | Set-Content -Path $script:tempArtifact
        }

        AfterEach {
            Remove-Item -Path $script:tempArtifact -Force -ErrorAction SilentlyContinue
        }

        It 'Outputs artifact.upload command' {
            $output = Publish-CIArtifact -Path $script:tempArtifact -Name 'test-artifact'
            $output | Should -Match '##vso\[artifact\.upload containerfolder=test-artifact;artifactname=test-artifact\]'
        }

        It 'Uses ContainerFolder when specified' {
            $output = Publish-CIArtifact -Path $script:tempArtifact -Name 'test-artifact' -ContainerFolder 'custom-folder'
            $output | Should -Match '##vso\[artifact\.upload containerfolder=custom-folder;artifactname=test-artifact\]'
        }
    }

    Context 'With non-existent path' {
        BeforeEach {
            Clear-MockCIEnvironment
            $env:TF_BUILD = 'True'
        }

        It 'Outputs warning for missing path' {
            $warning = $null
            Publish-CIArtifact -Path 'C:\nonexistent\file.txt' -Name 'test' -WarningVariable warning 3>&1
            $warning | Should -Match 'Artifact path not found'
        }

        It 'Does not produce command output for missing path' {
            $output = Publish-CIArtifact -Path 'C:\nonexistent\file.txt' -Name 'test' 3>$null
            $output | Should -BeNullOrEmpty
        }
    }

    Context 'In local environment' {
        BeforeEach {
            Clear-MockCIEnvironment
            $script:tempArtifact = Join-Path ([System.IO.Path]::GetTempPath()) 'test-artifact.txt'
            'artifact content' | Set-Content -Path $script:tempArtifact
        }

        AfterEach {
            Remove-Item -Path $script:tempArtifact -Force -ErrorAction SilentlyContinue
        }

        It 'Does not produce console output' {
            $output = Publish-CIArtifact -Path $script:tempArtifact -Name 'test-artifact'
            $output | Should -BeNullOrEmpty
        }
    }
}
