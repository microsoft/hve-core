#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

Describe 'New-Stimulus' -Tag 'Unit' {
    BeforeAll {
        $script:scriptPath = Join-Path $PSScriptRoot '../scripts/New-Stimulus.ps1'
        $script:bashScriptPath = Join-Path $PSScriptRoot '../scripts/new-stimulus.sh'
        $script:bashScript = ((Get-Content -Raw -LiteralPath $script:bashScriptPath) -replace "`r`n", "`n").TrimEnd() + "`n#"
        $script:testRoot = Join-Path ([System.IO.Path]::GetTempPath()) "vally-stimulus-$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $script:testRoot -Force | Out-Null
        Import-Module powershell-yaml -ErrorAction Stop
        Get-Command bash -ErrorAction Stop | Out-Null

        function Invoke-StimulusScaffolder {
            param(
                [Parameter(Mandatory)][string]$Implementation,
                [Parameter(Mandatory)][string]$ArtifactPath,
                [Parameter(Mandatory)][string]$Kind
            )

            if ($Implementation -eq 'PowerShell') {
                return (& $script:scriptPath -ArtifactPath $ArtifactPath -Kind $Kind `
                        -PromptText 'Exercise the artifact.' | Out-String).TrimEnd()
            }

            $output = $script:bashScript | & bash -s -- --artifact-path $ArtifactPath `
                --kind $Kind --prompt-text 'Exercise the artifact.' 2>&1 | Out-String
            if ($LASTEXITCODE -ne 0) {
                throw $output.Trim()
            }
            return $output.TrimEnd()
        }
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
                -ArtifactPath '.github/prompts/hve-core/rpi.prompt.md' `
                -Kind prompt -PromptText 'Invoke rpi with task=X.' | Out-String
        }

        It 'Emits a named stimulus block with a slugified artifact leaf' {
            $script:block | Should -Match '- name: rpi-conformance-[0-9a-f]{8}'
        }

        It 'Includes the prompt block scalar' {
            $script:block | Should -Match '(?m)^\s+prompt: \|'
            $script:block | Should -Match 'Invoke rpi with task=X\.'
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
                -ArtifactPath '.github/agents/hve-core/rpi-agent.agent.md' `
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

    Context 'Artifact staging' {
        It 'Stages a file artifact at its repository path with a two-level source' {
            $block = & $script:scriptPath `
                -ArtifactPath '.github/agents/hve-core/rpi-agent.agent.md' `
                -Kind agent -PromptText 'Exercise the agent.' | Out-String

            $block | Should -Match '(?m)^    agent_environment:\r?\n      files:\r?\n        - src: "\.\./\.\./\.github/agents/hve-core/rpi-agent\.agent\.md"\r?\n          dest: "\.github/agents/hve-core/rpi-agent\.agent\.md"\r?$'
            $block.IndexOf('agent_environment:') | Should -BeLessThan $block.IndexOf('    tags:')
        }

        It 'Stages a skill artifact as its skill directory' {
            $block = & $script:scriptPath `
                -ArtifactPath '.github/skills/hve-core/vally-tests/SKILL.md' `
                -Kind skill -PromptText 'Exercise the skill.' | Out-String

            $block | Should -Match '(?m)^    agent_environment:\r?\n      skills:\r?\n        - "\.\./\.\./\.github/skills/hve-core/vally-tests"\r?$'
            $block | Should -Not -Match 'files:'
        }

        It 'Normalizes backslash separators in staged paths' {
            $block = & $script:scriptPath -ArtifactPath '.github\prompts\hve-core\rpi.prompt.md' `
                -Kind prompt -PromptText 'hi' | Out-String

            $block | Should -Match 'src: "\.\./\.\./\.github/prompts/hve-core/rpi\.prompt\.md"'
            $block | Should -Match 'dest: "\.github/prompts/hve-core/rpi\.prompt\.md"'
        }

        It 'Round-trips <Implementation> <Kind> path <Case> exactly' -ForEach @(
            @{ Implementation = 'PowerShell'; Kind = 'prompt'; Case = 'with hash'; Path = '.github/prompts/team #1/example.prompt.md'; Expected = '.github/prompts/team #1/example.prompt.md' }
            @{ Implementation = 'Bash'; Kind = 'prompt'; Case = 'with hash'; Path = '.github/prompts/team #1/example.prompt.md'; Expected = '.github/prompts/team #1/example.prompt.md' }
            @{ Implementation = 'PowerShell'; Kind = 'skill'; Case = 'with hash'; Path = '.github/skills/team #1/example/SKILL.md'; Expected = '.github/skills/team #1/example/SKILL.md' }
            @{ Implementation = 'Bash'; Kind = 'skill'; Case = 'with hash'; Path = '.github/skills/team #1/example/SKILL.md'; Expected = '.github/skills/team #1/example/SKILL.md' }
            @{ Implementation = 'PowerShell'; Kind = 'prompt'; Case = 'with quote'; Path = '.github/prompts/team "blue"/example.prompt.md'; Expected = '.github/prompts/team "blue"/example.prompt.md' }
            @{ Implementation = 'Bash'; Kind = 'prompt'; Case = 'with quote'; Path = '.github/prompts/team "blue"/example.prompt.md'; Expected = '.github/prompts/team "blue"/example.prompt.md' }
            @{ Implementation = 'PowerShell'; Kind = 'prompt'; Case = 'with backslashes'; Path = '.github\prompts\team #1\example.prompt.md'; Expected = '.github/prompts/team #1/example.prompt.md' }
            @{ Implementation = 'Bash'; Kind = 'prompt'; Case = 'with backslashes'; Path = '.github\prompts\team #1\example.prompt.md'; Expected = '.github/prompts/team #1/example.prompt.md' }
        ) {
            $block = Invoke-StimulusScaffolder -Implementation $Implementation `
                -ArtifactPath $Path -Kind $Kind
            $document = ConvertFrom-Yaml -Yaml "stimuli:`n$block"
            $stimulus = @($document.stimuli)[0]

            if ($Kind -eq 'skill') {
                $skillDir = $Expected -replace '/SKILL\.md$', ''
                $stimulus.agent_environment.skills[0] | Should -Be "../../$skillDir"
            }
            else {
                $stimulus.agent_environment.files[0].src | Should -Be "../../$Expected"
                $stimulus.agent_environment.files[0].dest | Should -Be $Expected
            }
        }

        It 'Rejects <Case> artifact paths in <Implementation>' -ForEach @(
            @{ Implementation = 'PowerShell'; Case = 'rooted'; Path = '/etc/x.prompt.md' }
            @{ Implementation = 'Bash'; Case = 'rooted'; Path = '/etc/x.prompt.md' }
            @{ Implementation = 'PowerShell'; Case = 'drive-rooted'; Path = 'C:\repo\x.prompt.md' }
            @{ Implementation = 'Bash'; Case = 'drive-rooted'; Path = 'C:\repo\x.prompt.md' }
            @{ Implementation = 'PowerShell'; Case = 'traversal'; Path = '.github/../../x.prompt.md' }
            @{ Implementation = 'Bash'; Case = 'traversal'; Path = '.github/../../x.prompt.md' }
            @{ Implementation = 'PowerShell'; Case = 'multi-line'; Path = ".github/prompts/team`nname/example.prompt.md" }
            @{ Implementation = 'Bash'; Case = 'multi-line'; Path = ".github/prompts/team`nname/example.prompt.md" }
        ) {
            { Invoke-StimulusScaffolder -Implementation $Implementation `
                    -ArtifactPath $Path -Kind prompt } |
                Should -Throw
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
