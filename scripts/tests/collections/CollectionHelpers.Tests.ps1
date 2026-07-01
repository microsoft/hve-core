#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    Import-Module $PSScriptRoot/../../collections/Modules/CollectionHelpers.psm1 -Force
}

Describe 'Get-ArtifactFiles - repo-specific path exclusion' {
    BeforeAll {
        $script:repoRoot = Join-Path $TestDrive 'repo'
        $ghDir = Join-Path $script:repoRoot '.github'

        # Create root-level repo-specific agent (should be excluded)
        $agentsDir = Join-Path $ghDir 'agents'
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
        Set-Content -Path (Join-Path $agentsDir 'internal.agent.md') -Value '---\ndescription: repo-specific\n---'

        # Create collection-scoped agent in subdirectory (should be included)
        $hveCoreAgentsDir = Join-Path $agentsDir 'hve-core'
        New-Item -ItemType Directory -Path $hveCoreAgentsDir -Force | Out-Null
        Set-Content -Path (Join-Path $hveCoreAgentsDir 'rpi-agent.agent.md') -Value '---\ndescription: distributable\n---'

        # Create root-level repo-specific instruction (should be excluded)
        $instrDir = Join-Path $ghDir 'instructions'
        New-Item -ItemType Directory -Path $instrDir -Force | Out-Null
        Set-Content -Path (Join-Path $instrDir 'workflows.instructions.md') -Value '---\ndescription: repo-specific\n---'

        # Create collection-scoped instruction in subdirectory (should be included)
        $sharedInstrDir = Join-Path $instrDir 'shared'
        New-Item -ItemType Directory -Path $sharedInstrDir -Force | Out-Null
        Set-Content -Path (Join-Path $sharedInstrDir 'hve-core-location.instructions.md') -Value '---\ndescription: shared\n---'

        # Create root-level repo-specific prompt (should be excluded)
        $promptsDir = Join-Path $ghDir 'prompts'
        New-Item -ItemType Directory -Path $promptsDir -Force | Out-Null
        Set-Content -Path (Join-Path $promptsDir 'internal.prompt.md') -Value '---\ndescription: repo-specific prompt\n---'

        # Create collection-scoped prompt in subdirectory (should be included)
        $hveCorePromptsDir = Join-Path $promptsDir 'hve-core'
        New-Item -ItemType Directory -Path $hveCorePromptsDir -Force | Out-Null
        Set-Content -Path (Join-Path $hveCorePromptsDir 'task-plan.prompt.md') -Value '---\ndescription: distributable prompt\n---'

        # Create collection-scoped hook manifest in subdirectory (should be included)
        $sharedHooksDir = Join-Path $ghDir 'hooks/shared'
        New-Item -ItemType Directory -Path $sharedHooksDir -Force | Out-Null
        Set-Content -Path (Join-Path $sharedHooksDir 'telemetry.json') -Value '{ "version": 1 }'

        # Create hook implementation file one level deeper (should NOT be treated as a manifest)
        $hookImplDir = Join-Path $sharedHooksDir 'telemetry'
        New-Item -ItemType Directory -Path $hookImplDir -Force | Out-Null
        Set-Content -Path (Join-Path $hookImplDir 'config.json') -Value '{ "internal": true }'

        # Create flat hook manifest directly under .github/hooks (should be excluded)
        $hooksRootDir = Join-Path $ghDir 'hooks'
        Set-Content -Path (Join-Path $hooksRootDir 'orphan.json') -Value '{ "version": 1 }'
    }

    It 'Excludes root-level repo-specific instructions' {
        $items = Get-ArtifactFiles -RepoRoot $script:repoRoot
        $paths = $items | ForEach-Object { $_.path }
        $paths | Should -Not -Contain '.github/instructions/workflows.instructions.md'
    }

    It 'Excludes root-level repo-specific agents' {
        $items = Get-ArtifactFiles -RepoRoot $script:repoRoot
        $paths = $items | ForEach-Object { $_.path }
        $paths | Should -Not -Contain '.github/agents/internal.agent.md'
    }

    It 'Excludes root-level repo-specific prompts' {
        $items = Get-ArtifactFiles -RepoRoot $script:repoRoot
        $paths = $items | ForEach-Object { $_.path }
        $paths | Should -Not -Contain '.github/prompts/internal.prompt.md'
    }

    It 'Includes collection-scoped agents in subdirectories' {
        $items = Get-ArtifactFiles -RepoRoot $script:repoRoot
        $paths = $items | ForEach-Object { $_.path }
        $paths | Should -Contain '.github/agents/hve-core/rpi-agent.agent.md'
    }

    It 'Includes collection-scoped instructions in subdirectories' {
        $items = Get-ArtifactFiles -RepoRoot $script:repoRoot
        $paths = $items | ForEach-Object { $_.path }
        $paths | Should -Contain '.github/instructions/shared/hve-core-location.instructions.md'
    }

    It 'Includes collection-scoped prompts in subdirectories' {
        $items = Get-ArtifactFiles -RepoRoot $script:repoRoot
        $paths = $items | ForEach-Object { $_.path }
        $paths | Should -Contain '.github/prompts/hve-core/task-plan.prompt.md'
    }

    It 'Includes collection-scoped hook manifests in subdirectories' {
        $items = Get-ArtifactFiles -RepoRoot $script:repoRoot
        $hookItem = $items | Where-Object { $_.path -eq '.github/hooks/shared/telemetry.json' }
        $hookItem | Should -Not -BeNullOrEmpty
        $hookItem.kind | Should -Be 'hook'
    }

    It 'Excludes hook implementation files nested under the manifest folder' {
        $items = Get-ArtifactFiles -RepoRoot $script:repoRoot
        $paths = $items | ForEach-Object { $_.path }
        $paths | Should -Not -Contain '.github/hooks/shared/telemetry/config.json'
    }

    It 'Excludes flat hook manifests directly under .github/hooks' {
        $items = Get-ArtifactFiles -RepoRoot $script:repoRoot
        $paths = $items | ForEach-Object { $_.path }
        $paths | Should -Not -Contain '.github/hooks/orphan.json'
    }
}

