#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../security/Test-CodeQLSarifThreshold.ps1')

    $script:CheckDate = [datetime]'2026-10-02'

    function script:New-SarifRule {
        param(
            [Parameter(Mandatory)][string]$Id,
            [string]$SecuritySeverity,
            [string]$DefaultLevel
        )
        $rule = [ordered]@{ id = $Id; properties = [ordered]@{} }
        if ($SecuritySeverity) { $rule.properties['security-severity'] = $SecuritySeverity }
        if ($DefaultLevel) { $rule.defaultConfiguration = @{ level = $DefaultLevel } }
        return $rule
    }

    function script:New-SarifResult {
        param(
            [Parameter(Mandatory)][string]$RuleId,
            [string]$Level,
            [string]$Path = 'src/app.py',
            [int]$Line = 10,
            [hashtable]$RuleReference
        )
        $result = [ordered]@{
            ruleId    = $RuleId
            message   = @{ text = 'finding' }
            locations = @(@{ physicalLocation = @{ artifactLocation = @{ uri = $Path }; region = @{ startLine = $Line } } })
        }
        if ($Level) { $result.level = $Level }
        if ($RuleReference) { $result.rule = $RuleReference }
        return $result
    }

    function script:Write-Sarif {
        param(
            [Parameter(Mandatory)][string]$Name,
            [object[]]$DriverRules = @(),
            [object[]]$ExtensionRules = @(),
            [object[]]$Results = @(),
            [string]$ToolName = 'CodeQL'
        )
        $tool = [ordered]@{ driver = [ordered]@{ name = $ToolName; rules = @($DriverRules) } }
        if ($ExtensionRules.Count -gt 0) {
            $tool.extensions = @([ordered]@{ name = 'codeql/python-queries'; rules = @($ExtensionRules) })
        }
        $sarif = [ordered]@{
            version = '2.1.0'
            runs    = @([ordered]@{ tool = $tool; results = @($Results) })
        }
        $path = Join-Path $TestDrive "$Name.sarif"
        $sarif | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $path -Encoding utf8
        return $path
    }

    function script:Write-Exceptions {
        param([Parameter(Mandatory)][string]$Yaml, [string]$Name = 'exceptions')
        $path = Join-Path $TestDrive "$Name.yml"
        Set-Content -LiteralPath $path -Value $Yaml -Encoding utf8
        return $path
    }

    function script:Invoke-Gate {
        param([string[]]$Sarif, [string]$Exceptions, [string]$Threshold = 'Default')
        $summary = Join-Path $TestDrive "summary-$([guid]::NewGuid()).md"
        $params = @{ SarifPath = $Sarif; CheckDate = $script:CheckDate; SummaryPath = $summary; Threshold = $Threshold }
        if ($Exceptions) { $params.ExceptionsPath = $Exceptions }
        else { $params.ExceptionsPath = (Write-Exceptions -Yaml 'exceptions: []' -Name "empty-$([guid]::NewGuid())") }
        return Invoke-CodeQLSarifGate @params
    }

    function script:Get-MediumSecuritySarif {
        param([string]$Name = 'medium', [string]$Path = 'docs/slides/deck.html')
        return Write-Sarif -Name $Name `
            -DriverRules @(New-SarifRule -Id 'js/missing-origin-check' -SecuritySeverity '5.0') `
            -Results @(New-SarifResult -RuleId 'js/missing-origin-check' -Level 'warning' -Path $Path)
    }
}

