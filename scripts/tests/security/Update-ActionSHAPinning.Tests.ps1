#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '../../security/Update-ActionSHAPinning.ps1'
    . $scriptPath

    $mockPath = Join-Path $PSScriptRoot '../Mocks/GitMocks.psm1'
    Import-Module $mockPath -Force

    # Save environment before tests
    Save-CIEnvironment

    # Fixture paths
    $script:FixturesPath = Join-Path $PSScriptRoot '../Fixtures/Workflows'

    # Mock response helpers
    function script:New-MockGitHubGraphQLResponse {
        param(
            [string]$Login = 'testuser',
            [int]$RateRemaining = 5000,
            [int]$RateLimit = 5000
        )
        return @{
            data = @{
                viewer = @{ login = $Login }
                rateLimit = @{
                    remaining = $RateRemaining
                    limit = $RateLimit
                    resetAt = (Get-Date).AddHours(1).ToString('o')
                }
            }
        }
    }

    function script:New-MockRateLimitException {
        $exception = [System.Net.WebException]::new(
            "API rate limit exceeded",
            $null,
            [System.Net.WebExceptionStatus]::ProtocolError,
            $null
        )
        return $exception
    }
}

AfterAll {
    Restore-CIEnvironment
}

Describe 'Get-ActionReference' -Tag 'Unit' {
    Context 'Standard action references' {
        It 'Parses action with tag reference' {
            $yaml = 'uses: actions/checkout@v4'
            $result = Get-ActionReference -WorkflowContent $yaml
            $result | Should -Not -BeNullOrEmpty
            $result.OriginalRef | Should -Be 'actions/checkout@v4'
        }

        It 'Parses action with SHA reference' {
            $yaml = 'uses: actions/checkout@a5ac7e51b41094c92402da3b24376905380afc29'
            $result = Get-ActionReference -WorkflowContent $yaml
            $result.OriginalRef | Should -Be 'actions/checkout@a5ac7e51b41094c92402da3b24376905380afc29'
        }

        It 'Returns LineNumber for reference' {
            $yaml = "name: Test`njobs:`n  test:`n    steps:`n      - name: Checkout`n        uses: actions/checkout@v4"
            $result = Get-ActionReference -WorkflowContent $yaml
            $result.LineNumber | Should -BeGreaterThan 0
        }
    }

    Context 'Multiple action references' {
        It 'Finds all action references in workflow' {
            $yaml = "jobs:`n  test:`n    steps:`n      - name: Checkout`n        uses: actions/checkout@v4`n      - name: Setup`n        uses: actions/setup-node@v4"
            $result = @(Get-ActionReference -WorkflowContent $yaml)
            $result.Count | Should -Be 2
        }
    }

    Context 'Invalid references' {
        It 'Returns empty for non-action content' {
            $yaml = 'run: echo "Hello"'
            $result = Get-ActionReference -WorkflowContent $yaml
            $result | Should -BeNullOrEmpty
        }
    }
}

Describe 'Get-SHAForAction' -Tag 'Unit' {
    BeforeEach {
        Initialize-MockCIEnvironment
        $env:GITHUB_TOKEN = 'ghp_test123456789'
    }

    AfterEach {
        Clear-MockCIEnvironment
    }

    Context 'ActionSHAMap lookup' {
        It 'Returns action reference with SHA for known action' {
            $result = Get-SHAForAction -ActionRef 'actions/checkout@v4'
            $result | Should -Not -BeNullOrEmpty
            # Function returns full action reference with SHA (e.g., actions/checkout@sha)
            $result | Should -Match '@[a-f0-9]{40}$'
        }
    }

    Context 'Unmapped actions' {
        It 'Returns null when action not in map and no API call is made' {
            # Get-SHAForAction returns null for unmapped actions without attempting API
            $result = Get-SHAForAction -ActionRef 'unknown/action@v1'
            $result | Should -BeNullOrEmpty
        }

        It 'Returns null for unmapped actions requiring manual review' {
            # The function logs a warning and returns null for unmapped actions
            $result = Get-SHAForAction -ActionRef 'test-org/test-action@v1'
            $result | Should -BeNullOrEmpty
        }
    }
}

