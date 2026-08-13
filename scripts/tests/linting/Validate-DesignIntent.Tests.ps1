#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Contract regression tests for the Design Intent schemas and validator.
#>

BeforeAll {
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $script:validator = Join-Path $script:repoRoot 'scripts/linting/Validate-DesignIntent.ps1'
    $script:authoredSchemaPath = Join-Path $script:repoRoot 'scripts/linting/schemas/design-intent.schema.json'
    $script:verificationSchemaPath = Join-Path $script:repoRoot 'scripts/linting/schemas/design-intent-verification.schema.json'
    $script:adequacyMapPath = Join-Path $script:repoRoot '.github/skills/accessibility/accessibility/scripts/runtime_a11y/probe-criteria-map.json'
    $script:fixtureRoot = Join-Path $script:repoRoot 'scripts/tests/fixtures/design-intent/valid-repo'

    Import-Module powershell-yaml -ErrorAction Stop | Out-Null

    function New-FixtureRoot {
        <#
        .SYNOPSIS
            Copies the valid fixture repository into an isolated test root.
        #>
        param([string]$Name)

        $root = Join-Path $TestDrive $Name
        Copy-Item -Path $script:fixtureRoot -Destination $root -Recurse -Force
        return $root
    }

    function Get-AuthoredPath {
        param([string]$Root)
        return Join-Path $Root 'design-intent/valid-surface.intent.yaml'
    }

    function Get-ArtifactPath {
        param([string]$Root)
        return Join-Path $Root 'design-intent/.verification/valid-surface.earl.json'
    }

    function Invoke-Validator {
        <#
        .SYNOPSIS
            Runs the validator through its public interface and returns the parsed report.
        #>
        param(
            [string]$Root,
            [switch]$RequireVerification,
            [string]$AdequacyMapPath
        )

        $reportPath = Join-Path $TestDrive ("report-{0}.json" -f ([guid]::NewGuid()))
        $arguments = @{
            RootPath   = $Root
            OutputPath = $reportPath
        }
        if ($RequireVerification) { $arguments['RequireVerification'] = $true }
        if ($AdequacyMapPath) { $arguments['ProbeCriteriaMapPath'] = $AdequacyMapPath }

        & $script:validator @arguments *>&1 | Out-Null
        $exitCode = $LASTEXITCODE

        $report = if (Test-Path -LiteralPath $reportPath) {
            Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
        }
        else { $null }

        return [pscustomobject]@{
            ExitCode = $exitCode
            Report   = $report
            Codes    = @($report.Issues | ForEach-Object { $_.Code })
        }
    }

    function Set-AuthoredText {
        <#
        .SYNOPSIS
            Applies a literal text substitution to the authored fixture.
        #>
        param([string]$Root, [string]$Pattern, [string]$Replacement)

        $path = Get-AuthoredPath -Root $Root
        $content = Get-Content -LiteralPath $path -Raw
        [System.IO.File]::WriteAllText($path, ($content -replace $Pattern, $Replacement))
    }

    function Set-ArtifactProperty {
        <#
        .SYNOPSIS
            Rewrites the artifact fixture after mutating its parsed form.
        #>
        param([string]$Root, [scriptblock]$Mutate)

        $path = Get-ArtifactPath -Root $Root
        $artifact = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        & $Mutate $artifact
        [System.IO.File]::WriteAllText($path, ($artifact | ConvertTo-Json -Depth 20))
    }
}

