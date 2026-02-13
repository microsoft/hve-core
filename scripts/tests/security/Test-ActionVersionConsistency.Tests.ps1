#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

using module ../../security/Modules/SecurityClasses.psm1

<#
.SYNOPSIS
    Pester tests for Test-ActionVersionConsistency.ps1 functions.

.DESCRIPTION
    Tests version consistency checking functions without executing the main script.
    Uses dot-source guard pattern for function isolation.
#>

BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '../../security/Test-ActionVersionConsistency.ps1'
    . $scriptPath

    $mockPath = Join-Path $PSScriptRoot '../Mocks/GitMocks.psm1'
    Import-Module $mockPath -Force

    Save-CIEnvironment

    $script:FixturesPath = Join-Path $PSScriptRoot '../Fixtures/Workflows'
}

AfterAll {
    Restore-CIEnvironment
    Remove-Module CIHelpers -Force -ErrorAction SilentlyContinue
}

Describe 'Write-ConsistencyLog' -Tag 'Unit' {
    Context 'Log output' {
        It 'Does not throw for Info level' {
            { Write-ConsistencyLog -Message 'Test message' -Level Info } | Should -Not -Throw
        }

        It 'Does not throw for Warning level' {
            { Write-ConsistencyLog -Message 'Warning message' -Level Warning } | Should -Not -Throw
        }

        It 'Does not throw for Error level' {
            { Write-ConsistencyLog -Message 'Error message' -Level Error } | Should -Not -Throw
        }

        It 'Does not throw for Success level' {
            { Write-ConsistencyLog -Message 'Success message' -Level Success } | Should -Not -Throw
        }

        It 'Defaults to Info level when not specified' {
            { Write-ConsistencyLog -Message 'Default level test' } | Should -Not -Throw
        }
    }
}

