#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $script:SignerPath = Join-Path $script:RepositoryRoot '.github/workflows/extension-provenance-signer.yml'
    $script:SignerText = Get-Content -LiteralPath $script:SignerPath -Raw -Encoding utf8
    $script:Signer = $script:SignerText | ConvertFrom-Yaml

    function Get-SignerStepText {
        <#
        .SYNOPSIS
            Returns the uses and run text declared by a signer job.
        .PARAMETER JobName
            Signer job identifier.
        .OUTPUTS
            [string] Combined step text.
        #>
        [CmdletBinding()]
        [OutputType([string])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$JobName
        )

        return (@($script:Signer['jobs'][$JobName]['steps'] | ForEach-Object {
                    $uses = if ($_.Contains('uses')) { [string]$_['uses'] } else { '' }
                    $run = if ($_.Contains('run')) { [string]$_['run'] } else { '' }
                    "$uses`n$run"
                }) -join "`n")
    }
}

Describe 'Dormant extension provenance signer' -Tag 'Unit' {
    It 'Declares the immutable authorization, package, and attestation graph' {
        [string[]]@($script:Signer['jobs'].Keys | Sort-Object) |
            Should -Be @('attest', 'authorize', 'package')
        [string[]]@($script:Signer['jobs']['package']['needs']) | Should -Be @('authorize')
        [string[]]@($script:Signer['jobs']['attest']['needs']) | Should -Be @('authorize', 'package')
    }

    It 'Is dormant until a later caller references it' {
        $callers = @(Get-ChildItem -LiteralPath (Join-Path $script:RepositoryRoot '.github/workflows') -Filter '*.yml' |
                Where-Object { $_.FullName -ne $script:SignerPath } |
                Select-String -SimpleMatch 'extension-provenance-signer.yml')
        $callers | Should -BeNullOrEmpty
    }

    It 'Limits the scanner acknowledgment to the read-only package job' {
        $config = Get-Content -LiteralPath (Join-Path $script:RepositoryRoot '.poutine.yml') -Raw -Encoding utf8 |
            ConvertFrom-Yaml
        $exceptions = @($config['skip'] | Where-Object {
                @($_['rule']) -contains 'untrusted_checkout_exec' -and
                @($_['path']) -contains '.github/workflows/extension-provenance-signer.yml'
            })
        $exceptions | Should -HaveCount 1
        @($exceptions[0].Keys | Sort-Object) | Should -Be @('job', 'path', 'rule')
        [string[]]@($exceptions[0]['job']) | Should -Be @('package')
    }

    It 'Isolates the governance credential to checkout-free authorization' {
        [string]$script:Signer['jobs']['authorize']['environment'] | Should -BeExactly 'release-governance'
        [string]$script:Signer['jobs']['authorize']['permissions']['contents'] | Should -BeExactly 'read'
        $token = @($script:Signer['jobs']['authorize']['steps'] |
            Where-Object { [string]$_['name'] -eq 'Generate governance-read Release App token' })[0]
        [string]$token['with']['permission-administration'] | Should -BeExactly 'read'
        [string]$token['with']['private-key'] | Should -BeExactly '${{ secrets.RELEASE_APP_PRIVATE_KEY }}'
        $authorizeText = Get-SignerStepText -JobName 'authorize'
        $authorizeText | Should -Not -Match 'actions/checkout@|npm ci|Package-Extension\.ps1|gh release (upload|edit)'

        foreach ($job in @('package', 'attest')) {
            (Get-SignerStepText -JobName $job) |
                Should -Not -Match 'RELEASE_APP_PRIVATE_KEY|app-token\.outputs\.token'
        }
    }

    It 'Validates actor, draft, channel containment, and exact governance before checkout' {
        $authorizeText = Get-SignerStepText -JobName 'authorize'
        foreach ($contract in @(
                'hve-core-release-please\[bot\]'
                '254602402'
                'Exact draft release identity'
                'compare/\$EVENT_SHA\.\.\.\$BRANCH_SHA'
                'release-tags-creation-by-release-app'
                'release-tags-immutable'
                'bypass_actors'
                'actor_type == "Integration"'
                'actor_id == 2646666'
                'bypass_mode == "always"'
                'and \.bypass_actors == \[\]')) {
            $authorizeText | Should -Match $contract
        }
    }

    It 'Executes release source only in the read-only package job' {
        [string]$script:Signer['jobs']['package']['permissions']['contents'] | Should -BeExactly 'read'
        $packageText = Get-SignerStepText -JobName 'package'
        $packageText | Should -Match 'actions/checkout@'
        $packageText | Should -Match 'npm ci --ignore-scripts=false'
        $packageText | Should -Match 'Package-Extension\.ps1'
        $packageText | Should -Match 'Generate dependency SBOM|anchore/sbom-action@'

        foreach ($job in @('authorize', 'attest')) {
            (Get-SignerStepText -JobName $job) |
                Should -Not -Match 'actions/checkout@|npm ci|Package-Extension\.ps1|Prepare-Extension\.ps1|\.\/\.github\/actions\/'
        }
    }

    It 'Binds the event-default checkout to the authorized source before execution' {
        $packageSteps = @($script:Signer['jobs']['package']['steps'])
        $checkout = @($packageSteps | Where-Object { [string]$_['name'] -eq 'Checkout code' })[0]
        $checkout['with'].Contains('ref') | Should -BeFalse
        [bool]$checkout['with']['persist-credentials'] | Should -BeFalse

        $stepNames = [string[]]@($packageSteps | ForEach-Object { [string]$_['name'] })
        $checkoutIndex = [Array]::IndexOf($stepNames, 'Checkout code')
        $verifyIndex = [Array]::IndexOf($stepNames, 'Verify checked-out source')
        $verifyIndex | Should -Be ($checkoutIndex + 1)

        $verify = $packageSteps[$verifyIndex]
        [string]$verify['env']['EXPECTED_SOURCE'] | Should -BeExactly '${{ github.sha }}'
        [string]$verify['run'] | Should -Match 'git rev-parse HEAD'
        [string]$verify['run'] | Should -Match 'CHECKED_OUT_SOURCE.*EXPECTED_SOURCE'
    }

    It 'Keeps privileged attestation checkout-free and release-write-free' {
        $permissions = $script:Signer['jobs']['attest']['permissions']
        [string[]]@($permissions.Keys | Sort-Object) |
            Should -Be @('artifact-metadata', 'attestations', 'contents', 'id-token')
        [string]$permissions['contents'] | Should -BeExactly 'read'
        [string]$permissions['id-token'] | Should -BeExactly 'write'
        [string]$permissions['attestations'] | Should -BeExactly 'write'
        [string]$permissions['artifact-metadata'] | Should -BeExactly 'write'

        $attestText = Get-SignerStepText -JobName 'attest'
        $attestText | Should -Not -Match 'gh release (upload|edit)|actions/checkout@|\.\/scripts\/'
        @([regex]::Matches($attestText, 'actions/attest-build-provenance@')) | Should -HaveCount 1
        @([regex]::Matches($attestText, 'actions/attest@')) | Should -HaveCount 2
    }

    It 'Closes the attestation input and output file sets' {
        $packageText = Get-SignerStepText -JobName 'package'
        $attestText = Get-SignerStepText -JobName 'attest'
        $packageText | Should -Match 'dependencies\.spdx\.json'
        $packageText | Should -Match 'manifest\.json'
        $attestText | Should -Match 'EXPECTED_FILES='
        $attestText | Should -Match 'Untrusted package manifest does not match frozen attestation policy'
        $attestText | Should -Match 'attested/dependencies\.spdx\.json'
        $attestText | Should -Match '\.sigstore\.json'
        $attestText | Should -Match '\.intoto\.jsonl'
    }
}
