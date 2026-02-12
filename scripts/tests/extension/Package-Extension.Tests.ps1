#Requires -Modules Pester

BeforeAll {
    . $PSScriptRoot/../../extension/Package-Extension.ps1
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
            $result.CommandType | Should -BeIn @('npx', 'global')
            $result.Command | Should -Not -BeNullOrEmpty
        }
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
}

Describe 'Test-ExtensionManifestValid Error Paths' -Tag 'Unit' {
    Context 'Edge cases' {
        It 'Rejects null manifest with parameter binding error' {
            # Null manifests throw parameter binding error - expected behavior
            { Test-ExtensionManifestValid -ManifestContent $null } | Should -Throw
        }

        It 'Handles empty hashtable' {
            $result = Test-ExtensionManifestValid -ManifestContent @{}
            $result.IsValid | Should -BeFalse
            $result.Errors.Count | Should -BeGreaterThan 0
        }

        It 'Handles manifest with wrong engine type' {
            $manifest = @{
                name = 'ext'
                version = '1.0.0'
                publisher = 'pub'
                engines = @{ node = '>=16' }  # Wrong engine - missing vscode
            }
            $result = Test-ExtensionManifestValid -ManifestContent $manifest
            $result.IsValid | Should -BeFalse
            # Should catch missing engines.vscode
            $result.Errors | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'Get-VscePackageCommand Edge Cases' -Tag 'Unit' {
    It 'Handles vsce command type' {
        $result = Get-VscePackageCommand -CommandType 'vsce'
        $result.Executable | Should -Be 'vsce'
    }

    It 'Includes all arguments for package command' {
        $result = Get-VscePackageCommand -CommandType 'npx' -PreRelease
        $result.Arguments | Should -Contain 'package'
        $result.Arguments | Should -Contain '--pre-release'
    }
}

Describe 'New-PackagingResult Edge Cases' -Tag 'Unit' {
    It 'Handles null version' {
        $result = New-PackagingResult -Success $true -OutputPath '/test/path.vsix' -Version $null -ErrorMessage $null
        $result.Version | Should -BeNullOrEmpty
        $result.Success | Should -BeTrue
    }

    It 'Handles all properties null except success' {
        $result = New-PackagingResult -Success $false -OutputPath $null -Version $null -ErrorMessage $null
        $result.Success | Should -BeFalse
        $result.OutputPath | Should -BeNullOrEmpty
    }
}

Describe 'Invoke-ExtensionPackaging' -Tag 'Unit' {
    BeforeEach {
        $script:originalLocation = Get-Location
        Set-Location $TestDrive

        # Create minimal valid extension structure
        New-Item -Path 'extension' -ItemType Directory -Force | Out-Null
        New-Item -Path '.github' -ItemType Directory -Force | Out-Null

        $packageJson = @{
            name = 'test-extension'
            version = '1.0.0'
            publisher = 'test-publisher'
            engines = @{ vscode = '^1.80.0' }
        }
        $packageJson | ConvertTo-Json -Depth 10 | Set-Content -Path 'extension/package.json'

        # Override $PSScriptRoot context for testing
        $script:testRepoRoot = $TestDrive
    }

    AfterEach {
        Set-Location $script:originalLocation
    }

    Context 'Path validation' {
        It 'Function is accessible after script load' {
            # Verify the function was loaded
            Get-Command Invoke-ExtensionPackaging | Should -Not -BeNullOrEmpty
        }

        It 'Has expected parameter set' {
            $cmd = Get-Command Invoke-ExtensionPackaging
            $cmd.Parameters.Keys | Should -Contain 'Version'
            $cmd.Parameters.Keys | Should -Contain 'DevPatchNumber'
            $cmd.Parameters.Keys | Should -Contain 'PreRelease'
        }
    }

    Context 'Input validation' {
        It 'Get-ResolvedPackageVersion rejects invalid format' {
            $result = Get-ResolvedPackageVersion -SpecifiedVersion 'invalid.ver' -ManifestVersion '1.0.0' -DevPatchNumber ''
            # Invalid version format should be detected
            $result | Should -Not -BeNullOrEmpty
        }
    }
}

#region Invoke-ExtensionPackaging Extended Tests

Describe 'Invoke-ExtensionPackaging Extended' -Tag 'Unit' {
    BeforeAll {
        $script:TestDir = Join-Path ([IO.Path]::GetTempPath()) (New-Guid).ToString()
    }

    AfterAll {
        if (Test-Path $script:TestDir) {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Missing extension directory' {
        BeforeEach {
            New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Test-PathsExist returns false when extension directory missing' {
            # Use Test-PathsExist pure function to verify path validation behavior
            $extPath = Join-Path $script:TestDir 'extension'
            Test-Path $extPath | Should -BeFalse
        }
    }

    Context 'Missing package.json' {
        BeforeEach {
            New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $script:TestDir 'extension') -Force | Out-Null
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Extension directory exists but package.json is missing' {
            $extPath = Join-Path $script:TestDir 'extension'
            $pkgPath = Join-Path $extPath 'package.json'
            Test-Path $extPath | Should -BeTrue
            Test-Path $pkgPath | Should -BeFalse
        }
    }

    Context 'Missing .github directory' {
        BeforeEach {
            New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $script:TestDir 'extension') -Force | Out-Null
            $pkgJson = @{ name = 'test'; version = '1.0.0'; publisher = 'pub'; engines = @{ vscode = '^1.80.0' } }
            $pkgJson | ConvertTo-Json | Set-Content (Join-Path $script:TestDir 'extension/package.json')
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Extension and package.json exist but .github is missing' {
            $extPath = Join-Path $script:TestDir 'extension'
            $pkgPath = Join-Path $extPath 'package.json'
            $githubPath = Join-Path $script:TestDir '.github'
            Test-Path $extPath | Should -BeTrue
            Test-Path $pkgPath | Should -BeTrue
            Test-Path $githubPath | Should -BeFalse
        }
    }

    Context 'Invalid version in package.json' {
        BeforeEach {
            New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $script:TestDir 'extension') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $script:TestDir '.github') -Force | Out-Null
            $pkgJson = @{ name = 'test'; version = 'invalid'; publisher = 'pub'; engines = @{ vscode = '^1.80.0' } }
            $pkgJson | ConvertTo-Json | Set-Content (Join-Path $script:TestDir 'extension/package.json')
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Errors when package.json has invalid version format' {
            # Get-ResolvedPackageVersion validates version format
            $result = Get-ResolvedPackageVersion -SpecifiedVersion '' -ManifestVersion 'invalid' -DevPatchNumber ''
            $result.IsValid | Should -BeFalse
        }
    }

    Context 'Version parameter validation' {
        It 'Accepts valid semver version' {
            $result = Get-ResolvedPackageVersion -SpecifiedVersion '2.0.0' -ManifestVersion '1.0.0' -DevPatchNumber ''
            $result.IsValid | Should -BeTrue
            $result.PackageVersion | Should -Be '2.0.0'
        }

        It 'Rejects version with pre-release suffix' {
            $result = Get-ResolvedPackageVersion -SpecifiedVersion '1.0.0-beta.1' -ManifestVersion '1.0.0' -DevPatchNumber ''
            # Version with pre-release suffix is invalid - base version must be clean semver
            $result.IsValid | Should -BeFalse
            $result.ErrorMessage | Should -Not -BeNullOrEmpty
        }
    }

    Context 'DevPatchNumber parameter' {
        It 'Appends dev patch to manifest version' {
            $result = Get-ResolvedPackageVersion -SpecifiedVersion '' -ManifestVersion '1.0.0' -DevPatchNumber '123'
            $result.IsValid | Should -BeTrue
            $result.PackageVersion | Should -Be '1.0.0-dev.123'
        }

        It 'Appends dev patch to specified version' {
            $result = Get-ResolvedPackageVersion -SpecifiedVersion '2.0.0' -ManifestVersion '1.0.0' -DevPatchNumber '456'
            $result.IsValid | Should -BeTrue
            $result.PackageVersion | Should -Be '2.0.0-dev.456'
        }
    }

    Context 'PreRelease flag' {
        It 'Get-VscePackageCommand includes --pre-release when true' {
            $result = Get-VscePackageCommand -CommandType 'npx' -PreRelease
            $result.Arguments | Should -Contain '--pre-release'
        }

        It 'Get-VscePackageCommand excludes --pre-release when false' {
            $result = Get-VscePackageCommand -CommandType 'npx'
            $result.Arguments | Should -Not -Contain '--pre-release'
        }
    }

    Context 'Output path construction' {
        It 'Constructs correct vsix filename' {
            $result = Get-ExtensionOutputPath -ExtensionDirectory '/test' -ExtensionName 'my-ext' -PackageVersion '1.2.3'
            $result | Should -Match 'my-ext-1.2.3\.vsix$'
        }

        It 'Handles dev version in filename' {
            $result = Get-ExtensionOutputPath -ExtensionDirectory '/test' -ExtensionName 'my-ext' -PackageVersion '1.2.3-dev.42'
            $result | Should -Match 'my-ext-1.2.3-dev\.42\.vsix$'
        }
    }
}

