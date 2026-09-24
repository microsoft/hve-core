#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $script:WorkflowPath = Join-Path $script:RepositoryRoot '.github/workflows/dependency-review.yml'
    $script:Workflow = Get-Content -LiteralPath $script:WorkflowPath -Raw -Encoding utf8 |
        ConvertFrom-Yaml

    function Get-WorkflowStep {
        <#
        .SYNOPSIS
        Returns one named step from a workflow job.
        .PARAMETER JobName
        Workflow job identifier.
        .PARAMETER StepName
        Exact step display name.
        .OUTPUTS
        [System.Collections.IDictionary] Matching workflow step.
        #>
        [CmdletBinding()]
        [OutputType([System.Collections.IDictionary])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$JobName,

            [Parameter(Mandatory = $true)]
            [string]$StepName
        )

        $Steps = @($script:Workflow['jobs'][$JobName]['steps'] |
                Where-Object { [string]$_['name'] -eq $StepName })
        if ($Steps.Count -ne 1) {
            throw "Job '$JobName' must declare exactly one step named '$StepName' but declared $($Steps.Count)"
        }
        return $Steps[0]
    }

    function Get-WorkflowStepText {
        <#
        .SYNOPSIS
        Returns the uses and run text for every workflow step.
        .OUTPUTS
        [string] Combined workflow step text.
        #>
        [CmdletBinding()]
        [OutputType([string])]
        param()

        return (@($script:Workflow['jobs'].Values['steps'] | ForEach-Object {
                    $Uses = if ($_.Contains('uses')) { [string]$_['uses'] } else { '' }
                    $Run = if ($_.Contains('run')) { [string]$_['run'] } else { '' }
                    "$Uses`n$Run"
                }) -join "`n")
    }
}

