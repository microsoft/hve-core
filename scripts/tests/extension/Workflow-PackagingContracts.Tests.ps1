#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    # MarketplaceHelpers reloads its nested ArtifactHelpers dependency, so shared
    # modules load before the scripts whose own imports settle the session state.
    Import-Module (Join-Path $PSScriptRoot '../../lib/Modules/MarketplaceHelpers.psm1') -Force
    . (Join-Path $PSScriptRoot '../../extension/Get-MarketplacePackageMatrix.ps1')
    . (Join-Path $PSScriptRoot '../../extension/Package-Extension.ps1')

    $script:RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $script:WorkflowDirectory = Join-Path $script:RepositoryRoot '.github/workflows'
    $script:CatalogPath = Join-Path $script:RepositoryRoot '.github/plugin/marketplace.json'
    $script:RootManifest = Get-Content -LiteralPath (Join-Path $script:RepositoryRoot 'package.json') -Raw -Encoding utf8 | ConvertFrom-Json

    function Get-WorkflowText {
        <#
        .SYNOPSIS
        Reads raw workflow text.
        .PARAMETER Name
        Workflow file name.
        .OUTPUTS
        [string] Raw workflow content.
        #>
        [CmdletBinding()]
        [OutputType([string])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Name
        )

        return Get-Content -LiteralPath (Join-Path $script:WorkflowDirectory $Name) -Raw -Encoding utf8
    }

    function Get-WorkflowDocument {
        <#
        .SYNOPSIS
        Parses one workflow file.
        .PARAMETER Name
        Workflow file name.
        .OUTPUTS
        [System.Collections.IDictionary] Parsed workflow.
        #>
        [CmdletBinding()]
        [OutputType([System.Collections.IDictionary])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Name
        )

        return (Get-WorkflowText -Name $Name | ConvertFrom-Yaml)
    }

    function Get-JobStepText {
        <#
        .SYNOPSIS
        Returns the run and uses text of every step in a job, in declaration order.
        .PARAMETER Document
        Parsed workflow.
        .PARAMETER JobName
        Job identifier.
        .OUTPUTS
        [string[]] Step text in order.
        #>
        [CmdletBinding()]
        [OutputType([string[]])]
        param(
            [Parameter(Mandatory = $true)]
            [System.Collections.IDictionary]$Document,

            [Parameter(Mandatory = $true)]
            [string]$JobName
        )

        $steps = @($Document['jobs'][$JobName]['steps'])
        return [string[]]@($steps | ForEach-Object {
                $run = if ($_.Contains('run')) { [string]$_['run'] } else { '' }
                $uses = if ($_.Contains('uses')) { [string]$_['uses'] } else { '' }
                "$uses`n$run"
            })
    }

    function Get-NamedJobStep {
        <#
        .SYNOPSIS
        Returns the single step of a job carrying an exact display name.
        .PARAMETER Document
        Parsed workflow.
        .PARAMETER JobName
        Job identifier.
        .PARAMETER StepName
        Step display name.
        .OUTPUTS
        [System.Collections.IDictionary] Matching step.
        #>
        [CmdletBinding()]
        [OutputType([System.Collections.IDictionary])]
        param(
            [Parameter(Mandatory = $true)]
            [System.Collections.IDictionary]$Document,

            [Parameter(Mandatory = $true)]
            [string]$JobName,

            [Parameter(Mandatory = $true)]
            [string]$StepName
        )

        $found = @($Document['jobs'][$JobName]['steps'] | Where-Object { [string]$_['name'] -eq $StepName })
        if ($found.Count -ne 1) {
            throw "Job '$JobName' must declare exactly one step named '$StepName' but declared $($found.Count)"
        }
        return $found[0]
    }

    function ConvertTo-SortedJson {
        <#
        .SYNOPSIS
        Renders parsed JSON as key-sorted canonical text so structures compare independently of key order.
        .PARAMETER InputObject
        Parsed JSON value.
        .OUTPUTS
        [string] Canonical JSON text.
        #>
        [CmdletBinding()]
        [OutputType([string])]
        param(
            [Parameter(Mandatory = $false)]
            [AllowNull()]
            $InputObject
        )

        if ($InputObject -is [System.Collections.IDictionary]) {
            $keys = [string[]]@($InputObject.Keys)
            [array]::Sort($keys, [System.StringComparer]::Ordinal)
            $pairs = foreach ($key in $keys) {
                '{0}:{1}' -f (ConvertTo-Json -InputObject $key -Compress), (ConvertTo-SortedJson -InputObject $InputObject[$key])
            }
            return '{' + [string]::Join(',', @($pairs)) + '}'
        }
        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
            $items = foreach ($item in $InputObject) { ConvertTo-SortedJson -InputObject $item }
            return '[' + [string]::Join(',', @($items)) + ']'
        }
        return (ConvertTo-Json -InputObject $InputObject -Compress)
    }

    function Get-ScriptArrayLiteral {
        <#
        .SYNOPSIS
        Extracts string array literals declared inside a named function.
        .PARAMETER ScriptPath
        Script to parse.
        .PARAMETER FunctionName
        Function to inspect.
        .OUTPUTS
        [string[]] Literal string elements.
        #>
        [CmdletBinding()]
        [OutputType([string[]])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$ScriptPath,

            [Parameter(Mandatory = $true)]
            [string]$FunctionName
        )

        $ast = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$null, [ref]$null)
        $function = @($ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) |
                Where-Object { $_.Name -eq $FunctionName })
        $literals = @($function[0].FindAll({ $args[0] -is [System.Management.Automation.Language.ArrayLiteralAst] }, $true) |
                Where-Object { @($_.Elements | Where-Object { $_ -isnot [System.Management.Automation.Language.StringConstantExpressionAst] }).Count -eq 0 })
        return [string[]]@($literals | ForEach-Object { $_.Elements.Value })
    }
}
Describe 'Package discovery parity' -Tag 'Unit' {
    BeforeAll {
        $script:DiscoveryWorkflows = @(
            @{ Workflow = 'extension-package.yml'; Job = 'discover-packages' }
            @{ Workflow = 'extension-provenance.yml'; Job = 'discover-packages' }
            @{ Workflow = 'release-marketplace-stable.yml'; Job = 'discover' }
            @{ Workflow = 'plugin-package.yml'; Job = 'discover-packages' }
        )
    }

    It 'Discovers packages through the shared script in <Workflow>' -ForEach @(
        @{ Workflow = 'extension-package.yml'; Job = 'discover-packages' }
        @{ Workflow = 'extension-provenance.yml'; Job = 'discover-packages' }
        @{ Workflow = 'release-marketplace-stable.yml'; Job = 'discover' }
        @{ Workflow = 'plugin-package.yml'; Job = 'discover-packages' }
    ) {
        $steps = Get-JobStepText -Document (Get-WorkflowDocument -Name $Workflow) -JobName $Job
        @($steps | Where-Object { $_ -match 'scripts/extension/Get-MarketplacePackageMatrix\.ps1' }) |
            Should -HaveCount 1 -Because "$Workflow job '$Job' must use the single discovery script"
        @($steps | Where-Object { $_ -match '\./\.github/actions/setup-ps-modules' }) |
            Should -HaveCount 1 -Because "$Workflow job '$Job' runs PowerShell that needs pinned modules"
    }

    It 'Runs plugin discovery on the PreRelease policy' {
        $steps = Get-JobStepText -Document (Get-WorkflowDocument -Name 'plugin-package.yml') -JobName 'discover-packages'
        @($steps | Where-Object { $_ -match "Get-MarketplacePackageMatrix\.ps1 -Channel 'PreRelease'" }) | Should -HaveCount 1
    }

    It 'Keeps no duplicated maturity filtering in plugin discovery' {
        $steps = Get-JobStepText -Document (Get-WorkflowDocument -Name 'plugin-package.yml') -JobName 'discover-packages'
        @($steps | Where-Object { $_ -match 'jq ' }) | Should -HaveCount 0
        (Get-WorkflowText -Name 'plugin-package.yml') | Should -Not -Match 'x-hve'
    }

    It 'Consumes the shared names output for generated root verification' {
        $document = Get-WorkflowDocument -Name 'plugin-package.yml'
        [string]$document['jobs']['discover-packages']['outputs']['names'] | Should -BeExactly '${{ steps.discover.outputs.names }}'
        $verification = @($document['jobs']['package']['steps'] | Where-Object {
                $_.Contains('run') -and [string]$_['run'] -match 'Generated package roots do not match'
            })
        $verification | Should -HaveCount 1
        [string]$verification[0]['env']['DISCOVERED_NAMES'] | Should -BeExactly '${{ needs.discover-packages.outputs.names }}'
        $run = [string]$verification[0]['run']
        $run | Should -Match "jq -r '\.\[\]' \| sort"
        $run | Should -Match 'find "\$\{HVE_PLUGIN_STAGING_ROOT\}" -mindepth 1 -maxdepth 1 -type d'
        $run | Should -Match '\[ "\$expected" != "\$actual" \]'
        $run | Should -Not -Match '-eq 1\b|== 1\b'
    }

    It 'Produces the same PreRelease package set the plugin policy requires' {
        $catalog = Get-Content -LiteralPath $script:CatalogPath -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable
        $pluginPolicy = foreach ($entry in $catalog['plugins']) {
            $overlay = if ($entry.Contains('x-hve')) { $entry['x-hve'] } else { @{} }
            $maturity = if ($overlay.Contains('maturity')) { [string]$overlay['maturity'] } else { 'stable' }
            if ($maturity -in @('deprecated', 'removed')) { continue }
            [string]$entry['name']
        }
        $expected = [string[]]@($pluginPolicy)
        [array]::Sort($expected, [System.StringComparer]::Ordinal)
        @($expected).Count | Should -BeGreaterThan 0
        @((Get-MarketplacePackageMatrixCore -Channel PreRelease -CatalogPath $script:CatalogPath).Names) | Should -Be $expected
    }

    It 'Restricts the Stable extension policy to a subset of the plugin policy' {
        $stable = @((Get-MarketplacePackageMatrixCore -Channel Stable -CatalogPath $script:CatalogPath).Names)
        $preRelease = @((Get-MarketplacePackageMatrixCore -Channel PreRelease -CatalogPath $script:CatalogPath).Names)
        @($stable).Count | Should -BeGreaterThan 0
        foreach ($name in $stable) { $preRelease | Should -Contain $name }
    }
}
# End release packaging contracts.
Describe 'Packaging workflow arguments' -Tag 'Unit' {
    It 'Passes the matrix package ID into both packaging scripts in <Workflow>' -ForEach @(
        @{ Workflow = 'extension-package.yml'; Job = 'package' }
        @{ Workflow = 'extension-provenance.yml'; Job = 'build-attest' }
    ) {
        $steps = Get-JobStepText -Document (Get-WorkflowDocument -Name $Workflow) -JobName $Job
        @($steps | Where-Object { $_ -match 'Prepare-Extension\.ps1 .*-PackageId \$packageId' }) | Should -HaveCount 1
        @($steps | Where-Object { $_ -match "\`$packageId = ""(\`${{ matrix\.id }}|\`$env:PACKAGE_ID)""" }) | Should -HaveCount 2
        @($steps | Where-Object { $_ -match "PackageId\s+=\s+\`$packageId" }) | Should -HaveCount 1
    }

    It 'Selects the release VSIX by package ID during publish' {
        $steps = Get-JobStepText -Document (Get-WorkflowDocument -Name 'extension-marketplace-publish.yml') -JobName 'publish'
        @($steps | Where-Object { $_ -match 'Select-PackageVsix\.ps1 -AssetDirectory \$env:ASSET_DIRECTORY -PackageId \$env:PACKAGE_ID' }) | Should -HaveCount 1
    }

    It 'Resolves the extension identity from the shared module during publish' {
        $steps = Get-JobStepText -Document (Get-WorkflowDocument -Name 'extension-marketplace-publish.yml') -JobName 'publish'
        @($steps | Where-Object { $_ -match 'scripts/extension/Modules/ExtensionIdentity\.psm1' }) | Should -HaveCount 1
        @($steps | Where-Object { $_ -match 'EXTENSION_NAME=\$identity' }) | Should -HaveCount 1
    }

    It 'Downloads release assets with an identity-scoped glob' {
        $text = Get-WorkflowText -Name 'extension-marketplace-publish.yml'
        $text | Should -Match 'gh release download .* --pattern "\$env:VSIX_ASSET_GLOB"'
        $text | Should -Not -Match '--pattern "\*\$env:PACKAGE_ID\*\.vsix"'
    }

    It 'Publishes only from the marketplace publish workflow' {
        foreach ($workflow in @('extension-package.yml', 'extension-provenance.yml', 'plugin-package.yml')) {
            (Get-WorkflowText -Name $workflow) | Should -Not -Match 'vsce publish'
        }
        (Get-WorkflowText -Name 'extension-marketplace-publish.yml') | Should -Match 'vsce publish'
    }
}

Describe 'Packages matrix wiring' -Tag 'Unit' {
    It 'Publishes a packages-matrix output from <Workflow>' -ForEach @(
        @{ Workflow = 'extension-package.yml'; Job = 'discover-packages' }
        @{ Workflow = 'extension-provenance.yml'; Job = 'discover-packages' }
        @{ Workflow = 'plugin-package.yml'; Job = 'discover-packages' }
    ) {
        $document = Get-WorkflowDocument -Name $Workflow
        $outputs = $document['on']['workflow_call']['outputs']
        $outputs.Contains('packages-matrix') | Should -BeTrue
        [string]$outputs['packages-matrix']['value'] | Should -BeExactly "`${{ jobs.$Job.outputs.matrix }}"
    }

    It 'Feeds the discovered matrix into the publish workflow from <Workflow>' -ForEach @(
        @{ Workflow = 'release-marketplace-stable.yml'; Expression = '${{ needs.discover.outputs.matrix }}' }
        @{ Workflow = 'release-marketplace-prerelease.yml'; Expression = '${{ needs.package.outputs.packages-matrix }}' }
    ) {
        $document = Get-WorkflowDocument -Name $Workflow
        $publish = $document['jobs']['publish']
        [string]$publish['uses'] | Should -BeExactly './.github/workflows/extension-marketplace-publish.yml'
        [string]$publish['with']['packages-matrix'] | Should -BeExactly $Expression
    }

    It 'Requires the packages-matrix input in the publish workflow' {
        $document = Get-WorkflowDocument -Name 'extension-marketplace-publish.yml'
        $matrixInput = $document['on']['workflow_call']['inputs']['packages-matrix']
        $matrixInput['required'] | Should -BeTrue
        [string]$matrixInput['type'] | Should -BeExactly 'string'
    }
}

