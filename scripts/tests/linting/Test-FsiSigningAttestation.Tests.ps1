#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../lib/Modules/FrameworkSkillDiscovery.psm1') -Force
    Import-Module powershell-yaml -ErrorAction SilentlyContinue
    . (Join-Path $PSScriptRoot '../../linting/Validate-FsiContent.ps1')

    $script:RepoRoot = (git -C $PSScriptRoot rev-parse --show-toplevel 2>$null)
    if (-not $script:RepoRoot) { $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path }
    $script:ManifestSchema = Join-Path $script:RepoRoot 'scripts/linting/schemas/framework-skill-manifest.schema.json'
    $script:SectionSchema = Join-Path $script:RepoRoot 'scripts/linting/schemas/document-section.schema.json'

    function script:Test-Manifest([string]$Yaml) {
        $data = ConvertFrom-Yaml $Yaml
        $json = $data | ConvertTo-Json -Depth 20
        $errs = $null
        $valid = Test-Json -Json $json -SchemaFile $script:ManifestSchema -ErrorVariable errs -ErrorAction SilentlyContinue
        return [pscustomobject]@{ Valid = [bool]$valid; Errors = @($errs | ForEach-Object { $_.ToString() }) }
    }

    function script:Test-Section([hashtable]$Section) {
        $json = $Section | ConvertTo-Json -Depth 20
        return Test-Json -Json $json -SchemaFile $script:SectionSchema -ErrorAction SilentlyContinue
    }

    function script:New-BaselineManifest {
        return @'
framework: demo
version: 0.1.0
summary: demo
domain: demo
itemKind: document-section
phaseMap:
  default:
    - sample
status: draft
metadata:
  authority: microsoft/hve-core
  license: MIT
  attributionRequired: false
governance:
  owners:
    - "@microsoft/hve-core"
  review_cadence: P180D
  last_reviewed: "2026-04-21"
'@
    }
}

Describe 'Framework Skill manifest signing schema' -Tag 'Unit' {
    Context 'baseline' {
        It 'accepts manifest without signing block' {
            (Test-Manifest (New-BaselineManifest)).Valid | Should -BeTrue
        }
    }

    Context 'method enum' {
        It 'accepts signing.method = cosign' {
            $yaml = (New-BaselineManifest) + @'

signing:
  method: cosign
'@
            (Test-Manifest $yaml).Valid | Should -BeTrue
        }

        It 'accepts signing.method = gpg' {
            $yaml = (New-BaselineManifest) + @'

signing:
  method: gpg
'@
            (Test-Manifest $yaml).Valid | Should -BeTrue
        }

        It 'accepts signing.method = none' {
            $yaml = (New-BaselineManifest) + @'

signing:
  method: none
'@
            (Test-Manifest $yaml).Valid | Should -BeTrue
        }

        It 'rejects unknown method' {
            $yaml = (New-BaselineManifest) + @'

signing:
  method: pkcs7
'@
            (Test-Manifest $yaml).Valid | Should -BeFalse
        }

        It 'rejects signing block missing required method' {
            $yaml = (New-BaselineManifest) + @'

signing:
  required: true
'@
            (Test-Manifest $yaml).Valid | Should -BeFalse
        }

        It 'rejects unknown signing properties' {
            $yaml = (New-BaselineManifest) + @'

signing:
  method: cosign
  rogue: true
'@
            (Test-Manifest $yaml).Valid | Should -BeFalse
        }
    }

    Context 'transparency_log oneOf' {
        It 'accepts string URL form' {
            $yaml = (New-BaselineManifest) + @'

signing:
  method: cosign
  transparency_log: "https://rekor.sigstore.dev"
'@
            (Test-Manifest $yaml).Valid | Should -BeTrue
        }

        It 'accepts object form with url and public_key' {
            $yaml = (New-BaselineManifest) + @'

signing:
  method: cosign
  transparency_log:
    url: "https://rekor.example.org"
    public_key: "-----BEGIN PUBLIC KEY-----\nMFkwEwYH\n-----END PUBLIC KEY-----"
'@
            (Test-Manifest $yaml).Valid | Should -BeTrue
        }

        It 'rejects object form missing url' {
            $yaml = (New-BaselineManifest) + @'

signing:
  method: cosign
  transparency_log:
    public_key: "abc"
'@
            (Test-Manifest $yaml).Valid | Should -BeFalse
        }
    }

    Context 'verify anyOf' {
        It 'accepts verify with command only' {
            $yaml = (New-BaselineManifest) + @'

signing:
  method: cosign
  verify:
    command: cosign
    args: ["verify-blob", "--bundle", "art.bundle", "art"]
'@
            (Test-Manifest $yaml).Valid | Should -BeTrue
        }

        It 'accepts verify with script only' {
            $yaml = (New-BaselineManifest) + @'

signing:
  method: cosign
  verify:
    script: scripts/security/Verify-Cosign.ps1
'@
            (Test-Manifest $yaml).Valid | Should -BeTrue
        }

        It 'rejects verify with neither command nor script' {
            $yaml = (New-BaselineManifest) + @'

signing:
  method: cosign
  verify:
    args: ["x"]
'@
            (Test-Manifest $yaml).Valid | Should -BeFalse
        }
    }

    Context 'identity field' {
        It 'rejects empty identity' {
            $yaml = (New-BaselineManifest) + @'

signing:
  method: cosign
  identity: ""
'@
            (Test-Manifest $yaml).Valid | Should -BeFalse
        }
    }
}