Describe 'Design Intent schemas' -Tag 'Unit' {
    It 'Authored schema parses as JSON' {
        { Get-Content -LiteralPath $script:authoredSchemaPath -Raw | ConvertFrom-Json } | Should -Not -Throw
    }

    It 'Verification schema parses as JSON' {
        { Get-Content -LiteralPath $script:verificationSchemaPath -Raw | ConvertFrom-Json } | Should -Not -Throw
    }

    It 'Authored fixture conforms to the authored schema' {
        $schema = Get-Content -LiteralPath $script:authoredSchemaPath -Raw
        $record = ConvertFrom-Yaml -Yaml (Get-Content -LiteralPath (Get-AuthoredPath -Root $script:fixtureRoot) -Raw) -Ordered
        Test-Json -Json ($record | ConvertTo-Json -Depth 20) -Schema $schema | Should -BeTrue
    }

    It 'Generated runtime authored schema is byte-identical after synchronization' {
        $runtimeSchemaPath = Join-Path $script:repoRoot '.github/skills/accessibility/accessibility/scripts/runtime_a11y/design-intent.schema.json'
        if (-not (Test-Path -LiteralPath $runtimeSchemaPath -PathType Leaf)) {
            Set-ItResult -Skipped -Because 'generated runtime schema copy has not been synchronized yet'
            return
        }

        (Get-FileHash -LiteralPath $runtimeSchemaPath -Algorithm SHA256).Hash |
            Should -Be (Get-FileHash -LiteralPath $script:authoredSchemaPath -Algorithm SHA256).Hash
    }

    It 'Artifact fixture conforms to the verification schema' {
        $schema = Get-Content -LiteralPath $script:verificationSchemaPath -Raw
        $json = Get-Content -LiteralPath (Get-ArtifactPath -Root $script:fixtureRoot) -Raw
        Test-Json -Json $json -Schema $schema | Should -BeTrue
    }

    It 'Rejects unsupported <Kind> schema version' -ForEach @(
        @{ Kind = 'authored' }
        @{ Kind = 'verification' }
    ) {
        if ($Kind -eq 'authored') {
            $schema = Get-Content -LiteralPath $script:authoredSchemaPath -Raw
            $document = ConvertFrom-Yaml -Yaml (Get-Content -LiteralPath (Get-AuthoredPath -Root $script:fixtureRoot) -Raw) -Ordered
        }
        else {
            $schema = Get-Content -LiteralPath $script:verificationSchemaPath -Raw
            $document = Get-Content -LiteralPath (Get-ArtifactPath -Root $script:fixtureRoot) -Raw | ConvertFrom-Json
        }
        $document.schemaVersion = '2.0'

        Test-Json -Json ($document | ConvertTo-Json -Depth 20) -Schema $schema -ErrorAction SilentlyContinue |
            Should -BeFalse
    }

    It 'Authored schema assert enum matches the current runtime probe vocabulary' {
        $schema = Get-Content -LiteralPath $script:authoredSchemaPath -Raw | ConvertFrom-Json
        $enum = @($schema.'$defs'.expectation.properties.assert.enum) | Where-Object { $_ -ne 'custom' }
        $map = Get-Content -LiteralPath $script:adequacyMapPath -Raw | ConvertFrom-Json
        $probeIds = @($map.probes | ForEach-Object { $_.probeId })

        $missing = @($probeIds | Where-Object { $enum -notcontains $_ })
        $extra = @($enum | Where-Object { $probeIds -notcontains $_ })

        if ($missing.Count -gt 0 -or $extra.Count -gt 0) {
            throw ("Probe vocabulary drift. Missing from schema: $($missing -join ', '). " +
                "Absent from probe-criteria-map.json: $($extra -join ', '). " +
                'Reconcile the vocabulary and bump the schemaVersion before shipping the change.')
        }
    }
}

