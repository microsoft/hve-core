#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $script:Collector = Join-Path $script:RepoRoot '.github/skills/security/gh-code-scanning/scripts/Get-CodeScanningAlerts.ps1'
    $script:YamlWasLoaded = $null -ne (Get-Module powershell-yaml)
    Import-Module powershell-yaml -ErrorAction Stop
    $Workflow = Get-Content (Join-Path $script:RepoRoot '.github/workflows/create-gh-code-scanning-issues.yml') -Raw | ConvertFrom-Yaml
    $Steps = $Workflow.jobs.'create-gh-code-scanning-issues'.steps
    $script:IndexStep = @($Steps | Where-Object id -EQ 'issue-index')[0]
    $script:UpdateStep = @($Steps | Where-Object name -EQ 'Create backlog issues for new findings')[0]
    $script:ReconcileStep = @($Steps | Where-Object name -EQ 'Reconcile code scanning issues')[0]
    $Skill = Get-Content (Join-Path $script:RepoRoot '.github/skills/security/gh-code-scanning/SKILL.md') -Raw
    $Example = [regex]::Match($Skill, '(?s)### Dedup check before creation.*?```bash\r?\n(.*?)\r?\n```')
    if (-not $Example.Success) { throw 'Skill deduplication example not found.' }
    $script:SkillExample = $Example.Groups[1].Value.Replace('{owner}', 'example').Replace('{repo}', 'repo').Replace('rule_id="{rule_id}"', 'rule_id="js/rule-b"')
    $script:BashPath = if ($env:CODE_SCANNING_TEST_BASH) { $env:CODE_SCANNING_TEST_BASH } else { (Get-Command bash -ErrorAction Stop).Source }
    $script:JqPath = if ($env:CODE_SCANNING_TEST_JQ) { $env:CODE_SCANNING_TEST_JQ } else { (Get-Command jq -ErrorAction Stop).Source }

    function New-IdentityAlert {
        <# .SYNOPSIS
        Creates one synthetic live alert with rule-specific display metadata.
        #>
        param([string]$RuleId, [int]$Number)

        return @{
            number = $Number
            rule = @{ id = $RuleId; description = 'Shared finding'; severity = 'warning'; security_severity_level = $null }
            tool = @{ name = 'CodeQL' }
            html_url = "https://example.invalid/alerts/$Number"
            most_recent_instance = @{
                location = @{ path = "src/file$Number.py" }
                message = @{ text = "Finding for $RuleId" }
            }
        }
    }

    function Invoke-IdentityStep {
        <# .SYNOPSIS
        Executes an actual workflow run block with isolated, synthetic process state.
        #>
        param([string]$Body, [string]$Directory, [string]$Mode, [hashtable]$StepEnvironment = @{})

        $StartInfo = [System.Diagnostics.ProcessStartInfo]::new()
        $StartInfo.FileName = $script:BashPath
        $StartInfo.WorkingDirectory = $Directory
        $StartInfo.UseShellExecute = $false
        $StartInfo.RedirectStandardOutput = $true
        $StartInfo.RedirectStandardError = $true
        $StartInfo.Environment.Clear()
        foreach ($Name in @('SystemRoot', 'WINDIR', 'COMSPEC', 'TEMP', 'TMP', 'PATHEXT')) {
            $Value = [Environment]::GetEnvironmentVariable($Name)
            if ($Value) { $StartInfo.Environment[$Name] = $Value }
        }
        $Environment = @{
            PATH = '/usr/bin:/bin'; HOME = $Directory.Replace('\', '/'); GH_CONFIG_DIR = $Directory.Replace('\', '/')
            TEST_JQ_PATH = $script:JqPath.Replace('\', '/')
            OWNER = 'example'; REPO = 'repo'; DEFAULT_BRANCH = 'main'
            GITHUB_SERVER_URL = 'https://example.invalid'; GITHUB_REPOSITORY = 'example/repo'
            GITHUB_RUN_ID = 'fixture'; GITHUB_OUTPUT = 'index-output.txt'
            INDEX_TRUNCATED = 'false'; SCAN_HEALTH_VERDICT = 'healthy'; FAILING_ANALYSIS = ''; RECONCILE_MODE = $Mode
        }
        foreach ($Name in $Environment.Keys) { $StartInfo.Environment[$Name] = [string]$Environment[$Name] }
        foreach ($Name in $StepEnvironment.Keys) { $StartInfo.Environment[$Name] = [string]$StepEnvironment[$Name] }
        # Script-file execution preserves the original Bash/jq quoting on Windows.
        $ScriptPath = Join-Path $Directory 'step.sh'
        [System.IO.File]::WriteAllText($ScriptPath, ($script:MockPrefix + "`n" + $Body).Replace("`r`n", "`n") + "`n")
        foreach ($Argument in @('--noprofile', '--norc', $ScriptPath.Replace('\', '/'))) {
            $StartInfo.ArgumentList.Add($Argument)
        }
        $Process = [System.Diagnostics.Process]::new()
        $Process.StartInfo = $StartInfo
        try {
            $null = $Process.Start()
            $Stdout = $Process.StandardOutput.ReadToEndAsync()
            $Stderr = $Process.StandardError.ReadToEndAsync()
            if (-not $Process.WaitForExit(30000)) {
                $Process.Kill($true)
                throw 'Offline identity workflow step exceeded 30 seconds.'
            }
            return @{
                ExitCode = $Process.ExitCode
                Output = $Stdout.GetAwaiter().GetResult() + $Stderr.GetAwaiter().GetResult()
            }
        }
        finally { $Process.Dispose() }
    }

    $script:MockPrefix = @'
# Native Windows jq must preserve the LF output used by the Ubuntu workflow.
jq() { "$TEST_JQ_PATH" --binary "$@"; }
gh() {
  jq -cn --args '$ARGS.positional' -- "$@" >> gh-calls.jsonl
  case "$1 $2" in
        "issue list")
            if [[ "${TEST_EMULATE_QUERY:-false}" != "true" ]]; then
                cat candidates.json
                return
            fi
            shift 2
            local query='' limit=30 state=open
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --search) query="$2"; shift 2 ;;
                    --limit) limit="$2"; shift 2 ;;
                    --state) state="$2"; shift 2 ;;
                    --repo|--json) shift 2 ;;
                    *) printf 'Unexpected list argument in offline test\n' >&2; return 97 ;;
                esac
            done
            # Emulate only the documented fixture-query subset, not GitHub search ranking.
            jq --arg query "$query" --arg state "$state" --argjson limit "$limit" '
                def has_term($term): ($query | split(" ") | index($term)) != null;
                map(select((.body // "") | contains("automation:security-scan:"))
                    | select($state == "all" or (.state | ascii_downcase) == $state)
                    | select((has_term("author:app/github-actions") | not) or .author.login == "app/github-actions")
                    | select((has_term("label:automated") | not) or ([.labels[]?.name] | index("automated")) != null)
                    | select((has_term("label:security") | not) or ([.labels[]?.name] | index("security")) != null))
                | .[:$limit]
            ' candidates.json ;;
    "issue create") printf '%s\n' 'https://example.invalid/issues/100' ;;
    "issue comment"|"issue close"|"issue reopen"|"issue edit") : ;;
    *) printf 'Unexpected gh call in offline test\n' >&2; return 97 ;;
  esac
}
date() {
  case "$*" in
    "-u +%Y-%m-%d") printf '%s\n' '2026-09-08' ;;
    *) printf 'Unexpected date call in offline test\n' >&2; return 96 ;;
  esac
}
readonly -f jq gh date
'@

    function Invoke-IdentityScenario {
        <# .SYNOPSIS
        Feeds collector output or a raw-artifact fixture through the workflow without live calls.
        #>
        param(
            [AllowEmptyCollection()] [object[]]$Alerts,
            [string]$Mode = 'enforce',
            [string]$TrackedRule = 'js/rule-b',
            [AllowEmptyString()] [string]$ArtifactTemplate = '{valid}',
            [switch]$MissingArtifact,
            [switch]$IncludeClosedTracker,
            [switch]$ExpectRejection,
            [AllowEmptyCollection()] [object[]]$IssueCandidates,
            [switch]$EmulateQuery
        )

        $Directory = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $Directory
        $Raw = @($Alerts | ForEach-Object { ConvertTo-Json -InputObject $_ -Depth 10 -Compress })
        $Pager = $env:GH_PAGER
        $ExitCode = $global:LASTEXITCODE
        ${Function:gh} = {
            $global:LASTEXITCODE = 0
            if ($args[0] -eq 'auth' -and $args[1] -eq 'status') { return }
            if ($args[0] -eq 'api') { return $Raw }
            throw 'Unexpected collector gh call in offline test.'
        }.GetNewClosure()
        try {
            $Json = & $script:Collector -Owner 'example' -Repo 'repo' -OutputFormat Json
        }
        finally {
            Remove-Item Function:gh -ErrorAction SilentlyContinue
            $env:GH_PAGER = $Pager
            $global:LASTEXITCODE = $ExitCode
        }
        $Json = ($Json | Out-String).Trim()
        $Groups = @($Json | ConvertFrom-Json)
        $DuplicateJson = ConvertTo-Json -InputObject @($Groups + $Groups) -Depth 10
        if (-not $MissingArtifact) {
            $ArtifactTemplate.Replace('{valid}', $Json).Replace('{duplicate}', $DuplicateJson) |
                Set-Content (Join-Path $Directory 'alerts.json') -Encoding utf8NoBOM
        }
        $Candidates = @(
            @{ number = 42; state = 'OPEN'; body = "<!-- automation:security-scan:$TrackedRule -->`nHuman content"; author = @{ login = 'app/github-actions' }; labels = @(@{ name = 'automated' }, @{ name = 'security' }) }
            @{ number = 99; state = 'OPEN'; body = '<!-- automation:security-scan:py/absent-rule -->'; author = @{ login = 'app/github-actions' }; labels = @(@{ name = 'automated' }, @{ name = 'security' }) }
        )
        if ($IncludeClosedTracker) {
            $Candidates += @{ number = 43; state = 'CLOSED'; body = '<!-- automation:security-scan:py/closed-rule -->'; author = @{ login = 'app/github-actions' }; labels = @(@{ name = 'automated' }, @{ name = 'security' }) }
        }
        if ($PSBoundParameters.ContainsKey('IssueCandidates')) { $Candidates = $IssueCandidates }
        ConvertTo-Json -InputObject $Candidates -Depth 10 | Set-Content (Join-Path $Directory 'candidates.json') -Encoding utf8NoBOM
        $Output = ''
        $ExecutedSteps = 0
        $Truncated = 'false'
        foreach ($Step in @($script:IndexStep, $script:UpdateStep, $script:ReconcileStep)) {
            $Result = Invoke-IdentityStep -Body $Step.run -Directory $Directory -Mode $Mode -StepEnvironment @{
                INDEX_TRUNCATED = $Truncated
                TEST_EMULATE_QUERY = $EmulateQuery.IsPresent.ToString().ToLowerInvariant()
            }
            $ExecutedSteps++
            $Output += $Result.Output
            if (-not $ExpectRejection -or $Step -eq $script:IndexStep) {
                $Result.ExitCode | Should -Be 0 -Because $Result.Output
            }
            if ($Result.ExitCode -ne 0) { break }
            if ($Step -eq $script:IndexStep) {
                $IndexOutput = Get-Content (Join-Path $Directory 'index-output.txt') -Raw | ConvertFrom-StringData
                $Truncated = $IndexOutput.truncated
                $Truncated | Should -BeIn @('false', 'true')
            }
        }
        $Calls = @(Get-Content (Join-Path $Directory 'gh-calls.jsonl') | ForEach-Object { , (ConvertFrom-Json $_ -NoEnumerate) })
        return @{
            Live = $(if (-not $ExpectRejection -and $Truncated -eq 'false') { @(Get-Content (Join-Path $Directory 'live-rule-ids.json') -Raw | ConvertFrom-Json) })
            CloseSet = $(if (-not $ExpectRejection -and $Truncated -eq 'false') { @(Get-Content (Join-Path $Directory 'close-set.json') -Raw | ConvertFrom-Json) })
            Truncated = $Truncated
            CandidateCount = @(Get-Content (Join-Path $Directory 'issue-candidates.json') -Raw | ConvertFrom-Json).Count
            Index = @(Get-Content (Join-Path $Directory 'issue-index.json') -Raw | ConvertFrom-Json)
            HasLiveFile = Test-Path (Join-Path $Directory 'live-rule-ids.json')
            HasCloseSet = Test-Path (Join-Path $Directory 'close-set.json')
            Calls = $Calls
            Output = $Output
            ExitCode = $Result.ExitCode
            ExecutedSteps = $ExecutedSteps
        }
    }

    function New-QuotaIssue {
        <# .SYNOPSIS
        Creates a synthetic candidate for ownership and quota scenarios.
        #>
        param([int]$Number, [string]$Rule = 'py/filler', [string]$State = 'CLOSED', [string]$Author = 'app/github-actions', [string[]]$Labels = @('automated', 'security'))

        return @{ number = $Number; state = $State; body = "<!-- automation:security-scan:$Rule -->"; author = @{ login = $Author }; labels = @($Labels | ForEach-Object { @{ name = $_ } }) }
    }

    function Invoke-SkillQuotaScenario {
        <# .SYNOPSIS
        Executes the actual skill example using only synthetic candidates and a mock ledger.
        #>
        param([AllowEmptyCollection()] [object[]]$Candidates, [switch]$RawResponse)

        $Directory = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $Directory
        ConvertTo-Json -InputObject $Candidates -Depth 10 | Set-Content (Join-Path $Directory 'candidates.json') -Encoding utf8NoBOM
        [System.IO.File]::WriteAllText((Join-Path $Directory 'gh-calls.jsonl'), '')
        $Result = Invoke-IdentityStep -Body $script:SkillExample -Directory $Directory -Mode 'dry-run' -StepEnvironment @{
            TEST_EMULATE_QUERY = (-not $RawResponse).ToString().ToLowerInvariant()
        }
        $Result.Calls = @(Get-Content (Join-Path $Directory 'gh-calls.jsonl') | ForEach-Object { , (ConvertFrom-Json $_ -NoEnumerate) })
        return $Result
    }
}

