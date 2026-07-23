#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../evals/Test-EvalSpec.ps1'
    $script:ModulePath = Join-Path $PSScriptRoot '../../evals/Modules/EvalSpecSchema.psm1'
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $script:ValidFixturesRoot = Join-Path $PSScriptRoot 'fixtures/specs/valid'
    $script:InvalidFixturesRoot = Join-Path $PSScriptRoot 'fixtures/specs/invalid'

    Import-Module $script:ModulePath -Force

    if (-not (Get-Module -ListAvailable -Name 'powershell-yaml')) {
        throw "Pester suite requires 'powershell-yaml' module. Install via Install-Module powershell-yaml -Scope CurrentUser."
    }
    Import-Module powershell-yaml -ErrorAction Stop
}

Describe 'Test-EvalSpecCompliance (module)' -Tag 'Unit' {
    Context 'Valid fixtures' {
        It 'Reports zero errors for valid-minimal.yaml' {
            $path = Join-Path $script:ValidFixturesRoot 'valid-minimal.yaml'
            $spec = ConvertFrom-Yaml -Yaml (Get-Content -LiteralPath $path -Raw)
            $errors = Test-EvalSpecCompliance -Spec $spec -SpecPath 'valid-minimal.yaml' -RepoRoot $script:RepoRoot
            $errors.Count | Should -Be 0
        }

        It 'Reports zero errors for valid-backlink.yaml when backlinked artifact exists' {
            $path = Join-Path $script:ValidFixturesRoot 'valid-backlink.yaml'
            $spec = ConvertFrom-Yaml -Yaml (Get-Content -LiteralPath $path -Raw)
            $errors = Test-EvalSpecCompliance -Spec $spec -SpecPath 'valid-backlink.yaml' -RepoRoot $script:RepoRoot

            $resolved = Resolve-EvalArtifactPath -RepoRoot $script:RepoRoot -Kind 'skill' -Slug 'pr-reference'
            if ($null -eq $resolved) {
                Set-ItResult -Skipped -Because 'pr-reference skill is not present in this workspace'
                return
            }

            $errors.Count | Should -Be 0
        }

        It 'Reports zero errors when environment paths resolve relative to the spec directory' {
            $relPath = 'scripts/tests/evals/fixtures/specs/valid/valid-env-path.yaml'
            $path = Join-Path $script:RepoRoot $relPath
            $spec = ConvertFrom-Yaml -Yaml (Get-Content -LiteralPath $path -Raw)
            $errors = Test-EvalSpecCompliance -Spec $spec -SpecPath $relPath -RepoRoot $script:RepoRoot
            ($errors | Where-Object { $_.field -like 'environment.*' }).Count | Should -Be 0
        }
    }

    Context 'Invalid fixtures' {
        It 'Flags missing executor' {
            $path = Join-Path $script:InvalidFixturesRoot 'missing-executor.yaml'
            $spec = ConvertFrom-Yaml -Yaml (Get-Content -LiteralPath $path -Raw)
            $errors = Test-EvalSpecCompliance -Spec $spec -SpecPath 'missing-executor.yaml' -RepoRoot $script:RepoRoot
            ($errors | Where-Object { $_.field -eq 'defaults.executor' }).Count | Should -BeGreaterOrEqual 1
        }

        It 'Flags executor not in whitelist' {
            $path = Join-Path $script:InvalidFixturesRoot 'bad-executor.yaml'
            $spec = ConvertFrom-Yaml -Yaml (Get-Content -LiteralPath $path -Raw)
            $errors = Test-EvalSpecCompliance -Spec $spec -SpecPath 'bad-executor.yaml' -RepoRoot $script:RepoRoot
            ($errors | Where-Object { $_.message -like '*whitelist*' }).Count | Should -BeGreaterOrEqual 1
        }

        It 'Flags stimulus with empty graders' {
            $path = Join-Path $script:InvalidFixturesRoot 'missing-graders.yaml'
            $spec = ConvertFrom-Yaml -Yaml (Get-Content -LiteralPath $path -Raw)
            $errors = Test-EvalSpecCompliance -Spec $spec -SpecPath 'missing-graders.yaml' -RepoRoot $script:RepoRoot
            ($errors | Where-Object { $_.field -like '*.graders' }).Count | Should -BeGreaterOrEqual 1
        }

        It 'Flags unresolved skill backlink' {
            $path = Join-Path $script:InvalidFixturesRoot 'unresolved-backlink.yaml'
            $spec = ConvertFrom-Yaml -Yaml (Get-Content -LiteralPath $path -Raw)
            $errors = Test-EvalSpecCompliance -Spec $spec -SpecPath 'unresolved-backlink.yaml' -RepoRoot $script:RepoRoot
            ($errors | Where-Object { $_.message -like '*does not resolve*' }).Count | Should -BeGreaterOrEqual 1
        }

        It 'Flags moderation.threshold out of the 0.0-1.0 range' {
            $path = Join-Path $script:InvalidFixturesRoot 'moderation-threshold-out-of-range.yaml'
            $spec = ConvertFrom-Yaml -Yaml (Get-Content -LiteralPath $path -Raw)
            $errors = Test-EvalSpecCompliance -Spec $spec -SpecPath 'moderation-threshold-out-of-range.yaml' -RepoRoot $script:RepoRoot
            ($errors | Where-Object { $_.field -eq 'moderation.threshold' }).Count | Should -BeGreaterOrEqual 1
        }

        It 'Flags non-numeric moderation.threshold' {
            $path = Join-Path $script:InvalidFixturesRoot 'moderation-threshold-non-numeric.yaml'
            $spec = ConvertFrom-Yaml -Yaml (Get-Content -LiteralPath $path -Raw)
            $errors = Test-EvalSpecCompliance -Spec $spec -SpecPath 'moderation-threshold-non-numeric.yaml' -RepoRoot $script:RepoRoot
            ($errors | Where-Object { $_.field -eq 'moderation.threshold' }).Count | Should -BeGreaterOrEqual 1
        }

        It 'Flags environment paths that do not resolve relative to the spec directory' {
            $relPath = 'scripts/tests/evals/fixtures/specs/invalid/env-path-unresolved.yaml'
            $path = Join-Path $script:RepoRoot $relPath
            $spec = ConvertFrom-Yaml -Yaml (Get-Content -LiteralPath $path -Raw)
            $errors = Test-EvalSpecCompliance -Spec $spec -SpecPath $relPath -RepoRoot $script:RepoRoot
            ($errors | Where-Object { $_.field -like 'environment.*' -and $_.message -like '*does not resolve*' }).Count | Should -BeGreaterOrEqual 2
        }
    }

    Context 'Optional moderation block' {
        It 'Accepts a valid moderation.threshold' {
            $path = Join-Path $script:ValidFixturesRoot 'valid-moderation-threshold.yaml'
            $spec = ConvertFrom-Yaml -Yaml (Get-Content -LiteralPath $path -Raw)
            $errors = Test-EvalSpecCompliance -Spec $spec -SpecPath 'valid-moderation-threshold.yaml' -RepoRoot $script:RepoRoot
            $errors.Count | Should -Be 0
        }

        It 'Accepts boundary values 0.0 and 1.0' {
            foreach ($v in @(0.0, 1.0)) {
                $spec = @{
                    name = 'boundary'
                    defaults = @{ executor = 'copilot-sdk' }
                    moderation = @{ threshold = $v }
                    stimuli = @(@{ name = 's'; prompt = 'p'; graders = @(@{ type = 'noop' }) })
                }
                $errors = Test-EvalSpecCompliance -Spec $spec -SpecPath 'inline.yaml' -RepoRoot $script:RepoRoot
                ($errors | Where-Object { $_.field -eq 'moderation.threshold' }).Count | Should -Be 0
            }
        }
    }
}

