#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../linting/Validate-FsiContent.ps1')

    function New-Manifest {
        param([System.Collections.IDictionary]$Metadata)
        $m = [ordered]@{
            framework = 'test-framework'
            version   = '1.0.0'
            summary   = 'Test framework'
            phaseMap  = [ordered]@{ 'standards-mapping' = @('item-1') }
        }
        if ($null -ne $Metadata) {
            $m['metadata'] = $Metadata
        }
        return $m
    }
}

Describe 'Test-FsiLicensePresence' -Tag 'Unit' {
    Context 'when metadata block is missing' {
        It 'reports an error' {
            $manifest = [ordered]@{ framework = 'x'; version = '1'; summary = 's'; phaseMap = @{} }
            $result = Test-FsiLicensePresence -Manifest $manifest -Framework 'x'
            $result.Errors | Should -HaveCount 1
            $result.Errors[0] | Should -Match 'metadata block is required'
        }
    }

    Context 'when required licensing fields are present and license is non-public-domain' {
        It 'requires licenseUrl' {
            $manifest = New-Manifest -Metadata ([ordered]@{
                    authority           = 'OpenSSF'
                    license             = 'Apache-2.0'
                    attributionRequired = $true
                })
            $result = Test-FsiLicensePresence -Manifest $manifest -Framework 'x'
            $result.Errors | Should -HaveCount 1
            $result.Errors[0] | Should -Match 'licenseUrl is required'
        }

        It 'passes when licenseUrl is supplied' {
            $manifest = New-Manifest -Metadata ([ordered]@{
                    authority           = 'OpenSSF'
                    license             = 'Apache-2.0'
                    licenseUrl          = 'https://example.org/license'
                    attributionRequired = $true
                })
            $result = Test-FsiLicensePresence -Manifest $manifest -Framework 'x'
            $result.Errors | Should -HaveCount 0
        }
    }

    Context 'when license is the US-Gov-Public-Domain sentinel' {
        It 'does not require licenseUrl' {
            $manifest = New-Manifest -Metadata ([ordered]@{
                    authority           = 'NIST'
                    license             = 'US-Gov-Public-Domain'
                    attributionRequired = $false
                })
            $result = Test-FsiLicensePresence -Manifest $manifest -Framework 'x'
            $result.Errors | Should -HaveCount 0
        }
    }

    Context 'when attributionRequired is not boolean' {
        It 'reports a type error' {
            $manifest = New-Manifest -Metadata ([ordered]@{
                    authority           = 'OpenSSF'
                    license             = 'Apache-2.0'
                    licenseUrl          = 'https://example.org'
                    attributionRequired = 'yes'
                })
            $result = Test-FsiLicensePresence -Manifest $manifest -Framework 'x'
            $result.Errors | Where-Object { $_ -match 'attributionRequired must be a boolean' } | Should -HaveCount 1
        }
    }

    Context 'when authority or license is missing' {
        It 'reports both fields' {
            $manifest = New-Manifest -Metadata ([ordered]@{ attributionRequired = $false })
            $result = Test-FsiLicensePresence -Manifest $manifest -Framework 'x'
            $result.Errors | Where-Object { $_ -match 'metadata.authority is required' } | Should -HaveCount 1
            $result.Errors | Where-Object { $_ -match 'metadata.license is required' } | Should -HaveCount 1
        }
    }
}

Describe 'Test-FsiAttributionCoherence' -Tag 'Unit' {
    Context 'when attributionRequired is true' {
        It 'errors when attributionText is missing' {
            $manifest = New-Manifest -Metadata ([ordered]@{
                    attributionRequired = $true
                })
            $result = Test-FsiAttributionCoherence -Manifest $manifest -Framework 'x'
            $result.Errors | Should -HaveCount 1
            $result.Errors[0] | Should -Match 'attributionText must be a non-empty string'
        }

        It 'errors when attributionText is whitespace only' {
            $manifest = New-Manifest -Metadata ([ordered]@{
                    attributionRequired = $true
                    attributionText     = '   '
                })
            $result = Test-FsiAttributionCoherence -Manifest $manifest -Framework 'x'
            $result.Errors | Should -HaveCount 1
        }

        It 'passes when attributionText is supplied' {
            $manifest = New-Manifest -Metadata ([ordered]@{
                    attributionRequired = $true
                    attributionText     = 'Copyright Example.'
                })
            $result = Test-FsiAttributionCoherence -Manifest $manifest -Framework 'x'
            $result.Errors | Should -HaveCount 0
        }
    }

    Context 'when attributionRequired is false' {
        It 'does not require attributionText' {
            $manifest = New-Manifest -Metadata ([ordered]@{ attributionRequired = $false })
            $result = Test-FsiAttributionCoherence -Manifest $manifest -Framework 'x'
            $result.Errors | Should -HaveCount 0
        }
    }
}

