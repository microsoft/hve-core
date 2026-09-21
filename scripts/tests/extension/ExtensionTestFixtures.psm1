# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

# ExtensionTestFixtures.psm1
# Purpose: Deterministic marketplace, repository, and packaging fixtures for extension tests.

#Requires -Version 7.4

function Set-FixtureFile {
    <#
    .SYNOPSIS
    Writes fixture content with LF endings and no trailing newline injection.
    .PARAMETER Path
    Destination file path.
    .PARAMETER Value
    Exact file content.
    .OUTPUTS
    [void]
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value
    )

    $parent = Split-Path -Path $Path -Parent
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -Path $parent -ItemType Directory -Force | Out-Null
    }
    Set-Content -LiteralPath $Path -Value $Value -Encoding utf8NoBOM -NoNewline
}

function New-FixtureMarkdown {
    <#
    .SYNOPSIS
    Builds a Markdown fixture with description frontmatter.
    .PARAMETER Name
    Frontmatter name value, omitted when empty.
    .PARAMETER Description
    Frontmatter description value.
    .PARAMETER Handoff
    Optional handoff targets.
    .PARAMETER Body
    Body text after the frontmatter.
    .OUTPUTS
    [string] Markdown content.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Name = '',

        [Parameter(Mandatory = $true)]
        [string]$Description,

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [string[]]$Handoff = @(),

        [Parameter(Mandatory = $false)]
        [string]$Body = 'Fixture body.'
    )

    $lines = @('---')
    if ($Name) { $lines += "name: $Name" }
    $lines += "description: $Description"
    if ($Handoff.Count -gt 0) {
        $lines += 'handoffs:'
        foreach ($target in $Handoff) { $lines += "  - $target" }
    }
    $lines += @('---', '', $Body, '')
    return ($lines -join "`n")
}

function Get-ExtensionCatalogFixture {
    <#
    .SYNOPSIS
    Returns the deterministic marketplace catalog used by extension tests.
    .DESCRIPTION
    Five packages exercise legacy catalog structure and a non-empty agent
    handoff closure for extension tests that still consume the fixture.
    .OUTPUTS
    [System.Collections.Specialized.OrderedDictionary] Catalog object.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param()

    return [ordered]@{
        name     = 'fixture-marketplace'
        owner    = [ordered]@{ name = 'Fixture Owner' }
        metadata = [ordered]@{ version = '1.0.0' }
        plugins  = @(
            [ordered]@{
                name        = 'hve-core'
                description = 'Core fixture package'
                version     = '9.9.9'
                agents      = @('agents/core/alpha.md')
                commands    = @('commands/core/build.md')
                rules       = @('rules/core/style.instructions.md')
                skills      = @('skills/core/toolkit')
                hooks       = @('hooks/core/session.json')
                'x-hve'     = [ordered]@{
                    displayName       = 'Fixture Core'
                    maturity          = 'stable'
                    documentation     = 'docs/plugins/hve-core.md'
                }
            }
            [ordered]@{
                name        = 'hve-core-all'
                description = 'Full fixture bundle'
                version     = '9.9.9'
                agents      = @('agents/core/alpha.md', 'agents/core/beta.md')
                skills      = @('skills/core/toolkit', 'skills/labs/probe')
                'x-hve'     = [ordered]@{
                    displayName       = 'Fixture Core - All'
                    maturity          = 'stable'
                    documentation     = 'docs/plugins/hve-core-all.md'
                }
            }
            [ordered]@{
                name        = 'sample'
                description = 'Sample fixture package'
                version     = '9.9.9'
                agents      = @('agents/core/beta.md')
                'x-hve'     = [ordered]@{
                    displayName   = 'Fixture Sample'
                    maturity      = 'stable'
                    documentation = 'docs/plugins/sample.md'
                }
            }
            [ordered]@{
                name        = 'labs'
                description = 'Labs fixture package'
                version     = '9.9.9'
                agents      = @('agents/labs/gamma.md')
                skills      = @('skills/labs/probe')
                'x-hve'     = [ordered]@{
                    displayName   = 'Fixture Labs'
                    maturity      = 'experimental'
                    documentation = 'docs/plugins/labs.md'
                }
            }
            [ordered]@{
                name        = 'retired'
                description = 'Retired fixture package'
                version     = '9.9.9'
                agents      = @('agents/core/alpha.md')
                'x-hve'     = [ordered]@{
                    displayName = 'Fixture Retired'
                    maturity    = 'removed'
                }
            }
        )
    }
}

