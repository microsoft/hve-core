#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    . $PSScriptRoot/../../extension/Prepare-Extension.ps1
}

#region Package Generation Function Tests

Describe 'Get-CollectionDisplayName' {
    It 'Returns displayName when present' {
        $manifest = @{ displayName = 'My Display Name'; name = 'fallback' }
        $result = Get-CollectionDisplayName -CollectionManifest $manifest -DefaultValue 'default'
        $result | Should -Be 'My Display Name'
    }

    It 'Derives display name from name when displayName absent' {
        $manifest = @{ name = 'Git Workflow' }
        $result = Get-CollectionDisplayName -CollectionManifest $manifest -DefaultValue 'default'
        $result | Should -Be 'HVE Core - Git Workflow'
    }

    It 'Returns default when both displayName and name absent' {
        $manifest = @{ id = 'test' }
        $result = Get-CollectionDisplayName -CollectionManifest $manifest -DefaultValue 'Fallback'
        $result | Should -Be 'Fallback'
    }

    It 'Ignores whitespace-only displayName' {
        $manifest = @{ displayName = '   '; name = 'valid' }
        $result = Get-CollectionDisplayName -CollectionManifest $manifest -DefaultValue 'default'
        $result | Should -Be 'HVE Core - valid'
    }
}

Describe 'Copy-TemplateWithOverrides' {
    It 'Overrides existing properties' {
        $template = [PSCustomObject]@{ name = 'original'; version = '1.0.0' }
        $result = Copy-TemplateWithOverrides -Template $template -Overrides @{ name = 'overridden' }
        $result.name | Should -Be 'overridden'
        $result.version | Should -Be '1.0.0'
    }

    It 'Preserves template property order' {
        $template = [PSCustomObject]@{ a = '1'; b = '2'; c = '3' }
        $result = Copy-TemplateWithOverrides -Template $template -Overrides @{ b = 'new' }
        $names = @($result.PSObject.Properties.Name)
        $names[0] | Should -Be 'a'
        $names[1] | Should -Be 'b'
        $names[2] | Should -Be 'c'
    }

    It 'Appends new override keys not in template' {
        $template = [PSCustomObject]@{ name = 'ext' }
        $result = Copy-TemplateWithOverrides -Template $template -Overrides @{ name = 'ext'; extra = 'value' }
        $result.extra | Should -Be 'value'
    }

    It 'Returns PSCustomObject' {
        $template = [PSCustomObject]@{ name = 'ext' }
        $result = Copy-TemplateWithOverrides -Template $template -Overrides @{}
        $result | Should -BeOfType [PSCustomObject]
    }
}

Describe 'Set-JsonFile' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Creates file with JSON content' {
        $path = Join-Path $script:tempDir 'test.json'
        Set-JsonFile -Path $path -Content @{ name = 'test'; version = '1.0.0' }
        Test-Path $path | Should -BeTrue
        $content = Get-Content -Path $path -Raw | ConvertFrom-Json
        $content.name | Should -Be 'test'
    }

    It 'Creates parent directories when missing' {
        $path = Join-Path $script:tempDir 'nested/deep/test.json'
        Set-JsonFile -Path $path -Content @{ key = 'value' }
        Test-Path $path | Should -BeTrue
    }
}

Describe 'Remove-StaleGeneratedFiles' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        $script:extDir = Join-Path $script:tempDir 'extension'
        New-Item -ItemType Directory -Path $script:extDir -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Removes stale package.*.json files not in expected set' {
        $keepFile = Join-Path $script:extDir 'package.rpi.json'
        $staleFile = Join-Path $script:extDir 'package.obsolete.json'
        '{}' | Set-Content -Path $keepFile
        '{}' | Set-Content -Path $staleFile

        Remove-StaleGeneratedFiles -RepoRoot $script:tempDir -ExpectedFiles @($keepFile)

        Test-Path $keepFile | Should -BeTrue
        Test-Path $staleFile | Should -BeFalse
    }

    It 'Does not remove non-collection files' {
        $regularFile = Join-Path $script:extDir 'README.md'
        '# Test' | Set-Content -Path $regularFile

        Remove-StaleGeneratedFiles -RepoRoot $script:tempDir -ExpectedFiles @()

        Test-Path $regularFile | Should -BeTrue
    }
}

Describe 'Invoke-ExtensionCollectionsGeneration' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())

        # Set up minimal repo structure
        $collectionsDir = Join-Path $script:tempDir 'collections'
        $templatesDir = Join-Path $script:tempDir 'extension/templates'
        New-Item -ItemType Directory -Path $collectionsDir -Force | Out-Null
        New-Item -ItemType Directory -Path $templatesDir -Force | Out-Null

        # Package template
        @{
            name        = 'hve-core'
            displayName = 'HVE Core'
            version     = '2.0.0'
            description = 'Default description'
            publisher   = 'test-pub'
            engines     = @{ vscode = '^1.80.0' }
            contributes = @{}
        } | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $templatesDir 'package.template.json')

        # hve-core collection (flagship)
        @"
id: hve-core
name: HVE Core
displayName: HVE Core
description: All artifacts
"@ | Set-Content -Path (Join-Path $collectionsDir 'hve-core.collection.yml')

        # ado collection (includes per-channel description override for PreRelease)
        @"
id: ado
name: ADO Workflow
displayName: HVE Core - ADO Workflow
description: ADO workflow agents
descriptions:
  - channel: prerelease
    text: 'Experimental: ADO workflow agents (preview)'
"@ | Set-Content -Path (Join-Path $collectionsDir 'ado.collection.yml')

        # hve-core-all collection (no description to test fallback)
        @"
id: hve-core-all
name: All
displayName: HVE Core - All
"@ | Set-Content -Path (Join-Path $collectionsDir 'hve-core-all.collection.yml')

        # Central manifest: production projects collections from this file.
        @"
schemaVersion: `"1.0`"
collections:
  hve-core:
    name: HVE Core
    intro: HVE Core flagship collection.
    descriptions:
      - channel: stable
        text: All artifacts
  ado:
    name: ADO Workflow
    intro: ADO workflow agents.
    descriptions:
      - channel: stable
        text: ADO workflow agents
      - channel: prerelease
        text: 'Experimental: ADO workflow agents (preview)'
  hve-core-all:
    name: All
    intro: All HVE artifacts.
"@ | Set-Content -Path (Join-Path $collectionsDir 'core-manifest.yml')

        # README template (required for README generation); reuse the real template.
        $readmeTemplateSource = Join-Path (Get-Item "$PSScriptRoot/../../..").FullName 'extension/templates/README.template.md'
        Copy-Item -Path $readmeTemplateSource -Destination (Join-Path $templatesDir 'README.template.md') -Force
    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Generates package.json for hve-core' {
        $null = Invoke-ExtensionCollectionsGeneration -RepoRoot $script:tempDir
        $pkgPath = Join-Path $script:tempDir 'extension/package.json'
        Test-Path $pkgPath | Should -BeTrue
        $pkg = Get-Content $pkgPath -Raw | ConvertFrom-Json
        $pkg.name | Should -Be 'hve-core'
        $pkg.version | Should -Be '2.0.0'
    }

    It 'Generates collection package file for non-default collection' {
        $null = Invoke-ExtensionCollectionsGeneration -RepoRoot $script:tempDir
        $pkgPath = Join-Path $script:tempDir 'extension/package.ado.json'
        Test-Path $pkgPath | Should -BeTrue
        $pkg = Get-Content $pkgPath -Raw | ConvertFrom-Json
        $pkg.name | Should -Be 'hve-ado'
        $pkg.displayName | Should -Be 'HVE Core - ADO Workflow'
    }

    It 'Returns array of generated file paths' {
        $result = Invoke-ExtensionCollectionsGeneration -RepoRoot $script:tempDir
        # 3 package.*.json files plus 3 README.*.md files.
        $result.Count | Should -Be 6
    }

    It 'Propagates version from template to all generated files' {
        $result = Invoke-ExtensionCollectionsGeneration -RepoRoot $script:tempDir
        $packageFiles = $result | Where-Object { $_ -like '*package*.json' }
        foreach ($file in $packageFiles) {
            $pkg = Get-Content $file -Raw | ConvertFrom-Json
            $pkg.version | Should -Be '2.0.0'
        }
    }

    It 'Removes stale collection files not matching current collections when -Prune is specified' {
        $staleFile = Join-Path $script:tempDir 'extension/package.obsolete.json'
        '{}' | Set-Content -Path $staleFile

        Invoke-ExtensionCollectionsGeneration -RepoRoot $script:tempDir -Prune

        Test-Path $staleFile | Should -BeFalse
    }

    It 'Generates package for hve-core-all with description fallback' {
        $null = Invoke-ExtensionCollectionsGeneration -RepoRoot $script:tempDir
        $pkgPath = Join-Path $script:tempDir 'extension/package.hve-core-all.json'
        Test-Path $pkgPath | Should -BeTrue
        $pkg = Get-Content $pkgPath -Raw | ConvertFrom-Json
        $pkg.name | Should -Be 'hve-core-all'
        $pkg.displayName | Should -Be 'HVE Core - All'
        # Falls back to template description when collection lacks description
        $pkg.description | Should -Be 'Default description'
    }

    It 'Throws when package template is missing' {
        $badRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path (Join-Path $badRoot 'collections') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $badRoot 'extension/templates') -Force | Out-Null
        @"
id: test
"@ | Set-Content -Path (Join-Path $badRoot 'collections/test.collection.yml')

        { Invoke-ExtensionCollectionsGeneration -RepoRoot $badRoot } | Should -Throw '*Package template not found*'

        Remove-Item -Path $badRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Throws when no collection files exist' {
        $emptyRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path (Join-Path $emptyRoot 'collections') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $emptyRoot 'extension/templates') -Force | Out-Null
        @{ name = 'test'; version = '1.0.0' } | ConvertTo-Json | Set-Content -Path (Join-Path $emptyRoot 'extension/templates/package.template.json')

        { Invoke-ExtensionCollectionsGeneration -RepoRoot $emptyRoot } | Should -Throw '*does not exist*'

        Remove-Item -Path $emptyRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Prune Mode' {
        BeforeEach {
            $extDir = Join-Path $script:tempDir 'extension'
            New-Item -ItemType Directory -Path $extDir -Force | Out-Null
            $script:orphanPackagePath = Join-Path $extDir 'package.orphan.json'
            $script:orphanReadmePath = Join-Path $extDir 'README.orphan.md'
            '{}' | Set-Content -Path $script:orphanPackagePath
            '# orphan readme' | Set-Content -Path $script:orphanReadmePath
        }

        AfterEach {
            Remove-Item -Path $script:orphanPackagePath -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $script:orphanReadmePath -Force -ErrorAction SilentlyContinue
        }

        It 'Removes orphan package.<id>.json and README.<id>.md when -Prune is specified' {
            $null = Invoke-ExtensionCollectionsGeneration -RepoRoot $script:tempDir -Channel 'PreRelease' -Prune
            Test-Path $script:orphanPackagePath | Should -BeFalse
            Test-Path $script:orphanReadmePath | Should -BeFalse
            Test-Path (Join-Path $script:tempDir 'extension/package.json') | Should -BeTrue
            Test-Path (Join-Path $script:tempDir 'extension/package.ado.json') | Should -BeTrue
        }

        It 'Leaves orphan extension files intact when -Prune is omitted' {
            $null = Invoke-ExtensionCollectionsGeneration -RepoRoot $script:tempDir -Channel 'PreRelease'
            Test-Path $script:orphanPackagePath | Should -BeTrue
            Test-Path $script:orphanReadmePath | Should -BeTrue
        }
    }

    Context 'Collection Targeting' {
        It 'pins extension/package.json to the targeted collection on PreRelease' {
            $collectionPath = Join-Path $script:tempDir 'collections/ado.collection.yml'
            $null = Invoke-ExtensionCollectionsGeneration -RepoRoot $script:tempDir -Channel 'PreRelease' -Collection $collectionPath

            $pinnedPath = Join-Path $script:tempDir 'extension/package.json'
            Test-Path $pinnedPath | Should -BeTrue
            $pinned = Get-Content -Path $pinnedPath -Raw | ConvertFrom-Json
            $pinned.name | Should -Be 'hve-ado'
            $pinned.description | Should -Be 'Experimental: ADO workflow agents (preview)'

            # The per-id file is still written so other matrix jobs would find it.
            $perIdPath = Join-Path $script:tempDir 'extension/package.ado.json'
            Test-Path $perIdPath | Should -BeTrue
            $perId = Get-Content -Path $perIdPath -Raw | ConvertFrom-Json
            $perId.description | Should -Be 'Experimental: ADO workflow agents (preview)'
        }

        It 'pins extension/package.json to the targeted collection on Stable' {
            $collectionPath = Join-Path $script:tempDir 'collections/ado.collection.yml'
            $null = Invoke-ExtensionCollectionsGeneration -RepoRoot $script:tempDir -Channel 'Stable' -Collection $collectionPath

            $pinnedPath = Join-Path $script:tempDir 'extension/package.json'
            $pinned = Get-Content -Path $pinnedPath -Raw | ConvertFrom-Json
            $pinned.name | Should -Be 'hve-ado'
            $pinned.description | Should -Be 'ADO workflow agents'
            $pinned.description | Should -Not -Match '^Experimental:'
        }

        It 'omitting -Collection regenerates all per-id files (backward compatibility)' {
            $null = Invoke-ExtensionCollectionsGeneration -RepoRoot $script:tempDir -Channel 'Stable'

            $flagshipPath = Join-Path $script:tempDir 'extension/package.json'
            $flagship = Get-Content -Path $flagshipPath -Raw | ConvertFrom-Json
            $flagship.name | Should -Be 'hve-core'

            Test-Path (Join-Path $script:tempDir 'extension/package.ado.json') | Should -BeTrue
            Test-Path (Join-Path $script:tempDir 'extension/package.hve-core-all.json') | Should -BeTrue
        }
    }
}

