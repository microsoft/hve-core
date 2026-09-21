#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../extension/Package-Extension.ps1')
    Import-Module (Join-Path $PSScriptRoot 'ExtensionTestFixtures.psm1') -Force
    $script:PackageScriptPath = (Resolve-Path (Join-Path $PSScriptRoot '../../extension/Package-Extension.ps1')).Path
    Mock Write-Host {}
}

Describe 'Package-Extension package identity' -Tag 'Unit' {
    It 'Declares no package identity parameter' {
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:PackageScriptPath, [ref]$null, [ref]$parseErrors)
        $parseErrors | Should -BeNullOrEmpty
        @($ast.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath }) |
            Should -Be @('Version', 'DevPatchNumber', 'ChangelogPath', 'PreRelease', 'DryRun')
    }

    It 'Reads no marketplace catalog and swaps no package README' {
        $source = Get-Content -LiteralPath $script:PackageScriptPath -Raw
        $source | Should -Not -Match '(?i)marketplace'
        $source | Should -Not -Match '(?i)PackageId'
        $source | Should -Not -Match 'README\.md\.bak'
    }
}

Describe 'Test-ExtensionManifestValid' -Tag 'Unit' {
    Context 'when the manifest declares every required field' {
        It 'Reports the manifest as valid' {
            $manifest = [pscustomobject]@{
                name      = 'hve-sample'
                version   = '1.2.3'
                publisher = 'fixture-publisher'
                engines   = [pscustomobject]@{ vscode = '^1.106.1' }
            }
            $result = Test-ExtensionManifestValid -ManifestContent $manifest
            $result.IsValid | Should -BeTrue
            @($result.Errors) | Should -HaveCount 0
        }
    }

    Context 'when required fields are missing' {
        It 'Reports one error per missing field' {
            $result = Test-ExtensionManifestValid -ManifestContent ([pscustomobject]@{})
            $result.IsValid | Should -BeFalse
            @($result.Errors) | Should -Be @(
                "Missing required 'name' field"
                "Missing required 'version' field"
                "Missing required 'publisher' field"
                "Missing required 'engines' field"
            )
        }

        It 'Reports the missing engines.vscode field' {
            $manifest = [pscustomobject]@{
                name      = 'hve-sample'
                version   = '1.2.3'
                publisher = 'fixture-publisher'
                engines   = [pscustomobject]@{ node = '24' }
            }
            $result = Test-ExtensionManifestValid -ManifestContent $manifest
            $result.IsValid | Should -BeFalse
            @($result.Errors) | Should -Be @("Missing required 'engines.vscode' field")
        }
    }

    Context 'when the version is malformed' {
        It 'Reports the invalid version format' {
            $manifest = [pscustomobject]@{
                name      = 'hve-sample'
                version   = '1.2'
                publisher = 'fixture-publisher'
                engines   = [pscustomobject]@{ vscode = '^1.106.1' }
            }
            $result = Test-ExtensionManifestValid -ManifestContent $manifest
            $result.IsValid | Should -BeFalse
            @($result.Errors) | Should -Be @("Invalid version format: '1.2'")
        }
    }
}

Describe 'Get-ResolvedPackageVersion' -Tag 'Unit' {
    It 'Uses the manifest version when no override is supplied' {
        $result = Get-ResolvedPackageVersion -ManifestVersion '1.2.3'
        $result.IsValid | Should -BeTrue
        $result.BaseVersion | Should -BeExactly '1.2.3'
        $result.PackageVersion | Should -BeExactly '1.2.3'
        $result.ErrorMessage | Should -BeExactly ''
    }

    It 'Prefers the specified version over the manifest version' {
        $result = Get-ResolvedPackageVersion -SpecifiedVersion '4.5.6' -ManifestVersion '1.2.3'
        $result.PackageVersion | Should -BeExactly '4.5.6'
    }

    It 'Appends the development patch suffix' {
        $result = Get-ResolvedPackageVersion -SpecifiedVersion '4.5.6' -ManifestVersion '1.2.3' -DevPatchNumber '42'
        $result.BaseVersion | Should -BeExactly '4.5.6'
        $result.PackageVersion | Should -BeExactly '4.5.6-dev.42'
    }

    It 'Truncates trailing prerelease metadata to the numeric core' {
        $result = Get-ResolvedPackageVersion -SpecifiedVersion '4.5.6-rc.1' -ManifestVersion '1.2.3'
        $result.PackageVersion | Should -BeExactly '4.5.6'
    }

    It 'Rejects a malformed version with an exact message' {
        $result = Get-ResolvedPackageVersion -SpecifiedVersion 'not-a-version' -ManifestVersion '1.2.3'
        $result.IsValid | Should -BeFalse
        $result.PackageVersion | Should -BeExactly ''
        $result.ErrorMessage | Should -BeExactly "Invalid version format: 'not-a-version'"
    }
}

Describe 'Get-VscePackageArguments' -Tag 'Unit' {
    It 'Packages without dependency resolution by default' {
        @(Get-VscePackageArguments) | Should -Be @('package', '--no-dependencies')
    }

    It 'Adds the pre-release flag for the pre-release channel' {
        @(Get-VscePackageArguments -PreRelease) | Should -Be @('package', '--no-dependencies', '--pre-release')
    }
}

