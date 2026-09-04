#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ScriptPath = (Resolve-Path (Join-Path $PSScriptRoot '../../evals/Test-EvalSpec.ps1')).Path

    if (-not (Get-Module -ListAvailable -Name 'powershell-yaml')) {
        throw "Pester suite requires 'powershell-yaml'. Install via Install-Module powershell-yaml -Scope CurrentUser."
    }
    Import-Module powershell-yaml -ErrorAction Stop

    . $script:ScriptPath -SkipAgentCoverage *> $null

    function New-EquivalenceFixture {
        <#
        .SYNOPSIS
            Writes a canonical stimulus library and its two executable specs into a
            temporary root, applying optional per-file mutations.
        #>
        param(
            [Parameter(Mandatory = $true)][string]$Root,
            [Parameter(Mandatory = $false)][scriptblock]$Mutate
        )

        $canonical = @{
            name    = 'fixture-stimuli'
            stimuli = @(
                @{
                    name       = 'shared-basic'
                    prompt     = 'What is 2 + 2?'
                    invariants = @('answers-four')
                    tags       = @{ category = 'baseline-equivalence'; subcategory = 'factual-recall'; policy = 'equivalent' }
                    graders    = @(
                        @{ type = 'output-matches'; name = 'answers-four'; config = @{ pattern = '4' } }
                        @{ type = 'prompt'; name = 'response-quality'; config = @{ prompt = 'Correct?' } }
                    )
                },
                @{
                    # customized_disallow forbids persona bleed, so this stimulus asserts
                    # sameness and stays in the equivalence denominator.
                    name                = 'bleed-guarded'
                    prompt              = 'Tell me a short joke.'
                    invariants          = @('non-empty')
                    customized_disallow = @('agent-self-reference')
                    tags                = @{ category = 'baseline-equivalence'; subcategory = 'instruction-bleed'; policy = 'equivalent' }
                    graders             = @(
                        @{ type = 'output-matches'; name = 'non-empty'; config = @{ pattern = '\S' } }
                    )
                },
                @{
                    # customized_required documents behavior expected only in the
                    # customized run, so this stimulus is excluded from equivalence.
                    name                = 'true-divergence'
                    prompt              = 'Edit the README.'
                    invariants          = @('non-empty')
                    customized_required = @('routes-through-lifecycle')
                    tags                = @{ category = 'baseline-equivalence'; subcategory = 'customization-boundary'; policy = 'documented-divergence' }
                    graders             = @(
                        @{ type = 'output-matches'; name = 'non-empty'; config = @{ pattern = '\S' } }
                    )
                }
            )
        }

        $baseline = @{
            name    = 'fixture-baseline'
            type    = 'capability'
            stimuli = @(
                @{
                    name    = 'shared-basic'
                    prompt  = 'What is 2 + 2?'
                    tags    = @{ category = 'baseline-equivalence'; subcategory = 'factual-recall'; policy = 'equivalent' }
                    graders = @(
                        @{ type = 'output-matches'; name = 'answers-four'; config = @{ pattern = '4' } }
                        @{ type = 'prompt'; name = 'response-quality'; config = @{ prompt = 'Correct?' } }
                    )
                },
                @{
                    name    = 'bleed-guarded'
                    prompt  = 'Tell me a short joke.'
                    tags    = @{ category = 'baseline-equivalence'; subcategory = 'instruction-bleed'; policy = 'equivalent' }
                    graders = @(
                        @{ type = 'output-matches'; name = 'non-empty'; config = @{ pattern = '\S' } }
                    )
                },
                @{
                    name    = 'true-divergence'
                    prompt  = 'Edit the README.'
                    tags    = @{ category = 'baseline-equivalence'; subcategory = 'customization-boundary'; policy = 'documented-divergence' }
                    graders = @(
                        @{ type = 'output-matches'; name = 'non-empty'; config = @{ pattern = '\S' } }
                    )
                }
            )
        }

        $customized = @{
            name    = 'fixture-customized'
            type    = 'capability'
            stimuli = @(
                @{
                    name    = 'shared-basic'
                    turns   = @('Launch .github/agents/hve-core/rpi-agent.agent.md. Read the complete agent file before continuing; if a file view fails, use the shell to read it.', 'What is 2 + 2?')
                    tags    = @{ category = 'baseline-equivalence'; subcategory = 'factual-recall'; policy = 'equivalent' }
                    graders = @(
                        @{ type = 'output-matches'; name = 'answers-four'; config = @{ pattern = '4' } }
                        @{ type = 'prompt'; name = 'response-quality'; config = @{ prompt = 'Correct?' } }
                    )
                },
                @{
                    name    = 'bleed-guarded'
                    turns   = @('Launch .github/agents/hve-core/rpi-agent.agent.md. Read the complete agent file before continuing; if a file view fails, use the shell to read it.', 'Tell me a short joke.')
                    tags    = @{ category = 'baseline-equivalence'; subcategory = 'instruction-bleed'; policy = 'equivalent' }
                    graders = @(
                        @{ type = 'output-matches'; name = 'non-empty'; config = @{ pattern = '\S' } }
                        @{ type = 'output-matches'; name = 'agent-self-reference'; config = @{ pattern = 'agent' } }
                    )
                },
                @{
                    name    = 'true-divergence'
                    turns   = @('Launch .github/agents/hve-core/rpi-agent.agent.md. Read the complete agent file before continuing; if a file view fails, use the shell to read it.', 'Edit the README.')
                    tags    = @{ category = 'baseline-equivalence'; subcategory = 'customization-boundary'; policy = 'documented-divergence' }
                    graders = @(
                        @{ type = 'output-matches'; name = 'non-empty'; config = @{ pattern = '\S' } }
                        @{ type = 'output-matches'; name = 'routes-through-lifecycle'; config = @{ pattern = 'lifecycle' } }
                    )
                }
            )
        }

        foreach ($spec in @($canonical, $baseline, $customized)) {
            foreach ($stimulus in $spec.stimuli) {
                $stimulus['constraints'] = @{ max_agent_duration = '285s' }
            }
        }

        $bag = @{ Canonical = $canonical; Baseline = $baseline; Customized = $customized }
        if ($Mutate) { & $Mutate $bag }

        $canonicalDir = Join-Path $Root 'evals/baseline-equivalence'
        New-Item -ItemType Directory -Path (Join-Path $canonicalDir 'baseline') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $canonicalDir 'customized') -Force | Out-Null

        Set-Content -LiteralPath (Join-Path $canonicalDir 'stimuli.yml') -Value (ConvertTo-Yaml $bag.Canonical) -Encoding UTF8
        Set-Content -LiteralPath (Join-Path $canonicalDir 'baseline/eval.yaml') -Value (ConvertTo-Yaml $bag.Baseline) -Encoding UTF8
        Set-Content -LiteralPath (Join-Path $canonicalDir 'customized/eval.yaml') -Value (ConvertTo-Yaml $bag.Customized) -Encoding UTF8
    }

    function Invoke-SyncCheck {
        param(
            [Parameter(Mandatory = $false)][scriptblock]$Mutate
        )
        $root = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
        try {
            New-EquivalenceFixture -Root $root -Mutate $Mutate
            return Test-EquivalenceStimulusSync -RepoRoot $root
        }
        finally {
            Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Test-EquivalenceStimulusSync' -Tag 'Unit' {
    Context 'Synchronized specs' {
        It 'Reports no violations when canonical and executable specs agree' {
            $result = Invoke-SyncCheck
            @($result.violations).Count | Should -Be 0
            $result.checkedCount | Should -Be 3
        }

        It 'Accepts a customized-only guard that canonical declares' {
            $result = Invoke-SyncCheck
            @($result.violations | Where-Object { $_.field -eq 'customized_disallow' }).Count | Should -Be 0
        }

        It 'Accepts the customized launch turn before the canonical question' {
            $result = Invoke-SyncCheck
            @($result.violations | Where-Object { $_.field -eq 'prompt' }).Count | Should -Be 0
        }
    }

    Context 'Drift detection' {
        It 'Fails when a prompt differs from canonical' {
            $result = Invoke-SyncCheck -Mutate { param($b) $b.Customized.stimuli[0].turns[1] = 'What is 3 + 3?' }
            @($result.violations | Where-Object { $_.field -eq 'prompt' }).Count | Should -Be 1
        }

        It 'Fails when the customized launch target drifts' {
            $result = Invoke-SyncCheck -Mutate { param($b) $b.Customized.stimuli[0].turns[0] = 'Launch .github/agents/other.agent.md' }
            @($result.violations | Where-Object { $_.field -eq 'prompt' }).Count | Should -Be 1
        }

        It 'Fails when the customized stimulus adds an extra turn' {
            $result = Invoke-SyncCheck -Mutate { param($b) $b.Customized.stimuli[0].turns += 'Extra turn.' }
            @($result.violations | Where-Object { $_.field -eq 'prompt' }).Count | Should -Be 1
        }

        It 'Fails when tags differ from canonical' {
            $result = Invoke-SyncCheck -Mutate { param($b) $b.Baseline.stimuli[0].tags.subcategory = 'drifted' }
            @($result.violations | Where-Object { $_.field -eq 'tags' }).Count | Should -Be 1
        }

        It 'Fails when the canonical agent working-duration limit is missing' {
            $result = Invoke-SyncCheck -Mutate { param($b) $b.Canonical.stimuli[0].Remove('constraints') }
            @($result.violations | Where-Object { $_.field -eq 'constraints.max_agent_duration' }).Count | Should -BeGreaterThan 0
        }

        It 'Fails when an executable agent working-duration limit drifts' {
            $result = Invoke-SyncCheck -Mutate { param($b) $b.Customized.stimuli[0].constraints.max_agent_duration = '300s' }
            @($result.violations | Where-Object { $_.field -eq 'constraints.max_agent_duration' }).Count | Should -Be 1
        }

        It 'Fails when a canonical grader is missing from an executable spec' {
            $result = Invoke-SyncCheck -Mutate { param($b) $b.Baseline.stimuli[0].graders = @($b.Baseline.stimuli[0].graders[0]) }
            @($result.violations | Where-Object { $_.field -eq 'graders' }).Count | Should -BeGreaterThan 0
        }

        It 'Fails when a stimulus is missing from an executable spec' {
            $result = Invoke-SyncCheck -Mutate { param($b) $b.Customized.stimuli = @($b.Customized.stimuli[0]) }
            @($result.violations | Where-Object { $_.field -eq 'name' }).Count | Should -BeGreaterThan 0
        }

        It 'Fails when an executable spec declares a stimulus absent from canonical' {
            $result = Invoke-SyncCheck -Mutate {
                param($b)
                $b.Baseline.stimuli += @{
                    name    = 'unknown-stimulus'
                    prompt  = 'Unlisted.'
                    tags    = @{ category = 'baseline-equivalence' }
                    graders = @(@{ type = 'output-matches'; name = 'non-empty'; config = @{ pattern = '\S' } })
                }
            }
            @($result.violations | Where-Object { $_.stimulusName -eq 'unknown-stimulus' }).Count | Should -BeGreaterThan 0
        }
    }

    Context 'Invariant and guard placement' {
        It 'Fails when an invariant is enforced only in the customized spec' {
            $result = Invoke-SyncCheck -Mutate {
                param($b)
                $b.Canonical.stimuli[0].graders = @($b.Canonical.stimuli[0].graders[1])
                $b.Baseline.stimuli[0].graders = @($b.Baseline.stimuli[0].graders[1])
            }
            $invariantViolations = @($result.violations | Where-Object { $_.field -eq 'invariants' })
            $invariantViolations.Count | Should -BeGreaterThan 0
            $invariantViolations[0].message | Should -Match 'customized_required'
        }

        It 'Fails when a customized-only guard leaks into the baseline spec' {
            $result = Invoke-SyncCheck -Mutate {
                param($b)
                $b.Baseline.stimuli[1].graders += @{ type = 'output-matches'; name = 'agent-self-reference'; config = @{ pattern = 'agent' } }
            }
            $guardViolations = @($result.violations | Where-Object { $_.field -eq 'customized_disallow' })
            $guardViolations.Count | Should -BeGreaterThan 0
            $guardViolations[0].message | Should -Match 'baseline'
        }

        It 'Fails when a declared guard has no matching customized grader' {
            $result = Invoke-SyncCheck -Mutate {
                param($b)
                $b.Customized.stimuli[1].graders = @($b.Customized.stimuli[1].graders[0])
            }
            @($result.violations | Where-Object { $_.field -eq 'customized_disallow' }).Count | Should -BeGreaterThan 0
        }

        It 'Fails when the customized spec adds an undeclared grader' {
            $result = Invoke-SyncCheck -Mutate {
                param($b)
                $b.Customized.stimuli[0].graders += @{ type = 'output-matches'; name = 'undeclared-guard'; config = @{ pattern = 'x' } }
            }
            $graderViolations = @($result.violations | Where-Object { $_.field -eq 'graders' })
            $graderViolations.Count | Should -BeGreaterThan 0
            $graderViolations[0].message | Should -Match 'undeclared-guard'
        }
    }

    Context 'Missing or unreadable inputs' {
        It 'Skips cleanly when no baseline-equivalence suite is present' {
            # An absent suite is not a broken suite. A repository or fixture root that
            # never had the suite must not fail validation.
            $root = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
            New-Item -ItemType Directory -Path $root -Force | Out-Null
            try {
                $result = Test-EquivalenceStimulusSync -RepoRoot $root
                $result.suitePresent | Should -BeFalse
                @($result.violations).Count | Should -Be 0
                $result.checkedCount | Should -Be 0
            }
            finally {
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It 'Reports a violation when the suite is only partially present' {
            $root = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
            try {
                New-EquivalenceFixture -Root $root
                Remove-Item -LiteralPath (Join-Path $root 'evals/baseline-equivalence/baseline/eval.yaml') -Force
                $result = Test-EquivalenceStimulusSync -RepoRoot $root
                $result.suitePresent | Should -BeTrue
                @($result.violations).Count | Should -BeGreaterThan 0
                @($result.violations)[0].message | Should -Match 'partially present'
            }
            finally {
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'Comparison policy classification' {
        It 'Counts equivalent and documented-divergence stimuli separately' {
            $result = Invoke-SyncCheck
            $result.equivalent | Should -Be 2
            $result.divergence | Should -Be 1
        }

        It 'Keeps a customized_disallow stimulus in the equivalence denominator' {
            # A disallow guard forbids persona bleed, so it asserts sameness. Tagging it
            # documented-divergence would exempt the suite's strongest equivalence signal
            # from the tie ratio.
            $result = Invoke-SyncCheck
            @($result.violations).Count | Should -Be 0
            $result.equivalent | Should -Be 2
        }

        It 'Fails when a stimulus has no policy tag' {
            $result = Invoke-SyncCheck -Mutate {
                param($b)
                foreach ($spec in @($b.Canonical, $b.Baseline, $b.Customized)) {
                    $spec.stimuli[0].tags.Remove('policy')
                }
            }
            $policyViolations = @($result.violations | Where-Object { $_.field -eq 'policy' })
            $policyViolations.Count | Should -Be 1
            $policyViolations[0].message | Should -Match 'exactly one comparison policy'
        }

        It 'Fails when a policy tag is unrecognized' {
            $result = Invoke-SyncCheck -Mutate {
                param($b)
                foreach ($spec in @($b.Canonical, $b.Baseline, $b.Customized)) {
                    $spec.stimuli[0].tags.policy = 'mostly-equivalent'
                }
            }
            @($result.violations | Where-Object { $_.field -eq 'policy' }).Count | Should -Be 1
        }

        It 'Fails when documented-divergence is claimed without a customized_required guard' {
            $result = Invoke-SyncCheck -Mutate {
                param($b)
                foreach ($spec in @($b.Canonical, $b.Baseline, $b.Customized)) {
                    $spec.stimuli[0].tags.policy = 'documented-divergence'
                }
            }
            $policyViolations = @($result.violations | Where-Object { $_.field -eq 'policy' })
            $policyViolations.Count | Should -Be 1
            $policyViolations[0].message | Should -Match 'without evidence'
        }

        It 'Fails when a customized_required stimulus is tagged equivalent' {
            $result = Invoke-SyncCheck -Mutate {
                param($b)
                foreach ($spec in @($b.Canonical, $b.Baseline, $b.Customized)) {
                    $spec.stimuli[2].tags.policy = 'equivalent'
                }
            }
            $policyViolations = @($result.violations | Where-Object { $_.field -eq 'policy' })
            $policyViolations.Count | Should -Be 1
            $policyViolations[0].message | Should -Match 'tie ratio'
        }
    }

    Context 'Repository specs' {
        It 'Reports no violations for the committed baseline-equivalence suite' {
            $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
            $result = Test-EquivalenceStimulusSync -RepoRoot $repoRoot
            $result.checkedCount | Should -Be 35
            $result.violations | Should -BeNullOrEmpty
        }

        It 'Classifies every committed stimulus into exactly one policy' {
            # The two shared-seed project reads are equivalent-policy: both variants now
            # receive the same package.json and LICENSE, so both sides can answer and the
            # reads belong in the equivalence denominator rather than exempted from it.
            $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
            $result = Test-EquivalenceStimulusSync -RepoRoot $repoRoot
            ($result.equivalent + $result.divergence) | Should -Be 35
            $result.equivalent | Should -Be 35
            $result.divergence | Should -Be 0
        }
    }

    Context 'Gating invariants are limited to comparative evidence' {
        # Invariants are measured on the baseline run only, so a declared invariant
        # asserts something about the uncustomized model rather than about the
        # customization. A grader whose result cannot distinguish "the layer changed
        # behavior" from "the underlying model chose differently" therefore reports
        # without gating: it stays a grader, keeps appearing in the run results, and is
        # simply absent from `invariants`. These assertions pin that split so a later
        # edit cannot silently re-gate a preference or quietly de-gate a health signal.
        BeforeAll {
            $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
            $canonical = ConvertFrom-Yaml (Get-Content -LiteralPath (Join-Path $repoRoot 'evals/baseline-equivalence/stimuli.yml') -Raw)

            $script:DeclaredInvariants = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            $script:DeclaredGraders = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($stimulus in $canonical.stimuli) {
                # A reporting-only grader has no `invariants` key at all, so the field is
                # read conditionally rather than dereferenced.
                if ($stimulus.Contains('invariants')) {
                    foreach ($invariant in @($stimulus['invariants'])) {
                        if (-not [string]::IsNullOrWhiteSpace([string]$invariant)) { [void]$script:DeclaredInvariants.Add([string]$invariant) }
                    }
                }
                foreach ($grader in @($stimulus['graders'])) {
                    if ($grader -and $grader['name']) { [void]$script:DeclaredGraders.Add([string]$grader['name']) }
                }
            }
        }

        It 'Reports but does not gate on <Grader>' -ForEach @(
            @{ Grader = 'asks-clarifying-question'; Reason = 'interaction-style preference of the underlying model' }
            @{ Grader = 'mentions-print-paren'; Reason = 'illustration choice that differs by model' }
        ) {
            $script:DeclaredGraders.Contains($Grader) | Should -BeTrue -Because "$Grader must keep running so $Reason stays visible in the run results"
            $script:DeclaredInvariants.Contains($Grader) | Should -BeFalse -Because "$Grader is measured on the baseline run only, so it cannot evidence equivalence"
        }

        It 'Keeps gating on a grader that evidences run health' {
            # mentions-scripts-or-deps reads a file the seed workspace provides, and a
            # sibling stimulus reads the same file. Intermittent failure means the read
            # itself is unreliable, which is exactly what a gating invariant should
            # surface rather than absorb.
            $script:DeclaredInvariants.Contains('mentions-scripts-or-deps') | Should -BeTrue
        }
    }

    Context 'Violation count reporting' {
        # Regression guard for a PowerShell counting hazard. A pipeline that yields
        # exactly one hashtable reports that hashtable's key count rather than 1
        # when .Count is read without an enclosing array subexpression, so a single
        # violation silently measures as 3. Callers that gate on the count must
        # therefore see an exact 1 here, not merely a truthy value.
        It 'Reports exactly one violation when a single field drifts' {
            $result = Invoke-SyncCheck -Mutate { param($b) $b.Customized.stimuli[0].prompt = 'What is 3 + 3?' }
            @($result.violations).Count | Should -Be 1
            @($result.violations)[0].field | Should -Be 'prompt'
        }

        It 'Reports a violation collection that measures correctly at every size' {
            $none = Invoke-SyncCheck
            $one = Invoke-SyncCheck -Mutate { param($b) $b.Customized.stimuli[0].prompt = 'drifted' }
            $two = Invoke-SyncCheck -Mutate {
                param($b)
                $b.Customized.stimuli[0].prompt = 'drifted'
                $b.Baseline.stimuli[0].prompt = 'drifted differently'
            }

            @($none.violations).Count | Should -Be 0
            @($one.violations).Count | Should -Be 1
            @($two.violations).Count | Should -Be 2
        }
    }
}

Describe 'Baseline-equivalence comparison contract' -Tag 'Unit' {
    # These assertions run against the real repository files rather than a fixture.
    # The comparison contract is what `vally compare --eval-spec` judges against, so
    # drift between it and the canonical library silently changes what the tie ratio
    # measures without failing any other check.
    BeforeAll {
        $script:RepoRootPath = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
        $script:CanonicalSpec = ConvertFrom-Yaml (Get-Content -LiteralPath (Join-Path $script:RepoRootPath 'evals/baseline-equivalence/stimuli.yml') -Raw)
        $script:CompareSpec = ConvertFrom-Yaml (Get-Content -LiteralPath (Join-Path $script:RepoRootPath 'evals/baseline-equivalence/compare.eval.yml') -Raw)
        $script:CanonicalNames = @($script:CanonicalSpec.stimuli | ForEach-Object { [string]$_.name })
        $script:CompareNames = @($script:CompareSpec.stimuli | ForEach-Object { [string]$_.name })

        $script:CanonicalByName = @{}
        foreach ($stimulus in $script:CanonicalSpec.stimuli) {
            $script:CanonicalByName[[string]$stimulus.name] = $stimulus
        }
        $script:CompareByName = @{}
        foreach ($stimulus in $script:CompareSpec.stimuli) {
            $script:CompareByName[[string]$stimulus.name] = $stimulus
        }
    }

    Context 'Population synchronization' {
        It 'Covers every canonical stimulus exactly once' {
            $missing = @($script:CanonicalNames | Where-Object { $_ -notin $script:CompareNames })
            $unknown = @($script:CompareNames | Where-Object { $_ -notin $script:CanonicalNames })
            $duplicates = @($script:CompareNames | Group-Object | Where-Object { $_.Count -gt 1 })

            $missing | Should -BeNullOrEmpty
            $unknown | Should -BeNullOrEmpty
            $duplicates | Should -BeNullOrEmpty
            $script:CompareNames.Count | Should -Be $script:CanonicalNames.Count
        }

        It 'Matches the canonical prompt for every stimulus' {
            # Comparison pairs match on stimulus name plus trial index. A drifted prompt
            # would judge the pair against a contract the variants never received.
            $drift = foreach ($name in $script:CompareNames) {
                if ([string]$script:CompareByName[$name].prompt -ne [string]$script:CanonicalByName[$name].prompt) { $name }
            }
            @($drift) | Should -BeNullOrEmpty
        }

        It 'Matches the canonical comparison policy for every stimulus' {
            $drift = foreach ($name in $script:CompareNames) {
                $canonicalPolicy = [string]$script:CanonicalByName[$name].tags['policy']
                if ([string]$script:CompareByName[$name].tags['policy'] -ne $canonicalPolicy) { $name }
            }
            @($drift) | Should -BeNullOrEmpty
        }
    }

    Context 'Rubric syntax and semantics' {
        It 'Declares a non-empty top-level rubric for every stimulus' {
            # Vally 0.12 comparison mode reads the top-level `rubric`. An empty or absent
            # rubric silently falls back to the built-in default, which asks which
            # response is better rather than whether the contract was equally satisfied.
            $missing = foreach ($stimulus in $script:CompareSpec.stimuli) {
                if (-not $stimulus.rubric -or @($stimulus.rubric).Count -lt 1) { [string]$stimulus.name }
            }
            @($missing) | Should -BeNullOrEmpty
        }

        It 'Instructs a tie for every equivalent-policy stimulus' {
            $equivalent = @($script:CompareSpec.stimuli | Where-Object { [string]$_.tags['policy'] -eq 'equivalent' })
            $equivalent.Count | Should -BeGreaterThan 0
            foreach ($stimulus in $equivalent) {
                (@($stimulus.rubric) -join ' ') | Should -Match '(?i)\btie\b'
            }
        }

        It 'Contains no documented-divergence stimuli' {
            $divergence = @($script:CompareSpec.stimuli | Where-Object { [string]$_.tags['policy'] -eq 'documented-divergence' })
            $divergence.Count | Should -Be 0
        }

        It 'Does not require internal tracking vocabulary in any rubric' {
            # The prior divergence guards failed every trial because they demanded
            # lifecycle wording on trivial prompts. The comparison contract must judge
            # behavior, not incidental phrasing or internal directory names.
            (@($script:CompareSpec.stimuli | ForEach-Object { @($_.rubric) -join ' ' }) -join ' ') |
                Should -Not -Match '(?i)\.copilot-tracking'
        }
    }
}
