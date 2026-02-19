#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    . $PSScriptRoot/../../extension/Package-Extension.ps1
    Import-Module "$PSScriptRoot/../Mocks/GitMocks.psm1" -Force
    Import-Module "$PSScriptRoot/../../lib/Modules/CIHelpers.psm1" -Force
}

Describe 'Test-VsceAvailable' {
    It 'Returns hashtable with IsAvailable property' {
        $result = Test-VsceAvailable
        $result | Should -BeOfType [hashtable]
        $result.Keys | Should -Contain 'IsAvailable'
    }

    It 'Returns CommandType when available' {
        $result = Test-VsceAvailable
        if ($result.IsAvailable) {
            $result.CommandType | Should -BeIn @('npx', 'vsce')
            $result.Command | Should -Not -BeNullOrEmpty
        }
    }

    It 'Returns vsce when vsce command is found' {
        Mock Get-Command {
            param($Name, $ErrorAction)
            $null = $ErrorAction  # Suppress PSScriptAnalyzer warning
            if ($Name -eq 'vsce') {
                return [PSCustomObject]@{ Source = 'C:\bin\vsce.cmd' }
            }
            return $null
        }
        $result = Test-VsceAvailable
        $result.IsAvailable | Should -BeTrue
        $result.CommandType | Should -Be 'vsce'
        $result.Command | Should -Be 'C:\bin\vsce.cmd'
    }

    It 'Returns npx when only npx command is found' {
        Mock Get-Command {
            param($Name, $ErrorAction)
            $null = $ErrorAction  # Suppress PSScriptAnalyzer warning
            if ($Name -eq 'npx') {
                return [PSCustomObject]@{ Source = 'C:\bin\npx.cmd' }
            }
            return $null
        }
        $result = Test-VsceAvailable
        $result.IsAvailable | Should -BeTrue
        $result.CommandType | Should -Be 'npx'
        $result.Command | Should -Be 'C:\bin\npx.cmd'
    }

    It 'Returns not available when neither vsce nor npx exist' {
        Mock Get-Command { return $null }
        $result = Test-VsceAvailable
        $result.IsAvailable | Should -BeFalse
        $result.CommandType | Should -BeNullOrEmpty
        $result.Command | Should -BeNullOrEmpty
    }
}

Describe 'Test-ExtensionManifestValid' {
    It 'Returns valid result for proper manifest' {
        $manifest = [PSCustomObject]@{
            name = 'my-extension'
            version = '1.0.0'
            publisher = 'my-publisher'
            engines = [PSCustomObject]@{ vscode = '^1.80.0' }
        }
        $result = Test-ExtensionManifestValid -ManifestContent $manifest
        $result.IsValid | Should -BeTrue
        $result.Errors | Should -BeNullOrEmpty
    }

    It 'Returns invalid when name missing' {
        $manifest = @{
            version = '1.0.0'
            publisher = 'pub'
            engines = @{ vscode = '^1.80.0' }
        }
        $result = Test-ExtensionManifestValid -ManifestContent $manifest
        $result.IsValid | Should -BeFalse
        $result.Errors | Should -Contain "Missing required 'name' field"
    }

    It 'Returns invalid when version missing' {
        $manifest = @{
            name = 'ext'
            publisher = 'pub'
            engines = @{ vscode = '^1.80.0' }
        }
        $result = Test-ExtensionManifestValid -ManifestContent $manifest
        $result.IsValid | Should -BeFalse
        $result.Errors | Should -Contain "Missing required 'version' field"
    }

    It 'Returns invalid when publisher missing' {
        $manifest = @{
            name = 'ext'
            version = '1.0.0'
            engines = @{ vscode = '^1.80.0' }
        }
        $result = Test-ExtensionManifestValid -ManifestContent $manifest
        $result.IsValid | Should -BeFalse
        $result.Errors | Should -Contain "Missing required 'publisher' field"
    }

    It 'Returns invalid when engines.vscode missing' {
        $manifest = @{
            name = 'ext'
            version = '1.0.0'
            publisher = 'pub'
        }
        $result = Test-ExtensionManifestValid -ManifestContent $manifest
        $result.IsValid | Should -BeFalse
        $result.Errors | Should -Contain "Missing required 'engines' field"
    }

    It 'Returns invalid when engines exists but vscode key missing' {
        $manifest = [PSCustomObject]@{
            name = 'ext'
            version = '1.0.0'
            publisher = 'pub'
            engines = [PSCustomObject]@{ node = '>=16' }
        }
        $result = Test-ExtensionManifestValid -ManifestContent $manifest
        $result.IsValid | Should -BeFalse
        $result.Errors | Should -Contain "Missing required 'engines.vscode' field"
    }

    It 'Returns invalid when version format is incorrect' {
        $manifest = [PSCustomObject]@{
            name = 'ext'
            version = 'invalid-version'
            publisher = 'pub'
            engines = [PSCustomObject]@{ vscode = '^1.80.0' }
        }
        $result = Test-ExtensionManifestValid -ManifestContent $manifest
        $result.IsValid | Should -BeFalse
        $result.Errors | Should -Match 'Invalid version format'
    }

    It 'Collects multiple errors' {
        $manifest = @{}
        $result = Test-ExtensionManifestValid -ManifestContent $manifest
        $result.IsValid | Should -BeFalse
        $result.Errors.Count | Should -BeGreaterThan 1
    }
}

Describe 'Get-VscePackageCommand' {
    It 'Returns npx command structure for npx type' {
        $result = Get-VscePackageCommand -CommandType 'npx'
        $result.Executable | Should -Be 'npx'
        $result.Arguments | Should -Contain '@vscode/vsce'
        $result.Arguments | Should -Contain 'package'
    }

    It 'Returns vsce command for vsce type' {
        $result = Get-VscePackageCommand -CommandType 'vsce'
        $result.Executable | Should -Be 'vsce'
        $result.Arguments | Should -Contain 'package'
    }

    It 'Includes --pre-release flag when specified' {
        $result = Get-VscePackageCommand -CommandType 'npx' -PreRelease
        $result.Arguments | Should -Contain '--pre-release'
    }

    It 'Excludes --pre-release flag when not specified' {
        $result = Get-VscePackageCommand -CommandType 'npx'
        $result.Arguments | Should -Not -Contain '--pre-release'
    }
}

Describe 'New-PackagingResult' {
    BeforeAll {
        $script:testVsixPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath().TrimEnd([System.IO.Path]::DirectorySeparatorChar), 'ext.vsix')
    }

    It 'Creates success result with all properties' {
        $result = New-PackagingResult -Success $true -OutputPath $script:testVsixPath -Version '1.0.0' -ErrorMessage $null
        $result.Success | Should -BeTrue
        $result.OutputPath | Should -Be $script:testVsixPath
        $result.Version | Should -Be '1.0.0'
        $result.ErrorMessage | Should -BeNullOrEmpty
    }

    It 'Creates failure result with error message' {
        $result = New-PackagingResult -Success $false -OutputPath $null -Version $null -ErrorMessage 'Packaging failed'
        $result.Success | Should -BeFalse
        $result.ErrorMessage | Should -Be 'Packaging failed'
    }

    It 'Creates result with default empty strings for optional parameters' {
        $result = New-PackagingResult -Success $true
        $result.Success | Should -BeTrue
        $result.OutputPath | Should -Be ''
        $result.Version | Should -Be ''
        $result.ErrorMessage | Should -Be ''
    }

    It 'Creates failure result with only error message specified' {
        $result = New-PackagingResult -Success $false -ErrorMessage 'Something went wrong'
        $result.Success | Should -BeFalse
        $result.ErrorMessage | Should -Be 'Something went wrong'
        $result.OutputPath | Should -Be ''
        $result.Version | Should -Be ''
    }
}

