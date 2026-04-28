#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../linting/Validate-FsiContent.ps1')
}

Describe 'Test-FsiLicenseVerification' -Tag 'Unit' {
    Context 'absent licenseVerification block' {
        It 'returns no errors or warnings' {
            $manifest = [ordered]@{
                framework = 'demo'
                metadata  = [ordered]@{
                    authority             = 'Demo Authority'
                    license               = 'CC-BY-4.0'
                    attributionRequired   = $true
                    attributionText       = 'Demo'
                }
            }
            $result = Test-FsiLicenseVerification -Manifest $manifest -Framework 'demo'
            $result.Errors | Should -HaveCount 0
            $result.Warnings | Should -HaveCount 0
        }
    }

    Context 'verified status with matching declaredLicense' {
        It 'returns no errors or warnings' {
            $manifest = [ordered]@{
                framework = 'demo'
                status    = 'published'
                metadata  = [ordered]@{
                    authority           = 'Demo'
                    license             = 'CC-BY-4.0'
                    attributionRequired = $true
                    attributionText     = 'Demo'
                    licenseVerification = [ordered]@{
                        verifiedAt       = '2026-04-22T00:00:00Z'
                        verifiedUrl      = 'https://example.org/license'
                        sha256           = ('a' * 64)
                        declaredLicense  = 'CC-BY-4.0'
                        status           = 'verified'
                    }
                }
            }
            $result = Test-FsiLicenseVerification -Manifest $manifest -Framework 'demo'
            $result.Errors | Should -HaveCount 0
            $result.Warnings | Should -HaveCount 0
        }
    }

    Context 'FSI-LV-05: discrepancy on a published bundle' {
        It 'emits a hard error' {
            $manifest = [ordered]@{
                framework = 'demo'
                status    = 'published'
                metadata  = [ordered]@{
                    authority           = 'Demo'
                    license             = 'CC-BY-4.0'
                    attributionRequired = $true
                    attributionText     = 'Demo'
                    licenseVerification = [ordered]@{
                        verifiedAt       = '2026-04-22T00:00:00Z'
                        verifiedUrl      = 'https://example.org/license'
                        sha256           = ('b' * 64)
                        declaredLicense  = 'Apache-2.0'
                        status           = 'discrepancy'
                        discrepancyNotes = 'Upstream relicensed.'
                    }
                }
            }
            $result = Test-FsiLicenseVerification -Manifest $manifest -Framework 'demo'
            $result.Errors | Should -HaveCount 1
            $result.Errors[0] | Should -Match 'FSI-LV-05'
        }

        It 'defaults missing top-level status to published and still errors' {
            $manifest = [ordered]@{
                framework = 'demo'
                metadata  = [ordered]@{
                    authority           = 'Demo'
                    license             = 'CC-BY-4.0'
                    attributionRequired = $true
                    attributionText     = 'Demo'
                    licenseVerification = [ordered]@{
                        verifiedAt       = '2026-04-22T00:00:00Z'
                        verifiedUrl      = 'https://example.org/license'
                        sha256           = ('c' * 64)
                        declaredLicense  = 'Apache-2.0'
                        status           = 'discrepancy'
                        discrepancyNotes = 'Upstream relicensed.'
                    }
                }
            }
            $result = Test-FsiLicenseVerification -Manifest $manifest -Framework 'demo'
            $result.Errors | Should -HaveCount 1
            $result.Errors[0] | Should -Match 'FSI-LV-05'
        }
    }

    Context 'discrepancy on a draft bundle' {
        It 'returns no errors (draft bundles may carry unresolved discrepancies)' {
            $manifest = [ordered]@{
                framework = 'demo'
                status    = 'draft'
                metadata  = [ordered]@{
                    authority           = 'Demo'
                    license             = 'CC-BY-4.0'
                    attributionRequired = $true
                    attributionText     = 'Demo'
                    licenseVerification = [ordered]@{
                        verifiedAt       = '2026-04-22T00:00:00Z'
                        verifiedUrl      = 'https://example.org/license'
                        sha256           = ('d' * 64)
                        declaredLicense  = 'Apache-2.0'
                        status           = 'discrepancy'
                        discrepancyNotes = 'Upstream relicensed; remediation tracked.'
                    }
                }
            }
            $result = Test-FsiLicenseVerification -Manifest $manifest -Framework 'demo'
            $result.Errors | Should -HaveCount 0
        }
    }

    Context 'verified status but declaredLicense != metadata.license' {
        It 'emits a warning prompting reconciliation' {
            $manifest = [ordered]@{
                framework = 'demo'
                status    = 'published'
                metadata  = [ordered]@{
                    authority           = 'Demo'
                    license             = 'CC-BY-4.0'
                    attributionRequired = $true
                    attributionText     = 'Demo'
                    licenseVerification = [ordered]@{
                        verifiedAt       = '2026-04-22T00:00:00Z'
                        verifiedUrl      = 'https://example.org/license'
                        sha256           = ('e' * 64)
                        declaredLicense  = 'Apache-2.0'
                        status           = 'verified'
                    }
                }
            }
            $result = Test-FsiLicenseVerification -Manifest $manifest -Framework 'demo'
            $result.Errors | Should -HaveCount 0
            $result.Warnings | Should -HaveCount 1
            $result.Warnings[0] | Should -Match 'declaredLicense'
        }
    }

    Context 'malformed licenseVerification (not a mapping)' {
        It 'emits an error' {
            $manifest = [ordered]@{
                framework = 'demo'
                metadata  = [ordered]@{
                    authority           = 'Demo'
                    license             = 'CC-BY-4.0'
                    licenseVerification = 'not-a-mapping'
                }
            }
            $result = Test-FsiLicenseVerification -Manifest $manifest -Framework 'demo'
            $result.Errors | Should -HaveCount 1
            $result.Errors[0] | Should -Match 'must be a mapping'
        }
    }
}