function New-ExtensionFixtureRepo {
    <#
    .SYNOPSIS
    Creates a marketplace-backed repository fixture for preparation tests.
    .PARAMETER Path
    Root directory to populate.
    .OUTPUTS
    [hashtable] Fixture paths.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $repoRoot = (New-Item -Path $Path -ItemType Directory -Force).FullName
    $extensionDirectory = (New-Item -Path (Join-Path $repoRoot 'extension') -ItemType Directory -Force).FullName

    $catalogPath = Join-Path $repoRoot '.github/plugin/marketplace.json'
    Set-FixtureFile -Path $catalogPath -Value ((Get-ExtensionCatalogFixture | ConvertTo-Json -Depth 12) + "`n")

    Set-FixtureFile -Path (Join-Path $repoRoot '.github/agents/core/alpha.agent.md') `
        -Value (New-FixtureMarkdown -Name 'Alpha Agent' -Description 'Alpha fixture agent')
    Set-FixtureFile -Path (Join-Path $repoRoot '.github/agents/core/beta.agent.md') `
        -Value (New-FixtureMarkdown -Name 'Beta Agent' -Description 'Beta fixture agent' -Handoff @('Alpha Agent'))
    Set-FixtureFile -Path (Join-Path $repoRoot '.github/agents/labs/gamma.agent.md') `
        -Value (New-FixtureMarkdown -Name 'Gamma Agent' -Description 'Gamma fixture agent')
    Set-FixtureFile -Path (Join-Path $repoRoot '.github/prompts/core/build.prompt.md') `
        -Value (New-FixtureMarkdown -Description 'Build fixture prompt')
    Set-FixtureFile -Path (Join-Path $repoRoot '.github/instructions/core/style.instructions.md') `
        -Value (New-FixtureMarkdown -Description 'Style fixture instruction')
    Set-FixtureFile -Path (Join-Path $repoRoot '.github/skills/core/toolkit/SKILL.md') `
        -Value (New-FixtureMarkdown -Name 'toolkit' -Description 'Toolkit fixture skill')
    Set-FixtureFile -Path (Join-Path $repoRoot '.github/skills/labs/probe/SKILL.md') `
        -Value (New-FixtureMarkdown -Name 'probe' -Description 'Probe fixture skill')
    Set-FixtureFile -Path (Join-Path $repoRoot '.github/hooks/core/session.json') `
        -Value "{`n  `"description`": `"Session fixture hook`"`n}`n"

    foreach ($document in @(
            @{ Name = 'hve-core'; Title = 'Fixture Core' }
            @{ Name = 'hve-core-all'; Title = 'Fixture Core - All' }
            @{ Name = 'sample'; Title = 'Fixture Sample' }
            @{ Name = 'labs'; Title = 'Fixture Labs' }
        )) {
        $documentLines = @(
            '---'
            "title: $($document.Title)"
            "description: $($document.Title) durable document"
            '---'
            ''
            "$($document.Title) intro paragraph."
            ''
            '## Included Artifacts'
            ''
            '| Name | Description |'
            '|------|-------------|'
            '| **stale** | Durable table that must never reach the extension README |'
            ''
        )
        Set-FixtureFile -Path (Join-Path $repoRoot "docs/plugins/$($document.Name).md") -Value ($documentLines -join "`n")
    }

    $template = [ordered]@{
        name        = 'hve-core'
        displayName = 'Fixture Core'
        version     = '9.9.9'
        description = 'Template description'
        publisher   = 'fixture-publisher'
        engines     = [ordered]@{ vscode = '^1.106.1' }
        contributes = [ordered]@{}
    }
    Set-FixtureFile -Path (Join-Path $repoRoot 'extension/templates/package.template.json') `
        -Value (($template | ConvertTo-Json -Depth 8) + "`n")

    $readmeTemplate = @(
        '# {{DISPLAY_NAME}}'
        ''
        '> {{DESCRIPTION}}'
        ''
        '{{BODY}}'
        ''
        '## Included Artifacts'
        ''
        '{{ARTIFACTS}}'
        ''
    ) -join "`n"
    Set-FixtureFile -Path (Join-Path $repoRoot 'extension/templates/README.template.md') -Value $readmeTemplate

    Set-FixtureFile -Path (Join-Path $extensionDirectory 'package.json') -Value "{`n  `"name`": `"placeholder`"`n}`n"
    Set-FixtureFile -Path (Join-Path $extensionDirectory 'README.md') -Value "# Placeholder`n"
    Set-FixtureFile -Path (Join-Path $extensionDirectory 'package.obsolete.json') -Value "{}`n"
    Set-FixtureFile -Path (Join-Path $extensionDirectory 'README.obsolete.md') -Value "# Obsolete`n"

    return @{
        RepoRoot           = $repoRoot
        ExtensionDirectory = $extensionDirectory
        CatalogPath        = $catalogPath
        DocsDirectory      = (Join-Path $repoRoot 'docs/plugins')
        TemplatePath       = (Join-Path $repoRoot 'extension/templates/package.template.json')
    }
}