Describe 'Get-ArtifactFiles - deprecated path exclusion' {
    BeforeAll {
        $script:repoRoot = Join-Path $TestDrive 'repo-deprecated'
        $ghDir = Join-Path $script:repoRoot '.github'

        # Create non-deprecated artifacts
        $agentsDir = Join-Path $ghDir 'agents/rpi'
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
        Set-Content -Path (Join-Path $agentsDir 'active.agent.md') -Value '---\ndescription: active\n---'

        $promptsDir = Join-Path $ghDir 'prompts/rpi'
        New-Item -ItemType Directory -Path $promptsDir -Force | Out-Null
        Set-Content -Path (Join-Path $promptsDir 'active.prompt.md') -Value '---\ndescription: active\n---'

        # Create deprecated artifacts
        $deprecatedAgentsDir = Join-Path $ghDir 'deprecated/agents'
        New-Item -ItemType Directory -Path $deprecatedAgentsDir -Force | Out-Null
        Set-Content -Path (Join-Path $deprecatedAgentsDir 'old.agent.md') -Value '---\ndescription: deprecated\n---'

        $deprecatedPromptsDir = Join-Path $ghDir 'deprecated/prompts'
        New-Item -ItemType Directory -Path $deprecatedPromptsDir -Force | Out-Null
        Set-Content -Path (Join-Path $deprecatedPromptsDir 'old.prompt.md') -Value '---\ndescription: deprecated\n---'

        $deprecatedInstrDir = Join-Path $ghDir 'deprecated/instructions'
        New-Item -ItemType Directory -Path $deprecatedInstrDir -Force | Out-Null
        Set-Content -Path (Join-Path $deprecatedInstrDir 'old.instructions.md') -Value '---\ndescription: deprecated\n---'

        # Create deprecated skill
        $deprecatedSkillDir = Join-Path $ghDir 'deprecated/skills/old-skill'
        New-Item -ItemType Directory -Path $deprecatedSkillDir -Force | Out-Null
        Set-Content -Path (Join-Path $deprecatedSkillDir 'SKILL.md') -Value '---\nname: old-skill\ndescription: deprecated\n---'

        # Create non-deprecated skill (under .github/skills/)
        $skillDir = Join-Path $ghDir 'skills/experimental/good-skill'
        New-Item -ItemType Directory -Path $skillDir -Force | Out-Null
        Set-Content -Path (Join-Path $skillDir 'SKILL.md') -Value '---\nname: good-skill\ndescription: active\n---'
    }

    It 'Excludes deprecated agent files' {
        $items = Get-ArtifactFiles -RepoRoot $script:repoRoot
        $paths = $items | ForEach-Object { $_.path }
        $paths | Should -Not -Contain '.github/deprecated/agents/old.agent.md'
    }

    It 'Excludes deprecated prompt files' {
        $items = Get-ArtifactFiles -RepoRoot $script:repoRoot
        $paths = $items | ForEach-Object { $_.path }
        $paths | Should -Not -Contain '.github/deprecated/prompts/old.prompt.md'
    }

    It 'Excludes deprecated instruction files' {
        $items = Get-ArtifactFiles -RepoRoot $script:repoRoot
        $paths = $items | ForEach-Object { $_.path }
        $paths | Should -Not -Contain '.github/deprecated/instructions/old.instructions.md'
    }

    It 'Excludes deprecated skill directories' {
        $items = Get-ArtifactFiles -RepoRoot $script:repoRoot
        $paths = $items | ForEach-Object { $_.path }
        $paths | Should -Not -Contain '.github/deprecated/skills/old-skill'
    }

    It 'Includes non-deprecated artifacts' {
        $items = Get-ArtifactFiles -RepoRoot $script:repoRoot
        $paths = $items | ForEach-Object { $_.path }
        $paths | Should -Contain '.github/agents/rpi/active.agent.md'
        $paths | Should -Contain '.github/prompts/rpi/active.prompt.md'
    }

    It 'Includes non-deprecated skills' {
        $items = Get-ArtifactFiles -RepoRoot $script:repoRoot
        $paths = $items | ForEach-Object { $_.path }
        $paths | Should -Contain '.github/skills/experimental/good-skill'
    }
}