Describe 'document-section attestation schema' -Tag 'Unit' {
    BeforeAll {
        function script:New-ValidSection {
            return @{
                id       = 'exec-summary'
                title    = 'Executive Summary'
                template = '## Summary'
            }
        }
    }

    Context 'baseline' {
        It 'accepts section without attestation' {
            Test-Section (New-ValidSection) | Should -BeTrue
        }

        It 'accepts attestation with covers single id' {
            $section = New-ValidSection
            $section.attestation = @{ covers = @('exec-summary') }
            Test-Section $section | Should -BeTrue
        }

        It 'accepts attestation with required + multiple ids' {
            $section = New-ValidSection
            $section.attestation = @{
                required = $true
                covers   = @('exec-summary', 'compliance-bundle')
            }
            Test-Section $section | Should -BeTrue
        }
    }

    Context 'covers constraints' {
        It 'rejects attestation missing covers' {
            $section = New-ValidSection
            $section.attestation = @{ required = $true }
            Test-Section $section | Should -BeFalse
        }

        It 'rejects empty covers array' {
            $section = New-ValidSection
            $section.attestation = @{ covers = @() }
            Test-Section $section | Should -BeFalse
        }

        It 'rejects duplicate covers entries' {
            $section = New-ValidSection
            $section.attestation = @{ covers = @('a', 'a') }
            Test-Section $section | Should -BeFalse
        }

        It 'rejects covers entry with uppercase' {
            $section = New-ValidSection
            $section.attestation = @{ covers = @('Bad-Id') }
            Test-Section $section | Should -BeFalse
        }

        It 'rejects covers entry starting with hyphen' {
            $section = New-ValidSection
            $section.attestation = @{ covers = @('-leading') }
            Test-Section $section | Should -BeFalse
        }

        It 'rejects unknown attestation properties' {
            $section = New-ValidSection
            $section.attestation = @{ covers = @('a'); rogue = $true }
            Test-Section $section | Should -BeFalse
        }
    }
}

