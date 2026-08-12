#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ScriptPath = (Resolve-Path (Join-Path $PSScriptRoot '../../release/Assert-ReleaseAssetSet.ps1')).Path
    . $script:ScriptPath `
        -AssetNamePath 'unused' `
        -EvidencePath 'unused' `
        -RequiredAssetPath 'unused' `
        -Channel PreRelease `
        -Version '3.3.0' `
        -ReleaseTag 'prerelease-v3.3.0'

    $script:RequiredAsset = [string[]]@('dependencies.spdx.json', 'plugin-release-evidence.json')
    $script:ExpectedZip = [string[]]@('alpha.zip', 'beta.zip')
    $script:ExpectedVsix = [string[]]@('hve-alpha-3.3.0.vsix', 'hve-beta-3.3.0.vsix')

    # One released-catalog fixture backs every expected identity, because plugin
    # ZIP and VSIX membership both derive from the catalog under channel policy.
    $script:FixtureCatalog = Join-Path $TestDrive 'released-marketplace.json'
    @{
        metadata = @{ version = '3.3.0' }
        plugins  = @(
            @{ name = 'alpha' }
            @{ name = 'beta' }
            @{ name = 'retired'; 'x-hve' = @{ maturity = 'deprecated' } }
        )
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $script:FixtureCatalog -Encoding utf8

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
        foreach ($primary in @($script:ExpectedZip) + @($script:ExpectedVsix)) {
            $names.Add($primary)
            foreach ($suffix in @('.spdx.json', '.sigstore.json', '.intoto.jsonl')) {
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
            -ExpectedPluginZip $script:ExpectedZip `
            -ExpectedVsix $script:ExpectedVsix `
            -RequiredAsset $script:RequiredAsset
    }

    function New-EvidenceDocument {
        <#
        .SYNOPSIS
        Builds a plugin release evidence document for fixture use.
        .PARAMETER Version
        Recorded release version.
        .PARAMETER PackageName
        Recorded package names.
        .PARAMETER PackageCount
        Declared package count. Defaults to the package name count.
        .OUTPUTS
        [hashtable] Evidence document.
        #>
        [CmdletBinding()]
        [OutputType([hashtable])]
        param(
            [Parameter(Mandatory = $false)]
            [string]$Version = '3.3.0',

            [Parameter(Mandatory = $false)]
            [string[]]$PackageName = @('alpha', 'beta'),

            [Parameter(Mandatory = $false)]
            [int]$PackageCount = -1
        )

        $packages = @($PackageName | ForEach-Object {
                @{ name = $_; digest = ('0' * 64); fileCount = 3 }
            })
        return @{
            schema       = 'hve-core/plugin-release-evidence/v2'
            version      = $Version
            packageCount = $(if ($PackageCount -ge 0) { $PackageCount } else { $packages.Count })
            packages     = $packages
        }
    }
}

Describe 'Assert-ReleaseAssetSet expected identities' -Tag 'Unit' {
    Context 'Plugin ZIP identities from the released catalog' {
        It 'Derives one ZIP identity per released catalog package' {
            # A deprecated catalog entry contributes no expected ZIP, so the
            # count follows channel policy rather than a hand-maintained number.
            Get-ReleaseExpectedPluginZipName -Evidence (New-EvidenceDocument) -Version '3.3.0' -CatalogPath $script:FixtureCatalog |
                Should -Be @('alpha.zip', 'beta.zip')
        }

        It 'Derives the expectation from the catalog rather than the evidence ordering' {
            Get-ReleaseExpectedPluginZipName -Evidence (New-EvidenceDocument -PackageName @('beta', 'alpha')) -Version '3.3.0' -CatalogPath $script:FixtureCatalog |
                Should -Be @('alpha.zip', 'beta.zip')
        }

        # A tampered release can rewrite plugin-release-evidence.json into a
        # smaller self-consistent document, so the released catalog is the
        # authority the document is reconciled against.
        It 'Rejects a self-consistent evidence document that omits a released catalog package' {
            { Get-ReleaseExpectedPluginZipName -Evidence (New-EvidenceDocument -PackageName @('alpha')) -Version '3.3.0' -CatalogPath $script:FixtureCatalog } |
                Should -Throw '*omits released catalog package(s): beta*'
        }

        It 'Rejects evidence recording a package the released catalog does not publish' {
            { Get-ReleaseExpectedPluginZipName -Evidence (New-EvidenceDocument -PackageName @('alpha', 'beta', 'gamma')) -Version '3.3.0' -CatalogPath $script:FixtureCatalog } |
                Should -Throw '*does not publish: gamma*'
        }

        It 'Rejects evidence recording a package the channel policy excludes' {
            { Get-ReleaseExpectedPluginZipName -Evidence (New-EvidenceDocument -PackageName @('alpha', 'beta', 'retired')) -Version '3.3.0' -CatalogPath $script:FixtureCatalog } |
                Should -Throw '*does not publish: retired*'
        }

        It 'Matches evidence package names ordinally' {
            { Get-ReleaseExpectedPluginZipName -Evidence (New-EvidenceDocument -PackageName @('Alpha', 'beta')) -Version '3.3.0' -CatalogPath $script:FixtureCatalog } |
                Should -Throw '*omits released catalog package(s): alpha*'
        }

        It 'Rejects evidence recorded for a different version' {
            { Get-ReleaseExpectedPluginZipName -Evidence (New-EvidenceDocument -Version '3.1.0') -Version '3.3.0' -CatalogPath $script:FixtureCatalog } |
                Should -Throw '*records version 3.1.0 but the release is 3.3.0*'
        }

        It 'Rejects a packageCount that disagrees with the package array' {
            { Get-ReleaseExpectedPluginZipName -Evidence (New-EvidenceDocument -PackageCount 5) -Version '3.3.0' -CatalogPath $script:FixtureCatalog } |
                Should -Throw '*declares packageCount 5 but carries 2 package entries*'
        }

        It 'Rejects an empty package set' {
            { Get-ReleaseExpectedPluginZipName -Evidence (New-EvidenceDocument -PackageName @() -PackageCount 0) -Version '3.3.0' -CatalogPath $script:FixtureCatalog } |
                Should -Throw '*declares packageCount 0*'
        }

        It 'Rejects duplicate package names' {
            { Get-ReleaseExpectedPluginZipName -Evidence (New-EvidenceDocument -PackageName @('alpha', 'alpha')) -Version '3.3.0' -CatalogPath $script:FixtureCatalog } |
                Should -Throw '*duplicate package names*'
        }

        It 'Rejects a package entry without a name' {
            { Get-ReleaseExpectedPluginZipName -Evidence (New-EvidenceDocument -PackageName @('alpha', ' ')) -Version '3.3.0' -CatalogPath $script:FixtureCatalog } |
                Should -Throw '*package entry without a name*'
        }

        It 'Rejects evidence missing a required field' {
            $evidence = New-EvidenceDocument
            $evidence.Remove('packageCount')
            { Get-ReleaseExpectedPluginZipName -Evidence $evidence -Version '3.3.0' -CatalogPath $script:FixtureCatalog } |
                Should -Throw "*declares no 'packageCount' field*"
        }
    }

    Context 'VSIX identities from the released catalog' {
        It 'Derives one VSIX identity per <Channel>-eligible catalog package' -ForEach @(
            @{ Channel = 'PreRelease' }
            @{ Channel = 'Stable' }
        ) {
            # The count follows the catalog under channel policy, so a
            # deprecated package contributes no expected VSIX.
            Get-ReleaseExpectedVsixName -Channel $Channel -Version '3.3.0' -CatalogPath $script:FixtureCatalog |
                Should -Be @('hve-alpha-3.3.0.vsix', 'hve-beta-3.3.0.vsix')
        }

        It 'Resolves the repository catalog and its extension identities' {
            $catalog = (Resolve-Path (Join-Path $PSScriptRoot '../../../.github/plugin/marketplace.json')).Path
            $actual = Get-ReleaseExpectedVsixName -Channel Stable -Version '9.9.9' -CatalogPath $catalog
            @($actual).Count | Should -BeGreaterThan 1
            $actual | Should -Contain 'hve-core-9.9.9.vsix'
            $actual | Should -Contain 'hve-security-9.9.9.vsix'
            @($actual | Where-Object { $_ -notmatch '^hve-[a-z0-9-]+-9\.9\.9\.vsix$' }) | Should -BeNullOrEmpty
        }
    }

    Context 'Repeated import' {
        # A Constant script variable cannot be replaced even with -Force, so a
        # second dot-source of the helper must stay possible.
        It 'Dot-sources again without failing on its script-scoped state' {
            {
                . $script:ScriptPath `
                    -AssetNamePath 'unused' `
                    -EvidencePath 'unused' `
                    -RequiredAssetPath 'unused' `
                    -Channel PreRelease `
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

    It 'Reports a missing <Kind> asset' -ForEach @(
        @{ Kind = 'plugin ZIP'; Asset = 'beta.zip' }
        @{ Kind = 'VSIX'; Asset = 'hve-alpha-3.3.0.vsix' }
    ) {
        $findings = Invoke-AssetSetTest -AssetName (New-AssetSet -Remove @($Asset))
        $findings | Should -Contain "missing $Kind asset '$Asset'"
    }

    It 'Reports an unexpected <Kind> asset' -ForEach @(
        @{ Kind = 'plugin ZIP'; Asset = 'gamma.zip' }
        @{ Kind = 'VSIX'; Asset = 'hve-gamma-3.3.0.vsix' }
    ) {
        $findings = Invoke-AssetSetTest -AssetName (New-AssetSet -Add @(
                $Asset
                "$Asset.spdx.json"
                "$Asset.sigstore.json"
                "$Asset.intoto.jsonl"
            ))
        $findings | Should -Contain "unexpected $Kind asset '$Asset'"
    }

    It 'Reports a stale VSIX carrying the wrong release version' {
        # A leftover asset from an earlier attempt is an identity mismatch, not
        # an acceptable extra file.
        $findings = Invoke-AssetSetTest -AssetName (New-AssetSet -Add @('hve-alpha-3.1.0.vsix'))
        $findings | Should -Contain "unexpected VSIX asset 'hve-alpha-3.1.0.vsix'"
    }

    It 'Reports a duplicate asset name' {
        $findings = Invoke-AssetSetTest -AssetName (New-AssetSet -Add @('alpha.zip'))
        $findings | Should -Contain "duplicate asset 'alpha.zip' appears 2 times"
    }

    It 'Reports an incomplete <Sidecar> sidecar for <Kind> asset <Primary>' -ForEach @(
        @{ Kind = 'plugin ZIP'; Primary = 'alpha.zip'; Sidecar = '.spdx.json' }
        @{ Kind = 'plugin ZIP'; Primary = 'alpha.zip'; Sidecar = '.sigstore.json' }
        @{ Kind = 'plugin ZIP'; Primary = 'alpha.zip'; Sidecar = '.intoto.jsonl' }
        @{ Kind = 'VSIX'; Primary = 'hve-beta-3.3.0.vsix'; Sidecar = '.spdx.json' }
        @{ Kind = 'VSIX'; Primary = 'hve-beta-3.3.0.vsix'; Sidecar = '.sigstore.json' }
        @{ Kind = 'VSIX'; Primary = 'hve-beta-3.3.0.vsix'; Sidecar = '.intoto.jsonl' }
    ) {
        $findings = Invoke-AssetSetTest -AssetName (New-AssetSet -Remove @("$Primary$Sidecar"))
        $findings | Should -Be @("missing sidecar '$Primary$Sidecar' for $Kind asset '$Primary'")
    }

    It 'Reports a missing required singleton asset' {
        $findings = Invoke-AssetSetTest -AssetName (New-AssetSet -Remove @('dependencies.spdx.json'))
        $findings | Should -Contain "missing required asset 'dependencies.spdx.json'"
    }

    # Release asset names are ordinal identities, so a case variant is a
    # different asset rather than the expected one.
    It 'Treats a mixed-case <Kind> asset as a distinct identity' -ForEach @(
        @{ Kind = 'plugin ZIP'; Expected = 'alpha.zip'; Variant = 'ALPHA.zip' }
        @{ Kind = 'VSIX'; Expected = 'hve-alpha-3.3.0.vsix'; Variant = 'HVE-Alpha-3.3.0.vsix' }
    ) {
        $findings = Invoke-AssetSetTest -AssetName (New-AssetSet -Remove @($Expected) -Add @($Variant))
        $findings | Should -Contain "missing $Kind asset '$Expected'"
        $findings | Should -Contain "unexpected $Kind asset '$Variant'"
    }

    It 'Does not collapse two case-colliding assets into one duplicate' {
        $findings = Invoke-AssetSetTest -AssetName (New-AssetSet -Add @('Alpha.zip'))
        $findings | Should -Contain "unexpected plugin ZIP asset 'Alpha.zip'"
        @($findings | Where-Object { $_ -like 'duplicate asset*' }) | Should -BeNullOrEmpty
    }

    It 'Treats a mixed-case required asset as absent' {
        $findings = Invoke-AssetSetTest -AssetName (New-AssetSet -Remove @('dependencies.spdx.json') -Add @('Dependencies.spdx.json'))
        $findings | Should -Be @("missing required asset 'dependencies.spdx.json'")
    }

    It 'Treats a mixed-case sidecar as absent' {
        $findings = Invoke-AssetSetTest -AssetName (New-AssetSet -Remove @('alpha.zip.spdx.json') -Add @('alpha.zip.SPDX.json'))
        $findings | Should -Be @("missing sidecar 'alpha.zip.spdx.json' for plugin ZIP asset 'alpha.zip'")
    }

    It 'Rejects a release carrying one of each primary kind' {
        # The superseded contract accepted any nonzero VSIX and ZIP count.
        $partial = [string[]]@(
            'dependencies.spdx.json'
            'plugin-release-evidence.json'
            'alpha.zip'
            'alpha.zip.spdx.json'
            'alpha.zip.sigstore.json'
            'alpha.zip.intoto.jsonl'
            'hve-alpha-3.3.0.vsix'
            'hve-alpha-3.3.0.vsix.spdx.json'
            'hve-alpha-3.3.0.vsix.sigstore.json'
            'hve-alpha-3.3.0.vsix.intoto.jsonl'
        )
        $findings = Invoke-AssetSetTest -AssetName $partial
        $findings | Should -Contain "missing plugin ZIP asset 'beta.zip'"
        $findings | Should -Contain "missing VSIX asset 'hve-beta-3.3.0.vsix'"
    }

    It 'Reports every finding rather than stopping at the first' {
        $findings = Invoke-AssetSetTest -AssetName (New-AssetSet -Remove @('beta.zip', 'alpha.zip.spdx.json', 'dependencies.spdx.json'))
        @($findings).Count | Should -Be 3
    }

    It 'Does not echo sidecar findings for an absent primary asset' {
        $findings = Invoke-AssetSetTest -AssetName (New-AssetSet -Remove @(
                'beta.zip'
                'beta.zip.spdx.json'
                'beta.zip.sigstore.json'
                'beta.zip.intoto.jsonl'
            ))
        $findings | Should -Be @("missing plugin ZIP asset 'beta.zip'")
    }
}

Describe 'Assert-ReleaseAssetSet end to end' -Tag 'Unit' {
    BeforeAll {
        $script:EvidenceFile = Join-Path $TestDrive 'e2e-evidence.json'
        New-EvidenceDocument | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $script:EvidenceFile -Encoding utf8

        $script:PartialEvidenceFile = Join-Path $TestDrive 'e2e-partial-evidence.json'
        New-EvidenceDocument -PackageName @('alpha') | ConvertTo-Json -Depth 6 |
            Set-Content -LiteralPath $script:PartialEvidenceFile -Encoding utf8

        $script:RequiredFile = Join-Path $TestDrive 'e2e-required.txt'
        Set-Content -LiteralPath $script:RequiredFile -Encoding utf8 -Value @(
            'dependencies.spdx.json'
            'plugin-release-evidence.json'
            ''
        )

        function Invoke-AssertOverFile {
            <#
            .SYNOPSIS
            Runs the orchestrator over a written asset list.
            .PARAMETER AssetName
            Actual release asset names.
            .PARAMETER EvidencePath
            Evidence document to reconcile. Defaults to the complete fixture.
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
                [string]$EvidencePath = $script:EvidenceFile,

                [Parameter(Mandatory = $false)]
                [string]$Version = '3.3.0'
            )

            $listPath = Join-Path $TestDrive "assets-$([guid]::NewGuid().ToString('n')).txt"
            Set-Content -LiteralPath $listPath -Encoding utf8 -Value ([string[]]@($AssetName))
            return Assert-ReleaseAssetSet -AssetNamePath $listPath `
                -EvidencePath $EvidencePath `
                -RequiredAssetPath $script:RequiredFile `
                -Channel PreRelease `
                -Version $Version `
                -ReleaseTag 'prerelease-v3.3.0' `
                -CatalogPath $script:FixtureCatalog
        }
    }

    It 'Reports the verified identities for a complete published release' {
        $result = Invoke-AssertOverFile -AssetName (New-AssetSet)
        $result.PluginZip | Should -Be $script:ExpectedZip
        $result.Vsix | Should -Be $script:ExpectedVsix
        $result.ReleaseTag | Should -BeExactly 'prerelease-v3.3.0'
    }

    It 'Fails an incomplete published release with a finding count' {
        { Invoke-AssertOverFile -AssetName (New-AssetSet -Remove @('beta.zip')) } |
            Should -Throw '*has incomplete release assets: 1 findings*'
    }

    # The verified release is complete under its own evidence, so only the
    # released catalog can expose the shortened package list.
    It 'Fails a self-consistent release whose evidence omits a catalog package' {
        $shortened = [string[]]@(
            'dependencies.spdx.json'
            'plugin-release-evidence.json'
            'alpha.zip'
            'alpha.zip.spdx.json'
            'alpha.zip.sigstore.json'
            'alpha.zip.intoto.jsonl'
        )
        { Invoke-AssertOverFile -AssetName $shortened -EvidencePath $script:PartialEvidenceFile } |
            Should -Throw '*omits released catalog package(s): beta*'
    }

    It 'Rejects a version that is not MAJOR.MINOR.PATCH' {
        { Invoke-AssertOverFile -AssetName (New-AssetSet) -Version '3.3' } |
            Should -Throw '*does not match the*'
    }

    It 'Fails a release carrying no assets' {
        $listPath = Join-Path $TestDrive 'empty-assets.txt'
        Set-Content -LiteralPath $listPath -Encoding utf8 -Value "`n   `n"
        {
            Assert-ReleaseAssetSet -AssetNamePath $listPath `
                -EvidencePath $script:EvidenceFile `
                -RequiredAssetPath $script:RequiredFile `
                -Channel PreRelease `
                -Version '3.3.0' `
                -ReleaseTag 'prerelease-v3.3.0' `
                -CatalogPath $script:FixtureCatalog
        } | Should -Throw '*carries no release assets*'
    }

    It 'Fails when the evidence document is absent' {
        $listPath = Join-Path $TestDrive 'absent-evidence-assets.txt'
        Set-Content -LiteralPath $listPath -Encoding utf8 -Value (New-AssetSet)
        {
            Assert-ReleaseAssetSet -AssetNamePath $listPath `
                -EvidencePath (Join-Path $TestDrive 'missing-evidence.json') `
                -RequiredAssetPath $script:RequiredFile `
                -Channel PreRelease `
                -Version '3.3.0' `
                -ReleaseTag 'prerelease-v3.3.0' `
                -CatalogPath $script:FixtureCatalog
        } | Should -Throw '*carries no readable plugin-release-evidence.json*'
    }
}
