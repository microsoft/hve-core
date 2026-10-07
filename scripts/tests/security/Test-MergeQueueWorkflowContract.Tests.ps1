#Requires -Modules Pester, powershell-yaml
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeDiscovery {
    $script:TrustedCheckoutSites = @(
        @{ Workflow = 'adr-consistency-validation.yml'; Job = 'detect-changes' }
        @{ Workflow = 'adr-consistency-validation.yml'; Job = 'validate' }
        @{ Workflow = 'asset-docs-validation.yml'; Job = 'validate' }
        @{ Workflow = 'docusaurus-tests.yml'; Job = 'detect-changes' }
        @{ Workflow = 'docusaurus-tests.yml'; Job = 'docusaurus' }
        @{ Workflow = 'eval-validation.yml'; Job = 'content-moderation' }
        @{ Workflow = 'eval-validation.yml'; Job = 'eval-validation' }
        @{ Workflow = 'frontmatter-validation.yml'; Job = 'frontmatter-validation' }
        @{ Workflow = 'fuzz-tests.yml'; Job = 'fuzz' }
        @{ Workflow = 'gitleaks-scan.yml'; Job = 'scan' }
        @{ Workflow = 'markdown-link-check.yml'; Job = 'markdown-link-check' }
        @{ Workflow = 'msdate-freshness-check.yml'; Job = 'msdate-freshness' }
        @{ Workflow = 'node-tests.yml'; Job = 'node-tests' }
        @{ Workflow = 'pip-audit.yml'; Job = 'pip-audit' }
        @{ Workflow = 'ps-script-analyzer.yml'; Job = 'psscriptanalyzer' }
        @{ Workflow = 'pytest-tests.yml'; Job = 'pytest' }
        @{ Workflow = 'python-lint.yml'; Job = 'python-lint' }
        @{ Workflow = 'skill-validation.yml'; Job = 'validate' }
        @{ Workflow = 'yaml-lint.yml'; Job = 'yaml-lint' }
    )

    # Trusted events may receive the custom eval token; every other event must not.
    $script:CredentialEventScenarios = @(
        @{ Name = 'a same-repository pull request'; Trusted = $true; EventName = 'pull_request'; HeadRepository = @{ full_name = 'microsoft/hve-core'; fork = $false } }
        @{ Name = 'a manual dispatch'; Trusted = $true; EventName = 'workflow_dispatch' }
        @{ Name = 'a merge group'; Trusted = $false; EventName = 'merge_group' }
        @{ Name = 'a fork pull request'; Trusted = $false; EventName = 'pull_request'; HeadRepository = @{ full_name = 'contributor/hve-core'; fork = $true } }
        @{ Name = 'a pull request whose head repository was deleted'; Trusted = $false; EventName = 'pull_request'; HeadRepository = $null }
        @{ Name = 'a same-repository pull_request_target'; Trusted = $false; EventName = 'pull_request_target'; HeadRepository = @{ full_name = 'microsoft/hve-core'; fork = $false } }
        @{ Name = 'a push'; Trusted = $false; EventName = 'push' }
        @{ Name = 'a schedule'; Trusted = $false; EventName = 'schedule' }
        @{ Name = 'an unlisted repository_dispatch'; Trusted = $false; EventName = 'repository_dispatch' }
    )
}

