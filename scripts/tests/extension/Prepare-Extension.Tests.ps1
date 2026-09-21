#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../extension/Prepare-Extension.ps1')
    Import-Module (Join-Path $PSScriptRoot 'ExtensionTestFixtures.psm1') -Force
    $script:PrepareScriptPath = (Resolve-Path (Join-Path $PSScriptRoot '../../extension/Prepare-Extension.ps1')).Path

    function script:New-PluginFixtureRepo {
        <#
        .SYNOPSIS
        Builds a repository fixture whose only membership authority is plugin.json.
        .PARAMETER Path
        Root directory to populate.
        .PARAMETER Manifest
        Plugin manifest content.
        .OUTPUTS
        [hashtable] Fixture paths.
        #>
        [CmdletBinding()]
        [OutputType([hashtable])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Path,

            [Parameter(Mandatory = $false)]
            [AllowNull()]
            [System.Collections.IDictionary]$Manifest
        )

        $fixture = New-ExtensionFixtureRepo -Path $Path
        # The marketplace catalog must not participate in preparation; removing it
        # makes any surviving catalog read fail loudly instead of passing silently.
        Remove-Item -LiteralPath $fixture.CatalogPath -Force
        if ($null -ne $Manifest) {
            Set-FixtureFile -Path (Join-Path $fixture.RepoRoot 'plugin.json') `
                -Value (($Manifest | ConvertTo-Json -Depth 8) + "`n")
        }
        return $fixture
    }

    function script:Get-PluginManifestFixture {
        <#
        .SYNOPSIS
        Returns the deterministic plugin manifest used by preparation tests.
        .OUTPUTS
        [System.Collections.Specialized.OrderedDictionary] Manifest content.
        #>
        [CmdletBinding()]
        [OutputType([System.Collections.Specialized.OrderedDictionary])]
        param()

        return [ordered]@{
            name        = 'hve-core'
            description = 'Manifest fixture description'
            version     = '9.9.9'
            agents      = @('.github/agents/labs/gamma.agent.md', '.github/agents/core/alpha.agent.md')
            commands    = @('.github/prompts/core/build.prompt.md')
            rules       = @('.github/instructions/core/style.instructions.md')
            skills      = @('.github/skills/labs/probe', '.github/skills/core/toolkit')
            hooks       = '.github/hooks/core/session.json'
        }
    }

    Mock Write-Host {}
}

Describe 'Prepare-Extension plugin manifest reading' -Tag 'Unit' {
    BeforeAll {
        $script:ManifestFixture = New-PluginFixtureRepo -Path (Join-Path $TestDrive 'manifest-repo') -Manifest (Get-PluginManifestFixture)
        $script:ManifestPath = Join-Path $script:ManifestFixture.RepoRoot 'plugin.json'
    }

    It 'Reads the manifest as the component authority' {
        (Get-PluginManifest -Path $script:ManifestPath).description | Should -BeExactly 'Manifest fixture description'
    }

    It 'Throws with the manifest path when the manifest is absent' {
        $absent = Join-Path $script:ManifestFixture.RepoRoot '.github/absent.json'
        { Get-PluginManifest -Path $absent } | Should -Throw "Plugin manifest not found: $absent"
    }

    It 'Declares only the dry-run parameter' {
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:PrepareScriptPath, [ref]$null, [ref]$parseErrors)
        $parseErrors | Should -BeNullOrEmpty
        @($ast.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath }) | Should -Be @('DryRun')
    }
}

