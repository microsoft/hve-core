#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#
# Test-CodeQLSarifThreshold.ps1
#
# Purpose: Fail a code-scanning job when its SARIF contains a finding at the
#          repository's threshold, honoring only tracked exceptions. Works for
#          any SARIF-producing tool, not only CodeQL.
# Author: HVE Core Team

#Requires -Version 7.4

<#
.SYNOPSIS
    Fails when SARIF output from any code-scanning tool contains a result at the threshold.

.DESCRIPTION
    Reads one or more SARIF files (or every *.sarif file under a directory) and
    evaluates every result against the threshold contract. With -Threshold Default:

      A result fails when its rule has security-severity >= 4.0, or when its rule
      has no security-severity and its effective level is "error" or "warning".
      Effective level is result.level, else the rule's defaultConfiguration.level,
      else "warning" (the SARIF default). Rules resolve through ruleId, ruleIndex,
      and toolComponent across tool.driver and tool.extensions.

    With -Threshold All, every result fails regardless of level or severity. Use
    it for scanners gated at zero findings. Inline SARIF suppressions never
    exempt a result.

    A missing, unreadable, or run-less SARIF input fails the gate.

    Each result is attributed to its run's tool.driver.name. Failing results are
    grouped by tool, rule ID, and path. A group is excused only by a tracked
    exception with the same tool, rule, and path whose count equals the group's
    result count exactly. Excused results are still listed. The gate fails when
    an exception entry is malformed, expired, expires more than 90 days after the
    check date, matches a different number of results, or no longer matches any
    failing result for a tool and rule that this analysis ran. The gate never
    changes alert state on GitHub.

.PARAMETER SarifPath
    SARIF files or directories containing *.sarif files.

.PARAMETER Threshold
    Default applies the severity and level contract above. All fails every result.

.PARAMETER ExceptionsPath
    Tracked exceptions file. Defaults to security/code-scanning-exceptions.yml
    at the repository root. An explicitly supplied path must exist.

.PARAMETER CheckDate
    Date used for expiry checks. Defaults to the current UTC date.

.PARAMETER SummaryPath
    Markdown summary destination. Defaults to $env:GITHUB_STEP_SUMMARY when set.

.EXAMPLE
    ./scripts/security/Test-CodeQLSarifThreshold.ps1 -SarifPath ../results

.EXAMPLE
    npm run security:codeql-gate -- -SarifPath ./python.sarif

.EXAMPLE
    ./scripts/security/Test-CodeQLSarifThreshold.ps1 -SarifPath ./poutine.sarif -Threshold All
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string[]]$SarifPath,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Default', 'All')]
    [string]$Threshold = 'Default',

    [Parameter(Mandatory = $false)]
    [string]$ExceptionsPath,

    [Parameter(Mandatory = $false)]
    [datetime]$CheckDate = [datetime]::UtcNow.Date,

    [Parameter(Mandatory = $false)]
    [string]$SummaryPath
)

$ErrorActionPreference = 'Stop'

$script:ExceptionFields = @('tool', 'rule', 'path', 'count', 'kind', 'upstream', 'issue', 'owner', 'reason', 'expires')
$script:ExceptionKinds = @('false-positive', 'generated-code', 'third-party', 'platform-limitation')
$script:MaxExceptionDays = 90
$script:SecuritySeverityThreshold = 4.0

#region SARIF evaluation
function Get-PropertyValue {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [object]$InputObject,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($null -eq $InputObject) { return $null }
    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Resolve-SarifInputFile {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$Path
    )

    if ($Path.Count -eq 0) {
        throw 'No SARIF input was provided.'
    }
    $files = [System.Collections.Generic.List[string]]::new()
    foreach ($item in $Path) {
        if (Test-Path -LiteralPath $item -PathType Container) {
            $found = @(Get-ChildItem -LiteralPath $item -Filter '*.sarif' -File -Recurse | Sort-Object FullName)
            if ($found.Count -eq 0) {
                throw "No SARIF files found under: $item"
            }
            $files.AddRange([string[]]@($found.FullName))
        }
        elseif (Test-Path -LiteralPath $item -PathType Leaf) {
            $files.Add((Resolve-Path -LiteralPath $item).Path)
        }
        else {
            throw "SARIF input not found: $item"
        }
    }
    return , $files.ToArray()
}

