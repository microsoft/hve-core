#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

# The issue-writing step runs under bash against a fake gh backed by a JSON
# issue store, so repeated runs observe the issues earlier runs filed.
$script:IssueStepBash = (Get-Command bash -CommandType Application -ErrorAction SilentlyContinue |
    Select-Object -First 1).Source
$script:SkipIssueStep = -not $script:IssueStepBash
if (-not $script:SkipIssueStep) {
    & $script:IssueStepBash -c 'command -v jq >/dev/null' 2>$null
    $script:SkipIssueStep = $LASTEXITCODE -ne 0
}

BeforeAll {
    Import-Module PowerShell-Yaml -ErrorAction Stop

    $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
    $script:IssueStepBash = (Get-Command bash -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1).Source
    $workflow = Get-Content -Raw -LiteralPath (Join-Path $script:RepoRoot '.github/workflows/create-gh-code-scanning-issues.yml') |
        ConvertFrom-Yaml
    $script:IssueStep = @($workflow['jobs']['create-gh-code-scanning-issues']['steps']) |
        Where-Object { $_['name'] -eq 'Create backlog issues for new findings' }

    $script:FakeGh = @'
#!/usr/bin/env bash
set -euo pipefail
store=./issues.json
[[ -f "$store" ]] || echo '[]' > "$store"
command="$1 $2"
shift 2
number=""
if [[ "$command" == "issue edit" || "$command" == "issue comment" ]]; then
  number="$1"
  shift
fi
title=""
body=""
while (($#)); do
  case "$1" in
    --title) title="$2"; shift 2 ;;
    --body) body="$2"; shift 2 ;;
    *) shift ;;
  esac
done
update() {
  jq "$@" "$store" > "$store.tmp"
  mv "$store.tmp" "$store"
}
case "$command" in
  "issue list")
    jq '[.[] | select(.state == "OPEN") | {number, body}]' "$store"
    ;;
  "issue create")
    next=$(( $(jq length "$store") + 1 ))
    update --argjson n "$next" --arg t "$title" --arg b "$body" \
      '. + [{number: $n, title: $t, body: $b, state: "OPEN", comments: 0}]'
    echo "https://github.com/microsoft/hve-core/issues/${next}"
    ;;
  "issue edit")
    update --argjson n "$number" --arg t "$title" --arg b "$body" \
      'map(if .number == $n then .title = $t | .body = $b else . end)'
    ;;
  "issue comment")
    update --argjson n "$number" 'map(if .number == $n then .comments += 1 else . end)'
    ;;
  *)
    echo "unexpected gh ${command}" >&2
    exit 1
    ;;
esac
'@

    function script:New-AlertGroup {
        param(
            [Parameter(Mandatory)] [string]$Tool,
            [Parameter(Mandatory)] [int]$Count,
            [string]$RuleId = 'shared/rule'
        )

        return [ordered]@{
            RuleDescription    = 'Shared rule'
            RuleId             = $RuleId
            Tool               = $Tool
            SecuritySeverity   = 'high'
            Severity           = 'error'
            Count              = $Count
            AffectedPaths      = @("src/$Tool.js")
            HasFilePaths       = $true
            AlertUrl           = "https://github.com/microsoft/hve-core/security/code-scanning/$Count"
            FindingDescription = "$Tool finding"
        }
    }

    function script:New-IssueFixture {
        param([object[]]$Issues = @())

        $fixture = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString('n'))
        New-Item -ItemType Directory -Path (Join-Path $fixture 'bin') -Force | Out-Null
        $utf8 = [Text.UTF8Encoding]::new($false)
        [IO.File]::WriteAllText((Join-Path $fixture 'bin/gh'), ($script:FakeGh -replace "`r`n", "`n"), $utf8)
        [IO.File]::WriteAllText((Join-Path $fixture 'step.sh'),
            ([string]$script:IssueStep['run'] -replace "`r?`n", "`n"), $utf8)
        [IO.File]::WriteAllText((Join-Path $fixture 'issues.json'), (ConvertTo-Json -InputObject @($Issues) -Depth 5), $utf8)
        return $fixture
    }

    function script:Invoke-IssueStep {
        param(
            [Parameter(Mandatory)] [string]$Fixture,
            [Parameter(Mandatory)] [object[]]$Alerts
        )

        $utf8 = [Text.UTF8Encoding]::new($false)
        [IO.File]::WriteAllText((Join-Path $Fixture 'alerts.json'), (ConvertTo-Json -InputObject @($Alerts) -Depth 5), $utf8)
        Push-Location -LiteralPath $Fixture
        try {
            $env:OWNER = 'microsoft'
            $env:REPO = 'hve-core'
            $env:GITHUB_SERVER_URL = 'https://github.com'
            $env:GITHUB_REPOSITORY = 'microsoft/hve-core'
            $env:GITHUB_RUN_ID = '42'
            $env:LIFECYCLE_URL = 'https://github.com/microsoft/hve-core/blob/main/docs/security/code-scanning-alert-lifecycle.md'
            & $script:IssueStepBash -c 'chmod +x ./bin/gh && export PATH="$PWD/bin:$PATH" && bash ./step.sh' 2>&1 | Out-Null
            $LASTEXITCODE | Should -Be 0
            return @(Get-Content -LiteralPath (Join-Path $Fixture 'issues.json') -Raw | ConvertFrom-Json)
        } finally {
            Pop-Location
            foreach ($name in 'OWNER', 'REPO', 'GITHUB_SERVER_URL', 'GITHUB_REPOSITORY', 'GITHUB_RUN_ID', 'LIFECYCLE_URL') {
                Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
            }
        }
    }

    function script:Get-IssueForTool {
        param(
            [Parameter(Mandatory)] [object[]]$Issues,
            [Parameter(Mandatory)] [string]$Tool
        )

        return @($Issues | Where-Object { $_.body -match "(?m)^\*\*Tool:\*\* $([regex]::Escape($Tool))$" })
    }
}

