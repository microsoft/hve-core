#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

# Test-AdrCreationActivation.Tests.ps1
#
# Activation-harness regression suite for @adr-creation. Exercises the four
# canonical activation scenarios (CleanWorkspace, SteadyState, GovernEntry,
# AdoptTemplate) via Get-AgentActivationFingerprint and asserts:
#   * Per-scenario fingerprint hash matches the committed baseline (drift gate)
#   * CleanWorkspace cold-start byte budget < 44,000 bytes (PD-04=A)
#   * Lifecycle Dispatch load-set composition (always-attach vs on-demand)
#   * pester runner emits logs/pester-summary.json + logs/pester-failures.json

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Consumed by Pester -ForEach blocks at discovery time')]
param()

BeforeDiscovery {
    $ScenarioCases = @(
        @{ ScenarioName = 'CleanWorkspace' }
        @{ ScenarioName = 'SteadyState' }
        @{ ScenarioName = 'GovernEntry' }
        @{ ScenarioName = 'AdoptTemplate' }
    )
}

BeforeAll {
    $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../../..')).Path
    $modulePath = Join-Path $script:RepoRoot 'scripts/agents/activation-harness/Get-AgentActivationFingerprint.psm1'
    Import-Module -Name $modulePath -Force

    $script:AgentRelPath = '.github/agents/project-planning/adr-creation.agent.md'
    $script:AgentPath = Join-Path $script:RepoRoot $script:AgentRelPath

    $baselinePath = Join-Path $script:RepoRoot 'scripts/agents/activation-harness/baseline.json'
    $script:Baseline = Get-Content -LiteralPath $baselinePath -Raw -Encoding UTF8 |
        ConvertFrom-Json -AsHashtable

    $script:ColdStartBudget = 44000

    $script:Fingerprints = @{}
    foreach ($name in @('CleanWorkspace', 'SteadyState', 'GovernEntry', 'AdoptTemplate')) {
        $script:Fingerprints[$name] = Get-AgentActivationFingerprint `
            -AgentPath $script:AgentPath `
            -ScenarioName $name `
            -RepoRoot $script:RepoRoot
    }
}

AfterAll {
    Remove-Module -Name 'Get-AgentActivationFingerprint' -Force -ErrorAction SilentlyContinue
}

Describe '@adr-creation activation harness module contract' -Tag 'Unit' {
    It 'exports Get-AgentActivationFingerprint' {
        Get-Command -Name Get-AgentActivationFingerprint -ErrorAction Stop | Should -Not -BeNullOrEmpty
    }

    It 'returns a hashtable with required keys for scenario <ScenarioName>' -ForEach $ScenarioCases {
        $fp = $script:Fingerprints[$ScenarioName]
        $fp.Keys | Should -Contain 'ScenarioName'
        $fp.Keys | Should -Contain 'AgentBytes'
        $fp.Keys | Should -Contain 'ColdStartBytes'
        $fp.Keys | Should -Contain 'LoadedFiles'
        $fp.Keys | Should -Contain 'Hash'
        $fp.ScenarioName | Should -Be $ScenarioName
    }
}

Describe '@adr-creation activation fingerprint matches baseline' -Tag 'Unit' {
    It 'scenario <ScenarioName> hash matches baseline.json' -ForEach $ScenarioCases {
        $current = $script:Fingerprints[$ScenarioName]
        $expected = $script:Baseline[$ScenarioName]
        $expected | Should -Not -BeNullOrEmpty -Because "baseline.json must contain an entry for $ScenarioName"
        $current.Hash | Should -Be $expected.Hash -Because @"
Activation load-set drift detected for scenario '$ScenarioName'.
Expected hash : $($expected.Hash)
Actual hash   : $($current.Hash)
Expected files: $($expected.LoadedFiles | ForEach-Object { "$($_.Path) ($($_.Bytes))" } | Sort-Object | Join-String -Separator '; ')
Actual files  : $($current.LoadedFiles | ForEach-Object { "$($_.Path) ($($_.Bytes))" } | Sort-Object | Join-String -Separator '; ')
If the change is intentional, recapture baseline.json by running 'npm run test:activation:baseline' (see scripts/agents/activation-harness/README.md).
"@
    }

    It 'scenario <ScenarioName> cold-start byte total matches baseline' -ForEach $ScenarioCases {
        $current = $script:Fingerprints[$ScenarioName]
        $expected = $script:Baseline[$ScenarioName]
        $current.ColdStartBytes | Should -Be $expected.ColdStartBytes
    }
}

Describe '@adr-creation cold-start byte budget' -Tag 'Unit' {
    It 'CleanWorkspace ColdStartBytes is below the PD-04 budget' {
        $current = $script:Fingerprints['CleanWorkspace']
        $current.ColdStartBytes | Should -BeLessThan $script:ColdStartBudget -Because @"
Cold-start byte budget violation (PD-04=A).
Target  : less than $($script:ColdStartBudget) bytes
Actual  : $($current.ColdStartBytes) bytes
Loaded  : $($current.LoadedFiles | ForEach-Object { "$($_.Path) ($($_.Bytes))" } | Join-String -Separator '; ')
"@
    }
}

Describe '@adr-creation lifecycle dispatch load-set composition' -Tag 'Unit' {
    BeforeAll {
        $script:CleanLoaded = $script:Fingerprints['CleanWorkspace'].LoadedFiles | ForEach-Object { $_.Path }
        $script:SteadyLoaded = $script:Fingerprints['SteadyState'].LoadedFiles | ForEach-Object { $_.Path }
        $script:GovernLoaded = $script:Fingerprints['GovernEntry'].LoadedFiles | ForEach-Object { $_.Path }
        $script:AdoptLoaded = $script:Fingerprints['AdoptTemplate'].LoadedFiles | ForEach-Object { $_.Path }
    }

    It 'CleanWorkspace includes the agent file itself' {
        $script:CleanLoaded | Should -Contain '.github/agents/project-planning/adr-creation.agent.md'
    }

    It 'CleanWorkspace includes adr-identity.instructions.md (always-on identity)' {
        $script:CleanLoaded | Should -Contain '.github/instructions/project-planning/adr-identity.instructions.md'
    }

    It 'CleanWorkspace includes shared disclaimer-language.instructions.md' {
        $script:CleanLoaded | Should -Contain '.github/instructions/shared/disclaimer-language.instructions.md'
    }

    It 'CleanWorkspace excludes adr-handoff.instructions.md (Govern on-demand)' {
        $script:CleanLoaded | Should -Not -Contain '.github/instructions/project-planning/adr-handoff.instructions.md'
    }

    It 'CleanWorkspace excludes adr-byo-template.instructions.md (adopt-template on-demand)' {
        $script:CleanLoaded | Should -Not -Contain '.github/instructions/project-planning/adr-byo-template.instructions.md'
    }

    It 'SteadyState is a strict superset of CleanWorkspace' {
        foreach ($file in $script:CleanLoaded) {
            $script:SteadyLoaded | Should -Contain $file
        }
    }

    It 'GovernEntry includes adr-handoff.instructions.md (Govern Table A trigger)' {
        $script:GovernLoaded | Should -Contain '.github/instructions/project-planning/adr-handoff.instructions.md'
    }

    It 'AdoptTemplate includes adr-byo-template.instructions.md (Table B trigger)' {
        $script:AdoptLoaded | Should -Contain '.github/instructions/project-planning/adr-byo-template.instructions.md'
    }
}

Describe '@adr-creation activation scenarios produce distinct fingerprints' -Tag 'Unit' {
    It 'GovernEntry hash differs from SteadyState (Govern Table A on-demand load)' {
        $script:Fingerprints['GovernEntry'].Hash | Should -Not -Be $script:Fingerprints['SteadyState'].Hash
    }

    It 'AdoptTemplate hash differs from SteadyState (Table B on-demand load)' {
        $script:Fingerprints['AdoptTemplate'].Hash | Should -Not -Be $script:Fingerprints['SteadyState'].Hash
    }

    It 'AdoptTemplate hash differs from GovernEntry (distinct dispatch tables)' {
        $script:Fingerprints['AdoptTemplate'].Hash | Should -Not -Be $script:Fingerprints['GovernEntry'].Hash
    }

    It 'CleanWorkspace hash differs from SteadyState (cold-start vs steady)' {
        $script:Fingerprints['CleanWorkspace'].Hash | Should -Not -Be $script:Fingerprints['SteadyState'].Hash
    }
}

Describe '@adr-creation activation harness emits Pester runner artifacts' -Tag 'Unit' {
    It 'logs/pester-summary.json exists after this suite is invoked via Invoke-PesterTests.ps1' {
        $summaryPath = Join-Path $script:RepoRoot 'logs/pester-summary.json'
        Test-Path -LiteralPath $summaryPath | Should -BeTrue -Because 'Invoke-PesterTests.ps1 writes this file before discovery completes'
    }

    It 'logs/pester-failures.json exists after this suite is invoked via Invoke-PesterTests.ps1' {
        $failuresPath = Join-Path $script:RepoRoot 'logs/pester-failures.json'
        Test-Path -LiteralPath $failuresPath | Should -BeTrue
    }
}
