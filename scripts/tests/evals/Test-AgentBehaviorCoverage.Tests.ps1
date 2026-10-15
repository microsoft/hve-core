#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ScriptPath = (Resolve-Path (Join-Path $PSScriptRoot '../../evals/Test-EvalSpec.ps1')).Path
    $script:ModulePath = (Resolve-Path (Join-Path $PSScriptRoot '../../evals/Modules/EvalSpecSchema.psm1')).Path

    Import-Module $script:ModulePath -Force

    if (-not (Get-Module -ListAvailable -Name 'powershell-yaml')) {
        throw "Pester suite requires 'powershell-yaml'. Install via Install-Module powershell-yaml -Scope CurrentUser."
    }
    Import-Module powershell-yaml -ErrorAction Stop

    . $script:ScriptPath -SkipAgentCoverage *> $null

    function New-CoverageFixture {
        param(
            [Parameter(Mandatory = $true)][string]$Root,
            [Parameter(Mandatory = $true)][hashtable[]]$Agents,
            [Parameter(Mandatory = $false)][string[]]$Stimuli = @()
        )

        $agentsRoot = Join-Path $Root '.github/agents/sample'
        $stimuliRoot = Join-Path $Root 'evals/agent-behavior/stimuli'
        New-Item -ItemType Directory -Path $agentsRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $stimuliRoot -Force | Out-Null

        foreach ($agent in $Agents) {
            $slug = [string]$agent.slug
            $frontmatter = @('---', "name: $slug")
            if ($agent.ContainsKey('userInvocable')) {
                $frontmatter += "user-invocable: $($agent.userInvocable.ToString().ToLowerInvariant())"
            }
            $frontmatter += '---'
            $frontmatter += ''
            $frontmatter += "# $slug"
            $path = Join-Path $agentsRoot "$slug.agent.md"
            Set-Content -LiteralPath $path -Value ($frontmatter -join "`n") -Encoding UTF8
        }

        foreach ($slug in $Stimuli) {
            $path = Join-Path $stimuliRoot "$slug.yml"
            Set-Content -LiteralPath $path -Value "name: $slug`nprompt: test`n" -Encoding UTF8
        }
    }
}

