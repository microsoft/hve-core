#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '../../evals/Modules/StimulusIndex.psm1'
    $script:ScriptPath = Join-Path $PSScriptRoot '../../evals/Test-StimulusPresence.ps1'

    Import-Module $script:ModulePath -Force
    if (-not (Get-Module -ListAvailable -Name 'powershell-yaml')) {
        throw "Tests require the 'powershell-yaml' module to be installed."
    }
    Import-Module powershell-yaml -ErrorAction Stop
}

Describe 'StimulusIndex module' -Tag 'Unit' {
    Context 'Get-StimulusBacklink' {
        It 'Returns empty when stimulus has no tags' {
            $stim = [ordered]@{ name = 'no-tags'; prompt = 'hi' }
            $links = Get-StimulusBacklink -Stimulus $stim
            $links.Count | Should -Be 0
        }

        It 'Returns one entry per supported backlink kind' {
            $stim = [ordered]@{
                name = 'multi'
                tags = [ordered]@{
                    category    = 'fixture'
                    skill       = 'pr-reference'
                    agent       = 'task-research'
                    prompt      = 'task-plan'
                    instruction = 'powershell'
                }
            }
            $links = Get-StimulusBacklink -Stimulus $stim
            $links.Count | Should -Be 4
            ($links | Where-Object { $_.kind -eq 'skill' }).slug | Should -Be 'pr-reference'
            ($links | Where-Object { $_.kind -eq 'agent' }).slug | Should -Be 'task-research'
            ($links | Where-Object { $_.kind -eq 'prompt' }).slug | Should -Be 'task-plan'
            ($links | Where-Object { $_.kind -eq 'instruction' }).slug | Should -Be 'powershell'
        }

        It 'Skips empty backlink values' {
            $stim = [ordered]@{ tags = [ordered]@{ skill = ''; agent = '  ' } }
            (Get-StimulusBacklink -Stimulus $stim).Count | Should -Be 0
        }

        It 'Returns empty when stimulus is null' {
            (Get-StimulusBacklink -Stimulus $null).Count | Should -Be 0
        }
    }

    Context 'New-StimulusIndex and Test-StimulusCoverage' {
        BeforeAll {
            $script:evalRoot = Join-Path $TestDrive 'evals-index-fixture'
            New-Item -ItemType Directory -Path $script:evalRoot -Force | Out-Null

            $yaml1 = @'
name: spec-one
stimuli:
  - name: s1
    prompt: hi
    tags:
      skill: pr-reference
  - name: s2
    prompt: hi
    tags:
      agent: task-research
'@
            Set-Content -LiteralPath (Join-Path $script:evalRoot 'spec-one.yaml') -Value $yaml1 -Encoding UTF8

            New-Item -ItemType Directory -Path (Join-Path $script:evalRoot 'nested') -Force | Out-Null
            $yaml2 = @'
name: spec-two
stimuli:
  - name: dup
    prompt: hi
    tags:
      skill: pr-reference
'@
            Set-Content -LiteralPath (Join-Path $script:evalRoot 'nested/spec-two.yaml') -Value $yaml2 -Encoding UTF8

            $bad = "name: bad`nstimuli: [::not valid"
            Set-Content -LiteralPath (Join-Path $script:evalRoot 'invalid.yaml') -Value $bad -Encoding UTF8
        }

        It 'Indexes backlinks across all spec files' {
            $index = New-StimulusIndex -EvalRoot $script:evalRoot
            $index.specsScanned | Should -BeGreaterOrEqual 3
            $index.coverage.ContainsKey('skill:pr-reference') | Should -BeTrue
            $index.coverage.ContainsKey('agent:task-research') | Should -BeTrue
        }

        It 'Deduplicates spec paths for repeated backlinks' {
            $index = New-StimulusIndex -EvalRoot $script:evalRoot
            $specs = $index.coverage['skill:pr-reference']
            $specs.Count | Should -Be 2
            ($specs | Sort-Object) -join ',' | Should -Be (($specs | Sort-Object -Unique) -join ',')
        }

        It 'Records parse errors without throwing' {
            $index = New-StimulusIndex -EvalRoot $script:evalRoot
            $index.errors.Count | Should -BeGreaterOrEqual 1
            ($index.errors | Where-Object { $_.path -eq 'invalid.yaml' }) | Should -Not -BeNullOrEmpty
        }

        It 'Test-StimulusCoverage returns matching spec paths' {
            $index = New-StimulusIndex -EvalRoot $script:evalRoot
            $coverage = Test-StimulusCoverage -Index $index -Kind 'skill' -ArtifactId 'pr-reference'
            $coverage.Count | Should -Be 2
        }

        It 'Test-StimulusCoverage returns empty when not indexed' {
            $index = New-StimulusIndex -EvalRoot $script:evalRoot
            $coverage = Test-StimulusCoverage -Index $index -Kind 'prompt' -ArtifactId 'unknown'
            $coverage.Count | Should -Be 0
        }
    }
}

