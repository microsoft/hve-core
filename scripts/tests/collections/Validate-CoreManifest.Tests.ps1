#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    Import-Module PowerShell-Yaml -ErrorAction Stop
    . $PSScriptRoot/../../collections/Validate-CoreManifest.ps1

    function New-CoreManifestTestRepo {
        param(
            [Parameter(Mandatory = $true)]
            [string]$RootPath
        )

        New-Item -ItemType Directory -Path (Join-Path $RootPath '.github/agents/test') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $RootPath '.github/prompts/test') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $RootPath '.github/instructions/test') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $RootPath '.github/skills/test/test-skill') -Force | Out-Null

        Set-Content -Path (Join-Path $RootPath '.github/agents/test/test.agent.md') -Value "---`ndescription: test agent`n---"
        Set-Content -Path (Join-Path $RootPath '.github/prompts/test/test.prompt.md') -Value "---`ndescription: test prompt`n---"
        Set-Content -Path (Join-Path $RootPath '.github/instructions/test/test.instructions.md') -Value "---`ndescription: test instruction`n---"
        Set-Content -Path (Join-Path $RootPath '.github/skills/test/test-skill/SKILL.md') -Value '# Test skill'
        Set-Content -Path (Join-Path $RootPath 'CHANGELOG.md') -Value '# Changelog'
        Set-Content -Path (Join-Path $RootPath 'release-please-config.json') -Value '{}'
    }

    function New-CoreManifestFixture {
        return [ordered]@{
            schemaVersion = 1
            collections   = [ordered]@{
                'test' = [ordered]@{
                    name        = 'Test'
                    description = 'Test collection'
                }
            }
            agents        = [ordered]@{
                '.github/agents/test/test.agent.md' = [ordered]@{
                    path        = '.github/agents/test/test.agent.md'
                    maturity    = 'stable'
                    collections = @('test')
                }
            }
            prompts       = [ordered]@{
                '.github/prompts/test/test.prompt.md' = [ordered]@{
                    path        = '.github/prompts/test/test.prompt.md'
                    maturity    = 'preview'
                    collections = @('test')
                }
            }
            instructions  = [ordered]@{
                '.github/instructions/test/test.instructions.md' = [ordered]@{
                    path        = '.github/instructions/test/test.instructions.md'
                    maturity    = 'experimental'
                    collections = @('test')
                }
            }
            skills        = [ordered]@{
                '.github/skills/test/test-skill' = [ordered]@{
                    path        = '.github/skills/test/test-skill'
                    maturity    = 'stable'
                    collections = @('test')
                }
            }
            releases      = [ordered]@{
                'test-release' = [ordered]@{
                    channel         = 'stable'
                    includeMaturity = @('stable', 'preview', 'experimental')
                    excludePaths    = @('.github/prompts/test/excluded.prompt.md')
                    artifacts       = @(
                        '.github/agents/test/test.agent.md',
                        '.github/prompts/test/test.prompt.md',
                        '.github/instructions/test/test.instructions.md',
                        '.github/skills/test/test-skill'
                    )
                    whatNew         = [ordered]@{
                        source        = 'release-please-config.json'
                        changelogPath = 'CHANGELOG.md'
                    }
                }
            }
        }
    }

    function Write-CoreManifestFixture {
        param(
            [Parameter(Mandatory = $true)]
            [string]$ManifestPath,

            [Parameter(Mandatory = $true)]
            [object]$Manifest
        )

        New-Item -ItemType Directory -Path (Split-Path -Path $ManifestPath -Parent) -Force | Out-Null
        ConvertTo-Yaml -Data $Manifest | Set-Content -Path $ManifestPath
    }

    function Add-CoreManifestAgent {
        param(
            [Parameter(Mandatory = $true)]
            [string]$RootPath,

            [Parameter(Mandatory = $true)]
            [object]$Manifest,

            [Parameter(Mandatory = $true)]
            [string]$Path,

            [Parameter(Mandatory = $true)]
            [string]$Name,

            [Parameter(Mandatory = $true)]
            [string]$Maturity,

            [Parameter()]
            [string]$Body = ''
        )

        $fullPath = Join-Path $RootPath $Path
        New-Item -ItemType Directory -Path (Split-Path -Path $fullPath -Parent) -Force | Out-Null
        Set-Content -Path $fullPath -Value "---`nname: $Name`ndescription: $Name`n---`n$Body"
        $Manifest.agents[$Path] = [ordered]@{
            path        = $Path
            maturity    = $Maturity
            collections = @('test')
        }
    }

    function Add-CoreManifestPrompt {
        param(
            [Parameter(Mandatory = $true)]
            [string]$RootPath,

            [Parameter(Mandatory = $true)]
            [object]$Manifest,

            [Parameter(Mandatory = $true)]
            [string]$Path,

            [Parameter(Mandatory = $true)]
            [string]$Maturity
        )

        $fullPath = Join-Path $RootPath $Path
        New-Item -ItemType Directory -Path (Split-Path -Path $fullPath -Parent) -Force | Out-Null
        Set-Content -Path $fullPath -Value "---`ndescription: prompt`n---"
        $Manifest.prompts[$Path] = [ordered]@{
            path        = $Path
            maturity    = $Maturity
            collections = @('test')
        }
    }

    function Set-CoreManifestAgentBody {
        param(
            [Parameter(Mandatory = $true)]
            [string]$RootPath,

            [Parameter(Mandatory = $true)]
            [string]$Path,

            [Parameter(Mandatory = $true)]
            [string]$Body
        )

        $fullPath = Join-Path $RootPath $Path
        Set-Content -Path $fullPath -Value "---`ndescription: test agent`n---`n$Body"
    }

    function Set-CoreManifestAgentReferences {
        param(
            [Parameter(Mandatory = $true)]
            [string]$RootPath,

            [Parameter(Mandatory = $true)]
            [string]$Path,

            [Parameter()]
            [string[]]$RequiresAgents = @(),

            [Parameter()]
            [object[]]$Handoffs = @(),

            [Parameter()]
            [string]$Body = ''
        )

        $frontmatter = [ordered]@{ description = 'test agent' }
        if ($RequiresAgents.Count -gt 0) {
            $frontmatter.agents = @($RequiresAgents)
        }
        if ($Handoffs.Count -gt 0) {
            $frontmatter.handoffs = @($Handoffs)
        }

        $yaml = (ConvertTo-Yaml -Data $frontmatter).TrimEnd()
        $fullPath = Join-Path $RootPath $Path
        Set-Content -Path $fullPath -Value "---`n$yaml`n---`n$Body"
    }

    function Format-CoreManifestMaturityViolation {
        param(
            [Parameter(Mandatory = $true)]
            [string]$SourcePath,

            [Parameter(Mandatory = $true)]
            [string]$SourceMaturity,

            [Parameter(Mandatory = $true)]
            [string]$TargetPath,

            [Parameter(Mandatory = $true)]
            [string]$TargetMaturity,

            [Parameter(Mandatory = $true)]
            [string]$EdgeType
        )

        return "$SourcePath ($SourceMaturity) depends on $TargetPath ($TargetMaturity) via $EdgeType; higher-maturity assets must not depend on lower-maturity assets."
    }
}