Describe 'Release artifact naming' -Tag 'Unit' {
    BeforeAll {
        # This script enables strict mode, so it is scoped to this block only.
        . (Join-Path $PSScriptRoot '../../linting/Test-ExtensionArtifactNaming.ps1')
    }

    It 'Passes the extension VSIX artifact naming contract' {
        $result = Test-ExtensionArtifactNaming -RepoRoot $script:RepositoryRoot
        @($result.Issues) | Should -HaveCount 0
        $result.Passed | Should -BeTrue
        @($result.Producers).Count | Should -BeGreaterThan 0
        @($result.Consumers).Count | Should -BeGreaterThan 0
    }

    It 'Names every VSIX artifact after the matrix package ID' {
        foreach ($workflow in @('extension-package.yml', 'extension-provenance.yml', 'extension-marketplace-publish.yml', 'release-prerelease.yml')) {
            $text = Get-WorkflowText -Name $workflow
            $names = @([regex]::Matches($text, '(?m)name: (extension-vsix-[^\r\n]+)') |
                    ForEach-Object { $_.Groups[1].Value.Trim() } | Sort-Object -Unique)
            @($names).Count | Should -BeGreaterThan 0 -Because "$workflow handles VSIX artifacts"
            $names | Should -Be @('extension-vsix-${{ matrix.id }}')
        }
    }

    It 'Names every per-package SBOM artifact after the matrix package ID' {
        (Get-WorkflowText -Name 'extension-provenance.yml') | Should -Match 'artifact-name: sbom-\$\{\{ matrix\.id \}\}'
        (Get-WorkflowText -Name 'release-prerelease.yml') | Should -Match 'artifact-name: sbom-\$\{\{ matrix\.id \}\}'
        (Get-WorkflowText -Name 'release-stable-publish.yml') | Should -Match 'artifact-name: sbom-plugin-\$\{\{ matrix\.id \}\}'
    }

    It 'Matches the plugin archive producer and consumer names' {
        (Get-WorkflowText -Name 'plugin-package.yml') | Should -Match 'name: plugin-package-\$\{\{ matrix\.id \}\}'
        (Get-WorkflowText -Name 'release-stable-publish.yml') | Should -Match 'name: plugin-package-\$\{\{ matrix\.id \}\}'
        (Get-WorkflowText -Name 'release-prerelease.yml') | Should -Match 'name: plugin-package-\$\{\{ matrix\.id \}\}'
    }

    It 'Wires the artifact naming check into the local validation aggregate' {
        [string]$script:RootManifest.scripts.'lint:extension-artifact-naming' |
            Should -BeExactly 'pwsh -NoProfile -File scripts/linting/Test-ExtensionArtifactNaming.ps1'
        [string]$script:RootManifest.scripts.'validate:local' | Should -Match 'npm run lint:extension-artifact-naming'
    }
}

Describe 'Plugin validation lane' -Tag 'Unit' {
    BeforeAll {
        $script:PluginValidationSteps = Get-JobStepText -Document (Get-WorkflowDocument -Name 'plugin-validation.yml') -JobName 'validate'
        $script:StepIndex = @{}
        for ($index = 0; $index -lt $script:PluginValidationSteps.Count; $index++) {
            foreach ($command in @('lint:plugin-output', 'lint:marketplace', 'lint:hooks', 'plugin:generate', 'plugin:evidence')) {
                if ($script:PluginValidationSteps[$index] -match "npm run $([regex]::Escape($command))") {
                    $script:StepIndex[$command] = $index
                }
            }
        }
    }

    It 'Runs every required validation command' {
        @($script:StepIndex.Keys | Sort-Object) | Should -Be @('lint:hooks', 'lint:marketplace', 'lint:plugin-output', 'plugin:evidence', 'plugin:generate')
    }

    It 'Guards tracked plugin output before regenerating plugins' {
        $script:StepIndex['lint:plugin-output'] | Should -BeLessThan $script:StepIndex['plugin:generate']
    }

    It 'Records release evidence after regeneration' {
        $script:StepIndex['plugin:evidence'] | Should -BeGreaterThan $script:StepIndex['plugin:generate']
    }

    It 'Stages generated package work under runner temp in <Workflow> step <Step>' -ForEach @(
        @{ Workflow = 'plugin-validation.yml'; Job = 'validate'; Step = 'Regenerate plugins from source' }
        @{ Workflow = 'plugin-package.yml'; Job = 'discover-packages'; Step = 'Discover marketplace packages' }
        @{ Workflow = 'plugin-package.yml'; Job = 'package'; Step = 'Generate committed plugins' }
        @{ Workflow = 'plugin-package.yml'; Job = 'package'; Step = 'Generate plugins and projected release catalog' }
        @{ Workflow = 'plugin-package.yml'; Job = 'package'; Step = 'Verify generated roots match discovered packages' }
        @{ Workflow = 'plugin-package.yml'; Job = 'package'; Step = 'Package plugin directory' }
    ) {
        $document = Get-WorkflowDocument -Name $Workflow
        $step = Get-NamedJobStep -Document $document -JobName $Job -StepName $Step
        [string]$step['env']['HVE_PLUGIN_STAGING_ROOT'] |
            Should -BeExactly '${{ runner.temp }}/plugins'
    }

    # Canonical evidence is derived from declared git-tracked sources, so no
    # evidence producer may depend on a materialized package tree.
    It 'Records canonical evidence without a staging root in <Workflow> step <Step>' -ForEach @(
        @{ Workflow = 'plugin-validation.yml'; Job = 'validate'; Step = 'Record canonical release evidence' }
        @{ Workflow = 'plugin-package.yml'; Job = 'publish-evidence'; Step = 'Record canonical release evidence' }
        @{ Workflow = 'plugin-package.yml'; Job = 'publish-evidence'; Step = 'Verify recorded evidence reproduces' }
    ) {
        $document = Get-WorkflowDocument -Name $Workflow
        $step = Get-NamedJobStep -Document $document -JobName $Job -StepName $Step
        $environment = if ($step.Contains('env')) { $step['env'] } else { @{} }
        $environment.Contains('HVE_PLUGIN_STAGING_ROOT') | Should -BeFalse
    }

    It 'Preserves the plugins directory prefix inside signed ZIP archives' {
        $steps = Get-JobStepText -Document (Get-WorkflowDocument -Name 'plugin-package.yml') -JobName 'package'
        $package = @($steps | Where-Object { $_ -match 'zip -r' })
        $package | Should -HaveCount 1
        $package[0] | Should -Match '\(cd "\$\{RUNNER_TEMP\}"'
        $package[0] | Should -Match '"plugins/\$\{PACKAGE_ID\}"'
        $package[0] | Should -Match 'dist/plugins/\$\{PACKAGE_ID\}\.zip'
    }

    It 'References no repository-root generated plugin tree in retained callers' {
        foreach ($workflow in @('plugin-validation.yml', 'plugin-package.yml')) {
            $text = Get-WorkflowText -Name $workflow
            $text | Should -Not -Match 'find plugins -'
            $text | Should -Not -Match 'Get-ChildItem -LiteralPath plugins -Directory'
            $text | Should -Not -Match 'cp -R plugins '
        }
    }

    It 'Runs no removed collection lint' {
        (Get-WorkflowText -Name 'plugin-validation.yml') | Should -Not -Match 'lint:collections'
        [string]$script:RootManifest.scripts.'validate:local' | Should -Not -Match 'lint:collections'
        $script:RootManifest.scripts.PSObject.Properties.Name | Should -Not -Contain 'lint:collections'
    }
}

Describe 'Removed collection inputs' -Tag 'Unit' {
    It 'References no collections path from any source workflow' {
        $offenders = @(
            Get-ChildItem -LiteralPath $script:WorkflowDirectory -File -Filter '*.yml' |
                Where-Object { $_.Name -notlike '*.lock.yml' } |
                Where-Object { (Get-Content -LiteralPath $_.FullName -Raw) -match 'collections/' } |
                ForEach-Object { $_.Name }
        )
        @($offenders).Count | Should -Be 0 -Because "collections/ no longer exists: $($offenders -join ', ')"
    }

    It 'References no collections path from the root manifest or lockfile' {
        (Get-Content -LiteralPath (Join-Path $script:RepositoryRoot 'package.json') -Raw) | Should -Not -Match 'collections/'
        (Get-Content -LiteralPath (Join-Path $script:RepositoryRoot 'package-lock.json') -Raw) | Should -Not -Match '"collections/'
    }

    It 'Watches only documentation and workflow inputs for Docusaurus changes' {
        $steps = Get-JobStepText -Document (Get-WorkflowDocument -Name 'docusaurus-tests.yml') -JobName 'detect-changes'
        $detect = @($steps | Where-Object { $_ -match 'git diff --name-only' })
        $detect | Should -HaveCount 1
        $detect[0] | Should -Not -Match 'collections'
        $detect[0] | Should -Match '(?m)^\s*docs\s*`?\s*$'
        $detect[0] | Should -Match '\.github/workflows/docusaurus-tests\.yml'
        $detect[0] | Should -Match '\.github/workflows/deploy-docs\.yml'
    }
}

Describe 'Extension packaging configuration' -Tag 'Unit' {
    BeforeAll {
        $script:IgnoreLines = @(Get-Content -LiteralPath (Join-Path $script:RepositoryRoot 'extension/.vscodeignore'))
        $script:AllowEntries = [string[]]@($script:IgnoreLines | Where-Object { $_ -like '!*' })

        $catalog = Get-MarketplaceCatalog -Path $script:CatalogPath
        $agentIndex = Get-MarketplaceAgentIndex -Catalog $catalog -RepoRoot $script:RepositoryRoot
        $contributionKinds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        $script:HookKindSeen = $false
        foreach ($entry in @($catalog['plugins'])) {
            if (-not (Test-MarketplaceEntryEligible -Entry $entry -Channel 'PreRelease')) { continue }
            foreach ($item in Get-MarketplaceResolvedPackageRecipe -Entry $entry -Channel 'PreRelease' -AgentIndex $agentIndex) {
                if ($item.Kind -eq 'hook') { $script:HookKindSeen = $true; continue }
                [void]$contributionKinds.Add([string]$item.Kind)
            }
        }
        $sourceRootMap = Get-MarketplaceComponentSourceRoot
        $script:ContributionRoots = [string[]]@($contributionKinds | ForEach-Object {
                $sourceRootMap[(Get-MarketplaceComponentField -Kind $_)].SourceRoot
            } | Sort-Object -Unique)
        $script:HookRoot = $sourceRootMap[(Get-MarketplaceComponentField -Kind 'hook')].SourceRoot
        $script:SharedRoots = @(Get-ScriptArrayLiteral -ScriptPath (Join-Path $script:RepositoryRoot 'scripts/extension/Package-Extension.ps1') -FunctionName 'Copy-PreparedArtifacts')

        $expected = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        foreach ($root in $script:ContributionRoots) { [void]$expected.Add("!$root/**") }
        foreach ($root in $script:SharedRoots) {
            $absolute = Join-Path $script:RepositoryRoot $root
            if (Test-Path -LiteralPath $absolute -PathType Container) { [void]$expected.Add("!$root/**") }
            else { [void]$expected.Add("!$root") }
        }
        foreach ($baseFile in @('icon.png', 'package.json', 'README.md', 'LICENSE', 'CHANGELOG.md')) {
            [void]$expected.Add("!$baseFile")
        }
        $script:ExpectedAllowEntries = [string[]]@($expected)
    }

    It 'Derives a non-empty staging root set from the shared projection' {
        @($script:ContributionRoots).Count | Should -BeGreaterThan 0
        $script:ContributionRoots | Should -Be @('.github/agents', '.github/instructions', '.github/prompts', '.github/skills')
        @($script:SharedRoots) | Should -Be @('scripts/lib/Modules/CIHelpers.psm1', 'docs/templates')
    }

    It 'Allow-lists exactly the staging roots plus the base extension files' {
        $actual = [string[]]@($script:AllowEntries)
        $expected = [string[]]@($script:ExpectedAllowEntries)
        [array]::Sort($actual, [System.StringComparer]::Ordinal)
        [array]::Sort($expected, [System.StringComparer]::Ordinal)
        $actual | Should -Be $expected
    }

    It 'Never allow-lists the plugin-only hook root' {
        $script:HookKindSeen | Should -BeTrue
        $script:AllowEntries | Should -Not -Contain "!$script:HookRoot/**"
    }

    It 'Excludes package-specific generated files from the shipped VSIX' {
        $script:IgnoreLines | Should -Contain 'README.*.md'
        $script:IgnoreLines | Should -Contain 'package.*.json'
    }

    It 'Excludes Python and dependency caches from shipped skills' {
        foreach ($pattern in @('**/.venv/**', '**/.ruff_cache/**', '**/.pytest_cache/**', '**/__pycache__/**', '**/*.pyc')) {
            $script:IgnoreLines | Should -Contain $pattern
        }
    }

    It 'Uses only existing script directories for Pester coverage' {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $script:RepositoryRoot 'scripts/tests/pester.config.ps1'), [ref]$null, [ref]$null)
        $assignment = @($ast.FindAll({ $args[0] -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true) |
                Where-Object { $_.Left.Extent.Text -eq '$coverageDirs' })
        $assignment | Should -HaveCount 1
        $coverageDirs = @($assignment[0].Right.FindAll({ $args[0] -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true) |
                ForEach-Object { $_.Value })
        @($coverageDirs).Count | Should -BeGreaterThan 0
        foreach ($directory in $coverageDirs) {
            Test-Path -LiteralPath (Join-Path $script:RepositoryRoot "scripts/$directory") -PathType Container |
                Should -BeTrue -Because "coverage directory scripts/$directory must exist"
        }
        $coverageDirs | Should -Contain 'extension'
        $coverageDirs | Should -Contain 'plugins'
        $coverageDirs | Should -Contain 'docs'
        $coverageDirs | Should -Not -Contain 'collections'
    }
}

