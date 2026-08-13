#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../extension/Package-Extension.ps1')
    Import-Module (Join-Path $PSScriptRoot 'ExtensionTestFixtures.psm1') -Force
    $script:PackageScriptPath = (Resolve-Path (Join-Path $PSScriptRoot '../../extension/Package-Extension.ps1')).Path

    function Get-OrdinalSorted {
        <#
        .SYNOPSIS
        Returns strings sorted with ordinal comparison.
        .PARAMETER Value
        Strings to sort.
        .OUTPUTS
        [string[]] Ordinal-sorted strings.
        #>
        [CmdletBinding()]
        [OutputType([string[]])]
        param(
            [Parameter(Mandatory = $true)]
            [AllowEmptyCollection()]
            [string[]]$Value
        )

        $sorted = [string[]]@($Value)
        [array]::Sort($sorted, [System.StringComparer]::Ordinal)
        return $sorted
    }

    Mock Write-Host {}
    Mock Set-CIOutput {}
}

Describe 'Copy-PreparedArtifacts staging' -Tag 'Unit' {
    BeforeAll {
        $script:StagingFixture = New-PackagingFixtureRepo -Path (Join-Path $TestDrive 'staging-repo')
        $script:Copied = @(Copy-PreparedArtifacts -RepoRoot $script:StagingFixture.RepoRoot -ExtensionDirectory $script:StagingFixture.ExtensionDirectory)
        $script:ExpectedStaged = @(
            '.github/agents/core/alpha.agent.md'
            '.github/instructions/core/style.instructions.md'
            '.github/prompts/core/build.prompt.md'
            '.github/skills/core/toolkit/SKILL.md'
            '.github/skills/core/toolkit/scripts/run.py'
            'docs/templates/example-template.md'
            'scripts/lib/Modules/CIHelpers.psm1'
        )
    }

    It 'Stages exactly the distributable git-tracked intersection' {
        Get-OrdinalSorted -Value $script:Copied | Should -Be (Get-OrdinalSorted -Value $script:ExpectedStaged)
    }

    It 'Writes every staged file into the extension directory' {
        foreach ($relative in $script:ExpectedStaged) {
            $staged = Join-Path $script:StagingFixture.ExtensionDirectory $relative
            Test-Path -LiteralPath $staged -PathType Leaf | Should -BeTrue -Because "$relative must be staged"
            Get-Content -LiteralPath $staged -Raw | Should -BeExactly (Get-Content -LiteralPath (Join-Path $script:StagingFixture.RepoRoot $relative) -Raw)
        }
    }

    It 'Stages the hardcoded shared resources' {
        $script:Copied | Should -Contain 'scripts/lib/Modules/CIHelpers.psm1'
        $script:Copied | Should -Contain 'docs/templates/example-template.md'
    }

    It 'Excludes every planted non-distributable sentinel' {
        foreach ($sentinel in $script:StagingFixture.ExcludedSentinels) {
            $script:Copied | Should -Not -Contain $sentinel
            Test-Path -LiteralPath (Join-Path $script:StagingFixture.ExtensionDirectory $sentinel) | Should -BeFalse -Because "$sentinel must never ship"
        }
    }

    It 'Plants a non-empty sentinel set so the exclusion is observable' {
        @($script:StagingFixture.ExcludedSentinels).Count | Should -BeGreaterThan 0
        foreach ($sentinel in $script:StagingFixture.ExcludedSentinels) {
            Test-Path -LiteralPath (Join-Path $script:StagingFixture.RepoRoot $sentinel) -PathType Leaf | Should -BeTrue
        }
    }

    It 'Excludes untracked files under a staged contribution root' {
        $script:Copied | Should -Not -Contain $script:StagingFixture.UntrackedSource
        Test-Path -LiteralPath (Join-Path $script:StagingFixture.RepoRoot $script:StagingFixture.UntrackedSource) -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $script:StagingFixture.ExtensionDirectory $script:StagingFixture.UntrackedSource) | Should -BeFalse
    }

    It 'Stages no hook sources' {
        @($script:Copied | Where-Object { $_ -like '.github/hooks/*' }) | Should -HaveCount 0
    }
}

