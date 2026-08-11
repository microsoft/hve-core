#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

# Discovery-time capability probe: the Bash parity fixtures execute the real
# component-copy.sh, which needs both an interpreter and jq.
$script:BashAvailable = [bool](Get-Command bash -ErrorAction SilentlyContinue) -and [bool](Get-Command jq -ErrorAction SilentlyContinue)

BeforeAll {
    $script:PowerShellScript = (Resolve-Path (Join-Path $PSScriptRoot '../scripts/component-copy.ps1')).Path
    $script:BashScript = (Resolve-Path (Join-Path $PSScriptRoot '../scripts/component-copy.sh')).Path
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../../../..')).Path
    $script:FixtureCounter = 0

    function script:New-ComponentCopyFixture {
        param([string]$Version = '3.3.106')

        $script:FixtureCounter++
        $root = Join-Path $TestDrive "component-copy-$($script:FixtureCounter)"
        $source = Join-Path $root 'source'
        $target = Join-Path $root 'target'

        $sourceFiles = @{
            '.github/agents/hve-core/rpi-agent.agent.md'                  = '# RPI Agent'
            '.github/agents/hve-core/subagents/rpi-planner.agent.md'      = '# RPI Planner'
            '.github/agents/experimental/pptx.agent.md'                   = '# PPTX'
            '.github/prompts/hve-core/rpi.prompt.md'                      = '# RPI Prompt'
            '.github/instructions/hve-core/copilot-tracking.instructions.md' = '# Tracking'
            '.github/skills/rpi/rpi-plan/SKILL.md'                        = '# RPI Plan Skill'
            '.github/skills/rpi/rpi-plan/references/notes.md'             = '# Notes'
            '.github/skills/rpi/rpi-plan/.venv/lib/site.py'               = 'sentinel_venv'
            '.github/skills/rpi/rpi-plan/.VENV/lib/upper.py'              = 'sentinel_upper_venv'
            '.github/skills/rpi/rpi-plan/tests/test_plan.py'              = 'sentinel_tests'
            '.github/skills/rpi/rpi-plan/.PyTest_Cache/result.txt'        = 'sentinel_upper_cache'
            '.github/hooks/shared/telemetry.json'                         = '{}'
        }
        foreach ($relative in $sourceFiles.Keys) {
            $full = Join-Path $source $relative
            New-Item -ItemType Directory -Path (Split-Path $full -Parent) -Force | Out-Null
            Set-Content -LiteralPath $full -Value $sourceFiles[$relative] -NoNewline
        }

        $symlinkAvailable = $true
        try {
            New-Item -ItemType SymbolicLink `
                -Path (Join-Path $source '.github/skills/rpi/rpi-plan/linked-notes.md') `
                -Target (Join-Path $source '.github/skills/rpi/rpi-plan/references/notes.md') `
                -ErrorAction Stop | Out-Null
            New-Item -ItemType SymbolicLink `
                -Path (Join-Path $source '.github/skills/rpi/rpi-plan/linked-references') `
                -Target (Join-Path $source '.github/skills/rpi/rpi-plan/references') `
                -ErrorAction Stop | Out-Null
        }
        catch {
            $symlinkAvailable = $false
        }

        $catalog = [ordered]@{
            name    = 'hve-core'
            plugins = @(
                [ordered]@{
                    name     = 'hve-core'
                    version  = $Version
                    agents   = @('agents/hve-core/rpi-agent.md', 'agents/hve-core/subagents/rpi-planner.md')
                    commands = @('commands/hve-core/rpi.md')
                    rules    = @('rules/hve-core/copilot-tracking.instructions.md')
                    skills   = @('skills/rpi/rpi-plan')
                    hooks    = 'hooks/shared/telemetry.json'
                    'x-hve'  = [ordered]@{
                        componentMaturity = [ordered]@{
                            'hooks/shared/telemetry.json' = 'experimental'
                        }
                    }
                }
                [ordered]@{
                    name     = 'hve-core-all'
                    version  = $Version
                    agents   = @('agents/experimental/pptx.md', 'agents/hve-core/rpi-agent.md', 'agents/hve-core/subagents/rpi-planner.md')
                    commands = @('commands/hve-core/rpi.md')
                    rules    = @('rules/hve-core/copilot-tracking.instructions.md')
                    skills   = @('skills/rpi/rpi-plan')
                    hooks    = 'hooks/shared/telemetry.json'
                    'x-hve'  = [ordered]@{
                        componentMaturity = [ordered]@{
                            'agents/experimental/pptx.md' = 'experimental'
                            'hooks/shared/telemetry.json' = 'experimental'
                        }
                        profiles          = [ordered]@{
                            starter = @('agents/hve-core/rpi-agent.md', 'skills/rpi/rpi-plan')
                        }
                    }
                }
            )
        }
        $catalogPath = Join-Path $source '.github/plugin/marketplace.json'
        New-Item -ItemType Directory -Path (Split-Path $catalogPath -Parent) -Force | Out-Null
        $catalog | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $catalogPath -NoNewline

        Set-Content -LiteralPath (Join-Path $source 'package.json') -Value "{ `"version`": `"$Version`" }" -NoNewline
        New-Item -ItemType Directory -Path $target -Force | Out-Null

        return [pscustomobject]@{ Root = $root; Source = $source; Target = $target; SymlinkAvailable = $symlinkAvailable }
    }

    function script:Invoke-ComponentCopy {
        param(
            [pscustomobject]$Fixture,
            [string[]]$Component,
            [string]$PackageName = 'hve-core-all',
            [string]$SelectionName = 'custom',
            [switch]$ReportOnly,
            [switch]$KeepExisting,
            [string[]]$Collisions = @()
        )

        $arguments = @{
            HveCoreBasePath = $Fixture.Source
            TargetRoot      = $Fixture.Target
            PackageName     = $PackageName
            SelectionName   = $SelectionName
            Component       = $Component
        }
        if ($ReportOnly) { $arguments['ReportOnly'] = $true }
        if ($KeepExisting) { $arguments['KeepExisting'] = $true }
        if ($Collisions.Count -gt 0) { $arguments['Collisions'] = $Collisions }

        return (& $script:PowerShellScript @arguments 6>&1 | Out-String)
    }

    function script:Invoke-BashComponentCopy {
        param(
            [pscustomobject]$Fixture,
            [string[]]$Component,
            [string]$PackageName = 'hve-core-all',
            [string]$SelectionName = 'custom',
            [hashtable]$Environment = @{}
        )

        $saved = @{}
        foreach ($key in $Environment.Keys) {
            $saved[$key] = [System.Environment]::GetEnvironmentVariable($key)
            [System.Environment]::SetEnvironmentVariable($key, $Environment[$key])
        }
        try {
            $output = & bash $script:BashScript $Fixture.Source $Fixture.Target $PackageName $SelectionName @Component 2>&1 | Out-String
        }
        finally {
            foreach ($key in $Environment.Keys) { [System.Environment]::SetEnvironmentVariable($key, $saved[$key]) }
        }
        return $output
    }

    function script:Get-TrackingManifest {
        param([pscustomobject]$Fixture)
        return Get-Content -LiteralPath (Join-Path $Fixture.Target '.hve-tracking.json') -Raw | ConvertFrom-Json -AsHashtable
    }

    function script:Get-TargetFile {
        param([pscustomobject]$Fixture)
        $base = (Resolve-Path -LiteralPath $Fixture.Target).Path
        return @(Get-ChildItem -LiteralPath $Fixture.Target -Recurse -File -Force |
                ForEach-Object { ($_.FullName.Substring($base.Length) -replace '\\', '/').TrimStart('/') } |
                Sort-Object)
    }
}

