#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

function script:New-TestPluginPackage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$PluginName
    )

    $pluginDir = Join-Path $RepoRoot "plugins/$PluginName"
    New-Item -ItemType Directory -Path $pluginDir -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $pluginDir '.github/plugin') -Force | Out-Null
    Set-Content -Path (Join-Path $pluginDir 'README.md') -Value "# $PluginName"
    $manifestContent = @{ name = $PluginName; description = 'A plugin'; version = '1.0.0' } |
        ConvertTo-Json -Depth 5
    Set-Content -Path (Join-Path $pluginDir '.github/plugin/plugin.json') -Value $manifestContent -Encoding UTF8

    return $pluginDir
}

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

Describe 'Test-PluginPackageContent' {
    It 'Accepts real package-local component paths and inline hook configuration' {
        $repoRoot = Join-Path $TestDrive 'valid-package'
        $pluginRoot = New-TestPluginPackage -RepoRoot $repoRoot -PluginName 'valid'
        New-Item -ItemType Directory -Path (Join-Path $pluginRoot 'agents/core') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $pluginRoot 'instructions/core') -Force | Out-Null
        Set-Content -Path (Join-Path $pluginRoot 'instructions/core/test.instructions.md') -Value 'test'
        $manifest = @{
            name = 'valid'; description = 'd'; version = '1.0.0'
            agents = @('agents/core/'); rules = @('instructions/core/')
        }
        $manifestContent = $manifest | ConvertTo-Json -Depth 10
        Set-Content -Path (Join-Path $pluginRoot '.github/plugin/plugin.json') -Value $manifestContent

        @(Test-PluginPackageContent -PluginRoot $pluginRoot -PluginName 'valid') |
            Should -BeNullOrEmpty
    }

    It 'Rejects a component path that escapes the plugin root' {
        $repoRoot = Join-Path $TestDrive 'escaping-package'
        $pluginRoot = New-TestPluginPackage -RepoRoot $repoRoot -PluginName 'escape'
        $manifest = @{
            name = 'escape'; description = 'd'; version = '1.0.0'; skills = @('../outside/')
        }
        $manifestContent = $manifest | ConvertTo-Json -Depth 10
        Set-Content -Path (Join-Path $pluginRoot '.github/plugin/plugin.json') -Value $manifestContent

        (@(Test-PluginPackageContent -PluginRoot $pluginRoot -PluginName 'escape') -join "`n") |
            Should -BeLike '*path escapes plugin root*../outside/*'
    }

    It 'Rejects links in a plugin package' {
        $repoRoot = Join-Path $TestDrive 'linked-package'
        $pluginRoot = New-TestPluginPackage -RepoRoot $repoRoot -PluginName 'linked'
        $target = Join-Path $repoRoot 'outside'
        New-Item -ItemType Directory -Path $target -Force | Out-Null
        $instructionsRoot = Join-Path $pluginRoot 'instructions'
        New-Item -ItemType Directory -Path $instructionsRoot -Force | Out-Null
        New-Item -ItemType SymbolicLink -Path (Join-Path $instructionsRoot 'shared') -Target $target | Out-Null

        (@(Test-PluginPackageContent -PluginRoot $pluginRoot -PluginName 'linked') -join "`n") |
            Should -BeLike '*contains a link or reparse point*'
    }

    It 'Rejects plugin manifest identity mismatch' {
        $repoRoot = Join-Path $TestDrive 'identity-package'
        $pluginRoot = New-TestPluginPackage -RepoRoot $repoRoot -PluginName 'identity'
        $manifestContent = @{ name = 'other'; description = 'd'; version = '1.0.0' } | ConvertTo-Json
        Set-Content -Path (Join-Path $pluginRoot '.github/plugin/plugin.json') -Value $manifestContent

        (@(Test-PluginPackageContent -PluginRoot $pluginRoot -PluginName 'identity') -join "`n") |
            Should -BeLike '*does not match marketplace plugin*'
    }

    It 'Rejects a component target with the wrong type' {
        $repoRoot = Join-Path $TestDrive 'wrong-type-package'
        $pluginRoot = New-TestPluginPackage -RepoRoot $repoRoot -PluginName 'wrong-type'
        $componentPath = Join-Path $pluginRoot 'agents/test'
        New-Item -ItemType Directory -Path (Split-Path -Parent $componentPath) -Force | Out-Null
        Set-Content -Path $componentPath -Value 'not a directory'
        $manifestContent = @{
            name = 'wrong-type'; description = 'd'; version = '1.0.0'; agents = @('agents/test')
        } | ConvertTo-Json
        Set-Content -Path (Join-Path $pluginRoot '.github/plugin/plugin.json') -Value $manifestContent

        (@(Test-PluginPackageContent -PluginRoot $pluginRoot -PluginName 'wrong-type') -join "`n") |
            Should -BeLike '*expected directory but found file*'
    }

    It 'Rejects a rules directory without instruction files' {
        $repoRoot = Join-Path $TestDrive 'empty-rules-package'
        $pluginRoot = New-TestPluginPackage -RepoRoot $repoRoot -PluginName 'empty-rules'
        New-Item -ItemType Directory -Path (Join-Path $pluginRoot 'instructions/test') -Force | Out-Null
        $manifestContent = @{
            name = 'empty-rules'; description = 'd'; version = '1.0.0'; rules = @('instructions/test')
        } | ConvertTo-Json
        Set-Content -Path (Join-Path $pluginRoot '.github/plugin/plugin.json') -Value $manifestContent

        (@(Test-PluginPackageContent -PluginRoot $pluginRoot -PluginName 'empty-rules') -join "`n") |
            Should -BeLike '*rules path contains no .instructions.md files*'
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
        New-TestPluginPackage -RepoRoot $script:repoRoot -PluginName 'my-plugin' | Out-Null
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
        New-TestPluginPackage -RepoRoot $script:repoRoot -PluginName 'my-plugin' | Out-Null
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
        New-TestPluginPackage -RepoRoot $script:repoRoot -PluginName 'my-plugin' | Out-Null
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
        New-TestPluginPackage -RepoRoot $script:repoRoot -PluginName 'actual-source' | Out-Null
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
        New-TestPluginPackage -RepoRoot $script:repoRoot -PluginName 'my-plugin' | Out-Null
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
        New-TestPluginPackage -RepoRoot $script:repoRoot -PluginName 'my-plugin' | Out-Null
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
        New-TestPluginPackage -RepoRoot $script:repoRoot -PluginName 'other-plugin' | Out-Null
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

Describe 'Invoke-MarketplaceValidation - in-package content' {
    BeforeAll {
        $script:repoRoot = Join-Path $TestDrive 'repo-in-package-content'
        $script:manifestDir = Join-Path $script:repoRoot '.github/plugin'
        New-Item -ItemType Directory -Path $script:manifestDir -Force | Out-Null
        Set-Content -Path (Join-Path $script:repoRoot 'package.json') -Value '{"version":"1.0.0"}'
    }

    It 'Returns error when README.md is missing from the packaged plugin' {
        $pluginDir = Join-Path $script:repoRoot 'plugins/missing-readme'
        New-Item -ItemType Directory -Path $pluginDir -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $pluginDir '.github/plugin') -Force | Out-Null
        @{ name = 'missing-readme'; description = 'd'; version = '1.0.0'; agents = @(); commands = @(); skills = @(); hooks = @() } |
            ConvertTo-Json -Depth 5 |
            Set-Content -Path (Join-Path $pluginDir '.github/plugin/plugin.json') -Encoding UTF8
        $json = @{
            name     = 'test'
            metadata = @{ description = 'd'; version = '1.0.0'; pluginRoot = 'plugins' }
            owner    = @{ name = 'owner' }
            plugins  = @(@{ name = 'missing-readme'; source = 'missing-readme'; description = 'd'; version = '1.0.0' })
        } | ConvertTo-Json -Depth 5
        Set-Content -Path (Join-Path $script:manifestDir 'marketplace.json') -Value $json

        $result = Invoke-MarketplaceValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
        $result.ErrorCount | Should -BeGreaterThan 0
    }

    It 'Returns error when a declared manifest component path is missing inside the package' {
        $pluginDir = New-TestPluginPackage -RepoRoot $script:repoRoot -PluginName 'missing-component'
        Remove-Item -Path (Join-Path $pluginDir 'README.md') -Force
        $pluginJson = @{
            name = 'missing-component'
            description = 'd'
            version = '1.0.0'
            agents = @('agents/example/')
            commands = @()
            skills = @()
            hooks = @()
        } | ConvertTo-Json -Depth 5
        Set-Content -Path (Join-Path $pluginDir '.github/plugin/plugin.json') -Value $pluginJson -Encoding UTF8
        $json = @{
            name     = 'test'
            metadata = @{ description = 'd'; version = '1.0.0'; pluginRoot = 'plugins' }
            owner    = @{ name = 'owner' }
            plugins  = @(@{ name = 'missing-component'; source = 'missing-component'; description = 'd'; version = '1.0.0' })
        } | ConvertTo-Json -Depth 5
        Set-Content -Path (Join-Path $script:manifestDir 'marketplace.json') -Value $json

        $result = Invoke-MarketplaceValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
        $result.ErrorCount | Should -BeGreaterThan 0
    }
}