function New-PackagingFixtureRepo {
    <#
    .SYNOPSIS
    Creates a git-tracked repository fixture for packaging tests.
    .DESCRIPTION
    Populates a prepared extension manifest, contribution sources, excluded
    sentinel paths, shared staging resources, and a git index.
    .PARAMETER Path
    Root directory to populate.
    .PARAMETER VsceVersion
    Pinned vsce version recorded in the root manifest.
    .OUTPUTS
    [hashtable] Fixture paths and expected staging inventory.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [string]$VsceVersion = '3.9.2'
    )

    $repoRoot = (New-Item -Path $Path -ItemType Directory -Force).FullName
    $extensionDirectory = (New-Item -Path (Join-Path $repoRoot 'extension') -ItemType Directory -Force).FullName

    $manifest = [ordered]@{
        name        = 'hve-sample'
        displayName = 'Fixture Sample'
        version     = '1.2.3'
        publisher   = 'fixture-publisher'
        engines     = [ordered]@{ vscode = '^1.106.1' }
        contributes = [ordered]@{
            chatAgents       = @(@{ name = 'alpha'; path = './.github/agents/core/alpha.agent.md' })
            chatPromptFiles  = @(@{ name = 'build'; path = './.github/prompts/core/build.prompt.md' })
            chatInstructions = @(@{ name = 'style-instructions'; path = './.github/instructions/core/style.instructions.md' })
            chatSkills       = @(@{ name = 'toolkit'; path = './.github/skills/core/toolkit/SKILL.md' })
        }
    }
    Set-FixtureFile -Path (Join-Path $extensionDirectory 'package.json') -Value (($manifest | ConvertTo-Json -Depth 8) + "`n")
    Set-FixtureFile -Path (Join-Path $extensionDirectory 'README.md') -Value "# Canonical README`n"
    Set-FixtureFile -Path (Join-Path $extensionDirectory 'README.sample.md') -Value "# Sample package README`n"

    Set-FixtureFile -Path (Join-Path $repoRoot 'package.json') `
        -Value (([ordered]@{ name = 'fixture-root'; devDependencies = [ordered]@{ '@vscode/vsce' = $VsceVersion } } | ConvertTo-Json -Depth 6) + "`n")

    $trackedSources = @(
        '.github/agents/core/alpha.agent.md'
        '.github/prompts/core/build.prompt.md'
        '.github/instructions/core/style.instructions.md'
        '.github/skills/core/toolkit/SKILL.md'
        '.github/skills/core/toolkit/scripts/run.py'
        'scripts/lib/Modules/CIHelpers.psm1'
        'docs/templates/example-template.md'
    )
    foreach ($source in $trackedSources) {
        Set-FixtureFile -Path (Join-Path $repoRoot $source) -Value "fixture content for $source`n"
    }

    $excludedSentinels = @(
        '.github/skills/core/toolkit/tests/test_toolkit.py'
        '.github/skills/core/toolkit/scripts/tests/test_deep.py'
        '.github/skills/core/toolkit/.venv/lib/site.py'
        '.github/skills/core/toolkit/node_modules/left-pad/index.js'
        '.github/skills/core/toolkit/__pycache__/toolkit.pyc'
        '.github/skills/core/toolkit/.ruff_cache/cache.json'
        '.github/skills/core/toolkit/.pytest_cache/cache.json'
    )
    foreach ($sentinel in $excludedSentinels) {
        Set-FixtureFile -Path (Join-Path $repoRoot $sentinel) -Value "excluded sentinel $sentinel`n"
    }

    git -C $repoRoot init --quiet --initial-branch=main | Out-Null
    git -C $repoRoot add --all --force | Out-Null

    $untrackedSource = '.github/skills/core/toolkit/untracked.md'
    Set-FixtureFile -Path (Join-Path $repoRoot $untrackedSource) -Value "untracked skill file`n"

    return @{
        RepoRoot           = $repoRoot
        ExtensionDirectory = $extensionDirectory
        TrackedSources     = $trackedSources
        ExcludedSentinels  = $excludedSentinels
        UntrackedSource    = $untrackedSource
        VsceVersion        = $VsceVersion
    }
}

function New-FakeVsceExecutable {
    <#
    .SYNOPSIS
    Creates a fake vsce executable that reports a version and emits a VSIX.
    .PARAMETER Path
    Executable path to create.
    .PARAMETER Version
    Version reported for --version.
    .PARAMETER VsixName
    VSIX filename created when packaging.
    .PARAMETER ExitCode
    Exit code returned when packaging.
    .OUTPUTS
    [string] Full executable path.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Version,

        [Parameter(Mandatory = $false)]
        [string]$VsixName = 'hve-sample-1.2.3.vsix',

        [Parameter(Mandatory = $false)]
        [int]$ExitCode = 0
    )

    $script = @(
        '#!/bin/sh'
        'if [ "$1" = "--version" ]; then'
        "  echo $Version"
        '  exit 0'
        'fi'
        'printf "%s\n" "$@" > vsce-args.txt'
        'cp package.json vsce-observed-package.json'
        'cp README.md vsce-observed-readme.md'
        "printf 'fixture vsix' > `"$VsixName`""
        "exit $ExitCode"
        ''
    ) -join "`n"
    Set-FixtureFile -Path $Path -Value $script
    chmod +x $Path
    return (Resolve-Path -LiteralPath $Path).Path
}

Export-ModuleMember -Function @(
    'Get-ExtensionCatalogFixture',
    'New-ExtensionFixtureRepo',
    'New-FakeVsceExecutable',
    'New-FixtureMarkdown',
    'New-PackagingFixtureRepo',
    'Set-FixtureFile'
)
