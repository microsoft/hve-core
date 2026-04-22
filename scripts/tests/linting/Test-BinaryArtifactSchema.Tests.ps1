#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
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

    $script:BaseManifest = @'
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
}

Describe 'Framework Skill manifest binary artifact cleanup field' -Tag 'Unit' {
    Context 'cleanup enum' {
        It 'accepts cleanup: ephemeral on a binary producer' {
            $yaml = $script:BaseManifest + @'

pipeline:
  stages:
    - id: render
      kind: render
      produces:
        - id: deck
          kind: binary/docx
          cleanup: ephemeral
'@
            (Test-Manifest $yaml).Valid | Should -BeTrue
        }

        It 'accepts cleanup: retained on a binary producer' {
            $yaml = $script:BaseManifest + @'

pipeline:
  stages:
    - id: render
      kind: render
      produces:
        - id: deck
          kind: binary/pdf
          cleanup: retained
'@
            (Test-Manifest $yaml).Valid | Should -BeTrue
        }

        It 'rejects cleanup values outside the enum' {
            $yaml = $script:BaseManifest + @'

pipeline:
  stages:
    - id: render
      kind: render
      produces:
        - id: deck
          kind: binary/docx
          cleanup: persist
'@
            (Test-Manifest $yaml).Valid | Should -BeFalse
        }

        It 'still validates when cleanup is omitted (advisory only)' {
            $yaml = $script:BaseManifest + @'

pipeline:
  stages:
    - id: render
      kind: render
      produces:
        - id: deck
          kind: binary/docx
'@
            (Test-Manifest $yaml).Valid | Should -BeTrue
        }
    }
}

Describe 'Framework Skill manifest requiredSkills schema' -Tag 'Unit' {
    Context 'well-formed entries' {
        It 'accepts a single required skill reference' {
            $yaml = $script:BaseManifest + @'

requiredSkills:
  - ref: shared/framework-skill-interface
    scope: required
    reason: companion authoring guide
'@
            (Test-Manifest $yaml).Valid | Should -BeTrue
        }

        It 'accepts usedByStages tying a ref to specific stages' {
            $yaml = $script:BaseManifest + @'

pipeline:
  stages:
    - id: render
      kind: render
      produces:
        - id: doc
          kind: markdown
requiredSkills:
  - ref: shared/framework-skill-interface
    usedByStages:
      - render
'@
            (Test-Manifest $yaml).Valid | Should -BeTrue
        }
    }

    Context 'malformed entries' {
        It 'rejects an entry missing the required ref' {
            $yaml = $script:BaseManifest + @'

requiredSkills:
  - scope: optional
    reason: nope
'@
            (Test-Manifest $yaml).Valid | Should -BeFalse
        }

        It 'rejects a ref not matching the <domain>/<name> pattern' {
            $yaml = $script:BaseManifest + @'

requiredSkills:
  - ref: BadCase/path
'@
            (Test-Manifest $yaml).Valid | Should -BeFalse
        }

        It 'rejects extra properties on a requiredSkills entry' {
            $yaml = $script:BaseManifest + @'

requiredSkills:
  - ref: shared/framework-skill-interface
    bogus: extra
'@
            (Test-Manifest $yaml).Valid | Should -BeFalse
        }

        It 'rejects scope values outside the enum' {
            $yaml = $script:BaseManifest + @'

requiredSkills:
  - ref: shared/framework-skill-interface
    scope: maybe
'@
            (Test-Manifest $yaml).Valid | Should -BeFalse
        }
    }
}
