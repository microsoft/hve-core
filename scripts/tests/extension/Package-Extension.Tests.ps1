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
