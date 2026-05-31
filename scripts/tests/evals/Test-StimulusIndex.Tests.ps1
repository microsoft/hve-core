#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '../../evals/Modules/StimulusIndex.psm1'
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $script:EvalsRoot = Join-Path $script:RepoRoot 'evals'

    Import-Module $script:ModulePath -Force

    if (-not (Get-Module -ListAvailable -Name 'powershell-yaml')) {
        throw "Pester suite requires 'powershell-yaml' module. Install via Install-Module powershell-yaml -Scope CurrentUser."
    }
    Import-Module powershell-yaml -ErrorAction Stop
}

Describe 'Get-StimulusBacklink' -Tag 'Unit' {
    It 'Returns empty array when stimulus is $null' {
        ,(Get-StimulusBacklink -Stimulus $null) | Should -BeOfType [System.Array]
        (Get-StimulusBacklink -Stimulus $null).Count | Should -Be 0
    }

    It 'Returns empty array when stimulus has no tags' {
        $stim = @{ name = 'no-tags'; prompt = 'hi' }
        (Get-StimulusBacklink -Stimulus $stim).Count | Should -Be 0
    }

    It 'Extracts a prompt backlink from tags.prompt' {
        $stim = @{ name = 'p1'; tags = @{ prompt = 'task-plan'; advisory = $true } }
        $links = Get-StimulusBacklink -Stimulus $stim
        $links.Count | Should -Be 1
        $links[0].kind | Should -Be 'prompt'
        $links[0].slug | Should -Be 'task-plan'
    }

    It 'Extracts multiple backlinks when several supported kinds are present' {
        $stim = @{ tags = @{ skill = 'pr-reference'; agent = 'task-planner'; prompt = 'task-plan'; instruction = 'csharp' } }
        $links = Get-StimulusBacklink -Stimulus $stim
        $links.Count | Should -Be 4
        ($links | ForEach-Object { $_.kind }) | Sort-Object | Should -Be @('agent', 'instruction', 'prompt', 'skill')
    }

    It 'Trims whitespace from slugs and ignores empty slugs' {
        $stim = @{ tags = @{ prompt = '  task-plan  '; agent = '' } }
        $links = Get-StimulusBacklink -Stimulus $stim
        $links.Count | Should -Be 1
        $links[0].slug | Should -Be 'task-plan'
    }
}

Describe 'New-StimulusIndex' -Tag 'Unit' {
    It 'Returns an empty index when EvalRoot does not exist' {
        $missing = Join-Path $script:RepoRoot ('does-not-exist-' + [Guid]::NewGuid())
        $index = New-StimulusIndex -EvalRoot $missing
        $index.specsScanned | Should -Be 0
        $index.coverage.Keys.Count | Should -Be 0
    }

    It 'Indexes prompt backlinks from the behavior-conformance suite' {
        $index = New-StimulusIndex -EvalRoot $script:EvalsRoot
        $index.specsScanned | Should -BeGreaterThan 0

        $promptKeys = $index.coverage.Keys | Where-Object { $_ -like 'prompt:*' }
        $promptKeys.Count | Should -BeGreaterOrEqual 10

        $key = 'prompt:task-plan'
        $index.coverage.ContainsKey($key) | Should -BeTrue
        $index.coverage[$key] -join ';' | Should -Match 'behavior-conformance/prompts\.eval\.yaml'
    }

    It 'Indexes instruction backlinks from the behavior-conformance suite' {
        $index = New-StimulusIndex -EvalRoot $script:EvalsRoot

        $instructionKeys = $index.coverage.Keys | Where-Object { $_ -like 'instruction:*' }
        $instructionKeys.Count | Should -BeGreaterOrEqual 30

        $key = 'instruction:ado-backlog-sprint'
        $index.coverage.ContainsKey($key) | Should -BeTrue
        $index.coverage[$key] -join ';' | Should -Match 'behavior-conformance/instructions\.eval\.yaml'
    }

    It 'Indexes skill backlinks from the behavior-conformance suite' {
        $index = New-StimulusIndex -EvalRoot $script:EvalsRoot

        $skillKeys = $index.coverage.Keys | Where-Object { $_ -like 'skill:*' }
        $skillKeys.Count | Should -BeGreaterOrEqual 20

        $key = 'skill:python-foundational'
        $index.coverage.ContainsKey($key) | Should -BeTrue
        $index.coverage[$key] -join ';' | Should -Match 'behavior-conformance/skill-behavior\.eval\.yaml'
    }

    It 'Continues past unparseable spec files and records them under errors' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
        try {
            New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $tempRoot 'broken.yaml') -Value ":\n  - not: [valid"
            $index = New-StimulusIndex -EvalRoot $tempRoot
            $index.specsScanned | Should -Be 1
            $index.errors.Count | Should -BeGreaterOrEqual 1
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Test-StimulusCoverage' -Tag 'Unit' {
    BeforeAll {
        $script:Index = New-StimulusIndex -EvalRoot $script:EvalsRoot
    }

    It 'Returns covering spec paths for a known prompt backlink' {
        $paths = Test-StimulusCoverage -Index $script:Index -Kind 'prompt' -ArtifactId 'task-plan'
        $paths.Count | Should -BeGreaterOrEqual 1
        ($paths -join ';') | Should -Match 'behavior-conformance/prompts\.eval\.yaml'
    }

    It 'Returns covering spec paths for a known instruction backlink' {
        $paths = Test-StimulusCoverage -Index $script:Index -Kind 'instruction' -ArtifactId 'ado-backlog-sprint'
        $paths.Count | Should -BeGreaterOrEqual 1
        ($paths -join ';') | Should -Match 'behavior-conformance/instructions\.eval\.yaml'
    }

    It 'Returns an empty array for an unknown artifact' {
        $paths = Test-StimulusCoverage -Index $script:Index -Kind 'prompt' -ArtifactId 'definitely-not-a-prompt-xyz'
        $paths.Count | Should -Be 0
    }
}

