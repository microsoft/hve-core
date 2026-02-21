#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    . $PSScriptRoot/../../plugins/Validate-Marketplace.ps1
}

Describe 'Test-PluginSourceFormat' {
    It 'Returns empty string for valid source' {
        $result = Test-PluginSourceFormat -Source 'hve-core'
        $result | Should -BeNullOrEmpty
    }

    It 'Returns error for source with forward slash' {
        $result = Test-PluginSourceFormat -Source 'path/to/plugin'
        $result | Should -BeLike '*must not contain path separators*'
    }

    It 'Returns error for source with backslash' {
        $result = Test-PluginSourceFormat -Source 'path\to\plugin'
        $result | Should -BeLike '*must not contain path separators*'
    }

    It 'Returns error for source with relative path prefix' {
        $result = Test-PluginSourceFormat -Source './my-plugin'
        $result | Should -BeLike '*must not contain*'
    }
}

Describe 'Test-PluginSourceDirectory' {
    BeforeAll {
        $script:pluginsRoot = Join-Path $TestDrive 'plugins'
        New-Item -ItemType Directory -Path (Join-Path $script:pluginsRoot 'existing-plugin') -Force | Out-Null
    }

    It 'Returns empty string when directory exists' {
        $result = Test-PluginSourceDirectory -Source 'existing-plugin' -PluginsRoot $script:pluginsRoot
        $result | Should -BeNullOrEmpty
    }

    It 'Returns error when directory does not exist' {
        $result = Test-PluginSourceDirectory -Source 'missing-plugin' -PluginsRoot $script:pluginsRoot
        $result | Should -BeLike '*plugin source directory not found*'
    }
}

Describe 'Invoke-MarketplaceValidation - missing manifest' {
    BeforeAll {
        $script:repoRoot = Join-Path $TestDrive 'repo-no-manifest'
        New-Item -ItemType Directory -Path $script:repoRoot -Force | Out-Null
    }

    It 'Returns failure when marketplace.json does not exist' {
        $result = Invoke-MarketplaceValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
        $result.ErrorCount | Should -Be 1
    }
}

Describe 'Invoke-MarketplaceValidation - invalid JSON' {
    BeforeAll {
        $script:repoRoot = Join-Path $TestDrive 'repo-bad-json'
        $manifestDir = Join-Path $script:repoRoot '.github/plugin'
        New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null
        Set-Content -Path (Join-Path $manifestDir 'marketplace.json') -Value '{ invalid json }'
    }

    It 'Returns failure for malformed JSON' {
        $result = Invoke-MarketplaceValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
        $result.ErrorCount | Should -Be 1
    }
}

Describe 'Invoke-MarketplaceValidation - missing required fields' {
    BeforeAll {
        $script:repoRoot = Join-Path $TestDrive 'repo-missing-fields'
        $manifestDir = Join-Path $script:repoRoot '.github/plugin'
        New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null
        # Missing 'owner' and 'plugins'
        $json = @{ name = 'test'; metadata = @{ description = 'd'; version = '1.0.0'; pluginRoot = 'plugins' } } | ConvertTo-Json -Depth 5
        Set-Content -Path (Join-Path $manifestDir 'marketplace.json') -Value $json
    }

    It 'Returns errors for missing top-level fields' {
        $result = Invoke-MarketplaceValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
        $result.ErrorCount | Should -BeGreaterOrEqual 2
    }
}

Describe 'Invoke-MarketplaceValidation - missing metadata fields' {
    BeforeAll {
        $script:repoRoot = Join-Path $TestDrive 'repo-missing-metadata'
        $manifestDir = Join-Path $script:repoRoot '.github/plugin'
        New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null
        $pluginsDir = Join-Path $script:repoRoot 'plugins/my-plugin'
        New-Item -ItemType Directory -Path $pluginsDir -Force | Out-Null
        # metadata missing 'version' and 'pluginRoot'
        $json = @{
            name     = 'test'
            metadata = @{ description = 'd' }
            owner    = @{ name = 'owner' }
            plugins  = @(@{ name = 'my-plugin'; source = 'my-plugin'; description = 'd'; version = '1.0.0' })
        } | ConvertTo-Json -Depth 5
        Set-Content -Path (Join-Path $manifestDir 'marketplace.json') -Value $json
    }

    It 'Returns errors for missing metadata fields' {
        $result = Invoke-MarketplaceValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
        $result.ErrorCount | Should -BeGreaterOrEqual 2
    }
}

Describe 'Invoke-MarketplaceValidation - missing owner name' {
    BeforeAll {
        $script:repoRoot = Join-Path $TestDrive 'repo-missing-owner'
        $manifestDir = Join-Path $script:repoRoot '.github/plugin'
        New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null
        $pluginsDir = Join-Path $script:repoRoot 'plugins/my-plugin'
        New-Item -ItemType Directory -Path $pluginsDir -Force | Out-Null
        Set-Content -Path (Join-Path $script:repoRoot 'package.json') -Value '{"version":"1.0.0"}'
        $json = @{
            name     = 'test'
            metadata = @{ description = 'd'; version = '1.0.0'; pluginRoot = 'plugins' }
            owner    = @{}
            plugins  = @(@{ name = 'my-plugin'; source = 'my-plugin'; description = 'd'; version = '1.0.0' })
        } | ConvertTo-Json -Depth 5
        Set-Content -Path (Join-Path $manifestDir 'marketplace.json') -Value $json
    }

    It 'Returns error for missing owner name' {
        $result = Invoke-MarketplaceValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
        $result.ErrorCount | Should -BeGreaterOrEqual 1
    }
}

