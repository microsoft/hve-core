#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

Describe 'file-status-check' -Tag 'Unit' {
    BeforeAll {
        $script:scriptPath = Join-Path $PSScriptRoot '../scripts/file-status-check.ps1'
        $script:testRoot = Join-Path ([System.IO.Path]::GetTempPath()) "hve-test-file-status-$([guid]::NewGuid().ToString('N'))"
    }

    BeforeEach {
        New-Item -ItemType Directory -Path $script:testRoot -Force | Out-Null
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

    Context 'Managed files (unchanged)' {
        It 'Reports managed status when file hash matches manifest' {
            $filePath = '.github/agents/task-researcher.agent.md'
            New-Item -ItemType Directory -Path '.github/agents' -Force | Out-Null
            Set-Content -Path $filePath -Value '# Researcher' -NoNewline
            $hash = (Get-FileHash -Path $filePath -Algorithm SHA256).Hash.ToLower()

            $manifest = @{
                files = @{
                    $filePath = @{ sha256 = $hash; status = 'managed' }
                }
            }
            $manifest | ConvertTo-Json -Depth 10 | Set-Content '.hve-tracking.json'

            $output = & $script:scriptPath 6>&1 | Out-String

            $output | Should -Match "FILE=$([regex]::Escape($filePath))\|STATUS=managed\|ACTION=Will update"
        }
    }

    Context 'Modified files' {
        It 'Reports modified status when file hash differs from manifest' {
            $filePath = '.github/agents/task-researcher.agent.md'
            New-Item -ItemType Directory -Path '.github/agents' -Force | Out-Null
            Set-Content -Path $filePath -Value '# Modified Content' -NoNewline

            $manifest = @{
                files = @{
                    $filePath = @{ sha256 = 'old_hash_value'; status = 'managed' }
                }
            }
            $manifest | ConvertTo-Json -Depth 10 | Set-Content '.hve-tracking.json'

            $output = & $script:scriptPath 6>&1 | Out-String

            $output | Should -Match "FILE=$([regex]::Escape($filePath))\|STATUS=modified\|ACTION=Requires decision"
        }
    }

    Context 'Missing files' {
        It 'Reports missing status when tracked file does not exist on disk' {
            $filePath = '.github/agents/missing-file.agent.md'

            $manifest = @{
                files = @{
                    $filePath = @{ sha256 = 'abc123'; status = 'managed' }
                }
            }
            $manifest | ConvertTo-Json -Depth 10 | Set-Content '.hve-tracking.json'

            $output = & $script:scriptPath 6>&1 | Out-String

            $output | Should -Match "FILE=$([regex]::Escape($filePath))\|STATUS=missing\|ACTION=Will restore"
        }
    }

    Context 'Ejected files' {
        It 'Reports ejected status and skip action for ejected files' {
            $filePath = '.github/agents/custom.agent.md'
            New-Item -ItemType Directory -Path '.github/agents' -Force | Out-Null
            Set-Content -Path $filePath -Value '# Custom' -NoNewline

            $manifest = @{
                files = @{
                    $filePath = @{
                        sha256 = 'abc123'
                        status = 'ejected'
                        ejectedAt = '2025-01-01T00:00:00Z'
                    }
                }
            }
            $manifest | ConvertTo-Json -Depth 10 | Set-Content '.hve-tracking.json'

            $output = & $script:scriptPath 6>&1 | Out-String

            $output | Should -Match "FILE=$([regex]::Escape($filePath))\|STATUS=ejected\|ACTION=Skip"
        }

        It 'Does not check hash for ejected files' {
            $filePath = '.github/agents/ejected.agent.md'
            # File does not exist on disk, but ejected files should not be hash-checked
            $manifest = @{
                files = @{
                    $filePath = @{
                        sha256 = 'abc123'
                        status = 'ejected'
                        ejectedAt = '2025-01-01T00:00:00Z'
                    }
                }
            }
            $manifest | ConvertTo-Json -Depth 10 | Set-Content '.hve-tracking.json'

            $output = & $script:scriptPath 6>&1 | Out-String

            # Should report ejected, not missing
            $output | Should -Match 'STATUS=ejected'
            $output | Should -Not -Match 'STATUS=missing'
        }
    }

    Context 'Multiple files' {
        It 'Reports status for each tracked file independently' {
            New-Item -ItemType Directory -Path '.github/agents' -Force | Out-Null

            $managedPath = '.github/agents/managed.agent.md'
            Set-Content -Path $managedPath -Value '# Managed' -NoNewline
            $managedHash = (Get-FileHash -Path $managedPath -Algorithm SHA256).Hash.ToLower()

            $modifiedPath = '.github/agents/modified.agent.md'
            Set-Content -Path $modifiedPath -Value '# Modified' -NoNewline

            $missingPath = '.github/agents/missing.agent.md'

            $manifest = @{
                files = @{
                    $managedPath  = @{ sha256 = $managedHash; status = 'managed' }
                    $modifiedPath = @{ sha256 = 'wrong_hash'; status = 'managed' }
                    $missingPath  = @{ sha256 = 'abc123'; status = 'managed' }
                }
            }
            $manifest | ConvertTo-Json -Depth 10 | Set-Content '.hve-tracking.json'

            $output = & $script:scriptPath 6>&1 | Out-String

            $output | Should -Match 'STATUS=managed'
            $output | Should -Match 'STATUS=modified'
            $output | Should -Match 'STATUS=missing'
        }
    }
}
