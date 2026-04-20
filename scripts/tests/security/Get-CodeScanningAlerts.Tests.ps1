#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../security/Get-CodeScanningAlerts.ps1'
    $script:OriginalGhPager = $env:GH_PAGER

    # Sample alert JSON representing two rules with multiple occurrences
    $script:MockAlertJson = '[{"number":1,"rule":{"id":"js/sql-injection","description":"Database query built from user-controlled sources","security_severity_level":"high"},"tool":{"name":"CodeQL"},"most_recent_instance":{"location":{"path":"src/db.js"}}},{"number":2,"rule":{"id":"js/sql-injection","description":"Database query built from user-controlled sources","security_severity_level":"high"},"tool":{"name":"CodeQL"},"most_recent_instance":{"location":{"path":"src/api.js"}}},{"number":3,"rule":{"id":"js/xss","description":"Cross-site scripting vulnerability","security_severity_level":"medium"},"tool":{"name":"CodeQL"},"most_recent_instance":{"location":{"path":"src/render.js"}}}]'
}

AfterAll {
    $env:GH_PAGER = $script:OriginalGhPager
}

Describe 'Get-CodeScanningAlerts' -Tag 'Unit' {

    BeforeEach {
        # Create a gh function in current scope; child scopes (scripts called with &) inherit it.
        # This intercepts calls to 'gh' without relying on Pester Mock for external executables.
        $script:capturedGhArgs = $null
        $capturedArgsRef = [ref]$script:capturedGhArgs
        $mockJson = $script:MockAlertJson
        ${Function:gh} = {
            $capturedArgsRef.Value = $args
            $global:LASTEXITCODE = 0
            return $mockJson
        }.GetNewClosure()
    }

    AfterEach {
        Remove-Item -Path 'Function:gh' -ErrorAction SilentlyContinue
        $global:LASTEXITCODE = 0
    }

    Context 'Pager suppression' {
        It 'Sets GH_PAGER to empty string before invoking gh' {
            & $script:ScriptPath -Owner 'testorg' -Repo 'testrepo' | Out-Null

            $env:GH_PAGER | Should -Be ''
        }
    }

    Context 'Default output format (Table)' {
        It 'Produces output when OutputFormat is Table (default)' {
            $result = & $script:ScriptPath -Owner 'testorg' -Repo 'testrepo' | Out-String

            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'JSON output format' {
        It 'Produces valid JSON array when OutputFormat is Json' {
            $result = & $script:ScriptPath -Owner 'testorg' -Repo 'testrepo' -OutputFormat Json

            $parsed = $result | ConvertFrom-Json
            $parsed | Should -Not -BeNullOrEmpty
            $parsed.Count | Should -BeGreaterThan 0
        }

        It 'Groups alerts by rule and sorts by count descending' {
            $result = & $script:ScriptPath -Owner 'testorg' -Repo 'testrepo' -OutputFormat Json
            $parsed = $result | ConvertFrom-Json

            $parsed[0].RuleId | Should -Be 'js/sql-injection'
            $parsed[0].Count | Should -Be 2
            $parsed[1].RuleId | Should -Be 'js/xss'
            $parsed[1].Count | Should -Be 1
        }

        It 'Produces valid JSON array when OutputFormat is GroupedJson' {
            $result = & $script:ScriptPath -Owner 'testorg' -Repo 'testrepo' -OutputFormat GroupedJson

            $parsed = $result | ConvertFrom-Json
            $parsed | Should -Not -BeNullOrEmpty
            $parsed.Count | Should -BeGreaterThan 0
        }

        It 'Serializes SamplePaths as a JSON array even when only one path exists' {
            # js/xss has a single occurrence; verify the raw JSON uses bracket notation,
            # not a bare string (ConvertFrom-Json re-unwraps single-element arrays so
            # the raw string is the authoritative check)
            $result = & $script:ScriptPath -Owner 'testorg' -Repo 'testrepo' -OutputFormat Json
            $rawJson = $result | Out-String

            $rawJson | Should -Match '"SamplePaths":\s*\['
        }

        It 'Serializes SamplePaths as a JSON array when alert has no associated file path' {
            $noPathJson = '[{"number":10,"rule":{"id":"BranchProtectionID","description":"Branch-Protection","security_severity_level":"high"},"tool":{"name":"Scorecard"},"most_recent_instance":{"location":{"path":"no file associated with this alert"}}}]'
            ${Function:gh} = {
                $global:LASTEXITCODE = 0
                return $noPathJson
            }.GetNewClosure()

            $result = & $script:ScriptPath -Owner 'testorg' -Repo 'testrepo' -OutputFormat Json
            $rawJson = $result | Out-String

            $rawJson | Should -Match '"SamplePaths":\s*\['
            $rawJson | Should -Match 'no file associated with this alert'
        }

        It 'Deduplicates and sorts SamplePaths across multiple occurrences of the same rule' {
            $multiPathJson = '[{"number":1,"rule":{"id":"py/empty-except","description":"Empty except","security_severity_level":null},"tool":{"name":"CodeQL"},"most_recent_instance":{"location":{"path":"scripts/b.py"}}},{"number":2,"rule":{"id":"py/empty-except","description":"Empty except","security_severity_level":null},"tool":{"name":"CodeQL"},"most_recent_instance":{"location":{"path":"scripts/a.py"}}},{"number":3,"rule":{"id":"py/empty-except","description":"Empty except","security_severity_level":null},"tool":{"name":"CodeQL"},"most_recent_instance":{"location":{"path":"scripts/a.py"}}}]'
            ${Function:gh} = {
                $global:LASTEXITCODE = 0
                return $multiPathJson
            }.GetNewClosure()

            $result = & $script:ScriptPath -Owner 'testorg' -Repo 'testrepo' -OutputFormat Json
            $parsed = $result | ConvertFrom-Json

            $parsed[0].SamplePaths | Should -HaveCount 2
            $parsed[0].SamplePaths[0] | Should -Be 'scripts/a.py'
            $parsed[0].SamplePaths[1] | Should -Be 'scripts/b.py'
        }
    }

    Context 'Branch parameter' {
        It 'Defaults to main branch when Branch is not specified' {
            & $script:ScriptPath -Owner 'testorg' -Repo 'testrepo' | Out-Null

            $script:capturedGhArgs | Should -Contain 'repos/testorg/testrepo/code-scanning/alerts?state=open&ref=refs/heads/main&per_page=100'
        }

        It 'Uses specified branch when Branch is provided' {
            & $script:ScriptPath -Owner 'testorg' -Repo 'testrepo' -Branch 'develop' | Out-Null

            $script:capturedGhArgs | Should -Contain 'repos/testorg/testrepo/code-scanning/alerts?state=open&ref=refs/heads/develop&per_page=100'
        }
    }

    Context 'Error propagation' {
        It 'Throws when gh api returns non-zero exit code' {
            ${Function:gh} = {
                $global:LASTEXITCODE = 1
                return 'Error: authentication required'
            }

            { & $script:ScriptPath -Owner 'testorg' -Repo 'testrepo' } | Should -Throw
        }

        It 'Throws with scope refresh hint when gh api returns 403' {
            ${Function:gh} = {
                if ($args[0] -eq 'auth') {
                    $global:LASTEXITCODE = 0
                    return 'Logged in to github.com'
                }
                $global:LASTEXITCODE = 1
                return 'HTTP 403: Resource not accessible by integration'
            }

            { & $script:ScriptPath -Owner 'testorg' -Repo 'testrepo' } | Should -Throw '*gh auth refresh -s security_events*'
        }
    }
}

Describe 'Get-CodeScanningAlerts - Prerequisite guards' -Tag 'Unit' {

    BeforeEach {
        Remove-Item 'Function:gh' -ErrorAction SilentlyContinue
        $global:LASTEXITCODE = 0
    }

    AfterEach {
        Remove-Item 'Function:gh' -ErrorAction SilentlyContinue
        Remove-Item 'Function:Get-Command' -ErrorAction SilentlyContinue
        $global:LASTEXITCODE = 0
    }

    Context 'gh CLI not available' {
        It 'Throws with gh install link when gh is not on PATH' {
            # Shadow Get-Command so it reports gh as missing regardless of environment
            ${Function:Get-Command} = {
                if ($args[0] -eq 'gh') { return $null }
                Microsoft.PowerShell.Core\Get-Command @args
            }

            { & $script:ScriptPath -Owner 'testorg' -Repo 'testrepo' } | Should -Throw '*https://cli.github.com*'
        }
    }

    Context 'gh CLI not authenticated' {
        It 'Throws with auth hint when gh auth status returns non-zero' {
            $mockJson = $script:MockAlertJson
            ${Function:gh} = {
                if ($args[0] -eq 'auth') {
                    $global:LASTEXITCODE = 1
                    return 'You are not logged into any GitHub hosts.'
                }
                $global:LASTEXITCODE = 0
                return $mockJson
            }.GetNewClosure()

            { & $script:ScriptPath -Owner 'testorg' -Repo 'testrepo' } | Should -Throw '*gh auth login*'
        }
    }
}
