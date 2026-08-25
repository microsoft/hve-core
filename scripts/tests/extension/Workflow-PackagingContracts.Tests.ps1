#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

# Running a workflow step body against fixtures needs the shell it declares and
# the jq the body calls, so the discovery phase records their availability.
$script:SkipShellFixtureTests = -not (
    (Get-Command bash -CommandType Application -ErrorAction SilentlyContinue) -and
    (Get-Command jq -CommandType Application -ErrorAction SilentlyContinue)
)

BeforeAll {
    $script:RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $script:WorkflowDirectory = Join-Path $script:RepositoryRoot '.github/workflows'

    # Every workflow that participates in building, attesting, publishing, or
    # reconciling the one hve-core package.
    $script:PackagingWorkflow = [string[]]@(
        'extension-package.yml'
        'extension-provenance.yml'
        'extension-marketplace-publish.yml'
        'release-marketplace-prerelease.yml'
        'release-marketplace-stable.yml'
        'release-prerelease.yml'
        'release-stable-publish.yml'
        'release-prerelease-prepare.yml'
        'release-stable.yml'
        'pr-validation.yml'
    )

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

    function Invoke-WorkflowShellStep {
        <#
        .SYNOPSIS
        Runs a parsed bash step body in a disposable extension template fixture.
        .PARAMETER Body
        Step run text.
        .PARAMETER TemplateVersion
        Version committed to the fixture extension template.
        .PARAMETER Environment
        Step environment variables, which may hold blank values.
        .OUTPUTS
        [pscustomobject] Exit code and captured annotation output.
        #>
        [CmdletBinding()]
        [OutputType([pscustomobject])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Body,

            [Parameter(Mandatory = $true)]
            [string]$TemplateVersion,

            [Parameter(Mandatory = $true)]
            [hashtable]$Environment
        )

        $fixture = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('n'))
        New-Item -ItemType Directory -Path (Join-Path $fixture 'extension/templates') -Force | Out-Null
        try {
            Set-Content -LiteralPath (Join-Path $fixture 'extension/templates/package.template.json') `
                -Value "{`"name`":`"hve-core`",`"version`":`"$TemplateVersion`"}" -Encoding utf8
            $stepPath = Join-Path $fixture 'step.sh'
            Set-Content -LiteralPath $stepPath -Value $Body -Encoding utf8

            # env carries blank values that a PowerShell environment assignment
            # would delete, which set -u would then report as an unset variable.
            $assignments = [string[]]@($Environment.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" })
            Push-Location -LiteralPath $fixture
            try {
                $output = & env @assignments bash $stepPath 2>$null
                return [pscustomobject]@{
                    ExitCode = $LASTEXITCODE
                    Output   = [string]::Join("`n", [string[]]@($output))
                }
            } finally {
                Pop-Location
            }
        } finally {
            Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Retired multi-package contracts' -Tag 'Unit' {
    # Every retired contract is proved absent from the active packaging and
    # release surface, so a reintroduced matrix or ZIP job fails here first.
    It 'Declares no package matrix input or output in <Workflow>' -ForEach @(
        @{ Workflow = 'extension-package.yml' }
        @{ Workflow = 'extension-provenance.yml' }
        @{ Workflow = 'extension-marketplace-publish.yml' }
        @{ Workflow = 'release-marketplace-prerelease.yml' }
        @{ Workflow = 'release-marketplace-stable.yml' }
        @{ Workflow = 'release-prerelease.yml' }
        @{ Workflow = 'release-stable-publish.yml' }
    ) {
        $text = Get-WorkflowText -Name $Workflow
        $text | Should -Not -Match 'packages-matrix'
        $text | Should -Not -Match 'matrix\.id'
        $text | Should -Not -Match 'PackageId'
    }

    It 'Declares no job-level matrix strategy in <Workflow>' -ForEach @(
        @{ Workflow = 'extension-package.yml' }
        @{ Workflow = 'extension-provenance.yml' }
        @{ Workflow = 'extension-marketplace-publish.yml' }
        @{ Workflow = 'release-prerelease.yml' }
        @{ Workflow = 'release-stable-publish.yml' }
    ) {
        $document = Get-WorkflowDocument -Name $Workflow
        foreach ($job in $document['jobs'].Keys) {
            $definition = $document['jobs'][$job]
            if ($definition.Contains('strategy')) {
                $definition['strategy'].Contains('matrix') |
                    Should -BeFalse -Because "$Workflow job '$job' packages one fixed identity"
            }
        }
    }

    It 'Invokes no retired package selection or discovery script in <Workflow>' -ForEach @(
        @{ Workflow = 'extension-package.yml' }
        @{ Workflow = 'extension-provenance.yml' }
        @{ Workflow = 'extension-marketplace-publish.yml' }
        @{ Workflow = 'release-marketplace-prerelease.yml' }
        @{ Workflow = 'release-marketplace-stable.yml' }
        @{ Workflow = 'release-prerelease.yml' }
        @{ Workflow = 'release-stable-publish.yml' }
        @{ Workflow = 'release-prerelease-prepare.yml' }
        @{ Workflow = 'release-stable.yml' }
        @{ Workflow = 'pr-validation.yml' }
    ) {
        $text = Get-WorkflowText -Name $Workflow
        $text | Should -Not -Match 'Get-MarketplacePackageMatrix'
        $text | Should -Not -Match 'Select-PackageVsix'
        $text | Should -Not -Match 'ExtensionIdentity'
        $text | Should -Not -Match 'Generate-Plugins'
        $text | Should -Not -Match 'Update-VersionFiles'
    }

    It 'Calls no plugin packaging workflow and uploads no plugin ZIP in <Workflow>' -ForEach @(
        @{ Workflow = 'release-prerelease.yml' }
        @{ Workflow = 'release-stable-publish.yml' }
    ) {
        $text = Get-WorkflowText -Name $Workflow
        $text | Should -Not -Match 'plugin-package\.yml'
        $text | Should -Not -Match 'dist/plugins'
        $text | Should -Not -Match "\-p '\*\.zip'"
        $text | Should -Not -Match 'HVE_PLUGIN_STAGING_ROOT'

        $document = Get-WorkflowDocument -Name $Workflow
        [string[]]@($document['jobs'].Keys) | Should -Not -Contain 'upload-plugin-packages'
        @($document['jobs'].Keys | Where-Object { $_ -like 'plugin-package*' }) | Should -BeNullOrEmpty
    }

    It 'Reads no plugin release evidence or release candidate record in <Workflow>' -ForEach @(
        @{ Workflow = 'release-prerelease.yml' }
        @{ Workflow = 'release-stable-publish.yml' }
        @{ Workflow = 'release-prerelease-prepare.yml' }
        @{ Workflow = 'release-stable.yml' }
        @{ Workflow = 'pr-validation.yml' }
    ) {
        $text = Get-WorkflowText -Name $Workflow
        $text | Should -Not -Match 'plugin-release-evidence'
        $text | Should -Not -Match 'release-candidate'
        $text | Should -Not -Match 'CandidateAction'
    }

    # A one-entry catalog carries a relative source, so no workflow may derive
    # or assert an immutable per-package locator.
    It 'Derives no catalog source locator in <Workflow>' -ForEach @(
        @{ Workflow = 'release-prerelease.yml' }
        @{ Workflow = 'release-stable-publish.yml' }
        @{ Workflow = 'release-prerelease-prepare.yml' }
        @{ Workflow = 'release-stable.yml' }
        @{ Workflow = 'pr-validation.yml' }
    ) {
        $text = Get-WorkflowText -Name $Workflow
        $text | Should -Not -Match 'BASELINE_TAG'
        $text | Should -Not -Match 'source\.ref'
    }
}

Describe 'One-package build and artifact naming' -Tag 'Unit' {
    It 'Packages one hve-core VSIX from the explicit source ref' {
        $document = Get-WorkflowDocument -Name 'extension-package.yml'
        [string[]]@($document['jobs'].Keys) | Should -Be @('package')

        $inputs = $document['on']['workflow_call']['inputs']
        $inputs['source-ref']['required'] | Should -BeTrue
        $inputs['version']['required'] | Should -BeTrue
        $inputs.Contains('channel') | Should -BeTrue
        $document['on']['workflow_call'].Contains('outputs') | Should -BeFalse

        $checkout = Get-NamedJobStep -Document $document -JobName 'package' -StepName 'Checkout code'
        [string]$checkout['with']['ref'] |
            Should -BeExactly '${{ github.sha }}'

        $steps = Get-JobStepText -Document $document -JobName 'package'
        @($steps | Where-Object { $_ -match 'Prepare-Extension\.ps1$' }) | Should -HaveCount 1
        @($steps | Where-Object { $_ -match 'Package-Extension\.ps1 @arguments' }) | Should -HaveCount 1
    }

    It 'Validates the source ref before checkout and packaging inputs before dependencies' {
        $document = Get-WorkflowDocument -Name 'extension-package.yml'
        $names = [string[]]@($document['jobs']['package']['steps'] | ForEach-Object { [string]$_['name'] })
        $names.IndexOf('Validate source ref') | Should -BeLessThan $names.IndexOf('Checkout code')
        $names.IndexOf('Checkout code') | Should -BeLessThan $names.IndexOf('Validate packaging inputs')
        $names.IndexOf('Validate packaging inputs') | Should -BeLessThan $names.IndexOf('Install dependencies')
    }

    It 'Accepts a source-ref equal to the run commit before checkout' -Skip:$script:SkipShellFixtureTests {
        $step = Get-NamedJobStep -Document (Get-WorkflowDocument -Name 'extension-package.yml') `
            -JobName 'package' -StepName 'Validate source ref'
        $result = Invoke-WorkflowShellStep -Body ([string]$step['run']) -TemplateVersion '3.3.0' -Environment @{
            EVENT_SHA        = 'abcdef1111111111111111111111111111111111'
            INPUT_SOURCE_REF = 'abcdef1111111111111111111111111111111111'
        }
        $result.ExitCode | Should -Be 0
    }

    It 'Rejects malformed source-ref <SourceRef> before checkout' -Skip:$script:SkipShellFixtureTests -ForEach @(
        @{ SourceRef = '' }
        @{ SourceRef = '-branch' }
        @{ SourceRef = 'bad..ref' }
        @{ SourceRef = 'refs/heads/bad ref' }
        @{ SourceRef = 'main' }
        @{ SourceRef = 'v3.2.2' }
        @{ SourceRef = 'refs/tags/v3.2.2' }
        @{ SourceRef = 'ABCDEF1111111111111111111111111111111111' }
        @{ SourceRef = '2222222222222222222222222222222222222222' }
    ) {
        $step = Get-NamedJobStep -Document (Get-WorkflowDocument -Name 'extension-package.yml') `
            -JobName 'package' -StepName 'Validate source ref'
        $result = Invoke-WorkflowShellStep -Body ([string]$step['run']) -TemplateVersion '3.3.0' -Environment @{
            EVENT_SHA        = 'abcdef1111111111111111111111111111111111'
            INPUT_SOURCE_REF = $SourceRef
        }
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'source-ref'
    }

    It 'Fails a committed template version mismatch in extension-package.yml' -Skip:$script:SkipShellFixtureTests {
        $step = Get-NamedJobStep -Document (Get-WorkflowDocument -Name 'extension-package.yml') `
            -JobName 'package' -StepName 'Validate packaging inputs'
        $result = Invoke-WorkflowShellStep -Body ([string]$step['run']) -TemplateVersion '3.3.0' -Environment @{
            INPUT_SOURCE_REF = '1111111111111111111111111111111111111111'
            INPUT_VERSION    = '3.5.0'
        }
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'is 3\.3\.0 but the caller requested 3\.5\.0'
    }

    It 'Fails a blank version in extension-package.yml' -Skip:$script:SkipShellFixtureTests {
        $step = Get-NamedJobStep -Document (Get-WorkflowDocument -Name 'extension-package.yml') `
            -JobName 'package' -StepName 'Validate packaging inputs'
        $result = Invoke-WorkflowShellStep -Body ([string]$step['run']) -TemplateVersion '3.3.0' -Environment @{
            INPUT_SOURCE_REF = '1111111111111111111111111111111111111111'
            INPUT_VERSION    = ''
        }
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'version is required'
    }

    # The builder and the attest workflow must agree on one artifact name, so
    # they can never disagree about what was signed within a run.
    It 'Matches the VSIX artifact producer and consumer names' {
        (Get-WorkflowText -Name 'extension-package.yml') | Should -Match 'name: extension-vsix'
        (Get-WorkflowText -Name 'extension-provenance.yml') | Should -Match 'name: extension-vsix'
    }
}

# A caller-supplied ref must never select a checked-out tree; the run's own
# commit is the only trusted selector, and the gates below are what make it so.
Describe 'Trusted source binding' -Tag 'Unit' {
    It 'Checks out the run commit in <Workflow> step <StepName>' -ForEach @(
        @{ Workflow = 'extension-package.yml'; JobName = 'package'; StepName = 'Checkout code' }
        @{ Workflow = 'extension-provenance.yml'; JobName = 'attest'; StepName = 'Checkout code' }
        @{ Workflow = 'extension-provenance.yml'; JobName = 'attest'; StepName = 'Checkout Syft config' }
        @{ Workflow = 'release-prerelease.yml'; JobName = 'generate-dependency-sbom'; StepName = 'Checkout dependency manifests' }
        @{ Workflow = 'release-prerelease.yml'; JobName = 'verify-provenance'; StepName = 'Checkout verification script' }
        @{ Workflow = 'release-stable-publish.yml'; JobName = 'generate-dependency-sbom'; StepName = 'Checkout dependency manifests' }
        @{ Workflow = 'release-stable-publish.yml'; JobName = 'verify-provenance'; StepName = 'Checkout verification script' }
    ) {
        $step = Get-NamedJobStep -Document (Get-WorkflowDocument -Name $Workflow) -JobName $JobName -StepName $StepName
        [string]$step['with']['ref'] | Should -BeExactly '${{ github.sha }}'
    }

    It 'Retains the release identity gate that makes the run commit trusted in <Workflow>' -ForEach @(
        @{ Workflow = 'release-prerelease.yml' }
        @{ Workflow = 'release-stable-publish.yml' }
    ) {
        $document = Get-WorkflowDocument -Name $Workflow
        $identity = Get-NamedJobStep -Document $document -JobName 'validate-release' -StepName 'Verify trusted release identity'
        [string]$identity['run'] | Should -Match 'MERGE_SHA'
        [string]$identity['run'] | Should -Match 'RELEASE_SHA'
        [string]$document['jobs']['validate-release']['outputs']['sha'] | Should -BeExactly '${{ github.sha }}'
        [string[]]@($document['jobs']['generate-dependency-sbom']['needs']) | Should -Contain 'validate-release'
        [string[]]@($document['jobs']['verify-provenance']['needs']) | Should -Contain 'validate-release'
    }
}

# Promotion validation reads through the API now, so the contracts that matter
# are the absence of pull-request Git transport and the immutability of the refs
# every read is pinned to.
Describe 'Immutable promotion validation' -Tag 'Unit' {
    $script:PromotionJobs = @(
        @{ Workflow = 'pr-validation.yml'; JobName = 'gate-completeness-check' }
        @{ Workflow = 'release-stable-publish.yml'; JobName = 'validate-trigger' }
    )

    It 'Uses no pull-request Git transport in <Workflow> job <JobName>' -ForEach $script:PromotionJobs {
        $steps = Get-JobStepText -Document (Get-WorkflowDocument -Name $Workflow) -JobName $JobName
        @($steps | Where-Object { $_ -match 'git\s+fetch|git\s+pull|gh\s+pr\s+checkout|refs/pull/' }) | Should -HaveCount 0
    }

    It 'Pins every promotion content read to a resolved commit in <Workflow> job <JobName>' -ForEach $script:PromotionJobs {
        $text = (Get-JobStepText -Document (Get-WorkflowDocument -Name $Workflow) -JobName $JobName) -join "`n"
        $refs = @([regex]::Matches($text, '\?ref=\$(?<name>[A-Za-z_]+)') | ForEach-Object { $_.Groups['name'].Value } | Sort-Object -Unique)
        $refs | Should -Not -BeNullOrEmpty
        @($refs | Where-Object { $_ -notin @('HEAD_SHA', 'EVENT_SHA', 'BASELINE_SHA', 'SOURCE_SHA', 'STABLE_SHA', 'PRERELEASE_SHA') }) |
            Should -BeNullOrEmpty
    }

    It 'Bounds annotated tag peeling in <Workflow> job <JobName>' -ForEach $script:PromotionJobs {
        $text = (Get-JobStepText -Document (Get-WorkflowDocument -Name $Workflow) -JobName $JobName) -join "`n"
        $text | Should -Match 'hop.*-lt 10'
        $text | Should -Match 'tag chain revisits'
        $text | Should -Match 'unsupported object type'
        $text | Should -Match 'did not peel to a commit'
    }

    It 'Proves containment through compare status rather than local ancestry in <Workflow> job <JobName>' -ForEach $script:PromotionJobs {
        $text = (Get-JobStepText -Document (Get-WorkflowDocument -Name $Workflow) -JobName $JobName) -join "`n"
        $text | Should -Match 'compare/\$SOURCE_SHA\.\.\.'
        $text | Should -Match "'ahead'"
        $text | Should -Match "'identical'"
        $text | Should -Not -Match 'merge-base'
    }

    It 'Declares only the token scope each promotion job needs' {
        $gate = (Get-WorkflowDocument -Name 'pr-validation.yml')['jobs']['gate-completeness-check']['permissions']
        [string]$gate['contents'] | Should -BeExactly 'read'
        [string]$gate['pull-requests'] | Should -BeExactly 'read'
        @($gate.Keys) | Should -HaveCount 2

        # The Stable trigger compares immutable event SHAs, so it needs no
        # pull-request scope at all.
        $trigger = (Get-WorkflowDocument -Name 'release-stable-publish.yml')['jobs']['validate-trigger']['permissions']
        [string]$trigger['contents'] | Should -BeExactly 'read'
        @($trigger.Keys) | Should -HaveCount 1
    }

    It 'Retains every Stable trigger gate without a validation checkout' {
        $document = Get-WorkflowDocument -Name 'release-stable-publish.yml'
        $names = [string[]]@($document['jobs']['validate-trigger']['steps'] | ForEach-Object { [string]$_['name'] })
        $names | Should -Not -Contain 'Checkout Stable trigger validation workspace'

        $steps = Get-JobStepText -Document $document -JobName 'validate-trigger'
        foreach ($gate in @(
                'is not a merged same-repository pull request',
                'does not match event SHA',
                'is not an authorized Stable release head',
                'is not a published, non-draft GitHub PreRelease',
                'but the PreRelease manifest carries',
                'is not contained in release/prerelease',
                'does not contain selected source',
                'still carries release-as')) {
            @($steps | Where-Object { $_ -match [regex]::Escape($gate) }) |
                Should -Not -BeNullOrEmpty -Because "the '$gate' check must survive the API migration"
        }
    }
}

# The release preparation tree is untrusted data. These contracts keep the write
# credential out of it and bind the push to the commit the tree was built from.
Describe 'Release preparation transport' -Tag 'Unit' {
    $script:SyncWorkflows = @(
        @{ Workflow = 'release-prerelease.yml' }
        @{ Workflow = 'release-stable-publish.yml' }
    )

    It 'Fetches release preparation data without a credential in <Workflow>' -ForEach $script:SyncWorkflows {
        $document = Get-WorkflowDocument -Name $Workflow
        $names = [string[]]@($document['jobs']['sync-release-pr']['steps'] | ForEach-Object { [string]$_['name'] })
        $names | Should -Not -Contain 'Checkout release preparation data'

        $checkouts = @($document['jobs']['sync-release-pr']['steps'] | Where-Object { [string]$_['uses'] -match 'actions/checkout@' })
        $checkouts | Should -HaveCount 1
        [string]$checkouts[0]['with']['ref'] | Should -BeExactly '${{ github.sha }}'
        [string]$checkouts[0]['with']['persist-credentials'] | Should -Match '^[Ff]alse$'

        $prepare = Get-NamedJobStep -Document $document -JobName 'sync-release-pr' `
            -StepName 'Resolve and fetch the release preparation commit'
        [string]$prepare['run'] | Should -Match 'credential\.helper= fetch'
        [string]$prepare['run'] | Should -Not -Match 'x-access-token'
    }

    It 'Binds the preparation tree to an API-resolved immutable commit in <Workflow>' -ForEach $script:SyncWorkflows {
        $prepare = Get-NamedJobStep -Document (Get-WorkflowDocument -Name $Workflow) -JobName 'sync-release-pr' `
            -StepName 'Resolve and fetch the release preparation commit'
        $run = [string]$prepare['run']
        $run | Should -Match 'release-please--'
        $run | Should -Match 'is not a managed release preparation branch'
        $run | Should -Match 'did not resolve to a commit SHA'
        $run | Should -Match 'moved from .* during preparation'
        $run | Should -Match 'commit=\$resolved_object'
    }

    It 'Transforms the preparation tree without the write token in <Workflow>' -ForEach $script:SyncWorkflows {
        $transform = Get-NamedJobStep -Document (Get-WorkflowDocument -Name $Workflow) -JobName 'sync-release-pr' `
            -StepName 'Update committed version fields and retire the promotion intent'
        $transformEnv = if ($transform.Contains('env')) { $transform['env'] } else { $null }
        $envKeys = if ($null -ne $transformEnv) { [string[]]@($transformEnv.Keys) } else { @() }
        @($envKeys | Where-Object { $_ -match 'TOKEN' }) | Should -BeNullOrEmpty
        [string]$transform['run'] | Should -Not -Match 'git push'
        [string]$transform['run'] | Should -Match 'committed=false'
        [string]$transform['run'] | Should -Match 'committed=true'
    }

    It 'Scopes the write token to a lease-guarded push in <Workflow>' -ForEach $script:SyncWorkflows {
        $document = Get-WorkflowDocument -Name $Workflow
        $push = Get-NamedJobStep -Document $document -JobName 'sync-release-pr' `
            -StepName 'Push the synchronized release preparation commit'
        [string]$push['if'] | Should -Match "steps\.transform\.outputs\.committed == 'true'"
        [string]$push['env']['GH_APP_TOKEN'] | Should -BeExactly '${{ steps.app-token.outputs.token }}'
        [string]$push['run'] | Should -Match '--force-with-lease="refs/heads/\$RELEASE_BRANCH:\$EXPECTED_COMMIT"'

        $tokenSteps = @($document['jobs']['sync-release-pr']['steps'] | Where-Object {
                $stepEnv = if ($_.Contains('env')) { $_['env'] } else { $null }
                $null -ne $stepEnv -and @($stepEnv.Keys) -contains 'GH_APP_TOKEN'
            })
        $tokenSteps | Should -HaveCount 1
    }
}

Describe 'Retained provenance and SBOM assurance' -Tag 'Unit' {
    BeforeAll {
        $script:ProvenanceDocument = Get-WorkflowDocument -Name 'extension-provenance.yml'
        $script:ProvenanceSteps = Get-JobStepText -Document $script:ProvenanceDocument -JobName 'attest'
    }

    It 'Attests one VSIX with build provenance, per-VSIX SBOM, and dependency SBOM' {
        [string[]]@($script:ProvenanceDocument['jobs'].Keys) | Should -Be @('attest')

        @($script:ProvenanceSteps | Where-Object { $_ -match 'anchore/sbom-action@' }) | Should -HaveCount 1
        @($script:ProvenanceSteps | Where-Object { $_ -match 'actions/attest-build-provenance@' }) | Should -HaveCount 1
        @($script:ProvenanceSteps | Where-Object { $_ -match 'actions/attest@' }) | Should -HaveCount 2

        $text = Get-WorkflowText -Name 'extension-provenance.yml'
        $text | Should -Match 'sbom-path: extension/\$\{\{ steps\.vsix\.outputs\.name \}\}\.spdx\.json'
        $text | Should -Match 'sbom-path: sbom/dependencies\.spdx\.json'
    }

    It 'Resolves the built VSIX through the shared resolver' {
        @($script:ProvenanceSteps | Where-Object { $_ -match 'Resolve-VsixFile\.ps1 -DirectoryPath \$env:VSIX_DIRECTORY' }) | Should -HaveCount 1
    }

    It 'Exports the attestation bundle sidecars and uploads them with the VSIX' {
        @($script:ProvenanceSteps | Where-Object { $_ -match 'Export-AttestationBundle\.ps1' }) | Should -HaveCount 1
        $text = Get-WorkflowText -Name 'extension-provenance.yml'
        $text | Should -Match 'SIGSTORE_PATH: extension/\$\{\{ steps\.vsix\.outputs\.name \}\}\.sigstore\.json'
        $text | Should -Match 'INTOTO_PATH: extension/\$\{\{ steps\.vsix\.outputs\.name \}\}\.intoto\.jsonl'
        $text | Should -Match 'gh release upload'
    }

    # The privileged attest workflow signs what the unprivileged builder
    # produced, so it may run neither packaging script nor a dependency install.
    It 'Runs no packaging or dependency install in extension-provenance.yml' {
        $text = Get-WorkflowText -Name 'extension-provenance.yml'
        $text | Should -Not -Match 'Prepare-Extension\.ps1'
        $text | Should -Not -Match 'Package-Extension\.ps1'
        $text | Should -Not -Match 'npm ci'
        $text | Should -Not -Match 'actions/setup-node@'
    }

    It 'Requires the attestation source ref to be this run commit' {
        $script:ProvenanceDocument['on']['workflow_call']['inputs']['source-ref']['required'] | Should -BeTrue
        @($script:ProvenanceSteps | Where-Object { $_ -match 'is not the attestation source commit' }) | Should -HaveCount 1
    }

    It 'Verifies release provenance for one VSIX in <Workflow>' -ForEach @(
        @{ Workflow = 'release-prerelease.yml' }
        @{ Workflow = 'release-stable-publish.yml' }
    ) {
        $steps = Get-JobStepText -Document (Get-WorkflowDocument -Name $Workflow) -JobName 'verify-provenance'
        @($steps | Where-Object { $_ -match 'Invoke-ProvenanceVerification\.ps1' }) | Should -HaveCount 1
        @($steps | Where-Object { $_ -match "\-p '\*\.vsix'" }) | Should -HaveCount 1
    }

    It 'Generates and uploads the dependency SBOM in <Workflow>' -ForEach @(
        @{ Workflow = 'release-prerelease.yml' }
        @{ Workflow = 'release-stable-publish.yml' }
    ) {
        $document = Get-WorkflowDocument -Name $Workflow
        $steps = Get-JobStepText -Document $document -JobName 'generate-dependency-sbom'
        @($steps | Where-Object { $_ -match 'anchore/sbom-action@' }) | Should -HaveCount 1
        @($steps | Where-Object { $_ -match 'gh release upload' }) | Should -HaveCount 1

        $artifactNames = [string[]]@($document['jobs']['generate-dependency-sbom']['steps'] |
                Where-Object { $_.Contains('with') -and $_['with'].Contains('name') } |
                ForEach-Object { [string]$_['with']['name'] })
        $artifactNames | Should -Contain 'sbom-dependencies'
    }
}

Describe 'Retained marketplace publication' -Tag 'Unit' {
    BeforeAll {
        $script:PublishDocument = Get-WorkflowDocument -Name 'extension-marketplace-publish.yml'
    }

    It 'Runs validation, verification, preparation, and publication in that order' {
        # Parsed YAML mappings carry no key order, so membership and the needs
        # closure express the sequence instead.
        [string[]]@($script:PublishDocument['jobs'].Keys) | Sort-Object |
            Should -Be @('prepare-publisher', 'publish', 'validate-inputs', 'verify')
        [string[]]@($script:PublishDocument['jobs']['verify']['needs']) | Should -Be @('validate-inputs')
        [string[]]@($script:PublishDocument['jobs']['prepare-publisher']['needs']) | Should -Be @('validate-inputs', 'verify')
        [string[]]@($script:PublishDocument['jobs']['publish']['needs']) | Should -Be @('validate-inputs', 'verify', 'prepare-publisher')
    }

    It 'Requires only the release tag and channel flag' {
        $inputs = $script:PublishDocument['on']['workflow_call']['inputs']
        [string[]]@($inputs.Keys) | Sort-Object | Should -Be @('pre-release', 'tag')
        $inputs['tag']['required'] | Should -BeTrue
    }

    It 'Validates the channel tag namespace and minor parity before any credential' {
        $steps = Get-JobStepText -Document $script:PublishDocument -JobName 'validate-inputs'
        @($steps | Where-Object { $_ -match 'Release tag does not match the selected channel' }) | Should -HaveCount 1
        @($steps | Where-Object { $_ -match 'requires an \$expected_parity_label minor version' }) | Should -HaveCount 1
        @($steps | Where-Object { $_ -match 'azure/login@' }) | Should -HaveCount 0
    }

    It 'Downloads exactly one attested hve-core VSIX from the release tag' {
        $steps = Get-JobStepText -Document $script:PublishDocument -JobName 'verify'
        @($steps | Where-Object { $_ -match "--pattern 'hve-core-\*\.vsix'" }) | Should -HaveCount 1
        @($steps | Where-Object { $_ -match 'Expected exactly one hve-core VSIX' }) | Should -HaveCount 1
    }

    It 'Verifies attested provenance in both the verify and publish jobs' {
        foreach ($job in @('verify', 'publish')) {
            $steps = Get-JobStepText -Document $script:PublishDocument -JobName $job
            @($steps | Where-Object { $_ -match 'gh attestation verify "\$VSIX_FILE"' }) |
                Should -HaveCount 1 -Because "job '$job' verifies before it trusts the artifact"
            @($steps | Where-Object { $_ -match '--signer-workflow "?\$SIGNER_WORKFLOW"?' }) | Should -HaveCount 1
            @($steps | Where-Object { $_ -match '--source-digest "\$RELEASE_DIGEST"' }) | Should -HaveCount 1
        }
    }

    # Publish credentials become active only in the protected environment job,
    # and the toolchain install that runs lifecycle scripts stays outside it.
    It 'Holds the marketplace credentials boundary' {
        [string]$script:PublishDocument['jobs']['publish']['environment'] | Should -BeExactly 'marketplace'
        $script:PublishDocument['jobs']['prepare-publisher'].Contains('environment') | Should -BeFalse

        $prepareSteps = Get-JobStepText -Document $script:PublishDocument -JobName 'prepare-publisher'
        @($prepareSteps | Where-Object { $_ -match 'npm ci .*--ignore-scripts=false' }) | Should -HaveCount 1

        $publishSteps = Get-JobStepText -Document $script:PublishDocument -JobName 'publish'
        @($publishSteps | Where-Object { $_ -match 'npm ci' }) | Should -HaveCount 0
        @($publishSteps | Where-Object { $_ -match 'azure/login@' }) | Should -HaveCount 1
        @($publishSteps | Where-Object { $_ -match '"\$VSCE_BIN" "\$\{arguments\[@\]\}"' }) | Should -HaveCount 1
    }

    It 'Binds publication to the one hve-core identity inside the protected job' {
        $publishSteps = Get-JobStepText -Document $script:PublishDocument -JobName 'publish'
        @($publishSteps | Where-Object { $_ -match ([regex]::Escape("EXTENSION_NAME='hve-core'")) }) | Should -HaveCount 1
        @($publishSteps | Where-Object { $_ -match '\.psm1|Get-ExtensionIdentity|Get-ExtensionVsixGlob' }) | Should -HaveCount 0
    }

    It 'Carries the channel pre-release flag into vsce' {
        $publishSteps = Get-JobStepText -Document $script:PublishDocument -JobName 'publish'
        @($publishSteps | Where-Object { $_ -match 'arguments\+=\(--pre-release\)' }) | Should -HaveCount 1
    }

    It 'Publishes only from the marketplace publish workflow' {
        foreach ($workflow in $script:PackagingWorkflow) {
            if ($workflow -eq 'extension-marketplace-publish.yml') { continue }
            (Get-WorkflowText -Name $workflow) |
                Should -Not -Match 'vsce.*publish' -Because "$workflow must route publication through the shared workflow"
        }
    }

    It 'Feeds the released tag into the publish workflow from <Workflow>' -ForEach @(
        @{ Workflow = 'release-marketplace-prerelease.yml'; Source = 'validate-version'; PreRelease = $true }
        @{ Workflow = 'release-marketplace-stable.yml'; Source = 'normalize-version'; PreRelease = $false }
    ) {
        $document = Get-WorkflowDocument -Name $Workflow
        $publish = $document['jobs']['publish']
        [string]$publish['uses'] | Should -BeExactly './.github/workflows/extension-marketplace-publish.yml'
        [string]$publish['with']['tag'] | Should -BeExactly "`${{ needs.$Source.outputs.tag }}"
        $publish['with']['pre-release'] | Should -Be $PreRelease
        $publish['with'].Contains('packages-matrix') | Should -BeFalse
        [string]$publish['if'] | Should -Match 'dry-run'
    }

    It 'Verifies the released catalog version before publishing in <Workflow>' -ForEach @(
        @{ Workflow = 'release-marketplace-prerelease.yml' }
        @{ Workflow = 'release-marketplace-stable.yml' }
    ) {
        $document = Get-WorkflowDocument -Name $Workflow
        $document['jobs'].Contains('verify-catalog') | Should -BeTrue
        $document['jobs'].Contains('discover') | Should -BeFalse
        $steps = Get-JobStepText -Document $document -JobName 'verify-catalog'
        @($steps | Where-Object { $_ -match 'Catalog version \$catalog_version at the release ref does not match' }) | Should -HaveCount 1
    }
}

Describe 'Retained release reconciliation and OpenVEX' -Tag 'Unit' {
    It 'Reconciles a matching published release against the fixed asset set in <Workflow>' -ForEach @(
        @{ Workflow = 'release-prerelease.yml'; Required = @('dependencies.spdx.json'); Optional = @() }
        @{ Workflow = 'release-stable-publish.yml'; Required = @('dependencies.spdx.json', 'hve-core.openvex.json'); Optional = @('dependency-diff.md') }
    ) {
        $step = Get-NamedJobStep -Document (Get-WorkflowDocument -Name $Workflow) `
            -JobName 'validate-release' -StepName 'Verify published release assets'
        $run = [string]$step['run']
        $run | Should -Match 'Assert-ReleaseAssetSet\.ps1'
        $run | Should -Match '-AssetNamePath "\$ASSET_NAMES"'
        $run | Should -Match '-RequiredAssetPath "\$REQUIRED_LIST"'
        $run | Should -Match '-Version "\$RELEASE_VERSION"'
        $run | Should -Match '-ReleaseTag "\$RELEASE_TAG"'
        $run | Should -Not -Match '-EvidencePath'
        $run | Should -Not -Match '-CatalogPath'
        $run | Should -Not -Match '-Channel'

        $declared = [string[]]@(([string]$step['env']['REQUIRED_ASSETS']).Split("`n") |
                ForEach-Object { $_.Trim() } | Where-Object { $_ })
        $declared | Should -Be $Required

        if ($Optional.Count -gt 0) {
            $run | Should -Match '-OptionalAssetPath "\$OPTIONAL_LIST"'
            $optionalDeclared = [string[]]@(([string]$step['env']['OPTIONAL_ASSETS']).Split("`n") |
                    ForEach-Object { $_.Trim() } | Where-Object { $_ })
            $optionalDeclared | Should -Be $Optional
        }
        else {
            $run | Should -Not -Match '-OptionalAssetPath'
            $step['env'].Contains('OPTIONAL_ASSETS') | Should -BeFalse
        }
    }

    It 'Verifies every committed version field at the released commit in <Workflow>' -ForEach @(
        @{ Workflow = 'release-prerelease.yml'; Manifest = '.release-please-prerelease-manifest.json' }
        @{ Workflow = 'release-stable-publish.yml'; Manifest = '.release-please-manifest.json' }
    ) {
        $steps = Get-JobStepText -Document (Get-WorkflowDocument -Name $Workflow) -JobName 'validate-release'
        $verify = @($steps | Where-Object { $_ -match 'release-please reported \$RELEASE_VERSION' })
        $verify | Should -HaveCount 1
        foreach ($path in @('package\.json', 'package-lock\.json', [regex]::Escape($Manifest),
                'extension/templates/package\.template\.json', 'plugin\.json',
                '\.github/plugin/marketplace\.json:\.metadata\.version',
                '\.github/plugin/marketplace\.json:\.plugins\[0\]\.version')) {
            $verify[0] | Should -Match $path
        }
    }

    It 'Attests and uploads the Stable OpenVEX document' {
        $document = Get-WorkflowDocument -Name 'release-stable-publish.yml'
        [string]$document['jobs']['vex-attest']['uses'] | Should -BeExactly './.github/workflows/vex-attest.yml'
        [string]$document['jobs']['vex-attest']['with']['sbom-artifact'] | Should -BeExactly 'sbom-dependencies'

        $verifySteps = Get-JobStepText -Document $document -JobName 'verify-provenance'
        @($verifySteps | Where-Object { $_ -match "\-p 'hve-core\.openvex\.json'" }) | Should -HaveCount 1
        [string[]]@($document['jobs']['verify-provenance']['needs']) | Should -Contain 'vex-attest'
        [string[]]@($document['jobs']['publish-release']['needs']) | Should -Contain 'vex-attest'
    }

    It 'Documents VSIX and VEX verification without a plugin ZIP instruction' {
        $notes = [string](Get-NamedJobStep -Document (Get-WorkflowDocument -Name 'release-stable-publish.yml') `
                -JobName 'append-verification-notes' -StepName 'Append verification section to release notes')['run']
        $notes | Should -Match 'gh attestation verify <file>\.vsix'
        $notes | Should -Match 'gh attestation verify hve-core\.openvex\.json'
        $notes | Should -Not -Match '<file>\.zip'
    }

    It 'Skips every artifact-producing chain for a matching published release in <Workflow>' -ForEach @(
        @{ Workflow = 'release-prerelease.yml'; Package = 'extension-package-prerelease'; Provenance = 'extension-provenance-prerelease' }
        @{ Workflow = 'release-stable-publish.yml'; Package = 'extension-package-release'; Provenance = 'extension-provenance' }
    ) {
        $document = Get-WorkflowDocument -Name $Workflow
        foreach ($job in @($Package, $Provenance, 'generate-dependency-sbom')) {
            [string]$document['jobs'][$job]['if'] |
                Should -Match "release-state != 'published'" -Because "$Workflow job '$job' must not rebuild a published release"
        }
    }
}

Describe 'Release-please ownership and promotion transforms' -Tag 'Unit' {
    It 'Versions root plugin.json in <Config>' -ForEach @(
        @{ Config = 'release-please-config.json' }
        @{ Config = 'release-please-prerelease-config.json' }
    ) {
        $path = Join-Path $script:RepositoryRoot $Config
        $config = Get-Content -LiteralPath $path -Raw -Encoding utf8 | ConvertFrom-Json
        $extraFiles = @($config.packages.'.'.'extra-files')
        @($extraFiles | Where-Object { $_.path -eq 'plugin.json' -and $_.jsonpath -eq '$.version' }) |
            Should -HaveCount 1
        @($extraFiles | Where-Object { $_.path -eq '.github/plugin.json' }) |
            Should -HaveCount 0
    }

    It 'Creates no tag or GitHub release outside release-please in <Workflow>' -ForEach @(
        @{ Workflow = 'release-prerelease.yml' }
        @{ Workflow = 'release-stable-publish.yml' }
        @{ Workflow = 'release-prerelease-prepare.yml' }
        @{ Workflow = 'release-stable.yml' }
    ) {
        $text = Get-WorkflowText -Name $Workflow
        $text | Should -Not -Match 'gh release create'
        $text | Should -Not -Match 'git tag'
        $text | Should -Not -Match 'git push .*refs/tags'
    }

    It 'Runs release-please as the sole release pull request and tag creator in <Workflow>' -ForEach @(
        @{ Workflow = 'release-prerelease.yml' }
        @{ Workflow = 'release-stable-publish.yml' }
    ) {
        $steps = Get-JobStepText -Document (Get-WorkflowDocument -Name $Workflow) -JobName 'release-please'
        @($steps | Where-Object { $_ -match 'googleapis/release-please-action@' }) | Should -HaveCount 1
    }

    It 'Normalizes versions and syncs the plugin manifest during <Workflow> promotion' -ForEach @(
        @{ Workflow = 'release-prerelease-prepare.yml'; Job = 'prepare-promotion'; Step = 'Refresh the promotion head' }
        @{ Workflow = 'release-stable.yml'; Job = 'prepare-promotion'; Step = 'Refresh the promotion head' }
    ) {
        $run = [string](Get-NamedJobStep -Document (Get-WorkflowDocument -Name $Workflow) -JobName $Job -StepName $Step)['run']
        $run | Should -Match 'scripts/plugins/Sync-PluginManifest\.ps1'
        $run | Should -Match 'scripts/release/Set-RepositoryVersion\.ps1'
        $run | Should -Match '-Version "\$TARGET_VERSION"'
        $run | Should -Match '-RepoRoot "\$PWD"'

        $versionPosition = $run.IndexOf('scripts/release/Set-RepositoryVersion.ps1', [System.StringComparison]::Ordinal)
        $syncPosition = $run.IndexOf('scripts/plugins/Sync-PluginManifest.ps1', [System.StringComparison]::Ordinal)
        $finalCheckPosition = $run.LastIndexOf('scripts/plugins/Sync-PluginManifest.ps1', [System.StringComparison]::Ordinal)
        $versionPosition | Should -BeGreaterThan -1
        $syncPosition | Should -BeGreaterThan $versionPosition
        $finalCheckPosition | Should -BeGreaterThan $syncPosition
        $run.Substring($finalCheckPosition) | Should -Match '-Check'
    }

    It 'Stages only the Stable release-owned files' {
        $run = [string](Get-NamedJobStep -Document (Get-WorkflowDocument -Name 'release-stable.yml') `
                -JobName 'prepare-promotion' -StepName 'Refresh the promotion head')['run']
        $run | Should -Match 'RELEASE_OWNED_FILES=\('
        $run | Should -Match 'git add -- "\$\{RELEASE_OWNED_FILES\[@\]\}"'
        $run | Should -Not -Match 'git add --all'
    }

    It 'Checks out only trusted release tooling from main in <Workflow>' -ForEach @(
        @{ Workflow = 'release-prerelease-prepare.yml' }
        @{ Workflow = 'release-stable.yml' }
    ) {
        $step = Get-NamedJobStep -Document (Get-WorkflowDocument -Name $Workflow) `
            -JobName 'prepare-promotion' -StepName 'Checkout trusted release tooling'
        [string]$step['with']['ref'] | Should -BeExactly 'main'
        $sparse = [string[]]@(([string]$step['with']['sparse-checkout']).Split("`n") |
                ForEach-Object { $_.Trim() } | Where-Object { $_ })
        $sparse | Should -Be @(
            'scripts/release/Resolve-ReleasePromotionVersion.ps1'
            'scripts/release/Set-RepositoryVersion.ps1'
            'scripts/plugins/Sync-PluginManifest.ps1'
        )
    }

    It 'Restores release-owned files without a candidate record in <Workflow>' -ForEach @(
        @{ Workflow = 'release-prerelease-prepare.yml' }
        @{ Workflow = 'release-stable.yml' }
    ) {
        $run = [string](Get-NamedJobStep -Document (Get-WorkflowDocument -Name $Workflow) `
                -JobName 'prepare-promotion' -StepName 'Refresh the promotion head')['run']
        $run | Should -Match "restore_from_base required CHANGELOG\.md \.github/plugin/marketplace\.json"
        $run | Should -Match "'plugin\.json'"
        $run | Should -Not -Match 'release-candidate\.json'
    }

    It 'Syncs the managed release preparation branch through the bounded scripts in <Workflow>' -ForEach @(
        @{ Workflow = 'release-prerelease.yml' }
        @{ Workflow = 'release-stable-publish.yml' }
    ) {
        $document = Get-WorkflowDocument -Name $Workflow
        $step = Get-NamedJobStep -Document $document -JobName 'sync-release-pr' `
            -StepName 'Update committed version fields and retire the promotion intent'
        $run = [string]$step['run']
        $run | Should -Match 'scripts/plugins/Sync-PluginManifest\.ps1'
        $run | Should -Match 'scripts/release/Set-RepositoryVersion\.ps1'
        $run | Should -Match "del\(\.packages\[\`"\.\`"\]\[\`"release-as\`"\]\)"
        $run | Should -Not -Match 'release-candidate\.json'

        $checkout = Get-NamedJobStep -Document $document -JobName 'sync-release-pr' -StepName 'Checkout trusted release updater'
        $sparse = [string[]]@(([string]$checkout['with']['sparse-checkout']).Split("`n") |
                ForEach-Object { $_.Trim() } | Where-Object { $_ })
        $sparse | Should -Be @(
            'scripts/release/Set-RepositoryVersion.ps1'
            'scripts/plugins/Sync-PluginManifest.ps1'
        )
    }

    It 'Retains the PreRelease promotion, branch, and release-as gates in pr-validation.yml' {
        $steps = Get-JobStepText -Document (Get-WorkflowDocument -Name 'pr-validation.yml') -JobName 'gate-completeness-check'
        @($steps | Where-Object { $_ -match 'is not the canonical promotion head' }) | Should -HaveCount 1
        @($steps | Where-Object { $_ -match 'PreRelease candidate \$CANDIDATE has an even minor' }) | Should -HaveCount 1
        @($steps | Where-Object { $_ -match 'Stable candidate \$CANDIDATE has an odd minor' }) | Should -HaveCount 1
        @($steps | Where-Object { $_ -match 'the PreRelease release identity is occupied' }) | Should -HaveCount 1
    }

    It 'Publishes the release only after provenance verification in <Workflow>' -ForEach @(
        @{ Workflow = 'release-prerelease.yml' }
        @{ Workflow = 'release-stable-publish.yml' }
    ) {
        $document = Get-WorkflowDocument -Name $Workflow
        [string[]]@($document['jobs']['publish-release']['needs']) | Should -Contain 'verify-provenance'
        $steps = Get-JobStepText -Document $document -JobName 'publish-release'
        @($steps | Where-Object { $_ -match 'gh release edit .*--draft=false' }) | Should -HaveCount 1
    }
}
