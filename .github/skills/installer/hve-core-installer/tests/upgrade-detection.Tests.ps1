#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

# Discovery-time capability probe: the Bash parity fixtures execute the real
# upgrade-detection.sh, which needs an interpreter and jq.
$script:BashAvailable = [bool](Get-Command bash -ErrorAction SilentlyContinue) -and [bool](Get-Command jq -ErrorAction SilentlyContinue)

BeforeAll {
    $script:PowerShellScript = (Resolve-Path (Join-Path $PSScriptRoot '../scripts/upgrade-detection.ps1')).Path
    $script:BashScript = (Resolve-Path (Join-Path $PSScriptRoot '../scripts/upgrade-detection.sh')).Path
    $script:FixtureCounter = 0

    function script:New-UpgradeFixture {
        param(
            [string]$SourceVersion = '3.3.106',
            [AllowNull()][hashtable]$Manifest
        )

        $script:FixtureCounter++
        $root = Join-Path $TestDrive "upgrade-$($script:FixtureCounter)"
        $source = Join-Path $root 'source'
        $target = Join-Path $root 'target'
        New-Item -ItemType Directory -Path $source -Force | Out-Null
        New-Item -ItemType Directory -Path $target -Force | Out-Null

        Set-Content -LiteralPath (Join-Path $source 'package.json') -Value "{ `"version`": `"$SourceVersion`" }" -NoNewline
        if ($null -ne $Manifest) {
            $Manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $target '.hve-tracking.json') -NoNewline
        }

        return [pscustomobject]@{ Root = $root; Source = $source; Target = $target }
    }

    function script:New-InstalledManifest {
        param(
            [string]$Version = '3.3.100',
            [string]$ProfileName = 'starter',
            [string[]]$Component = @('agents/hve-core/rpi-agent.md', 'skills/rpi/rpi-plan')
        )

        return @{
            schemaVersion = 2
            source        = 'microsoft/hve-core'
            version       = $Version
            installed     = '2026-08-01T00:00:00Z'
            selection     = [ordered]@{
                profile    = $ProfileName
                components = $Component
            }
            files         = @{}
        }
    }

    function script:Invoke-PowerShellDetector {
        param([pscustomobject]$Fixture)
        return (& $script:PowerShellScript -HveCoreBasePath $Fixture.Source -TargetRoot $Fixture.Target 6>&1 | Out-String).Trim()
    }

    function script:Invoke-BashDetector {
        param([pscustomobject]$Fixture)
        return (& bash $script:BashScript $Fixture.Source $Fixture.Target 2>&1 | Out-String).Trim()
    }
}

Describe 'upgrade-detection contract' -Tag 'Unit' {
    BeforeAll {
        $script:command = Get-Command -Name $script:PowerShellScript
        $script:powerShellSource = Get-Content -LiteralPath $script:PowerShellScript -Raw
        $script:bashSource = Get-Content -LiteralPath $script:BashScript -Raw
    }

    It 'Declares the source and target root parameters' {
        @($script:command.Parameters.Keys | Where-Object { $_ -notin [System.Management.Automation.PSCmdlet]::CommonParameters }) |
            Should -Be @('HveCoreBasePath', 'TargetRoot')
    }

    It 'Emits selection vocabulary in the PowerShell implementation' {
        $script:powerShellSource | Should -Match 'INSTALLED_PROFILE='
        $script:powerShellSource | Should -Match 'INSTALLED_COMPONENTS='
    }

    It 'Emits selection vocabulary in the Bash implementation' {
        $script:bashSource | Should -Match 'INSTALLED_PROFILE='
        $script:bashSource | Should -Match 'INSTALLED_COMPONENTS='
    }

    It 'Reads and emits no package identity in either implementation' {
        $script:powerShellSource | Should -Not -Match 'INSTALLED_PACKAGE'
        $script:bashSource | Should -Not -Match 'INSTALLED_PACKAGE'
        $script:powerShellSource | Should -Not -Match "selection\['package'\]"
        $script:bashSource | Should -Not -Match '\.selection\.package'
    }
}

Describe 'upgrade-detection fresh installation' -Tag 'Unit' {
    BeforeAll {
        $script:fixture = New-UpgradeFixture
        $script:output = Invoke-PowerShellDetector -Fixture $script:fixture
    }

    It 'Reports UPGRADE_MODE=false when no tracking manifest exists' {
        $script:output | Should -Be 'UPGRADE_MODE=false'
    }

    It 'Emits no package, selection, or version keys' {
        $script:output | Should -Not -Match 'INSTALLED_PACKAGE'
        $script:output | Should -Not -Match 'INSTALLED_PROFILE='
        $script:output | Should -Not -Match 'INSTALLED_VERSION='
        $script:output | Should -Not -Match 'VERSION_CHANGED='
    }
}

Describe 'upgrade-detection version reporting' -Tag 'Unit' {
    It 'Reports the installed and source versions' {
        $fixture = New-UpgradeFixture -SourceVersion '3.3.106' -Manifest (New-InstalledManifest -Version '3.3.100')

        $output = Invoke-PowerShellDetector -Fixture $fixture

        $output | Should -Match '(?m)^UPGRADE_MODE=true$'
        $output | Should -Match '(?m)^INSTALLED_VERSION=3\.3\.100$'
        $output | Should -Match '(?m)^SOURCE_VERSION=3\.3\.106$'
    }

    It 'Reports VERSION_CHANGED=true when the source version differs' {
        $fixture = New-UpgradeFixture -SourceVersion '3.3.106' -Manifest (New-InstalledManifest -Version '3.3.100')

        Invoke-PowerShellDetector -Fixture $fixture | Should -Match '(?m)^VERSION_CHANGED=true$'
    }

    It 'Reports VERSION_CHANGED=false when the versions match' {
        $fixture = New-UpgradeFixture -SourceVersion '3.3.106' -Manifest (New-InstalledManifest -Version '3.3.106')

        Invoke-PowerShellDetector -Fixture $fixture | Should -Match '(?m)^VERSION_CHANGED=false$'
    }
}