Describe 'Test-StimulusPresence.ps1 entry script' -Tag 'Integration' {
    BeforeAll {
        function New-PresenceFixture {
            param(
                [Parameter(Mandatory)][AllowEmptyCollection()][hashtable[]]$Artifacts,
                [Parameter(Mandatory)][string[]]$SpecYaml
            )

            $dir = Join-Path $TestDrive ('case-' + [Guid]::NewGuid())
            New-Item -ItemType Directory -Path $dir -Force | Out-Null

            $evalRoot = Join-Path $dir 'evals'
            New-Item -ItemType Directory -Path $evalRoot -Force | Out-Null

            for ($i = 0; $i -lt $SpecYaml.Count; $i++) {
                Set-Content -LiteralPath (Join-Path $evalRoot "spec-$i.yaml") -Value $SpecYaml[$i] -Encoding UTF8
            }

            $manifestPath = Join-Path $dir 'manifest.json'
            $outFile = Join-Path $dir 'report.json'
            @{ artifacts = $Artifacts } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

            return [pscustomobject]@{
                ManifestPath = $manifestPath
                EvalRoot     = $evalRoot
                OutFile      = $outFile
            }
        }
    }

    It 'Exits 0 and reports zero artifacts when the manifest is empty' {
        $fx = New-PresenceFixture -Artifacts @() -SpecYaml @('name: empty')

        & pwsh -NoProfile -File $script:ScriptPath `
            -ManifestPath $fx.ManifestPath -EvalRoot $fx.EvalRoot -OutFile $fx.OutFile *> $null
        $LASTEXITCODE | Should -Be 0

        $report = Get-Content -LiteralPath $fx.OutFile -Raw | ConvertFrom-Json
        $report.missing.Count | Should -Be 0
        $report.covered.Count | Should -Be 0
    }

    It 'Exits 0 when every changed artifact is covered by a stimulus backlink' {
        $artifacts = @(
            @{ kind = 'skill'; artifactId = 'pr-reference'; path = '.github/skills/shared/pr-reference/SKILL.md'; status = 'M' }
            @{ kind = 'agent'; artifactId = 'task-research'; path = '.github/agents/hve-core/task-research.agent.md'; status = 'A' }
        )
        $spec = @'
name: cover-all
stimuli:
  - name: s1
    prompt: hi
    tags:
      skill: pr-reference
  - name: s2
    prompt: hi
    tags:
      agent: task-research
'@
        $fx = New-PresenceFixture -Artifacts $artifacts -SpecYaml @($spec)

        & pwsh -NoProfile -File $script:ScriptPath `
            -ManifestPath $fx.ManifestPath -EvalRoot $fx.EvalRoot -OutFile $fx.OutFile *> $null
        $LASTEXITCODE | Should -Be 0

        $report = Get-Content -LiteralPath $fx.OutFile -Raw | ConvertFrom-Json
        $report.covered.Count | Should -Be 2
        $report.missing.Count | Should -Be 0
        ($report.covered | Where-Object { $_.kind -eq 'skill' }).specs.Count | Should -BeGreaterOrEqual 1
    }

    It 'Exits 1 when any changed artifact is missing coverage' {
        $artifacts = @(
            @{ kind = 'prompt'; artifactId = 'orphan'; path = '.github/prompts/hve-core/orphan.prompt.md'; status = 'A' }
        )
        $spec = @'
name: unrelated
stimuli:
  - name: s1
    prompt: hi
    tags:
      skill: pr-reference
'@
        $fx = New-PresenceFixture -Artifacts $artifacts -SpecYaml @($spec)

        & pwsh -NoProfile -File $script:ScriptPath `
            -ManifestPath $fx.ManifestPath -EvalRoot $fx.EvalRoot -OutFile $fx.OutFile *> $null
        $LASTEXITCODE | Should -Be 1

        $report = Get-Content -LiteralPath $fx.OutFile -Raw | ConvertFrom-Json
        $report.missing.Count | Should -Be 1
        $report.missing[0].artifactId | Should -Be 'orphan'
        $report.missing[0].kind | Should -Be 'prompt'
    }

    It 'Skips deleted artifacts when computing missing coverage' {
        $artifacts = @(
            @{ kind = 'agent'; artifactId = 'retired'; path = '.github/agents/hve-core/retired.agent.md'; status = 'D' }
        )
        $spec = "name: empty`nstimuli: []"
        $fx = New-PresenceFixture -Artifacts $artifacts -SpecYaml @($spec)

        & pwsh -NoProfile -File $script:ScriptPath `
            -ManifestPath $fx.ManifestPath -EvalRoot $fx.EvalRoot -OutFile $fx.OutFile *> $null
        $LASTEXITCODE | Should -Be 0

        $report = Get-Content -LiteralPath $fx.OutFile -Raw | ConvertFrom-Json
        $report.skipped.Count | Should -Be 1
        $report.missing.Count | Should -Be 0
        $report.skipped[0].reason | Should -Be 'deleted'
    }

    It 'Exits 2 when the manifest does not exist' {
        $missing = Join-Path $TestDrive ('nope-' + [Guid]::NewGuid() + '.json')
        $evalRoot = Join-Path $TestDrive ('evals-' + [Guid]::NewGuid())
        New-Item -ItemType Directory -Path $evalRoot -Force | Out-Null

        & pwsh -NoProfile -File $script:ScriptPath `
            -ManifestPath $missing -EvalRoot $evalRoot *> $null
        $LASTEXITCODE | Should -Be 2
    }
}
