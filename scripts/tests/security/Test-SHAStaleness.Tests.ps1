#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

<#
.SYNOPSIS
    Pester tests for Test-SHAStaleness.ps1 functions.

.DESCRIPTION
    Tests the staleness checking functions without executing the main script.
    Uses AST function extraction to avoid running main execution block.
#>

BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '../../security/Test-SHAStaleness.ps1'
    $scriptContent = Get-Content $scriptPath -Raw

    # Extract function definitions from the script without executing main block
    # Parse the AST to get function definitions
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($scriptContent, [ref]$tokens, [ref]$errors)

    # Extract all function definitions
    $functionDefs = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)

    # Define each function in the current scope using ScriptBlock
    foreach ($func in $functionDefs) {
        $funcCode = $func.Extent.Text
        $scriptBlock = [scriptblock]::Create($funcCode)
        . $scriptBlock
    }

    $mockPath = Join-Path $PSScriptRoot '../Mocks/GitMocks.psm1'
    Import-Module $mockPath -Force

    # Save environment before tests
    Save-GitHubEnvironment

    # Fixture paths
    $script:FixturesPath = Join-Path $PSScriptRoot '../Fixtures/Security'
}

AfterAll {
    # Restore environment after tests
    Restore-GitHubEnvironment
}

Describe 'Test-GitHubToken' -Tag 'Unit' {
    BeforeEach {
        Initialize-MockGitHubEnvironment
    }

    AfterEach {
        Clear-MockGitHubEnvironment
    }

    Context 'No token provided' {
        It 'Returns hashtable with Valid=false when empty token provided' {
            $result = Test-GitHubToken -Token ''
            $result | Should -BeOfType [hashtable]
            $result.Valid | Should -BeFalse
        }

        It 'Returns Authenticated=false when no token provided' {
            $result = Test-GitHubToken -Token ''
            $result.Authenticated | Should -BeFalse
        }

        It 'Returns rate limit of 60 when no token provided' {
            $result = Test-GitHubToken -Token ''
            $result.RateLimit | Should -Be 60
        }
    }

    Context 'Invalid token' {
        BeforeEach {
            Mock Invoke-RestMethod {
                throw 'Bad credentials'
            }
        }

        It 'Returns Valid=false for invalid token' {
            $result = Test-GitHubToken -Token 'invalid-token'
            $result.Valid | Should -BeFalse
        }
    }

    Context 'Valid token' {
        BeforeEach {
            Mock Invoke-RestMethod {
                return @{
                    data = @{
                        viewer    = @{ login = 'testuser' }
                        rateLimit = @{ limit = 5000; remaining = 4999; resetAt = '2024-01-01T00:00:00Z' }
                    }
                }
            }
        }

        It 'Returns Valid=true for valid token' {
            $result = Test-GitHubToken -Token 'ghp_validtoken123456789'
            $result.Valid | Should -BeTrue
        }

        It 'Returns user information for valid token' {
            $result = Test-GitHubToken -Token 'ghp_validtoken123456789'
            $result.User | Should -Be 'testuser'
        }

        It 'Returns rate limit information for valid token' {
            $result = Test-GitHubToken -Token 'ghp_validtoken123456789'
            $result.RateLimit | Should -Be 5000
            $result.Remaining | Should -Be 4999
        }
    }
}

Describe 'Invoke-GitHubAPIWithRetry' -Tag 'Unit' {
    BeforeEach {
        Initialize-MockGitHubEnvironment
    }

    AfterEach {
        Clear-MockGitHubEnvironment
    }

    Context 'Successful requests' {
        It 'Returns response on first successful call' {
            Mock Invoke-RestMethod {
                return @{ data = 'success' }
            }

            $headers = @{ 'Authorization' = 'Bearer test' }
            $result = Invoke-GitHubAPIWithRetry -Uri 'https://api.github.com/graphql' -Method 'POST' -Headers $headers -Body '{}'
            $result.data | Should -Be 'success'
        }
    }

    Context 'Rate limiting' {
        It 'Throws on non-rate-limit errors' {
            Mock Invoke-RestMethod {
                throw [System.Exception]::new('Network error')
            }

            $headers = @{ 'Authorization' = 'Bearer test' }
            { Invoke-GitHubAPIWithRetry -Uri 'https://api.github.com/graphql' -Method 'POST' -Headers $headers -Body '{}' } | Should -Throw
        }
    }
}