Describe 'Test-FsiSigningAttestationConsistency' -Tag 'Unit' {
    Context 'manifest signing block' {
        It 'warns when signing.required is true and method is none' {
            $manifest = @{ signing = @{ required = $true; method = 'none' } }
            $result = Test-FsiSigningAttestationConsistency -Manifest $manifest -Framework 'demo' -RepoRoot $TestDrive
            $result.Warnings | Should -HaveCount 1
            $result.Warnings[0] | Should -Match "signing.required is true but signing.method is 'none'"
        }

        It 'is silent when method is cosign with required true' {
            $manifest = @{ signing = @{ required = $true; method = 'cosign' } }
            $result = Test-FsiSigningAttestationConsistency -Manifest $manifest -Framework 'demo' -RepoRoot $TestDrive
            $result.Warnings | Should -HaveCount 0
        }

        It 'is silent when method is none and required is false' {
            $manifest = @{ signing = @{ required = $false; method = 'none' } }
            $result = Test-FsiSigningAttestationConsistency -Manifest $manifest -Framework 'demo' -RepoRoot $TestDrive
            $result.Warnings | Should -HaveCount 0
        }

        It 'is silent when manifest has no signing block' {
            $manifest = @{}
            $result = Test-FsiSigningAttestationConsistency -Manifest $manifest -Framework 'demo' -RepoRoot $TestDrive
            $result.Warnings | Should -HaveCount 0
        }
    }

    Context 'per-item attestation.covers resolution' {
        It 'resolves covers entries that match pipeline produces ids' {
            $yaml = @'
id: section-a
title: Section A
template: "## A"
attestation:
  covers:
    - rendered-doc
'@
            $path = Join-Path $TestDrive 'section-a.yml'
            Set-Content -Path $path -Value $yaml -Encoding utf8
            $file = Get-Item -LiteralPath $path

            $manifest = @{}
            $pipeline = @{
                stages = @(
                    @{ id = 'render'; kind = 'render'; produces = @(@{ id = 'rendered-doc'; kind = 'markdown' }) }
                )
            }
            $result = Test-FsiSigningAttestationConsistency -Manifest $manifest -Pipeline $pipeline -ItemFiles @($file) -Framework 'demo' -RepoRoot $TestDrive
            $result.Warnings | Should -HaveCount 0
        }

        It 'resolves covers entries that match sibling item ids' {
            $yamlA = @'
id: section-a
title: Section A
template: "## A"
attestation:
  covers:
    - section-b
'@
            $yamlB = @'
id: section-b
title: Section B
template: "## B"
'@
            $pathA = Join-Path $TestDrive 'sa.yml'
            $pathB = Join-Path $TestDrive 'sb.yml'
            Set-Content -Path $pathA -Value $yamlA -Encoding utf8
            Set-Content -Path $pathB -Value $yamlB -Encoding utf8
            $files = @((Get-Item $pathA), (Get-Item $pathB))

            $result = Test-FsiSigningAttestationConsistency -Manifest @{} -ItemFiles $files -Framework 'demo' -RepoRoot $TestDrive
            $result.Warnings | Should -HaveCount 0
        }

        It 'resolves an item id against itself' {
            $yaml = @'
id: self
title: Self
template: "## S"
attestation:
  covers:
    - self
'@
            $path = Join-Path $TestDrive 'self.yml'
            Set-Content -Path $path -Value $yaml -Encoding utf8
            $file = Get-Item -LiteralPath $path

            $result = Test-FsiSigningAttestationConsistency -Manifest @{} -ItemFiles @($file) -Framework 'demo' -RepoRoot $TestDrive
            $result.Warnings | Should -HaveCount 0
        }

        It 'warns when a covers entry resolves to nothing' {
            $yaml = @'
id: section-a
title: Section A
template: "## A"
attestation:
  covers:
    - ghost-id
'@
            $path = Join-Path $TestDrive 'orphan.yml'
            Set-Content -Path $path -Value $yaml -Encoding utf8
            $file = Get-Item -LiteralPath $path

            $result = Test-FsiSigningAttestationConsistency -Manifest @{} -ItemFiles @($file) -Framework 'demo' -RepoRoot $TestDrive
            $result.Warnings | Should -HaveCount 1
            $result.Warnings[0] | Should -Match "attestation.covers entry 'ghost-id' does not resolve"
            $result.Warnings[0] | Should -Match "bundle 'demo'"
        }

        It 'emits one warning per unresolved entry' {
            $yaml = @'
id: section-a
title: Section A
template: "## A"
attestation:
  covers:
    - ghost-one
    - ghost-two
    - section-a
'@
            $path = Join-Path $TestDrive 'multi.yml'
            Set-Content -Path $path -Value $yaml -Encoding utf8
            $file = Get-Item -LiteralPath $path

            $result = Test-FsiSigningAttestationConsistency -Manifest @{} -ItemFiles @($file) -Framework 'demo' -RepoRoot $TestDrive
            $result.Warnings | Should -HaveCount 2
            ($result.Warnings -join "`n") | Should -Match 'ghost-one'
            ($result.Warnings -join "`n") | Should -Match 'ghost-two'
        }

        It 'is silent when items have no attestation block' {
            $yaml = @'
id: plain
title: Plain
template: "## P"
'@
            $path = Join-Path $TestDrive 'plain.yml'
            Set-Content -Path $path -Value $yaml -Encoding utf8
            $file = Get-Item -LiteralPath $path

            $result = Test-FsiSigningAttestationConsistency -Manifest @{} -ItemFiles @($file) -Framework 'demo' -RepoRoot $TestDrive
            $result.Errors | Should -HaveCount 0
            $result.Warnings | Should -HaveCount 0
        }
    }

    Context 'output contract' {
        It 'always returns Errors and Warnings arrays' {
            $result = Test-FsiSigningAttestationConsistency -Manifest @{} -Framework 'demo' -RepoRoot $TestDrive
            $result.PSObject.Properties.Name | Should -Contain 'Errors'
            $result.PSObject.Properties.Name | Should -Contain 'Warnings'
            ,$result.Errors | Should -BeOfType ([array])
            ,$result.Warnings | Should -BeOfType ([array])
        }
    }
}