Describe 'Get-TrackedFilesForSource failures' -Tag 'Unit' {
    BeforeEach {
        $script:FailureFixture = New-PackagingFixtureRepo -Path (Join-Path $TestDrive "tracked-$([guid]::NewGuid().ToString('N'))")
    }

    It 'Throws when a prepared source has no distributable tracked files' {
        { Get-TrackedFilesForSource -RepoRoot $script:FailureFixture.RepoRoot -SourcePath '.github/agents/absent' } |
            Should -Throw "Prepared source '.github/agents/absent' has no distributable tracked files."
    }

    It 'Throws when a source only contains excluded paths' {
        { Get-TrackedFilesForSource -RepoRoot $script:FailureFixture.RepoRoot -SourcePath '.github/skills/core/toolkit/tests' } |
            Should -Throw "Prepared source '.github/skills/core/toolkit/tests' has no distributable tracked files."
    }

    It 'Normalizes leading and trailing path decorations' {
        @(Get-TrackedFilesForSource -RepoRoot $script:FailureFixture.RepoRoot -SourcePath './docs/templates/') |
            Should -Be @('docs/templates/example-template.md')
    }

    It 'Rejects an escaping prepared contribution before staging' {
        $manifestPath = Join-Path $script:FailureFixture.ExtensionDirectory 'package.json'
        $original = Get-Content -LiteralPath $manifestPath -Raw
        $manifest = $original | ConvertFrom-Json
        $manifest.contributes.chatAgents[0].path = './.github/../package.json'
        $manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $manifestPath -Encoding utf8NoBOM
        $malformed = Get-Content -LiteralPath $manifestPath -Raw

        { Copy-PreparedArtifacts -RepoRoot $script:FailureFixture.RepoRoot -ExtensionDirectory $script:FailureFixture.ExtensionDirectory } |
            Should -Throw "Prepared chatAgents contribution '.github/../package.json' is not a contained artifact path."

        Get-Content -LiteralPath $manifestPath -Raw | Should -BeExactly $malformed
    }

    It 'Rejects a pathspec glob before staging' {
        $manifestPath = Join-Path $script:FailureFixture.ExtensionDirectory 'package.json'
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        $manifest.contributes.chatAgents[0].path = './.github/agents/core/*.agent.md'
        $manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $manifestPath -Encoding utf8NoBOM

        { Copy-PreparedArtifacts -RepoRoot $script:FailureFixture.RepoRoot -ExtensionDirectory $script:FailureFixture.ExtensionDirectory } |
            Should -Throw "Prepared chatAgents contribution '.github/agents/core/*.agent.md' is not a contained artifact path."
    }

    It 'Throws when a tracked file is missing from disk' {
        Remove-Item -LiteralPath (Join-Path $script:FailureFixture.RepoRoot 'docs/templates/example-template.md') -Force
        { Copy-PreparedArtifacts -RepoRoot $script:FailureFixture.RepoRoot -ExtensionDirectory $script:FailureFixture.ExtensionDirectory } |
            Should -Throw 'Tracked prepared file is missing: docs/templates/example-template.md'
    }
}

