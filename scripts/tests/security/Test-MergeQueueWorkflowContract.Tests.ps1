#Requires -Modules Pester, powershell-yaml
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeDiscovery {
    $TrustedCheckoutSites = @(
        @{ Workflow = 'adr-consistency-validation.yml'; Job = 'detect-changes' }
        @{ Workflow = 'adr-consistency-validation.yml'; Job = 'validate' }
        @{ Workflow = 'asset-docs-validation.yml'; Job = 'validate' }
        @{ Workflow = 'docusaurus-tests.yml'; Job = 'detect-changes' }
        @{ Workflow = 'docusaurus-tests.yml'; Job = 'docusaurus' }
        @{ Workflow = 'eval-validation.yml'; Job = 'content-moderation' }
        @{ Workflow = 'eval-validation.yml'; Job = 'eval-validation' }
        @{ Workflow = 'frontmatter-validation.yml'; Job = 'frontmatter-validation' }
        @{ Workflow = 'fuzz-tests.yml'; Job = 'fuzz' }
        @{ Workflow = 'gitleaks-scan.yml'; Job = 'scan' }
        @{ Workflow = 'markdown-link-check.yml'; Job = 'markdown-link-check' }
        @{ Workflow = 'msdate-freshness-check.yml'; Job = 'msdate-freshness' }
        @{ Workflow = 'node-tests.yml'; Job = 'node-tests' }
        @{ Workflow = 'pip-audit.yml'; Job = 'pip-audit' }
        @{ Workflow = 'ps-script-analyzer.yml'; Job = 'psscriptanalyzer' }
        @{ Workflow = 'pytest-tests.yml'; Job = 'pytest' }
        @{ Workflow = 'python-lint.yml'; Job = 'python-lint' }
        @{ Workflow = 'skill-validation.yml'; Job = 'validate' }
        @{ Workflow = 'yaml-lint.yml'; Job = 'yaml-lint' }
    )
}

BeforeAll {
Import-Module powershell-yaml -ErrorAction Stop

function Get-WorkflowRangeContractViolation {
    <#
    .SYNOPSIS
        Finds selector jobs that bypass immutable resolver outputs.
    .PARAMETER WorkflowPath
        Workflow YAML file to inspect.
    .PARAMETER SelectorJobId
        Aggregate-owned changed-file job IDs that require the shared contract.
    .OUTPUTS
        [string[]] containing workflow contract violations.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkflowPath,

        [Parameter(Mandatory = $true)]
        [string[]]$SelectorJobId
    )

    $Workflow = Get-Content -Raw -Path $WorkflowPath | ConvertFrom-Yaml
    $Violations = [System.Collections.Generic.List[string]]::new()
    $RequiredReferences = @(
        'needs.change-range.outputs.mode'
        'needs.change-range.outputs.base-sha'
        'needs.change-range.outputs.head-sha'
    )
    $MovingRefPattern = 'github\.base_ref|github\.event\.pull_request\.base\.ref|origin/|HEAD\^'

    foreach ($JobId in $SelectorJobId) {
        $Job = if ($Workflow.jobs -is [System.Collections.IDictionary]) {
            $Workflow.jobs[$JobId]
        }
        else {
            $Workflow.jobs.PSObject.Properties[$JobId].Value
        }

        if ($null -eq $Job) {
            $Violations.Add("missing-selector-job:$JobId")
            continue
        }

        $JobJson = $Job | ConvertTo-Json -Depth 20 -Compress
        foreach ($RequiredReference in $RequiredReferences) {
            if ($JobJson -notmatch [regex]::Escape($RequiredReference)) {
                $Violations.Add("missing-range-contract:${JobId}:$RequiredReference")
            }
        }

        if ($JobJson -match $MovingRefPattern) {
            $Violations.Add("moving-ref-fallback:$JobId")
        }
    }

    return $Violations.ToArray()
}

