#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '../../linting/Validate-PlannerArtifacts.ps1'
    . $scriptPath
}

Describe 'Find-EvidenceCitationViolationsInContent' {
    It 'emits no warning when verified row includes a (Lines N-M) span' {
        $content = @'
## Evidence Table

| Control | Verdict  | Evidence                                        |
| ------- | -------- | ----------------------------------------------- |
| C-01    | Verified | `path/to/file.md` (Lines 12-18) — anchor lookup |
'@
        $warnings = Find-EvidenceCitationViolationsInContent -Content $content -FilePath 'sample.md'
        @($warnings).Count | Should -Be 0
    }

    It 'emits a warning when verified row lacks span and lacks kind qualifier' {
        $content = @'
## Evidence Table

| Control | Verdict  | Evidence                            |
| ------- | -------- | ----------------------------------- |
| C-02    | Verified | `path/to/file.md` — anchor lookup   |
'@
        $warnings = @(Find-EvidenceCitationViolationsInContent -Content $content -FilePath 'sample.md')
        $warnings.Count | Should -Be 1
        $warnings[0].file | Should -Be 'sample.md'
        $warnings[0].verdict | Should -Be 'verified'
        $warnings[0].rowIndex | Should -Be 1
        $warnings[0].tableHeading | Should -Be 'Evidence Table'
    }

    It 'emits no warning when verified row uses a kind: live-endpoint qualifier without a line span' {
        $content = @'
## Evidence Table

| Control | Verdict  | Evidence                                                 |
| ------- | -------- | -------------------------------------------------------- |
| C-03    | Verified | kind: live-endpoint https://example.com/health — checked |
'@
        $warnings = Find-EvidenceCitationViolationsInContent -Content $content -FilePath 'sample.md'
        @($warnings).Count | Should -Be 0
    }

    It 'emits no warning when verdict is not verified or partial' {
        $content = @'
## Evidence Table

| Control | Verdict | Evidence              |
| ------- | ------- | --------------------- |
| C-04    | Pending | TBD                   |
'@
        $warnings = Find-EvidenceCitationViolationsInContent -Content $content -FilePath 'sample.md'
        @($warnings).Count | Should -Be 0
    }

    It 'emits a warning for a partial row missing both span and kind qualifier' {
        $content = @'
## Evidence Table

| Control | Verdict | Evidence                |
| ------- | ------- | ----------------------- |
| C-05    | Partial | rationale only, no span |
'@
        $warnings = @(Find-EvidenceCitationViolationsInContent -Content $content -FilePath 'sample.md')
        $warnings.Count | Should -Be 1
        $warnings[0].verdict | Should -Be 'partial'
    }

    It 'ignores tables that do not have both Verdict and Evidence columns' {
        $content = @'
## Other Table

| Name | Status |
| ---- | ------ |
| Item | Verified without evidence column |
'@
        $warnings = Find-EvidenceCitationViolationsInContent -Content $content -FilePath 'sample.md'
        @($warnings).Count | Should -Be 0
    }

    It 'detects header variant "Verdict (FY26)" with "Source" evidence column' {
        $content = @'
## Evidence Table

| Control | Verdict (FY26) | Source                                 |
| ------- | -------------- | -------------------------------------- |
| C-10    | Verified       | `path/to/file.md` (Lines 1-5) — anchor |
'@
        $warnings = Find-EvidenceCitationViolationsInContent -Content $content -FilePath 'sample.md'
        @($warnings).Count | Should -Be 0
    }

    It 'detects header variant "Source Reference" as evidence column' {
        $content = @'
## Evidence Table

| Control | Verdict  | Source Reference                       |
| ------- | -------- | -------------------------------------- |
| C-11    | Verified | `path/to/file.md` (Lines 1-5) — anchor |
'@
        $warnings = Find-EvidenceCitationViolationsInContent -Content $content -FilePath 'sample.md'
        @($warnings).Count | Should -Be 0
    }

    It 'detects header variant "Sources" as evidence column' {
        $content = @'
## Evidence Table

| Control | Verdict  | Sources                                |
| ------- | -------- | -------------------------------------- |
| C-12    | Verified | `path/to/file.md` (Lines 1-5) — anchor |
'@
        $warnings = Find-EvidenceCitationViolationsInContent -Content $content -FilePath 'sample.md'
        @($warnings).Count | Should -Be 0
    }

    It 'emits no warning when evidence cell uses concrete file path with no glob' {
        $content = @'
## Evidence Table

| Control | Verdict  | Evidence                                       |
| ------- | -------- | ---------------------------------------------- |
| C-20    | Verified | `policies/access.md` (Lines 1-10) — anchor     |
'@
        $warnings = Find-EvidenceCitationViolationsInContent -Content $content -FilePath 'sample.md'
        @($warnings).Count | Should -Be 0
    }

    It 'emits a warning when evidence cell copies a glob pattern verbatim' {
        $content = @'
## Evidence Table

| Control | Verdict  | Evidence                                  |
| ------- | -------- | ----------------------------------------- |
| C-21    | Verified | `policies/**/*.md` (Lines 1-10) — broad   |
'@
        $warnings = @(Find-EvidenceCitationViolationsInContent -Content $content -FilePath 'sample.md')
        $warnings.Count | Should -BeGreaterOrEqual 1
        ($warnings | Where-Object { $_.reason -match 'glob' }).Count | Should -BeGreaterOrEqual 1
    }

    It 'emits no warning when external-doc row cites a real file path with span' {
        $content = @'
## Evidence Table

| Control | Verdict  | Evidence                                                            |
| ------- | -------- | ------------------------------------------------------------------- |
| C-30    | Verified | kind: external-doc `vendor/standard.md` (Lines 1-5) — pinned excerpt |
'@
        $warnings = Find-EvidenceCitationViolationsInContent -Content $content -FilePath 'sample.md'
        @($warnings).Count | Should -Be 0
    }

    It 'emits a warning when external-doc row uses a badge image as inferred verification' {
        $content = @'
## Evidence Table

| Control | Verdict  | Evidence                                                                                |
| ------- | -------- | --------------------------------------------------------------------------------------- |
| C-31    | Verified | kind: external-doc ![build](https://img.shields.io/github/actions/workflow/build.svg) |
'@
        $warnings = @(Find-EvidenceCitationViolationsInContent -Content $content -FilePath 'sample.md')
        $warnings.Count | Should -BeGreaterOrEqual 1
        ($warnings | Where-Object { $_.reason -match 'badge' }).Count | Should -BeGreaterOrEqual 1
    }
}

Describe 'Find-EvidenceCitationViolations' {
    BeforeAll {
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "EvidenceCitationTests_$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null

        $script:CompliantPath = Join-Path $script:TempDir 'compliant.md'
        @'
## Evidence

| Control | Verdict  | Evidence                                  |
| ------- | -------- | ----------------------------------------- |
| C-01    | Verified | `policy.md` (Lines 5-10) — anchor lookup  |
'@ | Set-Content -LiteralPath $script:CompliantPath -Encoding UTF8

        $script:ViolatingPath = Join-Path $script:TempDir 'violating.md'
        @'
## Evidence

| Control | Verdict  | Evidence              |
| ------- | -------- | --------------------- |
| C-02    | Verified | `policy.md` — no span |
'@ | Set-Content -LiteralPath $script:ViolatingPath -Encoding UTF8

        $script:OutputPath = Join-Path $script:TempDir 'results.json'
    }

    AfterAll {
        if (Test-Path -LiteralPath $script:TempDir) {
            Remove-Item -LiteralPath $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'aggregates warnings across files and writes a JSON report' {
        $result = Find-EvidenceCitationViolations -Roots @($script:TempDir) -OutputPath $script:OutputPath
        $result.TotalWarnings | Should -Be 1
        Test-Path -LiteralPath $script:OutputPath | Should -BeTrue
        $payload = Get-Content -LiteralPath $script:OutputPath -Raw | ConvertFrom-Json
        $payload.totalWarnings | Should -Be 1
        $payload.warnings[0].verdict | Should -Be 'verified'
    }

    It 'returns zero warnings when given a root that does not exist' {
        $emptyOut = Join-Path $script:TempDir 'empty.json'
        $missingRoot = Join-Path $script:TempDir 'does-not-exist'
        $result = Find-EvidenceCitationViolations -Roots @($missingRoot) -OutputPath $emptyOut
        $result.TotalWarnings | Should -Be 0
    }
}
