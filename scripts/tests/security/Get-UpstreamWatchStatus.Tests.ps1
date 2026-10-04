#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../security/Get-UpstreamWatchStatus.ps1')

    function script:Write-WatchesFile {
        param([Parameter(Mandatory)][string]$Yaml)
        $path = Join-Path $TestDrive "watches-$([guid]::NewGuid()).yml"
        Set-Content -LiteralPath $path -Value $Yaml -Encoding utf8
        return $path
    }

    $script:AllKinds = @'
watches:
  - id: poutine-permissions-fp
    kind: issue-closed
    url: https://github.com/boostsecurityio/poutine/issues/348
    issue: 3112
    action: Remove the poutine false-positive exception.
  - id: gh-aw-release
    kind: release-newer
    repo: github/gh-aw
    pinned: v0.89.21
    issue: 3112
    action: Recompile agentic workflows on the new release.
  - id: firewall-runner-repo-root-refs
    kind: runner-version
    label: ubuntu-24.04-firewall
    minimum: 2.336.0
    issue: 3112
    action: Switch firewall jobs to repository-root action references.
  - id: parser-env-context
    kind: probe-outcome
    probe: env-context
    baseline: fail
    issue: 3112
    action: Retire the custom env-context check.
'@

    function script:Read-Valid {
        param([string]$Yaml = $script:AllKinds)
        $read = Read-UpstreamWatch -Path (Write-WatchesFile $Yaml)
        $read.Errors | Should -BeNullOrEmpty
        return $read.Watches
    }
}

Describe 'Read-UpstreamWatch' -Tag 'Unit' {
    It 'accepts one watch of every kind' {
        @(Read-Valid).Count | Should -Be 4
    }

    It 'accepts the repository watches file as shipped' {
        $repoFile = Join-Path $PSScriptRoot '../../../security/upstream-watches.yml'
        $read = Read-UpstreamWatch -Path $repoFile
        $read.Errors | Should -BeNullOrEmpty
    }

    It 'rejects <Name>' -ForEach @(
        @{ Name = 'an unknown kind'; Yaml = "watches:`n  - id: a`n    kind: nope`n    issue: 1`n    action: x"; Pattern = "'kind' must be one of" }
        @{ Name = 'a missing kind field'; Yaml = "watches:`n  - id: a`n    kind: issue-closed`n    issue: 1`n    action: x"; Pattern = "missing required field 'url'" }
        @{ Name = 'a missing common field'; Yaml = "watches:`n  - id: a`n    kind: issue-closed`n    url: https://github.com/o/r/issues/1`n    issue: 1"; Pattern = "missing required field 'action'" }
        @{ Name = 'a field from another kind'; Yaml = "watches:`n  - id: a`n    kind: issue-closed`n    url: https://github.com/o/r/issues/1`n    label: x`n    issue: 1`n    action: x"; Pattern = "unknown field 'label'" }
        @{ Name = 'a non-kebab id'; Yaml = "watches:`n  - id: Bad_Id`n    kind: issue-closed`n    url: https://github.com/o/r/issues/1`n    issue: 1`n    action: x"; Pattern = 'kebab-case' }
        @{ Name = 'a non-GitHub url'; Yaml = "watches:`n  - id: a`n    kind: issue-closed`n    url: https://example.com/1`n    issue: 1`n    action: x"; Pattern = "'url' must be" }
        @{ Name = 'a bad repo'; Yaml = "watches:`n  - id: a`n    kind: release-newer`n    repo: nope`n    pinned: 1.0.0`n    issue: 1`n    action: x"; Pattern = "'repo' must be" }
        @{ Name = 'a bad minimum'; Yaml = "watches:`n  - id: a`n    kind: runner-version`n    label: ubuntu-24.04`n    minimum: latest`n    issue: 1`n    action: x"; Pattern = "'minimum' must be" }
        @{ Name = 'a bad baseline'; Yaml = "watches:`n  - id: a`n    kind: probe-outcome`n    probe: p`n    baseline: maybe`n    issue: 1`n    action: x"; Pattern = "'baseline' must be" }
        @{ Name = 'a bad issue'; Yaml = "watches:`n  - id: a`n    kind: issue-closed`n    url: https://github.com/o/r/issues/1`n    issue: none`n    action: x"; Pattern = "'issue' must be" }
        @{ Name = 'a duplicate id'; Yaml = "watches:`n  - id: a`n    kind: probe-outcome`n    probe: p`n    baseline: fail`n    issue: 1`n    action: x`n  - id: a`n    kind: probe-outcome`n    probe: q`n    baseline: fail`n    issue: 1`n    action: x"; Pattern = 'duplicates' }
        @{ Name = 'a file without a watches list'; Yaml = 'items: []'; Pattern = "'watches' list" }
    ) {
        $read = Read-UpstreamWatch -Path (Write-WatchesFile $Yaml)
        ($read.Errors -join ' ') | Should -Match $Pattern
    }
}

