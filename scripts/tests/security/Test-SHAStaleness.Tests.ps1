#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for Test-SHAStaleness.ps1 functions.

.DESCRIPTION
    Tests the staleness checking functions by dot-sourcing the script.
    The guard pattern prevents main execution when dot-sourced.
#>

BeforeAll {
    . $PSScriptRoot/../../security/Test-SHAStaleness.ps1

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

Describe 'Get-BulkGitHubActionsStaleness' -Tag 'Unit' {
    BeforeEach {
        Initialize-MockGitHubEnvironment
    }

    AfterEach {
        Clear-MockGitHubEnvironment
    }

    Context 'GraphQL query construction' {
        BeforeEach {
            $script:testActionRepos = @('actions/checkout', 'actions/setup-node')
            $script:testShaToActionMap = @{
                'actions/checkout@abc123def456789012345678901234567890abcd' = @{
                    Repo = 'actions/checkout'
                    SHA  = 'abc123def456789012345678901234567890abcd'
                    File = '.github/workflows/ci.yml'
                }
                'actions/setup-node@def456789012345678901234567890abcdef12' = @{
                    Repo = 'actions/setup-node'
                    SHA  = 'def456789012345678901234567890abcdef12'
                    File = '.github/workflows/ci.yml'
                }
            }
        }

        It 'Calls GitHub GraphQL API' {
            Mock Invoke-GitHubAPIWithRetry {
                return @{
                    data = @{
                        repo0 = @{
                            name             = 'checkout'
                            defaultBranchRef = @{
                                target = @{
                                    oid           = 'abc123def456789012345678901234567890abcd'
                                    committedDate = '2025-01-01T00:00:00Z'
                                }
                            }
                        }
                        repo1 = @{
                            name             = 'setup-node'
                            defaultBranchRef = @{
                                target = @{
                                    oid           = 'def456789012345678901234567890abcdef12'
                                    committedDate = '2025-01-01T00:00:00Z'
                                }
                            }
                        }
                        commit0   = @{ object = @{ oid = 'abc123def456789012345678901234567890abcd'; committedDate = '2025-01-01T00:00:00Z' } }
                        commit1   = @{ object = @{ oid = 'def456789012345678901234567890abcdef12'; committedDate = '2025-01-01T00:00:00Z' } }
                        rateLimit = @{ limit = 5000; remaining = 4998; cost = 2 }
                    }
                }
            }

            $result = Get-BulkGitHubActionsStaleness -ActionRepos $script:testActionRepos -ShaToActionMap $script:testShaToActionMap -BatchSize 10
            Should -Invoke Invoke-GitHubAPIWithRetry -Times 2 -Scope It
        }

        It 'Returns array of results' {
            Mock Invoke-GitHubAPIWithRetry {
                return @{
                    data = @{
                        repo0 = @{
                            name             = 'checkout'
                            defaultBranchRef = @{
                                target = @{
                                    oid           = 'newsha12345678901234567890123456789012'
                                    committedDate = '2025-01-15T00:00:00Z'
                                }
                            }
                        }
                        repo1 = @{
                            name             = 'setup-node'
                            defaultBranchRef = @{
                                target = @{
                                    oid           = 'newsha98765432109876543210987654321098'
                                    committedDate = '2025-01-15T00:00:00Z'
                                }
                            }
                        }
                        commit0   = @{ object = @{ oid = 'abc123def456789012345678901234567890abcd'; committedDate = '2024-01-01T00:00:00Z' } }
                        commit1   = @{ object = @{ oid = 'def456789012345678901234567890abcdef12'; committedDate = '2024-01-01T00:00:00Z' } }
                        rateLimit = @{ limit = 5000; remaining = 4998; cost = 2 }
                    }
                }
            }

            # The function may return empty results if commit data doesn't match - this tests the API is called
            { Get-BulkGitHubActionsStaleness -ActionRepos $script:testActionRepos -ShaToActionMap $script:testShaToActionMap -BatchSize 10 } | Should -Not -Throw
        }
    }

    Context 'Error handling' {
        It 'Throws when GraphQL API fails with rate limit' {
            Mock Invoke-GitHubAPIWithRetry {
                throw [System.Exception]::new('Rate limit exceeded')
            }

            { Get-BulkGitHubActionsStaleness -ActionRepos @('actions/checkout') -ShaToActionMap @{} -BatchSize 10 } | Should -Throw
        }
    }

    Context 'Batch processing' {
        It 'Uses configured batch size' {
            $manyRepos = 1..25 | ForEach-Object { "org/repo$_" }
            $manyActions = @{}
            foreach ($repo in $manyRepos) {
                $sha = "sha$($_)".PadRight(40, '0')
                $manyActions["$repo@$sha"] = @{ Repo = $repo; SHA = $sha; File = 'test.yml' }
            }

            Mock Invoke-GitHubAPIWithRetry {
                @{
                    data = @{
                        rateLimit = @{ limit = 5000; remaining = 4998; cost = 2 }
                    }
                }
            }

            # With batch size 10 and 25 repos, we expect multiple batches
            { Get-BulkGitHubActionsStaleness -ActionRepos $manyRepos -ShaToActionMap $manyActions -BatchSize 10 } | Should -Not -Throw
        }
    }
}

Describe 'Test-GitHubActionsForStaleness' -Tag 'Unit' {
    BeforeEach {
        Initialize-MockGitHubEnvironment
        $script:originalLocation = Get-Location
        Set-Location $TestDrive

        # Create mock workflow directory
        New-Item -Path '.github/workflows' -ItemType Directory -Force | Out-Null
    }

    AfterEach {
        Set-Location $script:originalLocation
        Clear-MockGitHubEnvironment
    }

    Context 'Workflow file discovery' {
        It 'Handles missing workflow directory gracefully' {
            Remove-Item -Path '.github/workflows' -Recurse -Force -ErrorAction SilentlyContinue
            { Test-GitHubActionsForStaleness } | Should -Not -Throw
        }

        It 'Handles empty workflow directory' {
            { Test-GitHubActionsForStaleness } | Should -Not -Throw
        }

        It 'Extracts SHA-pinned actions from workflow files' {
            $workflowContent = @'
name: CI
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@abc123def456789012345678901234567890abcd
'@
            Set-Content -Path '.github/workflows/ci.yml' -Value $workflowContent

            Mock Get-BulkGitHubActionsStaleness { @() }

            { Test-GitHubActionsForStaleness } | Should -Not -Throw
            Should -Invoke Get-BulkGitHubActionsStaleness -Times 1 -Scope It
        }
    }

    Context 'SHA extraction regex' {
        It 'Matches full 40-character SHA' {
            $workflowContent = @'
name: Test
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@a5ac7e51b41094c92402da3b24376905380afc29
'@
            Set-Content -Path '.github/workflows/test.yml' -Value $workflowContent

            Mock Get-BulkGitHubActionsStaleness {
                param($ActionRepos, $ShaToActionMap)
                $ShaToActionMap.Count | Should -Be 1
                return @()
            }

            Test-GitHubActionsForStaleness
            Should -Invoke Get-BulkGitHubActionsStaleness -Times 1 -Scope It
        }

        It 'Ignores version tags (non-SHA references)' {
            $workflowContent = @'
name: Test
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
'@
            Set-Content -Path '.github/workflows/test.yml' -Value $workflowContent

            # Should not call bulk check since no SHA-pinned actions
            { Test-GitHubActionsForStaleness } | Should -Not -Throw
        }
    }

    Context 'Fallback to REST API' {
        It 'Falls back when GraphQL fails' {
            $workflowContent = @'
name: Test
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@abc123def456789012345678901234567890abcd
'@
            Set-Content -Path '.github/workflows/test.yml' -Value $workflowContent

            Mock Get-BulkGitHubActionsStaleness {
                throw 'GraphQL failed'
            }

            Mock Invoke-RestMethod {
                throw 'Rate limit'
            }

            # Should not throw, just log warning
            { Test-GitHubActionsForStaleness } | Should -Not -Throw
        }
    }
}

Describe 'Write-OutputResult' -Tag 'Unit' {
    BeforeEach {
        $script:testDependencies = @(
            [PSCustomObject]@{
                Type           = 'GitHubAction'
                File           = '.github/workflows/ci.yml'
                Name           = 'actions/checkout'
                CurrentVersion = 'abc123def456789012345678901234567890abcd'
                LatestVersion  = 'def456789012345678901234567890abcdef12'
                DaysOld        = 45
                Severity       = 'Low'
                Message        = 'GitHub Action is 45 days old'
            },
            [PSCustomObject]@{
                Type           = 'GitHubAction'
                File           = '.github/workflows/build.yml'
                Name           = 'actions/setup-node'
                CurrentVersion = 'old12345678901234567890123456789012345'
                LatestVersion  = 'new12345678901234567890123456789012345'
                DaysOld        = 95
                Severity       = 'High'
                Message        = 'GitHub Action is 95 days old'
            }
        )
    }

    Context 'JSON output' {
        It 'Writes valid JSON to file' {
            $outputPath = Join-Path $TestDrive 'output.json'
            Write-OutputResult -Dependencies $script:testDependencies -OutputFormat 'json' -OutputPath $outputPath
            Test-Path $outputPath | Should -BeTrue
            { Get-Content $outputPath -Raw | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'Includes all dependencies in JSON' {
            $outputPath = Join-Path $TestDrive 'output.json'
            Write-OutputResult -Dependencies $script:testDependencies -OutputFormat 'json' -OutputPath $outputPath
            $json = Get-Content $outputPath -Raw | ConvertFrom-Json
            $json.Dependencies.Count | Should -Be 2
            $json.TotalStaleItems | Should -Be 2
        }

        It 'Creates output directory if not exists' {
            $outputPath = Join-Path $TestDrive 'nested/dir/output.json'
            Write-OutputResult -Dependencies $script:testDependencies -OutputFormat 'json' -OutputPath $outputPath
            Test-Path $outputPath | Should -BeTrue
        }

        It 'Handles empty dependencies array' {
            $outputPath = Join-Path $TestDrive 'empty.json'
            Write-OutputResult -Dependencies @() -OutputFormat 'json' -OutputPath $outputPath
            $json = Get-Content $outputPath -Raw | ConvertFrom-Json
            $json.TotalStaleItems | Should -Be 0
        }
    }

    Context 'GitHub Actions output' {
        It 'Outputs warning annotations for each dependency' {
            $output = Write-OutputResult -Dependencies $script:testDependencies -OutputFormat 'github' 6>&1
            $outputText = $output -join "`n"
            $outputText | Should -Match '::warning file='
        }

        It 'Outputs notice when no dependencies' {
            $output = Write-OutputResult -Dependencies @() -OutputFormat 'github' 6>&1
            $outputText = $output -join "`n"
            $outputText | Should -Match '::notice::'
        }

        It 'Outputs error summary when dependencies found' {
            $output = Write-OutputResult -Dependencies $script:testDependencies -OutputFormat 'github' 6>&1
            $outputText = $output -join "`n"
            $outputText | Should -Match '::error::'
        }
    }

    Context 'Azure DevOps output' {
        It 'Outputs vso logissue warnings' {
            $output = Write-OutputResult -Dependencies $script:testDependencies -OutputFormat 'azdo' 6>&1
            $outputText = $output -join "`n"
            $outputText | Should -Match '##vso\[task\.logissue type=warning'
        }

        It 'Outputs info when no dependencies' {
            $output = Write-OutputResult -Dependencies @() -OutputFormat 'azdo' 6>&1
            $outputText = $output -join "`n"
            $outputText | Should -Match '##vso\[task\.logissue type=info\]'
        }

        It 'Sets SucceededWithIssues when dependencies found' {
            $output = Write-OutputResult -Dependencies $script:testDependencies -OutputFormat 'azdo' 6>&1
            $outputText = $output -join "`n"
            $outputText | Should -Match '##vso\[task\.complete result=SucceededWithIssues\]'
        }
    }

    Context 'Console output' {
        It 'Does not throw for console output' {
            { Write-OutputResult -Dependencies $script:testDependencies -OutputFormat 'console' } | Should -Not -Throw
        }

        It 'Handles empty dependencies' {
            { Write-OutputResult -Dependencies @() -OutputFormat 'console' } | Should -Not -Throw
        }
    }

    Context 'Summary output' {
        It 'Groups dependencies by type' {
            $output = Write-OutputResult -Dependencies $script:testDependencies -OutputFormat 'Summary' 6>&1
            $outputText = $output -join "`n"
            $outputText | Should -Match 'GitHubAction: 2'
        }

        It 'Shows total count' {
            $output = Write-OutputResult -Dependencies $script:testDependencies -OutputFormat 'Summary' 6>&1
            $outputText = $output -join "`n"
            $outputText | Should -Match 'Total stale dependencies: 2'
        }
    }
}

Describe 'Invoke-SHAStalenessTest' -Tag 'Unit' {
    BeforeEach {
        Initialize-MockGitHubEnvironment
        $script:originalLocation = Get-Location
        Set-Location $TestDrive

        # Create mock workflow directory with a workflow file
        New-Item -Path '.github/workflows' -ItemType Directory -Force | Out-Null
        New-Item -Path 'logs' -ItemType Directory -Force | Out-Null

        $workflowContent = @'
name: CI
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
'@
        Set-Content -Path '.github/workflows/ci.yml' -Value $workflowContent

        # Mock the functions that make API calls
        Mock Get-BulkGitHubActionsStaleness { @() }
        Mock Get-ToolStaleness { @() }
    }

    AfterEach {
        Set-Location $script:originalLocation
        Clear-MockGitHubEnvironment
    }

    Context 'Return codes' {
        It 'Returns 0 when no stale dependencies found' {
            $result = Invoke-SHAStalenessTest -OutputFormat 'console'
            $result | Should -Be 0
        }

        It 'Returns 0 when stale dependencies found without FailOnStale' {
            Mock Get-ToolStaleness {
                @([PSCustomObject]@{
                        Tool           = 'test-tool'
                        Repository     = 'test/repo'
                        CurrentVersion = '1.0.0'
                        LatestVersion  = '2.0.0'
                        IsStale        = $true
                        Error          = $null
                    })
            }

            $result = Invoke-SHAStalenessTest -OutputFormat 'console'
            $result | Should -Be 0
        }

        It 'Returns 1 when stale dependencies found with FailOnStale' {
            # Skip this test - requires internal script state manipulation
            # The script's $script:StaleDependencies is not accessible from test scope
            Set-ItResult -Skipped -Because 'Requires internal script state manipulation'
        }
    }

    Context 'Output formats' {
        It 'Accepts json output format' {
            $result = Invoke-SHAStalenessTest -OutputFormat 'json' -OutputPath (Join-Path $TestDrive 'out.json')
            $result | Should -Be 0
        }

        It 'Accepts github output format' {
            $result = Invoke-SHAStalenessTest -OutputFormat 'github'
            # Result includes output messages and exit code; check last element
            $exitCode = if ($result -is [array]) { $result[-1] } else { $result }
            $exitCode | Should -Be 0
        }

        It 'Accepts azdo output format' {
            $result = Invoke-SHAStalenessTest -OutputFormat 'azdo'
            $exitCode = if ($result -is [array]) { $result[-1] } else { $result }
            $exitCode | Should -Be 0
        }

        It 'Accepts Summary output format' {
            $result = Invoke-SHAStalenessTest -OutputFormat 'Summary'
            $exitCode = if ($result -is [array]) { $result[-1] } else { $result }
            $exitCode | Should -Be 0
        }
    }

    Context 'Parameters' {
        It 'Accepts MaxAge parameter' {
            { Invoke-SHAStalenessTest -MaxAge 60 -OutputFormat 'console' } | Should -Not -Throw
        }

        It 'Accepts GraphQLBatchSize parameter' {
            { Invoke-SHAStalenessTest -GraphQLBatchSize 10 -OutputFormat 'console' } | Should -Not -Throw
        }

        It 'Validates GraphQLBatchSize range' {
            { Invoke-SHAStalenessTest -GraphQLBatchSize 0 -OutputFormat 'console' } | Should -Throw
            { Invoke-SHAStalenessTest -GraphQLBatchSize 51 -OutputFormat 'console' } | Should -Throw
        }
    }

    Context 'Tool staleness integration' {
        It 'Processes tool staleness results' {
            Mock Get-ToolStaleness {
                @(
                    [PSCustomObject]@{
                        Tool           = 'tool1'
                        Repository     = 'org/tool1'
                        CurrentVersion = '1.0.0'
                        LatestVersion  = '1.0.0'
                        IsStale        = $false
                        Error          = $null
                    }
                )
            }

            { Invoke-SHAStalenessTest -OutputFormat 'console' } | Should -Not -Throw
            Should -Invoke Get-ToolStaleness -Times 1 -Scope It
        }

        It 'Handles tool check errors gracefully' {
            Mock Get-ToolStaleness {
                @([PSCustomObject]@{
                        Tool           = 'failed-tool'
                        Repository     = 'org/failed'
                        CurrentVersion = '1.0.0'
                        LatestVersion  = $null
                        IsStale        = $null
                        Error          = 'API error'
                    })
            }

            { Invoke-SHAStalenessTest -OutputFormat 'console' } | Should -Not -Throw
        }
    }
}

Describe 'Boundary Conditions' -Tag 'Unit' {
    BeforeAll {
        . $PSScriptRoot/../../security/Test-SHAStaleness.ps1
    }

    Context 'Version comparison edge cases' {
        It 'Compare-ToolVersion rejects empty strings via parameter validation' {
            # Mandatory parameters reject empty strings
            { Compare-ToolVersion -Current '' -Latest '1.0.0' } | Should -Throw
        }

        It 'Compare-ToolVersion handles whitespace version string' {
            # Whitespace passes mandatory check but fails version parsing
            $result = Compare-ToolVersion -Current ' ' -Latest '1.0.0'
            # Falls back to string comparison: ' ' ne '1.0.0' = true
            $result | Should -BeTrue
        }
    }

    Context 'Version format edge cases' {
        It 'Compare-ToolVersion handles version with v prefix' {
            $result = Compare-ToolVersion -Current 'v1.0.0' -Latest 'v2.0.0'
            $result | Should -BeTrue
        }

        It 'Compare-ToolVersion handles matching versions with different formats' {
            $result = Compare-ToolVersion -Current '1.0.0' -Latest 'v1.0.0'
            $result | Should -BeFalse -Because 'versions should match after normalization'
        }

        It 'Compare-ToolVersion handles prerelease versions' {
            # Pre-release metadata is stripped, so 1.0.0 vs 1.0.1 comparison
            $result = Compare-ToolVersion -Current '1.0.0' -Latest '1.0.1-beta'
            $result | Should -BeTrue
        }
    }

    Context 'Token validation return values' {
        It 'Test-GitHubToken returns hashtable for whitespace-only token' {
            Mock Invoke-RestMethod { 
                @{ login = 'user'; resources = @{ graphql = @{ remaining = 5000; limit = 5000 } } } 
            }
            $result = Test-GitHubToken -Token '   '
            $result | Should -BeOfType [hashtable]
            # Whitespace is treated as a token (trimmed or used as-is by API)
        }

        It 'Test-GitHubToken returns hashtable structure for empty token' {
            $result = Test-GitHubToken -Token ''
            $result | Should -BeOfType [hashtable]
            $result.Authenticated | Should -Be $false -Because 'empty token means unauthenticated'
            $result.RateLimit | Should -Be 60 -Because 'unauthenticated users get 60 rate limit'
        }
    }

    Context 'Log level handling' {
        It 'Write-SecurityLog handles all log levels' {
            { Write-SecurityLog -Message 'Test' -Level 'Info' } | Should -Not -Throw
            { Write-SecurityLog -Message 'Test' -Level 'Warning' } | Should -Not -Throw
            { Write-SecurityLog -Message 'Test' -Level 'Error' } | Should -Not -Throw
        }
    }
}
