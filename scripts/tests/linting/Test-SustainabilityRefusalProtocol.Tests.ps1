#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:SchemaPath = Resolve-Path (Join-Path $PSScriptRoot '../../linting/schemas/sustainability-state.schema.json')
    $script:DisclaimerPath = Resolve-Path (Join-Path $PSScriptRoot '../../../.github/instructions/shared/disclaimer-language.instructions.md')
    $script:IdentityPath = Resolve-Path (Join-Path $PSScriptRoot '../../../.github/instructions/sustainability/sustainability-identity.instructions.md')

    $script:DisclaimerContent = (Get-Content -Path $script:DisclaimerPath -Raw) -replace "`r`n", "`n"
    $script:IdentityContent = (Get-Content -Path $script:IdentityPath -Raw) -replace "`r`n", "`n"

    function Get-RefusalSectionHash {
        if ($script:DisclaimerContent -notmatch '(?ms)^## Sustainability Out-of-Band Disclosure Refusal\s*\n(.*?)(?=\n## |\z)') {
            throw 'Sustainability Out-of-Band Disclosure Refusal section not found.'
        }
        $body = $matches[1].Trim()
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
        return ([System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join ''
    }

    $script:RefusalParagraph = "This planner produces directional sustainability estimates derived from AI heuristics, public framework data, and user-declared inputs. Requests to generate text for CSRD or ESRS disclosures, SEC climate filings, GHG Protocol corporate inventories, TCFD reports, or ISO 14064 / ISO 14067 attestations fall outside this planner's scope. Route these requests to a qualified sustainability professional and your disclosure-framework counsel; this agent will not generate filing text, attestation language, or audit-grade figures for those frameworks."

    $script:DisclaimerHash = 'e32764641fd2751b9cdff76b326440817b21f5c6132236dc95a66dc4f99f055a'
    $script:ValidStateJson = @"
{
  "meta": {
    "schemaVersion": "1.0.0",
    "slug": "demo",
    "createdAt": "2026-04-22T00:00:00Z",
    "lastUpdatedAt": "2026-04-22T00:00:00Z",
    "disclaimerVersion": "$script:DisclaimerHash"
  },
  "disclaimerShownAt": "2026-04-22T00:00:00Z",
  "phase": "2.workload-assessment",
  "entryMode": "capture",
  "surfaces": ["web"],
  "workloadAssessment": { "capabilities": [], "scope": "demo", "confidence": "low" },
  "standardsMapping": { "activeFrameworks": [], "activeControls": [], "skipped": [] },
  "gapAnalysis": { "verified": [], "partial": [], "absent": [], "manual": [], "measurementInputs": [] },
  "backlog": { "items": [], "sciBudgets": {} },
  "licenseRegister": [],
  "skillsLoadedLogPath": ".copilot-tracking/sustainability-plans/demo/skills-loaded.log",
  "refusalLog": [
    { "turnId": "t-001", "intentSignal": "csrd disclosure text", "atPhase": "2.workload-assessment" }
  ]
}
"@

    $script:InvalidStateJson = @"
{
  "meta": {
    "schemaVersion": "1.0.0",
    "slug": "demo",
    "createdAt": "2026-04-22T00:00:00Z",
    "lastUpdatedAt": "2026-04-22T00:00:00Z",
    "disclaimerVersion": "$script:DisclaimerHash"
  },
  "disclaimerShownAt": "2026-04-22T00:00:00Z",
  "phase": "2.workload-assessment",
  "entryMode": "capture",
  "surfaces": ["web"],
  "workloadAssessment": { "capabilities": [], "scope": "demo", "confidence": "low" },
  "standardsMapping": { "activeFrameworks": [], "activeControls": [], "skipped": [] },
  "gapAnalysis": { "verified": [], "partial": [], "absent": [], "manual": [], "measurementInputs": [] },
  "backlog": { "items": [], "sciBudgets": {} },
  "licenseRegister": [],
  "skillsLoadedLogPath": ".copilot-tracking/sustainability-plans/demo/skills-loaded.log",
  "refusalLog": [
    { "turnId": "t-001", "atPhase": "2.workload-assessment" }
  ]
}
"@
}

Describe 'sustainability refusal protocol' -Tag 'Unit' {
    Context 'disclaimer source-of-truth' {
        It 'contains the verbatim refusal paragraph' {
            $normalized = $script:DisclaimerContent -replace '\s+', ' '
            $expected = $script:RefusalParagraph -replace '\s+', ' '
            $normalized.Contains($expected) | Should -BeTrue
        }

        It 'refusal section hash is stable' {
            $first = Get-RefusalSectionHash
            $second = Get-RefusalSectionHash
            $first | Should -Be $second
            $first | Should -Match '^[a-f0-9]{64}$'
        }
    }

    Context 'identity instructions wiring' {
        It 'references out-of-band framework signals' {
            $script:IdentityContent | Should -Match '(?i)\b(csrd|esrs|sec\s+climate|ghg\s+protocol|tcfd|iso\s+14064|iso\s+14067|audit|attestation|filing)\b'
        }

        It 'references state.refusalLog persistence' {
            $script:IdentityContent.Contains('state.refusalLog') | Should -BeTrue
        }
    }

    Context 'refusalLog schema validation' {
        It 'accepts a state with a valid refusalLog entry' {
            (Test-Json -Json $script:ValidStateJson -SchemaFile $script:SchemaPath -ErrorAction SilentlyContinue) | Should -BeTrue
        }

        It 'rejects a refusalLog entry missing intentSignal' {
            (Test-Json -Json $script:InvalidStateJson -SchemaFile $script:SchemaPath -ErrorAction SilentlyContinue) | Should -BeFalse
        }
    }
}