Describe 'Prepare-Extension component projection' -Tag 'Unit' {
    BeforeAll {
        $script:Components = @(Get-PluginComponent -Manifest ([pscustomobject](Get-PluginManifestFixture)))
    }

    It 'Maps <Field> entries to kind <Kind> under .github' -ForEach @(
        @{ Field = 'agents'; Kind = 'agent'; Expected = @('.github/agents/labs/gamma.agent.md', '.github/agents/core/alpha.agent.md') }
        @{ Field = 'commands'; Kind = 'prompt'; Expected = @('.github/prompts/core/build.prompt.md') }
        @{ Field = 'rules'; Kind = 'instruction'; Expected = @('.github/instructions/core/style.instructions.md') }
        @{ Field = 'skills'; Kind = 'skill'; Expected = @('.github/skills/labs/probe', '.github/skills/core/toolkit') }
    ) {
        @($script:Components | Where-Object { $_.Kind -eq $Kind } | ForEach-Object { $_.SourcePath }) | Should -Be $Expected
    }

    It 'Projects every declared component exactly once' {
        @($script:Components).Count | Should -Be 6
        @($script:Components.SourcePath | Sort-Object -Unique).Count | Should -Be 6
    }

    It 'Projects no hook component' {
        @($script:Components | Where-Object { $_.SourcePath -like '*hooks*' }) | Should -HaveCount 0
    }

    It 'Skips empty manifest fields' {
        $manifest = [pscustomobject]@{ agents = @('.github/agents/core/alpha.agent.md'); commands = @(); rules = $null; skills = @('') }
        @(Get-PluginComponent -Manifest $manifest).SourcePath | Should -Be @('.github/agents/core/alpha.agent.md')
    }

    It 'Rejects malformed <Field> path <Path>' -ForEach @(
        @{ Field = 'agents'; Path = '../package.json' }
        @{ Field = 'agents'; Path = 'agents/core/../../../package.json.agent.md' }
        @{ Field = 'commands'; Path = '/etc/passwd' }
        @{ Field = 'commands'; Path = 'prompts/core/*.prompt.md' }
        @{ Field = 'rules'; Path = 'instructions/core/style.md' }
        @{ Field = 'skills'; Path = 'skills/core/toolkit/SKILL.md' }
    ) {
        $manifest = [pscustomobject]@{ agents = @(); commands = @(); rules = @(); skills = @() }
        $manifest.$Field = @($Path)

        { Get-PluginComponent -Manifest $manifest } |
            Should -Throw "Plugin manifest $Field entry '$Path' is not a contained artifact path."
    }
}

Describe 'Prepare-Extension contributions' -Tag 'Unit' {
    BeforeAll {
        $script:Contributions = Get-ExtensionContributions -Items @(Get-PluginComponent -Manifest ([pscustomobject](Get-PluginManifestFixture)))
    }

    It 'Emits the exact agent contribution inventory sorted by name' {
        @($script:Contributions.Agents.name) | Should -Be @('alpha', 'gamma')
        @($script:Contributions.Agents.path) | Should -Be @('./.github/agents/core/alpha.agent.md', './.github/agents/labs/gamma.agent.md')
    }

    It 'Emits the exact prompt contribution inventory' {
        @($script:Contributions.Prompts.name) | Should -Be @('build')
        @($script:Contributions.Prompts.path) | Should -Be @('./.github/prompts/core/build.prompt.md')
    }

    It 'Suffixes instruction contribution names and keeps canonical paths' {
        @($script:Contributions.Instructions.name) | Should -Be @('style-instructions')
        @($script:Contributions.Instructions.path) | Should -Be @('./.github/instructions/core/style.instructions.md')
    }

    It 'Points skill contributions at the SKILL.md entry file' {
        @($script:Contributions.Skills.name) | Should -Be @('probe', 'toolkit')
        @($script:Contributions.Skills.path) | Should -Be @('./.github/skills/labs/probe/SKILL.md', './.github/skills/core/toolkit/SKILL.md')
    }

    It 'Exposes exactly the four VS Code contribution buckets' {
        @($script:Contributions.Keys | Sort-Object) | Should -Be @('Agents', 'Instructions', 'Prompts', 'Skills')
    }
}

Describe 'Prepare-Extension manifest contributes' -Tag 'Unit' {
    BeforeAll {
        $script:BaseManifest = [pscustomobject]@{ name = 'hve-core'; version = '1.2.3' }
        $script:Updated = Update-PackageJsonContributes -PackageJson $script:BaseManifest `
            -ChatAgents @([pscustomobject]@{ name = 'alpha'; path = './a' }) `
            -ChatPromptFiles @() `
            -ChatInstructions @([pscustomobject]@{ name = 'style-instructions'; path = './s' }) `
            -ChatSkills @([pscustomobject]@{ name = 'toolkit'; path = './t/SKILL.md' })
    }

    It 'Writes contribution keys in a deterministic order' {
        @($script:Updated.contributes.PSObject.Properties.Name) |
            Should -Be @('chatAgents', 'chatPromptFiles', 'chatInstructions', 'chatSkills')
    }

    It 'Serializes contribution keys in the same deterministic order' {
        $serialized = $script:Updated | ConvertTo-Json -Depth 20
        $order = @([regex]::Matches($serialized, '"(chatAgents|chatPromptFiles|chatInstructions|chatSkills)"') |
                ForEach-Object { $_.Groups[1].Value })
        $order | Should -Be @('chatAgents', 'chatPromptFiles', 'chatInstructions', 'chatSkills')
    }

    It 'Preserves empty contribution buckets' {
        $script:Updated.contributes.chatPromptFiles | Should -HaveCount 0
    }

    It 'Leaves the source manifest untouched' {
        $script:BaseManifest.PSObject.Properties['contributes'] | Should -BeNullOrEmpty
    }
}

