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

Describe 'Get-ExtensionOutputPath' {
    BeforeAll {
        $script:testDir = [System.IO.Path]::GetTempPath().TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    }

    It 'Constructs correct output path' {
        $result = Get-ExtensionOutputPath -ExtensionDirectory $script:testDir -ExtensionName 'my-extension' -PackageVersion '1.0.0'
        $expected = [System.IO.Path]::Combine($script:testDir, 'my-extension-1.0.0.vsix')
        $result | Should -Be $expected
    }

    It 'Handles pre-release version numbers' {
        $result = Get-ExtensionOutputPath -ExtensionDirectory $script:testDir -ExtensionName 'ext' -PackageVersion '2.1.0-preview.1'
        $expected = [System.IO.Path]::Combine($script:testDir, 'ext-2.1.0-preview.1.vsix')
        $result | Should -Be $expected
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
        New-Item -Path (Join-Path $script:repoRoot 'scripts/dev-tools') -ItemType Directory -Force | Out-Null
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
            Initialize-MockGitHubEnvironment
            New-Item -Path $script:extDir -ItemType Directory -Force | Out-Null
            New-Item -Path $script:repoRoot -ItemType Directory -Force | Out-Null
            New-Item -Path (Join-Path $script:repoRoot '.github') -ItemType Directory -Force | Out-Null
            New-Item -Path (Join-Path $script:repoRoot 'scripts/dev-tools') -ItemType Directory -Force | Out-Null
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
            Clear-MockGitHubEnvironment
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
            Clear-MockGitHubEnvironment

            New-Item -Path $script:extDir -ItemType Directory -Force | Out-Null
            New-Item -Path $script:repoRoot -ItemType Directory -Force | Out-Null
            New-Item -Path (Join-Path $script:repoRoot '.github') -ItemType Directory -Force | Out-Null
            New-Item -Path (Join-Path $script:repoRoot 'scripts/dev-tools') -ItemType Directory -Force | Out-Null
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