Describe 'Design Intent validator accepts valid input' -Tag 'Unit' {
    It 'Passes source-only validation for the fixture repository' {
        $result = Invoke-Validator -Root (New-FixtureRoot -Name 'source-only')
        $result.ExitCode | Should -Be 0
        $result.Report.Status | Should -Be 'passed'
        $result.Report.FilesChecked.Count | Should -Be 2
    }

    It 'Passes strict validation for the fixture repository' {
        $result = Invoke-Validator -Root (New-FixtureRoot -Name 'strict') -RequireVerification
        $result.ExitCode | Should -Be 0
        $result.Report.Mode | Should -Be 'require-verification'
    }

    It 'Treats an absent design-intent directory as a successful no-op' {
        $root = Join-Path $TestDrive 'empty-repo'
        New-Item -Path $root -ItemType Directory -Force | Out-Null
        $result = Invoke-Validator -Root $root -RequireVerification
        $result.ExitCode | Should -Be 0
        $result.Report.FilesChecked.Count | Should -Be 0
    }

    It 'Accepts an authored record with no artifact in source-only mode' {
        $root = New-FixtureRoot -Name 'no-artifact-source'
        Remove-Item -LiteralPath (Get-ArtifactPath -Root $root) -Force
        (Invoke-Validator -Root $root).ExitCode | Should -Be 0
    }

    It 'Accepts a proposed record with no artifact under RequireVerification' {
        $root = New-FixtureRoot -Name 'proposed'
        Remove-Item -LiteralPath (Get-ArtifactPath -Root $root) -Force
        Set-AuthoredText -Root $root -Pattern 'status: accepted' -Replacement 'status: proposed'
        (Invoke-Validator -Root $root -RequireVerification).ExitCode | Should -Be 0
    }

    It 'Accepts a retired record with no artifact under RequireVerification' {
        $root = New-FixtureRoot -Name 'retired'
        Remove-Item -LiteralPath (Get-ArtifactPath -Root $root) -Force
        Set-AuthoredText -Root $root -Pattern 'status: accepted' -Replacement 'status: retired'
        (Invoke-Validator -Root $root -RequireVerification).ExitCode | Should -Be 0
    }

    It 'Produces the same digest verdict for CRLF and LF checkouts' {
        $root = New-FixtureRoot -Name 'crlf'
        $path = Get-AuthoredPath -Root $root
        $lfContent = (Get-Content -LiteralPath $path -Raw) -replace "`r`n", "`n"
        [System.IO.File]::WriteAllText($path, ($lfContent -replace "`n", "`r`n"))

        (Get-Content -LiteralPath $path -Raw) | Should -Match "`r`n"
        (Invoke-Validator -Root $root -RequireVerification).ExitCode | Should -Be 0
    }
}