function Get-CheckoutTrustViolation {
    <#
    .SYNOPSIS
        Finds checkout steps whose ref is derived from caller inputs.
    .PARAMETER WorkflowPath
        Workflow YAML file to inspect.
    .OUTPUTS
        [string[]] containing input-derived checkout violations.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkflowPath
    )

    $Workflow = Get-Content -Raw -Path $WorkflowPath | ConvertFrom-Yaml
    $Violations = [System.Collections.Generic.List[string]]::new()
    if ($null -eq $Workflow -or -not $Workflow.Contains('jobs')) {
        return $Violations.ToArray()
    }

    foreach ($Job in $Workflow['jobs'].GetEnumerator()) {
        foreach ($Step in @($Job.Value['steps'])) {
            if ($null -eq $Step -or [string]$Step['uses'] -notlike 'actions/checkout@*' -or $null -eq $Step['with']) {
                continue
            }

            if ([string]$Step['with']['ref'] -match '(?<![\w.-])inputs\.') {
                $Violations.Add("input-derived-checkout:$($Job.Key)")
            }
        }
    }

    return $Violations.ToArray()
}

    $script:WorkflowRoot = Join-Path $PSScriptRoot '../../../.github/workflows'
    $script:AggregateWorkflowPath = Join-Path $PSScriptRoot '../../../.github/workflows/pr-validation.yml'
    $script:AggregateWorkflow = Get-Content -Raw -Path $script:AggregateWorkflowPath | ConvertFrom-Yaml
}

Describe 'Trusted checkout contract' -Tag 'Unit' {
    It 'Reports a checkout ref derived from caller inputs, including compound expressions' {
        $WorkflowPath = Join-Path $TestDrive 'input-derived-checkout.yml'
        @'
jobs:
    selector:
        runs-on: ubuntu-latest
        steps:
            - uses: actions/checkout@0000000000000000000000000000000000000000
              with:
                  ref: ${{ inputs.change-mode == 'range' && inputs.head-sha || github.sha }}
'@ | Set-Content -Path $WorkflowPath -Encoding utf8NoBOM

        Get-CheckoutTrustViolation -WorkflowPath $WorkflowPath | Should -Contain 'input-derived-checkout:selector'
    }

    It 'Never derives a checkout ref from caller inputs in any workflow' {
        $Violations = foreach ($WorkflowFile in Get-ChildItem -Path $script:WorkflowRoot -Filter '*.yml') {
            Get-CheckoutTrustViolation -WorkflowPath $WorkflowFile.FullName | ForEach-Object { "$($WorkflowFile.Name):$_" }
        }

        $Violations | Should -BeNullOrEmpty
    }

    It 'Checks out the event commit and verifies the resolved head before other steps in <Workflow> job <Job>' -ForEach $TrustedCheckoutSites {
        $Document = Get-Content -Raw -Path (Join-Path $script:WorkflowRoot $Workflow) | ConvertFrom-Yaml
        $Steps = @($Document['jobs'][$Job]['steps'])
        $CheckoutIndex = [array]::FindIndex($Steps, [Predicate[object]] { param($Step) [string]$Step['uses'] -like 'actions/checkout@*' })
        $CheckoutStep = $Steps[$CheckoutIndex]
        $VerifyStep = $Steps[$CheckoutIndex + 1]

        $CheckoutStep['with']['ref'] | Should -BeExactly '${{ github.sha }}'
        $CheckoutStep['with']['persist-credentials'] | Should -BeFalse
        $VerifyStep['if'] | Should -BeExactly "inputs.change-mode == 'range'"
        $VerifyStep['env']['EXPECTED_HEAD_SHA'] | Should -BeExactly '${{ inputs.head-sha }}'
        $VerifyStep.Contains('uses') | Should -BeFalse
        [string]$VerifyStep['run'] | Should -Match 'git rev-parse HEAD'
        [string]$VerifyStep['run'] | Should -Match 'exit 1'
        [string]$VerifyStep['run'] | Should -Not -Match '\$\{\{'
    }
}