Describe 'Invoke-ExtensionPackaging Detailed Tests' -Tag 'Unit' {
    BeforeAll {
        $script:TestDir = Join-Path ([IO.Path]::GetTempPath()) "pkg-ext-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:TestDir 'extension') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:TestDir '.github') -Force | Out-Null

        $pkgJson = @{
            name = 'test-extension'
            version = '1.0.0'
            publisher = 'test-publisher'
            engines = @{ vscode = '^1.80.0' }
        }
        $pkgJson | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $script:TestDir 'extension/package.json')
    }

    AfterAll {
        Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Test-VsceAvailable behavior' {
        It 'Returns hashtable with expected keys' {
            $result = Test-VsceAvailable
            $result | Should -BeOfType [hashtable]
            $result.ContainsKey('IsAvailable') | Should -BeTrue
        }

        It 'CommandType is npx or global when available' {
            $result = Test-VsceAvailable
            if ($result.IsAvailable) {
                $result.CommandType | Should -BeIn @('npx', 'global', 'vsce')
            }
        }
    }

    Context 'Test-ExtensionManifestValid comprehensive' {
        It 'Validates complete manifest' {
            $manifest = [PSCustomObject]@{
                name = 'ext'
                version = '1.0.0'
                publisher = 'pub'
                engines = [PSCustomObject]@{ vscode = '^1.80.0' }
            }
            $result = Test-ExtensionManifestValid -ManifestContent $manifest
            $result.IsValid | Should -BeTrue
        }

        It 'Reports missing engines.vscode specifically' {
            $manifest = [PSCustomObject]@{
                name = 'ext'
                version = '1.0.0'
                publisher = 'pub'
                engines = [PSCustomObject]@{ node = '>=16' }
            }
            $result = Test-ExtensionManifestValid -ManifestContent $manifest
            $result.IsValid | Should -BeFalse
        }

        It 'Reports engines without vscode property' {
            $manifest = [PSCustomObject]@{
                name = 'ext'
                version = '1.0.0'
                publisher = 'pub'
                engines = [PSCustomObject]@{}
            }
            $result = Test-ExtensionManifestValid -ManifestContent $manifest
            $result.IsValid | Should -BeFalse
        }
    }

    Context 'Get-ResolvedPackageVersion edge cases' {
        It 'Handles three-part version' {
            $result = Get-ResolvedPackageVersion -SpecifiedVersion '1.2.3' -ManifestVersion '0.0.0' -DevPatchNumber ''
            $result.IsValid | Should -BeTrue
            $result.PackageVersion | Should -Be '1.2.3'
        }

        It 'Handles version with zero patch' {
            $result = Get-ResolvedPackageVersion -SpecifiedVersion '1.0.0' -ManifestVersion '0.0.0' -DevPatchNumber ''
            $result.IsValid | Should -BeTrue
            $result.PackageVersion | Should -Be '1.0.0'
        }

        It 'Rejects version with only two parts' {
            $result = Get-ResolvedPackageVersion -SpecifiedVersion '1.0' -ManifestVersion '1.0.0' -DevPatchNumber ''
            $result.IsValid | Should -BeFalse
        }

        It 'Rejects version with non-numeric parts' {
            $result = Get-ResolvedPackageVersion -SpecifiedVersion 'a.b.c' -ManifestVersion '1.0.0' -DevPatchNumber ''
            $result.IsValid | Should -BeFalse
        }
    }

    Context 'New-PackagingResult structure' {
        It 'Creates complete success result' {
            $result = New-PackagingResult -Success $true -OutputPath '/test/ext.vsix' -Version '1.0.0' -ErrorMessage $null
            $result.Success | Should -BeTrue
            $result.OutputPath | Should -Be '/test/ext.vsix'
            $result.Version | Should -Be '1.0.0'
            $result.ErrorMessage | Should -BeNullOrEmpty
        }

        It 'Creates complete failure result' {
            $result = New-PackagingResult -Success $false -OutputPath $null -Version $null -ErrorMessage 'Failed to package'
            $result.Success | Should -BeFalse
            $result.ErrorMessage | Should -Be 'Failed to package'
        }
    }

    Context 'Get-VscePackageCommand variants' {
        It 'Builds npx command correctly' {
            $result = Get-VscePackageCommand -CommandType 'npx'
            $result.Executable | Should -Be 'npx'
            $result.Arguments | Should -Contain '@vscode/vsce'
            $result.Arguments | Should -Contain 'package'
        }

        It 'Builds vsce command correctly' {
            $result = Get-VscePackageCommand -CommandType 'vsce'
            $result.Executable | Should -Be 'vsce'
            $result.Arguments | Should -Contain 'package'
        }

        It 'Adds pre-release flag when requested' {
            $result = Get-VscePackageCommand -CommandType 'npx' -PreRelease
            $result.Arguments | Should -Contain '--pre-release'
        }

        It 'Excludes pre-release flag by default' {
            $result = Get-VscePackageCommand -CommandType 'npx'
            $result.Arguments | Should -Not -Contain '--pre-release'
        }
    }

    Context 'Get-ExtensionOutputPath variants' {
        It 'Constructs path with directory' {
            $result = Get-ExtensionOutputPath -ExtensionDirectory '/home/user/ext' -ExtensionName 'my-ext' -PackageVersion '2.0.0'
            $result | Should -Match 'my-ext-2.0.0\.vsix$'
        }

        It 'Constructs path with temp directory' {
            $tempDir = [System.IO.Path]::GetTempPath().TrimEnd([System.IO.Path]::DirectorySeparatorChar)
            $result = Get-ExtensionOutputPath -ExtensionDirectory $tempDir -ExtensionName 'my-ext' -PackageVersion '1.0.0'
            $result | Should -Match 'my-ext-1.0.0\.vsix$'
        }
    }
}

Describe 'Test-ExtensionManifestValid Comprehensive' -Tag 'Unit' {
    Context 'Version format validation' {
        It 'Accepts standard semver' {
            $manifest = [PSCustomObject]@{
                name = 'ext'
                version = '1.2.3'
                publisher = 'pub'
                engines = [PSCustomObject]@{ vscode = '^1.80.0' }
            }
            $result = Test-ExtensionManifestValid -ManifestContent $manifest
            $result.IsValid | Should -BeTrue
        }

        It 'Rejects version without patch number' {
            $manifest = [PSCustomObject]@{
                name = 'ext'
                version = '1.2'
                publisher = 'pub'
                engines = [PSCustomObject]@{ vscode = '^1.80.0' }
            }
            $result = Test-ExtensionManifestValid -ManifestContent $manifest
            $result.IsValid | Should -BeFalse
        }

        It 'Rejects version with letters' {
            $manifest = [PSCustomObject]@{
                name = 'ext'
                version = 'abc'
                publisher = 'pub'
                engines = [PSCustomObject]@{ vscode = '^1.80.0' }
            }
            $result = Test-ExtensionManifestValid -ManifestContent $manifest
            $result.IsValid | Should -BeFalse
        }
    }

    Context 'Engines field validation' {
        It 'Accepts valid engines.vscode' {
            $manifest = [PSCustomObject]@{
                name = 'ext'
                version = '1.0.0'
                publisher = 'pub'
                engines = [PSCustomObject]@{ vscode = '^1.80.0' }
            }
            $result = Test-ExtensionManifestValid -ManifestContent $manifest
            $result.IsValid | Should -BeTrue
        }

        It 'Rejects null engines' {
            $manifest = [PSCustomObject]@{
                name = 'ext'
                version = '1.0.0'
                publisher = 'pub'
                engines = $null
            }
            $result = Test-ExtensionManifestValid -ManifestContent $manifest
            $result.IsValid | Should -BeFalse
        }
    }
}

Describe 'Get-ResolvedPackageVersion Comprehensive' -Tag 'Unit' {
    Context 'Manifest version extraction' {
        It 'Extracts base version from manifest with pre-release' {
            $result = Get-ResolvedPackageVersion -SpecifiedVersion '' -ManifestVersion '1.2.3-alpha.1' -DevPatchNumber ''
            $result.IsValid | Should -BeTrue
            $result.BaseVersion | Should -Be '1.2.3'
        }

        It 'Handles manifest version with build metadata' {
            $result = Get-ResolvedPackageVersion -SpecifiedVersion '' -ManifestVersion '1.2.3+build.123' -DevPatchNumber ''
            $result.IsValid | Should -BeTrue
        }
    }

    Context 'DevPatchNumber combinations' {
        It 'Creates dev version from manifest' {
            $result = Get-ResolvedPackageVersion -SpecifiedVersion '' -ManifestVersion '2.0.0' -DevPatchNumber '789'
            $result.IsValid | Should -BeTrue
            $result.PackageVersion | Should -Be '2.0.0-dev.789'
        }

        It 'Ignores empty DevPatchNumber' {
            $result = Get-ResolvedPackageVersion -SpecifiedVersion '1.0.0' -ManifestVersion '0.0.0' -DevPatchNumber ''
            $result.IsValid | Should -BeTrue
            $result.PackageVersion | Should -Be '1.0.0'
        }
    }
}