Describe 'Test-EvalSpec.ps1 (entry script)' -Tag 'Unit' {
    BeforeEach {
        $script:OutputPath = Join-Path $TestDrive "eval-spec-validation-$([Guid]::NewGuid()).json"
    }

    It 'Exits 0 and reports all fixtures valid for the valid corpus' {
        & $script:ScriptPath `
            -Root 'scripts/tests/evals/fixtures/specs/valid' `
            -RepoRoot $script:RepoRoot `
            -OutputPath $script:OutputPath `
            -SkipAgentCoverage *> $null
        $exit = $LASTEXITCODE
        $report = Get-Content -LiteralPath $script:OutputPath -Raw | ConvertFrom-Json

        $exit | Should -Be 0
        $report.invalid.Count | Should -Be 0
        $report.valid.Count | Should -BeGreaterOrEqual 1
    }

    It 'Exits 1 and reports invalid entries for the invalid corpus' {
        & $script:ScriptPath `
            -Root 'scripts/tests/evals/fixtures/specs/invalid' `
            -RepoRoot $script:RepoRoot `
            -OutputPath $script:OutputPath `
            -SkipAgentCoverage *> $null
        $exit = $LASTEXITCODE
        $report = Get-Content -LiteralPath $script:OutputPath -Raw | ConvertFrom-Json

        $exit | Should -Be 1
        $report.invalid.Count | Should -BeGreaterOrEqual 4
    }

    It 'Flags an un-inventoried agent tag as orphaned and exits non-zero' {
        $fixtureRoot = Join-Path $TestDrive 'orphaned-agent-tag'
        New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'evals/agent-behavior') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $fixtureRoot '.github/agents') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $fixtureRoot '.github/agents/known-agent.agent.md') -Value "---\nuser-invocable: true\n---\n"
        Set-Content -LiteralPath (Join-Path $fixtureRoot 'evals/agent-behavior/AGENTS.yml') -Value @"