Describe 'Write-ManifestReviewArtifact' {
    BeforeAll {
        $script:repoRoot = (Get-Item "$PSScriptRoot/../../..").FullName
        $script:reviewTempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
    }

    AfterAll {
        Remove-Item -Path $script:reviewTempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Writes projected collection yaml and markdown into a per-collection subfolder' {
        $result = Write-ManifestReviewArtifact -RepoRoot $script:repoRoot -CollectionId 'ado' -OutputRoot $script:reviewTempDir

        $yamlPath = Join-Path $script:reviewTempDir 'ado/ado.collection.yml'
        $mdPath = Join-Path $script:reviewTempDir 'ado/ado.collection.md'

        Test-Path -LiteralPath $yamlPath | Should -BeTrue
        Test-Path -LiteralPath $mdPath | Should -BeTrue
        $result | Should -Contain $yamlPath
        $result | Should -Contain $mdPath
    }

    It 'Returns both written file paths' {
        $result = Write-ManifestReviewArtifact -RepoRoot $script:repoRoot -CollectionId 'ado' -OutputRoot $script:reviewTempDir
        @($result).Count | Should -Be 2
    }

    It 'Creates the per-collection output directory when missing' {
        $freshRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        try {
            Test-Path -LiteralPath $freshRoot | Should -BeFalse
            $null = Write-ManifestReviewArtifact -RepoRoot $script:repoRoot -CollectionId 'ado' -OutputRoot $freshRoot
            Test-Path -LiteralPath (Join-Path $freshRoot 'ado') | Should -BeTrue
        }
        finally {
            Remove-Item -Path $freshRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Emits yaml that parses to a manifest with the requested collection id' {
        $null = Write-ManifestReviewArtifact -RepoRoot $script:repoRoot -CollectionId 'ado' -OutputRoot $script:reviewTempDir
        $yamlPath = Join-Path $script:reviewTempDir 'ado/ado.collection.yml'
        $parsed = ConvertFrom-Yaml (Get-Content -LiteralPath $yamlPath -Raw)
        $parsed.id | Should -Be 'ado'
    }

    It 'Emits content matching the committed collection render' {
        $null = Write-ManifestReviewArtifact -RepoRoot $script:repoRoot -CollectionId 'ado' -OutputRoot $script:reviewTempDir

        $coreManifestPath = Join-Path $script:repoRoot 'collections/core-manifest.yml'
        $coreManifest = Read-CoreManifest -ManifestPath $coreManifestPath
        $expectedYaml = ConvertTo-Yaml -Data (ConvertTo-CollectionManifestFromCore -CoreManifest $coreManifest -CollectionId 'ado' -RepoRoot $script:repoRoot)
        $expectedMd = New-CollectionReadmeBodyFromCore -CoreManifest $coreManifest -CollectionId 'ado' -RepoRoot $script:repoRoot

        $actualYaml = Get-Content -LiteralPath (Join-Path $script:reviewTempDir 'ado/ado.collection.yml') -Raw
        $actualMd = Get-Content -LiteralPath (Join-Path $script:reviewTempDir 'ado/ado.collection.md') -Raw

        $actualYaml | Should -Be $expectedYaml
        $actualMd | Should -Be $expectedMd
    }

    It 'Throws for unknown collection ids' {
        { Write-ManifestReviewArtifact -RepoRoot $script:repoRoot -CollectionId 'does-not-exist' -OutputRoot $script:reviewTempDir } | Should -Throw
    }
}

Describe 'New-CollectionReadme' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null

        # Resolve the real template from the repo
        $script:repoRoot = (Get-Item "$PSScriptRoot/../../..").FullName
        $script:templatePath = Join-Path $script:repoRoot 'extension/templates/README.template.md'

        # Create mock artifact files with frontmatter descriptions
        $agentsDir = Join-Path $script:tempDir '.github/agents'
        $promptsDir = Join-Path $script:tempDir '.github/prompts'
        $instrDir = Join-Path $script:tempDir '.github/instructions'
        $skillsDir = Join-Path $script:tempDir '.github/skills/my-skill'
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
        New-Item -ItemType Directory -Path $promptsDir -Force | Out-Null
        New-Item -ItemType Directory -Path $instrDir -Force | Out-Null
        New-Item -ItemType Directory -Path $skillsDir -Force | Out-Null

        @"
---
description: "Alpha agent description"
---
# Alpha
"@ | Set-Content -Path (Join-Path $agentsDir 'alpha.agent.md')

        @"
---
description: "Zebra agent description"
---
# Zebra
"@ | Set-Content -Path (Join-Path $agentsDir 'zebra.agent.md')

        @"
---
description: "My prompt description"
---
# Prompt
"@ | Set-Content -Path (Join-Path $promptsDir 'my-prompt.prompt.md')

        @"
---
description: "My instruction description"
applyTo: "**/*.ps1"
---
# Instruction
"@ | Set-Content -Path (Join-Path $instrDir 'my-instr.instructions.md')

        @"
---
name: my-skill
description: "My skill description"
---
# Skill
"@ | Set-Content -Path (Join-Path $skillsDir 'SKILL.md')
    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Generates README with title and description from collection manifest' {
        $collection = @{
            id          = 'test-coll'
            name        = 'Test Collection'
            description = 'A test collection for unit testing'
            items       = @()
        }
        $mdPath = Join-Path $script:tempDir 'test.collection.md'
        'Body content goes here.' | Set-Content -Path $mdPath
        $outPath = Join-Path $script:tempDir 'README.test-coll.md'

        New-CollectionReadme -Collection $collection -CollectionMdPath $mdPath -TemplatePath $script:templatePath -RepoRoot $script:tempDir -OutputPath $outPath

        $content = Get-Content -Path $outPath -Raw
        $content | Should -Match '# HVE Core - Test Collection'
        $content | Should -Match '> A test collection for unit testing'
        $content | Should -Match 'Body content goes here'
    }

    It 'Uses HVE Core as title for hve-core collection' {
        $collection = @{
            id          = 'hve-core'
            name        = 'HVE Core'
            description = 'Full bundle'
            items       = @()
        }
        $mdPath = Join-Path $script:tempDir 'core.collection.md'
        'All artifacts.' | Set-Content -Path $mdPath
        $outPath = Join-Path $script:tempDir 'README.md'

        New-CollectionReadme -Collection $collection -CollectionMdPath $mdPath -TemplatePath $script:templatePath -RepoRoot $script:tempDir -OutputPath $outPath

        $content = Get-Content -Path $outPath -Raw
        $content | Should -Match '# HVE Core'
        $content | Should -Not -Match '# HVE Core All'
    }

    It 'Generates sorted artifact tables with descriptions grouped by kind' {
        $collection = @{
            id    = 'multi'
            name  = 'Multi'
            description = 'Multi-artifact test'
            items = @(
                @{ kind = 'agent'; path = '.github/agents/zebra.agent.md' },
                @{ kind = 'agent'; path = '.github/agents/alpha.agent.md' },
                @{ kind = 'prompt'; path = '.github/prompts/my-prompt.prompt.md' },
                @{ kind = 'instruction'; path = '.github/instructions/my-instr.instructions.md' },
                @{ kind = 'skill'; path = '.github/skills/my-skill/' }
            )
        }
        $mdPath = Join-Path $script:tempDir 'multi.collection.md'
        'Test body.' | Set-Content -Path $mdPath
        $outPath = Join-Path $script:tempDir 'README.multi.md'

        New-CollectionReadme -Collection $collection -CollectionMdPath $mdPath -TemplatePath $script:templatePath -RepoRoot $script:tempDir -OutputPath $outPath

        $content = Get-Content -Path $outPath -Raw
        $content | Should -Match '### Chat Agents'
        $content | Should -Match '\| Name \| Description \|'
        $content | Should -Match '\*\*alpha\*\*.*Alpha agent description'
        $content | Should -Match '\*\*zebra\*\*.*Zebra agent description'
        $content | Should -Match '### Prompts'
        $content | Should -Match '\*\*my-prompt\*\*.*My prompt description'
        $content | Should -Match '### Instructions'
        $content | Should -Match '\*\*my-instr\*\*.*My instruction description'
        $content | Should -Match '### Skills'
        $content | Should -Match '\*\*my-skill\*\*.*My skill description'
    }

    It 'Includes Full Edition link for non-default collections' {
        $collection = @{
            id          = 'test-edition'
            name        = 'Test Edition'
            description = 'Test edition test'
            items       = @()
        }
        $mdPath = Join-Path $script:tempDir 'test-edition.collection.md'
        'Test edition body.' | Set-Content -Path $mdPath
        $outPath = Join-Path $script:tempDir 'README.test-edition.md'

        New-CollectionReadme -Collection $collection -CollectionMdPath $mdPath -TemplatePath $script:templatePath -RepoRoot $script:tempDir -OutputPath $outPath

        $content = Get-Content -Path $outPath -Raw
        $content | Should -Match '## Full Edition'
        $content | Should -Match 'HVE Core.*extension'
    }

    It 'Excludes Full Edition link for hve-core' {
        $collection = @{
            id          = 'hve-core'
            name        = 'HVE Core'
            description = 'Flagship bundle'
            items       = @()
        }
        $mdPath = Join-Path $script:tempDir 'core2.collection.md'
        'Core body.' | Set-Content -Path $mdPath
        $outPath = Join-Path $script:tempDir 'README.core2.md'

        New-CollectionReadme -Collection $collection -CollectionMdPath $mdPath -TemplatePath $script:templatePath -RepoRoot $script:tempDir -OutputPath $outPath

        $content = Get-Content -Path $outPath -Raw
        $content | Should -Not -Match '## Full Edition'
    }

    It 'Excludes Full Edition link for hve-core-all' {
        $collection = @{
            id          = 'hve-core-all'
            name        = 'All'
            description = 'Full bundle'
            items       = @()
        }
        $mdPath = Join-Path $script:tempDir 'all2.collection.md'
        'All body.' | Set-Content -Path $mdPath
        $outPath = Join-Path $script:tempDir 'README.all2.md'

        New-CollectionReadme -Collection $collection -CollectionMdPath $mdPath -TemplatePath $script:templatePath -RepoRoot $script:tempDir -OutputPath $outPath

        $content = Get-Content -Path $outPath -Raw
        $content | Should -Not -Match '## Full Edition'
    }

    It 'Includes common footer sections' {
        $collection = @{
            id          = 'footer-test'
            name        = 'Footer'
            description = 'Footer test'
            items       = @()
        }
        $mdPath = Join-Path $script:tempDir 'footer.collection.md'
        'Footer body.' | Set-Content -Path $mdPath
        $outPath = Join-Path $script:tempDir 'README.footer.md'

        New-CollectionReadme -Collection $collection -CollectionMdPath $mdPath -TemplatePath $script:templatePath -RepoRoot $script:tempDir -OutputPath $outPath

        $content = Get-Content -Path $outPath -Raw
        $content | Should -Match '## Getting Started'
        $content | Should -Match '## Pre-release Channel'
        $content | Should -Match '## Requirements'
        $content | Should -Match '## License'
        $content | Should -Match '## Support'
        $content | Should -Match 'Microsoft ISE HVE Essentials'
    }

    It 'Handles collection without description key' {
        $collection = @{
            id    = 'no-desc'
            name  = 'No Description'
            items = @()
        }
        $mdPath = Join-Path $script:tempDir 'no-desc.collection.md'
        'No description body.' | Set-Content -Path $mdPath
        $outPath = Join-Path $script:tempDir 'README.no-desc.md'

        New-CollectionReadme -Collection $collection -CollectionMdPath $mdPath -TemplatePath $script:templatePath -RepoRoot $script:tempDir -OutputPath $outPath

        $content = Get-Content -Path $outPath -Raw
        $content | Should -Match '# HVE Core - No Description'
        $content | Should -Match 'No description body'
    }

    Context 'Maturity filtering' {
        It 'Excludes experimental items when AllowedMaturities contains only stable' {
            $collection = @{
                id    = 'maturity-test'
                name  = 'Maturity Test'
                description = 'Maturity filtering test'
                items = @(
                    @{ kind = 'agent'; path = '.github/agents/alpha.agent.md'; maturity = 'stable' },
                    @{ kind = 'agent'; path = '.github/agents/zebra.agent.md'; maturity = 'experimental' }
                )
            }
            $mdPath = Join-Path $script:tempDir 'maturity-filter.collection.md'
            'Maturity body.' | Set-Content -Path $mdPath
            $outPath = Join-Path $script:tempDir 'README.maturity-filter.md'

            New-CollectionReadme -Collection $collection -CollectionMdPath $mdPath -TemplatePath $script:templatePath -RepoRoot $script:tempDir -OutputPath $outPath -AllowedMaturities @('stable')

            $content = Get-Content -Path $outPath -Raw
            $content | Should -Match 'alpha'
            $content | Should -Not -Match 'zebra'
        }

        It 'Includes experimental items when AllowedMaturities allows them' {
            $collection = @{
                id    = 'maturity-test2'
                name  = 'Maturity Test 2'
                description = 'Maturity filtering test'
                items = @(
                    @{ kind = 'agent'; path = '.github/agents/alpha.agent.md'; maturity = 'stable' },
                    @{ kind = 'agent'; path = '.github/agents/zebra.agent.md'; maturity = 'experimental' }
                )
            }
            $mdPath = Join-Path $script:tempDir 'maturity-all.collection.md'
            'All maturity body.' | Set-Content -Path $mdPath
            $outPath = Join-Path $script:tempDir 'README.maturity-all.md'

            New-CollectionReadme -Collection $collection -CollectionMdPath $mdPath -TemplatePath $script:templatePath -RepoRoot $script:tempDir -OutputPath $outPath -AllowedMaturities @('stable', 'preview', 'experimental')

            $content = Get-Content -Path $outPath -Raw
            $content | Should -Match 'alpha'
            $content | Should -Match 'zebra'
        }

        It 'Excludes deprecated items regardless of channel' {
            $collection = @{
                id    = 'deprecated-test'
                name  = 'Deprecated Test'
                description = 'Deprecated filtering test'
                items = @(
                    @{ kind = 'agent'; path = '.github/agents/alpha.agent.md'; maturity = 'stable' },
                    @{ kind = 'agent'; path = '.github/agents/zebra.agent.md'; maturity = 'deprecated' }
                )
            }
            $mdPath = Join-Path $script:tempDir 'deprecated.collection.md'
            'Deprecated body.' | Set-Content -Path $mdPath
            $outPath = Join-Path $script:tempDir 'README.deprecated.md'

            New-CollectionReadme -Collection $collection -CollectionMdPath $mdPath -TemplatePath $script:templatePath -RepoRoot $script:tempDir -OutputPath $outPath -AllowedMaturities @('stable', 'preview', 'experimental')

            $content = Get-Content -Path $outPath -Raw
            $content | Should -Match 'alpha'
            $content | Should -Not -Match 'zebra'
        }
    }

    Context 'Template marker handling' {
        It 'Preserves intro text and replaces marker section in README' {
            $collection = @{
                id          = 'marker-intro'
                name        = 'Marker Intro'
                description = 'Marker intro test'
                items       = @(
                    @{ kind = 'agent'; path = '.github/agents/alpha.agent.md' }
                )
            }
            $mdPath = Join-Path $script:tempDir 'marker-intro.collection.md'
            @"
Hand-authored intro paragraph.

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->

Old stale artifact list.

<!-- END AUTO-GENERATED ARTIFACTS -->
"@ | Set-Content -Path $mdPath -Encoding utf8NoBOM
            $outPath = Join-Path $script:tempDir 'README.marker-intro.md'

            New-CollectionReadme -Collection $collection -CollectionMdPath $mdPath -TemplatePath $script:templatePath -RepoRoot $script:tempDir -OutputPath $outPath

            $content = Get-Content -Path $outPath -Raw
            $content | Should -Match 'Hand-authored intro paragraph'
            $content | Should -Not -Match 'Old stale artifact list'
        }

        It 'Writes back updated artifact section into collection.md' {
            $collection = @{
                id          = 'marker-wb'
                name        = 'Marker Writeback'
                description = 'Marker writeback test'
                items       = @(
                    @{ kind = 'agent'; path = '.github/agents/alpha.agent.md' }
                )
            }
            $mdPath = Join-Path $script:tempDir 'marker-wb.collection.md'
            @"
Writeback intro.

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->

Old content to replace.

<!-- END AUTO-GENERATED ARTIFACTS -->
"@ | Set-Content -Path $mdPath -Encoding utf8NoBOM
            $outPath = Join-Path $script:tempDir 'README.marker-wb.md'

            New-CollectionReadme -Collection $collection -CollectionMdPath $mdPath -TemplatePath $script:templatePath -RepoRoot $script:tempDir -OutputPath $outPath

            $mdContent = Get-Content -Path $mdPath -Raw
            $mdContent | Should -Match '<!-- BEGIN AUTO-GENERATED ARTIFACTS -->'
            $mdContent | Should -Match '<!-- END AUTO-GENERATED ARTIFACTS -->'
            $mdContent | Should -Match 'alpha'
            $mdContent | Should -Not -Match 'Old content to replace'
        }

        It 'Works without markers for backward compatibility' {
            $collection = @{
                id          = 'no-markers'
                name        = 'No Markers'
                description = 'No markers test'
                items       = @(
                    @{ kind = 'agent'; path = '.github/agents/alpha.agent.md' }
                )
            }
            $mdPath = Join-Path $script:tempDir 'no-markers.collection.md'
            'Legacy body content without markers.' | Set-Content -Path $mdPath -Encoding utf8NoBOM
            $outPath = Join-Path $script:tempDir 'README.no-markers.md'

            New-CollectionReadme -Collection $collection -CollectionMdPath $mdPath -TemplatePath $script:templatePath -RepoRoot $script:tempDir -OutputPath $outPath

            $content = Get-Content -Path $outPath -Raw
            $content | Should -Match 'Legacy body content without markers'
        }

        It 'Preserves footer content after end marker' {
            $collection = @{
                id          = 'marker-footer'
                name        = 'Marker Footer'
                description = 'Marker footer test'
                items       = @(
                    @{ kind = 'agent'; path = '.github/agents/alpha.agent.md' }
                )
            }
            $mdPath = Join-Path $script:tempDir 'marker-footer.collection.md'
            @"
Footer intro.

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->

Old artifacts.

<!-- END AUTO-GENERATED ARTIFACTS -->

## Prerequisites

This requires setup first.
"@ | Set-Content -Path $mdPath -Encoding utf8NoBOM
            $outPath = Join-Path $script:tempDir 'README.marker-footer.md'

            New-CollectionReadme -Collection $collection -CollectionMdPath $mdPath -TemplatePath $script:templatePath -RepoRoot $script:tempDir -OutputPath $outPath

            $readmeContent = Get-Content -Path $outPath -Raw
            $readmeContent | Should -Match 'Footer intro'
            $readmeContent | Should -Match 'Prerequisites'

            $mdContent = Get-Content -Path $mdPath -Raw
            $mdContent | Should -Match '<!-- BEGIN AUTO-GENERATED ARTIFACTS -->'
            $mdContent | Should -Match '<!-- END AUTO-GENERATED ARTIFACTS -->'
            $mdContent | Should -Match '## Prerequisites'
            $mdContent | Should -Match 'This requires setup first'
        }
    }

    Context 'Effective-set maturity notice' {
        It 'Emits no notice on Stable channel when experimental items are filtered out' {
            $collection = @{
                id          = 'notice-stable-filtered'
                name        = 'Notice Stable Filtered'
                description = 'Effective-set notice test'
                maturity    = 'stable'
                items       = @(
                    @{ kind = 'agent'; path = '.github/agents/alpha.agent.md'; maturity = 'stable' },
                    @{ kind = 'agent'; path = '.github/agents/zebra.agent.md'; maturity = 'experimental' }
                )
            }
            $mdPath = Join-Path $script:tempDir 'notice-stable-filtered.collection.md'
            'Body.' | Set-Content -Path $mdPath
            $outPath = Join-Path $script:tempDir 'README.notice-stable-filtered.md'

            New-CollectionReadme -Collection $collection -CollectionMdPath $mdPath -TemplatePath $script:templatePath -RepoRoot $script:tempDir -OutputPath $outPath -AllowedMaturities @('stable') -Channel 'Stable'

            $content = Get-Content -Path $outPath -Raw
            $content | Should -Not -Match 'Pre-Release with'
            $content | Should -Not -Match 'Pre-Release build'
        }

        It 'Emits strong indemnification notice on PreRelease channel when bundle includes experimental items' {
            $collection = @{
                id          = 'notice-prerelease'
                name        = 'Notice PreRelease'
                description = 'Effective-set notice test'
                maturity    = 'stable'
                items       = @(
                    @{ kind = 'agent'; path = '.github/agents/alpha.agent.md'; maturity = 'stable' },
                    @{ kind = 'agent'; path = '.github/agents/zebra.agent.md'; maturity = 'experimental' }
                )
            }
            $mdPath = Join-Path $script:tempDir 'notice-prerelease.collection.md'
            'Body.' | Set-Content -Path $mdPath
            $outPath = Join-Path $script:tempDir 'README.notice-prerelease.md'

            New-CollectionReadme -Collection $collection -CollectionMdPath $mdPath -TemplatePath $script:templatePath -RepoRoot $script:tempDir -OutputPath $outPath -AllowedMaturities @('stable', 'preview', 'experimental') -Channel 'PreRelease'

            $content = Get-Content -Path $outPath -Raw
            $content | Should -Match 'Pre-Release with experimental content'
            $content | Should -Match 'experimental assets that are subject to change'
            $content | Should -Match 'as-is, without warranty of any kind'
            $content | Should -Match 'microsoft/hve-core/issues'
        }

        It 'Emits preview-tier notice on PreRelease channel when bundle includes preview but not experimental items' {
            $collection = @{
                id          = 'notice-prerelease-preview'
                name        = 'Notice PreRelease Preview'
                description = 'Effective-set notice test'
                maturity    = 'stable'
                items       = @(
                    @{ kind = 'agent'; path = '.github/agents/alpha.agent.md'; maturity = 'stable' },
                    @{ kind = 'agent'; path = '.github/agents/zebra.agent.md'; maturity = 'preview' }
                )
            }
            $mdPath = Join-Path $script:tempDir 'notice-prerelease-preview.collection.md'
            'Body.' | Set-Content -Path $mdPath
            $outPath = Join-Path $script:tempDir 'README.notice-prerelease-preview.md'

            New-CollectionReadme -Collection $collection -CollectionMdPath $mdPath -TemplatePath $script:templatePath -RepoRoot $script:tempDir -OutputPath $outPath -AllowedMaturities @('stable', 'preview', 'experimental') -Channel 'PreRelease'

            $content = Get-Content -Path $outPath -Raw
            $content | Should -Match 'Pre-Release with preview content'
            $content | Should -Not -Match 'experimental assets'
        }

        It 'Emits mild pre-release notice on PreRelease channel when all items are stable' {
            $collection = @{
                id          = 'notice-allstable'
                name        = 'Notice All Stable'
                description = 'Effective-set notice test'
                maturity    = 'stable'
                items       = @(
                    @{ kind = 'agent'; path = '.github/agents/alpha.agent.md'; maturity = 'stable' },
                    @{ kind = 'agent'; path = '.github/agents/zebra.agent.md'; maturity = 'stable' }
                )
            }
            $mdPath = Join-Path $script:tempDir 'notice-allstable.collection.md'
            'Body.' | Set-Content -Path $mdPath
            $outPath = Join-Path $script:tempDir 'README.notice-allstable.md'

            New-CollectionReadme -Collection $collection -CollectionMdPath $mdPath -TemplatePath $script:templatePath -RepoRoot $script:tempDir -OutputPath $outPath -AllowedMaturities @('stable', 'preview', 'experimental') -Channel 'PreRelease'

            $content = Get-Content -Path $outPath -Raw
            $content | Should -Match 'Pre-Release build'
            $content | Should -Match 'early access and feedback'
            $content | Should -Not -Match 'experimental assets'
            $content | Should -Not -Match 'preview content'
        }

        It 'Emits existing experimental collection notice regardless of effective set' {
            $collection = @{
                id          = 'notice-experimental-coll'
                name        = 'Notice Experimental Collection'
                description = 'Effective-set notice test'
                maturity    = 'experimental'
                items       = @(
                    @{ kind = 'agent'; path = '.github/agents/alpha.agent.md'; maturity = 'stable' }
                )
            }
            $mdPath = Join-Path $script:tempDir 'notice-experimental-coll.collection.md'
            'Body.' | Set-Content -Path $mdPath
            $outPath = Join-Path $script:tempDir 'README.notice-experimental-coll.md'

            New-CollectionReadme -Collection $collection -CollectionMdPath $mdPath -TemplatePath $script:templatePath -RepoRoot $script:tempDir -OutputPath $outPath -AllowedMaturities @('stable', 'preview', 'experimental') -Channel 'PreRelease'

            $content = Get-Content -Path $outPath -Raw
            $content | Should -Match 'Experimental'
            $content | Should -Match 'experimental and available only in the Pre-Release channel'
            $content | Should -Not -Match 'Pre-Release with experimental content'
        }
    }
}

