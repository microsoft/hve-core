#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../plugins/Modules/PluginHelpers.psm1') -Force

    $script:PackageMetadata = @{ id = 'rpi'; name = 'rpi'; description = 'RPI workflow package' }
    $script:ReadmeItems = @(
        @{ Name = 'rpi'; Description = 'Plans work.'; Kind = 'agent'; Maturity = 'stable' }
        @{ Name = 'plan'; Description = 'Creates a plan.'; Kind = 'prompt'; Maturity = 'preview' }
        @{ Name = 'location'; Description = 'Finds artifacts.'; Kind = 'instruction'; Maturity = 'experimental' }
        @{ Name = 'rpi-plan'; Description = 'Builds plans.'; Kind = 'skill'; Maturity = 'stable' }
        @{ Name = 'telemetry'; Description = 'Records events.'; Kind = 'hook' }
    )

    function ConvertTo-NormalizedText {
        param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)
        return ($Text -replace "`r`n", "`n")
    }
}

Describe 'Split-PluginDocumentationSource' -Tag 'Unit' {
    Context 'when the document is absent or blank' {
        It 'Returns empty parts for <Label>' -ForEach @(
            @{ Label = 'null'; Value = $null }
            @{ Label = 'empty string'; Value = '' }
            @{ Label = 'whitespace'; Value = "   `n`t " }
        ) {
            $parsed = Split-PluginDocumentationSource -Content $Value
            $parsed.Title | Should -BeExactly ''
            $parsed.Notice | Should -BeExactly ''
            $parsed.Body | Should -BeExactly ''
        }
    }

    Context 'when the document declares a frontmatter title' {
        BeforeAll {
            $script:frontmatterParsed = Split-PluginDocumentationSource -Content (
                "---`ntitle: Contoso RPI`ndescription: Package prose`n---`n`nOverview prose.`n"
            )
        }

        It 'Uses the frontmatter title' {
            $script:frontmatterParsed.Title | Should -BeExactly 'Contoso RPI'
        }

        It 'Removes the frontmatter from the body' {
            $script:frontmatterParsed.Body | Should -BeExactly 'Overview prose.'
        }
    }

    Context 'when the document leads with an H1 and no frontmatter title' {
        BeforeAll {
            $script:headingParsed = Split-PluginDocumentationSource -Content "# Legacy Heading`n`nOverview prose.`n"
        }

        It 'Falls back to the H1 text' {
            $script:headingParsed.Title | Should -BeExactly 'Legacy Heading'
        }

        It 'Removes the H1 from the body' {
            $script:headingParsed.Body | Should -BeExactly 'Overview prose.'
        }
    }

    Context 'when both a frontmatter title and a leading H1 are present' {
        BeforeAll {
            $script:bothParsed = Split-PluginDocumentationSource -Content (
                "---`ntitle: Frontmatter Wins`n---`n# Legacy Heading`n`nOverview prose.`n"
            )
        }

        It 'Prefers the frontmatter title' {
            $script:bothParsed.Title | Should -BeExactly 'Frontmatter Wins'
        }

        It 'Still removes the H1 from the body' {
            $script:bothParsed.Body | Should -BeExactly 'Overview prose.'
        }
    }

    Context 'when the document carries a package notice block' {
        BeforeAll {
            $script:noticeParsed = Split-PluginDocumentationSource -Content (
                "---`ntitle: Contoso RPI`n---`n" +
                "<!-- BEGIN PACKAGE NOTICE -->`n> Requires a Contoso account.`n<!-- END PACKAGE NOTICE -->`n" +
                "`n  Overview prose.  `n`n"
            )
        }

        It 'Extracts the trimmed notice text' {
            $script:noticeParsed.Notice | Should -BeExactly '> Requires a Contoso account.'
        }

        It 'Removes the notice block from the body' {
            $script:noticeParsed.Body | Should -Not -Match 'PACKAGE NOTICE'
        }

        It 'Trims the remaining body' {
            $script:noticeParsed.Body | Should -BeExactly 'Overview prose.'
        }
    }

    Context 'when the document uses CRLF line endings' {
        It 'Normalizes to newline-separated body text' {
            $parsed = Split-PluginDocumentationSource -Content "---`r`ntitle: Contoso RPI`r`n---`r`n`r`nFirst.`r`nSecond.`r`n"
            $parsed.Title | Should -BeExactly 'Contoso RPI'
            $parsed.Body | Should -BeExactly "First.`nSecond."
        }
    }

    Context 'when the frontmatter is not parsable YAML' {
        BeforeAll {
            $script:malformedContent = "---`ntitle: 'unterminated`n---`n`nProse.`n"
        }

        It 'Does not throw' {
            { Split-PluginDocumentationSource -Content $script:malformedContent } | Should -Not -Throw
        }

        It 'Returns an empty title and the remaining body' {
            $parsed = Split-PluginDocumentationSource -Content $script:malformedContent
            $parsed.Title | Should -BeExactly ''
            $parsed.Body | Should -BeExactly 'Prose.'
        }
    }
}

