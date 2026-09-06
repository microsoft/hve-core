#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ScriptPath = (Resolve-Path (Join-Path $PSScriptRoot '../../release/Assert-ReleaseAssetSet.ps1')).Path
    . $script:ScriptPath `
        -AssetNamePath 'unused' `
        -RequiredAssetPath 'unused' `
        -Version '3.3.0' `
        -ReleaseTag 'prerelease-v3.3.0'

    $script:RequiredAsset = [string[]]@('dependencies.spdx.json')
    $script:ExpectedVsix = [string[]]@('hve-core-3.3.0.vsix')
    $script:SidecarSuffix = [string[]]@('.spdx.json', '.sigstore.json', '.intoto.jsonl')

    function New-AssetSet {
        <#
        .SYNOPSIS
        Builds a complete release asset name set with optional mutations.
        .PARAMETER Remove
        Asset names to drop from the complete set.
        .PARAMETER Add
        Asset names to append to the set.
        .OUTPUTS
        [string[]] Release asset names.
        #>
        [CmdletBinding()]
        [OutputType([string[]])]
        param(
            [Parameter(Mandatory = $false)]
            [string[]]$Remove = @(),

            [Parameter(Mandatory = $false)]
            [string[]]$Add = @()
        )

        $names = [System.Collections.Generic.List[string]]::new()
        foreach ($required in $script:RequiredAsset) { $names.Add($required) }
        foreach ($primary in $script:ExpectedVsix) {
            $names.Add($primary)
            foreach ($suffix in $script:SidecarSuffix) {
                $names.Add($primary + $suffix)
            }
        }
        return [string[]]@(@($names | Where-Object { $Remove -notcontains $_ }) + @($Add))
    }

    function Invoke-AssetSetTest {
        <#
        .SYNOPSIS
        Reconciles a mutated asset set against the shared expected identities.
        .PARAMETER AssetName
        Actual release asset names.
        .OUTPUTS
        [string[]] Findings.
        #>
        [CmdletBinding()]
        [OutputType([string[]])]
        param(
            [Parameter(Mandatory = $true)]
            [AllowEmptyCollection()]
            [string[]]$AssetName
        )

        return Test-ReleaseAssetSet -AssetName $AssetName `
            -ExpectedVsix $script:ExpectedVsix `
            -RequiredAsset $script:RequiredAsset
    }
}

Describe 'Assert-ReleaseAssetSet expected identities' -Tag 'Unit' {
    It 'Derives the one hve-core VSIX identity from the released version' {
        Get-ReleaseExpectedVsixName -Version '3.3.0' | Should -Be @('hve-core-3.3.0.vsix')
    }

    It 'Derives exactly one expected VSIX regardless of version' {
        @(Get-ReleaseExpectedVsixName -Version '4.0.0') | Should -Be @('hve-core-4.0.0.vsix')
    }

    # No catalog, evidence document, or channel policy participates, so nothing
    # a release publishes can widen or narrow its own expectation.
    It 'Takes no catalog, evidence, or channel parameter' {
        $command = Get-Command -Name Get-ReleaseExpectedVsixName
        [string[]]@($command.Parameters.Keys) | Should -Not -Contain 'CatalogPath'
        [string[]]@($command.Parameters.Keys) | Should -Not -Contain 'Evidence'
        [string[]]@($command.Parameters.Keys) | Should -Not -Contain 'Channel'
    }

    Context 'Repeated import' {
        # A Constant script variable cannot be replaced even with -Force, so a
        # second dot-source of the helper must stay possible.
        It 'Dot-sources again without failing on its script-scoped state' {
            {
                . $script:ScriptPath `
                    -AssetNamePath 'unused' `
                    -RequiredAssetPath 'unused' `
                    -Version '3.3.0' `
                    -ReleaseTag 'prerelease-v3.3.0'
            } | Should -Not -Throw
        }
    }
}

