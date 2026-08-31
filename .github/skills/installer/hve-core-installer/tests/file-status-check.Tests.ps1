#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

# Discovery-time capability probe: the Bash parity fixtures execute the real
# file-status-check.sh, which needs an interpreter and jq.
$script:BashAvailable = [bool](Get-Command bash -ErrorAction SilentlyContinue) -and [bool](Get-Command jq -ErrorAction SilentlyContinue)

BeforeAll {
    $script:PowerShellScript = (Resolve-Path (Join-Path $PSScriptRoot '../scripts/file-status-check.ps1')).Path
    $script:BashScript = (Resolve-Path (Join-Path $PSScriptRoot '../scripts/file-status-check.sh')).Path
    $script:FixtureCounter = 0

    function script:New-StatusFixture {
        param(
            [hashtable]$File = @{},
            [AllowNull()][hashtable]$Manifest
        )

        $script:FixtureCounter++
        $target = Join-Path $TestDrive "file-status-$($script:FixtureCounter)"
        New-Item -ItemType Directory -Path $target -Force | Out-Null

        foreach ($relative in $File.Keys) {
            $full = Join-Path $target $relative
            New-Item -ItemType Directory -Path (Split-Path $full -Parent) -Force | Out-Null
            Set-Content -LiteralPath $full -Value $File[$relative] -NoNewline
        }
        if ($null -ne $Manifest) {
            $Manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $target '.hve-tracking.json')
        }
        return $target
    }

    function script:New-ManifestEntry {
        param(
            [string]$Component,
            [string]$Kind,
            [string]$Maturity,
            [string]$Sha256,
            [string]$Status = 'managed'
        )
        return @{ component = $Component; kind = $Kind; maturity = $Maturity; version = '3.3.106'; sha256 = $Sha256; status = $Status }
    }

    function script:Get-Sha256 {
        param([string]$Root, [string]$Relative)
        return (Get-FileHash -LiteralPath (Join-Path $Root $Relative) -Algorithm SHA256).Hash.ToLower()
    }
}

Describe 'file-status-check schema gate' -Tag 'Unit' {
    It 'Fails when no manifest exists' {
        $target = New-StatusFixture

        { & $script:PowerShellScript -TargetRoot $target } | Should -Throw -ExpectedMessage '*No .hve-tracking.json found*'
    }

    It 'Rejects a version 1 manifest with clean-reinstall guidance' {
        $target = New-StatusFixture -Manifest @{ source = 'microsoft/hve-core'; version = '3.3.100'; package = 'hve-core'; files = @{} }

        { & $script:PowerShellScript -TargetRoot $target } | Should -Throw -ExpectedMessage '*clean reinstall*'
    }

    It 'Rejects an unsupported future schema version' {
        $target = New-StatusFixture -Manifest @{ schemaVersion = 3; files = @{} }

        { & $script:PowerShellScript -TargetRoot $target } | Should -Throw -ExpectedMessage "*schemaVersion '3'*"
    }
}