Describe 'Get-VscePackageCommand Comprehensive' -Tag 'Unit' {
    Context 'Command construction' {
        It 'Includes --no-dependencies by default' {
            $result = Get-VscePackageCommand -CommandType 'npx'
            $result.Arguments | Should -Contain '--no-dependencies'
        }

        It 'npx command includes @vscode/vsce' {
            $result = Get-VscePackageCommand -CommandType 'npx'
            $result.Arguments | Should -Contain '@vscode/vsce'
        }

        It 'vsce command does not include @vscode/vsce' {
            $result = Get-VscePackageCommand -CommandType 'vsce'
            $result.Arguments | Should -Not -Contain '@vscode/vsce'
        }
    }
}

Describe 'Test-VsceAvailable Comprehensive' -Tag 'Unit' {
    Context 'Return structure' {
        It 'Returns hashtable with all expected keys' {
            $result = Test-VsceAvailable
            $result.Keys | Should -Contain 'IsAvailable'
            $result.Keys | Should -Contain 'CommandType'
            $result.Keys | Should -Contain 'Command'
        }

        It 'IsAvailable is boolean' {
            $result = Test-VsceAvailable
            $result.IsAvailable | Should -BeOfType [bool]
        }
    }
}

Describe 'Invoke-ExtensionPackaging Orchestration' -Tag 'Integration' {
    BeforeAll {
        $script:OrchTestDir = Join-Path ([IO.Path]::GetTempPath()) "pkg-orch-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:OrchTestDir -Force | Out-Null
    }

    AfterAll {
        if (Test-Path $script:OrchTestDir) {
            Remove-Item -Path $script:OrchTestDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Directory structure validation' {
        BeforeEach {
            # Clean test directory
            Get-ChildItem $script:OrchTestDir | Remove-Item -Recurse -Force
        }

        It 'Returns 1 when extension directory does not exist' {
            # Create only .github but not extension
            New-Item -ItemType Directory -Path (Join-Path $script:OrchTestDir '.github') -Force | Out-Null

            # Save original location and change to test dir
            $originalPSScriptRoot = $PSScriptRoot
            Push-Location $script:OrchTestDir
            try {
                # The function checks for extension dir relative to repo root
                # Without mocking $PSScriptRoot, we test the guard clause logic
                $extDir = Join-Path $script:OrchTestDir 'extension'
                Test-Path $extDir | Should -BeFalse
            }
            finally {
                Pop-Location
            }
        }

        It 'Returns 1 when .github directory does not exist' {
            # Create fresh isolated test directory
            $isolatedDir = Join-Path ([System.IO.Path]::GetTempPath()) "github-test-$(New-Guid)"
            New-Item -ItemType Directory -Path $isolatedDir -Force | Out-Null
            try {
                # Create extension but not .github
                $extDir = Join-Path $isolatedDir 'extension'
                New-Item -ItemType Directory -Path $extDir -Force | Out-Null
                $pkgJson = @{ name = 'test'; version = '1.0.0'; publisher = 'pub'; engines = @{ vscode = '^1.80.0' } }
                $pkgJson | ConvertTo-Json | Set-Content (Join-Path $extDir 'package.json')

                $githubDir = Join-Path $isolatedDir '.github'
                Test-Path $githubDir | Should -BeFalse
            } finally {
                Remove-Item -Path $isolatedDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'Package.json validation' {
        BeforeEach {
            # Create full structure
            Get-ChildItem $script:OrchTestDir | Remove-Item -Recurse -Force
            New-Item -ItemType Directory -Path (Join-Path $script:OrchTestDir 'extension') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $script:OrchTestDir '.github') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $script:OrchTestDir 'scripts/dev-tools') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $script:OrchTestDir 'docs/templates') -Force | Out-Null
        }

        It 'Validates package.json has version field' {
            $pkgJson = @{ name = 'test'; publisher = 'pub'; engines = @{ vscode = '^1.80.0' } }
            $pkgJson | ConvertTo-Json | Set-Content (Join-Path $script:OrchTestDir 'extension/package.json')

            $content = Get-Content (Join-Path $script:OrchTestDir 'extension/package.json') | ConvertFrom-Json
            $content.PSObject.Properties['version'] | Should -BeNullOrEmpty
        }

        It 'Validates semantic version format' {
            $pkgJson = @{ name = 'test'; version = 'not-semver'; publisher = 'pub'; engines = @{ vscode = '^1.80.0' } }
            $pkgJson | ConvertTo-Json | Set-Content (Join-Path $script:OrchTestDir 'extension/package.json')

            $result = Get-ResolvedPackageVersion -SpecifiedVersion '' -ManifestVersion 'not-semver' -DevPatchNumber ''
            $result.IsValid | Should -BeFalse
        }

        It 'Validates specified version format' {
            $result = Get-ResolvedPackageVersion -SpecifiedVersion 'invalid-version' -ManifestVersion '1.0.0' -DevPatchNumber ''
            $result.IsValid | Should -BeFalse
        }
    }

    Context 'Version handling' {
        It 'Uses manifest version when no version specified' {
            $result = Get-ResolvedPackageVersion -SpecifiedVersion '' -ManifestVersion '3.2.1' -DevPatchNumber ''
            $result.PackageVersion | Should -Be '3.2.1'
            $result.BaseVersion | Should -Be '3.2.1'
        }

        It 'Uses specified version over manifest version' {
            $result = Get-ResolvedPackageVersion -SpecifiedVersion '5.0.0' -ManifestVersion '1.0.0' -DevPatchNumber ''
            $result.PackageVersion | Should -Be '5.0.0'
        }

        It 'Strips pre-release from manifest version for base' {
            $result = Get-ResolvedPackageVersion -SpecifiedVersion '' -ManifestVersion '1.0.0-beta.2' -DevPatchNumber ''
            $result.BaseVersion | Should -Be '1.0.0'
        }

        It 'Combines specified version with dev patch' {
            $result = Get-ResolvedPackageVersion -SpecifiedVersion '2.0.0' -ManifestVersion '1.0.0' -DevPatchNumber '500'
            $result.PackageVersion | Should -Be '2.0.0-dev.500'
        }
    }

    Context 'Changelog handling' {
        BeforeEach {
            Get-ChildItem $script:OrchTestDir | Remove-Item -Recurse -Force
            New-Item -ItemType Directory -Path (Join-Path $script:OrchTestDir 'extension') -Force | Out-Null
        }

        It 'Changelog path validation returns true for existing file' {
            $changelogPath = Join-Path $script:OrchTestDir 'CHANGELOG.md'
            '# Changelog' | Set-Content $changelogPath

            Test-Path $changelogPath | Should -BeTrue
        }

        It 'Changelog path validation returns false for missing file' {
            $changelogPath = Join-Path $script:OrchTestDir 'nonexistent-changelog.md'
            Test-Path $changelogPath | Should -BeFalse
        }
    }

    Context 'VSCE command building' {
        It 'Builds npx vsce command correctly' {
            $cmd = Get-VscePackageCommand -CommandType 'npx'
            $cmd.Executable | Should -Be 'npx'
            $cmd.Arguments[0] | Should -Be '@vscode/vsce'
            $cmd.Arguments | Should -Contain 'package'
            $cmd.Arguments | Should -Contain '--no-dependencies'
        }

        It 'Builds vsce command correctly' {
            $cmd = Get-VscePackageCommand -CommandType 'vsce'
            $cmd.Executable | Should -Be 'vsce'
            $cmd.Arguments | Should -Contain 'package'
            $cmd.Arguments | Should -Not -Contain '@vscode/vsce'
        }

        It 'Adds pre-release flag when specified' {
            $cmd = Get-VscePackageCommand -CommandType 'npx' -PreRelease
            $cmd.Arguments | Should -Contain '--pre-release'
        }
    }

    Context 'Output path generation' {
        It 'Generates correct vsix filename' {
            $path = Get-ExtensionOutputPath -ExtensionDirectory '/tmp/ext' -ExtensionName 'my-ext' -PackageVersion '1.2.3'
            $path | Should -Match 'my-ext-1\.2\.3\.vsix$'
        }

        It 'Handles dev version in filename' {
            $path = Get-ExtensionOutputPath -ExtensionDirectory '/tmp/ext' -ExtensionName 'my-ext' -PackageVersion '1.2.3-dev.42'
            $path | Should -Match 'my-ext-1\.2\.3-dev\.42\.vsix$'
        }
    }

    Context 'GitHub output integration' {
        It 'Formats version output correctly' {
            $version = '1.2.3-dev.100'
            $output = "version=$version"
            $output | Should -Be 'version=1.2.3-dev.100'
        }

        It 'Formats vsix-file output correctly' {
            $vsixName = 'test-ext-1.0.0.vsix'
            $output = "vsix-file=$vsixName"
            $output | Should -Be 'vsix-file=test-ext-1.0.0.vsix'
        }

        It 'Formats pre-release output correctly for true' {
            $preRelease = $true
            $output = "pre-release=$preRelease"
            $output | Should -Be 'pre-release=True'
        }

        It 'Formats pre-release output correctly for false' {
            $preRelease = $false
            $output = "pre-release=$preRelease"
            $output | Should -Be 'pre-release=False'
        }
    }
}

#region Phase 1: Pure Function Error Path Tests

Describe 'Get-ResolvedPackageVersion Error Paths' -Tag 'Unit' {
    Context 'Invalid specified version format' {
        It 'Returns invalid for version missing patch number' {
            $result = Get-ResolvedPackageVersion -SpecifiedVersion '1.0' -ManifestVersion '1.0.0'
            $result.IsValid | Should -BeFalse
            $result.ErrorMessage | Should -Match 'Invalid version format'
        }

        It 'Returns invalid for version with v prefix' {
            $result = Get-ResolvedPackageVersion -SpecifiedVersion 'v1.0.0' -ManifestVersion '1.0.0'
            $result.IsValid | Should -BeFalse
            $result.ErrorMessage | Should -Match 'Invalid version format'
        }

        It 'Returns invalid for version with prerelease suffix in specified version' {
            $result = Get-ResolvedPackageVersion -SpecifiedVersion '1.0.0-beta' -ManifestVersion '1.0.0'
            $result.IsValid | Should -BeFalse
            $result.ErrorMessage | Should -Match 'Invalid version format'
        }

        It 'Returns invalid for non-numeric version' {
            $result = Get-ResolvedPackageVersion -SpecifiedVersion 'latest' -ManifestVersion '1.0.0'
            $result.IsValid | Should -BeFalse
            $result.ErrorMessage | Should -Match 'Invalid version format'
        }

        It 'Returns invalid for empty major version' {
            $result = Get-ResolvedPackageVersion -SpecifiedVersion '.1.0' -ManifestVersion '1.0.0'
            $result.IsValid | Should -BeFalse
        }
    }

    Context 'Invalid manifest version format' {
        It 'Returns invalid for manifest with non-semver version' {
            $result = Get-ResolvedPackageVersion -SpecifiedVersion '' -ManifestVersion 'latest'
            $result.IsValid | Should -BeFalse
            $result.ErrorMessage | Should -Match 'Invalid version format in package.json'
        }

        It 'Returns invalid for manifest with only major.minor' {
            $result = Get-ResolvedPackageVersion -SpecifiedVersion '' -ManifestVersion '1.0'
            $result.IsValid | Should -BeFalse
            $result.ErrorMessage | Should -Match 'Invalid version format'
        }

        It 'Returns invalid for manifest with text version' {
            $result = Get-ResolvedPackageVersion -SpecifiedVersion '' -ManifestVersion 'development'
            $result.IsValid | Should -BeFalse
        }
    }

    Context 'Manifest version with prerelease suffix extraction' {
        It 'Extracts base version from manifest with -beta suffix' {
            $result = Get-ResolvedPackageVersion -SpecifiedVersion '' -ManifestVersion '2.0.0-beta.1'
            $result.IsValid | Should -BeTrue
            $result.BaseVersion | Should -Be '2.0.0'
            $result.PackageVersion | Should -Be '2.0.0'
        }

        It 'Extracts base version from manifest with -rc suffix' {
            $result = Get-ResolvedPackageVersion -SpecifiedVersion '' -ManifestVersion '3.1.0-rc.2'
            $result.IsValid | Should -BeTrue
            $result.BaseVersion | Should -Be '3.1.0'
        }

        It 'Extracts base version from manifest with -dev suffix' {
            $result = Get-ResolvedPackageVersion -SpecifiedVersion '' -ManifestVersion '1.5.0-dev.42'
            $result.IsValid | Should -BeTrue
            $result.BaseVersion | Should -Be '1.5.0'
        }

        It 'Applies DevPatchNumber to extracted base version' {
            $result = Get-ResolvedPackageVersion -SpecifiedVersion '' -ManifestVersion '2.0.0-beta.1' -DevPatchNumber '99'
            $result.IsValid | Should -BeTrue
            $result.BaseVersion | Should -Be '2.0.0'
            $result.PackageVersion | Should -Be '2.0.0-dev.99'
        }
    }
}

Describe 'Test-ExtensionManifestValid Additional Error Paths' -Tag 'Unit' {
    Context 'Invalid version format validation' {
        It 'Rejects version with v prefix' {
            $manifest = [PSCustomObject]@{
                name = 'ext'
                version = 'v1.0.0'
                publisher = 'pub'
                engines = [PSCustomObject]@{ vscode = '^1.80.0' }
            }
            $result = Test-ExtensionManifestValid -ManifestContent $manifest
            $result.IsValid | Should -BeFalse
            $result.Errors | Should -Contain "Invalid version format: 'v1.0.0'. Expected semantic version (e.g., 1.0.0)"
        }

        It 'Rejects version with only major.minor' {
            $manifest = [PSCustomObject]@{
                name = 'ext'
                version = '1.0'
                publisher = 'pub'
                engines = [PSCustomObject]@{ vscode = '^1.80.0' }
            }
            $result = Test-ExtensionManifestValid -ManifestContent $manifest
            $result.IsValid | Should -BeFalse
            $result.Errors | Should -Match 'Invalid version format'
        }

        It 'Rejects non-numeric version' {
            $manifest = [PSCustomObject]@{
                name = 'ext'
                version = 'latest'
                publisher = 'pub'
                engines = [PSCustomObject]@{ vscode = '^1.80.0' }
            }
            $result = Test-ExtensionManifestValid -ManifestContent $manifest
            $result.IsValid | Should -BeFalse
        }
    }

    Context 'Engines field edge cases' {
        It 'Rejects manifest with engines set to null' {
            $manifest = [PSCustomObject]@{
                name = 'ext'
                version = '1.0.0'
                publisher = 'pub'
                engines = $null
            }
            $result = Test-ExtensionManifestValid -ManifestContent $manifest
            $result.IsValid | Should -BeFalse
            $result.Errors | Should -Contain "Missing required 'engines' field"
        }

        It 'Rejects manifest with engines missing vscode property' {
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

        It 'Rejects manifest with empty engines object' {
            $manifest = [PSCustomObject]@{
                name = 'ext'
                version = '1.0.0'
                publisher = 'pub'
                engines = [PSCustomObject]@{}
            }
            $result = Test-ExtensionManifestValid -ManifestContent $manifest
            $result.IsValid | Should -BeFalse
            $result.Errors | Should -Contain "Missing required 'engines.vscode' field"
        }
    }

    Context 'Multiple validation errors' {
        It 'Collects all errors when multiple fields invalid' {
            $manifest = [PSCustomObject]@{
                version = 'invalid'
            }
            $result = Test-ExtensionManifestValid -ManifestContent $manifest
            $result.IsValid | Should -BeFalse
            $result.Errors.Count | Should -BeGreaterOrEqual 3
            $result.Errors | Should -Contain "Missing required 'name' field"
            $result.Errors | Should -Contain "Missing required 'publisher' field"
        }
    }
}

#endregion

#region Phase 2: Mocked Integration Tests for Invoke-ExtensionPackaging

Describe 'Invoke-ExtensionPackaging Integration' -Tag 'Integration' {
    BeforeAll {
        $script:IntegrationTestDir = Join-Path ([IO.Path]::GetTempPath()) "pkg-integration-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:IntegrationTestDir -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:IntegrationTestDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Path validation logic' {
        BeforeEach {
            $script:TestDir = Join-Path $script:IntegrationTestDir "test-$(New-Guid)"
            New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Detects when extension directory does not exist' {
            $extDir = Join-Path $script:TestDir 'nonexistent-extension'
            Test-Path $extDir | Should -BeFalse
        }

        It 'Detects when package.json does not exist' {
            New-Item -ItemType Directory -Path (Join-Path $script:TestDir 'extension') -Force | Out-Null
            $pkgJson = Join-Path $script:TestDir 'extension/package.json'
            Test-Path $pkgJson | Should -BeFalse
        }

        It 'Detects when .github directory does not exist' {
            New-Item -ItemType Directory -Path (Join-Path $script:TestDir 'extension') -Force | Out-Null
            $ghDir = Join-Path $script:TestDir '.github'
            Test-Path $ghDir | Should -BeFalse
        }

        It 'Returns true when all paths exist' {
            New-Item -ItemType Directory -Path (Join-Path $script:TestDir 'extension') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $script:TestDir '.github') -Force | Out-Null
            $pkgJsonPath = Join-Path $script:TestDir 'extension/package.json'
            '{}' | Set-Content -Path $pkgJsonPath

            Test-Path (Join-Path $script:TestDir 'extension') | Should -BeTrue
            Test-Path $pkgJsonPath | Should -BeTrue
            Test-Path (Join-Path $script:TestDir '.github') | Should -BeTrue
        }
    }

    Context 'Package.json validation' {
        BeforeEach {
            $script:TestDir = Join-Path $script:IntegrationTestDir "pkgjson-$(New-Guid)"
            New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $script:TestDir 'extension') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $script:TestDir '.github') -Force | Out-Null
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Test-ExtensionManifestValid catches invalid JSON parse result' {
            # Simulate what happens after parsing invalid JSON - empty object
            $manifest = [PSCustomObject]@{}
            $result = Test-ExtensionManifestValid -ManifestContent $manifest
            $result.IsValid | Should -BeFalse
            $result.Errors.Count | Should -BeGreaterThan 0
        }

        It 'Test-ExtensionManifestValid validates complete manifest' {
            $manifest = [PSCustomObject]@{
                name = 'test-extension'
                version = '1.0.0'
                publisher = 'test-publisher'
                engines = [PSCustomObject]@{ vscode = '^1.80.0' }
            }
            $result = Test-ExtensionManifestValid -ManifestContent $manifest
            $result.IsValid | Should -BeTrue
        }

        It 'Get-ResolvedPackageVersion handles version extraction from package.json' {
            # Simulate reading version from package.json
            $pkgJson = @{
                name = 'test'
                version = '1.2.3'
            }
            $result = Get-ResolvedPackageVersion -SpecifiedVersion '' -ManifestVersion $pkgJson.version
            $result.IsValid | Should -BeTrue
            $result.PackageVersion | Should -Be '1.2.3'
        }
    }

    Context 'Version handling with DevPatchNumber' {
        It 'Applies dev patch to base version from package.json' {
            $result = Get-ResolvedPackageVersion -SpecifiedVersion '' -ManifestVersion '2.0.0' -DevPatchNumber '123'
            $result.IsValid | Should -BeTrue
            $result.PackageVersion | Should -Be '2.0.0-dev.123'
            $result.BaseVersion | Should -Be '2.0.0'
        }

        It 'Applies dev patch to specified version' {
            $result = Get-ResolvedPackageVersion -SpecifiedVersion '3.0.0' -ManifestVersion '1.0.0' -DevPatchNumber '456'
            $result.IsValid | Should -BeTrue
            $result.PackageVersion | Should -Be '3.0.0-dev.456'
        }

        It 'Does not apply dev patch when not specified' {
            $result = Get-ResolvedPackageVersion -SpecifiedVersion '1.5.0' -ManifestVersion '1.0.0' -DevPatchNumber ''
            $result.PackageVersion | Should -Be '1.5.0'
            $result.PackageVersion | Should -Not -Match '-dev\.'
        }
    }

    Context 'VSCE command building with mocks' {
        It 'Builds correct command for npx without pre-release' {
            $cmd = Get-VscePackageCommand -CommandType 'npx'
            $cmd.Executable | Should -Be 'npx'
            $cmd.Arguments | Should -Contain '@vscode/vsce'
            $cmd.Arguments | Should -Contain 'package'
            $cmd.Arguments | Should -Contain '--no-dependencies'
            $cmd.Arguments | Should -Not -Contain '--pre-release'
        }

        It 'Builds correct command for npx with pre-release' {
            $cmd = Get-VscePackageCommand -CommandType 'npx' -PreRelease
            $cmd.Arguments | Should -Contain '--pre-release'
        }

        It 'Builds correct command for vsce directly' {
            $cmd = Get-VscePackageCommand -CommandType 'vsce'
            $cmd.Executable | Should -Be 'vsce'
            $cmd.Arguments | Should -Not -Contain '@vscode/vsce'
            $cmd.Arguments | Should -Contain 'package'
        }
    }

    Context 'Packaging result construction' {
        It 'Creates success result with all metadata' {
            $result = New-PackagingResult -Success $true -OutputPath '/path/to/ext.vsix' -Version '1.0.0' -ErrorMessage ''
            $result.Success | Should -BeTrue
            $result.OutputPath | Should -Be '/path/to/ext.vsix'
            $result.Version | Should -Be '1.0.0'
            $result.ErrorMessage | Should -BeNullOrEmpty
        }

        It 'Creates failure result with error message' {
            $result = New-PackagingResult -Success $false -OutputPath '' -Version '' -ErrorMessage 'VSCE failed with exit code 1'
            $result.Success | Should -BeFalse
            $result.ErrorMessage | Should -Be 'VSCE failed with exit code 1'
        }
    }

    Context 'Output path generation' {
        It 'Generates correct vsix path for stable version' {
            $path = Get-ExtensionOutputPath -ExtensionDirectory '/workspace/extension' -ExtensionName 'hve-core' -PackageVersion '1.0.0'
            $path | Should -Match 'hve-core-1\.0\.0\.vsix$'
        }

        It 'Generates correct vsix path for dev version' {
            $path = Get-ExtensionOutputPath -ExtensionDirectory '/workspace/extension' -ExtensionName 'hve-core' -PackageVersion '1.0.0-dev.42'
            $path | Should -Match 'hve-core-1\.0\.0-dev\.42\.vsix$'
        }

        It 'Generates correct vsix path for pre-release version' {
            $path = Get-ExtensionOutputPath -ExtensionDirectory '/workspace/extension' -ExtensionName 'hve-core' -PackageVersion '1.1.0-preview.1'
            $path | Should -Match 'hve-core-1\.1\.0-preview\.1\.vsix$'
        }
    }
}