Describe 'Prepare-Extension one-package preparation' -Tag 'Unit' {
    BeforeEach {
        $script:Fixture = New-PluginFixtureRepo -Path (Join-Path $TestDrive "prepare-$([guid]::NewGuid().ToString('N'))") -Manifest (Get-PluginManifestFixture)
        $script:Result = Invoke-PrepareExtension -ExtensionDirectory $script:Fixture.ExtensionDirectory -RepoRoot $script:Fixture.RepoRoot
        $script:Package = Get-Content -LiteralPath (Join-Path $script:Fixture.ExtensionDirectory 'package.json') -Raw | ConvertFrom-Json
    }

    It 'Reports the template version and every contribution count' {
        $script:Result.Success | Should -BeTrue
        $script:Result.ErrorMessage | Should -BeExactly ''
        $script:Result.Version | Should -BeExactly '9.9.9'
        $script:Result.AgentCount | Should -Be 2
        $script:Result.PromptCount | Should -Be 1
        $script:Result.InstructionCount | Should -Be 1
        $script:Result.SkillCount | Should -Be 2
    }

    It 'Keeps the single template identity and takes the manifest description' {
        $script:Package.name | Should -BeExactly 'hve-core'
        $script:Package.displayName | Should -BeExactly 'Fixture Core'
        $script:Package.description | Should -BeExactly 'Manifest fixture description'
    }

    It 'Writes every manifest component into the extension contributions' {
        @($script:Package.contributes.chatAgents.name) | Should -Be @('alpha', 'gamma')
        @($script:Package.contributes.chatPromptFiles.name) | Should -Be @('build')
        @($script:Package.contributes.chatInstructions.name) | Should -Be @('style-instructions')
        @($script:Package.contributes.chatSkills.name) | Should -Be @('probe', 'toolkit')
    }

    It 'Generates only the unsuffixed package manifest and README' {
        $generated = [string[]]@(Get-ChildItem -LiteralPath $script:Fixture.ExtensionDirectory -File |
                Where-Object { $_.Name -like 'package*.json' -or $_.Name -like 'README*.md' } |
                ForEach-Object { $_.Name })
        [array]::Sort($generated, [System.StringComparer]::Ordinal)
        $generated | Should -Be @('README.md', 'README.obsolete.md', 'package.json', 'package.obsolete.json')
    }

    It 'Deletes no pre-existing extension file' {
        Test-Path -LiteralPath (Join-Path $script:Fixture.ExtensionDirectory 'package.obsolete.json') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $script:Fixture.ExtensionDirectory 'README.obsolete.md') | Should -BeTrue
    }

    It 'Renders the README from the manifest description and durable document' {
        $readme = Get-Content -LiteralPath (Join-Path $script:Fixture.ExtensionDirectory 'README.md') -Raw
        $readme | Should -Match '(?m)^# Fixture Core$'
        $readme | Should -Match '(?m)^> Manifest fixture description$'
        $readme | Should -Match 'Fixture Core intro paragraph\.'
    }

    It 'Renders artifact tables without a maturity column' {
        $readme = Get-Content -LiteralPath (Join-Path $script:Fixture.ExtensionDirectory 'README.md') -Raw
        $readme | Should -Match '\| Name \| Description \|'
        $readme | Should -Not -Match '\| Name \| Maturity \| Description \|'
        $readme | Should -Match '\| \*\*alpha\*\* \| Alpha fixture agent \|'
        $readme | Should -Match '\| \*\*toolkit\*\* \| Toolkit fixture skill \|'
    }

    It 'Excludes the durable document artifact table' {
        Get-Content -LiteralPath (Join-Path $script:Fixture.ExtensionDirectory 'README.md') -Raw |
            Should -Not -Match 'Durable table that must never reach the extension README'
    }
}

Describe 'Prepare-Extension channel parity' -Tag 'Unit' {
    It 'Produces byte-identical output for Stable and PreRelease' {
        $outputs = @{}
        foreach ($channel in @('Stable', 'PreRelease')) {
            $fixture = New-PluginFixtureRepo -Path (Join-Path $TestDrive "channel-$channel") -Manifest (Get-PluginManifestFixture)
            Invoke-PrepareExtension -ExtensionDirectory $fixture.ExtensionDirectory -RepoRoot $fixture.RepoRoot | Out-Null
            $outputs[$channel] = @{
                Package = Get-Content -LiteralPath (Join-Path $fixture.ExtensionDirectory 'package.json') -Raw
                Readme  = Get-Content -LiteralPath (Join-Path $fixture.ExtensionDirectory 'README.md') -Raw
            }
        }
        $outputs['PreRelease'].Package | Should -BeExactly $outputs['Stable'].Package
        $outputs['PreRelease'].Readme | Should -BeExactly $outputs['Stable'].Readme
    }
}