Describe 'Get-ActionVersionViolations' -Tag 'Unit' {
    Context 'Clean workflow (no violations)' {
        It 'Returns zero violations for fully commented workflow' {
            $testPath = Join-Path $TestDrive 'clean-workflow-test'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Copy-Item -Path (Join-Path $script:FixturesPath 'consistent-versions.yml') -Destination $testPath

            $result = Get-ActionVersionViolations -WorkflowPath $testPath
            $result.Violations | Should -BeNullOrEmpty
        }

        It 'Returns correct TotalActions count' {
            $testPath = Join-Path $TestDrive 'consistent-test'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Copy-Item -Path (Join-Path $script:FixturesPath 'consistent-versions.yml') -Destination $testPath

            $result = Get-ActionVersionViolations -WorkflowPath $testPath
            $result.TotalActions | Should -Be 3
        }

        It 'Returns empty violations array for pinned-workflow.yml' {
            $testPath = Join-Path $TestDrive 'pinned-test'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Copy-Item -Path (Join-Path $script:FixturesPath 'pinned-workflow.yml') -Destination $testPath

            $result = Get-ActionVersionViolations -WorkflowPath $testPath
            $result.Violations.Count | Should -Be 0
        }
    }

    Context 'Missing version comment (single)' {
        It 'Detects SHA without version comment' {
            $testPath = Join-Path $TestDrive 'missing-single'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Copy-Item -Path (Join-Path $script:FixturesPath 'missing-version-comment.yml') -Destination $testPath

            $result = Get-ActionVersionViolations -WorkflowPath $testPath
            $missingComments = $result.Violations | Where-Object { $_.ViolationType -eq 'MissingVersionComment' }
            $missingComments.Count | Should -Be 1
        }

        It 'Returns correct violation properties for missing comment' {
            $testPath = Join-Path $TestDrive 'missing-props'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Copy-Item -Path (Join-Path $script:FixturesPath 'missing-version-comment.yml') -Destination $testPath

            $result = Get-ActionVersionViolations -WorkflowPath $testPath
            $violation = $result.Violations | Where-Object { $_.ViolationType -eq 'MissingVersionComment' } | Select-Object -First 1

            $violation.Type | Should -Be 'github-actions'
            $violation.Severity | Should -Be 'Medium'
            $violation.Name | Should -Be 'actions/checkout'
            $violation.Description | Should -Match 'missing version comment'
        }

        It 'Includes FullSha in violation Metadata' {
            $testPath = Join-Path $TestDrive 'missing-meta'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Copy-Item -Path (Join-Path $script:FixturesPath 'missing-version-comment.yml') -Destination $testPath

            $result = Get-ActionVersionViolations -WorkflowPath $testPath
            $violation = $result.Violations | Where-Object { $_.ViolationType -eq 'MissingVersionComment' } | Select-Object -First 1

            $violation.Metadata.FullSha | Should -Be 'a5ac7e51b41094c92402da3b24376905380afc29'
        }
    }

    Context 'Missing version comments (multiple)' {
        It 'Detects all missing version comments' {
            $testPath = Join-Path $TestDrive 'missing-multiple'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Copy-Item -Path (Join-Path $script:FixturesPath 'multiple-missing-comments.yml') -Destination $testPath

            $result = Get-ActionVersionViolations -WorkflowPath $testPath
            $missingComments = $result.Violations | Where-Object { $_.ViolationType -eq 'MissingVersionComment' }
            $missingComments.Count | Should -Be 3
        }

        It 'Returns unique line numbers for each violation' {
            $testPath = Join-Path $TestDrive 'missing-lines'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Copy-Item -Path (Join-Path $script:FixturesPath 'multiple-missing-comments.yml') -Destination $testPath

            $result = Get-ActionVersionViolations -WorkflowPath $testPath
            $lines = $result.Violations | ForEach-Object { $_.Line } | Sort-Object -Unique
            $lines.Count | Should -Be $result.Violations.Count
        }
    }

    Context 'Version mismatch detection' {
        It 'Detects version mismatch for same SHA across files' {
            $testPath = Join-Path $TestDrive 'mismatch-test'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Copy-Item -Path (Join-Path $script:FixturesPath 'version-mismatch-a.yml') -Destination $testPath
            Copy-Item -Path (Join-Path $script:FixturesPath 'version-mismatch-b.yml') -Destination $testPath

            $result = Get-ActionVersionViolations -WorkflowPath $testPath
            $mismatches = $result.Violations | Where-Object { $_.ViolationType -eq 'VersionMismatch' }
            $mismatches.Count | Should -Be 1
        }

        It 'Returns High severity for version mismatch' {
            $testPath = Join-Path $TestDrive 'mismatch-severity'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Copy-Item -Path (Join-Path $script:FixturesPath 'version-mismatch-a.yml') -Destination $testPath
            Copy-Item -Path (Join-Path $script:FixturesPath 'version-mismatch-b.yml') -Destination $testPath

            $result = Get-ActionVersionViolations -WorkflowPath $testPath
            $mismatch = $result.Violations | Where-Object { $_.ViolationType -eq 'VersionMismatch' } | Select-Object -First 1
            $mismatch.Severity | Should -Be 'High'
        }

        It 'Includes conflicting versions in Metadata' {
            $testPath = Join-Path $TestDrive 'mismatch-meta'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Copy-Item -Path (Join-Path $script:FixturesPath 'version-mismatch-a.yml') -Destination $testPath
            Copy-Item -Path (Join-Path $script:FixturesPath 'version-mismatch-b.yml') -Destination $testPath

            $result = Get-ActionVersionViolations -WorkflowPath $testPath
            $mismatch = $result.Violations | Where-Object { $_.ViolationType -eq 'VersionMismatch' } | Select-Object -First 1
            $mismatch.Metadata.ConflictingVersions | Should -Match 'v4\.1\.0'
            $mismatch.Metadata.ConflictingVersions | Should -Match 'v4\.1\.6'
        }

        It 'Includes affected locations in Metadata' {
            $testPath = Join-Path $TestDrive 'mismatch-locations'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Copy-Item -Path (Join-Path $script:FixturesPath 'version-mismatch-a.yml') -Destination $testPath
            Copy-Item -Path (Join-Path $script:FixturesPath 'version-mismatch-b.yml') -Destination $testPath

            $result = Get-ActionVersionViolations -WorkflowPath $testPath
            $mismatch = $result.Violations | Where-Object { $_.ViolationType -eq 'VersionMismatch' } | Select-Object -First 1
            $mismatch.Metadata.AffectedLocations.Count | Should -Be 2
        }
    }

    Context 'Non-existent path handling' {
        BeforeAll {
            # Use platform-agnostic path that guaranteed doesn't exist
            $script:NonExistentPath = Join-Path ([System.IO.Path]::GetTempPath()) "nonexistent-$(New-Guid)"
        }

        It 'Returns empty violations for non-existent path' {
            $result = Get-ActionVersionViolations -WorkflowPath $script:NonExistentPath
            $result.Violations | Should -BeNullOrEmpty
        }

        It 'Returns zero TotalActions for non-existent path' {
            $result = Get-ActionVersionViolations -WorkflowPath $script:NonExistentPath
            $result.TotalActions | Should -Be 0
        }

        It 'Returns empty ShaVersionMap for non-existent path' {
            $result = Get-ActionVersionViolations -WorkflowPath $script:NonExistentPath
            $result.ShaVersionMap.Count | Should -Be 0
        }
    }

    Context 'Empty directory handling' {
        It 'Returns empty violations for empty directory' {
            $emptyPath = Join-Path $TestDrive 'empty-workflows'
            New-Item -ItemType Directory -Path $emptyPath -Force | Out-Null

            $result = Get-ActionVersionViolations -WorkflowPath $emptyPath
            $result.Violations | Should -BeNullOrEmpty
        }

        It 'Returns zero TotalActions for empty directory' {
            $emptyPath = Join-Path $TestDrive 'empty-workflows-count'
            New-Item -ItemType Directory -Path $emptyPath -Force | Out-Null

            $result = Get-ActionVersionViolations -WorkflowPath $emptyPath
            $result.TotalActions | Should -Be 0
        }
    }

    Context 'Mixed violations (both types in one scan)' {
        It 'Detects both mismatch and missing comment violations' {
            $testPath = Join-Path $TestDrive 'mixed-violations'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            Copy-Item -Path (Join-Path $script:FixturesPath 'version-mismatch-a.yml') -Destination $testPath
            Copy-Item -Path (Join-Path $script:FixturesPath 'version-mismatch-b.yml') -Destination $testPath
            Copy-Item -Path (Join-Path $script:FixturesPath 'missing-version-comment.yml') -Destination $testPath

            $result = Get-ActionVersionViolations -WorkflowPath $testPath
            $mismatches = @($result.Violations | Where-Object { $_.ViolationType -eq 'VersionMismatch' })
            $missingComments = @($result.Violations | Where-Object { $_.ViolationType -eq 'MissingVersionComment' })

            $mismatches.Count | Should -BeGreaterThan 0
            $missingComments.Count | Should -BeGreaterThan 0
        }
    }
}

