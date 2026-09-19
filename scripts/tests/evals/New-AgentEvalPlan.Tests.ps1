#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../evals/New-AgentEvalPlan.ps1'
    . $script:ScriptPath

    function New-PlanFixture {
        param(
            [hashtable[]]$Artifacts = @(),
            [string[]]$AffectedAgents = @(),
            [hashtable[]]$SyntheticArtifacts = @(),
            [hashtable[]]$Specs = @()
        )

        $root = Join-Path $TestDrive "plan-$([guid]::NewGuid())"
        $evalRoot = Join-Path $root 'evals'
        New-Item -ItemType Directory -Path $evalRoot -Force | Out-Null
        foreach ($spec in $Specs) {
            $specPath = Join-Path $evalRoot $spec.Path
            New-Item -ItemType Directory -Path (Split-Path -Parent $specPath) -Force | Out-Null
            Set-Content -LiteralPath $specPath -Value $spec.Yaml -Encoding utf8NoBOM
        }
        $manifestPath = Join-Path $root 'changed.json'
        $changedSpecPath = Join-Path $root 'changed-spec.json'
        [ordered]@{ artifacts = $Artifacts; affectedAgents = $AffectedAgents } |
            ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $manifestPath -Encoding utf8NoBOM
        [ordered]@{ artifacts = $SyntheticArtifacts } |
            ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $changedSpecPath -Encoding utf8NoBOM
        return [pscustomobject]@{
            Root            = $root
            EvalRoot        = $evalRoot
            ManifestPath    = $manifestPath
            ChangedSpecPath = $changedSpecPath
        }
    }

    function New-AgentSpec {
        param([string]$Agent, [int]$Runs, [int]$Stimuli)

        $rows = @(
            for ($indexValue = 1; $indexValue -le $Stimuli; $indexValue++) {
                "  - name: $Agent-$indexValue`n    prompt: test`n    tags:`n      agent: $Agent"
            }
        ) -join "`n"
        return "name: $Agent`ndefaults:`n  runs: $Runs`nstimuli:`n$rows"
    }
}