Describe 'Test-DeprecatedPath' {
    It 'Returns true for path containing /deprecated/ segment' {
        Test-DeprecatedPath -Path '.github/deprecated/agents/old.agent.md' | Should -BeTrue
    }

    It 'Returns true for path with backslash deprecated segment' {
        Test-DeprecatedPath -Path '.github\deprecated\agents\old.agent.md' | Should -BeTrue
    }

    It 'Returns false for path without deprecated segment' {
        Test-DeprecatedPath -Path '.github/agents/rpi/active.agent.md' | Should -BeFalse
    }

    It 'Returns false when deprecated appears in filename only' {
        Test-DeprecatedPath -Path '.github/agents/deprecated-notes.agent.md' | Should -BeFalse
    }

    It 'Returns true for mid-path deprecated directory' {
        Test-DeprecatedPath -Path 'skills/deprecated/old-skill/SKILL.md' | Should -BeTrue
    }
}

Describe 'Test-HveCoreRepoSpecificPath' {
    It 'Returns true for root-level file (no subdirectory)' {
        Test-HveCoreRepoSpecificPath -RelativePath 'workflows.instructions.md' | Should -BeTrue
    }

    It 'Returns false for file in a subdirectory' {
        Test-HveCoreRepoSpecificPath -RelativePath 'hve-core/markdown.instructions.md' | Should -BeFalse
    }

    It 'Returns false for file in nested subdirectory' {
        Test-HveCoreRepoSpecificPath -RelativePath 'coding-standards/csharp/style.instructions.md' | Should -BeFalse
    }

    It 'Returns false for shared subdirectory path' {
        Test-HveCoreRepoSpecificPath -RelativePath 'shared/hve-core-location.instructions.md' | Should -BeFalse
    }
}

Describe 'Test-HveCoreRepoRelativePath' {
    It 'Returns true for root-level agent' {
        Test-HveCoreRepoRelativePath -Path '.github/agents/internal.agent.md' | Should -BeTrue
    }

    It 'Returns true for root-level instruction' {
        Test-HveCoreRepoRelativePath -Path '.github/instructions/workflows.instructions.md' | Should -BeTrue
    }

    It 'Returns true for root-level prompt' {
        Test-HveCoreRepoRelativePath -Path '.github/prompts/internal.prompt.md' | Should -BeTrue
    }

    It 'Returns false for non-.github path' {
        Test-HveCoreRepoRelativePath -Path 'scripts/plugins/foo.ps1' | Should -BeFalse
    }

    It 'Returns false for collection-scoped path in subdirectory' {
        Test-HveCoreRepoRelativePath -Path '.github/agents/hve-core/rpi-agent.agent.md' | Should -BeFalse
    }

    It 'Returns false for shared instruction in subdirectory' {
        Test-HveCoreRepoRelativePath -Path '.github/instructions/shared/hve-core-location.instructions.md' | Should -BeFalse
    }

    It 'Returns true for flat hook manifest directly under hooks' {
        Test-HveCoreRepoRelativePath -Path '.github/hooks/telemetry.json' | Should -BeTrue
    }

    It 'Returns false for collection-scoped hook manifest' {
        Test-HveCoreRepoRelativePath -Path '.github/hooks/shared/telemetry.json' | Should -BeFalse
    }

    It 'Returns false for path directly under .github (wrong nesting level)' {
        Test-HveCoreRepoRelativePath -Path '.github/foo.md' | Should -BeFalse
    }
}

Describe 'Resolve-CollectionItemMaturity' {
    It 'Returns stable for null' {
        $result = Resolve-CollectionItemMaturity -Maturity $null
        $result | Should -Be 'stable'
    }

    It 'Returns stable for empty string' {
        $result = Resolve-CollectionItemMaturity -Maturity ''
        $result | Should -Be 'stable'
    }

    It 'Returns stable for whitespace' {
        $result = Resolve-CollectionItemMaturity -Maturity '   '
        $result | Should -Be 'stable'
    }

    It 'Passes through preview' {
        $result = Resolve-CollectionItemMaturity -Maturity 'preview'
        $result | Should -Be 'preview'
    }

    It 'Passes through experimental' {
        $result = Resolve-CollectionItemMaturity -Maturity 'experimental'
        $result | Should -Be 'experimental'
    }
}

Describe 'Test-ArtifactDeprecated' {
    It 'Returns true for deprecated' {
        $result = Test-ArtifactDeprecated -Maturity 'deprecated'
        $result | Should -BeTrue
    }

    It 'Returns false for stable' {
        $result = Test-ArtifactDeprecated -Maturity 'stable'
        $result | Should -BeFalse
    }

    It 'Returns false for preview' {
        $result = Test-ArtifactDeprecated -Maturity 'preview'
        $result | Should -BeFalse
    }

    It 'Returns false for experimental' {
        $result = Test-ArtifactDeprecated -Maturity 'experimental'
        $result | Should -BeFalse
    }

    It 'Returns false for null (defaults to stable)' {
        $result = Test-ArtifactDeprecated -Maturity $null
        $result | Should -BeFalse
    }
}