Describe 'Code scanning live identity contract' -Tag 'Unit' {
    It 'protects a colliding live tracker in <Mode> with reversed order <Reverse>' -ForEach @(
        @{ Mode = 'enforce'; Reverse = $false }
        @{ Mode = 'enforce'; Reverse = $true }
        @{ Mode = 'dry-run'; Reverse = $false }
        @{ Mode = 'dry-run'; Reverse = $true }
    ) {
        $Alerts = @(New-IdentityAlert -RuleId 'py/rule-a' -Number 1; New-IdentityAlert -RuleId 'js/rule-b' -Number 2)
        if ($Reverse) { [array]::Reverse($Alerts) }
        $Result = Invoke-IdentityScenario -Alerts $Alerts -Mode $Mode

        $Result.Live | Should -BeExactly @('js/rule-b', 'py/rule-a')
        $Result.CloseSet | Should -HaveCount 1
        $Result.CloseSet[0].number | Should -Be 99
        $Comments = @($Result.Calls | Where-Object { $_[1] -eq 'comment' -and $_[2] -eq '42' })
        $Comments | Should -HaveCount 1
        $Creates = @($Result.Calls | Where-Object { $_[1] -eq 'create' })
        $Creates | Should -HaveCount 1
        $Creates[0][-1] | Should -Match 'automation:security-scan:py/rule-a'
        $Creates[0][-1] | Should -Not -Match 'src/file2.py'
        @($Result.Calls | Where-Object { $_[1] -eq 'edit' -or $_[1] -eq 'reopen' }) | Should -HaveCount 0
        $Closes = @($Result.Calls | Where-Object { $_[1] -eq 'close' })
        if ($Mode -eq 'enforce') {
            $Closes | Should -HaveCount 1
            $Closes[0][2] | Should -BeExactly '99'
            $Closes[0][-1] | Should -Match 'py/absent-rule'
            $Closes[0][-1] | Should -Match 'https://example.invalid/example/repo/actions/runs/fixture'
        }
        else {
            $Closes | Should -HaveCount 0
            $Result.Output | Should -Match 'Dry run: would close issue #99'
            $Result.Output | Should -Not -Match 'would close issue #42'
        }
    }

    It 'protects case-distinct live identities without normalizing tracker keys' {
        $Alerts = @(New-IdentityAlert -RuleId 'py/rule-a' -Number 1; New-IdentityAlert -RuleId 'PY/RULE-A' -Number 2)
        $Result = Invoke-IdentityScenario -Alerts $Alerts -TrackedRule 'PY/RULE-A'

        $Result.Live | Should -BeExactly @('PY/RULE-A', 'py/rule-a')
        $Result.CloseSet | Should -HaveCount 1
        $Result.CloseSet[0].number | Should -Be 99
        $Closes = @($Result.Calls | Where-Object { $_[1] -eq 'close' })
        $Closes | Should -HaveCount 1
        $Closes[0][2] | Should -BeExactly '99'
    }

    It 'keeps a repeated ID valid when descriptions differ' {
        $Alerts = @(New-IdentityAlert -RuleId 'js/rule-b' -Number 1; New-IdentityAlert -RuleId 'js/rule-b' -Number 2)
        $Alerts[1].rule.description = 'Updated description'
        $Result = Invoke-IdentityScenario -Alerts $Alerts

        $Result.Live | Should -BeExactly @('js/rule-b')
        @($Result.Calls | Where-Object { $_[1] -eq 'create' }) | Should -HaveCount 0
        $Comments = @($Result.Calls | Where-Object { $_[1] -eq 'comment' })
        $Comments | Should -HaveCount 1
        $Comments[0][-1] | Should -Match '2 occurrences'
        $Result.CloseSet | Should -HaveCount 1
        $Result.CloseSet[0].number | Should -Be 99
    }

    It 'keeps empty collector output as a valid stale-tracker closure control' {
        $Result = Invoke-IdentityScenario -Alerts @()

        $Result.Live | Should -HaveCount 0
        $Result.CloseSet.number | Should -Be @(42, 99)
        $Closes = @($Result.Calls | Where-Object { $_[1] -eq 'close' })
        $Closes | Should -HaveCount 2
        $Closes[0][2] | Should -BeExactly '42'
        $Closes[1][2] | Should -BeExactly '99'
    }
}

