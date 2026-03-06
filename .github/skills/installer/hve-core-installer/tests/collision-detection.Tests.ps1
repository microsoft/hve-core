#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

Describe 'collision-detection' -Tag 'Unit' {
    BeforeAll {
        $script:scriptPath = Join-Path $PSScriptRoot '../scripts/collision-detection.ps1'
        $script:testRoot = Join-Path ([System.IO.Path]::GetTempPath()) "hve-test-collision-$([guid]::NewGuid().ToString('N'))"
        $script:sourceRoot = Join-Path $script:testRoot 'source'
    }

    BeforeEach {
        New-Item -ItemType Directory -Path $script:testRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $script:sourceRoot -Force | Out-Null

        # Create source agents
        $agentsDir = Join-Path $script:sourceRoot '.github/agents/hve-core'
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
        Set-Content -Path (Join-Path $agentsDir 'task-researcher.agent.md') -Value '# Researcher'
        Set-Content -Path (Join-Path $agentsDir 'task-planner.agent.md') -Value '# Planner'

        Push-Location $script:testRoot
    }

    AfterEach {
        Pop-Location
    }

    AfterAll {
        if (Test-Path $script:testRoot) {
            Remove-Item $script:testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'No collisions' {
        It 'Reports COLLISIONS_DETECTED=false when target directory does not exist' {
            $output = & $script:scriptPath -Selection 'hve-core' 6>&1 | Out-String

            $output | Should -Match 'COLLISIONS_DETECTED=false'
        }

        It 'Reports COLLISIONS_DETECTED=false when no matching files exist' {
            New-Item -ItemType Directory -Path '.github/agents' -Force | Out-Null
            Set-Content -Path '.github/agents/unrelated.md' -Value '# Other'

            $output = & $script:scriptPath -Selection 'hve-core' 6>&1 | Out-String

            $output | Should -Match 'COLLISIONS_DETECTED=false'
        }
    }

    Context 'Collisions detected' {
        It 'Reports COLLISIONS_DETECTED=true when target files exist' {
            New-Item -ItemType Directory -Path '.github/agents' -Force | Out-Null
            Set-Content -Path '.github/agents/task-researcher.agent.md' -Value '# Existing'

            $output = & $script:scriptPath -Selection 'hve-core' 6>&1 | Out-String

            $output | Should -Match 'COLLISIONS_DETECTED=true'
        }

        It 'Lists collision file paths' {
            New-Item -ItemType Directory -Path '.github/agents' -Force | Out-Null
            Set-Content -Path '.github/agents/task-researcher.agent.md' -Value '# Existing'
            Set-Content -Path '.github/agents/task-planner.agent.md' -Value '# Existing'

            $output = & $script:scriptPath -Selection 'hve-core' 6>&1 | Out-String

            $output | Should -Match 'COLLISION_FILES='
            $output | Should -Match 'task-researcher\.agent\.md'
            $output | Should -Match 'task-planner\.agent\.md'
        }
    }

    Context 'Collection selection' {
        It 'Uses collectionAgents for non-hve-core selection' {
            New-Item -ItemType Directory -Path '.github/agents' -Force | Out-Null
            Set-Content -Path '.github/agents/custom-agent.agent.md' -Value '# Custom'

            $output = & $script:scriptPath -Selection 'my-collection' -CollectionAgents @('my-collection/custom-agent.agent.md') 6>&1 | Out-String

            $output | Should -Match 'COLLISIONS_DETECTED=true'
            $output | Should -Match 'custom-agent\.agent\.md'
        }

        It 'Reports no collisions for empty collectionAgents' {
            $output = & $script:scriptPath -Selection 'my-collection' -CollectionAgents @() 6>&1 | Out-String

            $output | Should -Match 'COLLISIONS_DETECTED=false'
        }
    }
}