Describe 'Code scanning issue writer' -Tag 'Unit' {
    It 'finds the issue-writing step' {
        $script:IssueStep | Should -Not -BeNullOrEmpty
    }

    It 'keeps one issue per tool when tools share a rule ID across repeated runs' -Skip:$script:SkipIssueStep {
        $fixture = New-IssueFixture
        try {
            $alerts = @((New-AlertGroup -Tool 'CodeQL' -Count 2), (New-AlertGroup -Tool 'zizmor' -Count 1))
            $null = Invoke-IssueStep -Fixture $fixture -Alerts $alerts
            $issues = Invoke-IssueStep -Fixture $fixture -Alerts $alerts

            $issues.Count | Should -Be 2
            foreach ($expected in @(@{ Tool = 'CodeQL'; Count = 2 }, @{ Tool = 'zizmor'; Count = 1 })) {
                $match = Get-IssueForTool -Issues $issues -Tool $expected.Tool
                $match.Count | Should -Be 1
                $match[0].body | Should -Match ([regex]::Escape("<!-- automation:security-scan:$($expected.Tool):shared/rule -->"))
                $match[0].body | Should -Match "\*\*Occurrences:\*\* $($expected.Count) occurrence"
                $match[0].comments | Should -Be 1
            }
        } finally {
            Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'reuses a rule-only issue only for the tool it records and migrates its marker' -Skip:$script:SkipIssueStep {
        $legacy = [ordered]@{
            number   = 1
            title    = '[Security][high] Shared rule'
            body     = "<!-- automation:security-scan:shared/rule -->`n## Code Scanning Alert: Shared rule`n`n**Tool:** zizmor`n**Occurrences:** 4 occurrences"
            state    = 'OPEN'
            comments = 0
        }
        $fixture = New-IssueFixture -Issues @($legacy)
        try {
            $alerts = @((New-AlertGroup -Tool 'CodeQL' -Count 2), (New-AlertGroup -Tool 'zizmor' -Count 1))
            $null = Invoke-IssueStep -Fixture $fixture -Alerts $alerts
            $issues = Invoke-IssueStep -Fixture $fixture -Alerts $alerts

            $issues.Count | Should -Be 2
            $zizmor = Get-IssueForTool -Issues $issues -Tool 'zizmor'
            $zizmor.Count | Should -Be 1
            $zizmor[0].number | Should -Be 1
            $zizmor[0].body | Should -Match ([regex]::Escape('<!-- automation:security-scan:zizmor:shared/rule -->'))
            $zizmor[0].body | Should -Not -Match ([regex]::Escape('<!-- automation:security-scan:shared/rule -->'))
            $codeql = Get-IssueForTool -Issues $issues -Tool 'CodeQL'
            $codeql.Count | Should -Be 1
            $codeql[0].number | Should -Be 2
        } finally {
            Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'keeps open and dismissed issues for the same tool and rule separate' -Skip:$script:SkipIssueStep {
        $fixture = New-IssueFixture
        try {
            $dismissed = New-AlertGroup -Tool 'CodeQL' -Count 1
            $dismissed['Kind'] = 'dismissed-still-detected'
            $dismissed['DismissedReason'] = 'false positive'
            $alerts = @((New-AlertGroup -Tool 'CodeQL' -Count 2), $dismissed)
            $null = Invoke-IssueStep -Fixture $fixture -Alerts $alerts
            $issues = Invoke-IssueStep -Fixture $fixture -Alerts $alerts

            $issues.Count | Should -Be 2
            @($issues | Where-Object { $_.body -match [regex]::Escape('<!-- automation:security-scan:CodeQL:shared/rule -->') }).Count | Should -Be 1
            @($issues | Where-Object { $_.body -match [regex]::Escape('<!-- automation:security-scan-dismissed:CodeQL:shared/rule -->') }).Count | Should -Be 1
        } finally {
            Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