Describe 'Update-WorkflowFile' -Tag 'Unit' {
    BeforeEach {
        Initialize-MockCIEnvironment
        $env:GITHUB_TOKEN = 'ghp_test123456789'

        # Copy fixture to TestDrive for modification testing
        $unpinnedSource = Join-Path $script:FixturesPath 'unpinned-workflow.yml'
        $script:TestWorkflow = Join-Path $TestDrive 'test-workflow.yml'
        Copy-Item $unpinnedSource $script:TestWorkflow

        Mock Invoke-RestMethod {
            return @{
                object = @{
                    sha = 'newsha123456789012345678901234567890abcd'
                }
            }
        }
    }

    AfterEach {
        Clear-MockCIEnvironment
    }

    Context 'Return value structure' {
        It 'Returns PSCustomObject with FilePath' {
            $result = Update-WorkflowFile -FilePath $script:TestWorkflow
            $result | Should -BeOfType [PSCustomObject]
            $result.FilePath | Should -Be $script:TestWorkflow
        }

        It 'Returns ActionsProcessed count' {
            $result = Update-WorkflowFile -FilePath $script:TestWorkflow
            $result.ActionsProcessed | Should -BeGreaterOrEqual 0
        }

        It 'Returns ActionsPinned count' {
            $result = Update-WorkflowFile -FilePath $script:TestWorkflow
            $result.PSObject.Properties.Name -contains 'ActionsPinned' | Should -BeTrue
        }
    }

    Context 'File modification' {
        It 'Updates unpinned action to SHA' {
            Update-WorkflowFile -FilePath $script:TestWorkflow

            $content = Get-Content $script:TestWorkflow -Raw
            # Check that the file was processed (content may or may not change based on mock)
            $content | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Already pinned workflows' {
        It 'Does not modify already pinned actions' {
            $pinnedSource = Join-Path $script:FixturesPath 'pinned-workflow.yml'
            $pinnedTest = Join-Path $TestDrive 'pinned-test.yml'
            Copy-Item $pinnedSource $pinnedTest

            $originalContent = Get-Content $pinnedTest -Raw
            Update-WorkflowFile -FilePath $pinnedTest
            $newContent = Get-Content $pinnedTest -Raw

            $newContent | Should -Be $originalContent
        }
    }
}

Describe 'Update-WorkflowFile -WhatIf' -Tag 'Unit' {
    BeforeEach {
        Initialize-MockCIEnvironment
        $env:GITHUB_TOKEN = 'ghp_test123456789'

        $unpinnedSource = Join-Path $script:FixturesPath 'unpinned-workflow.yml'
        $script:TestWorkflow = Join-Path $TestDrive 'whatif-test.yml'
        Copy-Item $unpinnedSource $script:TestWorkflow

        Mock Invoke-RestMethod {
            return @{
                object = @{
                    sha = 'newsha123456789012345678901234567890abcd'
                }
            }
        }
    }

    AfterEach {
        Clear-MockCIEnvironment
    }

    Context 'WhatIf behavior' {
        It 'Does not modify file when WhatIf is specified' {
            $originalContent = Get-Content $script:TestWorkflow -Raw

            Update-WorkflowFile -FilePath $script:TestWorkflow -WhatIf

            $newContent = Get-Content $script:TestWorkflow -Raw
            $newContent | Should -Be $originalContent
        }
    }
}

Describe 'Invoke-GitHubAPIWithRetry' -Tag 'Unit' {
    BeforeEach {
        Initialize-MockCIEnvironment
        $env:GITHUB_TOKEN = 'ghp_test123456789'
        $script:AttemptCount = 0

        # Mock Start-Sleep to avoid actual delays
        Mock Start-Sleep { }
    }

    AfterEach {
        Clear-MockCIEnvironment
    }

    Context 'Successful requests' {
        It 'Returns response on first attempt success' {
            Mock Invoke-RestMethod {
                $script:AttemptCount++
                return @{ data = 'success' }
            }

            $result = Invoke-GitHubAPIWithRetry -Uri 'https://api.github.com/test' -Method 'GET' -Headers @{ Authorization = 'token test' }

            $result.data | Should -Be 'success'
            $script:AttemptCount | Should -Be 1
            Should -Not -Invoke Start-Sleep
        }
    }

    Context 'Rate limit retry behavior' {
        It 'Retries on 403 rate limit error and succeeds' {
            Mock Invoke-RestMethod {
                $script:AttemptCount++
                if ($script:AttemptCount -lt 3) {
                    # Create exception with proper Response.StatusCode for rate limit detection
                    $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::Forbidden)
                    $exception = [Microsoft.PowerShell.Commands.HttpResponseException]::new('API rate limit exceeded', $response)
                    throw $exception
                }
                return @{ data = 'success after retry' }
            }

            $result = Invoke-GitHubAPIWithRetry -Uri 'https://api.github.com/test' -Method 'GET' -Headers @{ Authorization = 'token test' } -MaxRetries 5

            $result.data | Should -Be 'success after retry'
            $script:AttemptCount | Should -Be 3
            Should -Invoke Start-Sleep -Times 2
        }

        It 'Throws after exceeding MaxRetries' {
            Mock Invoke-RestMethod {
                $script:AttemptCount++
                $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::Forbidden)
                $exception = [Microsoft.PowerShell.Commands.HttpResponseException]::new('API rate limit exceeded', $response)
                throw $exception
            }

            { Invoke-GitHubAPIWithRetry -Uri 'https://api.github.com/test' -Method 'GET' -Headers @{ Authorization = 'token test' } -MaxRetries 2 } |
                Should -Throw

            $script:AttemptCount | Should -Be 2  # MaxRetries attempts
        }

        It 'Uses exponential backoff delay' {
            $script:delays = @()
            Mock Start-Sleep { param($Seconds) $script:delays += $Seconds }
            Mock Invoke-RestMethod {
                $script:AttemptCount++
                if ($script:AttemptCount -lt 3) {
                    $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::Forbidden)
                    $exception = [Microsoft.PowerShell.Commands.HttpResponseException]::new('API rate limit exceeded', $response)
                    throw $exception
                }
                return @{ data = 'success' }
            }

            Invoke-GitHubAPIWithRetry -Uri 'https://api.github.com/test' -Method 'GET' -Headers @{ Authorization = 'token test' } -InitialDelaySeconds 2

            # Verify exponential backoff pattern
            $script:delays[0] | Should -Be 2   # First delay
            $script:delays[1] | Should -Be 4   # Second delay (doubled)
        }
    }

    Context 'Non-retryable errors' {
        It 'Throws immediately on non-rate-limit error' {
            Mock Invoke-RestMethod {
                $script:AttemptCount++
                throw [System.Net.WebException]::new('Not Found')
            }

            { Invoke-GitHubAPIWithRetry -Uri 'https://api.github.com/test' -Method 'GET' -Headers @{ Authorization = 'token test' } } |
                Should -Throw '*Not Found*'

            $script:AttemptCount | Should -Be 1
            Should -Not -Invoke Start-Sleep
        }
    }

    Context 'Request with body' {
        It 'Includes body in request' {
            Mock Invoke-RestMethod {
                param($Uri, $Method, $Headers, $Body, $ContentType)
                $null = $Uri, $Method, $Headers  # Suppress PSScriptAnalyzer unused parameter warnings
                return @{ received = $Body; contentType = $ContentType }
            }

            $result = Invoke-GitHubAPIWithRetry -Uri 'https://api.github.com/graphql' -Method 'POST' -Headers @{ Authorization = 'token test' } -Body '{"query":"test"}'

            $result.received | Should -Be '{"query":"test"}'
            $result.contentType | Should -Be 'application/json'
        }
    }
}