Describe 'Resolve-CollectionDescription' {
    It 'Returns collection description on Stable channel with no overrides' {
        $collection = @{ description = 'Stable default' }
        $result = Resolve-CollectionDescription -Collection $collection -Channel 'Stable' -DefaultDescription 'Fallback'
        $result | Should -Be 'Stable default'
    }

    It 'Returns stable override on Stable channel when present' {
        $collection = @{
            description  = 'Default'
            descriptions = @(
                @{ channel = 'stable'; text = 'Stable override' }
                @{ channel = 'prerelease'; text = 'Pre override' }
            )
        }
        $result = Resolve-CollectionDescription -Collection $collection -Channel 'Stable' -DefaultDescription 'Fallback'
        $result | Should -Be 'Stable override'
    }

    It 'Returns prerelease override on PreRelease channel when present' {
        $collection = @{
            description  = 'Default'
            descriptions = @(
                @{ channel = 'stable'; text = 'Stable override' }
                @{ channel = 'prerelease'; text = 'Pre override' }
            )
        }
        $result = Resolve-CollectionDescription -Collection $collection -Channel 'PreRelease' -DefaultDescription 'Fallback'
        $result | Should -Be 'Pre override'
    }

    It 'Falls back to collection description on PreRelease channel when only stable override is present' {
        $collection = @{
            description  = 'Default'
            descriptions = @(
                @{ channel = 'stable'; text = 'Stable override' }
            )
        }
        $result = Resolve-CollectionDescription -Collection $collection -Channel 'PreRelease' -DefaultDescription 'Fallback'
        $result | Should -Be 'Default'
    }

    It 'Treats whitespace-only override as absent and falls back to collection description' {
        $collection = @{
            description  = 'Default'
            descriptions = @(
                @{ channel = 'prerelease'; text = '   ' }
            )
        }
        $result = Resolve-CollectionDescription -Collection $collection -Channel 'PreRelease' -DefaultDescription 'Fallback'
        $result | Should -Be 'Default'
    }

    It 'Returns DefaultDescription when collection lacks description and overrides' {
        $collection = @{ id = 'no-desc' }
        $result = Resolve-CollectionDescription -Collection $collection -Channel 'Stable' -DefaultDescription 'Fallback'
        $result | Should -Be 'Fallback'
    }
}

Describe 'Resolve-CollectionDisplayName' {
    It 'Returns stable override on Stable channel when present' {
        $collection = @{
            displayName  = 'Manifest Display'
            name         = 'fallback'
            displayNames = @{ stable = 'Stable Display'; prerelease = 'Pre Display' }
        }
        $result = Resolve-CollectionDisplayName -Collection $collection -Channel 'Stable' -DefaultDisplayName 'Default'
        $result | Should -Be 'Stable Display'
    }

    It 'Returns prerelease override on PreRelease channel when present' {
        $collection = @{
            displayName  = 'Manifest Display'
            name         = 'fallback'
            displayNames = @{ stable = 'Stable Display'; prerelease = 'Pre Display' }
        }
        $result = Resolve-CollectionDisplayName -Collection $collection -Channel 'PreRelease' -DefaultDisplayName 'Default'
        $result | Should -Be 'Pre Display'
    }

    It 'Falls back to manifest displayName on PreRelease channel when only stable override present' {
        $collection = @{
            displayName  = 'Manifest Display'
            name         = 'fallback'
            displayNames = @{ stable = 'Stable Display' }
        }
        $result = Resolve-CollectionDisplayName -Collection $collection -Channel 'PreRelease' -DefaultDisplayName 'Default'
        $result | Should -Be 'Manifest Display'
    }

    It 'Treats whitespace-only override as absent and falls back to manifest displayName' {
        $collection = @{
            displayName  = 'Manifest Display'
            displayNames = @{ prerelease = '   ' }
        }
        $result = Resolve-CollectionDisplayName -Collection $collection -Channel 'PreRelease' -DefaultDisplayName 'Default'
        $result | Should -Be 'Manifest Display'
    }

    It 'Returns DefaultDisplayName when collection lacks displayNames, displayName, and name' {
        $collection = @{ id = 'no-name' }
        $result = Resolve-CollectionDisplayName -Collection $collection -Channel 'Stable' -DefaultDisplayName 'Default'
        $result | Should -Be 'Default'
    }
}

#endregion Package Generation Function Tests

Describe 'Per-collection description and displayName constraints' {
    BeforeDiscovery {
        Import-Module powershell-yaml -ErrorAction Stop
        $repoRoot = (Get-Item "$PSScriptRoot/../../..").FullName
        $collectionsDir = Join-Path $repoRoot 'collections'
        $script:CollectionCases = @(
            Get-ChildItem -Path $collectionsDir -Filter '*.collection.yml' -File |
                Sort-Object Name |
                ForEach-Object { @{ Name = $_.Name; Path = $_.FullName } }
        )
    }

    It 'Collection <Name> satisfies marketplace length and distinctness constraints' -ForEach $CollectionCases {
        $manifest = Get-Content -Path $Path -Raw | ConvertFrom-Yaml

        $descriptionsStable = $null
        $descriptionsPrerelease = $null
        if ($manifest -and $manifest.ContainsKey('descriptions') -and $manifest.descriptions -is [System.Collections.IEnumerable] -and
            $manifest.descriptions -isnot [string]) {
            foreach ($entry in $manifest.descriptions) {
                if ($entry -is [System.Collections.IDictionary] -and $entry.Contains('channel') -and $entry.Contains('text')) {
                    switch ([string]$entry['channel']) {
                        'stable' { $descriptionsStable = [string]$entry['text'] }
                        'prerelease' { $descriptionsPrerelease = [string]$entry['text'] }
                    }
                }
            }
        }
        $displayNames = $null
        if ($manifest -and $manifest.ContainsKey('displayNames') -and $manifest.displayNames -is [hashtable]) {
            $displayNames = [hashtable]$manifest.displayNames
        }

        if ($null -ne $descriptionsStable) {
            $descriptionsStable.Length | Should -BeLessOrEqual 200 -Because "descriptions.stable in $Name must fit the VS Code Marketplace 200-char limit"
        }
        if ($null -ne $descriptionsPrerelease) {
            $descriptionsPrerelease.Length | Should -BeLessOrEqual 200 -Because "descriptions.prerelease in $Name must fit the VS Code Marketplace 200-char limit"
        }
        if ($displayNames -and $displayNames.ContainsKey('stable')) {
            ([string]$displayNames['stable']).Length | Should -BeLessOrEqual 80 -Because "displayNames.stable in $Name must fit a reasonable marketplace display length"
        }
        if ($displayNames -and $displayNames.ContainsKey('prerelease')) {
            ([string]$displayNames['prerelease']).Length | Should -BeLessOrEqual 80 -Because "displayNames.prerelease in $Name must fit a reasonable marketplace display length"
        }

        if ($null -ne $descriptionsStable -and $null -ne $descriptionsPrerelease) {
            if (-not [string]::IsNullOrWhiteSpace($descriptionsStable) -and -not [string]::IsNullOrWhiteSpace($descriptionsPrerelease)) {
                $descriptionsStable | Should -Not -Be $descriptionsPrerelease -Because "descriptions.stable and descriptions.prerelease in $Name should differ to justify per-channel overrides"
            }
        }
    }
}

Describe 'Get-AllowedMaturities' {
    It 'Returns only stable for Stable channel' {
        $result = Get-AllowedMaturities -Channel 'Stable'
        $result | Should -Be @('stable')
    }

    It 'Returns only stable for Stable channel even for hve-core-all' {
        $result = Get-AllowedMaturities -Channel 'Stable' -CollectionId 'hve-core-all'
        $result | Should -Be @('stable')
    }

    It 'Returns stable and preview for PreRelease channel without a collection' {
        $result = Get-AllowedMaturities -Channel 'PreRelease'
        $result | Should -Contain 'stable'
        $result | Should -Contain 'preview'
        $result | Should -Not -Contain 'experimental'
    }

    It 'Excludes experimental for PreRelease channel on a non-all collection' {
        $result = Get-AllowedMaturities -Channel 'PreRelease' -CollectionId 'ado'
        $result | Should -Contain 'stable'
        $result | Should -Contain 'preview'
        $result | Should -Not -Contain 'experimental'
    }

    It 'Includes experimental for PreRelease channel only for hve-core-all' {
        $result = Get-AllowedMaturities -Channel 'PreRelease' -CollectionId 'hve-core-all'
        $result | Should -Contain 'stable'
        $result | Should -Contain 'preview'
        $result | Should -Contain 'experimental'
    }

}