Describe 'Test-DistributionPath' -Tag 'Unit' {
    It 'Allows distributable path <Path>' -ForEach @(
        @{ Path = '.github/agents/core/alpha.agent.md' }
        @{ Path = '.github/skills/core/toolkit/SKILL.md' }
        @{ Path = '.github/skills/core/toolkit/scripts/run.py' }
        @{ Path = 'docs/templates/example-template.md' }
        @{ Path = '.github/skills/core/latest-tests-guide.md' }
    ) {
        Test-DistributionPath -Path $Path | Should -BeTrue
    }

    It 'Excludes non-distributable path <Path>' -ForEach @(
        @{ Path = 'tests/test_root.py' }
        @{ Path = '.github/skills/core/toolkit/tests/test_toolkit.py' }
        @{ Path = '.github/skills/core/toolkit/scripts/tests/test_deep.py' }
        @{ Path = '.github/skills/core/toolkit/.venv/lib/site.py' }
        @{ Path = '.github/skills/core/toolkit/node_modules/left-pad/index.js' }
        @{ Path = '.github/skills/core/toolkit/__pycache__/toolkit.pyc' }
        @{ Path = '.github/skills/core/toolkit/.ruff_cache/cache.json' }
        @{ Path = '.github/skills/core/toolkit/.pytest_cache/cache.json' }
    ) {
        Test-DistributionPath -Path $Path | Should -BeFalse
    }
}

Describe 'Get-PreparedSourceRoots' -Tag 'Unit' {
    It 'Maps contribution paths to repository-relative roots' {
        $manifest = [pscustomobject]@{
            contributes = [pscustomobject]@{
                chatAgents       = @([pscustomobject]@{ path = './.github/agents/core/alpha.agent.md' })
                chatPromptFiles  = @([pscustomobject]@{ path = './.github/prompts/core/build.prompt.md' })
                chatInstructions = @([pscustomobject]@{ path = './.github/instructions/core/style.instructions.md' })
                chatSkills       = @([pscustomobject]@{ path = './.github/skills/core/toolkit/SKILL.md' })
            }
        }
        @(Get-PreparedSourceRoots -PackageJson $manifest) | Should -Be @(
            '.github/agents/core/alpha.agent.md'
            '.github/instructions/core/style.instructions.md'
            '.github/prompts/core/build.prompt.md'
            '.github/skills/core/toolkit'
        )
    }

    It 'Deduplicates repeated contribution paths' {
        $manifest = [pscustomobject]@{
            contributes = [pscustomobject]@{
                chatAgents = @(
                    [pscustomobject]@{ path = './.github/agents/core/alpha.agent.md' }
                    [pscustomobject]@{ path = './.github/agents/core/alpha.agent.md' }
                )
                chatSkills = @(
                    [pscustomobject]@{ path = './.github/skills/core/toolkit/SKILL.md' }
                    [pscustomobject]@{ path = './.github/skills/core/toolkit/SKILL.md' }
                )
            }
        }
        @(Get-PreparedSourceRoots -PackageJson $manifest) | Should -Be @(
            '.github/agents/core/alpha.agent.md'
            '.github/skills/core/toolkit'
        )
    }

    It 'Derives no roots from a manifest without contributions' {
        $manifest = [pscustomobject]@{ contributes = [pscustomobject]@{} }
        @(Get-PreparedSourceRoots -PackageJson $manifest) | Should -HaveCount 0
    }

    It 'Derives no hook roots because hooks are plugin-only' {
        $manifest = [pscustomobject]@{
            contributes = [pscustomobject]@{
                chatAgents = @([pscustomobject]@{ path = './.github/agents/core/alpha.agent.md' })
                chatHooks  = @([pscustomobject]@{ path = './.github/hooks/core/session.json' })
            }
        }
        @(Get-PreparedSourceRoots -PackageJson $manifest) | Should -Be @('.github/agents/core/alpha.agent.md')
    }
}

Describe 'Test-PackagingInputsValid' -Tag 'Unit' {
    It 'Accepts a prepared extension directory inside a git worktree' {
        $fixture = New-PackagingFixtureRepo -Path (Join-Path $TestDrive 'inputs-valid')
        $result = Test-PackagingInputsValid -ExtensionDirectory $fixture.ExtensionDirectory -RepoRoot $fixture.RepoRoot
        $result.IsValid | Should -BeTrue
        @($result.Errors) | Should -HaveCount 0
        $result.PackageJsonPath | Should -BeExactly (Join-Path $fixture.ExtensionDirectory 'package.json')
    }

    It 'Reports a missing extension directory and manifest' {
        $repoRoot = (New-Item -Path (Join-Path $TestDrive 'inputs-missing') -ItemType Directory -Force).FullName
        New-Item -Path (Join-Path $repoRoot '.git') -ItemType Directory -Force | Out-Null
        $extensionDirectory = Join-Path $repoRoot 'extension'
        $result = Test-PackagingInputsValid -ExtensionDirectory $extensionDirectory -RepoRoot $repoRoot
        $result.IsValid | Should -BeFalse
        @($result.Errors) | Should -Be @(
            "Extension directory not found: $extensionDirectory"
            "package.json not found: $(Join-Path $extensionDirectory 'package.json')"
        )
    }
}

Describe 'New-PackagingResult' -Tag 'Unit' {
    It 'Defaults optional fields to empty strings' {
        $result = New-PackagingResult -Success $false
        $result.Success | Should -BeFalse
        $result.OutputPath | Should -BeExactly ''
        $result.Version | Should -BeExactly ''
        $result.ErrorMessage | Should -BeExactly ''
    }
}

AfterAll {
    Remove-Module ExtensionTestFixtures -Force -ErrorAction SilentlyContinue
}
