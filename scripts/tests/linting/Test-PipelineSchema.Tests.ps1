#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../lib/Modules/FrameworkSkillDiscovery.psm1') -Force
    Import-Module powershell-yaml -ErrorAction SilentlyContinue

    $script:RepoRoot = (git -C $PSScriptRoot rev-parse --show-toplevel 2>$null)
    if (-not $script:RepoRoot) { $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path }
    $script:SchemaPath = Join-Path $script:RepoRoot 'scripts/linting/schemas/framework-skill-manifest.schema.json'

    function script:Test-Manifest([string]$Yaml) {
        $data = ConvertFrom-Yaml $Yaml
        $json = $data | ConvertTo-Json -Depth 20
        $errs = $null
        $valid = Test-Json -Json $json -SchemaFile $script:SchemaPath -ErrorVariable errs -ErrorAction SilentlyContinue
        return [pscustomobject]@{ Valid = [bool]$valid; Errors = @($errs | ForEach-Object { $_.ToString() }) }
    }
}

Describe 'Framework Skill manifest pipeline schema' -Tag 'Unit' {
    Context 'manifest without pipeline' {
        It 'still validates' {
            $yaml = @'
framework: demo
version: 0.1.0
summary: demo
domain: demo
itemKind: control
phaseMap:
  default:
    - sample
status: draft
'@
            (Test-Manifest $yaml).Valid | Should -BeTrue
        }
    }

    Context 'well-formed pipeline' {
        It 'accepts a single producer/consumer chain' {
            $yaml = @'
framework: demo
version: 0.1.0
summary: demo
domain: demo
itemKind: control
phaseMap:
  default:
    - sample
status: draft
pipeline:
  stages:
    - id: gather
      kind: gather
      produces:
        - id: raw-data
          kind: yaml
    - id: render
      kind: render
      consumes:
        - raw-data
      produces:
        - id: final-doc
          kind: markdown
'@
            (Test-Manifest $yaml).Valid | Should -BeTrue
        }
    }

    Context 'malformed pipeline' {
        It 'rejects extra properties at stage level' {
            $yaml = @'
framework: demo
version: 0.1.0
summary: demo
domain: demo
itemKind: control
phaseMap:
  default:
    - sample
status: draft
pipeline:
  stages:
    - id: gather
      kind: gather
      bogus: extra
'@
            (Test-Manifest $yaml).Valid | Should -BeFalse
        }

        It 'rejects a stage missing required id' {
            $yaml = @'
framework: demo
version: 0.1.0
summary: demo
domain: demo
itemKind: control
phaseMap:
  default:
    - sample
status: draft
pipeline:
  stages:
    - kind: gather
'@
            (Test-Manifest $yaml).Valid | Should -BeFalse
        }

        It 'rejects a stage missing required kind' {
            $yaml = @'
framework: demo
version: 0.1.0
summary: demo
domain: demo
itemKind: control
phaseMap:
  default:
    - sample
status: draft
pipeline:
  stages:
    - id: gather
'@
            (Test-Manifest $yaml).Valid | Should -BeFalse
        }

        It 'rejects a produces entry that is a bare string' {
            $yaml = @'
framework: demo
version: 0.1.0
summary: demo
domain: demo
itemKind: control
phaseMap:
  default:
    - sample
status: draft
pipeline:
  stages:
    - id: gather
      kind: gather
      produces:
        - raw-data
'@
            (Test-Manifest $yaml).Valid | Should -BeFalse
        }

        It 'rejects empty stages array' {
            $yaml = @'
framework: demo
version: 0.1.0
summary: demo
domain: demo
itemKind: control
phaseMap:
  default:
    - sample
status: draft
pipeline:
  stages: []
'@
            (Test-Manifest $yaml).Valid | Should -BeFalse
        }
    }

    Context 'Get-FsiPipeline accessor' {
        It 'returns the pipeline hashtable when present' {
            $manifest = @{
                framework = 'demo'
                pipeline  = @{ stages = @(@{ id = 'gather'; kind = 'gather' }) }
            }
            $result = Get-FsiPipeline -Manifest $manifest
            $result | Should -Not -BeNullOrEmpty
            $result.stages.Count | Should -Be 1
        }

        It 'returns $null when pipeline is absent' {
            Get-FsiPipeline -Manifest @{ framework = 'demo' } | Should -BeNullOrEmpty
        }
    }
}