Describe 'Get-ArtifactFrontmatter - YAML parse failure' {
    It 'Returns fallback when YAML frontmatter is malformed' {
        $testFile = Join-Path $TestDrive 'bad-yaml.agent.md'
        # Invalid YAML: tab characters and broken mapping
        Set-Content -Path $testFile -Value "---`n`t: [invalid: yaml`n---`nBody"
        $result = Get-ArtifactFrontmatter -FilePath $testFile -FallbackDescription 'fallback-desc'
        $result.description | Should -Be 'fallback-desc'
    }
}

Describe 'Update-HveCoreAllCollection - deprecated item exclusion' {
    BeforeAll {
        $script:repoRoot = Join-Path $TestDrive 'repo-deprecated-exclusion'
        $ghDir = Join-Path $script:repoRoot '.github'

        # Create two artifacts: one active, one that will be marked deprecated in the manifest
        $agentsDir = Join-Path $ghDir 'agents/test-collection'
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
        Set-Content -Path (Join-Path $agentsDir 'active.agent.md') -Value "---`ndescription: active agent`n---`nBody"
        Set-Content -Path (Join-Path $agentsDir 'old.agent.md') -Value "---`ndescription: old agent`n---`nBody"

        $collectionsDir = Join-Path $script:repoRoot 'collections'
        New-Item -ItemType Directory -Path $collectionsDir -Force | Out-Null
    }

    It 'Excludes items marked deprecated in existing manifest and reports count' {
        $yaml = @"
id: hve-core-all
name: HVE Core All
description: All artifacts
tags: []
items:
- path: .github/agents/test-collection/active.agent.md
  kind: agent
- path: .github/agents/test-collection/old.agent.md
  kind: agent
  maturity: deprecated
display:
  ordering: alpha
"@
        Set-Content -Path (Join-Path $script:repoRoot 'collections/hve-core-all.collection.yml') -Value $yaml -Encoding utf8 -NoNewline

        $result = Update-HveCoreAllCollection -RepoRoot $script:repoRoot

        $result.DeprecatedCount | Should -BeGreaterOrEqual 1
        $output = Get-Content -Path (Join-Path $script:repoRoot 'collections/hve-core-all.collection.yml') -Raw
        $output | Should -Not -Match 'old\.agent\.md'
    }
}

Describe 'Update-HveCoreAllCollection - non-stable maturity key' {
    BeforeAll {
        $script:repoRoot = Join-Path $TestDrive 'repo-maturity-key'
        $ghDir = Join-Path $script:repoRoot '.github'

        $agentsDir = Join-Path $ghDir 'agents/test-collection'
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
        Set-Content -Path (Join-Path $agentsDir 'preview.agent.md') -Value "---`ndescription: preview agent`n---`nBody"

        $collectionsDir = Join-Path $script:repoRoot 'collections'
        New-Item -ItemType Directory -Path $collectionsDir -Force | Out-Null
    }

    It 'Includes maturity key in output for non-stable items' {
        $yaml = @"
id: hve-core-all
name: HVE Core All
description: All artifacts
tags: []
items:
- path: .github/agents/test-collection/preview.agent.md
  kind: agent
  maturity: preview
display:
  ordering: alpha
"@
        Set-Content -Path (Join-Path $script:repoRoot 'collections/hve-core-all.collection.yml') -Value $yaml -Encoding utf8 -NoNewline

        Update-HveCoreAllCollection -RepoRoot $script:repoRoot | Out-Null

        $output = Get-Content -Path (Join-Path $script:repoRoot 'collections/hve-core-all.collection.yml') -Raw
        $output | Should -Match 'maturity: preview'
    }

    It 'Omits maturity key for stable items' {
        $yaml = @"
id: hve-core-all
name: HVE Core All
description: All artifacts
tags: []
items:
- path: .github/agents/test-collection/preview.agent.md
  kind: agent
display:
  ordering: alpha
"@
        Set-Content -Path (Join-Path $script:repoRoot 'collections/hve-core-all.collection.yml') -Value $yaml -Encoding utf8 -NoNewline

        Update-HveCoreAllCollection -RepoRoot $script:repoRoot | Out-Null

        $output = Get-Content -Path (Join-Path $script:repoRoot 'collections/hve-core-all.collection.yml') -Raw
        $output | Should -Not -Match 'maturity:'
    }
}

Describe 'Update-HveCoreAllCollection - new item detection' {
    BeforeAll {
        $script:repoRoot = Join-Path $TestDrive 'repo-new-item'
        $ghDir = Join-Path $script:repoRoot '.github'

        $agentsDir = Join-Path $ghDir 'agents/test-collection'
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
        Set-Content -Path (Join-Path $agentsDir 'existing.agent.md') -Value "---`ndescription: existing agent`n---`nBody"
        Set-Content -Path (Join-Path $agentsDir 'new.agent.md') -Value "---`ndescription: new agent`n---`nBody"

        $collectionsDir = Join-Path $script:repoRoot 'collections'
        New-Item -ItemType Directory -Path $collectionsDir -Force | Out-Null
    }

    It 'Reports added items when new artifacts are discovered' {
        # Manifest only has the existing agent, discovery will find both
        $yaml = @"
id: hve-core-all
name: HVE Core All
description: All artifacts
tags: []
items:
- path: .github/agents/test-collection/existing.agent.md
  kind: agent
display:
  ordering: alpha
"@
        Set-Content -Path (Join-Path $script:repoRoot 'collections/hve-core-all.collection.yml') -Value $yaml -Encoding utf8 -NoNewline

        $result = Update-HveCoreAllCollection -RepoRoot $script:repoRoot

        $result.AddedCount | Should -BeGreaterOrEqual 1
    }

    It 'Reports zero added when manifest already contains all artifacts' {
        # Run update first to sync, then run again
        Update-HveCoreAllCollection -RepoRoot $script:repoRoot | Out-Null
        $result = Update-HveCoreAllCollection -RepoRoot $script:repoRoot

        $result.AddedCount | Should -Be 0
    }
}

