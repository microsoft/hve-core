#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../release/Resolve-ReleasePromotionVersion.ps1'
    . $script:ScriptPath -Channel PreRelease -CurrentPreReleaseVersion '3.3.101'
}

Describe 'Resolve-ReleasePromotionVersion' -Tag 'Unit' {
    Context 'PreRelease promotion' {
        It 'Advances <Current> to the next odd minor <Expected>' -ForEach @(
            @{ Current = '3.3.101'; Expected = '3.5.0' }
            @{ Current = '3.5.0'; Expected = '3.7.0' }
            @{ Current = '3.99.4'; Expected = '3.101.0' }
            @{ Current = '12.7.0'; Expected = '12.9.0' }
        ) {
            $result = Resolve-ReleasePromotionVersion `
                -Channel PreRelease `
                -CurrentPreReleaseVersion ([version]$Current)

            $result.Version | Should -BeExactly $Expected
        }

        It 'Reports only the PreRelease baseline it consumed' {
            $result = Resolve-ReleasePromotionVersion `
                -Channel PreRelease `
                -CurrentPreReleaseVersion ([version]'3.3.101')

            $result.Channel | Should -BeExactly 'PreRelease'
            $result.CurrentPreReleaseVersion | Should -BeExactly '3.3.101'
            $result.PromotedSourceVersion | Should -BeNullOrEmpty
            $result.CurrentStableVersion | Should -BeNullOrEmpty
        }

        It 'Rejects an even-minor PreRelease baseline' {
            {
                Resolve-ReleasePromotionVersion `
                    -Channel PreRelease `
                    -CurrentPreReleaseVersion ([version]'3.4.0')
            } | Should -Throw '*PreRelease baseline must have an odd minor*'
        }

        It 'Rejects a missing PreRelease baseline before parity' {
            {
                Resolve-ReleasePromotionVersion -Channel PreRelease
            } | Should -Throw '*CurrentPreReleaseVersion is required for PreRelease resolution*'
        }
    }

    Context 'Stable promotion' {
        It 'Promotes <Promoted> over Stable <Baseline> to <Expected>' -ForEach @(
            @{ Promoted = '3.5.0'; Baseline = '3.2.2'; Expected = '3.6.0' }
            @{ Promoted = '3.5.77'; Baseline = '3.4.0'; Expected = '3.6.0' }
            @{ Promoted = '4.1.0'; Baseline = '3.2.2'; Expected = '4.2.0' }
            @{ Promoted = '4.99.1'; Baseline = '4.98.0'; Expected = '4.100.0' }
        ) {
            $result = Resolve-ReleasePromotionVersion `
                -Channel Stable `
                -PromotedSourceVersion ([version]$Promoted) `
                -CurrentStableVersion ([version]$Baseline)

            $result.Version | Should -BeExactly $Expected
        }

        It 'Reports only the Stable inputs it consumed' {
            $result = Resolve-ReleasePromotionVersion `
                -Channel Stable `
                -PromotedSourceVersion ([version]'3.5.0') `
                -CurrentStableVersion ([version]'3.2.2')

            $result.Channel | Should -BeExactly 'Stable'
            $result.PromotedSourceVersion | Should -BeExactly '3.5.0'
            $result.CurrentStableVersion | Should -BeExactly '3.2.2'
            $result.CurrentPreReleaseVersion | Should -BeNullOrEmpty
        }

        It 'Rejects an even-minor promotion source' {
            {
                Resolve-ReleasePromotionVersion `
                    -Channel Stable `
                    -PromotedSourceVersion ([version]'3.4.0') `
                    -CurrentStableVersion ([version]'3.2.2')
            } | Should -Throw '*Stable promotion source must have an odd minor*'
        }

        It 'Rejects an odd-minor Stable baseline' {
            {
                Resolve-ReleasePromotionVersion `
                    -Channel Stable `
                    -PromotedSourceVersion ([version]'3.5.0') `
                    -CurrentStableVersion ([version]'3.3.0')
            } | Should -Throw '*Stable baseline must have an even minor*'
        }

        It 'Rejects a candidate that does not advance Stable for <Promoted> over <Baseline>' -ForEach @(
            @{ Promoted = '3.1.9'; Baseline = '3.2.2' }
            @{ Promoted = '3.1.0'; Baseline = '3.2.0' }
        ) {
            {
                Resolve-ReleasePromotionVersion `
                    -Channel Stable `
                    -PromotedSourceVersion ([version]$Promoted) `
                    -CurrentStableVersion ([version]$Baseline)
            } | Should -Throw '*must be greater than the Stable baseline*'
        }

        It 'Rejects a missing promotion source before parity' {
            {
                Resolve-ReleasePromotionVersion `
                    -Channel Stable `
                    -CurrentStableVersion ([version]'3.2.2')
            } | Should -Throw '*PromotedSourceVersion is required for Stable resolution*'
        }

        It 'Rejects a missing Stable baseline before parity' {
            {
                Resolve-ReleasePromotionVersion `
                    -Channel Stable `
                    -PromotedSourceVersion ([version]'3.5.0')
            } | Should -Throw '*CurrentStableVersion is required for Stable resolution*'
        }
    }

    Context 'Current release sequence' {
        It 'Carries 3.3.101 through PreRelease 3.5.0 to Stable 3.6.0' {
            $preRelease = Resolve-ReleasePromotionVersion `
                -Channel PreRelease `
                -CurrentPreReleaseVersion ([version]'3.3.101')
            $preRelease.Version | Should -BeExactly '3.5.0'

            $stable = Resolve-ReleasePromotionVersion `
                -Channel Stable `
                -PromotedSourceVersion ([version]$preRelease.Version) `
                -CurrentStableVersion ([version]'3.2.2')
            $stable.Version | Should -BeExactly '3.6.0'
        }
    }

    Context 'Script entry point' {
        It 'Resolves PreRelease without a Stable baseline' {
            $result = & $script:ScriptPath `
                -Channel PreRelease `
                -CurrentPreReleaseVersion '3.3.101'

            $result.Version | Should -BeExactly '3.5.0'
            $result.CurrentStableVersion | Should -BeNullOrEmpty
            $result.PromotedSourceVersion | Should -BeNullOrEmpty
        }

        It 'Emits a uniform compressed JSON shape for <Channel>' -ForEach @(
            @{
                Channel   = 'PreRelease'
                Arguments = @{ CurrentPreReleaseVersion = '3.3.101' }
                Expected  = '3.5.0'
            }
            @{
                Channel   = 'Stable'
                Arguments = @{ PromotedSourceVersion = '3.5.0'; CurrentStableVersion = '3.2.2' }
                Expected  = '3.6.0'
            }
        ) {
            $json = & $script:ScriptPath -Channel $Channel @Arguments -AsJson
            $parsed = $json | ConvertFrom-Json

            $parsed.Version | Should -BeExactly $Expected
            $parsed.Channel | Should -BeExactly $Channel
            $parsed.PSObject.Properties.Name | Should -HaveCount 5
            $parsed.PSObject.Properties.Name | Should -Contain 'Version'
            $parsed.PSObject.Properties.Name | Should -Contain 'Channel'
            $parsed.PSObject.Properties.Name | Should -Contain 'CurrentPreReleaseVersion'
            $parsed.PSObject.Properties.Name | Should -Contain 'PromotedSourceVersion'
            $parsed.PSObject.Properties.Name | Should -Contain 'CurrentStableVersion'
            $parsed.PSObject.Properties.Name | Should -Not -Contain 'ReleaseClass'
        }

        It 'Rejects a ReleaseClass argument during parameter binding' {
            {
                & $script:ScriptPath `
                    -Channel PreRelease `
                    -CurrentPreReleaseVersion '3.3.101' `
                    -ReleaseClass minor
            } | Should -Throw '*ReleaseClass*'
        }
    }
}