BeforeAll {
    Import-Module powershell-yaml -ErrorAction Stop

    function Get-WorkflowRangeContractViolation {
        <#
    .SYNOPSIS
        Finds selector jobs that bypass immutable resolver outputs.
    .PARAMETER WorkflowPath
        Workflow YAML file to inspect.
    .PARAMETER SelectorJobId
        Aggregate-owned changed-file job IDs that require the shared contract.
    .OUTPUTS
        [string[]] containing workflow contract violations.
    #>
        [CmdletBinding()]
        [OutputType([string[]])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$WorkflowPath,

            [Parameter(Mandatory = $true)]
            [string[]]$SelectorJobId
        )

        $Workflow = Get-Content -Raw -Path $WorkflowPath | ConvertFrom-Yaml
        $Violations = [System.Collections.Generic.List[string]]::new()
        $RequiredReferences = @(
            'needs.change-range.outputs.mode'
            'needs.change-range.outputs.base-sha'
            'needs.change-range.outputs.head-sha'
        )
        $MovingRefPattern = 'github\.base_ref|github\.event\.pull_request\.base\.ref|origin/|HEAD\^'

        foreach ($JobId in $SelectorJobId) {
            $Job = if ($Workflow.jobs -is [System.Collections.IDictionary]) {
                $Workflow.jobs[$JobId]
            }
            else {
                $Workflow.jobs.PSObject.Properties[$JobId].Value
            }

            if ($null -eq $Job) {
                $Violations.Add("missing-selector-job:$JobId")
                continue
            }

            $JobJson = $Job | ConvertTo-Json -Depth 20 -Compress
            foreach ($RequiredReference in $RequiredReferences) {
                if ($JobJson -notmatch [regex]::Escape($RequiredReference)) {
                    $Violations.Add("missing-range-contract:${JobId}:$RequiredReference")
                }
            }

            if ($JobJson -match $MovingRefPattern) {
                $Violations.Add("moving-ref-fallback:$JobId")
            }
        }

        return $Violations.ToArray()
    }

    function Get-CheckoutTrustViolation {
        <#
    .SYNOPSIS
        Finds checkout steps whose ref is derived from caller inputs.
    .PARAMETER WorkflowPath
        Workflow YAML file to inspect.
    .OUTPUTS
        [string[]] containing input-derived checkout violations.
    #>
        [CmdletBinding()]
        [OutputType([string[]])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$WorkflowPath
        )

        $Workflow = Get-Content -Raw -Path $WorkflowPath | ConvertFrom-Yaml
        $Violations = [System.Collections.Generic.List[string]]::new()
        if ($null -eq $Workflow -or -not $Workflow.Contains('jobs')) {
            return $Violations.ToArray()
        }

        foreach ($Job in $Workflow['jobs'].GetEnumerator()) {
            foreach ($Step in @($Job.Value['steps'])) {
                if ($null -eq $Step -or [string]$Step['uses'] -notlike 'actions/checkout@*' -or $null -eq $Step['with']) {
                    continue
                }

                if ([string]$Step['with']['ref'] -match '(?<![\w.-])inputs\.') {
                    $Violations.Add("input-derived-checkout:$($Job.Key)")
                }
            }
        }

        return $Violations.ToArray()
    }

    function Get-WorkflowExpressionToken {
        <#
    .SYNOPSIS
        Splits a GitHub Actions expression into literal, operator, and identifier tokens.
    .PARAMETER Expression
        Expression text without the ${{ }} wrapper.
    .OUTPUTS
        [hashtable[]] tokens with Type and Value keys. Unsupported syntax throws.
    #>
        [CmdletBinding()]
        [OutputType([hashtable[]])]
        param(
            [Parameter(Mandatory = $true)]
            [AllowEmptyString()]
            [string]$Expression
        )

        $TokenPattern = [regex]::new("\G(?:(?<ws>\s+)|(?<str>'(?:[^']|'')*')|(?<op>&&|\|\||==|!=|!|\(|\))|(?<num>-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)|(?<id>[A-Za-z_][A-Za-z0-9_-]*(?:\.[A-Za-z_][A-Za-z0-9_-]*)*))")
        $Tokens = [System.Collections.Generic.List[hashtable]]::new()
        $Position = 0
        while ($Position -lt $Expression.Length) {
            $TokenMatch = $TokenPattern.Match($Expression, $Position)
            if (-not $TokenMatch.Success -or $TokenMatch.Length -eq 0) {
                throw "Unsupported expression syntax at position ${Position}: $Expression"
            }

            foreach ($Type in @('str', 'op', 'num', 'id')) {
                if ($TokenMatch.Groups[$Type].Success) {
                    $Tokens.Add(@{ Type = $Type; Value = $TokenMatch.Groups[$Type].Value })
                }
            }

            $Position += $TokenMatch.Length
        }

        return $Tokens.ToArray()
    }

    function ConvertTo-WorkflowExpressionNumber {
        <#
    .SYNOPSIS
        Coerces a value to a number using GitHub Actions loose-equality rules.
    .PARAMETER Value
        Null, boolean, number, or string value.
    .OUTPUTS
        [double] where null and empty string are 0, booleans are 0 or 1, and non-numeric values are NaN.
    #>
        [CmdletBinding()]
        [OutputType([double])]
        param(
            [Parameter(Mandatory = $true)]
            [AllowNull()]
            [AllowEmptyString()]
            [object]$Value
        )

        if ($null -eq $Value) { return 0.0 }
        if ($Value -is [bool]) { return [double]$Value }
        if ($Value -is [string]) {
            if ($Value.Length -eq 0) { return 0.0 }
            if ($Value -match '^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?$') {
                return [double]::Parse($Value, [System.Globalization.CultureInfo]::InvariantCulture)
            }
            return [double]::NaN
        }
        if ($Value -is [double] -or $Value -is [int] -or $Value -is [long]) { return [double]$Value }

        return [double]::NaN
    }

    function Test-WorkflowExpressionTruthy {
        <#
    .SYNOPSIS
        Applies GitHub Actions truthiness to an expression value.
    .PARAMETER Value
        Expression result.
    .OUTPUTS
        [bool] false for false, 0, NaN, empty string, and null; otherwise true.
    #>
        [CmdletBinding()]
        [OutputType([bool])]
        param(
            [Parameter(Mandatory = $true)]
            [AllowNull()]
            [AllowEmptyString()]
            [object]$Value
        )

        if ($null -eq $Value) { return $false }
        if ($Value -is [bool]) { return $Value }
        if ($Value -is [string]) { return $Value.Length -gt 0 }
        if ($Value -is [double] -or $Value -is [int] -or $Value -is [long]) {
            return ([double]$Value -ne 0) -and -not [double]::IsNaN([double]$Value)
        }

        return $true
    }

    function Test-WorkflowExpressionEqual {
        <#
    .SYNOPSIS
        Compares two values with GitHub Actions loose equality.
    .PARAMETER Left
        Left operand.
    .PARAMETER Right
        Right operand.
    .OUTPUTS
        [bool] case-insensitive for strings; mismatched types are coerced to numbers and NaN is never equal.
    #>
        [CmdletBinding()]
        [OutputType([bool])]
        param(
            [Parameter(Mandatory = $true)]
            [AllowNull()]
            [AllowEmptyString()]
            [object]$Left,

            [Parameter(Mandatory = $true)]
            [AllowNull()]
            [AllowEmptyString()]
            [object]$Right
        )

        if ($null -eq $Left -and $null -eq $Right) { return $true }
        if ($Left -is [string] -and $Right -is [string]) {
            return [string]::Equals($Left, $Right, [System.StringComparison]::OrdinalIgnoreCase)
        }
        if ($Left -is [bool] -and $Right -is [bool]) { return $Left -eq $Right }

        $LeftNumber = ConvertTo-WorkflowExpressionNumber -Value $Left
        $RightNumber = ConvertTo-WorkflowExpressionNumber -Value $Right
        if ([double]::IsNaN($LeftNumber) -or [double]::IsNaN($RightNumber)) { return $false }

        return $LeftNumber -eq $RightNumber
    }

    function Read-WorkflowExpressionNode {
        <#
    .SYNOPSIS
        Evaluates one precedence level of a tokenized GitHub Actions expression.
    .PARAMETER State
        Parser state with Tokens, Index, and Resolver keys.
    .PARAMETER Level
        0 for ||, 1 for &&, 2 for == and !=, 3 for unary and primary terms.
    .OUTPUTS
        [object] expression value; && and || return an operand value as GitHub does.
    #>
        [CmdletBinding()]
        [OutputType([object])]
        param(
            [Parameter(Mandatory = $true)]
            [hashtable]$State,

            [Parameter(Mandatory = $false)]
            [int]$Level = 0
        )

        if ($Level -le 2) {
            $Operators = switch ($Level) {
                0 { @('||') }
                1 { @('&&') }
                2 { @('==', '!=') }
            }
            $Left = Read-WorkflowExpressionNode -State $State -Level ($Level + 1)
            while ($State.Index -lt $State.Tokens.Count -and
                $State.Tokens[$State.Index].Type -eq 'op' -and
                $State.Tokens[$State.Index].Value -in $Operators) {
                $Operator = $State.Tokens[$State.Index].Value
                $State.Index++
                $Right = Read-WorkflowExpressionNode -State $State -Level ($Level + 1)
                $LeftIsTruthy = Test-WorkflowExpressionTruthy -Value $Left
                $Left = switch ($Operator) {
                    '||' { if ($LeftIsTruthy) { $Left } else { $Right } }
                    '&&' { if ($LeftIsTruthy) { $Right } else { $Left } }
                    '==' { Test-WorkflowExpressionEqual -Left $Left -Right $Right }
                    '!=' { -not (Test-WorkflowExpressionEqual -Left $Left -Right $Right) }
                }
            }
            return $Left
        }

        if ($State.Index -ge $State.Tokens.Count) {
            throw 'Unexpected end of expression.'
        }

        $Token = $State.Tokens[$State.Index]
        $State.Index++
        switch ($Token.Type) {
            'str' { return $Token.Value.Substring(1, $Token.Value.Length - 2).Replace("''", "'") }
            'num' { return [double]::Parse($Token.Value, [System.Globalization.CultureInfo]::InvariantCulture) }
            'op' {
                if ($Token.Value -eq '!') {
                    $Operand = Read-WorkflowExpressionNode -State $State -Level 3
                    return -not (Test-WorkflowExpressionTruthy -Value $Operand)
                }
                if ($Token.Value -eq '(') {
                    $Inner = Read-WorkflowExpressionNode -State $State -Level 0
                    if ($State.Index -ge $State.Tokens.Count -or $State.Tokens[$State.Index].Value -ne ')') {
                        throw 'Expected a closing parenthesis.'
                    }
                    $State.Index++
                    return $Inner
                }
                throw "Unexpected operator '$($Token.Value)'."
            }
        }

        switch -CaseSensitive ($Token.Value) {
            'true' { return $true }
            'false' { return $false }
            'null' { return $null }
        }

        $IsCall = $State.Index -lt $State.Tokens.Count -and $State.Tokens[$State.Index].Value -eq '('
        if (-not $IsCall) {
            return & $State.Resolver $Token.Value
        }

        $State.Index++
        if ($State.Index -ge $State.Tokens.Count -or $State.Tokens[$State.Index].Value -ne ')') {
            throw "Unsupported arguments for function '$($Token.Value)'."
        }
        $State.Index++
        switch ($Token.Value) {
            'always' { return $true }
            'success' { return $true }
            'cancelled' { return $false }
            'failure' { return $false }
        }
        throw "Unsupported function '$($Token.Value)'."
    }

    function Invoke-WorkflowExpression {
        <#
    .SYNOPSIS
        Evaluates a GitHub Actions expression subset against a context resolver.
    .DESCRIPTION
        Supports string, boolean, null, and number literals; dotted context paths; !, ==, !=, &&, ||,
        and parentheses; and the always, success, cancelled, and failure status functions. Anything
        else throws so that contract tests fail closed instead of misreading a condition.
    .PARAMETER Expression
        Expression text, with or without the ${{ }} wrapper.
    .PARAMETER Resolver
        Script block that maps a dotted context path to its value.
    .OUTPUTS
        [object] expression value.
    #>
        [CmdletBinding()]
        [OutputType([object])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Expression,

            [Parameter(Mandatory = $true)]
            [scriptblock]$Resolver
        )

        $Text = $Expression.Trim()
        if ($Text -match '(?s)^\$\{\{(?<body>.*)\}\}$') {
            $Text = $Matches['body']
        }

        $State = @{
            Tokens   = @(Get-WorkflowExpressionToken -Expression $Text)
            Index    = 0
            Resolver = $Resolver
        }
        $Value = Read-WorkflowExpressionNode -State $State -Level 0
        if ($State.Index -lt $State.Tokens.Count) {
            throw "Unexpected token '$($State.Tokens[$State.Index].Value)'."
        }

        return $Value
    }

    function New-WorkflowEventResolver {
        <#
    .SYNOPSIS
        Builds a context resolver for one event scenario.
    .DESCRIPTION
        Resolves github.* from the scenario. Every needs output resolves to 'true', every needs result
        to 'success', every input to true, and every secret to a sentinel, so only the event gate can
        deny a condition.
    .PARAMETER Scenario
        Hashtable with EventName and an optional HeadRepository key whose value may be null.
    .OUTPUTS
        [scriptblock] resolver for Invoke-WorkflowExpression.
    #>
        [CmdletBinding()]
        [OutputType([scriptblock])]
        param(
            [Parameter(Mandatory = $true)]
            [hashtable]$Scenario
        )

        $GitHubEvent = @{}
        if ($Scenario.Contains('HeadRepository')) {
            $GitHubEvent['pull_request'] = @{ head = @{ repo = $Scenario['HeadRepository'] } }
        }
        $Context = @{
            github = @{
                event_name = $Scenario['EventName']
                repository = 'microsoft/hve-core'
                event      = $GitHubEvent
            }
        }
        $SecretSentinel = $script:SecretSentinel

        return {
            param([string]$Path)

            $Segments = $Path.Split('.')
            switch ($Segments[0]) {
                'needs' { if ($Segments[-1] -eq 'result') { return 'success' } else { return 'true' } }
                'inputs' { return $true }
                'secrets' { return $SecretSentinel }
            }

            $Node = $Context
            foreach ($Segment in $Segments) {
                if ($Node -isnot [System.Collections.IDictionary] -or -not $Node.Contains($Segment)) {
                    return $null
                }
                $Node = $Node[$Segment]
            }

            return $Node
        }.GetNewClosure()
    }

    function Get-TokenReachableJob {
        <#
    .SYNOPSIS
        Finds jobs that can reach the custom eval token directly or through needs.
    .PARAMETER Workflow
        Parsed workflow document.
    .OUTPUTS
        [string[]] sorted job IDs that reference the token, inherit secrets, or need such a job.
    #>
        [CmdletBinding()]
        [OutputType([string[]])]
        param(
            [Parameter(Mandatory = $true)]
            [System.Collections.IDictionary]$Workflow
        )

        $TokenReference = 'secrets\.copilot[-_]github[-_]token|secrets\s*\[|toJSON\(\s*secrets\s*\)'
        $Reachable = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($Job in $Workflow['jobs'].GetEnumerator()) {
            $JobJson = $Job.Value | ConvertTo-Json -Depth 30 -Compress
            if ($JobJson -match $TokenReference -or [string]$Job.Value['secrets'] -eq 'inherit') {
                [void]$Reachable.Add([string]$Job.Key)
            }
        }

        do {
            $Added = $false
            foreach ($Job in $Workflow['jobs'].GetEnumerator()) {
                if ($Reachable.Contains([string]$Job.Key)) { continue }
                foreach ($Need in @($Job.Value['needs'])) {
                    if ($null -ne $Need -and $Reachable.Contains([string]$Need)) {
                        [void]$Reachable.Add([string]$Job.Key)
                        $Added = $true
                        break
                    }
                }
            }
        } while ($Added)

        return @($Reachable | Sort-Object)
    }

    function Get-CredentialGateViolation {
        <#
    .SYNOPSIS
        Finds token-reachable jobs whose condition does not enforce the trusted-event gate.
    .PARAMETER Workflow
        Parsed workflow document.
    .PARAMETER UntrustedScenario
        Event scenarios in which every token-reachable job must be skipped.
    .PARAMETER TrustedScenario
        Event scenarios in which every token-reachable job must remain eligible to run.
    .OUTPUTS
        [string[]] containing credential gate violations.
    #>
        [CmdletBinding()]
        [OutputType([string[]])]
        param(
            [Parameter(Mandatory = $true)]
            [System.Collections.IDictionary]$Workflow,

            [Parameter(Mandatory = $false)]
            [hashtable[]]$UntrustedScenario = @(),

            [Parameter(Mandatory = $false)]
            [hashtable[]]$TrustedScenario = @()
        )

        $Violations = [System.Collections.Generic.List[string]]::new()
        $SameRepositoryPredicate = 'github.event.pull_request.head.repo.full_name == github.repository'

        if ($Workflow.Contains('env') -and ($Workflow['env'] | ConvertTo-Json -Depth 10 -Compress) -match 'secrets') {
            $Violations.Add('workflow-env-secret')
        }

        foreach ($JobId in (Get-TokenReachableJob -Workflow $Workflow)) {
            $Condition = [string]$Workflow['jobs'][$JobId]['if']
            if ([string]::IsNullOrWhiteSpace($Condition)) {
                $Violations.Add("ungated:$JobId")
                continue
            }

            if (-not ($Condition -replace '\s+', ' ').Contains($SameRepositoryPredicate)) {
                $Violations.Add("missing-same-repository-predicate:$JobId")
            }

            foreach ($Scenario in $UntrustedScenario) {
                $Result = Invoke-WorkflowExpression -Expression $Condition -Resolver (New-WorkflowEventResolver -Scenario $Scenario)
                if (Test-WorkflowExpressionTruthy -Value $Result) {
                    $Violations.Add("runs-untrusted:${JobId}:$($Scenario['Name'])")
                }
            }

            foreach ($Scenario in $TrustedScenario) {
                $Result = Invoke-WorkflowExpression -Expression $Condition -Resolver (New-WorkflowEventResolver -Scenario $Scenario)
                if (-not (Test-WorkflowExpressionTruthy -Value $Result)) {
                    $Violations.Add("blocks-trusted:${JobId}:$($Scenario['Name'])")
                }
            }
        }

        return $Violations.ToArray()
    }

    $script:SecretSentinel = 'copilot-token-sentinel'
    $script:WorkflowRoot = Join-Path $PSScriptRoot '../../../.github/workflows'
    $script:AggregateWorkflowPath = Join-Path $PSScriptRoot '../../../.github/workflows/pr-validation.yml'
    $script:AggregateWorkflow = Get-Content -Raw -Path $script:AggregateWorkflowPath | ConvertFrom-Yaml

    # Every aggregate job that scopes work by change range, mapped to its reusable workflow file.
    $script:ChangedFileSelectorJobs = @{}
    foreach ($JobEntry in $script:AggregateWorkflow['jobs'].GetEnumerator()) {
        $With = $JobEntry.Value['with']
        if ($With -isnot [System.Collections.IDictionary]) { continue }
        if ($With['changed-files-only'] -eq $true -or $With.Contains('change-mode')) {
            $script:ChangedFileSelectorJobs[[string]$JobEntry.Key] = Split-Path -Leaf ([string]$JobEntry.Value['uses'])
        }
    }
}