Describe 'Assert-ReleaseAssetSet reconciliation' -Tag 'Unit' {
    It 'Accepts a complete asset set' {
        Invoke-AssetSetTest -AssetName (New-AssetSet) | Should -BeNullOrEmpty
    }

    It 'Reports the missing VSIX asset' {
        $findings = Invoke-AssetSetTest -AssetName (New-AssetSet -Remove @('hve-core-3.3.0.vsix'))
        $findings | Should -Contain "missing VSIX asset 'hve-core-3.3.0.vsix'"
    }

    It 'Reports an unexpected VSIX asset' {
        $findings = Invoke-AssetSetTest -AssetName (New-AssetSet -Add @(
                'hve-security-3.3.0.vsix'
                'hve-security-3.3.0.vsix.spdx.json'
                'hve-security-3.3.0.vsix.sigstore.json'
                'hve-security-3.3.0.vsix.intoto.jsonl'
            ))
        $findings | Should -Contain "unexpected VSIX asset 'hve-security-3.3.0.vsix'"
    }

    It 'Reports a stale VSIX carrying the wrong release version' {
        # A leftover asset from an earlier attempt is an identity mismatch, not
        # an acceptable extra file.
        $findings = Invoke-AssetSetTest -AssetName (New-AssetSet -Add @('hve-core-3.1.0.vsix'))
        $findings | Should -Contain "unexpected VSIX asset 'hve-core-3.1.0.vsix'"
    }

    It 'Reports a duplicate asset name' {
        $findings = Invoke-AssetSetTest -AssetName (New-AssetSet -Add @('hve-core-3.3.0.vsix'))
        $findings | Should -Contain "duplicate asset 'hve-core-3.3.0.vsix' appears 2 times"
    }

    It 'Reports an incomplete <Sidecar> sidecar for the VSIX asset' -ForEach @(
        @{ Sidecar = '.spdx.json' }
        @{ Sidecar = '.sigstore.json' }
        @{ Sidecar = '.intoto.jsonl' }
    ) {
        $findings = Invoke-AssetSetTest -AssetName (New-AssetSet -Remove @("hve-core-3.3.0.vsix$Sidecar"))
        $findings | Should -Be @("missing sidecar 'hve-core-3.3.0.vsix$Sidecar' for VSIX asset 'hve-core-3.3.0.vsix'")
    }

    It 'Reports a missing required singleton asset' {
        $findings = Invoke-AssetSetTest -AssetName (New-AssetSet -Remove @('dependencies.spdx.json'))
        $findings | Should -Contain "missing required asset 'dependencies.spdx.json'"
    }

    It 'Reports a retired plugin ZIP as an unexpected asset' {
        $findings = Invoke-AssetSetTest -AssetName (New-AssetSet -Add @('hve-core-3.3.0.zip'))
        $findings | Should -Be @("unexpected asset 'hve-core-3.3.0.zip'")
    }

    It 'Reports an arbitrary extra asset' {
        $findings = Invoke-AssetSetTest -AssetName (New-AssetSet -Add @('release-debug.txt'))
        $findings | Should -Be @("unexpected asset 'release-debug.txt'")
    }

    It 'Allows a declared optional asset without requiring it' {
        Test-ReleaseAssetSet -AssetName (New-AssetSet -Add @('dependency-diff.md')) `
            -ExpectedVsix $script:ExpectedVsix `
            -RequiredAsset $script:RequiredAsset `
            -OptionalAsset @('dependency-diff.md') | Should -BeNullOrEmpty

        Test-ReleaseAssetSet -AssetName (New-AssetSet) `
            -ExpectedVsix $script:ExpectedVsix `
            -RequiredAsset $script:RequiredAsset `
            -OptionalAsset @('dependency-diff.md') | Should -BeNullOrEmpty
    }

    It 'Reports an unexpected VSIX with complete sidecars only once' {
        $findings = Invoke-AssetSetTest -AssetName (New-AssetSet -Add @(
                'hve-security-3.3.0.vsix'
                'hve-security-3.3.0.vsix.spdx.json'
                'hve-security-3.3.0.vsix.sigstore.json'
                'hve-security-3.3.0.vsix.intoto.jsonl'
            ))
        $findings | Should -Be @("unexpected VSIX asset 'hve-security-3.3.0.vsix'")
    }

    # The Stable channel adds its OpenVEX document to the required singleton
    # set, and a channel asset is required exactly as the caller supplies it.
    It 'Reports a missing channel singleton asset' {
        $findings = Test-ReleaseAssetSet -AssetName (New-AssetSet) `
            -ExpectedVsix $script:ExpectedVsix `
            -RequiredAsset ([string[]]@('dependencies.spdx.json', 'hve-core.openvex.json'))
        $findings | Should -Be @("missing required asset 'hve-core.openvex.json'")
    }

    # Release asset names are ordinal identities, so a case variant is a
    # different asset rather than the expected one.
    It 'Treats a mixed-case VSIX asset as a distinct identity' {
        $findings = Invoke-AssetSetTest -AssetName (New-AssetSet -Remove @('hve-core-3.3.0.vsix') -Add @('HVE-Core-3.3.0.vsix'))
        $findings | Should -Contain "missing VSIX asset 'hve-core-3.3.0.vsix'"
        $findings | Should -Contain "unexpected VSIX asset 'HVE-Core-3.3.0.vsix'"
    }

    It 'Does not collapse two case-colliding assets into one duplicate' {
        $findings = Invoke-AssetSetTest -AssetName (New-AssetSet -Add @('HVE-Core-3.3.0.vsix'))
        $findings | Should -Contain "unexpected VSIX asset 'HVE-Core-3.3.0.vsix'"
        @($findings | Where-Object { $_ -like 'duplicate asset*' }) | Should -BeNullOrEmpty
    }

    It 'Treats a mixed-case required asset as absent' {
        $findings = Invoke-AssetSetTest -AssetName (New-AssetSet -Remove @('dependencies.spdx.json') -Add @('Dependencies.spdx.json'))
        $findings | Should -Be @(
            "missing required asset 'dependencies.spdx.json'"
            "unexpected asset 'Dependencies.spdx.json'"
        )
    }

    It 'Treats a mixed-case sidecar as absent' {
        $findings = Invoke-AssetSetTest -AssetName (New-AssetSet -Remove @('hve-core-3.3.0.vsix.spdx.json') -Add @('hve-core-3.3.0.vsix.SPDX.json'))
        $findings | Should -Be @(
            "missing sidecar 'hve-core-3.3.0.vsix.spdx.json' for VSIX asset 'hve-core-3.3.0.vsix'"
            "unexpected asset 'hve-core-3.3.0.vsix.SPDX.json'"
        )
    }

    It 'Reports every finding rather than stopping at the first' {
        $findings = Invoke-AssetSetTest -AssetName (New-AssetSet -Remove @(
                'hve-core-3.3.0.vsix.spdx.json'
                'dependencies.spdx.json'
            ))
        @($findings).Count | Should -Be 2
    }

    It 'Does not echo sidecar findings for an absent primary asset' {
        $findings = Invoke-AssetSetTest -AssetName (New-AssetSet -Remove @(
                'hve-core-3.3.0.vsix'
                'hve-core-3.3.0.vsix.spdx.json'
                'hve-core-3.3.0.vsix.sigstore.json'
                'hve-core-3.3.0.vsix.intoto.jsonl'
            ))
        $findings | Should -Be @("missing VSIX asset 'hve-core-3.3.0.vsix'")
    }
}