Describe 'Test-CollectionMaturityEligible' {
    It 'Returns eligible for stable collection on Stable channel' {
        $manifest = @{ id = 'test'; maturity = 'stable' }
        $result = Test-CollectionMaturityEligible -CollectionManifest $manifest -Channel 'Stable'
        $result.IsEligible | Should -BeTrue
        $result.Reason | Should -BeNullOrEmpty
    }

    It 'Returns eligible for stable collection on PreRelease channel' {
        $manifest = @{ id = 'test'; maturity = 'stable' }
        $result = Test-CollectionMaturityEligible -CollectionManifest $manifest -Channel 'PreRelease'
        $result.IsEligible | Should -BeTrue
    }

    It 'Returns eligible for preview collection on Stable channel' {
        $manifest = @{ id = 'test'; maturity = 'preview' }
        $result = Test-CollectionMaturityEligible -CollectionManifest $manifest -Channel 'Stable'
        $result.IsEligible | Should -BeTrue
    }

    It 'Returns eligible for preview collection on PreRelease channel' {
        $manifest = @{ id = 'test'; maturity = 'preview' }
        $result = Test-CollectionMaturityEligible -CollectionManifest $manifest -Channel 'PreRelease'
        $result.IsEligible | Should -BeTrue
    }

    It 'Returns ineligible for experimental collection on Stable channel' {
        $manifest = @{ id = 'exp-coll'; maturity = 'experimental' }
        $result = Test-CollectionMaturityEligible -CollectionManifest $manifest -Channel 'Stable'
        $result.IsEligible | Should -BeFalse
        $result.Reason | Should -Match 'experimental.*excluded from Stable'
    }

    It 'Returns eligible for experimental collection on PreRelease channel' {
        $manifest = @{ id = 'exp-coll'; maturity = 'experimental' }
        $result = Test-CollectionMaturityEligible -CollectionManifest $manifest -Channel 'PreRelease'
        $result.IsEligible | Should -BeTrue
    }

    It 'Returns ineligible for deprecated collection on Stable channel' {
        $manifest = @{ id = 'old-coll'; maturity = 'deprecated' }
        $result = Test-CollectionMaturityEligible -CollectionManifest $manifest -Channel 'Stable'
        $result.IsEligible | Should -BeFalse
        $result.Reason | Should -Match 'deprecated.*excluded from all channels'
    }

    It 'Returns ineligible for deprecated collection on PreRelease channel' {
        $manifest = @{ id = 'old-coll'; maturity = 'deprecated' }
        $result = Test-CollectionMaturityEligible -CollectionManifest $manifest -Channel 'PreRelease'
        $result.IsEligible | Should -BeFalse
        $result.Reason | Should -Match 'deprecated.*excluded from all channels'
    }

    It 'Returns ineligible for removed collection on Stable channel' {
        $manifest = @{ id = 'gone-coll'; maturity = 'removed' }
        $result = Test-CollectionMaturityEligible -CollectionManifest $manifest -Channel 'Stable'
        $result.IsEligible | Should -BeFalse
        $result.Reason | Should -Match 'removed.*excluded from all channels'
    }

    It 'Returns ineligible for removed collection on PreRelease channel' {
        $manifest = @{ id = 'gone-coll'; maturity = 'removed' }
        $result = Test-CollectionMaturityEligible -CollectionManifest $manifest -Channel 'PreRelease'
        $result.IsEligible | Should -BeFalse
        $result.Reason | Should -Match 'removed.*excluded from all channels'
    }

    It 'Defaults to stable when maturity key is absent' {
        $manifest = @{ id = 'no-maturity' }
        $result = Test-CollectionMaturityEligible -CollectionManifest $manifest -Channel 'Stable'
        $result.IsEligible | Should -BeTrue
    }

    It 'Defaults to stable when maturity value is empty string' {
        $manifest = @{ id = 'empty-maturity'; maturity = '' }
        $result = Test-CollectionMaturityEligible -CollectionManifest $manifest -Channel 'Stable'
        $result.IsEligible | Should -BeTrue
    }

    It 'Returns ineligible for unknown maturity value' {
        $manifest = @{ id = 'bad-coll'; maturity = 'alpha' }
        $result = Test-CollectionMaturityEligible -CollectionManifest $manifest -Channel 'PreRelease'
        $result.IsEligible | Should -BeFalse
        $result.Reason | Should -Match 'invalid maturity value'
    }

    It 'Returns hashtable with expected keys' {
        $manifest = @{ id = 'test'; maturity = 'stable' }
        $result = Test-CollectionMaturityEligible -CollectionManifest $manifest -Channel 'Stable'
        $result.Keys | Should -Contain 'IsEligible'
        $result.Keys | Should -Contain 'Reason'
    }
}

Describe 'Test-PathsExist' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null
        $script:extDir = Join-Path $script:tempDir 'extension'
        $script:ghDir = Join-Path $script:tempDir '.github'
        New-Item -ItemType Directory -Path $script:extDir -Force | Out-Null
        New-Item -ItemType Directory -Path $script:ghDir -Force | Out-Null
        $script:pkgJson = Join-Path $script:extDir 'package.json'
        '{}' | Set-Content -Path $script:pkgJson
    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Returns valid when all paths exist' {
        $result = Test-PathsExist -ExtensionDir $script:extDir -PackageJsonPath $script:pkgJson -GitHubDir $script:ghDir
        $result.IsValid | Should -BeTrue
        $result.MissingPaths | Should -BeNullOrEmpty
    }

    It 'Returns invalid when extension dir missing' {
        $nonexistentPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), 'nonexistent-ext-dir-12345')
        $result = Test-PathsExist -ExtensionDir $nonexistentPath -PackageJsonPath $script:pkgJson -GitHubDir $script:ghDir
        $result.IsValid | Should -BeFalse
        $result.MissingPaths | Should -Contain $nonexistentPath
    }

    It 'Collects multiple missing paths' {
        $missing1 = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), 'missing-path-1')
        $missing2 = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), 'missing-path-2')
        $missing3 = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), 'missing-path-3')
        $result = Test-PathsExist -ExtensionDir $missing1 -PackageJsonPath $missing2 -GitHubDir $missing3
        $result.IsValid | Should -BeFalse
        $result.MissingPaths.Count | Should -Be 3
    }
}

Describe 'Get-DiscoveredAgents' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        $script:agentsDir = Join-Path $script:tempDir 'agents'
        $script:agentsSubDir = Join-Path $script:agentsDir 'test-collection'
        New-Item -ItemType Directory -Path $script:agentsSubDir -Force | Out-Null

        # Create test agent files in subdirectory (distributable)
        @'
---
description: "Stable agent"
---
'@ | Set-Content -Path (Join-Path $script:agentsSubDir 'stable.agent.md')

        @'
---
description: "Preview agent"
---
'@ | Set-Content -Path (Join-Path $script:agentsSubDir 'preview.agent.md')

        # Create root-level agent (repo-specific, should be skipped)
        @'
---
description: "Root-level agent"
---
'@ | Set-Content -Path (Join-Path $script:agentsDir 'root-agent.agent.md')

    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Discovers agents matching allowed maturities' {
        $result = Get-DiscoveredAgents -AgentsDir $script:agentsDir -AllowedMaturities @('stable', 'preview') -ExcludedAgents @()
        $result.DirectoryExists | Should -BeTrue
        $result.Agents.Count | Should -Be 2
    }

    It 'Filters agents by maturity' {
        $result = Get-DiscoveredAgents -AgentsDir $script:agentsDir -AllowedMaturities @('preview') -ExcludedAgents @()
        $result.Agents.Count | Should -Be 0
        $result.Skipped.Count | Should -Be 3
    }

    It 'Excludes specified agents' {
        $result = Get-DiscoveredAgents -AgentsDir $script:agentsDir -AllowedMaturities @('stable', 'preview') -ExcludedAgents @('stable')
        $result.Agents.Count | Should -Be 1
    }

    It 'Returns empty when directory does not exist' {
        $nonexistentPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), 'nonexistent-agents-dir-12345')
        $result = Get-DiscoveredAgents -AgentsDir $nonexistentPath -AllowedMaturities @('stable') -ExcludedAgents @()
        $result.DirectoryExists | Should -BeFalse
        $result.Agents | Should -BeNullOrEmpty
    }

    It 'Skips root-level repo-specific agents with correct skip reason' {
        $result = Get-DiscoveredAgents -AgentsDir $script:agentsDir -AllowedMaturities @('stable', 'preview') -ExcludedAgents @()
        $agentNames = $result.Agents | ForEach-Object { $_.name }
        $agentNames | Should -Not -Contain 'root-agent'
        $skipped = $result.Skipped | Where-Object { $_.Name -eq 'root-agent' }
        $skipped | Should -Not -BeNullOrEmpty
        $skipped.Reason | Should -Match 'repo-specific'
    }
}

Describe 'Get-DiscoveredPrompts' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        $script:promptsDir = Join-Path $script:tempDir 'prompts'
        $script:promptsSubDir = Join-Path $script:promptsDir 'test-collection'
        $script:ghDir = Join-Path $script:tempDir '.github'
        New-Item -ItemType Directory -Path $script:promptsSubDir -Force | Out-Null
        New-Item -ItemType Directory -Path $script:ghDir -Force | Out-Null

        @'
---
description: "Test prompt"
---
'@ | Set-Content -Path (Join-Path $script:promptsSubDir 'test.prompt.md')
    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Discovers prompts in directory' {
        $result = Get-DiscoveredPrompts -PromptsDir $script:promptsDir -GitHubDir $script:ghDir -AllowedMaturities @('stable')
        $result.DirectoryExists | Should -BeTrue
        $result.Prompts.Count | Should -BeGreaterThan 0
    }

    It 'Returns empty when directory does not exist' {
        $nonexistentPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), 'nonexistent-prompts-dir-12345')
        $result = Get-DiscoveredPrompts -PromptsDir $nonexistentPath -GitHubDir $script:ghDir -AllowedMaturities @('stable')
        $result.DirectoryExists | Should -BeFalse
    }
}

Describe 'Get-DiscoveredInstructions' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        $script:instrDir = Join-Path $script:tempDir 'instructions'
        $script:instrSubDir = Join-Path $script:instrDir 'test-collection'
        $script:ghDir = Join-Path $script:tempDir '.github'
        New-Item -ItemType Directory -Path $script:instrSubDir -Force | Out-Null
        New-Item -ItemType Directory -Path $script:ghDir -Force | Out-Null

        @'
---
description: "Test instruction"
applyTo: "**/*.ps1"
---
'@ | Set-Content -Path (Join-Path $script:instrSubDir 'test.instructions.md')
    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Discovers instructions in directory' {
        $result = Get-DiscoveredInstructions -InstructionsDir $script:instrDir -GitHubDir $script:ghDir -AllowedMaturities @('stable')
        $result.DirectoryExists | Should -BeTrue
        $result.Instructions.Count | Should -BeGreaterThan 0
    }

    It 'Returns empty when directory does not exist' {
        $nonexistentPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), 'nonexistent-instr-dir-12345')
        $result = Get-DiscoveredInstructions -InstructionsDir $nonexistentPath -GitHubDir $script:ghDir -AllowedMaturities @('stable')
        $result.DirectoryExists | Should -BeFalse
    }

    It 'Skips root-level repo-specific instructions' {
        @'
---
description: "Repo-specific workflow instruction"
applyTo: "**/.github/workflows/*.yml"
---
'@ | Set-Content -Path (Join-Path $script:instrDir 'workflows.instructions.md')

        $result = Get-DiscoveredInstructions -InstructionsDir $script:instrDir -GitHubDir $script:ghDir -AllowedMaturities @('stable')
        $instrNames = $result.Instructions | ForEach-Object { $_.name }
        $instrNames | Should -Not -Contain 'workflows-instructions'
        $result.Skipped | Where-Object { $_.Reason -match 'repo-specific' } | Should -Not -BeNullOrEmpty
    }

    It 'Still discovers instructions in subdirectories' {
        $otherDir = Join-Path $script:instrDir 'csharp'
        New-Item -ItemType Directory -Path $otherDir -Force | Out-Null
        @'
---
description: "Repo-specific"
applyTo: "**/.github/workflows/*.yml"
---
'@ | Set-Content -Path (Join-Path $script:instrDir 'workflows.instructions.md')
        @'
---
description: "C# instruction"
applyTo: "**/*.cs"
---
'@ | Set-Content -Path (Join-Path $otherDir 'csharp.instructions.md')

        $result = Get-DiscoveredInstructions -InstructionsDir $script:instrDir -GitHubDir $script:ghDir -AllowedMaturities @('stable')
        $instrNames = $result.Instructions | ForEach-Object { $_.name }
        $instrNames | Should -Contain 'csharp-instructions'
        $instrNames | Should -Not -Contain 'workflows-instructions'
    }
}

Describe 'Get-DiscoveredSkills' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        $script:skillsDir = Join-Path $script:tempDir 'skills'
        New-Item -ItemType Directory -Path $script:skillsDir -Force | Out-Null

        # Create test skill under a collection-id directory
        $skillDir = Join-Path $script:skillsDir 'test-collection/test-skill'
        New-Item -ItemType Directory -Path $skillDir -Force | Out-Null
        @'
---
name: test-skill
description: "Test skill"
---
# Skill
'@ | Set-Content -Path (Join-Path $skillDir 'SKILL.md')

        # Create nested skill under same collection-id directory
        $nestedSkillDir = Join-Path $script:skillsDir 'test-collection/nested-skill'
        New-Item -ItemType Directory -Path $nestedSkillDir -Force | Out-Null
        @'
---
name: nested-skill
description: "Nested skill in collection"
---
# Nested Skill
'@ | Set-Content -Path (Join-Path $nestedSkillDir 'SKILL.md')

        # Create root-level skill (repo-specific, should be skipped)
        $rootSkillDir = Join-Path $script:skillsDir 'root-skill'
        New-Item -ItemType Directory -Path $rootSkillDir -Force | Out-Null
        @'
---
name: root-skill
description: "Root-level skill"
---
# Root Skill
'@ | Set-Content -Path (Join-Path $rootSkillDir 'SKILL.md')

    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Discovers skills in directory' {
        $result = Get-DiscoveredSkills -SkillsDir $script:skillsDir -AllowedMaturities @('stable')
        $result.DirectoryExists | Should -BeTrue
        $result.Skills.Count | Should -Be 2
        $skillNames = $result.Skills | ForEach-Object { $_.name }
        $skillNames | Should -Contain 'test-skill'
        $skillNames | Should -Contain 'nested-skill'
    }

    It 'Returns empty when directory does not exist' {
        $nonexistent = Join-Path $script:tempDir 'nonexistent-skills'
        $result = Get-DiscoveredSkills -SkillsDir $nonexistent -AllowedMaturities @('stable')
        $result.DirectoryExists | Should -BeFalse
        $result.Skills | Should -BeNullOrEmpty
    }

    It 'Filters skills when stable is not an allowed maturity' {
        $result = Get-DiscoveredSkills -SkillsDir $script:skillsDir -AllowedMaturities @('preview')
        $result.Skills.Count | Should -Be 0
        $result.Skipped.Count | Should -BeGreaterThan 0
    }

    It 'Discovers nested skills with correct path' {
        $result = Get-DiscoveredSkills -SkillsDir $script:skillsDir -AllowedMaturities @('stable')
        $nestedSkill = $result.Skills | Where-Object { $_.name -eq 'nested-skill' }
        $nestedSkill | Should -Not -BeNullOrEmpty
        $nestedSkill.path | Should -Be './.github/skills/test-collection/nested-skill/SKILL.md'
    }

    It 'Skips root-level repo-specific skills with correct skip reason' {
        $result = Get-DiscoveredSkills -SkillsDir $script:skillsDir -AllowedMaturities @('stable')
        $skillNames = $result.Skills | ForEach-Object { $_.name }
        $skillNames | Should -Not -Contain 'root-skill'
        $skipped = $result.Skipped | Where-Object { $_.Name -eq 'root-skill' }
        $skipped | Should -Not -BeNullOrEmpty
        $skipped.Reason | Should -Match 'repo-specific'
    }
}

Describe 'Get-CollectionManifest' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Loads collection manifest from valid YAML path' {
        $manifestFile = Join-Path $script:tempDir 'test.collection.yml'
        @"
id: test
name: test-ext
displayName: Test Extension
description: Test
items:
  - hve-core-all
"@ | Set-Content -Path $manifestFile

        $result = Get-CollectionManifest -CollectionPath $manifestFile
        $result | Should -Not -BeNullOrEmpty
        $result.id | Should -Be 'test'
    }

    It 'Loads collection manifest from valid JSON path' {
        $manifestFile = Join-Path $script:tempDir 'test.collection.json'
        @{
            '\$schema' = '../schemas/collection-manifest.schema.json'
            id = 'test'
            name = 'test-ext'
            displayName = 'Test Extension'
            description = 'Test'
            items = @('hve-core-all')
        } | ConvertTo-Json -Depth 5 | Set-Content -Path $manifestFile

        $result = Get-CollectionManifest -CollectionPath $manifestFile
        $result | Should -Not -BeNullOrEmpty
        $result.id | Should -Be 'test'
    }

    It 'Throws when path does not exist' {
        $nonexistent = Join-Path $script:tempDir 'nonexistent.json'
        { Get-CollectionManifest -CollectionPath $nonexistent } | Should -Throw '*not found*'
    }

    It 'Returns hashtable with expected keys' {
        $manifestFile = Join-Path $script:tempDir 'keys.collection.yml'
        @"
id: keys
name: keys-ext
displayName: Keys
description: Keys test
items:
  - developer
"@ | Set-Content -Path $manifestFile

        $result = Get-CollectionManifest -CollectionPath $manifestFile
        $result.Keys | Should -Contain 'id'
        $result.Keys | Should -Contain 'name'
        $result.Keys | Should -Contain 'items'
    }
}

Describe 'Test-GlobMatch' {
    It 'Returns true for matching wildcard pattern' {
        $result = Test-GlobMatch -Name 'rpi-agent' -Patterns @('rpi-*')
        $result | Should -BeTrue
    }

    It 'Returns false for non-matching pattern' {
        $result = Test-GlobMatch -Name 'memory' -Patterns @('rpi-*')
        $result | Should -BeFalse
    }

    It 'Matches against multiple patterns' {
        $result = Test-GlobMatch -Name 'memory' -Patterns @('rpi-*', 'mem*')
        $result | Should -BeTrue
    }

    It 'Handles exact name match' {
        $result = Test-GlobMatch -Name 'memory' -Patterns @('memory')
        $result | Should -BeTrue
    }
}