Describe 'Export-ConsistencyReport' -Tag 'Unit' {
    BeforeEach {
        $script:TestOutputPath = Join-Path $TestDrive 'report'
        New-Item -ItemType Directory -Path $script:TestOutputPath -Force | Out-Null

        # Create mock violations
        $script:MockViolations = @()

        $v1 = [DependencyViolation]::new()
        $v1.File = 'workflow.yml'
        $v1.Line = 10
        $v1.Type = 'github-actions'
        $v1.Name = 'actions/checkout'
        $v1.Version = 'a5ac7e5'
        $v1.Severity = 'Medium'
        $v1.ViolationType = 'MissingVersionComment'
        $v1.Description = 'SHA-pinned action missing version comment'
        $v1.Remediation = 'Add version comment'
        $v1.Metadata = @{ FullSha = 'a5ac7e51b41094c92402da3b24376905380afc29' }
        $script:MockViolations += $v1

        $v2 = [DependencyViolation]::new()
        $v2.File = 'other.yml'
        $v2.Line = 15
        $v2.Type = 'github-actions'
        $v2.Name = 'actions/setup-node'
        $v2.Version = '60edb5d'
        $v2.Severity = 'High'
        $v2.ViolationType = 'VersionMismatch'
        $v2.Description = 'Same SHA has conflicting version comments'
        $v2.Remediation = 'Standardize version comment'
        $v2.Metadata = @{ ConflictingVersions = 'v4.0.0, v4.0.2' }
        $script:MockViolations += $v2
    }

    Context 'Table format output' {
        It 'Does not throw for Table format' {
            { Export-ConsistencyReport -Violations $script:MockViolations -Format Table -TotalActions 5 } | Should -Not -Throw
        }

        It 'Writes file when OutputPath specified' {
            $outputFile = Join-Path $script:TestOutputPath 'report.txt'
            Export-ConsistencyReport -Violations $script:MockViolations -Format Table -OutputPath $outputFile -TotalActions 5
            Test-Path $outputFile | Should -BeTrue
        }

        It 'Reports success message when no violations' {
            # Capture Host output
            $output = Export-ConsistencyReport -Violations @() -Format Table -TotalActions 0 6>&1
            ($output -join ' ') | Should -Match 'No version consistency violations found'
        }
    }

    Context 'JSON format with OutputPath' {
        It 'Generates valid JSON' {
            $outputFile = Join-Path $script:TestOutputPath 'report.json'
            Export-ConsistencyReport -Violations $script:MockViolations -Format Json -OutputPath $outputFile -TotalActions 5

            Test-Path $outputFile | Should -BeTrue
            $content = Get-Content $outputFile -Raw
            { $content | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'Includes Timestamp field' {
            $outputFile = Join-Path $script:TestOutputPath 'report-ts.json'
            Export-ConsistencyReport -Violations $script:MockViolations -Format Json -OutputPath $outputFile -TotalActions 5

            $rawContent = Get-Content $outputFile -Raw
            $rawContent | Should -Match '"Timestamp":\s*"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}'
        }

        It 'Includes TotalActions count' {
            $outputFile = Join-Path $script:TestOutputPath 'report-total.json'
            Export-ConsistencyReport -Violations $script:MockViolations -Format Json -OutputPath $outputFile -TotalActions 10

            $content = Get-Content $outputFile -Raw | ConvertFrom-Json
            $content.TotalActions | Should -Be 10
        }

        It 'Includes MismatchCount' {
            $outputFile = Join-Path $script:TestOutputPath 'report-mismatch.json'
            Export-ConsistencyReport -Violations $script:MockViolations -Format Json -OutputPath $outputFile -TotalActions 5

            $content = Get-Content $outputFile -Raw | ConvertFrom-Json
            $content.MismatchCount | Should -Be 1
        }

        It 'Includes MissingComments count' {
            $outputFile = Join-Path $script:TestOutputPath 'report-missing.json'
            Export-ConsistencyReport -Violations $script:MockViolations -Format Json -OutputPath $outputFile -TotalActions 5

            $content = Get-Content $outputFile -Raw | ConvertFrom-Json
            $content.MissingComments | Should -Be 1
        }

        It 'Includes Violations array' {
            $outputFile = Join-Path $script:TestOutputPath 'report-violations.json'
            Export-ConsistencyReport -Violations $script:MockViolations -Format Json -OutputPath $outputFile -TotalActions 5

            $content = Get-Content $outputFile -Raw | ConvertFrom-Json
            $content.Violations.Count | Should -Be 2
        }
    }

    Context 'SARIF format schema validation' {
        It 'Generates valid SARIF structure' {
            $outputFile = Join-Path $script:TestOutputPath 'report.sarif'
            Export-ConsistencyReport -Violations $script:MockViolations -Format Sarif -OutputPath $outputFile -TotalActions 5

            Test-Path $outputFile | Should -BeTrue
            $content = Get-Content $outputFile -Raw | ConvertFrom-Json
            $content.version | Should -Be '2.1.0'
        }

        It 'Includes schema reference' {
            $outputFile = Join-Path $script:TestOutputPath 'report-schema.sarif'
            Export-ConsistencyReport -Violations $script:MockViolations -Format Sarif -OutputPath $outputFile -TotalActions 5

            $content = Get-Content $outputFile -Raw | ConvertFrom-Json
            $content.'$schema' | Should -Match 'sarif-2\.1\.0\.json'
        }

        It 'Includes tool driver information' {
            $outputFile = Join-Path $script:TestOutputPath 'report-tool.sarif'
            Export-ConsistencyReport -Violations $script:MockViolations -Format Sarif -OutputPath $outputFile -TotalActions 5

            $content = Get-Content $outputFile -Raw | ConvertFrom-Json
            $content.runs[0].tool.driver.name | Should -Be 'action-version-consistency'
        }

        It 'Maps violations to SARIF results' {
            $outputFile = Join-Path $script:TestOutputPath 'report-results.sarif'
            Export-ConsistencyReport -Violations $script:MockViolations -Format Sarif -OutputPath $outputFile -TotalActions 5

            $content = Get-Content $outputFile -Raw | ConvertFrom-Json
            $content.runs[0].results.Count | Should -Be 2
        }

        It 'Maps MissingVersionComment to warning level' {
            $outputFile = Join-Path $script:TestOutputPath 'report-warning.sarif'
            Export-ConsistencyReport -Violations $script:MockViolations -Format Sarif -OutputPath $outputFile -TotalActions 5

            $content = Get-Content $outputFile -Raw | ConvertFrom-Json
            $warningResult = $content.runs[0].results | Where-Object { $_.ruleId -eq 'missing-version-comment' }
            $warningResult.level | Should -Be 'warning'
        }

        It 'Maps VersionMismatch to error level' {
            $outputFile = Join-Path $script:TestOutputPath 'report-error.sarif'
            Export-ConsistencyReport -Violations $script:MockViolations -Format Sarif -OutputPath $outputFile -TotalActions 5

            $content = Get-Content $outputFile -Raw | ConvertFrom-Json
            $errorResult = $content.runs[0].results | Where-Object { $_.ruleId -eq 'version-mismatch' }
            $errorResult.level | Should -Be 'error'
        }

        It 'Includes locations with file and line' {
            $outputFile = Join-Path $script:TestOutputPath 'report-locations.sarif'
            Export-ConsistencyReport -Violations $script:MockViolations -Format Sarif -OutputPath $outputFile -TotalActions 5

            $content = Get-Content $outputFile -Raw | ConvertFrom-Json
            $result = $content.runs[0].results[0]
            $result.locations[0].physicalLocation.artifactLocation.uri | Should -Not -BeNullOrEmpty
            $result.locations[0].physicalLocation.region.startLine | Should -BeGreaterThan 0
        }
    }

    Context 'Empty violations array' {
        It 'Handles empty violations for JSON format' {
            $outputFile = Join-Path $script:TestOutputPath 'empty.json'
            Export-ConsistencyReport -Violations @() -Format Json -OutputPath $outputFile -TotalActions 0

            $content = Get-Content $outputFile -Raw | ConvertFrom-Json
            $content.Violations.Count | Should -Be 0
            $content.MismatchCount | Should -Be 0
            $content.MissingComments | Should -Be 0
        }

        It 'Handles empty violations for SARIF format' {
            $outputFile = Join-Path $script:TestOutputPath 'empty.sarif'
            Export-ConsistencyReport -Violations @() -Format Sarif -OutputPath $outputFile -TotalActions 0

            $content = Get-Content $outputFile -Raw | ConvertFrom-Json
            $content.runs[0].results.Count | Should -Be 0
        }
    }

    Context 'Multiple violations of each type' {
        BeforeEach {
            $script:MultipleViolations = @()

            # Add 3 MissingVersionComment violations
            for ($i = 1; $i -le 3; $i++) {
                $v = [DependencyViolation]::new()
                $v.File = "workflow$i.yml"
                $v.Line = $i * 10
                $v.Type = 'github-actions'
                $v.Name = "actions/action$i"
                $v.Version = "sha$i"
                $v.Severity = 'Medium'
                $v.ViolationType = 'MissingVersionComment'
                $v.Description = 'Missing comment'
                $script:MultipleViolations += $v
            }

            # Add 2 VersionMismatch violations
            for ($i = 1; $i -le 2; $i++) {
                $v = [DependencyViolation]::new()
                $v.File = "mismatch$i.yml"
                $v.Line = $i * 5
                $v.Type = 'github-actions'
                $v.Name = "actions/mismatch$i"
                $v.Version = "msha$i"
                $v.Severity = 'High'
                $v.ViolationType = 'VersionMismatch'
                $v.Description = 'Version mismatch'
                $script:MultipleViolations += $v
            }
        }

        It 'Counts multiple MissingVersionComment violations correctly' {
            $outputFile = Join-Path $script:TestOutputPath 'multiple.json'
            Export-ConsistencyReport -Violations $script:MultipleViolations -Format Json -OutputPath $outputFile -TotalActions 10

            $content = Get-Content $outputFile -Raw | ConvertFrom-Json
            $content.MissingComments | Should -Be 3
        }

        It 'Counts multiple VersionMismatch violations correctly' {
            $outputFile = Join-Path $script:TestOutputPath 'multiple-mismatch.json'
            Export-ConsistencyReport -Violations $script:MultipleViolations -Format Json -OutputPath $outputFile -TotalActions 10

            $content = Get-Content $outputFile -Raw | ConvertFrom-Json
            $content.MismatchCount | Should -Be 2
        }
    }
}

Describe 'Main Script Execution' -Tag 'Unit' {
    BeforeAll {
        $script:TestScript = (Resolve-Path (Join-Path $PSScriptRoot '../../security/Test-ActionVersionConsistency.ps1')).Path
        $script:FixturesPath = Join-Path $PSScriptRoot '../Fixtures/Workflows'
        # Use cross-platform temp directory (accessible from child process, unlike $TestDrive)
        $tempBase = [System.IO.Path]::GetTempPath()
        $script:MainTestRoot = Join-Path $tempBase "pester-main-$(Get-Random)"
        New-Item -ItemType Directory -Path $script:MainTestRoot -Force | Out-Null
    }

    AfterAll {
        if ($script:MainTestRoot -and (Test-Path $script:MainTestRoot)) {
            Remove-Item -Path $script:MainTestRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Exit code handling' {
        BeforeEach {
            $script:TestWorkspace = Join-Path $script:MainTestRoot "test-$(Get-Random)"
            New-Item -ItemType Directory -Path $script:TestWorkspace -Force | Out-Null
        }

        AfterEach {
            if ($script:TestWorkspace -and (Test-Path $script:TestWorkspace)) {
                Remove-Item -Path $script:TestWorkspace -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It 'Returns exit code 0 when no violations and no fail flags' {
            Copy-Item -Path (Join-Path $script:FixturesPath 'pinned-workflow.yml') -Destination $script:TestWorkspace

            $null = pwsh -NoProfile -Command "& '$script:TestScript' -Path '$script:TestWorkspace' -Format Json" 2>&1
            $LASTEXITCODE | Should -Be 0
        }

        It 'Returns exit code 1 when FailOnMismatch and mismatches exist' {
            Copy-Item -Path (Join-Path $script:FixturesPath 'version-mismatch-a.yml') -Destination $script:TestWorkspace
            Copy-Item -Path (Join-Path $script:FixturesPath 'version-mismatch-b.yml') -Destination $script:TestWorkspace

            $tempScript = Join-Path $script:TestWorkspace 'run-test.ps1'
            $scriptContent = @"
& '$($script:TestScript)' -Path '$($script:TestWorkspace)' -Format Json -FailOnMismatch
exit `$LASTEXITCODE
"@
            Set-Content -Path $tempScript -Value $scriptContent
            $proc = Start-Process -FilePath 'pwsh' -ArgumentList @('-NoProfile', '-File', $tempScript) -Wait -PassThru -NoNewWindow
            $proc.ExitCode | Should -Be 1
        }

        It 'Returns exit code 1 when FailOnMissingComment and missing comments exist' {
            Copy-Item -Path (Join-Path $script:FixturesPath 'missing-version-comment.yml') -Destination $script:TestWorkspace

            $tempScript = Join-Path $script:TestWorkspace 'run-test.ps1'
            $scriptContent = @"
& '$($script:TestScript)' -Path '$($script:TestWorkspace)' -Format Json -FailOnMissingComment
exit `$LASTEXITCODE
"@
            Set-Content -Path $tempScript -Value $scriptContent
            $proc = Start-Process -FilePath 'pwsh' -ArgumentList @('-NoProfile', '-File', $tempScript) -Wait -PassThru -NoNewWindow
            $proc.ExitCode | Should -Be 1
        }

        It 'Returns exit code 0 when violations exist but no fail flags set' {
            Copy-Item -Path (Join-Path $script:FixturesPath 'missing-version-comment.yml') -Destination $script:TestWorkspace

            $null = pwsh -NoProfile -Command "& '$script:TestScript' -Path '$script:TestWorkspace' -Format Json" 2>&1
            $LASTEXITCODE | Should -Be 0
        }
    }
}