Describe 'Code scanning single-document boundary in <Mode>' -Tag 'Unit' -ForEach @(
    @{ Mode = 'enforce' }
    @{ Mode = 'dry-run' }
) {
    It 'rejects <Name> before any issue mutation' -ForEach @(
        @{ Name = 'empty then live'; Template = '[] {valid}' }
        @{ Name = 'live then empty'; Template = '{valid} []' }
        @{ Name = 'two empty arrays'; Template = '[] []' }
        @{ Name = 'object then valid array'; Template = '{} {valid}' }
        @{ Name = 'invalid records then valid array'; Template = '[{}] {valid}' }
        @{ Name = 'duplicates across documents'; Template = '{valid} {valid}' }
        @{ Name = 'empty input'; Template = '' }
        @{ Name = 'whitespace input'; Template = " `r`n`t" }
        @{ Name = 'missing file'; Template = '{valid}'; Missing = $true }
        @{ Name = 'invalid syntax'; Template = '[' }
        @{ Name = 'valid prefix with malformed suffix'; Template = '{valid} [' }
        @{ Name = 'object root'; Template = '{}' }
        @{ Name = 'null root'; Template = 'null' }
        @{ Name = 'nested array'; Template = '[[]]' }
        @{ Name = 'duplicates within one array'; Template = '{duplicate}' }
        @{ Name = 'valid array then null'; Template = '{valid} null' }
        @{ Name = 'false then valid array'; Template = 'false {valid}' }
    ) {
        $Alerts = @(
            New-IdentityAlert -RuleId 'js/rule-b' -Number 1
            New-IdentityAlert -RuleId 'py/closed-rule' -Number 2
            New-IdentityAlert -RuleId 'py/new-rule' -Number 3
        )
        $Result = Invoke-IdentityScenario -Alerts $Alerts -Mode $Mode -ArtifactTemplate $Template -MissingArtifact:([bool]$Missing) -IncludeClosedTracker -ExpectRejection

        @($Result.Calls | Where-Object { $_[0] -eq 'issue' -and $_[1] -ne 'list' }) | Should -HaveCount 0 -Because $Result.Output
        $Result.ExitCode | Should -Not -Be 0 -Because $Result.Output
        $Result.ExecutedSteps | Should -Be 2
        $Result.Output | Should -Match 'no issues were processed'
    }

    It 'preserves valid lifecycle operations and escaped strings with surrounding whitespace' {
        $Alerts = @(
            New-IdentityAlert -RuleId 'js/rule-b' -Number 1
            New-IdentityAlert -RuleId 'py/closed-rule' -Number 2
            New-IdentityAlert -RuleId 'py/new-rule' -Number 3
        )
        $Alerts[2].most_recent_instance.message.text = "First `"quoted`" line`nSecond line with \backslash"
        $Result = Invoke-IdentityScenario -Alerts $Alerts -Mode $Mode -IncludeClosedTracker -ArtifactTemplate " `r`n{valid}`r`n`t"

        $Result.ExitCode | Should -Be 0
        $Result.Live | Should -BeExactly @('js/rule-b', 'py/closed-rule', 'py/new-rule')
        $Creates = @($Result.Calls | Where-Object { $_[1] -eq 'create' })
        $Creates | Should -HaveCount 1
        $Creates[0][-1] | Should -Match 'automation:security-scan:py/new-rule'
        $Creates[0][-1].Contains($Alerts[2].most_recent_instance.message.text) | Should -BeTrue
        $Comments = @($Result.Calls | Where-Object { $_[1] -eq 'comment' })
        $Comments | Should -HaveCount 2
        @($Comments | ForEach-Object { $_[2] } | Sort-Object) | Should -Be @('42', '43')
        $Reopens = @($Result.Calls | Where-Object { $_[1] -eq 'reopen' })
        $Reopens | Should -HaveCount 1
        $Reopens[0][2] | Should -BeExactly '43'
        $Edits = @($Result.Calls | Where-Object { $_[1] -eq 'edit' })
        $Edits | Should -HaveCount 1
        $Edits[0] | Should -BeExactly @('issue', 'edit', '43', '--repo', 'example/repo', '--add-label', 'needs-triage')
        $Result.CloseSet | Should -HaveCount 1
        $Result.CloseSet[0].number | Should -Be 99
        $Closes = @($Result.Calls | Where-Object { $_[1] -eq 'close' })
        if ($Mode -eq 'enforce') {
            $Closes | Should -HaveCount 1
            $Closes[0][2] | Should -BeExactly '99'
        }
        else { $Closes | Should -HaveCount 0 }
    }

    It 'accepts one empty array with whitespace without creating or updating issues' {
        $Result = Invoke-IdentityScenario -Alerts @() -Mode $Mode -ArtifactTemplate " `r`n[]`r`n"

        $Result.ExitCode | Should -Be 0
        $Result.Live | Should -HaveCount 0
        $Result.CloseSet.number | Should -Be @(42, 99)
        @($Result.Calls | Where-Object { $_[1] -in @('create', 'comment', 'reopen', 'edit') }) | Should -HaveCount 0
        $Closes = @($Result.Calls | Where-Object { $_[1] -eq 'close' })
        $Closes | Should -HaveCount $(if ($Mode -eq 'enforce') { 2 } else { 0 })
    }
}