Describe 'Get-CollectionArtifacts' {
    It 'Returns artifacts from collection items across supported kinds' {
        $collection = @{
            items = @(
                @{ kind = 'agent'; path = '.github/agents/dev-agent.agent.md' },
                @{ kind = 'prompt'; path = '.github/prompts/dev-prompt.prompt.md' },
                @{ kind = 'instruction'; path = '.github/instructions/dev/dev.instructions.md' },
                @{ kind = 'skill'; path = '.github/skills/video-to-gif/' }
            )
        }

        $result = Get-CollectionArtifacts -Collection $collection -AllowedMaturities @('stable', 'preview')
        $result.Agents | Should -Contain 'dev-agent'
        $result.Prompts | Should -Contain 'dev-prompt'
        $result.Instructions | Should -Contain 'dev/dev'
        $result.Skills | Should -Contain 'video-to-gif'
    }

    It 'Uses item maturity when provided' {
        $collection = @{
            items = @(
                @{ kind = 'agent'; path = '.github/agents/dev-agent.agent.md'; maturity = 'stable' },
                @{ kind = 'agent'; path = '.github/agents/preview-dev.agent.md'; maturity = 'preview' }
            )
        }

        $result = Get-CollectionArtifacts -Collection $collection -AllowedMaturities @('stable')
        $result.Agents | Should -Contain 'dev-agent'
        $result.Agents | Should -Not -Contain 'preview-dev'
    }

    It 'Defaults to stable maturity when item maturity is omitted' {
        $collection = @{
            items = @(
                @{ kind = 'agent'; path = '.github/agents/dev-agent.agent.md' },
                @{ kind = 'agent'; path = '.github/agents/preview-dev.agent.md' }
            )
        }

        $result = Get-CollectionArtifacts -Collection $collection -AllowedMaturities @('stable')
        $result.Agents | Should -Contain 'dev-agent'
        $result.Agents | Should -Contain 'preview-dev'
    }

    It 'Returns empty when collection has no items' {
        $collection = @{ id = 'empty' }
        $result = Get-CollectionArtifacts -Collection $collection -AllowedMaturities @('stable')
        $result.Agents.Count | Should -Be 0
        $result.Prompts.Count | Should -Be 0
        $result.Instructions.Count | Should -Be 0
        $result.Skills.Count | Should -Be 0
    }
}

Describe 'Resolve-HandoffDependencies' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        $script:agentsDir = Join-Path $script:tempDir 'agents'
        New-Item -ItemType Directory -Path $script:agentsDir -Force | Out-Null

        # Agent with no handoffs
        @'
---
description: "Solo agent"
---
'@ | Set-Content -Path (Join-Path $script:agentsDir 'solo.agent.md')

        # Agent with single handoff (object format matching real agents)
        @'
---
description: "Parent agent"
handoffs:
  - label: "Go to child"
    agent: child
    prompt: Continue
---
'@ | Set-Content -Path (Join-Path $script:agentsDir 'parent.agent.md')

        @'
---
description: "Child agent"
---
'@ | Set-Content -Path (Join-Path $script:agentsDir 'child.agent.md')

        # Self-referential agent (object format)
        @'
---
description: "Self agent"
handoffs:
  - label: "Self"
    agent: self-ref
---
'@ | Set-Content -Path (Join-Path $script:agentsDir 'self-ref.agent.md')

        # Circular chain (object format)
        @'
---
description: "Chain A"
handoffs:
  - label: "To B"
    agent: chain-b
---
'@ | Set-Content -Path (Join-Path $script:agentsDir 'chain-a.agent.md')

        @'
---
description: "Chain B"
handoffs:
  - label: "To A"
    agent: chain-a
---
'@ | Set-Content -Path (Join-Path $script:agentsDir 'chain-b.agent.md')

    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Returns seed agents when no handoffs' {
        $result = Resolve-HandoffDependencies -SeedAgents @('solo') -AgentsDir $script:agentsDir
        $result | Should -Contain 'solo'
        $result.Count | Should -Be 1
    }

    It 'Resolves single-level handoff' {
        $result = Resolve-HandoffDependencies -SeedAgents @('parent') -AgentsDir $script:agentsDir
        $result | Should -Contain 'parent'
        $result | Should -Contain 'child'
    }

    It 'Handles self-referential handoffs' {
        $result = Resolve-HandoffDependencies -SeedAgents @('self-ref') -AgentsDir $script:agentsDir
        $result | Should -Contain 'self-ref'
        $result.Count | Should -Be 1
    }

    It 'Handles circular handoff chains' {
        $result = Resolve-HandoffDependencies -SeedAgents @('chain-a') -AgentsDir $script:agentsDir
        $result | Should -Contain 'chain-a'
        $result | Should -Contain 'chain-b'
        $result.Count | Should -Be 2
    }
}

Describe 'Resolve-RequiresDependencies' {
    It 'Resolves agent requires to include dependent prompts' {
        $result = Resolve-RequiresDependencies `
            -ArtifactNames @{ agents = @('main') } `
            -AllowedMaturities @('stable') `
            -CollectionRequires @{ agents = @{ 'main' = @{ prompts = @('dep-prompt') } } } `
            -CollectionMaturities @{ prompts = @{ 'dep-prompt' = 'stable' } }
        $result.Prompts | Should -Contain 'dep-prompt'
    }

    It 'Resolves transitive agent dependencies' {
        $result = Resolve-RequiresDependencies `
            -ArtifactNames @{ agents = @('top') } `
            -AllowedMaturities @('stable') `
            -CollectionRequires @{ agents = @{ 'top' = @{ agents = @('mid') }; 'mid' = @{ prompts = @('leaf-prompt') } } } `
            -CollectionMaturities @{ agents = @{ 'mid' = 'stable' }; prompts = @{ 'leaf-prompt' = 'stable' } }
        $result.Agents | Should -Contain 'mid'
        $result.Prompts | Should -Contain 'leaf-prompt'
    }

    It 'Respects maturity filter on dependencies' {
        $result = Resolve-RequiresDependencies `
            -ArtifactNames @{ agents = @('main') } `
            -AllowedMaturities @('stable') `
            -CollectionRequires @{ agents = @{ 'main' = @{ prompts = @('exp-prompt') } } } `
            -CollectionMaturities @{ prompts = @{ 'exp-prompt' = 'experimental' } }
        $result.Prompts | Should -Not -Contain 'exp-prompt'
    }
}

Describe 'Update-PackageJsonContributes' {
    It 'Updates contributes section with chat participants' {
        $packageJson = [PSCustomObject]@{
            name = 'test-extension'
            contributes = [PSCustomObject]@{}
        }
        $agents = @(
            @{ name = 'agent1'; description = 'Desc 1' }
        )
        $prompts = @(
            @{ name = 'prompt1'; description = 'Prompt desc' }
        )
        $instructions = @(
            @{ name = 'instr1'; description = 'Instr desc' }
        )

        $result = Update-PackageJsonContributes -PackageJson $packageJson -ChatAgents $agents -ChatPromptFiles $prompts -ChatInstructions $instructions -ChatSkills @()
        $result.contributes | Should -Not -BeNullOrEmpty
    }

    It 'Handles empty arrays' {
        $packageJson = [PSCustomObject]@{
            name = 'test-extension'
            contributes = [PSCustomObject]@{}
        }

        $result = Update-PackageJsonContributes -PackageJson $packageJson -ChatAgents @() -ChatPromptFiles @() -ChatInstructions @() -ChatSkills @()
        $result | Should -Not -BeNullOrEmpty
    }
}

Describe 'New-PrepareResult' {
    It 'Creates success result with counts' {
        $result = New-PrepareResult -Success $true -AgentCount 5 -PromptCount 10 -InstructionCount 15 -SkillCount 3 -Version '1.0.0'
        $result.Success | Should -BeTrue
        $result.AgentCount | Should -Be 5
        $result.PromptCount | Should -Be 10
        $result.InstructionCount | Should -Be 15
        $result.SkillCount | Should -Be 3
        $result.Version | Should -Be '1.0.0'
        $result.ErrorMessage | Should -BeNullOrEmpty
    }

    It 'Creates failure result with error message' {
        $result = New-PrepareResult -Success $false -ErrorMessage 'Something went wrong'
        $result.Success | Should -BeFalse
        $result.ErrorMessage | Should -Be 'Something went wrong'
        $result.AgentCount | Should -Be 0
        $result.PromptCount | Should -Be 0
        $result.InstructionCount | Should -Be 0
    }

    It 'Returns hashtable with all expected keys' {
        $result = New-PrepareResult -Success $true
        $result.Keys | Should -Contain 'Success'
        $result.Keys | Should -Contain 'AgentCount'
        $result.Keys | Should -Contain 'PromptCount'
        $result.Keys | Should -Contain 'InstructionCount'
        $result.Keys | Should -Contain 'SkillCount'
        $result.Keys | Should -Contain 'Version'
        $result.Keys | Should -Contain 'ErrorMessage'
    }
}

Describe 'Invoke-PrepareExtension' {
    BeforeAll {
        $script:tempDir = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null

        # Create extension directory with package.json
        $script:extDir = Join-Path $script:tempDir 'extension'
        New-Item -ItemType Directory -Path $script:extDir -Force | Out-Null
        @'
{
    "name": "test-extension",
    "version": "1.2.3",
    "contributes": {}
}
'@ | Set-Content -Path (Join-Path $script:extDir 'package.json')

        # Create package template for generation
        $script:templatesDir = Join-Path $script:extDir 'templates'
        New-Item -ItemType Directory -Path $script:templatesDir -Force | Out-Null
        @'
{
    "name": "hve-core",
    "displayName": "HVE Core",
    "version": "1.2.3",
    "description": "Test extension",
    "publisher": "test-pub",
    "engines": { "vscode": "^1.80.0" },
    "contributes": {}
}
'@ | Set-Content -Path (Join-Path $script:templatesDir 'package.template.json')

        # Create collections directory with a minimal hve-core collection (flagship)
        $script:collectionsDir = Join-Path $script:tempDir 'collections'
        New-Item -ItemType Directory -Path $script:collectionsDir -Force | Out-Null
        @"
id: hve-core
name: HVE Core
displayName: HVE Core
description: Test extension
"@ | Set-Content -Path (Join-Path $script:collectionsDir 'hve-core.collection.yml')

        # Central manifest: production projects collections from this file.
        @"
schemaVersion: `"1.0`"
collections:
  hve-core:
    name: HVE Core
    intro: HVE Core flagship collection.
    descriptions:
      - channel: stable
        text: Test extension
  hve-core-all:
    name: hve-core-all
    descriptions:
      - channel: stable
        text: All collections edition
  developer:
    name: hve-developer
    descriptions:
      - channel: stable
        text: Developer edition
  perchannel:
    name: hve-perchannel
    descriptions:
      - channel: stable
        text: Stable per-channel description
      - channel: prerelease
        text: 'Experimental: Per-channel preview description'
  deprecated-coll:
    name: deprecated-ext
    maturity: deprecated
    descriptions:
      - channel: stable
        text: Deprecated collection for testing
  experimental-coll:
    name: experimental-ext
    maturity: experimental
    descriptions:
      - channel: stable
        text: Experimental collection for testing
  pin-target:
    name: pin-target
    descriptions:
      - channel: stable
        text: Pin target stable description
      - channel: prerelease
        text: 'Experimental: Pin target preview description'
"@ | Set-Content -Path (Join-Path $script:collectionsDir 'core-manifest.yml')

        # README template (required for README generation); reuse the real template.
        $readmeTemplateSource = Join-Path (Get-Item "$PSScriptRoot/../../..").FullName 'extension/templates/README.template.md'
        Copy-Item -Path $readmeTemplateSource -Destination (Join-Path $script:templatesDir 'README.template.md') -Force

        # Create .github structure with subdirectories (root-level files are repo-specific)
        $script:ghDir = Join-Path $script:tempDir '.github'
        $script:agentsDir = Join-Path $script:ghDir 'agents'
        $script:agentsSubDir = Join-Path $script:agentsDir 'test-collection'
        $script:promptsDir = Join-Path $script:ghDir 'prompts'
        $script:promptsSubDir = Join-Path $script:promptsDir 'test-collection'
        $script:instrDir = Join-Path $script:ghDir 'instructions'
        $script:instrSubDir = Join-Path $script:instrDir 'test-collection'
        New-Item -ItemType Directory -Path $script:agentsSubDir -Force | Out-Null
        New-Item -ItemType Directory -Path $script:promptsSubDir -Force | Out-Null
        New-Item -ItemType Directory -Path $script:instrSubDir -Force | Out-Null

        # Create test agent in subdirectory
        @'
---
description: "Test agent"
---
# Agent
'@ | Set-Content -Path (Join-Path $script:agentsSubDir 'test.agent.md')

        # Create test prompt in subdirectory
        @'
---
description: "Test prompt"
---
# Prompt
'@ | Set-Content -Path (Join-Path $script:promptsSubDir 'test.prompt.md')

        # Create test instruction in subdirectory
        @'
---
description: "Test instruction"
applyTo: "**/*.ps1"
---
# Instruction
'@ | Set-Content -Path (Join-Path $script:instrSubDir 'test.instructions.md')

    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Returns success result with correct counts' {
        $result = Invoke-PrepareExtension `
            -ExtensionDirectory $script:extDir `
            -RepoRoot $script:tempDir `
            -Channel 'Stable' `
            -DryRun

        $result.Success | Should -BeTrue
        $result.AgentCount | Should -Be 1
        $result.PromptCount | Should -Be 1
        $result.InstructionCount | Should -Be 1
        $result.Version | Should -Be '1.2.3'
    }

    It 'Fails when extension directory missing' {
        $nonexistentPath = Join-Path $TestDrive 'nonexistent-ext-dir-12345'
        $result = Invoke-PrepareExtension `
            -ExtensionDirectory $nonexistentPath `
            -RepoRoot $script:tempDir `
            -Channel 'Stable'

        $result.Success | Should -BeFalse
        $result.ErrorMessage | Should -Not -BeNullOrEmpty
    }

    It 'Respects channel filtering' {
        # Add preview agent in subdirectory
        @'
---
description: "Preview agent"
---
'@ | Set-Content -Path (Join-Path $script:agentsSubDir 'preview.agent.md')

        $collectionPath = Join-Path $script:tempDir 'channel-filter.collection.yml'
        @"
id: hve-core
name: HVE Core
displayName: HVE Core
description: Channel filtering test
items:
  - kind: agent
    path: .github/agents/test-collection/test.agent.md
    maturity: stable
  - kind: agent
    path: .github/agents/test-collection/preview.agent.md
    maturity: preview
"@ | Set-Content -Path $collectionPath

        $stableResult = Invoke-PrepareExtension `
            -ExtensionDirectory $script:extDir `
            -RepoRoot $script:tempDir `
            -Channel 'Stable' `
            -Collection $collectionPath `
            -DryRun

        $preReleaseResult = Invoke-PrepareExtension `
            -ExtensionDirectory $script:extDir `
            -RepoRoot $script:tempDir `
            -Channel 'PreRelease' `
            -Collection $collectionPath `
            -DryRun

        $preReleaseResult.AgentCount | Should -BeGreaterThan $stableResult.AgentCount
    }

    It 'Filters prompts and instructions by maturity' {
        # Add experimental prompt in subdirectory
        @'
---
description: "Experimental prompt"
---
'@ | Set-Content -Path (Join-Path $script:promptsSubDir 'experimental.prompt.md')

        # Add preview instruction in subdirectory
        @'
---
description: "Preview instruction"
applyTo: "**/*.js"
---
'@ | Set-Content -Path (Join-Path $script:instrSubDir 'preview.instructions.md')

        $collectionPath = Join-Path $script:tempDir 'prompt-instruction-filter.collection.yml'
        @"
id: hve-core-all
name: HVE Core
displayName: HVE Core
description: Prompt/instruction filtering test
items:
  - kind: agent
    path: .github/agents/test-collection/test.agent.md
    maturity: stable
  - kind: prompt
    path: .github/prompts/test-collection/test.prompt.md
    maturity: stable
  - kind: prompt
    path: .github/prompts/test-collection/experimental.prompt.md
    maturity: experimental
  - kind: instruction
    path: .github/instructions/test-collection/test.instructions.md
    maturity: stable
  - kind: instruction
    path: .github/instructions/test-collection/preview.instructions.md
    maturity: preview
"@ | Set-Content -Path $collectionPath

        $stableResult = Invoke-PrepareExtension `
            -ExtensionDirectory $script:extDir `
            -RepoRoot $script:tempDir `
            -Channel 'Stable' `
            -Collection $collectionPath `
            -DryRun

        $preReleaseResult = Invoke-PrepareExtension `
            -ExtensionDirectory $script:extDir `
            -RepoRoot $script:tempDir `
            -Channel 'PreRelease' `
            -Collection $collectionPath `
            -DryRun

        $preReleaseResult.PromptCount | Should -BeGreaterThan $stableResult.PromptCount
        $preReleaseResult.InstructionCount | Should -BeGreaterThan $stableResult.InstructionCount

        # Clean up backup left by the hve-core-all collection template copy
        $bakPath = Join-Path $script:extDir 'package.json.bak'
        if (Test-Path $bakPath) {
            Remove-Item -Path $bakPath -Force
        }
    }

    It 'Updates package.json when not DryRun' {
        $result = Invoke-PrepareExtension `
            -ExtensionDirectory $script:extDir `
            -RepoRoot $script:tempDir `
            -Channel 'Stable' `
            -DryRun:$false

        $result.Success | Should -BeTrue

        $pkgJson = Get-Content -Path (Join-Path $script:extDir 'package.json') -Raw | ConvertFrom-Json
        $pkgJson.contributes.chatAgents | Should -Not -BeNullOrEmpty
    }

    It 'Copies changelog when path provided' {
        $changelogPath = Join-Path $script:tempDir 'CHANGELOG.md'
        '# Changelog' | Set-Content -Path $changelogPath

        $result = Invoke-PrepareExtension `
            -ExtensionDirectory $script:extDir `
            -RepoRoot $script:tempDir `
            -Channel 'Stable' `
            -ChangelogPath $changelogPath `
            -DryRun:$false

        $result.Success | Should -BeTrue
        Test-Path (Join-Path $script:extDir 'CHANGELOG.md') | Should -BeTrue
    }

    It 'Fails when package template is missing' {
        $badRoot = Join-Path $TestDrive 'bad-template-root'
        $badExtDir = Join-Path $badRoot 'extension'
        New-Item -ItemType Directory -Path $badExtDir -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $badRoot 'collections') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $badRoot '.github/agents') -Force | Out-Null
        @"
