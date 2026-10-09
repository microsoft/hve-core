#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

# Discovery-time state: -ForEach reads these before BeforeAll runs.
$RepoRoot = Join-Path $PSScriptRoot '../../..'
$WorkflowFiles = @(Get-ChildItem -Path (Join-Path $RepoRoot '.github/workflows') -Filter '*.yml' |
        Where-Object { $_.Name -notmatch '\.lock\.yml$' -and $_.Name -ne 'agentics-maintenance.yml' })

# Release app installation grants contents: write, pull-requests: write, and
# metadata: read. Each release job requests only the subset it uses.
$ReleaseTokenScopes = @(
    foreach ($Workflow in 'release-prerelease-prepare.yml', 'release-stable.yml') {
        @{ Workflow = $Workflow; Job = 'prepare-promotion'; Scopes = @{ 'permission-contents' = 'write' } }
        @{ Workflow = $Workflow; Job = 'open-promotion-pr'; Scopes = @{ 'permission-contents' = 'read'; 'permission-pull-requests' = 'write' } }
    }
    foreach ($Workflow in 'release-prerelease.yml', 'release-stable-publish.yml') {
        @{ Workflow = $Workflow; Job = 'release-please'; Scopes = @{ 'permission-contents' = 'write'; 'permission-pull-requests' = 'write' } }
        @{ Workflow = $Workflow; Job = 'sync-release-pr'; Scopes = @{ 'permission-contents' = 'write' } }
    }
)

BeforeAll {
    Import-Module PowerShell-Yaml -ErrorAction Stop

    function Get-AppTokenStep {
        param([Parameter(Mandatory)][string]$Path)

        $document = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Yaml
        foreach ($job in $document['jobs'].GetEnumerator()) {
            foreach ($step in @($job.Value['steps'])) {
                if ($step -is [System.Collections.IDictionary] -and "$($step['uses'])" -match '^actions/create-github-app-token@') {
                    [pscustomobject]@{ Job = $job.Key; With = $step['with'] }
                }
            }
        }
    }
}

Describe 'GitHub App installation tokens' -Tag 'Unit' {
    It 'Requests explicit permissions and keeps revocation in <_.Name>' -ForEach $WorkflowFiles {
        foreach ($token in @(Get-AppTokenStep -Path $_.FullName)) {
            $permissions = @($token.With.Keys | Where-Object { $_ -like 'permission-*' })
            $permissions | Should -Not -BeNullOrEmpty -Because "job '$($token.Job)' must not inherit every installation permission"
            $token.With.Keys | Should -Not -Contain 'skip-token-revoke'
            if ($token.With.Contains('owner')) {
                $token.With.Keys | Should -Contain 'repositories' -Because "an owner without repositories grants every repository in the installation"
            }
        }
    }

    It 'Scopes the <Job> token in <Workflow> to exactly the permissions it uses' -ForEach $ReleaseTokenScopes {
        $tokens = @(Get-AppTokenStep -Path (Join-Path $RepoRoot ".github/workflows/$Workflow") | Where-Object Job -EQ $Job)
        $tokens | Should -HaveCount 1
        $actual = @{}
        foreach ($key in $tokens[0].With.Keys | Where-Object { $_ -like 'permission-*' }) { $actual[$key] = [string]$tokens[0].With[$key] }
        ($actual.Keys | Sort-Object) | Should -Be ($Scopes.Keys | Sort-Object)
        foreach ($key in $Scopes.Keys) { $actual[$key] | Should -BeExactly $Scopes[$key] }
    }

    It 'Hands the promotion push token only to the push step in <_>' -ForEach @('release-prerelease-prepare.yml', 'release-stable.yml') {
        $document = Get-Content -Raw -LiteralPath (Join-Path $RepoRoot ".github/workflows/$_") | ConvertFrom-Yaml
        $steps = @($document['jobs']['prepare-promotion']['steps'])
        $consumers = @($steps | Where-Object { ($_ | ConvertTo-Json -Depth 6 -Compress) -match 'steps\.app-token\.outputs\.token' } | ForEach-Object { $_['name'] })
        $consumers | Should -Be @('Push the promotion head')
        $checkout = $steps | Where-Object { $_['name'] -eq 'Checkout promotion working tree' }
        $checkout['with']['persist-credentials'] | Should -BeFalse
        $checkout['with'].Contains('token') | Should -BeFalse
    }
}

Describe 'Release app key governance' -Tag 'Unit' {
    # The key is a release-governance environment secret. The environment admits
    # only main, the release branches, and release tags, so a job reads the key
    # only when it runs on one of those refs.
    It 'Reads RELEASE_APP_PRIVATE_KEY only from release-governance in <_.Name>' -ForEach $WorkflowFiles {
        $document = Get-Content -Raw -LiteralPath $_.FullName | ConvertFrom-Yaml
        foreach ($job in $document['jobs'].GetEnumerator()) {
            if (($job.Value | ConvertTo-Json -Depth 12 -Compress) -notmatch 'secrets\.RELEASE_APP_PRIVATE_KEY') { continue }
            $environment = $job.Value['environment']
            # The signer's authorization records a deployment per signing as an
            # audit trail; every other key-reading job skips deployment records.
            if ($_.Name -eq 'extension-provenance-signer.yml' -and $job.Key -eq 'authorize') {
                [string]$environment | Should -BeExactly 'release-governance'
                continue
            }
            $environment | Should -BeOfType [System.Collections.IDictionary] -Because "job '$($job.Key)' reads the release app key"
            [string]$environment['name'] | Should -BeExactly 'release-governance'
            $environment['deployment'] | Should -BeFalse
        }
    }

    It 'Starts no key-reading workflow from a pull request event in <_.Name>' -ForEach $WorkflowFiles {
        $text = Get-Content -Raw -LiteralPath $_.FullName
        if ($text -notmatch 'secrets\.RELEASE_APP_PRIVATE_KEY') { return }
        $document = $text | ConvertFrom-Yaml
        $document['on'].Keys | Should -Not -Contain 'pull_request'
        $document['on'].Keys | Should -Not -Contain 'pull_request_target'
        $text | Should -Not -Match 'github\.event\.pull_request'
    }

    It 'Resolves the merged pull request read-only in <_>' -ForEach @('release-prerelease.yml', 'release-stable-publish.yml') {
        $document = Get-Content -Raw -LiteralPath (Join-Path $RepoRoot ".github/workflows/$_") | ConvertFrom-Yaml
        $resolve = $document['jobs']['resolve-merge']
        $resolve.Contains('environment') | Should -BeFalse
        ($resolve['permissions'].Keys | Sort-Object) | Should -Be @('contents', 'pull-requests')
        $resolve['permissions'].Values | Should -Not -Contain 'write'
        [string]$resolve['steps'][0]['run'] | Should -Match 'commits/\$EVENT_SHA/pulls'
        [string]$resolve['steps'][0]['run'] | Should -Match '\.merge_commit_sha == \$sha and \.base\.ref == \$base'
    }
}
