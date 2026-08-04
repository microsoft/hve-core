#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

# Discovery-time capability probe: the Bash parity fixtures execute the real
# collision-detection.sh, which delegates to component-copy.sh and needs jq.
$script:BashAvailable = [bool](Get-Command bash -ErrorAction SilentlyContinue) -and [bool](Get-Command jq -ErrorAction SilentlyContinue)

BeforeAll {
    $script:PowerShellScript = (Resolve-Path (Join-Path $PSScriptRoot '../scripts/collision-detection.ps1')).Path
    $script:BashScript = (Resolve-Path (Join-Path $PSScriptRoot '../scripts/collision-detection.sh')).Path
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../../../..')).Path
    $script:FixtureCounter = 0

    # Real recipe members used as the detection input.
    $script:PackageName = 'hve-core'
    $script:Components = @('agents/hve-core/rpi-agent.md', 'skills/rpi/rpi-plan')

    function script:New-CollisionFixture {
        param([string[]]$ExistingTarget = @())

        $script:FixtureCounter++
        $target = Join-Path $TestDrive "collision-$($script:FixtureCounter)"
        New-Item -ItemType Directory -Path $target -Force | Out-Null

        foreach ($relative in $ExistingTarget) {
            $full = Join-Path $target $relative
            if ($relative.EndsWith('/')) {
                New-Item -ItemType Directory -Path $full -Force | Out-Null
                continue
            }
            New-Item -ItemType Directory -Path (Split-Path $full -Parent) -Force | Out-Null
            Set-Content -LiteralPath $full -Value '# Local' -NoNewline
        }
        return $target
    }

    function script:Get-KeyValue {
        param([string]$Output, [string]$Key)

        $match = [regex]::Match($Output, "(?m)^$([regex]::Escape($Key))=(.*)$")
        if (-not $match.Success) { return @() }
        return @($match.Groups[1].Value.Trim() -split ',' | Where-Object { $_ })
    }
}

Describe 'collision-detection parameter contract' -Tag 'Unit' {
    BeforeAll {
        $script:command = Get-Command -Name $script:PowerShellScript
        $script:powerShellSource = Get-Content -LiteralPath $script:PowerShellScript -Raw
        $script:bashSource = Get-Content -LiteralPath $script:BashScript -Raw
    }

    It 'Declares the source, target, and component parameters' {
        foreach ($name in @('HveCoreBasePath', 'TargetRoot', 'PackageName', 'Component')) {
            $script:command.Parameters.Keys | Should -Contain $name
            $attributes = @($script:command.Parameters[$name].Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] })
            @($attributes | Where-Object { $_.Mandatory }).Count | Should -Be 1
        }
    }

    It 'Requires an explicit package and forwards it in both implementations' {
        $script:command.Parameters['PackageName'].ParameterType | Should -Be ([string])
        $script:powerShellSource | Should -Match '-PackageName \$PackageName'
        $script:bashSource | Should -Match '"\$package_name" custom'
    }

    It 'Delegates to component-copy report mode in both implementations' {
        $script:powerShellSource | Should -Match 'component-copy\.ps1'
        $script:powerShellSource | Should -Match '-ReportOnly'
        $script:bashSource | Should -Match 'component-copy\.sh'
        $script:bashSource | Should -Match 'REPORT_ONLY=true'
    }
}

