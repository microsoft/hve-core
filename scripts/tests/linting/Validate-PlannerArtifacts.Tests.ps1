#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    # Dot-source the main script
    $scriptPath = Join-Path $PSScriptRoot '../../linting/Validate-PlannerArtifacts.ps1'
    . $scriptPath

    $script:TempTestDir = Join-Path ([System.IO.Path]::GetTempPath()) "AIArtifactTests_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $script:TempTestDir -Force | Out-Null

    $script:ConfigDir = Join-Path $script:TempTestDir '.github/config'
    New-Item -ItemType Directory -Path $script:ConfigDir -Force | Out-Null

    $script:InstructionDir = Join-Path $script:TempTestDir '.github/instructions'
    New-Item -ItemType Directory -Path $script:InstructionDir -Force | Out-Null

    # Footer text constants matching config
    $script:Tier1Text = '> **Note** — The author created this content with assistance from AI. All outputs should be reviewed and validated before use.'
    $script:CheckboxText = '> - [ ] Reviewed and validated by a human reviewer'
    $script:DisclaimerText = '> **Disclaimer** — This agent is an assistive tool only. It does not provide legal, regulatory, or compliance advice.'

    # Create valid footer-with-review.yml
    $script:FooterConfigContent = @"
version: "1.0"

footers:
  ai-content-note:
    id: tier1-ai-content-note
    label: "AI Content Note"
    text: >-
      > **Note** — The author created this content with assistance from AI.
      All outputs should be reviewed and validated before use.

  human-review-checkbox:
    id: human-review-checkbox
    label: "Human Review Checkbox"
    text: "> - [ ] Reviewed and validated by a human reviewer"

artifact-classification:
  agentic:
    required-footers:
      - ai-content-note
    artifacts:
      - control-surface-catalog

  human-facing:
    required-footers:
      - ai-content-note
      - human-review-checkbox
    artifacts:
      - rai-review-summary

  human-facing-with-disclaimer:
    required-footers:
      - ai-content-note
      - human-review-checkbox
    requires-disclaimer: true
    disclaimer-ref: rai-full-disclaimer
    artifacts:
      - handoff-summary
"@

    # Create valid disclaimer-language.instructions.md (markdown source of truth)
    $script:DisclaimerSourceContent = @"
---
description: "Test disclaimer source"
---

# Disclaimer Language

## RAI Planning

> [!CAUTION]
> **Disclaimer:** This agent is an assistive tool only. It does not provide legal, regulatory, or compliance advice.
"@

    $script:FooterConfigPath = Join-Path $script:ConfigDir 'footer-with-review.yml'
    Set-Content -Path $script:FooterConfigPath -Value $script:FooterConfigContent -Encoding utf8

    $script:DisclaimerSourceDir = Join-Path $script:TempTestDir '.github/instructions/shared'
    New-Item -ItemType Directory -Path $script:DisclaimerSourceDir -Force | Out-Null
    $script:DisclaimerSourcePath = Join-Path $script:DisclaimerSourceDir 'disclaimer-language.instructions.md'
    $script:DisclaimerSourceRelative = '.github/instructions/shared/disclaimer-language.instructions.md'
    Set-Content -Path $script:DisclaimerSourcePath -Value $script:DisclaimerSourceContent -Encoding utf8
}

