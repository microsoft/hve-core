#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

# Guards the agent firewall egress in the compiled gh-aw lock files. runtimes.node
# opts every agent into gh-aw's Node ecosystem domains, so each source blocks them.
# dependency-pr-review keeps registry.npmjs.org and lists the rest by hand; these
# tests fail when that list drifts from the Node set the pinned gh-aw compiles.

BeforeDiscovery {
    $repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
    $script:LockCases = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot '.github/workflows') -Filter '*.lock.yml' |
            ForEach-Object { @{ Name = $_.Name; Path = $_.FullName } })
}

BeforeAll {
    $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
    $script:Workflows = Join-Path $script:RepoRoot '.github/workflows'
    $script:RegistryException = 'registry.npmjs.org'

    function Get-AgentFirewallDomain {
        <#
        .SYNOPSIS
            Returns the allowed and blocked domains of the agent job's firewall config in a lock file.
        #>
        param([Parameter(Mandatory)][string]$Path)

        $lines = Get-Content -LiteralPath $Path
        $job = ''
        foreach ($line in $lines) {
            if ($line -match '^  ([A-Za-z0-9_-]+):\s*$') { $job = $Matches[1] }
            if ($job -eq 'agent' -and $line -match 'awf-config\.schema\.json') {
                $config = $line -replace '\\"', '"'
                $read = {
                    param($key)
                    $list = [regex]::Match($config, "`"$key`"\s*:\s*\[([^\]]*)\]").Groups[1].Value
                    @($list -split ',' | ForEach-Object { $_.Trim().Trim('"') } | Where-Object { $_ })
                }
                return [pscustomobject]@{ Allow = (& $read 'allowDomains'); Block = (& $read 'blockDomains') }
            }
        }
        throw "No agent firewall config found in $Path"
    }

    function Get-SourceBlockedDomain {
        <#
        .SYNOPSIS
            Returns the network.blocked entries from a gh-aw workflow source's frontmatter.
        #>
        param([Parameter(Mandatory)][string]$Path)

        $text = (Get-Content -LiteralPath $Path -Raw) -replace "`r`n?", "`n"
        $frontmatter = ($text -split '(?m)^---\s*$', 3)[1]
        $block = [regex]::Match($frontmatter, '(?ms)^network:\s*\n.*?^  blocked:\s*\n((?:    - [^\n]+\n)+)').Groups[1].Value
        return @([regex]::Matches($block, '(?m)^    - (\S+)') | ForEach-Object { $_.Groups[1].Value })
    }

    # gh-aw's Node ecosystem set, as compiled by the pinned gh-aw for a source that blocks `node`.
    $script:NodeSet = @((Get-AgentFirewallDomain -Path (Join-Path $script:Workflows 'backlog-groom.lock.yml')).Block | Sort-Object -Unique)
}

Describe 'Agent firewall Node egress' -Tag 'Unit' {
    It 'derives a non-empty Node domain set from a lock that blocks node' {
        $script:NodeSet.Count | Should -BeGreaterThan 0
        $script:NodeSet | Should -Contain $script:RegistryException
    }

    It 'reaches no Node ecosystem domain from the agent in <Name>' -ForEach $script:LockCases {
        $domains = Get-AgentFirewallDomain -Path $Path
        $reachable = @($domains.Allow | Where-Object { $_ -in $script:NodeSet -and $_ -notin $domains.Block })
        if ($Name -eq 'dependency-pr-review.lock.yml') {
            $reachable | Should -Be @($script:RegistryException)
        }
        else {
            $reachable | Should -BeNullOrEmpty
        }
    }

    It 'lists every Node domain except registry.npmjs.org in the dependency-pr-review source' {
        $listed = @(Get-SourceBlockedDomain -Path (Join-Path $script:Workflows 'dependency-pr-review.md') | Sort-Object -Unique)
        $expected = @($script:NodeSet | Where-Object { $_ -ne $script:RegistryException })

        Compare-Object -ReferenceObject $expected -DifferenceObject $listed | Should -BeNullOrEmpty
    }
}
