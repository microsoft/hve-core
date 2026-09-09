#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $script:YamlWasLoaded = $null -ne (Get-Module powershell-yaml)
    Import-Module powershell-yaml -ErrorAction Stop
    $script:Workflow = Get-Content (Join-Path $script:RepoRoot '.github/workflows/create-gh-code-scanning-issues.yml') -Raw | ConvertFrom-Yaml
    $script:CodeQL = Get-Content (Join-Path $script:RepoRoot '.github/workflows/codeql-analysis.yml') -Raw | ConvertFrom-Yaml
    $Steps = $script:Workflow.jobs.'create-gh-code-scanning-issues'.steps
    $script:HealthStep = @($Steps | Where-Object id -EQ 'scan-health')[0]
    $script:ReconcileStep = @($Steps | Where-Object name -EQ 'Reconcile code scanning issues')[0]
    $script:BashPath = if ($env:CODE_SCANNING_TEST_BASH) { $env:CODE_SCANNING_TEST_BASH } else { (Get-Command bash -ErrorAction Stop).Source }
    $script:JqPath = if ($env:CODE_SCANNING_TEST_JQ) { $env:CODE_SCANNING_TEST_JQ } else { (Get-Command jq -ErrorAction Stop).Source }

    function New-TestAnalysis {
        <# .SYNOPSIS
        Creates synthetic CodeQL analysis metadata with explicit success evidence.
        #>
        param(
            [string]$Category = '/language:python',
            [string]$CreatedAt = '2026-09-07T04:00:00Z',
            [AllowEmptyString()] [string]$ErrorText = '',
            [int]$Id = 203
        )

        return @{ id = $Id; category = $Category; created_at = $CreatedAt; error = $ErrorText }
    }

    function Invoke-TestBash {
        <# .SYNOPSIS
        Runs a workflow step with only runtime essentials and synthetic test environment values.
        #>
        param(
            [string]$Body,
            [string]$Directory,
            [hashtable]$Environment
        )

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
        $StartInfo.Environment['PATH'] = '/usr/bin:/bin'
        $StartInfo.Environment['HOME'] = $Directory.Replace('\', '/')
        $StartInfo.Environment['GH_CONFIG_DIR'] = $Directory.Replace('\', '/')
        $StartInfo.Environment['TEST_JQ_PATH'] = $script:JqPath.Replace('\', '/')
        foreach ($Name in $Environment.Keys) {
            $StartInfo.Environment[$Name] = [string]$Environment[$Name]
        }
        # A file preserves Bash/jq quoting across Windows native command-line parsing.
        $ScriptPath = Join-Path $Directory 'step.sh'
        [System.IO.File]::WriteAllText($ScriptPath, $Body.Replace("`r`n", "`n") + "`n")
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
                throw 'Offline CodeQL workflow step exceeded 30 seconds.'
            }
            return @{
                ExitCode = $Process.ExitCode
                Stdout = $Stdout.GetAwaiter().GetResult()
                Stderr = $Stderr.GetAwaiter().GetResult()
            }
        }
        finally {
            $Process.Dispose()
        }
    }

    $script:MockPrefix = @'
jq() { "$TEST_JQ_PATH" "$@"; }
gh() {
  printf '%s\n' "$*" >> gh-calls.txt
  case "$1 $2" in
    "api "*)
      [[ "$TEST_API_FAILURE" != "true" ]] || return 1
      cat analyses.json ;;
    "issue close") printf '%s\n' "$3" >> closes.txt ;;
    *) printf 'Unexpected gh call in offline test\n' >&2; return 97 ;;
  esac
}
date() {
  case "$*" in
    "-u -d 10 days ago +%Y-%m-%dT%H:%M:%SZ") printf '%s\n' '2026-08-29T00:00:00Z' ;;
    *) printf 'Unexpected date call in offline test\n' >&2; return 96 ;;
  esac
}
readonly -f jq gh date
'@

    function Invoke-HealthScenario {
        <# .SYNOPSIS
        Feeds an actual health-step verdict into actual reconciliation with a synthetic absent-rule tracker.
        #>
        param(
            [AllowEmptyCollection()] [object[]]$Analyses = $script:Healthy,
            [AllowEmptyString()] [string]$Response,
            [AllowEmptyString()] [string]$ExpectedCategories = $script:HealthStep.env.EXPECTED_CODEQL_CATEGORIES,
            [string]$Mode = 'enforce',
            [switch]$ApiFailure
        )

        $Directory = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $Directory
        $Payload = if ($PSBoundParameters.ContainsKey('Response')) { $Response } else { ConvertTo-Json -InputObject (, $Analyses) -Depth 10 -Compress }
        $Payload | Set-Content (Join-Path $Directory 'analyses.json') -Encoding utf8NoBOM
        '[]' | Set-Content (Join-Path $Directory 'alerts.json') -Encoding utf8NoBOM
        '[]' | Set-Content (Join-Path $Directory 'live-rule-ids.json') -Encoding utf8NoBOM
        '[{"number":42,"state":"open","rule":"py/absent-rule"}]' | Set-Content (Join-Path $Directory 'issue-index.json') -Encoding utf8NoBOM
        foreach ($Name in @('health-output.txt', 'gh-calls.txt', 'closes.txt')) {
            [System.IO.File]::WriteAllText((Join-Path $Directory $Name), '')
        }
        $Environment = @{
            OWNER = 'example'; REPO = 'repo'; DEFAULT_BRANCH = 'main'
            GITHUB_SERVER_URL = 'https://example.invalid'; GITHUB_REPOSITORY = 'example/repo'
            GITHUB_RUN_ID = 'fixture'; GITHUB_OUTPUT = 'health-output.txt'
            EXPECTED_CODEQL_CATEGORIES = $ExpectedCategories
            TEST_API_FAILURE = $ApiFailure.IsPresent.ToString().ToLowerInvariant()
            INDEX_TRUNCATED = 'false'; RECONCILE_MODE = $Mode
        }
        $Health = Invoke-TestBash -Body ($script:MockPrefix + "`n" + $script:HealthStep.run) -Directory $Directory -Environment $Environment
        $Health.ExitCode | Should -Be 0 -Because ($Health.Stdout + $Health.Stderr)
        $Outputs = @{}
        foreach ($Line in Get-Content (Join-Path $Directory 'health-output.txt')) {
            $Parts = $Line.Split('=', 2)
            if ($Parts.Count -eq 2) { $Outputs[$Parts[0]] = $Parts[1] }
        }
        $Environment.SCAN_HEALTH_VERDICT = $Outputs.verdict
        $Environment.FAILING_ANALYSIS = $Outputs.'failing-analysis'
        $Reconcile = Invoke-TestBash -Body ($script:MockPrefix + "`n" + $script:ReconcileStep.run) -Directory $Directory -Environment $Environment
        return @{
            Verdict = $Outputs.verdict
            FailingAnalysis = $Outputs.'failing-analysis'
            ExitCode = $Reconcile.ExitCode
            Closes = @(Get-Content (Join-Path $Directory 'closes.txt'))
            Calls = @(Get-Content (Join-Path $Directory 'gh-calls.txt'))
            Output = $Health.Stdout + $Health.Stderr + $Reconcile.Stdout + $Reconcile.Stderr
        }
    }

    $script:Healthy = @(
        New-TestAnalysis -Category '/language:actions' -Id 201
        New-TestAnalysis -Category '/language:python' -Id 203
        New-TestAnalysis -Category '/language:javascript-typescript' -Id 205
    )
}