Describe 'Assert-ReleaseAssetSet end to end' -Tag 'Unit' {
    BeforeAll {
        $script:RequiredFile = Join-Path $TestDrive 'e2e-required.txt'
        Set-Content -LiteralPath $script:RequiredFile -Encoding utf8 -Value @(
            'dependencies.spdx.json'
            ''
        )

        function Invoke-AssertOverFile {
            <#
            .SYNOPSIS
            Runs the orchestrator over a written asset list.
            .PARAMETER AssetName
            Actual release asset names.
            .PARAMETER Version
            Released version. Defaults to the fixture version.
            .OUTPUTS
            [pscustomobject] The verified identities.
            #>
            [CmdletBinding()]
            [OutputType([pscustomobject])]
            param(
                [Parameter(Mandatory = $true)]
                [AllowEmptyCollection()]
                [string[]]$AssetName,

                [Parameter(Mandatory = $false)]
                [string]$Version = '3.3.0'
            )

            $listPath = Join-Path $TestDrive "assets-$([guid]::NewGuid().ToString('n')).txt"
            Set-Content -LiteralPath $listPath -Encoding utf8 -Value ([string[]]@($AssetName))
            return Assert-ReleaseAssetSet -AssetNamePath $listPath `
                -RequiredAssetPath $script:RequiredFile `
                -Version $Version `
                -ReleaseTag 'prerelease-v3.3.0'
        }
    }

    It 'Returns the verified VSIX identity for a complete release' {
        $result = Invoke-AssertOverFile -AssetName (New-AssetSet)
        $result.ReleaseTag | Should -BeExactly 'prerelease-v3.3.0'
        $result.Version | Should -BeExactly '3.3.0'
        $result.Vsix | Should -Be @('hve-core-3.3.0.vsix')
    }

    It 'Rejects malformed direct helper version <Version>' -ForEach @(
        @{ Version = '3.3' }
        @{ Version = 'v3.3.0' }
        @{ Version = "3.3.0`n4.0.0" }
    ) {
        { Invoke-AssertOverFile -AssetName (New-AssetSet) -Version $Version } |
            Should -Throw '*does not match*'
    }

    It 'Fails an incomplete release with a finding count' {
        { Invoke-AssertOverFile -AssetName (New-AssetSet -Remove @('hve-core-3.3.0.vsix.sigstore.json')) } |
            Should -Throw '*has incomplete release assets: 1 findings*'
    }

    It 'Fails a release whose VSIX carries a different version' {
        # The released version alone names the expected VSIX, so a stale build
        # is both a missing identity and an unexpected one.
        { Invoke-AssertOverFile -AssetName (New-AssetSet) -Version '3.5.0' } |
            Should -Throw '*has incomplete release assets: 2 findings*'
    }

    It 'Fails a release carrying a retired plugin ZIP' {
        { Invoke-AssertOverFile -AssetName (New-AssetSet -Add @('hve-core-3.3.0.zip')) } |
            Should -Throw '*has incomplete release assets: 1 findings*'
    }

    It 'Fails an empty asset list' {
        { Invoke-AssertOverFile -AssetName @() } | Should -Throw '*carries no release assets*'
    }

    It 'Fails an unreadable asset list' {
        { Assert-ReleaseAssetSet -AssetNamePath (Join-Path $TestDrive 'absent.txt') `
                -RequiredAssetPath $script:RequiredFile `
                -Version '3.3.0' `
                -ReleaseTag 'prerelease-v3.3.0' } |
            Should -Throw '*Asset list not found*'
    }

    It 'Fails an empty required asset list' {
        $emptyRequired = Join-Path $TestDrive 'e2e-empty-required.txt'
        Set-Content -LiteralPath $emptyRequired -Encoding utf8 -Value ''
        $listPath = Join-Path $TestDrive 'e2e-assets-empty-required.txt'
        Set-Content -LiteralPath $listPath -Encoding utf8 -Value (New-AssetSet)
        { Assert-ReleaseAssetSet -AssetNamePath $listPath `
                -RequiredAssetPath $emptyRequired `
                -Version '3.3.0' `
                -ReleaseTag 'prerelease-v3.3.0' } |
            Should -Throw '*No required singleton assets were supplied*'
    }
}
