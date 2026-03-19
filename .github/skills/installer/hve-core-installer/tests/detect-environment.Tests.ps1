#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

Describe 'detect-environment' -Tag 'Unit' {
    BeforeAll {
        $script:scriptPath = Join-Path $PSScriptRoot '../scripts/detect-environment.ps1'
        $script:testRoot = Join-Path ([System.IO.Path]::GetTempPath()) "hve-test-detect-env-$([guid]::NewGuid().ToString('N'))"
    }

    BeforeEach {
        # Clean and recreate temp directory for full isolation between tests
        if (Test-Path $script:testRoot) {
            Remove-Item $script:testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
        New-Item -ItemType Directory -Path $script:testRoot -Force | Out-Null
        Push-Location $script:testRoot

        # Save and clear environment variables
        $script:savedCodespaces = $env:CODESPACES
        $script:savedRemoteContainers = $env:REMOTE_CONTAINERS
        $env:CODESPACES = $null
        $env:REMOTE_CONTAINERS = $null
    }

    AfterEach {
        Pop-Location
        $env:CODESPACES = $script:savedCodespaces
        $env:REMOTE_CONTAINERS = $script:savedRemoteContainers
    }

    AfterAll {
        if (Test-Path $script:testRoot) {
            Remove-Item $script:testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Local environment detection' {
        It 'Detects local environment when no container markers are present' {
            $output = & $script:scriptPath 6>&1 | Out-String

            $output | Should -Match 'ENV_TYPE=local'
            $output | Should -Match 'IS_CODESPACES=False'
            $output | Should -Match 'IS_DEVCONTAINER=False'
        }
    }

    Context 'Codespaces environment detection' {
        It 'Detects Codespaces when CODESPACES env var is true' {
            $env:CODESPACES = 'true'

            $output = & $script:scriptPath 6>&1 | Out-String

            $output | Should -Match 'ENV_TYPE=codespaces'
            $output | Should -Match 'IS_CODESPACES=True'
            $output | Should -Match 'IS_DEVCONTAINER=True'
        }
    }

    Context 'Devcontainer detection' {
        It 'Detects devcontainer when REMOTE_CONTAINERS env var is true' {
            $env:REMOTE_CONTAINERS = 'true'

            $output = & $script:scriptPath 6>&1 | Out-String

            $output | Should -Match 'ENV_TYPE=devcontainer'
            $output | Should -Match 'IS_DEVCONTAINER=True'
        }
    }

    Context 'Devcontainer JSON detection' {
        It 'Reports HAS_DEVCONTAINER_JSON=True when file exists' {
            New-Item -ItemType Directory -Path '.devcontainer' -Force | Out-Null
            Set-Content -Path '.devcontainer/devcontainer.json' -Value '{}'

            $output = & $script:scriptPath 6>&1 | Out-String

            $output | Should -Match 'HAS_DEVCONTAINER_JSON=True'
        }

        It 'Reports HAS_DEVCONTAINER_JSON=False when file does not exist' {
            $output = & $script:scriptPath 6>&1 | Out-String

            $output | Should -Match 'HAS_DEVCONTAINER_JSON=False'
        }
    }

    Context 'Workspace file detection' {
        It 'Reports HAS_WORKSPACE_FILE=True when .code-workspace file exists' {
            Set-Content -Path 'test.code-workspace' -Value '{}'

            $output = & $script:scriptPath 6>&1 | Out-String

            $output | Should -Match 'HAS_WORKSPACE_FILE=True'
        }

        It 'Reports HAS_WORKSPACE_FILE=False when no workspace file exists' {
            $output = & $script:scriptPath 6>&1 | Out-String

            $output | Should -Match 'HAS_WORKSPACE_FILE=False'
        }
    }

    Context 'HVE-Core repo detection' {
        It 'Reports IS_HVE_CORE_REPO output' {
            # In a temp directory outside a hve-core repo, this should be False
            $output = & $script:scriptPath 6>&1 | Out-String

            $output | Should -Match 'IS_HVE_CORE_REPO='
        }
    }
}