Describe 'Design Intent validator rejects authored violations' -Tag 'Unit' {
    It 'Rejects a duplicate YAML mapping key before conversion' {
        $root = New-FixtureRoot -Name 'duplicate-key'
        Set-AuthoredText -Root $root -Pattern 'owner: Design Systems Guild' -Replacement "owner: Design Systems Guild`nowner: Someone Else"
        $result = Invoke-Validator -Root $root
        $result.ExitCode | Should -Be 1
        $result.Codes | Should -Contain 'duplicate-yaml-key'
    }

    It 'Rejects YAML that does not parse to a mapping' {
        $root = New-FixtureRoot -Name 'not-a-mapping'
        [System.IO.File]::WriteAllText((Get-AuthoredPath -Root $root), "- just`n- a list`n")
        (Invoke-Validator -Root $root).Codes | Should -Contain 'yaml-parse-error'
    }

    It 'Rejects an unknown authored field' {
        $root = New-FixtureRoot -Name 'unknown-field'
        Set-AuthoredText -Root $root -Pattern 'version: 2' -Replacement "version: 2`nunexpectedField: copied criterion text"
        (Invoke-Validator -Root $root).Codes | Should -Contain 'schema-violation'
    }

    It 'Rejects an impossible decidedOn date that satisfies the schema pattern' {
        $root = New-FixtureRoot -Name 'impossible-date'
        Set-AuthoredText -Root $root -Pattern '"2026-07-14"' -Replacement '"2026-02-30"'
        (Invoke-Validator -Root $root).Codes | Should -Contain 'invalid-date'
    }

    It 'Rejects an impossible override reviewedOn date' {
        $root = New-FixtureRoot -Name 'impossible-review-date'
        Set-AuthoredText -Root $root -Pattern '"2026-07-20"' -Replacement '"2026-13-01"'
        (Invoke-Validator -Root $root).Codes | Should -Contain 'invalid-date'
    }

    It 'Rejects a surfaceId that does not match the filename stem' {
        $root = New-FixtureRoot -Name 'filename-mismatch'
        Set-AuthoredText -Root $root -Pattern 'surfaceId: valid-surface' -Replacement 'surfaceId: other-surface'
        (Invoke-Validator -Root $root).Codes | Should -Contain 'filename-binding'
    }

    It 'Rejects a surface absent from the runtime configuration' {
        $root = New-FixtureRoot -Name 'unknown-surface'
        Set-AuthoredText -Root $root -Pattern 'surfaceId: valid-surface' -Replacement 'surfaceId: ghost-surface'
        Rename-Item -LiteralPath (Get-AuthoredPath -Root $root) -NewName 'ghost-surface.intent.yaml'
        Remove-Item -LiteralPath (Get-ArtifactPath -Root $root) -Force
        (Invoke-Validator -Root $root).Codes | Should -Contain 'unknown-surface'
    }

    It 'Rejects a bound state the surface does not declare' {
        $root = New-FixtureRoot -Name 'undeclared-state'
        Set-AuthoredText -Root $root -Pattern 'state: error' -Replacement 'state: collapsed'
        (Invoke-Validator -Root $root).Codes | Should -Contain 'undeclared-state'
    }

    It 'Rejects duplicate intent identifiers' {
        $root = New-FixtureRoot -Name 'duplicate-intent'
        Set-AuthoredText -Root $root -Pattern 'id: INT-002' -Replacement 'id: INT-001'
        (Invoke-Validator -Root $root).Codes | Should -Contain 'duplicate-intent-id'
    }

    It 'Rejects duplicate expectation identifiers' {
        $root = New-FixtureRoot -Name 'duplicate-expectation'
        Set-AuthoredText -Root $root -Pattern 'id: EXP-002' -Replacement 'id: EXP-001'
        (Invoke-Validator -Root $root).Codes | Should -Contain 'duplicate-expectation-id'
    }

    It 'Rejects an assertion token that is not a current runtime probe' {
        $root = New-FixtureRoot -Name 'unknown-probe'
        Set-AuthoredText -Root $root -Pattern 'assert: probe-focus-visible' -Replacement 'assert: probe-invented'
        (Invoke-Validator -Root $root).Codes | Should -Contain 'schema-violation'
    }

    It 'Rejects a probe paired with the wrong method' {
        $root = New-FixtureRoot -Name 'probe-method'
        Set-AuthoredText -Root $root -Pattern 'method: axe-auto\s+assert: probe-axe' -Replacement "method: runtime-automation`n        assert: probe-axe"
        (Invoke-Validator -Root $root).Codes | Should -Contain 'schema-violation'
    }

    It 'Rejects a deciding claim the probe does not support in the bound state' {
        $root = New-FixtureRoot -Name 'inadequate-deciding'
        Set-AuthoredText -Root $root -Pattern '          - wcag-22:1\.4\.11\n        role: informs\n        blocking: false' -Replacement "          - wcag-22:1.4.11`n        role: decides`n        blocking: true"
        (Invoke-Validator -Root $root).Codes | Should -Contain 'inadequate-deciding-claim'
    }

    It 'Rejects an informing criterion the probe neither decides nor informs' {
        $root = New-FixtureRoot -Name 'unsupported-criterion'
        Set-AuthoredText -Root $root -Pattern '- wcag-22:1\.4\.11' -Replacement '- wcag-22:1.2.4'
        (Invoke-Validator -Root $root).Codes | Should -Contain 'unsupported-criterion'
    }

    It 'Rejects an informing expectation marked blocking' {
        $root = New-FixtureRoot -Name 'informing-blocker'
        Set-AuthoredText -Root $root -Pattern 'role: informs\n        blocking: false' -Replacement "role: informs`n        blocking: true"
        (Invoke-Validator -Root $root).Codes | Should -Contain 'schema-violation'
    }

    It 'Accepts a custom deciding expectation without a review for uncovered gating' {
        $root = New-FixtureRoot -Name 'custom-deciding'
        Set-AuthoredText -Root $root -Pattern 'assert: custom\n        detail: A reviewer walks the summary aloud and confirms the reading order matches the visual grouping\.\n        criteria:\n          - wcag-22:1\.3\.2\n        role: informs\n        blocking: false' -Replacement "assert: custom`n        detail: A reviewer walks the summary aloud.`n        criteria:`n          - wcag-22:1.3.2`n        role: decides`n        blocking: true"
        (Invoke-Validator -Root $root).Codes | Should -Not -Contain 'schema-violation'
    }
}