Describe 'Dependency Review workflow contract' -Tag 'Unit' {
    It 'Preserves the supported triggers and dependency manifest paths' {
        $Triggers = $script:Workflow['on']
        [string[]]@($Triggers['push']['branches']) | Should -Be @('main', 'develop')
        [string[]]@($Triggers['pull_request']['branches']) | Should -Be @('main', 'develop')
        [string[]]@($Triggers['pull_request']['paths']) | Should -Be @(
            '**/package.json'
            '**/package-lock.json'
            '**/pyproject.toml'
            '**/uv.lock'
            '**/requirements*.txt'
            '.github/workflows/dependency-review.yml'
        )
        $Triggers.Contains('workflow_call') | Should -BeTrue
    }

    It 'Separates dependency submission from pull request review' {
        [string[]]@($script:Workflow['jobs'].Keys | Sort-Object) |
            Should -Be @('dependency-review', 'dependency-submission', 'main-sbom')
        [string[]]@($script:Workflow['jobs']['dependency-review']['needs']) |
            Should -Be @('dependency-submission')
    }

    It 'Publishes an unattested commit-specific SBOM for main pushes' {
        $Job = $script:Workflow['jobs']['main-sbom']
        [string[]]@($Job['permissions'].Keys) | Should -Be @('contents')
        [string]$Job['permissions']['contents'] | Should -BeExactly 'read'
        [string]$Job['if'] | Should -Match "github\.event_name == 'push'"
        [string]$Job['if'] | Should -Match "github\.ref == 'refs/heads/main'"

        $Checkout = Get-WorkflowStep -JobName 'main-sbom' -StepName 'Checkout code'
        [string]$Checkout['uses'] | Should -Match '^actions/checkout@[0-9a-f]{40}$'
        [bool]$Checkout['with']['persist-credentials'] | Should -BeFalse

        $Generation = Get-WorkflowStep -JobName 'main-sbom' -StepName 'Generate main dependency SBOM'
        [string]$Generation['uses'] | Should -Match '^anchore/sbom-action@[0-9a-f]{40}$'
        [string]$Generation['with']['path'] | Should -BeExactly '.'
        [string]$Generation['with']['format'] | Should -BeExactly 'spdx-json'
        [string]$Generation['with']['output-file'] |
            Should -BeExactly 'continuous-sbom/main-dependencies-${{ github.sha }}.spdx.json'
        [bool]$Generation['with']['upload-artifact'] | Should -BeFalse
        [bool]$Generation['with']['upload-release-assets'] | Should -BeFalse
        [string]$Generation['with']['config'] | Should -BeExactly '.syft.yaml'

        $Upload = Get-WorkflowStep -JobName 'main-sbom' -StepName 'Upload main dependency SBOM'
        [string]$Upload['id'] | Should -BeExactly 'upload-main-sbom'
        [string]$Upload['uses'] | Should -Match '^actions/upload-artifact@[0-9a-f]{40}$'
        [string]$Upload['with']['name'] | Should -BeExactly 'main-dependencies-${{ github.sha }}'
        [string]$Upload['with']['path'] |
            Should -BeExactly 'continuous-sbom/main-dependencies-${{ github.sha }}.spdx.json'
        [string]$Upload['with']['if-no-files-found'] | Should -BeExactly 'error'
        [int]$Upload['with']['retention-days'] | Should -Be 30

        $Summary = Get-WorkflowStep -JobName 'main-sbom' -StepName 'Add SBOM download summary'
        [string]$Summary['env']['ARTIFACT_URL'] |
            Should -BeExactly '${{ steps.upload-main-sbom.outputs.artifact-url }}'
        [string]$Summary['env']['ARTIFACT_DIGEST'] |
            Should -BeExactly '${{ steps.upload-main-sbom.outputs.artifact-digest }}'
        [string]$Summary['env']['SOURCE_SHA'] | Should -BeExactly '${{ github.sha }}'
        [string]$Summary['run'] | Should -Match 'GITHUB_STEP_SUMMARY'
        [string]$Summary['run'] | Should -Match 'unattested continuous evidence'
        [string]$Summary['run'] | Should -Match '30 days'
    }

    It 'Uses least privilege for dependency submission' {
        $Job = $script:Workflow['jobs']['dependency-submission']
        [string[]]@($Job['permissions'].Keys) | Should -Be @('contents')
        [string]$Job['permissions']['contents'] | Should -BeExactly 'write'
        [string]$Job['if'] | Should -Match "github\.event_name == 'push'"
        [string]$Job['if'] | Should -Match "github\.event_name == 'pull_request'"
        [string]$Job['if'] | Should -Match 'head\.repo\.full_name == github\.repository'

        $Checkout = Get-WorkflowStep -JobName 'dependency-submission' -StepName 'Checkout code'
        [string]$Checkout['uses'] | Should -Match '^actions/checkout@[0-9a-f]{40}$'
        [bool]$Checkout['with']['persist-credentials'] | Should -BeFalse

        $Submission = Get-WorkflowStep -JobName 'dependency-submission' -StepName 'Submit uv.lock dependencies'
        [string]$Submission['uses'] |
            Should -Match '^advanced-security/component-detection-dependency-submission-action@[0-9a-f]{40}$'
        [string]$Submission['with']['detectorArgs'] | Should -BeExactly 'UvLock=EnableIfDefaultOff'
    }

    It 'Uses least privilege and dependency-aware conditions for pull request review' {
        $Job = $script:Workflow['jobs']['dependency-review']
        [string[]]@($Job['permissions'].Keys | Sort-Object) |
            Should -Be @('contents', 'pull-requests')
        [string]$Job['permissions']['contents'] | Should -BeExactly 'read'
        [string]$Job['permissions']['pull-requests'] | Should -BeExactly 'write'
        [string]$Job['if'] | Should -Match 'always\(\)'
        [string]$Job['if'] | Should -Match "github\.event_name == 'pull_request'"
        [string]$Job['if'] | Should -Match "needs\.dependency-submission\.result == 'success'"
        [string]$Job['if'] | Should -Match "needs\.dependency-submission\.result == 'skipped'"
        [string]$Job['if'] | Should -Not -Match "result == 'failure'"

        $Checkout = Get-WorkflowStep -JobName 'dependency-review' -StepName 'Checkout code'
        [string]$Checkout['uses'] | Should -Match '^actions/checkout@[0-9a-f]{40}$'
        [bool]$Checkout['with']['persist-credentials'] | Should -BeFalse

        $Review = Get-WorkflowStep -JobName 'dependency-review' -StepName 'Dependency Review'
        [string]$Review['uses'] | Should -Match '^actions/dependency-review-action@[0-9a-f]{40}$'
        [bool]$Review['with']['retry-on-snapshot-warnings'] | Should -BeTrue
        [int]$Review['with']['retry-on-snapshot-warnings-timeout'] | Should -Be 120
        [string]$Review['with']['fail-on-severity'] | Should -BeExactly 'moderate'
        [string]$Review['with']['comment-summary-in-pr'] | Should -BeExactly 'always'
        [bool]$Review['with']['license-check'] | Should -BeTrue
        [string]$Review['with']['allow-ghsas'] | Should -Match 'GHSA-69w3-r845-3855'
    }

    It 'Keeps continuous dependency evidence outside release and attestation paths' {
        [string[]]@($script:Workflow['permissions'].Keys) | Should -Be @('contents')
        [string]$script:Workflow['permissions']['contents'] | Should -BeExactly 'read'

        foreach ($Job in @($script:Workflow['jobs'].Values)) {
            [string[]]$Permission = @($Job['permissions'].Keys)
            $Permission | Should -Not -Contain 'id-token'
            $Permission | Should -Not -Contain 'attestations'
            $Permission | Should -Not -Contain 'artifact-metadata'
            $Permission | Should -Not -Contain 'packages'
            $Permission | Should -Not -Contain 'security-events'
        }

        Get-WorkflowStepText |
            Should -Not -Match 'actions/attest|gh release (upload|edit)'
    }
}
