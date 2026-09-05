#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '../../evals/Modules/ChangedSpecStimulus.psm1'
    $script:ExecutorPath = Join-Path $PSScriptRoot '../../evals/Invoke-VallyEvals.ps1'
    $script:ResolverScript = Join-Path $PSScriptRoot '../../evals/Get-ChangedSpecStimulus.ps1'
    $script:StubPath = Join-Path $PSScriptRoot 'fixtures/stub-vally.ps1'

    Import-Module $script:ModulePath -Force
    if (-not (Get-Module -ListAvailable -Name 'powershell-yaml')) {
        throw "Tests require the 'powershell-yaml' module to be installed."
    }
    Import-Module powershell-yaml -ErrorAction Stop

    function New-StimulusSpec {
        param([string[]]$Stimuli)
        return @"
name: changed-spec-fixture
type: capability
defaults:
  executor: copilot-sdk
stimuli:
$($Stimuli -join "`n")
"@
    }

    function New-PromptStimulus {
        param(
            [string]$Name,
            [string]$Slug,
            [string]$Pattern = 'VEX'
        )
        return @"
  - name: $Name
    prompt: |
      Invoke the prompt with minimal arguments.
    tags:
      category: behavior-conformance
      prompt: $Slug
      advisory: "true"
    graders:
      - type: output-matches
        name: scope-language
        config:
          pattern: "(?i)$Pattern"
"@
    }
}