Describe 'Trusted checkout contract' -Tag 'Unit' {
    BeforeAll {
        # Inline copies stay byte-identical per shell so a weakened comparison in any copy fails here.
        $script:CanonicalHeadVerificationBodies = @{
            pwsh = @'
$actualHeadSha = (git rev-parse HEAD).Trim()
if ($env:EXPECTED_HEAD_SHA -cnotmatch '^(?:[0-9a-f]{40}|[0-9a-f]{64})$' -or $actualHeadSha -cne $env:EXPECTED_HEAD_SHA) {
  Write-Output "::error::Checked-out commit $actualHeadSha does not match the resolved head commit."
  exit 1
}
'@ -replace "`r`n", "`n"
            bash = @'
actual_head_sha="$(git rev-parse HEAD)"
if [[ ! "${EXPECTED_HEAD_SHA}" =~ ^([0-9a-f]{40}|[0-9a-f]{64})$ || "${actual_head_sha}" != "${EXPECTED_HEAD_SHA}" ]]; then
  echo "::error::Checked-out commit ${actual_head_sha} does not match the resolved head commit."
  exit 1
fi
'@ -replace "`r`n", "`n"
        }
    }

    It 'Reports a checkout ref derived from caller inputs, including compound expressions' {
        $WorkflowPath = Join-Path $TestDrive 'input-derived-checkout.yml'
        @'
jobs:
    selector:
        runs-on: ubuntu-latest
        steps:
            - uses: actions/checkout@0000000000000000000000000000000000000000
              with:
                  ref: ${{ inputs.change-mode == 'range' && inputs.head-sha || github.sha }}
'@ | Set-Content -Path $WorkflowPath -Encoding utf8NoBOM

        Get-CheckoutTrustViolation -WorkflowPath $WorkflowPath | Should -Contain 'input-derived-checkout:selector'
    }

    It 'Never derives a checkout ref from caller inputs in any workflow' {
        $Violations = foreach ($WorkflowFile in Get-ChildItem -Path $script:WorkflowRoot -Filter '*.yml') {
            Get-CheckoutTrustViolation -WorkflowPath $WorkflowFile.FullName | ForEach-Object { "$($WorkflowFile.Name):$_" }
        }

        $Violations | Should -BeNullOrEmpty
    }

    It 'Checks out the event commit and verifies the resolved head before other steps in <Workflow> job <Job>' -ForEach $script:TrustedCheckoutSites {
        $Document = Get-Content -Raw -Path (Join-Path $script:WorkflowRoot $Workflow) | ConvertFrom-Yaml
        $Steps = @($Document['jobs'][$Job]['steps'])
        $CheckoutIndex = [array]::FindIndex($Steps, [Predicate[object]] { param($Step) [string]$Step['uses'] -like 'actions/checkout@*' })
        $CheckoutStep = $Steps[$CheckoutIndex]
        $VerifyStep = $Steps[$CheckoutIndex + 1]

        $CheckoutStep['with']['ref'] | Should -BeExactly '${{ github.sha }}'
        $CheckoutStep['with']['persist-credentials'] | Should -BeFalse
        $VerifyStep['if'] | Should -BeExactly "inputs.change-mode == 'range'"
        $VerifyStep['env']['EXPECTED_HEAD_SHA'] | Should -BeExactly '${{ inputs.head-sha }}'
        $VerifyStep.Contains('uses') | Should -BeFalse
        [string]$VerifyStep['run'] | Should -Match 'git rev-parse HEAD'
        [string]$VerifyStep['run'] | Should -Match 'exit 1'
        [string]$VerifyStep['run'] | Should -Not -Match '\$\{\{'
    }

    It 'Uses the canonical head-verification body for its shell in <Workflow> job <Job>' -ForEach $script:TrustedCheckoutSites {
        $Document = Get-Content -Raw -Path (Join-Path $script:WorkflowRoot $Workflow) | ConvertFrom-Yaml
        $VerifyStep = @($Document['jobs'][$Job]['steps']) | Where-Object { $_['name'] -eq 'Verify resolved head commit' }
        $Shell = [string]$VerifyStep['shell']
        $Body = ([string]$VerifyStep['run']) -replace "`r`n", "`n"

        $script:CanonicalHeadVerificationBodies.Keys | Should -Contain $Shell
        $Body.Trim() | Should -BeExactly $script:CanonicalHeadVerificationBodies[$Shell]
    }

    It 'Lists every workflow job that verifies a resolved head commit' -ForEach @(@{ Sites = $script:TrustedCheckoutSites }) {
        $DiscoveredSites = foreach ($WorkflowFile in Get-ChildItem -Path $script:WorkflowRoot -Filter '*.yml') {
            $Document = Get-Content -Raw -Path $WorkflowFile.FullName | ConvertFrom-Yaml
            if ($Document -isnot [System.Collections.IDictionary] -or $Document['jobs'] -isnot [System.Collections.IDictionary]) { continue }

            foreach ($JobEntry in $Document['jobs'].GetEnumerator()) {
                $Steps = @($JobEntry.Value['steps'])
                if (@($Steps | Where-Object { $_ -is [System.Collections.IDictionary] -and $_['name'] -eq 'Verify resolved head commit' }).Count -gt 0) {
                    "$($WorkflowFile.Name):$($JobEntry.Key)"
                }
            }
        }
        $ListedSites = foreach ($Site in $Sites) { "$($Site.Workflow):$($Site.Job)" }

        @($DiscoveredSites | Sort-Object) | Should -BeExactly @($ListedSites | Sort-Object)
    }
}