Describe 'collision-detection component reporting' -Tag 'Unit' {
    It 'Reports canonical maturity and target for every selected component' {
        $target = New-CollisionFixture
        $output = & $script:PowerShellScript -HveCoreBasePath $script:RepoRoot -TargetRoot $target -PackageName $script:PackageName -Component $script:Components 6>&1 | Out-String

        $output | Should -Match 'COMPONENT=agents/hve-core/rpi-agent\.md\|KIND=agent\|MATURITY=stable\|TARGET=\.github/agents/hve-core/rpi-agent\.agent\.md\|EXISTS=false'
        $output | Should -Match 'COMPONENT=skills/rpi/rpi-plan\|KIND=skill\|MATURITY=stable\|TARGET=\.github/skills/rpi/rpi-plan\|EXISTS=false'
        $output | Should -Match 'COLLISIONS_DETECTED=false'
    }

    It 'Reports experimental maturity before any write' {
        $target = New-CollisionFixture
        $output = & $script:PowerShellScript -HveCoreBasePath $script:RepoRoot -TargetRoot $target -PackageName $script:PackageName -Component @('skills/hve-core/vally-tests') 6>&1 | Out-String

        $output | Should -Match 'MATURITY=experimental'
        @(Get-ChildItem -LiteralPath $target -Recurse -File -Force) | Should -BeNullOrEmpty
    }

    It 'Reports a file collision on the full target path' {
        $target = New-CollisionFixture -ExistingTarget @('.github/agents/hve-core/rpi-agent.agent.md')
        $output = & $script:PowerShellScript -HveCoreBasePath $script:RepoRoot -TargetRoot $target -PackageName $script:PackageName -Component $script:Components 6>&1 | Out-String

        $output | Should -Match 'COLLISIONS_DETECTED=true'
        Get-KeyValue -Output $output -Key 'COLLISION_COMPONENTS' | Should -Be @('agents/hve-core/rpi-agent.md')
        Get-KeyValue -Output $output -Key 'COLLISION_TARGETS' | Should -Be @('.github/agents/hve-core/rpi-agent.agent.md')
    }

    It 'Reports a skill collision on the target directory' {
        $target = New-CollisionFixture -ExistingTarget @('.github/skills/rpi/rpi-plan/')
        $output = & $script:PowerShellScript -HveCoreBasePath $script:RepoRoot -TargetRoot $target -PackageName $script:PackageName -Component $script:Components 6>&1 | Out-String

        Get-KeyValue -Output $output -Key 'COLLISION_COMPONENTS' | Should -Be @('skills/rpi/rpi-plan')
        Get-KeyValue -Output $output -Key 'COLLISION_TARGETS' | Should -Be @('.github/skills/rpi/rpi-plan')
    }

    It 'Reports an unrelated existing agent as no collision' {
        $target = New-CollisionFixture -ExistingTarget @('.github/agents/hve-core/unrelated.agent.md')
        $output = & $script:PowerShellScript -HveCoreBasePath $script:RepoRoot -TargetRoot $target -PackageName $script:PackageName -Component $script:Components 6>&1 | Out-String

        $output | Should -Match 'COLLISIONS_DETECTED=false'
    }

    It 'Rejects a component outside recipe membership' {
        $target = New-CollisionFixture
        { & $script:PowerShellScript -HveCoreBasePath $script:RepoRoot -TargetRoot $target -PackageName $script:PackageName -Component @('agents/hve-core/absent.md') } |
            Should -Throw -ExpectedMessage '*not declared membership*'
    }

    It 'Rejects an unknown package before reporting components' {
        $target = New-CollisionFixture
        { & $script:PowerShellScript -HveCoreBasePath $script:RepoRoot -TargetRoot $target -PackageName 'not-a-package' -Component $script:Components } |
            Should -Throw -ExpectedMessage "*declares no package named 'not-a-package'*"
        @(Get-ChildItem -LiteralPath $target -Recurse -File -Force) | Should -BeNullOrEmpty
    }

    It 'Rejects a component outside the selected focused package' {
        $target = New-CollisionFixture
        { & $script:PowerShellScript -HveCoreBasePath $script:RepoRoot -TargetRoot $target -PackageName 'hve-core' -Component @('agents/ado/ado-backlog-manager.md') } |
            Should -Throw -ExpectedMessage "*not declared membership of the 'hve-core' marketplace recipe*"
    }

    It 'Resolves shared components from focused and full packages' {
        foreach ($packageName in @('hve-core', 'hve-core-all')) {
            $target = New-CollisionFixture
            $output = & $script:PowerShellScript -HveCoreBasePath $script:RepoRoot -TargetRoot $target -PackageName $packageName -Component $script:Components 6>&1 | Out-String
            $output | Should -Match 'COMPONENT=agents/hve-core/rpi-agent\.md'
            $output | Should -Match 'COLLISIONS_DETECTED=false'
        }
    }
}

Describe 'collision-detection PowerShell and Bash parity' -Tag 'Unit' -Skip:(-not $script:BashAvailable) {
    It 'Produces identical output without collisions' {
        $target = New-CollisionFixture
        $powerShellOutput = (& $script:PowerShellScript -HveCoreBasePath $script:RepoRoot -TargetRoot $target -PackageName $script:PackageName -Component $script:Components 6>&1 | Out-String).Trim()
        $bashOutput = (& bash $script:BashScript $script:RepoRoot $target $script:PackageName @script:Components 2>&1 | Out-String).Trim()

        $bashOutput | Should -Be $powerShellOutput
    }

    It 'Produces identical output with file and skill collisions' {
        $target = New-CollisionFixture -ExistingTarget @('.github/agents/hve-core/rpi-agent.agent.md', '.github/skills/rpi/rpi-plan/')
        $powerShellOutput = (& $script:PowerShellScript -HveCoreBasePath $script:RepoRoot -TargetRoot $target -PackageName $script:PackageName -Component $script:Components 6>&1 | Out-String).Trim()
        $bashOutput = (& bash $script:BashScript $script:RepoRoot $target $script:PackageName @script:Components 2>&1 | Out-String).Trim()

        $bashOutput | Should -Be $powerShellOutput
        $bashOutput | Should -Match 'COLLISIONS_DETECTED=true'
    }

    It 'Exits non-zero for a component outside recipe membership' {
        $target = New-CollisionFixture
        & bash $script:BashScript $script:RepoRoot $target $script:PackageName 'agents/hve-core/absent.md' 2>&1 | Out-Null

        $LASTEXITCODE | Should -Not -Be 0
    }
}