Describe 'Get-PinnedVsceCommand' -Tag 'Unit' {
    BeforeEach {
        $script:VsceFixture = New-PackagingFixtureRepo -Path (Join-Path $TestDrive "vsce-$([guid]::NewGuid().ToString('N'))")
        $script:SavedPath = $env:PATH
        $script:EmptyPathDirectory = (New-Item -Path (Join-Path $TestDrive "empty-path-$([guid]::NewGuid().ToString('N'))") -ItemType Directory -Force).FullName
    }

    AfterEach {
        $env:PATH = $script:SavedPath
    }

    It 'Prefers the repository-local vsce binary' {
        $local = New-FakeVsceExecutable -Path (Join-Path $script:VsceFixture.RepoRoot 'node_modules/.bin/vsce') -Version '3.9.2'
        $env:PATH = $script:EmptyPathDirectory
        $result = Get-PinnedVsceCommand -RepoRoot $script:VsceFixture.RepoRoot
        $result.IsAvailable | Should -BeTrue
        $result.Command | Should -BeExactly (Join-Path $script:VsceFixture.RepoRoot 'node_modules/.bin/vsce')
        $result.ExpectedVersion | Should -BeExactly '3.9.2'
        $result.ActualVersion | Should -BeExactly '3.9.2'
        Test-Path -LiteralPath $local -PathType Leaf | Should -BeTrue
    }

    It 'Falls back to a vsce binary on PATH' {
        $pathDirectory = (New-Item -Path (Join-Path $TestDrive "path-vsce-$([guid]::NewGuid().ToString('N'))") -ItemType Directory -Force).FullName
        New-FakeVsceExecutable -Path (Join-Path $pathDirectory 'vsce') -Version '3.9.2' | Out-Null
        $env:PATH = "$pathDirectory$([System.IO.Path]::PathSeparator)$script:EmptyPathDirectory"
        $result = Get-PinnedVsceCommand -RepoRoot $script:VsceFixture.RepoRoot
        $result.IsAvailable | Should -BeTrue
        $result.Command | Should -BeExactly (Join-Path $pathDirectory 'vsce')
    }

    It 'Rejects a vsce binary whose version differs from the repository pin' {
        New-FakeVsceExecutable -Path (Join-Path $script:VsceFixture.RepoRoot 'node_modules/.bin/vsce') -Version '1.0.0' | Out-Null
        $env:PATH = $script:EmptyPathDirectory
        $result = Get-PinnedVsceCommand -RepoRoot $script:VsceFixture.RepoRoot
        $result.IsAvailable | Should -BeFalse
        $result.ExpectedVersion | Should -BeExactly '3.9.2'
        $result.ActualVersion | Should -BeExactly '1.0.0'
    }

    It 'Reports no command when vsce is absent everywhere' {
        $env:PATH = $script:EmptyPathDirectory
        $result = Get-PinnedVsceCommand -RepoRoot $script:VsceFixture.RepoRoot
        $result.IsAvailable | Should -BeFalse
        $result.Command | Should -BeExactly ''
        $result.ActualVersion | Should -BeExactly ''
        $result.ExpectedVersion | Should -BeExactly '3.9.2'
    }

    It 'Reads the pin from the repository root manifest' {
        $customFixture = New-PackagingFixtureRepo -Path (Join-Path $TestDrive "vsce-pin-$([guid]::NewGuid().ToString('N'))") -VsceVersion '9.9.9'
        $env:PATH = $script:EmptyPathDirectory
        (Get-PinnedVsceCommand -RepoRoot $customFixture.RepoRoot).ExpectedVersion | Should -BeExactly '9.9.9'
    }

    It 'Never falls back to an npx invocation' {
        $source = Get-Content -LiteralPath $script:PackageScriptPath -Raw
        $source | Should -Not -Match 'npx'
    }
}