Describe 'CodeQL health configuration contract' -Tag 'Unit' {
    It 'requires exactly the categories emitted by the configured matrix and template' {
        $script:HealthStep.env.EXPECTED_CODEQL_CATEGORIES | Should -Not -BeNullOrEmpty
        $Declared = @($script:HealthStep.env.EXPECTED_CODEQL_CATEGORIES | ConvertFrom-Json)
        $Template = @($script:CodeQL.jobs.analyze.steps | Where-Object name -EQ 'Perform CodeQL Analysis')[0].with.category
        $Expected = @($script:CodeQL.jobs.analyze.strategy.matrix.language | ForEach-Object {
            $Template.Replace('${{ matrix.language }}', $_)
        })
        ($Declared | Sort-Object) | Should -Be ($Expected | Sort-Object)
        $Declared.Count | Should -Be @($Declared | Select-Object -Unique).Count
    }

    It 'retains the closure dry-run default' {
        $script:Workflow.on.workflow_call.inputs.'reconcile-mode'.default | Should -BeExactly 'dry-run'
    }
}

Describe 'CodeQL complete-category health gate' -Tag 'Unit' {
    It 'permits a synthetic enforce close only with all configured categories healthy' {
        $Result = Invoke-HealthScenario
        $Result.Verdict | Should -BeExactly 'healthy' -Because $Result.Output
        $Result.ExitCode | Should -Be 0
        $Result.Closes | Should -Be @('42')
        $Result.Calls[0] | Should -BeExactly 'api --paginate --slurp repos/example/repo/code-scanning/analyses?ref=refs/heads/main&tool_name=CodeQL&per_page=100'
    }

    It 'never closes in dry-run even with healthy evidence' {
        $Result = Invoke-HealthScenario -Mode 'dry-run'
        $Result.Verdict | Should -BeExactly 'healthy'
        $Result.ExitCode | Should -Be 0
        $Result.Closes | Should -HaveCount 0
        $Result.Output | Should -Match 'Dry run: would close issue #42'
    }

    It 'blocks closure when <Category> is missing' -ForEach @(
        @{ Category = '/language:actions' }
        @{ Category = '/language:python' }
        @{ Category = '/language:javascript-typescript' }
    ) {
        $Result = Invoke-HealthScenario -Analyses @($script:Healthy | Where-Object category -NE $Category)
        $Result.Verdict | Should -BeExactly 'incomplete-analysis'
        $Result.ExitCode | Should -Be 0
        $Result.Closes | Should -HaveCount 0
    }

    It 'blocks closure for stale <Category> evidence with error <ErrorText>' -ForEach @(
        @{ Category = '/language:actions'; ErrorText = '' }
        @{ Category = '/language:python'; ErrorText = '' }
        @{ Category = '/language:javascript-typescript'; ErrorText = '' }
        @{ Category = '/language:python'; ErrorText = 'failed' }
    ) {
        $Analyses = @($script:Healthy | Where-Object category -NE $Category) + @(New-TestAnalysis -Category $Category -CreatedAt '2026-08-28T23:59:59Z' -ErrorText $ErrorText)
        $Result = Invoke-HealthScenario -Analyses $Analyses
        $Result.Verdict | Should -BeExactly 'incomplete-analysis'
        $Result.Closes | Should -HaveCount 0
    }

    It 'keeps no-analysis evidence distinct for response <Response>' -ForEach @(
        @{ Response = '[]' }
        @{ Response = '[[]]' }
        @{ Response = '[[],[]]' }
    ) {
        $Result = Invoke-HealthScenario -Response $Response
        $Result.Verdict | Should -BeExactly 'no-analysis-in-window'
        $Result.ExitCode | Should -Be 0
        $Result.Closes | Should -HaveCount 0
    }

    It 'blocks closure when all categories are stale' {
        $Analyses = @($script:Healthy | ForEach-Object { New-TestAnalysis -Category $_.category -CreatedAt '2026-08-28T23:59:59Z' })
        $Result = Invoke-HealthScenario -Analyses $Analyses
        $Result.Verdict | Should -BeExactly 'no-analysis-in-window'
        $Result.Closes | Should -HaveCount 0
    }

    It 'accepts the inclusive cutoff but rejects one second before it' -ForEach @(
        @{ Time = '2026-08-29T00:00:00Z'; Verdict = 'healthy'; CloseCount = 1 }
        @{ Time = '2026-08-28T23:59:59Z'; Verdict = 'incomplete-analysis'; CloseCount = 0 }
    ) {
        $Analyses = @($script:Healthy | Where-Object category -NE '/language:python') + @(New-TestAnalysis -CreatedAt $Time)
        $Result = Invoke-HealthScenario -Analyses $Analyses
        $Result.Verdict | Should -BeExactly $Verdict
        $Result.Closes | Should -HaveCount $CloseCount
    }

    It 'fails reconciliation for a latest error and identifies the failed analysis' {
        $Result = Invoke-HealthScenario -Analyses ($script:Healthy + @(New-TestAnalysis -CreatedAt '2026-09-08T04:00:00Z' -ErrorText 'failed' -Id 999))
        $Result.Verdict | Should -BeExactly 'analysis-error'
        $Result.FailingAnalysis | Should -BeExactly '999'
        $Result.ExitCode | Should -Be 1
        $Result.Closes | Should -HaveCount 0
    }

    It 'lets newer success supersede an older error across pages in either order <Reverse>' -ForEach @(
        @{ Reverse = $false }
        @{ Reverse = $true }
    ) {
        $Pages = @(@(New-TestAnalysis -CreatedAt '2026-09-01T04:00:00Z' -ErrorText 'failed'), $script:Healthy)
        if ($Reverse) { [array]::Reverse($Pages) }
        $Result = Invoke-HealthScenario -Response (ConvertTo-Json -InputObject $Pages -Depth 10 -Compress)
        $Result.Verdict | Should -BeExactly 'healthy'
        $Result.Closes | Should -Be @('42')
    }

    It 'does not hide errors tied at the latest timestamp in either order <Reverse>' -ForEach @(
        @{ Reverse = $false }
        @{ Reverse = $true }
    ) {
        $Analyses = $script:Healthy + @(New-TestAnalysis -ErrorText 'failed' -Id 999)
        if ($Reverse) { [array]::Reverse($Analyses) }
        $Result = Invoke-HealthScenario -Analyses $Analyses
        $Result.Verdict | Should -BeExactly 'analysis-error'
        $Result.Closes | Should -HaveCount 0
    }

    It 'does not count an unrelated category as missing Python coverage' {
        $Analyses = @($script:Healthy | Where-Object category -NE '/language:python') + @(New-TestAnalysis -Category '/language:other')
        $Result = Invoke-HealthScenario -Analyses $Analyses
        $Result.Verdict | Should -BeExactly 'incomplete-analysis'
        $Result.Closes | Should -HaveCount 0
    }

    It 'does not require an old category outside the current configuration' {
        $Result = Invoke-HealthScenario -Analyses ($script:Healthy + @(New-TestAnalysis -Category '/language:removed' -CreatedAt '2026-08-01T00:00:00Z' -ErrorText 'failed'))
        $Result.Verdict | Should -BeExactly 'healthy'
        $Result.Closes | Should -Be @('42')
    }
}

