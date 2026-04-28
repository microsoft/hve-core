#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../linting/Validate-FsiContent.ps1')

    $script:RepoRoot = (git -C $PSScriptRoot rev-parse --show-toplevel 2>$null)
    if (-not $script:RepoRoot) { $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path }
}

Describe 'Test-FsiSkillReferenceResolution' -Tag 'Unit' {
    Context 'manifest without requiredSkills' {
        It 'returns no errors or warnings' {
            $manifest = @{ framework = 'demo' }
            $result = Test-FsiSkillReferenceResolution -Manifest $manifest -Framework 'demo' -RepoRoot $script:RepoRoot
            $result.Errors | Should -HaveCount 0
            $result.Warnings | Should -HaveCount 0
        }
    }

    Context 'requiredSkills with a resolvable ref' {
        It 'returns no errors when the SKILL.md exists' {
            $manifest = @{
                framework = 'demo'
                requiredSkills = @(
                    @{ ref = 'shared/framework-skill-interface' }
                )
            }
            $result = Test-FsiSkillReferenceResolution -Manifest $manifest -Framework 'demo' -RepoRoot $script:RepoRoot
            $result.Errors | Should -HaveCount 0
        }
    }

    Context 'requiredSkills with an unresolvable ref' {
        It 'errors when the SKILL.md does not exist' {
            $manifest = @{
                framework = 'demo'
                requiredSkills = @(
                    @{ ref = 'nonexistent/skill' }
                )
            }
            $result = Test-FsiSkillReferenceResolution -Manifest $manifest -Framework 'demo' -RepoRoot $script:RepoRoot
            $result.Errors.Count | Should -BeGreaterThan 0
            ($result.Errors -join "`n") | Should -Match 'nonexistent/skill'
        }
    }

    Context 'usedByStages matching pipeline stage ids' {
        It 'returns no errors when every usedByStages id matches a stage id' {
            $manifest = @{
                framework = 'demo'
                pipeline = @{ stages = @(
                    @{ id = 'render'; kind = 'render' }
                ) }
                requiredSkills = @(
                    @{ ref = 'shared/framework-skill-interface'; usedByStages = @('render') }
                )
            }
            $result = Test-FsiSkillReferenceResolution -Manifest $manifest -Framework 'demo' -RepoRoot $script:RepoRoot
            $result.Errors | Should -HaveCount 0
        }
    }

    Context 'usedByStages referencing an unknown stage id' {
        It 'errors with the offending stage id' {
            $manifest = @{
                framework = 'demo'
                pipeline = @{ stages = @(
                    @{ id = 'render'; kind = 'render' }
                ) }
                requiredSkills = @(
                    @{ ref = 'shared/framework-skill-interface'; usedByStages = @('ghost') }
                )
            }
            $result = Test-FsiSkillReferenceResolution -Manifest $manifest -Framework 'demo' -RepoRoot $script:RepoRoot
            $result.Errors.Count | Should -BeGreaterThan 0
            ($result.Errors -join "`n") | Should -Match 'ghost'
        }
    }

    Context 'Raw-wrapped manifest input' {
        It 'unwraps PSObject.Raw and validates equivalently' {
            $raw = @{
                framework = 'demo'
                requiredSkills = @(
                    @{ ref = 'nonexistent/skill' }
                )
            }
            $bundle = [pscustomobject]@{ Raw = $raw }
            $result = Test-FsiSkillReferenceResolution -Manifest $bundle -Framework 'demo' -RepoRoot $script:RepoRoot
            $result.Errors.Count | Should -BeGreaterThan 0
        }
    }

    Context 'manifest without pipeline but with valid ref' {
        It 'returns no errors and skips usedByStages checks' {
            $manifest = @{
                framework = 'demo'
                requiredSkills = @(
                    @{ ref = 'shared/framework-skill-interface' }
                )
            }
            $result = Test-FsiSkillReferenceResolution -Manifest $manifest -Framework 'demo' -RepoRoot $script:RepoRoot
            $result.Errors | Should -HaveCount 0
        }
    }
}