function Resolve-SarifRule {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Result,

        [Parameter(Mandatory = $true)]
        [object]$Run
    )

    $tool = Get-PropertyValue $Run 'tool'
    $driverRules = @(Get-PropertyValue (Get-PropertyValue $tool 'driver') 'rules')
    $extensions = @(Get-PropertyValue $tool 'extensions')
    $ruleRef = Get-PropertyValue $Result 'rule'
    $ruleIndex = Get-PropertyValue $ruleRef 'index'
    if ($null -eq $ruleIndex) { $ruleIndex = Get-PropertyValue $Result 'ruleIndex' }
    $componentIndex = Get-PropertyValue (Get-PropertyValue $ruleRef 'toolComponent') 'index'

    if ($null -ne $ruleIndex -and $ruleIndex -ge 0) {
        $rules = $driverRules
        if ($null -ne $componentIndex -and $componentIndex -ge 0 -and $componentIndex -lt $extensions.Count) {
            $rules = @(Get-PropertyValue $extensions[$componentIndex] 'rules')
        }
        if ($ruleIndex -lt $rules.Count -and $null -ne $rules[$ruleIndex]) {
            return $rules[$ruleIndex]
        }
    }

    $ruleId = Get-PropertyValue $Result 'ruleId'
    if (-not $ruleId) { $ruleId = Get-PropertyValue $ruleRef 'id' }
    if ($ruleId) {
        $candidates = @($driverRules) + @($extensions | ForEach-Object { @(Get-PropertyValue $_ 'rules') })
        foreach ($rule in $candidates) {
            if ($null -ne $rule -and (Get-PropertyValue $rule 'id') -eq $ruleId) {
                return $rule
            }
        }
    }
    return $null
}

