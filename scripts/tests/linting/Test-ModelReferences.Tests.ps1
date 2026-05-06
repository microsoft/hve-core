#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../linting/Test-ModelReferences.ps1'
    . $script:ScriptPath

    # Suppress Write-Host output during tests
    Mock Write-Host {}

    # Create temp directory for test fixtures
    $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "ModelRefTests_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
}

AfterAll {
    if (Test-Path $script:TempDir) {
        Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

#region Get-FrontmatterFromFile Tests

Describe 'Get-FrontmatterFromFile' -Tag 'Unit' {
    BeforeAll {
        $script:FixtureDir = Join-Path $script:TempDir 'frontmatter'
        New-Item -ItemType Directory -Path $script:FixtureDir -Force | Out-Null
    }

    Context 'when file has valid frontmatter' {
        It 'Returns parsed hashtable with string model' {
            $filePath = Join-Path $script:FixtureDir 'valid-string.agent.md'
            @"
---
name: Test Agent
model: Claude Haiku 4.5 (copilot)
---

# Content
"@ | Set-Content -Path $filePath -Encoding utf8

            $result = Get-FrontmatterFromFile -FilePath $filePath
            $result | Should -Not -BeNullOrEmpty
            $result['name'] | Should -Be 'Test Agent'
            $result['model'] | Should -Be 'Claude Haiku 4.5 (copilot)'
        }

        It 'Returns parsed hashtable with array model' {
            $filePath = Join-Path $script:FixtureDir 'valid-array.agent.md'
            @"
---
name: Test Agent
model:
  - Claude Haiku 4.5 (copilot)
  - GPT-5.4 mini (copilot)
---

# Content
"@ | Set-Content -Path $filePath -Encoding utf8

            $result = Get-FrontmatterFromFile -FilePath $filePath
            $result | Should -Not -BeNullOrEmpty
            $result['model'] | Should -HaveCount 2
        }

        It 'Handles frontmatter with additional properties' {
            $filePath = Join-Path $script:FixtureDir 'extra-props.prompt.md'
            @"
---
description: 'A test prompt'
agent: 'agent'
model: GPT-5.4 mini (copilot)
---

# Content
"@ | Set-Content -Path $filePath -Encoding utf8

            $result = Get-FrontmatterFromFile -FilePath $filePath
            $result['description'] | Should -Be 'A test prompt'
            $result['agent'] | Should -Be 'agent'
            $result['model'] | Should -Be 'GPT-5.4 mini (copilot)'
        }
    }

    Context 'when file has no frontmatter' {
        It 'Returns null for file without frontmatter' {
            $filePath = Join-Path $script:FixtureDir 'no-frontmatter.agent.md'
            @"
# Just a heading

No frontmatter here.
"@ | Set-Content -Path $filePath -Encoding utf8

            $result = Get-FrontmatterFromFile -FilePath $filePath
            $result | Should -BeNullOrEmpty
        }

        It 'Returns null for empty file' {
            $filePath = Join-Path $script:FixtureDir 'empty.agent.md'
            '' | Set-Content -Path $filePath -Encoding utf8

            $result = Get-FrontmatterFromFile -FilePath $filePath
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'when file has invalid YAML' {
        It 'Returns null and writes warning for malformed YAML' {
            $filePath = Join-Path $script:FixtureDir 'bad-yaml.agent.md'
            @"
---
name: [unclosed bracket
model: bad: yaml: here
---

# Content
"@ | Set-Content -Path $filePath -Encoding utf8

            $result = Get-FrontmatterFromFile -FilePath $filePath
            $result | Should -BeNullOrEmpty
        }
    }
}

#endregion

#region Get-ModelReferences Tests

Describe 'Get-ModelReferences' -Tag 'Unit' {
    Context 'when frontmatter has no model property' {
        It 'Returns empty array' {
            $frontmatter = @{ name = 'Test Agent'; description = 'No model here' }
            $result = Get-ModelReferences -Frontmatter $frontmatter
            $result | Should -HaveCount 0
        }
    }

    Context 'when model is a string' {
        It 'Returns single-element array' {
            $frontmatter = @{ model = 'Claude Haiku 4.5 (copilot)' }
            $result = @(Get-ModelReferences -Frontmatter $frontmatter)
            $result | Should -HaveCount 1
            $result[0] | Should -Be 'Claude Haiku 4.5 (copilot)'
        }
    }

    Context 'when model is an array' {
        It 'Returns all model names' {
            $frontmatter = @{ model = @('Claude Haiku 4.5 (copilot)', 'GPT-5.4 mini (copilot)', 'Gemini 3 Flash (Preview) (copilot)') }
            $result = Get-ModelReferences -Frontmatter $frontmatter
            $result | Should -HaveCount 3
            $result[0] | Should -Be 'Claude Haiku 4.5 (copilot)'
            $result[1] | Should -Be 'GPT-5.4 mini (copilot)'
            $result[2] | Should -Be 'Gemini 3 Flash (Preview) (copilot)'
        }

        It 'Returns single-element array for single-item list' {
            $frontmatter = @{ model = @('GPT-5.4 mini (copilot)') }
            $result = @(Get-ModelReferences -Frontmatter $frontmatter)
            $result | Should -HaveCount 1
            $result[0] | Should -Be 'GPT-5.4 mini (copilot)'
        }
    }

    Context 'when model value is null' {
        It 'Returns empty array' {
            $frontmatter = @{ model = $null }
            $result = Get-ModelReferences -Frontmatter $frontmatter
            $result | Should -HaveCount 0
        }
    }
}

#endregion

#region Invoke-ModelReferenceValidation Tests

Describe 'Invoke-ModelReferenceValidation' -Tag 'Unit' {
    BeforeAll {
        $script:ValidationDir = Join-Path $script:TempDir 'validation'
        New-Item -ItemType Directory -Path $script:ValidationDir -Force | Out-Null

        # Create a minimal catalog
        $script:CatalogDir = Join-Path $script:TempDir 'catalog'
        New-Item -ItemType Directory -Path $script:CatalogDir -Force | Out-Null
        $script:TestCatalogPath = Join-Path $script:CatalogDir 'model-catalog.json'
    }

    Context 'when catalog does not exist' {
        It 'Throws error for missing catalog' {
            $nonexistentPath = Join-Path $script:CatalogDir 'nonexistent.json'
            { Invoke-ModelReferenceValidation -CatalogPath $nonexistentPath -ScanPath $script:ValidationDir } | Should -Throw '*not found*'
        }
    }

    Context 'when all models are valid' {
        BeforeAll {
            $script:ValidDir = Join-Path $script:ValidationDir 'valid-models'
            New-Item -ItemType Directory -Path $script:ValidDir -Force | Out-Null

            # Create catalog with known models
            $catalog = @{
                lastUpdated = '2026-05-06'
                source      = 'https://example.com'
                models      = @(
                    @{ name = 'Claude Haiku 4.5 (copilot)'; tier = 'fast'; multiplier = 0.33; status = 'ga' }
                    @{ name = 'GPT-5.4 mini (copilot)'; tier = 'fast'; multiplier = 0.33; status = 'ga' }
                    @{ name = 'Gemini 3 Flash (Preview) (copilot)'; tier = 'fast'; multiplier = 0.33; status = 'preview' }
                )
            }
            $catalog | ConvertTo-Json -Depth 5 | Set-Content -Path $script:TestCatalogPath -Encoding utf8

            # Create agent file with valid model array
            @"
---
name: Valid Agent
model:
  - Claude Haiku 4.5 (copilot)
  - GPT-5.4 mini (copilot)
---

# Agent
"@ | Set-Content -Path (Join-Path $script:ValidDir 'test.agent.md') -Encoding utf8

            # Create prompt file with valid single model
            @"
---
description: Valid Prompt
model: Gemini 3 Flash (Preview) (copilot)
---

# Prompt
"@ | Set-Content -Path (Join-Path $script:ValidDir 'test.prompt.md') -Encoding utf8

            $script:ValidResult = Invoke-ModelReferenceValidation -CatalogPath $script:TestCatalogPath -ScanPath $script:ValidDir
        }

        It 'Reports zero invalid references' {
            $script:ValidResult.invalidReferences | Should -Be 0
        }

        It 'Reports correct total references' {
            $script:ValidResult.totalReferences | Should -Be 3
        }

        It 'Reports correct valid references' {
            $script:ValidResult.validReferences | Should -Be 3
        }

        It 'Reports correct files with models count' {
            $script:ValidResult.filesWithModels | Should -Be 2
        }

        It 'Reports correct total file count' {
            $script:ValidResult.totalFiles | Should -Be 2
        }

        It 'Returns empty errors array' {
            $script:ValidResult.errors | Should -HaveCount 0
        }

        It 'Returns results for each file with models' {
            $script:ValidResult.results | Should -HaveCount 2
        }

        It 'Marks all results as valid status' {
            $script:ValidResult.results | ForEach-Object { $_.status | Should -Be 'valid' }
        }

        It 'Includes catalog last updated date' {
            $script:ValidResult.catalogLastUpdated | Should -Be '2026-05-06'
        }
    }

    Context 'when models are invalid' {
        BeforeAll {
            $script:InvalidDir = Join-Path $script:ValidationDir 'invalid-models'
            New-Item -ItemType Directory -Path $script:InvalidDir -Force | Out-Null

            # Create agent file with invalid model
            @"
---
name: Bad Agent
model:
  - Claude Haiku 4.5 (copilot)
  - Nonexistent Model (copilot)
---

# Agent
"@ | Set-Content -Path (Join-Path $script:InvalidDir 'bad.agent.md') -Encoding utf8

            $script:InvalidResult = Invoke-ModelReferenceValidation -CatalogPath $script:TestCatalogPath -ScanPath $script:InvalidDir
        }

        It 'Reports one invalid reference' {
            $script:InvalidResult.invalidReferences | Should -Be 1
        }

        It 'Reports one valid reference' {
            $script:InvalidResult.validReferences | Should -Be 1
        }

        It 'Contains error with model name' {
            $script:InvalidResult.errors | Should -HaveCount 1
            $script:InvalidResult.errors[0].model | Should -Be 'Nonexistent Model (copilot)'
        }

        It 'Contains descriptive error message' {
            $script:InvalidResult.errors[0].message | Should -Match 'Unrecognized model'
        }

        It 'Marks file result as invalid' {
            $script:InvalidResult.results[0].status | Should -Be 'invalid'
        }
    }

    Context 'when models are retiring' {
        BeforeAll {
            $script:RetiringDir = Join-Path $script:ValidationDir 'retiring-models'
            New-Item -ItemType Directory -Path $script:RetiringDir -Force | Out-Null

            # Create catalog with a retiring model
            $retiringCatalog = @{
                lastUpdated = '2026-05-06'
                source      = 'https://example.com'
                models      = @(
                    @{ name = 'Claude Haiku 4.5 (copilot)'; tier = 'fast'; multiplier = 0.33; status = 'ga' }
                    @{ name = 'Old Model (copilot)'; tier = 'fast'; multiplier = 0.33; status = 'retiring'; retiredDate = '2026-06-01' }
                )
            }
            $script:RetiringCatalogPath = Join-Path $script:CatalogDir 'retiring-catalog.json'
            $retiringCatalog | ConvertTo-Json -Depth 5 | Set-Content -Path $script:RetiringCatalogPath -Encoding utf8

            # Create agent file with retiring model
            @"
---
name: Retiring Agent
model:
  - Old Model (copilot)
  - Claude Haiku 4.5 (copilot)
---

# Agent
"@ | Set-Content -Path (Join-Path $script:RetiringDir 'retiring.agent.md') -Encoding utf8

            $script:RetiringResult = Invoke-ModelReferenceValidation -CatalogPath $script:RetiringCatalogPath -ScanPath $script:RetiringDir
        }

        It 'Reports one retiring reference' {
            $script:RetiringResult.retiringReferences | Should -Be 1
        }

        It 'Reports zero invalid references' {
            $script:RetiringResult.invalidReferences | Should -Be 0
        }

        It 'Counts retiring model as valid' {
            $script:RetiringResult.validReferences | Should -Be 2
        }

        It 'Contains warning with retiring model name' {
            $script:RetiringResult.warnings | Should -HaveCount 1
            $script:RetiringResult.warnings[0].model | Should -Be 'Old Model (copilot)'
        }

        It 'Contains descriptive warning message' {
            $script:RetiringResult.warnings[0].message | Should -Match 'retiring'
        }

        It 'Marks file result as warning status' {
            $script:RetiringResult.results[0].status | Should -Be 'warning'
        }
    }

    Context 'when file has both invalid and retiring models' {
        BeforeAll {
            $script:MixedDir = Join-Path $script:ValidationDir 'mixed-models'
            New-Item -ItemType Directory -Path $script:MixedDir -Force | Out-Null

            # Create agent file with both invalid and retiring model
            @"
---
name: Mixed Agent
model:
  - Old Model (copilot)
  - Fake Model (copilot)
---

# Agent
"@ | Set-Content -Path (Join-Path $script:MixedDir 'mixed.agent.md') -Encoding utf8

            $script:MixedResult = Invoke-ModelReferenceValidation -CatalogPath $script:RetiringCatalogPath -ScanPath $script:MixedDir
        }

        It 'Marks file as invalid when both retiring and invalid present' {
            $script:MixedResult.results[0].status | Should -Be 'invalid'
        }

        It 'Reports one invalid and one retiring' {
            $script:MixedResult.invalidReferences | Should -Be 1
            $script:MixedResult.retiringReferences | Should -Be 1
        }
    }

    Context 'when files have no model property' {
        BeforeAll {
            $script:NoModelDir = Join-Path $script:ValidationDir 'no-model'
            New-Item -ItemType Directory -Path $script:NoModelDir -Force | Out-Null

            @"
---
name: No Model Agent
description: Agent without model
---

# Agent
"@ | Set-Content -Path (Join-Path $script:NoModelDir 'no-model.agent.md') -Encoding utf8

            $script:NoModelResult = Invoke-ModelReferenceValidation -CatalogPath $script:TestCatalogPath -ScanPath $script:NoModelDir
        }

        It 'Reports zero files with models' {
            $script:NoModelResult.filesWithModels | Should -Be 0
        }

        It 'Reports zero total references' {
            $script:NoModelResult.totalReferences | Should -Be 0
        }

        It 'Returns empty results array' {
            $script:NoModelResult.results | Should -HaveCount 0
        }

        It 'Counts the file in total files' {
            $script:NoModelResult.totalFiles | Should -Be 1
        }
    }

    Context 'when scan path has no matching files' {
        BeforeAll {
            $script:EmptyDir = Join-Path $script:ValidationDir 'empty'
            New-Item -ItemType Directory -Path $script:EmptyDir -Force | Out-Null

            $script:EmptyResult = Invoke-ModelReferenceValidation -CatalogPath $script:TestCatalogPath -ScanPath $script:EmptyDir
        }

        It 'Reports zero total files' {
            $script:EmptyResult.totalFiles | Should -Be 0
        }

        It 'Reports zero references' {
            $script:EmptyResult.totalReferences | Should -Be 0
        }
    }

    Context 'when files have no frontmatter' {
        BeforeAll {
            $script:NoFmDir = Join-Path $script:ValidationDir 'no-frontmatter'
            New-Item -ItemType Directory -Path $script:NoFmDir -Force | Out-Null

            @"
# No Frontmatter Agent

Just content, no YAML.
"@ | Set-Content -Path (Join-Path $script:NoFmDir 'bare.agent.md') -Encoding utf8

            $script:NoFmResult = Invoke-ModelReferenceValidation -CatalogPath $script:TestCatalogPath -ScanPath $script:NoFmDir
        }

        It 'Counts file in total but not in models' {
            $script:NoFmResult.totalFiles | Should -Be 1
            $script:NoFmResult.filesWithModels | Should -Be 0
        }
    }
}

#endregion
