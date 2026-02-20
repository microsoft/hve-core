# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
# Licensed under the MIT license.

#Requires -Modules Pester
# SecurityHelpers.Tests.ps1
#
# Purpose: Unit tests for SecurityHelpers.psm1 module
# Author: HVE Core Team

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../security/Modules/SecurityHelpers.psm1'
    Import-Module $modulePath -Force
}

Describe 'Write-SecurityLog' -Tag 'Unit' {
    Context 'Console output' {
        It 'Outputs formatted message with timestamp' {
            $output = Write-SecurityLog -Message 'Test message' -Level Info 6>&1
            $output | Should -Match '\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] \[Info\] Test message'
        }

        It 'Outputs message with Warning level' {
            $output = Write-SecurityLog -Message 'Warning message' -Level Warning 6>&1
            $output | Should -Match '\[Warning\] Warning message'
        }

        It 'Outputs message with Error level' {
            $output = Write-SecurityLog -Message 'Error message' -Level Error 6>&1
            $output | Should -Match '\[Error\] Error message'
        }

        It 'Outputs message with Success level' {
            $output = Write-SecurityLog -Message 'Success message' -Level Success 6>&1
            $output | Should -Match '\[Success\] Success message'
        }

        It 'Outputs message with Debug level' {
            $output = Write-SecurityLog -Message 'Debug message' -Level Debug 6>&1
            $output | Should -Match '\[Debug\] Debug message'
        }

        It 'Outputs message with Verbose level' {
            $output = Write-SecurityLog -Message 'Verbose message' -Level Verbose 6>&1
            $output | Should -Match '\[Verbose\] Verbose message'
        }

        It 'Outputs blank line for empty message' {
            # Mock Write-Host to capture the blank line call
            $output = Write-SecurityLog -Message '' -Level Info 6>&1
            # Empty message should not produce log entry output
            $output | Should -BeNullOrEmpty
        }

        It 'Outputs blank line for whitespace-only message' {
            $output = Write-SecurityLog -Message '   ' -Level Info 6>&1
            $output | Should -BeNullOrEmpty
        }

        It 'Defaults to Info level' {
            $output = Write-SecurityLog -Message 'Default level' 6>&1
            $output | Should -Match '\[Info\] Default level'
        }
    }

    Context 'Non-console output' {
        It 'Does not output to console when OutputFormat is not console' {
            $output = Write-SecurityLog -Message 'Test' -Level Info -OutputFormat 'silent' 6>&1
            $output | Should -BeNullOrEmpty
        }
    }

    Context 'File logging' {
        BeforeEach {
            $script:testLogPath = Join-Path $TestDrive 'test-security.log'
        }

        It 'Creates log directory if not exists' {
            $nestedPath = Join-Path $TestDrive 'nested/dir/security.log'
            Write-SecurityLog -Message 'Test' -Level Info -LogPath $nestedPath
            Test-Path (Split-Path -Parent $nestedPath) | Should -BeTrue
        }

        It 'Appends log entry to file' {
            Write-SecurityLog -Message 'First entry' -Level Info -LogPath $script:testLogPath
            Write-SecurityLog -Message 'Second entry' -Level Warning -LogPath $script:testLogPath
            $content = Get-Content -Path $script:testLogPath
            $content.Count | Should -Be 2
            $content[0] | Should -Match '\[Info\] First entry'
            $content[1] | Should -Match '\[Warning\] Second entry'
        }

        It 'Handles file write errors gracefully' {
            # Create a file and lock it
            $lockedPath = Join-Path $TestDrive 'locked.log'
            $file = [System.IO.File]::Open($lockedPath, 'Create', 'Write', 'None')
            try {
                # Should emit warning but not throw
                { Write-SecurityLog -Message 'Test' -Level Info -LogPath $lockedPath 3>$null } | Should -Not -Throw
            }
            finally {
                $file.Close()
            }
        }
    }

    Context 'CI annotation forwarding' {
        BeforeAll {
            Mock Write-CIAnnotation {} -ModuleName SecurityHelpers
            Mock Write-Host {} -ModuleName SecurityHelpers
        }

        It 'Forwards Warning messages as CI annotations when -CIAnnotation is set' {
            Write-SecurityLog -Message 'Test warning' -Level Warning -CIAnnotation
            Should -Invoke Write-CIAnnotation -ModuleName SecurityHelpers -ParameterFilter { $Level -eq 'Warning' -and $Message -eq 'Test warning' } -Times 1 -Exactly
        }

        It 'Forwards Error messages as CI annotations when -CIAnnotation is set' {
            Write-SecurityLog -Message 'Test error' -Level Error -CIAnnotation
            Should -Invoke Write-CIAnnotation -ModuleName SecurityHelpers -ParameterFilter { $Level -eq 'Error' -and $Message -eq 'Test error' } -Times 1 -Exactly
        }

        It 'Does not forward Info messages as CI annotations' {
            Write-SecurityLog -Message 'Test info' -Level Info -CIAnnotation
            Should -Invoke Write-CIAnnotation -ModuleName SecurityHelpers -Times 0
        }

        It 'Does not forward any messages when -CIAnnotation is not set' {
            Write-SecurityLog -Message 'No annotation' -Level Warning
            Should -Invoke Write-CIAnnotation -ModuleName SecurityHelpers -Times 0
        }
    }
}