Describe 'Invoke-MarketplaceValidation - version mismatch' {
    BeforeAll {
        $script:repoRoot = Join-Path $TestDrive 'repo-version-mismatch'
        $manifestDir = Join-Path $script:repoRoot '.github/plugin'
        New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null
        $pluginsDir = Join-Path $script:repoRoot 'plugins/my-plugin'
        New-Item -ItemType Directory -Path $pluginsDir -Force | Out-Null
        Set-Content -Path (Join-Path $script:repoRoot 'package.json') -Value '{"version":"2.0.0"}'
        $json = @{
            name     = 'test'
            metadata = @{ description = 'd'; version = '1.0.0'; pluginRoot = 'plugins' }
            owner    = @{ name = 'owner' }
            plugins  = @(@{ name = 'my-plugin'; source = 'my-plugin'; description = 'd'; version = '1.0.0' })
        } | ConvertTo-Json -Depth 5
        Set-Content -Path (Join-Path $manifestDir 'marketplace.json') -Value $json
    }

    It 'Returns error when metadata version does not match package.json' {
        $result = Invoke-MarketplaceValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
        $result.ErrorCount | Should -BeGreaterOrEqual 1
    }
}

Describe 'Invoke-MarketplaceValidation - empty plugins array' {
    BeforeAll {
        $script:repoRoot = Join-Path $TestDrive 'repo-empty-plugins'
        $manifestDir = Join-Path $script:repoRoot '.github/plugin'
        New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null
        Set-Content -Path (Join-Path $script:repoRoot 'package.json') -Value '{"version":"1.0.0"}'
        $json = @{
            name     = 'test'
            metadata = @{ description = 'd'; version = '1.0.0'; pluginRoot = 'plugins' }
            owner    = @{ name = 'owner' }
            plugins  = @()
        } | ConvertTo-Json -Depth 5
        Set-Content -Path (Join-Path $manifestDir 'marketplace.json') -Value $json
    }

    It 'Returns error for empty plugins array' {
        $result = Invoke-MarketplaceValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
        $result.ErrorCount | Should -BeGreaterOrEqual 1
    }
}

Describe 'Invoke-MarketplaceValidation - duplicate plugin names' {
    BeforeAll {
        $script:repoRoot = Join-Path $TestDrive 'repo-dupes'
        $manifestDir = Join-Path $script:repoRoot '.github/plugin'
        New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:repoRoot 'plugins/my-plugin') -Force | Out-Null
        Set-Content -Path (Join-Path $script:repoRoot 'package.json') -Value '{"version":"1.0.0"}'
        $json = @{
            name     = 'test'
            metadata = @{ description = 'd'; version = '1.0.0'; pluginRoot = 'plugins' }
            owner    = @{ name = 'owner' }
            plugins  = @(
                @{ name = 'my-plugin'; source = 'my-plugin'; description = 'd1'; version = '1.0.0' }
                @{ name = 'my-plugin'; source = 'my-plugin'; description = 'd2'; version = '1.0.0' }
            )
        } | ConvertTo-Json -Depth 5
        Set-Content -Path (Join-Path $manifestDir 'marketplace.json') -Value $json
    }

    It 'Returns error for duplicate plugin names' {
        $result = Invoke-MarketplaceValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
        $result.ErrorCount | Should -BeGreaterOrEqual 1
    }
}

Describe 'Invoke-MarketplaceValidation - plugin source errors' {
    BeforeAll {
        $script:repoRoot = Join-Path $TestDrive 'repo-source-errors'
        $manifestDir = Join-Path $script:repoRoot '.github/plugin'
        New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null
        Set-Content -Path (Join-Path $script:repoRoot 'package.json') -Value '{"version":"1.0.0"}'
        $json = @{
            name     = 'test'
            metadata = @{ description = 'd'; version = '1.0.0'; pluginRoot = 'plugins' }
            owner    = @{ name = 'owner' }
            plugins  = @(
                @{ name = 'bad/source'; source = 'bad/source'; description = 'd'; version = '1.0.0' }
            )
        } | ConvertTo-Json -Depth 5
        Set-Content -Path (Join-Path $manifestDir 'marketplace.json') -Value $json
    }

    It 'Returns error for plugin with path separator in source' {
        $result = Invoke-MarketplaceValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
        $result.ErrorCount | Should -BeGreaterOrEqual 1
    }
}