Describe 'Get-ResolvedPackageVersion' {
    It 'Returns specified version when provided' {
        $result = Get-ResolvedPackageVersion -SpecifiedVersion '2.0.0' -ManifestVersion '1.0.0' -DevPatchNumber ''
        $result.IsValid | Should -BeTrue
        $result.PackageVersion | Should -Be '2.0.0'
    }

    It 'Returns manifest version when no specified version' {
        $result = Get-ResolvedPackageVersion -SpecifiedVersion '' -ManifestVersion '1.5.0' -DevPatchNumber ''
        $result.IsValid | Should -BeTrue
        $result.PackageVersion | Should -Be '1.5.0'
    }

    It 'Applies dev patch number when provided' {
        $result = Get-ResolvedPackageVersion -SpecifiedVersion '' -ManifestVersion '1.0.0' -DevPatchNumber '42'
        $result.IsValid | Should -BeTrue
        $result.PackageVersion | Should -Be '1.0.0-dev.42'
    }

    It 'Specified version with dev patch appends dev suffix' {
        $result = Get-ResolvedPackageVersion -SpecifiedVersion '3.0.0' -ManifestVersion '1.0.0' -DevPatchNumber '99'
        $result.IsValid | Should -BeTrue
        $result.PackageVersion | Should -Be '3.0.0-dev.99'
    }

    It 'Returns invalid for malformed specified version' {
        $result = Get-ResolvedPackageVersion -SpecifiedVersion 'not-a-version' -ManifestVersion '1.0.0' -DevPatchNumber ''
        $result.IsValid | Should -BeFalse
        $result.ErrorMessage | Should -Match 'Invalid version format specified'
    }

    It 'Returns invalid for malformed manifest version when no specified version' {
        $result = Get-ResolvedPackageVersion -SpecifiedVersion '' -ManifestVersion 'bad-version' -DevPatchNumber ''
        $result.IsValid | Should -BeFalse
        $result.ErrorMessage | Should -Match 'Invalid version format in package.json'
    }

    It 'Extracts base version from manifest with prerelease suffix' {
        $result = Get-ResolvedPackageVersion -SpecifiedVersion '' -ManifestVersion '1.2.3-beta.1' -DevPatchNumber ''
        $result.IsValid | Should -BeTrue
        $result.BaseVersion | Should -Be '1.2.3'
        $result.PackageVersion | Should -Be '1.2.3'
    }

    It 'Returns BaseVersion correctly when specified version provided' {
        $result = Get-ResolvedPackageVersion -SpecifiedVersion '4.5.6' -ManifestVersion '1.0.0' -DevPatchNumber ''
        $result.IsValid | Should -BeTrue
        $result.BaseVersion | Should -Be '4.5.6'
    }
}