Describe 'Invoke-CoreManifestValidation' {
    BeforeEach {
        $script:repoRoot = Join-Path $TestDrive 'repo'
        $script:manifestPath = Join-Path $script:repoRoot 'collections/core-manifest.yml'
        New-CoreManifestTestRepo -RootPath $script:repoRoot
    }

    It 'Passes for a valid central manifest' {
        $manifest = New-CoreManifestFixture
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $result = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath

        $result.Success | Should -BeTrue
        $result.ErrorCount | Should -Be 0
    }

    It 'Fails when a required top-level section is missing' {
        $manifest = New-CoreManifestFixture
        $manifest.Remove('schemaVersion')
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $result = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath

        $result.Success | Should -BeFalse
        $result.Errors -join "`n" | Should -Match "schemaVersion"
    }

    It 'Fails when an artifact key differs from its path' {
        $manifest = New-CoreManifestFixture
        $manifest.agents['.github/agents/test/test.agent.md'].path = '.github/agents/test/other.agent.md'
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $result = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath
        $result.Success | Should -BeFalse
        $result.Errors -join "`n" | Should -Match 'must match path'
    }

    It 'Fails for invalid artifact metadata' {
        $manifest = New-CoreManifestFixture
        $manifest.prompts['.github/prompts/test/test.prompt.md'].maturity = 'pilot'
        $manifest.prompts['.github/prompts/test/test.prompt.md'].collections = @('missing')
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $result = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath
        $result.Success | Should -BeFalse
        $result.Errors -join "`n" | Should -Match "invalid maturity 'pilot'"
        $result.Errors -join "`n" | Should -Match "unknown collection 'missing'"
    }

    It 'Allows missing artifact paths only when maturity is removed' {
        $manifest = New-CoreManifestFixture
        $manifest.agents['.github/agents/test/removed.agent.md'] = [ordered]@{
            path        = '.github/agents/test/removed.agent.md'
            maturity    = 'removed'
            collections = @('test')
        }
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $result = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath
        $result.Success | Should -BeTrue
    }

    It 'Does not warn when a removed artifact is present on disk' {
        $manifest = New-CoreManifestFixture
        Add-CoreManifestAgent -RootPath $script:repoRoot -Manifest $manifest -Path '.github/agents/test/kept.agent.md' -Name 'Kept Agent' -Maturity 'removed'
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $result = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath
        $result.Success | Should -BeTrue
        $result.Warnings -join "`n" | Should -Not -Match 'kept.agent.md'
    }

    It 'Fails when a non-removed artifact path is missing' {
        $manifest = New-CoreManifestFixture
        $manifest.agents['.github/agents/test/test.agent.md'].path = '.github/agents/test/missing.agent.md'
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $result = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath
        $result.Success | Should -BeFalse
        $result.Errors -join "`n" | Should -Match 'does not exist'
    }

    It 'Fails when a release artifact is excluded or not present in artifact sections' {
        $manifest = New-CoreManifestFixture
        $manifest.releases['test-release'].excludePaths = @('.github/agents/test/test.agent.md')
        $manifest.releases['test-release'].artifacts += '.github/agents/test/missing.agent.md'
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $result = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath
        $result.Success | Should -BeFalse
        $result.Errors -join "`n" | Should -Match 'lists excluded artifact'
        $result.Errors -join "`n" | Should -Match 'not present in manifest artifact sections'
    }

    It 'Fails when release includeMaturity excludes an artifact maturity' {
        $manifest = New-CoreManifestFixture
        $manifest.releases['test-release'].includeMaturity = @('stable')
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $result = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath
        $result.Success | Should -BeFalse
        $result.Errors -join "`n" | Should -Match "not included by includeMaturity"
    }

    It 'Allows deprecated release artifacts only with an explicit release flag' {
        $manifest = New-CoreManifestFixture
        $manifest.prompts['.github/prompts/test/test.prompt.md'].maturity = 'deprecated'
        $manifest.releases['test-release'].includeMaturity = @('stable', 'experimental', 'deprecated')
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $withoutFlag = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath
        $withoutFlag.Success | Should -BeFalse
        $withoutFlag.Errors -join "`n" | Should -Match 'without allowDeprecated: true'

        $manifest.releases['test-release'].allowDeprecated = $true
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $withFlag = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath
        $withFlag.Success | Should -BeTrue
    }

    It 'Fails when release metadata files are missing' {
        $manifest = New-CoreManifestFixture
        $manifest.releases['test-release'].whatNew.changelogPath = 'missing.md'
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $result = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath
        $result.Success | Should -BeFalse
        $result.Errors -join "`n" | Should -Match 'missing.md'
    }
}