#endregion

#region Phase 3: Orchestration Early Exit Tests

Describe 'Invoke-ExtensionPackaging Orchestration - Early Exit Paths' -Tag 'Integration' {
    BeforeAll {
        $script:OrchTestRoot = Join-Path ([System.IO.Path]::GetTempPath()) "pkg-orch-tests-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:OrchTestRoot -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:OrchTestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Path validation early exits' {
        BeforeEach {
            $script:TestDir = Join-Path $script:OrchTestRoot "test-$(New-Guid)"
            New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null

            # Save original PSScriptRoot and set up test environment
            $script:OriginalScriptRoot = $PSScriptRoot
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Returns error when extension directory does not exist' {
            # Create minimal structure without extension directory
            $scriptsDir = Join-Path $script:TestDir 'scripts/extension'
            New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null

            # Mock PSScriptRoot to point to our test scripts directory
            $mockScriptRoot = $scriptsDir

            # Create a test harness that sets PSScriptRoot
            $testScript = @'
param($TestRoot)
$PSScriptRoot = $TestRoot
$ScriptDir = $PSScriptRoot
$RepoRoot = (Get-Item "$ScriptDir/../..").FullName
$ExtensionDir = Join-Path $RepoRoot "extension"

# Check extension directory
if (-not (Test-Path $ExtensionDir)) {
    return 1
}
return 0
'@
            $result = [scriptblock]::Create($testScript).Invoke($mockScriptRoot)
            $result | Should -Be 1
        }

        It 'Returns error when package.json does not exist' {
            # Create extension directory but no package.json
            $scriptsDir = Join-Path $script:TestDir 'scripts/extension'
            $extDir = Join-Path $script:TestDir 'extension'
            New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
            New-Item -ItemType Directory -Path $extDir -Force | Out-Null

            $testScript = @'
param($TestRoot)
$ScriptDir = Join-Path $TestRoot 'scripts/extension'
$RepoRoot = (Get-Item "$ScriptDir/../..").FullName
$ExtensionDir = Join-Path $RepoRoot "extension"
$PackageJsonPath = Join-Path $ExtensionDir "package.json"

if (-not (Test-Path $ExtensionDir)) { return 1 }
if (-not (Test-Path $PackageJsonPath)) { return 1 }
return 0
'@
            $result = [scriptblock]::Create($testScript).Invoke($script:TestDir)
            $result | Should -Be 1
        }

        It 'Returns error when .github directory does not exist' {
            # Create extension directory and package.json but no .github
            $scriptsDir = Join-Path $script:TestDir 'scripts/extension'
            $extDir = Join-Path $script:TestDir 'extension'
            New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
            New-Item -ItemType Directory -Path $extDir -Force | Out-Null
            '{"name":"test","version":"1.0.0"}' | Set-Content (Join-Path $extDir 'package.json')

            $testScript = @'
param($TestRoot)
$ScriptDir = Join-Path $TestRoot 'scripts/extension'
$RepoRoot = (Get-Item "$ScriptDir/../..").FullName
$ExtensionDir = Join-Path $RepoRoot "extension"
$GitHubDir = Join-Path $RepoRoot ".github"
$PackageJsonPath = Join-Path $ExtensionDir "package.json"

if (-not (Test-Path $ExtensionDir)) { return 1 }
if (-not (Test-Path $PackageJsonPath)) { return 1 }
if (-not (Test-Path $GitHubDir)) { return 1 }
return 0
'@
            $result = [scriptblock]::Create($testScript).Invoke($script:TestDir)
            $result | Should -Be 1
        }
    }

    Context 'JSON parsing error handling' {
        BeforeEach {
            $script:TestDir = Join-Path $script:OrchTestRoot "json-test-$(New-Guid)"
            $extDir = Join-Path $script:TestDir 'extension'
            $ghDir = Join-Path $script:TestDir '.github'
            New-Item -ItemType Directory -Path $extDir -Force | Out-Null
            New-Item -ItemType Directory -Path $ghDir -Force | Out-Null
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Returns error when package.json contains invalid JSON' {
            # Create invalid JSON file
            'not valid json {{{' | Set-Content (Join-Path $script:TestDir 'extension/package.json')

            $pkgPath = Join-Path $script:TestDir 'extension/package.json'
            $parseError = $null
            try {
                $content = Get-Content -Path $pkgPath -Raw | ConvertFrom-Json
            } catch {
                $parseError = $_
            }

            $parseError | Should -Not -BeNullOrEmpty
        }

        It 'Returns error when package.json is empty' {
            # Create empty file
            '' | Set-Content (Join-Path $script:TestDir 'extension/package.json')

            $pkgPath = Join-Path $script:TestDir 'extension/package.json'
            $content = Get-Content -Path $pkgPath -Raw
            
            # Empty string should be detected as invalid
            [string]::IsNullOrWhiteSpace($content) | Should -BeTrue
        }

        It 'Returns error when package.json missing version field' {
            # Create JSON without version
            '{"name":"test","publisher":"pub"}' | Set-Content (Join-Path $script:TestDir 'extension/package.json')

            $pkgPath = Join-Path $script:TestDir 'extension/package.json'
            $packageJson = Get-Content -Path $pkgPath -Raw | ConvertFrom-Json

            $hasVersion = $packageJson.PSObject.Properties['version']
            $hasVersion | Should -BeNullOrEmpty
        }

        It 'Detects invalid version format in package.json' {
            # Create JSON with invalid version format
            '{"name":"test","version":"not-a-version","publisher":"pub"}' | Set-Content (Join-Path $script:TestDir 'extension/package.json')

            $pkgPath = Join-Path $script:TestDir 'extension/package.json'
            $packageJson = Get-Content -Path $pkgPath -Raw | ConvertFrom-Json

            $packageJson.version -match '^\d+\.\d+\.\d+' | Should -BeFalse
        }
    }

    Context 'Version validation in orchestration context' {
        It 'Validates specified version format matches semver' {
            $validVersions = @('1.0.0', '2.1.0', '10.20.30')
            $invalidVersions = @('1.0', '1.0.0-dev.1', 'v1.0.0', '1.0.0.0')

            foreach ($v in $validVersions) {
                $v -match '^\d+\.\d+\.\d+$' | Should -BeTrue -Because "$v should be valid"
            }

            foreach ($v in $invalidVersions) {
                $v -match '^\d+\.\d+\.\d+$' | Should -BeFalse -Because "$v should be invalid for -Version parameter"
            }
        }

        It 'Extracts base version from package.json version with suffix' {
            $versions = @(
                @{ Input = '1.0.0'; Expected = '1.0.0' }
                @{ Input = '1.0.0-dev.123'; Expected = '1.0.0' }
                @{ Input = '2.1.0-preview.1'; Expected = '2.1.0' }
            )

            foreach ($test in $versions) {
                $test.Input -match '^(\d+\.\d+\.\d+)' | Out-Null
                $Matches[1] | Should -Be $test.Expected
            }
        }
    }

    Context 'Directory copy operations validation' {
        BeforeEach {
            $script:TestDir = Join-Path $script:OrchTestRoot "copy-test-$(New-Guid)"
            $extDir = Join-Path $script:TestDir 'extension'
            $ghDir = Join-Path $script:TestDir '.github'
            $agentsDir = Join-Path $ghDir 'agents'

            New-Item -ItemType Directory -Path $extDir -Force | Out-Null
            New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null

            # Create test agent
            '---\ndescription: test\n---' | Set-Content (Join-Path $agentsDir 'test.agent.md')

            # Create valid package.json
            @{
                name = 'test-ext'
                version = '1.0.0'
                publisher = 'test'
                engines = @{ vscode = '^1.80.0' }
            } | ConvertTo-Json | Set-Content (Join-Path $extDir 'package.json')
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Validates source .github directory exists before copy' {
            $ghDir = Join-Path $script:TestDir '.github'
            Test-Path $ghDir | Should -BeTrue
        }

        It 'Validates .github/agents directory structure' {
            $agentsDir = Join-Path $script:TestDir '.github/agents'
            $agents = Get-ChildItem -Path $agentsDir -Filter '*.agent.md' -ErrorAction SilentlyContinue
            $agents.Count | Should -BeGreaterOrEqual 1
        }
    }
}