Describe 'Code scanning direct reconciliation document guard' -Tag 'Unit' {
    It 'rejects <Name> even with valid derived inputs' -ForEach @(
        @{ Name = 'two empty arrays'; Payload = '[] []' }
        @{ Name = 'empty then nonempty'; Payload = '[] [{}]' }
        @{ Name = 'nonempty then empty'; Payload = '[{}] []' }
        @{ Name = 'object then array'; Payload = '{} []' }
        @{ Name = 'empty input'; Payload = '' }
        @{ Name = 'whitespace input'; Payload = " `n`t" }
        @{ Name = 'missing file'; Payload = ''; Missing = $true }
        @{ Name = 'malformed suffix'; Payload = '[] [' }
    ) {
        $Directory = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $Directory
        if (-not $Missing) { $Payload | Set-Content (Join-Path $Directory 'alerts.json') -Encoding utf8NoBOM }
        '[]' | Set-Content (Join-Path $Directory 'live-rule-ids.json') -Encoding utf8NoBOM
        '[{"number":99,"state":"open","rule":"py/absent-rule"}]' | Set-Content (Join-Path $Directory 'issue-index.json') -Encoding utf8NoBOM
        [System.IO.File]::WriteAllText((Join-Path $Directory 'gh-calls.jsonl'), '')

        $Result = Invoke-IdentityStep -Body $script:ReconcileStep.run -Directory $Directory -Mode 'enforce'

        @(Get-Content (Join-Path $Directory 'gh-calls.jsonl')) | Should -HaveCount 0 -Because $Result.Output
        $Result.ExitCode | Should -Not -Be 0
        Test-Path (Join-Path $Directory 'close-set.json') | Should -BeFalse
    }
}