Describe 'Export-CoreManifestValidationReport' {
    It 'Writes structured JSON output' {
        $outputPath = Join-Path $TestDrive 'logs/core-manifest-validation-results.json'
        $validationResult = @{
            Success      = $true
            ErrorCount   = 0
            WarningCount = 1
            Errors       = @()
            Warnings     = @('test warning')
        }

        Export-CoreManifestValidationReport -ValidationResult $validationResult -OutputPath $outputPath

        Test-Path -Path $outputPath | Should -BeTrue
        $report = Get-Content -Path $outputPath -Raw | ConvertFrom-Json
        $report.Success | Should -BeTrue
        $report.ErrorCount | Should -Be 0
        $report.WarningCount | Should -Be 1
        @($report.Warnings)[0] | Should -Be 'test warning'
    }
}

Describe 'Invoke-CoreManifestValidation maturity dependency rule' {
    BeforeEach {
        $script:repoRoot = Join-Path $TestDrive 'repo'
        $script:manifestPath = Join-Path $script:repoRoot 'collections/core-manifest.yml'
        $script:sourceAgent = '.github/agents/test/test.agent.md'
        New-CoreManifestTestRepo -RootPath $script:repoRoot
    }

    It 'T1: passes when no dependency edges exist' {
        $manifest = New-CoreManifestFixture
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $result = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath

        $result.Success | Should -BeTrue
        $result.ErrorCount | Should -Be 0
    }

    It 'T1a: fails when a manifest entry declares requires' {
        $manifest = New-CoreManifestFixture
        $manifest.agents[$script:sourceAgent].requires = [ordered]@{ agents = @('Exp Agent') }
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $result = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath

        $result.Success | Should -BeFalse
        $result.Errors | Should -Contain "agents entry '$script:sourceAgent' must not define 'requires'; declare subagent dependencies in the asset frontmatter 'agents' list instead."
    }

    It 'T1b: fails when a manifest entry declares handoffs' {
        $manifest = New-CoreManifestFixture
        $manifest.agents[$script:sourceAgent].handoffs = @(
            [ordered]@{ agent = 'Exp Agent'; label = 'Continue' }
        )
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $result = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath

        $result.Success | Should -BeFalse
        $result.Errors | Should -Contain "agents entry '$script:sourceAgent' must not define 'handoffs'; declare handoffs in the asset frontmatter instead."
    }

    It 'T2: fails when a stable agent requires an experimental agent' {
        $manifest = New-CoreManifestFixture
        Add-CoreManifestAgent -RootPath $script:repoRoot -Manifest $manifest -Path '.github/agents/test/exp.agent.md' -Name 'Exp Agent' -Maturity 'experimental'
        Set-CoreManifestAgentReferences -RootPath $script:repoRoot -Path $script:sourceAgent -RequiresAgents @('Exp Agent')
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $result = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath

        $result.Success | Should -BeFalse
        $result.ErrorCount | Should -Be 1
        $result.Errors | Should -Contain (Format-CoreManifestMaturityViolation -SourcePath $script:sourceAgent -SourceMaturity 'stable' -TargetPath '.github/agents/test/exp.agent.md' -TargetMaturity 'experimental' -EdgeType 'requires')
    }

    It 'T3: passes when an experimental agent requires an experimental agent' {
        $manifest = New-CoreManifestFixture
        $manifest.agents[$script:sourceAgent].maturity = 'experimental'
        Add-CoreManifestAgent -RootPath $script:repoRoot -Manifest $manifest -Path '.github/agents/test/exp.agent.md' -Name 'Exp Agent' -Maturity 'experimental'
        Set-CoreManifestAgentReferences -RootPath $script:repoRoot -Path $script:sourceAgent -RequiresAgents @('Exp Agent')
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $result = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath

        $result.Success | Should -BeTrue
        $result.ErrorCount | Should -Be 0
    }

    It 'T4: passes when an experimental agent requires a stable agent' {
        $manifest = New-CoreManifestFixture
        $manifest.agents[$script:sourceAgent].maturity = 'experimental'
        Add-CoreManifestAgent -RootPath $script:repoRoot -Manifest $manifest -Path '.github/agents/test/stable.agent.md' -Name 'Stable Agent' -Maturity 'stable'
        Set-CoreManifestAgentReferences -RootPath $script:repoRoot -Path $script:sourceAgent -RequiresAgents @('Stable Agent')
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $result = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath

        $result.Success | Should -BeTrue
        $result.ErrorCount | Should -Be 0
    }

    It 'T5: fails when a stable agent hands off to an experimental agent' {
        $manifest = New-CoreManifestFixture
        Add-CoreManifestAgent -RootPath $script:repoRoot -Manifest $manifest -Path '.github/agents/test/exp.agent.md' -Name 'Exp Agent' -Maturity 'experimental'
        Set-CoreManifestAgentReferences -RootPath $script:repoRoot -Path $script:sourceAgent -Handoffs @(
            [ordered]@{ agent = 'Exp Agent'; prompt = 'follow up manually'; label = 'Continue' }
        )
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $result = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath

        $result.Success | Should -BeFalse
        $result.ErrorCount | Should -Be 1
        $result.Errors | Should -Contain (Format-CoreManifestMaturityViolation -SourcePath $script:sourceAgent -SourceMaturity 'stable' -TargetPath '.github/agents/test/exp.agent.md' -TargetMaturity 'experimental' -EdgeType 'handoff-agent')
    }

    It 'T6: fails when a stable agent hands off via a slash command to an experimental prompt' {
        $manifest = New-CoreManifestFixture
        Add-CoreManifestAgent -RootPath $script:repoRoot -Manifest $manifest -Path '.github/agents/test/stable.agent.md' -Name 'Stable Agent' -Maturity 'stable'
        Add-CoreManifestPrompt -RootPath $script:repoRoot -Manifest $manifest -Path '.github/prompts/test/expprompt.prompt.md' -Maturity 'experimental'
        Set-CoreManifestAgentReferences -RootPath $script:repoRoot -Path $script:sourceAgent -Handoffs @(
            [ordered]@{ agent = 'Stable Agent'; prompt = '/expprompt'; label = 'Run' }
        )
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $result = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath

        $result.Success | Should -BeFalse
        $result.ErrorCount | Should -Be 1
        $result.Errors | Should -Contain (Format-CoreManifestMaturityViolation -SourcePath $script:sourceAgent -SourceMaturity 'stable' -TargetPath '.github/prompts/test/expprompt.prompt.md' -TargetMaturity 'experimental' -EdgeType 'handoff-prompt')
    }

    It 'T7: skips a free-text (non-slash) prompt handoff' {
        $manifest = New-CoreManifestFixture
        Add-CoreManifestAgent -RootPath $script:repoRoot -Manifest $manifest -Path '.github/agents/test/stable.agent.md' -Name 'Stable Agent' -Maturity 'stable'
        Add-CoreManifestPrompt -RootPath $script:repoRoot -Manifest $manifest -Path '.github/prompts/test/expprompt.prompt.md' -Maturity 'experimental'
        Set-CoreManifestAgentReferences -RootPath $script:repoRoot -Path $script:sourceAgent -Handoffs @(
            [ordered]@{ agent = 'Stable Agent'; prompt = 'expprompt by hand'; label = 'Run' }
        )
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $result = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath

        $result.Success | Should -BeTrue
        $result.ErrorCount | Should -Be 0
    }

    It 'T8: fails when a stable agent embeds a #file directive to an experimental instruction' {
        $manifest = New-CoreManifestFixture
        Set-CoreManifestAgentBody -RootPath $script:repoRoot -Path $script:sourceAgent -Body '#file:.github/instructions/test/test.instructions.md'
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $result = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath

        $result.Success | Should -BeFalse
        $result.ErrorCount | Should -Be 1
        $result.Errors | Should -Contain (Format-CoreManifestMaturityViolation -SourcePath $script:sourceAgent -SourceMaturity 'stable' -TargetPath '.github/instructions/test/test.instructions.md' -TargetMaturity 'experimental' -EdgeType 'embedded')
    }

    It 'T9: fails when a stable agent embeds a glob reference to an experimental agent' {
        $manifest = New-CoreManifestFixture
        Add-CoreManifestAgent -RootPath $script:repoRoot -Manifest $manifest -Path '.github/agents/test/exp.agent.md' -Name 'Exp Agent' -Maturity 'experimental'
        Set-CoreManifestAgentBody -RootPath $script:repoRoot -Path $script:sourceAgent -Body 'Delegates to .github/agents/**/exp.agent.md for the work.'
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $result = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath

        $result.Success | Should -BeFalse
        $result.ErrorCount | Should -Be 1
        $result.Errors | Should -Contain (Format-CoreManifestMaturityViolation -SourcePath $script:sourceAgent -SourceMaturity 'stable' -TargetPath '.github/agents/test/exp.agent.md' -TargetMaturity 'experimental' -EdgeType 'embedded')
    }

    It 'T10: does not flag a documentation-table mention or a bare directory glob' {
        $manifest = New-CoreManifestFixture
        Add-CoreManifestAgent -RootPath $script:repoRoot -Manifest $manifest -Path '.github/agents/test/exp.agent.md' -Name 'Exp Agent' -Maturity 'experimental'
        $body = @(
            '| Agent | Maturity |',
            '|-------|----------|',
            '| Exp Agent | experimental |',
            '',
            'See .github/agents/** for the full catalog.'
        ) -join "`n"
        Set-CoreManifestAgentBody -RootPath $script:repoRoot -Path $script:sourceAgent -Body $body
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $result = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath

        $result.Success | Should -BeTrue
        $result.ErrorCount | Should -Be 0
    }

    It 'T11: skips a deprecated target maturity' {
        $manifest = New-CoreManifestFixture
        Add-CoreManifestAgent -RootPath $script:repoRoot -Manifest $manifest -Path '.github/agents/test/dep.agent.md' -Name 'Dep Agent' -Maturity 'deprecated'
        Set-CoreManifestAgentReferences -RootPath $script:repoRoot -Path $script:sourceAgent -RequiresAgents @('Dep Agent')
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $result = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath

        $maturityViolations = @($result.Errors | Where-Object { $_ -like '*higher-maturity assets must not depend on lower-maturity assets.*' })
        $maturityViolations | Should -BeNullOrEmpty
    }

    It 'T12: skips a removed target maturity' {
        $manifest = New-CoreManifestFixture
        Add-CoreManifestAgent -RootPath $script:repoRoot -Manifest $manifest -Path '.github/agents/test/gone.agent.md' -Name 'Gone Agent' -Maturity 'removed'
        Set-CoreManifestAgentReferences -RootPath $script:repoRoot -Path $script:sourceAgent -RequiresAgents @('Gone Agent')
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $result = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath

        $maturityViolations = @($result.Errors | Where-Object { $_ -like '*higher-maturity assets must not depend on lower-maturity assets.*' })
        $maturityViolations | Should -BeNullOrEmpty
    }

    It 'T13: fails when a stable agent requires a preview agent' {
        $manifest = New-CoreManifestFixture
        Add-CoreManifestAgent -RootPath $script:repoRoot -Manifest $manifest -Path '.github/agents/test/prev.agent.md' -Name 'Prev Agent' -Maturity 'preview'
        Set-CoreManifestAgentReferences -RootPath $script:repoRoot -Path $script:sourceAgent -RequiresAgents @('Prev Agent')
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $result = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath

        $result.Success | Should -BeFalse
        $result.ErrorCount | Should -Be 1
        $result.Errors | Should -Contain (Format-CoreManifestMaturityViolation -SourcePath $script:sourceAgent -SourceMaturity 'stable' -TargetPath '.github/agents/test/prev.agent.md' -TargetMaturity 'preview' -EdgeType 'requires')
    }

    It 'T14: fails when a preview agent requires an experimental agent' {
        $manifest = New-CoreManifestFixture
        $manifest.agents[$script:sourceAgent].maturity = 'preview'
        Add-CoreManifestAgent -RootPath $script:repoRoot -Manifest $manifest -Path '.github/agents/test/exp.agent.md' -Name 'Exp Agent' -Maturity 'experimental'
        Set-CoreManifestAgentReferences -RootPath $script:repoRoot -Path $script:sourceAgent -RequiresAgents @('Exp Agent')
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $result = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath

        $result.Success | Should -BeFalse
        $result.ErrorCount | Should -Be 1
        $result.Errors | Should -Contain (Format-CoreManifestMaturityViolation -SourcePath $script:sourceAgent -SourceMaturity 'preview' -TargetPath '.github/agents/test/exp.agent.md' -TargetMaturity 'experimental' -EdgeType 'requires')
    }

    It 'T15: returns multiple violations deduplicated and in deterministic sorted order' {
        $manifest = New-CoreManifestFixture
        Add-CoreManifestAgent -RootPath $script:repoRoot -Manifest $manifest -Path '.github/agents/test/exp-a.agent.md' -Name 'Exp A' -Maturity 'experimental'
        Add-CoreManifestAgent -RootPath $script:repoRoot -Manifest $manifest -Path '.github/agents/test/exp-b.agent.md' -Name 'Exp B' -Maturity 'experimental'
        Set-CoreManifestAgentReferences -RootPath $script:repoRoot -Path $script:sourceAgent -RequiresAgents @('Exp A', 'Exp B') -Handoffs @(
            [ordered]@{ agent = 'Exp A'; prompt = 'follow up manually'; label = 'Continue' }
        ) -Body '#file:.github/instructions/test/test.instructions.md'
        Write-CoreManifestFixture -ManifestPath $script:manifestPath -Manifest $manifest

        $result = Invoke-CoreManifestValidation -RepoRoot $script:repoRoot -ManifestPath $script:manifestPath

        $expected = @(
            (Format-CoreManifestMaturityViolation -SourcePath $script:sourceAgent -SourceMaturity 'stable' -TargetPath '.github/instructions/test/test.instructions.md' -TargetMaturity 'experimental' -EdgeType 'embedded'),
            (Format-CoreManifestMaturityViolation -SourcePath $script:sourceAgent -SourceMaturity 'stable' -TargetPath '.github/agents/test/exp-a.agent.md' -TargetMaturity 'experimental' -EdgeType 'handoff-agent'),
            (Format-CoreManifestMaturityViolation -SourcePath $script:sourceAgent -SourceMaturity 'stable' -TargetPath '.github/agents/test/exp-a.agent.md' -TargetMaturity 'experimental' -EdgeType 'requires'),
            (Format-CoreManifestMaturityViolation -SourcePath $script:sourceAgent -SourceMaturity 'stable' -TargetPath '.github/agents/test/exp-b.agent.md' -TargetMaturity 'experimental' -EdgeType 'requires')
        )
        $maturityViolations = @($result.Errors | Where-Object { $_ -like '*higher-maturity assets must not depend on lower-maturity assets.*' })

        $result.Success | Should -BeFalse
        $maturityViolations | Should -Be $expected
    }
}