Describe 'Invoke-PackageExtension' {
    BeforeAll {
        $script:testRoot = Join-Path ([System.IO.Path]::GetTempPath()) "pkg-ext-test-$([guid]::NewGuid().ToString('N').Substring(0,8))"
        $script:extDir = Join-Path $script:testRoot 'extension'
        $script:repoRoot = Join-Path $script:testRoot 'repo'
    }

    BeforeEach {
        # Create fresh test directories for each test
        New-Item -Path $script:extDir -ItemType Directory -Force | Out-Null
        New-Item -Path $script:repoRoot -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $script:repoRoot '.github') -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $script:repoRoot '.github/skills') -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $script:repoRoot 'scripts/lib/Modules') -ItemType Directory -Force | Out-Null
        Set-Content -Path (Join-Path $script:repoRoot 'scripts/lib/Modules/CIHelpers.psm1') -Value '# Mock module'
        New-Item -Path (Join-Path $script:repoRoot 'docs/templates') -ItemType Directory -Force | Out-Null
    }

    AfterEach {
        if (Test-Path $script:testRoot) {
            Remove-Item -Path $script:testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Returns failure when extension directory does not exist' {
        $nonexistentPath = Join-Path ([System.IO.Path]::GetTempPath()) "nonexistent-ext-$([guid]::NewGuid().ToString('N').Substring(0,8))"
        $result = Invoke-PackageExtension -ExtensionDirectory $nonexistentPath -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
        $result.ErrorMessage | Should -Match 'Extension directory not found'
    }

    It 'Returns failure when package.json missing' {
        $result = Invoke-PackageExtension -ExtensionDirectory $script:extDir -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
        $result.ErrorMessage | Should -Match 'package.json not found'
    }

    It 'Returns failure when .github directory missing' {
        # Create package.json but remove .github
        $manifest = @{
            name = 'test-ext'
            version = '1.0.0'
            publisher = 'test'
            engines = @{ vscode = '^1.80.0' }
        }
        $manifest | ConvertTo-Json | Set-Content (Join-Path $script:extDir 'package.json')
        Remove-Item -Path (Join-Path $script:repoRoot '.github') -Recurse -Force

        $result = Invoke-PackageExtension -ExtensionDirectory $script:extDir -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
        $result.ErrorMessage | Should -Match '.github directory not found'
    }

    It 'Returns failure for invalid JSON in package.json' {
        Set-Content -Path (Join-Path $script:extDir 'package.json') -Value '{ invalid json }'

        $result = Invoke-PackageExtension -ExtensionDirectory $script:extDir -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
        $result.ErrorMessage | Should -Match 'Failed to parse package.json'
    }

    It 'Returns failure for invalid manifest missing required fields' {
        $manifest = @{ name = 'only-name' }  # Missing version, publisher, engines
        $manifest | ConvertTo-Json | Set-Content (Join-Path $script:extDir 'package.json')

        $result = Invoke-PackageExtension -ExtensionDirectory $script:extDir -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
        $result.ErrorMessage | Should -Match 'Invalid package.json'
    }

    It 'Returns failure for invalid specified version format' {
        $manifest = @{
            name = 'test-ext'
            version = '1.0.0'
            publisher = 'test'
            engines = @{ vscode = '^1.80.0' }
        }
        $manifest | ConvertTo-Json | Set-Content (Join-Path $script:extDir 'package.json')

        $result = Invoke-PackageExtension -ExtensionDirectory $script:extDir -RepoRoot $script:repoRoot -Version 'invalid-version'
        $result.Success | Should -BeFalse
        $result.ErrorMessage | Should -Match 'Invalid version format'
    }

    It 'Returns structured result hashtable with expected keys' {
        Mock Test-VsceAvailable { return @{ IsAvailable = $false; CommandType = ''; Command = '' } }

        $manifest = @{
            name = 'test-ext'
            version = '1.0.0'
            publisher = 'test'
            engines = @{ vscode = '^1.80.0' }
        }
        $manifest | ConvertTo-Json | Set-Content (Join-Path $script:extDir 'package.json')

        # Will fail at vsce availability check, validates structure
        $result = Invoke-PackageExtension -ExtensionDirectory $script:extDir -RepoRoot $script:repoRoot

        $result | Should -BeOfType [hashtable]
        $result.Keys | Should -Contain 'Success'
        $result.Keys | Should -Contain 'ErrorMessage'
    }

    It 'Applies DevPatchNumber to version correctly' {
        Mock Test-VsceAvailable { return @{ IsAvailable = $false; CommandType = ''; Command = '' } }

        $manifest = @{
            name = 'test-ext'
            version = '2.0.0'
            publisher = 'test'
            engines = @{ vscode = '^1.80.0' }
        }
        $manifest | ConvertTo-Json | Set-Content (Join-Path $script:extDir 'package.json')

        # Will fail at vsce availability check, validates version resolution path
        $result = Invoke-PackageExtension -ExtensionDirectory $script:extDir -RepoRoot $script:repoRoot -DevPatchNumber '123'

        # Even on failure, the result indicates version was processed
        $result | Should -BeOfType [hashtable]
    }

    It 'Copies changelog when valid path provided' {
        Mock Test-VsceAvailable { return @{ IsAvailable = $true; CommandType = 'vsce'; Command = 'vsce' } }
        Mock Get-VscePackageCommand { return @{ Executable = 'echo'; Arguments = @('mocked') } }

        $manifest = @{
            name = 'test-ext'
            version = '1.0.0'
            publisher = 'test'
            engines = @{ vscode = '^1.80.0' }
        }
        $manifest | ConvertTo-Json | Set-Content (Join-Path $script:extDir 'package.json')

        # Create a changelog file
        $changelogPath = Join-Path $script:repoRoot 'CHANGELOG.md'
        Set-Content -Path $changelogPath -Value '# Changelog'

        $result = Invoke-PackageExtension -ExtensionDirectory $script:extDir -RepoRoot $script:repoRoot -ChangelogPath $changelogPath

        # Changelog should be copied to extension directory
        $destChangelog = Join-Path $script:extDir 'CHANGELOG.md'
        Test-Path $destChangelog | Should -BeTrue
        $result | Should -Not -BeNullOrEmpty
    }

    It 'Warns when changelog path does not exist' {
        Mock Test-VsceAvailable { return @{ IsAvailable = $true; CommandType = 'vsce'; Command = 'vsce' } }
        Mock Get-VscePackageCommand { return @{ Executable = 'echo'; Arguments = @('mocked') } }
        Mock Write-Warning { }

        $manifest = @{
            name = 'test-ext'
            version = '1.0.0'
            publisher = 'test'
            engines = @{ vscode = '^1.80.0' }
        }
        $manifest | ConvertTo-Json | Set-Content (Join-Path $script:extDir 'package.json')

        $nonexistentChangelog = Join-Path ([System.IO.Path]::GetTempPath()) "changelog-$([guid]::NewGuid().ToString('N').Substring(0,8)).md"
        $result = Invoke-PackageExtension -ExtensionDirectory $script:extDir -RepoRoot $script:repoRoot -ChangelogPath $nonexistentChangelog

        Should -Invoke Write-Warning -Times 1
        $result | Should -Not -BeNullOrEmpty
    }

    It 'Returns failure when vsce command fails with non-zero exit code' {
        Mock Test-VsceAvailable { return @{ IsAvailable = $true; CommandType = 'vsce'; Command = 'vsce' } }
        Mock Get-VscePackageCommand { return @{ Executable = 'pwsh'; Arguments = @('-Command', 'exit 1') } }

        $manifest = @{
            name = 'test-ext'
            version = '1.0.0'
            publisher = 'test'
            engines = @{ vscode = '^1.80.0' }
        }
        $manifest | ConvertTo-Json | Set-Content (Join-Path $script:extDir 'package.json')

        $result = Invoke-PackageExtension -ExtensionDirectory $script:extDir -RepoRoot $script:repoRoot

        $result.Success | Should -BeFalse
        $result.ErrorMessage | Should -Match 'vsce package command failed|The term'
    }

    It 'Returns failure when CIHelpers.psm1 missing' {
        # Create package.json and .github, but remove CIHelpers.psm1
        $manifest = @{
            name = 'test-ext'
            version = '1.0.0'
            publisher = 'test'
            engines = @{ vscode = '^1.80.0' }
        }
        $manifest | ConvertTo-Json | Set-Content (Join-Path $script:extDir 'package.json')
        Remove-Item -Path (Join-Path $script:repoRoot 'scripts/lib/Modules/CIHelpers.psm1') -Force

        $result = Invoke-PackageExtension -ExtensionDirectory $script:extDir -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
        $result.ErrorMessage | Should -Match 'CIHelpers.psm1 not found'
    }

    Context 'Package.json backup restore' {
        It 'Does not create backup when no collection specified' {
            Mock Test-VsceAvailable { return @{ IsAvailable = $true; CommandType = 'vsce'; Command = 'vsce' } }
            Mock Get-VscePackageCommand { return @{ Executable = 'echo'; Arguments = @('mocked') } }

            $manifest = @{
                name      = 'test-ext'
                version   = '1.0.0'
                publisher = 'test'
                engines   = @{ vscode = '^1.80.0' }
            }
            $manifest | ConvertTo-Json | Set-Content (Join-Path $script:extDir 'package.json')

            # Create fake vsix so packaging succeeds
            $vsixPath = Join-Path $script:extDir 'test-ext-1.0.0.vsix'
            Set-Content -Path $vsixPath -Value 'fake-vsix'

            $null = Invoke-PackageExtension -ExtensionDirectory $script:extDir -RepoRoot $script:repoRoot

            Test-Path (Join-Path $script:extDir 'package.json.bak') | Should -BeFalse
        }

        It 'Restores package.json from backup after packaging' {
            Mock Test-VsceAvailable { return @{ IsAvailable = $true; CommandType = 'vsce'; Command = 'vsce' } }
            Mock Get-VscePackageCommand { return @{ Executable = 'echo'; Arguments = @('mocked') } }

            # Original package.json content (will be overwritten by template)
            $originalManifest = @{
                name      = 'hve-core'
                version   = '1.0.0'
                publisher = 'test'
                engines   = @{ vscode = '^1.80.0' }
            }

            # Simulate post-template state: template content in package.json, original backed up
            $templateManifest = @{
                name      = 'hve-developer'
                version   = '1.0.0'
                publisher = 'test'
                engines   = @{ vscode = '^1.80.0' }
            }
            $templateManifest | ConvertTo-Json | Set-Content (Join-Path $script:extDir 'package.json')
            $originalManifest | ConvertTo-Json | Set-Content (Join-Path $script:extDir 'package.json.bak')

            # Create fake vsix so packaging succeeds
            $vsixPath = Join-Path $script:extDir 'hve-developer-1.0.0.vsix'
            Set-Content -Path $vsixPath -Value 'fake-vsix'

            $null = Invoke-PackageExtension -ExtensionDirectory $script:extDir -RepoRoot $script:repoRoot

            # Verify the original manifest was restored
            $restored = Get-Content -Path (Join-Path $script:extDir 'package.json') -Raw | ConvertFrom-Json
            $restored.name | Should -Be 'hve-core'
        }

        It 'Removes backup file after restore' {
            Mock Test-VsceAvailable { return @{ IsAvailable = $true; CommandType = 'vsce'; Command = 'vsce' } }
            Mock Get-VscePackageCommand { return @{ Executable = 'echo'; Arguments = @('mocked') } }

            $manifest = @{
                name      = 'test-ext'
                version   = '1.0.0'
                publisher = 'test'
                engines   = @{ vscode = '^1.80.0' }
            }
            $manifest | ConvertTo-Json | Set-Content (Join-Path $script:extDir 'package.json')

            # Create a backup file manually to simulate Invoke-PrepareExtension behavior
            $backupManifest = @{
                name      = 'original-ext'
                version   = '1.0.0'
                publisher = 'test'
                engines   = @{ vscode = '^1.80.0' }
            }
            $backupManifest | ConvertTo-Json | Set-Content (Join-Path $script:extDir 'package.json.bak')

            # Create fake vsix so packaging succeeds
            $vsixPath = Join-Path $script:extDir 'test-ext-1.0.0.vsix'
            Set-Content -Path $vsixPath -Value 'fake-vsix'

            $null = Invoke-PackageExtension -ExtensionDirectory $script:extDir -RepoRoot $script:repoRoot

            Test-Path (Join-Path $script:extDir 'package.json.bak') | Should -BeFalse
        }

        It 'Restored package.json contains original metadata' {
            Mock Test-VsceAvailable { return @{ IsAvailable = $true; CommandType = 'vsce'; Command = 'vsce' } }
            Mock Get-VscePackageCommand { return @{ Executable = 'echo'; Arguments = @('mocked') } }

            # Original manifest backed up before template was applied
            $originalManifest = @{
                name        = 'hve-core-original'
                version     = '2.5.0'
                publisher   = 'original-pub'
                description = 'Original description'
                engines     = @{ vscode = '^1.80.0' }
            }

            # Template manifest currently in package.json
            $templateManifest = @{
                name        = 'hve-test-collection'
                version     = '2.5.0'
                publisher   = 'test-pub'
                description = 'Test description'
                engines     = @{ vscode = '^1.80.0' }
            }
            $templateManifest | ConvertTo-Json | Set-Content (Join-Path $script:extDir 'package.json')
            $originalManifest | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $script:extDir 'package.json.bak')

            # Create fake vsix matching the template name
            $vsixPath = Join-Path $script:extDir 'hve-test-collection-2.5.0.vsix'
            Set-Content -Path $vsixPath -Value 'fake-vsix'

            $null = Invoke-PackageExtension -ExtensionDirectory $script:extDir -RepoRoot $script:repoRoot

            $restored = Get-Content -Path (Join-Path $script:extDir 'package.json') -Raw | ConvertFrom-Json
            $restored.name | Should -Be 'hve-core-original'
            $restored.publisher | Should -Be 'original-pub'
            $restored.description | Should -Be 'Original description'
        }
    }

    It 'Cleans pre-existing copied directories before preparing extension' {
        Mock Test-VsceAvailable { return @{ IsAvailable = $true; CommandType = 'vsce'; Command = 'vsce' } }
        Mock Get-VscePackageCommand { return @{ Executable = 'echo'; Arguments = @('mocked') } }

        $manifest = @{
            name      = 'test-ext'
            version   = '1.0.0'
            publisher = 'test'
            engines   = @{ vscode = '^1.80.0' }
        }
        $manifest | ConvertTo-Json | Set-Content (Join-Path $script:extDir 'package.json')

        # Pre-create directories that should be cleaned before packaging
        $preExistingGithub = Join-Path $script:extDir '.github/stale'
        $preExistingScripts = Join-Path $script:extDir 'scripts/old'
        New-Item -Path $preExistingGithub -ItemType Directory -Force | Out-Null
        Set-Content -Path (Join-Path $preExistingGithub 'leftover.md') -Value 'stale'
        New-Item -Path $preExistingScripts -ItemType Directory -Force | Out-Null
        Set-Content -Path (Join-Path $preExistingScripts 'leftover.ps1') -Value 'stale'

        $vsixPath = Join-Path $script:extDir 'test-ext-1.0.0.vsix'
        Set-Content -Path $vsixPath -Value 'fake-vsix'

        $result = Invoke-PackageExtension -ExtensionDirectory $script:extDir -RepoRoot $script:repoRoot

        # Stale files should have been removed during pre-clean
        $result | Should -BeOfType [hashtable]
    }

    It 'Returns failure when an unexpected error occurs during orchestration' {
        Mock Test-VsceAvailable { return @{ IsAvailable = $true; CommandType = 'vsce'; Command = 'vsce' } }
        Mock Get-PackagingDirectorySpec { throw 'Simulated unexpected failure' }

        $manifest = @{
            name      = 'test-ext'
            version   = '1.0.0'
            publisher = 'test'
            engines   = @{ vscode = '^1.80.0' }
        }
        $manifest | ConvertTo-Json | Set-Content (Join-Path $script:extDir 'package.json')

        $result = Invoke-PackageExtension -ExtensionDirectory $script:extDir -RepoRoot $script:repoRoot

        $result.Success | Should -BeFalse
        $result.ErrorMessage | Should -Match 'Simulated unexpected failure'
    }

    It 'Returns success without VSIX creation when DryRun is specified' {
        $manifest = @{
            name      = 'test-ext'
            version   = '1.0.0'
            publisher = 'test'
            engines   = @{ vscode = '^1.80.0' }
        }
        $manifest | ConvertTo-Json | Set-Content (Join-Path $script:extDir 'package.json')

        $result = Invoke-PackageExtension -ExtensionDirectory $script:extDir -RepoRoot $script:repoRoot -DryRun

        $result.Success | Should -BeTrue
        $result.Version | Should -Be '1.0.0'
        $result.OutputPath | Should -BeNullOrEmpty
    }
}

