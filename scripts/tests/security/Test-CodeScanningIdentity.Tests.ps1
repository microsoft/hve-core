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
jq() { "$TEST_JQ_PATH" "$@"; }
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
        Feeds real collector output through indexing, updates and reconciliation without live calls.
        #>
        param(
            [AllowEmptyCollection()] [object[]]$Alerts,
            [string]$Mode = 'enforce',
            [string]$TrackedRule = 'js/rule-b'
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
        $Json | Set-Content (Join-Path $Directory 'alerts.json') -Encoding utf8NoBOM
        $Candidates = @(
            @{ number = 42; state = 'OPEN'; body = "<!-- automation:security-scan:$TrackedRule -->`nHuman content"; author = @{ login = 'app/github-actions' }; labels = @(@{ name = 'automated' }, @{ name = 'security' }) }
            @{ number = 99; state = 'OPEN'; body = '<!-- automation:security-scan:py/absent-rule -->'; author = @{ login = 'app/github-actions' }; labels = @(@{ name = 'automated' }, @{ name = 'security' }) }
        )
        ConvertTo-Json -InputObject $Candidates -Depth 10 | Set-Content (Join-Path $Directory 'candidates.json') -Encoding utf8NoBOM
        $Output = ''
        foreach ($Step in @($script:IndexStep, $script:UpdateStep, $script:ReconcileStep)) {
            $Result = Invoke-IdentityStep -Body $Step.run -Directory $Directory -Mode $Mode
            $Result.ExitCode | Should -Be 0 -Because $Result.Output
            $Output += $Result.Output
        }
        Get-Content (Join-Path $Directory 'index-output.txt') | Should -Contain 'truncated=false'
        $Calls = @(Get-Content (Join-Path $Directory 'gh-calls.jsonl') | ForEach-Object { , (ConvertFrom-Json $_ -NoEnumerate) })
        return @{
            Live = @(Get-Content (Join-Path $Directory 'live-rule-ids.json') -Raw | ConvertFrom-Json)
            CloseSet = @(Get-Content (Join-Path $Directory 'close-set.json') -Raw | ConvertFrom-Json)
            Calls = $Calls
            Output = $Output
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

AfterAll {
    if (-not $script:YamlWasLoaded) { Remove-Module powershell-yaml -ErrorAction SilentlyContinue }
}
