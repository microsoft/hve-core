#Requires -Modules Pester

BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '../../security/Test-SHAStaleness.ps1'
    . $scriptPath

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

    Context 'Token present' {
        It 'Returns true when GITHUB_TOKEN is set' {
            $env:GITHUB_TOKEN = 'ghp_test123456789'
            Test-GitHubToken | Should -BeTrue
        }

        It 'Returns true when GH_TOKEN is set' {
            $env:GH_TOKEN = 'ghp_test123456789'
            Test-GitHubToken | Should -BeTrue
        }
    }

    Context 'Token absent' {
        It 'Returns false when no token environment variable is set' {
            $env:GITHUB_TOKEN = $null
            $env:GH_TOKEN = $null
            Test-GitHubToken | Should -BeFalse
        }
    }
}

Describe 'Invoke-GitHubAPIWithRetry' -Tag 'Unit' {
    BeforeEach {
        Initialize-MockGitHubEnvironment
        $env:GITHUB_TOKEN = 'ghp_test123456789'
    }

    AfterEach {
        Clear-MockGitHubEnvironment
    }

    Context 'Successful requests' {
        It 'Returns response on first successful call' {
            Mock Invoke-RestMethod {
                return @{ sha = 'abc123def456789012345678901234567890abcd' }
            }

            $result = Invoke-GitHubAPIWithRetry -Uri 'https://api.github.com/repos/test/test'
            $result.sha | Should -Be 'abc123def456789012345678901234567890abcd'
        }
    }

    Context 'Rate limiting' {
        It 'Retries on 403 rate limit response' {
            $script:CallCount = 0
            Mock Invoke-RestMethod {
                $script:CallCount++
                if ($script:CallCount -lt 3) {
                    $ex = [System.Net.WebException]::new("Rate limit exceeded")
                    throw $ex
                }
                return @{ sha = 'abc123' }
            }

            $result = Invoke-GitHubAPIWithRetry -Uri 'https://api.github.com/test' -MaxRetries 5
            $script:CallCount | Should -BeGreaterOrEqual 3
            $result.sha | Should -Be 'abc123'
        }
    }

    Context 'Error handling' {
        It 'Throws after max retries exceeded' {
            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new("Network error")
            }

            { Invoke-GitHubAPIWithRetry -Uri 'https://api.github.com/test' -MaxRetries 2 } | Should -Throw
        }
    }
}

Describe 'Test-GitHubActionsForStaleness' -Tag 'Unit' {
    BeforeEach {
        Initialize-MockGitHubEnvironment
        $env:GITHUB_TOKEN = 'ghp_test123456789'

        Mock Invoke-RestMethod {
            return @{
                sha = 'newsha123456789012345678901234567890abcd'
                commit = @{
                    committer = @{
                        date = (Get-Date).AddDays(-5).ToString('o')
                    }
                }
            }
        }
    }

    AfterEach {
        Clear-MockGitHubEnvironment
    }

    Context 'Stale detection' {
        It 'Detects stale SHA when newer commit exists' {
            $action = @{
                Owner = 'actions'
                Repo = 'checkout'
                CurrentSHA = 'oldsha123456789012345678901234567890abcd'
                Version = 'v4'
            }

            $result = Test-GitHubActionsForStaleness -Actions @($action)
            $result | Should -Not -BeNullOrEmpty
            $result[0].IsStale | Should -BeTrue
        }
    }

    Context 'MaxAge parameter' {
        It 'Respects MaxAge parameter for staleness threshold' {
            Mock Invoke-RestMethod {
                return @{
                    sha = 'newsha123456789012345678901234567890abcd'
                    commit = @{
                        committer = @{
                            date = (Get-Date).AddDays(-10).ToString('o')
                        }
                    }
                }
            }

            $action = @{
                Owner = 'actions'
                Repo = 'checkout'
                CurrentSHA = 'newsha123456789012345678901234567890abcd'
                Version = 'v4'
            }

            $result = Test-GitHubActionsForStaleness -Actions @($action) -MaxAge 30
            $result[0].IsStale | Should -BeFalse
        }
    }
}

Describe 'Compare-ToolVersion' -Tag 'Unit' {
    Context 'Version comparisons' {
        It 'Returns 0 for equal versions' {
            Compare-ToolVersion -Current '8.18.2' -Latest '8.18.2' | Should -Be 0
        }

        It 'Returns negative for older current version' {
            Compare-ToolVersion -Current '8.16.0' -Latest '8.18.2' | Should -BeLessThan 0
        }

        It 'Returns positive for newer current version' {
            Compare-ToolVersion -Current '9.0.0' -Latest '8.18.2' | Should -BeGreaterThan 0
        }

        It 'Handles major version differences' {
            Compare-ToolVersion -Current '7.0.0' -Latest '8.0.0' | Should -BeLessThan 0
        }

        It 'Handles minor version differences' {
            Compare-ToolVersion -Current '8.17.0' -Latest '8.18.0' | Should -BeLessThan 0
        }

        It 'Handles patch version differences' {
            Compare-ToolVersion -Current '8.18.1' -Latest '8.18.2' | Should -BeLessThan 0
        }
    }
}