Describe 'Get-UpstreamWatchStatus' -Tag 'Unit' {
    It 'reports every watch unknown when nothing was observed' {
        $status = Get-UpstreamWatchStatus -Watches (Read-Valid)
        @($status.State | Sort-Object -Unique) | Should -Be @('unknown')
        @($status | Where-Object Triggered).Count | Should -Be 0
        $status[0].Marker | Should -Be 'automation:upstream-watch:poutine-permissions-fp'
    }

    It 'triggers every kind when its condition is met' {
        $status = Get-UpstreamWatchStatus -Watches (Read-Valid) `
            -IssueStates @{ 'https://github.com/boostsecurityio/poutine/issues/348' = 'closed' } `
            -LatestReleases @{ 'github/gh-aw' = 'v0.90.0' } `
            -RunnerVersions @{ 'ubuntu-24.04-firewall' = '2.336.0' } `
            -ProbeOutcomes @{ 'env-context' = 'pass' }
        @($status | Where-Object Triggered).Count | Should -Be 4
        ($status | Where-Object Id -EQ 'firewall-runner-repo-root-refs').Detail | Should -Be 'runner 2.336.0, minimum 2.336.0'
    }

    It 'waits when no condition is met' {
        $status = Get-UpstreamWatchStatus -Watches (Read-Valid) `
            -IssueStates @{ 'https://github.com/boostsecurityio/poutine/issues/348' = 'open' } `
            -LatestReleases @{ 'github/gh-aw' = 'v0.89.21' } `
            -RunnerVersions @{ 'ubuntu-24.04-firewall' = '2.331.0' } `
            -ProbeOutcomes @{ 'env-context' = 'fail' }
        @($status.State | Sort-Object -Unique) | Should -Be @('waiting')
    }

    It 'compares versions numerically, not as text' {
        $yaml = "watches:`n  - id: a`n    kind: release-newer`n    repo: o/r`n    pinned: 1.9.0`n    issue: 1`n    action: x"
        $status = Get-UpstreamWatchStatus -Watches (Read-Valid $yaml) -LatestReleases @{ 'o/r' = 'release-1.10.0' }
        $status[0].State | Should -Be 'triggered'
    }

    It 'reports an empty array for no watches' {
        $status = Get-UpstreamWatchStatus -Watches @()
        @($status).Count | Should -Be 0
    }
}