Describe 'Release source ownership' -Tag 'Unit' {
    BeforeAll {
        $script:WorkflowNames = [string[]]@(
            Get-ChildItem -LiteralPath $script:WorkflowDirectory -File -Filter '*.yml' |
                Where-Object { $_.Name -notlike '*.lock.yml' } |
                ForEach-Object { $_.Name }
        )
        # A tag write is any git reference creation under refs/tags.
        $script:TagCreators = [string[]]@(
            $script:WorkflowNames | Where-Object { (Get-WorkflowText -Name $_) -match 'ref=refs/tags/' }
        )
        $script:ReleaseCreators = [string[]]@(
            $script:WorkflowNames | Where-Object { (Get-WorkflowText -Name $_) -match 'gh release create ' }
        )
    }

    It 'Retired the pre-release PR workflow and its branch reset' {
        Test-Path -LiteralPath (Join-Path $script:WorkflowDirectory 'release-prerelease-pr.yml') | Should -BeFalse
        foreach ($workflow in $script:WorkflowNames) {
            (Get-WorkflowText -Name $workflow) | Should -Not -Match 'prerelease/next' -Because "$workflow must not reference the retired pre-release branch"
            (Get-WorkflowText -Name $workflow) | Should -Not -Match 'reset-prerelease' -Because "$workflow must not reference the retired branch reset"
        }
        $script:RootManifest.scripts.PSObject.Properties.Name | Should -Not -Contain 'reset-prerelease'
    }

    It 'Creates no immutable release tag or GitHub release outside release-please' {
        @($script:TagCreators) | Should -HaveCount 0 -Because "release-please owns every release tag: $($script:TagCreators -join ', ')"
        @($script:ReleaseCreators) | Should -HaveCount 0 -Because "release-please owns every GitHub release: $($script:ReleaseCreators -join ', ')"
        foreach ($workflow in @('release-prerelease.yml', 'release-stable-publish.yml')) {
            (Get-WorkflowText -Name $workflow) | Should -Match 'googleapis/release-please-action@'
        }
    }

    It 'Creates no tag or GitHub release during stable preparation on main' {
        $text = Get-WorkflowText -Name 'release-stable.yml'
        $text | Should -Not -Match 'ref=refs/tags/'
        # Reading the selected source release is permitted; only mutation is not.
        $text | Should -Not -Match 'gh release (create|edit|delete|upload)'
        $text | Should -Not -Match 'release_created'
    }

    It 'Configures release-please to create draft releases with release-please-owned tags' {
        foreach ($configName in @(
                'release-please-config.json'
                'release-please-prerelease-config.json'
            )) {
            $config = Get-Content -LiteralPath (Join-Path $script:RepositoryRoot $configName) -Raw -Encoding utf8 | ConvertFrom-Json
            $package = $config.packages.'.'
            $package.PSObject.Properties.Name | Should -Not -Contain 'skip-github-release' -Because "$configName selects skip modes through action inputs"
            $package.draft | Should -BeTrue -Because "$configName keeps publication as the immutable boundary"
            $package.'force-tag-creation' | Should -BeTrue -Because "$configName must create the release tag before release-tag provenance checks"
        }
    }

    It 'Uses no source branch that a release workflow force-pushes' {
        foreach ($workflow in $script:WorkflowNames) {
            $text = Get-WorkflowText -Name $workflow
            $text | Should -Not -Match 'release/plugins' -Because "$workflow must never source or move the orphan snapshot branch"
            $text | Should -Not -Match 'push --force' -Because "$workflow must not force-push any reference"
        }
    }
}

Describe 'Release-please channel state' -Tag 'Unit' {
    BeforeAll {
        $script:ChannelConfigNames = @(
            'release-please-config.json'
            'release-please-prerelease-config.json'
        )
        $script:ChannelConfigs = @{}
        foreach ($name in $script:ChannelConfigNames) {
            $script:ChannelConfigs[$name] = Get-Content -LiteralPath (Join-Path $script:RepositoryRoot $name) -Raw -Encoding utf8 |
                ConvertFrom-Json -AsHashtable
        }
        $script:StableChannelManifest = Get-Content -LiteralPath (Join-Path $script:RepositoryRoot '.release-please-manifest.json') -Raw -Encoding utf8 |
            ConvertFrom-Json -AsHashtable
        $script:PreReleaseChannelManifest = Get-Content -LiteralPath (Join-Path $script:RepositoryRoot '.release-please-prerelease-manifest.json') -Raw -Encoding utf8 |
            ConvertFrom-Json -AsHashtable
    }

    It 'Owns complete branch-local PreRelease release-please state' {
        $config = $script:ChannelConfigs['release-please-prerelease-config.json']
        $topKeys = [string[]]@($config.Keys)
        [array]::Sort($topKeys, [System.StringComparer]::Ordinal)
        $topKeys | Should -Be @('$schema', 'commit-search-depth', 'packages', 'release-search-depth')
        $config['release-search-depth'] | Should -Be 800
        $config['commit-search-depth'] | Should -Be 1000

        $package = $config['packages']['.']
        $packageKeys = [string[]]@($package.Keys)
        [array]::Sort($packageKeys, [System.StringComparer]::Ordinal)
        $packageKeys | Should -Be @(
            'bump-minor-pre-major'
            'bump-patch-for-minor-pre-major'
            'changelog-path'
            'changelog-sections'
            'draft'
            'extra-files'
            'force-tag-creation'
            'include-component-in-tag'
            'package-name'
            'release-type'
            'versioning'
        )
        [string]$package['release-type'] | Should -BeExactly 'node'
        [string]$package['versioning'] | Should -BeExactly 'always-bump-patch'
        $package['force-tag-creation'] | Should -BeTrue
        [string]$package['changelog-path'] | Should -BeExactly 'CHANGELOG.md'
        @($package['extra-files']) | Should -HaveCount 3

        # package-name plus include-component-in-tag are what emit the
        # hve-core-v<version> namespace the Marketplace lane validates.
        [string]$package['package-name'] | Should -BeExactly 'hve-core'
        $package['include-component-in-tag'] | Should -BeTrue

        foreach ($forbidden in @(
                'version-file'
                'skip-github-release'
                'skip-github-pull-request'
                'skip-changelog'
                'prerelease'
                'prerelease-type'
            )) {
            $package.Contains($forbidden) | Should -BeFalse -Because 'the PreRelease channel uses numeric node releases without action-mode config keys'
        }

        @($script:PreReleaseChannelManifest.Keys) | Should -Be @('.')
    }

    It 'Keeps each branch seed on its assigned numeric parity' {
        $stableVersion = [string]$script:StableChannelManifest['.']
        $preReleaseVersion = [string]$script:PreReleaseChannelManifest['.']
        $stableVersion | Should -Match '^\d+\.\d+\.\d+$'
        $preReleaseVersion | Should -Match '^\d+\.\d+\.\d+$'

        $stable = $stableVersion.Split('.')
        $preRelease = $preReleaseVersion.Split('.')
        ([int]$stable[1] % 2) | Should -Be 0 -Because 'Stable owns the even-minor baseline'
        ([int]$preRelease[1] % 2) | Should -Be 1 -Because 'PreRelease owns the odd-minor baseline'
    }

    It 'Uses one identical parity-safe package configuration per channel' {
        $stable = $script:ChannelConfigs['release-please-config.json']
        $preRelease = $script:ChannelConfigs['release-please-prerelease-config.json']
        [string]$stable['packages']['.']['versioning'] | Should -BeExactly 'always-bump-patch'
        [string]$preRelease['packages']['.']['versioning'] | Should -BeExactly 'always-bump-patch'
        (ConvertTo-SortedJson -InputObject $preRelease) |
            Should -BeExactly (ConvertTo-SortedJson -InputObject $stable)
    }
}

Describe 'Pre-release preparation and publication' -Tag 'Unit' {
    BeforeAll {
        $script:PreReleaseDocument = Get-WorkflowDocument -Name 'release-prerelease.yml'
        $script:PreReleaseText = Get-WorkflowText -Name 'release-prerelease.yml'
    }

    It 'Runs PreRelease release-please only for the exact promotion and managed heads' {
        $triggers = [string[]]@($script:PreReleaseDocument['on'].Keys)
        [array]::Sort($triggers, [System.StringComparer]::Ordinal)
        $triggers | Should -Be @('pull_request')
        @($script:PreReleaseDocument['on']['pull_request']['types']) | Should -Be @('closed')
        @($script:PreReleaseDocument['on']['pull_request']['branches']) | Should -Be @('release/prerelease')

        $guard = [string]$script:PreReleaseDocument['jobs']['release-please']['if']
        $guard | Should -Match 'github\.event\.pull_request\.merged == true'
        $guard | Should -Match "github\.event\.pull_request\.base\.ref == 'release/prerelease'"
        $guard | Should -Match 'head\.repo\.full_name == github\.repository'
        $guard | Should -Match "head\.ref == 'release-promotion--main--to--release-prerelease'"
        $guard | Should -Match "head\.ref == 'release-please--branches--release/prerelease'"

        $release = Get-NamedJobStep -Document $script:PreReleaseDocument -JobName 'release-please' -StepName 'Run release-please'
        [string]$release['uses'] | Should -Match '^googleapis/release-please-action@[0-9a-f]{40}$'
        [string]$release['with']['config-file'] | Should -BeExactly 'release-please-prerelease-config.json'
        [string]$release['with']['manifest-file'] | Should -BeExactly '.release-please-prerelease-manifest.json'
        [string]$release['with']['target-branch'] | Should -BeExactly 'release/prerelease'
        [string]$release['with']['skip-github-release'] |
            Should -BeExactly "`${{ github.event.pull_request.head.ref != 'release-please--branches--release/prerelease' }}"
        [string]$release['with']['skip-github-pull-request'] |
            Should -BeExactly "`${{ github.event.pull_request.head.ref == 'release-please--branches--release/prerelease' }}"

        $outputCheck = Get-NamedJobStep -Document $script:PreReleaseDocument -JobName 'release-please' -StepName 'Validate release-please outputs'
        [string]$outputCheck['run'] | Should -Match 'prepared no release pull request'
        [string]$outputCheck['run'] | Should -Match 'changelog-visible commits'
        [string]$outputCheck['run'] | Should -Match 'pending release interlock'
    }

    It 'Proves the released commit is the merged commit contained in release/prerelease' {
        [string]$script:PreReleaseDocument['jobs']['validate-release']['if'] |
            Should -Match "needs\.release-please\.outputs\.release_created == 'true'"

        $identity = Get-NamedJobStep -Document $script:PreReleaseDocument -JobName 'validate-release' -StepName 'Verify trusted release identity'
        [string]$identity['env']['EVENT_SHA'] | Should -BeExactly '${{ github.sha }}'
        [string]$identity['env']['MERGE_SHA'] | Should -BeExactly '${{ github.event.pull_request.merge_commit_sha }}'
        [string]$identity['env']['RELEASE_SHA'] | Should -BeExactly '${{ needs.release-please.outputs.sha }}'
        $run = [string]$identity['run']
        $run | Should -Match '\[ "\$MERGE_SHA" != "\$EVENT_SHA" \]'
        $run | Should -Match '\[ "\$RELEASE_SHA" != "\$EVENT_SHA" \]'

        $checkout = Get-NamedJobStep -Document $script:PreReleaseDocument -JobName 'validate-release' -StepName 'Checkout release/prerelease history'
        [string]$checkout['with']['ref'] | Should -BeExactly 'release/prerelease'
        [string]$checkout['with']['fetch-depth'] | Should -BeExactly '0'
        $checkout['with']['persist-credentials'] | Should -BeFalse

        $steps = Get-JobStepText -Document $script:PreReleaseDocument -JobName 'validate-release'
        @($steps | Where-Object { $_ -match 'git merge-base --is-ancestor' }) | Should -HaveCount 1
        @($steps | Where-Object { $_ -match '\.release-please-prerelease-manifest\.json' }) | Should -HaveCount 1
    }

    It 'Validates an odd minor, tag namespace, and retired PreRelease intent' {
        $steps = Get-JobStepText -Document $script:PreReleaseDocument -JobName 'validate-release'
        $version = @($steps | Where-Object { $_ -match 'MINOR % 2 == 0' })
        $version | Should -HaveCount 1
        $version[0] | Should -Match '\^\[0-9\]\+\\\.\[0-9\]\+\\\.\[0-9\]\+\$'
        $version[0] | Should -Match 'hve-core-v\$RELEASE_VERSION'

        $script:PreReleaseText | Should -Not -Match 'PRE_MAJOR|PRE_MINOR'
        $committedState = @($steps | Where-Object { $_ -match 'STALE_INTENT' })
        $committedState | Should -HaveCount 1
        $committedState[0] | Should -Match 'release-please-prerelease-config\.json still carries release-as'

        # Parity cannot detect an always-bump-patch fallback, so exact intent
        # equality and its retirement carry the PreRelease release identity.
        $intent = Get-NamedJobStep -Document $script:PreReleaseDocument -JobName 'sync-release-pr' -StepName 'Update committed version fields and retire the promotion intent'
        $intentRun = [string]$intent['run']
        $intentRun | Should -Match ([regex]::Escape('CONFIG="$RELEASE_REPO/release-please-prerelease-config.json"'))
        $intentRun | Should -Match '\[ "\$INTENT" != "\$VERSION" \]'
        $intentRun | Should -Match 'but the managed release is \$VERSION'
        $intentRun | Should -Match ([regex]::Escape('del(.packages["."]["release-as"])'))
        $intentRun | Should -Match ([regex]::Escape('.release-please-prerelease-manifest.json'))
    }

    It 'Removed the explicit source resolution and custom draft creation path' {
        foreach ($job in @('resolve-source', 'create-prerelease')) {
            $script:PreReleaseDocument['jobs'].Contains($job) |
                Should -BeFalse -Because "release-please owns pre-release tag and release creation, so $job is retired"
        }
        $script:PreReleaseDocument['jobs']['release-please'] | Should -Not -BeNullOrEmpty
        $script:PreReleaseText | Should -Not -Match 'source-sha|source_sha'
        $script:PreReleaseText | Should -Not -Match 'needs\.resolve-source'
        $script:PreReleaseText | Should -Not -Match 'gh release create'
        $script:PreReleaseText | Should -Not -Match 'gh release view'
        $script:PreReleaseText | Should -Not -Match 'git/refs/tags/'
    }

    It 'Closes the pre-release milestone only after final publication' {
        @($script:PreReleaseDocument['jobs']['close-milestone']['needs']) | Should -Contain 'publish-release'
        @($script:PreReleaseDocument['jobs']['publish-release']['needs']) | Should -Contain 'upload-plugin-packages'

        $mainSync = $script:PreReleaseDocument['jobs']['main-catalog-sync']
        $mainSync | Should -Not -BeNullOrEmpty
        @($mainSync['needs']) | Should -Be @('validate-release', 'plugin-package-prerelease', 'publish-release')
        [string]$mainSync['uses'] | Should -BeExactly './.github/workflows/release-main-catalog-sync.yml'
        [string]$mainSync['with']['version'] | Should -BeExactly '${{ needs.validate-release.outputs.version }}'
        [string]$mainSync['with']['release-sha'] | Should -BeExactly '${{ needs.validate-release.outputs.sha }}'
    }

    It 'Publishes the draft as a GitHub pre-release with the release App token' {
        $token = Get-NamedJobStep -Document $script:PreReleaseDocument -JobName 'publish-release' -StepName 'Generate GitHub App Token'
        [string]$token['id'] | Should -BeExactly 'app-token'
        [string]$token['uses'] | Should -Match '^actions/create-github-app-token@[0-9a-f]{40}$'

        # release-please cannot classify a numeric version as a pre-release, and
        # a github.token publish emits no event, so one App-token edit sets the
        # flag and drops the draft together.
        $publish = Get-NamedJobStep -Document $script:PreReleaseDocument -JobName 'publish-release' -StepName 'Publish GitHub Release'
        [string]$publish['env']['GH_TOKEN'] | Should -BeExactly '${{ steps.app-token.outputs.token }}'
        [string]$publish['run'] | Should -Match 'gh release edit "\$TAG" --prerelease --draft=false'
        @([regex]::Matches($script:PreReleaseText, 'gh release edit ')) | Should -HaveCount 1
    }

    It 'Packages the plugin and the VSIX from the validated release commit' {
        $jobs = $script:PreReleaseDocument['jobs']
        foreach ($job in @('extension-package-prerelease', 'plugin-package-prerelease')) {
            @($jobs[$job]['needs']) | Should -Contain 'validate-release'
            [string]$jobs[$job]['with']['source-ref'] | Should -BeExactly '${{ needs.validate-release.outputs.sha }}'
            [string]$jobs[$job]['with']['version'] | Should -BeExactly '${{ needs.validate-release.outputs.version }}'
        }
        [string]$jobs['extension-package-prerelease']['uses'] | Should -BeExactly './.github/workflows/extension-package.yml'
        [string]$jobs['plugin-package-prerelease']['uses'] | Should -BeExactly './.github/workflows/plugin-package.yml'
        [string]$jobs['plugin-package-prerelease']['with']['source-policy'] | Should -BeExactly 'release-tag'
        $jobs['plugin-package-prerelease']['with'].Contains('project-release-catalog') | Should -BeFalse
    }
}

