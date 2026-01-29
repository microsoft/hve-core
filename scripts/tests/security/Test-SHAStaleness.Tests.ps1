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