Describe 'component-copy parameter contract' -Tag 'Unit' {
    BeforeAll {
        $script:command = Get-Command -Name $script:PowerShellScript
        $script:powerShellSource = Get-Content -LiteralPath $script:PowerShellScript -Raw
        $script:bashSource = Get-Content -LiteralPath $script:BashScript -Raw
    }

    It 'Declares the mandatory selection and target parameters' {
        foreach ($name in @('HveCoreBasePath', 'TargetRoot', 'PackageName', 'SelectionName', 'Component')) {
            $script:command.Parameters.Keys | Should -Contain $name
            $attributes = @($script:command.Parameters[$name].Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] })
            @($attributes | Where-Object { $_.Mandatory }).Count | Should -Be 1 -Because "$name identifies what is copied and where"
        }
    }

    It 'Requires an explicit package with no production default' {
        $script:command.Parameters['PackageName'].ParameterType | Should -Be ([string])
        $script:command.Parameters['PackageName'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory |
            Should -Contain $true
        $script:powerShellSource | Should -Not -Match '\[string\]\$PackageName\s*='
        $script:bashSource | Should -Match '<package_name>'
    }

    It 'Writes package identity from the PowerShell implementation' {
        $script:powerShellSource | Should -Match '\$PackageName'
        $script:powerShellSource | Should -Match '\$SelectionName'
        $script:powerShellSource | Should -Match "schemaVersion = \`$schemaVersion"
        $script:powerShellSource | Should -Not -Match '(?i)PackageId'
    }

    It 'Writes package identity from the Bash implementation' {
        $script:bashSource | Should -Match 'package_name'
        $script:bashSource | Should -Match 'selection_name'
        $script:bashSource | Should -Match 'schemaVersion: \$schema'
        $script:bashSource | Should -Not -Match '(?i)package_id'
    }
}

Describe 'component-copy path mapping' -Tag 'Unit' {
    BeforeEach { $script:fixture = New-ComponentCopyFixture }

    It 'Maps every kind to its canonical target root without flattening paths' {
        Invoke-ComponentCopy -Fixture $script:fixture -Component @(
            'agents/hve-core/subagents/rpi-planner.md'
            'commands/hve-core/rpi.md'
            'rules/hve-core/copilot-tracking.instructions.md'
        ) | Out-Null

        Get-TargetFile -Fixture $script:fixture | Should -Be @(
            '.github/agents/hve-core/subagents/rpi-planner.agent.md'
            '.github/instructions/hve-core/copilot-tracking.instructions.md'
            '.github/prompts/hve-core/rpi.prompt.md'
            '.hve-tracking.json'
        )
    }

    It 'Copies source content verbatim' {
        Invoke-ComponentCopy -Fixture $script:fixture -Component @('agents/hve-core/rpi-agent.md') | Out-Null

        Get-Content -LiteralPath (Join-Path $script:fixture.Target '.github/agents/hve-core/rpi-agent.agent.md') -Raw |
            Should -Be '# RPI Agent'
    }

    It 'Copies a skill as a complete directory' {
        Invoke-ComponentCopy -Fixture $script:fixture -Component @('skills/rpi/rpi-plan') | Out-Null

        Test-Path -LiteralPath (Join-Path $script:fixture.Target '.github/skills/rpi/rpi-plan/SKILL.md') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $script:fixture.Target '.github/skills/rpi/rpi-plan/references/notes.md') | Should -BeTrue
    }

    It 'Excludes local environment and test directories from a skill copy' {
        Invoke-ComponentCopy -Fixture $script:fixture -Component @('skills/rpi/rpi-plan') | Out-Null

        Test-Path -LiteralPath (Join-Path $script:fixture.Target '.github/skills/rpi/rpi-plan/.venv') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $script:fixture.Target '.github/skills/rpi/rpi-plan/.VENV') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $script:fixture.Target '.github/skills/rpi/rpi-plan/tests') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $script:fixture.Target '.github/skills/rpi/rpi-plan/.PyTest_Cache') | Should -BeFalse
    }

    It 'Omits file symlinks and does not traverse directory symlinks' {
        if (-not $script:fixture.SymlinkAvailable) { Set-ItResult -Skipped -Because 'symbolic links are unavailable'; return }

        Invoke-ComponentCopy -Fixture $script:fixture -Component @('skills/rpi/rpi-plan') | Out-Null

        Test-Path -LiteralPath (Join-Path $script:fixture.Target '.github/skills/rpi/rpi-plan/linked-notes.md') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $script:fixture.Target '.github/skills/rpi/rpi-plan/linked-references') | Should -BeFalse
        @((Get-TrackingManifest -Fixture $script:fixture).files.Keys | Where-Object { $_ -match 'linked-' }) | Should -BeNullOrEmpty
    }

    It 'Copies a repeated component once' {
        Invoke-ComponentCopy -Fixture $script:fixture -Component @('skills/rpi/rpi-plan', 'skills/rpi/rpi-plan/') | Out-Null

        @((Get-TrackingManifest -Fixture $script:fixture).selection.components) | Should -Be @('skills/rpi/rpi-plan')
    }

    It 'Overwrites an existing managed file' {
        $existing = Join-Path $script:fixture.Target '.github/agents/hve-core/rpi-agent.agent.md'
        New-Item -ItemType Directory -Path (Split-Path $existing -Parent) -Force | Out-Null
        Set-Content -LiteralPath $existing -Value '# Local edit' -NoNewline

        Invoke-ComponentCopy -Fixture $script:fixture -Component @('agents/hve-core/rpi-agent.md') | Out-Null

        Get-Content -LiteralPath $existing -Raw | Should -Be '# RPI Agent'
    }
}