Describe 'Test-FsiDisclaimerPresence' -Tag 'Unit' {
    Context 'when metadata.disclaimer is absent' {
        It 'returns no errors and no warning when attributionRequired is false' {
            $manifest = New-Manifest -Metadata ([ordered]@{ attributionRequired = $false })
            $result = Test-FsiDisclaimerPresence -Manifest $manifest -Framework 'x'
            $result.Errors | Should -HaveCount 0
            $result.Warnings | Should -HaveCount 0
        }

        It 'returns no errors and no warning when attributionRequired is true (disclaimer is optional and reserved for framework-specific caveats)' {
            $manifest = New-Manifest -Metadata ([ordered]@{ attributionRequired = $true })
            $result = Test-FsiDisclaimerPresence -Manifest $manifest -Framework 'x'
            $result.Errors | Should -HaveCount 0
            $result.Warnings | Should -HaveCount 0
        }
    }

    Context 'when metadata.disclaimer is a string' {
        It 'accepts a non-empty string' {
            $manifest = New-Manifest -Metadata ([ordered]@{
                    attributionRequired = $true
                    disclaimer          = 'SCI outputs are directional estimates, not an audited carbon disclosure.'
                })
            $result = Test-FsiDisclaimerPresence -Manifest $manifest -Framework 'x'
            $result.Errors | Should -HaveCount 0
            $result.Warnings | Should -HaveCount 0
        }

        It 'errors when the string is whitespace only' {
            $manifest = New-Manifest -Metadata ([ordered]@{
                    attributionRequired = $false
                    disclaimer          = '   '
                })
            $result = Test-FsiDisclaimerPresence -Manifest $manifest -Framework 'x'
            $result.Errors | Should -HaveCount 1
            $result.Errors[0] | Should -Match 'string form must be non-empty'
        }
    }

    Context 'when metadata.disclaimer is an object' {
        It 'accepts a well-formed object with text, severity, and reviewer' {
            $manifest = New-Manifest -Metadata ([ordered]@{
                    attributionRequired = $true
                    disclaimer          = [ordered]@{
                        text     = 'Requires WCAG auditor review.'
                        severity = 'caution'
                        reviewer = 'WCAG auditor'
                    }
                })
            $result = Test-FsiDisclaimerPresence -Manifest $manifest -Framework 'x'
            $result.Errors | Should -HaveCount 0
            $result.Warnings | Should -HaveCount 0
        }

        It 'errors when text is missing' {
            $manifest = New-Manifest -Metadata ([ordered]@{
                    disclaimer = [ordered]@{ severity = 'info' }
                })
            $result = Test-FsiDisclaimerPresence -Manifest $manifest -Framework 'x'
            $result.Errors | Where-Object { $_ -match 'disclaimer.text is required' } | Should -HaveCount 1
        }

        It 'errors when severity is outside the allowed enum' {
            $manifest = New-Manifest -Metadata ([ordered]@{
                    disclaimer = [ordered]@{ text = 'Hi.'; severity = 'critical' }
                })
            $result = Test-FsiDisclaimerPresence -Manifest $manifest -Framework 'x'
            $result.Errors | Where-Object { $_ -match 'severity must be one of' } | Should -HaveCount 1
        }

        It 'errors when reviewer is whitespace only' {
            $manifest = New-Manifest -Metadata ([ordered]@{
                    disclaimer = [ordered]@{ text = 'Hi.'; reviewer = '   ' }
                })
            $result = Test-FsiDisclaimerPresence -Manifest $manifest -Framework 'x'
            $result.Errors | Where-Object { $_ -match 'reviewer must be non-empty' } | Should -HaveCount 1
        }
    }

    Context 'when metadata.disclaimer is an unsupported type' {
        It 'errors with a shape message' {
            $manifest = New-Manifest -Metadata ([ordered]@{ disclaimer = 42 })
            $result = Test-FsiDisclaimerPresence -Manifest $manifest -Framework 'x'
            $result.Errors | Where-Object { $_ -match 'must be a string or an object' } | Should -HaveCount 1
        }
    }
}

