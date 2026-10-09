#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../security/Get-CodeScanningExceptionStatus.ps1')

    $script:CheckDate = [datetime]'2026-10-02'
    $script:Upstream = 'https://github.com/github/codeql/issues/1'

    function script:New-Alert {
        param([string]$Tool = 'CodeQL', [string]$Rule = 'js/missing-origin-check', [string]$Path = 'docs/slides/deck.html', [int]$Number = 42)
        [pscustomobject]@{
            tool                 = [pscustomobject]@{ name = $Tool }
            rule                 = [pscustomobject]@{ id = $Rule }
            html_url             = "https://github.com/owner/repo/security/code-scanning/$Number"
            most_recent_instance = [pscustomobject]@{ location = [pscustomobject]@{ path = $Path } }
        }
    }
    $script:OpenAlerts = @(New-Alert)

    function script:Write-ExceptionsFile {
        param([Parameter(Mandatory)][string]$Yaml)
        $path = Join-Path $TestDrive "exceptions-$([guid]::NewGuid()).yml"
        Set-Content -LiteralPath $path -Value $Yaml -Encoding utf8
        return $path
    }

    $script:Entry = @'
exceptions:
  - tool: CodeQL
    rule: js/missing-origin-check
    path: docs/slides/deck.html
    count: 1
    kind: false-positive
    upstream: https://github.com/github/codeql/issues/1
    issue: 1234
    owner: octocat
    reason: upstream false positive
    expires: 2026-10-30
'@
}