Describe 'component-copy tracking manifest' -Tag 'Unit' {
    BeforeEach { $script:fixture = New-ComponentCopyFixture -Version '3.3.106' }

    It 'Writes exactly the version 2 manifest keys' {
        Invoke-ComponentCopy -Fixture $script:fixture -Component @('agents/hve-core/rpi-agent.md') -SelectionName 'starter' | Out-Null

        $manifest = Get-TrackingManifest -Fixture $script:fixture
        @($manifest.Keys | Sort-Object) | Should -Be @('files', 'installed', 'schemaVersion', 'selection', 'source', 'version')
        $manifest.schemaVersion | Should -Be 2
        $manifest.Keys | Should -Not -Contain 'package'
    }

    It 'Records the source repository, version, and ISO 8601 install timestamp' {
        Invoke-ComponentCopy -Fixture $script:fixture -Component @('agents/hve-core/rpi-agent.md') | Out-Null

        $manifest = Get-TrackingManifest -Fixture $script:fixture
        $manifest.source | Should -Be 'microsoft/hve-core'
        $manifest.version | Should -Be '3.3.106'
        [System.DateTimeOffset]::TryParse([string]$manifest.installed, [ref]([System.DateTimeOffset]::MinValue)) | Should -BeTrue
    }

    It 'Records the selection profile and component paths' {
        Invoke-ComponentCopy -Fixture $script:fixture -SelectionName 'starter' -Component @('skills/rpi/rpi-plan', 'agents/hve-core/rpi-agent.md') | Out-Null

        $selection = (Get-TrackingManifest -Fixture $script:fixture).selection
        @($selection.Keys) | Should -Be @('package', 'profile', 'components')
        $selection.package | Should -Be 'hve-core-all'
        $selection.profile | Should -Be 'starter'
        @($selection.components) | Should -Be @('agents/hve-core/rpi-agent.md', 'skills/rpi/rpi-plan')
    }

    It 'Records component, kind, maturity, version, hash, and status for each file' {
        Invoke-ComponentCopy -Fixture $script:fixture -Component @('agents/experimental/pptx.md') | Out-Null

        $entry = (Get-TrackingManifest -Fixture $script:fixture).files['.github/agents/experimental/pptx.agent.md']
        @($entry.Keys | Sort-Object) | Should -Be @('component', 'kind', 'maturity', 'sha256', 'status', 'version')
        $entry.component | Should -Be 'agents/experimental/pptx.md'
        $entry.kind | Should -Be 'agent'
        $entry.maturity | Should -Be 'experimental'
        $entry.version | Should -Be '3.3.106'
        $entry.status | Should -Be 'managed'
        $entry.sha256 | Should -Be (Get-FileHash -LiteralPath (Join-Path $script:fixture.Target '.github/agents/experimental/pptx.agent.md') -Algorithm SHA256).Hash.ToLower()
    }

    It 'Defaults an unlabeled component to stable maturity' {
        Invoke-ComponentCopy -Fixture $script:fixture -Component @('agents/hve-core/rpi-agent.md') | Out-Null

        (Get-TrackingManifest -Fixture $script:fixture).files['.github/agents/hve-core/rpi-agent.agent.md'].maturity | Should -Be 'stable'
    }

    It 'Keys every skill file to its owning skill component' {
        Invoke-ComponentCopy -Fixture $script:fixture -Component @('skills/rpi/rpi-plan') | Out-Null

        $files = (Get-TrackingManifest -Fixture $script:fixture).files
        $trackedKeys = [string[]]@($files.Keys)
        [array]::Sort($trackedKeys, [System.StringComparer]::Ordinal)
        $trackedKeys | Should -Be @(
            '.github/skills/rpi/rpi-plan/SKILL.md'
            '.github/skills/rpi/rpi-plan/references/notes.md'
        )
        foreach ($key in $files.Keys) {
            $files[$key].component | Should -Be 'skills/rpi/rpi-plan'
            $files[$key].kind | Should -Be 'skill'
        }
    }

    It 'Persists no absolute target root' {
        Invoke-ComponentCopy -Fixture $script:fixture -Component @('agents/hve-core/rpi-agent.md') | Out-Null

        Get-Content -LiteralPath (Join-Path $script:fixture.Target '.hve-tracking.json') -Raw |
            Should -Not -Match ([regex]::Escape((Resolve-Path -LiteralPath $script:fixture.Target).Path))
    }
}

