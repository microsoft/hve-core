#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ScriptPath = Resolve-Path (Join-Path $PSScriptRoot '../../linting/Test-FsiSustainabilityProfile.ps1')

    function Invoke-Profile {
        param(
            [Parameter(Mandatory)] [string]$RepoRoot,
            [string]$SustainabilitySkillsPath = '.github/skills/sustainability',
            [string]$DisclaimerInstructionsPath = '.github/instructions/shared/disclaimer-language.instructions.md',
            [string[]]$ArtifactPaths = @(),
            [string[]]$SkillsLoadedLogPaths = @(),
            [string]$ExpectedDisclaimerHash
        )
        $params = @{
            RepoRoot                   = $RepoRoot
            SustainabilitySkillsPath   = $SustainabilitySkillsPath
            DisclaimerInstructionsPath = $DisclaimerInstructionsPath
            ArtifactPaths              = $ArtifactPaths
            SkillsLoadedLogPaths       = $SkillsLoadedLogPaths
            AsObject                   = $true
        }
        if ($PSBoundParameters.ContainsKey('ExpectedDisclaimerHash')) {
            $params.ExpectedDisclaimerHash = $ExpectedDisclaimerHash
        }
        & $script:ScriptPath @params
    }

    function New-TempRepo {
        $root = Join-Path ([System.IO.Path]::GetTempPath()) ("fsi-sus-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $root '.github/skills/sustainability') -Force | Out-Null
        $disclaimerDir = Join-Path $root '.github/instructions/shared'
        New-Item -ItemType Directory -Path $disclaimerDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $disclaimerDir 'disclaimer-language.instructions.md') -Value "# Disclaimers`n`n## Other Section`n`nbody`n" -Encoding utf8
        return $root
    }

    function New-Bundle {
        param(
            [Parameter(Mandatory)] [string]$RepoRoot,
            [Parameter(Mandatory)] [string]$Name,
            [Parameter(Mandatory)] [string]$ManifestYaml,
            [hashtable]$Items = @{}
        )
        $bundleRoot = Join-Path $RepoRoot ".github/skills/sustainability/$Name"
        New-Item -ItemType Directory -Path $bundleRoot -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $bundleRoot 'index.yml') -Value $ManifestYaml -Encoding utf8
        if ($Items.Count -gt 0) {
            $itemsDir = Join-Path $bundleRoot 'items'
            New-Item -ItemType Directory -Path $itemsDir -Force | Out-Null
            foreach ($k in $Items.Keys) {
                Set-Content -LiteralPath (Join-Path $itemsDir "$k.yml") -Value $Items[$k] -Encoding utf8
            }
        }
        return $bundleRoot
    }
}