Describe 'Current remediation context for <State> trackers in <Mode>' -Tag 'Unit' -ForEach @(
    @{ State = 'OPEN'; Mode = 'enforce' }
    @{ State = 'CLOSED'; Mode = 'enforce' }
    @{ State = 'OPEN'; Mode = 'dry-run' }
    @{ State = 'CLOSED'; Mode = 'dry-run' }
) {
    It 'publishes current <Details> without overwriting human content' -ForEach @(
        @{ Details = 'security finding'; Security = 'high'; Severity = 'warning'; ExpectedSeverity = 'high'; NoPath = $false; Missing = $false }
        @{ Details = 'quality finding'; Security = $null; Severity = 'warning'; ExpectedSeverity = 'warning'; NoPath = $false; Missing = $false }
        @{ Details = 'configuration finding'; Security = 'medium'; Severity = 'error'; ExpectedSeverity = 'medium'; NoPath = $true; Missing = $false }
        @{ Details = 'missing optional metadata'; Security = $null; Severity = $null; ExpectedSeverity = $null; NoPath = $false; Missing = $true }
    ) {
        $Alerts = @(
            New-IdentityAlert -RuleId 'py/recurring-rule' -Number 501
            New-IdentityAlert -RuleId 'py/recurring-rule' -Number 502
        )
        $Message = "Current `"quoted`" diagnostic`nPath \branch and literal `$value."
        foreach ($Alert in $Alerts) {
            $Alert.rule.description = 'Current recurrence description'
            $Alert.rule.security_severity_level = $Security
            $Alert.rule.severity = $Severity
            $Alert.most_recent_instance.message.text = $(if ($Missing) { $null } else { $Message })
            if ($Missing) { $Alert.html_url = $null }
            if ($NoPath) {
                $Alert.tool.name = 'Scorecard'
                $Alert.most_recent_instance.location.path = 'no file associated with this alert'
            }
        }
        $OldBody = @'
<!-- automation:security-scan:py/recurring-rule -->
Human remediation notes: preserve this explanation and completed checklist.
- [x] Investigated the previous occurrence
Old description; severity low; old finding text.
https://example.invalid/alerts/90
src/old-path.py
'@
        $Candidates = @(
            @{ number = 42; state = $State; title = 'Human edited title'; body = $OldBody; author = @{ login = 'app/github-actions' }; labels = @(@{ name = 'automated' }, @{ name = 'security' }, @{ name = 'human-label' }) }
            @{ number = 99; state = 'OPEN'; body = '<!-- automation:security-scan:py/absent-rule -->'; author = @{ login = 'app/github-actions' }; labels = @(@{ name = 'automated' }, @{ name = 'security' }) }
        )
        $Result = Invoke-IdentityScenario -Alerts $Alerts -Mode $Mode -IssueCandidates $Candidates
        $Comments = @($Result.Calls | Where-Object { $_[1] -eq 'comment' })
        $Comments | Should -HaveCount 1
        $Comments[0][2] | Should -BeExactly '42'
        $Body = $Comments[0][-1]
        $Comments[0] | Should -BeExactly @('issue', 'comment', '42', '--repo', 'example/repo', '--body', $Body)
        $Body | Should -Match '^Weekly scan update: 2 occurrences as of 2026-09-08\.'
        $Body | Should -Match '## Code Scanning Alert: Current recurrence description'
        $Body.Contains('**Rule:** `py/recurring-rule`') | Should -BeTrue
        $Body.Contains('**Occurrences:** 2 occurrences') | Should -BeTrue
        $Body.Contains('**Detection Date:** 2026-09-08') | Should -BeTrue
        $Body.Contains('**Workflow Run:** https://example.invalid/example/repo/actions/runs/fixture') | Should -BeTrue
        $Body | Should -Not -Match 'automation:security-scan:|### Action Required|old-path|alerts/90|old finding text|Human remediation notes'
        if ($ExpectedSeverity) { $Body.Contains("**Severity:** $ExpectedSeverity") | Should -BeTrue }
        else { $Body | Should -Not -Match '\*\*Severity:\*\*' }
        if ($Missing) {
            $Body | Should -Not -Match '\*\*Alert:\*\*|\bnull\b'
            $Body.Contains('See the linked alert for details.') | Should -BeTrue
        }
        else {
            $Body.Contains('**Alert:** https://example.invalid/alerts/501') | Should -BeTrue
            $Body.Contains($Message) | Should -BeTrue
        }
        if ($NoPath) {
            $Body.Contains('**Tool:** Scorecard') | Should -BeTrue
            $Body.Contains('### Repository configuration finding') | Should -BeTrue
            $Body.Contains('This alert refers to a repository-level configuration setting with no associated source file.') | Should -BeTrue
            $Body | Should -Not -Match '### Affected paths|no file associated with this alert|/blob/'
        }
        else {
            $Body.Contains('**Tool:** CodeQL') | Should -BeTrue
            $Body.Contains('- [src/file501.py](https://example.invalid/example/repo/blob/main/src/file501.py)') | Should -BeTrue
            $Body.Contains('- [src/file502.py](https://example.invalid/example/repo/blob/main/src/file502.py)') | Should -BeTrue
        }
        @($Result.Calls | Where-Object { $_[1] -eq 'create' }) | Should -HaveCount 0
        $Reopens = @($Result.Calls | Where-Object { $_[1] -eq 'reopen' })
        $Edits = @($Result.Calls | Where-Object { $_[1] -eq 'edit' })
        if ($State -eq 'CLOSED') {
            $Reopens | Should -HaveCount 1
            $Reopens[0] | Should -BeExactly @('issue', 'reopen', '42', '--repo', 'example/repo', '--comment', 'Reopened automatically because rule `py/recurring-rule` is present in the latest code scanning results.')
            $Edits | Should -HaveCount 1
            $Edits[0] | Should -BeExactly @('issue', 'edit', '42', '--repo', 'example/repo', '--add-label', 'needs-triage')
        }
        else {
            $Reopens | Should -HaveCount 0
            $Edits | Should -HaveCount 0
        }
        $Result.CloseSet | Should -HaveCount 1
        $Result.CloseSet[0].number | Should -Be 99
        $Closes = @($Result.Calls | Where-Object { $_[1] -eq 'close' })
        if ($Mode -eq 'enforce') {
            $Closes | Should -HaveCount 1
            $Closes[0][2] | Should -BeExactly '99'
        }
        else { $Closes | Should -HaveCount 0 }
    }
}

Describe 'New issue rendering compatibility' -Tag 'Unit' {
    It 'preserves the complete new body for <Kind>' -ForEach @(
        @{ Kind = 'file finding'; NoPath = $false }
        @{ Kind = 'configuration finding'; NoPath = $true }
    ) {
        $Alert = New-IdentityAlert -RuleId 'py/new-rule' -Number 501
        $Alert.rule.description = 'Current finding'
        $Alert.rule.security_severity_level = 'high'
        $Alert.most_recent_instance.message.text = 'Current diagnostic.'
        $ExpectedPaths = "### Affected paths`n`n- [src/file501.py](https://example.invalid/example/repo/blob/main/src/file501.py)"
        if ($NoPath) {
            $Alert.tool.name = 'Scorecard'
            $Alert.most_recent_instance.location.path = 'no file associated with this alert'
            $ExpectedPaths = "### Repository configuration finding`n`nThis alert refers to a repository-level configuration setting with no associated source file."
        }
        $ExpectedBody = @'
<!-- automation:security-scan:py/new-rule -->
## Code Scanning Alert: Current finding

**Rule:** `py/new-rule`
**Severity:** high
**Tool:** TOOL_NAME
**Occurrences:** 1 occurrence
**Alert:** https://example.invalid/alerts/501

### What was found
Current diagnostic.

PATHS_SECTION

---
**Detection Date:** 2026-09-08
**Workflow Run:** https://example.invalid/example/repo/actions/runs/fixture

### Action Required
- [ ] Review the alert and confirm it is not a false positive
- [ ] Remediate or dismiss the finding with a documented reason
- [ ] Close this issue after the fix is merged
'@
        $ExpectedBody = $ExpectedBody.Replace("`r`n", "`n").Replace('TOOL_NAME', $Alert.tool.name).Replace('PATHS_SECTION', $ExpectedPaths)
        $Result = Invoke-IdentityScenario -Alerts @($Alert) -Mode 'dry-run' -IssueCandidates @()

        $Result.Calls | Should -HaveCount 2
        $Result.Calls[1] | Should -BeExactly @('issue', 'create', '--repo', 'example/repo', '--title', '[Security][high] Current finding', '--label', 'security,automated,needs-triage', '--body', $ExpectedBody)
        $Result.CloseSet | Should -HaveCount 0
    }
}