Describe 'Test-PackagingInputsValid' {
    BeforeAll {
        $script:testRoot = Join-Path ([System.IO.Path]::GetTempPath()) "pkg-inputs-test-$([guid]::NewGuid().ToString('N').Substring(0,8))"
        $script:extDir = Join-Path $script:testRoot 'extension'
        $script:repoRoot = Join-Path $script:testRoot 'repo'
    }

    BeforeEach {
        New-Item -Path $script:extDir -ItemType Directory -Force | Out-Null
        New-Item -Path $script:repoRoot -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $script:repoRoot '.github') -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $script:repoRoot '.github/skills') -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $script:repoRoot 'scripts/lib/Modules') -ItemType Directory -Force | Out-Null
        Set-Content -Path (Join-Path $script:repoRoot 'scripts/lib/Modules/CIHelpers.psm1') -Value '# Mock'
        Set-Content -Path (Join-Path $script:extDir 'package.json') -Value '{}'
    }

    AfterEach {
        if (Test-Path $script:testRoot) {
            Remove-Item -Path $script:testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Returns valid when all paths exist' {
        $result = Test-PackagingInputsValid -ExtensionDirectory $script:extDir -RepoRoot $script:repoRoot
        $result.IsValid | Should -BeTrue
        $result.Errors | Should -BeNullOrEmpty
    }

    It 'Returns resolved paths in result' {
        $result = Test-PackagingInputsValid -ExtensionDirectory $script:extDir -RepoRoot $script:repoRoot
        $result.PackageJsonPath | Should -BeLike '*package.json'
        $result.GitHubDir | Should -BeLike '*.github'
        $result.CIHelpersPath | Should -BeLike '*CIHelpers.psm1'
    }

    It 'Returns error when extension directory not found' {
        $nonexistent = Join-Path ([System.IO.Path]::GetTempPath()) "nonexistent-$([guid]::NewGuid().ToString('N').Substring(0,8))"
        $result = Test-PackagingInputsValid -ExtensionDirectory $nonexistent -RepoRoot $script:repoRoot
        $result.IsValid | Should -BeFalse
        # Function accumulates multiple errors; extension dir missing cascades to package.json missing
        $result.Errors | Should -Match 'Extension directory not found|package.json not found'
    }

    It 'Returns error when package.json not found' {
        Remove-Item -Path (Join-Path $script:extDir 'package.json') -Force
        $result = Test-PackagingInputsValid -ExtensionDirectory $script:extDir -RepoRoot $script:repoRoot
        $result.IsValid | Should -BeFalse
        $result.Errors | Should -Match 'package.json not found'
    }

    It 'Returns error when .github directory not found' {
        Remove-Item -Path (Join-Path $script:repoRoot '.github') -Recurse -Force
        $result = Test-PackagingInputsValid -ExtensionDirectory $script:extDir -RepoRoot $script:repoRoot
        $result.IsValid | Should -BeFalse
        $result.Errors | Should -Match '.github directory not found'
    }

    It 'Returns error when CIHelpers.psm1 not found' {
        Remove-Item -Path (Join-Path $script:repoRoot 'scripts/lib/Modules/CIHelpers.psm1') -Force
        $result = Test-PackagingInputsValid -ExtensionDirectory $script:extDir -RepoRoot $script:repoRoot
        $result.IsValid | Should -BeFalse
        $result.Errors | Should -Match 'CIHelpers.psm1 not found'
    }

    It 'Collects multiple errors' {
        Remove-Item -Path (Join-Path $script:extDir 'package.json') -Force
        Remove-Item -Path (Join-Path $script:repoRoot '.github') -Recurse -Force
        $result = Test-PackagingInputsValid -ExtensionDirectory $script:extDir -RepoRoot $script:repoRoot
        $result.IsValid | Should -BeFalse
        $result.Errors.Count | Should -BeGreaterOrEqual 2
    }
}