Describe 'New-SecurityIssue' -Tag 'Unit' {
    It 'Returns PSCustomObject with all properties' {
        $issue = New-SecurityIssue -Type 'TestType' -Severity 'High' -Title 'Test Title' -Description 'Test Description'
        $issue.Type | Should -Be 'TestType'
        $issue.Severity | Should -Be 'High'
        $issue.Title | Should -Be 'Test Title'
        $issue.Description | Should -Be 'Test Description'
    }

    It 'Sets Timestamp to current time' {
        $before = Get-Date
        $issue = New-SecurityIssue -Type 'Test' -Severity 'Low' -Title 'Test' -Description 'Test'
        $after = Get-Date
        $timestamp = [datetime]::ParseExact($issue.Timestamp, 'yyyy-MM-dd HH:mm:ss', $null)
        $timestamp | Should -BeGreaterOrEqual $before.AddSeconds(-1)
        $timestamp | Should -BeLessOrEqual $after.AddSeconds(1)
    }

    It 'Validates Severity parameter - Low' {
        $issue = New-SecurityIssue -Type 'Test' -Severity 'Low' -Title 'Test' -Description 'Test'
        $issue.Severity | Should -Be 'Low'
    }

    It 'Validates Severity parameter - Medium' {
        $issue = New-SecurityIssue -Type 'Test' -Severity 'Medium' -Title 'Test' -Description 'Test'
        $issue.Severity | Should -Be 'Medium'
    }

    It 'Validates Severity parameter - High' {
        $issue = New-SecurityIssue -Type 'Test' -Severity 'High' -Title 'Test' -Description 'Test'
        $issue.Severity | Should -Be 'High'
    }

    It 'Validates Severity parameter - Critical' {
        $issue = New-SecurityIssue -Type 'Test' -Severity 'Critical' -Title 'Test' -Description 'Test'
        $issue.Severity | Should -Be 'Critical'
    }

    It 'Rejects invalid Severity value' {
        { New-SecurityIssue -Type 'Test' -Severity 'Invalid' -Title 'Test' -Description 'Test' } | Should -Throw
    }

    It 'Includes optional File property' {
        $issue = New-SecurityIssue -Type 'Test' -Severity 'Low' -Title 'Test' -Description 'Test' -File 'test.yml'
        $issue.File | Should -Be 'test.yml'
    }

    It 'Includes optional Line property' {
        $issue = New-SecurityIssue -Type 'Test' -Severity 'Low' -Title 'Test' -Description 'Test' -Line 42
        $issue.Line | Should -Be 42
    }

    It 'Includes optional Recommendation property' {
        $issue = New-SecurityIssue -Type 'Test' -Severity 'Low' -Title 'Test' -Description 'Test' -Recommendation 'Fix it'
        $issue.Recommendation | Should -Be 'Fix it'
    }

    It 'Defaults Line to 0' {
        $issue = New-SecurityIssue -Type 'Test' -Severity 'Low' -Title 'Test' -Description 'Test'
        $issue.Line | Should -Be 0
    }
}