Describe 'file-status-check per-file status' -Tag 'Unit' {
    It 'Reports managed status with component context when the hash matches' {
        $relative = '.github/agents/hve-core/rpi-agent.agent.md'
        $target = New-StatusFixture -File @{ $relative = '# RPI Agent' }
        $manifest = @{ schemaVersion = 2; files = @{ $relative = New-ManifestEntry -Component 'agents/hve-core/rpi-agent.md' -Kind 'agent' -Maturity 'stable' -Sha256 (Get-Sha256 -Root $target -Relative $relative) } }
        $manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $target '.hve-tracking.json')

        $output = & $script:PowerShellScript -TargetRoot $target 6>&1 | Out-String

        $output.Trim() | Should -Be "FILE=$relative|COMPONENT=agents/hve-core/rpi-agent.md|KIND=agent|MATURITY=stable|STATUS=managed|ACTION=Will update"
    }

    It 'Reports modified status when the hash differs' {
        $relative = '.github/agents/hve-core/rpi-agent.agent.md'
        $target = New-StatusFixture -File @{ $relative = '# Local edit' } -Manifest @{
            schemaVersion = 2
            files         = @{ $relative = New-ManifestEntry -Component 'agents/hve-core/rpi-agent.md' -Kind 'agent' -Maturity 'stable' -Sha256 'stale' }
        }

        (& $script:PowerShellScript -TargetRoot $target 6>&1 | Out-String) | Should -Match 'STATUS=modified\|ACTION=Requires decision'
    }

    It 'Reports missing status when a tracked file is absent' {
        $target = New-StatusFixture -Manifest @{
            schemaVersion = 2
            files         = @{ '.github/skills/rpi/rpi-plan/SKILL.md' = New-ManifestEntry -Component 'skills/rpi/rpi-plan' -Kind 'skill' -Maturity 'stable' -Sha256 'abc123' }
        }

        (& $script:PowerShellScript -TargetRoot $target 6>&1 | Out-String) | Should -Match 'STATUS=missing\|ACTION=Will restore'
    }

    It 'Reports ejected status without hashing the file' {
        $target = New-StatusFixture -Manifest @{
            schemaVersion = 2
            files         = @{ '.github/agents/hve-core/rpi-agent.agent.md' = New-ManifestEntry -Component 'agents/hve-core/rpi-agent.md' -Kind 'agent' -Maturity 'stable' -Sha256 'abc123' -Status 'ejected' }
        }

        $output = & $script:PowerShellScript -TargetRoot $target 6>&1 | Out-String
        $output | Should -Match 'STATUS=ejected\|ACTION=Skip \(user owns this file\)'
        $output | Should -Not -Match 'STATUS=missing'
    }

    It 'Reports each skill file independently under one component' {
        $skillFile = '.github/skills/hve-core/vally-tests/SKILL.md'
        $referenceFile = '.github/skills/hve-core/vally-tests/references/notes.md'
        $target = New-StatusFixture -File @{ $skillFile = '# Skill'; $referenceFile = '# Notes' }
        $manifest = @{
            schemaVersion = 2
            files         = @{
                $skillFile     = New-ManifestEntry -Component 'skills/hve-core/vally-tests' -Kind 'skill' -Maturity 'experimental' -Sha256 (Get-Sha256 -Root $target -Relative $skillFile)
                $referenceFile = New-ManifestEntry -Component 'skills/hve-core/vally-tests' -Kind 'skill' -Maturity 'experimental' -Sha256 'stale'
            }
        }
        $manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $target '.hve-tracking.json')

        $output = & $script:PowerShellScript -TargetRoot $target 6>&1 | Out-String
        $output | Should -Match "FILE=$([regex]::Escape($skillFile))\|COMPONENT=skills/hve-core/vally-tests\|KIND=skill\|MATURITY=experimental\|STATUS=managed"
        $output | Should -Match "FILE=$([regex]::Escape($referenceFile))\|COMPONENT=skills/hve-core/vally-tests\|KIND=skill\|MATURITY=experimental\|STATUS=modified"
    }
}

Describe 'file-status-check PowerShell and Bash parity' -Tag 'Unit' -Skip:(-not $script:BashAvailable) {
    It 'Produces identical output across statuses' {
        $managed = '.github/agents/hve-core/rpi-agent.agent.md'
        $modified = '.github/prompts/hve-core/rpi.prompt.md'
        $target = New-StatusFixture -File @{ $managed = '# RPI Agent'; $modified = '# Local edit' }
        $manifest = @{
            schemaVersion = 2
            files         = @{
                $managed                                = New-ManifestEntry -Component 'agents/hve-core/rpi-agent.md' -Kind 'agent' -Maturity 'stable' -Sha256 (Get-Sha256 -Root $target -Relative $managed)
                $modified                               = New-ManifestEntry -Component 'commands/hve-core/rpi.md' -Kind 'prompt' -Maturity 'stable' -Sha256 'stale'
                '.github/skills/rpi/rpi-plan/SKILL.md'  = New-ManifestEntry -Component 'skills/rpi/rpi-plan' -Kind 'skill' -Maturity 'stable' -Sha256 'abc123'
                '.github/instructions/hve-core/x.instructions.md' = New-ManifestEntry -Component 'rules/hve-core/x.instructions.md' -Kind 'instruction' -Maturity 'experimental' -Sha256 'abc123' -Status 'ejected'
            }
        }
        $manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $target '.hve-tracking.json')

        $powerShellOutput = (& $script:PowerShellScript -TargetRoot $target 6>&1 | Out-String).Trim()
        $bashOutput = (& bash $script:BashScript $target 2>&1 | Out-String).Trim()

        $bashOutput | Should -Be $powerShellOutput
    }

    It 'Exits non-zero for a version 1 manifest' {
        $target = New-StatusFixture -Manifest @{ source = 'microsoft/hve-core'; version = '3.3.100'; package = 'hve-core'; files = @{} }

        $output = & bash $script:BashScript $target 2>&1 | Out-String
        $LASTEXITCODE | Should -Not -Be 0
        $output | Should -Match 'clean reinstall'
    }
}