Describe 'Stable promotion and publication gate' -Tag 'Unit' {
    BeforeAll {
        $script:PrepareDocument = Get-WorkflowDocument -Name 'release-stable.yml'
        $script:PublishDocument = Get-WorkflowDocument -Name 'release-stable-publish.yml'
        $script:PublishText = Get-WorkflowText -Name 'release-stable-publish.yml'
    }

    It 'Opens a non-auto-merged release/prerelease to release/stable promotion pull request' {
        $steps = Get-JobStepText -Document $script:PrepareDocument -JobName 'open-promotion-pr'
        $promotion = @($steps | Where-Object { $_ -match 'gh pr create' })
        $promotion | Should -HaveCount 1
        $promotion[0] | Should -Match '--head "\$HEAD_BRANCH"'
        $promotion[0] | Should -Match '--base "\$BASE_BRANCH"'
        $job = $script:PrepareDocument['jobs']['open-promotion-pr']
        [string]$job['steps'][1]['env']['HEAD_BRANCH'] | Should -BeExactly '${{ needs.prepare-promotion.outputs.promotion-head }}'
        [string]$job['steps'][1]['env']['BASE_BRANCH'] | Should -BeExactly 'release/stable'
        [string]$job['steps'][1]['env']['SOURCE_BRANCH'] | Should -BeExactly 'release/prerelease'
        [string]$job['steps'][1]['env']['SOURCE_TAG'] | Should -BeExactly '${{ needs.prepare-promotion.outputs.source-tag }}'
        $promotion[0] | Should -Match 'EXPECTED_HEAD="\$PROMOTION_HEAD_PREFIX--\$SOURCE_TAG"'
        $promotion[0] | Should -Match '\[ "\$HEAD_BRANCH" != "\$EXPECTED_HEAD" \]'
        (Get-WorkflowText -Name 'release-stable.yml') | Should -Not -Match 'gh pr merge'
        (Get-WorkflowText -Name 'release-stable.yml') | Should -Not -Match '--auto'
    }

    It 'Promotes published PreRelease state without pre-validation jobs or release-please' {
        $prepare = $script:PrepareDocument['jobs']['prepare-promotion']
        $prepare.Contains('needs') | Should -BeFalse
        @($script:PrepareDocument['jobs']['open-promotion-pr']['needs']) | Should -Be @('prepare-promotion')
        $script:PrepareDocument['jobs'].Contains('release-please') | Should -BeFalse
        $stablePreparation = Get-WorkflowText -Name 'release-stable.yml'
        $stablePreparation | Should -Not -Match 'googleapis/release-please-action@'
        $stablePreparation | Should -Not -Match 'pester-tests'
        @($script:PrepareDocument['on']['release']['types']) | Should -Be @('published')
        [string]$script:PrepareDocument['env']['SOURCE_BRANCH'] | Should -BeExactly 'release/prerelease'
        [string]$script:PrepareDocument['env']['BASE_BRANCH'] | Should -BeExactly 'release/stable'
        [string]$script:PrepareDocument['env']['SOURCE_MANIFEST'] | Should -BeExactly '.release-please-prerelease-manifest.json'
        $dispatchTag = $script:PrepareDocument['on']['workflow_dispatch']['inputs']['prerelease-tag']
        $dispatchTag['required'] | Should -BeTrue
        [string]$dispatchTag['type'] | Should -BeExactly 'string'

        $state = Get-NamedJobStep -Document $script:PrepareDocument -JobName 'prepare-promotion' -StepName 'Resolve promotion state'
        foreach ($name in @('DISPATCH_TAG', 'EVENT_NAME', 'EVENT_TAG', 'GH_TOKEN', 'REPOSITORY')) {
            $state['env'].Contains($name) | Should -BeTrue
        }
        $stateRun = [string]$state['run']
        $stateRun | Should -Match 'release-please--'
        $stateRun | Should -Match 'release-promotion--'
        $stateRun | Should -Match '\$SOURCE_MANIFEST'
        $stateRun | Should -Match ([regex]::Escape('^hve-core-v[0-9]+\.[0-9]+\.[0-9]+$'))
        $stateRun | Should -Match '\[\[ .*SOURCE_TAG.*=~ \^hve-core-v'
        $stateRun | Should -Not -Match 'SOURCE_TAG.*\|\s*grep'
        [string]$prepare['outputs']['promotion-head'] | Should -BeExactly '${{ steps.state.outputs.promotion-head }}'
        $stateRun | Should -Match ([regex]::Escape('+refs/tags/$SOURCE_TAG:refs/tags/$SOURCE_TAG'))
        $stateRun | Should -Match ([regex]::Escape('refs/tags/$SOURCE_TAG^{commit}'))
        $stateRun | Should -Match ([regex]::Escape('git show "$SOURCE_SHA:$SOURCE_MANIFEST"'))
        $stateRun | Should -Match ([regex]::Escape('git merge-base --is-ancestor "$SOURCE_SHA" "refs/remotes/origin/$SOURCE_BRANCH"'))
        $stateRun | Should -Match ([regex]::Escape('gh release download "$SOURCE_TAG"'))
        $stateRun | Should -Match ([regex]::Escape('refs/remotes/origin/$BASE_BRANCH..$SOURCE_SHA'))
        $stateRun | Should -Not -Match 'SOURCE_SHA=\$\(git rev-parse "refs/remotes/origin/\$SOURCE_BRANCH"\)'
        $stateRun | Should -Not -Match 'plugins-v\$VERSION|hve-core-v\$VERSION'

        # Commit classification and its release-class dispatch are gone: the
        # promoted source version alone selects the next even minor.
        @($script:PrepareDocument['jobs']['prepare-promotion']['steps'] |
                Where-Object { [string]$_['name'] -eq 'Classify promoted commits' }) | Should -HaveCount 0
        $stablePreparation | Should -Not -Match 'Classify promoted commits'
        $stablePreparation | Should -Not -Match 'release-class|release_class|release class'
        [string[]]@($script:PrepareDocument['on']['workflow_dispatch']['inputs'].Keys) | Should -Be @('prerelease-tag')
        $prepare['outputs'].Contains('release-class') | Should -BeFalse

        $resolver = Get-NamedJobStep -Document $script:PrepareDocument -JobName 'prepare-promotion' -StepName 'Resolve exact Stable version'
        foreach ($name in @('SOURCE_VERSION', 'STABLE_BASELINE')) {
            $resolver['env'].Contains($name) | Should -BeTrue
        }
        $resolverRun = [string]$resolver['run']
        $resolverRun | Should -Match 'Resolve-ReleasePromotionVersion\.ps1'
        $resolverRun | Should -Match '-Channel Stable'
        $resolverRun | Should -Match ([regex]::Escape('-PromotedSourceVersion "$SOURCE_VERSION"'))
        $resolverRun | Should -Match ([regex]::Escape('-CurrentStableVersion "$STABLE_BASELINE"'))
        $resolverRun | Should -Not -Match '-CurrentPreReleaseVersion|-ReleaseClass'
        # Canonical syntax still guards the resolved value, but the same-run
        # parity recheck is gone because the resolver owns that contract.
        $resolverRun | Should -Match ([regex]::Escape('^[0-9]+\.[0-9]+\.[0-9]+$'))
        $resolverRun | Should -Not -Match '% 2'
    }

    # release-please's json extra-files updater writes bare version values and
    # cannot express the catalog's plugins-v<version> locator. Only the shared
    # updater running on the same preparation branch keeps the promoted commit
    # consistent; a downstream lint gate would just fail forever instead.
    It 'Runs release-please against release/stable and exposes validated release outputs' {
        $releaseJob = $script:PublishDocument['jobs']['release-please']
        $releaseJob | Should -Not -BeNullOrEmpty
        $releaseSteps = Get-JobStepText -Document $script:PublishDocument -JobName 'release-please'
        @($releaseSteps | Where-Object { $_ -match '\^release-please--' }) | Should -HaveCount 1

        $release = Get-NamedJobStep -Document $script:PublishDocument -JobName 'release-please' -StepName 'Run release-please'
        [string]$release['uses'] | Should -Match '^googleapis/release-please-action@[0-9a-f]{40}$'
        [string]$release['with']['target-branch'] | Should -BeExactly 'release/stable'
        [string]$release['with']['manifest-file'] | Should -BeExactly '.release-please-manifest.json'

        [string]$releaseJob['outputs']['release-pr-branch'] |
            Should -BeExactly '${{ steps.release-pr.outputs.branch }}'
        foreach ($output in @('release_created', 'tag_name', 'version', 'sha', 'body')) {
            $releaseJob['outputs'].Contains($output) | Should -BeTrue
        }
        $validation = @($releaseSteps | Where-Object { $_ -match 'release_created' -and $_ -match 'tag_name' -and $_ -match 'version' -and $_ -match 'sha' })
        $validation | Should -HaveCount 1
        $validation[0] | Should -Match 'hve-core-v\$RELEASE_VERSION'
        $validation[0] | Should -Match 'prepared no release pull request'
        $validation[0] | Should -Match 'changelog-visible commits'
    }

    It 'Prepares on the Stable promotion merge and tags only the managed release pull request' {
        $triggers = [string[]]@($script:PublishDocument['on'].Keys)
        $triggers | Should -Be @('pull_request')
        @($script:PublishDocument['on']['pull_request']['types']) | Should -Be @('closed')
        @($script:PublishDocument['on']['pull_request']['branches']) | Should -Be @('release/stable')

        $validationJob = $script:PublishDocument['jobs']['validate-trigger']
        $validationJob | Should -Not -BeNullOrEmpty
        [string]$validationJob['permissions']['contents'] | Should -BeExactly 'read'
        $guard = [string]$validationJob['if']
        $guard | Should -Match 'github\.event\.pull_request\.merged == true'
        $guard | Should -Match "github\.event\.pull_request\.base\.ref == 'release/stable'"
        $guard | Should -Match 'head\.repo\.full_name == github\.repository'
        $guard | Should -Match 'release-promotion--release-prerelease--to--release-stable--hve-core-v'
        $guard | Should -Match "head\.ref == 'release-please--branches--release/stable'"

        @($script:PublishDocument['jobs']['release-please']['needs']) | Should -Be @('validate-trigger')
        [string]$validationJob['outputs']['mode'] | Should -BeExactly '${{ steps.identity.outputs.mode }}'
        [string]$validationJob['outputs']['source-tag'] | Should -BeExactly '${{ steps.identity.outputs.source-tag }}'
        [string]$validationJob['outputs']['source-sha'] | Should -BeExactly '${{ steps.source.outputs.source-sha }}'
        $identity = Get-NamedJobStep -Document $script:PublishDocument -JobName 'validate-trigger' -StepName 'Validate merged head identity'
        [string]$identity['run'] | Should -Match 'release-promotion--release-prerelease--to--release-stable--\(hve-core-v\[0-9\]'
        [string]$identity['run'] | Should -Match '\[ "\$HEAD_REF" = "\$MANAGED_HEAD" \]'

        $configFile = [string](Get-NamedJobStep -Document $script:PublishDocument -JobName 'release-please' -StepName 'Run release-please')['with']['config-file']
        $configFile | Should -BeExactly 'release-please-config.json'

        $release = Get-NamedJobStep -Document $script:PublishDocument -JobName 'release-please' -StepName 'Run release-please'
        [string]$release['with']['skip-github-release'] |
            Should -BeExactly "`${{ needs.validate-trigger.outputs.mode != 'managed' }}"
        [string]$release['with']['skip-github-pull-request'] |
            Should -BeExactly "`${{ needs.validate-trigger.outputs.mode == 'managed' }}"

        [string]$script:PublishDocument['concurrency']['group'] | Should -BeExactly '${{ github.workflow }}-release/stable'
        $script:PublishDocument['concurrency']['cancel-in-progress'] | Should -BeFalse

        $sourceGate = Get-NamedJobStep -Document $script:PublishDocument -JobName 'validate-trigger' -StepName 'Validate selected promotion source and intent'
        $sourceGateRun = [string]$sourceGate['run']
        $sourceGateRun | Should -Match 'refs/pull/\$PR_NUMBER/head'
        $sourceGateRun | Should -Match 'refs/tags/\$SOURCE_TAG\^\{commit\}'
        $sourceGateRun | Should -Match 'git merge-base --is-ancestor "\$SOURCE_SHA" "refs/remotes/pull/\$PR_NUMBER/head"'
        $sourceGateRun | Should -Match 'plugin-release-evidence\.json'
        $sourceGateRun | Should -Match 'CANDIDATE=.*release-please-config\.json'
        $sourceGateRun | Should -Not -Match 'plugins-v\$CANDIDATE|hve-core-v\$CANDIDATE'

        $managedGate = Get-NamedJobStep -Document $script:PublishDocument -JobName 'validate-trigger' -StepName 'Validate managed release intent was consumed'
        [string]$managedGate['run'] | Should -Match 'release-as'
        [string]$managedGate['run'] | Should -Match '\[ -n "\$INTENT" \]'

        # Parity cannot detect an always-bump-patch fallback, so exact intent
        # equality and its retirement carry the Stable release identity.
        $intent = Get-NamedJobStep -Document $script:PublishDocument -JobName 'sync-release-pr' -StepName 'Update committed version fields and retire the promotion intent'
        $intentRun = [string]$intent['run']
        $intentRun | Should -Match ([regex]::Escape('CONFIG="$RELEASE_REPO/release-please-config.json"'))
        $intentRun | Should -Match '\[ "\$INTENT" != "\$VERSION" \]'
        $intentRun | Should -Match 'but the managed release is \$VERSION'
        $intentRun | Should -Match ([regex]::Escape('del(.packages["."]["release-as"])'))

        $publicationState = Get-NamedJobStep -Document $script:PublishDocument -JobName 'validate-release' -StepName 'Verify release version and committed state'
        [string]$publicationState['run'] | Should -Match 'release-please-config\.json still carries release-as'
    }

    It 'Scopes Stable promotion heads to the validated selected tag' {
        $prepare = $script:PrepareDocument['jobs']['prepare-promotion']
        $script:PrepareDocument['env'].Contains('PROMOTION_HEAD') | Should -BeFalse
        [string]$script:PrepareDocument['env']['PROMOTION_HEAD_PREFIX'] |
            Should -BeExactly 'release-promotion--release-prerelease--to--release-stable'
        [string]$prepare['outputs']['promotion-head'] | Should -BeExactly '${{ steps.state.outputs.promotion-head }}'

        $state = Get-NamedJobStep -Document $script:PrepareDocument -JobName 'prepare-promotion' -StepName 'Resolve promotion state'
        $stateRun = [string]$state['run']
        $stateRun | Should -Match 'PROMOTION_HEAD="\$PROMOTION_HEAD_PREFIX--\$SOURCE_TAG"'
        $stateRun | Should -Match 'jq -r --arg head "\$PROMOTION_HEAD"'
        $stateRun | Should -Match 'gh pr list .*--limit 100'
        $stateRun | Should -Match 'promotion-head=\$PROMOTION_HEAD'

        $refresh = Get-NamedJobStep -Document $script:PrepareDocument -JobName 'prepare-promotion' -StepName 'Refresh the promotion head'
        [string]$refresh['env']['PROMOTION_HEAD'] | Should -BeExactly '${{ steps.state.outputs.promotion-head }}'
        [string]$refresh['env']['SOURCE_TAG'] | Should -BeExactly '${{ steps.state.outputs.source-tag }}'
        [string]$refresh['run'] | Should -Match 'EXPECTED_HEAD="\$PROMOTION_HEAD_PREFIX--\$SOURCE_TAG"'
        [string]$refresh['run'] | Should -Match 'refs/heads/\$PROMOTION_HEAD'
    }

    It 'Proves the Stable release commit is the merged commit contained in release/stable' {
        [string]$script:PublishDocument['jobs']['validate-release']['if'] |
            Should -Match "needs\.release-please\.outputs\.release_created == 'true'"

        $identity = Get-NamedJobStep -Document $script:PublishDocument -JobName 'validate-release' -StepName 'Verify trusted release identity'
        [string]$identity['env']['EVENT_SHA'] | Should -BeExactly '${{ github.sha }}'
        [string]$identity['env']['MERGE_SHA'] | Should -BeExactly '${{ github.event.pull_request.merge_commit_sha }}'
        [string]$identity['env']['RELEASE_SHA'] | Should -BeExactly '${{ needs.release-please.outputs.sha }}'
        $run = [string]$identity['run']
        $run | Should -Match '\[ "\$MERGE_SHA" != "\$EVENT_SHA" \]'
        $run | Should -Match '\[ "\$RELEASE_SHA" != "\$EVENT_SHA" \]'

        $checkout = Get-NamedJobStep -Document $script:PublishDocument -JobName 'validate-release' -StepName 'Checkout release/stable history'
        [string]$checkout['with']['ref'] | Should -BeExactly 'release/stable'
        [string]$checkout['with']['fetch-depth'] | Should -BeExactly '0'
        $checkout['with']['persist-credentials'] | Should -BeFalse

        $steps = Get-JobStepText -Document $script:PublishDocument -JobName 'validate-release'
        @($steps | Where-Object { $_ -match 'git merge-base --is-ancestor' }) | Should -HaveCount 1
    }

    It 'Creates no Stable tag or GitHub release outside release-please' {
        $script:PublishDocument['jobs'].Contains('create-release') | Should -BeFalse
        $script:PublishText | Should -Not -Match 'ref=refs/tags/'
        $script:PublishText | Should -Not -Match 'gh release create '
        $script:PublishText | Should -Not -Match '--force'

        $token = Get-NamedJobStep -Document $script:PublishDocument -JobName 'publish-release' -StepName 'Generate GitHub App Token'
        [string]$token['id'] | Should -BeExactly 'app-token'
        [string]$token['uses'] | Should -Match '^actions/create-github-app-token@[0-9a-f]{40}$'
        $publish = Get-NamedJobStep -Document $script:PublishDocument -JobName 'publish-release' -StepName 'Publish GitHub Release'
        [string]$publish['env']['GH_TOKEN'] | Should -BeExactly '${{ steps.app-token.outputs.token }}'
        [string]$publish['run'] | Should -Match 'gh release edit "\$TAG" --draft=false'
    }

    It 'Packages every release asset from the validated release-please commit' {
        $jobs = $script:PublishDocument['jobs']
        foreach ($job in @('extension-provenance', 'plugin-package-release')) {
            [string]$jobs[$job]['with']['source-ref'] | Should -BeExactly '${{ needs.validate-release.outputs.sha }}'
            [string]$jobs[$job]['with']['version'] | Should -BeExactly '${{ needs.validate-release.outputs.version }}'
        }
    }

    It 'Validates a nonempty identical package set across both release channels' {
        $steps = @($script:PublishDocument['jobs']['validate-release']['steps'] | Where-Object {
                $_.Contains('run') -and [string]$_['run'] -match 'Get-MarketplacePackageMatrixCore'
            })
        $steps | Should -HaveCount 1
        $gate = [string]$steps[0]['run']
        $gate | Should -Match "@\('Stable', 'PreRelease'\)"
        $gate | Should -Match '\$names\.Count -eq 0'
        $gate | Should -Match '\[System\.StringComparer\]::Ordinal'
        $gate | Should -Match '-cne'
        $gate | Should -Match 'package sets differ'
        $gate | Should -Not -Match '-ne 1\b|exactly one'
        $script:PublishText | Should -Not -Match '(?i)one-package'
    }

    It 'Holds the cross-channel package-set invariant the Stable gate enforces' {
        $stable = [string[]]@((Get-MarketplacePackageMatrixCore -Channel Stable -CatalogPath $script:CatalogPath).Names)
        $preRelease = [string[]]@((Get-MarketplacePackageMatrixCore -Channel PreRelease -CatalogPath $script:CatalogPath).Names)
        @($stable).Count | Should -BeGreaterThan 0
        [array]::Sort($stable, [System.StringComparer]::Ordinal)
        [array]::Sort($preRelease, [System.StringComparer]::Ordinal)
        $stable | Should -Be $preRelease
    }
}