Describe 'Write-SecurityReport' -Tag 'Unit' {
    BeforeEach {
        $script:testIssues = @(
            [PSCustomObject]@{
                Type           = 'UnpinnedAction'
                Severity       = 'High'
                Title          = 'Unpinned action'
                Description    = 'actions/checkout@v4'
                File           = '.github/workflows/ci.yml'
                Line           = 10
                Recommendation = 'Pin to SHA'
                Timestamp      = '2025-01-31 10:00:00'
            },
            [PSCustomObject]@{
                Type           = 'StaleSHA'
                Severity       = 'Medium'
                Title          = 'Stale SHA'
                Description    = 'SHA is 45 days old'
                File           = '.github/workflows/build.yml'
                Line           = 25
                Recommendation = 'Update SHA'
                Timestamp      = '2025-01-31 10:00:00'
            }
        )
    }

    Context 'JSON output' {
        It 'Returns valid JSON string' {
            $output = Write-SecurityReport -Results $script:testIssues -OutputFormat json
            { $output | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'Includes Summary in JSON' {
            $output = Write-SecurityReport -Results $script:testIssues -Summary 'Test summary' -OutputFormat json
            $json = $output | ConvertFrom-Json
            $json.Summary | Should -Be 'Test summary'
        }

        It 'Includes Issues array in JSON' {
            $output = Write-SecurityReport -Results $script:testIssues -OutputFormat json
            $json = $output | ConvertFrom-Json
            $json.Issues.Count | Should -Be 2
        }

        It 'Includes Timestamp in JSON' {
            $output = Write-SecurityReport -Results $script:testIssues -OutputFormat json
            $json = $output | ConvertFrom-Json
            $json.Timestamp | Should -Match '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}'
        }

        It 'Includes Count in JSON' {
            $output = Write-SecurityReport -Results $script:testIssues -OutputFormat json
            $json = $output | ConvertFrom-Json
            $json.Count | Should -Be 2
        }

        It 'Writes to file when OutputPath specified' {
            $outputFile = Join-Path $TestDrive 'report.json'
            Write-SecurityReport -Results $script:testIssues -OutputFormat json -OutputPath $outputFile
            Test-Path $outputFile | Should -BeTrue
            $content = Get-Content -Path $outputFile -Raw
            { $content | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'Creates output directory if not exists' {
            $outputFile = Join-Path $TestDrive 'nested/dir/report.json'
            Write-SecurityReport -Results $script:testIssues -OutputFormat json -OutputPath $outputFile
            Test-Path $outputFile | Should -BeTrue
        }

        It 'Handles empty results array' {
            $output = Write-SecurityReport -Results @() -OutputFormat json
            $json = $output | ConvertFrom-Json
            $json.Count | Should -Be 0
            $json.Issues.Count | Should -Be 0
        }
    }

    Context 'Console output' {
        It 'Shows success message when no issues' {
            # Capture console output (stream 6 is information)
            $output = Write-SecurityReport -Results @() -OutputFormat console 6>&1
            ($output -join ' ') | Should -Match 'No security issues found'
        }

        It 'Shows summary when provided with no issues' {
            $output = Write-SecurityReport -Results @() -Summary 'Scan complete' -OutputFormat console 6>&1
            ($output -join ' ') | Should -Match 'Scan complete'
        }

        It 'Shows warning header when issues found' {
            $output = Write-SecurityReport -Results $script:testIssues -OutputFormat console 6>&1
            ($output -join ' ') | Should -Match 'SECURITY ISSUES DETECTED'
        }

        It 'Outputs each issue severity and type' {
            $output = Write-SecurityReport -Results $script:testIssues -OutputFormat console 6>&1
            $text = $output -join ' '
            $text | Should -Match '\[High\].*UnpinnedAction'
            $text | Should -Match '\[Medium\].*StaleSHA'
        }

        It 'Shows total issue count' {
            $output = Write-SecurityReport -Results $script:testIssues -OutputFormat console 6>&1
            ($output -join ' ') | Should -Match 'Total issues: 2'
        }
    }

    Context 'Markdown output' {
        It 'Returns markdown table' {
            $output = Write-SecurityReport -Results $script:testIssues -OutputFormat markdown
            $output | Should -Match '\| Severity \| Type \| Title \| File \| Line \|'
            $output | Should -Match '\|----------|------|-------|------|------|'
        }

        It 'Shows checkmark when no issues' {
            $output = Write-SecurityReport -Results @() -OutputFormat markdown
            $output | Should -Match ':white_check_mark:'
            $output | Should -Match 'No security issues found'
        }

        It 'Includes summary when provided' {
            $output = Write-SecurityReport -Results $script:testIssues -Summary 'Scan complete' -OutputFormat markdown
            $output | Should -Match 'Scan complete'
        }

        It 'Includes total count header' {
            $output = Write-SecurityReport -Results $script:testIssues -OutputFormat markdown
            $output | Should -Match '\*\*Total issues: 2\*\*'
        }

        It 'Formats issue rows correctly' {
            $output = Write-SecurityReport -Results $script:testIssues -OutputFormat markdown
            $output | Should -Match '\| High \| UnpinnedAction \| Unpinned action \|'
            $output | Should -Match '\| Medium \| StaleSHA \| Stale SHA \|'
        }

        It 'Writes to file when OutputPath specified' {
            $outputFile = Join-Path $TestDrive 'report.md'
            Write-SecurityReport -Results $script:testIssues -OutputFormat markdown -OutputPath $outputFile
            Test-Path $outputFile | Should -BeTrue
            $content = Get-Content -Path $outputFile -Raw
            $content | Should -Match '## Security Scan Results'
        }

        It 'Uses dash for missing File' {
            $issueNoFile = @([PSCustomObject]@{
                    Type           = 'Test'
                    Severity       = 'Low'
                    Title          = 'Test'
                    Description    = 'Test'
                    File           = $null
                    Line           = 0
                    Recommendation = 'Fix'
                    Timestamp      = '2025-01-31 10:00:00'
                })
            $output = Write-SecurityReport -Results $issueNoFile -OutputFormat markdown
            $output | Should -Match '\| - \| - \|$'
        }
    }
}

Describe 'Test-GitHubToken' -Tag 'Unit' {
    Context 'Token validation' {
        It 'Returns hashtable with expected keys' {
            Mock Invoke-RestMethod -ModuleName SecurityHelpers { throw 'Simulated error' }
            $result = Test-GitHubToken -Token 'test-token'
            $result.Keys | Should -Contain 'IsValid'
            $result.Keys | Should -Contain 'RateLimit'
            $result.Keys | Should -Contain 'Remaining'
            $result.Keys | Should -Contain 'ResetTime'
            $result.Keys | Should -Contain 'Message'
        }

        It 'Returns invalid for empty token' {
            $result = Test-GitHubToken -Token ''
            $result.IsValid | Should -BeFalse
            $result.Message | Should -Be 'Token is empty or null'
        }

        It 'Returns invalid for null-like token' {
            $result = Test-GitHubToken -Token ([string]::Empty)
            $result.IsValid | Should -BeFalse
        }

        It 'Sets appropriate message for 401 response' {
            Mock Invoke-RestMethod -ModuleName SecurityHelpers {
                $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::Unauthorized)
                $exception = [Microsoft.PowerShell.Commands.HttpResponseException]::new('Unauthorized', $response)
                throw $exception
            }
            $result = Test-GitHubToken -Token 'invalid-token'
            $result.IsValid | Should -BeFalse
            $result.Message | Should -Be 'Token is invalid or expired'
        }

        It 'Sets appropriate message for 403 response' {
            Mock Invoke-RestMethod -ModuleName SecurityHelpers {
                $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::Forbidden)
                $exception = [Microsoft.PowerShell.Commands.HttpResponseException]::new('Forbidden', $response)
                throw $exception
            }
            $result = Test-GitHubToken -Token 'forbidden-token'
            $result.IsValid | Should -BeFalse
            $result.Message | Should -Be 'Token lacks required permissions or rate limit exceeded'
        }

        It 'Handles successful token validation' {
            Mock Invoke-RestMethod -ModuleName SecurityHelpers {
                @{
                    rate = @{
                        limit     = 5000
                        remaining = 4999
                        reset     = [DateTimeOffset]::UtcNow.AddHours(1).ToUnixTimeSeconds()
                    }
                }
            }
            $result = Test-GitHubToken -Token 'valid-token'
            $result.IsValid | Should -BeTrue
            $result.RateLimit | Should -Be 5000
            $result.Remaining | Should -Be 4999
            $result.Message | Should -Be 'Token validated successfully'
        }

        It 'Sets ResetTime from Unix timestamp' {
            $resetTime = [DateTimeOffset]::UtcNow.AddHours(1)
            Mock Invoke-RestMethod -ModuleName SecurityHelpers {
                @{
                    rate = @{
                        limit     = 5000
                        remaining = 4999
                        reset     = $resetTime.ToUnixTimeSeconds()
                    }
                }
            }
            $result = Test-GitHubToken -Token 'valid-token'
            $result.ResetTime | Should -BeOfType [datetime]
        }
    }
}

Describe 'Invoke-GitHubAPIWithRetry' -Tag 'Unit' {
    Context 'Successful requests' {
        It 'Returns response on successful GET' {
            Mock Invoke-RestMethod -ModuleName SecurityHelpers { @{ data = 'test' } }
            $headers = @{ Authorization = 'Bearer test' }
            $result = Invoke-GitHubAPIWithRetry -Uri 'https://api.github.com/test' -Headers $headers
            $result.data | Should -Be 'test'
        }

        It 'Passes Body for POST requests' {
            Mock Invoke-RestMethod -ModuleName SecurityHelpers -ParameterFilter { $Body -eq '{"test":"data"}' } { @{ success = $true } }
            $headers = @{ Authorization = 'Bearer test' }
            $result = Invoke-GitHubAPIWithRetry -Uri 'https://api.github.com/test' -Method POST -Headers $headers -Body '{"test":"data"}'
            $result.success | Should -BeTrue
        }

        It 'Uses GET method by default' {
            Mock Invoke-RestMethod -ModuleName SecurityHelpers -ParameterFilter { $Method -eq 'GET' } { @{ method = 'GET' } }
            $headers = @{ Authorization = 'Bearer test' }
            $result = Invoke-GitHubAPIWithRetry -Uri 'https://api.github.com/test' -Headers $headers
            $result.method | Should -Be 'GET'
        }
    }

    Context 'Retry behavior' {
        It 'Retries on 429 rate limit' {
            $script:callCount = 0
            Mock Invoke-RestMethod -ModuleName SecurityHelpers {
                $script:callCount++
                if ($script:callCount -lt 2) {
                    $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::TooManyRequests)
                    $exception = [Microsoft.PowerShell.Commands.HttpResponseException]::new('Rate limited', $response)
                    throw $exception
                }
                return @{ success = $true }
            }
            $headers = @{ Authorization = 'Bearer test' }
            $result = Invoke-GitHubAPIWithRetry -Uri 'https://api.github.com/test' -Headers $headers -InitialDelaySeconds 1
            $result.success | Should -BeTrue
            $script:callCount | Should -Be 2
        }

        It 'Retries on 5xx server errors' {
            $script:callCount = 0
            Mock Invoke-RestMethod -ModuleName SecurityHelpers {
                $script:callCount++
                if ($script:callCount -lt 2) {
                    $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::InternalServerError)
                    $exception = [Microsoft.PowerShell.Commands.HttpResponseException]::new('Server error', $response)
                    throw $exception
                }
                return @{ success = $true }
            }
            $headers = @{ Authorization = 'Bearer test' }
            $result = Invoke-GitHubAPIWithRetry -Uri 'https://api.github.com/test' -Headers $headers -InitialDelaySeconds 1
            $result.success | Should -BeTrue
        }

        It 'Does not retry on 404 errors' {
            $script:callCount = 0
            Mock Invoke-RestMethod -ModuleName SecurityHelpers {
                $script:callCount++
                $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::NotFound)
                $exception = [Microsoft.PowerShell.Commands.HttpResponseException]::new('Not found', $response)
                throw $exception
            }
            $headers = @{ Authorization = 'Bearer test' }
            $result = Invoke-GitHubAPIWithRetry -Uri 'https://api.github.com/test' -Headers $headers -InitialDelaySeconds 1 2>$null
            $result | Should -BeNullOrEmpty
            $script:callCount | Should -Be 1
        }

        It 'Returns null after max retries exceeded' {
            Mock Invoke-RestMethod -ModuleName SecurityHelpers {
                $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::TooManyRequests)
                $exception = [Microsoft.PowerShell.Commands.HttpResponseException]::new('Rate limited', $response)
                throw $exception
            }
            $headers = @{ Authorization = 'Bearer test' }
            $result = Invoke-GitHubAPIWithRetry -Uri 'https://api.github.com/test' -Headers $headers -MaxRetries 2 -InitialDelaySeconds 1 2>$null 3>$null
            $result | Should -BeNullOrEmpty
        }

        It 'Uses exponential backoff' {
            $script:delays = @()
            $script:callCount = 0
            Mock Start-Sleep -ModuleName SecurityHelpers { $script:delays += $Seconds }
            Mock Invoke-RestMethod -ModuleName SecurityHelpers {
                $script:callCount++
                $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::TooManyRequests)
                $exception = [Microsoft.PowerShell.Commands.HttpResponseException]::new('Rate limited', $response)
                throw $exception
            }
            $headers = @{ Authorization = 'Bearer test' }
            Invoke-GitHubAPIWithRetry -Uri 'https://api.github.com/test' -Headers $headers -MaxRetries 3 -InitialDelaySeconds 2 2>$null 3>$null
            # Should have delays of 2, 4 (exponential backoff)
            $script:delays.Count | Should -Be 2
            $script:delays[0] | Should -Be 2
            $script:delays[1] | Should -Be 4
        }
    }

    Context 'Parameter validation' {
        It 'Validates Method parameter' {
            $headers = @{ Authorization = 'Bearer test' }
            { Invoke-GitHubAPIWithRetry -Uri 'https://api.github.com/test' -Method 'INVALID' -Headers $headers } | Should -Throw
        }

        It 'Validates MaxRetries range' {
            $headers = @{ Authorization = 'Bearer test' }
            { Invoke-GitHubAPIWithRetry -Uri 'https://api.github.com/test' -Headers $headers -MaxRetries 0 } | Should -Throw
            { Invoke-GitHubAPIWithRetry -Uri 'https://api.github.com/test' -Headers $headers -MaxRetries 11 } | Should -Throw
        }

        It 'Validates InitialDelaySeconds range' {
            $headers = @{ Authorization = 'Bearer test' }
            { Invoke-GitHubAPIWithRetry -Uri 'https://api.github.com/test' -Headers $headers -InitialDelaySeconds 0 } | Should -Throw
            { Invoke-GitHubAPIWithRetry -Uri 'https://api.github.com/test' -Headers $headers -InitialDelaySeconds 61 } | Should -Throw
        }
    }

    Context 'Message-based status code extraction (cross-platform fallback)' {
        # These tests verify that status codes can be extracted from exception message text
        # when Response.StatusCode is unavailable (common on Linux)

        It 'Maps "Not found" message to 404 and does not retry' {
            $script:callCount = 0
            Mock Invoke-RestMethod -ModuleName SecurityHelpers {
                $script:callCount++
                throw [System.InvalidOperationException]::new('Not found')
            }
            $headers = @{ Authorization = 'Bearer test' }
            $result = Invoke-GitHubAPIWithRetry -Uri 'https://api.github.com/test' -Headers $headers -InitialDelaySeconds 1 2>$null
            $result | Should -BeNullOrEmpty
            $script:callCount | Should -Be 1  # 404 is not retryable
        }

        It 'Maps "Unauthorized" message to 401 and does not retry' {
            $script:callCount = 0
            Mock Invoke-RestMethod -ModuleName SecurityHelpers {
                $script:callCount++
                throw [System.InvalidOperationException]::new('Unauthorized')
            }
            $headers = @{ Authorization = 'Bearer test' }
            $result = Invoke-GitHubAPIWithRetry -Uri 'https://api.github.com/test' -Headers $headers -InitialDelaySeconds 1 2>$null
            $result | Should -BeNullOrEmpty
            $script:callCount | Should -Be 1  # 401 is not retryable
        }

        It 'Maps "Forbidden" message to 403 and retries' {
            $script:callCount = 0
            Mock Invoke-RestMethod -ModuleName SecurityHelpers {
                $script:callCount++
                if ($script:callCount -lt 2) {
                    throw [System.InvalidOperationException]::new('Forbidden')
                }
                return @{ success = $true }
            }
            $headers = @{ Authorization = 'Bearer test' }
            $result = Invoke-GitHubAPIWithRetry -Uri 'https://api.github.com/test' -Headers $headers -InitialDelaySeconds 1 3>$null
            $result.success | Should -BeTrue
            $script:callCount | Should -Be 2  # 403 is retryable (rate limit)
        }

        It 'Maps "Rate limited" message to 429 and retries' {
            $script:callCount = 0
            Mock Invoke-RestMethod -ModuleName SecurityHelpers {
                $script:callCount++
                if ($script:callCount -lt 2) {
                    throw [System.InvalidOperationException]::new('Rate limited')
                }
                return @{ success = $true }
            }
            $headers = @{ Authorization = 'Bearer test' }
            $result = Invoke-GitHubAPIWithRetry -Uri 'https://api.github.com/test' -Headers $headers -InitialDelaySeconds 1 3>$null
            $result.success | Should -BeTrue
            $script:callCount | Should -Be 2  # 429 is retryable
        }

        It 'Maps "Too many requests" message to 429 and retries' {
            $script:callCount = 0
            Mock Invoke-RestMethod -ModuleName SecurityHelpers {
                $script:callCount++
                if ($script:callCount -lt 2) {
                    throw [System.InvalidOperationException]::new('Too many requests')
                }
                return @{ success = $true }
            }
            $headers = @{ Authorization = 'Bearer test' }
            $result = Invoke-GitHubAPIWithRetry -Uri 'https://api.github.com/test' -Headers $headers -InitialDelaySeconds 1 3>$null
            $result.success | Should -BeTrue
            $script:callCount | Should -Be 2
        }

        It 'Maps "Server error" message to 500 and retries' {
            $script:callCount = 0
            Mock Invoke-RestMethod -ModuleName SecurityHelpers {
                $script:callCount++
                if ($script:callCount -lt 2) {
                    throw [System.InvalidOperationException]::new('Server error')
                }
                return @{ success = $true }
            }
            $headers = @{ Authorization = 'Bearer test' }
            $result = Invoke-GitHubAPIWithRetry -Uri 'https://api.github.com/test' -Headers $headers -InitialDelaySeconds 1 3>$null
            $result.success | Should -BeTrue
            $script:callCount | Should -Be 2
        }

        It 'Maps "Internal server error" message to 500 and retries' {
            $script:callCount = 0
            Mock Invoke-RestMethod -ModuleName SecurityHelpers {
                $script:callCount++
                if ($script:callCount -lt 2) {
                    throw [System.InvalidOperationException]::new('Internal server error occurred')
                }
                return @{ success = $true }
            }
            $headers = @{ Authorization = 'Bearer test' }
            $result = Invoke-GitHubAPIWithRetry -Uri 'https://api.github.com/test' -Headers $headers -InitialDelaySeconds 1 3>$null
            $result.success | Should -BeTrue
            $script:callCount | Should -Be 2
        }

        It 'Maps "Bad gateway" message to 502 and retries' {
            $script:callCount = 0
            Mock Invoke-RestMethod -ModuleName SecurityHelpers {
                $script:callCount++
                if ($script:callCount -lt 2) {
                    throw [System.InvalidOperationException]::new('Bad gateway')
                }
                return @{ success = $true }
            }
            $headers = @{ Authorization = 'Bearer test' }
            $result = Invoke-GitHubAPIWithRetry -Uri 'https://api.github.com/test' -Headers $headers -InitialDelaySeconds 1 3>$null
            $result.success | Should -BeTrue
            $script:callCount | Should -Be 2
        }

        It 'Maps "Service unavailable" message to 503 and retries' {
            $script:callCount = 0
            Mock Invoke-RestMethod -ModuleName SecurityHelpers {
                $script:callCount++
                if ($script:callCount -lt 2) {
                    throw [System.InvalidOperationException]::new('Service unavailable')
                }
                return @{ success = $true }
            }
            $headers = @{ Authorization = 'Bearer test' }
            $result = Invoke-GitHubAPIWithRetry -Uri 'https://api.github.com/test' -Headers $headers -InitialDelaySeconds 1 3>$null
            $result.success | Should -BeTrue
            $script:callCount | Should -Be 2
        }

        It 'Maps "Gateway timeout" message to 504 and retries' {
            $script:callCount = 0
            Mock Invoke-RestMethod -ModuleName SecurityHelpers {
                $script:callCount++
                if ($script:callCount -lt 2) {
                    throw [System.InvalidOperationException]::new('Gateway timeout')
                }
                return @{ success = $true }
            }
            $headers = @{ Authorization = 'Bearer test' }
            $result = Invoke-GitHubAPIWithRetry -Uri 'https://api.github.com/test' -Headers $headers -InitialDelaySeconds 1 3>$null
            $result.success | Should -BeTrue
            $script:callCount | Should -Be 2
        }

        It 'Handles case-insensitive message matching' {
            $script:callCount = 0
            Mock Invoke-RestMethod -ModuleName SecurityHelpers {
                $script:callCount++
                if ($script:callCount -lt 2) {
                    throw [System.InvalidOperationException]::new('RATE LIMITED')
                }
                return @{ success = $true }
            }
            $headers = @{ Authorization = 'Bearer test' }
            $result = Invoke-GitHubAPIWithRetry -Uri 'https://api.github.com/test' -Headers $headers -InitialDelaySeconds 1 3>$null
            $result.success | Should -BeTrue
            $script:callCount | Should -Be 2
        }

        It 'Does not retry unknown errors when no status code is extractable' {
            $script:callCount = 0
            Mock Invoke-RestMethod -ModuleName SecurityHelpers {
                $script:callCount++
                throw [System.InvalidOperationException]::new('Some unknown network error')
            }
            $headers = @{ Authorization = 'Bearer test' }
            $result = Invoke-GitHubAPIWithRetry -Uri 'https://api.github.com/test' -Headers $headers -InitialDelaySeconds 1 2>$null
            $result | Should -BeNullOrEmpty
            $script:callCount | Should -Be 1  # Unknown errors are not retried
        }
    }
}
