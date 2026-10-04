#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../security/Get-CodeScanningExceptionStatus.ps1')

    $script:CheckDate = [datetime]'2026-10-02'
    $script:OpenAlerts = @(
        [pscustomobject]@{
            rule                 = [pscustomobject]@{ id = 'js/missing-origin-check' }
            html_url             = 'https://github.com/owner/repo/security/code-scanning/42'
            most_recent_instance = [pscustomobject]@{ location = [pscustomobject]@{ path = 'docs/slides/deck.html' } }
        }
    )

    function script:Write-ExceptionsFile {
        param([Parameter(Mandatory)][string]$Yaml)
        $path = Join-Path $TestDrive "exceptions-$([guid]::NewGuid()).yml"
        Set-Content -LiteralPath $path -Value $Yaml -Encoding utf8
        return $path
    }

    $script:Entry = @'
exceptions:
  - rule: js/missing-origin-check
    path: docs/slides/deck.html
    issue: 1234
    owner: octocat
    reason: upstream false positive, reported at example
    expires: 2026-10-30
'@
}

Describe 'Get-CodeScanningExceptionStatus' -Tag 'Unit' {
    It 'reports an exception whose alert is still open with days left' {
        $status = Get-CodeScanningExceptionStatus -ExceptionsPath (Write-ExceptionsFile $script:Entry) -OpenAlerts $script:OpenAlerts -CheckDate $script:CheckDate

        $status | Should -HaveCount 1
        $status[0].Rule | Should -Be 'js/missing-origin-check'
        $status[0].Issue | Should -Be 1234
        $status[0].Expires | Should -Be '2026-10-30'
        $status[0].DaysLeft | Should -Be 28
        $status[0].AlertOpen | Should -BeTrue
        $status[0].AlertUrl | Should -Be 'https://github.com/owner/repo/security/code-scanning/42'
    }

    It 'reports AlertOpen false when no open alert matches the path' {
        $yaml = $script:Entry.Replace('docs/slides/deck.html', 'docs/slides/other.html')
        $status = Get-CodeScanningExceptionStatus -ExceptionsPath (Write-ExceptionsFile $yaml) -OpenAlerts $script:OpenAlerts -CheckDate $script:CheckDate

        $status[0].AlertOpen | Should -BeFalse
        $status[0].AlertUrl | Should -Be ''
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

    It 'reads the repository exceptions file as shipped' {
        $repoFile = Join-Path $PSScriptRoot '../../../security/code-scanning-exceptions.yml'
        $status = Get-CodeScanningExceptionStatus -ExceptionsPath $repoFile -OpenAlerts @() -CheckDate $script:CheckDate

        @($status) | Should -HaveCount 0
    }
}