agents:
  - slug: known-agent
    path: '.github/agents/known-agent.agent.md'
    class: unknown
    cost_tier: light
"@
        Set-Content -LiteralPath (Join-Path $fixtureRoot 'evals/agent-behavior/eval.yaml') -Value @"
name: orphaned-agent-tag
defaults:
  executor: copilot-sdk
stimuli:
  - name: orphaned-tag
    prompt: test prompt
    tags:
      category: agent-behavior
      agent: orphaned-agent
      scenario: startup-disclaimer
    graders:
      - type: noop
"@

        & $script:ScriptPath `
            -Root 'evals' `
            -RepoRoot $fixtureRoot `
            -OutputPath $script:OutputPath `
            -SkipAgentCoverage *> $null
        $exit = $LASTEXITCODE
        $report = Get-Content -LiteralPath $script:OutputPath -Raw | ConvertFrom-Json

        $exit | Should -Be 1
        $report.orphanedTags.Count | Should -Be 2
        ($report.orphanedTags | Where-Object { $_.tag -eq 'agent' -and $_.value -eq 'orphaned-agent' }).Count | Should -Be 1
    }

    It 'Passes when all agent and scenario tags are inventoried' {
        $fixtureRoot = Join-Path $TestDrive 'inventoried-tags'
        New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'evals/agent-behavior') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $fixtureRoot '.github/agents') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $fixtureRoot '.github/agents/known-agent.agent.md') -Value "---\nuser-invocable: true\n---\n"
        Set-Content -LiteralPath (Join-Path $fixtureRoot 'evals/agent-behavior/AGENTS.yml') -Value @"
agents:
  - slug: known-agent
    path: '.github/agents/known-agent.agent.md'
    class: unknown
    cost_tier: light
"@
        Set-Content -LiteralPath (Join-Path $fixtureRoot 'evals/agent-behavior/eval.yaml') -Value @"
name: inventoried-tags
defaults:
  executor: copilot-sdk
stimuli:
  - name: covered-tag
    prompt: test prompt
    tags:
      category: agent-behavior
      agent: known-agent
      scenario: startup-disclaimer
    graders:
      - type: noop
"@

        & $script:ScriptPath `
            -Root 'evals' `
            -RepoRoot $fixtureRoot `
            -OutputPath $script:OutputPath `
            -SkipAgentCoverage *> $null
        $exit = $LASTEXITCODE
        $report = Get-Content -LiteralPath $script:OutputPath -Raw | ConvertFrom-Json

        $exit | Should -Be 0
        $report.orphanedTags.Count | Should -Be 0
    }

    It 'Reports a distinct inventory error (not per-tag orphans) and exits non-zero when the inventory is missing' {
        $fixtureRoot = Join-Path $TestDrive 'missing-inventory'
        New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'evals/agent-behavior') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $fixtureRoot '.github/agents') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $fixtureRoot 'evals/agent-behavior/eval.yaml') -Value @"
name: missing-inventory
defaults:
  executor: copilot-sdk
stimuli:
  - name: some-tag
    prompt: test prompt
    tags:
      category: agent-behavior
      agent: known-agent
      scenario: startup-disclaimer
    graders:
      - type: noop
"@

        & $script:ScriptPath `
            -Root 'evals' `
            -RepoRoot $fixtureRoot `
            -OutputPath $script:OutputPath `
            -SkipAgentCoverage *> $null
        $exit = $LASTEXITCODE
        $report = Get-Content -LiteralPath $script:OutputPath -Raw | ConvertFrom-Json

        $exit | Should -Be 1
        $report.inventoryError | Should -Not -BeNullOrEmpty
        $report.inventoryError | Should -Match 'Agent inventory not found'
        $report.orphanedTags.Count | Should -Be 0
    }
}