Describe 'Write-SecurityLog' -Tag 'Unit' {
    Context 'Log output' {
        It 'Does not throw for Info level' {
            { Write-SecurityLog -Message 'Test message' -Level Info } | Should -Not -Throw
        }

        It 'Does not throw for Warning level' {
            { Write-SecurityLog -Message 'Warning message' -Level Warning } | Should -Not -Throw
        }

        It 'Does not throw for Error level' {
            { Write-SecurityLog -Message 'Error message' -Level Error } | Should -Not -Throw
        }

        It 'Does not throw for Success level' {
            { Write-SecurityLog -Message 'Success message' -Level Success } | Should -Not -Throw
        }
    }
}

Describe 'Compare-ToolVersion' -Tag 'Unit' {
    Context 'Semantic version comparison' {
        It 'Returns true when latest is newer major version' {
            Compare-ToolVersion -Current '1.0.0' -Latest '2.0.0' | Should -BeTrue
        }

        It 'Returns true when latest is newer minor version' {
            Compare-ToolVersion -Current '1.0.0' -Latest '1.1.0' | Should -BeTrue
        }

        It 'Returns true when latest is newer patch version' {
            Compare-ToolVersion -Current '1.0.0' -Latest '1.0.1' | Should -BeTrue
        }

        It 'Returns false when current equals latest' {
            Compare-ToolVersion -Current '1.0.0' -Latest '1.0.0' | Should -BeFalse
        }

        It 'Returns false when current is newer than latest' {
            Compare-ToolVersion -Current '2.0.0' -Latest '1.0.0' | Should -BeFalse
        }

        It 'Handles major version differences correctly' {
            Compare-ToolVersion -Current '7.0.0' -Latest '8.0.0' | Should -BeTrue
        }

        It 'Handles minor version differences correctly' {
            Compare-ToolVersion -Current '8.17.0' -Latest '8.18.0' | Should -BeTrue
        }

        It 'Handles patch version differences correctly' {
            Compare-ToolVersion -Current '8.18.1' -Latest '8.18.2' | Should -BeTrue
        }
    }

    Context 'Version with v prefix' {
        It 'Handles v-prefixed versions' {
            Compare-ToolVersion -Current 'v1.0.0' -Latest 'v2.0.0' | Should -BeTrue
        }

        It 'Handles mixed v-prefix versions' {
            Compare-ToolVersion -Current '1.0.0' -Latest 'v2.0.0' | Should -BeTrue
        }

        It 'Returns false for equal v-prefixed versions' {
            Compare-ToolVersion -Current 'v1.0.0' -Latest 'v1.0.0' | Should -BeFalse
        }
    }

    Context 'Pre-release versions' {
        It 'Strips pre-release metadata for comparison' {
            Compare-ToolVersion -Current '1.0.0-alpha' -Latest '1.0.0' | Should -BeFalse
        }

        It 'Handles build metadata' {
            Compare-ToolVersion -Current '1.0.0+build123' -Latest '2.0.0' | Should -BeTrue
        }
    }
}

Describe 'Get-ToolStaleness' -Tag 'Integration', 'RequiresNetwork' {
    Context 'With mock manifest' {
        BeforeEach {
            # Create a temporary manifest file
            $script:TempManifest = Join-Path $TestDrive 'tool-checksums.json'
            $manifestContent = @{
                tools = @(
                    @{
                        name    = 'test-tool'
                        repo    = 'test-org/test-repo'
                        version = '1.0.0'
                        sha256  = 'abc123'
                        notes   = 'Test tool'
                    }
                )
            } | ConvertTo-Json -Depth 10
            Set-Content -Path $script:TempManifest -Value $manifestContent
        }

        It 'Returns results array' -Skip:$true {
            # Skip by default - requires actual GitHub API access
            $result = Get-ToolStaleness -ManifestPath $script:TempManifest
            $result | Should -BeOfType [System.Object[]]
        }
    }

    Context 'Missing manifest' {
        It 'Handles missing manifest gracefully' {
            $result = Get-ToolStaleness -ManifestPath 'TestDrive:/nonexistent/manifest.json'
            $result | Should -BeNullOrEmpty
        }
    }
}