Describe 'Get-CodeScanningExceptionStatus' -Tag 'Unit' {
    It 'reports an exception whose alert is still open with days left and v2 fields' {
        $status = Get-CodeScanningExceptionStatus -ExceptionsPath (Write-ExceptionsFile $script:Entry) -OpenAlerts $script:OpenAlerts -CheckDate $script:CheckDate

        $status | Should -HaveCount 1
        $status[0].Tool | Should -Be 'CodeQL'
        $status[0].Rule | Should -Be 'js/missing-origin-check'
        $status[0].Count | Should -Be 1
        $status[0].Kind | Should -Be 'false-positive'
        $status[0].Upstream | Should -Be $script:Upstream
        $status[0].Issue | Should -Be 1234
        $status[0].Expires | Should -Be '2026-10-30'
        $status[0].DaysLeft | Should -Be 28
        $status[0].AlertOpen | Should -BeTrue
        $status[0].OpenAlertCount | Should -Be 1
        $status[0].AlertUrl | Should -Be 'https://github.com/owner/repo/security/code-scanning/42'
    }

    It 'reports AlertOpen false when no open alert matches the path' {
        $yaml = $script:Entry.Replace('docs/slides/deck.html', 'docs/slides/other.html')
        $status = Get-CodeScanningExceptionStatus -ExceptionsPath (Write-ExceptionsFile $yaml) -OpenAlerts $script:OpenAlerts -CheckDate $script:CheckDate

        $status[0].AlertOpen | Should -BeFalse
        $status[0].OpenAlertCount | Should -Be 0
        $status[0].AlertUrl | Should -Be ''
    }

    It 'reports alert state <Expected> when <Case>' -ForEach @(
        @{ Case = 'a matching alert is open'; Path = 'docs/slides/deck.html'; Observed = @(); Expected = 'open' }
        @{ Case = 'the tool has an analysis and no matching alert'; Path = 'docs/slides/other.html'; Observed = @('CodeQL'); Expected = 'closed' }
        @{ Case = 'the tool has no analysis on the branch'; Path = 'docs/slides/other.html'; Observed = @('zizmor'); Expected = 'not-observed' }
        @{ Case = 'only a differently cased tool has an analysis'; Path = 'docs/slides/other.html'; Observed = @('codeql'); Expected = 'not-observed' }
    ) {
        $yaml = $script:Entry.Replace('docs/slides/deck.html', $Path)
        $status = Get-CodeScanningExceptionStatus -ExceptionsPath (Write-ExceptionsFile $yaml) -OpenAlerts $script:OpenAlerts -CheckDate $script:CheckDate -ObservedTools $Observed

        $status[0].AlertState | Should -BeExactly $Expected
    }

    It 'does not match an alert from a different tool' {
        $status = Get-CodeScanningExceptionStatus -ExceptionsPath (Write-ExceptionsFile $script:Entry) -OpenAlerts @(New-Alert -Tool 'zizmor') -CheckDate $script:CheckDate

        $status[0].AlertOpen | Should -BeFalse
    }

    It 'counts every open alert for the tool, rule, and path' {
        $alerts = @((New-Alert -Number 1), (New-Alert -Number 2), (New-Alert -Path 'other.html' -Number 3))
        $status = Get-CodeScanningExceptionStatus -ExceptionsPath (Write-ExceptionsFile $script:Entry) -OpenAlerts $alerts -CheckDate $script:CheckDate

        $status[0].OpenAlertCount | Should -Be 2
    }

    It 'reports the supplied upstream state <State>' -ForEach @(@{ State = 'open' }, @{ State = 'closed' }) {
        $status = Get-CodeScanningExceptionStatus -ExceptionsPath (Write-ExceptionsFile $script:Entry) -OpenAlerts $script:OpenAlerts -CheckDate $script:CheckDate -UpstreamStates @{ $script:Upstream = $State }

        $status[0].UpstreamState | Should -Be $State
    }

    It 'reports unknown when the upstream state was not looked up' {
        $status = Get-CodeScanningExceptionStatus -ExceptionsPath (Write-ExceptionsFile $script:Entry) -OpenAlerts $script:OpenAlerts -CheckDate $script:CheckDate

        $status[0].UpstreamState | Should -Be 'unknown'
    }

    It 'reports negative days left for an expired exception' {
        $yaml = $script:Entry.Replace('2026-10-30', '2026-09-30')
        $status = Get-CodeScanningExceptionStatus -ExceptionsPath (Write-ExceptionsFile $yaml) -OpenAlerts $script:OpenAlerts -CheckDate $script:CheckDate

        $status[0].DaysLeft | Should -Be -2
    }

    It 'returns an empty list for the shipped empty file' {
        $status = Get-CodeScanningExceptionStatus -ExceptionsPath (Write-ExceptionsFile 'exceptions: []') -OpenAlerts $script:OpenAlerts -CheckDate $script:CheckDate

        @($status) | Should -HaveCount 0
    }

    It 'skips an entry without an issue number' {
        $yaml = $script:Entry.Replace('    issue: 1234', '    issue: none')
        $status = Get-CodeScanningExceptionStatus -ExceptionsPath (Write-ExceptionsFile $yaml) -OpenAlerts $script:OpenAlerts -CheckDate $script:CheckDate -WarningAction SilentlyContinue

        @($status) | Should -HaveCount 0
    }

    It 'skips an entry without a tool' {
        $yaml = $script:Entry.Replace('  - tool: CodeQL', '  - tool:')
        $status = Get-CodeScanningExceptionStatus -ExceptionsPath (Write-ExceptionsFile $yaml) -OpenAlerts $script:OpenAlerts -CheckDate $script:CheckDate -WarningAction SilentlyContinue

        @($status) | Should -HaveCount 0
    }

    It 'reads the repository exceptions file as shipped' {
        $repoFile = Join-Path $PSScriptRoot '../../../security/code-scanning-exceptions.yml'
        $shipped = @((Get-Content -LiteralPath $repoFile -Raw | ConvertFrom-Yaml)['exceptions'])
        $status = Get-CodeScanningExceptionStatus -ExceptionsPath $repoFile -OpenAlerts @() -CheckDate ([datetime]::UtcNow.Date)

        @($status) | Should -HaveCount $shipped.Count
        @($status | Where-Object { $_.DaysLeft -lt 0 }) | Should -BeNullOrEmpty
    }
}