Describe 'Update-HveCoreAllCollection - display key ordering' {
    BeforeAll {
        $script:repoRoot = Join-Path $TestDrive 'repo-display-order'
        $ghDir = Join-Path $script:repoRoot '.github'

        # Create a minimal artifact so discovery finds at least one item
        $agentsDir = Join-Path $ghDir 'agents/test-collection'
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
        Set-Content -Path (Join-Path $agentsDir 'sample.agent.md') -Value "---`ndescription: sample agent`n---`nBody"
    }

    It 'Preserves featured-then-ordering key order when both keys exist' {
        $collectionsDir = Join-Path $script:repoRoot 'collections'
        New-Item -ItemType Directory -Path $collectionsDir -Force | Out-Null

        # Write manifest with ordering BEFORE featured (reversed)
        $yaml = @"
id: hve-core-all
name: HVE Core All
description: All artifacts
tags: []
items:
- path: .github/agents/test-collection/sample.agent.md
  kind: agent
display:
  ordering: alpha
  featured:
  - sample.agent.md
"@
        Set-Content -Path (Join-Path $collectionsDir 'hve-core-all.collection.yml') -Value $yaml -Encoding utf8 -NoNewline

        Update-HveCoreAllCollection -RepoRoot $script:repoRoot | Out-Null

        $output = Get-Content -Path (Join-Path $collectionsDir 'hve-core-all.collection.yml') -Raw
        # featured must appear before ordering in the output
        $featuredIndex = $output.IndexOf('featured:')
        $orderingIndex = $output.IndexOf('ordering:')
        $featuredIndex | Should -BeLessThan $orderingIndex -Because 'featured key should precede ordering key in display section'
    }

    It 'Handles display with only ordering key' {
        $collectionsDir = Join-Path $script:repoRoot 'collections'
        New-Item -ItemType Directory -Path $collectionsDir -Force | Out-Null

        $yaml = @"
id: hve-core-all
name: HVE Core All
description: All artifacts
tags: []
items:
- path: .github/agents/test-collection/sample.agent.md
  kind: agent
display:
  ordering: alpha
"@
        Set-Content -Path (Join-Path $collectionsDir 'hve-core-all.collection.yml') -Value $yaml -Encoding utf8 -NoNewline

        Update-HveCoreAllCollection -RepoRoot $script:repoRoot | Out-Null

        $output = Get-Content -Path (Join-Path $collectionsDir 'hve-core-all.collection.yml') -Raw
        $output | Should -Match 'ordering: alpha'
        $output | Should -Not -Match 'featured:'
    }

    It 'Handles display with only featured key' {
        $collectionsDir = Join-Path $script:repoRoot 'collections'
        New-Item -ItemType Directory -Path $collectionsDir -Force | Out-Null

        $yaml = @"
id: hve-core-all
name: HVE Core All
description: All artifacts
tags: []
items:
- path: .github/agents/test-collection/sample.agent.md
  kind: agent
display:
  featured:
  - sample.agent.md
"@
        Set-Content -Path (Join-Path $collectionsDir 'hve-core-all.collection.yml') -Value $yaml -Encoding utf8 -NoNewline

        Update-HveCoreAllCollection -RepoRoot $script:repoRoot | Out-Null

        $output = Get-Content -Path (Join-Path $collectionsDir 'hve-core-all.collection.yml') -Raw
        $output | Should -Match 'featured:'
        $output | Should -Not -Match 'ordering:'
    }

    It 'Returns expected result hashtable' {
        $collectionsDir = Join-Path $script:repoRoot 'collections'
        New-Item -ItemType Directory -Path $collectionsDir -Force | Out-Null

        $yaml = @"
id: hve-core-all
name: HVE Core All
description: All artifacts
tags: []
items:
- path: .github/agents/test-collection/sample.agent.md
  kind: agent
display:
  ordering: alpha
"@
        Set-Content -Path (Join-Path $collectionsDir 'hve-core-all.collection.yml') -Value $yaml -Encoding utf8 -NoNewline

        $result = Update-HveCoreAllCollection -RepoRoot $script:repoRoot

        $result.ItemCount | Should -BeGreaterOrEqual 1
        $result.Keys | Should -Contain 'AddedCount'
        $result.Keys | Should -Contain 'RemovedCount'
        $result.Keys | Should -Contain 'DeprecatedCount'
    }

    It 'Does not write to disk in DryRun mode' {
        $collectionsDir = Join-Path $script:repoRoot 'collections'
        New-Item -ItemType Directory -Path $collectionsDir -Force | Out-Null

        $yaml = @"
id: hve-core-all
name: HVE Core All
description: All artifacts
tags: []
items: []
display:
  ordering: alpha
"@
        Set-Content -Path (Join-Path $collectionsDir 'hve-core-all.collection.yml') -Value $yaml -Encoding utf8 -NoNewline

        Update-HveCoreAllCollection -RepoRoot $script:repoRoot -DryRun | Out-Null

        $output = Get-Content -Path (Join-Path $collectionsDir 'hve-core-all.collection.yml') -Raw
        $output | Should -Match 'items: \[\]' -Because 'DryRun should not modify the file'
    }
}

