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
        param([string]$Body, [string]$Directory, [string]$Mode)

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
    "issue list") cat candidates.json ;;
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
            [switch]$ExpectRejection
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
        ConvertTo-Json -InputObject $Candidates -Depth 10 | Set-Content (Join-Path $Directory 'candidates.json') -Encoding utf8NoBOM
        $Output = ''
        $ExecutedSteps = 0
        foreach ($Step in @($script:IndexStep, $script:UpdateStep, $script:ReconcileStep)) {
            $Result = Invoke-IdentityStep -Body $Step.run -Directory $Directory -Mode $Mode
            $ExecutedSteps++
            $Output += $Result.Output
            if (-not $ExpectRejection -or $Step -eq $script:IndexStep) {
                $Result.ExitCode | Should -Be 0 -Because $Result.Output
            }
            if ($Result.ExitCode -ne 0) { break }
        }
        Get-Content (Join-Path $Directory 'index-output.txt') | Should -Contain 'truncated=false'
        $Calls = @(Get-Content (Join-Path $Directory 'gh-calls.jsonl') | ForEach-Object { , (ConvertFrom-Json $_ -NoEnumerate) })
        return @{
            Live = $(if (-not $ExpectRejection) { @(Get-Content (Join-Path $Directory 'live-rule-ids.json') -Raw | ConvertFrom-Json) })
            CloseSet = $(if (-not $ExpectRejection) { @(Get-Content (Join-Path $Directory 'close-set.json') -Raw | ConvertFrom-Json) })
            Calls = $Calls
            Output = $Output
            ExitCode = $Result.ExitCode
            ExecutedSteps = $ExecutedSteps
        }
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

AfterAll {
    if (-not $script:YamlWasLoaded) { Remove-Module powershell-yaml -ErrorAction SilentlyContinue }
}
