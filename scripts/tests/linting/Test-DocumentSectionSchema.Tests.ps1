#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:SchemaPath = Resolve-Path (Join-Path $PSScriptRoot '../../linting/schemas/document-section.schema.json')
    $script:SchemaJson = Get-Content -Path $script:SchemaPath -Raw
    $script:SchemaObject = $script:SchemaJson | ConvertFrom-Json -AsHashtable

    function Test-Section {
        param([Parameter(Mandatory)][hashtable]$Section)
        $json = $Section | ConvertTo-Json -Depth 20
        return Test-Json -Json $json -SchemaFile $script:SchemaPath -ErrorAction SilentlyContinue
    }

    function New-ValidSection {
        return @{
            id       = 'exec-summary'
            title    = 'Executive Summary'
            template = '## {{project_name}} Summary'
        }
    }
}

Describe 'document-section schema' -Tag 'Unit' {
    Context 'baseline' {
        It 'accepts a minimally valid section' {
            Test-Section (New-ValidSection) | Should -BeTrue
        }

        It 'accepts a section with all optional fields' {
            $section = New-ValidSection
            $section.description = 'High-level project overview'
            $section.inputs = @(
                @{ name = 'project_name'; description = 'Name of the project'; required = $true }
            )
            $section.applicability = @{
                discriminator = 'doc-type'
                appliesWhen   = @('prd', 'brd')
            }
            $section.evidenceHints = @('docs/**/*.md')
            Test-Section $section | Should -BeTrue
        }
    }

    Context 'required fields' {
        It 'rejects section without id' {
            $section = New-ValidSection
            $section.Remove('id')
            Test-Section $section | Should -BeFalse
        }

        It 'rejects section without title' {
            $section = New-ValidSection
            $section.Remove('title')
            Test-Section $section | Should -BeFalse
        }

        It 'rejects section without template' {
            $section = New-ValidSection
            $section.Remove('template')
            Test-Section $section | Should -BeFalse
        }

        It 'rejects empty id' {
            $section = New-ValidSection
            $section.id = ''
            Test-Section $section | Should -BeFalse
        }

        It 'rejects empty title' {
            $section = New-ValidSection
            $section.title = ''
            Test-Section $section | Should -BeFalse
        }

        It 'rejects empty template' {
            $section = New-ValidSection
            $section.template = ''
            Test-Section $section | Should -BeFalse
        }
    }

    Context 'id format is lower-kebab' {
        It 'accepts lower-kebab id' {
            $section = New-ValidSection
            $section.id = 'risk-analysis'
            Test-Section $section | Should -BeTrue
        }

        It 'rejects id with uppercase' {
            $section = New-ValidSection
            $section.id = 'Risk-Analysis'
            Test-Section $section | Should -BeFalse
        }

        It 'rejects id starting with a number' {
            $section = New-ValidSection
            $section.id = '1-risk'
            Test-Section $section | Should -BeFalse
        }

        It 'rejects id with underscores' {
            $section = New-ValidSection
            $section.id = 'risk_analysis'
            Test-Section $section | Should -BeFalse
        }
    }

    Context 'inputs array' {
        It 'accepts inputs with name only' {
            $section = New-ValidSection
            $section.inputs = @(@{ name = 'project_name' })
            Test-Section $section | Should -BeTrue
        }

        It 'accepts inputs with all fields' {
            $section = New-ValidSection
            $section.inputs = @(
                @{
                    name        = 'project_name'
                    description = 'Project display name'
                    required    = $true
                    persistence = 'session'
                }
            )
            Test-Section $section | Should -BeTrue
        }

        It 'rejects input with empty name' {
            $section = New-ValidSection
            $section.inputs = @(@{ name = '' })
            Test-Section $section | Should -BeFalse
        }

        It 'rejects input name with invalid characters' {
            $section = New-ValidSection
            $section.inputs = @(@{ name = 'project-name' })
            Test-Section $section | Should -BeFalse
        }

        It 'accepts input name with underscores' {
            $section = New-ValidSection
            $section.inputs = @(@{ name = 'my_var_2' })
            Test-Section $section | Should -BeTrue
        }

        It 'rejects unknown persistence value' {
            $section = New-ValidSection
            $section.inputs = @(@{ name = 'x'; persistence = 'global' })
            Test-Section $section | Should -BeFalse
        }

        It 'accepts all valid persistence values' {
            foreach ($val in @('none', 'session', 'project', 'user')) {
                $section = New-ValidSection
                $section.inputs = @(@{ name = 'x'; persistence = $val })
                Test-Section $section | Should -BeTrue -Because "persistence '$val' should be accepted"
            }
        }
    }

    Context 'applicability discriminator' {
        It 'accepts applicability with appliesWhen' {
            $section = New-ValidSection
            $section.applicability = @{
                discriminator = 'project-type'
                appliesWhen   = @('greenfield')
            }
            Test-Section $section | Should -BeTrue
        }

        It 'accepts applicability with naWhen and naReason' {
            $section = New-ValidSection
            $section.applicability = @{
                discriminator = 'project-type'
                naWhen        = @('maintenance')
                naReason      = 'Not relevant for maintenance projects'
            }
            Test-Section $section | Should -BeTrue
        }

        It 'rejects applicability with unknown property' {
            $section = New-ValidSection
            $section.applicability = @{
                discriminator = 'type'
                appliesWhen   = @('x')
                unknown       = 'bad'
            }
            Test-Section $section | Should -BeFalse
        }
    }

    Context 'evidenceHints are paths or globs' {
        It 'accepts path-like evidence hints' {
            $section = New-ValidSection
            $section.evidenceHints = @('src/**/*.ps1', '.github/workflows/ci.yml')
            Test-Section $section | Should -BeTrue
        }

        It 'rejects prose evidence hints with spaces' {
            $section = New-ValidSection
            $section.evidenceHints = @('See the policy document for details.')
            Test-Section $section | Should -BeFalse
        }
    }

    Context 'selectWhen predicate (Phase 4 / Ext 5)' {
        It 'accepts selectWhen with discriminator + values' {
            $section = New-ValidSection
            $section.selectWhen = @{
                discriminator = 'prd_template_variant'
                values        = @('regulated')
            }
            Test-Section $section | Should -BeTrue
        }

        It 'accepts selectWhen with discriminator + notValues (negation)' {
            $section = New-ValidSection
            $section.selectWhen = @{
                discriminator = 'prd_template_variant'
                notValues     = @('legacy')
            }
            Test-Section $section | Should -BeTrue
        }

        It 'accepts selectWhen with both values and notValues' {
            $section = New-ValidSection
            $section.selectWhen = @{
                discriminator = 'prd_template_variant'
                values        = @('regulated', 'standard')
                notValues     = @('legacy')
            }
            Test-Section $section | Should -BeTrue
        }

        It 'accepts selectWhen alongside applicability (positive selection vs exclusion)' {
            $section = New-ValidSection
            $section.applicability = @{
                discriminator = 'doc-type'
                appliesWhen   = @('prd')
            }
            $section.selectWhen = @{
                discriminator = 'prd_template_variant'
                values        = @('regulated')
            }
            Test-Section $section | Should -BeTrue
        }

        It 'rejects selectWhen without discriminator' {
            $section = New-ValidSection
            $section.selectWhen = @{
                values = @('regulated')
            }
            Test-Section $section | Should -BeFalse
        }

        It 'rejects selectWhen with neither values nor notValues' {
            $section = New-ValidSection
            $section.selectWhen = @{
                discriminator = 'prd_template_variant'
            }
            Test-Section $section | Should -BeFalse
        }

        It 'rejects selectWhen with empty values array' {
            $section = New-ValidSection
            $section.selectWhen = @{
                discriminator = 'prd_template_variant'
                values        = @()
            }
            Test-Section $section | Should -BeFalse
        }

        It 'rejects selectWhen with duplicate values' {
            $section = New-ValidSection
            $section.selectWhen = @{
                discriminator = 'prd_template_variant'
                values        = @('regulated', 'regulated')
            }
            Test-Section $section | Should -BeFalse
        }

        It 'rejects unknown selectWhen property' {
            $section = New-ValidSection
            $section.selectWhen = @{
                discriminator = 'prd_template_variant'
                values        = @('regulated')
                custom        = 'nope'
            }
            Test-Section $section | Should -BeFalse
        }
    }

    Context 'additionalProperties rejected' {
        It 'rejects unknown top-level property' {
            $section = New-ValidSection
            $section.custom = 'not-allowed'
            Test-Section $section | Should -BeFalse
        }
    }

    Context 'schema metadata' {
        It 'declares $id at the top level' {
            $script:SchemaObject['$id'] | Should -Not -BeNullOrEmpty
        }

        It 'declares $id as an http(s) URL' {
            $script:SchemaObject['$id'] | Should -Match '^https?://'
        }

        It 'sets title to Document-Section Item' {
            $script:SchemaObject['title'] | Should -Be 'Document-Section Item'
        }
    }
}