Describe 'Design Intent validator rejects verification violations' -Tag 'Unit' {
    It 'Rejects a stale digest' {
        $root = New-FixtureRoot -Name 'stale-digest'
        Set-AuthoredText -Root $root -Pattern 'title: Checkout summary panel' -Replacement 'title: Checkout summary panel revised'
        (Invoke-Validator -Root $root).Codes | Should -Contain 'stale-digest'
    }

    It 'Rejects an invalid digest syntax at the schema layer' {
        $root = New-FixtureRoot -Name 'digest-syntax'
        Set-ArtifactProperty -Root $root -Mutate { param($a) $a.intentDigest = 'sha256:NOTHEX' }
        (Invoke-Validator -Root $root).Codes | Should -Contain 'schema-violation'
    }

    It 'Rejects a timestamp that is not RFC 3339' {
        $root = New-FixtureRoot -Name 'bad-timestamp'
        $path = Get-ArtifactPath -Root $root
        $json = (Get-Content -LiteralPath $path -Raw) -replace '"2026-07-21T09:15:00Z"', '"July 21 2026"'
        [System.IO.File]::WriteAllText($path, $json)
        (Invoke-Validator -Root $root).Codes | Should -Contain 'invalid-timestamp'
    }

    It 'Rejects an assertion that does not resolve to a current expectation' {
        $root = New-FixtureRoot -Name 'unresolved'
        Set-ArtifactProperty -Root $root -Mutate { param($a) $a.assertions[0].expectationId = 'EXP-999' }
        $codes = (Invoke-Validator -Root $root).Codes
        $codes | Should -Contain 'unresolved-assertion'
        $codes | Should -Contain 'incomplete-coverage'
    }

    It 'Rejects a duplicate assertion pair' {
        $root = New-FixtureRoot -Name 'duplicate-assertion'
        Set-ArtifactProperty -Root $root -Mutate { param($a) $a.assertions[1].expectationId = 'EXP-001' }
        (Invoke-Validator -Root $root).Codes | Should -Contain 'duplicate-assertion'
    }

    It 'Rejects incomplete assertion coverage' {
        $root = New-FixtureRoot -Name 'incomplete'
        Set-ArtifactProperty -Root $root -Mutate { param($a) $a.assertions = @($a.assertions[0..3]) }
        (Invoke-Validator -Root $root).Codes | Should -Contain 'incomplete-coverage'
    }

    It 'Rejects an inapplicable outcome without machine detail' {
        $root = New-FixtureRoot -Name 'inapplicable'
        Set-ArtifactProperty -Root $root -Mutate { param($a) $a.assertions[4].info = $null }
        (Invoke-Validator -Root $root).Codes | Should -Contain 'schema-violation'
    }

    It 'Rejects an unknown field in the verification artifact' {
        $root = New-FixtureRoot -Name 'artifact-unknown-field'
        Set-ArtifactProperty -Root $root -Mutate {
            param($a) $a | Add-Member -NotePropertyName 'reviewedBy' -NotePropertyValue 'A. Human'
        }
        (Invoke-Validator -Root $root).Codes | Should -Contain 'schema-violation'
    }

    It 'Rejects an artifact whose surfaceId disagrees with its filename' {
        $root = New-FixtureRoot -Name 'artifact-filename'
        Set-ArtifactProperty -Root $root -Mutate { param($a) $a.surfaceId = 'other-surface' }
        (Invoke-Validator -Root $root).Codes | Should -Contain 'filename-binding'
    }

    It 'Rejects an artifact that does not parse as JSON' {
        $root = New-FixtureRoot -Name 'artifact-parse'
        [System.IO.File]::WriteAllText((Get-ArtifactPath -Root $root), '{ not json')
        (Invoke-Validator -Root $root).Codes | Should -Contain 'json-parse-error'
    }

    It 'Rejects an artifact with no corresponding authored record' {
        $root = New-FixtureRoot -Name 'orphan'
        Remove-Item -LiteralPath (Get-AuthoredPath -Root $root) -Force
        (Invoke-Validator -Root $root).Codes | Should -Contain 'orphan-artifact'
    }

    It 'Rejects an accepted record without an artifact under RequireVerification' {
        $root = New-FixtureRoot -Name 'missing-verification'
        Remove-Item -LiteralPath (Get-ArtifactPath -Root $root) -Force
        (Invoke-Validator -Root $root -RequireVerification).Codes | Should -Contain 'missing-verification'
    }
}