Describe 'Invoke-MarketplaceValidation - JSON output' {
    BeforeEach {
        $script:repoRoot = Join-Path $TestDrive 'repo-json-output'
        $script:manifestDir = Join-Path $script:repoRoot '.github/plugin'
        New-Item -ItemType Directory -Path $script:manifestDir -Force | Out-Null
        New-TestPluginPackage -RepoRoot $script:repoRoot -PluginName 'my-plugin' | Out-Null
        Set-Content -Path (Join-Path $script:repoRoot 'package.json') -Value '{"version":"1.0.0"}'
    }

    It 'Writes report with expected schema for valid plugin validation' {
        $outputPath = Join-Path $TestDrive 'logs/marketplace-validation-results.json'
        $json = @{
            name     = 'test'
            metadata = @{ description = 'd'; version = '1.0.0'; pluginRoot = 'plugins' }
            owner    = @{ name = 'owner' }
            plugins  = @(
                @{ name = 'my-plugin'; source = 'my-plugin'; description = 'A plugin'; version = '1.0.0' }
            )
        } | ConvertTo-Json -Depth 5
        Set-Content -Path (Join-Path $script:manifestDir 'marketplace.json') -Value $json

        $result = Invoke-MarketplaceValidation -RepoRoot $script:repoRoot -OutputPath $outputPath
        $report = Get-Content -Path $outputPath -Raw | ConvertFrom-Json

        $result.Success | Should -BeTrue
        $report.Timestamp | Should -Not -BeNullOrEmpty
        { [DateTimeOffset]::Parse($report.Timestamp) } | Should -Not -Throw
        $report.ErrorCount | Should -Be 0
        $report.Results.Count | Should -Be 1
        $report.Results[0].PluginName | Should -Be 'my-plugin'
        $report.Results[0].IsValid | Should -BeTrue
        $report.Results[0].Errors | Should -BeNullOrEmpty
        $report.Results[0].Warnings | Should -BeNullOrEmpty
    }

    It 'Writes per-plugin errors into JSON results' {
        $outputPath = Join-Path $TestDrive 'logs/marketplace-validation-results.json'
        New-TestPluginPackage -RepoRoot $script:repoRoot -PluginName 'actual-source' | Out-Null
        $json = @{
            name     = 'test'
            metadata = @{ description = 'd'; version = '1.0.0'; pluginRoot = 'plugins' }
            owner    = @{ name = 'owner' }
            plugins  = @(
                @{ name = 'display-name'; source = 'actual-source'; description = 'A plugin'; version = '1.0.0' }
            )
        } | ConvertTo-Json -Depth 5
        Set-Content -Path (Join-Path $script:manifestDir 'marketplace.json') -Value $json

        $result = Invoke-MarketplaceValidation -RepoRoot $script:repoRoot -OutputPath $outputPath
        $report = Get-Content -Path $outputPath -Raw | ConvertFrom-Json
        $pluginResult = @($report.Results | Where-Object { $_.PluginName -eq 'display-name' })[0]

        $result.Success | Should -BeFalse
        $report.ErrorCount | Should -BeGreaterThan 0
        $pluginResult.IsValid | Should -BeFalse
        $pluginResult.Errors | Should -Contain "name does not match source 'actual-source'"
        $pluginResult.Warnings | Should -BeNullOrEmpty
    }
}
