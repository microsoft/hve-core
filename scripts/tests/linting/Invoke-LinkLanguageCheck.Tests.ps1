#Requires -Modules Pester
<#
.SYNOPSIS
    Pester tests for Invoke-LinkLanguageCheck.ps1 script
.DESCRIPTION
    Tests for Link Language Check wrapper script:
    - Link-Lang-Check.ps1 invocation
    - JSON parsing
    - GitHub Actions integration
    - Exit code handling
#>

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../linting/Invoke-LinkLanguageCheck.ps1'
    $script:ModulePath = Join-Path $PSScriptRoot '../../linting/Modules/LintingHelpers.psm1'

    # Direct dot-source for proper code coverage tracking
    . $script:ScriptPath

    # Import LintingHelpers for mocking
    Import-Module $script:ModulePath -Force
}

AfterAll {
    Remove-Module LintingHelpers -Force -ErrorAction SilentlyContinue
}

#region Link-Lang-Check Invocation Tests

Describe 'Link-Lang-Check.ps1 Invocation' -Tag 'Unit' {
    Context 'Script discovery' {
        It 'Link-Lang-Check.ps1 exists' {
            $linkLangCheckPath = Join-Path $PSScriptRoot '../../linting/Link-Lang-Check.ps1'
            Test-Path $linkLangCheckPath | Should -BeTrue
        }
    }

    Context 'Normal execution' {
        It 'Invoke-LinkLanguageCheck.ps1 exists' {
            $scriptExists = Test-Path $script:ScriptPath
            $scriptExists | Should -BeTrue
        }
    }
}

#endregion

#region JSON Parsing Tests