Describe 'Ownership-filtered candidate quota in <Mode>' -Tag 'Unit' -ForEach @(
    @{ Mode = 'enforce' }
    @{ Mode = 'dry-run' }
) {
    BeforeEach {
        $script:QuotaLiveAlerts = @(New-IdentityAlert -RuleId 'js/rule-b' -Number 1; New-IdentityAlert -RuleId 'py/closed-rule' -Number 2)
        $script:QuotaOwned = @(
            New-QuotaIssue -Number 42 -Rule 'js/rule-b' -State 'OPEN'
            New-QuotaIssue -Number 43 -Rule 'py/closed-rule'
            New-QuotaIssue -Number 99 -Rule 'py/absent-rule' -State 'OPEN'
        )
    }

    It 'does not let 200 <Kind> issues crowd out owned trackers' -ForEach @(
        @{ Kind = 'wrong-author'; Author = 'fixture-user'; Labels = @('automated', 'security') }
        @{ Kind = 'missing-automated'; Author = 'app/github-actions'; Labels = @('security') }
        @{ Kind = 'missing-security'; Author = 'app/github-actions'; Labels = @('automated') }
    ) {
        $Noise = @(1..200 | ForEach-Object { New-QuotaIssue -Number (1000 + $_) -Author $Author -Labels $Labels -State $(if ($_ % 2) { 'OPEN' } else { 'CLOSED' }) })
        $Result = Invoke-IdentityScenario -Alerts $script:QuotaLiveAlerts -Mode $Mode -IssueCandidates ($Noise + $script:QuotaOwned) -EmulateQuery

        $Result.Truncated | Should -BeExactly 'false'
        $Result.CandidateCount | Should -Be 3
        $Result.Index.number | Should -Be @(42, 43, 99)
        @($Result.Calls | Where-Object { $_[1] -eq 'create' }) | Should -HaveCount 0
        @($Result.Calls | Where-Object { $_[1] -eq 'comment' }) | Should -HaveCount 2
        $Reopens = @($Result.Calls | Where-Object { $_[1] -eq 'reopen' })
        $Reopens | Should -HaveCount 1
        $Reopens[0][2] | Should -BeExactly '43'
        $Result.CloseSet.number | Should -Be 99
        $Closes = @($Result.Calls | Where-Object { $_[1] -eq 'close' })
        if ($Mode -eq 'enforce') { $Closes | Should -HaveCount 1; $Closes[0][2] | Should -BeExactly '99' }
        else { $Closes | Should -HaveCount 0 }
    }

    It 'handles <Count> eligible candidates conservatively' -ForEach @(
        @{ Count = 199 }
        @{ Count = 200 }
        @{ Count = 201 }
    ) {
        $Candidates = $script:QuotaOwned + @(1..($Count - 3) | ForEach-Object { New-QuotaIssue -Number (1000 + $_) })
        $Result = Invoke-IdentityScenario -Alerts $script:QuotaLiveAlerts -Mode $Mode -IssueCandidates $Candidates -EmulateQuery

        $Result.CandidateCount | Should -Be ([math]::Min($Count, 200))
        $Result.ExitCode | Should -Be 0
        $Result.ExecutedSteps | Should -Be 3
        if ($Count -ge 200) {
            $Result.Truncated | Should -BeExactly 'true'
            $Result.HasLiveFile | Should -BeFalse
            $Result.HasCloseSet | Should -BeFalse
            @($Result.Calls | Where-Object { $_[1] -ne 'list' }) | Should -HaveCount 0
            $Result.Output | Should -Match 'updates skipped because the issue index may be truncated'
            $Result.Output | Should -Match 'Reconciliation skipped because the issue index may be truncated'
        }
        else {
            $Result.Truncated | Should -BeExactly 'false'
            @($Result.Calls | Where-Object { $_[1] -eq 'comment' }) | Should -HaveCount 2
            @($Result.Calls | Where-Object { $_[1] -eq 'reopen' }) | Should -HaveCount 1
            $Result.CloseSet.number | Should -Be 99
        }
    }

    It 'allows creation when only unowned candidates exist' {
        $Noise = @(1..200 | ForEach-Object { New-QuotaIssue -Number (1000 + $_) -Author 'fixture-user' })
        $Result = Invoke-IdentityScenario -Alerts @($script:QuotaLiveAlerts[0]) -Mode $Mode -IssueCandidates $Noise -EmulateQuery

        $Result.Truncated | Should -BeExactly 'false'
        $Result.CandidateCount | Should -Be 0
        $Result.Calls | Should -HaveCount 2
        $Result.Calls[1][1] | Should -BeExactly 'create'
        $Result.CloseSet | Should -HaveCount 0
    }
}