Describe 'ChangedSpecStimulus pure functions' -Tag 'Unit' {

    Context 'Get-SpecStimulusSignatureMap' {
        It 'Returns an empty map for empty or whitespace input' {
            (Get-SpecStimulusSignatureMap -Yaml '').Count | Should -Be 0
            (Get-SpecStimulusSignatureMap -Yaml "   `n  ").Count | Should -Be 0
        }

        It 'Returns an empty map when there is no stimuli array' {
            (Get-SpecStimulusSignatureMap -Yaml "name: noop").Count | Should -Be 0
        }

        It 'Maps each named stimulus to a signature' {
            $yaml = New-StimulusSpec -Stimuli @(
                (New-PromptStimulus -Name 'prompt-a-conformance' -Slug 'a'),
                (New-PromptStimulus -Name 'prompt-b-conformance' -Slug 'b')
            )
            $map = Get-SpecStimulusSignatureMap -Yaml $yaml
            $map.Count | Should -Be 2
            $map.ContainsKey('prompt-a-conformance') | Should -BeTrue
            $map.ContainsKey('prompt-b-conformance') | Should -BeTrue
        }

        It 'Skips stimuli without a name' {
            $yaml = @"
name: x
stimuli:
  - prompt: no-name-here
    tags:
      prompt: orphan
"@
            (Get-SpecStimulusSignatureMap -Yaml $yaml).Count | Should -Be 0
        }
    }

    Context 'Get-ChangedStimulusName' {
        It 'Detects an added stimulus' {
            $base = @{ 'a' = 'sig-a' }
            $head = @{ 'a' = 'sig-a'; 'b' = 'sig-b' }
            $changed = Get-ChangedStimulusName -BaseMap $base -HeadMap $head
            $changed | Should -Be @('b')
        }

        It 'Detects a modified stimulus by signature change' {
            $base = @{ 'a' = 'sig-a-old' }
            $head = @{ 'a' = 'sig-a-new' }
            $changed = Get-ChangedStimulusName -BaseMap $base -HeadMap $head
            $changed | Should -Be @('a')
        }

        It 'Ignores unchanged stimuli' {
            $base = @{ 'a' = 'sig-a'; 'b' = 'sig-b' }
            $head = @{ 'a' = 'sig-a'; 'b' = 'sig-b' }
            (Get-ChangedStimulusName -BaseMap $base -HeadMap $head).Count | Should -Be 0
        }

        It 'Ignores deletions (present in base, absent in head)' {
            $base = @{ 'a' = 'sig-a'; 'b' = 'sig-b' }
            $head = @{ 'a' = 'sig-a' }
            (Get-ChangedStimulusName -BaseMap $base -HeadMap $head).Count | Should -Be 0
        }
    }

    Context 'Signature stability' {
        It 'Produces identical signatures regardless of tag key order' {
            $yamlA = @"
name: x
stimuli:
  - name: s
    prompt: hi
    tags:
      category: behavior-conformance
      prompt: slug
      advisory: "true"
"@
            $yamlB = @"
name: x
stimuli:
  - name: s
    prompt: hi
    tags:
      advisory: "true"
      prompt: slug
      category: behavior-conformance
"@
            $a = Get-SpecStimulusSignatureMap -Yaml $yamlA
            $b = Get-SpecStimulusSignatureMap -Yaml $yamlB
            [string]$a['s'] | Should -Be ([string]$b['s'])
        }

        It 'Produces a different signature when a grader pattern changes' {
            $yamlA = New-StimulusSpec -Stimuli @((New-PromptStimulus -Name 's' -Slug 'slug' -Pattern 'VEX'))
            $yamlB = New-StimulusSpec -Stimuli @((New-PromptStimulus -Name 's' -Slug 'slug' -Pattern 'OpenVEX'))
            $a = Get-SpecStimulusSignatureMap -Yaml $yamlA
            $b = Get-SpecStimulusSignatureMap -Yaml $yamlB
            [string]$a['s'] | Should -Not -Be ([string]$b['s'])
        }
    }

    Context 'Get-StimulusBacklinkForName' {
        It 'Resolves backlinks for named stimuli only' {
            $yaml = New-StimulusSpec -Stimuli @(
                (New-PromptStimulus -Name 'prompt-a-conformance' -Slug 'a'),
                (New-PromptStimulus -Name 'prompt-b-conformance' -Slug 'b')
            )
            $links = Get-StimulusBacklinkForName -Yaml $yaml -Name @('prompt-a-conformance')
            @($links).Count | Should -Be 1
            $links[0].kind | Should -Be 'prompt'
            $links[0].slug | Should -Be 'a'
            $links[0].name | Should -Be 'prompt-a-conformance'
        }

        It 'Skips a changed stimulus that has no backlink tag' {
            $yaml = @"
name: x
stimuli:
  - name: no-backlink
    prompt: hi
    tags:
      category: behavior-conformance
"@
            (Get-StimulusBacklinkForName -Yaml $yaml -Name @('no-backlink')).Count | Should -Be 0
        }

        It 'Returns empty when no names are requested' {
            $yaml = New-StimulusSpec -Stimuli @((New-PromptStimulus -Name 's' -Slug 'slug'))
            (Get-StimulusBacklinkForName -Yaml $yaml -Name @()).Count | Should -Be 0
        }
    }
}