Describe 'Set-ContentIfChanged' {
    BeforeAll {
        $script:testDir = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null
    }

    It 'Creates file when it does not exist' {
        $path = Join-Path $script:testDir 'new-file.txt'
        $result = Set-ContentIfChanged -Path $path -Value 'hello'
        $result | Should -BeTrue
        Get-Content -Path $path -Raw -Encoding utf8 | Should -Be 'hello'
    }

    It 'Skips write when content is identical' {
        $path = Join-Path $script:testDir 'same-content.txt'
        Set-Content -Path $path -Value 'unchanged' -Encoding utf8 -NoNewline
        $before = (Get-Item -LiteralPath $path).LastWriteTimeUtc
        Start-Sleep -Milliseconds 50
        $result = Set-ContentIfChanged -Path $path -Value 'unchanged'
        $result | Should -BeFalse
        (Get-Item -LiteralPath $path).LastWriteTimeUtc | Should -Be $before
    }

    It 'Overwrites when content differs' {
        $path = Join-Path $script:testDir 'diff-content.txt'
        Set-Content -Path $path -Value 'old' -Encoding utf8 -NoNewline
        $result = Set-ContentIfChanged -Path $path -Value 'new'
        $result | Should -BeTrue
        Get-Content -Path $path -Raw -Encoding utf8 | Should -Be 'new'
    }

    It 'Case-sensitive comparison triggers write' {
        $path = Join-Path $script:testDir 'case-sensitive.txt'
        Set-Content -Path $path -Value 'Hello' -Encoding utf8 -NoNewline
        $result = Set-ContentIfChanged -Path $path -Value 'hello'
        $result | Should -BeTrue
        Get-Content -Path $path -Raw -Encoding utf8 | Should -Be 'hello'
    }

    It 'Handles empty string content' {
        $path = Join-Path $script:testDir 'empty-content.txt'
        $result = Set-ContentIfChanged -Path $path -Value ''
        $result | Should -BeTrue
        [System.IO.File]::ReadAllText($path) | Should -Be ''
    }

    It 'Writes UTF-8 without BOM and no trailing newline' {
        $path = Join-Path $script:testDir 'encoding-check.txt'
        Set-ContentIfChanged -Path $path -Value 'test content' | Out-Null
        $bytes = [System.IO.File]::ReadAllBytes($path)
        # UTF-8 BOM is 0xEF 0xBB 0xBF — first bytes must not match
        if ($bytes.Length -ge 3) {
            ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) | Should -BeFalse
        }
        # No trailing newline
        $text = [System.IO.File]::ReadAllText($path)
        $text | Should -Be 'test content'
    }
}

Describe 'Update-HveCoreAllCollection - removed maturity exclusion' {
    BeforeAll {
        $script:repoRoot = Join-Path $TestDrive 'repo-removed-maturity'
        $agentsDir = Join-Path $script:repoRoot '.github/agents/test-collection'
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
        Set-Content -Path (Join-Path $agentsDir 'keep.agent.md') -Value "---`ndescription: keep`n---`nBody"
        Set-Content -Path (Join-Path $agentsDir 'drop.agent.md') -Value "---`ndescription: drop`n---`nBody"
        New-Item -ItemType Directory -Path (Join-Path $script:repoRoot 'collections') -Force | Out-Null
    }

    It 'Excludes items with maturity: removed from generated hve-core-all manifest' {
        $yaml = @"
id: hve-core-all
name: HVE Core All
description: All artifacts
tags: []
items:
- path: .github/agents/test-collection/keep.agent.md
  kind: agent
- path: .github/agents/test-collection/drop.agent.md
  kind: agent
  maturity: removed
display:
  ordering: alpha
"@
        Set-Content -Path (Join-Path $script:repoRoot 'collections/hve-core-all.collection.yml') -Value $yaml -Encoding utf8 -NoNewline

        Update-HveCoreAllCollection -RepoRoot $script:repoRoot | Out-Null

        $output = Get-Content -Path (Join-Path $script:repoRoot 'collections/hve-core-all.collection.yml') -Raw
        $output | Should -Match 'keep\.agent\.md'
        $output | Should -Not -Match 'drop\.agent\.md'
    }
}

