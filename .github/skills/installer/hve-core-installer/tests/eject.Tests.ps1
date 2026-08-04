#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

# Discovery-time capability probe: the Bash parity fixtures execute the real
# eject.sh, which needs an interpreter and jq.
$script:BashAvailable = [bool](Get-Command bash -ErrorAction SilentlyContinue) -and [bool](Get-Command jq -ErrorAction SilentlyContinue)

BeforeAll {
    $script:PowerShellScript = (Resolve-Path (Join-Path $PSScriptRoot '../scripts/eject.ps1')).Path
    $script:BashScript = (Resolve-Path (Join-Path $PSScriptRoot '../scripts/eject.sh')).Path
    $script:FixtureCounter = 0

    function script:New-EjectFixture {
        param([AllowNull()][hashtable]$Manifest)

        $script:FixtureCounter++
        $target = Join-Path $TestDrive "eject-$($script:FixtureCounter)"
        New-Item -ItemType Directory -Path $target -Force | Out-Null
        if ($null -ne $Manifest) {
            $Manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $target '.hve-tracking.json')
        }
        return $target
    }

    function script:New-TrackedManifest {
        return @{
            schemaVersion = 2
            source        = 'microsoft/hve-core'
            version       = '3.3.106'
            installed     = '2026-08-01T00:00:00Z'
            selection     = @{ profile = 'starter'; components = @('agents/hve-core/rpi-agent.md', 'skills/rpi/rpi-plan') }
            files         = @{
                '.github/agents/hve-core/rpi-agent.agent.md'      = @{ component = 'agents/hve-core/rpi-agent.md'; kind = 'agent'; maturity = 'stable'; version = '3.3.106'; sha256 = 'abc123'; status = 'managed' }
                '.github/skills/rpi/rpi-plan/SKILL.md'            = @{ component = 'skills/rpi/rpi-plan'; kind = 'skill'; maturity = 'stable'; version = '3.3.106'; sha256 = 'def456'; status = 'managed' }
                '.github/skills/rpi/rpi-plan/references/notes.md' = @{ component = 'skills/rpi/rpi-plan'; kind = 'skill'; maturity = 'stable'; version = '3.3.106'; sha256 = 'ghi789'; status = 'managed' }
            }
        }
    }

    function script:Get-EjectManifest {
        param([string]$Target)
        return Get-Content -LiteralPath (Join-Path $Target '.hve-tracking.json') -Raw | ConvertFrom-Json -AsHashtable
    }
}

Describe 'eject parameter contract' -Tag 'Unit' {
    BeforeAll { $script:command = Get-Command -Name $script:PowerShellScript }

    It 'Declares a mandatory Component parameter' {
        $attributes = @($script:command.Parameters['Component'].Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] })
        @($attributes | Where-Object { $_.Mandatory }).Count | Should -Be 1
    }

    It 'Declares an optional TargetRoot parameter and no file-path parameter' {
        $script:command.Parameters.Keys | Should -Contain 'TargetRoot'
        $script:command.Parameters.Keys | Should -Not -Contain 'FilePath'
    }
}

Describe 'eject component ownership' -Tag 'Unit' {
    It 'Marks a single-file component as ejected' {
        $target = New-EjectFixture -Manifest (New-TrackedManifest)

        & $script:PowerShellScript -Component 'agents/hve-core/rpi-agent.md' -TargetRoot $target 6>&1 | Out-Null

        (Get-EjectManifest -Target $target).files['.github/agents/hve-core/rpi-agent.agent.md'].status | Should -Be 'ejected'
    }

    It 'Marks every file of a skill component as ejected' {
        $target = New-EjectFixture -Manifest (New-TrackedManifest)

        & $script:PowerShellScript -Component 'skills/rpi/rpi-plan' -TargetRoot $target 6>&1 | Out-Null

        $files = (Get-EjectManifest -Target $target).files
        $files['.github/skills/rpi/rpi-plan/SKILL.md'].status | Should -Be 'ejected'
        $files['.github/skills/rpi/rpi-plan/references/notes.md'].status | Should -Be 'ejected'
    }

    It 'Adds an ejectedAt timestamp in the shared string format' {
        $target = New-EjectFixture -Manifest (New-TrackedManifest)

        & $script:PowerShellScript -Component 'agents/hve-core/rpi-agent.md' -TargetRoot $target 6>&1 | Out-Null

        Get-Content -LiteralPath (Join-Path $target '.hve-tracking.json') -Raw |
            Should -Match '"ejectedAt": "\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z"'
    }

    It 'Preserves the install timestamp format when rewriting the manifest' {
        $target = New-EjectFixture -Manifest (New-TrackedManifest)

        & $script:PowerShellScript -Component 'agents/hve-core/rpi-agent.md' -TargetRoot $target 6>&1 | Out-Null

        Get-Content -LiteralPath (Join-Path $target '.hve-tracking.json') -Raw |
            Should -Match '"installed": "2026-08-01T00:00:00Z"'
    }

    It 'Leaves other components managed' {
        $target = New-EjectFixture -Manifest (New-TrackedManifest)

        & $script:PowerShellScript -Component 'agents/hve-core/rpi-agent.md' -TargetRoot $target 6>&1 | Out-Null

        (Get-EjectManifest -Target $target).files['.github/skills/rpi/rpi-plan/SKILL.md'].status | Should -Be 'managed'
    }
}

