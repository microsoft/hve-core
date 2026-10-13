#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../scripts/Get-CodeScanningAlerts.ps1'
    $script:OriginalGhPager = $env:GH_PAGER

    # Sample alert JSON representing two rules with multiple occurrences
    $script:MockAlertJson = '[{"number":1,"rule":{"id":"js/sql-injection","description":"Database query built from user-controlled sources","security_severity_level":"high","severity":"error"},"tool":{"name":"CodeQL"},"html_url":"https://github.com/owner/repo/security/code-scanning/1","most_recent_instance":{"location":{"path":"src/db.js"},"message":{"text":"SQL injection from user input"}}},{"number":2,"rule":{"id":"js/sql-injection","description":"Database query built from user-controlled sources","security_severity_level":"high","severity":"error"},"tool":{"name":"CodeQL"},"html_url":"https://github.com/owner/repo/security/code-scanning/2","most_recent_instance":{"location":{"path":"src/api.js"},"message":{"text":"SQL injection from user input"}}},{"number":3,"rule":{"id":"js/xss","description":"Cross-site scripting vulnerability","security_severity_level":"medium","severity":"warning"},"tool":{"name":"CodeQL"},"html_url":"https://github.com/owner/repo/security/code-scanning/3","most_recent_instance":{"location":{"path":"src/render.js"},"message":{"text":"Unsanitized input rendered"}}}]'
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
        BeforeEach {
            $env:GH_PAGER = 'pager-was-set'
            ${Function:gh} = { $global:LASTEXITCODE = 0 }.GetNewClosure()
            & $script:ScriptPath -Owner 'owner' -Repo 'repo'
        }
        AfterEach {
            Remove-Item Env:GH_PAGER -ErrorAction SilentlyContinue
        }

        It 'Suppresses pager by clearing GH_PAGER before invoking gh' {
            $env:GH_PAGER | Should -BeNullOrEmpty
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

        It 'Serializes AffectedPaths as a JSON array even when only one path exists' {
            # js/xss has a single occurrence; verify the raw JSON uses bracket notation,
            # not a bare string (ConvertFrom-Json re-unwraps single-element arrays so
            # the raw string is the authoritative check)
            $result = & $script:ScriptPath -Owner 'testorg' -Repo 'testrepo' -OutputFormat Json
            $rawJson = $result | Out-String

            $rawJson | Should -Match '"AffectedPaths":\s*\['
        }

        It 'Serializes a single rule group as a JSON array' {
            # Regression: one group previously serialized as a bare object, which broke the
            # workflow consumer that iterates with jq '.[]'. Json and GroupedJson share the
            # same switch branch, so this covers both.
            $singleRuleJson = '[{"number":1,"rule":{"id":"VulnerabilitiesID","description":"Vulnerabilities","security_severity_level":"high"},"tool":{"name":"Scorecard"},"most_recent_instance":{"location":{"path":"no file associated with this alert"}}}]'
            ${Function:gh} = {
                $global:LASTEXITCODE = 0
                return $singleRuleJson
            }.GetNewClosure()

            $rawJson = (& $script:ScriptPath -Owner 'testorg' -Repo 'testrepo' -OutputFormat Json | Out-String).Trim()

            $rawJson | Should -BeLike '`[*`]'
            $rawJson | ConvertFrom-Json | Should -HaveCount 1
        }

        It 'Serializes an empty result as an empty JSON array' {
            ${Function:gh} = {
                $global:LASTEXITCODE = 0
                return '[]'
            }.GetNewClosure()

            $rawJson = (& $script:ScriptPath -Owner 'testorg' -Repo 'testrepo' -OutputFormat Json | Out-String).Trim()

            $rawJson | Should -Be '[]'
        }

        It 'Serializes multiple rule groups as a JSON array' {
            $rawJson = (& $script:ScriptPath -Owner 'testorg' -Repo 'testrepo' -OutputFormat Json | Out-String).Trim()

            $rawJson | Should -BeLike '`[*`]'
            $rawJson | ConvertFrom-Json | Should -HaveCount 2
        }

        It 'Serializes AffectedPaths as empty array and sets HasFilePaths false when alert has no associated file path' {
            $noPathJson = '[{"number":10,"rule":{"id":"BranchProtectionID","description":"Branch-Protection","security_severity_level":"high"},"tool":{"name":"Scorecard"},"most_recent_instance":{"location":{"path":"no file associated with this alert"}}}]'
            ${Function:gh} = {
                $global:LASTEXITCODE = 0
                return $noPathJson
            }.GetNewClosure()

            $result = & $script:ScriptPath -Owner 'testorg' -Repo 'testrepo' -OutputFormat Json
            $parsed = $result | ConvertFrom-Json

            $parsed[0].AffectedPaths | Should -HaveCount 0
            $parsed[0].HasFilePaths | Should -BeFalse
        }

        It 'Deduplicates and sorts AffectedPaths across multiple occurrences of the same rule' {
            $multiPathJson = '[{"number":1,"rule":{"id":"py/empty-except","description":"Empty except","security_severity_level":null},"tool":{"name":"CodeQL"},"most_recent_instance":{"location":{"path":"scripts/b.py"}}},{"number":2,"rule":{"id":"py/empty-except","description":"Empty except","security_severity_level":null},"tool":{"name":"CodeQL"},"most_recent_instance":{"location":{"path":"scripts/a.py"}}},{"number":3,"rule":{"id":"py/empty-except","description":"Empty except","security_severity_level":null},"tool":{"name":"CodeQL"},"most_recent_instance":{"location":{"path":"scripts/a.py"}}}]'
            ${Function:gh} = {
                $global:LASTEXITCODE = 0
                return $multiPathJson
            }.GetNewClosure()

            $result = & $script:ScriptPath -Owner 'testorg' -Repo 'testrepo' -OutputFormat Json
            $parsed = $result | ConvertFrom-Json

            $parsed[0].AffectedPaths | Should -HaveCount 2
            $parsed[0].AffectedPaths[0] | Should -Be 'scripts/a.py'
            $parsed[0].AffectedPaths[1] | Should -Be 'scripts/b.py'
        }

        It 'Includes Severity field in grouped output' {
            $result = & $script:ScriptPath -Owner 'testorg' -Repo 'testrepo' -OutputFormat Json
            $parsed = $result | ConvertFrom-Json

            $parsed[0].Severity | Should -Be 'error'
        }

        It 'Includes AlertUrl field in grouped output' {
            $result = & $script:ScriptPath -Owner 'testorg' -Repo 'testrepo' -OutputFormat Json
            $parsed = $result | ConvertFrom-Json

            $parsed[0].AlertUrl | Should -Match '/security/code-scanning/'
        }

        It 'Includes FindingDescription field in grouped output' {
            $result = & $script:ScriptPath -Owner 'testorg' -Repo 'testrepo' -OutputFormat Json
            $parsed = $result | ConvertFrom-Json

            $parsed[0].FindingDescription | Should -Not -BeNullOrEmpty
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

    Context 'Dismissed alerts still detected' {
        BeforeEach {
            $openJson = '[{"number":1,"state":"open","rule":{"id":"js/xss","description":"Cross-site scripting vulnerability","security_severity_level":"medium","severity":"warning"},"tool":{"name":"CodeQL"},"html_url":"https://github.com/owner/repo/security/code-scanning/1","most_recent_instance":{"state":"open","location":{"path":"src/render.js"},"message":{"text":"Unsanitized input rendered"}}}]'
            $script:dismissedJson = '[]'
            $script:ghCalls = [System.Collections.Generic.List[string]]::new()
            $callsRef = $script:ghCalls
            $dismissedRef = [ref]$script:dismissedJson
            ${Function:gh} = {
                if ($args[0] -eq 'auth') { $global:LASTEXITCODE = 0; return 'Logged in' }
                $callsRef.Add([string]$args[1])
                $global:LASTEXITCODE = 0
                if ($args[1] -like '*state=dismissed*') { return $dismissedRef.Value }
                return $openJson
            }.GetNewClosure()
        }

        It 'Includes a dismissed alert whose instance on the branch is still open' {
            $script:dismissedJson = '[{"number":7,"state":"dismissed","dismissed_reason":"false positive","rule":{"id":"py/unused-global-variable","description":"Unused global variable","severity":"note"},"tool":{"name":"CodeQL"},"html_url":"https://github.com/owner/repo/security/code-scanning/7","most_recent_instance":{"state":"open","location":{"path":"src/state.py"},"message":{"text":"The global variable is not used."}}}]'

            $parsed = & $script:ScriptPath -Owner 'testorg' -Repo 'testrepo' -OutputFormat Json -IncludeDismissedStillDetected | ConvertFrom-Json

            $parsed | Should -HaveCount 2
            $parsed[0].RuleId | Should -Be 'js/xss'
            $parsed[0].PSObject.Properties.Name | Should -Not -Contain 'Kind'
            $parsed[1].RuleId | Should -Be 'py/unused-global-variable'
            $parsed[1].Kind | Should -Be 'dismissed-still-detected'
            $parsed[1].DismissedReason | Should -Be 'false positive'
            $parsed[1].AffectedPaths | Should -Be 'src/state.py'
            $script:ghCalls | Should -Contain 'repos/testorg/testrepo/code-scanning/alerts?state=dismissed&ref=refs/heads/main&per_page=100'
        }

        It 'Includes a dismissed alert whose branch instance reports dismissed' {
            $script:dismissedJson = '[{"number":8,"state":"dismissed","dismissed_reason":"won''t fix","rule":{"id":"py/overly-permissive-file","description":"Overly permissive file permissions","security_severity_level":"high"},"tool":{"name":"CodeQL"},"most_recent_instance":{"state":"dismissed","location":{"path":"tests/test_perm.py"}}}]'

            $parsed = & $script:ScriptPath -Owner 'testorg' -Repo 'testrepo' -OutputFormat Json -IncludeDismissedStillDetected | ConvertFrom-Json

            ($parsed | Where-Object Kind -eq 'dismissed-still-detected').RuleId | Should -Be 'py/overly-permissive-file'
        }

        It 'Excludes a dismissed alert whose instance on the branch is fixed' {
            $script:dismissedJson = '[{"number":9,"state":"dismissed","dismissed_reason":"false positive","rule":{"id":"py/clear-text-logging-sensitive-data","description":"Clear-text logging of sensitive information","security_severity_level":"high"},"tool":{"name":"CodeQL"},"most_recent_instance":{"state":"fixed","location":{"path":"src/output.py"}}},{"number":10,"state":"dismissed","dismissed_reason":"false positive","rule":{"id":"py/unused-global-variable","description":"Unused global variable"},"tool":{"name":"CodeQL"},"most_recent_instance":{"state":"open","location":{"path":"src/state.py"}}}]'

            $parsed = & $script:ScriptPath -Owner 'testorg' -Repo 'testrepo' -OutputFormat Json -IncludeDismissedStillDetected | ConvertFrom-Json
            $dismissed = @($parsed | Where-Object Kind -eq 'dismissed-still-detected')

            $dismissed | Should -HaveCount 1
            $dismissed[0].RuleId | Should -Be 'py/unused-global-variable'
        }

        It 'Adds nothing when there are no dismissed alerts' {
            $rawJson = (& $script:ScriptPath -Owner 'testorg' -Repo 'testrepo' -OutputFormat Json -IncludeDismissedStillDetected | Out-String).Trim()

            $parsed = $rawJson | ConvertFrom-Json
            $rawJson | Should -BeLike '`[*`]'
            @($parsed) | Should -HaveCount 1
            @($parsed | Where-Object Kind) | Should -HaveCount 0
        }

        It 'Does not query dismissed alerts unless the option is set' {
            & $script:ScriptPath -Owner 'testorg' -Repo 'testrepo' -OutputFormat Json | Out-Null

            $script:ghCalls | Should -Not -Contain 'repos/testorg/testrepo/code-scanning/alerts?state=dismissed&ref=refs/heads/main&per_page=100'
            @($script:ghCalls | Where-Object { $_ -like '*state=dismissed*' }) | Should -HaveCount 0
        }

        It 'Shows the Kind column in table output when the option is set' {
            $script:dismissedJson = '[{"number":7,"state":"dismissed","rule":{"id":"py/unused-global-variable","description":"Unused global variable"},"tool":{"name":"CodeQL"},"most_recent_instance":{"state":"open","location":{"path":"src/state.py"}}}]'

            $table = & $script:ScriptPath -Owner 'testorg' -Repo 'testrepo' -IncludeDismissedStillDetected | Out-String

            $table | Should -Match 'Kind'
            $table | Should -Match 'dismissed-still-detected'
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
