#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../linting/Validate-FsiContent.ps1')
}

Describe 'Test-FsiVariableResolution' -Tag 'Unit' {
    Context 'valid resolution via inputs' {
        It 'reports no errors when template var matches an input name' {
            $yaml = @'
id: test-section
title: Test Section
template: "## {{project_name}} Overview"
inputs:
  - name: project_name
    description: Project name
'@
            $path = Join-Path $TestDrive 'valid-input.yml'
            Set-Content -Path $path -Value $yaml -Encoding utf8

            $result = Test-FsiVariableResolution -ItemPath $path -Globals @{}

            $result.Errors | Should -HaveCount 0
            $result.Warnings | Should -HaveCount 0
        }
    }

    Context 'valid resolution via globals' {
        It 'reports no errors when template var matches a globals key' {
            $yaml = @'
id: test-section
title: Test Section
template: "## {{project_name}} Overview"
'@
            $path = Join-Path $TestDrive 'valid-global.yml'
            Set-Content -Path $path -Value $yaml -Encoding utf8

            $result = Test-FsiVariableResolution -ItemPath $path -Globals @{ project_name = $true }

            $result.Errors | Should -HaveCount 0
            $result.Warnings | Should -HaveCount 0
        }
    }

    Context 'unresolved variable' {
        It 'emits error containing unresolved-var for unknown tokens' {
            $yaml = @'
id: test-section
title: Test Section
template: "## {{unknown_var}} Overview"
'@
            $path = Join-Path $TestDrive 'unresolved.yml'
            Set-Content -Path $path -Value $yaml -Encoding utf8

            $result = Test-FsiVariableResolution -ItemPath $path -Globals @{}

            $result.Errors | Should -HaveCount 1
            $result.Errors[0] | Should -Match 'unresolved-var'
            $result.Warnings | Should -HaveCount 0
        }
    }

    Context 'shadow warning' {
        It 'emits warning containing shadow when input name collides with globals key' {
            $yaml = @'
id: test-section
title: Test Section
template: "## {{project_name}} Overview"
inputs:
  - name: project_name
    description: Project name
'@
            $path = Join-Path $TestDrive 'shadow.yml'
            Set-Content -Path $path -Value $yaml -Encoding utf8

            $result = Test-FsiVariableResolution -ItemPath $path -Globals @{ project_name = $true }

            $result.Errors | Should -HaveCount 0
            $result.Warnings | Should -HaveCount 1
            $result.Warnings[0] | Should -Match 'shadow'
        }
    }

    Context 'escaped braces' {
        It 'skips escaped braces and reports no errors' {
            $yaml = @"
id: test-section
title: Test Section
template: |
  ## \{{escaped}} Overview
"@
            $path = Join-Path $TestDrive 'escaped.yml'
            Set-Content -Path $path -Value $yaml -Encoding utf8

            $result = Test-FsiVariableResolution -ItemPath $path -Globals @{}

            $result.Errors | Should -HaveCount 0
            $result.Warnings | Should -HaveCount 0
        }
    }

    Context 'no template field' {
        It 'reports no errors when item has no template' {
            $yaml = @'
id: test-section
title: Test Section
'@
            $path = Join-Path $TestDrive 'no-template.yml'
            Set-Content -Path $path -Value $yaml -Encoding utf8

            $result = Test-FsiVariableResolution -ItemPath $path -Globals @{}

            $result.Errors | Should -HaveCount 0
            $result.Warnings | Should -HaveCount 0
        }
    }

    Context 'YAML parse error' {
        It 'emits error containing yaml-parse-error for invalid YAML' {
            $invalidYaml = @'
id: test-section
title: Test Section
template: "value
  bad: [indent
'@
            $path = Join-Path $TestDrive 'bad-yaml.yml'
            Set-Content -Path $path -Value $invalidYaml -Encoding utf8

            $result = Test-FsiVariableResolution -ItemPath $path -Globals @{}

            $result.Errors | Should -HaveCount 1
            $result.Errors[0] | Should -Match 'yaml-parse-error'
        }
    }

    Context 'multiple variables' {
        It 'resolves some vars and flags unresolved ones independently' {
            $yaml = @'
id: test-section
title: Test Section
template: "## {{project_name}} by {{author}} — {{unknown_field}}"
inputs:
  - name: project_name
    description: Project name
'@
            $path = Join-Path $TestDrive 'multi-var.yml'
            Set-Content -Path $path -Value $yaml -Encoding utf8

            $result = Test-FsiVariableResolution -ItemPath $path -Globals @{ author = $true }

            $result.Errors | Should -HaveCount 1
            $result.Errors[0] | Should -Match 'unknown_field'
            $result.Warnings | Should -HaveCount 0
        }
    }

    Context 'empty globals' {
        It 'resolves against inputs only when globals is empty' {
            $yaml = @'
id: test-section
title: Test Section
template: "## {{project_name}} Overview"
inputs:
  - name: project_name
    description: Project name
'@
            $path = Join-Path $TestDrive 'empty-globals.yml'
            Set-Content -Path $path -Value $yaml -Encoding utf8

            $result = Test-FsiVariableResolution -ItemPath $path -Globals @{}

            $result.Errors | Should -HaveCount 0
            $result.Warnings | Should -HaveCount 0
        }
    }
}