Describe 'upgrade-detection selection reporting' -Tag 'Unit' {
    It 'Reports the recorded profile and components' {
        $fixture = New-UpgradeFixture -Manifest (New-InstalledManifest -ProfileName 'starter')

        $output = Invoke-PowerShellDetector -Fixture $fixture
        $output | Should -Match '(?m)^INSTALLED_PROFILE=starter$'
        $output | Should -Match '(?m)^INSTALLED_COMPONENTS=agents/hve-core/rpi-agent\.md,skills/rpi/rpi-plan$'
    }

    It 'Reports a custom selection without a named profile' {
        $fixture = New-UpgradeFixture -Manifest (New-InstalledManifest -ProfileName 'custom' -Component @('agents/hve-core/documentation.md'))

        $output = Invoke-PowerShellDetector -Fixture $fixture
        $output | Should -Match '(?m)^INSTALLED_PROFILE=custom$'
        $output | Should -Match '(?m)^INSTALLED_COMPONENTS=agents/hve-core/documentation\.md$'
    }

    It 'Emits VERSION_CHANGED immediately before INSTALLED_PROFILE' {
        $fixture = New-UpgradeFixture -Manifest (New-InstalledManifest -ProfileName 'starter')

        Invoke-PowerShellDetector -Fixture $fixture |
            Should -Match "(?m)^VERSION_CHANGED=true\r?\nINSTALLED_PROFILE=starter$"
    }

    It 'Replays a manifest that records no package' {
        $fixture = New-UpgradeFixture -Manifest (New-InstalledManifest -ProfileName 'starter')

        $output = Invoke-PowerShellDetector -Fixture $fixture
        $output | Should -Not -Match 'INSTALLED_PACKAGE'
        $output | Should -Match '(?m)^INSTALLED_COMPONENTS=agents/hve-core/rpi-agent\.md,skills/rpi/rpi-plan$'
    }

    It 'Defaults an absent profile to custom' {
        $manifest = New-InstalledManifest
        $manifest['selection'] = [ordered]@{ components = @('agents/hve-core/rpi-agent.md') }
        $fixture = New-UpgradeFixture -Manifest $manifest

        Invoke-PowerShellDetector -Fixture $fixture | Should -Match '(?m)^INSTALLED_PROFILE=custom$'
    }
}

Describe 'upgrade-detection schema gate' -Tag 'Unit' {
    It 'Rejects a version 1 manifest with clean-reinstall guidance' {
        $fixture = New-UpgradeFixture -Manifest @{ source = 'microsoft/hve-core'; version = '3.3.100'; package = 'hve-core'; files = @{} }

        { Invoke-PowerShellDetector -Fixture $fixture } | Should -Throw -ExpectedMessage '*clean reinstall*'
    }

    It 'Rejects an unsupported future schema version' {
        $fixture = New-UpgradeFixture -Manifest @{ schemaVersion = 3; version = '3.3.100'; files = @{} }

        { Invoke-PowerShellDetector -Fixture $fixture } | Should -Throw -ExpectedMessage "*schemaVersion '3'*"
    }
}

Describe 'upgrade-detection PowerShell and Bash parity' -Tag 'Unit' -Skip:(-not $script:BashAvailable) {
    It 'Produces identical output for a fresh installation' {
        $fixture = New-UpgradeFixture

        Invoke-BashDetector -Fixture $fixture | Should -Be (Invoke-PowerShellDetector -Fixture $fixture)
    }

    It 'Produces identical output for an upgradeable installation' {
        $fixture = New-UpgradeFixture -SourceVersion '3.3.106' -Manifest (New-InstalledManifest -Version '3.3.100')

        Invoke-BashDetector -Fixture $fixture | Should -Be (Invoke-PowerShellDetector -Fixture $fixture)
    }

    It 'Produces identical output for an up-to-date custom installation' {
        $fixture = New-UpgradeFixture -SourceVersion '3.3.106' -Manifest (New-InstalledManifest -Version '3.3.106' -ProfileName 'custom')

        Invoke-BashDetector -Fixture $fixture | Should -Be (Invoke-PowerShellDetector -Fixture $fixture)
    }

    It 'Produces identical output and emits no package line for a schema version 2 manifest' {
        $fixture = New-UpgradeFixture -Manifest (New-InstalledManifest)

        $bashOutput = Invoke-BashDetector -Fixture $fixture
        $LASTEXITCODE | Should -Be 0
        $bashOutput | Should -Not -Match 'INSTALLED_PACKAGE'
        $bashOutput | Should -Be (Invoke-PowerShellDetector -Fixture $fixture)
    }

    It 'Exits non-zero for a version 1 manifest' {
        $fixture = New-UpgradeFixture -Manifest @{ source = 'microsoft/hve-core'; version = '3.3.100'; package = 'hve-core'; files = @{} }

        $output = Invoke-BashDetector -Fixture $fixture
        $LASTEXITCODE | Should -Not -Be 0
        $output | Should -Match 'clean reinstall'
    }
}