Describe 'New-AgentEvalPlan.ps1' -Tag 'Unit' {
    It 'emits a stable digest and omits empty shards' {
        $fixture = New-PlanFixture `
            -Artifacts @(@{ kind = 'agent'; artifactId = 'alpha'; path = '.github/agents/hve-core/alpha.agent.md'; status = 'M' }) `
            -Specs @(@{ Path = 'alpha.yaml'; Yaml = New-AgentSpec -Agent 'alpha' -Runs 5 -Stimuli 2 })

        $first = New-AgentEvalPlanValue -ManifestPath $fixture.ManifestPath -ChangedSpecManifestPath $fixture.ChangedSpecPath -EvalRoot $fixture.EvalRoot -ShardCount 4 -BaselineSubject 'rpi-agent'
        $second = New-AgentEvalPlanValue -ManifestPath $fixture.ManifestPath -ChangedSpecManifestPath $fixture.ChangedSpecPath -EvalRoot $fixture.EvalRoot -ShardCount 4 -BaselineSubject 'rpi-agent'

        @($first.ordinaryShards) | Should -HaveCount 1
        $first.ordinaryShards[0].id | Should -Be 'ordinary-01'
        $first.ordinaryShards[0].expectedTrialWeight | Should -Be 10
        $first.planDigest | Should -BeExactly $second.planDigest
        Test-AgentEvalPlanDigest -Plan ([pscustomobject]$first) | Should -BeTrue
    }

    It 'assigns longest components first with stable shard tie breaks' {
        $fixture = New-PlanFixture `
            -Artifacts @(
                @{ kind = 'agent'; artifactId = 'alpha'; path = '.github/agents/hve-core/alpha.agent.md'; status = 'M' }
                @{ kind = 'agent'; artifactId = 'beta'; path = '.github/agents/hve-core/beta.agent.md'; status = 'M' }
                @{ kind = 'agent'; artifactId = 'gamma'; path = '.github/agents/hve-core/gamma.agent.md'; status = 'M' }
            ) `
            -Specs @(
                @{ Path = 'alpha.yaml'; Yaml = New-AgentSpec -Agent 'alpha' -Runs 5 -Stimuli 3 }
                @{ Path = 'beta.yaml'; Yaml = New-AgentSpec -Agent 'beta' -Runs 5 -Stimuli 2 }
                @{ Path = 'gamma.yaml'; Yaml = New-AgentSpec -Agent 'gamma' -Runs 5 -Stimuli 1 }
            )

        $plan = New-AgentEvalPlanValue -ManifestPath $fixture.ManifestPath -ChangedSpecManifestPath $fixture.ChangedSpecPath -EvalRoot $fixture.EvalRoot -ShardCount 4 -BaselineSubject 'rpi-agent'

        @($plan.ordinaryShards.expectedTrialWeight) | Should -Be @(15, 10, 5)
        @($plan.ordinaryShards[0].artifacts) | Should -Be @('agent:alpha')
        @($plan.ordinaryShards[1].artifacts) | Should -Be @('agent:beta')
        @($plan.ordinaryShards[2].artifacts) | Should -Be @('agent:gamma')
    }

    It 'keeps artifacts sharing an identical run key in one component' {
        $components = Get-AgentEvalOwnershipComponent -ArtifactPlan @(
            [pscustomobject]@{ kind = 'agent'; artifactId = 'alpha'; specRuns = @('shared') }
            [pscustomobject]@{ kind = 'agent'; artifactId = 'beta'; specRuns = @('shared', 'beta') }
            [pscustomobject]@{ kind = 'agent'; artifactId = 'gamma'; specRuns = @('gamma') }
        )

        @($components) | Should -HaveCount 2
        @($components[0].ArtifactKeys) | Should -Be @('agent:alpha', 'agent:beta')
        @($components[0].RunKeys) | Should -Be @('beta', 'shared')
    }

    It 'deduplicates synthetic artifacts against changed artifacts' {
        $artifact = @{ kind = 'agent'; artifactId = 'alpha'; path = '.github/agents/hve-core/alpha.agent.md'; status = 'M' }
        $fixture = New-PlanFixture `
            -Artifacts @($artifact) `
            -SyntheticArtifacts @(@{ kind = 'agent'; artifactId = 'alpha'; path = 'evals/alpha.yaml'; status = 'M'; source = 'changed-spec' }) `
            -Specs @(@{ Path = 'alpha.yaml'; Yaml = New-AgentSpec -Agent 'alpha' -Runs 1 -Stimuli 1 })

        $plan = New-AgentEvalPlanValue -ManifestPath $fixture.ManifestPath -ChangedSpecManifestPath $fixture.ChangedSpecPath -EvalRoot $fixture.EvalRoot -ShardCount 4 -BaselineSubject 'rpi-agent'

        @($plan.ordinaryShards[0].artifacts) | Should -Be @('agent:alpha')
        @($plan.ordinaryShards[0].runKeys) | Should -HaveCount 1
    }

    It 'records required baseline models and producers from affected agents' {
        $fixture = New-PlanFixture -AffectedAgents @('rpi-agent')

        $plan = New-AgentEvalPlanValue -ManifestPath $fixture.ManifestPath -ChangedSpecManifestPath $fixture.ChangedSpecPath -EvalRoot $fixture.EvalRoot -ShardCount 4 -BaselineSubject 'rpi-agent'

        $plan.baseline.required | Should -BeTrue
        $plan.baseline.reason | Should -Be 'affected-agent:rpi-agent'
        @($plan.baseline.models) | Should -Be @('gpt-5.6-luna', 'claude-sonnet-5')
        @($plan.expectedProducers) | Should -Contain 'baseline:gpt-5.6-luna'
        @($plan.expectedProducers) | Should -Contain 'baseline:claude-sonnet-5'
    }

    It 'records not-required baseline state without model producers' {
        $fixture = New-PlanFixture -AffectedAgents @('other-agent')

        $plan = New-AgentEvalPlanValue -ManifestPath $fixture.ManifestPath -ChangedSpecManifestPath $fixture.ChangedSpecPath -EvalRoot $fixture.EvalRoot -ShardCount 4 -BaselineSubject 'rpi-agent'

        $plan.baseline.required | Should -BeFalse
        $plan.baseline.reason | Should -Be 'agent-not-affected:rpi-agent'
        @($plan.baseline.models) | Should -HaveCount 0
        @($plan.expectedProducers | Where-Object { $_ -like 'baseline:*' }) | Should -HaveCount 0
        @($plan.expectedProducers) | Should -Be @('prompt', 'instruction', 'skill')
        @($plan.expectedProducers | Where-Object { [string]::IsNullOrWhiteSpace([string]$_) }) | Should -HaveCount 0
    }

    It 'rejects an artifact without coverage' {
        $fixture = New-PlanFixture -Artifacts @(
            @{ kind = 'agent'; artifactId = 'orphan'; path = '.github/agents/hve-core/orphan.agent.md'; status = 'M' }
        )

        {
            New-AgentEvalPlanValue -ManifestPath $fixture.ManifestPath -ChangedSpecManifestPath $fixture.ChangedSpecPath -EvalRoot $fixture.EvalRoot -ShardCount 4 -BaselineSubject 'rpi-agent'
        } | Should -Throw '*artifact(s) have no covering spec*'
    }

    It 'detects duplicate or missing ownership' {
        {
            Assert-AgentEvalOwnership -ExpectedArtifact @('agent:alpha') -ExpectedRunKey @('alpha.yaml') -Shard @(
                [pscustomobject]@{ artifacts = @('agent:alpha'); runKeys = @('alpha.yaml') }
                [pscustomobject]@{ artifacts = @('agent:alpha'); runKeys = @('alpha.yaml') }
            )
        } | Should -Throw "Artifact 'agent:alpha' has 2 shard owners*"
    }

    It 'invalidates the plan digest when ownership changes' {
        $fixture = New-PlanFixture `
            -Artifacts @(@{ kind = 'agent'; artifactId = 'alpha'; path = '.github/agents/hve-core/alpha.agent.md'; status = 'M' }) `
            -Specs @(@{ Path = 'alpha.yaml'; Yaml = New-AgentSpec -Agent 'alpha' -Runs 1 -Stimuli 1 })
        $plan = New-AgentEvalPlanValue -ManifestPath $fixture.ManifestPath -ChangedSpecManifestPath $fixture.ChangedSpecPath -EvalRoot $fixture.EvalRoot -ShardCount 4 -BaselineSubject 'rpi-agent'
        $roundTripped = $plan | ConvertTo-Json -Depth 50 | ConvertFrom-Json -Depth 50
        $roundTripped.ordinaryShards[0].artifacts[0] = 'agent:changed'

        Test-AgentEvalPlanDigest -Plan $roundTripped | Should -BeFalse
    }
}