Describe 'Invoke-PackageExtension' -Tag 'Unit' {
    BeforeEach {
        $script:RunFixture = New-PackagingFixtureRepo -Path (Join-Path $TestDrive "run-$([guid]::NewGuid().ToString('N'))")
        $script:ManifestPath = Join-Path $script:RunFixture.ExtensionDirectory 'package.json'
    }

    Context 'when running with DryRun' {
        BeforeEach {
            $script:DryRunResult = Invoke-PackageExtension -ExtensionDirectory $script:RunFixture.ExtensionDirectory `
                -RepoRoot $script:RunFixture.RepoRoot -DryRun
        }

        It 'Reports success with the resolved version and no output path' {
            $script:DryRunResult.Success | Should -BeTrue
            $script:DryRunResult.Version | Should -BeExactly '1.2.3'
            $script:DryRunResult.OutputPath | Should -BeExactly ''
        }

        It 'Creates no VSIX' {
            @(Get-ChildItem -LiteralPath $script:RunFixture.ExtensionDirectory -Filter '*.vsix' -File) | Should -HaveCount 0
        }

        It 'Removes every staged resource directory' {
            foreach ($directory in @('.github', 'docs', 'scripts')) {
                Test-Path -LiteralPath (Join-Path $script:RunFixture.ExtensionDirectory $directory) | Should -BeFalse -Because "$directory must be cleaned up"
            }
        }

        It 'Leaves the canonical README untouched and creates no backup' {
            Get-Content -LiteralPath (Join-Path $script:RunFixture.ExtensionDirectory 'README.md') -Raw | Should -BeExactly "# Canonical README`n"
            Test-Path -LiteralPath (Join-Path $script:RunFixture.ExtensionDirectory 'README.md.bak') | Should -BeFalse
        }
    }

    Context 'when the pinned vsce is unavailable' {
        BeforeEach {
            New-FakeVsceExecutable -Path (Join-Path $script:RunFixture.RepoRoot 'node_modules/.bin/vsce') -Version '1.0.0' | Out-Null
            $script:MismatchResult = Invoke-PackageExtension -ExtensionDirectory $script:RunFixture.ExtensionDirectory `
                -RepoRoot $script:RunFixture.RepoRoot
        }

        It 'Fails with the pinned version message' {
            $script:MismatchResult.Success | Should -BeFalse
            $script:MismatchResult.ErrorMessage | Should -BeExactly "Pinned vsce 3.9.2 is unavailable (found '1.0.0')."
        }

        It 'Still cleans up staged directories and leaves the canonical README' {
            foreach ($directory in @('.github', 'docs', 'scripts')) {
                Test-Path -LiteralPath (Join-Path $script:RunFixture.ExtensionDirectory $directory) | Should -BeFalse
            }
            Get-Content -LiteralPath (Join-Path $script:RunFixture.ExtensionDirectory 'README.md') -Raw | Should -BeExactly "# Canonical README`n"
        }
    }

    Context 'when vsce exits non-zero' {
        BeforeEach {
            New-FakeVsceExecutable -Path (Join-Path $script:RunFixture.RepoRoot 'node_modules/.bin/vsce') -Version '3.9.2' -ExitCode 3 | Out-Null
            $script:FailureResult = Invoke-PackageExtension -ExtensionDirectory $script:RunFixture.ExtensionDirectory `
                -RepoRoot $script:RunFixture.RepoRoot
        }

        It 'Fails with the vsce exit code message' {
            $script:FailureResult.Success | Should -BeFalse
            $script:FailureResult.ErrorMessage | Should -BeExactly 'vsce failed with exit code 3'
        }

        It 'Staged the contribution sources before invoking vsce' {
            $observed = Get-Content -LiteralPath (Join-Path $script:RunFixture.ExtensionDirectory 'vsce-observed-package.json') -Raw | ConvertFrom-Json
            $observed.name | Should -BeExactly 'hve-sample'
        }

        It 'Removes staged directories and leaves the canonical README after failure' {
            foreach ($directory in @('.github', 'docs', 'scripts')) {
                Test-Path -LiteralPath (Join-Path $script:RunFixture.ExtensionDirectory $directory) | Should -BeFalse
            }
            Get-Content -LiteralPath (Join-Path $script:RunFixture.ExtensionDirectory 'README.md') -Raw | Should -BeExactly "# Canonical README`n"
            Test-Path -LiteralPath (Join-Path $script:RunFixture.ExtensionDirectory 'README.md.bak') | Should -BeFalse
        }
    }

    Context 'when a tracked prepared file is missing from disk' {
        BeforeEach {
            Remove-Item -LiteralPath (Join-Path $script:RunFixture.RepoRoot 'docs/templates/example-template.md') -Force
            $script:ThrowResult = Invoke-PackageExtension -ExtensionDirectory $script:RunFixture.ExtensionDirectory `
                -RepoRoot $script:RunFixture.RepoRoot
        }

        It 'Converts the thrown staging error into a failed result' {
            $script:ThrowResult.Success | Should -BeFalse
            $script:ThrowResult.ErrorMessage | Should -BeExactly 'Tracked prepared file is missing: docs/templates/example-template.md'
        }

        It 'Removes staged directories after the throw' {
            foreach ($directory in @('.github', 'docs', 'scripts')) {
                Test-Path -LiteralPath (Join-Path $script:RunFixture.ExtensionDirectory $directory) | Should -BeFalse
            }
        }
    }

    Context 'when packaging succeeds' {
        BeforeEach {
            New-FakeVsceExecutable -Path (Join-Path $script:RunFixture.RepoRoot 'node_modules/.bin/vsce') `
                -Version '3.9.2' -VsixName 'hve-sample-2.0.0-dev.7.vsix' | Out-Null
            $script:SuccessResult = Invoke-PackageExtension -ExtensionDirectory $script:RunFixture.ExtensionDirectory `
                -RepoRoot $script:RunFixture.RepoRoot -Version '2.0.0' -DevPatchNumber '7' -PreRelease
        }

        It 'Reports the development version and the produced VSIX' {
            $script:SuccessResult.Success | Should -BeTrue
            $script:SuccessResult.Version | Should -BeExactly '2.0.0-dev.7'
            (Split-Path -Leaf $script:SuccessResult.OutputPath) | Should -BeExactly 'hve-sample-2.0.0-dev.7.vsix'
        }

        It 'Passes deterministic pre-release arguments to vsce' {
            @(Get-Content -LiteralPath (Join-Path $script:RunFixture.ExtensionDirectory 'vsce-args.txt')) |
                Should -Be @('package', '--no-dependencies', '--pre-release')
        }

        It 'Applies the development version to the manifest vsce reads' {
            $observed = Get-Content -LiteralPath (Join-Path $script:RunFixture.ExtensionDirectory 'vsce-observed-package.json') -Raw | ConvertFrom-Json
            $observed.version | Should -BeExactly '2.0.0-dev.7'
        }

        It 'Packages the canonical README without swapping a package README' {
            Get-Content -LiteralPath (Join-Path $script:RunFixture.ExtensionDirectory 'vsce-observed-readme.md') -Raw |
                Should -BeExactly "# Canonical README`n"
            Get-Content -LiteralPath (Join-Path $script:RunFixture.ExtensionDirectory 'README.md') -Raw |
                Should -BeExactly "# Canonical README`n"
            Test-Path -LiteralPath (Join-Path $script:RunFixture.ExtensionDirectory 'README.md.bak') | Should -BeFalse
        }

        It 'Ignores a suffixed package README left in the extension directory' {
            Test-Path -LiteralPath (Join-Path $script:RunFixture.ExtensionDirectory 'README.sample.md') -PathType Leaf | Should -BeTrue
            Get-Content -LiteralPath (Join-Path $script:RunFixture.ExtensionDirectory 'vsce-observed-readme.md') -Raw |
                Should -Not -Match 'Sample package README'
        }

        It 'Restores the original manifest version after packaging' {
            $manifest = Get-Content -LiteralPath $script:ManifestPath -Raw | ConvertFrom-Json
            $manifest.version | Should -BeExactly '1.2.3'
        }

        It 'Publishes CI outputs without publishing the extension' {
            Should -Invoke Set-CIOutput -Times 3 -Exactly
            Should -Invoke Set-CIOutput -Times 1 -Exactly -ParameterFilter { $Name -eq 'vsix-file' -and $Value -eq 'hve-sample-2.0.0-dev.7.vsix' }
            Should -Invoke Set-CIOutput -Times 1 -Exactly -ParameterFilter { $Name -eq 'version' -and $Value -eq '2.0.0-dev.7' }
            Should -Invoke Set-CIOutput -Times 1 -Exactly -ParameterFilter { $Name -eq 'pre-release' -and $Value -eq 'True' }
        }

        It 'Removes staged directories while keeping the VSIX' {
            foreach ($directory in @('.github', 'docs', 'scripts')) {
                Test-Path -LiteralPath (Join-Path $script:RunFixture.ExtensionDirectory $directory) | Should -BeFalse
            }
            Test-Path -LiteralPath $script:SuccessResult.OutputPath -PathType Leaf | Should -BeTrue
        }
    }
}

AfterAll {
    Remove-Module ExtensionTestFixtures -Force -ErrorAction SilentlyContinue
}
