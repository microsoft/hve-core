#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

Describe 'Select-Grader' -Tag 'Unit' {
    BeforeAll {
        $script:scriptPath = Join-Path $PSScriptRoot '../scripts/Select-Grader.ps1'
    }

    Context 'Parameter validation' {
        It 'Has a mandatory <Name> parameter' -ForEach @(
            @{ Name = 'Kind' }
            @{ Name = 'Check' }
        ) {
            $param = (Get-Command $script:scriptPath).Parameters[$Name]
            $param | Should -Not -BeNullOrEmpty
            $attr = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
            $attr.Mandatory | Should -BeTrue
        }

        It 'Rejects an invalid Kind value' {
            { & $script:scriptPath -Kind 'invalid' -Check 'x' } | Should -Throw
        }
    }

    Context 'Explicit grader type override' {
        It 'Emits a <Type> grader block carrying the check name' -ForEach @(
            @{ Type = 'prompt'; Marker = 'scoring: scale_1_5' }
            @{ Type = 'output-contains'; Marker = 'substring:' }
            @{ Type = 'output-matches'; Marker = 'pattern:' }
        ) {
            $block = & $script:scriptPath -Kind prompt -Check 'agent-attribution' -GraderType $Type | Out-String

            $block | Should -Match "type: $Type"
            $block | Should -Match 'name: agent-attribution'
            $block | Should -Match ([Regex]::Escape($Marker))
        }
    }

    Context 'Instructions kind reference special-case' {
        It 'Resolves the instructions reference without a trailing plural' {
            { & $script:scriptPath -Kind instructions -Check 'some-check' -GraderType output-matches } |
                Should -Not -Throw
            $block = & $script:scriptPath -Kind instructions -Check 'some-check' -GraderType output-matches | Out-String
            $block | Should -Match 'name: some-check'
        }
    }

    Context 'Grader auto-detection from the per-kind reference' {
        It 'Resolves a recommended grader for a documented check heading' {
            $block = & $script:scriptPath -Kind prompt -Check 'Required Frontmatter Fields' | Out-String

            $block | Should -Match 'name: Required Frontmatter Fields'
            $block | Should -Match 'type: (prompt|output-contains|output-matches)'
        }

        It 'Throws when the check is not found in the reference' {
            { & $script:scriptPath -Kind prompt -Check 'this-heading-does-not-exist-xyz' } |
                Should -Throw -ExpectedMessage '*not found*'
        }
    }
}
