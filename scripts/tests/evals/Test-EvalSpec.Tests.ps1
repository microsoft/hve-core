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
    Context 'Plain-language evaluation repair contracts' {
        BeforeAll {
            $script:AgentSpec = ConvertFrom-Yaml (Get-Content (Join-Path $script:RepoRoot 'evals/agent-behavior/eval.yaml') -Raw)
            $script:SkillSpec = ConvertFrom-Yaml (Get-Content (Join-Path $script:RepoRoot 'evals/skill-quality/eval.yaml') -Raw)
            $script:InstructionSpec = ConvertFrom-Yaml (Get-Content (Join-Path $script:RepoRoot 'evals/behavior-conformance/instructions.eval.yaml') -Raw)
            $demo = ConvertFrom-Yaml (Get-Content (Join-Path $script:RepoRoot 'evals/agent-behavior/stimuli/hve-demo-material.yml') -Raw)
            $prd = ConvertFrom-Yaml (Get-Content (Join-Path $script:RepoRoot 'evals/agent-behavior/stimuli/prd-builder.yml') -Raw)
            $script:RepairCases = @(
                $demo.stimuli | Where-Object name -EQ 'hve-demo-material-class-recipe'
                $prd.stimuli | Where-Object name -EQ 'prd-builder-research-blocked'
                $script:SkillSpec.stimuli | Where-Object name -EQ 'architecture-review-record-and-authority'
            )
        }

        It 'Retains case identity, classifications, suite thresholds, runs and judge defaults' {
            $script:RepairCases.name | Should -Be @(
                'hve-demo-material-class-recipe', 'prd-builder-research-blocked', 'architecture-review-record-and-authority'
            )
            $script:RepairCases[0].tags.category | Should -Be 'agent-behavior'
            $script:RepairCases[1].tags.scenario | Should -Be 'prd-research-blocked'
            $script:RepairCases[2].tags.skill | Should -Be 'architecture-review'
            foreach ($case in $script:RepairCases) {
                $case.tags.ContainsKey('advisory') | Should -BeFalse
            }
            $script:AgentSpec.defaults.runs | Should -Be 5
            $script:AgentSpec.defaults.timeout | Should -Be '300s'
            $script:AgentSpec.defaults.judge_model | Should -Be 'claude-sonnet-5'
            $script:SkillSpec.defaults.runs | Should -Be 3
            $script:SkillSpec.defaults.ContainsKey('judge_model') | Should -BeFalse
            $script:InstructionSpec.defaults.runs | Should -Be 3
            $script:InstructionSpec.defaults.timeout | Should -Be '120s'
            foreach ($spec in @($script:AgentSpec, $script:SkillSpec)) {
                $spec.scoring.threshold | Should -Be 0.7
            }
            $script:InstructionSpec.ContainsKey('scoring') | Should -BeFalse
        }

        It 'Uses one conjunctive binary prompt judge per semantic case without a model override' {
            $expectedNames = @('hve-demo-material-class-recipe-content', 'prd-research-blocked-contract', 'architecture-review-contract')
            for ($i = 0; $i -lt $script:RepairCases.Count; $i++) {
                $case = $script:RepairCases[$i]
                $judges = @($case.graders | Where-Object type -EQ 'prompt')
                $judges | Should -HaveCount 1
                $judges[0].name | Should -Be $expectedNames[$i]
                $judges[0].config.scoring | Should -Be 'binary'
                $judges[0].config.threshold | Should -Be 0.85
                $judges[0].config.ContainsKey('model') | Should -BeFalse
                ($case.rubric -join ' ') | Should -Match 'All criteria are mandatory'
                ($case.rubric -join ' ') | Should -Match 'equivalent wording'
                ($case.rubric -join ' ') | Should -Match 'prompt echoes'
            }
            ($script:RepairCases[0].rubric -join ' ') | Should -Match '4 to 6 minutes.*Azure AI Speech.*tts-voiceover'
            ($script:RepairCases[0].rubric -join ' ') | Should -Match 'deck-export.*narration.*MP4.*duration validation'
            ($script:RepairCases[1].rubric -join ' ') | Should -Match 'open question or unvalidated assumption.*does-not-satisfy'
            ($script:RepairCases[1].rubric -join ' ') | Should -Match 'Stop only.*unrelated work may continue'
            ($script:RepairCases[2].rubric -join ' ') | Should -Match 'scope.*E1.*option A.*assumptions.*trade-offs'
            ($script:RepairCases[2].rubric -join ' ') | Should -Match 'reliability and cost.*budget approval.*limit'
            ($script:RepairCases[2].rubric -join ' ') | Should -Match 'dispositions.*decision owners.*persist.*before.*handoff'
            ($script:RepairCases[2].rubric -join ' ') | Should -Match 'authority stays in the ADR and with the user'
        }

        It 'Stages the demo agent with its relative instruction import and curriculum available' {
            $case = $script:RepairCases[0]
            $base = Join-Path $script:RepoRoot 'evals/agent-behavior'
            $agent = @($case.agent_environment.files | Where-Object dest -EQ '.github/agents/experimental/hve-demo-material.agent.md')
            $agent | Should -HaveCount 1
            $agentPath = Join-Path $base $agent[0].src
            $agentPath | Should -Exist
            $instruction = @($case.agent_environment.files | Where-Object dest -EQ '.github/instructions/shared/plain-language.instructions.md')
            $instruction | Should -HaveCount 1
            (Join-Path $base $instruction[0].src) | Should -Exist
            $text = Get-Content $agentPath -Raw
            $text | Should -Match '#file:../../instructions/shared/plain-language.instructions.md'
            $case.agent_environment.skills | Should -Contain '../../.github/skills/experimental/hve-demo-material'
            foreach ($skill in $case.agent_environment.skills) {
                (Join-Path $base "$skill/SKILL.md") | Should -Exist
                (Join-Path $base "$skill/references/curriculum.md") | Should -Exist
            }
            $case.prompt | Should -Match 'Read.*\.github/agents/experimental/hve-demo-material\.agent\.md'
            $case.prompt | Should -Match 'planning only'
            $case.prompt | Should -Match 'Return the plan prose'
        }

        It 'Keeps file presence separate from semantics and the supplemental response check' {
            $case = $script:RepairCases[0]
            $case.graders | Should -HaveCount 3
            $file = @($case.graders | Where-Object type -EQ 'file-exists')
            $file | Should -HaveCount 1
            $file[0].name | Should -Be 'hve-demo-material-class-recipe-plan-exists'
            $file[0].config.path | Should -Be '.copilot-tracking/demo-material/synthetic-l100-plan.md'
            $supplement = @($case.graders | Where-Object name -EQ 'hve-demo-material-class-recipe-no-source-edit')
            $supplement | Should -HaveCount 1
            $supplement[0].type | Should -Be 'output-matches'
            $supplement[0].config.negate | Should -BeTrue
        }

        It 'Retains exactly 18 labeled synthetic controls without claiming semantic calibration' {
            $controls = (Get-Content (Join-Path $PSScriptRoot 'fixtures/specs/plain-language-repair-controls.json') -Raw | ConvertFrom-Json).controls
            $controls | Should -HaveCount 18
            @($controls.id | Sort-Object -Unique) | Should -HaveCount 18
            foreach ($case in $script:RepairCases) {
                $group = @($controls | Where-Object subject -EQ $case.name)
                $group | Should -HaveCount 6
                @($group | Where-Object expected -EQ $true) | Should -HaveCount 2
                @($group | Where-Object expected -EQ $false) | Should -HaveCount 4
            }
            foreach ($control in $controls) {
                $control.expected | Should -BeOfType ([bool])
                $control.answer | Should -Not -BeNullOrEmpty
                $control.rationale | Should -Not -BeNullOrEmpty
            }
        }

        It 'Resolves actual planner caps and observes missing versus present demo files without an executor' {
            $probe = @'
const { pathToFileURL } = await import('node:url');
const path = await import('node:path');
const fs = await import('node:fs/promises');
const root = process.argv[1];
const workspace = process.argv[2];
const moduleAt = name => import(pathToFileURL(path.join(root, 'node_modules', '@microsoft', 'vally', 'dist', name)).href);
const { loadEvalSpec } = await moduleAt('eval/loader.js');
const { planRun } = await moduleAt('pipeline/plan.js');
const { ProjectContext } = await moduleAt('config/context.js');
const { FileExistsGrader } = await moduleAt('graders/static/file-exists-grader.js');
const filePath = path.join(root, 'evals', 'behavior-conformance', 'instructions.eval.yaml');
const spec = await loadEvalSpec(filePath);
const names = ['instruction-plain-language-direct-research', 'instruction-plain-language-machine-output'];
spec.stimuli = spec.stimuli.filter(s => names.includes(s.name));
const plan = await planRun({
    variants: [{ name: 'local', specs: [{ filePath, spec }] }],
    models: [undefined], projectCtx: await ProjectContext.load(root), skipGrade: true,
    getExecutor: () => ({ name: 'copilot-sdk', execute() { throw new Error('Executor must not run'); } })
});
if (plan.evals.some(e => e.failure)) throw new Error('Local timeout planning failed');
const config = JSON.parse(process.argv[3]);
await fs.mkdir(workspace, { recursive: true });
const grader = new FileExistsGrader();
const trajectory = { workDir: workspace, output: config.path };
const absent = await grader.grade({ config, trajectory });
const file = path.join(workspace, config.path);
await fs.mkdir(path.dirname(file), { recursive: true });
await fs.writeFile(file, 'Synthetic presence fixture, not semantic evidence.');
const present = await grader.grade({ config, trajectory });
console.log(JSON.stringify({ items: plan.items.map(i => ({ name: i.stimulus.name, timeout: i.run.timeout })), absent: absent.passed, present: present.passed }));
'@
            $config = ($script:RepairCases[0].graders | Where-Object type -EQ 'file-exists').config | ConvertTo-Json -Compress
            $json = & node --input-type=module -e $probe $script:RepoRoot (Join-Path $TestDrive 'demo-presence') $config
            $LASTEXITCODE | Should -Be 0
            $result = $json | ConvertFrom-Json
            $research = @($result.items | Where-Object name -EQ 'instruction-plain-language-direct-research')
            $short = @($result.items | Where-Object name -EQ 'instruction-plain-language-machine-output')
            $research | Should -HaveCount 3
            $short | Should -HaveCount 3
            foreach ($item in $research) { $item.timeout | Should -Be 300000 }
            foreach ($item in $short) { $item.timeout | Should -Be 120000 }
            $result.absent | Should -BeFalse
            $result.present | Should -BeTrue
            $case = @($script:InstructionSpec.stimuli | Where-Object name -EQ 'instruction-plain-language-direct-research')[0]
            $case.tags.advisory | Should -Be 'true'
            $case.constraints.max_duration | Should -Be '300s'
            $case.constraints.ContainsKey('max_agent_duration') | Should -BeFalse
        }
    }

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