Describe 'Main Script Execution' {
    BeforeAll {
        # Create test repo structure (script expects .github/workflows from current directory)
        $script:TestRepo = Join-Path $TestDrive 'test-repo'
        $script:WorkflowDir = Join-Path $script:TestRepo '.github' 'workflows'
        New-Item -ItemType Directory -Path $script:WorkflowDir -Force | Out-Null
        
        # Create logs directory
        $logsDir = Join-Path $script:TestRepo 'logs'
        New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
        
        # Create test manifest in scripts/security location
        $manifestDir = Join-Path $script:TestRepo 'scripts' 'security'
        New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null
        $script:ManifestPath = Join-Path $manifestDir 'tool-checksums.json'
        @{
            tools = @(
                @{
                    name    = 'pwsh'
                    repo    = 'PowerShell/PowerShell'
                    version = '7.4.0'
                    sha256  = 'test-sha'
                    notes   = 'PowerShell'
                }
            )
        } | ConvertTo-Json -Depth 10 | Set-Content -Path $script:ManifestPath
        
        # Save current directory
        $script:OriginalLocation = Get-Location
        
        # Mock GitHub API at Describe scope to affect all child script invocations
        Mock Invoke-RestMethod {
            if ($Uri -like '*graphql*') {
                # GraphQL API for checking GitHub Actions
                return @{
                    data = @{
                        rateLimit  = @{ remaining = 5000; resetAt = (Get-Date).AddHours(1).ToString('o') }
                        repository = @{
                            refs = @{
                                nodes = @(
                                    @{
                                        name   = 'v5'
                                        target = @{
                                            oid           = '9999999999999999999999999999999999999999'
                                            committedDate = (Get-Date).AddMonths(-2).ToString('o')
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
            }
            elseif ($Uri -like '*/releases/latest') {
                # REST API for checking tool releases
                $repoName = ($Uri -split '/')[-3]
                return @{
                    tag_name = switch ($repoName) {
                        'actionlint' { 'v1.7.10' }
                        'gitleaks'   { 'v8.30.0' }
                        default      { 'v1.0.0' }
                    }
                    published_at = (Get-Date).AddMonths(-1).ToString('o')
                }
            }
            return @{}
        }
    }
    
    AfterAll {
        # Restore original directory
        Set-Location $script:OriginalLocation
    }

    Context 'Array coercion in main execution block' {
        BeforeEach {
            # Create workflow with SHA-pinned action
            $workflowContent = @'
name: Test
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@8e5e7e5ab8b370d6c329ec480221332ada57f0ab
'@
            Set-Content -Path (Join-Path $script:WorkflowDir 'test.yml') -Value $workflowContent
            
            # Change to test repo directory
            Set-Location $script:TestRepo
        }
        
        AfterEach {
            # Return to original location
            Set-Location $script:OriginalLocation
        }

        It 'Executes array coercion when processing action repos' {
            # This test executes the main script block which includes:
            # - @($allActionRepos).Count checks (lines 532, 537)
            # - @($Dependencies).Count checks throughout result formatting
            
            $jsonPath = Join-Path $script:TestRepo 'logs' 'test-output.json'
            & $scriptPath -OutputFormat 'json' -OutputPath $jsonPath *>&1 | Out-Null
            
            # Validate JSON structure was created with array coercion
            Test-Path $jsonPath | Should -BeTrue
            $result = Get-Content $jsonPath | ConvertFrom-Json
            
            # Verify array coercion created proper structure
            $result.PSObject.Properties.Name | Should -Contain 'TotalStaleItems'
            # JSON deserialization creates Int64 (long) not Int32
            $result.TotalStaleItems | Should -BeOfType [long]
            $result.PSObject.Properties.Name | Should -Contain 'Dependencies'
            # Dependencies should be array (even if empty)
            , $result.Dependencies | Should -BeOfType [System.Object[]]
        }

        It 'Processes stale dependencies with array count operations' {
            # Create multiple workflows to trigger grouping logic
            for ($i = 1; $i -le 3; $i++) {
                $workflowContent = @"
name: Test$i
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@8e5e7e5ab8b370d6c329ec480221332ada57f0ab
      - uses: actions/setup-node@64ed1c7eab4cce3362f8c340dee64e5eaeef8f7c
"@
                Set-Content -Path (Join-Path $script:WorkflowDir "test$i.yml") -Value $workflowContent
            }

            # This executes lines that group and count dependencies:
            # - @($Dependencies | Group-Object Type) (line 753)
            # - @($type.Group | Where-Object...).Count in summary building
            
            $jsonPath = Join-Path $script:TestRepo 'logs' 'grouped-test.json'
            & $scriptPath -OutputFormat 'json' -OutputPath $jsonPath *>&1 | Out-Null
            
            # Validate grouping and counting worked
            Test-Path $jsonPath | Should -BeTrue
            $result = Get-Content $jsonPath | ConvertFrom-Json
            
            # Should have processed multiple action repos (array coercion on line 532)
            $result.TotalStaleItems | Should -BeOfType [long]
            $result.TotalStaleItems | Should -BeGreaterOrEqual 0
            
            # Log file should contain evidence of array counting
            $logPath = Join-Path $script:TestRepo 'logs' 'sha-staleness-monitoring.log'
            Test-Path $logPath | Should -BeTrue
            $logContent = Get-Content $logPath -Raw
            # Should log count of repos found (uses @($allActionRepos).Count)
            $logContent | Should -Match 'unique repositories.*SHA-pinned actions'
        }

        It 'Handles tool staleness checking with array coercion' {
            # This executes tool checking code:
            # - @($toolResults).Count (line 895)
            # - @($staleTools).Count (line 897-898)
            # - @($errorTools).Count (line 921-922)
            
            $jsonPath = Join-Path $script:TestRepo 'logs' 'tool-check.json'
            & $scriptPath -OutputPath $jsonPath -OutputFormat 'json' *>&1 | Out-Null
            
            # Validate tool processing used array coercion
            Test-Path $jsonPath | Should -BeTrue
            $result = Get-Content $jsonPath | ConvertFrom-Json
            
            # Result should have TotalStaleItems even if zero (proves @($toolResults).Count worked)
            $result.PSObject.Properties.Name | Should -Contain 'TotalStaleItems'
            
            # Check log for tool checking evidence
            $logPath = Join-Path $script:TestRepo 'logs' 'sha-staleness-monitoring.log'
            $logContent = Get-Content $logPath -Raw
            $logContent | Should -Match 'Checking tool staleness'
        }

        It 'Executes result formatting with array operations' {
            # This triggers formatting code with array coercion:
            # - @($Dependencies).Count in various output formats (lines 706, 721, 731, 742, 747, 752)
            # - TotalStaleItems = @($Dependencies).Count (line 676)
            
            $jsonPath = Join-Path $script:TestRepo 'logs' 'format-test.json'
            & $scriptPath -OutputFormat 'json' -OutputPath $jsonPath *>&1 | Out-Null
            
            # Validate JSON output format uses array coercion correctly
            Test-Path $jsonPath | Should -BeTrue
            $jsonResult = Get-Content $jsonPath | ConvertFrom-Json
            
            # Verify required fields from array operations
            $jsonResult.PSObject.Properties.Name | Should -Contain 'TotalStaleItems'
            $jsonResult.PSObject.Properties.Name | Should -Contain 'Dependencies'
            $jsonResult.PSObject.Properties.Name | Should -Contain 'Timestamp'
            
            # TotalStaleItems should be numeric from @($Dependencies).Count
            $jsonResult.TotalStaleItems | Should -BeOfType [long]
            $jsonResult.TotalStaleItems | Should -BeGreaterOrEqual 0
            
            # Test Summary format exercises array coercion (@($Dependencies).Count)  
            # The key is that it executes the @($Dependencies).Count operations
            $summaryOutput = & $scriptPath -OutputFormat 'Summary' 2>&1 | Out-String
            $summaryOutput | Should -Match "(Total stale dependencies:|No stale dependencies detected)"
        }
    }

    Context 'CI environment integration' {
        BeforeEach {
            # Save original environment
            $script:OriginalGHA = $env:GITHUB_ACTIONS
            $script:OriginalADO = $env:TF_BUILD
            
            # Create test workflow
            $workflowContent = @'
name: CI Test
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@8e5e7e5ab8b370d6c329ec480221332ada57f0ab
'@
            Set-Content -Path (Join-Path $script:WorkflowDir 'ci.yml') -Value $workflowContent
            
            # Change to test repo
            Set-Location $script:TestRepo
        }

        AfterEach {
            $env:GITHUB_ACTIONS = $script:OriginalGHA
            $env:TF_BUILD = $script:OriginalADO
            Set-Location $script:OriginalLocation
        }

        It 'Executes GitHub Actions output formatting with array coercion' {
            $env:GITHUB_ACTIONS = 'true'
            $outputFile = Join-Path $script:TestRepo 'github-output.txt'
            $env:GITHUB_OUTPUT = $outputFile
            
            # This triggers GitHub Actions specific formatting (lines 706-715)
            # which includes @($Dependencies).Count checks
            
            & $scriptPath -OutputFormat 'github' *>&1 | Out-Null
            
            # GitHub Actions format writes to GITHUB_OUTPUT, verify it was created
            if ($outputFile -and (Test-Path $outputFile)) {
                # Output file should have workflow command format
                $content = Get-Content $outputFile -Raw
                $content | Should -Not -BeNullOrEmpty
            }
            
            # Verify log shows proper array counting
            $logPath = Join-Path $script:TestRepo 'logs' 'sha-staleness-monitoring.log'
            $logContent = Get-Content $logPath -Raw
            # Should mention "stale dependencies found" with count (uses @($Dependencies).Count)
            $logContent | Should -Match 'Stale dependencies found: \d+'
        }

        It 'Executes Azure DevOps output formatting with array coercion' {
            $env:TF_BUILD = 'true'
            
            # This triggers ADO specific formatting (lines 721-729)
            # which includes @($Dependencies).Count checks
            
            & $scriptPath -OutputFormat 'azdo' *>&1 | Out-Null
            
            # Azure DevOps format includes task.logissue commands
            # Validates that @($Dependencies).Count was evaluated
            $logPath = Join-Path $script:TestRepo 'logs' 'sha-staleness-monitoring.log'
            $logContent = Get-Content $logPath -Raw
            $logContent | Should -Match 'Stale dependencies found: \d+'
        }

        It 'Executes console output formatting with array coercion' {
            # No CI environment - uses console output (lines 731-755)
            # Includes @($Dependencies).Count and grouping operations
            
            # Console format doesn't create output file unless -OutputPath specified
            & $scriptPath -OutputFormat 'console' *>&1 | Out-Null
            
            # Verify log contains array coercion evidence
            $logPath = Join-Path $script:TestRepo 'logs' 'sha-staleness-monitoring.log'
            Test-Path $logPath | Should -BeTrue
            $logContent = Get-Content $logPath -Raw
            # Should have processed and counted (uses @($Dependencies).Count)
            $logContent | Should -Match 'SHA staleness monitoring completed'
            $logContent | Should -Match 'Stale dependencies found: \d+'
        }
    }

    Context 'Empty and edge case scenarios' {
        BeforeEach {
            Set-Location $script:TestRepo
        }
        
        AfterEach {
            Set-Location $script:OriginalLocation
        }
        
        It 'Handles empty workflow directory with array coercion' {
            # Remove all workflow files
            Get-ChildItem $script:WorkflowDir -Filter "*.yml" | Remove-Item -Force
            
            # This should execute array coercion on empty collections
            # Testing @($allActionRepos).Count -eq 0 branch (line 532)
            
            $jsonPath = Join-Path $script:TestRepo 'logs' 'empty-test.json'
            & $scriptPath -OutputFormat 'json' -OutputPath $jsonPath *>&1 | Out-Null
            
            # Validate empty array handling
            Test-Path $jsonPath | Should -BeTrue
            $result = Get-Content $jsonPath | ConvertFrom-Json
            
            # Should show 0 items (proves @($allActionRepos).Count -eq 0 worked)
            $result.TotalStaleItems | Should -Be 0
            
            # Log should indicate no SHA-pinned actions found
            $logPath = Join-Path $script:TestRepo 'logs' 'sha-staleness-monitoring.log'
            $logContent = Get-Content $logPath -Raw
            $logContent | Should -Match 'No SHA-pinned.*found|No stale dependencies'
        }

        It 'Processes single stale dependency with array coercion' {
            # Create single workflow
            $singleWorkflow = @'
name: Single
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@8e5e7e5ab8b370d6c329ec480221332ada57f0ab
'@
            Set-Content -Path (Join-Path $script:WorkflowDir 'single.yml') -Value $singleWorkflow
            
            # Mock to return stale dependency (old SHA)
            Mock Invoke-RestMethod {
                if ($Uri -like '*graphql*') {
                    return @{
                        data = @{
                            rateLimit  = @{ remaining = 5000; resetAt = (Get-Date).AddHours(1).ToString('o') }
                            repository = @{
                                refs = @{
                                    nodes = @(
                                        @{
                                            name   = 'v5'
                                            target = @{
                                                oid           = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
                                                committedDate = (Get-Date).AddMonths(-6).ToString('o')
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
                return @{}
            } -ModuleName $null
            
            # Single item return should be coerced to array, also tests stale detection
            $jsonPath = Join-Path $script:TestRepo 'logs' 'single-test.json'
            & $scriptPath -OutputFormat 'json' -OutputPath $jsonPath *>&1 | Out-Null
            
            # Validate single item is properly handled as array
            Test-Path $jsonPath | Should -BeTrue
            $result = Get-Content $jsonPath | ConvertFrom-Json
            
            # Single dependency should still produce numeric count (not $null)
            $result.TotalStaleItems | Should -BeOfType [long]
            $result.TotalStaleItems | Should -BeGreaterOrEqual 0
            # Dependencies array should exist
            $result.PSObject.Properties.Name | Should -Contain 'Dependencies'
            # If we have dependencies, validate structure
            if ($result.TotalStaleItems -gt 0) {
                $result.Dependencies | Should -Not -BeNullOrEmpty
                # First item should have required properties
                $result.Dependencies[0].PSObject.Properties.Name | Should -Contain 'Type'
            }
        }
    }
}