function Get-SarifEvaluation {
    <#
    .SYNOPSIS
        Evaluates SARIF files against the threshold contract.
    .OUTPUTS
        PSCustomObject with Findings (every result with its Tool and Failing flag)
        and KnownRules (tool and rule ID keys this analysis ran).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Path,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Default', 'All')]
        [string]$Threshold = 'Default'
    )

    $findings = [System.Collections.Generic.List[object]]::new()
    $knownRules = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)

    foreach ($file in (Resolve-SarifInputFile -Path $Path)) {
        try {
            $sarif = Get-Content -Raw -LiteralPath $file | ConvertFrom-Json -Depth 100
        }
        catch {
            throw "SARIF file is unreadable: $file ($($_.Exception.Message))"
        }
        $runs = @(Get-PropertyValue $sarif 'runs')
        if ($runs.Count -eq 0 -or $null -eq $runs[0]) {
            throw "SARIF file has no runs: $file"
        }

        foreach ($run in $runs) {
            $tool = Get-PropertyValue $run 'tool'
            $toolName = [string](Get-PropertyValue (Get-PropertyValue $tool 'driver') 'name')
            if (-not $toolName) { $toolName = '(unknown tool)' }
            $ruleSets = @(@(Get-PropertyValue (Get-PropertyValue $tool 'driver') 'rules')) +
                @(@(Get-PropertyValue $tool 'extensions') | ForEach-Object { @(Get-PropertyValue $_ 'rules') })
            foreach ($rule in $ruleSets) {
                $id = Get-PropertyValue $rule 'id'
                if ($id) { [void]$knownRules.Add("$toolName`n$id") }
            }

            foreach ($result in @(Get-PropertyValue $run 'results')) {
                if ($null -eq $result) { continue }
                $rule = Resolve-SarifRule -Result $result -Run $run
                $ruleId = Get-PropertyValue $result 'ruleId'
                if (-not $ruleId) { $ruleId = Get-PropertyValue (Get-PropertyValue $result 'rule') 'id' }
                if (-not $ruleId) { $ruleId = Get-PropertyValue $rule 'id' }
                if (-not $ruleId) { $ruleId = '(unknown rule)' }

                $severityText = Get-PropertyValue (Get-PropertyValue $rule 'properties') 'security-severity'
                $securitySeverity = $null
                if ($null -ne $severityText -and "$severityText" -ne '') {
                    $parsed = 0.0
                    if ([double]::TryParse("$severityText", [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsed)) {
                        $securitySeverity = $parsed
                    }
                }

                $level = Get-PropertyValue $result 'level'
                if (-not $level) { $level = Get-PropertyValue (Get-PropertyValue $rule 'defaultConfiguration') 'level' }
                if (-not $level) { $level = 'warning' }

                $failing = if ($Threshold -eq 'All') {
                    $true
                }
                elseif ($null -ne $securitySeverity) {
                    $securitySeverity -ge $script:SecuritySeverityThreshold
                }
                else {
                    $level -in @('error', 'warning')
                }

                $location = @(Get-PropertyValue $result 'locations') | Select-Object -First 1
                $physical = Get-PropertyValue $location 'physicalLocation'
                $uri = Get-PropertyValue (Get-PropertyValue $physical 'artifactLocation') 'uri'
                $line = Get-PropertyValue (Get-PropertyValue $physical 'region') 'startLine'

                $findings.Add([pscustomobject]@{
                        Tool             = $toolName
                        RuleId           = $ruleId
                        SecuritySeverity = $securitySeverity
                        Level            = $level
                        Path             = if ($uri) { [string]$uri } else { '(no location)' }
                        Line             = $line
                        Failing          = [bool]$failing
                        File             = $file
                    })
            }
        }
    }

    return [pscustomobject]@{
        Findings   = $findings.ToArray()
        KnownRules = $knownRules
    }
}
#endregion