id: test
"@ | Set-Content -Path (Join-Path $badRoot 'collections/test.collection.yml')

        $result = Invoke-PrepareExtension `
            -ExtensionDirectory $badExtDir `
            -RepoRoot $badRoot `
            -Channel 'Stable'

        $result.Success | Should -BeFalse
        $result.ErrorMessage | Should -Match 'Package generation failed'
    }

    It 'Fails when no collection YAML files exist' {
        $emptyRoot = Join-Path $TestDrive 'empty-collections-root'
        $emptyExtDir = Join-Path $emptyRoot 'extension'
        New-Item -ItemType Directory -Path $emptyExtDir -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $emptyRoot 'collections') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $emptyRoot 'extension/templates') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $emptyRoot '.github/agents') -Force | Out-Null
        @{ name = 'test'; version = '1.0.0' } | ConvertTo-Json | Set-Content -Path (Join-Path $emptyRoot 'extension/templates/package.template.json')

        $result = Invoke-PrepareExtension `
            -ExtensionDirectory $emptyExtDir `
            -RepoRoot $emptyRoot `
            -Channel 'Stable'

        $result.Success | Should -BeFalse
        $result.ErrorMessage | Should -Match 'Package generation failed'
    }

    Context 'Collection template copy' {
        BeforeAll {
            # Developer collection manifest (in collections/ for generation)
            $script:devCollectionYaml = Join-Path $script:collectionsDir 'developer.collection.yml'
            @"
id: developer
name: hve-developer
displayName: HVE Core - Developer Edition
description: Developer edition
"@ | Set-Content -Path $script:devCollectionYaml
            $script:devCollectionPath = $script:devCollectionYaml

            # hve-core collection manifest (flagship, skips template copy)
            $script:coreCollectionPath = Join-Path $script:tempDir 'hve-core.collection.yml'
            @"
id: hve-core
name: HVE Core
displayName: HVE Core
description: Flagship collection
"@ | Set-Content -Path $script:coreCollectionPath

            # Collection manifest referencing a missing template
            $script:missingCollectionPath = Join-Path $script:tempDir 'nonexistent.collection.yml'
            @"
id: nonexistent
name: nonexistent
displayName: Nonexistent
description: Missing template
"@ | Set-Content -Path $script:missingCollectionPath

        }

        AfterEach {
            # Clean up backup files left by collection template copy
            $bakPath = Join-Path $script:extDir 'package.json.bak'
            if (Test-Path $bakPath) {
                Remove-Item -Path $bakPath -Force
            }
        }

        It 'Skips template copy when no collection specified' {
            $result = Invoke-PrepareExtension `
                -ExtensionDirectory $script:extDir `
                -RepoRoot $script:tempDir `
                -Channel 'Stable' `
                -DryRun

            $result.Success | Should -BeTrue
            # package.json should contain the generated hve-core content (not a collection template)
            $currentJson = Get-Content -Path (Join-Path $script:extDir 'package.json') -Raw | ConvertFrom-Json
            $currentJson.name | Should -Be 'hve-core'
            Test-Path (Join-Path $script:extDir 'package.json.bak') | Should -BeFalse
        }

        It 'Skips template copy for hve-core collection' {
            $result = Invoke-PrepareExtension `
                -ExtensionDirectory $script:extDir `
                -RepoRoot $script:tempDir `
                -Channel 'Stable' `
                -Collection $script:coreCollectionPath `
                -DryRun

            $result.Success | Should -BeTrue
            Test-Path (Join-Path $script:extDir 'package.json.bak') | Should -BeFalse
        }

        It 'Returns error when collection template file missing' {
            $result = Invoke-PrepareExtension `
                -ExtensionDirectory $script:extDir `
                -RepoRoot $script:tempDir `
                -Channel 'Stable' `
                -Collection $script:missingCollectionPath `
                -DryRun

            $result.Success | Should -BeFalse
            $result.ErrorMessage | Should -Match 'Collection template not found'
        }

        It 'Copies template to package.json for non-default collection' {
            $result = Invoke-PrepareExtension `
                -ExtensionDirectory $script:extDir `
                -RepoRoot $script:tempDir `
                -Channel 'Stable' `
                -Collection $script:devCollectionPath `
                -DryRun

            $result.Success | Should -BeTrue
            $updatedJson = Get-Content -Path (Join-Path $script:extDir 'package.json') -Raw | ConvertFrom-Json
            $updatedJson.name | Should -Be 'hve-developer'
        }

        It 'Creates package.json.bak backup before template copy' {
            $result = Invoke-PrepareExtension `
                -ExtensionDirectory $script:extDir `
                -RepoRoot $script:tempDir `
                -Channel 'Stable' `
                -Collection $script:devCollectionPath `
                -DryRun

            $result.Success | Should -BeTrue
            $bakPath = Join-Path $script:extDir 'package.json.bak'
            Test-Path $bakPath | Should -BeTrue
            # Backup should contain the hve-core (flagship) generated content
            $bakJson = Get-Content -Path $bakPath -Raw | ConvertFrom-Json
            $bakJson.name | Should -Be 'hve-core'
        }

        It 'Resolves per-channel description into pinned package.json for non-default collection on PreRelease' {
            $perChannelCollectionPath = Join-Path $script:collectionsDir 'perchannel.collection.yml'
            @"
id: perchannel
name: hve-perchannel
displayName: HVE Core - Per Channel
description: Stable per-channel description
descriptions:
  - channel: prerelease
    text: 'Experimental: Per-channel preview description'
"@ | Set-Content -Path $perChannelCollectionPath

            $result = Invoke-PrepareExtension `
                -ExtensionDirectory $script:extDir `
                -RepoRoot $script:tempDir `
                -Channel 'PreRelease' `
                -Collection $perChannelCollectionPath `
                -DryRun

            $result.Success | Should -BeTrue
            $pinnedJson = Get-Content -Path (Join-Path $script:extDir 'package.json') -Raw | ConvertFrom-Json
            $pinnedJson.name | Should -Be 'hve-perchannel'
            $pinnedJson.description | Should -Be 'Experimental: Per-channel preview description'
        }
    }

    Context 'Collection maturity gating' {
        BeforeAll {
            # Deprecated collection in collections/ directory for generation
            $script:deprecatedCollectionPath = Join-Path $script:collectionsDir 'deprecated-coll.collection.yml'
            @"
id: deprecated-coll
name: deprecated-ext
displayName: Deprecated Collection
description: Deprecated collection for testing
maturity: deprecated
"@ | Set-Content -Path $script:deprecatedCollectionPath

            # Experimental collection in collections/ directory for generation
            $script:experimentalCollectionPath = Join-Path $script:collectionsDir 'experimental-coll.collection.yml'
            @"
id: experimental-coll
name: experimental-ext
displayName: Experimental Collection
description: Experimental collection for testing
maturity: experimental
"@ | Set-Content -Path $script:experimentalCollectionPath
        }

        It 'Returns early success for deprecated collection on Stable channel' {
            $result = Invoke-PrepareExtension `
                -ExtensionDirectory $script:extDir `
                -RepoRoot $script:tempDir `
                -Channel 'Stable' `
                -Collection $script:deprecatedCollectionPath `
                -DryRun

            $result.Success | Should -BeTrue
            $result.AgentCount | Should -Be 0
        }

        It 'Returns early success for deprecated collection on PreRelease channel' {
            $result = Invoke-PrepareExtension `
                -ExtensionDirectory $script:extDir `
                -RepoRoot $script:tempDir `
                -Channel 'PreRelease' `
                -Collection $script:deprecatedCollectionPath `
                -DryRun

            $result.Success | Should -BeTrue
            $result.AgentCount | Should -Be 0
        }

        It 'Returns early success for experimental collection on Stable channel' {
            $result = Invoke-PrepareExtension `
                -ExtensionDirectory $script:extDir `
                -RepoRoot $script:tempDir `
                -Channel 'Stable' `
                -Collection $script:experimentalCollectionPath `
                -DryRun

            $result.Success | Should -BeTrue
            $result.AgentCount | Should -Be 0
        }

        It 'Processes experimental collection on PreRelease channel' {
            $result = Invoke-PrepareExtension `
                -ExtensionDirectory $script:extDir `
                -RepoRoot $script:tempDir `
                -Channel 'PreRelease' `
                -Collection $script:experimentalCollectionPath `
                -DryRun

            $result.Success | Should -BeTrue
            $result.ErrorMessage | Should -Be ''
        }
    }

    Context 'Exclusion reporting and skill filtering' {
        BeforeAll {
            # Add root-level repo-specific files to trigger exclusion messages
            @'
---
description: "Root-level agent"
---
'@ | Set-Content -Path (Join-Path $script:agentsDir 'root-agent.agent.md')

            @'
---
description: "Root-level prompt"
---
'@ | Set-Content -Path (Join-Path $script:promptsDir 'root-prompt.prompt.md')

            @'
---
description: "Root-level instruction"
applyTo: "**/*.ps1"
---
'@ | Set-Content -Path (Join-Path $script:instrDir 'root-instr.instructions.md')

            # Add skills directory with skill in subdirectory
            $script:skillsDir = Join-Path $script:ghDir 'skills'
            $script:skillSubDir = Join-Path $script:skillsDir 'test-collection/test-skill'
            New-Item -ItemType Directory -Path $script:skillSubDir -Force | Out-Null
            @'
---
name: test-skill
description: "Test skill"
---
# Skill
'@ | Set-Content -Path (Join-Path $script:skillSubDir 'SKILL.md')

            # Add root-level skill
            $rootSkillDir = Join-Path $script:skillsDir 'root-skill'
            New-Item -ItemType Directory -Path $rootSkillDir -Force | Out-Null
            @'
---
name: root-skill
description: "Root-level skill"
---
# Root Skill
'@ | Set-Content -Path (Join-Path $rootSkillDir 'SKILL.md')

            # Restore valid package.json and template
            @'
{
    "name": "hve-core",
    "displayName": "HVE Core",
    "version": "1.2.3",
    "description": "Test extension",
    "publisher": "test-pub",
    "engines": { "vscode": "^1.80.0" },
    "contributes": {}
}
'@ | Set-Content -Path (Join-Path $script:templatesDir 'package.template.json')
        }

        It 'Reports skipped items when root-level repo-specific files exist' {
            $result = Invoke-PrepareExtension `
                -ExtensionDirectory $script:extDir `
                -RepoRoot $script:tempDir `
                -Channel 'Stable' `
                -DryRun

            $result.Success | Should -BeTrue
            $result.AgentCount | Should -BeGreaterOrEqual 1
            $result.SkillCount | Should -BeGreaterOrEqual 1
        }

        It 'Filters skills by collection membership' {
            $collectionPath = Join-Path $script:tempDir 'skill-filter.collection.yml'
            @"
id: hve-core
name: HVE Core
displayName: HVE Core
description: Skill filtering test
items:
  - kind: agent
    path: .github/agents/test-collection/test.agent.md
    maturity: stable
  - kind: skill
    path: .github/skills/test-collection/test-skill/
    maturity: stable
"@ | Set-Content -Path $collectionPath

            $result = Invoke-PrepareExtension `
                -ExtensionDirectory $script:extDir `
                -RepoRoot $script:tempDir `
                -Channel 'Stable' `
                -Collection $collectionPath `
                -DryRun

            $result.Success | Should -BeTrue
            $result.SkillCount | Should -Be 1
        }

        It 'Shows DryRun message when changelog provided with DryRun' {
            $changelogPath = Join-Path $script:tempDir 'CHANGELOG-DRYRUN.md'
            '# DryRun Changelog' | Set-Content -Path $changelogPath

            $result = Invoke-PrepareExtension `
                -ExtensionDirectory $script:extDir `
                -RepoRoot $script:tempDir `
                -Channel 'Stable' `
                -ChangelogPath $changelogPath `
                -DryRun

            $result.Success | Should -BeTrue
        }
    }

    Context 'Per-channel description pin' {
        BeforeAll {
            $script:pinCollectionPath = Join-Path $script:collectionsDir 'pin-target.collection.yml'
            @"
id: pin-target
name: pin-target
displayName: HVE Core - Pin Target
description: Pin target stable description
descriptions:
  - channel: prerelease
    text: 'Experimental: Pin target preview description'
"@ | Set-Content -Path $script:pinCollectionPath
        }

        AfterEach {
            $bakPath = Join-Path $script:extDir 'package.json.bak'
            if (Test-Path $bakPath) {
                Remove-Item -Path $bakPath -Force
            }
        }

        It 'Pins extension/package.json description to the targeted PreRelease value' {
            $result = Invoke-PrepareExtension `
                -ExtensionDirectory $script:extDir `
                -RepoRoot $script:tempDir `
                -Channel 'PreRelease' `
                -Collection $script:pinCollectionPath `
                -DryRun:$false

            $result.Success | Should -BeTrue

            $pkgJson = Get-Content -Path (Join-Path $script:extDir 'package.json') -Raw | ConvertFrom-Json
            $pkgJson.description | Should -Be 'Experimental: Pin target preview description'
            $pkgJson.name | Should -Be 'hve-pin-target'
        }
    }
}

#region Additional Coverage Tests

Describe 'Get-ArtifactDescription' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Returns empty string when file does not exist' {
        $result = Get-ArtifactDescription -FilePath (Join-Path $script:tempDir 'nonexistent.md')
        $result | Should -Be ''
    }

    It 'Returns empty string when file has no frontmatter' {
        $path = Join-Path $script:tempDir 'no-frontmatter.md'
        '# Just a heading' | Set-Content -Path $path
        $result = Get-ArtifactDescription -FilePath $path
        $result | Should -Be ''
    }

    It 'Returns empty string when frontmatter has no description' {
        $path = Join-Path $script:tempDir 'no-desc.md'
        @"
---
applyTo: "**/*.ps1"
---
# No description
"@ | Set-Content -Path $path
        $result = Get-ArtifactDescription -FilePath $path
        $result | Should -Be ''
    }

    It 'Returns description from valid frontmatter' {
        $path = Join-Path $script:tempDir 'valid.md'
        @"
---
description: "My artifact description"
---
# Valid
"@ | Set-Content -Path $path
        $result = Get-ArtifactDescription -FilePath $path
        $result | Should -Be 'My artifact description'
    }

    It 'Strips branding suffix from description' {
        $path = Join-Path $script:tempDir 'branded.md'
        @"
---
description: "Some tool - Brought to you by microsoft/hve-core"
---
# Branded
"@ | Set-Content -Path $path
        $result = Get-ArtifactDescription -FilePath $path
        $result | Should -Be 'Some tool'
    }

    It 'Returns empty string when frontmatter YAML is invalid' {
        $path = Join-Path $script:tempDir 'bad-yaml.md'
        @"
---
description: [invalid: yaml: :
---
# Bad
"@ | Set-Content -Path $path
        $result = Get-ArtifactDescription -FilePath $path
        $result | Should -Be ''
    }
}