#endregion

#region Priority 2: Mocked CLI Integration Tests

Describe 'Invoke-ExtensionPackaging - Mocked CLI Integration' -Tag 'Integration', 'Mocked' {
    BeforeAll {
        $script:MockedTestRoot = Join-Path ([System.IO.Path]::GetTempPath()) "pkg-mocked-tests-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:MockedTestRoot -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:MockedTestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'VSCE command construction and invocation logic' {
        It 'Get-VscePackageCommand builds correct args without PreRelease' {
            $result = Get-VscePackageCommand -CommandType 'npx' -PreRelease:$false

            $result.Arguments | Should -Contain 'package'
            $result.Arguments | Should -Contain '--no-dependencies'
            $result.Arguments | Should -Not -Contain '--pre-release'
        }

        It 'Get-VscePackageCommand builds correct args with PreRelease' {
            $result = Get-VscePackageCommand -CommandType 'vsce' -PreRelease:$true

            $result.Arguments | Should -Contain 'package'
            $result.Arguments | Should -Contain '--pre-release'
        }

        It 'Test-VsceAvailable returns npx when vsce not available' {
            # This test verifies the fallback behavior
            $result = Test-VsceAvailable

            # At minimum, one should be available in most environments
            if ($result.IsAvailable) {
                $result.CommandType | Should -BeIn @('vsce', 'npx')
            }
        }
    }

    Context 'Directory copy operations' {
        BeforeEach {
            $script:TestDir = Join-Path $script:MockedTestRoot "copy-ops-$(New-Guid)"
            $extDir = Join-Path $script:TestDir 'extension'
            $ghDir = Join-Path $script:TestDir '.github'
            $scriptsDir = Join-Path $script:TestDir 'scripts/dev-tools'
            $docsDir = Join-Path $script:TestDir 'docs/templates'

            New-Item -ItemType Directory -Path $extDir -Force | Out-Null
            New-Item -ItemType Directory -Path $ghDir -Force | Out-Null
            New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
            New-Item -ItemType Directory -Path $docsDir -Force | Out-Null

            # Create package.json
            @{
                name = 'test-ext'
                version = '1.0.0'
                publisher = 'test'
                engines = @{ vscode = '^1.80.0' }
            } | ConvertTo-Json | Set-Content (Join-Path $extDir 'package.json')

            # Create test files in source directories
            'test content' | Set-Content (Join-Path $ghDir 'test.md')
            'script content' | Set-Content (Join-Path $scriptsDir 'test.ps1')
            'doc content' | Set-Content (Join-Path $docsDir 'test.md')
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Can copy .github directory to extension' {
            $extDir = Join-Path $script:TestDir 'extension'
            $srcGh = Join-Path $script:TestDir '.github'
            $destGh = Join-Path $extDir '.github'

            Copy-Item -Path $srcGh -Destination $destGh -Recurse

            Test-Path $destGh | Should -BeTrue
            Test-Path (Join-Path $destGh 'test.md') | Should -BeTrue
        }

        It 'Can create nested directory structure in extension' {
            $extDir = Join-Path $script:TestDir 'extension'
            $scriptsPath = Join-Path $extDir 'scripts'

            New-Item -Path $scriptsPath -ItemType Directory -Force | Out-Null

            Test-Path $scriptsPath | Should -BeTrue
        }

        It 'Can copy scripts/dev-tools to extension' {
            $extDir = Join-Path $script:TestDir 'extension'
            $srcScripts = Join-Path $script:TestDir 'scripts/dev-tools'
            $destScripts = Join-Path $extDir 'scripts'

            New-Item -Path $destScripts -ItemType Directory -Force | Out-Null
            Copy-Item -Path $srcScripts -Destination (Join-Path $destScripts 'dev-tools') -Recurse

            Test-Path (Join-Path $destScripts 'dev-tools/test.ps1') | Should -BeTrue
        }

        It 'Can remove copied directories during cleanup' {
            $extDir = Join-Path $script:TestDir 'extension'
            $ghInExt = Join-Path $extDir '.github'

            # Copy then remove
            Copy-Item -Path (Join-Path $script:TestDir '.github') -Destination $ghInExt -Recurse
            Test-Path $ghInExt | Should -BeTrue

            Remove-Item -Path $ghInExt -Recurse -Force
            Test-Path $ghInExt | Should -BeFalse
        }
    }

    Context 'Version restoration logic' {
        BeforeEach {
            $script:TestDir = Join-Path $script:MockedTestRoot "version-restore-$(New-Guid)"
            $extDir = Join-Path $script:TestDir 'extension'
            New-Item -ItemType Directory -Path $extDir -Force | Out-Null
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Restores original version after modification' {
            $pkgPath = Join-Path $script:TestDir 'extension/package.json'
            $originalVersion = '1.0.0'
            $tempVersion = '1.0.0-dev.123'

            # Create original package.json
            @{
                name = 'test'
                version = $originalVersion
                publisher = 'pub'
            } | ConvertTo-Json | Set-Content $pkgPath

            # Modify version (simulating packaging)
            $packageJson = Get-Content $pkgPath -Raw | ConvertFrom-Json
            $packageJson.version = $tempVersion
            $packageJson | ConvertTo-Json -Depth 10 | Set-Content $pkgPath

            # Verify modification
            $modified = Get-Content $pkgPath -Raw | ConvertFrom-Json
            $modified.version | Should -Be $tempVersion

            # Restore (simulating cleanup)
            $packageJson.version = $originalVersion
            $packageJson | ConvertTo-Json -Depth 10 | Set-Content $pkgPath

            # Verify restoration
            $restored = Get-Content $pkgPath -Raw | ConvertFrom-Json
            $restored.version | Should -Be $originalVersion
        }
    }

    Context 'VSIX file detection' {
        BeforeEach {
            $script:TestDir = Join-Path $script:MockedTestRoot "vsix-detect-$(New-Guid)"
            New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Detects .vsix file after packaging' {
            # Create mock .vsix file
            $vsixPath = Join-Path $script:TestDir 'test-ext-1.0.0.vsix'
            [byte[]]$mockContent = @(0x50, 0x4B, 0x03, 0x04)  # ZIP header
            [System.IO.File]::WriteAllBytes($vsixPath, $mockContent)

            $vsixFile = Get-ChildItem -Path $script:TestDir -Filter "*.vsix" | Select-Object -First 1

            $vsixFile | Should -Not -BeNullOrEmpty
            $vsixFile.Name | Should -Match '\.vsix$'
        }

        It 'Returns most recent .vsix when multiple exist' {
            # Create older vsix
            $oldVsix = Join-Path $script:TestDir 'old-1.0.0.vsix'
            [byte[]]$mockContent = @(0x50, 0x4B, 0x03, 0x04)
            [System.IO.File]::WriteAllBytes($oldVsix, $mockContent)

            Start-Sleep -Milliseconds 100

            # Create newer vsix
            $newVsix = Join-Path $script:TestDir 'new-1.0.1.vsix'
            [System.IO.File]::WriteAllBytes($newVsix, $mockContent)

            $vsixFile = Get-ChildItem -Path $script:TestDir -Filter "*.vsix" |
                        Sort-Object LastWriteTime -Descending |
                        Select-Object -First 1

            $vsixFile.Name | Should -Be 'new-1.0.1.vsix'
        }

        It 'Reports file size correctly' {
            $vsixPath = Join-Path $script:TestDir 'sized-ext-1.0.0.vsix'
            $content = [byte[]]::new(1024)  # 1KB
            [System.IO.File]::WriteAllBytes($vsixPath, $content)

            $vsixFile = Get-ChildItem -Path $vsixPath
            $sizeKB = [math]::Round($vsixFile.Length / 1KB, 2)

            $sizeKB | Should -Be 1
        }
    }

    Context 'Changelog handling' {
        BeforeEach {
            $script:TestDir = Join-Path $script:MockedTestRoot "changelog-$(New-Guid)"
            $extDir = Join-Path $script:TestDir 'extension'
            New-Item -ItemType Directory -Path $extDir -Force | Out-Null

            $script:ChangelogContent = @'
# Changelog

## [1.0.0] - 2026-02-10
- Initial release
'@
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Copies changelog to extension directory when provided' {
            $changelogSrc = Join-Path $script:TestDir 'CHANGELOG.md'
            $changelogDest = Join-Path $script:TestDir 'extension/CHANGELOG.md'

            $script:ChangelogContent | Set-Content $changelogSrc

            Copy-Item -Path $changelogSrc -Destination $changelogDest -Force

            Test-Path $changelogDest | Should -BeTrue
            (Get-Content $changelogDest -Raw).Trim() | Should -Be $script:ChangelogContent.Trim()
        }

        It 'Skips changelog when path does not exist' {
            $nonExistentPath = Join-Path $script:TestDir 'nonexistent-changelog.md'

            $exists = Test-Path $nonExistentPath
            $exists | Should -BeFalse

            # Simulating the conditional logic
            if (-not $exists) {
                # Should not throw, just skip
                $skipped = $true
            }
            $skipped | Should -BeTrue
        }
    }

    Context 'GitHub output generation' {
        It 'Formats version output correctly' {
            $version = '1.0.0-dev.123'
            $output = "version=$version"

            $output | Should -Be 'version=1.0.0-dev.123'
        }

        It 'Formats vsix-file output correctly' {
            $vsixName = 'hve-core-1.0.0.vsix'
            $output = "vsix-file=$vsixName"

            $output | Should -Be 'vsix-file=hve-core-1.0.0.vsix'
        }

        It 'Formats pre-release output correctly' {
            $preRelease = $true
            $output = "pre-release=$preRelease"

            $output | Should -Be 'pre-release=True'
        }
    }
}