Describe 'Local ownership remains authoritative' -Tag 'Unit' {
    It 'rejects unowned and malformed raw results even when the query is filtered' {
        $BadMarker = New-QuotaIssue -Number 104 -Rule 'js/rule-b'
        $BadMarker.body = "Prefixed text`n<!-- automation:security-scan:js/rule-b -->"
        $BadId = New-QuotaIssue -Number 105 -Rule 'js/rule-b'
        $BadId.body = '<!-- automation:security-scan:bad id -->'
        $Candidates = @(
            New-QuotaIssue -Number 101 -Rule 'js/rule-b' -Author 'fixture-user'
            New-QuotaIssue -Number 102 -Rule 'js/rule-b' -Labels @('security')
            New-QuotaIssue -Number 103 -Rule 'js/rule-b' -Labels @('automated')
            $BadMarker; $BadId
            New-QuotaIssue -Number 42 -Rule 'js/rule-b' -State 'OPEN'
        )
        $Result = Invoke-IdentityScenario -Alerts @(New-IdentityAlert -RuleId 'js/rule-b' -Number 1) -IssueCandidates $Candidates

        $Result.CandidateCount | Should -Be 6
        $Result.Index | Should -HaveCount 1
        $Result.Index[0].number | Should -Be 42
        $Result.Calls | Should -HaveCount 2
        $Result.Calls[1][0..4] | Should -BeExactly @('issue', 'comment', '42', '--repo', 'example/repo')
    }
}