Describe 'Reusable packaging source contracts' -Tag 'Unit' {
    It 'Requires an explicit source ref and version in <Workflow>' -ForEach @(
        @{ Workflow = 'extension-package.yml' }
        @{ Workflow = 'extension-provenance.yml' }
        @{ Workflow = 'plugin-package.yml' }
    ) {
        $inputs = (Get-WorkflowDocument -Name $Workflow)['on']['workflow_call']['inputs']
        foreach ($name in @('source-ref', 'version')) {
            $inputs.Contains($name) | Should -BeTrue -Because "$Workflow must accept $name"
            $inputs[$name]['required'] | Should -BeTrue -Because "$Workflow must require $name"
            $inputs[$name].Contains('default') | Should -BeFalse -Because "$Workflow must not default $name"
        }
    }

    It 'Checks out the explicit source in every extension job of <Workflow>' -ForEach @(
        @{ Workflow = 'extension-package.yml' }
        @{ Workflow = 'extension-provenance.yml' }
    ) {
        $document = Get-WorkflowDocument -Name $Workflow
        $checkouts = 0
        foreach ($job in $document['jobs'].Values) {
            foreach ($step in @($job['steps'])) {
                if (-not $step.Contains('uses')) { continue }
                if ([string]$step['uses'] -notmatch '^actions/checkout@') { continue }
                $checkouts++
                [string]$step['with']['ref'] | Should -BeExactly '${{ inputs.source-ref }}'
                $step['with']['persist-credentials'] | Should -BeFalse
            }
        }
        $checkouts | Should -BeGreaterThan 0
    }

    It 'Requires an explicit provenance policy for plugin packaging' {
        $inputs = (Get-WorkflowDocument -Name 'plugin-package.yml')['on']['workflow_call']['inputs']
        $inputs.Contains('source-policy') | Should -BeTrue
        $inputs['source-policy']['required'] | Should -BeTrue
        [string]$inputs['source-policy']['type'] | Should -BeExactly 'string'
        $inputs['source-policy'].Contains('default') | Should -BeFalse
    }

    It 'Verifies source provenance before target-tree execution in plugin job <Job>' -ForEach @(
        @{ Job = 'discover-packages' }
        @{ Job = 'package' }
    ) {
        $document = Get-WorkflowDocument -Name 'plugin-package.yml'
        $steps = @($document['jobs'][$Job]['steps'])
        $checkout = @($steps | Where-Object { $_.Contains('uses') -and [string]$_['uses'] -match '^actions/checkout@' })
        $checkout | Should -HaveCount 1
        $checkout[0]['with'].Contains('ref') | Should -BeFalse
        $checkout[0]['with']['persist-credentials'] | Should -BeFalse

        $proof = @($steps | Where-Object { $_.Contains('run') -and [string]$_['run'] -match 'SOURCE_POLICY' })
        $proof | Should -HaveCount 1
        $run = [string]$proof[0]['run']
        foreach ($pattern in @(
                '\^\[0-9a-f\]\{40\}\$',
                "'main-ancestor'",
                "'release-tag'",
                'refs/heads/main:refs/remotes/origin/main',
                'git merge-base --is-ancestor',
                'refs/tags/hve-core-v\$\{INPUT_VERSION\}',
                'rev-parse --verify --end-of-options',
                'git checkout --quiet --detach',
                'git rev-parse HEAD',
                'Unsupported source policy'
            )) {
            $run | Should -Match $pattern
        }

        $proofIndex = [array]::IndexOf($steps, $proof[0])
        $executionIndexes = @(0..($steps.Count - 1) | Where-Object {
                ([string]$steps[$_]['uses'] -match '^\./|^actions/setup-node@') -or
                ([string]$steps[$_]['run'] -match 'npm (ci|run)|\.ps1\b')
            })
        $executionIndexes.Count | Should -BeGreaterThan 0
        $proofIndex | Should -BeLessThan $executionIndexes[0]
    }

    It 'Wires each release lane to its matching plugin source policy' {
        $preRelease = Get-WorkflowDocument -Name 'release-prerelease.yml'
        [string]$preRelease['jobs']['plugin-package-prerelease']['with']['source-policy'] |
            Should -BeExactly 'release-tag'

        $stable = Get-WorkflowDocument -Name 'release-stable-publish.yml'
        [string]$stable['jobs']['plugin-package-release']['with']['source-policy'] |
            Should -BeExactly 'release-tag'
    }

    It 'Fails a blank source ref or version in <Workflow>' -ForEach @(
        @{ Workflow = 'extension-package.yml'; Job = 'discover-packages' }
        @{ Workflow = 'extension-provenance.yml'; Job = 'discover-packages' }
        @{ Workflow = 'plugin-package.yml'; Job = 'discover-packages' }
        @{ Workflow = 'plugin-package.yml'; Job = 'publish-evidence' }
    ) {
        $steps = Get-JobStepText -Document (Get-WorkflowDocument -Name $Workflow) -JobName $Job
        @($steps | Where-Object { $_ -match 'source-ref is required and must not be blank' }) | Should -HaveCount 1
        @($steps | Where-Object { $_ -match 'version is required and must not be blank' }) | Should -HaveCount 1
    }

    It 'Consumes the version input in the plugin lane' {
        $steps = Get-JobStepText -Document (Get-WorkflowDocument -Name 'plugin-package.yml') -JobName 'package'
        @($steps | Where-Object { $_ -match 'Assert-PluginReleaseEvidence\.ps1' }) | Should -HaveCount 0

        $evidence = @(Get-JobStepText -Document (Get-WorkflowDocument -Name 'plugin-package.yml') -JobName 'publish-evidence' |
                Where-Object { $_ -match 'Assert-PluginReleaseEvidence\.ps1' })
        $evidence | Should -HaveCount 2
        foreach ($step in $evidence) {
            $step | Should -Match '-EvidenceVersion v2'
            $step | Should -Match '-SourceCommit \$env:INPUT_SOURCE_REF'
            $step | Should -Match '-Version \$env:INPUT_VERSION'
            $step | Should -Match '-ReleaseTag "hve-core-v\$env:INPUT_VERSION"'
        }
        $evidence[0] | Should -Match '-ExpectedPackageCount \$expectedCount'
        $evidence[0] | Should -Match '-OutputPath logs/plugin-release-evidence\.json'
        $evidence[1] | Should -Match '-ExpectedEvidencePath logs/plugin-release-evidence\.json'
    }

    It 'Avoids projected release catalogs in both channel package lanes' {
        $plugin = Get-WorkflowDocument -Name 'plugin-package.yml'
        $projection = $plugin['on']['workflow_call']['inputs']['project-release-catalog']
        $projection | Should -Not -BeNullOrEmpty
        [string]$projection['type'] | Should -BeExactly 'boolean'
        $projection['default'] | Should -BeFalse

        $preRelease = Get-WorkflowDocument -Name 'release-prerelease.yml'
        $preRelease['jobs']['plugin-package-prerelease']['with'].Contains('project-release-catalog') | Should -BeFalse
        $stable = Get-WorkflowDocument -Name 'release-stable-publish.yml'
        $stable['jobs']['plugin-package-release']['with'].Contains('project-release-catalog') | Should -BeFalse
    }

    It 'Binds recorded evidence to the discovered package set' {
        $document = Get-WorkflowDocument -Name 'plugin-package.yml'
        $record = Get-NamedJobStep -Document $document -JobName 'publish-evidence' -StepName 'Record canonical release evidence'
        [string]$record['env']['DISCOVERED_NAMES'] | Should -BeExactly '${{ needs.discover-packages.outputs.names }}'
        [string]$record['env']['INPUT_SOURCE_REF'] | Should -BeExactly '${{ inputs.source-ref }}'
        [string]$record['env']['INPUT_VERSION'] | Should -BeExactly '${{ inputs.version }}'

        $run = [string]$record['run']
        $run | Should -Match 'ConvertFrom-Json'
        $run | Should -Match 'Package discovery produced no package names'
        $run | Should -Match '-ExpectedPackageCount \$expectedCount'

        # Record, reproduce, then publish. A document that cannot be recomputed
        # from the same tracked sources never reaches the release.
        $names = [string[]]@($document['jobs']['publish-evidence']['steps'] | ForEach-Object { [string]$_['name'] })
        [array]::IndexOf($names, 'Record canonical release evidence') |
            Should -BeLessThan ([array]::IndexOf($names, 'Verify recorded evidence reproduces'))
        [array]::IndexOf($names, 'Verify recorded evidence reproduces') |
            Should -BeLessThan ([array]::IndexOf($names, 'Upload evidence to GitHub Release'))
    }

    # Historical plugins-v tags stay immutable and keep resolving. Retirement is
    # prospective only, so no workflow may write that namespace again.
    It 'Creates, moves, deletes, or force-updates no plugins-v tag in any workflow' {
        $workflows = @(Get-ChildItem -LiteralPath $script:WorkflowDirectory -Filter '*.yml' -File)
        $workflows | Should -Not -BeNullOrEmpty
        foreach ($workflow in $workflows) {
            $text = Get-Content -LiteralPath $workflow.FullName -Raw -Encoding utf8
            foreach ($forbidden in @(
                    'refs/tags/plugins-v',
                    'git tag[^\n]*plugins-v',
                    'gh release (create|delete)[^\n]*plugins-v',
                    'push --force',
                    'push[^\n]*--delete',
                    'Assert-PluginSnapshotTarget'
                )) {
                $text | Should -Not -Match $forbidden -Because "$($workflow.Name) must not write the plugins-v namespace"
            }
        }
    }

    It 'Retired the orphan snapshot publisher and every workflow reference to it' {
        Test-Path -LiteralPath (Join-Path $script:WorkflowDirectory 'plugin-snapshot-publish.yml') |
            Should -BeFalse -Because 'canonical release evidence replaces orphan snapshot publication'
        foreach ($workflow in @(Get-ChildItem -LiteralPath $script:WorkflowDirectory -Filter '*.yml' -File)) {
            $text = Get-Content -LiteralPath $workflow.FullName -Raw -Encoding utf8
            foreach ($forbidden in @('plugin-snapshot-publish\.yml', 'plugin-snapshot-production', 'plugins-snapshot/')) {
                $text | Should -Not -Match $forbidden -Because "$($workflow.Name) must not reference the retired publisher"
            }
        }
    }

    It 'Grants release write permission only to the evidence publishing job' {
        $document = Get-WorkflowDocument -Name 'plugin-package.yml'
        [string]$document['permissions']['contents'] | Should -BeExactly 'read'
        foreach ($name in @('discover-packages', 'package')) {
            [string]$document['jobs'][$name]['permissions']['contents'] | Should -BeExactly 'read'
        }

        $evidenceJob = $document['jobs']['publish-evidence']
        [string]$evidenceJob['needs'] | Should -BeExactly 'discover-packages'
        [string]$evidenceJob['permissions']['contents'] | Should -BeExactly 'write'
        [string]$evidenceJob['permissions']['id-token'] | Should -BeExactly 'write'
        [string]$evidenceJob['permissions']['attestations'] | Should -BeExactly 'write'

        $attest = Get-NamedJobStep -Document $document -JobName 'publish-evidence' -StepName 'Attest build provenance'
        [string]$attest['uses'] | Should -Match '^actions/attest-build-provenance@[0-9a-f]{40}$'
        [string]$attest['with']['subject-path'] | Should -BeExactly 'logs/plugin-release-evidence.json'

        $upload = Get-NamedJobStep -Document $document -JobName 'publish-evidence' -StepName 'Upload evidence to GitHub Release'
        [string]$upload['env']['TAG'] | Should -BeExactly 'hve-core-v${{ inputs.version }}'
        [string]$upload['run'] | Should -Match 'gh release upload "\$TAG"'
        [string]$upload['run'] | Should -Match 'logs/plugin-release-evidence\.json'
        [string]$upload['run'] | Should -Not -Match 'gh release (create|delete|edit)'
    }

    It 'Publishes canonical release evidence for both release lanes before publication' {
        foreach ($lane in @(
                @{ Workflow = 'release-prerelease.yml'; PackageJob = 'plugin-package-prerelease' },
                @{ Workflow = 'release-stable-publish.yml'; PackageJob = 'plugin-package-release' }
            )) {
            $document = Get-WorkflowDocument -Name $lane.Workflow
            $job = $document['jobs'][$lane.PackageJob]
            [string]$job['uses'] | Should -BeExactly './.github/workflows/plugin-package.yml'

            # The reusable call writes a release asset and attests it, so the
            # caller must grant exactly those permissions.
            [string]$job['permissions']['contents'] | Should -BeExactly 'write'
            [string]$job['permissions']['id-token'] | Should -BeExactly 'write'
            [string]$job['permissions']['attestations'] | Should -BeExactly 'write'

            # Producer before consumer: publication waits on the packaging call
            # that uploads the evidence asset every catalog consumer reads.
            @($document['jobs']['upload-plugin-packages']['needs']) | Should -Contain $lane.PackageJob
            @($document['jobs']['publish-release']['needs']) | Should -Contain 'upload-plugin-packages'
        }

        # Main synchronization reads the asset from the release it advertises,
        # so it depends on the producing job directly as well as on publication.
        $preRelease = Get-WorkflowDocument -Name 'release-prerelease.yml'
        @($preRelease['jobs']['main-catalog-sync']['needs']) | Should -Contain 'plugin-package-prerelease'
        @($preRelease['jobs']['main-catalog-sync']['needs']) | Should -Contain 'publish-release'
    }

    It 'Publishes the marketplace lanes from the released ref' {
        $stable = Get-WorkflowDocument -Name 'release-marketplace-stable.yml'
        $checkout = @($stable['jobs']['discover']['steps'] | Where-Object { $_.Contains('uses') -and [string]$_['uses'] -match '^actions/checkout@' })
        $checkout | Should -HaveCount 1
        [string]$checkout[0]['with']['ref'] | Should -BeExactly '${{ needs.normalize-version.outputs.tag }}'

        $prerelease = Get-WorkflowDocument -Name 'release-marketplace-prerelease.yml'
        [string]$prerelease['jobs']['package']['with']['source-ref'] | Should -BeExactly '${{ needs.validate-version.outputs.tag }}'
        [string]$prerelease['jobs']['package']['with']['version'] | Should -BeExactly '${{ needs.validate-version.outputs.version }}'
    }

    It 'Keeps PreRelease marketplace event values out of shell source and permits release lookup' {
        $document = Get-WorkflowDocument -Name 'release-marketplace-prerelease.yml'
        $job = $document['jobs']['validate-version']
        [string]$job['permissions']['contents'] | Should -BeExactly 'read'
        $steps = Get-JobStepText -Document $document -JobName 'validate-version'
        foreach ($step in $steps) {
            $step | Should -Not -Match '\$\{\{\s*(github\.event|inputs\.)'
        }
        $resolve = @($job['steps'] | Where-Object { [string]$_['id'] -eq 'resolve' })[0]
        foreach ($name in @('EVENT_NAME', 'EVENT_TAG', 'MANUAL_VERSION', 'REPOSITORY')) {
            $resolve['env'].Contains($name) | Should -BeTrue
        }

        # Manual dispatch and the automatic release event reach the same channel
        # parity gate, so neither path can publish the wrong minor.
        [string]$job['if'] | Should -Match "github\.event_name == 'workflow_dispatch'"
        [string]$job['if'] | Should -Match 'github\.event\.release\.prerelease == true'
        $validate = @($job['steps'] | Where-Object { [string]$_['id'] -eq 'validate' })[0]
        [string]$validate['run'] | Should -Match 'PUBLISH_MINOR % 2 == 0'
        [string]$validate['run'] | Should -Match 'requires odd minor version'
        [string]$document['jobs']['package']['with']['channel'] | Should -BeExactly 'PreRelease'

        $stable = Get-WorkflowDocument -Name 'release-marketplace-stable.yml'
        $stableJob = $stable['jobs']['normalize-version']
        [string]$stableJob['permissions']['contents'] | Should -BeExactly 'read'
        [string]$stableJob['if'] | Should -Match "github\.event_name == 'workflow_dispatch'"
        [string]$stableJob['if'] | Should -Match 'github\.event\.release\.prerelease == false'
        $normalize = @($stableJob['steps'] | Where-Object { [string]$_['id'] -eq 'normalize' })[0]
        [string]$normalize['run'] | Should -Match 'PUBLISH_MINOR % 2 == 1'
        [string]$normalize['run'] | Should -Match 'requires even minor version'
        $discover = @($stable['jobs']['discover']['steps'] | Where-Object { [string]$_['id'] -eq 'discover' })[0]
        [string]$discover['run'] | Should -Match "-Channel 'Stable'"
    }
}

