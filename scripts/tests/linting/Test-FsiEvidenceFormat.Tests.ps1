#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../linting/Validate-FsiContent.ps1')
}

Describe 'Test-FsiEvidenceFormat' -Tag 'Unit' {

    Context 'manifest does not declare evidenceFormat' {
        It 'returns no diagnostics regardless of item content' {
            $manifest = @{ framework = 'demo' }
            $itemYaml = @'
id: demo
controls:
- id: c1
  evidenceHints:
  - some/path.md (Lines 1-10)
'@
            $path = Join-Path $TestDrive 'absent.yml'
            Set-Content -Path $path -Value $itemYaml -Encoding utf8
            $file = Get-Item -LiteralPath $path

            $result = Test-FsiEvidenceFormat -Manifest $manifest -ItemFiles @($file) -Framework 'demo' -RepoRoot $TestDrive

            $result.Errors   | Should -HaveCount 0
            $result.Warnings | Should -HaveCount 0
        }
    }

    Context 'manifest declares evidenceFormat=shared and items declare evidenceHints' {
        It 'returns no diagnostics' {
            $manifest = @{ framework = 'demo'; evidenceFormat = 'shared' }
            $itemYaml = @'
id: demo
controls:
- id: c1
  evidenceHints:
  - some/path.md (Lines 1-10)
- id: c2
  evidenceHints:
  - other/file.md (Lines 5-7)
'@
            $path = Join-Path $TestDrive 'shared-with-hints.yml'
            Set-Content -Path $path -Value $itemYaml -Encoding utf8
            $file = Get-Item -LiteralPath $path

            $result = Test-FsiEvidenceFormat -Manifest $manifest -ItemFiles @($file) -Framework 'demo' -RepoRoot $TestDrive

            $result.Errors   | Should -HaveCount 0
            $result.Warnings | Should -HaveCount 0
        }
    }

    Context 'manifest declares an unknown evidenceFormat value' {
        It 'emits EF-01 error' {
            $manifest = @{ framework = 'demo'; evidenceFormat = 'legacy' }
            $itemYaml = @'
id: demo
controls:
- id: c1
  evidenceHints:
  - p.md (Lines 1-2)
'@
            $path = Join-Path $TestDrive 'invalid-value.yml'
            Set-Content -Path $path -Value $itemYaml -Encoding utf8
            $file = Get-Item -LiteralPath $path

            $result = Test-FsiEvidenceFormat -Manifest $manifest -ItemFiles @($file) -Framework 'demo' -RepoRoot $TestDrive

            $result.Errors   | Should -HaveCount 1
            $result.Errors[0] | Should -Match "evidenceFormat 'legacy' is not in allowed set"
            $result.Warnings | Should -HaveCount 0
        }
    }

    Context 'manifest declares evidenceFormat=shared but no items declare evidenceHints' {
        It 'emits EF-03 vacuous-assertion warning' {
            $manifest = @{ framework = 'demo'; evidenceFormat = 'shared' }
            $itemYaml = @'
id: demo
controls:
- id: c1
  title: No hints here
'@
            $path = Join-Path $TestDrive 'vacuous.yml'
            Set-Content -Path $path -Value $itemYaml -Encoding utf8
            $file = Get-Item -LiteralPath $path

            $result = Test-FsiEvidenceFormat -Manifest $manifest -ItemFiles @($file) -Framework 'demo' -RepoRoot $TestDrive

            $result.Errors   | Should -HaveCount 0
            $result.Warnings | Should -HaveCount 1
            $result.Warnings[0] | Should -Match 'vacuous assertion'
        }
    }

    Context 'manifest declares evidenceFormat=shared with mixed items (some without hints)' {
        It 'returns no diagnostics when at least one item declares evidenceHints' {
            $manifest = @{ framework = 'demo'; evidenceFormat = 'shared' }
            $withHints = @'
id: a
controls:
- id: a1
  evidenceHints:
  - some/path.md (Lines 1-3)
'@
            $withoutHints = @'
id: b
controls:
- id: b1
  title: No hints
'@
            $p1 = Join-Path $TestDrive 'a.yml'
            $p2 = Join-Path $TestDrive 'b.yml'
            Set-Content -Path $p1 -Value $withHints -Encoding utf8
            Set-Content -Path $p2 -Value $withoutHints -Encoding utf8

            $result = Test-FsiEvidenceFormat -Manifest $manifest `
                -ItemFiles @((Get-Item -LiteralPath $p1), (Get-Item -LiteralPath $p2)) `
                -Framework 'demo' -RepoRoot $TestDrive

            $result.Errors   | Should -HaveCount 0
            $result.Warnings | Should -HaveCount 0
        }
    }

    Context 'EF-02 lexical glob-path sanity on evidenceHints tokens' {
        It 'accepts well-formed relative glob paths' {
            $manifest = @{ framework = 'demo'; evidenceFormat = 'shared' }
            $itemYaml = @'
id: ok
controls:
- id: c1
  evidenceHints:
  - "**/energy-report.json"
  - ".github/workflows/*.yml"
  - "docs/sustainability/principles/*.md"
  - "scripts/lib/Modules/?ode.psm1"
'@
            $path = Join-Path $TestDrive 'ef02-valid.yml'
            Set-Content -Path $path -Value $itemYaml -Encoding utf8
            $file = Get-Item -LiteralPath $path

            $result = Test-FsiEvidenceFormat -Manifest $manifest -ItemFiles @($file) -Framework 'demo' -RepoRoot $TestDrive

            $result.Errors   | Should -HaveCount 0
            $result.Warnings | Should -HaveCount 0
        }

        It 'rejects absolute paths (leading "/")' {
            $manifest = @{ framework = 'demo'; evidenceFormat = 'shared' }
            $itemYaml = @'
id: abs
controls:
- id: c1
  evidenceHints:
  - "/etc/foo/bar.json"
'@
            $path = Join-Path $TestDrive 'ef02-abs.yml'
            Set-Content -Path $path -Value $itemYaml -Encoding utf8
            $file = Get-Item -LiteralPath $path

            $result = Test-FsiEvidenceFormat -Manifest $manifest -ItemFiles @($file) -Framework 'demo' -RepoRoot $TestDrive

            $result.Errors   | Should -HaveCount 1
            $result.Errors[0] | Should -Match 'leading "/" not allowed'
        }

        It 'rejects ".." path traversal' {
            $manifest = @{ framework = 'demo'; evidenceFormat = 'shared' }
            $itemYaml = @'
id: trav
controls:
- id: c1
  evidenceHints:
  - "../outside/secrets.json"
'@
            $path = Join-Path $TestDrive 'ef02-traversal.yml'
            Set-Content -Path $path -Value $itemYaml -Encoding utf8
            $file = Get-Item -LiteralPath $path

            $result = Test-FsiEvidenceFormat -Manifest $manifest -ItemFiles @($file) -Framework 'demo' -RepoRoot $TestDrive

            $result.Errors   | Should -HaveCount 1
            $result.Errors[0] | Should -Match '"\.\." path segments'
        }

        It 'rejects tokens with leading or trailing whitespace' {
            $manifest = @{ framework = 'demo'; evidenceFormat = 'shared' }
            $itemYaml = @'
id: ws
controls:
- id: c1
  evidenceHints:
  - "  leading.json"
'@
            $path = Join-Path $TestDrive 'ef02-ws.yml'
            Set-Content -Path $path -Value $itemYaml -Encoding utf8
            $file = Get-Item -LiteralPath $path

            $result = Test-FsiEvidenceFormat -Manifest $manifest -ItemFiles @($file) -Framework 'demo' -RepoRoot $TestDrive

            $result.Errors   | Should -HaveCount 1
            $result.Errors[0] | Should -Match 'leading or trailing whitespace'
        }

        It 'emits one EF-02 error per malformed token in a mixed list' {
            $manifest = @{ framework = 'demo'; evidenceFormat = 'shared' }
            $itemYaml = @'
id: mixed
controls:
- id: c1
  evidenceHints:
  - "good/path.json"
  - "/abs/path.json"
  - "../up.json"
'@
            $path = Join-Path $TestDrive 'ef02-mixed.yml'
            Set-Content -Path $path -Value $itemYaml -Encoding utf8
            $file = Get-Item -LiteralPath $path

            $result = Test-FsiEvidenceFormat -Manifest $manifest -ItemFiles @($file) -Framework 'demo' -RepoRoot $TestDrive

            $result.Errors   | Should -HaveCount 2
            ($result.Errors -join "`n") | Should -Match 'leading "/" not allowed'
            ($result.Errors -join "`n") | Should -Match '"\.\." path segments'
        }

        It 'is not enforced when evidenceFormat is absent (back-compat)' {
            $manifest = @{ framework = 'demo' }
            $itemYaml = @'
id: nocheck
controls:
- id: c1
  evidenceHints:
  - "/etc/absolute/ok-when-unasserted.json"
  - "../up.json"
'@
            $path = Join-Path $TestDrive 'ef02-absent.yml'
            Set-Content -Path $path -Value $itemYaml -Encoding utf8
            $file = Get-Item -LiteralPath $path

            $result = Test-FsiEvidenceFormat -Manifest $manifest -ItemFiles @($file) -Framework 'demo' -RepoRoot $TestDrive

            $result.Errors   | Should -HaveCount 0
            $result.Warnings | Should -HaveCount 0
        }
    }
}