Describe 'Skill and workflow candidate query contract' -Tag 'Unit' {
    It 'uses the same exact owned all-state query before limiting on both surfaces' {
        $WorkflowResult = Invoke-IdentityScenario -Alerts @() -Mode 'dry-run' -IssueCandidates @() -EmulateQuery
        $SkillResult = Invoke-SkillQuotaScenario -Candidates @()
        foreach ($Result in @($WorkflowResult, $SkillResult)) {
            $Result.Calls[0] | Should -BeExactly @('issue', 'list', '--repo', 'example/repo', '--search', '"automation:security-scan:" in:body author:app/github-actions label:automated label:security', '--state', 'all', '--limit', '200', '--json', 'number,state,body,author,labels')
        }
    }

    It 'finds an existing closed owner behind 200 unowned issues' {
        $Noise = @(1..200 | ForEach-Object { New-QuotaIssue -Number (1000 + $_) -Author 'fixture-user' })
        $Result = Invoke-SkillQuotaScenario -Candidates ($Noise + @(New-QuotaIssue -Number 42 -Rule 'js/rule-b'))

        $Result.ExitCode | Should -Be 0 -Because $Result.Output
        $Result.Calls | Should -HaveCount 1
    }

    It 'aborts before creation for <Count> eligible candidates' -ForEach @(
        @{ Count = 200 }
        @{ Count = 201 }
    ) {
        $Result = Invoke-SkillQuotaScenario -Candidates @(1..$Count | ForEach-Object { New-QuotaIssue -Number $_ })

        $Result.ExitCode | Should -Not -Be 0
        $Result.Calls | Should -HaveCount 1
        $Result.Output | Should -Match 'Candidate query reached its limit'
    }

    It 'creates below quota when no verified match exists' {
        $Result = Invoke-SkillQuotaScenario -Candidates @(1..199 | ForEach-Object { New-QuotaIssue -Number $_ })

        $Result.ExitCode | Should -Be 0 -Because $Result.Output
        $Result.Calls | Should -HaveCount 2
        $Result.Calls[1][1] | Should -BeExactly 'create'
    }

    It 'rejects ambiguous raw verified owners' {
        $Result = Invoke-SkillQuotaScenario -Candidates @(
            New-QuotaIssue -Number 42 -Rule 'js/rule-b'
            New-QuotaIssue -Number 43 -Rule 'js/rule-b'
        ) -RawResponse

        $Result.ExitCode | Should -Not -Be 0
        $Result.Calls | Should -HaveCount 1
        $Result.Output | Should -Match 'Multiple verified tracking issues'
    }

    It 'does not adopt unowned raw matches' {
        $Result = Invoke-SkillQuotaScenario -Candidates @(New-QuotaIssue -Number 42 -Rule 'js/rule-b' -Author 'fixture-user') -RawResponse

        $Result.ExitCode | Should -Be 0
        $Result.Calls | Should -HaveCount 2
        $Result.Calls[1][1] | Should -BeExactly 'create'
    }
}

AfterAll {
    if (-not $script:YamlWasLoaded) { Remove-Module powershell-yaml -ErrorAction SilentlyContinue }
}
