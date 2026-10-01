#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '../../evals/Modules/ChangedSpecStimulus.psm1'
    $script:ExecutorPath = Join-Path $PSScriptRoot '../../evals/Invoke-VallyEvals.ps1'
    $script:ResolverScript = Join-Path $PSScriptRoot '../../evals/Get-ChangedSpecStimulus.ps1'
    $script:StubPath = Join-Path $PSScriptRoot 'fixtures/stub-vally.ps1'

    Import-Module $script:ModulePath -Force
    Import-Module (Join-Path $PSScriptRoot '../../evals/Modules/EvalChangeSet.psm1') -Force
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

Describe 'Get-ChangedSpecStimulusArtifact (local Git)' -Tag 'Unit' {
    BeforeEach {
        $script:Repo = Join-Path $TestDrive ('repo-' + [Guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:Repo -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:Repo 'evals/behavior-conformance') -Force | Out-Null

        Push-Location $script:Repo
        git init --quiet --initial-branch=main 2>&1 | Out-Null
        git config user.email 'test@example.com' 2>&1 | Out-Null
        git config user.name 'Test' 2>&1 | Out-Null
        git config commit.gpgsign false 2>&1 | Out-Null
        Pop-Location
    }

    AfterEach {
        if (Test-Path -LiteralPath $script:Repo) {
            Get-ChildItem -LiteralPath $script:Repo -Recurse -Force -File | ForEach-Object { $_.IsReadOnly = $false }
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

            $head = New-StimulusSpec -Stimuli @(
                (New-PromptStimulus -Name 'prompt-existing-conformance' -Slug 'existing'),
                (New-PromptStimulus -Name 'prompt-vex-scan-conformance' -Slug 'vex-scan')
            )
            Set-Content -LiteralPath $specAbs -Value $head -Encoding utf8
            git add -A 2>&1 | Out-Null
            git commit -m 'add stimulus' --quiet 2>&1 | Out-Null

            $changeSetPath = Join-Path $TestDrive 'selection.json'
            New-EvalChangeSet -BaseRef $baseSha -HeadRef 'HEAD' -RepoRoot $script:Repo |
                ConvertTo-Json -Depth 6 | Set-Content $changeSetPath
            $artifacts = Get-ChangedSpecStimulusArtifact -ChangeSetPath $changeSetPath -RepoRoot $script:Repo -EvalRoot 'evals'
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

            $head = $base -replace 'type: capability', "type: capability`ndescription: tweaked"
            Set-Content -LiteralPath $specAbs -Value $head -Encoding utf8
            git add -A 2>&1 | Out-Null
            git commit -m 'tweak description' --quiet 2>&1 | Out-Null

            $changeSetPath = Join-Path $TestDrive 'selection.json'
            New-EvalChangeSet -BaseRef $baseSha -HeadRef 'HEAD' -RepoRoot $script:Repo |
                ConvertTo-Json -Depth 6 | Set-Content $changeSetPath
            $artifacts = Get-ChangedSpecStimulusArtifact -ChangeSetPath $changeSetPath -RepoRoot $script:Repo -EvalRoot 'evals'
        }
        finally {
            Pop-Location
        }

        @($artifacts).Count | Should -Be 0
    }

    It 'uses the merge-base and PR content when both tips modify the same spec' {
        $spec = 'evals/behavior-conformance/prompts.eval.yaml'
        $path = Join-Path $script:Repo $spec
        $baseYaml = New-StimulusSpec -Stimuli @((New-PromptStimulus -Name 's' -Slug 'prompt' -Pattern 'old'))
        $newYaml = New-StimulusSpec -Stimuli @((New-PromptStimulus -Name 's' -Slug 'prompt' -Pattern 'new'))
        $git = @{ RepoRoot = $script:Repo }
        Set-Content $path $baseYaml
        $null = Invoke-EvalGit @git -Arguments @('add', '-A')
        $null = Invoke-EvalGit @git -Arguments @('commit', '--quiet', '-m', 'base')
        $baseSha = (Invoke-EvalGit @git -Arguments @('rev-parse', 'HEAD')).Trim()
        $null = Invoke-EvalGit @git -Arguments @('checkout', '-b', 'pr')
        Set-Content $path $newYaml
        $null = Invoke-EvalGit @git -Arguments @('add', '-A')
        $null = Invoke-EvalGit @git -Arguments @('commit', '--quiet', '-m', 'PR spec')
        $headSha = (Invoke-EvalGit @git -Arguments @('rev-parse', 'HEAD')).Trim()
        $null = Invoke-EvalGit @git -Arguments @('checkout', 'main')
        Set-Content $path $newYaml
        Set-Content (Join-Path $script:Repo 'main.md') 'main advancement'
        $null = Invoke-EvalGit @git -Arguments @('add', '-A')
        $null = Invoke-EvalGit @git -Arguments @('commit', '--quiet', '-m', 'main spec')
        $mainSha = (Invoke-EvalGit @git -Arguments @('rev-parse', 'HEAD')).Trim()
        $null = Invoke-EvalGit @git -Arguments @('merge', '--no-ff', '--no-edit', 'pr')
        # A working-tree read would miss the changed stimulus, while a base-tip read
        # would compare identical tips rather than the original baseline.
        Set-Content $path $baseYaml
        $changeSetPath = Join-Path $TestDrive 'selection.json'
        $set = New-EvalChangeSet -BaseRef $mainSha -HeadRef $headSha -RepoRoot $script:Repo
        $set.comparisonBase | Should -Be $baseSha
        $set | ConvertTo-Json -Depth 6 | Set-Content $changeSetPath
        $artifacts = Get-ChangedSpecStimulusArtifact -ChangeSetPath $changeSetPath -RepoRoot $script:Repo
        $artifacts | Should -HaveCount 1
        $artifacts[0].stimulusName | Should -Be 's'
    }

    It 'returns no derived manifests for a docs PR merged with advanced-main AI and spec changes' {
        $git = @{ RepoRoot = $script:Repo }
        Set-Content (Join-Path $script:Repo 'CONTRIBUTING.md') 'base'
        Set-Content (Join-Path $script:Repo 'TRANSPARENCY-NOTE.md') 'base'
        $null = Invoke-EvalGit @git -Arguments @('add', '-A')
        $null = Invoke-EvalGit @git -Arguments @('commit', '--quiet', '-m', 'base')
        $baseSha = (Invoke-EvalGit @git -Arguments @('rev-parse', 'HEAD')).Trim()
        $null = Invoke-EvalGit @git -Arguments @('checkout', '-b', 'pr')
        Set-Content (Join-Path $script:Repo 'CONTRIBUTING.md') 'PR'
        Set-Content (Join-Path $script:Repo 'TRANSPARENCY-NOTE.md') 'PR'
        $null = Invoke-EvalGit @git -Arguments @('add', '-A')
        $null = Invoke-EvalGit @git -Arguments @('commit', '--quiet', '-m', 'docs')
        $headSha = (Invoke-EvalGit @git -Arguments @('rev-parse', 'HEAD')).Trim()
        $null = Invoke-EvalGit @git -Arguments @('checkout', 'main')
        $agentDir = Join-Path $script:Repo '.github/agents/core'
        $null = New-Item -ItemType Directory -Path $agentDir -Force
        Set-Content (Join-Path $agentDir 'upstream.agent.md') 'upstream'
        Set-Content (Join-Path $script:Repo 'evals/behavior-conformance/new.yaml') (New-StimulusSpec -Stimuli @((New-PromptStimulus -Name 's' -Slug 'upstream')))
        $null = Invoke-EvalGit @git -Arguments @('add', '-A')
        $null = Invoke-EvalGit @git -Arguments @('commit', '--quiet', '-m', 'main AI')
        $null = Invoke-EvalGit @git -Arguments @('merge', '--no-ff', '--no-edit', 'pr')
        $changeSetPath = Join-Path $TestDrive 'selection.json'
        $set = New-EvalChangeSet -BaseRef $baseSha -HeadRef $headSha -RepoRoot $script:Repo
        $set | ConvertTo-Json -Depth 6 | Set-Content $changeSetPath
        Test-EvalChangeSetRelevance -ChangeSet $set -RepoRoot $script:Repo | Should -BeFalse
        . (Join-Path $PSScriptRoot '../../evals/Get-ChangedAIArtifact.ps1') -ChangeSetPath $changeSetPath
        $ai = Invoke-ChangedArtifactScan -ChangeSetPath $changeSetPath -RepoRoot $script:Repo
        $ai.artifacts | Should -HaveCount 0
        $ai.affectedAgents | Should -HaveCount 0
        $derived = Get-ChangedSpecStimulusArtifact -ChangeSetPath $changeSetPath -RepoRoot $script:Repo
        $derived | Should -HaveCount 0
        $outputPath = Join-Path $TestDrive 'spec-manifest.json'
        & pwsh -NoProfile -File $script:ResolverScript -RepoRoot $script:Repo -ChangeSetPath $changeSetPath -OutFile $outputPath
        $LASTEXITCODE | Should -Be 0
        $manifest = Get-Content $outputPath -Raw | ConvertFrom-Json
        $manifest.artifacts | Should -HaveCount 0
        $manifest.headRef | Should -Be $headSha
    }

    It 'handles committed spec <Operation> without hiding unexpected missing objects' -ForEach @(
        @{ Operation = 'addition' }
        @{ Operation = 'deletion' }
        @{ Operation = 'rename' }
        @{ Operation = 'copy' }
    ) {
        $git = @{ RepoRoot = $script:Repo }
        $spec = 'evals/behavior-conformance/prompt.yaml'
        $yaml = New-StimulusSpec -Stimuli @((New-PromptStimulus -Name 's' -Slug 'prompt'))
        Set-Content (Join-Path $script:Repo 'README.md') 'seed'
        if ($Operation -ne 'addition') { Set-Content (Join-Path $script:Repo $spec) $yaml }
        $null = Invoke-EvalGit @git -Arguments @('add', '-A')
        $null = Invoke-EvalGit @git -Arguments @('commit', '--quiet', '-m', 'base')
        $baseSha = (Invoke-EvalGit @git -Arguments @('rev-parse', 'HEAD')).Trim()
        switch ($Operation) {
            'addition' { Set-Content (Join-Path $script:Repo $spec) $yaml }
            'deletion' { Remove-Item -LiteralPath (Join-Path $script:Repo $spec) }
            'rename' { $null = Invoke-EvalGit @git -Arguments @('mv', $spec, 'evals/behavior-conformance/renamed.yaml') }
            'copy' { Copy-Item -LiteralPath (Join-Path $script:Repo $spec) -Destination (Join-Path $script:Repo 'evals/behavior-conformance/copied.yaml') }
        }
        $null = Invoke-EvalGit @git -Arguments @('add', '-A')
        $null = Invoke-EvalGit @git -Arguments @('commit', '--quiet', '-m', 'spec change')
        $changeSetPath = Join-Path $TestDrive 'selection.json'
        $set = New-EvalChangeSet -BaseRef $baseSha -HeadRef HEAD -RepoRoot $script:Repo
        if ($Operation -eq 'copy') {
            # The generator does not enable copy detection, so simulate a C record for the copied path.
            $set.changes[0].status = 'C'
            $set.changes[0].previousPath = $spec
        }
        $set | ConvertTo-Json -Depth 6 | Set-Content $changeSetPath
        $artifacts = Get-ChangedSpecStimulusArtifact -ChangeSetPath $changeSetPath -RepoRoot $script:Repo
        $artifacts.Count | Should -Be $(if ($Operation -eq 'deletion') { 0 } else { 1 })
        if ($Operation -eq 'addition') {
            $set.changes[0].status = 'M'
            $set | ConvertTo-Json -Depth 6 | Set-Content $changeSetPath
            { Get-ChangedSpecStimulusArtifact -ChangeSetPath $changeSetPath -RepoRoot $script:Repo } | Should -Throw '*git show*failed*'
            $set.changes[0].status = 'A'
            $set.headRef = 'a' * 40
            $set | ConvertTo-Json -Depth 6 | Set-Content $changeSetPath
            { Get-ChangedSpecStimulusArtifact -ChangeSetPath $changeSetPath -RepoRoot $script:Repo } | Should -Throw '*git show*failed*'
        }
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