Describe 'Threshold contract' {
    It 'fails a medium security-severity result' {
        $gate = Invoke-Gate -Sarif (Get-MediumSecuritySarif)
        $gate.ExitCode | Should -Be 1
        $gate.Failing.RuleId | Should -Be 'js/missing-origin-check'
        $gate.Summary | Should -Match '\[CodeQL\] js/missing-origin-check \(security-severity 5\) at docs/slides/deck.html:10'
    }

    It 'passes a low security-severity result even at warning level' {
        $sarif = Write-Sarif -Name 'low' `
            -DriverRules @(New-SarifRule -Id 'py/low' -SecuritySeverity '3.9') `
            -Results @(New-SarifResult -RuleId 'py/low' -Level 'warning')
        (Invoke-Gate -Sarif $sarif).ExitCode | Should -Be 0
    }

    It 'fails a quality result at warning level' {
        $sarif = Write-Sarif -Name 'quality' `
            -DriverRules @(New-SarifRule -Id 'py/unused-global-variable' -DefaultLevel 'note') `
            -Results @(New-SarifResult -RuleId 'py/unused-global-variable' -Level 'warning')
        $gate = Invoke-Gate -Sarif $sarif
        $gate.ExitCode | Should -Be 1
        $gate.Summary | Should -Match 'level warning'
    }

    It 'passes a note-level quality result' {
        $sarif = Write-Sarif -Name 'note' `
            -DriverRules @(New-SarifRule -Id 'py/note' -DefaultLevel 'note') `
            -Results @(New-SarifResult -RuleId 'py/note')
        (Invoke-Gate -Sarif $sarif).ExitCode | Should -Be 0
    }

    It 'treats a result with no level and no rule default as warning' {
        $sarif = Write-Sarif -Name 'default-level' `
            -DriverRules @(New-SarifRule -Id 'py/plain') `
            -Results @(New-SarifResult -RuleId 'py/plain')
        (Invoke-Gate -Sarif $sarif).ExitCode | Should -Be 1
    }

    It 'resolves rules from tool extensions through the toolComponent index' {
        $sarif = Write-Sarif -Name 'extensions' `
            -ExtensionRules (New-SarifRule -Id 'py/other' -DefaultLevel 'note'), (New-SarifRule -Id 'py/clear-text-logging' -SecuritySeverity '7.5') `
            -Results @(New-SarifResult -RuleId 'py/clear-text-logging' -Level 'note' -RuleReference @{ id = 'py/clear-text-logging'; index = 1; toolComponent = @{ index = 0 } })
        $gate = Invoke-Gate -Sarif $sarif
        $gate.ExitCode | Should -Be 1
        $gate.Failing.SecuritySeverity | Should -Be 7.5
    }

    It 'does not exempt results carrying inline suppressions' {
        $result = New-SarifResult -RuleId 'py/plain' -Level 'error'
        $result.suppressions = @(@{ kind = 'inSource' })
        $sarif = Write-Sarif -Name 'suppressed' -DriverRules @(New-SarifRule -Id 'py/plain') -Results @($result)
        (Invoke-Gate -Sarif $sarif).ExitCode | Should -Be 1
    }

    It 'passes when the SARIF has zero results' {
        $sarif = Write-Sarif -Name 'empty' -DriverRules @(New-SarifRule -Id 'py/plain')
        $gate = Invoke-Gate -Sarif $sarif
        $gate.ExitCode | Should -Be 0
        $gate.Summary | Should -Match 'Passed'
    }

    It 'reads every SARIF file under a directory' {
        $dir = Join-Path $TestDrive 'dir-input'
        New-Item -ItemType Directory -Path $dir | Out-Null
        Move-Item (Get-MediumSecuritySarif -Name 'dir-a') (Join-Path $dir 'a.sarif')
        Move-Item (Write-Sarif -Name 'dir-b' -DriverRules @(New-SarifRule -Id 'py/plain')) (Join-Path $dir 'b.sarif')
        $gate = Invoke-Gate -Sarif $dir
        $gate.ExitCode | Should -Be 1
        @($gate.Failing).Count | Should -Be 1
    }
}

Describe 'Threshold All' {
    It 'fails a note-level result that the default threshold passes' {
        $sarif = Write-Sarif -Name 'all-note' -ToolName 'poutine' `
            -DriverRules @(New-SarifRule -Id 'github_action_from_unverified_creator_used' -DefaultLevel 'note') `
            -Results @(New-SarifResult -RuleId 'github_action_from_unverified_creator_used' -Path '.github/workflows/label-sync.yml')
        (Invoke-Gate -Sarif $sarif).ExitCode | Should -Be 0
        $gate = Invoke-Gate -Sarif $sarif -Threshold 'All'
        $gate.ExitCode | Should -Be 1
        $gate.Failing.Tool | Should -Be 'poutine'
        $gate.Summary | Should -Match 'Threshold: every result'
    }

    It 'fails a low security-severity result' {
        $sarif = Write-Sarif -Name 'all-low' `
            -DriverRules @(New-SarifRule -Id 'py/low' -SecuritySeverity '1.0') `
            -Results @(New-SarifResult -RuleId 'py/low' -Level 'note')
        (Invoke-Gate -Sarif $sarif -Threshold 'All').ExitCode | Should -Be 1
    }

    It 'passes when every tool reports zero results' {
        $sarif = Write-Sarif -Name 'all-clean' -ToolName 'zizmor' -DriverRules @(New-SarifRule -Id 'template-injection')
        (Invoke-Gate -Sarif $sarif -Threshold 'All').ExitCode | Should -Be 0
    }
}