Describe 'component-copy preflight rejection' -Tag 'Unit' {
    BeforeEach { $script:fixture = New-ComponentCopyFixture }

    It 'Rejects a traversal component path before any write' {
        { Invoke-ComponentCopy -Fixture $script:fixture -Component @('agents/../../etc/passwd') } |
            Should -Throw -ExpectedMessage '*relative path segments*'

        Get-TargetFile -Fixture $script:fixture | Should -BeNullOrEmpty
    }

    It 'Rejects an absolute component path' {
        { Invoke-ComponentCopy -Fixture $script:fixture -Component @('/etc/passwd') } |
            Should -Throw -ExpectedMessage '*relative to the package root*'
    }

    It 'Rejects a backslash component path' {
        { Invoke-ComponentCopy -Fixture $script:fixture -Component @('agents\hve-core\rpi-agent.md') } |
            Should -Throw -ExpectedMessage '*forward slashes*'
    }

    It 'Rejects a component outside the four installable kinds' {
        { Invoke-ComponentCopy -Fixture $script:fixture -Component @('hooks/shared/telemetry.json') } |
            Should -Throw -ExpectedMessage '*agents, commands, rules, skills*'
    }

    It 'Rejects a partial skill selection' {
        { Invoke-ComponentCopy -Fixture $script:fixture -Component @('skills/rpi/rpi-plan/SKILL.md') } |
            Should -Throw -ExpectedMessage '*not declared membership*'

        Get-TargetFile -Fixture $script:fixture | Should -BeNullOrEmpty
    }

    It 'Rejects a component that the recipe does not declare' {
        { Invoke-ComponentCopy -Fixture $script:fixture -Component @('agents/hve-core/absent.md') } |
            Should -Throw -ExpectedMessage '*not declared membership*'
    }

    It 'Rejects an unknown package before any write' {
        { Invoke-ComponentCopy -Fixture $script:fixture -PackageName 'not-a-package' -Component @('agents/hve-core/rpi-agent.md') } |
            Should -Throw -ExpectedMessage "*declares no package named 'not-a-package'*"

        Get-TargetFile -Fixture $script:fixture | Should -BeNullOrEmpty
    }

    It 'Rejects a component outside the selected focused package before any write' {
        { Invoke-ComponentCopy -Fixture $script:fixture -PackageName 'hve-core' -Component @('agents/experimental/pptx.md') } |
            Should -Throw -ExpectedMessage "*not declared membership of the 'hve-core' marketplace recipe*"

        Get-TargetFile -Fixture $script:fixture | Should -BeNullOrEmpty
    }

    It 'Accepts shared components from focused and full packages' {
        Invoke-ComponentCopy -Fixture $script:fixture -PackageName 'hve-core' -Component @('agents/hve-core/rpi-agent.md') | Out-Null
        (Get-TrackingManifest -Fixture $script:fixture).selection.package | Should -Be 'hve-core'

        Invoke-ComponentCopy -Fixture $script:fixture -PackageName 'hve-core-all' -Component @('agents/hve-core/rpi-agent.md') | Out-Null
        (Get-TrackingManifest -Fixture $script:fixture).selection.package | Should -Be 'hve-core-all'
    }

    It 'Rejects a declared component whose source is missing' {
        Remove-Item -LiteralPath (Join-Path $script:fixture.Source '.github/agents/hve-core/rpi-agent.agent.md') -Force

        { Invoke-ComponentCopy -Fixture $script:fixture -Component @('agents/hve-core/rpi-agent.md') } |
            Should -Throw -ExpectedMessage '*has no source file*'

        Test-Path -LiteralPath (Join-Path $script:fixture.Target '.hve-tracking.json') | Should -BeFalse
    }

    It 'Rejects a target root that does not exist' {
        { & $script:PowerShellScript -HveCoreBasePath $script:fixture.Source -TargetRoot (Join-Path $script:fixture.Root 'absent') `
            -PackageName 'hve-core-all' -SelectionName 'custom' -Component @('agents/hve-core/rpi-agent.md') } | Should -Throw -ExpectedMessage '*TargetRoot*'
    }

    It 'Rejects a source without a marketplace catalog' {
        Remove-Item -LiteralPath (Join-Path $script:fixture.Source '.github/plugin/marketplace.json') -Force

        { Invoke-ComponentCopy -Fixture $script:fixture -Component @('agents/hve-core/rpi-agent.md') } |
            Should -Throw -ExpectedMessage '*Marketplace catalog not found*'
    }
}

Describe 'component-copy manifest schema gate' -Tag 'Unit' {
    BeforeEach { $script:fixture = New-ComponentCopyFixture }

    It 'Rejects a version 1 manifest with clean-reinstall guidance before any write' {
        $legacy = @{ source = 'microsoft/hve-core'; version = '3.3.100'; package = 'hve-core'; files = @{} }
        $legacy | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $script:fixture.Target '.hve-tracking.json')

        { Invoke-ComponentCopy -Fixture $script:fixture -Component @('agents/hve-core/rpi-agent.md') } |
            Should -Throw -ExpectedMessage '*clean reinstall*'

        Test-Path -LiteralPath (Join-Path $script:fixture.Target '.github/agents') | Should -BeFalse
    }

    It 'Rejects an unsupported future schema version' {
        @{ schemaVersion = 3; files = @{} } | ConvertTo-Json -Depth 10 |
            Set-Content -LiteralPath (Join-Path $script:fixture.Target '.hve-tracking.json')

        { Invoke-ComponentCopy -Fixture $script:fixture -Component @('agents/hve-core/rpi-agent.md') } |
            Should -Throw -ExpectedMessage "*schemaVersion '3'*"
    }
}

Describe 'component-copy collision retention and eject' -Tag 'Unit' {
    BeforeEach { $script:fixture = New-ComponentCopyFixture }

    It 'Leaves a retained collision component untouched' {
        $existing = Join-Path $script:fixture.Target '.github/skills/rpi/rpi-plan/SKILL.md'
        New-Item -ItemType Directory -Path (Split-Path $existing -Parent) -Force | Out-Null
        Set-Content -LiteralPath $existing -Value '# Local skill' -NoNewline

        $output = Invoke-ComponentCopy -Fixture $script:fixture -Component @('skills/rpi/rpi-plan', 'agents/hve-core/rpi-agent.md') `
            -KeepExisting -Collisions @('skills/rpi/rpi-plan')

        Get-Content -LiteralPath $existing -Raw | Should -Be '# Local skill'
        $output | Should -Match 'Kept existing: skills/rpi/rpi-plan'
        @((Get-TrackingManifest -Fixture $script:fixture).files.Keys) | Should -Be @('.github/agents/hve-core/rpi-agent.agent.md')
    }

    It 'Preserves an ejected entry and leaves its file untouched' {
        Invoke-ComponentCopy -Fixture $script:fixture -Component @('agents/hve-core/rpi-agent.md') | Out-Null
        $manifestPath = Join-Path $script:fixture.Target '.hve-tracking.json'
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -AsHashtable
        $manifest.files['.github/agents/hve-core/rpi-agent.agent.md'].status = 'ejected'
        $manifest.files['.github/agents/hve-core/rpi-agent.agent.md'].ejectedAt = '2026-08-02T00:00:00Z'
        $manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $manifestPath
        Set-Content -LiteralPath (Join-Path $script:fixture.Target '.github/agents/hve-core/rpi-agent.agent.md') -Value '# User owned' -NoNewline

        $output = Invoke-ComponentCopy -Fixture $script:fixture -Component @('agents/hve-core/rpi-agent.md')

        $output | Should -Match 'Skipped ejected: \.github/agents/hve-core/rpi-agent\.agent\.md'
        Get-Content -LiteralPath (Join-Path $script:fixture.Target '.github/agents/hve-core/rpi-agent.agent.md') -Raw | Should -Be '# User owned'
        $entry = (Get-TrackingManifest -Fixture $script:fixture).files['.github/agents/hve-core/rpi-agent.agent.md']
        $entry.status | Should -Be 'ejected'
        Get-Content -LiteralPath $manifestPath -Raw | Should -Match '"ejectedAt": "2026-08-02T00:00:00Z"'
    }

    It 'Preserves omitted managed records across a narrower selection' {
        Invoke-ComponentCopy -Fixture $script:fixture -Component @('agents/hve-core/rpi-agent.md', 'skills/rpi/rpi-plan') | Out-Null
        $before = Get-TrackingManifest -Fixture $script:fixture

        Invoke-ComponentCopy -Fixture $script:fixture -Component @('agents/hve-core/rpi-agent.md') | Out-Null
        $after = Get-TrackingManifest -Fixture $script:fixture

        @($after.files.Keys | Sort-Object) | Should -Be @($before.files.Keys | Sort-Object)
        @($after.selection.components) | Should -Be @('agents/hve-core/rpi-agent.md', 'skills/rpi/rpi-plan')
        $after.files['.github/skills/rpi/rpi-plan/SKILL.md'].status | Should -Be 'managed'
    }

    It 'Preserves an omitted ejected record and never overwrites it after re-inclusion' {
        Invoke-ComponentCopy -Fixture $script:fixture -Component @('agents/hve-core/rpi-agent.md', 'skills/rpi/rpi-plan') | Out-Null
        $manifestPath = Join-Path $script:fixture.Target '.hve-tracking.json'
        $manifest = Get-TrackingManifest -Fixture $script:fixture
        $agentPath = '.github/agents/hve-core/rpi-agent.agent.md'
        $manifest.files[$agentPath].status = 'ejected'
        $manifest.files[$agentPath].ejectedAt = '2026-08-03T00:00:00Z'
        $manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $manifestPath
        Set-Content -LiteralPath (Join-Path $script:fixture.Target $agentPath) -Value '# User owned' -NoNewline

        Invoke-ComponentCopy -Fixture $script:fixture -Component @('skills/rpi/rpi-plan') | Out-Null
        Invoke-ComponentCopy -Fixture $script:fixture -Component @('agents/hve-core/rpi-agent.md') | Out-Null

        $after = Get-TrackingManifest -Fixture $script:fixture
        $after.files[$agentPath].status | Should -Be 'ejected'
        Get-Content -LiteralPath $manifestPath -Raw | Should -Match '"ejectedAt": "2026-08-03T00:00:00Z"'
        Get-Content -LiteralPath (Join-Path $script:fixture.Target $agentPath) -Raw | Should -Be '# User owned'
        @($after.selection.components) | Should -Be @('agents/hve-core/rpi-agent.md', 'skills/rpi/rpi-plan')
    }
}

Describe 'component-copy report-only preflight' -Tag 'Unit' {
    BeforeEach { $script:fixture = New-ComponentCopyFixture }

    It 'Reports canonical maturity for every component without writing' {
        $output = Invoke-ComponentCopy -Fixture $script:fixture -ReportOnly -Component @('agents/experimental/pptx.md', 'skills/rpi/rpi-plan')

        $output | Should -Match 'COMPONENT=agents/experimental/pptx\.md\|KIND=agent\|MATURITY=experimental\|TARGET=\.github/agents/experimental/pptx\.agent\.md\|EXISTS=false'
        $output | Should -Match 'COMPONENT=skills/rpi/rpi-plan\|KIND=skill\|MATURITY=stable\|TARGET=\.github/skills/rpi/rpi-plan\|EXISTS=false'
        $output | Should -Match 'COLLISIONS_DETECTED=false'
        Get-TargetFile -Fixture $script:fixture | Should -BeNullOrEmpty
    }

    It 'Reports a file collision on the full target path' {
        $existing = Join-Path $script:fixture.Target '.github/agents/hve-core/rpi-agent.agent.md'
        New-Item -ItemType Directory -Path (Split-Path $existing -Parent) -Force | Out-Null
        Set-Content -LiteralPath $existing -Value '# Local' -NoNewline

        $output = Invoke-ComponentCopy -Fixture $script:fixture -ReportOnly -Component @('agents/hve-core/rpi-agent.md')

        $output | Should -Match 'COLLISIONS_DETECTED=true'
        $output | Should -Match 'COLLISION_COMPONENTS=agents/hve-core/rpi-agent\.md'
        $output | Should -Match 'COLLISION_TARGETS=\.github/agents/hve-core/rpi-agent\.agent\.md'
    }

    It 'Reports a skill collision on the target directory' {
        New-Item -ItemType Directory -Path (Join-Path $script:fixture.Target '.github/skills/rpi/rpi-plan') -Force | Out-Null

        $output = Invoke-ComponentCopy -Fixture $script:fixture -ReportOnly -Component @('skills/rpi/rpi-plan')

        $output | Should -Match 'COLLISION_COMPONENTS=skills/rpi/rpi-plan'
        $output | Should -Match 'COLLISION_TARGETS=\.github/skills/rpi/rpi-plan'
    }
}

Describe 'component-copy production starter selection' -Tag 'Unit' {
    BeforeAll {
        Import-Module (Join-Path $script:RepoRoot 'scripts/lib/Modules/MarketplaceHelpers.psm1') -Force

        $catalog = Get-MarketplaceCatalog -Path (Join-Path $script:RepoRoot '.github/plugin/marketplace.json')
        $entry = @($catalog['plugins']) | Where-Object { $_['name'] -eq 'hve-core-all' }
        $agentIndex = Get-MarketplaceAgentIndex -Catalog $catalog -RepoRoot $script:RepoRoot
        $script:StarterSelection = @(Resolve-MarketplaceComponentSelection -Entry $entry -RepoRoot $script:RepoRoot -AgentIndex $agentIndex -ProfileName 'starter')
        $script:ProductionTarget = Join-Path $TestDrive 'production-starter'
        New-Item -ItemType Directory -Path $script:ProductionTarget -Force | Out-Null
    }

    AfterAll {
        Remove-Module MarketplaceHelpers -Force -ErrorAction SilentlyContinue
    }

    It 'Copies the resolved starter profile into the canonical target layout' {
        & $script:PowerShellScript -HveCoreBasePath $script:RepoRoot -TargetRoot $script:ProductionTarget `
            -PackageName 'hve-core-all' -SelectionName 'starter' `
            -Component @($script:StarterSelection | ForEach-Object { $_.PackagePath }) 6>&1 | Out-Null

        Test-Path -LiteralPath (Join-Path $script:ProductionTarget '.github/agents/hve-core/rpi-agent.agent.md') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $script:ProductionTarget '.github/prompts/hve-core/rpi.prompt.md') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $script:ProductionTarget '.github/instructions/hve-core/hve-builder.instructions.md') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $script:ProductionTarget '.github/skills/rpi/rpi-plan/SKILL.md') | Should -BeTrue
    }

    It 'Tracks every starter component with canonical maturity' {
        $manifest = Get-Content -LiteralPath (Join-Path $script:ProductionTarget '.hve-tracking.json') -Raw | ConvertFrom-Json -AsHashtable

        $manifest.schemaVersion | Should -Be 2
        $manifest.selection.package | Should -Be 'hve-core-all'
        $manifest.selection.profile | Should -Be 'starter'
        @($manifest.selection.components).Count | Should -Be @($script:StarterSelection).Count
        $tracked = @($manifest.files.Values | ForEach-Object { $_.maturity } | Sort-Object -Unique)
        $tracked | Should -Contain 'experimental' -Because 'the starter includes experimental Vally content and must disclose it'
    }
}