Describe 'Invoke-MarketplaceValidation - name-source mismatch' {
    BeforeAll {
        $script:repoRoot = Join-Path $TestDrive 'repo-name-mismatch'
        $manifestDir = Join-Path $script:repoRoot '.github/plugin'
        New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:repoRoot 'plugins/actual-source') -Force | Out-Null
        Set-Content -Path (Join-Path $script:repoRoot 'package.json') -Value '{"version":"1.0.0"}'
        $json = @{
            name     = 'test'
            metadata = @{ description = 'd'; version = '1.0.0'; pluginRoot = 'plugins' }
            owner    = @{ name = 'owner' }
            plugins  = @(
                @{ name = 'display-name'; source = 'actual-source'; description = 'd'; version = '1.0.0' }
            )
        } | ConvertTo-Json -Depth 5
        Set-Content -Path (Join-Path $manifestDir 'marketplace.json') -Value $json
    }

    It 'Returns error when plugin name does not match source' {
        $result = Invoke-MarketplaceValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
        $result.ErrorCount | Should -BeGreaterOrEqual 1
    }
}

Describe 'Invoke-MarketplaceValidation - plugin version mismatch' {
    BeforeAll {
        $script:repoRoot = Join-Path $TestDrive 'repo-plugin-version'
        $manifestDir = Join-Path $script:repoRoot '.github/plugin'
        New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:repoRoot 'plugins/my-plugin') -Force | Out-Null
        Set-Content -Path (Join-Path $script:repoRoot 'package.json') -Value '{"version":"2.0.0"}'
        $json = @{
            name     = 'test'
            metadata = @{ description = 'd'; version = '2.0.0'; pluginRoot = 'plugins' }
            owner    = @{ name = 'owner' }
            plugins  = @(
                @{ name = 'my-plugin'; source = 'my-plugin'; description = 'd'; version = '1.0.0' }
            )
        } | ConvertTo-Json -Depth 5
        Set-Content -Path (Join-Path $manifestDir 'marketplace.json') -Value $json
    }

    It 'Returns error when plugin version does not match package.json' {
        $result = Invoke-MarketplaceValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
        $result.ErrorCount | Should -BeGreaterOrEqual 1
    }
}

Describe 'Invoke-MarketplaceValidation - missing plugin fields' {
    BeforeAll {
        $script:repoRoot = Join-Path $TestDrive 'repo-missing-plugin-fields'
        $manifestDir = Join-Path $script:repoRoot '.github/plugin'
        New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null
        Set-Content -Path (Join-Path $script:repoRoot 'package.json') -Value '{"version":"1.0.0"}'
        # Plugin missing 'description' and 'version'
        $json = @{
            name     = 'test'
            metadata = @{ description = 'd'; version = '1.0.0'; pluginRoot = 'plugins' }
            owner    = @{ name = 'owner' }
            plugins  = @(
                @{ name = 'my-plugin'; source = 'my-plugin' }
            )
        } | ConvertTo-Json -Depth 5
        Set-Content -Path (Join-Path $manifestDir 'marketplace.json') -Value $json
    }

    It 'Returns errors for missing plugin-level fields' {
        $result = Invoke-MarketplaceValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
        $result.ErrorCount | Should -BeGreaterOrEqual 2
    }
}

Describe 'Invoke-MarketplaceValidation - valid manifest' {
    BeforeAll {
        $script:repoRoot = Join-Path $TestDrive 'repo-valid'
        $manifestDir = Join-Path $script:repoRoot '.github/plugin'
        New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:repoRoot 'plugins/my-plugin') -Force | Out-Null
        Set-Content -Path (Join-Path $script:repoRoot 'package.json') -Value '{"version":"1.0.0"}'
        $json = @{
            name     = 'test'
            metadata = @{ description = 'd'; version = '1.0.0'; pluginRoot = 'plugins' }
            owner    = @{ name = 'owner' }
            plugins  = @(
                @{ name = 'my-plugin'; source = 'my-plugin'; description = 'A plugin'; version = '1.0.0' }
            )
        } | ConvertTo-Json -Depth 5
        Set-Content -Path (Join-Path $manifestDir 'marketplace.json') -Value $json
    }

    It 'Returns success for a valid manifest' {
        $result = Invoke-MarketplaceValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
        $result.ErrorCount | Should -Be 0
    }

    It 'Returns success with multiple valid plugins' {
        New-Item -ItemType Directory -Path (Join-Path $script:repoRoot 'plugins/other-plugin') -Force | Out-Null
        $json = @{
            name     = 'test'
            metadata = @{ description = 'd'; version = '1.0.0'; pluginRoot = 'plugins' }
            owner    = @{ name = 'owner' }
            plugins  = @(
                @{ name = 'my-plugin'; source = 'my-plugin'; description = 'A plugin'; version = '1.0.0' }
                @{ name = 'other-plugin'; source = 'other-plugin'; description = 'Another'; version = '1.0.0' }
            )
        } | ConvertTo-Json -Depth 5
        $manifestDir = Join-Path $script:repoRoot '.github/plugin'
        Set-Content -Path (Join-Path $manifestDir 'marketplace.json') -Value $json

        $result = Invoke-MarketplaceValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
        $result.ErrorCount | Should -Be 0
    }
}