#region Tracked exceptions
function Read-CodeScanningException {
    <#
    .SYNOPSIS
        Reads and validates the tracked exceptions file.
    .OUTPUTS
        PSCustomObject with Entries (valid entries) and Errors (validation messages).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [datetime]$CheckDate
    )

    $entries = [System.Collections.Generic.List[object]]::new()
    $errors = [System.Collections.Generic.List[string]]::new()

    if (-not (Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue)) {
        Import-Module powershell-yaml -ErrorAction Stop
    }
    try {
        $document = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Yaml
    }
    catch {
        $errors.Add("Exceptions file is not valid YAML: $($_.Exception.Message)")
        return [pscustomobject]@{ Entries = $entries.ToArray(); Errors = $errors.ToArray() }
    }

    if ($null -eq $document -or $document -isnot [System.Collections.IDictionary] -or -not $document.Contains('exceptions')) {
        $errors.Add("Exceptions file must be a mapping with an 'exceptions' list.")
        return [pscustomobject]@{ Entries = $entries.ToArray(); Errors = $errors.ToArray() }
    }

    $list = $document['exceptions']
    if ($null -eq $list) { $list = @() }
    if ($list -is [System.Collections.IDictionary] -or $list -is [string] -or $list -isnot [System.Collections.IEnumerable]) {
        $errors.Add("'exceptions' must be a list.")
        return [pscustomobject]@{ Entries = $entries.ToArray(); Errors = $errors.ToArray() }
    }

    $latest = $CheckDate.Date.AddDays($script:MaxExceptionDays)
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $index = 0
    foreach ($item in $list) {
        $index++
        $label = "Exception #$index"
        if ($item -isnot [System.Collections.IDictionary]) {
            $errors.Add("${label}: must be a mapping.")
            continue
        }
        $entryErrors = [System.Collections.Generic.List[string]]::new()
        foreach ($key in $item.Keys) {
            if ("$key" -notin $script:ExceptionFields) { $entryErrors.Add("unknown field '$key'") }
        }
        foreach ($field in $script:ExceptionFields) {
            if (-not $item.Contains($field) -or $null -eq $item[$field] -or "$($item[$field])".Trim() -eq '') {
                $entryErrors.Add("missing required field '$field'")
            }
        }

        $issue = 0
        if ($item.Contains('issue') -and $null -ne $item['issue'] -and -not ([int]::TryParse("$($item['issue'])", [ref]$issue) -and $issue -gt 0)) {
            $entryErrors.Add("'issue' must be a positive issue number")
        }

        $count = 0
        if ($item.Contains('count') -and $null -ne $item['count'] -and -not ([int]::TryParse("$($item['count'])", [ref]$count) -and $count -gt 0)) {
            $entryErrors.Add("'count' must be a positive number of matching results")
        }

        if ($item.Contains('kind') -and $null -ne $item['kind'] -and "$($item['kind'])".Trim() -ne '' -and "$($item['kind'])" -cnotin $script:ExceptionKinds) {
            $entryErrors.Add("'kind' must be one of: $($script:ExceptionKinds -join ', ')")
        }

        if ($item.Contains('upstream') -and $null -ne $item['upstream'] -and "$($item['upstream'])".Trim() -ne '' -and "$($item['upstream'])" -notmatch '^https://[^\s/]+/\S+$') {
            $entryErrors.Add("'upstream' must be an https URL to the upstream report")
        }

        $expires = $null
        if ($item.Contains('expires') -and $null -ne $item['expires']) {
            $raw = $item['expires']
            if ($raw -is [datetime]) {
                $expires = $raw.Date
            }
            else {
                $parsedDate = [datetime]::MinValue
                if ([datetime]::TryParseExact("$raw", 'yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsedDate)) {
                    $expires = $parsedDate.Date
                }
                else {
                    $entryErrors.Add("'expires' must be an ISO date (YYYY-MM-DD)")
                }
            }
            if ($null -ne $expires) {
                if ($expires -lt $CheckDate.Date) {
                    $entryErrors.Add("expired on $($expires.ToString('yyyy-MM-dd'))")
                }
                elseif ($expires -gt $latest) {
                    $entryErrors.Add("expires $($expires.ToString('yyyy-MM-dd')), more than $($script:MaxExceptionDays) days after $($CheckDate.ToString('yyyy-MM-dd'))")
                }
            }
        }

        if ($entryErrors.Count -gt 0) {
            $errors.Add("${label} ($($item['tool']) $($item['rule']) in $($item['path'])): $($entryErrors -join '; ').")
            continue
        }

        $key = "$($item['tool'])`n$($item['rule'])`n$($item['path'])"
        if (-not $seen.Add($key)) {
            $errors.Add("${label} ($($item['tool']) $($item['rule']) in $($item['path'])): duplicates an earlier entry.")
            continue
        }

        $entries.Add([pscustomobject]@{
                Tool     = [string]$item['tool']
                Rule     = [string]$item['rule']
                Path     = [string]$item['path']
                Count    = $count
                Kind     = [string]$item['kind']
                Upstream = [string]$item['upstream']
                Issue    = $issue
                Owner    = [string]$item['owner']
                Reason   = [string]$item['reason']
                Expires  = $expires
            })
    }

    return [pscustomobject]@{ Entries = $entries.ToArray(); Errors = $errors.ToArray() }
}
#endregion