Describe 'component-copy PowerShell and Bash parity' -Tag 'Unit' -Skip:(-not $script:BashAvailable) {
    BeforeEach {
        $script:powerShellFixture = New-ComponentCopyFixture -Version '3.3.106'
        $script:bashFixture = New-ComponentCopyFixture -Version '3.3.106'
        $script:AllComponents = @(
            'agents/experimental/pptx.md'
            'agents/hve-core/subagents/rpi-planner.md'
            'commands/hve-core/rpi.md'
            'rules/hve-core/copilot-tracking.instructions.md'
            'skills/rpi/rpi-plan'
        )
    }

    It 'Copies the same files with the same content' {
        Invoke-ComponentCopy -Fixture $script:powerShellFixture -SelectionName 'starter' -Component $script:AllComponents | Out-Null
        Invoke-BashComponentCopy -Fixture $script:bashFixture -SelectionName 'starter' -Component $script:AllComponents | Out-Null

        $powerShellFiles = Get-TargetFile -Fixture $script:powerShellFixture
        Get-TargetFile -Fixture $script:bashFixture | Should -Be $powerShellFiles

        foreach ($relative in ($powerShellFiles | Where-Object { $_ -ne '.hve-tracking.json' })) {
            Get-Content -LiteralPath (Join-Path $script:bashFixture.Target $relative) -Raw |
                Should -Be (Get-Content -LiteralPath (Join-Path $script:powerShellFixture.Target $relative) -Raw) -Because "'$relative' must not depend on the interpreter"
        }
    }

    It 'Writes equivalent manifests' {
        Invoke-ComponentCopy -Fixture $script:powerShellFixture -SelectionName 'starter' -Component $script:AllComponents | Out-Null
        Invoke-BashComponentCopy -Fixture $script:bashFixture -SelectionName 'starter' -Component $script:AllComponents | Out-Null

        $powerShellManifest = Get-TrackingManifest -Fixture $script:powerShellFixture
        $bashManifest = Get-TrackingManifest -Fixture $script:bashFixture

        @($bashManifest.Keys | Sort-Object) | Should -Be @($powerShellManifest.Keys | Sort-Object)
        $bashManifest.schemaVersion | Should -Be $powerShellManifest.schemaVersion
        $bashManifest.source | Should -Be $powerShellManifest.source
        $bashManifest.version | Should -Be $powerShellManifest.version
        $bashManifest.selection.package | Should -Be $powerShellManifest.selection.package
        $bashManifest.selection.profile | Should -Be $powerShellManifest.selection.profile
        @($bashManifest.selection.components) | Should -Be @($powerShellManifest.selection.components)
        @($bashManifest.files.Keys | Sort-Object) | Should -Be @($powerShellManifest.files.Keys | Sort-Object)

        foreach ($key in $powerShellManifest.files.Keys) {
            foreach ($field in @('component', 'kind', 'maturity', 'version', 'sha256', 'status')) {
                $bashManifest.files[$key][$field] | Should -Be $powerShellManifest.files[$key][$field] -Because "'$key' field '$field' must match"
            }
        }
        [System.DateTimeOffset]::TryParse([string]$bashManifest.installed, [ref]([System.DateTimeOffset]::MinValue)) | Should -BeTrue
    }

    It 'Produces identical copy output' {
        $powerShellOutput = (Invoke-ComponentCopy -Fixture $script:powerShellFixture -SelectionName 'starter' -Component $script:AllComponents).Trim()
        $bashOutput = (Invoke-BashComponentCopy -Fixture $script:bashFixture -SelectionName 'starter' -Component $script:AllComponents).Trim()

        $bashOutput | Should -Be $powerShellOutput
    }

    It 'Produces identical report-only output' {
        New-Item -ItemType Directory -Path (Join-Path $script:powerShellFixture.Target '.github/skills/rpi/rpi-plan') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:bashFixture.Target '.github/skills/rpi/rpi-plan') -Force | Out-Null

        $powerShellOutput = (Invoke-ComponentCopy -Fixture $script:powerShellFixture -ReportOnly -Component $script:AllComponents).Trim()
        $bashOutput = (Invoke-BashComponentCopy -Fixture $script:bashFixture -Component $script:AllComponents -Environment @{ REPORT_ONLY = 'true' }).Trim()

        $bashOutput | Should -Be $powerShellOutput
        $powerShellOutput | Should -Match 'COLLISIONS_DETECTED=true'
    }

    It 'Retains the same components under KEEP_EXISTING' {
        foreach ($fixture in @($script:powerShellFixture, $script:bashFixture)) {
            $existing = Join-Path $fixture.Target '.github/skills/rpi/rpi-plan/SKILL.md'
            New-Item -ItemType Directory -Path (Split-Path $existing -Parent) -Force | Out-Null
            Set-Content -LiteralPath $existing -Value '# Local skill' -NoNewline
        }
        $collisionsFile = Join-Path $script:bashFixture.Root 'collisions.txt'
        Set-Content -LiteralPath $collisionsFile -Value 'skills/rpi/rpi-plan'

        Invoke-ComponentCopy -Fixture $script:powerShellFixture -Component $script:AllComponents -KeepExisting -Collisions @('skills/rpi/rpi-plan') | Out-Null
        Invoke-BashComponentCopy -Fixture $script:bashFixture -Component $script:AllComponents -Environment @{ KEEP_EXISTING = 'true'; COLLISIONS_FILE = $collisionsFile } | Out-Null

        foreach ($fixture in @($script:powerShellFixture, $script:bashFixture)) {
            Get-Content -LiteralPath (Join-Path $fixture.Target '.github/skills/rpi/rpi-plan/SKILL.md') -Raw | Should -Be '# Local skill'
            @((Get-TrackingManifest -Fixture $fixture).files.Keys) | Should -Not -Contain '.github/skills/rpi/rpi-plan/SKILL.md'
        }
    }

    It 'Preserves identical tracking across broad and narrow reruns' {
        foreach ($fixture in @($script:powerShellFixture, $script:bashFixture)) {
            if ($fixture -eq $script:powerShellFixture) {
                Invoke-ComponentCopy -Fixture $fixture -Component $script:AllComponents | Out-Null
                Invoke-ComponentCopy -Fixture $fixture -Component @('agents/hve-core/subagents/rpi-planner.md') | Out-Null
            }
            else {
                Invoke-BashComponentCopy -Fixture $fixture -Component $script:AllComponents | Out-Null
                $LASTEXITCODE | Should -Be 0
                Invoke-BashComponentCopy -Fixture $fixture -Component @('agents/hve-core/subagents/rpi-planner.md') | Out-Null
                $LASTEXITCODE | Should -Be 0
            }
        }

        $powerShellManifest = Get-TrackingManifest -Fixture $script:powerShellFixture
        $bashManifest = Get-TrackingManifest -Fixture $script:bashFixture
        @($powerShellManifest.files.Keys | Sort-Object) | Should -Be @($bashManifest.files.Keys | Sort-Object)
        @($powerShellManifest.selection.components) | Should -Be @($bashManifest.selection.components)
        @($powerShellManifest.selection.components) | Should -Be $script:AllComponents
    }

    It 'Exits non-zero and writes nothing for a component outside recipe membership' {
        Invoke-BashComponentCopy -Fixture $script:bashFixture -Component @('agents/hve-core/absent.md') | Out-Null
        $LASTEXITCODE | Should -Not -Be 0

        Test-Path -LiteralPath (Join-Path $script:bashFixture.Target '.hve-tracking.json') | Should -BeFalse
    }

    It 'Exits non-zero for an unsupported manifest schema version' {
        $legacy = @{ source = 'microsoft/hve-core'; version = '3.3.100'; package = 'hve-core'; files = @{} }
        $legacy | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $script:bashFixture.Target '.hve-tracking.json')

        $output = Invoke-BashComponentCopy -Fixture $script:bashFixture -Component @('agents/hve-core/rpi-agent.md')
        $LASTEXITCODE | Should -Not -Be 0
        $output | Should -Match 'clean reinstall'
        Test-Path -LiteralPath (Join-Path $script:bashFixture.Target '.github/agents') | Should -BeFalse
    }
}

