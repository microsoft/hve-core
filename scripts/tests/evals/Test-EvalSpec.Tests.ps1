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
            @($errors | Where-Object { $_.field -like 'environment.*' }).Count | Should -Be 0
        }
    }

    Context 'Invalid fixtures' {
        It 'Flags missing executor' {
            $path = Join-Path $script:InvalidFixturesRoot 'missing-executor.yaml'
            $spec = ConvertFrom-Yaml -Yaml (Get-Content -LiteralPath $path -Raw)
            $errors = Test-EvalSpecCompliance -Spec $spec -SpecPath 'missing-executor.yaml' -RepoRoot $script:RepoRoot
            @($errors | Where-Object { $_.field -eq 'defaults.executor' }).Count | Should -BeGreaterOrEqual 1
        }

        It 'Flags executor not in whitelist' {
            $path = Join-Path $script:InvalidFixturesRoot 'bad-executor.yaml'
            $spec = ConvertFrom-Yaml -Yaml (Get-Content -LiteralPath $path -Raw)
            $errors = Test-EvalSpecCompliance -Spec $spec -SpecPath 'bad-executor.yaml' -RepoRoot $script:RepoRoot
            @($errors | Where-Object { $_.message -like '*whitelist*' }).Count | Should -BeGreaterOrEqual 1
        }

        It 'Flags stimulus with empty graders' {
            $path = Join-Path $script:InvalidFixturesRoot 'missing-graders.yaml'
            $spec = ConvertFrom-Yaml -Yaml (Get-Content -LiteralPath $path -Raw)
            $errors = Test-EvalSpecCompliance -Spec $spec -SpecPath 'missing-graders.yaml' -RepoRoot $script:RepoRoot
            @($errors | Where-Object { $_.field -like '*.graders' }).Count | Should -BeGreaterOrEqual 1
        }

        It 'Flags unresolved skill backlink' {
            $path = Join-Path $script:InvalidFixturesRoot 'unresolved-backlink.yaml'
            $spec = ConvertFrom-Yaml -Yaml (Get-Content -LiteralPath $path -Raw)
            $errors = Test-EvalSpecCompliance -Spec $spec -SpecPath 'unresolved-backlink.yaml' -RepoRoot $script:RepoRoot
            @($errors | Where-Object { $_.message -like '*does not resolve*' }).Count | Should -BeGreaterOrEqual 1
        }

        It 'Flags moderation.threshold out of the 0.0-1.0 range' {
            $path = Join-Path $script:InvalidFixturesRoot 'moderation-threshold-out-of-range.yaml'
            $spec = ConvertFrom-Yaml -Yaml (Get-Content -LiteralPath $path -Raw)
            $errors = Test-EvalSpecCompliance -Spec $spec -SpecPath 'moderation-threshold-out-of-range.yaml' -RepoRoot $script:RepoRoot
            @($errors | Where-Object { $_.field -eq 'moderation.threshold' }).Count | Should -BeGreaterOrEqual 1
        }

        It 'Flags non-numeric moderation.threshold' {
            $path = Join-Path $script:InvalidFixturesRoot 'moderation-threshold-non-numeric.yaml'
            $spec = ConvertFrom-Yaml -Yaml (Get-Content -LiteralPath $path -Raw)
            $errors = Test-EvalSpecCompliance -Spec $spec -SpecPath 'moderation-threshold-non-numeric.yaml' -RepoRoot $script:RepoRoot
            @($errors | Where-Object { $_.field -eq 'moderation.threshold' }).Count | Should -BeGreaterOrEqual 1
        }

        It 'Flags environment paths that do not resolve relative to the spec directory' {
            $relPath = 'scripts/tests/evals/fixtures/specs/invalid/env-path-unresolved.yaml'
            $path = Join-Path $script:RepoRoot $relPath
            $spec = ConvertFrom-Yaml -Yaml (Get-Content -LiteralPath $path -Raw)
            $errors = Test-EvalSpecCompliance -Spec $spec -SpecPath $relPath -RepoRoot $script:RepoRoot
            @($errors | Where-Object { $_.field -like 'environment.*' -and $_.message -like '*does not resolve*' }).Count | Should -BeGreaterOrEqual 2
        }

        It 'Flags a duplicate grader name across stimuli and identifies the first declaration' {
            $spec = @{
                name     = 'duplicate-graders'
                defaults = @{ executor = 'copilot-sdk' }
                stimuli  = @(
                    @{
                        name    = 'first-stimulus'
                        prompt  = 'first prompt'
                        graders = @(@{ type = 'noop'; name = 'shared-grader' })
                    },
                    @{
                        name    = 'second-stimulus'
                        prompt  = 'second prompt'
                        graders = @(@{ type = 'noop'; name = 'shared-grader' })
                    }
                )
            }

            $errors = Test-EvalSpecCompliance -Spec $spec -SpecPath 'inline.yaml' -RepoRoot $script:RepoRoot
            $duplicate = @($errors | Where-Object { $_.field -eq 'stimuli[1] (second-stimulus).graders[0].name' })

            $duplicate | Should -HaveCount 1
            $duplicate[0].message | Should -BeExactly "Duplicate grader name 'shared-grader'; first declared in stimulus 'first-stimulus'"
        }

        It "Flags grader names outside Vally's lexical contract" {
            $spec = @{
                name     = 'invalid-grader-names'
                defaults = @{ executor = 'copilot-sdk' }
                stimuli  = @(
                    @{
                        name    = 'invalid-names'
                        prompt  = 'test prompt'
                        graders = @(
                            @{ type = 'noop'; name = 'grader-applyTo-evidence' },
                            @{ type = 'noop'; name = 'grader_name' },
                            @{ type = 'noop'; name = '-leading-hyphen' },
                            @{ type = 'noop'; name = ('a' * 61) }
                        )
                    }
                )
            }

            $errors = Test-EvalSpecCompliance -Spec $spec -SpecPath 'inline.yaml' -RepoRoot $script:RepoRoot
            $invalidNames = @($errors | Where-Object { $_.message -like 'Invalid grader name*' })

            $invalidNames | Should -HaveCount 4
            @($invalidNames.field) | Should -Be @(
                'stimuli[0] (invalid-names).graders[0].name',
                'stimuli[0] (invalid-names).graders[1].name',
                'stimuli[0] (invalid-names).graders[2].name',
                'stimuli[0] (invalid-names).graders[3].name'
            )
        }

        It 'Allows a repeated judge name in the canonical comparison spec contract' {
            $spec = @{
                name     = 'comparison-contract'
                defaults = @{ executor = 'copilot-sdk' }
                stimuli  = @(
                    @{ name = 'first'; prompt = 'first'; graders = @(@{ type = 'prompt'; name = 'equivalence-judgement' }) },
                    @{ name = 'second'; prompt = 'second'; graders = @(@{ type = 'prompt'; name = 'equivalence-judgement' }) }
                )
            }

            $errors = Test-EvalSpecCompliance -Spec $spec -SpecPath 'evals/baseline-equivalence/compare.eval.yml' -RepoRoot $script:RepoRoot

            @($errors | Where-Object { $_.message -like 'Duplicate grader name*' }) | Should -HaveCount 0
        }
    }

    Context 'Environment paths for <Scope> <Key>' -ForEach @(
        @{ Scope = 'root'; Key = 'environment' }
        @{ Scope = 'root'; Key = 'agent_environment' }
        @{ Scope = 'stimulus'; Key = 'environment' }
        @{ Scope = 'stimulus'; Key = 'agent_environment' }
    ) {
        BeforeEach {
            $script:EnvironmentSpec = @{
                name = 'environment-paths'
                defaults = @{ executor = 'copilot-sdk' }
                stimuli = @(@{ name = 's'; prompt = 'p'; graders = @(@{ type = 'noop' }) })
            }
            $script:EnvironmentOwner = if ($Scope -eq 'root') { $script:EnvironmentSpec } else { $script:EnvironmentSpec.stimuli[0] }
            $script:EnvironmentField = if ($Scope -eq 'root') { $Key } else { "stimuli[0] (s).$Key" }
            $script:EnvironmentSpecPath = 'suite/eval.yaml'
            New-Item -ItemType Directory -Path (Join-Path $TestDrive 'suite/assets/skill') -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $TestDrive 'suite/assets/input.md') -Value 'fixture'
        }

        It 'Accepts spec-relative skills and bare or mapped file sources' {
            $script:EnvironmentOwner[$Key] = @{
                skills = @('assets/skill')
                files = @('assets/input.md', @{ src = 'assets/input.md'; dest = 'remapped/input.md' })
            }

            $errors = @(Test-EvalSpecCompliance -Spec $script:EnvironmentSpec -SpecPath $script:EnvironmentSpecPath -RepoRoot $TestDrive)

            $errors | Should -HaveCount 0
        }

        It 'Accepts absolute skill and file sources alongside relative paths without mutating the spec' {
            $skillPath = (Get-Item -LiteralPath (Join-Path $TestDrive 'suite/assets/skill')).FullName
            $filePath = (Get-Item -LiteralPath (Join-Path $TestDrive 'suite/assets/input.md')).FullName
            $script:EnvironmentOwner[$Key] = @{
                skills = @($skillPath, 'assets/skill')
                files = @($filePath, @{ src = $filePath; dest = 'remapped/input.md' }, 'assets/input.md')
            }
            $before = $script:EnvironmentSpec | ConvertTo-Json -Depth 10

            $errors = @(Test-EvalSpecCompliance -Spec $script:EnvironmentSpec -SpecPath $script:EnvironmentSpecPath -RepoRoot $TestDrive)

            $errors | Should -HaveCount 0
            ($script:EnvironmentSpec | ConvertTo-Json -Depth 10) | Should -BeExactly $before
        }

        It 'Reports missing absolute sources with indexed fields and their actual resolved paths' {
            $absoluteRoot = (Get-Item -LiteralPath $TestDrive).FullName
            $skillPath = Join-Path $absoluteRoot 'missing-skill'
            $filePath = Join-Path $absoluteRoot 'missing-file'
            $mappedFilePath = Join-Path $absoluteRoot 'missing-mapped-file'
            $script:EnvironmentOwner[$Key] = @{
                skills = @($skillPath)
                files = @($filePath, @{ src = $mappedFilePath; dest = 'output.md' })
            }
            $expectedFields = @(
                "$script:EnvironmentField.skills[0]"
                "$script:EnvironmentField.files[0]"
                "$script:EnvironmentField.files[1]"
            )
            $expectedPaths = @($skillPath, $filePath, $mappedFilePath)

            $errors = @(Test-EvalSpecCompliance -Spec $script:EnvironmentSpec -SpecPath $script:EnvironmentSpecPath -RepoRoot $TestDrive)

            $errors | Should -HaveCount 3
            for ($index = 0; $index -lt $expectedPaths.Count; $index++) {
                $expectedPath = $expectedPaths[$index]
                $errors[$index].path | Should -BeExactly $script:EnvironmentSpecPath
                $errors[$index].field | Should -BeExactly $expectedFields[$index]
                $errors[$index].message | Should -Match ([regex]::Escape("path '$expectedPath' does not resolve to an existing path (resolved to '$expectedPath')"))
            }
        }

        It 'Reports all unresolved sources with their indexed fields' {
            $script:EnvironmentOwner[$Key] = @{
                skills = @('missing-skill')
                files = @('missing-file', @{ src = 'missing-mapped-file'; dest = 'output.md' })
            }

            $errors = @(Test-EvalSpecCompliance -Spec $script:EnvironmentSpec -SpecPath $script:EnvironmentSpecPath -RepoRoot $TestDrive)

            $errors | Should -HaveCount 3
            $errors.field | Should -Contain "$script:EnvironmentField.skills[0]"
            $errors.field | Should -Contain "$script:EnvironmentField.files[0]"
            $errors.field | Should -Contain "$script:EnvironmentField.files[1]"
            foreach ($errorRecord in $errors) {
                $errorRecord.path | Should -BeExactly $script:EnvironmentSpecPath
                $errorRecord.message | Should -Match 'does not resolve.*relative to the spec directory'
            }
        }

        It 'Reports empty paths and mappings without a source' {
            $script:EnvironmentOwner[$Key] = @{
                skills = @(' ')
                files = @(@{ dest = 'output.md' }, @{ src = ''; dest = 'empty.md' })
            }

            $errors = @(Test-EvalSpecCompliance -Spec $script:EnvironmentSpec -SpecPath $script:EnvironmentSpecPath -RepoRoot $TestDrive)

            $errors | Should -HaveCount 3
            $errors.field | Should -Contain "$script:EnvironmentField.skills[0]"
            $errors.field | Should -Contain "$script:EnvironmentField.files[0]"
            $errors.field | Should -Contain "$script:EnvironmentField.files[1]"
            foreach ($errorRecord in $errors) { $errorRecord.message | Should -Match '^Empty ' }
        }

        It 'Reports an invalid filesystem path without throwing' {
            $script:EnvironmentOwner[$Key] = @{ files = @("invalid$([char]0)path") }

            $errors = @(Test-EvalSpecCompliance -Spec $script:EnvironmentSpec -SpecPath $script:EnvironmentSpecPath -RepoRoot $TestDrive)

            $errors | Should -HaveCount 1
            $errors[0].field | Should -BeExactly "$script:EnvironmentField.files[0]"
            $errors[0].message | Should -Match '^Invalid .* path'
        }

        It 'Rejects UNC and device paths before filesystem probing' {
            $rejectedPaths = @(
                '\\server\share\input.md'
                '//server/share/input.md'
                '\\?\C:\eval\input.md'
                '\\.\PhysicalDrive0'
                '\??\C:\eval\input.md'
                '//?/UNC/server/share/input.md'
            )
            $script:EnvironmentOwner[$Key] = @{ files = $rejectedPaths }
            Mock Test-Path { throw 'Rejected paths must not reach Test-Path' } -ModuleName EvalSpecSchema

            $errors = @(Test-EvalSpecCompliance -Spec $script:EnvironmentSpec -SpecPath $script:EnvironmentSpecPath -RepoRoot $TestDrive)

            $errors | Should -HaveCount $rejectedPaths.Count
            Should -Invoke Test-Path -ModuleName EvalSpecSchema -Times 0 -Exactly
            foreach ($errorRecord in $errors) {
                $errorRecord.message | Should -Match '^UNC and device paths are not allowed'
            }
        }

        It 'Rejects a linked source ancestor before inspecting its children' {
            $outside = Join-Path $TestDrive 'outside'
            New-Item -ItemType Directory -Path $outside -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $outside 'input.md') -Value 'not staged'
            $link = Join-Path $TestDrive 'suite/assets/linked'
            $linkType = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
            New-Item -ItemType $linkType -Path $link -Target $outside -ErrorAction Stop | Out-Null
            $script:EnvironmentOwner[$Key] = @{
                skills = @('assets/linked')
                files = @('assets/linked/input.md', @{ src = 'assets/linked/input.md'; dest = 'output.md' })
            }

            $errors = @(Test-EvalSpecCompliance -Spec $script:EnvironmentSpec -SpecPath $script:EnvironmentSpecPath -RepoRoot $TestDrive)

            $errors | Should -HaveCount 3
            $errors.field | Should -Contain "$script:EnvironmentField.skills[0]"
            $errors.field | Should -Contain "$script:EnvironmentField.files[0]"
            $errors.field | Should -Contain "$script:EnvironmentField.files[1]"
            foreach ($errorRecord in $errors) { $errorRecord.message | Should -Match 'symbolic links and reparse points are not allowed' }
        }

        It 'Accepts an ordinary directory used as a file source' {
            $script:EnvironmentOwner[$Key] = @{ files = @('assets/skill') }

            $errors = @(Test-EvalSpecCompliance -Spec $script:EnvironmentSpec -SpecPath $script:EnvironmentSpecPath -RepoRoot $TestDrive)

            $errors | Should -HaveCount 0
        }

        It 'Rejects an ordinary file used as a skill source' {
            $script:EnvironmentOwner[$Key] = @{ skills = @('assets/input.md') }

            $errors = @(Test-EvalSpecCompliance -Spec $script:EnvironmentSpec -SpecPath $script:EnvironmentSpecPath -RepoRoot $TestDrive)

            $errors | Should -HaveCount 1
            $errors[0].message | Should -Match 'expected an ordinary directory'
        }

        It 'Accepts a local hardlink as an ordinary file source' {
            $link = Join-Path $TestDrive 'suite/assets/hardlink.md'
            New-Item -ItemType HardLink -Path $link -Target (Join-Path $TestDrive 'suite/assets/input.md') -ErrorAction Stop | Out-Null
            $script:EnvironmentOwner[$Key] = @{ files = @('assets/hardlink.md') }

            $errors = @(Test-EvalSpecCompliance -Spec $script:EnvironmentSpec -SpecPath $script:EnvironmentSpecPath -RepoRoot $TestDrive)

            $errors | Should -HaveCount 0
        }

        It 'Rejects a Unix named pipe as a file source' -Skip:$IsWindows {
            $pipePath = Join-Path $TestDrive 'suite/assets/pipe'
            & mkfifo $pipePath
            $LASTEXITCODE | Should -Be 0
            $script:EnvironmentOwner[$Key] = @{ files = @('assets/pipe') }

            $errors = @(Test-EvalSpecCompliance -Spec $script:EnvironmentSpec -SpecPath $script:EnvironmentSpecPath -RepoRoot $TestDrive)

            $errors | Should -HaveCount 1
            $errors[0].message | Should -Match 'not an ordinary file or directory'
        }

        It 'Accepts a named reference without requiring a filesystem path' {
            $script:EnvironmentOwner[$Key] = 'named-environment-not-on-disk'

            $errors = @(Test-EvalSpecCompliance -Spec $script:EnvironmentSpec -SpecPath $script:EnvironmentSpecPath -RepoRoot $TestDrive)

            $errors | Should -HaveCount 0
        }

        It 'Rejects invalid environment values rather than treating them as mappings' {
            foreach ($value in @($null, 42, @('array-value'), ' ')) {
                $script:EnvironmentOwner[$Key] = $value

                $errors = @(Test-EvalSpecCompliance -Spec $script:EnvironmentSpec -SpecPath $script:EnvironmentSpecPath -RepoRoot $TestDrive)

                $errors | Should -HaveCount 1
                $errors[0].field | Should -BeExactly $script:EnvironmentField
                $errors[0].message | Should -Match 'mapping or a non-empty named reference'
            }
        }

        It 'Rejects both aliases on the same object even when one is null' {
            $script:EnvironmentOwner['environment'] = $null
            $script:EnvironmentOwner['agent_environment'] = @{}

            $errors = @(Test-EvalSpecCompliance -Spec $script:EnvironmentSpec -SpecPath $script:EnvironmentSpecPath -RepoRoot $TestDrive)

            $errors | Should -HaveCount 1
            $expectedField = if ($Scope -eq 'root') { 'agent_environment' } else { 'stimuli[0] (s).agent_environment' }
            $errors[0].field | Should -BeExactly $expectedField
            $errors[0].message | Should -Match 'not both'
        }
    }

    It 'Allows different aliases at root and stimulus scope without mutating the spec' {
        $spec = @{
            name = 'mixed-aliases'
            defaults = @{ executor = 'copilot-sdk' }
            environment = 'parent-environment'
            stimuli = @(@{
                name = 's'; prompt = 'p'; graders = @(@{ type = 'noop' })
                agent_environment = 'child-environment'
            })
        }
        $before = $spec | ConvertTo-Json -Depth 10

        $errors = @(Test-EvalSpecCompliance -Spec $spec -SpecPath 'inline.yaml' -RepoRoot $TestDrive)

        $errors | Should -HaveCount 0
        ($spec | ConvertTo-Json -Depth 10) | Should -BeExactly $before
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
                @($errors | Where-Object { $_.field -eq 'moderation.threshold' }).Count | Should -Be 0
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
        @($report.orphanedTags | Where-Object { $_.tag -eq 'agent' -and $_.value -eq 'orphaned-agent' }).Count | Should -Be 1
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
