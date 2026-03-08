#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

Describe 'upgrade-detection' -Tag 'Unit' {
    BeforeAll {
        $script:scriptPath = Join-Path $PSScriptRoot '../scripts/upgrade-detection.ps1'
        $script:testRoot = Join-Path ([System.IO.Path]::GetTempPath()) "hve-test-upgrade-$([guid]::NewGuid().ToString('N'))"
        $script:sourceRoot = Join-Path $script:testRoot 'source'
    }

    BeforeEach {
        New-Item -ItemType Directory -Path $script:testRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $script:sourceRoot -Force | Out-Null
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

    Context 'Fresh installation (no manifest)' {
        It 'Reports UPGRADE_MODE=false when no manifest exists' {
            $output = & $script:scriptPath -HveCoreBasePath $script:sourceRoot 6>&1 | Out-String

            $output | Should -Match 'UPGRADE_MODE=false'
        }
    }

    Context 'Existing installation' {
        BeforeEach {
            @{ version = '2.0.0' } | ConvertTo-Json | Set-Content (Join-Path $script:sourceRoot 'package.json')
        }

        It 'Reports UPGRADE_MODE=true when manifest exists' {
            $manifest = @{
                source = 'microsoft/hve-core'
                version = '1.0.0'
                collection = 'hve-core'
                files = @{}
            }
            $manifest | ConvertTo-Json -Depth 10 | Set-Content '.hve-tracking.json'

            $output = & $script:scriptPath -HveCoreBasePath $script:sourceRoot 6>&1 | Out-String

            $output | Should -Match 'UPGRADE_MODE=true'
        }

        It 'Reports installed and source versions' {
            $manifest = @{
                source = 'microsoft/hve-core'
                version = '1.0.0'
                collection = 'hve-core'
                files = @{}
            }
            $manifest | ConvertTo-Json -Depth 10 | Set-Content '.hve-tracking.json'

            $output = & $script:scriptPath -HveCoreBasePath $script:sourceRoot 6>&1 | Out-String

            $output | Should -Match 'INSTALLED_VERSION=1\.0\.0'
            $output | Should -Match 'SOURCE_VERSION=2\.0\.0'
        }

        It 'Reports VERSION_CHANGED=True when versions differ' {
            $manifest = @{
                source = 'microsoft/hve-core'
                version = '1.0.0'
                collection = 'hve-core'
                files = @{}
            }
            $manifest | ConvertTo-Json -Depth 10 | Set-Content '.hve-tracking.json'

            $output = & $script:scriptPath -HveCoreBasePath $script:sourceRoot 6>&1 | Out-String

            $output | Should -Match 'VERSION_CHANGED=True'
        }

        It 'Reports VERSION_CHANGED=False when versions match' {
            $manifest = @{
                source = 'microsoft/hve-core'
                version = '2.0.0'
                collection = 'hve-core'
                files = @{}
            }
            $manifest | ConvertTo-Json -Depth 10 | Set-Content '.hve-tracking.json'

            $output = & $script:scriptPath -HveCoreBasePath $script:sourceRoot 6>&1 | Out-String

            $output | Should -Match 'VERSION_CHANGED=False'
        }

        It 'Reports INSTALLED_COLLECTION from manifest' {
            $manifest = @{
                source = 'microsoft/hve-core'
                version = '1.0.0'
                collection = 'developer'
                files = @{}
            }
            $manifest | ConvertTo-Json -Depth 10 | Set-Content '.hve-tracking.json'

            $output = & $script:scriptPath -HveCoreBasePath $script:sourceRoot 6>&1 | Out-String

            $output | Should -Match 'INSTALLED_COLLECTION=developer'
        }

        It 'Defaults INSTALLED_COLLECTION to hve-core when not set in manifest' {
            $manifest = @{
                source = 'microsoft/hve-core'
                version = '1.0.0'
                files = @{}
            }
            $manifest | ConvertTo-Json -Depth 10 | Set-Content '.hve-tracking.json'

            $output = & $script:scriptPath -HveCoreBasePath $script:sourceRoot 6>&1 | Out-String

            $output | Should -Match 'INSTALLED_COLLECTION=hve-core'
        }
    }
}