Describe 'Invoke-CoreManifestValidation against the real core manifest' {
    It 'T16: reports no maturity dependency violations for collections/core-manifest.yml' {
        $realRepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
        $realManifestPath = Join-Path $realRepoRoot 'collections/core-manifest.yml'

        $result = Invoke-CoreManifestValidation -RepoRoot $realRepoRoot -ManifestPath $realManifestPath

        $maturityViolations = @($result.Errors | Where-Object { $_ -like '*higher-maturity assets must not depend on lower-maturity assets.*' })
        $maturityViolations | Should -BeNullOrEmpty
    }
}

Describe 'Get-CoreManifestArtifactSectionNames' {
    It 'T17: returns the four artifact section names in order' {
        Get-CoreManifestArtifactSectionNames | Should -Be @('agents', 'prompts', 'instructions', 'skills')
    }
}

Describe 'Resolve-CoreManifestEmbeddedToken' {
    BeforeEach {
        $script:maturityMap = @{
            '.github/agents/test/exp.agent.md'               = 'experimental'
            '.github/instructions/test/test.instructions.md' = 'experimental'
            '.github/skills/test/test-skill'                 = 'stable'
        }
    }

    It 'T18: resolves a direct asset path' {
        Resolve-CoreManifestEmbeddedToken -Token '.github/agents/test/exp.agent.md' -MaturityMap $script:maturityMap |
            Should -Be @('.github/agents/test/exp.agent.md')
    }

    It 'T19: resolves a /SKILL.md suffix to its skill directory' {
        Resolve-CoreManifestEmbeddedToken -Token '.github/skills/test/test-skill/SKILL.md' -MaturityMap $script:maturityMap |
            Should -Be @('.github/skills/test/test-skill')
    }

    It 'T20: resolves a glob by matching its file basename' {
        Resolve-CoreManifestEmbeddedToken -Token '.github/agents/**/exp.agent.md' -MaturityMap $script:maturityMap |
            Should -Be @('.github/agents/test/exp.agent.md')
    }

    It 'T21: returns nothing for a bare directory glob without a concrete file name' {
        @(Resolve-CoreManifestEmbeddedToken -Token '.github/agents/**' -MaturityMap $script:maturityMap) |
            Should -BeNullOrEmpty
    }

    It 'T22: returns nothing for an unknown path' {
        @(Resolve-CoreManifestEmbeddedToken -Token '.github/agents/test/missing.agent.md' -MaturityMap $script:maturityMap) |
            Should -BeNullOrEmpty
    }

    It 'T23: emits a verbose message for a malformed glob whose final segment is still a glob' {
        $messages = Resolve-CoreManifestEmbeddedToken -Token '.github/agents/test/*' -MaturityMap $script:maturityMap -Verbose 4>&1
        @($messages | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }) | Should -Not -BeNullOrEmpty
    }
}