Describe 'component-copy destination containment' -Tag 'Unit' {
    BeforeEach {
        $script:containmentFixture = New-ComponentCopyFixture
        $script:outsideRoot = Join-Path $script:containmentFixture.Root 'outside'
        New-Item -ItemType Directory -Path $script:outsideRoot -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:outsideRoot 'bystander.txt') -Value 'original' -NoNewline
    }

    It 'Refuses a component whose destination parent is a symbolic link' {
        if (-not $script:containmentFixture.SymlinkAvailable) {
            Set-ItResult -Skipped -Because 'symbolic links are unavailable'
            return
        }

        $linkPath = Join-Path $script:containmentFixture.Target '.github/skills'
        New-Item -ItemType Directory -Path (Split-Path $linkPath -Parent) -Force | Out-Null
        New-Item -ItemType SymbolicLink -Path $linkPath -Target $script:outsideRoot -ErrorAction Stop | Out-Null

        { Invoke-ComponentCopy -Fixture $script:containmentFixture -Component @('skills/rpi/rpi-plan') } |
            Should -Throw -ExpectedMessage '*resolves through a link*'

        # The escape is what matters, not only the exception: nothing may land
        # outside the target root.
        @(Get-ChildItem -LiteralPath $script:outsideRoot -File).Name | Should -Be @('bystander.txt')
    }

    It 'Refuses a component whose destination parent is a directory junction' {
        $junctionPath = Join-Path $script:containmentFixture.Target '.github/skills'
        New-Item -ItemType Directory -Path (Split-Path $junctionPath -Parent) -Force | Out-Null

        # New-Item -ItemType Junction reports success on non-Windows hosts while
        # creating nothing, so the junction is confirmed to exist and to carry
        # the ReparsePoint attribute before the case is treated as applicable.
        $junctionCreated = $false
        try {
            New-Item -ItemType Junction -Path $junctionPath -Target $script:outsideRoot -ErrorAction Stop | Out-Null
            if (Test-Path -LiteralPath $junctionPath) {
                $entry = Get-Item -LiteralPath $junctionPath -Force
                $junctionCreated = [bool]($entry.Attributes -band [System.IO.FileAttributes]::ReparsePoint)
            }
        }
        catch {
            $junctionCreated = $false
        }

        if (-not $junctionCreated) {
            Set-ItResult -Skipped -Because 'directory junctions are unavailable on this platform'
            return
        }

        { Invoke-ComponentCopy -Fixture $script:containmentFixture -Component @('skills/rpi/rpi-plan') } |
            Should -Throw -ExpectedMessage '*resolves through a link*'

        @(Get-ChildItem -LiteralPath $script:outsideRoot -File).Name | Should -Be @('bystander.txt')
    }

    It 'Installs normally when no destination ancestor is a link' {
        Invoke-ComponentCopy -Fixture $script:containmentFixture -Component @('skills/rpi/rpi-plan') | Out-Null

        Test-Path -LiteralPath (Join-Path $script:containmentFixture.Target '.github/skills/rpi/rpi-plan/SKILL.md') |
            Should -BeTrue
    }

    It 'Refuses a link planted between the preflight check and the write' {
        if (-not $script:containmentFixture.SymlinkAvailable) {
            Set-ItResult -Skipped -Because 'symbolic links are unavailable'
            return
        }

        # Preflight passes because the path is clean, then the parent is
        # replaced by a link before the copy. The write-site re-verification is
        # the only thing standing between that race and an escaped write.
        $agentsDir = Join-Path $script:containmentFixture.Target '.github/agents'
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
        Invoke-ComponentCopy -Fixture $script:containmentFixture -Component @('agents/hve-core/rpi-agent.md') | Out-Null

        Remove-Item -LiteralPath $agentsDir -Recurse -Force
        New-Item -ItemType SymbolicLink -Path $agentsDir -Target $script:outsideRoot -ErrorAction Stop | Out-Null

        { Invoke-ComponentCopy -Fixture $script:containmentFixture -Component @('agents/hve-core/rpi-agent.md') } |
            Should -Throw -ExpectedMessage '*resolves through a link*'

        @(Get-ChildItem -LiteralPath $script:outsideRoot -File).Name | Should -Be @('bystander.txt')
    }
}