Describe 'Prepare-Extension failure and dry-run behavior' -Tag 'Unit' {
    BeforeEach {
        $script:FailureFixture = New-PluginFixtureRepo -Path (Join-Path $TestDrive "failure-$([guid]::NewGuid().ToString('N'))") -Manifest (Get-PluginManifestFixture)
        $script:OriginalPackage = Get-Content -LiteralPath (Join-Path $script:FailureFixture.ExtensionDirectory 'package.json') -Raw
    }

    It 'Writes nothing under DryRun' {
        $result = Invoke-PrepareExtension -ExtensionDirectory $script:FailureFixture.ExtensionDirectory `
            -RepoRoot $script:FailureFixture.RepoRoot -DryRun

        $result.Success | Should -BeTrue
        $result.AgentCount | Should -Be 2
        Get-Content -LiteralPath (Join-Path $script:FailureFixture.ExtensionDirectory 'package.json') -Raw |
            Should -BeExactly $script:OriginalPackage
        Get-Content -LiteralPath (Join-Path $script:FailureFixture.ExtensionDirectory 'README.md') -Raw |
            Should -BeExactly "# Placeholder`n"
    }

    It 'Fails when the plugin manifest is absent' {
        Remove-Item -LiteralPath (Join-Path $script:FailureFixture.RepoRoot 'plugin.json') -Force

        $result = Invoke-PrepareExtension -ExtensionDirectory $script:FailureFixture.ExtensionDirectory -RepoRoot $script:FailureFixture.RepoRoot
        $result.Success | Should -BeFalse
        $result.ErrorMessage | Should -BeLike 'Plugin manifest not found:*'
    }

    It 'Fails when the plugin manifest declares no components' {
        Set-FixtureFile -Path (Join-Path $script:FailureFixture.RepoRoot 'plugin.json') `
            -Value (([ordered]@{ name = 'hve-core'; description = 'Empty'; hooks = '.github/hooks/core/session.json' } | ConvertTo-Json -Depth 4) + "`n")

        $result = Invoke-PrepareExtension -ExtensionDirectory $script:FailureFixture.ExtensionDirectory -RepoRoot $script:FailureFixture.RepoRoot
        $result.Success | Should -BeFalse
        $result.ErrorMessage | Should -BeExactly 'Plugin manifest declares no extension components.'
    }

    It 'Fails before writing when the plugin manifest declares an escaping component' {
        $manifestPath = Join-Path $script:FailureFixture.RepoRoot 'plugin.json'
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        $manifest.agents = @('../package.json')
        Set-FixtureFile -Path $manifestPath -Value (($manifest | ConvertTo-Json -Depth 8) + "`n")

        $result = Invoke-PrepareExtension -ExtensionDirectory $script:FailureFixture.ExtensionDirectory -RepoRoot $script:FailureFixture.RepoRoot

        $result.Success | Should -BeFalse
        $result.ErrorMessage | Should -BeExactly "Plugin manifest agents entry '../package.json' is not a contained artifact path."
        Get-Content -LiteralPath (Join-Path $script:FailureFixture.ExtensionDirectory 'package.json') -Raw |
            Should -BeExactly $script:OriginalPackage
    }

    It 'Fails when the package template declares an invalid version' {
        $templatePath = Join-Path $script:FailureFixture.RepoRoot 'extension/templates/package.template.json'
        $template = Get-Content -LiteralPath $templatePath -Raw -Encoding utf8 | ConvertFrom-Json
        $template.version = '9.9'
        Set-FixtureFile -Path $templatePath -Value (($template | ConvertTo-Json -Depth 8) + "`n")

        $result = Invoke-PrepareExtension -ExtensionDirectory $script:FailureFixture.ExtensionDirectory -RepoRoot $script:FailureFixture.RepoRoot
        $result.Success | Should -BeFalse
        $result.ErrorMessage | Should -BeExactly 'Invalid version format in package template: 9.9'
    }

    It 'Fails when a required template is missing' {
        $readmeTemplatePath = Join-Path $script:FailureFixture.RepoRoot 'extension/templates/README.template.md'
        Remove-Item -LiteralPath $readmeTemplatePath -Force

        $result = Invoke-PrepareExtension -ExtensionDirectory $script:FailureFixture.ExtensionDirectory -RepoRoot $script:FailureFixture.RepoRoot
        $result.Success | Should -BeFalse
        $result.ErrorMessage | Should -BeExactly "README template not found: $readmeTemplatePath"
    }
}

AfterAll {
    Remove-Module ExtensionTestFixtures -Force -ErrorAction SilentlyContinue
}