Describe 'Aggregate changed-file workflow contract' -Tag 'Unit' {
        It 'Reports a selector job that bypasses the shared range contract' {
                $WorkflowPath = Join-Path $TestDrive 'bypassed-contract.yml'
                @'
jobs:
    selector:
        runs-on: ubuntu-latest
        steps:
            - run: git diff --name-only base..head
'@ | Set-Content -Path $WorkflowPath -Encoding utf8NoBOM

                $Violations = Get-WorkflowRangeContractViolation -WorkflowPath $WorkflowPath -SelectorJobId 'selector'

                $Violations | Should -Contain 'missing-range-contract:selector:needs.change-range.outputs.mode'
                $Violations | Should -Contain 'missing-range-contract:selector:needs.change-range.outputs.base-sha'
                $Violations | Should -Contain 'missing-range-contract:selector:needs.change-range.outputs.head-sha'
        }

        It 'Reports a selector job that reintroduces a moving-ref fallback' {
                $WorkflowPath = Join-Path $TestDrive 'moving-ref-fallback.yml'
                @'
jobs:
    selector:
        needs: change-range
        runs-on: ubuntu-latest
        env:
            MODE: ${{ needs.change-range.outputs.mode }}
            BASE_SHA: ${{ needs.change-range.outputs.base-sha }}
            HEAD_SHA: ${{ needs.change-range.outputs.head-sha }}
        steps:
            - run: git diff --name-only origin/main..HEAD
'@ | Set-Content -Path $WorkflowPath -Encoding utf8NoBOM

                $Violations = Get-WorkflowRangeContractViolation -WorkflowPath $WorkflowPath -SelectorJobId 'selector'

                $Violations | Should -Contain 'moving-ref-fallback:selector'
        }

            It 'Routes every inline selector caller through the aggregate range contract' {
                $SelectorJobIds = @(
                    'python-lint'
                    'pytest'
                    'copilot-otel-runtime-tests'
                    'node-tests'
                    'fuzz-tests'
                    'pip-audit'
                    'docusaurus-tests'
                    'adr-consistency-validation'
                )

                $Violations = Get-WorkflowRangeContractViolation -WorkflowPath $script:AggregateWorkflowPath -SelectorJobId $SelectorJobIds

                $Violations | Should -BeNullOrEmpty
            }

            It 'Defines full-or-range inputs without moving-ref fallbacks in every inline selector' {
                $WorkflowNames = @(
                    'python-lint.yml'
                    'pytest-tests.yml'
                    'node-tests.yml'
                    'fuzz-tests.yml'
                    'pip-audit.yml'
                    'docusaurus-tests.yml'
                    'adr-consistency-validation.yml'
                )

                foreach ($WorkflowName in $WorkflowNames) {
                    $WorkflowPath = Join-Path $PSScriptRoot "../../../.github/workflows/$WorkflowName"
                    $WorkflowText = Get-Content -Raw -Path $WorkflowPath
                    $Workflow = $WorkflowText | ConvertFrom-Yaml
                    $Inputs = $Workflow['on']['workflow_call']['inputs']

                    $Inputs['change-mode']['default'] | Should -BeExactly 'full'
                    $Inputs.Contains('base-sha') | Should -BeTrue
                    $Inputs.Contains('head-sha') | Should -BeTrue
                    $WorkflowText | Should -Match 'inputs\.base-sha'
                    $WorkflowText | Should -Not -Match 'github\.base_ref|github\.event\.before|origin/main|origin/\$'
                }
            }

            It 'Routes every script-backed selector caller through the aggregate range contract' {
                $SelectorJobIds = @(
                    'psscriptanalyzer'
                    'yaml-lint'
                    'frontmatter-validation'
                    'asset-docs-validation'
                    'msdate-freshness'
                    'skill-validation'
                    'markdown-link-check'
                )

                $Violations = Get-WorkflowRangeContractViolation -WorkflowPath $script:AggregateWorkflowPath -SelectorJobId $SelectorJobIds

                $Violations | Should -BeNullOrEmpty
            }

            It 'Defines full-or-range inputs without moving-ref fallbacks in every script-backed selector' {
                $WorkflowNames = @(
                    'ps-script-analyzer.yml'
                    'yaml-lint.yml'
                    'frontmatter-validation.yml'
                    'asset-docs-validation.yml'
                    'msdate-freshness-check.yml'
                    'skill-validation.yml'
                    'markdown-link-check.yml'
                )

                foreach ($WorkflowName in $WorkflowNames) {
                    $WorkflowPath = Join-Path $PSScriptRoot "../../../.github/workflows/$WorkflowName"
                    $WorkflowText = Get-Content -Raw -Path $WorkflowPath
                    $Workflow = $WorkflowText | ConvertFrom-Yaml
                    $Inputs = $Workflow['on']['workflow_call']['inputs']

                    $Inputs['change-mode']['default'] | Should -BeExactly 'full'
                    $Inputs.Contains('base-sha') | Should -BeTrue
                    $Inputs.Contains('head-sha') | Should -BeTrue
                    $WorkflowText | Should -Match 'inputs\.base-sha'
                    $WorkflowText | Should -Not -Match 'inputs\.base-branch|github\.base_ref|github\.event\.before|origin/main|origin/\$'
                }
            }

            It 'Preserves repository-wide internal markdown-link validation' {
                $WorkflowPath = Join-Path $PSScriptRoot '../../../.github/workflows/markdown-link-check.yml'
                $WorkflowText = Get-Content -Raw -Path $WorkflowPath

                $WorkflowText | Should -Match 'internal links are always validated repository-wide'
        $WorkflowText | Should -Match '\$params\[''ChangedFilesOnly''\] = \$true'
        $WorkflowText | Should -Match '\$params\[''BaseBranch''\] = \$env:INPUT_BASE_SHA'
            }

    It 'Routes eval and gitleaks callers through the aggregate range contract' {
        $Violations = Get-WorkflowRangeContractViolation -WorkflowPath $script:AggregateWorkflowPath -SelectorJobId @('eval-validation', 'gitleaks-scan')

        $Violations | Should -BeNullOrEmpty
    }

    It 'Withholds the custom eval token from merge groups at the caller boundary' {
        $EvalCaller = $script:AggregateWorkflow['jobs']['eval-validation']
        $SecretExpression = $EvalCaller['secrets']['copilot-github-token']

        $SecretExpression | Should -Match "github\.event_name != 'merge_group'"
        $SecretExpression | Should -Match "\|\| ''"
    }

    It 'Bypasses the eval range artifact and forces unprivileged linting in full mode' {
        $WorkflowPath = Join-Path $PSScriptRoot '../../../.github/workflows/eval-validation.yml'
        $Workflow = Get-Content -Raw -Path $WorkflowPath | ConvertFrom-Yaml
        $EvalSteps = @($Workflow['jobs']['eval-validation']['steps'])
        $GenerateStep = $EvalSteps | Where-Object { $_['name'] -eq 'Generate immutable eval change set' }
        $UploadStep = $EvalSteps | Where-Object { $_['name'] -eq 'Upload immutable eval change set' }
        $DetectStep = $EvalSteps | Where-Object { $_['name'] -eq 'Detect eval-relevant changes' }

        $GenerateStep['if'] | Should -BeExactly "inputs.change-mode == 'range'"
        $UploadStep['if'] | Should -BeExactly "inputs.change-mode == 'range'"
        $DetectStep['run'] | Should -Match "INPUT_CHANGE_MODE -eq 'full'"
        $DetectStep['run'] | Should -Match '\$relevant = \$true'
        $Workflow['jobs']['content-moderation']['if'] | Should -BeExactly "inputs.change-mode == 'range'"
    }

    It 'Keeps every custom-token eval job outside merge-group execution' {
        $WorkflowPath = Join-Path $PSScriptRoot '../../../.github/workflows/eval-validation.yml'
        $Workflow = Get-Content -Raw -Path $WorkflowPath | ConvertFrom-Yaml

        foreach ($JobProperty in $Workflow['jobs'].GetEnumerator()) {
            $JobJson = $JobProperty.Value | ConvertTo-Json -Depth 30 -Compress
            if ($JobJson -match 'COPILOT_GITHUB_TOKEN') {
                $JobCondition = [string]$JobProperty.Value['if']
                $JobCondition | Should -Match "github\.event_name == 'pull_request'"
                $JobCondition | Should -Match "github\.event_name == 'workflow_dispatch'"
                $JobCondition | Should -Not -Match 'merge_group'
            }
        }
    }

    It 'Scopes gitleaks to exact SHAs in range mode and omits log options in full mode' {
        $WorkflowPath = Join-Path $PSScriptRoot '../../../.github/workflows/gitleaks-scan.yml'
        $WorkflowText = Get-Content -Raw -Path $WorkflowPath
        $Workflow = $WorkflowText | ConvertFrom-Yaml
        $ScanStep = @($Workflow['jobs']['scan']['steps']) | Where-Object { $_['id'] -eq 'gitleaks' }
        $Inputs = $Workflow['on']['workflow_call']['inputs']

        $Inputs['change-mode']['default'] | Should -BeExactly 'full'
        $Inputs.Contains('log-opts') | Should -BeFalse
        $ScanStep['run'] | Should -Match '\$\{INPUT_BASE_SHA\}\.\.\$\{INPUT_HEAD_SHA\}'
        $ScanStep['run'] | Should -Match "INPUT_CHANGE_MODE.*= 'full'"
        $WorkflowText | Should -Not -Match 'github\.event\.pull_request'
    }
}

    Describe 'Aggregate merge-group ownership' -Tag 'Unit' {
        It 'Subscribes to checks requested for merge groups targeting main' {
            $MergeGroupTrigger = $script:AggregateWorkflow['on']['merge_group']

            @($MergeGroupTrigger['types']) | Should -Contain 'checks_requested'
            @($MergeGroupTrigger['branches']) | Should -Contain 'main'
        }

        It 'Uses event-safe concurrency without pull-request-only fields' {
            $ConcurrencyGroup = $script:AggregateWorkflow['concurrency']['group']

            $ConcurrencyGroup | Should -BeExactly '${{ github.workflow }}-${{ github.ref }}'
            $ConcurrencyGroup | Should -Not -Match 'pull_request'
        }

        It 'Exposes one resolver-owned immutable range decision' {
            $RangeJob = $script:AggregateWorkflow['jobs']['change-range']
            $ResolveStep = @($RangeJob['steps']) | Where-Object { $_['id'] -eq 'resolve' }
            $CheckoutStep = @($RangeJob['steps']) | Where-Object { $_['uses'] -like 'actions/checkout@*' }

            $RangeJob['outputs']['mode'] | Should -BeExactly '${{ steps.resolve.outputs.mode }}'
            $RangeJob['outputs']['base-sha'] | Should -BeExactly '${{ steps.resolve.outputs.base-sha }}'
            $RangeJob['outputs']['head-sha'] | Should -BeExactly '${{ steps.resolve.outputs.head-sha }}'
                $CheckoutStep['with']['ref'] | Should -BeExactly '${{ github.sha }}'
            $ResolveStep['env']['EVENT_NAME'] | Should -BeExactly '${{ github.event_name }}'
            $ResolveStep['env']['BASE_SHA'] | Should -Match "event_name == 'merge_group'.*merge_group\.base_sha"
            $ResolveStep['env']['BASE_SHA'] | Should -Not -Match 'pull_request\.base'
            $ResolveStep['env']['HEAD_SHA'] | Should -Match "event_name == 'merge_group'.*merge_group\.head_sha.*\|\| github\.sha"
            $ResolveStep['env']['PR_HEAD_SHA'] | Should -Match "event_name == 'pull_request'.*pull_request\.head\.sha"
            $ResolveStep['env']['DEFAULT_BRANCH'] | Should -BeExactly '${{ github.event.repository.default_branch }}'
            $ResolveStep['run'] | Should -Match 'scripts/ci/Resolve-WorkflowChangeRange\.ps1'
            $ResolveStep['run'] | Should -Not -Match '\$\{\{'
        }

        It 'Keeps the resolver in the stable aggregate gate' {
            @($script:AggregateWorkflow['jobs']['pr-validation-success']['needs']) | Should -Contain 'change-range'
        }

        It 'Keeps release-promotion checks limited to pull requests' {
            $GateSteps = @($script:AggregateWorkflow['jobs']['gate-completeness-check']['steps'])
            $PromotionSteps = @($GateSteps | Where-Object { $_['name'] -like 'Validate * promotion intent*' })

            $PromotionSteps | Should -HaveCount 2
            foreach ($PromotionStep in $PromotionSteps) {
                $PromotionStep['if'] | Should -Match "github\.event_name == 'pull_request'"
            }
        }
    }
