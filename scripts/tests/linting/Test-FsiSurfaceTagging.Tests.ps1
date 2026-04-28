#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../linting/Validate-FsiContent.ps1')
}

Describe 'Test-FsiSurfaceTagging' -Tag 'Unit' {

    Context 'manifest declares surfaceFilter and item appliesTo is a subset' {
        It 'passes without errors or warnings' {
            $manifest = @{
                framework     = 'demo'
                surfaceFilter = @('cloud', 'web', 'ml', 'fleet')
            }
            $itemYaml = @'
id: demo
controls:
- id: low-carbon-region
  appliesTo: [cloud]
  measurementClass: estimated
  sciVariable: I
'@
            $path = Join-Path $TestDrive 'item-pass.yml'
            Set-Content -Path $path -Value $itemYaml -Encoding utf8
            $file = Get-Item -LiteralPath $path

            $result = Test-FsiSurfaceTagging -Manifest $manifest -ItemFiles @($file) -Framework 'demo' -RepoRoot $TestDrive

            $result.Errors   | Should -HaveCount 0
            $result.Warnings | Should -HaveCount 0
        }
    }

    Context 'manifest omits surfaceFilter' {
        It 'permits items without appliesTo' {
            $manifest = @{ framework = 'demo' }
            $itemYaml = @'
id: demo
controls:
- id: codeql
  title: CodeQL
'@
            $path = Join-Path $TestDrive 'item-no-filter.yml'
            Set-Content -Path $path -Value $itemYaml -Encoding utf8
            $file = Get-Item -LiteralPath $path

            $result = Test-FsiSurfaceTagging -Manifest $manifest -ItemFiles @($file) -Framework 'demo' -RepoRoot $TestDrive

            $result.Errors   | Should -HaveCount 0
            $result.Warnings | Should -HaveCount 0
        }
    }

    Context 'item appliesTo value not in surfaceFilter' {
        It 'emits an error' {
            $manifest = @{ framework = 'demo'; surfaceFilter = @('cloud', 'web') }
            $itemYaml = @'
id: demo
controls:
- id: ml-only
  appliesTo: [ml]
'@
            $path = Join-Path $TestDrive 'item-out-of-filter.yml'
            Set-Content -Path $path -Value $itemYaml -Encoding utf8
            $file = Get-Item -LiteralPath $path

            $result = Test-FsiSurfaceTagging -Manifest $manifest -ItemFiles @($file) -Framework 'demo' -RepoRoot $TestDrive

            $result.Errors.Count | Should -BeGreaterThan 0
            ($result.Errors -join "`n") | Should -Match "appliesTo value 'ml'"
        }
    }

    Context 'manifest has surfaceFilter but item omits appliesTo' {
        It 'emits an error' {
            $manifest = @{ framework = 'demo'; surfaceFilter = @('cloud', 'web', 'ml', 'fleet') }
            $itemYaml = @'
id: demo
controls:
- id: missing-applies-to
  title: No surfaces tagged
'@
            $path = Join-Path $TestDrive 'item-missing.yml'
            Set-Content -Path $path -Value $itemYaml -Encoding utf8
            $file = Get-Item -LiteralPath $path

            $result = Test-FsiSurfaceTagging -Manifest $manifest -ItemFiles @($file) -Framework 'demo' -RepoRoot $TestDrive

            $result.Errors.Count | Should -BeGreaterThan 0
            ($result.Errors -join "`n") | Should -Match 'appliesTo is required'
        }
    }

    Context 'invalid sciVariable' {
        It 'emits an error' {
            $manifest = @{ framework = 'demo' }
            $itemYaml = @'
id: demo
controls:
- id: bad-sci
  sciVariable: Z
'@
            $path = Join-Path $TestDrive 'item-bad-sci.yml'
            Set-Content -Path $path -Value $itemYaml -Encoding utf8
            $file = Get-Item -LiteralPath $path

            $result = Test-FsiSurfaceTagging -Manifest $manifest -ItemFiles @($file) -Framework 'demo' -RepoRoot $TestDrive

            ($result.Errors -join "`n") | Should -Match "sciVariable 'Z'"
        }
    }

    Context 'invalid measurementClass' {
        It 'emits an error' {
            $manifest = @{ framework = 'demo' }
            $itemYaml = @'
id: demo
controls:
- id: bad-mc
  measurementClass: speculative
'@
            $path = Join-Path $TestDrive 'item-bad-mc.yml'
            Set-Content -Path $path -Value $itemYaml -Encoding utf8
            $file = Get-Item -LiteralPath $path

            $result = Test-FsiSurfaceTagging -Manifest $manifest -ItemFiles @($file) -Framework 'demo' -RepoRoot $TestDrive

            ($result.Errors -join "`n") | Should -Match "measurementClass 'speculative'"
        }
    }

    Context 'malformed appliesToPrinciples reference' {
        It 'emits an error' {
            $manifest = @{ framework = 'demo' }
            $itemYaml = @'
id: demo
controls:
- id: bad-ref
  appliesToPrinciples:
    - not-a-valid-ref
'@
            $path = Join-Path $TestDrive 'item-bad-ref.yml'
            Set-Content -Path $path -Value $itemYaml -Encoding utf8
            $file = Get-Item -LiteralPath $path

            $result = Test-FsiSurfaceTagging -Manifest $manifest -ItemFiles @($file) -Framework 'demo' -RepoRoot $TestDrive

            ($result.Errors -join "`n") | Should -Match 'appliesToPrinciples entry'
        }
    }

    Context 'capability-inventory back-fill audit' {
        It 'all hve-core capability-inventory items declare appliesTo' {
            $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '../../..')
            $itemsDir = Join-Path $repoRoot '.github/skills/security/capability-inventory-hve-core/items'
            $files = Get-ChildItem -LiteralPath $itemsDir -Filter '*.yml' -File
            $files.Count | Should -BeGreaterThan 0
            foreach ($f in $files) {
                $content = Get-Content -LiteralPath $f.FullName -Raw -Encoding utf8
                $content | Should -Match 'appliesTo: \[cloud, web, ml, fleet\]' -Because "Step 1.4 atomic back-fill must cover $($f.Name)"
            }
        }

        It 'all physical-ai capability-inventory items declare appliesTo' {
            $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '../../..')
            $itemsDir = Join-Path $repoRoot '.github/skills/security/capability-inventory-physical-ai/items'
            $files = Get-ChildItem -LiteralPath $itemsDir -Filter '*.yml' -File
            $files.Count | Should -BeGreaterThan 0
            foreach ($f in $files) {
                $content = Get-Content -LiteralPath $f.FullName -Raw -Encoding utf8
                $content | Should -Match 'appliesTo: \[cloud, web, ml, fleet\]' -Because "Step 1.4 atomic back-fill must cover $($f.Name)"
            }
        }
    }
}
