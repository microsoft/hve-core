#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

Describe 'agent-copy' -Tag 'Unit' {
    BeforeAll {
        $script:scriptPath = Join-Path $PSScriptRoot '../scripts/agent-copy.ps1'
        $script:testRoot = Join-Path ([System.IO.Path]::GetTempPath()) "hve-test-agent-copy-$([guid]::NewGuid().ToString('N'))"
        $script:sourceRoot = Join-Path $script:testRoot 'source'
        $script:targetRoot = Join-Path $script:testRoot 'target'
    }

    BeforeEach {
        # Create clean source and target directories for each test
        New-Item -ItemType Directory -Path $script:sourceRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $script:targetRoot -Force | Out-Null

        # Create source agents directory with sample files
        $agentsDir = Join-Path $script:sourceRoot '.github/agents/hve-core'
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null

        Set-Content -Path (Join-Path $agentsDir 'task-researcher.agent.md') -Value '# Researcher' -NoNewline
        Set-Content -Path (Join-Path $agentsDir 'task-planner.agent.md') -Value '# Planner' -NoNewline

        # Create package.json in source
        @{ version = '2.0.0' } | ConvertTo-Json | Set-Content (Join-Path $script:sourceRoot 'package.json')

        Push-Location $script:targetRoot
    }

    AfterEach {
        Pop-Location
    }

    AfterAll {
        if (Test-Path $script:testRoot) {
            Remove-Item $script:testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Directory creation' {
        It 'Creates .github/agents directory when it does not exist' {
            & $script:scriptPath -HveCoreBasePath $script:sourceRoot -CollectionId 'hve-core' -FilesToCopy @('hve-core/task-researcher.agent.md')

            Test-Path '.github/agents' | Should -BeTrue
        }

        It 'Does not fail when .github/agents directory already exists' {
            New-Item -ItemType Directory -Path '.github/agents' -Force | Out-Null

            { & $script:scriptPath -HveCoreBasePath $script:sourceRoot -CollectionId 'hve-core' -FilesToCopy @('hve-core/task-researcher.agent.md') } | Should -Not -Throw
        }
    }

    Context 'File copying' {
        It 'Copies specified agent files to target directory' {
            & $script:scriptPath -HveCoreBasePath $script:sourceRoot -CollectionId 'hve-core' -FilesToCopy @('hve-core/task-researcher.agent.md', 'hve-core/task-planner.agent.md')

            Test-Path '.github/agents/task-researcher.agent.md' | Should -BeTrue
            Test-Path '.github/agents/task-planner.agent.md' | Should -BeTrue
        }

        It 'Copies file content correctly' {
            & $script:scriptPath -HveCoreBasePath $script:sourceRoot -CollectionId 'hve-core' -FilesToCopy @('hve-core/task-researcher.agent.md')

            Get-Content '.github/agents/task-researcher.agent.md' -Raw | Should -Be '# Researcher'
        }

        It 'Skips collision files when keepExisting is true' {
            New-Item -ItemType Directory -Path '.github/agents' -Force | Out-Null
            Set-Content -Path '.github/agents/task-researcher.agent.md' -Value '# Custom' -NoNewline

            & $script:scriptPath -HveCoreBasePath $script:sourceRoot -CollectionId 'hve-core' -FilesToCopy @('hve-core/task-researcher.agent.md') -KeepExisting -Collisions @(Join-Path '.github/agents' 'task-researcher.agent.md')

            Get-Content '.github/agents/task-researcher.agent.md' -Raw | Should -Be '# Custom'
        }

        It 'Overwrites files when keepExisting is false' {
            New-Item -ItemType Directory -Path '.github/agents' -Force | Out-Null
            Set-Content -Path '.github/agents/task-researcher.agent.md' -Value '# Custom' -NoNewline

            & $script:scriptPath -HveCoreBasePath $script:sourceRoot -CollectionId 'hve-core' -FilesToCopy @('hve-core/task-researcher.agent.md')

            Get-Content '.github/agents/task-researcher.agent.md' -Raw | Should -Be '# Researcher'
        }
    }

    Context 'Manifest creation' {
        It 'Creates .hve-tracking.json manifest' {
            & $script:scriptPath -HveCoreBasePath $script:sourceRoot -CollectionId 'hve-core' -FilesToCopy @('hve-core/task-researcher.agent.md')

            Test-Path '.hve-tracking.json' | Should -BeTrue
        }

        It 'Writes correct manifest structure' {
            & $script:scriptPath -HveCoreBasePath $script:sourceRoot -CollectionId 'hve-core' -FilesToCopy @('hve-core/task-researcher.agent.md')

            $manifest = Get-Content '.hve-tracking.json' | ConvertFrom-Json
            $manifest.source | Should -Be 'microsoft/hve-core'
            $manifest.version | Should -Be '2.0.0'
            $manifest.collection | Should -Be 'hve-core'
        }

        It 'Stores SHA256 hashes for copied files' {
            & $script:scriptPath -HveCoreBasePath $script:sourceRoot -CollectionId 'hve-core' -FilesToCopy @('hve-core/task-researcher.agent.md')

            $manifest = Get-Content '.hve-tracking.json' | ConvertFrom-Json -AsHashtable
            $fileEntry = $manifest.files['.github/agents/task-researcher.agent.md']
            $fileEntry | Should -Not -BeNullOrEmpty
            $fileEntry.sha256 | Should -Not -BeNullOrEmpty
            $fileEntry.status | Should -Be 'managed'
        }

        It 'Records correct SHA256 hash matching the file on disk' {
            & $script:scriptPath -HveCoreBasePath $script:sourceRoot -CollectionId 'hve-core' -FilesToCopy @('hve-core/task-researcher.agent.md')

            $manifest = Get-Content '.hve-tracking.json' | ConvertFrom-Json -AsHashtable
            $expectedHash = (Get-FileHash -Path '.github/agents/task-researcher.agent.md' -Algorithm SHA256).Hash.ToLower()
            $manifest.files['.github/agents/task-researcher.agent.md'].sha256 | Should -Be $expectedHash
        }
    }
}