Describe 'Maturity vocabulary drift guard' {
    BeforeAll {
        $script:allowedMaturities = Get-CollectionMaturityVocabulary
        $script:maturityRank = Get-CollectionMaturityRank
        $script:rankKeys = @($script:maturityRank.Keys)
    }

    It 'Exposes a non-empty allowed maturity vocabulary' {
        $script:allowedMaturities.Count | Should -BeGreaterThan 0
    }

    It 'Exposes a non-empty maturity rank map' {
        $script:rankKeys.Count | Should -BeGreaterThan 0
    }

    It 'Ranks every allowed maturity so propagation never hits a null rank' {
        foreach ($maturity in $script:allowedMaturities) {
            $script:rankKeys | Should -Contain $maturity -Because "maturity '$maturity' is in the vocabulary and must have a rank for Update-HveCoreAllCollection propagation"
        }
    }

    It 'Does not rank maturities absent from the allowed vocabulary' {
        foreach ($key in $script:rankKeys) {
            $script:allowedMaturities | Should -Contain $key -Because "maturity rank key '$key' has no matching entry in the allowed maturity vocabulary"
        }
    }

    It 'Returns a stable rank order matching vocabulary strictness' {
        for ($i = 0; $i -lt $script:allowedMaturities.Count; $i++) {
            $script:maturityRank[$script:allowedMaturities[$i]] | Should -Be $i -Because 'rank must equal the vocabulary index so strictest maturity wins'
        }
    }
}

Describe 'Get-CollectionMaturityRank - null-rank regression' {
    BeforeAll {
        $script:vocabulary = Get-CollectionMaturityVocabulary
        $script:rank = Get-CollectionMaturityRank
    }

    # Regression guard for the PowerShell `$null -gt 0` pitfall: an unranked
    # maturity returns $null from the rank map, and `$null -gt 0` is $false,
    # so a missing rank would silently lose the strictest-wins comparison
    # during propagation. Every vocabulary entry must resolve to a non-null
    # integer rank.
    It 'Assigns a non-null integer rank to every vocabulary entry' {
        foreach ($maturity in $script:vocabulary) {
            $resolved = $script:rank[$maturity]
            $resolved | Should -Not -BeNullOrEmpty -Because "maturity '$maturity' must have a rank or propagation hits the `$null -gt 0 pitfall"
            $resolved | Should -BeOfType [int]
        }
    }

    It 'Produces ranks that compare correctly without a null short-circuit' {
        $stableRank = $script:rank['stable']
        $removedRank = $script:rank['removed']
        ($removedRank -gt $stableRank) | Should -BeTrue -Because 'strictest maturity must win the comparison'
        # A null rank would make this comparison silently $false.
        ($null -gt $stableRank) | Should -BeFalse
    }
}

Describe 'Update-HveCoreAllCollection - experimental maturity propagation' {
    BeforeAll {
        $script:repoRoot = Join-Path $TestDrive 'repo-experimental-propagation'
        $agentsDir = Join-Path $script:repoRoot '.github/agents/test-collection'
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
        Set-Content -Path (Join-Path $agentsDir 'exp.agent.md') -Value "---`ndescription: experimental agent`n---`nBody"

        $collectionsDir = Join-Path $script:repoRoot 'collections'
        New-Item -ItemType Directory -Path $collectionsDir -Force | Out-Null

        # Source themed collection declares the item as experimental
        $themeYaml = @"
id: test-theme
name: Test Theme
description: Theme collection
tags: []
items:
- path: .github/agents/test-collection/exp.agent.md
  kind: agent
  maturity: experimental
"@
        Set-Content -Path (Join-Path $collectionsDir 'test-theme.collection.yml') -Value $themeYaml -Encoding utf8 -NoNewline
    }

    It 'Propagates experimental maturity from a source collection into the aggregated manifest' {
        # hve-core-all starts with the item as stable (no maturity key)
        $aggregateYaml = @"
id: hve-core-all
name: HVE Core All
description: All artifacts
tags: []
items:
- path: .github/agents/test-collection/exp.agent.md
  kind: agent
display:
  ordering: alpha
"@
        Set-Content -Path (Join-Path $script:repoRoot 'collections/hve-core-all.collection.yml') -Value $aggregateYaml -Encoding utf8 -NoNewline

        Update-HveCoreAllCollection -RepoRoot $script:repoRoot | Out-Null

        $output = Get-Content -Path (Join-Path $script:repoRoot 'collections/hve-core-all.collection.yml') -Raw
        $output | Should -Match 'exp\.agent\.md'
        $output | Should -Match 'maturity: experimental'
    }
}