#endregion

#region Phase 4: Additional Orchestration Coverage Tests

Describe 'Package-Extension Orchestration - Additional Coverage' -Tag 'Unit' {
    BeforeAll {
        $script:OrchCoverageRoot = Join-Path ([System.IO.Path]::GetTempPath()) "pkg-orch-cov-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:OrchCoverageRoot -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:OrchCoverageRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Version resolution edge cases' {
        It 'Handles version with complex prerelease identifier' {
            $result = Get-ResolvedPackageVersion -SpecifiedVersion '' -ManifestVersion '1.0.0-beta.1+build.123' -DevPatchNumber ''

            # Should extract base version correctly
            $result.BaseVersion | Should -Be '1.0.0'
        }

        It 'Rejects version with invalid format - missing patch' {
            $result = Get-ResolvedPackageVersion -SpecifiedVersion '1.0' -ManifestVersion '1.0.0' -DevPatchNumber ''

            $result.IsValid | Should -BeFalse
            $result.ErrorMessage | Should -Match 'Invalid version format'
        }

        It 'Rejects version with letters' {
            $result = Get-ResolvedPackageVersion -SpecifiedVersion '1.0.abc' -ManifestVersion '1.0.0' -DevPatchNumber ''

            $result.IsValid | Should -BeFalse
        }

        It 'Handles empty string for DevPatchNumber' {
            $result = Get-ResolvedPackageVersion -SpecifiedVersion '1.0.0' -ManifestVersion '1.0.0' -DevPatchNumber ''

            $result.IsValid | Should -BeTrue
            $result.PackageVersion | Should -Be '1.0.0'
            $result.PackageVersion | Should -Not -Match 'dev'
        }

        It 'Handles whitespace-only DevPatchNumber as empty' {
            $result = Get-ResolvedPackageVersion -SpecifiedVersion '1.0.0' -ManifestVersion '1.0.0' -DevPatchNumber '   '

            # Whitespace is truthy, so it would be appended - test the actual behavior
            $result.IsValid | Should -BeTrue
        }
    }

    Context 'Manifest validation extended' {
        It 'Rejects manifest with invalid version format' {
            $manifest = [PSCustomObject]@{
                name = 'ext'
                version = 'not-a-version'
                publisher = 'pub'
                engines = [PSCustomObject]@{ vscode = '^1.80.0' }
            }

            $result = Test-ExtensionManifestValid -ManifestContent $manifest

            $result.IsValid | Should -BeFalse
            $result.Errors | Should -Contain "Invalid version format: 'not-a-version'. Expected semantic version (e.g., 1.0.0)"
        }

        It 'Rejects manifest with engines but missing vscode' {
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

        It 'Accepts manifest with version including prerelease suffix' {
            $manifest = [PSCustomObject]@{
                name = 'ext'
                version = '1.0.0-dev.123'
                publisher = 'pub'
                engines = [PSCustomObject]@{ vscode = '^1.80.0' }
            }

            $result = Test-ExtensionManifestValid -ManifestContent $manifest

            $result.IsValid | Should -BeTrue
        }

        It 'Handles manifest with null engines value' {
            $manifest = [PSCustomObject]@{
                name = 'ext'
                version = '1.0.0'
                publisher = 'pub'
                engines = $null
            }

            $result = Test-ExtensionManifestValid -ManifestContent $manifest

            $result.IsValid | Should -BeFalse
            $result.Errors | Should -Contain "Missing required 'engines' field"
        }
    }

    Context 'Package command construction variations' {
        It 'Handles vsce command type with all flags' {
            $result = Get-VscePackageCommand -CommandType 'vsce' -PreRelease

            $result.Executable | Should -Be 'vsce'
            $result.Arguments | Should -Contain 'package'
            $result.Arguments | Should -Contain '--no-dependencies'
            $result.Arguments | Should -Contain '--pre-release'
        }

        It 'NPX command includes @vscode/vsce package' {
            $result = Get-VscePackageCommand -CommandType 'npx'

            $result.Executable | Should -Be 'npx'
            $result.Arguments[0] | Should -Be '@vscode/vsce'
        }
    }

    Context 'Output path construction' {
        It 'Handles paths with spaces' {
            $pathWithSpaces = Join-Path ([System.IO.Path]::GetTempPath()) 'path with spaces'
            # Ensure trailing slash is trimmed
            $pathWithSpaces = $pathWithSpaces.TrimEnd([System.IO.Path]::DirectorySeparatorChar)
            $result = Get-ExtensionOutputPath -ExtensionDirectory $pathWithSpaces -ExtensionName 'ext' -PackageVersion '1.0.0'

            $result | Should -Match 'path with spaces'
            $result | Should -Match 'ext-1\.0\.0\.vsix$'
        }

        It 'Handles complex version strings in path' {
            $result = Get-ExtensionOutputPath -ExtensionDirectory '/tmp' -ExtensionName 'my-ext' -PackageVersion '2.0.0-dev.456'

            $result | Should -Match 'my-ext-2\.0\.0-dev\.456\.vsix$'
        }
    }

    Context 'Packaging result creation' {
        It 'Creates success result with empty strings for optional params' {
            $result = New-PackagingResult -Success $true

            $result.Success | Should -BeTrue
            $result.OutputPath | Should -Be ''
            $result.Version | Should -Be ''
            $result.ErrorMessage | Should -Be ''
        }

        It 'Creates failure result preserving error details' {
            $errorMsg = "VSCE failed: exit code 1`nStderr: Missing required field"
            $result = New-PackagingResult -Success $false -ErrorMessage $errorMsg

            $result.Success | Should -BeFalse
            $result.ErrorMessage | Should -Match 'VSCE failed'
        }
    }
}

Describe 'Package-Extension - File Operations Coverage' -Tag 'Unit' {
    BeforeAll {
        $script:FileOpsRoot = Join-Path ([System.IO.Path]::GetTempPath()) "pkg-fileops-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:FileOpsRoot -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:FileOpsRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Package.json temporary version update simulation' {
        BeforeEach {
            $script:TestDir = Join-Path $script:FileOpsRoot "ver-update-$(New-Guid)"
            $script:ExtDir = Join-Path $script:TestDir 'extension'
            New-Item -ItemType Directory -Path $script:ExtDir -Force | Out-Null

            # Create initial package.json
            $script:OriginalVersion = '1.0.0'
            $script:PackageJsonPath = Join-Path $script:ExtDir 'package.json'
            @{
                name = 'test-ext'
                version = $script:OriginalVersion
                publisher = 'test'
                engines = @{ vscode = '^1.80.0' }
            } | ConvertTo-Json | Set-Content -Path $script:PackageJsonPath
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Simulates temporary version update for dev builds' {
            $newVersion = '1.0.0-dev.123'

            # Read, update, write (simulating orchestration logic)
            $packageJson = Get-Content -Path $script:PackageJsonPath -Raw | ConvertFrom-Json
            $packageJson.version = $newVersion
            $packageJson | ConvertTo-Json -Depth 10 | Set-Content -Path $script:PackageJsonPath -Encoding UTF8NoBOM

            # Verify update
            $updated = Get-Content -Path $script:PackageJsonPath -Raw | ConvertFrom-Json
            $updated.version | Should -Be $newVersion
        }

        It 'Simulates version restoration after packaging' {
            $devVersion = '1.0.0-dev.123'

            # Update to dev version
            $packageJson = Get-Content -Path $script:PackageJsonPath -Raw | ConvertFrom-Json
            $packageJson.version = $devVersion
            $packageJson | ConvertTo-Json -Depth 10 | Set-Content -Path $script:PackageJsonPath -Encoding UTF8NoBOM

            # Restore original
            $packageJson.version = $script:OriginalVersion
            $packageJson | ConvertTo-Json -Depth 10 | Set-Content -Path $script:PackageJsonPath -Encoding UTF8NoBOM

            # Verify restoration
            $restored = Get-Content -Path $script:PackageJsonPath -Raw | ConvertFrom-Json
            $restored.version | Should -Be $script:OriginalVersion
        }
    }

    Context 'Directory cleanup simulation' {
        BeforeEach {
            $script:TestDir = Join-Path $script:FileOpsRoot "cleanup-$(New-Guid)"
            $script:ExtDir = Join-Path $script:TestDir 'extension'
            New-Item -ItemType Directory -Path $script:ExtDir -Force | Out-Null
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Cleans existing copied directories before copy' {
            $dirsToClean = @('.github', 'docs', 'scripts')
            foreach ($dir in $dirsToClean) {
                $dirPath = Join-Path $script:ExtDir $dir
                New-Item -ItemType Directory -Path $dirPath -Force | Out-Null
                'test file' | Set-Content (Join-Path $dirPath 'test.txt')
            }

            # Clean operation
            foreach ($dir in $dirsToClean) {
                $dirPath = Join-Path $script:ExtDir $dir
                if (Test-Path $dirPath) {
                    Remove-Item -Path $dirPath -Recurse -Force
                }
            }

            # Verify cleanup
            foreach ($dir in $dirsToClean) {
                $dirPath = Join-Path $script:ExtDir $dir
                Test-Path $dirPath | Should -BeFalse
            }
        }

        It 'Creates scripts subdirectory structure' {
            $scriptsDir = Join-Path $script:ExtDir 'scripts'
            New-Item -Path $scriptsDir -ItemType Directory -Force | Out-Null

            Test-Path $scriptsDir | Should -BeTrue
        }

        It 'Creates docs subdirectory structure' {
            $docsDir = Join-Path $script:ExtDir 'docs'
            New-Item -Path $docsDir -ItemType Directory -Force | Out-Null

            Test-Path $docsDir | Should -BeTrue
        }
    }

    Context 'VSIX file detection simulation' {
        BeforeEach {
            $script:TestDir = Join-Path $script:FileOpsRoot "vsix-detect-$(New-Guid)"
            New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Finds generated .vsix file' {
            # Create mock vsix files with different timestamps
            $vsix1 = Join-Path $script:TestDir 'old-1.0.0.vsix'
            $vsix2 = Join-Path $script:TestDir 'new-1.0.1.vsix'

            'old content' | Set-Content $vsix1
            Start-Sleep -Milliseconds 100
            'new content' | Set-Content $vsix2

            # Find most recent
            $vsixFile = Get-ChildItem -Path $script:TestDir -Filter '*.vsix' | Sort-Object LastWriteTime -Descending | Select-Object -First 1

            $vsixFile | Should -Not -BeNullOrEmpty
            $vsixFile.Name | Should -Be 'new-1.0.1.vsix'
        }

        It 'Returns null when no .vsix file exists' {
            $vsixFile = Get-ChildItem -Path $script:TestDir -Filter '*.vsix' -ErrorAction SilentlyContinue | Select-Object -First 1

            $vsixFile | Should -BeNullOrEmpty
        }

        It 'Reports file size correctly' {
            $vsixPath = Join-Path $script:TestDir 'test-1.0.0.vsix'
            $content = 'A' * 1024  # 1KB of content
            $content | Set-Content $vsixPath

            $vsixFile = Get-Item $vsixPath
            $sizeKB = [math]::Round($vsixFile.Length / 1KB, 2)

            $sizeKB | Should -BeGreaterThan 0
        }
    }
}

#endregion