Describe 'Advisory spec detection (Invoke-VallyEvals integration)' -Tag 'Unit' {
    BeforeAll {
        $script:DispatcherPath = Join-Path $script:RepoRoot 'scripts/evals/Invoke-VallyEvals.ps1'
        $script:AdvisorySpec = Join-Path $script:RepoRoot 'evals/behavior-conformance/prompts.eval.yaml'

        # Load the dispatcher with parameter binding suppressed so its functions
        # become available without running the dispatch logic.
        $dispatcherScript = Get-Command $script:DispatcherPath -ErrorAction Stop
        $advisoryFn = $dispatcherScript.ScriptBlock.Ast.FindAll(
            { param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Test-SpecIsAdvisory' },
            $true
        ) | Select-Object -First 1

        if ($null -eq $advisoryFn) {
            throw "Test-SpecIsAdvisory function not found in dispatcher script."
        }

        $script:AdvisoryScriptBlock = [scriptblock]::Create($advisoryFn.Extent.Text)
        . $script:AdvisoryScriptBlock
    }

    It 'Identifies the prompt-conformance spec as advisory' {
        Test-SpecIsAdvisory -SpecPath $script:AdvisorySpec | Should -BeTrue
    }

    It 'Returns $false for an authoritative spec without tags.advisory' {
        $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString() + '.yaml')
        try {
            $spec = @{
                name = 'auth'
                type = 'capability'
                config = @{ executor = 'copilot-sdk' }
                stimuli = @(@{ name = 's1'; prompt = 'hi'; graders = @(@{ type = 'exact-match'; value = 'hi' }) })
            }
            ($spec | ConvertTo-Yaml) | Set-Content -LiteralPath $tempPath -Encoding utf8
            Test-SpecIsAdvisory -SpecPath $tempPath | Should -BeFalse
        }
        finally {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Returns $false when only some stimuli carry tags.advisory' {
        $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString() + '.yaml')
        try {
            $spec = @{
                name = 'mixed'
                type = 'capability'
                config = @{ executor = 'copilot-sdk' }
                stimuli = @(
                    @{ name = 's1'; prompt = 'a'; graders = @(@{ type = 'exact-match'; value = 'a' }); tags = @{ advisory = $true } },
                    @{ name = 's2'; prompt = 'b'; graders = @(@{ type = 'exact-match'; value = 'b' }) }
                )
            }
            ($spec | ConvertTo-Yaml) | Set-Content -LiteralPath $tempPath -Encoding utf8
            Test-SpecIsAdvisory -SpecPath $tempPath | Should -BeFalse
        }
        finally {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }
    }
}