Describe 'Multiple tools' {
    It 'attributes results to each tool and names every tool in the summary' {
        $codeql = Get-MediumSecuritySarif -Name 'multi-codeql'
        $zizmor = Write-Sarif -Name 'multi-zizmor' -ToolName 'zizmor' `
            -DriverRules @(New-SarifRule -Id 'artipacked' -DefaultLevel 'warning') `
            -Results @(New-SarifResult -RuleId 'artipacked' -Path '.github/workflows/ci.yml')
        $gate = Invoke-Gate -Sarif $codeql, $zizmor
        $gate.ExitCode | Should -Be 1
        @($gate.Failing).Count | Should -Be 2
        ($gate.Failing.Tool | Sort-Object) -join ',' | Should -Be 'CodeQL,zizmor'
        $gate.Summary | Should -Match '## Code-scanning threshold gate \(CodeQL, zizmor\)'
    }
}

Describe 'Fail-closed inputs' {
    It 'fails when the SARIF file is missing' {
        $gate = Invoke-Gate -Sarif (Join-Path $TestDrive 'missing.sarif')
        $gate.ExitCode | Should -Be 1
        $gate.InputErrors | Should -Match 'not found'
    }

    It 'fails when no SARIF input is given' {
        $gate = Invoke-Gate -Sarif @()
        $gate.ExitCode | Should -Be 1
    }

    It 'fails when a directory holds no SARIF files' {
        $dir = Join-Path $TestDrive 'no-sarif'
        New-Item -ItemType Directory -Path $dir | Out-Null
        (Invoke-Gate -Sarif $dir).ExitCode | Should -Be 1
    }

    It 'fails when the SARIF is unreadable' {
        $path = Join-Path $TestDrive 'broken.sarif'
        Set-Content -LiteralPath $path -Value '{ not json'
        $gate = Invoke-Gate -Sarif $path
        $gate.ExitCode | Should -Be 1
        $gate.InputErrors | Should -Match 'unreadable'
    }

    It 'fails when the SARIF has no runs' {
        $path = Join-Path $TestDrive 'no-runs.sarif'
        Set-Content -LiteralPath $path -Value '{"version":"2.1.0","runs":[]}'
        $gate = Invoke-Gate -Sarif $path
        $gate.ExitCode | Should -Be 1
        $gate.InputErrors | Should -Match 'no runs'
    }

    It 'writes the summary to the summary path' {
        $summary = Join-Path $TestDrive 'job-summary.md'
        $exceptions = Write-Exceptions -Yaml 'exceptions: []' -Name 'summary-empty'
        $null = Invoke-CodeQLSarifGate -SarifPath (Get-MediumSecuritySarif -Name 'summary') -ExceptionsPath $exceptions -CheckDate $script:CheckDate -SummaryPath $summary
        Get-Content -Raw -LiteralPath $summary | Should -Match '## Code-scanning threshold gate \(CodeQL\)'
    }
}

