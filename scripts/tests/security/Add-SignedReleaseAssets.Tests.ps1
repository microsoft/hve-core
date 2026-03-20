#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    # Stub gh CLI when not installed so Pester can mock it
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { function global:gh { } }

    . $PSScriptRoot/../../security/Add-SignedReleaseAssets.ps1

    # Suppress console output
    Mock Write-Host {}
    Mock Write-Warning {}
}

Describe 'Get-VsixAssetsNeedingSignature' -Tag 'Unit' {
    Context 'When release has no assets' {
        It 'Returns empty array' {
            $release = @{ assets = @() }

            $result = Get-VsixAssetsNeedingSignature -Release $release

            $result.Count | Should -Be 0
        }
    }

    Context 'When release has only non-VSIX assets' {
        It 'Returns empty array' {
            $release = @{
                assets = @(
                    @{ name = 'README.md' },
                    @{ name = 'checksums.txt' }
                )
            }

            $result = Get-VsixAssetsNeedingSignature -Release $release

            $result.Count | Should -Be 0
        }
    }

    Context 'When all VSIX assets already have .sigstore.json' {
        It 'Returns empty array' {
            $release = @{
                assets = @(
                    @{ name = 'extension-1.0.0.vsix' },
                    @{ name = 'extension-1.0.0.vsix.sigstore.json' }
                )
            }

            $result = Get-VsixAssetsNeedingSignature -Release $release

            $result.Count | Should -Be 0
        }
    }

    Context 'When VSIX assets lack .sigstore.json' {
        It 'Returns the VSIX name that needs a signature' {
            $release = @{
                assets = @(
                    @{ name = 'extension-1.0.0.vsix' }
                )
            }

            $result = @(Get-VsixAssetsNeedingSignature -Release $release)

            $result.Count | Should -Be 1
            $result[0] | Should -Be 'extension-1.0.0.vsix'
        }
    }

    Context 'When multiple VSIX assets have mixed coverage' {
        It 'Returns only VSIX names missing .sigstore.json' {
            $release = @{
                assets = @(
                    @{ name = 'ext-a-1.0.0.vsix' },
                    @{ name = 'ext-a-1.0.0.vsix.sigstore.json' },
                    @{ name = 'ext-b-2.0.0.vsix' },
                    @{ name = 'ext-c-3.0.0.vsix' },
                    @{ name = 'ext-c-3.0.0.vsix.sigstore.json' }
                )
            }

            $result = @(Get-VsixAssetsNeedingSignature -Release $release)

            $result.Count | Should -Be 1
            $result[0] | Should -Be 'ext-b-2.0.0.vsix'
        }
    }

    Context 'When all VSIX assets are missing .sigstore.json' {
        It 'Returns all VSIX names' {
            $release = @{
                assets = @(
                    @{ name = 'ext-a-1.0.0.vsix' },
                    @{ name = 'ext-b-2.0.0.vsix' }
                )
            }

            $result = @(Get-VsixAssetsNeedingSignature -Release $release)

            $result.Count | Should -Be 2
            $result | Should -Contain 'ext-a-1.0.0.vsix'
            $result | Should -Contain 'ext-b-2.0.0.vsix'
        }
    }
}

Describe 'Get-AttestationBundle' -Tag 'Unit' {
    Context 'When attestation bundle is found' {
        It 'Returns the bundle file path' {
            $outputDir = Join-Path $TestDrive 'bundles-found'
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
            $bundleFile = Join-Path $outputDir 'sha256-abc123.jsonl'
            New-Item -ItemType File -Path $bundleFile -Force | Out-Null

            Mock gh {}

            $result = Get-AttestationBundle -ArtifactPath "$TestDrive/fake.vsix" `
                -Repository 'owner/repo' -OutputDirectory $outputDir

            $result | Should -Be $bundleFile
            Should -Invoke gh -Times 1 -Exactly
        }
    }

    Context 'When no attestation bundle is found' {
        It 'Returns $null' {
            $outputDir = Join-Path $TestDrive 'bundles-empty'

            Mock gh {}

            $result = Get-AttestationBundle -ArtifactPath "$TestDrive/fake.vsix" `
                -Repository 'owner/repo' -OutputDirectory $outputDir

            $result | Should -BeNullOrEmpty
        }
    }
}