Describe 'New-PluginReadmeContent' -Tag 'Unit' {
    Context 'when every artifact kind is present and no package document is supplied' {
        BeforeAll {
            $script:fullReadme = ConvertTo-NormalizedText -Text (
                New-PluginReadmeContent -PackageMetadata $script:PackageMetadata -Items $script:ReadmeItems
            )
            $script:expectedReadme = (@(
                    '<!-- markdownlint-disable-file -->'
                    '# rpi'
                    ''
                    'RPI workflow package'
                    ''
                    '## Install'
                    ''
                    '```bash'
                    'copilot plugin install rpi@hve-core'
                    '```'
                    ''
                    '## Agents'
                    ''
                    '| Agent | Maturity | Description |'
                    '|-------|----------|-------------|'
                    '| rpi   | stable   | Plans work. |'
                    ''
                    '## Commands'
                    ''
                    '| Command | Maturity | Description     |'
                    '|---------|----------|-----------------|'
                    '| plan    | preview  | Creates a plan. |'
                    ''
                    '## Instructions'
                    ''
                    '| Instruction | Maturity     | Description      |'
                    '|-------------|--------------|------------------|'
                    '| location    | experimental | Finds artifacts. |'
                    ''
                    '## Skills'
                    ''
                    '| Skill    | Maturity | Description   |'
                    '|----------|----------|---------------|'
                    '| rpi-plan | stable   | Builds plans. |'
                    ''
                    '## Hooks'
                    ''
                    '| Hook      | Maturity | Description     |'
                    '|-----------|----------|-----------------|'
                    '| telemetry | stable   | Records events. |'
                    ''
                    '---'
                    ''
                    '> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)'
                    ''
                ) -join "`n") + "`n"
        }

        It 'Renders the complete README exactly' {
            $script:fullReadme | Should -BeExactly $script:expectedReadme
        }

        It 'Orders artifact sections agents, commands, instructions, skills, hooks' {
            $headingOrder = @([regex]::Matches($script:fullReadme, '(?m)^## (Agents|Commands|Instructions|Skills|Hooks)$') |
                    ForEach-Object { $_.Groups[1].Value })
            $headingOrder | Should -Be @('Agents', 'Commands', 'Instructions', 'Skills', 'Hooks')
        }

        It 'Discloses every canonical lifecycle label present in the recipe' {
            foreach ($label in @('stable', 'preview', 'experimental')) {
                $script:fullReadme | Should -Match "(?m)^\|[^|]+\| $label\s*\|"
            }
        }

        It 'Discloses the canonical stable default for an unlabeled item' {
            $script:fullReadme | Should -Match '(?m)^\| telemetry \| stable   \|'
        }
    }

    Context 'when only one artifact kind is present' {
        BeforeAll {
            $script:singleKindReadme = ConvertTo-NormalizedText -Text (
                New-PluginReadmeContent -PackageMetadata $script:PackageMetadata `
                    -Items @(@{ Name = 'rpi'; Description = 'Plans work.'; Kind = 'agent' })
            )
        }

        It 'Emits the agents section' {
            $script:singleKindReadme | Should -Match '(?m)^## Agents$'
        }

        It 'Omits sections for absent kinds' {
            foreach ($absentHeading in @('## Commands', '## Instructions', '## Skills', '## Hooks')) {
                $script:singleKindReadme | Should -Not -Match "(?m)^$([regex]::Escape($absentHeading))$"
            }
        }
    }

    Context 'when the package has no items at all' {
        It 'Still emits the title, install block, and fixed source footer' {
            $emptyReadme = ConvertTo-NormalizedText -Text (
                New-PluginReadmeContent -PackageMetadata $script:PackageMetadata -Items @()
            )
            $emptyReadme | Should -BeExactly ((@(
                            '<!-- markdownlint-disable-file -->'
                            '# rpi'
                            ''
                            'RPI workflow package'
                            ''
                            '## Install'
                            ''
                            '```bash'
                            'copilot plugin install rpi@hve-core'
                            '```'
                            ''
                            '---'
                            ''
                            '> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)'
                            ''
                        ) -join "`n") + "`n")
        }
    }

    Context 'when a package maturity is declared' {
        It 'Injects the <Label> notice' -ForEach @(
            @{ Label = 'experimental'; Maturity = 'experimental'; Pattern = '> \*\*.+ Experimental\*\* .+ This package is experimental\.' }
            @{ Label = 'preview'; Maturity = 'preview'; Pattern = '> \*\*.+ Preview\*\* .+ This package is in preview\.' }
        ) {
            $readme = ConvertTo-NormalizedText -Text (
                New-PluginReadmeContent -PackageMetadata $script:PackageMetadata -Items @() -Maturity $Maturity
            )
            $readme | Should -Match $Pattern
        }

        It 'Injects no notice for <Label>' -ForEach @(
            @{ Label = 'stable'; Maturity = 'stable' }
            @{ Label = 'an empty maturity'; Maturity = '' }
        ) {
            $readme = ConvertTo-NormalizedText -Text (
                New-PluginReadmeContent -PackageMetadata $script:PackageMetadata -Items @() -Maturity $Maturity
            )
            $readme | Should -Not -Match 'Experimental'
            $readme | Should -Not -Match 'Preview'
        }
    }

    Context 'when the package document supplies a title, notice, and overview' {
        BeforeAll {
            $script:documentReadme = ConvertTo-NormalizedText -Text (
                New-PluginReadmeContent -PackageMetadata $script:PackageMetadata -Items @() -PackageDocumentation (
                    "---`ntitle: Contoso RPI Workflow`n---`n" +
                    "<!-- BEGIN PACKAGE NOTICE -->`n> Requires a Contoso account.`n<!-- END PACKAGE NOTICE -->`n" +
                    "`nDurable prose paragraph.`n"
                )
            )
        }

        It 'Uses the document title as the README heading' {
            $script:documentReadme | Should -Match '(?m)^# Contoso RPI Workflow$'
            $script:documentReadme | Should -Not -Match '(?m)^# rpi$'
        }

        It 'Places the notice after the description and before the overview' {
            $noticeIndex = $script:documentReadme.IndexOf('> Requires a Contoso account.')
            $descriptionIndex = $script:documentReadme.IndexOf('RPI workflow package')
            $overviewIndex = $script:documentReadme.IndexOf('## Overview')
            $noticeIndex | Should -BeGreaterThan $descriptionIndex
            $overviewIndex | Should -BeGreaterThan $noticeIndex
        }

        It 'Emits the document body as the overview section' {
            $script:documentReadme | Should -Match "(?m)^## Overview$"
            $script:documentReadme | Should -Match '(?m)^Durable prose paragraph\.$'
        }
    }

    Context 'when the package metadata declares its own notice' {
        It 'Prefers the metadata notice over the document notice' {
            $readme = ConvertTo-NormalizedText -Text (
                New-PluginReadmeContent -PackageMetadata @{
                    id = 'rpi'; name = 'rpi'; description = 'RPI workflow package'; notice = '> Metadata notice.'
                } -Items @() -PackageDocumentation (
                    "<!-- BEGIN PACKAGE NOTICE -->`n> Document notice.`n<!-- END PACKAGE NOTICE -->`n`nProse.`n"
                )
            )
            $readme | Should -Match '(?m)^> Metadata notice\.$'
            $readme | Should -Not -Match 'Document notice'
        }
    }

    Context 'when the package document body is only whitespace' {
        It 'Omits the overview section' {
            $readme = ConvertTo-NormalizedText -Text (
                New-PluginReadmeContent -PackageMetadata $script:PackageMetadata -Items @() -PackageDocumentation (
                    "---`ntitle: Contoso RPI Workflow`n---`n`n   `n`t`n"
                )
            )
            $readme | Should -Not -Match '## Overview'
        }
    }

    Context 'when the package document already inventories artifacts' {
        It 'Suppresses generated tables for <Label>' -ForEach @(
            @{ Label = 'an Included Artifacts heading'; Documentation = "---`ntitle: Contoso RPI`n---`n`nProse.`n`n## Included Artifacts`n`nTable lives here.`n" }
            @{ Label = 'auto-generated markers'; Documentation = "---`ntitle: Contoso RPI`n---`n`nProse.`n`n<!-- BEGIN AUTO-GENERATED ARTIFACTS -->`n`n<!-- END AUTO-GENERATED ARTIFACTS -->`n" }
        ) {
            $readme = ConvertTo-NormalizedText -Text (
                New-PluginReadmeContent -PackageMetadata $script:PackageMetadata -Items $script:ReadmeItems -PackageDocumentation $Documentation
            )
            $readme | Should -Not -Match '(?m)^## Agents$'
            $readme | Should -Not -Match '(?m)^## Skills$'
        }
    }
}

AfterAll {
    Remove-Module PluginHelpers -Force -ErrorAction SilentlyContinue
}