Describe 'eject untracked component' -Tag 'Unit' {
    It 'Reports an untracked component without modifying the manifest' {
        $target = New-EjectFixture -Manifest (New-TrackedManifest)
        $before = Get-Content -LiteralPath (Join-Path $target '.hve-tracking.json') -Raw

        $output = & $script:PowerShellScript -Component 'agents/hve-core/absent.md' -TargetRoot $target 6>&1 | Out-String

        $output | Should -Match 'not found in tracking manifest'
        Get-Content -LiteralPath (Join-Path $target '.hve-tracking.json') -Raw | Should -Be $before
    }
}

Describe 'eject schema gate' -Tag 'Unit' {
    It 'Fails when no manifest exists' {
        $target = New-EjectFixture

        { & $script:PowerShellScript -Component 'agents/hve-core/rpi-agent.md' -TargetRoot $target } |
            Should -Throw -ExpectedMessage '*No .hve-tracking.json found*'
    }

    It 'Rejects a version 1 manifest with clean-reinstall guidance' {
        $target = New-EjectFixture -Manifest @{ source = 'microsoft/hve-core'; version = '3.3.100'; package = 'hve-core'; files = @{} }

        { & $script:PowerShellScript -Component 'agents/hve-core/rpi-agent.md' -TargetRoot $target } |
            Should -Throw -ExpectedMessage '*clean reinstall*'
    }
}

Describe 'eject PowerShell and Bash parity' -Tag 'Unit' -Skip:(-not $script:BashAvailable) {
    It 'Produces identical output and status for a skill component' {
        $powerShellTarget = New-EjectFixture -Manifest (New-TrackedManifest)
        $bashTarget = New-EjectFixture -Manifest (New-TrackedManifest)

        $powerShellOutput = (& $script:PowerShellScript -Component 'skills/rpi/rpi-plan' -TargetRoot $powerShellTarget 6>&1 | Out-String).Trim()
        $bashOutput = (& bash $script:BashScript 'skills/rpi/rpi-plan' $bashTarget 2>&1 | Out-String).Trim()

        $bashOutput | Should -Be $powerShellOutput
        foreach ($target in @($powerShellTarget, $bashTarget)) {
            $files = (Get-EjectManifest -Target $target).files
            $files['.github/skills/rpi/rpi-plan/SKILL.md'].status | Should -Be 'ejected'
            $files['.github/agents/hve-core/rpi-agent.agent.md'].status | Should -Be 'managed'
        }
    }

    It 'Produces identical output for an untracked component' {
        $powerShellTarget = New-EjectFixture -Manifest (New-TrackedManifest)
        $bashTarget = New-EjectFixture -Manifest (New-TrackedManifest)

        $powerShellOutput = (& $script:PowerShellScript -Component 'agents/hve-core/absent.md' -TargetRoot $powerShellTarget 6>&1 | Out-String).Trim()
        $bashOutput = (& bash $script:BashScript 'agents/hve-core/absent.md' $bashTarget 2>&1 | Out-String).Trim()

        $bashOutput | Should -Be $powerShellOutput
    }

    It 'Keeps the install timestamp identical across implementations' {
        $powerShellTarget = New-EjectFixture -Manifest (New-TrackedManifest)
        $bashTarget = New-EjectFixture -Manifest (New-TrackedManifest)

        & $script:PowerShellScript -Component 'agents/hve-core/rpi-agent.md' -TargetRoot $powerShellTarget 6>&1 | Out-Null
        & bash $script:BashScript 'agents/hve-core/rpi-agent.md' $bashTarget 2>&1 | Out-Null

        foreach ($target in @($powerShellTarget, $bashTarget)) {
            Get-Content -LiteralPath (Join-Path $target '.hve-tracking.json') -Raw | Should -Match '"installed": "2026-08-01T00:00:00Z"'
        }
    }

    It 'Exits non-zero for a version 1 manifest' {
        $target = New-EjectFixture -Manifest @{ source = 'microsoft/hve-core'; version = '3.3.100'; package = 'hve-core'; files = @{} }

        $output = & bash $script:BashScript 'agents/hve-core/rpi-agent.md' $target 2>&1 | Out-String
        $LASTEXITCODE | Should -Not -Be 0
        $output | Should -Match 'clean reinstall'
    }
}
