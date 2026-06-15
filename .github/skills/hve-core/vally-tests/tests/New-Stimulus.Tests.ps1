#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

Describe 'New-Stimulus' -Tag 'Unit' {
    BeforeAll {
        $script:scriptPath = Join-Path $PSScriptRoot '../scripts/New-Stimulus.ps1'
        $script:testRoot = Join-Path ([System.IO.Path]::GetTempPath()) "vally-stimulus-$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $script:testRoot -Force | Out-Null
    }

    AfterAll {
        if (Test-Path $script:testRoot) {
            Remove-Item $script:testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Parameter validation' {
        It 'Has a mandatory <Name> parameter' -ForEach @(
            @{ Name = 'ArtifactPath' }
            @{ Name = 'Kind' }
            @{ Name = 'PromptText' }
        ) {
            $param = (Get-Command $script:scriptPath).Parameters[$Name]
            $param | Should -Not -BeNullOrEmpty
            $attr = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
            $attr.Mandatory | Should -BeTrue
        }

        It 'Rejects an invalid Kind value' {
            { & $script:scriptPath -ArtifactPath 'x.prompt.md' -Kind 'invalid' -PromptText 'hi' } |
                Should -Throw
        }
    }

    Context 'Stdout emission' {
        BeforeAll {
            $script:block = & $script:scriptPath `
                -ArtifactPath '.github/prompts/hve-core/task-research.prompt.md' `
                -Kind prompt -PromptText 'Invoke task-research with topic=X.' | Out-String
        }

        It 'Emits a named stimulus block with a slugified artifact leaf' {
            $script:block | Should -Match '- name: task-research-conformance-[0-9a-f]{8}'
        }

        It 'Includes the prompt block scalar' {
            $script:block | Should -Match '(?m)^\s+prompt: \|'
            $script:block | Should -Match 'Invoke task-research with topic=X\.'
        }

        It 'Tags the block with the routed category for prompt kind' {
            $script:block | Should -Match 'category: behavior-conformance'
            $script:block | Should -Match 'kind: prompt'
        }

        It 'Surfaces the prompt_sha256 dedupe key' {
            $script:block | Should -Match 'prompt_sha256: [0-9a-f]{64}'
        }

        It 'Defaults to the output-matches grader type' {
            $script:block | Should -Match 'type: output-matches'
        }
    }

    Context 'Kind to category routing' {
        It 'Routes agent kind to the agent-behavior category' {
            $block = & $script:scriptPath `
                -ArtifactPath '.github/agents/hve-core/task-researcher.agent.md' `
                -Kind agent -PromptText 'Exercise the agent.' | Out-String

            $block | Should -Match 'category: agent-behavior'
            $block | Should -Match 'kind: agent'
        }
    }

    Context 'Grader type selection' {
        It 'Emits a prompt grader block when GraderType is prompt' {
            $block = & $script:scriptPath -ArtifactPath 'x.prompt.md' -Kind prompt `
                -PromptText 'hi' -GraderType prompt | Out-String

            $block | Should -Match 'type: prompt'
            $block | Should -Match 'scoring: scale_1_5'
        }

        It 'Emits an output-contains grader block when GraderType is output-contains' {
            $block = & $script:scriptPath -ArtifactPath 'x.prompt.md' -Kind prompt `
                -PromptText 'hi' -GraderType output-contains | Out-String

            $block | Should -Match 'type: output-contains'
            $block | Should -Match 'substring:'
        }
    }

    Context 'Normalized hash determinism' {
        It 'Produces the same hash regardless of case and whitespace' {
            $a = & $script:scriptPath -ArtifactPath 'x.prompt.md' -Kind prompt `
                -PromptText 'Hello   World' | Out-String
            $b = & $script:scriptPath -ArtifactPath 'x.prompt.md' -Kind prompt `
                -PromptText 'hello world' | Out-String

            $hashA = [Regex]::Match($a, 'prompt_sha256: ([0-9a-f]{64})').Groups[1].Value
            $hashB = [Regex]::Match($b, 'prompt_sha256: ([0-9a-f]{64})').Groups[1].Value

            $hashA | Should -Not -BeNullOrEmpty
            $hashA | Should -Be $hashB
        }
    }

    Context 'Output file append' {
        It 'Creates the file with a stimuli header and appends the block' {
            $outFile = Join-Path $script:testRoot 'suite.eval.yaml'

            $msg = & $script:scriptPath -ArtifactPath 'x.prompt.md' -Kind prompt `
                -PromptText 'first prompt' -OutputPath $outFile | Out-String

            $msg | Should -Match 'Appended stimulus'
            $content = Get-Content -LiteralPath $outFile -Raw
            $content | Should -Match '(?m)^stimuli:'
            $content | Should -Match '- name: x-conformance-'
        }

        It 'Appends additional blocks to an existing file without re-adding the header' {
            $outFile = Join-Path $script:testRoot 'suite-append.eval.yaml'

            & $script:scriptPath -ArtifactPath 'x.prompt.md' -Kind prompt `
                -PromptText 'first prompt' -OutputPath $outFile | Out-Null
            & $script:scriptPath -ArtifactPath 'y.prompt.md' -Kind prompt `
                -PromptText 'second prompt' -OutputPath $outFile | Out-Null

            $content = Get-Content -LiteralPath $outFile -Raw
            ([Regex]::Matches($content, '(?m)^stimuli:')).Count | Should -Be 1
            ([Regex]::Matches($content, '- name: ')).Count | Should -Be 2
        }
    }
}