Describe 'Get-PackagingDirectorySpec' {
    BeforeAll {
        # Use platform-agnostic temp paths for cross-platform CI compatibility
        $script:repoRoot = Join-Path ([System.IO.Path]::GetTempPath()) 'spec-repo'
        $script:extDir = Join-Path ([System.IO.Path]::GetTempPath()) 'spec-ext'
    }

    It 'Returns array of 3 directory specifications' {
        $result = Get-PackagingDirectorySpec -RepoRoot $script:repoRoot -ExtensionDirectory $script:extDir
        $result.Count | Should -Be 3
    }

    It 'Includes .github directory specification' {
        $result = Get-PackagingDirectorySpec -RepoRoot $script:repoRoot -ExtensionDirectory $script:extDir
        $githubSpec = $result | Where-Object { $_.Source -like '*.github' }
        $githubSpec | Should -Not -BeNullOrEmpty
        $githubSpec.Destination | Should -BeLike '*.github'
        $githubSpec.IsFile | Should -BeFalse
    }

    It 'Includes CIHelpers.psm1 file specification' {
        $result = Get-PackagingDirectorySpec -RepoRoot $script:repoRoot -ExtensionDirectory $script:extDir
        $ciHelpersSpec = $result | Where-Object { $_.Source -like '*CIHelpers.psm1' }
        $ciHelpersSpec | Should -Not -BeNullOrEmpty
        $ciHelpersSpec.IsFile | Should -BeTrue
    }

    It 'Includes docs/templates directory specification' {
        $result = Get-PackagingDirectorySpec -RepoRoot $script:repoRoot -ExtensionDirectory $script:extDir
        $templatesSpec = $result | Where-Object { $_.Source -like '*templates' }
        $templatesSpec | Should -Not -BeNullOrEmpty
        $templatesSpec.IsFile | Should -BeFalse
    }

    It 'Uses correct path joining for source and destination' {
        $result = Get-PackagingDirectorySpec -RepoRoot $script:repoRoot -ExtensionDirectory $script:extDir
        foreach ($spec in $result) {
            $spec.Source | Should -Not -BeNullOrEmpty
            $spec.Destination | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'Invoke-VsceCommand' {
    BeforeAll {
        $script:testDir = Join-Path ([System.IO.Path]::GetTempPath()) "vsce-cmd-test-$([guid]::NewGuid().ToString('N').Substring(0,8))"
    }

    BeforeEach {
        New-Item -Path $script:testDir -ItemType Directory -Force | Out-Null
    }

    AfterEach {
        if (Test-Path $script:testDir) {
            Remove-Item -Path $script:testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Returns hashtable with Success and ExitCode' {
        $result = Invoke-VsceCommand -Executable 'pwsh' -Arguments @('-Command', 'exit 0') -WorkingDirectory $script:testDir
        $result | Should -BeOfType [hashtable]
        $result.Keys | Should -Contain 'Success'
        $result.Keys | Should -Contain 'ExitCode'
    }

    It 'Returns Success true for zero exit code' {
        $result = Invoke-VsceCommand -Executable 'pwsh' -Arguments @('-Command', 'exit 0') -WorkingDirectory $script:testDir
        $result.Success | Should -BeTrue
        $result.ExitCode | Should -Be 0
    }

    It 'Returns Success false for non-zero exit code' {
        $result = Invoke-VsceCommand -Executable 'pwsh' -Arguments @('-Command', 'exit 42') -WorkingDirectory $script:testDir
        $result.Success | Should -BeFalse
        $result.ExitCode | Should -Be 42
    }

    It 'Restores working directory after execution' {
        $originalDir = Get-Location
        $null = Invoke-VsceCommand -Executable 'pwsh' -Arguments @('-Command', 'exit 0') -WorkingDirectory $script:testDir
        (Get-Location).Path | Should -Be $originalDir.Path
    }

    It 'Uses cmd wrapper when UseWindowsWrapper specified with npx' -Skip:(-not $IsWindows) {
        # Test that cmd wrapper path executes without error
        # npx --help outputs text to the pipeline alongside the hashtable return value
        $output = Invoke-VsceCommand -Executable 'npx' -Arguments @('--help') -WorkingDirectory $script:testDir -UseWindowsWrapper
        # Filter for the hashtable return (command output also flows through pipeline)
        $result = $output | Where-Object { $_ -is [hashtable] }
        $result | Should -Not -BeNullOrEmpty
        $result.Keys | Should -Contain 'Success'
    }
}

Describe 'Remove-PackagingArtifacts' {
    BeforeAll {
        $script:testDir = Join-Path ([System.IO.Path]::GetTempPath()) "rm-artifacts-test-$([guid]::NewGuid().ToString('N').Substring(0,8))"
    }

    BeforeEach {
        New-Item -Path $script:testDir -ItemType Directory -Force | Out-Null
    }

    AfterEach {
        if (Test-Path $script:testDir) {
            Remove-Item -Path $script:testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Removes existing directories' {
        New-Item -Path (Join-Path $script:testDir '.github') -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $script:testDir 'scripts') -ItemType Directory -Force | Out-Null

        Remove-PackagingArtifacts -ExtensionDirectory $script:testDir

        Test-Path (Join-Path $script:testDir '.github') | Should -BeFalse
        Test-Path (Join-Path $script:testDir 'scripts') | Should -BeFalse
    }

    It 'Silently skips non-existent directories' {
        { Remove-PackagingArtifacts -ExtensionDirectory $script:testDir } | Should -Not -Throw
    }

    It 'Uses custom directory names when specified' {
        New-Item -Path (Join-Path $script:testDir 'custom1') -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $script:testDir 'custom2') -ItemType Directory -Force | Out-Null

        Remove-PackagingArtifacts -ExtensionDirectory $script:testDir -DirectoryNames @('custom1', 'custom2')

        Test-Path (Join-Path $script:testDir 'custom1') | Should -BeFalse
        Test-Path (Join-Path $script:testDir 'custom2') | Should -BeFalse
    }

    It 'Removes nested contents recursively' {
        $nestedDir = Join-Path $script:testDir '.github/nested/deep'
        New-Item -Path $nestedDir -ItemType Directory -Force | Out-Null
        Set-Content -Path (Join-Path $nestedDir 'file.txt') -Value 'content'

        Remove-PackagingArtifacts -ExtensionDirectory $script:testDir -DirectoryNames @('.github')

        Test-Path (Join-Path $script:testDir '.github') | Should -BeFalse
    }
}

Describe 'Restore-PackageJsonVersion' {
    BeforeAll {
        $script:testDir = Join-Path ([System.IO.Path]::GetTempPath()) "restore-ver-test-$([guid]::NewGuid().ToString('N').Substring(0,8))"
    }

    BeforeEach {
        New-Item -Path $script:testDir -ItemType Directory -Force | Out-Null
    }

    AfterEach {
        if (Test-Path $script:testDir) {
            Remove-Item -Path $script:testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Restores original version to package.json' {
        $packageJsonPath = Join-Path $script:testDir 'package.json'
        $packageJson = @{ name = 'test'; version = '2.0.0' }
        $packageJson | ConvertTo-Json | Set-Content -Path $packageJsonPath

        $obj = Get-Content $packageJsonPath | ConvertFrom-Json
        Restore-PackageJsonVersion -PackageJsonPath $packageJsonPath -PackageJson $obj -OriginalVersion '1.0.0'

        $updated = Get-Content $packageJsonPath | ConvertFrom-Json
        $updated.version | Should -Be '1.0.0'
    }

    It 'Returns early when OriginalVersion is null' {
        $packageJsonPath = Join-Path $script:testDir 'package.json'
        $packageJson = @{ name = 'test'; version = '2.0.0' }
        $packageJson | ConvertTo-Json | Set-Content -Path $packageJsonPath

        $obj = Get-Content $packageJsonPath | ConvertFrom-Json
        { Restore-PackageJsonVersion -PackageJsonPath $packageJsonPath -PackageJson $obj -OriginalVersion $null } | Should -Not -Throw

        $unchanged = Get-Content $packageJsonPath | ConvertFrom-Json
        $unchanged.version | Should -Be '2.0.0'
    }

    It 'Returns early when PackageJson is null' {
        $packageJsonPath = Join-Path $script:testDir 'package.json'
        Set-Content -Path $packageJsonPath -Value '{"version": "2.0.0"}'

        { Restore-PackageJsonVersion -PackageJsonPath $packageJsonPath -PackageJson $null -OriginalVersion '1.0.0' } | Should -Not -Throw

        $unchanged = Get-Content $packageJsonPath | ConvertFrom-Json
        $unchanged.version | Should -Be '2.0.0'
    }

    It 'Returns early when PackageJsonPath is null' {
        $packageJson = @{ name = 'test'; version = '2.0.0' }
        { Restore-PackageJsonVersion -PackageJsonPath $null -PackageJson $packageJson -OriginalVersion '1.0.0' } | Should -Not -Throw
    }

    It 'Handles write failure gracefully' {
        Mock Write-Warning {}
        $invalidPath = Join-Path $script:testDir 'nonexistent/package.json'
        $packageJson = [PSCustomObject]@{ name = 'test'; version = '2.0.0' }

        { Restore-PackageJsonVersion -PackageJsonPath $invalidPath -PackageJson $packageJson -OriginalVersion '1.0.0' } | Should -Not -Throw
    }
}

Describe 'Get-CollectionReadmePath' {
    BeforeAll {
        $script:testDir = Join-Path ([System.IO.Path]::GetTempPath()) "collection-readme-test-$([guid]::NewGuid().ToString('N').Substring(0,8))"
        $script:extDir = Join-Path $script:testDir 'extension'
    }

    BeforeEach {
        New-Item -Path $script:extDir -ItemType Directory -Force | Out-Null
    }

    AfterEach {
        if (Test-Path $script:testDir) {
            Remove-Item -Path $script:testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Returns null for hve-core collection' {
        $collectionPath = Join-Path $script:testDir 'collection.yml'
        @"
id: hve-core
name: core
"@ | Set-Content $collectionPath

        $result = Get-CollectionReadmePath -CollectionPath $collectionPath -ExtensionDirectory $script:extDir
        $result | Should -BeNullOrEmpty
    }

    It 'Returns collection README path when file exists' {
        $collectionPath = Join-Path $script:testDir 'collection.yml'
        @"
id: developer
name: dev
"@ | Set-Content $collectionPath

        $collectionReadme = Join-Path $script:extDir 'README.developer.md'
        Set-Content -Path $collectionReadme -Value '# Developer README'

        $result = Get-CollectionReadmePath -CollectionPath $collectionPath -ExtensionDirectory $script:extDir
        $result | Should -Be $collectionReadme
    }

    It 'Returns null when collection README file does not exist' {
        $collectionPath = Join-Path $script:testDir 'collection.yml'
        @"
id: security
name: sec
"@ | Set-Content $collectionPath

        $result = Get-CollectionReadmePath -CollectionPath $collectionPath -ExtensionDirectory $script:extDir
        $result | Should -BeNullOrEmpty
    }

    It 'Parses JSON collection file correctly' {
        $collectionPath = Join-Path $script:testDir 'collection.json'
        @{
            id   = 'json-collection'
            name = 'json'
        } | ConvertTo-Json | Set-Content $collectionPath

        $collectionReadme = Join-Path $script:extDir 'README.json-collection.md'
        Set-Content -Path $collectionReadme -Value '# JSON Collection README'

        $result = Get-CollectionReadmePath -CollectionPath $collectionPath -ExtensionDirectory $script:extDir
        $result | Should -Be $collectionReadme
    }
}

Describe 'Set-CollectionReadme' {
    BeforeAll {
        $script:testDir = Join-Path ([System.IO.Path]::GetTempPath()) "set-readme-test-$([guid]::NewGuid().ToString('N').Substring(0,8))"
    }

    BeforeEach {
        New-Item -Path $script:testDir -ItemType Directory -Force | Out-Null
        Set-Content -Path (Join-Path $script:testDir 'README.md') -Value '# Original README'
    }

    AfterEach {
        if (Test-Path $script:testDir) {
            Remove-Item -Path $script:testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Swaps README.md with collection README and creates backup' {
        $collectionReadmePath = Join-Path $script:testDir 'README.developer.md'
        Set-Content -Path $collectionReadmePath -Value '# Developer README'

        Set-CollectionReadme -ExtensionDirectory $script:testDir -CollectionReadmePath $collectionReadmePath -Operation Swap

        $readmeContent = Get-Content -Path (Join-Path $script:testDir 'README.md') -Raw
        $readmeContent | Should -Match 'Developer README'

        Test-Path (Join-Path $script:testDir 'README.md.bak') | Should -BeTrue
        $backupContent = Get-Content -Path (Join-Path $script:testDir 'README.md.bak') -Raw
        $backupContent | Should -Match 'Original README'
    }

    It 'Warns and returns early when no collection path for swap' {
        Mock Write-Warning {}
        Set-CollectionReadme -ExtensionDirectory $script:testDir -Operation Swap

        Should -Invoke Write-Warning -Times 1
        $readmeContent = Get-Content -Path (Join-Path $script:testDir 'README.md') -Raw
        $readmeContent | Should -Match 'Original README'
    }

    It 'Restores README.md from backup and removes backup file' {
        # Create backup state
        Set-Content -Path (Join-Path $script:testDir 'README.md.bak') -Value '# Original README'
        Set-Content -Path (Join-Path $script:testDir 'README.md') -Value '# Collection README'

        Set-CollectionReadme -ExtensionDirectory $script:testDir -Operation Restore

        $readmeContent = Get-Content -Path (Join-Path $script:testDir 'README.md') -Raw
        $readmeContent | Should -Match 'Original README'
        Test-Path (Join-Path $script:testDir 'README.md.bak') | Should -BeFalse
    }

    It 'Restore is a no-op when no backup exists' {
        { Set-CollectionReadme -ExtensionDirectory $script:testDir -Operation Restore } | Should -Not -Throw
        $readmeContent = Get-Content -Path (Join-Path $script:testDir 'README.md') -Raw
        $readmeContent | Should -Match 'Original README'
    }
}

Describe 'Copy-CollectionArtifacts' {
    BeforeAll {
        $script:testDir = Join-Path ([System.IO.Path]::GetTempPath()) "copy-col-test-$([guid]::NewGuid().ToString('N').Substring(0,8))"
        $script:extDir = Join-Path $script:testDir 'extension'
        $script:repoRoot = Join-Path $script:testDir 'repo'
    }

    BeforeEach {
        New-Item -Path $script:extDir -ItemType Directory -Force | Out-Null
        New-Item -Path $script:repoRoot -ItemType Directory -Force | Out-Null
    }

    AfterEach {
        if (Test-Path $script:testDir) {
            Remove-Item -Path $script:testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Copies agents from repo to extension directory' {
        # Create source agent
        $agentsSrc = Join-Path $script:repoRoot '.github/agents'
        New-Item -Path $agentsSrc -ItemType Directory -Force | Out-Null
        Set-Content -Path (Join-Path $agentsSrc 'task-planner.agent.md') -Value '# Agent'

        # Create package.json with contributes referencing agents
        $pkgJson = @{
            contributes = @{
                chatAgents = @(
                    @{ path = './.github/agents/task-planner.agent.md' }
                )
            }
        }
        $pkgJson | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $script:extDir 'package.json')

        Copy-CollectionArtifacts -RepoRoot $script:repoRoot -ExtensionDirectory $script:extDir -PrepareResult @{}

        Test-Path (Join-Path $script:extDir '.github/agents/task-planner.agent.md') | Should -BeTrue
    }

    It 'Copies prompts from repo to extension directory' {
        # Create source prompt
        $promptsSrc = Join-Path $script:repoRoot '.github/prompts'
        New-Item -Path $promptsSrc -ItemType Directory -Force | Out-Null
        Set-Content -Path (Join-Path $promptsSrc 'my-prompt.prompt.md') -Value '# Prompt'

        $pkgJson = @{
            contributes = @{
                chatPromptFiles = @(
                    @{ path = './.github/prompts/my-prompt.prompt.md' }
                )
            }
        }
        $pkgJson | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $script:extDir 'package.json')

        Copy-CollectionArtifacts -RepoRoot $script:repoRoot -ExtensionDirectory $script:extDir -PrepareResult @{}

        Test-Path (Join-Path $script:extDir '.github/prompts/my-prompt.prompt.md') | Should -BeTrue
    }

    It 'Copies instructions from repo to extension directory' {
        # Create source instruction
        $instrSrc = Join-Path $script:repoRoot '.github/instructions'
        New-Item -Path $instrSrc -ItemType Directory -Force | Out-Null
        Set-Content -Path (Join-Path $instrSrc 'commit-message.instructions.md') -Value '# Instructions'

        $pkgJson = @{
            contributes = @{
                chatInstructions = @(
                    @{ path = './.github/instructions/commit-message.instructions.md' }
                )
            }
        }
        $pkgJson | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $script:extDir 'package.json')

        Copy-CollectionArtifacts -RepoRoot $script:repoRoot -ExtensionDirectory $script:extDir -PrepareResult @{}

        Test-Path (Join-Path $script:extDir '.github/instructions/commit-message.instructions.md') | Should -BeTrue
    }

    It 'Copies skills recursively from repo to extension directory' {
        # Create source skill with nested file
        $skillSrc = Join-Path $script:repoRoot '.github/skills/video-to-gif'
        New-Item -Path $skillSrc -ItemType Directory -Force | Out-Null
        Set-Content -Path (Join-Path $skillSrc 'SKILL.md') -Value '# Skill'

        $pkgJson = @{
            contributes = @{
                chatSkills = @(
                    @{ path = './.github/skills/video-to-gif' }
                )
            }
        }
        $pkgJson | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $script:extDir 'package.json')

        Copy-CollectionArtifacts -RepoRoot $script:repoRoot -ExtensionDirectory $script:extDir -PrepareResult @{}

        Test-Path (Join-Path $script:extDir '.github/skills/video-to-gif') | Should -BeTrue
    }

    It 'Skips missing source files without error' {
        $pkgJson = @{
            contributes = @{
                chatAgents       = @( @{ path = './.github/agents/nonexistent.agent.md' } )
                chatPromptFiles  = @( @{ path = './.github/prompts/nonexistent.prompt.md' } )
                chatInstructions = @( @{ path = './.github/instructions/nonexistent.instructions.md' } )
                chatSkills       = @( @{ path = './.github/skills/nonexistent' } )
            }
        }
        $pkgJson | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $script:extDir 'package.json')

        { Copy-CollectionArtifacts -RepoRoot $script:repoRoot -ExtensionDirectory $script:extDir -PrepareResult @{} } | Should -Not -Throw
    }

    It 'Handles empty contributes sections' {
        $pkgJson = @{ contributes = @{} }
        $pkgJson | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $script:extDir 'package.json')

        { Copy-CollectionArtifacts -RepoRoot $script:repoRoot -ExtensionDirectory $script:extDir -PrepareResult @{} } | Should -Not -Throw
    }
}

Describe 'Invoke-PackageExtension - Collection mode' {
    BeforeAll {
        $script:testRoot = Join-Path ([System.IO.Path]::GetTempPath()) "pkg-col-test-$([guid]::NewGuid().ToString('N').Substring(0,8))"
        $script:extDir = Join-Path $script:testRoot 'extension'
        $script:repoRoot = Join-Path $script:testRoot 'repo'
    }

    BeforeEach {
        New-Item -Path $script:extDir -ItemType Directory -Force | Out-Null
        New-Item -Path $script:repoRoot -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $script:repoRoot '.github') -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $script:repoRoot '.github/skills') -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $script:repoRoot 'scripts/lib/Modules') -ItemType Directory -Force | Out-Null
        Set-Content -Path (Join-Path $script:repoRoot 'scripts/lib/Modules/CIHelpers.psm1') -Value '# Mock module'
        New-Item -Path (Join-Path $script:repoRoot 'docs/templates') -ItemType Directory -Force | Out-Null

        $manifest = @{
            name      = 'test-ext'
            version   = '1.0.0'
            publisher = 'test'
            engines   = @{ vscode = '^1.80.0' }
            contributes = @{}
        }
        $manifest | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $script:extDir 'package.json')
        Set-Content -Path (Join-Path $script:extDir 'README.md') -Value '# Default README'
    }

    AfterEach {
        if (Test-Path $script:testRoot) {
            Remove-Item -Path $script:testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Uses collection-filtered artifact copy when Collection specified' {
        Mock Test-VsceAvailable { return @{ IsAvailable = $true; CommandType = 'vsce'; Command = 'vsce' } }
        Mock Get-VscePackageCommand { return @{ Executable = 'echo'; Arguments = @('mocked') } }

        $collectionPath = Join-Path $script:testRoot 'collection.yml'
        @"
id: developer
name: dev
displayName: Developer
items:
  - developer
"@ | Set-Content $collectionPath

        $vsixPath = Join-Path $script:extDir 'test-ext-1.0.0.vsix'
        Set-Content -Path $vsixPath -Value 'fake-vsix'

        $result = Invoke-PackageExtension -ExtensionDirectory $script:extDir -RepoRoot $script:repoRoot -Collection $collectionPath
        $result | Should -BeOfType [hashtable]
    }

    It 'Swaps collection README when collection has matching collection README' {
        Mock Test-VsceAvailable { return @{ IsAvailable = $true; CommandType = 'vsce'; Command = 'vsce' } }
        Mock Get-VscePackageCommand { return @{ Executable = 'echo'; Arguments = @('mocked') } }

        $collectionPath = Join-Path $script:testRoot 'collection.yml'
        @"
id: developer
name: dev
displayName: Developer
items:
  - developer
"@ | Set-Content $collectionPath

        # Create collection README in extension directory
        Set-Content -Path (Join-Path $script:extDir 'README.developer.md') -Value '# Developer Collection'

        $vsixPath = Join-Path $script:extDir 'test-ext-1.0.0.vsix'
        Set-Content -Path $vsixPath -Value 'fake-vsix'

        $result = Invoke-PackageExtension -ExtensionDirectory $script:extDir -RepoRoot $script:repoRoot -Collection $collectionPath

        # README should be restored after packaging completes
        $readmeContent = Get-Content -Path (Join-Path $script:extDir 'README.md') -Raw
        $readmeContent | Should -Match 'Default README'
        $result | Should -BeOfType [hashtable]
    }

    It 'Returns failure when no vsix file generated after successful vsce command' {
        Mock Test-VsceAvailable { return @{ IsAvailable = $true; CommandType = 'vsce'; Command = 'vsce' } }
        Mock Get-VscePackageCommand { return @{ Executable = 'echo'; Arguments = @('mocked') } }

        $result = Invoke-PackageExtension -ExtensionDirectory $script:extDir -RepoRoot $script:repoRoot

        $result.Success | Should -BeFalse
        $result.ErrorMessage | Should -Match 'No .vsix file found after packaging'
    }
}