Describe 'Get-ChangedSpecStimulusArtifact (git integration)' -Tag 'Integration' {
    BeforeEach {
        $script:Repo = Join-Path $TestDrive ('repo-' + [Guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:Repo -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:Repo 'evals/behavior-conformance') -Force | Out-Null

        Push-Location $script:Repo
        git init --quiet 2>&1 | Out-Null
        git config user.email 'test@example.com' 2>&1 | Out-Null
        git config user.name 'Test' 2>&1 | Out-Null
        git config commit.gpgsign false 2>&1 | Out-Null
        Pop-Location
    }

    AfterEach {
        if (Test-Path -LiteralPath $script:Repo) {
            Remove-Item -LiteralPath $script:Repo -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Emits a synthetic artifact for a newly added stimulus' {
        $specRel = 'evals/behavior-conformance/prompts.eval.yaml'
        $specAbs = Join-Path $script:Repo $specRel

        $base = New-StimulusSpec -Stimuli @((New-PromptStimulus -Name 'prompt-existing-conformance' -Slug 'existing'))
        Set-Content -LiteralPath $specAbs -Value $base -Encoding utf8

        Push-Location $script:Repo
        try {
            git add -A 2>&1 | Out-Null
            git commit -m 'base' --quiet 2>&1 | Out-Null
            $baseSha = (git rev-parse HEAD).Trim()

            # Head: add a new stimulus and commit it (PR head is always committed).
            $head = New-StimulusSpec -Stimuli @(
                (New-PromptStimulus -Name 'prompt-existing-conformance' -Slug 'existing'),
                (New-PromptStimulus -Name 'prompt-vex-scan-conformance' -Slug 'vex-scan')
            )
            Set-Content -LiteralPath $specAbs -Value $head -Encoding utf8
            git add -A 2>&1 | Out-Null
            git commit -m 'add stimulus' --quiet 2>&1 | Out-Null

            $artifacts = Get-ChangedSpecStimulusArtifact -BaseRef $baseSha -HeadRef 'HEAD' -RepoRoot $script:Repo -EvalRoot 'evals'
        }
        finally {
            Pop-Location
        }

        @($artifacts).Count | Should -Be 1
        $artifacts[0].kind | Should -Be 'prompt'
        $artifacts[0].artifactId | Should -Be 'vex-scan'
        $artifacts[0].source | Should -Be 'changed-spec'
        $artifacts[0].path | Should -Be $specRel
    }

    It 'Does not emit an artifact when only non-stimulus content changes' {
        $specRel = 'evals/behavior-conformance/prompts.eval.yaml'
        $specAbs = Join-Path $script:Repo $specRel

        $base = New-StimulusSpec -Stimuli @((New-PromptStimulus -Name 'prompt-existing-conformance' -Slug 'existing'))
        Set-Content -LiteralPath $specAbs -Value $base -Encoding utf8

        Push-Location $script:Repo
        try {
            git add -A 2>&1 | Out-Null
            git commit -m 'base' --quiet 2>&1 | Out-Null
            $baseSha = (git rev-parse HEAD).Trim()

            # Head: change only the top-level description, not any stimulus.
            $head = $base -replace 'type: capability', "type: capability`ndescription: tweaked"
            Set-Content -LiteralPath $specAbs -Value $head -Encoding utf8
            git add -A 2>&1 | Out-Null
            git commit -m 'tweak description' --quiet 2>&1 | Out-Null

            $artifacts = Get-ChangedSpecStimulusArtifact -BaseRef $baseSha -HeadRef 'HEAD' -RepoRoot $script:Repo -EvalRoot 'evals'
        }
        finally {
            Pop-Location
        }

        @($artifacts).Count | Should -Be 0
    }
}

Describe 'Invoke-VallyEvals changed-spec union (integration)' -Tag 'Integration' {
    BeforeEach {
        Remove-Item Env:\STUB_VALLY_MODE -ErrorAction SilentlyContinue
        $script:Root = Join-Path $TestDrive ('union-' + [Guid]::NewGuid())
        $script:EvalRoot = Join-Path $script:Root 'evals'
        $script:LogsDir = Join-Path $script:Root 'logs'
        New-Item -ItemType Directory -Path $script:EvalRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $script:LogsDir -Force | Out-Null

        $spec = New-StimulusSpec -Stimuli @((New-PromptStimulus -Name 'prompt-vex-scan-conformance' -Slug 'vex-scan'))
        Set-Content -LiteralPath (Join-Path $script:EvalRoot 'prompts.eval.yaml') -Value $spec -Encoding utf8

        # Empty changed-artifact manifest: the underlying prompt did not change.
        $script:ArtifactManifest = Join-Path $script:Root 'manifest.json'
        @{ artifacts = @() } | ConvertTo-Json | Set-Content -LiteralPath $script:ArtifactManifest -Encoding utf8

        $script:SummaryPath = Join-Path $script:LogsDir 'eval-summary.json'
    }

    AfterEach {
        Remove-Item Env:\STUB_VALLY_MODE -ErrorAction SilentlyContinue
    }

    It 'Executes a changed-spec stimulus even when the artifact manifest is empty' {
        $changedSpecManifest = Join-Path $script:Root 'changed-spec-stimuli.json'
        @{
            artifacts = @(
                @{ kind = 'prompt'; artifactId = 'vex-scan'; path = 'evals/prompts.eval.yaml'; status = 'M'; source = 'changed-spec' }
            )
        } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $changedSpecManifest -Encoding utf8

        $env:STUB_VALLY_MODE = 'pass'
        try {
            & pwsh -NoProfile -File $script:ExecutorPath `
                -ManifestPath $script:ArtifactManifest `
                -ChangedSpecManifestPath $changedSpecManifest `
                -EvalRoot $script:EvalRoot `
                -LogsDir $script:LogsDir `
                -RepoRoot $script:Root `
                -VallyCommand $script:StubPath `
                -SkipInputModeration -SkipOutputModeration *> $null
        }
        finally {
            Remove-Item Env:\STUB_VALLY_MODE -ErrorAction SilentlyContinue
        }
        $LASTEXITCODE | Should -Be 0

        $summary = Get-Content -LiteralPath $script:SummaryPath -Raw | ConvertFrom-Json
        $summary.totals.artifacts | Should -Be 1
        $summary.totals.specs | Should -Be 1
        $summary.perArtifact[0].kind | Should -Be 'prompt'
        $summary.perArtifact[0].artifactId | Should -Be 'vex-scan'
    }

    It 'Writes an empty summary when neither the artifact nor the changed-spec manifest has entries' {
        $changedSpecManifest = Join-Path $script:Root 'changed-spec-stimuli.json'
        @{ artifacts = @() } | ConvertTo-Json | Set-Content -LiteralPath $changedSpecManifest -Encoding utf8

        & pwsh -NoProfile -File $script:ExecutorPath `
            -ManifestPath $script:ArtifactManifest `
            -ChangedSpecManifestPath $changedSpecManifest `
            -EvalRoot $script:EvalRoot `
            -LogsDir $script:LogsDir `
            -RepoRoot $script:Root `
            -VallyCommand $script:StubPath *> $null
        $LASTEXITCODE | Should -Be 0

        $summary = Get-Content -LiteralPath $script:SummaryPath -Raw | ConvertFrom-Json
        $summary.totals.artifacts | Should -Be 0
    }

    It 'Does not double-run when a changed-spec artifact is already in the artifact manifest' {
        @{
            artifacts = @(
                @{ kind = 'prompt'; artifactId = 'vex-scan'; path = '.github/prompts/security/vex-scan.prompt.md'; status = 'M' }
            )
        } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $script:ArtifactManifest -Encoding utf8

        $changedSpecManifest = Join-Path $script:Root 'changed-spec-stimuli.json'
        @{
            artifacts = @(
                @{ kind = 'prompt'; artifactId = 'vex-scan'; path = 'evals/prompts.eval.yaml'; status = 'M'; source = 'changed-spec' }
            )
        } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $changedSpecManifest -Encoding utf8

        $env:STUB_VALLY_MODE = 'pass'
        try {
            & pwsh -NoProfile -File $script:ExecutorPath `
                -ManifestPath $script:ArtifactManifest `
                -ChangedSpecManifestPath $changedSpecManifest `
                -EvalRoot $script:EvalRoot `
                -LogsDir $script:LogsDir `
                -RepoRoot $script:Root `
                -VallyCommand $script:StubPath `
                -SkipInputModeration -SkipOutputModeration *> $null
        }
        finally {
            Remove-Item Env:\STUB_VALLY_MODE -ErrorAction SilentlyContinue
        }
        $LASTEXITCODE | Should -Be 0

        $summary = Get-Content -LiteralPath $script:SummaryPath -Raw | ConvertFrom-Json
        $summary.totals.artifacts | Should -Be 1
    }
}
