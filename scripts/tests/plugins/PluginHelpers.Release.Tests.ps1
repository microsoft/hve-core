#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../plugins/Modules/PluginHelpers.psm1') -Force
    Mock Write-Host {} -ModuleName PluginHelpers
}

Describe 'New-PluginReleaseLocator' -Tag 'Unit' {
    Context 'when a release version is supplied' {
        BeforeAll {
            $script:preReleaseLocator = New-PluginReleaseLocator -Version '1.2.3' -Channel PreRelease
            $script:stableLocator = New-PluginReleaseLocator -Version '1.2.3' -Channel Stable
        }

        It 'Derives the PreRelease release tag' {
            $script:preReleaseLocator.Ref | Should -BeExactly 'prerelease-v1.2.3'
        }

        It 'Derives the Stable release tag' {
            $script:stableLocator.Ref | Should -BeExactly 'v1.2.3'
        }

        It 'Derives the <Channel> tag for version <Version>' -ForEach @(
            @{ Channel = 'PreRelease'; Version = '1.2.3-beta.1'; ExpectedRef = 'prerelease-v1.2.3-beta.1' }
            @{ Channel = 'PreRelease'; Version = '10.0.0'; ExpectedRef = 'prerelease-v10.0.0' }
            @{ Channel = 'Stable'; Version = '1.2.3-beta.1'; ExpectedRef = 'v1.2.3-beta.1' }
            @{ Channel = 'Stable'; Version = '10.0.0'; ExpectedRef = 'v10.0.0' }
        ) {
            (New-PluginReleaseLocator -Version $Version -Channel $Channel).Ref | Should -BeExactly $ExpectedRef
        }

        It 'Defaults the source repository' {
            $script:preReleaseLocator.Repo | Should -BeExactly 'microsoft/hve-core'
            $script:stableLocator.Repo | Should -BeExactly 'microsoft/hve-core'
        }

        It 'Accepts an alternate repository' {
            (New-PluginReleaseLocator -Version '1.2.3' -Channel Stable -Repo 'contoso/contoso-hve').Repo |
                Should -BeExactly 'contoso/contoso-hve'
        }

        # The locator addresses the repository at its release tag, so it carries
        # no package path a consumer could resolve against a projected tree.
        It 'Returns a pathless locator carrying only Ref and Repo' {
            foreach ($locator in @($script:preReleaseLocator, $script:stableLocator)) {
                @($locator.Keys | Sort-Object) | Should -Be @('Ref', 'Repo')
            }
        }
    }

    Context 'when an explicit release tag is supplied' {
        It 'Accepts the exact <Channel> tag <Tag>' -ForEach @(
            @{ Channel = 'Stable'; Tag = 'v4.5.6' }
            @{ Channel = 'Stable'; Tag = 'v4.5.6-rc.1' }
            @{ Channel = 'PreRelease'; Tag = 'prerelease-v4.5.6' }
        ) {
            (New-PluginReleaseLocator -Tag $Tag -Channel $Channel).Ref | Should -BeExactly $Tag
        }

        It 'Accepts an alternate repository with an explicit tag' {
            $locator = New-PluginReleaseLocator -Tag 'prerelease-v1.0.0' -Channel PreRelease -Repo 'contoso/contoso-hve'
            $locator.Ref | Should -BeExactly 'prerelease-v1.0.0'
            $locator.Repo | Should -BeExactly 'contoso/contoso-hve'
        }

        It 'Refuses the cross-channel tag <Tag> for <Channel>' -ForEach @(
            @{ Channel = 'Stable'; Tag = 'prerelease-v1.2.3'; Prefix = 'v' }
            @{ Channel = 'PreRelease'; Tag = 'v1.2.3'; Prefix = 'prerelease-v' }
        ) {
            { New-PluginReleaseLocator -Tag $Tag -Channel $Channel } |
                Should -Throw -ExpectedMessage "*must use the immutable $Channel '$Prefix<version>' tag form*"
        }
    }

    Context 'when the locator is not immutable or is malformed' {
        It 'Refuses <Label>' -ForEach @(
            @{ Label = 'a lowercase commit sha'; Parameters = @{ Tag = '0123456789abcdef0123456789abcdef01234567'; Channel = 'Stable' }; Pattern = 'is a commit sha' }
            @{ Label = 'an uppercase commit sha'; Parameters = @{ Tag = '0123456789ABCDEF0123456789ABCDEF01234567'; Channel = 'PreRelease' }; Pattern = 'is a commit sha' }
            @{ Label = 'an abbreviated commit sha'; Parameters = @{ Tag = '0123456'; Channel = 'Stable' }; Pattern = "must use the immutable Stable 'v<version>' tag form" }
            @{ Label = 'the default branch'; Parameters = @{ Tag = 'main'; Channel = 'Stable' }; Pattern = "must use the immutable Stable 'v<version>' tag form" }
            @{ Label = 'a release branch'; Parameters = @{ Tag = 'release/prerelease'; Channel = 'PreRelease' }; Pattern = "must use the immutable PreRelease 'prerelease-v<version>' tag form" }
            @{ Label = 'a retired tag namespace'; Parameters = @{ Tag = 'legacy-v1.2.3'; Channel = 'Stable' }; Pattern = "must use the immutable Stable 'v<version>' tag form" }
            @{ Label = 'an unversioned tag'; Parameters = @{ Tag = 'v1.2'; Channel = 'Stable' }; Pattern = "must use the immutable Stable 'v<version>' tag form" }
            @{ Label = 'an empty tag'; Parameters = @{ Tag = ''; Channel = 'PreRelease' }; Pattern = "must use the immutable PreRelease 'prerelease-v<version>' tag form" }
            @{ Label = 'a non-semantic version'; Parameters = @{ Version = '1.2'; Channel = 'Stable' }; Pattern = 'is not a semantic version' }
            @{ Label = 'an empty version'; Parameters = @{ Version = ''; Channel = 'PreRelease' }; Pattern = 'is not a semantic version' }
            @{ Label = 'a repository without an owner'; Parameters = @{ Version = '1.2.3'; Channel = 'Stable'; Repo = 'contoso-hve' }; Pattern = "must use 'owner/name' form" }
            @{ Label = 'a repository with extra segments'; Parameters = @{ Version = '1.2.3'; Channel = 'Stable'; Repo = 'contoso/hve/extra' }; Pattern = "must use 'owner/name' form" }
        ) {
            { New-PluginReleaseLocator @Parameters } | Should -Throw -ExpectedMessage "*$Pattern*"
        }
    }
}

AfterAll {
    Remove-Module PluginHelpers -Force -ErrorAction SilentlyContinue
}