Describe 'Tracked exceptions' {
    BeforeAll {
        function script:New-ExceptionYaml {
            param(
                [string]$Tool = 'CodeQL',
                [string]$Rule = 'js/missing-origin-check',
                [string]$Path = 'docs/slides/deck.html',
                [string]$Count = '1',
                [string]$Kind = 'false-positive',
                [string]$Upstream = 'https://github.com/github/codeql/issues/1',
                [string]$Expires = '2026-11-15',
                [string[]]$Omit = @()
            )
            $fields = [ordered]@{
                tool     = $Tool
                rule     = $Rule
                path     = $Path
                count    = $Count
                kind     = $Kind
                upstream = $Upstream
                issue    = '1234'
                owner    = 'octocat'
                reason   = 'upstream analyzer false positive'
                expires  = $Expires
            }
            $lines = @('exceptions:')
            $first = $true
            foreach ($key in $fields.Keys) {
                if ($key -in $Omit) { continue }
                $prefix = if ($first) { '  - ' } else { '    ' }
                $lines += "$prefix${key}: $($fields[$key])"
                $first = $false
            }
            return $lines -join "`n"
        }
    }

    It 'excuses a matching result and lists it' {
        $gate = Invoke-Gate -Sarif (Get-MediumSecuritySarif -Name 'excused') -Exceptions (Write-Exceptions -Yaml (New-ExceptionYaml) -Name 'match')
        $gate.ExitCode | Should -Be 0
        @($gate.Excepted).Count | Should -Be 1
        $gate.Summary | Should -Match 'excepted as false-positive \(issue #1234, upstream https://github.com/github/codeql/issues/1, expires 2026-11-15\)'
    }

    It 'does not excuse a result whose <Field> differs only in case' -ForEach @(
        @{ Field = 'tool'; Tool = 'codeql'; Rule = 'js/missing-origin-check'; Path = 'docs/slides/deck.html' }
        @{ Field = 'rule'; Tool = 'CodeQL'; Rule = 'JS/missing-origin-check'; Path = 'docs/slides/deck.html' }
        @{ Field = 'path'; Tool = 'CodeQL'; Rule = 'js/missing-origin-check'; Path = 'docs/slides/Deck.html' }
    ) {
        $yaml = New-ExceptionYaml -Tool $Tool -Rule $Rule -Path $Path
        $gate = Invoke-Gate -Sarif (Get-MediumSecuritySarif -Name "case-$Field") -Exceptions (Write-Exceptions -Yaml $yaml -Name "case-$Field")
        $gate.ExitCode | Should -Be 1
        @($gate.Failing).Count | Should -Be 1
        @($gate.Excepted).Count | Should -Be 0
    }

    It 'keeps two entries that differ only in case distinct' {
        $exact = New-ExceptionYaml
        $variant = (New-ExceptionYaml -Path 'docs/slides/Deck.html') -replace '^exceptions:\r?\n', ''
        $gate = Invoke-Gate -Sarif (Get-MediumSecuritySarif -Name 'case-pair') -Exceptions (Write-Exceptions -Yaml "$exact`n$variant" -Name 'case-pair')
        @($gate.Excepted).Count | Should -Be 1
        @($gate.ExceptionErrors | Where-Object { $_ -match 'Stale exception: .*docs/slides/Deck\.html' }).Count | Should -Be 1
    }

    It 'fails when more results match than the pinned count' {
        $sarif = Write-Sarif -Name 'count-more' `
            -DriverRules @(New-SarifRule -Id 'js/missing-origin-check' -SecuritySeverity '5.0') `
            -Results (New-SarifResult -RuleId 'js/missing-origin-check' -Path 'docs/slides/deck.html' -Line 10), (New-SarifResult -RuleId 'js/missing-origin-check' -Path 'docs/slides/deck.html' -Line 20)
        $gate = Invoke-Gate -Sarif $sarif -Exceptions (Write-Exceptions -Yaml (New-ExceptionYaml) -Name 'count-more')
        $gate.ExitCode | Should -Be 1
        @($gate.Failing).Count | Should -Be 2
        @($gate.Excepted).Count | Should -Be 0
        $gate.ExceptionErrors | Should -Match 'expects 1 result\(s\) but found 2'
    }

    It 'fails when fewer results match than the pinned count' {
        $gate = Invoke-Gate -Sarif (Get-MediumSecuritySarif -Name 'count-fewer') -Exceptions (Write-Exceptions -Yaml (New-ExceptionYaml -Count '3') -Name 'count-fewer')
        $gate.ExitCode | Should -Be 1
        $gate.ExceptionErrors | Should -Match 'expects 3 result\(s\) but found 1'
    }

    It 'excuses several results when the count matches exactly' {
        $sarif = Write-Sarif -Name 'count-two' `
            -DriverRules @(New-SarifRule -Id 'js/missing-origin-check' -SecuritySeverity '5.0') `
            -Results (New-SarifResult -RuleId 'js/missing-origin-check' -Path 'docs/slides/deck.html' -Line 10), (New-SarifResult -RuleId 'js/missing-origin-check' -Path 'docs/slides/deck.html' -Line 20)
        $gate = Invoke-Gate -Sarif $sarif -Exceptions (Write-Exceptions -Yaml (New-ExceptionYaml -Count '2') -Name 'count-two')
        $gate.ExitCode | Should -Be 0
        @($gate.Excepted).Count | Should -Be 2
    }

    It 'does not excuse the same rule and path from a different tool' {
        $sarif = Write-Sarif -Name 'tool-scope' -ToolName 'zizmor' `
            -DriverRules @(New-SarifRule -Id 'js/missing-origin-check' -SecuritySeverity '5.0') `
            -Results @(New-SarifResult -RuleId 'js/missing-origin-check' -Level 'warning' -Path 'docs/slides/deck.html')
        $gate = Invoke-Gate -Sarif $sarif -Exceptions (Write-Exceptions -Yaml (New-ExceptionYaml) -Name 'tool-scope')
        $gate.ExitCode | Should -Be 1
        $gate.Failing.Tool | Should -Be 'zizmor'
        $gate.ExceptionErrors | Should -BeNullOrEmpty
    }

    It 'excuses a matching result in a multi-tool run and fails the other tool' {
        $zizmor = Write-Sarif -Name 'multi-excuse-zizmor' -ToolName 'zizmor' `
            -DriverRules @(New-SarifRule -Id 'artipacked' -DefaultLevel 'warning') `
            -Results @(New-SarifResult -RuleId 'artipacked' -Path '.github/workflows/ci.yml')
        $gate = Invoke-Gate -Sarif (Get-MediumSecuritySarif -Name 'multi-excuse-codeql'), $zizmor -Exceptions (Write-Exceptions -Yaml (New-ExceptionYaml) -Name 'multi-excuse')
        $gate.ExitCode | Should -Be 1
        @($gate.Excepted).Count | Should -Be 1
        $gate.Failing.Tool | Should -Be 'zizmor'
    }

    It 'fails an exception with an unknown kind' {
        $gate = Invoke-Gate -Sarif (Get-MediumSecuritySarif -Name 'bad-kind') -Exceptions (Write-Exceptions -Yaml (New-ExceptionYaml -Kind 'wont-fix') -Name 'bad-kind')
        $gate.ExitCode | Should -Be 1
        $gate.ExceptionErrors | Should -Match "'kind' must be one of"
    }

    It 'fails an exception whose upstream is not an https URL' {
        $gate = Invoke-Gate -Sarif (Get-MediumSecuritySarif -Name 'bad-upstream') -Exceptions (Write-Exceptions -Yaml (New-ExceptionYaml -Upstream 'reported') -Name 'bad-upstream')
        $gate.ExitCode | Should -Be 1
        $gate.ExceptionErrors | Should -Match "'upstream' must be an https URL"
    }

    It 'fails an exception with a non-positive count' {
        $gate = Invoke-Gate -Sarif (Get-MediumSecuritySarif -Name 'zero-count') -Exceptions (Write-Exceptions -Yaml (New-ExceptionYaml -Count '0') -Name 'zero-count')
        $gate.ExitCode | Should -Be 1
        $gate.ExceptionErrors | Should -Match "'count' must be a positive number"
    }

    It 'fails an exception missing each v2 field' -ForEach @(
        @{ Field = 'tool' }, @{ Field = 'count' }, @{ Field = 'kind' }, @{ Field = 'upstream' }
    ) {
        $gate = Invoke-Gate -Sarif (Get-MediumSecuritySarif -Name "missing-$Field") -Exceptions (Write-Exceptions -Yaml (New-ExceptionYaml -Omit $Field) -Name "missing-$Field")
        $gate.ExitCode | Should -Be 1
        $gate.ExceptionErrors | Should -Match "missing required field '$Field'"
    }

    It 'does not excuse a result in a different path' {
        $sarif = Get-MediumSecuritySarif -Name 'other-path' -Path 'docs/slides/other.html'
        $gate = Invoke-Gate -Sarif $sarif -Exceptions (Write-Exceptions -Yaml (New-ExceptionYaml) -Name 'nonmatch')
        $gate.ExitCode | Should -Be 1
        $gate.Failing.Path | Should -Be 'docs/slides/other.html'
        $gate.ExceptionErrors | Should -Match 'Stale exception'
    }

    It 'fails an expired exception' {
        $gate = Invoke-Gate -Sarif (Get-MediumSecuritySarif -Name 'expired') -Exceptions (Write-Exceptions -Yaml (New-ExceptionYaml -Expires '2026-10-01') -Name 'expired')
        $gate.ExitCode | Should -Be 1
        $gate.ExceptionErrors | Should -Match 'expired on 2026-10-01'
    }

    It 'fails an exception that expires more than 90 days out' {
        $gate = Invoke-Gate -Sarif (Get-MediumSecuritySarif -Name 'far') -Exceptions (Write-Exceptions -Yaml (New-ExceptionYaml -Expires '2027-01-01') -Name 'far')
        $gate.ExitCode | Should -Be 1
        $gate.ExceptionErrors | Should -Match 'more than 90 days'
    }

    It 'accepts an exception that expires exactly 90 days out' {
        $gate = Invoke-Gate -Sarif (Get-MediumSecuritySarif -Name 'edge') -Exceptions (Write-Exceptions -Yaml (New-ExceptionYaml -Expires '2026-12-31') -Name 'edge')
        $gate.ExitCode | Should -Be 0
    }

    It 'fails an exception that is missing a required field' {
        $gate = Invoke-Gate -Sarif (Get-MediumSecuritySarif -Name 'missing-field') -Exceptions (Write-Exceptions -Yaml (New-ExceptionYaml -Omit 'owner') -Name 'missing-field')
        $gate.ExitCode | Should -Be 1
        $gate.ExceptionErrors | Should -Match "missing required field 'owner'"
    }

    It 'fails an exception with an unknown field' {
        $yaml = (New-ExceptionYaml) + "`n    expiry: 2026-11-15"
        $gate = Invoke-Gate -Sarif (Get-MediumSecuritySarif -Name 'unknown-field') -Exceptions (Write-Exceptions -Yaml $yaml -Name 'unknown-field')
        $gate.ExitCode | Should -Be 1
        $gate.ExceptionErrors | Should -Match "unknown field 'expiry'"
    }

    It 'fails a stale exception whose rule ran but no longer reports a result' {
        $sarif = Write-Sarif -Name 'stale' -DriverRules @(New-SarifRule -Id 'js/missing-origin-check' -SecuritySeverity '5.0')
        $gate = Invoke-Gate -Sarif $sarif -Exceptions (Write-Exceptions -Yaml (New-ExceptionYaml) -Name 'stale')
        $gate.ExitCode | Should -Be 1
        $gate.ExceptionErrors | Should -Match 'Stale exception: CodeQL js/missing-origin-check'
    }

    It 'ignores an exception for a rule this analysis did not run' {
        $sarif = Write-Sarif -Name 'other-category' -DriverRules @(New-SarifRule -Id 'actions/untrusted-checkout' -SecuritySeverity '5.0')
        $gate = Invoke-Gate -Sarif $sarif -Exceptions (Write-Exceptions -Yaml (New-ExceptionYaml) -Name 'other-category')
        $gate.ExitCode | Should -Be 0
        $gate.ExceptionErrors | Should -BeNullOrEmpty
    }

    It 'treats the shipped empty file the same as no exceptions' {
        $empty = Write-Exceptions -Yaml "# comment`nexceptions: []" -Name 'shipped-empty'
        $withFile = Invoke-Gate -Sarif (Get-MediumSecuritySarif -Name 'empty-file') -Exceptions $empty
        $withFile.ExitCode | Should -Be 1
        @($withFile.Failing).Count | Should -Be 1
        @($withFile.Excepted).Count | Should -Be 0
        $withFile.ExceptionErrors | Should -BeNullOrEmpty
    }

    # Shipped entries are checked against today, the date the gate uses in CI.
    It 'validates the repository exceptions file as shipped' {
        $repoFile = Join-Path $PSScriptRoot '../../../security/code-scanning-exceptions.yml'
        $read = Read-CodeScanningException -Path $repoFile -CheckDate ([datetime]::UtcNow.Date)
        $read.Errors | Should -BeNullOrEmpty
        foreach ($entry in $read.Entries) {
            $entry.Upstream | Should -Match '^https://github\.com/[^/]+/[^/]+/issues/\d+$'
            $entry.Issue | Should -BeGreaterThan 0
        }
    }

    It 'fails when an explicit exceptions path does not exist' {
        $summary = Join-Path $TestDrive 'missing-exceptions.md'
        $gate = Invoke-CodeQLSarifGate -SarifPath (Write-Sarif -Name 'clean' -DriverRules @(New-SarifRule -Id 'py/plain')) -ExceptionsPath (Join-Path $TestDrive 'nope.yml') -CheckDate $script:CheckDate -SummaryPath $summary
        $gate.ExitCode | Should -Be 1
        $gate.ExceptionErrors | Should -Match 'not found'
    }

    It 'fails a file without an exceptions list' {
        $gate = Invoke-Gate -Sarif (Get-MediumSecuritySarif -Name 'bad-shape') -Exceptions (Write-Exceptions -Yaml 'rules: []' -Name 'bad-shape')
        $gate.ExitCode | Should -Be 1
        $gate.ExceptionErrors | Should -Match "'exceptions' list"
    }
}
