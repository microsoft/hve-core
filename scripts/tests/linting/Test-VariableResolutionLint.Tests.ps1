#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../linting/Validate-FsiContent.ps1')

    $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "fsi-varres-tests-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null

    function Write-TempItemYaml {
        param(
            [Parameter(Mandatory)][string]$FileName,
            [Parameter(Mandatory)][string]$Content
        )
        $path = Join-Path $script:TempDir $FileName
        Set-Content -Path $path -Value $Content -Encoding utf8
        return $path
    }
}

AfterAll {
    if (Test-Path $script:TempDir) {
        Remove-Item -Recurse -Force $script:TempDir
    }
}

Describe 'Test-FsiVariableResolution' -Tag 'Unit' {
    Context 'resolved variables' {
        It 'resolves a variable from inputs' {
            $path = Write-TempItemYaml 'input-resolved.yml' @'
id: section-a
title: Test
template: "Hello {{project_name}}"
inputs:
  - name: project_name
'@
            $result = Test-FsiVariableResolution -ItemPath $path
            $result.Errors | Should -HaveCount 0
            $result.Warnings | Should -HaveCount 0
        }

        It 'resolves a variable from globals' {
            $path = Write-TempItemYaml 'global-resolved.yml' @'
id: section-b
title: Test
template: "Org: {{org_name}}"
'@
            $result = Test-FsiVariableResolution -ItemPath $path -Globals @{ org_name = $true }
            $result.Errors | Should -HaveCount 0
            $result.Warnings | Should -HaveCount 0
        }

        It 'resolves multiple variables from mixed sources' {
            $path = Write-TempItemYaml 'mixed-resolved.yml' @'
id: section-c
title: Test
template: "{{project_name}} at {{org_name}}"
inputs:
  - name: project_name
'@
            $result = Test-FsiVariableResolution -ItemPath $path -Globals @{ org_name = $true }
            $result.Errors | Should -HaveCount 0
            $result.Warnings | Should -HaveCount 0
        }
    }

    Context 'unresolved variables' {
        It 'errors on a variable not in inputs or globals' {
            $path = Write-TempItemYaml 'unresolved.yml' @'
id: section-d
title: Test
template: "Hello {{unknown_var}}"
'@
            $result = Test-FsiVariableResolution -ItemPath $path
            $result.Errors | Should -HaveCount 1
            $result.Errors[0] | Should -Match 'unknown_var'
            $result.Errors[0] | Should -Match 'unresolved-var'
        }

        It 'errors on each unresolved variable separately' {
            $path = Write-TempItemYaml 'multi-unresolved.yml' @'
id: section-e
title: Test
template: "{{var_a}} and {{var_b}}"
'@
            $result = Test-FsiVariableResolution -ItemPath $path
            $result.Errors | Should -HaveCount 2
        }

        It 'includes the item id in the error message' {
            $path = Write-TempItemYaml 'id-in-error.yml' @'
id: my-section
title: Test
template: "{{missing}}"
'@
            $result = Test-FsiVariableResolution -ItemPath $path
            $result.Errors[0] | Should -Match 'my-section'
        }
    }

    Context 'shadow warnings' {
        It 'warns when an input name shadows a globals key' {
            $path = Write-TempItemYaml 'shadow.yml' @'
id: section-f
title: Test
template: "{{project_name}}"
inputs:
  - name: project_name
'@
            $result = Test-FsiVariableResolution -ItemPath $path -Globals @{ project_name = $true }
            $result.Errors | Should -HaveCount 0
            $result.Warnings | Should -HaveCount 1
            $result.Warnings[0] | Should -Match 'shadow'
        }
    }

    Context 'escaped tokens' {
        It 'ignores escaped \{{var}} tokens' {
            $path = Write-TempItemYaml 'escaped.yml' @'
id: section-g
title: Test
template: 'Literal \{{not_a_var}} here'
'@
            $result = Test-FsiVariableResolution -ItemPath $path
            $result.Errors | Should -HaveCount 0
            $result.Warnings | Should -HaveCount 0
        }

        It 'resolves unescaped tokens next to escaped ones' {
            $path = Write-TempItemYaml 'mixed-escape.yml' @'
id: section-h
title: Test
template: 'Real {{project_name}} and literal \{{fake}}'
inputs:
  - name: project_name
'@
            $result = Test-FsiVariableResolution -ItemPath $path
            $result.Errors | Should -HaveCount 0
        }
    }

    Context 'whitespace tolerance' {
        It 'resolves tokens with internal whitespace' {
            $path = Write-TempItemYaml 'whitespace.yml' @'
id: section-i
title: Test
template: "Hello {{ project_name }}"
inputs:
  - name: project_name
'@
            $result = Test-FsiVariableResolution -ItemPath $path
            $result.Errors | Should -HaveCount 0
        }
    }

    Context 'no template' {
        It 'returns clean result when template is absent' {
            $path = Write-TempItemYaml 'no-template.yml' @'
id: section-j
title: Test
'@
            $result = Test-FsiVariableResolution -ItemPath $path
            $result.Errors | Should -HaveCount 0
            $result.Warnings | Should -HaveCount 0
        }
    }

    Context 'template without variables' {
        It 'returns clean result for plain text template' {
            $path = Write-TempItemYaml 'plain-template.yml' @'
id: section-k
title: Test
template: "This has no variables at all."
'@
            $result = Test-FsiVariableResolution -ItemPath $path
            $result.Errors | Should -HaveCount 0
            $result.Warnings | Should -HaveCount 0
        }
    }

    Context 'malformed YAML' {
        It 'returns parse error for invalid YAML' {
            $path = Write-TempItemYaml 'bad-yaml.yml' @'
id: [unterminated
'@
            $result = Test-FsiVariableResolution -ItemPath $path
            $result.Errors | Should -HaveCount 1
            $result.Errors[0] | Should -Match 'yaml-parse-error'
        }
    }
}