Describe 'Runner version helpers' -Tag 'Unit' {
    It 'reads the runner version from a job log' {
        $log = "2026-10-03T00:00:00.0000000Z Current runner version: '2.331.0'`n2026-10-03T00:00:01Z Runner name: 'GitHub Actions 1'"
        Get-RunnerVersionFromLog -LogText $log | Should -Be '2.331.0'
    }

    It 'returns null when the log has no version line' {
        Get-RunnerVersionFromLog -LogText 'no version here' | Should -BeNullOrEmpty
    }

    It 'reads the label from a probe job name, including a reusable-workflow prefix' {
        Get-RunnerProbeLabel -JobName 'GitHub Code Scanning / Runner probe (ubuntu-24.04-firewall)' | Should -Be 'ubuntu-24.04-firewall'
        Get-RunnerProbeLabel -JobName 'Fetch Code Scanning Alerts' | Should -BeNullOrEmpty
    }

    It 'collects versions only from successful probe jobs' {
        Mock gh {
            $global:LASTEXITCODE = 0
            $joined = $args -join ' '
            if ($joined -match '/runs/7/jobs') {
                '{"id":1,"name":"Scan / Runner probe (ubuntu-24.04-firewall)","conclusion":"success"}'
                '{"id":2,"name":"Scan / Runner probe (ubuntu-24.04)","conclusion":"failure"}'
                '{"id":3,"name":"Scan / Fetch Code Scanning Alerts","conclusion":"success"}'
            }
            elseif ($joined -match '/jobs/1/logs') { "Current runner version: '2.331.0'" }
            else { "Current runner version: '9.9.9'" }
        }
        $versions = Get-RunnerVersionObservation -Owner 'o' -Repo 'r' -RunId 7
        $versions.Keys.Count | Should -Be 1
        $versions['ubuntu-24.04-firewall'] | Should -Be '2.331.0'
    }

    It 'returns no versions when the job list cannot be read' {
        Mock gh { $global:LASTEXITCODE = 1 }
        $versions = Get-RunnerVersionObservation -Owner 'o' -Repo 'r' -RunId 7 -WarningAction SilentlyContinue
        $versions.Keys.Count | Should -Be 0
    }
}

Describe 'Get-WatchLookup' -Tag 'Unit' {
    It 'looks up each issue and release once' {
        Mock gh {
            $global:LASTEXITCODE = 0
            if (($args -join ' ') -match 'releases/latest') { 'v0.90.0' } else { 'closed' }
        }
        $watches = @(Read-Valid) + @(Read-Valid)[0]
        $lookup = Get-WatchLookup -Watches $watches
        $lookup.IssueStates['https://github.com/boostsecurityio/poutine/issues/348'] | Should -Be 'closed'
        $lookup.LatestReleases['github/gh-aw'] | Should -Be 'v0.90.0'
        Should -Invoke gh -Times 2 -Exactly
    }

    It 'marks failed lookups unknown or empty' {
        Mock gh { $global:LASTEXITCODE = 1 }
        $lookup = Get-WatchLookup -Watches (Read-Valid)
        $lookup.IssueStates['https://github.com/boostsecurityio/poutine/issues/348'] | Should -Be 'unknown'
        $lookup.LatestReleases['github/gh-aw'] | Should -Be ''
    }
}

Describe 'Runner probe jobs in gh-code-scanning.yml' -Tag 'Unit' {
    BeforeAll {
        Import-Module PowerShell-Yaml -ErrorAction Stop
        $root = Join-Path $PSScriptRoot '../../..'
        $script:Workflow = Get-Content -Raw (Join-Path $root '.github/workflows/gh-code-scanning.yml') | ConvertFrom-Yaml
        $read = Read-UpstreamWatch -Path (Join-Path $root 'security/upstream-watches.yml')
        $script:RunnerLabels = @($read.Watches | Where-Object { $_['kind'] -eq 'runner-version' } | ForEach-Object { [string]$_['label'] } | Sort-Object -Unique)
        $script:ProbeJobs = @($script:Workflow.jobs.GetEnumerator() | Where-Object { [string]$_.Value['name'] -match '^Runner probe \(' })
    }

    It 'gives every runner-version watch a static, permissionless probe job that the scan job waits for' {
        foreach ($label in $script:RunnerLabels) {
            $job = @($script:ProbeJobs | Where-Object { $_.Value['name'] -eq "Runner probe ($label)" })
            $job | Should -HaveCount 1 -Because "the runner-version watch on $label needs a probe job"
            $job[0].Value['runs-on'] | Should -BeExactly $label
            $job[0].Value['permissions'].Count | Should -Be 0
            @($script:Workflow.jobs['scan']['needs']) | Should -Contain $job[0].Key
        }
    }

    It 'has no probe job without a runner-version watch' {
        foreach ($job in $script:ProbeJobs) {
            (Get-RunnerProbeLabel -JobName $job.Value['name']) | Should -BeIn $script:RunnerLabels
        }
    }

    It 'keeps every runs-on value literal so the runner policy check can verify it' {
        foreach ($job in $script:Workflow.jobs.Values) {
            [string]$job['runs-on'] | Should -Not -Match '\$\{\{'
        }
    }
}