Describe 'Test-FsiSustainabilityProfile - license-whitelist (Rule 1)' -Tag 'Unit' {
    It 'accepts a license in the whitelist' {
        $repo = New-TempRepo
        try {
            New-Bundle -RepoRoot $repo -Name 'good' -ManifestYaml @"
metadata:
  name: good
  license: MIT
"@ | Out-Null
            $result = Invoke-Profile -RepoRoot $repo
            ($result.Diagnostics | Where-Object { $_.rule -eq 'license-whitelist' }).Count | Should -Be 0
        } finally { Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'rejects a license outside the whitelist' {
        $repo = New-TempRepo
        try {
            New-Bundle -RepoRoot $repo -Name 'bad' -ManifestYaml @"
metadata:
  name: bad
  license: GPL-3.0
"@ | Out-Null
            $result = Invoke-Profile -RepoRoot $repo
            ($result.Diagnostics | Where-Object { $_.rule -eq 'license-whitelist' -and $_.severity -eq 'error' }).Count | Should -BeGreaterThan 0
        } finally { Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Describe 'Test-FsiSustainabilityProfile - runtime-fetch-ban (Rule 2)' -Tag 'Unit' {
    It 'rejects an Electricity Maps numeric literal embedded in a control body' {
        $repo = New-TempRepo
        try {
            $manifest = @"
metadata:
  name: bad
  license: MIT
"@
            $item = @"
controls:
  - id: ctl-1
    body: "Use 250 gCO2eq/kWh as the regional intensity for planning purposes."
    references:
      - attribution: "Source: Electricity Maps API snapshot."
"@
            New-Bundle -RepoRoot $repo -Name 'bad' -ManifestYaml $manifest -Items @{ 'ctl-1' = $item } | Out-Null
            $result = Invoke-Profile -RepoRoot $repo
            ($result.Diagnostics | Where-Object { $_.rule -eq 'runtime-fetch-ban' -and $_.severity -eq 'error' }).Count | Should -BeGreaterThan 0
        } finally { Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'accepts a control body without numeric carbon-intensity literals' {
        $repo = New-TempRepo
        try {
            $manifest = @"
metadata:
  name: ok
  license: MIT
"@
            $item = @"
controls:
  - id: ctl-1
    body: "Fetch regional carbon intensity at runtime via the Electricity Maps API."
    references:
      - attribution: "Electricity Maps API"
"@
            New-Bundle -RepoRoot $repo -Name 'ok' -ManifestYaml $manifest -Items @{ 'ctl-1' = $item } | Out-Null
            $result = Invoke-Profile -RepoRoot $repo
            ($result.Diagnostics | Where-Object { $_.rule -eq 'runtime-fetch-ban' }).Count | Should -Be 0
        } finally { Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Describe 'Test-FsiSustainabilityProfile - attribution-required (Rule 3)' -Tag 'Unit' {
    It 'rejects a CC-BY-4.0 bundle missing attribution metadata' {
        $repo = New-TempRepo
        try {
            New-Bundle -RepoRoot $repo -Name 'bad' -ManifestYaml @"
metadata:
  name: bad
  license: CC-BY-4.0
"@ | Out-Null
            $result = Invoke-Profile -RepoRoot $repo
            ($result.Diagnostics | Where-Object { $_.rule -eq 'attribution-required' -and $_.severity -eq 'error' }).Count | Should -BeGreaterThan 0
        } finally { Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'accepts a CC-BY-4.0 bundle with attributionRequired and attributionText' {
        $repo = New-TempRepo
        try {
            New-Bundle -RepoRoot $repo -Name 'ok' -ManifestYaml @"
metadata:
  name: ok
  license: CC-BY-4.0
  attributionRequired: true
  attributionText: "© Example, CC-BY-4.0."
"@ | Out-Null
            $result = Invoke-Profile -RepoRoot $repo
            ($result.Diagnostics | Where-Object { $_.rule -eq 'attribution-required' }).Count | Should -Be 0
        } finally { Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'enforces attribution when license uses compound + form (Apache-2.0+CC-BY-4.0)' {
        $repo = New-TempRepo
        try {
            New-Bundle -RepoRoot $repo -Name 'bad' -ManifestYaml @"
metadata:
  name: bad
  license: Apache-2.0+CC-BY-4.0
"@ | Out-Null
            $result = Invoke-Profile -RepoRoot $repo
            ($result.Diagnostics | Where-Object { $_.rule -eq 'attribution-required' -and $_.severity -eq 'error' }).Count | Should -BeGreaterThan 0
        } finally { Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Describe 'Test-FsiSustainabilityProfile - skills-loaded-log-append-only (Rule 4)' -Tag 'Unit' {
    It 'accepts a log with monotonic timestamps and 5 tab-separated fields' {
        $repo = New-TempRepo
        try {
            $log = Join-Path $repo 'skills-loaded.log'
            $lines = @(
                "2026-04-21T12:00:00Z`tgsf-sci`t1.0.0`tCSL-1.0`ttrue",
                "2026-04-21T12:01:00Z`tswd`t1.0.0`tCC-BY-4.0`ttrue"
            )
            Set-Content -LiteralPath $log -Value ($lines -join "`n") -Encoding utf8
            $result = Invoke-Profile -RepoRoot $repo -SkillsLoadedLogPaths @($log)
            ($result.Diagnostics | Where-Object { $_.rule -eq 'skills-loaded-log-append-only' }).Count | Should -Be 0
        } finally { Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'rejects a log with non-monotonic timestamps' {
        $repo = New-TempRepo
        try {
            $log = Join-Path $repo 'skills-loaded.log'
            $lines = @(
                "2026-04-21T12:05:00Z`tgsf-sci`t1.0.0`tCSL-1.0`ttrue",
                "2026-04-21T12:01:00Z`tswd`t1.0.0`tCC-BY-4.0`ttrue"
            )
            Set-Content -LiteralPath $log -Value ($lines -join "`n") -Encoding utf8
            $result = Invoke-Profile -RepoRoot $repo -SkillsLoadedLogPaths @($log)
            ($result.Diagnostics | Where-Object { $_.rule -eq 'skills-loaded-log-append-only' -and $_.severity -eq 'error' }).Count | Should -BeGreaterThan 0
        } finally { Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'rejects a log line that does not have 5 tab-separated fields' {
        $repo = New-TempRepo
        try {
            $log = Join-Path $repo 'skills-loaded.log'
            Set-Content -LiteralPath $log -Value "2026-04-21T12:00:00Z`tgsf-sci`t1.0.0" -Encoding utf8
            $result = Invoke-Profile -RepoRoot $repo -SkillsLoadedLogPaths @($log)
            ($result.Diagnostics | Where-Object { $_.rule -eq 'skills-loaded-log-append-only' -and $_.severity -eq 'error' }).Count | Should -BeGreaterThan 0
        } finally { Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Describe 'Test-FsiSustainabilityProfile - disclaimer-drift (Rule 5)' -Tag 'Unit' {
    It 'emits a warning when the Sustainability Planning block is absent (pre-Step-5.10)' {
        $repo = New-TempRepo
        try {
            $result = Invoke-Profile -RepoRoot $repo
            ($result.Diagnostics | Where-Object { $_.rule -eq 'disclaimer-drift' -and $_.severity -eq 'warning' }).Count | Should -BeGreaterThan 0
        } finally { Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'emits an error when ExpectedDisclaimerHash differs from the actual hash' {
        $repo = New-TempRepo
        try {
            $disclaimer = Join-Path $repo '.github/instructions/shared/disclaimer-language.instructions.md'
            $body = @'
# Disclaimers

## Sustainability Planning

> [!CAUTION]
> Directional sustainability estimate produced by an AI planner. Not an audited disclosure.

## Other
body
'@
            Set-Content -LiteralPath $disclaimer -Value $body -Encoding utf8
            $result = Invoke-Profile -RepoRoot $repo -ExpectedDisclaimerHash 'deadbeef'
            ($result.Diagnostics | Where-Object { $_.rule -eq 'disclaimer-drift' -and $_.severity -eq 'error' }).Count | Should -BeGreaterThan 0
        } finally { Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Describe 'Test-FsiSustainabilityProfile - inline-disclaimer (DD-13)' -Tag 'Unit' {
    BeforeAll {
        $script:BacklogFooter = '> Directional sustainability estimate produced by an AI planner. Not an audited disclosure. Review by a qualified sustainability professional and applicable disclosure-framework counsel (CSRD/ESRS, SEC climate rules, GHG Protocol, TCFD, ISO 14064/14067) is required before external use.'
        $script:ActiveControlsDisclaimer = 'Directional sustainability estimate produced by an AI planner. Not an audited disclosure. Review by a qualified sustainability professional and applicable disclosure-framework counsel (CSRD/ESRS, SEC climate rules, GHG Protocol, TCFD, ISO 14064/14067) is required before external use.'
        $script:SciBudgetsHeader = @(
            '# Directional SCI estimate (gCO2eq, per functional unit) generated by an AI planner.',
            '# Measurement-class precedence: deterministic > estimated > heuristic > user-declared.',
            '# Not an audited disclosure; review by qualified sustainability and disclosure-framework counsel required before external use.'
        ) -join "`n"
    }

    It 'rejects a backlog item that does not end with the verbatim footer' {
        $repo = New-TempRepo
        try {
            $artifact = Join-Path $repo '.copilot-tracking/sustainability-plans/demo/backlog/item-1.md'
            New-Item -ItemType Directory -Path (Split-Path $artifact) -Force | Out-Null
            Set-Content -LiteralPath $artifact -Value "# Item 1`n`nbody without footer" -Encoding utf8
            $result = Invoke-Profile -RepoRoot $repo -ArtifactPaths @($artifact)
            ($result.Diagnostics | Where-Object { $_.rule -eq 'inline-disclaimer-backlog-footer' -and $_.severity -eq 'error' }).Count | Should -BeGreaterThan 0
        } finally { Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'accepts a backlog item that ends with the verbatim footer' {
        $repo = New-TempRepo
        try {
            $artifact = Join-Path $repo '.copilot-tracking/sustainability-plans/demo/backlog/item-1.md'
            New-Item -ItemType Directory -Path (Split-Path $artifact) -Force | Out-Null
            Set-Content -LiteralPath $artifact -Value "# Item 1`n`nbody`n`n$script:BacklogFooter" -Encoding utf8
            $result = Invoke-Profile -RepoRoot $repo -ArtifactPaths @($artifact)
            ($result.Diagnostics | Where-Object { $_.rule -eq 'inline-disclaimer-backlog-footer' }).Count | Should -Be 0
        } finally { Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'rejects an active-controls.json missing the disclaimer field' {
        $repo = New-TempRepo
        try {
            $artifact = Join-Path $repo '.copilot-tracking/sustainability-plans/demo/active-controls.json'
            New-Item -ItemType Directory -Path (Split-Path $artifact) -Force | Out-Null
            Set-Content -LiteralPath $artifact -Value '{"controls": []}' -Encoding utf8
            $result = Invoke-Profile -RepoRoot $repo -ArtifactPaths @($artifact)
            ($result.Diagnostics | Where-Object { $_.rule -eq 'inline-disclaimer-active-controls' -and $_.severity -eq 'error' }).Count | Should -BeGreaterThan 0
        } finally { Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'rejects a sci-budgets file missing the verbatim 3-line header' {
        $repo = New-TempRepo
        try {
            $artifact = Join-Path $repo '.copilot-tracking/sustainability-plans/demo/sci-budgets/web.yml'
            New-Item -ItemType Directory -Path (Split-Path $artifact) -Force | Out-Null
            Set-Content -LiteralPath $artifact -Value "budgets: []" -Encoding utf8
            $result = Invoke-Profile -RepoRoot $repo -ArtifactPaths @($artifact)
            ($result.Diagnostics | Where-Object { $_.rule -eq 'inline-disclaimer-sci-budgets-header' -and $_.severity -eq 'error' }).Count | Should -BeGreaterThan 0
        } finally { Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue }
    }
}
