#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

Describe 'OutputPath Parameter' -Tag 'Unit' {
    Context 'OutputPath parameter exists' {
        It 'Has OutputPath parameter defined in the script' {
            $scriptPath = Join-Path $PSScriptRoot '../../linting/Validate-MarkdownFrontmatter.ps1'
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '\[string\]\$OutputPath\s*='
        }
    }

    Context 'OutputPath is used in Export' {
        It 'Uses OutputPath variable in Export-ValidationResults call' {
            $scriptPath = Join-Path $PSScriptRoot '../../linting/Validate-MarkdownFrontmatter.ps1'
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'Export-ValidationResults.*\$OutputPath'
        }
    }
}