AfterAll {
    if (Test-Path $script:TempTestDir) {
        Remove-Item -Path $script:TempTestDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Import-FooterConfig' -Tag 'Unit' {
    It 'Loads a valid footer config' {
        $config = Import-FooterConfig -ConfigPath $script:FooterConfigPath
        $config.version | Should -Be '1.0'
        $config.footers | Should -Not -BeNullOrEmpty
        $config.'artifact-classification' | Should -Not -BeNullOrEmpty
    }

    It 'Throws when file does not exist' {
        { Import-FooterConfig -ConfigPath (Join-Path $script:TempTestDir 'nonexistent.yml') } | Should -Throw '*not found*'
    }

    It 'Throws when version is missing' {
        $badConfig = Join-Path $script:TempTestDir 'bad-footer.yml'
        Set-Content -Path $badConfig -Value "footers:`n  test:`n    id: test`nartifact-classification:`n  tier:`n    artifacts: []" -Encoding utf8
        { Import-FooterConfig -ConfigPath $badConfig } | Should -Throw "*missing 'version'*"
    }
}

Describe 'Import-DisclaimerSource' -Tag 'Unit' {
    It 'Loads a valid disclaimer markdown source' {
        $config = Import-DisclaimerSource -SourcePath $script:DisclaimerSourcePath
        $config.version | Should -Be 'markdown-source'
        $config.disclaimers | Should -Not -BeNullOrEmpty
        $config.disclaimers['rai-planner'].id | Should -Be 'rai-full-disclaimer'
        $config.disclaimers['rai-planner'].label | Should -Be 'RAI Planning Disclaimer'
    }

    It 'Extracts disclaimer prose with the **Disclaimer** prefix stripped' {
        $config = Import-DisclaimerSource -SourcePath $script:DisclaimerSourcePath
        $config.disclaimers['rai-planner'].text | Should -BeLike 'This agent is an assistive tool only*'
    }

    It 'Throws when file does not exist' {
        { Import-DisclaimerSource -SourcePath (Join-Path $script:TempTestDir 'nonexistent.md') } | Should -Throw '*not found*'
    }

    It 'Throws when markdown contains no disclaimer sections' {
        $badSource = Join-Path $script:TempTestDir 'no-sections.md'
        Set-Content -Path $badSource -Value "# Empty`n`nNo H2 sections here." -Encoding utf8
        { Import-DisclaimerSource -SourcePath $badSource } | Should -Throw '*No disclaimer sections*'
    }

    It 'Retains prose verbatim when the **Disclaimer:** prefix is absent' {
        $source = Join-Path $script:TempTestDir 'no-prefix.md'
        $content = @"
# Disclaimer Language

## RAI Planning

> [!CAUTION]
> This text has no bolded prefix and should be retained verbatim.
"@
        Set-Content -Path $source -Value $content -Encoding utf8
        $config = Import-DisclaimerSource -SourcePath $source
        $config.disclaimers['rai-planner'].text | Should -Be 'This text has no bolded prefix and should be retained verbatim.'
    }

    It 'Joins multi-line CAUTION blockquote prose with single spaces' {
        $source = Join-Path $script:TempTestDir 'multi-line.md'
        $content = @"
# Disclaimer Language

## RAI Planning

> [!CAUTION]
> **Disclaimer:** First sentence continues
> across multiple
> blockquote lines.
"@
        Set-Content -Path $source -Value $content -Encoding utf8
        $config = Import-DisclaimerSource -SourcePath $source
        $config.disclaimers['rai-planner'].text | Should -Be 'First sentence continues across multiple blockquote lines.'
    }

    It 'Uses only the first CAUTION block when an H2 section contains multiple' {
        $source = Join-Path $script:TempTestDir 'multi-caution.md'
        $content = @"
# Disclaimer Language

## RAI Planning

> [!CAUTION]
> **Disclaimer:** First caution wins.

Some prose between blocks.

> [!CAUTION]
> **Disclaimer:** Second caution is ignored.
"@
        Set-Content -Path $source -Value $content -Encoding utf8
        $config = Import-DisclaimerSource -SourcePath $source
        $config.disclaimers['rai-planner'].text | Should -Be 'First caution wins.'
    }

    It 'Parses multiple H2 sections into distinct planner keys using the first heading word as slug' {
        $source = Join-Path $script:TempTestDir 'multi-section.md'
        $content = @"
# Disclaimer Language

## RAI Planning

> [!CAUTION]
> **Disclaimer:** RAI text.

## Security Engineering

> [!CAUTION]
> **Disclaimer:** Security text.

## SSSC

> [!CAUTION]
> **Disclaimer:** SSSC text.
"@
        Set-Content -Path $source -Value $content -Encoding utf8
        $config = Import-DisclaimerSource -SourcePath $source
        $config.disclaimers.Keys | Sort-Object | Should -Be @('rai-planner', 'security-planner', 'sssc-planner')
        $config.disclaimers['security-planner'].id | Should -Be 'security-full-disclaimer'
        $config.disclaimers['security-planner'].label | Should -Be 'Security Engineering Disclaimer'
        $config.disclaimers['sssc-planner'].text | Should -Be 'SSSC text.'
    }

    It 'Silently skips H2 sections that contain no CAUTION blockquote' {
        $source = Join-Path $script:TempTestDir 'empty-section.md'
        $content = @"
# Disclaimer Language

## RAI Planning

Some prose with no caution block here.

## Security Engineering

> [!CAUTION]
> **Disclaimer:** Security text only.
"@
        Set-Content -Path $source -Value $content -Encoding utf8
        $config = Import-DisclaimerSource -SourcePath $source
        $config.disclaimers.ContainsKey('rai-planner') | Should -BeFalse
        $config.disclaimers.Keys | Should -Be @('security-planner')
        $config.disclaimers['security-planner'].text | Should -Be 'Security text only.'
    }
}

Describe 'Get-FooterSearchText' -Tag 'Unit' {
    It 'Strips blockquote markers and normalizes whitespace' {
        $result = Get-FooterSearchText -FooterText '> **Note** — The author   created this content'
        $result | Should -Be '**Note** — The author created this content'
    }

    It 'Handles text without blockquote markers' {
        $result = Get-FooterSearchText -FooterText 'Plain text footer'
        $result | Should -Be 'Plain text footer'
    }
}

Describe 'Test-FooterInContent' -Tag 'Unit' {
    It 'Returns true when footer text is present' {
        $content = @"
# Heading

Some content here.

$($script:Tier1Text)
"@
        Test-FooterInContent -Content $content -FooterText $script:Tier1Text | Should -BeTrue
    }

    It 'Returns false when footer text is absent' {
        $content = '# Heading\n\nSome content with no footer.'
        Test-FooterInContent -Content $content -FooterText $script:Tier1Text | Should -BeFalse
    }
}

Describe 'Test-DisclaimerInContent' -Tag 'Unit' {
    It 'Returns true when disclaimer text is present' {
        $content = @"
# Heading

Some content here.

$($script:DisclaimerText)
"@
        Test-DisclaimerInContent -Content $content -DisclaimerText $script:DisclaimerText | Should -BeTrue
    }

    It 'Returns false when disclaimer text is absent' {
        $content = '# Heading\n\nSome content with no disclaimer.'
        Test-DisclaimerInContent -Content $content -DisclaimerText $script:DisclaimerText | Should -BeFalse
    }
}

Describe 'Find-ArtifactReferences' -Tag 'Unit' {
    BeforeAll {
        $script:FooterConfig = Import-FooterConfig -ConfigPath $script:FooterConfigPath
    }

    It 'Finds agentic artifact references' {
        $refs = Find-ArtifactReferences -ArtifactClassification $script:FooterConfig.'artifact-classification' -RelativePath 'rai-planning/control-surface-catalog.md'
        $refs.Count | Should -Be 1
        $refs[0].ArtifactName | Should -Be 'control-surface-catalog'
        $refs[0].Tier | Should -Be 'agentic'
    }

    It 'Finds human-facing-with-disclaimer artifact references' {
        $refs = Find-ArtifactReferences -ArtifactClassification $script:FooterConfig.'artifact-classification' -RelativePath 'rai-planning/handoff-summary.md'
        $refs.Count | Should -Be 1
        $refs[0].RequiresDisclaimer | Should -BeTrue
        $refs[0].DisclaimerRef | Should -Be 'rai-full-disclaimer'
    }

    It 'Returns empty when no artifacts match' {
        $refs = Find-ArtifactReferences -ArtifactClassification $script:FooterConfig.'artifact-classification' -RelativePath 'rai-planning/unrelated.md'
        $refs.Count | Should -Be 0
    }

    It 'Excludes tiers when file path falls outside scope' {
        # Add scope to the classification for this test
        $scopedClassification = @{
            agentic = @{
                scope             = @('rai-planning/**')
                'required-footers' = @('ai-content-note')
                artifacts         = @('control-surface-catalog')
            }
        }
        $refs = Find-ArtifactReferences -ArtifactClassification $scopedClassification -RelativePath 'github/control-surface-catalog.md'
        $refs.Count | Should -Be 0

        $refsInScope = Find-ArtifactReferences -ArtifactClassification $scopedClassification -RelativePath 'rai-planning/control-surface-catalog.md'
        $refsInScope.Count | Should -Be 1
    }
}

Describe 'Test-AIArtifactCompliance' -Tag 'Unit' {
    BeforeAll {
        $script:FooterConfig = Import-FooterConfig -ConfigPath $script:FooterConfigPath
        $script:DisclaimerConfig = Import-DisclaimerSource -SourcePath $script:DisclaimerSourcePath
    }

    Context 'Agentic tier (Tier 1 only)' {
        It 'Passes when Tier 1 footer is present' {
            $filePath = Join-Path $script:InstructionDir 'control-surface-catalog.instructions.md'
            $content = @"
---
description: Test instruction
---

# Template for control-surface-catalog

Content here.

$($script:Tier1Text)
"@
            Set-Content -Path $filePath -Value $content -Encoding utf8
            $result = Test-AIArtifactCompliance -FilePath $filePath -FooterConfig $script:FooterConfig -DisclaimerConfig $script:DisclaimerConfig -RepoRoot $script:TempTestDir
            $result.Passed | Should -BeTrue
            $result.Issues.Count | Should -Be 0
        }

        It 'Fails when Tier 1 footer is missing' {
            $filePath = Join-Path $script:InstructionDir 'control-surface-catalog.instructions.md'
            $content = @"
---
description: Test instruction
---

# Template for control-surface-catalog

Content here with no footer.
"@
            Set-Content -Path $filePath -Value $content -Encoding utf8
            $result = Test-AIArtifactCompliance -FilePath $filePath -FooterConfig $script:FooterConfig -DisclaimerConfig $script:DisclaimerConfig -RepoRoot $script:TempTestDir
            $result.Passed | Should -BeFalse
            $result.Issues.Count | Should -BeGreaterThan 0
        }
    }

    Context 'Human-facing tier (Tier 1 + checkbox)' {
        It 'Passes when both footers are present' {
            $filePath = Join-Path $script:InstructionDir 'rai-review-summary.instructions.md'
            $content = @"
---
description: Test instruction
---

# Template for rai-review-summary

Content here.

$($script:Tier1Text)

$($script:CheckboxText)
"@
            Set-Content -Path $filePath -Value $content -Encoding utf8
            $result = Test-AIArtifactCompliance -FilePath $filePath -FooterConfig $script:FooterConfig -DisclaimerConfig $script:DisclaimerConfig -RepoRoot $script:TempTestDir
            $result.Passed | Should -BeTrue
        }

        It 'Fails when checkbox is missing' {
            $filePath = Join-Path $script:InstructionDir 'rai-review-summary.instructions.md'
            $content = @"
---
description: Test instruction
---

# Template for rai-review-summary

Content here.

$($script:Tier1Text)
"@
            Set-Content -Path $filePath -Value $content -Encoding utf8
            $result = Test-AIArtifactCompliance -FilePath $filePath -FooterConfig $script:FooterConfig -DisclaimerConfig $script:DisclaimerConfig -RepoRoot $script:TempTestDir
            $result.Passed | Should -BeFalse
            $result.Issues | Should -HaveCount 1
            $result.Issues[0] | Should -BeLike '*Human Review Checkbox*'
        }
    }

    Context 'Human-facing-with-disclaimer tier (Tier 1 + checkbox + disclaimer)' {
        It 'Passes when all three elements are present' {
            $filePath = Join-Path $script:InstructionDir 'handoff-summary.instructions.md'
            $content = @"
---
description: Test instruction
---

# Template for handoff-summary

Content here.

$($script:Tier1Text)

$($script:CheckboxText)

$($script:DisclaimerText)
"@
            Set-Content -Path $filePath -Value $content -Encoding utf8
            $result = Test-AIArtifactCompliance -FilePath $filePath -FooterConfig $script:FooterConfig -DisclaimerConfig $script:DisclaimerConfig -RepoRoot $script:TempTestDir
            $result.Passed | Should -BeTrue
        }

        It 'Fails when disclaimer is missing' {
            $filePath = Join-Path $script:InstructionDir 'handoff-summary.instructions.md'
            $content = @"
---
description: Test instruction
---

# Template for handoff-summary

Content here.

$($script:Tier1Text)

$($script:CheckboxText)
"@
            Set-Content -Path $filePath -Value $content -Encoding utf8
            $result = Test-AIArtifactCompliance -FilePath $filePath -FooterConfig $script:FooterConfig -DisclaimerConfig $script:DisclaimerConfig -RepoRoot $script:TempTestDir
            $result.Passed | Should -BeFalse
            $result.Issues | Should -HaveCount 1
            $result.Issues[0] | Should -BeLike '*Disclaimer*'
        }
    }

    Context 'Files without artifact references' {
        It 'Skips files with no matching artifacts' {
            $filePath = Join-Path $script:InstructionDir 'unrelated.instructions.md'
            $content = @"
---
description: Unrelated instruction
---

# This file has nothing to do with RAI artifacts
"@
            Set-Content -Path $filePath -Value $content -Encoding utf8
            $result = Test-AIArtifactCompliance -FilePath $filePath -FooterConfig $script:FooterConfig -DisclaimerConfig $script:DisclaimerConfig -RepoRoot $script:TempTestDir
            $result.Skipped | Should -BeTrue
            $result.Passed | Should -BeTrue
        }
    }
}

Describe 'Test-AIArtifactValidation' -Tag 'Unit' {
    BeforeAll {
        $script:FooterConfig = Import-FooterConfig -ConfigPath $script:FooterConfigPath
        $script:DisclaimerConfig = Import-DisclaimerSource -SourcePath $script:DisclaimerSourcePath
    }

    BeforeEach {
        # Create compliant agentic file (control-surface-catalog)
        $agenticPath = Join-Path $script:InstructionDir 'control-surface-catalog.instructions.md'
        $agenticContent = @"
---
description: Control surface catalog
---

# Control Surface Catalog

$($script:Tier1Text)
"@
        Set-Content -Path $agenticPath -Value $agenticContent -Encoding utf8

        # Create non-compliant human-facing file (rai-review-summary) missing checkbox
        $humanPath = Join-Path $script:InstructionDir 'rai-review-summary.instructions.md'
        $humanContent = @"
---
description: RAI review summary
---

# RAI Review Summary

$($script:Tier1Text)
"@
        Set-Content -Path $humanPath -Value $humanContent -Encoding utf8
    }

    Context 'Multi-file processing' {
        It 'Returns correct summary counts' {
            Mock git { $script:TempTestDir } -ParameterFilter { $args[0] -eq 'rev-parse' }
            Mock Get-FilesRecursive {
                Get-ChildItem -Path $script:InstructionDir -Filter '*.instructions.md' -Recurse
            }
            Mock Write-CIAnnotation {}
            Mock Test-CIEnvironment { $false }
            Mock Get-StandardTimestamp { '2025-01-01T00:00:00Z' }
            Mock Write-Host {}

            $result = Test-AIArtifactValidation `
                -Paths @('.github/instructions') `
                -FooterConfigPath '.github/config/footer-with-review.yml' `
                -DisclaimerSourcePath '.github/instructions/shared/disclaimer-language.instructions.md'

            $result.TotalFiles | Should -BeGreaterOrEqual 2
            $result.FilesWithArtifacts | Should -BeGreaterOrEqual 2
            $result.FilesWithIssues | Should -BeGreaterOrEqual 1
        }
    }

    Context 'Exclude path filtering' {
        It 'Skips files matching exclude patterns' {
            $subDir = Join-Path $script:InstructionDir 'excluded'
            New-Item -ItemType Directory -Path $subDir -Force | Out-Null
            $excludedFile = Join-Path $subDir 'control-surface-catalog.instructions.md'
            Set-Content -Path $excludedFile -Value '# No footers' -Encoding utf8

            Mock git { $script:TempTestDir } -ParameterFilter { $args[0] -eq 'rev-parse' }
            Mock Get-FilesRecursive {
                Get-ChildItem -Path $script:InstructionDir -Filter '*.instructions.md' -Recurse
            }
            Mock Write-CIAnnotation {}
            Mock Test-CIEnvironment { $false }
            Mock Get-StandardTimestamp { '2025-01-01T00:00:00Z' }
            Mock Write-Host {}

            $result = Test-AIArtifactValidation `
                -Paths @('.github/instructions') `
                -FooterConfigPath '.github/config/footer-with-review.yml' `
                -DisclaimerSourcePath '.github/instructions/shared/disclaimer-language.instructions.md' `
                -ExcludePaths @('**/excluded/**')

            $excludedResults = $result.Results | Where-Object { $_.RelativePath -like '*excluded*' }
            $excludedResults | Should -BeNullOrEmpty
        }
    }

    Context 'FailOnMissing behavior' {
        It 'Sets HasFailures to true when FailOnMissing and issues exist' {
            Mock git { $script:TempTestDir } -ParameterFilter { $args[0] -eq 'rev-parse' }
            Mock Get-FilesRecursive {
                Get-ChildItem -Path $script:InstructionDir -Filter '*.instructions.md' -Recurse
            }
            Mock Write-CIAnnotation {}
            Mock Test-CIEnvironment { $false }
            Mock Get-StandardTimestamp { '2025-01-01T00:00:00Z' }
            Mock Write-Host {}

            $result = Test-AIArtifactValidation `
                -Paths @('.github/instructions') `
                -FooterConfigPath '.github/config/footer-with-review.yml' `
                -DisclaimerSourcePath '.github/instructions/shared/disclaimer-language.instructions.md' `
                -FailOnMissing

            $result.HasFailures | Should -BeTrue
        }

        It 'Sets HasFailures to false without FailOnMissing even when issues exist' {
            Mock git { $script:TempTestDir } -ParameterFilter { $args[0] -eq 'rev-parse' }
            Mock Get-FilesRecursive {
                Get-ChildItem -Path $script:InstructionDir -Filter '*.instructions.md' -Recurse
            }
            Mock Write-CIAnnotation {}
            Mock Test-CIEnvironment { $false }
            Mock Get-StandardTimestamp { '2025-01-01T00:00:00Z' }
            Mock Write-Host {}

            $result = Test-AIArtifactValidation `
                -Paths @('.github/instructions') `
                -FooterConfigPath '.github/config/footer-with-review.yml' `
                -DisclaimerSourcePath '.github/instructions/shared/disclaimer-language.instructions.md'

            $result.HasFailures | Should -BeFalse
        }
    }

    Context 'JSON export' {
        It 'Writes valid JSON to OutputPath' {
            $outputPath = '.github/config/test-results.json'
            $outputFullPath = Join-Path $script:TempTestDir $outputPath

            Mock git { $script:TempTestDir } -ParameterFilter { $args[0] -eq 'rev-parse' }
            Mock Get-FilesRecursive {
                Get-ChildItem -Path $script:InstructionDir -Filter '*.instructions.md' -Recurse
            }
            Mock Write-CIAnnotation {}
            Mock Test-CIEnvironment { $false }
            Mock Get-StandardTimestamp { '2025-01-01T00:00:00Z' }
            Mock Write-Host {}

            Test-AIArtifactValidation `
                -Paths @('.github/instructions') `
                -FooterConfigPath '.github/config/footer-with-review.yml' `
                -DisclaimerSourcePath '.github/instructions/shared/disclaimer-language.instructions.md' `
                -OutputPath $outputPath

            $outputFullPath | Should -Exist
            $raw = Get-Content -Path $outputFullPath -Raw
            $raw | Should -Match '"timestamp"\s*:\s*"2025-01-01T00:00:00Z"'
            $json = $raw | ConvertFrom-Json
            $json.totalFiles | Should -BeGreaterOrEqual 2
            $json.results | Should -Not -BeNullOrEmpty
        }
    }
}