Describe 'CodeQL unclassifiable evidence' -Tag 'Unit' {
    It 'skips closure on API failure' {
        $Result = Invoke-HealthScenario -ApiFailure
        $Result.Verdict | Should -BeExactly 'probe-failed'
        $Result.ExitCode | Should -Be 0
        $Result.Closes | Should -HaveCount 0
    }

    It 'rejects malformed response <Response>' -ForEach @(
        @{ Response = '' }
        @{ Response = '[' }
        @{ Response = '{}' }
        @{ Response = '[{}]' }
        @{ Response = '[null]' }
        @{ Response = '[[null]]' }
        @{ Response = '[[{}]]' }
        @{ Response = '[] []' }
    ) {
        $Result = Invoke-HealthScenario -Response $Response
        $Result.Verdict | Should -BeExactly 'probe-failed'
        $Result.Closes | Should -HaveCount 0
    }

    It 'rejects <Field> classification metadata <Value>' -ForEach @(
        @{ Field = 'category'; Value = $null }
        @{ Field = 'category'; Value = '' }
        @{ Field = 'category'; Value = 3 }
        @{ Field = 'created_at'; Value = $null }
        @{ Field = 'created_at'; Value = 'not-a-date' }
        @{ Field = 'created_at'; Value = '2026-02-31T00:00:00Z' }
        @{ Field = 'created_at'; Value = '9999-99-99T99:99:99Z' }
        @{ Field = 'error'; Value = $null }
        @{ Field = 'error'; Value = @() }
        @{ Field = 'id'; Value = '203' }
        @{ Field = 'id'; Value = $null }
    ) {
        $Malformed = New-TestAnalysis
        $Malformed[$Field] = $Value
        $Analyses = @($script:Healthy | Where-Object category -NE '/language:python') + @($Malformed)
        $Result = Invoke-HealthScenario -Analyses $Analyses
        $Result.Verdict | Should -BeExactly 'probe-failed'
        $Result.Closes | Should -HaveCount 0
    }

    It 'rejects missing error evidence rather than assuming success' {
        $Malformed = New-TestAnalysis
        $Malformed.Remove('error')
        $Analyses = @($script:Healthy | Where-Object category -NE '/language:python') + @($Malformed)
        $Result = Invoke-HealthScenario -Analyses $Analyses
        $Result.Verdict | Should -BeExactly 'probe-failed'
        $Result.Closes | Should -HaveCount 0
    }

    It 'rejects invalid expected categories <Expected>' -ForEach @(
        @{ Expected = '' }
        @{ Expected = '[]' }
        @{ Expected = 'null' }
        @{ Expected = '[1]' }
        @{ Expected = '[""]' }
        @{ Expected = '["/language:python","/language:python"]' }
    ) {
        $Result = Invoke-HealthScenario -ExpectedCategories $Expected
        $Result.Verdict | Should -BeExactly 'probe-failed'
        $Result.Closes | Should -HaveCount 0
    }
}

AfterAll {
    if (-not $script:YamlWasLoaded) {
        Remove-Module powershell-yaml -ErrorAction SilentlyContinue
    }
}