Describe 'Resolve-StrictSafeMaturity' {
    BeforeAll {
        $script:vocabulary = Get-CollectionMaturityVocabulary
    }

    It 'Returns every known maturity unchanged' {
        foreach ($maturity in $script:vocabulary) {
            Resolve-StrictSafeMaturity -Maturity $maturity -WarningAction SilentlyContinue |
                Should -Be $maturity -Because "ranked maturity '$maturity' must pass through untouched"
        }
    }

    It 'Does not warn for a known maturity' {
        Resolve-StrictSafeMaturity -Maturity 'preview' -WarningVariable knownWarnings -WarningAction SilentlyContinue | Out-Null
        $knownWarnings | Should -BeNullOrEmpty
    }

    It 'Errs toward experimental for an unrankable maturity' {
        Resolve-StrictSafeMaturity -Maturity 'beta' -WarningAction SilentlyContinue |
            Should -Be 'experimental' -Because 'strict-safe resolution must prefer experimental over stable'
    }

    It 'Treats an empty maturity as experimental rather than stable' {
        # Resolve-CollectionItemMaturity converts empty to 'stable' before this
        # runs, so a literal empty value reaching here is itself unrankable.
        Resolve-StrictSafeMaturity -Maturity '' -WarningAction SilentlyContinue |
            Should -Be 'experimental'
    }

    It 'Emits a deep warning with remediation guidance for an unrankable maturity' {
        Resolve-StrictSafeMaturity -Maturity 'beta' -Source 'theme.collection.yml (agent foo)' -WarningVariable badWarnings -WarningAction SilentlyContinue | Out-Null
        $badWarnings | Should -Not -BeNullOrEmpty
        $warningText = $badWarnings -join "`n"
        $warningText | Should -Match "Unrankable maturity 'beta'"
        $warningText | Should -Match 'theme\.collection\.yml \(agent foo\)'
        $warningText | Should -Match 'Remediation:'
        foreach ($maturity in $script:vocabulary) {
            $warningText | Should -Match ([regex]::Escape($maturity)) -Because "remediation must list valid value '$maturity'"
        }
    }
}

Describe 'Update-HveCoreAllCollection - strictest-wins propagation' {
    BeforeEach {
        $script:repoRoot = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
        $script:agentsDir = Join-Path $script:repoRoot '.github/agents/test-collection'
        New-Item -ItemType Directory -Path $script:agentsDir -Force | Out-Null
        Set-Content -Path (Join-Path $script:agentsDir 'item.agent.md') -Value "---`ndescription: item agent`n---`nBody"

        $script:collectionsDir = Join-Path $script:repoRoot 'collections'
        New-Item -ItemType Directory -Path $script:collectionsDir -Force | Out-Null
    }

    It 'Does not downgrade a stricter aggregate maturity from a less-strict source' {
        # Source declares the item stable; aggregate already has it experimental.
        $themeYaml = @"
id: test-theme
name: Test Theme
description: Theme collection
tags: []
items:
- path: .github/agents/test-collection/item.agent.md
  kind: agent
  maturity: stable
"@
        Set-Content -Path (Join-Path $script:collectionsDir 'test-theme.collection.yml') -Value $themeYaml -Encoding utf8 -NoNewline

        $aggregateYaml = @"
id: hve-core-all
name: HVE Core All
description: All artifacts
tags: []
items:
- path: .github/agents/test-collection/item.agent.md
  kind: agent
  maturity: experimental
display:
  ordering: alpha
"@
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.yml') -Value $aggregateYaml -Encoding utf8 -NoNewline

        Update-HveCoreAllCollection -RepoRoot $script:repoRoot | Out-Null

        $output = Get-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.yml') -Raw
        $output | Should -Match 'maturity: experimental'
    }

    It 'Errs toward experimental and warns when a source maturity is unrankable' {
        $themeYaml = @"
id: test-theme
name: Test Theme
description: Theme collection
tags: []
items:
- path: .github/agents/test-collection/item.agent.md
  kind: agent
  maturity: beta
"@
        Set-Content -Path (Join-Path $script:collectionsDir 'test-theme.collection.yml') -Value $themeYaml -Encoding utf8 -NoNewline

        $aggregateYaml = @"
id: hve-core-all
name: HVE Core All
description: All artifacts
tags: []
items:
- path: .github/agents/test-collection/item.agent.md
  kind: agent
display:
  ordering: alpha
"@
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.yml') -Value $aggregateYaml -Encoding utf8 -NoNewline

        Update-HveCoreAllCollection -RepoRoot $script:repoRoot -WarningVariable propWarnings -WarningAction SilentlyContinue | Out-Null

        $output = Get-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.yml') -Raw
        $output | Should -Match 'maturity: experimental' -Because 'an unrankable source maturity must err toward experimental'

        $warningText = $propWarnings -join "`n"
        $warningText | Should -Match "Unrankable maturity 'beta'"
        $warningText | Should -Match 'Remediation:'
    }

    It 'Excludes the item when a source escalates it to deprecated (strictest wins)' {
        $themeYaml = @"
id: test-theme
name: Test Theme
description: Theme collection
tags: []
items:
- path: .github/agents/test-collection/item.agent.md
  kind: agent
  maturity: deprecated
"@
        Set-Content -Path (Join-Path $script:collectionsDir 'test-theme.collection.yml') -Value $themeYaml -Encoding utf8 -NoNewline

        $aggregateYaml = @"
id: hve-core-all
name: HVE Core All
description: All artifacts
tags: []
items:
- path: .github/agents/test-collection/item.agent.md
  kind: agent
  maturity: experimental
display:
  ordering: alpha
"@
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.yml') -Value $aggregateYaml -Encoding utf8 -NoNewline

        Update-HveCoreAllCollection -RepoRoot $script:repoRoot | Out-Null

        $output = Get-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.yml') -Raw
        $output | Should -Not -Match 'item\.agent\.md' -Because 'deprecated is stricter than experimental and must exclude the item'
    }
}