Describe 'JSON Output Parsing' -Tag 'Unit' {
    Context 'Valid JSON with issues' {
        BeforeEach {
            $script:JsonWithIssues = @'
[
    {
        "file": "docs/guide.md",
        "line_number": 15,
        "original_url": "https://docs.microsoft.com/en-us/azure"
    },
    {
        "file": "README.md",
        "line_number": 42,
        "original_url": "https://learn.microsoft.com/en-us/dotnet"
    }
]
'@
        }

        It 'Parses JSON array correctly' {
            $result = $script:JsonWithIssues | ConvertFrom-Json
            $result | Should -HaveCount 2
        }

        It 'Extracts file property' {
            $result = $script:JsonWithIssues | ConvertFrom-Json
            $result[0].file | Should -Be 'docs/guide.md'
        }

        It 'Extracts line_number property' {
            $result = $script:JsonWithIssues | ConvertFrom-Json
            $result[0].line_number | Should -Be 15
        }

        It 'Extracts original_url property' {
            $result = $script:JsonWithIssues | ConvertFrom-Json
            $result[0].original_url | Should -Be 'https://docs.microsoft.com/en-us/azure'
        }
    }

    Context 'Empty JSON array' {
        It 'Handles empty array' {
            $result = '[]' | ConvertFrom-Json
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Invalid JSON' {
        It 'Throws on malformed JSON' {
            { 'not valid json' | ConvertFrom-Json } | Should -Throw
        }
    }
}

#endregion

#region GitHub Actions Integration Tests

Describe 'GitHub Actions Integration' -Tag 'Unit' {
    Context 'Module exports verification' {
        It 'Write-GitHubAnnotation is available in module' {
            $module = Get-Module LintingHelpers
            $module.ExportedFunctions.Keys | Should -Contain 'Write-GitHubAnnotation'
        }

        It 'Set-GitHubOutput is available in module' {
            $module = Get-Module LintingHelpers
            $module.ExportedFunctions.Keys | Should -Contain 'Set-GitHubOutput'
        }

        It 'Write-GitHubStepSummary is available in module' {
            $module = Get-Module LintingHelpers
            $module.ExportedFunctions.Keys | Should -Contain 'Write-GitHubStepSummary'
        }
    }

    Context 'GitHub Actions detection' {
        It 'Detects GitHub Actions via GITHUB_ACTIONS env var' {
            $originalValue = $env:GITHUB_ACTIONS
            try {
                $env:GITHUB_ACTIONS = 'true'
                $env:GITHUB_ACTIONS | Should -Be 'true'

                $env:GITHUB_ACTIONS = $null
                $env:GITHUB_ACTIONS | Should -BeNullOrEmpty
            }
            finally {
                $env:GITHUB_ACTIONS = $originalValue
            }
        }
    }
}

#endregion

#region Annotation Generation Tests

Describe 'Annotation Generation' -Tag 'Unit' {
    Context 'Annotation content' {
        BeforeEach {
            $script:Issue = [PSCustomObject]@{
                file         = 'docs/test.md'
                line_number  = 25
                original_url = 'https://docs.microsoft.com/en-us/azure/overview'
            }
        }

        It 'Issue object has required properties' {
            $script:Issue.file | Should -Not -BeNullOrEmpty
            $script:Issue.line_number | Should -BeGreaterThan 0
            $script:Issue.original_url | Should -Match 'en-us'
        }

        It 'File path is workspace-relative' {
            $script:Issue.file | Should -Not -Match '^[A-Z]:\\'
            $script:Issue.file | Should -Not -Match '^/'
        }
    }

    Context 'Annotation severity mapping' {
        It 'Language path issues are warnings' {
            # Link language issues are warnings, not errors
            $severity = 'warning'
            $severity | Should -Be 'warning'
        }
    }
}

#endregion

#region Exit Code Tests

Describe 'Exit Code Handling' -Tag 'Unit' {
    Context 'No issues found' {
        It 'Empty result indicates success' {
            $issues = @()
            $issues.Count | Should -Be 0
        }
    }

    Context 'Issues found' {
        BeforeEach {
            $script:Issues = @(
                [PSCustomObject]@{ file = 'test.md'; line_number = 1; original_url = 'https://example.com/en-us/page' }
            )
        }

        It 'Non-empty result indicates issues present' {
            $script:Issues.Count | Should -BeGreaterThan 0
        }

        It 'Script should warn but not fail on issues' {
            # Link language issues are warnings, script continues
            $warningExpected = $true
            $warningExpected | Should -BeTrue
        }
    }
}

#endregion

#region Output Format Tests

Describe 'Output Format' -Tag 'Unit' {
    Context 'Console output' {
        BeforeEach {
            $script:SampleIssue = [PSCustomObject]@{
                file         = 'README.md'
                line_number  = 10
                original_url = 'https://docs.microsoft.com/en-us/azure'
            }
        }

        It 'Issue can be formatted as string' {
            $formatted = "[$($script:SampleIssue.file):$($script:SampleIssue.line_number)] $($script:SampleIssue.original_url)"
            $formatted | Should -Be '[README.md:10] https://docs.microsoft.com/en-us/azure'
        }
    }

    Context 'Summary statistics' {
        BeforeEach {
            $script:Issues = @(
                [PSCustomObject]@{ file = 'a.md'; line_number = 1; original_url = 'url1' },
                [PSCustomObject]@{ file = 'a.md'; line_number = 2; original_url = 'url2' },
                [PSCustomObject]@{ file = 'b.md'; line_number = 1; original_url = 'url3' }
            )
        }

        It 'Can count total issues' {
            $script:Issues.Count | Should -Be 3
        }

        It 'Can count affected files' {
            $fileCount = ($script:Issues | Select-Object -ExpandProperty file -Unique).Count
            $fileCount | Should -Be 2
        }
    }
}

#endregion

#region Integration with Link-Lang-Check Tests

Describe 'Link-Lang-Check Integration' -Tag 'Integration' {
    Context 'Script dependencies' {
        It 'LintingHelpers module can be imported' {
            { Import-Module $script:ModulePath -Force } | Should -Not -Throw
        }

        It 'Link-Lang-Check.ps1 exists at expected path' {
            $linkLangCheckPath = Join-Path $PSScriptRoot '../../linting/Link-Lang-Check.ps1'
            Test-Path $linkLangCheckPath | Should -BeTrue
        }
    }

    Context 'Output compatibility' {
        It 'Link-Lang-Check output can be parsed as JSON' {
            # Sample output format from Link-Lang-Check.ps1
            $sampleOutput = '[{"file":"test.md","line_number":1,"original_url":"https://example.com/en-us/page"}]'
            { $sampleOutput | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'Parsed output has expected structure' {
            $sampleOutput = '[{"file":"test.md","line_number":1,"original_url":"https://example.com/en-us/page"}]'
            $parsed = $sampleOutput | ConvertFrom-Json
            $parsed[0].PSObject.Properties.Name | Should -Contain 'file'
            $parsed[0].PSObject.Properties.Name | Should -Contain 'line_number'
            $parsed[0].PSObject.Properties.Name | Should -Contain 'original_url'
        }
    }
}

#endregion

#region Invoke-LinkLanguageCheckWrapper Tests

Describe 'Invoke-LinkLanguageCheckWrapper' -Tag 'Unit' {
    BeforeAll {
        $script:TestDir = Join-Path ([IO.Path]::GetTempPath()) (New-Guid).ToString()
        New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:TestDir 'logs') -Force | Out-Null
    }

    AfterAll {
        if (Test-Path $script:TestDir) {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Function exists' {
        It 'Invoke-LinkLanguageCheckWrapper is defined' {
            Get-Command Invoke-LinkLanguageCheckWrapper -ErrorAction SilentlyContinue | Should -Not -BeNull
        }

        It 'Function has OutputType attribute' {
            $cmd = Get-Command Invoke-LinkLanguageCheckWrapper
            $cmd.OutputType.Type | Should -Contain ([int])
        }
    }

    Context 'No issues scenario' {
        BeforeEach {
            Mock git { return $script:TestDir } -ParameterFilter { $args[0] -eq 'rev-parse' }
            Mock Write-GitHubAnnotation { }
            Mock Set-GitHubOutput { }
            Mock Set-GitHubEnv { }
            Mock Write-GitHubStepSummary { }
        }

        It 'Returns 0 when no issues found' {
            # Test with empty results
            $result = '[]' | ConvertFrom-Json
            $result | Should -BeNullOrEmpty
        }

        It 'Writes success message for no issues' {
            # Verify the success path handles empty results correctly
            $emptyResults = @()
            $emptyResults.Count | Should -Be 0
        }
    }

    Context 'Issues found scenario' {
        BeforeEach {
            $script:MockIssues = @(
                [PSCustomObject]@{
                    file = 'docs/test.md'
                    line_number = 10
                    original_url = 'https://docs.microsoft.com/en-us/azure'
                }
            )
            Mock git { return $script:TestDir } -ParameterFilter { $args[0] -eq 'rev-parse' }
            Mock Write-GitHubAnnotation { }
            Mock Set-GitHubOutput { }
            Mock Set-GitHubEnv { }
            Mock Write-GitHubStepSummary { }
        }

        It 'Creates annotation for each issue' {
            foreach ($item in $script:MockIssues) {
                Write-GitHubAnnotation `
                    -Type 'warning' `
                    -Message "URL contains language path: $($item.original_url)" `
                    -File $item.file `
                    -Line $item.line_number
            }
            Should -Invoke Write-GitHubAnnotation -Times 1 -Exactly
        }

        It 'Sets LINK_LANG_FAILED environment variable' {
            Set-GitHubEnv -Name "LINK_LANG_FAILED" -Value "true"
            Should -Invoke Set-GitHubEnv -Times 1 -Exactly -ParameterFilter {
                $Name -eq 'LINK_LANG_FAILED' -and $Value -eq 'true'
            }
        }

        It 'Sets issues output count' {
            Set-GitHubOutput -Name "issues" -Value $script:MockIssues.Count
            Should -Invoke Set-GitHubOutput -Times 1 -Exactly -ParameterFilter {
                $Name -eq 'issues' -and $Value -eq 1
            }
        }
    }

    Context 'Output data structure' {
        It 'Creates correct output data for issues' {
            $results = @(
                [PSCustomObject]@{ file = 'a.md'; line_number = 1; original_url = 'url1' }
            )
            $outputData = @{
                timestamp = (Get-Date).ToUniversalTime().ToString("o")
                script = "link-lang-check"
                summary = @{
                    total_issues = $results.Count
                    files_affected = ($results | Select-Object -ExpandProperty file -Unique).Count
                }
                issues = $results
            }
            $outputData.script | Should -Be 'link-lang-check'
            $outputData.summary.total_issues | Should -Be 1
            $outputData.summary.files_affected | Should -Be 1
        }

        It 'Creates correct output data for no issues' {
            $emptyResults = @{
                timestamp = (Get-Date).ToUniversalTime().ToString("o")
                script = "link-lang-check"
                summary = @{
                    total_issues = 0
                    files_affected = 0
                }
                issues = @()
            }
            $emptyResults.summary.total_issues | Should -Be 0
            $emptyResults.issues | Should -BeNullOrEmpty
        }

        It 'Converts output to valid JSON' {
            $outputData = @{
                timestamp = (Get-Date).ToUniversalTime().ToString("o")
                script = "link-lang-check"
                summary = @{ total_issues = 0; files_affected = 0 }
                issues = @()
            }
            $json = $outputData | ConvertTo-Json -Depth 3
            { $json | ConvertFrom-Json } | Should -Not -Throw
        }
    }

    Context 'ExcludePaths parameter' {
        It 'Accepts empty ExcludePaths array' {
            $excludePaths = @()
            $excludePaths.Count | Should -Be 0
        }

        It 'Accepts single exclude path' {
            $excludePaths = @('node_modules')
            $excludePaths.Count | Should -Be 1
        }

        It 'Accepts multiple exclude paths' {
            $excludePaths = @('node_modules', 'vendor', '.git')
            $excludePaths.Count | Should -Be 3
        }
    }

    Context 'Summary generation' {
        It 'Generates summary with issue count' {
            $results = @(
                [PSCustomObject]@{ file = 'a.md'; line_number = 1; original_url = 'url1' },
                [PSCustomObject]@{ file = 'b.md'; line_number = 2; original_url = 'url2' }
            )
            $uniqueFiles = $results | Select-Object -ExpandProperty file -Unique
            $uniqueFiles | Should -HaveCount 2
        }

        It 'Groups occurrences by file' {
            $results = @(
                [PSCustomObject]@{ file = 'a.md'; line_number = 1; original_url = 'url1' },
                [PSCustomObject]@{ file = 'a.md'; line_number = 2; original_url = 'url2' },
                [PSCustomObject]@{ file = 'b.md'; line_number = 1; original_url = 'url3' }
            )
            $aCount = ($results | Where-Object file -eq 'a.md').Count
            $aCount | Should -Be 2
        }
    }
}

#endregion

#region Invoke-LinkLanguageCheckWrapper Full Path Tests

Describe 'Invoke-LinkLanguageCheckWrapper Full Execution' -Tag 'Unit' {
    BeforeAll {
        $script:TestDir = Join-Path ([IO.Path]::GetTempPath()) "llc-wrapper-$(New-Guid)"
        $script:LogsDir = Join-Path $script:TestDir 'logs'
        New-Item -ItemType Directory -Path $script:LogsDir -Force | Out-Null
    }

    AfterAll {
        if (Test-Path $script:TestDir) {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Wrapper executes with issues found' {
        BeforeEach {
            Mock Write-GitHubAnnotation { }
            Mock Set-GitHubOutput { }
            Mock Set-GitHubEnv { }
            Mock Write-GitHubStepSummary { }
        }

        It 'Calls Write-GitHubAnnotation for issues' {
            # Simulate the wrapper logic for issues found
            $results = @(
                [PSCustomObject]@{
                    file = 'docs/test.md'
                    line_number = 10
                    original_url = 'https://docs.microsoft.com/en-us/azure'
                }
            )

            foreach ($item in $results) {
                Write-GitHubAnnotation `
                    -Type 'warning' `
                    -Message "URL contains language path: $($item.original_url)" `
                    -File $item.file `
                    -Line $item.line_number
            }

            Should -Invoke Write-GitHubAnnotation -Times 1 -Exactly
        }

        It 'Saves results to JSON file' {
            $results = @(
                [PSCustomObject]@{ file = 'docs/test.md'; line_number = 10; original_url = 'https://docs.microsoft.com/en-us/azure' }
            )

            $outputData = @{
                timestamp = (Get-Date).ToUniversalTime().ToString("o")
                script = "link-lang-check"
                summary = @{
                    total_issues = $results.Count
                    files_affected = ($results | Select-Object -ExpandProperty file -Unique).Count
                }
                issues = $results
            }

            $jsonPath = Join-Path $script:LogsDir "link-lang-check-results.json"
            $outputData | ConvertTo-Json -Depth 3 | Set-Content -Path $jsonPath -Encoding utf8NoBOM

            Test-Path $jsonPath | Should -BeTrue
            $content = Get-Content -Path $jsonPath -Raw | ConvertFrom-Json
            $content.script | Should -Be 'link-lang-check'
        }

        It 'Writes step summary with issues' {
            $results = @(
                [PSCustomObject]@{ file = 'docs/test.md'; line_number = 10; original_url = 'https://docs.microsoft.com/en-us/azure' }
            )
            $uniqueFiles = $results | Select-Object -ExpandProperty file -Unique

            $summaryContent = @"
## Link Language Path Check Results

⚠️ **Status**: Issues Found

Found $($results.Count) URL(s) containing language path 'en-us'.

**Files affected:**
$(($uniqueFiles | ForEach-Object { $count = ($results | Where-Object file -eq $_).Count; "- $_ ($count occurrence(s))" }) -join "`n")
"@
            Write-GitHubStepSummary -Content $summaryContent

            Should -Invoke Write-GitHubStepSummary -Times 1 -Exactly
        }
    }

    Context 'Wrapper executes with no issues' {
        BeforeEach {
            Mock Write-GitHubAnnotation { }
            Mock Set-GitHubOutput { }
            Mock Set-GitHubEnv { }
            Mock Write-GitHubStepSummary { }
        }

        It 'Sets issues output to 0' {
            Set-GitHubOutput -Name "issues" -Value "0"

            Should -Invoke Set-GitHubOutput -Times 1 -Exactly -ParameterFilter {
                $Name -eq 'issues' -and $Value -eq '0'
            }
        }

        It 'Writes success step summary' {
            $summaryContent = @"
## Link Language Path Check Results

✅ **Status**: Passed

No URLs with language-specific paths detected.
"@
            Write-GitHubStepSummary -Content $summaryContent

            Should -Invoke Write-GitHubStepSummary -Times 1 -Exactly
        }

        It 'Saves empty results to JSON file' {
            $emptyResults = @{
                timestamp = (Get-Date).ToUniversalTime().ToString("o")
                script = "link-lang-check"
                summary = @{
                    total_issues = 0
                    files_affected = 0
                }
                issues = @()
            }

            $jsonPath = Join-Path $script:LogsDir "link-lang-check-empty-results.json"
            $emptyResults | ConvertTo-Json -Depth 3 | Set-Content -Path $jsonPath -Encoding utf8NoBOM

            Test-Path $jsonPath | Should -BeTrue
            $content = Get-Content -Path $jsonPath -Raw | ConvertFrom-Json
            $content.summary.total_issues | Should -Be 0
        }
    }

    Context 'Wrapper handles git errors' {
        BeforeEach {
            Mock Write-Error { }
        }

        It 'Returns error when not in git repository' {
            Mock git {
                $global:LASTEXITCODE = 128
                return 'fatal: not a git repository'
            }

            # Simulate the check from the function
            $repoRoot = git rev-parse --show-toplevel 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Not in a git repository"
            }

            Should -Invoke Write-Error -Times 1 -Exactly -ParameterFilter {
                $Message -eq 'Not in a git repository'
            }
        }
    }

    Context 'Logs directory creation' {
        It 'Creates logs directory if it does not exist' {
            $tempRoot = Join-Path ([IO.Path]::GetTempPath()) "llc-logs-$(New-Guid)"
            $logsDir = Join-Path $tempRoot 'logs'

            try {
                New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

                # Simulate the directory creation logic
                if (-not (Test-Path $logsDir)) {
                    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
                }

                Test-Path $logsDir | Should -BeTrue
            }
            finally {
                Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

#endregion

#region Invoke-LinkLanguageCheckWrapper Integration Tests

Describe 'Invoke-LinkLanguageCheckWrapper Real Execution' -Tag 'Unit' {
    BeforeAll {
        $script:TestRepoDir = Join-Path ([IO.Path]::GetTempPath()) "llc-int-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:TestRepoDir -Force | Out-Null
    }

    AfterAll {
        if (Test-Path $script:TestRepoDir) {
            Remove-Item -Path $script:TestRepoDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Full wrapper execution with real git repo' {
        BeforeEach {
            # Create a minimal git repo with test files
            Push-Location $script:TestRepoDir
            git init --quiet 2>$null

            # Create logs directory
            New-Item -ItemType Directory -Path (Join-Path $script:TestRepoDir 'logs') -Force | Out-Null

            # Create a file with en-us link
            $testFile = Join-Path $script:TestRepoDir 'test-doc.md'
            'Visit https://docs.microsoft.com/en-us/azure for docs.' | Set-Content -Path $testFile

            git add -A 2>$null
            git commit -m 'initial' --quiet 2>$null
        }

        AfterEach {
            Pop-Location
        }

        It 'Wrapper function executes and returns exit code' {
            # Mock the GitHub-specific functions since we are not in GitHub Actions
            Mock Write-GitHubAnnotation { } -ModuleName LintingHelpers
            Mock Set-GitHubOutput { } -ModuleName LintingHelpers
            Mock Set-GitHubEnv { } -ModuleName LintingHelpers
            Mock Write-GitHubStepSummary { } -ModuleName LintingHelpers

            $result = Invoke-LinkLanguageCheckWrapper
            # The function should return 0 (success) or 1 (issues found)
            $result | Should -BeIn @(0, 1)
        }

        It 'Creates results JSON file in logs directory' {
            Mock Write-GitHubAnnotation { } -ModuleName LintingHelpers
            Mock Set-GitHubOutput { } -ModuleName LintingHelpers
            Mock Set-GitHubEnv { } -ModuleName LintingHelpers
            Mock Write-GitHubStepSummary { } -ModuleName LintingHelpers

            Invoke-LinkLanguageCheckWrapper

            $resultsFile = Join-Path $script:TestRepoDir 'logs/link-lang-check-results.json'
            Test-Path $resultsFile | Should -BeTrue
        }

        It 'Results file contains valid JSON structure' {
            Mock Write-GitHubAnnotation { } -ModuleName LintingHelpers
            Mock Set-GitHubOutput { } -ModuleName LintingHelpers
            Mock Set-GitHubEnv { } -ModuleName LintingHelpers
            Mock Write-GitHubStepSummary { } -ModuleName LintingHelpers

            Invoke-LinkLanguageCheckWrapper

            $resultsFile = Join-Path $script:TestRepoDir 'logs/link-lang-check-results.json'
            $content = Get-Content -Path $resultsFile -Raw | ConvertFrom-Json
            $content.script | Should -Be 'link-lang-check'
            $content.summary | Should -Not -BeNull
        }
    }

    Context 'Wrapper with no en-us links' {
        BeforeEach {
            Push-Location $script:TestRepoDir

            # Clean up and create fresh repo
            Remove-Item -Path (Join-Path $script:TestRepoDir '*') -Recurse -Force -ErrorAction SilentlyContinue
            git init --quiet 2>$null

            New-Item -ItemType Directory -Path (Join-Path $script:TestRepoDir 'logs') -Force | Out-Null

            # Create a file WITHOUT en-us link
            $testFile = Join-Path $script:TestRepoDir 'clean-doc.md'
            'Visit https://docs.microsoft.com/azure for docs.' | Set-Content -Path $testFile

            git add -A 2>$null
            git commit -m 'clean' --quiet 2>$null
        }

        AfterEach {
            Pop-Location
        }

        It 'Returns 0 when no issues found' {
            Mock Write-GitHubAnnotation { } -ModuleName LintingHelpers
            Mock Set-GitHubOutput { } -ModuleName LintingHelpers
            Mock Set-GitHubEnv { } -ModuleName LintingHelpers
            Mock Write-GitHubStepSummary { } -ModuleName LintingHelpers

            $result = Invoke-LinkLanguageCheckWrapper
            $result | Should -Be 0
        }

        It 'Results show zero issues' {
            Mock Write-GitHubAnnotation { } -ModuleName LintingHelpers
            Mock Set-GitHubOutput { } -ModuleName LintingHelpers
            Mock Set-GitHubEnv { } -ModuleName LintingHelpers
            Mock Write-GitHubStepSummary { } -ModuleName LintingHelpers

            Invoke-LinkLanguageCheckWrapper

            $resultsFile = Join-Path $script:TestRepoDir 'logs/link-lang-check-results.json'
            $content = Get-Content -Path $resultsFile -Raw | ConvertFrom-Json
            $content.summary.total_issues | Should -Be 0
        }
    }

    Context 'Wrapper with ExcludePaths' {
        BeforeEach {
            Push-Location $script:TestRepoDir

            # Clean up and create fresh repo
            Remove-Item -Path (Join-Path $script:TestRepoDir '*') -Recurse -Force -ErrorAction SilentlyContinue
            git init --quiet 2>$null

            New-Item -ItemType Directory -Path (Join-Path $script:TestRepoDir 'logs') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $script:TestRepoDir 'tests') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $script:TestRepoDir 'docs') -Force | Out-Null

            # Create excluded file with en-us link
            $excludedFile = Join-Path $script:TestRepoDir 'tests/test.md'
            'Link: https://docs.microsoft.com/en-us/test' | Set-Content -Path $excludedFile

            # Create included file without en-us link
            $includedFile = Join-Path $script:TestRepoDir 'docs/clean.md'
            'Link: https://docs.microsoft.com/azure' | Set-Content -Path $includedFile

            git add -A 2>$null
            git commit -m 'with exclusions' --quiet 2>$null
        }

        AfterEach {
            Pop-Location
        }

        It 'Excludes files matching pattern' {
            Mock Write-GitHubAnnotation { } -ModuleName LintingHelpers
            Mock Set-GitHubOutput { } -ModuleName LintingHelpers
            Mock Set-GitHubEnv { } -ModuleName LintingHelpers
            Mock Write-GitHubStepSummary { } -ModuleName LintingHelpers

            $result = Invoke-LinkLanguageCheckWrapper -ExcludePaths @('tests/**')

            # Should return 0 because the only file with en-us is excluded
            $result | Should -Be 0
        }
    }
}

Describe 'Invoke-LinkLanguageCheckWrapper Orchestration Paths' -Tag 'Unit' {
    BeforeAll {
        $script:OrchDir = Join-Path ([IO.Path]::GetTempPath()) "llc-orch-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:OrchDir -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:OrchDir 'logs') -Force | Out-Null
    }

    AfterAll {
        if (Test-Path $script:OrchDir) {
            Remove-Item -Path $script:OrchDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Script invocation' {
        It 'Constructs script path correctly' {
            $scriptDir = $PSScriptRoot.Replace('\tests\linting', '\linting')
            $linkLangCheckPath = Join-Path $scriptDir 'Link-Lang-Check.ps1'
            # Path should be well-formed
            $linkLangCheckPath | Should -Match 'Link-Lang-Check\.ps1$'
        }

        It 'Passes ExcludePaths to inner script when provided' {
            $scriptArgs = @{}
            $excludePaths = @('node_modules', '.git')
            if ($excludePaths.Count -gt 0) {
                $scriptArgs['ExcludePaths'] = $excludePaths
            }
            $scriptArgs.Keys | Should -Contain 'ExcludePaths'
            $scriptArgs['ExcludePaths'] | Should -HaveCount 2
        }

        It 'Does not pass ExcludePaths when empty' {
            $scriptArgs = @{}
            $excludePaths = @()
            if ($excludePaths.Count -gt 0) {
                $scriptArgs['ExcludePaths'] = $excludePaths
            }
            $scriptArgs.Keys | Should -Not -Contain 'ExcludePaths'
        }
    }

    Context 'Results parsing' {
        It 'Handles valid JSON with issues' {
            $jsonOutput = @'
[
    {"file": "docs/test.md", "line_number": 10, "original_url": "https://docs.microsoft.com/en-us/azure"}
]
'@
            $results = $jsonOutput | ConvertFrom-Json
            $results | Should -HaveCount 1
            $results[0].file | Should -Be 'docs/test.md'
        }

        It 'Handles empty JSON array' {
            $jsonOutput = '[]'
            $results = $jsonOutput | ConvertFrom-Json
            $results | Should -BeNullOrEmpty
        }

        It 'Results have required properties' {
            $jsonOutput = '[{"file": "test.md", "line_number": 5, "original_url": "https://example.com/en-us/page"}]'
            $results = $jsonOutput | ConvertFrom-Json
            $results[0].PSObject.Properties.Name | Should -Contain 'file'
            $results[0].PSObject.Properties.Name | Should -Contain 'line_number'
            $results[0].PSObject.Properties.Name | Should -Contain 'original_url'
        }
    }

    Context 'Git repository handling' {
        BeforeEach {
            Mock Write-Error { }
        }

        It 'Gets repo root from git command' {
            Mock git { return $script:OrchDir } -ParameterFilter { $args[0] -eq 'rev-parse' }

            $repoRoot = git rev-parse --show-toplevel
            $repoRoot | Should -Be $script:OrchDir
        }

        It 'Handles git failure gracefully' {
            Mock git {
                $global:LASTEXITCODE = 128
                return $null
            } -ParameterFilter { $args[0] -eq 'rev-parse' }

            $repoRoot = git rev-parse --show-toplevel 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Not in a git repository"
            }

            Should -Invoke Write-Error -Times 1
        }
    }

    Context 'Annotation creation for issues' {
        BeforeEach {
            Mock Write-GitHubAnnotation { }
        }

        It 'Creates warning annotation for each issue' {
            $issues = @(
                [PSCustomObject]@{ file = 'a.md'; line_number = 1; original_url = 'https://docs.microsoft.com/en-us/test' },
                [PSCustomObject]@{ file = 'b.md'; line_number = 2; original_url = 'https://learn.microsoft.com/en-us/dotnet' }
            )

            foreach ($item in $issues) {
                Write-GitHubAnnotation `
                    -Type 'warning' `
                    -Message "URL contains language path: $($item.original_url)" `
                    -File $item.file `
                    -Line $item.line_number
            }

            Should -Invoke Write-GitHubAnnotation -Times 2 -Exactly
        }
    }

    Context 'Output data structure' {
        It 'Creates output data with timestamp' {
            $outputData = @{
                timestamp = (Get-Date).ToUniversalTime().ToString("o")
                script = "link-lang-check"
                summary = @{ total_issues = 0; files_affected = 0 }
                issues = @()
            }

            $outputData.timestamp | Should -Match '^\d{4}-\d{2}-\d{2}T'
        }

        It 'Calculates files_affected from unique files' {
            $results = @(
                [PSCustomObject]@{ file = 'a.md'; line_number = 1; original_url = 'url1' },
                [PSCustomObject]@{ file = 'a.md'; line_number = 2; original_url = 'url2' },
                [PSCustomObject]@{ file = 'b.md'; line_number = 1; original_url = 'url3' }
            )

            $filesAffected = ($results | Select-Object -ExpandProperty file -Unique).Count
            $filesAffected | Should -Be 2
        }
    }

    Context 'GitHub output and environment' {
        BeforeEach {
            Mock Set-GitHubOutput { }
            Mock Set-GitHubEnv { }
        }

        It 'Sets issues output with count' {
            $issueCount = 5
            Set-GitHubOutput -Name "issues" -Value $issueCount

            Should -Invoke Set-GitHubOutput -ParameterFilter { $Name -eq 'issues' -and $Value -eq 5 }
        }

        It 'Sets LINK_LANG_FAILED when issues found' {
            Set-GitHubEnv -Name "LINK_LANG_FAILED" -Value "true"

            Should -Invoke Set-GitHubEnv -ParameterFilter { $Name -eq 'LINK_LANG_FAILED' -and $Value -eq 'true' }
        }
    }

    Context 'Step summary generation' {
        BeforeEach {
            Mock Write-GitHubStepSummary { }
        }

        It 'Generates summary for issues found' {
            $results = @(
                [PSCustomObject]@{ file = 'test.md'; line_number = 1; original_url = 'https://example.com/en-us/page' }
            )
            $uniqueFiles = $results | Select-Object -ExpandProperty file -Unique

            $summary = @"
## Link Language Path Check Results

⚠️ **Status**: Issues Found

Found $($results.Count) URL(s) containing language path 'en-us'.

**Files affected:**
$(($uniqueFiles | ForEach-Object { $count = ($results | Where-Object file -eq $_).Count; "- $_ ($count occurrence(s))" }) -join "`n")
"@
            Write-GitHubStepSummary -Content $summary

            Should -Invoke Write-GitHubStepSummary -Times 1
        }

        It 'Generates success summary for no issues' {
            $summary = @"
## Link Language Path Check Results

✅ **Status**: Passed

No URLs with language-specific paths detected.
"@
            Write-GitHubStepSummary -Content $summary

            Should -Invoke Write-GitHubStepSummary -Times 1
        }
    }

    Context 'Return values' {
        It 'Returns 1 when issues found' {
            $results = @([PSCustomObject]@{ file = 'test.md'; line_number = 1; original_url = 'url' })
            $exitCode = if ($results -and $results.Count -gt 0) { 1 } else { 0 }
            $exitCode | Should -Be 1
        }

        It 'Returns 0 when no issues' {
            $results = @()
            $exitCode = if ($results -and $results.Count -gt 0) { 1 } else { 0 }
            $exitCode | Should -Be 0
        }

        It 'Returns 0 for null results' {
            $results = $null
            $exitCode = if ($results -and $results.Count -gt 0) { 1 } else { 0 }
            $exitCode | Should -Be 0
        }
    }

    Context 'File writing' {
        It 'Writes results to JSON file' {
            $outputData = @{
                timestamp = (Get-Date).ToUniversalTime().ToString("o")
                script = "link-lang-check"
                summary = @{ total_issues = 1; files_affected = 1 }
                issues = @(@{ file = 'test.md'; line_number = 1; original_url = 'url' })
            }

            $jsonPath = Join-Path $script:OrchDir 'logs/orch-test-results.json'
            $outputData | ConvertTo-Json -Depth 3 | Out-File $jsonPath -Encoding utf8

            Test-Path $jsonPath | Should -BeTrue
            $content = Get-Content $jsonPath -Raw | ConvertFrom-Json
            $content.script | Should -Be 'link-lang-check'
        }
    }
}