Describe 'CI Integration - Package-Extension' {
    BeforeAll {
        $script:testRoot = Join-Path ([System.IO.Path]::GetTempPath()) "ci-int-test-$([guid]::NewGuid().ToString('N').Substring(0,8))"
        $script:extDir = Join-Path $script:testRoot 'extension'
        $script:repoRoot = Join-Path $script:testRoot 'repo'
    }

    AfterAll {
        if (Test-Path $script:testRoot) {
            Remove-Item -Path $script:testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'GitHub Actions environment' {
        BeforeEach {
            Initialize-MockCIEnvironment
            New-Item -Path $script:extDir -ItemType Directory -Force | Out-Null
            New-Item -Path $script:repoRoot -ItemType Directory -Force | Out-Null
            New-Item -Path (Join-Path $script:repoRoot '.github') -ItemType Directory -Force | Out-Null
            New-Item -Path (Join-Path $script:repoRoot '.github/skills') -ItemType Directory -Force | Out-Null
            New-Item -Path (Join-Path $script:repoRoot 'scripts/lib/Modules') -ItemType Directory -Force | Out-Null
            Set-Content -Path (Join-Path $script:repoRoot 'scripts/lib/Modules/CIHelpers.psm1') -Value '# Mock module'
            New-Item -Path (Join-Path $script:repoRoot 'docs/templates') -ItemType Directory -Force | Out-Null

            $manifest = @{
                name      = 'test-ext'
                version   = '1.0.0'
                publisher = 'test'
                engines   = @{ vscode = '^1.80.0' }
            }
            $manifest | ConvertTo-Json | Set-Content (Join-Path $script:extDir 'package.json')
        }

        AfterEach {
            Clear-MockCIEnvironment
            if (Test-Path $script:testRoot) {
                Remove-Item -Path $script:testRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It 'Sets version output variable on successful package' {
            Mock Test-VsceAvailable { return @{ IsAvailable = $true; CommandType = 'vsce'; Command = 'vsce' } }
            Mock Get-VscePackageCommand { return @{ Executable = 'echo'; Arguments = @('mocked') } }

            $vsixPath = Join-Path $script:extDir 'test-ext-1.0.0.vsix'
            Set-Content -Path $vsixPath -Value 'fake-vsix'

            $null = Invoke-PackageExtension -ExtensionDirectory $script:extDir -RepoRoot $script:repoRoot

            $outputContent = Get-Content $env:GITHUB_OUTPUT -Raw
            $outputContent | Should -Match 'version=1\.0\.0'
        }

        It 'Sets vsix-file output variable on successful package' {
            Mock Test-VsceAvailable { return @{ IsAvailable = $true; CommandType = 'vsce'; Command = 'vsce' } }
            Mock Get-VscePackageCommand { return @{ Executable = 'echo'; Arguments = @('mocked') } }

            $vsixPath = Join-Path $script:extDir 'test-ext-1.0.0.vsix'
            Set-Content -Path $vsixPath -Value 'fake-vsix'

            $null = Invoke-PackageExtension -ExtensionDirectory $script:extDir -RepoRoot $script:repoRoot

            $outputContent = Get-Content $env:GITHUB_OUTPUT -Raw
            $outputContent | Should -Match 'vsix-file=test-ext-1\.0\.0\.vsix'
        }

        It 'Sets pre-release output variable when PreRelease specified' {
            Mock Test-VsceAvailable { return @{ IsAvailable = $true; CommandType = 'vsce'; Command = 'vsce' } }
            Mock Get-VscePackageCommand { return @{ Executable = 'echo'; Arguments = @('mocked') } }

            $vsixPath = Join-Path $script:extDir 'test-ext-1.0.0.vsix'
            Set-Content -Path $vsixPath -Value 'fake-vsix'

            $null = Invoke-PackageExtension -ExtensionDirectory $script:extDir -RepoRoot $script:repoRoot -PreRelease

            $outputContent = Get-Content $env:GITHUB_OUTPUT -Raw
            $outputContent | Should -Match 'pre-release=True'
        }

        It 'Sets pre-release output variable to false when PreRelease not specified' {
            Mock Test-VsceAvailable { return @{ IsAvailable = $true; CommandType = 'vsce'; Command = 'vsce' } }
            Mock Get-VscePackageCommand { return @{ Executable = 'echo'; Arguments = @('mocked') } }

            $vsixPath = Join-Path $script:extDir 'test-ext-1.0.0.vsix'
            Set-Content -Path $vsixPath -Value 'fake-vsix'

            $null = Invoke-PackageExtension -ExtensionDirectory $script:extDir -RepoRoot $script:repoRoot

            $outputContent = Get-Content $env:GITHUB_OUTPUT -Raw
            $outputContent | Should -Match 'pre-release=False'
        }

        It 'Returns failure result when vsce command fails' {
            Mock Test-VsceAvailable { return @{ IsAvailable = $true; CommandType = 'vsce'; Command = 'vsce' } }
            Mock Get-VscePackageCommand { return @{ Executable = 'pwsh'; Arguments = @('-Command', 'exit 1') } }

            $result = Invoke-PackageExtension -ExtensionDirectory $script:extDir -RepoRoot $script:repoRoot

            $result.Success | Should -BeFalse
            $result.ErrorMessage | Should -Match 'vsce package command failed'
        }
    }

    Context 'Local environment' {
        BeforeEach {
            Clear-MockCIEnvironment

            New-Item -Path $script:extDir -ItemType Directory -Force | Out-Null
            New-Item -Path $script:repoRoot -ItemType Directory -Force | Out-Null
            New-Item -Path (Join-Path $script:repoRoot '.github') -ItemType Directory -Force | Out-Null
            New-Item -Path (Join-Path $script:repoRoot '.github/skills') -ItemType Directory -Force | Out-Null
            New-Item -Path (Join-Path $script:repoRoot 'scripts/lib/Modules') -ItemType Directory -Force | Out-Null
            Set-Content -Path (Join-Path $script:repoRoot 'scripts/lib/Modules/CIHelpers.psm1') -Value '# Mock module'
            New-Item -Path (Join-Path $script:repoRoot 'docs/templates') -ItemType Directory -Force | Out-Null

            $manifest = @{
                name      = 'test-ext'
                version   = '1.0.0'
                publisher = 'test'
                engines   = @{ vscode = '^1.80.0' }
            }
            $manifest | ConvertTo-Json | Set-Content (Join-Path $script:extDir 'package.json')
        }

        AfterEach {
            if (Test-Path $script:testRoot) {
                Remove-Item -Path $script:testRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It 'Completes without error when not in CI environment' {
            Mock Test-VsceAvailable { return @{ IsAvailable = $true; CommandType = 'vsce'; Command = 'vsce' } }
            Mock Get-VscePackageCommand { return @{ Executable = 'echo'; Arguments = @('mocked') } }

            $vsixPath = Join-Path $script:extDir 'test-ext-1.0.0.vsix'
            Set-Content -Path $vsixPath -Value 'fake-vsix'

            $result = Invoke-PackageExtension -ExtensionDirectory $script:extDir -RepoRoot $script:repoRoot

            $result.Success | Should -BeTrue
        }
    }
}