Describe 'Test-AgentBehaviorCoverage (function)' -Tag 'Unit' {
    BeforeEach {
        $script:Fixture = Join-Path $TestDrive ("coverage-" + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:Fixture -Force | Out-Null
    }

    It 'Returns covered and missing slugs against a fixture repo' {
        New-CoverageFixture -Root $script:Fixture -Agents @(
            @{ slug = 'alpha' },
            @{ slug = 'beta' }
        ) -Stimuli @('alpha')

        $report = Test-AgentBehaviorCoverage -RepoRoot $script:Fixture

        $report.parentCount | Should -Be 2
        $report.checkedCount | Should -Be 2
        $report.covered.Count | Should -Be 1
        $report.missing.Count | Should -Be 1
        $report.covered[0].slug | Should -Be 'alpha'
        $report.missing[0].slug | Should -Be 'beta'
    }

    It 'Ignores subagents that declare user-invocable: false' {
        New-CoverageFixture -Root $script:Fixture -Agents @(
            @{ slug = 'parent-agent' },
            @{ slug = 'helper-subagent'; userInvocable = $false }
        )

        $report = Test-AgentBehaviorCoverage -RepoRoot $script:Fixture

        $report.parentCount | Should -Be 1
        $report.missing.Count | Should -Be 1
        $report.missing[0].slug | Should -Be 'parent-agent'
        $allSlugs = @($report.covered | ForEach-Object { $_.slug }) + @($report.missing | ForEach-Object { $_.slug })
        $allSlugs | Should -Not -Contain 'helper-subagent'
    }

    It 'Honors -RestrictToSlugs for incremental enforcement' {
        New-CoverageFixture -Root $script:Fixture -Agents @(
            @{ slug = 'legacy' },
            @{ slug = 'newly-added' }
        )

        $report = Test-AgentBehaviorCoverage -RepoRoot $script:Fixture -RestrictToSlugs @('newly-added')

        $report.parentCount | Should -Be 2
        $report.checkedCount | Should -Be 1
        $report.missing.Count | Should -Be 1
        $report.missing[0].slug | Should -Be 'newly-added'
    }

    It 'Returns zero missing when every parent agent has a partial' {
        New-CoverageFixture -Root $script:Fixture -Agents @(
            @{ slug = 'one' },
            @{ slug = 'two' }
        ) -Stimuli @('one', 'two')

        $report = Test-AgentBehaviorCoverage -RepoRoot $script:Fixture

        $report.missing.Count | Should -Be 0
        $report.covered.Count | Should -Be 2
    }
}

Describe 'Test-EvalSpec.ps1 -NewAgentsOnly (entry script)' -Tag 'Unit' {
    BeforeEach {
        $script:OutputPath = Join-Path $TestDrive ("eval-spec-coverage-" + [Guid]::NewGuid().ToString('N') + ".json")
    }

    It 'Skips coverage check gracefully when no new parent agents are detected' {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
        $output = & $script:ScriptPath `
            -Root 'scripts/tests/evals/fixtures/specs/valid' `
            -RepoRoot $repoRoot `
            -OutputPath $script:OutputPath `
            -NewAgentsOnly `
            -BaseRef 'HEAD' *>&1
        $exit = $LASTEXITCODE
        $exit | Should -Be 0
        ($output -join "`n") | Should -Match 'Skipping coverage check|coverage'
    }
}

Describe 'Test-AgentBehaviorPolicy (function)' -Tag 'Unit' {
    BeforeAll {
        function New-PolicyRepo {
            param(
                [Parameter(Mandatory = $true)][hashtable]$Spec,
                [Parameter(Mandatory = $true)][hashtable]$Policy,
                [string]$AlphaBody = "# Alpha`n`nFollow #file:../../instructions/shared/one.instructions.md.`n"
            )

            $root = Join-Path $TestDrive ("policy-" + [Guid]::NewGuid().ToString('N'))
            $files = @{
                '.github/agents/sample/alpha.agent.md'               = "---`nname: Alpha`n---`n`n$AlphaBody"
                '.github/agents/sample/beta.agent.md'                = "---`nname: Beta`n---`n`n# Beta`n"
                '.github/instructions/shared/one.instructions.md'    = "---`napplyTo: '**'`n---`n`nShared rule.`n"
                '.github/instructions/shared/cycle-a.instructions.md' = "See #file:./cycle-b.instructions.md`n"
                '.github/instructions/shared/cycle-b.instructions.md' = "See #file:./cycle-a.instructions.md`n"
                'outside.md'                                          = "Outside the artifact root.`n"
                'evals/agent-behavior/AGENTS.yml'                     = "agents:`n  - slug: alpha`n    path: '.github/agents/sample/alpha.agent.md'`n  - slug: beta`n    path: '.github/agents/sample/beta.agent.md'`n"
                'evals/agent-behavior/fixtures/contract.md'           = "Fixture contract.`n"
            }
            foreach ($relative in $files.Keys) {
                $path = Join-Path $root $relative
                New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force | Out-Null
                [System.IO.File]::WriteAllText($path, $files[$relative])
            }
            [System.IO.File]::WriteAllText((Join-Path $root 'evals/agent-behavior/eval.yaml'), (ConvertTo-Yaml $Spec))
            [System.IO.File]::WriteAllText((Join-Path $root 'evals/agent-behavior/measurement-policy.json'), ($Policy | ConvertTo-Json -Depth 10))
            return $root
        }

        function New-BaselineSpec {
            return @{
                name    = 'agent-behavior'
                scoring = @{ threshold = 0.7 }
                stimuli = @(
                    @{
                        name              = 'alpha-loaded'
                        prompt            = 'p'
                        agent_environment = @{
                            files  = @(@{ src = '../../.github/agents/sample/alpha.agent.md'; dest = '.github/copilot-instructions.md' })
                            skills = @('../../.github/skills/sample/demo')
                        }
                        tags              = @{ category = 'agent-behavior'; agent = 'alpha' }
                        graders           = @(@{ type = 'output-matches'; name = 'alpha-behavior'; config = @{ pattern = 'x' } })
                    }
                    @{
                        name    = 'beta-plain'
                        prompt  = 'p'
                        tags    = @{ category = 'agent-behavior'; agent = 'beta'; advisory = 'true' }
                        graders = @(@{ type = 'output-matches'; name = 'beta-behavior'; config = @{ pattern = 'x' } })
                    }
                )
            }
        }

        function New-BaselinePolicy {
            return [ordered]@{
                schemaVersion = 1
                rolloutState  = 'calibration'
                contextDebt   = @('beta-plain')
                stimuli       = [ordered]@{
                    'alpha-loaded' = [ordered]@{ class = 'agent-contract'; authoritative = $true; measurement = 'legacy' }
                    'beta-plain'   = [ordered]@{ class = 'base-model'; authoritative = $false; measurement = 'legacy' }
                }
            }
        }

        function Invoke-Policy {
            param([hashtable]$Spec, $Policy, [string]$AlphaBody)
            $arguments = @{ Spec = $Spec; Policy = $Policy }
            if ($PSBoundParameters.ContainsKey('AlphaBody')) { $arguments.AlphaBody = $AlphaBody }
            $root = New-PolicyRepo @arguments
            return Test-AgentBehaviorPolicy -RepoRoot $root
        }

        function Add-Candidate {
            param([hashtable]$Spec, $Policy, [hashtable]$EntryOverrides = @{}, [hashtable]$TagOverrides = @{})
            $tags = @{ category = 'agent-behavior'; agent = 'alpha'; advisory = 'true' }
            foreach ($key in $TagOverrides.Keys) { $tags[$key] = $TagOverrides[$key] }
            $Spec.stimuli += @{
                name              = 'alpha-candidate'
                prompt            = 'p'
                agent_environment = @{
                    files  = @(@{ src = '../../.github/agents/sample/alpha.agent.md'; dest = '.github/copilot-instructions.md' })
                    skills = @('../../.github/skills/sample/demo')
                }
                tags              = $tags
                graders           = @(
                    @{ type = 'output-matches'; name = 'candidate-behavior'; config = @{ pattern = 'x' } }
                    @{ type = 'system-event'; name = 'candidate-context'; config = @{ required = @('hve.context.composed') } }
                )
            }
            $entry = [ordered]@{
                class          = 'agent-contract'
                authoritative  = $false
                measurement    = 'candidate'
                coverageGap    = 'alpha'
                agentSource    = '.github/agents/sample/alpha.agent.md'
                requiredSkills = @('demo')
                assertions     = @('candidate-behavior')
            }
            foreach ($key in $EntryOverrides.Keys) {
                if ($null -eq $EntryOverrides[$key]) { $entry.Remove($key) } else { $entry[$key] = $EntryOverrides[$key] }
            }
            $Policy.stimuli['alpha-candidate'] = $entry
        }
    }

    It 'Accepts a policy that matches what each stimulus stages and reports debt' {
        $report = Invoke-Policy -Spec (New-BaselineSpec) -Policy (New-BaselinePolicy)

        @($report.errors) | Should -HaveCount 0
        $report.rolloutState | Should -Be 'calibration'
        $report.agents['alpha'].legacyAuthoritativeContract | Should -Be 1
        $report.coverageDebt | Should -Be @('alpha', 'beta')
        $report.contextDebt | Should -Be @('beta-plain')
        $report.importDebt | Should -Be @('alpha-loaded')
    }

    It 'Rejects <Case>' -ForEach @(
        @{ Case = 'a stimulus with no policy entry'; Mutate = { param($s, $p) $p.stimuli.Remove('beta-plain'); $p.contextDebt = @() }; Expected = "Stimulus 'beta-plain' has no policy entry" }
        @{ Case = 'a policy entry with no stimulus'; Mutate = { param($s, $p) $p.stimuli['ghost'] = [ordered]@{ class = 'base-model'; authoritative = $false; measurement = 'legacy' } }; Expected = "Policy entry 'ghost' has no matching stimulus" }
        @{ Case = 'an unknown class'; Mutate = { param($s, $p) $p.stimuli['beta-plain'].class = 'loaded' }; Expected = "unknown class 'loaded'" }
        @{ Case = 'an unknown measurement'; Mutate = { param($s, $p) $p.stimuli['beta-plain'].measurement = 'verified' }; Expected = "unknown measurement 'verified'" }
        @{ Case = 'an agent-contract label without the mount'; Mutate = { param($s, $p) $p.stimuli['beta-plain'].class = 'agent-contract'; $p.contextDebt = @() }; Expected = "classed agent-contract but does not stage" }
        @{ Case = 'a reference staged as instructions'; Mutate = { param($s, $p) $p.stimuli['alpha-loaded'].class = 'artifact-reference' }; Expected = 'stages its agent as workspace instructions' }
        @{ Case = 'a base-model label that stages the agent'; Mutate = { param($s, $p) $p.stimuli['alpha-loaded'].class = 'base-model' }; Expected = 'classed base-model but stages its own agent source' }
        @{ Case = 'a fixture-contract without its fixture mounted'; Mutate = { param($s, $p) $p.stimuli['beta-plain'].class = 'fixture-contract'; $p.stimuli['beta-plain'].fixture = 'fixtures/contract.md'; $p.contextDebt = @() }; Expected = "does not stage fixture 'fixtures/contract.md'" }
        @{ Case = 'an undeclared authority change'; Mutate = { param($s, $p) $s.stimuli[0].tags.advisory = 'true' }; Expected = "authority changed without a policy update" }
        @{ Case = 'debt on a resolved stimulus'; Mutate = { param($s, $p) $p.contextDebt = @('beta-plain', 'alpha-loaded') }; Expected = "Context debt entry 'alpha-loaded' is resolved" }
        @{ Case = 'duplicate debt entries'; Mutate = { param($s, $p) $p.contextDebt = @('beta-plain', 'beta-plain') }; Expected = "lists 'beta-plain' more than once" }
        @{ Case = 'an unenrolled agent tag'; Mutate = { param($s, $p) $s.stimuli[1].tags.agent = 'gamma' }; Expected = "agent tag 'gamma' is not enrolled" }
        @{ Case = 'an unsupported rollout state'; Mutate = { param($s, $p) $p.rolloutState = 'strict' }; Expected = "rolloutState must be 'calibration' or 'enforced'" }
    ) {
        $spec = New-BaselineSpec
        $policy = New-BaselinePolicy
        & $Mutate $spec $policy

        $report = Invoke-Policy -Spec $spec -Policy $policy

        ($report.errors -join "`n") | Should -Match ([regex]::Escape($Expected))
    }

    It 'Accepts a complete advisory candidate for a coverage gap' {
        $spec = New-BaselineSpec
        $policy = New-BaselinePolicy
        Add-Candidate -Spec $spec -Policy $policy

        $report = Invoke-Policy -Spec $spec -Policy $policy

        @($report.errors) | Should -HaveCount 0
        $report.agents['alpha'].candidates | Should -Be 1
    }

    It 'Rejects a candidate with <Case>' -ForEach @(
        @{ Case = 'authoritative status'; Entry = @{ authoritative = $true }; Tags = @{ advisory = 'false' }; Expected = 'must be advisory until promoted' }
        @{ Case = 'no incumbent or gap'; Entry = @{ coverageGap = $null }; Tags = @{}; Expected = 'must name exactly one of incumbent or coverageGap' }
        @{ Case = 'both incumbent and gap'; Entry = @{ incumbent = 'alpha-loaded' }; Tags = @{}; Expected = 'must name exactly one of incumbent or coverageGap' }
        @{ Case = 'an advisory incumbent'; Entry = @{ coverageGap = $null; incumbent = 'beta-plain' }; Tags = @{}; Expected = "incumbent 'beta-plain' is not authoritative" }
        @{ Case = 'another agent gap'; Entry = @{ coverageGap = 'beta' }; Tags = @{}; Expected = "coverageGap must be its own agent 'alpha'" }
        @{ Case = 'a mismatched agent source'; Entry = @{ agentSource = '.github/agents/sample/beta.agent.md' }; Tags = @{}; Expected = 'agentSource must equal' }
        @{ Case = 'no required skill declaration'; Entry = @{ requiredSkills = $null }; Tags = @{}; Expected = 'must declare requiredSkills' }
        @{ Case = 'an unstaged required skill'; Entry = @{ requiredSkills = @('demo', 'absent-skill') }; Tags = @{}; Expected = "does not stage required skill 'absent-skill'" }
        @{ Case = 'no assertions'; Entry = @{ assertions = $null }; Tags = @{}; Expected = 'must list the behavior assertions' }
        @{ Case = 'an unknown assertion'; Entry = @{ assertions = @('missing-grader') }; Tags = @{}; Expected = "unknown assertion 'missing-grader'" }
    ) {
        $spec = New-BaselineSpec
        $policy = New-BaselinePolicy
        Add-Candidate -Spec $spec -Policy $policy -EntryOverrides $Entry -TagOverrides $Tags

        $report = Invoke-Policy -Spec $spec -Policy $policy

        ($report.errors -join "`n") | Should -Match ([regex]::Escape($Expected))
    }

    It 'Accepts an advisory stimulus re-measured in place as its own incumbent' {
        $spec = New-BaselineSpec
        $policy = New-BaselinePolicy
        Add-Candidate -Spec $spec -Policy $policy -EntryOverrides @{ coverageGap = $null; incumbent = 'alpha-candidate' }

        $report = Invoke-Policy -Spec $spec -Policy $policy

        @($report.errors) | Should -HaveCount 0
    }

    It 'Rejects a non-legacy stimulus that <Case>' -ForEach @(
        @{ Case = 'keeps a diff grader'; Graders = @(@{ type = 'diff-not-contains'; name = 'candidate-diff'; config = @{ pattern = 'x' } }); Drop = ''; Expected = "must not use diff grader 'candidate-diff'" }
        @{ Case = 'omits the host context assertion'; Graders = @(); Drop = 'candidate-context'; Expected = "requiring 'hve.context.composed'" }
    ) {
        $spec = New-BaselineSpec
        $policy = New-BaselinePolicy
        Add-Candidate -Spec $spec -Policy $policy
        $candidate = $spec.stimuli[-1]
        $candidate.graders = @(@($candidate.graders | Where-Object { $_.name -ne $Drop }) + $Graders)

        $report = Invoke-Policy -Spec $spec -Policy $policy

        ($report.errors -join "`n") | Should -Match ([regex]::Escape($Expected))
    }

    It 'Accepts a filesystem boundary asserted with passed required and other verdicts disallowed' {
        $spec = New-BaselineSpec
        $policy = New-BaselinePolicy
        Add-Candidate -Spec $spec -Policy $policy -EntryOverrides @{ filesystem = [ordered]@{ allow = @(
                    [ordered]@{ change = 'modify'; path = 'state/session.json' }
                    [ordered]@{ change = 'create'; pattern = '^reports/[a-z-]+\.md$'; max = 2 }
                ) } }
        $spec.stimuli[-1].graders += @{ type = 'system-event'; name = 'candidate-filesystem'; config = @{ required = @('hve.filesystem.passed'); disallowed = @('hve.filesystem.violated', 'hve.filesystem.unavailable') } }

        $report = Invoke-Policy -Spec $spec -Policy $policy

        @($report.errors) | Should -HaveCount 0
    }

    It 'Rejects a filesystem boundary that <Case>' -ForEach @(
        @{ Case = 'is not an allow list'; Boundary = [ordered]@{ deny = @() }; Expected = "filesystem must be an object with an 'allow' list" }
        @{ Case = 'uses an unknown change'; Boundary = [ordered]@{ allow = @([ordered]@{ change = 'delete'; path = 'a.txt' }) }; Expected = "change must be 'create' or 'modify'" }
        @{ Case = 'names both path and pattern'; Boundary = [ordered]@{ allow = @([ordered]@{ change = 'create'; path = 'a.txt'; pattern = '^a$' }) }; Expected = 'exactly one of path or pattern' }
        @{ Case = 'modifies by pattern'; Boundary = [ordered]@{ allow = @([ordered]@{ change = 'modify'; pattern = '^a\.txt$' }) }; Expected = 'modify rules require an exact path' }
        @{ Case = 'caps a modify rule'; Boundary = [ordered]@{ allow = @([ordered]@{ change = 'modify'; path = 'a.txt'; max = 1 }) }; Expected = 'max applies only to create rules' }
        @{ Case = 'caps with a non-positive max'; Boundary = [ordered]@{ allow = @([ordered]@{ change = 'create'; pattern = '^a$'; max = 0 }) }; Expected = 'max must be a positive integer' }
        @{ Case = 'escapes with a parent segment'; Boundary = [ordered]@{ allow = @([ordered]@{ change = 'create'; path = '../a.txt' }) }; Expected = "must be a normalized relative path" }
        @{ Case = 'authorizes Git metadata'; Boundary = [ordered]@{ allow = @([ordered]@{ change = 'modify'; path = '.git/config' }) }; Expected = 'targets Git metadata or an ignore file' }
        @{ Case = 'authorizes an ignore file'; Boundary = [ordered]@{ allow = @([ordered]@{ change = 'create'; path = 'out/.gitignore' }) }; Expected = 'targets Git metadata or an ignore file' }
        @{ Case = 'uses an unanchored pattern'; Boundary = [ordered]@{ allow = @([ordered]@{ change = 'create'; pattern = 'reports/.*' }) }; Expected = 'pattern must be anchored' }
        @{ Case = 'lacks the filesystem verdict assertion'; Boundary = [ordered]@{ allow = @() }; Expected = "no system-event grader requires 'hve.filesystem.passed'" }
    ) {
        $spec = New-BaselineSpec
        $policy = New-BaselinePolicy
        Add-Candidate -Spec $spec -Policy $policy -EntryOverrides @{ filesystem = $Boundary }

        $report = Invoke-Policy -Spec $spec -Policy $policy

        ($report.errors -join "`n") | Should -Match ([regex]::Escape($Expected))
    }

    It 'Rejects candidate context whose import graph <Case>' -ForEach @(
        @{ Case = 'names a missing target'; Body = "Use #file:../../instructions/shared/missing.instructions.md."; Expected = 'does not exist' }
        @{ Case = 'forms a cycle'; Body = "Use #file:../../instructions/shared/cycle-a.instructions.md."; Expected = 'Import cycle reaches' }
        @{ Case = 'leaves the artifact root'; Body = "Use #file:../../../outside.md."; Expected = 'resolves outside .github' }
    ) {
        $spec = New-BaselineSpec
        $policy = New-BaselinePolicy
        Add-Candidate -Spec $spec -Policy $policy

        $report = Invoke-Policy -Spec $spec -Policy $policy -AlphaBody $Body

        ($report.errors -join "`n") | Should -Match ([regex]::Escape($Expected))
    }

    It 'Reports a legacy contract import problem as debt rather than an error' {
        $report = Invoke-Policy -Spec (New-BaselineSpec) -Policy (New-BaselinePolicy) -AlphaBody 'Use #file:../../instructions/shared/missing.instructions.md.'

        @($report.errors) | Should -HaveCount 0
        $report.importDebt | Should -Be @('alpha-loaded')
    }

    It 'Fails enforced rollout while coverage or context debt remains' {
        $policy = New-BaselinePolicy
        $policy.rolloutState = 'enforced'

        $report = Invoke-Policy -Spec (New-BaselineSpec) -Policy $policy

        $joined = $report.errors -join "`n"
        $joined | Should -Match "Agent 'alpha' has no authoritative enforced agent-contract stimulus"
        $joined | Should -Match "Stimulus 'beta-plain' still lacks the agent context"
    }

    It 'Accepts enforced rollout when every agent has authoritative enforced coverage' {
        $spec = New-BaselineSpec
        $spec.stimuli[1].agent_environment = @{ files = @(@{ src = '../../.github/agents/sample/beta.agent.md'; dest = '.github/copilot-instructions.md' }) }
        $spec.stimuli[1].tags.Remove('advisory')
        $spec.stimuli[0].graders += @{ type = 'system-event'; name = 'alpha-context'; config = @{ required = @('hve.context.composed') } }
        $spec.stimuli[1].graders += @{ type = 'system-event'; name = 'beta-context'; config = @{ required = @('hve.context.composed') } }
        $policy = New-BaselinePolicy
        $policy.rolloutState = 'enforced'
        $policy.contextDebt = @()
        $policy.stimuli['alpha-loaded'] = [ordered]@{ class = 'agent-contract'; authoritative = $true; measurement = 'enforced'; agentSource = '.github/agents/sample/alpha.agent.md'; requiredSkills = @('demo'); assertions = @('alpha-behavior') }
        $policy.stimuli['beta-plain'] = [ordered]@{ class = 'agent-contract'; authoritative = $true; measurement = 'enforced'; agentSource = '.github/agents/sample/beta.agent.md'; requiredSkills = @(); assertions = @('beta-behavior') }

        $report = Invoke-Policy -Spec $spec -Policy $policy

        @($report.errors) | Should -HaveCount 0
        $report.coverageDebt | Should -HaveCount 0
    }

    It 'Validates the repository policy against the compiled suite' {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path

        $report = Test-AgentBehaviorPolicy -RepoRoot $repoRoot

        @($report.errors) | Should -HaveCount 0
        $report.rolloutState | Should -Be 'calibration'
    }
}