Describe 'Promotion and main catalog synchronization contracts' -Tag 'Unit' {
    BeforeAll {
        $script:PrepareDocument = Get-WorkflowDocument -Name 'release-stable.yml'
        $script:PublishDocument = Get-WorkflowDocument -Name 'release-stable-publish.yml'
    }

    It 'Keeps a stable per-hop promotion head and restores only release-owned fields' -ForEach @(
        @{
            Workflow = 'release-prerelease-prepare.yml'
            Source = 'main'
            Base = 'release/prerelease'
            Head = 'release-promotion--main--to--release-prerelease'
            HeadVariable = 'PROMOTION_HEAD'
            RestoreSource = $false
            Config = 'release-please-prerelease-config.json'
            Manifest = '.release-please-prerelease-manifest.json'
            Channel = 'PreRelease'
            ResolverStep = 'Resolve exact PreRelease version'
            ResolverInput = '-CurrentPreReleaseVersion "$PRERELEASE_BASELINE"'
            ForbiddenResolverInput = '-PromotedSourceVersion'
            StableState = $false
        }
        @{
            Workflow = 'release-stable.yml'
            Source = 'release/prerelease'
            Base = 'release/stable'
            Head = 'release-promotion--release-prerelease--to--release-stable'
            HeadVariable = 'PROMOTION_HEAD_PREFIX'
            RestoreSource = $true
            Config = 'release-please-config.json'
            Manifest = '.release-please-manifest.json'
            Channel = 'Stable'
            ResolverStep = 'Resolve exact Stable version'
            ResolverInput = '-CurrentStableVersion "$STABLE_BASELINE"'
            ForbiddenResolverInput = '-CurrentPreReleaseVersion'
            StableState = $true
        }
    ) {
        $document = Get-WorkflowDocument -Name $Workflow
        [string]$document['env']['SOURCE_BRANCH'] | Should -BeExactly $Source
        [string]$document['env']['BASE_BRANCH'] | Should -BeExactly $Base
        [string]$document['env'][$HeadVariable] | Should -BeExactly $Head
        [string]$document['env']['TARGET_CONFIG'] | Should -BeExactly $Config
        [string]$document['env']['TARGET_MANIFEST'] | Should -BeExactly $Manifest

        $text = Get-WorkflowText -Name $Workflow
        $text | Should -Not -Match 'gh pr merge|--auto|push --force|ref=refs/tags/'

        # Commit classification and the cross-channel baseline read are gone;
        # each lane resolves from the branch state it already owns.
        $text | Should -Not -Match 'Classify promoted commits'
        $text | Should -Not -Match 'release-class|release_class|release class'
        $prepareOutputs = $document['jobs']['prepare-promotion']['outputs']
        foreach ($removed in @('release-class', 'stable-baseline-source')) {
            $prepareOutputs.Contains($removed) | Should -BeFalse
        }

        $resolver = Get-NamedJobStep -Document $document -JobName 'prepare-promotion' -StepName $ResolverStep
        $resolverRun = [string]$resolver['run']
        $resolverRun | Should -Match "-Channel $Channel"
        $resolverRun | Should -Match ([regex]::Escape($ResolverInput))
        $resolverRun | Should -Not -Match ([regex]::Escape($ForbiddenResolverInput))

        if ($StableState) {
            [string]$document['env']['SOURCE_MANIFEST'] | Should -BeExactly '.release-please-prerelease-manifest.json'
            [string]$prepareOutputs['stable-baseline'] | Should -BeExactly '${{ steps.state.outputs.stable-baseline }}'
            [string](Get-NamedJobStep -Document $document -JobName 'prepare-promotion' -StepName 'Resolve promotion state')['run'] |
                Should -Match 'STABLE_BASELINE=\$\(git show "refs/remotes/origin/\$BASE_BRANCH:\$TARGET_MANIFEST"'
        }
        else {
            foreach ($removed in @('SOURCE_MANIFEST', 'STABLE_BRANCH', 'STABLE_MANIFEST')) {
                $document['env'].Contains($removed) | Should -BeFalse
            }
            $prepareOutputs.Contains('stable-baseline') | Should -BeFalse
            $text | Should -Not -Match 'STABLE_BASELINE|STABLE_BRANCH|STABLE_MANIFEST|stable-baseline|release/stable|Read Stable baseline'
            $resolverRun | Should -Match ([regex]::Escape('^[0-9]+\.[0-9]+\.[0-9]+$'))
            $resolverRun | Should -Match '\[\[ .*VERSION.*=~ \^\[0-9\]'
            $resolverRun | Should -Not -Match '% 2'
        }

        $refresh = Get-NamedJobStep -Document $document -JobName 'prepare-promotion' -StepName 'Refresh the promotion head'
        $run = [string]$refresh['run']
        $run | Should -Match 'merge_ref "refs/remotes/origin/\$BASE_BRANCH" theirs'
        $run | Should -Match 'merge_ref "\$SOURCE_SHA" theirs'
        $run | Should -Match 'CHANGELOG\.md "\$TARGET_CONFIG" "\$TARGET_MANIFEST"'
        $run | Should -Match 'Update-VersionFiles\.ps1'
        $run | Should -Match '-CatalogRefMode Exact'
        $run | Should -Match '-SkipManifest'
        $run | Should -Match '-SkipPluginGenerate'
        $run | Should -Match 'release-as'
        if ($RestoreSource) {
            $run | Should -Match 'git checkout "\$SOURCE_SHA" --'
            $run | Should -Match 'package\.json package-lock\.json'
            $run | Should -Match 'extension/templates/package\.template\.json'
            $run | Should -Match '\.github/plugin/marketplace\.json'
            $run.IndexOf('merge_ref "$SOURCE_SHA"', [System.StringComparison]::Ordinal) |
                Should -BeLessThan $run.IndexOf('git checkout "$SOURCE_SHA"', [System.StringComparison]::Ordinal)
            $run.IndexOf('git checkout "$SOURCE_SHA"', [System.StringComparison]::Ordinal) |
                Should -BeLessThan $run.IndexOf('Update-VersionFiles.ps1', [System.StringComparison]::Ordinal)
        }
        else {
            $run | Should -Not -Match 'git checkout .*package\.json'
        }
        $run.IndexOf('merge_ref "$SOURCE_SHA"', [System.StringComparison]::Ordinal) |
            Should -BeLessThan $run.IndexOf('Update-VersionFiles.ps1', [System.StringComparison]::Ordinal)
        $run.IndexOf('Update-VersionFiles.ps1', [System.StringComparison]::Ordinal) |
            Should -BeLessThan $run.IndexOf('release-as', [System.StringComparison]::Ordinal)
    }

    # An occupied tag or GitHub release is immutable, so release-please could
    # never issue that candidate. The probe therefore runs read-only, before any
    # branch mutation or release-intent write, and fails closed.
    It 'Proves the candidate release identity is unoccupied before mutating <Workflow>' -ForEach @(
        @{ Workflow = 'release-prerelease-prepare.yml' }
        @{ Workflow = 'release-stable.yml' }
    ) {
        $document = Get-WorkflowDocument -Name $Workflow
        $probe = Get-NamedJobStep -Document $document -JobName 'prepare-promotion' -StepName 'Validate candidate release identity is unoccupied'
        [string]$probe['if'] | Should -BeExactly "`${{ steps.state.outputs.continue == 'true' }}"
        [string]$probe['env']['GH_TOKEN'] | Should -BeExactly '${{ github.token }}'
        [string]$probe['env']['REPOSITORY'] | Should -BeExactly '${{ github.repository }}'
        [string]$probe['env']['VERSION'] | Should -BeExactly '${{ steps.resolve.outputs.version }}'

        $run = [string]$probe['run']
        $run | Should -Match 'set -euo pipefail'
        $run | Should -Match ([regex]::Escape('cd "$GITHUB_WORKSPACE/promotion"'))
        $run | Should -Match ([regex]::Escape('CANDIDATE_REF="refs/tags/hve-core-v$VERSION"'))
        $run | Should -Not -Match ([regex]::Escape('refs/tags/plugins-v$VERSION'))
        $run | Should -Match ([regex]::Escape('git ls-remote origin "$CANDIDATE_REF"'))
        $run | Should -Match ([regex]::Escape('gh api --include "/repos/$REPOSITORY/releases/tags/hve-core-v$VERSION"'))

        # Only an explicit not-found proves availability; success means occupied
        # and every other outcome is an error rather than a pass.
        $run | Should -Match 'PROBE_EXIT=\$\?'
        $run | Should -Match '\[ "\$PROBE_EXIT" -eq 0 \]'
        $run | Should -Match 'HTTP 404'
        $run | Should -Match 'no explicit not-found result'

        foreach ($forbidden in @('gh release ', 'ref=refs/tags/', 'git tag', 'git push', '--force', '--method', '-X POST', '-X PATCH', '-X DELETE')) {
            $run | Should -Not -Match ([regex]::Escape($forbidden))
        }

        $names = [string[]]@($document['jobs']['prepare-promotion']['steps'] | ForEach-Object { [string]$_['name'] })
        [array]::IndexOf($names, 'Validate candidate release identity is unoccupied') |
            Should -BeLessThan ([array]::IndexOf($names, 'Refresh the promotion head'))
    }

    It 'Synchronizes main from validated PreRelease evidence and never from Stable' {
        $script:PublishDocument['jobs'].Contains('open-main-sync-pr') | Should -BeFalse
        (Get-WorkflowText -Name 'release-stable-publish.yml') | Should -Not -Match 'release-main-catalog-sync|gh pr merge|--auto'

        $document = Get-WorkflowDocument -Name 'release-main-catalog-sync.yml'
        [string]$document['env']['BASE_BRANCH'] | Should -BeExactly 'main'
        [string]$document['env']['SOURCE_BRANCH'] | Should -BeExactly 'release/prerelease'
        $job = $document['jobs']['sync-catalog']
        $job | Should -Not -BeNullOrEmpty
        $steps = Get-JobStepText -Document $document -JobName 'sync-catalog'
        $validation = @($steps | Where-Object { $_ -match 'RELEASE_TAG="hve-core-v\$VERSION"' })
        $validation | Should -HaveCount 1
        $validation[0] | Should -Match 'plugin-release-evidence\.json'
        $validation[0] | Should -Match 'hve-core/plugin-release-evidence/v2'
        $validation[0] | Should -Match '\.locator\.ref == \("hve-core-v" \+ \$version\)'
        $validation[0] | Should -Match '\.packageCount \| type == "number"'
        $validation[0] | Should -Match '\.digest \| type == "string"'
        $validation[0] | Should -Match 'carries no readable plugin-release-evidence\.json'
        $validation[0] | Should -Match 'gh release download "\$RELEASE_TAG"'
        $validation[0] | Should -Not -Match 'locator\.path'
        $validation[0] | Should -Match 'git merge-base --is-ancestor'
        $validation[0] | Should -Match 'continue=false'

        $update = @($steps | Where-Object { $_ -match 'Update-VersionFiles\.ps1' })
        $update | Should -HaveCount 1
        $update[0] | Should -Match 'git merge --no-edit -X theirs'
        $update[0] | Should -Match '-SkipManifest'
        $update[0] | Should -Match 'git show "\$RELEASE_SHA:CHANGELOG\.md" > CHANGELOG\.md'

        $open = @($steps | Where-Object { $_ -match 'gh pr create' })
        $open | Should -HaveCount 1
        $open[0] | Should -Match 'gh pr close'
        $open[0] | Should -Match 'Superseded by the \$\{VERSION\} main development catalog synchronization'
        $open[0] | Should -Not -Match 'gh pr merge|--auto|push --force'

        $prValidation = Get-WorkflowDocument -Name 'pr-validation.yml'
        @($prValidation['on']['pull_request']['branches']) |
            Should -Be @('main', 'develop', 'release/prerelease', 'release/stable')
        $monotonic = Get-NamedJobStep -Document $prValidation -JobName 'gate-completeness-check' -StepName 'Validate main catalog synchronization advances main'
        [string]$monotonic['if'] | Should -Match "github\.event\.pull_request\.base\.ref == 'main'"
        [string]$monotonic['if'] | Should -Match "release-main-catalog-sync--v"
        [string]$monotonic['run'] | Should -Match 'CANDIDATE=.*package\.json'
        [string]$monotonic['run'] | Should -Match 'main already carries'

        $stableMonotonic = Get-NamedJobStep -Document $prValidation -JobName 'gate-completeness-check' -StepName 'Validate Stable promotion intent advances release/stable'
        [string]$stableMonotonic['if'] | Should -Match "github\.event\.pull_request\.base\.ref == 'release/stable'"
        [string]$stableMonotonic['if'] | Should -Match 'release-promotion--release-prerelease--to--release-stable--hve-core-v'
        [string]$stableMonotonic['run'] | Should -Match 'CANDIDATE=.*release-please-config\.json'
        [string]$stableMonotonic['run'] | Should -Match 'BASELINE=.*\.release-please-manifest\.json'
        [string]$stableMonotonic['run'] | Should -Match 'already contained in release/stable'
        [string]$stableMonotonic['run'] | Should -Not -Match 'plugins-v\$CANDIDATE|hve-core-v\$CANDIDATE'
        # A separate-run gate re-derives parity and advancement from the pull
        # request head, independently of the preparation run that proposed them.
        [string]$stableMonotonic['run'] | Should -Match 'SOURCE_MINOR % 2 == 0'
        [string]$stableMonotonic['run'] | Should -Match 'CANDIDATE_MINOR % 2 != 0'
        [string]$stableMonotonic['run'] | Should -Match 'has an odd minor'
        [string]$stableMonotonic['run'] | Should -Match 'sort -V \| tail -1'
        [string]$stableMonotonic['run'] | Should -Match 'release/stable already carries \$BASELINE'
    }

    It 'Requires complete canonical release evidence in every catalog consumer' {
        $consumers = @(
            @{
                Document = Get-WorkflowDocument -Name 'release-main-catalog-sync.yml'
                Job = 'sync-catalog'
                Step = 'Validate release evidence and candidate version'
            }
            @{
                Document = $script:PrepareDocument
                Job = 'prepare-promotion'
                Step = 'Resolve promotion state'
            }
            @{
                Document = $script:PublishDocument
                Job = 'validate-trigger'
                Step = 'Validate selected promotion source and intent'
            }
        )

        foreach ($consumer in $consumers) {
            $step = Get-NamedJobStep -Document $consumer.Document -JobName $consumer.Job -StepName $consumer.Step
            $run = [string]$step['run']
            foreach ($pattern in @(
                    'hve-core/plugin-release-evidence/v2'
                    '\.sourceCommit == \$source_commit'
                    '\.version == \$version'
                    '\.locator\.ref == \("hve-core-v" \+ \$version\)'
                    '\.packageCount \| type == "number"'
                    '\.packages \| type == "array"'
                    '\.digest \| type == "string"'
                    'gh release download'
                    'plugin-release-evidence\.json'
                )) {
                $run | Should -Match $pattern
            }
            # Only the projected package path clause is dropped; the evidence
            # addresses the repository at its release tag instead.
            $run | Should -Not -Match 'locator\.path'
            $run | Should -Not -Match 'plugins-v'
        }

        $stableState = Get-NamedJobStep -Document $script:PrepareDocument -JobName 'prepare-promotion' -StepName 'Resolve promotion state'
        [string]$stableState['env']['REPOSITORY'] | Should -BeExactly '${{ github.repository }}'
        [string]$stableState['run'] | Should -Match ([regex]::Escape('--arg repository "$REPOSITORY"'))

        $mainSyncState = Get-NamedJobStep -Document (Get-WorkflowDocument -Name 'release-main-catalog-sync.yml') `
            -JobName 'sync-catalog' -StepName 'Validate release evidence and candidate version'
        [string]$mainSyncState['env']['REPOSITORY'] | Should -BeExactly '${{ github.repository }}'
        [string]$mainSyncState['env']['GH_TOKEN'] | Should -BeExactly '${{ steps.app-token.outputs.token }}'
    }
}

Describe 'Release and installation documentation contracts' -Tag 'Unit' {
    BeforeAll {
        $script:ReleaseDocumentationPaths = @(
            '.github/workflows/README.md'
            'extension/PACKAGING.md'
            'docs/architecture/workflows.md'
            'docs/contributing/release-process.md'
        )
        $script:ReleaseDocumentation = @{}
        foreach ($relativePath in $script:ReleaseDocumentationPaths) {
            $script:ReleaseDocumentation[$relativePath] = Get-Content -LiteralPath (Join-Path $script:RepositoryRoot $relativePath) -Raw -Encoding utf8
        }
    }

    It 'Derives documented Stable workflow job names from parsed YAML' {
        $readme = $script:ReleaseDocumentation['.github/workflows/README.md']
        foreach ($workflow in @('release-stable.yml', 'release-stable-publish.yml')) {
            $match = [regex]::Match($readme, "(?m)^$([regex]::Escape($workflow)) jobs: (?<jobs>[^\r\n]+)$")
            $match.Success | Should -BeTrue -Because "$workflow must have one enumerated job contract"
            $document = Get-WorkflowDocument -Name $workflow
            $documented = [string[]]@($match.Groups['jobs'].Value.Split(',') | ForEach-Object { $_.Trim() } | Sort-Object)
            $expected = [string[]]@($document['jobs'].Keys | Sort-Object)
            $documented | Should -Be $expected
        }
    }

    It 'Contains no hand-maintained numeric job totals or stale Stable workflow ownership' {
        foreach ($relativePath in $script:ReleaseDocumentationPaths) {
            $text = $script:ReleaseDocumentation[$relativePath]
            $text | Should -Not -Match '(?i)\b\d+\s+(?:parallel\s+)?jobs?\b' -Because "$relativePath must not maintain workflow job totals"
            $text | Should -Match 'release-stable\.yml' -Because "$relativePath must name the Stable promotion workflow"
            $text | Should -Match 'release/prerelease' -Because "$relativePath must name the Stable promotion source"
            $text | Should -Match 'release/stable' -Because "$relativePath must name the Stable promotion target"
            $text | Should -Match 'release-stable-publish\.yml' -Because "$relativePath must name Stable release-please orchestration"
            $text | Should -Match '(?i)release-please' -Because "$relativePath must name the release authority"
            $text | Should -Match '(?i)draft' -Because "$relativePath must describe the reviewed draft boundary"
            $text | Should -Not -Match 'plugins-v<version>' -Because "$relativePath must not document a future plugins-v snapshot locator"
            $text | Should -Match '(?i)main' -Because "$relativePath must describe the moving main catalog"
            if ($relativePath -ne 'extension/PACKAGING.md') {
                $text | Should -Match 'release-main-catalog-sync\.yml' -Because "$relativePath must name reviewed PreRelease catalog synchronization"
            }
        }
    }

    It 'Requires the implemented release ref, canonical evidence, signed asset, and retirement vocabulary' {
        foreach ($relativePath in $script:ReleaseDocumentationPaths) {
            $text = $script:ReleaseDocumentation[$relativePath]
            $text | Should -Match 'hve-core-v<version>' -Because "$relativePath must document the exact release ref"
            $text | Should -Match 'plugin-release-evidence\.json' -Because "$relativePath must document canonical release evidence on the hve-core release"
            $text | Should -Match '(?is)signed\s+plugin ZIPs?' -Because "$relativePath must keep signed plugin ZIPs as release deliverables"
            foreach ($asset in @('SBOM', 'Sigstore', 'in-toto')) {
                $text | Should -Match ([regex]::Escape($asset)) -Because "$relativePath must keep $asset assets as release deliverables"
            }
            $text | Should -Match '(?is)future\s+`plugins-v`\s+snapshot publication has stopped' -Because "$relativePath must state prospective-only snapshot retirement"
            $text | Should -Match '(?is)existing\s+`plugins-v`\s+tags\s+and\s+catalogs\s+remain\s+immutable\s+and\s+supported' -Because "$relativePath must keep historical plugins-v tags and catalogs supported"
        }
    }

    It 'States ref-less main refresh behavior and the main versus release attestation posture' {
        foreach ($relativePath in $script:ReleaseDocumentationPaths) {
            $text = $script:ReleaseDocumentation[$relativePath]
            $text | Should -Match '(?is)ref-less main catalog' -Because "$relativePath must name the ref-less main catalog"
            $text | Should -Match '(?is)(?:marketplace refresh|refreshes the marketplace)' -Because "$relativePath must require an explicit marketplace refresh instead of automatic main updates"
            $text | Should -Match '(?is)(?:plugin update|updates the plugin)' -Because "$relativePath must require an explicit plugin update instead of automatic main updates"
            $text | Should -Match '(?is)(?:without a|no)\s+release gate,\s+SBOM,\s+or\s+attestation' -Because "$relativePath must state that main bytes carry no release gate, SBOM, or attestation"
            $text | Should -Match '(?is)release-gated[^.]{0,120}SBOM-covered[^.]{0,120}attested' -Because "$relativePath must state that release channels remain gated and attested"
        }
    }

    It 'References only workflow files that exist' {
        foreach ($relativePath in $script:ReleaseDocumentationPaths) {
            $text = $script:ReleaseDocumentation[$relativePath]
            $workflowNames = @([regex]::Matches($text, '`(?<name>[a-z0-9-]+\.yml)`') | ForEach-Object { $_.Groups['name'].Value } | Sort-Object -Unique)
            foreach ($workflowName in $workflowNames) {
                Test-Path -LiteralPath (Join-Path $script:WorkflowDirectory $workflowName) -PathType Leaf |
                    Should -BeTrue -Because "$relativePath documents $workflowName"
            }
        }
    }

    It 'Treats capability groups as discovery aids rather than installable collections' {
        $rolePaths = @(
            'business-program-manager.md'
            'data-scientist.md'
            'security-architect.md'
            'sre-operations.md'
            'tech-lead.md'
            'tpm.md'
            'ux-designer.md'
        )
        $roleDirectory = Join-Path $script:RepositoryRoot 'docs/hve-guide/roles'
        foreach ($rolePath in $rolePaths) {
            $text = Get-Content -LiteralPath (Join-Path $roleDirectory $rolePath) -Raw -Encoding utf8
            $text | Should -Not -Match '(?im)^## Recommended Collections$'
            $text | Should -Not -Match '(?i)\bprimary collections?\b'
            $text | Should -Match '(?im)^## Capability Groups$'
            $text | Should -Match '(?i)selective clone'
        }
        $utility = Get-Content -LiteralPath (Join-Path $roleDirectory 'utility.md') -Raw -Encoding utf8
        $utility | Should -Not -Match '(?i)collection installation'
    }

    It 'Parses selective clone as the final install keyword' {
        $installPath = Join-Path $script:RepositoryRoot 'docs/getting-started/install.md'
        $installText = Get-Content -LiteralPath $installPath -Raw -Encoding utf8
        $match = [regex]::Match($installText, '(?s)\A---\r?\n(?<yaml>.*?)\r?\n---')
        $match.Success | Should -BeTrue
        $frontmatter = ConvertFrom-Yaml -Yaml $match.Groups['yaml'].Value
        $keywords = @($frontmatter['keywords'])
        $keywords[-1] | Should -BeExactly 'selective clone'
    }
}

Describe 'Catalog release ref and plugin locator consistency' -Tag 'Unit' {
    BeforeAll {
        $script:Catalog = Get-Content -LiteralPath $script:CatalogPath -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable
        $script:Template = Get-Content -LiteralPath (Join-Path $script:RepositoryRoot 'extension/templates/package.template.json') -Raw -Encoding utf8 | ConvertFrom-Json
        $script:Lock = Get-Content -LiteralPath (Join-Path $script:RepositoryRoot 'package-lock.json') -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable
    }

    It 'Agrees on one committed shared version without requiring a channel manifest on main' {
        $version = [string]$script:RootManifest.version
        $version | Should -Not -BeNullOrEmpty
        [string]$script:Template.version | Should -BeExactly $version
        [string]$script:Lock['version'] | Should -BeExactly $version
        [string]$script:Lock['packages']['']['version'] | Should -BeExactly $version
        [string]$script:Catalog['metadata']['version'] | Should -BeExactly $version
    }

    It 'Binds each release workflow to its own channel manifest while main skips manifests' {
        $preRelease = Get-WorkflowDocument -Name 'release-prerelease.yml'
        $preReleaseState = [string](Get-NamedJobStep -Document $preRelease -JobName 'validate-release' -StepName 'Verify committed pre-release state')['run']
        $preReleaseState | Should -Match '\.release-please-prerelease-manifest\.json'
        $preReleaseState | Should -Not -Match '"\.release-please-manifest\.json'
        $preReleaseState | Should -Match '\.source\.ref == \("hve-core-v" \+ \$version\)'

        $preReleaseSync = [string](Get-NamedJobStep -Document $preRelease -JobName 'sync-release-pr' -StepName 'Update committed version fields and retire the promotion intent')['run']
        $preReleaseSync | Should -Match '-CatalogRefMode Exact'

        $stable = Get-WorkflowDocument -Name 'release-stable-publish.yml'
        $stableState = [string](Get-NamedJobStep -Document $stable -JobName 'validate-release' -StepName 'Verify release version and committed state')['run']
        $stableState | Should -Match '"\.release-please-manifest\.json'
        $stableState | Should -Not -Match 'release-please-prerelease-manifest\.json'
        $stableState | Should -Match '\.source\.ref == \("hve-core-v" \+ \$version\)'
        $stableSync = [string](Get-NamedJobStep -Document $stable -JobName 'sync-release-pr' -StepName 'Update committed version fields and retire the promotion intent')['run']
        $stableSync | Should -Match '-CatalogRefMode Exact'
        # Final publication is an independent boundary: it rejects an odd minor
        # even though preparation already resolved an even one.
        $stableState | Should -Match 'MINOR % 2 != 0'
        $stableState | Should -Match 'has an odd minor'

        $mainSync = Get-WorkflowDocument -Name 'release-main-catalog-sync.yml'
        $mainUpdate = [string](Get-NamedJobStep -Document $mainSync -JobName 'sync-catalog' -StepName 'Update the main catalog')['run']
        $mainUpdate | Should -Match '-CatalogRefMode Remove'
        $mainUpdate | Should -Match '-SkipManifest'
        $mainUpdate | Should -Match 'main catalog entries must omit source\.ref and source\.sha'
        $mainUpdate | Should -Match '\(\.plugins \| type == "array"\)'

        $pluginPackage = Get-WorkflowText -Name 'plugin-package.yml'
        $pluginPackage | Should -Match '\$expectedRef = "hve-core-v\$env:INPUT_VERSION"'
    }

    # The committed catalog is the main channel. Release workflows add exact
    # refs to branch-owned catalog state before packaging or publication.
    It 'Keeps the committed main catalog canonical and ref-less' {
        $version = [string]$script:RootManifest.version
        @($script:Catalog['plugins']).Count | Should -BeGreaterThan 0
        foreach ($entry in @($script:Catalog['plugins'])) {
            [string]$entry['version'] | Should -BeExactly $version
            [string]$entry['source']['path'] | Should -BeExactly '.github'
            $entry['source'].Contains('ref') | Should -BeFalse
            $entry['source'].Contains('sha') | Should -BeFalse
        }
    }

    It 'Keeps main as a numeric moving catalog rather than a Stable release baseline' {
        $version = [string]$script:RootManifest.version
        $version | Should -Match '^\d+\.\d+\.\d+$'
        [string]$script:Catalog['metadata']['version'] | Should -BeExactly $version
    }
}