Describe 'Aggregate changed-file workflow contract' -Tag 'Unit' {
    It 'Reports a selector job that bypasses the shared range contract' {
        $WorkflowPath = Join-Path $TestDrive 'bypassed-contract.yml'
        @'
jobs:
    selector:
        runs-on: ubuntu-latest
        steps:
            - run: git diff --name-only base..head
'@ | Set-Content -Path $WorkflowPath -Encoding utf8NoBOM

        $Violations = Get-WorkflowRangeContractViolation -WorkflowPath $WorkflowPath -SelectorJobId 'selector'

        $Violations | Should -Contain 'missing-range-contract:selector:needs.change-range.outputs.mode'
        $Violations | Should -Contain 'missing-range-contract:selector:needs.change-range.outputs.base-sha'
        $Violations | Should -Contain 'missing-range-contract:selector:needs.change-range.outputs.head-sha'
    }

    It 'Reports a selector job that reintroduces a moving-ref fallback' {
        $WorkflowPath = Join-Path $TestDrive 'moving-ref-fallback.yml'
        @'
jobs:
    selector:
        needs: change-range
        runs-on: ubuntu-latest
        env:
            MODE: ${{ needs.change-range.outputs.mode }}
            BASE_SHA: ${{ needs.change-range.outputs.base-sha }}
            HEAD_SHA: ${{ needs.change-range.outputs.head-sha }}
        steps:
            - run: git diff --name-only origin/main..HEAD
'@ | Set-Content -Path $WorkflowPath -Encoding utf8NoBOM

        $Violations = Get-WorkflowRangeContractViolation -WorkflowPath $WorkflowPath -SelectorJobId 'selector'

        $Violations | Should -Contain 'moving-ref-fallback:selector'
    }

    It 'Routes every changed-file aggregate job through the range contract' {
        $ChangedFileJobs = @($script:ChangedFileSelectorJobs.Keys)
        $ChangedFilesOnlyJobs = @(
            $script:AggregateWorkflow['jobs'].GetEnumerator() |
                Where-Object { $_.Value['with'] -is [System.Collections.IDictionary] -and $_.Value['with']['changed-files-only'] -eq $true } |
                ForEach-Object { [string]$_.Key }
        )

        $ChangedFileJobs | Should -Not -BeNullOrEmpty
        foreach ($JobId in $ChangedFilesOnlyJobs) {
            $ChangedFileJobs | Should -Contain $JobId
        }
        Get-WorkflowRangeContractViolation -WorkflowPath $script:AggregateWorkflowPath -SelectorJobId $ChangedFileJobs |
            Should -BeNullOrEmpty
    }

    It 'Defines full-or-range inputs without moving-ref fallbacks in every changed-file workflow' {
        $WorkflowNames = @($script:ChangedFileSelectorJobs.Values | Sort-Object -Unique)

        $WorkflowNames | Should -Not -BeNullOrEmpty
        foreach ($WorkflowName in $WorkflowNames) {
            $WorkflowPath = Join-Path $PSScriptRoot "../../../.github/workflows/$WorkflowName"
            $WorkflowText = Get-Content -Raw -Path $WorkflowPath
            $Workflow = $WorkflowText | ConvertFrom-Yaml
            $Inputs = $Workflow['on']['workflow_call']['inputs']

            $Inputs['change-mode']['default'] | Should -BeExactly 'full' -Because "$WorkflowName must default to full validation"
            $Inputs.Contains('base-sha') | Should -BeTrue -Because "$WorkflowName must accept the resolved base"
            $Inputs.Contains('head-sha') | Should -BeTrue -Because "$WorkflowName must accept the resolved head"
            $WorkflowText | Should -Match 'inputs\.base-sha' -Because "$WorkflowName must use the resolved base"
            $WorkflowText | Should -Not -Match 'inputs\.base-branch|github\.base_ref|github\.event\.before|origin/main|origin/\$' -Because "$WorkflowName must not fall back to a moving ref"
        }
    }

    It 'Lets change-range errors fail the step unless the caller opts into soft-fail' {
        $Violations = foreach ($WorkflowName in @($script:ChangedFileSelectorJobs.Values | Sort-Object -Unique)) {
            $Workflow = Get-Content -Raw -Path (Join-Path $PSScriptRoot "../../../.github/workflows/$WorkflowName") | ConvertFrom-Yaml
            foreach ($JobEntry in $Workflow['jobs'].GetEnumerator()) {
                foreach ($Step in @($JobEntry.Value['steps'])) {
                    if ($Step -isnot [System.Collections.IDictionary]) { continue }
                    if ([string]$Step['run'] -notmatch 'CHANGE_MODE|BASE_SHA') { continue }
                    if ($Step['continue-on-error'] -is [bool] -and $Step['continue-on-error']) {
                        "$($WorkflowName):$($JobEntry.Key):$($Step['name'])"
                    }
                }
            }
        }

        $Violations | Should -BeNullOrEmpty
    }
    It 'Reports ms.date freshness as advisory in full mode for changed-files callers only' {
        $WorkflowRoot = Join-Path $PSScriptRoot '../../../.github/workflows'
        $Workflow = Get-Content -Raw -Path (Join-Path $WorkflowRoot 'msdate-freshness-check.yml') | ConvertFrom-Yaml
        $CheckStep = @($Workflow['jobs']['msdate-freshness']['steps']) | Where-Object { $_['name'] -eq 'Run ms.date freshness check' }
        $WeeklyWorkflow = Get-Content -Raw -Path (Join-Path $WorkflowRoot 'weekly-validation.yml') | ConvertFrom-Yaml
        $AggregateCaller = $script:AggregateWorkflow['jobs']['msdate-freshness']['with']
        $WeeklyCaller = @($WeeklyWorkflow['jobs'].Values | Where-Object { $_['uses'] -eq './.github/workflows/msdate-freshness-check.yml' })

        $CheckStep['run'] | Should -Match "(?s)CHANGED_FILES_ONLY -eq 'true' -and \`$env:INPUT_CHANGE_MODE -eq 'full'\) \{\s+Write-Output '::warning::[^']+'\s+& scripts/linting/Invoke-MsDateFreshnessCheck\.ps1 @params\s+exit 0\s+\}"
        $AggregateCaller['changed-files-only'] | Should -BeTrue
        $AggregateCaller['soft-fail'] | Should -BeFalse
        $WeeklyCaller | Should -HaveCount 1
        $WeeklyCaller[0]['with']['changed-files-only'] | Should -BeFalse
        $WeeklyCaller[0]['with']['soft-fail'] | Should -BeFalse
    }

    It 'Preserves repository-wide internal markdown-link validation' {
        $WorkflowPath = Join-Path $PSScriptRoot '../../../.github/workflows/markdown-link-check.yml'
        $WorkflowText = Get-Content -Raw -Path $WorkflowPath

        $WorkflowText | Should -Match 'internal links are always validated repository-wide'
        $WorkflowText | Should -Match '\$params\[''ChangedFilesOnly''\] = \$true'
        $WorkflowText | Should -Match '\$params\[''BaseBranch''\] = \$env:INPUT_BASE_SHA'
    }

    It 'Bypasses the eval range artifact and forces unprivileged linting in full mode' {
        $WorkflowPath = Join-Path $PSScriptRoot '../../../.github/workflows/eval-validation.yml'
        $Workflow = Get-Content -Raw -Path $WorkflowPath | ConvertFrom-Yaml
        $EvalSteps = @($Workflow['jobs']['eval-validation']['steps'])
        $GenerateStep = $EvalSteps | Where-Object { $_['name'] -eq 'Generate immutable eval change set' }
        $UploadStep = $EvalSteps | Where-Object { $_['name'] -eq 'Upload immutable eval change set' }
        $DetectStep = $EvalSteps | Where-Object { $_['name'] -eq 'Detect eval-relevant changes' }

        $GenerateStep['if'] | Should -BeExactly "inputs.change-mode == 'range'"
        $UploadStep['if'] | Should -BeExactly "inputs.change-mode == 'range'"
        $DetectStep['run'] | Should -Match "INPUT_CHANGE_MODE -eq 'full'"
        $DetectStep['run'] | Should -Match '\$relevant = \$true'
    }

    It 'Moderates content in both modes with a full-scope manifest when no range exists' {
        $WorkflowPath = Join-Path $PSScriptRoot '../../../.github/workflows/eval-validation.yml'
        $Workflow = Get-Content -Raw -Path $WorkflowPath | ConvertFrom-Yaml
        $ModerationJob = $Workflow['jobs']['content-moderation']
        $ModerationSteps = @($ModerationJob['steps'])
        $DownloadStep = $ModerationSteps | Where-Object { $_['name'] -eq 'Download immutable eval change set' }
        $ManifestStep = $ModerationSteps | Where-Object { $_['id'] -eq 'artifact-manifest' }

        $ModerationJob.Contains('if') | Should -BeFalse
        $DownloadStep['if'] | Should -BeExactly "inputs.change-mode == 'range'"
        $ManifestStep['env']['INPUT_CHANGE_MODE'] | Should -BeExactly '${{ inputs.change-mode }}'
        $ManifestStep['run'] | Should -Match "(?s)'range' \{\s+pwsh [^}]*-ChangeSetPath logs/eval-change-set\.json"
        $ManifestStep['run'] | Should -Match "(?s)'full' \{\s+pwsh [^}]*-AllTracked"
        $ManifestStep['run'] | Should -Match "default \{ throw 'Unsupported change mode\.' \}"
    }

    It 'Fails agent-eval selection before any code runs when no verified range exists' {
        $WorkflowPath = Join-Path $PSScriptRoot '../../../.github/workflows/eval-validation.yml'
        $Workflow = Get-Content -Raw -Path $WorkflowPath | ConvertFrom-Yaml
        $FirstStep = @($Workflow['jobs']['agent-plan']['steps'])[0]

        $FirstStep.Contains('uses') | Should -BeFalse
        $FirstStep.Contains('if') | Should -BeFalse
        $FirstStep['env']['INPUT_CHANGE_MODE'] | Should -BeExactly '${{ inputs.change-mode }}'
        $FirstStep['run'] | Should -Match 'INPUT_CHANGE_MODE\}" != ''range'''
        $FirstStep['run'] | Should -Match 'exit 1'
    }

    It 'Scopes gitleaks to exact SHAs in range mode and to candidate history in full mode' {
        $WorkflowPath = Join-Path $PSScriptRoot '../../../.github/workflows/gitleaks-scan.yml'
        $WorkflowText = Get-Content -Raw -Path $WorkflowPath
        $Workflow = $WorkflowText | ConvertFrom-Yaml
        $ScanStep = @($Workflow['jobs']['scan']['steps']) | Where-Object { $_['id'] -eq 'gitleaks' }
        $Inputs = $Workflow['on']['workflow_call']['inputs']

        $Inputs['change-mode']['default'] | Should -BeExactly 'full'
        $Inputs.Contains('log-opts') | Should -BeFalse
        $ScanStep['run'] | Should -Match ([regex]::Escape('"--log-opts=--diff-merges=first-parent ${INPUT_BASE_SHA}..${INPUT_HEAD_SHA}"'))
        $ScanStep['run'] | Should -Match "INPUT_CHANGE_MODE.*= 'full'"
        $ScanStep['run'] | Should -Match ([regex]::Escape('"--log-opts=--full-history --diff-filter=tuxdb --diff-merges=first-parent HEAD"'))
        $ScanStep['run'] | Should -Not -Match '--all'
        $WorkflowText | Should -Not -Match 'github\.event\.pull_request'
    }
}