Describe 'component-copy containment parity' -Tag 'Unit' -Skip:(-not $script:BashAvailable) {
    BeforeEach {
        $script:parityFixture = New-ComponentCopyFixture
        $script:parityOutside = Join-Path $script:parityFixture.Root 'outside'
        New-Item -ItemType Directory -Path $script:parityOutside -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:parityOutside 'bystander.txt') -Value 'original' -NoNewline
    }

    It 'Reaches the same refusal verdict in both shells for a symlinked destination parent' {
        if (-not $script:parityFixture.SymlinkAvailable) {
            Set-ItResult -Skipped -Because 'symbolic links are unavailable'
            return
        }

        $linkPath = Join-Path $script:parityFixture.Target '.github/skills'
        New-Item -ItemType Directory -Path (Split-Path $linkPath -Parent) -Force | Out-Null
        New-Item -ItemType SymbolicLink -Path $linkPath -Target $script:parityOutside -ErrorAction Stop | Out-Null

        $powerShellRefused = $false
        try { Invoke-ComponentCopy -Fixture $script:parityFixture -Component @('skills/rpi/rpi-plan') | Out-Null }
        catch { $powerShellRefused = $true }

        $bashOutput = Invoke-BashComponentCopy -Fixture $script:parityFixture -Component @('skills/rpi/rpi-plan')
        $bashRefused = $LASTEXITCODE -ne 0

        # Behavioural equivalence is the contract; message text is not required
        # to match between the two implementations.
        $bashRefused | Should -Be $powerShellRefused
        $bashOutput | Should -Match 'resolves through a link'
        @(Get-ChildItem -LiteralPath $script:parityOutside -File).Name | Should -Be @('bystander.txt')
    }

    It 'Reaches the same accept verdict in both shells for a clean destination' {
        Invoke-ComponentCopy -Fixture $script:parityFixture -Component @('agents/hve-core/rpi-agent.md') | Out-Null
        $powerShellInstalled = Test-Path -LiteralPath (Join-Path $script:parityFixture.Target '.github/agents/hve-core/rpi-agent.agent.md')

        $bashFixture = New-ComponentCopyFixture
        Invoke-BashComponentCopy -Fixture $bashFixture -Component @('agents/hve-core/rpi-agent.md') | Out-Null
        $bashInstalled = Test-Path -LiteralPath (Join-Path $bashFixture.Target '.github/agents/hve-core/rpi-agent.agent.md')

        $bashInstalled | Should -Be $powerShellInstalled
        $powerShellInstalled | Should -BeTrue
    }
}