Describe 'Test-FsiRedistributionCoherence' -Tag 'Unit' {
    BeforeAll {
        function New-ItemFile {
            param([string]$Name, [string]$Yaml)
            $path = Join-Path $TestDrive $Name
            Set-Content -LiteralPath $path -Value $Yaml -Encoding utf8
            return Get-Item -LiteralPath $path
        }
    }

    Context 'when redistribution permits verbatim text' {
        It 'allows long body fields' {
            $longBody = ('x' * 500)
            $item = New-ItemFile -Name 'permissive.yml' -Yaml @"
id: item-1
title: Item 1
body: "$longBody"
"@
            $manifest = New-Manifest -Metadata ([ordered]@{
                    redistribution = [ordered]@{
                        textVerbatim              = $true
                        idsAndUrlsOnly            = $false
                        derivedSummariesPermitted = $true
                    }
                })
            $result = Test-FsiRedistributionCoherence -Manifest $manifest -Framework 'x' -ItemFiles @($item) -RepoRoot $TestDrive
            $result.Errors | Should -HaveCount 0
        }
    }

    Context 'when textVerbatim is false' {
        It 'errors on per-item body exceeding MaxItemBodyChars' {
            $longBody = ('x' * 250)
            $item = New-ItemFile -Name 'too-long.yml' -Yaml @"
id: item-1
title: Item 1
body: "$longBody"
"@
            $manifest = New-Manifest -Metadata ([ordered]@{
                    redistribution = [ordered]@{
                        textVerbatim              = $false
                        idsAndUrlsOnly            = $false
                        derivedSummariesPermitted = $true
                    }
                })
            $result = Test-FsiRedistributionCoherence -Manifest $manifest -Framework 'x' -ItemFiles @($item) -MaxItemBodyChars 200 -RepoRoot $TestDrive
            $result.Errors | Should -HaveCount 1
            $result.Errors[0] | Should -Match 'exceeds redistribution limit'
        }

        It 'passes when body is under the limit' {
            $shortBody = ('x' * 50)
            $item = New-ItemFile -Name 'short.yml' -Yaml @"
id: item-1
title: Item 1
body: "$shortBody"
"@
            $manifest = New-Manifest -Metadata ([ordered]@{
                    redistribution = [ordered]@{
                        textVerbatim              = $false
                        idsAndUrlsOnly            = $false
                        derivedSummariesPermitted = $true
                    }
                })
            $result = Test-FsiRedistributionCoherence -Manifest $manifest -Framework 'x' -ItemFiles @($item) -MaxItemBodyChars 200 -RepoRoot $TestDrive
            $result.Errors | Should -HaveCount 0
        }
    }

    Context 'when idsAndUrlsOnly is true' {
        It 'errors on long description fields' {
            $longDesc = ('y' * 300)
            $item = New-ItemFile -Name 'desc.yml' -Yaml @"
id: item-1
title: Item 1
description: "$longDesc"
"@
            $manifest = New-Manifest -Metadata ([ordered]@{
                    redistribution = [ordered]@{
                        textVerbatim              = $true
                        idsAndUrlsOnly            = $true
                        derivedSummariesPermitted = $true
                    }
                })
            $result = Test-FsiRedistributionCoherence -Manifest $manifest -Framework 'x' -ItemFiles @($item) -MaxItemBodyChars 200 -RepoRoot $TestDrive
            $result.Errors | Should -HaveCount 1
            $result.Errors[0] | Should -Match 'item.description length'
        }
    }
}

Describe 'Framework Skill manifests in repo' -Tag 'Unit' {
    It 'all <_> manifests pass licensing presence and attribution coherence' -ForEach @(
        '.github/skills/security/openssf-scorecard/index.yml'
        '.github/skills/security/openssf-best-practices-badge/index.yml'
        '.github/skills/security/nist-ssdf/index.yml'
        '.github/skills/security/slsa/index.yml'
        '.github/skills/security/sigstore/index.yml'
        '.github/skills/security/cisa-sscm/index.yml'
        '.github/skills/security/s2c2f/index.yml'
        '.github/skills/security/sbom/index.yml'
        '.github/skills/security/capability-inventory-hve-core/index.yml'
        '.github/skills/security/capability-inventory-physical-ai/index.yml'
        '.github/skills/project-planning/adr-template/index.yml'
        '.github/skills/project-planning/prd-template/index.yml'
    ) {
        $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '../../..')
        $manifestPath = Join-Path $repoRoot $_
        Test-Path -LiteralPath $manifestPath | Should -BeTrue

        $raw = Get-Content -LiteralPath $manifestPath -Raw
        $manifest = $raw | ConvertFrom-Yaml -ErrorAction Stop

        $presence = Test-FsiLicensePresence -Manifest $manifest -Framework $_
        $presence.Errors | Should -HaveCount 0

        $coherence = Test-FsiAttributionCoherence -Manifest $manifest -Framework $_
        $coherence.Errors | Should -HaveCount 0
    }
}