Describe 'Invoke-SignedReleaseAssetUpload' -Tag 'Unit' {
    BeforeEach {
        Mock gh {}
    }

    Context 'When gh auth fails' {
        It 'Writes error and returns early' {
            Mock gh { throw 'not authenticated' } -ParameterFilter {
                $args -contains 'auth' -and $args -contains 'status'
            }
            Mock Write-Error {}

            Invoke-SignedReleaseAssetUpload -Repository 'owner/repo'

            Should -Invoke Write-Error -Times 1 -Exactly
        }
    }

    Context 'When no releases are returned' {
        It 'Reports no releases and returns' {
            Mock gh { return '[]' } -ParameterFilter { $args -contains 'api' }

            Invoke-SignedReleaseAssetUpload -Repository 'owner/repo'

            Should -Invoke Write-Host -ParameterFilter {
                $Object -eq 'No non-draft releases found.'
            }
        }
    }

    Context 'When releases exist with VSIX needing signatures' {
        It 'Downloads VSIX, fetches attestation, and uploads sigstore asset in DryRun mode' {
            $vsixName = 'ext-1.0.0.vsix'
            $releaseJson = @(
                @{
                    tag_name = 'v1.0.0'
                    assets   = @(
                        @{ name = $vsixName }
                    )
                }
            ) | ConvertTo-Json -Depth 5

            Mock gh { return $releaseJson } -ParameterFilter { $args -contains 'api' }
            Mock gh {} -ParameterFilter { $args -contains 'release' -and $args -contains 'download' }
            Mock gh {} -ParameterFilter { $args -contains 'attestation' }
            Mock gh {} -ParameterFilter { $args -contains 'release' -and $args -contains 'upload' }

            Mock Test-Path { return $true }
            Mock Get-AttestationBundle { return "$TestDrive/bundle.jsonl" }
            Mock Copy-Item {}

            Invoke-SignedReleaseAssetUpload -Repository 'owner/repo' -MaxReleases 5 -DryRun

            Should -Invoke Get-AttestationBundle -Times 1 -Exactly
            Should -Invoke gh -Times 0 -ParameterFilter {
                $args -contains 'release' -and $args -contains 'upload'
            }
            Should -Invoke Write-Host -ParameterFilter {
                $Object -like '*DRY RUN*'
            }
        }
    }

    Context 'When VSIX download fails' {
        It 'Warns and skips the asset' {
            $releaseJson = @(
                @{
                    tag_name = 'v1.0.0'
                    assets   = @(
                        @{ name = 'ext-1.0.0.vsix' }
                    )
                }
            ) | ConvertTo-Json -Depth 5

            Mock gh { return $releaseJson } -ParameterFilter { $args -contains 'api' }
            Mock gh {} -ParameterFilter { $args -contains 'release' -and $args -contains 'download' }

            Mock Test-Path { return $false }

            Invoke-SignedReleaseAssetUpload -Repository 'owner/repo'

            Should -Invoke Write-Warning -Times 1 -Exactly
        }
    }

    Context 'When no attestation is found for a VSIX' {
        It 'Skips the asset gracefully' {
            $releaseJson = @(
                @{
                    tag_name = 'v1.0.0'
                    assets   = @(
                        @{ name = 'ext-1.0.0.vsix' }
                    )
                }
            ) | ConvertTo-Json -Depth 5

            Mock gh { return $releaseJson } -ParameterFilter { $args -contains 'api' }
            Mock gh {} -ParameterFilter { $args -contains 'release' -and $args -contains 'download' }
            Mock Test-Path { return $true }
            Mock Get-AttestationBundle { return $null }

            Invoke-SignedReleaseAssetUpload -Repository 'owner/repo'

            Should -Invoke Write-Host -ParameterFilter {
                $Object -like '*no attestation found*'
            }
            Should -Invoke gh -Times 0 -ParameterFilter {
                $args -contains 'release' -and $args -contains 'upload'
            }
        }
    }
}