Describe 'Get-CollectionArtifactKey - default branch' {
    It 'Handles unknown kind with matching suffix' {
        $result = Get-CollectionArtifactKey -Kind 'custom' -Path '.github/custom/my-file.custom.md'
        $result | Should -Be 'my-file'
    }

    It 'Handles unknown kind with .md extension but no matching suffix' {
        $result = Get-CollectionArtifactKey -Kind 'custom' -Path '.github/custom/readme.md'
        $result | Should -Be 'readme'
    }

    It 'Handles unknown kind with non-md file' {
        $result = Get-CollectionArtifactKey -Kind 'custom' -Path '.github/custom/config.json'
        $result | Should -Be 'config.json'
    }
}

Describe 'Test-TemplateConsistency' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Returns inconsistent when template file not found' {
        $manifest = @{ name = 'test'; displayName = 'Test'; description = 'Desc' }
        $result = Test-TemplateConsistency -TemplatePath (Join-Path $script:tempDir 'nonexistent.json') -CollectionManifest $manifest
        $result.IsConsistent | Should -BeFalse
        $result.Mismatches.Count | Should -Be 1
        $result.Mismatches[0].Field | Should -Be 'file'
        $result.Mismatches[0].Message | Should -Match 'not found'
    }

    It 'Returns inconsistent when template is invalid JSON' {
        $badPath = Join-Path $script:tempDir 'bad-template.json'
        'not valid json {{{' | Set-Content -Path $badPath
        $manifest = @{ name = 'test' }
        $result = Test-TemplateConsistency -TemplatePath $badPath -CollectionManifest $manifest
        $result.IsConsistent | Should -BeFalse
        $result.Mismatches[0].Message | Should -Match 'Failed to parse'
    }

    It 'Returns consistent when fields match' {
        $path = Join-Path $script:tempDir 'matching.json'
        @{ name = 'hve-rpi'; displayName = 'HVE RPI'; description = 'RPI tools' } | ConvertTo-Json | Set-Content -Path $path
        $manifest = @{ name = 'hve-rpi'; displayName = 'HVE RPI'; description = 'RPI tools' }
        $result = Test-TemplateConsistency -TemplatePath $path -CollectionManifest $manifest
        $result.IsConsistent | Should -BeTrue
        $result.Mismatches.Count | Should -Be 0
    }

    It 'Reports mismatches for diverging fields' {
        $path = Join-Path $script:tempDir 'diverging.json'
        @{ name = 'old-name'; displayName = 'Old Name'; description = 'Old desc' } | ConvertTo-Json | Set-Content -Path $path
        $manifest = @{ name = 'new-name'; displayName = 'New Name'; description = 'New desc' }
        $result = Test-TemplateConsistency -TemplatePath $path -CollectionManifest $manifest
        $result.IsConsistent | Should -BeFalse
        $result.Mismatches.Count | Should -Be 3
    }

    It 'Skips comparison when field missing in either side' {
        $path = Join-Path $script:tempDir 'partial.json'
        @{ name = 'test' } | ConvertTo-Json | Set-Content -Path $path
        $manifest = @{ displayName = 'Test Display' }
        $result = Test-TemplateConsistency -TemplatePath $path -CollectionManifest $manifest
        $result.IsConsistent | Should -BeTrue
    }
}

Describe 'Update-PackageJsonContributes - existing contributes fields' {
    It 'Updates existing chatAgents field via else branch' {
        $packageJson = [PSCustomObject]@{
            name        = 'test-extension'
            contributes = [PSCustomObject]@{
                chatAgents       = @(@{ path = './old.agent.md' })
                chatPromptFiles  = @(@{ path = './old.prompt.md' })
                chatInstructions = @(@{ path = './old.instr.md' })
                chatSkills       = @(@{ path = './old.skill' })
            }
        }
        $agents = @(@{ name = 'new-agent'; path = './.github/agents/new.agent.md' })
        $prompts = @(@{ name = 'new-prompt'; path = './.github/prompts/new.prompt.md' })
        $instructions = @(@{ name = 'new-instr'; path = './.github/instructions/new.instructions.md' })
        $skills = @(@{ name = 'new-skill'; path = './.github/skills/new-skill' })

        $result = Update-PackageJsonContributes -PackageJson $packageJson `
            -ChatAgents $agents `
            -ChatPromptFiles $prompts `
            -ChatInstructions $instructions `
            -ChatSkills $skills

        $result.contributes.chatAgents[0].path | Should -Be './.github/agents/new.agent.md'
        $result.contributes.chatPromptFiles[0].path | Should -Be './.github/prompts/new.prompt.md'
        $result.contributes.chatInstructions[0].path | Should -Be './.github/instructions/new.instructions.md'
        $result.contributes.chatSkills[0].path | Should -Be './.github/skills/new-skill'
    }

    It 'Adds contributes section when missing' {
        $packageJson = [PSCustomObject]@{
            name = 'bare-extension'
        }

        $result = Update-PackageJsonContributes -PackageJson $packageJson `
            -ChatAgents @() `
            -ChatPromptFiles @() `
            -ChatInstructions @() `
            -ChatSkills @()

        $result.contributes | Should -Not -BeNullOrEmpty
    }
}

Describe 'Resolve-HandoffDependencies - additional cases' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        $script:agentsDir = Join-Path $script:tempDir 'agents'
        New-Item -ItemType Directory -Path $script:agentsDir -Force | Out-Null

        # Agent with string-format handoffs
        @'
---
description: "String handoff agent"
handoffs:
  - string-target
---
'@ | Set-Content -Path (Join-Path $script:agentsDir 'string-handoff.agent.md')

        @'
---
description: "String target"
---
'@ | Set-Content -Path (Join-Path $script:agentsDir 'string-target.agent.md')

        # Agent with broken YAML in handoffs section
        @'
---
description: "Broken YAML agent"
handoffs:
  - label: [invalid: yaml: :
---
'@ | Set-Content -Path (Join-Path $script:agentsDir 'broken-yaml.agent.md')
    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Resolves string-format handoffs' {
        $result = Resolve-HandoffDependencies -SeedAgents @('string-handoff') -AgentsDir $script:agentsDir
        $result | Should -Contain 'string-handoff'
        $result | Should -Contain 'string-target'
    }

    It 'Throws when handoff target file is missing' {
        { Resolve-HandoffDependencies -SeedAgents @('missing-agent') -AgentsDir $script:agentsDir } |
            Should -Throw '*Handoff target agent file not found: missing-agent*'
    }

    It 'Warns and continues when handoff YAML is malformed' {
        $result = Resolve-HandoffDependencies -SeedAgents @('broken-yaml') -AgentsDir $script:agentsDir 3>&1
        $warnings = @($result | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })
        $warnings.Count | Should -BeGreaterOrEqual 1
        $agentNames = @($result | Where-Object { $_ -is [string] })
        $agentNames | Should -Contain 'broken-yaml'
    }
}

Describe 'Resolve-HandoffDependencies - display name resolution' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        $script:agentsDir = Join-Path $script:tempDir 'agents'
        New-Item -ItemType Directory -Path $script:agentsDir -Force | Out-Null

        # Agent whose handoffs use display names instead of file stems
        @'
---
name: Parent Agent
description: "Agent with display-name handoffs"
handoffs:
  - label: "Go to child"
    agent: Child Agent
    prompt: Continue
---
'@ | Set-Content -Path (Join-Path $script:agentsDir 'parent-agent.agent.md')

        @'
---
name: Child Agent
description: "Child with display name"
---
'@ | Set-Content -Path (Join-Path $script:agentsDir 'child-agent.agent.md')

        # Chain using display names: Planner -> Implementor (mimics real hve-core agents)
        @'
---
name: Task Planner
description: "Planner agent"
handoffs:
  - label: "Implement"
    agent: Task Implementor
---
'@ | Set-Content -Path (Join-Path $script:agentsDir 'task-planner.agent.md')

        @'
---
name: Task Implementor
description: "Implementor agent"
handoffs:
  - label: "Review"
    agent: Task Planner
---
'@ | Set-Content -Path (Join-Path $script:agentsDir 'task-implementor.agent.md')

        # Suffixed-name fixtures: target whose source name carries an '(exp)' suffix.
        @'
---
name: Foo (exp)
description: "Suffixed target"
---
'@ | Set-Content -Path (Join-Path $script:agentsDir 'foo.agent.md')

        @'
---
name: Suffix Referrer
description: "Agent referencing the suffixed target by suffixed name"
handoffs:
  - label: "To Foo"
    agent: Foo (exp)
---
'@ | Set-Content -Path (Join-Path $script:agentsDir 'suffix-referrer.agent.md')

        @'
---
name: Base Name Referrer
description: "Agent referencing the suffixed target by base name (broken)"
handoffs:
  - label: "To Foo (broken)"
    agent: Foo
---
'@ | Set-Content -Path (Join-Path $script:agentsDir 'base-name-referrer.agent.md')
    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Resolves handoff targets specified by display name' {
        $result = Resolve-HandoffDependencies -SeedAgents @('parent-agent') -AgentsDir $script:agentsDir
        $result | Should -Contain 'parent-agent'
        $result | Should -Contain 'child-agent'
    }

    It 'Resolves circular display-name handoff chains' {
        $result = Resolve-HandoffDependencies -SeedAgents @('task-planner') -AgentsDir $script:agentsDir
        $result | Should -Contain 'task-planner'
        $result | Should -Contain 'task-implementor'
    }

    It 'Resolves a suffixed-name reference against a suffixed target' {
        $result = Resolve-HandoffDependencies -SeedAgents @('suffix-referrer') -AgentsDir $script:agentsDir
        $result | Should -Contain 'suffix-referrer'
        $result | Should -Contain 'foo'
    }

    It 'Throws when reference base-name does not match suffixed target' {
        { Resolve-HandoffDependencies -SeedAgents @('base-name-referrer') -AgentsDir $script:agentsDir } |
            Should -Throw "*Reference uses base name; the target's source 'name:' is 'Foo (exp)'*"
    }
}

Describe 'Get-DiscoveredPrompts - maturity filtering' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        $script:promptsDir = Join-Path $script:tempDir 'prompts'
        $script:promptsSubDir = Join-Path $script:promptsDir 'test-collection'
        $script:ghDir = Join-Path $script:tempDir '.github'
        New-Item -ItemType Directory -Path $script:promptsSubDir -Force | Out-Null
        New-Item -ItemType Directory -Path $script:ghDir -Force | Out-Null

        @'
---
description: "Stable prompt"
---
'@ | Set-Content -Path (Join-Path $script:promptsSubDir 'stable.prompt.md')
    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Skips prompts when none match allowed maturities' {
        $result = Get-DiscoveredPrompts -PromptsDir $script:promptsDir -GitHubDir $script:ghDir -AllowedMaturities @('experimental')
        $result.Prompts.Count | Should -Be 0
        $result.Skipped.Count | Should -Be 1
        $result.Skipped[0].Reason | Should -Match 'maturity'
    }
}

Describe 'Get-DiscoveredInstructions - maturity filtering' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        $script:instrDir = Join-Path $script:tempDir 'instructions'
        $script:instrSubDir = Join-Path $script:instrDir 'test-collection'
        $script:ghDir = Join-Path $script:tempDir '.github'
        New-Item -ItemType Directory -Path $script:instrSubDir -Force | Out-Null
        New-Item -ItemType Directory -Path $script:ghDir -Force | Out-Null

        @'
---
description: "Test instruction"
applyTo: "**/*.ps1"
---
'@ | Set-Content -Path (Join-Path $script:instrSubDir 'test.instructions.md')
    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Skips instructions when none match allowed maturities' {
        $result = Get-DiscoveredInstructions -InstructionsDir $script:instrDir -GitHubDir $script:ghDir -AllowedMaturities @('experimental')
        $result.Instructions.Count | Should -Be 0
        $result.Skipped.Count | Should -Be 1
        $result.Skipped[0].Reason | Should -Match 'maturity'
    }
}

Describe 'Invoke-PrepareExtension - error cases' {
    BeforeAll {
        $script:tempDir = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null

        $script:extDir = Join-Path $script:tempDir 'extension'
        New-Item -ItemType Directory -Path $script:extDir -Force | Out-Null

        $script:templatesDir = Join-Path $script:extDir 'templates'
        New-Item -ItemType Directory -Path $script:templatesDir -Force | Out-Null
        @'
{
    "name": "hve-core",
    "displayName": "HVE Core",
    "version": "1.0.0",
    "description": "Test extension",
    "publisher": "test-pub",
    "engines": { "vscode": "^1.80.0" },
    "contributes": {}
}
'@ | Set-Content -Path (Join-Path $script:templatesDir 'package.template.json')

        $script:collectionsDir = Join-Path $script:tempDir 'collections'
        New-Item -ItemType Directory -Path $script:collectionsDir -Force | Out-Null
        @"
id: hve-core
name: HVE Core
displayName: HVE Core
description: Test
"@ | Set-Content -Path (Join-Path $script:collectionsDir 'hve-core.collection.yml')

        # Central manifest: generation projects collections from this file.
        @"
schemaVersion: `"1.0`"
collections:
  hve-core:
    name: HVE Core
    intro: HVE Core flagship collection.
    descriptions:
      - channel: stable
        text: Test
"@ | Set-Content -Path (Join-Path $script:collectionsDir 'core-manifest.yml')

        # README template (required for README generation); reuse the real template.
        $readmeTemplateSource = Join-Path (Get-Item "$PSScriptRoot/../../..").FullName 'extension/templates/README.template.md'
        Copy-Item -Path $readmeTemplateSource -Destination (Join-Path $script:templatesDir 'README.template.md') -Force

        $script:ghDir = Join-Path $script:tempDir '.github'
        New-Item -ItemType Directory -Path (Join-Path $script:ghDir 'agents') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:ghDir 'prompts') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:ghDir 'instructions') -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Fails when package.json has invalid JSON' {
        # Write invalid JSON and mock generation to preserve it
        $badPkgPath = Join-Path $script:extDir 'package.json'
        'NOT VALID JSON' | Set-Content -Path $badPkgPath

        Mock Invoke-ExtensionCollectionsGeneration { return @($badPkgPath) }

        $result = Invoke-PrepareExtension `
            -ExtensionDirectory $script:extDir `
            -RepoRoot $script:tempDir `
            -Channel 'Stable'

        $result.Success | Should -BeFalse
        $result.ErrorMessage | Should -Match 'Failed to parse package.json'
    }

    It 'Fails when package.json lacks version field' {
        $badPkgPath = Join-Path $script:extDir 'package.json'
        @{ name = 'test-no-version' } | ConvertTo-Json | Set-Content -Path $badPkgPath

        Mock Invoke-ExtensionCollectionsGeneration { return @($badPkgPath) }

        $result = Invoke-PrepareExtension `
            -ExtensionDirectory $script:extDir `
            -RepoRoot $script:tempDir `
            -Channel 'Stable'

        $result.Success | Should -BeFalse
        $result.ErrorMessage | Should -Match "does not contain a 'version' field"
    }

    It 'Fails when version format is invalid' {
        $badPkgPath = Join-Path $script:extDir 'package.json'
        @{ name = 'test'; version = 'not-semver' } | ConvertTo-Json | Set-Content -Path $badPkgPath

        Mock Invoke-ExtensionCollectionsGeneration { return @($badPkgPath) }

        $result = Invoke-PrepareExtension `
            -ExtensionDirectory $script:extDir `
            -RepoRoot $script:tempDir `
            -Channel 'Stable'

        $result.Success | Should -BeFalse
        $result.ErrorMessage | Should -Match 'Invalid version format'
    }

    It 'Warns when changelog path specified but file not found' {
        $validPkgPath = Join-Path $script:extDir 'package.json'
        @{ name = 'test'; version = '1.0.0'; contributes = @{} } | ConvertTo-Json -Depth 5 | Set-Content -Path $validPkgPath

        $result = Invoke-PrepareExtension `
            -ExtensionDirectory $script:extDir `
            -RepoRoot $script:tempDir `
            -Channel 'Stable' `
            -ChangelogPath (Join-Path $script:tempDir 'NONEXISTENT-CHANGELOG.md') 3>&1

        # Filter out the result hashtable from warnings
        $hashtableResult = $result | Where-Object { $_ -is [hashtable] }
        if ($hashtableResult) {
            $hashtableResult.Success | Should -BeTrue
        }
    }

    Context 'Collection with requires dependencies' {
        BeforeAll {
            $script:reqCollectionPath = Join-Path $script:tempDir 'requires-test.collection.yml'
            @"
id: hve-core
name: HVE Core
displayName: HVE Core
description: Requires test
items:
  - kind: agent
    path: .github/agents/test-collection/main.agent.md
    maturity: stable
    requires:
      prompts:
        - dep-prompt
  - kind: prompt
    path: .github/prompts/test-collection/dep-prompt.prompt.md
    maturity: stable
"@ | Set-Content -Path $script:reqCollectionPath

            # Create required agent and prompt files in subdirectories
            $reqAgentDir = Join-Path $script:ghDir 'agents/test-collection'
            $reqPromptDir = Join-Path $script:ghDir 'prompts/test-collection'
            New-Item -ItemType Directory -Path $reqAgentDir -Force | Out-Null
            New-Item -ItemType Directory -Path $reqPromptDir -Force | Out-Null
            @'
---
description: "Main agent"
---
'@ | Set-Content -Path (Join-Path $reqAgentDir 'main.agent.md')

            @'
---
description: "Dependent prompt"
---
'@ | Set-Content -Path (Join-Path $reqPromptDir 'dep-prompt.prompt.md')

            # Restore valid package.json
            $validPkgPath = Join-Path $script:extDir 'package.json'
            @{ name = 'hve-core'; version = '1.0.0'; contributes = @{} } | ConvertTo-Json -Depth 5 | Set-Content -Path $validPkgPath
        }

        It 'Resolves requires dependencies in collection' {
            $result = Invoke-PrepareExtension `
                -ExtensionDirectory $script:extDir `
                -RepoRoot $script:tempDir `
                -Channel 'Stable' `
                -Collection $script:reqCollectionPath `
                -DryRun

            $result.Success | Should -BeTrue
            $result.AgentCount | Should -BeGreaterOrEqual 1
            $result.PromptCount | Should -BeGreaterOrEqual 1
        }
    }
}