#region Main Function
function Invoke-CodeQLSarifGate {
    <#
    .SYNOPSIS
        Evaluates SARIF against the threshold and tracked exceptions.
    .OUTPUTS
        PSCustomObject with ExitCode, Failing, Excepted, ExceptionErrors, and Summary.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $false)]
        [string[]]$SarifPath = @(),

        [Parameter(Mandatory = $false)]
        [ValidateSet('Default', 'All')]
        [string]$Threshold = 'Default',

        [Parameter(Mandatory = $false)]
        [string]$ExceptionsPath,

        [Parameter(Mandatory = $false)]
        [datetime]$CheckDate = [datetime]::UtcNow.Date,

        [Parameter(Mandatory = $false)]
        [string]$SummaryPath
    )

    $inputErrors = [System.Collections.Generic.List[string]]::new()
    $evaluation = $null
    try {
        $evaluation = Get-SarifEvaluation -Path $SarifPath -Threshold $Threshold
    }
    catch {
        $inputErrors.Add($_.Exception.Message)
    }

    $exceptionEntries = @()
    $exceptionErrors = [System.Collections.Generic.List[string]]::new()
    $resolvedExceptions = $ExceptionsPath
    if (-not $resolvedExceptions) {
        $repoRoot = git rev-parse --show-toplevel 2>$null
        if (-not $repoRoot) { $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent }
        $resolvedExceptions = Join-Path $repoRoot 'security/code-scanning-exceptions.yml'
        if (-not (Test-Path -LiteralPath $resolvedExceptions -PathType Leaf)) { $resolvedExceptions = $null }
    }
    elseif (-not (Test-Path -LiteralPath $resolvedExceptions -PathType Leaf)) {
        $exceptionErrors.Add("Exceptions file not found: $resolvedExceptions")
        $resolvedExceptions = $null
    }
    if ($resolvedExceptions) {
        $read = Read-CodeScanningException -Path $resolvedExceptions -CheckDate $CheckDate
        $exceptionEntries = @($read.Entries)
        $exceptionErrors.AddRange([string[]]@($read.Errors))
    }

    $failing = [System.Collections.Generic.List[object]]::new()
    $excepted = [System.Collections.Generic.List[object]]::new()
    $resultCount = 0
    $tools = @()
    if ($null -ne $evaluation) {
        $resultCount = @($evaluation.Findings).Count
        $tools = @($evaluation.Findings | ForEach-Object Tool | Sort-Object -Unique)
        # Ordinal keys keep matching consistent with the ordinal duplicate check in Read-CodeScanningException.
        $groups = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
        foreach ($finding in @($evaluation.Findings | Where-Object Failing)) {
            $key = "$($finding.Tool)`n$($finding.RuleId)`n$($finding.Path)"
            if (-not $groups.Contains($key)) { $groups[$key] = [System.Collections.Generic.List[object]]::new() }
            $groups[$key].Add($finding)
        }
        $entryByKey = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::Ordinal)
        foreach ($entry in $exceptionEntries) { $entryByKey["$($entry.Tool)`n$($entry.Rule)`n$($entry.Path)"] = $entry }

        foreach ($key in $groups.Keys) {
            $group = $groups[$key]
            $match = $null
            [void]$entryByKey.TryGetValue($key, [ref]$match)
            if (-not $match) {
                $failing.AddRange([object[]]$group.ToArray())
            }
            elseif ($match.Count -ne $group.Count) {
                $failing.AddRange([object[]]$group.ToArray())
                $exceptionErrors.Add("Count mismatch: $($match.Tool) $($match.Rule) in $($match.Path) (issue #$($match.Issue)) expects $($match.Count) result(s) but found $($group.Count). Fix the new results or update the count in review.")
            }
            else {
                foreach ($finding in $group) { $excepted.Add([pscustomobject]@{ Finding = $finding; Exception = $match }) }
            }
        }
        foreach ($key in $entryByKey.Keys) {
            $entry = $entryByKey[$key]
            if ($evaluation.KnownRules.Contains("$($entry.Tool)`n$($entry.Rule)") -and -not $groups.Contains($key)) {
                $exceptionErrors.Add("Stale exception: $($entry.Tool) $($entry.Rule) in $($entry.Path) (issue #$($entry.Issue)) matches no failing result. Remove it.")
            }
        }
    }

    $describe = {
        param($f)
        $severity = if ($null -ne $f.SecuritySeverity) { "security-severity $($f.SecuritySeverity.ToString([System.Globalization.CultureInfo]::InvariantCulture))" } else { "level $($f.Level)" }
        $where = if ($null -ne $f.Line) { "$($f.Path):$($f.Line)" } else { $f.Path }
        "[$($f.Tool)] $($f.RuleId) ($severity) at $where"
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    $passed = $inputErrors.Count -eq 0 -and $failing.Count -eq 0 -and $exceptionErrors.Count -eq 0
    $toolLabel = if ($tools.Count -gt 0) { " ($($tools -join ', '))" } else { '' }
    $lines.Add("## Code-scanning threshold gate$toolLabel")
    $lines.Add('')
    $lines.Add($(if ($passed) { "$([char]::ConvertFromUtf32(0x2705)) Passed: no results at the threshold." } else { "$([char]::ConvertFromUtf32(0x274C)) Failed: resolve every item below in code or configuration. Dismissing the alert does not clear this gate." }))
    $lines.Add('')
    $thresholdText = if ($Threshold -eq 'All') { 'every result' } else { 'security-severity >= 4.0, or level error/warning for rules without a security severity' }
    $lines.Add("Threshold: $thresholdText. Results evaluated: $resultCount.")
    foreach ($message in $inputErrors) { $lines.Add("* Input error: $message") }
    if ($failing.Count -gt 0) {
        $lines.Add('')
        $lines.Add('### Results at the threshold')
        $lines.Add('')
        foreach ($f in $failing) { $lines.Add("* $(& $describe $f)") }
    }
    if ($excepted.Count -gt 0) {
        $lines.Add('')
        $lines.Add('### Excepted results (still open on GitHub)')
        $lines.Add('')
        foreach ($e in $excepted) {
            $lines.Add("* $(& $describe $e.Finding): excepted as $($e.Exception.Kind) (issue #$($e.Exception.Issue), upstream $($e.Exception.Upstream), expires $($e.Exception.Expires.ToString('yyyy-MM-dd')))")
        }
    }
    if ($exceptionErrors.Count -gt 0) {
        $lines.Add('')
        $lines.Add('### Exception file problems')
        $lines.Add('')
        foreach ($message in $exceptionErrors) { $lines.Add("* $message") }
    }
    $summary = ($lines -join "`n") + "`n"

    $destination = if ($SummaryPath) { $SummaryPath } else { $env:GITHUB_STEP_SUMMARY }
    if ($destination) {
        Add-Content -LiteralPath $destination -Value $summary -Encoding utf8
    }

    return [pscustomobject]@{
        ExitCode        = $(if ($passed) { 0 } else { 1 })
        Failing         = $failing.ToArray()
        Excepted        = $excepted.ToArray()
        ExceptionErrors = $exceptionErrors.ToArray()
        InputErrors     = $inputErrors.ToArray()
        Summary         = $summary
    }
}
#endregion

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        $gate = Invoke-CodeQLSarifGate @PSBoundParameters
        Write-Output $gate.Summary
        if ($env:GITHUB_OUTPUT) {
            # Callers that report without failing (soft-fail) read these instead of raw scanner counts.
            @(
                "failing-count=$(@($gate.Failing).Count)"
                "excepted-count=$(@($gate.Excepted).Count)"
                "exception-error-count=$(@($gate.ExceptionErrors).Count + @($gate.InputErrors).Count)"
            ) | Add-Content -LiteralPath $env:GITHUB_OUTPUT -Encoding utf8
        }
        exit $gate.ExitCode
    }
    catch {
        Write-Error -ErrorAction Continue "Test-CodeQLSarifThreshold failed: $($_.Exception.Message)"
        exit 1
    }
}
#endregion
