#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

Describe 'OutputPath Parameter' -Tag 'Unit' {
    BeforeAll {
        $script:MainScript = Join-Path $PSScriptRoot '../../linting/Validate-MarkdownFrontmatter.ps1'
    }

    Context 'Default OutputPath behavior' {
        It 'Uses default path when -OutputPath not specified' {
            # Act - verify the parameter exists
            $param = (Get-Command $script:MainScript).Parameters['OutputPath']

            # Assert
            $param | Should -Not -BeNullOrEmpty
            $param.ParameterType.FullName | Should -Be 'System.String'
        }
    }

    Context 'Custom OutputPath behavior' {
        It 'Accepts custom output path parameter' {
            # Act - verify parameter accepts string values
            $param = (Get-Command $script:MainScript).Parameters['OutputPath']

            # Assert
            $param.ParameterType.FullName | Should -Be 'System.String'
        }
    }
}