Describe 'Design Intent validator fails closed on unusable inputs' -Tag 'Unit' {
    It 'Fails closed when the probe adequacy map is missing' {
        $root = New-FixtureRoot -Name 'adequacy-missing'
        $result = Invoke-Validator -Root $root -AdequacyMapPath (Join-Path $TestDrive 'absent-map.json')
        $result.ExitCode | Should -Be 1
        $result.Codes | Should -Contain 'adequacy-map-unavailable'
    }

    It 'Fails closed when the probe adequacy map is unreadable' {
        $root = New-FixtureRoot -Name 'adequacy-unreadable'
        $mapPath = Join-Path $TestDrive 'broken-map.json'
        [System.IO.File]::WriteAllText($mapPath, '{ "probes": ')
        (Invoke-Validator -Root $root -AdequacyMapPath $mapPath).Codes | Should -Contain 'adequacy-map-unavailable'
    }

    It 'Fails closed when the probe adequacy map has no probes array' {
        $root = New-FixtureRoot -Name 'adequacy-shape'
        $mapPath = Join-Path $TestDrive 'shapeless-map.json'
        [System.IO.File]::WriteAllText($mapPath, '{ "somethingElse": [] }')
        (Invoke-Validator -Root $root -AdequacyMapPath $mapPath).Codes | Should -Contain 'adequacy-map-unavailable'
    }

    It 'Fails closed when the probe adequacy map declares no probes' {
        $root = New-FixtureRoot -Name 'adequacy-empty'
        $mapPath = Join-Path $TestDrive 'empty-map.json'
        [System.IO.File]::WriteAllText($mapPath, '{ "probes": [] }')
        (Invoke-Validator -Root $root -AdequacyMapPath $mapPath).Codes | Should -Contain 'adequacy-map-unavailable'
    }

    It 'Fails closed when a probe entry has no probeId' {
        $root = New-FixtureRoot -Name 'adequacy-no-id'
        $mapPath = Join-Path $TestDrive 'no-id-map.json'
        [System.IO.File]::WriteAllText($mapPath, '{ "probes": [ { "decides": [] } ] }')
        (Invoke-Validator -Root $root -AdequacyMapPath $mapPath).Codes | Should -Contain 'adequacy-map-unavailable'
    }

    It 'Fails when authored records exist without a runtime configuration' {
        $root = New-FixtureRoot -Name 'no-runtime-config'
        Remove-Item -LiteralPath (Join-Path $root 'a11y-runtime.config.json') -Force
        (Invoke-Validator -Root $root).Codes | Should -Contain 'missing-runtime-config'
    }

    It 'Fails when the runtime configuration is unreadable' {
        $root = New-FixtureRoot -Name 'broken-runtime-config'
        [System.IO.File]::WriteAllText((Join-Path $root 'a11y-runtime.config.json'), '{ "surfaces": ')
        (Invoke-Validator -Root $root).Codes | Should -Contain 'unreadable-runtime-config'
    }

    It 'Fails when RootPath is not a directory' {
        & $script:validator -RootPath (Join-Path $TestDrive 'does-not-exist') -ErrorAction SilentlyContinue *>&1 | Out-Null
        $LASTEXITCODE | Should -Be 2
    }
}