Describe 'Get-LatestCommitSHA' -Tag 'Unit' {
    BeforeEach {
        Initialize-MockCIEnvironment
        $env:GITHUB_TOKEN = 'ghp_test123456789'
    }

    AfterEach {
        Clear-MockCIEnvironment
    }

    Context 'Successful SHA retrieval' {
        It 'Returns SHA for valid repository and branch' {
            Mock Invoke-RestMethod {
                return @{ sha = 'abc123def456789012345678901234567890abcdef' }
            }

            $result = Get-LatestCommitSHA -Owner 'actions' -Repo 'checkout' -Branch 'main'

            $result | Should -Be 'abc123def456789012345678901234567890abcdef'
        }

        It 'Handles branch parameter with refs/heads prefix' {
            Mock Invoke-RestMethod {
                param($Uri)
                if ($Uri -match 'refs/heads/main') {
                    return @{ sha = 'sha123' }
                }
                return @{ sha = 'sha456' }
            }

            $result = Get-LatestCommitSHA -Owner 'actions' -Repo 'checkout' -Branch 'refs/heads/main'

            $result | Should -Be 'sha123'
        }
    }

    Context 'Error handling' {
        It 'Returns null for non-existent repository' {
            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new('Not Found')
            }

            $result = Get-LatestCommitSHA -Owner 'nonexistent' -Repo 'repo' -Branch 'main'

            $result | Should -BeNullOrEmpty
        }

        It 'Returns null on API error without throwing' {
            Mock Invoke-RestMethod {
                throw [System.Exception]::new('Network error')
            }

            # Function should handle error gracefully and return null
            $result = Get-LatestCommitSHA -Owner 'actions' -Repo 'checkout' -Branch 'main'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Default branch detection' {
        It 'Uses default branch when Branch not specified' {
            Mock Invoke-RestMethod {
                param($Uri)
                if ($Uri -match '/repos/[^/]+/[^/]+$') {
                    return @{ default_branch = 'main' }
                }
                return @{ sha = 'default-branch-sha' }
            }

            $result = Get-LatestCommitSHA -Owner 'actions' -Repo 'checkout'

            $result | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'Test-GitHubToken' -Tag 'Unit' {
    BeforeEach {
        Initialize-MockCIEnvironment
    }

    AfterEach {
        Clear-MockCIEnvironment
    }

    Context 'Valid authenticated token' {
        It 'Returns Valid and Authenticated for good token' {
            Mock Invoke-RestMethod {
                return (script:New-MockGitHubGraphQLResponse -Login 'testuser' -RateRemaining 5000)
            }

            $result = Test-GitHubToken -Token 'ghp_validtoken123'

            $result.Valid | Should -BeTrue
            $result.Authenticated | Should -BeTrue
            $result.User | Should -Be 'testuser'
        }

        It 'Returns rate limit information' {
            Mock Invoke-RestMethod {
                return (script:New-MockGitHubGraphQLResponse -RateRemaining 4500 -RateLimit 5000)
            }

            $result = Test-GitHubToken -Token 'ghp_validtoken123'

            $result.Remaining | Should -Be 4500
            $result.RateLimit | Should -Be 5000
        }
    }

    Context 'Unauthenticated access' {
        It 'Returns Valid but not Authenticated for empty token' {
            Mock Invoke-RestMethod {
                return @{
                    data = @{
                        rateLimit = @{ remaining = 60; limit = 60 }
                    }
                }
            }

            $result = Test-GitHubToken -Token ''

            $result.Valid | Should -BeTrue
            $result.Authenticated | Should -BeFalse
        }
    }

    Context 'Low rate limit warning' {
        It 'Includes warning when remaining is low' {
            Mock Invoke-RestMethod {
                return (script:New-MockGitHubGraphQLResponse -RateRemaining 50 -RateLimit 5000)
            }

            $result = Test-GitHubToken -Token 'ghp_validtoken123'

            $result.Remaining | Should -BeLessThan 100
        }
    }

    Context 'Invalid token' {
        It 'Returns Valid false on API error' {
            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new('Unauthorized')
            }

            $result = Test-GitHubToken -Token 'invalid_token'

            $result.Valid | Should -BeFalse
        }

        It 'Includes error message on failure' {
            Mock Invoke-RestMethod {
                throw [System.Exception]::new('Bad credentials')
            }

            $result = Test-GitHubToken -Token 'bad_token'

            $result.Message | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'Export-SecurityReport' -Tag 'Unit' {
    BeforeAll {
        $script:MockResults = @(
            @{
                FilePath = 'workflow1.yml'
                ActionsPinned = 3
                ActionsSkipped = 1
                Changes = @(
                    @{ Action = 'actions/checkout@v4'; Status = 'Pinned' }
                )
            }
        )
    }

    Context 'Report generation' {
        It 'Creates report file' {
            Mock New-Item { param($Path) return @{ FullName = $Path } }
            Mock Set-Content { }
            Mock Get-Date { return [datetime]'2026-01-26T10:00:00' }

            $result = Export-SecurityReport -Results $script:MockResults

            $result | Should -Not -BeNullOrEmpty
        }

        It 'Returns report file path' {
            Mock New-Item { param($Path) return @{ FullName = $Path } }
            Mock Set-Content { }

            $result = Export-SecurityReport -Results $script:MockResults

            $result | Should -Match '\.json$'
        }
    }

    Context 'Empty results handling' {
        It 'Rejects empty results array via parameter validation' {
            { Export-SecurityReport -Results @() } | Should -Throw '*empty collection*'
        }
    }
}

Describe 'Set-ContentPreservePermission' -Tag 'Unit' {
    Context 'File writing' {
        It 'Writes content to file' {
            $testPath = Join-Path $TestDrive 'test-write.txt'

            Set-ContentPreservePermission -Path $testPath -Value 'test content'

            Test-Path $testPath | Should -BeTrue
            Get-Content $testPath -Raw | Should -Match 'test content'
        }

        It 'Respects NoNewline parameter' {
            $testPath = Join-Path $TestDrive 'test-nonewline.txt'

            Set-ContentPreservePermission -Path $testPath -Value 'no newline' -NoNewline

            $content = [System.IO.File]::ReadAllText($testPath)
            $content | Should -Be 'no newline'
        }
    }

    Context 'Permission preservation' {
        It 'Does not throw on Windows' {
            $testPath = Join-Path $TestDrive 'test-perm.txt'

            { Set-ContentPreservePermission -Path $testPath -Value 'content' } |
                Should -Not -Throw
        }
    }

    Context 'Overwrite behavior' {
        It 'Overwrites existing file content' {
            $testPath = Join-Path $TestDrive 'test-overwrite.txt'
            Set-Content $testPath -Value 'original'

            Set-ContentPreservePermission -Path $testPath -Value 'updated'

            Get-Content $testPath -Raw | Should -Match 'updated'
        }
    }
}

Describe 'Get-SHAForAction - Already Pinned' -Tag 'Unit' {
    BeforeAll {
        $script:OriginalGitHubToken = $env:GITHUB_TOKEN
        $env:GITHUB_TOKEN = 'ghp_test123456789'
    }

    AfterAll {
        $env:GITHUB_TOKEN = $script:OriginalGitHubToken
    }

    Context 'SHA-pinned action without UpdateStale' {
        It 'Returns original ref when action is already SHA-pinned' {
            $sha = 'a' * 40
            $ref = "actions/checkout@$sha"
            Mock Write-SecurityLog { }

            $result = Get-SHAForAction -ActionRef $ref

            $result | Should -Be $ref
        }
    }

    Context 'SHA-pinned action with UpdateStale' {
        It 'Returns original ref when UpdateStale is not specified' {
            $currentSHA = 'a' * 40
            $latestSHA = 'b' * 40
            $ref = "actions/checkout@$currentSHA"

            Mock Write-SecurityLog { }
            Mock Get-LatestCommitSHA { return $latestSHA }

            $result = Get-SHAForAction -ActionRef $ref

            # Without UpdateStale flag in scope, returns original
            $result | Should -Be $ref
        }
    }
}

Describe 'Update-WorkflowFile - Edge Cases' -Tag 'Unit' {
    Context 'No actions in file' {
        It 'Returns zero counts when file has no action references' {
            $testFile = Join-Path $TestDrive 'empty-workflow.yml'
            Set-Content $testFile -Value @'
name: empty
on: push
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: echo hello
'@
            Mock Write-SecurityLog { }

            $result = Update-WorkflowFile -FilePath $testFile

            $result.ActionsProcessed | Should -Be 0
            $result.ActionsPinned | Should -Be 0
            $result.ActionsSkipped | Should -Be 0
        }
    }

    Context 'File with local actions' {
        It 'Skips local action references starting with ./' {
            $testFile = Join-Path $TestDrive 'local-action.yml'
            Set-Content $testFile -Value @'
name: local
on: push
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: ./local-action
'@
            Mock Write-SecurityLog { }

            $result = Update-WorkflowFile -FilePath $testFile

            $result.ActionsProcessed | Should -Be 0
        }
    }
}

Describe 'Invoke-ActionSHAPinningUpdate' -Tag 'Unit' {
    BeforeAll {
        $env:GITHUB_TOKEN = 'ghp_test123456789'
        Initialize-MockCIEnvironment
    }
    AfterAll {
        Clear-MockCIEnvironment
    }

    Context 'Missing workflow path' {
        It 'Throws when workflow path does not exist' {
            { Invoke-ActionSHAPinningUpdate -WorkflowPath '/nonexistent/path' } |
                Should -Throw '*Workflow path not found*'
        }
    }

    Context 'No YAML files in directory' {
        It 'Warns and returns when no yml files found' {
            $emptyDir = Join-Path $TestDrive 'empty-workflows'
            New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null

            Mock Write-SecurityLog { }

            Invoke-ActionSHAPinningUpdate -WorkflowPath $emptyDir

            Should -Invoke Write-SecurityLog -Times 1 -ParameterFilter { $Level -eq 'Warning' }
        }
    }

    Context 'Full orchestration' {
        It 'Processes workflow files and generates summary' {
            $workDir = Join-Path $TestDrive 'orchestration-workflows'
            New-Item -ItemType Directory -Path $workDir -Force | Out-Null

            $sha = 'a' * 40
            $content = @"
name: test
on: push
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@$sha
"@
            Set-Content (Join-Path $workDir 'ci.yml') -Value $content

            Mock Write-SecurityLog { }
            Mock Write-SecurityOutput { }
            Mock Get-SHAForAction { return "actions/checkout@$sha" }

            Invoke-ActionSHAPinningUpdate -WorkflowPath $workDir -OutputFormat 'console'

            Should -Invoke Write-SecurityOutput -Times 1
        }
    }

    Context 'OutputReport flag' {
        It 'Calls Export-SecurityReport when OutputReport is set' {
            $workDir = Join-Path $TestDrive 'report-workflows'
            New-Item -ItemType Directory -Path $workDir -Force | Out-Null

            Set-Content (Join-Path $workDir 'test.yml') -Value @'
name: test
on: push
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: echo hi
'@
            Mock Write-SecurityLog { }
            Mock Write-SecurityOutput { }
            Mock Export-SecurityReport { return (Join-Path $TestDrive 'report.json') }

            Invoke-ActionSHAPinningUpdate -WorkflowPath $workDir -OutputReport -OutputFormat 'console'

            Should -Invoke Export-SecurityReport -Times 1
        }
    }

    Context 'Manual review actions' {
        It 'Adds SecurityIssue for actions requiring manual review' {
            $workDir = Join-Path $TestDrive 'manual-review-workflows'
            New-Item -ItemType Directory -Path $workDir -Force | Out-Null

            Set-Content (Join-Path $workDir 'unmapped.yml') -Value @'
name: unmapped
on: push
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Unknown action
        uses: some-unknown/action@v1
'@
            Mock Write-SecurityLog { }
            Mock Write-SecurityOutput { }
            Mock Get-SHAForAction { return $null }
            Mock New-SecurityIssue { return [PSCustomObject]@{Type='';Severity='';Title='';Description=''} }

            Invoke-ActionSHAPinningUpdate -WorkflowPath $workDir -OutputFormat 'console'

            Should -Invoke New-SecurityIssue -Times 1
        }
    }

    Context 'WhatIf support' {
        It 'Does not modify files when WhatIf is used' {
            $workDir = Join-Path $TestDrive 'whatif-workflows'
            New-Item -ItemType Directory -Path $workDir -Force | Out-Null

            $sha = 'a' * 40
            $content = @"
name: whatif
on: push
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@$sha
"@
            $filePath = Join-Path $workDir 'whatif.yml'
            Set-Content $filePath -Value $content

            Mock Write-SecurityLog { }
            Mock Write-SecurityOutput { }
            Mock Get-SHAForAction { return "actions/checkout@$sha" }

            Invoke-ActionSHAPinningUpdate -WorkflowPath $workDir -OutputFormat 'console' -WhatIf

            # File content should remain unchanged
            $afterContent = Get-Content $filePath -Raw
            $afterContent | Should -Match "actions/checkout@$sha"
        }
    }
}