Describe 'Eval credential boundary' -Tag 'Unit' {
    BeforeAll {
        $script:EvalWorkflowPath = Join-Path $PSScriptRoot '../../../.github/workflows/eval-validation.yml'
        $script:EvalWorkflow = Get-Content -Raw -Path $script:EvalWorkflowPath | ConvertFrom-Yaml
        $script:CallerSecretExpression = [string]$script:AggregateWorkflow['jobs']['eval-validation']['secrets']['copilot-github-token']
        $script:MergeGroupResolver = New-WorkflowEventResolver -Scenario @{ EventName = 'merge_group' }
    }

    Context 'Expression evaluator' {
        It 'Coerces a missing value and false to the same number, as GitHub loose equality does' {
            Invoke-WorkflowExpression -Expression 'github.event.absent == false' -Resolver $script:MergeGroupResolver | Should -BeTrue
            Invoke-WorkflowExpression -Expression 'github.event.absent == github.repository' -Resolver $script:MergeGroupResolver | Should -BeFalse
            Invoke-WorkflowExpression -Expression "'Microsoft/HVE-Core' == github.repository" -Resolver $script:MergeGroupResolver | Should -BeTrue
        }

        It 'Returns operand values from && and ||' {
            Invoke-WorkflowExpression -Expression "`${{ github.event_name == 'pull_request' && 'yes' || 'no' }}" -Resolver $script:MergeGroupResolver | Should -BeExactly 'no'
            Invoke-WorkflowExpression -Expression "!cancelled() && always() && 'run'" -Resolver $script:MergeGroupResolver | Should -BeExactly 'run'
        }

        It 'Rejects unsupported syntax instead of guessing' {
            { Invoke-WorkflowExpression -Expression 'github.event.commits[0]' -Resolver $script:MergeGroupResolver } | Should -Throw
            { Invoke-WorkflowExpression -Expression "contains(github.ref, 'main')" -Resolver $script:MergeGroupResolver } | Should -Throw
        }
    }

    Context 'Caller boundary' {
        It 'Passes the custom eval token under the trusted-event allowlist only' {
            $Expected = '${{ (github.event_name == ''workflow_dispatch'' || (github.event_name == ''pull_request'' && github.event.pull_request.head.repo.full_name == github.repository)) && secrets.COPILOT_GITHUB_TOKEN || '''' }}'

            $script:CallerSecretExpression | Should -BeExactly $Expected
        }

        It 'Passes the custom eval token for <Name>' -ForEach @($script:CredentialEventScenarios | Where-Object { $_.Trusted }) {
            $Resolver = New-WorkflowEventResolver -Scenario $_

            Invoke-WorkflowExpression -Expression $script:CallerSecretExpression -Resolver $Resolver | Should -BeExactly $script:SecretSentinel
        }

        It 'Passes an empty custom eval token for <Name>' -ForEach @($script:CredentialEventScenarios | Where-Object { -not $_.Trusted }) {
            $Resolver = New-WorkflowEventResolver -Scenario $_

            Invoke-WorkflowExpression -Expression $script:CallerSecretExpression -Resolver $Resolver | Should -BeExactly ''
        }
    }

    Context 'Token-reachable jobs' {
        It 'Reports token jobs that forget, bypass, or widen the trusted-event gate' -ForEach @(@{ Untrusted = @($script:CredentialEventScenarios | Where-Object { -not $_.Trusted }) }) {
            $ForkFlagPath = @('github', 'event', 'pull_request', 'head', 'repo', 'fork') -join '.'
            $Workflow = @{
                env  = @{ LEAKED = '${{ secrets.copilot-github-token }}' }
                jobs = @{
                    'direct-ungated' = @{ steps = @(@{ env = @{ COPILOT_GITHUB_TOKEN = '${{ secrets.copilot-github-token }}' } }) }
                    'transitive-always' = @{ needs = @('direct-ungated'); 'if' = 'always()' }
                    'fork-flag' = @{ needs = 'direct-ungated'; 'if' = "github.event_name == 'pull_request' && $ForkFlagPath == false" }
                    'inherited-secrets' = @{ uses = './.github/workflows/other.yml'; secrets = 'inherit'; 'if' = "github.event_name != 'merge_group'" }
                    'unprivileged' = @{ steps = @(@{ run = 'echo lint' }) }
                }
            }

            $Violations = Get-CredentialGateViolation -Workflow $Workflow -UntrustedScenario $Untrusted

            $Violations | Should -Contain 'workflow-env-secret'
            $Violations | Should -Contain 'ungated:direct-ungated'
            $Violations | Should -Contain 'missing-same-repository-predicate:transitive-always'
            $Violations | Should -Contain 'runs-untrusted:transitive-always:a merge group'
            $Violations | Should -Contain 'missing-same-repository-predicate:fork-flag'
            $Violations | Should -Contain 'runs-untrusted:fork-flag:a pull request whose head repository was deleted'
            $Violations | Should -Not -Contain 'runs-untrusted:fork-flag:a fork pull request'
            $Violations | Should -Contain 'runs-untrusted:inherited-secrets:a push'
            ($Violations -join "`n") | Should -Not -Match 'unprivileged'
        }

        It 'Finds every eval job that can reach the custom token and leaves unprivileged checks ungated' {
            $Expected = @('agent-plan', 'equivalence-advisory', 'equivalence-execute', 'equivalence-fan-in', 'eval-execute', 'eval-fan-in', 'eval-report')

            Get-TokenReachableJob -Workflow $script:EvalWorkflow | Should -Be $Expected
            foreach ($JobId in @('eval-validation', 'content-moderation')) {
                $script:EvalWorkflow['jobs'][$JobId].Contains('if') | Should -BeFalse
            }
            Get-CredentialGateViolation -Workflow $script:EvalWorkflow | Should -BeNullOrEmpty
        }

        It 'Skips every token-reachable eval job for <Name>' -ForEach @($script:CredentialEventScenarios | Where-Object { -not $_.Trusted }) {
            Get-CredentialGateViolation -Workflow $script:EvalWorkflow -UntrustedScenario $_ | Should -BeNullOrEmpty
        }

        It 'Keeps every token-reachable eval job eligible for <Name>' -ForEach @($script:CredentialEventScenarios | Where-Object { $_.Trusted -and $_.EventName -eq 'pull_request' }) {
            Get-CredentialGateViolation -Workflow $script:EvalWorkflow -TrustedScenario $_ | Should -BeNullOrEmpty
        }

        It 'Never uses the fail-open fork flag in <_>' -ForEach @('eval-validation.yml', 'agent-conformance.yml', 'pr-validation.yml') {
            Get-Content -Raw -Path (Join-Path $script:WorkflowRoot $_) | Should -Not -Match 'head\.repo\.fork'
        }
    }
}

Describe 'Aggregate merge-group ownership' -Tag 'Unit' {
    It 'Subscribes to checks requested for merge groups targeting main' {
        $MergeGroupTrigger = $script:AggregateWorkflow['on']['merge_group']

        @($MergeGroupTrigger['types']) | Should -Contain 'checks_requested'
        @($MergeGroupTrigger['branches']) | Should -Contain 'main'
    }

    It 'Uses event-safe concurrency without pull-request-only fields' {
        $ConcurrencyGroup = $script:AggregateWorkflow['concurrency']['group']

        $ConcurrencyGroup | Should -BeExactly '${{ github.workflow }}-${{ github.event_name == ''workflow_dispatch'' && github.run_id || github.ref }}'
        $ConcurrencyGroup | Should -Not -Match 'pull_request'
    }

    It 'Exposes one resolver-owned immutable range decision' {
        $RangeJob = $script:AggregateWorkflow['jobs']['change-range']
        $ResolveStep = @($RangeJob['steps']) | Where-Object { $_['id'] -eq 'resolve' }
        $CheckoutStep = @($RangeJob['steps']) | Where-Object { $_['uses'] -like 'actions/checkout@*' }

        $RangeJob['outputs']['mode'] | Should -BeExactly '${{ steps.resolve.outputs.mode }}'
        $RangeJob['outputs']['base-sha'] | Should -BeExactly '${{ steps.resolve.outputs.base-sha }}'
        $RangeJob['outputs']['head-sha'] | Should -BeExactly '${{ steps.resolve.outputs.head-sha }}'
        $CheckoutStep['with']['ref'] | Should -BeExactly '${{ github.sha }}'
        $ResolveStep['env']['EVENT_NAME'] | Should -BeExactly '${{ github.event_name }}'
        $ResolveStep['env']['BASE_SHA'] | Should -Match "event_name == 'merge_group'.*merge_group\.base_sha"
        $ResolveStep['env']['BASE_SHA'] | Should -Not -Match 'pull_request\.base'
        $ResolveStep['env']['HEAD_SHA'] | Should -Match "event_name == 'merge_group'.*merge_group\.head_sha.*\|\| github\.sha"
        $ResolveStep['env']['PR_HEAD_SHA'] | Should -Match "event_name == 'pull_request'.*pull_request\.head\.sha"
        $ResolveStep['env']['DEFAULT_BRANCH'] | Should -BeExactly '${{ github.event.repository.default_branch }}'
        $ResolveStep['run'] | Should -Match 'scripts/ci/Resolve-WorkflowChangeRange\.ps1'
        $ResolveStep['run'] | Should -Not -Match '\$\{\{'
    }

    It 'Keeps the resolver in the stable aggregate gate' {
        @($script:AggregateWorkflow['jobs']['pr-validation-success']['needs']) | Should -Contain 'change-range'
    }

    It 'Gives each manual dispatch its own eval concurrency group' {
        $EvalWorkflow = Get-Content -Raw -Path (Join-Path $script:WorkflowRoot 'eval-validation.yml') | ConvertFrom-Yaml

        $EvalWorkflow['concurrency']['group'] | Should -Match "github\.event_name == 'workflow_dispatch' && github\.run_id \|\|"
        $EvalWorkflow['concurrency']['cancel-in-progress'] | Should -BeFalse
    }

    It 'Keeps release-promotion checks limited to pull requests' {
        $GateSteps = @($script:AggregateWorkflow['jobs']['gate-completeness-check']['steps'])
        $PromotionSteps = @($GateSteps | Where-Object { $_['name'] -like 'Validate * promotion intent*' })

        $PromotionSteps | Should -HaveCount 2
        foreach ($PromotionStep in $PromotionSteps) {
            $PromotionStep['if'] | Should -Match "github\.event_name == 'pull_request'"
        }
    }

    It 'Bounds the write scopes and secrets reachable from merge_group' {
        # merge_group runs fork-originated code in the base-repository context, so every write grant is deliberate.
        $ExpectedWriteGrants = @(
            'action-version-consistency-scan=security-events'
            'adr-consistency-validation=security-events'
            'codeql=security-events'
            'copilot-otel-runtime-tests=id-token'
            'dangerous-workflow-check=security-events'
            'dependency-pinning-check=security-events'
            'docusaurus-tests=id-token'
            'eval-validation=pull-requests'
            'gitleaks-scan=security-events'
            'node-tests=id-token'
            'pester-tests=id-token'
            'pytest=id-token'
            'workflow-permissions-check=security-events'
            'workflow-runner-check=security-events'
        )
        $TopLevelPermissions = $script:AggregateWorkflow['permissions']
        $NonMapPermissionJobs = [System.Collections.Generic.List[string]]::new()
        $ActualWriteGrants = foreach ($JobEntry in $script:AggregateWorkflow['jobs'].GetEnumerator()) {
            $Permissions = $JobEntry.Value['permissions']
            if ($null -eq $Permissions) { continue }
            if ($Permissions -isnot [System.Collections.IDictionary]) {
                $NonMapPermissionJobs.Add($JobEntry.Key)
                continue
            }

            foreach ($Scope in $Permissions.GetEnumerator()) {
                if ([string]$Scope.Value -eq 'write') { "$($JobEntry.Key)=$($Scope.Key)" }
            }
        }
        $AggregateText = Get-Content -Raw -Path $script:AggregateWorkflowPath
        $SecretNames = @([regex]::Matches($AggregateText, 'secrets\.([A-Za-z0-9_]+)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)

        $NonMapPermissionJobs | Should -BeNullOrEmpty
        $TopLevelPermissions | Should -BeOfType [System.Collections.IDictionary]
        @($TopLevelPermissions.Keys) | Should -BeExactly @('contents')
        $TopLevelPermissions['contents'] | Should -BeExactly 'read'
        @($ActualWriteGrants | Sort-Object) | Should -BeExactly @($ExpectedWriteGrants | Sort-Object)
        $SecretNames | Should -BeExactly @('COPILOT_GITHUB_TOKEN')
        $AggregateText | Should -Not -Match 'secrets:\s*inherit'
    }
}