Describe 'Get-ExceptionFieldValue' -Tag 'Unit' {
    It 'returns the field from every shipped entry' {
        $repoFile = Join-Path $PSScriptRoot '../../../security/code-scanning-exceptions.yml'
        $shipped = @((Get-Content -LiteralPath $repoFile -Raw | ConvertFrom-Yaml)['exceptions'])
        $tools = Get-ExceptionFieldValue -ExceptionsPath $repoFile -Field 'tool'

        $tools.Count | Should -Be $shipped.Count
        $tools | Should -Contain 'CodeQL'
    }

    It 'returns an empty list for an empty register' {
        $values = Get-ExceptionFieldValue -ExceptionsPath (Write-ExceptionsFile 'exceptions: []') -Field 'upstream'

        $values.Count | Should -Be 0
    }
}

Describe 'Get-GitHubIssueApiPath' -Tag 'Unit' {
    It 'converts <Url>' -ForEach @(
        @{ Url = 'https://github.com/github/codeql/issues/17'; Expected = 'repos/github/codeql/issues/17' }
        @{ Url = 'https://github.com/boostsecurityio/poutine/pull/348/'; Expected = 'repos/boostsecurityio/poutine/issues/348' }
    ) {
        Get-GitHubIssueApiPath -Url $Url | Should -Be $Expected
    }

    It 'returns null for <Url>' -ForEach @(
        @{ Url = 'https://example.com/bugs/1' }
        @{ Url = 'https://github.com/github/codeql/discussions/5' }
        @{ Url = '' }
    ) {
        Get-GitHubIssueApiPath -Url $Url | Should -BeNullOrEmpty
    }
}

Describe 'Get-UpstreamState' -Tag 'Unit' {
    It 'records gh results once per URL and marks non-GitHub URLs unknown' {
        Mock gh { $global:LASTEXITCODE = 0; 'closed' }
        $states = Get-UpstreamState -Url @('https://github.com/a/b/issues/1', 'https://example.com/x', 'https://github.com/a/b/issues/1')

        $states['https://github.com/a/b/issues/1'] | Should -Be 'closed'
        $states['https://example.com/x'] | Should -Be 'unknown'
        Should -Invoke gh -Times 1 -Exactly
    }

    It 'reports unknown when the lookup fails' {
        Mock gh { $global:LASTEXITCODE = 1; '' }
        $states = Get-UpstreamState -Url @('https://github.com/a/b/issues/2')

        $states['https://github.com/a/b/issues/2'] | Should -Be 'unknown'
    }
}

Describe 'Get-ObservedTool' -Tag 'Unit' {
    It 'keeps tools with an analysis and drops empty and 404 results' {
        Mock gh {
            $global:LASTEXITCODE = 0
            switch -Wildcard ("$args") {
                '*tool_name=CodeQL&*' { '1' }
                '*tool_name=zizmor&*' { '0' }
                default { $global:LASTEXITCODE = 1; 'gh: no analysis found (HTTP 404)' }
            }
        }
        $observed = Get-ObservedTool -Owner 'o' -Repo 'r' -Branch 'main' -Tool @('CodeQL', 'zizmor', 'hve-workflow-validator', 'CodeQL')

        $observed | Should -Be @('CodeQL')
        Should -Invoke gh -Times 3 -Exactly
    }

    It 'warns and leaves a tool out when the lookup fails' {
        Mock gh { $global:LASTEXITCODE = 1; 'gh: Resource not accessible by integration (HTTP 403)' }
        $observed = Get-ObservedTool -Owner 'o' -Repo 'r' -Branch 'main' -Tool @('CodeQL') -WarningVariable warnings -WarningAction SilentlyContinue

        @($observed) | Should -HaveCount 0
        "$warnings" | Should -Match 'not-observed'
    }

    It 'filters by ref and URL-encoded tool name' {
        Mock gh { $global:LASTEXITCODE = 0; '1' }
        Get-ObservedTool -Owner 'o' -Repo 'r' -Branch 'main' -Tool @('dependency pinning') | Out-Null

        Should -Invoke gh -Times 1 -Exactly -ParameterFilter { "$args" -like '*repos/o/r/code-scanning/analyses?ref=refs/heads/main&tool_name=dependency%20pinning&per_page=1*' }
    }
}