Describe 'Invoke-ExtensionCollectionsGeneration - core manifest errors' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())

        $collectionsDir = Join-Path $script:tempDir 'collections'
        $templatesDir = Join-Path $script:tempDir 'extension/templates'
        New-Item -ItemType Directory -Path $collectionsDir -Force | Out-Null
        New-Item -ItemType Directory -Path $templatesDir -Force | Out-Null

        @{
            name        = 'hve-core'
            displayName = 'HVE Core'
            version     = '1.0.0'
            description = 'default'
            publisher   = 'test-pub'
            engines     = @{ vscode = '^1.80.0' }
            contributes = @{}
        } | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $templatesDir 'package.template.json')
    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Throws when the core manifest is missing' {
        $collectionsDir = Join-Path $script:tempDir 'collections'
        Remove-Item -Path "$collectionsDir/*" -Force -ErrorAction SilentlyContinue

        { Invoke-ExtensionCollectionsGeneration -RepoRoot $script:tempDir } | Should -Throw '*does not exist*'
    }

    It 'Throws when the core manifest defines no collections metadata' {
        $collectionsDir = Join-Path $script:tempDir 'collections'
        Remove-Item -Path "$collectionsDir/*" -Force -ErrorAction SilentlyContinue
        @"
schemaVersion: `"1.0`"
"@ | Set-Content -Path (Join-Path $collectionsDir 'core-manifest.yml')

        { Invoke-ExtensionCollectionsGeneration -RepoRoot $script:tempDir } | Should -Throw '*does not define collections metadata*'
    }
}

Describe 'Invoke-ExtensionCollectionsGeneration - README generation' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())

        $collectionsDir = Join-Path $script:tempDir 'collections'
        $templatesDir = Join-Path $script:tempDir 'extension/templates'
        New-Item -ItemType Directory -Path $collectionsDir -Force | Out-Null
        New-Item -ItemType Directory -Path $templatesDir -Force | Out-Null

        # Package template
        @{
            name        = 'hve-core'
            displayName = 'HVE Core'
            version     = '1.0.0'
            description = 'default'
            publisher   = 'test-pub'
            engines     = @{ vscode = '^1.80.0' }
            contributes = @{}
        } | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $templatesDir 'package.template.json')

        # README template
        $repoRoot = (Get-Item "$PSScriptRoot/../../..").FullName
        $realTemplatePath = Join-Path $repoRoot 'extension/templates/README.template.md'
        if (Test-Path $realTemplatePath) {
            Copy-Item -Path $realTemplatePath -Destination (Join-Path $templatesDir 'README.template.md')
        }
        else {
            @"
# {{DISPLAY_NAME}}

> {{DESCRIPTION}}

{{BODY}}

{{ARTIFACTS}}

{{FULL_EDITION}}
"@ | Set-Content -Path (Join-Path $templatesDir 'README.template.md')
        }

        # Central manifest: README bodies are projected from each collection's intro.
        @"
schemaVersion: `"1.0`"
collections:
  hve-core:
    name: HVE Core
    intro: HVE Core body content.
  hve-core-all:
    name: All
    intro: HVE Core All body content.
  readme-test:
    name: README Test
    intro: Body content for readme test.
"@ | Set-Content -Path (Join-Path $collectionsDir 'core-manifest.yml')
    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Generates a README for a non-default collection from its intro' {
        $null = Invoke-ExtensionCollectionsGeneration -RepoRoot $script:tempDir
        $readmePath = Join-Path $script:tempDir 'extension/README.readme-test.md'
        Test-Path $readmePath | Should -BeTrue
        $content = Get-Content -Path $readmePath -Raw
        $content | Should -Match 'Body content for readme test'
    }

    It 'Generates README.md for hve-core collection' {
        $null = Invoke-ExtensionCollectionsGeneration -RepoRoot $script:tempDir
        $readmePath = Join-Path $script:tempDir 'extension/README.md'
        Test-Path $readmePath | Should -BeTrue
        $content = Get-Content -Path $readmePath -Raw
        $content | Should -Match 'HVE Core body content'
    }

    It 'Generates README for hve-core-all collection' {
        $null = Invoke-ExtensionCollectionsGeneration -RepoRoot $script:tempDir
        $readmePath = Join-Path $script:tempDir 'extension/README.hve-core-all.md'
        Test-Path $readmePath | Should -BeTrue
        $content = Get-Content -Path $readmePath -Raw
        $content | Should -Match 'HVE Core All body content'
    }
}

#region Deprecated Path Exclusion Tests

Describe 'Get-DiscoveredAgents - deprecated path exclusion' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        $script:agentsDir = Join-Path $script:tempDir 'agents'
        New-Item -ItemType Directory -Path $script:agentsDir -Force | Out-Null

        # Create active agent
        $activeDir = Join-Path $script:agentsDir 'rpi'
        New-Item -ItemType Directory -Path $activeDir -Force | Out-Null
        @'
---
description: "Active agent"
---
'@ | Set-Content -Path (Join-Path $activeDir 'active.agent.md')

        # Create deprecated agent
        $deprecatedDir = Join-Path $script:agentsDir 'deprecated'
        New-Item -ItemType Directory -Path $deprecatedDir -Force | Out-Null
        @'
---
description: "Deprecated agent"
---
'@ | Set-Content -Path (Join-Path $deprecatedDir 'old.agent.md')
    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Excludes agents in deprecated directory' {
        $result = Get-DiscoveredAgents -AgentsDir $script:agentsDir -AllowedMaturities @('stable') -ExcludedAgents @()
        $agentNames = $result.Agents | ForEach-Object { $_.name }
        $agentNames | Should -Contain 'active'
        $agentNames | Should -Not -Contain 'old'
    }
}

Describe 'Get-DiscoveredPrompts - deprecated path exclusion' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        $script:promptsDir = Join-Path $script:tempDir 'prompts'
        $script:ghDir = Join-Path $script:tempDir '.github'
        New-Item -ItemType Directory -Path $script:promptsDir -Force | Out-Null
        New-Item -ItemType Directory -Path $script:ghDir -Force | Out-Null

        # Create active prompt
        $activeDir = Join-Path $script:promptsDir 'rpi'
        New-Item -ItemType Directory -Path $activeDir -Force | Out-Null
        @'
---
description: "Active prompt"
---
'@ | Set-Content -Path (Join-Path $activeDir 'active.prompt.md')

        # Create deprecated prompt
        $deprecatedDir = Join-Path $script:promptsDir 'deprecated'
        New-Item -ItemType Directory -Path $deprecatedDir -Force | Out-Null
        @'
---
description: "Deprecated prompt"
---
'@ | Set-Content -Path (Join-Path $deprecatedDir 'old.prompt.md')
    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Excludes prompts in deprecated directory' {
        $result = Get-DiscoveredPrompts -PromptsDir $script:promptsDir -GitHubDir $script:ghDir -AllowedMaturities @('stable')
        $promptNames = $result.Prompts | ForEach-Object { $_.name }
        $promptNames | Should -Contain 'active'
        $promptNames | Should -Not -Contain 'old'
    }
}

Describe 'Get-DiscoveredInstructions - deprecated path exclusion' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        $script:instrDir = Join-Path $script:tempDir 'instructions'
        $script:ghDir = Join-Path $script:tempDir '.github'
        New-Item -ItemType Directory -Path $script:instrDir -Force | Out-Null
        New-Item -ItemType Directory -Path $script:ghDir -Force | Out-Null

        # Create active instruction
        $activeDir = Join-Path $script:instrDir 'rpi'
        New-Item -ItemType Directory -Path $activeDir -Force | Out-Null
        @'
---
description: "Active instruction"
applyTo: "**/*.ps1"
---
'@ | Set-Content -Path (Join-Path $activeDir 'active.instructions.md')

        # Create deprecated instruction
        $deprecatedDir = Join-Path $script:instrDir 'deprecated'
        New-Item -ItemType Directory -Path $deprecatedDir -Force | Out-Null
        @'
---
description: "Deprecated instruction"
applyTo: "**/*.ps1"
---
'@ | Set-Content -Path (Join-Path $deprecatedDir 'old.instructions.md')
    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Excludes instructions in deprecated directory' {
        $result = Get-DiscoveredInstructions -InstructionsDir $script:instrDir -GitHubDir $script:ghDir -AllowedMaturities @('stable')
        $instrNames = $result.Instructions | ForEach-Object { $_.name }
        $instrNames | Should -Contain 'active-instructions'
        $instrNames | Should -Not -Contain 'old-instructions'
    }
}

Describe 'Get-DiscoveredSkills - deprecated path exclusion' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        $script:skillsDir = Join-Path $script:tempDir 'skills'
        New-Item -ItemType Directory -Path $script:skillsDir -Force | Out-Null

        # Create active skill
        $activeSkillDir = Join-Path $script:skillsDir 'experimental/good-skill'
        New-Item -ItemType Directory -Path $activeSkillDir -Force | Out-Null
        @'
---
name: good-skill
description: "Active skill"
---
'@ | Set-Content -Path (Join-Path $activeSkillDir 'SKILL.md')

        # Create deprecated skill
        $deprecatedSkillDir = Join-Path $script:skillsDir 'deprecated/old-skill'
        New-Item -ItemType Directory -Path $deprecatedSkillDir -Force | Out-Null
        @'
---
name: old-skill
description: "Deprecated skill"
---
'@ | Set-Content -Path (Join-Path $deprecatedSkillDir 'SKILL.md')
    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Excludes skills in deprecated directory' {
        $result = Get-DiscoveredSkills -SkillsDir $script:skillsDir -AllowedMaturities @('stable')
        $skillNames = $result.Skills | ForEach-Object { $_.name }
        $skillNames | Should -Contain 'good-skill'
        $skillNames | Should -Not -Contain 'old-skill'
    }
}

#endregion Deprecated Path Exclusion Tests

#region Maturity Notice Tests

Describe 'New-CollectionReadme - maturity notice' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null

        # Create minimal README template with all tokens including MATURITY_NOTICE
        $templateContent = @"
# {{DISPLAY_NAME}}

> {{DESCRIPTION}}

{{MATURITY_NOTICE}}

{{BODY}}

## Included Artifacts

{{ARTIFACTS}}

{{FULL_EDITION}}
"@
        $script:templatePath = Join-Path $script:tempDir 'README.template.md'
        Set-Content -Path $script:templatePath -Value $templateContent

        # Create collection body markdown
        $script:bodyPath = Join-Path $script:tempDir 'test.collection.md'
        Set-Content -Path $script:bodyPath -Value 'Collection body content.'
    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Includes experimental notice for experimental collection' {
        $collection = @{
            id          = 'test-exp'
            name        = 'Test Experimental'
            description = 'An experimental collection'
            maturity    = 'experimental'
            items       = @()
        }
        $outputPath = Join-Path $script:tempDir 'README-exp.md'
        New-CollectionReadme -Collection $collection -CollectionMdPath $script:bodyPath `
            -TemplatePath $script:templatePath -RepoRoot $script:tempDir -OutputPath $outputPath

        $content = Get-Content -Path $outputPath -Raw
        $content | Should -Match '\u26A0' # warning sign emoji
        $content | Should -Match 'Pre-Release channel'
    }

    It 'Has no notice for collection without maturity field' {
        $collection = @{
            id          = 'test-default'
            name        = 'Test Default'
            description = 'A default collection'
            items       = @()
        }
        $outputPath = Join-Path $script:tempDir 'README-default.md'
        New-CollectionReadme -Collection $collection -CollectionMdPath $script:bodyPath `
            -TemplatePath $script:templatePath -RepoRoot $script:tempDir -OutputPath $outputPath

        $content = Get-Content -Path $outputPath -Raw
        $content | Should -Not -Match '\u26A0'
    }

    It 'Has no notice for explicit stable maturity' {
        $collection = @{
            id          = 'test-stable'
            name        = 'Test Stable'
            description = 'A stable collection'
            maturity    = 'stable'
            items       = @()
        }
        $outputPath = Join-Path $script:tempDir 'README-stable.md'
        New-CollectionReadme -Collection $collection -CollectionMdPath $script:bodyPath `
            -TemplatePath $script:templatePath -RepoRoot $script:tempDir -OutputPath $outputPath

        $content = Get-Content -Path $outputPath -Raw
        $content | Should -Not -Match '\u26A0'
    }
}

#endregion Maturity Notice Tests

#region Split-CollectionMdByMarkers Tests

Describe 'Split-CollectionMdByMarkers' {
    It 'Returns HasMarkers false for content without markers' {
        $result = Split-CollectionMdByMarkers -Content 'Hello world'
        $result.HasMarkers | Should -BeFalse
        $result.Intro | Should -Be 'Hello world'
        $result.Footer | Should -Be ''
    }

    It 'Throws for empty string input' {
        { Split-CollectionMdByMarkers -Content '' } | Should -Throw
    }

    It 'Parses intro and footer around markers' {
        $content = "Intro text`n`n<!-- BEGIN AUTO-GENERATED ARTIFACTS -->`n`nGenerated`n`n<!-- END AUTO-GENERATED ARTIFACTS -->`n`nFooter text"
        $result = Split-CollectionMdByMarkers -Content $content
        $result.HasMarkers | Should -BeTrue
        $result.Intro | Should -Be 'Intro text'
        $result.Footer | Should -Be 'Footer text'
    }

    It 'Returns HasMarkers false when only BEGIN marker is present' {
        $content = "Intro`n<!-- BEGIN AUTO-GENERATED ARTIFACTS -->`nSome content"
        $result = Split-CollectionMdByMarkers -Content $content
        $result.HasMarkers | Should -BeFalse
    }

    It 'Returns HasMarkers false when END marker appears before BEGIN' {
        $content = "<!-- END AUTO-GENERATED ARTIFACTS -->`n<!-- BEGIN AUTO-GENERATED ARTIFACTS -->"
        $result = Split-CollectionMdByMarkers -Content $content
        $result.HasMarkers | Should -BeFalse
    }

    It 'Returns HasMarkers false for duplicate BEGIN markers without END' {
        $content = "<!-- BEGIN AUTO-GENERATED ARTIFACTS -->`n<!-- BEGIN AUTO-GENERATED ARTIFACTS -->`nContent"
        $result = Split-CollectionMdByMarkers -Content $content
        $result.HasMarkers | Should -BeFalse
    }

    It 'Does not include an Existing key in the result' {
        $noMarkers = Split-CollectionMdByMarkers -Content 'plain'
        $noMarkers.Keys | Should -Not -Contain 'Existing'

        $withMarkers = Split-CollectionMdByMarkers -Content "Intro`n<!-- BEGIN AUTO-GENERATED ARTIFACTS -->`n`n<!-- END AUTO-GENERATED ARTIFACTS -->"
        $withMarkers.Keys | Should -Not -Contain 'Existing'
    }
}

#endregion Split-CollectionMdByMarkers Tests

#endregion Additional Coverage Tests
