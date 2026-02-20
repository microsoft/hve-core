#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    Import-Module $PSScriptRoot/../../plugins/Modules/PluginHelpers.psm1 -Force
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

Describe 'Get-PluginItemName' {
    It 'Strips .agent.md suffix' {
        $result = Get-PluginItemName -FileName 'task-researcher.agent.md' -Kind 'agent'
        $result | Should -Be 'task-researcher.md'
    }

    It 'Strips .prompt.md suffix' {
        $result = Get-PluginItemName -FileName 'gen-plan.prompt.md' -Kind 'prompt'
        $result | Should -Be 'gen-plan.md'
    }

    It 'Strips .instructions.md suffix' {
        $result = Get-PluginItemName -FileName 'csharp.instructions.md' -Kind 'instruction'
        $result | Should -Be 'csharp.md'
    }

    It 'Returns skill directory name unchanged' {
        $result = Get-PluginItemName -FileName 'video-to-gif' -Kind 'skill'
        $result | Should -Be 'video-to-gif'
    }
}

Describe 'Get-PluginSubdirectory' {
    It 'Maps agent to agents' {
        $result = Get-PluginSubdirectory -Kind 'agent'
        $result | Should -Be 'agents'
    }

    It 'Maps prompt to commands' {
        $result = Get-PluginSubdirectory -Kind 'prompt'
        $result | Should -Be 'commands'
    }

    It 'Maps instruction to instructions' {
        $result = Get-PluginSubdirectory -Kind 'instruction'
        $result | Should -Be 'instructions'
    }

    It 'Maps skill to skills' {
        $result = Get-PluginSubdirectory -Kind 'skill'
        $result | Should -Be 'skills'
    }
}

Describe 'Test-SymlinkCapability' {
    It 'Returns a boolean' {
        $result = Test-SymlinkCapability
        $result | Should -BeOfType [bool]
    }

    It 'Cleans up probe directory' {
        $probeDirPattern = Join-Path ([System.IO.Path]::GetTempPath()) "hve-symlink-probe-$PID"
        Test-SymlinkCapability | Out-Null
        Test-Path $probeDirPattern | Should -BeFalse
    }
}

Describe 'New-PluginLink' {
    BeforeAll {
        $script:linkRoot = Join-Path $TestDrive 'link-test'
        New-Item -ItemType Directory -Path $script:linkRoot -Force | Out-Null
    }

    It 'Writes text stub when SymlinkCapable is false' {
        $src = Join-Path $script:linkRoot 'src-stub.txt'
        Set-Content -Path $src -Value 'content' -NoNewline
        $dest = Join-Path $script:linkRoot 'dest-stub.txt'

        New-PluginLink -SourcePath $src -DestinationPath $dest

        Test-Path $dest | Should -BeTrue
        $stubContent = [System.IO.File]::ReadAllText($dest)
        $expectedPath = [System.IO.Path]::GetRelativePath((Split-Path -Parent $dest), $src) -replace '\\', '/'
        $stubContent | Should -Be $expectedPath
    }

    It 'Creates parent directory when destination parent does not exist' {
        $src = Join-Path $script:linkRoot 'src-parent.txt'
        Set-Content -Path $src -Value 'data' -NoNewline
        $dest = Join-Path $script:linkRoot 'nested/deep/dest-parent.txt'

        New-PluginLink -SourcePath $src -DestinationPath $dest

        Test-Path $dest | Should -BeTrue
    }
}
