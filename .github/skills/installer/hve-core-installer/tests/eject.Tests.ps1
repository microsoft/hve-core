#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

Describe 'eject' -Tag 'Unit' {
    BeforeAll {
        $script:scriptPath = Join-Path $PSScriptRoot '../scripts/eject.ps1'
        $script:testRoot = Join-Path ([System.IO.Path]::GetTempPath()) "hve-test-eject-$([guid]::NewGuid().ToString('N'))"
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

    Context 'Successful ejection' {
        It 'Sets file status to ejected in manifest' {
            $manifest = @{
                source = 'microsoft/hve-core'
                version = '1.0.0'
                files = @{
                    '.github/agents/task-implementor.agent.md' = @{
                        version = '1.0.0'
                        sha256 = 'abc123'
                        status = 'managed'
                    }
                }
            }
            $manifest | ConvertTo-Json -Depth 10 | Set-Content '.hve-tracking.json'

            & $script:scriptPath -FilePath '.github/agents/task-implementor.agent.md'

            $updated = Get-Content '.hve-tracking.json' | ConvertFrom-Json -AsHashtable
            $updated.files['.github/agents/task-implementor.agent.md'].status | Should -Be 'ejected'
        }

        It 'Adds ejectedAt timestamp to the file entry' {
            $manifest = @{
                source = 'microsoft/hve-core'
                version = '1.0.0'
                files = @{
                    '.github/agents/task-implementor.agent.md' = @{
                        version = '1.0.0'
                        sha256 = 'abc123'
                        status = 'managed'
                    }
                }
            }
            $manifest | ConvertTo-Json -Depth 10 | Set-Content '.hve-tracking.json'

            & $script:scriptPath -FilePath '.github/agents/task-implementor.agent.md'

            $updated = Get-Content '.hve-tracking.json' | ConvertFrom-Json -AsHashtable
            $updated.files['.github/agents/task-implementor.agent.md'].ejectedAt | Should -Not -BeNullOrEmpty
        }

        It 'Preserves other files in the manifest' {
            $manifest = @{
                source = 'microsoft/hve-core'
                version = '1.0.0'
                files = @{
                    '.github/agents/task-implementor.agent.md' = @{
                        version = '1.0.0'
                        sha256 = 'abc123'
                        status = 'managed'
                    }
                    '.github/agents/task-researcher.agent.md' = @{
                        version = '1.0.0'
                        sha256 = 'def456'
                        status = 'managed'
                    }
                }
            }
            $manifest | ConvertTo-Json -Depth 10 | Set-Content '.hve-tracking.json'

            & $script:scriptPath -FilePath '.github/agents/task-implementor.agent.md'

            $updated = Get-Content '.hve-tracking.json' | ConvertFrom-Json -AsHashtable
            $updated.files['.github/agents/task-researcher.agent.md'].status | Should -Be 'managed'
        }
    }

    Context 'File not found in manifest' {
        It 'Outputs error message for untracked file' {
            $manifest = @{
                source = 'microsoft/hve-core'
                version = '1.0.0'
                files = @{}
            }
            $manifest | ConvertTo-Json -Depth 10 | Set-Content '.hve-tracking.json'

            $output = & $script:scriptPath -FilePath '.github/agents/nonexistent.md' 6>&1 | Out-String

            $output | Should -Match 'not found in tracking manifest'
        }

        It 'Does not modify manifest when file is not tracked' {
            $manifest = @{
                source = 'microsoft/hve-core'
                version = '1.0.0'
                files = @{
                    '.github/agents/task-implementor.agent.md' = @{
                        version = '1.0.0'
                        sha256 = 'abc123'
                        status = 'managed'
                    }
                }
            }
            $manifest | ConvertTo-Json -Depth 10 | Set-Content '.hve-tracking.json'

            & $script:scriptPath -FilePath '.github/agents/nonexistent.md'

            $updated = Get-Content '.hve-tracking.json' | ConvertFrom-Json -AsHashtable
            $updated.files['.github/agents/task-implementor.agent.md'].status | Should -Be 'managed'
        }
    }

    Context 'Parameter validation' {
        It 'Has a mandatory FilePath parameter' {
            $command = Get-Command $script:scriptPath
            $param = $command.Parameters['FilePath']
            $param | Should -Not -BeNullOrEmpty
            $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory } | Should -Not -BeNullOrEmpty
        }
    }
}
